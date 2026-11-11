--!strict
-- W29: the HUD of a phone in landscape ("compact"): a touch screen whose UI area is shorter than MAX_HEIGHT virtual
-- pixels (UI/Scale keeps touch buttons at least Theme.Size.MinTouch, so an 844 x 390 or 667 x 375 phone is only
-- ~440 virtual pixels high, while the HUD is laid out for 720).
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan package A, the phone grid of
-- the zone map): every element has one place in one grid, measured from an edge of the HUD's layer (Screens, under
-- Roblox's top bar, `area`):
--   left    the portrait (scaled); one row under it with the Auto button (Lure, Auto Hunt and Auto Potion in its
--           popover, as on PC) and the blessing, elixirs, return bonus and effect icons; then the "stack" of 52-px
--           lines (party strip, arena, event panels, Elite II, the guide when M has no room, the quest tracker) down to
--           the thumb zone, the rest behind a '+N' chip at the stack's right end (Logic/HudStack.place);
--   centre  the target frame with a '⋯' button for the player menu beside it, and under it the M zone: the target's
--           effect icons, the cast line (cast bar or weapon pool name) and the guide bar while M reaches 218;
--   right   the minimap (0.6, or 0.5 on a layer under 420 high so the arc stays clear), the menu drawer button and the
--           PvP toggle (its countdown inside) left of it;
--   bottom  attack button in the corner, five skill buttons on an arc around it, page and target buttons, potions,
--           sprint and mount, the mail icon over the target button (owner 2026-10-21), unchanged since W29.
-- The left thumb zone (Logic/HudZones.thumb, Roblox's dynamic thumbstick) holds nothing persistent: the stack ends
-- 8 px above it. A place is a rectangle measured from one corner of the layer (`edge` "tl" / "tr" / "bl" / "br", `x`,
-- `y` = the distance of the rectangle's corner on that side from the layer's corner); the stack runs down to
-- `stackBottom`. Pure; tests/phonehud.spec checks the three phones of DEVICES under a top bar of 0, 36 and 58 px:
-- nothing overlaps, nothing leaves the layer or lies in the thumb zone, and every touch target keeps its size.

local PhoneHud = {}

PhoneHud.MAX_HEIGHT = 560

-- The phones the layout is checked on: viewport (points), safe-area insets (left, top, right, bottom) and the UI
-- scale (UI/Scale: the touch minimum 44 / 52 on every phone).
PhoneHud.DEVICES = {
	{ name = "844x390", w = 844, h = 390, insets = { 47, 0, 47, 21 } },
	{ name = "667x375", w = 667, h = 375, insets = { 0, 0, 0, 0 } },
	{ name = "932x430", w = 932, h = 430, insets = { 59, 0, 59, 21 } },
}
PhoneHud.SCALE = 44 / 52
PhoneHud.MIN_TOUCH = 44
-- The controls of the right thumb (attack, skills, the drawer button, sprint, mount) keep at least this.
PhoneHud.CONTROL = 52

export type Place = {
	edge: "tl" | "tr" | "bl" | "br",
	x: number,
	y: number,
	w: number,
	h: number,
	bottom: number?, -- legacy: down to this many pixels above the bottom
	stack: boolean?, -- the stack: down to `stackBottom` of the layer
	scale: number?, -- UIScale of the element (its own size is w / scale x h / scale)
	round: boolean?, -- a round button (overlap measured between circles)
	touch: boolean?, -- a touch target (at least MIN_TOUCH on its short side)
	control: boolean?, -- a control of the right thumb (at least CONTROL)
}

-- Element scales: the portrait, and the minimap's two sizes (`minimapScale`).
PhoneHud.PORTRAIT_SCALE = 0.7
PhoneHud.MINIMAP_SCALE = 0.6
PhoneHud.MINIMAP_SMALL = 0.5
-- A layer at least this high takes the 0.6 minimap; a shorter one the 0.5 (the skill arc reaches up to it).
PhoneHud.MINIMAP_TALL = 420
-- Hud/Minimap's frame at scale 1 (SIZE 220 + 44, SIZE + 46): 158 x 160 at 0.6, 132 x 133 at 0.5.
PhoneHud.MINIMAP = table.freeze({ w = 264, h = 266 })

-- The bottom-right arc (MobileSkills): attack button size, skill button size, arc radius, angles (degrees, 0 = right,
-- 90 = up) and the distance of the attack button from the corner.
PhoneHud.ATTACK = 80
PhoneHud.SKILL = 52
PhoneHud.RADIUS = 125
PhoneHud.ANGLES = { 185, 160, 135, 110, 85 }
PhoneHud.CORNER = { x = 8, y = 24 } -- y clears the EXP bar

-- The left column: the row under the portrait (Auto, then the buffs), the stack from STACK_TOP in LINE-px lines down
-- to STACK_BOTTOM over the layer's bottom or 8 over the thumb zone's top (THUMB_TOP of the layer's height), whichever
-- is higher. The '+N' chip stands at the stack's right end (CHIP, Logic/HudStack.place).
PhoneHud.ROW_TOP = 93
PhoneHud.ROW = 52
PhoneHud.LINE = 52
PhoneHud.LINE_GAP = 8
PhoneHud.STACK_TOP = 153
PhoneHud.STACK_BOTTOM = 28
PhoneHud.STACK_WIDTH = 260
PhoneHud.THUMB_TOP = 0.58
PhoneHud.CHIP = table.freeze({ w = 44, h = 52 })

-- The M zone (centre): from M_LEFT to the drawer button less M_RIGHT, from M_TOP down to M_BOTTOM or 8 over the mail
-- icon. Its parts top down: the target's effect icons, the cast line, the guide bar (only while M reaches M_BOTTOM).
PhoneHud.M_LEFT = 296
PhoneHud.M_TOP = 104
PhoneHud.M_BOTTOM = 218
PhoneHud.M_RIGHT = 74 -- past the minimap's width: the drawer button (52), its gap (14) and 8

-- Widths of the elements that change on a phone.
PhoneHud.TARGET_WIDTH = 220
PhoneHud.CASTBAR_WIDTH = 220
PhoneHud.NAVBAR_WIDTH = 236
-- Every item of the stack ends 6 px left of the '+N' chip, so it can stand beside the chip in the stack's last line:
-- the panels, the arena's pill and the guide line (PANEL_WIDTH), the tracker, which grows down to the floor where the
-- chip stands (TRACKER_WIDTH), and the party's strip (PARTY_WIDTH: PARTY_TILES tiles of one line, PARTY_GAP apart, and
-- a PARTY_MORE wide "+N" tile). Package A review (owner 2026-11-10, "things covering each other"): wider ones (the
-- party 218, the event panels 220 and 240, the pill 280, the tracker 260) met the chip and went behind it, so a phone
-- could show nothing but '+N', and picking one from the list brought nothing back.
PhoneHud.PANEL_WIDTH = PhoneHud.STACK_WIDTH - PhoneHud.CHIP.w - 6
PhoneHud.TRACKER_WIDTH = PhoneHud.PANEL_WIDTH
PhoneHud.PARTY_TILES = 3
PhoneHud.PARTY_GAP = 3
PhoneHud.PARTY_MORE = 44
PhoneHud.PARTY_WIDTH = PhoneHud.PARTY_TILES * (PhoneHud.LINE + PhoneHud.PARTY_GAP) + PhoneHud.PARTY_MORE
-- The Auto popover (Lure, Auto Hunt, Auto Potion): right of the Auto button over the row, an overlay the player opens.
PhoneHud.AUTO_POPOVER = table.freeze({ w = 3 * 52 + 4 * 8, h = 52 + 2 * 8 })

-- The minimap's scale on a layer `h` high.
function PhoneHud.minimapScale(h: number): number
	return if h >= PhoneHud.MINIMAP_TALL then PhoneHud.MINIMAP_SCALE else PhoneHud.MINIMAP_SMALL
end

-- The minimap's size on a layer `h` high (rounded like the zone map: 158 x 160, 132 x 133).
function PhoneHud.minimapSize(h: number): (number, number)
	local s = PhoneHud.minimapScale(h)
	return math.round(PhoneHud.MINIMAP.w * s), math.round(PhoneHud.MINIMAP.h * s)
end

-- The bottom of the stack on a layer `h` high: 28 over the bottom, or 8 over the thumb zone, whichever is higher.
function PhoneHud.stackBottom(h: number): number
	return math.min(h - PhoneHud.STACK_BOTTOM, math.round(PhoneHud.THUMB_TOP * h) - 8)
end

-- How many LINE-px lines the stack holds on a layer `h` high (the '+N' chip shares the last one).
function PhoneHud.stackLines(h: number): number
	local room = PhoneHud.stackBottom(h) - PhoneHud.STACK_TOP
	return math.max(0, math.floor((room + PhoneHud.LINE_GAP) / (PhoneHud.LINE + PhoneHud.LINE_GAP)))
end

-- The centre of skill button `i` (1..5) of the arc, as offsets from the bottom-right corner (negative = left / up).
function PhoneHud.skillCenter(i: number): (number, number)
	local cx = -(PhoneHud.CORNER.x + PhoneHud.ATTACK / 2)
	local cy = -(PhoneHud.CORNER.y + PhoneHud.ATTACK / 2)
	local a = math.rad(PhoneHud.ANGLES[i])
	return cx + math.cos(a) * PhoneHud.RADIUS, cy - math.sin(a) * PhoneHud.RADIUS
end

-- The mail icon (owner 2026-10-21: only while parcels wait, over the target button, left of the arc).
local MAIL = table.freeze({ x = 206, y = 130, w = 48, h = 48 })

-- The M zone of a w x h layer: left, top, right, bottom.
function PhoneHud.mZone(w: number, h: number): (number, number, number, number)
	local mw = PhoneHud.minimapSize(h)
	local mailTop = h - MAIL.y - MAIL.h
	return PhoneHud.M_LEFT, PhoneHud.M_TOP, w - (mw + PhoneHud.M_RIGHT), math.min(PhoneHud.M_BOTTOM, mailTop - 8)
end

-- Whether the guide bar has its place in M (else it takes a line of the stack, Logic/HudStack "guide").
function PhoneHud.guideInM(w: number, h: number): boolean
	local _, _, _, bottom = PhoneHud.mZone(w, h)
	return bottom >= PhoneHud.M_BOTTOM
end

-- Every place of a w x h layer by name.
function PhoneHud.places(w: number, h: number): { [string]: Place }
	local mw, mh = PhoneHud.minimapSize(h)
	local left, top, right = PhoneHud.mZone(w, h)
	local mWidth = right - left
	local out: { [string]: Place } = {
		-- left
		-- UI plan phase 4: the portrait is 340 x 110 (Logic/HudStack.PORTRAIT), so 238 x 77 here
		portrait = { edge = "tl", x = 8, y = 8, w = 238, h = 77, scale = PhoneHud.PORTRAIT_SCALE },
		auto = { edge = "tl", x = 8, y = PhoneHud.ROW_TOP, w = 52, h = PhoneHud.ROW, touch = true },
		-- the blessing, elixirs, return bonus and effect icons, then their '+N'
		effects = { edge = "tl", x = 8 + 52 + 8, y = PhoneHud.ROW_TOP, w = 280 - 60, h = PhoneHud.ROW },
		stack = {
			edge = "tl",
			x = 8,
			y = PhoneHud.STACK_TOP,
			w = PhoneHud.STACK_WIDTH,
			h = 0,
			stack = true,
		},
		-- centre
		target = { edge = "tl", x = left, y = 8, w = PhoneHud.TARGET_WIDTH, h = 92 },
		-- the player menu's "⋯" right of the frame (4 px: the drawer button of the narrowest phone starts 48 px on)
		targetActions = { edge = "tl", x = left + PhoneHud.TARGET_WIDTH + 4, y = 8, w = 44, h = 44, touch = true },
		targetEffects = { edge = "tl", x = left, y = top, w = math.min(236, mWidth), h = 36 },
		-- the cast line: the cast bar, or the weapon pool's name while no cast runs (Hud/PoolLabel)
		castBar = { edge = "tl", x = left, y = top + 40, w = math.min(PhoneHud.CASTBAR_WIDTH, mWidth), h = 26 },
		-- right
		minimap = { edge = "tr", x = 8, y = 8, w = mw, h = mh, scale = PhoneHud.minimapScale(h) },
		menuToggle = { edge = "tr", x = mw + 14, y = 8, w = 52, h = 52, touch = true, control = true },
		-- the countdown stands inside the toggle (no badge under it)
		pvp = { edge = "tr", x = mw + 14, y = 66, w = 52, h = 52, touch = true, round = true },
		-- bottom
		attack = {
			edge = "br",
			x = PhoneHud.CORNER.x,
			y = PhoneHud.CORNER.y,
			w = PhoneHud.ATTACK,
			h = PhoneHud.ATTACK,
			touch = true,
			round = true,
			control = true,
		},
		page = { edge = "br", x = 206, y = 30, w = 84, h = 44, touch = true },
		targetButton = { edge = "br", x = 206, y = 80, w = 84, h = 44, touch = true },
		mail = { edge = "br", x = MAIL.x, y = MAIL.y, w = MAIL.w, h = MAIL.h, touch = true },
		potions = { edge = "br", x = 298, y = 28, w = 180, h = 56, touch = true },
		sprint = { edge = "br", x = 298, y = 92, w = 64, h = 64, touch = true, round = true, control = true },
		mount = { edge = "br", x = 368, y = 92, w = 64, h = 64, touch = true, control = true },
	}
	if PhoneHud.guideInM(w, h) then
		out.navBar =
			{ edge = "tl", x = left, y = top + 70, w = math.min(PhoneHud.NAVBAR_WIDTH, mWidth), h = 44, touch = true }
	end
	for i = 1, #PhoneHud.ANGLES do
		local dx, dy = PhoneHud.skillCenter(i)
		out[`skill{i}`] = {
			edge = "br",
			x = -dx - PhoneHud.SKILL / 2,
			y = -dy - PhoneHud.SKILL / 2,
			w = PhoneHud.SKILL,
			h = PhoneHud.SKILL,
			touch = true,
			round = true,
			control = true,
		}
	end
	return out
end

-- The places of the first phone of DEVICES without a top bar: the reference set for code and specs that need one
-- place by name (every place but the minimap, the M zone's and the stack's ends is the same on each phone).
local REFERENCE_W = (844 - 47 - 47) / PhoneHud.SCALE
local REFERENCE_H = (390 - 0 - 21) / PhoneHud.SCALE
PhoneHud.PLACES = table.freeze(PhoneHud.places(REFERENCE_W, REFERENCE_H))

-- The top of the stack: the party strip is one of its lines (UI plan package A), so `others` no longer moves it.
PhoneHud.PARTY_ROW = 58 + 6
function PhoneHud.stackTop(_others: number?): number
	return PhoneHud.STACK_TOP
end

-- Whether the HUD takes the phone layout: a touch screen shorter than MAX_HEIGHT virtual pixels.
function PhoneHud.compact(touch: boolean, virtualHeight: number): boolean
	return touch and virtualHeight < PhoneHud.MAX_HEIGHT
end

-- The place of an element on a w x h layer (default: the reference phone), nil for an unknown name.
function PhoneHud.place(name: string, w: number?, h: number?): Place?
	if w and h then
		return PhoneHud.places(w, h)[name]
	end
	return PhoneHud.PLACES[name]
end

-- UDim2 parts and anchor point of a place: (xScale, xOffset, yScale, yOffset, anchorX, anchorY).
function PhoneHud.udim(place: Place): (number, number, number, number, number, number)
	local right = place.edge == "tr" or place.edge == "br"
	local bottom = place.edge == "bl" or place.edge == "br"
	return if right then 1 else 0,
		if right then -place.x else place.x,
		if bottom then 1 else 0,
		if bottom then -place.y else place.y,
		if right then 1 else 0,
		if bottom then 1 else 0
end

export type Rect = { left: number, top: number, right: number, bottom: number, round: boolean }

-- The rectangle of a place on a UI area of w x h virtual pixels.
function PhoneHud.rect(place: Place, w: number, h: number): Rect
	local height = if place.stack
		then PhoneHud.stackBottom(h) - place.y
		elseif place.bottom then h - place.bottom - place.y
		else place.h
	local left = if place.edge == "tr" or place.edge == "br" then w - place.x - place.w else place.x
	local top = if place.edge == "bl" or place.edge == "br" then h - place.y - height else place.y
	return { left = left, top = top, right = left + place.w, bottom = top + height, round = place.round == true }
end

-- The UI area (the HUD's layer) of a device in virtual pixels: the safe area under Roblox's top bar (`topBar` real
-- pixels, default 0), divided by the UI scale.
function PhoneHud.area(device: { w: number, h: number, insets: { number } }, topBar: number?): (number, number)
	local i = device.insets
	local top = math.max(i[2], topBar or 0)
	return (device.w - i[1] - i[3]) / PhoneHud.SCALE, (device.h - top - i[4]) / PhoneHud.SCALE
end

-- The thumbstick zone of a w x h layer (Logic/HudZones.THUMB as shares; kept here so HudZones stays above PhoneHud).
PhoneHud.THUMB = table.freeze({ x = 0.04, y = PhoneHud.THUMB_TOP, w = 0.26, h = 0.34 })
function PhoneHud.thumb(w: number, h: number): Rect
	local t = PhoneHud.THUMB
	return { left = w * t.x, top = h * t.y, right = w * (t.x + t.w), bottom = h * (t.y + t.h), round = false }
end

local function overlapRects(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

local function circle(r: Rect): (number, number, number)
	return (r.left + r.right) / 2, (r.top + r.bottom) / 2, math.min(r.right - r.left, r.bottom - r.top) / 2
end

-- Whether two placed elements overlap (circles for two round buttons, circle against rectangle for one).
function PhoneHud.overlaps(a: Rect, b: Rect): boolean
	if not overlapRects(a, b) then
		return false
	end
	if a.round and b.round then
		local ax, ay, ar = circle(a)
		local bx, by, br = circle(b)
		return (ax - bx) ^ 2 + (ay - by) ^ 2 < (ar + br) ^ 2
	end
	if a.round or b.round then
		local c, r = if a.round then a else b, if a.round then b else a
		local cx, cy, radius = circle(c)
		local nx = math.clamp(cx, r.left, r.right)
		local ny = math.clamp(cy, r.top, r.bottom)
		return (cx - nx) ^ 2 + (cy - ny) ^ 2 < radius * radius
	end
	return true
end

-- Every pair of elements that overlap on a w x h area, as "a / b" strings, the elements reaching off the area and (UI
-- plan package A) the faults: an element in the thumb zone ("name in the thumb zone") and a touch target under its
-- minimum, CONTROL for the right thumb's controls and MIN_TOUCH for the others ("name 40 < 44").
function PhoneHud.problems(w: number, h: number): ({ string }, { string }, { string })
	local places = PhoneHud.places(w, h)
	local names = {}
	for name in places do
		table.insert(names, name)
	end
	table.sort(names)
	local rects: { [string]: Rect } = {}
	local outside = {}
	for _, name in names do
		local r = PhoneHud.rect(places[name], w, h)
		rects[name] = r
		if r.left < 0 or r.top < 0 or r.right > w or r.bottom > h or r.bottom <= r.top then
			table.insert(outside, name)
		end
	end
	local clashes = {}
	for i, a in names do
		for j = i + 1, #names do
			local b = names[j]
			if PhoneHud.overlaps(rects[a], rects[b]) then
				table.insert(clashes, `{a} / {b}`)
			end
		end
	end
	local faults = {}
	local thumb = PhoneHud.thumb(w, h)
	for _, name in names do
		local place = places[name]
		if PhoneHud.overlaps(rects[name], thumb) then
			table.insert(faults, `{name} in the thumb zone`)
		end
		if place.touch then
			local least = if place.control then PhoneHud.CONTROL else PhoneHud.MIN_TOUCH
			local side = math.min(place.w, place.h)
			if side < least then
				table.insert(faults, `{name} {side} < {least}`)
			end
		end
	end
	return clashes, outside, faults
end

return PhoneHud
