--!strict
-- Limiteur de fréquence par clé (token bucket, docs/CLEAN_CODE.md §4). L'horloge est injectée.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, updatedAt: number }
type LimiterData = {
	_capacity: number,
	_refillPerSecond: number,
	_buckets: { [any]: Bucket },
}
export type RateLimiter = typeof(setmetatable({} :: LimiterData, RateLimiter))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	assert(capacity >= 1 and refillPerSecond > 0, "paramètres de limiteur invalides")
	return setmetatable({ _capacity = capacity, _refillPerSecond = refillPerSecond, _buckets = {} }, RateLimiter)
end

-- Consomme un jeton pour `key` si possible. Renvoie false quand la clé dépasse sa fréquence.
function RateLimiter.allow(self: RateLimiter, key: any, now: number): boolean
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._capacity, updatedAt = now }
		self._buckets[key] = bucket
	end
	local elapsed = math.max(0, now - bucket.updatedAt)
	bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._refillPerSecond)
	bucket.updatedAt = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

return RateLimiter
