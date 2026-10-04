--!strict
-- Economy tuning values. Every number here is a placeholder: economy values are a human decision,
-- tuned with tests/EconomySim.luau (M4-07).
-- Formula: baseYield × stage multiplier × combined boosts (additive, capped) × trait multiplier.
local EconomyConfig = {
	STARTING_SHELLS = 0,
	-- Only claimable stages pay
	STAGE_MULTIPLIER = table.freeze({ Mature = 1, Flourishing = 1.25 }),
	-- Added on top of 1. Mismatches add 0: poor conditions only miss a bonus, never penalise.
	CONDITION_BONUS = table.freeze({ lightMatch = 0.15, flowMatch = 0.10 }),
	-- Cap for all additive boosts combined
	MAX_TOTAL_MULTIPLIER = 2.0,
	MAX_GRANT_PER_CALL = 10000,
	HARVEST_FRAGMENT_RETURN = 1,
	MAX_BUY_QTY = 10,
	-- Fragments can only be bought this close (studs) to the hub shop stall's counter
	SHOP_RANGE = 25,
}

return table.freeze(EconomyConfig)
