--!strict
-- Lightweight server/client event used for "signals upward" between services.
-- Lower layers fire, higher layers (PlotService, Quest, Analytics) connect,
-- so a lower layer never needs to require the layer above it.
--
-- Usage:
--   PlacementService.CoralPlaced = Signal.new() :: Signal.Signal<Player, string, Placement>
--   PlacementService.CoralPlaced:Connect(function(player, socketId, placement) ... end)
--   PlacementService.CoralPlaced:Fire(player, socketId, placement)

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type ConnectionImpl = {
	Connected: boolean,
	_signal: SignalImpl,
	_handler: (...any) -> (),
	Disconnect: (self: ConnectionImpl) -> (),
}

type SignalImpl = {
	_connections: { ConnectionImpl },
}

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: ConnectionImpl)
	if not self.Connected then
		return
	end
	self.Connected = false

	local connections = self._signal._connections
	local index = table.find(connections, self)
	if index then
		table.remove(connections, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal<...any>
	local self = setmetatable({
		_connections = {},
	}, Signal)
	return (self :: any) :: Signal<...any>
end

function Signal.Connect(self: SignalImpl, handler: (...any) -> ()): Connection
	local connection = setmetatable({
		Connected = true,
		_signal = self,
		_handler = handler,
	}, Connection)
	table.insert(self._connections, (connection :: any) :: ConnectionImpl)
	return (connection :: any) :: Connection
end

function Signal.Once(self: SignalImpl, handler: (...any) -> ()): Connection
	local connection: Connection
	connection = Signal.Connect(self, function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

-- Each handler runs in its own thread so a listener that errors or yields
-- can't break other listeners or stall the service that fired (keeps
-- Plant/Claim yield-free between validate and mutate).
function Signal.Fire(self: SignalImpl, ...: any)
	-- Snapshot so handlers can connect/disconnect safely while we iterate
	for _, connection in table.clone(self._connections) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal.Wait(self: SignalImpl): ...any
	local thread = coroutine.running()
	Signal.Once(self, function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: SignalImpl)
	for _, connection in self._connections do
		connection.Connected = false
	end
	table.clear(self._connections)
end

function Signal.Destroy(self: SignalImpl)
	Signal.DisconnectAll(self)
	setmetatable(self :: any, nil)
end

return Signal
