--!strict
-- UI plan phase 3 (Studio review 2026-10-31: the backpack window did three jobs at two thirds of the screen): the
-- window's tabs (Logic/CharacterTabs). The equipment and backpack, the statistics, and the sets and title once they
-- mean something; the window is the backpack tab's width.
local fs = require("@lune/fs")

local T = require("./Test")
local CharacterTabs = require("../src/shared/Logic/CharacterTabs")
local Progression = require("../src/shared/Data/Progression")

local function read(path: string): string
	return fs.readFile(path)
end

T.describe("Backpack window tabs (UI plan phase 3)", function()
	T.it("a fresh character sees the equipment and the statistics only", function()
		T.expect(CharacterTabs.setsShown(1, 1)).toBe(false)
		T.expect(CharacterTabs.titlesShown(0)).toBe(false)
		T.expect(CharacterTabs.tabs(false, false)).toEqual({ "backpack", "stats" })
	end)

	T.it("the build sets come with the paid refunds, or stay while the second set is worn", function()
		T.expect(CharacterTabs.SETS_LEVEL).toBe(Progression.freeRespecLevel)
		T.expect(CharacterTabs.setsShown(CharacterTabs.SETS_LEVEL - 1, 1)).toBe(false)
		T.expect(CharacterTabs.setsShown(CharacterTabs.SETS_LEVEL, 1)).toBe(true)
		T.expect(CharacterTabs.setsShown(5, 2)).toBe(true)
		T.expect(CharacterTabs.setsShown(nil, nil)).toBe(false)
	end)

	T.it("the third tab says what it holds", function()
		T.expect(CharacterTabs.titlesShown(1)).toBe(true)
		T.expect(CharacterTabs.tabs(true, false)).toEqual({ "backpack", "stats", "sets" })
		T.expect(CharacterTabs.tabs(false, true)).toEqual({ "backpack", "stats", "sets" })
		T.expect(CharacterTabs.setsLabel(true, true)).toBe("character.tab.setsTitles")
		T.expect(CharacterTabs.setsLabel(true, false)).toBe("character.tab.sets")
		T.expect(CharacterTabs.setsLabel(false, true)).toBe("character.tab.titles")
		local pl = require("../src/shared/Data/Localization/pl") :: any
		local en = require("../src/shared/Data/Localization/en") :: any
		for _, key in
			{ "character.tab.setsTitles", "character.tab.sets", "character.tab.titles", "character.tab.statsPoints" }
		do
			T.expect(type(pl[key])).toBe("string")
			T.expect(type(en[key])).toBe("string")
		end
	end)

	T.it("a tab that went away hands its place to the backpack", function()
		local two = CharacterTabs.tabs(false, false)
		T.expect(CharacterTabs.pick("stats", two)).toBe("stats")
		T.expect(CharacterTabs.pick("sets", two)).toBe("backpack")
		T.expect(CharacterTabs.pick(nil, two)).toBe("backpack")
		T.expect(CharacterTabs.pick("sets", CharacterTabs.tabs(true, false))).toBe("sets")
	end)

	T.it("the path suggestion shows only with free points and a plan", function()
		T.expect(CharacterTabs.suggestShown(0, true)).toBe(false)
		T.expect(CharacterTabs.suggestShown(nil, true)).toBe(false)
		T.expect(CharacterTabs.suggestShown(3, false)).toBe(false)
		T.expect(CharacterTabs.suggestShown(3, true)).toBe(true)
	end)

	T.it("one job per view: the sets and the title left the equipment column", function()
		local src = read("src/client/UI/Screens/CharacterWindow/init.luau")
		local hero = assert(string.match(src, "local function heroColumn(.-)\nend\n"))
		T.expect(string.find(hero, "BuildSetSwitch", 1, true)).toBe(nil)
		T.expect(string.find(hero, "TitleChooser", 1, true)).toBe(nil)
		for _, page in { '"BackpackTab", "backpack"', '"StatsTab", "stats"', '"SetsTab", "sets"' } do
			T.expect(string.find(src, page, 1, true) ~= nil).toBe(true)
		end
		local alloc = read("src/client/UI/Screens/CharacterWindow/StatAllocator.luau")
		T.expect(string.find(alloc, "Visible = suggestOn", 1, true) ~= nil).toBe(true)
	end)

	T.it("the window is the backpack tab's width, about 43% of a 1920 screen", function()
		local src = read("src/client/Controllers/ScreenController.luau")
		local w, h = string.match(src, 'id = "character",.-size = Vector2%.new%((%d+), (%d+)%)')
		local width, height = tonumber(w) or 0, tonumber(h) or 0
		T.expect(width).toBe(260 + 22 + 500 + 2 * 22)
		T.expect(width < 1240 * 0.7).toBe(true)
		T.expect(height <= 760).toBe(true)
	end)
end)

return nil
