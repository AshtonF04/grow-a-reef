-- src/server/ServerMain.server.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.PlayerService)

-- 1. Build the remotes. They exist only as instances created here,
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"