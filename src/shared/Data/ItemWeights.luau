--!strict
-- Weights of the "Better item!" score (S67, Logic/ItemScore; DESIGN §5.9). Data only, never on the wiki.
-- A weight is points per unit of a stat or hook as it lands in ItemRoll.itemStats, on one of four axes; a % line
-- (mode "pct") is worth PCT_POINTS per 1 % when its stat has a weight. Traits are valued once, by their STATY 14
-- starting estimate (% of the axis at Common +0) x PCT_POINTS x trait strength.

export type Axis = "dmg" | "surv" | "support" | "util"
export type Weight = { axis: Axis, w: number, situational: boolean? } -- w = points per unit as it lands in itemStats
export type TraitWeight = { axis: Axis, pct: number } -- % of the axis at Common +0 (STATY 14 start values)
-- PathDef.itemWeights: multipliers on top of the class weights (1 = unchanged, 0 = ignore).
export type ItemWeights = {
	axes: { [string]: number }?, -- "dmg" | "surv" | "support" | "util"
	stats: { [string]: number }?, -- StatCalc stat id, hook id, or a Data/Bonuses line id (read as its stat / hook)
	traits: { [string]: number }?, -- trait id from Data/ItemTraits
}

local function dmg(w: number, situational: boolean?): Weight
	return table.freeze({ axis = "dmg" :: Axis, w = w, situational = situational })
end
local function surv(w: number, situational: boolean?): Weight
	return table.freeze({ axis = "surv" :: Axis, w = w, situational = situational })
end
local function support(w: number): Weight
	return table.freeze({ axis = "support" :: Axis, w = w })
end
local function util(w: number): Weight
	return table.freeze({ axis = "util" :: Axis, w = w })
end
local function trait(axis: Axis, pct: number): TraitWeight
	return table.freeze({ axis = axis, pct = pct })
end

-- S20 weights, every class alike; S67 adds the defensive lines that are worth the same to everyone.
local COMMON: { [string]: Weight } = {
	vit = surv(2),
	maxHp = surv(0.2),
	armor = surv(0.6),
	mres = surv(0.5),
	hpRegen = surv(2),
	dodge = surv(3),
	resFire = surv(0.4),
	resIce = surv(0.4),
	resLightning = surv(0.4),
	resPoison = surv(0.4),
	critResist = surv(0.1), -- monsters crit 5 % of the time
	meleeGuard = surv(1.2), -- about 60 % of blows are melee
	rangedGuard = surv(0.8), -- about 40 % ranged
	moveSpeed = util(1),
	expBonus = util(0.5),
	dropBonus = util(0.5),
	goldBonus = util(0.3),
}

-- S20 weights by class plus the S62-S64 lines (STATY 14 estimates; hooks of those lines by hook id).
local CLASS: { [string]: { [string]: Weight } } = {
	Warrior = {
		str = dmg(3),
		physAtk = dmg(3),
		critChance = dmg(3),
		critDmg = dmg(1),
		atkSpeed = dmg(3),
		lifesteal = surv(3),
		maxEnergy = dmg(0.5),
		energyRegen = dmg(2),
		accuracy = dmg(1.5),
		pierce = dmg(0.4), -- 20 % pierce is about +4 % on a common monster (was a flat-armour weight 2)
		skillDmg = dmg(1),
		basicDmg = dmg(1),
		costReduce = dmg(0.6),
		dotPower = dmg(0.2),
		woundChance = dmg(0.4),
		resourceOnHit = dmg(4),
		block = surv(2),
	},
	Hunter = {
		dex = dmg(3),
		physAtk = dmg(3),
		critChance = dmg(4),
		critDmg = dmg(1.5),
		atkSpeed = dmg(3),
		lifesteal = surv(2),
		maxEnergy = dmg(0.5),
		energyRegen = dmg(2),
		accuracy = dmg(2),
		pierce = dmg(0.4),
		skillDmg = dmg(1),
		basicDmg = dmg(1.2),
		costReduce = dmg(0.6),
		dotPower = dmg(0.3),
		woundChance = dmg(0.4),
		poisonChance = dmg(0.4),
		resourceOnHit = dmg(4),
	},
	Mage = {
		int = dmg(3),
		magAtk = dmg(3),
		critChance = dmg(3),
		critDmg = dmg(1),
		atkSpeed = dmg(2),
		maxMana = dmg(0.4),
		manaRegen = dmg(3),
		magicPierce = dmg(0.4),
		skillDmg = dmg(1.6),
		basicDmg = dmg(0.4),
		costReduce = dmg(1.4),
		dotPower = dmg(0.2),
		resourceOnHit = dmg(6),
	},
	Cleric = {
		int = dmg(3),
		magAtk = dmg(3),
		maxMana = dmg(0.4),
		manaRegen = dmg(3),
		critChance = dmg(2),
		atkSpeed = dmg(2),
		magicPierce = dmg(0.4),
		skillDmg = dmg(1.4),
		basicDmg = dmg(0.6),
		costReduce = dmg(1),
		dotPower = dmg(0.1),
		resourceOnHit = dmg(5),
		healPower = support(2),
		block = surv(2),
	},
}

