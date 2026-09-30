--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local CoralLooks = require(ReplicatedStorage.Shared.Config.CoralLooks)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local Types = require(ReplicatedStorage.Shared.Types)
local PlantChoice = require(script.Parent.PlantChoice)

type PlayerState = Types.PlayerState

type Actions = {
	unlock: (string) -> (),
	plant: (string, string) -> (),
	harvest: (string) -> (),
	buy: (string) -> (),
}

type Card = {
	socketId: string,
	match: TextLabel,
	status: TextLabel,
	stroke: UIStroke,
	bar: Frame,
	fill: Frame,
	button: TextButton,
	swap: TextButton,
}

type NurseryCard = {
	coralId: string,
	owned: TextLabel,
	home: TextLabel,
	stroke: UIStroke,
	button: TextButton,
}

type Tab = "reef" | "nursery"

local COLORS = {
	ink = Color3.fromRGB(236, 246, 242),
	muted = Color3.fromRGB(168, 198, 192),
	gold = Color3.fromRGB(242, 196, 96),
	coral = Color3.fromRGB(232, 122, 72),
	good = Color3.fromRGB(118, 196, 132),
	line = Color3.fromRGB(86, 122, 120),
	wait = Color3.fromRGB(70, 86, 90),
	waitInk = Color3.fromRGB(186, 196, 196),
	plantInk = Color3.fromRGB(36, 18, 12),
	harvestInk = Color3.fromRGB(14, 40, 28),
	unlockInk = Color3.fromRGB(42, 30, 10),
	card = Color3.fromRGB(18, 48, 56),
	tabIdle = Color3.fromRGB(14, 36, 42),
	tabActive = Color3.fromRGB(34, 78, 84),
}

local HEADER_HEIGHT = 132
local TAB_HEIGHT = 32

local HUDService = {}

local player = Players.LocalPlayer
local actions: Actions? = nil
local current: PlayerState? = nil
local cards: { [string]: Card } = {}
local nurseryCards: { [string]: NurseryCard } = {}
local announced: { [string]: boolean } = {}
local activeTab: Tab = "reef"

local panelFrame: Frame? = nil
local shellsValue: TextLabel? = nil
local stockValue: TextLabel? = nil
local nextValue: TextLabel? = nil
local toastFrame: Frame? = nil
local toastLabel: TextLabel? = nil
local cardList: ScrollingFrame? = nil
local nurseryList: ScrollingFrame? = nil
local reefTab: TextButton? = nil
local nurseryTab: TextButton? = nil
local nurseryTabStroke: UIStroke? = nil
local toastToken = 0

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function label(parent: Instance, text: string, size: number, font: Enum.Font, color: Color3): TextLabel
	local ui = Instance.new("TextLabel")
	ui.BackgroundTransparency = 1
	ui.BorderSizePixel = 0
	ui.Font = font
	ui.TextSize = size
	ui.TextColor3 = color
	ui.TextXAlignment = Enum.TextXAlignment.Left
	ui.TextYAlignment = Enum.TextYAlignment.Center
	ui.Text = text
	ui.Parent = parent
	return ui
end

