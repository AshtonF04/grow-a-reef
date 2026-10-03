--!strict
-- Shared UI tokens from the design doc so every screen matches.
-- Deep Teal = HUD foundations (white text), Coral Orange = the one primary action per screen,
-- Seafoam = success / good habitat fit (always paired with text), Sand = cards.

local Theme = {}

Theme.Colors = table.freeze({
	DeepTeal = Color3.fromRGB(14, 74, 92),
	DeepTealDark = Color3.fromRGB(8, 46, 60),
	CoralOrange = Color3.fromRGB(255, 122, 69),
	CoralOrangeDark = Color3.fromRGB(196, 78, 34),
	Seafoam = Color3.fromRGB(88, 214, 165),
	SeafoamDark = Color3.fromRGB(38, 140, 104),
	Amber = Color3.fromRGB(255, 196, 64),
	Sand = Color3.fromRGB(253, 240, 210),
	SandDark = Color3.fromRGB(214, 184, 128),
	Muted = Color3.fromRGB(150, 150, 150),
	White = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(40, 44, 52),
	Outline = Color3.fromRGB(10, 30, 40),
})

Theme.Fonts = table.freeze({
	Display = Font.fromEnum(Enum.Font.FredokaOne),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
})

Theme.TextSize = table.freeze({
	Small = 14,
	Body = 18,
	Title = 24,
	Big = 30,
})

Theme.Spacing = table.freeze({
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
})

Theme.Corner = table.freeze({
	S = UDim.new(0, 8),
	M = UDim.new(0, 12),
	L = UDim.new(0, 18),
	Pill = UDim.new(1, 0),
})

Theme.StrokeThickness = 3

return table.freeze(Theme)
