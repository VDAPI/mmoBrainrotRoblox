--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, too detailed descriptions, nothing folds"): where a
-- popover (a tooltip, an item tooltip, an (i) note's box) stands next to the element it belongs to, as a pure
-- rectangle: on the preferred side of its anchor, on the opposite side when there is no room (below / above flip),
-- then beside it; inside the safe area, MARGIN from its edges; never over its anchor; off a rectangle it is told to
-- avoid (a window's action bar) whenever another side has room. The defaults are today's Components/InfoTip: GAP under
-- the anchor, left edges aligned (right edges when the box would run off the right side), above it when there is no
-- room below. Today's cursor tooltips are a pointer anchor (`cursor`) with their own gap: Components/Tooltip 18 right
-- and 22 down (TOOLTIP), ItemTooltip 20 and 20 (ITEM, flipping left of the cursor as today). Components/Tooltip,
-- ItemTooltip and InfoTip place themselves with it (UI package C; on a touch screen the item tooltip takes the half of
-- the screen away from the tapped slot, `away`). All numbers are virtual pixels of one layer.
-- Review 2026-11-10: `away` stands at the top of its half again, under a full-screen window's title bar, as the touch
-- tooltip did before (at the slot's height it went down over the backpack's Załóż / Użyj bar), and keeps off a
-- window's action strip by rising over that title bar when it is too tall for the room between them.
-- Review 2026-11-11: a popover taller than that room (the touch item tooltip's full view: 20-25 lines) is capped at
-- it (`awayRoom`, `capped`): its body scrolls and what is pinned under the body (the "Mniej ▾" row) stays on the
-- screen, instead of the panel covering the title bar and losing its bottom under the screen's edge.

local Popover = {}

export type Rect = { left: number, top: number, right: number, bottom: number }
export type Size = { w: number, h: number }
export type Side = "below" | "above" | "right" | "left"
-- prefer: the side to try first (default "below"); avoid: a rectangle to keep off when a side with room is free of
-- it; gap: between the anchor and the popover (default GAP); margin: from the safe area's edges (default MARGIN);
-- top (`away` only): the line its top edge stands under when there is room, the bottom of a window's title bar;
-- keepOff (`away` only): more rectangles to keep off with `avoid` (the ones windows register).
export type Options = {
	prefer: Side?,
	avoid: Rect?,
	gap: number?,
	margin: number?,
	top: number?,
	keepOff: { Rect }?,
}

Popover.MARGIN = 8 -- Components/InfoTip and ItemTooltip: from the screen's edges
Popover.GAP = 6 -- Components/InfoTip: between the (i) and its box
-- Components/Tooltip's and ItemTooltip's OFFSET from the cursor: `gap` to the right, `drop` down.
Popover.TOOLTIP = table.freeze({ gap = 18, drop = 22 })
Popover.ITEM = table.freeze({ gap = 20, drop = 20 })

local OPPOSITE: { [string]: Side } = { below = "above", above = "below", right = "left", left = "right" }
local ACROSS: { [string]: { Side } } = {
	below = { "right", "left" },
	above = { "right", "left" },
	right = { "below", "above" },
	left = { "below", "above" },
}

local EPSILON = 1e-6

local function overlaps(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

-- How much of `b` the rectangle `a` covers (its area).
local function covered(a: Rect, b: Rect): number
	local w = math.min(a.right, b.right) - math.max(a.left, b.left)
	local h = math.min(a.bottom, b.bottom) - math.max(a.top, b.top)
	return if w > 0 and h > 0 then w * h else 0
end

local function within(r: Rect, area: Rect): boolean
	return r.left >= area.left - EPSILON
		and r.top >= area.top - EPSILON
		and r.right <= area.right + EPSILON
		and r.bottom <= area.bottom + EPSILON
end

-- The anchor of a popover that follows the pointer at (x, y): a point `drop` under it, so that a popover beside it
-- has its top edge there (Popover.TOOLTIP, Popover.ITEM).
function Popover.cursor(x: number, y: number, drop: number): Rect
	return { left = x, top = y + drop, right = x, bottom = y + drop }
end

-- The box on `side` of `anchor`: across that side aligned to the anchor's start edge, to its end edge when it would run
-- out of `area`, then kept inside `area` (InfoTip's rule); the room left on that side (negative: it does not fit).
local function onSide(side: Side, anchor: Rect, size: Size, area: Rect, gap: number): (Rect, number)
	local x, y, room
	if side == "below" or side == "above" then
		if side == "below" then
			y = anchor.bottom + gap
			room = area.bottom - y - size.h
		else
			y = anchor.top - gap - size.h
			room = y - area.top
		end
		x = anchor.left
		if x + size.w > area.right then
			x = anchor.right - size.w
		end
		x = math.clamp(x, area.left, math.max(area.left, area.right - size.w))
	else
		if side == "right" then
			x = anchor.right + gap
			room = area.right - x - size.w
		else
			x = anchor.left - gap - size.w
			room = x - area.left
		end
		y = anchor.top
		if y + size.h > area.bottom then
			y = anchor.bottom - size.h
		end
		y = math.clamp(y, area.top, math.max(area.top, area.bottom - size.h))
	end
	return { left = x, top = y, right = x + size.w, bottom = y + size.h }, room
end

local function inset(safe: Rect, margin: number): Rect
	return {
		left = safe.left + margin,
		top = safe.top + margin,
		right = safe.right - margin,
		bottom = safe.bottom - margin,
	}
end

-- The rectangle of a popover of `size` for `anchor` inside `safe` (the layer less Roblox's top bar), and the side it
-- took. Tried in turn: the preferred side, the opposite one, then the two beside the anchor; the first that has room
-- and keeps off `avoid`, else the first that has room. A popover too large for every side takes the one with the most
-- room, pushed inside the safe area (only then may it cover its anchor).
function Popover.place(anchor: Rect, size: Size, safe: Rect, options: Options?): (Rect, Side)
	local o: Options = options or {}
	local margin = o.margin or Popover.MARGIN
	local gap = o.gap or Popover.GAP
	local area = inset(safe, margin)
	local prefer: Side = o.prefer or "below"
	local across = ACROSS[prefer]
	local sides: { Side } = { prefer, OPPOSITE[prefer], across[1], across[2] }
	local fit: Rect? = nil
	local fitSide: Side = prefer
	local most: Rect? = nil
	local mostSide: Side = prefer
	local mostRoom = -math.huge
	for _, side: Side in sides do
		local rect, room = onSide(side, anchor, size, area, gap)
		if room >= -EPSILON and within(rect, area) then
			local avoid = o.avoid
			if not avoid or not overlaps(rect, avoid) then
				return rect, side
			end
			if not fit then
				fit, fitSide = rect, side
			end
		end
		if room > mostRoom then
			most, mostSide, mostRoom = rect, side, room
		end
	end
	if fit then
		return fit, fitSide
	end
	local r = assert(most, "a side")
	local x = math.clamp(r.left, area.left, math.max(area.left, area.right - size.w))
	local y = math.clamp(r.top, area.top, math.max(area.top, area.bottom - size.h))
	return { left = x, top = y, right = x + size.w, bottom = y + size.h }, mostSide
end

-- UI package C (Components/ItemTooltip on a touch screen): a popover of `size` on the half of `safe` away from
-- `anchor`, the tapped slot, so the thumb and the slot stay clear: the right half for an anchor left of the middle,
-- else the left half, next to the middle (clear of the anchor). It stands at the top of that half, under `top` (a
-- full-screen window's title bar) when given, inside the safe area less the margin; a popover too tall for the room
-- under `top` rises over it rather than leave the screen. When it would cover `avoid` (a window's action buttons) it
-- moves under or over them where there is room, else to the place that covers least of them (over them it may rise
-- over the title bar). `keepOff` adds more such rectangles: it then keeps off all of them, else covers least of them.
-- Returns the rectangle and the side of the anchor it took ("right" or "left").
function Popover.away(anchor: Rect, size: Size, safe: Rect, options: Options?): (Rect, Side)
	local o: Options = options or {}
	local gap = o.gap or Popover.GAP
	local margin = o.margin or Popover.MARGIN
	local area = inset(safe, margin)
	local middle = (safe.left + safe.right) / 2
	local side: Side = if (anchor.left + anchor.right) / 2 < middle then "right" else "left"
	local x = if side == "right"
		then math.max(middle, anchor.right) + gap
		else math.min(middle, anchor.left) - gap - size.w
	x = math.clamp(x, area.left, math.max(area.left, area.right - size.w))
	local function at(y: number): Rect
		local top = math.clamp(y, area.top, math.max(area.top, area.bottom - size.h))
		return { left = x, top = top, right = x + size.w, bottom = top + size.h }
	end
	local keep: { Rect } = table.clone(o.keepOff or {})
	if o.avoid then
		table.insert(keep, o.avoid)
	end
	-- how much of the rectangles to keep off `r` covers
	local function cover(r: Rect): number
		local sum = 0
		for _, k in keep do
			sum += covered(r, k)
		end
		return sum
	end
	local rect = at(if o.top then o.top + margin else area.top)
	local least = cover(rect)
	if least <= 0 then
		return rect, side
	end
	local best = rect
	for _, k in keep do
		for _, y in { k.bottom + gap, k.top - gap - size.h } do
			local moved = at(y)
			if not overlaps(moved, anchor) then
				local c = cover(moved)
				if c <= 0 then
					return moved, side
				end
				if c < least then
					best, least = moved, c
				end
			end
		end
	end
	return best, side
end

-- The height a popover placed by `away` with the same options has at its first place: from under `top` (the
-- window's title bar) to the safe area's bottom less the margin, or to `avoid` (the action strip) less the gap when
-- that strip is under it. A popover at most this tall stands there, clear of both.
function Popover.awayRoom(safe: Rect, options: Options?): number
	local o: Options = options or {}
	local margin = o.margin or Popover.MARGIN
	local gap = o.gap or Popover.GAP
	local area = inset(safe, margin)
	local top = if o.top then math.max(area.top, o.top + margin) else area.top
	local bottom = area.bottom
	if o.avoid and o.avoid.top > top then
		bottom = math.min(bottom, o.avoid.top - gap)
	end
	return math.max(0, bottom - top)
end

-- A popover whose body scrolls inside `room`: its height and the body's, for a body `body` tall and `fixed` pixels
-- around it (the padding, the rows pinned under the body). The body shows whole while it fits.
function Popover.capped(body: number, fixed: number, room: number): (number, number)
	local shown = math.max(0, math.min(body, room - fixed))
	return shown + fixed, shown
end

return Popover
