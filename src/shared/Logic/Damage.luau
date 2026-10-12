--!strict
-- Damage formula (DESIGN §4.5). Pure; all randomness comes from the injected Rng.
--
--   raw        = (attack x multiplier + flat) x (1 + skillDmg | basicDmg)   (S62: params.isSkill / params.basic)
--   effective  = armor x (1 - armorBreak) x (1 - pierce)   or   mres x (1 - magicPierce)   (Damage.defenseOf)
--   reduction  = effective / (effective + 40 x attackerLevel + 200)
--   crit       = 1 + (critDmg/100 - 1) x (1 - defender critResist)   (S62: Damage.critMultiplier)
--   damage     = raw x (1 - reduction) x random(0.92..1.08) x crit x (1 - elementRes) x pvp(0.6)
--   dodge      = clamp(targetDodge - attackerAccuracy, 0, 30 %)
--   S61: dodge + miss (the attacker's misfortune) + block <= dodgeCap + avoidBonus, one roll (Damage.avoidance)
--   S64: the block (regular hits only) is the third outcome of that roll; melee / ranged protection is a reduction
--        entry in CombatService (Damage.guard), not part of this formula

local BuffCategories = require("../Data/BuffCategories")
local Combat = require("../Data/Combat")
local Rng = require("./Rng")
local Stats = require("../Data/Stats")

export type Element = "fire" | "ice" | "lightning" | "poison"

export type Attacker = {
	level: number,
	physAtk: number,
	magAtk: number,
	critChance: number, -- %
	critDmg: number, -- %, 150 = x1.5
	accuracy: number?, -- %
	pierce: number?, -- % armour ignored, cap Data/Stats
	magicPierce: number?, -- % magic resistance ignored, cap Data/Stats
	skillDmg: number?, -- % more skill damage (params.isSkill)
	basicDmg: number?, -- % more basic attack damage (params.basic)
	lifesteal: number?, -- % of damage dealt
}

export type Defender = {
	armor: number,
	mres: number,
	dodge: number?, -- %
	res: { [string]: number }?, -- element -> %
	level: number?, -- for the level advantage (Damage.levelGap); nil = none
	critResist: number?, -- % of the crit bonus removed
}

export type Params = {
	kind: "phys" | "magic",
	multiplier: number?, -- skill multiplier (1 for basic attacks)
	flat: number?,
	element: Element?,
	pvp: boolean?,
	canCrit: boolean?, -- default true
	canDodge: boolean?, -- default true
	forceCrit: boolean?, -- always crit (Hunter's Camouflage)
	miss: number?, -- S61: % chance the attacker misses (misfortune on the attacker; already x0.5 in PvP)
	armorBreak: number?, -- % armour removed by armour break, before pierce; set by CombatService
	isSkill: boolean?, -- skill damage: attacker.skillDmg
	basic: boolean?, -- basic attack (also its double hit): attacker.basicDmg
	block: number?, -- % chance the defender blocks; already capped and PvP-scaled by the caller (Traits.blockChance)
}

export type Result = {
	amount: number,
	crit: boolean,
	dodged: boolean, -- also true on a miss: nothing landed
	missed: boolean?, -- S61: the attacker missed (misfortune), shown as "Miss"
	blocked: boolean?, -- S64: the defender blocked (dodged is true too: nothing landed), shown as "Blocked"
	element: Element?,
	lifesteal: number, -- HP the attacker heals
	-- S63: the hit before Combat.pvpModifier, after armor, crit and resistances: base of damage over time (0 when
	-- nothing landed; equal to amount outside PvP).
	dotBase: number?,
}

local Damage = {}

local RES_KEYS: { [string]: string } = {
	fire = "resFire",
	ice = "resIce",
	lightning = "resLightning",
	poison = "resPoison",
}

local function capOf(id: string): number
	local def = Stats.get(id)
	return if def and def.cap then def.cap else 100
end
local PIERCE_CAP, MAGIC_PIERCE_CAP, CRIT_RESIST_CAP = capOf("pierce"), capOf("magicPierce"), capOf("critResist")

-- S62 (STATY 4, 13): defence that counts against a hit. Physical: armour after armour break, then pierce; magic:
-- magic resistance after magic pierce.
function Damage.defenseOf(kind: "phys" | "magic", attacker: Attacker, defender: Defender, armorBreak: number?): number
	if kind == "magic" then
		return math.max(0, defender.mres) * (1 - math.clamp(attacker.magicPierce or 0, 0, MAGIC_PIERCE_CAP) / 100)
	end
	return math.max(0, defender.armor)
		* (1 - math.clamp(armorBreak or 0, 0, 100) / 100)
		* (1 - math.clamp(attacker.pierce or 0, 0, PIERCE_CAP) / 100)
end

-- S62: crit multiplier; critResist removes part of the bonus above x1 (not of the whole hit).
function Damage.critMultiplier(critDmg: number, critResist: number?): number
	return 1 + math.max(0, critDmg / 100 - 1) * (1 - math.clamp(critResist or 0, 0, CRIT_RESIST_CAP) / 100)
end

-- S62: skill / basic attack damage bonus of the attacker for this hit.
function Damage.bonusMul(attacker: Attacker, params: Params): number
	local mul = 1
	if params.isSkill then
		mul *= 1 + (attacker.skillDmg or 0) / 100
	end
	if params.basic then
		mul *= 1 + (attacker.basicDmg or 0) / 100
	end
	return mul
end

-- S63: damage multiplier of an elemental resistance (capped at 75 %); also poison ticks against resPoison.
function Damage.resMul(res: number): number
	return 1 - math.clamp(res, 0, 75) / 100
end

-- S63 (STATY 8): armour break from items on a player: at most Combat.pvp.armorBreakStacks stacks, item cap.
function Damage.pvpArmorBreak(unit: number, stacks: number): number
	return math.min(
		math.max(0, unit) * math.clamp(stacks, 0, Combat.pvp.armorBreakStacks),
		BuffCategories.caps.enemyArmorItem
	)
end

-- Chance (0..1) that the defender dodges.
function Damage.dodgeChance(defenderDodge: number, attackerAccuracy: number): number
	return math.clamp(defenderDodge - attackerAccuracy, 0, Combat.dodgeCap) / 100
end

function Damage.rollHit(defenderDodge: number, attackerAccuracy: number, rng: Rng.Rng): boolean
	return not rng:chance(Damage.dodgeChance(defenderDodge, attackerAccuracy))
end

-- S66 (STATY 6, 7): monsters dodge only players' basic attacks; any other player hit on a monster cannot be dodged.
-- Never changes `params` (an area skill reuses it for the next targets).
function Damage.paramsVsMonster(params: Params, basic: boolean?): Params
	if basic or params.canDodge == false then
		return params
	end
	local copy = table.clone(params)
	copy.canDodge = false
	return copy
end

-- S61 (ROZWOJ 7.6): chances (0..1) of dodge, miss and block. Their sum is capped at dodgeCap + avoidBonus, cut in
-- this order: the dodge stays, the miss gets at most the rest, the block what is left.
function Damage.avoidance(dodge: number, accuracy: number, miss: number?, block: number?): (number, number, number)
	local total = (Combat.dodgeCap + Combat.avoidBonus) / 100
	local d = Damage.dodgeChance(dodge, accuracy)
	local m = math.min(math.clamp(miss or 0, 0, BuffCategories.caps.enemyMiss) / 100, math.max(0, total - d))
	local b = math.min(math.clamp(block or 0, 0, Combat.blockCap) / 100, math.max(0, total - d - m))
	return d, m, b
end

-- Exactly one roll, like rollHit: with miss and block 0 the outcome and the roll sequence are the same as before S61.
function Damage.rollAvoid(dodge: number, miss: number, block: number, rng: Rng.Rng): ("dodge" | "miss" | "block")?
	local r = rng:next()
	if r < dodge then
		return "dodge"
	elseif r < dodge + miss then
		return "miss"
	elseif r < dodge + miss + block then
		return "block"
	end
	return nil
end

-- S64 (STATY 6): % melee / ranged protection that counts against a blow of `delivery` (nil: neither, e.g. red
-- zones). The cap of 30 comes from Data/Stats through StatCalc.
function Damage.guard(delivery: string?, melee: number, ranged: number): number
	if delivery == "melee" then
		return math.clamp(melee, 0, 100)
	elseif delivery == "ranged" then
		return math.clamp(ranged, 0, 100)
	end
	return 0
end

-- Fraction of damage removed by `defense` against an attacker of `attackerLevel`.
function Damage.reduction(defense: number, attackerLevel: number): number
	local def = math.max(0, defense)
	return def / (def + Combat.reductionPerLevel * attackerLevel + Combat.reductionBase)
end

-- Level advantage (Data/Combat.levelGap*): damage multiplier and extra crit chance (%) of an attacker
-- `attackerLevel` against a defender `defenderLevel`. Below Combat.levelGapFrom levels of advantage: (1, 0).
function Damage.levelGap(attackerLevel: number, defenderLevel: number?): (number, number)
	if defenderLevel == nil then
		return 1, 0
	end
	local steps = math.clamp(attackerLevel - defenderLevel - Combat.levelGapFrom + 1, 0, Combat.levelGapMaxSteps)
	return 1 + steps * Combat.levelGapDmg, steps * Combat.levelGapCrit
end

function Damage.computeDamage(attacker: Attacker, defender: Defender, params: Params, rng: Rng.Rng): Result
	local element: Element? = params.element
	if params.canDodge ~= false then
		local d, m, b = Damage.avoidance(defender.dodge or 0, attacker.accuracy or 0, params.miss, params.block)
		local outcome = Damage.rollAvoid(d, m, b, rng)
		if outcome ~= nil then
			return {
				amount = 0,
				crit = false,
				dodged = true,
				missed = outcome == "miss",
				blocked = if outcome == "block" then true else nil,
				element = element,
				lifesteal = 0,
				dotBase = 0,
			}
		end
	end

	local attack = if params.kind == "magic" then attacker.magAtk else attacker.physAtk
	local raw = math.max(0, attack * (params.multiplier or 1) + (params.flat or 0)) * Damage.bonusMul(attacker, params)

	local defense = Damage.defenseOf(params.kind, attacker, defender, params.armorBreak)
	local gapMul, gapCrit = Damage.levelGap(attacker.level, defender.level)
	local amount = raw * (1 - Damage.reduction(defense, attacker.level)) * gapMul
	amount *= rng:float(Combat.randomMin, Combat.randomMax)

	local crit = false
	local critChance = math.clamp(attacker.critChance + gapCrit, 0, 100) / 100
	if params.forceCrit or (params.canCrit ~= false and rng:chance(critChance)) then
		crit = true
		amount *= Damage.critMultiplier(attacker.critDmg, defender.critResist)
	end

	if element and defender.res then
		local res = defender.res[RES_KEYS[element] or element] or 0
		amount *= Damage.resMul(res)
	end
	local dotBase = math.max(Combat.minDamage, math.floor(amount + 0.5))
	if params.pvp then
		amount *= Combat.pvpModifier
	end

	local final = math.max(Combat.minDamage, math.floor(amount + 0.5))
	local lifesteal = math.floor(final * math.clamp(attacker.lifesteal or 0, 0, 15) / 100)
	if params.pvp then
		-- S63 (STATY 8): lifesteal against players heals half.
		lifesteal = math.floor(lifesteal * Combat.pvp.lifesteal)
	end
	return {
		amount = final,
		crit = crit,
		dodged = false,
		element = element,
		lifesteal = lifesteal,
		dotBase = dotBase,
	}
end

-- Builds Attacker/Defender tables from StatCalc values (players).
function Damage.fromStats(level: number, values: { [string]: number }): (Attacker, Defender)
	return {
		level = level,
		physAtk = values.physAtk or 0,
		magAtk = values.magAtk or 0,
		critChance = values.critChance or 0,
		critDmg = values.critDmg or 150,
		accuracy = values.accuracy or 0,
		pierce = values.pierce or 0,
		magicPierce = values.magicPierce or 0,
		skillDmg = values.skillDmg or 0,
		basicDmg = values.basicDmg or 0,
		lifesteal = values.lifesteal or 0,
	}, {
		level = level,
		armor = values.armor or 0,
		mres = values.mres or 0,
		dodge = values.dodge or 0,
		res = {
			resFire = values.resFire or 0,
			resIce = values.resIce or 0,
			resLightning = values.resLightning or 0,
			resPoison = values.resPoison or 0,
		},
		critResist = values.critResist or 0,
	}
end

return Damage
