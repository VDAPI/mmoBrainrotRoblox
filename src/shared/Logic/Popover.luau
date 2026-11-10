--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, too detailed descriptions, nothing folds"): where a
-- popover (a tooltip, an item tooltip, an (i) note's box) stands next to the element it belongs to, as a pure
-- rectangle: on the preferred side of its anchor, on the opposite side when there is no room (below / above flip),
-- then beside it; inside the safe area, MARGIN from its edges; never over its anchor; off a rectangle it is told to
-- avoid (a window's action bar) whenever another side has room. The defaults are today's Components/InfoTip: GAP under
-- the anchor, left edges aligned (right edges when the box would run off the right side), above it when there is no
-- room below. Today's cursor tooltips are a pointer anchor (`cursor`) with their own gap: Components/Tooltip 18 right
-- and 22 down (TOOLTIP), ItemTooltip 20 and 20 (ITEM, flipping left of the cursor as today). Nothing reads this module
-- yet: UI package C moves Tooltip, ItemTooltip and InfoTip onto it. All numbers are virtual pixels of one layer.

local Popover = {}

export type Rect = { left: number, top: number, right: number, bottom: number }
export type Size = { w: number, h: number }
export type Side = "below" | "above" | "right" | "left"
-- prefer: the side to try first (default "below"); avoid: a rectangle to keep off when a side with room is free of
-- it; gap: between the anchor and the popover (default GAP); margin: from the safe area's edges (default MARGIN).
export type Options = { prefer: Side?, avoid: Rect?, gap: number?, margin: number? }

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

-- The rectangle of a popover of `size` for `anchor` inside `safe` (the layer less Roblox's top bar), and the side it
-- took. Tried in turn: the preferred side, the opposite one, then the two beside the anchor; the first that has room
-- and keeps off `avoid`, else the first that has room. A popover too large for every side takes the one with the most
-- room, pushed inside the safe area (only then may it cover its anchor).
function Popover.place(anchor: Rect, size: Size, safe: Rect, options: Options?): (Rect, Side)
	local o: Options = options or {}
	local margin = o.margin or Popover.MARGIN
	local gap = o.gap or Popover.GAP
	local area = {
		left = safe.left + margin,
		top = safe.top + margin,
		right = safe.right - margin,
		bottom = safe.bottom - margin,
	}
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

return Popover
