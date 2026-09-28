-- Require Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require Game Services
local PlayerStateService = require(script.PlayerStateService)

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