local function styleButton(button: TextButton, kind: string, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.Font = Fonts.Bold
	button.TextSize = 16
	if not enabled then
		button.BackgroundColor3 = COLORS.wait
		button.TextColor3 = COLORS.waitInk
		return
	end
	if kind == "harvest" then
		button.BackgroundColor3 = COLORS.good
		button.TextColor3 = COLORS.harvestInk
	elseif kind == "plant" then
		button.BackgroundColor3 = COLORS.coral
		button.TextColor3 = COLORS.plantInk
	else
		button.BackgroundColor3 = COLORS.gold
		button.TextColor3 = COLORS.unlockInk
	end
end

local function makeCardFrame(parent: Instance, layoutOrder: number): (Frame, UIStroke)
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = "Card"
	cardFrame.LayoutOrder = layoutOrder
	cardFrame.BackgroundColor3 = COLORS.card
	cardFrame.BackgroundTransparency = 0.12
	cardFrame.BorderSizePixel = 0
	cardFrame.Size = UDim2.new(1, -8, 0, 0)
	cardFrame.AutomaticSize = Enum.AutomaticSize.Y
	cardFrame.Parent = parent
	corner(cardFrame, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.4
	stroke.Color = COLORS.line
	stroke.Transparency = 0.2
	stroke.Parent = cardFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = cardFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cardFrame

	return cardFrame, stroke
end

local function shortName(coralId: string): string
	local coral = CoralDefinitions[coralId]
	if not coral then
		return coralId
	end
	return (string.gsub(coral.displayName, " Coral$", ""))
end

local function perform(socketId: string)
	local state = current
	local handler = actions
	if not state or not handler then
		return
	end
	local now = workspace:GetServerTimeNow()
	if not state.socketUnlocks[socketId] then
		local block = ReefRules.UnlockBlock(state, socketId)
		if block and block.code == "order" then
			HUDService.Toast(false, block.message)
			return
		end
		handler.unlock(socketId)
		return
	end

	local placement = state.placements[socketId]
	if placement then
		if ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
			handler.harvest(socketId)
		end
		return
	end

	local coralId = PlantChoice.For(state, socketId)
	if coralId then
		handler.plant(socketId, coralId)
	else
		HUDService.SetTab("nursery")
		HUDService.Toast(false, "You don't have a fragment. Buy one in the Nursery.")
	end
end

local function refreshCard(card: Card, state: PlayerState, now: number)
	local socket = SocketDefinitions[card.socketId]
	local placement = state.placements[card.socketId]
	local choice = PlantChoice.For(state, card.socketId)
	card.status.Text = ReefRules.StatusLine(state, card.socketId, now, choice)

	local home = ReefRules.HomeCoral(card.socketId)
	local shownCoral = if placement then placement.coralId elseif choice then choice elseif home then home.id else nil
	card.match.Text = if shownCoral then ReefRules.MatchText(shownCoral, card.socketId) else ""
	card.match.TextColor3 = if shownCoral and ReefRules.Fit(shownCoral, card.socketId) == "flourishing"
		then COLORS.good
		else COLORS.ink

	local mature = placement ~= nil and ReefRules.IsMature(placement.plantedAt, placement.coralId, now)
	card.status.TextColor3 = if mature then COLORS.gold else COLORS.muted
	card.stroke.Color = if mature then COLORS.gold else COLORS.line
	card.bar.Visible = placement ~= nil
	if placement then
		local progress = ReefRules.Progress(placement.plantedAt, placement.coralId, now)
		card.fill.Size = UDim2.fromScale(progress, 1)
		card.fill.BackgroundColor3 = COLORS.coral:Lerp(COLORS.good, progress)
	end

	local unlocked = state.socketUnlocks[card.socketId] == true
	card.swap.Visible = unlocked and placement == nil and PlantChoice.CanCycle(state)

	if not unlocked then
		local block = ReefRules.UnlockBlock(state, card.socketId)
		local cost = if socket then socket.unlockCostShells else 0
		card.button.Text = string.format("Unlock  ·  %d shells", cost)
		styleButton(card.button, "unlock", block == nil or block.code == "shells")
		return
	end

	if placement then
		if mature then
			card.button.Text = string.format("Harvest  ·  +%d shells", ReefRules.HarvestYield(placement.coralId, card.socketId))
			styleButton(card.button, "harvest", true)
		else
			card.button.Text = "Growing"
			styleButton(card.button, "wait", false)
		end
		return
	end

	local coral = if choice then CoralDefinitions[choice] else nil
	if coral then
		card.button.Text = "Plant " .. coral.displayName
		styleButton(card.button, "plant", true)
	else
		card.button.Text = "Get a fragment in the Nursery"
		styleButton(card.button, "unlock", true)
	end
end

local function buildCard(parent: Instance, socketId: string, layoutOrder: number, state: PlayerState): Card
	local socket = SocketDefinitions[socketId]
	local cardFrame, stroke = makeCardFrame(parent, layoutOrder)

	local title = label(cardFrame, if socket then socket.displayName else socketId, 18, Fonts.Bold, COLORS.ink)
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 22)

	local conditions = label(cardFrame, ReefRules.ConditionText(socketId), 14, Fonts.Body, COLORS.muted)
	conditions.LayoutOrder = 2
	conditions.Size = UDim2.new(1, 0, 0, 18)

	local match = label(cardFrame, "", 14, Fonts.Body, COLORS.ink)
	match.LayoutOrder = 3
	match.TextWrapped = true
	match.Size = UDim2.new(1, 0, 0, 0)
	match.AutomaticSize = Enum.AutomaticSize.Y

	local status = label(cardFrame, "", 14, Fonts.Bold, COLORS.muted)
	status.LayoutOrder = 4
	status.Size = UDim2.new(1, 0, 0, 18)

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.LayoutOrder = 5
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = Color3.fromRGB(8, 22, 26)
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.Parent = cardFrame
	corner(bar, 4)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = COLORS.coral
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	corner(fill, 4)

	local row = Instance.new("Frame")
	row.Name = "Actions"
	row.LayoutOrder = 6
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 32)
	row.Parent = cardFrame
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.LayoutOrder = 1
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 1, 0)
	button.Text = ""
	button.Parent = row
	corner(button, 8)
	button.Activated:Connect(function()
		perform(socketId)
	end)

	local swap = Instance.new("TextButton")
	swap.Name = "Swap"
	swap.LayoutOrder = 2
	swap.BorderSizePixel = 0
	swap.Size = UDim2.new(0, 64, 1, 0)
	swap.BackgroundColor3 = COLORS.tabActive
	swap.TextColor3 = COLORS.ink
	swap.Font = Fonts.Bold
	swap.TextSize = 14
	swap.Text = "Swap"
	swap.Visible = false
	swap.Parent = row
	corner(swap, 8)

	local card: Card = {
		socketId = socketId,
		match = match,
		status = status,
		stroke = stroke,
		bar = bar,
		fill = fill,
		button = button,
		swap = swap,
	}

	swap:GetPropertyChangedSignal("Visible"):Connect(function()
		button.Size = if swap.Visible then UDim2.new(1, -70, 1, 0) else UDim2.new(1, 0, 1, 0)
	end)
	swap.Activated:Connect(function()
		local latest = current
		if latest then
			PlantChoice.Cycle(latest, socketId)
			refreshCard(card, latest, workspace:GetServerTimeNow())
		end
	end)

	refreshCard(card, state, workspace:GetServerTimeNow())
	return card
