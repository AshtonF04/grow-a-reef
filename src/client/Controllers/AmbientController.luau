--!strict
-- Cosmetic underwater life, client-only: kelp sway (models tagged "Kelp") and schools of low-poly fish.
-- One shared 20 Hz loop; kelp only animates near the camera so cost stays flat as the map grows.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local AmbientController = {}

local UPDATE_INTERVAL = 1 / 20
local KELP_RANGE = 140
local FISH_COUNT = 18

type KelpEntry = { model: Model, parts: { BasePart }, base: { CFrame }, pivot: CFrame, phase: number, amp: number }
type Fish = { model: Model, centre: Vector3, radius: number, height: number, speed: number, angle: number, bob: number }

local kelps: { KelpEntry } = {}
local fishes: { Fish } = {}

local FISH_COLORS = {
	{ Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 255, 255) }, -- clownfish
	{ Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 230, 80) }, -- blue tang
	{ Color3.fromRGB(255, 220, 70), Color3.fromRGB(40, 40, 60) }, -- yellow
	{ Color3.fromRGB(255, 110, 150), Color3.fromRGB(255, 220, 230) }, -- pink
}

local function addKelp(model: Instance)
	if not model:IsA("Model") or model.PrimaryPart == nil then
		return
	end
	local parts, base = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= model.PrimaryPart then
			table.insert(parts, d)
			table.insert(base, d.CFrame)
		end
	end
	local pivot = (model.PrimaryPart :: BasePart).CFrame
	table.insert(kelps, { model = model, parts = parts, base = base, pivot = pivot, phase = math.random() * math.pi * 2, amp = 0.05 + math.random() * 0.04 })
end

local function part(props: { [string]: any }, className: string?): BasePart
	local p = Instance.new(className or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function makeFish(parent: Instance): Model
	local colors = FISH_COLORS[math.random(1, #FISH_COLORS)]
	local s = 0.8 + math.random() * 0.8
	local m = Instance.new("Model")
	m.Name = "Fish"
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.3, 2) * s, Color = colors[1] })
	body.Parent = m
	m.PrimaryPart = body
	part({ Name = "Stripe", Size = Vector3.new(1.15, 1.1, 0.3) * s, CFrame = CFrame.new(0, 0, -0.2 * s), Color = colors[2] }).Parent = m
	part({ Name = "Tail", Size = Vector3.new(0.2, 1.1, 0.9) * s, CFrame = CFrame.new(0, 0, 1.2 * s) * CFrame.Angles(0, math.pi, 0), Color = colors[1] }, "WedgePart").Parent = m
	for _, x in { -0.5, 0.5 } do
		part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3) * s, CFrame = CFrame.new(x * s, 0.2 * s, -0.7 * s), Color = Color3.fromRGB(20, 20, 30) }).Parent = m
	end
	m.Parent = parent
	return m
end

local function spawnFish(folder: Folder)
	local plots = workspace:FindFirstChild("PlayerPlots")
	local centres = { Vector3.zero }
	if plots then
		for _, plot in plots:GetChildren() do
			if plot:IsA("Model") then
				table.insert(centres, plot:GetPivot().Position)
			end
		end
	end
	for i = 1, FISH_COUNT do
		local centre = centres[(i % #centres) + 1]
		table.insert(fishes, {
			model = makeFish(folder),
			centre = centre + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20)),
			radius = 10 + math.random() * 25,
			height = 9 + math.random() * 16,
			speed = (0.15 + math.random() * 0.2) * (if math.random() < 0.5 then -1 else 1),
			angle = math.random() * math.pi * 2,
			bob = math.random() * math.pi * 2,
		})
	end
end

local function step(t: number, dt: number)
	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero

	-- Kelp sway: rotate each leaf around the kelp's root
	local movedParts, movedCFrames = {}, {}
	for _, k in kelps do
		if (k.pivot.Position - camPos).Magnitude < KELP_RANGE and k.model.Parent then
			local sway = CFrame.Angles(math.sin(t * 1.1 + k.phase) * k.amp, 0, math.cos(t * 0.8 + k.phase) * k.amp)
			local rotated = k.pivot * sway * k.pivot:Inverse()
			for i, p in k.parts do
				if p.Parent then -- skip leaves that streamed out
					table.insert(movedParts, p)
					table.insert(movedCFrames, rotated * k.base[i])
				end
			end
		end
	end
	if #movedParts > 0 then
		workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- Fish: lazy circles with a gentle bob, facing their direction of travel
	for _, f in fishes do
		f.angle += f.speed * dt
		local pos = f.centre + Vector3.new(math.cos(f.angle) * f.radius, f.height + math.sin(t + f.bob) * 1.2, math.sin(f.angle) * f.radius)
		local ahead = f.centre + Vector3.new(math.cos(f.angle + 0.05 * math.sign(f.speed)) * f.radius, f.height, math.sin(f.angle + 0.05 * math.sign(f.speed)) * f.radius)
		local wiggle = CFrame.Angles(0, math.sin(t * 8 + f.bob) * 0.15, 0)
		f.model:PivotTo(CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z)) * wiggle)
	end
end

function AmbientController.Init()
	for _, k in CollectionService:GetTagged("Kelp") do
		addKelp(k)
	end
	CollectionService:GetInstanceAddedSignal("Kelp"):Connect(addKelp)

	local folder = Instance.new("Folder")
	folder.Name = "ClientAmbient"
	folder.Parent = workspace
	spawnFish(folder)

	local accumulator = 0
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		t += dt
		if accumulator >= UPDATE_INTERVAL then
			step(t, accumulator)
			accumulator = 0
		end
	end)
end

return AmbientController
