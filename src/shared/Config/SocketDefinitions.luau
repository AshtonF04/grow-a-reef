--!strict
local Types = require(script.Parent.Parent.Types)

type LightLevel = Types.LightLevel
type FlowLevel = Types.FlowLevel

export type SocketDefinition = {
	id: string,
	displayName: string,
	light: LightLevel,
	flow: FlowLevel,
	unlockOrder: number,
	unlockCostShells: number, -- 0 = unlocked from the start
	zone: number, -- The zone the socket is unlocked in
}

local SocketDefinitions: { [string]: SocketDefinition } = {
	sandy_patch = {
		id = "sandy_patch",
		displayName = "Sandy Patch",
		light = "Bright",
		flow = "Medium",
		unlockOrder = 1,
		unlockCostShells = 0, -- tutorial socket: highlighted for the free Sun Coral
		zone = 1,
	},
	sun_ledge = {
		id = "sun_ledge",
		displayName = "Sun Ledge",
		light = "Bright",
		flow = "Low",
		unlockOrder = 2,
		unlockCostShells = 10,
		zone = 1,
	},
	surge_channel = {
		id = "surge_channel",
		displayName = "Surge Channel",
		light = "Bright",
		flow = "High",
		unlockOrder = 3,
		unlockCostShells = 50, -- placeholder: tune against the 15-25 min target
		zone = 1,
	},
	kelp_shade = {
		id = "kelp_shade",
		displayName = "Kelp Shade",
		light = "Dim",
		flow = "Medium",
		unlockOrder = 4,
		unlockCostShells = 50, -- placeholder
		zone = 1,
	},
	rock_crevice = {
		id = "rock_crevice",
		displayName = "Rock Crevice",
		light = "Dim",
		flow = "High",
		unlockOrder = 5,
		unlockCostShells = 120, -- placeholder
		zone = 1,
	},
	deep_nook = {
		id = "deep_nook",
		displayName = "Deep Nook",
		light = "Dim",
		flow = "Low",
		unlockOrder = 6,
		unlockCostShells = 120, -- placeholder
		zone = 1,
	},
}

local seenUnlockOrders: { [number]: string } = {}

for socketId, socket in SocketDefinitions do
	-- Boot Validation
	-- Asserts socketId matches its key in table and no two sockets have the same unlockOrder
	assert(socket.id == socketId, "Socket ID mismatch: " .. socket.id .. " != " .. socketId)

	local previous = seenUnlockOrders[socket.unlockOrder]
	if previous ~= nil then
		error("Duplicate unlockOrder " .. socket.unlockOrder .. ": " .. previous .. " and " .. socketId)
	end
	seenUnlockOrders[socket.unlockOrder] = socketId

	table.freeze(socket)
end
table.freeze(SocketDefinitions)

return SocketDefinitions