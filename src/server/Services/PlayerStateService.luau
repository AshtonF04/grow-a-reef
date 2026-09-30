--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local Types = require(ReplicatedStorage.Shared.Types)

local PlayerStateService = {}

type Session = { data: Types.PlayerData, plotId: string?, loaded: boolean }
type Sessions = { [string]: Session? }
PlayerStateService.Sessions = {} :: Sessions

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

function PlayerStateService.InitPlayerState(player: Player) : Types.PlayerData
    local userId : string = tostring(player.UserId)
    local defaultData: Types.PlayerData = PlayerStateService.buildDefaultData()

    local newSession: Session = { data = defaultData, plotId = nil, loaded = true }
    PlayerStateService.Sessions[userId] = newSession

    return newSession.data
end

function PlayerStateService.RemovePlayer(player: Player)
    local userId = tostring(player.UserId)
    PlayerStateService.Sessions[userId] = nil
end

function PlayerStateService.GetState(player: Player | string): Types.PlayerData?
    local userId: string

    if typeof(player) == "Instance" then
        userId = tostring(player.UserId)
    else
        userId = player
    end

    local session = PlayerStateService.Sessions[userId]
    if session == nil then
        return nil
    end

    return session.data
end

function PlayerStateService.Init()

end

return PlayerStateService