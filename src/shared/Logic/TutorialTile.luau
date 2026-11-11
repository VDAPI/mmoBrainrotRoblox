--!strict
-- Owner 2026-11-10 ("things covering each other"; UI plan package A): where the tutorial's tile stands next to the HUD
-- element of its step (UI/HudAnchors) and where its arrow points, as numbers, so tests/tutorial.spec can prove that it
-- stays inside the HUD's layer and off its element, off the message zone on PC and a tablet (Logic/HudZones Z8: the
-- toasts and banners stand there) and off the skill arc on a phone (Logic/PhoneHud). It was
-- Controllers/TutorialController's own `place`; the controller now only measures and draws. Pure; virtual pixels of
-- the HUD's layer, measured from its top-left corner.
-- Final UI review 2026-11-10 (a phone's tile stood in the thumbstick zone with its skip buttons under the left thumb,
-- and the fight steps' tiles covered the potions, the sprint and the target's frame): on a phone the tile stands in the
-- left column (TutorialTile.column), GAP left of the M zone, under the portrait and over the thumbstick zone, without an
-- arrow (the outline marks the element); only the tracker's step gets it above the tracker with "▼". It keeps clear of
-- the thumbstick zone, the attack button's arc, the buttons round it and the target's band (TutorialTile.avoid).

local HudZones = require("./HudZones")
local PhoneHud = require("./PhoneHud")
local TopBand = require("./TopBand")

local TutorialTile = {}

-- An element as UI/HudAnchors measures it, and a rectangle by its edges.
export type Anchor = { x: number, y: number, w: number, h: number }
export type Rect = { left: number, top: number, right: number, bottom: number }
-- The tile: its width, its height with a floor (room for the arrow, `h`) and its own height (`tall`).
export type Size = { w: number, h: number, tall: number? }
-- The arrow between the tile and its element: its glyph and its centre.
export type Arrow = { glyph: string, x: number, y: number }

TutorialTile.MARGIN = 16 -- from the layer's edge
TutorialTile.GAP = 10 -- between the element and the arrow
TutorialTile.ARROW = 24 -- the arrow's room between the tile and the element
TutorialTile.WIDTH_PC = 440
TutorialTile.WIDTH_TOUCH = 360
-- a phone in landscape: the left column up to GAP short of the M zone, so the band's messages keep their place there
-- (Logic/TopBand.slots keeps GAP from the tile)
TutorialTile.WIDTH_PHONE = PhoneHud.M_LEFT - TopBand.GAP - TutorialTile.MARGIN
TutorialTile.TOUCH_CLUSTER = 150 -- kept free left of the phone's attack and skill buttons
-- Studio check of phase 4 (the closing tile stood 114 screen px over the action bar): on PC the tile at the default
-- place ends GAP over the cast line (Logic/HudZones.CAST_BAR), which stands right over the action bar
TutorialTile.OVER_BAR = HudZones.CAST_BAR.bottom + HudZones.CAST_BAR.h + TutorialTile.GAP

-- The tile's width on PC, a touch screen and a phone in landscape (`compact`).
function TutorialTile.width(touch: boolean, compact: boolean): number
	if compact then
		return TutorialTile.WIDTH_PHONE
	end
	return if touch then TutorialTile.WIDTH_TOUCH else TutorialTile.WIDTH_PC
end

local function meets(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

-- The places a phone's tile keeps clear of besides the arc: the buttons round the arc and the target's band.
TutorialTile.PHONE_AVOID = table.freeze({
	"potions",
	"sprint",
	"mount",
	"page",
	"targetButton",
	"mail",
	"target",
	"targetActions",
	"targetEffects",
	"castBar",
})

-- What the tile keeps clear of on a w x h layer: the message zone (PC and a tablet: no target, its tallest place) or,
-- on a phone (`compact`), the attack button with the skill arc round it, the thumbstick zone (where nothing persistent
-- belongs; the skip stood there under the left thumb), the buttons round the arc and the target's band (its frame, its
-- "⋯", its effects and its cast line: the first fights need them).
function TutorialTile.avoid(w: number, h: number, touch: boolean, compact: boolean): { Rect }
	if compact then
		local places = PhoneHud.places(w, h)
		local arc = PhoneHud.rect(places.attack, w, h)
		local box: Rect = { left = arc.left, top = arc.top, right = arc.right, bottom = arc.bottom }
		for i = 1, #PhoneHud.ANGLES do
			local r = PhoneHud.rect(places[`skill{i}`], w, h)
			box.left = math.min(box.left, r.left)
			box.top = math.min(box.top, r.top)
			box.right = math.max(box.right, r.right)
			box.bottom = math.max(box.bottom, r.bottom)
		end
		local thumb = PhoneHud.thumb(w, h)
		local out: { Rect } =
			{ box, { left = thumb.left, top = thumb.top, right = thumb.right, bottom = thumb.bottom } }
		for _, name in TutorialTile.PHONE_AVOID do
			local place = places[name]
			if place then
				local r = PhoneHud.rect(place, w, h)
				table.insert(out, { left = r.left, top = r.top, right = r.right, bottom = r.bottom })
			end
		end
		return out
	end
	local zone = HudZones.messageZone(w, h, { touch = touch })
	if zone.bottom <= zone.top or zone.right <= zone.left then
		return {}
	end
	return { zone }
