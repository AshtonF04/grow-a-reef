--!nonstrict
-- Shared low-poly building helpers for the worldgen scripts.
-- Rojo syncs them to ServerStorage.WorldGen (never runs on its own, never replicates). Run in Edit mode via the command bar or MCP
-- execute_luau; they build Studio-only content listed in assets/manifest.md.
-- Style: chunky SmoothPlastic parts, random rotations for faceted "low poly" rocks, saturated flat colours.

local CollectionService = game:GetService("CollectionService")

local Lib = {}

Lib.Palette = {
	Sand = Color3.fromRGB(234, 204, 146),
	SandDark = Color3.fromRGB(222, 190, 130),
	SandLight = Color3.fromRGB(246, 226, 182),
	Rocks = {
		Color3.fromRGB(190, 146, 104), -- sandstone
		Color3.fromRGB(170, 110, 86), -- terracotta
		Color3.fromRGB(140, 122, 110), -- warm grey
		Color3.fromRGB(122, 104, 128), -- dusky purple
	},
	Kelp = {
		Color3.fromRGB(70, 168, 86),
		Color3.fromRGB(48, 134, 72),
		Color3.fromRGB(116, 196, 92),
	},
	Corals = {
		Color3.fromRGB(255, 118, 160),
		Color3.fromRGB(172, 112, 226),
		Color3.fromRGB(255, 208, 86),
		Color3.fromRGB(88, 212, 222),
		Color3.fromRGB(255, 140, 90),
	},
	Wood = Color3.fromRGB(150, 104, 66),
	WoodDark = Color3.fromRGB(110, 74, 46),
	Seafoam = Color3.fromRGB(88, 214, 165),
	DeepTeal = Color3.fromRGB(14, 74, 92),
}

local rng = Random.new(1)

function Lib.Seed(seed: number)
	rng = Random.new(seed)
end

function Lib.R(min: number, max: number): number
	return rng:NextNumber(min, max)
end

function Lib.Pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

function Lib.Part(props: { [string]: any }, className: string?): BasePart
	local p = Instance.new(className or "Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- Non-collidable decoration (never blocks players or tap raycasts)
function Lib.Decor(props: { [string]: any }, className: string?): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return Lib.Part(props, className)
end

function Lib.Model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Lib.Tag(inst: Instance, tag: string)
	CollectionService:AddTag(inst, tag)
end

local function randomRot(): CFrame
	return CFrame.Angles(Lib.R(-0.5, 0.5), Lib.R(0, math.pi * 2), Lib.R(-0.5, 0.5))
end

-- Faceted boulder: a few randomly rotated blocks/wedges overlapping, partially buried
function Lib.Rock(parent: Instance, position: Vector3, size: number, color: Color3?, collide: boolean?): Model
	local m = Lib.Model("Rock", parent)
	local base = color or Lib.Pick(Lib.Palette.Rocks)
	local chunks = math.clamp(math.floor(size / 2.5), 2, 5)
	for i = 1, chunks do
		local s = size * Lib.R(0.55, 1)
		local offset = if i == 1
			then Vector3.zero
			else Vector3.new(Lib.R(-0.45, 0.45) * size, Lib.R(-0.2, 0.25) * size, Lib.R(-0.45, 0.45) * size)
		local h, s2, v = base:ToHSV()
		local props = {
			Name = "Chunk",
			Size = Vector3.new(s, s * Lib.R(0.6, 0.95), s * Lib.R(0.7, 1)),
			CFrame = CFrame.new(position + offset) * randomRot(),
			Color = Color3.fromHSV(h, s2, math.clamp(v * Lib.R(0.88, 1.1), 0, 1)),
			CanCollide = collide ~= false,
			Parent = m,
		}
		Lib.Part(props, if i % 3 == 0 then "WedgePart" else "Part")
	end
	return m
end

-- Kelp: a twisting ribbon of leaf segments on a thin stem. Tagged "Kelp" for client sway.
function Lib.Kelp(parent: Instance, position: Vector3, height: number): Model
	local m = Lib.Model("Kelp", parent)
	local color = Lib.Pick(Lib.Palette.Kelp)
	local segments = math.max(2, math.floor(height / 2.4))
	local root = Lib.Decor({
		Name = "Root",
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = CFrame.new(position),
		Transparency = 1,
		Parent = m,
	})
	m.PrimaryPart = root
	local twist = Lib.R(0, math.pi * 2)
	local lean = Lib.R(-0.06, 0.06)
	for i = 1, segments do
		local y = (i - 0.5) * 2.4
		local h, s, v = color:ToHSV()
		Lib.Decor({
			Name = "Leaf",
			Size = Vector3.new(0.35, 2.7, 1.5 - i * 0.04),
			CFrame = CFrame.new(position + Vector3.new(lean * y * 2, y, 0))
				* CFrame.Angles(0, twist + i * 0.7, lean),
			Color = Color3.fromHSV(h, s, math.clamp(v * (0.85 + i * 0.03), 0, 1)),
			Parent = m,
		})
	end
	Lib.Tag(m, "Kelp")
	return m
end

-- Tube coral cluster (static decoration, not a growable coral)
function Lib.TubeCoral(parent: Instance, position: Vector3, scale: number?): Model
	local k = scale or 1
	local m = Lib.Model("TubeCoral", parent)
	local color = Lib.Pick(Lib.Palette.Corals)
	local h, s, v = color:ToHSV()
	for _ = 1, 5 do
		local height = Lib.R(1.5, 4) * k
		local width = Lib.R(0.8, 1.3) * k
		local pos = position + Vector3.new(Lib.R(-1.3, 1.3) * k, height / 2, Lib.R(-1.3, 1.3) * k)
		local cf = CFrame.new(pos) * CFrame.Angles(Lib.R(-0.25, 0.25), 0, Lib.R(-0.25, 0.25))
		Lib.Decor({
			Name = "Tube",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, width, width),
			CFrame = cf * CFrame.Angles(0, 0, math.pi / 2),
			Color = color,
			Parent = m,
		})
		Lib.Decor({
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, width * 1.08, width * 1.08),
			CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromHSV(h, s * 0.6, math.min(1, v * 1.15)),
			Parent = m,
		})
	end
	return m
