--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralLooks = require(ReplicatedStorage.Shared.Config.CoralLooks)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local Types = require(ReplicatedStorage.Shared.Types)
local PlantChoice = require(script.Parent.PlantChoice)

type PlayerState = Types.PlayerState
type Placement = Types.Placement
type CoralLook = CoralLooks.CoralLook
type Stage = ReefRules.Stage

type Actions = {
	unlock: (string) -> (),
	plant: (string, string) -> (),
	harvest: (string) -> (),
}

type Marker = {
	billboard: BillboardGui,
	status: TextLabel,
	title: TextLabel,
}

type Effects = {
	grow: ParticleEmitter,
	harvest: ParticleEmitter,
	flourish: ParticleEmitter,
	ripe: PointLight,
	guide: Highlight,
	guideSparkle: ParticleEmitter,
}

-- Mature coral size relative to the built model.
local CORAL_SIZE = 1.2
local STAGE_SCALE: { [Stage]: number } = {
	Fragment = 0.3,
	Sprouting = 0.5,
	Growing = 0.75,
	Mature = 1,
}
local POP_SECONDS = 0.45
local MARKER_LIFT = 4.6
local MARKER_HALF = Vector2.new(94, 30)
local MARKER_RANGE = 90

local ReefVisuals = {}

local mounted = false
local actions: Actions? = nil
local current: PlayerState? = nil
local pads: { [string]: BasePart } = {}
local prompts: { [string]: ProximityPrompt } = {}
local markers: { [string]: Marker } = {}
local effects: { [string]: Effects } = {}
local corals: { [string]: Model } = {}
local basePivots: { [string]: CFrame } = {}
local shownStage: { [string]: Stage } = {}
local popStart: { [string]: number } = {}

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

local function nub(model: Model, position: Vector3, diameter: number, color: Color3, material: Enum.Material?)
	local piece = Instance.new("Part")
	piece.Name = "Tip"
	piece.Shape = Enum.PartType.Ball
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Size = Vector3.new(diameter, diameter, diameter)
	piece.CFrame = CFrame.new(position)
	prepare(piece)
	piece.Parent = model
	return piece
end

local function limb(model: Model, from: Vector3, to: Vector3, diameter: number, color: Color3)
	local direction = to - from
	local up = if math.abs(direction.Unit.Y) > 0.9 then Vector3.zAxis else Vector3.yAxis
	local piece = Instance.new("Part")
	piece.Name = "Limb"
	piece.Shape = Enum.PartType.Cylinder
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Size = Vector3.new(direction.Magnitude, diameter, diameter)
	-- A cylinder runs along its X axis. Turn X to face the target.
	piece.CFrame = CFrame.lookAt((from + to) / 2, to, up) * CFrame.Angles(0, math.pi / 2, 0)
	prepare(piece)
	piece.Parent = model
end

local function disc(model: Model, center: Vector3, diameter: number, thickness: number, color: Color3, tiltX: number, tiltZ: number)
	local piece = Instance.new("Part")
	piece.Name = "Plate"
	piece.Shape = Enum.PartType.Cylinder
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Size = Vector3.new(thickness, diameter, diameter)
	piece.CFrame = CFrame.new(center) * CFrame.Angles(tiltX, 0, tiltZ) * CFrame.Angles(0, 0, math.pi / 2)
	prepare(piece)
	piece.Parent = model
end

