--!nonstrict
-- Builds the whole underwater map: seafloor, hub, boundary, and the 6 player plots (M2-01).
-- Re-runnable: destroys and rebuilds Workspace.World and Workspace.PlayerPlots.
-- Run in Edit mode from the command bar: local f = game.ServerStorage.WorldGen:Clone() f.Parent = game.ServerStorage require(f.BuildWorld) f:Destroy()
local Lib = require(script.Parent.Lib)

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
	local spire = Lib.Model("Spire", boundary)
	local spireColor = Lib.Pick(P.Rocks)
	-- Fixed chunk count: shrinking chunks converge in height, so a "while y < h" loop could never end
	local y = 0
	local w = R(12, 18)
	for _ = 1, math.floor(R(3, 7)) do
		Lib.Part({
			Name = "Chunk",
			Size = Vector3.new(w, w * 0.8, w),
			CFrame = CFrame.new(base + Vector3.new(R(-1.5, 1.5), y + w * 0.4, R(-1.5, 1.5)))
				* CFrame.Angles(R(-0.3, 0.3), R(0, 6.28), R(-0.3, 0.3)),
			Color = spireColor:Lerp(Color3.new(1, 1, 1), R(0, 0.12)),
			Parent = spire,
		})
		y += w * 0.6
		w *= 0.78
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
	Lib.Part({
		Name = "Stone",
		Size = Vector3.new(4, 0.8, 3),
		CFrame = CFrame.new(math.cos(a) * 30, 0.4, math.sin(a) * 30) * CFrame.Angles(0, -a + R(-0.2, 0.2), 0),
		Color = Lib.Pick(P.Rocks),
		Parent = hub,
	})
end

-- Giant clam
local clam = Lib.Model("GiantClam", hub)
Lib.Part({
	Name = "BottomShell",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(16, 7, 14),
	CFrame = CFrame.new(0, 1, 0),
	Color = Color3.fromRGB(176, 140, 214),
	Parent = clam,
})
Lib.Part({
	Name = "TopShell",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(16, 6, 14),
	CFrame = CFrame.new(0, 6.5, 4.5) * CFrame.Angles(math.rad(-55), 0, 0),
	Color = Color3.fromRGB(196, 160, 232),
	Parent = clam,
})
for i = -3, 3 do
	Lib.Decor({
		Name = "Ridge",
		Size = Vector3.new(0.6, 0.5, 13),
		CFrame = CFrame.new(0, 6.5, 4.5) * CFrame.Angles(math.rad(-55), 0, 0) * CFrame.new(i * 2, 3, 0),
		Color = Color3.fromRGB(150, 110, 196),
		Parent = clam,
	})
end
local pearl = Lib.Part({
	Name = "Pearl",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(4.5, 4.5, 4.5),
	CFrame = CFrame.new(0, 5.2, -0.5),
	Color = Color3.fromRGB(255, 250, 240),
	Material = Enum.Material.Neon,
	Parent = clam,
})
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(200, 240, 255)
glow.Range = 22
glow.Brightness = 1.5
glow.Parent = pearl

-- Rock arch over the north entrance of the plaza
local arch = Lib.Model("Arch", hub)
for _, x in { -11, 11 } do
	for j = 0, 4 do
		Lib.Part({
			Name = "Pillar",
			Size = Vector3.new(6 - j * 0.5, 5, 6 - j * 0.5),
			CFrame = CFrame.new(x - math.sign(x) * j * 0.8, 2.5 + j * 4.2, -26) * CFrame.Angles(R(-0.2, 0.2), R(0, 6), R(-0.2, 0.2)),
			Color = Lib.Pick(P.Rocks),
			Parent = arch,
		})
	end
