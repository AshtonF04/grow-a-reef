--!strict

-- Server entry.
-- Builds the reef, keeps each player's wallet, and checks every action.
-- The client can ask. It cannot change its own shells.

local Players = game:GetService("Players")

local Remotes = require(script.Remotes)
local PlayerStateService = require(script.PlayerStateService)
local PlotService = require(script.PlotService)
local WorldService = require(script.WorldService)
local ReefRules = require(game:GetService("ReplicatedStorage").Shared.ReefRules)

local function sync(player: Player)
	local state = PlayerStateService.GetState(player)
	if not state then
		return
	end
	PlotService.Apply(player, state)
	Remotes.state_changed:FireClient(player, state)
end

local function handlePlayer(player: Player)
	local created = PlayerStateService.GetState(player) == nil
	if created then
		PlayerStateService.InitPlayerState(player)
	end
	PlotService.Ensure(player)
	sync(player)
	if created then
		print(string.format("[reef] %s entered the reef", player.Name))
	end
end

local function reply(player: Player, ok: boolean, message: string)
	Remotes.action_notice:FireClient(player, ok, message)
	if ok then
		sync(player)
	end
end

local function asString(value: any): string?
	if typeof(value) == "string" then
		return value
	end
	return nil
end

local function finish(player: Player, ran: boolean, ok: any, message: any)
	if not ran or typeof(ok) ~= "boolean" or typeof(message) ~= "string" then
		if not ran then
			warn("[reef]", ok)
		end
		reply(player, false, "Something went wrong.")
		return
	end
	reply(player, ok, message)
end

Remotes.request_state.OnServerEvent:Connect(function(player: Player)
	handlePlayer(player)
end)

Remotes.unlock_socket.OnServerEvent:Connect(function(player: Player, socketId: any)
	local id = asString(socketId)
	if not id then
		reply(player, false, "Unknown spot.")
		return
	end
	local ran, ok, message = pcall(PlayerStateService.UnlockSocket, player, id)
	finish(player, ran, ok, message)
end)

Remotes.plant_coral.OnServerEvent:Connect(function(player: Player, socketId: any, coralId: any)
	local socket = asString(socketId)
	local coral = asString(coralId)
	if not socket or not coral then
		reply(player, false, "Unknown plant.")
		return
	end
	local ran, ok, message = pcall(PlayerStateService.PlantCoral, player, socket, coral)
	finish(player, ran, ok, message)
end)

Remotes.harvest_coral.OnServerEvent:Connect(function(player: Player, socketId: any)
	local id = asString(socketId)
	if not id then
		reply(player, false, "Unknown spot.")
		return
	end
	local ran, ok, message = pcall(PlayerStateService.HarvestCoral, player, id)
	finish(player, ran, ok, message)
end)

WorldService.Build()

Players.PlayerAdded:Connect(handlePlayer)
Players.PlayerRemoving:Connect(function(player: Player)
	PlotService.Remove(player)
	PlayerStateService.RemovePlayer(player)
end)

for _, player in Players:GetPlayers() do
	handlePlayer(player)
end

print(string.format("[reef] ready. Sun Coral matures in %s here.", ReefRules.FormatTime(ReefRules.GrowDuration("sun_coral"))))
