--!strict
-- Always-on HUD (Shells counter + side buttons). Driven only by StateController, never by a remote.
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

	-- Shells pill, top centre: gold coin bubble + count, like the reference's currency pill
	local pill, label = UIKit.pill({
		Name = "ShellsPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Theme.Spacing.S),
		Size = UDim2.fromOffset(200, 52),
		Parent = gui,
	}, "0", "🐚")
	label.Name = "ShellsLabel"
	local scale = UIKit.new("UIScale", { Parent = pill })

	-- Left-side button column (Shop etc.), registered by other controllers via AddButton
	local column = UIKit.new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Theme.Spacing.M, 0.5, 0),
		Size = UDim2.fromOffset(84, 320),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UIKit.new("UIListLayout", {
			Padding = UDim.new(0, Theme.Spacing.M),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

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

-- Adds a round button with a caption to the left column; fires ButtonPressed(name) when tapped
function HUDController.AddButton(name: string, icon: string, color: Color3?, darkColor: Color3?, order: number?): TextButton?
	local column = buttonColumn
	if column == nil then
		return nil
	end
	local button = UIKit.circleButton({
		Name = name .. "Button",
		Text = "",
		LayoutOrder = order or 0,
		Parent = column,
	}, 76, color, darkColor)
	UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.6, 0.6),
		Text = icon,
		TextScaled = true,
		FontFace = Theme.Fonts.Body,
		Parent = button,
	})
	UIKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 8, 0, 24),
		Text = name,
		TextSize = Theme.TextSize.Body,
		Parent = button,
	})
	button.Activated:Connect(function()
		HUDController.ButtonPressed:Fire(name)
	end)
	return button
end

return HUDController
