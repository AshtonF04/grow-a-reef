--!nonstrict
-- Flat-shaded low-poly mesh builder on top of EditableMesh. Every triangle gets its own vertices, normal
-- and colour, giving the faceted cartoon look with no textures. Triangles are oriented to face away from
-- a supplied "inside" point so winding mistakes can't flip faces.
--
-- Note: EditableMesh geometry lives only in the current Studio session. To keep a mesh permanently it
-- must be uploaded (AssetService:CreateAssetAsync) or exported.
local AssetService = game:GetService("AssetService")

local LowPoly = {}
LowPoly.__index = LowPoly

export type Builder = typeof(setmetatable({} :: {
	mesh: EditableMesh,
	min: Vector3,
	max: Vector3,
	tris: number,
	colorIds: { [string]: number },
}, LowPoly))

function LowPoly.new(): Builder
	local mesh = AssetService:CreateEditableMesh()
	return setmetatable({
		mesh = mesh,
		min = Vector3.new(math.huge, math.huge, math.huge),
		max = Vector3.new(-math.huge, -math.huge, -math.huge),
		tris = 0,
		colorIds = {},
	}, LowPoly)
end

function LowPoly:_color(c: Color3): number
	local key = c:ToHex()
	local id = self.colorIds[key]
	if id == nil then
		id = self.mesh:AddColor(c, 1)
		self.colorIds[key] = id
	end
	return id
end

-- One flat triangle. `inside` (optional) is a point the face should point away from.
function LowPoly:Tri(a: Vector3, b: Vector3, c: Vector3, color: Color3, inside: Vector3?)
	local n = (b - a):Cross(c - a)
	if n.Magnitude < 1e-9 then
		return
	end
	n = n.Unit
	if inside and n:Dot((a + b + c) / 3 - inside) < 0 then
		b, c = c, b
		n = -n
	end
	local m = self.mesh
	local va, vb, vc = m:AddVertex(a), m:AddVertex(b), m:AddVertex(c)
	local face = m:AddTriangle(va, vb, vc)
	local nid = m:AddNormal(n)
	m:SetFaceNormals(face, { nid, nid, nid })
	local cid = self:_color(color)
	m:SetFaceColors(face, { cid, cid, cid })
	self.min = self.min:Min(a):Min(b):Min(c)
	self.max = self.max:Max(a):Max(b):Max(c)
	self.tris += 1
end

-- Both sides (for thin fins/tails)
function LowPoly:DoubleTri(a: Vector3, b: Vector3, c: Vector3, color: Color3)
	self:Tri(a, b, c, color)
	self:Tri(a, c, b, color)
end

local function shade(c: Color3, k: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * k, 0, 1))
end
LowPoly.Shade = shade

-- Tapered n-sided tube from p0 to p1 (open ends; caps optional)
function LowPoly:Tube(p0: Vector3, p1: Vector3, r0: number, r1: number, sides: number, color: Color3, capTop: boolean?, capBottom: boolean?)
	local axis = (p1 - p0).Unit
	local ref = if math.abs(axis.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	local u = axis:Cross(ref).Unit
	local v = axis:Cross(u).Unit
	local ring0, ring1 = {}, {}
	for i = 0, sides - 1 do
		local a = i / sides * math.pi * 2
		local dir = u * math.cos(a) + v * math.sin(a)
		ring0[i] = p0 + dir * r0
		ring1[i] = p1 + dir * r1
	end
	local mid = (p0 + p1) / 2
	for i = 0, sides - 1 do
		local j = (i + 1) % sides
		local k = if i % 2 == 0 then 1 else 0.92 -- alternating facet brightness for the faceted look
		self:Tri(ring0[i], ring0[j], ring1[j], shade(color, k), mid)
		self:Tri(ring0[i], ring1[j], ring1[i], shade(color, k), mid)
		if capTop then
			self:Tri(p1, ring1[i], ring1[j], color, mid)
		end
		if capBottom then
			self:Tri(p0, ring0[j], ring0[i], color, mid)
		end
	end
end

-- Icosahedron vertices/faces (unit radius)
local PHI = (1 + math.sqrt(5)) / 2
local ICO_V = {
	Vector3.new(-1, PHI, 0), Vector3.new(1, PHI, 0), Vector3.new(-1, -PHI, 0), Vector3.new(1, -PHI, 0),
	Vector3.new(0, -1, PHI), Vector3.new(0, 1, PHI), Vector3.new(0, -1, -PHI), Vector3.new(0, 1, -PHI),
	Vector3.new(PHI, 0, -1), Vector3.new(PHI, 0, 1), Vector3.new(-PHI, 0, -1), Vector3.new(-PHI, 0, 1),
}
local ICO_F = {
	{ 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
	{ 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
	{ 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
	{ 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
}

-- Returns triangles of a unit icosphere ({ {Vector3,Vector3,Vector3} }), subdivided `level` times
function LowPoly.IcoTriangles(level: number): { { Vector3 } }
	local tris = {}
	for _, f in ICO_F do
		table.insert(tris, { ICO_V[f[1]].Unit, ICO_V[f[2]].Unit, ICO_V[f[3]].Unit })
	end
	for _ = 1, level do
		local nextTris = {}
		for _, t in tris do
			local a, b, c = t[1], t[2], t[3]
			local ab, bc, ca = ((a + b) / 2).Unit, ((b + c) / 2).Unit, ((c + a) / 2).Unit
			table.insert(nextTris, { a, ab, ca })
			table.insert(nextTris, { b, bc, ab })
			table.insert(nextTris, { c, ca, bc })
			table.insert(nextTris, { ab, bc, ca })
		end
		tris = nextTris
	end
	return tris
end

-- Faceted ball (scale lets it be squashed into a mound/ellipsoid)
function LowPoly:Ball(center: Vector3, scale: Vector3, color: Color3, level: number?)
	for i, t in LowPoly.IcoTriangles(level or 0) do
		local k = 0.9 + (i % 3) * 0.06
		self:Tri(center + t[1] * scale, center + t[2] * scale, center + t[3] * scale, shade(color, k), center)
	end
end

-- Wraps the mesh in a MeshPart + invisible Root PrimaryPart at local origin (base centre)
function LowPoly:ToModel(name: string, parent: Instance?): Model
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(self.mesh))
	part.Name = "Mesh"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = Color3.new(1, 1, 1) -- vertex colours carry the palette
	part.Material = Enum.Material.SmoothPlastic
	local centre = (self.min + self.max) / 2
	part.CFrame = CFrame.new(centre)

	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	part.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Triangles", self.tris)
	model.Parent = parent
	return model
end

return LowPoly
