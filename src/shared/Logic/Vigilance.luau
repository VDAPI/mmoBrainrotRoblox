--!strict
-- Scout's red-zone reaction (S77, ROZWOJ 11.5 / 7.3): Vigilance and Warning fire when a monster within range starts a
-- telegraphed attack, each at most once per cooldown per scout. The rules are Data/Paths HOOK_RULES.vigilance;
-- CombatService (telegraph) applies the effects.

local Paths = require("../Data/Paths")

local Vigilance = {}

export type Zone = {
	windup: number, -- seconds of the red zone's windup (0 = an attack without a red zone)
	monsterDistance: number, -- flat studs from the scout to the monster
}

-- `last` = os.clock() of this scout's last trigger of this kind (nil = never).
function Vigilance.ready(last: number?, now: number, zone: Zone): boolean
	local rules = Paths.HOOK_RULES.vigilance
	if zone.windup <= 0 or zone.monsterDistance > rules.monsterRange then
		return false
	end
	return last == nil or now - last >= rules.cooldown
end

-- Seconds of the bonus: the windup + HOOK_RULES.vigilance.extra.
function Vigilance.duration(windup: number): number
	return windup + Paths.HOOK_RULES.vigilance.extra
end

return Vigilance
