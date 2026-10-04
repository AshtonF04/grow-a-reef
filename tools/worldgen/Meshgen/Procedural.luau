--!nonstrict
-- Procedural low-poly assets for the mesh comparison test: Sun Coral stages, clownfish, large rock.
-- Returns a table of builder functions; each returns a Model (Root at base centre, mesh non-collide).
local LowPoly = require(script.Parent.LowPoly)

local Procedural = {}

local ORANGE = Color3.fromRGB(255, 136, 56)
local ORANGE_DARK = Color3.fromRGB(222, 98, 38)
local TIP = Color3.fromRGB(255, 236, 140)

------------------------------------------------------------------------------------------------
-- Sun Coral: one shared branch tree; stages reveal more of it and scale it up, so all three
-- stages read as the same species growing.
------------------------------------------------------------------------------------------------
local BRANCHES = {} -- { yaw, tilt, length, children = { {yawOffset, tilt, length} } }
do
	local rng = Random.new(301)
	for i = 1, 5 do
		local yaw = i / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		table.insert(BRANCHES, {
			yaw = yaw,
			tilt = rng:NextNumber(0.8, 1.05),
			length = rng:NextNumber(0.9, 1.15),
			children = {
				{ dyaw = -0.55, tilt = rng:NextNumber(0.35, 0.55), length = rng:NextNumber(0.65, 0.85) },
				{ dyaw = 0.55, tilt = rng:NextNumber(0.35, 0.55), length = rng:NextNumber(0.65, 0.85) },
			},
		})
	end
end

local function dirFrom(yaw: number, tilt: number): Vector3
	return (CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, tilt)).UpVector
end

-- stage: 1 = Bud, 2 = Young, 3 = Mature
function Procedural.SunCoral(stage: number, parent: Instance?): Model
	local b = LowPoly.new()
	local s = ({ 0.42, 0.7, 1 })[stage]
	local branchCount = ({ 3, 5, 5 })[stage]
	local fork = stage == 3

	-- Wide squashed base mound
	b:Ball(Vector3.new(0, 0.1 * s, 0), Vector3.new(0.85, 0.42, 0.85) * s, ORANGE_DARK, 1)
	local trunkTop = Vector3.new(0, 0.9 * s, 0)
	b:Tube(Vector3.new(0, 0.2 * s, 0), trunkTop, 0.4 * s, 0.32 * s, 6, ORANGE)
	b:Ball(trunkTop, Vector3.one * 0.38 * s, ORANGE, 0)

	for i = 1, branchCount do
		local br = BRANCHES[i]
		local dir = dirFrom(br.yaw, br.tilt)
		local len = br.length * 1.2 * s
		local mid = trunkTop + dir * len
		b:Tube(trunkTop, mid, 0.3 * s, 0.24 * s, 6, ORANGE)
		if fork then
			b:Ball(mid, Vector3.one * 0.26 * s, ORANGE, 0)
			for _, ch in br.children do
				local cdir = dirFrom(br.yaw + ch.dyaw, ch.tilt)
				local tipPos = mid + cdir * ch.length * 1.1 * s
				b:Tube(mid, tipPos, 0.22 * s, 0.18 * s, 6, ORANGE)
				b:Ball(tipPos, Vector3.one * 0.3 * s, TIP, 1)
			end
		else
			b:Ball(mid, Vector3.one * 0.32 * s, TIP, 1)
		end
	end
	-- Central top tip
	local top = trunkTop + Vector3.new(0, 0.9 * s, 0)
	b:Tube(trunkTop, top, 0.28 * s, 0.22 * s, 6, ORANGE)
	b:Ball(top, Vector3.one * 0.34 * s, TIP, 1)

	return b:ToModel(({ "Bud", "Young", "Mature" })[stage], parent)
end

