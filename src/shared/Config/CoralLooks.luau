--!strict

-- Coral palettes. ReefVisuals uses them for the 3D coral, HUDService for Nursery swatches.

export type CoralLook = {
	body: Color3,
	tip: Color3,
	deep: Color3,
}

local looks: { [string]: CoralLook } = {
	sun_coral = {
		body = Color3.fromRGB(255, 122, 66),
		tip = Color3.fromRGB(255, 196, 112),
		deep = Color3.fromRGB(196, 78, 46),
	},
	branch_coral = {
		body = Color3.fromRGB(206, 112, 196),
		tip = Color3.fromRGB(255, 200, 238),
		deep = Color3.fromRGB(140, 70, 146),
	},
	brain_coral = {
		body = Color3.fromRGB(150, 188, 96),
		tip = Color3.fromRGB(214, 232, 150),
		deep = Color3.fromRGB(92, 128, 62),
	},
	plate_coral = {
		body = Color3.fromRGB(84, 176, 170),
		tip = Color3.fromRGB(176, 236, 220),
		deep = Color3.fromRGB(46, 112, 116),
	},
	star_coral = {
		body = Color3.fromRGB(206, 160, 70),
		tip = Color3.fromRGB(255, 240, 130),
		deep = Color3.fromRGB(138, 102, 48),
	},
	bubble_coral = {
		body = Color3.fromRGB(214, 234, 214),
		tip = Color3.fromRGB(236, 250, 244),
		deep = Color3.fromRGB(150, 184, 170),
	},
}

local fallback: CoralLook = looks.sun_coral

for _, look in looks do
	table.freeze(look)
end
table.freeze(looks)

local CoralLooks = {}

function CoralLooks.Get(coralId: string): CoralLook
	return looks[coralId] or fallback
end

return table.freeze(CoralLooks)
