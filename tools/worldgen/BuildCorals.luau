--!nonstrict
-- Builds growth-stage coral models into ReplicatedStorage/Assets/Corals/<modelName>/{Bud,Young,Mature}
-- (M3-09, M4-02). Rules: invisible anchored `Root` PrimaryPart at the centre of the base, every part
-- non-collide/query/touch, tip parts tagged `CoralTip`. Re-runnable (replaces existing models).
-- Run in Edit mode: local f = game.ServerStorage.WorldGen:Clone() f.Parent = game.ServerStorage require(f.BuildCorals) f:Destroy()
local Lib = require(script.Parent.Lib)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local R = Lib.R

local assets = ReplicatedStorage:FindFirstChild("Assets")
if assets == nil then
	assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
end
local coralsFolder = assets:FindFirstChild("Corals")
if coralsFolder == nil then
	coralsFolder = Instance.new("Folder")
	coralsFolder.Name = "Corals"
	coralsFolder.Parent = assets
end

local function newStage(species: Folder, name: string): Model
	local old = species:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = Lib.Model(name, species)
	local root = Lib.Decor({
		Name = "Root",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(0, 0, 0),
		Transparency = 1,
		Parent = m,
	})
	m.PrimaryPart = root
	return m
end

local function piece(m: Model, props: { [string]: any }, className: string?): BasePart
	props.Parent = m
	props.CastShadow = true
	return Lib.Decor(props, className)
end

local function tip(part: BasePart)
	Lib.Tag(part, "CoralTip")
	return part
end

local function species(name: string): Folder
	local f = coralsFolder:FindFirstChild(name)
	if f == nil then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = coralsFolder
	end
	return f
end

-- A tilted cylinder from `from` along direction (yaw, tilt) with length; returns the end point
local function limb(m: Model, from: Vector3, yaw: number, tilt: number, length: number, width: number, color: Color3): Vector3
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, tilt)).UpVector
	local mid = from + dir * (length / 2)
	piece(m, {
		Name = "Branch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, width, width),
		CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.pi / 2, 0),
		Color = color,
	})
	return from + dir * length
end

local function ball(m: Model, at: Vector3, size: number, color: Color3, isTip: boolean?): BasePart
	local p = piece(m, {
		Name = if isTip then "Tip" else "Knob",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(at),
		Color = color,
	})
	if isTip then
		tip(p)
	end
	return p
end

------------------------------------------------------------------------------------------------
-- Sun Coral: warm orange rounded branches with pale-yellow ball tips, wide stable base
------------------------------------------------------------------------------------------------
do
	Lib.Seed(301)
	local sp = species("SunCoral")
	local body = Color3.fromRGB(255, 136, 56)
	local bodyDark = Color3.fromRGB(222, 98, 38)
	local tipColor = Color3.fromRGB(255, 236, 140)

	local function base(m: Model, w: number, h: number)
		piece(m, {
			Name = "Base",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(w, h, w),
			CFrame = CFrame.new(0, h * 0.25, 0),
			Color = bodyDark,
		})
	end

	-- Bud ~1.2 studs: mound with three nubs
	local bud = newStage(sp, "Bud")
	base(bud, 1.6, 0.9)
	for i = 1, 3 do
		local yaw = i / 3 * math.pi * 2
		local e = limb(bud, Vector3.new(0, 0.3, 0), yaw, 0.35, 0.6, 0.38, body)
		ball(bud, e, 0.45, tipColor, true)
	end

	-- Young ~2.2 studs: four branches
	local young = newStage(sp, "Young")
	base(young, 2.2, 1.1)
	for i = 1, 4 do
		local yaw = i / 4 * math.pi * 2 + 0.3
		local e = limb(young, Vector3.new(0, 0.4, 0), yaw, R(0.5, 0.7), R(1.3, 1.7), 0.5, body)
		ball(young, e, 0.62, tipColor, true)
	end
	local e = limb(young, Vector3.new(0, 0.4, 0), 0, 0, 1.6, 0.55, body)
	ball(young, e, 0.66, tipColor, true)

	-- Mature ~3.5 studs: trunk, five branches, each forking once
	local mature = newStage(sp, "Mature")
	base(mature, 3, 1.4)
	local trunkTop = limb(mature, Vector3.new(0, 0.4, 0), 0, 0, 1.2, 0.8, body)
	ball(mature, trunkTop, 0.85, body)
	for i = 1, 5 do
		local yaw = i / 5 * math.pi * 2
		local mid = limb(mature, trunkTop, yaw, R(0.75, 0.95), R(1, 1.3), 0.6, body)
		ball(mature, mid, 0.62, body)
		for _, d in { -0.45, 0.45 } do
			local tipPos = limb(mature, mid, yaw + d, R(0.35, 0.55), R(0.8, 1.1), 0.45, body)
			ball(mature, tipPos, 0.62, tipColor, true)
		end
	end
	local top = limb(mature, trunkTop, 0, 0, 1.1, 0.6, body)
	ball(mature, top, 0.75, tipColor, true)
