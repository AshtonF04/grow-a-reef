--!strict
-- Owns the plot pool: validates plots at boot, assigns one per player, writes socket facts as attributes
-- (server writes facts, clients derive visuals), and spawns players at their own plot.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlacementService = require(script.Parent.PlacementService)

-- Placeholder socket looks; World can tweak these without touching logic
local SOCKET_LOOKS = {
	unlocked = { Color = Color3.fromRGB(250, 234, 196), Transparency = 0 },
	locked = { Color = Color3.fromRGB(90, 90, 100), Transparency = 0.5 },
}

local EMPTY_SIGN_TEXT = "Empty Reef"

local PlotService = {}

local _freePlots: { Model } = {}
local _plotByPlayer: { [Player]: Model } = {}
local _socketCache: { [Model]: { [string]: BasePart } } = {}
local _respawnConnections: { [Player]: RBXScriptConnection } = {}

local function plotNumber(plot: Model): number
	return tonumber(string.match(plot.Name, "%d+")) or math.huge
end

local function sortPool()
	table.sort(_freePlots, function(a, b)
		return plotNumber(a) < plotNumber(b)
	end)
end

local function setSignText(plot: Model, text: string)
	local sign = plot:FindFirstChild("OwnerSign")
	local board = sign and sign:FindFirstChild("Board")
	if board == nil then
		return
	end
	for _, gui in board:GetChildren() do
		local label = gui:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.Text = text
		end
	end
end

