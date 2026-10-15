--!strict
-- Wall-clock schedule of Data/ScheduledEvents (S129, DESIGN-17 §7-§8). Pure: every function takes the time it works
-- on (servers and clients pass Util/Clock.now, so /time moves the schedule too). An occurrence id is the UTC date of
-- its start ("20261013"; the data allow at most one slot a day), the same on every server.

local ScheduledEvents = require("../Data/ScheduledEvents")
local Time = require("./Time")

type EventDef = ScheduledEvents.EventDef
type Slot = ScheduledEvents.Slot

export type Occurrence = { key: string, id: string, startsAt: number, endsAt: number }

local DAY = 86400

local Schedule = {}

-- ISO weekday of `t` in UTC: 1 = Monday ... 7 = Sunday (day 0, 1 January 1970, was a Thursday).
function Schedule.weekday(t: number): number
	return ((Time.dayNumber(t) + 3) % 7) + 1
end

-- (year, month, day) of a UTC day number (integer arithmetic, Logic/Time.civil; no os.date).
function Schedule.ymd(day: number): (number, number, number)
	return Time.civil(day * DAY)
end

-- "YYYYMMDD" of the UTC day containing `t`.
function Schedule.dateKey(t: number): string
	local year, month, day = Schedule.ymd(Time.dayNumber(t))
	return string.format("%04d%02d%02d", year, month, day)
end

-- The start of `slot` in UTC week `week` (Logic/Time.weekNumber).
function Schedule.startOf(slot: Slot, week: number): number
	return Time.weekStart(week) + (slot.weekday - 1) * DAY + slot.hour * 3600 + slot.minute * 60
end

-- The id of the occurrence of `def` starting at `startsAt`: its UTC date.
function Schedule.idOf(_def: EventDef, startsAt: number): string
	return Schedule.dateKey(startsAt)
end

local function occurrence(def: EventDef, startsAt: number): Occurrence
	return { key = def.key, id = Schedule.idOf(def, startsAt), startsAt = startsAt, endsAt = startsAt + def.duration }
end

-- Every start of `def` in the weeks `fromWeek`..`toWeek`, unsorted.
local function starts(def: EventDef, fromWeek: number, toWeek: number): { number }
	local out: { number } = {}
	for week = fromWeek, toWeek do
		for _, slot in def.slots do
			table.insert(out, Schedule.startOf(slot, week))
		end
	end
	return out
end

-- The occurrence running at `now` (startsAt <= now < endsAt); a Sunday evening one may run past Monday 00:00, so
-- the previous week is searched too. nil when none or the event is disabled.
function Schedule.current(def: EventDef, now: number): Occurrence?
	if not def.enabled then
		return nil
	end
	local week = Time.weekNumber(now)
	local best: number? = nil
	for _, s in starts(def, week - 1, week) do
		if s <= now and now < s + def.duration and (best == nil or s > best) then
			best = s
		end
	end
	return if best then occurrence(def, best) else nil
end

-- The earliest occurrence starting after `now` (this week or the next). nil when disabled.
function Schedule.next(def: EventDef, now: number): Occurrence?
	if not def.enabled then
		return nil
	end
	local week = Time.weekNumber(now)
	local best: number? = nil
	for _, s in starts(def, week, week + 1) do
		if s > now and (best == nil or s < best) then
			best = s
		end
	end
	return if best then occurrence(def, best) else nil
end

-- The announcements of `occ` due in (from, to]: the warnings of `def.warn` (seconds before the start, descending),
-- then 0 for the start. A server loop calls it with the previous and the current step time, so every announcement
-- falls exactly once (also after a frozen server or /time), and a server starting at `now` (from = now) never
-- announces missed warnings.
function Schedule.crossed(def: EventDef, occ: Occurrence?, from: number, to: number): { number }
	local out: { number } = {}
	if occ == nil or to <= from then
		return out
	end
	for _, before in def.warn do
		local at = occ.startsAt - before
		if from < at and at <= to then
			table.insert(out, before)
		end
	end
	if from < occ.startsAt and occ.startsAt <= to then
		table.insert(out, 0)
	end
	return out
end

-- The first occurrence of an event with blocksWorldEvents whose quiet window [startsAt - quietBefore, endsAt) meets
-- [from, to); nil when none. S101 world events (WorldEventService) and S130 ask it before they start.
function Schedule.blocking(list: { EventDef }, from: number, to: number): Occurrence?
	local found: Occurrence? = nil
	for _, def in list do
		if def.enabled and def.blocksWorldEvents then
			for _, s in starts(def, Time.weekNumber(from) - 1, Time.weekNumber(to) + 1) do
				local quietFrom = s - def.quietBefore
				local ends = s + def.duration
				if quietFrom < to and ends > from and (found == nil or s < found.startsAt) then
					found = occurrence(def, s)
				end
			end
		end
	end
	return found
end

-- Seconds to the next start (HUD, window); nil when the event is disabled.
function Schedule.untilNext(def: EventDef, now: number): number?
	local nextOcc = Schedule.next(def, now)
	return if nextOcc then nextOcc.startsAt - now else nil
end

return Schedule
