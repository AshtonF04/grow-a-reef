local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
type CoralDefinition = CoralDefinitions.CoralDefinition

local PlayerService = {}

export type PlayerState = {
    playerID: string,
    shells: number,
    pearls: number,
    socketUnlocks: { [string]: boolean },
    placements: { [string]: CoralDefinition? },
    fragments: { [string]: number }
}

print("Player Service Started...")

return PlayerService