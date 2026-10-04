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
	local p = resolve(player)
	getData(p).currencies.shells += amount
	PlayerStateService.MarkDirty(p, "currencies")
end

function DevTools.SetShells(player: Player?, amount: number)
	local p = resolve(player)
	getData(p).currencies.shells = amount
	PlayerStateService.MarkDirty(p, "currencies")
end

function DevTools.GrantFragment(player: Player?, coralId: string, qty: number)
	local p = resolve(player)
	local fragments = getData(p).inventory.fragments
	fragments[coralId] = (fragments[coralId] or 0) + qty
	PlayerStateService.MarkDirty(p, "inventory")
end

function DevTools.UnlockAllSockets(player: Player?)
	local p = resolve(player)
	local sockets = getData(p).unlocks.sockets
	for socketId in sockets do
		sockets[socketId] = true
	end
	PlayerStateService.MarkDirty(p, "unlocks")
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
