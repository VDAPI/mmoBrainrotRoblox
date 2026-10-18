--!strict
-- S145 (DESIGN-18 §6.4): the Cleric's two schools (Data/Skills.FAITH). Pure: Skills/Context, Types/Support,
-- SkillService and the balance model (tests/SkillModel, table Faith) read the same rules.
--   mostWounded  the ally with the lowest HP share below full (ties: the first; nil when nobody is wounded): Light Ray's
--                heal, healWounded, Saving Blow (Skills/Context.mostWounded); solo the list holds only the caster
--   rayHeal      Light Ray's heal: rayHeal % of the HP its main hit took
--   ward         Guiding Light: a shield of `pct` % of the HP a heal skill restored, at most FAITH.wardCap % of the
--                target's max HP (0 without the passive or without a restored point)
--   zealCut      Zeal: seconds an offensive cast of a skill of `castPool` takes off the running cooldowns of the hammer
--                pool's skills (0 for any other pool: Zeal works only with Mace and Flail)
--   zealShortens whether Zeal shortens a running cooldown of a skill of `skillPool` (the hammer pool's own skills)
--   brandShare   the Inquisitor's Wandering Brand: the share (%) of a brand skill's burn that lands on a second enemy
--   interrupts   Rebuke: a hit breaks the channel, aim or beam of an enemy player (Logic/Channel event "interrupt");
--                a monster's cast and a boss's channel never (bosses: only damage breaks it, Logic/BossMechanics)

local SkillData = require("../Data/Skills")

local FAITH = SkillData.FAITH

local Faith = {}

function Faith.mostWounded(fractions: { number }): number?
	local best, bestFraction = nil, 1
	for i, fraction in fractions do
		if fraction < bestFraction then
			best, bestFraction = i, fraction
		end
	end
	return best
end

function Faith.rayHeal(dealt: number, pct: number): number
	if dealt <= 0 or pct <= 0 then
		return 0
	end
	return dealt * pct / 100
end

function Faith.ward(healed: number, pct: number, maxHp: number): number
	if healed <= 0 or pct <= 0 then
		return 0
	end
	return math.min(healed * pct / 100, math.max(0, maxHp) * FAITH.wardCap / 100)
end

function Faith.zealCut(castPool: string?, hook: number): number
	if castPool ~= FAITH.hammer or hook <= 0 then
		return 0
	end
	return hook
end

function Faith.zealShortens(skillPool: string?): boolean
	return skillPool == FAITH.hammer
end

function Faith.brandShare(skillId: string, hook: number): number
	if not FAITH.brandSkills[skillId] or hook <= 0 then
		return 0
	end
	return hook
end

function Faith.interrupts(isPlayer: boolean, bossLike: boolean): boolean
	return isPlayer and not bossLike
end

return Faith
