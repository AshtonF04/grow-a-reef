--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerState = Types.PlayerState

local PlayerStateService = {}

PlayerStateService.Players = {} :: { [string]: PlayerState }

local function userIdOf(player: Player | string): string
	if typeof(player) == "Instance" then
		return tostring(player.UserId)
	end
	return player
end

function PlayerStateService.GetState(player: Player | string): PlayerState?
	return PlayerStateService.Players[userIdOf(player)]
end

function PlayerStateService.InitPlayerState(player: Player): PlayerState
	local userId = tostring(player.UserId)
	local existing = PlayerStateService.Players[userId]
	if existing then
		return existing
	end

	local unlocks: { [string]: boolean } = {}
	for id, socket in SocketDefinitions do
		unlocks[id] = socket.unlockCostShells <= 0
	end

	local fragments: { [string]: number } = {}
	for id, count in GameConfig.StartingFragments do
		fragments[id] = count
	end

	local state: PlayerState = {
		playerID = userId,
		shells = GameConfig.StartingShells,
		pearls = GameConfig.StartingPearls,
		socketUnlocks = unlocks,
		placements = {},
		fragments = fragments,
	}

	PlayerStateService.Players[userId] = state
	return state
end

function PlayerStateService.RemovePlayer(player: Player)
	PlayerStateService.Players[tostring(player.UserId)] = nil
end

function PlayerStateService.UnlockSocket(player: Player, socketId: string): (boolean, string)
	local state = PlayerStateService.GetState(player)
	if not state then
		return false, "Your reef isn't ready yet."
	end
	local block = ReefRules.UnlockBlock(state, socketId)
	if block then
		return false, block.message
	end

	local socket = SocketDefinitions[socketId]
	if not socket then
		return false, "That spot doesn't exist."
	end

	state.shells -= socket.unlockCostShells
	state.socketUnlocks[socketId] = true
	if socket.unlockCostShells <= 0 then
		return true, string.format("Opened %s.", socket.displayName)
	end
	return true, string.format("Opened %s for %d shells.", socket.displayName, socket.unlockCostShells)
end

function PlayerStateService.PlantCoral(player: Player, socketId: string, coralId: string): (boolean, string)
	local state = PlayerStateService.GetState(player)
	if not state then
		return false, "Your reef isn't ready yet."
	end
	local block = ReefRules.PlantBlock(state, socketId, coralId)
	if block then
		return false, block.message
	end

	local socket = SocketDefinitions[socketId]
	local coral = CoralDefinitions[coralId]
	if not socket or not coral then
		return false, "That plant or spot doesn't exist."
	end

	state.fragments[coralId] = (state.fragments[coralId] or 0) - 1
	state.placements[socketId] = {
		coralId = coralId,
		plantedAt = workspace:GetServerTimeNow(),
	}

	local readyIn = ReefRules.FormatTime(ReefRules.GrowDuration(coralId))
	return true, string.format("Planted %s on %s. Ready in %s.", coral.displayName, socket.displayName, readyIn)
end

function PlayerStateService.HarvestCoral(player: Player, socketId: string): (boolean, string)
	local state = PlayerStateService.GetState(player)
	if not state then
		return false, "Your reef isn't ready yet."
	end
	local now = workspace:GetServerTimeNow()
	local block = ReefRules.HarvestBlock(state, socketId, now)
	if block then
		return false, block.message
	end

	local placement = state.placements[socketId]
	local socket = SocketDefinitions[socketId]
	if not placement or not socket then
		return false, "Nothing is growing there."
	end
	local coral = CoralDefinitions[placement.coralId]
	if not coral then
		return false, "That coral no longer exists."
	end

	state.placements[socketId] = nil
	state.shells += coral.baseYield
	state.fragments[placement.coralId] = (state.fragments[placement.coralId] or 0) + 1

	return true,
		string.format(
			"Harvested %s for %d shells. You now have %d.",
			coral.displayName,
			coral.baseYield,
			state.shells
		)
end

return PlayerStateService
