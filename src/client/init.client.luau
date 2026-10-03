--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local StateController = require(script.Controllers.StateController)
local HUDController = require(script.Controllers.HUDController)

local MAX_ATTEMPTS = 5

-- Asks the server for our state, retrying while it's still loading our data
local function clientReady(): boolean
	local clientReadyRemote = Remotes.GetFunction("client_ready")
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(function()
			return clientReadyRemote:InvokeServer()
		end)
		if ok and type(result) == "table" and result.ok == true then
			return true
		end
		task.wait(attempt * 0.5)
	end
	warn("Client: could not load player state after " .. MAX_ATTEMPTS .. " attempts")
	return false
end

-- 1. Listen for state before asking for it
StateController.Init()

-- 2. HUD is spawned so its GUI setup never delays the handshake
task.spawn(HUDController.Init)

-- 3. Handshake
clientReady()
