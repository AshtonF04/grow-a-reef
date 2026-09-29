local player = game.Players.LocalPlayer
local PlayerGUI = player:WaitForChild("PlayerGui")
local HUD = PlayerGUI:WaitForChild("HUD")

local HUDService = {}

-- Method to update main HUD with new state information
function HUDService.updateHUD(newState)
    HUD.ShellsLabel.Text = "Shells: ".. newState.shells
end

return HUDService