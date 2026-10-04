--!strict
-- OwnerTag billboard: "<name>'s Reef" over each claimed plot's entrance (from the plot's OwnerName attribute).
-- Client-only and parented to the streamed PlotSpawn, so it disappears with it when it streams out.
-- Unclaimed plots show no tag. Socket names are wooden NameSign meshes in the world (BuildWorld); lock state
-- and price only show in the socket's proximity prompt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local WorldLabelController = {}

local OWNER_TAG_DISTANCE = 220

local function bindPlot(plot: Model)
	local spawnPart = plot:WaitForChild("PlotSpawn", 10)
	if spawnPart == nil or not spawnPart:IsA("BasePart") or spawnPart:FindFirstChild("OwnerTag") then
		return
	end
	local gui = UIKit.new("BillboardGui", {
		Name = "OwnerTag",
		Adornee = spawnPart,
		Size = UDim2.fromOffset(300, 56),
		StudsOffsetWorldSpace = Vector3.new(0, 10, 0),
		MaxDistance = OWNER_TAG_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local pill, label = UIKit.pill({
		Name = "Owner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, "", "🐠")

	local function refresh()
		local name = plot:GetAttribute("OwnerName")
		local mine = plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
		gui.Enabled = type(name) == "string"
		label.Text = if mine then "Your Reef" elseif type(name) == "string" then name .. "'s Reef" else ""
		-- Your own plot is green so it's easy to find from the hub
		if mine then
			UIKit.setButtonColor(pill, Theme.Colors.Green, Theme.Colors.GreenDark)
		else
			UIKit.setButtonColor(pill, Theme.Colors.Blue, Theme.Colors.BlueDark)
		end
		local textStroke = label:FindFirstChild("TextStroke") :: UIStroke
		textStroke.Color = if mine then Theme.Colors.GreenDark else Theme.Colors.Navy
	end
	refresh()
	plot:GetAttributeChangedSignal("OwnerName"):Connect(refresh)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	gui.Parent = spawnPart
end

local function observe(tag: string, className: string, callback: (any) -> ())
	local function consider(inst: Instance)
		if inst:IsA(className) then
			task.spawn(callback, inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(consider)
	for _, inst in CollectionService:GetTagged(tag) do
		consider(inst)
	end
end

function WorldLabelController.Init()
	observe("ReefPlot", "Model", bindPlot)
end

return WorldLabelController