end

-- A phone's tile in the left column (`tall` its own height): from MARGIN, at the M zone's top beside it (under the
-- portrait and its row) and ending over the thumbstick zone; higher when it is taller than that room, never over the
-- layer's top.
function TutorialTile.column(w: number, h: number, tall: number): (number, number)
	local margin = TutorialTile.MARGIN
	local thumb = PhoneHud.thumb(w, h)
	local y = math.min(PhoneHud.M_TOP, thumb.top - tall)
	return margin, math.clamp(y, margin, math.max(margin, h - tall - margin))
end

-- The tile's top-left corner and its arrow (nil: none) for an element at `anchor` (nil: the default place) on a
-- `layer` (w x h): next to the element, the arrow pointing at it, never over it nor over `avoid` (TutorialTile.avoid);
-- `menu` is the menu over the minimap as measured (UI/HudSlots.Menu), which a tile left of one of its buttons keeps
-- clear of (Studio check 2026-10-31: the tile covered the minimap). With no room on any side the tile takes the default
-- place moved off the element, without an arrow (the outline still marks the element). A phone in landscape
-- (`compact`) takes the left column's place (TutorialTile.column) without an arrow, unless that meets the element.
function TutorialTile.place(
	anchor: Anchor?,
	tile: Size,
	layer: { w: number, h: number },
	touch: boolean,
	menu: Rect?,
	avoid: { Rect }?,
	compact: boolean?
): (number, number, Arrow?)
	local w, h = layer.w, layer.h
	local bw, bh = tile.w, tile.h
	local margin, gap, arrowRoom = TutorialTile.MARGIN, TutorialTile.GAP, TutorialTile.ARROW
	local keep: { Rect } = avoid or {}
	-- the tile's own height: an arrowless place needs no room for the arrow
	local tall = math.max(tile.tall or bh, 1)
	local function clampX(x: number): number
		return math.clamp(x, margin, math.max(margin, w - bw - margin))
	end
	local function clampY(y: number): number
		return math.clamp(y, margin, math.max(margin, h - bh - margin))
	end
	local function free(x: number, y: number, height: number?): boolean
		local box = { left = x, top = y, right = x + bw, bottom = y + (height or bh) }
		if anchor then
			local own = { left = anchor.x, top = anchor.y, right = anchor.x + anchor.w, bottom = anchor.y + anchor.h }
			if meets(box, own) then
				return false
			end
		end
		for _, r in keep do
			if meets(box, r) then
				return false
			end
		end
		return true
	end
	-- the default place: PC over the action bar, a tablet in the upper middle clear of the thumbstick and the arc, a
	-- phone the left column
	local function default(): (number, number)
		if compact then
			return TutorialTile.column(w, h, tall)
		end
		return clampX((w - bw) / 2), clampY(if touch then h * 0.16 else h - TutorialTile.OVER_BAR - tall)
	end
	-- the default place, moved off what it must keep clear of and off the element (a short layer's may reach the arc,
	-- the messages or a phone's stack): over what it meets when there is room there, else under it, else beside it
	-- (a phone's arrowless tile by its own height)
	local fh = if compact then tall else bh
	local function fallback(): (number, number)
		local x, y = default()
		local rects = table.clone(keep)
		if anchor then
			table.insert(
				rects,
				{ left = anchor.x, top = anchor.y, right = anchor.x + anchor.w, bottom = anchor.y + anchor.h }
			)
		end
		for _ = 1, #rects do
			if free(x, y, fh) then
				break
			end
			for _, r in rects do
				if meets({ left = x, top = y, right = x + bw, bottom = y + fh }, r) then
					local up = r.top - gap - fh
					local down = r.bottom + gap
					if up >= margin then
						y = up
					elseif down <= h - fh - margin then
						y = down
					else
						local toRight = clampX(r.right + gap)
						local toLeft = clampX(r.left - gap - bw)
						x = if free(toRight, y, fh) or not free(toLeft, y, fh) then toRight else toLeft
					end
				end
			end
		end
		return x, y
	end
	if not anchor then
		local x, y = fallback()
		return x, y, nil
	end
	local rect = anchor :: Anchor
	local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
	-- a phone: the left column without an arrow (the drawer's button, the potions, the attack button and its skills
	-- stand on the right; the thumbstick zone under it) while that place is off the element
	if compact then
		local x, y = TutorialTile.column(w, h, tall)
		if free(x, y, tall) then
			return x, y, nil
		end
	end

	-- left of the element (a button of the menu: left of the whole menu), the arrow "▶" at its middle; slid down past
	-- what it meets while the arrow still reaches the element's side
	local function left(extra: number): (number?, number?, Arrow?)
		local edge = rect.x
		if
			menu
			and rect.x >= menu.left - 1
			and rect.x + rect.w <= menu.right + 1
			and rect.y < menu.bottom
			and rect.y + rect.h > menu.top
		then
			edge = math.min(edge, menu.left)
		end
		local x = edge - gap - arrowRoom - bw - extra
		if x < margin then
			return nil, nil, nil
		end
		local y = clampY(cy - bh / 2)
		for _ = 1, #keep + 1 do
			if free(x, y) then
				break
			end
			local box = { left = x, top = y, right = x + bw, bottom = y + bh }
			for _, r in keep do
				if meets(box, r) then
					y = clampY(r.bottom + gap)
				end
			end
		end
		local ay = math.clamp(cy, y + 16, y + bh - 16)
		if not free(x, y) or ay < rect.y - 1 or ay > rect.y + rect.h + 1 then
			return nil, nil, nil
		end
		return x, y, { glyph = "▶", x = x + bw + arrowRoom / 2 + 2, y = ay }
	end
	-- right of the element, the arrow "◀" at its middle (a phone's stack on the left): slid down past what it meets
	-- while the arrow still reaches the element's side
	local function rightOf(): (number?, number?, Arrow?)
		local x = rect.x + rect.w + gap + arrowRoom
		if x + bw > w - margin then
			return nil, nil, nil
		end
		local y = clampY(cy - bh / 2)
		for _ = 1, #keep + 1 do
			if free(x, y) then
				break
			end
			local box = { left = x, top = y, right = x + bw, bottom = y + bh }
			for _, r in keep do
				if meets(box, r) then
					y = clampY(r.bottom + gap)
				end
			end
		end
		local ay = math.clamp(cy, y + 16, y + bh - 16)
		if not free(x, y) or ay < rect.y - 1 or ay > rect.y + rect.h + 1 then
			return nil, nil, nil
		end
		return x, y, { glyph = "◀", x = x - arrowRoom / 2 - 2, y = ay }
	end
	-- above ("▼") or below ("▲") the element, slid sideways past what it meets while the arrow still reaches it
	local function vertical(above: boolean): (number?, number?, Arrow?)
		local y = if above then clampY(rect.y - gap - arrowRoom - bh) else clampY(rect.y + rect.h + gap + arrowRoom)
		local x = clampX(cx - bw / 2)
		for _ = 1, #keep + 1 do
			if free(x, y) then
				break
			end
			local box = { left = x, top = y, right = x + bw, bottom = y + bh }
			for _, r in keep do
				if meets(box, r) then
					local toRight = clampX(r.right + gap)
					local toLeft = clampX(r.left - gap - bw)
					x = if math.abs(toRight - x) <= math.abs(toLeft - x) then toRight else toLeft
				end
			end
		end
		local ax = math.clamp(cx, x + 16, x + bw - 16)
		if not free(x, y) or ax < rect.x - 1 or ax > rect.x + rect.w + 1 then
			return nil, nil, nil
		end
		if above then
			return x, y, { glyph = "▼", x = ax, y = y + bh + arrowRoom / 2 + 2 }
		end
		return x, y, { glyph = "▲", x = ax, y = y - arrowRoom / 2 - 2 }
	end

	-- the choices in order: a phone's element of the left column (the tracker) gets the tile above it; a tablet's
	-- attack and skill buttons get it left of their arc; an element in the lower part gets it above; one on the right
	-- left of it; anything else below it; then the others in that order
	local tries: { () -> (number?, number?, Arrow?) } = {}
	if compact then
		table.insert(tries, function()
			return vertical(true)
		end)
	end
	if touch and cx > w * 0.6 and cy > h * 0.55 then
		table.insert(tries, function()
			return left(TutorialTile.TOUCH_CLUSTER)
		end)
	end
	local low = cy > h * 0.55
	local right = cx > w * 0.6
	if low then
		table.insert(tries, function()
			return vertical(true)
		end)
	end
	if right then
		table.insert(tries, function()
			return left(0)
		end)
	end
	table.insert(tries, function()
		return vertical(false)
	end)
	if not low then
		table.insert(tries, function()
			return vertical(true)
		end)
	end
	if not right then
		table.insert(tries, rightOf)
		table.insert(tries, function()
			return left(0)
		end)
	end
	for _, try in tries do
		local x, y, a = try()
		if x and y then
			return x, y, a
		end
	end
	-- no side has room: the default place, without an arrow (the outline still marks the element)
	local x, y = fallback()
	return x, y, nil
end

return TutorialTile
