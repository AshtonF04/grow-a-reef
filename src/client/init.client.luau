local player = game.Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local HUDService = require(script.HUDService)

-- Connect remote events to client
remotes.state_changed.OnClientEvent:Connect(HUDService.updateHUD)