--!strict

local CollectionService = game:GetService("CollectionService")

local WorldAmbience = {}

local function phaseOf(inst: Instance): number
	local phase = inst:GetAttribute("Phase")
	if typeof(phase) == "number" then
		return phase
	end
	return 0
end

local function swayKelp(now: number)
	for _, inst in CollectionService:GetTagged("ReefKelp") do
		if inst:IsA("BasePart") then
			local base = inst:GetAttribute("BaseCFrame")
			if typeof(base) == "CFrame" then
				local height = inst.Size.Y
				local sway = math.sin(now * 0.85 + phaseOf(inst)) * 0.14
				local bottom = base * CFrame.new(0, -height / 2, 0)
				inst.CFrame = bottom * CFrame.Angles(sway, 0, sway * 0.65) * CFrame.new(0, height / 2, 0)
			end
		end
	end
end

local function slideCurrent(now: number)
	for _, inst in CollectionService:GetTagged("ReefCurrent") do
		if inst:IsA("BasePart") then
			local base = inst:GetAttribute("BaseCFrame")
			if typeof(base) == "CFrame" then
				local slide = math.sin(now * 0.9 + phaseOf(inst)) * 2.4
				inst.CFrame = base * CFrame.new(0, 0, slide)
			end
		end
	end
end

local function riseBubbles(now: number)
	for _, inst in CollectionService:GetTagged("ReefBubble") do
		if inst:IsA("BasePart") then
			local base = inst:GetAttribute("BasePosition")
			local speed = inst:GetAttribute("Speed")
			local height = inst:GetAttribute("Height")
			if typeof(base) == "Vector3" and typeof(speed) == "number" and typeof(height) == "number" then
				local cycle = (now * speed + phaseOf(inst)) % 1
				inst.Position = base + Vector3.new(0, cycle * height, 0)
				inst.Transparency = 0.28 + cycle * 0.65
				local size = 0.28 + cycle * 0.45
				inst.Size = Vector3.new(size, size, size)
			end
		end
	end
end

local function swimFish(now: number)
	for _, inst in CollectionService:GetTagged("ReefFish") do
		if inst:IsA("Model") then
			local center = inst:GetAttribute("Center")
			local radius = inst:GetAttribute("Radius")
			local height = inst:GetAttribute("Height")
			local speed = inst:GetAttribute("Speed")
			if typeof(center) ~= "Vector3" or typeof(radius) ~= "number" or typeof(height) ~= "number" or typeof(speed) ~= "number" then
				continue
			end
			local phase = phaseOf(inst)
			local angle = now * speed + phase
			local bob = math.sin(now * 2 + phase) * 0.35
			local position = Vector3.new(center.X + math.cos(angle) * radius, center.Y + height + bob, center.Z + math.sin(angle) * radius)
			local ahead = Vector3.new(
				center.X + math.cos(angle + 0.08) * radius,
				position.Y,
				center.Z + math.sin(angle + 0.08) * radius
			)
			if (ahead - position).Magnitude > 0.05 then
				inst:PivotTo(CFrame.lookAt(position, ahead))
			end
		end
	end
end

local function flickerCaustics(now: number)
	for _, inst in CollectionService:GetTagged("ReefCaustic") do
		local light = inst:FindFirstChildOfClass("PointLight")
		if light then
			local wave = math.sin(now * 1.4 + phaseOf(inst)) * 0.5 + 0.5
			light.Brightness = 0.25 + wave * 0.55
		end
	end
end

function WorldAmbience.Tick()
	local now = os.clock()
	swayKelp(now)
	slideCurrent(now)
	riseBubbles(now)
	swimFish(now)
	flickerCaustics(now)
end

return WorldAmbience
