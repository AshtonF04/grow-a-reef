-- Require Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

-- Require Game Services
local PlayerStateService = require(script.PlayerStateService)

local stateChanged = Instance.new("RemoteEvent")
stateChanged.Name = "state_changed"
stateChanged.Parent = remotes

-- Init Player On Join
game.Players.PlayerAdded:Connect(function(player: Player)
    local playerState = PlayerStateService.InitPlayerState(player)
end)

-- Remove player from list on game leave
game.Players.PlayerRemoving:Connect(function(player: Player)
    PlayerStateService.RemovePlayer(player)
end)

-- 1. Build the remotes. They exist only as instances created here,
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"