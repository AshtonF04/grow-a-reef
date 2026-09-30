-- Rules and economy checks. Run with tests/run.ps1.

local ReefRules = __require("ReefRules")
local GameConfig = __require("GameConfig")
local CoralDefinitions = __require("CoralDefinitions")
local Service = __require("PlayerStateService")

local passed, failed = 0, 0
local function check(name, condition, detail)
	if condition then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (if detail then "  (" .. tostring(detail) .. ")" else ""))
	end
end

local nextUser = 0
local function newPlayer(record)
	nextUser += 1
	local player = { UserId = nextUser, Name = "tester" .. nextUser }
	local state = Service.InitPlayerState(player, record)
	return player, state
end

-- Every coral flourishes on exactly one socket, and every socket hosts exactly one coral.
do
	local homes = {}
	for _, coral in ReefRules.OrderedCorals() do
		local home = ReefRules.HomeSocket(coral.id)
		check("home exists for " .. coral.id, home ~= nil)
		if home then
			check("home unique for " .. home.id, homes[home.id] == nil, homes[home.id])
			homes[home.id] = coral.id
		end
	end
	for _, socket in ReefRules.OrderedSockets() do
		check("socket has a home coral: " .. socket.id, ReefRules.HomeCoral(socket.id) ~= nil)
	end
end

-- Fresh reef: Sandy Patch open, one Sun Coral, a clear first step.
do
	local _, state = newPlayer(nil)
	check("sandy open", state.socketUnlocks.sandy_patch == true)
	check("sun ledge closed", state.socketUnlocks.sun_ledge == false)
	check("one sun fragment", state.fragments.sun_coral == 1)
	local text, kind, target = ReefRules.NextStep(state, __clock)
	check("first step is plant", kind == "plant", text)
	check("first step targets sandy", target == "sandy_patch", target)
end

-- Plant, early harvest rejected, harvest pays the flourish bonus once.
do
	local player, state = newPlayer(nil)
	local ok = Service.PlantCoral(player, "sandy_patch", "sun_coral")
	check("plant ok", ok)
	check("fragment spent", state.fragments.sun_coral == 0)
	local again = Service.PlantCoral(player, "sandy_patch", "sun_coral")
	check("double plant rejected", not again)
	local early = Service.HarvestCoral(player, "sandy_patch")
	check("early harvest rejected", not early)

	__clock += ReefRules.GrowDuration("sun_coral") + 1
	local harvested = Service.HarvestCoral(player, "sandy_patch")
	local expected = math.floor(CoralDefinitions.sun_coral.baseYield * GameConfig.FlourishMultiplier + 0.5)
	check("harvest ok", harvested)
	check("flourish payout", state.shells == expected, state.shells)
	check("fragment returned", state.fragments.sun_coral == 1)
	local twice = Service.HarvestCoral(player, "sandy_patch")
	check("double harvest rejected", not twice)
	check("no double payout", state.shells == expected, state.shells)
end

-- Mismatched coral pays base yield, never less.
do
	check("partial pays base", ReefRules.HarvestYield("sun_coral", "sun_ledge") == CoralDefinitions.sun_coral.baseYield)
	check("poor pays base", ReefRules.HarvestYield("sun_coral", "deep_nook") == CoralDefinitions.sun_coral.baseYield)
end

-- Unlock order and costs are enforced by the server.
do
	local player, state = newPlayer(nil)
	state.shells = 1000
	local skipped = Service.UnlockSocket(player, "surge_channel")
	check("cannot skip unlock order", not skipped)
	check("no charge for rejected unlock", state.shells == 1000)
	check("unlock in order", Service.UnlockSocket(player, "sun_ledge"))
	check("unlock charged", state.shells == 990, state.shells)
	check("reopen rejected", not Service.UnlockSocket(player, "sun_ledge"))
end

-- Nursery: exact charge, no negatives, holding cap.
do
	local player, state = newPlayer(nil)
	state.shells = CoralDefinitions.brain_coral.nurseryCost - 1
	check("cannot buy short", not Service.BuyFragment(player, "brain_coral"))
	check("no charge when short", state.shells == CoralDefinitions.brain_coral.nurseryCost - 1)
	state.shells += 1
	check("buy ok", Service.BuyFragment(player, "brain_coral"))
	check("exact charge", state.shells == 0, state.shells)
	check("fragment added", state.fragments.brain_coral == 1)
	check("unknown coral rejected", not Service.BuyFragment(player, "fake_coral"))
	state.shells = 1e6
	state.fragments.sun_coral = GameConfig.MaxFragmentsPerCoral
	check("holding cap", not Service.BuyFragment(player, "sun_coral"))
