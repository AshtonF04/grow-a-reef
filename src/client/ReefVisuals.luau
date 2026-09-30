--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerState = Types.PlayerState
type Placement = Types.Placement

type Actions = {
	unlock: (string) -> (),
	plant: (string, string) -> (),
	harvest: (string) -> (),
}

type Marker = {
	status: TextLabel,
	title: TextLabel,
}

local ReefVisuals = {}

local mounted = false
local actions: Actions? = nil
local current: PlayerState? = nil
local pads: { [string]: BasePart } = {}
local prompts: { [string]: ProximityPrompt } = {}
local markers: { [string]: Marker } = {}
local corals: { [string]: Model } = {}
local basePivots: { [string]: CFrame } = {}

type CoralLook = {
	body: Color3,
	tip: Color3,
	deep: Color3,
}

local LOOKS: { [string]: CoralLook } = {
	sun_coral = {
		body = Color3.fromRGB(255, 122, 66),
		tip = Color3.fromRGB(255, 196, 112),
		deep = Color3.fromRGB(196, 78, 46),
	},
}

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function nub(model: Model, position: Vector3, diameter: number, color: Color3)
	local piece = Instance.new("Part")
	piece.Name = "Tip"
	piece.Shape = Enum.PartType.Ball
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Size = Vector3.new(diameter, diameter, diameter)
	piece.CFrame = CFrame.new(position)
	prepare(piece)
	piece.Parent = model
end

local function buildCoral(coralId: string): Model
	local fallback = LOOKS.sun_coral
	assert(fallback, "Missing sun coral colors")
	local look = LOOKS[coralId] or fallback
	local model = Instance.new("Model")
	model.Name = "Coral"
	model:SetAttribute("CoralId", coralId)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Transparency = 1
	root.Size = Vector3.new(0.6, 0.6, 0.6)
	root.CFrame = CFrame.new(0, 0, 0)
	prepare(root)
	root.Parent = model
	model.PrimaryPart = root

	-- Sun coral is a cluster of polyps. Balls stay upright no matter how the model turns.
	nub(model, Vector3.new(0, 0.7, 0), 1.7, look.deep)
	nub(model, Vector3.new(0, 1.45, 0), 1.35, look.body)
	nub(model, Vector3.new(-0.85, 1.35, -0.35), 0.85, look.body)
	nub(model, Vector3.new(0.9, 1.3, 0.3), 0.82, look.body)
	nub(model, Vector3.new(-0.55, 2.15, 0.35), 0.95, look.tip)
	nub(model, Vector3.new(0.7, 2.2, -0.2), 0.9, look.tip)
	nub(model, Vector3.new(0.1, 2.35, -0.7), 0.84, look.tip)
	nub(model, Vector3.new(-0.15, 2.45, 0.65), 0.8, look.tip)
	nub(model, Vector3.new(0.15, 2.85, 0.05), 0.72, look.tip)

	return model
end

local function pose(model: Model, socketId: string, progress: number)
	local base = basePivots[socketId]
	if not base then
		return
	end
	local scale = 0.18 + 0.82 * progress
	if progress >= 1 then
		scale += math.sin(os.clock() * 3) * 0.035
	end
	local bob = math.sin(os.clock() * 1.35 + #socketId) * 0.06
	model:ScaleTo(math.max(0.05, scale))
	model:PivotTo(base * CFrame.new(0, bob, 0))
end

local function ensureHighlight(model: Model, mature: boolean)
	local existing = model:FindFirstChild("ReadyGlow")
	if mature then
		if not existing then
			local highlight = Instance.new("Highlight")
			highlight.Name = "ReadyGlow"
			highlight.Adornee = model
			highlight.FillColor = Color3.fromRGB(255, 214, 130)
			highlight.FillTransparency = 0.72
			highlight.OutlineColor = Color3.fromRGB(255, 228, 160)
			highlight.OutlineTransparency = 0.15
			highlight.Parent = model
		end
		local root = model.PrimaryPart
		if root and not root:FindFirstChild("RipeLight") then
			local light = Instance.new("PointLight")
			light.Name = "RipeLight"
			light.Color = Color3.fromRGB(255, 170, 90)
			light.Brightness = 1.3
			light.Range = 12
			light.Parent = root
		end
	else
		if existing then
			existing:Destroy()
		end
		local root = model.PrimaryPart
		local light = root and root:FindFirstChild("RipeLight")
		if light then
			light:Destroy()
		end
	end
end

local function ensureCoral(socketId: string, placement: Placement, now: number)
	local existing = corals[socketId]
	if existing and existing.Parent then
		local sameCoral = existing:GetAttribute("CoralId") == placement.coralId
		local sameTime = existing:GetAttribute("PlantedAt") == placement.plantedAt
		if sameCoral and sameTime then
			return
		end
		existing:Destroy()
		corals[socketId] = nil
	end

	local pad = pads[socketId]
	if not pad or not pad.Parent then
		return
	end

	local model = buildCoral(placement.coralId)
	model:SetAttribute("PlantedAt", placement.plantedAt)
	model.Parent = pad.Parent
	basePivots[socketId] = pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0)
	corals[socketId] = model
	pose(model, socketId, ReefRules.Progress(placement.plantedAt, placement.coralId, now))
end

local function requestAction(socketId: string)
	local state = current
	local handler = actions
	if not state or not handler then
		return
	end
	local now = workspace:GetServerTimeNow()
	if not state.socketUnlocks[socketId] then
		handler.unlock(socketId)
		return
	end
	local placement = state.placements[socketId]
	if placement then
		if ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
			handler.harvest(socketId)
		end
		return
	end
	local coralId = ReefRules.FirstFragment(state)
	if coralId then
		handler.plant(socketId, coralId)
	end
