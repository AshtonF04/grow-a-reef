--!strict
-- Tap-to-place (M5-02). A camera raycast from the tap/click finds the nearest socket on the player's own
-- plot.
--   Normal mode: tapping a socket does what its prompt would (SocketTapped -> PlacementController), and
--   the mouse hover outlines the socket under the cursor.
--   Placement mode (Begin(coralId), entered from the plant tray's picker): every own socket gets a fit tag
--   (✓ Great fit / ~ OK fit / • No bonus / 🔒 Locked / ✕ In use; colour is never the only cue), the mouse
--   hover shows a see-through Bud ghost tinted by fit, and a tap on a free socket plants there. A bottom
--   banner has Cancel (Esc / gamepad B also cancel).
-- Plant() is optimistic: a stand-in Bud appears at once and is dropped when the server's CoralId arrives,
-- or shrinks away on error (ClientNet shows the toast). The ghost is a runtime see-through clone of each
-- coral's Bud model, so no separate ghost meshes are needed.
-- ProximityPrompts stay as the controller and keyboard fallback.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local ErrorMessages = require(ReplicatedStorage.Shared.Config.ErrorMessages)
local EconomyMath = require(ReplicatedStorage.Shared.Logic.EconomyMath)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local PlotLocator = require(script.Parent.Parent.Util.PlotLocator)
local ReefVisualController = require(script.Parent.ReefVisualController)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Toast = require(script.Parent.Parent.UI.Toast)

type Fit = { valid: boolean, text: string, color: Color3, textColor: Color3, code: string? }

local TapPlaceController = {}
TapPlaceController.SocketTapped = Signal.new() :: Signal.Signal<string> -- normal mode only
TapPlaceController.PendingChanged = Signal.new() :: Signal.Signal<string>

local TAP_MAX_MOVE = 12 -- pixels; more than this is a camera drag, not a tap
local TAP_MAX_SECONDS = 0.5
local PICK_RADIUS = 4.5 -- studs from the hit point to a socket centre
local PICK_MAX_HEIGHT = 8
local RAY_LENGTH = 400
local GHOST_TRANSPARENCY = 0.55
local CONFIRM_WAIT_STEPS = 30 -- x 0.1 s for CoralId to replicate after a successful plant
local BUD = "Bud"

local sockets: { [string]: BasePart } = {}
local pending: { [string]: Model } = {}
local markers: { [string]: BillboardGui } = {}
local presses: { [InputObject]: { pos: Vector3, t: number } } = {}
local placingCoral: string? = nil
local fxFolder: Folder? = nil
local highlight: Highlight? = nil
local ghost: Model? = nil
local banner: ScreenGui? = nil
local bannerLabel: TextLabel? = nil

local function fitFor(coralId: string, socketId: string): Fit
	local socket = sockets[socketId]
	if socket == nil or socket:GetAttribute("Unlocked") ~= true then
		return { valid = false, text = "🔒 Locked", color = Theme.Colors.Red, textColor = Theme.Colors.White, code = "SocketLocked" }
	end
	if socket:GetAttribute("CoralId") ~= nil or pending[socketId] then
		return { valid = false, text = "✕ In use", color = Theme.Colors.Red, textColor = Theme.Colors.White, code = "SocketOccupied" }
	end
	local coral, def = CoralDefinitions[coralId], SocketDefinitions[socketId]
	if coral and def and EconomyMath.IsConditionMatch(coral, def) then
		return { valid = true, text = "✓ Great fit", color = Theme.Colors.Seafoam, textColor = Theme.Colors.TextDark }
	elseif coral and def and EconomyMath.GetConditionBonus(coral, def) > 0 then
		return { valid = true, text = "~ OK fit", color = Theme.Colors.Amber, textColor = Theme.Colors.TextDark }
	end
	return { valid = true, text = "• No bonus", color = Theme.Colors.BlueLight, textColor = Theme.Colors.TextDark }
end

local function makeSeeThrough(model: Model, transparency: number?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if transparency and d.Transparency < 1 then
				d.CastShadow = false
				d.Transparency = transparency
			end
		end
	end
end

-- Fit tags over every own socket while placing; removed otherwise
local function refreshMarkers()
	for socketId, socket in sockets do
		local marker = markers[socketId]
		if placingCoral == nil or socket.Parent == nil then
			if marker then
				marker:Destroy()
				markers[socketId] = nil
			end
			continue
		end
		if marker == nil or marker.Parent ~= socket then
			if marker then
				marker:Destroy()
			end
			marker = UIKit.new("BillboardGui", {
				Name = "FitTag",
				Size = UDim2.fromOffset(124, 34),
				StudsOffset = Vector3.new(0, 3.5, 0),
				AlwaysOnTop = true,
				LightInfluence = 0,
				MaxDistance = 120,
				Adornee = socket,
				Parent = socket,
			}, {
				UIKit.new("TextLabel", {
					Name = "Tag",
					Size = UDim2.fromScale(1, 1),
					FontFace = Theme.Fonts.Body,
					TextScaled = true,
				}, { UIKit.corner(Theme.Corner.Pill), UIKit.padding(4), UIKit.stroke(Theme.Colors.Navy, 2) }),
			})
			markers[socketId] = marker
		end
		local fit = fitFor(placingCoral :: string, socketId)
		local tag = (marker :: BillboardGui):FindFirstChild("Tag") :: TextLabel
		tag.Text = fit.text
		tag.BackgroundColor3 = fit.color
		tag.TextColor3 = fit.textColor
	end
end

local function clearHover()
	if highlight then
		highlight.Adornee = nil
	end
	if ghost then
		ghost.Parent = nil
	end
end

local function setHover(socketId: string?)
	local hl = highlight
	if hl == nil then
		return
	end
	if socketId == nil then
		clearHover()
		return
	end
	local socket = sockets[socketId]
	local coralId = placingCoral
	if coralId == nil then
		-- Normal mode: a soft white outline on the socket the cursor is over
		if ghost then
			ghost.Parent = nil
		end
		hl.Adornee = socket
		hl.FillColor = Theme.Colors.White
		hl.FillTransparency = 0.85
		hl.OutlineColor = Theme.Colors.White
		return
	end

	local fit = fitFor(coralId, socketId)
	if fit.valid then
		if ghost == nil or ghost:GetAttribute("CoralId") ~= coralId then
			if ghost then
				ghost:Destroy()
			end
			local model = ReefVisualController.CloneStageModel(coralId, BUD)
			model.Name = "PlacementGhost"
			model:SetAttribute("CoralId", coralId)
			makeSeeThrough(model, GHOST_TRANSPARENCY)
			ghost = model
		end
		local g = ghost :: Model
		g:PivotTo(ReefVisualController.GetCoralPivot(socket))
		g.Parent = fxFolder
		hl.Adornee = g
	else
		if ghost then
			ghost.Parent = nil
		end
		hl.Adornee = socket
	end
	hl.FillColor = fit.color
	hl.FillTransparency = 0.6
	hl.OutlineColor = fit.color
end

-- Nearest own socket to where the camera ray through the screen point hits the world
local function pickSocket(screenPos: Vector3): string?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	if fxFolder then
		table.insert(exclude, fxFolder)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if hit == nil then
		return nil
	end

	local best: string? = nil
	local bestDistance = math.huge
	for socketId, socket in sockets do
		if socket.Parent then
			local offset = hit.Position - socket.Position
			local distance = Vector2.new(offset.X, offset.Z).Magnitude
			local reach = math.max(PICK_RADIUS, math.max(socket.Size.X, socket.Size.Z) / 2 + 1)
			if distance < reach and math.abs(offset.Y) < PICK_MAX_HEIGHT and distance < bestDistance then
				best, bestDistance = socketId, distance
			end
		end
	end
	return best
end

local function buildBanner()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local screen = UIKit.new("ScreenGui", {
		Name = "PlacementBanner",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local frame = UIKit.new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(1, -32, 0, 64),
		BackgroundColor3 = Theme.Colors.Blue,
		Parent = screen,
	}, {
		UIKit.corner(Theme.Corner.M),
		UIKit.stroke(Theme.Colors.BlueLight, Theme.RimThickness),
		UIKit.gloss(),
		UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(460, 64) }),
	})
	local label = UIKit.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.new(1, -140, 1, -16),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = Theme.TextSize.Body, Parent = label })
	local cancel = UIKit.button({
		Name = "Cancel",
		Text = "Cancel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(110, 44),
		Parent = frame,
	}, Theme.Colors.Red, Theme.Colors.RedDark)
	cancel.Activated:Connect(function()
		TapPlaceController.Cancel()
	end)
	screen.Parent = playerGui
	banner = screen
	bannerLabel = label