end

-- Best fragment prefers the flourishing coral for a socket.
do
	local _, state = newPlayer(nil)
	state.fragments.brain_coral = 1
	check("best fit for sun ledge is brain", ReefRules.BestFragment(state, "sun_ledge") == "brain_coral")
	check("best fit for sandy is sun", ReefRules.BestFragment(state, "sandy_patch") == "sun_coral")
	check("preferred is honoured", ReefRules.BestFragment(state, "sandy_patch", "brain_coral") == "brain_coral")
end

-- Save round trip and hostile records.
do
	local player, state = newPlayer(nil)
	state.shells = 57
	Service.PlantCoral(player, "sandy_patch", "sun_coral")
	local record = Service.ToRecord(state)
	local _, restored = newPlayer(record)
	check("shells restored", restored.shells == 57)
	check("placement restored", restored.placements.sandy_patch ~= nil)
	check("plantedAt restored", restored.placements.sandy_patch.plantedAt == state.placements.sandy_patch.plantedAt)

	local _, cleaned = newPlayer({
		shells = -40,
		pearls = 0 / 0,
		fragments = { sun_coral = 3.7, fake_coral = 9, brain_coral = 1e9 },
		socketUnlocks = { sun_ledge = true, moon_base = true },
		placements = {
			sandy_patch = { coralId = "sun_coral", plantedAt = __clock + 99999 },
			deep_nook = { coralId = "sun_coral", plantedAt = 1 },
			sun_ledge = { coralId = "fake_coral", plantedAt = 1 },
		},
	})
	check("negative shells clamped", cleaned.shells == 0, cleaned.shells)
	check("nan pearls ignored", cleaned.pearls == GameConfig.StartingPearls)
	check("fragments floored", cleaned.fragments.sun_coral == 3)
	check("unknown fragment dropped", cleaned.fragments.fake_coral == nil)
	check("fragment cap on load", cleaned.fragments.brain_coral == GameConfig.MaxFragmentsPerCoral)
	check("unknown socket dropped", cleaned.socketUnlocks.moon_base == nil)
	check("future plantedAt clamped", cleaned.placements.sandy_patch.plantedAt <= __clock)
	check("placement on locked socket dropped", cleaned.placements.deep_nook == nil)
	check("unknown coral placement dropped", cleaned.placements.sun_ledge == nil)
end

-- A bot follows NextStep from a fresh reef until every socket is open and planted.
do
	local player, state = newPlayer(nil)
	local startClock = __clock
	local steps = 0
	local stuck = nil
	while steps < 2000 do
		steps += 1
		local text, kind, target = ReefRules.NextStep(state, __clock)
		local allOpen = true
		for _, socket in ReefRules.OrderedSockets() do
			if not state.socketUnlocks[socket.id] or state.placements[socket.id] == nil then
				allOpen = false
			end
		end
		if allOpen then
			break
		end
		local ok = true
		if kind == "harvest" then
			ok = Service.HarvestCoral(player, target)
		elseif kind == "plant" then
			ok = Service.PlantCoral(player, target, ReefRules.BestFragment(state, target))
		elseif kind == "unlock" then
			ok = Service.UnlockSocket(player, target)
		elseif kind == "buy" then
			ok = Service.BuyFragment(player, ReefRules.HomeCoral(target).id)
		elseif kind == "wait" or kind == "save" then
			local soonest = math.huge
			for socketId, placement in state.placements do
				soonest = math.min(soonest, ReefRules.RemainingSeconds(placement.plantedAt, placement.coralId, __clock))
			end
			if soonest == math.huge then
				stuck = text
				break
			end
			__clock += soonest + 0.1
		else
			stuck = text
			break
		end
		if not ok then
			stuck = "action failed: " .. text
			break
		end
	end
	check("bot never gets stuck", stuck == nil, stuck)
	local elapsed = __clock - startClock
	local scale = GameConfig.DevTimeScale or 1
	print(string.format(
		"bot filled all six sockets in %d steps, %s on this build's timers (%s with real timers)",
		steps,
		ReefRules.FormatTime(elapsed),
		ReefRules.FormatTime(elapsed / scale)
	))
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed", 0)
end
