--!strict
-- Damage formula (DESIGN §4.5). Pure; all randomness comes from the injected Rng.
--
--   raw        = attack x multiplier + flat
--   effective  = max(0, defense - armorPen)            (penetration only against physical armor)
--   reduction  = effective / (effective + 40 x attackerLevel + 200)
--   damage     = raw x (1 - reduction) x random(0.92..1.08) x crit x (1 - elementRes) x pvp(0.6)
--   dodge      = clamp(targetDodge - attackerAccuracy, 0, 30 %)
--   S61: dodge + miss (the attacker's misfortune) + block <= dodgeCap + avoidBonus, one roll (Damage.avoidance)

local BuffCategories = require("../Data/BuffCategories")
local Combat = require("../Data/Combat")
local Rng = require("./Rng")

export type Element = "fire" | "ice" | "lightning" | "poison"

export type Attacker = {
	level: number,
	physAtk: number,
	magAtk: number,
	critChance: number, -- %
	critDmg: number, -- %, 150 = x1.5
	accuracy: number?, -- %
	armorPen: number?,
	lifesteal: number?, -- % of damage dealt
}

export type Defender = {
	armor: number,
	mres: number,
	dodge: number?, -- %
	res: { [string]: number }?, -- element -> %
	level: number?, -- for the level advantage (Damage.levelGap); nil = none
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
}

export type Result = {
	amount: number,
	crit: boolean,
	dodged: boolean, -- also true on a miss: nothing landed
	missed: boolean?, -- S61: the attacker missed (misfortune), shown as "Miss"
	element: Element?,
	lifesteal: number, -- HP the attacker heals
}

local Damage = {}

local RES_KEYS: { [string]: string } = {
	fire = "resFire",
	ice = "resIce",
	lightning = "resLightning",
	poison = "resPoison",
}

-- Chance (0..1) that the defender dodges.
function Damage.dodgeChance(defenderDodge: number, attackerAccuracy: number): number
	return math.clamp(defenderDodge - attackerAccuracy, 0, Combat.dodgeCap) / 100
end

function Damage.rollHit(defenderDodge: number, attackerAccuracy: number, rng: Rng.Rng): boolean
	return not rng:chance(Damage.dodgeChance(defenderDodge, attackerAccuracy))
end

-- S61 (ROZWOJ 7.6): chances (0..1) of dodge, miss and block. Their sum is capped at dodgeCap + avoidBonus, cut in
-- this order: the dodge stays, the miss gets at most the rest, the block what is left.
function Damage.avoidance(dodge: number, accuracy: number, miss: number?, block: number?): (number, number, number)
	local total = (Combat.dodgeCap + Combat.avoidBonus) / 100
	local d = Damage.dodgeChance(dodge, accuracy)
	local m = math.min(math.clamp(miss or 0, 0, BuffCategories.caps.enemyMiss) / 100, math.max(0, total - d))
	local b = math.min(math.max(0, block or 0) / 100, math.max(0, total - d - m))
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
		local d, m = Damage.avoidance(defender.dodge or 0, attacker.accuracy or 0, params.miss)
		-- The block does not come back from here yet (S64).
		local outcome = Damage.rollAvoid(d, m, 0, rng)
		if outcome == "dodge" or outcome == "miss" then
			return {
				amount = 0,
				crit = false,
				dodged = true,
				missed = outcome == "miss",
				element = element,
				lifesteal = 0,
			}
		end
	end

	local attack = if params.kind == "magic" then attacker.magAtk else attacker.physAtk
	local raw = math.max(0, attack * (params.multiplier or 1) + (params.flat or 0))

	local defense = if params.kind == "magic"
		then defender.mres
		else math.max(0, defender.armor - (attacker.armorPen or 0))
	local gapMul, gapCrit = Damage.levelGap(attacker.level, defender.level)
	local amount = raw * (1 - Damage.reduction(defense, attacker.level)) * gapMul
	amount *= rng:float(Combat.randomMin, Combat.randomMax)

	local crit = false
	local critChance = math.clamp(attacker.critChance + gapCrit, 0, 100) / 100
	if params.forceCrit or (params.canCrit ~= false and rng:chance(critChance)) then
		crit = true
		amount *= math.max(1, attacker.critDmg / 100)
	end

	if element and defender.res then
		local res = defender.res[RES_KEYS[element] or element] or 0
		amount *= 1 - math.clamp(res, 0, 75) / 100
	end
	if params.pvp then
		amount *= Combat.pvpModifier
	end

	local final = math.max(Combat.minDamage, math.floor(amount + 0.5))
	local lifesteal = math.floor(final * math.clamp(attacker.lifesteal or 0, 0, 15) / 100)
	return { amount = final, crit = crit, dodged = false, element = element, lifesteal = lifesteal }
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
		armorPen = values.armorPen or 0,
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
	}
end

return Damage