-- Each builder draws a mature coral standing on the origin. Parts below y = 0 sit inside the pad.
local BUILDERS: { [string]: (Model, CoralLook) -> () } = {
	sun_coral = function(model, look)
		nub(model, Vector3.new(0, 0.7, 0), 1.7, look.deep)
		nub(model, Vector3.new(0, 1.45, 0), 1.35, look.body)
		nub(model, Vector3.new(-0.85, 1.35, -0.35), 0.85, look.body)
		nub(model, Vector3.new(0.9, 1.3, 0.3), 0.82, look.body)
		nub(model, Vector3.new(-0.55, 2.15, 0.35), 0.95, look.tip)
		nub(model, Vector3.new(0.7, 2.2, -0.2), 0.9, look.tip)
		nub(model, Vector3.new(0.1, 2.35, -0.7), 0.84, look.tip)
		nub(model, Vector3.new(-0.15, 2.45, 0.65), 0.8, look.tip)
		nub(model, Vector3.new(0.15, 2.85, 0.05), 0.72, look.tip)
	end,

	branch_coral = function(model, look)
		local base = Vector3.new(0, 0.2, 0)
		nub(model, Vector3.new(0, 0.25, 0), 1.0, look.deep)
		local forks = {
			{ Vector3.new(0.8, 1.6, 0.2), Vector3.new(1.4, 2.5, 0.5), Vector3.new(0.9, 2.7, -0.2) },
			{ Vector3.new(-0.7, 1.8, -0.3), Vector3.new(-1.3, 2.6, -0.6), Vector3.new(-0.5, 2.9, -0.7) },
			{ Vector3.new(0.1, 2.0, 0.8), Vector3.new(0.3, 3.0, 1.3), Vector3.new(-0.4, 2.8, 1.1) },
			{ Vector3.new(0.2, 2.2, -0.9), Vector3.new(0.7, 3.1, -1.2) },
			{ Vector3.new(-0.1, 2.5, 0.05), Vector3.new(0.1, 3.4, 0.1) },
		}
		for _, fork in forks do
			local joint = fork[1]
			limb(model, base, joint, 0.36, look.body)
			for index = 2, #fork do
				limb(model, joint, fork[index], 0.28, look.body)
				nub(model, fork[index], 0.4, look.tip)
			end
		end
	end,

	brain_coral = function(model, look)
		nub(model, Vector3.new(0, 0.2, 0), 3.2, look.deep)
		nub(model, Vector3.new(0, 0.55, 0), 2.7, look.body)
		local lobes = {
			Vector3.new(0.6, 1.5, 0.3),
			Vector3.new(-0.6, 1.45, 0.4),
			Vector3.new(0.1, 1.55, -0.6),
			Vector3.new(-0.2, 1.75, 0.05),
			Vector3.new(0.85, 1.1, -0.6),
			Vector3.new(-0.9, 1.05, -0.4),
		}
		for index, position in lobes do
			nub(model, position, if index == 4 then 1.2 else 0.95, if index % 2 == 0 then look.tip else look.body)
		end
	end,

	plate_coral = function(model, look)
		limb(model, Vector3.new(0, -0.1, 0), Vector3.new(0.05, 2.4, 0.02), 0.5, look.deep)
		disc(model, Vector3.new(0.2, 1.1, 0.1), 3.6, 0.22, look.body, 0.08, -0.06)
		disc(model, Vector3.new(-0.3, 1.8, -0.2), 2.8, 0.2, look.body, -0.1, 0.08)
		disc(model, Vector3.new(0.15, 2.45, 0.1), 1.9, 0.18, look.tip, 0.06, 0.1)
		nub(model, Vector3.new(0.05, 2.6, 0.02), 0.5, look.tip)
	end,

	star_coral = function(model, look)
		local columns = {
			{ foot = Vector3.new(0, 0, 0), height = 2.5, width = 1.35 },
			{ foot = Vector3.new(0.95, 0, 0.45), height = 1.7, width = 1.1 },
			{ foot = Vector3.new(-0.85, 0, -0.5), height = 2.0, width = 1.0 },
		}
		local rng = Random.new(7)
		for _, column in columns do
			local foot = column.foot
			local height = column.height
			local width = column.width
			local top = foot + Vector3.new(0, height, 0)
			limb(model, foot, top, width, look.body)
			nub(model, top, width, look.body)
			for _ = 1, 7 do
				local angle = rng:NextNumber(0, math.pi * 2)
				local y = rng:NextNumber(0.4, height)
				local offset = Vector3.new(math.cos(angle) * width / 2, y, math.sin(angle) * width / 2)
				nub(model, foot + offset, 0.24, look.tip, Enum.Material.Neon)
			end
			nub(model, top + Vector3.new(0, width / 2, 0), 0.26, look.tip, Enum.Material.Neon)
		end
	end,

	bubble_coral = function(model, look)
		nub(model, Vector3.new(0, 0, 0), 1.9, look.deep)
		local rng = Random.new(11)
		for index = 1, 11 do
			local angle = index * 2.4
			local radius = rng:NextNumber(0.2, 1.05)
			local position = Vector3.new(math.cos(angle) * radius, 0.75 + rng:NextNumber(0, 1.1), math.sin(angle) * radius)
			local bubble = nub(model, position, rng:NextNumber(0.62, 0.95), look.body, Enum.Material.Glass)
			bubble.Transparency = 0.22
		end
		nub(model, Vector3.new(0, 1.9, 0), 0.8, look.tip, Enum.Material.Glass).Transparency = 0.15
	end,
}

