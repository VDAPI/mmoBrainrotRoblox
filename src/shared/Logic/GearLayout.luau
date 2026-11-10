--!strict
-- Content rectangles of the item and character windows (UI plan 2026-11-10, package D; owner 2026-11-10: "niektóre
-- rzeczy zasłaniają inne"). Every function takes the size of the area its window gives the view (the window's content
-- rect, Logic/WindowFrame.content, or the part of it under the window's own tab strip) and never the screen: the
-- audit found a 428-px backpack on an 844x390 phone because the columns came from the viewport, and services whose
-- button slid under the next line on a phone. The rects are relative to the area's top-left corner, in virtual px.
-- A view keeps its list scrolling between its header and its pinned buttons. Adoption stage (UI package D after C,
-- 2026-11-10): the services' main buttons stand in Components/Window's Footer, pinned under the content outside its
-- scroll, so a service's view gets the body above it (WindowFrame.body) and the functions give the footer's parts in
-- the footer row's own rect (the view's width, FOOTER high). The companion backpack and the skills window keep their
-- own bars (the panel is shared with the character window; the skills window has a bar per selection).
-- tests/gearlayout.spec checks every window at its PC content size and on the three phones (PhoneHud.DEVICES) under
-- Roblox's top bar of 0, 36 and 58 real px, which a window takes in virtual px (bar / PhoneHud.SCALE, as
-- Components/Window does with Scale.TopBar / Scale.Value).
--   GearLayout.area(screen, window, touch, topBar?, compact?, footer?)  a window's content (WindowFrame.rect), the
--                                         body above its Footer with `footer` (WindowFrame.body)
--   GearLayout.tabsTop(scroll?)           where a view starts under its window's own tab strip (WindowFrame.tabStrip)
--   GearLayout.character(area, touch)     the character window's columns (Logic/CharacterSections.columns)
--   GearLayout.backpack(area, slot?, hinted?, touch?)  the backpack panel: header, hint line, filters, slots, actions
--   GearLayout.skillPanelArea(area)       the PC skill details panel's inner size in the skills window's content
--   GearLayout.skillPanel(area, rows)     PC skill details: the lines over the buttons' rows
--   GearLayout.sheetOverhang(compact)     how far the phone details sheet reaches over the window's bottom padding
--   GearLayout.skillSheet(area)           the phone details sheet: the details over one bar of buttons
--   GearLayout.smithUpgrade(area)         the blacksmith's upgrade view ("Ulepsz" in the footer)
--   GearLayout.auctionSell(area) / GearLayout.auctionBrowse(area)  ("Wystaw", "Szukaj" and the pager in the footer)
--   GearLayout.alchemy(area)              the recipes and the brewing queue ("Odbierz wszystko" in the footer)
--   GearLayout.look(area)                 the appearance window: preview and picker side by side
--   GearLayout.backpackShop(area)         a row of the backpack shop: its text and its button

local CharacterSections = require("./CharacterSections")
local WindowFrame = require("./WindowFrame")

export type Size = WindowFrame.Size
export type Rect = WindowFrame.Rect

local GearLayout = {}

-- Theme's sizes as the window frame has them (Logic is pure; tests/gearlayout.spec reads Theme.luau to keep them equal)
GearLayout.FOOTER = WindowFrame.FOOTER -- Components/Window's Footer row: the services' main buttons
GearLayout.FOOTER_GAP = WindowFrame.FOOTER_GAP -- between the body and the footer (its rule in the middle)
GearLayout.GAP = 6
GearLayout.BUTTON = WindowFrame.FOOTER -- Theme.Size.ButtonHeight: a footer's buttons are as tall as the row
GearLayout.BUTTON_SMALL = 40 -- Theme.Size.ButtonHeightSmall (PC only; a touch screen takes TOUCH)
GearLayout.TOUCH = WindowFrame.CLOSE -- Theme.Size.MinTouch
GearLayout.ROW_TALL = 64 -- Theme.Size.RowHeightTall: Components/ListRow with `Tall` (a line under the name)
GearLayout.MIN_DETAILS = 260 -- the phone sheet keeps this much for the skill details (UI plan L10)

local function rect(left: number, top: number, right: number, bottom: number): Rect
	return { left = left, top = top, right = right, bottom = bottom }
end

