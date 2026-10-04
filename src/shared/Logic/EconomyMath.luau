--!strict
-- Pure economy formulas shared by the server (payouts, prices), the client ("you'll earn X") and tests.
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local CoralDefinitions = require(Shared.Config.CoralDefinitions)
local SocketDefinitions = require(Shared.Config.SocketDefinitions)

type CoralDefinition = CoralDefinitions.CoralDefinition
type SocketDefinition = SocketDefinitions.SocketDefinition

local EconomyMath = {}

-- Additive bonus from matching light and/or flow (0, 0.10, 0.15 or 0.25 with default config)
function EconomyMath.GetConditionBonus(coral: CoralDefinition, socket: SocketDefinition): number
	local bonus = 0
	if coral.light == socket.light then
		bonus += EconomyConfig.CONDITION_BONUS.lightMatch
	end
	if coral.flow == socket.flow then
		bonus += EconomyConfig.CONDITION_BONUS.flowMatch
	end
	return bonus
end

-- Full match on both light and flow unlocks Flourishing
function EconomyMath.IsConditionMatch(coral: CoralDefinition, socket: SocketDefinition): boolean
	return coral.light == socket.light and coral.flow == socket.flow
end

-- Returns 1 for now; M6-03 reads it from TraitDefinitions
function EconomyMath.GetTraitMultiplier(_traitId: string?): number
	return 1
end

-- 1 + sum of positive boosts, capped at MAX_TOTAL_MULTIPLIER
function EconomyMath.CombineBoosts(boosts: { number }): number
	local total = 1
	for _, b in boosts do
		if b > 0 then
			total += b
		end
	end
	return math.min(total, EconomyConfig.MAX_TOTAL_MULTIPLIER)
end

function EconomyMath.ComputeHarvestYield(
	coral: CoralDefinition,
	socket: SocketDefinition,
	stage: Types.GrowthStage,
	traitId: string?,
	extraBoosts: { number }?
): number
	local stageMultiplier = (EconomyConfig.STAGE_MULTIPLIER :: any)[stage]
	if stageMultiplier == nil then
		return 0
	end
	local boosts = { EconomyMath.GetConditionBonus(coral, socket) }
	if extraBoosts then
		for _, b in extraBoosts do
			table.insert(boosts, b)
		end
	end
	local raw = coral.baseYield * stageMultiplier * EconomyMath.CombineBoosts(boosts) * EconomyMath.GetTraitMultiplier(traitId)
	return math.max(1, math.floor(raw + 1e-9))
end

function EconomyMath.GetFragmentPrice(coralId: string, qty: number): number
	local coral = CoralDefinitions[coralId]
	assert(coral, "EconomyMath.GetFragmentPrice: unknown coral " .. tostring(coralId))
	assert(math.floor(qty) == qty and qty >= 1 and qty <= EconomyConfig.MAX_BUY_QTY, "EconomyMath.GetFragmentPrice: qty out of range")
	return coral.fragmentPriceShells * qty
end

function EconomyMath.GetSocketUnlockCost(socketId: string): number
	local socket = SocketDefinitions[socketId]
	assert(socket, "EconomyMath.GetSocketUnlockCost: unknown socket " .. tostring(socketId))
	return socket.unlockCostShells
end

return EconomyMath
