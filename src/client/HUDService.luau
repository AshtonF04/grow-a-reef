--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerState = Types.PlayerState

type Actions = {
	unlock: (string) -> (),
	plant: (string, string) -> (),
	harvest: (string) -> (),
}

type Card = {
	socketId: string,
	status: TextLabel,
	stroke: UIStroke,
	bar: Frame,
	fill: Frame,
	button: TextButton,
}

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
}

local HUDService = {}

local player = Players.LocalPlayer
local actions: Actions? = nil
local current: PlayerState? = nil
local cards: { [string]: Card } = {}
local announced: { [string]: boolean } = {}

local shellsValue: TextLabel? = nil
local stockValue: TextLabel? = nil
local nextValue: TextLabel? = nil
local toastFrame: Frame? = nil
local toastLabel: TextLabel? = nil
local cardList: ScrollingFrame? = nil
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

	local coralId = ReefRules.FirstFragment(state)
	if coralId then
		handler.plant(socketId, coralId)
	else
		HUDService.Toast(false, "You don't have a fragment to plant.")
	end
end

local function refreshCard(card: Card, state: PlayerState, now: number)
	local socket = SocketDefinitions[card.socketId]
	local placement = state.placements[card.socketId]
	card.status.Text = ReefRules.StatusLine(state, card.socketId, now)

	local mature = placement ~= nil and ReefRules.IsMature(placement.plantedAt, placement.coralId, now)
	card.status.TextColor3 = if mature then COLORS.gold else COLORS.muted
	card.stroke.Color = if mature then COLORS.gold else COLORS.line
	card.bar.Visible = placement ~= nil
	if placement then
		local progress = ReefRules.Progress(placement.plantedAt, placement.coralId, now)
		card.fill.Size = UDim2.fromScale(progress, 1)
		card.fill.BackgroundColor3 = COLORS.coral:Lerp(COLORS.good, progress)
	end

	if not state.socketUnlocks[card.socketId] then
		local block = ReefRules.UnlockBlock(state, card.socketId)
		local cost = if socket then socket.unlockCostShells else 0
		card.button.Text = string.format("Unlock  ·  %d shells", cost)
		styleButton(card.button, "unlock", block == nil or block.code == "shells")
		return
	end

	if placement then
		if mature then
			card.button.Text = "Harvest"
			styleButton(card.button, "harvest", true)
		else
			card.button.Text = "Growing"
			styleButton(card.button, "wait", false)
		end
		return
	end

	local coralId = ReefRules.FirstFragment(state)
	local coral = if coralId then CoralDefinitions[coralId] else nil
	if coral then
		card.button.Text = "Plant " .. coral.displayName
		styleButton(card.button, "plant", true)
	else
		card.button.Text = "Need a fragment"
		styleButton(card.button, "wait", false)
	end
end

local function buildCard(socketId: string, layoutOrder: number, state: PlayerState): Card
	local socket = SocketDefinitions[socketId]
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = "SocketCard"
	cardFrame.LayoutOrder = layoutOrder
	cardFrame.BackgroundColor3 = Color3.fromRGB(18, 48, 56)
	cardFrame.BackgroundTransparency = 0.12
	cardFrame.BorderSizePixel = 0
	cardFrame.Size = UDim2.new(1, -8, 0, 0)
	cardFrame.AutomaticSize = Enum.AutomaticSize.Y
	cardFrame.Parent = cardList
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

	local title = label(cardFrame, if socket then socket.displayName else socketId, 18, Fonts.Bold, COLORS.ink)
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 22)

	local conditions = label(cardFrame, ReefRules.ConditionText(socketId), 14, Fonts.Body, COLORS.muted)
	conditions.LayoutOrder = 2
	conditions.Size = UDim2.new(1, 0, 0, 18)

	local planted = state.placements[socketId]
	local coralId = (if planted then planted.coralId else ReefRules.FirstFragment(state)) or "sun_coral"
	local match = label(cardFrame, ReefRules.MatchText(coralId, socketId), 14, Fonts.Body, COLORS.ink)
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

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.LayoutOrder = 6
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, 32)
	button.Text = ""
	button.Parent = cardFrame
	corner(button, 8)
	button.Activated:Connect(function()
		perform(socketId)
	end)

	local card: Card = {
		socketId = socketId,
		status = status,
		stroke = stroke,
		bar = bar,
		fill = fill,
		button = button,
	}
	refreshCard(card, state, workspace:GetServerTimeNow())
	return card
end

