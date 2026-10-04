--!strict
-- Wall-clock helpers (DESIGN §10, §11): UTC day numbers, countdowns and the alchemist's order queue.
-- Pure functions; callers pass `now` (Util/Clock on the server and client).

local Time = {}

export type Order = { recipeId: string, readyAt: number }

-- UTC day index used for daily lockouts and quests.
function Time.dayNumber(t: number): number
	return math.floor(t / 86400)
end

-- Seconds left until `expiresAt` (never negative).
function Time.remaining(expiresAt: number, now: number): number
	return math.max(0, expiresAt - now)
end

-- "1:05:09" / "4:07" / "0:12".
function Time.format(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

-- Whether another order fits into a queue of `slots` parallel orders.
function Time.canQueue(queue: { Order }, slots: number): boolean
	return #queue < slots
end

-- Indices of finished orders, ascending.
function Time.readyItems(queue: { Order }, now: number): { number }
	local ready = {}
	for index, order in queue do
		if order.readyAt <= now then
			table.insert(ready, index)
		end
	end
	return ready
end

-- Progress 0..1 of an order that started `duration` seconds before readyAt.
function Time.progress(order: Order, duration: number, now: number): number
	if duration <= 0 then
		return 1
	end
	return math.clamp(1 - (order.readyAt - now) / duration, 0, 1)
end

return Time
