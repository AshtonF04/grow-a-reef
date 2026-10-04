--!strict
-- Plant / Claim / Unlock input via client-side ProximityPrompts on the player's own sockets (works on
-- touch, mouse/keyboard and controller). Locked sockets open SocketPopupController on a short hold. The custom tap-to-place ghost replaces this in M5-02.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local TimeUtil = require(ReplicatedStorage.Shared.Util.TimeUtil)
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local PlotLocator = require(script.Parent.Parent.Util.PlotLocator)
local StateController = require(script.Parent.StateController)
local PlantTrayController = require(script.Parent.PlantTrayController)
local ShopController = require(script.Parent.ShopController)
local SocketPopupController = require(script.Parent.SocketPopupController)
local Theme = require(script.Parent.Parent.UI.Theme)

local PlacementController = {}

local UNLOCK_HOLD_SECONDS = 0.5 -- locked sockets are "hold E" so walking past never pops a window

local prompts: { [string]: ProximityPrompt } = {}
local sockets: { [string]: BasePart } = {}
local readyTimers: { [string]: thread } = {}
local inFlight: { [string]: boolean } = {}

-- Chooses which fragment to plant: prefer sun_coral, else the first owned (M4-05 replaces with the tray)
local function pickFragment(): string?
	local state = StateController.Get()
	if state == nil then
		return nil
	end
	local fragments = state.inventory.fragments
	if (fragments.sun_coral or 0) > 0 then
		return "sun_coral"
	end
	local best: string? = nil
	for coralId, count in fragments do
		if count > 0 and CoralDefinitions[coralId] and (best == nil or coralId < best) then
			best = coralId
		end
	end
	return best
end

-- Floating "+N 🐚" above the socket after a claim
local function popReward(socket: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Theme.Fonts.Display
	label.TextColor3 = Theme.Colors.Gold
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Theme.Colors.Navy
	stroke.Parent = label
	label.Parent = gui
	gui.Adornee = socket
	gui.Parent = socket
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 8, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(1.3, function()
		gui:Destroy()
	end)
end

function PlacementController.RefreshPrompt(socketId: string)
	local prompt = prompts[socketId]
	local socket = sockets[socketId]
	if prompt == nil or socket == nil then
		return
	end

	local timer = readyTimers[socketId]
	if timer then
		task.cancel(timer)
		readyTimers[socketId] = nil
	end

	prompt.Enabled = false
	if inFlight[socketId] then
		return
	end

	local locked = socket:GetAttribute("Unlocked") ~= true
	prompt.HoldDuration = if locked then UNLOCK_HOLD_SECONDS else 0
	if locked then
		-- Every locked socket opens the details popup; only the next one in unlockOrder can be bought there
		local def = SocketDefinitions[socketId]
		prompt.ObjectText = "🔒 " .. def.displayName
		prompt.ActionText = if SocketPopupController.GetNextLocked() == socketId
			then ("Unlock %d 🐚"):format(def.unlockCostShells)
			else "Details"
		prompt.Enabled = true
		return
	end

	local coralId = socket:GetAttribute("CoralId")
	if coralId == nil then
		prompt.ObjectText = SocketDefinitions[socketId].displayName
		prompt.ActionText = if pickFragment() then "Plant" else "Get Fragments"
		prompt.Enabled = true
		return
	end

	local readyAt = socket:GetAttribute("ReadyAt")
	if type(readyAt) ~= "number" then
		return
	end
	local remaining = readyAt - TimeUtil.Now()
	if remaining <= 0 then
		local coral = CoralDefinitions[coralId :: string]
		prompt.ActionText = "Claim"
		prompt.ObjectText = if coral then coral.displayName else ""
		prompt.Enabled = true
	else
		-- Growing: one delay per socket flips the prompt to Claim exactly at ReadyAt
		readyTimers[socketId] = task.delay(remaining + 0.05, function()
			readyTimers[socketId] = nil
			PlacementController.RefreshPrompt(socketId)
		end)
	end
end

function PlacementController.OnSocketActivated(socketId: string)
	local socket = sockets[socketId]
	if socket == nil or inFlight[socketId] then
		return
	end
	if socket:GetAttribute("Unlocked") ~= true then
		SocketPopupController.Open(socketId) -- the popup's Purchase button does the unlock
		return
	end
	inFlight[socketId] = true
	PlacementController.RefreshPrompt(socketId)

	local coralId = socket:GetAttribute("CoralId")
	if coralId == nil then
		-- Empty socket: choose a coral in the plant tray, or go buy one
		if pickFragment() then
			PlantTrayController.Open(socketId)
		else
			ShopController.Open()
		end
	else
		local result = ClientNet.ClaimCoral(socketId)
		if result.ok then
			popReward(socket, "+" .. result.value.shells .. " 🐚")
		else
			warn("PlacementController: claim failed: " .. tostring(result.err))
		end
	end

	inFlight[socketId] = nil
	PlacementController.RefreshPrompt(socketId)
end

local function bindSocket(socketId: string, socket: BasePart)
	local old = prompts[socketId]
	if old then
		old:Destroy() -- socket re-streamed: rebind to the new instance
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReefPrompt"
	prompt.HoldDuration = 0
	prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = socket
	prompt.Triggered:Connect(function()
		PlacementController.OnSocketActivated(socketId)
	end)
	prompts[socketId] = prompt
	sockets[socketId] = socket

	for _, attr in { "Unlocked", "CoralId", "ReadyAt" } do
		socket:GetAttributeChangedSignal(attr):Connect(function()
			PlacementController.RefreshPrompt(socketId)
		end)
	end
	PlacementController.RefreshPrompt(socketId)
end

function PlacementController.Init()
	local plot = PlotLocator.WaitForOwnPlot()
	if plot == nil then
		warn("PlacementController: no plot assigned, prompts disabled")
		return
	end
	PlotLocator.ObserveSockets(plot, bindSocket)

	StateController.Changed:Connect(function(sliceKey: string)
		if sliceKey == "inventory" or sliceKey == "snapshot" or sliceKey == "currencies" or sliceKey == "unlocks" then
			for socketId in prompts do
				PlacementController.RefreshPrompt(socketId)
			end
		end
	end)
end

return PlacementController
