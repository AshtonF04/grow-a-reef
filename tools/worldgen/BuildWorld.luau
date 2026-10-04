--!nonstrict
-- Builds the whole underwater map: seafloor, hub, boundary, and the 6 player plots (M2-01).
-- Re-runnable: destroys and rebuilds Workspace.World and Workspace.PlayerPlots.
-- Run in Edit mode from the command bar: local f = game.ServerStorage.WorldGen:Clone() f.Parent = game.ServerStorage require(f.BuildWorld) f:Destroy()
-- Needs the AI mesh templates in ServerStorage/WorldAssets (imported with ImportMesh.luau, see assets/manifest.md).
local Lib = require(script.Parent.Lib)
local SocketDefinitions = require(game:GetService("ReplicatedStorage").Shared.Config.SocketDefinitions)

assert(game:GetService("ServerStorage"):FindFirstChild("WorldAssets"), "BuildWorld: ServerStorage.WorldAssets is missing")

local P = Lib.Palette
local R = Lib.R

local PLOT_COUNT = 6
local RING_RADIUS = 130 -- distance from hub centre to each plot centre (adjacent plots ~130 studs apart)
local PLOT_SIZE = 64
local BASE_HEIGHT = 2
local FLOOR_SIZE = 640
local BOUNDARY_RADIUS = 250

-- Socket layout in plot-local space. -Z faces the hub (entrance). Bright side is the open left (x < 0);
-- dim side is the right (x > 0), under a rock overhang and kelp.
local SOCKET_LAYOUT = {
	sandy_patch = { pos = Vector3.new(-13, 0, -8) },
	sun_ledge = { pos = Vector3.new(-21, 2.5, 9), ledge = true },
	surge_channel = { pos = Vector3.new(-6, 0, 19), channel = true },
	kelp_shade = { pos = Vector3.new(11, 0, -6), kelp = true },
	rock_crevice = { pos = Vector3.new(21, 0, 9), crevice = true },
	deep_nook = { pos = Vector3.new(9, 0, 21) },
}


------------------------------------------------------------------------------------------------
-- Clean up previous builds and prototype leftovers
------------------------------------------------------------------------------------------------
for _, name in { "World", "PlayerPlots", "Baseplate", "SpawnLocation", "NeonBluePart" } do
	local existing = workspace:FindFirstChild(name)
	while existing do
		existing:Destroy()
		existing = workspace:FindFirstChild(name)
	end
end

local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace

------------------------------------------------------------------------------------------------
-- Seafloor
------------------------------------------------------------------------------------------------
Lib.Seed(7)
local floor = Instance.new("Folder")
floor.Name = "Seafloor"
floor.Parent = world

Lib.Part({
	Name = "Ground",
	Size = Vector3.new(FLOOR_SIZE, 10, FLOOR_SIZE),
	CFrame = CFrame.new(0, -5, 0),
	Color = P.Sand,
	Parent = floor,
})

-- Scattered floor decoration (between plots, away from the hub and plot footprints)
local plotCentres = {}
for i = 1, PLOT_COUNT do
	local a = (i - 1) / PLOT_COUNT * math.pi * 2
	plotCentres[i] = Vector3.new(math.cos(a) * RING_RADIUS, 0, math.sin(a) * RING_RADIUS)
end

local function clearOfPlots(pos: Vector3, margin: number): boolean
	if pos.Magnitude < 36 + margin then
		return false
	end
	for _, c in plotCentres do
		local d = pos - c
		if math.abs(d.X) < PLOT_SIZE / 2 + 10 + margin and math.abs(d.Z) < PLOT_SIZE / 2 + 10 + margin then
			return false
		end
	end
	return true
end

local function randomFloorPoint(margin: number): Vector3
	for _ = 1, 50 do
		local r = R(30, BOUNDARY_RADIUS - 15)
		local a = R(0, math.pi * 2)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if clearOfPlots(p, margin) then
			return p
		end
	end
	return Vector3.new(0, 0, 60)
end

local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = world
for _ = 1, 45 do
	Lib.Rock(decor, randomFloorPoint(4), R(3, 8))
end
for _ = 1, 40 do
	Lib.Kelp(decor, randomFloorPoint(2), R(8, 20))
