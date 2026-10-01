--!nonstrict
-- M0-07 (KAN-10) acceptance tests: PlayerStateService replication API.
-- Studio-only. Press Play (solo), then read the "[M0-07]" summary in Output.
-- Works with client/Tests/M0_07_Replication.client.luau, which reports what the client received.
-- Set ENABLED = false (or delete both Tests folders) before merging.
local ENABLED = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not ENABLED or not RunService:IsStudio() then
	return
end

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local PlayerStateService = require(script.Parent.Parent.Services.PlayerStateService)

local SLICES = { "currencies", "unlocks", "inventory", "placements", "discoveries", "tutorial" }

-- Remotes aren't created by init.server until M0-08, so create them here if missing.
if not ReplicatedStorage:FindFirstChild("Remotes") then
	Remotes.CreateAll()
end

-- Test-only bridge: lets the server ask the client what state_changed events it received.
local bridge = Instance.new("RemoteFunction")
bridge.Name = "_TestBridge"
bridge.Parent = ReplicatedStorage

---------------------------------------------------------------------------
-- Tiny test harness
---------------------------------------------------------------------------
local results = {}

local function expect(condition: any, message: string)
	if not condition then
		error(message, 0)
	end
end

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	table.insert(results, { name = name, ok = ok, err = err })
end

local function waitFrames(n: number)
	for _ = 1, n do
		RunService.Heartbeat:Wait()
	end
end

local function countKeys(t): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- Runs fn, waits for deferred flushes, returns every slice key StateChanged fired for `player`.
local function recordStateChanged(player: Player, fn: () -> ()): { string }
	local fired = {}
	local conn = PlayerStateService.StateChanged:Connect(function(p, key)
		if p == player then
			table.insert(fired, key)
		end
	end)
	fn()
	waitFrames(3)
	conn:Disconnect()
	return fired
end

-- Runs fn and returns server-side warnings/errors logged while it (and its deferred work) ran.
local function captureLogs(fn: () -> ()): { warnings: { string }, errors: { string } }
	local logs = { warnings = {}, errors = {} }
	local conn = LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageWarning then
			table.insert(logs.warnings, message)
		elseif messageType == Enum.MessageType.MessageError then
			table.insert(logs.errors, message)
		end
	end)
	fn()
	task.wait(0.25)
	conn:Disconnect()
	return logs
end

-- Waits for remote traffic to land, then returns (and clears) the client's received-event log.
local function collectClient(player: Player): { { key: string, value: any } }
	task.wait(0.5)
	return bridge:InvokeClient(player, "collect")
end

local function waitForClient(player: Player, timeout: number): boolean
	local ready = false
	task.spawn(function()
		local ok, res = pcall(bridge.InvokeClient, bridge, player, "ping")
		ready = ok and res == "pong"
	end)
	local start = os.clock()
	while not ready and os.clock() - start < timeout do
		task.wait(0.1)
	end
	return ready
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()

local start = os.clock()
while not PlayerStateService.IsLoaded(player) and os.clock() - start < 10 do
	task.wait()
end

---------------------------------------------------------------------------
-- Server-side tests
---------------------------------------------------------------------------
test("IsLoaded: true for a joined player, false for an unknown userId", function()
	expect(PlayerStateService.IsLoaded(player) == true, "joined player should be loaded")
	expect(PlayerStateService.IsLoaded("0") == false, "unknown userId should not be loaded")
end)

test("GetClientView: returns nil (no throw) when there is no session", function()
	expect(PlayerStateService.GetClientView("0") == nil, "expected nil for unknown userId")
end)

test("GetClientView: contains exactly the six client slices, no version/meta", function()
	local view = PlayerStateService.GetClientView(player)
	expect(view ~= nil, "view was nil")
	for _, key in SLICES do
		expect(view[key] ~= nil, "missing slice '" .. key .. "'")
	end
	expect(view.version == nil, "'version' must not be sent to the client")
	expect(view.meta == nil, "'meta' must not be sent to the client")
	expect(countKeys(view) == 6, "expected 6 keys, got " .. countKeys(view))
end)

