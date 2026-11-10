--!strict
-- UI plan 2026-11-10, L10 (owner 2026-11-10: "niektóre rzeczy zasłaniają inne"): the item and character windows lay
-- out from their content rect (Logic/GearLayout), not the screen. At every registered PC size and on the three phones
-- (PhoneHud.DEVICES, the phone's compact title bar, Roblox's top bar of 0, 36 and 58 real px: a window takes it in
-- virtual px, bar / PhoneHud.SCALE, as tests/uiframe.spec does): no negative size, every rect inside its area and no two
-- overlapping, the buttons pinned to the bottom (the footer) and touch targets of 44 on a phone, at least 2 slot rows
-- on a phone and 5 on PC, at least 260 px of skill details on a phone. The windows read the same functions (source
-- checks at the end).

local fs = require("@lune/fs")

local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local GearLayout = require("../src/shared/Logic/GearLayout")
local Locale = require("../src/shared/Util/Locale")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")
local TextCaps = require("../src/shared/Logic/TextCaps")
local WindowFrame = require("../src/shared/Logic/WindowFrame")

type Rect = GearLayout.Rect
type Size = GearLayout.Size

-- The registered sizes (ScreenController, NpcController, MarketController, PremiumController).
local WINDOWS: { [string]: Size } = {
	character = { w = 1240, h = 720 },
	inventory = { w = 560, h = 640 },
	skills = { w = 920, h = 640 },
	blacksmith = { w = 860, h = 660 },
	auction = { w = 1080, h = 700 },
	alchemy = { w = 1000, h = 680 },
	look = { w = 820, h = 600 },
	backpacks = { w = 640, h = 640 },
}

-- Each case: the window's content area as the view gets it (`tabs`: under the window's own tab strip).
type Case = { name: string, area: Size, touch: boolean }

-- Roblox's top bar on a phone in real px (none, the slim bar, the full one), as the plan and UI-ZASADY give it
local BARS = { 0, 36, 58 }

local function cases(window: string, under: number?): { Case }
	local out: { Case } = {}
	local size = WINDOWS[window]
	local pc = GearLayout.area({ w = 1920, h = 1080 }, size, false)
	table.insert(out, { name = `{window} PC`, area = { w = pc.w, h = pc.h - (under or 0) }, touch = false })
	for _, device in PhoneHud.DEVICES do
		local w, h = PhoneHud.area(device)
		for _, bar in BARS do
			local area = GearLayout.area({ w = w, h = h }, size, true, bar / PhoneHud.SCALE, true)
			table.insert(out, {
				name = `{window} {device.name} bar {bar}`,
				area = { w = area.w, h = area.h - (under or 0) },
				touch = true,
			})
		end
	end
	return out
end

local function sizeOk(r: Rect): boolean
	return r.right - r.left >= 0 and r.bottom - r.top >= 0
end

local function inside(r: Rect, area: Size): boolean
	return r.left >= -0.001 and r.top >= -0.001 and r.right <= area.w + 0.001 and r.bottom <= area.h + 0.001
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.left < b.right - 0.001
		and b.left < a.right - 0.001
		and a.top < b.bottom - 0.001
		and b.top < a.bottom - 0.001
end

-- every rect has a size, lies in the area and meets no other one
local function check(case: Case, rects: { [string]: Rect })
	local names: { string } = {}
	for name in rects do
		table.insert(names, name)
	end
	table.sort(names)
	for i, name in names do
		local r = rects[name]
		T.expect({ case.name, name, sizeOk(r) }).toEqual({ case.name, name, true })
		T.expect({ case.name, name, inside(r, case.area) }).toEqual({ case.name, name, true })
		for j = i + 1, #names do
			local other = names[j]
			T.expect({ case.name, name, other, overlaps(r, rects[other]) }).toEqual({ case.name, name, other, false })
		end
	end
end

