--!strict
-- What a skill cast from the bar aims at (S28; owner 2026-10-31: Blink is an escape and never lands in the monster;
-- owner 2026-11-10: a tapped skill aims at the enemy we fight by itself, holding the key picks a direction by hand).
-- Pure: client/Controllers/SkillController measures the inputs and turns the answer into a point.

local SkillAim = {}

-- "manual"   where the player aimed by hand: the preview of a held key or a dragged button, quick cast's cursor
-- "target"   the enemy we fight (the selected one)
-- "nearest"  no enemy selected: the nearest one within SkillAim.reach, which becomes the target
-- "ally"     the selected ally (a healing field goes under them)
-- "move"     the way the character walks, or faces when standing (Blink)
-- "feet"     at the caster's feet (a banner without a target, a healing field without an ally)
-- "front"    in front of the character (nobody to aim at)
-- "none"     the skill aims nowhere (a buff, a circle around you, a trap at your feet, a skill on an enemy)
export type Source = "manual" | "target" | "nearest" | "ally" | "move" | "feet" | "front" | "none"

-- What a key press does at once on PC: "cast" now, "cursor" now at the cursor, "wait" for the release (a tap aims
-- by itself, a hold past Config.Skills.holdToAim shows the preview at the cursor and casts there).
export type Press = "cast" | "cursor" | "wait"

export type Input = {
	kind: string, -- SkillDef.type
	mode: string?, -- SkillDef.target
	manual: boolean, -- aimed by hand (a held key, a dragged button, quick cast)
	target: boolean, -- a living enemy is selected
	nearest: boolean, -- no enemy selected, but one stands within SkillAim.reach
	ally: boolean?, -- a living allied player is selected
}

-- The slack the server allows around an area (Skills/Context: enemiesInCircle / Cone / Line).
local SLACK = 1.5

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

-- What a cast aims at: a hand-picked point first, then the rules of the tap.
function SkillAim.source(input: Input): Source
	if input.manual then
		return "manual"
	end
	local kind = input.kind
	if not SkillAim.aims(kind, input.mode) then
		return "none"
	end
	if kind == "blink" then
		return "move" -- an escape: never into the target
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
		return "nearest"
	end
	return "front"
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
