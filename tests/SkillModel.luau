--!strict
-- Skill model (S85, balance plan D1, ROZWOJ 0 / 7.5 / 8): a time-stepped, expected-value fight that casts the real
-- skills of a build (ranks from the level, A/B breakpoints, path nodes, resources, potions) on the game's own pure
-- functions (Paths.effectiveFor, Paths.passiveTotals, StatCalc, Damage, EffectStack, Skills.cost / cooldown / healAmount,
-- Traits). The guard next to the S32 convention (FightSim.SKILL_DPS = x1.2 stays the main model of the G targets).
-- Never game code: test data and measurement assumptions only, nothing in BALANCE_MODULES or on the wiki.
--
--   builds(classId)                 the class base (BASE, rows 1 of every path; Mage rows 1-2) and every
--                                   PathDef.reference (key "<pathId>.<id>"), rotation from the data only
--   character(build, L, element?)   the build trimmed to L: level-up simulation through Paths.canChooseMain / canBuy;
--                                   S137: skill ranks bought through SkillPoints.apply in the pool of the build's
--                                   weapon (Mage: the element; order ReferenceBuild.ranks or rotation, passives, rest)
--   player(build, L, opts?)         Balance.gear + StatPlan.suggest + Paths.passiveTotals + circle auras
--   fight(sp, opts)                 the engine (port of Skills/Context, Types/Offense, Types/Support, Types/Movement,
--                                   SkillService.cast, CombatService.DealDamage / tryBasicAttack, StatusEffectService)
--   metrics(build, L, opts?)        T-SK1..4 numbers of one row; oneHeal (T-SK5); healerVsBoss (T-SK6)
--   targetsG10() / targetsMeadows() TargetRow lists for balance.spec (report mode) and docs/BALANS.md
--   HANDLERS / BEHAVIOURS           registries: S86 adds the class mechanics here
--
-- S86 (balance plan part 4): the class mechanics of S69-S81 in the same engine, each a named function or branch
-- with `-- mirrors <file>:<function>` (heals and shields from the target's max HP B1, dice and wheel B2, burn B3,
-- heal zones B4, Fury B5, block B6, intercept B7, traps B8, falcon B9, aiming B10, beam B11, Arcane Charges B12,
-- accumulate B13, the area rule B14); item traits on the event (STATY 14); a fight with monsters that hit back
-- (`retaliate`); PathMetrics, measured situations, PATH_TARGETS / evaluateTargets, guards, Elite duels. Server-only
-- constants the model copies (TRAP_CHECK, Push SECONDS, the 0.1 s channel poll, ...) are in SERVER_CONSTANTS and
-- tests/balance.spec reads the server files to compare them (text guards).
--
-- Inventory (A3; the full table with counts is in docs/SESJE.md, S85):
--   S85 here: types target, projectile, cone, circleSelf, circleTarget, line, chain, charge, buff, debuff, heal, hot,
--     shield, channel, groupBuff, groupHeal, trap (05b859d shape: effects on the first entry), blink, resurrect;
--     behaviours splash, pierce, lingering (Skills.castZones), echo, split, execute, finisher, firstWave, bleedStacks,
--     poisonStacks, lifesteal, secondTarget, overhealShield, selfHeal, healWounded, burst, stunSplash, cdrPerTarget,
--     critCdr, cleanse, effect / selfEffect / allyEffect; effects statBuff, bleed, poison, armorBreak, vulnerability,
--     nextShot, guaranteedCrit, sighted, hot, shield; hooks elementDamage, holyDamage, areaSkillDamage, eliteDamage,
--     bossDamage, executioner, vs_<family>, damagePerEnemy, weakSpot, dotPower, bleedDamage, poisonDamage,
--     elementRider, riderSameTarget, doubleAttack, manaOnHit, cooldownReduction, zealCdr, the cost hooks (through
--     Skills.cost), heal hooks (healBonus, allyHealBonus, lowHpHealBonus, healCrit, holyStrikeHeal, holyHealAll).
--   S86 (unmodelled, listed per build): types guard, shout, banner, companion, beam, healZone; castTime; Fury
--     (furyConsume, carnage, fury hooks); Arcane Charges and empowered; burn effects; accumulate; spell tag bonuses
--     (areaDamage, singleDamage, spellDamage, resonance); trap damage / rings / pulls / energy; dice; healZone,
--     chainHeal, shieldPerHit, allyHeal, allyShield, behindEffect, shieldBurst; item trait hooks and effects; returns.
--   No effect on a dummy: movement, knockback, pulls, stuns, slows, freezes, roots, taunt, camouflage, damage
--     reduction, invulnerability, mana shield, intercept, kills (poisonSpread, markJump, extendOnKill), defensive hooks.

local B = require("./Balance")
local Bases = require("../src/shared/Data/Items/Bases")
local Bonuses = require("../src/shared/Data/Bonuses")
local BuffCategories = require("../src/shared/Data/BuffCategories")
local Bosses = require("../src/shared/Data/Bosses")
local Chain = require("../src/shared/Logic/Chain")
local Classes = require("../src/shared/Data/Classes")
local Channel = require("../src/shared/Logic/Channel")
local Combat = require("../src/shared/Data/Combat")
local Damage = require("../src/shared/Logic/Damage")
local EffectStack = require("../src/shared/Logic/EffectStack")
local Families = require("../src/shared/Data/Families")
local FightSim = require("../src/shared/Logic/FightSim")
local Fury = require("../src/shared/Logic/Fury")
local Intercept = require("../src/shared/Logic/Intercept")
local ItemTraits = require("../src/shared/Data/ItemTraits")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Monsters = require("../src/shared/Data/Monsters")
local PathData = require("../src/shared/Data/Paths")
local Paths = require("../src/shared/Logic/Paths")
local Potions = require("../src/shared/Logic/Potions")
local Rarities = require("../src/shared/Data/Rarities")
local Roll = require("../src/shared/Logic/Roll")
local SkillData = require("../src/shared/Data/Skills")
local SkillGeom = require("../src/shared/Logic/SkillGeom")
local SkillMotions = require("../src/shared/Data/SkillMotions")
local SkillPoints = require("../src/shared/Logic/SkillPoints")
local SkillPools = require("../src/shared/Logic/SkillPools")
local Skills = require("../src/shared/Logic/Skills")
local StatPlan = require("../src/shared/Logic/StatPlan")
local Stats = require("../src/shared/Data/Stats")
local Traits = require("../src/shared/Logic/Traits")

local SkillModel = {}

-- Test data (assumptions of the measurement, never game numbers) --------------------------------------------------

SkillModel.ASSUMPTIONS = {
	dt = 0.05, -- s per step (diag SkillEngine E.DT)
	burstSeconds = 8, -- T-SK2 / T-SK3 window (balance plan D1)
	sustainedSeconds = 60, -- T-SK1 window (balance plan D1, diag_skills)
	areaTargets = 3, -- T-SK3 dummies (balance plan D1)
	dummyHp = 1e12, -- dummies never die (diag_skills)
	-- execute / finisher / executioner on a dummy: "linear" = share of hits below the threshold is threshold / 100, the
	-- dummy's HP falls linearly through the fight (diag SkillEngine belowFraction); "hp" = by the dummy's real HP (it
	-- never falls: no share)
	executeShare = "linear",
	-- every dummy stands at the aim point in reach of every area (ROZWOJ 11.6, 12.7); a pierce hits the second dummy
	-- when there are at least 2; projectile and orb flight is left out (dummies in reach)
	dummySpread = 0,
	elements = { "fire", "ice", "lightning" }, -- the Mage's number is their mean (ROZWOJ 12.7; the diagnosis: fire)
	teamLevelGap = 1, -- T-SK6 party at the boss level - 1 (diag_heal, S92)
	team = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }, -- T-SK6 default party, tank first (diag_heal)
	-- S92-S94 party 4 (balance plan D1): the measured healer replaces "healer.dungeon"
	teamS92 = { "guardian.defender", "healer.dungeon", "berserker.fury", "marksman.kingslayer" },
	-- HP share of a heal target before the heal outside the HP axis (T-SK5, T-SK6, dummies): no low-HP bonus (S85);
	-- with `retaliate` (S86 D3) the caster's own HP track decides
	healTargetFraction = 1,
	-- S86 measurement assumptions (never contract numbers; DECYZJE S86):
	redZoneMove = 1.5, -- s of movement at each red zone of the boss schedule (STATY 3 Runic Seal, ROZWOJ 12.8)
	bannerUptime = 0.9, -- share of the time the party stands in the War Banner and the shouts (ROZWOJ 10.6)
	-- who stands in a heal zone (ROZWOJ 9.3 "Sanktuarium pod walczącymi wręcz"): the tank and melee fighters yes,
	-- ranged ones no, a solo Cleric yes (the zone under itself)
	zoneInside = { tank = true, melee = true, ranged = false, solo = true },
	-- share of the group a further trap of one cast catches (Frost Trap 10B's side trap at TRAP_SIDE_OFFSET, the ring
	-- snares after the first; ROZWOJ 11.4): floor(groupSpread x n) of the n dummies, the first trap all of them
	groupSpread = 0.5,
	behindShare = B.SITUATIONS.behindShare, -- Run Through in a group: the S84 assumption (STATY 14, not measured)
	retaliateSeconds = 300, -- the longest duel with monsters that hit back (D3; Elites, grind, pace (b))
	grindFights = 20, -- Cleric grind: 20 fights in a row with AreaSpawns groups (ROZWOJ 9.6)
	grindHealSeconds = 3, -- a Heal between fights: 3 s and 20 mana per cast (ROZWOJ 9.6)
	grindHealMana = 20,
	restPct = 0.5, -- % max HP per s of the rest variant (ROZWOJ 9.6, report)
	walk = 6, -- s of walking between groups in the pace formula (6 + 8/g) / 14 (ROZWOJ 10.6)
	fightRef = 8, -- s of the Berserker's group fight in that formula (ROZWOJ 10.6)
	bossSeconds = 180, -- Mage boss window from full mana (ROZWOJ 12.7)
	enemiesNear = 3, -- EHP: monsters within HOOK_RULES.perEnemy.radius for Front Line (ROZWOJ 10.6)
}
local A = SkillModel.ASSUMPTIONS

-- S86 (D1): the levels of the class and path metrics (S89-S92 quote it).
SkillModel.METRIC_LEVELS = { 20, 45, 70, 100 }

-- S86 class bases of the path ratios (SkillModel.baseFor): the S85 base with the weapon of the class measurement
-- (ROZWOJ 10.6 two-handed axe, 12.7 staff, 9.6 mace + shield; the Hunter: the compared build's weapon with a quiver,
-- 11.6) and the breakpoints of the compared build on the shared skills. `sameWeapon` = the weapon of the build.
SkillModel.BASES = {
	Warrior = { weapon = { main = "axe2h" }, source = "ROZWOJ 10.6" },
	Hunter = { sameWeapon = true, offhand = "quiver", source = "ROZWOJ 11.6" },
	Mage = { weapon = { main = "staff" }, source = "ROZWOJ 12.7" },
	Cleric = { weapon = { main = "mace1h", offhand = "shield" }, source = "ROZWOJ 9.6" },
} :: { [string]: any }

-- S86 (E1): path targets as test data rows (report only; S89 asserts the Cleric and the Warrior, S90 the Hunter and
-- the Mage, S92-S94 the regions). `metric` names a function of SkillModel.TARGET_METRICS; `build` is the S85 key, with
-- `weapon` a variant (SkillModel.withWeapon); `bands` = a band per level; `project` = the number of the ROZWOJ table
-- for the same build and level (D10); `heavy` rows (R4-R6) only in the report. Levels 45 / 70 / 100 unless the row
-- says otherwise; every row is also computed at 20: S91 asserts the rows that are targets of the 1-20 table
-- (Balance.S91.pathRows: T-SK3, solo pace of support and tank paths), the rest is printed (bands of 45-100).
export type PathTarget = {
	id: string,
	classId: string,
	path: string,
	metric: string,
	build: string,
	weapon: { main: string, offhand: string? }?,
	levels: { number },
	low: number?,
	high: number?,
	bands: { [number]: { number } }?,
	source: string,
	note: string?,
	project: { [number]: number }?,
	n: number?, -- destroyer.clear: monsters in the group
	heavy: boolean?,
	-- S89 (F1): `report` = who asserts the row instead (the row is only printed); `reportAt` = only these levels are
	-- printed (F4); `skill` / `at` / `choice` name an R4 option; `noL20` = no print at 20 (R4-R6)
	report: string?,
	reportAt: { number }?,
	skill: string?,
	at: number?,
	choice: string?,
	noL20: boolean?,
	cap: string?, -- S90: hunter.dexCaps, which cap ("crit", "speed", "dodge")
}

local L45 = { 45, 70, 100 }
local L20 = { 20, 45, 70, 100 }
local QUIVER = "quiver"

local function target(
	id: string,
	classId: string,
	path: string,
	metric: string,
	build: string,
	levels: { number },
	low: number?,
	high: number?,
	source: string,
	extra: { [string]: any }?
): PathTarget
	local row: any = {
		id = id,
		classId = classId,
		path = path,
		metric = metric,
		build = build,
		levels = levels,
		low = low,
		high = high,
		source = source,
	}
	for k, v in extra or {} do
		row[k] = v
	end
	return row :: PathTarget
end

-- S89 (F1): the classes whose rows (above 20) balance.spec asserted (PATHS_TUNED). S94 (L3): all four, switch removed.

local MAGE_GAIN = { [45] = { 1.20, 1.30 }, [70] = { 1.30, 1.40 }, [100] = { 1.35, 1.45 } } -- ROZWOJ 12.7

SkillModel.PATH_TARGETS = {
	-- Warrior (ROZWOJ 10.6)
	target(
		"berserker.base",
		"Warrior",
		"berserker",
		"single60/base",
		"berserker.fury",
		L45,
		1.25,
		1.35,
		"ROZWOJ 10.6",
		{
			project = { [20] = 1.12, [45] = 1.25, [70] = 1.30, [100] = 1.37 },
		}
	),
	target(
		"guardian.dps",
		"Warrior",
		"guardian",
		"single60/fury",
		"guardian.defender",
		L45,
		0.60,
		0.75,
		"ROZWOJ 10.6",
		{
			project = { [20] = 0.80, [45] = 0.72, [70] = 0.70, [100] = 0.67 },
			-- S89: poza zasięgiem dźwigni S89: 0.45-0.48 (plan i rzędy 1-3, DECYZJE S89)
			report = "właściciel (F4)",
		}
	),
	target("guardian.ehp", "Warrior", "guardian", "ehp/fury", "guardian.defender", L45, 1.60, 1.80, "ROZWOJ 10.6", {
		note = "3 wrogów w 10 st.",
		project = { [45] = 1.57, [70] = 1.57, [100] = 1.8 },
	}),
	target(
		"guardian.ehpRed",
		"Warrior",
		"guardian",
		"ehpRed/fury",
		"guardian.defender",
		L45,
		1.30,
		1.50,
		"ROZWOJ 10.6"
	),
	target("guardian.group", "Warrior", "guardian", "group/fury", "guardian.loner", L20, 0.55, nil, "ROZWOJ 10.6", {
		project = { [20] = 0.83, [45] = 0.78, [70] = 0.83, [100] = 0.61 },
	}),
	target(
		"guardian.group",
		"Warrior",
		"standard",
		"group/fury",
		"standard.commander",
		L20,
		0.55,
		nil,
		"ROZWOJ 10.6",
		{
			note = "10.6 stawia ten próg Strażnikowi i Chorążemu",
			project = { [20] = 0.93, [45] = 0.82, [70] = 0.74, [100] = 0.73 },
		}
	),
	target(
		"standard.support",
		"Warrior",
		"standard",
		"support",
		"standard.commander",
		L45,
		4.90,
		5.10,
		"ROZWOJ 7.5, 10.6",
		{
			weapon = { main = "sword1h", offhand = "shield" },
			project = { [45] = 4.9, [70] = 5.0, [100] = 5.08 },
			-- S89: na 45 tylko druk (C2); na 70 poza zasięgiem dźwigni S89: 4.71 (Sztandar z `opener`, DECYZJE S89)
			reportAt = { 45, 70 },
		}
	),
	target(
		"standard.support",
		"Warrior",
		"standard",
		"support",
		"standard.commander",
		L45,
		4.90,
		5.10,
		"ROZWOJ 7.5, 10.6",
		{
			weapon = { main = "saber1h", offhand = "shield" },
			project = { [45] = 4.9, [70] = 5.0, [100] = 5.08 },
			-- S89: na 45 tylko druk (C2); na 70 poza zasięgiem dźwigni S89: 4.73 (Sztandar z `opener`, DECYZJE S89)
			reportAt = { 45, 70 },
		}
	),
	target("standard.S", "Warrior", "standard", "S", "standard.commander", L45, 0.55, nil, "ROZWOJ 7.5", {
		project = { [100] = 0.74 },
	}),
	target(
		"warrior.solo",
		"Warrior",
		"guardian",
		"pace/fury",
		"guardian.loner",
		L20,
		nil,
		1.50,
		"ROZWOJ 1 pkt 27, 7.5, 10.6",
		{
			project = { [20] = 1.12, [45] = 1.16, [70] = 1.12, [100] = 1.37 },
		}
	),
	target(
		"warrior.solo",
		"Warrior",
		"standard",
		"pace/fury",
		"standard.commander",
		L20,
		nil,
		1.50,
		"ROZWOJ 1 pkt 27, 7.5, 10.6",
		{
			project = { [20] = 1.04, [45] = 1.12, [70] = 1.20, [100] = 1.21 },
		}
	),
	-- Cleric (ROZWOJ 9.0, 9.6)
	target(
		"inquisitor.ratio",
		"Cleric",
		"inquisitor",
		"single60/fury",
		"inquisitor.solo",
		L45,
		nil,
		nil,
		"ROZWOJ 9.0 pkt 5, 9.6",
		{
			bands = { [45] = { 0.80, 0.86 }, [70] = { 0.85, 0.91 }, [100] = { 0.87, 0.93 } },
			project = { [20] = 0.78, [45] = 0.83, [70] = 0.88, [100] = 0.90 },
		}
	),
	target(
		"inquisitor.hp",
		"Cleric",
		"inquisitor",
		"maxHp/fury",
		"inquisitor.solo",
		L45,
		1.30,
		1.40,
		"ROZWOJ 9.0 pkt 5, 9.6"
	),
	target("healer.dps", "Cleric", "healer", "single60/fury", "healer.dungeon", L45, 0.45, 0.54, "ROZWOJ 9.6", {
		note = "berło + tarcza",
		project = { [20] = 0.54, [45] = 0.46, [70] = 0.45, [100] = 0.48 },
		report = "tylko raport (healer.S, tempo solo)",
	}),
	target("healer.dps", "Cleric", "healer", "single60/fury", "healer.solo", L45, 0.58, 0.66, "ROZWOJ 9.6", {
		note = "kostur",
		project = { [20] = 0.66, [45] = 0.58, [70] = 0.58, [100] = 0.61 },
		report = "tylko raport (healer.S, tempo solo)",
	}),
	-- S89 (F2, ROZWOJ 7.5, 9.6): S of the Healer: "Samotny" with the holy staff / "Inkwizytor solo", 1 target 60 s
	target("healer.S", "Cleric", "healer", "single60/inquisitor", "healer.solo", L45, 0.55, nil, "ROZWOJ 7.5, 9.6", {
		note = "kostur",
	}),
	target("fortune.dps", "Cleric", "fortune", "single60/fury", "fortune.plunder", L45, 0.49, 0.55, "ROZWOJ 9.6", {
		project = { [20] = 0.55, [45] = 0.49, [70] = 0.50, [100] = 0.55 },
		report = "tylko raport (tempo solo)",
	}),
	target("healer.tsk5", "Cleric", "healer", "tsk5", "healer.dungeon", L20, 0.25, 0.35, "ROZWOJ 7.5, 9.6", {
		note = "tank Obrońca",
	}),
	target(
		"fortune.healLess",
		"Cleric",
		"fortune",
		"healLess",
		"fortune.plunder",
		L45,
		0.20,
		0.25,
		"ROZWOJ 9.0 pkt 3, 9.4, 9.6",
		{
			project = { [45] = 0.21, [70] = 0.21, [100] = 0.21 },
			-- S89: na 45 poza zasięgiem dźwigni S89: 0.085 (na 45 Uzdrowiciel ma z leczenia tylko rzędy 1-3);
			-- S91: rzędy 1-3 Uzdrowiciela bez zmian (Błogosławione Dłonie globalne, T-SK5 na 45-100 w paśmie S87)
			reportAt = { 45 },
		}
	),
	target(
		"cleric.solo",
		"Cleric",
		"healer",
		"grind/inquisitor",
		"healer.solo",
		L45,
		nil,
		1.50,
		"ROZWOJ 7.5, 9.0, 9.6",
		{
			note = "9.0 mówi 1,35",
			project = { [20] = 0.92, [45] = 1.06, [70] = 1.16, [100] = 1.07 },
		}
	),
	target(
		"cleric.solo",
		"Cleric",
		"fortune",
		"grind/inquisitor",
		"fortune.plunder",
		L45,
		nil,
		1.50,
		"ROZWOJ 7.5, 9.0, 9.6",
		{
			note = "9.0 mówi 1,35",
			project = { [20] = 1.11, [45] = 1.14, [70] = 1.35, [100] = 1.11 },
		}
	),
	-- S94 (L3): poza zasięgiem dźwigni S94: T-SK6 of the bosses 45-100 is a region row (R.<map>.<boss>.tsk6): Morvane
	-- asserted at <= 2.7 (S92), Azgor 12.8 and Vaelgrath 15.9 unfinished (S93 / S94, the owner's decision)
	target("healer.tsk6", "Cleric", "healer", "tsk6", "healer.dungeon", L45, 1.0, 2.0, "ROZWOJ 0, 7.5, 9.6", {
		note = "tank Obrońca, drużyna S92",
		report = "poza zasięgiem dźwigni S94: T-SK6 Azgora 12,8 i Vaelgratha 15,9 (decyzja właściciela; wiersze regionów)",
	}),
	-- Hunter (ROZWOJ 11.6)
	target(
		"marksman.base",
		"Hunter",
		"marksman",
		"single60/base",
		"marksman.kingslayer",
		L45,
		1.25,
		1.35,
		"ROZWOJ 11.6",
		{
			weapon = { main = "heavycrossbow", offhand = QUIVER },
			project = { [20] = 1.16, [45] = 1.29, [70] = 1.37, [100] = 1.36 },
		}
	),
	target(
		"marksman.base",
		"Hunter",
		"marksman",
		"single60/base",
		"marksman.kingslayer",
		L45,
		1.25,
		1.35,
		"ROZWOJ 11.6",
		{
			weapon = { main = "longbow", offhand = QUIVER },
			project = { [20] = 1.15, [45] = 1.29, [70] = 1.36, [100] = 1.35 },
		}
	),
	target(
		"marksman.r7",
		"Hunter",
		"marksman",
		"single60/fury",
		"marksman.kingslayer",
		L45,
		1.15,
		1.35,
		"ROZWOJ 0, 11.6",
		{
			weapon = { main = "heavycrossbow", offhand = QUIVER },
			project = { [20] = 1.16, [45] = 1.29, [70] = 1.38, [100] = 1.35 },
		}
	),
	target(
		"marksman.r7",
		"Hunter",
		"marksman",
		"single60/fury",
		"marksman.kingslayer",
		L45,
		1.15,
		1.35,
		"ROZWOJ 0, 11.6",
		{
			weapon = { main = "longbow", offhand = QUIVER },
			project = { [20] = 1.15, [45] = 1.29, [70] = 1.37, [100] = 1.34 },
		}
	),
	target("trapper.aoe", "Hunter", "trapper", "aoe8/marksmanBest", "trapper.poacher", L45, 1.15, nil, "ROZWOJ 11.6", {
		weapon = { main = "crossbow", offhand = QUIVER },
		project = { [45] = 1.18, [70] = 1.11, [100] = 1.29 },
	}),
	target("trapper.aoe", "Hunter", "trapper", "aoe8/marksmanBest", "trapper.poacher", L45, 1.15, nil, "ROZWOJ 11.6", {
		weapon = { main = "bow", offhand = QUIVER },
		project = { [45] = 1.24, [70] = 1.17, [100] = 1.35 },
	}),
	target(
		"trapper.single",
		"Hunter",
		"trapper",
		"single60/base",
		"trapper.poacher",
		L45,
		1.05,
		1.15,
		"ROZWOJ 11.6, 15.4",
		{
			weapon = { main = "crossbow", offhand = QUIVER },
			note = "bez R7",
			project = { [20] = 0.98, [45] = 1.01, [70] = 1.05, [100] = 1.05 },
		}
	),
	target(
		"trapper.single",
		"Hunter",
		"trapper",
		"single60/base",
		"trapper.poacher",
		L45,
		1.05,
		1.15,
		"ROZWOJ 11.6, 15.4",
		{
			weapon = { main = "bow", offhand = QUIVER },
			note = "bez R7",
			project = { [20] = 1.02, [45] = 1.06, [70] = 1.09, [100] = 1.10 },
		}
	),
	target("scout.support", "Hunter", "scout", "support", "scout.partyHunter", L45, 4.90, 5.10, "ROZWOJ 7.5, 11.6", {
		weapon = { main = "bow", offhand = QUIVER },
		project = { [45] = 5.08, [70] = 5.10, [100] = 5.24 },
	}),
	target("scout.support", "Hunter", "scout", "support", "scout.partyHunter", L45, 4.90, 5.10, "ROZWOJ 7.5, 11.6", {
		weapon = { main = "shortbow", offhand = QUIVER },
		project = { [45] = 5.08, [70] = 5.10, [100] = 5.24 },
	}),
	target("scout.S", "Hunter", "scout", "S", "scout.partyHunter", L45, 0.55, nil, "ROZWOJ 7.5, 11.6", {
		weapon = { main = "bow", offhand = QUIVER },
		project = { [45] = 0.84, [70] = 0.83, [100] = 0.86 },
	}),
	target("scout.S", "Hunter", "scout", "S", "scout.partyHunter", L45, 0.55, nil, "ROZWOJ 7.5, 11.6", {
		weapon = { main = "shortbow", offhand = QUIVER },
	}),
	target(
		"scout.solo",
		"Hunter",
		"scout",
		"scoutPaceA",
		"scout.partyHunter",
		L20,
		nil,
		1.50,
		"ROZWOJ 1 pkt 27, 11.6",
		{
			weapon = { main = "bow", offhand = QUIVER },
			note = "(a) grupa 8 s",
			project = { [20] = 1.03, [45] = 1.23, [70] = 1.24, [100] = 1.33 },
		}
	),
	target(
		"scout.solo",
		"Hunter",
		"scout",
		"scoutPaceA",
		"scout.partyHunter",
		L20,
		nil,
		1.50,
		"ROZWOJ 1 pkt 27, 11.6",
		{
			weapon = { main = "shortbow", offhand = QUIVER },
			note = "(a) grupa 8 s",
			project = { [20] = 1.01, [45] = 1.21, [70] = 1.23, [100] = 1.32 },
		}
	),
	target(
		"scout.solo",
		"Hunter",
		"scout",
		"scoutPaceB",
		"scout.partyHunter",
		L20,
		nil,
		1.50,
		"ROZWOJ 1 pkt 27, 11.6",
		{
			weapon = { main = "bow", offhand = QUIVER },
			note = "(b) 3 potwory, które oddają",
		}
	),
	target(
		"scout.solo",
		"Hunter",
		"scout",
		"scoutPaceB",
		"scout.partyHunter",
		L20,
		nil,
		1.50,
		"ROZWOJ 1 pkt 27, 11.6",
		{
			weapon = { main = "shortbow", offhand = QUIVER },
			note = "(b) 3 potwory, które oddają",
		}
	),
	-- S90 (H1): R3 of the Trapper (area 3 targets 8 s / 1 target 8 s <= areaCap 2.0) with both weapons of the path
	target("trapper.r3", "Hunter", "trapper", "tsk3", "trapper.poacher", L45, nil, nil, "ROZWOJ 11.6", {
		weapon = { main = "crossbow", offhand = QUIVER },
	}),
	target("trapper.r3", "Hunter", "trapper", "tsk3", "trapper.poacher", L45, nil, nil, "ROZWOJ 11.6", {
		weapon = { main = "bow", offhand = QUIVER },
	}),
	-- Mage (ROZWOJ 8, 12.7)
	target(
		"destroyer.aoe",
		"Mage",
		"destroyer",
		"aoe60/base",
		"destroyer.destroyerExp",
		L45,
		nil,
		nil,
		"ROZWOJ 12.7",
		{
			bands = MAGE_GAIN,
			project = { [45] = 1.21, [70] = 1.38, [100] = 1.46 },
			-- S90: destroyer.aoe na 100 poza zasięgiem dźwigni S90: 1.455; Wir i Kataklizm z rangą 10 na 3 celach, a ich
			-- obniżka podnosi arcanist.vsDestroyer na 100 ponad 1.25 (DECYZJE S90)
			reportAt = { 100 },
		}
	),
	target(
		"destroyer.single",
		"Mage",
		"destroyer",
		"boss180/base",
		"destroyer.destroyerBoss",
		L45,
		1.05,
		1.20,
		"ROZWOJ 12.7",
		{
			project = { [20] = 0.98, [45] = 1.07, [70] = 1.14, [100] = 1.19 },
			-- S90: destroyer.single na 70 poza zasięgiem dźwigni S90: 1.038; build bossa na 70 ma Kataklizm na randze 3 i
			-- Burzę Meteorów bez 10B przy pełnym zużyciu many, a każda dźwignia na 70 rusza 45 albo 100 (DECYZJE S90)
			reportAt = { 70 },
		}
	),
	target(
		"destroyer.clear",
		"Mage",
		"destroyer",
		"clear/arcanistExp",
		"destroyer.destroyerExp",
		L45,
		nil,
		1.00,
		"ROZWOJ 12.7",
		{
			n = 2,
			note = "2 wrogów",
			-- S90: destroyer.clear poza zasięgiem dźwigni S90: Niszczyciel czyści 2-4 wrogów w 2,6-2,8 s niezależnie od
			-- liczby wrogów (próg pierwszych rzutów), Arkanista 2 wrogów w 1,3 s; Wir x2 daje 1,77 / 1,79 (2 wrogów, 70 / 100)
			-- i psuje destroyer.aoe, mage.tsk4 i arcanist.vsDestroyer (DECYZJE S90)
			report = "właściciel (H4)",
		}
	),
	target(
		"destroyer.clear",
		"Mage",
		"destroyer",
		"clear/arcanistExp",
		"destroyer.destroyerExp",
		L45,
		nil,
		1.00,
		"ROZWOJ 12.7",
		{
			n = 3,
			note = "3 wrogów",
			-- S90: destroyer.clear poza zasięgiem dźwigni S90: Niszczyciel czyści 2-4 wrogów w 2,6-2,8 s niezależnie od
			-- liczby wrogów (próg pierwszych rzutów), Arkanista 2 wrogów w 1,3 s; Wir x2 daje 1,77 / 1,79 (2 wrogów, 70 / 100)
			-- i psuje destroyer.aoe, mage.tsk4 i arcanist.vsDestroyer (DECYZJE S90)
			report = "właściciel (H4)",
		}
	),
	target(
		"destroyer.clear",
		"Mage",
		"destroyer",
		"clear/arcanistExp",
		"destroyer.destroyerExp",
		L45,
		nil,
		1.00,
		"ROZWOJ 12.7",
		{
			n = 4,
			note = "4 wrogów",
			-- S90: destroyer.clear poza zasięgiem dźwigni S90: Niszczyciel czyści 2-4 wrogów w 2,6-2,8 s niezależnie od
			-- liczby wrogów (próg pierwszych rzutów), Arkanista 2 wrogów w 1,3 s; Wir x2 daje 1,77 / 1,79 (2 wrogów, 70 / 100)
			-- i psuje destroyer.aoe, mage.tsk4 i arcanist.vsDestroyer (DECYZJE S90)
			report = "właściciel (H4)",
		}
	),
	target(
		"arcanist.single",
		"Mage",
		"arcanist",
		"boss180/base",
		"arcanist.arcanistBoss",
		L45,
		nil,
		nil,
		"ROZWOJ 12.7",
		{
			bands = MAGE_GAIN,
			project = { [20] = 1.02, [45] = 1.23, [70] = 1.36, [100] = 1.47 },
		}
	),
	target(
		"arcanist.vsDestroyer",
		"Mage",
		"arcanist",
		"boss180/destroyerBoss",
		"arcanist.arcanistBoss",
		L45,
		1.15,
		1.25,
		"ROZWOJ 12.7",
		{
			project = { [20] = 1.04, [45] = 1.15, [70] = 1.20, [100] = 1.24 },
			-- S90: arcanist.vsDestroyer na 70 poza zasięgiem dźwigni S90: 1.269 (ten sam dołek bossa Niszczyciela na 70)
			reportAt = { 70 },
		}
	),
	-- S90 (H1, DECYZJE): the four bands of ROZWOJ 12.0 / 12.7 instead of the S86 2.0-3.0 with variants >= 1.6
	target("mage.tsk4", "Mage", "destroyer", "tsk4", "destroyer.destroyerExp", L45, 2.0, 2.8, "ROZWOJ 8, 12.0, 12.7", {
		project = { [45] = 1.97, [70] = 2.48, [100] = 2.18 },
	}),
	target("mage.tsk4", "Mage", "arcanist", "tsk4", "arcanist.arcanistBoss", L45, 2.0, 2.4, "ROZWOJ 8, 12.0, 12.7", {
		project = { [45] = 2.02, [70] = 2.32, [100] = 2.40 },
	}),
	target("mage.tsk4", "Mage", "destroyer", "tsk4", "destroyer.destroyerBoss", L45, 1.6, 2.8, "ROZWOJ 12.0, 12.7", {
		note = "wariant: Oszczędny Splot",
		project = { [45] = 1.64, [70] = 2.11, [100] = 1.82 },
	}),
	-- S90: Przeciążenie na 45 i 100 poza zasięgiem dźwigni S90: 2.84 / 2.85. S91: overloadCost 10/20/30 -> 9/18/27
	-- (węzeł rzędu 3, lista S90) daje 2.77 / 2.71 / 2.78, więc wiersz asertuje na 45 / 70 / 100
	target("mage.tsk4", "Mage", "arcanist", "tsk4", "arcanist.arcanistOverload", L45, 2.6, 2.8, "ROZWOJ 12.0, 12.7", {
		note = "wariant: Przeciążenie",
		project = { [45] = 2.62, [70] = 2.75, [100] = 2.79 },
	}),
	-- S90 (H1): T-SK3 of the Mage path builds against their areaCap (Destroyer 3.0, Arcanist 2.0; SkillModel.bandOf)
	target("mage.tsk3", "Mage", "destroyer", "tsk3", "destroyer.destroyerExp", L45, nil, nil, "ROZWOJ 8, 12.7, 15.5.3"),
	target(
		"mage.tsk3",
		"Mage",
		"destroyer",
		"tsk3",
		"destroyer.destroyerBoss",
		L45,
		nil,
		nil,
		"ROZWOJ 8, 12.7, 15.5.3"
	),
	target("mage.tsk3", "Mage", "arcanist", "tsk3", "arcanist.arcanistBoss", L45, nil, nil, "ROZWOJ 8, 12.7, 15.5.3"),
	target(
		"mage.tsk3",
		"Mage",
		"arcanist",
		"tsk3",
		"arcanist.arcanistOverload",
		L45,
		nil,
		nil,
		"ROZWOJ 8, 12.7, 15.5.3"
	),
	-- every class
	-- S89 (F2): the upper band is max(2.0, 1.15 x R1_L20[build]) (SkillModel.bandOf)
	target("all.r1", "Warrior", "berserker", "r1", "berserker.fury", L45, 1.6, 2.0, "ROZWOJ 0"),
	-- S89: all.r1 Inkwizytora poza zasięgiem dźwigni S89: 4.4-5.7 przy stosunku 0.84-0.93 Furii (DECYZJE S89)
	target("all.r1", "Cleric", "inquisitor", "r1", "inquisitor.solo", L45, 1.6, 2.0, "ROZWOJ 0", {
		report = "właściciel (F4)",
	}),
	-- S90: all.r1 Strzelca i Trapera z Kuszą poza zasięgiem dźwigni S90: 2.80-2.97 przy górze 2.78-2.86 (R1 bazy Łowcy
	-- na 20. to 2.42-2.49, a Strzelec x baza >= 1.25 i R7 1.15-1.35 wymagają mocnej bazy; DECYZJE S90).
	-- S91: R1 na 45-100 to wartości rang powyżej 20 (S90), poza zasięgiem dźwigni S91; R1 na 20 asertuje blok S91
	target("all.r1", "Hunter", "marksman", "r1", "marksman.kingslayer", L45, 1.6, 2.0, "ROZWOJ 0", {
		report = "właściciel (S90, S91)",
	}),
	target("all.r1", "Hunter", "marksman", "r1", "marksman.kingslayer", L45, 1.6, 2.0, "ROZWOJ 0", {
		weapon = { main = "longbow", offhand = QUIVER },
		report = "właściciel (S90, S91)",
	}),
	target("all.r1", "Hunter", "trapper", "r1", "trapper.poacher", L45, 1.6, 2.0, "ROZWOJ 0", {
		report = "właściciel (S90, S91)",
	}),
	target("all.r1", "Hunter", "trapper", "r1", "trapper.poacher", L45, 1.6, 2.0, "ROZWOJ 0", {
		weapon = { main = "bow", offhand = QUIVER },
	}),
	-- S90: all.r1 Maga poza zasięgiem dźwigni S90: 3.3-3.9 (exp), 4.3-5.0 (boss) przy górze 3.37-3.66; R1 buildów Maga na 20.
	-- to 2.9-3.2, a pasma 12.7 wymagają jej pełnych umiejętności (Pocisk Ognia to ok. połowa obrażeń; DECYZJE S90).
	-- S91: R1 na 45-100 to wartości rang powyżej 20 (S90), poza zasięgiem dźwigni S91; R1 na 20 asertuje blok S91
	target(
		"all.r1",
		"Mage",
		"destroyer",
		"r1",
		"destroyer.destroyerExp",
		L45,
		1.6,
		2.0,
		"ROZWOJ 0",
		{ report = "właściciel (S90, S91)" }
	),
	target(
		"all.r1",
		"Mage",
		"destroyer",
		"r1",
		"destroyer.destroyerBoss",
		L45,
		1.6,
		2.0,
		"ROZWOJ 0",
		{ report = "właściciel (S90, S91)" }
	),
	target("all.r1", "Mage", "arcanist", "r1", "arcanist.arcanistBoss", L45, 1.6, 2.0, "ROZWOJ 0", {
		report = "właściciel (S90, S91)",
	}),
	-- S94 (L3): poza zasięgiem dźwigni S94: every support / tank path wins the Elite II solo with potions on the real
	-- spawners of every region (S92, S93, S94 support rows in the report); the Elite II curves hold duo <= 150 %
	target("support.elites", "Warrior", "guardian", "elites", "guardian.loner", L45, 1, 1, "ROZWOJ 7.5, 10.6", {
		report = "poza zasięgiem dźwigni S94: wygrywa Elitę II solo z miksturami (wiersze regionów R.<map>.support.*)",
	}),
	target("support.elites", "Warrior", "standard", "elites", "standard.commander", L45, 1, 1, "ROZWOJ 7.5, 10.6", {
		report = "poza zasięgiem dźwigni S94: wygrywa Elitę II solo z miksturami (wiersze regionów R.<map>.support.*)",
	}),
	target("support.elites", "Cleric", "healer", "elites", "healer.solo", L45, 1, 1, "ROZWOJ 7.5, 9.6", {
		report = "poza zasięgiem dźwigni S94: wygrywa Elitę II solo z miksturami (wiersze regionów R.<map>.support.*)",
	}),
	target("support.elites", "Cleric", "fortune", "elites", "fortune.plunder", L45, 1, 1, "ROZWOJ 7.5, 9.6", {
		report = "poza zasięgiem dźwigni S94: wygrywa Elitę II solo z miksturami (wiersze regionów R.<map>.support.*)",
	}),
	target("support.elites", "Hunter", "scout", "elites", "scout.partyHunter", L45, 1, 1, "ROZWOJ 7.5, 11.6", {
		report = "poza zasięgiem dźwigni S94: wygrywa Elitę II solo z miksturami (wiersze regionów R.<map>.support.*)",
	}),
} :: { PathTarget }

-- all.tsk3 (ROZWOJ 0, 8, 15.5.3): T-SK3 of every build and base against its areaCap; R4 / R5 / R6 (ROZWOJ 0, 2.3,
-- 2.7): the report rows of SkillModel.r4Rows / r5Rows / r6Rows (heavy: never in balance.spec).
for _, classId in B.CLASSES do
	for _, key in
		({
			Warrior = {
				"base",
				"guardian.defender",
				"guardian.loner",
				"berserker.fury",
				"berserker.butcher",
				"standard.commander",
				"standard.warden",
			},
			Hunter = {
				"base",
				"marksman.kingslayer",
				"marksman.eliteHunter",
				"trapper.poisoner",
				"scout.partyHunter",
				"scout.tracker",
			},
			-- S90: trapper.poacher (trapper.r3) and the Mage path builds (mage.tsk3) are asserted under their own ids
			Mage = { "base" },
			Cleric = {
				"base",
				"healer.dungeon",
				"healer.solo",
				"fortune.plunder",
				"inquisitor.solo",
				"inquisitor.bulwark",
			},
		} :: any)[classId] :: { string }
	do
		local path = string.match(key, "^(.-)%.") or "base"
		table.insert(
			SkillModel.PATH_TARGETS,
			-- S94 (L3): only printed (no band): T-SK3 against areaCap is asserted by the region guards
			-- (R.<map>.guard.tsk3.*, S92-S94)
			target("all.tsk3", classId, path, "tsk3", key, L45, nil, nil, "ROZWOJ 0, 8, 15.5.3", {
				report = "tylko raport: T-SK3 asertują strażniki regionów (R.<map>.guard.tsk3.*)",
			})
		)
	end
end
-- S90 (C4, ROZWOJ 8, 11.6, 15.4): every Hunter reference build's crit (with Draw a Bead), attack speed and dodge before
-- the Data/Stats caps, minus the cap (SkillModel.dexCaps): no node wasted above a cap (crit and dodge <= 0.5 points,
-- speed <= 0.01).
for _, key in
	{
		"marksman.kingslayer",
		"marksman.eliteHunter",
		"trapper.poacher",
		"trapper.poisoner",
		"scout.partyHunter",
		"scout.tracker",
	}
do
	local path = string.match(key, "^(.-)%.") :: string
	for _, spec in { { "crit", 0.5 }, { "speed", 0.01 }, { "dodge", 0.5 } } :: { { any } } do
		table.insert(
			SkillModel.PATH_TARGETS,
			target("hunter.dexCaps", "Hunter", path, "dexCap", key, L45, nil, spec[2], "ROZWOJ 8, 11.6, 15.4", {
				cap = spec[1],
				note = `{spec[1]} ponad limit`,
			})
		)
	end
end
for _, id in { "r4", "r5", "r6" } do
	table.insert(
		SkillModel.PATH_TARGETS,
		target(id, "Warrior", "all", id, "berserker.fury", { 45, 70, 100 }, nil, nil, "ROZWOJ 0, 2.3, 2.7", {
			heavy = true,
			note = "tabele R4 / R5 / R6 raportu",
		})
	)
end

-- S89 (F2): R1 of "Furia" and "Inkwizytor solo" trimmed to L20 (the S89 start table, A5, to 0.01); all.r1's upper band
-- is max(2.0, 1.15 x R1_L20[build]) (balance plan D1: T-SK1 <= 1.15 x own L20). S90 adds the Hunter and Mage builds.
-- S90 (H1): the Hunter per weapon of the measurement (key with "@weapon" for a variant), the Mage builds; the S90 start
-- table at L20 before any S90 change (the crossbow at 1.45).
-- S91 (E7): rows that only print at 45-100 take R1 at L20 after the 1-20 retune; asserted rows keep the S89 / S90
-- value (a lower bound there would fail the frozen 45-100 paths).
SkillModel.R1_L20 = {
	["berserker.fury"] = 2.27, -- S91: granica R1 z L20 sprzed S91, ścieżki nastrojone na nią w S89 / S90 (S91: 2.14)
	["inquisitor.solo"] = 2.06, -- S91: R1 na L20 po przestrojeniu 1–20
	["marksman.kingslayer"] = 2.28, -- heavy crossbow; S91: R1 na L20 po przestrojeniu 1–20
	["marksman.kingslayer@longbow+quiver"] = 2.29, -- S91: R1 na L20 po przestrojeniu 1–20
	["trapper.poacher"] = 2.22, -- crossbow; S91: R1 na L20 po przestrojeniu 1–20
	["trapper.poacher@bow+quiver"] = 2.44, -- S91: granica R1 z L20 sprzed S91, ścieżki nastrojone na nią w S89 / S90 (S91: 2.23)
	["destroyer.destroyerExp"] = 2.47, -- S91: R1 na L20 po przestrojeniu 1–20
	["destroyer.destroyerBoss"] = 2.66, -- S91: R1 na L20 po przestrojeniu 1–20
	["arcanist.arcanistBoss"] = 2.58, -- S91: R1 na L20 po przestrojeniu 1–20
} :: { [string]: number }

-- S89 (E1, DECYZJE): R4 bands of the test (ROZWOJ 0 "ok. +10-15% / +20-25%"); A and B both with a value: |A - B| <= 0.05.
SkillModel.R4_BANDS = { [5] = { 0.08, 0.17 }, [10] = { 0.17, 0.28 } }
SkillModel.R4_DIFF = 0.05
SkillModel.R4_CASTS = 12 -- S90: a cooldown option's R4 window covers at least 12 cooldowns (SkillModel.optionGain)
-- S90: skills measured in the build's whole rotation (their value comes from the other spells)
SkillModel.R4_ROTATION = { arcaneDischarge = true } :: { [string]: boolean }

-- S89 (E1): breakpoint options with a rank level above 20 printed without an assertion: control, movement and geometry
-- (free utility, ROZWOJ 2.7) and options without a value in the role SkillModel.optionGain measures (S86).
SkillModel.R4_UTILITY = {
	["mightyStrike:10a"] = "obszar przy roli 1 cel (bez metryki)",
	["charge:10a"] = "ogłuszenie (kontrola)",
	["charge:10b"] = "obszar przy roli 1 cel (bez metryki)",
	["bladeWhirl:5a"] = "ruch w trakcie rzutu",
	["bladeWhirl:5b"] = "kradzież życia (podtrzymanie, bez metryki w roli)",
	["bladeWhirl:10a"] = "przyciąganie (kontrola)",
	["taunt:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["taunt:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["taunt:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["taunt:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["bloodlust:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["bloodlust:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["bloodlust:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["bloodlust:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["earthquake:5b"] = "przyciąganie (kontrola)",
	["intercept:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["intercept:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["intercept:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["intercept:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["lastBastion:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["lastBastion:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["lastBastion:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["lastBastion:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["shieldWall:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["shieldWall:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["shieldWall:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["shieldWall:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["cleave:5a"] = "geometria albo czas kontroli",
	["cleave:10b"] = "kradzież życia (podtrzymanie, bez metryki w roli)",
	["rend:5b"] = "kradzież życia (podtrzymanie, bez metryki w roli)",
	["rend:10b"] = "obszar przy roli 1 cel (bez metryki)",
	["titansWrath:5a"] = "geometria albo czas kontroli",
	["titansWrath:10a"] = "ogłuszenie (kontrola)",
	["carnage:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["carnage:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["carnage:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["carnage:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["battleCry:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["battleCry:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["battleCry:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["battleCry:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["warBanner:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["warBanner:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["warBanner:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["warBanner:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["crushingBlow:5a"] = "kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)",
	["crushingBlow:10a"] = "obszar przy roli 1 cel (bez metryki)",
	["advanceOrder:5a"] = "geometria albo czas kontroli",
	["advanceOrder:5b"] = "przyciąganie (kontrola)",
	["advanceOrder:10b"] = "oczyszczenie",
	["holyStrike:10a"] = "kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)",
	["holyStrike:10b"] = "leczenie sojusznika z obrażeń (bez metryki w roli 1 cel)",
	["heal:10a"] = "nadmiar w tarczę (bez nadleczenia w modelu)",
	["heal:10b"] = "przeskok na innych (bez metryki na jednym tanku)",
	["radiance:5a"] = "geometria albo czas kontroli",
	["radiance:5b"] = "przyciąganie (kontrola)",
	["radiance:10a"] = "leczenie sojuszników z obrażeń (bez metryki w roli 1 cel)",
	["circleOfLight:5a"] = "oczyszczenie",
	["circleOfLight:5b"] = "geometria albo czas kontroli",
	["circleOfLight:10a"] = "redukcja obrażeń drużyny (bez metryki w roli)",
	["shieldOfFaith:5b"] = "oczyszczenie",
	["shieldOfFaith:10a"] = "drugi cel (bez metryki na jednym tanku)",
	["judgement:5a"] = "kradzież życia (podtrzymanie, bez metryki w roli)",
	["judgement:5b"] = "ogłuszenie (kontrola)",
	["judgement:10a"] = "kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)",
	["renew:5b"] = "drugi cel (bez metryki na jednym tanku)",
	["renew:10a"] = "oczyszczenie",
	["sanctuary:5a"] = "geometria albo czas kontroli",
	["sanctuary:5b"] = "oczyszczenie",
	["sanctuary:10b"] = "redukcja obrażeń drużyny (bez metryki w roli)",
	["divineIntervention:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["divineIntervention:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["divineIntervention:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["divineIntervention:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["guardianAngel:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["guardianAngel:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["guardianAngel:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["guardianAngel:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["resurrection:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["resurrection:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["resurrection:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["resurrection:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["fortuneDice:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["fortuneDice:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["fortuneDice:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["fortuneDice:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["prayer:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["prayer:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["prayer:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["prayer:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["wheelOfFortune:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["wheelOfFortune:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["wheelOfFortune:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["wheelOfFortune:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["purify:5a"] = "nadmiar w tarczę (bez nadleczenia w modelu)",
	["purify:5b"] = "obszar przy roli leczenia (bez metryki)",
	["purify:10a"] = "drugi cel (bez metryki na jednym tanku)",
	["brandOfLight:5b"] = "obszar przy roli 1 cel (bez metryki)",
	["brandOfLight:10a"] = "kradzież życia (podtrzymanie, bez metryki w roli)",
	["brandOfLight:10b"] = "kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)",
	["auraOfEndurance:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["auraOfEndurance:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["auraOfEndurance:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["auraOfEndurance:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["hammerOfHeaven:5a"] = "geometria albo czas kontroli",
	["hammerOfHeaven:10a"] = "geometria albo czas kontroli",
	["advanceOrder:10a"] = "krytyk sojuszników: wartość w B Chorążego, nie w obrażeniach Rozkazu",
	-- S90: the Hunter and the Mage
	["aimedShot:10b"] = "kradzież życia (podtrzymanie, bez metryki w roli)",
	["doubleShot:10a"] = "spowolnienie (kontrola)",
	["disengage:5a"] = "spowolnienie (kontrola)",
	["disengage:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["disengage:10a"] = "obrażenia następnego strzału: Odskok poza rotacją buildów (0 w DPS Strzelca, S90)",
	["disengage:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["arrowRain:5a"] = "geometria albo czas kontroli",
	["arrowRain:10a"] = "spowolnienie (kontrola)",
	["volley:10a"] = "geometria albo czas kontroli",
	["piercingArrow:5a"] = "geometria albo czas kontroli",
	["piercingArrow:10a"] = "odrzucenie (kontrola)",
	["drawBead:5a"] = "wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)",
	["drawBead:5b"] = "wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)",
	["drawBead:10a"] = "wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)",
	["drawBead:10b"] = "wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)",
	["stormArrow:5a"] = "geometria albo czas kontroli",
	["stormArrow:10a"] = "ogłuszenie (kontrola)",
	["frostTrap:5a"] = "geometria albo czas kontroli",
	["frostTrap:10a"] = "zamrożenie (kontrola)",
	["venomSnare:5a"] = "geometria albo czas kontroli",
	["venomSnare:5b"] = "przyciąganie (kontrola)",
	["camouflage:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["camouflage:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["camouflage:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["camouflage:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["snarefield:5a"] = "geometria albo czas kontroli",
	["snarefield:5b"] = "kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)",
	["snarefield:10b"] = "przyciąganie (kontrola)",
	["falcon:5b"] = "spowolnienie (kontrola)",
	["huntersMark:5a"] = "osłabienie wroga: wartość w B Zwiadowcy (wiersz scout.support)",
	["huntersMark:5b"] = "osłabienie wroga: wartość w B Zwiadowcy (wiersz scout.support)",
	["huntersMark:10a"] = "spowolnienie (kontrola)",
	["huntersMark:10b"] = "osłabienie wroga: wartość w B Zwiadowcy (wiersz scout.support)",
	["drive:5a"] = "geometria albo czas kontroli",
	["drive:10b"] = "unieruchomienie (kontrola)",
	["iceShard:5a"] = "zamrożenie (kontrola)",
	["chainLightning:5a"] = "dodatkowe skoki: wartość dopiero przy więcej niż 3 wrogach (pomiar na 3 manekinach)",
	["fireball:10a"] = "3 małe kule spadają 7 st. od środka, a manekiny stoją w środku (geometria, 0 w modelu)",
	["chainLightning:10a"] = "ogłuszenie (kontrola)",
	["blink:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["blink:5b"] = "geometria albo czas kontroli",
	["blink:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["blink:10b"] = "spowolnienie (kontrola)",
	["frostNova:5a"] = "geometria albo czas kontroli",
	["frostNova:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["meteor:5a"] = "krótsze opóźnienie (geometria, bez wartości w 60 s)",
	["firewall:10a"] = "ogłuszenie (kontrola)",
	["elementalVortex:5a"] = "geometria albo czas kontroli",
	["elementalVortex:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["cataclysm:5a"] = "geometria albo czas kontroli",
	["manaShield:5a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["manaShield:5b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["manaShield:10a"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["manaShield:10b"] = "wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)",
	["evocation:5a"] = "mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)",
	["evocation:5b"] = "mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)",
	["evocation:10a"] = "mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)",
	["evocation:10b"] = "mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)",
	["arcaneTorrent:5b"] = "ruch w trakcie kanału",
	-- S91: options of rank 5 reached by 20 (ranks 5 at 17 / 19)
	["mightyStrike:5a"] = "odrzucenie (kontrola)",
	["charge:5a"] = "zasięg doskoku (geometria)",
	["heal:5a"] = "drugi cel (bez metryki na jednym tanku)",
	["heal:5b"] = "leczenie siebie przy rzucie (bez metryki na tanku)",
} :: { [string]: string }

-- S89 (F4): measured options a single number cannot bring into the band (printed; DECYZJE S89, list for the owner).
SkillModel.R4_REPORT = {
	["cleave:5b"] = "synergia z 10A (3 stosy krwawienia): 0,12 na 45, 0,25 od 70; jedna liczba nie mieści obu",
	["renew:5a"] = "dłuższa Odnowa rzucana na odnowieniu traci tyknięcia (odświeżenie bez reszty): -0,29",
	-- S90 (G1, H4)
	["falcon:5a"] = "z Królewskim Sokołem (od 60.) ptak zostaje do końca walki, więc +4 s czasu nic nie daje (0 na 100)",
	["frostTrap:10b"] = "druga pułapka łapie 1 z 3 wrogów (groupSpread), a liczba sideł jest całkowita: 0,11–0,12",
	["arcaneDischarge:5b"] = "Wyładowanie czeka na 4 Ładunki, więc krótsze odnowienie nie zmienia rzutów w rotacji (0)",
	-- S91 (E5): rank 5 options reached by 20 out of reach of the S91 levers
	["holyStrike:5a"] = "S91: odprysk 40% na 3 manekinach daje 0,80; 6,5% (0,13) psuje cleric.solo Fortuny na 100 (1,36 → 1,59 > 1,50)",
	["aimedShot:5a"] = "S91: przebicie 50% daje 0,50; 13% (0,13) psuje trapper.aoe na 45 (1,15 → 1,11), scout.solo na 70 / 100 i r5a na 100",
	["doubleShot:5a"] = "S91: +1 strzała to +50% (liczba całkowita); zejście do 0,08-0,17 wymaga zmiany kształtu (słabsza trzecia strzała)",
} :: { [string]: string }
-- S91 (E5): the |A - B| row of an option pair that one number cannot hold at 20 and at 45-100 (printed)
SkillModel.R4_DIFF_REPORT = {
	["firebolt:5"] = "S91: przebicie 17% daje 0,165 na 20 i 0,083 na 45-100 (5B 0,16); 5B 0,88 -> 0,895 obniża T-SK4 Arkanisty na 55 pod 2,0 (G10)",
} :: { [string]: string }

-- S89 (E1): the build of a skill's R4 rows: path skills on their path's target build, base skills on the class's combat
-- path, Heal, Circle of Light, Shield of Faith on "Uzdrowiciel lochowy" and Taunt on "Obrońca".
SkillModel.R4_PATH_BUILDS = {
	guardian = "guardian.defender",
	berserker = "berserker.fury",
	standard = "standard.commander",
	healer = "healer.dungeon",
	fortune = "fortune.plunder",
	inquisitor = "inquisitor.solo",
	-- S90: the Hunter's and the Mage's paths on their target builds; the Mage's base skills on "Arkanista (boss)" (B
	-- is the boss option, ROZWOJ 12.2; the option role decides 1 or 3 dummies, SkillModel.optionGain)
	marksman = "marksman.kingslayer",
	trapper = "trapper.poacher",
	scout = "scout.partyHunter",
	destroyer = "destroyer.destroyerExp",
	arcanist = "arcanist.arcanistBoss",
} :: { [string]: string }
SkillModel.R4_CLASS_BUILDS = {
	Warrior = "berserker.fury",
	Cleric = "inquisitor.solo",
	Hunter = "marksman.kingslayer",
	Mage = "arcanist.arcanistBoss",
} :: { [string]: string }
SkillModel.R4_SUPPORT_BUILDS = {
	heal = "healer.dungeon",
	circleOfLight = "healer.dungeon",
	shieldOfFaith = "healer.dungeon",
	taunt = "guardian.defender",
} :: { [string]: string }

-- S89 (F2): r4.<skillId>.<rank> rows of every active Cleric and Warrior skill (both options; S91: the options of a rank
-- level <= 20 asserted too), the A - B difference when both have a value, r5 (the weapon spread of the combat paths)
-- and r6 (the value of a point in rows 4-11: the weakest and the strongest third against the mean, at 100).
do
	for _, classId in { "Warrior", "Cleric", "Hunter", "Mage" } do
		for _, def in SkillData.byClass[classId] do
			local d: any = def
			if d.type == "passive" or not d.breakpoints then
				continue
			end
			local key = SkillModel.R4_SUPPORT_BUILDS[d.id]
				or (if d.path then SkillModel.R4_PATH_BUILDS[d.path] else SkillModel.R4_CLASS_BUILDS[classId])
			local path = string.match(key, "^(.-)%.") :: string
			for _, at in Skills.BREAKPOINT_LEVELS do
				local rankLevel = Skills.rankLevel(d, at)
				local levels: { number } = {}
				for _, L in L45 do
					if L >= rankLevel then
						table.insert(levels, L)
					end
				end
				if #levels == 0 then
					continue
				end
				local band = SkillModel.R4_BANDS[at]
				local measured = 0
				for _, choice in { "a", "b" } do
					local k = `{d.id}:{at}{choice}`
					local why = SkillModel.R4_UTILITY[k] or SkillModel.R4_REPORT[k]
					-- S91 (E5): the options of a rank level <= 20 are asserted at 45 / 70 / 100 like the others
					local report = if SkillModel.R4_UTILITY[k]
						then "użyteczność (R4_UTILITY)"
						elseif SkillModel.R4_REPORT[k] then "właściciel (F4)"
						else nil
					if report == nil then
						measured += 1
					end
					table.insert(
						SkillModel.PATH_TARGETS,
						target(`r4.{d.id}.{at}`, classId, path, "r4", key, levels, band[1], band[2], "ROZWOJ 0, 2.7", {
							skill = d.id,
							at = at,
							choice = choice,
							noL20 = true,
							report = report,
							note = if why then `{choice}: {why}` else choice,
						})
					)
				end
				if measured == 2 then
					table.insert(
						SkillModel.PATH_TARGETS,
						target(
							`r4.{d.id}.{at}`,
							classId,
							path,
							"r4diff",
							key,
							levels,
							nil,
							SkillModel.R4_DIFF,
							"ROZWOJ 0, 2.7",
							{
								skill = d.id,
								at = at,
								noL20 = true,
								note = "|A − B|",
								report = if SkillModel.R4_DIFF_REPORT[`{d.id}:{at}`] then "właściciel (F4)" else nil,
							}
						)
					)
				end
			end
		end
	end
	table.insert(
		SkillModel.PATH_TARGETS,
		target("r5.berserker", "Warrior", "berserker", "r5", "berserker.fury", L45, nil, 0.10, "ROZWOJ 0 (E2)", {
			noL20 = true,
			note = "miecz, topór, młot, włócznia dwuręczne",
		})
	)
	table.insert(
		SkillModel.PATH_TARGETS,
		target("r5.inquisitor", "Cleric", "inquisitor", "r5", "inquisitor.solo", L45, nil, 0.10, "ROZWOJ 0 (E2)", {
			noL20 = true,
			note = "buława i korbacz z relikwią",
		})
	)
	-- S90 (G2): R5b of the Hunter's and the Mage's combat paths, every weapon type in the path's own metric
	-- (SkillModel.PATH_METRIC) within 10% of the mean of the types
	for _, spec in
		{
			{ "Hunter", "marksman", "marksman.kingslayer", "Łuk Długi, Ciężka Kusza (1 cel 60 s)" },
			{ "Hunter", "trapper", "trapper.poacher", "Kusza, Łuk (obszar 3 cele 8 s)" },
			{ "Mage", "destroyer", "destroyer.destroyerExp", "kostur, różdżka z kulą (obszar 3 cele 60 s)" },
			{ "Mage", "arcanist", "arcanist.arcanistBoss", "kostur runiczny, różdżka z księgą (boss 180 s)" },
		} :: { { any } }
	do
		table.insert(
			SkillModel.PATH_TARGETS,
			target(`r5.{spec[2]}`, spec[1], spec[2], "r5", spec[3], L45, nil, 0.10, "ROZWOJ 0 (G2)", {
				noL20 = true,
				note = spec[4],
			})
		)
	end
	-- S90 (G2, DECYZJE): R5a, the two combat paths of the Hunter and of the Mage: role gain x base (SkillModel.r5aGain)
	-- of each path within 10% of the pair's mean
	for _, spec in
		{
			{ "Hunter", "marksman", "marksman.kingslayer", "r5a.hunter", "Strzelec 1 cel / baza" },
			{ "Hunter", "trapper", "trapper.poacher", "r5a.hunter", "Traper obszar 8 s / baza" },
			{ "Mage", "destroyer", "destroyer.destroyerExp", "r5a.mage", "Niszczyciel obszar 60 s / baza" },
			{ "Mage", "arcanist", "arcanist.arcanistBoss", "r5a.mage", "Arkanista boss 180 s / baza" },
		} :: { { any } }
	do
		table.insert(
			SkillModel.PATH_TARGETS,
			target(spec[4], spec[1], spec[2], "r5a", spec[3], L45, nil, 0.10, "ROZWOJ 0 (G2)", {
				noL20 = true,
				note = spec[5],
			})
		)
	end
	-- S89 (F4, DECYZJE): the Berserker, the Inquisitor and the Healer only printed (their middle or last third holds
	-- skills and nodes without a value in the metric: area, sustain, rescue). S90: the five Hunter and Mage paths.
	for _, spec in
		{
			{ "Warrior", "berserker", "berserker.fury", "właściciel (F4)" },
			{ "Cleric", "inquisitor", "inquisitor.solo", "właściciel (F4)" },
			{ "Warrior", "standard", "standard.commander", nil },
			{ "Cleric", "healer", "healer.dungeon", "właściciel (F4)" },
			{ "Warrior", "guardian", "guardian.defender", "tylko raport (E3)" },
			{ "Cleric", "fortune", "fortune.plunder", "tylko raport (E3)" },
			-- S90: r6 Strzelca i Trapera poza zasięgiem dźwigni S90: Strzelec 0.20 (najsłabsza trzecia część), Traper 1.66
			-- (najmocniejsza). Pierwszy punkt rzędu 4 (Namierzenie +15,7%, Trujące Sidła +40% metryki) niesie pierwszą część;
			-- środkowa Strzelca to Strzała Burzy +0,9%, Strzał w Serce -0,4% i Nawałnica 0 w 1 cel 60 s: obie umiejętności
			-- x1,25 dają 0,32 przy Królobójca x baza 1,348 na 100 (pasmo C do 1,35); Trujące Sidła x0,7 dają 1,46, ale
			-- Kłusownik / Strzelec w obszarze na 45 1,05 < 1,15 (pasmo D) (DECYZJE S90)
			{ "Hunter", "marksman", "marksman.kingslayer", "właściciel (F4)" },
			{ "Hunter", "trapper", "trapper.poacher", "właściciel (F4)" },
			{ "Hunter", "scout", "scout.partyHunter", nil },
			-- S90: r6 Niszczyciela (0.53 / 1.58) i Arkanisty (0.40 / 1.56) poza zasięgiem dźwigni S90: pierwsza część to
			-- umiejętność rzędu 4 (Wir +8,7%, Wyładowanie +5,0%) i Potęga; w środkowej węzły bez wartości w metryce
			-- (Gniew Burzy i Przepływ Żywiołów 0, Inwokacja Mocy +0,1%), a Odzysk ma -2,43 (obniża boss 180 s); to wybór
			-- węzłów buildu wzorcowego, a ich wartości rusza pasma 12.7 (właściciel, DECYZJE S90)
			{ "Mage", "destroyer", "destroyer.destroyerExp", "właściciel (F4)" },
			{ "Mage", "arcanist", "arcanist.arcanistBoss", "właściciel (F4)" },
		} :: { { any } }
	do
		local report = spec[4]
		table.insert(
			SkillModel.PATH_TARGETS,
			target(`r6.{spec[2]}`, spec[1], spec[2], "r6min", spec[3], { 100 }, 0.6, nil, "ROZWOJ 0, 2.3 (E3)", {
				noL20 = true,
				report = report,
				note = "najsłabsza trzecia część / średnia",
			})
		)
		table.insert(
			SkillModel.PATH_TARGETS,
			target(`r6.{spec[2]}`, spec[1], spec[2], "r6max", spec[3], { 100 }, nil, 1.5, "ROZWOJ 0, 2.3 (E3)", {
				noL20 = true,
				report = report,
				note = "najmocniejsza trzecia część / średnia",
			})
		)
	end
end

-- The class base (B2, ROZWOJ 2.1): no main path, rows 1 of every path (Mage rows 1-2, 12.7), A everywhere, the class
-- stat plan, the weapon of the class measurement. `loadout` (P2) is Balance.LOADOUT, the diagnosis' weapon.
SkillModel.BASE = {
	Warrior = { rows = 1, weapon = { main = "axe2h" } }, -- ROZWOJ 10.6 (two-handed axe, the reference)
	Hunter = { rows = 1, weapon = { main = "bow", offhand = "quiver" } }, -- ROZWOJ 11.6
	Mage = { rows = 2, weapon = { main = "staff" } }, -- ROZWOJ 12.7
	Cleric = { rows = 1, weapon = { main = "mace1h", offhand = "shield" } }, -- ROZWOJ 9.6 (Balance.LOADOUT)
} :: { [string]: { rows: number, weapon: { main: string, offhand: string? } } }

SkillModel.LEVELS = { 20, 45, 70, 100 } -- the T-SK grid (balance plan D1)
SkillModel.BOSS_AT = { [20] = "grimrok", [45] = "morvane", [70] = "azgor", [100] = "vaelgrath" } :: { [number]: string }
SkillModel.G10_LEVELS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }

local EPS = 1e-6
-- mirrors Damage.computeDamage's life steal clamp: the cap of the stat (Data/Stats; tests/Balance.luau lsCap too)
local LIFESTEAL_CAP: number = ((Stats.get("lifesteal") :: any) or {}).cap or 100
-- mirrors StatusEffectService TICK_INTERVAL (one DoT / HoT tick per second; Traits.ticks assumes the same)
local TICK = 1
-- mirrors SkillService INSTANT: types without the motion's hit delay
local INSTANT: { [string]: boolean } = { resurrect = true, channel = true, beam = true }
-- mirrors Skills/Context HOLY_HEAL_SKILLS (Holy Wrath, holyHealAll; a server list, "Dla S87")
local HOLY_HEAL_SKILLS: { [string]: boolean } =
	{ radiance = true, judgement = true, brandOfLight = true, hammerOfHeaven = true }
-- mirrors SkillService ZEAL_SKILLS (Ardor, zealCdr)
local ZEAL_SKILLS = { "heal", "purify" }
-- mirrors Types/Offense: a split impact's radius and enemiesInCircle's tolerance
local SPLIT_RADIUS, CIRCLE_TOLERANCE = 3.5, 1.5
-- S86 server-only constants (text guards in balance.spec; "Dla S87": move them to Logic)
local TRAP_CHECK = 0.25 -- mirrors Types/Movement TRAP_CHECK (a trap looks for enemies every 0.25 s)
local PUSH_DURATION = 0.22 -- mirrors Skills/Push SECONDS (a pulling trap waits Push.DURATION before it fires)
local CHANNEL_POLL = 0.1 -- mirrors SkillService.startChannel task.wait(0.1) (a beam tick lands on this grid)

-- S86 text guards: a server file, a Lua pattern with one number capture and the model's number.
SkillModel.SERVER_CONSTANTS = {
	{ file = "src/server/Skills/Types/Movement.luau", pattern = "local TRAP_CHECK = ([%d%.]+)", value = TRAP_CHECK },
	{ file = "src/server/Skills/Push.luau", pattern = "local SECONDS = ([%d%.]+)", value = PUSH_DURATION },
	{ file = "src/server/Services/SkillService.luau", pattern = "task%.wait%(([%d%.]+)%)", value = CHANNEL_POLL },
	{
		file = "src/server/Services/StatusEffectService.luau",
		pattern = "local TICK_INTERVAL = ([%d%.]+)",
		value = TICK,
	},
	{ file = "src/server/Skills/Context.luau", pattern = "Magnitude <= radius %+ ([%d%.]+)", value = CIRCLE_TOLERANCE },
	{
		file = "src/server/Skills/Types/Offense.luau",
		pattern = "enemiesInCircle%(spot, ([%d%.]+)%)",
		value = SPLIT_RADIUS,
	},
	{
		file = "src/shared/Logic/Damage.luau",
		pattern = "attacker%.lifesteal or 0, 0, ([%d%.]+)%)",
		value = LIFESTEAL_CAP,
	},
} :: { { file: string, pattern: string, value: number } }

-- Types -------------------------------------------------------------------------------------------------------------

export type Build = {
	key: string, -- "<pathId>.<id>", "base", "base.loadout"
	classId: string,
	pathId: string?,
	ref: any?,
	base: boolean,
	weapon: { main: string, offhand: string? },
	areaCap: number,
	rotation: { { [string]: any } },
	nodes: { { any } },
	bp: { [string]: string },
	stats: { [string]: number },
	damageReference: boolean?,
	r7Exempt: boolean?,
}

export type CharacterResult = {
	character: any, -- { class, level, path = { main, nodes, bp, freeUsed }, equipment, ranks, barPool }
	spent: number,
	free: number,
	unbought: { { node: string, reason: string } },
	rankChecks: number, -- ranks bought, each through Paths.canBuy
	pool: string, -- S137: the weapon pool of the build
	skillFree: number, -- S137: skill points left in the pool
}

-- Builds ------------------------------------------------------------------------------------------------------------

local buildCache: { [string]: { Build } } = {}

local function skillNodeOf(classId: string, skillId: string): string?
	for _, path in Paths.pathsOf(classId) do
		for _, row in path.rows do
			for _, node in row.nodes do
				if node.kind == "skill" and node.skill == skillId then
					return node.id
				end
			end
		end
	end
	return nil
end

-- B2 c: the class rotations in path / build order, the first occurrence of a skill wins (with its conditions),
-- kept when `keep(skillId)`.
local function classRotation(classId: string, keep: (string) -> boolean): { { [string]: any } }
	local out: { { [string]: any } } = {}
	local seen: { [string]: boolean } = {}
	for _, path in Paths.pathsOf(classId) do
		for _, ref in path.reference do
			for _, entry in ref.rotation do
				local id = entry.skill
				if not seen[id] then
					seen[id] = true
					if keep(id) then
						table.insert(out, entry)
					end
				end
			end
		end
	end
	return out
end

-- S85 (B1, B2): the class base first (BASE; base.loadout when Balance.LOADOUT differs), then every reference build of
-- every path in Paths order. Builds and rotations are data only; nothing here sorts or filters a priority.
function SkillModel.builds(classId: string): { Build }
	local cached = buildCache[classId]
	if cached then
		return cached
	end
	local out: { Build } = {}
	local spec = SkillModel.BASE[classId]
	local nodes: { { any } } = {}
	local inBase: { [string]: boolean } = {}
	for _, path in Paths.pathsOf(classId) do
		for r = 1, spec.rows do
			for _, node in path.rows[r].nodes do
				table.insert(nodes, { node.id, node.maxRank })
				inBase[node.id] = true
			end
		end
	end
	local rotation = classRotation(classId, function(id: string): boolean
		local skill = SkillData.get(id)
		if not skill then
			return false
		end
		if skill.path == nil then
			return true
		end
		local nodeId = skillNodeOf(classId, id)
		return nodeId ~= nil and inBase[nodeId] == true
	end)
	local class = Classes.get(classId :: any) :: any
	local function base(key: string, weapon: { main: string, offhand: string? }): Build
		return {
			key = key,
			classId = classId,
			pathId = nil,
			ref = nil,
			base = true,
			weapon = weapon,
			areaCap = 2.0, -- ROZWOJ 8 (R3 / T-SK3)
			rotation = rotation,
			nodes = nodes,
			bp = {},
			stats = class.statPlan,
		}
	end
	table.insert(out, base("base", spec.weapon))
	local loadout = B.LOADOUT[classId]
	if loadout.weapon ~= spec.weapon.main or loadout.offhand ~= spec.weapon.offhand then
		local twoHanded = Paths.isTwoHanded(loadout.weapon)
		table.insert(
			out,
			base("base.loadout", { main = loadout.weapon, offhand = if twoHanded then nil else loadout.offhand })
		)
	end
	for _, path in Paths.pathsOf(classId) do
		for _, ref in path.reference do
			table.insert(out, {
				key = `{path.id}.{ref.id}`,
				classId = classId,
				pathId = path.id,
				ref = ref,
				base = false,
				weapon = ref.weapon,
				areaCap = ref.areaCap or 2.0, -- ROZWOJ 8
				rotation = ref.rotation,
				nodes = ref.nodes,
				bp = ref.bp,
				stats = ref.stats,
				damageReference = ref.damageReference,
				r7Exempt = ref.r7Exempt,
			})
		end
	end
	buildCache[classId] = out
	return out
end

-- One build by key ("<pathId>.<id>", "base", "base.loadout") of a class, or of any class for a path key.
function SkillModel.build(key: string, classId: string?): Build?
	for _, c in (if classId then { classId } else B.CLASSES) do
		for _, build in SkillModel.builds(c) do
			if build.key == key then
				return build
			end
		end
	end
	return nil
end

-- Character -------------------------------------------------------------------------------------------------------

local charCache: { [string]: CharacterResult } = {}

-- S137: an item id of a base type (the model's weapon in character.equipment selects the pool).
local function itemOfType(itemType: string): string?
	local first = `{itemType}_1`
	local def = Items.get(first)
	if def and def.type == itemType then
		return first
	end
	local best: string? = nil
	for id, item in Items.byId do
		if item.type == itemType and (best == nil or id < best) then
			best = id
		end
	end
	return best
end

-- S137 (DESIGN-18 §13): the order the build buys skill ranks in: ReferenceBuild.ranks, else the rotation, then the
-- pool's passives, then the rest of the pool (SkillPools.members).
function SkillModel.rankOrder(build: Build, pool: string): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local function push(id: string)
		if not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	local ref: any = build.ref
	if ref and ref.ranks then
		for _, id in ref.ranks do
			push(id)
		end
	end
	for _, entry in build.rotation do
		push(entry.skill)
	end
	local members = SkillPools.members(build.classId, pool)
	for _, id in members do
		local def = SkillData.get(id)
		if def and def.type == "passive" then
			push(id)
		end
	end
	for _, id in members do
		push(id)
	end
	return out
end

-- S85 (B3): level-up from 1 to L on the ROZWOJ 3.2 save shape. The main path (the build's) at Paths.MAIN_LEVEL
-- through Paths.canChooseMain; on every new point the first rank of `nodes` that Paths.canBuy accepts (an entry that
-- cannot be bought yet waits, later ones may pass). Breakpoint choices from the build (Skills.effective applies them
-- from rank 5 / 10). S137: after the nodes of a level the skill points of the level go into the build's pool
-- (rankOrder, each skill up to its limit in turn) as one SkillPoints.apply reservation; `element` = the Mage weapon's.
function SkillModel.character(build: Build, L: number, element: string?): CharacterResult
	local key = `{build.classId}|{build.key}|{L}|{element or "-"}`
	local cached = charCache[key]
	if cached then
		return cached
	end
	local path =
		{ main = nil :: string?, nodes = {} :: { [string]: number }, bp = table.clone(build.bp), freeUsed = false }
	local weaponId = itemOfType(build.weapon.main)
	local equipment = if weaponId then { weapon = { id = weaponId, el = element } } else {}
	local character: any = { class = build.classId, level = 1, path = path, equipment = equipment, ranks = {} }
	local pool = SkillPools.activePool(character) :: string
	character.barPool = pool
	local order = SkillModel.rankOrder(build, pool)
	local units: { string } = {}
	for _, entry in build.nodes do
		for _ = 1, entry[2] do
			table.insert(units, entry[1])
		end
	end
	local done: { boolean } = {}
	local checks = 0
	for level = 1, L do
		character.level = level
		if build.pathId and path.main == nil and Paths.canChooseMain(character, build.pathId) then
			path.main = build.pathId
			path.freeUsed = true
		end
		while Paths.free(character) >= 1 do
			local bought = false
			for i, nodeId in units do
				if not done[i] and Paths.canBuy(character, nodeId) then
					path.nodes[nodeId] = (path.nodes[nodeId] or 0) + 1
					done[i] = true
					bought = true
					checks += 1
					break
				end
			end
			if not bought then
				break
			end
		end
	end
	-- S137: the skill points of L go into the build's pool in one reservation from nothing (rankOrder, each skill up
	-- to its limit in turn): the reference build is planned for its level, like a player who resets before measuring
	do
		local left = SkillPoints.free(character, pool)
		local plan: { [string]: number } = {}
		for _, id in order do
			if left <= 0 then
				break
			end
			local def = SkillData.get(id)
			if def and Paths.skillOpen(character, id, pool) then
				local add = math.min(SkillPoints.cap(def, L), left)
				if add > 0 then
					plan[id] = add
					left -= add
				end
			end
		end
		if next(plan) ~= nil then
			local ok, err, ranks = SkillPoints.apply(character, pool, plan)
			assert(ok and ranks, `SkillModel.character: {build.key} L{L} {err}`)
			character.ranks[pool] = ranks
		end
	end
	local unbought: { { node: string, reason: string } } = {}
	for i, nodeId in units do
		if not done[i] then
			local _, reason = Paths.canBuy(character, nodeId)
			table.insert(unbought, { node = nodeId, reason = reason or "?" })
		end
	end
	local result: CharacterResult = {
		character = character,
		spent = Paths.spent(character),
		free = Paths.free(character),
		unbought = unbought,
		rankChecks = checks,
		pool = pool,
		skillFree = SkillPoints.free(character, pool),
	}
	charCache[key] = result
	return result
end

-- Player ----------------------------------------------------------------------------------------------------------

export type PlayerOpts = {
	gear: B.GearOpts?, -- passed on to Balance.gear (rarity, upgrade, traitScale, ilvl ...)
	element: string?, -- the Mage weapon's element (E5)
}

local playerCache: { [string]: any } = {}

local function serialize(t: { [string]: number }): string
	local keys: { string } = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	local parts: { string } = {}
	for _, k in keys do
		table.insert(parts, `{k}={t[k]}`)
	end
	return table.concat(parts, ",")
end

-- The Balance player of a model player with `flat` / `pct` effect stats (EffectStack.stats of the working statBuffs
-- and auras), cached by the effect set (diag currentPlayer).
local function playerWith(sp: any, flat: { [string]: number }, pct: { [string]: number }, furyStacks: number?): any
	local stacks = furyStacks or 0
	local key = serialize(flat) .. "|" .. serialize(pct) .. (if stacks > 0 then `|fury{stacks}` else "")
	local hit = sp.byEffects[key]
	if hit then
		return hit
	end
	local sources: { any } = { { key = "source.passives", flat = sp.passives.flat, pct = sp.passives.pct } }
	if next(flat) ~= nil or next(pct) ~= nil then
		table.insert(sources, { key = "source.effects", flat = flat, pct = pct })
	end
	if stacks > 0 then
		-- S86 (B5) mirrors StatusEffectService furySource: furySpeed % attack speed and furyLifesteal points of life
		-- steal per stack (items + path hooks, as hookOf)
		local hooks = sp.hooksAll or sp.passives.hooks
		local speed, steal = hooks.furySpeed or 0, hooks.furyLifesteal or 0
		if speed > 0 or steal > 0 then
			table.insert(sources, {
				key = "source.fury",
				pct = if speed > 0 then { atkSpeed = stacks * speed } else nil,
				flat = if steal > 0 then { lifesteal = stacks * steal } else nil,
			})
		end
	end
	local p: any = B.playerFromItems(
		sp.classId,
		sp.level,
		sp.items,
		sp.traitScale,
		{ stats = sp.stats, sources = sources, hooks = sp.passives.hooks }
	)
	sp.byEffects[key] = p
	return p
end

-- S85 (B4): the player of `build` at L. Gear of the convention (Balance.gear with the build's weapon), stats from
-- StatPlan.suggest (the "spend as the path suggests" button), path passives / nodes / hooks from Paths.passiveTotals,
-- circle auras of the build on its owner (PartyAuraService covers the owner, solo too). `sp.p` is a Balance.Player
-- (FightSim.dps reads it); `sp.pathHooks` is SkillService.PassiveHook (path and class passives only).
function SkillModel.player(build: Build, L: number, opts: PlayerOpts?): any
	local o: PlayerOpts = opts or {}
	-- cached without gear options (S86 / S88 pass their own GearOpts and keep the player)
	local key = `{build.classId}|{build.key}|{L}|{o.element or "-"}`
	local cached = if o.gear then nil else playerCache[key]
	if cached then
		return cached
	end
	local ch = SkillModel.character(build, L, if build.classId == "Mage" then o.element else nil)
	local character = ch.character
	local weapons = { main = build.weapon.main, offhand = build.weapon.offhand }
	local gearOpts: any = if o.gear then table.clone(o.gear :: any) else {}
	gearOpts.weapon = build.weapon.main
	gearOpts.offhand = if build.weapon.offhand then build.weapon.offhand else false
	gearOpts.element = o.element or gearOpts.element
	local items = B.gear(build.classId, L, gearOpts)
	local start = StatPlan.startOf(build.classId) :: any
	local stats = table.clone(start)
	for id, n in StatPlan.suggest(build.stats, start, start, StatPlan.total(L)) do
		stats[id] = (stats[id] or 0) + n
	end
	local passives = Paths.passiveTotals(character, weapons)
	local auraEntries: { any } = {}
	for _, aura in Paths.auras(character, weapons) do
		local category: any = BuffCategories.get(aura.category)
		if aura.shape == "circle" and category and category.kind == "statBuff" then
			table.insert(auraEntries, {
				category = aura.category,
				stats = aura.stats,
				pct = category.mode == "pct",
				at = -1,
			})
		end
	end
	local class = Classes.get(build.classId :: any) :: any
	local sp: any = {
		build = build,
		classId = build.classId,
		level = L,
		character = character,
		weapons = weapons,
		items = items,
		traitScale = gearOpts.traitScale,
		stats = stats,
		passives = passives,
		pathHooks = passives.hooks,
		auraEntries = auraEntries,
		byEffects = {},
		resource = class.resource,
	}
	local flat, pct = EffectStack.stats(auraEntries)
	sp.p = playerWith(sp, flat, pct)
	sp.hooksAll = sp.p.hooks -- CombatService.Hook: items + path passives (S86: the Fury source reads it)
	sp.ranged = class.basicAttack.ranged -- S86 (B4): melee fighters stand in heal zones
	sp.element = sp.p.element
	-- S54: skill damage x the equipped weapon's base speed / Combat.skillSpeedRef, once per player
	sp.speedMul = Skills.speedFactor(sp.p.weaponSpeed)
	if not o.gear then
		playerCache[key] = sp
	end
	return sp
end

-- A Balance.Player (the S32 convention) as a model player without skills or path (H1 control on Balance.player).
function SkillModel.wrap(p: any): any
	local class = Classes.get(p.classId :: any) :: any
	local sp: any = {
		build = { key = "convention", classId = p.classId, rotation = {} },
		classId = p.classId,
		level = p.level,
		character = { class = p.classId, level = p.level, path = { nodes = {}, bp = {}, freeUsed = false } },
		weapons = {},
		passives = { flat = {}, pct = {}, hooks = {} },
		pathHooks = {},
		auraEntries = {},
		byEffects = { ["|"] = p },
		resource = class.resource,
		hooksAll = p.hooks,
		ranged = class.basicAttack.ranged,
		p = p,
		element = p.element,
		speedMul = Skills.speedFactor(p.weaponSpeed),
	}
	return sp
end

-- Static unmodelled list of a player (I1 c): hooks the model does not count. S86: the class mechanics and the item
-- trait hooks joined the modelled list (on the event or, in a fight with monsters that hit back, `retaliate`).
local HOOKS_MODELLED: { [string]: boolean } = {
	-- S85
	elementDamage = true,
	holyDamage = true,
	areaSkillDamage = true,
	eliteDamage = true,
	bossDamage = true,
	executioner = true,
	damagePerEnemy = true,
	weakSpot = true,
	dotPower = true,
	bleedDamage = true,
	poisonDamage = true,
	elementRider = true,
	riderSameTarget = true,
	doubleAttack = true,
	manaOnHit = true,
	cooldownReduction = true,
	zealCdr = true,
	healBonus = true,
	allyHealBonus = true,
	lowHpHealBonus = true,
	healCrit = true,
	holyStrikeHeal = true,
	holyHealAll = true,
	trapCost = true,
	areaCost = true,
	spellCost = true,
	areaLingering = true,
	-- S86 class mechanics
	furyMax = true,
	furySpeed = true,
	furyDamage = true,
	furyLifesteal = true,
	furyGuard = true,
	falconDamage = true,
	falconBond = true,
	falconInterval = true,
	royalFalcon = true,
	spotOnHit = true,
	spotBonus = true,
	trapEnergy = true,
	trapRootDuration = true,
	areaDamage = true,
	singleDamage = true,
	spellDamage = true,
	resonance = true,
	chargeCost = true,
	chargeDamage = true,
	chargeReclaim = true,
	areaKillMana = true,
	channelGuard = true,
	vortexGuard = true,
	block = true,
	blockHeal = true,
	riposte = true,
	counterDamage = true,
	guardPerEnemy = true,
	lastStand = true,
	killHeal = true,
	poisonedGuard = true,
	poisonSlow = true,
	thorns = true,
	interceptMitigation = true, -- B7: Logic/Intercept in the boss report
	interceptThorns = true,
	-- S86 item trait hooks (STATY 14: on the event)
	controlledDamage = true,
	traitRuneSeal = true,
	traitFullDraw = true,
	traitSpark = true,
	traitTwinCut = true,
	traitRunThrough = true,
	traitExecute = true,
	traitWound = true,
	traitPoison = true,
	traitArmorBreak = true,
	traitWeaken = true,
	traitHarass = true,
	traitShock = true,
	traitSavingBlow = true,
	woundChance = true,
	poisonChance = true,
	resourceOnHit = true,
	frostbite = true,
}
-- Hooks that change no metric (threat, movement, minimap, kills of a dying group's spread, radius of areas every dummy
-- stands in, the mana shield's price): docs/SESJE.md S86 names the reason of each.
local HOOKS_NONE: { [string]: boolean } = {
	threat = true,
	manaShieldCost = true,
	areaRadius = true,
	minimapEliteBonus = true,
	vigilanceGuard = true,
	vigilanceMove = true,
	poisonSpread = true,
}

local function staticUnmodelled(sp: any): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(text: string)
		if not seen[text] then
			seen[text] = true
			table.insert(out, text)
		end
	end
	for id, v in sp.p.hooks do
		if v ~= 0 and not HOOKS_MODELLED[id] and not HOOKS_NONE[id] and string.sub(id, 1, 3) ~= "vs_" then
			if string.sub(id, 1, 4) ~= "res_" then
				add(`hak {id}`)
			end
		end
	end
	table.sort(out)
	return out
end

-- Fight -----------------------------------------------------------------------------------------------------------

export type FightOpts = {
	targets: { any }?, -- MonsterStats (default: Balance.monster(GENERIC, L))
	dummy: boolean?, -- default true: HP without end
	seconds: number?, -- default ASSUMPTIONS.sustainedSeconds
	skills: boolean?, -- false = basic attacks only
	startPool: number?, -- share of the pool at the start (default 1)
	unlimited: boolean?, -- costs count in `spent` but never leave the pool (on cooldown, T-SK4)
	potions: boolean?, -- E4
	control: boolean?, -- H1: leaves out the terms FightSim.dps does not count
	heal: any?, -- F: { tank = Player, team = n }: heal rotation of a Cleric on a boss
	-- S86 (D3): the monsters hit back (FightSim.hit, misfortune, block, reductions, shields, heals cut to the missing
	-- HP, HP potions); the fight ends when every target or the player is dead
	retaliate: boolean?,
	hpPotions: boolean?, -- S86: HP potions every Potions.interval(L) in a retaliate fight (the Balance.potionHps rule)
	startHp: number?, -- S86: share of max HP at the start of a retaliate fight (default 1)
	sample: ((state: any) -> ())?, -- S86: called every step after the rotation (time means of B, D, C3)
	instantTraps: boolean?, -- S86 (B8.4): traps fire at once, without TRAP_CHECK and the pull wait (ROZWOJ 11.6)
	rotation: { { [string]: any } }?, -- S86 (R4): another rotation than the build's
	override: { [string]: { def: any, bp: any } }?, -- S86 (R4): a skill's effective def and behaviours
	startFury: number?, -- S86 tests: Fury stacks at the start (Fury.set)
	startCharges: number?, -- S86 tests: Arcane Charges at the start (giveCharges)
}

export type FightResult = {
	seconds: number,
	dealt: number,
	dps: number,
	by: { [string]: number },
	casts: { [string]: number },
	spent: number,
	poolMax: number,
	poolEnd: number,
	regen: number,
	potions: number,
	healTo: { [string]: number },
	skipped: { [string]: { reason: string, count: number } },
	unmodelled: { string },
	firstCasts: { string },
	-- S86
	furyMean: number, -- mean Fury stacks over the fight (B5)
	furyFull: number, -- share of the time at full Fury (furyGuard)
	furyMax: number,
	controlled: number, -- share of the time the focus target is slowed, rooted, frozen or stunned (B8, C3)
	sealLit: number, -- share of the time the Runic Seal glows (standing still, C3)
	basicDealt: number, -- damage of basic attacks (with their second hits and draws)
	elementDealt: number, -- damage of the weapon-element effects (burn ticks, arcs; C3 elementShare)
	areaDealt: number, -- damage of area skill hits (Traits.isAreaSkill, zone ticks included; C3 areaShare)
	offensiveCasts: number, -- offensive casts and traps (C3 skillInterval)
	died: boolean, -- retaliate: the player fell
	hpEnd: number, -- retaliate: HP share at the end
	hpLost: number, -- retaliate: HP lost over the fight / max HP (damage taken minus effective heals)
	taken: number, -- retaliate: damage taken after reductions and shields
	healEff: number, -- retaliate: HP the heals really restored (cut to the missing HP, B1.3)
	kills: number,
	potionsHp: number,
	blockEnergy: number, -- energy from blocks with block from nodes (B6)
	falconStrikes: number, -- B9
	trapsFired: number, -- B8
	beamTicks: number, -- B11
	chargesMean: number, -- B12: mean Arcane Charges
	returns: number, -- T-SK4 income besides regeneration (resource)
	cascade: number, -- the Cascade mana of returns (areaKillMana; only monsters that die give it)
	chargesEnd: number, -- Arcane Charges at the end
	furyEnd: number, -- Fury stacks at the end
	lifestealHeal: number, -- life steal heals (D2 balance)
}

local function mark(state: any, text: string)
	state.unmodelled[text] = true
end

local function schedule(state: any, at: number, fn: () -> ())
	state.seq += 1
	local ev = { t = at, seq = state.seq, fn = fn }
	local list = state.events
	local i = #list
	-- insertion keeps (t, seq) order; most events are appended near the end
	while i >= 1 and (list[i].t > at or (list[i].t == at and list[i].seq > ev.seq)) do
		i -= 1
	end
	table.insert(list, i + 1, ev)
end

local function alive(state: any): { any }
	if state.dummy then
		return state.targets -- dummies never die
	end
	local out = {}
	for _, tg in state.targets do
		if tg.hp > 0 then
			table.insert(out, tg)
		end
	end
	return out
end

-- The working Balance player: statBuff effects on the player and the build's circle auras through
-- Logic/EffectStack (StatusEffectService modifierSource), the Fury source (S86), recomputed only when they change.
local function current(state: any): any
	if not state.selfDirty then
		return state.p
	end
	state.selfDirty = false
	local entries = table.clone(state.sp.auraEntries)
	for _, e in state.self.effects do
		if e.kind == "statBuff" then
			table.insert(entries, { category = e.category, stats = e.stats, pct = e.pct, at = e.appliedAt })
		end
	end
	local flat, pct = EffectStack.stats(entries)
	state.p = playerWith(state.sp, flat, pct, state.furyStat)
	return state.p
end

-- CombatService.Hook (items + path passives) and SkillService.PassiveHook (path passives only).
local function hook(state: any, id: string): number
	return current(state).hooks[id] or 0
end
local function pathHook(state: any, id: string): number
	return state.sp.pathHooks[id] or 0
end

-- mirrors CombatService.DotBonus
local function dotBonus(state: any, kind: string): number
	if kind == "bleed" then
		return hook(state, "dotPower") + hook(state, "bleedDamage")
	elseif kind == "poison" then
		return hook(state, "dotPower") + hook(state, "poisonDamage")
	elseif kind == "burn" then
		return hook(state, "dotPower")
	end
	return 0
end

-- mirrors StatusEffectService.IsBossLike (bosses and Elite II ignore notBoss effects)
local function bossLike(entity: any): boolean
	return entity.m ~= nil and (entity.m.variant == "boss" or entity.m.variant == "elite2")
end

-- mirrors StatusEffectService.Apply (S85 C4). One effect per key (kind, source, skillId, category; the source is
-- always this player), EffectStack.restack (a running effect gains a stack up to maxStacks, keeps nextTick, ends at
-- now + duration; tickAmount x stacks), statBuff merge (EffectStack.merge). S86: `accumulate` (B13: the tick from
-- EffectStack.accumulate, the unpaid rest added to the new total), `stacks` / `keepLonger` (EffectStack.restack),
-- `onEnd` with the starting value (shields, S71), `item` (EffectStack.ITEM entries of split categories).
local function apply(state: any, entity: any, kind: string, o: any): boolean
	if (o.duration or 0) <= 0 then
		return false
	end
	if o.notBoss and bossLike(entity) then
		return false
	end
	local t = state.t
	local key = `{kind}|{o.skillId or ""}|{o.category or ""}`
	local e = entity.effects[key]
	local running = e ~= nil and e.expiresAt > t + EPS
	local old = if running
		then {
			stacks = e.stacks,
			value = e.value,
			tickAmount = e.tickAmount,
			expiresAt = e.expiresAt,
			nextTick = e.nextTick,
		}
		else nil
	local st = EffectStack.restack(old, {
		unit = o.value or 0,
		tickUnit = o.tickAmount,
		maxStacks = o.maxStacks,
		duration = o.duration,
		now = t,
		tickInterval = TICK,
		stacks = o.stacks,
		keepLonger = o.keepLonger,
	})
	local tickAmount, nextTick = st.tickAmount, st.nextTick
	if o.accumulate and o.tickAmount then
		-- mirrors StatusEffectService.Apply (S65): the tick comes only from accumulate
		local total = o.tickAmount * EffectStack.ticksBetween(t + TICK, t + o.duration, TICK)
		local maxStacks = o.maxStacks or 1
		local scheduleOld = if running
				and e.tickAmount
				and e.nextTick
			then { tickAmount = e.tickAmount, nextTick = e.nextTick, expiresAt = e.expiresAt }
			else nil
		tickAmount, nextTick = EffectStack.accumulate(scheduleOld, {
			total = total,
			limit = if maxStacks > 1 then maxStacks else nil,
			duration = o.duration,
			now = t,
			interval = TICK,
		})
	end
	local stats, expiresAt = o.stats, st.expiresAt
	if kind == "statBuff" then
		local timed = if running then { stats = e.stats, pct = e.pct, expiresAt = e.expiresAt } else nil
		stats, expiresAt = EffectStack.merge(timed, { stats = o.stats, pct = o.pct, expiresAt = st.expiresAt }, t)
	end
	entity.effects[key] = {
		kind = kind,
		skillId = o.skillId,
		category = o.category,
		stacks = st.stacks,
		value = st.value,
		tickAmount = tickAmount,
		nextTick = nextTick,
		expiresAt = expiresAt,
		appliedAt = t,
		stats = stats,
		pct = o.pct,
		initial = o.value or 0,
		onEnd = o.onEnd,
		item = o.skillId == EffectStack.ITEM,
		element = o.element,
		area = o.area,
	}
	if entity == state.self and kind == "statBuff" then
		state.selfDirty = true
	end
	return true
end

local function effectsOf(entity: any, kind: string): { any }
	local out = {}
	for _, e in entity.effects do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end

-- A running effect of `kind` on `entity` (StatusEffectService.Has).
local function has(state: any, entity: any, kind: string): boolean
	for _, e in entity.effects do
		if e.kind == kind and e.expiresAt > state.t + EPS then
			return true
		end
	end
	return false
end

-- The strongest running value of `kind` (StatusEffectService.Max).
local function maxOf(state: any, entity: any, kind: string): number
	local best = 0
	for _, e in entity.effects do
		if e.kind == kind and e.expiresAt > state.t + EPS then
			best = math.max(best, e.value or 0)
		end
	end
	return best
end

-- The working value of a value category (StatusEffectService.CategoryValue, EffectStack.value).
local function categoryValue(state: any, entity: any, category: string): number
	local entries = {}
	for _, e in entity.effects do
		if e.category == category and e.expiresAt > state.t + EPS then
			table.insert(entries, { category = category, value = e.value, at = e.appliedAt, item = e.item })
		end
	end
	return EffectStack.value(entries, category)
end

-- mirrors StatusEffectService.SlowFactor < 1: slowed, rooted, frozen or stunned (Easy Prey, the control axis)
local CONTROL_KINDS: { [string]: boolean } = { slow = true, root = true, freeze = true, stun = true }
local function controlled(state: any, entity: any): boolean
	for _, e in entity.effects do
		if CONTROL_KINDS[e.kind] and e.expiresAt > state.t + EPS then
			return true
		end
	end
	return false
end

-- mirrors StatusEffectService.Consume / Remove: every self effect of `kind` goes, the first one's value counts
local function takeOne(state: any, kind: string): any?
	local first = nil
	for key, e in state.self.effects do
		if e.kind == kind then
			state.self.effects[key] = nil
			first = first or e
		end
	end
	return first
end

-- Healing done (F): `who` is "self", "tank" or "ally". The attempted amount counts (T-SK5, T-SK6 without the cut);
-- S86 (B1.3): in a retaliate fight a heal on the caster restores at most the missing HP (healEff).
local function giveHeal(state: any, who: string, amount: number)
	if amount <= 0 then
		return
	end
	state.healTo[who] = (state.healTo[who] or 0) + amount
	if state.retaliate and who == "self" then
		local effective = math.min(amount, math.max(0, state.maxHp - state.hp))
		state.hp += effective
		state.healEff += effective
	end
end

-- HP share of a heal target before the heal: the caster's own HP track in a retaliate fight, else
-- ASSUMPTIONS.healTargetFraction (no low-HP bonus on T-SK5 / T-SK6, S85).
local function hpFraction(state: any, who: string): number
	if state.retaliate and who == "self" then
		return state.hp / math.max(1, state.maxHp)
	end
	return A.healTargetFraction
end

-- S86 (B1) mirrors Skills/Context Context.healFactor: healPower, the heal hooks on heals (healBonus + allyHealBonus
-- on another player + lowHpHealBonus below SkillData.LOW_HP_HEAL % HP, Skills.healBonusPct), healCrit as expected
-- value (x HEAL_CRIT_MUL); shields only healPower and the crit.
local function healFactor(state: any, who: string, shield: boolean): number
	local v = current(state).values
	local mul = 1 + (v.healPower or 0) / 100
	if not shield then
		local bonus = Skills.healBonusPct({
			healBonus = pathHook(state, "healBonus"),
			allyHealBonus = pathHook(state, "allyHealBonus"),
			lowHpHealBonus = pathHook(state, "lowHpHealBonus"),
		}, who ~= "self", hpFraction(state, who))
		mul *= 1 + bonus / 100
	end
	local chance = Skills.healCritChance(v.critChance or 0, pathHook(state, "healCrit"))
	return mul * (1 + chance * (SkillData.HEAL_CRIT_MUL - 1))
end
SkillModel.healFactor = healFactor

-- mirrors Skills/Context Context.healFrom (PvP x0.7 does not apply in PvE)
local function healFrom(state: any, who: string, amount: number)
	giveHeal(state, who, amount * healFactor(state, who, false))
end

-- Fury (B5) -------------------------------------------------------------------------------------------------------

local FURY = PathData.HOOK_RULES.fury
local CARNAGE = PathData.HOOK_RULES.carnage

-- mirrors StatusEffectService.FuryMax: the furyMax hook, at most HOOK_RULES.fury.maxStacks; 0 = no Fury
local function furyMax(state: any): number
	return math.clamp(math.floor(hook(state, "furyMax")), 0, FURY.maxStacks)
end

-- mirrors StatusEffectService.AddFury: one hit that dealt damage; Carnage adds HOOK_RULES.carnage.furyGain
local function addFury(state: any)
	local max = furyMax(state)
	if max <= 0 then
		return
	end
	local amount = if has(state, state.self, "carnage") then CARNAGE.furyGain else 1
	state.fury = Fury.gain(state.fury, state.t, max, amount, FURY)
end

-- mirrors StatusEffectService stepFury (Heartbeat): Fury.step with Carnage frozen; the stat source (furySpeed,
-- furyLifesteal) recomputes at most every HOOK_RULES.fury.statInterval s (StatService.InvalidateThrottled).
local function stepFury(state: any)
	local max = furyMax(state)
	if max <= 0 then
		return
	end
	state.fury = Fury.step(state.fury, state.t, max, true, has(state, state.self, "carnage"), FURY)
	local stacks = state.fury.stacks
	if stacks ~= state.furyStat and state.t + EPS >= state.furyStatAt + FURY.statInterval then
		local h = state.sp.hooksAll or {}
		if (h.furySpeed or 0) > 0 or (h.furyLifesteal or 0) > 0 then
			state.furyStat = stacks
			state.furyStatAt = state.t
			state.selfDirty = true
		end
	end
end
SkillModel.furyMax = furyMax

-- S86 (B5 test): Fury under hits at `hits` (s) over `seconds` through the model's addFury / stepFury, with furyMax =
-- `max`; Carnage on [carnage[1], carnage[2]). Returns the stacks at each whole second (index = second + 1).
function SkillModel.furySim(hits: { number }, seconds: number, max: number, carnage: { number }?): { number }
	local state: any = {
		t = 0,
		fury = Fury.new(),
		furyStat = 0,
		furyStatAt = -math.huge,
		selfDirty = false,
		self = { effects = {} },
		p = { hooks = { furyMax = max } },
		sp = { hooksAll = {} },
	}
	local out: { number } = {}
	local nextHit = 1
	local steps = math.floor(seconds / A.dt + 0.5)
	for step = 0, steps do
		state.t = step * A.dt
		state.self.effects = {}
		if carnage and state.t + EPS >= carnage[1] and state.t < carnage[2] - EPS then
			state.self.effects.c = { kind = "carnage", expiresAt = carnage[2], value = 0 }
		end
		stepFury(state)
		while hits[nextHit] and hits[nextHit] <= state.t + EPS do
			addFury(state)
			nextHit += 1
		end
		if math.abs(state.t - math.floor(state.t + 0.5)) < EPS then
			out[math.floor(state.t + 0.5) + 1] = state.fury.stacks
		end
	end
	return out
end

-- Arcane Charges (B12) -----------------------------------------------------------------------------------------------

local CHARGES = SkillData.ARCANE_CHARGES

-- mirrors SkillService chargesEnabled: charges work with Arcane Discharge and the path's weapon only
local function chargesEnabled(state: any): boolean
	if state.chargesOn == nil then
		state.chargesOn = (Paths.skillUsable(state.sp.character, CHARGES.consumer, state.sp.weapons)) == true
	end
	return state.chargesOn
end

-- mirrors SkillService chargesOf: Skills.chargesNow (in combat for the whole fight)
local function chargesNow(state: any): number
	return Skills.chargesNow(state.charges.stacks, state.charges.expiresAt, state.t, true)
end

-- mirrors SkillService giveCharges: StatusEffectService.Apply "arcaneCharge" (EffectStack.restack: one more stack,
-- or at least `stacks`; the time starts again)
local function giveCharges(state: any, stacks: number?)
	local c = state.charges
	local running = c.expiresAt > state.t + EPS
	local st = EffectStack.restack(if running then { stacks = c.stacks, value = 0, expiresAt = c.expiresAt } else nil, {
		unit = 0,
		maxStacks = CHARGES.max,
		duration = CHARGES.duration,
		now = state.t,
		stacks = stacks,
		tickInterval = TICK,
	})
	state.charges = { stacks = st.stacks, expiresAt = st.expiresAt }
end

-- Effects over time -----------------------------------------------------------------------------------------------

-- mirrors StatusEffectService.tickEntity (S85 C4): the end first, then the tick (a d s effect deals Traits.ticks
-- ticks for d > 1; none for d <= 1); ticks on monsters bypass armour, crit and multipliers (Monster:TakeDamage).
-- S86: an ended shield runs its onEnd once with the starting value (S71 Shattering Shield); Carnage's natural end
-- sets Fury to its furyRestore (S75, StatusEffectService after the loop); a HoT heals through giveHeal (the HP
-- track of a retaliate fight).
local function tickEntity(state: any, entity: any)
	local t = state.t
	local restore = 0
	for key, e in entity.effects do
		if e.expiresAt <= t + EPS then
			entity.effects[key] = nil
			if entity == state.self and e.kind == "statBuff" then
				state.selfDirty = true
			end
			if entity == state.self and e.kind == "carnage" and (e.value or 0) > 0 then
				restore = math.max(restore, e.value)
			end
			local onEnd = e.onEnd
			if onEnd then
				e.onEnd = nil
				onEnd(entity, e.initial or 0)
			end
			continue
		end
		if e.nextTick and e.tickAmount and t + EPS >= e.nextTick then
			e.nextTick += TICK
			if e.kind == "hot" then
				giveHeal(state, entity.who or "self", e.tickAmount)
			elseif entity.m and entity.hp > 0 then
				entity.hp -= e.tickAmount
				state.dealt += e.tickAmount
				local bucket = e.skillId or "dot"
				state.by[bucket] = (state.by[bucket] or 0) + e.tickAmount
				if e.element == "weapon" then
					state.elementDealt += e.tickAmount
				end
				if e.area then
					state.areaDealt += e.tickAmount
				end
			end
		end
	end
	if restore > 0 then
		-- mirrors StatusEffectService.SetFury (Fury.set, clamped to FuryMax)
		state.fury = Fury.set(state.fury, t, restore, furyMax(state))
	end
end

-- Share of hits on `tg` below `pct` % HP (execute, finisher): a dummy's HP falls linearly (ASSUMPTIONS).
local function belowShare(tg: any, pct: number): number
	if tg.dummy and A.executeShare == "linear" then
		return math.clamp(pct / 100, 0, 1)
	end
	return if tg.hp / tg.maxHp * 100 < pct then 1 else 0
end

-- mirrors CombatService.offensiveMultiplier (S85 C3, S86): eliteDamage / bossDamage by variant, vs_<family>,
-- executioner + Beheading (traitExecute) below Combat.lowHpFraction (Traits.executeBonus, a share of hits on a
-- dummy), Easy Prey (controlledDamage on a slowed / rooted / frozen / stunned target, Traits.controlledBonus), the lit
-- Runic Seal (traitRuneSeal), Frostbite from this player's ice, damagePerEnemy per living target up to
-- HOOK_RULES.perEnemy.max, Fury (furyDamage per stack). control = H1 (FightSim.dps counts only vs_<family>).
local function offensiveMultiplier(state: any, tg: any): number
	local mult = 1
	local m = tg.m
	if not state.control then
		if m.variant == "elite" or m.variant == "elite2" then
			mult += hook(state, "eliteDamage") / 100
		elseif m.variant == "boss" then
			mult += hook(state, "bossDamage") / 100
		end
	end
	if m.family then
		mult += hook(state, Bonuses.familyLine("vs_", m.family)) / 100
	end
	if not state.control then
		local executioner, trait = hook(state, "executioner"), hook(state, "traitExecute")
		if executioner > 0 or trait > 0 then
			local share = belowShare(tg, Combat.lowHpFraction * 100)
			mult += share * Traits.executeBonus(executioner, trait, nil) / 100
		end
		local prey = hook(state, "controlledDamage")
		if prey > 0 and controlled(state, tg) then
			mult += Traits.controlledBonus(prey, 0.5, nil) / 100
		end
		local seal = hook(state, "traitRuneSeal")
		if seal > 0 and state.sealLit then
			mult += seal / 100
		end
		local frost = maxOf(state, tg, "frostbite")
		if frost > 0 then
			mult += frost / 100
		end
		local perEnemy = hook(state, "damagePerEnemy")
		if perEnemy > 0 then
			mult += perEnemy * math.min(#alive(state), PathData.HOOK_RULES.perEnemy.max) / 100
		end
		local stacks = state.fury.stacks
		if stacks > 0 then
			local perStack = hook(state, "furyDamage")
			if perStack > 0 then
				mult += stacks * perStack / 100
			end
		end
	end
	return mult
end

-- Weapon-element effects (B13, C) ---------------------------------------------------------------------------------

-- A chance per trial as a fixed rate (S86, DECYZJE): the counter starts at one half and fires every time it passes
-- 1, so `chance` x trials effects land in a fight (the expected value of the game's roll).
local function proc(state: any, key: string, chance: number): boolean
	if chance <= 0 then
		return false
	end
	if chance >= 1 then
		return true
	end
	local c = (state.procs[key] or 0.5) + chance
	if c >= 1 then
		state.procs[key] = c - 1
		return true
	end
	state.procs[key] = c
	return false
end

-- mirrors Skills/Elements.chill: Frostbite (SkillData.FROSTBITE or the higher fixed hook "frostbite") on targets the
-- player's ice slowed or froze, keepLonger
local function chill(state: any, tg: any, duration: number)
	if state.sp.element ~= "ice" or duration <= 0 or tg.m == nil then
		return
	end
	local value = math.max(SkillData.FROSTBITE, hook(state, "frostbite"))
	apply(state, tg, "frostbite", { duration = duration, value = value, keepLonger = true, skillId = "frostbite" })
end

local dealDamage: (state: any, tg: any, o: any) -> number

-- The other living target nearest to `tg` (Skills/Elements nearestOther; dummies stand at one point).
local function otherTarget(state: any, tg: any): any?
	for _, x in alive(state) do
		if x ~= tg then
			return x
		end
	end
	return nil
end

-- mirrors Skills/Elements.apply (S65, S79): Traits.elementPlan with the caller's spec, elementRider and
-- riderSameTarget, dotBonus("burn"); a burn with accumulate, an ice slow with Frostbite (chill), a lightning arc
-- into the nearest other enemy (else on the same target with sameTarget). `jump(other, pct)` deals the arc.
local function elementApply(
	state: any,
	tg: any,
	element: string?,
	spec: any,
	hit: number,
	skillId: string,
	jump: (other: any, pct: number) -> ()
)
	local plan = Traits.elementPlan(
		element,
		spec,
		hit,
		hook(state, "elementRider"),
		dotBonus(state, "burn"),
		hook(state, "riderSameTarget") > 0
	)
	if not plan then
		return
	end
	if plan.kind == "burn" then
		apply(state, tg, "burn", {
			duration = plan.duration,
			value = plan.pct,
			tickAmount = plan.tick,
			skillId = skillId,
			accumulate = true,
			element = "weapon",
		})
	elseif plan.kind == "slow" then
		if
			apply(
				state,
				tg,
				"slow",
				{ duration = plan.duration, value = plan.pct, skillId = skillId, category = "enemySlow" }
			)
		then
			chill(state, tg, plan.duration)
		end
	else
		local other = otherTarget(state, tg)
		if other then
			jump(other, plan.pct)
		elseif plan.sameTarget > 0 then
			jump(tg, plan.sameTarget)
		end
	end
end

-- Elemental Spark's recipe (mirrors CombatService sparkSpec from the trait's params)
local SPARK_PARAMS: any = (ItemTraits.get("elementalSpark") :: any).params
local SPARK_SPEC: any = {
	burnPct = SPARK_PARAMS.burnPct,
	burnDuration = SPARK_PARAMS.burnDuration,
	exactTicks = true,
	slowPct = SPARK_PARAMS.slowPct,
	slowDuration = SPARK_PARAMS.slowDuration,
	arcPct = SPARK_PARAMS.arcPct,
	arcRadius = SPARK_PARAMS.arcRadius,
	sameTargetPct = SPARK_PARAMS.sameTargetPct,
}
local function traitParam(id: string, key: string): number
	local def: any = ItemTraits.get(id)
	return def.params[key]
end

-- Item on-hit effects (C) ------------------------------------------------------------------------------------------

-- mirrors CombatService.ApplyPoison: every poison of a player, with poisonSlow (enemySlow) while it is applied
local function applyPoison(state: any, tg: any, o: any): boolean
	local applied = apply(state, tg, "poison", o)
	local slow = hook(state, "poisonSlow")
	if applied and slow > 0 then
		apply(
			state,
			tg,
			"slow",
			{ duration = o.duration, value = slow, skillId = "poisonSlow", category = "enemySlow" }
		)
	end
	return applied
end

-- mirrors CombatService.applyTraitEffect (S63-S65): bleed / poison (Traits.chance, Traits.dotTick, accumulate,
-- maxStacks, attackSlow), armour break (every hit; area share), weaken, harass (slow + attack slow), shock (stun,
-- gap, not bosses, the monster's next attack delayed). Rolls as a rate (proc).
local function applyTraitEffect(
	state: any,
	tg: any,
	entry: any,
	grown: number,
	line: number,
	share: number,
	hit: number
)
	local spec = entry.onHit
	local effect = spec.effect
	local id = entry.trait.id
	if effect == "bleed" or effect == "poison" then
		local chance = Traits.chance(if grown > 0 then spec.chance or 0 else 0, line, share)
		if not proc(state, id, chance / 100) then
			return
		end
		local pct = if grown > 0 then grown else spec.linePct or 0
		local options = {
			duration = spec.duration,
			value = pct,
			tickAmount = Traits.dotTick(hit, pct, spec.duration, dotBonus(state, effect)),
			maxStacks = spec.maxStacks,
			skillId = EffectStack.ITEM,
			accumulate = true,
		}
		if effect == "poison" then
			applyPoison(state, tg, options)
		else
			apply(state, tg, effect, options)
		end
		if grown > 0 and spec.attackSlow then
			apply(state, tg, "attackSlow", {
				duration = spec.duration,
				value = spec.attackSlow,
				skillId = EffectStack.ITEM,
				category = "enemyAttackSlow",
			})
		end
	elseif effect == "armorBreak" then
		if grown <= 0 or not proc(state, id, share) then
			return
		end
		apply(state, tg, "armorBreak", {
			duration = spec.duration,
			value = grown,
			maxStacks = spec.maxStacks,
			skillId = EffectStack.ITEM,
			category = "enemyArmor",
		})
	elseif effect == "weaken" then
		if grown <= 0 or not proc(state, id, share) then
			return
		end
		apply(state, tg, "weaken", {
			duration = spec.duration,
			value = grown,
			skillId = EffectStack.ITEM,
			category = "enemyDamageDown",
		})
	elseif effect == "harass" then
		if not proc(state, id, Traits.chance(grown, 0, share) / 100) then
			return
		end
		apply(
			state,
			tg,
			"slow",
			{ duration = spec.duration, value = spec.slow, skillId = EffectStack.ITEM, category = "enemySlow" }
		)
		apply(state, tg, "attackSlow", {
			duration = spec.duration,
			value = spec.attackSlow,
			skillId = EffectStack.ITEM,
			category = "enemyAttackSlow",
		})
	elseif effect == "shock" then
		local gap = spec.gap or 0
		if bossLike(tg) or not Traits.gapReady(tg.shockAt, state.t, gap) then
			return
		end
		if not proc(state, id, Traits.chance(grown, 0, share) / 100) then
			return
		end
		if
			apply(state, tg, "stun", { duration = spec.duration, skillId = EffectStack.ITEM, notBoss = spec.notBoss })
		then
			tg.shockAt = state.t
			-- mirrors Monster.DelayAttack: the next attack moves to stun + delayShare x interval at the earliest
			if tg.nextAttack then
				local interval = tg.m.attackInterval
				tg.nextAttack = math.max(tg.nextAttack, state.t + spec.duration + (spec.delayShare or 0) * interval)
			end
		end
	end
end

-- mirrors CombatService applyOnHit (S63): every live on-hit trait and line of the player, Traits.procShare of the hit
-- (0 for noProc, 1 for basic attacks and one-target skills, Combat.areaProcShare per target of an area skill), then
-- resourceOnHit (Traits.resourceOnHit, once per Combat.resourceOnHitGap).
local function applyOnHit(state: any, tg: any, hit: number, o: any)
	local share = Traits.procShare({ basic = o.basic, area = o.area, noProc = o.noProc })
	if share <= 0 then
		return
	end
	for _, entry in ItemTraits.onHitList do
		local grown = hook(state, entry.trait.hook :: string)
		local line = if entry.onHit.line then hook(state, entry.onHit.line) else 0
		if grown > 0 or line > 0 then
			applyTraitEffect(state, tg, entry, grown, line, share, hit)
		end
	end
	local pct = hook(state, "resourceOnHit")
	if pct > 0 then
		local amount = Traits.resourceOnHit(pct, state.poolMax, state.resourceAt, state.t)
		if amount > 0 then
			state.gainReturn(amount)
			state.resourceAt = state.t
		end
	end
end

-- mirrors CombatService savingBlow (S65): the most wounded ally within the radius heals amount x pct % through
-- Context.healFrom; the bearer (the only wounded one) heals the part under the lifesteal cap (Traits.savingSelfShare)
local function savingBlow(state: any, amount: number)
	local value = hook(state, "traitSavingBlow")
	if value <= 0 then
		return
	end
	if state.heal then
		healFrom(state, "tank", amount * value / 100) -- the tank is the wounded ally (heal mode, F2)
		return
	end
	if state.retaliate and state.hp < state.maxHp then
		local lifesteal = current(state).values.lifesteal or 0
		giveHeal(state, "self", amount * Traits.savingSelfShare(value, lifesteal) / 100)
	end
end

-- mirrors CombatService.Spot (S77): spotOnHit + spotBonus as a vulnerability (enemyWeak) for HOOK_RULES.spot.duration
local function spot(state: any, tg: any)
	local value = hook(state, "spotOnHit")
	if value <= 0 then
		return
	end
	value += hook(state, "spotBonus")
	apply(state, tg, "vulnerability", {
		duration = PathData.HOOK_RULES.spot.duration,
		value = value,
		skillId = "scout_spotting",
		category = "enemyWeak",
	})
end

-- A kill (non-dummy fights): killHeal (CombatService reward), Carnage resets (SkillService, HOOK_RULES.carnage).
local function onKill(state: any, _tg: any)
	state.kills += 1
	local killHeal = Traits.killHeal(hook(state, "killHeal")) -- mirrors CombatService:reward (S88 cap)
	if killHeal > 0 then
		giveHeal(state, "self", current(state).values.maxHp * killHeal / 100)
	end
	if has(state, state.self, "carnage") then
		for _, id in CARNAGE.resets do
			state.cd[id] = nil -- mirrors SkillService.ResetCooldown (the GCD stays)
		end
	end
end

export type HitOpts = {
	magic: boolean,
	percent: number, -- % of attack (params.multiplier x 100)
	extra: number?, -- DealOptions.multiplier
	basic: boolean?,
	consumeShot: boolean?,
	forceShare: number?, -- share of hits with forceCrit (execute)
	noProc: boolean?,
	bucket: string?,
	focus: boolean?, -- the selected target (Weak Spot)
	scale: number?, -- expected share of the hit (doubleAttack's second hit)
	area: boolean?, -- S86: an area skill hit (Traits.procShare)
	skill: string?, -- S86: DealOptions.skill (Spotting reads HOOK_RULES.spot.skills)
	areaHit: boolean?, -- S86: counts in areaDealt (C3)
}

-- mirrors CombatService.DealDamage + Logic/Damage.computeDamage (S85 C3), one expected hit: guaranteedCrit and
-- nextShot taken by every hit with consumeShot ~= false (basic attacks too), Draw a Bead (sighted) crit, the target's
-- strongest vulnerability, Weak Spot stacks, armour break of the enemyArmor category (EffectStack.value), pierce /
-- magicPierce, Damage.reduction, levelGap, crit as expected value (forceCrit: the full multiplier; monsters have no
-- element resistance), skillDmg / basicDmg, offensiveMultiplier; dodge only on basic attacks (Damage.paramsVsMonster);
-- rounding, minDamage and the 0.92-1.08 spread (mean 1) left out. Returns the expected damage.
-- S86: Spotting, Fury (AddFury on a hit that dealt damage), the item on-hit effects (applyOnHit), Saving Blow, kills.
dealDamage = function(state: any, tg: any, o: HitOpts): number
	if tg.hp <= 0 then
		return 0
	end
	local p = current(state)
	local v = p.values
	local attacker, _ = Damage.fromStats(p.level, v)
	local extra = o.extra or 1
	local force = o.forceShare or 0
	if o.consumeShot ~= false then
		if takeOne(state, "guaranteedCrit") then
			force = 1
		end
		local shot = takeOne(state, "nextShot")
		if shot then
			extra *= 1 + shot.value / 100
		end
	end
	local params: any = { kind = if o.magic then "magic" else "phys", isSkill = not o.basic, basic = o.basic }
	for _, e in effectsOf(tg, "sighted") do
		if e.stats then
			params.critAdd = e.stats.critChance
			params.critDmgAdd = e.stats.critDmg
		end
	end
	extra *= 1 + maxOf(state, tg, "vulnerability") / 100 -- StatusEffectService.Max: the strongest, never a sum
	local weak = hook(state, "weakSpot")
	if weak > 0 and not o.noProc and o.focus and not state.control then
		extra *= 1 + state.weakStacks * PathData.HOOK_RULES.weakSpotPerStack / 100
		state.weakStacks = math.min(weak, state.weakStacks + 1)
	end
	local armorBreak = categoryValue(state, tg, "enemyArmor")
	local defender = MonsterStats.asDefender(tg.m)
	local defense = Damage.defenseOf(params.kind, attacker, defender, armorBreak)
	local gapMul, gapCrit = Damage.levelGap(attacker.level, defender.level)
	local chance = Damage.critChance(attacker, params, gapCrit) / 100
	local critMul = Damage.critMultiplier(attacker.critDmg + (params.critDmgAdd or 0), defender.critResist)
	local critFactor = (1 - force) * (1 + chance * (critMul - 1)) + force * critMul
	local hitShare = if o.basic then 1 - Damage.dodgeChance(defender.dodge or 0, attacker.accuracy or 0) else 1
	local raw = (if o.magic then attacker.magAtk else attacker.physAtk) * o.percent / 100
	raw *= Damage.bonusMul(attacker, params)
	local amount = raw * (1 - Damage.reduction(defense, attacker.level)) * gapMul * critFactor
	-- element resistance: MonsterStats.asDefender gives monsters none (Damage.resMul would be 1)
	amount *= offensiveMultiplier(state, tg) * extra * hitShare * (o.scale or 1)
	if tg.invulnerable then
		amount = 0
	end
	local before = tg.hp
	tg.hp -= amount
	state.dealt += amount
	local bucket = o.bucket or "basic"
	state.by[bucket] = (state.by[bucket] or 0) + amount
	if o.basic then
		state.basicDealt += amount
	end
	if o.areaHit then
		state.areaDealt += amount
	end
	state.lastCrit = (1 - force) * chance + force
	if amount > 0 then
		local manaOnHit = hook(state, "manaOnHit")
		if manaOnHit > 0 and state.resource == "mana" then
			state.gainReturn(v.maxMana * manaOnHit / 100)
		end
		local lifesteal = math.clamp(v.lifesteal or 0, 0, LIFESTEAL_CAP) -- mirrors Damage.computeDamage
		if lifesteal > 0 then
			giveHeal(state, "self", amount * lifesteal / 100)
			state.lifestealHeal += amount * lifesteal / 100
		end
		if not state.control then
			if o.basic or (o.skill and PathData.HOOK_RULES.spot.skills[o.skill]) then
				spot(state, tg)
			end
			addFury(state)
			if not o.noProc then
				if tg.hp > 0 or tg.dummy then
					applyOnHit(state, tg, amount, o)
				end
				savingBlow(state, amount)
			end
		end
	end
	if before > 0 and tg.hp <= 0 and not tg.dummy then
		onKill(state, tg)
	end
	return amount
end

-- mirrors CombatService runThrough (S65): a landed basic hit with an enemy in the band behind the target hits it
-- for value % (basic, noProc); the band is not measured: ASSUMPTIONS.behindShare of the hits in a group (S84)
local function runThrough(state: any, tg: any, p: any)
	local value = hook(state, "traitRunThrough")
	local other = otherTarget(state, tg)
	if value <= 0 or not other then
		return
	end
	dealDamage(state, other, {
		magic = p.magic,
		percent = 100,
		extra = value / 100,
		basic = true,
		noProc = true,
		consumeShot = false,
		scale = A.behindShare,
	})
end

-- mirrors CombatService spark (S65): Traits.chance(traitSpark) per landed basic hit wakes the weapon element
-- (Skills/Elements.apply with the Spark's params, EffectStack.ITEM, accumulate; the arc a basic noProc hit)
local function spark(state: any, tg: any, p: any, hit: number)
	local value = hook(state, "traitSpark")
	if value <= 0 or not state.sp.element then
		return
	end
	if not proc(state, "spark", Traits.chance(value, 0, 1) / 100) then
		return
	end
	elementApply(state, tg, state.sp.element, SPARK_SPEC, hit, EffectStack.ITEM, function(other: any, pct: number)
		local before = state.dealt
		dealDamage(state, other, {
			magic = p.magic,
			percent = 100,
			extra = pct / 100,
			basic = true,
			noProc = true,
			consumeShot = false,
		})
		state.elementDealt += state.dealt - before
	end)
end

-- mirrors CombatService.tryBasicAttack (S85 C2): a swing every 1 / max(0.2, atkSpeed) from t = 0 (the speed of the
-- moment), doubleAttack as the expected second hit (no on-hit effects, nothing left to consume), the weapon element.
-- Swings keep their nominal times (nextBasic += interval, diag SkillEngine), so the step does not round the interval
-- up; AttackPose.hitDelay is left out: with the end-of-window correction it does not change the sum (DECYZJE).
-- S86: none while aiming or during a beam (the swing waits for the channel's end); Full Draw (the consumed
-- "nextBasic", Traits.drawBonus), Twin Cut (Traits.twinCut), then on a landed hit Run Through and Elemental Spark.
local function basicSwing(state: any)
	local p = current(state)
	local focus = alive(state)[1]
	if not focus then
		return
	end
	local o: HitOpts = {
		magic = p.magic,
		percent = 100,
		basic = true,
		focus = true,
	}
	local s86 = not state.control
	local twin = false
	local twinValue = if s86 then hook(state, "traitTwinCut") else 0
	if twinValue > 0 then
		state.twinCount, twin = Traits.twinCut(
			state.twinCount,
			state.twinAt,
			state.t,
			traitParam("twinCut", "every"),
			traitParam("twinCut", "reset")
		)
		state.twinAt = state.t
	end
	if s86 then
		local draw = takeOne(state, "nextBasic")
		if draw and (draw.value or 0) > 0 and draw.expiresAt > state.t + EPS then
			o.extra = 1 + Traits.drawBonus(draw.value, p.weaponSpeed) / 100
		end
	end
	local main = dealDamage(state, focus, o)
	local amount = main
	local double = hook(state, "doubleAttack")
	if double > 0 then
		local second = table.clone(o)
		second.consumeShot = false
		second.noProc = true
		second.extra = nil
		second.scale = math.clamp(double, 0, 100) / 100
		amount += dealDamage(state, focus, second)
	end
	if twin then
		amount += dealDamage(state, focus, {
			magic = p.magic,
			percent = 100,
			basic = true,
			noProc = true,
			consumeShot = false,
			extra = twinValue / 100,
		})
	end
	if s86 and main > 0 then
		runThrough(state, focus, p)
		spark(state, focus, p, main)
	end
	local interval = 1 / math.max(0.2, p.values.atkSpeed or 1)
	state.lastSwing = { at = state.nextBasic, interval = interval, amount = amount }
	state.nextBasic += interval
end

-- Handlers ----------------------------------------------------------------------------------------------------------

type Ctx = any

-- mirrors Skills/Context ctx.damage (S85 C3): execute (forceCrit share) and finisher on main hits, elemental /
-- holy hooks (PassiveHook), the weapon normalisation (speedMul), areaSkillDamage on area skills (not pulses or plain
-- hits), cdrPerTarget, the weapon element of adaptive skills (Traits.elementPlan), then the on-hit behaviours.
-- S86 (B14, B12): Skills.spellBonus of the tag (areaHits enemies in the wave, secondary hits) x Skills.resonanceMul
-- (mana before the cast) x castMul (Arcane Charges, empowered), none on zone ticks; Cascade (Skills.areaKillMana) on
-- kills; the adaptive element through Skills/Elements.apply (burn with accumulate, ice slow and Frostbite, arcs).
local damage: (ctx: Ctx, tg: any, percent: number, o: { [string]: any }?) -> number

local function elementalMultiplier(ctx: Ctx, holy: boolean?): number
	local mult = 1
	if ctx.element then
		mult += pathHook(ctx.state, "elementDamage") / 100
	end
	if ctx.def.holy or holy then
		mult += pathHook(ctx.state, "holyDamage") / 100
	end
	return mult
end

local function attackOf(ctx: Ctx): number
	local v = current(ctx.state).values
	return (if ctx.magic then v.magAtk or 0 else v.physAtk or 0) * ctx.state.sp.speedMul
end

-- ctx.heal: Context.healFrom with healFactor (S71).
local function heal(ctx: Ctx, who: string, amount: number)
	healFrom(ctx.state, who, amount)
end

local function maxHpOf(state: any, who: string): number
	if who == "tank" and state.heal then
		return state.heal.tank.values.maxHp
	end
	return current(state).values.maxHp
end

local function healAmount(ctx: Ctx, who: string, prefix: "heal" | "shield"): number
	local state = ctx.state
	return Skills.healAmount(
		ctx.def,
		ctx.rank,
		prefix,
		maxHpOf(state, who),
		current(state).values.magAtk or 0,
		state.sp.level
	)
end

-- Allies in reach: solo the caster; heal mode the caster and the tank (other members are not counted, F2).
local function allies(state: any): { string }
	return if state.heal then { "self", "tank" } else { "self" }
end

-- The self entity (statBuff, nextShot, ...) and the tank entity (heal over time) of heal mode.
local function entityOf(state: any, who: string): any
	return if who == "tank" then state.tank else state.self
end

-- S86 (B1) mirrors Skills/Context ctx.shield: an absorb shield of amount x healFactor(shield) on the ally; it counts
-- by its amount in the heal totals (S85 T-SK6) and, on the caster of a retaliate fight, soaks damage before HP. `onEnd`
-- (Shattering Shield) runs once when it breaks or expires with the starting value.
local function shield(ctx: Ctx, who: string, amount: number, duration: number, onEnd: ((any, number) -> ())?)
	local state = ctx.state
	if amount <= 0 or duration <= 0 then
		return
	end
	local value = amount * healFactor(state, who, true)
	state.healTo[who] = (state.healTo[who] or 0) + value
	apply(
		state,
		entityOf(state, who),
		"shield",
		{ duration = duration, value = value, skillId = ctx.id, onEnd = onEnd }
	)
end

-- mirrors Skills/Context applyEffect (S85 kinds; S86: burn ticks like bleed / poison with DotBonus, Carnage and the
-- furyConsume stats field (x the stacks this cast spent), ice control longer by Elements.power with Frostbite, the
-- dice scale / duration multiplier (EffectOptions), poison through CombatService.ApplyPoison)
local function applyEffect(ctx: Ctx, entity: any, effect: any, scale: number?, durationMul: number?)
	local state = ctx.state
	local kind = effect.kind
	local s = scale or 1
	local duration = Skills.scaled(ctx.def, effect.duration, ctx.rank) * (durationMul or 1)
	local raw = if type(effect.value) == "string"
		then Skills.valueAt(ctx.def, effect.value, ctx.rank)
		elseif type(effect.value) == "number" then effect.value
		else 0
	local value = raw * s
	local tickAmount: number? = nil
	if kind == "bleed" or kind == "poison" or kind == "burn" then
		tickAmount = math.max(1, attackOf(ctx) * value / 100 / math.max(1, duration))
			* (1 + dotBonus(state, kind) / 100)
	elseif kind == "hot" then
		if entity.who == nil then
			return
		end
		if effect.hpPct ~= nil then
			-- S73: hpPct % of the bearer's max HP per second x healFactor at the application
			tickAmount = maxHpOf(state, entity.who)
				* Skills.resolve(ctx.def, effect.hpPct, ctx.rank)
				/ 100
				* healFactor(state, entity.who, false)
				* s
		else
			-- S70 dice face Spring: value % of max HP every second, no heal bonus
			tickAmount = maxHpOf(state, entity.who) * value / 100
		end
	end
	local stats: { [string]: number }? = nil
	if effect.stats then
		local resolved: { [string]: number } = {}
		for stat, field in effect.stats do
			local base = Skills.valueAt(ctx.def, field, ctx.rank)
			if field == ctx.def.furyConsume then
				base *= ctx.furyUsed or 0 -- S73: once per Fury stack this cast spent
			end
			resolved[stat] = base * s
		end
		stats = resolved
	end
	local chilly = ctx.element == "ice" and state.sp.element == "ice" and (kind == "slow" or kind == "freeze")
	if chilly then
		duration *= 1 + math.max(0, hook(state, "elementRider")) / 100 -- Elements.power
	end
	local options = {
		duration = duration,
		value = value,
		tickAmount = tickAmount,
		stats = stats,
		pct = effect.pct,
		maxStacks = if kind == "bleed" then ctx.bp.bleedStacks elseif kind == "poison" then ctx.bp.poisonStacks else nil,
		skillId = ctx.id,
		category = effect.category,
		notBoss = effect.notBoss,
		area = Traits.isAreaSkill(ctx.def.type), -- the ticks of an area skill count in areaDealt (C3 areaShare)
	}
	local applied = if kind == "poison"
		then applyPoison(state, entity, options)
		else apply(state, entity, kind, options)
	if chilly and applied and entity.m ~= nil then
		chill(state, entity, duration)
	end
end

-- mirrors Skills/Context applyEffects (dice faces only through the roll)
local function applyEffects(ctx: Ctx, entity: any, side: string)
	for _, effect in ctx.def.effects or {} do
		if Skills.effectSide(ctx.def, effect) == side and not effect.face then
			applyEffect(ctx, entity, effect)
		end
	end
end

-- mirrors Skills/Context onHit (S28 / S69 / S71): Divine Wrath heal, lifesteal, healWounded, splash around the
-- main target; knockback and stunNear change nothing on a dummy.
local function onHit(ctx: Ctx, tg: any, percent: number, amount: number, o: { [string]: any })
	local state = ctx.state
	local share = 0
	if ctx.id == "holyStrike" then
		if o.primary then
			share = pathHook(state, "holyStrikeHeal")
		end
	elseif HOLY_HEAL_SKILLS[ctx.id] then
		local strength = pathHook(state, "holyHealAll")
		if strength > 0 then
			share = pathHook(state, "holyStrikeHeal") * strength / 100
		end
	end
	if share > 0 then
		heal(ctx, "self", amount * share / 100)
	end
	if ctx.bp.lifesteal then
		heal(ctx, "self", amount * ctx.bp.lifesteal / 100)
	end
	if ctx.bp.healWounded and o.primary then
		-- the most wounded ally: the tank in heal mode (no wound model, F2), the caster solo
		heal(ctx, if state.heal then "tank" else "self", amount * ctx.bp.healWounded / 100)
	end
	local splash = ctx.bp.splash
	if splash and o.primary then
		for _, other in alive(state) do
			if other ~= tg then
				damage(ctx, other, percent * splash.pct / 100, { plain = true, consumeShot = false, secondary = true })
			end
		end
	end
end

-- Arc and zone hits of the weapon element count in elementDealt (C3).
local function elementHit(ctx: Ctx, tg: any, percent: number, o: { [string]: any })
	local state = ctx.state
	local before = state.dealt
	damage(ctx, tg, percent, o)
	state.elementDealt += state.dealt - before
end

damage = function(ctx: Ctx, tg: any, percent: number, options: { [string]: any }?): number
	if tg.hp <= 0 then
		return 0
	end
	local state = ctx.state
	local o: { [string]: any } = options or {}
	local def, bp = ctx.def, ctx.bp
	local pct = percent
	local force = 0
	if bp.execute and not o.plain then
		force = belowShare(tg, bp.execute)
	end
	local finisher: any = def.finisher
	if finisher and finisher.hp and finisher.mul and not o.plain then
		pct *= 1 + belowShare(tg, finisher.hp) * (finisher.mul - 1)
	end
	local multiplier = elementalMultiplier(ctx, o.holy) * state.sp.speedMul
	local area = Traits.isAreaSkill(def.type)
	if area and not (o.plain or o.lingering) then
		multiplier *= 1 + hook(state, "areaSkillDamage") / 100
	end
	if not o.lingering and not state.control then
		-- S86 (B14) mirrors Context.damage (S79, S80)
		local bonus = Skills.spellBonus(ctx.tag, o.areaHits or 1, o.secondary == true, {
			areaDamage = pathHook(state, "areaDamage"),
			singleDamage = pathHook(state, "singleDamage"),
			spellDamage = pathHook(state, "spellDamage"),
		})
		multiplier *= (1 + bonus / 100) * Skills.resonanceMul(ctx.manaFraction, pathHook(state, "resonance")) * ctx.castMul
	end
	local before = tg.hp
	local amount = dealDamage(state, tg, {
		magic = ctx.magic,
		percent = pct,
		extra = multiplier,
		consumeShot = o.consumeShot ~= false,
		forceShare = force,
		noProc = o.plain == true or o.noAdaptive == true or o.noProc == true or o.secondary == true,
		bucket = ctx.id,
		focus = tg == alive(state)[1],
		area = area,
		skill = if o.plain then nil else ctx.id,
		areaHit = area,
	})
	-- S86 (B14) mirrors Context.damage Cascade: an area spell's kill gives areaKillMana % of max mana
	local killPct = pathHook(state, "areaKillMana")
	if killPct > 0 and not tg.dummy then
		local mana = Skills.areaKillMana(ctx.tag, before > 0 and tg.hp <= 0, amount, killPct, state.poolMax)
		if mana > 0 and state.resource == "mana" then
			state.gainReturn(mana)
			state.cascade += mana
		end
	end
	local cdr = bp.cdrPerTarget
	if cdr and not o.lingering and not ctx.struck[tg] and ctx.struckCount < cdr.max then
		ctx.struck[tg] = true
		ctx.struckCount += 1
		state.cd[ctx.id] = (state.cd[ctx.id] or 0) - cdr.sec
	end
	if def.adaptive and amount > 0 and not o.noAdaptive then
		-- mirrors Skills/Elements.apply with Data/Skills.ADAPTIVE (Context ADAPTIVE_SPEC), accumulate (S79)
		local spec: any = {
			burnPct = SkillData.ADAPTIVE.burnPct,
			burnDuration = SkillData.ADAPTIVE.burnDuration,
			slowPct = SkillData.ADAPTIVE.slowPct,
			slowDuration = SkillData.ADAPTIVE.slowDuration,
			arcPct = SkillData.ADAPTIVE.arcPct,
			arcRadius = SkillData.ADAPTIVE.arcRadius,
			exactTicks = SkillData.ADAPTIVE.exactTicks,
		}
		elementApply(state, tg, ctx.element, spec, amount, ctx.id, function(other: any, jumpPct: number)
			elementHit(
				ctx,
				other,
				percent * jumpPct / 100,
				{ noAdaptive = true, consumeShot = false, secondary = true }
			)
		end)
	end
	if amount > 0 and not o.plain then
		onHit(ctx, tg, percent, amount, o)
	end
	local critCdr = bp.critCdr
	if critCdr and not o.plain and not ctx.critCdrUsed and ctx.cooldown > 0 then
		-- the first crit of the cast: expected share of the cooldown (the chance of this hit)
		ctx.critCdrUsed = true
		state.cd[ctx.id] = (state.cd[ctx.id] or 0) - ctx.cooldown * critCdr / 100 * (state.lastCrit or 0)
	end
	return amount
end

-- mirrors Types/Offense hitAll: the enemy effects only with `withEffects`; S86: areaHits = #list unless given,
-- secondary hits say so (S79).
local function hitAll(ctx: Ctx, list: { any }, percent: number, withEffects: boolean, o: { [string]: any }?)
	local opts: { [string]: any } = table.clone(o or {})
	opts.areaHits = opts.areaHits or #list
	for _, tg in list do
		local amount = damage(ctx, tg, percent, opts)
		if withEffects and amount > 0 then
			applyEffects(ctx, tg, "enemy")
		end
	end
end

-- mirrors Skills/Context lingering + startZone: zones of the first wave (Skills.castZones with areaLingering),
-- floor(duration) pulses a second on every dummy as plain zone ticks (no spell bonuses); an element zone x
-- Elements.power with its ice slow and Frostbite, a poison zone x the Hunter's poison bonus, a zone slow (1.2 s).
local function lingering(ctx: Ctx, percent: number, wave: number, inCircle: number)
	local state = ctx.state
	for _, zone in Skills.castZones(ctx.def, ctx.bp, wave, percent, pathHook(state, "areaLingering"), inCircle) do
		local pulse = zone.pct
		local power = 1
		if zone.element then
			power = 1 + math.max(0, hook(state, "elementRider")) / 100
			pulse *= power
		elseif zone.kind == "poison" then
			pulse *= 1 + dotBonus(state, "poison") / 100
		end
		local frost = zone.element == true and state.sp.element == "ice"
		for second = 1, math.floor(zone.duration) do
			schedule(state, state.t + second, function()
				for _, tg in alive(state) do
					local opts = {
						plain = true,
						consumeShot = false,
						lingering = true,
						noAdaptive = if zone.element then true else nil,
					}
					if zone.element then
						elementHit(ctx, tg, pulse, opts)
					else
						damage(ctx, tg, pulse, opts)
					end
					if zone.slow then
						apply(
							state,
							tg,
							"slow",
							{ duration = 1.2, value = zone.slow, skillId = ctx.id, category = "enemySlow" }
						)
					end
					if frost then
						local duration = 1.2 * power
						if
							apply(state, tg, "slow", {
								duration = duration,
								value = SkillData.ADAPTIVE.slowPct,
								skillId = ctx.id .. ":zone",
								category = "enemySlow",
							})
						then
							chill(state, tg, duration)
						end
					end
				end
			end)
		end
	end
end

local function at(ctx: Ctx, delay: number, fn: () -> ())
	if delay <= EPS then
		fn()
	else
		schedule(ctx.state, ctx.state.t + delay, fn)
	end
end

-- Handlers by type (SkillService HANDLERS). Each returns false when it refuses (nothing spent).
SkillModel.HANDLERS = {} :: { [string]: (ctx: Ctx) -> boolean }
local H = SkillModel.HANDLERS

-- mirrors Types/Offense.target: furyConsume spends every Fury stack for x Skills.furyMultiplier (S73, B5; spent even
-- when the blow is dodged), stunSplash on a stunned target (S71)
H.target = function(ctx)
	local state = ctx.state
	local tg = alive(state)[1]
	if not tg then
		return false
	end
	local percent = Skills.valueAt(ctx.def, "dmg", ctx.rank)
	if ctx.def.furyConsume then
		local stacks
		state.fury, stacks = Fury.consume(state.fury) -- mirrors Context.consumeFury / StatusEffectService.ConsumeFury
		ctx.furyUsed = stacks
		state.furyConsumed += stacks
		percent *= Skills.furyMultiplier(Skills.valueAt(ctx.def, ctx.def.furyConsume, ctx.rank), stacks)
	end
	local amount = damage(ctx, tg, percent, { primary = true })
	if amount > 0 then
		applyEffects(ctx, tg, "enemy")
		if ctx.bp.stunSplash and #effectsOf(tg, "stun") > 0 then
			local splash = percent * Skills.valueAt(ctx.def, "stunSplash", ctx.rank) / 100
			for _, other in alive(state) do
				if other ~= tg then
					damage(ctx, other, splash, { plain = true, consumeShot = false })
				end
			end
		end
	end
	return true
end

-- mirrors Types/Offense.projectile: `hits` shots every `interval` (0.15), only the first consumes and pierces,
-- every shot that lands applies the effects, Storm Arrow's splash (values.splash) around the target.
H.projectile = function(ctx)
	local state = ctx.state
	local tg = alive(state)[1]
	if not tg then
		return false
	end
	local hits = ctx.def.hits or 1
	local interval = ctx.def.interval or 0.15
	for shot = 1, hits do
		at(ctx, (shot - 1) * interval, function()
			if tg.hp <= 0 then
				return
			end
			local percent = Skills.valueAt(ctx.def, "dmg", ctx.rank)
			local amount = damage(ctx, tg, percent, { consumeShot = shot == 1, primary = shot == 1 })
			if amount > 0 then
				applyEffects(ctx, tg, "enemy")
			end
			local share = ctx.bp.pierce
			if shot == 1 and share then
				local list = alive(state)
				local nextOne = list[2]
				if nextOne and nextOne ~= tg then
					damage(
						ctx,
						nextOne,
						percent * share / 100,
						{ consumeShot = false, noProc = true, secondary = true }
					)
				end
			end
			if ctx.def.values.splash and ctx.def.radius then
				local others = {}
				for _, x in alive(state) do
					if x ~= tg then
						table.insert(others, x)
					end
				end
				hitAll(ctx, others, Skills.valueAt(ctx.def, "splash", ctx.rank), false, { secondary = true })
			end
		end)
	end
	return true
end

-- mirrors Types/Offense.cone (a volley: N arrows over the enemies every 0.06 s; effects from the first arrow on each;
-- every arrow counts the enemies in the cone, S79)
H.cone = function(ctx)
	local state = ctx.state
	local enemies = alive(state)
	local hits = ctx.def.hits
	if hits and #enemies > 0 then
		local n = #enemies
		for i = 1, hits do
			local tg = enemies[(i - 1) % n + 1]
			schedule(state, state.t + i * 0.06, function()
				local amount =
					damage(ctx, tg, Skills.valueAt(ctx.def, "dmg", ctx.rank), { consumeShot = i == 1, areaHits = n })
				if amount > 0 and i <= n then
					applyEffects(ctx, tg, "enemy")
				end
			end)
		end
	else
		hitAll(ctx, enemies, Skills.valueAt(ctx.def, "dmg", ctx.rank), true)
	end
	return true
end

-- S86 (B1) mirrors Types/Offense shieldPerHit (S73, Defender's Oath): a shield on the caster, hpPct % of its max HP
-- per monster of the first wave, at most `max` of them, through ctx.shield
local function shieldPerHit(ctx: Ctx, count: number)
	local spec = ctx.bp.shieldPerHit
	if not spec or count <= 0 then
		return
	end
	local maxHp = current(ctx.state).values.maxHp
	shield(
		ctx,
		"self",
		maxHp * Skills.resolve(ctx.def, spec.hpPct, ctx.rank) / 100 * math.min(count, spec.max),
		spec.duration
	)
end

-- mirrors Types/Offense.circleSelf: waves every `interval` (0.4), effects from the first, Radiance heals allies,
-- the zones, the echo wave; the caster's own effects (Taunt's armour); S86 shieldPerHit on the first wave.
H.circleSelf = function(ctx)
	local state = ctx.state
	local def = ctx.def
	local hasDamage = def.values.dmg ~= nil
	local hits = def.hits or 1
	local interval = def.interval or 0.4
	local function wave(n: number, percent: number)
		local enemies = alive(state)
		if hasDamage then
			hitAll(ctx, enemies, percent, n == 1)
		elseif n == 1 then
			for _, tg in enemies do
				applyEffects(ctx, tg, "enemy")
			end
		end
		if n == 1 then
			shieldPerHit(ctx, #enemies)
		end
		if n == 1 and def.values.heal and hasDamage then
			local amount = attackOf(ctx)
				* Skills.valueAt(def, "dmg", ctx.rank)
				/ 100
				* Skills.valueAt(def, "heal", ctx.rank)
				/ 100
				* Skills.healMul(state.sp.level)
			for _, who in allies(state) do
				heal(ctx, who, amount)
			end
		end
		if hasDamage then
			lingering(ctx, percent, n, 0)
		end
	end
	local dmg = if hasDamage then Skills.valueAt(def, "dmg", ctx.rank) else 0
	for n = 1, hits do
		at(ctx, (n - 1) * interval, function()
			wave(n, dmg)
		end)
	end
	local echo = ctx.bp.echo
	if echo and hasDamage then
		at(ctx, (hits - 1) * interval + echo.delay, function()
			wave(hits + 1, dmg * echo.pct / 100)
		end)
	end
	applyEffects(ctx, state.self, "self")
	return true
end

-- mirrors Types/Offense.circleTarget (S85 C5): share of a meteor storm's impacts that hit a dummy at the aim point;
-- a storm (hits > 1 and delay > 0) strikes circles of max(4, r / 3) at a distance uniform in [0, r - r_i] from the
-- point; enemiesInCircle's tolerance 1.5. 1 for every other circle.
function SkillModel.stormShare(def: any): number
	local radius = def.radius or 8
	local hits = def.hits or 1
	if not (hits > 1 and (def.delay or 0) > 0) then
		return 1
	end
	local impactRadius = math.max(4, radius / 3)
	return math.min(1, (impactRadius + CIRCLE_TOLERANCE) / math.max(0.01, radius - impactRadius))
end

-- mirrors Types/Offense.circleTarget: `delay` (+ Push.DURATION after a pull), waves every `interval` (0.5),
-- firstWave, a meteor storm's impacts, Thunderstorm's bolt (one random enemy: 1 / n each, the wave counts the circle:
-- Skills.areaCount), effects from the first wave, the zones, the split blasts (3.5 studs) and the echo.
H.circleTarget = function(ctx)
	local state = ctx.state
	local def = ctx.def
	if def.values.dmg == nil then
		return true
	end
	local hits = def.hits or 1
	local interval = def.interval or 0.5
	local delay = def.delay or 0
	if Skills.pullRadius(def, ctx.bp) > 0 then
		delay = math.max(delay, PUSH_DURATION) -- S76: pulled enemies reach the point first
	end
	local stormShare = SkillModel.stormShare(def)
	local dmg = Skills.valueAt(def, "dmg", ctx.rank)
	local firstPercent = dmg * (1 + (ctx.bp.firstWave or 0) / 100)
	for w = 1, hits do
		at(ctx, delay + (w - 1) * interval, function()
			local enemies = alive(state)
			local percent = if w == 1 then firstPercent else dmg
			if def.randomTarget then
				local n = #enemies
				if n > 0 then
					hitAll(ctx, enemies, percent / n, true, { areaHits = Skills.areaCount(def, n, 1) })
				end
				lingering(ctx, dmg, w, n)
				return
			end
			hitAll(ctx, enemies, percent * stormShare, w == 1)
			lingering(ctx, dmg, w, 0)
			local split = ctx.bp.split
			if w == 1 and split then
				local reach = SPLIT_RADIUS + CIRCLE_TOLERANCE
				local hitsDummies = split.radius - A.dummySpread <= reach
				for i = 1, split.count do
					at(ctx, 0.15 + i * 0.08, function()
						if hitsDummies then
							hitAll(ctx, alive(state), dmg * split.pct / 100, false, { secondary = true })
						end
					end)
				end
			end
		end)
	end
	local echo = ctx.bp.echo
	if echo then
		at(ctx, delay + (hits - 1) * interval + echo.delay, function()
			hitAll(ctx, alive(state), dmg * echo.pct / 100, false)
		end)
	end
	return true
end

-- mirrors Types/Offense.line (with a duration: floor(duration / interval) hits without effects)
H.line = function(ctx)
	local state = ctx.state
	local duration = Skills.scaled(ctx.def, ctx.def.duration, ctx.rank)
	local dmg = Skills.valueAt(ctx.def, "dmg", ctx.rank)
	if duration > 0 then
		local interval = ctx.def.interval or 0.5
		for i = 1, math.floor(duration / interval) do
			schedule(state, state.t + i * interval, function()
				hitAll(ctx, alive(state), dmg, false)
			end)
		end
	else
		hitAll(ctx, alive(state), dmg, true)
	end
	return true
end

-- mirrors Types/Offense.chain: the path first (Logic/Chain.path; dummies at one point: index order), -10 % a jump,
-- every hit counts the chain's length (areaHits, S79)
H.chain = function(ctx)
	local state = ctx.state
	local list = alive(state)
	if #list == 0 then
		return false
	end
	local jumps = math.floor(Skills.valueAt(ctx.def, "jumps", ctx.rank) + 0.5)
	local points = {}
	for _ = 1, #list do
		table.insert(points, { x = 0, z = A.dummySpread })
	end
	local order = Chain.path(points, 1, (ctx.def.radius or 12) + CIRCLE_TOLERANCE, jumps)
	local percent = Skills.valueAt(ctx.def, "dmg", ctx.rank)
	for i, index in order do
		local tg = list[index]
		local amount = damage(
			ctx,
			tg,
			percent * (1 - 0.1 * (i - 1)),
			{ consumeShot = i == 1, primary = i == 1, areaHits = #order }
		)
		if amount > 0 then
			applyEffects(ctx, tg, "enemy")
		end
	end
	return true
end

-- S86: a leap or a blink moves the caster (the Runic Seal breaks: CombatService.BreakSeal / pollSeal)
local function moved(state: any)
	state.sealSince = state.t
	state.sealLit = false
end

-- mirrors Types/Movement.charge (the blow 0.15 s after the leap)
H.charge = function(ctx)
	local state = ctx.state
	local tg = alive(state)[1]
	if not tg then
		return false
	end
	moved(state)
	schedule(state, state.t + 0.15, function()
		local amount = damage(ctx, tg, Skills.valueAt(ctx.def, "dmg", ctx.rank), { primary = true })
		if amount > 0 then
			applyEffects(ctx, tg, "enemy")
		end
	end)
	return true
end

-- mirrors Types/Movement.blink: the caster's effects (Disengage's next shot), BreakSeal; the breakpoint's slowing trap
-- stays where the caster stood (no dummy walks there)
H.blink = function(ctx)
	moved(ctx.state)
	applyEffects(ctx, ctx.state.self, "self")
	return true
end

-- Traps (B8) ------------------------------------------------------------------------------------------------------

-- mirrors Types/Movement fire: values.dmg and the enemy effects on everyone caught (on those hit when it deals
-- damage; trapRootDuration lengthens roots), trapEnergy once per trap (hook x min(caught, TRAP_ENERGY_MAX)), the
-- breakpoint's echo (damage only, after its delay).
local function fireTrap(ctx: Ctx, caught: { any })
	local state = ctx.state
	state.trapsFired += 1
	local hasDamage = ctx.def.values.dmg ~= nil
	local rootBonus = hook(state, "trapRootDuration")
	for _, tg in caught do
		local hit = true
		if hasDamage then
			hit = damage(ctx, tg, Skills.valueAt(ctx.def, "dmg", ctx.rank), {}) > 0
		end
		if hit then
			for _, effect in ctx.def.effects or {} do
				if Skills.effectSide(ctx.def, effect) == "enemy" and not effect.face then
					if effect.kind == "root" and rootBonus > 0 then
						local longer = table.clone(effect)
						longer.duration = Skills.scaled(ctx.def, effect.duration, ctx.rank) + rootBonus
						applyEffect(ctx, tg, longer)
					else
						applyEffect(ctx, tg, effect)
					end
				end
			end
		end
	end
	local energy = hook(state, "trapEnergy")
	if energy > 0 and #caught > 0 and state.resource == "energy" then
		state.gainReturn(energy * math.min(#caught, SkillData.TRAP_ENERGY_MAX))
	end
	local echo = ctx.bp.echo
	if echo and hasDamage then
		schedule(state, state.t + echo.delay, function()
			for _, tg in caught do
				damage(ctx, tg, Skills.valueAt(ctx.def, "dmg", ctx.rank) * echo.pct / 100, {})
			end
		end)
	end
end

-- mirrors Types/Movement arm: wait TRAP_CHECK, then look for enemies (a trap under a standing dummy fires at the
-- first check); a pulling trap fires Push.DURATION after the pull; `catch` = how many of the dummies it reaches.
local function armTrap(ctx: Ctx, catch: number)
	local state = ctx.state
	local lifetime = Skills.scaled(ctx.def, ctx.def.duration, ctx.rank)
	if catch <= 0 or lifetime < TRAP_CHECK then
		return
	end
	local check = if state.instantTraps then 0 else TRAP_CHECK
	local pullWait = if state.instantTraps then 0 else PUSH_DURATION
	at(ctx, check, function()
		local list = alive(state)
		local caught = {}
		for i = 1, math.min(catch, #list) do
			table.insert(caught, list[i])
		end
		if #caught == 0 then
			return
		end
		if Skills.pullRadius(ctx.def, ctx.bp) > 0 then
			at(ctx, pullWait, function()
				fireTrap(ctx, caught)
			end)
		else
			fireTrap(ctx, caught)
		end
	end)
end

-- mirrors Types/Movement.trap (S76): `hits` traps, in a ring of ringRadius (SkillGeom.ringPoints) or side by side
-- (SkillGeom.sidePoints, SkillData.TRAP_SIDE_OFFSET). Dummies stand at the aim point: the first trap catches all of
-- them (a ring: the group walks into one snare), every further trap floor(groupSpread x n) of them (ASSUMPTIONS,
-- DECYZJE S86: one target stands in the first trap only).
SkillModel.trapCatch = function(index: number, n: number): number
	return if index == 1 then n else math.floor(A.groupSpread * n + EPS)
end
H.trap = function(ctx)
	local state = ctx.state
	local count = math.max(1, math.floor((ctx.def.hits or 1) + 0.5))
	local points = if count == 1
		then { { x = 0, z = 0 } }
		elseif (ctx.def.ringRadius or 0) > 0 then SkillGeom.ringPoints(
			0,
			0,
			ctx.def.ringRadius,
			count,
			SkillGeom.angle(0, 10, 0, 0)
		)
		else SkillGeom.sidePoints(0, 10, 0, 0, count, SkillData.TRAP_SIDE_OFFSET)
	local n = #alive(state)
	for i = 1, #points do
		armTrap(ctx, SkillModel.trapCatch(i, n))
	end
	return true
end

-- Support ---------------------------------------------------------------------------------------------------------

-- mirrors Types/Support.buff (S73): Fury first (furyConsume: every stack, the stats field x the stacks), the caster's
-- own effects, the party pass on the caster (allyPass: effects on "allies", allyEffects, allyHeal, allyShield);
-- behindEffect needs an ally behind the caster (none solo).
H.buff = function(ctx)
	local state = ctx.state
	if ctx.def.furyConsume then
		local stacks
		state.fury, stacks = Fury.consume(state.fury) -- before the effects: Carnage's stats read the stacks (S74)
		ctx.furyUsed = stacks
		state.furyConsumed += stacks
	end
	applyEffects(ctx, state.self, "self")
	if Skills.hasAllyPass(ctx.def, ctx.bp) then
		applyEffects(ctx, state.self, "allies")
		for _, effect in ctx.def.allyEffects or {} do
			applyEffect(ctx, state.self, effect)
		end
		local maxHp = current(state).values.maxHp
		local allyHeal, allyShield = ctx.bp.allyHeal, ctx.bp.allyShield
		if allyHeal then
			heal(ctx, "self", maxHp * Skills.resolve(ctx.def, allyHeal.hpPct, ctx.rank) / 100)
		end
		if allyShield then
			shield(ctx, "self", maxHp * Skills.resolve(ctx.def, allyShield.hpPct, ctx.rank) / 100, allyShield.duration)
		end
	end
	return true
end

-- The falcon (B9) -----------------------------------------------------------------------------------------------

local ROYAL = PathData.HOOK_RULES.royalFalcon

-- mirrors Skills/Companion strike: consumeShot = false, primary, noProc; the enemy effects on a hit, the Royal Falcon
-- spots (CombatService.Spot); a dive stuns monsters other than bosses (notBoss)
local function falconStrike(state: any, tg: any, pct: number, dive: boolean)
	local f = state.falcon
	local ctx = f.ctx
	state.falconStrikes += 1
	local amount = damage(ctx, tg, pct, { consumeShot = false, primary = true, noProc = true })
	if amount > 0 then
		applyEffects(ctx, tg, "enemy")
		if hook(state, "royalFalcon") > 0 then
			spot(state, tg)
		end
		if dive then
			apply(state, tg, "stun", { duration = ROYAL.stun, skillId = ctx.id, notBoss = true })
		end
	end
end

-- mirrors Skills/Companion tick: the next tick scheduled first, a strike on the target for dmg x (1 + falconDamage);
-- without the keystone the falcon stops at endsAt (the Royal Falcon stays to the end of the fight)
local function falconTick(state: any, token: number)
	local f = state.falcon
	if not f or f.token ~= token then
		return
	end
	if not f.royal and state.t + EPS >= f.endsAt then
		state.falcon = nil
		return
	end
	schedule(state, state.t + f.interval, function()
		falconTick(state, token)
	end)
	local tg = alive(state)[1]
	if tg then
		local ctx = f.ctx
		falconStrike(
			state,
			tg,
			Skills.valueAt(ctx.def, "dmg", ctx.rank) * (1 + hook(state, "falconDamage") / 100),
			false
		)
	end
end

-- mirrors Skills/Companion.start: duration + falconBond (the keystone: the whole fight), interval
-- max(HOOK_RULES.royalFalcon.minInterval, interval x (1 - falconInterval %)), the first strike after `delay` (1 s)
H.companion = function(ctx)
	local state = ctx.state
	local royal = hook(state, "royalFalcon") > 0
	local duration = Skills.scaled(ctx.def, ctx.def.duration, ctx.rank)
		+ (if royal then 0 else hook(state, "falconBond"))
	local interval = math.max(ROYAL.minInterval, (ctx.def.interval or 2) * (1 - hook(state, "falconInterval") / 100))
	state.falconToken += 1
	local token = state.falconToken
	state.falcon = { token = token, ctx = ctx, endsAt = state.t + duration, interval = interval, royal = royal }
	schedule(state, state.t + (ctx.def.delay or 1), function()
		falconTick(state, token)
	end)
	return true
end
SkillModel.falconInterval = function(def: any, falconInterval: number): number
	return math.max(ROYAL.minInterval, (def.interval or 2) * (1 - falconInterval / 100))
end

-- mirrors Types/Support.debuff: enemy effects on the target and, with a radius, on every other dummy; S86: Hunter's
-- Mark sends the Royal Falcon diving (Companion.dive: (dive + falconBond x bondDive) % x (1 + falconDamage %))
H.debuff = function(ctx)
	local state = ctx.state
	local list = alive(state)
	local tg = list[1]
	if not tg then
		return false
	end
	applyEffects(ctx, tg, "enemy")
	if (ctx.def.radius or 0) > 0 then
		for _, other in list do
			if other ~= tg then
				applyEffects(ctx, other, "enemy")
			end
		end
	end
	if ctx.id == "huntersMark" and state.falcon and hook(state, "royalFalcon") > 0 then
		local pct = (ROYAL.dive + hook(state, "falconBond") * ROYAL.bondDive) * (1 + hook(state, "falconDamage") / 100)
		falconStrike(state, tg, pct, true)
	end
	return true
end

-- The ally a heal helps (Support allyTarget): heal mode: entries with target "tank" / "mostWounded" or without a
-- target heal the tank (F2); solo the caster.
local function healTarget(ctx: Ctx): string
	local state = ctx.state
	if not state.heal then
		return "self"
	end
	local target = ctx.entry.target
	if target == "self" then
		return "self"
	end
	return "tank"
end

-- mirrors Types/Support healOne: the heal, and with overhealShield the overflow becomes an 8 s shield (the HP track
-- of a retaliate fight only: elsewhere nothing overflows, S85 F2)
local function healOne(ctx: Ctx, who: string, amount: number)
	local state = ctx.state
	local attempted = amount * healFactor(state, who, false)
	local before = state.healEff
	giveHeal(state, who, attempted)
	if ctx.bp.overhealShield and state.retaliate and who == "self" then
		local overflow = attempted - (state.healEff - before)
		if overflow > 1 then
			apply(state, state.self, "shield", { duration = 8, value = overflow, skillId = ctx.id })
		end
	end
end

-- HP share of an ally for chainHeal / most wounded (heal mode: every member is wounded, the tank most)
local function woundOf(state: any, who: string): number
	if state.retaliate and who == "self" then
		return state.hp / math.max(1, state.maxHp)
	end
	if state.heal then
		return if who == "tank" then 0.5 else 0.99
	end
	return 1
end

-- mirrors Types/Support.heal (S69): healOne on the target, the Purify 5B burst on every dummy, chainHeal (10B): the
-- heal jumps to more wounded allies (Skills.chainOrder of the others, Skills.chainShare); secondTarget needs a second
-- member (F2: none).
H.heal = function(ctx)
	local state = ctx.state
	local who = healTarget(ctx)
	healOne(ctx, who, healAmount(ctx, who, "heal"))
	local burst = ctx.bp.burst
	if burst then
		for _, tg in alive(state) do
			damage(ctx, tg, burst.pct, { plain = true, consumeShot = false, holy = true })
		end
	end
	local chain = ctx.bp.chainHeal
	if chain then
		local pool, fractions = {}, {}
		for _, other in allies(state) do
			if other ~= who then
				table.insert(pool, other)
				table.insert(fractions, woundOf(state, other))
			end
		end
		for k, index in Skills.chainOrder(fractions, chain.jumps) do
			local ally = pool[index]
			healOne(ctx, ally, healAmount(ctx, ally, "heal") * Skills.chainShare(chain.pct, k))
		end
	end
	return true
end

-- mirrors Types/Support.hot: the sum at the cast x healFactor over the ticks of a "hot" effect
H.hot = function(ctx)
	local state = ctx.state
	local who = healTarget(ctx)
	local duration = Skills.scaled(ctx.def, ctx.def.duration, ctx.rank)
	local total = healAmount(ctx, who, "heal") * healFactor(state, who, false)
	apply(state, entityOf(state, who), "hot", {
		duration = duration,
		tickAmount = total / math.max(1, duration),
		skillId = ctx.id,
	})
	return true
end

-- mirrors Types/Support.shield + burstOnEnd (S71 Shattering Shield): when the shield breaks or expires the bearer
-- (the ally within the radius, F2) heals values.shieldBurst % of its starting value through the caster's heal
H.shield = function(ctx)
	local who = healTarget(ctx)
	local duration = Skills.scaled(ctx.def, ctx.def.duration, ctx.rank)
	local onEnd: ((any, number) -> ())? = nil
	if ctx.bp.shieldBurst then
		local share = Skills.valueAt(ctx.def, "shieldBurst", ctx.rank)
		onEnd = function(_bearer: any, initial: number)
			if share > 0 and initial > 0 then
				heal(ctx, who, initial * share / 100)
			end
		end
	end
	shield(ctx, who, healAmount(ctx, who, "shield"), duration, onEnd)
	return true
end

-- Who stands in a heal zone (ASSUMPTIONS.zoneInside, ROZWOJ 9.3).
local function inZone(state: any, who: string): boolean
	if who == "tank" then
		return A.zoneInside.tank
	end
	if state.heal then
		return if state.sp.ranged then A.zoneInside.ranged else A.zoneInside.melee
	end
	return A.zoneInside.solo
end

-- S86 (B4) mirrors Skills/Context ctx.healZone: every second for floor(duration) s each ally inside heals share % of
-- their own heal of this skill (Skills.healAmount at the tick, healFactor), then onTick (Sanctuary 10B's allyGuard)
local function healZone(ctx: Ctx, duration: number, share: number, extras: { any }?)
	local state = ctx.state
	for second = 1, math.floor(duration) do
		schedule(state, state.t + second, function()
			for _, who in allies(state) do
				if inZone(state, who) then
					heal(ctx, who, healAmount(ctx, who, "heal") * share / 100)
					for _, effect in extras or {} do
						applyEffect(ctx, entityOf(state, who), effect)
					end
				end
			end
		end)
	end
end
SkillModel.zoneTicks = function(duration: number): number
	return math.floor(duration)
end

-- mirrors Types/Support.healZone (S70 Sanctuary): a field for the skill's duration, share 100, allyEffects per tick
H.healZone = function(ctx)
	healZone(ctx, Skills.scaled(ctx.def, ctx.def.duration, ctx.rank), 100, ctx.def.allyEffects)
	return true
end

-- mirrors Types/Support.groupHeal: every ally in reach heals their own amount (F2: the tank's part counts); S86 the
-- Circle of Light 10B field (healZone with its duration and pct)
H.groupHeal = function(ctx)
	local state = ctx.state
	for _, who in allies(state) do
		heal(ctx, who, healAmount(ctx, who, "heal"))
		for _, effect in ctx.def.allyEffects or {} do
			applyEffect(ctx, entityOf(state, who), effect)
		end
	end
	local zone = ctx.bp.healZone
	if zone then
		healZone(ctx, zone.duration, zone.pct, nil)
	end
	return true
end

-- S86 (B2): expected multiplier of each face of a roll of `n` faces: every outcome of Logic/Roll.pick (one face
-- 1 / n; with rollDouble % a second, different face) or of the wheel's pointed face (Roll.face) with its
-- probability, times Roll.multipliers. Returns { [face] = expected multiplier }.
function SkillModel.diceExpected(n: number, double: number, all: boolean, boost: number): { number }
	local out: { number } = {}
	for i = 1, n do
		out[i] = 0
	end
	local function add(picked: { number }, p: number)
		for i, m in Roll.multipliers(n, picked, all, boost) do
			out[i] += p * m
		end
	end
	for f = 1, n do
		if all or n <= 1 or double <= 0 then
			add({ f }, 1 / n)
		else
			add({ f }, (1 - double / 100) / n)
			for g = 1, n do
				if g ~= f then
					add({ f, g }, double / 100 / n / (n - 1))
				end
			end
		end
	end
	return out
end

-- S86 (B2) mirrors Skills/Context rollDice: the faces (effects with `face`) on every ally in the radius as expected
-- values (SkillModel.diceExpected scales each face's value), half = one face for half the duration (Prayer 5B); the
-- wheel (roll.all) puts the enemy effects (misfortune) on enemies within roll.enemyRadius.
local function rollDice(ctx: Ctx, half: boolean)
	local state = ctx.state
	local faces = {}
	for _, effect in ctx.def.effects or {} do
		if effect.face then
			table.insert(faces, effect)
		end
	end
	local n = #faces
	if n == 0 then
		return
	end
	local spec = ctx.def.roll
	local all = not half and spec ~= nil and spec.all == true
	local boost = if ctx.def.values.boost ~= nil then Skills.valueAt(ctx.def, "boost", ctx.rank) else 0
	local double = if half then 0 else ctx.bp.rollDouble or 0
	local expected = SkillModel.diceExpected(n, double, all, boost)
	for _, who in allies(state) do
		for i, face in faces do
			if expected[i] > 0 then
				applyEffect(ctx, entityOf(state, who), face, expected[i], if half then 0.5 else 1)
			end
		end
	end
	if all and spec then
		for _, tg in alive(state) do
			applyEffects(ctx, tg, "enemy")
		end
	end
end

-- mirrors Types/Support.groupBuff: the party copies on the caster (solo), the own effects, the dice (S86 B2),
-- Divine Intervention's % max HP heal
H.groupBuff = function(ctx)
	local state = ctx.state
	applyEffects(ctx, state.self, "allies")
	for _, effect in ctx.def.allyEffects or {} do
		applyEffect(ctx, state.self, effect)
	end
	applyEffects(ctx, state.self, "self")
	if ctx.def.roll then
		rollDice(ctx, false)
	end
	if ctx.id == "divineIntervention" then
		for _, who in allies(state) do
			heal(ctx, who, maxHpOf(state, who) * Skills.valueAt(ctx.def, "heal", ctx.rank) / 100)
		end
	end
	return true
end

-- Without a dead ally the server refuses Resurrection (nothing spent): never cast on a dummy.
H.resurrect = function(_ctx)
	return false
end

-- S86 mirrors Types/Movement.guard (S74): without an ally to protect (solo, F2) the self variant: the guard's own
-- reduction only, no selfEffects (skipSelfEffects); the intercept itself is Logic/Intercept (B7, boss report)
H.guard = function(ctx)
	ctx.skipSelfEffects = true
	applyEffects(ctx, ctx.state.self, "self")
	return true
end

-- S86 mirrors Types/Support.shout (S74): allies in the radius (the caster too, never an intercept on itself) get the
-- ally effects and allyEffects, the caster its own; enemies in hitRadius take values.dmg (effects on a hit) or the
-- enemy effects (taunt)
H.shout = function(ctx)
	local state = ctx.state
	for _, effect in ctx.def.effects or {} do
		if Skills.effectSide(ctx.def, effect) == "allies" and effect.kind ~= "intercept" then
			applyEffect(ctx, state.self, effect)
		end
	end
	for _, effect in ctx.def.allyEffects or {} do
		applyEffect(ctx, state.self, effect)
	end
	applyEffects(ctx, state.self, "self")
	local hasDamage = ctx.def.values.dmg ~= nil
	for _, tg in alive(state) do
		if hasDamage then
			if damage(ctx, tg, Skills.valueAt(ctx.def, "dmg", ctx.rank), {}) > 0 then
				applyEffects(ctx, tg, "enemy")
			end
		else
			applyEffects(ctx, tg, "enemy")
		end
	end
	return true
end

-- S86 mirrors Types/Movement.banner + PartyAuraService zones (S74): a pulse at once and every AURA.tick s while the
-- banner stands; each pulse gives the allies in the circle (the owner stands in it) the ally effects and allyEffects
-- for AURA.duration s, enemies the enemy effects
H.banner = function(ctx)
	local state = ctx.state
	local AURA = PathData.AURA
	local duration = Skills.scaled(ctx.def, ctx.def.duration, ctx.rank)
	local allyEffects, enemyEffects = {}, {}
	local function pulsed(effect: any): any
		local copy = table.clone(effect)
		copy.duration = AURA.duration
		return copy
	end
	for _, effect in ctx.def.effects or {} do
		local side = Skills.effectSide(ctx.def, effect)
		if side == "allies" then
			table.insert(allyEffects, pulsed(effect))
		elseif side == "enemy" then
			table.insert(enemyEffects, pulsed(effect))
		end
	end
	for _, effect in ctx.def.allyEffects or {} do
		table.insert(allyEffects, pulsed(effect))
	end
	local endsAt = state.t + duration
	local k = 0
	while k * AURA.tick < duration - EPS do
		at(ctx, k * AURA.tick, function()
			if state.t + EPS >= endsAt then
				return
			end
			for _, effect in allyEffects do
				applyEffect(ctx, state.self, effect)
			end
			for _, tg in alive(state) do
				for _, effect in enemyEffects do
					applyEffect(ctx, tg, effect)
				end
			end
		end)
		k += 1
	end
	return true
end

-- The beam (B11) --------------------------------------------------------------------------------------------------

-- S86 mirrors Types/Offense.beam + SkillService.startBeam / startChannel (S80): refused without mana for one tick
-- (Skills.drain with the cast's CostMods); Skills.beamTicks ticks every interval on the 0.1 s poll grid, each drains
-- its mana first (none left: the beam ends, Channel.stops "noMana") and deals Skills.beamTickPct; Master Mind's
-- channelGuard for the whole beam; basic attacks and other casts wait (14.4). Damage never ends it.
-- S86 mirrors SkillService.startChannel (S79): Master Mind's channelGuard (Skills.channelGuard) on the caster for a
-- channel or a beam; closeChannel takes it off at any exit (endChannel).
local function channelGuardOn(state: any, kind: string, duration: number)
	local guard = Skills.channelGuard(kind, pathHook(state, "channelGuard"), duration)
	if guard then
		apply(state, state.self, guard.kind, {
			duration = guard.duration,
			value = guard.value,
			skillId = guard.skillId,
			category = guard.category,
		})
		state.channel.guardKey = `{guard.kind}|{guard.skillId}|{guard.category}`
	end
end

-- mirrors SkillService.closeChannel cut short (Channel.stops): the channel ends and its guard comes off.
local function endChannel(state: any)
	local ch = state.channel
	state.channel = nil
	local e = ch and ch.guardKey and state.self.effects[ch.guardKey]
	if e and e.expiresAt > state.t then
		e.expiresAt = state.t
	end
end

H.beam = function(ctx)
	local state = ctx.state
	local tg = alive(state)[1]
	if not tg then
		return false
	end
	local drain = Skills.drain(ctx.def, ctx.rank, state.poolMax, ctx.costMods)
	if drain > 0 and not state.unlimited and state.pool + EPS < drain then
		return false
	end
	local dmg, growth = Skills.valueAt(ctx.def, "dmg", ctx.rank), Skills.valueAt(ctx.def, "growth", ctx.rank)
	local ticks = Skills.beamTicks(ctx.def)
	local interval = ctx.def.interval or 0.5
	local duration = ticks * interval
	state.channelToken += 1
	local token = state.channelToken
	state.channel = { kind = "beam", untilT = state.t + duration, def = ctx.def, token = token }
	channelGuardOn(state, "beam", duration)
	for n = 1, ticks do
		local due = math.ceil((n * interval - 1e-3) / CHANNEL_POLL - 1e-9) * CHANNEL_POLL
		schedule(state, state.t + due, function()
			local ch = state.channel
			if not ch or ch.token ~= token then
				return
			end
			if drain > 0 then
				if not state.unlimited and state.pool + EPS < drain then
					endChannel(state) -- Channel.stops("beam", "noMana")
					return
				end
				state.spent += drain
				if not state.unlimited then
					state.pool -= drain
				end
			end
			state.beamTicks += 1
			if tg.hp > 0 then
				damage(ctx, tg, Skills.beamTickPct(dmg, growth, n), { primary = true, consumeShot = n == 1 })
			end
			if n == ticks then
				state.channel = nil
			end
		end)
	end
	return true
end

-- Behaviour keys the model knows (C6): counted here or without effect on a dummy. Any other key goes to unmodelled.
SkillModel.BEHAVIOURS = {
	splash = true,
	pierce = true,
	lingering = true,
	echo = true,
	split = true,
	execute = true,
	bleedStacks = true,
	poisonStacks = true,
	lifesteal = true,
	secondTarget = true,
	overhealShield = true,
	selfHeal = true,
	healWounded = true,
	burst = true,
	stunSplash = true,
	cdrPerTarget = true,
	critCdr = true,
	firstWave = true,
	cleanse = true,
	-- S86
	shieldPerHit = true,
	allyHeal = true,
	allyShield = true,
	chainHeal = true,
	healZone = true,
	roll = true,
	rollDouble = true,
	grantCharges = true,
	empower = true,
	shieldBurst = true,
	stunLast = true,
	-- no effect on a dummy (movement, kills, a second member; docs/SESJE.md S86)
	behindEffect = true,
	pull = true,
	knockback = true,
	castMove = true,
	stunNear = true,
	trap = true,
	poisonSpread = true,
	markJump = true,
	extendOnKill = true,
	steadfast = true,
	channelMove = true,
	tauntNear = true,
} :: { [string]: boolean }

-- Rotation ----------------------------------------------------------------------------------------------------------

-- S85 (D2) / S86: conditions of a rotation entry on the dummies and the player. Returns true, false, or a string: the
-- reason of an entry the model has no state for.
local function condition(state: any, entry: { [string]: any }): boolean | string
	for key, value in entry do
		if key == "skill" then
			continue
		elseif key == "target" then
			if value == "tank" then
				if not state.heal then
					return false
				end
			elseif value == "mostWounded" then
				-- heal mode: the tank; solo: the caster when its HP track shows a wound (retaliate)
				if not state.heal and not (state.retaliate and state.hp < state.maxHp - EPS) then
					return false
				end
			elseif value == "meleeAllies" then
				-- S86 (B4): a melee ally stands where the zone goes (heal mode: the tank; solo: the caster, zoneInside,
				-- when its HP track shows a wound: nobody casts a heal zone at full HP)
				local inside = if state.heal
					then inZone(state, "tank")
					else A.zoneInside.solo and state.retaliate and state.hp < state.maxHp - EPS
				if not inside then
					return false
				end
			elseif value == "allyInZone" then
				return false -- S86: no ally in a red zone on dummies (the guard needs a red zone of the boss model)
			end
		elseif key == "minEnemies" then
			if #alive(state) < value then
				return false
			end
		elseif key == "minWounded" then
			-- heal mode: every member is wounded; solo: nobody
			if not state.heal or state.heal.team < value then
				return false
			end
		elseif key == "elite" then
			local focus = alive(state)[1]
			local variant = if focus then focus.m.variant else "normal"
			if value and not (variant == "elite" or variant == "elite2" or variant == "boss") then
				return false
			end
		elseif key == "debuff" then
			local who = if entry.target == "self" then state.self else alive(state)[1]
			if not who or #effectsOf(who, value) == 0 then
				return false
			end
		elseif key == "opener" then
			if value and state.casts[entry.skill] then
				return false
			end
		elseif key == "belowHp" then
			-- S86: the caster's HP track (retaliate); at full HP on a dummy and in heal mode never
			if not (state.retaliate and state.hp / math.max(1, state.maxHp) * 100 < value) then
				return false
			end
		elseif key == "minManaPct" or key == "maxManaPct" then
			local share = if state.poolMax > 0 then state.pool / state.poolMax * 100 else 0
			if key == "minManaPct" and share < value then
				return false
			elseif key == "maxManaPct" and share > value then
				return false
			end
		elseif key == "notInZone" then
			continue -- no red zones on a dummy
		elseif key == "beforeRedZone" then
			return false -- no boss schedule in the fight (Guardian Angel; DECYZJE S86)
		elseif key == "minFury" then
			if state.fury.stacks < value then
				return false
			end
		elseif key == "minCharges" then
			if chargesNow(state) < value then
				return false
			end
		else
			return `warunek {key}: nieznany`
		end
	end
	return true
end

-- The CostMods of a cast now (SkillService.cast): costReduce, the PassiveHook table, Arcane Charges.
local function costMods(state: any): Skills.CostMods
	return {
		costReduce = current(state).values.costReduce or 0,
		hooks = state.sp.pathHooks,
		charges = if chargesEnabled(state) then chargesNow(state) else 0,
	}
end

-- A prepared rotation entry: the effective skill, its rank, cost (Skills.cost) and cooldown (Skills.cooldown), or why
-- it is never cast.
local function prepare(state: any, entry: { [string]: any }): any
	local sp = state.sp
	local id = entry.skill
	local base = SkillData.get(id)
	local out: any = { entry = entry, id = id }
	if not base or base.class ~= sp.classId then
		out.never = "spoza klasy"
		return out
	end
	local rank = Paths.skillRank(sp.character, id)
	if rank <= 0 or base.type == "passive" then
		out.off = true -- no rank yet (not listed)
		return out
	end
	if not Paths.skillUsable(sp.character, id, sp.weapons) then
		out.off = true
		return out
	end
	local def, bp = Paths.effectiveFor(sp.character, id, sp.weapons, rank)
	local override = state.override and state.override[id]
	if override then
		def, bp = override.def, override.bp
	end
	if not Skills.elementAllowed(def, sp.element) then
		out.off = true
		return out
	end
	out.rank, out.def, out.bp = rank, def, bp
	local p = state.p
	out.cooldown = Skills.cooldown(def, rank, Skills.cooldownReduction(p.hooks.cooldownReduction or 0), bp)
	if def.type == "resurrect" then
		out.never = "bez martwego sojusznika"
	elseif def.type ~= "channel" and not SkillModel.HANDLERS[def.type] then
		-- a channel has no handler: SkillService.cast runs it (cast below)
		out.never = `typ {def.type}: nieznany`
	end
	for key in bp do
		if not SkillModel.BEHAVIOURS[key] then
			mark(state, `zachowanie {key}`)
		end
	end
	return out
end

-- Cost of a prepared entry now (mirrors SkillService.cast: Skills.cost with the CostMods of the moment, S86 B12).
local function costNow(state: any, item: any): number
	return (Skills.cost(item.def, item.rank, state.sp.level, state.sp.classId, costMods(state)))
end

-- S86 (B12 test): the cost the model charges for `def` at `rank` with `charges` Arcane Charges (the CostMods of
-- SkillService.cast: costReduce, the PassiveHook table, charges).
function SkillModel.costWith(sp: any, def: any, rank: number, charges: number): number
	return (
		Skills.cost(def, rank, sp.level, sp.classId, {
			costReduce = sp.p.values.costReduce or 0,
			hooks = sp.pathHooks,
			charges = charges,
		})
	)
end

local function skip(state: any, item: any, reason: string)
	if state.t + EPS < (item.virtualReady or 0) then
		return
	end
	item.virtualReady = state.t + (item.cooldown or 1)
	local s = state.skipped[item.id]
	if not s then
		s = { reason = reason, count = 0 }
		state.skipped[item.id] = s
	end
	s.count += 1
end

-- mirrors SkillService.finished: selfEffects (not after a guard's self variant), selfHeal, Mantle of Elements
-- (Skills.castGuard), Arcane Charges (Discharge spends them with chargeReclaim, other damaging spells add one when
-- charges work), the empowered use, Full Draw primed by an offensive skill or a trap, zealCdr (Ardor).
local function finished(ctx: Ctx)
	local state = ctx.state
	if not ctx.skipSelfEffects then
		for _, effect in ctx.def.selfEffects or {} do
			applyEffect(ctx, state.self, effect)
		end
	end
	if ctx.bp.selfHeal then
		heal(ctx, "self", current(state).values.maxHp * ctx.bp.selfHeal / 100)
	end
	local mantle = Skills.castGuard(ctx.def, pathHook(state, "vortexGuard"))
	if mantle then
		apply(state, state.self, mantle.kind, {
			duration = mantle.duration,
			value = mantle.value,
			skillId = mantle.skillId,
			category = mantle.category,
		})
	end
	if ctx.consumes then
		local spent = ctx.chargesSpent or 0
		state.charges = { stacks = 0, expiresAt = 0 }
		local reclaim = pathHook(state, "chargeReclaim")
		if reclaim > 0 and spent > 0 and state.resource == "mana" then
			state.gainReturn(state.poolMax * reclaim / 100 * spent)
		end
	elseif ctx.spell and chargesEnabled(state) then
		giveCharges(state, nil)
	end
	if ctx.empowerReserved then
		state.empowered.stacks = math.max(0, state.empowered.stacks - 1) -- StatusEffectService.UseStack
	end
	local offensive = Skills.offensive(ctx.def)
	if (offensive or ctx.def.type == "trap") and not state.control then
		local draw = hook(state, "traitFullDraw")
		if draw > 0 then
			apply(state, state.self, "nextBasic", { duration = traitParam("fullDraw", "window"), value = draw })
		end
	end
	local zeal = if offensive then pathHook(state, "zealCdr") else 0
	if zeal > 0 then
		for _, id in ZEAL_SKILLS do
			local ready = state.cd[id]
			if ready and ready > state.t then
				state.cd[id] = math.max(state.t, ready - zeal)
			end
		end
	end
end

-- mirrors SkillService completeChannel (S70, S80): mana back, Prayer 5B's dice (fortuneDice as the player would cast
-- it, one face for half its duration), Evocation 10B's charges (Skills.chargesAfterGain) and Empowering Invocation
local function completeChannel(ctx: Ctx)
	local state = ctx.state
	state.gain(current(state).values.maxMana * Skills.valueAt(ctx.def, "mana", ctx.rank) / 100)
	if ctx.bp.roll then
		local dice = SkillData.get("fortuneDice")
		if dice then
			local sp = state.sp
			local rank = math.max(1, Skills.rankAt(dice, sp.level))
			local def, bp = Paths.effectiveFor(sp.character, dice.id, sp.weapons, rank)
			local diceCtx = table.clone(ctx)
			diceCtx.id, diceCtx.def, diceCtx.bp, diceCtx.rank = dice.id, def, bp, rank
			rollDice(diceCtx, true)
		end
	end
	local grant = ctx.bp.grantCharges
	if grant and grant > 0 and chargesEnabled(state) then
		giveCharges(state, Skills.chargesAfterGain(chargesNow(state), grant))
	end
	local empower = ctx.bp.empower
	if empower and empower.uses > 0 then
		state.empowered = {
			stacks = empower.uses,
			expiresAt = state.t + SkillData.EMPOWERED.duration,
			value = Skills.resolve(ctx.def, empower.pct, ctx.rank),
		}
	end
end

-- mirrors SkillService.cast (S85 C1, D1, E1; S86): the cost (Skills.cost with Arcane Charges) and the mana share
-- before it (resonance) at the cast, GCD and cooldown at the cast, the castMul snapshot (Skills.dischargeFactor /
-- chargeDamageFactor, empowered), then: a channel stands its duration (the model casts nothing meanwhile; basic
-- attacks go on) and completes; an aimed skill (castTime, B10) waits its castTime without basic attacks and shoots
-- without the motion's hit delay; other types land after SkillMotions.hitDelay (none for INSTANT types).
local function cast(state: any, item: any): boolean
	local def = item.def
	local mods = costMods(state)
	local charges = mods.charges or 0
	local cost = (Skills.cost(def, item.rank, state.sp.level, state.sp.classId, mods))
	local manaFraction = if state.resource == "mana" then state.pool / math.max(1, state.poolMax) else 0
	local spell = Skills.isSpell(def)
	local consumes = Skills.consumesCharges(def)
	local castMul = 1
	local ctx: Ctx = {
		state = state,
		entry = item.entry,
		id = item.id,
		def = def,
		bp = item.bp,
		rank = item.rank,
		magic = def.damageKind == "magic",
		element = if def.adaptive then state.sp.element else def.element,
		cooldown = item.cooldown,
		struck = {},
		struckCount = 0,
		critCdrUsed = false,
		tag = Skills.tag(def),
		manaFraction = manaFraction,
		costMods = mods,
		spell = spell,
		consumes = consumes,
		furyUsed = 0,
	}
	if consumes then
		castMul *= Skills.dischargeFactor(Skills.valueAt(def, "perCharge", item.rank), charges)
		ctx.chargesSpent = charges
	elseif spell and charges > 0 then
		castMul *= Skills.chargeDamageFactor(charges, pathHook(state, "chargeDamage"))
	end
	if spell then
		local e = state.empowered
		if e.stacks > 0 and e.expiresAt > state.t + EPS then
			castMul *= 1 + e.value / 100
			ctx.empowerReserved = true
		end
	end
	ctx.castMul = castMul
	state.spent += cost
	if not state.unlimited then
		state.pool -= cost
	end
	state.gcd = state.t + SkillData.GCD
	state.cd[item.id] = state.t + item.cooldown
	state.casts[item.id] = (state.casts[item.id] or 0) + 1
	if Skills.offensive(def) or def.type == "trap" then
		state.offensiveCasts += 1
	end
	if #state.firstCasts < 12 then
		table.insert(state.firstCasts, item.id)
	end
	if def.type == "channel" then
		local duration = Skills.scaled(def, def.duration, item.rank)
		state.channelToken += 1
		local token = state.channelToken
		state.channel = { kind = "channel", untilT = state.t + duration, def = def, token = token }
		channelGuardOn(state, "channel", duration)
		finished(ctx)
		schedule(state, state.t + duration, function()
			local ch = state.channel
			if ch and ch.token == token then
				state.channel = nil
				completeChannel(ctx)
			end
		end)
		return true
	end
	local handler = SkillModel.HANDLERS[def.type]
	local function run()
		if handler(ctx) then
			finished(ctx)
		elseif not state.unlimited then
			-- the handler refused (SkillService refund): cost back, cooldown and GCD off
			state.pool = math.min(state.poolMax, state.pool + cost)
			state.spent -= cost
			state.cd[item.id] = nil
			state.gcd = 0
		end
	end
	local castTime = def.castTime or 0
	if castTime > 0 then
		-- B10 mirrors SkillService startChannel(ctx, onDone, onRefund) kind "castTime": no basic attacks, another
		-- skill refused; the shot at the end without the hit delay (Logic/Channel: damage never ends the aim)
		state.channelToken += 1
		local token = state.channelToken
		state.channel = { kind = "castTime", untilT = state.t + castTime, def = def, token = token }
		state.aims += 1
		schedule(state, state.t + castTime, function()
			local ch = state.channel
			if ch and ch.token == token then
				state.channel = nil
				run()
			end
		end)
		return true
	end
	local delay = if INSTANT[def.type] then 0 else SkillMotions.hitDelay(item.id)
	if delay <= EPS then
		run()
	else
		schedule(state, state.t + delay, run)
	end
	return true
end

-- mirrors PotionService: the biggest allowed quality (Balance.potionHps rule) every Potions.interval(L), drunk when
-- the pool has room for it or a ready cast lacks the resource (DECYZJE).
local function potionAmount(resource: string, level: number): number
	local best = 0
	for q = 1, 5 do
		local def: any = Items.get(`potion_{resource}_{q}`)
		if def and (def.level or 1) <= level then
			best = math.max(best, def.use.amount)
		end
	end
	return best
end

-- S86 (D3) mirrors CombatService.monsterHitsPlayer + StatusEffectService damageFilter: one expected blow of `tg` on the
-- player: FightSim.hit (armour, dodge and block on regular blows, melee / ranged protection, res_<family>) with the
-- monster's misfortune in Damage.avoidance (regular blows), Bonebreaker's weaken (enemyDamageDown), the own reductions
-- (damageReduction effects, lastStand below Combat.lowHpFraction, guardPerEnemy per living monster up to
-- HOOK_RULES.perEnemy.max, poisonedGuard, furyGuard at full Fury) through EffectStack.reduction, then absorb shields;
-- a block's energy (HOOK_RULES.blockEnergy with block from nodes, CombatService.NodeHook) and blockHeal, the counter
-- (Traits.counterChance) and thorns. A channel ends on damage unless Logic/Channel says otherwise.
local function monsterHit(state: any, tg: any, mul: number?, kind: string?, canDodge: boolean?)
	local p = current(state)
	local v = p.values
	local m = tg.m
	local amount = FightSim.hit(m, p, mul, kind, canDodge)
	local regular = canDodge ~= false
	if regular then
		local blockChance = Traits.blockChance(p.hooks.block or 0, false)
		local miss = math.min(maxOf(state, tg, "misfortune"), BuffCategories.caps.enemyMiss)
		local d0, _, b0 = Damage.avoidance(v.dodge or 0, 0, 0, blockChance)
		local d1, m1, b1 = Damage.avoidance(v.dodge or 0, 0, miss, blockChance)
		if miss > 0 then
			amount *= (1 - d1 - m1 - b1) / math.max(1e-9, 1 - d0 - b0)
		end
		if b1 > 0 then
			if pathHook(state, "block") > 0 and state.resource == "energy" then
				local energy = b1 * PathData.HOOK_RULES.blockEnergy
				state.gainReturn(energy)
				state.blockEnergy += energy
			end
			local blockHeal = hook(state, "blockHeal")
			if blockHeal > 0 then
				giveHeal(state, "self", b1 * v.maxHp * blockHeal / 100)
			end
		end
		local counter = Traits.counterChance(hook(state, "riposte"), false) / 100
		if counter > 0 and tg.hp > 0 then
			dealDamage(state, tg, {
				magic = p.magic,
				percent = 100,
				basic = true,
				noProc = true,
				consumeShot = false,
				extra = 1 + hook(state, "counterDamage") / 100,
				scale = counter,
			})
		end
	end
	local weaken = categoryValue(state, tg, "enemyDamageDown")
	if weaken > 0 then
		amount *= 1 - weaken / 100
	end
	local entries = {}
	for _, e in state.self.effects do
		if e.kind == "damageReduction" and e.expiresAt > state.t + EPS then
			table.insert(entries, { category = e.category, value = e.value, at = e.appliedAt })
		end
	end
	local own = {}
	local lastStand = hook(state, "lastStand")
	if lastStand > 0 and state.hp / state.maxHp < Combat.lowHpFraction then
		table.insert(own, lastStand)
	end
	local perEnemy = hook(state, "guardPerEnemy")
	if perEnemy > 0 then
		table.insert(own, perEnemy * math.min(#alive(state), PathData.HOOK_RULES.perEnemy.max))
	end
	local poisoned = hook(state, "poisonedGuard")
	if poisoned > 0 and has(state, tg, "poison") then
		table.insert(own, poisoned)
	end
	local furyGuard = hook(state, "furyGuard")
	local max = furyMax(state)
	if furyGuard > 0 and max > 0 and state.fury.stacks >= max then
		table.insert(own, furyGuard)
	end
	for _, r in own do
		table.insert(entries, { category = "own", value = r, at = 0 })
	end
	local reduction = EffectStack.reduction(entries)
	amount *= 1 - reduction / 100
	for _, e in state.self.effects do
		if amount <= 0 then
			break
		end
		if e.kind == "shield" and e.expiresAt > state.t + EPS and (e.value or 0) > 0 then
			local absorbed = math.min(e.value, amount)
			e.value -= absorbed
			amount -= absorbed
			if e.value <= 0 then
				e.expiresAt = 0
			end
		end
	end
	if amount > 0 then
		state.hp -= amount
		state.taken += amount
		local ch = state.channel
		if ch and (Channel.stops(ch.kind, "damage", ch.def)) then
			endChannel(state)
		end
		local thorns = hook(state, "thorns")
		if thorns > 0 and tg.hp > 0 then
			local reflected = math.max(1, math.floor(amount * thorns / 100))
			tg.hp -= reflected
			state.dealt += reflected
		end
	end
end

-- S85 (C1): the fight. Steps of ASSUMPTIONS.dt over [0, seconds): events due, effect ticks, the basic swing, potions,
-- the rotation, regeneration. Without real HP the window ends at `seconds` and the last swing counts only its part
-- inside the window (C2: 60 s at speed 1.2 = 72 swings). S86: Fury every step (B5), the control axis and the Runic
-- Seal, channels (castTime, beam), Arcane Charges, and with `retaliate` the monsters' blows on the player (D3).
function SkillModel.fight(sp: any, opts: FightOpts?): FightResult
	local o: FightOpts = opts or {}
	local T = o.seconds or A.sustainedSeconds
	local dummy = o.dummy ~= false
	local monsters = o.targets or { B.monster(B.GENERIC, sp.level) }
	local state: any = {
		sp = sp,
		p = sp.p,
		selfDirty = true,
		t = 0,
		seq = 0,
		events = {},
		targets = {},
		self = { effects = {}, who = "self" },
		tank = { effects = {}, who = "tank" },
		dealt = 0,
		by = {},
		casts = {},
		firstCasts = {},
		cd = {},
		gcd = 0,
		spent = 0,
		healTo = {},
		skipped = {},
		unmodelled = {},
		weakStacks = 0,
		nextBasic = 0,
		dummy = dummy,
		control = o.control == true,
		unlimited = o.unlimited == true,
		heal = o.heal,
		resource = sp.resource,
		potions = 0,
		-- S86
		fury = Fury.new(),
		furyStat = 0,
		furyStatAt = -math.huge,
		furyConsumed = 0,
		charges = { stacks = 0, expiresAt = 0 },
		empowered = { stacks = 0, expiresAt = 0, value = 0 },
		channel = nil,
		channelToken = 0,
		procs = {},
		twinCount = 0,
		twinAt = nil,
		sealSince = 0,
		sealLit = false,
		basicDealt = 0,
		elementDealt = 0,
		areaDealt = 0,
		offensiveCasts = 0,
		aims = 0,
		retaliate = o.retaliate == true,
		hp = 0,
		maxHp = 0,
		taken = 0,
		healEff = 0,
		kills = 0,
		potionsHp = 0,
		blockEnergy = 0,
		falcon = nil,
		falconToken = 0,
		falconStrikes = 0,
		trapsFired = 0,
		beamTicks = 0,
		resourceAt = nil,
		lifestealHeal = 0,
		instantTraps = o.instantTraps == true,
		override = o.override,
	}
	for i, m in monsters do
		table.insert(state.targets, {
			id = `t{i}`,
			m = m,
			hp = if dummy then A.dummyHp else m.maxHp,
			maxHp = if dummy then A.dummyHp else m.maxHp,
			dummy = dummy,
			effects = {},
			nextAttack = 0,
			nextAbility = if m.ability then m.ability.cooldown else nil,
		})
	end
	local p0 = current(state)
	state.poolMax = if sp.resource == "mana" then p0.values.maxMana else p0.values.maxEnergy
	state.pool = state.poolMax * (o.startPool or 1)
	state.gain = function(amount: number)
		state.pool = math.min(state.poolMax, state.pool + amount)
	end
	-- S86 (T-SK4): passive returns (Reclaim, Cascade, manaOnHit, resourceOnHit, trap and block energy) count as income
	state.returns = 0
	state.cascade = 0 -- the Cascade part of returns (T-SK4: measured in a clear fight, rawMetrics)
	state.gainReturn = function(amount: number)
		state.gain(amount)
		state.returns += amount
	end
	state.maxHp = p0.values.maxHp
	state.hp = state.maxHp * (o.startHp or 1)
	if o.startFury and furyMax(state) > 0 then
		state.fury = Fury.set(state.fury, 0, o.startFury, furyMax(state))
	end
	if o.startCharges and o.startCharges > 0 then
		giveCharges(state, o.startCharges)
	end
	local regen = if sp.resource == "mana" then p0.values.manaRegen or 0 else p0.values.energyRegen or 0
	state.regen = regen
	local items: { any } = {}
	if o.skills ~= false then
		for _, entry in o.rotation or sp.build.rotation do
			local item = prepare(state, entry)
			if not item.off then
				table.insert(items, item)
			end
		end
	end
	local potionAmountNow = if o.potions then potionAmount(sp.resource, sp.level) else 0
	local potionEvery = Potions.interval(sp.level)
	local nextPotion = 0
	local hpPotion = if o.hpPotions then potionAmount("hp", sp.level) else 0
	local nextHpPotion = 0
	local sealStill = traitParam("runicSeal", "still")
	local steps = math.floor(T / A.dt + 0.5)
	local ended = T
	local furySum, furyFullTime, controlTime, sealTime, chargeSum = 0, 0, 0, 0, 0
	local died = false
	for step = 0, steps - 1 do
		local t = step * A.dt
		state.t = t
		local events = state.events
		while #events > 0 and events[1].t <= t + EPS do
			local ev = table.remove(events, 1)
			ev.fn()
		end
		for _, tg in state.targets do
			tickEntity(state, tg)
		end
		tickEntity(state, state.self)
		tickEntity(state, state.tank)
		if not dummy and #alive(state) == 0 then
			ended = t
			break
		end
		if state.retaliate and state.hp <= 0 then
			ended = t
			died = true
			break
		end
		if not state.control then
			stepFury(state)
			local lit = t - state.sealSince + EPS >= sealStill
			if lit ~= state.sealLit then
				state.sealLit = lit
			end
		end
		local channel = state.channel
		if channel and t + EPS >= channel.untilT then
			channel = nil
		end
		local blocksBasic = channel ~= nil and (channel.kind == "castTime" or channel.kind == "beam")
		if blocksBasic then
			-- mirrors CombatService.tryBasicAttack: a swing missed while aiming or beaming is lost (no catch-up);
			-- the first swing after the channel starts a new cadence (nextAttack = now + 1 / speed)
			state.nextBasic = math.max(state.nextBasic, t + A.dt)
		elseif t + EPS >= state.nextBasic then
			basicSwing(state)
		end
		local blocked = false
		if #items > 0 and channel == nil and t + EPS >= state.gcd then
			for _, item in items do
				if t + EPS < (state.cd[item.id] or 0) then
					continue
				end
				if item.never then
					skip(state, item, item.never)
					continue
				end
				local ok = condition(state, item.entry)
				if type(ok) == "string" then
					skip(state, item, ok)
					continue
				elseif not ok then
					continue
				end
				if not state.unlimited and state.pool + EPS < costNow(state, item) then
					blocked = true -- a ready cast lacks the resource (the potion rule)
					continue
				end
				cast(state, item)
				break
			end
		end
		if o.potions and t + EPS >= nextPotion and potionAmountNow > 0 then
			if state.pool <= state.poolMax - potionAmountNow or blocked then
				state.gain(potionAmountNow)
				state.potions += 1
				nextPotion = t + potionEvery
			end
		end
		if state.retaliate then
			-- the monsters' blows (FightSim: one swing at once, then every attackInterval, slowed by enemyAttackSlow;
			-- stunned or frozen monsters wait), Elite II's ability every cooldown x SPECIAL_HIT
			for _, tg in alive(state) do
				local disabled = has(state, tg, "stun") or has(state, tg, "freeze")
				if t + EPS >= tg.nextAttack then
					if disabled then
						tg.nextAttack = t + A.dt
					else
						monsterHit(state, tg)
						local slow = categoryValue(state, tg, "enemyAttackSlow")
						tg.nextAttack += Traits.slowedInterval(tg.m.attackInterval, slow)
					end
				end
				local ability = tg.m.ability
				if ability and tg.nextAbility and t + EPS >= tg.nextAbility then
					monsterHit(state, tg, (ability.damage or 1) * B.SPECIAL_HIT, ability.damageKind, false)
					tg.nextAbility += ability.cooldown
				end
			end
			if o.hpPotions and hpPotion > 0 and t + EPS >= nextHpPotion and state.hp <= state.maxHp - hpPotion then
				giveHeal(state, "potion", hpPotion)
				local effective = math.min(hpPotion, state.maxHp - state.hp)
				state.hp += effective
				state.potionsHp += 1
				nextHpPotion = t + potionEvery
			end
			local regenHp = (current(state).values.hpRegenCombat or 0) * A.dt
			state.hp = math.min(state.maxHp, state.hp + regenHp)
		end
		local p = current(state)
		local r = if sp.resource == "mana" then p.values.manaRegen or 0 else p.values.energyRegen or 0
		state.gain(r * A.dt)
		if o.sample then
			o.sample(state)
		end
		-- the means of the step (B5, B8, B12, C3)
		furySum += state.fury.stacks * A.dt
		local max = furyMax(state)
		if max > 0 and state.fury.stacks >= max then
			furyFullTime += A.dt
		end
		local focus = alive(state)[1]
		if focus and controlled(state, focus) then
			controlTime += A.dt
		end
		if state.sealLit then
			sealTime += A.dt
		end
		chargeSum += chargesNow(state) * A.dt
	end
	-- C2: only the part of the swings inside the window counts: the last swing loses the part past T, a swing due
	-- before T that the last step did not reach counts its part inside (as the last swing's amount)
	local last = state.lastSwing
	if dummy and last then
		local inside = math.min(1, (T - last.at) / last.interval)
		local fix = (inside - 1) * last.amount
		local ch = state.channel
		local blockedEnd = ch ~= nil and ch.kind ~= "channel" and ch.untilT > T - EPS
		if state.nextBasic < T - EPS and not blockedEnd then
			fix += (T - state.nextBasic) / last.interval * last.amount
		end
		state.dealt += fix
		state.basicDealt += fix
		state.by.basic = (state.by.basic or 0) + fix
	end
	local unmodelled: { string } = {}
	for text in state.unmodelled do
		table.insert(unmodelled, text)
	end
	for _, text in staticUnmodelled(sp) do
		if not state.unmodelled[text] then
			table.insert(unmodelled, text)
		end
	end
	table.sort(unmodelled)
	local seconds = math.max(A.dt, ended)
	return {
		seconds = ended,
		dealt = state.dealt,
		dps = state.dealt / seconds,
		by = state.by,
		casts = state.casts,
		spent = state.spent,
		poolMax = state.poolMax,
		poolEnd = state.pool,
		regen = regen,
		potions = state.potions,
		healTo = state.healTo,
		skipped = state.skipped,
		unmodelled = unmodelled,
		firstCasts = state.firstCasts,
		furyMean = furySum / seconds,
		furyFull = furyFullTime / seconds,
		furyMax = furyMax(state),
		controlled = controlTime / seconds,
		sealLit = sealTime / seconds,
		basicDealt = state.basicDealt,
		elementDealt = state.elementDealt,
		areaDealt = state.areaDealt,
		offensiveCasts = state.offensiveCasts,
		died = died,
		hpEnd = if state.retaliate then math.max(0, state.hp) / state.maxHp else 1,
		hpLost = if state.retaliate then (state.taken - state.healEff) / state.maxHp else 0,
		taken = state.taken,
		healEff = state.healEff,
		kills = state.kills,
		potionsHp = state.potionsHp,
		blockEnergy = state.blockEnergy,
		falconStrikes = state.falconStrikes,
		trapsFired = state.trapsFired,
		beamTicks = state.beamTicks,
		chargesMean = chargeSum / seconds,
		returns = state.returns,
		cascade = state.cascade,
		lifestealHeal = state.lifestealHeal,
		chargesEnd = chargesNow(state),
		furyEnd = state.fury.stacks,
	}
end

-- Metrics -----------------------------------------------------------------------------------------------------------

-- S85 fields keep their names and definitions; S86 (D) adds the PathMetrics fields of "Definicje metryk"
-- (docs/sessions/S86.md, DECYZJE S86): single60 (= sustained60), r1 (= tsk1), boss180, maxHp, ehp, ehpRed, the Fury
-- means, the measured situations (C3) and the counters of the S86 mechanics.
export type Metrics = {
	basic: number,
	onCooldown: number,
	demand: number, -- resource per second on cooldown
	burst8: number,
	sustained60: number,
	sustained60p: number,
	potionsPerMinute: number,
	aoe3burst: number,
	aoe3sus: number,
	tsk1: number,
	tsk2: number,
	tsk3: number,
	tsk1rel: number,
	tsk2rel: number,
	tsk4: number, -- demand on cooldown / (regeneration + passive returns) (Mage T-SK4, Cleric report)
	pool: number,
	regen: number,
	spent: number,
	free: number,
	unmodelled: { string },
	skipped: { [string]: { reason: string, count: number } },
	offRotation: { string },
	shares: { [string]: number }, -- damage share of sustained60
	byElement: { [string]: Metrics }?,
	-- S86 PathMetrics
	single60: number, -- 1 target 60 s (= sustained60)
	r1: number, -- R1 = T-SK1
	boss180: number, -- 1 target 180 s from a full pool, the pool as the limit (Mage 12.7)
	boss180u: number, -- the same without the limit (situation `mana`)
	returns: number, -- passive returns per second on cooldown (T-SK4 income)
	maxHp: number,
	ehp: number, -- max HP / expected regular blow after armour, dodge, block and own reductions (3 enemies near)
	ehpRed: number, -- the same for a red zone blow (canDodge = false)
	furyMean: number, -- mean Fury stacks, 1 target 60 s (B5)
	furyMeanGroup: number, -- mean Fury stacks, 3 targets 60 s
	furyFullGroup: number, -- share of the group fight at full Fury (furyGuard in EHP)
	basicShare: number, -- C3: basic attack damage / all damage, 1 target 60 s
	basicShareGroup: number, -- the same on 3 targets
	skillInterval: number, -- C3: s between offensive casts (traps too), 1 target 60 s
	elementShare: number, -- C3: weapon-element damage share (burns, arcs, zones)
	areaShare: number, -- C3: area skill hits / all damage on 3 targets
	controlled: number, -- C3: share of the time the target is controlled (B8), 1 target
	controlledBoss: number, -- the same on a boss (notBoss effects do not land)
	still: number, -- C3: share of the time the Runic Seal glows, 1 target
	stillBoss: number, -- the same with ASSUMPTIONS.redZoneMove s of moving at each red zone of the boss model
	mana: number, -- C3 (Mage): boss180 / boss180u
	trapsPerMinute: number,
	falconPerMinute: number,
	chargesMean: number,
}

local metricsCache: { [string]: Metrics } = {}

-- S86 (C3 still on a boss): red zones per second of the S83 boss model of the level's region (Balance.bossFightAt:
-- special attacks cast over the fight).
local function redZoneRate(classId: string, L: number): number
	local _, f = B.bossFightAt(classId, L)
	local casts = 0
	for _, ph in f.phases do
		casts += ph.casts
	end
	return casts / math.max(1e-9, f.seconds)
end
SkillModel.redZoneRate = redZoneRate

-- S86 (D, B6): effective HP of a player: max HP / the expected blow of a monster of level L (FightSim.hit: armour,
-- dodge and block on regular blows, protection) x (1 - own reductions through EffectStack.reduction): Front Line
-- (guardPerEnemy x ASSUMPTIONS.enemiesNear), Relentless (furyGuard) for the share of time at full Fury, Clenched Teeth
-- (lastStand) on the last Combat.lowHpFraction of HP. `red` = a red zone blow (canDodge = false).
function SkillModel.ehpOf(p: any, L: number, red: boolean, furyFull: number?, kind: any?): number
	local m = B.monster(kind or B.GENERIC, L)
	local hit = FightSim.hit(m, p, nil, nil, if red then false else nil)
	local hooks = p.hooks
	local base: { number } = {}
	local perEnemy = hooks.guardPerEnemy or 0
	if perEnemy > 0 then
		table.insert(base, perEnemy * math.min(A.enemiesNear, PathData.HOOK_RULES.perEnemy.max))
	end
	local function taken(extra: { number }): number
		local entries = {}
		for _, r in base do
			table.insert(entries, { category = "own", value = r, at = 0 })
		end
		for _, r in extra do
			table.insert(entries, { category = "own", value = r, at = 0 })
		end
		return hit * (1 - EffectStack.reduction(entries) / 100)
	end
	local full = math.clamp(furyFull or 0, 0, 1)
	local guard = hooks.furyGuard or 0
	local function blended(extra: { number }): number
		if guard > 0 and full > 0 then
			local withGuard = table.clone(extra)
			table.insert(withGuard, guard)
			return full * taken(withGuard) + (1 - full) * taken(extra)
		end
		return taken(extra)
	end
	local hp = p.values.maxHp
	local low = Combat.lowHpFraction
	local lastStand = hooks.lastStand or 0
	local above = blended({})
	local below = if lastStand > 0 then blended({ lastStand }) else above
	return (1 - low) * hp / math.max(1e-9, above) + low * hp / math.max(1e-9, below)
end

local function rawMetrics(build: Build, L: number, element: string?): Metrics
	local sp = SkillModel.player(build, L, { element = element })
	local one = { B.monster(B.GENERIC, L) }
	local three = {}
	for _ = 1, A.areaTargets do
		table.insert(three, B.monster(B.GENERIC, L))
	end
	local basic = SkillModel.fight(sp, { skills = false, targets = one })
	local cooldown = SkillModel.fight(sp, { unlimited = true, targets = one })
	local burst = SkillModel.fight(sp, { seconds = A.burstSeconds, targets = one })
	local sustained = SkillModel.fight(sp, { targets = one })
	local withPotions = SkillModel.fight(sp, { targets = one, potions = true })
	local aoeBurst = SkillModel.fight(sp, { seconds = A.burstSeconds, targets = three })
	local aoeSus = SkillModel.fight(sp, { targets = three })
	-- S86
	local boss = SkillModel.fight(sp, { seconds = A.bossSeconds, targets = one })
	local bossU = if sp.resource == "mana"
		then SkillModel.fight(sp, { seconds = A.bossSeconds, targets = one, unlimited = true })
		else boss
	local onBoss = SkillModel.fight(sp, { targets = { B.monster(B.GENERIC, L, "boss") } })
	local unmodelled: { [string]: boolean } = {}
	for _, r in { cooldown, burst, sustained, aoeBurst, aoeSus } do
		for _, text in r.unmodelled do
			unmodelled[text] = true
		end
	end
	local skipped: { [string]: { reason: string, count: number } } = table.clone(sustained.skipped)
	for id, s in aoeSus.skipped do
		if not skipped[id] then
			skipped[id] = s
		end
	end
	local list: { string } = {}
	for text in unmodelled do
		table.insert(list, text)
	end
	table.sort(list)
	local inRotation: { [string]: boolean } = {}
	for _, entry in build.rotation do
		inRotation[entry.skill] = true
	end
	local off: { string } = {}
	for _, id in Paths.availableSkills(sp.character) do
		local def = SkillData.get(id)
		if def and def.type ~= "passive" and not inRotation[id] and Paths.skillUsable(sp.character, id, sp.weapons) then
			if Skills.elementAllowed(def, sp.element) then
				table.insert(off, id)
			end
		end
	end
	local shares: { [string]: number } = {}
	for id, v in sustained.by do
		shares[id] = v / math.max(1e-9, sustained.dealt)
	end
	local ch = SkillModel.character(build, L)
	local returns = cooldown.returns / A.sustainedSeconds
	if (sp.pathHooks.areaKillMana or 0) > 0 and sp.resource == "mana" then
		-- S86 (T-SK4, ROZWOJ 12.7 "Kaskada"): the dummy never dies, so Cascade is the mana of a clear fight on
		-- cooldown (A.areaTargets GENERIC monsters that die) per second of that fight plus A.walk to the next group
		-- (the grind pace of ROZWOJ 10.6; DECYZJE S86)
		local group = {}
		for _ = 1, A.areaTargets do
			table.insert(group, B.monster(B.GENERIC, L))
		end
		local clear =
			SkillModel.fight(sp, { targets = group, dummy = false, unlimited = true, seconds = A.retaliateSeconds })
		returns += clear.cascade / (clear.seconds + A.walk)
	end
	local still = sustained.sealLit
	local sealStill = (ItemTraits.get("runicSeal") :: any).params.still
	return {
		basic = basic.dps,
		onCooldown = cooldown.dps,
		demand = cooldown.spent / A.sustainedSeconds,
		burst8 = burst.dps,
		sustained60 = sustained.dps,
		sustained60p = withPotions.dps,
		potionsPerMinute = withPotions.potions * 60 / A.sustainedSeconds,
		aoe3burst = aoeBurst.dps,
		aoe3sus = aoeSus.dps,
		tsk1 = sustained.dps / basic.dps,
		tsk2 = burst.dps / basic.dps,
		tsk3 = aoeBurst.dps / burst.dps,
		tsk1rel = 0,
		tsk2rel = 0,
		tsk4 = (cooldown.spent / A.sustainedSeconds) / math.max(1e-9, cooldown.regen + returns),
		pool = cooldown.poolMax,
		regen = cooldown.regen,
		spent = ch.spent,
		free = ch.free,
		unmodelled = list,
		skipped = skipped,
		offRotation = off,
		shares = shares,
		single60 = sustained.dps,
		r1 = sustained.dps / basic.dps,
		boss180 = boss.dps,
		boss180u = bossU.dps,
		returns = returns,
		maxHp = sp.p.values.maxHp,
		ehp = SkillModel.ehpOf(sp.p, L, false, aoeSus.furyFull),
		ehpRed = SkillModel.ehpOf(sp.p, L, true, aoeSus.furyFull),
		furyMean = sustained.furyMean,
		furyMeanGroup = aoeSus.furyMean,
		furyFullGroup = aoeSus.furyFull,
		basicShare = sustained.basicDealt / math.max(1e-9, sustained.dealt),
		basicShareGroup = aoeSus.basicDealt / math.max(1e-9, aoeSus.dealt),
		skillInterval = A.sustainedSeconds / math.max(1, sustained.offensiveCasts),
		elementShare = sustained.elementDealt / math.max(1e-9, sustained.dealt),
		areaShare = aoeSus.areaDealt / math.max(1e-9, aoeSus.dealt),
		controlled = sustained.controlled,
		controlledBoss = onBoss.controlled,
		still = still,
		stillBoss = still * math.max(0, 1 - redZoneRate(build.classId, L) * (A.redZoneMove + sealStill)),
		mana = boss.dps / math.max(1e-9, bossU.dps),
		trapsPerMinute = sustained.trapsFired * 60 / A.sustainedSeconds,
		falconPerMinute = sustained.falconStrikes * 60 / A.sustainedSeconds,
		chargesMean = sustained.chargesMean,
	}
end

local NUMERIC = {
	"basic",
	"onCooldown",
	"demand",
	"burst8",
	"sustained60",
	"sustained60p",
	"potionsPerMinute",
	"aoe3burst",
	"aoe3sus",
	"pool",
	"regen",
	"single60",
	"boss180",
	"boss180u",
	"returns",
	"maxHp",
	"ehp",
	"ehpRed",
	"furyMean",
	"furyMeanGroup",
	"furyFullGroup",
	"basicShare",
	"basicShareGroup",
	"skillInterval",
	"elementShare",
	"areaShare",
	"controlled",
	"controlledBoss",
	"still",
	"stillBoss",
	"trapsPerMinute",
	"falconPerMinute",
	"chargesMean",
}

-- S85 (G1): the numbers of one row. Mage: the mean of the three weapon elements (E5), ratios from the means, the
-- per-element numbers in byElement. tsk1rel / tsk2rel against the same build at L20. S86: cached per run (key: class,
-- build key, which names the weapon of a variant, and level).
function SkillModel.metrics(build: Build, L: number): Metrics
	local key = `{build.classId}|{build.key}|{L}`
	local cached = metricsCache[key]
	if cached then
		return cached
	end
	local m: Metrics
	if build.classId == "Mage" then
		local byElement: { [string]: Metrics } = {}
		local runs: { Metrics } = {}
		for _, element in A.elements do
			local r = rawMetrics(build, L, element)
			byElement[element] = r
			table.insert(runs, r)
		end
		m = table.clone(runs[1])
		for _, field in NUMERIC do
			local sum = 0
			for _, r in runs do
				sum += (r :: any)[field]
			end
			(m :: any)[field] = sum / #runs
		end
		m.tsk1 = m.sustained60 / m.basic
		m.r1 = m.tsk1
		m.tsk2 = m.burst8 / m.basic
		m.tsk3 = m.aoe3burst / m.burst8
		m.tsk4 = m.demand / math.max(1e-9, m.regen + m.returns)
		m.mana = m.boss180 / math.max(1e-9, m.boss180u)
		local seen: { [string]: boolean } = {}
		local list: { string } = {}
		local off: { [string]: boolean } = {}
		local skipped: { [string]: { reason: string, count: number } } = {}
		local shares: { [string]: number } = {}
		for _, r in runs do
			for _, text in r.unmodelled do
				if not seen[text] then
					seen[text] = true
					table.insert(list, text)
				end
			end
			for _, id in r.offRotation do
				off[id] = true
			end
			for id, s in r.skipped do
				skipped[id] = skipped[id] or s
			end
			for id, v in r.shares do
				shares[id] = (shares[id] or 0) + v / #runs
			end
		end
		table.sort(list)
		local offList: { string } = {}
		for id in off do
			table.insert(offList, id)
		end
		table.sort(offList)
		m.unmodelled = list
		m.offRotation = offList
		m.skipped = skipped
		m.shares = shares
		m.byElement = byElement
	else
		m = rawMetrics(build, L, nil)
	end
	if L == 20 then
		m.tsk1rel, m.tsk2rel = 1, 1
	else
		local at20 = SkillModel.metrics(build, 20)
		m.tsk1rel = m.tsk1 / at20.tsk1
		m.tsk2rel = m.tsk2 / at20.tsk2
	end
	metricsCache[key] = m
	return m
end

-- Test helper (J1 b): effects of `applies` ({ t, kind, duration, tick, maxStacks }) on one dummy over `seconds`
-- through the model's Apply / tickEntity; returns every tick { t, amount } and the effects left at the end.
function SkillModel.timeline(applies: { { [string]: any } }, seconds: number): ({ { number } }, { [string]: any })
	local state: any = {
		t = 0,
		dealt = 0,
		by = {},
		healTo = {},
		selfDirty = false,
		self = { effects = {} },
		unmodelled = {},
	}
	local target = { m = B.monster(B.GENERIC, 20), hp = A.dummyHp, maxHp = A.dummyHp, dummy = true, effects = {} }
	local ticks: { { number } } = {}
	local steps = math.floor(seconds / A.dt + 0.5)
	local nextApply = 1
	for step = 0, steps do
		state.t = step * A.dt
		local before = state.dealt
		tickEntity(state, target)
		if state.dealt > before then
			table.insert(ticks, { state.t, state.dealt - before })
		end
		local a = applies[nextApply]
		while a and a.t <= state.t + EPS do
			apply(state, target, a.kind or "bleed", {
				duration = a.duration,
				value = a.value or 1,
				tickAmount = a.tick,
				maxStacks = a.maxStacks,
				skillId = a.skillId or "test",
				accumulate = a.accumulate,
			})
			nextApply += 1
			a = applies[nextApply]
		end
	end
	return ticks, target.effects
end

-- S86 (B13 test case, ROZWOJ 14.4): two burns of `a` and `b` damage in total (tick = total / Traits.ticks), `gap` s
-- apart, `duration` s each, refreshed with accumulate through the model's Apply; the sum of every tick.
function SkillModel.accumulateCase(a: number, b: number, gap: number, duration: number): number
	local per = Traits.ticks(duration)
	local ticks = SkillModel.timeline({
		{ t = 0, kind = "burn", duration = duration, tick = a / per, accumulate = true },
		{ t = gap, kind = "burn", duration = duration, tick = b / per, accumulate = true },
	}, gap + duration + 2)
	local sum = 0
	for _, tick in ticks do
		sum += tick[2]
	end
	return sum
end

-- Healing (F) -----------------------------------------------------------------------------------------------------

-- S85 (F1, T-SK5): one Heal of the build's Cleric at L on `tank` (a Balance.Player) as a share of the tank's max HP:
-- Skills.healAmount("heal") x the heal factor of another player (healPower, healBonus + allyHealBonus, healCrit as
-- expected value). Default tank: the convention Warrior (ROZWOJ 9.6, diag_skilltable). S86 (B1): the factor is the
-- fight's healFactor (one path with ctx.heal), the target at ASSUMPTIONS.healTargetFraction (no cut, no low-HP bonus).
function SkillModel.oneHeal(build: Build, L: number, tank: any?, gear: B.GearOpts?): number
	local sp = SkillModel.player(build, L, if gear then { gear = gear } else nil) -- S88: `gear` (Mythic +9)
	local tankPlayer = tank or B.player("Warrior", L)
	local rank = Paths.skillRank(sp.character, "heal")
	if rank <= 0 then
		return 0
	end
	local def = Paths.effectiveFor(sp.character, "heal", sp.weapons, rank)
	local amount = Skills.healAmount(def, rank, "heal", tankPlayer.values.maxHp, sp.p.values.magAtk or 0, L)
	local state = { sp = sp, p = sp.p, selfDirty = false, self = { effects = {} } }
	return amount * healFactor(state, "tank", false) / tankPlayer.values.maxHp
end

-- The tank "Defender" (guardian.defender) at L as a Balance.Player (T-SK5's second tank, S86, S87 G10, S89).
function SkillModel.defenderTank(L: number): any
	local build = SkillModel.build("guardian.defender", "Warrior") :: Build
	return SkillModel.player(build, L).p
end

export type HealerVsBoss = {
	bossId: string,
	level: number,
	seconds: number,
	hps: number, -- heal per second on the tank
	tankDps: number,
	tsk6: number,
	mana: number, -- heal rotation's mana on cooldown / regeneration (report)
	casts: { [string]: number },
	unmodelled: { string },
}

local healCache: { [string]: HealerVsBoss } = {}

-- S85 (F2, T-SK6): the build's Cleric in the party of the band's boss (party at boss level - 1; ASSUMPTIONS.team or
-- opts.team = "s92"), heal per second on the tank over Balance.bossFight(...).seconds from the build's rotation with
-- its mana (no potions) / the fight's tankDps. "Without overheal": no second target, no other members, no overflow
-- shield; amounts are not cut to missing HP (no HP axis, S86).
function SkillModel.healerVsBoss(build: Build, bossId: string, opts: { team: string? }?): HealerVsBoss
	local teamName = if opts and opts.team then opts.team else "default"
	local key = `{build.key}|{bossId}|{teamName}`
	local cached = healCache[key]
	if cached then
		return cached
	end
	local def = Bosses.byId[bossId] :: any
	local L = def.level - A.teamLevelGap
	local sp = SkillModel.player(build, L)
	local team: { any } = {}
	if teamName == "s92" then
		for _, k in A.teamS92 do
			if string.sub(k, 1, 7) == "healer." then
				table.insert(team, sp.p)
			else
				local b = SkillModel.build(k) :: Build
				table.insert(team, SkillModel.player(b, L).p)
			end
		end
	else
		for _, classId in A.team do
			table.insert(team, if classId == "Cleric" then sp.p else B.player(classId, L))
		end
	end
	local fightOf = B.bossFight(bossId, team)
	local m = B.monster(B.bossKind(def), def.level, "boss")
	local heal = { tank = team[1], team = #team }
	local r = SkillModel.fight(sp, { targets = { m }, seconds = fightOf.seconds, heal = heal })
	local cd = SkillModel.fight(sp, { targets = { m }, seconds = A.sustainedSeconds, heal = heal, unlimited = true })
	local hps = (r.healTo.tank or 0) / math.max(1e-9, fightOf.seconds)
	local out: HealerVsBoss = {
		bossId = bossId,
		level = L,
		seconds = fightOf.seconds,
		hps = hps,
		tankDps = fightOf.tankDps,
		tsk6 = hps / math.max(1e-9, fightOf.tankDps),
		mana = (cd.spent / A.sustainedSeconds) / math.max(1e-9, cd.regen),
		casts = r.casts,
		unmodelled = r.unmodelled,
	}
	healCache[key] = out
	return out
end

-- Target rows (J2) ----------------------------------------------------------------------------------------------------

-- T-SK4 bands (ROZWOJ 8, 12.7): the main builds 2.0-3.0, their variants from 1.6, the base 1.1-1.4.
-- S90 (F4, DECYZJE): the path bands of ROZWOJ 12.0 / 12.7 (were 2.0-3.0 and >= 1.6 for the variants, S87)
SkillModel.TSK4_BANDS = {
	["destroyer.destroyerExp"] = { 2.0, 2.8 },
	["arcanist.arcanistBoss"] = { 2.0, 2.4 },
	["destroyer.destroyerBoss"] = { 1.6, 2.8 },
	["arcanist.arcanistOverload"] = { 2.6, 2.8 },
	base = { 1.1, 1.4 },
	["base.loadout"] = { 1.1, 1.4 },
} :: { [string]: { number } }
SkillModel.TSK5_BAND = { 0.25, 0.35 } -- ROZWOJ 0, 7.5

-- S85 (J2): G10 rows for the global block (report until S87): T-SK4 of the Mage base and every Mage build from 45
-- (the target holds after 45, ROZWOJ 8; mean of the elements) and T-SK5 of the Cleric base and every Cleric build on
-- both tanks, L = 20, 25, ..., 100. Labels name the build key (and the tank). S86 (F3): only three rows a level stay
-- without `report` (the ones S87's global block asserts): T-SK4 of destroyer.destroyerExp and arcanist.arcanistBoss
-- (2.0-3.0, ROZWOJ 8, 12.7) and T-SK5 of healer.dungeon on guardian.defender (0.25-0.35, ROZWOJ 7.5); the variants,
-- the Mage base and the other S85 rows get report = true. T-SK4 now counts Arcane Charges and the passive returns
-- (B12), T-SK5 the heal factor of B1.
SkillModel.G10_ASSERTED = {
	["T-SK4|destroyer.destroyerExp"] = true,
	["T-SK4|arcanist.arcanistBoss"] = true,
	["T-SK5|healer.dungeon|guardian.defender"] = true,
} :: { [string]: boolean }
function SkillModel.targetsG10(): { B.TargetRow }
	local rows: { B.TargetRow } = {}
	for _, L in SkillModel.G10_LEVELS do
		if L >= 45 then
			for _, build in SkillModel.builds("Mage") do
				local band = SkillModel.TSK4_BANDS[build.key] or { 2.0, 3.0 }
				local m = SkillModel.metrics(build, L)
				table.insert(
					rows,
					{
						id = "G10",
						group = "G10",
						label = `T-SK4 Mage {build.key} {L}`,
						value = m.tsk4,
						low = band[1],
						high = band[2],
						classId = "Mage",
						level = L,
						report = if SkillModel.G10_ASSERTED[`T-SK4|{build.key}`] then nil else true,
					} :: any
				)
			end
		end
		local tanks = { { "Warrior", B.player("Warrior", L) }, { "guardian.defender", SkillModel.defenderTank(L) } }
		for _, build in SkillModel.builds("Cleric") do
			for _, tank in tanks do
				table.insert(
					rows,
					{
						id = "G10",
						group = "G10",
						label = `T-SK5 Cleric {build.key} na {tank[1]} {L}`,
						value = SkillModel.oneHeal(build, L, tank[2]),
						low = SkillModel.TSK5_BAND[1],
						high = SkillModel.TSK5_BAND[2],
						classId = "Cleric",
						level = L,
						report = if SkillModel.G10_ASSERTED[`T-SK5|{build.key}|{tank[1]}`] then nil else true,
					} :: any
				)
			end
		end
	end
	return rows
end

-- S85 (J2): the Meadows' rows at L20: T-SK3 of every base and build against its areaCap, T-SK6 of every Cleric
-- build on Grimrok (default party). S86 (F4): after the mechanics every row that holds is asserted by the region
-- block (no `report`). S91: T-SK6 back in band for the healing builds (heal cost 12, Grimrok); the rows below stay
-- printed with the reason (report = the owner): builds that never heal the tank
SkillModel.MEADOWS_REPORT = {
	-- S91: T-SK6 Grimrok poza zasięgiem dźwigni S91: 0.13 (healer.solo): rotacja „Uzdrowiciela solo” leczy tylko
	-- siebie poniżej 50% HP, więc tanka nie leczy (definicja T-SK6 jest dla buildów leczących drużynę)
	["R.meadows.tsk6.healer.solo"] = true,
	-- S91: T-SK6 Grimrok poza zasięgiem dźwigni S91: 0.00 (inquisitor.solo, inquisitor.bulwark): rotacja Inkwizytora
	-- nie leczy tanka (definicja T-SK6 jest dla buildów leczących)
	["R.meadows.tsk6.inquisitor.solo"] = true,
	["R.meadows.tsk6.inquisitor.bulwark"] = true,
} :: { [string]: boolean }
function SkillModel.targetsMeadows(): { B.TargetRow }
	local rows: { B.TargetRow } = {}
	for _, classId in B.CLASSES do
		for _, build in SkillModel.builds(classId) do
			local id = `R.meadows.tsk3.{classId}.{build.key}`
			table.insert(
				rows,
				{
					id = id,
					group = "T-SK3",
					label = `T-SK3 {classId} {build.key} 20`,
					value = SkillModel.metrics(build, 20).tsk3,
					high = build.areaCap,
					classId = classId,
					level = 20,
					report = if SkillModel.MEADOWS_REPORT[id] then "właściciel" else nil,
				} :: any
			)
		end
	end
	for _, build in SkillModel.builds("Cleric") do
		local id = `R.meadows.tsk6.{build.key}`
		table.insert(
			rows,
			{
				id = id,
				group = "T-SK6",
				label = `T-SK6 Cleric {build.key} grimrok`,
				value = SkillModel.healerVsBoss(build, "grimrok").tsk6,
				low = 1.0,
				high = 2.0,
				classId = "Cleric",
				level = 20,
				report = if SkillModel.MEADOWS_REPORT[id] then "właściciel" else nil,
			} :: any
		)
	end
	return rows
end

-- S86: class bases, path metrics and targets -----------------------------------------------------------------------

local variantCache: { [string]: Build } = {}

local function weaponKey(w: { main: string, offhand: string? }): string
	return if w.offhand then `{w.main}+{w.offhand}` else w.main
end

-- A build with another weapon (key "<key>@<weapon>"; the weapon of the path measurement, S90 R5).
function SkillModel.withWeapon(build: Build, main: string, offhand: string?): Build
	local w = { main = main, offhand = offhand }
	if build.weapon.main == main and build.weapon.offhand == offhand then
		return build
	end
	local key = `{build.key}@{weaponKey(w)}`
	local cached = variantCache[`{build.classId}|{key}`]
	if cached then
		return cached
	end
	local copy: any = table.clone(build)
	copy.key = key
	copy.weapon = w
	variantCache[`{build.classId}|{key}`] = copy
	return copy
end

-- Skills the class base can use (no path, or a node in the base rows).
local baseSkillCache: { [string]: { [string]: boolean } } = {}
local function baseSkills(classId: string): { [string]: boolean }
	local cached = baseSkillCache[classId]
	if cached then
		return cached
	end
	local base = SkillModel.builds(classId)[1]
	local inBase: { [string]: boolean } = {}
	for _, entry in base.nodes do
		inBase[entry[1]] = true
	end
	local out: { [string]: boolean } = {}
	for _, path in Paths.pathsOf(classId) do
		for _, row in path.rows do
			for _, node in row.nodes do
				if node.kind == "skill" and node.skill and inBase[node.id] then
					out[node.skill] = true
				end
			end
		end
	end
	for _, def in Skills.unlocked(classId, 100) do
		if def.path == nil then
			out[def.id] = true
		end
	end
	baseSkillCache[classId] = out
	return out
end

-- S86 (BASES, DECYZJE): the class base a path build is compared with. The S85 base (rows 1 of every path, Mage 1-2,
-- full ranks, Classes.statPlan) with the weapon of SkillModel.BASES (the Hunter: the compared weapon and a quiver),
-- the compared build's breakpoints on the skills they share (the rest A), and the compared build's rotation limited
-- to the base's skills, then the other entries of the S85 base rotation in their order.
function SkillModel.baseFor(build: Build, weapon: { main: string, offhand: string? }?): Build
	local classId = build.classId
	local spec = SkillModel.BASES[classId]
	local w = if spec.sameWeapon then { main = (weapon or build.weapon).main, offhand = spec.offhand } else spec.weapon
	local key = `base.{string.lower(classId)}@{build.key}@{weaponKey(w)}`
	local cached = variantCache[`{classId}|{key}`]
	if cached then
		return cached
	end
	local base = SkillModel.builds(classId)[1]
	local skills = baseSkills(classId)
	local bp: { [string]: string } = {}
	for k, option in build.bp do
		local id = string.match(k, "^(.-):")
		if id and skills[id] then
			bp[k] = option
		end
	end
	local rotation: { { [string]: any } } = {}
	local seen: { [string]: boolean } = {}
	for _, entry in build.rotation do
		if skills[entry.skill] and not seen[entry.skill] then
			seen[entry.skill] = true
			table.insert(rotation, entry)
		end
	end
	for _, entry in base.rotation do
		if not seen[entry.skill] then
			seen[entry.skill] = true
			table.insert(rotation, entry)
		end
	end
	local copy: any = table.clone(base)
	copy.key = key
	copy.weapon = { main = w.main, offhand = w.offhand }
	copy.bp = bp
	copy.rotation = rotation
	variantCache[`{classId}|{key}`] = copy
	return copy
end

SkillModel.FURY = "berserker.fury" -- the damage reference of every class (ROZWOJ 7.5, 10.4)

local function byKey(key: string): Build
	local build = SkillModel.build(key)
	assert(build, `SkillModel: unknown build {key}`)
	return build
end
SkillModel.byKey = byKey

-- The "Furia" metrics at L (D2).
function SkillModel.fury(L: number): Metrics
	return SkillModel.metrics(byKey(SkillModel.FURY), L)
end

-- Fury reference (D2) ---------------------------------------------------------------------------------------------

export type FuryRef = {
	single60: number,
	basic: number,
	r1: number,
	burst8: number,
	group: number,
	maxHp: number,
	ehp: number,
	ehpRed: number,
	furyMean: number,
	furyMeanGroup: number,
	lifesteal: number, -- life steal heals / damage taken in a group of 3 that hits back (ROZWOJ 10.7 risk 3)
	vsBase: number, -- single60 / the base with axe2h
}

local furyRefCache: { [number]: FuryRef } = {}

-- S86 (D2): the Berserker "Furia" at L: the S85 numbers, EHP, the Fury means next to the 7.5 of ROZWOJ 10.6 and the
-- life steal balance in a fight with 3 monsters that hit back.
function SkillModel.furyReference(L: number): FuryRef
	local cached = furyRefCache[L]
	if cached then
		return cached
	end
	local build = byKey(SkillModel.FURY)
	local m = SkillModel.metrics(build, L)
	local sp = SkillModel.player(build, L)
	local group = {}
	for _ = 1, A.areaTargets do
		table.insert(group, B.monster(B.GENERIC, L))
	end
	local r = SkillModel.fight(sp, {
		targets = group,
		dummy = false,
		retaliate = true,
		seconds = A.retaliateSeconds,
	})
	local out: FuryRef = {
		single60 = m.single60,
		basic = m.basic,
		r1 = m.r1,
		burst8 = m.burst8,
		group = m.aoe3burst,
		maxHp = m.maxHp,
		ehp = m.ehp,
		ehpRed = m.ehpRed,
		furyMean = m.furyMean,
		furyMeanGroup = m.furyMeanGroup,
		lifesteal = r.lifestealHeal / math.max(1e-9, r.taken),
		vsBase = m.single60 / SkillModel.metrics(SkillModel.baseFor(build), L).single60,
	}
	furyRefCache[L] = out
	return out
end

-- Party values B and S (D) ----------------------------------------------------------------------------------------

export type Support = { B: number, S: number, value: number, sources: { [string]: number } }

-- The damage factor of a party bonus on the "Furia" Berserker at L (Balance.dps with SKILL_DPS: basic attacks and
-- skills): attack %, attack speed %, crit points, the target's armour break %.
local function partyGain(L: number, bonus: { atk: number?, haste: number?, crit: number?, armor: number? }): number
	local p = SkillModel.player(byKey(SkillModel.FURY), L).p
	local m = B.monster(B.GENERIC, L)
	local before = B.dps(p, m)
	local q: any = table.clone(p)
	q.values = table.clone(p.values)
	q.values.physAtk = (q.values.physAtk or 0) * (1 + (bonus.atk or 0) / 100)
	q.values.magAtk = (q.values.magAtk or 0) * (1 + (bonus.atk or 0) / 100)
	q.values.atkSpeed = (q.values.atkSpeed or 1) * (1 + (bonus.haste or 0) / 100)
	q.values.critChance = (q.values.critChance or 0) + (bonus.crit or 0)
	local target = m
	if (bonus.armor or 0) > 0 then
		target = table.clone(m)
		target.armor = m.armor * (1 - bonus.armor / 100)
	end
	return B.dps(q, target) / math.max(1e-9, before) - 1
end
SkillModel.partyGain = partyGain

local supportCache: { [string]: Support } = {}

-- S86 (D5, ROZWOJ 7.5, 10.6): B of the Standard-Bearer: the time means over A.bossSeconds on one dummy of the ally
-- effects of its rotation (allyAttack: Commander's Voice; allyHaste: the War Banner; allyCrit: Inspiration on the
-- banner's pulses and the Order to Advance, the strongest in the category per step) and of the Crushing Blow's armour
-- break on the target, each turned into party damage on "Furia" (partyGain) x ASSUMPTIONS.bannerUptime. S = 1 target
-- 60 s / "Furia". Value = 4 x (1 + B) + S.
function SkillModel.standardSupport(build: Build, L: number): Support
	local key = `std|{build.key}|{L}`
	if supportCache[key] then
		return supportCache[key]
	end
	local sp = SkillModel.player(build, L)
	local sums: { [string]: number } = {}
	local function add(name: string, v: number)
		sums[name] = (sums[name] or 0) + v * A.dt
	end
	local r = SkillModel.fight(sp, {
		seconds = A.bossSeconds,
		sample = function(state: any)
			local strongest: { [string]: any } = {}
			for _, e in state.self.effects do
				if e.expiresAt > state.t + EPS and e.kind == "statBuff" and e.category then
					local c = e.category
					if c == "allyAttack" or c == "allyHaste" or c == "allyCrit" then
						local v = 0
						for _, x in e.stats or {} do
							v = math.max(v, x)
						end
						if not strongest[c] or v > strongest[c].v then
							strongest[c] = { v = v, id = e.skillId or "?" }
						end
					end
				end
			end
			for c, s in strongest do
				add(`{c}|{s.id}`, s.v)
			end
			local tg = state.targets[1]
			local brk = 0
			for _, e in tg.effects do
				if
					e.kind == "armorBreak"
					and e.category == "enemyArmor"
					and not e.item
					and e.expiresAt > state.t + EPS
				then
					brk = math.max(brk, e.value or 0)
				end
			end
			add("armor|crushingBlow", brk)
		end,
	})
	local T = r.seconds
	local sources: { [string]: number } = {}
	local total = 0
	for name, sum in sums do
		local mean = sum / T
		local c = string.match(name, "^(.-)|") :: string
		local gain = if c == "allyAttack"
			then partyGain(L, { atk = mean })
			elseif c == "allyHaste" then partyGain(L, { haste = mean })
			elseif c == "allyCrit" then partyGain(L, { crit = mean })
			else partyGain(L, { armor = mean })
		local value = gain * A.bannerUptime
		sources[name] = value
		total += value
	end
	local S = SkillModel.metrics(build, L).single60 / SkillModel.fury(L).single60
	local out: Support = { B = total, S = S, value = 4 * (1 + total) + S, sources = sources }
	supportCache[key] = out
	return out
end

-- S86 (D6, ROZWOJ 7.5, 11.6): B of the Scout: the time mean of enemyWeak on a boss over A.bossSeconds (Hunter's Mark,
-- Spotting with spotBonus, Drive; the strongest entry per step, a weaker one never adds, 7.1) as damage of everyone
-- hitting the boss. S = 1 target 60 s / "Królobójca" with the long bow.
function SkillModel.scoutSupport(build: Build, L: number): Support
	local key = `scout|{build.key}|{L}`
	if supportCache[key] then
		return supportCache[key]
	end
	local sp = SkillModel.player(build, L)
	local sums: { [string]: number } = {}
	local r = SkillModel.fight(sp, {
		seconds = A.bossSeconds,
		targets = { B.monster(B.GENERIC, L, "boss") },
		sample = function(state: any)
			local tg = state.targets[1]
			local best, id = 0, nil
			for _, e in tg.effects do
				if e.kind == "vulnerability" and e.category == "enemyWeak" and e.expiresAt > state.t + EPS then
					if (e.value or 0) > best then
						best, id = e.value, e.skillId or "?"
					end
				end
			end
			if id then
				sums[id] = (sums[id] or 0) + best * A.dt
			end
		end,
	})
	local sources: { [string]: number } = {}
	local total = 0
	for id, sum in sums do
		sources[id] = sum / r.seconds / 100
		total += sources[id]
	end
	local ref = SkillModel.withWeapon(byKey("marksman.kingslayer"), "longbow", "quiver")
	local S = SkillModel.metrics(build, L).single60 / SkillModel.metrics(ref, L).single60
	local out: Support = { B = total, S = S, value = 4 * (1 + total) + S, sources = sources }
	supportCache[key] = out
	return out
end

-- S86 (B2, ROZWOJ 9.4, 9.6): the party bonus of Fortune: time means over 180 s (a boss fight) of the dice and the
-- wheel on an ally (crit points, attack speed %) turned into damage on "Furia", and the share of time the boss has
-- misfortune with its mean.
export type FortuneBonus = { dice: number, wheel: number, missUptime: number, missMean: number }
function SkillModel.fortuneBonus(build: Build, L: number): FortuneBonus
	local sp = SkillModel.player(build, L)
	local sums = { diceCrit = 0, diceHaste = 0, wheelCrit = 0, wheelHaste = 0, miss = 0, missTime = 0 }
	local r = SkillModel.fight(sp, {
		seconds = A.bossSeconds,
		targets = { B.monster(B.GENERIC, L, "boss") },
		sample = function(state: any)
			for _, e in state.self.effects do
				if e.kind == "statBuff" and e.expiresAt > state.t + EPS and e.stats then
					local prefix = if e.skillId == "fortuneDice"
						then "dice"
						elseif e.skillId == "wheelOfFortune" then "wheel"
						else nil
					if prefix then
						sums[prefix .. "Crit"] += (e.stats.critChance or 0) * A.dt
						sums[prefix .. "Haste"] += (e.stats.atkSpeed or 0) * A.dt
					end
				end
			end
			local miss = maxOf(state, state.targets[1], "misfortune")
			if miss > 0 then
				sums.miss += miss * A.dt
				sums.missTime += A.dt
			end
		end,
	})
	local T = r.seconds
	return {
		dice = partyGain(L, { crit = sums.diceCrit / T, haste = sums.diceHaste / T }),
		wheel = partyGain(L, { crit = sums.wheelCrit / T, haste = sums.wheelHaste / T }),
		missUptime = sums.missTime / T,
		missMean = if sums.missTime > 0 then sums.miss / sums.missTime else 0,
	}
end

-- Pace and grind (D3-D6) --------------------------------------------------------------------------------------------

-- S86 (ROZWOJ 10.6): solo pace of a support or tank build: (walk + fightRef / g) / (walk + fightRef), g = group (3
-- targets 8 s) / the group of `ref` (default "Furia").
function SkillModel.pace(build: Build, L: number, ref: Build?): number
	local g = SkillModel.metrics(build, L).aoe3burst / SkillModel.metrics(ref or byKey(SkillModel.FURY), L).aoe3burst
	return (A.walk + A.fightRef / math.max(1e-9, g)) / (A.walk + A.fightRef)
end

-- The Hunter's combat builds of the Scout's pace (the faster of the Marksman and the Trapper on the better weapon).
local function hunterCombat(): { Build }
	return {
		SkillModel.withWeapon(byKey("marksman.kingslayer"), "heavycrossbow", "quiver"),
		SkillModel.withWeapon(byKey("marksman.kingslayer"), "longbow", "quiver"),
		SkillModel.withWeapon(byKey("trapper.poacher"), "crossbow", "quiver"),
		SkillModel.withWeapon(byKey("trapper.poacher"), "bow", "quiver"),
	}
end

local killCache: { [string]: number } = {}
-- S86 (D3): seconds to kill `n` monsters of level L that hit back (GENERIC, potions on), the player from full HP.
function SkillModel.killTime(build: Build, L: number, n: number?): number
	local count = n or A.areaTargets
	local key = `{build.classId}|{build.key}|{L}|{count}`
	if killCache[key] then
		return killCache[key]
	end
	local function one(element: string?): number
		local sp = SkillModel.player(build, L, { element = element })
		local group = {}
		for _ = 1, count do
			table.insert(group, B.monster(B.GENERIC, L))
		end
		local r = SkillModel.fight(sp, {
			targets = group,
			dummy = false,
			retaliate = true,
			hpPotions = true,
			potions = true,
			seconds = A.retaliateSeconds,
		})
		-- a death is no kill: the whole window (not the short time to the fall)
		return if r.died then A.retaliateSeconds else r.seconds
	end
	local t
	if build.classId == "Mage" then
		t = 0
		for _, element in A.elements do
			t += one(element) / #A.elements
		end
	else
		t = one(nil)
	end
	killCache[key] = t
	return t
end

-- S86 (ROZWOJ 11.6): the Scout's pace (a) (walk + fightRef / r) / (walk + fightRef), r = group / the fastest combat
-- build's group; (b) (walk + t) / (walk + t_min), t = the time to kill 3 monsters that hit back.
function SkillModel.scoutPace(build: Build, L: number): (number, number)
	local best, bestTime = 0, math.huge
	for _, b in hunterCombat() do
		best = math.max(best, SkillModel.metrics(b, L).aoe3burst)
		bestTime = math.min(bestTime, SkillModel.killTime(b, L))
	end
	local r = SkillModel.metrics(build, L).aoe3burst / math.max(1e-9, best)
	local a = (A.walk + A.fightRef / math.max(1e-9, r)) / (A.walk + A.fightRef)
	local b = (A.walk + SkillModel.killTime(build, L)) / (A.walk + bestTime)
	return a, b
end

-- Group sizes of 20 fights in a row with the AreaSpawns weights (largest remainder, the smaller sizes first).
local function grindSizes(n: number): { number }
	local weights = B.groupWeights()
	local total = 0
	for _, w in weights do
		total += w
	end
	local out: { number } = {}
	local got: { [number]: number } = {}
	for i = 1, n do
		local best, bestGap = 1, -math.huge
		for size, w in weights do
			local gap = i * w / total - (got[size] or 0)
			if gap > bestGap + 1e-9 or (math.abs(gap - bestGap) <= 1e-9 and size < best) then
				best, bestGap = size, gap
			end
		end
		got[best] = (got[best] or 0) + 1
		table.insert(out, best)
	end
	return out
end
SkillModel.grindSizes = grindSizes

export type Grind = { seconds: number, fight: number, between: number, died: number }
local grindCache: { [string]: Grind } = {}

-- S86 (D4, ROZWOJ 9.6): Cleric grind: ASSUMPTIONS.grindFights fights in a row with groups of the region kind of L
-- (Balance.kindAtRegion, AreaSpawns sizes) that hit back; HP and mana carry over; between fights a Heal on itself
-- (ASSUMPTIONS.grindHealSeconds s and grindHealMana mana a cast, waiting for mana when short) or, `rest`, the rest at
-- restPct % max HP a second. Returns the total seconds.
function SkillModel.grind(build: Build, L: number, rest: boolean?): Grind
	local key = `{build.key}|{L}|{rest == true}`
	if grindCache[key] then
		return grindCache[key]
	end
	local sp = SkillModel.player(build, L)
	local kind = Monsters.get(B.kindAtRegion(L)) :: any
	local hp, pool = 1, 1
	local fightTime, between, died = 0, 0, 0
	local v = sp.p.values
	local healRank = Paths.skillRank(sp.character, "heal")
	local healDef = if healRank > 0 then Paths.effectiveFor(sp.character, "heal", sp.weapons, healRank) else nil
	local poolMax = if sp.resource == "mana" then v.maxMana else v.maxEnergy
	local regen = if sp.resource == "mana" then v.manaRegen or 0 else v.energyRegen or 0
	for _, size in grindSizes(A.grindFights) do
		local r = SkillModel.fight(sp, {
			targets = FightSim.group(kind, L, size),
			dummy = false,
			retaliate = true,
			startHp = hp,
			startPool = pool,
			seconds = A.retaliateSeconds,
		})
		-- a fight lost to death counts the whole window (as killTime), never the short time to the fall
		fightTime += if r.died then A.retaliateSeconds else r.seconds
		if r.died then
			died += 1
		end
		hp = math.max(0.01, r.hpEnd)
		pool = r.poolEnd / math.max(1, poolMax)
		if rest or not healDef then
			local t = (1 - hp) * 100 / A.restPct
			between += t
			hp = 1
			pool = math.min(1, pool + regen * t / math.max(1, poolMax))
		else
			-- the HP track of the grind (lowHpHealBonus below SkillData.LOW_HP_HEAL, as Context.healFactor)
			local state = {
				sp = sp,
				p = sp.p,
				selfDirty = false,
				self = { effects = {} },
				retaliate = true,
				hp = hp * v.maxHp,
				maxHp = v.maxHp,
			}
			local guard = 0
			while hp < 1 - 1e-6 and guard < 100 do
				state.hp = hp * v.maxHp
				guard += 1
				local mana = pool * poolMax
				if mana < A.grindHealMana then
					local wait = (A.grindHealMana - mana) / math.max(1e-9, regen)
					between += wait
					pool = A.grindHealMana / poolMax
				end
				local amount = Skills.healAmount(healDef, healRank, "heal", v.maxHp, v.magAtk or 0, L)
					* healFactor(state, "self", false)
				hp = math.min(1, hp + amount / v.maxHp)
				pool = math.min(1, pool - A.grindHealMana / poolMax + regen * A.grindHealSeconds / poolMax)
				between += A.grindHealSeconds
			end
		end
	end
	local out: Grind = { seconds = fightTime + between, fight = fightTime, between = between, died = died }
	grindCache[key] = out
	return out
end

-- Elites (E3) -------------------------------------------------------------------------------------------------------

local caveCache: { [string]: any } = {}
local function cavesOf(mapId: string): any
	if not caveCache[mapId] then
		caveCache[mapId] = B.caveElites(mapId)
	end
	return caveCache[mapId]
end

-- The Elite and Elite II kinds of the region of L (the cave Elite whose spawner range holds L or is nearest; the
-- Elite II spawner nearest L).
function SkillModel.eliteKinds(L: number): (string?, string?)
	local mapId = B.REGION_IDS[B.regionAt(L)]
	local elite, eliteGap = nil, math.huge
	local elite2, elite2Gap = nil, math.huge
	for _, cave in cavesOf(mapId) do
		for _, k in cave.kinds do
			local gap = math.max(k.min - L, L - k.max, 0)
			if gap < eliteGap then
				elite, eliteGap = k.kind, gap
			end
		end
		for _, e in cave.elite2 do
			local gap = math.abs(e.spawner - L)
			if gap < elite2Gap then
				elite2, elite2Gap = e.kind, gap
			end
		end
	end
	return elite, elite2
end

export type Duel = { kind: string, won: boolean, seconds: number, hpEnd: number }
local duelCache: { [string]: Duel } = {}

-- S86 (E3): a duel of the build's player with a monster of `kind` at L (variant "elite" or "elite2" with its ability
-- from MonsterAbilities, as Balance.elite / elite2), both potions, the monster hits back. Won = the monster died first.
function SkillModel.duel(build: Build, L: number, kind: string, variant: string): Duel
	local key = `{build.classId}|{build.key}|{L}|{kind}|{variant}`
	if duelCache[key] then
		return duelCache[key]
	end
	local def = Monsters.get(kind) :: any
	local m = table.clone(B.monster(def, L, variant))
	m.delivery = def.attack
	if variant == "elite2" and def.ability then
		m.ability = MonsterAbilities.get(def.ability)
	end
	local sp = SkillModel.player(build, L, if build.classId == "Mage" then { element = "fire" } else nil)
	local r = SkillModel.fight(sp, {
		targets = { m },
		dummy = false,
		retaliate = true,
		hpPotions = true,
		potions = true,
		seconds = A.retaliateSeconds,
	})
	local out: Duel =
		{ kind = kind, won = not r.died and r.seconds < A.retaliateSeconds - EPS, seconds = r.seconds, hpEnd = r.hpEnd }
	duelCache[key] = out
	return out
end

-- Intercept (B7) ----------------------------------------------------------------------------------------------------

export type InterceptReport = {
	level: number,
	mageHit: number, -- the boss's biggest hit on the Mage (S134: plain or an `avoid` blow taken) / Mage max HP
	mageKept: number, -- with Intercept (Logic/Intercept.resolve)
	mageCovered: number, -- with Intercept and Cover (allyGuard)
	guardTook: number, -- the guard's part after Martyr (Intercept.split) / guard max HP
	wallNoCap: number, -- a red zone on the whole party with Shield Wall: the guard's total without the cap / max HP
	wallCap: number, -- the same with caps.interceptPerSecond (Intercept.take)
}

-- S86 (B7, ROZWOJ 10.6) mirrors StatusEffectService interceptFilter (Logic/Intercept.applies / pick / part / take /
-- resolve, then Intercept.split with Martyr): the S83 boss of the band (default party) and the "Obrońca" at L.
function SkillModel.interceptReport(L: number): InterceptReport
	local bossId = SkillModel.BOSS_AT[L]
	local def = Bosses.byId[bossId] :: any
	local team = {}
	for _, classId in A.team do
		table.insert(team, B.player(classId, L))
	end
	local f = B.bossFight(bossId, team)
	local mage = team[2]
	-- S134: the biggest blow that can land on the Mage: a plain one or an `avoid` blow taken (not dodged)
	local mageHit = math.max(f.biggestHit.Mage or 0, f.biggestAvoidable.Mage or 0) * mage.values.maxHp
	local guardBuild = byKey("guardian.defender")
	local gsp = SkillModel.player(guardBuild, L)
	local guardHp = gsp.p.values.maxHp
	local function valueOf(skillId: string, field: string): number
		local rank = Paths.skillRank(gsp.character, skillId)
		if rank <= 0 then
			return 0
		end
		local skill = Paths.effectiveFor(gsp.character, skillId, gsp.weapons, rank)
		return Skills.valueAt(skill, field, rank)
	end
	local share = valueOf("intercept", "share")
	local martyr = gsp.pathHooks.interceptMitigation or 0
	local thorns = gsp.pathHooks.interceptThorns or 0
	local windows = {}
	local kept, _, moved = Intercept.resolve(
		"monster",
		mageHit,
		{
			{ guard = "guard", share = share, radius = 30, distance = 5, alive = true },
		},
		windows,
		0,
		function()
			return guardHp
		end
	)
	local toGuard = Intercept.split(moved, martyr, thorns)
	local cover = 0
	for _, aura in Paths.auras(gsp.character, gsp.weapons) do
		if aura.category == "allyGuard" then
			cover = math.max(cover, aura.stats.value or 0)
		end
	end
	-- Shield Wall: the biggest special attack as a red zone on every member, its share of the four others moves.
	-- S134: no mechanic (a split's total is shared by those inside, a mark hits one, a channel has no area)
	local wall = valueOf("shieldWall", "share")
	local m = B.monster(B.bossKind(def), def.level, "boss")
	local biggest = 1
	for _, attack in def.attacks do
		if attack.mechanic == nil then
			biggest = math.max(biggest, attack.damage)
		end
	end
	local own = FightSim.hit(m, gsp.p, biggest, nil, false)
	local parts, capped = 0, 0
	local wallWindows = {}
	for i = 2, #team do
		local hit = FightSim.hit(m, team[i], biggest, nil, false)
		local part = Intercept.part(hit, wall)
		parts += part
		local taken, w = Intercept.take(wallWindows.guard, 0, guardHp, part)
		wallWindows.guard = w
		capped += taken
	end
	local reduce = 1 - math.clamp(martyr, 0, 100) / 100
	return {
		level = L,
		mageHit = mageHit / mage.values.maxHp,
		mageKept = kept / mage.values.maxHp,
		mageCovered = kept * (1 - cover / 100) / mage.values.maxHp,
		guardTook = toGuard / guardHp,
		wallNoCap = (own + parts * reduce) / guardHp,
		wallCap = (own + capped * reduce) / guardHp,
	}
end

-- Mage group clearing (D8) ------------------------------------------------------------------------------------------

-- "Arkanista na exp" (ROZWOJ 12.5, model only): the arcanistBoss nodes, breakpoints A, the rotation without the
-- Arcane Torrent.
function SkillModel.arcanistExp(): Build
	local cached = variantCache["Mage|arcanist.arcanistExp"]
	if cached then
		return cached
	end
	local ref = byKey("arcanist.arcanistBoss")
	local copy: any = table.clone(ref)
	copy.key = "arcanist.arcanistExp"
	copy.bp = {}
	local rotation = {}
	for _, entry in ref.rotation do
		if entry.skill ~= "arcaneTorrent" then
			table.insert(rotation, entry)
		end
	end
	copy.rotation = rotation
	variantCache["Mage|arcanist.arcanistExp"] = copy
	return copy
end

-- S86 (D8): seconds to kill `n` GENERIC monsters of L standing in the area (no blows back), mean of the elements.
function SkillModel.clearTime(build: Build, L: number, n: number): number
	local t = 0
	for _, element in A.elements do
		local sp = SkillModel.player(build, L, { element = element })
		local group = {}
		for _ = 1, n do
			table.insert(group, B.monster(B.GENERIC, L))
		end
		t += SkillModel.fight(sp, { targets = group, dummy = false, seconds = A.retaliateSeconds }).seconds / #A.elements
	end
	return t
end

-- Targets (E2) ------------------------------------------------------------------------------------------------------

-- The build of a target row (with its weapon variant), of the row's class ("base" names every class's base).
local function rowBuild(row: PathTarget): Build
	local build = SkillModel.build(row.build, row.classId)
	assert(build, `SkillModel: unknown build {row.classId} {row.build}`)
	if row.weapon then
		build = SkillModel.withWeapon(build, row.weapon.main, row.weapon.offhand)
	end
	return build
end

local function ratio(a: number, b: number): number
	return a / math.max(1e-12, b)
end

local function grindRatio(build: Build, L: number): number
	return ratio(SkillModel.grind(build, L).seconds, SkillModel.grind(byKey("inquisitor.solo"), L).seconds)
end

-- S86 (D): every metric of a target row: (row, L) -> value. Ratios are the definitions of docs/sessions/S86.md
-- "Definicje metryk" (DECYZJE S86).
SkillModel.TARGET_METRICS = {
	["single60/base"] = function(row: PathTarget, L: number): number
		local build = rowBuild(row)
		return ratio(SkillModel.metrics(build, L).single60, SkillModel.metrics(SkillModel.baseFor(build), L).single60)
	end,
	["single60/fury"] = function(row: PathTarget, L: number): number
		return ratio(SkillModel.metrics(rowBuild(row), L).single60, SkillModel.fury(L).single60)
	end,
	["ehp/fury"] = function(row: PathTarget, L: number): number
		return ratio(SkillModel.metrics(rowBuild(row), L).ehp, SkillModel.fury(L).ehp)
	end,
	["ehpRed/fury"] = function(row: PathTarget, L: number): number
		return ratio(SkillModel.metrics(rowBuild(row), L).ehpRed, SkillModel.fury(L).ehpRed)
	end,
	["group/fury"] = function(row: PathTarget, L: number): number
		return ratio(SkillModel.metrics(rowBuild(row), L).aoe3burst, SkillModel.fury(L).aoe3burst)
	end,
	["maxHp/fury"] = function(row: PathTarget, L: number): number
		return ratio(SkillModel.metrics(rowBuild(row), L).maxHp, SkillModel.fury(L).maxHp)
	end,
	support = function(row: PathTarget, L: number): number
		local build = rowBuild(row)
		local s = if build.classId == "Hunter"
			then SkillModel.scoutSupport(build, L)
			else SkillModel.standardSupport(build, L)
		return s.value
	end,
	S = function(row: PathTarget, L: number): number
		local build = rowBuild(row)
		local s = if build.classId == "Hunter"
			then SkillModel.scoutSupport(build, L)
			else SkillModel.standardSupport(build, L)
		return s.S
	end,
	["pace/fury"] = function(row: PathTarget, L: number): number
		return SkillModel.pace(rowBuild(row), L)
	end,
	scoutPaceA = function(row: PathTarget, L: number): number
		local a = SkillModel.scoutPace(rowBuild(row), L)
		return a
	end,
	scoutPaceB = function(row: PathTarget, L: number): number
		local _, b = SkillModel.scoutPace(rowBuild(row), L)
		return b
	end,
	tsk5 = function(row: PathTarget, L: number): number
		return SkillModel.oneHeal(rowBuild(row), L, SkillModel.defenderTank(L))
	end,
	healLess = function(row: PathTarget, L: number): number
		local tank = SkillModel.defenderTank(L)
		return 1
			- ratio(SkillModel.oneHeal(rowBuild(row), L, tank), SkillModel.oneHeal(byKey("healer.dungeon"), L, tank))
	end,
	["grind/inquisitor"] = function(row: PathTarget, L: number): number
		return grindRatio(rowBuild(row), L)
	end,
	["aoe8/marksmanBest"] = function(row: PathTarget, L: number): number
		local best = 0
		for _, weapon in { "heavycrossbow", "longbow" } do
			local b = SkillModel.withWeapon(byKey("marksman.kingslayer"), weapon, "quiver")
			best = math.max(best, SkillModel.metrics(b, L).aoe3burst)
		end
		return ratio(SkillModel.metrics(rowBuild(row), L).aoe3burst, best)
	end,
	["aoe60/base"] = function(row: PathTarget, L: number): number
		local build = rowBuild(row)
		return ratio(SkillModel.metrics(build, L).aoe3sus, SkillModel.metrics(SkillModel.baseFor(build), L).aoe3sus)
	end,
	["boss180/base"] = function(row: PathTarget, L: number): number
		local build = rowBuild(row)
		return ratio(SkillModel.metrics(build, L).boss180, SkillModel.metrics(SkillModel.baseFor(build), L).boss180)
	end,
	["boss180/destroyerBoss"] = function(row: PathTarget, L: number): number
		return ratio(
			SkillModel.metrics(rowBuild(row), L).boss180,
			SkillModel.metrics(byKey("destroyer.destroyerBoss"), L).boss180
		)
	end,
	["clear/arcanistExp"] = function(row: PathTarget, L: number): number
		local n = row.n or 3
		return ratio(SkillModel.clearTime(rowBuild(row), L, n), SkillModel.clearTime(SkillModel.arcanistExp(), L, n))
	end,
	tsk4 = function(row: PathTarget, L: number): number
		return SkillModel.metrics(rowBuild(row), L).tsk4
	end,
	r1 = function(row: PathTarget, L: number): number
		return SkillModel.metrics(rowBuild(row), L).r1
	end,
	tsk3 = function(row: PathTarget, L: number): number
		return SkillModel.metrics(rowBuild(row), L).tsk3
	end,
	elites = function(row: PathTarget, L: number): number
		local elite, elite2 = SkillModel.eliteKinds(L)
		if not elite or not elite2 then
			return 0
		end
		local build = rowBuild(row)
		local a = SkillModel.duel(build, L, elite, "elite")
		local b = SkillModel.duel(build, L, elite2, "elite2")
		return if a.won and not b.won then 1 else 0
	end,
	tsk6 = function(row: PathTarget, L: number): number
		return SkillModel.healerVsBoss(rowBuild(row), SkillModel.BOSS_AT[L], { team = "s92" }).tsk6
	end,
	-- S89 (F2): healer.S = 1 target 60 s / "Inkwizytor solo" (the best combat path of the class, ROZWOJ 9.6)
	["single60/inquisitor"] = function(row: PathTarget, L: number): number
		return ratio(
			SkillModel.metrics(rowBuild(row), L).single60,
			SkillModel.metrics(byKey("inquisitor.solo"), L).single60
		)
	end,
	-- S89 (E1): the gain of one breakpoint option (SkillModel.optionGain); 0 without a value in the role (S86)
	r4 = function(row: PathTarget, L: number): number
		local v = SkillModel.optionGain(rowBuild(row), row.skill :: string, row.at :: number, row.choice :: string, L)
		return v or 0
	end,
	r4diff = function(row: PathTarget, L: number): number
		local build = rowBuild(row)
		local a = SkillModel.optionGain(build, row.skill :: string, row.at :: number, "a", L)
		local b = SkillModel.optionGain(build, row.skill :: string, row.at :: number, "b", L)
		return math.abs((a or 0) - (b or 0))
	end,
	r5 = function(row: PathTarget, L: number): number
		return SkillModel.r5Spread(rowBuild(row), L)
	end,
	-- S90 (G2): |role gain x base of the row's path / the mean of the class's pair - 1|
	r5a = function(row: PathTarget, L: number): number
		local build = rowBuild(row)
		local own = SkillModel.r5aGain(build, L)
		local other = SkillModel.r5aGain(byKey(SkillModel.R5A_PAIRS[build.key]), L)
		return math.abs(own / math.max(1e-12, (own + other) / 2) - 1)
	end,
	-- S90 (C4): a Hunter cap: the value before Data/Stats' cap minus the cap (SkillModel.dexCaps)
	dexCap = function(row: PathTarget, L: number): number
		local c = SkillModel.dexCaps(rowBuild(row), L)
		local cap = row.cap
		return if cap == "crit"
			then c.critSighted - c.critCap
			elseif cap == "speed" then c.speed - c.speedCap
			else c.dodge - c.dodgeCap
	end,
	r6min = function(row: PathTarget, _L: number): number
		return SkillModel.r6Parts(rowBuild(row)).low
	end,
	r6max = function(row: PathTarget, _L: number): number
		return SkillModel.r6Parts(rowBuild(row)).high
	end,
} :: { [string]: (PathTarget, number) -> number }

export type TargetResult = {
	id: string,
	classId: string,
	path: string,
	L: number,
	build: string, -- the row's build key (with "@weapon" for a variant)
	weapon: string,
	value: number,
	low: number?,
	high: number?,
	pass: boolean,
	asserted: boolean, -- a level of the row above 20 (S89 / S90; asserted by balance.spec, S94 without a switch)
	report: string?, -- S89: who asserts it instead (the row's `report`, or "F4" at a `reportAt` level)
	source: string,
	note: string?,
	project: number?,
	metric: string,
}

local targetCache: { [string]: TargetResult } = {}

-- The band of a row at L (a per-level band, else low / high; at 20 the band of the row's first level).
function SkillModel.bandOf(row: PathTarget, L: number): (number?, number?)
	if row.metric == "tsk3" then
		local build = rowBuild(row)
		return nil, build.areaCap
	end
	if row.bands then
		local band = row.bands[L] or row.bands[row.levels[1]]
		if band then
			return band[1], band[2]
		end
	end
	local own = if row.metric == "r1" then SkillModel.R1_L20[rowBuild(row).key] or SkillModel.R1_L20[row.build] else nil
	if row.metric == "r1" and own then
		-- S89 (F2): max(2.0, 1.15 x the build's own R1 at L20)
		return row.low, math.max(row.high or 2.0, 1.15 * own)
	end
	return row.low, row.high
end

-- S86 (E2): every row of PATH_TARGETS (of `classId`, or all) at its levels and at 20, without the heavy R4-R6 rows
-- (opts.heavy keeps them out anyway: they have their own report tables). Read by the paths block of balance.spec and
-- by the report, so both show the same pass / fail.
-- S137: the row a PATH_TARGETS result is named by in Balance.GLOBAL_REPORT_ONLY: id "path.<build>.L<level>.<row id>",
-- label = the row's note ("" without one).
function SkillModel.reportRow(id: string, buildKey: string, L: number, note: string?): any
	return { id = `path.{buildKey}.L{L}.{id}`, label = note or "" }
end

function SkillModel.evaluateTargets(classId: string?): { TargetResult }
	local out: { TargetResult } = {}
	for _, row in SkillModel.PATH_TARGETS do
		if row.heavy or (classId and row.classId ~= classId) then
			continue
		end
		local fn = SkillModel.TARGET_METRICS[row.metric]
		assert(fn, `SkillModel: unknown target metric {row.metric}`)
		local levels = table.clone(row.levels)
		if not row.noL20 and not table.find(levels, 20) then
			table.insert(levels, 1, 20)
		end
		local build = rowBuild(row)
		for _, L in levels do
			-- S90: an R4 row only where the build has the skill at that rank (a path skill bought later has none yet)
			if
				row.skill
				and row.at
				and Paths.skillRank(SkillModel.character(build, L).character, row.skill) < (row.at :: number)
			then
				continue
			end
			local option = `{row.skill or ""}{row.at or ""}{row.choice or ""}`
			local key = `{row.id}|{row.classId}|{build.key}|{row.metric}|{row.n or ""}|{option}|{row.cap or ""}|{L}`
			local cached = targetCache[key]
			if not cached then
				local value = fn(row, L)
				-- S90: an option without a value in its role at this level (the skill does no damage yet, e.g. Frost
				-- Trap before Blast Trap) is only printed
				local noMetric = row.metric == "r4"
					and SkillModel.optionGain(build, row.skill :: string, row.at :: number, row.choice :: string, L)
						== nil
				local low, high = SkillModel.bandOf(row, L)
				cached = {
					id = row.id,
					classId = row.classId,
					path = row.path,
					L = L,
					build = build.key,
					weapon = weaponKey(build.weapon),
					value = value,
					low = low,
					high = high,
					pass = value == value
						and (low == nil or value >= low - 1e-9)
						and (high == nil or value <= high + 1e-9),
					-- S89 (F1, F4): a row with `report`, or a `reportAt` level, is only printed; S137: also a row named
					-- in Balance.GLOBAL_REPORT_ONLY (SkillModel.reportRow)
					asserted = L > 20
						and table.find(row.levels, L) ~= nil
						and row.report == nil
						and not (row.reportAt and table.find(row.reportAt, L))
						and not noMetric
						and B.reportOnlyFor(SkillModel.reportRow(row.id, build.key, L, row.note)) == nil,
					report = row.report
						or (if row.reportAt and table.find(row.reportAt, L) then "F4" else nil)
						or (if noMetric then "bez metryki na tym poziomie" else nil)
						or (B.reportOnlyFor(SkillModel.reportRow(row.id, build.key, L, row.note)) or {} :: any).session,
					source = row.source,
					note = row.note,
					project = if row.project then row.project[L] else nil,
					metric = row.metric,
				}
				targetCache[key] = cached
			end
			table.insert(out, cached)
		end
	end
	return out
end

-- S90 report helpers (I1) -----------------------------------------------------------------------------------------

export type ManaRow = {
	demand: number, -- mana per s with every damaging spell on cooldown (T-SK4 numerator)
	regen: number,
	returns: number, -- passive returns per s (Reclaim, Cascade)
	ratio: number, -- T-SK4
	evocation: number, -- mana per s of an Evocation on every cooldown (0 without the skill)
	ratioEvocation: number, -- demand / (regen + returns + evocation)
}

-- S90 (F4, I1, ROZWOJ 12.7): the mana table of a Mage build at L (mean of the elements, as metrics); Evocation on every
-- cooldown counted apart: its mana % x the pool / its cooldown (Paths.effectiveFor with the build's nodes).
function SkillModel.manaRow(build: Build, L: number): ManaRow
	local m = SkillModel.metrics(build, L)
	local sp = SkillModel.player(build, L)
	local evo = 0
	local rank = Paths.skillRank(sp.character, "evocation")
	if rank > 0 then
		local def = Paths.effectiveFor(sp.character, "evocation", sp.weapons, rank)
		evo = Skills.valueAt(def, "mana", rank) / 100 * m.pool / math.max(1, Skills.cooldown(def, rank))
	end
	local income = m.regen + m.returns
	return {
		demand = m.demand,
		regen = m.regen,
		returns = m.returns,
		ratio = m.tsk4,
		evocation = evo,
		ratioEvocation = m.demand / math.max(1e-9, income + evo),
	}
end

-- S90 (I1, ROZWOJ 12.7): the build without one skill in its rotation (key "<key>-<skillId>"), e.g. the Arcanist
-- without the Arcane Torrent (12.7: x1.03 on 70, x1.08 on 100).
function SkillModel.withoutSkill(build: Build, skillId: string): Build
	local key = `{build.key}-{skillId}`
	local cached = variantCache[`{build.classId}|{key}`]
	if cached then
		return cached
	end
	local copy: any = table.clone(build)
	copy.key = key
	local rotation = {}
	for _, entry in build.rotation do
		if entry.skill ~= skillId then
			table.insert(rotation, entry)
		end
	end
	copy.rotation = rotation
	variantCache[`{build.classId}|{key}`] = copy
	return copy
end

-- S90 (I1, ROZWOJ 12.7): seconds per monster of a grind with rest (SkillModel.grind, rest variant: 20 fights with the
-- region's groups that hit back, the rest at ASSUMPTIONS.restPct between them).
function SkillModel.restPerMonster(build: Build, L: number): number
	local monsters = 0
	for _, n in grindSizes(A.grindFights) do
		monsters += n
	end
	return SkillModel.grind(build, L, true).seconds / math.max(1, monsters)
end

-- Guards (F1) -------------------------------------------------------------------------------------------------------

export type Guards = { tsk1rel: number, tsk2rel: number, tsk3cap: number }
SkillModel.GUARD_LIMITS = { tsk1rel = 1.15, tsk2rel = 1.25, tsk3cap = 1.0 } -- balance plan D1
SkillModel.GUARD_LEVELS = { 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }
-- The L20 references of the plan (D1, before the rebuild): T-SK1 / T-SK2 / T-SK3 of W / Ł / M / K.
SkillModel.GUARD_D1 = {
	tsk1 = { Warrior = 1.90, Hunter = 2.12, Mage = 2.37, Cleric = 1.83 },
	tsk2 = { Warrior = 2.31, Hunter = 2.58, Mage = 2.62, Cleric = 1.96 },
	tsk3 = { Warrior = 1.54, Hunter = 1.29, Mage = 1.21, Cleric = 1.48 },
}

-- S86 (F1, balance plan D1): T-SK1(L) / T-SK1(own L20), T-SK2(L) / T-SK2(own L20) (the S85 fields tsk1rel, tsk2rel)
-- and T-SK3(L) / areaCap; limits <= 1.15, <= 1.25, <= 1.0 (asserted by S92-S94 after the S91 anchor).
function SkillModel.guards(build: Build, L: number): Guards
	local m = SkillModel.metrics(build, L)
	return { tsk1rel = m.tsk1rel, tsk2rel = m.tsk2rel, tsk3cap = m.tsk3 / build.areaCap }
end

-- Measured situations (C3) ----------------------------------------------------------------------------------------

export type Situations = {
	basicShare: number,
	basicShareGroup: number,
	skillInterval: number,
	elementShare: number,
	iceUptime: number,
	areaShare: number,
	controlled: number,
	controlledBoss: number,
	still: number,
	stillBoss: number,
	mana: number?,
	dungeon: number?, -- heal per second on the tank (the T-SK6 numerator, S85 definition)
}

-- S86 (C3): the situations of the trait model measured on `build` at L (the S84 assumptions in Balance.SITUATIONS);
-- the Mage's ice uptime from the ice element's control share.
function SkillModel.situations(build: Build, L: number): Situations
	local m = SkillModel.metrics(build, L)
	local ice = if m.byElement and m.byElement.ice then m.byElement.ice.controlled else m.controlled
	local out: Situations = {
		basicShare = m.basicShare,
		basicShareGroup = m.basicShareGroup,
		skillInterval = m.skillInterval,
		elementShare = m.elementShare,
		iceUptime = ice,
		areaShare = m.areaShare,
		controlled = m.controlled,
		controlledBoss = m.controlledBoss,
		still = m.still,
		stillBoss = m.stillBoss,
		mana = if build.classId == "Mage" then m.mana else nil,
		dungeon = nil,
	}
	if build.classId == "Cleric" and (build.pathId == "healer" or build.pathId == "fortune") then
		out.dungeon = SkillModel.healerVsBoss(build, SkillModel.BOSS_AT[L] or "vaelgrath").hps
	end
	return out
end

-- The measured table of traitTerms for an S84 situation name (A5: Balance.traitTerms' fourth argument).
function SkillModel.measuredFor(build: Build, L: number, situation: string): B.Measured
	local s = SkillModel.situations(build, L)
	local group = situation == "group"
	local boss = situation == "boss"
	return {
		basicShare = if group then s.basicShareGroup else s.basicShare,
		skillInterval = s.skillInterval,
		elementShare = s.elementShare,
		iceUptime = s.iceUptime,
		controlled = if boss then s.controlledBoss else s.controlled,
		still = if boss then s.stillBoss else s.still,
		areaShare = if group then s.areaShare else 0,
	}
end

-- Item traits in the skill model (C) ------------------------------------------------------------------------------

-- The measure of a trait situation on the skill model (STATY 14): DPS situations a fight's damage per second, `tank`
-- max HP / net damage taken per s from 3 monsters that hit back, `solo` HP lost per kill (a duel; lower is better),
-- `dungeon` heal per s on the tank in heal mode, `mana` the 180 s boss window with the pool as the limit.
local function situationValue(sp: any, L: number, situation: string): number
	if situation == "group" then
		local three = {}
		for _ = 1, A.areaTargets do
			table.insert(three, B.monster(B.GENERIC, L))
		end
		return SkillModel.fight(sp, { targets = three }).dps
	elseif situation == "boss" or situation == "mana" then
		return SkillModel.fight(sp, { seconds = A.bossSeconds, targets = { B.monster(B.GENERIC, L, "boss") } }).dps
	elseif situation == "elite" then
		return SkillModel.fight(sp, { targets = { B.monster(B.GENERIC, L, "elite") } }).dps
	elseif situation == "armored" then
		local defence = (require("../src/shared/Data/Families") :: any).defence("undead", "armored")
		local kind = table.clone(B.GENERIC) :: any
		kind.defMul = defence.defMul or 1
		return SkillModel.fight(sp, { targets = { B.monster(kind, L) } }).dps
	elseif situation == "tank" then
		local three = {}
		for _ = 1, A.areaTargets do
			table.insert(three, B.monster(B.GENERIC, L))
		end
		local r = SkillModel.fight(sp, { targets = three, retaliate = true })
		return sp.p.values.maxHp / math.max(1e-9, (r.taken - r.healEff) / math.max(A.dt, r.seconds))
	elseif situation == "solo" then
		local r = SkillModel.fight(sp, {
			targets = { B.monster(B.GENERIC, L) },
			dummy = false,
			retaliate = true,
			seconds = A.retaliateSeconds,
		})
		return math.max(1e-9, (r.taken - r.healEff) / sp.p.values.maxHp)
	elseif situation == "dungeon" then
		local tank = SkillModel.defenderTank(L)
		local r = SkillModel.fight(sp, {
			targets = { B.monster(B.GENERIC, L, "boss") },
			seconds = A.bossSeconds,
			heal = { tank = tank, team = 5 },
		})
		return (r.healTo.tank or 0) / A.bossSeconds
	end
	-- single, controlled, still
	return SkillModel.fight(sp, {}).dps
end

-- S86 (C2, S84 / S88 definition): the value of trait `traitId` on the skill model: M(with) / M(without) - 1 with
-- traitScale[traitId] = 0 (the other trait of the set stays); `solo`: loss without / loss with - 1. A Mage set without
-- an element: the mean of the three weapon elements (as S84).
function SkillModel.traitValue(build: Build, L: number, traitId: string, situation: string, gear: B.GearOpts?): number
	local elements: { any } = if build.classId == "Mage" and not (gear and gear.element) then A.elements else { false }
	local a, b = 0, 0
	for _, el in elements do
		local element = if el then el else (if gear and gear.element then gear.element else nil)
		local with = SkillModel.player(build, L, { gear = gear or {}, element = element })
		local without = SkillModel.player(build, L, { gear = B.withoutTrait(gear, traitId), element = element })
		a += situationValue(with, L, situation) / #elements
		b += situationValue(without, L, situation) / #elements
	end
	if situation == "solo" then
		return b / math.max(1e-12, a) - 1
	end
	return a / math.max(1e-12, b) - 1
end

-- S84 Balance.situationMeasure with the measured situations (traitTerms' fourth argument).
local function measuredMeasure(p: any, situation: string, measured: B.Measured): number
	local ctx = B.situationCtx(p, situation)
	if ctx.measure == "ehp" then
		local sum = 0
		local rates = ctx.rates :: { { attacks: number, targetShare: number } }
		for _, r in rates do
			local c = table.clone(ctx)
			c.attacks, c.targetShare = r.attacks, r.targetShare
			local t = B.traitTerms(p, ctx.m, c, measured)
			local taken = c.attacks * ctx.hit * t.takenMul
			sum += p.values.maxHp / math.max(1e-9, taken - math.min(t.sustain, 0.8 * taken))
		end
		return sum / #rates
	elseif ctx.measure == "loss" then
		local t = B.traitTerms(p, ctx.m, ctx, measured)
		local seconds = ctx.m.maxHp / math.max(1e-9, t.dps)
		local incoming = ctx.hit * t.takenMul * (1 + seconds / ctx.m.attackInterval)
		local perSecond = t.sustain - t.killHealHp * ctx.kills
		local heal = (perSecond + (p.values.hpRegenCombat or 0)) * seconds + t.killHealHp
		return (incoming - math.min(heal, 0.8 * incoming)) / p.values.maxHp
	end
	local t = B.traitTerms(p, ctx.m, ctx, measured)
	local taken = ctx.hit * t.takenMul
	local net = taken - math.min(t.sustain / math.max(1e-9, ctx.attacks), 0.8 * taken)
	return t.dps * p.values.maxHp / math.max(1e-9, net)
end

-- S86 (C3, C5): Balance.traitValue with the situation measured on `build` (traitTerms' fourth argument).
function SkillModel.traitValueMeasured(
	build: Build,
	L: number,
	traitId: string,
	situation: string,
	gear: B.GearOpts?
): number
	local measured = SkillModel.measuredFor(build, L, situation)
	local classId = build.classId
	local with = B.itemPlayer(classId, L, gear)
	local without = B.itemPlayer(classId, L, B.withoutTrait(gear, traitId))
	local a = measuredMeasure(with, situation, measured)
	local b = measuredMeasure(without, situation, measured)
	if B.situationCtx(with, situation).measure == "loss" then
		return b / math.max(1e-12, a) - 1
	end
	return a / math.max(1e-12, b) - 1
end

-- The path build of a trait's set (STATY 3, first path: a path whose weapon list holds the set's weapon; the relic on
-- the Priest of Fortune), on the set's weapon and off-hand.
function SkillModel.traitBuild(traitId: string): Build
	local spec = B.TRAIT_SETS[traitId]
	local classId, weapon, offhand = spec[1], spec[2], if spec[3] then spec[3] else nil
	if traitId == "prosperity" then
		return SkillModel.withWeapon(byKey("fortune.plunder"), weapon, offhand)
	end
	for _, path in Paths.pathsOf(classId) do
		local main = path.weapon and path.weapon.main
		if main and table.find(main, weapon) and #path.reference > 0 then
			return SkillModel.withWeapon(byKey(`{path.id}.{path.reference[1].id}`), weapon, offhand)
		end
	end
	local base = SkillModel.builds(classId)[1]
	return SkillModel.withWeapon(base, weapon, offhand)
end

-- S86 (C1, the table of docs/sessions/S86.md): traits whose value comes from the blows taken (counters, block, weaken,
-- attack slow, stun, kill heal) go through Balance.traitTerms with the measured situation; the rest on the event.
SkillModel.TRAIT_VIA_TERMS = {
	swordplay = true,
	parry = true,
	bonebreaker = true,
	harrying = true,
	concussion = true,
	reaping = true,
} :: { [string]: boolean }

export type TraitModelRow = {
	traitId: string,
	build: string,
	situation: string,
	s84: number, -- Balance.traitValue (S84 convention)
	measured: number, -- traitTerms with the situation measured on the build
	model: number, -- the skill model, on the event
	staty: number, -- STATY 14 starting estimate
}

local traitRowCache: { [string]: TraitModelRow } = {}

-- S86 (C6): one trait at L with rarity / upgrade: the first STATY 14 situation of its row (Balance.TRAIT_SETS),
-- prosperity none (0 in a fight).
function SkillModel.traitRow(traitId: string, L: number, rarity: number, up: number): TraitModelRow
	local key = `{traitId}|{L}|{rarity}|{up}`
	if traitRowCache[key] then
		return traitRowCache[key]
	end
	local ItemWeights = require("../src/shared/Data/ItemWeights") :: any
	local spec = B.TRAIT_SETS[traitId]
	local situation = spec[4][1] or "single"
	local classId, gear = B.traitGear(traitId, rarity, up)
	local build = SkillModel.traitBuild(traitId)
	local weight = ItemWeights.traits[traitId]
	local row: TraitModelRow
	if #spec[4] == 0 then
		row = { traitId = traitId, build = build.key, situation = "-", s84 = 0, measured = 0, model = 0, staty = 0 }
	else
		local measured = SkillModel.traitValueMeasured(build, L, traitId, situation, gear)
		row = {
			traitId = traitId,
			build = build.key,
			situation = situation,
			s84 = B.traitValue(classId, L, gear, traitId, situation),
			measured = measured,
			model = if SkillModel.TRAIT_VIA_TERMS[traitId]
				then measured
				else SkillModel.traitValue(build, L, traitId, situation, gear),
			staty = if weight then weight.pct / 100 else 0 / 0,
		}
	end
	traitRowCache[key] = row
	return row
end

-- R4 / R5 / R6 (D7) -------------------------------------------------------------------------------------------------

-- The role of a skill for R4: area types on 3 dummies, other damaging skills on 1, heals on the tank.
local function roleOf(def: any): string?
	if def.values and def.values.dmg ~= nil then
		return if Traits.isAreaSkill(def.type) then "area" else "single"
	end
	if
		def.type == "heal"
		or def.type == "hot"
		or def.type == "groupHeal"
		or def.type == "healZone"
		or def.type == "shield"
	then
		return "heal"
	end
	return nil
end

-- The role value of one skill (R4): 60 s on cooldown without a resource limit, the skill alone in the rotation;
-- damage of the skill and its ticks, or heal on the tank in heal mode.
local function skillRoleValue(
	sp: any,
	L: number,
	skillId: string,
	def: any,
	bp: any,
	role: string,
	seconds: number?,
	rotation: { { [string]: any } }?
): number
	local targets = {}
	for _ = 1, if role == "area" then A.areaTargets else 1 do
		table.insert(targets, B.monster(B.GENERIC, L))
	end
	local r = SkillModel.fight(sp, {
		targets = targets,
		unlimited = true,
		rotation = rotation or { { skill = skillId } },
		override = { [skillId] = { def = def, bp = bp } },
		heal = if role == "heal" then { tank = SkillModel.defenderTank(L), team = 5 } else nil,
		seconds = seconds,
	})
	if role == "heal" then
		return r.healTo.tank or 0
	end
	return r.by[skillId] or 0
end

-- S86 (D7): R4 = the role value of `skillId` with option `choice` at breakpoint rank `at` / without that breakpoint
-- (Skills.effective of the skill without breakpoints[at]; the other breakpoint as in the build) - 1. nil when the
-- build's rank is below `at`, the skill has no role value or the option does not exist.
function SkillModel.optionGain(build: Build, skillId: string, at: number, choice: string, L: number): number?
	local base = SkillData.get(skillId) :: any
	-- S90: the Mage on the skill's own element (lightning and ice spells need that weapon; adaptive ones fire)
	local element = if build.classId == "Mage"
		then (if base and base.element and table.find(A.elements, base.element) then base.element else "fire")
		else nil
	local sp = SkillModel.player(build, L, if element then { element = element } else nil)
	local rank = Paths.skillRank(sp.character, skillId)
	if rank < at or not base or not base.breakpoints or not base.breakpoints[at] then
		return nil
	end
	local option = base.breakpoints[at][choice]
	if option == nil then
		return nil
	end
	local choices = table.clone(sp.character.path.bp or {})
	choices[Skills.choiceKey(skillId, at)] = choice
	local mods = Paths.skillMods(sp.character, skillId, sp.weapons)
	local withDef, withBp = Skills.effective(base, rank, choices, mods)
	local role = roleOf(withDef)
	if not role then
		return nil
	end
	-- S90 (G1, DECYZJE): an option that adds targets (splash, split, pierce, add.jumps) to a one-target skill counts on
	-- 3 dummies; an area skill always on 3; a one-target option on 1
	if
		role == "single"
		and (option.splash ~= nil or option.split ~= nil or option.pierce ~= nil or (option.add and option.add.jumps))
	then
		role = "area"
	end
	local stripped = table.clone(base)
	stripped.breakpoints = table.clone(base.breakpoints)
	stripped.breakpoints[at] = nil
	local withoutDef, withoutBp = Skills.effective(stripped, rank, choices, mods)
	-- S90 (G1, DECYZJE): a cooldown option over at least R4_CASTS cooldowns of the skill (60 s gave 2-3 casts of a
	-- 20-40 s cooldown, so `mul.cooldown` counted 0 or +50 %); every other option on the S86 60 s
	local seconds: number? = nil
	if option.mul and option.mul.cooldown then
		local cooldown = Skills.scaled(withoutDef, withoutDef.cooldown, rank)
		seconds = math.max(A.sustainedSeconds, SkillModel.R4_CASTS * cooldown)
	end
	-- S90: a skill whose value comes from the other spells (Arcane Discharge spends the Charges they give) in the
	-- build's whole rotation, counting only its own damage
	local rotation = if SkillModel.R4_ROTATION[skillId] then build.rotation else nil
	local a = skillRoleValue(sp, L, skillId, withDef, withBp, role, seconds, rotation)
	local b = skillRoleValue(sp, L, skillId, withoutDef, withoutBp, role, seconds, rotation)
	if b <= 0 then
		return nil
	end
	return a / b - 1
end

export type R4Row = {
	build: string,
	skill: string,
	at: number,
	choice: string,
	L: number,
	value: number,
	chosen: boolean,
}

-- S86 (D7): R4 of every rotation skill with breakpoints of the damage and heal builds "do celów", both options, at
-- the first of 45 / 70 / 100 where the rank reaches the breakpoint (DECYZJE S86: the cost cap of G3).
SkillModel.R4_BUILDS = {
	"berserker.fury",
	"inquisitor.solo",
	"healer.dungeon",
	"marksman.kingslayer",
	"trapper.poacher",
	"destroyer.destroyerExp",
	"arcanist.arcanistBoss",
}
function SkillModel.r4Rows(): { R4Row }
	local out: { R4Row } = {}
	for _, key in SkillModel.R4_BUILDS do
		local build = byKey(key)
		local seen: { [string]: boolean } = {}
		for _, entry in build.rotation do
			local id = entry.skill
			if seen[id] then
				continue
			end
			seen[id] = true
			local base = SkillData.get(id) :: any
			if not base or not base.breakpoints then
				continue
			end
			for _, at in Skills.BREAKPOINT_LEVELS do
				for _, L in { 45, 70, 100 } do
					local sp = SkillModel.player(build, L)
					if Paths.skillRank(sp.character, id) >= at then
						for _, choice in { "a", "b" } do
							local value = SkillModel.optionGain(build, id, at, choice, L)
							if value then
								local bp = build.bp[Skills.choiceKey(id, at)] or "a"
								table.insert(out, {
									build = key,
									skill = id,
									at = at,
									choice = choice,
									L = L,
									value = value,
									chosen = bp == choice,
								})
							end
						end
						break
					end
				end
			end
		end
	end
	return out
end

export type R5Row = { kind: string, build: string, weapon: string, L: number, value: number }

-- S86 (D7): R5 (a) each combat path of a class with two (Hunter: Marksman 1 target 60 s, Trapper area 8 s; Mage:
-- Destroyer area 60 s, Arcanist boss 180 s) in its own metric / the mean of the pair in that metric - 1; (b) every
-- weapon of a combat path's weapon list in the path's metric / the mean over its weapons - 1.
function SkillModel.r5Rows(): { R5Row }
	local out: { R5Row } = {}
	local pairs = {
		{ { "marksman.kingslayer", "single60" }, { "trapper.poacher", "aoe3burst" } },
		{ { "destroyer.destroyerExp", "aoe3sus" }, { "arcanist.arcanistBoss", "boss180" } },
	}
	for _, L in L45 do
		for _, pair in pairs do
			for i, entry in pair do
				local field = entry[2]
				local own = (SkillModel.metrics(byKey(entry[1]), L) :: any)[field]
				local other = (SkillModel.metrics(byKey(pair[3 - i][1]), L) :: any)[field]
				table.insert(out, {
					kind = `a {field}`,
					build = entry[1],
					weapon = weaponKey(byKey(entry[1]).weapon),
					L = L,
					value = own / math.max(1e-12, (own + other) / 2) - 1,
				})
			end
		end
		for _, entry in
			{
				{ "berserker.fury", "single60" },
				{ "inquisitor.solo", "single60" },
				{ "marksman.kingslayer", "single60" },
				{ "trapper.poacher", "aoe3burst" },
				{ "destroyer.destroyerExp", "aoe3sus" },
				{ "arcanist.arcanistBoss", "boss180" },
			}
		do
			local build = byKey(entry[1])
			local path = PathData.get(build.pathId :: string) :: any
			local values = {}
			local sum = 0
			for _, weapon in path.weapon.main do
				local offhand = build.weapon.offhand
				if offhand and path.weapon.offhand and not table.find(path.weapon.offhand, offhand) then
					offhand = nil
				end
				if Paths.isTwoHanded(weapon) then
					offhand = nil
				end
				local b = SkillModel.withWeapon(build, weapon, offhand)
				local v = (SkillModel.metrics(b, L) :: any)[entry[2]]
				table.insert(values, { weaponKey(b.weapon), v })
				sum += v
			end
			for _, wv in values do
				table.insert(out, {
					kind = `b {entry[2]}`,
					build = entry[1],
					weapon = wv[1],
					L = L,
					value = wv[2] / math.max(1e-12, sum / #values) - 1,
				})
			end
		end
	end
	return out
end

export type R6Row = { build: string, node: string, ranks: number, perPoint: number, value: number }

-- S86 (D7, P2): R6 at 100 for the damage builds: the gain of the path metric from one passive / modify node of rows
-- 4-11 of the main path (the build without its ranks) per point, against the mean of the build's nodes. Skill nodes
-- and rows 1-3 are left out (DECYZJE S86).
SkillModel.R6_BUILDS = {
	{ "berserker.fury", "single60" },
	{ "inquisitor.solo", "single60" },
	{ "marksman.kingslayer", "single60" },
	{ "trapper.poacher", "aoe3burst" },
	{ "destroyer.destroyerExp", "aoe3sus" },
	{ "arcanist.arcanistBoss", "boss180" },
}
function SkillModel.r6Rows(): { R6Row }
	local out: { R6Row } = {}
	local L = 100
	for _, entry in SkillModel.R6_BUILDS do
		local build = byKey(entry[1])
		local field = entry[2]
		local full = (SkillModel.metrics(build, L) :: any)[field]
		local rows: { R6Row } = {}
		local sum = 0
		for i, node in build.nodes do
			local nodeId = node[1]
			local def, path, row = Paths.findNode(nodeId)
			if def and path and path.id == build.pathId and (row or 0) >= 4 and def.kind ~= "skill" then
				local nodes = table.clone(build.nodes)
				table.remove(nodes, i)
				local copy: any = table.clone(build)
				copy.key = `{build.key}-{nodeId}`
				copy.nodes = nodes
				local without = (SkillModel.metrics(copy, L) :: any)[field]
				local perPoint = (full / math.max(1e-12, without) - 1) / node[2]
				sum += perPoint
				table.insert(rows, { build = entry[1], node = nodeId, ranks = node[2], perPoint = perPoint, value = 0 })
			end
		end
		local mean = sum / math.max(1, #rows)
		for _, r in rows do
			r.value = r.perPoint / math.max(1e-12, mean)
			table.insert(out, r)
		end
	end
	return out
end

-- S90 (G2, ROZWOJ 11.6, 12.7): the metric of a combat path (R5a, R5b, R6): the Marksman 1 target 60 s, the Trapper
-- area 3 targets 8 s, the Destroyer area 3 targets 60 s, the Arcanist the boss 180 s; the rest 1 target 60 s.
SkillModel.PATH_METRIC = {
	marksman = "single60",
	trapper = "aoe3burst",
	destroyer = "aoe3sus",
	arcanist = "boss180",
} :: { [string]: string }

-- The build with `weapon` of its path's list: a two-handed one alone, else the build's off-hand when the path allows it,
-- else the path's first off-hand (the Mage's wand: orb or tome, S90).
local function pathWeapon(build: Build, weapon: string): Build
	local path = PathData.get(build.pathId :: string) :: any
	local offhand: string? = nil
	if not Paths.isTwoHanded(weapon) then
		local allowed = path.weapon.offhand
		offhand = build.weapon.offhand
		if allowed and not (offhand and table.find(allowed, offhand)) then
			offhand = allowed[1]
		end
	end
	return SkillModel.withWeapon(build, weapon, offhand)
end
SkillModel.pathWeapon = pathWeapon

-- S89 (E2, DECYZJE): R5 of a class with one combat path: every weapon of the path's weapon list (the build's off-hand
-- kept unless two-handed) in 1 target 60 s; the largest |weapon / mean of the weapons - 1|. S90 (G2): in the path's
-- metric (PATH_METRIC), the Mage's wand with the path's off-hand.
function SkillModel.r5Spread(build: Build, L: number): number
	local path = PathData.get(build.pathId :: string) :: any
	local field = SkillModel.PATH_METRIC[build.pathId :: string] or "single60"
	local values: { number } = {}
	local sum = 0
	for _, weapon in path.weapon.main do
		local v = (SkillModel.metrics(pathWeapon(build, weapon), L) :: any)[field]
		table.insert(values, v)
		sum += v
	end
	local mean = sum / math.max(1, #values)
	local worst = 0
	for _, v in values do
		worst = math.max(worst, math.abs(v / math.max(1e-12, mean) - 1))
	end
	return worst
end

-- S90 (G2, DECYZJE): the role gain x base of a combat path: the path's metric (PATH_METRIC) / the same of the class base
-- (SkillModel.baseFor: the Hunter with the same weapon, the Mage with the staff), the mean over the path's weapons.
function SkillModel.r5aGain(build: Build, L: number): number
	local path = PathData.get(build.pathId :: string) :: any
	local field = SkillModel.PATH_METRIC[build.pathId :: string] or "single60"
	local sum = 0
	for _, weapon in path.weapon.main do
		local b = pathWeapon(build, weapon)
		sum += (SkillModel.metrics(b, L) :: any)[field] / math.max(
			1e-12,
			(SkillModel.metrics(SkillModel.baseFor(b), L) :: any)[field]
		)
	end
	return sum / math.max(1, #path.weapon.main)
end

-- S90 (G2): the other combat path of the class (R5a pairs).
SkillModel.R5A_PAIRS = {
	["marksman.kingslayer"] = "trapper.poacher",
	["trapper.poacher"] = "marksman.kingslayer",
	["destroyer.destroyerExp"] = "arcanist.arcanistBoss",
	["arcanist.arcanistBoss"] = "destroyer.destroyerExp",
} :: { [string]: string }

export type R6Part = { points: number, metric: number, ehp: number, gain: number, perPoint: number, ratio: number }
export type R6Parts = {
	points: number,
	mean: number, -- gain per point of rows 4-11
	parts: { R6Part },
	low: number, -- the weakest third's gain per point / mean
	high: number, -- the strongest third's
}
local r6Cache: { [string]: R6Parts } = {}

-- `build` with only the first `k` points of its main path's rows 4-11 (in the reference order; the boundary node
-- partly bought), every other node kept.
local function withRowPoints(build: Build, k: number): Build
	local nodes: { { any } } = {}
	local used = 0
	for _, entry in build.nodes do
		local _, path, row = Paths.findNode(entry[1])
		if path and path.id == build.pathId and (row or 0) >= 4 then
			local take = math.min(entry[2], k - used)
			if take > 0 then
				table.insert(nodes, { entry[1], take })
				used += take
			end
		else
			table.insert(nodes, entry)
		end
	end
	local copy: any = table.clone(build)
	copy.key = `{build.key}#r6:{k}`
	copy.nodes = nodes
	return copy
end

-- The R6 metric of a build at L (E3): 1 target 60 s on the boss model target (Giant Slayer's bossDamage counts; the
-- Berserker, the Inquisitor), 4 x (1 + B) + S (the Standard-Bearer), heal and shields per second on the tank over the
-- boss window (the Healer; the trait situation `dungeon`).
local function r6Metric(build: Build, L: number): number
	if build.pathId == "standard" then
		return SkillModel.standardSupport(build, L).value
	end
	-- S90 (G3): the Scout's 4 x (1 + B) + S, the Trapper, the Destroyer and the Arcanist in their PATH_METRIC
	if build.pathId == "scout" then
		return SkillModel.scoutSupport(build, L).value
	end
	local field = if build.pathId == "marksman" then nil else SkillModel.PATH_METRIC[build.pathId :: string]
	if field then
		return (SkillModel.metrics(build, L) :: any)[field]
	end
	local sp = SkillModel.player(build, L)
	local boss = { B.monster(B.GENERIC, L, "boss") }
	if build.pathId == "healer" then
		local r = SkillModel.fight(sp, {
			targets = boss,
			seconds = A.bossSeconds,
			heal = { tank = SkillModel.defenderTank(L), team = 5 },
		})
		return (r.healTo.tank or 0) / A.bossSeconds
	end
	return SkillModel.fight(sp, { targets = boss }).dps
end

-- S89 (E3, ROZWOJ 0, 2.3): the points of rows 4-11 of the main path in the reference order split into three equal
-- parts (the capstone counts with its part); at 100 each part's gain is the power sqrt((1 + dmetric) x (1 + dEHP)) - 1
-- of buying it after the parts before it, per point, against the mean gain per point of rows 4-11.
function SkillModel.r6Parts(build: Build): R6Parts
	local cached = r6Cache[build.key]
	if cached then
		return cached
	end
	local L = 100
	local total = 0
	for _, entry in build.nodes do
		local _, path, row = Paths.findNode(entry[1])
		if path and path.id == build.pathId and (row or 0) >= 4 then
			total += entry[2]
		end
	end
	local cuts = { 0, math.floor(total / 3 + 0.5), math.floor(2 * total / 3 + 0.5), total }
	local parts: { R6Part } = {}
	local prevMetric, prevEhp = 0, 0
	local sum = 0
	for i, k in cuts do
		local b = withRowPoints(build, k)
		local metric = r6Metric(b, L)
		local ehp = SkillModel.metrics(b, L).ehp
		if i > 1 then
			local points = k - cuts[i - 1]
			local gain = math.sqrt((metric / math.max(1e-12, prevMetric)) * (ehp / math.max(1e-12, prevEhp))) - 1
			sum += gain
			table.insert(parts, {
				points = points,
				metric = metric / math.max(1e-12, prevMetric) - 1,
				ehp = ehp / math.max(1e-12, prevEhp) - 1,
				gain = gain,
				perPoint = gain / math.max(1, points),
				ratio = 0,
			})
		end
		prevMetric, prevEhp = metric, ehp
	end
	local mean = sum / math.max(1, total)
	local low, high = math.huge, -math.huge
	for _, p in parts do
		p.ratio = p.perPoint / math.max(1e-12, mean)
		low = math.min(low, p.ratio)
		high = math.max(high, p.ratio)
	end
	local out: R6Parts = { points = total, mean = mean, parts = parts, low = low, high = high }
	r6Cache[build.key] = out
	return out
end

-- S86 (B8.4): the Trapper's traps in the model against the "instant circles" of ROZWOJ 11.6 (the same fight, every
-- trap fires at its placement): (area 8 s, 1 target 60 s) with real timing and instant.
function SkillModel.trapTiming(build: Build, L: number): (number, number, number, number)
	local sp = SkillModel.player(build, L)
	local three = {}
	for _ = 1, A.areaTargets do
		table.insert(three, B.monster(B.GENERIC, L))
	end
	local one = { B.monster(B.GENERIC, L) }
	local real8 = SkillModel.fight(sp, { seconds = A.burstSeconds, targets = three }).dps
	local inst8 = SkillModel.fight(sp, { seconds = A.burstSeconds, targets = three, instantTraps = true }).dps
	local real60 = SkillModel.fight(sp, { targets = one }).dps
	local inst60 = SkillModel.fight(sp, { targets = one, instantTraps = true }).dps
	return real8, inst8, real60, inst60
end

-- S88: trait bands and weapon sets (STATY 14) -----------------------------------------------------------------------

-- S88: `build` without the path nodes `off` (the nodes strengthening a trait, Balance.TRAIT_TARGETS nodesOff).
function SkillModel.withoutNodes(build: Build, off: { string }?): Build
	if not off or #off == 0 then
		return build
	end
	local key = `{build.key}~{table.concat(off, "~")}`
	local cached = variantCache[`{build.classId}|{key}`]
	if cached then
		return cached
	end
	local copy: any = table.clone(build)
	copy.key = key
	local nodes: { { any } } = {}
	for _, entry in build.nodes do
		if not table.find(off, entry[1]) then
			table.insert(nodes, entry)
		end
	end
	copy.nodes = nodes
	variantCache[`{build.classId}|{key}`] = copy
	return copy
end

-- S88: the value of a trait in one situation on `build` (the A0 choice: the skill model on the event; the six traits
-- of TRAIT_VIA_TERMS through Balance.traitTerms with the situation measured on the build).
function SkillModel.traitSituation(
	build: Build,
	L: number,
	traitId: string,
	situation: string,
	gear: B.GearOpts?
): number
	if SkillModel.TRAIT_VIA_TERMS[traitId] then
		return SkillModel.traitValueMeasured(build, L, traitId, situation, gear)
	end
	return SkillModel.traitValue(build, L, traitId, situation, gear)
end

export type TraitTargetResult = {
	row: B.TraitTarget,
	level: number,
	-- one entry per weapon element (Mage rows) or one entry: the mean over the band situations
	values: { { element: string?, value: number, by: { [string]: number }, nodes: number? } },
	report: { [string]: number }, -- report situations (mean over the elements)
	band: { number },
}

local traitTargetCache: { [string]: TraitTargetResult } = {}

-- S88 (C1-C2): one row of Balance.TRAIT_TARGETS at L with `rarity` / `up` (default Common +0): the value of the trait
-- in every band situation (equal weights, nodesOff off), with the nodes on (`nodes`), and the report situations.
function SkillModel.traitTarget(row: B.TraitTarget, L: number, rarity: number?, up: number?): TraitTargetResult
	local r, u = rarity or 1, up or 0
	local key = `{row.trait}|{row.build}|{row.weapon}|{row.offhand}|{L}|{r}|{u}`
	local cached = traitTargetCache[key]
	if cached then
		return cached
	end
	local full = SkillModel.withWeapon(byKey(row.build), row.weapon, row.offhand)
	local off = SkillModel.withoutNodes(full, row.nodesOff)
	local elements: { any } = if row.elements then A.elements else { false }
	local values = {}
	local report: { [string]: number } = {}
	for _, el in elements do
		local gear: B.GearOpts = {
			weapon = row.weapon,
			offhand = if row.offhand then row.offhand else false,
			rarity = r,
			up = u,
			element = if el then el else nil,
		}
		local by: { [string]: number } = {}
		local sum, withNodes = 0, 0
		for _, situation in row.situations do
			local v = SkillModel.traitSituation(off, L, row.trait, situation, gear)
			by[situation] = v
			sum += v
			if row.nodesOff then
				withNodes += SkillModel.traitSituation(full, L, row.trait, situation, gear)
			end
		end
		for _, situation in row.report or {} do
			report[situation] = (report[situation] or 0)
				+ SkillModel.traitSituation(off, L, row.trait, situation, gear) / #elements
		end
		table.insert(values, {
			element = if el then el else nil,
			value = sum / #row.situations,
			by = by,
			nodes = if row.nodesOff then withNodes / #row.situations else nil,
		})
	end
	local result: TraitTargetResult = {
		row = row,
		level = L,
		values = values,
		report = report,
		band = if row.twoHanded then B.TRAIT_BAND_2H else B.TRAIT_BAND,
	}
	traitTargetCache[key] = result
	return result
end

export type TypeSetResult = {
	entry: B.TypeSet,
	level: number,
	-- index in MIX against the first set (1 = the first set), and per MIX situation
	sets: { { label: string, index: number, by: { [string]: number } } },
	spread: number, -- max / min - 1
}

local typeSetCache: { [string]: TypeSetResult } = {}

-- The path measure of one weapon set in one MIX situation (C9): DPS of the fight on the event; `power` paths x the
-- power² ratio of the TRAIT_VIA_TERMS traits of the set (their EHP and counters), square root; `healer` the mean of
-- the dungeon heal per s and the one-target DPS (the model's Healer loses no HP in a duel, so its solo power is DPS).
local function setMeasure(entry: B.TypeSet, build: Build, L: number, situation: string, set: any): number
	local sp = SkillModel.player(build, L, if build.classId == "Mage" then { element = "fire" } else nil)
	if entry.measure == "healer" then
		return situationValue(sp, L, situation)
	end
	local dps = situationValue(sp, L, situation)
	if entry.measure ~= "power" then
		return dps
	end
	local gear: B.GearOpts = { weapon = set.main, offhand = if set.offhand then set.offhand else false }
	local mul = 1
	for _, id in { set.main, set.offhand } do
		local base = Bases.byType[id] :: any
		local traitId = base and base.trait
		if traitId and SkillModel.TRAIT_VIA_TERMS[traitId] then
			mul *= 1 + SkillModel.traitValueMeasured(build, L, traitId, situation, gear)
		end
	end
	return math.sqrt(dps * dps * mul)
end

-- S88 (C9, E6): the weapon sets of one Balance.TYPE_SETS path at L in Balance.MIX (healer: dungeon and single, equal
-- weights), each against the first set; spread = max / min - 1.
function SkillModel.typeSets(entry: B.TypeSet, L: number): TypeSetResult
	local key = `{entry.path}|{L}`
	local cached = typeSetCache[key]
	if cached then
		return cached
	end
	local mix: { [string]: number } = if entry.measure == "healer" then { dungeon = 0.5, single = 0.5 } else B.MIX
	local names: { string } = {}
	for name in mix do
		table.insert(names, name)
	end
	table.sort(names)
	local base = byKey(entry.build)
	local first: { [string]: number } = {}
	local sets = {}
	for i, set in entry.sets do
		local build = SkillModel.withWeapon(base, set.main, set.offhand)
		local by: { [string]: number } = {}
		local index, weights = 0, 0
		for _, name in names do
			local v = setMeasure(entry, build, L, name, set)
			if i == 1 then
				first[name] = v
			end
			by[name] = v / math.max(1e-12, first[name])
			index += mix[name] * by[name]
			weights += mix[name]
		end
		table.insert(sets, {
			label = `{set.main}{if set.offhand then " + " .. set.offhand else ""}`,
			index = index / weights,
			by = by,
		})
	end
	local lo, hi = math.huge, 0
	for _, s in sets do
		lo, hi = math.min(lo, s.index), math.max(hi, s.index)
	end
	local result: TypeSetResult = { entry = entry, level = L, sets = sets, spread = hi / math.max(1e-12, lo) - 1 }
	typeSetCache[key] = result
	return result
end

-- S88: class checks (E) -------------------------------------------------------------------------------------------

local function pathNode(pathId: string, nodeId: string): any
	local path = PathData.byId[pathId] :: any
	for _, row in path.rows do
		for _, node in row.nodes do
			if node.id == nodeId then
				return node
			end
		end
	end
	error(`SkillModel: no node {nodeId} in {pathId}`)
end

export type GuardLimits = {
	build: string,
	weapon: string,
	level: number,
	block: number, -- block from every source before blockCap (hook "block": Block, Shield Master, Parry, lines)
	riposte: number, -- counter chance before riposteCap (Counterattack, Retaliation, Swordplay)
	avoid: number, -- dodge + misfortune + block before Damage.avoidance cuts them (<= dodgeCap + avoidBonus)
	ehp: number, -- `tank` EHP with both traits of the set / without both - 1
	blockHealPerSecond: number, -- Parry's heal in % max HP per s (STATY 14: ~0.15 %/s)
}

-- E1 (STATY 3, 5, 10, 14): the Guardian's caps on a build ("Samotnik", "Obrońca") with `weapon` + shield at L.
function SkillModel.guardLimits(buildKey: string, weapon: string, L: number): GuardLimits
	local build = SkillModel.withWeapon(byKey(buildKey), weapon, "shield")
	local sp = SkillModel.player(build, L)
	local p = sp.p
	local hooks = p.hooks
	local miss = 0 -- misfortune works on the monsters' blows only through party auras (none in the build alone)
	-- the raw sum: Damage.avoidance clamps each part to the total, so its result could never exceed the cap
	local avoid = (math.max(0, p.values.dodge or 0) + miss + Traits.blockChance(hooks.block or 0, false)) / 100
	local measured = SkillModel.measuredFor(build, L, "tank")
	local baseTrait = (Bases.byType[weapon] :: any).trait
	local scale = table.clone(B.NO_TRAITS)
	for id in scale do
		scale[id] = if id == baseTrait or id == "parry" then 0 else 1
	end
	local off = SkillModel.player(build, L, { gear = { traitScale = scale } }).p
	local ehpWith = measuredMeasure(p, "tank", measured)
	local ehpWithout = measuredMeasure(off, "tank", measured)
	local _, _, block = Damage.avoidance(p.values.dodge or 0, 0, 0, Traits.blockChance(hooks.block or 0, false))
	local rate = (B.SITUATIONS.tankRates[1] + B.SITUATIONS.tankRates[2]) / 2
	return {
		build = buildKey,
		weapon = weapon,
		level = L,
		block = hooks.block or 0,
		riposte = hooks.riposte or 0,
		avoid = avoid,
		ehp = ehpWith / math.max(1e-12, ehpWithout) - 1,
		blockHealPerSecond = rate * block * (hooks.blockHeal or 0),
	}
end

-- S90 (C4, ROZWOJ 8, 11.6, 15.4): a Hunter build's crit, attack speed and dodge before the Data/Stats caps (StatCalc
-- clamps them, so the player is rebuilt with those three caps lifted), crit with Draw a Bead's `sighted` on the build's
-- rank (Paths.effectiveFor), next to the caps.
export type DexCaps = {
	crit: number,
	critSighted: number,
	critDmg: number,
	speed: number,
	dodge: number,
	critCap: number,
	speedCap: number,
	dodgeCap: number,
}
local dexCache: { [string]: DexCaps } = {}
local DEX_CAPS = { "critChance", "atkSpeed", "dodge" }

function SkillModel.dexCaps(build: Build, L: number): DexCaps
	local key = `{build.classId}|{build.key}|{L}`
	if dexCache[key] then
		return dexCache[key]
	end
	local sp = SkillModel.player(build, L)
	local caps: { [string]: number } = {}
	for _, id in DEX_CAPS do
		local def = Stats.get(id) :: any
		caps[id] = def.cap
	end
	local flat, pct = EffectStack.stats(sp.auraEntries)
	local sources: { any } = { { key = "source.passives", flat = sp.passives.flat, pct = sp.passives.pct } }
	if next(flat) ~= nil or next(pct) ~= nil then
		table.insert(sources, { key = "source.effects", flat = flat, pct = pct })
	end
	local ok, raw = pcall(function()
		for _, id in DEX_CAPS do
			(Stats.get(id) :: any).cap = nil
		end
		return B.playerFromItems(
			sp.classId,
			sp.level,
			sp.items,
			sp.traitScale,
			{ stats = sp.stats, sources = sources, hooks = sp.passives.hooks }
		)
	end)
	for _, id in DEX_CAPS do
		(Stats.get(id) :: any).cap = caps[id]
	end
	assert(ok, raw)
	local v = (raw :: any).values
	local sighted = 0
	local rank = Paths.skillRank(sp.character, "drawBead")
	if rank > 0 then
		local def = Paths.effectiveFor(sp.character, "drawBead", sp.weapons, rank)
		sighted = Skills.valueAt(def, "crit", rank)
	end
	local out: DexCaps = {
		crit = v.critChance or 0,
		critSighted = (v.critChance or 0) + sighted,
		critDmg = v.critDmg or 0,
		speed = v.atkSpeed or 0,
		dodge = v.dodge or 0,
		critCap = caps.critChance,
		speedCap = caps.atkSpeed,
		dodgeCap = caps.dodge,
	}
	dexCache[key] = out
	return out
end

export type ExecuteCheck = {
	gear: string,
	trait: number, -- Beheading's grown value
	node: number, -- Executioner (hook "executioner" of the build)
	cap: number,
	withLines: number, -- trait + node + top leg_executioner + top myth_executioner
	cut: number, -- what executionerCap cuts of withLines
}

-- E3 (STATY 10, 14): Beheading and Executioner on "Furia" with sword2h, Common +0 and Mythic +9.
function SkillModel.executeCheck(L: number, rarity: number, up: number): ExecuteCheck
	local build = SkillModel.withWeapon(byKey(SkillModel.FURY), "sword2h", nil)
	local sp = SkillModel.player(build, L, { gear = { rarity = rarity, up = up } })
	local hooks = sp.p.hooks
	local trait = hooks.traitExecute or 0
	local node = hooks.executioner or 0
	-- the node's hook only: the expected lines of the S32 set are left out (their top values come next)
	local itemLines = 0
	for _, item in sp.items do
		local stats = B.itemStats(item)
		itemLines += stats.hooks.executioner or 0
	end
	node -= itemLines
	local legTop = (Bonuses.get("leg_executioner") :: any).max
	local mythTop = (Bonuses.get("myth_executioner") :: any).max
	local withLines = trait + node + legTop + mythTop
	return {
		gear = `{Rarities.get(rarity).key} +{up}`,
		trait = trait,
		node = node,
		cap = Combat.executionerCap,
		withLines = withLines,
		cut = math.max(0, withLines - Combat.executionerCap),
	}
end

export type KillHealSum = {
	label: string,
	raw: number, -- summed killHeal hook (% max HP per kill)
	capped: number, -- Traits.killHeal (the lifesteal cap)
	lossPerKill: number, -- HP lost per kill in G1 (Balance.duel of the S32 player), % max HP
	waves: number, -- healed by the ~20 kills of two shield waves of the boss, % max HP (capped)
	inGame: boolean, -- false: the STATY 14 sum, never together in the game (Reaping one-handed, Drinker two-handed)
}

-- E5 (STATY 5, 10, 14): the kill-heal sums the game allows at L, capped by Traits.killHeal.
function SkillModel.killHealSums(L: number): { KillHealSum }
	local reaping = ItemRoll.trait(B.makeItem(B.tierId("axe1h", L), L, Rarities.MYTHIC, 9, {})) :: any
	local mythTop = (Bonuses.get("myth_killHeal") :: any).max
	local legTop = (Bonuses.get("leg_killHeal") :: any).max
	-- Krwiopijca (Drinker): the node whose passive hook is the killHeal CombatService.reward sums
	local drinkerNode = pathNode("berserker", "berserker_drinker")
	local drinkerField = drinkerNode.passive.hooks.killHeal
	local drinker = Paths.nodeValues(drinkerNode, drinkerNode.maxRank)[drinkerField] or 0
	local out: { KillHealSum } = {}
	local function add(label: string, classId: string, raw: number, inGame: boolean)
		local p = B.cachedPlayer(classId, L)
		local f = B.duel(p, B.monster(B.GENERIC, L))
		local capped = Traits.killHeal(raw)
		table.insert(out, {
			label = label,
			raw = raw,
			capped = capped,
			lossPerKill = f.hpLost * 100,
			waves = math.min(100, 20 * capped),
			inGame = inGame,
		})
	end
	add("Strażnik: Żniwo M+9 + myth_killHeal + 1× leg_killHeal", "Warrior", reaping.value + mythTop + legTop, true)
	add(
		"Strażnik: Żniwo M+9 + myth_killHeal + 3× leg_killHeal",
		"Warrior",
		reaping.value + mythTop + 3 * legTop,
		true
	)
	add(
		"Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 1× leg_killHeal",
		"Warrior",
		drinker + mythTop + legTop,
		true
	)
	add(
		"Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 3× leg_killHeal",
		"Warrior",
		drinker + mythTop + 3 * legTop,
		true
	)
	add(
		"STATY 14: Żniwo M+9 + Krwiopijca 3 + leg + myth (w grze nie występuje)",
		"Warrior",
		reaping.value + drinker + legTop + mythTop,
		false
	)
	return out
end

export type SavingSelf = { level: number, gear: string, lifesteal: number, self: number, total: number, cap: number }

-- E4 (STATY 3, 5): Saving Blow on its bearer with the set's lifesteal lines: the self part (Traits.savingSelfShare)
-- + lifesteal stays within the lifesteal cap.
function SkillModel.savingSelf(L: number, rarity: number, up: number): SavingSelf
	local build = SkillModel.withWeapon(byKey("healer.dungeon"), "holystaff", nil)
	local sp = SkillModel.player(build, L, { gear = { rarity = rarity, up = up } })
	local lifesteal = sp.p.values.lifesteal or 0
	local value = ((sp.p.traits or {}).savingBlow or { value = 0 }).value
	local self = Traits.savingSelfShare(value, lifesteal)
	local def = Stats.get("lifesteal") :: any
	return {
		level = L,
		gear = `{Rarities.get(rarity).key} +{up}`,
		lifesteal = lifesteal,
		self = self,
		total = math.min(lifesteal, def.cap) + self,
		cap = def.cap,
	}
end

-- S88: PvP (F) ----------------------------------------------------------------------------------------------------

-- F2: attackers and defenders (the S86 builds of ROZWOJ 10-12 for one target).
SkillModel.PVP_ATTACKERS = { "berserker.fury", "inquisitor.solo", "marksman.kingslayer", "destroyer.destroyerBoss" }
SkillModel.PVP_DEFENDERS =
	{ "berserker.fury", "inquisitor.solo", "marksman.kingslayer", "destroyer.destroyerBoss", "guardian.loner" }

local function pvpPlayer(key: string, L: number, gear: B.GearOpts?): any
	local build = byKey(key)
	return SkillModel.player(build, L, if gear then { gear = gear, element = "fire" } else { element = "fire" }).p
end

-- The attacker's class lines (F2 variant): two rings and the talisman with vs_<defender class> of a middle Mythic roll.
local function withClassLines(p: any, defenderClass: string, L: number): any
	local copy = table.clone(p)
	copy.hooks = table.clone(p.hooks)
	local id = Bonuses.classLine("vs_", defenderClass)
	local ilvl = math.max(1, L - B.GEAR_GAP)
	copy.hooks[id] = (copy.hooks[id] or 0) + 3 * ItemRoll.rollBonusValue(id, ilvl, Rarities.MYTHIC, 0.5)
	return copy
end

export type PvpPair = {
	attacker: string,
	defender: string,
	level: number,
	seconds: number, -- time to kill with traits
	noTraits: number, -- without any trait (both sides)
	ratio: number, -- seconds / noTraits (>= 0.90: the traits shorten the fight by at most 10 %)
	tickShare: number, -- share of trait / line ticks in the PvP damage
	tickSharePve: number, -- the same exchange with the rules against monsters
	classLines: number, -- seconds with the attacker's full class lines
	stun: number, -- share of the fight the defender stands stunned (Concussion)
}

local pvpCache: { [string]: PvpPair } = {}

-- F1-F3: one pair at L (Common +0, S32 convention).
function SkillModel.pvpPair(attacker: string, defender: string, L: number): PvpPair
	local key = `{attacker}|{defender}|{L}`
	if pvpCache[key] then
		return pvpCache[key]
	end
	local a, b = pvpPlayer(attacker, L), pvpPlayer(defender, L)
	local a0 = pvpPlayer(attacker, L, { traitScale = B.NO_TRAITS })
	local b0 = pvpPlayer(defender, L, { traitScale = B.NO_TRAITS })
	local with = B.pvpDuel(a, b).ab
	local without = B.pvpDuel(a0, b0).ab
	local pve = B.pvpDuel(a, b, { pve = true, seconds = with.seconds }).ab
	local lines = B.pvpDuel(withClassLines(a, b.classId, L), b, { classLines = true }).ab
	local row: PvpPair = {
		attacker = attacker,
		defender = defender,
		level = L,
		seconds = with.seconds,
		noTraits = without.seconds,
		ratio = with.seconds / math.max(1e-9, without.seconds),
		tickShare = with.ticks / math.max(1e-9, with.dps),
		tickSharePve = pve.ticks / math.max(1e-9, pve.dps),
		classLines = lines.seconds,
		stun = with.stun,
	}
	pvpCache[key] = row
	return row
end

-- F3: the conditional and defensive traits of STATY 8 (and Frostbite of the ice weapons) with their row build of
-- Balance.TRAIT_TARGETS; PvP value / PvE value in a mirror duel (same still / controlled shares).
SkillModel.PVP_HALF_TRAITS = {
	"beheading",
	"easyPrey",
	"runicSeal",
	"fullDraw",
	"bonebreaker",
	"swordplay",
	"parry",
	"savingBlow",
	"elementalMight",
} :: { string }

export type PvpHalf = { trait: string, level: number, pvp: number, pve: number, ratio: number }

function SkillModel.pvpHalf(traitId: string, L: number): PvpHalf
	local row: B.TraitTarget? = nil
	for _, r in B.TRAIT_TARGETS do
		if r.trait == traitId then
			row = r
			break
		end
	end
	assert(row, `SkillModel: no TRAIT_TARGETS row for {traitId}`)
	-- the nodes that strengthen the trait stay off as in its band (Executioner counts with Beheading in traitTerms)
	local build =
		SkillModel.withoutNodes(SkillModel.withWeapon(byKey(row.build), row.weapon, row.offhand), row.nodesOff)
	local element = if traitId == "elementalMight" then "ice" else "fire"
	local gear: B.GearOpts = { weapon = row.weapon, offhand = if row.offhand then row.offhand else false }
	local p = SkillModel.player(build, L, { gear = gear, element = element }).p
	local off = SkillModel.player(build, L, { gear = B.withoutTrait(gear, traitId), element = element }).p
	local S = B.SITUATIONS
	local opts: B.PvpOpts = { still = S.still, controlled = S.controlled }
	local pvp = B.pvpTraitValue(p, off, p, traitId, false, opts)
	local pve = B.pvpTraitValue(p, off, p, traitId, true, opts)
	return { trait = traitId, level = L, pvp = pvp, pve = pve, ratio = pvp / math.max(1e-12, pve) }
end

-- F3 (STATY 8): share of a fight the target player stands stunned by Concussion (the Inquisitor with a flail and a
-- shield, Balance.TRAIT_TARGETS), a mirror duel at L.
function SkillModel.pvpStun(L: number): number
	local build = SkillModel.withWeapon(byKey("inquisitor.solo"), "flail1h", "shield")
	local p = SkillModel.player(build, L, { gear = { weapon = "flail1h", offhand = "shield" } }).p
	return B.pvpDuel(p, p).ab.stun
end

-- F3: one tick of a skill's damage over time (Rending, Venom Arrow, the element burn): Damage.computeDamage's
-- dotBase without and with pvp (the same seed), Traits.pvpTick only in PvP; returns PvP / PvE.
function SkillModel.pvpTickRatio(L: number): number
	local a = pvpPlayer("berserker.fury", L)
	local b = pvpPlayer("guardian.loner", L)
	local attacker = Damage.fromStats(L, a.values)
	local _, defender = Damage.fromStats(L, b.values)
	local Rng = require("../src/shared/Logic/Rng") :: any
	local pve = Damage.computeDamage(attacker, defender, { kind = "phys", canDodge = false }, Rng.new(7))
	local pvp = Damage.computeDamage(attacker, defender, { kind = "phys", canDodge = false, pvp = true }, Rng.new(7))
	local tick = Traits.dotTick(pve.dotBase or 0, 30, 4, 0)
	local pvpTick = Traits.pvpTick(Traits.dotTick(pvp.dotBase or 0, 30, 4, 0))
	return pvpTick / math.max(1e-9, tick)
end

-- S88: the target rows (H) ----------------------------------------------------------------------------------------

local s88Cache: { B.TargetRow }? = nil

-- H1-H2: every S88 target as a TargetRow (balance.spec asserts the rows without `report`; the report prints all of
-- them). Levels Balance.TRAIT_LEVELS (45 / 70 / 100).
function SkillModel.targetsS88(): { B.TargetRow }
	if s88Cache then
		return s88Cache
	end
	local rows: { B.TargetRow } = {}
	local function add(
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		L: number?,
		report: string?,
		classId: string?
	)
		table.insert(rows, {
			id = id,
			group = string.match(id, "^([%a%d]+)") or id,
			label = label,
			value = value,
			low = low,
			high = high,
			classId = classId,
			level = L,
			report = report,
		})
	end
	local levels = B.TRAIT_LEVELS
	-- C2 / E6: trait bands and the nodes that strengthen a trait
	for _, row in B.TRAIT_TARGETS do
		for _, L in levels do
			local r = SkillModel.traitTarget(row, L)
			for _, v in r.values do
				local element = if v.element then ` {v.element}` else ""
				local label = `{row.trait}{element} · {row.build}@{row.weapon} · L{L}`
				local reportOnly = row.reportWhy ~= nil
					and (row.reportElements == nil or (v.element ~= nil and table.find(row.reportElements, v.element) ~= nil))
					and (row.reportAt == nil or table.find(row.reportAt, L) ~= nil) -- S89
				add(
					"T1",
					label,
					v.value,
					r.band[1],
					r.band[2],
					L,
					if reportOnly then row.reportSession or "S88" else nil
				)
				if v.nodes then
					add("T1.nodes", `{label} (z węzłami)`, v.nodes, nil, B.TRAIT_NODES_MAX, L)
				end
			end
		end
	end
	-- C9: weapon sets of a path
	for _, entry in B.TYPE_SETS do
		for _, L in levels do
			local r = SkillModel.typeSets(entry, L)
			local reportOnly = entry.reportWhy ~= nil
				and (entry.reportAt == nil or table.find(entry.reportAt, L) ~= nil)
			add(
				"T2",
				`{entry.path} · L{L}`,
				r.spread,
				nil,
				B.TYPE_SET_MAX,
				L,
				if reportOnly then entry.reportSession or "S88" else nil
			)
		end
	end
	-- B: armour and magic resistance shares, agile kinds
	local D = B.DEFENCE_TARGETS
	local undeadArmored = Families.defence("undead", "armored") :: any
	local undeadWarded = Families.defence("undead", "warded") :: any
	for _, L in levels do
		local function kindWith(defMul: number, mresMul: number): any
			local kind = table.clone(B.GENERIC) :: any
			kind.defMul, kind.mresMul = defMul, mresMul
			return B.monster(kind, L)
		end
		add("B1", `pancerz zwykły · L{L}`, B.armorShare(kindWith(1, 1), L, false), D.armor[1], D.armor[2], L)
		add(
			"B1",
			`pancerz ×{undeadArmored.defMul} · L{L}`,
			B.armorShare(kindWith(undeadArmored.defMul, 1), L, false),
			D.armored[1],
			D.armored[2],
			L
		)
		add("B1", `odporność zwykła · L{L}`, B.armorShare(kindWith(1, 1), L, true), D.mres[1], D.mres[2], L)
		add(
			"B1",
			`odporność ×{undeadWarded.mresMul} · L{L}`,
			B.armorShare(kindWith(1, undeadWarded.mresMul), L, true),
			D.warded[1],
			D.warded[2],
			L
		)
		for _, c in B.CLASSES do
			for _, def in B.defenceAt(c, L) do
				if string.find(def.id, "agile", 1, true) then
					local generic = B.defenceAt(c, L)[1]
					-- the animal trait is shared with the lynx of the Meadows (1-20). S91: the trait lives in
					-- Data/Families (not an S91 lever) and the lynx's EXP/s on the Meadows is in band: the owner decides
					local lynx = string.find(def.id, "animal", 1, true) ~= nil
					add(
						"B5",
						`{c} {def.id} · L{L}: czas / zwykły`,
						def.seconds / generic.seconds,
						nil,
						D.dodgeTime,
						L,
						if lynx then "właściciel" else nil,
						c
					)
				end
			end
		end
	end
	-- D3: family and class lines at level 100
	for _, t in B.LINE_TARGETS do
		local id = if t.over == "family"
			then Bonuses.familyLine(t.prefix :: any, Families.ids[1])
			else Bonuses.classLine(t.prefix :: any, "Warrior")
		local lo, hi = ItemRoll.bonusRange(id, 100, Rarities.COMMON)
		local _, top = ItemRoll.bonusRange(id, 100, Rarities.MYTHIC)
		local name = `{t.prefix}<{if t.over == "family" then "rodzina" else "klasa"}>`
		add("D3", `{name}: Zwykły min · L100`, lo, t.common[1] - 0.05, t.common[1] + 0.05, 100)
		add("D3", `{name}: Zwykły max · L100`, hi, t.common[2] - 0.05, t.common[2] + 0.05, 100)
		add("D3", `{name}: Mityk max · L100`, top, nil, t.mythicTop, 100)
	end
	-- D4: named Mythics
	local named: { string } = {}
	for id in B.NAMED_TARGETS do
		table.insert(named, id)
	end
	table.sort(named)
	for _, id in named do
		local sum = 0
		for _, c in B.NAMED_TARGETS[id] do
			sum += B.namedPower(id, c).power
		end
		local def = Items.get(id) :: any
		add("D4", `{id} · L{def.level}`, sum / #B.NAMED_TARGETS[id], B.NAMED_BAND[1], B.NAMED_BAND[2], def.level)
	end
	-- E1: the Guardian's caps
	local avoidCap = (Combat.dodgeCap + Combat.avoidBonus) / 100
	for _, L in levels do
		for _, key in { "guardian.loner", "guardian.defender" } do
			for _, w in { "sword1h", "saber1h", "axe1h", "mace1h" } do
				local g = SkillModel.guardLimits(key, w, L)
				local label = `{key}@{w} · L{L}`
				add("E1.block", label, g.block, nil, Combat.blockCap, L)
				add("E1.riposte", label, g.riposte, nil, Combat.riposteCap, L)
				add("E1.avoid", label, g.avoid, nil, avoidCap, L)
				-- S89 (F4): out of reach of the S89 levers (the traits of the axe and the mace, S88): owner
				local ehpReport = if w == "axe1h" or w == "mace1h" then "S89" else nil
				add("E1.ehp", label, g.ehp, nil, B.GUARD_EHP_MAX, L, ehpReport)
			end
		end
		-- E3: Beheading and Executioner never cut by the cap
		for _, r in { { Rarities.COMMON, 0 }, { Rarities.MYTHIC, 9 } } do
			local e = SkillModel.executeCheck(L, r[1], r[2])
			add("E3", `Ścięcie + Kat · {e.gear} · L{L}`, e.trait + e.node, nil, e.cap, L)
			local s = SkillModel.savingSelf(L, r[1], r[2])
			add("E4.self", `Zbawczy cios na noszącym + wampiryzm · {s.gear} · L{L}`, s.total, nil, s.cap, L)
		end
		-- E4: T-SK5 with Anointment (Common)
		local healer = byKey("healer.dungeon")
		add(
			"E4.tsk5",
			`T-SK5 healer.dungeon na guardian.defender · L{L}`,
			SkillModel.oneHeal(healer, L, SkillModel.defenderTank(L)),
			SkillModel.TSK5_BAND[1],
			SkillModel.TSK5_BAND[2],
			L
		)
		-- E5: kill heal sums the game allows, capped
		local cap = (Stats.get("lifesteal") :: any).cap
		for _, k in SkillModel.killHealSums(L) do
			if k.inGame then
				add("E5", `{k.label} · L{L}`, k.capped, nil, cap, L)
			end
		end
	end
	-- F: PvP
	local P = B.PVP_TARGETS
	for _, L in levels do
		for _, a in SkillModel.PVP_ATTACKERS do
			for _, d in SkillModel.PVP_DEFENDERS do
				local r = SkillModel.pvpPair(a, d, L)
				add("F.ratio", `{a} → {d} · L{L}`, r.ratio, P.ratio, nil, L)
				add("F.ticks", `{a} → {d} · L{L}`, math.abs(r.tickShare - r.tickSharePve), nil, P.tickShare, L)
			end
		end
		add(
			"F.tick",
			`tyknięcie umiejętności PvP / PvE · L{L}`,
			SkillModel.pvpTickRatio(L),
			P.tick[1],
			P.tick[2],
			L
		)
		for _, t in SkillModel.PVP_HALF_TRAITS do
			local h = SkillModel.pvpHalf(t, L)
			add("F.half", `{t} · L{L}`, h.ratio, nil, P.half, L)
		end
		add("F.stun", `Wstrząs: ogłuszenie / czas walki · L{L}`, SkillModel.pvpStun(L), nil, P.stun, L)
	end
	-- G: luck within the cap, Fortune felt
	local LuckData = require("../src/shared/Data/Luck") :: any
	for _, L in levels do
		for _, k in { "K1", "K2" } do
			local d = B.dropsPerHour("Warrior", L, k, "full")
			add(
				"G.cap",
				`{k} + Fortuna: szczęście przed limitem · L{L}`,
				d.beforeCap,
				nil,
				LuckData.monsterItemCap,
				L
			)
		end
		local with = B.dropsPerHour("Warrior", L, "K1", "full")
		local without = B.dropsPerHour("Warrior", L, "K1", false)
		add(
			"G.fortune",
			`K1: Unikaty z Fortuną / bez · L{L}`,
			with.unique / math.max(1e-12, without.unique),
			B.FORTUNE_UNIQUES[1],
			B.FORTUNE_UNIQUES[2],
			L
		)
	end
	s88Cache = rows
	return rows
end

return SkillModel
