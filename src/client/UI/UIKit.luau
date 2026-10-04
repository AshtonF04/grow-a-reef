--!strict
-- Small helpers for building UI from code so every screen lives in git and shares the Theme.
local Theme = require(script.Parent.Theme)

local UIKit = {}

-- Creates an instance, applies props (Parent last so it replicates once), and parents children
function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(radius: UDim?): UICorner
	return UIKit.new("UICorner", { CornerRadius = radius or Theme.Corner.M })
end

function UIKit.stroke(color: Color3?, thickness: number?): UIStroke
	return UIKit.new("UIStroke", {
		Name = "Rim",
		Color = color or Theme.Colors.BlueLight,
		Thickness = thickness or Theme.StrokeThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Text outline (applied to text glyphs instead of the frame border)
function UIKit.textStroke(color: Color3?, thickness: number?): UIStroke
	return UIKit.new("UIStroke", {
		Name = "TextStroke",
		Color = color or Theme.Colors.Navy,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UIKit.padding(all: number): UIPadding
	local d = UDim.new(0, all)
	return UIKit.new("UIPadding", { PaddingTop = d, PaddingBottom = d, PaddingLeft = d, PaddingRight = d })
end

function UIKit.gradient(top: Color3, bottom: Color3): UIGradient
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

-- Glossy top-light shading used on every blue surface
function UIKit.gloss(): UIGradient
	return UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 215, 230))
end

-- Chunky cartoon text label with a navy outline (dark text gets no outline)
function UIKit.label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.White,
		TextSize = Theme.TextSize.Body,
		TextScaled = false,
	}
	for k, v in props do
		defaults[k] = v
	end
	local label = UIKit.new("TextLabel", defaults)
	if defaults.TextColor3 ~= Theme.Colors.TextDark then
		UIKit.textStroke().Parent = label
	end
	return label
end

local function addPressScale(button: GuiButton)
	local scale = UIKit.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		scale.Scale = 0.92
	end)
	button.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
end

-- Recolours a button / pill made by UIKit (body, rim and text outline), e.g. to grey it out
function UIKit.setButtonColor(button: GuiObject, color: Color3, darkColor: Color3)
	button.BackgroundColor3 = color
	local rim = button:FindFirstChild("Rim")
	if rim and rim:IsA("UIStroke") then
		rim.Color = darkColor
	end
	local textStroke = button:FindFirstChild("TextStroke")
	if textStroke and textStroke:IsA("UIStroke") then
		textStroke.Color = darkColor
	end
end

-- Pill button: coloured body, darker rim, glossy shading, squish on press.
-- Defaults to blue; pass Theme.Colors.Green / Red (+ their Dark) for YES / NO style buttons.
function UIKit.button(props: { [string]: any }, color: Color3?, darkColor: Color3?): TextButton
	local dark = darkColor or Theme.Colors.BlueDark
	local defaults: { [string]: any } = {
		AutoButtonColor = false,
		BackgroundColor3 = color or Theme.Colors.Blue,
		FontFace = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.White,
		TextSize = Theme.TextSize.Body,
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = UIKit.new("TextButton", defaults, {
		UIKit.corner(Theme.Corner.Pill),
		UIKit.stroke(dark, Theme.StrokeThickness),
		UIKit.gloss(),
		UIKit.textStroke(dark, 2),
	})
	addPressScale(button)
	return button
end

-- Round icon button (HUD column, close X, the prompt key)
function UIKit.circleButton(props: { [string]: any }, size: number, color: Color3?, darkColor: Color3?): TextButton
	local p: { [string]: any } = { Size = UDim2.fromOffset(size, size), TextSize = math.floor(size * 0.5) }
	for k, v in props do
		p[k] = v
	end
	local button = UIKit.button(p, color, darkColor)
	local rim = button:FindFirstChild("Rim") :: UIStroke
	rim.Thickness = math.max(3, math.floor(size / 14))
	UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = button })
	return button
