--!strict

local CoralDefinitions = require(script.Parent.Config.CoralDefinitions)
local GameConfig = require(script.Parent.Config.GameConfig)
local SocketDefinitions = require(script.Parent.Config.SocketDefinitions)
local Types = require(script.Parent.Types)

type SocketDefinition = SocketDefinitions.SocketDefinition
type PlayerState = Types.PlayerState

export type ActionBlock = {
	code: string,
	message: string,
}

local ReefRules = {}

local ordered: { SocketDefinition } = {}
for _, socket in SocketDefinitions do
	table.insert(ordered, socket)
end
table.sort(ordered, function(a, b)
	return a.unlockOrder < b.unlockOrder
end)
table.freeze(ordered)

function ReefRules.OrderedSockets(): { SocketDefinition }
	return ordered
end

function ReefRules.GrowDuration(coralId: string): number
	local override = GameConfig.DevGrowSeconds
	if override ~= nil then
		return override
	end
	local coral = CoralDefinitions[coralId]
	if not coral then
		return 0
	end
	return coral.growSeconds
end

function ReefRules.RemainingSeconds(plantedAt: number, coralId: string, now: number): number
	return math.max(0, ReefRules.GrowDuration(coralId) - (now - plantedAt))
end

function ReefRules.IsMature(plantedAt: number, coralId: string, now: number): boolean
	local duration = ReefRules.GrowDuration(coralId)
	return (now - plantedAt) >= duration - 0.05
end

function ReefRules.Progress(plantedAt: number, coralId: string, now: number): number
	local duration = ReefRules.GrowDuration(coralId)
	if duration <= 0 then
		return 1
	end
	return math.clamp((now - plantedAt) / duration, 0, 1)
end

function ReefRules.FormatTime(seconds: number): string
	local remaining = math.max(0, math.ceil(seconds - 1e-3))
	local minutes = math.floor(remaining / 60)
	local secs = remaining % 60
	return string.format("%d:%02d", minutes, secs)
end

function ReefRules.FirstFragment(state: PlayerState): string?
	local starter = state.fragments.sun_coral
	if starter ~= nil and starter > 0 then
		return "sun_coral"
	end
	for id, count in state.fragments do
		if count > 0 and CoralDefinitions[id] ~= nil then
			return id
		end
	end
	return nil
end

function ReefRules.ConditionText(socketId: string): string
	local socket = SocketDefinitions[socketId]
	if not socket then
		return ""
	end
	return string.format("%s light   ·   %s flow", socket.light, socket.flow)
end

function ReefRules.MatchText(coralId: string, socketId: string): string
	local coral = CoralDefinitions[coralId]
	local socket = SocketDefinitions[socketId]
	if not coral or not socket then
		return ""
	end
	local wants = {}
	if coral.light ~= socket.light then
		table.insert(wants, string.format("%s light", string.lower(coral.light)))
	end
	if coral.flow ~= socket.flow then
		table.insert(wants, string.format("%s flow", string.lower(coral.flow)))
	end
	if #wants == 0 then
		return coral.displayName .. " thrives here"
	end
	return coral.displayName .. " wants " .. table.concat(wants, " and ")
end

function ReefRules.UnlockBlock(state: PlayerState, socketId: string): ActionBlock?
	local socket = SocketDefinitions[socketId]
	if not socket then
		return { code = "unknown", message = "That spot doesn't exist." }
	end
	if state.socketUnlocks[socketId] then
		return { code = "already_open", message = socket.displayName .. " is already open." }
	end

	local blocking: SocketDefinition? = nil
	for _, other in SocketDefinitions do
		if other.unlockOrder < socket.unlockOrder and not state.socketUnlocks[other.id] then
			if not blocking or other.unlockOrder < blocking.unlockOrder then
				blocking = other
			end
		end
	end
	if blocking then
		return {
			code = "order",
			message = string.format("Open %s first.", blocking.displayName),
		}
	end

	if state.shells < socket.unlockCostShells then
		local short = socket.unlockCostShells - state.shells
		return {
			code = "shells",
			message = string.format("You need %d more shells to open %s.", short, socket.displayName),
		}
	end

	return nil
end

