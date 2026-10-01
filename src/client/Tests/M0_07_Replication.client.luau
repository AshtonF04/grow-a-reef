--!nonstrict
-- M0-07 (KAN-10) test helper: records every state_changed event this client receives
-- and hands the log to server/Tests/M0_07_Replication.server.luau when asked.
-- Does nothing unless the server test created ReplicatedStorage._TestBridge.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local bridge = ReplicatedStorage:WaitForChild("_TestBridge", 15)
if not bridge then
	return -- server tests are disabled
end

ReplicatedStorage:WaitForChild("Remotes")
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local stateChanged = Remotes.GetEvent("state_changed")

local received = {}
stateChanged.OnClientEvent:Connect(function(sliceKey, value)
	table.insert(received, { key = sliceKey, value = value })
end)

bridge.OnClientInvoke = function(command)
	if command == "collect" then
		local out = received
		received = {}
		return out
	end
	return "pong"
end
