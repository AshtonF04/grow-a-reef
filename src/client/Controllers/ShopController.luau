--!strict
-- Coral fragment shop. The catalog (prices, availability) comes from the server; affordability is
-- refreshed live from StateController so the panel reacts instantly as Shells change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local CoralIcon = require(script.Parent.Parent.UI.CoralIcon)

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

	local frame = UIKit.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.72),
		BackgroundColor3 = Theme.Colors.DeepTeal,
		Parent = screen,
	}, {
		UIKit.corner(Theme.Corner.L),
		UIKit.stroke(Theme.Colors.DeepTealDark, 4),
		UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(480, 560) }),
		UIKit.padding(Theme.Spacing.L),
	})
	UIKit.new("UIScale", { Parent = frame })

	UIKit.label({
		Name = "Title",
		Size = UDim2.new(1, -60, 0, 40),
		Text = "🛒 Coral Shop",
		TextSize = Theme.TextSize.Big,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local close = UIKit.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 44),
		Text = "X",
		TextSize = Theme.TextSize.Title,
		Parent = frame,
	}, Color3.fromRGB(220, 70, 70), Color3.fromRGB(150, 40, 40))
	close.Activated:Connect(function()
		ShopController.Close()
	end)

	local scroll = UIKit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, {
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})

	screen.Parent = playerGui
	gui = screen
	panel = frame
	list = scroll
end

local function makeRow(entry: FragmentEntry, order: number)
	local coral = CoralDefinitions[entry.coralId]
	local row = UIKit.new("Frame", {
		Name = entry.coralId,
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = Theme.Colors.Sand,
		LayoutOrder = order,
		Parent = list,
	}, {
		UIKit.corner(Theme.Corner.M),
		UIKit.stroke(Theme.Colors.SandDark, 3),
	})
	local icon = CoralIcon.new(entry.coralId, { Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(6, 6) })
	icon.Parent = row

	UIKit.new("TextLabel", {
		Position = UDim2.fromOffset(96, 8),
		Size = UDim2.new(1, -230, 0, 28),
		BackgroundTransparency = 1,
		Text = coral.displayName,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.TextDark,
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.TextSize.Title,
		Parent = row,
	})
	UIKit.new("TextLabel", {
		Position = UDim2.fromOffset(96, 38),
		Size = UDim2.new(1, -230, 0, 20),
		BackgroundTransparency = 1,
		Text = ("⏱ %s  ·  %s %s  ·  ~%d 🐚"):format(
			formatDuration(coral.growSeconds),
			if coral.light == "Bright" then "☀️" else "🌙",
			coral.flow,
			coral.baseYield
		),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.TextDark,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		Parent = row,
	})
	local owned = UIKit.new("TextLabel", {
		Position = UDim2.fromOffset(96, 62),
		Size = UDim2.new(1, -230, 0, 20),
		BackgroundTransparency = 1,
		Text = "Owned x0",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.SeafoamDark,
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.TextSize.Small,
		Parent = row,
	})

	local button = UIKit.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(120, 56),
		Text = "Buy " .. entry.price .. " 🐚",
		TextSize = Theme.TextSize.Body,
		Parent = row,
	})
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
			row.button.AutoButtonColor = false
			if affordable then
				row.button.Text = "Buy " .. entry.price .. " 🐚"
				row.button.BackgroundColor3 = Theme.Colors.CoralOrange
			else
				row.button.Text = "Need " .. (entry.price - shells) .. " more"
				row.button.BackgroundColor3 = Theme.Colors.Muted
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
		warn("ShopController: catalog failed: " .. tostring(result.err))
		return
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
	if not result.ok then
		warn("ShopController: buy failed: " .. tostring(result.err))
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
