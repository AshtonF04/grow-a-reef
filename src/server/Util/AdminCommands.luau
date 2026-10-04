--!strict
-- "/dev" chat command for live servers (and Studio), limited to the UserIds in ADMINS. Runs the same
-- DevTools functions as the Studio command bar. The server checks the speaker's UserId, which a client
-- can't fake; anyone else typing "/dev" gets no reply and nothing happens. Replies go only to the admin,
-- through the admin_message remote, and show as system messages in their chat (AdminChatController).
--   /dev help                      list commands
--   /dev shells 500                set Shells          /dev addshells 100     grant Shells
--   /dev fragment sun_coral 3      grant fragments (negative qty removes)
--   /dev unlockall                 unlock every socket
--   /dev finish [socketId|all]     finish growth now (default: all)
--   /dev reset                     reset save data to a fresh first join
--   /dev state                     Shells, fragments and unlocked sockets
--   /dev txlog [n]                 print recent transactions to the server log (F9 > Server)
-- Add "@name" anywhere to target another player in the server (start of their name), e.g. /dev shells 50 @bob
-- Live, these change real saved data (the "PlayerData" store). Every use is printed to the server log.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local PlayerStateService = require(script.Parent.Parent.Services.PlayerStateService)
local InventoryService = require(script.Parent.Parent.Services.InventoryService)
local DevTools = require(script.Parent.DevTools)

local AdminCommands = {}

local ADMINS: { [number]: boolean } = {
	[28437485] = true, -- Fungo_Dev
}
local MAX_SHELLS = 1_000_000
local MAX_FRAGMENTS = 100

type Handler = (target: Player, args: { string }) -> string

local function findPlayer(partial: string): Player?
	local lower = partial:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower():sub(1, #lower) == lower or p.DisplayName:lower():sub(1, #lower) == lower then
			return p
		end
	end
	return nil
end

local function toInt(text: string?, min: number, max: number): number?
	local n = tonumber(text)
	if n == nil or n ~= math.floor(n) or n < min or n > max then
		return nil
	end
	return n
end

local function resultText(result: any, okText: string): string
	if type(result) == "table" and result.ok == false then
		return "Failed: " .. tostring(result.err)
	end
	return okText
end

local commands: { [string]: Handler } = {}

commands.help = function()
	return "/dev shells <n> | addshells <n> | fragment <coralId> [qty] | unlockall | finish [socketId|all] | reset | state | txlog [n]   (add @name to target another player)"
end

commands.shells = function(target, args)
	local n = toInt(args[1], 0, MAX_SHELLS)
	if n == nil then
		return ("Usage: /dev shells <0-%d>"):format(MAX_SHELLS)
	end
	return resultText(DevTools.SetShells(target, n), ("%s now has %d Shells"):format(target.Name, n))
end

commands.addshells = function(target, args)
	local n = toInt(args[1], 1, MAX_SHELLS)
	if n == nil then
		return "Usage: /dev addshells <amount>"
	end
	return resultText(DevTools.GrantShells(target, n), ("Gave %s %d Shells"):format(target.Name, n))
end

commands.fragment = function(target, args)
	local coralId = args[1]
	local qty = toInt(args[2] or "1", -MAX_FRAGMENTS, MAX_FRAGMENTS)
	if coralId == nil or CoralDefinitions[coralId] == nil or qty == nil or qty == 0 then
		local ids = {}
		for id in CoralDefinitions do
			table.insert(ids, id)
		end
		table.sort(ids)
		return "Usage: /dev fragment <coralId> [qty]. Corals: " .. table.concat(ids, ", ")
	end
	return resultText(DevTools.GrantFragment(target, coralId, qty), ("%s: %+d %s"):format(target.Name, qty, coralId))
end

commands.unlockall = function(target)
	DevTools.UnlockAllSockets(target)
	return "Unlocked every socket for " .. target.Name
end

commands.finish = function(target, args)
	local data = PlayerStateService.GetState(target)
	if data == nil then
		return "No data loaded"
	end
	local which = args[1] or "all"
	local count = 0
	for socketId in data.placements do
		if which == "all" or which == socketId then
			DevTools.FinishGrowth(target, socketId)
			count += 1
		end
	end
	return ("Finished %d coral(s) for %s"):format(count, target.Name)
end

commands.reset = function(target)
	DevTools.ResetData(target)
	return "Reset " .. target.Name .. "'s data to a fresh first join"
end

commands.state = function(target)
	local data = PlayerStateService.GetState(target)
	if data == nil then
		return "No data loaded"
	end
	local fragments = {}
	for id, n in data.inventory.fragments do
		if n > 0 then
			table.insert(fragments, id .. " x" .. n)
		end
	end
	table.sort(fragments)
	local unlocked, total = 0, 0
	for socketId in SocketDefinitions do
		total += 1
		if data.unlocks.sockets[socketId] then
			unlocked += 1
		end
	end
	return ("%s: %d Shells | fragments: %s | sockets %d/%d"):format(
		target.Name,
		InventoryService.GetShells(target),
		if #fragments > 0 then table.concat(fragments, ", ") else "none",
		unlocked,
		total
	)
end

commands.txlog = function(_target, args)
	DevTools.PrintTransactions(toInt(args[1], 1, 100) or 10)
	return "Printed recent transactions to the server log (F9 > Server)"
end

local NEEDS_NO_DATA = { help = true, txlog = true }

local function run(admin: Player, text: string): string
	local words = {}
	local targetName: string? = nil
	for word in text:gmatch("%S+") do
		if word:sub(1, 1) == "@" and #word > 1 then
			targetName = word:sub(2)
		else
			table.insert(words, word)
		end
	end
	table.remove(words, 1) -- the "/dev" alias itself
	local name = (table.remove(words, 1) or "help"):lower()
	local handler = commands[name]
	if handler == nil then
		return "Unknown command '" .. name .. "'. " .. commands.help(admin, {})
	end
	local target = admin
	if targetName then
		local found = findPlayer(targetName)
		if found == nil then
			return "No player matching @" .. targetName
		end
		target = found
	end
	if not NEEDS_NO_DATA[name] and not PlayerStateService.IsLoaded(target) then
		return target.Name .. "'s data isn't loaded yet"
	end
	local ok, reply = pcall(handler, target, words)
	return if ok then reply else "Error: " .. tostring(reply)
end

function AdminCommands.IsAdmin(player: Player): boolean
	return ADMINS[player.UserId] == true
end

function AdminCommands.Init()
	local reply = Remotes.GetEvent("admin_message")
	local command = Instance.new("TextChatCommand")
	command.Name = "DevCommand"
	command.PrimaryAlias = "/dev"
	command.AutocompleteVisible = false
	command.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	command.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player == nil or not AdminCommands.IsAdmin(player) then
			return
		end
		local message = run(player, text)
		print(("AdminCommands: %s ran '%s' -> %s"):format(player.Name, text, message))
		reply:FireClient(player, message)
	end)
end

return AdminCommands
