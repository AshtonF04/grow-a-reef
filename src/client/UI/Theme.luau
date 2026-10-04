--!strict
-- Shared UI tokens so every screen matches the cartoon-blue style (bright blue panels with a light-blue
-- rim, title tabs, round buttons, white chunky text with a navy outline).
-- Blue = panels and neutral buttons, Green = the confirm action, Red = cancel / exit,
-- Seafoam / Amber = habitat-fit chips (always paired with text), Gold = the shell coin.

local Theme = {}

Theme.Colors = table.freeze({
	Blue = Color3.fromRGB(51, 153, 255),
	BlueLight = Color3.fromRGB(120, 196, 255),
	BlueDark = Color3.fromRGB(22, 96, 196),
	BlueInset = Color3.fromRGB(32, 120, 230), -- cards / rows sunk into a panel
	Navy = Color3.fromRGB(10, 45, 120),
	Green = Color3.fromRGB(84, 214, 92),
	GreenDark = Color3.fromRGB(36, 146, 52),
	Red = Color3.fromRGB(240, 84, 84),
	RedDark = Color3.fromRGB(168, 38, 46),
	Gold = Color3.fromRGB(255, 206, 46),
	GoldDark = Color3.fromRGB(196, 136, 10),
	Disabled = Color3.fromRGB(150, 160, 175),
	DisabledDark = Color3.fromRGB(96, 104, 118),
	Seafoam = Color3.fromRGB(88, 214, 165),
	Amber = Color3.fromRGB(255, 196, 64),
	White = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(28, 40, 70),
})

-- Luckiest Guy is the chunky cartoon face of the reference; FredokaOne reads better at small sizes
Theme.Fonts = table.freeze({
	Display = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	Body = Font.fromEnum(Enum.Font.FredokaOne),
})

Theme.TextSize = table.freeze({
	Small = 14,
	Body = 18,
	Title = 26,
	Big = 32,
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
	M = UDim.new(0, 14),
	L = UDim.new(0, 22),
	Pill = UDim.new(1, 0),
})

Theme.StrokeThickness = 3
Theme.RimThickness = 5 -- light-blue rim around panels

return table.freeze(Theme)
