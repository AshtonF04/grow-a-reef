--!strict

-- Loads and saves each reef with DataStores.
-- A session lock stops two servers from writing the same reef.
-- A failed load is never saved over: that player keeps playing, but the session stays unsaved.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local STORE_NAME = "ReefProfiles"
local SCHEMA_VERSION = 1
-- A lock older than this is treated as abandoned. Autosave refreshes it well inside this window.
local LOCK_TIMEOUT = 150
local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 4
local SAVE_ATTEMPTS = 3

export type Record = { [string]: any }

local SaveService = {}

SaveService.SchemaVersion = SCHEMA_VERSION
SaveService.AutosaveSeconds = AUTOSAVE_SECONDS

-- Studio sessions share one id so a crashed Play session never locks you out of your own save.
local sessionId = if RunService:IsStudio()
	then "studio"
	elseif game.JobId ~= "" then game.JobId
	else HttpService:GenerateGUID(false)

local store: DataStore? = nil
local storeError: string? = nil

-- Errors that retrying won't fix: an unpublished place, or Studio without API access.
local function isPermanent(message: string): boolean
	return string.find(message, "403", 1, true) ~= nil
		or string.find(message, "publish", 1, true) ~= nil
		or string.find(message, "not allowed", 1, true) ~= nil
end

local function getStore(): (DataStore?, string?)
	if store or storeError then
		return store, storeError
	end
	if game.PlaceId == 0 then
		storeError = "this place is not published"
		return nil, storeError
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		storeError = tostring(result)
	end
	return store, storeError
end

local function keyFor(userId: number): string
	return "reef_" .. tostring(userId)
end

local function lockedByOther(record: any, now: number): boolean
	if typeof(record) ~= "table" then
		return false
	end
	local session = record.session
	if typeof(session) ~= "table" then
		return false
	end
	if session.id == sessionId then
		return false
	end
	return typeof(session.at) == "number" and now - session.at < LOCK_TIMEOUT
end

-- Returns (true, record) on success. record is nil for a brand-new player.
-- Returns (false, nil, reason) when the save could not be read. Do not save for that player.
function SaveService.Load(userId: number): (boolean, Record?, string?)
	local dataStore, reason = getStore()
	if not dataStore then
		return false, nil, reason
	end

	local lastError = "unknown error"
	for attempt = 1, LOAD_ATTEMPTS do
		local forceLock = attempt == LOAD_ATTEMPTS
		local blocked = false
		local loaded: Record? = nil

		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(userId), function(old: any)
				local now = os.time()
				blocked = false
				if not forceLock and lockedByOther(old, now) then
					blocked = true
					return nil
				end
				local record: Record = if typeof(old) == "table" then old else { version = SCHEMA_VERSION }
				record.session = { id = sessionId, at = now }
				loaded = if typeof(old) == "table" then record else nil
				return record
			end)
		end)

		if ok and not blocked then
			return true, loaded, nil
		end
		if not ok then
			lastError = tostring(err)
			if isPermanent(lastError) then
				store = nil
				storeError = lastError
				return false, nil, lastError
			end
		else
			lastError = "reef is open on another server"
		end
		task.wait(2 * attempt)
	end
	return false, nil, lastError
end

-- Writes the record. With release = true, also drops this server's lock.
-- Refuses to write if another server has taken the lock since we loaded.
function SaveService.Save(userId: number, record: Record, release: boolean): (boolean, string?)
	local dataStore, reason = getStore()
	if not dataStore then
		return false, reason
	end

	local lastError = "unknown error"
	for attempt = 1, SAVE_ATTEMPTS do
		local stolen = false
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(userId), function(old: any)
				stolen = false
				if typeof(old) == "table" and typeof(old.session) == "table" and old.session.id ~= sessionId then
					stolen = true
					return nil
				end
				local copy = table.clone(record)
				copy.version = SCHEMA_VERSION
				copy.session = if release then nil else { id = sessionId, at = os.time() }
				return copy
			end)
		end)
		if ok then
			if stolen then
				return false, "another server owns this reef now"
			end
			return true, nil
		end
		lastError = tostring(err)
		task.wait(attempt)
	end
	return false, lastError
end

-- Drops this server's lock without touching the data. Used when a player leaves mid-load.
function SaveService.Release(userId: number)
	local dataStore = getStore()
	if not dataStore then
		return
	end
	pcall(function()
		dataStore:UpdateAsync(keyFor(userId), function(old: any)
			if typeof(old) ~= "table" or typeof(old.session) ~= "table" or old.session.id ~= sessionId then
				return nil
			end
			old.session = nil
			return old
		end)
	end)
end

return SaveService
