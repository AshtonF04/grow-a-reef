--!strict
-- In-memory ring buffer of every currency/item change, for investigating duplication bugs and disputes.
-- Memory-only for now; persisting it (DataStore or analytics) is a later decision.

export type Entry = {
	txId: string,
	userId: number,
	time: number,
	kind: string, -- "currency" | "fragment" | "socket"
	id: string, -- what changed ("shells", "sun_coral")
	delta: number, -- signed amount
	reason: string, -- why ("claim", "shop_fragment")
}

local MAX_ENTRIES = 500

local TransactionLog = {}

local entries: { Entry } = {}
local head = 0 -- index of the newest entry
local count = 0
local counter = 0

function TransactionLog.Record(player: Player, kind: string, id: string, delta: number, reason: string)
	counter += 1
	local now = os.time()
	local entry: Entry = {
		txId = string.format("%d-%d-%d", player.UserId, now, counter),
		userId = player.UserId,
		time = now,
		kind = kind,
		id = id,
		delta = delta,
		reason = reason,
	}
	head = head % MAX_ENTRIES + 1
	entries[head] = entry
	count = math.min(count + 1, MAX_ENTRIES)
end

-- Returns copies of the last n entries, newest first
function TransactionLog.GetRecent(n: number): { Entry }
	local out = {}
	local index = head
	for _ = 1, math.min(n, count) do
		table.insert(out, table.clone(entries[index]))
		index -= 1
		if index < 1 then
			index = MAX_ENTRIES
		end
	end
	return out
end

function TransactionLog.GetCount(): number
	return count
end

function TransactionLog.PrintRecent(n: number)
	for _, e in TransactionLog.GetRecent(n) do
		print(
			string.format(
				"[Tx %s] user=%d %s %s %+d (%s)",
				e.txId,
				e.userId,
				e.kind,
				e.id,
				e.delta,
				e.reason
			)
		)
	end
end

return TransactionLog
