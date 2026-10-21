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
	avoidBonus = 10, -- S61: dodge + miss + block <= dodgeCap + avoidBonus (%), Logic/Damage.avoidance
	minDamage = 1,
	-- "Below 30 % HP" threshold of the executioner and last-stand effects (Data/Bonuses hooks).
	lowHpFraction = 0.3,
	-- S54 (ROZWOJ 8): skill damage x base weapon speed / skillSpeedRef (two-handed axe = x1); basic attacks unchanged.
	-- The balance sessions own the value.
	skillSpeedRef = 0.8,

	-- S61 (ROZWOJ 7.6): PvP rules. Control keeps Config.PvpCcMultiplier.
	pvp = table.freeze({
		combatWindow = 10, -- s after the last player hit (dealt or taken) that count as PvP combat
		heal = 0.7, -- heals and heal-over-time ticks on a player in PvP combat
		shield = 0.7, -- absorb shields applied to a player in PvP combat
		misfortune = 0.5, -- the attacker's misfortune in the PvP branch of DealDamage
		fortuneBuff = 0.5, -- Fortune's random party buffs (dice and wheel, read from S70)
		-- luck: none in PvP, enforced by Logic/Luck options.pvp (S60); no loot comes from players
		-- S63 (STATY 8):
		dot = 0.6, -- every damage-over-time tick of a player on a player (items and skills), applied once
		armorBreakStacks = 3, -- most armour break stacks from items on a player
		lifesteal = 0.5, -- the attacker's lifesteal stat against players (not a skill's behaviour.lifesteal)
		-- S64 (STATY 8):
		block = 0.5, -- block chance after blockCap: 2.5 % from the shield, at most 12.5 %
		counter = 0.5, -- counter chance after riposteCap: 5 % from the sword, at most 15 %
		frostbite = 0.5, -- S65 (STATY 8): Frostbite bonus vs players: +3 % (6 %), +5 % with the staff (10 %)
		finisher = 1.5, -- S76 (ROZWOJ 11.3): a skill's finisher multiplier on players, at most this
		-- S140: Phoenix Heart saves from a player's lethal blow too; its invulnerability lasts x this then
		phoenix = 0.5,
	}),
	-- S64 (STATY 3, 5, 6, 8): defensive and conditional item traits.
	blockCap = 25, -- % block chance from every source (Parry trait, blockChance lines, Block / Shield Master nodes)
	riposteCap = 34, -- % counter chance (Swordplay trait, riposte passive, Retaliation and Requital nodes); unlimited before S64
	executionerCap = 60, -- % bonus below lowHpFraction (Beheading, Executioner node, leg_/myth_executioner); unlimited before S64
	cdrCap = 20, -- % skill cooldown reduction from items (leg_cooldown, myth_cooldown)
	-- S67 (STATY 4, 8): lines with a parameter.
	familyResCap = 30, -- % sum of res_<family> lines from items against one monster family
	classLineCap = 20, -- % each side in PvP: the attacker's vs_<target class> sum, the target's res_<attacker class> sum
	-- S63 (STATY 4, 5): on-hit effects of items.
	onHitChanceCap = 40, -- % total chance of one on-hit effect (trait + line)
	areaProcShare = 1 / 3, -- share of the chance per target of an area skill
	resourceOnHitCap = 1, -- % of max mana / energy per hit from the resourceOnHit line
	resourceOnHitGap = 0.5, -- s between two resourceOnHit refunds
	-- S61: the Guardian's intercept (Logic/Intercept; share caps in Data/BuffCategories).
	interceptRadius = 20, -- studs: default radius of an intercept effect (the guard must stand this close)
	interceptWindow = 1, -- s: window of BuffCategories.caps.interceptPerSecond
	-- S61: red zone registry (CombatService.RedZones).
	redZoneGrace = 0.5, -- s a red zone stays registered after its windup when the cast never resolves

	-- Basic attack ranges in studs (DESIGN §24) and the lag tolerance the server allows on top.
	meleeRange = 7,
	rangedRange = 35,
	rangeTolerance = 4,

	-- Who sees damage numbers / hit effects.
	fxRadius = 80,
	-- S159 (owner 2026-10-21, "a blow you can see coming"): a monster's regular blow winds up this long before it lands
	-- (the clients pose the draw, "aw"); the interval between blows stays. A target that stepped farther than
	-- reach x windReach + windSlack (flat studs) by then is missed. Ranged blows fly as projectiles after the draw.
	-- S159a: an Elite II's throw at a fleeing target is drawn back too (a throw / a spell the target can see coming).
	basicWind = table.freeze({ melee = 0.45, ranged = 0.35, throw = 0.5 }),
	windReach = 1.5,
	windSlack = 3,

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

	-- Monster base stats (DESIGN §15.1, lowered after the S17 tests): HP = 55 + monsterHpComp x 15 L^1.55,
	-- attack = 4 + 2.5 L^0.88, armour = 10 L x defMul, magic resistance = 8 L x mresMul (S66, STATY 7).
	-- tests/balance.spec checks fight length and HP lost against the design target.
	monsterHpBase = 55,
	monsterHpFactor = 15,
	-- S66: monster HP compensation for the higher armour (10 L) and magic resistance (8 L), on the level part only
	-- (STATY 7 start 0.85, measured 0.9: tests/balance.spec 1-20 keeps its fight times); tuned in S84 / S88
	monsterHpComp = 0.9,
	monsterHpExponent = 1.55,
	monsterAtkBase = 4,
	monsterAtkFactor = 2.5,
	monsterAtkExponent = 0.88,
	monsterArmorPerLevel = 10,
	monsterMresPerLevel = 8,
	monsterAttackInterval = 2.0, -- seconds between attacks before the kind's speed multiplier
	monsterCritChance = 5,
	monsterCritDmg = 150,
	-- S32: damage of each member by the size of its group (1-4). The whole group attacks at once, so without this
	-- a group of 4 dealt ~10x the damage of one monster; tests/balance.spec checks the group targets.
	groupDamageMul = table.freeze({ 1, 0.85, 0.72, 0.62 }),
	-- Level advantage (FIX 2026-10-09, Logic/Damage.levelGap): an attacker levelGapFrom+ levels above the defender
	-- gets +levelGapDmg damage and +levelGapCrit % crit chance per level from levelGapFrom on (6 levels = +10 %,
	-- 7 = +20 %...), counted up to levelGapMaxSteps steps. Works both ways (player, monster, PvP).
	levelGapFrom = 6,
	levelGapDmg = 0.10,
	levelGapCrit = 5,
	levelGapMaxSteps = 10,
	-- Elite II respawn (FIX 2026-10-09, Logic/AreaSpawns.elite2Respawn): base + perLevel x cave level seconds,
	-- +-spread around it. S134e (owner 2026-10-15: "too long a wait for the Elite II"): level 20 ~6 min, 66 ~8 min,
	-- 100 ~10 min (was 480 + 12 x level: ~12 / ~21 / ~28 min).
	elite2RespawnBase = 300,
	elite2RespawnPerLevel = 3,
	elite2RespawnSpread = 0.15,
	-- S134i: the Elite II of a hideout on the open map (Logic/AreaSpawns.lair) respawns this many times slower than a cave's
	-- of its top level (Balance.targetsS134i: the hour of a band at most 1.35 of the caves alone)
	lairElite2RespawnMul = 1.5,

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
	-- Obstacle steering (FIX 2026-10-09, Logic/Steer + Entities/Monster): probes this far ahead (plus the
	-- monster's half size), tries these angles to both sides, keeps a detour side this long (seconds).
	steerLookAhead = 6,
	steerAngles = table.freeze({ 35, 70, 105, 140 }),
	steerHold = 0.8,
	returnSpeedMultiplier = 1.25,
	returnTimeout = 12,
	idleRegenDelay = 4,
	idleRegenPct = 8,
})
