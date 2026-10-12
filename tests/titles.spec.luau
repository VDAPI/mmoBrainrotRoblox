--!strict
local PathData = require("../src/shared/Data/Paths")
local Quests = require("../src/shared/Data/Quests")
local TitleData = require("../src/shared/Data/Titles")
local Titles = require("../src/shared/Logic/Titles")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

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

	T.it("the story title needs the whole main line", function()
		local def = TitleData.get("dragonbane")
		T.expect(def and def.req.value).toBe(#Quests.Main.list)
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

T.describe("Path titles (S59)", function()
	local LIST: { any } = {
		{ id = "wanderer", nameKey = "title.wanderer", req = { kind = "level", value = 10 }, color = "#FFFFFF" },
		{
			id = "path_fxStorm",
			nameKey = "title.path_fxStorm",
			req = { kind = "mainPath", path = "fxStorm" },
			color = "#FFFFFF",
		},
		{
			id = "path_fxRune",
			nameKey = "title.path_fxRune",
			req = { kind = "mainPath", path = "fxRune" },
			color = "#FFFFFF",
		},
	}

	local function hero(main: string?, title: string?): any
		return { level = 30, title = title, path = { main = main, nodes = {}, bp = {}, freeUsed = true } }
	end

	T.it("the main path title shows when nothing was chosen", function()
		local c = hero("fxStorm", nil)
		T.expect(Titles.shown(c, LIST)).toBe("path_fxStorm")
		local set = {}
		for _, id in Titles.unlocked(c, LIST) do
			set[id] = true
		end
		T.expect(set.wanderer).toBe(true)
		T.expect(set.path_fxStorm).toBe(true)
		T.expect(set.path_fxRune).toBeNil()
	end)

	T.it("a choice, a hidden title and a choice that is no longer unlocked", function()
		T.expect(Titles.shown(hero("fxStorm", "wanderer"), LIST)).toBe("wanderer")
		T.expect(Titles.shown(hero("fxStorm", Titles.NONE), LIST)).toBeNil()
		local c = hero("fxStorm", "path_fxStorm")
		T.expect(Titles.shown(c, LIST)).toBe("path_fxStorm")
		c.path.main = "fxRune"
		T.expect(Titles.shown(c, LIST)).toBe("path_fxRune")
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
