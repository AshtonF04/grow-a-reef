--!strict
-- The one place the client calls the server. Every call is pcall-wrapped and always returns a Result.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)

type Result<T> = Types.Result<T>

local MAX_READY_ATTEMPTS = 5

local ClientNet = {}

local function invoke(name: string, ...: any): Result<any>
	local args = table.pack(...)
	local ok, result = pcall(function()
		return Remotes.GetFunction(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok or type(result) ~= "table" or type(result.ok) ~= "boolean" then
		return Result.error("Internal")
	end
	return result
end

function ClientNet.PlantCoral(socketId: string, coralId: string): Result<Types.Placement>
	return invoke("plant_coral", socketId, coralId)
end

function ClientNet.ClaimCoral(socketId: string): Result<Types.ClaimReward>
	return invoke("claim_coral", socketId)
end

-- { fragments = { {coralId, price, affordable} }, sockets = { {socketId, cost, affordable, available} } }
function ClientNet.GetCatalog(): Result<any>
	return invoke("get_catalog")
end

function ClientNet.BuyFragment(coralId: string, qty: number): Result<number>
	return invoke("buy_fragment", coralId, qty)
end

function ClientNet.UnlockSocket(socketId: string): Result<nil>
	return invoke("unlock_socket", socketId)
end

-- Asks the server for our state, retrying while it's still loading our data
function ClientNet.ClientReady(): Result<boolean>
	local last: Result<boolean> = Result.error("Internal")
	for attempt = 1, MAX_READY_ATTEMPTS do
		last = invoke("client_ready")
		if last.ok then
			return last
		end
		task.wait(attempt * 0.5)
	end
	warn("ClientNet: could not load player state after " .. MAX_READY_ATTEMPTS .. " attempts")
	return last
end

return ClientNet
