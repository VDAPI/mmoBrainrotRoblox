--!strict
-- Leaderboards (S124, DESIGN-17 §5): the board data, the score encoding, board ids, the in-memory board, write
-- throttling, rows and the own line, the Hall of Fame list and the town board panels. The Roblox stores are not here
-- (no DataStoreService in Lune): the server only calls these functions. S125: weekly EXP and the guild board below.

local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local Exp = require("../src/shared/Logic/Exp")
local Leaderboard = require("../src/shared/Logic/Leaderboard")
local Leaderboards = require("../src/shared/Data/Leaderboards")
local T = require("./Test")
local Town = require("../src/shared/Data/Town")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local CFG = { excludeAdmins = true, minLevel = Config.Leaderboard.minLevel }
local MAX = Config.MaxLevel

local function placeholders(text: string): { string }
	local out = {}
	for name in string.gmatch(text, "{([%w_]+)}") do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

local function entry(key: string, score: number): Leaderboard.Entry
	return { key = key, score = score }
end

local function keysOf(entries: { Leaderboard.Entry }): { string }
	local out = {}
	for _, e in entries do
		table.insert(out, e.key)
	end
	return out
end

local function plain(value: any, path: string)
	local kind = type(value)
	if kind == "table" then
		for k, v in value do
			if type(k) ~= "string" and type(k) ~= "number" then
				error(`{path}: key of type {type(k)}`)
			end
			plain(v, `{path}.{k}`)
		end
	elseif kind ~= "string" and kind ~= "number" and kind ~= "boolean" then
		error(`{path}: value of type {kind}`)
	end
end

