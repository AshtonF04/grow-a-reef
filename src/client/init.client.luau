local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local HUDService = require(script.Controllers.HUDController)

-- Connect remote events to client
remotes.state_changed.OnClientEvent:Connect(HUDService.updateHUD)