end
for _ = 1, 30 do
	Lib.TubeCoral(decor, randomFloorPoint(2), R(0.8, 1.6))
end
for _ = 1, 22 do
	Lib.FanCoral(decor, randomFloorPoint(2), R(0.8, 1.5))
end
for _ = 1, 25 do
	Lib.Anemone(decor, randomFloorPoint(1))
end
for _ = 1, 40 do
	Lib.Starfish(decor, randomFloorPoint(1))
end
for _ = 1, 50 do
	Lib.Seashell(decor, randomFloorPoint(1))
end
for _ = 1, 35 do
	Lib.SeaGrass(decor, randomFloorPoint(2), R(2, 4))
end
for _ = 1, 10 do
	Lib.BubbleVent(decor, randomFloorPoint(3))
end

------------------------------------------------------------------------------------------------
-- Boundary: a ring of tall rock spires and a kelp forest
------------------------------------------------------------------------------------------------
Lib.Seed(11)
local boundary = Instance.new("Folder")
boundary.Name = "Boundary"
boundary.Parent = world
for i = 1, 70 do
	local a = i / 70 * math.pi * 2 + R(-0.03, 0.03)
	local r = BOUNDARY_RADIUS + R(-6, 10)
	local base = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local spire = Lib.Mesh("RockSpire", boundary, Lib.Jitter(base - Vector3.new(0, 2, 0), 0.06), R(28, 48), true) :: Model
	spire.Name = "Spire"
	-- A couple of boulders round the foot so it doesn't look stuck into the sand
	for _ = 1, 2 do
		local footAngle = R(0, math.pi * 2)
		Lib.Rock(spire, base + Vector3.new(math.cos(footAngle) * 9, 2, math.sin(footAngle) * 9), R(5, 9))
	end
	if i % 2 == 0 then
		Lib.Kelp(boundary, base + Vector3.new(-math.cos(a) * 14, 0, -math.sin(a) * 14), R(20, 34))
	end
end
-- Invisible wall so nobody wanders off the map
for i = 1, 36 do
	local a = i / 36 * math.pi * 2
	local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * (BOUNDARY_RADIUS - 4)
	Lib.Part({
		Name = "InvisibleWall",
		Size = Vector3.new(48, 120, 2),
		CFrame = CFrame.lookAt(pos + Vector3.new(0, 60, 0), Vector3.new(0, 60, 0)),
		Transparency = 1,
		CastShadow = false,
		Parent = boundary,
	})
end

------------------------------------------------------------------------------------------------
-- Hub: sand plaza, rock arch, giant clam with a glowing pearl, welcome sign
------------------------------------------------------------------------------------------------
Lib.Seed(21)
local hub = Instance.new("Folder")
hub.Name = "Hub"
hub.Parent = world

Lib.Part({
	Name = "Plaza",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(1, 56, 56),
	CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
	Color = P.SandLight,
	Parent = hub,
})
-- Ring of stepping stones around the plaza
for i = 1, 24 do
	local a = i / 24 * math.pi * 2
	local stone = Lib.Mesh("SteppingStone", hub, CFrame.new(math.cos(a) * 30, -0.15, math.sin(a) * 30) * CFrame.Angles(0, -a + R(-0.2, 0.2), 0), 1, true) :: Model
	stone.Name = "Stone"
end

-- Giant clam: mesh opens toward -Z with its inner floor at 0.76 of 7 studs; the pearl sits in that cradle
local CLAM_HEIGHT = 14
local clam = Lib.Mesh("GiantClam", hub, CFrame.new(0, -0.3, 0), CLAM_HEIGHT, true) :: Model
local clamScale = CLAM_HEIGHT / 7
local pearl = Lib.Part({
	Name = "Pearl",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 2.2 * clamScale,
	CFrame = CFrame.new(0, -0.3 + (0.76 + 1.1) * clamScale, -0.3 * clamScale),
	Color = Color3.fromRGB(255, 250, 240),
	Material = Enum.Material.Neon,
	Parent = clam,
})
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(200, 240, 255)
glow.Range = 22
glow.Brightness = 1.5
glow.Parent = pearl

