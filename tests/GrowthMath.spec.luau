--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Expect = require(script.Parent.Expect)
local GrowthMath = require(ReplicatedStorage.Shared.Logic.GrowthMath)
local GrowthConfig = require(ReplicatedStorage.Shared.Config.GrowthConfig)

local function placement(plantedAt: number, readyAt: number)
	return { coralId = "sun_coral", plantedAt = plantedAt, readyAt = readyAt }
end

local P = placement(1000, 1100)

return {
	["progress is 0 at plant, 0.5 halfway, 1 at ready and after"] = function()
		Expect.near(GrowthMath.GetProgress(P, 1000), 0)
		Expect.near(GrowthMath.GetProgress(P, 1050), 0.5)
		Expect.near(GrowthMath.GetProgress(P, 1100), 1)
		Expect.near(GrowthMath.GetProgress(P, 99999), 1)
	end,
	["clock rollback gives progress 0 and Fragment"] = function()
		Expect.near(GrowthMath.GetProgress(P, 900), 0)
		Expect.equal(GrowthMath.GetStage(P, 900), "Fragment")
	end,
	["readyAt <= plantedAt counts as fully grown"] = function()
		Expect.near(GrowthMath.GetProgress(placement(10, 10), 5), 1)
	end,
	["IsReady flips exactly at readyAt"] = function()
		Expect.falsy(GrowthMath.IsReady(P, 1099))
		Expect.truthy(GrowthMath.IsReady(P, 1100))
	end,
	["speedMultiplier halves grow time and rounds up"] = function()
		Expect.equal(GrowthMath.ComputeReadyAt(0, 300, 2), 150)
		Expect.equal(GrowthMath.ComputeReadyAt(0, 301, 2), 151)
		Expect.equal(GrowthMath.ComputeReadyAt(0, 300), 300)
		Expect.throws(function()
			GrowthMath.ComputeReadyAt(0, 0)
		end)
		Expect.throws(function()
			GrowthMath.ComputeReadyAt(0, 10, 0)
		end)
	end,
	["Flourishing only when ready and matched"] = function()
		Expect.equal(GrowthMath.GetStage(P, 1100, true), "Flourishing")
		Expect.equal(GrowthMath.GetStage(P, 1100, false), "Mature")
		Expect.equal(GrowthMath.GetStage(P, 1100), "Mature")
		Expect.equal(GrowthMath.GetStage(P, 1050, true), "Growing")
	end,
	["stages progress Fragment > Sprouting > Growing > Mature"] = function()
		Expect.equal(GrowthMath.GetStage(P, 1001), "Fragment")
		Expect.equal(GrowthMath.GetStage(P, 1010), "Sprouting")
		Expect.equal(GrowthMath.GetStage(P, 1040), "Growing")
		Expect.equal(GrowthMath.GetStage(P, 1100), "Mature")
		Expect.equal(GrowthMath.GetVisualStage("Sprouting"), "Bud")
		Expect.equal(GrowthMath.GetVisualStage("Growing"), "Young")
		Expect.equal(GrowthMath.GetVisualStage("Flourishing"), "Mature")
	end,
	["seconds remaining never negative"] = function()
		Expect.equal(GrowthMath.GetSecondsRemaining(P, 1090), 10)
		Expect.equal(GrowthMath.GetSecondsRemaining(P, 5000), 0)
	end,
	["next stage change timestamps"] = function()
		local fragmentEnd = 1000 + GrowthConfig.FRAGMENT_SECONDS
		local growingAt = 1000 + 100 * GrowthConfig.STAGE_THRESHOLDS.Growing
		Expect.near(GrowthMath.GetNextStageChangeAt(P, 1000) :: number, fragmentEnd)
		Expect.near(GrowthMath.GetNextStageChangeAt(P, fragmentEnd) :: number, growingAt)
		Expect.near(GrowthMath.GetNextStageChangeAt(P, 1050) :: number, 1100)
		Expect.equal(GrowthMath.GetNextStageChangeAt(P, 1100), nil)
	end,
}
