--!strict
-- W29: the HUD of a phone in landscape ("compact"): a touch screen whose UI area is shorter than MAX_HEIGHT virtual
-- pixels (UI/Scale keeps touch buttons at least Theme.Size.MinTouch, so an 844 x 390 or 667 x 375 phone is only
-- ~440 virtual pixels high, while the HUD is laid out for 720). Every element gets a place in one of four zones:
--   left    portrait (scaled), the Cloak / Auto Hunt / Auto Potion toggles, own effect icons, blessings, then the
--           "stack" (party frames, world boss / event / Blood Moon panels, quest tracker) down to the EXP bar;
--   centre  target frame, its effect icons, the cast bar and the "Actions" button under it;
--   right   minimap (scaled), the menu drawer button (the 14 menu buttons open as a drawer), the PvP toggle, the
--           guide bar under the minimap;
--   bottom  attack button in the corner, five skill buttons on an arc around it, page and target buttons, potions,
--           sprint, mount and emote (the bottom skill bar is hidden: the arc holds the same ten slots), the mail
--           icon over the target button.
-- A place is a rectangle measured from one corner of the UI area (`edge` "tl" / "tr" / "bl" / "br", `x`, `y` = the
-- distance of the rectangle's corner on that side from the screen's corner) or, for the stack, from the top-left
-- down to `bottom` pixels above the screen's bottom. Pure; tests/phonehud.spec checks that nothing overlaps on the
-- phones of DEVICES and that every touch target keeps Theme.Size.MinTouch.

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

export type Place = {
	edge: "tl" | "tr" | "bl" | "br",
	x: number,
	y: number,
	w: number,
	h: number,
	bottom: number?, -- the stack: from y down to this many pixels above the bottom
	scale: number?, -- UIScale of the element (its own size is w / scale x h / scale)
	round: boolean?, -- a round button (overlap measured between circles)
	touch: boolean?, -- a touch target (at least MIN_TOUCH on its short side)
}

-- Element scales.
PhoneHud.PORTRAIT_SCALE = 0.7
PhoneHud.MINIMAP_SCALE = 0.6

-- The bottom-right arc (MobileSkills): attack button size, skill button size, arc radius, angles (degrees, 0 = right,
-- 90 = up) and the distance of the attack button from the corner.
PhoneHud.ATTACK = 80
PhoneHud.SKILL = 52
PhoneHud.RADIUS = 125
PhoneHud.ANGLES = { 185, 160, 135, 110, 85 }
PhoneHud.CORNER = { x = 8, y = 24 } -- y clears the EXP bar

-- The top of the left stack (party frames, panels, quest tracker) and the gap above the bottom.
PhoneHud.STACK_TOP = 298
PhoneHud.STACK_BOTTOM = 28

-- Widths of the elements that change on a phone.
PhoneHud.TARGET_WIDTH = 220
PhoneHud.CASTBAR_WIDTH = 220
PhoneHud.NAVBAR_WIDTH = 236
PhoneHud.PANEL_WIDTH = 220
PhoneHud.TRACKER_WIDTH = 260