end

local function refreshNurseryCard(card: NurseryCard, state: PlayerState, recommended: boolean)
	local coral = CoralDefinitions[card.coralId]
	if not coral then
		return
	end
	local owned = state.fragments[card.coralId] or 0
	card.owned.Text = if owned > 0 then string.format("Owned  %d", owned) else ""

	local home = ReefRules.HomeSocket(card.coralId)
	if home then
		local open = state.socketUnlocks[home.id] == true
		card.home.Text = string.format(
			"Flourishes on %s%s  ·  %d shells there",
			home.displayName,
			if open then "" else " (locked)",
			ReefRules.HarvestYield(card.coralId, home.id)
		)
	else
		card.home.Text = ""
	end

	local block = ReefRules.BuyBlock(state, card.coralId)
	card.stroke.Color = if recommended then COLORS.gold else COLORS.line
	if block and block.code == "full" then
		card.button.Text = "Hands full"
		styleButton(card.button, "wait", false)
	else
		card.button.Text = string.format("Buy fragment  ·  %d shells", coral.nurseryCost)
		styleButton(card.button, "plant", block == nil)
	end
end

local function buildNurseryCard(parent: Instance, coralId: string, layoutOrder: number): NurseryCard
	local coral = CoralDefinitions[coralId]
	local look = CoralLooks.Get(coralId)
	local cardFrame, stroke = makeCardFrame(parent, layoutOrder)

	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, 24)
	top.Parent = cardFrame

	local swatch = Instance.new("Frame")
	swatch.BorderSizePixel = 0
	swatch.Size = UDim2.fromOffset(18, 18)
	swatch.Position = UDim2.fromOffset(0, 3)
	swatch.BackgroundColor3 = look.body
	swatch.Parent = top
	corner(swatch, 9)
	local swatchStroke = Instance.new("UIStroke")
	swatchStroke.Color = look.tip
	swatchStroke.Thickness = 2
	swatchStroke.Parent = swatch

	local title = label(top, if coral then coral.displayName else coralId, 18, Fonts.Bold, COLORS.ink)
	title.Position = UDim2.fromOffset(26, 0)
	title.Size = UDim2.new(1, -110, 1, 0)

	local owned = label(top, "", 14, Fonts.Bold, COLORS.gold)
	owned.AnchorPoint = Vector2.new(1, 0)
	owned.Position = UDim2.new(1, 0, 0, 0)
	owned.Size = UDim2.new(0, 80, 1, 0)
	owned.TextXAlignment = Enum.TextXAlignment.Right

	local facts = if coral
		then string.format(
			"%s light  ·  %s flow  ·  grows in %s",
			coral.light,
			coral.flow,
			ReefRules.FormatTime(ReefRules.GrowDuration(coralId))
		)
		else ""
	local conditions = label(cardFrame, facts, 14, Fonts.Body, COLORS.muted)
	conditions.LayoutOrder = 2
	conditions.Size = UDim2.new(1, 0, 0, 18)

	local home = label(cardFrame, "", 14, Fonts.Body, COLORS.ink)
	home.LayoutOrder = 3
	home.TextWrapped = true
	home.Size = UDim2.new(1, 0, 0, 0)
	home.AutomaticSize = Enum.AutomaticSize.Y

	local button = Instance.new("TextButton")
	button.Name = "Buy"
	button.LayoutOrder = 4
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, 32)
	button.Text = ""
	button.Parent = cardFrame
	corner(button, 8)
	button.Activated:Connect(function()
		local handler = actions
		local state = current
		if not handler or not state then
			return
		end
		local block = ReefRules.BuyBlock(state, coralId)
		if block then
			HUDService.Toast(false, block.message)
			return
		end
		handler.buy(coralId)
	end)

	return {
		coralId = coralId,
		owned = owned,
		home = home,
		stroke = stroke,
		button = button,
	}
