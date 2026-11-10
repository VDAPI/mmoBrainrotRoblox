--!strict
-- Owner 2026-11-10 ("bardzo dużo napisów, niektóre rzeczy zasłaniają inne"): UI plan package E, layout rule L10 on
-- Logic/WorldLayout. The world and social windows at their registered sizes, on every screen of tests/uiframe.spec
-- (PC, tablets and Logic/PhoneHud's phones, Roblox's top bar 0, 36 and 58 px, the window's content from
-- Logic/WindowFrame): no negative size, the lists show at least 2-3 rows on a phone and 5 on PC, the footers and the
-- dialog's buttons stay pinned at the bottom, the tabs fit or scroll, "Graj" stays on the screen, the emote wheel and
-- the fishing panel keep clear of the top bar (and the panel of a phone's HUD), the NPC's line never runs into the
-- choices, and Party Finder's rows stay in their 290-px cells. The numbers WorldLayout copies from Components/Section
-- and Theme are read from those files.

local fs = require("@lune/fs")

local Classes = require("../src/shared/Data/Classes")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local T = require("./Test")
local TextCaps = require("../src/shared/Logic/TextCaps")
local UiScale = require("../src/shared/Logic/UiScale")
local WindowFrame = require("../src/shared/Logic/WindowFrame")
local WorldLayout = require("../src/shared/Logic/WorldLayout")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

type Size = WorldLayout.Size
type Rect = WorldLayout.Rect
type Device = WorldLayout.Device

-- The screens of tests/uiframe.spec: the windows' layer in virtual pixels and Roblox's top bar in it.
local PC = {
	{ 1920, 1080 },
	{ 1366, 768 },
	{ 1280, 720 },
	{ 1920, 1200 },
	{ 2560, 1080 },
	{ 1280, 1024 },
	{ 1024, 768 },
	{ 1024, 600 },
	{ 1280, 600 },
}
local TABLET = { { 1280, 720 }, { 1280, 800 }, { 1024, 768 }, { 1024, 600 }, { 1366, 1024 } }
local BARS = { 0, 36, 58 }

type Screen = { name: string, device: Device, touch: boolean, compact: boolean, w: number, h: number, bar: number }

local function screens(): { Screen }
	local out: { Screen } = {}
	for _, set in { { touch = false, sizes = PC }, { touch = true, sizes = TABLET } } do
		for _, size in set.sizes do
			local k = UiScale.factor(size[1], size[2], set.touch)
			for _, bar in BARS do
				table.insert(out, {
					name = `{if set.touch then "tablet" else "PC"} {size[1]}x{size[2]} bar {bar}`,
					device = WorldLayout.device(set.touch, false),
					touch = set.touch,
					compact = false,
					w = size[1] / k,
					h = size[2] / k,
					bar = bar / k,
				})
			end
		end
	end
	for _, device in PhoneHud.DEVICES do
		local w, h = PhoneHud.area(device)
		for _, bar in BARS do
			table.insert(out, {
				name = `phone {device.name} bar {bar}`,
				device = "phone",
				touch = true,
				compact = true,
				w = w,
				h = h,
				bar = bar / PhoneHud.SCALE,
			})
		end
	end
	return out
end

-- The registered size of a window id (the first `id = "<id>",` followed by its `size = Vector2.new(W, H)`).
local function windowSize(id: string): Size
	local function walk(dir: string): Size?
		local names = fs.readDir(dir)
		table.sort(names)
		for _, name in names do
			local path = `{dir}/{name}`
			if fs.isDir(path) then
				local found = walk(path)
				if found then
					return found
				end
			elseif string.sub(name, -5) == ".luau" then
				local current: string? = nil
				for line in string.gmatch(fs.readFile(path), "[^\n]+") do
					current = string.match(line, '^%s*id = "([%w_]+)",') or current
					local w, h = string.match(line, "^%s*size = Vector2%.new%((%d+), (%d+)%)")
					if w and h then
						if current == id then
							return { w = assert(tonumber(w)), h = assert(tonumber(h)) }
						end
						current = nil
					end
				end
			end
		end
		return nil
	end
	return assert(walk("src/client/Controllers"), `no registered window {id}`)
end

-- The window's content on a screen (Logic/WindowFrame: a touch window under the top bar, compact on a phone).
local function contentOf(id: string, screen: Screen): Size
	local frame =
		WindowFrame.rect({ w = screen.w, h = screen.h }, windowSize(id), nil, screen.touch, screen.bar, screen.compact)
	local c = frame.content
	return { w = c.right - c.left, h = c.bottom - c.top }
end

-- The fewest rows a list shows: a phone, a tablet, PC.
local function wanted(device: Device, phone: number, pc: number): number
	return if device == "pc" then pc else phone
end

local function inside(r: Rect, outer: Rect): boolean
	local e = 1e-6
	return r.left >= outer.left - e
		and r.top >= outer.top - e
		and r.right <= outer.right + e
		and r.bottom <= outer.bottom + e
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

-- Every number of a layout table (nested tables too) is at least zero.
local function negatives(name: string, value: any, out: { string })
	if type(value) == "number" then
		if value < -1e-6 then
			table.insert(out, `{name} = {value}`)
		end
	elseif type(value) == "table" then
		for key, inner in value do
			negatives(`{name}.{key}`, inner, out)
		end
	end
end

local function constant(path: string, pattern: string): number
	local found = string.match(fs.readFile(path), pattern)
	return assert(tonumber(found), `{path}: {pattern}`)
end

T.describe("WorldLayout (UI plan L10, package E)", function()
	T.it("copies Components/Section's and Theme's numbers", function()
		local S = WorldLayout.SECTION
		T.expect(constant("src/client/UI/Components/Section.luau", "local HEADER_PC = (%d+)")).toBe(S.header)
		T.expect(constant("src/client/UI/Components/Section.luau", "local SUMMARY_PC = (%d+)")).toBe(S.summary)
		T.expect(constant("src/client/UI/Theme.luau", "MinTouch = (%d+)")).toBe(S.headerTouch)
		T.expect(constant("src/client/UI/Theme.luau", "MinTouch = (%d+)")).toBe(S.summaryTouch)
		T.expect(constant("src/client/UI/Theme.luau", "Padding = {%s*Tiny = %d+,%s*Small = (%d+)")).toBe(S.gap)
		T.expect(constant("src/client/UI/Theme.luau", "\n%s*Body = (%d+)")).toBe(WorldLayout.BODY)
	end)

	T.it("rankings: the rows show 2 on a phone under the folded podium, 5 on PC", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local content = contentOf("rankings", screen)
			for _, filter in { false, true } do
				for _, info in { false, true } do
					local r = WorldLayout.rankings(content, screen.device, filter, info)
					negatives(`{screen.name} rankings`, r, problems)
					-- the podium is open on PC, folded on a phone (rankPodium)
					local skip = if screen.device == "phone"
						then WorldLayout.section(screen.device, false, 0) + r.list.gap
						else 0
					local rows = WorldLayout.rows(r.list, skip)
					local want = wanted(screen.device, 2, 5)
					if rows < want then
						table.insert(problems, `{screen.name} filter {filter} info {info}: {rows} rows < {want}`)
					end
					-- the footer pinned under the list
					local board = content.h - (if r.strip > 0 then r.strip + 8 else 0)
					if math.abs(r.list.top + r.list.height + 2 + r.footer - board) > 1e-6 then
						table.insert(problems, `{screen.name}: footer not at the bottom`)
					end
				end
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("season pass: at least 3 tier rows on a phone; PC shows its strip and 5 tiers", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local content = contentOf("season", screen)
			local s = WorldLayout.season(content, screen.device)
			negatives(`{screen.name} season`, s, problems)
			if screen.device == "pc" then
				if content.h - (s.header + s.toolbar + s.gap) < WorldLayout.seasonStrip() then
					table.insert(problems, `{screen.name}: the strip is cut`)
				end
				if s.columns < 5 then
					table.insert(problems, `{screen.name}: {s.columns} tier columns`)
				end
			else
				local rows = WorldLayout.rows(s.list)
				local want = if screen.device == "phone" then 3 else 2
				if rows < want then
					table.insert(problems, `{screen.name}: {rows} tier rows < {want}`)
				end
			end
			-- the two tabs fit their strip
			for lang, texts in { pl = pl, en = en } :: { [string]: { [string]: string } } do
				local need = 0
				for _, key in { "season.tab.rewards", "season.tab.how" } do
					need += TextCaps.width(texts[key], 17) + 24
				end
				if need > s.tabsWidth then
					table.insert(problems, `{screen.name} {lang}: the tabs need {need} > {s.tabsWidth}`)
				end
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("achievements: 3 rows on a phone, 5 on PC; the bestiary's entries never go negative", function()
		local problems: { string } = {}
		local regions = 4
		for _, screen in screens() do
			local content = contentOf("achievements", screen)
			local a = WorldLayout.achievements(content, screen.device)
			negatives(`{screen.name} achievements`, a, problems)
			local rows = WorldLayout.rows(a.list)
			local want = wanted(screen.device, 3, 5)
			if rows < want then
				table.insert(problems, `{screen.name}: {rows} rows < {want}`)
			end
			-- the bestiary in the list's place, the regions open on PC and folded on a phone (bestiaryRegions)
			local middle = { w = content.w, h = a.list.height }
			for _, open in { true, false } do
				local b = WorldLayout.bestiary(middle, screen.device, open, regions)
				negatives(`{screen.name} bestiary open {open}`, b, problems)
				if math.abs(b.list.top + b.list.height - middle.h) > 1e-6 then
					table.insert(problems, `{screen.name} regions open {open}: the entries do not end at the bottom`)
				end
				-- open: the region rows show (they scroll when the screen is short)
				if open and b.regions < WorldLayout.BESTIARY.regionRow then
					table.insert(problems, `{screen.name}: the open regions show {b.regions} px`)
				end
			end
			local default = WorldLayout.bestiary(middle, screen.device, screen.device ~= "phone", regions).list
			if WorldLayout.rows(default) < 2 then
				table.insert(problems, `{screen.name}: {WorldLayout.rows(default)} bestiary rows < 2`)
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("quest board: 2 cards under the hunting block (folded on a phone); the tabs and the set's line fit", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local content = contentOf("questboard", screen)
			for _, hunt in { false, true } do
				local b = WorldLayout.questBoard(content, screen.device, hunt, screen.device ~= "phone")
				negatives(`{screen.name} questboard`, b, problems)
				local rows = WorldLayout.rows(b.list)
				if rows < 2 then
					table.insert(problems, `{screen.name} hunt {hunt}: {rows} cards < 2`)
				end
				if b.tabsWidth > 0 then
					for lang, texts in { pl = pl, en = en } :: { [string]: { [string]: string } } do
						local need = TextCaps.width(texts["quest.board.daily"], 17)
							+ TextCaps.width(texts["quest.board.weekly"], 17)
							+ 48
						if need > b.tabsWidth then
							table.insert(problems, `{screen.name} {lang}: tabs {need} > {b.tabsWidth}`)
						end
					end
					if content.w - b.tabsWidth - 8 < 300 then
						table.insert(problems, `{screen.name}: the set's line {content.w - b.tabsWidth - 8} < 300`)
					end
				end
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("quest dialog: 3 lines of the page over the reward choice and the pinned buttons", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local content = contentOf("questnpc", screen)
			for _, choice in { false, true } do
				local d = WorldLayout.questDialog(content, screen.device, choice)
				negatives(`{screen.name} questnpc`, d, problems)
				if d.bodyLines < 3 then
					table.insert(problems, `{screen.name} choice {choice}: {d.bodyLines} lines < 3`)
				end
				-- the buttons at the bottom, the choice right over them
				if math.abs(d.bodyTop + d.body + d.choice + d.buttons - content.h) > 1e-6 then
					table.insert(problems, `{screen.name}: the buttons are not pinned`)
				end
				-- a phone's choice row: the label and four slots in one row
				if choice and d.choiceLabel > 0 and d.choiceLabel + 4 * (d.slot + 14) > content.w then
					table.insert(problems, `{screen.name}: the reward row does not fit`)
				end
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("NPC dialog: the box holds the longest line, the choices start under it with 2 rows", function()
		local problems: { string } = {}
		local sample = WorldLayout.longestLine()
		T.expect(TextCaps.chars(sample)).toBe(TextCaps.SURFACES.dialogPage.chars + 2)
		for _, screen in screens() do
			local content = contentOf("npc", screen)
			local d = WorldLayout.npcDialog(content, screen.device)
			negatives(`{screen.name} npc`, d, problems)
			local width = d.line.right - d.line.left
			local need = TextCaps.lines(sample, WorldLayout.BODY, width) * WorldLayout.BODY
			if d.line.bottom - d.line.top < need then
				table.insert(problems, `{screen.name}: the line box {d.line.bottom - d.line.top} < {need}`)
			end
			if d.line.bottom > d.choicesTop or d.portrait.h > d.choicesTop then
				table.insert(problems, `{screen.name}: the line runs into the choices`)
			end
			if WorldLayout.rows(d.choices) < 2 then
				table.insert(problems, `{screen.name}: {WorldLayout.rows(d.choices)} choices < 2`)
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("party and friends: 3 rows on a phone, 5 on PC (a full party)", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local party = WorldLayout.party(contentOf("party", screen), screen.device)
			negatives(`{screen.name} party`, party, problems)
			local rows = WorldLayout.rows(party.list)
			local want = wanted(screen.device, 3, 5)
			if rows < want then
				table.insert(problems, `{screen.name}: {rows} party rows < {want}`)
			end
			local friends = WorldLayout.friends(contentOf("friends", screen), screen.device)
			negatives(`{screen.name} friends`, friends, problems)
			rows = WorldLayout.rows(friends.list)
			if rows < want then
				table.insert(problems, `{screen.name}: {rows} friend rows < {want}`)
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("Party Finder: the wanted classes and the steppers stay inside their 290-px cells", function()
		local classes = #Classes.order
		local label = WorldLayout.finderClassLabel(classes)
		T.expect(label >= WorldLayout.FINDER.minLabel).toBe(true)
		for _, texts in { pl, en } :: { { [string]: string } } do
			T.expect(TextCaps.width(texts["finder.want"], 17) <= label).toBe(true)
		end
		T.expect(WorldLayout.finderStepperText() >= 180).toBe(true)
		-- a fifth class shrinks the label, it never pushes a button out of the cell
		T.expect(WorldLayout.finderClassLabel(classes + 1) + (classes + 1) * 50).toBe(WorldLayout.FINDER.cell)
	end)

	T.it("character select: 'Graj' and 'Usuń' pinned on the card, inside the screen under the top bar", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local c = WorldLayout.characterSelect({ w = screen.w, h = screen.h }, screen.compact, screen.bar)
			negatives(`{screen.name} select`, c, problems)
			local area = { left = 0, top = screen.bar, right = screen.w, bottom = screen.h }
			if not inside(c.play, area) or not inside(c.delete, area) then
				table.insert(problems, `{screen.name}: 'Graj' or 'Usuń' off the screen`)
			end
			if c.play.bottom > c.delete.top or c.titleTop < screen.bar then
				table.insert(problems, `{screen.name}: the buttons or the title overlap`)
			end
			-- what stands over the buttons fits its part: the emblem, the name, class and map
			local text = if screen.compact then 32 + 24 + 20 + 3 * 4 else 40 + 26 + 22 + 3 * 8
			if c.emblem + text > c.info + 1e-6 then
				table.insert(problems, `{screen.name}: the card's info {c.emblem + text} > {c.info}`)
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("emote wheel: inside the screen under the top bar, no part over another", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local layer = { w = screen.w, h = screen.h }
			local wheel = WorldLayout.emoteWheel(layer, screen.bar)
			local area = { left = 0, top = screen.bar, right = screen.w, bottom = screen.h }
			for i, r in WorldLayout.emoteRects(layer, wheel, 8) do
				if not inside(r, area) then
					table.insert(problems, `{screen.name}: part {i} of the wheel off the screen`)
				end
			end
			if wheel.radius < WorldLayout.EMOTE.minRadius then
				table.insert(problems, `{screen.name}: radius {wheel.radius}`)
			end
			-- a page of 1 to 8 emotes: the buttons, "Zamknij", the arrows and the title never overlap
			for count = 1, 8 do
				local rects = WorldLayout.emoteRects(layer, wheel, count)
				for i = 1, #rects do
					for j = i + 1, #rects do
						if overlaps(rects[i], rects[j]) then
							table.insert(problems, `{screen.name}: {count} emotes, part {i} over part {j}`)
						end
					end
				end
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("fishing: the panel under the top bar, clear of a phone's HUD columns and bottom buttons", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local layer = { w = screen.w, h = screen.h }
			local f = WorldLayout.fishing(layer, screen.bar, screen.compact)
			local area = { left = 0, top = screen.bar, right = screen.w, bottom = screen.h }
			if not inside(f.panel, area) then
				table.insert(problems, `{screen.name}: the panel off the screen`)
			end
			if f.bar < 160 then
				table.insert(problems, `{screen.name}: the bar {f.bar} px`)
			end
			if screen.compact then
				for name, r in WorldLayout.phonePlaces(layer, screen.bar) do
					if not WorldLayout.FISHING_FREE[name] and overlaps(f.panel, r) then
						table.insert(problems, `{screen.name}: the panel covers {name}`)
					end
				end
			end
		end
		T.expect(problems).toEqual({})
	end)
end)
