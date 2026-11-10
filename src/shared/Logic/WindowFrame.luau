--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, too detailed descriptions, nothing folds"): where a
-- window, its title bar, its ✕, its content and its footer stand, as pure rectangles, so a spec can prove that every
-- registered window fits every screen and that its title bar stays clear of Roblox's top bar. The defaults are today's
-- Components/Window: centred on the full-screen virtual canvas (UI/Scale) at an offset from the centre, full screen on
-- a touch screen, a 52-px title bar with a 44-px ✕ 6 px from its right end, the content Theme.Padding.Large inside.
-- New for the UI plan: a phone's window starts under Roblox's top bar and has a 44-px title bar with tighter padding
-- (`compact`), and a dragged PC window keeps its title bar under the top bar (`clampDrag`). Components/Window,
-- Components/Modal and WindowManager read it (UI package C); tests/uiframe.spec proves the rules on it. All numbers are
-- virtual pixels of the windows' layer, which covers the whole screen (the top bar included), from its top-left corner.

local TextCaps = require("./TextCaps")

local WindowFrame = {}

export type Size = { w: number, h: number }
export type Point = { x: number, y: number }
export type Rect = { left: number, top: number, right: number, bottom: number }
-- `content` is the padded body under the title bar; `footer` is the strip at its bottom where a window with actions
-- puts its buttons (its other content then stands above the footer).
export type Frame = { window: Rect, header: Rect, close: Rect, content: Rect, footer: Rect }

-- Theme's numbers (client code; tests/uiframe.spec reads Theme.luau to keep them equal).
WindowFrame.HEADER = 52 -- Theme.Size.WindowHeader
WindowFrame.HEADER_COMPACT = 44 -- Theme.Size.WindowHeaderCompact: a phone's title bar
WindowFrame.PADDING = 22 -- Theme.Padding.Large
WindowFrame.PADDING_COMPACT = 14 -- Theme.Padding.Medium: a phone keeps 280 px of content under a 58-px top bar
WindowFrame.CLOSE = 44 -- Theme.Size.MinTouch: the ✕
-- UI package C: a phone's ✕ is 52 wide and as tall as its 44-px title bar, an easier target for a thumb.
WindowFrame.CLOSE_WIDE = 52
WindowFrame.CLOSE_INSET = 6 -- Components/Window: the ✕ from the title bar's right end
WindowFrame.FOOTER = 52 -- Theme.Size.ButtonHeight
-- UI package C: a window's pinned footer (Components/Window's Footer) stands this far under the rest of its content.
WindowFrame.FOOTER_GAP = 8 -- Theme.Padding.Small
WindowFrame.MODAL_W = 520 -- Components/Modal, Theme.Size.ModalWidth
-- Components/Window: a dragged window keeps this much of its width on the screen.
WindowFrame.KEEP = 80
-- The title bar stays this far under Roblox's top bar (the UI plan's layout rule L7).
WindowFrame.TOP_GAP = 8
-- WindowManager: a service and its companion backpack stand this far apart.
WindowFrame.PAIR_GAP = 12

local function box(left: number, top: number, w: number, h: number): Rect
	return { left = left, top = top, right = left + w, bottom = top + h }
end

-- The rectangles of a window of `size` on a `screen` (the windows' layer): on PC centred at `offset` from the centre;
-- on a touch screen the whole layer from the bottom of Roblox's top bar (`topBar` virtual pixels tall, default 0: the
-- whole layer, as today). `compact` (a phone): the shorter title bar and padding. A modal (Components/Modal) is a
-- centred window MODAL_W wide on every device: rect(screen, { w = MODAL_W, h = height }, nil, false).window.
function WindowFrame.rect(
	screen: Size,
	size: Size,
	offset: Point?,
	touch: boolean,
	topBar: number?,
	compact: boolean?
): Frame
	local window: Rect
	if touch then
		local top = topBar or 0
		window = { left = 0, top = top, right = screen.w, bottom = screen.h }
	else
		local o = offset or { x = 0, y = 0 }
		window = box(screen.w / 2 + o.x - size.w / 2, screen.h / 2 + o.y - size.h / 2, size.w, size.h)
	end
	local headerH = if compact then WindowFrame.HEADER_COMPACT else WindowFrame.HEADER
	local pad = if compact then WindowFrame.PADDING_COMPACT else WindowFrame.PADDING
	local header = { left = window.left, top = window.top, right = window.right, bottom = window.top + headerH }
	local closeW = if compact then WindowFrame.CLOSE_WIDE else WindowFrame.CLOSE
	local close = box(
		header.right - WindowFrame.CLOSE_INSET - closeW,
		header.top + (headerH - WindowFrame.CLOSE) / 2,
		closeW,
		WindowFrame.CLOSE
	)
	local content = {
		left = window.left + pad,
		top = header.bottom + pad,
		right = window.right - pad,
		bottom = window.bottom - pad,
	}
	local footer = {
		left = content.left,
		top = content.bottom - WindowFrame.FOOTER,
		right = content.right,
		bottom = content.bottom,
	}
	return { window = window, header = header, close = close, content = content, footer = footer }
