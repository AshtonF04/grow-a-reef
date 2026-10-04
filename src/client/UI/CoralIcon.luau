--!strict
-- A ViewportFrame showing a coral's Mature model, framed to fit. Used by the plant tray and shop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)

local CoralIcon = {}

function CoralIcon.new(coralId: string, props: { [string]: any }?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	if props then
		for k, v in props do
			(viewport :: any)[k] = v
		end
	end

	local coral = CoralDefinitions[coralId]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local corals = assets and assets:FindFirstChild("Corals")
	local species = corals and coral and corals:FindFirstChild(coral.modelName)
	local template = species and species:FindFirstChild("Mature")
	if template == nil or not template:IsA("Model") then
		return viewport
	end

	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = viewport

	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local target = cf.Position
	camera.CFrame = CFrame.lookAt(target + Vector3.new(0.6, 0.55, 1).Unit * distance, target)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

return CoralIcon