end

function TapPlaceController.IsPlacing(): boolean
	return placingCoral ~= nil
end

function TapPlaceController.IsPending(socketId: string): boolean
	return pending[socketId] ~= nil
end

function TapPlaceController.Begin(coralId: string)
	local coral = CoralDefinitions[coralId]
	if coral == nil then
		return
	end
	local anyFree = false
	for socketId in sockets do
		if fitFor(coralId, socketId).valid then
			anyFree = true
		end
	end
	if not anyFree then
		Toast.Info("No free spots. Claim a coral or unlock a spot first!")
		return
	end
	placingCoral = coralId
	if banner == nil then
		buildBanner()
	end
	if bannerLabel then
		bannerLabel.Text = ("Tap a spot to plant %s"):format(coral.displayName)
	end
	if banner then
		banner.Enabled = true
	end
	clearHover()
	refreshMarkers()
end

function TapPlaceController.Cancel()
	placingCoral = nil
	if banner then
		banner.Enabled = false
	end
	clearHover()
	refreshMarkers()
end

-- Optimistic plant: shows the Bud at once, then keeps it (server agreed) or rolls it back (error toast)
function TapPlaceController.Plant(socketId: string, coralId: string): boolean
	local socket = sockets[socketId]
	if socket == nil or pending[socketId] then
		return false
	end
	local standIn = ReefVisualController.CloneStageModel(coralId, BUD)
	standIn.Name = socketId .. "_Pending"
	makeSeeThrough(standIn)
	local pivot = ReefVisualController.GetCoralPivot(socket)
	standIn:PivotTo(pivot)
	standIn.Parent = fxFolder
	pending[socketId] = standIn
	TapPlaceController.PendingChanged:Fire(socketId)
	refreshMarkers()

	local result = ClientNet.PlantCoral(socketId, coralId)
	if result.ok then
		-- ReefVisualController draws the real coral from the replicated CoralId; drop the stand-in after it
		for _ = 1, CONFIRM_WAIT_STEPS do
			if socket:GetAttribute("CoralId") ~= nil or socket.Parent == nil then
				break
			end
			task.wait(0.1)
		end
		standIn:Destroy()
	else
		-- Rollback: shrink the stand-in away (ClientNet already showed the error toast)
		local scale = Instance.new("NumberValue")
		scale.Value = 1
		scale.Changed:Connect(function(v)
			if standIn.Parent then
				pcall(standIn.ScaleTo, standIn, math.max(v, 0.05))
				standIn:PivotTo(pivot)
			end
		end)
		local tween = TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Value = 0.05 })
		tween:Play()
		tween.Completed:Wait()
		scale:Destroy()
		standIn:Destroy()
	end
	pending[socketId] = nil
	TapPlaceController.PendingChanged:Fire(socketId)
	refreshMarkers()
	return result.ok