end

-- The offset of a PC window of `size` dragged to `offset`: at least KEEP of its width and its whole title bar stay on
-- the `screen`, and the title bar never goes higher than TOP_GAP under Roblox's top bar (`topBar` virtual pixels;
-- today's Window lets it reach the screen's top edge, under the bar).
function WindowFrame.clampDrag(screen: Size, size: Size, offset: Point, topBar: number?): Point
	local maxX = math.max(0, screen.w / 2 + size.w / 2 - WindowFrame.KEEP)
	local maxY = math.max(0, screen.h / 2 + size.h / 2 - WindowFrame.HEADER)
	local minY = math.min((topBar or 0) + WindowFrame.TOP_GAP - (screen.h - size.h) / 2, maxY)
	return { x = math.clamp(offset.x, -maxX, maxX), y = math.clamp(offset.y, minY, maxY) }
end

-- The offsets of the companion backpack and of a service window opened next to it (WindowManager): side by side,
-- PAIR_GAP apart, the backpack on the left, the pair centred together.
function WindowFrame.pair(service: Size, backpack: Size): (Point, Point)
	local half = (backpack.w + service.w + WindowFrame.PAIR_GAP) / 2
	return { x = -half + backpack.w / 2, y = 0 }, { x = half - service.w / 2, y = 0 }
end

-- UI package C: the part of a window's content above its pinned footer (Components/Window's Footer), FOOTER_GAP over
-- it; the whole content for a window without one. Layout specs of the windows (packages D and E) measure their body
-- in it.
function WindowFrame.body(frame: Frame, footer: boolean?): Rect
	local c = frame.content
	if not footer then
		return { left = c.left, top = c.top, right = c.right, bottom = c.bottom }
	end
	return { left = c.left, top = c.top, right = c.right, bottom = frame.footer.top - WindowFrame.FOOTER_GAP }
end

-- UI package C (Components/Tabs, owner 2026-11-10: the quest journal's "Tygodniowe" tab stood past the strip's end):
-- the look of a tab strip, one for the whole row. The first level whose row fits the strip; past the last one the
-- strip scrolls sideways. Side padding and text size: Theme.Padding.Large / Medium / Small, Theme.TextSize.Body / Small.
WindowFrame.TAB_GAP = 8 -- Theme.Padding.Small, between two tabs
WindowFrame.TAB_LEVELS = table.freeze({
	table.freeze({ pad = 22, size = 20 }),
	table.freeze({ pad = 14, size = 20 }),
	table.freeze({ pad = 8, size = 17 }),
})
export type TabFit = { pad: number, size: number, width: number, scroll: boolean }

-- The width of a row of tabs with these labels (Logic/TextCaps.width), `pad` on each side of a label.
function WindowFrame.tabRow(labels: { string }, pad: number, size: number): number
	local width = 0
	for i, label in labels do
		width += TextCaps.width(TextCaps.plain(label), size) + 2 * pad + (if i > 1 then WindowFrame.TAB_GAP else 0)
	end
	return width
end

-- The level of a tab row with `labels` in a strip `room` virtual pixels wide, the row's width at it, and whether the
-- strip has to scroll (the row does not fit even at the last level).
function WindowFrame.tabFit(labels: { string }, room: number): TabFit
	local levels = WindowFrame.TAB_LEVELS
	for i, level in levels do
		local width = WindowFrame.tabRow(labels, level.pad, level.size)
		if width <= room or i == #levels then
			return { pad = level.pad, size = level.size, width = width, scroll = width > room }
		end
	end
	error("WindowFrame.TAB_LEVELS is empty")
end

-- UI package C: a modal (Components/Modal) on a `screen` with Roblox's top bar `topBar` virtual pixels tall, its
-- dialog `height` tall as laid out: MODAL_W wide (less on a narrow screen), at most the screen less the top bar less
-- 2 x TOP_GAP tall (its body scrolls), centred in the room under the top bar.
function WindowFrame.modal(screen: Size, height: number, topBar: number?): Rect
	local bar = topBar or 0
	local w = math.min(WindowFrame.MODAL_W, screen.w - 2 * WindowFrame.TOP_GAP)
	local h = math.min(height, screen.h - bar - 2 * WindowFrame.TOP_GAP)
	return box((screen.w - w) / 2, bar + (screen.h - bar - h) / 2, w, h)
end

return WindowFrame