-- Rock arch over the north entrance of the plaza. The mesh is decor; invisible boxes give its legs collision
-- (mesh collision would risk filling the walkway).
local ARCH_HEIGHT = 20
local arch = Lib.Mesh("RockArch", hub, CFrame.new(0, -0.5, -26), ARCH_HEIGHT) :: Model
arch.Name = "Arch"
local archScale = ARCH_HEIGHT / 8.85
for _, side in { -1, 1 } do
	Lib.Part({
		Name = "LegCollider",
		Size = Vector3.new(3 * archScale, ARCH_HEIGHT * 0.8, 4 * archScale),
		CFrame = CFrame.new(side * (10.19 / 2 - 1.5) * archScale, ARCH_HEIGHT * 0.4, -26),
		Transparency = 1,
		CastShadow = false,
		Parent = arch,
	})
end
Lib.Kelp(arch, Vector3.new(-15, 0, -24), 16)
Lib.Kelp(arch, Vector3.new(15, 0, -28), 18)

Lib.Sign(hub, CFrame.new(0, 0, 16) * CFrame.Angles(0, math.pi, 0), "Grow A Reef 🐠", 14, "WelcomeSign")

-- Shop stall on the plaza edge, between two plot paths (150°), its counter facing the clam.
-- ShopStall template (yaw 0, 9 tall): counter block x ±3.5, z ±1.8, top at y≈3; awning roof to z ±2.6.
-- The crab shopkeeper stands behind the counter (+Z). ShopCounter (tagged) is what the client prompt and the
-- server's SHOP_RANGE check use; workspace.World's ShopTeleport attribute is where the HUD Shop button lands.
local SHOP_ANGLE = math.rad(150)
local SHOP_POS = Vector3.new(math.cos(SHOP_ANGLE), 0, math.sin(SHOP_ANGLE)) * 22 + Vector3.new(0, 0.8, 0)
local SHOP_CF = CFrame.lookAt(SHOP_POS, Vector3.new(0, SHOP_POS.Y, 0))
local shop = Lib.Model("ShopStall", hub)
Lib.Mesh("ShopStall", shop, SHOP_CF, 9, true)
local keeper = Lib.Mesh("Shopkeeper", shop, SHOP_CF * CFrame.new(0, 0, 3.4), 4.6)
if keeper then
	Lib.Tag(keeper, "ShopNPC")
end
local counter = Lib.Part({
	Name = "ShopCounter",
	Size = Vector3.new(7, 3, 0.4),
	CFrame = SHOP_CF * CFrame.new(0, 1.5, -2.1),
	Transparency = 1,
	CanCollide = false,
	CanQuery = true,
	CanTouch = false,
	CastShadow = false,
	Parent = shop,
})
Lib.Tag(counter, "ShopCounter")
local shopSign = Lib.NameSign(shop, SHOP_CF * CFrame.new(-5.6, 0, -2.4) * CFrame.Angles(0, 0.3, 0), "Reef Shop 🐚", 3.2)
if shopSign then
	shopSign.Name = "ShopSign"
end
local landing = (SHOP_CF * CFrame.new(0, 0, -8)).Position
world:SetAttribute("ShopTeleport", CFrame.lookAt(landing, Vector3.new(SHOP_POS.X, landing.Y, SHOP_POS.Z)))

for i = 1, 8 do
	local a = i / 8 * math.pi * 2 + 0.2
	local pos = Vector3.new(math.cos(a) * 22, 0.8, math.sin(a) * 22)
	if (pos - SHOP_POS).Magnitude > 9 then
		Lib.TubeCoral(hub, pos, 1.1)
	end
end

------------------------------------------------------------------------------------------------
-- Plots
------------------------------------------------------------------------------------------------
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "PlayerPlots"
plotsFolder.Parent = workspace

local TOP = BASE_HEIGHT

-- Round boulder only (Lib.Rock sometimes picks a wide slab): predictable width beside sockets, so rocks never
-- clip the coral spot. `position` is the rock's centre, like Lib.Rock.
local function boulder(parent: Instance, position: Vector3, size: number): Model
	local m = Lib.Mesh("RockA", parent, Lib.Jitter(position - Vector3.new(0, size * 0.45, 0), 0.1), size * 0.9, true) :: Model
	m.Name = "Rock"
	return m
end

