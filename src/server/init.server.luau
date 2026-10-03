--!strict

-- Require Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Boot-load shared configs (runs definition validation)
require(ReplicatedStorage.Shared.Config.SocketDefinitions)
require(ReplicatedStorage.Shared.Config.CoralDefinitions)

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Result = require(ReplicatedStorage.Shared.Util.Result)

-- 1. Create remotes
Remotes.CreateAll()

-- 2. Require game services (requiring only loads them, nothing starts yet)
local DataService = require(script.Services.DataService)
local PlayerStateService = require(script.Services.PlayerStateService)
local PlotService = require(script.Services.PlotService)

-- 3. Init game services in dependency order
DataService:Init()
PlayerStateService:Init()
PlotService:Init()

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
local function onPlayerAdded(player: Player)
	-- Yields while the save loads; nil means the load failed and the player was already kicked
	local data = PlayerStateService.InitPlayerState(player)
	if data == nil then
		return
	end
end

local function onPlayerRemoving(player: Player)
	PlayerStateService.RemovePlayer(player)
end

-- client_ready is how the client asks for its data. Never throws to the client.
-- TODO(M3-07): this handler moves into NetService.
local function onClientReady(player: Player)
	if not PlayerStateService.IsLoaded(player) then
		return Result.error("NotLoaded")
	end

	PlayerStateService.ReplicateSnapshot(player)
	return Result.result(true)
end

-- 4. Bind client_ready remote function to handler
Remotes.GetFunction("client_ready").OnServerInvoke = onClientReady

-- 5. Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- 6. Catch players who joined before this script ran (common in Studio)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