-- Hooks of every class. Class-dependent hooks weigh 0 here so a class without its entry gets 0, not HOOK_DEFAULT.
local HOOKS: { [string]: Weight } = {
	bossDamage = dmg(2, true),
	eliteDamage = dmg(2, true),
	doubleAttack = dmg(1),
	killHeal = surv(8), -- 1 % max HP per kill is about 4 % survival (STATY 14, Reaping)
	thorns = dmg(0.2),
	manaOnHit = dmg(3),
	executioner = dmg(0.6),
	lastStand = surv(0.6),
	cooldownReduction = dmg(1),
	dotPower = dmg(0),
	woundChance = dmg(0),
	poisonChance = dmg(0),
	resourceOnHit = dmg(0),
	block = surv(0),
}

-- Lines with a parameter (S67): family and class lines, situational (STATY 10: half value).
local PREFIX_HOOKS: { [string]: Weight } = {
	vs_ = dmg(2, true),
	res_ = surv(2, true),
}

-- STATY 14 starting estimates of every trait (Common +0).
-- S88 (C10): the values measured in the trait bands where they differ from the STATY 14 estimate by over 1 point
local TRAITS: { [string]: TraitWeight } = {
	swordplay = trait("dmg", 4),
	twinCut = trait("dmg", 4),
	reaping = trait("surv", 5),
	bonebreaker = trait("surv", 6),
	beheading = trait("dmg", 4.6),
	rendingGash = trait("dmg", 4.5),
	sundering = trait("dmg", 5),
	runThrough = trait("dmg", 5),
	parry = trait("surv", 5),
	harrying = trait("surv", 5),
	toxicBarbs = trait("dmg", 4.5),
	criticalForce = trait("dmg", 4.5),
	easyPrey = trait("dmg", 6),
	bodkinBolt = trait("dmg", 5),
	fullDraw = trait("dmg", 4.5),
	elementalSpark = trait("dmg", 4.5),
	elementalMight = trait("dmg", 6.5),
	runicSeal = trait("dmg", 5.5),
	learnedFormulae = trait("dmg", 2),
	powerLens = trait("dmg", 4.75),
	anointment = trait("support", 5),
	savingBlow = trait("support", 4),
	concussion = trait("surv", 4.5),
	prosperity = trait("util", 8),
}

local ALL_AXES = table.freeze({ dmg = 1, surv = 1, support = 1, util = 1 })

return table.freeze({
	AXES = table.freeze({ "dmg", "surv", "support", "util" } :: { Axis }),
	PCT_POINTS = 2, -- points worth 1 % of an axis (S20: a +1 % pct line scored 2)
	SITUATIONAL = 0.5, -- lines that work only against one family, one class, bosses or elites (STATY 10)
	WEAPON = 5, -- points per point of weapon damage per second (S20)
	UPGRADE_MARGIN = 1.02, -- S20
	HOOK_DEFAULT = dmg(1),
	common = table.freeze(COMMON),
	class = table.freeze(CLASS),
	hooks = table.freeze(HOOKS),
	prefixHooks = table.freeze(PREFIX_HOOKS),
	traits = table.freeze(TRAITS),
	-- Axis multipliers of each class (paths change them through itemWeights).
	axes = table.freeze({ Warrior = ALL_AXES, Hunter = ALL_AXES, Mage = ALL_AXES, Cleric = ALL_AXES }),
})
