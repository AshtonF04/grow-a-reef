--!strict
-- Owns which sockets are unlocked and which coral sits in each. No economy rules (ShopService) and no
-- timing rules (GrowthService) live here. Every change is announced by a signal. Never yields.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local PlayerStateService = require(script.Parent.PlayerStateService)

type Placement = Types.Placement
type Result<T> = Types.Result<T>

local PlacementService = {}

PlacementService.SocketUnlocked = Signal.new() :: Signal.Signal<Player, string>
PlacementService.CoralPlaced = Signal.new() :: Signal.Signal<Player, string, Placement>
PlacementService.PlacementCleared = Signal.new() :: Signal.Signal<Player, string, Placement>

local function getLoadedData(player: Player): Types.PlayerData?
	if not PlayerStateService.IsLoaded(player) then
		return nil
	end
	return PlayerStateService.GetState(player)
end

local function copyPlacement(p: Placement): Placement
	return { coralId = p.coralId, plantedAt = p.plantedAt, readyAt = p.readyAt, trait = p.trait }
end

function PlacementService.IsSocketUnlocked(player: Player, socketId: string): boolean
	local data = getLoadedData(player)
	return data ~= nil and SocketDefinitions[socketId] ~= nil and data.unlocks.sockets[socketId] == true
end

function PlacementService.UnlockSocket(player: Player, socketId: string): Result<nil>
	local data = getLoadedData(player)
	if data == nil then
		return Result.error("NotLoaded")
	end
	if SocketDefinitions[socketId] == nil then
		return Result.error("UnknownSocket")
	end
	if data.unlocks.sockets[socketId] == true then
		return Result.error("AlreadyUnlocked")
	end

	data.unlocks.sockets[socketId] = true
	PlayerStateService.MarkDirty(player, "unlocks")
	PlacementService.SocketUnlocked:Fire(player, socketId)
	return Result.result(nil)
end

function PlacementService.GetPlacement(player: Player, socketId: string): Placement?
	local data = getLoadedData(player)
	if data == nil or SocketDefinitions[socketId] == nil then
		return nil
	end
	local p = data.placements[socketId]
	return if p then copyPlacement(p) else nil
end

function PlacementService.GetAllPlacements(player: Player): { [string]: Placement }
	local data = getLoadedData(player)
	local out = {}
	if data then
		for socketId, p in data.placements do
			out[socketId] = copyPlacement(p)
		end
	end
	return out
end

function PlacementService.IsSocketOccupied(player: Player, socketId: string): boolean
	local data = getLoadedData(player)
	return data ~= nil and data.placements[socketId] ~= nil
end

function PlacementService.SetPlacement(player: Player, socketId: string, placement: Placement): Result<nil>
	local data = getLoadedData(player)
	if data == nil then
		return Result.error("NotLoaded")
	end
	if SocketDefinitions[socketId] == nil then
		return Result.error("UnknownSocket")
	end
	if data.unlocks.sockets[socketId] ~= true then
		return Result.error("SocketLocked")
	end
	if data.placements[socketId] ~= nil then
		return Result.error("SocketOccupied")
	end

	local record = copyPlacement(placement)
	data.placements[socketId] = record
	PlayerStateService.MarkDirty(player, "placements")
	PlacementService.CoralPlaced:Fire(player, socketId, copyPlacement(record))
	return Result.result(nil)
end

function PlacementService.ClearPlacement(player: Player, socketId: string): Result<Placement>
	local data = getLoadedData(player)
	if data == nil then
		return Result.error("NotLoaded")
	end
	if SocketDefinitions[socketId] == nil then
		return Result.error("UnknownSocket")
	end
	local removed = data.placements[socketId]
	if removed == nil then
		return Result.error("SocketEmpty")
	end

	data.placements[socketId] = nil
	PlayerStateService.MarkDirty(player, "placements")
	PlacementService.PlacementCleared:Fire(player, socketId, copyPlacement(removed))
	return Result.result(removed)
end

function PlacementService:Init() end

return PlacementService