local function fragmentLine(state: PlayerState): string
	local parts = {}
	for _, coral in CoralDefinitions do
		local count = state.fragments[coral.id] or 0
		if count > 0 then
			local suffix = if count == 1 then "fragment" else "fragments"
			table.insert(parts, string.format("%d %s %s", count, coral.displayName, suffix))
		end
	end
	if #parts == 0 then
		return "No coral fragments"
	end
	return table.concat(parts, "   ·   ")
end

function HUDService.Toast(ok: boolean, message: string)
	if not toastFrame or not toastLabel then
		return
	end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.TextColor3 = if ok then COLORS.ink else Color3.fromRGB(255, 196, 176)
	toastFrame.BackgroundColor3 = if ok then Color3.fromRGB(16, 54, 58) else Color3.fromRGB(72, 32, 28)
	toastFrame.Visible = true
	task.delay(3.4, function()
		if token == toastToken then
			toastFrame.Visible = false
		end
	end)
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

	toastFrame = Instance.new("Frame")
	toastFrame.Name = "Toast"
	toastFrame.AnchorPoint = Vector2.new(0.5, 0)
	toastFrame.Position = UDim2.new(0.5, 0, 0, 12)
	toastFrame.Size = UDim2.fromOffset(480, 0)
	toastFrame.AutomaticSize = Enum.AutomaticSize.Y
	toastFrame.BackgroundColor3 = Color3.fromRGB(16, 54, 58)
	toastFrame.BackgroundTransparency = 0.08
	toastFrame.BorderSizePixel = 0
	toastFrame.Visible = false
	toastFrame.Parent = gui
	corner(toastFrame, 10)
	local toastPad = Instance.new("UIPadding")
	toastPad.PaddingTop = UDim.new(0, 10)
	toastPad.PaddingBottom = UDim.new(0, 10)
	toastPad.PaddingLeft = UDim.new(0, 14)
	toastPad.PaddingRight = UDim.new(0, 14)
	toastPad.Parent = toastFrame
	toastLabel = label(toastFrame, "", 16, Fonts.Bold, COLORS.ink)
	toastLabel.TextWrapped = true
	toastLabel.TextXAlignment = Enum.TextXAlignment.Center
	toastLabel.Size = UDim2.new(1, 0, 0, 0)
	toastLabel.AutomaticSize = Enum.AutomaticSize.Y

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
	header.Size = UDim2.new(1, 0, 0, 132)
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

	shellsValue = label(shellRow, "0", 36, Fonts.Bold, COLORS.gold)
	shellsValue.Size = UDim2.fromOffset(0, 40)
	shellsValue.AutomaticSize = Enum.AutomaticSize.X
	local shellsCaption = label(shellRow, "shells", 18, Fonts.Body, COLORS.muted)
	shellsCaption.Size = UDim2.fromOffset(70, 40)

	stockValue = label(header, "Reading the reef...", 15, Fonts.Body, COLORS.ink)
	stockValue.Position = UDim2.fromOffset(0, 72)
	stockValue.Size = UDim2.new(1, 0, 0, 18)
	stockValue.TextTruncate = Enum.TextTruncate.AtEnd

	nextValue = label(header, "", 14, Fonts.Body, Color3.fromRGB(196, 228, 214))
	nextValue.Position = UDim2.fromOffset(0, 92)
	nextValue.Size = UDim2.new(1, 0, 0, 36)
	nextValue.TextWrapped = true
	nextValue.TextYAlignment = Enum.TextYAlignment.Top

	cardList = Instance.new("ScrollingFrame")
	cardList.Name = "Cards"
	cardList.BackgroundTransparency = 1
	cardList.BorderSizePixel = 0
	cardList.Position = UDim2.fromOffset(0, 136)
	cardList.Size = UDim2.new(1, 0, 1, -136)
	cardList.CanvasSize = UDim2.new()
	cardList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cardList.ScrollingDirection = Enum.ScrollingDirection.Y
	cardList.ScrollBarThickness = 5
	cardList.ScrollBarImageColor3 = Color3.fromRGB(150, 196, 190)
	cardList.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = cardList
end

function HUDService.Render(state: PlayerState)
	if not shellsValue or not stockValue or not nextValue or not cardList then
		return
	end
	current = state
	shellsValue.Text = tostring(state.shells)
	stockValue.Text = fragmentLine(state)
	nextValue.Text = ReefRules.NextStep(state, workspace:GetServerTimeNow())

	for _, child in cardList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(cards)

	for _, socket in ReefRules.OrderedSockets() do
		cards[socket.id] = buildCard(socket.id, socket.unlockOrder, state)
	end
end

function HUDService.Tick(state: PlayerState, now: number)
	if not nextValue then
		return
	end
	current = state
	nextValue.Text = ReefRules.NextStep(state, now)
	for _, card in cards do
		refreshCard(card, state, now)
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
