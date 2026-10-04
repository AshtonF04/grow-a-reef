--!strict
local StateController = require(script.Controllers.StateController)
local HUDController = require(script.Controllers.HUDController)
local PlacementController = require(script.Controllers.PlacementController)
local ReefVisualController = require(script.Controllers.ReefVisualController)
local ClientNet = require(script.Net.ClientNet)

-- 1. Listen for state before asking for it
StateController.Init()

-- 2. HUD is spawned so its GUI setup never delays the handshake
task.spawn(HUDController.Init)

-- 3. Handshake (retries while the server is still loading our data)
ClientNet.ClientReady()

-- 4. World interaction and visuals (both wait for our plot)
task.spawn(PlacementController.Init)
task.spawn(ReefVisualController.Init)
