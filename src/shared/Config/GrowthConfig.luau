--!strict
-- Growth timing rules shared by server (claims), client (models, countdowns) and tests.
-- Placeholder values, to tune in M5.
local Types = require(script.Parent.Parent.Types)

export type VisualStage = "Bud" | "Young" | "Mature"

local GrowthConfig = {
	-- The short "just placed" phase, in seconds
	FRAGMENT_SECONDS = 3,
	-- Fraction of total grow time at which Sprouting becomes Growing (Mature starts at progress 1)
	STAGE_THRESHOLDS = table.freeze({ Growing = 0.34 }),
	VISUAL_STAGE = table.freeze({
		Fragment = "Bud",
		Sprouting = "Bud",
		Growing = "Young",
		Mature = "Mature",
		Flourishing = "Mature",
	} :: { [Types.GrowthStage]: VisualStage }),
}

return table.freeze(GrowthConfig)