-- Collects every ReefPlot, validates it against SocketDefinitions, and builds the free pool + socket cache
function PlotService:Init()
	local plots = CollectionService:GetTagged("ReefPlot")
	if #plots == 0 then
		warn("PlotService: No models tagged with 'ReefPlot' found")
		return
	end

	local problems: { string } = {}
	for _, plot in plots do
		if not plot:IsA("Model") then
			table.insert(problems, plot:GetFullName() .. ": tagged ReefPlot but is not a Model")
			continue
		end

		local sockets: { [string]: BasePart } = {}
		for socketId in SocketDefinitions do
			local part = plot:FindFirstChild(socketId, true)
			if part == nil or not part:IsA("BasePart") then
				table.insert(problems, plot.Name .. ": missing socket '" .. socketId .. "'")
			elseif not CollectionService:HasTag(part, "ReefSocket") then
				table.insert(problems, plot.Name .. ": socket '" .. socketId .. "' is missing the ReefSocket tag")
			else
				sockets[socketId] = part
			end
		end

		local spawn = plot:FindFirstChild("PlotSpawn", true)
		if spawn == nil or not spawn:IsA("SpawnLocation") then
			table.insert(problems, plot.Name .. ": missing PlotSpawn")
		end

		_socketCache[plot] = sockets
		-- With StreamingEnabled, a plot only streams to the players added as persistent (its owner),
		-- so the owner always has every socket and never loses them to streaming-out
		plot.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
		table.insert(_freePlots, plot)
	end

	if #problems > 0 then
		error("PlotService: invalid plots:\n  " .. table.concat(problems, "\n  "), 0)
	end

	sortPool()
	for _, plot in _freePlots do
		setSignText(plot, EMPTY_SIGN_TEXT)
		for _, socket in _socketCache[plot] do
			socket:SetAttribute("Unlocked", nil)
			local badge = socket:FindFirstChild("LockBadge")
			if badge and badge:IsA("BillboardGui") then
				badge.Enabled = false
			end
		end
	end
	print(("PlotService: %d plots ready"):format(#_freePlots))

	-- Any change to unlocks/placements refreshes just that socket (ignored for players with no plot)
	local function refreshOne(player: Player, socketId: string)
		if _plotByPlayer[player] then
			PlotService.RefreshSocketVisual(player, socketId)
		end
	end
	PlacementService.SocketUnlocked:Connect(refreshOne)
	PlacementService.CoralPlaced:Connect(refreshOne)
	PlacementService.PlacementCleared:Connect(refreshOne)

	-- Catch-all for direct data edits (DevTools, resets)
	PlayerStateService.StateChanged:Connect(function(player: Player, sliceKey: string)
		if (sliceKey == "unlocks" or sliceKey == "placements") and _plotByPlayer[player] then
			PlotService.RefreshAllSockets(player)
		end
	end)
end

-- Claims the first free plot for the player. Returns the existing plot if they already have one.
function PlotService.AssignPlot(player: Player): Types.Result<Model>
	local existing = _plotByPlayer[player]
	if existing then
		return Result.result(existing)
	end

	local plot = table.remove(_freePlots, 1)
	if plot == nil then
		warn("PlotService: no free plots")
		return Result.error("Internal")
	end

	_plotByPlayer[player] = plot
	plot:AddPersistentPlayer(player)
	plot:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotId", plot.Name)
	PlayerStateService.SetPlotId(player, plot.Name)
	setSignText(plot, player.DisplayName .. "'s Reef")
	return Result.result(plot)
end

-- Returns the player's plot to the pool. Safe to call for a player who never got one.
function PlotService.ReleasePlot(player: Player)
	local connection = _respawnConnections[player]
	if connection then
		connection:Disconnect()
		_respawnConnections[player] = nil
	end

	local plot = _plotByPlayer[player]
	if plot == nil then
		return
	end

	plot:SetAttribute("OwnerUserId", nil)
	pcall(function()
		plot:RemovePersistentPlayer(player)
	end)
	-- Coral models are client-side only (M3), so clearing socket attributes is all the cleanup needed;
	-- the next owner must never see the previous player's state.
	for _, socket in _socketCache[plot] do
		socket:SetAttribute("Unlocked", nil)
		socket:SetAttribute("CoralId", nil)
		socket:SetAttribute("PlantedAt", nil)
		socket:SetAttribute("ReadyAt", nil)
		socket.Color = SOCKET_LOOKS.locked.Color
		socket.Transparency = SOCKET_LOOKS.locked.Transparency
		local badge = socket:FindFirstChild("LockBadge")
		if badge and badge:IsA("BillboardGui") then
			badge.Enabled = false
		end
	end
	setSignText(plot, EMPTY_SIGN_TEXT)

	if player.Parent then
		player:SetAttribute("PlotId", nil)
	end
	PlayerStateService.SetPlotId(player, nil)
	_plotByPlayer[player] = nil
	table.insert(_freePlots, plot)
	sortPool()
end

function PlotService.GetPlot(player: Player): Model?
	return _plotByPlayer[player]
end

function PlotService.GetSocketInstance(player: Player, socketId: string): BasePart?
	local plot = _plotByPlayer[player]
	if plot == nil then
		return nil
	end
	return _socketCache[plot][socketId]
end

-- Writes the socket's facts (Unlocked + placement) as attributes and applies the placeholder look.
-- Attributes replicate, so every client renders models and countdowns from them. The trait is never
-- written here (revealed separately in M6-03).
function PlotService.RefreshSocketVisual(player: Player, socketId: string)
	local socket = PlotService.GetSocketInstance(player, socketId)
	if socket == nil then
		return
	end

	local unlocked = PlacementService.IsSocketUnlocked(player, socketId)
	socket:SetAttribute("Unlocked", unlocked)

	local placement = PlacementService.GetPlacement(player, socketId)
	socket:SetAttribute("CoralId", if placement then placement.coralId else nil)
	socket:SetAttribute("PlantedAt", if placement then placement.plantedAt else nil)
	socket:SetAttribute("ReadyAt", if placement then placement.readyAt else nil)

	local look = if unlocked then SOCKET_LOOKS.unlocked else SOCKET_LOOKS.locked
	socket.Color = look.Color
	socket.Transparency = look.Transparency

	local badge = socket:FindFirstChild("LockBadge")
	if badge and badge:IsA("BillboardGui") then
		badge.Enabled = not unlocked
	end
end

function PlotService.RefreshAllSockets(player: Player)
	for socketId in SocketDefinitions do
		PlotService.RefreshSocketVisual(player, socketId)
	end
end

-- RefreshSocketVisual writes placements too, so applying all placements is the same pass
PlotService.ApplyAllPlacements = PlotService.RefreshAllSockets

-- Spawns the player at their plot. CharacterAutoLoads is off (set in the bootstrap), so this is the only
-- place characters load: on join here, and on death after RespawnTime via the Died hook below.
function PlotService.SpawnPlayerAtPlot(player: Player)
	local plot = _plotByPlayer[player]
	if plot == nil then
		warn("PlotService: SpawnPlayerAtPlot called for a player with no plot")
		return
	end
	local spawn = plot:FindFirstChild("PlotSpawn", true)
	if spawn and spawn:IsA("SpawnLocation") then
		player.RespawnLocation = spawn
	end

	if _respawnConnections[player] == nil then
		_respawnConnections[player] = player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid == nil or not humanoid:IsA("Humanoid") then
				return
			end
			humanoid.Died:Once(function()
				task.delay(Players.RespawnTime, function()
					if player.Parent == Players and _plotByPlayer[player] then
						player:LoadCharacter()
					end
				end)
			end)
		end)
	end

	player:LoadCharacter()
end

return PlotService
