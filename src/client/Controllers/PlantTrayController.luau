--!strict
-- Bottom-sheet coral picker shown when activating an empty socket. Each card shows owned count, grow
-- time, habitat fit and the expected payout, while keeping the target socket visible above the sheet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local HabitatIcons = require(ReplicatedStorage.Shared.Config.HabitatIcons)
local EconomyMath = require(ReplicatedStorage.Shared.Logic.EconomyMath)
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local CoralIcon = require(script.Parent.Parent.UI.CoralIcon)

local PlantTrayController = {}

local gui: ScreenGui? = nil
local sheet: Frame? = nil
local titleLabel: TextLabel? = nil
local grid: ScrollingFrame? = nil
local lightLabel: TextLabel? = nil
local flowLabel: TextLabel? = nil
local currentSocket: string? = nil
local busy = false

local function formatDuration(seconds: number): string
	if seconds >= 3600 then
		return string.format("%dh", math.floor(seconds / 3600 + 0.5))
	elseif seconds >= 60 then
		return string.format("%dm", math.floor(seconds / 60 + 0.5))
	end
	return seconds .. "s"
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = UIKit.new("ScreenGui", {
		Name = "PlantTray",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Bottom sheet: ~40% of the screen height, capped width on desktop
	local window = UIKit.panel({
		Name = "Sheet",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0.4, 0),
		Parent = screen,
	}, "Plant", function()
		PlantTrayController.Close()
	end)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(760, 360), MinSize = Vector2.new(300, 240), Parent = window.frame })
	local panel = window.frame
	local title = window.title

	-- Socket details strip: the conditions the fit chips on each card are judged against
	local details = UIKit.new("Frame", {
		Name = "SocketDetails",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = window.content,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function detailPill(name: string, width: number, order: number): TextLabel
		local _, label = UIKit.pill({
			Name = name,
			Size = UDim2.fromOffset(width, 30),
			BackgroundColor3 = Theme.Colors.BlueInset,
			LayoutOrder = order,
			Parent = details,
		}, "")
		label.FontFace = Theme.Fonts.Body
		return label
	end
	local light = detailPill("Light", 130, 1)
	local flow = detailPill("Flow", 170, 2)

	local scroll = UIKit.new("ScrollingFrame", {
		Name = "Cards",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.BlueLight,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window.content,
	}, {
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -8, 0, 210),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	screen.Parent = playerGui
	gui = screen
	sheet = panel
	titleLabel = title
	grid = scroll
	lightLabel = light
	flowLabel = flow
end

local function fitChip(parent: Instance, coralId: string, socketId: string)
	local coral = CoralDefinitions[coralId]
	local socket = SocketDefinitions[socketId]
	local bonus = EconomyMath.GetConditionBonus(coral, socket)
	local text, color, textColor
	if EconomyMath.IsConditionMatch(coral, socket) then
		text, color, textColor = "✓ Great fit", Theme.Colors.Seafoam, Theme.Colors.TextDark
	elseif bonus > 0 then
		text, color, textColor = "~ OK fit", Theme.Colors.Amber, Theme.Colors.TextDark
	else
		text, color, textColor = "No bonus", Theme.Colors.BlueLight, Theme.Colors.TextDark
	end
	UIKit.new("TextLabel", {
		Name = "Fit",
		Size = UDim2.new(1, -8, 0, 24),
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = textColor,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 5,
		Parent = parent,
	}, { UIKit.corner(Theme.Corner.Pill) })
end

local function makeCard(coralId: string, socketId: string, owned: number, order: number)
	local coral = CoralDefinitions[coralId]
	local socket = SocketDefinitions[socketId]
	local enabled = owned > 0
	local card = UIKit.new("TextButton", {
		Name = coralId,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if enabled then Theme.Colors.BlueInset else Theme.Colors.Disabled,
		LayoutOrder = order,
		Parent = grid,
	}, {
		UIKit.corner(Theme.Corner.M),
		UIKit.stroke(if enabled then Theme.Colors.BlueDark else Theme.Colors.DisabledDark, 3),
		UIKit.padding(6),
		UIKit.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local icon = CoralIcon.new(coralId, { Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 1 })
	icon.ImageTransparency = if enabled then 0 else 0.5
	icon.Parent = card

	UIKit.label({
		Size = UDim2.new(1, 0, 0, 22),
		Text = coral.displayName,
		TextSize = Theme.TextSize.Body,
		LayoutOrder = 2,
		Parent = card,
	})
	UIKit.label({
		Size = UDim2.new(1, 0, 0, 18),
		Text = ("Owned x%d  ·  ⏱ %s"):format(owned, formatDuration(coral.growSeconds)),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 3,
		Parent = card,
	})
	local stage = if EconomyMath.IsConditionMatch(coral, socket) then "Flourishing" else "Mature"
	UIKit.label({
		Size = UDim2.new(1, 0, 0, 18),
		Text = ("Earns ~%d 🐚"):format(EconomyMath.ComputeHarvestYield(coral, socket, stage)),
		TextColor3 = Theme.Colors.Gold,
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 4,
		Parent = card,
	})
	fitChip(card, coralId, socketId)

	if enabled then
		card.Activated:Connect(function()
			PlantTrayController.SelectCoral(coralId)
		end)
	end
end

function PlantTrayController.Refresh()
	local socketId = currentSocket
	local state = StateController.Get()
	if grid == nil or socketId == nil or state == nil then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Corals in unlocked zones; owned first, then by grow time
	local list = {}
	for coralId, coral in CoralDefinitions do
		if coral.zone <= state.unlocks.zone then
			table.insert(list, coralId)
		end
	end
	local fragments = state.inventory.fragments
	table.sort(list, function(a, b)
		local ownA, ownB = (fragments[a] or 0) > 0, (fragments[b] or 0) > 0
		if ownA ~= ownB then
			return ownA
		end
		return CoralDefinitions[a].growSeconds < CoralDefinitions[b].growSeconds
	end)
	for i, coralId in list do
		makeCard(coralId, socketId, fragments[coralId] or 0, i)
	end
end

function PlantTrayController.Open(socketId: string)
	if gui == nil then
		build()
	end
	currentSocket = socketId
	local socket = SocketDefinitions[socketId]
	if titleLabel then
		titleLabel.Text = if socket then socket.displayName else socketId
	end
	if socket and lightLabel and flowLabel then
		lightLabel.Text = HabitatIcons.Light[socket.light] .. " " .. HabitatIcons.LightLabel[socket.light]
		flowLabel.Text = HabitatIcons.Flow[socket.flow] .. " " .. HabitatIcons.FlowLabel[socket.flow]
	end
	PlantTrayController.Refresh()
	local screen = gui :: ScreenGui
	local panel = sheet :: Frame
	screen.Enabled = true
	panel.Position = UDim2.fromScale(0.5, 1.4)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -8) }):Play()
end

function PlantTrayController.Close()
	currentSocket = nil
	if gui then
		gui.Enabled = false
	end
end

function PlantTrayController.IsOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function PlantTrayController.SelectCoral(coralId: string)
	local socketId = currentSocket
	if socketId == nil or busy then
		return
	end
	busy = true
	local result = ClientNet.PlantCoral(socketId, coralId)
	busy = false
	if result.ok then
		PlantTrayController.Close()
	else
		warn("PlantTrayController: plant failed: " .. tostring(result.err))
	end
end

function PlantTrayController.Init()
	StateController.Changed:Connect(function(sliceKey: string)
		if PlantTrayController.IsOpen() and (sliceKey == "inventory" or sliceKey == "snapshot") then
			PlantTrayController.Refresh()
		end
	end)
end

return PlantTrayController
