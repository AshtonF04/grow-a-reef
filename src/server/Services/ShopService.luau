--!strict
-- The main Shells sink: buying fragments and socket unlocks. Prices only ever come from config; the
-- client never sends a price. Separate from the future CommerceService (Robux). Never yields.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EconomyMath = require(ReplicatedStorage.Shared.Logic.EconomyMath)
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local PlayerStateService = require(script.Parent.PlayerStateService)
local InventoryService = require(script.Parent.InventoryService)
local PlacementService = require(script.Parent.PlacementService)

type Result<T> = Types.Result<T>

export type FragmentEntry = { coralId: string, price: number, affordable: boolean }
export type SocketEntry = { socketId: string, cost: number, affordable: boolean, available: boolean }
export type Catalog = { fragments: { FragmentEntry }, sockets: { SocketEntry } }

local ShopService = {}

ShopService.FragmentBought = Signal.new() :: Signal.Signal<Player, string, number, number>
ShopService.SocketBought = Signal.new() :: Signal.Signal<Player, string, number>

-- True when every socket with a lower unlockOrder is already unlocked
local function prerequisitesMet(data: Types.PlayerData, socketId: string): boolean
	local order = SocketDefinitions[socketId].unlockOrder
	for otherId, other in SocketDefinitions do
		if other.unlockOrder < order and data.unlocks.sockets[otherId] ~= true then
			return false
		end
	end
	return true
end

function ShopService.GetCatalog(player: Player): Result<Catalog>
	local data = PlayerStateService.GetState(player)
	if data == nil then
		return Result.error("NotLoaded")
	end
	local shells = data.currencies.shells

	local fragments: { FragmentEntry } = {}
	for coralId, coral in CoralDefinitions do
		if coral.zone <= data.unlocks.zone then
			table.insert(fragments, { coralId = coralId, price = coral.fragmentPriceShells, affordable = shells >= coral.fragmentPriceShells })
		end
	end
	table.sort(fragments, function(a, b)
		return a.price < b.price
	end)

	local sockets: { SocketEntry } = {}
	for socketId, socket in SocketDefinitions do
		if data.unlocks.sockets[socketId] ~= true then
			table.insert(sockets, {
				socketId = socketId,
				cost = socket.unlockCostShells,
				affordable = shells >= socket.unlockCostShells,
				available = prerequisitesMet(data, socketId),
			})
		end
	end
	table.sort(sockets, function(a, b)
		return SocketDefinitions[a.socketId].unlockOrder < SocketDefinitions[b.socketId].unlockOrder
	end)

	return Result.result({ fragments = fragments, sockets = sockets })
end

-- Returns the new fragment count
function ShopService.BuyFragment(player: Player, coralId: string, qty: number): Result<number>
	local data = PlayerStateService.GetState(player)
	if data == nil or not PlayerStateService.IsLoaded(player) then
		return Result.error("NotLoaded")
	end
	local coral = CoralDefinitions[coralId]
	if coral == nil then
		return Result.error("UnknownCoral")
	end
	if type(qty) ~= "number" or math.floor(qty) ~= qty or qty < 1 or qty > EconomyConfig.MAX_BUY_QTY then
		return Result.error("InvalidArgs")
	end
	if coral.zone > data.unlocks.zone then
		return Result.error("ZoneLocked")
	end
	local price = EconomyMath.GetFragmentPrice(coralId, qty)
	if data.currencies.shells < price then
		return Result.error("NotEnoughShells")
	end

	local spent = InventoryService.SpendShells(player, price, "shop_fragment")
	if not spent.ok then
		return Result.error(spent.err)
	end
	local granted = InventoryService.GrantFragment(player, coralId, qty, "shop_fragment")
	if not granted.ok then
		InventoryService.GrantShells(player, price, "shop_fragment_refund")
		warn("ShopService: fragment grant failed after spend, refunded")
		return Result.error("Internal")
	end
	ShopService.FragmentBought:Fire(player, coralId, qty, price)
	return Result.result(granted.value)
end

function ShopService.BuySocketUnlock(player: Player, socketId: string): Result<nil>
	local data = PlayerStateService.GetState(player)
	if data == nil or not PlayerStateService.IsLoaded(player) then
		return Result.error("NotLoaded")
	end
	if SocketDefinitions[socketId] == nil then
		return Result.error("UnknownSocket")
	end
	if data.unlocks.sockets[socketId] == true then
		return Result.error("AlreadyUnlocked")
	end
	if not prerequisitesMet(data, socketId) then
		return Result.error("PrerequisiteMissing")
	end
	local cost = EconomyMath.GetSocketUnlockCost(socketId)
	if data.currencies.shells < cost then
		return Result.error("NotEnoughShells")
	end

	if cost > 0 then
		local spent = InventoryService.SpendShells(player, cost, "socket_unlock")
		if not spent.ok then
			return Result.error(spent.err)
		end
	end
	local unlocked = PlacementService.UnlockSocket(player, socketId)
	if not unlocked.ok then
		if cost > 0 then
			InventoryService.GrantShells(player, cost, "socket_unlock_refund")
		end
		warn("ShopService: UnlockSocket failed after spend, refunded")
		return Result.error("Internal")
	end
	ShopService.SocketBought:Fire(player, socketId, cost)
	return Result.result(nil)
end

function ShopService:Init() end

return ShopService
