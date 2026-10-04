--!strict
-- Turns socket attributes (server facts) into coral models and countdowns using the same GrowthMath as
-- the server. Stage swaps are scheduled for the exact moment they happen; timers share one 1 Hz loop.
-- No Heartbeat/RenderStepped for growth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local EconomyMath = require(ReplicatedStorage.Shared.Logic.EconomyMath)
local GrowthMath = require(ReplicatedStorage.Shared.Logic.GrowthMath)
local TimeUtil = require(ReplicatedStorage.Shared.Util.TimeUtil)
local Types = require(ReplicatedStorage.Shared.Types)
local PlotLocator = require(script.Parent.Parent.Util.PlotLocator)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)

type SocketVisual = {
	model: Model?,
	visualStage: string?,
	flourishing: boolean?,
	coralId: string?,
	pending: thread?,
	timer: BillboardGui?,
	timerLabel: TextLabel?,
}

local ReefVisualController = {}

local clientFolder: Folder? = nil
local visuals: { [BasePart]: SocketVisual } = {}
local warnedMissing: { [string]: boolean } = {}
local timerLoopRunning = false

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

local function readPlacement(socket: BasePart): Types.Placement?
	local coralId = socket:GetAttribute("CoralId")
	local plantedAt = socket:GetAttribute("PlantedAt")
	local readyAt = socket:GetAttribute("ReadyAt")
	if type(coralId) ~= "string" or type(plantedAt) ~= "number" or type(readyAt) ~= "number" then
		return nil
	end
	return { coralId = coralId, plantedAt = plantedAt, readyAt = readyAt }
end

-- Clones the stage model, or a small coloured placeholder if the asset is missing
local function cloneStageModel(coralId: string, visualStage: string): Model
	local coral = CoralDefinitions[coralId]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local corals = assets and assets:FindFirstChild("Corals")
	local species = corals and coral and corals:FindFirstChild(coral.modelName)
	local template = species and species:FindFirstChild(visualStage)
	if template and template:IsA("Model") then
		return template:Clone()
	end

	if not warnedMissing[coralId] then
		warnedMissing[coralId] = true
		warn(("ReefVisualController: missing model Assets/Corals/%s/%s"):format(coral and coral.modelName or coralId, visualStage))
	end
	local m = Instance.new("Model")
	local p = Instance.new("Part")
	p.Size = Vector3.new(1, 1.5, 1)
	p.Color = Theme.Colors.CoralOrange
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(0, 0.75, 0)
	p.Parent = m
	m.PrimaryPart = p
	return m
end

-- Same rule as the server: a full light + flow match (socket id is its Part name) unlocks Flourishing
local function isConditionMatch(coralId: string, socketId: string): boolean
	local coral = CoralDefinitions[coralId]
	local socket = SocketDefinitions[socketId]
	return coral ~= nil and socket ~= nil and EconomyMath.IsConditionMatch(coral, socket)
end

-- Placeholder Flourishing marker: sparkles rising from the coral (proper VFX in M5-03)
local function addSparkles(model: Model)
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FlourishSparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(150, 255, 220))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1.2, 1.8)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(1.5, 2.5)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 1.5, 0)
	attachment.Parent = root
	emitter.Parent = attachment
end

local function buildTimer(socket: BasePart): (BillboardGui, TextLabel)
	local gui = UIKit.new("BillboardGui", {
		Name = "CoralTimer",
		Size = UDim2.fromOffset(110, 38),
		StudsOffset = Vector3.new(0, 6, 0),
		MaxDistance = 80,
		LightInfluence = 0,
		AlwaysOnTop = false,
		Adornee = socket,
	})
	local pill = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.DeepTeal,
		Parent = gui,
	}, {
		UIKit.corner(Theme.Corner.Pill),
		UIKit.stroke(Theme.Colors.DeepTealDark, 3),
	})
	local label = UIKit.label({
		Name = "Time",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 22,
		Parent = pill,
	})
	gui.Parent = clientFolder
	return gui, label
end

local function updateTimerText(socket: BasePart, visual: SocketVisual)
	local label = visual.timerLabel
	local placement = readPlacement(socket)
	if label == nil or placement == nil then
		return
	end
	local remaining = GrowthMath.GetSecondsRemaining(placement, TimeUtil.Now())
	local pill = label.Parent :: Frame
	if remaining <= 0 then
		local ready = if visual.flourishing then "✨ Ready!" else "Ready!"
		if label.Text ~= ready then
			label.Text = ready
			pill.BackgroundColor3 = Theme.Colors.Seafoam
			-- little bounce to draw the eye
			local gui = visual.timer :: BillboardGui
			gui.Size = UDim2.fromOffset(130, 46)
			TweenService:Create(gui, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(110, 38) }):Play()
		end
	else
		label.Text = formatTime(remaining)
		pill.BackgroundColor3 = Theme.Colors.DeepTeal
	end