-- The content size of a window of `window` size (WindowFrame.rect): on touch the whole layer under the top bar.
-- `topBar` is in virtual px (Roblox's bar in real px divided by the UI scale). With `footer` (the window has
-- Components/Window's Footer) the body above it: FOOTER and FOOTER_GAP less (WindowFrame.body).
function GearLayout.area(
	screen: Size,
	window: Size,
	touch: boolean,
	topBar: number?,
	compact: boolean?,
	footer: boolean?
): Size
	local body = WindowFrame.body(WindowFrame.rect(screen, window, nil, touch, topBar, compact), footer)
	return { w = body.right - body.left, h = body.bottom - body.top }
end

-- Where a view starts under its window's own tab strip (Components/Tabs: WindowFrame.tabStrip, with the scroll bar's
-- room when the strip has `Scroll`) and GAP under it: the blacksmith's six tabs scroll, the auction's three do not.
function GearLayout.tabsTop(scroll: boolean?): number
	return WindowFrame.tabStrip(scroll).height + GearLayout.GAP
end

-- The footer row of a view `width` wide (Components/Window's Footer: its buttons are BUTTON high, the row's height).
function GearLayout.footerRow(width: number): Size
	return { w = width, h = GearLayout.FOOTER }
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
	tabs = WindowFrame.TAB_HEIGHT, -- Components/Tabs (Theme.Size.TabHeight)
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

-- `tree` and `gutter`: the tree's column left of the panel (SkillsWindow/PathTab.LIST_WIDTH) and the gap after it;
-- `top`: the header and the tabs over both (SkillsWindow/Header.HEIGHT, TabBar.HEIGHT and a 6-px gap after each);
-- `pad`: the panel's padding (Theme.Padding.Medium). tests/gearlayout.spec checks them against the window's source.
GearLayout.SKILL = table.freeze({ preview = 150, reason = 20, tree = 510, gutter = 12, top = 102, pad = 14 })

-- The PC details panel's inner size (inside its padding) in a skills window whose content is `area`: the window lays
-- the panel out from this until the panel is measured, and the spec checks the panel at this size.
function GearLayout.skillPanelArea(area: Size): Size
	local S = GearLayout.SKILL
	return { w = area.w - S.tree - S.gutter - 2 * S.pad, h = area.h - S.top - 2 * S.pad }
end

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
-- a top bar, a pinned A / B row and an action bar. The sheet covers the window's content and reaches over its bottom
-- padding (sheetOverhang), so on an 844x390 phone under Roblox's 58-px top bar (68.5 virtual px: 295.5 px of content)
-- the details keep 261.5 px, at least MIN_DETAILS.
export type SkillSheet = { body: Rect, bar: Rect }

GearLayout.SHEET_EDGE = 4 -- the sheet stops this far above the window's bottom edge, clear of its frame lines

-- How far below the window's content the phone sheet reaches: the window's bottom padding (WindowFrame.PADDING, or
-- PADDING_COMPACT on a phone's compact window) down to SHEET_EDGE. `area` of skillSheet is the content's size plus this.
function GearLayout.sheetOverhang(compact: boolean): number
	return (if compact then WindowFrame.PADDING_COMPACT else WindowFrame.PADDING) - GearLayout.SHEET_EDGE
end

function GearLayout.skillSheet(area: Size): SkillSheet
	local bar = rect(0, area.h - GearLayout.TOUCH, area.w, area.h)
	return { body = rect(0, 0, area.w, bar.top), bar = bar }
end

-- The blacksmith's upgrade view (under the window's tabs, above its footer): the items to pick on the left; on the
-- right the anvil (a panel that flashes with the result) holding the picked item, a scrolling middle (name,
-- comparison, chance and cost, the Scroll of Protection) and the result line. "Ulepsz" stands in the window's footer
-- under the anvil (`button`, in the footer row), so it never covers the scroll's line on a phone. A short area (a
-- phone) puts the item next to the middle instead of above it.
export type SmithUpgrade = {
	list: Rect,
	anvil: Rect,
	slot: Rect,
	middle: Rect,
	result: Rect,
	button: Rect, -- in the footer row (footerRow(area.w))
	row: boolean, -- the item stands left of the middle
}

GearLayout.SMITH = table.freeze({ list = 262, gutter = 18, slot = 84, result = 28, pad = 10, minMiddle = 120 })

function GearLayout.smithUpgrade(area: Size): SmithUpgrade
	local S = GearLayout.SMITH
	local x = S.list + S.gutter
	local width = area.w - x
	local button = rect(x, 0, area.w, GearLayout.BUTTON)
	local anvil = rect(x, 0, area.w, area.h)
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

-- The auction's "Sell" view: the backpack's items (left half), the form (right half, scrolling); "Wystaw przedmiot"
-- in the window's footer under the form (`button`, in the footer row).
export type AuctionSell = { items: Rect, form: Rect, button: Rect }

