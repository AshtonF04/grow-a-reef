--!strict
-- Owns persistence: the ProfileStore, schema version, default data shape and migrations.
-- profile.Data is the live table ProfileStore saves; everything else must use that exact table, never a copy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Migrations = require(script.Parent.Parent.Migrations)

local SCHEMA_VERSION = 1
local SAVE_NOW_COOLDOWN = 10 -- seconds between forced saves per player

-- Studio never touches real player data
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData"

local LOAD_FAIL_MESSAGE = "We couldn't load your data. Please rejoin in a minute. Nothing has been lost."
local SESSION_STOLEN_MESSAGE = "Your data was loaded on another server. Please rejoin."

local DataService = {}

DataService.SCHEMA_VERSION = SCHEMA_VERSION
DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Types.PlayerData>
DataService.ProfileReleased = Signal.new() :: Signal.Signal<Player>

local _store: any = nil
local _profiles: { [Player]: any } = {}
local _released: { [Player]: boolean } = {} -- guards ProfileReleased against double-firing
local _kicked: { [Player]: boolean } = {}
local _lastSaveNow: { [Player]: number } = {}
local _simulateFailure = false

-- Returns a fresh default data table on every call (never a shared one)
function DataService.GetDefaultData(): Types.PlayerData
	local sockets: { [string]: boolean } = {}
	for socketId, socket in SocketDefinitions do
		sockets[socketId] = socket.unlockCostShells == 0
	end

	return {
		version = SCHEMA_VERSION,
		currencies = { shells = 0, pearls = 0 },
		unlocks = { zone = 1, sockets = sockets },
		-- The starter fragment is granted once on first join, not here: Reconcile re-adds
		-- missing template keys on every load, so a template fragment would be re-granted.
		inventory = { fragments = {} },
		placements = {},
		discoveries = { corals = {}, fish = {}, traits = {} },
		tutorial = { version = 1, step = "start", done = false },
		-- 0 means "never joined"; PlayerStateService stamps the real time on first join
		meta = { firstJoin = 0, lastSeen = 0 },
	}
end

-- Pure: upgrades a save to SCHEMA_VERSION, or returns nil plus a reason.
-- Refuses saves newer than this server so an old server can never overwrite newer data.
function DataService.Migrate(data: any, migrations: { Migrations.Migration }?, targetVersion: number?): (Types.PlayerData?, string?)
	local list = migrations or Migrations
	local target = targetVersion or SCHEMA_VERSION

	if type(data.version) ~= "number" then
		data.version = 1
	end
	if data.version > target then
		return nil, "save is newer than this server"
	end

	while data.version < target do
		local step = nil
		for _, migration in list do
			if migration.from == data.version then
				step = migration
				break
			end
		end
		if step == nil then
			return nil, "missing migration from v" .. data.version
		end
		data = step.run(data)
		data.version = step.to
	end

	return data, nil
end

local function kickOnce(player: Player, message: string)
	if _kicked[player] then
		return
	end
	_kicked[player] = true
	player:Kick(message)
end

local function fail(player: Player, reason: string): Types.Result<Types.PlayerData>
	warn(string.format("DataService: load failed for UserId %d (%s)", player.UserId, reason))
	kickOnce(player, LOAD_FAIL_MESSAGE)
	return Result.error("NotLoaded")
end

-- Loads the player's save with a session lock (yields). On any failure the player is kicked
-- and nothing is written, so defaults can never be saved over real progress.
function DataService.LoadProfile(player: Player): Types.Result<Types.PlayerData>
	_released[player] = nil
	_kicked[player] = nil

	if _simulateFailure then
		return fail(player, "simulated failure")
	end

	local key = "Player_" .. player.UserId
	local profile = _store:StartSessionAsync(key, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		if player.Parent ~= Players then
			return Result.error("NotLoaded") -- player left mid-load, nothing to kick
		end
		return fail(player, "session could not be started")
	end

	profile:AddUserId(player.UserId) -- lets data-erasure requests find this save
	profile:Reconcile()

	local migrated, err = DataService.Migrate(profile.Data)
	if migrated == nil then
		profile:EndSession()
		return fail(player, "migration: " .. tostring(err))
	end
	profile.Data = migrated

	if player.Parent ~= Players then
		profile:EndSession()
		return Result.error("NotLoaded")
	end

	profile.OnSessionEnd:Connect(function()
		_profiles[player] = nil
		if not _released[player] then
			-- Session ended without us releasing it: taken over by another server
			_released[player] = true
			DataService.ProfileReleased:Fire(player)
			kickOnce(player, SESSION_STOLEN_MESSAGE)
		end
	end)

	_profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile.Data)
	return Result.result(profile.Data)
end

-- Ends the session (triggers the final save). Safe to call for players with no profile.
function DataService.ReleaseProfile(player: Player)
	_lastSaveNow[player] = nil
	_kicked[player] = nil
	local profile = _profiles[player]
	if profile == nil then
		return
	end
	_released[player] = true
	_profiles[player] = nil
	profile.Data.meta.lastSeen = os.time()
	profile:EndSession()
	DataService.ProfileReleased:Fire(player)
end

-- Forces an immediate save for events that must not be lost; ignored if called within the cooldown
function DataService.SaveNow(player: Player)
	local profile = _profiles[player]
	if profile == nil then
		return
	end
	local now = os.clock()
	local last = _lastSaveNow[player]
	if last and now - last < SAVE_NOW_COOLDOWN then
		return
	end
	_lastSaveNow[player] = now
	profile:Save()
end

function DataService.GetProfile(player: Player): any
	return _profiles[player]
end

function DataService.IsLoaded(player: Player): boolean
	local profile = _profiles[player]
	return profile ~= nil and profile:IsActive()
end

function DataService.GetData(player: Player): Types.PlayerData?
	local profile = _profiles[player]
	return if profile then profile.Data else nil
end

-- Studio-only test hook: makes LoadProfile fail through the normal failure path
function DataService.SetSimulateFailure(enabled: boolean)
	assert(RunService:IsStudio(), "DataService.SetSimulateFailure is Studio-only")
	_simulateFailure = enabled
end

-- ProfileStore already saves and releases every active session on game:BindToClose,
-- so no extra shutdown handling is needed here.
function DataService:Init()
	_store = ProfileStore.New(STORE_NAME, DataService.GetDefaultData())
end

return DataService