end

local function onTap(screenPos: Vector3)
	local socketId = pickSocket(screenPos)
	local coralId = placingCoral
	if socketId == nil then
		return -- tapping open ground keeps placement mode on
	end
	if coralId == nil then
		TapPlaceController.SocketTapped:Fire(socketId)
		return
	end
	local fit = fitFor(coralId, socketId)
	if not fit.valid then
		Toast.Error(ErrorMessages.Get(fit.code or "Internal"))
		return
	end
	TapPlaceController.Cancel()
	task.spawn(TapPlaceController.Plant, socketId, coralId)
end

function TapPlaceController.Init()
	local folder = Instance.new("Folder")
	folder.Name = "PlacementFX"
	folder.Parent = workspace
	fxFolder = folder
	highlight = UIKit.new("Highlight", {
		Name = "PlacementHover",
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		OutlineTransparency = 0,
		Parent = folder,
	})

	local plot = PlotLocator.WaitForOwnPlot()
	if plot == nil then
		return
	end
	PlotLocator.ObserveSockets(plot, function(socketId, socket)
		sockets[socketId] = socket
		for _, attr in { "Unlocked", "CoralId" } do
			socket:GetAttributeChangedSignal(attr):Connect(function()
				if placingCoral then
					refreshMarkers()
				end
			end)
		end
		if placingCoral then
			refreshMarkers()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if placingCoral then
				TapPlaceController.Cancel()
			end
			return
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			presses[input] = { pos = input.Position, t = os.clock() }
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local press = presses[input]
		if press == nil then
			return
		end
		presses[input] = nil
		local moved = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(press.pos.X, press.pos.Y)).Magnitude
		if moved <= TAP_MAX_MOVE and os.clock() - press.t <= TAP_MAX_SECONDS then
			onTap(input.Position)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			setHover(if processed then nil else pickSocket(input.Position))
		end
	end)
end

return TapPlaceController
