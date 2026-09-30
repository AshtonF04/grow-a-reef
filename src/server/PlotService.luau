--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocketLayout = require(ReplicatedStorage.Shared.Config.SocketLayout)
local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerState = Types.PlayerState

local PLOT_SPACING = 96
local SHOAL_TOP = 1.2

local PlotService = {}

local nextIndex = 0
local indices: { [string]: number } = {}

for id in require(ReplicatedStorage.Shared.Config.SocketDefinitions) do
	if SocketLayout.sockets[id] == nil then
		error("No reef layout for socket " .. id, 0)
	end
end

local function smooth(part: BasePart)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
end

local function indexOf(userId: string): number
	local existing = indices[userId]
	if existing then
		return existing
	end
	local index = nextIndex
	nextIndex += 1
	indices[userId] = index
	return index
end

local function addShells(parent: Instance, pad: BasePart)
	local spots = {
		Vector3.new(5.2, 0, 3.1),
		Vector3.new(-4.6, 0, -2.4),
		Vector3.new(2.4, 0, -3.6),
	}
	for index, spot in spots do
		local shell = Instance.new("Part")
		shell.Name = "Shell"
		shell.Shape = Enum.PartType.Ball
		shell.Size = Vector3.new(0.7, 0.32, 0.85)
		shell.Color = Color3.fromRGB(232, 214, 176):Lerp(Color3.fromRGB(180, 140, 110), (index - 1) * 0.2)
		shell.Material = Enum.Material.SmoothPlastic
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		smooth(shell)
		shell.CFrame = pad.CFrame * CFrame.new(spot.X, pad.Size.Y / 2 + 0.12, spot.Z)
		shell.Parent = parent
	end
end

local function addKelp(parent: Instance, pad: BasePart)
	local spots = {
		Vector3.new(-4.2, 0, -2.6),
		Vector3.new(-2.2, 0, 3.1),
		Vector3.new(3.4, 0, -2.2),
		Vector3.new(4.6, 0, 2.4),
		Vector3.new(0.4, 0, -4.1),
		Vector3.new(-3.6, 0, 0.8),
	}
	local heights = { 8, 12, 7, 11, 9, 13 }
	for index, spot in spots do
		local height = heights[index]
		local stalk = Instance.new("Part")
		stalk.Name = "Kelp"
		stalk.Size = Vector3.new(1.1, height, 0.14)
		stalk.Color = Color3.fromRGB(46, 124, 62):Lerp(Color3.fromRGB(104, 164, 70), index / #spots)
		stalk.Material = Enum.Material.SmoothPlastic
		stalk.CanCollide = false
		stalk.CanQuery = false
		stalk.CanTouch = false
		stalk.CastShadow = false
		smooth(stalk)
		local bottom = pad.CFrame * CFrame.new(spot.X, pad.Size.Y / 2, spot.Z) * CFrame.Angles(0, index * 1.1, 0)
		stalk.CFrame = bottom * CFrame.new(0, height / 2, 0)
		stalk:SetAttribute("Phase", index * 0.9)
		stalk.Parent = parent
		CollectionService:AddTag(stalk, "ReefKelp")
		stalk:SetAttribute("BaseCFrame", stalk.CFrame)
	end
end

local function addCurrent(parent: Instance, pad: BasePart)
	for index = 1, 3 do
		local strip = Instance.new("Part")
		strip.Name = "Current"
		strip.Size = Vector3.new(6.2, 0.12, 0.8)
		strip.Color = Color3.fromRGB(150, 214, 220)
		strip.Material = Enum.Material.Glass
		strip.Transparency = 0.45
		strip.CanCollide = false
		strip.CanQuery = false
		strip.CanTouch = false
		strip.CastShadow = false
		smooth(strip)
		strip.CFrame = pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + 0.18, -5 + index * 3.2)
		strip:SetAttribute("Phase", index * 1.4)
		strip.Parent = parent
		CollectionService:AddTag(strip, "ReefCurrent")
		strip:SetAttribute("BaseCFrame", strip.CFrame)
	end
end

local function dress(socketId: string, model: Model, pad: BasePart)
	if socketId == "sandy_patch" then
		addShells(model, pad)
	elseif socketId == "sun_ledge" then
		local cap = Instance.new("Part")
		cap.Name = "Cap"
		cap.Size = Vector3.new(7, 1.1, 5)
		cap.Color = Color3.fromRGB(196, 154, 108)
		cap.Material = Enum.Material.Sandstone
		smooth(cap)
		cap.CFrame = pad.CFrame * CFrame.new(-1.2, pad.Size.Y / 2 + 0.4, 0.4)
		cap.Parent = model
	elseif socketId == "surge_channel" then
		addCurrent(model, pad)
	elseif socketId == "kelp_shade" then
		addKelp(model, pad)
	elseif socketId == "rock_crevice" then
		for index, side in { -1, 1 } do
			local pillar = Instance.new("Part")
			pillar.Name = "Pillar"
			pillar.Size = Vector3.new(2.2, 5.5, 2.6)
			pillar.Color = Color3.fromRGB(92, 90, 88)
			pillar.Material = Enum.Material.Rock
			smooth(pillar)
			pillar.CFrame = pad.CFrame
				* CFrame.new(side * 2.3, 1.6, 0)
				* CFrame.Angles(0, 0.4 * side, 0.08 * side)
			pillar.Parent = model
		end
	elseif socketId == "deep_nook" then
		local arch = Instance.new("Part")
		arch.Name = "Arch"
		arch.Size = Vector3.new(8, 3.2, 1.4)
		arch.Color = Color3.fromRGB(62, 78, 86)
		arch.Material = Enum.Material.Slate
		smooth(arch)
		arch.CFrame = pad.CFrame * CFrame.new(0, 2.2, -3.2)
		arch.Parent = model
	end
