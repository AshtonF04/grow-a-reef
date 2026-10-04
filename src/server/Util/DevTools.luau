--!strict
-- Studio-only test commands. They bypass normal validation, so they must never be reachable live
-- or from a client: no remote is ever connected to these. Exposed as _G.Dev in Studio.
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return {}
end

local HttpService = game:GetService("HttpService")
local Services = script.Parent.Parent.Services
local PlayerStateService = require(Services.PlayerStateService)
local DataService = require(Services.DataService)
local InventoryService = require(Services.InventoryService)
local PlacementService = require(Services.PlacementService)
local TransactionLog = require(script.Parent.TransactionLog)

local DevTools = {}

local function getData(player: Player)
	local data = PlayerStateService.GetState(player)
	assert(data, "DevTools: player has no loaded data")
	return data
end

-- Defaults to the first player so command-bar calls can omit it: _G.Dev.GrantShells(nil, 50)
local function resolve(player: Player?): Player
	local p = player or game:GetService("Players"):GetPlayers()[1]
	assert(p, "DevTools: no player in game")
	return p
end

function DevTools.GrantShells(player: Player?, amount: number)
	return InventoryService.GrantShells(resolve(player), amount, "dev")
end

-- Grants or spends the difference so the change is logged like any other
function DevTools.SetShells(player: Player?, amount: number)
	local p = resolve(player)
	local diff = amount - InventoryService.GetShells(p)
	if diff > 0 then
		return InventoryService.GrantShells(p, diff, "dev")
	elseif diff < 0 then
		return InventoryService.SpendShells(p, -diff, "dev")
	end
	return nil
end

-- Negative qty consumes
function DevTools.GrantFragment(player: Player?, coralId: string, qty: number)
	local p = resolve(player)
	if qty < 0 then
		return InventoryService.ConsumeFragment(p, coralId, -qty, "dev")
	end
	return InventoryService.GrantFragment(p, coralId, qty, "dev")
end

function DevTools.UnlockAllSockets(player: Player?)
	local p = resolve(player)
	for socketId, unlocked in getData(p).unlocks.sockets do
		if not unlocked then
			PlacementService.UnlockSocket(p, socketId)
		end
	end
end

-- Skips the wait: makes that placement ready now
function DevTools.FinishGrowth(player: Player?, socketId: string)
	local p = resolve(player)
	local placement = getData(p).placements[socketId]
	assert(placement, "DevTools.FinishGrowth: socket is empty")
	local growSeconds = placement.readyAt - placement.plantedAt
	placement.readyAt = os.time()
	placement.plantedAt = placement.readyAt - growSeconds
	PlayerStateService.MarkDirty(p, "placements")
end

-- Clears and refills the EXISTING table in place (ProfileStore holds a reference to it)
function DevTools.ResetData(player: Player?)
	local p = resolve(player)
	local data = getData(p) :: any
	table.clear(data)
	for key, value in DataService.GetDefaultData() :: any do
		data[key] = value
	end
	PlayerStateService.ApplyFirstJoin(data)
	PlayerStateService.ReplicateSnapshot(p)
	-- Also mark every slice dirty so server listeners (plot visuals etc.) refresh
	for _, slice in { "currencies", "unlocks", "inventory", "placements", "discoveries", "tutorial" } do
		PlayerStateService.MarkDirty(p, slice)
	end
end

function DevTools.PrintState(player: Player?)
	print(HttpService:JSONEncode(getData(resolve(player))))
end

function DevTools.PrintTransactions(n: number?)
	TransactionLog.PrintRecent(n or 10)
end

function DevTools.SetSimulateFailure(enabled: boolean)
	DataService.SetSimulateFailure(enabled)
end

-- Returns the player's live data as JSON (for tools that can't read Output)
function DevTools.GetStateJSON(player: Player?): string
	return HttpService:JSONEncode(getData(resolve(player)))
end

-- Calls any server service method: _G.Dev.Call("GrowthService", "Plant", player, "sandy_patch", "sun_coral")
function DevTools.Call(serviceName: string, methodName: string, ...: any): ...any
	local module = Services:FindFirstChild(serviceName) or script.Parent:FindFirstChild(serviceName)
	assert(module and module:IsA("ModuleScript"), "DevTools.Call: unknown module " .. serviceName)
	local service = require(module) :: any
	return service[methodName](...)
end

return DevTools
