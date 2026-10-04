--!strict
-- Always-on HUD: a left column with the Shells counter on top and side buttons (Shop teleport etc.) below,
-- all soft-cornered rectangles. Driven only by StateController, never by a remote.
-- The ScreenGui is built from code in Init(); requiring this module never yields.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local HUDController = {}

-- Fired when the player taps a HUD button: (buttonName)
HUDController.ButtonPressed = Signal.new() :: Signal.Signal<string>

local shellsLabel: TextLabel? = nil
local shellsScale: UIScale? = nil
local buttonColumn: Frame? = nil
local lastShells: number? = nil

local COLUMN_WIDTH = 168

-- 12345 -> "12,345"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function build(playerGui: PlayerGui)
	-- ResetOnSpawn = false so cached references survive character respawns
	local gui = UIKit.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1,
	})

	-- Left column: Shells counter first, then buttons registered by other controllers via AddButton
	local column = UIKit.new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Theme.Spacing.M, 0.42, 0),
		Size = UDim2.fromOffset(COLUMN_WIDTH, 320),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UIKit.new("UIListLayout", {
			Padding = UDim.new(0, Theme.Spacing.M),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Shells counter: gold coin bubble + count, a soft rectangle rather than a pill
	local pill, label = UIKit.pill({
		Name = "ShellsPill",
		Size = UDim2.fromOffset(COLUMN_WIDTH, 52),
		LayoutOrder = -1,
		Parent = column,
	}, "0", "🐚")
	label.Name = "ShellsLabel";
	(pill:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = Theme.Corner.M
	local scale = UIKit.new("UIScale", { Parent = pill })

	gui.Parent = playerGui
	shellsLabel = label
	shellsScale = scale
	buttonColumn = column
end

function HUDController.Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		warn("HUDController: Players.LocalPlayer.PlayerGui not found, HUD disabled")
		return
	end

	local existing = playerGui:FindFirstChild("HUD")
	if existing then
		existing:Destroy() -- leftover Studio-built HUD from before M0-10
	end
	build(playerGui)

	StateController.Changed:Connect(function(sliceKey: string)
		if sliceKey ~= "snapshot" and sliceKey ~= "currencies" then
			return
		end
		local state = StateController.Get()
		if state then
			HUDController.UpdateHUD(state)
		end
	end)

	-- The snapshot may have arrived before the HUD finished building
	local state = StateController.Get()
	if state then
		HUDController.UpdateHUD(state)
	end
end

function HUDController.UpdateHUD(state: Types.ClientState)
	local label = shellsLabel
	if label == nil then
		return
	end
	local shells = state.currencies.shells
	label.Text = formatNumber(shells)

	-- Pop the pill when the balance goes up
	if lastShells ~= nil and shells > lastShells and shellsScale then
		shellsScale.Scale = 1.15
		TweenService:Create(shellsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastShells = shells
end

-- Adds a soft-cornered rectangular button (icon + name) to the left column; fires ButtonPressed(name) when tapped
function HUDController.AddButton(name: string, icon: string, color: Color3?, darkColor: Color3?, order: number?): TextButton?
	local column = buttonColumn
	if column == nil then
		return nil
	end
	local button = UIKit.button({
		Name = name .. "Button",
		Text = "",
		Size = UDim2.fromOffset(COLUMN_WIDTH, 56),
		LayoutOrder = order or 0,
		Parent = column,
	}, color, darkColor);
	(button:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = Theme.Corner.M
	local dark = darkColor or Theme.Colors.BlueDark
	UIKit.new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		Text = icon,
		TextScaled = true,
		FontFace = Theme.Fonts.Body,
		Parent = button,
	})
	local caption = UIKit.label({
		Name = "Caption",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(1, -64, 1, -12),
		Text = name,
		TextScaled = true,
		Parent = button,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = Theme.TextSize.Title, Parent = caption })
	local captionStroke = caption:FindFirstChildOfClass("UIStroke")
	if captionStroke then
		captionStroke.Color = dark
	end
	button.Activated:Connect(function()
		HUDController.ButtonPressed:Fire(name)
	end)
	return button
end

return HUDController
