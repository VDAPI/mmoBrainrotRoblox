--!strict
-- S142 (DESIGN-18 §6.1): the lightning school. Pure; numbers in Data/Skills.SHOCK and in the skills' values. The server
-- (Skills/Context, Types/Offense, CombatService) and the balance model (tests/SkillModel, `-- mirrors`) only call these.
--   * Lightning Bolt (values.crit) and Overcharge (hooks overchargeCrit / overchargeDmg): points of crit chance and of
--     crit damage on the hit, both only on lightning spells (critOf: values.crit of other skills, e.g. the Warrior's
--     Advance Order ally buff, never adds to their own hits).
--   * Lightning Lance (SkillDef.sureCrit): its main hit always crits, without spending anyone's guaranteedCrit.
--   * Conductor (hook conduct): every main hit of a single-target lightning spell jumps to the nearest other enemy within
--     SHOCK.conductRadius of the target for conduct % (a secondary hit: ROZWOJ 12.3), never back to the first.
--   * Storm Armor: a monster's melee blow on the bearer is struck back for value % of magic attack, at most once per
--     SHOCK.armorGap s per attacker.
--   * Ball Lightning (SkillDef.finale): the last wave of the circle knocks back and stuns.

local Chain = require("./Chain")
local SkillData = require("../Data/Skills")
local Traits = require("./Traits")

local SHOCK = SkillData.SHOCK

local Shock = {}

Shock.CONDUCT_RADIUS = SHOCK.conductRadius

-- Points of crit chance and of crit damage of one hit: the skill's own `skillCrit` (values.crit) and Overcharge's
-- hooks, only when the spell is lightning (elsewhere values.crit means an effect's stat, not the hit's crit).
function Shock.critOf(element: string?, skillCrit: number?, overCrit: number?, overDmg: number?): (number, number)
	local chance = 0
	local dmg = 0
	if element == "lightning" then
		chance += math.max(0, skillCrit or 0) + math.max(0, overCrit or 0)
		dmg += math.max(0, overDmg or 0)
	end
	return chance, dmg
end

-- Whether a hit is a sure crit: the skill's sureCrit on its main hit (not a splash, a pierce or a zone tick).
function Shock.sureCrit(sure: boolean?, main: boolean): boolean
	return sure == true and main
end

-- Whether a hit jumps (Conductor): a main hit of a single-target lightning spell with the hook above 0.
function Shock.conducts(element: string?, tag: string, main: boolean, pct: number): boolean
	return element == "lightning" and tag == "single" and main and pct > 0
end

-- The jump's target: the index of the point nearest to points[1] (the struck target) within `radius` (flat distance,
-- ties to the lower index), never 1 itself; nil when nothing is near.
function Shock.conductTarget(points: { Chain.Point }, radius: number?): number?
	local path = Chain.path(points, 1, radius or SHOCK.conductRadius, 2)
	return path[2]
end

-- Storm Armor: whether a blow at `now` is struck back on the attacker last struck back at `last` (nil = never).
function Shock.armorReady(last: number?, now: number): boolean
	return Traits.gapReady(last, now, SHOCK.armorGap)
end

-- Ball Lightning: whether wave `wave` of `hits` is the finale (the last one) of a skill with `finale`.
function Shock.finale(hasFinale: boolean, wave: number, hits: number): boolean
	return hasFinale and wave >= math.max(1, hits)
end

return Shock
