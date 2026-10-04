--!strict
-- Draws every ProximityPrompt with Style = Custom in the cartoon-blue style: a round blue key bubble
-- ("E", the gamepad button, or a tap icon on touch) next to a pill with the action/object text, plus a
-- fill bar while a hold is in progress. The key bubble is clickable/tappable.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local PromptController = {}

local folder: Folder? = nil

local GAMEPAD_NAMES: { [string]: string } = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
}

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "👆"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return GAMEPAD_NAMES[name] or name
	end
	local text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if text ~= "" then text:upper() else prompt.KeyboardKeyCode.Name
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local adornee = prompt.Parent
	if folder == nil or adornee == nil or not (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model")) then
		return
	end

	local gui = UIKit.new("BillboardGui", {
		Name = "Prompt_" .. adornee.Name,
		Adornee = adornee,
		Size = UDim2.fromOffset(250, 70),
		StudsOffset = Vector3.new(0, 2.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Active = true,
	})
	local root = UIKit.new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local scale = UIKit.new("UIScale", { Scale = 0, Parent = root })

	-- Round key bubble (left)
	local key = UIKit.circleButton({
		Name = "Key",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Text = keyText(prompt, inputType),
		TextSize = 30,
		ZIndex = 2,
		Parent = root,
	}, 62, Theme.Colors.Blue, Theme.Colors.BlueDark)

	-- Action / object pill (right), tucked behind the bubble like the reference
	local pill = UIKit.new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.new(1, -44, 0, 52),
		BackgroundColor3 = Theme.Colors.Blue,
		Parent = root,
	}, {
		UIKit.corner(Theme.Corner.Pill),
		UIKit.stroke(Theme.Colors.BlueLight, 3),
		UIKit.gloss(),
	})
	local objectLabel = UIKit.label({
		Name = "Object",
		Position = UDim2.fromOffset(32, 4),
		Size = UDim2.new(1, -44, 0, 16),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pill,
	})
	local actionLabel = UIKit.label({
		Name = "Action",
		Position = UDim2.fromOffset(32, 18),
		Size = UDim2.new(1, -44, 0, 30),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pill,
	})

	-- Hold progress bar along the bottom of the pill
	local bar = UIKit.new("Frame", {
		Name = "HoldBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 30, 1, -3),
		Size = UDim2.new(1, -46, 0, 6),
		BackgroundColor3 = Theme.Colors.BlueDark,
		Visible = prompt.HoldDuration > 0,
		Parent = pill,
	}, { UIKit.corner(Theme.Corner.Pill) })
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.Gold,
		Parent = bar,
	}, { UIKit.corner(Theme.Corner.Pill) })

	local function refreshText()
		actionLabel.Text = prompt.ActionText
		objectLabel.Text = prompt.ObjectText
		objectLabel.Visible = prompt.ObjectText ~= ""
		actionLabel.Position = if prompt.ObjectText ~= "" then UDim2.fromOffset(32, 18) else UDim2.fromOffset(32, 11)
		bar.Visible = prompt.HoldDuration > 0
	end
	refreshText()

	local connections: { RBXScriptConnection } = {}
	local function add(c: RBXScriptConnection)
		table.insert(connections, c)
	end
	add(prompt:GetPropertyChangedSignal("ActionText"):Connect(refreshText))
	add(prompt:GetPropertyChangedSignal("ObjectText"):Connect(refreshText))
	add(prompt:GetPropertyChangedSignal("HoldDuration"):Connect(refreshText))

	local fillTween: Tween? = nil
	add(prompt.PromptButtonHoldBegan:Connect(function()
		fill.Size = UDim2.fromScale(0, 1)
		fillTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		;(fillTween :: Tween):Play()
	end))
	add(prompt.PromptButtonHoldEnded:Connect(function()
		if fillTween then
			fillTween:Cancel()
		end
		fill.Size = UDim2.fromScale(0, 1)
	end))
	add(prompt.Triggered:Connect(function()
		scale.Scale = 1.12
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end))

	-- Clicking / tapping the key bubble holds the prompt like the real key
	add(key.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			prompt:InputHoldBegin()
		end
	end))
	add(key.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			prompt:InputHoldEnd()
		end
	end))

	gui.Parent = folder
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	prompt.PromptHidden:Once(function()
		for _, c in connections do
			c:Disconnect()
		end
		gui:Destroy()
	end)
end

function PromptController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- BillboardGuis kept in PlayerGui stay clickable (Adornee places them in the world).
	-- A Folder, not a ScreenGui: layer collectors don't render nested inside each other.
	folder = UIKit.new("Folder", { Name = "Prompts", Parent = playerGui })
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt, inputType)
		end
	end)
end

return PromptController
