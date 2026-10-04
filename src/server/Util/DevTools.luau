--!strict
-- Test commands. They bypass normal validation, so no remote is ever connected to these. Two ways in:
-- the Studio command bar (_G.Dev / _DevBridge, set up only in Studio by init.server) and AdminCommands'
-- "/dev" chat command, which checks the speaker against its admin UserId allowlist first.
-- SetSimulateFailure and Call stay Studio-only.
local RunService = game:GetService("RunService")

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
	assert(RunService:IsStudio(), "DevTools.SetSimulateFailure is Studio-only")
	DataService.SetSimulateFailure(enabled)
end

-- Returns the player's live data as JSON (for tools that can't read Output)
function DevTools.GetStateJSON(player: Player?): string
	return HttpService:JSONEncode(getData(resolve(player)))
end

-- Calls any server service method: _G.Dev.Call("GrowthService", "Plant", player, "sandy_patch", "sun_coral")
function DevTools.Call(serviceName: string, methodName: string, ...: any): ...any
	assert(RunService:IsStudio(), "DevTools.Call is Studio-only")
	local module = Services:FindFirstChild(serviceName) or script.Parent:FindFirstChild(serviceName)
	assert(module and module:IsA("ModuleScript"), "DevTools.Call: unknown module " .. serviceName)
	local service = require(module) :: any
	return service[methodName](...)
end

return DevTools
