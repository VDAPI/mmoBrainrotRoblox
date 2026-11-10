--!strict
-- What a skill cast from the bar aims at (S28; owner 2026-10-31: Blink is an escape and never lands in the monster;
-- owner 2026-11-10: a tapped skill aims at the enemy we fight by itself, holding the key picks a direction by hand).
-- Review 2026-11-10: a tapped Blink jumps the way the player steers by hand, else straight away from the enemy, never
-- toward it; a selected ally stays selected (a tapped damage skill goes to the nearest enemy without taking its place).
-- Pure: client/Controllers/SkillController measures the inputs and turns the answer into a point.

local Config = require("../Config")

local SkillAim = {}

-- "manual"   where the player aimed by hand: the preview of a held key or a dragged button, quick cast's cursor
-- "target"   the enemy we fight (the selected one)
-- "nearest"  nothing living selected: the nearest enemy within SkillAim.reach, which becomes the target
-- "nearby"   a living ally selected: the nearest enemy within reach for this cast only (the ally stays selected)
-- "ally"     the selected ally (a healing field goes under them; a skill on an enemy with nobody else in reach, which
--            the server refuses, as before)
-- "escape"   Blink: the way SkillAim.escape picks (own steering, else away from the enemy, else ahead)
-- "feet"     at the caster's feet (a banner without a target, a healing field without an ally)
-- "front"    in front of the character (nobody to aim at)
-- "none"     the skill aims nowhere (a buff, a circle around you, a trap at your feet); a skill on an enemy: nobody
export type Source = "manual" | "target" | "nearest" | "nearby" | "ally" | "escape" | "feet" | "front" | "none"

-- What a key press does at once on PC: "cast" now, "cursor" now at the cursor, "wait" for the release (a tap aims
-- by itself, a hold past Config.Skills.holdToAim shows the preview at the cursor and casts there).
export type Press = "cast" | "cursor" | "wait"

export type Input = {
	kind: string, -- SkillDef.type
	mode: string?, -- SkillDef.target
	manual: boolean, -- aimed by hand (a held key, a dragged button, quick cast)
	target: boolean, -- a living enemy is selected
	nearest: boolean, -- no enemy selected, but one stands within SkillAim.reach
	ally: boolean?, -- a living model that is not an enemy is selected (an allied player)
}

-- A direction or an offset on the ground (studs).
export type Flat = { x: number, z: number }

