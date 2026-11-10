--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, too detailed descriptions, nothing folds"): where a
-- window, its title bar, its ✕, its content and its footer stand, as pure rectangles, so a spec can prove that every
-- registered window fits every screen and that its title bar stays clear of Roblox's top bar. The defaults are today's
-- Components/Window: centred on the full-screen virtual canvas (UI/Scale) at an offset from the centre, full screen on
-- a touch screen, a 52-px title bar with a 44-px ✕ 6 px from its right end, the content Theme.Padding.Large inside.
-- New for the UI plan: a phone's window starts under Roblox's top bar and has a 44-px title bar with tighter padding
-- (`compact`), and a dragged PC window keeps its title bar under the top bar (`clampDrag`). Nothing reads this module
-- yet: UI package C moves Components/Window and WindowManager onto it. All numbers are virtual pixels of the windows'
-- layer, which covers the whole screen (the top bar included), from its top-left corner.

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
WindowFrame.CLOSE_INSET = 6 -- Components/Window: the ✕ from the title bar's right end
WindowFrame.FOOTER = 52 -- Theme.Size.ButtonHeight
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
	local close = box(
		header.right - WindowFrame.CLOSE_INSET - WindowFrame.CLOSE,
		header.top + (headerH - WindowFrame.CLOSE) / 2,
		WindowFrame.CLOSE,
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

return WindowFrame