end

-- Rounded pill with an optional round icon bubble on the left (like the "$ 999,999" currency pill).
-- Returns the pill and its text label.
function UIKit.pill(props: { [string]: any }, text: string, icon: string?): (Frame, TextLabel)
	local defaults: { [string]: any } = {
		BackgroundColor3 = Theme.Colors.Blue,
		Size = UDim2.fromOffset(160, 40),
	}
	for k, v in props do
		defaults[k] = v
	end
	local pill = UIKit.new("Frame", defaults, {
		UIKit.corner(Theme.Corner.Pill),
		UIKit.stroke(Theme.Colors.BlueDark, Theme.StrokeThickness),
		UIKit.gloss(),
	})
	if icon then
		UIKit.new("Frame", {
			Name = "IconBubble",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.new(1, -8, 1, -8),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundColor3 = Theme.Colors.Gold,
			Parent = pill,
		}, {
			UIKit.corner(Theme.Corner.Pill),
			UIKit.stroke(Theme.Colors.GoldDark, 2),
			UIKit.new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = icon,
				TextScaled = true,
				FontFace = Theme.Fonts.Body,
			}, { UIKit.padding(4) }),
		})
	end
	local label = UIKit.label({
		Name = "Text",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = if icon then UDim2.new(0.72, -10, 1, -4) else UDim2.new(1, -20, 1, -4),
		Text = text,
		TextScaled = true,
		Parent = pill,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = Theme.TextSize.Title, Parent = label })
	return pill, label
end

-- One detail line inside a panel: "icon  Label ........ Value" on an inset bar
function UIKit.statRow(props: { [string]: any }, icon: string, labelText: string, value: string): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = Theme.Colors.BlueInset,
		Size = UDim2.new(1, 0, 0, 34),
	}
	for k, v in props do
		defaults[k] = v
	end
	local row = UIKit.new("Frame", defaults, {
		UIKit.corner(Theme.Corner.S),
		UIKit.stroke(Theme.Colors.BlueDark, 2),
	})
	UIKit.label({
		Name = "Label",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0.55, -10, 1, 0),
		Text = icon .. "  " .. labelText,
		FontFace = Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	UIKit.label({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.new(0.45, -10, 1, 0),
		Text = value,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	return row
end

export type Panel = { frame: Frame, content: Frame, title: TextLabel, close: TextButton? }

-- Reference-style window: blue body with a thick light-blue rim, a title tab overlapping the top-left
-- edge and a round X button overlapping the top-right corner. Put children in `content`.
function UIKit.panel(props: { [string]: any }, title: string, onClose: (() -> ())?): Panel
	local defaults: { [string]: any } = {
		BackgroundColor3 = Theme.Colors.Blue,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = UIKit.new("Frame", defaults, {
		UIKit.corner(Theme.Corner.L),
		UIKit.stroke(Theme.Colors.BlueLight, Theme.RimThickness),
		UIKit.gloss(),
	})

	local tab = UIKit.new("Frame", {
		Name = "TitleTab",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Blue,
		ZIndex = 2,
		Parent = frame,
	}, {
		UIKit.corner(Theme.Corner.Pill),
		UIKit.stroke(Theme.Colors.BlueLight, 4),
		UIKit.gloss(),
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
	})
	local titleLabel = UIKit.label({
		Name = "Title",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = title,
		TextSize = Theme.TextSize.Title,
		ZIndex = 2,
		Parent = tab,
	})

	local close: TextButton? = nil
	if onClose then
		local x = UIKit.circleButton({
			Name = "Close",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -8, 0, 8),
			Text = "X",
			ZIndex = 3,
			Parent = frame,
		}, 46, Theme.Colors.Blue, Theme.Colors.BlueLight)
		x.Activated:Connect(onClose)
		close = x
	end

	local content = UIKit.new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 1, -46),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	return { frame = frame, content = content, title = titleLabel, close = close }
end

return UIKit
