--!strict

local CoralDefinitions = require(script.Parent.Config.CoralDefinitions)
local GameConfig = require(script.Parent.Config.GameConfig)
local SocketDefinitions = require(script.Parent.Config.SocketDefinitions)
local Types = require(script.Parent.Types)

type CoralDefinition = CoralDefinitions.CoralDefinition
type SocketDefinition = SocketDefinitions.SocketDefinition
type PlayerState = Types.PlayerState

export type ActionBlock = {
	code: string,
	message: string,
}

-- flourishing: light and flow both match. partial: one matches. poor: neither.
export type Fit = "flourishing" | "partial" | "poor"
export type Stage = "Fragment" | "Sprouting" | "Growing" | "Mature"
export type StepKind = "harvest" | "plant" | "unlock" | "buy" | "wait" | "save" | "done"

local FIT_RANK: { [Fit]: number } = {
	flourishing = 2,
	partial = 1,
	poor = 0,
}

local ReefRules = {}

local orderedSockets: { SocketDefinition } = {}
for _, socket in SocketDefinitions do
	table.insert(orderedSockets, socket)
end
table.sort(orderedSockets, function(a, b)
	return a.unlockOrder < b.unlockOrder
end)
table.freeze(orderedSockets)

local orderedCorals: { CoralDefinition } = {}
for _, coral in CoralDefinitions do
	table.insert(orderedCorals, coral)
end
table.sort(orderedCorals, function(a, b)
	if a.nurseryCost ~= b.nurseryCost then
		return a.nurseryCost < b.nurseryCost
	end
	return a.id < b.id
end)
table.freeze(orderedCorals)

function ReefRules.OrderedSockets(): { SocketDefinition }
	return orderedSockets
end

function ReefRules.OrderedCorals(): { CoralDefinition }
	return orderedCorals
end

function ReefRules.GrowDuration(coralId: string): number
	local coral = CoralDefinitions[coralId]
	if not coral then
		return 0
	end
	local scale = GameConfig.DevTimeScale
	if scale ~= nil then
		return coral.growSeconds * scale
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

function ReefRules.StageOf(plantedAt: number, coralId: string, now: number): Stage
	if ReefRules.IsMature(plantedAt, coralId, now) then
		return "Mature"
	end
	local progress = ReefRules.Progress(plantedAt, coralId, now)
	if progress >= 0.5 then
		return "Growing"
	elseif progress >= 0.15 then
		return "Sprouting"
	end
	return "Fragment"
end

function ReefRules.FormatTime(seconds: number): string
	local remaining = math.max(0, math.ceil(seconds - 1e-3))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local secs = remaining % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

function ReefRules.Fit(coralId: string, socketId: string): Fit
	local coral = CoralDefinitions[coralId]
	local socket = SocketDefinitions[socketId]
	if not coral or not socket then
		return "poor"
	end
	local matches = (if coral.light == socket.light then 1 else 0) + (if coral.flow == socket.flow then 1 else 0)
	if matches == 2 then
		return "flourishing"
	elseif matches == 1 then
		return "partial"
	end
	return "poor"
end

function ReefRules.HarvestYield(coralId: string, socketId: string): number
	local coral = CoralDefinitions[coralId]
	if not coral then
		return 0
	end
	if ReefRules.Fit(coralId, socketId) == "flourishing" then
		return math.floor(coral.baseYield * GameConfig.FlourishMultiplier + 0.5)
	end
	return coral.baseYield
end

-- The socket where this coral flourishes.
function ReefRules.HomeSocket(coralId: string): SocketDefinition?
	for _, socket in orderedSockets do
		if ReefRules.Fit(coralId, socket.id) == "flourishing" then
			return socket
		end
	end
	return nil
end

-- The coral that flourishes on this socket.
function ReefRules.HomeCoral(socketId: string): CoralDefinition?
	for _, coral in orderedCorals do
		if ReefRules.Fit(coral.id, socketId) == "flourishing" then
			return coral
		end
	end
	return nil
end

function ReefRules.OwnedCorals(state: PlayerState): { string }
	local owned = {}
	for _, coral in orderedCorals do
		if (state.fragments[coral.id] or 0) > 0 then
			table.insert(owned, coral.id)
		end
	end
	return owned
end

-- Which fragment to plant on a socket: the player's pick if they still own it, else the best fit.
function ReefRules.BestFragment(state: PlayerState, socketId: string, preferred: string?): string?
	if preferred and CoralDefinitions[preferred] and (state.fragments[preferred] or 0) > 0 then
		return preferred
	end
	local best: string? = nil
	local bestRank = -1
	for _, coral in orderedCorals do
		if (state.fragments[coral.id] or 0) > 0 then
			local rank = FIT_RANK[ReefRules.Fit(coral.id, socketId)]
			if rank > bestRank then
				best = coral.id
				bestRank = rank
			end
		end
	end
	return best
end

