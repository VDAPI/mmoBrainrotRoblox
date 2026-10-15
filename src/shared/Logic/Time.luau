--!strict
-- Wall-clock helpers (DESIGN §10, §11): UTC day numbers, countdowns and the alchemist's order queue.
-- Pure functions; callers pass `now` (Util/Clock on the server and client).

local Time = {}

export type Order = { recipeId: string, readyAt: number }

-- UTC day index used for daily lockouts and quests.
function Time.dayNumber(t: number): number
	return math.floor(t / 86400)
end

-- S100: the time (seconds) the next UTC day starts (the login reward's "next reward in" countdown).
function Time.nextDayAt(t: number): number
	return (Time.dayNumber(t) + 1) * 86400
end

-- S98: UTC week index for the weekly contracts. Weeks start on Monday 00:00 UTC (day 0, 1 January 1970, was a
-- Thursday, hence the + 3).
function Time.weekNumber(t: number): number
	return math.floor((Time.dayNumber(t) + 3) / 7)
end

-- S98: the time (seconds) week `week` starts: Monday 00:00 UTC.
function Time.weekStart(week: number): number
	return (week * 7 - 3) * 86400
end

-- S98: days, hours and minutes of a countdown (Time.format would print "150:12:00" for six days).
function Time.split(seconds: number): (number, number, number)
	local s = math.max(0, math.floor(seconds))
	return s // 86400, (s % 86400) // 3600, (s % 3600) // 60
end

-- S121: the UTC calendar date (year, month 1..12, day 1..31) of `t`. Computed from the day number ("civil from
-- days", H. Hinnant) instead of os.date, so Lune and Roblox give the same answer.
function Time.civil(t: number): (number, number, number)
	local z = Time.dayNumber(t) + 719468
	local era = z // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local day = doy - (153 * mp + 2) // 5 + 1
	local month = if mp < 10 then mp + 3 else mp - 9
	local year = yoe + era * 400 + (if month <= 2 then 1 else 0)
	return year, month, day
end

-- S121: "YYYYMM" of the UTC month containing `t` (VIP cosmetic of the month; arena seasons may reuse it, S126).
function Time.monthKey(t: number): string
	local year, month = Time.civil(t)
	return string.format("%04d%02d", year, month)
end

-- S121: (year, month) of a "YYYYMM" key, nil for a malformed one (the UI prints "11.2026").
function Time.monthLabel(key: string): (number?, number?)
	if type(key) ~= "string" or not string.match(key, "^%d%d%d%d%d%d$") then
		return nil, nil
	end
	local year = tonumber(string.sub(key, 1, 4)) :: number
	local month = tonumber(string.sub(key, 5, 6)) :: number
	if month < 1 or month > 12 then
		return nil, nil
	end
	return year, month
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
