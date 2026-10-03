--!strict

-- Require Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Boot-load shared configs (runs definition validation)
require(ReplicatedStorage.Shared.Config.SocketDefinitions)
require(ReplicatedStorage.Shared.Config.CoralDefinitions)

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Result = require(ReplicatedStorage.Shared.Util.Result)

-- 1. Create remotes
Remotes.CreateAll()

-- 2. Require game services (requiring only loads them, nothing starts yet)
local PlayerStateService = require(script.Services.PlayerStateService)
local PlotService = require(script.Services.PlotService)

-- 3. Init game services in dependency order
PlayerStateService:Init()
PlotService:Init()

-- Handler Methods
local function onPlayerAdded(player: Player)
	PlayerStateService.InitPlayerState(player)
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
