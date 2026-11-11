--!strict
-- UI plan 2026-11-10, L10 (owner 2026-11-10: "niektóre rzeczy zasłaniają inne"): the item and character windows lay
-- out from their content rect (Logic/GearLayout), not the screen. At every registered PC size and on the three phones
-- (PhoneHud.DEVICES, the phone's compact title bar, Roblox's top bar of 0, 36 and 58 real px: a window takes it in
-- virtual px, bar / PhoneHud.SCALE, as tests/uiframe.spec does): no negative size, every rect inside its area and no two
-- overlapping, the buttons pinned to the bottom (the footer) and touch targets of 44 on a phone, at least 2 slot rows
-- on a phone and 5 on PC, at least 260 px of skill details on a phone. The windows read the same functions (source
-- checks at the end). Adoption stage (2026-11-10): the services (blacksmith, auction, alchemist, appearance, trade) put
-- their main buttons in Components/Window's Footer, so their views are measured in the body above it
-- (WindowFrame.body) and their buttons in the footer row; GearLayout's sizes are the window frame's and Theme's.

local fs = require("@lune/fs")

local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local EffectReroll = require("../src/shared/Logic/EffectReroll")
local Format = require("../src/shared/Util/Format")
local GearLayout = require("../src/shared/Logic/GearLayout")
local ItemName = require("../src/shared/Logic/ItemName")
local Locale = require("../src/shared/Util/Locale")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local Rarities = require("../src/shared/Data/Rarities")
local Reroll = require("../src/shared/Logic/Reroll")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")
local TextCaps = require("../src/shared/Logic/TextCaps")
local Transmog = require("../src/shared/Logic/Transmog")
local WindowFrame = require("../src/shared/Logic/WindowFrame")

type Rect = GearLayout.Rect
type Size = GearLayout.Size

-- The registered sizes (ScreenController, NpcController, MarketController, PremiumController, SocialController).
local WINDOWS: { [string]: Size } = {
	character = { w = 1240, h = 720 },
	inventory = { w = 560, h = 640 },
	skills = { w = 920, h = 640 },
	blacksmith = { w = 860, h = 660 },
	auction = { w = 1080, h = 700 },
	alchemy = { w = 1000, h = 680 },
	look = { w = 820, h = 600 },
	backpacks = { w = 640, h = 640 },
	trade = { w = 640, h = 520 },
}

-- Each case: the window's content area as the view gets it (`tabs`: under the window's own tab strip).
type Case = { name: string, area: Size, touch: boolean }

-- Roblox's top bar on a phone in real px (none, the slim bar, the full one), as the plan and UI-ZASADY give it
local BARS = { 0, 36, 58 }

-- `under`: the window's own tab strip over the view; `footer`: the window has Components/Window's Footer
local function cases(window: string, under: number?, footer: boolean?): { Case }
	local out: { Case } = {}
	local size = WINDOWS[window]
	local pc = GearLayout.area({ w = 1920, h = 1080 }, size, false, nil, nil, footer)
	table.insert(out, { name = `{window} PC`, area = { w = pc.w, h = pc.h - (under or 0) }, touch = false })
	for _, device in PhoneHud.DEVICES do
		local w, h = PhoneHud.area(device)
		for _, bar in BARS do
			local area = GearLayout.area({ w = w, h = h }, size, true, bar / PhoneHud.SCALE, true, footer)
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

-- a view's own button row sits in its bottom strip: on the area's bottom edge, at most FOOTER high (`rows` rows of
-- buttons more): the companion backpack's action bar, the skills window's buttons and the phone sheet's bar
local function inFooter(case: Case, name: string, r: Rect, rows: number?)
	local high = GearLayout.FOOTER + ((rows or 1) - 1) * (GearLayout.BUTTON_SMALL + GearLayout.GAP)
	T.expect({ case.name, name, math.abs(r.bottom - case.area.h) < 0.001, r.bottom - r.top <= high })
		.toEqual({ case.name, name, true, true })
end

-- the window's Footer row of a view: every part inside the row (the view's width, FOOTER high), none overlapping,
-- the buttons as tall as the row (a touch target on a phone too)
local function footerRow(case: Case, parts: { [string]: Rect }, buttons: { string })
	local row: Case = { name = `{case.name} footer`, area = GearLayout.footerRow(case.area.w), touch = case.touch }
	check(row, parts)
	for _, name in buttons do
		local r = parts[name]
		T.expect({ case.name, name, r.bottom - r.top }).toEqual({ case.name, name, GearLayout.BUTTON })
	end
end

