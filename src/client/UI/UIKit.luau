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
		Color = color or Theme.Colors.Outline,
		Thickness = thickness or Theme.StrokeThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Text outline (applied to text glyphs instead of the frame border)
function UIKit.textStroke(color: Color3?, thickness: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or Theme.Colors.Outline,
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

-- Chunky cartoon text label with an outline
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
	if props.TextColor3 == nil or props.TextColor3 == Theme.Colors.White then
		UIKit.textStroke().Parent = label
	end
	return label
end

-- Chunky cartoon button: coloured body, darker bottom "lip", outline, squish on press
function UIKit.button(props: { [string]: any }, color: Color3?, darkColor: Color3?): TextButton
	local body = color or Theme.Colors.CoralOrange
	local defaults: { [string]: any } = {
		AutoButtonColor = false,
		BackgroundColor3 = body,
		FontFace = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.White,
		TextSize = Theme.TextSize.Body,
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = UIKit.new("TextButton", defaults, {
		UIKit.corner(Theme.Corner.M),
		UIKit.stroke(darkColor or Theme.Colors.CoralOrangeDark, Theme.StrokeThickness),
		UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
		UIKit.textStroke(darkColor or Theme.Colors.CoralOrangeDark, 2),
	})
	local scale = UIKit.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		scale.Scale = 0.94
	end)
	button.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	return button
end

return UIKit
