--!strict
-- Owner 2026-10-21 (Studio, PC ~1366 wide: "the mail button touches the bottom of the quest tracker next to the
-- attack button, the world boss panel covers the tracker's first line"): where the HUD's column of panels and the
-- buttons of the bottom-right corner stand, so that nothing covers anything at its built-in place.
-- * The corner (`fixed`): the PvP toggle with its countdown badge under it, the mail envelope in its own slot under
--   both, and on a touch screen the attack button, the skill arc around it and its page / target buttons
--   (Hud/PvpToggle, MailButton, AttackButton, MobileSkills read their places here).
-- * The column (`column`): PC the right side under the menu, the minimap and the guide bar down to the corner's
--   buttons; a touch screen that is not a phone the left side under the portrait (and the party frames) down to the
--   sprint / mount / emote row; a phone in landscape the left stack of Logic/PhoneHud.
-- * The stack (`place`, `layout`): the arena queue's pill, the event panels (world boss, world event, Blood Moon,
--   tournament), the Elite II timers on a touch screen and the quest tracker, in that order, top down. An element the
--   player has moved (HudLayout) stays where it is and the others go round it: above it, under it or, when the column
--   has no room left, in a spare column beside it. The tracker takes the room left down to the floor (its list
--   scrolls), on a crowded screen down to its header and one line.
-- All numbers are virtual pixels of UI/Scale; rectangles are measured from the top-left corner of the screen. Pure;
-- tests/hudlayout.spec checks that nothing overlaps at the common screen sizes.

local PhoneHud = require("./PhoneHud")

local HudStack = {}

export type Rect = { left: number, top: number, right: number, bottom: number }
-- A button of the corner: its distance from the right and the bottom edge and its size.
export type Spot = { right: number, bottom: number, w: number, h: number }
export type Column = {
	x: number, -- the column's right edge (`right`) or left edge
	right: boolean,
	top: number,
	floor: number, -- nothing of the stack goes below this
	spares: { number }?, -- the edges of the spare columns beside it, nearest first (the same side as `x`)
	spareTop: number?, -- where the spare columns start (default `top`)
}
export type Item = {
	id: string,
	w: number,
	h: number,
	grow: boolean?, -- takes the room down to the floor or the next element below (the quest tracker)
	least: number?, -- a `grow` element with no room for `h` anywhere: the least height it shrinks to
}
-- What an element of the column tells it (UI/HudSlots): shown, its size (virtual pixels, after its scale) and, once
-- the player moved it (UI/HudDrag), its rectangle.
export type Box = { shown: boolean, w: number, h: number, custom: Rect? }

