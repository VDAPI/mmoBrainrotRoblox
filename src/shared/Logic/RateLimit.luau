--!strict
-- Token bucket rate limiter keyed by arbitrary strings (e.g. "userId:RemoteName").
-- Pure: the caller passes the current time, so tests can drive the clock.

local RateLimit = {}
RateLimit.__index = RateLimit

type Bucket = { tokens: number, last: number }

export type RateLimit = typeof(setmetatable(
	{} :: { rate: number, burst: number, buckets: { [string]: Bucket } },
	RateLimit
))

-- rate: tokens refilled per second; burst: bucket capacity (defaults to max(rate, 1) * 2).
function RateLimit.new(rate: number, burst: number?): RateLimit
	assert(rate > 0, "RateLimit: rate must be positive")
	return setmetatable({
		rate = rate,
		burst = burst or math.max(rate, 1) * 2,
		buckets = {},
	}, RateLimit)
end

-- Consumes one token. Returns false when the bucket is empty.
function RateLimit.take(self: RateLimit, key: string, now: number): boolean
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.burst, last = now }
		self.buckets[key] = bucket
	end
	local elapsed = math.max(0, now - bucket.last)
	bucket.tokens = math.min(self.burst, bucket.tokens + elapsed * self.rate)
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

-- Drops every bucket whose key starts with prefix (e.g. when a player leaves).
function RateLimit.clearPrefix(self: RateLimit, prefix: string)
	for key in self.buckets do
		if string.sub(key, 1, #prefix) == prefix then
			self.buckets[key] = nil
		end
	end
end

return RateLimit