end

-- One shared 1 Hz loop for all countdowns; stops when there are none
local function ensureTimerLoop()
	if timerLoopRunning then
		return
	end
	timerLoopRunning = true
	task.spawn(function()
		while true do
			local any = false
			for socket, visual in visuals do
				if visual.timer then
					any = true
					updateTimerText(socket, visual)
				end
			end
			if not any then
				break
			end
			task.wait(1)
		end
		timerLoopRunning = false
	end)
end

local function clearVisual(visual: SocketVisual)
	if visual.pending then
		task.cancel(visual.pending)
		visual.pending = nil
	end
	if visual.model then
		visual.model:Destroy()
		visual.model = nil
	end
	if visual.timer then
		visual.timer:Destroy()
		visual.timer = nil
		visual.timerLabel = nil
	end
	visual.visualStage = nil
	visual.coralId = nil
	visual.flourishing = nil
end

function ReefVisualController.UpdateSocketVisual(socket: BasePart)
	local visual = visuals[socket]
	if visual == nil then
		return
	end
	if visual.pending then
		task.cancel(visual.pending)
		visual.pending = nil
	end

	local placement = readPlacement(socket)
	if placement == nil then
		clearVisual(visual)
		return
	end

	local now = TimeUtil.Now()
	local stage = GrowthMath.GetStage(placement, now, isConditionMatch(placement.coralId, socket.Name))
	local visualStage = GrowthMath.GetVisualStage(stage)
	local flourishing = stage == "Flourishing"

	if visual.visualStage ~= visualStage or visual.coralId ~= placement.coralId or visual.flourishing ~= flourishing then
		local isNew = visual.model == nil or visual.coralId ~= placement.coralId
		if visual.model then
			visual.model:Destroy()
		end
		local model = cloneStageModel(placement.coralId, visualStage)
		model.Name = socket.Name .. "_Coral"
		local target = socket.CFrame * CFrame.new(0, socket.Size.Y / 2, 0)
		model:PivotTo(target)
		model.Parent = clientFolder
		visual.model = model
		visual.visualStage = visualStage
		visual.coralId = placement.coralId
		visual.flourishing = flourishing
		if flourishing then
			addSparkles(model)
		end

		-- Pop-in: start small and grow to full size
		local ok = pcall(function()
			model:ScaleTo(if isNew then 0.3 else 0.8)
		end)
		if ok then
			local scale = Instance.new("NumberValue")
			scale.Value = if isNew then 0.3 else 0.8
			scale.Changed:Connect(function(v)
				if model.Parent then
					model:ScaleTo(v)
					model:PivotTo(target)
				end
			end)
			local tween = TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Value = 1 })
			tween.Completed:Once(function()
				scale:Destroy()
			end)
			tween:Play()
		end
	end

	if visual.timer == nil then
		visual.timer, visual.timerLabel = buildTimer(socket)
	end
	updateTimerText(socket, visual)
	ensureTimerLoop()

	-- Schedule exactly one wake-up for the next stage change
	local nextAt = GrowthMath.GetNextStageChangeAt(placement, now)
	if nextAt then
		visual.pending = task.delay(math.max(0, nextAt - now) + 0.05, function()
			visual.pending = nil
			ReefVisualController.UpdateSocketVisual(socket)
		end)
	end
end

function ReefVisualController.BindSocket(socket: BasePart)
	if visuals[socket] then
		return
	end
	visuals[socket] = {}
	socket.Destroying:Connect(function()
		local visual = visuals[socket]
		if visual then
			clearVisual(visual)
			visuals[socket] = nil
		end
	end)
	for _, attr in { "CoralId", "PlantedAt", "ReadyAt" } do
		socket:GetAttributeChangedSignal(attr):Connect(function()
			ReefVisualController.UpdateSocketVisual(socket)
		end)
	end
	ReefVisualController.UpdateSocketVisual(socket)
end

function ReefVisualController.Init()
	local folder = Instance.new("Folder")
	folder.Name = "ClientCoral"
	folder.Parent = workspace
	clientFolder = folder

	-- Binds by socket Part, so binding another plot's sockets later (visits) needs no changes
	local plot = PlotLocator.WaitForOwnPlot()
	if plot == nil then
		return
	end
	PlotLocator.ObserveSockets(plot, function(_socketId, socket)
		ReefVisualController.BindSocket(socket)
	end)
end

return ReefVisualController
