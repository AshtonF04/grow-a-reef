--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Expect = require(script.Parent.Expect)
local Shared = ReplicatedStorage.Shared
local EconomyMath = require(Shared.Logic.EconomyMath)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local CoralDefinitions = require(Shared.Config.CoralDefinitions)
local SocketDefinitions = require(Shared.Config.SocketDefinitions)

local brain = CoralDefinitions.brain_coral -- Dim / Low, baseYield 40
local branch = CoralDefinitions.branch_coral -- Bright / High, baseYield 10
local sun = CoralDefinitions.sun_coral -- Bright / Medium

-- Table-driven cases: { name, run = () -> number, expected }
local yieldCases = {
	{ name = "no match (brain on surge_channel)", run = function()
		return EconomyMath.ComputeHarvestYield(brain, SocketDefinitions.surge_channel, "Mature")
	end, expected = 40 },
	{ name = "flow only (brain on sun_ledge)", run = function()
		return EconomyMath.ComputeHarvestYield(brain, SocketDefinitions.sun_ledge, "Mature")
	end, expected = 44 },
	{ name = "light only (brain on kelp_shade)", run = function()
		return EconomyMath.ComputeHarvestYield(brain, SocketDefinitions.kelp_shade, "Mature")
	end, expected = 46 },
	{ name = "both, Flourishing (brain on deep_nook)", run = function()
		return EconomyMath.ComputeHarvestYield(brain, SocketDefinitions.deep_nook, "Flourishing")
	end, expected = 62 },
	{ name = "both, Mature (brain on deep_nook)", run = function()
		return EconomyMath.ComputeHarvestYield(brain, SocketDefinitions.deep_nook, "Mature")
	end, expected = 50 },
	{ name = "sun on sandy_patch Flourishing rounds down", run = function()
		return EconomyMath.ComputeHarvestYield(sun, SocketDefinitions.sandy_patch, "Flourishing")
	end, expected = math.floor(sun.baseYield * 1.25 * 1.25) },
	{ name = "Growing is not claimable", run = function()
		return EconomyMath.ComputeHarvestYield(branch, SocketDefinitions.surge_channel, "Growing")
	end, expected = 0 },
	{ name = "Fragment is not claimable", run = function()
		return EconomyMath.ComputeHarvestYield(branch, SocketDefinitions.surge_channel, "Fragment")
	end, expected = 0 },
}

local spec: { [string]: () -> () } = {}

for _, case in yieldCases do
	spec["yield: " .. case.name] = function()
		Expect.equal(case.run(), case.expected)
	end
end

spec["condition bonus values"] = function()
	Expect.near(EconomyMath.GetConditionBonus(brain, SocketDefinitions.surge_channel), 0)
	Expect.near(EconomyMath.GetConditionBonus(brain, SocketDefinitions.sun_ledge), 0.10)
	Expect.near(EconomyMath.GetConditionBonus(brain, SocketDefinitions.kelp_shade), 0.15)
	Expect.near(EconomyMath.GetConditionBonus(brain, SocketDefinitions.deep_nook), 0.25)
	Expect.truthy(EconomyMath.IsConditionMatch(brain, SocketDefinitions.deep_nook))
	Expect.falsy(EconomyMath.IsConditionMatch(brain, SocketDefinitions.sun_ledge))
end

spec["boost cap: ten +0.5 boosts give exactly the max"] = function()
	local boosts = table.create(10, 0.5)
	Expect.near(EconomyMath.CombineBoosts(boosts), EconomyConfig.MAX_TOTAL_MULTIPLIER)
end

spec["negative boosts are ignored"] = function()
	Expect.near(EconomyMath.CombineBoosts({ -0.5, 0.2 }), 1.2)
end

spec["minimum payout is 1"] = function()
	local tiny = table.clone(sun) :: any
	tiny.baseYield = 0.1
	Expect.equal(EconomyMath.ComputeHarvestYield(tiny, SocketDefinitions.surge_channel, "Mature"), 1)
end

spec["fragment prices and errors"] = function()
	Expect.equal(EconomyMath.GetFragmentPrice("branch_coral", 1), 8)
	Expect.equal(EconomyMath.GetFragmentPrice("branch_coral", EconomyConfig.MAX_BUY_QTY), 8 * EconomyConfig.MAX_BUY_QTY)
	Expect.throws(function()
		EconomyMath.GetFragmentPrice("branch_coral", 0)
	end)
	Expect.throws(function()
		EconomyMath.GetFragmentPrice("branch_coral", EconomyConfig.MAX_BUY_QTY + 1)
	end)
	Expect.throws(function()
		EconomyMath.GetFragmentPrice("bogus", 1)
	end)
end

spec["socket unlock cost comes from config"] = function()
	Expect.equal(EconomyMath.GetSocketUnlockCost("sun_ledge"), SocketDefinitions.sun_ledge.unlockCostShells)
end

return spec
