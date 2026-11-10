--!strict
-- Owner 2026-10-21 (Studio, PC ~1366 wide: "the mail button touches the bottom of the quest tracker next to the
-- attack button, the world boss panel covers the tracker's first line"): where the HUD's column of panels and the
-- buttons of the bottom-right corner stand, so that nothing covers anything at its built-in place.
-- * The corner (`fixed`): the PvP toggle with its countdown badge under it, the mail envelope in its own slot under
--   both, and on a touch screen the attack button, the skill arc around it and its page / target buttons
--   (Hud/PvpToggle, MailButton, AttackButton, MobileSkills read their places here).
-- * The column (`column`): PC the right side under the menu, the minimap (and the guide bar while it shows) down to
--   the corner's buttons; a touch screen that is not a phone the left side under the portrait (and the party frames)
--   down to the sprint / mount row; a phone in landscape the left stack of Logic/PhoneHud.
-- * The stack (`place`, `layout`): the arena queue's pill, the event panels (world boss, world event, Blood Moon,
--   tournament), the Elite II timers on a touch screen and the quest tracker, in that order, top down. An element the
--   player has moved (HudLayout) stays where it is and the others go round it: above it, under it or, when the column
--   has no room left, in a spare column beside it. The tracker takes the room left down to the floor (its list
--   scrolls), on a crowded screen down to its header and one line.
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan package A): nothing of the
-- stack goes past the column's floor any more. With no room the column first shrinks what may shrink (the tracker to
-- its header and two lines), then folds the panels to their header line from the lowest up (and the tracker to its
-- header last), then hides elements from the lowest up behind a '+N' chip at the floor (Hud/StackChip lists them, a
-- pick brings one back first: `keep`); `place` returns the rectangles, the folded ids and the hidden ids.
-- All numbers are virtual pixels of UI/Scale; rectangles are measured from the top-left corner of the screen. Pure;
-- tests/hudlayout.spec checks that nothing overlaps at the common screen sizes.

local PhoneHud = require("./PhoneHud")

local HudStack = {}

