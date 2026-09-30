--!strict

local GameConfig = {
	StartingShells = 0,
	StartingPearls = 0,
	-- Every coral's growSeconds is multiplied by this while testing.
	-- 1/15 turns Sun Coral's 5:00 into 0:20 and keeps the other corals in proportion.
	-- Set it to nil for real timers.
	DevTimeScale = (1 / 15) :: number?,
	-- Harvest multiplier when a coral's light and flow both match its socket.
	FlourishMultiplier = 1.5,
	MaxFragmentsPerCoral = 20,
	StartingFragments = {
		sun_coral = 1,
	} :: { [string]: number },
}

table.freeze(GameConfig.StartingFragments)
table.freeze(GameConfig)

return GameConfig
