local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
type CoralDefinition = CoralDefinitions.CoralDefinition

-- Player State Type
export type PlayerState = {
    playerID: string | nil,
    shells: number,
    pearls: number,
    socketUnlocks: { [string]: boolean },
    placements: { [string]: CoralDefinition? },
    fragments: { [string]: number }
}

local PlayerStateService = {}

PlayerStateService.Players = {} :: { [string]: PlayerState }

function PlayerStateService.InitPlayerState(player: Player): PlayerState
    local playerID = tostring(player.UserId)

    local newState: PlayerState = {
        playerID = playerID,
        shells = 0,
        pearls = 0,
        socketUnlocks = {
            sandy_patch = false
        },
        placements = {},
        fragments = {
            sun_coral = 1
        }
    }

    PlayerStateService.Players[playerID] = newState

    print(PlayerStateService.Players)
end

print("Player Service Started...")

return PlayerStateService