local function buildSocket(plot: Model, cf: CFrame, socketId: string, layout)
	local top = TOP + (layout.ledge and layout.pos.Y or 0)
	local centre = cf * CFrame.new(layout.pos.X, top, layout.pos.Z)
	local deco = Lib.Model(socketId .. "_Decor", plot)

	-- Raised ledge (sun_ledge): a rock step platform
	if layout.ledge then
		Lib.Part({
			Name = "Ledge",
			Size = Vector3.new(12, layout.pos.Y, 12),
			CFrame = cf * CFrame.new(layout.pos.X, TOP + layout.pos.Y / 2, layout.pos.Z),
			Color = P.Rocks[1],
			Parent = deco,
		})
		Lib.Part({
			Name = "Step",
			Size = Vector3.new(4, layout.pos.Y / 2, 3),
			CFrame = cf * CFrame.new(layout.pos.X + 7, TOP + layout.pos.Y / 4, layout.pos.Z - 2),
			Color = P.Rocks[3],
			Parent = deco,
		})
	end

	-- The socket itself: named exactly after the socket id, tagged ReefSocket (code finds it by name)
	local socket = Lib.Part({
		Name = socketId,
		Size = Vector3.new(5, 1, 5),
		CFrame = centre * CFrame.new(0, 0.5, 0),
		Color = P.SandLight,
		CanCollide = false,
		CanQuery = true,
		CanTouch = false,
		Parent = plot,
	})
	Lib.Tag(socket, "ReefSocket")

	-- Ring of small pebbles around the socket
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local p = (centre * CFrame.new(math.cos(a) * 3.4, 0.3, math.sin(a) * 3.4)).Position
		local pebble = Lib.Mesh("RockA", deco, Lib.Jitter(p - Vector3.new(0, 0.45, 0), 0.3), R(0.7, 1)) :: Model
		pebble.Name = "Pebble"
	end

	-- Little wooden name sign at the front-right of the socket (entrance side), clear of the coral and pebbles.
	-- Name only: lock state and price live in the socket's proximity prompt.
	local signCf = centre * CFrame.new(2.6, 0, -4) * CFrame.Angles(0, R(-0.25, 0.05), 0)
	Lib.NameSign(deco, signCf, SocketDefinitions[socketId].displayName, 2.6)

	-- Flavour per location
	if layout.kelp then
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			Lib.Kelp(deco, (centre * CFrame.new(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)).Position, R(10, 18))
		end
	elseif layout.channel then
		for _, x in { -5.5, 5.5 } do
			for z = -6, 6, 4 do
				boulder(deco, (centre * CFrame.new(x + R(-0.3, 0.3), 1.2, z)).Position, R(3.5, 5))
			end
		end
		Lib.BubbleVent(deco, (centre * CFrame.new(0, 0, 7)).Position)
	elseif layout.crevice then
		for _, x in { -6.3, 6.3 } do
			boulder(deco, (centre * CFrame.new(x, 3, 1)).Position, 7)
			boulder(deco, (centre * CFrame.new(x * 0.95, 7, 2)).Position, 5)
		end
	end
	return socket
end

