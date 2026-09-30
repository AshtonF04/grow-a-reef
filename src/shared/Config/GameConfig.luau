--!strict

local GameConfig = {
	StartingShells = 0,
	StartingPearls = 0,
	-- Sun Coral is authored at 300 seconds. This override is the timer you actually wait.
	-- Set it to nil when you want each coral's real growSeconds.
	DevGrowSeconds = 20 :: number?,
	StartingFragments = {
		sun_coral = 1,
	} :: { [string]: number },
}

table.freeze(GameConfig.StartingFragments)
table.freeze(GameConfig)

return GameConfig
