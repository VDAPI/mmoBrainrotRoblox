--!strict
-- Damage formula (DESIGN §4.5). Pure; all randomness comes from the injected Rng.
--
--   raw        = attack x multiplier + flat
--   effective  = max(0, defense - armorPen)            (penetration only against physical armor)
--   reduction  = effective / (effective + 40 x attackerLevel + 200)
--   damage     = raw x (1 - reduction) x random(0.92..1.08) x crit x (1 - elementRes) x pvp(0.6)
--   dodge      = clamp(targetDodge - attackerAccuracy, 0, 30 %)

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
}

export type Result = {
	amount: number,
	crit: boolean,
	dodged: boolean,
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

-- Fraction of damage removed by `defense` against an attacker of `attackerLevel`.
function Damage.reduction(defense: number, attackerLevel: number): number
	local def = math.max(0, defense)
	return def / (def + Combat.reductionPerLevel * attackerLevel + Combat.reductionBase)
end

function Damage.computeDamage(attacker: Attacker, defender: Defender, params: Params, rng: Rng.Rng): Result
	local element: Element? = params.element
	if params.canDodge ~= false and not Damage.rollHit(defender.dodge or 0, attacker.accuracy or 0, rng) then
		return { amount = 0, crit = false, dodged = true, element = element, lifesteal = 0 }
	end

	local attack = if params.kind == "magic" then attacker.magAtk else attacker.physAtk
	local raw = math.max(0, attack * (params.multiplier or 1) + (params.flat or 0))

	local defense = if params.kind == "magic"
		then defender.mres
		else math.max(0, defender.armor - (attacker.armorPen or 0))
	local amount = raw * (1 - Damage.reduction(defense, attacker.level))
	amount *= rng:float(Combat.randomMin, Combat.randomMax)

	local crit = false
	if params.forceCrit or (params.canCrit ~= false and rng:chance(math.clamp(attacker.critChance, 0, 100) / 100)) then
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
