--!strict
-- Help for returning players (S153, docs/DESIGN.md §11): the bonus after a long absence (Logic/Returning) and the
-- "What has changed" log (Data/Changelog).
local Changelog = require("../src/shared/Data/Changelog")
local Config = require("../src/shared/Config")
local Products = require("../src/shared/Data/Products")
local Returning = require("../src/shared/Logic/Returning")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local DAY = 86400
local HOUR = 3600
local NOW = 20000 * DAY + 12 * HOUR
local R = Config.Returning

local function fresh(): Returning.State
	return Returning.sanitize(nil)
end

T.describe("Returning: the bonus", function()
	T.it("no lastSeen (the first load after S153, a new account): nothing", function()
		local s, granted = Returning.check(fresh(), 0, NOW, 100)
		T.expect(granted).toBe(false)
		T.expect(s).toEqual({ left = 0, at = 0, seen = 0 })
	end)

	T.it("6 days 23 h away: nothing; 7 days: the full bonus", function()
		local _, early = Returning.check(fresh(), NOW - (R.awayDays * DAY - HOUR), NOW, 50)
		T.expect(early).toBe(false)
		local s, granted = Returning.check(fresh(), NOW - R.awayDays * DAY, NOW, 50)
		T.expect(granted).toBe(true)
		T.expect(s.left).toBe(R.seconds)
		T.expect(s.at).toBe(NOW)
	end)

	T.it("the cooldown counts from the last grant", function()
		local s = Returning.check(fresh(), NOW - 30 * DAY, NOW, 50)
		-- back again after 10 days (away 8 of them): inside the cooldown
		local later = NOW + 10 * DAY
		local _, again = Returning.check(s, later - 8 * DAY, later, 50)
		T.expect(again).toBe(false)
		-- after 15 days (away 8): granted
		local much = NOW + 15 * DAY
		local s2, yes = Returning.check(s, much - 8 * DAY, much, 50)
		T.expect(yes).toBe(true)
		T.expect(s2.at).toBe(much)
	end)

	T.it("needs a character of minLevel on the account; a level 100 one gets it too", function()
		local _, low = Returning.check(fresh(), NOW - 20 * DAY, NOW, R.minLevel - 1)
		T.expect(low).toBe(false)
		local _, ok = Returning.check(fresh(), NOW - 20 * DAY, NOW, R.minLevel)
		T.expect(ok).toBe(true)
		local _, top = Returning.check(fresh(), NOW - 20 * DAY, NOW, 100)
		T.expect(top).toBe(true)
	end)

	T.it("a grant sets the time, it never adds", function()
		local s = { left = 1200, at = NOW - 20 * DAY, seen = 3 }
		local out, granted = Returning.check(s, NOW - 8 * DAY, NOW, 50)
		T.expect(granted).toBe(true)
		T.expect(out).toEqual({ left = R.seconds, at = NOW, seen = 3 })
	end)

	T.it("ticks only in the world and never below 0", function()
		local s = { left = 100, at = NOW, seen = 0 }
		T.expect(Returning.tick(s, 30, false).left).toBe(100)
		T.expect(Returning.tick(s, 30, true).left).toBe(70)
		T.expect(Returning.tick(s, 500, true).left).toBe(0)
		T.expect(Returning.tick(s, -5, true).left).toBe(100)
	end)

	T.it("bonus and minutes", function()
		T.expect(Returning.bonus(fresh())).toBe(0)
		T.expect(Returning.bonus({ left = 1, at = NOW, seen = 0 })).toBe(R.expBonus)
		T.expect(Returning.minutes({ left = 61, at = NOW, seen = 0 })).toBe(2)
		T.expect(Returning.minutes(fresh())).toBe(0)
	end)

	T.it("sanitizes broken saves", function()
		T.expect(Returning.sanitize("x")).toEqual({ left = 0, at = 0, seen = 0 })
		T.expect(Returning.sanitize({ left = -5, at = 0 / 0, seen = "3" })).toEqual({ left = 0, at = 0, seen = 0 })
		T.expect(Returning.sanitize({ left = 1e9, at = 12.7, seen = 4.9 })).toEqual({
			left = R.seconds,
			at = 12,
			seen = 4,
		})
		T.expect(Returning.sanitize({ left = math.huge, at = -1, seen = -2 })).toEqual({ left = 0, at = 0, seen = 0 })
	end)

	T.it("is not sold: Data/Products never mentions it", function()
		local function mentions(value: any): boolean
			return type(value) == "string" and string.find(string.lower(value), "returning", 1, true) ~= nil
		end
		local function walk(value: any, depth: number)
			if depth > 8 or type(value) ~= "table" then
				return
			end
			for key, inner in value do
				T.expect({ key, mentions(key), mentions(inner) }).toEqual({ key, false, false })
				walk(inner, depth + 1)
			end
		end
		walk(Products, 0)
		-- nor does its source read Config.Returning (or anything named after it)
		local fs = require("@lune/fs")
		T.expect(mentions(fs.readFile("src/shared/Data/Products.luau"))).toBe(false)
	end)
end)

