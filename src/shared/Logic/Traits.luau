--!strict
-- On-hit effects of item traits and lines (S63, docs/STATY.md 5, 8, 13). Pure helpers CombatService and
-- StatusEffectService use; the numbers live in Data/Combat, Data/BuffCategories and Data/ItemTraits. S64 adds the
-- defensive and conditional traits (block, counter, execute, controlled targets). S65 adds the
-- rhythm traits and the player's trait state here.

local BuffCategories = require("../Data/BuffCategories")
local Combat = require("../Data/Combat")

local Traits = {}

-- How a hit was dealt (CombatService.DealOptions passes as is).
export type Hit = { basic: boolean?, area: boolean?, noProc: boolean? }

-- Skill types that hit every target in an area (Data/Skills/Types); one-target types: target, projectile, charge.
Traits.AREA_TYPES = table.freeze({
	cone = true,
	circleSelf = true,
	circleTarget = true,
	line = true,
	chain = true,
	trap = true,
} :: { [string]: boolean })

function Traits.isAreaSkill(skillType: string?): boolean
	return skillType ~= nil and Traits.AREA_TYPES[skillType] == true
end

-- Share of an effect's chance this hit gets: 0 for secondary hits (noProc), 1 for basic attacks and one-target
-- skills, Combat.areaProcShare per target of an area skill.
function Traits.procShare(hit: Hit?): number
	if hit == nil then
		return 1
	end
	if hit.noProc then
		return 0
	end
	if hit.area and not hit.basic then
		return Combat.areaProcShare
	end
	return 1
end

-- % chance of one effect: trait chance + line chance, capped at Combat.onHitChanceCap, times the hit's share.
function Traits.chance(traitChance: number, lineChance: number, share: number): number
	return math.min(math.max(0, traitChance) + math.max(0, lineChance), Combat.onHitChanceCap) * share
end

-- Ticks an effect of `duration` s really deals: StatusEffectService removes the effect before its last tick, so
-- dividing by these makes the ticks add up to exactly pct % of the hit (STATY 5). 4 s -> 3, 5 s -> 4.
function Traits.ticks(duration: number): number
	return math.max(1, math.ceil(duration) - 1)
end

-- One tick of a damage over time worth `pct` % of `hit` over `duration` s, raised by `bonus` % (dotPower).
function Traits.dotTick(hit: number, pct: number, duration: number, bonus: number): number
	return math.max(1, hit * pct / 100 / Traits.ticks(duration) * (1 + bonus / 100))
end

-- A tick of a player on a player (STATY 8); StatusEffectService.Apply is the only caller, so it applies once.
function Traits.pvpTick(tick: number): number
	return tick * Combat.pvp.dot
end

-- A trait value against a player (TraitDef.pvp; nil = 1).
function Traits.pvpValue(value: number, multiplier: number?): number
	return value * (if multiplier == nil then 1 else multiplier)
end

-- S64 (STATY 5, 8): block chance in % for one regular hit; pvp halves it after the cap.
function Traits.blockChance(total: number, pvp: boolean): number
	return math.clamp(total, 0, Combat.blockCap) * (if pvp then Combat.pvp.block else 1)
end

-- S64: counter chance in % after a regular attack; the same with riposteCap and pvp.counter.
function Traits.counterChance(total: number, pvp: boolean): number
	return math.clamp(total, 0, Combat.riposteCap) * (if pvp then Combat.pvp.counter else 1)
end

-- S64: bonus % below Combat.lowHpFraction: executioner (nodes, legends) + Beheading; traitPvp = the trait's
-- multiplier against players, nil against monsters. Only the trait part is halved in PvP.
function Traits.executeBonus(executioner: number, trait: number, traitPvp: number?): number
	local bonus = math.max(0, executioner) + Traits.pvpValue(math.max(0, trait), traitPvp)
	return math.min(bonus, Combat.executionerCap)
end

-- S64: Easy Prey: `value` when the target is slowed, rooted, frozen or stunned (StatusEffectService.SlowFactor < 1).
function Traits.controlledBonus(value: number, slowFactor: number, traitPvp: number?): number
	if slowFactor >= 1 then
		return 0
	end
	return Traits.pvpValue(math.max(0, value), traitPvp)
end

-- Armour break from items at `stacks` stacks of `unit` %.
function Traits.armorBreakCap(unit: number, stacks: number): number
	return math.min(unit * stacks, BuffCategories.caps.enemyArmorItem)
end

-- Attack interval under `slowPct` % attack slow (capped by BuffCategories.caps.enemyAttackSlow).
function Traits.slowedInterval(interval: number, slowPct: number): number
	local slow = math.clamp(slowPct, 0, BuffCategories.caps.enemyAttackSlow)
	return interval / (1 - slow / 100)
end

-- True when `gap` s passed since `last` (nil = never).
function Traits.gapReady(last: number?, now: number, gap: number): boolean
	return last == nil or now - last >= gap
end

-- Mana / energy refunded by the resourceOnHit line: min(linePct, cap) % of the maximum, 0 within the gap.
function Traits.resourceOnHit(linePct: number, maxResource: number, last: number?, now: number): number
	if linePct <= 0 or not Traits.gapReady(last, now, Combat.resourceOnHitGap) then
		return 0
	end
	return math.max(0, maxResource) * math.min(linePct, Combat.resourceOnHitCap) / 100
end

return Traits