end

local function addMound(parent: Instance, pivot: CFrame, offset: Vector3, size: Vector3, color: Color3, material: Enum.Material)
	local mound = Instance.new("Part")
	mound.Name = "Mound"
	mound.Shape = Enum.PartType.Ball
	mound.Size = size
	mound.Color = color
	mound.Material = material
	smooth(mound)
	mound.CFrame = pivot * CFrame.new(offset)
	mound.Parent = parent
end

function PlotService.Ensure(player: Player): Model
	local plots = workspace:FindFirstChild("ReefPlots")
	if not plots or not plots:IsA("Folder") then
		error("Reef world is not built", 0)
	end

	local userId = tostring(player.UserId)
	local existing = plots:FindFirstChild(userId)
	if existing and existing:IsA("Model") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local pivot = SocketLayout.plotPivot * CFrame.new(indexOf(userId) * PLOT_SPACING, 0, 0)
	local plot = Instance.new("Model")
	plot.Name = userId
	plot:SetAttribute("OwnerUserId", player.UserId)

	local shoal = Instance.new("Part")
	shoal.Name = "Shoal"
	shoal.Size = Vector3.new(84, 1.2, 80)
	shoal.Color = Color3.fromRGB(188, 166, 116)
	shoal.Material = Enum.Material.Sand
	smooth(shoal)
	shoal.CFrame = pivot * CFrame.new(0, 0.6, -6)
	shoal.Parent = plot
	plot.PrimaryPart = shoal

	addMound(plot, pivot, Vector3.new(34, 0.5, 8), Vector3.new(14, 4.2, 12), Color3.fromRGB(176, 154, 108), Enum.Material.Sand)
	addMound(plot, pivot, Vector3.new(-40, 0.4, 6), Vector3.new(14, 4.4, 12), Color3.fromRGB(168, 148, 104), Enum.Material.Sand)
	addMound(plot, pivot, Vector3.new(8, 0.3, -36), Vector3.new(18, 5, 14), Color3.fromRGB(160, 142, 100), Enum.Material.Sand)
	addMound(plot, pivot, Vector3.new(-14, 0.2, 24), Vector3.new(12, 3.6, 10), Color3.fromRGB(196, 174, 122), Enum.Material.Sand)
	addMound(plot, pivot, Vector3.new(32, 1.2, -18), Vector3.new(7, 5, 6), Color3.fromRGB(96, 100, 98), Enum.Material.Rock)
	addMound(plot, pivot, Vector3.new(-22, 1.4, 8), Vector3.new(6, 4.2, 5), Color3.fromRGB(110, 108, 104), Enum.Material.Rock)

	for _, socket in ReefRules.OrderedSockets() do
		local layout = SocketLayout.sockets[socket.id]
		local socketModel = Instance.new("Model")
		socketModel.Name = socket.id

		local centerY = SHOAL_TOP + layout.offset.Y + layout.size.Y / 2
		local pad = Instance.new("Part")
		pad.Name = "Pad"
		pad.Size = layout.size
		pad.Color = layout.color
		pad.Material = layout.material
		smooth(pad)
		pad.CFrame = pivot * CFrame.new(layout.offset.X, centerY, layout.offset.Z)
		pad.Parent = socketModel
		socketModel.PrimaryPart = pad
		socketModel.Parent = plot
		dress(socket.id, socketModel, pad)
	end

	plot.Parent = plots
	return plot
end

function PlotService.Apply(player: Player, state: PlayerState)
	local plots = workspace:FindFirstChild("ReefPlots")
	if not plots then
		return
	end
	local plot = plots:FindFirstChild(tostring(player.UserId))
	if not plot then
		return
	end

	for id, layout in SocketLayout.sockets do
		local socketModel = plot:FindFirstChild(id)
		if socketModel and socketModel:IsA("Model") then
			local pad = socketModel:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") then
				if state.socketUnlocks[id] then
					pad.Color = layout.color
					pad.Transparency = 0
				else
					pad.Color = layout.color:Lerp(Color3.fromRGB(18, 26, 30), 0.62)
					pad.Transparency = 0.15
				end
			end
		end
	end
end

function PlotService.Remove(player: Player)
	local plots = workspace:FindFirstChild("ReefPlots")
	if not plots then
		return
	end
	local plot = plots:FindFirstChild(tostring(player.UserId))
	if plot then
		plot:Destroy()
	end
end

return PlotService
