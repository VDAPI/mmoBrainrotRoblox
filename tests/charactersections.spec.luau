--!strict
-- Owner 2026-11-10 ("a lot of text, some things cover others, nothing can be collapsed"; the tabs of UI plan phase 3
-- are gone): the backpack window holds the equipment, the backpack and the statistics in one view again, and its
-- secondary parts fold (Logic/CharacterSections, UI/Components/Section): the statistics stand open, the sets and title
-- show once they mean something and fold to one line.
local fs = require("@lune/fs")

local T = require("./Test")
local CharacterSections = require("../src/shared/Logic/CharacterSections")
local GearLayout = require("../src/shared/Logic/GearLayout")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
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
		-- owner 2026-11-10 (UI plan): the derived statistics in four sections, the attack ones open
		T.expect(SectionFold.isOpen(nil, "charOffense")).toBe(true)
		for _, id in { "charDefense", "charResources", "charOther" } do
			T.expect({ id, SectionFold.known(id), SectionFold.isOpen(nil, id) }).toEqual({ id, true, false })
		end
	end)

	T.it("the derived statistics: one section per group, names on up to two lines, never cut", function()
		local list = read("src/client/UI/Screens/CharacterWindow/DerivedList.luau")
		for _, id in { "charOffense", "charDefense", "charResources", "charOther" } do
			T.expect({ id, string.find(list, `"{id}"`, 1, true) ~= nil }).toEqual({ id, true })
		end
		T.expect(string.find(list, "Section.new(", 1, true) ~= nil).toBe(true)
		T.expect(string.find(list, "TextTruncate", 1, true)).toBeNil()
		T.expect(string.find(list, "TextWrapped = true", 1, true) ~= nil).toBe(true)
	end)

	T.it("a stat is one line with its effect behind the i; the buttons and the points only with free points", function()
		local alloc = read("src/client/UI/Screens/CharacterWindow/StatAllocator.luau")
		-- no second line under the name: what a stat raises is behind the (i)
		T.expect(string.find(alloc, 'Name = "Desc"', 1, true)).toBeNil()
		T.expect(string.find(alloc, "InfoTip.new(", 1, true) ~= nil).toBe(true)
		-- the -/+ controls and "Wolne punkty" follow the free points
		T.expect(string.find(alloc, "Visible = hasPoints", 1, true) ~= nil).toBe(true)
		T.expect(string.find(alloc, "local controlsOn = hasPoints", 1, true) ~= nil).toBe(true)
		local _, steps = string.gsub(alloc, "\n%s*controlsOn\n%s*%)", "")
		T.expect(steps).toBe(2) -- the - and the + button
		-- the backpack's overflow line is Small 17, never scaled
		local panel = read("src/client/UI/Screens/BackpackPanel.luau")
		T.expect(string.find(panel, "TextScaled", 1, true)).toBeNil()
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

	T.it(
		"touch: columns from the content width; three on a wide tablet, two on a phone with a 500-px backpack",
		function()
			local L = CharacterSections.LAYOUT
			-- owner 2026-11-10 (UI plan): the width is the window's content (WindowFrame.content), not the screen's
			-- a 1280 wide tablet (1236 of content): three columns, one-line rows; a 1210 one: two-line rows
			T.expect(CharacterSections.columns(true, 1236)).toEqual({ wide = true, left = L.left, compact = false })
			T.expect(CharacterSections.columns(true, 1166)).toEqual({ wide = true, left = L.left, compact = true })
			-- the three phones (safe-area insets left out, a 58-px top bar, the compact title bar): two columns and the
			-- backpack keeps its 500 (the audit's 428 on 844x390 came from the screen's width)
			for _, device in PhoneHud.DEVICES do
				local w, h = PhoneHud.area(device)
				local area = GearLayout.area({ w = w, h = h }, { w = 1240, h = 720 }, true, 58, true)
				local columns = CharacterSections.columns(true, area.w)
				T.expect({ device.name, columns.wide }).toEqual({ device.name, false })
				T.expect({ device.name, area.w - columns.left - L.narrowGutter >= L.middle })
					.toEqual({ device.name, true })
			end
			-- a 16:9 phone (667 x 375, 760 of content): the stat rows go on two lines
			local small = CharacterSections.columns(true, 760)
			T.expect(small.wide).toBe(false)
			T.expect(small.compact).toBe(true)
			-- never narrower than the equipment with touch slots (3 x 56 + 2 x 8)
			T.expect(CharacterSections.columns(true, 556).left >= 3 * 56 + 2 * 8).toBe(true)
			-- the window takes its numbers from GearLayout, measured from its content, never from the screen
			local src = read(WINDOW)
			T.expect(string.find(src, "GearLayout.character(", 1, true) ~= nil).toBe(true)
			T.expect(string.find(src, '[Out("AbsoluteSize")]', 1, true) ~= nil).toBe(true)
			T.expect(string.find(src, "Scale.VirtualSize", 1, true)).toBeNil()
			T.expect(string.find(src, "Compact = compact", 1, true) ~= nil).toBe(true)
			-- the paddings are Theme's (Padding.Large and Medium)
			local theme = read("src/client/UI/Theme.luau")
			local at = assert(string.find(theme, "Theme.Padding = {", 1, true))
			local large = tonumber(string.match(theme, "Large = (%d+)", at))
			local medium = tonumber(string.match(theme, "Medium = (%d+)", at))
			T.expect(L.pad).toBe(large)
			T.expect(L.gutter).toBe(large)
			T.expect(L.narrowGutter).toBe(medium)
		end
	)
end)

return nil
