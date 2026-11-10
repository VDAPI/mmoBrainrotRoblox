--!strict
-- Owner 2026-10-22 (Studio: text that did not fit its box: a "◆" alone on a second line, heads of one row in three
-- sizes, a glyph cut in its button, a word broken letter by letter): one-line text widths estimated without
-- TextService against the boxes the text sits in. The estimate (Builder Sans) is generous on purpose, so a pass here
-- leaves room in Studio: a letter, digit or mark LETTER of the text size, a space SPACE, a symbol beyond Latin
-- (◆ ▶ ▣) a full em. The model lives in Logic/TextCaps.width (2026-11-10), shared with the text caps of textcaps.spec.
--   F1 every Button with a literal offset size and a literal text holds it on one line, its side padding included
--      (Components/Button: Theme.Padding.Tiny under NARROW, else Medium)
--   F2 the Portal Master's price buttons hold every label on one line, at every price, in both languages
--   F3 the skill tree's column heads: one text size (no TextScaled), room for every role name (PoolTree.HEAD_WIDTH)
--   F4 the login reward card: no word of the chest line is wider than the PC card's room beside its "i"
--   Owner 2026-11-10 ("too much text, things covering each other"), UI package C:
--   F5 a tab row takes one look for all its tabs, the first of WindowFrame.TAB_LEVELS that fits its strip, and past
--      the last one the strip scrolls sideways (the quest journal's "Tygodniowe" stood past the strip's end)
--   F6 a Button, a tab and a side tab keep their label on one line (no wrapping, no scaled text)
--   F7 (review 2026-11-10: the tabs had come out 42 px) a tab is as tall as its strip less the scroll bar's room, 44 by
--      default, a touch screen's ◂ / ▸ is a whole touch target, and the selected tab scrolls clear of them

local fs = require("@lune/fs")

local Locale = require("../src/shared/Util/Locale")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local PortalData = require("../src/shared/Data/PortalShop")
local T = require("./Test")
local TextCaps = require("../src/shared/Logic/TextCaps")
local WindowFrame = require("../src/shared/Logic/WindowFrame")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = T.describe, T.it, T.expect

local LANGS = { "pl", "en" }
local width = TextCaps.width

local function read(path: string): string
	return fs.readFile(path)
end

-- `Name = <digits>` pairs of a `<prefix> = {` table in Theme.luau.
local function tokens(prefix: string): { [string]: number }
	local source = read("src/client/UI/Theme.luau")
	local start = string.find(source, prefix .. " = {", 1, true)
	assert(start, prefix)
	local stop = string.find(source, "\n}", start, true)
	local out: { [string]: number } = {}
	for name, value in string.gmatch(string.sub(source, start, stop), "(%w+) = (%d+)") do
		out[name] = tonumber(value) :: number
	end
	return out
end

local function number(path: string, pattern: string): number
	local value = string.match(read(path), pattern)
	assert(value, `{path}: {pattern}`)
	return tonumber(value) :: number
end

local TEXT = tokens("Theme.TextSize")
local PADDING = tokens("Theme.Padding")

