--!strict

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local SocketLayout = require(ReplicatedStorage.Shared.Config.SocketLayout)

local WorldService = {}

local function smooth(part: BasePart)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function invisibleAnchor(parent: Instance, position: Vector3, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	smooth(part)
	part.Position = position
	part.Parent = parent
	return part
end

local function applyLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.Ambient = Color3.fromRGB(64, 89, 97)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 140, 148)
	Lighting.Brightness = 2.4
	Lighting.ClockTime = 13.2
	Lighting.GeographicLatitude = 8
	Lighting.GlobalShadows = true
	Lighting.Outlines = false
	Lighting.FogColor = Color3.fromRGB(140, 189, 199)
	Lighting.FogStart = 45
	Lighting.FogEnd = 320
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.ExposureCompensation = -0.1

	if not Lighting:FindFirstChild("ReefAtmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "ReefAtmosphere"
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.18
		atmosphere.Color = Color3.fromRGB(168, 214, 214)
		atmosphere.Decay = Color3.fromRGB(92, 140, 150)
		atmosphere.Glare = 0.12
		atmosphere.Haze = 2.1
		atmosphere.Parent = Lighting
	end

	if not Lighting:FindFirstChild("ReefBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "ReefBloom"
		bloom.Intensity = 0.35
		bloom.Size = 22
		bloom.Threshold = 1.15
		bloom.Parent = Lighting
	end

	if not Lighting:FindFirstChild("ReefColor") then
		local color = Instance.new("ColorCorrectionEffect")
		color.Name = "ReefColor"
		color.Saturation = 0.12
		color.Contrast = 0.06
		color.TintColor = Color3.fromRGB(214, 236, 232)
		color.Parent = Lighting
	end

	if not Lighting:FindFirstChild("ReefSun") then
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "ReefSun"
		rays.Intensity = 0.07
		rays.Spread = 0.7
		rays.Parent = Lighting
	end
end

local function buildPlaque(parent: Instance)
	local plaque = Instance.new("Part")
	plaque.Name = "Plaque"
	plaque.Size = Vector3.new(10, 6, 0.45)
	plaque.Color = Color3.fromRGB(28, 48, 52)
	plaque.Material = Enum.Material.Slate
	smooth(plaque)
	plaque.CFrame = CFrame.lookAt(Vector3.new(-15, 4, 9), Vector3.new(-15, 4, 22))
	plaque.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 42
	gui.LightInfluence = 0
	gui.Parent = plaque

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 40, 48)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = frame

	local function line(text: string, textSize: number, font: Enum.Font, color: Color3, height: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, height)
		label.Font = font
		label.TextSize = textSize
		label.TextColor3 = color
		label.TextWrapped = true
		label.Text = text
		label.Parent = frame
	end

	line("GROW A REEF", 48, Fonts.Bold, Color3.fromRGB(240, 248, 244), 56)
	line(
		"Plant a fragment. Harvest shells. Open new spots and buy the coral that flourishes there.",
		22,
		Fonts.Body,
		Color3.fromRGB(186, 214, 208),
		70
	)
end

local function buildFish(parent: Instance, color: Color3, center: Vector3, radius: number, height: number, speed: number, phase: number)
	local model = Instance.new("Model")
	model.Name = "Fish"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(0.85, 0.62, 2.1)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	smooth(body)
	body.Parent = model
	model.PrimaryPart = body

	local tail = Instance.new("WedgePart")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.7, 0.62, 0.85)
	tail.Color = color:Lerp(Color3.new(0, 0, 0), 0.25)
	tail.Material = Enum.Material.SmoothPlastic
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CanTouch = false
	smooth(tail)
	tail.CFrame = CFrame.new(0, 0, 1.2)
	tail.Parent = model

	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Shape = Enum.PartType.Ball
	eye.Size = Vector3.new(0.16, 0.16, 0.16)
	eye.Color = Color3.fromRGB(20, 24, 28)
	eye.Material = Enum.Material.SmoothPlastic
	eye.CanCollide = false
	eye.CanQuery = false
	eye.CanTouch = false
	smooth(eye)
	eye.CFrame = CFrame.new(0.22, 0.12, -0.72)
	eye.Parent = model

	model:SetAttribute("Center", center)
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Height", height)
	model:SetAttribute("Speed", speed)
	model:SetAttribute("Phase", phase)
	model.Parent = parent
	model:PivotTo(CFrame.new(center + Vector3.new(radius, height, 0)))
	CollectionService:AddTag(model, "ReefFish")
