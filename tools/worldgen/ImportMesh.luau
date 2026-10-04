--!nonstrict
-- Turns a fresh AI `generate_mesh` result (a Model in Workspace tagged with the job's tag) into a world
-- template at ServerStorage/WorldAssets/<name>: same layout as the coral/fish assets, i.e. an invisible
-- anchored `Root` PrimaryPart at the centre of the base plus the textured MeshPart(s).
-- MeshParts are anchored, non-collide/query/touch by default; Lib.Mesh turns collision on per use.
-- Usage (Edit mode): local f = game.ServerStorage.WorldGen:Clone() f.Parent = game.ServerStorage
--   print(require(f.ImportMesh)("Assistant-<tag>", "RockA")) f:Destroy()
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

return function(tag: string, name: string): string
	local model: Model? = nil
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("Model") then
			model = inst
		end
	end
	assert(model, "ImportMesh: nothing tagged " .. tag)

	local folder = ServerStorage:FindFirstChild("WorldAssets")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "WorldAssets"
		folder.Parent = ServerStorage
	end
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end

	local oldRoot = model:FindFirstChild("Root")
	if oldRoot then
		oldRoot:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			-- generate_mesh spawns results yawed toward the camera; zero it so templates face -Z like the code expects
			d.CFrame = CFrame.new(d.Position)
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	CollectionService:RemoveTag(model, tag)

	local cf, size = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	root.Parent = model
	model.PrimaryPart = root
	model.Name = name
	model:PivotTo(CFrame.new())
	model.Parent = folder
	return ("%s: %.2f x %.2f x %.2f"):format(name, size.X, size.Y, size.Z)
end
