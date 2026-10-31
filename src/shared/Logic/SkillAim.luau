--!strict
-- What a point skill cast from the hotbar aims at (S28; owner 2026-10-31: Blink on a phone flew into the selected
-- monster). Pure: client/Controllers/SkillController measures the inputs and turns the answer into a point.

local SkillAim = {}

export type Source = "cursor" | "move" | "target" | "feet" | "front"

-- On PC the ground under the cursor wins. On touch a blink (an escape) goes the way the joystick points, or where
-- the character faces when standing, and never into the selected monster. Otherwise: the selected monster, a blink
-- the way you move, a banner at the feet (S74), everything else in front of the character. Disengage is a blink too,
-- but the server ignores its point and always jumps back.
function SkillAim.source(kind: string, touch: boolean, hasCursor: boolean, hasTarget: boolean): Source
	if not touch and hasCursor then
		return "cursor"
	end
	if touch and kind == "blink" then
		return "move"
	end
	if hasTarget then
		return "target"
	end
	if kind == "blink" then
		return "move"
	end
	if kind == "banner" then
		return "feet"
	end
	return "front"
end

return SkillAim
