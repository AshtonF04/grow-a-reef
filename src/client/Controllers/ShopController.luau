--!strict
-- Coral fragment shop. The catalog (prices, availability) comes from the server; affordability is
-- refreshed live from StateController so the panel reacts instantly as Shells change.
-- Opened from the hub shop stall's prompt (ShopBoothController); the server only sells near the stall.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local HabitatIcons = require(ReplicatedStorage.Shared.Config.HabitatIcons)
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local CoralIcon = require(script.Parent.Parent.UI.CoralIcon)
local Toast = require(script.Parent.Parent.UI.Toast)

type FragmentEntry = { coralId: string, price: number }

local ShopController = {}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local list: ScrollingFrame? = nil
local catalog: { FragmentEntry } = {}
local rows: { [string]: { button: TextButton, owned: TextLabel } } = {}
local busy = false

local function formatDuration(seconds: number): string
	if seconds >= 60 then
		return string.format("%dm", math.floor(seconds / 60 + 0.5))
	end
	return seconds .. "s"
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = UIKit.new("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local window = UIKit.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromScale(0.9, 0.72),
		Parent = screen,
	}, "Coral Shop", function()
		ShopController.Close()
	end)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(480, 560), Parent = window.frame })
	UIKit.new("UIScale", { Parent = window.frame })

	local scroll = UIKit.new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.BlueLight,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window.content,
	}, {
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4) }),
	})

	screen.Parent = playerGui
	gui = screen
	panel = window.frame
	list = scroll
end

local function makeRow(entry: FragmentEntry, order: number)
	local coral = CoralDefinitions[entry.coralId]
	local row = UIKit.new("Frame", {
		Name = entry.coralId,
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = Theme.Colors.BlueInset,
		LayoutOrder = order,
		Parent = list,
	}, {
		UIKit.corner(Theme.Corner.M),
		UIKit.stroke(Theme.Colors.BlueDark, 3),
	})
	local iconBubble = UIKit.new("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Theme.Colors.BlueLight,
		Parent = row,
	}, { UIKit.corner(Theme.Corner.M), UIKit.stroke(Theme.Colors.BlueDark, 2) })
	local icon = CoralIcon.new(entry.coralId, { Size = UDim2.fromScale(1, 1) })
	icon.Parent = iconBubble

	UIKit.label({
		Position = UDim2.fromOffset(98, 8),
		Size = UDim2.new(1, -234, 0, 28),
		Text = coral.displayName,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = Theme.TextSize.Title,
		Parent = row,
	})
	UIKit.label({
		Position = UDim2.fromOffset(98, 38),
		Size = UDim2.new(1, -234, 0, 20),
		Text = ("⏱ %s  ·  %s %s  ·  ~%d 🐚"):format(
			formatDuration(coral.growSeconds),
			HabitatIcons.Light[coral.light],
			HabitatIcons.Flow[coral.flow],
			coral.baseYield
		),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		Parent = row,
	})
	local owned = UIKit.label({
		Position = UDim2.fromOffset(98, 62),
		Size = UDim2.new(1, -234, 0, 20),
		Text = "Owned x0",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Gold,
		TextSize = Theme.TextSize.Small,
		Parent = row,
	})

	local button = UIKit.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(124, 52),
		Text = "Buy " .. entry.price .. " 🐚",
		TextSize = Theme.TextSize.Body,
		Parent = row,
	}, Theme.Colors.Green, Theme.Colors.GreenDark)
	button.Activated:Connect(function()
		ShopController.Buy(entry.coralId)
	end)
	rows[entry.coralId] = { button = button, owned = owned }
end

-- Re-applies owned counts and affordability from the local state mirror (no server call)
local function applyState()
	local state = StateController.Get()
	local shells = if state then state.currencies.shells else 0
	for _, entry in catalog do
		local row = rows[entry.coralId]
		if row then
			local count = if state then state.inventory.fragments[entry.coralId] or 0 else 0
			row.owned.Text = "Owned x" .. count
			local affordable = shells >= entry.price
			row.button.Active = affordable
			if affordable then
				row.button.Text = "Buy " .. entry.price .. " 🐚"
				UIKit.setButtonColor(row.button, Theme.Colors.Green, Theme.Colors.GreenDark)
			else
				row.button.Text = "Need " .. (entry.price - shells) .. " more"
				UIKit.setButtonColor(row.button, Theme.Colors.Disabled, Theme.Colors.DisabledDark)
			end
		end
	end
end

function ShopController.Refresh()
	if list == nil then
		return
	end
	local result = ClientNet.GetCatalog()
	if not result.ok then
		return -- ClientNet already showed the error toast
	end
	catalog = result.value.fragments
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(rows)
	for i, entry in catalog do
		makeRow(entry, i)
	end
	applyState()
end

function ShopController.Buy(coralId: string)
	if busy then
		return -- ignore taps while a purchase is in flight
	end
	local state = StateController.Get()
	local entry = nil
	for _, e in catalog do
		if e.coralId == coralId then
			entry = e
		end
	end
	if state == nil or entry == nil or state.currencies.shells < entry.price then
		return
	end
	busy = true
	local result = ClientNet.BuyFragment(coralId, 1)
	busy = false
	if result.ok then
		Toast.Success(("+1 %s fragment"):format(CoralDefinitions[coralId].displayName))
	end
end

function ShopController.Open()
	if gui == nil then
		build()
	end
	local screen = gui :: ScreenGui
	screen.Enabled = true
	local scale = (panel :: Frame):FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	ShopController.Refresh()
end

function ShopController.Close()
	if gui then
		gui.Enabled = false
	end
end

function ShopController.IsOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function ShopController.Toggle()
	if gui and gui.Enabled then
		ShopController.Close()
	else
		ShopController.Open()
	end
end

function ShopController.Init()
	StateController.Changed:Connect(function(sliceKey: string)
		if gui == nil or not gui.Enabled then
			return
		end
		if sliceKey == "unlocks" then
			ShopController.Refresh() -- zones may add new corals
		elseif sliceKey == "currencies" or sliceKey == "inventory" or sliceKey == "snapshot" then
			applyState()
		end
	end)
end

return ShopController
