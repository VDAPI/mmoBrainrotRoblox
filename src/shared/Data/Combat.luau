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
	-- S32: gold from monsters far below the player drops by this share of the EXP penalty (Logic/Exp).
	goldPenaltyShare = 0.5,
	-- S32: EXP and gold of a kind x hpMul ^ kindRewardHpExponent x (atkMul x speed) ^ kindRewardAtkExponent: tougher
	-- kinds pay more, and EXP per second of fighting stays within ~±15 % between kinds (was 0.7-1.7).
	kindRewardHpExponent = 0.75,
	kindRewardAtkExponent = 0.25,

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
	-- S32: damage of each member by the size of its group (1-4). The whole group attacks at once, so without this
	-- a group of 4 dealt ~10x the damage of one monster; tests/balance.spec checks the group targets.
	groupDamageMul = table.freeze({ 1, 0.85, 0.72, 0.62 }),

	-- Variants (DESIGN §15.1).
	variants = table.freeze({
		normal = table.freeze({ levelAdd = 0, hpMul = 1, dmgMul = 1, scale = 1, aggroRange = 12 }),
		-- S32 (tests/balance.spec): an Elite solo takes 20-35 s and 60-90 % HP (was ~35 s and 110-145 %), an Elite II
		-- needs 2-3 players of its level (was ~150 % HP of the tank for three).
		elite = table.freeze({ levelAdd = 2, hpMul = 3.0, dmgMul = 1.25, scale = 1.25, aggroRange = 20 }),
		elite2 = table.freeze({ levelAdd = 4, hpMul = 10, dmgMul = 1.35, scale = 1.5, aggroRange = 20 }),
		-- Dungeon bosses (DESIGN §16): HP is 30 x normal x players (Logic/BossScaling via the kind's hpMul).
		-- dmgMul 6 (was 2.2 before S18) keeps boss hits close to the old values after the flatter attack curve.
		boss = table.freeze({ levelAdd = 0, hpMul = 1, dmgMul = 6, scale = 1, aggroRange = 70 }),
	}),

	-- AI (DESIGN §15.1).
	wanderRadius = 8, -- around the group centre (S19)
	passiveLevelGap = 15, -- monsters this many levels below the player do not attack first
	aiTickRate = 5, -- per second
	sleepRadius = 250, -- spawners without players this close stop working (S19: was 150)
	-- Leash (S22, Logic/Leash): past leashRange from the group centre a monster goes home once no player has hit
	-- its group for leashGrace seconds; past leashMax it always goes home. A chasing monster that has not moved
	-- (and not attacked) for stuckTime seconds goes home too. Going home: no healing, no invulnerability,
	-- returnSpeedMultiplier x speed, teleported home after returnTimeout seconds. Back home (idle), it regains
	-- idleRegenPct % of its max HP per second once idleRegenDelay seconds have passed since the last hit.
	leashRange = 70,
	leashMax = 150,
	leashGrace = 5,
	stuckTime = 5,
	returnSpeedMultiplier = 1.25,
	returnTimeout = 12,
	idleRegenDelay = 4,
	idleRegenPct = 8,
})
