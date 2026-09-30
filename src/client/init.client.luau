--!strict

-- Client entry.
-- Draws the guide and the coral, and asks the server when you plant, harvest, or unlock.
-- Shells and fragments change only after the server agrees.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HUDService = require(script.HUDService)
local ReefVisuals = require(script.ReefVisuals)
local WorldAmbience = require(script.WorldAmbience)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerState = Types.PlayerState

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("Remotes", 30)
if not folder then
	warn("[reef] Remotes never appeared")
	return
end

local function event(name: string): RemoteEvent
	local child = folder:WaitForChild(name, 30)
	if not child or not child:IsA("RemoteEvent") then
		error("Missing remote " .. name, 0)
	end
	return child
end

local stateChanged = event("state_changed")
local actionNotice = event("action_notice")
local requestState = event("request_state")
local unlockSocket = event("unlock_socket")
local plantCoral = event("plant_coral")
local harvestCoral = event("harvest_coral")

local actions = {
	unlock = function(socketId: string)
		unlockSocket:FireServer(socketId)
	end,
	plant = function(socketId: string, coralId: string)
		plantCoral:FireServer(socketId, coralId)
	end,
	harvest = function(socketId: string)
		harvestCoral:FireServer(socketId)
	end,
}

HUDService.Start(actions)

local latest: PlayerState? = nil
local welcomed = false

local function onState(state: any)
	if typeof(state) ~= "table" then
		return
	end
	local typed = state :: PlayerState
	latest = typed
	HUDService.Render(typed)
	if ReefVisuals.IsMounted() then
		ReefVisuals.Apply(typed)
	end
	if not welcomed and typed.shells == 0 and next(typed.placements) == nil then
		welcomed = true
		HUDService.Toast(true, "Sandy Patch is open. Plant your Sun Coral.")
	end
end

actionNotice.OnClientEvent:Connect(function(ok: any, message: any)
	if typeof(ok) ~= "boolean" or typeof(message) ~= "string" then
		return
	end
	HUDService.Toast(ok, message)
end)

stateChanged.OnClientEvent:Connect(onState)
requestState:FireServer()

task.spawn(function()
	local plots = workspace:WaitForChild("ReefPlots", 20)
	if not plots then
		HUDService.Toast(false, "The reef plot didn't appear.")
		return
	end
	local plotModel = plots:WaitForChild(tostring(player.UserId), 20)
	if plotModel and plotModel:IsA("Model") then
		ReefVisuals.Mount(plotModel, actions)
		if latest then
			ReefVisuals.Apply(latest)
		end
	else
		HUDService.Toast(false, "The reef plot didn't appear.")
	end
end)

RunService.Heartbeat:Connect(function()
	WorldAmbience.Tick()
	if latest then
		local now = workspace:GetServerTimeNow()
		HUDService.Tick(latest, now)
		ReefVisuals.Tick(latest, now)
	end
end)
