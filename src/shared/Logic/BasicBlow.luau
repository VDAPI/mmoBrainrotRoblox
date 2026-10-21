--!strict
-- A monster's regular blow (S159; studio review 2026-10-21): how long it is drawn back before it lands, what it shoots
-- and which clip of a real model the clients play for the draw. One rule for the server (Entities/Monster: the "aw"
-- event and the blow after it), the clients (CombatFxController "aw", AnimationController.MonsterAttack) and AnimLab
-- (`mob <kind> attack1`, Logic/MotionKeys.basicBlow). Pure (Lune).
--   shot(attack, damageKind)   "melee", or a ranged blow's "arrow" / "bolt" (a magic one)
--   wind(attack, variant)      seconds of the draw: Data/Combat.basicWind (melee / ranged) x basicWindVariant
--   throwWind(variant)         the draw of an Elite II's throw at a fleeing target (basicWind.throw x the variant's)
--   slot(shot)                 the clip slot of a real model: a bolt is a spell ("cast"), every other draw "attack2"
--                              (AnimationController: a windup up to 1 s that does not strike at once)

local Combat = require("../Data/Combat")

local BasicBlow = {}

export type Shot = "melee" | "arrow" | "bolt"

local function factor(variant: string?): number
	return (Combat.basicWindVariant :: any)[variant or "normal"] or 1
end

function BasicBlow.shot(attack: string?, damageKind: string?): Shot
	if attack ~= "ranged" then
		return "melee"
	end
	return if damageKind == "magic" then "bolt" else "arrow"
end

function BasicBlow.wind(attack: string?, variant: string?): number
	local base = if attack == "ranged" then Combat.basicWind.ranged else Combat.basicWind.melee
	return base * factor(variant)
end

function BasicBlow.throwWind(variant: string?): number
	return Combat.basicWind.throw * factor(variant)
end

function BasicBlow.slot(shot: string): string
	return if shot == "bolt" then "cast" else "attack2"
end

return BasicBlow