------------------------------------------------------------------------------------------------
-- Clownfish: lathed 8-sided body along Z (head at -Z), stripe bands, fins, eyes
------------------------------------------------------------------------------------------------
function Procedural.Clownfish(parent: Instance?): Model
	local b = LowPoly.new()
	local WHITE = Color3.fromRGB(250, 250, 250)
	local BLACK = Color3.fromRGB(30, 30, 40)
	-- Profile: { z, halfWidth, halfHeight }
	local profile = {
		{ -1.05, 0.0, 0.0 },
		{ -0.9, 0.28, 0.36 },
		{ -0.6, 0.42, 0.55 },
		{ -0.3, 0.46, 0.6 },
		{ 0.05, 0.44, 0.56 },
		{ 0.4, 0.36, 0.44 },
		{ 0.7, 0.22, 0.28 },
		{ 0.88, 0.12, 0.16 },
	}
	-- White bands (z ranges) with black edges
	local function bandColor(z: number): Color3
		for _, band in { { -0.62, -0.42 }, { 0.0, 0.2 }, { 0.62, 0.76 } } do
			if z >= band[1] - 0.04 and z <= band[2] + 0.04 then
				if z < band[1] or z > band[2] then
					return BLACK
				end
				return WHITE
			end
		end
		return Color3.fromRGB(255, 140, 40)
	end
	local SIDES = 8
	local centre = Vector3.new(0, 0, 0)
	local function ringPoint(p, i)
		local a = i / SIDES * math.pi * 2
		return Vector3.new(math.cos(a) * p[2], math.sin(a) * p[3], p[1])
	end
	-- Subdivide the profile finer so stripe bands get their own facets
	local rings = {}
	for i = 1, #profile - 1 do
		local p0, p1 = profile[i], profile[i + 1]
		for k = 0, 2 do
			local t = k / 3
			table.insert(rings, { p0[1] + (p1[1] - p0[1]) * t, p0[2] + (p1[2] - p0[2]) * t, p0[3] + (p1[3] - p0[3]) * t })
		end
	end
	table.insert(rings, profile[#profile])
	for r = 1, #rings - 1 do
		local p0, p1 = rings[r], rings[r + 1]
		local col = bandColor((p0[1] + p1[1]) / 2)
		for i = 0, SIDES - 1 do
			local j = (i + 1) % SIDES
			local a, bb, c, d = ringPoint(p0, i), ringPoint(p0, j), ringPoint(p1, j), ringPoint(p1, i)
			local k = if i % 2 == 0 then 1 else 0.9
			b:Tri(a, bb, c, LowPoly.Shade(col, k), centre)
			b:Tri(a, c, d, LowPoly.Shade(col, k), centre)
		end
	end
	-- Tail cap + forked tail fin
	local tailEnd = rings[#rings]
	local tailCentre = Vector3.new(0, 0, tailEnd[1])
	for i = 0, SIDES - 1 do
		b:Tri(tailCentre, ringPoint(tailEnd, i), ringPoint(tailEnd, (i + 1) % SIDES), Color3.fromRGB(255, 140, 40), Vector3.new(0, 0, 0))
	end
	local orange = Color3.fromRGB(255, 150, 50)
	b:DoubleTri(tailCentre, Vector3.new(0, 0.55, 1.45), Vector3.new(0, 0.05, 1.2), orange)
	b:DoubleTri(tailCentre, Vector3.new(0, -0.05, 1.2), Vector3.new(0, -0.55, 1.45), orange)
	b:DoubleTri(Vector3.new(0, 0.55, 1.45), Vector3.new(0, 0.62, 1.52), Vector3.new(0, 0.3, 1.38), BLACK)
	-- Dorsal and side fins
	b:DoubleTri(Vector3.new(0, 0.58, -0.35), Vector3.new(0, 0.95, -0.05), Vector3.new(0, 0.5, 0.35), orange)
	b:DoubleTri(Vector3.new(0, 0.48, 0.1), Vector3.new(0, 0.8, 0.45), Vector3.new(0, 0.35, 0.6), orange)
	for _, side in { -1, 1 } do
		b:DoubleTri(Vector3.new(side * 0.42, -0.15, -0.35), Vector3.new(side * 0.85, -0.4, -0.1), Vector3.new(side * 0.4, -0.3, 0.05), orange)
		-- Eye: white ball with dark pupil
		local eye = Vector3.new(side * 0.36, 0.18, -0.72)
		b:Ball(eye, Vector3.one * 0.15, WHITE, 1)
		b:Ball(eye + Vector3.new(side * 0.08, 0.01, -0.04), Vector3.one * 0.085, BLACK, 0)
	end

	local model = b:ToModel("Clownfish", parent)
	return model
end

------------------------------------------------------------------------------------------------
-- Large rock: noisy icosphere, flattened bottom, per-face sandstone/terracotta variation
------------------------------------------------------------------------------------------------
function Procedural.Rock(parent: Instance?, seed: number?): Model
	local b = LowPoly.new()
	local rng = Random.new(seed or 77)
	local SIZE = Vector3.new(5, 3.6, 4.5) -- half-extents (~10 x 7 x 9 studs)
	local palette = { Color3.fromRGB(196, 150, 104), Color3.fromRGB(186, 140, 96), Color3.fromRGB(176, 116, 88), Color3.fromRGB(205, 165, 118) }
	-- Displace each unique vertex consistently so faces stay connected
	local offsets: { [string]: number } = {}
	local function displaced(v: Vector3): Vector3
		local key = string.format("%.3f,%.3f,%.3f", v.X, v.Y, v.Z)
		local o = offsets[key]
		if o == nil then
			o = rng:NextNumber(0.82, 1.12)
			offsets[key] = o
		end
		local p = v * SIZE * o
		-- Flatten the bottom so it sits on the floor
		return Vector3.new(p.X, math.max(p.Y, -SIZE.Y * 0.35), p.Z)
	end
	local centre = Vector3.new(0, 0, 0)
	for _, t in LowPoly.IcoTriangles(1) do
		local a, bb, c = displaced(t[1]), displaced(t[2]), displaced(t[3])
		local up = ((a + bb + c) / 3).Unit.Y
		local col = palette[rng:NextInteger(1, #palette)]
		-- Top faces a touch lighter, undersides darker, for a sculpted cartoon read
		b:Tri(a, bb, c, LowPoly.Shade(col, 0.9 + up * 0.12), centre)
	end
	local model = b:ToModel("LargeRock", parent)
	-- Root at the base centre (bottom was flattened at -0.35 * SIZE.Y)
	local root = model.PrimaryPart
	root.CFrame = CFrame.new(0, -SIZE.Y * 0.35, 0)
	return model
end

return Procedural
