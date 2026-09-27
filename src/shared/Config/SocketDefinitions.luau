--!strict

export type LightLevel = "Bright" | "Dim"
export type FlowLevel = "Low" | "Medium" | "High"


export type SocketDefinition = {
	id: string,
	displayName: string,
	light: LightLevel,
	flow: FlowLevel,
	unlockOrder: number,
	unlockCostShells: number, -- 0 = unlocked from the start
}

local SocketDefinitions: { [string]: SocketDefinition } = {
	sandy_patch = {
		id = "sandy_patch",
		displayName = "Sandy Patch",
		light = "Bright",
		flow = "Medium",
		unlockOrder = 1,
		unlockCostShells = 0, -- tutorial socket: highlighted for the free Sun Coral
	},
	sun_ledge = {
		id = "sun_ledge",
		displayName = "Sun Ledge",
		light = "Bright",
		flow = "Low",
		unlockOrder = 2,
		unlockCostShells = 10,
	},
	surge_channel = {
		id = "surge_channel",
		displayName = "Surge Channel",
		light = "Bright",
		flow = "High",
		unlockOrder = 3,
		unlockCostShells = 50, -- placeholder: tune against the 15-25 min target
	},
	kelp_shade = {
		id = "kelp_shade",
		displayName = "Kelp Shade",
		light = "Dim",
		flow = "Medium",
		unlockOrder = 4,
		unlockCostShells = 50, -- placeholder
	},
	rock_crevice = {
		id = "rock_crevice",
		displayName = "Rock Crevice",
		light = "Dim",
		flow = "High",
		unlockOrder = 5,
		unlockCostShells = 120, -- placeholder
	},
	deep_nook = {
		id = "deep_nook",
		displayName = "Deep Nook",
		light = "Dim",
		flow = "Low",
		unlockOrder = 6,
		unlockCostShells = 120, -- placeholder
	},
}

for _, socket in SocketDefinitions do
	table.freeze(socket)
end
table.freeze(SocketDefinitions)

return SocketDefinitions