end
for x = -8, 8, 4 do
	Lib.Part({
		Name = "Top",
		Size = Vector3.new(6, 4.5, 6),
		CFrame = CFrame.new(x, 22 - math.abs(x) * 0.25, -26) * CFrame.Angles(R(-0.3, 0.3), R(0, 6), R(-0.3, 0.3)),
		Color = Lib.Pick(P.Rocks),
		Parent = arch,
	})
end
Lib.Kelp(arch, Vector3.new(-15, 0, -24), 16)
Lib.Kelp(arch, Vector3.new(15, 0, -28), 18)

Lib.Sign(hub, CFrame.new(0, 0, 16) * CFrame.Angles(0, math.pi, 0), "Grow A Reef 🐠", 14, "WelcomeSign")
for i = 1, 8 do
	local a = i / 8 * math.pi * 2 + 0.2
	Lib.TubeCoral(hub, Vector3.new(math.cos(a) * 22, 0.8, math.sin(a) * 22), 1.1)
end

------------------------------------------------------------------------------------------------
-- Plots
------------------------------------------------------------------------------------------------
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "PlayerPlots"
plotsFolder.Parent = workspace

local TOP = BASE_HEIGHT

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
		Lib.Decor({
			Name = "Pebble",
			Size = Vector3.new(1.3, 1, 1.2),
			CFrame = CFrame.new(p) * CFrame.Angles(R(-0.4, 0.4), R(0, 6), R(-0.4, 0.4)),
			Color = Lib.Pick(P.Rocks),
			Parent = deco,
		})
	end

	-- Name, habitat and lock state are client billboards (WorldLabelController), not parts

	-- Flavour per location
	if layout.kelp then
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			Lib.Kelp(deco, (centre * CFrame.new(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)).Position, R(10, 18))
		end
	elseif layout.channel then
		for _, x in { -5, 5 } do
			for z = -6, 6, 4 do
				Lib.Rock(deco, (centre * CFrame.new(x + R(-0.5, 0.5), 1.2, z)).Position, R(3.5, 5))
			end
		end
		Lib.BubbleVent(deco, (centre * CFrame.new(0, 0, 7)).Position)
	elseif layout.crevice then
		for _, x in { -5.5, 5.5 } do
			Lib.Rock(deco, (centre * CFrame.new(x, 3, 1)).Position, 7)
			Lib.Rock(deco, (centre * CFrame.new(x * 0.8, 7, 2)).Position, 5)
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
	local overhangColor = P.Rocks[4]
	for _, p in { Vector3.new(28, 0, 28), Vector3.new(28, 0, 2), Vector3.new(2, 0, 28) } do
		for j = 0, 3 do
			Lib.Part({
				Name = "Pillar",
				Size = Vector3.new(4.5, 3.6, 4.5),
				CFrame = cf * CFrame.new(p.X, TOP + 1.8 + j * 3.2, p.Z) * CFrame.Angles(R(-0.2, 0.2), R(0, 6), R(-0.2, 0.2)),
				Color = overhangColor:Lerp(Color3.new(0, 0, 0), R(0, 0.15)),
				Parent = overhang,
			})
		end
	end
	for x = 6, 27, 7 do
		for z = 6, 27, 7 do
			Lib.Part({
				Name = "Roof",
				Size = Vector3.new(8.5, 3, 8.5),
				CFrame = cf * CFrame.new(x, TOP + 13.5 + R(-0.5, 0.5), z) * CFrame.Angles(R(-0.12, 0.12), R(0, 6), R(-0.12, 0.12)),
				Color = overhangColor:Lerp(Color3.new(1, 1, 1), R(0, 0.1)),
				Parent = overhang,
			})
		end
	end
	-- Hanging kelp/coral under the overhang edge
	for _ = 1, 4 do
		Lib.FanCoral(overhang, (cf * CFrame.new(R(6, 26), TOP + 11.5, R(6, 26))).Position, 0.6)
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

	return plot
end

for i, centre in plotCentres do
	buildPlot(i, centre)
end

return ("Built world: %d plots"):format(PLOT_COUNT)
