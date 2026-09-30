--!strict

-- Server entry.
-- Builds the reef, loads and saves each player's reef, and checks every action.
-- The client can ask. It cannot change its own shells.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Remotes)
local PlayerStateService = require(script.PlayerStateService)
local PlotService = require(script.PlotService)
local SaveService = require(script.SaveService)
local WorldService = require(script.WorldService)
local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local ReefRules = require(ReplicatedStorage.Shared.ReefRules)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerState = Types.PlayerState

-- Minimum seconds between two requests of the same kind from one player.
local ACTION_GAP = 0.2

local loading: { [Player]: boolean } = {}
-- true when this player's reef loaded cleanly and may be saved.
local canSave: { [Player]: boolean } = {}
local lastAction: { [Player]: { [string]: number } } = {}
local pendingSaves = 0
local warnedNoSave = false

local function sync(player: Player)
	local state = PlayerStateService.GetState(player)
	if not state then
		return
	end
	PlotService.Apply(player, state)
	Remotes.state_changed:FireClient(player, state)
end

local function saveNow(player: Player, state: PlayerState, release: boolean)
	pendingSaves += 1
	local ok, reason = SaveService.Save(player.UserId, PlayerStateService.ToRecord(state), release)
	pendingSaves -= 1
	if not ok then
		warn(string.format("[reef] save failed for %s: %s", player.Name, tostring(reason)))
		if reason and string.find(reason, "another server", 1, true) then
			canSave[player] = false
		end
	end
end

local function welcomeBack(state: PlayerState): string
	local now = workspace:GetServerTimeNow()
	local ready: { string } = {}
	local soonest: number? = nil
	local soonestName = ""
	for _, socket in ReefRules.OrderedSockets() do
		local placement = state.placements[socket.id]
		if placement then
			local coral = CoralDefinitions[placement.coralId]
			local name = if coral then coral.displayName else "Coral"
			if ReefRules.IsMature(placement.plantedAt, placement.coralId, now) then
				table.insert(ready, string.format("%s on %s", name, socket.displayName))
			else
				local remain = ReefRules.RemainingSeconds(placement.plantedAt, placement.coralId, now)
				if soonest == nil or remain < soonest then
					soonest = remain
					soonestName = string.format("%s on %s", name, socket.displayName)
				end
			end
		end
	end
	if #ready == 1 then
		return string.format("Welcome back. %s grew while you were away.", ready[1])
	elseif #ready > 1 then
		return string.format("Welcome back. %d corals grew while you were away.", #ready)
	elseif soonest ~= nil then
		return string.format("Welcome back. %s is ready in %s.", soonestName, ReefRules.FormatTime(soonest))
	end
	return "Welcome back to your reef."
end

local function loadPlayer(player: Player)
	if loading[player] or PlayerStateService.GetState(player) then
		return
	end
	loading[player] = true
	local ok, record, reason = SaveService.Load(player.UserId)
	loading[player] = nil

	if player.Parent ~= Players then
		if ok then
			SaveService.Release(player.UserId)
		end
		return
	end

	local state = PlayerStateService.InitPlayerState(player, if ok then record else nil)
	canSave[player] = ok
	PlotService.Ensure(player)
	sync(player)

	if not ok then
		if not warnedNoSave then
			warnedNoSave = true
			warn(
				"[reef] saving is off:",
				reason,
				"(in Studio: File > Game Settings > Security > Enable Studio Access to API Services, on a published place)"
			)
		end
		Remotes.action_notice:FireClient(player, false, "Your reef couldn't load its save. Progress this visit won't be saved.")
	elseif record ~= nil then
		Remotes.action_notice:FireClient(player, true, welcomeBack(state))
	end
	print(string.format("[reef] %s entered the reef (%s)", player.Name, if ok then "saving on" else "saving off"))
end

local function allow(player: Player, action: string): boolean
	local now = os.clock()
	local times = lastAction[player]
	if not times then
		times = {}
		lastAction[player] = times
	end
	local last = times[action]
	if last and now - last < ACTION_GAP then
		return false
	end
	times[action] = now
	return true
end

local function reply(player: Player, ok: boolean, message: string)
	Remotes.action_notice:FireClient(player, ok, message)
	if ok then
		sync(player)
	end
end

local function asString(value: any): string?
	if typeof(value) == "string" and #value <= 64 then
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
	if not allow(player, "request_state") then
		return
	end
	if PlayerStateService.GetState(player) then
		sync(player)
	end
end)

Remotes.unlock_socket.OnServerEvent:Connect(function(player: Player, socketId: any)
	if not allow(player, "unlock") then
		return
	end
	local id = asString(socketId)
	if not id or not SocketDefinitions[id] then
		reply(player, false, "Unknown spot.")
		return
	end
	local ran, ok, message = pcall(PlayerStateService.UnlockSocket, player, id)
	finish(player, ran, ok, message)
end)

Remotes.plant_coral.OnServerEvent:Connect(function(player: Player, socketId: any, coralId: any)
	if not allow(player, "plant") then
		return
	end
	local socket = asString(socketId)
	local coral = asString(coralId)
	if not socket or not coral or not SocketDefinitions[socket] or not CoralDefinitions[coral] then
		reply(player, false, "Unknown plant.")
		return
	end
	local ran, ok, message = pcall(PlayerStateService.PlantCoral, player, socket, coral)
	finish(player, ran, ok, message)
end)

Remotes.harvest_coral.OnServerEvent:Connect(function(player: Player, socketId: any)
	if not allow(player, "harvest") then
		return
	end
	local id = asString(socketId)
	if not id or not SocketDefinitions[id] then
		reply(player, false, "Unknown spot.")
		return
	end
	local ran, ok, message = pcall(PlayerStateService.HarvestCoral, player, id)
	finish(player, ran, ok, message)
end)

Remotes.buy_fragment.OnServerEvent:Connect(function(player: Player, coralId: any)
	if not allow(player, "buy") then
		return
	end
	local id = asString(coralId)
	if not id or not CoralDefinitions[id] then
		reply(player, false, "That coral isn't in the Nursery.")
		return
	end
	local ran, ok, message = pcall(PlayerStateService.BuyFragment, player, id)
	finish(player, ran, ok, message)
end)

WorldService.Build()

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(player: Player)
	local state = PlayerStateService.GetState(player)
	local save = canSave[player]
	PlotService.Remove(player)
	PlayerStateService.RemovePlayer(player)
	canSave[player] = nil
	lastAction[player] = nil
	if state and save then
		saveNow(player, state, true)
	end
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

task.spawn(function()
	while true do
		task.wait(SaveService.AutosaveSeconds)
		for _, player in Players:GetPlayers() do
			local state = PlayerStateService.GetState(player)
			if state and canSave[player] then
				task.spawn(saveNow, player, state, false)
			end
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		local state = PlayerStateService.GetState(player)
		if state and canSave[player] then
			canSave[player] = false
			task.spawn(saveNow, player, state, true)
		end
	end
	local deadline = os.clock() + 25
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

print(
	string.format(
		"[reef] ready. Sun Coral matures in %s here.",
		ReefRules.FormatTime(ReefRules.GrowDuration("sun_coral"))
	)
)