local function e(id: number, day: number): any
	return { id = id, day = day, key = `k{id}` }
end

T.describe("Returning: the letter", function()
	local today = Time.dayNumber(NOW)

	T.it("newest first, newer than seen, at most letterMax, future days hidden", function()
		local entries = {}
		for id = 1, R.letterMax + 3 do
			table.insert(entries, e(id, today - 20 + id))
		end
		table.insert(entries, e(R.letterMax + 4, today + 1)) -- not out yet
		local all = Returning.letter(0, entries, NOW)
		T.expect(#all).toBe(R.letterMax)
		T.expect(all[1].id).toBe(R.letterMax + 3)
		for i = 2, #all do
			T.expect(all[i].id < all[i - 1].id).toBe(true)
		end
		local some = Returning.letter(R.letterMax + 1, entries, NOW)
		T.expect(#some).toBe(2)
		T.expect(some[1].id).toBe(R.letterMax + 3)
		T.expect(#Returning.letter(R.letterMax + 3, entries, NOW)).toBe(0)
		T.expect(#Returning.recent(entries, NOW)).toBe(R.letterMax)
	end)

	T.it("markSeen keeps the highest id and never goes back", function()
		local s = Returning.markSeen({ left = 5, at = 1, seen = 2 }, { e(4, today), e(3, today) })
		T.expect(s).toEqual({ left = 5, at = 1, seen = 4 })
		T.expect(Returning.markSeen(s, { e(1, today) }).seen).toBe(4)
	end)

	T.it("readUpTo accepts only an id of the log", function()
		local entries = { e(1, today), e(2, today), e(5, today) }
		T.expect(Returning.readUpTo(entries, 3)).toBeNil()
		local read = Returning.readUpTo(entries, 2) :: { any }
		T.expect(#read).toBe(2)
		T.expect(Returning.markSeen(fresh(), read).seen).toBe(2)
	end)
end)

T.describe("Data/Changelog (S153)", function()
	T.it("ids grow and are unique, days never go back", function()
		local list = Changelog.ENTRIES
		T.expect(#list > 0).toBe(true)
		for i, entry in list do
			T.expect(entry.id == math.floor(entry.id) and entry.id > 0).toBe(true)
			if i > 1 then
				T.expect({ entry.key, entry.id > list[i - 1].id }).toEqual({ entry.key, true })
				T.expect({ entry.key, entry.day >= list[i - 1].day }).toEqual({ entry.key, true })
			end
		end
		T.expect(Changelog.maxId()).toBe(list[#list].id)
	end)

	T.it("every entry has a title and a body in both languages", function()
		local keys: { [string]: boolean } = {}
		for _, entry in Changelog.ENTRIES do
			T.expect({ entry.key, keys[entry.key] == nil }).toEqual({ entry.key, true })
			keys[entry.key] = true
			for _, part in { "title", "body" } do
				local key = `changelog.{entry.key}.{part}`
				T.expect({ key, type(pl[key]) == "string", type(en[key]) == "string" }).toEqual({ key, true, true })
			end
		end
	end)
end)