local function buildPlot(index: number, centre: Vector3)
	Lib.Seed(100 + index)
	-- -Z faces the hub so the entrance and spawn point inward
	local cf = CFrame.lookAt(centre, Vector3.new(0, 0, 0))
	local plot = Lib.Model("Plot_" .. index, plotsFolder)
	Lib.Tag(plot, "ReefPlot")

	local base = Lib.Part({
		Name = "Base",
		Size = Vector3.new(PLOT_SIZE, BASE_HEIGHT, PLOT_SIZE),
		CFrame = cf * CFrame.new(0, BASE_HEIGHT / 2, 0),
		Color = P.Sand,
		Parent = plot,
	})
	plot.PrimaryPart = base

	-- Slightly lighter inner sand patches for texture
	for _ = 1, 8 do
		Lib.Decor({
			Name = "SandPatch",
			Size = Vector3.new(R(6, 12), 0.2, R(6, 12)),
			CFrame = cf * CFrame.new(R(-26, 26), TOP + 0.05, R(-26, 26)) * CFrame.Angles(0, R(0, 6), 0),
			Color = Lib.Pick({ P.SandLight, P.SandDark }),
			CastShadow = false,
			Parent = plot,
		})
	end

	-- Rocky rim around the island, with an entrance gap facing the hub (-Z)
	local rim = Lib.Model("Rim", plot)
	local half = PLOT_SIZE / 2
	local step = 5
	for t = -half, half, step do
		for _, edge in { { t, half }, { t, -half }, { half, t }, { -half, t } } do
			local x, z = edge[1], edge[2]
			local isEntrance = z == -half and math.abs(x) < 9
			if not isEntrance then
				local p = (cf * CFrame.new(x + R(-1, 1), R(1, 2.5), z + R(-1, 1))).Position
				Lib.Rock(rim, p, R(4.5, 7.5), if R(0, 1) < 0.6 then P.Rocks[1] else P.Rocks[2])
			end
		end
	end
	-- Entrance ramp
	Lib.Part({
		Name = "Ramp",
		Size = Vector3.new(16, BASE_HEIGHT, 8),
		CFrame = cf * CFrame.new(0, BASE_HEIGHT / 2, -half - 4) * CFrame.Angles(0, math.pi, 0),
		Color = P.SandDark,
		Parent = plot,
	}, "WedgePart")

	-- Dim corner: rock overhang roof on pillars over the right-back quadrant
	local overhang = Lib.Model("Overhang", plot)
	for _, p in { Vector3.new(28, 0, 28), Vector3.new(28, 0, 2), Vector3.new(2, 0, 28) } do
		local pillarCf = Lib.Jitter((cf * CFrame.new(p.X, TOP - 0.5, p.Z)).Position, 0.04)
		local pillar = Lib.Mesh("RockSpire", overhang, pillarCf, 14.5, true) :: Model
		pillar.Name = "Pillar"
	end
	for x = 6, 27, 7 do
		for z = 6, 27, 7 do
			local slabCf = cf * CFrame.new(x, TOP + 12 + R(-0.4, 0.4), z) * CFrame.Angles(R(-0.08, 0.08), R(0, 6), R(-0.08, 0.08))
			local slab = Lib.Mesh("RockSlab", overhang, slabCf, 3.2, true) :: Model
			slab.Name = "Roof"
		end
	end
	-- Hanging kelp/coral under the overhang edge
	for _ = 1, 4 do
		Lib.FanCoral(overhang, (cf * CFrame.new(R(6, 26), TOP + 12.2, R(6, 26))).Position, 0.6, true)
	end

	-- Sockets
	for socketId, layout in SOCKET_LAYOUT do
		buildSocket(plot, cf, socketId, layout)
	end

	-- Bright-side flourish: sea grass and shells on the sunny left
	for _ = 1, 4 do
		Lib.SeaGrass(plot, (cf * CFrame.new(R(-28, -4), TOP, R(-26, 26))).Position, 2)
	end
	for _ = 1, 6 do
		Lib.Seashell(plot, (cf * CFrame.new(R(-28, 28), TOP, R(-28, 28))).Position)
	end
	Lib.Starfish(plot, (cf * CFrame.new(-4, TOP, -16)).Position)
	Lib.Starfish(plot, (cf * CFrame.new(-26, TOP, -22)).Position)

	-- Spawn inside the entrance, facing into the plot
	local spawn = Lib.Part({
		Name = "PlotSpawn",
		Size = Vector3.new(7, 0.6, 7),
		CFrame = cf * CFrame.new(0, TOP + 0.3, -24) * CFrame.Angles(0, math.pi, 0),
		Color = P.Seafoam,
		Material = Enum.Material.SmoothPlastic,
		Parent = plot,
	}, "SpawnLocation")
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Enabled = true

	-- Owner sign on the seafloor beside the entrance ramp, facing the hub. Its text is filled in on each
	-- client (WorldLabelController, "Your Reef" / "<name>'s Reef" / "Empty Reef") via the OwnerSignBoard tag.
	local ownerSign = Lib.NameSign(plot, cf * CFrame.new(12, 0, -39) * CFrame.Angles(0, -0.2, 0), "Empty Reef", 4.5)
	if ownerSign then
		ownerSign.Name = "OwnerSign"
		Lib.Tag(ownerSign:FindFirstChild("Board") :: BasePart, "OwnerSignBoard")
	end

	return plot
end

for i, centre in plotCentres do
	buildPlot(i, centre)
end

return ("Built world: %d plots"):format(PLOT_COUNT)
