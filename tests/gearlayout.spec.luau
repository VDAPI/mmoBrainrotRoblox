--!strict
-- UI plan 2026-11-10, L10 (owner 2026-11-10: "niektóre rzeczy zasłaniają inne"): the item and character windows lay
-- out from their content rect (Logic/GearLayout), not the screen. At every registered PC size and on the three phones
-- (PhoneHud.DEVICES, Roblox's top bar 0 and 58, the phone's compact title bar): no negative size, every rect inside its
-- area and no two overlapping, the buttons pinned to the bottom (the footer), at least 2 slot rows on a phone and 5 on
-- PC, at least 260 px of skill details on a phone. The windows read the same functions (source checks at the end).

local fs = require("@lune/fs")

local GearLayout = require("../src/shared/Logic/GearLayout")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local T = require("./Test")
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

local function cases(window: string, under: number?): { Case }
	local out: { Case } = {}
	local size = WINDOWS[window]
	local pc = GearLayout.area({ w = 1920, h = 1080 }, size, false)
	table.insert(out, { name = `{window} PC`, area = { w = pc.w, h = pc.h - (under or 0) }, touch = false })
	for _, device in PhoneHud.DEVICES do
		local w, h = PhoneHud.area(device)
		for _, bar in { 0, 58 } do
			local area = GearLayout.area({ w = w, h = h }, size, true, bar, true)
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
			local area = GearLayout.area({ w = w, h = h }, WINDOWS.character, true, 58, true)
			T.expect({ device.name, area.h >= 280 }).toEqual({ device.name, true })
			local frame = WindowFrame.rect({ w = w, h = h }, WINDOWS.character, nil, true, 58, true)
			T.expect(area.w).toBe(frame.content.right - frame.content.left)
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
		local function backpackCases(): { Case }
			local out = cases("inventory")
			-- and the backpack column of the character window
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
			for _, hinted in { false, true } do
				local b = GearLayout.backpack(case.area, nil, hinted)
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
			end
		end
	end)

	T.it(
		"skill details: at least 260 px on a phone (one bar), the PC panel's buttons pinned under the lines",
		function()
			for _, case in cases("skills") do
				if case.touch then
					local sheet = GearLayout.skillSheet(case.area)
					check(case, { body = sheet.body, bar = sheet.bar })
					inFooter(case, "bar", sheet.bar)
					T.expect({ case.name, sheet.body.bottom - sheet.body.top >= GearLayout.MIN_DETAILS })
						.toEqual({ case.name, true })
					T.expect({ case.name, sheet.bar.bottom - sheet.bar.top >= GearLayout.TOUCH })
						.toEqual({ case.name, true })
				else
					-- the right panel under the header (44 + 6) and the tabs (46 + 6), next to the 510-px tree
					local panel = { w = case.area.w - 522, h = case.area.h - 102 }
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
							T.expect({ case.name, rows, preview, p.lines.bottom - p.lines.top >= 150 })
								.toEqual({ case.name, rows, preview, true })
						end
					end
				end
			end
		end
	)

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
		end
	end)
end)