test("GetClientView: slices are copies, not the live saved tables", function()
	local data = PlayerStateService.GetState(player)
	local view = PlayerStateService.GetClientView(player)
	for _, key in SLICES do
		expect(not rawequal(view[key], data[key]), "'" .. key .. "' is the live table")
	end
end)

test("GetClientView: nested tables are copies too (strict reading of 'fresh table')", function()
	local data = PlayerStateService.GetState(player)
	local view = PlayerStateService.GetClientView(player)
	expect(not rawequal(view.unlocks.sockets, data.unlocks.sockets), "unlocks.sockets is the live table")
	expect(not rawequal(view.inventory.fragments, data.inventory.fragments), "inventory.fragments is the live table")
	expect(not rawequal(view.discoveries.corals, data.discoveries.corals), "discoveries.corals is the live table")
end)

test("ReplicateSlice: invalid key warns and does not throw", function()
	local threw = false
	local logs = captureLogs(function()
		threw = not pcall(PlayerStateService.ReplicateSlice, player, "bogus_slice")
	end)
	expect(not threw, "ReplicateSlice threw on an invalid key")
	expect(#logs.warnings >= 1, "expected a warning, got none")
end)

test("MarkDirty: same slice 5x in one frame -> StateChanged fires once", function()
	local fired = recordStateChanged(player, function()
		for _ = 1, 5 do
			PlayerStateService.MarkDirty(player, "currencies")
		end
	end)
	expect(#fired == 1, "expected 1 fire, got " .. #fired)
	expect(fired[1] == "currencies", "expected 'currencies', got " .. tostring(fired[1]))
end)

test("MarkDirty: 3 different slices in one frame -> 3 fires, one per slice", function()
	local fired = recordStateChanged(player, function()
		PlayerStateService.MarkDirty(player, "currencies")
		PlayerStateService.MarkDirty(player, "inventory")
		PlayerStateService.MarkDirty(player, "currencies")
		PlayerStateService.MarkDirty(player, "placements")
		PlayerStateService.MarkDirty(player, "inventory")
	end)
	expect(#fired == 3, "expected 3 fires, got " .. #fired)
	local seen = {}
	for _, key in fired do
		expect(not seen[key], "'" .. key .. "' fired twice")
		seen[key] = true
	end
	expect(seen.currencies and seen.inventory and seen.placements, "wrong set of slices fired")
end)

test("MarkDirty: separate frames -> separate flushes (pending resets)", function()
	local fired = recordStateChanged(player, function()
		PlayerStateService.MarkDirty(player, "currencies")
		waitFrames(2)
		PlayerStateService.MarkDirty(player, "currencies")
	end)
	expect(#fired == 2, "expected 2 fires, got " .. #fired)
end)

test("MarkDirty: invalid key does not fire StateChanged", function()
	local fired = recordStateChanged(player, function()
		PlayerStateService.MarkDirty(player, "bogus_slice")
	end)
	expect(#fired == 0, "StateChanged fired " .. #fired .. "x for an invalid slice key")
end)

---------------------------------------------------------------------------
-- Client-received tests (the ticket's "Done when" #1)
---------------------------------------------------------------------------
if not waitForClient(player, 10) then
	test("Client test script responded", function()
		error("client/Tests/M0_07_Replication.client.luau never answered", 0)
	end)
else
	collectClient(player) -- discard anything sent by the server-side tests above

	test("Client: MarkDirty same slice 5x in one frame -> exactly 1 event received", function()
		for _ = 1, 5 do
			PlayerStateService.MarkDirty(player, "currencies")
		end
		local got = collectClient(player)
		expect(#got == 1, "client received " .. #got .. " events")
		expect(got[1].key == "currencies", "wrong key: " .. tostring(got[1].key))
	end)

	test("Client: receives the latest value, not the value at MarkDirty time", function()
		local data = PlayerStateService.GetState(player)
		data.currencies.shells = 10
		PlayerStateService.MarkDirty(player, "currencies")
		data.currencies.shells = 42
		PlayerStateService.MarkDirty(player, "currencies")
		local got = collectClient(player)
		expect(#got == 1, "client received " .. #got .. " events")
		expect(got[1].value.shells == 42, "expected shells = 42, got " .. tostring(got[1].value.shells))
		data.currencies.shells = 0
	end)

	test("Client: mixed slices in one frame -> one event per slice", function()
		PlayerStateService.MarkDirty(player, "currencies")
		PlayerStateService.MarkDirty(player, "currencies")
		PlayerStateService.MarkDirty(player, "inventory")
		PlayerStateService.MarkDirty(player, "inventory")
		PlayerStateService.MarkDirty(player, "unlocks")
		local got = collectClient(player)
		expect(#got == 3, "client received " .. #got .. " events")
	end)

	test("Client: ReplicateSnapshot sends one 'snapshot' with the six slices only", function()
		PlayerStateService.ReplicateSnapshot(player)
		local got = collectClient(player)
		expect(#got == 1, "client received " .. #got .. " events")
		expect(got[1].key == "snapshot", "expected key 'snapshot', got " .. tostring(got[1].key))
		local view = got[1].value
		for _, key in SLICES do
			expect(view[key] ~= nil, "snapshot missing '" .. key .. "'")
		end
		expect(view.version == nil and view.meta == nil, "snapshot leaked version/meta")
	end)

	test("Client: invalid slice key sends nothing", function()
		pcall(PlayerStateService.ReplicateSlice, player, "bogus_slice")
		PlayerStateService.MarkDirty(player, "bogus_slice")
		local got = collectClient(player)
		expect(#got == 0, "client received " .. #got .. " events")
	end)
end

---------------------------------------------------------------------------
-- Leaving players (ticket "Done when" #3). Runs last: it removes the session, then restores it.
---------------------------------------------------------------------------
test("MarkDirty after RemovePlayer: no throw, no StateChanged, no errors", function()
	PlayerStateService.RemovePlayer(player)
	local threw = false
	local fired
	local logs = captureLogs(function()
		fired = recordStateChanged(player, function()
			threw = not pcall(PlayerStateService.MarkDirty, player, "currencies")
		end)
	end)
	expect(not threw, "MarkDirty threw")
	expect(#fired == 0, "StateChanged fired for a removed player")
	expect(#logs.errors == 0, "error logged: " .. tostring(logs.errors[1]))
	PlayerStateService.InitPlayerState(player)
end)

test("Player leaves with a flush pending: flush does nothing, no errors", function()
	local fired
	local logs = captureLogs(function()
		fired = recordStateChanged(player, function()
			PlayerStateService.MarkDirty(player, "currencies")
			PlayerStateService.RemovePlayer(player) -- same frame, before the deferred flush runs
		end)
	end)
	expect(#fired == 0, "StateChanged fired after the player left")
	expect(#logs.errors == 0, "error logged: " .. tostring(logs.errors[1]))
	PlayerStateService.InitPlayerState(player)
end)

test("After re-init, MarkDirty works again", function()
	local fired = recordStateChanged(player, function()
		PlayerStateService.MarkDirty(player, "currencies")
	end)
	expect(#fired == 1, "expected 1 fire, got " .. #fired)
end)

---------------------------------------------------------------------------
-- Summary
---------------------------------------------------------------------------
local passed = 0
for _, r in results do
	if r.ok then
		passed += 1
	end
end

print(("[M0-07] ===== %d / %d passed ====="):format(passed, #results))
for _, r in results do
	if r.ok then
		print("[M0-07] PASS  " .. r.name)
	else
		warn("[M0-07] FAIL  " .. r.name .. "  ->  " .. tostring(r.err))
	end
end