local function buildCoral(coralId: string): Model
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

	local builder = BUILDERS[coralId] or BUILDERS.sun_coral
	builder(model, CoralLooks.Get(coralId))
	return model
end

local function pose(model: Model, socketId: string, stage: Stage)
	local base = basePivots[socketId]
	if not base then
		return
	end
	local scale = STAGE_SCALE[stage] * CORAL_SIZE
	local started = popStart[socketId]
	if started then
		local t = (os.clock() - started) / POP_SECONDS
		if t < 1 then
			scale *= 1 + math.sin(math.pi * t) * 0.22
		else
			popStart[socketId] = nil
		end
	end
	if stage == "Mature" then
		scale *= 1 + math.sin(os.clock() * 3) * 0.03
	end
	if math.abs(model:GetScale() - scale) > 1e-3 then
		model:ScaleTo(math.max(0.05, scale))
	end
	local bob = math.sin(os.clock() * 1.35 + #socketId) * 0.06
	model:PivotTo(base * CFrame.new(0, bob, 0))
end

local function setReadyGlow(model: Model, on: boolean)
	local existing = model:FindFirstChild("ReadyGlow")
	if on and not existing then
		local highlight = Instance.new("Highlight")
		highlight.Name = "ReadyGlow"
		highlight.Adornee = model
		highlight.FillColor = Color3.fromRGB(255, 214, 130)
		highlight.FillTransparency = 0.72
		highlight.OutlineColor = Color3.fromRGB(255, 228, 160)
		highlight.OutlineTransparency = 0.15
		highlight.Parent = model
	elseif not on and existing then
		existing:Destroy()
	end
end

local function ensureCoral(socketId: string, placement: Placement)
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
	shownStage[socketId] = nil
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
	local coralId = PlantChoice.For(state, socketId)
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
	billboard.StudsOffsetWorldSpace = Vector3.new(0, pad.Size.Y / 2 + MARKER_LIFT, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = MARKER_RANGE
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
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.TextColor3 = Color3.fromRGB(186, 214, 206)
	status.Text = ""
	status.Parent = frame

	return { billboard = billboard, title = title, status = status }
end

local function emitter(parent: Instance, name: string, color: Color3, rate: number): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Name = name
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Rate = rate
	particles.Lifetime = NumberRange.new(0.8, 1.6)
	particles.Speed = NumberRange.new(1.5, 4)
	particles.SpreadAngle = Vector2.new(70, 70)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.LightEmission = 0.8
	particles.Color = ColorSequence.new(color)
	particles.Parent = parent
	return particles
end

local function makeEffects(pad: BasePart): Effects
	local attachment = Instance.new("Attachment")
	attachment.Name = "ReefFX"
	attachment.Position = Vector3.new(0, pad.Size.Y / 2 + 1, 0)
	attachment.Parent = pad

	local grow = emitter(attachment, "GrowBurst", Color3.fromRGB(190, 255, 220), 0)
	local harvest = emitter(attachment, "HarvestBurst", Color3.fromRGB(255, 214, 120), 0)
	harvest.Speed = NumberRange.new(4, 8)
	harvest.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	local flourish = emitter(attachment, "Flourish", Color3.fromRGB(255, 236, 170), 3)
	flourish.Speed = NumberRange.new(0.3, 0.9)
	flourish.Enabled = false

	local ripe = Instance.new("PointLight")
	ripe.Name = "RipeLight"
	ripe.Color = Color3.fromRGB(255, 170, 90)
	ripe.Brightness = 1.3
	ripe.Range = 12
	ripe.Enabled = false
	ripe.Parent = attachment

	local guide = Instance.new("Highlight")
	guide.Name = "GuideLight"
	guide.Adornee = pad
	guide.FillTransparency = 1
	guide.OutlineColor = Color3.fromRGB(255, 214, 120)
	guide.OutlineTransparency = 0.05
	guide.Enabled = false
	guide.Parent = pad

	local guideSparkle = emitter(pad, "GuideSparkle", Color3.fromRGB(255, 210, 130), 4)
	guideSparkle.Lifetime = NumberRange.new(1.1, 1.8)
	guideSparkle.Speed = NumberRange.new(0.3, 0.9)
	guideSparkle.Size = NumberSequence.new(0.22)
	guideSparkle.Enabled = false

	return {
		grow = grow,
		harvest = harvest,
		flourish = flourish,
		ripe = ripe,
		guide = guide,
		guideSparkle = guideSparkle,
	}
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.Min.X < b.Max.X and b.Min.X < a.Max.X and a.Min.Y < b.Max.Y and b.Min.Y < a.Max.Y
end

-- Hides any marker that would sit on top of a more important or nearer one, or under the guide panel.
local function declutter(priority: { [string]: number }, covered: { Rect })
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	type Entry = { marker: Marker, point: Vector3, visible: boolean, rank: number }
	local entries: { Entry } = {}
	for socketId, marker in markers do
		local pad = pads[socketId]
		if pad then
			local world = pad.Position + Vector3.new(0, pad.Size.Y / 2 + MARKER_LIFT, 0)
			local point, onScreen = camera:WorldToViewportPoint(world)
			table.insert(entries, {
				marker = marker,
				point = point,
				visible = onScreen and point.Z > 0 and point.Z < MARKER_RANGE,
				rank = priority[socketId] or 1,
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.point.Z < b.point.Z
	end)

	local taken = table.clone(covered)
	for _, entry in entries do
		local show = entry.visible
		if show then
			local center = Vector2.new(entry.point.X, entry.point.Y)
			local rect = Rect.new(center - MARKER_HALF, center + MARKER_HALF)
			for _, other in taken do
				if overlaps(rect, other) then
					show = false
					break
				end
			end
			if show then
				table.insert(taken, rect)
			end
		end
		entry.marker.billboard.Enabled = show
	end
end

local function refresh(state: PlayerState, now: number, covered: { Rect })
	local _, stepKind, target = ReefRules.NextStep(state, now)
	local guided = if stepKind == "harvest" or stepKind == "plant" or stepKind == "unlock" then target else nil
	local priority: { [string]: number } = {}

	for _, socket in ReefRules.OrderedSockets() do
		local pad = pads[socket.id]
		local fx = effects[socket.id]
		local placement = state.placements[socket.id]
		local unlocked = state.socketUnlocks[socket.id] == true
		local mature = placement ~= nil and ReefRules.IsMature(placement.plantedAt, placement.coralId, now)
		local flourishing = mature and placement ~= nil and ReefRules.Fit(placement.coralId, socket.id) == "flourishing"

		if fx then
			local glow = guided == socket.id and not mature
			fx.guide.Enabled = glow
			fx.guideSparkle.Enabled = glow
			fx.ripe.Enabled = mature
			fx.flourish.Enabled = flourishing
		end
		if guided == socket.id or mature then
			priority[socket.id] = 0
		end

		local marker = markers[socket.id]
		if marker then
			marker.status.Text = ReefRules.StatusLine(state, socket.id, now, PlantChoice.For(state, socket.id))
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
				local coralId = PlantChoice.For(state, socket.id)
				prompt.ActionText = if coralId then "Plant" else "Empty"
				prompt.Enabled = coralId ~= nil
			end
		end

		if placement and pad then
			ensureCoral(socket.id, placement)
			local model = corals[socket.id]
			if model then
				local stage: Stage = ReefRules.StageOf(placement.plantedAt, placement.coralId, now)
				local previous = shownStage[socket.id]
				local justPlanted = stage == "Fragment"
				if previous ~= stage then
					shownStage[socket.id] = stage
					-- A coral that was already grown when we first saw it appears without a pop.
					if previous ~= nil or justPlanted then
						popStart[socket.id] = os.clock()
						if fx then
							fx.grow:Emit(if mature then 26 else 14)
						end
					end
				end
				model:SetAttribute("Mature", mature)
				pose(model, socket.id, stage)
				setReadyGlow(model, mature)
			end
		end
	end

	declutter(priority, covered)
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
				effects[socket.id] = makeEffects(pad)
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
			local fx = effects[socketId]
			if fx and model:GetAttribute("Mature") == true then
				fx.harvest:Emit(36)
			end
			model:Destroy()
		end
		corals[socketId] = nil
		basePivots[socketId] = nil
		shownStage[socketId] = nil
		popStart[socketId] = nil
	end
	refresh(state, workspace:GetServerTimeNow(), {})
end

function ReefVisuals.Tick(state: PlayerState, now: number, covered: { Rect })
	if not mounted then
		return
	end
	current = state
	refresh(state, now, covered)
end

return ReefVisuals
