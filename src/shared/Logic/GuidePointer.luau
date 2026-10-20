--!strict
-- The guide pointer's maths (W28; pure). One shared set of rules for every "go there" arrow: the golden world guide of
-- the tutorial (Controllers/GuidePointerController: a floating arrow over the player, chevrons on the ground, a
-- bobbing diamond with the distance over the target and an arrow at the screen's edge while the target is off
-- screen) and the small arrow in the quest tracker's header (UI/Screens/Hud/QuestTracker).
-- Screen angles are degrees for GuiObject.Rotation of an "up" glyph: 0 = up, clockwise positive.

local GuidePointer = {}

-- Studs from the target that count as reached (the guide hides): an NPC stands behind the "Talk" prompt range, a
-- portal is entered on its pad, a monster is in sight.
GuidePointer.REACH = table.freeze({ npc = 9, place = 8, monster = 14 })

-- Normalises an angle to (-180, 180].
function GuidePointer.wrap(degrees: number): number
	local a = degrees % 360
	if a > 180 then
		a -= 360
	end
	return a
end

-- The rotation of an "up" arrow that points at a ground direction (dx, dz) for a camera looking along (fx, fz);
-- nil when the camera looks straight down (no forward on the ground) or the direction is zero.
function GuidePointer.bearing(dx: number, dz: number, fx: number, fz: number): number?
	if fx * fx + fz * fz < 1e-6 or dx * dx + dz * dz < 1e-6 then
		return nil
	end
	return GuidePointer.wrap(math.deg(math.atan2(dx, -dz) - math.atan2(fx, -fz)))
end

-- The yaw (radians, for CFrame.Angles(0, yaw, 0)) that turns -Z (a part's front) towards the ground direction (dx, dz).
function GuidePointer.yaw(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

-- Ground distance (y ignored).
function GuidePointer.flat(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	return math.sqrt(dx * dx + dz * dz)
end

-- Whether a target `distance` studs away counts as reached within `radius`.
function GuidePointer.reached(distance: number, radius: number): boolean
	return distance <= radius
end

export type Edge = { onScreen: boolean, x: number, y: number, rotation: number }

-- Where the screen arrow stands for a target projected at (sx, sy) with `depth` (Camera:WorldToViewportPoint: depth
-- below 0 = behind the camera, where the projection is mirrored) on a w × h viewport. On screen (inside `margin`):
-- the point itself. Off screen: on the margin rectangle along the line from the centre, rotated towards the target
-- (behind the camera it points to the bottom half, the way to turn).
function GuidePointer.edge(sx: number, sy: number, depth: number, w: number, h: number, margin: number): Edge
	if depth > 0 and sx >= margin and sx <= w - margin and sy >= margin and sy <= h - margin then
		return { onScreen = true, x = sx, y = sy, rotation = 0 }
	end
	local cx, cy = w / 2, h / 2
	local dx, dy = sx - cx, sy - cy
	if depth <= 0 then
		dx, dy = -dx, -dy
		if dy < 0 then
			dy = math.max(-dy, 1) -- behind: never at the top edge (that reads as "ahead")
		end
	end
	if math.abs(dx) < 1e-6 and math.abs(dy) < 1e-6 then
		dy = 1
	end
	local hw, hh = math.max(cx - margin, 1), math.max(cy - margin, 1)
	local scale = math.huge
	if math.abs(dx) > 1e-6 then
		scale = math.min(scale, hw / math.abs(dx))
	end
	if math.abs(dy) > 1e-6 then
		scale = math.min(scale, hh / math.abs(dy))
	end
	return {
		onScreen = false,
		x = cx + dx * scale,
		y = cy + dy * scale,
		rotation = GuidePointer.wrap(math.deg(math.atan2(dx, -dy))),
	}
end

-- Distances along the line to the target where the ground chevrons stand: `count` of them every `spacing` studs from
-- `first`, shifted by `phase` (0..1, scrolls them towards the target), only those at least `spacing` / 2 short of
-- the target.
function GuidePointer.chevrons(
	distance: number,
	first: number,
	spacing: number,
	count: number,
	phase: number
): { number }
	local out: { number } = {}
	local shift = (phase % 1) * spacing
	for i = 1, count do
		local at = first + (i - 1) * spacing + shift
		if at <= distance - spacing / 2 then
			table.insert(out, at)
		end
	end
	return out
end

-- How visible a chevron at `index` of `count` is (0 = solid): the scrolling one fades in at the start and out at the
-- end so the trail flows instead of jumping.
function GuidePointer.fade(index: number, count: number, phase: number): number
	local p = phase % 1
	if index == 1 then
		return 1 - p * 0.85
	elseif index == count then
		return 0.15 + p * 0.85
	end
	return 0.15
end

-- The bob of the floating parts: `amplitude` × a sine of `period` seconds.
function GuidePointer.bob(t: number, amplitude: number, period: number): number
	return amplitude * math.sin(t * 2 * math.pi / period)
end

-- Whole studs shown under the target's diamond.
function GuidePointer.meters(distance: number): number
	return math.max(0, math.floor(distance + 0.5))
end

return GuidePointer
