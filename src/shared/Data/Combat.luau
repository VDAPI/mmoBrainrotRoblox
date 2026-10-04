--!strict
-- Combat constants (DESIGN §4.5, §15.1, §24). Data only; formulas in Logic/Damage and Logic/MonsterStats.

return table.freeze({
	-- Damage formula: reduction = def / (def + reductionPerLevel x attackerLevel + reductionBase)
	reductionPerLevel = 40,
	reductionBase = 200,
	randomMin = 0.92,
	randomMax = 1.08,
	pvpModifier = 0.6,
	dodgeCap = 30, -- % after subtracting accuracy
	minDamage = 1,

	-- Basic attack ranges in studs (DESIGN §24) and the lag tolerance the server allows on top.
	meleeRange = 7,
	rangedRange = 35,
	rangeTolerance = 4,

	-- Who sees damage numbers / hit effects.
	fxRadius = 80,

	-- Gold from a monster: round((goldBase + goldFactor x L ^ goldExponent) x variant multiplier x random(goldRandomMin..Max))
	goldBase = 2,
	goldFactor = 1.2,
	goldExponent = 1.1,
	goldRandomMin = 0.8,
	goldRandomMax = 1.2,
	goldVariantMultiplier = table.freeze({ normal = 1, elite = 3, elite2 = 8, boss = 40 }),

	-- Monster base stats (DESIGN §15.1): HP = 60 + 28 L^1.35, attack = 6 + 3.2 L^1.15, armor = 4 L.
	monsterHpBase = 60,
	monsterHpFactor = 28,
	monsterHpExponent = 1.35,
	monsterAtkBase = 6,
	monsterAtkFactor = 3.2,
	monsterAtkExponent = 1.15,
	monsterArmorPerLevel = 4,
	monsterMresPerLevel = 3,
	monsterAttackInterval = 1.6, -- seconds between attacks before the kind's speed multiplier
	monsterCritChance = 5,
	monsterCritDmg = 150,

	-- Variants (DESIGN §15.1).
	variants = table.freeze({
		normal = table.freeze({ levelAdd = 0, hpMul = 1, dmgMul = 1, scale = 1, aggroRange = 18 }),
		elite = table.freeze({ levelAdd = 2, hpMul = 4, dmgMul = 1.5, scale = 1.25, aggroRange = 25 }),
		elite2 = table.freeze({ levelAdd = 4, hpMul = 12, dmgMul = 2, scale = 1.5, aggroRange = 25 }),
	}),

	-- AI (DESIGN §15.1).
	wanderRadius = 10,
	leashRange = 45,
	passiveLevelGap = 15, -- monsters this many levels below the player do not attack first
	aiTickRate = 5, -- per second
	sleepRadius = 150, -- spawners without players this close stop working
	returnSpeedMultiplier = 1.6,
})
