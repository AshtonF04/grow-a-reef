--!strict
-- Fills in each plot's wooden OwnerSign (built by BuildWorld, board tagged OwnerSignBoard) from the plot's
-- OwnerName / OwnerUserId attributes: "Your Reef" (green) on your own plot, "<name>'s Reef" on others,
-- "Empty Reef" when unclaimed. Client-only text, so each player sees "Your Reef" on their own plot.
-- Socket names are NameSign meshes too; lock state and price only show in the socket's proximity prompt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local WorldLabelController = {}

local TEXT_COLOR = Color3.fromRGB(255, 248, 230)
local MINE_COLOR = Color3.fromRGB(150, 255, 140)

local function findPlot(inst: Instance): Model?
	local node = inst.Parent
	for _ = 1, 8 do
		if node == nil then
			return nil
		end
		if node:IsA("Model") and CollectionService:HasTag(node, "ReefPlot") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function bindBoard(board: BasePart)
	local plot = findPlot(board)
	local surface = board:WaitForChild("LabelFront", 10)
	local label = surface and surface:WaitForChild("Text", 10)
	if plot == nil or label == nil or not label:IsA("TextLabel") then
		return
	end

	local function refresh()
		local name = plot:GetAttribute("OwnerName")
		local mine = plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
		label.Text = if mine then "Your Reef" elseif type(name) == "string" then name .. "'s Reef" else "Empty Reef"
		label.TextColor3 = if mine then MINE_COLOR else TEXT_COLOR
	end
	refresh()
	plot:GetAttributeChangedSignal("OwnerName"):Connect(refresh)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
end

function WorldLabelController.Init()
	-- Tags fire again when a streamed-out plot comes back, so the new board instance gets bound too
	CollectionService:GetInstanceAddedSignal("OwnerSignBoard"):Connect(function(inst)
		if inst:IsA("BasePart") then
			task.spawn(bindBoard, inst)
		end
	end)
	for _, inst in CollectionService:GetTagged("OwnerSignBoard") do
		if inst:IsA("BasePart") then
			task.spawn(bindBoard, inst)
		end
	end
end

return WorldLabelController
