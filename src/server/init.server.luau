--!strict

-- Require Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Boot-load shared configs (runs definition validation)
require(ReplicatedStorage.Shared.Config.SocketDefinitions)
require(ReplicatedStorage.Shared.Config.CoralDefinitions)

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

-- No character loads until the player's plot is assigned: PlotService.SpawnPlayerAtPlot is the only
-- place characters load (on join and after death). Any feature that assumes a character exists on join
-- must wait for CharacterAdded instead.
Players.CharacterAutoLoads = false

-- 1. Create remotes
Remotes.CreateAll()

-- 2. Require game services (requiring only loads them, nothing starts yet)
local DataService = require(script.Services.DataService)
local PlayerStateService = require(script.Services.PlayerStateService)
local InventoryService = require(script.Services.InventoryService)
local PlacementService = require(script.Services.PlacementService)
local GrowthService = require(script.Services.GrowthService)
local PlotService = require(script.Services.PlotService)
local NetService = require(script.Services.NetService)

-- 3. Init game services in dependency order (NetService last: it exposes the others to clients)
DataService:Init()
PlayerStateService:Init()
InventoryService:Init()
PlacementService:Init()
GrowthService:Init()
PlotService:Init()
NetService:Init()

-- Studio-only command-bar helpers (see README)
if RunService:IsStudio() then
	local DevTools = require(script.Util.DevTools)
	-- selene: allow(global_usage)
	local globals: any = _G
	globals.Dev = DevTools

	-- Lets Studio plugins/tools (which don't share _G) call DevTools. ServerStorage never replicates to clients.
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "_DevBridge"
	bridge.OnInvoke = function(fnName: string, ...)
		return (DevTools :: any)[fnName](...)
	end
	bridge.Parent = game:GetService("ServerStorage")
end

-- Handler Methods
local function stillHere(player: Player): boolean
	return player.Parent == Players
end

local function onPlayerAdded(player: Player)
	-- 1. Load data (yields); nil means the load failed and the player was already kicked
	local data = PlayerStateService.InitPlayerState(player)
	if data == nil or not stillHere(player) then
		return
	end

	-- 2. Claim a plot
	local plotResult = PlotService.AssignPlot(player)
	if not plotResult.ok then
		player:Kick("This server is full, please try another")
		PlayerStateService.RemovePlayer(player)
		return
	end
	if not stillHere(player) then
		return
	end

	-- 3. Write socket facts (unlocks + placements), 4. spawn them there
	PlotService.RefreshAllSockets(player)
	PlotService.SpawnPlayerAtPlot(player)
end

-- Release the plot before the data; both are safe for players who never finished joining
local function onPlayerRemoving(player: Player)
	PlotService.ReleasePlot(player)
	PlayerStateService.RemovePlayer(player)
end

-- 5. Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- 6. Catch players who joined before this script ran (common in Studio)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
