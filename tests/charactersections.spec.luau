--!strict
-- Owner 2026-11-10 ("a lot of text, some things cover others, nothing can be collapsed"; the tabs of UI plan phase 3
-- are gone): the backpack window holds the equipment, the backpack and the statistics in one view again, and its
-- secondary parts fold (Logic/CharacterSections, UI/Components/Section): the statistics stand open, the sets and title
-- show once they mean something and fold to one line.
local fs = require("@lune/fs")

local T = require("./Test")
local CharacterSections = require("../src/shared/Logic/CharacterSections")
local Progression = require("../src/shared/Data/Progression")
local SectionFold = require("../src/shared/Logic/SectionFold")

local pl = require("../src/shared/Data/Localization/pl") :: any
local en = require("../src/shared/Data/Localization/en") :: any

local function read(path: string): string
	return fs.readFile(path)
end

local WINDOW = "src/client/UI/Screens/CharacterWindow/init.luau"

T.describe("Backpack window sections", function()
	T.it("a fresh character sees the equipment, the backpack and the statistics; the sets wait", function()
		T.expect(CharacterSections.setsShown(1, 1)).toBe(false)
		T.expect(CharacterSections.titlesShown(0)).toBe(false)
		T.expect(CharacterSections.setsLabel(false, false)).toBeNil()
	end)

	T.it("the build sets come with the paid refunds, or stay while the second set is worn", function()
		T.expect(CharacterSections.SETS_LEVEL).toBe(Progression.freeRespecLevel)
		T.expect(CharacterSections.setsShown(CharacterSections.SETS_LEVEL - 1, 1)).toBe(false)
		T.expect(CharacterSections.setsShown(CharacterSections.SETS_LEVEL, 1)).toBe(true)
		T.expect(CharacterSections.setsShown(5, 2)).toBe(true)
		T.expect(CharacterSections.setsShown(nil, nil)).toBe(false)
	end)

	T.it("the sets section's title says what it holds", function()
		T.expect(CharacterSections.titlesShown(1)).toBe(true)
		T.expect(CharacterSections.setsLabel(true, true)).toBe("character.section.setsTitle")
		T.expect(CharacterSections.setsLabel(true, false)).toBe("character.section.sets")
		T.expect(CharacterSections.setsLabel(false, true)).toBe("character.section.title")
		for _, key in
			{
				"character.section.stats",
				"character.section.sets",
				"character.section.title",
				"character.section.setsTitle",
				"character.section.noTitle",
				"character.pointsLeft",
				"character.sets.hint",
				"title.none.hint",
				"buildset.set",
			}
		do
			T.expect(type(pl[key])).toBe("string")
			T.expect(type(en[key])).toBe("string")
		end
	end)

	T.it("folded, the statistics show the free points and nothing without any", function()
		T.expect(CharacterSections.pointsBadge(3)).toBe(3)
		T.expect(CharacterSections.pointsBadge(0)).toBeNil()
		T.expect(CharacterSections.pointsBadge(nil)).toBeNil()
	end)

	T.it("folded, the sets and title section is one line: the active set and the worn title", function()
		T.expect(CharacterSections.setsSummary(true, true, 2, "slayer")).toEqual({
			{ key = "buildset.set", args = { n = 2 } },
			{ title = "slayer" },
		})
		T.expect(CharacterSections.setsSummary(true, false, nil, nil)).toEqual({
			{ key = "buildset.set", args = { n = 1 } },
		})
		T.expect(CharacterSections.setsSummary(false, true, 1, nil)).toEqual({ { key = "character.section.noTitle" } })
		T.expect(CharacterSections.setsSummary(false, false, 1, "slayer")).toEqual({})
	end)

	T.it("the path suggestion shows only with free points and a plan", function()
		T.expect(CharacterSections.suggestShown(0, true)).toBe(false)
		T.expect(CharacterSections.suggestShown(nil, true)).toBe(false)
		T.expect(CharacterSections.suggestShown(3, false)).toBe(false)
		T.expect(CharacterSections.suggestShown(3, true)).toBe(true)
	end)

	T.it("the statistics stand open by default, the sets fold", function()
		T.expect(SectionFold.isOpen(nil, "charStats")).toBe(true)
		T.expect(SectionFold.isOpen(nil, "charSets")).toBe(false)
	end)

	T.it("no tabs: one view with the equipment, the backpack and both sections", function()
		local src = read(WINDOW)
		T.expect(string.find(src, "Components.Tabs", 1, true)).toBeNil()
		T.expect(string.find(src, "Focus", 1, true)).toBeNil()
		for _, needle in
			{ 'Id = "charStats"', 'Id = "charSets"', "BackpackPanel(", "Equipment(", "StatAllocator(", "DerivedList(" }
		do
			T.expect(string.find(src, needle, 1, true) ~= nil).toBe(true)
		end
		-- every section the window builds has its default (the server keeps only known ids)
		for id in string.gmatch(src, 'Id = "(%w+)"') do
			T.expect(SectionFold.known(id)).toBe(true)
		end
		-- the set hint went behind the section's "i"
		local sets = assert(string.match(src, "local function setsSection(.-)\nend\n"))
		T.expect(string.find(sets, "Info =", 1, true) ~= nil).toBe(true)
		T.expect(string.find(sets, '"character.sets.hint"', 1, true) ~= nil).toBe(true)
		local alloc = read("src/client/UI/Screens/CharacterWindow/StatAllocator.luau")
		T.expect(string.find(alloc, "Visible = suggestOn", 1, true) ~= nil).toBe(true)
	end)

	T.it("the window is three columns wide again and the left column fits the open sets on PC", function()
		local L = CharacterSections.LAYOUT
		local src = read("src/client/Controllers/ScreenController.luau")
		local w, h = string.match(src, 'id = "character",.-size = Vector2%.new%((%d+), (%d+)%)')
		local width, height = tonumber(w) or 0, tonumber(h) or 0
		T.expect(width).toBe(1240)
		-- the content: the window less its title bar (52) and the padding
		local content = height - 52 - 2 * L.pad
		-- name 64, the equipment 4 x 72 + 3 x 12 with its hint (22) and Unequip (40), the sets header (32), the switch
		-- (34) and the title picker (64), 8 apart
		local leftOpen = 64 + (4 * 72 + 3 * 12 + 22 + 40) + 32 + 34 + 64 + 5 * 8
		T.expect(leftOpen <= content).toBe(true)
		T.expect(height <= 760).toBe(true)
		-- the statistics' column keeps a stat row on one line on PC
		local right = width - 2 * L.pad - (L.left + L.gutter + L.middle + L.gutter)
		T.expect(right - L.scrollPad >= L.statsOneLine).toBe(true)
		T.expect(CharacterSections.columns(false, 1920)).toEqual({ wide = true, left = L.left, compact = false })
	end)

	T.it("touch: three columns on a wide tablet, two on a phone, the stat rows on two lines when narrow", function()
		local L = CharacterSections.LAYOUT
		-- a 1280 wide tablet: three columns, one-line rows; a 1210 one (1024 x 768 at the touch scale): two-line rows
		T.expect(CharacterSections.columns(true, 1280)).toEqual({ wide = true, left = L.left, compact = false })
		T.expect(CharacterSections.columns(true, 1210)).toEqual({ wide = true, left = L.left, compact = true })
		-- a 20:9 phone (844 x 390 at 44 / 52): two columns, the left one at its widest
		local phone = CharacterSections.columns(true, 997)
		T.expect(phone).toEqual({ wide = false, left = L.narrowLeftMax, compact = false })
		-- a 16:9 phone (667 x 375): the backpack keeps its 500, the stat rows go on two lines
		local small = CharacterSections.columns(true, 788)
		T.expect(small.wide).toBe(false)
		T.expect(small.compact).toBe(true)
		T.expect(788 - 2 * L.pad - small.left - L.narrowGutter >= L.middle).toBe(true)
		-- never narrower than the equipment with touch slots (3 x 56 + 2 x 8)
		T.expect(CharacterSections.columns(true, 600).left >= 3 * 56 + 2 * 8).toBe(true)
		-- the window takes its numbers from here
		local src = read(WINDOW)
		T.expect(string.find(src, "CharacterSections.columns(touch, size.X)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(src, "Compact = compact", 1, true) ~= nil).toBe(true)
		-- the paddings are Theme's (Padding.Large and Medium)
		local theme = read("src/client/UI/Theme.luau")
		local at = assert(string.find(theme, "Theme.Padding = {", 1, true))
		local large = tonumber(string.match(theme, "Large = (%d+)", at))
		local medium = tonumber(string.match(theme, "Medium = (%d+)", at))
		T.expect(L.pad).toBe(large)
		T.expect(L.gutter).toBe(large)
		T.expect(L.narrowGutter).toBe(medium)
	end)
end)

return nil
