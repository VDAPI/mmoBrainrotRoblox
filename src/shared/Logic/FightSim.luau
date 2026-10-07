--!strict
-- Expected-value fight model (S32, DESIGN §15.1). Pure: no randomness, numbers from Logic/Damage and
-- Logic/MonsterStats. Used by tests/Balance.luau (balance.spec, tools/balance_report) and the admin commands
-- /simfight and /balance (with the player's real stats).
--
-- A fight: the player kills the members one by one; every living member attacks (one swing right away, then
-- every interval); Elite II abilities land `specialHit` of the time; in-combat regeneration heals.

local AreaSpawns = require("./AreaSpawns")
local Combat = require("../Data/Combat")
local Damage = require("./Damage")
local MonsterAbilities = require("../Data/MonsterAbilities")
local MonsterStats = require("./MonsterStats")

local FightSim = {}

-- Share of telegraphed special attacks that still hit (most are dodged by moving out).
FightSim.SPECIAL_HIT = 0.5
-- Damage share of 1-2 skills used on cooldown on top of basic attacks (single target).
FightSim.SKILL_DPS = 1.2

export type Player = {
	level: number,
	values: { [string]: number }, -- StatCalc values
	hooks: { [string]: number }, -- legendary effects (doubleAttack, ...)
	magic: boolean, -- basic attack kind of the class
}

export type Fight = { seconds: number, hpLost: number, playerHp: number }

-- Expected damage per second of the player's basic attacks (x `skill`) against a monster.
function FightSim.dps(p: Player, m: MonsterStats.MonsterStats, skill: number?): number
	local v = p.values
	local attack = if p.magic then v.magAtk or 0 else v.physAtk or 0
	local defense = if p.magic then m.mres else m.armor
	local critFactor = 1 + math.min(v.critChance or 0, 100) / 100 * ((v.critDmg or 150) / 100 - 1)
	local double = 1 + (p.hooks.doubleAttack or 0) / 100
	local perHit = attack * (1 - Damage.reduction(defense, p.level)) * critFactor
	return perHit * math.max(0.1, v.atkSpeed or 1) * double * (skill or 1)
end

-- Expected damage of one monster attack (`mul` x attack) on the player, after armour / magic resistance.
function FightSim.hit(m: any, p: Player, mul: number?, kind: string?, canDodge: boolean?): number
	local v = p.values
	local magic = (kind or m.damageKind) == "magic"
	local defense = if magic then v.mres or 0 else v.armor or 0
	local crit = 1 + Combat.monsterCritChance / 100 * (Combat.monsterCritDmg / 100 - 1)
	local dodge = if canDodge == false then 0 else math.min(v.dodge or 0, Combat.dodgeCap) / 100
	return m.attack * (mul or 1) * (1 - Damage.reduction(defense, m.level)) * crit * (1 - dodge)
end

-- One player against `members` (MonsterStats, optionally with `ability`), killed in order.
function FightSim.groupFight(p: Player, members: { any }, skill: number?): Fight
	local lost = 0
	for _, m in members do
		lost += FightSim.hit(m, p)
	end
	local seconds = 0
	for k, m in members do
		local duration = m.maxHp / math.max(1e-6, FightSim.dps(p, m, skill))
		seconds += duration
		for j = k, #members do
			local other = members[j]
			lost += FightSim.hit(other, p) * duration / other.attackInterval
			local ability = other.ability
			if ability then
				lost += FightSim.hit(other, p, ability.damage, ability.damageKind, false) * FightSim.SPECIAL_HIT * duration / ability.cooldown
			end
		end
	end
	lost -= (p.values.hpRegenCombat or 0) * seconds
	local hp = math.max(1, p.values.maxHp or 1)
	return { seconds = seconds, hpLost = math.max(0, lost) / hp, playerHp = hp }
end

-- `n` members of a monster kind at spawner level `level` (Elite II carry their ability).
function FightSim.group(kind: any, level: number, n: number, variant: MonsterStats.Variant?): { any }
	local v: MonsterStats.Variant = variant or "normal"
	local members = {}
	for _ = 1, n do
		local m: any = table.clone(MonsterStats.compute(kind, level, v, n))
		if v == "elite2" and kind.ability then
			m.ability = MonsterAbilities.get(kind.ability)
		end
		table.insert(members, m)
	end
	return members
end

-- Expected fight over the group sizes of Logic/AreaSpawns: HP lost and seconds per fight, members per fight.
function FightSim.expectedGroup(
	p: Player,
	kind: any,
	level: number,
	skill: number?
): { hpLost: number, seconds: number, members: number, bySize: { Fight } }
	local total, hpLost, seconds, members = 0, 0, 0, 0
	local bySize: { Fight } = {}
	for n, w in AreaSpawns.GROUP_SIZE_WEIGHTS do
		local fight = FightSim.groupFight(p, FightSim.group(kind, level, n), skill)
		bySize[n] = fight
		total += w
		hpLost += w * fight.hpLost
		seconds += w * fight.seconds
		members += w * n
	end
	return { hpLost = hpLost / total, seconds = seconds / total, members = members / total, bySize = bySize }
end

return FightSim
