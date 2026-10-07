--!strict
-- Monster statistics from level, kind multipliers and variant (DESIGN §15.1). Pure.

local Combat = require("../Data/Combat")
local Damage = require("./Damage")
local Exp = require("./Exp")

export type Variant = "normal" | "elite" | "elite2" | "boss"

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

-- Damage multiplier of a member of a group of `size` (S32, Combat.groupDamageMul; 1 alone or unknown).
function MonsterStats.groupDamageMul(size: number?): number
	local list = Combat.groupDamageMul
	if not size or size <= 1 then
		return 1
	end
	return list[math.min(math.floor(size), #list)] or 1
end

-- Hunting ground multipliers (S33, Data/AreaProfiles): HP and attack of the area's monsters.
export type Mods = { hpMul: number?, atkMul: number? }

-- `level` is the spawner's rolled level; the variant adds its own levels on top. `groupSize` (S32) lowers the
-- damage of every member of a bigger group; `mods` (S33) are the area profile's HP and attack multipliers.
function MonsterStats.compute(
	kind: Kind,
	level: number,
	variant: Variant?,
	groupSize: number?,
	mods: Mods?
): MonsterStats
	local v: Variant = variant or "normal"
	local variantMods = Combat.variants[v]
	assert(variantMods, `MonsterStats: unknown variant {v}`)
	local hpMul = if mods and mods.hpMul then mods.hpMul else 1
	local atkMul = if mods and mods.atkMul then mods.atkMul else 1
	local finalLevel = math.max(1, math.floor(level + variantMods.levelAdd))
	return {
		level = finalLevel,
		maxHp = math.floor(MonsterStats.baseHp(finalLevel) * kind.hpMul * variantMods.hpMul * hpMul + 0.5),
		attack = MonsterStats.baseAttack(finalLevel)
			* kind.atkMul
			* variantMods.dmgMul
			* atkMul
			* MonsterStats.groupDamageMul(groupSize),
		armor = Combat.monsterArmorPerLevel * finalLevel * kind.defMul,
		mres = Combat.monsterMresPerLevel * finalLevel * kind.defMul,
		attackInterval = Combat.monsterAttackInterval / math.max(0.1, kind.speed),
		range = kind.range or (if kind.attack == "ranged" then 30 else Combat.meleeRange),
		aggroRange = variantMods.aggroRange,
		scale = variantMods.scale,
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

-- EXP and gold factor of a kind (S32): tougher kinds pay more, weak ones less. Bosses use 1.
function MonsterStats.kindReward(kind: { hpMul: number, atkMul: number, speed: number }?): number
	if not kind then
		return 1
	end
	local hp = math.max(0.05, kind.hpMul or 1) ^ Combat.kindRewardHpExponent
	local danger = math.max(0.05, (kind.atkMul or 1) * (kind.speed or 1)) ^ Combat.kindRewardAtkExponent
	return hp * danger
end

-- Gold multiplier for a player of `playerLevel` killing a monster of `monsterLevel` (S32): a share of the EXP
-- penalty (Exp.levelDiffMultiplier), never a bonus.
function MonsterStats.goldLevelMultiplier(playerLevel: number, monsterLevel: number): number
	local expMul = math.min(1, Exp.levelDiffMultiplier(playerLevel, monsterLevel))
	return 1 - (1 - expMul) * Combat.goldPenaltyShare
end

-- Gold dropped by a monster (before the kind factor, the level penalty and the killer's gold bonus).
function MonsterStats.gold(level: number, variant: string, roll: number): number
	local multiplier = (Combat.goldVariantMultiplier :: any)[variant] or 1
	local factor = Combat.goldRandomMin + (Combat.goldRandomMax - Combat.goldRandomMin) * math.clamp(roll, 0, 1)
	return math.max(1, math.floor(level * Combat.goldPerLevel * factor * multiplier + 0.5))
end

-- Whether a monster attacks a player first (weak monsters leave much stronger players alone).
function MonsterStats.isAggressiveTowards(monsterLevel: number, playerLevel: number): boolean
	return playerLevel - monsterLevel < Combat.passiveLevelGap
end

return MonsterStats
