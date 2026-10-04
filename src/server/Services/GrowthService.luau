--!strict
-- Orchestrates the core loop: Plant and Claim. Checks every rule first, then makes every change with no
-- yield in between (stops duplication exploits). Uses the lower services instead of touching data itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local GrowthMath = require(ReplicatedStorage.Shared.Logic.GrowthMath)
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local TimeUtil = require(ReplicatedStorage.Shared.Util.TimeUtil)
local PlayerStateService = require(script.Parent.PlayerStateService)
local InventoryService = require(script.Parent.InventoryService)
local PlacementService = require(script.Parent.PlacementService)

type Placement = Types.Placement
type ClaimReward = Types.ClaimReward
type Result<T> = Types.Result<T>

local GrowthService = {}

GrowthService.CoralPlanted = Signal.new() :: Signal.Signal<Player, string, Placement>
GrowthService.CoralClaimed = Signal.new() :: Signal.Signal<Player, string, ClaimReward>

function GrowthService.Plant(player: Player, socketId: string, coralId: string): Result<Placement>
	-- 1. Validate (first error wins, nothing changes on any error)
	local data = PlayerStateService.GetState(player)
	if data == nil or not PlayerStateService.IsLoaded(player) then
		return Result.error("NotLoaded")
	end
	if SocketDefinitions[socketId] == nil then
		return Result.error("UnknownSocket")
	end
	local coral = CoralDefinitions[coralId]
	if coral == nil then
		return Result.error("UnknownCoral")
	end
	if not PlacementService.IsSocketUnlocked(player, socketId) then
		return Result.error("SocketLocked")
	end
	if PlacementService.IsSocketOccupied(player, socketId) then
		return Result.error("SocketOccupied")
	end
	if coral.zone > data.unlocks.zone then
		return Result.error("ZoneLocked")
	end
	if InventoryService.GetFragmentCount(player, coralId) < 1 then
		return Result.error("NotEnoughFragments")
	end

	-- 2. Mutate (no yields)
	local consumed = InventoryService.ConsumeFragment(player, coralId, 1, "plant")
	if not consumed.ok then
		return Result.error("Internal")
	end
	local plantedAt = TimeUtil.Now()
	local placement: Placement = {
		coralId = coralId,
		plantedAt = plantedAt,
		readyAt = GrowthMath.ComputeReadyAt(plantedAt, coral.growSeconds),
		trait = nil, -- traits arrive in M6-03
	}
	local placed = PlacementService.SetPlacement(player, socketId, placement)
	if not placed.ok then
		InventoryService.GrantFragment(player, coralId, 1, "plant_refund")
		warn(("GrowthService: SetPlacement failed after validation (%s) for UserId %d"):format(tostring(placed.err), player.UserId))
		return Result.error("Internal")
	end

	-- Planting a species counts as owning it in the collection book
	if not data.discoveries.corals[coralId] then
		data.discoveries.corals[coralId] = true
		PlayerStateService.MarkDirty(player, "discoveries")
	end

	GrowthService.CoralPlanted:Fire(player, socketId, placement)
	return Result.result(placement)
end

-- Claim removes the coral, pays Shells and returns 1 fragment, so replanting is always free (Decision 1).
function GrowthService.Claim(player: Player, socketId: string): Result<ClaimReward>
	-- 1. Validate
	if not PlayerStateService.IsLoaded(player) then
		return Result.error("NotLoaded")
	end
	if SocketDefinitions[socketId] == nil then
		return Result.error("UnknownSocket")
	end
	local placement = PlacementService.GetPlacement(player, socketId)
	if placement == nil then
		return Result.error("SocketEmpty")
	end
	if not GrowthMath.IsReady(placement, TimeUtil.Now()) then
		return Result.error("NotReady")
	end
	local coral = CoralDefinitions[placement.coralId]
	if coral == nil then
		warn("GrowthService: placement references unknown coral '" .. placement.coralId .. "'")
		return Result.error("Internal")
	end

	-- 2. Mutate (no yields). Clearing first is the once-only guard: a second claim finds an empty socket.
	local cleared = PlacementService.ClearPlacement(player, socketId)
	if not cleared.ok then
		return Result.error(cleared.err)
	end
	local shells = coral.baseYield -- TODO(M4-03): EconomyMath
	InventoryService.GrantShells(player, shells, "claim")
	InventoryService.GrantFragment(player, coral.id, 1, "claim_return")

	local reward: ClaimReward = {
		shells = shells,
		fragmentCoralId = coral.id,
		trait = placement.trait,
		newDiscoveries = {},
	}
	GrowthService.CoralClaimed:Fire(player, socketId, reward)
	return Result.result(reward)
end

function GrowthService.GetStage(player: Player, socketId: string): Types.GrowthStage?
	local placement = PlacementService.GetPlacement(player, socketId)
	if placement == nil then
		return nil
	end
	return GrowthMath.GetStage(placement, TimeUtil.Now())
end

function GrowthService.GetSnapshot(player: Player): { Types.SocketSnapshot }
	local now = TimeUtil.Now()
	local out = {}
	for socketId, placement in PlacementService.GetAllPlacements(player) do
		table.insert(out, {
			socketId = socketId,
			coralId = placement.coralId,
			stage = GrowthMath.GetStage(placement, now),
			progress = GrowthMath.GetProgress(placement, now),
			readyAt = placement.readyAt,
			ready = GrowthMath.IsReady(placement, now),
		})
	end
	return out
end

function GrowthService:Init() end

return GrowthService
