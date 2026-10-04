--!strict
-- Economy pacing simulation (M4-07). Target: all six sockets unlocked in 15–25 minutes of play.
-- Uses only configs, GrowthMath and EconomyMath (no services, no Instances). Not a .spec, so the
-- runner skips it. Run from the command bar:
--   local S = require(game.ServerStorage.Tests.EconomySim) S.PrintReport(S.Run("greedy")) S.PrintReport(S.Run("fastest"))
--
-- Tuning notes: see TUNING at the bottom of this file.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local CoralDefinitions = require(Shared.Config.CoralDefinitions)
local SocketDefinitions = require(Shared.Config.SocketDefinitions)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local EconomyMath = require(Shared.Logic.EconomyMath)
local GrowthMath = require(Shared.Logic.GrowthMath)

export type Strategy = "greedy" | "fastest"
export type Report = {
	strategy: Strategy,
	unlockMinutes: { { socketId: string, minutes: number } },
	totalMinutes: number?,
	shellsEarned: number,
	shellsSpent: number,
}

local THINK_SECONDS = 5 -- fixed "player think time" per action
local MAX_SECONDS = 4 * 3600 -- safety cap so the loop always ends

local EconomySim = {}

local function socketsByOrder(): { string }
	local ids = {}
	for id in SocketDefinitions do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return SocketDefinitions[a].unlockOrder < SocketDefinitions[b].unlockOrder
	end)
	return ids
end

local function yieldFor(coralId: string, socketId: string): number
	local coral = CoralDefinitions[coralId]
	local socket = SocketDefinitions[socketId]
	local stage = if EconomyMath.IsConditionMatch(coral, socket) then "Flourishing" else "Mature"
	return EconomyMath.ComputeHarvestYield(coral, socket, stage)
end

-- Ranks corals for a socket: greedy = best Shells per second, fastest = shortest grow time
local function score(strategy: Strategy, coralId: string, socketId: string): number
	local coral = CoralDefinitions[coralId]
	if strategy == "fastest" then
		return -coral.growSeconds
	end
	return yieldFor(coralId, socketId) / coral.growSeconds
end

function EconomySim.Run(strategy: Strategy?): Report
	local strat: Strategy = strategy or "greedy"
	local order = socketsByOrder()
	local unlocked: { [string]: boolean } = {}
	for id, s in SocketDefinitions do
		unlocked[id] = s.unlockCostShells == 0
	end
	local fragments: { [string]: number } = { sun_coral = 1 }
	local placements: { [string]: { coralId: string, plantedAt: number, readyAt: number } } = {}
	local shells = EconomyConfig.STARTING_SHELLS
	local earned, spent = 0, 0
	local unlockMinutes = {}
	local busyUntil = 0

	local function nextLocked(): string?
		for _, id in order do
			if not unlocked[id] then
				return id
			end
		end
		return nil
	end

	local function bestOwned(socketId: string): string?
		local best, bestScore = nil, -math.huge
		for coralId, n in fragments do
			if n > 0 then
				local s = score(strat, coralId, socketId)
				if s > bestScore then
					best, bestScore = coralId, s
				end
			end
		end
		return best
	end

	local function bestToBuy(socketId: string): string?
		local best, bestScore = nil, -math.huge
		for coralId, coral in CoralDefinitions do
			if coral.zone == 1 and coral.fragmentPriceShells <= shells then
				local s = score(strat, coralId, socketId)
				if s > bestScore then
					best, bestScore = coralId, s
				end
			end
		end
		return best
	end

	for t = 0, MAX_SECONDS do
		if nextLocked() == nil then
			break
		end
		if t < busyUntil then
			continue
		end

		local acted = false
		-- 1. Claim anything ready
		for socketId, p in placements do
			if GrowthMath.IsReady(p, t) then
				local gain = yieldFor(p.coralId, socketId)
				shells += gain
				earned += gain
				fragments[p.coralId] = (fragments[p.coralId] or 0) + EconomyConfig.HARVEST_FRAGMENT_RETURN
				placements[socketId] = nil
				acted = true
				break
			end
		end
		-- 2. Buy the next socket as soon as it's affordable
		if not acted then
			local nextId = nextLocked()
			if nextId and shells >= SocketDefinitions[nextId].unlockCostShells then
				shells -= SocketDefinitions[nextId].unlockCostShells
				spent += SocketDefinitions[nextId].unlockCostShells
				unlocked[nextId] = true
				table.insert(unlockMinutes, { socketId = nextId, minutes = t / 60 })
				acted = true
			end
		end
		-- 3. Plant owned fragments in empty unlocked sockets; 4. buy one if none owned
		if not acted then
			for _, socketId in order do
				if unlocked[socketId] and placements[socketId] == nil then
					local coralId = bestOwned(socketId)
					if coralId then
						fragments[coralId] -= 1
						local coral = CoralDefinitions[coralId]
						placements[socketId] = { coralId = coralId, plantedAt = t, readyAt = GrowthMath.ComputeReadyAt(t, coral.growSeconds) }
						acted = true
					else
						local buy = bestToBuy(socketId)
						if buy then
							local price = EconomyMath.GetFragmentPrice(buy, 1)
							shells -= price
							spent += price
							fragments[buy] = (fragments[buy] or 0) + 1
							acted = true
						end
					end
					break
				end
			end
		end
		if acted then
			busyUntil = t + THINK_SECONDS
		end
	end

	local total = if nextLocked() == nil and #unlockMinutes > 0 then unlockMinutes[#unlockMinutes].minutes else nil
	return { strategy = strat, unlockMinutes = unlockMinutes, totalMinutes = total, shellsEarned = earned, shellsSpent = spent }
end

function EconomySim.PrintReport(report: Report)
	print(("[EconomySim] strategy=%s"):format(report.strategy))
	for _, u in report.unlockMinutes do
		print(("  %-14s unlocked at %5.1f min"):format(u.socketId, u.minutes))
	end
	print(("  ALL SIX: %s min | earned %d, spent %d"):format(
		if report.totalMinutes then string.format("%.1f", report.totalMinutes) else "never (cap hit)",
		report.shellsEarned,
		report.shellsSpent
	))
end

--[[ TUNING (2026-10-03) — placeholder values pending review by both developers
	Before: Sun 300s/18, sockets 10/50/50/120/120 -> greedy 34.3 min, fastest 30.6 min (too slow;
	the first unlock also took 5 min, a long first wait for a new player).
	After:  Sun 120s/12, sockets 10/40/50/90/110 -> both strategies 20.2 min
	        (unlocks at 2.1, 6.3, 10.9, 15.2, 20.2 min): centred in the 15–25 min target with an even ramp.
	Branch (180s/10, 8 Shells) and Brain (600s/40, 20 Shells) were left at the M4-02 values so the
	M4-03 payout checks (Brain 62 on deep_nook, 44 on sun_ledge) still hold.
]]

return EconomySim