export type Rect = { left: number, top: number, right: number, bottom: number }
-- A button of the corner: its distance from the right and the bottom edge and its size.
export type Spot = { right: number, bottom: number, w: number, h: number }
export type Size = { w: number, h: number }
export type Column = {
	x: number, -- the column's right edge (`right`) or left edge
	right: boolean,
	top: number,
	floor: number, -- nothing of the stack goes below this
	spares: { number }?, -- the edges of the spare columns beside it, nearest first (the same side as `x`)
	spareTop: number?, -- where the spare columns start (default `top`)
	width: number?, -- the lane's width: the '+N' chip stands at its far end (default the chip's width)
	chip: Size?, -- the '+N' chip (default CHIP)
}
export type Item = {
	id: string,
	w: number,
	h: number,
	grow: boolean?, -- takes the room down to the floor or the next element below (the quest tracker)
	least: number?, -- the least height it shrinks to before any panel folds (the tracker: its header and two lines)
	line: number?, -- the height of its folded line (a panel's header, the tracker's header): the column may fold it
	keep: boolean?, -- the player took it from the '+N' list: folded and hidden after the others
}
-- What an element of the column tells it (UI/HudSlots): shown, its size (virtual pixels, after its scale), its folded
-- line, whether the player brought it out of the '+N' list and, once the player moved it (UI/HudDrag), its rectangle.
export type Box = { shown: boolean, w: number, h: number, custom: Rect?, line: number?, keep: boolean? }
-- Where `place` put the column: the shown elements' rectangles by id (a folded one its line), the ids it folded to
-- their line (not the player's choice: the panel shows its line until there is room), the ids behind the '+N' chip
-- (top down) and the chip while one is hidden.
export type Placed = { rects: { [string]: Rect }, folded: { string }, hidden: { string }, chip: Rect? }

-- The order of the stack, top down. "party" (the phone's party strip) and "guide" (the guide bar of a phone whose M
-- zone has no room for it) join only on a phone; "elite" stacks only on a touch screen (PC: over the corner's
-- buttons); "arena" is the arena's queue pill or, during a match, its team list (Hud/ArenaTeams).
HudStack.ORDER = table.freeze({
	"party",
	"arena",
	"worldBoss",
	"worldEvent",
	"bloodMoon",
	"tourney",
	"elite",
	"guide",
	"questTracker",
})

-- UI plan phase 4 (one spacing grid, plan §2 rule 7): the HUD stands MARGIN from the screen's edges everywhere
-- (Theme.Padding.Large: the portrait, the menu over the minimap, the column under them and the corner's buttons; the
-- column and the corner stood 16 from the edge, out of line with the minimap above them) and its elements stand GAP
-- apart (Theme.Padding.Small); a HUD button is ICON (Theme.Size.IconButton). tests/hudlayout.spec reads Theme for
-- these.
HudStack.GAP = 8
HudStack.MARGIN = 22
HudStack.ICON = 52
-- UI plan phase 4: the portrait (Hud/init) at MARGIN, MARGIN, 340 x 110 (it was 400 x 136), and the row of effects
-- GAP under it, at most EFFECTS tall.
HudStack.PORTRAIT = table.freeze({ w = 340, h = 110 })
HudStack.EFFECTS = 44
-- PC: the column starts under the menu's one row of buttons and the minimap (UI plan phase 1: one row of six buttons
-- instead of 14 in two, it was 460; phase 4: the area's line under the minimap joined the map's name inside its frame:
-- 22 + 52 + 8 + 266, then GAP), and under the guide bar while one shows (Hud/NavBar, 44 tall GAP under the minimap:
-- 22 + 52 + 8 + 266 + 8 + 44, then GAP).
HudStack.RIGHT_TOP = HudStack.MARGIN + HudStack.ICON + HudStack.GAP + 266 + HudStack.GAP
HudStack.RIGHT_TOP_GUIDE = HudStack.MARGIN + HudStack.ICON + HudStack.GAP + 266 + HudStack.GAP + 44 + HudStack.GAP
-- UI plan phase 2: the row of "something waits" buttons (Hud/WaitingRow: mail, login reward, season pass, Blood Moon
-- results), 44 tall, under the minimap (or under the guide bar), pushes the column down by its height and GAP while it
-- shows.
HudStack.WAITING = 44
-- A touch screen (not a phone): under the portrait and its effects row (22 + 110 + 8 + 44, then GAP); the party
-- frames (UI/Screens/PartyFrames) stand at PARTY_TOP and push it down by one row per member.
HudStack.TOUCH_TOP = HudStack.MARGIN + HudStack.PORTRAIT.h + HudStack.GAP + HudStack.EFFECTS + HudStack.GAP
HudStack.PARTY_TOP = HudStack.MARGIN + HudStack.PORTRAIT.h + 70
HudStack.PARTY_ROW = 64
-- A touch screen: the sprint and mount buttons stand this high over the bottom (Hud/SprintButton: 260 + 64).
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
HudStack.MAIL = table.freeze({ right = HudStack.MARGIN, bottom = 32, w = 52, h = 52 })
HudStack.PVP = table.freeze({ right = HudStack.MARGIN, bottom = 120, w = 64, h = 64 })
HudStack.PVP_BADGE = table.freeze({ w = 170, h = 24, gap = 4 })
HudStack.ATTACK = table.freeze({ right = 110, bottom = 150, w = 104, h = 104 }) -- touch
-- Touch: the skill arc round the attack button (centre as offsets from the bottom-right corner, degrees from the
-- right, counter-clockwise) and its small buttons (centres).
HudStack.ARC = table.freeze({ x = -162, y = -202, radius = 120, size = 68, angles = { 180, 150, 120, 90, 60 } })
HudStack.SMALL = table.freeze({ w = 84, h = 44 })
HudStack.PAGE = table.freeze({ x = -162 - 120 - 76, y = -202 + 40 }) -- left of the arc's first button, clear of it
HudStack.TARGET = table.freeze({ x = -162, y = -202 - 120 - 56 })

-- The "Auto" button right of the portrait (Hud/AutoGroup: GAP right of it, 44 px, aligned to the portrait's bottom;
-- UI plan phase 2: it holds the Cloak of Luring, Auto Hunt and Auto Potions, the login reward and the season pass
-- moved under the minimap); a phone keeps the three at their own places. The spare column of a touch screen stands
-- right of it.
HudStack.EXTRAS = table.freeze({
	x = HudStack.MARGIN + HudStack.PORTRAIT.w + HudStack.GAP,
	y = HudStack.MARGIN + HudStack.PORTRAIT.h - 44,
	w = 44,
	h = 44,
})

-- The tracker's height before it moves to a spare column (its header and two lines) and its header alone, the line
-- it folds to once every panel above it is folded (UI plan package A: the tracker keeps at least its header).
HudStack.TRACKER_LEAST = 6 + 28 + 3 + 8
HudStack.TRACKER_MIN = HudStack.TRACKER_LEAST + 2 * 22