function GearLayout.auctionSell(area: Size): AuctionSell
	local half = area.w / 2
	return {
		items = rect(0, 0, half - 8, area.h),
		form = rect(half + 8, 0, area.w, area.h),
		button = rect(half + 8, 0, area.w, GearLayout.BUTTON),
	}
end

-- The auction's "Browse" view: the filters (scrolling) and the results; the window's footer holds "Szukaj" under the
-- filters and the pager under the results (`search` and `pager`, in the footer row).
export type AuctionBrowse = { filters: Rect, search: Rect, results: Rect, pager: Rect }

GearLayout.BROWSE = table.freeze({ filters = 250, gutter = 10, pageButton = 110 })

function GearLayout.auctionBrowse(area: Size): AuctionBrowse
	local B = GearLayout.BROWSE
	local x = B.filters + B.gutter
	return {
		filters = rect(0, 0, B.filters, area.h),
		search = rect(0, 0, B.filters, GearLayout.BUTTON),
		results = rect(x, 0, area.w, area.h),
		pager = rect(x, 0, area.w, GearLayout.BUTTON),
	}
end

-- The alchemist's window: the recipes (tabs and a scrolling list) and the brewing queue on the right: its title and
-- the orders as list rows (Components/ListRow `Tall`: the name over the time left, a progress line under them),
-- scrolling; "Odbierz wszystko" in the window's footer under the queue (`collect`, in the footer row).
export type Alchemy = { recipes: Rect, title: Rect, queue: Rect, collect: Rect, rows: number }

GearLayout.ALCHEMY = table.freeze({ queue = 270, gutter = 16, title = 36, gap = 6 })

function GearLayout.alchemy(area: Size): Alchemy
	local A = GearLayout.ALCHEMY
	local x = area.w - A.queue
	local queue = rect(x, A.title + 4, area.w, area.h)
	return {
		recipes = rect(0, 0, x - A.gutter, area.h),
		title = rect(x, 0, area.w, A.title),
		queue = queue,
		collect = rect(x, 0, area.w, GearLayout.BUTTON),
		rows = math.max(0, math.floor((queue.bottom - queue.top + A.gap) / (GearLayout.ROW_TALL + A.gap))),
	}
end

-- The appearance window: the preview (its 330 x 420 shape, smaller when the area is) next to the 440-wide picker; one
-- column only when the two do not fit side by side. The cost and "Zmień wygląd" stand in the window's footer
-- (`cost` and `button`, in the footer row: the button at its right end, the cost line left of it), so the preview
-- takes the body's whole height: the footer's gap and rule keep it off the button (it kept 16 px above the window's
-- edge before).
export type Look = { row: boolean, preview: Rect, picker: Rect, cost: Rect, button: Rect }

GearLayout.LOOK = table.freeze({ picker = 440, gap = 22, previewW = 330, previewH = 420, minW = 180, button = 220 })

-- The footer's cost line and button of a view `width` wide.
local function lookFooter(width: number): (Rect, Rect)
	local L = GearLayout.LOOK
	local button = rect(width - L.button, 0, width, GearLayout.BUTTON)
	return rect(0, 0, button.left - GearLayout.GAP, GearLayout.BUTTON), button
end

function GearLayout.look(area: Size): Look
	local L = GearLayout.LOOK
	local room = area.w - L.picker - L.gap
	if room >= L.minW then
		local h = math.min(L.previewH, area.h, room * L.previewH / L.previewW)
		local w = math.floor(h * L.previewW / L.previewH)
		h = math.floor(h)
		local left = math.floor((area.w - (w + L.gap + L.picker)) / 2)
		local cost, button = lookFooter(area.w)
		return {
			row = true,
			preview = rect(left, 0, left + w, h),
			picker = rect(left + w + L.gap, 0, left + w + L.gap + L.picker, area.h),
			cost = cost,
			button = button,
		}
	end
	local w = math.min(area.w, L.previewW)
	local h = math.floor(w * L.previewH / L.previewW)
	local x = math.floor((area.w - w) / 2)
	local pickerW = math.min(area.w, L.picker)
	local px = math.floor((area.w - pickerW) / 2)
	local cost, button = lookFooter(area.w)
	return {
		row = false,
		preview = rect(x, 0, x + w, h),
		picker = rect(px, h + L.gap, px + pickerW, math.max(area.h, h + L.gap + 1)),
		cost = cost,
		button = button,
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
