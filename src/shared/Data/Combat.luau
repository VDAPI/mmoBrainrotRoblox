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

	-- Gold from a monster (DESIGN §5.5): round(L x goldPerLevel x random(goldRandomMin..Max) x variant multiplier)
	goldPerLevel = 3,
	goldRandomMin = 0.7,
	goldRandomMax = 1.3,
	goldVariantMultiplier = table.freeze({ normal = 1, elite = 4, elite2 = 12, boss = 40 }),

	-- Monster base stats (DESIGN §15.1, lowered after the S17 tests): HP = 55 + 15 L^1.55, attack = 4 + 2.5 L^0.88,
	-- armor = 4 L. tests/balance.spec checks fight length and HP lost against the design target.
	monsterHpBase = 55,
	monsterHpFactor = 15,
	monsterHpExponent = 1.55,
	monsterAtkBase = 4,
	monsterAtkFactor = 2.5,
	monsterAtkExponent = 0.88,
	monsterArmorPerLevel = 4,
	monsterMresPerLevel = 3,
	monsterAttackInterval = 2.0, -- seconds between attacks before the kind's speed multiplier
	monsterCritChance = 5,
	monsterCritDmg = 150,

	-- Variants (DESIGN §15.1).
	variants = table.freeze({
		normal = table.freeze({ levelAdd = 0, hpMul = 1, dmgMul = 1, scale = 1, aggroRange = 12 }),
		elite = table.freeze({ levelAdd = 2, hpMul = 4, dmgMul = 1.5, scale = 1.25, aggroRange = 20 }),
		elite2 = table.freeze({ levelAdd = 4, hpMul = 12, dmgMul = 2, scale = 1.5, aggroRange = 20 }),
		-- Dungeon bosses (DESIGN §16): HP is 30 x normal x players (Logic/BossScaling via the kind's hpMul).
		-- dmgMul 6 (was 2.2 before S18) keeps boss hits close to the old values after the flatter attack curve.
		boss = table.freeze({ levelAdd = 0, hpMul = 1, dmgMul = 6, scale = 1, aggroRange = 70 }),
	}),

	-- AI (DESIGN §15.1).
	wanderRadius = 8, -- around the group centre (S19)
	leashRange = 70,
	passiveLevelGap = 15, -- monsters this many levels below the player do not attack first
	aiTickRate = 5, -- per second
	sleepRadius = 250, -- spawners without players this close stop working (S19: was 150)
	returnSpeedMultiplier = 1.6,
})
