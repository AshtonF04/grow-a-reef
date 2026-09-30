--!strict

-- Which fragment the player picked for each empty spot.
-- With no pick, the spot uses the best-fitting fragment the player owns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerState = Types.PlayerState

local PlantChoice = {}

local picks: { [string]: string } = {}

function PlantChoice.For(state: PlayerState, socketId: string): string?
	return ReefRules.BestFragment(state, socketId, picks[socketId])
end

function PlantChoice.CanCycle(state: PlayerState): boolean
	return #ReefRules.OwnedCorals(state) > 1
end

function PlantChoice.Cycle(state: PlayerState, socketId: string): string?
	local owned = ReefRules.OwnedCorals(state)
	if #owned == 0 then
		return nil
	end
	local current = PlantChoice.For(state, socketId)
	local index = if current then table.find(owned, current) or 0 else 0
	local nextId = owned[index % #owned + 1]
	picks[socketId] = nextId
	return nextId
end

return PlantChoice