end

function WorldService.Build()
	if workspace:FindFirstChild("ReefWorld") then
		return
	end

	local lit, lightError = pcall(applyLighting)
	if not lit then
		warn("[reef] lighting skipped", lightError)
	end

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Color3.fromRGB(46, 72, 74)
		baseplate.Material = Enum.Material.Slate
	end

	local world = Instance.new("Folder")
	world.Name = "ReefWorld"
	world.Parent = workspace

	local plots = Instance.new("Folder")
	plots.Name = "ReefPlots"
	plots.Parent = workspace

	local water = Instance.new("Part")
	water.Name = "Surface"
	water.Size = Vector3.new(220, 1, 220)
	water.Color = Color3.fromRGB(62, 138, 150)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.62
	water.Reflectance = 0.08
	water.CanCollide = false
	water.CanQuery = false
	water.CanTouch = false
	water.CastShadow = false
	smooth(water)
	water.CFrame = CFrame.new(0, 15, -8)
	water.Parent = world

	local sandy = SocketLayout.sockets.sandy_patch
	local sandyWorld = SocketLayout.plotPivot * Vector3.new(sandy.offset.X, 0, sandy.offset.Z)
	local lamp = invisibleAnchor(world, Vector3.new(sandyWorld.X, 22, sandyWorld.Z), "SunShaft")
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 48
	spot.Brightness = 3
	spot.Range = 42
	spot.Color = Color3.fromRGB(255, 236, 210)
	spot.Parent = lamp

	for index = 1, 4 do
		local anchor = invisibleAnchor(world, Vector3.new(-12 + index * 8, 8, -6 - index * 4), "Caustic")
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(180, 230, 220)
		light.Brightness = 0.6
		light.Range = 18
		light.Parent = anchor
		anchor:SetAttribute("Phase", index * 1.3)
		CollectionService:AddTag(anchor, "ReefCaustic")
	end

	for index = 1, 14 do
		local angle = index * 0.72
		local radius = 8 + (index % 5) * 3.1
		local bubble = Instance.new("Part")
		bubble.Name = "Bubble"
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.new(0.45, 0.45, 0.45)
		bubble.Color = Color3.fromRGB(210, 236, 238)
		bubble.Material = Enum.Material.Glass
		bubble.Transparency = 0.35
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.CanTouch = false
		bubble.CastShadow = false
		smooth(bubble)
		bubble.Position = Vector3.new(math.cos(angle) * radius, 2, -16 + math.sin(angle) * radius)
		bubble:SetAttribute("BasePosition", bubble.Position)
		bubble:SetAttribute("Phase", index * 0.45)
		bubble:SetAttribute("Speed", 0.11 + (index % 3) * 0.035)
		bubble:SetAttribute("Height", 8 + (index % 4) * 1.4)
		bubble.Parent = world
		CollectionService:AddTag(bubble, "ReefBubble")
	end

	local reefCenter = SocketLayout.plotPivot.Position
	buildFish(world, Color3.fromRGB(255, 148, 72), reefCenter, 14, 7.2, 0.42, 0)
	buildFish(world, Color3.fromRGB(86, 168, 186), reefCenter, 20, 9.1, 0.27, 2.1)
	buildFish(world, Color3.fromRGB(232, 206, 92), reefCenter, 11, 6.2, 0.55, 4.2)

	buildPlaque(world)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ReefSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Color = Color3.fromRGB(196, 174, 124)
	spawn.Material = Enum.Material.Sand
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	smooth(spawn)
	spawn.CFrame = CFrame.new(0, 1, 18)
	spawn.Parent = workspace
end

return WorldService
