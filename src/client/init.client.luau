local player = game.Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerGUI = player:WaitForChild("PlayerGui")
local HUD = PlayerGUI:WaitForChild("HUD")

function updateHUD(newState)
    HUD.ShellsLabel.Text = "Shells: ".. newState.shells
end

remotes.state_changed.OnClientEvent:Connect(updateHUD)