-- Require Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

-- Boot-load shared configs (runs definition validation)
require(ReplicatedStorage.Shared.Config.SocketDefinitions)
require(ReplicatedStorage.Shared.Config.CoralDefinitions)

-- Require Game Services
local PlayerStateService = require(script.Services.PlayerStateService)

local stateChanged = Instance.new("RemoteEvent")
stateChanged.Name = "state_changed"
stateChanged.Parent = remotes

-- Init Player On Join
game.Players.PlayerAdded:Connect(function(player: Player)
    local playerState = PlayerStateService.InitPlayerState(player)
    return playerState
end)

-- Remove player from list on game leave
game.Players.PlayerRemoving:Connect(function(player: Player)
    PlayerStateService.RemovePlayer(player)
end)
