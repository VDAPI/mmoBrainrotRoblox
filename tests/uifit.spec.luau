--!strict
-- Owner 2026-10-22 (Studio: text that did not fit its box: a "◆" alone on a second line, heads of one row in three
-- sizes, a glyph cut in its button, a word broken letter by letter): one-line text widths estimated without
-- TextService against the boxes the text sits in. The estimate (Builder Sans) is generous on purpose, so a pass here
-- leaves room in Studio: a letter, digit or mark LETTER of the text size, a space SPACE, a symbol beyond Latin
-- (◆ ▶ ▣) a full em.
--   F1 every Button with a literal offset size and a literal text holds it on one line, its side padding included
--      (Components/Button: Theme.Padding.Tiny under NARROW, else Medium)
--   F2 the Portal Master's price buttons hold every label on one line, at every price, in both languages
--   F3 the skill tree's column heads: one text size (no TextScaled), room for every role name (PoolTree.HEAD_WIDTH)
--   F4 the login reward card: no word of the chest line is wider than the PC card's room beside its "i"

local fs = require("@lune/fs")

local Locale = require("../src/shared/Util/Locale")
local PortalData = require("../src/shared/Data/PortalShop")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = T.describe, T.it, T.expect

local LETTER = 0.56
local SPACE = 0.3
local SYMBOL = 1.0
local LANGS = { "pl", "en" }

local function width(text: string, size: number): number
	local em = 0
	for _, code in utf8.codes(text) do
		em += if code == 32 then SPACE elseif code >= 0x2000 then SYMBOL else LETTER
	end
	return em * size
end

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
end)
