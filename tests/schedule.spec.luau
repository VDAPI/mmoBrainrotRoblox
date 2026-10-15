--!strict
-- Wall-clock schedule (S129, DESIGN-17 §7-§8): dates, the Blood Moon occurrences, the week boundary, the
-- announcements, the block of world events and the data of Data/ScheduledEvents (Logic/Schedule).
local Schedule = require("../src/shared/Logic/Schedule")
local ScheduledEvents = require("../src/shared/Data/ScheduledEvents")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local MONDAY = 1791763200 -- 2026-10-12 00:00 UTC (the S98 week test)
local TUESDAY_19 = 1791918000 -- 2026-10-13 19:00 UTC
local THURSDAY_19 = 1792090800 -- 2026-10-15 19:00 UTC
local DAY = 86400

local BLOOD = ScheduledEvents.get("bloodmoon") :: ScheduledEvents.EventDef

local function copyDef(changes: { [string]: any }): ScheduledEvents.EventDef
	local def: any = table.clone(BLOOD)
	for k, v in changes do
		def[k] = v
	end
	return def
end

T.describe("Schedule: days and dates", function()
	T.it("gives ISO weekdays and UTC dates without os.date", function()
		T.expect(Schedule.weekday(0)).toBe(4)
		T.expect(Schedule.weekday(MONDAY)).toBe(1)
		T.expect(Schedule.weekday(TUESDAY_19)).toBe(2)
		T.expect(Schedule.weekday(MONDAY + 6 * DAY + 3600)).toBe(7)
		T.expect({ Schedule.ymd(Time.dayNumber(MONDAY)) }).toEqual({ 2026, 10, 12 })
		T.expect(Schedule.dateKey(1709208000)).toBe("20240229")
		T.expect(Schedule.dateKey(951868800)).toBe("20000301")
		T.expect(Schedule.dateKey(1798761599)).toBe("20261231")
		T.expect(Schedule.dateKey(1798761600)).toBe("20270101")
	end)

	T.it("counts 400 days from 2026-01-01 without gaps", function()
		local lengths = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
		local year, month, day = 2026, 1, 1
		local last = ""
		for i = 0, 399 do
			local key = Schedule.dateKey(1767225600 + i * DAY + 1234)
			T.expect(key).toBe(string.format("%04d%02d%02d", year, month, day))
			T.expect(key > last).toBe(true)
			last = key
			day += 1
			local len = lengths[month] + (if month == 2 and year % 4 == 0 then 1 else 0)
			if day > len then
				day = 1
				month += 1
				if month > 12 then
					month = 1
					year += 1
				end
			end
		end
	end)
end)

T.describe("Schedule: Blood Moon occurrences", function()
	T.it("runs Tuesday and Thursday 19:00 UTC for 30 minutes", function()
		local occ = Schedule.current(BLOOD, TUESDAY_19)
		T.expect(occ ~= nil).toBe(true)
		local o = occ :: Schedule.Occurrence
		T.expect(o.id).toBe("20261013")
		T.expect(o.key).toBe("bloodmoon")
		T.expect(o.startsAt).toBe(TUESDAY_19)
		T.expect(o.endsAt).toBe(TUESDAY_19 + 1800)
		T.expect(Schedule.current(BLOOD, TUESDAY_19 - 1)).toBeNil()
		T.expect((Schedule.next(BLOOD, TUESDAY_19 - 1) :: Schedule.Occurrence).startsAt).toBe(TUESDAY_19)
		T.expect(Schedule.current(BLOOD, TUESDAY_19 + 1799) ~= nil).toBe(true)
		T.expect(Schedule.current(BLOOD, TUESDAY_19 + 1800)).toBeNil()
		T.expect((Schedule.current(BLOOD, THURSDAY_19 + 60) :: Schedule.Occurrence).id).toBe("20261015")
		T.expect(Schedule.idOf(BLOOD, THURSDAY_19)).toBe("20261015")
	end)

	T.it("finds the next one in this week and the next", function()
		T.expect((Schedule.next(BLOOD, MONDAY + 2 * DAY + 12 * 3600) :: Schedule.Occurrence).startsAt).toBe(THURSDAY_19)
		local friday = MONDAY + 4 * DAY + 12 * 3600
		T.expect((Schedule.next(BLOOD, friday) :: Schedule.Occurrence).startsAt).toBe(TUESDAY_19 + 7 * DAY)
		T.expect(Schedule.next(BLOOD, TUESDAY_19) ~= nil).toBe(true)
		T.expect((Schedule.next(BLOOD, TUESDAY_19) :: Schedule.Occurrence).startsAt).toBe(THURSDAY_19)
		T.expect(Schedule.untilNext(BLOOD, TUESDAY_19 - 600)).toBe(600)
	end)

	T.it("a disabled event never runs", function()
		local off = copyDef({ enabled = false })
		T.expect(Schedule.current(off, TUESDAY_19 + 10)).toBeNil()
		T.expect(Schedule.next(off, TUESDAY_19 - 10)).toBeNil()
		T.expect(Schedule.untilNext(off, TUESDAY_19 - 10)).toBeNil()
	end)

	T.it("an occurrence late on Sunday runs past Monday 00:00", function()
		local sunday = copyDef({ slots = { { weekday = 7, hour = 23, minute = 50 } }, duration = 1800 })
		local occ = Schedule.current(sunday, MONDAY + 7 * DAY + 600) -- Monday 2026-10-19 00:10
		T.expect(occ ~= nil).toBe(true)
		T.expect((occ :: Schedule.Occurrence).id).toBe("20261018")
		T.expect((occ :: Schedule.Occurrence).startsAt).toBe(MONDAY + 7 * DAY - 600)
	end)
end)

