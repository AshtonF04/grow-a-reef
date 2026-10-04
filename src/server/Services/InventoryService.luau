--!strict
-- The only place balances change. Every change is validated, logged, replicated and announced the same way.
-- No other file may write to data.currencies or data.inventory directly.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local PlayerStateService = require(script.Parent.PlayerStateService)
local TransactionLog = require(script.Parent.Parent.Util.TransactionLog)

-- TODO(M4-01): moves to EconomyConfig
local MAX_GRANT_PER_CALL = 10000

type Result<T> = Types.Result<T>

local InventoryService = {}

-- (player, currency, newAmount, delta, reason)
InventoryService.CurrencyChanged = Signal.new() :: Signal.Signal<Player, string, number, number, string>
-- (player, coralId, newCount, delta, reason)
InventoryService.FragmentsChanged = Signal.new() :: Signal.Signal<Player, string, number, number, string>

local function isValidAmount(n: any): boolean
	return type(n) == "number" and n == n and math.floor(n) == n and n > 0 and n <= MAX_GRANT_PER_CALL
end

function InventoryService.GetShells(player: Player): number
	local data = PlayerStateService.GetState(player)
	return if data then data.currencies.shells else 0
end

function InventoryService.GetPearls(player: Player): number
	local data = PlayerStateService.GetState(player)
	return if data then data.currencies.pearls else 0
end

local function changeShells(player: Player, delta: number, reason: string): Result<number>
	local data = PlayerStateService.GetState(player)
	if data == nil or not PlayerStateService.IsLoaded(player) then
		return Result.error("NotLoaded")
	end
	local newAmount = data.currencies.shells + delta
	if newAmount < 0 then
		return Result.error("NotEnoughShells")
	end

	data.currencies.shells = newAmount
	TransactionLog.Record(player, "currency", "shells", delta, reason)
	PlayerStateService.MarkDirty(player, "currencies")
	InventoryService.CurrencyChanged:Fire(player, "shells", newAmount, delta, reason)
	return Result.result(newAmount)
end

function InventoryService.GrantShells(player: Player, amount: number, reason: string): Result<number>
	if not isValidAmount(amount) then
		return Result.error("InvalidArgs")
	end
	return changeShells(player, amount, reason)
end

function InventoryService.SpendShells(player: Player, amount: number, reason: string): Result<number>
	if not isValidAmount(amount) then
		return Result.error("InvalidArgs")
	end
	return changeShells(player, -amount, reason)
end

function InventoryService.GetFragmentCount(player: Player, coralId: string): number
	local data = PlayerStateService.GetState(player)
	return if data then data.inventory.fragments[coralId] or 0 else 0
end

local function changeFragments(player: Player, coralId: string, delta: number, reason: string): Result<number>
	local data = PlayerStateService.GetState(player)
	if data == nil or not PlayerStateService.IsLoaded(player) then
		return Result.error("NotLoaded")
	end
	if CoralDefinitions[coralId] == nil then
		return Result.error("UnknownCoral")
	end
	local fragments = data.inventory.fragments
	local newCount = (fragments[coralId] or 0) + delta
	if newCount < 0 then
		return Result.error("NotEnoughFragments")
	end

	-- Remove empty entries so saves stay small
	fragments[coralId] = if newCount == 0 then nil else newCount
	TransactionLog.Record(player, "fragment", coralId, delta, reason)
	PlayerStateService.MarkDirty(player, "inventory")
	InventoryService.FragmentsChanged:Fire(player, coralId, newCount, delta, reason)
	return Result.result(newCount)
end

function InventoryService.GrantFragment(player: Player, coralId: string, qty: number, reason: string): Result<number>
	if not isValidAmount(qty) then
		return Result.error("InvalidArgs")
	end
	return changeFragments(player, coralId, qty, reason)
end

function InventoryService.ConsumeFragment(player: Player, coralId: string, qty: number, reason: string): Result<number>
	if not isValidAmount(qty) then
		return Result.error("InvalidArgs")
	end
	return changeFragments(player, coralId, -qty, reason)
end

function InventoryService:Init() end

return InventoryService
