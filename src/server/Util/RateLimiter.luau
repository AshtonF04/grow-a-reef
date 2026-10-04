--!strict
-- Per-player, per-action token buckets for remotes.
type Limit = { capacity: number, refillPerSecond: number }
type Bucket = { tokens: number, last: number }

local LIMITS: { [string]: Limit } = {
	plant_coral = { capacity = 5, refillPerSecond = 2 },
	claim_coral = { capacity = 8, refillPerSecond = 4 },
	client_ready = { capacity = 3, refillPerSecond = 0.5 },
	get_catalog = { capacity = 5, refillPerSecond = 2 },
	buy_fragment = { capacity = 5, refillPerSecond = 2 },
	unlock_socket = { capacity = 3, refillPerSecond = 1 },
}
local DEFAULT_LIMIT: Limit = { capacity = 3, refillPerSecond = 1 }

local RateLimiter = {}

local buckets: { [Player]: { [string]: Bucket } } = {}

-- Refills based on elapsed time and spends one token if available
function RateLimiter.Check(player: Player, action: string): boolean
	local limit = LIMITS[action] or DEFAULT_LIMIT
	local playerBuckets = buckets[player]
	if playerBuckets == nil then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end

	local now = os.clock()
	local bucket = playerBuckets[action]
	if bucket == nil then
		bucket = { tokens = limit.capacity, last = now }
		playerBuckets[action] = bucket
	end

	bucket.tokens = math.min(limit.capacity, bucket.tokens + (now - bucket.last) * limit.refillPerSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.ClearPlayer(player: Player)
	buckets[player] = nil
end

return RateLimiter