-- What a tapped Blink knows (offsets from the caster, on the ground).
export type Escape = {
	steer: Flat?, -- the player's own steering in the world (SkillAim.steering); nil: none
	facing: Flat, -- where the character faces
	length: number, -- how far this Blink jumps (the skill's length with its breakpoints: 15, 20 with 5B)
	enemy: Flat?, -- the selected living enemy
	nearest: Flat?, -- the living enemy whose body's edge is nearest (counts within SkillAim.escapeReach)
	radius: number?, -- the body radius of `nearest` (its edge is that much nearer than its centre)
}

-- The slack the server allows around an area (Skills/Context: enemiesInCircle / Cone / Line).
local SLACK = 1.5
-- Move input below this is a stick at rest (TargetController uses the same for "the player moves").
local STEER_MIN = 0.1

local function unit(v: Flat): Flat?
	local length = math.sqrt(v.x * v.x + v.z * v.z)
	if length < 1e-3 then
		return nil
	end
	return { x = v.x / length, z = v.z / length }
end

-- Skills that aim at a point or in a direction: everything cast on a point (circles, snares, a healing field, a
-- banner, Blink) and cones and lines. Disengage is a blink without a point: it always jumps back.
function SkillAim.aims(kind: string, mode: string?): boolean
	return mode == "point" or kind == "cone" or kind == "line"
end

-- Holding the key (dragging the button) shows a preview: everything that aims, and the area of a circle around the
-- caster or a trap at the feet.
function SkillAim.previews(kind: string, mode: string?): boolean
	return SkillAim.aims(kind, mode) or kind == "circleSelf" or kind == "trap"
end

-- Whether a tap with no enemy selected looks for the nearest one: not an escape (Blink), not a healing field or a
-- banner (they serve allies).
function SkillAim.seeks(kind: string, mode: string?): boolean
	return SkillAim.aims(kind, mode) and kind ~= "blink" and kind ~= "healZone" and kind ~= "banner"
end

-- Whether the character turns to where the skill flies when it is cast: a skill on an enemy, a cone, a line, a circle
-- on a point. Not Blink: the server turns the character when it lands.
function SkillAim.turns(kind: string, mode: string?): boolean
	return mode == "enemy" or (SkillAim.aims(kind, mode) and kind ~= "blink")
end

-- A key press on PC. A touch device's keyboard and skills that do not aim cast at once; the "Cast at cursor"
-- setting (quickCast, the old way) casts at once at the cursor; everything else waits for the release.
function SkillAim.press(kind: string, mode: string?, touch: boolean, quickCast: boolean): Press
	if touch or not SkillAim.previews(kind, mode) then
		return "cast"
	end
	if quickCast then
		return if SkillAim.aims(kind, mode) then "cursor" else "cast"
	end
	return "wait"
end

-- A key that stayed down `seconds` was held (aimed by hand), not tapped.
function SkillAim.held(seconds: number, threshold: number): boolean
	return seconds >= threshold
end

-- What a cast aims at: a hand-picked point first, then the rules of the tap. The nearest enemy becomes the target only
-- when nothing living is selected: a selected ally stays selected and nothing engages ("nearby").
function SkillAim.source(input: Input): Source
	if input.manual then
		return "manual"
	end
	local kind = input.kind
	if not SkillAim.aims(kind, input.mode) then
		return "none"
	end
	if kind == "blink" then
		return "escape" -- never into the target
	end
	if kind == "healZone" then
		return if input.ally then "ally" else "feet"
	end
	if input.target then
		return "target"
	end
	if kind == "banner" then
		return "feet" -- S74 (ROZWOJ 10.5)
	end
	if input.nearest then
		return if input.ally then "nearby" else "nearest"
	end
	return "front"
end

-- Who a skill on an enemy goes to (it casts at once, never aimed by hand): the selected living enemy; with nothing
-- living selected the nearest enemy within its range, which becomes the target, or nobody (cast.error.noTarget); with a
-- living ally selected the nearest enemy for this cast only, else the ally as before (the server refuses it).
function SkillAim.onEnemy(input: Input): Source
	if input.target then
		return "target"
	end
	if input.nearest then
		return if input.ally then "nearby" else "nearest"
	end
	return if input.ally then "ally" else "none"
end

-- The world direction of the player's own steering: TargetController.MoveInput (x right, z back, relative to the
-- camera, as the default controls walk the character) turned by the camera's forward on the ground. nil while the
-- player steers nowhere. Never Humanoid.MoveDirection: it follows a MoveTo walk too (the approach to the target,
-- Auto Hunt), which is not the player's choice.
function SkillAim.steering(input: Flat, forward: Flat): Flat?
	local f = unit(forward)
	if not f or math.sqrt(input.x * input.x + input.z * input.z) <= STEER_MIN then
		return nil
	end
	-- the camera's right on the ground is (-f.z, f.x); input.z is negative forward
	return unit({ x = -f.z * input.x - f.x * input.z, z = f.x * input.x - f.z * input.z })
end

-- How far from the caster an enemy's body (its edge, not its centre) sends a tapped Blink of `length` studs straight
-- away from it (review 2026-11-10): the whole jump plus Config.Skills.escapeMargin. A fixed 15 let a Blink with the
-- 5B breakpoint (20 studs) land in a monster 18 studs ahead, and a big boss's body reaches far nearer than its centre.
-- Every enemy farther than this stays at least the margin clear of where a jump straight ahead lands.
function SkillAim.escapeReach(length: number): number
	return length + Config.Skills.escapeMargin
end

-- The way a tapped Blink jumps (a unit direction): the way the player steers by hand (their choice); with no own
-- steering straight away from the selected enemy, else from the nearest one whose body is within
-- SkillAim.escapeReach; else straight ahead. Never toward an enemy by itself: standing in a fight the character faces
-- its target (TargetController.faceStep), and straight ahead never lands in a body.
function SkillAim.escape(e: Escape): Flat
	local steer = if e.steer then unit(e.steer) else nil
	if steer then
		return steer
	end
	local facing = unit(e.facing) or { x = 0, z = -1 }
	local nearest = e.nearest
	local edge = if nearest then math.sqrt(nearest.x * nearest.x + nearest.z * nearest.z) - (e.radius or 0) else nil
	local from = e.enemy or (if edge and edge <= SkillAim.escapeReach(e.length) then nearest else nil)
	if from then
		-- an enemy standing in us has no "away": back, away from where we face
		return unit({ x = -from.x, z = -from.z }) or { x = -facing.x, z = -facing.z }
	end
	return facing
end

-- How far a tap looks for the nearest enemy: the farthest an enemy may stand and still be hit (a circle at full range,
-- the cone's radius, the line's length), with the server's slack.
function SkillAim.reach(kind: string, range: number?, radius: number?, length: number?): number
	if kind == "cone" then
		return (radius or 10) + SLACK
	elseif kind == "line" then
		return (length or 20) + SLACK
	end
	return (range or 30) + (radius or 0) + SLACK
end

return SkillAim
