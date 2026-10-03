--!strict
-- The client's local mirror of the server's ClientState.
-- Every UI reads from here (never from a remote directly) and subscribes to Changed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local StateController = {}

-- Fires (sliceKey) whenever the mirror changes; sliceKey is "snapshot" for a full replace
StateController.Changed = Signal.new() :: Signal.Signal<string>

local state: Types.ClientState? = nil

-- Must run before client_ready is invoked, since the server sends the snapshot from inside that call
function StateController.Init()
	Remotes.GetEvent("state_changed").OnClientEvent:Connect(StateController.Apply)
end

-- Updates the mirror with a full snapshot or a single slice, then fires Changed
function StateController.Apply(sliceKey: string, value: any)
	if sliceKey == "snapshot" then
		state = value
	elseif state == nil then
		warn("StateController: received slice '" .. tostring(sliceKey) .. "' before any snapshot, ignoring")
		return
	else
		(state :: any)[sliceKey] = value
	end

	StateController.Changed:Fire(sliceKey)
end

-- Returns the current state, or nil before the first snapshot
function StateController.Get(): Types.ClientState?
	return state
end

function StateController.GetShells(): number
	return if state then state.currencies.shells else 0
end

return StateController
