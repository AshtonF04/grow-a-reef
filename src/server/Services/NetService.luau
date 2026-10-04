--!strict
-- The trust boundary. Every remote handler gets the same wrapper: argument shape check, rate limit,
-- loaded check and error capture, so each new remote is safe by default. Never throws to the client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local PlayerStateService = require(script.Parent.PlayerStateService)
local GrowthService = require(script.Parent.GrowthService)
local ShopService = require(script.Parent.ShopService)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Validate = require(script.Parent.Parent.Util.Validate)

type BindOptions = { requireLoaded: boolean? }

local NetService = {}

function NetService.Bind(
	name: string,
	checkArgs: (...any) -> boolean,
	handler: (Player, ...any) -> Types.Result<any>,
	options: BindOptions?
)
	local requireLoaded = not (options and options.requireLoaded == false)
	Remotes.GetFunction(name).OnServerInvoke = function(player: Player, ...: any)
		if not checkArgs(...) then
			return Result.error("InvalidArgs")
		end
		if not RateLimiter.Check(player, name) then
			return Result.error("RateLimited")
		end
		if requireLoaded and not PlayerStateService.IsLoaded(player) then
			return Result.error("NotLoaded")
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(("NetService: %s errored for UserId %d: %s"):format(name, player.UserId, tostring(result)))
			return Result.error("Internal")
		end
		return result
	end
end

function NetService:Init()
	NetService.Bind("plant_coral", function(socketId, coralId)
		return Validate.IsKnownId(socketId, SocketDefinitions) and Validate.IsKnownId(coralId, CoralDefinitions)
	end, function(player, socketId, coralId)
		return GrowthService.Plant(player, socketId, coralId)
	end)

	NetService.Bind("claim_coral", function(socketId)
		return Validate.IsKnownId(socketId, SocketDefinitions)
	end, function(player, socketId)
		return GrowthService.Claim(player, socketId)
	end)

	NetService.Bind("get_catalog", function()
		return true
	end, function(player)
		return ShopService.GetCatalog(player)
	end)

	NetService.Bind("buy_fragment", function(coralId, qty)
		return Validate.IsKnownId(coralId, CoralDefinitions) and Validate.IsInteger(qty, 1, EconomyConfig.MAX_BUY_QTY)
	end, function(player, coralId, qty)
		return ShopService.BuyFragment(player, coralId, qty)
	end)

	NetService.Bind("unlock_socket", function(socketId)
		return Validate.IsKnownId(socketId, SocketDefinitions)
	end, function(player, socketId)
		return ShopService.BuySocketUnlock(player, socketId)
	end)

	-- How the client asks for its data; returns its own NotLoaded so the client retries
	NetService.Bind("client_ready", function()
		return true
	end, function(player)
		if not PlayerStateService.IsLoaded(player) then
			return Result.error("NotLoaded")
		end
		PlayerStateService.ReplicateSnapshot(player)
		return Result.result(true)
	end, { requireLoaded = false })

	Players.PlayerRemoving:Connect(RateLimiter.ClearPlayer)
end

return NetService