-- The order of the stack, top down; "elite" stacks only on a touch screen (PC: over the corner's buttons).
HudStack.ORDER = table.freeze({ "arena", "worldBoss", "worldEvent", "bloodMoon", "tourney", "elite", "questTracker" })

HudStack.GAP = 8
HudStack.MARGIN = 16 -- Theme.Padding.Large
-- PC: the column starts under two rows of menu buttons, the minimap and the guide bar (UI/HudDrag.RIGHT_TOP).
HudStack.RIGHT_TOP = 460
-- A touch screen (not a phone): under the portrait and its effect icons (16 + 136 + 6 + 44), the party frames push
-- it down (16 + 136 + 70, then one row per member).
HudStack.TOUCH_TOP = 202
HudStack.PARTY_TOP = 222
HudStack.PARTY_ROW = 64
-- A touch screen: the sprint, mount and emote buttons stand this high over the bottom (Hud/SprintButton: 260 + 64).
HudStack.TOUCH_ROW = 324

-- Widths of the column's elements (Hud/WorldBossPanel and the other panels, Hud/QuestTracker, Hud/Elite2Timer,
-- Hud/ArenaPanel's queue pill).
HudStack.PANEL_PC = 280
HudStack.PANEL_TOUCH = 240
HudStack.TRACKER = 300
HudStack.ELITE = 240
HudStack.ARENA_PILL = 280

-- The corner's buttons, bottom up: the mail envelope (over the EXP bar), the PvP toggle's countdown / "forced" badge
-- (right-aligned with the toggle, as wide as its text up to `w`) and the toggle.
HudStack.MAIL = table.freeze({ right = 16, bottom = 32, w = 52, h = 52 })
HudStack.PVP = table.freeze({ right = 16, bottom = 120, w = 64, h = 64 })
HudStack.PVP_BADGE = table.freeze({ w = 170, h = 24, gap = 4 })
HudStack.ATTACK = table.freeze({ right = 110, bottom = 150, w = 104, h = 104 }) -- touch
-- Touch: the skill arc round the attack button (centre as offsets from the bottom-right corner, degrees from the
-- right, counter-clockwise) and its small buttons (centres).
HudStack.ARC = table.freeze({ x = -162, y = -202, radius = 120, size = 68, angles = { 180, 150, 120, 90, 60 } })
HudStack.SMALL = table.freeze({ w = 84, h = 44 })
HudStack.PAGE = table.freeze({ x = -162 - 120 - 76, y = -202 + 40 }) -- left of the arc's first button, clear of it
HudStack.TARGET = table.freeze({ x = -162, y = -202 - 120 - 56 })

-- The login reward, season pass and achievements buttons right of the portrait (Hud: x 16 + 400 + 12, three 44 px
-- buttons 8 apart from y 16 + 136 - 44); a phone has them in its menu drawer. The spare column of a touch screen
-- stands right of them.
HudStack.EXTRAS = table.freeze({ x = 428, y = 108, w = 44, h = 3 * 44 + 2 * 8 })

-- The tracker's height before it moves to a spare column (its header and two lines) and the least it shrinks to
-- when there is no room for that in any column (its header; the list scrolls in what is left).
HudStack.TRACKER_LEAST = 6 + 28 + 3 + 8
HudStack.TRACKER_MIN = HudStack.TRACKER_LEAST + 2 * 22

-- The rectangle of a corner button on a w x h screen.
function HudStack.spot(spot: Spot, w: number, h: number): Rect
	return {
		left = w - spot.right - spot.w,
		top = h - spot.bottom - spot.h,
		right = w - spot.right,
		bottom = h - spot.bottom,
	}
end

local function centred(x: number, y: number, w: number, h: number): Rect
	return { left = x - w / 2, top = y - h / 2, right = x + w / 2, bottom = y + h / 2 }
end

-- The centre of skill button `i` of the arc as offsets from the bottom-right corner.
function HudStack.skillCenter(i: number): (number, number)
	local a = math.rad(HudStack.ARC.angles[i])
	return HudStack.ARC.x + math.cos(a) * HudStack.ARC.radius, HudStack.ARC.y - math.sin(a) * HudStack.ARC.radius
end

-- Every button of the bottom-right corner on a w x h screen (PC, or a touch screen that is not a phone: a phone's
-- are Logic/PhoneHud's), by name; the badge at its widest.
function HudStack.fixed(touch: boolean, w: number, h: number): { [string]: Rect }
	local out: { [string]: Rect } = {}
	local pvp = HudStack.spot(HudStack.PVP, w, h)
	out.pvp = pvp
	local badge = HudStack.PVP_BADGE
	out.pvpBadge = {
		left = pvp.right - badge.w,
		top = pvp.bottom + badge.gap,
		right = pvp.right,
		bottom = pvp.bottom + badge.gap + badge.h,
	}
	out.mail = HudStack.spot(HudStack.MAIL, w, h)
	if touch then
		out.attack = HudStack.spot(HudStack.ATTACK, w, h)
		for i = 1, #HudStack.ARC.angles do
			local x, y = HudStack.skillCenter(i)
			out[`skill{i}`] = centred(w + x, h + y, HudStack.ARC.size, HudStack.ARC.size)
		end
		out.page = centred(w + HudStack.PAGE.x, h + HudStack.PAGE.y, HudStack.SMALL.w, HudStack.SMALL.h)
		out.target = centred(w + HudStack.TARGET.x, h + HudStack.TARGET.y, HudStack.SMALL.w, HudStack.SMALL.h)
	end
	return out
end

-- The top of the corner's buttons.
function HudStack.cornerTop(touch: boolean, w: number, h: number): number
	local top = h
	for _, r in HudStack.fixed(touch, w, h) do
		top = math.min(top, r.top)
	end
	return top
end

-- Owner 2026-10-22 (Studio 1462 x 793: the tracker still ran 22 px into the PvP toggle, the layer's height from the
-- formula did not match the screen): a rectangle a GUI object really takes, from its AbsolutePosition and
-- AbsoluteSize (screen pixels: corner x, y, size w x h), in the virtual pixels of the frame whose corner is at
-- (ox, oy) under UI scale `scale`. UI/HudSlots measures the corner's buttons with it (`measured` of `layout`).
function HudStack.fromScreen(x: number, y: number, w: number, h: number, ox: number, oy: number, scale: number): Rect
	local left = (x - ox) / scale
	local top = (y - oy) / scale
	return { left = left, top = top, right = left + w / scale, bottom = top + h / scale }
end

-- The highest top among `rects` that stand in the lane [left, right], or `top` when none is higher.
local function topIn(rects: { Rect }, left: number, right: number, top: number): number
	for _, r in rects do
		if r.left < right and left < r.right then
			top = math.min(top, r.top)
		end
	end
	return top
end

-- PC: the Elite II timers stand over the corner's buttons (their bottom edge), the measured ones too (`measured`,
-- see `fromScreen`); a touch screen stacks them in the column (`place`, id "elite").
function HudStack.eliteBottom(w: number, h: number, measured: { Rect }?): number
	local right = w - HudStack.MARGIN
	local top = topIn(measured or {}, right - HudStack.ELITE, right, HudStack.cornerTop(false, w, h))
	return top - HudStack.GAP
end

-- PC: the rectangle of the Elite II timers (`height` tall) over the corner's buttons.
function HudStack.elite(w: number, h: number, height: number, measured: { Rect }?): Rect
	local bottom = HudStack.eliteBottom(w, h, measured)
	local right = w - HudStack.MARGIN
	return { left = right - HudStack.ELITE, top = bottom - height, right = right, bottom = bottom }
end

-- The column of a w x h screen: PC (`touch` false), a touch screen that is not a phone, a phone (`compact`).
-- `others` = party members besides the player.
function HudStack.column(touch: boolean, compact: boolean, w: number, h: number, others: number): Column
	if compact then
		local stack = PhoneHud.PLACES.stack
		return { x = stack.x, right = false, top = PhoneHud.stackTop(others), floor = h - (stack.bottom or 0) }
	end
	if touch then
		local top = if others > 0 then HudStack.PARTY_TOP + others * HudStack.PARTY_ROW else HudStack.TOUCH_TOP
		return {
			x = HudStack.MARGIN,
			right = false,
			top = top,
			floor = h - HudStack.TOUCH_ROW - HudStack.GAP,
			-- right of the buttons right of the portrait (Cloak of Luring and the auto buttons end above TOUCH_TOP)
			spares = { HudStack.EXTRAS.x + HudStack.EXTRAS.w + HudStack.GAP },
			spareTop = HudStack.TOUCH_TOP,
		}
	end
	return {
		x = w - HudStack.MARGIN,
		right = true,
		top = HudStack.RIGHT_TOP,
		floor = HudStack.cornerTop(false, w, h) - HudStack.GAP,
		-- two: a short window at the 0.6 floor has little height under the minimap (owner 2026-10-22)
		spares = {
			w - HudStack.MARGIN - HudStack.TRACKER - HudStack.GAP,
			w - HudStack.MARGIN - 2 * (HudStack.TRACKER + HudStack.GAP),
		},
	}
end

-- The floor of `column` kept GAP above every rectangle of `under` (the corner's buttons as measured on screen) that
-- stands below the column's top in one of its lanes (the column and its spares, `width` wide): whatever the computed
-- floor says, nothing of the stack reaches a button that is really there.
function HudStack.floorAbove(column: Column, width: number, under: { Rect }): number
	local floor = column.floor
	local edges: { number } = { column.x }
	local spares: { number } = column.spares or {}
	for _, spare in spares do
		table.insert(edges, spare)
	end
	local below: { Rect } = {}
	for _, r in under do
		if r.top > column.top then
			table.insert(below, r)
		end
	end
	for _, edge in edges do
		local left = if column.right then edge - width else edge
		floor = math.min(floor, topIn(below, left, left + width, floor + HudStack.GAP) - HudStack.GAP)
	end
	return floor
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end
HudStack.overlaps = overlaps

-- The places of `items` (in order, top down) in `column`, round the `fixed` rectangles (moved elements, the corner's
-- buttons, the PC Elite II timers), by id. An element goes at the first free place under the one before it; when it
-- would pass the floor, at the first free place of a spare column from its top; with no room in any column a
-- `least` element shrinks, the others stand under the one before (past the floor). A `grow` element reaches down to
-- the floor or to the first rectangle under it.
function HudStack.place(items: { Item }, column: Column, fixed: { Rect }): { [string]: Rect }
	local out: { [string]: Rect } = {}
	local taken: { Rect } = table.clone(fixed)
	local gap = HudStack.GAP
	local function span(edge: number, w: number): (number, number)
		if column.right then
			return edge - w, edge
		end
		return edge, edge + w
	end
	-- the first y from `y` down where a w x h box at [left, right] meets nothing taken
	local function free(left: number, right: number, y: number, h: number): number
		for _ = 1, #taken + 1 do
			local box = { left = left, top = y, right = right, bottom = y + h }
			local hit: Rect? = nil
			for _, r in taken do
				if overlaps(box, r) then
					hit = r
					break
				end
			end
			if not hit then
				return y
			end
			y = hit.bottom + gap
		end
		return y
	end
	-- the column, else the first spare one, with room for a w x h box: found, its left, right and top, in the column
	local function room(w: number, h: number, cursor: number): (boolean, number, number, number, boolean)
		local left, right = span(column.x, w)
		local y = free(left, right, cursor, h)
		if y + h <= column.floor then
			return true, left, right, y, true
		end
		local spares: { number } = column.spares or {}
		for _, spare in spares do
			local sl, sr = span(spare, w)
			local sy = free(sl, sr, column.spareTop or column.top, h)
			if sy + h <= column.floor then
				return true, sl, sr, sy, false
			end
		end
		-- no room: under the one before, past the floor
		return false, left, right, y, true
	end
	local cursor = column.top
	for _, item in items do
		local found, x, right, y, main = room(item.w, item.h, cursor)
		local least = item.least
		if not found and least then
			local fits, lx, lr, ly, lm = room(item.w, least, cursor)
			if fits then
				x, right, y, main = lx, lr, ly, lm
			end
		end
		local bottom = y + (if item.grow and least then math.min(item.h, least) else item.h)
		if item.grow then
			bottom = math.max(bottom, column.floor)
			for _, r in taken do
				if r.left < right and x < r.right and r.top >= y and r.top - gap < bottom then
					bottom = r.top - gap
				end
			end
			bottom = math.max(bottom, y + math.min(item.h, least or item.h))
		end
		local rect = { left = x, top = y, right = right, bottom = bottom }
		out[item.id] = rect
		table.insert(taken, rect)
		if main then
			cursor = bottom + gap
		end
	end
	return out
end

-- The built-in place of every shown element of `boxes` (by id, HudStack.ORDER) that the player has not moved, on a
-- w x h screen: PC (`touch` false), a touch screen that is not a phone, a phone (`compact`); `others` = party members
-- besides the player. Moved elements, the corner's buttons and the buttons right of the portrait (not on a phone:
-- Logic/PhoneHud keeps the stack clear of them) and the PC Elite II timers are obstacles the others go round.
-- `measured`: the corner's buttons as they really stand (`fromScreen`; not on a phone): obstacles too, and the column's
-- floor stays above them (`floorAbove`) when the computed one is lower (owner 2026-10-22).
function HudStack.layout(
	touch: boolean,
	compact: boolean,
	w: number,
	h: number,
	others: number,
	boxes: { [string]: Box },
	measured: { Rect }?
): { [string]: Rect }
	local column = HudStack.column(touch, compact, w, h, others)
	local under: { Rect } = if compact then {} else measured or {}
	if #under > 0 then
		column.floor = HudStack.floorAbove(column, math.max(HudStack.TRACKER, HudStack.PANEL_PC), under)
	end
	local fixed: { Rect } = table.clone(under)
	if not compact then
		for _, rect in HudStack.fixed(touch, w, h) do
			table.insert(fixed, rect)
		end
		local e = HudStack.EXTRAS
		table.insert(fixed, { left = e.x, top = e.y, right = e.x + e.w, bottom = e.y + e.h })
	end
	local items: { Item } = {}
	for _, id: string in HudStack.ORDER do
		local box = boxes[id]
		if not box or not box.shown then
			continue
		end
		if box.custom then
			table.insert(fixed, box.custom)
		elseif id == "elite" and not touch then
			table.insert(fixed, HudStack.elite(w, h, box.h, under)) -- PC: right over the corner's buttons
		else
			local tracker = id == "questTracker"
			local item: Item = {
				id = id,
				w = box.w,
				h = box.h,
				grow = tracker,
				least = if tracker then math.min(box.h, HudStack.TRACKER_LEAST) else nil,
			}
			table.insert(items, item)
		end
	end
	return HudStack.place(items, column, fixed)
end

return HudStack