T.describe("Leaderboards (S124)", function()
	T.it("defines a level board, one per class and a Hall of Fame per class", function()
		local seen = {}
		for _, def in Leaderboards.list do
			T.expect(seen[def.id]).toBeNil()
			seen[def.id] = true
			T.expect({ def.id, def.kind == "ordered" or def.kind == "sorted" or def.kind == "list" })
				.toEqual({ def.id, true })
			T.expect({ def.id, def.ttl ~= nil }).toEqual({ def.id, def.kind == "sorted" })
			T.expect({ def.id, def.max ~= nil }).toEqual({ def.id, def.kind == "list" })
			T.expect({ def.id, def.mode ~= nil }).toEqual({ def.id, def.kind == "list" })
			if def.score then
				T.expect({ def.id, Leaderboard.SCORERS[def.score] ~= nil }).toEqual({ def.id, true })
			end
			for _, part in def.parts or {} do
				T.expect({ def.id, part, Leaderboard.PARTS[part] ~= nil }).toEqual({ def.id, part, true })
			end
			T.expect(Leaderboards.get(def.id)).toBe(def)
		end
		local level = Leaderboards.get("level") :: Leaderboards.BoardDef
		T.expect(level.kind).toBe("ordered")
		T.expect(level.class).toBeNil()
		T.expect(level.score).toBe("level")
		for _, class in Classes.order do
			local lower = string.lower(class)
			local byClass = Leaderboards.get(`level_{lower}`) :: Leaderboards.BoardDef
			T.expect({ byClass.kind, byClass.class, byClass.score }).toEqual({ "ordered", class, "level" })
			local hof = Leaderboards.get(`hof_{lower}`) :: Leaderboards.BoardDef
			T.expect({ hof.kind, hof.class, hof.max, hof.mode }).toEqual({ "list", class, 10, "first" })
		end
		T.expect(table.isfrozen(Leaderboards :: any)).toBe(true)
		T.expect(table.isfrozen(Leaderboards.list)).toBe(true)
		T.expect(table.isfrozen(level)).toBe(true)
	end)

	T.it("tabs, filters, panels and plinths point at real boards", function()
		for _, tab in Leaderboards.tabs do
			for _, id in tab.boards do
				T.expect({ tab.id, id, Leaderboards.get(id) ~= nil }).toEqual({ tab.id, id, true })
			end
			if tab.filter == "class" then
				for _, class in Classes.order do
					local n = 0
					for _, id in tab.boards do
						if (Leaderboards.get(id) :: any).class == class then
							n += 1
						end
					end
					T.expect({ tab.id, class, n }).toEqual({ tab.id, class, 1 })
					T.expect(Leaderboard.boardFor(tab, class)).toBe(`{tab.id}_{string.lower(class)}`)
				end
			end
		end
		local levelTab = Leaderboards.tabs[1]
		T.expect(Leaderboard.boardFor(levelTab, nil)).toBe("level")
		T.expect(Leaderboard.boardFor(Leaderboards.tabs[2], nil)).toBeNil()
		for _, panel in Leaderboards.TOWN.panels do
			for _, id in panel.boards do
				T.expect({ panel.id, id, Leaderboards.get(id) ~= nil }).toEqual({ panel.id, id, true })
			end
		end
		for i, plinth in Leaderboards.TOWN.plinths do
			local def = Leaderboards.get(plinth.board) :: Leaderboards.BoardDef
			T.expect(def.kind).toBe("list")
			T.expect(def.class).toBe(Classes.order[i])
		end
		T.expect(#Leaderboards.TOWN.plinths).toBe(#Town.fame.plinths)
		T.expect(Leaderboards.TOWN.panels[1].n).toBe(Config.Leaderboard.townTop)
	end)

	T.it("has every text in both languages with the same placeholders", function()
		local keys = {}
		for _, def in Leaderboards.list do
			table.insert(keys, def.nameKey)
		end
		for _, tab in Leaderboards.tabs do
			table.insert(keys, tab.nameKey)
		end
		for _, panel in Leaderboards.TOWN.panels do
			table.insert(keys, panel.titleKey)
		end
		for _, plinth in Leaderboards.TOWN.plinths do
			table.insert(keys, plinth.captionKey)
		end
		for key in en do
			if string.sub(key, 1, 12) == "leaderboard." or string.sub(key, 1, 10) == "town.fame." then
				table.insert(keys, key)
			end
		end
		for key in pl do
			if string.sub(key, 1, 12) == "leaderboard." or string.sub(key, 1, 10) == "town.fame." then
				table.insert(keys, key)
			end
		end
		for _, key in keys do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			T.expect({ key, placeholders(pl[key]) }).toEqual({ key, placeholders(en[key]) })
		end
	end)

	T.it("encodes the level score as a whole number that orders levels, EXP and the first at the top", function()
		local now = 1791763200
		for _, level in { 1, 2, 19, 20, 57, 98, 99 } do
			local need = Exp.expToNext(level)
			local a = Leaderboard.levelScore(level, 0, nil, now)
			local b = Leaderboard.levelScore(level, need // 2, nil, now)
			local c = Leaderboard.levelScore(level, need - 1, nil, now)
			T.expect(a < b and b < c).toBe(true)
			T.expect(c < Leaderboard.levelScore(level + 1, 0, nil, now)).toBe(true)
			for _, s in { a, b, c } do
				T.expect(s % 1).toBe(0)
				T.expect(s < 2 ^ 53).toBe(true)
			end
		end
		local early = Leaderboard.levelScore(MAX, 0, now - 1000, now)
		local late = Leaderboard.levelScore(MAX, 0, now, now)
		T.expect(early > late).toBe(true)
		T.expect(late > Leaderboard.levelScore(MAX - 1, Exp.expToNext(MAX - 1) - 1, nil, now)).toBe(true)
		T.expect(Leaderboard.levelScore(MAX, 0, nil, now)).toBe(late)
		T.expect(late < 2 ^ 53 and late % 1 == 0).toBe(true)
		T.expect(Leaderboard.levelScore(0, 0, nil, now)).toBe(Leaderboard.levelScore(1, 0, nil, now))
		T.expect(Leaderboard.levelScore(150, 0, now, now)).toBe(late)
		-- more EXP than the level needs stays inside the level
		T.expect(Leaderboard.levelScore(10, 1e12, nil, now) < Leaderboard.levelScore(11, 0, nil, now)).toBe(true)

		local level, frac = Leaderboard.decodeLevel(Leaderboard.levelScore(57, Exp.expToNext(57) * 0.43, nil, now))
		T.expect(level).toBe(57)
		T.expect(frac ~= nil and frac >= 0.42 and frac <= 0.44).toBe(true)
		local top, topFrac = Leaderboard.decodeLevel(early)
		T.expect(top).toBe(MAX)
		T.expect(topFrac).toBeNil()
		local one, oneFrac = Leaderboard.decodeLevel(Leaderboard.levelScore(1, 0, nil, now))
		T.expect(one).toBe(1)
		T.expect(oneFrac).toBe(0)
	end)

	T.it("scores only the level, EXP and the moment of the top level", function()
		local now = 1791763200
		local base = { level = 42, exp = 1234, reached100At = nil, name = "Aria", class = "Mage" }
		local rich = table.clone(base) :: any
		rich.title = "title_highborn"
		rich.guildId = "g1"
		rich.gold = 1e9
		rich.lure = { untilTs = 1e12, on = true }
		rich.equipment = { weapon = { id = "x", rarity = 5 } }
		rich.class = "Warrior"
		for name, scorer in Leaderboard.SCORERS do
			T.expect({ name, scorer(base, now) }).toEqual({ name, scorer(rich, now) })
		end
	end)

	T.it("builds and reads board instance ids", function()
		local def, parts = Leaderboard.resolve("level")
		T.expect(def).toBe(Leaderboards.get("level"))
		T.expect(parts).toBeNil()
		T.expect((Leaderboard.resolve("level_mage"))).toBe(Leaderboards.get("level_mage"))
		T.expect((Leaderboard.resolve("nothing"))).toBeNil()
		T.expect((Leaderboard.resolve(""))).toBeNil()
		T.expect((Leaderboard.resolve(string.rep("a", 200)))).toBeNil()

		local weekly: Leaderboards.BoardDef = {
			id = "x",
			kind = "sorted",
			nameKey = "x",
			scope = "character",
			parts = { "week" },
			ttl = 1,
			format = "int",
		}
		local arena: Leaderboards.BoardDef = {
			id = "arena",
			kind = "sorted",
			nameKey = "x",
			scope = "character",
			parts = { "season", "bracket" },
			ttl = 1,
			format = "int",
		}
		local defs = { weekly, arena }
		T.expect(Leaderboard.instanceId(weekly, { "2963" })).toBe("x_2963")
		local d1, p1 = Leaderboard.resolve("x_2963", defs)
		T.expect(d1).toBe(weekly)
		T.expect(p1).toEqual({ "2963" })
		T.expect(function()
			Leaderboard.instanceId(weekly, nil)
		end).toThrow()
		T.expect(function()
			Leaderboard.instanceId(weekly, { "1", "2" })
		end).toThrow()
		T.expect(function()
			Leaderboard.instanceId(Leaderboards.get("level") :: any, { "1" })
		end).toThrow()
		local d2, p2 = Leaderboard.resolve("arena_202611_40_59", defs)
		T.expect(d2).toBe(arena)
		T.expect(p2).toEqual({ "202611", "40_59" })
		T.expect((Leaderboard.resolve("arena_202611", defs))).toBeNil()
		T.expect((Leaderboard.resolve("arena_202611_", defs))).toBeNil()
		T.expect((Leaderboard.resolve("x_", defs))).toBeNil()
		T.expect((Leaderboard.resolve("x_29 63", defs))).toBeNil()
		T.expect(Leaderboard.PARTS.week({ now = 1791763200 })).toBe("2963")
		T.expect(Leaderboard.PARTS.season({ now = 1791763200 })).toBe("202610")
		T.expect(Leaderboard.partsAt(weekly, 1791763200)).toEqual({ "2963" })
		T.expect(Leaderboard.partsAt(Leaderboards.get("level") :: any, 1)).toBeNil()

		T.expect(Leaderboard.entryKey(123, 4)).toBe("123_4")
		T.expect(Leaderboard.entryKey(123, "5")).toBe("123_5")
		local user, slot = Leaderboard.parseKey("123_4")
		T.expect({ user, slot }).toEqual({ 123, "4" })
		T.expect((Leaderboard.parseKey("g_abc"))).toBeNil()
		T.expect((Leaderboard.parseKey("x"))).toBeNil()
	end)

	T.it("keeps an in-memory board ordered, with ties by key and expiry", function()
		local board = Leaderboard.memoryBoard()
		board.set("b", 10)
		board.set("a", 10)
		board.set("c", 30)
		board.set("d", 5, nil, 100)
		T.expect(keysOf(board.top(10, 50))).toEqual({ "c", "a", "b", "d" })
		T.expect(keysOf(board.top(10, 100))).toEqual({ "c", "a", "b" })
		T.expect(board.size(100)).toBe(3)
		board.set("c", 1)
		T.expect(keysOf(board.top(2, 0))).toEqual({ "a", "b" })
		board.remove("a")
		T.expect(keysOf(board.top(10, 0))).toEqual({ "b", "c" })
		T.expect(board.update("b", function(old)
			return (if old then old.score else 0) + 7, "meta"
		end, nil, 0)).toBe(17)
		T.expect(board.get("b", 0)).toEqual({ score = 17, value = "meta" })
		T.expect(board.update("b", function()
			return nil
		end, nil, 0)).toBeNil()
		T.expect((board.get("b", 0) :: any).score).toBe(17)
		board.update("new", function(old)
			return (if old then old.score else 0) + 3
		end, 20, 10)
		T.expect((board.get("new", 19) :: any).score).toBe(3)
		T.expect(board.get("new", 20)).toBeNil()
		board.clear()
		T.expect(board.size(0)).toBe(0)
	end)

	T.it("throttles writes per board and key", function()
		local t = Leaderboard.newThrottle()
		T.expect(Leaderboard.queue(t, "level", "1_1", { score = 5 }, 0, 60)).toBe(true)
		T.expect(#Leaderboard.due(t, 0, 60)).toBe(1)
		T.expect(Leaderboard.queue(t, "level", "1_1", { score = 6 }, 10, 60)).toBe(false)
		T.expect(Leaderboard.queue(t, "level", "1_1", { score = 7 }, 20, 60)).toBe(false)
		-- another board of the same key has its own clock
		T.expect(Leaderboard.queue(t, "level_mage", "1_1", { score = 7 }, 20, 60)).toBe(true)
		local now = Leaderboard.due(t, 30, 60)
		T.expect(#now).toBe(1)
		T.expect(now[1].board).toBe("level_mage")
		T.expect(#Leaderboard.due(t, 59, 60)).toBe(0)
		local later = Leaderboard.due(t, 60, 60)
		T.expect(#later).toBe(1)
		T.expect(later[1].score).toBe(7)
		T.expect(#Leaderboard.due(t, 200, 60)).toBe(0)

		Leaderboard.queue(t, "week", "1_1", { delta = 5 }, 100, 60)
		Leaderboard.due(t, 100, 60)
		Leaderboard.queue(t, "week", "1_1", { delta = 5 }, 110, 60)
		Leaderboard.queue(t, "week", "1_1", { delta = 3 }, 120, 60)
		T.expect(Leaderboard.pendingCount(t)).toBe(1)
		local forced = Leaderboard.due(t, 121, 60, true)
		T.expect(#forced).toBe(1)
		T.expect(forced[1].delta).toBe(8)

		Leaderboard.queue(t, "level", "2_1", { score = 1 }, 300, 60)
		Leaderboard.due(t, 300, 60)
		Leaderboard.queue(t, "level", "2_1", { score = 2 }, 310, 60)
		T.expect(#Leaderboard.due(t, 311, 60)).toBe(0)
		Leaderboard.release(t, "2_1")
		T.expect(#Leaderboard.due(t, 312, 60)).toBe(1)
		Leaderboard.queue(t, "level", "3_1", { score = 1 }, 400, 60)
		Leaderboard.queue(t, "level", "3_1", { remove = true }, 400, 60)
		local removed = Leaderboard.due(t, 400, 60)
		T.expect({ removed[1].remove, removed[1].score }).toEqual({ true, nil })
		-- a write after a queued removal replaces it (hide, then show)
		Leaderboard.queue(t, "@meta", "4_1", { remove = true }, 500, 60)
		Leaderboard.queue(t, "@meta", "4_1", { meta = { n = "A", t = 500 } }, 500, 60)
		local shown = Leaderboard.due(t, 500, 60)
		T.expect({ shown[1].remove, (shown[1].meta :: any).n }).toEqual({ nil, "A" })
	end)

	T.it("merges the own score into a cached top", function()
		local list = { entry("a", 50), entry("b", 40), entry("c", 30) }
		T.expect(keysOf(Leaderboard.mergeLocal(list, "x", 45, 10))).toEqual({ "a", "x", "b", "c" })
		T.expect(keysOf(Leaderboard.mergeLocal(list, "c", 60, 10))).toEqual({ "c", "a", "b" })
		T.expect(keysOf(Leaderboard.mergeLocal(list, "a", 35, 10))).toEqual({ "b", "a", "c" })
		T.expect(keysOf(Leaderboard.mergeLocal(list, "b", nil, 10))).toEqual({ "a", "c" })
		T.expect(keysOf(Leaderboard.mergeLocal(list, "x", 45, 3))).toEqual({ "a", "x", "b" })
		T.expect(keysOf(Leaderboard.mergeLocal(list, "x", 10, 3))).toEqual({ "a", "b", "c" })
		T.expect(keysOf(list)).toEqual({ "a", "b", "c" })
	end)

	T.it("builds rows without excluded users, with metadata and the own line", function()
		local now = 1791763200
		local def = Leaderboards.get("level") :: Leaderboards.BoardDef
		local entries = {
			entry("7_1", Leaderboard.levelScore(80, 0, nil, now)),
			entry("9_2", Leaderboard.levelScore(70, Exp.expToNext(70) // 2, nil, now)),
			entry("11_1", Leaderboard.levelScore(60, 0, nil, now)),
		}
		local meta: { [string]: Leaderboard.Meta } = {
			["7_1"] = { n = "Admin", c = "Mage", t = 0 },
			["9_2"] = { n = "Aria", c = "Cleric", g = "ORD", l = 70, t = 0 },
			["11_1"] = { n = "", t = 0, d = true },
		}
		local rows = Leaderboard.rows(def, entries, function(key)
			return meta[key]
		end, function(user)
			return user == 7
		end, "11_1")
		T.expect(#rows).toBe(2)
		local _, half = Leaderboard.decodeLevel(entries[2].score)
		T.expect({ rows[1].r, rows[1].n, rows[1].c, rows[1].g, rows[1].l, rows[1].p }).toEqual({
			1,
			"Aria",
			"@class.Cleric.name",
			"ORD",
			70,
			math.floor((half :: number) * 100),
		})
		T.expect(rows[1].p == 49 or rows[1].p == 50).toBe(true)
		T.expect({ rows[2].r, rows[2].n, rows[2].mine, rows[2].l }).toEqual({ 2, "", true, 60 })
		T.expect(rows[1].mine).toBeNil()
		T.expect(Leaderboard.rankOf(rows)).toBe(2)

		local me = Leaderboard.me({ level = 60, exp = 0 }, rows, CFG, false)
		T.expect({ me.r, me.l }).toEqual({ 2, 60 })
		local outside = Leaderboard.me({ level = 30, exp = Exp.expToNext(30) // 4 }, { rows[1] }, CFG, false)
		local need30 = Exp.expToNext(30)
		T.expect({ outside.r, outside.l, outside.p }).toEqual({ nil, 30, math.floor((need30 // 4) / need30 * 100) })
		local below = Leaderboard.me({ level = CFG.minLevel - 1, exp = 0 }, rows, CFG, false)
		T.expect(below.below).toBe(CFG.minLevel)
		T.expect(Leaderboard.me({ level = 60, exp = 0, lbHidden = true }, rows, CFG, true).hidden).toBe(true)
		local atTop = Leaderboard.me({ level = MAX, exp = 0 }, {}, CFG, false)
		T.expect({ atTop.l, atTop.p }).toEqual({ MAX, nil })
	end)

	T.it("leaves out admins and test characters, and characters below the minimum level", function()
		T.expect(Leaderboard.excluded(5, {}, { 5 }, CFG)).toBe(true)
		T.expect(Leaderboard.excluded(5, {}, { 5 }, { excludeAdmins = false, minLevel = 5 })).toBe(false)
		T.expect(Leaderboard.excluded(6, {}, { 5 }, CFG)).toBe(false)
		T.expect(Leaderboard.excluded(6, { lbHidden = true }, { 5 }, CFG)).toBe(true)
		T.expect(Leaderboard.excluded(6, nil, {}, CFG)).toBe(false)
		T.expect(Leaderboard.eligible({ level = CFG.minLevel }, CFG)).toBe(true)
		T.expect(Leaderboard.eligible({ level = CFG.minLevel - 1 }, CFG)).toBe(false)
	end)

	T.it("keeps the first ten of the Hall of Fame for good, in the order they reached the top", function()
		local list: { Leaderboard.ListEntry }? = nil
		for i = 1, 10 do
			local why
			list, why = Leaderboard.listInsert(list, { k = `u_{i}`, n = `N{i}`, at = 1000 - i }, 10, "first")
			T.expect(why).toBeNil()
		end
		local full = list :: { Leaderboard.ListEntry }
		T.expect(#full).toBe(10)
		T.expect(full[1].k).toBe("u_10")
		T.expect(Leaderboard.placeOf(full, "u_1")).toBe(10)
		local none, why = Leaderboard.listInsert(full, { k = "late", n = "L", at = 1 }, 10, "first")
		T.expect({ none, why }).toEqual({ nil, "full" })
		local dup, dupWhy = Leaderboard.listInsert(full, { k = "u_3", n = "N3", at = 5 }, 10, "first")
		T.expect({ dup, dupWhy }).toEqual({ nil, "dup" })
		T.expect(#full).toBe(10)

		-- two servers writing in the opposite order end with the same list
		local a = { k = "a", n = "A", at = 50 }
		local b = { k = "b", n = "B", at = 40 }
		local one = Leaderboard.listInsert(Leaderboard.listInsert(nil, a, 10, "first"), b, 10, "first")
		local two = Leaderboard.listInsert(Leaderboard.listInsert(nil, b, 10, "first"), a, 10, "first")
		T.expect(one).toEqual(two)
		T.expect((one :: any)[1].k).toBe("b")

		local latest: { Leaderboard.ListEntry }? = nil
		for i = 1, 6 do
			latest = Leaderboard.listInsert(latest, { k = `k{i}`, n = "x", at = i }, 4, "latest")
		end
		T.expect(#(latest :: any)).toBe(4)
		T.expect((latest :: any)[1].k).toBe("k3")

		local input = { { k = "z", n = "Z", at = 9 } }
		Leaderboard.listInsert(input, { k = "y", n = "Y", at = 1 }, 10, "first")
		T.expect(#input).toBe(1)

		local me = Leaderboard.listMe(full, "u_4", 10, false)
		T.expect(me.r).toBe(7)
		T.expect(Leaderboard.listMe({ input[1] }, "other", 10, false).left).toBe(9)
		local rows = Leaderboard.listRows(Leaderboards.get("hof_mage") :: any, full, function()
			return false
		end, "u_10")
		T.expect({ rows[1].n, rows[1].at, rows[1].mine, rows[1].c }).toEqual({ "N10", 990, true, "@class.Mage.name" })
	end)

	T.it("tells a new character on a reused slot key apart from the deleted one in the Hall of Fame", function()
		local old = { k = "7_1", n = "Old", c = "Warrior", u = 7, at = 100, cid = "c-old" }
		local list = Leaderboard.listInsert(nil, old, 10, "first") :: { Leaderboard.ListEntry }
		local again, why = Leaderboard.listInsert(list, table.clone(old), 10, "first")
		T.expect({ again, why }).toEqual({ nil, "dup" })
		T.expect(Leaderboard.placeOf(list, "7_1", "c-new")).toBeNil()
		T.expect(Leaderboard.placeOf(list, "7_1", "c-old")).toBe(1)
		T.expect(Leaderboard.listMe(list, "7_1", 10, false, "c-new").left).toBe(9)
		local rows = Leaderboard.listRows(Leaderboards.get("hof_warrior") :: any, list, function()
			return false
		end, "7_1", "c-new")
		T.expect(rows[1].mine).toBeNil()

		local new = { k = "7_1", n = "New", c = "Warrior", u = 7, at = 200, cid = "c-new" }
		local both = Leaderboard.listInsert(list, new, 10, "first") :: { Leaderboard.ListEntry }
		T.expect(#both).toBe(2)
		T.expect(Leaderboard.placeOf(both, "7_1", "c-new")).toBe(2)
		T.expect(Leaderboard.listMe(both, "7_1", 10, false, "c-new").r).toBe(2)
		-- an entry without a character id (/lb fake) matches by key alone
		T.expect(Leaderboard.placeOf({ { k = "0_1", n = "T", at = 1 } }, "0_1", "any")).toBe(1)
	end)

	T.it("builds the town board panels from snapshots as plain data", function()
		local now = 1791763200
		local fakes = Leaderboard.fakeEntries(30, now)
		T.expect(#fakes).toBe(30)
		local entries = {}
		local meta = {}
		for _, f in fakes do
			table.insert(entries, entry(f.key, f.score))
			meta[f.key] = f.meta
		end
		table.sort(entries, Leaderboard.better)
		local rows = Leaderboard.rows(Leaderboards.get("level") :: any, entries, function(key)
			return meta[key]
		end, function()
			return false
		end, nil)
		T.expect(rows[1].l).toBe(MAX)
		local hofList = { { k = "1_1", n = "First", c = "Warrior", at = now } }
		local function read(id: string): Leaderboard.Snapshot?
			local def = Leaderboards.get(id) :: Leaderboards.BoardDef
			if def.kind == "list" then
				return {
					id = id,
					kind = def.kind,
					format = def.format,
					rows = if id == "hof_warrior"
						then Leaderboard.listRows(def, hofList, function()
							return false
						end, nil)
						else {},
					at = now,
					mode = "local",
				}
			end
			return { id = id, kind = def.kind, format = def.format, rows = rows, at = now, mode = "local" }
		end
		local panels = Leaderboard.townPanels(Leaderboards.TOWN.panels, read)
		T.expect(#panels).toBe(2)
		T.expect(#panels[1].columns).toBe(1)
		T.expect(#panels[1].columns[1].rows).toBe(Config.Leaderboard.townTop)
		T.expect(#panels[2].columns).toBe(#Classes.order)
		T.expect(panels[2].columns[1].titleKey).toBe("leaderboard.board.hof_warrior")
		T.expect(panels[2].columns[1].rows[1].n).toBe("First")
		T.expect(#panels[2].columns[2].rows).toBe(0)
		plain(panels, "panels")
		-- nothing read yet: empty columns
		local empty = Leaderboard.townPanels(Leaderboards.TOWN.panels, function()
			return nil
		end)
		T.expect(#empty[1].columns[1].rows).toBe(0)
	end)

	T.it("splits dates into day, month and year", function()
		T.expect(Leaderboard.dateParts(1791763200)).toEqual({ d = "12", m = "10", y = "2026" })
		T.expect(Leaderboard.dateParts(0)).toEqual({ d = "01", m = "01", y = "1970" })
	end)
end)

-- S125 (DESIGN-17 §5): weekly EXP (brackets, the week, the entry and its merge, the payout lock and plan), the guild
-- score and the save fields. The SortedMap and DataStore calls are not here: the server only calls these functions.
T.describe("S125 weekly EXP and the guild board", function()
	local AccountSchema = require("../src/shared/Logic/AccountSchema")
	local TitleData = require("../src/shared/Data/Titles")
	local Time = require("../src/shared/Logic/Time")
	local MONDAY = 1791763200 -- 2026-10-12 00:00 UTC, week 2963 (S98)

	local function weekly(s: number, cid: string?): Leaderboard.WeeklyValue
		return { s = s, m = { n = "Aria", c = "Mage", l = 30, u = 1, t = 0 }, cid = cid }
	end

	T.it("has four contiguous brackets, the rewards, the sources and both boards", function()
		local brackets = Leaderboards.WEEK_BRACKETS
		T.expect(brackets).toEqual({ { 1, 19 }, { 20, 44 }, { 45, 69 }, { 70, 100 } })
		local nextLevel = 1
		for _, b in brackets do
			T.expect(b[1]).toBe(nextLevel)
			T.expect(b[2] >= b[1]).toBe(true)
			nextLevel = b[2] + 1
		end
		T.expect(nextLevel).toBe(MAX + 1)
		local rewards = Leaderboards.WEEK_REWARDS
		T.expect(rewards.shards).toEqual({ 100, 50, 25 })
		for i, n in rewards.shards do
			T.expect(n > 0 and n == math.floor(n)).toBe(true)
			if i > 1 then
				T.expect(n < rewards.shards[i - 1]).toBe(true)
			end
		end
		T.expect(rewards.titleDays).toBe(7)
		local title = TitleData.get(rewards.title) :: TitleData.TitleDef
		T.expect(title ~= nil).toBe(true)
		T.expect(title.req.kind).toBe("timed")
		T.expect(Leaderboards.WEEK_SOURCES.admin).toBeNil()
		for _, source in { "monster", "boss", "quest", "contract", "worldEvent" } do
			T.expect({ source, Leaderboard.countsForWeek(source) }).toEqual({ source, true })
		end
		T.expect(Leaderboard.countsForWeek("admin")).toBe(false)
		T.expect(Leaderboard.countsForWeek(nil)).toBe(false)
		T.expect(Leaderboard.countsForWeek("purchase")).toBe(false)
		local week = Leaderboards.get("exp_week") :: Leaderboards.BoardDef
		T.expect({ week.kind, week.scope, week.format, week.ttl }).toEqual({
			"sorted",
			"character",
			"int",
			Config.Leaderboard.weekTtl,
		})
		T.expect(week.parts).toEqual({ "week", "bracket" })
		T.expect(week.score).toBeNil()
		local guild = Leaderboards.get("guild") :: Leaderboards.BoardDef
		T.expect({ guild.kind, guild.scope, guild.format }).toEqual({ "ordered", "guild", "guild" })
		T.expect(guild.score).toBeNil()
		for _, key in { week.nameKey, guild.nameKey, "leaderboard.tab.week", "leaderboard.tab.guild" } do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)

	T.it("finds brackets, labels and weekly board ids", function()
		local cases = { { 1, 1 }, { 19, 1 }, { 20, 2 }, { 44, 2 }, { 45, 3 }, { 69, 3 }, { 70, 4 }, { 100, 4 } }
		for _, c in cases do
			T.expect({ c[1], Leaderboard.bracketOf(c[1]) }).toEqual({ c[1], c[2] })
		end
		T.expect(Leaderboard.bracketOf(0)).toBe(1)
		T.expect(Leaderboard.bracketOf(101)).toBe(4)
		T.expect(Leaderboard.bracketLabel(1)).toBe("1–19")
		T.expect(Leaderboard.bracketLabel(4)).toBe("70–100")
		T.expect(Leaderboard.bracketLabel(9)).toBe("")
		T.expect(Leaderboard.weekMapName(2963, 2)).toBe("exp_week_2963_2")
		T.expect(Leaderboard.weekMapName(2963, 1) ~= Leaderboard.weekMapName(2964, 1)).toBe(true)
		T.expect(Leaderboard.weekMapName(2963, 1) ~= Leaderboard.weekMapName(2963, 2)).toBe(true)
		local def, parts = Leaderboard.resolve("exp_week_2963_2")
		T.expect(def).toBe(Leaderboards.get("exp_week"))
		T.expect(parts).toEqual({ "2963", "2" })
		T.expect(Leaderboard.PARTS.bracket({ now = 0, level = 50 })).toBe("3")
		T.expect(Leaderboard.PARTS.bracket({ now = 0, bracket = 2 })).toBe("2")
		local tab: Leaderboards.TabDef? = nil
		for _, t in Leaderboards.tabs do
			if t.id == "week" then
				tab = t
			end
		end
		T.expect(tab ~= nil).toBe(true)
		local weekTab = tab :: Leaderboards.TabDef
		T.expect(weekTab.filter).toBe("bracket")
		T.expect(Leaderboard.boardFor(weekTab, "4", MONDAY + 3600)).toBe("exp_week_2963_4")
		T.expect(Leaderboard.boardFor(weekTab, "9", MONDAY)).toBe("exp_week_2963_4")
		T.expect(Leaderboard.boardFor(weekTab, "2", nil)).toBeNil()
		T.expect((Leaderboard.resolve("guild"))).toBe(Leaderboards.get("guild"))
		-- a client reads only the boards the window builds: this week (or within READ_GRACE of its start), brackets 1..4
		local function readable(id: string, now: number): boolean
			local d, p = Leaderboard.resolve(id)
			return d ~= nil and Leaderboard.readable(d, p, now)
		end
		T.expect(readable("level", MONDAY)).toBe(true)
		T.expect(readable("exp_week_2963_1", MONDAY + 86400)).toBe(true)
		T.expect(readable("exp_week_2963_4", MONDAY + 86400)).toBe(true)
		T.expect(readable("exp_week_2962_2", MONDAY + 60)).toBe(true)
		T.expect(readable("exp_week_2962_2", MONDAY + Leaderboard.READ_GRACE + 60)).toBe(false)
		T.expect(readable("exp_week_2964_1", MONDAY + 60)).toBe(false)
		for _, bad in { "exp_week_2963_0", "exp_week_2963_5", "exp_week_2963_01", "exp_week_2963_x", "exp_week_abc_1" } do
			T.expect({ bad, readable(bad, MONDAY + 60) }).toEqual({ bad, false })
		end
		T.expect(Leaderboard.readable(Leaderboards.get("exp_week") :: any, nil, MONDAY)).toBe(false)
	end)

	T.it("adds weekly EXP without touching the input", function()
		local first = Leaderboard.addWeekly(nil, 2963, 120)
		T.expect(first).toEqual({ week = 2963, exp = 120, b = 0 })
		local state = { week = 2963, exp = 500, b = 2 }
		local more = Leaderboard.addWeekly(state, 2963, 40.7)
		T.expect(more).toEqual({ week = 2963, exp = 540, b = 2 })
		T.expect(state).toEqual({ week = 2963, exp = 500, b = 2 })
		T.expect(Leaderboard.addWeekly(state, 2964, 10)).toEqual({ week = 2964, exp = 10, b = 0 })
		T.expect(Leaderboard.addWeekly(state, 2963, -50)).toEqual(state)
		T.expect(Leaderboard.addWeekly(state, 2963, 0 / 0)).toEqual(state)
		T.expect(Leaderboard.addWeekly(state, 2963, math.huge)).toEqual(state)
		T.expect(Leaderboard.addWeekly(state, 2963, 0)).toEqual(state)
		T.expect(Leaderboard.weekExp({ expWeek = state }, 2963)).toBe(500)
		T.expect(Leaderboard.weekExp({ expWeek = state }, 2964)).toBe(0)
		T.expect(Leaderboard.weekExp({}, 2963)).toBe(0)
	end)

	T.it("builds the weekly entry and merges it as an absolute total", function()
		local entry = Leaderboard.weeklyEntry({
			userId = 123,
			slot = 2,
			charId = "c1",
			name = "Aria",
			class = "Mage",
			level = 30,
			guildTag = "ORD",
			exp = 4321.9,
			now = 50,
		})
		T.expect(entry.key).toBe("123_2")
		T.expect(entry.sortKey).toBe(4321)
		T.expect(entry.value).toEqual({
			s = 4321,
			m = { n = "Aria", c = "Mage", g = "ORD", l = 30, u = 123, t = 50 },
			cid = "c1",
		})
		-- nothing stored -> the entry
		T.expect(Leaderboard.mergeWeekly(nil, weekly(10, "c1"))).toEqual(weekly(10, "c1"))
		-- a retry with the same total changes nothing
		T.expect(Leaderboard.mergeWeekly(weekly(10, "c1"), weekly(10, "c1"))).toEqual(weekly(10, "c1"))
		-- a later, higher total wins
		T.expect(Leaderboard.mergeWeekly(weekly(10, "c1"), weekly(25, "c1"))).toEqual(weekly(25, "c1"))
		-- an older, lower total from another server never replaces a higher one
		T.expect(Leaderboard.mergeWeekly(weekly(25, "c1"), weekly(10, "c1"))).toBeNil()
		-- a new character on the slot replaces the entry of the deleted one
		T.expect(Leaderboard.mergeWeekly(weekly(25, "c1"), weekly(3, "c2"))).toEqual(weekly(3, "c2"))
	end)

	T.it("claims the payout lock once, lets a stale lock be taken over and keeps what was sent", function()
		local record, err = Leaderboard.claimPayout(nil, "jobA", 1000, 900)
		T.expect(err).toBeNil()
		T.expect(record).toEqual({ state = "claimed", job = "jobA", at = 1000, sent = {}, winners = {} })
		local claimed =
			{ state = "claimed", job = "jobA", at = 1000, sent = { ["1_1"] = true }, winners = { { b = 1 } } }
		T.expect({ Leaderboard.claimPayout(claimed, "jobB", 1100, 900) }).toEqual({ nil, "busy" })
		local taken = Leaderboard.claimPayout(claimed, "jobB", 2000, 900)
		T.expect(taken.job).toBe("jobB")
		T.expect(taken.at).toBe(2000)
		T.expect(taken.sent).toEqual({ ["1_1"] = true })
		T.expect(taken.winners).toEqual({ { b = 1 } })
		T.expect(claimed.job).toBe("jobA")
		local again = Leaderboard.claimPayout(claimed, "jobA", 1100, 900)
		T.expect(again.job).toBe("jobA")
		T.expect(again.sent).toEqual({ ["1_1"] = true })
		T.expect({ Leaderboard.claimPayout({ state = "done" }, "jobA", 1100, 900) }).toEqual({ nil, "done" })
		local reset = Leaderboard.claimPayout({ state = "reset", at = 1 }, "jobC", 5, 900)
		T.expect(reset.state).toBe("claimed")
	end)

	T.it("plans the top three of every bracket with shards and a title until a week after the next Monday", function()
		local W = 2963
		local function e(key: string, s: number, cid: string?): { key: string, value: any }
			return { key = key, value = { s = s, m = { n = key, c = "Mage", l = 30, u = 0, t = 0 }, cid = cid } }
		end
		local tops = {
			[1] = {},
			[2] = { e("10_1", 500, "a"), e("11_1", 900, "b") },
			[3] = {
				e("20_1", 300, "c"),
				e("21_1", 0, "d"),
				e("bad", 999, "x"),
				e("22_1", 300, "e"),
				e("23_1", 300, "f"),
				e("24_1", 700, "g"),
			},
		}
		local plan = Leaderboard.payoutPlan(W, tops)
		T.expect(#plan).toBe(5)
		local untilTs = Time.weekStart(W + 1) + 7 * 86400
		local got = {}
		for _, p in plan do
			table.insert(got, { p.bracket, p.place, p.key, p.userId, p.charId, p.shards, p.title, p.untilTs, p.exp })
		end
		T.expect(got).toEqual({
			{ 2, 1, "11_1", 11, "b", 100, "weekly_diligent", untilTs, 900 },
			{ 2, 2, "10_1", 10, "a", 50, "weekly_diligent", untilTs, 500 },
			{ 3, 1, "24_1", 24, "g", 100, "weekly_diligent", untilTs, 700 },
			{ 3, 2, "20_1", 20, "c", 50, "weekly_diligent", untilTs, 300 },
			{ 3, 3, "22_1", 22, "e", 25, "weekly_diligent", untilTs, 300 },
		})
		T.expect(Leaderboard.payoutPlan(W, tops)).toEqual(plan)
		local user = Leaderboard.parseKey("123_2")
		T.expect(user).toBe(123)
		local winners = Leaderboard.winnersOf(plan)
		T.expect(winners[1]).toEqual({ b = 2, p = 1, n = "11_1", c = "Mage", l = 30, e = 900 })
		for _, w in winners do
			for key in w do
				T.expect({ key, key ~= "userId" and key ~= "key" and key ~= "charId" }).toEqual({ key, true })
			end
		end
		local rows = Leaderboard.winnerRows(winners, 3)
		T.expect(#rows).toBe(3)
		T.expect({ rows[1].r, rows[1].s, rows[1].c }).toEqual({ 1, 700, "@class.Mage.name" })
		T.expect(#Leaderboard.winnerRows(winners, 1)).toBe(0)
		T.expect(#Leaderboard.winnerRows(nil, 1)).toBe(0)
	end)

	T.it("uses the S98 week", function()
		T.expect(Leaderboard.weekEndsIn(Time.weekStart(2963))).toBe(7 * 86400)
		T.expect(Leaderboard.weekEndsIn(MONDAY + 3600)).toBe(7 * 86400 - 3600)
		T.expect(Time.weekNumber(MONDAY + 3600)).toBe(2963)
		T.expect(Leaderboard.PARTS.week({ now = MONDAY + 3600 })).toBe("2963")
		local me = Leaderboard.weekMe({ level = 50, expWeek = { week = 2963, exp = 77, b = 3 } }, {}, 2963, false)
		T.expect(me).toEqual({ s = 77, b = 3 })
		T.expect(Leaderboard.weekMe({ level = 50 }, {}, 2963, true)).toEqual({ hidden = true })
	end)

	T.it("scores a guild by its highest member levels, the older guild first on a tie", function()
		local members = {}
		for i = 1, 12 do
			members[`m{i}`] = { level = i * 5 }
		end
		T.expect(Leaderboard.guildScore(members)).toBe(15 + 20 + 25 + 30 + 35 + 40 + 45 + 50 + 55 + 60)
		T.expect(Leaderboard.guildScore({ a = { level = 10 }, b = { level = 20 }, c = { level = 7 } })).toBe(37)
		T.expect(Leaderboard.guildScore({})).toBe(0)
		T.expect(Leaderboard.guildScore(nil)).toBe(0)
		local high = Leaderboard.encodeGuild(300, 5000)
		local low = Leaderboard.encodeGuild(299, 1)
		local older = Leaderboard.encodeGuild(300, 4000)
		T.expect(high > low).toBe(true)
		T.expect(older > high).toBe(true)
		T.expect(Leaderboard.decodeGuild(high)).toBe(300)
		T.expect(Leaderboard.decodeGuild(Leaderboard.encodeGuild(0, MONDAY))).toBe(0)
		local max = Leaderboard.encodeGuild(1000, 0)
		T.expect(max < 2 ^ 53).toBe(true)
		T.expect(Leaderboard.decodeGuild(max)).toBe(1000)
		T.expect(Leaderboard.guildKey("abc")).toBe("g_abc")
		T.expect((Leaderboard.parseKey("g_abc"))).toBeNil()
		local def = Leaderboards.get("guild") :: Leaderboards.BoardDef
		local rows = Leaderboard.rows(def, { { key = "g_abc", score = high } }, function()
			return { n = "Order", g = "ORD", l = 60, m = 12, t = 0 }
		end, function()
			return false
		end, "g_abc")
		T.expect({ rows[1].s, rows[1].m, rows[1].g, rows[1].n, rows[1].mine })
			.toEqual({ 300, 12, "ORD", "Order", true })
		T.expect(Leaderboard.guildMe(nil, rows)).toEqual({ none = true })
		T.expect(Leaderboard.guildMe({ members = { a = { level = 9 } } }, rows)).toEqual({ r = 1, s = 9 })
	end)

	T.it("reads the weekly metadata from the entry itself", function()
		local def = Leaderboards.get("exp_week") :: Leaderboards.BoardDef
		local rows = Leaderboard.rows(def, {
			{ key = "5_1", score = 900, value = { n = "Week", c = "Hunter", l = 33, u = 5, t = 0 } },
		}, function()
			return { n = "Stale", c = "Mage", l = 1, t = 0 }
		end, function()
			return false
		end, nil)
		T.expect({ rows[1].n, rows[1].c, rows[1].l, rows[1].s }).toEqual({ "Week", "@class.Hunter.name", 33, 900 })
	end)

	T.it("adds the weekly and timed title fields from the template, without a migration", function()
		local template = AccountSchema.characterTemplate()
		T.expect(template.expWeek).toEqual({ week = 0, exp = 0, b = 0 })
		T.expect(template.timedTitles).toEqual({})
		T.expect(AccountSchema.CURRENT).toBe(8)
		local data: any = {
			schema = AccountSchema.CURRENT,
			characters = { ["1"] = { id = "x", name = "Old", class = "Mage", level = 40 } },
		}
		AccountSchema.migrate(data)
		T.expect(data.characters["1"].expWeek).toEqual({ week = 0, exp = 0, b = 0 })
		T.expect(data.characters["1"].timedTitles).toEqual({})
		T.expect(data.characters["1"].level).toBe(40)
	end)

	T.it("fills the weekly and guild boards for /lb fake deterministically", function()
		local a = Leaderboard.fakeWeekly(40, MONDAY)
		T.expect(a).toEqual(Leaderboard.fakeWeekly(40, MONDAY))
		local seen = {}
		for i, f in a do
			seen[f.bracket] = true
			if i > 1 then
				T.expect(f.value.s < a[i - 1].value.s).toBe(true)
			end
		end
		T.expect(seen).toEqual({ [1] = true, [2] = true, [3] = true, [4] = true })
		local g = Leaderboard.fakeGuilds(40, MONDAY)
		T.expect(#g).toBe(30)
		T.expect(g[1].key).toBe("g_fake1")
		T.expect(Leaderboard.decodeGuild(g[1].score) > Leaderboard.decodeGuild(g[2].score)).toBe(true)
	end)
end)

return nil