end

local function fragmentLine(state: PlayerState): string
	local parts = {}
	for _, coralId in ReefRules.OwnedCorals(state) do
		table.insert(parts, string.format("%s %d", shortName(coralId), state.fragments[coralId] or 0))
	end
	if #parts == 0 then
		return "No coral fragments"
	end
	return "Fragments   " .. table.concat(parts, "  ·  ")
end

local function makeList(parent: Instance, name: string): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name = name
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, HEADER_HEIGHT + TAB_HEIGHT + 10)
	list.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_HEIGHT + 10))
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = Color3.fromRGB(150, 196, 190)
	list.Parent = parent

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	return list
end

local function makeTab(parent: Instance, text: string, position: UDim2): (TextButton, UIStroke)
	local tab = Instance.new("TextButton")
	tab.BorderSizePixel = 0
	tab.AutoButtonColor = true
	tab.Position = position
	tab.Size = UDim2.new(0.5, -4, 0, TAB_HEIGHT)
	tab.Font = Fonts.Bold
	tab.TextSize = 16
	tab.TextColor3 = COLORS.ink
	tab.Text = text
	tab.Parent = parent
	corner(tab, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.4
	stroke.Color = COLORS.line
	stroke.Parent = tab
	return tab, stroke
end

function HUDService.SetTab(tab: Tab)
	activeTab = tab
	if cardList then
		cardList.Visible = tab == "reef"
	end
	if nurseryList then
		nurseryList.Visible = tab == "nursery"
	end
	if reefTab then
		reefTab.BackgroundColor3 = if tab == "reef" then COLORS.tabActive else COLORS.tabIdle
	end
	if nurseryTab then
		nurseryTab.BackgroundColor3 = if tab == "nursery" then COLORS.tabActive else COLORS.tabIdle
	end
end

function HUDService.Toast(ok: boolean, message: string)
	local frame = toastFrame
	local text = toastLabel
	if not frame or not text then
		return
	end
	toastToken += 1
	local token = toastToken
	text.Text = message
	text.TextColor3 = if ok then COLORS.ink else Color3.fromRGB(255, 196, 176)
	frame.BackgroundColor3 = if ok then Color3.fromRGB(16, 54, 58) else Color3.fromRGB(72, 32, 28)
	frame.Visible = true
	task.delay(3.4, function()
		if token == toastToken then
			frame.Visible = false
		end
	end)
end

-- Screen areas the guide covers, in viewport pixels. World markers stay out of them.
function HUDService.CoveredRects(): { Rect }
	local panel = panelFrame
	if not panel or not panel.Visible then
		return {}
	end
	local inset = GuiService:GetGuiInset()
	local min = panel.AbsolutePosition + inset
	return { Rect.new(min, min + panel.AbsoluteSize) }
end

function HUDService.Start(actionFns: Actions)
	actions = actionFns
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("ReefHUD")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ReefHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 12)
	toast.Size = UDim2.fromOffset(480, 0)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundColor3 = Color3.fromRGB(16, 54, 58)
	toast.BackgroundTransparency = 0.08
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.Parent = gui
	corner(toast, 10)
	local toastPad = Instance.new("UIPadding")
	toastPad.PaddingTop = UDim.new(0, 10)
	toastPad.PaddingBottom = UDim.new(0, 10)
	toastPad.PaddingLeft = UDim.new(0, 14)
	toastPad.PaddingRight = UDim.new(0, 14)
	toastPad.Parent = toast
	local toastText = label(toast, "", 16, Fonts.Bold, COLORS.ink)
	toastText.TextWrapped = true
	toastText.TextXAlignment = Enum.TextXAlignment.Center
	toastText.Size = UDim2.new(1, 0, 0, 0)
	toastText.AutomaticSize = Enum.AutomaticSize.Y
	toastFrame = toast
	toastLabel = toastText

	local panel = Instance.new("Frame")
	panel.Name = "Guide"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 8)
	panel.Size = UDim2.new(0, 332, 1, -20)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Parent = gui
	corner(panel, 14)
	panelFrame = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(150, 196, 190)
	panelStroke.Transparency = 0.4
	panelStroke.Thickness = 1.5
	panelStroke.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 52, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 28, 36)),
	})
	gradient.Parent = panel

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.Parent = panel

	local title = label(header, "Grow a Reef", 22, Fonts.Bold, COLORS.ink)
	title.Size = UDim2.new(1, 0, 0, 28)

	local shellRow = Instance.new("Frame")
	shellRow.BackgroundTransparency = 1
	shellRow.Position = UDim2.fromOffset(0, 30)
	shellRow.Size = UDim2.new(1, 0, 0, 40)
	shellRow.Parent = header
	local shellLayout = Instance.new("UIListLayout")
	shellLayout.FillDirection = Enum.FillDirection.Horizontal
	shellLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	shellLayout.Padding = UDim.new(0, 8)
	shellLayout.Parent = shellRow

	local shells = label(shellRow, "0", 36, Fonts.Bold, COLORS.gold)
	shells.Size = UDim2.fromOffset(0, 40)
	shells.AutomaticSize = Enum.AutomaticSize.X
	local shellsCaption = label(shellRow, "shells", 18, Fonts.Body, COLORS.muted)
	shellsCaption.Size = UDim2.fromOffset(70, 40)
	shellsValue = shells

	local stock = label(header, "Reading the reef...", 15, Fonts.Body, COLORS.ink)
	stock.Position = UDim2.fromOffset(0, 72)
	stock.Size = UDim2.new(1, 0, 0, 18)
	stock.TextTruncate = Enum.TextTruncate.AtEnd
	stockValue = stock

	local nextLine = label(header, "", 14, Fonts.Body, Color3.fromRGB(196, 228, 214))
	nextLine.Position = UDim2.fromOffset(0, 92)
	nextLine.Size = UDim2.new(1, 0, 0, 36)
	nextLine.TextWrapped = true
	nextLine.TextYAlignment = Enum.TextYAlignment.Top
	nextValue = nextLine

	local reefButton = makeTab(panel, "Reef", UDim2.fromOffset(0, HEADER_HEIGHT + 4))
	local nurseryButton, nurseryStroke = makeTab(panel, "Nursery", UDim2.new(0.5, 4, 0, HEADER_HEIGHT + 4))
	reefButton.Activated:Connect(function()
		HUDService.SetTab("reef")
	end)
	nurseryButton.Activated:Connect(function()
		HUDService.SetTab("nursery")
	end)
	reefTab = reefButton
	nurseryTab = nurseryButton
	nurseryTabStroke = nurseryStroke

	cardList = makeList(panel, "Cards")
	nurseryList = makeList(panel, "Nursery")
	HUDService.SetTab(activeTab)
