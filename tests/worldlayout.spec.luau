--!strict
-- Owner 2026-11-10 ("bardzo dużo napisów, niektóre rzeczy zasłaniają inne"): UI plan package E, layout rule L10 on
-- Logic/WorldLayout. The world and social windows at their registered sizes, on every screen of tests/uiframe.spec
-- (PC, tablets and Logic/PhoneHud's phones, Roblox's top bar 0, 36 and 58 px, the window's content from
-- Logic/WindowFrame): no negative size, the lists show at least 2-3 rows on a phone and 5 on PC, the footers and the
-- dialog's buttons stay pinned at the bottom, the tabs fit or scroll, "Graj" stays on the screen, the emote wheel and
-- the fishing panel keep clear of the top bar (and the panel of a phone's HUD), the NPC's line never runs into the
-- choices, and Party Finder's rows stay in their 290-px cells. The numbers WorldLayout copies from Components/Section
-- and Theme are read from those files. Every text field's placeholder in E's windows fits 20 characters.

local fs = require("@lune/fs")

local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local Folds = require("../src/shared/Data/Folds")
local Leaderboards = require("../src/shared/Data/Leaderboards")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local Seasons = require("../src/shared/Data/Seasons")
local SectionFold = require("../src/shared/Logic/SectionFold")
local T = require("./Test")
local TextCaps = require("../src/shared/Logic/TextCaps")
local TextScan = require("./TextScan")
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

-- Review 2026-11-10 (a notched phone: the fishing panel covered the menu button): a screen in the Windows layer lays
-- out in that layer's size, the safe area this spec's phones use (PhoneHud.area): the HUD's layer (Scale.HudSize) with
-- Roblox's top bar over it, never the whole screen (Scale.VirtualSize, wider on a notched phone).
local function readsWindowsLayer(path: string): boolean
	local src = fs.readFile(path)
	return string.find(src, "Scale.VirtualSize", 1, true) == nil
		and string.find(src, "use(Scale.HudSize)", 1, true) ~= nil
		and string.find(src, "use(Scale.TopBar)", 1, true) ~= nil
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

	-- Review 2026-11-10: the rows counted under the podium as Data/Folds/World opens it on the device (open on PC and a
	-- tablet, folded on a phone) and under the weekly board's rewards line (PC and a tablet; a phone leaves it out).
	T.it("rankings: the rows show 2 on a phone, 5 on PC, under the podium as it opens by default", function()
		local problems: { string } = {}
		for _, screen in screens() do
			local content = contentOf("rankings", screen)
			for _, filter in { false, true } do
				for _, info in { false, true } do
					for _, week in { false, true } do
						local r = WorldLayout.rankings(content, screen.device, filter, info, week)
						negatives(`{screen.name} rankings`, r, problems)
						local open = SectionFold.default("rankPodium", screen.compact)
						local skip = WorldLayout.section(screen.device, open, r.podium) + r.list.gap
						if r.rewards > 0 then
							skip += r.rewards + r.list.gap
						end
						local rows = WorldLayout.rows(r.list, skip)
						local want = wanted(screen.device, 2, 5)
						if rows < want then
							table.insert(
								problems,
								`{screen.name} filter {filter} info {info} week {week}: {rows} rows < {want}`
							)
						end
						if week and (r.rewards > 0) == (screen.device == "phone") then
							table.insert(problems, `{screen.name}: the rewards line {r.rewards} on {screen.device}`)
						end
						-- the footer pinned under the list
						local board = content.h - (if r.strip > 0 then r.strip + 8 else 0)
						if math.abs(r.list.top + r.list.height + 2 + r.footer - board) > 1e-6 then
							table.insert(problems, `{screen.name}: footer not at the bottom`)
						end
						-- the rewards line is one line on the board (its padding 8 each side, the rows' scroll bar 6)
						if r.rewards > 0 then
							local width = content.w - (if r.side > 0 then r.side + 12 else 0) - 16 - 6
							for lang, t in { pl = pl, en = en } :: { [string]: { [string]: string } } do
								local title = t["title." .. Leaderboards.WEEK_REWARDS.title]
								local text = string.gsub(t["leaderboard.week.rewards.short"], "{title}", title)
								if TextCaps.width(text, WorldLayout.SMALL) > width then
									table.insert(problems, `{screen.name} {lang}: the rewards line is cut`)
								end
							end
						end
					end
				end
			end
		end
		T.expect(problems).toEqual({})
	end)

	-- Review 2026-11-10 (UI-ZASADY §1, state and time on top): a phone's footer keeps one line, so when the week or the
	-- arena season ends goes into the title row (it fits the board with the (i)), and a board of this server only says
	-- so first in that footer line; the (i) keeps the rule and the update time.
	T.it("rankings on a phone: the countdown in the title row, the server warning in the footer line", function()
		local src = fs.readFile("src/client/UI/Screens/RankingsWindow.luau")
		T.expect(string.find(src, "local left = if use(layout).footerLines < 2 then use(endsIn)", 1, true) ~= nil)
			.toBe(true)
		T.expect(string.find(src, '"leaderboard.local.short"', 1, true) ~= nil).toBe(true)
		local problems: { string } = {}
		for _, screen in screens() do
			if screen.device == "phone" then
				local width = contentOf("rankings", screen).w - 30
				for lang, t in { pl = pl, en = en } :: { [string]: { [string]: string } } do
					for _, board in { "exp_week", "arena", "arena3" } do
						local time = string.gsub(string.gsub(t["arena.time.dh"], "{d}", "88"), "{h}", "88")
						local left = string.gsub(t["leaderboard.endsIn"], "{time}", time)
						local title = `{t["leaderboard.board." .. board]} · {left}`
						if TextCaps.width(title, 24) > width then
							table.insert(problems, `{screen.name} {lang}: "{title}" wider than the board`)
						end
					end
				end
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("season pass: at least 3 tier rows on a phone; PC shows its strip and 5 tiers", function()
		local src = fs.readFile("src/client/UI/Screens/SeasonPass.luau")
		T.expect(string.find(src, "local left = phoneWhen(use, use(view))", 1, true) ~= nil).toBe(true)
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
			-- review 2026-11-10: a phone's header line keeps when the season ends (or the claim date of its grace days)
			-- beside the season's name: it fits with the (i) left of the tier's 170
			if screen.device == "phone" then
				for lang, t in { pl = pl, en = en } :: { [string]: { [string]: string } } do
					for _, def in Seasons.list do
						local ends = string.gsub(string.gsub(t["season.endsShort"], "{d}", "88"), "{h}", "88")
						local grace = string.gsub(t["season.graceShort"], "{date}", "88.88.8888")
						for _, left in { ends, grace } do
							local line = `{t[def.nameKey]} · {left}`
							if TextCaps.width(line, 24) + 44 > content.w - 170 then
								table.insert(problems, `{screen.name} {lang}: "{line}" wider than the header`)
							end
						end
					end
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

	-- The labels of the achievements' range and filter switches (AchievementsWindow/Summary).
	local SWITCH_KEYS = {
		"ach.scope.all",
		"ach.scope.account",
		"ach.scope.character",
		"ach.filter.all",
		"ach.filter.open",
		"ach.filter.done",
	}

	T.it("achievements: 3 rows on a phone, 5 on PC; the bestiary's entries never go negative", function()
		-- Review 2026-11-10: open on a phone, the regions leave the entries less than a row, so the regions work as a
		-- picker there: a tap on one folds them again (the header names the chosen region)
		local bestiary = fs.readFile("src/client/UI/Screens/AchievementsWindow/BestiaryTab.luau")
		local foldsOnPick = "ctx%.region:set%(region%)%s+if Fusion%.peek%(PhoneLayout%.Compact%) then%s+"
			.. "Section%.set%(REGIONS_ID, false%)"
		T.expect(string.find(bestiary, foldsOnPick) ~= nil).toBe(true)
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
			-- review 2026-11-10: the range and filter labels fit their buttons in one line (Small 17, the padding 14
			-- each side)
			for lang, t in { pl = pl, en = en } :: { [string]: { [string]: string } } do
				for _, key in SWITCH_KEYS do
					if TextCaps.width(t[key], WorldLayout.SMALL) + 28 > a.switchButton then
						table.insert(
							problems,
							`{screen.name} {lang}: "{t[key]}" wider than its {a.switchButton} button`
						)
					end
				end
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
		-- Review 2026-11-10: folded, the block's title says what waits (the counts in the header row, not a summary
		-- line that would cost a phone its second card)
		local src = fs.readFile("src/client/UI/Screens/QuestBoard.luau")
		T.expect(string.find(src, "return if use2(open) then header else folded", 1, true) ~= nil).toBe(true)
		local problems: { string } = {}
		for _, screen in screens() do
			local content = contentOf("questboard", screen)
			-- the folded title in its header row (Components/Section: the padding 4 each side, the arrow 18, two gaps
			-- 6, the (i) 44 on touch and 28 on PC)
			local room = content.w - 8 - 18 - 12 - (if screen.touch then 44 else 28)
			for lang, t in { pl = pl, en = en } :: { [string]: { [string]: string } } do
				local ready = string.gsub(t["contract.board.ready"], "{n}", "99")
				local take = string.gsub(t["contract.board.take"], "{n}", "99")
				local folded = `{t["contract.board.title"]} · {ready} · {take}`
				if TextCaps.width(folded, WorldLayout.BODY) > room then
					table.insert(problems, `{screen.name} {lang}: "{folded}" wider than its header`)
				end
			end
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
		T.expect(readsWindowsLayer("src/client/UI/Screens/EmoteWheel.luau")).toBe(true)
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
		T.expect(readsWindowsLayer("src/client/UI/Screens/FishingGame.luau")).toBe(true)
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

	T.it("the sections of E's windows have their defaults in Folds/World or Folds/Menu", function()
		local mine: { [string]: boolean } = {}
		for _, area in Folds do
			if area.name == "World" or area.name == "Menu" then
				for id in area.folds do
					mine[id] = true
				end
			end
		end
		local files = {
			"src/client/UI/Screens/RankingsWindow.luau",
			"src/client/UI/Screens/QuestBoard.luau",
			"src/client/UI/Screens/QuestJournal.luau",
			"src/client/UI/Screens/GameMenu.luau",
			"src/client/UI/Screens/AchievementsWindow/BestiaryTab.luau",
			"src/client/UI/Screens/WorldMap/Panels.luau",
			"src/client/UI/Screens/WorldMap/DetailCard.luau",
			"src/client/UI/Screens/GuildWindow/Overview.luau",
			"src/client/UI/Screens/GuildWindow/Settings.luau",
		}
		local found = 0
		for _, path in files do
			local src = fs.readFile(path)
			for id in string.gmatch(src, 'Section%.new%(%s*[%w_]+%s*,%s*{%s*Id%s*=%s*"([%w_]+)"') do
				found += 1
				T.expect(`{path} {id} {mine[id] == true}`).toBe(`{path} {id} true`)
			end
			for id in string.gmatch(src, 'Section%.state%(%s*[%w_]+%s*,%s*"([%w_]+)"') do
				found += 1
				T.expect(`{path} {id} {mine[id] == true}`).toBe(`{path} {id} true`)
			end
		end
		T.expect(found >= 8).toBe(true)
	end)

	T.it("every text field's placeholder in E's windows fits the field's 20 characters", function()
		-- UI-ZASADY §2 (placeholder pola: 20): the character name's limits are filled with their real numbers (3-16),
		-- anything else with TextCaps' samples.
		local args = { min = Config.CharacterName.MinLength, max = Config.CharacterName.MaxLength }
		local cap = TextCaps.SURFACES.placeholder.chars
		local found, problems = 0, {}
		local function walk(dir: string)
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					walk(path)
				elseif string.sub(name, -5) == ".luau" and TextScan.ownerOfFile(path) == "E" then
					local src = fs.readFile(path)
					for key in string.gmatch(src, 'Placeholder%a*%s*=%s*Text%.T%(%s*scope%s*,%s*"([%w_%.]+)"') do
						found += 1
						for lang, strings in { pl = pl, en = en } :: { [string]: { [string]: string } } do
							local filled = string.gsub(strings[key] or "", "{(%w+)}", function(arg: string): string?
								local value = (args :: { [string]: number })[arg]
								return if value then tostring(value) else nil
							end)
							local chars = TextCaps.chars(TextCaps.expand(filled))
							if chars > cap then
								table.insert(problems, `{lang} {key} ({chars}): {filled}`)
							end
						end
					end
				end
			end
		end
		walk("src/client/UI")
		T.expect(problems).toEqual({})
		T.expect(found >= 10).toBe(true)
	end)
end)
