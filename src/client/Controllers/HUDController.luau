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

local function build(playerGui: PlayerGui)
	-- ResetOnSpawn = false so cached references survive character respawns
	local gui = UIKit.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1,
	})

	-- Shells pill, top centre
	local pill = UIKit.new("Frame", {
		Name = "ShellsPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Theme.Spacing.S),
		Size = UDim2.fromOffset(190, 50),
		BackgroundColor3 = Theme.Colors.DeepTeal,
		Parent = gui,
	}, {
		UIKit.corner(Theme.Corner.Pill),
		UIKit.stroke(Theme.Colors.DeepTealDark, 4),
		UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
	})
	local scale = UIKit.new("UIScale", { Parent = pill })

	-- Shell icon bubble overlapping the left edge of the pill
	UIKit.new("Frame", {
		Name = "IconBubble",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = Theme.Colors.Sand,
		Parent = pill,
	}, {
		UIKit.corner(Theme.Corner.Pill),
		UIKit.stroke(Theme.Colors.SandDark, 4),
		UIKit.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "🐚",
			TextScaled = true,
			FontFace = Theme.Fonts.Display,
		}, { UIKit.padding(8) }),
	})

	local label = UIKit.label({
		Name = "ShellsLabel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 44, 0.5, 0),
		Size = UDim2.new(1, -56, 1, -12),
		Text = "Shells: 0",
		TextSize = Theme.TextSize.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = pill,
	})

	-- Left-side button column (Shop etc.), registered by other controllers via AddButton
	local column = UIKit.new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Theme.Spacing.M, 0.5, 0),
		Size = UDim2.fromOffset(84, 300),
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
	label.Text = "Shells: " .. shells

	-- Pop the pill when the balance goes up
	if lastShells ~= nil and shells > lastShells and shellsScale then
		shellsScale.Scale = 1.15
		TweenService:Create(shellsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastShells = shells
end

-- Adds a square button to the left column; fires ButtonPressed(name) when tapped
function HUDController.AddButton(name: string, icon: string, color: Color3?, darkColor: Color3?, order: number?): TextButton?
	local column = buttonColumn
	if column == nil then
		return nil
	end
	local button = UIKit.button({
		Name = name .. "Button",
		Size = UDim2.fromOffset(84, 84),
		Text = "",
		LayoutOrder = order or 0,
		Parent = column,
	}, color, darkColor)
	UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.62),
		Position = UDim2.fromScale(0, 0.04),
		Text = icon,
		TextScaled = true,
		FontFace = Theme.Fonts.Display,
		Parent = button,
	})
	UIKit.label({
		Size = UDim2.fromScale(1, 0.32),
		Position = UDim2.fromScale(0, 0.64),
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