T.describe("Schedule: announcements", function()
	T.it("each warning and the start fall exactly once", function()
		local occ = Schedule.current(BLOOD, TUESDAY_19) :: Schedule.Occurrence
		local s = TUESDAY_19
		T.expect(Schedule.crossed(BLOOD, occ, s - 700, s - 590)).toEqual({ 600 })
		T.expect(Schedule.crossed(BLOOD, occ, s - 61, s - 59)).toEqual({ 60 })
		T.expect(Schedule.crossed(BLOOD, occ, s - 1, s)).toEqual({ 0 })
		T.expect(Schedule.crossed(BLOOD, occ, s - 700, s + 5)).toEqual({ 600, 60, 0 })
		T.expect(Schedule.crossed(BLOOD, occ, s + 10, s + 11)).toEqual({})
		T.expect(Schedule.crossed(BLOOD, nil, s - 700, s + 5)).toEqual({})
		-- one second steps from 15 min before: every announcement once
		local seen: { [number]: number } = {}
		for t = s - 900, s + 60 do
			for _, a in Schedule.crossed(BLOOD, Schedule.next(BLOOD, t), t, t + 1) do
				seen[a] = (seen[a] or 0) + 1
			end
		end
		T.expect(seen).toEqual({ [600] = 1, [60] = 1, [0] = 1 })
	end)
end)

T.describe("Schedule: world events blocked", function()
	T.it("blocks the quiet minutes before and the event itself", function()
		local list = ScheduledEvents.list
		local s = TUESDAY_19
		local hit = Schedule.blocking(list, s - 20 * 60, s - 6 * 60)
		T.expect(hit ~= nil).toBe(true)
		T.expect((hit :: Schedule.Occurrence).id).toBe("20261013")
		T.expect(Schedule.blocking(list, s - 90 * 60, s - 76 * 60)).toBeNil()
		T.expect(Schedule.blocking(list, s + 20 * 60, s + 34 * 60) ~= nil).toBe(true)
		T.expect(Schedule.blocking(list, s + 30 * 60, s + 44 * 60)).toBeNil()
		T.expect(Schedule.blocking({ copyDef({ blocksWorldEvents = false }) }, s - 60, s + 60)).toBeNil()
	end)
end)

T.describe("Schedule: data", function()
	T.it("every event is well formed, at most one slot a day, with texts", function()
		T.expect(table.isfrozen(ScheduledEvents)).toBe(true)
		local keys: { [string]: boolean } = {}
		for _, def in ScheduledEvents.list do
			T.expect(keys[def.key]).toBeNil()
			keys[def.key] = true
			T.expect(ScheduledEvents.get(def.key)).toBe(def)
			T.expect(#def.slots > 0).toBe(true)
			local days: { [number]: boolean } = {}
			for _, slot in def.slots do
				T.expect(slot.weekday).toBeBetween(1, 7)
				T.expect(slot.hour).toBeBetween(0, 23)
				T.expect(slot.minute).toBeBetween(0, 59)
				T.expect({ def.key, slot.weekday, days[slot.weekday] }).toEqual({ def.key, slot.weekday, nil })
				days[slot.weekday] = true
			end
			T.expect(def.duration > 0).toBe(true)
			T.expect(def.duration < DAY).toBe(true)
			for i, before in def.warn do
				T.expect(before > 0).toBe(true)
				if i > 1 then
					T.expect(before < def.warn[i - 1]).toBe(true)
				end
			end
			for _, key in { def.nameKey, def.descKey } do
				T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			end
		end
	end)

	T.it("the Blood Moon is Tuesday and Thursday 19:00 UTC for 30 min (DESIGN-17 §7)", function()
		T.expect(BLOOD.slots).toEqual({
			{ weekday = 2, hour = 19, minute = 0 },
			{ weekday = 4, hour = 19, minute = 0 },
		})
		T.expect(BLOOD.duration).toBe(1800)
		T.expect(BLOOD.warn).toEqual({ 600, 60 })
		T.expect(BLOOD.blocksWorldEvents).toBe(true)
		T.expect(BLOOD.enabled).toBe(true)
	end)
end)
