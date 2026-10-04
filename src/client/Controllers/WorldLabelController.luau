--!strict
-- World billboards that replace the old Studio signs:
--   SocketTag: socket name + light/flow icons, plus a lock and the unlock price while locked.
--   OwnerTag: "<name>'s Reef" over each claimed plot's entrance (from the plot's OwnerName attribute).
-- Both are client-only and parented to the streamed part, so they disappear with it when it streams out.
-- Unclaimed plots show no tags at all.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local HabitatIcons = require(ReplicatedStorage.Shared.Config.HabitatIcons)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local WorldLabelController = {}

local SOCKET_TAG_DISTANCE = 60
local OWNER_TAG_DISTANCE = 220
-- Where the old info tablet stood: in front of the socket (entrance side), so it never covers the coral
local SOCKET_TAG_OFFSET = CFrame.new(0, 2.2, -4.4)

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

local function isClaimed(plot: Model?): boolean
	return plot ~= nil and plot:GetAttribute("OwnerUserId") ~= nil
end

local function bindSocket(socket: BasePart)
	local def = SocketDefinitions[socket.Name]
	if def == nil or socket:FindFirstChild("SocketTag") then
		return
	end
	local plot = findPlot(socket)

	local anchor = UIKit.new("Attachment", {
		Name = "SocketTagAnchor",
		CFrame = SOCKET_TAG_OFFSET,
		Parent = socket,
	})
	local gui = UIKit.new("BillboardGui", {
		Name = "SocketTag",
		Adornee = anchor,
		Size = UDim2.fromOffset(190, 78),
		MaxDistance = SOCKET_TAG_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})

	local namePill, nameLabel = UIKit.pill({
		Name = "Name",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(180, 36),
		Parent = gui,
	}, def.displayName)
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = nameLabel })

	-- Habitat icons under the name; the lock + price chip replaces them while locked
	local habitat = UIKit.label({
		Name = "Habitat",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(180, 32),
		Text = HabitatIcons.Light[def.light] .. "  " .. HabitatIcons.Flow[def.flow],
		FontFace = Theme.Fonts.Body,
		TextSize = 24,
		Parent = gui,
	})
	local lockChip, lockLabel = UIKit.pill({
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(120, 34),
		BackgroundColor3 = Theme.Colors.Gold,
		Parent = gui,
	}, ("%d 🐚"):format(def.unlockCostShells), "🔒")
	local lockRim = lockChip:FindFirstChild("Rim") :: UIStroke
	lockRim.Color = Theme.Colors.GoldDark
	local lockText = lockLabel:FindFirstChild("TextStroke") :: UIStroke
	lockText.Color = Theme.Colors.GoldDark
	local bubble = lockChip:FindFirstChild("IconBubble") :: Frame
	bubble.BackgroundColor3 = Theme.Colors.Navy
	local bubbleRim = bubble:FindFirstChildOfClass("UIStroke") :: UIStroke
	bubbleRim.Color = Theme.Colors.BlueLight

	local function refresh()
		local locked = socket:GetAttribute("Unlocked") ~= true
		gui.Enabled = isClaimed(plot)
		habitat.Visible = not locked
		lockChip.Visible = locked
		UIKit.setButtonColor(namePill, if locked then Theme.Colors.Disabled else Theme.Colors.Blue, if locked
			then Theme.Colors.DisabledDark
			else Theme.Colors.BlueDark)
	end
	refresh()
	socket:GetAttributeChangedSignal("Unlocked"):Connect(refresh)
	if plot then
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	end
	gui.Parent = socket
end

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
	-- Plots first so a socket's plot is tagged by the time its label checks ownership
	observe("ReefPlot", "Model", bindPlot)
	observe("ReefSocket", "BasePart", bindSocket)
end

return WorldLabelController
