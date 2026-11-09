--!strict
-- RateLimit - a token bucket per key (usually a player). Pure: the caller passes `now`.

local RateLimit = {}
RateLimit.__index = RateLimit

export type Limiter = typeof(setmetatable(
	{} :: { perSecond: number, burst: number, buckets: { [any]: { tokens: number, t: number } } },
	RateLimit
))

function RateLimit.new(perSecond: number, burst: number): Limiter
	return setmetatable({ perSecond = perSecond, burst = burst, buckets = {} }, RateLimit)
end

--- Spend one token for `key` at time `now`. False means: too fast, ignore the request.
function RateLimit.take(self: Limiter, key: any, now: number): boolean
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.burst, t = now }
		self.buckets[key] = bucket
	end
	bucket.tokens =
		math.min(self.burst, bucket.tokens + math.max(0, now - bucket.t) * self.perSecond)
	bucket.t = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimit.forget(self: Limiter, key: any)
	self.buckets[key] = nil
end

return RateLimit