function ReefRules.ConditionText(socketId: string): string
	local socket = SocketDefinitions[socketId]
	if not socket then
		return ""
	end
	return string.format("%s light   ·   %s flow", socket.light, socket.flow)
end

function ReefRules.BonusText(): string
	return string.format("+%d%% shells", math.floor((GameConfig.FlourishMultiplier - 1) * 100 + 0.5))
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
		return string.format("%s flourishes here  ·  %s", coral.displayName, ReefRules.BonusText())
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

function ReefRules.BuyBlock(state: PlayerState, coralId: string): ActionBlock?
	local coral = CoralDefinitions[coralId]
	if not coral then
		return { code = "unknown", message = "That coral isn't in the Nursery." }
	end
	if (state.fragments[coralId] or 0) >= GameConfig.MaxFragmentsPerCoral then
		return {
			code = "full",
			message = string.format("You can't hold more %s fragments.", coral.displayName),
		}
	end
	if state.shells < coral.nurseryCost then
		return {
			code = "shells",
			message = string.format(
				"You need %d more shells for a %s fragment.",
				coral.nurseryCost - state.shells,
				coral.displayName
			),
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

function ReefRules.StatusLine(state: PlayerState, socketId: string, now: number, preferred: string?): string
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
			if ReefRules.Fit(placement.coralId, socketId) == "flourishing" then
				return coralName .. " is flourishing"
			end
			return coralName .. " is ready"
		end
		local remain = ReefRules.RemainingSeconds(placement.plantedAt, placement.coralId, now)
		local stage = ReefRules.StageOf(placement.plantedAt, placement.coralId, now)
		return stage .. "  ·  " .. ReefRules.FormatTime(remain)
	end

	local coralId = ReefRules.BestFragment(state, socketId, preferred)
	if not coralId then
		return "Empty  ·  buy a fragment"
	end
	local coral = CoralDefinitions[coralId]
	return "Plant " .. (if coral then coral.displayName else "coral")
end

function ReefRules.NextStep(state: PlayerState, now: number): (string, StepKind, string?)
	for _, socket in orderedSockets do
		local placement = state.placements[socket.id]
		if placement and ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
			return socket.displayName .. " is ready to harvest.", "harvest", socket.id
		end
	end

	local emptyOpen: { SocketDefinition } = {}
	for _, socket in orderedSockets do
		if state.socketUnlocks[socket.id] and state.placements[socket.id] == nil then
			table.insert(emptyOpen, socket)
		end
	end

	for _, socket in emptyOpen do
		local coralId = ReefRules.BestFragment(state, socket.id)
		local coral = if coralId then CoralDefinitions[coralId] else nil
		if coral then
			return string.format("Plant %s on %s.", coral.displayName, socket.displayName), "plant", socket.id
		end
	end

	local nextLocked: SocketDefinition? = nil
	for _, socket in orderedSockets do
		if not state.socketUnlocks[socket.id] then
			nextLocked = socket
			break
		end
	end
	if nextLocked and ReefRules.UnlockBlock(state, nextLocked.id) == nil then
		return string.format("Open %s for %d shells.", nextLocked.displayName, nextLocked.unlockCostShells), "unlock", nextLocked.id
	end

	local saveUp: string? = nil
	for _, socket in emptyOpen do
		local home = ReefRules.HomeCoral(socket.id)
		if home then
			if ReefRules.BuyBlock(state, home.id) == nil then
				return string.format(
					"Buy a %s fragment in the Nursery for %s.",
					home.displayName,
					socket.displayName
				),
					"buy",
					socket.id
			elseif not saveUp then
				saveUp = string.format(
					"Save %d shells for a %s fragment for %s.",
					home.nurseryCost,
					home.displayName,
					socket.displayName
				)
			end
		end
	end

	for _, socket in orderedSockets do
		local placement = state.placements[socket.id]
		if placement and not ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
			local remain = ReefRules.RemainingSeconds(placement.plantedAt, placement.coralId, now)
			return string.format("%s is growing  ·  %s", socket.displayName, ReefRules.FormatTime(remain)), "wait"
		end
	end

	if saveUp then
		return saveUp, "save"
	end

	if nextLocked then
		local block = ReefRules.UnlockBlock(state, nextLocked.id)
		if block then
			return block.message, "save"
		end
	end

	return "Every spot on this reef is open.", "done"
end

do
	local sun = CoralDefinitions.sun_coral
	local sandy = SocketDefinitions.sandy_patch
	assert(sun ~= nil, "sun_coral definition missing")
	assert(sandy ~= nil, "sandy_patch definition missing")
	assert(sun.light == sandy.light and sun.flow == sandy.flow, "Sandy Patch should match Sun Coral")
	assert(sandy.unlockCostShells == 0, "Sandy Patch should start free")
	for _, coral in orderedCorals do
		assert(ReefRules.HomeSocket(coral.id) ~= nil, coral.id .. " has no socket where it flourishes")
	end
end

return ReefRules
