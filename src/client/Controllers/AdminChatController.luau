--!strict
-- Shows replies to "/dev" chat commands as system messages in the local chat. The server only ever fires
-- admin_message to admins (AdminCommands), so for everyone else this never runs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local AdminChatController = {}

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function AdminChatController.Init()
	Remotes.GetEvent("admin_message").OnClientEvent:Connect(function(message: string)
		local channels = TextChatService:FindFirstChild("TextChannels")
		local system = channels and channels:FindFirstChild("RBXSystem")
		if system and system:IsA("TextChannel") then
			system:DisplaySystemMessage('<font color="#7CFFB2">[dev]</font> ' .. escape(tostring(message)))
		else
			print("[dev] " .. tostring(message))
		end
	end)
end

return AdminChatController