local function theme(block: string): { [string]: number }
	local source = fs.readFile("src/client/UI/Theme.luau")
	local start = assert(string.find(source, `{block} = \{`, 1, true), block)
	local stop = string.find(source, "\n}", start, true)
	local out: { [string]: number } = {}
	for name, value in string.gmatch(string.sub(source, start, stop), "(%w+) = (%d+)") do
		out[name] = assert(tonumber(value), name)
	end
	return out
end

T.describe("GearLayout (UI plan L10, owner 2026-11-10)", function()
	T.it("measures with the window frame's and Theme's sizes, not numbers of its own", function()
		local size = theme("Theme.Size")
		T.expect(GearLayout.FOOTER).toBe(WindowFrame.FOOTER)
		T.expect(GearLayout.FOOTER_GAP).toBe(WindowFrame.FOOTER_GAP)
		T.expect(GearLayout.BUTTON).toBe(size.ButtonHeight)
		T.expect(GearLayout.BUTTON).toBe(WindowFrame.FOOTER)
		T.expect(GearLayout.BUTTON_SMALL).toBe(size.ButtonHeightSmall)
		T.expect(GearLayout.TOUCH).toBe(size.MinTouch)
		T.expect(GearLayout.TOUCH).toBe(WindowFrame.CLOSE)
		T.expect(GearLayout.ROW_TALL).toBe(size.RowHeightTall)
		T.expect(GearLayout.BACKPACK.tabs).toBe(size.TabHeight)
		T.expect(GearLayout.BACKPACK.tabs).toBe(WindowFrame.TAB_HEIGHT)
		-- a view under its window's own tabs starts under the strip Components/Tabs draws, with or without its bar
		for _, scroll in { false, true } do
			T.expect(GearLayout.tabsTop(scroll)).toBe(WindowFrame.tabStrip(scroll).height + GearLayout.GAP)
		end
		-- a window with a Footer gives its view the body above it
		local frame = WindowFrame.rect({ w = 1920, h = 1080 }, WINDOWS.alchemy, nil, false)
		local body = WindowFrame.body(frame, true)
		local area = GearLayout.area({ w = 1920, h = 1080 }, WINDOWS.alchemy, false, nil, nil, true)
		T.expect(area.h).toBe(body.bottom - body.top)
		T.expect(area.h).toBe(frame.content.bottom - frame.content.top - WindowFrame.FOOTER - WindowFrame.FOOTER_GAP)
		-- the windows place their views with those functions, not with the numbers they replaced
		local smith = fs.readFile("src/client/UI/Screens/BlacksmithWindow/init.luau")
		T.expect(string.find(smith, "GearLayout.tabsTop(true)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(smith, "Scroll = true", 1, true) ~= nil).toBe(true) -- the strip with its bar
		local auction = fs.readFile("src/client/UI/Screens/AuctionWindow/init.luau")
		T.expect(string.find(auction, "GearLayout.tabsTop()", 1, true) ~= nil).toBe(true)
		T.expect(string.find(auction, "Scroll = true", 1, true)).toBeNil()
		for _, path in
			{
				"src/client/UI/Screens/BlacksmithWindow/init.luau",
				"src/client/UI/Screens/AuctionWindow/init.luau",
				"src/client/UI/Screens/AlchemyWindow.luau",
				"src/client/UI/Screens/BlacksmithWindow/Craft.luau",
			}
		do
			local source = fs.readFile(path)
			T.expect({ path, string.find(source, "fromOffset(0, 52)", 1, true) == nil }).toEqual({ path, true })
			T.expect({ path, string.find(source, "fromOffset(0, 100)", 1, true) == nil }).toEqual({ path, true })
		end
	end)

	T.it("the services' main buttons stand in the window's Footer", function()
		for _, path in
			{
				"src/client/UI/Screens/BlacksmithWindow/init.luau",
				"src/client/UI/Screens/AuctionWindow/init.luau",
				"src/client/UI/Screens/AlchemyWindow.luau",
				"src/client/UI/Screens/LookWindow.luau",
				"src/client/UI/Screens/TradeWindow.luau",
			}
		do
			local source = fs.readFile(path)
			T.expect({ path, string.find(source, "Footer = ", 1, true) ~= nil }).toEqual({ path, true })
			T.expect({ path, string.find(source, "Window.Parts", 1, true) ~= nil }).toEqual({ path, true })
		end
		-- every tab of a tabbed service gives its footer row, so the footer's static room is never an empty strip
		local views = {
			"BlacksmithWindow/Craft",
			"BlacksmithWindow/Upgrade",
			"BlacksmithWindow/Reroll",
			"BlacksmithWindow/Effect",
			"BlacksmithWindow/Transmog",
			"BlacksmithWindow/Dismantle",
			"AuctionWindow/Browse",
			"AuctionWindow/Sell",
			"AuctionWindow/Mine",
		}
		for _, view in views do
			local path = `src/client/UI/Screens/{view}.luau`
			local source = fs.readFile(path)
			T.expect({ path, string.find(source, "{ View: Instance, Footer: Fusion.Child }", 1, true) ~= nil })
				.toEqual({ path, true })
			T.expect({ path, string.find(source, "\t\tFooter = ", 1, true) ~= nil }).toEqual({ path, true })
			-- the item list stays a column next to the anvil on a phone (no strip on top over a shrunk anvil)
			T.expect({ path, string.find(source, "use(touch) then UDim2.fromOffset(0, 136)", 1, true) == nil })
				.toEqual({ path, true })
		end
	end)

	T.it(
		"trade: the two sides and the warning under them fit the PC body above the footer, a phone scrolls them",
		function()
			local source = fs.readFile("src/client/UI/Screens/TradeWindow.luau")
			local column = assert(tonumber(string.match(source, "local COLUMN = (%d+)")), "COLUMN")
			T.expect(string.find(source, "Position = UDim2.fromOffset(0, COLUMN + 6)", 1, true) ~= nil).toBe(true)
			T.expect(string.find(source, "Scroll = true", 1, true) ~= nil).toBe(true)
			-- the warning is one 26-px line of Small 17 under the sides
			local pc = GearLayout.area({ w = 1920, h = 1080 }, WINDOWS.trade, false, nil, nil, true)
			T.expect(column + 6 + 26 <= pc.h).toBe(true)
			-- on a phone the body above the footer is lower than one side, so the sides scroll (and never reach the footer)
			local device = PhoneHud.DEVICES[1]
			local w, h = PhoneHud.area(device)
			local phone = GearLayout.area({ w = w, h = h }, WINDOWS.trade, true, 58 / PhoneHud.SCALE, true, true)
			T.expect(phone.h < column).toBe(true)
		end
	)

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
			for _, case in cases("blacksmith", GearLayout.tabsTop(true), true) do
				local u = GearLayout.smithUpgrade(case.area)
				check(case, { list = u.list, slot = u.slot, middle = u.middle, result = u.result })
				check(case, { list = u.list, anvil = u.anvil })
				-- "Ulepsz" in the footer row, under the anvil
				footerRow(case, { button = u.button }, { "button" })
				T.expect({ case.name, u.button.left, u.button.right })
					.toEqual({ case.name, u.anvil.left, u.anvil.right })
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

	T.it("the anvil tabs: why the pinned button is greyed out, else its price, stands left of it", function()
		-- review 2026-11-11: the reason was the last line of the anvil's scroll and the price stood under the 150-px
		-- results, both below the fold on PC and on every phone while the button stood pinned in the footer.
		-- Picker.status puts either first in the footer row, Small 17 in at most two lines of the 52-px row.
		local gap = theme("Theme.Padding").Small -- the footer row's UIListLayout padding (Components/Window)
		local picker = fs.readFile("src/client/UI/Screens/BlacksmithWindow/Picker.luau")
		T.expect(string.find(picker, "function Picker.status(", 1, true) ~= nil).toBe(true)
		T.expect(string.find(picker, "UDim2.new(1, -use(props.Inset), 1, 0)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(picker, "TextSize = Theme.TextSize.Small", 1, true) ~= nil).toBe(true)
		-- the price as Picker.price writes it: the gold, then each material with how many it takes
		T.expect(string.find(picker, "◉ {Format.number(cost.gold)}", 1, true) ~= nil).toBe(true)
		T.expect(string.find(picker, "{ItemText.get(use, material.id)} ×{material.n}", 1, true) ~= nil).toBe(true)
		local function price(lang: string, cost: { gold: number, materials: { { id: string, n: number } } }): string
			local parts = { `◉ {Format.number(cost.gold)}` }
			for _, material in cost.materials do
				table.insert(parts, `{ItemName.get(lang, material.id)} ×{material.n}`)
			end
			return table.concat(parts, "  ")
		end
		-- the text keys a block of source returns (a view's `refusal` and `blocker`, a Logic check)
		local function keys(source: string, pattern: string, into: { [string]: boolean })
			local block = assert(string.match(source, pattern), pattern)
			for key in string.gmatch(block, '"([%a]+%.[%w%.]+)"') do
				into[key] = true
			end
		end
		local function logic(name: string): string
			return fs.readFile(`src/shared/Logic/{name}.luau`)
		end
		-- the dearest attempt of each rarity: the last item level, the growth at its cap
		local function dearest(pay: (any) -> { gold: number, materials: { { id: string, n: number } } }): { any }
			local out = {}
			for rarity = Rarities.COMMON, Rarities.MAX do
				table.insert(
					out,
					pay({ id = "probe", ilvl = Config.MaxLevel, rarity = rarity, bonuses = {}, rr = { n = 99 } })
				)
			end
			return out
		end
		local tabs = {
			{
				view = "Reroll",
				buttons = 2,
				inset = "Inset = 2 * (FOOTER_BUTTON + Theme.Padding.Small),",
				logic = { { "Reroll", "function Reroll%.eligible(.-)\nend\n" } },
				costs = dearest(Reroll.payment),
			},
			{
				view = "Effect",
				buttons = 1,
				inset = "Inset = FOOTER_BUTTON + Theme.Padding.Small,",
				logic = { { "EffectReroll", "function EffectReroll%.eligible(.-)\nend\n" } },
				costs = dearest(EffectReroll.payment),
			},
			{
				-- "Przywróć własny" stands next to "Nałóż wygląd" while a look is worn: the line takes the room of two
				view = "Transmog",
				buttons = 2,
				inset = "(if use(worn) ~= OWN then 2 else 1) * (FOOTER_BUTTON + Theme.Padding.Small)",
				logic = { { "Transmog", "function Transmog%.canApply(.-)\nend\n" } },
				costs = dearest(Transmog.cost),
			},
		}
		local checked = 0
		for _, tab in tabs do
			local path = `src/client/UI/Screens/BlacksmithWindow/{tab.view}.luau`
			local source = fs.readFile(path)
			local at = assert(string.find(source, "\t\tFooter = {", 1, true), path)
			local anvil, footer = string.sub(source, 1, at), string.sub(source, at)
			-- the footer's line reads the same `blocker` the button greys out with; the anvil no longer shows it
			for _, needle in
				{ "Picker.status(scope, {", "Reason = blocker,", "Picker.price(use, use(cost))", tab.inset }
			do
				T.expect({ path, needle, string.find(footer, needle, 1, true) ~= nil }).toEqual({ path, needle, true })
			end
			T.expect({ path, string.find(anvil, "use(blocker)", 1, true) == nil }).toEqual({ path, true })
			-- the main button never hides, so the row is never an empty strip; an item it refuses greys it out
			local primary = assert(string.match(footer, 'Variant = "primary",(.-)OnClick'), path)
			T.expect({ path, string.find(primary, "Visible", 1, true) == nil }).toEqual({ path, true })
			T.expect({ path, string.find(primary, "use(blocker) ~= nil", 1, true) ~= nil }).toEqual({ path, true })
			local reasons: { [string]: boolean } = {}
			keys(source, "local refusal = scope:Computed(.-)\n\tend%)", reasons)
			keys(source, "local blocker = scope:Computed(.-)\n\tend%)", reasons)
			for _, entry in tab.logic do
				keys(logic(entry[1]), entry[2], reasons)
			end
			-- an item the tab refuses is a reason too (it left the button enabled with no cost)
			local blocker = assert(string.match(source, "local blocker = scope:Computed(.-)\n\tend%)"))
			T.expect({ path, string.find(blocker, "use(refusal)", 1, true) ~= nil }).toEqual({ path, true })
			local button = assert(tonumber(string.match(source, "local FOOTER_BUTTON = (%d+)")), path)
			for _, case in cases("blacksmith", GearLayout.tabsTop(true), true) do
				local room = case.area.w - tab.buttons * (button + gap)
				T.expect({ case.name, tab.view, room >= 200 }).toEqual({ case.name, tab.view, true })
				for _, lang in { "pl", "en" } do
					local texts: { string } = {}
					for key in reasons do
						local text = Locale.T(key, nil, lang)
						T.expect({ lang, key, text ~= key }).toEqual({ lang, key, true })
						table.insert(texts, text)
					end
					for _, cost in tab.costs do
						table.insert(texts, price(lang, cost))
					end
					for _, text in texts do
						T.expect({ case.name, lang, text, TextCaps.lines(text, 17, room) <= 2 })
							.toEqual({ case.name, lang, text, true })
						checked += 1
					end
				end
			end
		end
		T.expect(checked > 300).toBe(true)
	end)

	T.it("the auction: 'Wystaw' and 'Szukaj' in the footer, the form and the filters scroll above them", function()
		for _, case in cases("auction", GearLayout.tabsTop(), true) do
			local sell = GearLayout.auctionSell(case.area)
			check(case, { items = sell.items, form = sell.form })
			footerRow(case, { button = sell.button }, { "button" })
			T.expect({ case.name, sell.button.left, sell.button.right })
				.toEqual({ case.name, sell.form.left, sell.form.right })
			local browse = GearLayout.auctionBrowse(case.area)
			check(case, { filters = browse.filters, results = browse.results })
			-- "Szukaj" under the filters, the pager (two page buttons and the page line between them) under the results
			footerRow(case, { search = browse.search, pager = browse.pager }, { "search", "pager" })
			T.expect({ case.name, browse.search.right <= browse.filters.right + 0.001 }).toEqual({ case.name, true })
			T.expect({ case.name, browse.pager.left >= browse.results.left - 0.001 }).toEqual({ case.name, true })
			local line = browse.pager.right - browse.pager.left - 2 * (GearLayout.BROWSE.pageButton + 10)
			T.expect({ case.name, line >= 200 }).toEqual({ case.name, true })
			T.expect({ case.name, browse.filters.bottom - browse.filters.top >= 2 * GearLayout.TOUCH })
				.toEqual({ case.name, true })
		end
	end)

	T.it(
		"the alchemist: the queue scrolls with 2 rows on a phone and 5 on PC, 'Odbierz wszystko' in the footer",
		function()
			for _, case in cases("alchemy", nil, true) do
				local a = GearLayout.alchemy(case.area)
				check(case, { recipes = a.recipes, title = a.title, queue = a.queue })
				footerRow(case, { collect = a.collect }, { "collect" })
				T.expect({ case.name, a.collect.left, a.collect.right })
					.toEqual({ case.name, a.queue.left, a.queue.right })
				-- the orders are ListRow `Tall` rows: whole rows in the queue, 2 on a phone and 5 on PC
				T.expect({ case.name, a.rows >= (if case.touch then 2 else 5) }).toEqual({ case.name, true })
				local queueH = a.queue.bottom - a.queue.top
				T.expect({ case.name, a.rows * GearLayout.ROW_TALL + (a.rows - 1) * GearLayout.ALCHEMY.gap <= queueH })
					.toEqual({ case.name, true })
			end
		end
	)

	T.it("the alchemist's group tabs and the backpack's filters fit their strip, pl and en, PC and phones", function()
		-- Components/Tabs takes less padding, then the smaller text (WindowFrame.tabFit) and past that scrolls sideways;
		-- these rows fit before that, "Błogosławieństwa" (a glossary term past the tab cap, TextCaps.TERMS) included
		local function fits(case: Case, keys: { string }, width: number)
			for _, lang in { "pl", "en" } do
				local labels = {}
				for _, key in keys do
					table.insert(labels, Locale.T(key, nil, lang))
				end
				local fit = WindowFrame.tabFit(labels, width - 2 * WindowFrame.TAB_EDGE)
				T.expect({ case.name, lang, fit.scroll }).toEqual({ case.name, lang, false })
			end
		end
		local groups =
			{ "alchemy.group.blessing", "alchemy.group.travel", "alchemy.group.material", "alchemy.group.elixir" }
		for _, case in cases("alchemy", nil, true) do
			local recipes = GearLayout.alchemy(case.area).recipes
			fits(case, groups, recipes.right - recipes.left)
		end
		local filters = {
			"inventory.filter.all",
			"inventory.filter.equipment",
			"inventory.filter.materials",
			"inventory.filter.consumables",
		}
		for _, case in cases("inventory") do
			fits(case, filters, case.area.w)
		end
		for _, case in cases("character") do
			local column = GearLayout.character(case.area, case.touch).backpack
			fits(case, filters, column.right - column.left)
		end
		-- the alchemist's strip is Components/Tabs right above its list
		local alchemy = fs.readFile("src/client/UI/Screens/AlchemyWindow.luau")
		T.expect(
			string.find(alchemy, '{ id = "blessing", label = Text.T(scope, "alchemy.group.blessing") }', 1, true) ~= nil
		)
			.toBe(true)
	end)

	T.it("the appearance window: the preview next to the picker, inside the content (no 792 px in 776)", function()
		for _, case in cases("look", nil, true) do
			local l = GearLayout.look(case.area)
			T.expect({ case.name, l.row }).toEqual({ case.name, true })
			check(case, { preview = l.preview, picker = l.picker })
			T.expect({ case.name, l.preview.right - l.preview.left >= GearLayout.LOOK.minW })
				.toEqual({ case.name, true })
			-- the cost line and "Zmień wygląd" in the footer row
			footerRow(case, { cost = l.cost, button = l.button }, { "button" })
			T.expect({ case.name, l.cost.right - l.cost.left >= 300 }).toEqual({ case.name, true })
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
