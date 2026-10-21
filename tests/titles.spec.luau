--!strict
local PathData = require("../src/shared/Data/Paths")
local Quests = require("../src/shared/Data/Quests")
local TitleData = require("../src/shared/Data/Titles")
local Titles = require("../src/shared/Logic/Titles")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

-- S138: a character whose leading direction (Logic/Paths.mainOf) is `pathId`: rows of that real path filled bottom-up
-- (first node of a choice row) up to MAIN_MIN_POINTS ranks; nil = no ranks (no leading direction).
local function leading(pathId: string?, title: string?): any
	local path = if pathId then PathData.get(pathId) else nil
	local nodes: { [string]: number } = {}
	local have = 0
	if path then
		for _, row in path.rows do
			for _, node in row.nodes do
				if have < PathData.MAIN_MIN_POINTS then
					nodes[node.id] = node.maxRank
					have += node.maxRank
				end
				if row.choice then
					break
				end
			end
		end
	end
	return {
		class = if path then path.class else "Mage",
		level = 100,
		title = title,
		path = { nodes = nodes, bp = {} },
	}
end

local function character(level: number, mainDone: number, kills: number, duels: number): any
	return {
		level = level,
		quests = { mainDone = mainDone },
		pvp = { kills = kills, deaths = 0, duelsWon = duels, duelsLost = 0 },
	}
end

