--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require custom configs and modules
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local Types = require(ReplicatedStorage.Shared.Types)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

-- Define session type to store a users current session
type Session = { data: Types.PlayerData, plotId: string?, loaded: boolean }

-- List of valid slices used by client to access player data, a list of all data attributes the client can access
local VALID_SLICES = { currencies = true, unlocks = true, inventory = true,
                       placements = true, discoveries = true, tutorial = true 
}

-- Stores users and their pending slices that are marked dirty and need to be sent to client to update
local pending: { [string]: { [string]: true } } = {}   -- userId -> set of slice keys

local PlayerStateService = {}

-- Define custom signals for this service
PlayerStateService.StateChanged = Signal.new()

-- Create list of sessions to store all user sessions
PlayerStateService.Sessions = {} :: { [string]: Session? }

-- utility: Gets a players user id regardless of if a player instance or a userid was passed
local function getUserId(player : Player | string) : string
    local userId: string

    if typeof(player) == "Instance" then
        userId = tostring(player.UserId)
    else
        userId = player
    end

    return userId
end

-- Builds default data for new players
function PlayerStateService.buildDefaultData() : Types.PlayerData
    -- Iterate over all sockets to build a table setting that socket to true (unlocked) if unlock cost is 0, and false otherwise
    local sockets: { [string]: boolean } = {}
    for socketId, socket in SocketDefinitions do
        sockets[socketId] = socket.unlockCostShells == 0
    end

    -- Define all default player data
    local data: Types.PlayerData = {
        version = 1,
        currencies = { 
            shells = 0, 
            pearls = 0 
        },
        unlocks = {
            zone = 1,
            sockets = sockets,
        },
        inventory = { 
            fragments = { 
                sun_coral = 1 
            } 
        },
        placements = {},
        discoveries = { corals = {}, fish = {}, traits = {} },
        tutorial = { version = 1, step = "start", done = false },
        meta = { firstJoin = os.time(), lastSeen = os.time() },
    }
    return data
end

-- Creates new instance of player data using buildDefaultData and creates a new session for the player
function PlayerStateService.InitPlayerState(player: Player) : Types.PlayerData
    local userId : string = tostring(player.UserId)
    local defaultData: Types.PlayerData = PlayerStateService.buildDefaultData()

    local newSession: Session = { data = defaultData, plotId = nil, loaded = true }
    PlayerStateService.Sessions[userId] = newSession

    return newSession.data
end

-- Handles removing player session and clearing pending upon leaving the game
function PlayerStateService.RemovePlayer(player: Player)
    local userId = tostring(player.UserId)
    PlayerStateService.Sessions[userId] = nil
    pending[userId] = nil
end

-- Gets a players full state for the server and returns it
function PlayerStateService.GetState(player: Player | string): Types.PlayerData?
    local userId = getUserId(player)

    local session = PlayerStateService.Sessions[userId]
    if session == nil then
        return nil
    end

    return session.data
end

-- Checks if a specific player has a loaded session
function PlayerStateService.IsLoaded(player: Player | string) : boolean
    local userId : string = getUserId(player)
    local session : Session? = PlayerStateService.Sessions[userId]
    if session and session.loaded then
        return true
    else
        return false
    end
end

-- Gets all client visible slices of a players data and returns it
function PlayerStateService.GetClientView(player : Player | string) : Types.ClientState?
    local playerData : Types.PlayerData? = PlayerStateService.GetState(player)

    if playerData == nil then
        return nil
    end

    local clientState : Types.ClientState = {
        currencies = table.clone(playerData.currencies),
        unlocks = table.clone(playerData.unlocks),
        inventory = table.clone(playerData.inventory),
        placements = table.clone(playerData.placements),
        discoveries = table.clone(playerData.discoveries),
        tutorial = table.clone(playerData.tutorial)
    }

    return clientState
end

-- Sends a snapshot of the clientview of player data over a remote event
function PlayerStateService.ReplicateSnapshot(player : Player)
    local state_changed = Remotes.GetEvent("state_changed")
    state_changed:FireClient(player, "snapshot", PlayerStateService.GetClientView(player))
end

-- Sends a specific slice of player data in client view over a remote event
function PlayerStateService.ReplicateSlice(player: Player, sliceKey: string)
    local clientView = PlayerStateService.GetClientView(player)
    if clientView == nil then return end

    if VALID_SLICES[sliceKey] then
        local state_changed = Remotes.GetEvent("state_changed")
        state_changed:FireClient(player, sliceKey, clientView[sliceKey])
    else
        warn("PlayerStateService: Invalid slice key for ReplicateSlice")
        return
    end
end

-- Marks specific slices of player data as "dirty" and defers firing the remote to sync with client data
-- Avoid firing remote event many times and clogging network with traffic when many player data values change at once
-- task.defer waits until the end of the frame before running so even if 5 modules modify 5 different slices of data in one frame, the remote and ui only update once with all the 
function PlayerStateService.MarkDirty(player: Player, sliceKey: string)
    local userId = getUserId(player)
    if PlayerStateService.Sessions[userId] == nil then return end  -- player already left: do nothing

    local set = pending[userId]
    if set then
        set[sliceKey] = true            -- flush already scheduled, just add to it
        return
    end

    pending[userId] = { [sliceKey] = true }
    task.defer(function()
        local toSend = pending[userId]
        pending[userId] = nil           -- swap the set out BEFORE sending
        if not toSend or PlayerStateService.Sessions[userId] == nil then return end
        for key in toSend do
            PlayerStateService.ReplicateSlice(player, key)
            PlayerStateService.StateChanged:Fire(player, key)
        end
    end)
end

function PlayerStateService.Init()

end

return PlayerStateService