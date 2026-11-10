--!strict
-- Content rectangles of the item and character windows (UI plan 2026-11-10, package D; owner 2026-11-10: "niektóre
-- rzeczy zasłaniają inne"). Every function takes the size of the area its window gives the view (the window's content
-- rect, Logic/WindowFrame.content, or the part of it under the window's own tab strip) and never the screen: the
-- audit found a 428-px backpack on an 844x390 phone because the columns came from the viewport, and services whose
-- button slid under the next line on a phone. The rects are relative to the area's top-left corner, in virtual px.
-- A view keeps its list scrolling between its header and its pinned buttons, and its buttons in the bottom strip
-- (the footer: WindowFrame.FOOTER, as the window's footer will be). tests/gearlayout.spec checks every window at its
-- PC content size and on the three phones (PhoneHud.DEVICES, top bar 0 and 58).
--   GearLayout.area(screen, window, touch, topBar?, compact?)  the content size of a window (WindowFrame.rect)
--   GearLayout.character(area, touch)     the character window's columns (Logic/CharacterSections.columns)
--   GearLayout.backpack(area, slot?, hinted?)  the backpack panel: header, hint line, filters, slot grid, actions
--   GearLayout.skillPanel(area, rows)     PC skill details: the lines over the buttons' rows
--   GearLayout.skillSheet(area)           the phone details sheet: the details over one bar of buttons
--   GearLayout.smithUpgrade(area)         the blacksmith's upgrade view
--   GearLayout.auctionSell(area) / GearLayout.auctionBrowse(area)
--   GearLayout.alchemy(area)              the recipes and the brewing queue
--   GearLayout.look(area)                 the appearance window: preview and picker side by side
--   GearLayout.backpackShop(area)         a row of the backpack shop: its text and its button

local CharacterSections = require("./CharacterSections")
local WindowFrame = require("./WindowFrame")

export type Size = WindowFrame.Size
export type Rect = WindowFrame.Rect

local GearLayout = {}

GearLayout.FOOTER = WindowFrame.FOOTER -- the bottom strip that holds a view's buttons
GearLayout.TABS = 52 -- a window's own tab strip with its gap (the blacksmith's and the auction's Tabs)
GearLayout.GAP = 6
GearLayout.BUTTON = 52 -- Theme.Size.ButtonHeight
GearLayout.BUTTON_SMALL = 40 -- Theme.Size.ButtonHeightSmall
GearLayout.TOUCH = 44 -- Theme.Size.MinTouch
GearLayout.MIN_DETAILS = 260 -- the phone sheet keeps this much for the skill details (UI plan L10)

local function rect(left: number, top: number, right: number, bottom: number): Rect
	return { left = left, top = top, right = right, bottom = bottom }
end

-- The content size of a window of `window` size (WindowFrame.rect): on touch the whole layer under the top bar.
function GearLayout.area(screen: Size, window: Size, touch: boolean, topBar: number?, compact: boolean?): Size
	local content = WindowFrame.rect(screen, window, nil, touch, topBar, compact).content
	return { w = content.right - content.left, h = content.bottom - content.top }
end

-- The character window: the left column (name, equipment, sections), the backpack and, when they fit, the statistics.
export type Character = { wide: boolean, compact: boolean, left: Rect, backpack: Rect, right: Rect? }

function GearLayout.character(area: Size, touch: boolean): Character
	local L = CharacterSections.LAYOUT
	local columns = CharacterSections.columns(touch, area.w)
	local left = rect(0, 0, columns.left, area.h)
	if columns.wide then
		local backpackLeft = columns.left + L.gutter
		local backpackRight = backpackLeft + L.middle
		return {
			wide = true,
			compact = columns.compact,
			left = left,
			backpack = rect(backpackLeft, 0, backpackRight, area.h),
			right = rect(backpackRight + L.gutter, 0, area.w, area.h),
		}
	end
	local backpackLeft = columns.left + L.narrowGutter
	return {
		wide = false,
		compact = columns.compact,
		left = left,
		backpack = rect(backpackLeft, 0, math.min(area.w, backpackLeft + L.middle), area.h),
	}
end

-- The backpack panel (UI/Screens/BackpackPanel): the gold and slots header, the overflow / pockets line under it (Small
-- 17, only while `hinted`), the filter tabs, the slot grid (scrolling) and the action bar in the footer.
-- On `touch` the sort button and the action buttons are touch targets (44, UI-ZASADY: ButtonHeightSmall only on PC):
-- the header grows to 44 and the action bar is exactly one button high (its sideways scroll bar, shown only when the
-- buttons overflow, lies over their lower edge), so a phone under Roblox's 58-px top bar keeps 2 rows of 56-px slots
-- with the hint line too.
export type Backpack = {
	header: Rect,
	hint: Rect?,
	tabs: Rect,
	grid: Rect,
	actions: Rect,
	columns: number,
	rows: number,
}

GearLayout.BACKPACK = table.freeze({
	header = 40,
	touchHeader = 44, -- the sort button as a touch target
	hint = 20, -- one Small (17) line
	tabs = 44, -- Theme.Size.TabHeight
	slot = 64,
	touchSlot = 56, -- the character window's backpack on touch
	gap = 6,
	padLeft = 4,
	padRight = 10, -- the grid's scroll bar
})

function GearLayout.backpack(area: Size, slot: number?, hinted: boolean?, touch: boolean?): Backpack
	local B = GearLayout.BACKPACK
	local size = slot or B.slot
	local header = rect(0, 0, area.w, if touch then B.touchHeader else B.header)
	local y = header.bottom
	local hint: Rect? = nil
	if hinted then
		hint = rect(0, y, area.w, y + B.hint)
		y += B.hint
	end
	local tabs = rect(0, y + GearLayout.GAP, area.w, y + GearLayout.GAP + B.tabs)
	local actionsH = if touch then GearLayout.TOUCH else GearLayout.BUTTON_SMALL + GearLayout.GAP
	local actions = rect(0, area.h - actionsH, area.w, area.h)
	local grid = rect(0, tabs.bottom + GearLayout.GAP, area.w, actions.top - GearLayout.GAP)
	local step = size + B.gap
	return {
		header = header,
		hint = hint,
		tabs = tabs,
		grid = grid,
		actions = actions,
		columns = math.max(0, math.floor((area.w - B.padLeft - B.padRight + B.gap) / step)),
		rows = math.max(0, math.floor((grid.bottom - grid.top - 4 + B.gap) / step)),
	}
end

-- PC skill details (the right panel of the skills window): the preview on demand, the scrolling lines, the reasons of
-- the disabled buttons and `rows` rows of buttons pinned to the bottom.
export type SkillPanel = { preview: Rect?, lines: Rect, reason: Rect, buttons: Rect }

GearLayout.SKILL = table.freeze({ preview = 150, reason = 20 })

function GearLayout.skillPanel(area: Size, rows: number, preview: boolean?): SkillPanel
	local n = math.max(1, rows)
	local buttonsH = n * GearLayout.BUTTON_SMALL + (n - 1) * GearLayout.GAP
	local buttons = rect(0, area.h - buttonsH, area.w, area.h)
	local reason = rect(0, buttons.top - 4 - GearLayout.SKILL.reason, area.w, buttons.top - 4)
	local top = if preview then GearLayout.SKILL.preview + 8 else 0
	return {
		preview = if preview then rect(0, 0, area.w, GearLayout.SKILL.preview) else nil,
		lines = rect(0, top, area.w, reason.top - 4),
		reason = reason,
		buttons = buttons,
	}
end

-- The phone details sheet of the skills window: the details (scrolling; the name is their first line, the breakpoint
-- cards choose in their own section) over one bar: back, the selection's buttons and, while ranks are reserved,
-- "Cancel" and "Confirm (+N)" (the window's own reservation bar steps aside while the sheet is open). One bar instead of
-- a top bar, a pinned A / B row and an action bar: the details keep at least MIN_DETAILS on an 844x390 phone under a
-- 58-px top bar (306 px of content).
export type SkillSheet = { body: Rect, bar: Rect }

function GearLayout.skillSheet(area: Size): SkillSheet
	local bar = rect(0, area.h - GearLayout.TOUCH, area.w, area.h)
	return { body = rect(0, 0, area.w, bar.top), bar = bar }
end

-- The blacksmith's upgrade view (under the window's tabs): the items to pick on the left; on the right the anvil (a
-- panel that flashes with the result) holding the picked item, a scrolling middle (name, comparison, chance and cost,
-- the Scroll of Protection) and the result line, and "Ulepsz" under the anvil in the footer, so the button never
-- covers the scroll's line on a phone. A short area (a phone) puts the item next to the middle instead of above it.
export type SmithUpgrade = {
	list: Rect,
	anvil: Rect,
	slot: Rect,
	middle: Rect,
	result: Rect,
	button: Rect,
	row: boolean, -- the item stands left of the middle
}

GearLayout.SMITH = table.freeze({ list = 262, gutter = 18, slot = 84, result = 28, pad = 10, minMiddle = 120 })

function GearLayout.smithUpgrade(area: Size): SmithUpgrade
	local S = GearLayout.SMITH
	local x = S.list + S.gutter
	local width = area.w - x
	local button = rect(x + width * 0.1, area.h - GearLayout.BUTTON, x + width * 0.9, area.h)
	local anvil = rect(x, 0, area.w, button.top - GearLayout.GAP)
	local left, right = anvil.left + S.pad, anvil.right - S.pad
	local result = rect(left, anvil.bottom - S.pad - S.result, right, anvil.bottom - S.pad)
	local slot = rect(x + width / 2 - S.slot / 2, S.pad, x + width / 2 + S.slot / 2, S.pad + S.slot)
	local middle = rect(left, slot.bottom + 8, right, result.top - 4)
	local row = middle.bottom - middle.top < S.minMiddle
	if row then
		slot = rect(left, S.pad, left + S.slot, S.pad + S.slot)
		middle = rect(slot.right + 12, S.pad, right, result.top - 4)
	end
	return {
		list = rect(0, 0, S.list, area.h),
		anvil = anvil,
		slot = slot,
		middle = middle,
		result = result,
		button = button,
		row = row,
	}
end

-- The auction's "Sell" view: the backpack's items (left half), the form (right half, scrolling) over "Wystaw" pinned
-- in the footer.
export type AuctionSell = { items: Rect, form: Rect, button: Rect }

function GearLayout.auctionSell(area: Size): AuctionSell
	local half = area.w / 2
	local button = rect(half + 8, area.h - GearLayout.BUTTON, area.w, area.h)
	return {
		items = rect(0, 0, half - 8, area.h),
		form = rect(half + 8, 0, area.w, button.top - GearLayout.GAP),
		button = button,
	}
end

-- The auction's "Browse" view: the filters (scrolling) over "Szukaj" pinned in the footer, the results over the pager.
export type AuctionBrowse = { filters: Rect, search: Rect, results: Rect, pager: Rect }

GearLayout.BROWSE = table.freeze({ filters = 250, gutter = 10, pager = 46 })

function GearLayout.auctionBrowse(area: Size): AuctionBrowse
	local B = GearLayout.BROWSE
	local search = rect(0, area.h - GearLayout.TOUCH, B.filters, area.h)
	local x = B.filters + B.gutter
	local pager = rect(x, area.h - B.pager, area.w, area.h)
	return {
		filters = rect(0, 0, B.filters, search.top - GearLayout.GAP),
		search = search,
		results = rect(x, 0, area.w, pager.top - 8),
		pager = pager,
	}
end

-- The alchemist's window: the recipes (tabs and a scrolling list) and the brewing queue on the right: its title, the
-- slots as a scrolling list and "Odbierz wszystko" pinned in the footer.
export type Alchemy = { recipes: Rect, title: Rect, queue: Rect, collect: Rect, rows: number }

GearLayout.ALCHEMY = table.freeze({ queue = 270, gutter = 16, title = 36, slot = 84, gap = 8 })

function GearLayout.alchemy(area: Size): Alchemy
	local A = GearLayout.ALCHEMY
	local x = area.w - A.queue
	local collect = rect(x, area.h - GearLayout.BUTTON, area.w, area.h)
	local queue = rect(x, A.title + 4, area.w, collect.top - 8)
	return {
		recipes = rect(0, 0, x - A.gutter, area.h),
		title = rect(x, 0, area.w, A.title),
		queue = queue,
		collect = collect,
		rows = math.max(0, math.floor((queue.bottom - queue.top + A.gap) / (A.slot + A.gap))),
	}
end

-- The appearance window: the preview (its 330 x 420 shape, smaller when the area is) next to the 440-wide picker; one
-- column only when the two do not fit side by side.
export type Look = { row: boolean, preview: Rect, picker: Rect }

GearLayout.LOOK = table.freeze({ picker = 440, gap = 22, previewW = 330, previewH = 420, minW = 180 })

function GearLayout.look(area: Size): Look
	local L = GearLayout.LOOK
	local room = area.w - L.picker - L.gap
	if room >= L.minW then
		local h = math.min(L.previewH, area.h - 16, room * L.previewH / L.previewW)
		local w = math.floor(h * L.previewW / L.previewH)
		h = math.floor(h)
		local left = math.floor((area.w - (w + L.gap + L.picker)) / 2)
		return {
			row = true,
			preview = rect(left, 0, left + w, h),
			picker = rect(left + w + L.gap, 0, left + w + L.gap + L.picker, area.h),
		}
	end
	local w = math.min(area.w, L.previewW)
	local h = math.floor(w * L.previewH / L.previewW)
	local x = math.floor((area.w - w) / 2)
	local pickerW = math.min(area.w, L.picker)
	local px = math.floor((area.w - pickerW) / 2)
	return {
		row = false,
		preview = rect(x, 0, x + w, h),
		picker = rect(px, h + L.gap, px + pickerW, math.max(area.h, h + L.gap + 1)),
	}
end

-- A row of the backpack shop (UI/Screens/BackpackShop): the icon, two lines of text and the buy button; the text ends
-- before the button (truncated, never under it).
export type ShopRow = { icon: Rect, text: Rect, button: Rect, height: number }

GearLayout.SHOP_ROW = table.freeze({ height = 70, icon = 56, button = 170, buttonNarrow = 130, scroll = 10 })

function GearLayout.backpackShop(area: Size): ShopRow
	local R = GearLayout.SHOP_ROW
	local w = area.w - R.scroll
	local buttonW = if w < 560 then R.buttonNarrow else R.button
	local button = rect(w - 8 - buttonW, (R.height - 48) / 2, w - 8, (R.height + 48) / 2)
	return {
		icon = rect(7, 7, 7 + R.icon, 7 + R.icon),
		text = rect(74, 6, button.left - 8, R.height - 6),
		button = button,
		height = R.height,
	}
end

return GearLayout
