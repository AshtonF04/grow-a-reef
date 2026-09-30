--!strict

-- Positions are relative to the plot pivot.
-- X and Z are horizontal. Y is extra lift above the sand, not the final height.

export type SocketDress = {
	offset: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
}

local sockets: { [string]: SocketDress } = {
	sandy_patch = {
		offset = Vector3.new(0, 0, 10),
		size = Vector3.new(15, 0.9, 11),
		color = Color3.fromRGB(210, 188, 136),
		material = Enum.Material.Sand,
	},
	sun_ledge = {
		offset = Vector3.new(-18, 0, -1),
		size = Vector3.new(11, 2.4, 8),
		color = Color3.fromRGB(176, 138, 98),
		material = Enum.Material.Sandstone,
	},
	surge_channel = {
		offset = Vector3.new(18, 0, -4),
		size = Vector3.new(8, 1, 16),
		color = Color3.fromRGB(118, 132, 130),
		material = Enum.Material.Slate,
	},
	kelp_shade = {
		offset = Vector3.new(-26, 0, -16),
		size = Vector3.new(12, 0.9, 10),
		color = Color3.fromRGB(132, 146, 108),
		material = Enum.Material.Sand,
	},
	rock_crevice = {
		offset = Vector3.new(-2, 0, -18),
		size = Vector3.new(7, 2.2, 6),
		color = Color3.fromRGB(108, 104, 100),
		material = Enum.Material.Rock,
	},
	deep_nook = {
		offset = Vector3.new(20, 0, -22),
		size = Vector3.new(12, 0.8, 10),
		color = Color3.fromRGB(78, 96, 104),
		material = Enum.Material.Slate,
	},
}

for _, dress in sockets do
	table.freeze(dress)
end
table.freeze(sockets)

local SocketLayout = {
	plotPivot = CFrame.new(0, 0, -14),
	sockets = sockets,
}

table.freeze(SocketLayout)

return SocketLayout