T.describe("Titles", function()
	T.it("a fresh character has none", function()
		T.expect(#Titles.unlocked(character(1, 0, 0, 0))).toBe(0)
	end)

	T.it("unlocks by level, story, duels and PvP kills", function()
		local list = Titles.unlocked(character(50, 10, 10, 10))
		local set = {}
		for _, id in list do
			set[id] = true
		end
		T.expect(set.wanderer).toBe(true)
		T.expect(set.veteran).toBe(true)
		T.expect(set.champion).toBeNil()
		T.expect(set.sentinel).toBe(true)
		T.expect(set.duelist).toBe(true)
		T.expect(set.bloodied).toBe(true)
		T.expect(set.warlord).toBeNil()
	end)

	T.it("shows the chosen title only while unlocked", function()
		local c = character(30, 0, 0, 0)
		c.title = "adventurer"
		T.expect(Titles.shown(c)).toBe("adventurer")
		c.title = "legend"
		T.expect(Titles.shown(c)).toBeNil()
		c.title = "nope"
		T.expect(Titles.shown(c)).toBeNil()
	end)

	-- S102 (B6): story titles follow the quest positions, so story insertions never move their meaning
	T.it("the story title needs Vaelgrath", function()
		local def = TitleData.get("dragonbane")
		T.expect(def and def.req.value).toBe(Quests.Main.indexOf.vaelgrath)
	end)

	-- S105: Dragonbane exactly from vaelgrath; the finale's title from firstSpring, in the same shape
	T.it("dragonbane from vaelgrath, thornbearer from firstSpring (S105)", function()
		local Main = Quests.Main
		local function done(n: number): any
			return character(100, n, 0, 0)
		end
		T.expect(Titles.isUnlocked(done(Main.indexOf.vaelgrath - 1), "dragonbane")).toBe(false)
		T.expect(Titles.isUnlocked(done(Main.indexOf.vaelgrath), "dragonbane")).toBe(true)
		T.expect(Titles.isUnlocked(done(Main.indexOf.firstSpring - 1), "thornbearer")).toBe(false)
		T.expect(Titles.isUnlocked(done(Main.indexOf.firstSpring), "thornbearer")).toBe(true)
		local def = assert(TitleData.get("thornbearer"))
		T.expect(def.req).toEqual({ kind = "mainDone", value = Main.indexOf.firstSpring })
		T.expect(def.wiki).toBeNil() -- S109: published on the wiki
		-- right after Dragonbane on the list
		local at: { [string]: number } = {}
		for i, t in TitleData.list do
			at[t.id] = i
		end
		T.expect(at.thornbearer).toBe(at.dragonbane + 1)
		T.expect(en["title.thornbearer"] ~= nil and pl["title.thornbearer"] ~= nil).toBe(true)
	end)

	T.it("sentinel = the tutorial", function()
		local def = TitleData.get("sentinel")
		T.expect(def and def.req.value).toBe(Quests.Main.indexOf.herbs)
	end)

	T.it("ids are unique and every title has a colour", function()
		local seen = {}
		for _, def in TitleData.list do
			T.expect(seen[def.id]).toBeNil()
			seen[def.id] = true
			T.expect(string.match(def.color, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
			T.expect(def.nameKey).toBe(`title.{def.id}`)
		end
	end)
end)

T.describe("Path titles (S59; S138: the leading direction)", function()
	-- two real Mage directions under test titles (Titles reads the leading direction through Logic/Paths)
	local LIST: { any } = {
		{ id = "wanderer", nameKey = "title.wanderer", req = { kind = "level", value = 10 }, color = "#FFFFFF" },
		{
			id = "path_a",
			nameKey = "title.path_a",
			req = { kind = "mainPath", path = "destroyer" },
			color = "#FFFFFF",
		},
		{
			id = "path_b",
			nameKey = "title.path_b",
			req = { kind = "mainPath", path = "arcanist" },
			color = "#FFFFFF",
		},
	}

	local function hero(main: string?, title: string?): any
		return leading(main, title)
	end

	T.it("the leading direction's title shows when nothing was chosen", function()
		local c = hero("destroyer", nil)
		T.expect(Titles.shown(c, LIST)).toBe("path_a")
		local set = {}
		for _, id in Titles.unlocked(c, LIST) do
			set[id] = true
		end
		T.expect(set.wanderer).toBe(true)
		T.expect(set.path_a).toBe(true)
		T.expect(set.path_b).toBeNil()
		-- below MAIN_MIN_POINTS no direction leads: no path title
		local thin = hero("destroyer", nil)
		for id in thin.path.nodes do
			thin.path.nodes[id] = nil
			break
		end
		T.expect(Titles.shown(thin, LIST)).toBeNil()
	end)

	T.it("a choice, a hidden title and a choice that is no longer unlocked", function()
		T.expect(Titles.shown(hero("destroyer", "wanderer"), LIST)).toBe("wanderer")
		T.expect(Titles.shown(hero("destroyer", Titles.NONE), LIST)).toBeNil()
		local c = hero("destroyer", "path_a")
		T.expect(Titles.shown(c, LIST)).toBe("path_a")
		-- the Arcanist leads now: the chosen Destroyer title locks and falls back to the Arcanist's
		local other = hero("arcanist", "path_a")
		T.expect(Titles.isUnlocked(other, "path_a", LIST)).toBe(false)
		T.expect(Titles.shown(other, LIST)).toBe("path_b")
		T.expect(Titles.shown(hero(nil, nil), LIST)).toBeNil()
		T.expect(Titles.shown({ level = 30 }, LIST)).toBeNil()
		T.expect(Titles.pathTitle({ level = 30 }, LIST)).toBeNil()
	end)

	T.it("game titles and paths point at each other", function()
		for _, def in TitleData.list do
			T.expect(def.id ~= Titles.NONE).toBe(true)
			local req: any = def.req
			if req.kind == "mainPath" then
				local path = PathData.byId[req.path]
				T.expect({ id = def.id, ok = path ~= nil and path.titleId == def.id })
					.toEqual({ id = def.id, ok = true })
			end
		end
		for _, path in PathData.list do
			local def = TitleData.get(path.titleId)
			local req: any = def and def.req
			T.expect({ path = path.id, ok = req ~= nil and req.kind == "mainPath" and req.path == path.id }).toEqual({
				path = path.id,
				ok = true,
			})
			local key = `title.{path.titleId}`
			T.expect({ key = key, ok = (pl :: any)[key] ~= nil and (en :: any)[key] ~= nil }).toEqual({
				key = key,
				ok = true,
			})
		end
	end)
end)

T.describe("VIP title (S121)", function()
	local function hero(main: string?, title: string?): any
		return leading(main, title)
	end

	local function has(list: { string }, id: string): boolean
		return table.find(list, id) ~= nil
	end

	T.it("is unlocked only with the VIP context", function()
		local c = hero(nil, nil)
		T.expect(has(Titles.unlocked(c), "vip")).toBe(false)
		T.expect(has(Titles.unlocked(c, nil, { vip = false }), "vip")).toBe(false)
		T.expect(has(Titles.unlocked(c, nil, { vip = true }), "vip")).toBe(true)
		T.expect(Titles.isUnlocked(c, "vip")).toBe(false)
		T.expect(Titles.isUnlocked(c, "vip", nil, { vip = true })).toBe(true)
		local def = TitleData.get("vip")
		T.expect(def ~= nil and def.wiki == nil).toBe(true) -- S131: published with the VIP article
		T.expect((pl :: any)["title.vip"] ~= nil and (en :: any)["title.vip"] ~= nil).toBe(true)
	end)

	T.it("a chosen VIP title falls back to the path title when VIP ends", function()
		local withPath = hero(nil, "vip")
		T.expect(Titles.shown(withPath, nil, { vip = true })).toBe("vip")
		T.expect(Titles.shown(withPath, nil, { vip = false })).toBeNil()
		T.expect(Titles.shown(withPath)).toBeNil()
		local first = PathData.list[1]
		if first then
			local c = hero(first.id, "vip")
			T.expect(Titles.shown(c, nil, { vip = false })).toBe(first.titleId)
		end
	end)
end)

T.describe("Timed titles (S125)", function()
	local NOW = 1791763200

	local function timed(untilTs: number?, title: string?): any
		return {
			level = 1,
			title = title,
			timedTitles = if untilTs then { weekly_diligent = untilTs } else {},
			path = { nodes = {}, bp = {} },
		}
	end

	T.it("unlocks a timed title while its term is in the future", function()
		local def = TitleData.get("weekly_diligent") :: TitleData.TitleDef
		T.expect(def.req.kind).toBe("timed")
		T.expect(Titles.isUnlocked(timed(NOW + 10), "weekly_diligent", nil, { now = NOW })).toBe(true)
		T.expect(Titles.isUnlocked(timed(NOW - 1), "weekly_diligent", nil, { now = NOW })).toBe(false)
		T.expect(Titles.isUnlocked(timed(NOW), "weekly_diligent", nil, { now = NOW })).toBe(false)
		T.expect(Titles.isUnlocked(timed(nil), "weekly_diligent", nil, { now = NOW })).toBe(false)
		T.expect(Titles.isUnlocked({ level = 1 }, "weekly_diligent", nil, { now = NOW })).toBe(false)
		T.expect(table.find(Titles.unlocked(timed(NOW + 10), nil, { now = NOW }), "weekly_diligent") ~= nil).toBe(true)
		T.expect(Titles.timedUntil(timed(NOW + 10), "weekly_diligent")).toBe(NOW + 10)
		T.expect(Titles.timedUntil(timed(nil), "weekly_diligent")).toBeNil()
		T.expect(Titles.contextOf(nil, false, NOW).now).toBe(NOW)
	end)

	T.it("a chosen expired timed title falls back to the path title", function()
		local c = timed(NOW - 5, "weekly_diligent")
		T.expect(Titles.shown(timed(NOW + 5, "weekly_diligent"), nil, { now = NOW })).toBe("weekly_diligent")
		T.expect(Titles.shown(c, nil, { now = NOW })).toBe(Titles.pathTitle(c))
	end)

	T.it("grants the later term and prunes only expired entries, never touching the input", function()
		local before = { weekly_diligent = NOW + 100, other = NOW - 1 }
		local granted = Titles.grantTimed(before, "weekly_diligent", NOW + 50)
		T.expect(granted.weekly_diligent).toBe(NOW + 100)
		T.expect(Titles.grantTimed(before, "weekly_diligent", NOW + 500).weekly_diligent).toBe(NOW + 500)
		T.expect(before.weekly_diligent).toBe(NOW + 100)
		T.expect(Titles.grantTimed(nil, "weekly_diligent", NOW)).toEqual({ weekly_diligent = NOW })
		local kept, removed = Titles.pruneTimed(before, NOW)
		T.expect(kept).toEqual({ weekly_diligent = NOW + 100 })
		T.expect(removed).toBe(true)
		local same, none = Titles.pruneTimed(kept, NOW)
		T.expect(same).toEqual(kept)
		T.expect(none).toBe(false)
		T.expect(before.other).toBe(NOW - 1)
	end)

	T.it("every timed title has its name and is on the wiki since S131", function()
		for _, def in TitleData.list do
			if def.req.kind == "timed" then
				T.expect({ def.id, pl[def.nameKey] ~= nil, en[def.nameKey] ~= nil }).toEqual({ def.id, true, true })
				T.expect({ def.id, def.wiki }).toEqual({ def.id, nil })
			end
		end
	end)
end)

T.describe("S128 arena season titles", function()
	T.it("unlocks a season title from character.arena.titles and names its season", function()
		T.expect(Titles.isUnlocked({ level = 50 }, "arena_gold")).toBe(false)
		local c: any = { level = 50, arena = { titles = { gold = "202611" } } }
		T.expect(Titles.isUnlocked(c, "arena_gold")).toBe(true)
		T.expect(Titles.isUnlocked(c, "arena_silver")).toBe(false)
		T.expect(Titles.argsOf(c, "arena_gold")).toEqual({ season = "202611" })
		T.expect(Titles.argsOf(c, "wanderer")).toBeNil()
		T.expect(Titles.argsOf(c, "arena_master")).toBeNil()
		local listed = Titles.unlocked(c)
		T.expect(table.find(listed, "arena_gold") ~= nil).toBe(true)
	end)

	T.it("every season title carries {season} in both languages, a plain name and stays off the wiki", function()
		local n = 0
		for _, def in TitleData.list do
			if def.seasonArg then
				n += 1
				for _, lang in { pl, en } do
					local text = lang[def.nameKey]
					T.expect({ def.id, text ~= nil and string.find(text, "{season}", 1, true) ~= nil }).toEqual({
						def.id,
						true,
					})
					T.expect({ def.id, lang[`{def.nameKey}.plain`] ~= nil }).toEqual({ def.id, true })
				end
			end
			if def.req.kind == "arenaSeason" then
				T.expect({ def.id, def.wiki, def.seasonArg }).toEqual({ def.id, nil, true }) -- S131: published
			end
		end
		T.expect(n).toBe(5)
	end)
end)

-- S151: achievement titles (req.kind "achievement"): a character achievement from character.ach.done, an account one
-- from the context (account.ach.done through Titles.contextOf)
T.describe("Achievement titles (S151)", function()
	T.it("a character achievement unlocks its title on that character only", function()
		local c = character(80, 0, 0, 0)
		T.expect(Titles.isUnlocked(c, "ach_elusive")).toBe(false)
		c.ach = { c = {}, s = {}, done = { dodge3 = 1700000000 } }
		T.expect(Titles.isUnlocked(c, "ach_elusive")).toBe(true)
		T.expect(Titles.isUnlocked(character(80, 0, 0, 0), "ach_elusive")).toBe(false)
	end)

	T.it("an account achievement unlocks its title for every character of the account", function()
		local account = { cosmetics = { owned = {} }, ach = { c = {}, s = {}, done = { worldBoss1 = 1 }, paid = {} } }
		local ctx = Titles.contextOf(account, false)
		T.expect(Titles.isUnlocked(character(1, 0, 0, 0), "ach_ancestorbane", nil, ctx)).toBe(true)
		T.expect(Titles.isUnlocked(character(1, 0, 0, 0), "ach_ancestorbane")).toBe(false)
		T.expect(Titles.isUnlocked(character(1, 0, 0, 0), "ach_ancestorbane", nil, Titles.contextOf({}, false)))
			.toBe(false)
	end)

	T.it("every achievement title names an achievement with that title as reward, stays off the wiki", function()
		local Achievements = require("../src/shared/Data/Achievements")
		local n = 0
		for _, def in TitleData.list do
			if def.req.kind == "achievement" then
				n += 1
				local ach = Achievements.get((def.req :: any).id)
				T.expect({ def.id, ach ~= nil and ach.reward ~= nil and ach.reward.title }).toEqual({ def.id, def.id })
				T.expect({ def.id, def.wiki }).toEqual({ def.id, false })
				T.expect({ def.id, pl[def.nameKey] ~= nil, en[def.nameKey] ~= nil }).toEqual({ def.id, true, true })
			end
		end
		T.expect(n).toBe(11) -- S151: 7, S151c: + 4 bestiary regions
	end)

	T.it("the old level, story, duel and PvP titles keep their requirements", function()
		local kinds = {
			wanderer = "level",
			adventurer = "level",
			veteran = "level",
			champion = "level",
			legend = "level",
			sentinel = "mainDone",
			dragonbane = "mainDone",
			thornbearer = "mainDone",
			duelist = "duelsWon",
			gladiator = "duelsWon",
			bloodied = "pvpKills",
			warlord = "pvpKills",
		}
		for id, kind in kinds do
			local def = TitleData.get(id)
			T.expect({ id, def and def.req.kind }).toEqual({ id, kind })
		end
	end)
end)

return nil
