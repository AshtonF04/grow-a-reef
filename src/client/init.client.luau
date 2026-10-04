--!strict
local StateController = require(script.Controllers.StateController)
local HUDController = require(script.Controllers.HUDController)
local PlacementController = require(script.Controllers.PlacementController)
local ReefVisualController = require(script.Controllers.ReefVisualController)
local PlantTrayController = require(script.Controllers.PlantTrayController)
local ShopController = require(script.Controllers.ShopController)
local AmbientController = require(script.Controllers.AmbientController)
local PromptController = require(script.Controllers.PromptController)
local SocketPopupController = require(script.Controllers.SocketPopupController)
local WorldLabelController = require(script.Controllers.WorldLabelController)
local ShopBoothController = require(script.Controllers.ShopBoothController)
local Theme = require(script.UI.Theme)
local ClientNet = require(script.Net.ClientNet)

-- 1. Listen for state before asking for it
StateController.Init()

-- 2. HUD is spawned so its GUI setup never delays the handshake
task.spawn(function()
	HUDController.Init()
	HUDController.AddButton("Shop", "🛒", Theme.Colors.Green, Theme.Colors.GreenDark, 1)
end)
HUDController.ButtonPressed:Connect(function(name: string)
	if name == "Shop" then
		ShopBoothController.Teleport() -- the shop itself opens from the stall's prompt
	end
end)
PlantTrayController.Init()
ShopController.Init()
PromptController.Init()
SocketPopupController.Init()
WorldLabelController.Init()
ShopBoothController.Init()

-- 3. Handshake (retries while the server is still loading our data)
ClientNet.ClientReady()

-- 4. World interaction and visuals (both wait for our plot)
task.spawn(PlacementController.Init)
task.spawn(ReefVisualController.Init)
task.spawn(AmbientController.Init)
