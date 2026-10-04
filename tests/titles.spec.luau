--!strict
local Quests = require("../src/shared/Data/Quests")
local TitleData = require("../src/shared/Data/Titles")
local Titles = require("../src/shared/Logic/Titles")
local T = require("./Test")

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