end

------------------------------------------------------------------------------------------------
-- Branch Coral: tall thin forked antlers in hot pink (fast grower)
------------------------------------------------------------------------------------------------
do
	Lib.Seed(302)
	local sp = species("BranchCoral")
	local body = Color3.fromRGB(240, 72, 162)
	local tipColor = Color3.fromRGB(255, 184, 228)

	local function fork(m: Model, from: Vector3, yaw: number, tilt: number, length: number, width: number, depth: number)
		local e = limb(m, from, yaw, tilt, length, width, body)
		if depth <= 0 then
			ball(m, e, width * 1.4, tipColor, true)
			return
		end
		fork(m, e, yaw + 0.75, tilt + 0.12, length * 0.72, width * 0.8, depth - 1)
		fork(m, e, yaw - 0.75, tilt + 0.12, length * 0.72, width * 0.8, depth - 1)
	end

	local function base(m: Model, w: number)
		piece(m, {
			Name = "Base",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, w * 0.75, w * 0.75),
			CFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(200, 50, 130),
		})
	end

	local bud = newStage(sp, "Bud")
	base(bud, 1.2)
	for i = 1, 2 do
		fork(bud, Vector3.new(0, 0.3, 0), i * math.pi, 0.35, 0.8, 0.28, 0)
	end

	local young = newStage(sp, "Young")
	base(young, 1.6)
	for i = 1, 3 do
		fork(young, Vector3.new(0, 0.3, 0), i / 3 * math.pi * 2, 0.35, 1.2, 0.32, 1)
	end

	local mature = newStage(sp, "Mature")
	base(mature, 2)
	for i = 1, 3 do
		fork(mature, Vector3.new(0, 0.3, 0), i / 3 * math.pi * 2 + 0.4, 0.3, 1.6, 0.4, 2)
	end
end

------------------------------------------------------------------------------------------------
-- Brain Coral: low rounded dome with grooves, lime/teal (slow, high value)
------------------------------------------------------------------------------------------------
do
	Lib.Seed(303)
	local sp = species("BrainCoral")
	local body = Color3.fromRGB(156, 222, 96)
	local groove = Color3.fromRGB(70, 160, 130)
	local tipColor = Color3.fromRGB(214, 255, 160)

	local function dome(m: Model, w: number, h: number, ridges: number)
		piece(m, {
			Name = "Dome",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(w, h * 2, w),
			CFrame = CFrame.new(0, h * 0.35, 0),
			Color = body,
		})
		-- Meandering grooves: thin dark strips laid over the dome at varying angles
		for i = 1, ridges do
			local a = i / ridges * math.pi
			local cf = CFrame.new(0, h * 0.35, 0) * CFrame.Angles(0, a, 0)
			piece(m, {
				Name = "Groove",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.12, w * 1.02, h * 2.02),
				CFrame = cf * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(R(-0.05, 0.05), 0, 0),
				Color = groove,
			})
		end
		local cap = ball(m, Vector3.new(0, h * 1.3, 0), w * 0.18, tipColor, true)
		cap.Name = "Crown"
	end

	local bud = newStage(sp, "Bud")
	dome(bud, 1.4, 0.55, 2)
	local young = newStage(sp, "Young")
	dome(young, 2.4, 0.9, 3)
	local mature = newStage(sp, "Mature")
	dome(mature, 3.6, 1.3, 4)
	-- Small satellite domes on the mature colony
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		local p = Vector3.new(math.cos(a) * 1.9, 0.25, math.sin(a) * 1.9)
		piece(mature, {
			Name = "Satellite",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 0.9, 1.1),
			CFrame = CFrame.new(p),
			Color = body:Lerp(groove, 0.25),
		})
	end
end

return "Built corals: SunCoral, BranchCoral, BrainCoral"
