--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerState = Types.PlayerState
type Placement = Types.Placement

local PlayerStateService = {}

PlayerStateService.Players = {} :: { [string]: PlayerState }

local function userIdOf(player: Player | string): string
	if typeof(player) == "Instance" then
		return tostring(player.UserId)
	end
	return player
end

local function count(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.max(0, math.floor(value))
end

local function freshState(userId: string): PlayerState
	local unlocks: { [string]: boolean } = {}
	for id, socket in SocketDefinitions do
		unlocks[id] = socket.unlockCostShells <= 0
	end

	local fragments: { [string]: number } = {}
	for id, amount in GameConfig.StartingFragments do
		fragments[id] = amount
	end

	return {
		playerID = userId,
		shells = GameConfig.StartingShells,
		pearls = GameConfig.StartingPearls,
		socketUnlocks = unlocks,
		placements = {},
		fragments = fragments,
	}
end

-- Copies only known ids and sane numbers from a saved record into a fresh state.
local function applyRecord(state: PlayerState, record: { [string]: any }, now: number)
	state.shells = count(record.shells) or state.shells
	state.pearls = count(record.pearls) or state.pearls

	if typeof(record.socketUnlocks) == "table" then
		for id, open in record.socketUnlocks do
			if typeof(id) == "string" and SocketDefinitions[id] and open == true then
				state.socketUnlocks[id] = true
			end
		end
	end

	if typeof(record.fragments) == "table" then
		for id, amount in record.fragments do
			local n = count(amount)
			if typeof(id) == "string" and CoralDefinitions[id] and n then
				state.fragments[id] = math.min(n, GameConfig.MaxFragmentsPerCoral)
			end
		end
	end

	if typeof(record.placements) == "table" then
		for socketId, placement in record.placements do
			if
				typeof(socketId) == "string"
				and SocketDefinitions[socketId]
				and state.socketUnlocks[socketId]
				and typeof(placement) == "table"
				and typeof(placement.coralId) == "string"
				and CoralDefinitions[placement.coralId]
				and typeof(placement.plantedAt) == "number"
				and placement.plantedAt == placement.plantedAt
			then
				-- A clock that ran ahead of us never makes coral younger than "just planted".
				state.placements[socketId] = {
					coralId = placement.coralId,
					plantedAt = math.min(placement.plantedAt, now),
				}
			end
		end
	end
end

function PlayerStateService.GetState(player: Player | string): PlayerState?
	return PlayerStateService.Players[userIdOf(player)]
end

-- record is the saved table from SaveService, or nil for a new reef.
function PlayerStateService.InitPlayerState(player: Player, record: { [string]: any }?): PlayerState
	local userId = tostring(player.UserId)
	local existing = PlayerStateService.Players[userId]
	if existing then
		return existing
	end

	local state = freshState(userId)
	if record then
		applyRecord(state, record, workspace:GetServerTimeNow())
	end

	PlayerStateService.Players[userId] = state
	return state
end

function PlayerStateService.ToRecord(state: PlayerState): { [string]: any }
	local placements: { [string]: Placement } = {}
	for socketId, placement in state.placements do
		if placement then
			placements[socketId] = { coralId = placement.coralId, plantedAt = placement.plantedAt }
		end
	end
	return {
		shells = state.shells,
		pearls = state.pearls,
		socketUnlocks = table.clone(state.socketUnlocks),
		fragments = table.clone(state.fragments),
		placements = placements,
		lastSeen = os.time(),
	}
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

function PlayerStateService.BuyFragment(player: Player, coralId: string): (boolean, string)
	local state = PlayerStateService.GetState(player)
	if not state then
		return false, "Your reef isn't ready yet."
	end
	local block = ReefRules.BuyBlock(state, coralId)
	if block then
		return false, block.message
	end
	local coral = CoralDefinitions[coralId]
	if not coral then
		return false, "That coral isn't in the Nursery."
	end

	state.shells -= coral.nurseryCost
	state.fragments[coralId] = (state.fragments[coralId] or 0) + 1

	local home = ReefRules.HomeSocket(coralId)
	local hint = if home then string.format(" It flourishes on %s.", home.displayName) else ""
	return true, string.format("Bought a %s fragment for %d shells.%s", coral.displayName, coral.nurseryCost, hint)
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

	local payout = ReefRules.HarvestYield(placement.coralId, socketId)
	local flourishing = ReefRules.Fit(placement.coralId, socketId) == "flourishing"

	state.placements[socketId] = nil
	state.shells += payout
	state.fragments[placement.coralId] =
		math.min((state.fragments[placement.coralId] or 0) + 1, GameConfig.MaxFragmentsPerCoral)

	return true,
		string.format(
			"Harvested %s for %d shells%s. You now have %d.",
			coral.displayName,
			payout,
			if flourishing then " (flourishing)" else "",
			state.shells
		)
end

return PlayerStateService