end

-- Fan coral: a flat, wavy fan on a short stalk
function Lib.FanCoral(parent: Instance, position: Vector3, scale: number?): Model
	local k = scale or 1
	local m = Lib.Model("FanCoral", parent)
	local color = Lib.Pick(Lib.Palette.Corals)
	local yaw = Lib.R(0, math.pi * 2)
	for i = 1, 6 do
		local a = (i - 3.5) * 0.32
		Lib.Decor({
			Name = "Blade",
			Size = Vector3.new(1.4 * k, 4.2 * k, 0.25),
			CFrame = CFrame.new(position)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(0, 0, a)
				* CFrame.new(0, 2.1 * k, 0),
			Color = color,
			Parent = m,
		})
	end
	return m
end

-- Anemone: squat base with a crown of balls
function Lib.Anemone(parent: Instance, position: Vector3): Model
	local m = Lib.Model("Anemone", parent)
	local color = Lib.Pick(Lib.Palette.Corals)
	Lib.Decor({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(240, 230, 220),
		Parent = m,
	})
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		Lib.Decor({
			Name = "Tip",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 0.6, 1.2 + Lib.R(0, 0.3), math.sin(a) * 0.6)),
			Color = color,
			Material = Enum.Material.Neon,
			Parent = m,
		})
	end
	return m
end

function Lib.Starfish(parent: Instance, position: Vector3): Model
	local m = Lib.Model("Starfish", parent)
	local color = Lib.Pick({ Color3.fromRGB(255, 120, 70), Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 190, 70) })
	local yaw = Lib.R(0, math.pi * 2)
	for i = 1, 5 do
		Lib.Decor({
			Name = "Arm",
			Size = Vector3.new(0.5, 0.25, 1.3),
			CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0))
				* CFrame.Angles(0, yaw + i / 5 * math.pi * 2, 0)
				* CFrame.new(0, 0, -0.6),
			Color = color,
			Parent = m,
		}, "WedgePart")
	end
	return m
end

function Lib.Seashell(parent: Instance, position: Vector3): BasePart
	return Lib.Decor({
		Name = "Seashell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.45, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, Lib.R(0, 6), 0),
		Color = Lib.Pick({ Color3.fromRGB(255, 230, 220), Color3.fromRGB(255, 200, 190), Color3.fromRGB(240, 220, 255) }),
		Parent = parent,
	})
end

-- Patch of short sea grass blades
function Lib.SeaGrass(parent: Instance, position: Vector3, radius: number)
	local m = Lib.Model("SeaGrass", parent)
	for _ = 1, 10 do
		local p = position + Vector3.new(Lib.R(-radius, radius), 0, Lib.R(-radius, radius))
		local h = Lib.R(0.8, 2)
		Lib.Decor({
			Name = "Blade",
			Size = Vector3.new(0.2, h, 0.5),
			CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(Lib.R(-0.3, 0.3), Lib.R(0, 6), Lib.R(-0.3, 0.3)),
			Color = Lib.Pick(Lib.Palette.Kelp),
			CastShadow = false,
			Parent = m,
		}, "WedgePart")
	end
	return m
end

-- Rising bubble stream from a small vent rock
function Lib.BubbleVent(parent: Instance, position: Vector3)
	local rock = Lib.Rock(parent, position, 2.2)
	local emitterPart = Lib.Decor({
		Name = "BubbleSource",
		Size = Vector3.new(1, 0.2, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 1, 0)),
		Transparency = 1,
		Parent = rock,
	})
	local e = Instance.new("ParticleEmitter")
	e.Name = "Bubbles"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
	e.LightEmission = 0.4
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(4, 6)
	e.Rate = 4
	e.Speed = NumberRange.new(3, 5)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Acceleration = Vector3.new(0, 1, 0)
	e.Parent = emitterPart
	return rock
end

-- Wooden signpost with a SurfaceGui label on both faces
function Lib.Sign(parent: Instance, cf: CFrame, text: string, width: number?, name: string?): Model
	local w = width or 8
	local m = Lib.Model(name or "Sign", parent)
	for _, x in { -w / 2 + 0.6, w / 2 - 0.6 } do
		Lib.Part({
			Name = "Post",
			Size = Vector3.new(0.6, 5, 0.6),
			CFrame = cf * CFrame.new(x, 2.5, 0),
			Color = Lib.Palette.WoodDark,
			Parent = m,
		})
	end
	local board = Lib.Part({
		Name = "Board",
		Size = Vector3.new(w, 2.4, 0.5),
		CFrame = cf * CFrame.new(0, 4.4, 0),
		Color = Lib.Palette.Wood,
		Parent = m,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Label" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.2
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = text
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		label.TextColor3 = Color3.fromRGB(255, 248, 230)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(70, 44, 24)
		stroke.Parent = label
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = label
		label.Parent = gui
		gui.Parent = board
	end
	m.PrimaryPart = board
	return m
end

return Lib