-- a button row sits in the footer: on the area's bottom edge, at most FOOTER high (`rows` rows of buttons more)
local function inFooter(case: Case, name: string, r: Rect, rows: number?)
	local high = GearLayout.FOOTER + ((rows or 1) - 1) * (GearLayout.BUTTON_SMALL + GearLayout.GAP)
	T.expect({ case.name, name, math.abs(r.bottom - case.area.h) < 0.001, r.bottom - r.top <= high })
		.toEqual({ case.name, name, true, true })
end

T.describe("GearLayout (UI plan L10, owner 2026-11-10)", function()
	T.it("a phone's content keeps at least 280 px under a 58-px top bar (the area every phone case uses)", function()
		for _, device in PhoneHud.DEVICES do
			local w, h = PhoneHud.area(device)
			local bar = 58 / PhoneHud.SCALE -- 68.5 virtual px
			local area = GearLayout.area({ w = w, h = h }, WINDOWS.character, true, bar, true)
			T.expect({ device.name, area.h >= 280 }).toEqual({ device.name, true })
			local frame = WindowFrame.rect({ w = w, h = h }, WINDOWS.character, nil, true, bar, true)
			T.expect(area.w).toBe(frame.content.right - frame.content.left)
			T.expect(area.h).toBe(frame.content.bottom - frame.content.top)
		end
	end)

	T.it("the character window: columns from the content width, the backpack 500 wide on every phone", function()
		for _, case in cases("character") do
			local layout = GearLayout.character(case.area, case.touch)
			local rects: { [string]: Rect } = { left = layout.left, backpack = layout.backpack }
			if layout.right then
				rects.right = layout.right
			end
			check(case, rects)
			T.expect({ case.name, layout.backpack.right - layout.backpack.left }).toEqual({ case.name, 500 })
			if not case.touch then
				T.expect({ case.name, layout.wide }).toEqual({ case.name, true })
			end
		end
	end)

	T.it("the backpack: the grid between the filters and the actions, 2 slot rows on a phone, 5 on PC", function()
		-- both homes of BackpackPanel: the companion window ("inventory", next to a service) and the character
		-- window's backpack column; on touch both take 56-px slots (the panel's own default there)
		local function backpackCases(): { Case }
			local out = cases("inventory")
			for _, case in cases("character") do
				local column = GearLayout.character(case.area, case.touch).backpack
				table.insert(out, {
					name = `{case.name} backpack column`,
					area = { w = column.right - column.left, h = column.bottom - column.top },
					touch = case.touch,
				})
			end
			return out
		end
		for _, case in backpackCases() do
			local slot = if case.touch then GearLayout.BACKPACK.touchSlot else GearLayout.BACKPACK.slot
			for _, hinted in { false, true } do
				local b = GearLayout.backpack(case.area, slot, hinted, case.touch)
				local rects: { [string]: Rect } =
					{ header = b.header, tabs = b.tabs, grid = b.grid, actions = b.actions }
				if b.hint then
					rects.hint = b.hint
				end
				check(case, rects)
				inFooter(case, "actions", b.actions)
				T.expect({ case.name, hinted, b.rows >= (if case.touch then 2 else 5) })
					.toEqual({ case.name, hinted, true })
				T.expect({ case.name, b.columns >= 6 }).toEqual({ case.name, true })
				-- the grid really holds those rows (its padding and the gaps between them)
				local B = GearLayout.BACKPACK
				T.expect({ case.name, hinted, b.grid.bottom - b.grid.top >= 4 + b.rows * slot + (b.rows - 1) * B.gap })
					.toEqual({ case.name, hinted, true })
				if case.touch then
					-- the sort button (the header's height) and the action buttons are touch targets
					T.expect({ case.name, b.header.bottom - b.header.top, b.actions.bottom - b.actions.top })
						.toEqual({ case.name, GearLayout.TOUCH, GearLayout.TOUCH })
				end
			end
		end
	end)

	T.it(
		"skill details: at least 260 px on a phone (one bar), the PC panel's buttons pinned under the lines",
		function()
			for _, case in cases("skills") do
				if case.touch then
					-- the sheet covers the content and the window's bottom padding down to SHEET_EDGE
					local over = GearLayout.sheetOverhang(true)
					T.expect(over).toBe(WindowFrame.PADDING_COMPACT - GearLayout.SHEET_EDGE)
					local area = { w = case.area.w, h = case.area.h + over }
					local own: Case = { name = `{case.name} sheet`, area = area, touch = true }
					local sheet = GearLayout.skillSheet(area)
					check(own, { body = sheet.body, bar = sheet.bar })
					inFooter(own, "bar", sheet.bar)
					T.expect({ case.name, sheet.body.bottom - sheet.body.top >= GearLayout.MIN_DETAILS })
						.toEqual({ case.name, true })
					T.expect({ case.name, sheet.bar.bottom - sheet.bar.top >= GearLayout.TOUCH })
						.toEqual({ case.name, true })
				else
					-- the right panel inside its padding, under the header and the tabs, next to the tree
					local panel = GearLayout.skillPanelArea(case.area)
					local inner: Case = { name = case.name, area = panel, touch = false }
					for _, rows in { 1, 2 } do
						for _, preview in { false, true } do
							local p = GearLayout.skillPanel(panel, rows, preview)
							local rects: { [string]: Rect } =
								{ lines = p.lines, reason = p.reason, buttons = p.buttons }
							if p.preview then
								rects.preview = p.preview
							end
							check(inner, rects)
							inFooter(inner, "buttons", p.buttons, rows)
							-- the tightest case, the preview open over two rows of buttons, keeps 142 px of lines
							T.expect({ case.name, rows, preview, p.lines.bottom - p.lines.top >= 140 })
								.toEqual({ case.name, rows, preview, true })
						end
					end
				end
			end
		end
	)

	T.it("the folded 'Koszt i odnowienie' line fits the PC panel: cost and cooldown, no range", function()
		-- review 2026-11-10: with the range (and the cooldown's reduction) the line ran past the panel for every skill
		-- with a range. The summary row of a Section in the panel's lines: the panel, less the lines' scroll pad (8)
		-- and the row's paddings (4, the arrow 18 and 6 on the left; 4 on the right, 8 after the text), Small 17.
		local panel = GearLayout.skillPanelArea(GearLayout.area({ w = 1920, h = 1080 }, WINDOWS.skills, false))
		local room = panel.w - 8 - (4 + 18 + 6) - 4 - 8
		T.expect(room).toBe(278)
		local checked = 0
		for _, lang in { "pl", "en" } do
			for id, def in SkillData.byId do
				for rank = 1, math.max(1, def.maxLevel) do
					-- what SkillInfo.costSummary builds: the cost (a beam's drain per tick, else the resource rounded
					-- up, at the first and the last level) and the cooldown after 0, half and all of the reduction cap
					local costs: { string } = {}
					if def.type == "beam" then
						local drain = Skills.valueAt(def, "drain", rank)
						table.insert(
							costs,
							Locale.T("skills.cost.drain", { drain = math.floor(drain * 10 + 0.5) / 10 }, lang)
						)
					elseif def.resource then
						for _, level in { 1, Config.MaxLevel } do
							local cost = Skills.cost(def, rank, level, def.class)
							if cost > 0 then
								local text = { cost = math.ceil(cost - 1e-6) }
								table.insert(costs, Locale.T(`skills.cost.{def.resource}`, text, lang))
							end
						end
					end
					local cooldowns: { string } = {}
					for _, cdr in { 0, Combat.cdrCap / 2, Combat.cdrCap } do
						local shown = math.floor(Skills.cooldown(def, rank, cdr) * 10 + 0.5) / 10
						if shown > 0 then
							table.insert(cooldowns, Locale.T("skills.cooldown.short", { cooldown = shown }, lang))
						end
					end
					for _, cost in if #costs > 0 then costs else { "" } do
						for _, cooldown in if #cooldowns > 0 then cooldowns else { "" } do
							local text = if cost ~= "" and cooldown ~= ""
								then `{cost} · {cooldown}`
								else cost .. cooldown
							local ok, why = TextCaps.check("sectionSummary", text)
							T.expect({ lang, id, text, ok, why }).toEqual({ lang, id, text, true, nil })
							T.expect({ lang, id, text, TextCaps.width(text, 17) <= room })
								.toEqual({ lang, id, text, true })
							checked += 1
						end
					end
				end
			end
		end
		T.expect(checked > 1000).toBe(true)
		-- the window folds to that line; the range stays in the open section's cost line
		local info = fs.readFile("src/client/UI/SkillInfo.luau")
		local summary = assert(string.match(info, "function SkillInfo%.costSummary(.-)\nend\n"))
		T.expect(string.find(summary, "skills.range", 1, true)).toBeNil()
		T.expect(string.find(summary, "skills.cooldownReduced", 1, true)).toBeNil()
		T.expect(string.find(summary, '"skills.cooldown.short"', 1, true) ~= nil).toBe(true)
		local details = fs.readFile("src/client/UI/Screens/SkillsWindow/Details.luau")
		T.expect(
			string.find(details, "Summary = if hasCost then SkillInfo.costSummary(use, skill, shown)", 1, true) ~= nil
		)
			.toBe(true)
	end)

	T.it("the PC details panel's geometry is the skills window's own (tree, header, tabs, padding)", function()
		local function number(path: string, pattern: string): number?
			return tonumber(string.match(fs.readFile(path), pattern))
		end
		local dir = "src/client/UI/Screens/SkillsWindow/"
		local S = GearLayout.SKILL
		T.expect(number(`{dir}PathTab.luau`, "PathTab%.LIST_WIDTH = (%d+)")).toBe(S.tree)
		local header = number(`{dir}Header.luau`, "Header%.HEIGHT = (%d+)")
		local tabs = number(`{dir}TabBar.luau`, "TabBar%.HEIGHT = (%d+)")
		T.expect((header or 0) + 6 + (tabs or 0) + 6).toBe(S.top)
		local window = fs.readFile(`{dir}init.luau`)
		for _, needle in
			{ "GearLayout.skillPanelArea(", "GearLayout.SKILL.tree + GearLayout.SKILL.gutter", "GearLayout.SKILL.pad" }
		do
			T.expect({ needle, string.find(window, needle, 1, true) ~= nil }).toEqual({ needle, true })
		end
		T.expect(string.find(window, "Header.HEIGHT + 6 + TabBar.HEIGHT + 6", 1, true) ~= nil).toBe(true)
		-- and the phone sheet reaches over the window's padding by sheetOverhang
		local sheet = fs.readFile(`{dir}Sheet.luau`)
		T.expect(string.find(sheet, "GearLayout.sheetOverhang(", 1, true) ~= nil).toBe(true)
	end)

	T.it(
		"the blacksmith's upgrade: 'Ulepsz' in the footer, the middle scrolls between the item and the result",
		function()
			for _, case in cases("blacksmith", GearLayout.TABS) do
				local u = GearLayout.smithUpgrade(case.area)
				check(case, { list = u.list, slot = u.slot, middle = u.middle, result = u.result, button = u.button })
				check(case, { list = u.list, anvil = u.anvil, button = u.button })
				inFooter(case, "button", u.button)
				-- the item, the middle and the result inside the anvil's panel
				local inner: Case = {
					name = case.name,
					area = { w = u.anvil.right - u.anvil.left, h = u.anvil.bottom - u.anvil.top },
					touch = case.touch,
				}
				local function local_(r: Rect): Rect
					return {
						left = r.left - u.anvil.left,
						top = r.top - u.anvil.top,
						right = r.right - u.anvil.left,
						bottom = r.bottom - u.anvil.top,
					}
				end
				check(inner, { slot = local_(u.slot), middle = local_(u.middle), result = local_(u.result) })
				T.expect({ case.name, u.middle.bottom - u.middle.top >= GearLayout.SMITH.minMiddle })
					.toEqual({ case.name, true })
				if not case.touch then
					T.expect({ case.name, u.row }).toEqual({ case.name, false }) -- PC: the item above the middle
				end
			end
		end
	)

	T.it("the auction: 'Wystaw' and 'Szukaj' in the footer, the form and the filters scroll above them", function()
		for _, case in cases("auction", GearLayout.TABS) do
			local sell = GearLayout.auctionSell(case.area)
			check(case, { items = sell.items, form = sell.form, button = sell.button })
			inFooter(case, "sell", sell.button)
			local browse = GearLayout.auctionBrowse(case.area)
			check(
				case,
				{ filters = browse.filters, search = browse.search, results = browse.results, pager = browse.pager }
			)
			inFooter(case, "search", browse.search)
			inFooter(case, "pager", browse.pager)
			T.expect({ case.name, browse.filters.bottom - browse.filters.top >= 2 * GearLayout.TOUCH })
				.toEqual({ case.name, true })
		end
	end)

	T.it(
		"the alchemist: the queue scrolls with 2 rows on a phone and 5 on PC, 'Odbierz wszystko' in the footer",
		function()
			for _, case in cases("alchemy") do
				local a = GearLayout.alchemy(case.area)
				check(case, { recipes = a.recipes, title = a.title, queue = a.queue, collect = a.collect })
				inFooter(case, "collect", a.collect)
				T.expect({ case.name, a.rows >= (if case.touch then 2 else 5) }).toEqual({ case.name, true })
			end
		end
	)

	T.it("the appearance window: the preview next to the picker, inside the content (no 792 px in 776)", function()
		for _, case in cases("look") do
			local l = GearLayout.look(case.area)
			T.expect({ case.name, l.row }).toEqual({ case.name, true })
			check(case, { preview = l.preview, picker = l.picker })
			T.expect({ case.name, l.preview.right - l.preview.left >= GearLayout.LOOK.minW })
				.toEqual({ case.name, true })
		end
	end)

	T.it("the backpack shop: a row's text ends before its button", function()
		for _, case in cases("backpacks") do
			local row = GearLayout.backpackShop(case.area)
			local rowArea: Case = { name = case.name, area = { w = case.area.w, h = row.height }, touch = case.touch }
			check(rowArea, { icon = row.icon, text = row.text, button = row.button })
			T.expect({ case.name, row.text.right - row.text.left >= 200 }).toEqual({ case.name, true })
		end
	end)

	T.it("the windows read GearLayout", function()
		local readers = {
			"src/client/UI/Screens/CharacterWindow/init.luau",
			"src/client/UI/Screens/BackpackPanel.luau",
			"src/client/UI/Screens/SkillsWindow/init.luau",
			"src/client/UI/Screens/SkillsWindow/Sheet.luau",
			"src/client/UI/Screens/BlacksmithWindow/Upgrade.luau",
			"src/client/UI/Screens/AuctionWindow/Sell.luau",
			"src/client/UI/Screens/AuctionWindow/Browse.luau",
			"src/client/UI/Screens/AlchemyWindow.luau",
			"src/client/UI/Screens/LookWindow.luau",
			"src/client/UI/Screens/BackpackShop.luau",
		}
		for _, path in readers do
			local source = fs.readFile(path)
			T.expect({ path, string.find(source, "GearLayout.", 1, true) ~= nil }).toEqual({ path, true })
			-- the area comes from the view's own size, never the screen's
			T.expect({ path, string.find(source, "Scale.VirtualSize", 1, true) == nil }).toEqual({ path, true })
			-- measured with UI/ViewSize (review 2026-11-10): an AbsoluteSize over the UI scale alone still held the
			-- window's opening motion; BackpackPanel needs no size (its rows are anchored to its edges)
			if not string.find(path, "BackpackPanel", 1, true) then
				T.expect({ path, string.find(source, "ViewSize.new(scope)", 1, true) ~= nil }).toEqual({ path, true })
				T.expect({ path, string.find(source, "AbsoluteSize", 1, true) == nil }).toEqual({ path, true })
			end
		end
	end)
end)