local PLACES: { [string]: Place } = {
	-- left
	portrait = { edge = "tl", x = 8, y = 8, w = 280, h = 96, scale = PhoneHud.PORTRAIT_SCALE },
	lure = { edge = "tl", x = 8, y = 110, w = 48, h = 68, touch = true },
	autoGrind = { edge = "tl", x = 62, y = 110, w = 48, h = 68, touch = true },
	autoPotion = { edge = "tl", x = 116, y = 110, w = 48, h = 68, touch = true },
	effects = { edge = "tl", x = 8, y = 182, w = 268, h = 44 },
	blessing = { edge = "tl", x = 8, y = 230, w = 280, h = 64 },
	stack = { edge = "tl", x = 8, y = PhoneHud.STACK_TOP, w = 260, h = 0, bottom = PhoneHud.STACK_BOTTOM },
	-- centre
	target = { edge = "tl", x = 296, y = 8, w = PhoneHud.TARGET_WIDTH, h = 92 },
	targetEffects = { edge = "tl", x = 296, y = 110, w = 236, h = 40 },
	castBar = { edge = "tl", x = 296, y = 154, w = PhoneHud.CASTBAR_WIDTH, h = 26 },
	actions = { edge = "tl", x = 296, y = 184, w = 100, h = 48, touch = true },
	pool = { edge = "tl", x = 296, y = 238, w = 220, h = 24 }, -- the weapon pool's name for a moment
	-- right
	minimap = { edge = "tr", x = 8, y = 8, w = 158, h = 160, scale = PhoneHud.MINIMAP_SCALE },
	menuToggle = { edge = "tr", x = 172, y = 8, w = 52, h = 52, touch = true },
	pvp = { edge = "tr", x = 172, y = 66, w = 64, h = 64, touch = true, round = true },
	pvpBadge = { edge = "tr", x = 172, y = 132, w = 64, h = 24 },
	navBar = { edge = "tr", x = 8, y = 174, w = PhoneHud.NAVBAR_WIDTH, h = 44, touch = true },
	-- bottom
	attack = {
		edge = "br",
		x = PhoneHud.CORNER.x,
		y = PhoneHud.CORNER.y,
		w = PhoneHud.ATTACK,
		h = PhoneHud.ATTACK,
		touch = true,
		round = true,
	},
	page = { edge = "br", x = 206, y = 30, w = 84, h = 44, touch = true },
	targetButton = { edge = "br", x = 206, y = 80, w = 84, h = 44, touch = true },
	-- owner 2026-10-21: the mail icon (only while parcels wait) over the target button, left of the arc
	mail = { edge = "br", x = 206, y = 130, w = 48, h = 48, touch = true },
	potions = { edge = "br", x = 298, y = 28, w = 180, h = 56, touch = true },
	sprint = { edge = "br", x = 298, y = 92, w = 64, h = 64, touch = true, round = true },
	mount = { edge = "br", x = 368, y = 92, w = 64, h = 64, touch = true },
	emote = { edge = "br", x = 438, y = 92, w = 56, h = 56, touch = true },
}

-- The centre of skill button `i` (1..5) of the arc, as offsets from the bottom-right corner (negative = left / up).
function PhoneHud.skillCenter(i: number): (number, number)
	local cx = -(PhoneHud.CORNER.x + PhoneHud.ATTACK / 2)
	local cy = -(PhoneHud.CORNER.y + PhoneHud.ATTACK / 2)
	local a = math.rad(PhoneHud.ANGLES[i])
	return cx + math.cos(a) * PhoneHud.RADIUS, cy - math.sin(a) * PhoneHud.RADIUS
end

for i = 1, #PhoneHud.ANGLES do
	local dx, dy = PhoneHud.skillCenter(i)
	PLACES[`skill{i}`] = {
		edge = "br",
		x = -dx - PhoneHud.SKILL / 2,
		y = -dy - PhoneHud.SKILL / 2,
		w = PhoneHud.SKILL,
		h = PhoneHud.SKILL,
		touch = true,
		round = true,
	}
end

PhoneHud.PLACES = PLACES

-- The top of the stack's next element below the party frames (`others` = party members besides the player).
PhoneHud.PARTY_ROW = 58 + 6
function PhoneHud.stackTop(others: number): number
	return PhoneHud.STACK_TOP + math.max(0, others) * PhoneHud.PARTY_ROW
end

-- Whether the HUD takes the phone layout: a touch screen shorter than MAX_HEIGHT virtual pixels.
function PhoneHud.compact(touch: boolean, virtualHeight: number): boolean
	return touch and virtualHeight < PhoneHud.MAX_HEIGHT
end

-- The place of an element (nil for an unknown name).
function PhoneHud.place(name: string): Place?
	return PLACES[name]
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
	local height = if place.bottom then h - place.bottom - place.y else place.h
	local left = if place.edge == "tr" or place.edge == "br" then w - place.x - place.w else place.x
	local top = if place.edge == "bl" or place.edge == "br" then h - place.y - height else place.y
	return { left = left, top = top, right = left + place.w, bottom = top + height, round = place.round == true }
end

-- The UI area of a device in virtual pixels (the safe area divided by the UI scale).
function PhoneHud.area(device: { w: number, h: number, insets: { number } }): (number, number)
	local i = device.insets
	return (device.w - i[1] - i[3]) / PhoneHud.SCALE, (device.h - i[2] - i[4]) / PhoneHud.SCALE
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

-- Every pair of elements that overlap on a w x h area, as "a / b" strings, and the elements reaching off the area.
function PhoneHud.problems(w: number, h: number): ({ string }, { string })
	local names = {}
	for name in PLACES do
		table.insert(names, name)
	end
	table.sort(names)
	local rects: { [string]: Rect } = {}
	local outside = {}
	for _, name in names do
		local r = PhoneHud.rect(PLACES[name], w, h)
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
	return clashes, outside
end

return PhoneHud