-- UI plan package A: a panel's folded line (Hud/PanelHeader: Theme.Size.PanelLine on PC, Theme.Size.MinTouch on a
-- tablet, Theme.Size.HudLine on a phone, Logic/PhoneHud.LINE) and the '+N' chip at the floor of the column (a touch
-- screen's at least MinTouch; a phone's at the right end of its stack, Logic/PhoneHud.CHIP).
HudStack.LINE_PC = 32
HudStack.LINE_TOUCH = 44
HudStack.CHIP = table.freeze({ w = 72, h = 32 })
HudStack.CHIP_TOUCH = table.freeze({ w = 72, h = 44 })
-- The message zone (Logic/HudZones Z8) ends at this share of the layer's height: the spare columns start under it.
HudStack.MESSAGE_BOTTOM = 0.4

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

-- UI plan phase 2 (Studio audit 2026-10-31: windows never hid the HUD under them): whether an open window's rectangle
-- `by` covers HUD element `item` by more than `margin` on both axes (a window edge that only touches it does not).
function HudStack.covers(item: Rect, by: Rect, margin: number): boolean
	local w = math.min(item.right, by.right) - math.max(item.left, by.left)
	local h = math.min(item.bottom, by.bottom) - math.max(item.top, by.top)
	return w > margin and h > margin
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

-- Studio check 2026-10-31 (a quest tracker the player had moved near its built-in place stood under the row of
-- "something waits" buttons): the top of an element moved to [left, right] at `top`, kept GAP under the menu over the
-- minimap (`menu`, as measured: its buttons, the minimap, the guide bar and the row) when it would stand in its lane;
-- `top` otherwise.
function HudStack.belowMenu(left: number, right: number, top: number, menu: Rect?): number
	if not menu or right <= menu.left or left >= menu.right or top >= menu.bottom + HudStack.GAP then
		return top
	end
	return menu.bottom + HudStack.GAP
end

