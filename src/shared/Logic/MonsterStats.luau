--!strict
-- Monster statistics from level, kind multipliers and variant (DESIGN §15.1). Pure.

local Combat = require("../Data/Combat")
local Damage = require("./Damage")

export type Variant = "normal" | "elite" | "elite2"

-- Kind multipliers (subset of a Data/Monsters entry).
export type Kind = {
	hpMul: number,
	atkMul: number,
	defMul: number,
	speed: number, -- attack speed multiplier (2 = twice as fast)
	attack: "melee" | "ranged",
	damageKind: ("phys" | "magic")?,
	range: number?,
}

export type MonsterStats = {
	level: number,
	maxHp: number,
	attack: number,
	armor: number,
	mres: number,
	attackInterval: number,
	range: number,
	aggroRange: number,
	scale: number,
	variant: Variant,
	damageKind: "phys" | "magic",
}

local MonsterStats = {}

function MonsterStats.baseHp(level: number): number
	return Combat.monsterHpBase + Combat.monsterHpFactor * level ^ Combat.monsterHpExponent
end

function MonsterStats.baseAttack(level: number): number
	return Combat.monsterAtkBase + Combat.monsterAtkFactor * level ^ Combat.monsterAtkExponent
end

-- `level` is the spawner's rolled level; the variant adds its own levels on top.
function MonsterStats.compute(kind: Kind, level: number, variant: Variant?): MonsterStats
	local v: Variant = variant or "normal"
	local mods = Combat.variants[v]
	assert(mods, `MonsterStats: unknown variant {v}`)
	local finalLevel = math.max(1, math.floor(level + mods.levelAdd))
	return {
		level = finalLevel,
		maxHp = math.floor(MonsterStats.baseHp(finalLevel) * kind.hpMul * mods.hpMul + 0.5),
		attack = MonsterStats.baseAttack(finalLevel) * kind.atkMul * mods.dmgMul,
		armor = Combat.monsterArmorPerLevel * finalLevel * kind.defMul,
		mres = Combat.monsterMresPerLevel * finalLevel * kind.defMul,
		attackInterval = Combat.monsterAttackInterval / math.max(0.1, kind.speed),
		range = kind.range or (if kind.attack == "ranged" then 30 else Combat.meleeRange),
		aggroRange = mods.aggroRange,
		scale = mods.scale,
		variant = v,
		damageKind = (kind.damageKind or "phys") :: "phys" | "magic",
	}
end

-- Damage.Attacker / Damage.Defender views of a monster.
function MonsterStats.asAttacker(stats: MonsterStats): Damage.Attacker
	return {
		level = stats.level,
		physAtk = stats.attack,
		magAtk = stats.attack,
		critChance = Combat.monsterCritChance,
		critDmg = Combat.monsterCritDmg,
		accuracy = 0,
		armorPen = 0,
		lifesteal = 0,
	}
end

function MonsterStats.asDefender(stats: MonsterStats): Damage.Defender
	return { armor = stats.armor, mres = stats.mres, dodge = 0, res = {} }
end

-- Gold dropped by a monster (before the killer's gold bonus).
function MonsterStats.gold(level: number, variant: string, roll: number): number
	local multiplier = (Combat.goldVariantMultiplier :: any)[variant] or 1
	local base = Combat.goldBase + Combat.goldFactor * level ^ Combat.goldExponent
	local factor = Combat.goldRandomMin + (Combat.goldRandomMax - Combat.goldRandomMin) * math.clamp(roll, 0, 1)
	return math.max(1, math.floor(base * multiplier * factor + 0.5))
end

-- Whether a monster attacks a player first (weak monsters leave much stronger players alone).
function MonsterStats.isAggressiveTowards(monsterLevel: number, playerLevel: number): boolean
	return playerLevel - monsterLevel < Combat.passiveLevelGap
end

return MonsterStats