local function files(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local full = `{dir}/{name}`
		if fs.isDir(full) then
			files(full, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, full)
		end
	end
end

type Call = { file: string, line: number, w: number, h: number, text: string, size: number }

-- Button(scope, { ... }) calls with a literal `Size = UDim2.fromOffset(w, h)` and a literal `Text = "..."`.
local function buttons(): { Call }
	local paths = {}
	files("src/client", paths)
	local out: { Call } = {}
	for _, path in paths do
		local source = read(path)
		local at = 1
		while true do
			local first, last = string.find(source, "Button%(%w+, {", at)
			if not first then
				break
			end
			at = last + 1
			local before = if first > 1 then string.sub(source, first - 1, first - 1) else " "
			if string.match(before, "[%w_%.]") then
				continue
			end
			local depth, i = 1, last + 1
			while depth > 0 and i <= #source do
				local c = string.sub(source, i, i)
				if c == "{" then
					depth += 1
				elseif c == "}" then
					depth -= 1
				end
				i += 1
			end
			local block = string.sub(source, last + 1, i - 1)
			local w, h = string.match(block, "\n%s*Size = UDim2%.fromOffset%((%d+), (%d+)%)")
			local text = string.match(block, '\n%s*Text = "([^"]*)"')
			if w and h and text then
				local token = string.match(block, "\n%s*TextSize = Theme%.TextSize%.(%a+)")
				local _, lines = string.gsub(string.sub(source, 1, first), "\n", "")
				table.insert(out, {
					file = path,
					line = lines + 1,
					w = tonumber(w) :: number,
					h = tonumber(h) :: number,
					text = text,
					size = TEXT[token or "Body"],
				})
			end
		end
	end
	return out
end

describe("uifit", function()
	it("F1 a Button with a literal size holds its literal text on one line", function()
		local narrow = number("src/client/UI/Components/Button.luau", "local NARROW = (%d+)")
		local calls = buttons()
		expect(#calls > 5).toBe(true)
		local bad = {}
		for _, call in calls do
			local pad = if call.w < narrow then PADDING.Tiny else PADDING.Medium
			local need = width(call.text, call.size)
			if need > call.w - 2 * pad or call.size > call.h then
				table.insert(
					bad,
					`{call.file}:{call.line} "{call.text}" needs {need} x {call.size} in {call.w} x {call.h}`
				)
			end
		end
		expect(table.concat(bad, "\n")).toBe("")
	end)

	it("F2 the Portal Master's price buttons hold every label on one line in both languages", function()
		local path = "src/client/UI/Screens/PortalShopWindow.luau"
		local buttonWidth = number(path, "local buttonWidth = (%d+)")
		local pack = number(path, "local PACK = (%d+)")
		local room = buttonWidth - 2 * PADDING.Medium
		local bad = {}
		for _, lang in LANGS do
			for _, entry in PortalData.list do
				local labels = {
					Locale.T("portalshop.buyOne", { n = 1, price = entry.piece }, lang),
					Locale.T("portalshop.buyMany", { n = pack, price = entry.piece * pack }, lang),
					Locale.T("portalshop.perm", { price = entry.perm }, lang),
					Locale.T("portalshop.claim", nil, lang),
				}
				for _, label in labels do
					if width(label, TEXT.Small) > room then
						table.insert(bad, `{lang} "{label}"`)
					end
				end
			end
			-- the "owned" plate takes the button's place without padding
			local owned = Locale.T("portalshop.owned", nil, lang)
			if width(owned, TEXT.Small) > buttonWidth then
				table.insert(bad, `{lang} "{owned}"`)
			end
		end
		expect(table.concat(bad, "\n")).toBe("")
	end)

	it("F3 the skill tree's column heads share one text size and hold every role name", function()
		local path = "src/client/UI/Screens/SkillsWindow/PoolTree.luau"
		local room = number(path, "PoolTree%.HEAD_WIDTH = (%d+)")
		for line in string.gmatch(read(path), "[^\n]+") do
			local code = string.match(line, "^(.-)%-%-") or line
			expect(string.find(code, "TextScaled", 1, true)).toBe(nil)
		end
		local count = 0
		for _, tbl in { pl, en } do
			for key, text in tbl :: { [string]: string } do
				if string.match(key, "^skills%.role%.%u$") then
					count += 1
					if width(text, TEXT.Caption) > room then
						expect(`{key} "{text}"`).toBe("fits")
					end
				end
			end
		end
		expect(count >= 14).toBe(true)
	end)

	it("F4 no word of the login chest line is wider than the PC card beside its 'i'", function()
		-- the window's content (less its padding and the scroll bar) in seven cells less the grid gap, less the card's
		-- padding, the row's gap and the "i"
		local window = number("src/client/Controllers/LoginRewardController.luau", "size = Vector2%.new%((%d+),")
		local view = read("src/client/UI/Screens/LoginReward.luau")
		expect(string.find(view, "local CHEST_TEXT = Theme.TextSize.Caption", 1, true) ~= nil).toBe(true)
		local room = (window - 2 * PADDING.Large - 4) / 7 - 8 - 2 * 6 - 4 - 20
		local bad = {}
		for _, lang in LANGS do
			for key in en :: { [string]: string } do
				local class = string.match(key, "^class%.(%w+)%.name$")
				if class then
					local line = "▣ " .. Locale.T("login.chest.short", { class = Locale.T(key, nil, lang) }, lang)
					for word in string.gmatch(line, "%S+") do
						if width(word, TEXT.Caption) > room then
							table.insert(bad, `{lang} "{word}" in "{line}"`)
						end
					end
				end
			end
		end
		expect(table.concat(bad, "\n")).toBe("")
	end)

	it("F5 a tab row fits its strip at one look for all its tabs, or the strip scrolls", function()
		-- Components/Tabs: the look from WindowFrame.tabFit, a strip that scrolls sideways
		local tabs = read("src/client/UI/Components/Tabs.luau")
		for _, needle in
			{
				"WindowFrame.tabFit(",
				'scope:New("ScrollingFrame")',
				"ScrollingDirection = Enum.ScrollingDirection.X",
				"AutomaticCanvasSize = Enum.AutomaticSize.X",
			}
		do
			if not string.find(tabs, needle, 1, true) then
				expect(`Components/Tabs: {needle}`).toBe("found")
			end
		end
		-- the quest journal's six tabs: in its PC window (QuestController's size less the window's padding and the
		-- strip's edges for the selected tab's frame) and in the narrowest phone's window
		local window = number(
			"src/client/Controllers/QuestController.luau",
			'id = "quests",%s+titleKey = "[%w%.]+",%s+size = Vector2%.new%((%d+),'
		)
		local edge = tokens("Theme.Stroke").Normal
		local pc = window - 2 * PADDING.Large - 2 * edge
		local phone = math.huge
		for _, device in PhoneHud.DEVICES do
			local w = PhoneHud.area(device)
			phone = math.min(phone, w - 2 * PADDING.Medium - 2 * edge)
		end
		local levels = WindowFrame.TAB_LEVELS
		for _, lang in LANGS do
			local labels = {}
			for _, id in { "main", "daily", "side", "contract", "boss", "weekly" } do
				table.insert(labels, Locale.T(`quest.tab.{id}`, nil, lang))
			end
			for _, room in { pc, phone } do
				local fit = WindowFrame.tabFit(labels, room)
				local want = levels[#levels]
				for _, level in levels do
					if WindowFrame.tabRow(labels, level.pad, level.size) <= room then
						want = level
						break
					end
				end
				expect({ fit.pad, fit.size }).toEqual({ want.pad, want.size })
				expect(fit.width).toBe(WindowFrame.tabRow(labels, want.pad, want.size))
				expect(fit.scroll).toBe(fit.width > room)
			end
			-- a phone's window holds the whole row
			expect(WindowFrame.tabFit(labels, phone).scroll).toBe(false)
		end
	end)

	it("F6 a Button, a tab and a side tab keep their label on one line", function()
		for _, name in { "Button", "Tabs", "SideTabs" } do
			local source = read(`src/client/UI/Components/{name}.luau`)
			expect(string.find(source, "TextWrapped = false", 1, true) ~= nil).toBe(true)
			expect(string.find(source, "TextWrapped = true", 1, true)).toBe(nil)
			expect(string.find(source, "TextScaled", 1, true)).toBe(nil)
		end
		expect(string.find(read("src/client/UI/Components/SideTabs.luau"), "Theme.Size.TabHeight", 1, true) ~= nil).toBe(
			true
		)
	end)

	it("F7 a tab is a whole touch target, its ◂ / ▸ too, and the selected tab scrolls clear of them", function()
		local size = tokens("Theme.Size")
		expect(WindowFrame.TAB_HEIGHT).toBe(size.TabHeight)
		expect(WindowFrame.TAB_EDGE).toBe(tokens("Theme.Stroke").Normal)
		expect(WindowFrame.TAB_CHEVRON_TOUCH >= size.MinTouch).toBe(true)
		-- Components/Tabs: the row's ScrollingFrame reaches `edge` above the strip and pads the row down by as much,
		-- and the bar draws in its room without an inset; a tab is the strip's height less that room
		local tabs = read("src/client/UI/Components/Tabs.luau")
		for _, needle in
			{
				"WindowFrame.tabStrip(",
				"WindowFrame.tabReveal(",
				"Position = UDim2.fromOffset(0, -EDGE)",
				"Size = UDim2.new(1, 0, 1, EDGE)",
				"PaddingTop = UDim.new(0, EDGE)",
				"HorizontalScrollBarInset = Enum.ScrollBarInset.None",
				"Size = UDim2.new(0, 0, 1, -barSpace)",
			}
		do
			if not string.find(tabs, needle, 1, true) then
				expect(`Components/Tabs: {needle}`).toBe("found")
			end
		end
		for _, scroll in { false, true } do
			local strip = WindowFrame.tabStrip(scroll)
			local tab = (strip.height + strip.edge) - strip.edge - strip.bar
			expect(tab).toBe(strip.button)
			expect(strip.button).toBe(size.TabHeight)
		end
		-- a tab past either end of a 400-wide strip scrolled at 300, revealed: clear of that end's ◂ / ▸ and the frame
		for _, chevron in { WindowFrame.TAB_CHEVRON, WindowFrame.TAB_CHEVRON_TOUCH } do
			local edge = chevron + WindowFrame.TAB_EDGE
			for _, tab in { { 380, 470 }, { 330, 395 }, { -60, 30 }, { 10, 100 } } do
				local moved = WindowFrame.tabReveal(tab[1], tab[2], 400, 300, chevron) - 300
				if tab[1] - moved < edge or tab[2] - moved > 400 - edge then
					expect(`{chevron}-px chevrons: the tab {tab[1]}-{tab[2]} ends at {tab[1] - moved}-{tab[2] - moved}`).toBe(
						"clear"
					)
				end
			end
			expect(WindowFrame.tabReveal(edge, 400 - edge, 400, 120, chevron)).toBe(120)
			expect(WindowFrame.tabReveal(5, 60, 400, 0, chevron)).toBe(0)
		end
	end)
end)