function ReefRules.PlantBlock(state: PlayerState, socketId: string, coralId: string): ActionBlock?
	local socket = SocketDefinitions[socketId]
	local coral = CoralDefinitions[coralId]
	if not socket or not coral then
		return { code = "unknown", message = "That plant or spot doesn't exist." }
	end
	if not state.socketUnlocks[socketId] then
		return { code = "locked", message = "Open " .. socket.displayName .. " before planting." }
	end
	if state.placements[socketId] ~= nil then
		return { code = "occupied", message = "Something is already growing on " .. socket.displayName .. "." }
	end
	if (state.fragments[coralId] or 0) < 1 then
		return {
			code = "fragments",
			message = "You don't have a " .. coral.displayName .. " fragment.",
		}
	end
	return nil
end

function ReefRules.HarvestBlock(state: PlayerState, socketId: string, now: number): ActionBlock?
	local socket = SocketDefinitions[socketId]
	local placement = state.placements[socketId]
	if not socket or not placement then
		return { code = "empty", message = "Nothing is growing there." }
	end
	local coral = CoralDefinitions[placement.coralId]
	local coralName = if coral then coral.displayName else "Coral"
	if not ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
		local remain = ReefRules.RemainingSeconds(placement.plantedAt, placement.coralId, now)
		return {
			code = "growing",
			message = string.format("%s still needs %s.", coralName, ReefRules.FormatTime(remain)),
		}
	end
	return nil
end

function ReefRules.StatusLine(state: PlayerState, socketId: string, now: number): string
	local socket = SocketDefinitions[socketId]
	if not socket then
		return ""
	end
	if not state.socketUnlocks[socketId] then
		local block = ReefRules.UnlockBlock(state, socketId)
		if block and block.code == "order" then
			return block.message
		end
		return string.format("%d shells to open", socket.unlockCostShells)
	end

	local placement = state.placements[socketId]
	if placement then
		local coral = CoralDefinitions[placement.coralId]
		local coralName = if coral then coral.displayName else "Coral"
		if ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
			return coralName .. " is ready"
		end
		local remain = ReefRules.RemainingSeconds(placement.plantedAt, placement.coralId, now)
		return "Growing  ·  " .. ReefRules.FormatTime(remain)
	end

	local coralId = ReefRules.FirstFragment(state)
	if not coralId then
		return "No fragments to plant"
	end
	local coral = CoralDefinitions[coralId]
	return "Plant " .. (if coral then coral.displayName else "coral")
end

function ReefRules.NextStep(state: PlayerState, now: number): string
	for _, socket in ordered do
		local placement = state.placements[socket.id]
		if placement and ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
			return socket.displayName .. " is ready to harvest."
		end
	end

	local nextLocked: SocketDefinition? = nil
	for _, socket in ordered do
		if not state.socketUnlocks[socket.id] then
			nextLocked = socket
			break
		end
	end
	if nextLocked and ReefRules.UnlockBlock(state, nextLocked.id) == nil then
		return string.format("Open %s for %d shells.", nextLocked.displayName, nextLocked.unlockCostShells)
	end

	local coralId = ReefRules.FirstFragment(state)
	if coralId then
		for _, socket in ordered do
			if state.socketUnlocks[socket.id] and state.placements[socket.id] == nil then
				local coral = CoralDefinitions[coralId]
				local name = if coral then coral.displayName else "coral"
				return string.format("Plant %s on %s.", name, socket.displayName)
			end
		end
	end

	for _, socket in ordered do
		local placement = state.placements[socket.id]
		if placement and not ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
			local remain = ReefRules.RemainingSeconds(placement.plantedAt, placement.coralId, now)
			return string.format("%s is growing  ·  %s", socket.displayName, ReefRules.FormatTime(remain))
		end
	end

	if nextLocked then
		local block = ReefRules.UnlockBlock(state, nextLocked.id)
		if block then
			return block.message
		end
	end

	return "Every spot on this reef is open."
end

do
	local sun = CoralDefinitions.sun_coral
	local sandy = SocketDefinitions.sandy_patch
	assert(sun ~= nil, "sun_coral definition missing")
	assert(sandy ~= nil, "sandy_patch definition missing")
	assert(sun.light == sandy.light and sun.flow == sandy.flow, "Sandy Patch should match Sun Coral")
	assert(sandy.unlockCostShells == 0, "Sandy Patch should start free")
end

return ReefRules