end

local function clearCards(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

function HUDService.Render(state: PlayerState)
	local shells = shellsValue
	local stock = stockValue
	local reefList = cardList
	local shopList = nurseryList
	if not shells or not stock or not reefList or not shopList then
		return
	end
	current = state
	shells.Text = tostring(state.shells)
	stock.Text = fragmentLine(state)

	clearCards(reefList)
	table.clear(cards)
	for _, socket in ReefRules.OrderedSockets() do
		cards[socket.id] = buildCard(reefList, socket.id, socket.unlockOrder, state)
	end

	if next(nurseryCards) == nil then
		for index, coral in ReefRules.OrderedCorals() do
			nurseryCards[coral.id] = buildNurseryCard(shopList, coral.id, index)
		end
	end

	HUDService.Tick(state, workspace:GetServerTimeNow())
end

function HUDService.Tick(state: PlayerState, now: number)
	local nextLine = nextValue
	if not nextLine then
		return
	end
	current = state
	local text, kind, target = ReefRules.NextStep(state, now)
	nextLine.Text = text

	for _, card in cards do
		refreshCard(card, state, now)
	end

	local recommended = if kind == "buy" and target then ReefRules.HomeCoral(target) else nil
	for coralId, card in nurseryCards do
		refreshNurseryCard(card, state, recommended ~= nil and recommended.id == coralId)
	end
	if nurseryTabStroke then
		nurseryTabStroke.Color = if kind == "buy" and activeTab ~= "nursery" then COLORS.gold else COLORS.line
		nurseryTabStroke.Thickness = if kind == "buy" and activeTab ~= "nursery" then 2.4 else 1.4
	end

	for _, socket in ReefRules.OrderedSockets() do
		local placement = state.placements[socket.id]
		if placement and ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
			local key = socket.id .. ":" .. tostring(placement.plantedAt)
			if not announced[key] then
				announced[key] = true
				local coral = CoralDefinitions[placement.coralId]
				local coralName = if coral then coral.displayName else "Coral"
				HUDService.Toast(true, string.format("%s on %s is ready to harvest.", coralName, socket.displayName))
			end
		end
	end
end

return HUDService