-- Studio check of phase 4 (1108 x 576: a quest tracker the player had moved at a larger window, saved as a share of
-- the screen's width, ran 3 px past the right edge at the 0.6 scale, Logic/HudLayout.place keeps only KEEP px on
-- the screen): the left of an element moved to `x`, `w` wide, kept MARGIN inside a screen `screenW` wide on both sides
-- like the built-in column; `x` when the element is wider than the room between the margins.
function HudStack.insideX(x: number, w: number, screenW: number): number
	local high = screenW - HudStack.MARGIN - w
	if high < HudStack.MARGIN then
		return x
	end
	return math.clamp(x, HudStack.MARGIN, high)
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
-- `others` = party members besides the player; `guide`: the guide bar shows under the minimap (PC); `waiting`: the
-- row of "something waits" buttons shows under them (PC). `menuBottom` (PC): where the menu over the minimap really
-- ends, as measured on screen (UI/HudSlots.MenuBottom): the column never starts above it (Studio check 2026-10-31: the
-- row stood in the tracker). `band`: the target band's bottom now (Logic/HudZones.targetBand): the message zone runs
-- from GAP under it, so on a short tablet with the dungeon boss bar it ends lower than its usual share of the height.
function HudStack.column(
	touch: boolean,
	compact: boolean,
	w: number,
	h: number,
	others: number,
	guide: boolean?,
	waiting: boolean?,
	menuBottom: number?,
	band: number?
): Column
	if compact then
		-- UI plan package A: the party strip is the stack's first line, the stack ends over the thumb zone
		return {
			x = 8,
			right = false,
			top = PhoneHud.STACK_TOP,
			floor = PhoneHud.stackBottom(h),
			width = PhoneHud.STACK_WIDTH,
			chip = PhoneHud.CHIP,
		}
	end
	-- the spare columns start GAP under the message zone (Logic/HudZones Z8): a panel moved aside never covers it (UI
	-- package A: nor the band over a zone that has no height left, a tablet's with the dungeon boss bar and an add)
	local underMessages = math.max(h * HudStack.MESSAGE_BOTTOM, (band or 0) + HudStack.GAP) + HudStack.GAP
	local width = math.max(HudStack.TRACKER, if touch then HudStack.PANEL_TOUCH else HudStack.PANEL_PC)
	if touch then
		local top = if others > 0 then HudStack.PARTY_TOP + others * HudStack.PARTY_ROW else HudStack.TOUCH_TOP
		return {
			x = HudStack.MARGIN,
			right = false,
			top = top,
			floor = h - HudStack.TOUCH_ROW - HudStack.GAP,
			-- right of the buttons right of the portrait (Cloak of Luring and the auto buttons end above TOUCH_TOP)
			spares = { HudStack.EXTRAS.x + HudStack.EXTRAS.w + HudStack.GAP },
			spareTop = math.max(HudStack.TOUCH_TOP, underMessages),
			width = width,
			chip = HudStack.CHIP_TOUCH,
		}
	end
	local top = math.max(
		(if guide then HudStack.RIGHT_TOP_GUIDE else HudStack.RIGHT_TOP)
			+ (if waiting then HudStack.WAITING + HudStack.GAP else 0),
		if menuBottom and menuBottom > 0 then menuBottom + HudStack.GAP else 0
	)
	return {
		x = w - HudStack.MARGIN,
		right = true,
		top = top,
		floor = HudStack.cornerTop(false, w, h) - HudStack.GAP,
		-- two: a short window at the 0.6 floor has little height under the minimap (owner 2026-10-22)
		spares = {
			w - HudStack.MARGIN - HudStack.TRACKER - HudStack.GAP,
			w - HudStack.MARGIN - 2 * (HudStack.TRACKER + HudStack.GAP),
		},
		spareTop = math.max(top, underMessages),
		width = width,
		chip = HudStack.CHIP,
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

-- Owner 2026-10-22 (Studio 1462 x 793: a tracker the player had moved, at 1675 x 455 near its built-in place, ran 38
-- units into the PvP toggle, because a moved element only knew the screen's bottom): the floor of an element moved to
-- [left, right] from `top`: `bottom`, or GAP above the first of `under` (the corner's buttons, computed and measured)
-- that stands below its top in its lane.
function HudStack.floorUnder(left: number, right: number, top: number, bottom: number, under: { Rect }): number
	local floor = bottom
	for _, r in under do
		if r.top > top and r.left < right and left < r.right then
			floor = math.min(floor, r.top - HudStack.GAP)
		end
	end
	return floor
end

-- The quest tracker's list height at `top` with the floor `floor` (its column place's bottom, or `floorUnder` once
-- moved); the frame adds `chrome` (padding, header, gap). As tall as its content (`content`), a resized tracker its
-- saved height (`sized`, the whole frame), never past the floor: with no room the list hides and the header stays.
function HudStack.trackerBody(top: number, floor: number, chrome: number, content: number, sized: number?): number
	local wanted = if sized then sized - chrome else content
	return math.max(0, math.min(wanted, floor - top - chrome))
end

-- UI plan phase 1 (owner 2026-10-31; DESIGN §23 "lower left: chat"): on PC the Roblox chat window stands in the lower
-- left corner (Hud/ChatDock) and ends CHAT_GAP screen px left of the action bar: the WidthScale for a window standing
-- at `left`, `width` wide at WidthScale `scale`, with the bar starting at `barLeft` (screen px); never wider than
-- Roblox's own width (1) nor narrower than CHAT_MIN. A hidden window (no width) keeps `scale`.
HudStack.CHAT_GAP = 12
HudStack.CHAT_MIN = 0.6
function HudStack.chatWidthScale(left: number, width: number, scale: number, barLeft: number): number
	if width <= 0 or scale <= 0 then
		return scale
	end
	local base = width / scale
	return math.clamp((barLeft - HudStack.CHAT_GAP - left) / base, HudStack.CHAT_MIN, 1)
end

-- UI plan package A (owner 2026-11-10: "things covering each other"): on a short PC screen Roblox's chat window, as
-- tall as Roblox makes it, reached the party rows and the NPC bark's slot over it. It shortens as much as it must to
-- keep its top CHAT_GAP screen px under `ceiling` (the bark slot's bottom, screen px): the HeightScale for a window
-- standing from `top`, `height` tall at HeightScale `scale` (bottom-aligned, so its bottom stays); never taller than
-- Roblox's own height (1) nor shorter than CHAT_MIN_H of it. A hidden window (no height) keeps `scale`.
HudStack.CHAT_MIN_H = 0.5
function HudStack.chatHeightScale(top: number, height: number, scale: number, ceiling: number): number
	if height <= 0 or scale <= 0 then
		return scale
	end
	local base = height / scale
	return math.clamp((top + height - ceiling - HudStack.CHAT_GAP) / base, HudStack.CHAT_MIN_H, 1)
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end
HudStack.overlaps = overlaps

-- How `place` shows one element: at its height, shrunk to its least, folded to its line or behind the '+N' chip.
type Mode = "full" | "least" | "line" | "hidden"

-- The '+N' chip of `column`: at the floor, at the far end of the lane, GAP over the `fixed` rectangles in its way
-- (the PC Elite II timers stand right over the corner's buttons); never above the column's top.
local function chipOf(column: Column, fixed: { Rect }): Rect
	local size = column.chip or HudStack.CHIP
	local width = math.max(column.width or size.w, size.w)
	local left = if column.right then column.x - size.w else column.x + width - size.w
	local right = left + size.w
	local top = column.floor - size.h
	for _ = 1, #fixed + 1 do
		local moved = false
		for _, r in fixed do
			if r.left < right and left < r.right and r.top < top + size.h and top < r.bottom then
				top = r.top - HudStack.GAP - size.h
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	top = math.max(top, column.top)
	return { left = left, top = top, right = right, bottom = top + size.h }
end

-- The places of `items` (in order, top down) in `column`, round the `fixed` rectangles (moved elements, the corner's
-- buttons, the PC Elite II timers). An element goes at the first free place under the one before it. Nothing ever
-- goes past the floor (UI plan package A): when the elements do not fit, the column shrinks every `least` element (the
-- tracker to its header and two lines), then folds the `line` elements to their line from the lowest up (the panels
-- first, a `grow` one, the tracker, last; a `keep` one after the others) and opens again, from the top, what still
-- fits. Only when even the lines do not fit, an element that finds no room goes to the first free place of a spare
-- column from its top (owner 2026-10-22: a short window at the 0.6 floor), and after that the lowest elements hide
-- behind the '+N' chip at the floor (a `keep` one last). A `grow` element reaches down to the floor or to the first
-- rectangle under it.
function HudStack.place(items: { Item }, column: Column, fixed: { Rect }): Placed
	local gap = HudStack.GAP
	local function span(edge: number, w: number): (number, number)
		if column.right then
			return edge - w, edge
		end
		return edge, edge + w
	end
	local modes: { Mode } = {}
	for i in items do
		modes[i] = "full"
	end
	local chip = chipOf(column, fixed)

	-- the places with today's modes, or nil when one element finds no room above the floor (`spares`: in a spare
	-- column too)
	local function attempt(withChip: boolean, spares: boolean): { [string]: Rect }?
		local out: { [string]: Rect } = {}
		local taken: { Rect } = table.clone(fixed)
		if withChip then
			-- the elements above the chip stand GAP over it (beside it on a phone, PhoneHud.PANEL_WIDTH keeps clear)
			table.insert(taken, { left = chip.left, top = chip.top - gap, right = chip.right, bottom = chip.bottom })
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
		-- the column, else the first spare one, with room for a w x h box above the floor: its left, right and top,
		-- and whether it is the main column
		local function room(w: number, h: number, cursor: number): (boolean, number, number, number, boolean)
			local left, right = span(column.x, w)
			local y = free(left, right, cursor, h)
			if y + h <= column.floor + 1e-6 then
				return true, left, right, y, true
			end
			local edges: { number } = if spares then column.spares or {} else {}
			for _, spare in edges do
				local sl, sr = span(spare, w)
				local sy = free(sl, sr, column.spareTop or column.top, h)
				if sy + h <= column.floor + 1e-6 then
					return true, sl, sr, sy, false
				end
			end
			return false, left, right, y, true
		end
		local cursor = column.top
		for i, item in items do
			local mode = modes[i]
			if mode == "hidden" then
				continue
			end
			local h = if mode == "line"
				then item.line or item.h
				elseif mode == "least" then item.least or item.h
				else item.h
			local found, x, right, y, main = room(item.w, h, cursor)
			if not found then
				return nil
			end
			local bottom = y + h
			if item.grow and mode ~= "line" then
				local limit = column.floor
				for _, r in taken do
					if r.left < right and x < r.right and r.top >= y and r.top - gap < limit then
						limit = r.top - gap
					end
				end
				bottom = math.max(bottom, limit)
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

	local function result(rects: { [string]: Rect }, withChip: boolean): Placed
		local folded: { string } = {}
		local hidden: { string } = {}
		for i, item in items do
			if modes[i] == "line" then
				table.insert(folded, item.id)
			elseif modes[i] == "hidden" then
				table.insert(hidden, item.id)
			end
		end
		return { rects = rects, folded = folded, hidden = hidden, chip = if withChip then chip else nil }
	end

	-- the indices from the lowest up, the kept ones after the others
	local function lowestFirst(pick: (Item) -> boolean): { number }
		local out: { number } = {}
		for _, keep in { false, true } do
			for i = #items, 1, -1 do
				local item = items[i]
				if (item.keep == true) == keep and pick(item) then
					table.insert(out, i)
				end
			end
		end
		return out
	end

	-- opens again, from the top, the folded or shrunk elements that still fit in the main column (a fold leaves room);
	-- it stops at the first that does not, so a lower panel never stands open while a higher one is folded
	local function relax(rects: { [string]: Rect }): { [string]: Rect }
		for i, item in items do
			local was = modes[i]
			if was ~= "line" and was ~= "least" then
				continue
			end
			local opened = false
			for _, better: Mode in (if was == "line" then { "full", "least" } else { "full" }) :: { Mode } do
				if better == "least" and not (item.least and item.least < item.h) then
					continue
				end
				modes[i] = better
				local tried = attempt(false, false)
				if tried then
					rects = tried
					opened = better == "full"
					break
				end
				modes[i] = was
			end
			if not opened then
				break
			end
		end
		return rects
	end

	local rects = attempt(false, false)
	if rects then
		return result(rects, false)
	end
	-- 1. the least height of what may shrink
	for i, item in items do
		if item.least and item.least < item.h then
			modes[i] = "least"
		end
	end
	rects = attempt(false, false)
	if rects then
		return result(rects, false)
	end
	-- 2. the panels fold to their line from the lowest up, then the growing ones (the tracker to its header)
	local folds = lowestFirst(function(item: Item): boolean
		return item.line ~= nil and item.line < item.h and not item.grow
	end)
	for _, i in
		lowestFirst(function(item: Item): boolean
			return item.line ~= nil and item.line < item.h and item.grow == true
		end)
	do
		table.insert(folds, i)
	end
	for _, i in folds do
		modes[i] = "line"
		rects = attempt(false, false)
		if rects then
			return result(relax(rects), false)
		end
	end
	-- 3. what still finds no room goes to a spare column (the lines stay folded)
	rects = attempt(false, true)
	if rects then
		return result(rects, false)
	end
	-- 4. behind the '+N' chip from the lowest up
	for _, i in
		lowestFirst(function(): boolean
			return true
		end)
	do
		modes[i] = "hidden"
		rects = attempt(true, true)
		if rects then
			return result(rects, true)
		end
	end
	return result({}, true)
end

-- The built-in place of every shown element of `boxes` (by id, HudStack.ORDER) that the player has not moved, on a
-- w x h screen: PC (`touch` false), a touch screen that is not a phone, a phone (`compact`); `others` = party members
-- besides the player. Moved elements, the corner's buttons and the buttons right of the portrait (not on a phone:
-- Logic/PhoneHud keeps the stack clear of them) and the PC Elite II timers are obstacles the others go round.
-- `measured`: the corner's buttons as they really stand (`fromScreen`; not on a phone): obstacles too, and the column's
-- floor stays above them (`floorAbove`) when the computed one is lower (owner 2026-10-22). `guide`: the guide bar shows
-- under the minimap (PC: the column starts under it); `waiting`, `menuBottom` and `band`: HudStack.column. The whole
-- result of `place`: the rectangles, the folded and the hidden ids and the '+N' chip.
function HudStack.arrange(
	touch: boolean,
	compact: boolean,
	w: number,
	h: number,
	others: number,
	boxes: { [string]: Box },
	measured: { Rect }?,
	guide: boolean?,
	waiting: boolean?,
	menuBottom: number?,
	band: number?
): Placed
	local column = HudStack.column(touch, compact, w, h, others, guide, waiting, menuBottom, band)
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
				-- the tracker keeps its header and two lines while a panel can still fold
				least = if tracker then math.min(box.h, HudStack.TRACKER_MIN) else nil,
				line = box.line,
				keep = box.keep,
			}
			table.insert(items, item)
		end
	end
	return HudStack.place(items, column, fixed)
end

-- The rectangles of `arrange` (the folded elements' lines; nothing for the hidden ones).
function HudStack.layout(
	touch: boolean,
	compact: boolean,
	w: number,
	h: number,
	others: number,
	boxes: { [string]: Box },
	measured: { Rect }?,
	guide: boolean?,
	waiting: boolean?,
	menuBottom: number?
): { [string]: Rect }
	return HudStack.arrange(touch, compact, w, h, others, boxes, measured, guide, waiting, menuBottom).rects
end

return HudStack