end

local function makePrompt(pad: BasePart, socketId: string): ProximityPrompt
	local socket = SocketDefinitions[socketId]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReefPrompt"
	prompt.ObjectText = if socket then socket.displayName else socketId
	prompt.ActionText = "Look"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = pad
	prompt.Triggered:Connect(function()
		requestAction(socketId)
	end)
	return prompt
end

local function makeMarker(pad: BasePart, titleText: string): Marker
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Marker"
	billboard.Size = UDim2.fromOffset(180, 52)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, pad.Size.Y / 2 + 3.3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.Parent = pad

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 32, 38)
	frame.BackgroundTransparency = 0.22
	frame.BorderSizePixel = 0
	frame.Parent = billboard
	corner(frame, 8)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(8, 4)
	title.Size = UDim2.new(1, -16, 0, 20)
	title.Font = Fonts.Bold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 246, 242)
	title.Text = titleText
	title.Parent = frame

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(8, 24)
	status.Size = UDim2.new(1, -16, 0, 20)
	status.Font = Fonts.Body
	status.TextSize = 14
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(186, 214, 206)
	status.Text = ""
	status.Parent = frame

	return { title = title, status = status }
end

local function ensureGuide(pad: BasePart, enabled: boolean)
	local highlight = pad:FindFirstChild("GuideLight")
	if not highlight then
		local created = Instance.new("Highlight")
		created.Name = "GuideLight"
		created.Adornee = pad
		created.FillTransparency = 1
		created.OutlineColor = Color3.fromRGB(255, 214, 120)
		created.OutlineTransparency = 0.05
		created.Parent = pad
		highlight = created
	end
	if highlight:IsA("Highlight") then
		highlight.Enabled = enabled
	end

	local sparkle = pad:FindFirstChild("GuideSparkle")
	if not sparkle then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "GuideSparkle"
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Rate = 4
		emitter.Lifetime = NumberRange.new(1.1, 1.8)
		emitter.Speed = NumberRange.new(0.3, 0.9)
		emitter.Size = NumberSequence.new(0.22)
		emitter.LightEmission = 0.7
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 210, 130))
		emitter.Parent = pad
		sparkle = emitter
	end
	if sparkle:IsA("ParticleEmitter") then
		sparkle.Enabled = enabled
	end
end

local function refresh(state: PlayerState, now: number)
	local showGuide = state.shells == 0 and (state.fragments.sun_coral or 0) > 0 and next(state.placements) == nil
	for _, socket in ReefRules.OrderedSockets() do
		local pad = pads[socket.id]
		local placement = state.placements[socket.id]
		local unlocked = state.socketUnlocks[socket.id] == true
		local mature = placement ~= nil and ReefRules.IsMature(placement.plantedAt, placement.coralId, now)

		if pad then
			ensureGuide(pad, showGuide and socket.id == "sandy_patch" and unlocked and placement == nil)
		end

		local marker = markers[socket.id]
		if marker then
			marker.status.Text = ReefRules.StatusLine(state, socket.id, now)
			marker.title.TextColor3 = if mature then Color3.fromRGB(255, 214, 130) else Color3.fromRGB(236, 246, 242)
		end

		local prompt = prompts[socket.id]
		if prompt then
			if not unlocked then
				local block = ReefRules.UnlockBlock(state, socket.id)
				prompt.ActionText = "Unlock"
				prompt.Enabled = block == nil or block.code == "shells"
			elseif placement then
				prompt.ActionText = if mature then "Harvest" else "Growing"
				prompt.Enabled = mature
			else
				local coralId = ReefRules.FirstFragment(state)
				prompt.ActionText = if coralId then "Plant" else "Empty"
				prompt.Enabled = coralId ~= nil
			end
		end

		if placement then
			ensureCoral(socket.id, placement, now)
			local model = corals[socket.id]
			if model then
				pose(model, socket.id, ReefRules.Progress(placement.plantedAt, placement.coralId, now))
				ensureHighlight(model, mature)
			end
		end
	end
end

function ReefVisuals.IsMounted(): boolean
	return mounted
end

function ReefVisuals.Mount(plot: Model, actionFns: Actions)
	actions = actionFns
	for _, socket in ReefRules.OrderedSockets() do
		local socketModel = plot:WaitForChild(socket.id, 10)
		if socketModel and socketModel:IsA("Model") then
			local pad = socketModel:WaitForChild("Pad", 5)
			if pad and pad:IsA("BasePart") then
				pads[socket.id] = pad
				prompts[socket.id] = makePrompt(pad, socket.id)
				markers[socket.id] = makeMarker(pad, socket.displayName)
			end
		end
	end
	mounted = next(pads) ~= nil
end

function ReefVisuals.Apply(state: PlayerState)
	if not mounted then
		return
	end
	current = state
	local stale = {}
	for socketId, model in corals do
		local placement = state.placements[socketId]
		local same = placement ~= nil
			and model:GetAttribute("CoralId") == placement.coralId
			and model:GetAttribute("PlantedAt") == placement.plantedAt
		if not same then
			table.insert(stale, socketId)
		end
	end
	for _, socketId in stale do
		local model = corals[socketId]
		if model then
			model:Destroy()
		end
		corals[socketId] = nil
		basePivots[socketId] = nil
	end
	refresh(state, workspace:GetServerTimeNow())
end

function ReefVisuals.Tick(state: PlayerState, now: number)
	if not mounted then
		return
	end
	current = state
	refresh(state, now)
end

return ReefVisuals
