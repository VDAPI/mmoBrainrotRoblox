--!strict
-- Balance model (S32, DESIGN §15.1): expected values from the game's own modules, no randomness.
-- Used by balance.spec (targets of DESIGN §15.1) and tools/balance_report.luau (docs/BALANS.md).
--
--   gear(classId, level, opts)      -> the items a player wears (weapon, off-hand, 4 armour pieces, jewellery)
--   player(classId, level, opts)    -> StatCalc values of that player + the weapon
--   duel / groupFight / expectedGroup / elite / elite2 / grimrok -> fight length and HP lost
--   power(...)                      -> "character power" = sqrt(DPS x effective HP), for rarity value
--   pace(...) / economy(...)        -> kills per level, EXP/h, gold/h and the 1-20 gold budget
-- S83 (balance plan, world model 1-100; the S32 functions above stay as they are and build the 1-20 tables):
--   regionAt / kindAtRegion / kindRates          -> the usual kind of a level, kinds of a region vs GENERIC
--   questsAt / paceAt / paceBand / economyAt     -> quests on their own level, pace with carried EXP, gold per hour
--   potionsAt / potionHps                        -> potions on the S54 interval (Logic/Potions)
--   caveElites / team / bossCadence / bossFight  -> cave Elites from the real spawners, the bosses' schedule
--   targets1_20 / targetsGlobal / targetsRegion  -> target rows for balance.spec and the report (REGION_TARGETS)
--   dataDump / rankDump / ledger                 -> the balance ledger (tools/balance_reasons.luau)
-- S84 (items, loot and monster defence 20-100; test data SITUATIONS, MIX, G8_PAIRS, LUCK_PROFILES below):
--   traitTerms / power(p, L, PowerOpts) / powerMix / traitValue -> item traits as expected values in situations
--   rarityGainAt / twoHandedParity / upgradePlan / upgradeVsIncome -> G7, G8, G9
--   materialDemand / materialSupply / ilvlGaps / longevity       -> materials, item level gaps, longevity
--   luckProfile / dropsPerHour / usableShare / bossDrops          -> drops per hour with luck (D5)
--   armorShare / defenceAt / vsDefence                            -> monster families, armour, dodge
--
-- Fights use basic attacks plus `SKILL_DPS` (1-2 skills on cooldown) and no potions. Monsters swing once at the
-- start and then every interval; the player regenerates its in-combat regen.

local fs = require("@lune/fs")

local AreaProfiles = require("../src/shared/Data/AreaProfiles")
local ArenaData = require("../src/shared/Data/Arena")
local ArenaRules = require("../src/shared/Logic/ArenaRules")
local AreaRates = require("../src/shared/Logic/AreaRates")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local Bases = require("../src/shared/Data/Items/Bases")
local Blessings = require("../src/shared/Data/Blessings")
local Bonuses = require("../src/shared/Data/Bonuses")
local Bosses = require("../src/shared/Data/Bosses")
local BossMechanics = require("../src/shared/Logic/BossMechanics")
local BossScaling = require("../src/shared/Logic/BossScaling")
local BossSchedule = require("../src/shared/Logic/BossSchedule")
local BossTuning = require("../src/shared/Data/BossTuning")
local BuffCategories = require("../src/shared/Data/BuffCategories")
local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local Damage = require("../src/shared/Logic/Damage")
local Families = require("../src/shared/Data/Families")
local Combat = require("../src/shared/Data/Combat")
local Exp = require("../src/shared/Logic/Exp")
local FightSim = require("../src/shared/Logic/FightSim")
local GuildSkills = require("../src/shared/Data/GuildSkills")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemScore = require("../src/shared/Logic/ItemScore")
local ItemTraits = require("../src/shared/Data/ItemTraits")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Items = require("../src/shared/Data/Items")
local LevelCurves = require("../src/shared/Logic/LevelCurves")
local LoginReward = require("../src/shared/Logic/LoginReward")
local LoginRewardData = require("../src/shared/Data/LoginReward")
local WorldEvents = require("../src/shared/Logic/WorldEvents")
local Loot = require("../src/shared/Logic/Loot")
local LootTables = require("../src/shared/Data/LootTables")
local Luck = require("../src/shared/Logic/Luck")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterCast = require("../src/shared/Logic/MonsterCast")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Monsters = require("../src/shared/Data/Monsters")
local MountData = require("../src/shared/Data/Mounts")
local MountLogic = require("../src/shared/Logic/Mounts")
local PartyBonus = require("../src/shared/Logic/PartyBonus")
local PartyLoot = require("../src/shared/Logic/PartyLoot")
local PathData = require("../src/shared/Data/Paths")
local Paths = require("../src/shared/Logic/Paths")
local Potions = require("../src/shared/Logic/Potions")
local QuestBudget = require("../src/shared/Logic/QuestBudget")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local Rarities = require("../src/shared/Data/Rarities")
local ScheduledEvents = require("../src/shared/Data/ScheduledEvents")
local Recipes = require("../src/shared/Data/Recipes")
local Reroll = require("../src/shared/Logic/Reroll")
local Shops = require("../src/shared/Data/Shops")
local SkillData = require("../src/shared/Data/Skills")
local Spawns = require("../src/shared/Data/Spawns")
local Skills = require("../src/shared/Logic/Skills")
local StatCalc = require("../src/shared/Logic/StatCalc")
local Stats = require("../src/shared/Data/Stats")
local StoryProgress = require("../src/shared/Logic/StoryProgress")
local Traits = require("../src/shared/Logic/Traits")
local Upgrade = require("../src/shared/Logic/Upgrade")

local Balance = {}

Balance.CLASSES = { "Warrior", "Hunter", "Mage", "Cleric" }

-- Main weapon, off-hand and armour weight per class (the most common choice).
Balance.LOADOUT = {
	Warrior = { weapon = "sword1h", offhand = "shield", weight = "heavy" },
	Hunter = { weapon = "bow", offhand = "quiver", weight = "medium" },
	Mage = { weapon = "wand", offhand = "orb", weight = "light" },
	Cleric = { weapon = "mace1h", offhand = "shield", weight = "heavy" },
} :: { [string]: { weapon: string, offhand: string?, weight: string } }

-- Damage share of 1-2 skills used on cooldown on top of basic attacks (single target).
Balance.SKILL_DPS = FightSim.SKILL_DPS
-- Share of a boss fight the players spend hitting (the rest: moving out of telegraphs).
Balance.BOSS_UPTIME = 0.75
-- Share of Elite II / boss special attacks that still hit (most telegraphs are dodged).
Balance.SPECIAL_HIT = FightSim.SPECIAL_HIT
-- Gear "at level": item level = player level - GEAR_GAP (what drops give on average).
Balance.GEAR_GAP = 2
-- Seconds between two fights (walking to the next group) and out-of-combat regeneration (% max HP / s).
Balance.BREAK = 1
Balance.WALK = 6

Balance.ARMOR_SLOTS = { "helmet", "armor", "gloves", "boots" }
Balance.JEWELLERY = { "necklace", "ring", "ring", "talisman" }

-- S84 test data (assumptions of the item model, not game numbers: never in BALANCE_MODULES or on the wiki) --------

-- Situations of the trait model (S84 B3; the names S88 measures with). Every number is a STATY 14 assumption ("Do
-- pomiaru"); S85-S86 replace basicShare, controlled, still, mana, dungeon and areaShare with their skill model.
Balance.SITUATIONS = {
	-- share of the basic attack in the damage: ~50 % (Swordplay, Twin Cut), the Mage 35-50 % (Elemental Spark)
	basicShare = { Warrior = 0.5, Hunter = 0.5, Mage = 0.4, Cleric = 0.5 } :: { [string]: number },
	skillInterval = 2.5, -- s between offensive skills (Full Draw: a skill every 2-3 s)
	elementShare = 0.175, -- share of the weapon-element effects in the Mage's damage (Elemental Might: 15-20 %)
	iceUptime = 0.65, -- share of the fight the Mage's ice skills slow the target (Elemental Might: 60-70 %)
	-- Run Through: share of basic hits with an enemy in the band behind the target (group; 0 on one target and on
	-- the boss itself, the boss's shield waves count as a group); the report adds 0.15 and 0.5 (band not measured)
	behindShare = 0.3,
	behindReport = { 0.15, 0.5 },
	tankRates = { 1.25, 0.6 }, -- attacks per s on a tank: in a group 1-1.5, one target 0.5-0.7 (Swordplay, Parry)
	killEvery = 8, -- s per kill in `solo` (Reaping: a kill every 6-10 s)
	bossTeam = 3, -- players of the boss fight (S32 Grimrok: 3-5); its shield waves (2 x ~10, STATY 7) from Data/Bosses
	controlled = 0.65, -- share of the fight the target is controlled (Easy Prey: 60-70 %)
	still = 0.70, -- share of the fight the Mage stands still (Runic Seal: 60-75 %)
	areaShare = 0, -- share of area skills: the S32 convention has none (Combat.areaProcShare once S85-S86 add them)
	singleSeconds = 60, -- `single`: one generic monster of the player's level, a 60 s exchange
}
-- Every situation of traitValue: power situations measure power², `tank` EHP, `solo` HP lost per kill.
Balance.SITUATION_LIST =
	{ "single", "group", "elite", "boss", "armored", "tank", "solo", "controlled", "still", "mana", "dungeon" }
-- Weights of the situations in powerMix (S88 uses the same table).
Balance.MIX = { group = 0.5, elite = 0.3, boss = 0.2 } :: { [string]: number }

-- G8 (S84 D): two-handed weapon (no off-hand) against the class default loadout (LOADOUT); `path` = the one-handed set
-- of the same path (report only, S89-S90). The Hunter has no two-handed weapon (HUNTER_WEAPONS: report ranking).
Balance.G8_PAIRS = {
	{ classId = "Warrior", weapon = "sword2h" },
	{ classId = "Warrior", weapon = "axe2h" },
	{ classId = "Warrior", weapon = "hammer2h" },
	{ classId = "Warrior", weapon = "spear2h" },
	{ classId = "Mage", weapon = "staff", path = { weapon = "wand", offhand = "orb" } },
	{ classId = "Mage", weapon = "runestaff", path = { weapon = "wand", offhand = "tome" } },
	{ classId = "Cleric", weapon = "holystaff", path = { weapon = "scepter", offhand = "shield" } },
} :: { { classId: string, weapon: string, path: { weapon: string, offhand: string }? } }
Balance.HUNTER_WEAPONS = { "bow", "shortbow", "longbow", "crossbow", "heavycrossbow" }

-- D5 and luck (S84 H1; S88 G1 uses the same profiles). The player is a Priest of Fortune (scepter + relic); every
-- number comes from the data (Bonuses, Blessings, GuildSkills, ItemRoll.trait) through Balance.luckProfile.
--   jewellery: "heroic" = expected dropBonus lines of a Heroic set (expectedBonuses); "legendary" = one dropBonus
--              line of a middle Legendary roll on each of the 4 jewellery items; "mythic" = top of the Mythic range
--   (S134g: the legendaryLines field (leg_dropBonus lines) is gone with the lines; luckProfile.legendary is 0)
Balance.LUCK_PROFILES = {
	{ id = "K0", label = "bez szczęścia" },
	{ id = "K1", label = "zwykły", jewellery = "heroic", blessing = 3, guild = 0, relic = { rarity = 1, up = 0 } },
	{
		id = "K2",
		label = "łowca łupu",
		jewellery = "legendary",
		blessing = 4,
		guild = 5,
		relic = { rarity = 5, up = 9 },
	},
	{
		id = "K3",
		label = "maks.",
		jewellery = "mythic",
		blessing = 5,
		guild = 5,
		relic = { rarity = 5, up = 9 },
	},
} :: { any }

-- S88 test data (targets of the trait, line and named-item tuning; never game numbers) ----------------------------

-- C1 (STATY 14, answer 6): every combat trait is worth TRAIT_BAND in its situations (equal weights) on the path
-- build of every path of its STATY 3 row (the first build of the path; the first row of a trait is its main path,
-- used by the PvP checks), Common +0 at 45 / 70 / 100. `report` situations are printed only (a structural zero of
-- the model: the boss's shield waves are a group, a Healer loses no HP in a duel); `nodesOff` = the path nodes that
-- strengthen the trait, off in the band and on in the TRAIT_NODES_MAX row; `elements` = every weapon element on its
-- own; `twoHanded` = a two-handed Mage / Cleric weapon (E6: up to TRAIT_BAND_2H); `reportWhy` / `reportSession` =
-- the row is report only (H4: the reason, the session with the lever); `reportElements` = those elements only.
-- SkillModel.traitTarget measures a row (SkillModel.traitValue on the event; the six traits of
-- SkillModel.TRAIT_VIA_TERMS through Balance.traitTerms with the situation measured on the build).
export type TraitTarget = {
	trait: string,
	build: string,
	weapon: string,
	offhand: string?,
	situations: { string },
	report: { string }?,
	nodesOff: { string }?,
	elements: boolean?,
	twoHanded: boolean?,
	reportWhy: string?,
	reportSession: string?,
	reportElements: { string }?,
	reportAt: { number }?, -- S89: report only at these levels (all levels when nil and reportWhy is set)
}
Balance.TRAIT_BAND = { 0.04, 0.06 }
Balance.TRAIT_BAND_2H = { 0.04, 0.09 } -- E6: the two-handed Mage and Cleric weapons after x1.3-1.5
Balance.TRAIT_NODES_MAX = 0.08 -- STATY 14: Rending Gash with the bleed nodes, Toxic Barbs with the venoms, Beheading with Executioner
Balance.TRAIT_LEVELS = { 45, 70, 100 }
local function traitTarget(
	trait: string,
	build: string,
	weapon: string,
	offhand: string?,
	situations: { string },
	extra: { [string]: any }?
): TraitTarget
	local row: any = { trait = trait, build = build, weapon = weapon, offhand = offhand, situations = situations }
	for k, v in extra or {} do
		row[k] = v
	end
	return row :: TraitTarget
end
Balance.TRAIT_TARGETS = {
	-- S94: 70 and 100 in the report: the S84 boss situation at 70 / 100 is Vaelgrath (Balance.bossFightAt, regionAt(70)
	-- = the Frost Peaks) with the S94 shield waves at 86 / 87 (<= 110 % per member of a party of 3, C7): fewer helper
	-- attacks to counter (0.050 -> 0.037 / 0.051 -> 0.039); waves at 99 / 100 give 2.9 per member, a faster swing
	-- breaks the S32 tank (speed 1.5: 5.1 HP / min)
	-- S134: 45 in the report too: bosses 2.0 call 8 helpers per wave for every party (a party of 3 had 14) and cast
	-- more telegraphed attacks, so the tank counters fewer helper and basic blows (0.044 -> 0.037 at 45)
	traitTarget("swordplay", "guardian.loner", "sword1h", "shield", { "group", "elite", "boss" }, {
		reportSession = "S134", -- S94 (70, 100), S134 (45)
		reportAt = { 45, 70, 100 },
		reportWhy = "poza zasięgiem dźwigni S94: 0.037 / 0.039 at 70 / 100 (the S84 boss at 70 and 100 is Vaelgrath with the S94 waves 86 / 87; waves at 99 / 100 lose 2.9 HP per member, a faster swing breaks the S32 tank); owner: the boss of the situation at 70. S134: 0.037 at 45 (bosses 2.0: 8 helpers per wave instead of 14 for a party of 3, more telegraphed casts, fewer blows to counter); owner: the trait value or the boss of the situation",
	}),
	-- S89 (F4): 0.044 at 45 and 70 after the S89 nodes (asserted); 100 stays report
	-- S93: 45 in the report too: the S84 boss situation at 45 is Azgor moved to 45 (Balance.bossFightAt), whose shield
	-- waves at 58 / 59 (<= 110 % per member of a party of 3, C7) give the tank fewer helper attacks to counter
	-- S94: 70 too (Vaelgrath with the S94 waves 86 / 87 as the S84 boss at 70: 0.044 -> 0.033)
	traitTarget("swordplay", "standard.commander", "sword1h", "shield", { "group", "elite", "boss" }, {
		reportSession = "S94", -- S89 (100), S93 (45), S94 (70)
		reportAt = { 45, 70, 100 },
		reportWhy = "poza zasięgiem dźwigni S89: 0.039 at 100; the Standard-Bearer counters only with the sword's fixed 10 % (no Counterattack node in its rows 4-11), trait values are S88's (owner). Poza zasięgiem dźwigni S93: 0.038 at 45 (the S84 boss at 45 is Azgor with the S93 waves 58 / 59; owner: the boss of the situation at 45). Poza zasięgiem dźwigni S94: 0.033 at 70 (the S84 boss at 70 is Vaelgrath with the S94 waves 86 / 87)",
	}),
	traitTarget("twinCut", "standard.commander", "saber1h", "shield", { "single", "elite" }),
	traitTarget("twinCut", "guardian.defender", "saber1h", "shield", { "single", "elite" }, {
		reportSession = "S89",
		reportAt = { 45 },
		reportWhy = "poza zasięgiem dźwigni S89: 0.0615 at 45; R1 (S89) raised the basic attack share of every Warrior and the Guardian has no damage lever at 45 (owner: the trait value, S88)",
	}),
	traitTarget("reaping", "guardian.loner", "axe1h", "shield", { "solo" }, { report = { "boss" } }),
	traitTarget("bonebreaker", "guardian.defender", "mace1h", "shield", { "tank" }),
	traitTarget("bonebreaker", "inquisitor.solo", "mace1h", "shield", { "tank" }),
	traitTarget("bonebreaker", "fortune.plunder", "mace1h", "relic", { "tank" }),
	traitTarget("beheading", "berserker.fury", "sword2h", nil, { "single", "group" }, {
		nodesOff = { "berserker_executioner" },
	}),
	traitTarget("rendingGash", "berserker.fury", "axe2h", nil, { "single", "elite" }, {
		nodesOff = { "berserker_wounds", "berserker_openWounds" },
		reportSession = "S89",
		reportAt = { 45, 100 },
		reportWhy = "poza zasięgiem dźwigni S89: 0.0400 at 45, 0.039 at 100 (band from 0.04): Mighty Strike 10B and Rend 10A bleeds (R4) take the share of the hits that proc it (owner: the trait value, S88)",
	}),
	traitTarget("sundering", "berserker.fury", "hammer2h", nil, { "single", "armored" }),
	traitTarget("runThrough", "berserker.fury", "spear2h", nil, { "group" }, {
		report = { "boss" },
		reportSession = "S89",
		reportAt = { 45 },
		reportWhy = "poza zasięgiem dźwigni S89: 0.063 at 45; R1 (S89) cut the shared area skills, the group at 45 has no Titan's Wrath yet (owner: the trait value, S88)",
	}),
	traitTarget("parry", "guardian.defender", "sword1h", "shield", { "tank" }),
	traitTarget("parry", "standard.commander", "sword1h", "shield", { "tank" }),
	traitTarget("parry", "healer.dungeon", "scepter", "shield", { "tank" }),
	traitTarget("parry", "inquisitor.bulwark", "mace1h", "shield", { "tank" }),
	traitTarget("harrying", "scout.partyHunter", "shortbow", "quiver", { "solo" }),
	traitTarget("toxicBarbs", "trapper.poacher", "bow", "quiver", { "single", "elite" }, {
		nodesOff = { "trapper_venom", "trapper_basilisk" },
	}),
	traitTarget("toxicBarbs", "scout.partyHunter", "bow", "quiver", { "single", "elite" }, {
		reportSession = "S90",
		reportAt = { 45 },
		reportWhy = "poza zasięgiem dźwigni S90: 0.062 at 45; the Hunter's skills above rank 20 got flatter (R1, S90), basic hits carry more of the damage (owner: the trait value, S88)",
	}),
	traitTarget("criticalForce", "marksman.kingslayer", "longbow", "quiver", { "single", "group" }),
	traitTarget("easyPrey", "trapper.poacher", "crossbow", "quiver", { "controlled" }),
	traitTarget("bodkinBolt", "marksman.kingslayer", "heavycrossbow", "quiver", { "single", "armored" }),
	traitTarget("fullDraw", "marksman.kingslayer", "longbow", "quiver", { "single", "group" }, {
		reportSession = "S90",
		reportWhy = "poza zasięgiem dźwigni S90: 0.063-0.068 at 45-100; the Marksman casts as often as before while its skills above rank 20 got flatter (R1, S90), so the boosted basic weighs more (owner: the trait value, S88)",
	}),
	traitTarget("fullDraw", "marksman.kingslayer", "heavycrossbow", "quiver", { "single", "group" }, {
		reportSession = "S90",
		reportWhy = "poza zasięgiem dźwigni S90: 0.061-0.065 at 45-100 (as the longbow; owner: the trait value, S88)",
	}),
	traitTarget("fullDraw", "trapper.poacher", "bow", "quiver", { "single", "group" }),
	traitTarget("fullDraw", "scout.partyHunter", "shortbow", "quiver", { "single", "group" }, {
		reportSession = "S90",
		reportAt = { 45 },
		reportWhy = "poza zasięgiem dźwigni S90: 0.062 at 45 (as the Marksman; owner: the trait value, S88)",
	}),
	traitTarget("elementalSpark", "destroyer.destroyerExp", "wand", "orb", { "mana", "group" }, {
		elements = true,
		reportElements = { "fire", "lightning" },
		reportSession = "S90",
		reportWhy = "poza zasięgiem dźwigni S90: fire 0.060-0.062, lightning 0.061-0.065 at 45 / 100; the Destroyer's skills above rank 20 got lower (R1, S90), the basic attack carries more (owner: the trait value, S88)",
	}),
	traitTarget("elementalSpark", "arcanist.arcanistBoss", "wand", "tome", { "mana", "group" }, {
		elements = true,
		reportElements = { "lightning" },
		reportSession = "S90",
		reportAt = { 45 },
		reportWhy = "poza zasięgiem dźwigni S90: lightning 0.062 at 45 (fire 0.046-0.051 and lightning 0.048-0.056 at 70-100 in band); one Spark number for both paths (owner: the trait value, S88)",
	}),
	traitTarget("elementalMight", "destroyer.destroyerExp", "staff", nil, { "single", "group" }, {
		elements = true,
		twoHanded = true,
		reportElements = { "lightning" },
		reportSession = "S90",
		reportAt = { 100 },
		reportWhy = "poza zasięgiem dźwigni S90: lightning 0.099 at 100 (0.082-0.086 at 45-70): the arc rider on one target (riderSameTarget); one Might number for three elements (owner: the trait value, S88)",
	}),
	traitTarget("runicSeal", "arcanist.arcanistBoss", "runestaff", nil, { "still", "boss" }),
	traitTarget("learnedFormulae", "arcanist.arcanistBoss", "wand", "tome", { "mana" }, {
		reportSession = "S90",
		reportWhy = "poza zasięgiem dźwigni S90: 0.003-0.015 at 45-100; at T-SK4 2.0-2.4 (ROZWOJ 12.7) the boss build's damage comes from the cheap Discharge and the charges, a saving buys few extra casts in 180 s (owner: the trait, S88)",
	}),
	traitTarget("powerLens", "destroyer.destroyerExp", "wand", "orb", { "single", "group" }),
	traitTarget("anointment", "healer.dungeon", "scepter", "shield", { "dungeon" }),
	traitTarget("anointment", "fortune.plunder", "scepter", "relic", { "dungeon" }),
	traitTarget("savingBlow", "healer.dungeon", "holystaff", nil, { "dungeon" }, { report = { "solo" } }),
	traitTarget("concussion", "inquisitor.solo", "flail1h", "shield", { "group" }, { report = { "boss" } }),
	traitTarget("concussion", "fortune.plunder", "flail1h", "relic", { "group" }, { report = { "boss" } }),
} :: { TraitTarget }

-- C9: weapon sets of one path compared in MIX (max / min - 1 <= TYPE_SET_MAX); `measure` "dps" (combat paths),
-- "power" (sqrt(DPS x EHP): Guardian, Standard-Bearer, Scout, Priest of Fortune) or "healer" (mean of the dungeon
-- heal and the one-target DPS). The relic only against relics (Prosperity). `reportWhy`: the row is report only (H4).
export type TypeSet = {
	path: string,
	build: string,
	measure: string,
	sets: { { main: string, offhand: string? } },
	reportWhy: string?,
	reportSession: string?,
	reportAt: { number }?, -- report only at these levels (all levels when nil and reportWhy is set)
}
Balance.TYPE_SET_MAX = 0.05
Balance.TYPE_SETS = {
	{
		path = "berserker",
		build = "berserker.fury",
		measure = "dps",
		sets = { { main = "sword2h" }, { main = "axe2h" }, { main = "hammer2h" }, { main = "spear2h" } },
	},
	{
		path = "guardian",
		build = "guardian.loner",
		measure = "power",
		reportSession = "S89",
		reportWhy = "poza zasięgiem dźwigni S89: 0.106-0.110 (mace + shield): the mace base and Bonebreaker outside `tank`; the Guardian's nodes act on every weapon alike (owner: bases / traits)",
		sets = {
			{ main = "sword1h", offhand = "shield" },
			{ main = "saber1h", offhand = "shield" },
			{ main = "axe1h", offhand = "shield" },
			{ main = "mace1h", offhand = "shield" },
		},
	},
	{
		path = "standard",
		build = "standard.commander",
		measure = "power",
		sets = { { main = "sword1h", offhand = "shield" }, { main = "saber1h", offhand = "shield" } },
	},
	{
		path = "marksman",
		build = "marksman.kingslayer",
		measure = "dps",
		sets = { { main = "longbow", offhand = "quiver" }, { main = "heavycrossbow", offhand = "quiver" } },
	},
	{
		path = "trapper",
		build = "trapper.poacher",
		measure = "dps",
		sets = { { main = "crossbow", offhand = "quiver" }, { main = "bow", offhand = "quiver" } },
	},
	{
		path = "scout",
		build = "scout.partyHunter",
		measure = "power",
		sets = { { main = "shortbow", offhand = "quiver" }, { main = "bow", offhand = "quiver" } },
	},
	{
		path = "destroyer",
		build = "destroyer.destroyerExp",
		measure = "dps",
		reportSession = "S90",
		reportWhy = "poza zasięgiem dźwigni S90: staff / wand + orb spread 0.053 / 0.050 / 0.061 at 45 / 70 / 100 (the Spark and the Lens on the wand and Might on the staff weigh more as the S90 skills above rank 20 fall; owner: bases / traits, S88)",
		sets = { { main = "staff" }, { main = "wand", offhand = "orb" } },
	},
	{
		path = "arcanist",
		build = "arcanist.arcanistBoss",
		measure = "dps",
		sets = { { main = "runestaff" }, { main = "wand", offhand = "tome" } },
	},
	{
		path = "inquisitor",
		build = "inquisitor.solo",
		measure = "dps",
		sets = { { main = "mace1h", offhand = "shield" }, { main = "flail1h", offhand = "shield" } },
	},
	{
		path = "fortune",
		build = "fortune.plunder",
		measure = "power",
		reportSession = "S89",
		reportWhy = "poza zasięgiem dźwigni S89: 0.060-0.063 (flail 1.03, scepter 0.97-0.98 of the mace): Anointment heals nobody in MIX; the nodes act on every weapon alike (owner: bases / traits)",
		sets = {
			{ main = "mace1h", offhand = "relic" },
			{ main = "flail1h", offhand = "relic" },
			{ main = "scepter", offhand = "relic" },
		},
	},
	{
		path = "healer",
		build = "healer.dungeon",
		measure = "healer",
		reportSession = "S89",
		reportWhy = "poza zasięgiem dźwigni S89: 0.071-0.083 (holy staff 1.07-1.08 of scepter + shield): the staff's base in dungeon; the nodes act on every weapon alike (owner: bases)",
		sets = { { main = "scepter", offhand = "shield" }, { main = "holystaff" } },
	},
} :: { TypeSet }

-- D4 (STATY 9): the 12 named Mythics against the expected rolled Mythic of the same base and ilvl (Balance.namedPower,
-- the S84 F definition): power in MIX of the target classes (the main stat of the item; none: the classes that wear
-- it) within NAMED_BAND; every regular line at most NAMED_LINE_MAX x the Mythic top of ItemRoll.bonusRange at the
-- item's level (S134g: a named item has 3 lines and 2 fixed skill effects like a rolled Mythic; the effects are on
-- both sides, so the power compares the stats).
Balance.NAMED_BAND = { 1.00, 1.08 }
Balance.NAMED_LINE_MAX = 2.5
Balance.NAMED_TARGETS = {
	unique_grimrok_cleaver = { "Warrior" },
	unique_grimrok_fang = { "Hunter" },
	unique_grimrok_totem = { "Warrior", "Hunter", "Mage", "Cleric" },
	unique_morvane_shroud = { "Mage" },
	unique_morvane_scepter = { "Cleric" },
	unique_morvane_bow = { "Hunter" },
	unique_azgor_heart = { "Warrior", "Hunter", "Mage", "Cleric" },
	unique_azgor_staff = { "Mage" },
	unique_azgor_helm = { "Warrior", "Cleric" },
	unique_vaelgrath_fang = { "Warrior" },
	unique_vaelgrath_scale = { "Warrior", "Cleric" },
	unique_vaelgrath_eye = { "Mage" },
} :: { [string]: { string } }

-- S88 targets of the defence, the class checks, PvP and luck (STATY 5, 7, 8, 14; ROZWOJ 1 pt 31, 6.1, 6.3).
Balance.DEFENCE_TARGETS = {
	armor = { 0.15, 0.21 }, -- defMul 1 (STATY 7)
	armored = { 0.25, 0.33 }, -- defMul 1.8 (undead armored)
	mres = { 0.12, 0.17 }, -- mresMul 1 (S66)
	warded = { 0.21, 0.27 }, -- mresMul 1.8 (undead warded)
	dodgeTime = 1.10, -- B5: fight time against an agile kind / GENERIC
}
Balance.GUARD_EHP_MAX = 0.12 -- E1: both traits of the Guardian's set, EHP with / without both - 1
Balance.PVP_TARGETS = { ratio = 0.90, tickShare = 0.02, tick = { 0.59, 0.61 }, half = 0.55, stun = 0.02 }
Balance.FORTUNE_UNIQUES = { 1.20, 1.35 } -- G2: Uniques per hour with / without a full Priest of Fortune, profile K1

-- D3 (answer 23): family and class lines at level 100, ItemRoll.bonusRange: the Common range and the Mythic top.
Balance.LINE_TARGETS = {
	{ prefix = "vs_", over = "family", common = { 5, 12 }, mythicTop = 14.5 },
	{ prefix = "res_", over = "family", common = { 5, 11 }, mythicTop = 13.5 },
	{ prefix = "vs_", over = "class", common = { 4, 9 }, mythicTop = 11 },
	{ prefix = "res_", over = "class", common = { 4, 9 }, mythicTop = 11 },
} :: { { prefix: string, over: string, common: { number }, mythicTop: number } }

-- traitScale with all 24 traits off: the "bez cech" columns of G7, G8 and the trait table.
Balance.NO_TRAITS = {} :: { [string]: number }
for _, def in ItemTraits.list do
	Balance.NO_TRAITS[def.id] = 0
end

export type GearOpts = {
	ilvl: number?, -- default level - GEAR_GAP
	weaponIlvl: number?, -- weapon and off-hand (shop tiers), default ilvl
	rarity: number?,
	up: number?,
	weapon: string?, -- base type
	offhand: (string | false)?, -- base type, false = none (two-handed weapons never have one)
	jewellery: boolean?, -- default true
	armor: boolean?, -- default true
	bonuses: boolean?, -- expected random bonuses (default true)
	-- S84: strength of each trait (trait id -> 0 off .. 1 as in the game); nil = every trait as in the game
	traitScale: { [string]: number }?,
	element: string?, -- S84: element of a Mage weapon ("fire" | "ice" | "lightning"); nil = the model averages them
	-- S91: gracz z węzłami rzędów 1–3 (ROZWOJ 2.4): the key of a reference build ("berserker.fury"); its nodes trimmed
	-- to the level (SkillModel.character: Paths.pointsAt and Paths.canBuy, the main path from 20) add their
	-- Paths.passiveTotals (stats and hooks) to the convention player. nil = no nodes (bit for bit as before S91).
	nodes: string?,
}

local function tierId(baseType: string, ilvl: number): string
	return `{baseType}_{Items.generate.tierFor(math.max(1, ilvl))}`
end

-- Bonus pool an item of `defId` rolls from for `classId` (ItemRoll.bonusPool since S32, raw pool before).
local function poolFor(defId: string, classId: string?): { string }
	local roll: any = ItemRoll
	if roll.bonusPool then
		return roll.bonusPool(defId, classId)
	end
	local def = Items.get(defId) :: any
	return Bonuses.pools[def.bonusGroup or ""] or {}
end

-- S67: a family line works on the matching family in half of the fights (STATY 10: situational lines count half).
local FAMILY_MATCH = 0.5

-- Expected lines of one pool entry with chance `share`. S67: a family marker spreads half its middle value over each
-- family's variant (the model reads only the line of the monster's family); a class marker is worth 0 in PvE but
-- keeps its place in the pool.
local function expectedLines(out: { any }, id: string, ilvl: number, rarity: number, share: number)
	local param = Bonuses.params[id]
	if not param then
		table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * share })
	elseif param.over == "family" then
		for _, family in Families.ids do
			local variant = Bonuses.familyLine(param.prefix, family)
			local v = ItemRoll.rollBonusValue(variant, ilvl, rarity, 0.5) * share * FAMILY_MATCH
			table.insert(out, { stat = variant, v = v })
		end
	end
end

-- Expected bonus lines of one item: every pool entry gets its chance to be rolled x its middle value. S62: the chance
-- is ItemRoll.inclusion of the type-weighted pool, averaged over bonusMin..bonusMax (rng:int); before, count / #pool.
-- S84: memoised (a pure function of its arguments; nobody changes the returned list).
local expectedCache: { [string]: { any } } = {}
local expectedBonusesRaw: (string, number, number, string?) -> { any }
local function expectedBonuses(defId: string, ilvl: number, rarity: number, classId: string?): { any }
	local key = `{defId}|{ilvl}|{rarity}|{classId}`
	local cached = expectedCache[key]
	if not cached then
		cached = expectedBonusesRaw(defId, ilvl, rarity, classId)
		expectedCache[key] = cached
	end
	return cached
end
expectedBonusesRaw = function(defId: string, ilvl: number, rarity: number, classId: string?): { any }
	local rarityDef = Rarities.get(rarity)
	local out = {}
	local roll: any = ItemRoll
	if roll.poolWeights and rarityDef.bonusMax > 0 then
		local weights = roll.poolWeights(defId, classId)
		local share: { [string]: number } = {}
		local n = rarityDef.bonusMax - rarityDef.bonusMin + 1
		for k = rarityDef.bonusMin, rarityDef.bonusMax do
			for id, p in roll.inclusion(weights, k) do
				share[id] = (share[id] or 0) + p / n
			end
		end
		for _, id in poolFor(defId, classId) do
			expectedLines(out, id, ilvl, rarity, share[id] or 0)
		end
	else
		local pool = poolFor(defId, classId)
		local count = (rarityDef.bonusMin + rarityDef.bonusMax) / 2
		if count > 0 and #pool > 0 then
			local share = math.min(1, count / #pool)
			for _, id in pool do
				expectedLines(out, id, ilvl, rarity, share)
			end
		end
	end
	-- S134g: no legendary / mythic lines any more (Legendary and Mythic roll skill effects, valued in ItemScore only:
	-- Balance.rarityEdge); the power model sees their stats alone
	return out
end

local function makeItem(defId: string, ilvl: number, rarity: number, up: number, bonuses: { any }): any
	return {
		uid = "model",
		id = defId,
		rarity = rarity,
		ilvl = ilvl,
		bonuses = bonuses,
		up = up,
		bound = false,
		n = 1,
		rv = Rarities.RV,
	}
end

-- Item instances of a full set for `classId`.
function Balance.gear(classId: string, level: number, opts: GearOpts?): { any }
	local o: GearOpts = opts or {}
	local loadout = Balance.LOADOUT[classId]
	local ilvl = math.max(1, math.floor(o.ilvl or (level - Balance.GEAR_GAP)))
	local rarity = o.rarity or Rarities.COMMON
	local up = o.up or 0
	local withBonuses = o.bonuses ~= false
	local items = {}
	local function add(defId: string, level: number?)
		local l = level or ilvl
		local bonuses = if withBonuses then expectedBonuses(defId, l, rarity, classId) else {}
		table.insert(items, makeItem(defId, l, rarity, up, bonuses))
	end
	local weaponIlvl = math.max(1, math.floor(o.weaponIlvl or ilvl))
	local weaponType = o.weapon or loadout.weapon
	add(tierId(weaponType, weaponIlvl), weaponIlvl)
	if o.element then
		items[1].el = o.element -- S84: ItemRoll.elementOf reads it on elemental weapons only
	end
	local weaponBase = Bases.byType[weaponType] :: any
	local twoHanded = weaponBase.weapon(1).twoHanded
	local offhand = if o.offhand == false then nil else (o.offhand or loadout.offhand)
	if offhand and not twoHanded then
		add(tierId(offhand :: string, weaponIlvl), weaponIlvl)
	end
	if o.armor ~= false then
		for _, slot in Balance.ARMOR_SLOTS do
			add(tierId(`{slot}_{loadout.weight}`, ilvl))
		end
	end
	if o.jewellery ~= false then
		for _, slot in Balance.JEWELLERY do
			add(tierId(slot, ilvl))
		end
	end
	return items
end

-- Allocated stats: class start + every point into the main stat(s).
function Balance.statsFor(classId: string, level: number): any
	local class = Classes.get(classId) :: Classes.ClassDef
	local stats = table.clone(class.startStats) :: any
	local mains = class.mainStats
	for i = 1, (level - 1) * 5 do
		local id = mains[(i - 1) % #mains + 1]
		stats[id] += 1
	end
	return stats
end

export type Player = {
	classId: string,
	level: number,
	values: { [string]: number },
	hooks: { [string]: number },
	magic: boolean,
	-- S84: the live traits of the items (ItemRoll.trait through itemStats, scaled by GearOpts.traitScale; a trait
	-- at 0 is left out), the main weapon's base speed (Full Draw) and its element when the gear names it
	traits: { [string]: ItemRoll.TraitRoll }?,
	weaponSpeed: number?,
	element: string?,
}

-- `traitScale` (S84): strength of each trait; the grown part of a trait (ItemRoll.trait value in flat[stat] or
-- hooks[hook]) shrinks by (1 - scale) x value before StatCalc, fixed hooks (Swordplay's riposte, Parry's block) go
-- only at 0. nil or 1 leaves the item stats untouched (bit for bit).
-- S85 (B5): `extra` (tests/SkillModel) gives the allocated stats instead of Balance.statsFor, more StatCalc sources
-- after the gear (path passives, effects) and more hooks (path passives); without it nothing changes (bit for bit).
export type PlayerExtra = {
	stats: any?,
	sources: { StatCalc.Source }?,
	hooks: { [string]: number }?,
}

-- ItemRoll.itemStats for the model's items. S87: a rolled two-handed weapon's regular lines count x
-- Rarities.twoHandedBonusMul; the game rounds the product to the line's decimals, which would distort the model's
-- expected (fractional) line values, so here the lines are multiplied without rounding (same fields:
-- ItemRoll.isRegularLine, Rarities.twoHandedBonusMul). On-grid products give exactly ItemRoll.itemStats.
-- mirrors ItemRoll.itemStats
function Balance.itemStats(item: any): ItemRoll.ItemStats
	local stats = ItemRoll.itemStats(item)
	local def = Items.get(item.id) :: any
	if not (stats.weapon and stats.weapon.twoHanded) or (def and def.fixedBonuses) or #(item.bonuses or {}) == 0 then
		return stats
	end
	local bare = table.clone(item)
	bare.bonuses = {}
	local out = ItemRoll.itemStats(bare)
	for _, bonus in item.bonuses do
		local bonusDef = Bonuses.get(bonus.stat)
		if bonusDef then
			local v = bonus.v * (if ItemRoll.isRegularLine(bonus.stat) then Rarities.twoHandedBonusMul else 1)
			table.insert(out.bonuses, { id = bonus.stat, v = v, quality = 0.5 })
			if bonusDef.hook then
				out.hooks[bonusDef.hook] = (out.hooks[bonusDef.hook] or 0) + v
			elseif bonusDef.stat then
				local target = if bonusDef.mode == "pct" then out.pct else out.flat
				target[bonusDef.stat] = (target[bonusDef.stat] or 0) + v
			end
		end
	end
	return out
end

function Balance.playerFromItems(
	classId: string,
	level: number,
	items: { any },
	traitScale: { [string]: number }?,
	extra: PlayerExtra?
): Player
	local flat: { [string]: number } = {}
	local pct: { [string]: number } = {}
	local hooks: { [string]: number } = {}
	local weapon: any = nil
	local traits: { [string]: ItemRoll.TraitRoll } = {}
	local element: string? = nil
	for _, item in items do
		local stats = Balance.itemStats(item)
		local trait = stats.trait
		local scale = if trait and traitScale then traitScale[trait.id] else nil
		if trait and scale and scale ~= 1 then
			local def = trait.def
			local cut = (1 - scale) * trait.value
			if def.kind == "stat" and def.stat then
				stats.flat[def.stat] = (stats.flat[def.stat] or 0) - cut
			elseif def.hook then
				stats.hooks[def.hook] = (stats.hooks[def.hook] or 0) - cut
			end
			if scale == 0 then
				for hookId, v in def.fixedHooks or {} do
					stats.hooks[hookId] = (stats.hooks[hookId] or 0) - v
				end
			end
			if scale ~= 0 then
				local copy = table.clone(trait)
				copy.value = trait.value * scale
				copy.power = trait.power * scale
				traits[trait.id] = copy
			end
		elseif trait then
			traits[trait.id] = trait
		end
		for id, v in stats.flat do
			flat[id] = (flat[id] or 0) + v
		end
		for id, v in stats.pct do
			pct[id] = (pct[id] or 0) + v
		end
		for id, v in stats.hooks do
			hooks[id] = (hooks[id] or 0) + v
		end
		if stats.weapon then
			weapon = stats.weapon
			element = if item.el then stats.weapon.element else nil
		end
	end
	local class = Classes.get(classId) :: Classes.ClassDef
	if not weapon then
		local unarmed = Stats.Formula.unarmed
		weapon = { dmg = unarmed.dmg, mdmg = unarmed.mdmg, speed = unarmed.speed, ranged = class.basicAttack.ranged }
	end
	local sources: { StatCalc.Source } = { { key = "gear", flat = flat, pct = pct } }
	if extra then
		for _, source in extra.sources or {} do
			table.insert(sources, source)
		end
		for id, v in extra.hooks or {} do
			hooks[id] = (hooks[id] or 0) + v
		end
	end
	local result = StatCalc.compute({
		level = level,
		stats = if extra and extra.stats then extra.stats else Balance.statsFor(classId, level),
		sources = sources,
		weapon = { dmg = weapon.dmg, mdmg = weapon.mdmg, speed = weapon.speed, ranged = weapon.ranged },
	})
	return {
		classId = classId,
		level = level,
		values = result.values,
		hooks = hooks,
		magic = class.basicAttack.kind == "magic",
		traits = traits,
		weaponSpeed = weapon.speed,
		element = element,
	}
end

function Balance.player(classId: string, level: number, opts: GearOpts?): Player
	local items = Balance.gear(classId, level, opts)
	if opts and opts.nodes then
		return Balance.playerFromItems(classId, level, items, opts.traitScale, Balance.nodesExtra(classId, level, opts))
	end
	return Balance.playerFromItems(classId, level, items, opts and opts.traitScale)
end

-- S91: gracz z węzłami rzędów 1–3 (ROZWOJ 2.4). The reference build `opts.nodes` trimmed to `level` by
-- tests/SkillModel.character (required here lazily: SkillModel requires this module), its Paths.passiveTotals with
-- the convention weapons; the allocated stats stay Balance.statsFor (the convention). Hooks that only act on skills
-- change nothing in FightSim.
function Balance.trimmedCharacter(classId: string, level: number, buildKey: string): any
	local SkillModel = (require :: any)("./SkillModel")
	local build = SkillModel.build(buildKey, classId)
	assert(build, `Balance: unknown build {buildKey} of {classId}`)
	return SkillModel.character(build, level).character
end

function Balance.nodesExtra(classId: string, level: number, opts: GearOpts): PlayerExtra
	local loadout = Balance.LOADOUT[classId]
	local main = opts.weapon or loadout.weapon
	local twoHanded = (Bases.byType[main] :: any).weapon(1).twoHanded
	local offhand = if opts.offhand == false or twoHanded then nil else (opts.offhand or loadout.offhand)
	local character = Balance.trimmedCharacter(classId, level, opts.nodes :: string)
	local passives = Paths.passiveTotals(character, { main = main, offhand = offhand :: string? })
	return {
		sources = { { key = "source.passives", flat = passives.flat, pct = passives.pct } },
		hooks = passives.hooks,
	}
end

export type Variant = { key: string, nodes: string?, set: string }

-- S91: the combat build of each class (SkillModel.R4_CLASS_BUILDS): the nodes of the Elite II teams and of the
-- Grimrok teams in the variant with nodes.
Balance.COMBAT_BUILD = {
	Warrior = "berserker.fury",
	Hunter = "marksman.kingslayer",
	Mage = "arcanist.arcanistBoss",
	Cleric = "inquisitor.solo",
} :: { [string]: string }

local variantsCache: { [string]: { Variant } } = {}
-- S91 (B1): the player variants of the convention at `level`: "bez węzłów" first, then every reference build of the
-- class trimmed to the level; builds that buy the same nodes at this level are counted once (the first key).
function Balance.buildsAt(classId: string, level: number): { Variant }
	local cacheKey = `{classId}|{level}`
	local cached = variantsCache[cacheKey]
	if cached then
		return cached
	end
	local out: { Variant } = { { key = "bez węzłów", nodes = nil, set = "" } }
	local seen: { [string]: boolean } = { [""] = true }
	local SkillModel = (require :: any)("./SkillModel")
	for _, build in SkillModel.builds(classId) do
		if build.base then
			continue
		end
		local character = SkillModel.character(build, level).character
		local ids: { string } = {}
		for id, rank in character.path.nodes do
			if rank > 0 then
				table.insert(ids, `{id}={rank}`)
			end
		end
		table.sort(ids)
		-- S138: no main path any more; the key keeps the build's own path from the old main path level (row 3, S57-S137)
		-- so the 1-20 tables keep their rows
		local own = if build.pathId and level >= PathData.ROWS[PathData.DIP_ROWS + 1].level then build.pathId else "-"
		local set = own .. ":" .. table.concat(ids, ",")
		if #ids == 0 then
			set = ""
		end
		if not seen[set] then
			seen[set] = true
			table.insert(out, { key = build.key, nodes = build.key, set = set })
		end
	end
	variantsCache[cacheKey] = out
	return out
end

-- Monsters ------------------------------------------------------------------------------------------------

Balance.FAMILY_MATCH = FAMILY_MATCH
-- S67: a family so family lines count; in the model every family gives the same (FAMILY_MATCH spreads the lines).
Balance.GENERIC = { hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee", family = Families.ids[1] }

-- Stats of a monster kind (Data/Monsters id or a kind table) at spawner level `level`.
function Balance.monster(kind: any, level: number, variant: string?, groupSize: number?): any
	local def = if type(kind) == "string" then Monsters.get(kind) else kind
	assert(def, `Balance: unknown monster {kind}`)
	return (MonsterStats.compute :: any)(def, level, variant or "normal", groupSize)
end

-- Damage of the player's basic attacks + skills against a monster, per second (Logic/FightSim).
function Balance.dps(p: Player, m: any): number
	return FightSim.dps(p :: any, m, Balance.SKILL_DPS)
end

-- Damage of one monster attack (multiplier `mul`) against the player, expected, after armour / resistance.
function Balance.hit(m: any, p: Player, mul: number?, kind: string?, canDodge: boolean?, canCrit: boolean?): number
	return FightSim.hit(m, p :: any, mul, kind, canDodge, canCrit)
end

export type Fight = FightSim.Fight

-- One player against members killed one by one; every living member attacks.
function Balance.groupFight(p: Player, members: { any }): Fight
	return FightSim.groupFight(p :: any, members, Balance.SKILL_DPS)
end

function Balance.duel(p: Player, m: any): Fight
	return Balance.groupFight(p, { m })
end

-- Group weights of Logic/AreaSpawns (1-4 members).
function Balance.groupWeights(): { [number]: number }
	return AreaSpawns.GROUP_SIZE_WEIGHTS
end

-- A group of `n` monsters of `kind` at `level`.
function Balance.group(kind: any, level: number, n: number): { any }
	local def = if type(kind) == "string" then Monsters.get(kind) else kind
	return FightSim.group(def, level, n)
end

-- Expected fight over group sizes (weights of AreaSpawns): HP lost and seconds per fight, members per fight.
function Balance.expectedGroup(
	p: Player,
	kind: any,
	level: number
): { hpLost: number, seconds: number, members: number, bySize: { Fight } }
	local def = if type(kind) == "string" then Monsters.get(kind) else kind
	return FightSim.expectedGroup(p :: any, def, level, Balance.SKILL_DPS)
end

-- Elite (cave, spawner level = player level, variant adds its levels).
function Balance.elite(p: Player, kind: any, level: number): Fight
	return Balance.duel(p, Balance.monster(kind, level, "elite"))
end

-- S134e: one lethal kit blow (Crushing Blow) of monster `m` on `p`: x the ability's damage and its gap ramp
-- (Logic/MonsterCast.lethalMul), never a crit, no dodge (a red zone).
function Balance.lethalHit(m: any, p: Player, ability: any): number
	return Balance.hit(
		m,
		p,
		ability.damage * MonsterCast.lethalMul(ability, m.level, p.level),
		ability.damageKind,
		false,
		ability.canCrit
	)
end

-- S134e: options of the Elite II fights: `avoidHit` = share of the `avoid` blows of the kit that land (default 0:
-- dodged, like the bosses 2.0 of S134).
export type Elite2Opts = { avoidHit: number? }

-- Elite II with its ability, against `players` copies of the team (damage on the first one, the tank). S134e: the kit
-- (Data/MonsterAbilities.KITS.elite2) in a standing fight: Crushing Blow x avoidHit (default 0); Pounce and the throw
-- never come (the tank stays in reach: they answer a fleeing target, Balance.elite2Kite).
function Balance.elite2(team: { Player }, kind: string, level: number, opts: Elite2Opts?): Fight
	local def = Monsters.get(kind) :: any
	local m = table.clone(Balance.monster(def, level, "elite2"))
	m.ability = if def.ability then MonsterAbilities.get(def.ability) else nil
	local tank = team[1]
	local dps = 0
	for _, p in team do
		dps += Balance.dps(p, m)
	end
	local seconds = m.maxHp / dps
	local lost = Balance.hit(m, tank) * (1 + seconds / m.attackInterval)
	if m.ability then
		lost += Balance.hit(m, tank, m.ability.damage, m.ability.damageKind, false) * Balance.SPECIAL_HIT * seconds / m.ability.cooldown
	end
	local avoidHit = if opts then opts.avoidHit or 0 else 0
	if avoidHit > 0 then
		local crush = MonsterAbilities.get("crush") :: any
		lost += Balance.lethalHit(m, tank, crush) * avoidHit * seconds / (crush.cooldown + crush.windup)
	end
	lost -= (tank.values.hpRegenCombat or 0) * seconds
	return { seconds = seconds, hpLost = math.max(0, lost) / tank.values.maxHp, playerHp = tank.values.maxHp }
end

-- S134e (C1): assumptions of the kiting model (not game numbers): the share of the time a kiting ranged player
-- shoots, and the seconds of regular blows it takes after each Pounce before it runs again.
Balance.KITE_UPTIME = 0.6
Balance.PIN_SECONDS = 2

export type KiteFight = {
	seconds: number,
	-- share of the max HP: the bigger of the deficit over the fight (after in-combat regeneration and the potions) and
	-- the biggest loss between two potions (burst)
	hpLost: number,
	sustained: number, -- the deficit over the fight
	burst: number, -- the biggest loss inside one potion interval
	throwHit: number, -- one throw / max HP
	crushHit: number, -- one Crushing Blow not dodged / max HP
	dies: boolean,
	throws: number,
	pounces: number,
	crushes: number,
}

-- S134e (C1): one ranged player keeping an Elite II (spawner `level`) at a distance: shoots `KITE_UPTIME` of the time,
-- takes the throws (regular ranged blows: dodge, block, ranged protection; x MonsterCast.throwMul, the gap ramp) every
-- attack interval x intervalMul while it runs, after each Pounce (x SPECIAL_HIT, every windup + cooldown)
-- PIN_SECONDS of regular melee blows, Crushing Blow x avoidHit (default 0: it dodges them all). Healing: in-combat
-- regeneration and the best allowed potion at its interval, at most the max HP a drink (a potion never heals past it;
-- Balance.potionHps counts the whole potion: up to twice the HP of a Mage from 45). It dies when the deficit over the
-- fight passes the max HP or when one potion interval holds more than it (the hits it takes before it may drink
-- again). Its own ability stays out (an area around itself or a small circle: it does not reach a kiting target).
function Balance.elite2Kite(p: Player, kind: string, level: number, opts: Elite2Opts?): KiteFight
	local def = Monsters.get(kind) :: any
	local m = table.clone(Balance.monster(def, level, "elite2"))
	local kit = MonsterAbilities.KITS.elite2
	local crush = MonsterAbilities.get("crush") :: any
	local pounce = MonsterAbilities.get("pounce") :: any
	local throw = kit.throw :: any
	local avoidHit = if opts then opts.avoidHit or 0 else 0
	local maxHp = p.values.maxHp
	local seconds = m.maxHp / (Balance.dps(p, m) * Balance.KITE_UPTIME)
	local pounces = seconds / (pounce.cooldown + pounce.windup)
	local crushes = seconds / (crush.cooldown + crush.windup)
	-- the throws fill the time it neither casts nor holds the player after a Pounce
	local busy = pounces * (pounce.windup + Balance.PIN_SECONDS) + crushes * crush.windup
	local running = math.max(0, seconds - busy)
	local throwEvery = m.attackInterval * throw.intervalMul
	local throws = running / throwEvery
	local ranged = table.clone(m)
	ranged.delivery = "ranged"
	local melee = table.clone(m)
	melee.delivery = "melee"
	local throwHit = Balance.hit(ranged, p, MonsterCast.throwMul(throw, m.level, p.level))
	local pinHits = Balance.PIN_SECONDS / m.attackInterval
	local pinHit = Balance.hit(melee, p)
	local pounceHit = Balance.hit(m, p, pounce.damage, pounce.damageKind, false) * Balance.SPECIAL_HIT
	local lost = throwHit * throws + pinHit * pinHits * pounces + pounceHit * pounces
	local crushHit = Balance.lethalHit(m, p, crush)
	lost += crushHit * avoidHit * crushes
	-- potions: the best allowed one, at most the max HP a drink
	local best = 0
	for _, potion in Balance.hpPotions() do
		if (potion.level or 1) <= p.level then
			best = math.max(best, potion.heal)
		end
	end
	local interval = Potions.interval(p.level)
	local heal = (p.values.hpRegenCombat or 0) + math.min(best, maxHp) / interval
	local sustained = math.max(0, lost - heal * seconds) / maxHp
	-- between two potions: the throws of one interval (at least the one that lands on full HP), or a Pounce with its
	-- pin
	local inWindow = math.max(1, math.floor(interval / throwEvery))
	local burst = math.max(throwHit * inWindow, pounceHit + pinHit * pinHits) / maxHp
	local hpLost = math.max(sustained, burst)
	local crushShare = crushHit / maxHp
	return {
		seconds = seconds,
		hpLost = hpLost,
		sustained = sustained,
		burst = burst,
		throwHit = throwHit / maxHp,
		crushHit = crushShare,
		dies = hpLost > 1 or (avoidHit > 0 and crushShare >= 1),
		throws = throws,
		pounces = pounces,
		crushes = crushes,
	}
end

-- Grimrok (or another boss): fight length for `team`, the biggest single hit on each team member and the tank's
-- HP lost per minute from basic attacks + the threat attacks. S134: the HP never scales with the party, and the
-- biggest hit is the biggest attack that cannot be dodged (no `avoid`, no mechanic: Balance.bossFight has those).
function Balance.boss(bossId: string, team: { Player }): any
	local def = Bosses.byId[bossId] :: any
	local kind = {
		hpMul = BossScaling.hpMultiplier() * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		mresMul = def.mresMul, -- S66
		family = def.family, -- S66
		speed = def.speed,
		attack = def.attack,
		damageKind = def.damageKind,
	}
	local m = Balance.monster(kind, def.level, "boss")
	local dps = 0
	for _, p in team do
		dps += Balance.dps(p, m) * Balance.BOSS_UPTIME
	end
	local seconds = m.maxHp / dps
	local biggest = {}
	local biggestMul = 1
	for _, attack in def.attacks do
		if not attack.avoid and attack.mechanic == nil then
			biggestMul = math.max(biggestMul, attack.damage)
		end
	end
	for i, p in team do
		biggest[i] = {
			classId = p.classId,
			hit = Balance.hit(m, p, biggestMul, nil, false) * Combat.randomMax,
			share = Balance.hit(m, p, biggestMul, nil, false) * Combat.randomMax / p.values.maxHp,
			basic = Balance.hit(m, p) / p.values.maxHp,
		}
	end
	local tank = team[1]
	local tankPerSecond = Balance.hit(m, tank) / m.attackInterval
	for _, attack in def.attacks do
		if attack.target == "threat" then
			tankPerSecond += Balance.hit(m, tank, attack.damage, nil, false) * Balance.SPECIAL_HIT / attack.cooldown
		end
	end
	return {
		hp = m.maxHp,
		attack = m.attack,
		seconds = seconds,
		biggest = biggest,
		biggestMul = biggestMul,
		tankHpPerMinute = tankPerSecond * 60 / tank.values.maxHp,
	}
end

-- S84: `traits` = the trait model (traitTerms) in `situation` (Balance.SITUATIONS, default "single"); without opts
-- the S32 convention as before (stat traits already in the stats, no hook or effect trait).
export type PowerOpts = { traits: boolean?, situation: string? }

-- Character power: sqrt(DPS x effective HP) against a generic monster of the player's level.
function Balance.power(p: Player, level: number?, opts: PowerOpts?): number
	if opts and opts.traits then
		return Balance.situationPower(p, Balance.situationCtx(p, opts.situation or "single", level))
	end
	-- S87: the same number as FightSim.power with SKILL_DPS (/balance)
	return FightSim.power(p :: any, Balance.monster(Balance.GENERIC, level or p.level), Balance.SKILL_DPS)
end

-- Power of a full set of `rarity` relative to Common (same ilvl): 0.12 = +12 %.
function Balance.rarityGain(classId: string, level: number, rarity: number): number
	local base = Balance.power(Balance.player(classId, level))
	local better = Balance.power(Balance.player(classId, level, { rarity = rarity }))
	return better / base - 1
end

-- DPS x survivability of a weapon choice relative to the class's default loadout.
function Balance.weaponScore(classId: string, level: number, weapon: string, offhand: (string | false)?): number
	local p = Balance.player(classId, level, { weapon = weapon, offhand = offhand })
	return Balance.power(p)
end

-- Reward of one kill ---------------------------------------------------------------------------------------

-- Kind factor for EXP and gold (MonsterStats.kindReward since S32, 1 before).
function Balance.kindReward(kind: any): number
	local stats: any = MonsterStats
	if stats.kindReward then
		return stats.kindReward(if type(kind) == "string" then Monsters.get(kind) else kind)
	end
	return 1
end

-- S98 (C4): true = the model without the quest budget compensation (build/ comparisons and questbudget.spec only).
Balance.QUEST_BUDGET_OFF = false

-- S98: the quest budget multiplier of a kill credited to a character of `playerLevel` (CombatService.reward; not
-- for a dungeon boss).
function Balance.budgetMul(playerLevel: number, variant: string?): number
	if Balance.QUEST_BUDGET_OFF or (variant or "normal") == "boss" then
		return 1
	end
	return QuestBudget.monsterExpMul(playerLevel)
end

function Balance.killExp(playerLevel: number, kind: any, monsterLevel: number, variant: string?): number
	local base = Exp.monsterExp(monsterLevel, (variant or "normal") :: any)
	local mul = if (variant or "normal") == "boss" then 1 else Balance.kindReward(kind)
	return base * mul * Exp.levelDiffMultiplier(playerLevel, monsterLevel) * Balance.budgetMul(playerLevel, variant)
end

function Balance.killGold(playerLevel: number, kind: any, monsterLevel: number, variant: string?): number
	local stats: any = MonsterStats
	local v = variant or "normal"
	local gold = MonsterStats.gold(monsterLevel, v, 0.5)
	if stats.goldLevelMultiplier then
		gold *= stats.goldLevelMultiplier(playerLevel, monsterLevel)
	end
	if v ~= "boss" then
		gold *= Balance.kindReward(kind)
	end
	return gold
end

-- Expected merchant value of the items and materials of one kill (normal / elite / elite2).
function Balance.dropValue(monsterLevel: number, variant: string, partId: string?): number
	local drops = Rarities.itemDrops[variant] or Rarities.itemDrops.normal
	local count = drops.chance * ((drops.min + drops.max) / 2 + (drops.extra or 0))
	local weights = Rarities.dropWeights[variant] or Rarities.dropWeights.normal
	local slots = LootTables.byId.wolf.slotWeights
	local wTotal, slotTotal = 0, 0
	for _, w in weights do
		wTotal += w
	end
	for _, w in slots do
		slotTotal += w
	end
	local ilvl = Balance.dropIlvl(monsterLevel, variant)
	local value = 0
	for rarity, w in weights do
		for slot, sw in slots do
			local def = Items.get(
				tierId(
					if slot == "weapon"
						then "sword1h"
						elseif slot == "offhand" then "shield"
						elseif slot == "ring" or slot == "necklace" or slot == "talisman" then slot
						else `{slot}_heavy`,
					ilvl
				)
			) :: any
			value += (w / wTotal) * (sw / slotTotal) * ItemValue.equipment(def, ilvl, rarity, 0)
		end
	end
	local materials = 0
	local tableDef = LootTables.byId[partId or "wolf"] or LootTables.byId.wolf
	local list = table.clone(tableDef.materials)
	for _, mat in tableDef.variantMaterials[variant] or {} do
		table.insert(list, mat)
	end
	for _, mat in list do
		local def = Items.get(mat.id) :: any
		if def then
			materials += mat.chance * (mat.min + mat.max) / 2 * def.price
		end
	end
	return count * value + materials, count
end

-- Average item level of a drop (ItemRoll.dropLevelRange since S32: level - 0..2; before: level +-2).
function Balance.dropIlvl(monsterLevel: number, variant: string?): number
	local roll: any = ItemRoll
	if roll.dropLevelRange then
		local low, high = roll.dropLevelRange(monsterLevel, variant)
		return (low + high) / 2
	end
	local add = if variant == "elite" then 2 elseif variant == "elite2" then 4 else 0
	return monsterLevel + add
end

-- Share of normal drops a player of `level` can wear (monster level = player level).
function Balance.wearableShare(level: number): number
	local roll: any = ItemRoll
	if roll.dropLevelRange then
		local low, high = roll.dropLevelRange(level, "normal")
		local ok = 0
		for l = low, high do
			ok += if l <= level then 1 else 0
		end
		return ok / (high - low + 1)
	end
	local ok = 0
	for d = -2, 2 do
		ok += if math.max(1, level + d) <= level then 1 else 0
	end
	return ok / 5
end

-- Pace and economy -----------------------------------------------------------------------------------------

-- Share of the side quests a player does on the way (the main story counts in full).
Balance.SIDE_SHARE = 0.5

-- Quest EXP and gold of levels 1..19 (main story + SIDE_SHARE of the Meadows side quests), spread over the levels
-- in proportion to the EXP each level needs (quests are done along the way, not all at their own level).
-- S98: the boss quests below 20 count in full (the same quest EXP as the window model).
function Balance.questRewards(level: number): (number, number)
	local exp, gold, need = 0, 0, 0
	-- S99: the hunting contracts below 20 too (questsAt counts them on their level; their kills are grinding kills,
	-- so questKills leaves them out)
	local lists = {
		{ Quests.Main.list, 1 },
		{ Quests.Side.list, Balance.SIDE_SHARE },
		{ Quests.Boss.list, 1 },
		{ Quests.Contracts.list, 1 },
	}
	for _, entry in lists do
		for _, q in entry[1] :: any do
			if q.level < 20 then
				exp += (q.reward.exp or 0) * entry[2]
				gold += (q.reward.gold or 0) * entry[2]
			end
		end
	end
	for l = 1, 19 do
		need += Exp.expToNext(l)
	end
	local share = Exp.expToNext(level) / need
	return exp * share, gold * share
end

-- Monsters killed for quest objectives at `level` (main story + SIDE_SHARE of side quests), spread like the EXP.
function Balance.questKills(level: number): number
	local kills, need = 0, 0
	for _, entry in { { Quests.Main.list, 1 }, { Quests.Side.list, Balance.SIDE_SHARE } } do
		for _, q in entry[1] :: any do
			if q.level < 20 then
				for _, o in q.objectives do
					if o.type == "kill" then
						kills += o.n * entry[2]
					end
				end
			end
		end
	end
	for l = 1, 19 do
		need += Exp.expToNext(l)
	end
	return kills * Exp.expToNext(level) / need
end

-- Expected items of `rarity` per kill of `variant` that the killer's class can use (class bias of LootTables,
-- jewellery counts for everyone).
function Balance.itemsPerKill(variant: string, rarity: number): number
	local drops = Rarities.itemDrops[variant] or Rarities.itemDrops.normal
	local count = drops.chance * ((drops.min + drops.max) / 2 + (drops.extra or 0))
	local weights = Rarities.dropWeights[variant] or Rarities.dropWeights.normal
	local total = 0
	for _, w in weights do
		total += w
	end
	local bias = LootTables.byId.wolf.classBias
	return count * (weights[rarity] or 0) / total * (bias + (1 - bias) * 0.25)
end

-- Seconds per Elite kill in a cave at `level` (fight + rest + walk), for `classId`.
function Balance.eliteCadence(classId: string, level: number): number
	local p = Balance.player(classId, level)
	local f = Balance.elite(p, Balance.GENERIC, level)
	return f.seconds + f.hpLost / (Stats.Formula.hpRegenPct / 100) + Balance.BREAK + Balance.WALK
end

-- The usual monster kind of a level on the Meadows (for EXP, gold and parts).
function Balance.kindAt(level: number): string
	local best, bestMid = "wolf", math.huge
	for _, def in Monsters.list do
		if def.region == 1 and not def.passive then
			if level >= def.levels.min and level <= def.levels.max then
				local mid = math.abs((def.levels.min + def.levels.max) / 2 - level)
				if mid < bestMid then
					best, bestMid = def.id, mid
				end
			end
		end
	end
	return best
end

export type Pace = {
	level: number,
	kind: string,
	expPerKill: number,
	goldPerKill: number,
	dropPerKill: number,
	secondsPerKill: number,
	kills: number,
	hours: number,
	expPerHour: number,
	goldPerHour: number,
	questGold: number,
	questExp: number,
	hpLostPerFight: number,
	restShare: number,
}

-- Grinding groups of the level's kind at the player's level (classId's fight), with rests.
function Balance.pace(classId: string, level: number): Pace
	local kind = Balance.kindAt(level)
	local p = Balance.player(classId, level)
	local fight = Balance.expectedGroup(p, kind, level)
	local regen = Stats.Formula.hpRegenPct / 100
	local rest = fight.hpLost / regen
	local perFight = fight.seconds + rest + Balance.BREAK + Balance.WALK
	local secondsPerKill = perFight / fight.members
	local expPerKill = Balance.killExp(level, kind, level)
	local goldPerKill = Balance.killGold(level, kind, level)
	local dropPerKill = Balance.dropValue(level, "normal", kind)
	local questExp, questGold = Balance.questRewards(level)
	local need = math.max(0, Exp.expToNext(level) - questExp)
	local kills = need / expPerKill
	local hours = kills * secondsPerKill / 3600
	return {
		level = level,
		kind = kind,
		expPerKill = expPerKill,
		goldPerKill = goldPerKill,
		dropPerKill = dropPerKill,
		secondsPerKill = secondsPerKill,
		kills = kills,
		hours = hours,
		expPerHour = expPerKill * 3600 / secondsPerKill,
		goldPerHour = goldPerKill * 3600 / secondsPerKill,
		questGold = questGold,
		questExp = questExp,
		hpLostPerFight = fight.hpLost,
		restShare = rest / perFight,
	}
end

-- Expected gold of upgrading an item of `ilvl` from +0 to +`to` (one success per step, failures repeat the step
-- with the item kept by a protection scroll counted as the same attempt).
function Balance.upgradeGold(ilvl: number, to: number): number
	local item = makeItem("sword1h_1", ilvl, Rarities.COMMON, 0, {})
	local total = 0
	for n = 1, to do
		total += Upgrade.cost(item, n).gold / (Upgrade.chance(n) / 100)
	end
	return total
end

-- Potion gold per kill: the HP lost above REST_LIMIT of a fight is healed with the cheapest fitting potion.
Balance.POTION_ABOVE = 0.6
function Balance.potionGold(classId: string, level: number): number
	local kind = Balance.kindAt(level)
	local p = Balance.player(classId, level)
	local fight = Balance.expectedGroup(p, kind, level)
	local weights = Balance.groupWeights()
	local total, gold = 0, 0
	local potions = {}
	for q = 1, 5 do
		local def = Items.get(`potion_hp_{q}`) :: any
		table.insert(potions, { heal = def.use.amount, price = def.buyPrice })
	end
	for n, w in weights do
		local over = math.max(0, fight.bySize[n].hpLost - Balance.POTION_ABOVE) * p.values.maxHp
		local cost = 0
		if over > 0 then
			local best = math.huge
			for _, potion in potions do
				best = math.min(best, math.ceil(over / potion.heal) * potion.price)
			end
			cost = best
		end
		total += w
		gold += w * cost
	end
	return gold / total / fight.members
end

export type Economy = {
	rows: { any },
	killGold: number,
	dropGold: number,
	questGold: number,
	potionGold: number,
	upgradeGold: number,
}

-- Gold budget from level 1 to 20 for `classId`.
function Balance.economy(classId: string, toLevel: number?): Economy
	local rows = {}
	local killGold, dropGold, questGold, potionGold, upgradeGold = 0, 0, 0, 0, 0
	for level = 1, (toLevel or 20) - 1 do
		local pace = Balance.pace(classId, level)
		local kills = pace.kills
		local income = kills * (pace.goldPerKill + pace.dropPerKill) + pace.questGold
		local potions = kills * Balance.potionGold(classId, level)
		local ilvl = math.max(1, level - Balance.GEAR_GAP)
		local up3 = Balance.upgradeGold(ilvl, 3)
		killGold += kills * pace.goldPerKill
		dropGold += kills * pace.dropPerKill
		questGold += pace.questGold
		potionGold += potions
		upgradeGold += up3
		table.insert(rows, {
			level = level,
			pace = pace,
			income = income,
			kills = kills * pace.goldPerKill,
			drops = kills * pace.dropPerKill,
			potions = potions,
			up1 = Balance.upgradeGold(ilvl, 1),
			up3 = up3,
			up9 = Balance.upgradeGold(ilvl, 9),
		})
	end
	return {
		rows = rows,
		killGold = killGold,
		dropGold = dropGold,
		questGold = questGold,
		potionGold = potionGold,
		upgradeGold = upgradeGold,
	}
end

-- Hunting ground profiles (S33) ----------------------------------------------------------------------------

-- An hour in a hunting ground of `profileId` (nil = none) at the player's level against `kind` (default: the
-- level's usual Meadows kind), Logic/AreaRates.
function Balance.areaRates(classId: string, level: number, profileId: string?, kind: any?): AreaRates.Rates
	local def = if kind == nil
		then Monsters.get(Balance.kindAt(level))
		elseif type(kind) == "string" then Monsters.get(kind)
		else kind
	return AreaRates.rates(Balance.player(classId, level) :: any, def, level, profileId, Balance.SKILL_DPS)
end

-- World model 1-100 (S83) ----------------------------------------------------------------------------------------
-- Next to the S32 functions (which keep computing the 1-20 tables and the fixture): regions, quests on their own
-- level, pace with carried EXP, potions on the S54 interval, the class variety bonus, economy, cave Elites from the
-- real spawners and the bosses with their real attack schedule. Expected values, no randomness.

Balance.REGION_IDS = { "meadows", "duskwood", "ashen", "frostpeak" }
Balance.BANDS = { { 1, 20 }, { 20, 45 }, { 45, 70 }, { 70, 100 } }

-- Region (1-4) of a character level: below 20 the Meadows, below 45 Duskwood, below 70 the Ashen Wastes.
function Balance.regionAt(level: number): number
	return if level < 20 then 1 elseif level < 45 then 2 elseif level < 70 then 3 else 4
end

-- S87 C4: LevelCurves.dropFactor of the region of regionAt(level), the factor Loot.rollMonsterLoot and
-- AreaRates.rates pass for that region's monsters (dropsPerHour, materialSupply, dismantlePerItem read it).
function Balance.dropFactorAt(level: number): number
	return LevelCurves.dropFactor(Balance.REGION_IDS[Balance.regionAt(level)])
end

local playerCache: { [string]: Player } = {}
-- Balance.player with the default gear, cached (the world model asks for the same players hundreds of times).
function Balance.cachedPlayer(classId: string, level: number): Player
	local key = `{classId}:{level}`
	local p = playerCache[key]
	if not p then
		p = Balance.player(classId, level)
		playerCache[key] = p
	end
	return p
end

local function kindDef(kind: any): any
	return if type(kind) == "string" then Monsters.get(kind) else kind
end

local outdoorCache: { [number]: { string } } = {}
-- Kinds of the hunting grounds of region r (Areas.byMap, no passive kinds), in area order.
function Balance.outdoorKinds(r: number): { string }
	local cached = outdoorCache[r]
	if cached then
		return cached
	end
	local out: { string } = {}
	for _, area in Areas.byMap[Balance.REGION_IDS[r]].areas do
		for _, id in area.kinds do
			local def = Monsters.get(id)
			if def and not def.passive and def.region == r and not table.find(out, id) then
				table.insert(out, id)
			end
		end
	end
	outdoorCache[r] = out
	return out
end

-- The usual kind of a level: Balance.kindAt (S32) below 20; above, the hunting-ground kind of regionAt(level)
-- whose level range holds the level with its middle closest (diag_economy kindAt); none holds it -> the nearest range.
function Balance.kindAtRegion(level: number): string
	if level < 20 then
		return Balance.kindAt(level)
	end
	local best, bestGap, bestMid = "", math.huge, math.huge
	for _, id in Balance.outdoorKinds(Balance.regionAt(level)) do
		local def = Monsters.get(id) :: any
		local gap = math.max(def.levels.min - level, level - def.levels.max, 0)
		local mid = math.abs((def.levels.min + def.levels.max) / 2 - level)
		if gap < bestGap or (gap == bestGap and mid < bestMid) then
			best, bestGap, bestMid = id, gap, mid
		end
	end
	return best
end

export type KindRate = {
	kind: string,
	level: number,
	expPerSecond: number, -- EXP per second of fighting vs GENERIC (Warrior 1 on 1, middle level of the kind)
	hpPerExp: number, -- (HP lost / EXP per kill) / the same of GENERIC at that level, relative to the region mean
	hpPerExpGeneric: number, -- S92: the same against GENERIC only (the S54 draft's 1.20 threshold, report)
	caster: boolean, -- ranged magic attacker
	passive: boolean,
}

-- Every kind of the region (also the cave-only ones), Warrior 1 on 1 at the kind's middle level, no rest.
-- `includePassive` keeps passive kinds (the S32 Meadows check had the rabbit).
function Balance.kindRates(mapId: string, includePassive: boolean?): { KindRate }
	local r = table.find(Balance.REGION_IDS, mapId)
	local out: { KindRate } = {}
	local raw: { number } = {}
	for _, def in Monsters.list do
		if def.region == r and (includePassive or not def.passive) then
			local level = math.floor((def.levels.min + def.levels.max) / 2)
			local p = Balance.cachedPlayer("Warrior", level)
			local own = Balance.duel(p, Balance.monster(def, level))
			local generic = Balance.duel(p, Balance.monster(Balance.GENERIC, level))
			local exp = Balance.killExp(level, def, level)
			local ratio = (exp / own.seconds) / (Balance.killExp(level, Balance.GENERIC, level) / generic.seconds)
			-- HP per EXP against the generic kind of the same level first (EXP grows with the level), then the region mean
			local genericExp = Balance.killExp(level, Balance.GENERIC, level)
			table.insert(raw, (own.hpLost / exp) / math.max(1e-9, generic.hpLost / genericExp))
			table.insert(out, {
				kind = def.id,
				level = level,
				expPerSecond = ratio,
				hpPerExp = 0,
				hpPerExpGeneric = raw[#raw],
				caster = def.attack == "ranged" and def.damageKind == "magic",
				passive = def.passive == true,
			})
		end
	end
	local sum = 0
	for _, v in raw do
		sum += v
	end
	local mean = sum / math.max(1, #raw)
	for i, row in out do
		row.hpPerExp = raw[i] / mean
	end
	return out
end

-- Quests --------------------------------------------------------------------------------------------------------

export type QuestOpts = { bosses: boolean? }
export type QuestsAt = {
	exp: number, -- main + SIDE_SHARE x side (+ boss quests with opts.bosses)
	gold: number,
	main: number, -- EXP of the main quests without a boss objective
	side: number, -- SIDE_SHARE x EXP of the side quests
	boss: number, -- EXP of the main quests with a boss objective (in `exp` only with opts.bosses)
	bossGold: number,
	daily: number, -- PER_DAY x Daily.reward EXP per day (report only)
	dailyGold: number,
	-- S98: the boss quests of Data/Quests/Boss (category "boss", in `exp` and `gold`), the hunting contract of the level
	-- (S99, in `exp` and `gold`) and the weekly contracts with the boss contract per week (report only)
	bossQuest: number,
	contract: number,
	weekly: number,
}

local function hasBoss(q: any): boolean
	for _, o in q.objectives do
		if o.type == "boss" then
			return true
		end
	end
	return false
end

-- Quest rewards at their own level (balance plan 4 B3): no spreading over a band, no extrapolation.
function Balance.questsAt(level: number, opts: QuestOpts?): QuestsAt
	local o: QuestOpts = opts or {}
	local main, mainGold, side, sideGold, boss, bossGold = 0, 0, 0, 0, 0, 0
	for _, q in Quests.Main.list :: { any } do
		if q.level == level then
			if hasBoss(q) then
				boss += q.reward.exp or 0
				bossGold += q.reward.gold or 0
			else
				main += q.reward.exp or 0
				mainGold += q.reward.gold or 0
			end
		end
	end
	for _, q in Quests.Side.list :: { any } do
		if q.level == level then
			side += (q.reward.exp or 0) * Balance.SIDE_SHARE
			sideGold += (q.reward.gold or 0) * Balance.SIDE_SHARE
		end
	end
	-- S98: boss quests (category "boss") and the hunting contract of the level count like the side quests
	local bossQuest, bossQuestGold, contract, contractGold = 0, 0, 0, 0
	for _, q in Quests.Boss.list :: { any } do
		if q.level == level then
			bossQuest += q.reward.exp or 0
			bossQuestGold += q.reward.gold or 0
		end
	end
	for _, q in Quests.Contracts.list :: { any } do
		if q.level == level then
			contract += q.reward.exp or 0
			contractGold += q.reward.gold or 0
		end
	end
	local daily = Quests.Daily.reward(level)
	local exp, gold = main + side + bossQuest + contract, mainGold + sideGold + bossQuestGold + contractGold
	if o.bosses then
		exp += boss
		gold += bossGold
	end
	local weekly = Quests.Weekly.reward(level)
	-- the boss contract only from the first boss's entry level (QuestLogic.bossContractFor)
	local bossWeekly = if QuestLogic.bossContractFor(level) ~= nil then Quests.Weekly.bossReward(level).exp or 0 else 0
	return {
		bossQuest = bossQuest,
		contract = contract,
		weekly = Quests.Weekly.PER_WEEK * (weekly.exp or 0) + bossWeekly,
		exp = exp,
		gold = gold,
		main = main,
		side = side,
		boss = boss,
		bossGold = bossGold,
		daily = Quests.Daily.PER_DAY * (daily.exp or 0),
		dailyGold = Quests.Daily.PER_DAY * (daily.gold or 0),
	}
end

-- Potions -------------------------------------------------------------------------------------------------------

export type Potion = { quality: number, heal: number, price: number, level: number }

local defaultPotions: { Potion }? = nil
-- potion_hp_1..5 (Items): amount, buy price and level.
function Balance.hpPotions(): { Potion }
	if defaultPotions then
		return defaultPotions
	end
	local out: { Potion } = {}
	for q = 1, 5 do
		local def = Items.get(`potion_hp_{q}`) :: any
		-- S87: the level a potion needs (Great 45, Mighty 70), the same function as PotionService and the shop
		table.insert(
			out,
			{ quality = q, heal = def.use.amount, price = def.buyPrice, level = Potions.requiredLevel(def) }
		)
	end
	defaultPotions = out
	return out
end

local function allowedPotions(level: number, potions: { Potion }?): { Potion }
	local out: { Potion } = {}
	for _, p in potions or Balance.hpPotions() do
		if (p.level or 1) <= level then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return a.heal < b.heal
	end)
	return out
end

export type PotionUse = { quality: number, drinks: number, gold: number, wait: number }

-- Healing `hpLost` (share of max HP) with potions in `freeSeconds`: out-of-combat regeneration first, then the
-- cheapest allowed quality whose drinks fit (first drink at once, then every Potions.interval), else the biggest
-- with the extra wait (diag_economy potionFight, with the S54 interval and the potion levels).
function Balance.potionsAt(
	classId: string,
	level: number,
	hpLost: number,
	freeSeconds: number,
	potions: { Potion }?
): PotionUse
	local p = Balance.cachedPlayer(classId, level)
	local maxHp = p.values.maxHp
	local need = hpLost * maxHp - Stats.Formula.hpRegenPct / 100 * maxHp * freeSeconds
	local list = allowedPotions(level, potions)
	if need <= 0 or #list == 0 then
		return { quality = 0, drinks = 0, gold = 0, wait = 0 }
	end
	local interval = Potions.interval(level)
	local fits = math.floor(freeSeconds / interval) + 1
	for _, potion in list do
		local drinks = math.ceil(need / potion.heal)
		if drinks <= fits then
			return { quality = potion.quality, drinks = drinks, gold = drinks * potion.price, wait = 0 }
		end
	end
	local big = list[#list]
	local drinks = math.ceil(need / big.heal)
	return { quality = big.quality, drinks = drinks, gold = drinks * big.price, wait = (drinks - fits) * interval }
end

-- HP per second of the best allowed potion at the S54 interval (for the boss model).
function Balance.potionHps(level: number, potions: { Potion }?): number
	local list = allowedPotions(level, potions)
	if #list == 0 then
		return 0
	end
	return list[#list].heal / Potions.interval(level)
end

-- Pace ----------------------------------------------------------------------------------------------------------

export type PaceOpts = {
	kind: any?, -- a Data/Monsters id or a kind table (default kindAtRegion)
	area: "best"?, -- the region's hunting ground with the most EXP/h (Logic/AreaRates with its profile)
	potions: "chain"?, -- potions instead of the rest
	party: { string }?, -- class ids: same ground, credit split, no synergy, x PartyLoot.poolMul x PartyBonus.expMul
	bosses: boolean?, -- boss quests count
	carry: number?, -- EXP carried in from the level before
}

export type PaceAt = {
	kind: string,
	area: string?,
	profile: string?,
	secondsPerKill: number,
	expPerKill: number,
	expPerHour: number,
	kills: number,
	hours: number,
	questExp: number,
	carryOut: number,
	restShare: number,
	potions: PotionUse?, -- per fight (chain)
	goldPerKill: number,
	dropPerKill: number,
	potionGoldPerKill: number,
	hpLostPerFight: number,
	expMul: number,
}

local function areasCovering(level: number): { any }
	local out = {}
	for _, area in Areas.byMap[Balance.REGION_IDS[Balance.regionAt(level)]].areas do
		if level >= area.lv[1] and level <= area.lv[2] then
			table.insert(out, area)
		end
	end
	return out
end

-- An hour in `area` (kinds averaged with equal weight, each at the level clamped to its range in the area).
function Balance.areaHour(classId: string, level: number, area: any): any
	local p = Balance.cachedPlayer(classId, level)
	local n, spk, exp, coin, drop, hp = 0, 0, 0, 0, 0, 0
	for _, id in area.kinds do
		local def = Monsters.get(id) :: any
		local low, high = math.max(area.lv[1], def.levels.min), math.min(area.lv[2], def.levels.max)
		if low > high then
			low, high = area.lv[1], area.lv[2]
		end
		local r = AreaRates.rates(p :: any, def, math.clamp(level, low, high), area.profile, Balance.SKILL_DPS)
		n += 1
		spk += r.secondsPerKill
		exp += r.expPerKill
		coin += r.coinGoldPerHour / r.killsPerHour
		drop += r.dropGoldPerHour / r.killsPerHour
		hp += r.hpLostPerFight
	end
	spk /= n
	-- S98: the quest budget multiplier of the character's level, as CombatService.reward (AreaRates stays without it)
	exp *= Balance.budgetMul(level)
	return {
		id = area.id,
		profile = area.profile,
		secondsPerKill = spk,
		expPerKill = exp / n,
		expPerHour = exp / n * 3600 / spk,
		coinPerKill = coin / n,
		dropPerKill = drop / n,
		hpLost = hp / n,
	}
end

-- Pace of one level: kills of the level's kind (expected group, rest from regeneration, BREAK + WALK), quests at
-- their own level, the EXP above the level's need carried to the next (opts.carry in, carryOut out).
function Balance.paceAt(classId: string, level: number, opts: PaceOpts?): PaceAt
	local o: PaceOpts = opts or {}
	local kindArg = o.kind or Balance.kindAtRegion(level)
	local def = kindDef(kindArg)
	local kindName = if type(kindArg) == "string" then kindArg else "generic"
	local p = Balance.cachedPlayer(classId, level)
	local regen = Stats.Formula.hpRegenPct / 100
	local free = Balance.BREAK + Balance.WALK
	local fight = Balance.expectedGroup(p, def, level)
	local secondsPerKill, restShare, potionUse, potionGoldPerKill = 0, 0, nil, 0
	if o.potions == "chain" then
		local wait, gold, drinks, quality = 0, 0, 0, 0
		local total = 0
		for n, w in Balance.groupWeights() do
			local use = Balance.potionsAt(classId, level, fight.bySize[n].hpLost, free)
			total += w
			wait += w * use.wait
			gold += w * use.gold
			drinks += w * use.drinks
			quality = math.max(quality, use.quality)
		end
		wait, gold, drinks = wait / total, gold / total, drinks / total
		local perFight = fight.seconds + free + wait
		secondsPerKill = perFight / fight.members
		restShare = wait / perFight
		potionUse = { quality = quality, drinks = drinks, gold = gold, wait = wait }
		potionGoldPerKill = gold / fight.members
	else
		local rest = fight.hpLost / regen
		local perFight = fight.seconds + rest + free
		secondsPerKill = perFight / fight.members
		restShare = rest / perFight
	end
	local expPerKill = Balance.killExp(level, def, level)
	local goldPerKill = Balance.killGold(level, def, level)
	local dropPerKill = Balance.dropValue(level, "normal", if type(kindArg) == "string" then kindArg else nil)
	local areaId, profile = nil, nil
	if o.area == "best" then
		local best = nil
		for _, area in areasCovering(level) do
			local h = Balance.areaHour(classId, level, area)
			if not best or h.expPerHour > best.expPerHour then
				best = h
			end
		end
		if best then
			areaId, profile = best.id, best.profile
			secondsPerKill = best.secondsPerKill
			expPerKill = best.expPerKill
			goldPerKill = best.coinPerKill
			dropPerKill = best.dropPerKill
			local perFight = secondsPerKill * fight.members
			restShare = math.min(1, best.hpLost / regen / perFight)
		end
	end
	local expPerHour = expPerKill * 3600 / secondsPerKill
	local expMul = 1
	if o.party and #o.party > 0 then
		-- same ground, each member kills on its own and the credit is shared: the mean of the solo rates
		local sum = 0
		for _, c in o.party do
			local solo = if c == classId
				then expPerHour
				else Balance.paceAt(c, level, { kind = o.kind, area = o.area }).expPerHour
			sum += solo
		end
		-- S134b: every kill pays the party pool (PartyLoot.poolMul) split equally; the model's members all fight
		-- at the same level as the monsters (counted)
		expMul = PartyLoot.poolMul(#o.party) * PartyBonus.expMul(o.party)
		expPerHour = sum / #o.party * expMul
		expPerKill = expPerHour * secondsPerKill / 3600
		-- S134b: kill gold from the same pool (the member's own kill rate; no class bonus on gold)
		goldPerKill *= PartyLoot.poolMul(#o.party)
	end
	local q = Balance.questsAt(level, { bosses = o.bosses })
	local questExp = q.exp + (o.carry or 0)
	local need = Exp.expToNext(level) - questExp
	local carryOut = math.max(0, -need)
	local kills = math.max(0, need) / expPerKill
	return {
		kind = kindName,
		area = areaId,
		profile = profile,
		secondsPerKill = secondsPerKill,
		expPerKill = expPerKill,
		expPerHour = expPerHour,
		kills = kills,
		hours = kills * secondsPerKill / 3600,
		questExp = q.exp,
		carryOut = carryOut,
		restShare = restShare,
		potions = potionUse,
		goldPerKill = goldPerKill,
		dropPerKill = dropPerKill,
		potionGoldPerKill = potionGoldPerKill,
		hpLostPerFight = fight.hpLost,
		expMul = expMul,
	}
end

-- Levels lo .. hi - 1 one after the other, the quest EXP above a level's need carried to the next.
function Balance.paceBand(
	classId: string,
	lo: number,
	hi: number,
	opts: PaceOpts?
): { hours: number, levels: { PaceAt } }
	local carry = 0
	local hours = 0
	local levels: { PaceAt } = {}
	for level = lo, hi - 1 do
		local o: any = table.clone(opts or {})
		o.carry = carry
		local pace = Balance.paceAt(classId, level, o)
		carry = pace.carryOut
		hours += pace.hours
		table.insert(levels, pace)
	end
	return { hours = hours, levels = levels }
end

-- S91: model okna od 1. poziomu (S92 B1); S92 liczy nim też L19 i L20. Each main quest without a boss objective pays
-- its EXP over the window from its level to the level before the next main quest (in proportion to Exp.expToNext);
-- SIDE_SHARE of the side quests is spread over their band (Balance.BANDS: 1-19, 20-44, ...) like questRewards; the
-- quest EXP above a level's need carries to the next (paceAt's carry). Warrior / rest / GENERIC by default:
-- opts.kind = a kind (or "kindAt" for the Meadows kind of each level, Balance.kindAt; S92: "region" for
-- Balance.kindAtRegion), opts.withBossQuests = the boss
-- quests count too (report variant: grimrok over 18-19).
-- S98: opts.budget = false = the S94 quest lists (Balance.questCreditByLevel); the default counts the quest budget.
export type PaceWindowOpts = { kind: any?, withBossQuests: boolean?, budget: boolean? }
export type PaceWindow = {
	level: number,
	hours: number,
	questExp: number, -- quest EXP of the level (window main + side, without the carry)
	carryIn: number,
	carryOut: number,
	secondsPerKill: number,
	expPerKill: number,
}

local windowCache: { [string]: { PaceWindow } } = {}

-- S98 (docs/DESIGN-15.md §3.2, C1): every quest list of the pace model, read by one function so later sessions add
-- quests in the data only (each quest's `category` picks its rule in CREDIT_RULES). budget = false is for ever the
-- S91 / S94 model: the main story in windows and SIDE_SHARE of the side quests below 20 over 1-19, no boss quests, no
-- contracts, no side quests from 20 (the stable arc of S96 is new to it).
export type QuestCreditOpts = { withBossQuests: boolean?, budget: boolean? }
export type QuestCreditRow = {
	exp: number, -- Exp.expToNext(L)
	quest: number, -- quest EXP credited to L (without the carry)
	carryIn: number, -- quest EXP above the need of L - 1
	carryOut: number, -- quest EXP above the need of L (the next level's carryIn)
	need: number, -- EXP left to kill: max(0, exp - quest - carryIn)
	byCategory: { [string]: number }, -- `quest` split by category (main, side, boss, contract)
}
type QuestSource = { list: { any }, below: number? }
-- share = the part of a quest's EXP the model counts; spread = "window" (the main story: from its level to the level
-- before the next main quest), "band" (Logic/QuestBudget.bandOf of its level), "level" (its own level only)
local CREDIT_RULES: { [string]: { share: number, spread: string } } = {
	main = { share = 1, spread = "window" },
	side = { share = Balance.SIDE_SHARE, spread = "band" },
	boss = { share = 1, spread = "band" },
	contract = { share = 1, spread = "level" },
}
Balance.CREDIT_RULES = CREDIT_RULES

-- S103: the S94 EXP of the old story quests a story session put on the story rule (Data/Quests/Main settleStory):
-- the base model reads these, so it stays the S94 model bit for bit (tests/questbudget.spec). S104 / S105 add the old
-- quests of their chapters.
-- stylua: ignore
local LEGACY_EXP: { [string]: number } = table.freeze({
	werewolves = 22219, ruins = 23557, ents = 23136, cult = 30817, swamp = 39997, crypt = 61156, -- S103 (exp(L, f) of S92)
	ashen = 49874, orcs = 67684, golems = 81109, deepforge = 101826, -- S104 (exp(L, f) of S94)
	frostpeak = 135265, giants = 165230, glacier = 215466, -- S105 (exp(L, 1) of S94)
	toDuskwood = 7150, -- S109 (exp(20, 0.6) of S94: the bridge over level 20 joined the story rule, T-QB3 / T-QB5)
})
Balance.LEGACY_EXP = LEGACY_EXP

local function questSources(budget: boolean): { QuestSource }
	if not budget then
		-- S102: the S94 story = the 32 quests of StoryProgress.LEGACY_ORDER (later story insertions are budget)
		local legacy = {}
		for _, id in StoryProgress.LEGACY_ORDER do
			local quest: any = Quests.Main.get(id)
			local old = LEGACY_EXP[id]
			if old then
				-- S103: a copy with its S94 reward (the live quest gets its EXP from the story rule)
				quest = table.clone(quest)
				quest.reward = table.clone(quest.reward)
				quest.reward.exp = old
			end
			table.insert(legacy, quest)
		end
		return { { list = legacy }, { list = Quests.Side.list, below = 20 } }
	end
	return {
		{ list = Quests.Main.list },
		{ list = Quests.Side.list },
		{ list = Quests.Boss.list },
		{ list = Quests.Contracts.list },
	}
end

-- S109 (audit T-QB7): the quest lists the credit model reads (budget = false: the S94 lists), for the completeness check.
function Balance.questSourceLists(budget: boolean?): { { list: { any }, below: number? } }
	return questSources(budget ~= false)
end

local creditCache: { [string]: { QuestCreditRow } } = {}

local function creditRows(o: QuestCreditOpts): { QuestCreditRow }
	local budget = o.budget ~= false
	local withBosses = o.withBossQuests == true
	local key = `{budget}|{withBosses}`
	local cached = creditCache[key]
	if cached then
		return cached
	end
	local out: { [number]: number } = {}
	local cats: { [number]: { [string]: number } } = {}
	local function add(L: number, category: string, value: number)
		out[L] = (out[L] or 0) + value
		local c = cats[L] or {}
		cats[L] = c
		c[category] = (c[category] or 0) + value
	end
	local sources = questSources(budget)
	local function counted(source: QuestSource, q: any): boolean
		if source.below and q.level >= source.below then
			return false
		end
		local rule = CREDIT_RULES[q.category or "main"]
		assert(rule, `Balance: no credit rule for the quest category {q.category} ({q.id})`)
		return rule.spread ~= "window" or withBosses or not hasBoss(q)
	end
	-- the levels of the main quests counted (window starts, S91)
	local starts: { number } = {}
	for _, source in sources do
		for _, q in source.list do
			if counted(source, q) and CREDIT_RULES[q.category or "main"].spread == "window" then
				if not table.find(starts, q.level) then
					table.insert(starts, q.level)
				end
			end
		end
	end
	table.sort(starts)
	for _, source in sources do
		for _, q in source.list do
			if not counted(source, q) then
				continue
			end
			local category: string = q.category or "main"
			local rule = CREDIT_RULES[category]
			if rule.spread == "window" then
				local i = table.find(starts, q.level) :: number
				-- S94: the last main quest's window runs to MaxLevel - 1 (glacier 92-99, as the S91 windows read; it
				-- paid only level 92 before: h(92) = 0 and h(93) / h(92) without meaning)
				local last = if starts[i + 1] then starts[i + 1] - 1 else math.max(q.level, Config.MaxLevel - 1)
				local need = 0
				for L = q.level, last do
					need += Exp.expToNext(L)
				end
				for L = q.level, last do
					add(L, category, (q.reward.exp or 0) * Exp.expToNext(L) / need)
				end
			elseif rule.spread == "band" then
				if q.level < Config.MaxLevel then
					local lo, hi = QuestBudget.bandOf(q.level)
					local need = 0
					for L = lo, hi do
						need += Exp.expToNext(L)
					end
					for L = lo, hi do
						add(L, category, (q.reward.exp or 0) * rule.share * Exp.expToNext(L) / need)
					end
				end
			else
				add(q.level, category, (q.reward.exp or 0) * rule.share)
			end
		end
	end
	local rows: { QuestCreditRow } = {}
	local carry = 0
	for L = 1, Config.MaxLevel do
		local e = Exp.expToNext(L)
		local quest = out[L] or 0
		local need = e - quest - carry
		local carryOut = math.max(0, -need)
		table.insert(rows, {
			exp = e,
			quest = quest,
			carryIn = carry,
			carryOut = carryOut,
			need = math.max(0, need),
			byCategory = cats[L] or {},
		})
		carry = carryOut
	end
	creditCache[key] = rows
	return rows
end

-- S98 (C1): the quest EXP of the pace window model per level 1..99 (exp = Exp.expToNext, quest = window main + side +
-- boss + contract EXP credited to the level, carryIn = the excess of the level before, need = what is left to kill).
-- opts.budget = false: the S94 model (the base of the quest budget, tests/fixtures/quest_budget_base.json).
function Balance.questCreditByLevel(opts: QuestCreditOpts?): { [number]: QuestCreditRow }
	local rows = creditRows(opts or {})
	local out: { [number]: QuestCreditRow } = {}
	for L = 1, Config.MaxLevel - 1 do
		out[L] = rows[L]
	end
	return out
end

function Balance.paceWindowAt(classId: string, level: number, opts: PaceWindowOpts?): PaceWindow
	local o: PaceWindowOpts = opts or {}
	-- only nil / string kinds are cached: a kind table has no stable key (a second table must not read the first's)
	local cacheable = o.kind == nil or type(o.kind) == "string"
	local key = `{classId}|{o.kind or "generic"}|{o.withBossQuests == true}|{o.budget ~= false}`
	local list = if cacheable then windowCache[key] else nil
	if not list or #list < level then
		list = {}
		local credit = creditRows({ withBossQuests = o.withBossQuests, budget = o.budget })
		local top = math.max(level, 20)
		for L = 1, top do
			-- S92: "region" = the hunting-ground kind of each level (Balance.kindAtRegion; the report's region variant)
			local kind = if o.kind == "kindAt"
				then Balance.kindAt(L)
				elseif o.kind == "region" then Balance.kindAtRegion(L)
				else (o.kind or Balance.GENERIC)
			local pace = Balance.paceAt(classId, L, { kind = kind })
			local row = credit[L]
			local kills = row.need / pace.expPerKill
			table.insert(list, {
				level = L,
				hours = kills * pace.secondsPerKill / 3600,
				questExp = row.quest,
				carryIn = row.carryIn,
				carryOut = row.carryOut,
				secondsPerKill = pace.secondsPerKill,
				expPerKill = pace.expPerKill,
			})
		end
		if cacheable then
			windowCache[key] = list
		end
	end
	return list[level]
end

-- S91: the moving mean m(L) = mean of h(L - 4 .. L) of the window model (levels below 1 left out).
function Balance.paceWindowMean(classId: string, level: number, opts: PaceWindowOpts?): number
	local sum, n = 0, 0
	for L = math.max(1, level - 4), level do
		sum += Balance.paceWindowAt(classId, L, opts).hours
		n += 1
	end
	return sum / n
end

-- Economy -------------------------------------------------------------------------------------------------------

-- Potion gold per kill of the S32 rest model (HP lost above POTION_ABOVE healed with the cheapest fitting potion)
-- for any kind and the potions allowed at the level.
function Balance.potionGoldFor(classId: string, level: number, kind: any): number
	local def = kindDef(kind)
	local p = Balance.cachedPlayer(classId, level)
	local fight = Balance.expectedGroup(p, def, level)
	local list = allowedPotions(level)
	local total, gold = 0, 0
	for n, w in Balance.groupWeights() do
		local over = math.max(0, fight.bySize[n].hpLost - Balance.POTION_ABOVE) * p.values.maxHp
		local cost = 0
		if over > 0 then
			local best = math.huge
			for _, potion in list do
				best = math.min(best, math.ceil(over / potion.heal) * potion.price)
			end
			cost = best
		end
		total += w
		gold += w * cost
	end
	return gold / total / fight.members
end

export type EconomyAt = {
	killGold: number, -- per hour
	dropGold: number, -- per hour (merchant value of the drop)
	questGold: number, -- gold of the quests at this level (per level, not per hour: a quest can carry a whole level)
	potionGold: number, -- per hour
	incomePerHour: number, -- kill gold + drop sales per hour
	potionShare: number, -- potion gold / income per hour
	dropToKill: number,
	pace: PaceAt,
}

-- Gold per hour of grinding at the paceAt pace and the quest gold of the level (no upgrades or materials: S84, G9).
function Balance.economyAt(classId: string, level: number, opts: PaceOpts?): EconomyAt
	local o: PaceOpts = opts or {}
	local pace = Balance.paceAt(classId, level, o)
	local perHour = 3600 / pace.secondsPerKill
	local killGold = pace.goldPerKill * perHour
	local dropGold = pace.dropPerKill * perHour
	local questGold = Balance.questsAt(level, { bosses = o.bosses }).gold
	local potionPerKill = if o.potions == "chain"
		then pace.potionGoldPerKill
		else Balance.potionGoldFor(classId, level, o.kind or Balance.kindAtRegion(level))
	local potionGold = potionPerKill * perHour
	local income = killGold + dropGold
	return {
		killGold = killGold,
		dropGold = dropGold,
		questGold = questGold,
		potionGold = potionGold,
		incomePerHour = income,
		potionShare = potionGold / math.max(1e-9, income),
		dropToKill = dropGold / math.max(1e-9, killGold),
		pace = pace,
	}
end

-- Cave Elites ---------------------------------------------------------------------------------------------------

export type EliteFight = {
	level: number,
	classId: string,
	single: Fight,
	pair: Fight,
	encounter: number, -- (1 - q) x single + q x pair HP lost
	pairRatio: number,
	variant: string?, -- S91: the player variant of Balance.buildsAt (nil = bez węzłów)
}
export type EliteKind = { kind: string, min: number, max: number, fights: { EliteFight } }
export type Elite2Fight = { kind: string, spawner: number, playerLevel: number, byTeam: { Fight } }
export type CaveElites = {
	id: string,
	levels: { number },
	pairShare: number, -- q: Elite spawners with two members / all Elite spawners of the cave (real spawners)
	kinds: { EliteKind },
	elite2: { Elite2Fight },
}

-- The caves of a region from the real spawners (Data/Spawns): single and paired Elites for the four classes at the
-- spawner's min, middle and max level, Elite II for 1-4 players (Balance.team) at min(100, spawner + 2).
-- The Elite II fights of one spawner (S32 reading: teams of 1-4 at the spawner level + 2, at its lowest and top level)
-- into `out` (S134i: shared by the caves and the hideouts).
local function elite2Fights(spawner: any, withNodes: boolean?, out: { Elite2Fight })
	for _, kind in spawner.choices or { spawner.monster } do
		for i, L in { spawner.level.min, spawner.level.max } do
			if i == 2 and L == spawner.level.min then
				continue -- S134i: a hideout's Elite II has one level
			end
			local pl = math.min(100, L + 2)
			if withNodes and pl < PathData.ROWS[1].level then
				continue
			end
			local byTeam: { Fight } = {}
			for n = 1, 4 do
				local team = {}
				for i = 1, n do
					local c = Balance.ORDER[i]
					table.insert(
						team,
						if withNodes
							then Balance.player(c, pl, { nodes = Balance.COMBAT_BUILD[c] })
							else Balance.cachedPlayer(c, pl)
					)
				end
				byTeam[n] = Balance.elite2(team, kind, L)
			end
			table.insert(out, { kind = kind, spawner = L, playerLevel = pl, byTeam = byTeam })
		end
	end
end

-- S134i: the Elite II fights of a region map's hideouts (Data/Spawns, the spawners with `lair`), by hideout id.
local lairCache: { [string]: { { id: string, elite2: { Elite2Fight } } } } = {}
function Balance.lairElites(mapId: string, withNodes: boolean?): { { id: string, elite2: { Elite2Fight } } }
	local cacheKey = `{mapId}|{withNodes == true}`
	local cached = lairCache[cacheKey]
	if cached then
		return cached
	end
	local out = {}
	for _, s in Spawns.byMap[mapId] or {} do
		if s.lair and s.variant == "elite2" then
			local fights: { Elite2Fight } = {}
			elite2Fights(s, withNodes, fights)
			table.insert(out, { id = s.lair, elite2 = fights })
		end
	end
	lairCache[cacheKey] = out
	return out
end

-- S91 (B1): `withNodes` = the players with nodes: every variant of Balance.buildsAt but "bez węzłów" (Elites), the
-- class's combat build of Balance.COMBAT_BUILD (Elite II teams); levels without nodes give no fights.
local caveCache: { [string]: { CaveElites } } = {}
function Balance.caveElites(mapId: string, withNodes: boolean?): { CaveElites }
	local cacheKey = `{mapId}|{withNodes == true}`
	local cached = caveCache[cacheKey]
	if cached then
		return cached
	end
	local out: { CaveElites } = {}
	for _, cave in Areas.caves.list do
		if cave.region == mapId then
			local spawners = Spawns.byMap[cave.id] or {}
			local groups, paired = 0, 0
			local rangeOf: { [string]: { min: number, max: number } } = {}
			local elite2Spawners: { any } = {} -- S134h: two per cave (A, then B)
			for _, s in spawners do
				if s.variant == "elite" then
					groups += 1
					paired += if s.count >= 2 then 1 else 0
					rangeOf[s.monster] = rangeOf[s.monster] or s.level
				elseif s.variant == "elite2" then
					table.insert(elite2Spawners, s)
				end
			end
			local q = if groups > 0 then paired / groups else 0
			local kinds: { EliteKind } = {}
			for _, kind in cave.elites do
				local range = rangeOf[kind]
				if range then
					local def = Monsters.get(kind) :: any
					local fights: { EliteFight } = {}
					local levels = { range.min, math.floor((range.min + range.max) / 2), range.max }
					for i, L in levels do
						if i == 1 or L ~= levels[i - 1] then
							for _, c in Balance.CLASSES do
								local PL = math.min(100, L)
								local players: { { p: Player, variant: string? } } = {}
								if withNodes then
									for _, v in Balance.buildsAt(c, PL) do
										if v.nodes then
											table.insert(
												players,
												{ p = Balance.player(c, PL, { nodes = v.nodes }), variant = v.key }
											)
										end
									end
								else
									table.insert(players, { p = Balance.cachedPlayer(c, PL) })
								end
								for _, entry in players do
									local p = entry.p
									local single = Balance.elite(p, def, L)
									local pair = Balance.groupFight(p, FightSim.group(def, L, 2, "elite"))
									table.insert(fights, {
										level = L,
										classId = c,
										single = single,
										pair = pair,
										encounter = (1 - q) * single.hpLost + q * pair.hpLost,
										pairRatio = pair.hpLost / math.max(1e-9, single.hpLost),
										variant = entry.variant,
									})
								end
							end
						end
					end
					table.insert(kinds, { kind = kind, min = range.min, max = range.max, fights = fights })
				end
			end
			local elite2: { Elite2Fight } = {}
			for _, elite2Spawner in elite2Spawners do
				elite2Fights(elite2Spawner, withNodes, elite2)
			end
			table.insert(out, { id = cave.id, levels = cave.levels, pairShare = q, kinds = kinds, elite2 = elite2 })
		end
	end
	caveCache[cacheKey] = out
	return out
end

-- Boss model (S83) ----------------------------------------------------------------------------------------------

-- Seconds after an attack's windup before the next attack of any kind (S87: Data/BossTuning.globalGap, read by
-- Entities/Boss.Step too; balancemodel.spec checks that the server reads it).
Balance.BOSS_GLOBAL_GAP = BossTuning.globalGap

-- Numeric "local NAME = 12.5" lines of a server boss script, read as text (the scripts need Roblox; same rule as
-- tools/WikiData/Bosses.scriptConsts).
function Balance.bossScriptConsts(bossId: string): { [string]: number }
	local out: { [string]: number } = {}
	local path = `src/server/Entities/BossScripts/{bossId}.luau`
	if not fs.isFile(path) then
		return out
	end
	for line in string.gmatch(fs.readFile(path), "[^\r\n]+") do
		local key, value = string.match(line, "^local ([A-Z_]+) = ([%d%.]+)$")
		if key and value and tonumber(value) then
			out[key] = tonumber(value) :: number
		end
	end
	return out
end

-- Scripted boss hazards (server BossScripts, multiplier of the boss attack like CombatService): Azgor's lava
-- outside the shrinking safe circle, Vaelgrath's storm away from the braziers. S87: damage from Data/BossTuning
-- (the scripts require it); phase, tick and kind stay here, the ticks checked as text by balancemodel.spec.
-- S94 (B1b): Vaelgrath's tick is the script's STORM_TICK (read as text, like FLIGHT_SECONDS in bossFight)
Balance.HAZARDS = {
	azgor = { phase = 3, damage = BossTuning.hazards.azgor.lava, every = 1, damageKind = "magic" },
	vaelgrath = {
		phase = 3,
		damage = BossTuning.hazards.vaelgrath.freezingStorm,
		every = Balance.bossScriptConsts("vaelgrath").STORM_TICK or 3,
		damageKind = "magic",
	},
} :: { [string]: { phase: number, damage: number, every: number, damageKind: string } }

export type CadenceState = { nextAttack: { [string]: number }, nextGlobal: number, phase: number }
export type CadenceOpts = {
	step: number?, -- 0.05 s
	seconds: number?, -- 600 s in one phase
	globalStart: number?, -- 4 s (Boss.new: nextGlobal = now + 4)
	firstUse: number?, -- 5 s (mean of 3 + U(0, 4))
	gap: number?, -- BOSS_GLOBAL_GAP
	pick: ((ready: { any }, t: number, state: CadenceState) -> any?)?, -- default: Logic/BossSchedule.pick (S87)
}
export type Cadence = { perMinute: { [string]: number }, rateShare: { [string]: number }, casting: number }

-- S87: the game's choice (Logic/BossSchedule: most overdue relative to its cooldown). -- mirrors Entities/Boss.Step
function Balance.PICK_SCHEDULE(ready: { any }, t: number, state: CadenceState): any?
	return BossSchedule.pick(ready, t, state.nextAttack)
end

-- The S83 rule (first ready attack in list order), kept for tests to reproduce the S83 control numbers.
function Balance.PICK_LIST_ORDER(ready: { any }): any?
	return ready[1]
end

-- Attack schedule of `def` in `phase` (Entities/Boss.Step at a fixed step): when t >= nextGlobal, opts.pick's
-- choice among the ready attacks (default Logic/BossSchedule.pick, S87; Balance.PICK_LIST_ORDER = the S83 rule);
-- then nextAttack = t + cooldown and nextGlobal = t + windup + gap.
-- rateShare = uses per minute / (60 / cooldown); casting = time spent winding up / time.
function Balance.bossCadence(def: any, phase: number, opts: CadenceOpts?): Cadence
	local o: CadenceOpts = opts or {}
	local step = o.step or 0.05
	local seconds = o.seconds or 600
	local gap = o.gap or Balance.BOSS_GLOBAL_GAP
	local attacks = {}
	local state: CadenceState = { nextAttack = {}, nextGlobal = o.globalStart or 4, phase = phase }
	local counts: { [string]: number } = {}
	for _, attack in def.attacks do
		if table.find(attack.phases, phase) then
			table.insert(attacks, attack)
			state.nextAttack[attack.id] = o.firstUse or 5
			counts[attack.id] = 0
		end
	end
	local casting = 0
	local steps = math.floor(seconds / step + 0.5)
	for i = 0, steps - 1 do
		local t = i * step
		if t >= state.nextGlobal then
			local chosen = nil
			local pick = o.pick or Balance.PICK_SCHEDULE
			local ready = BossSchedule.ready(attacks, phase, t, state.nextAttack)
			if #ready > 0 then
				chosen = pick(ready, t, state)
			end
			if chosen then
				state.nextAttack[chosen.id] = t + chosen.cooldown
				state.nextGlobal = t + chosen.windup + gap
				counts[chosen.id] += 1
				casting += chosen.windup
			end
		end
	end
	local perMinute: { [string]: number } = {}
	local rateShare: { [string]: number } = {}
	for _, attack in attacks do
		perMinute[attack.id] = counts[attack.id] / (seconds / 60)
		rateShare[attack.id] = perMinute[attack.id] / (60 / attack.cooldown)
	end
	return { perMinute = perMinute, rateShare = rateShare, casting = math.min(1, casting / seconds) }
end

-- Kind table of a boss (Entities/Boss kindFor; S134: the same for every party).
function Balance.bossKind(def: any): any
	return {
		hpMul = BossScaling.hpMultiplier() * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		mresMul = def.mresMul,
		family = def.family,
		speed = def.speed,
		attack = def.attack,
		damageKind = def.damageKind,
	}
end

-- Melee classes stand next to the boss (in a ring attack's safe centre, under a self circle); the others stand off.
Balance.MELEE = { Warrior = true, Cleric = true } :: { [string]: boolean }

export type BossPhase = {
	share: number, -- share of the boss HP
	seconds: number, -- boss vulnerable and fighting
	shieldSeconds: number, -- shield waves (boss invulnerable, holds still, no attacks)
	flightSeconds: number, -- extra invulnerable seconds while attacking (Vaelgrath phase 2)
	casts: number, -- special attacks cast
	tankDps: number, -- boss damage per second on the tank (basic + specials, enrage)
	raidDps: number, -- boss damage per second on the other players together
}
export type BossOpts = {
	specialHit: number?, -- share of telegraphed attacks that land (SPECIAL_HIT)
	hazardShare: number?, -- share of the hazard ticks taken (0: players stand safe)
	cadence: CadenceOpts?,
	-- S84: the boss at this level (its shield waves move by the same number of levels); nil = Data/Bosses level
	level: number?,
	-- S91 (Grimrok bez wsparcia): multiplier of member i's Balance.dps on the boss and on the shield helpers (the
	-- skill model's DPS on the boss / the convention's); nil = 1
	dpsMul: { number }?,
	-- S134: share of the big blows to dodge (`avoid`) that still land (default 0: the party dodges them)
	avoidHit: number?,
	-- S134: players standing together in a `split` area (default: the whole party)
	splitInside: number?,
}

-- S134: seconds of reaction the model takes off a channel before the party starts breaking it
Balance.CHANNEL_REACTION = 0.5

-- S134: the party mechanics of one fight (Balance.bossFight). `split`: one blow on a member standing in the area /
-- its max HP (x Combat.randomMax), by class, the biggest over the boss's split attacks; `channel`: seconds the party
-- needs to break the boss's channel (the slowest one) and whether it does in time (seconds - CHANNEL_REACTION).
export type BossMechanicsReport = {
	split: { [string]: number },
	hasSplit: boolean,
	channelSeconds: number, -- needed (0 without a channel)
	channelLimit: number, -- seconds - CHANNEL_REACTION of the strictest channel (math.huge without one)
	channelBroken: boolean, -- true without a channel
	hasChannel: boolean,
	channelHit: { [string]: number }, -- an unbroken channel on a member / its max HP (x randomMax), by class
}
export type BossFight = {
	hp: number,
	dps: number, -- team damage per second on the boss (x BOSS_UPTIME)
	seconds: number,
	phases: { BossPhase },
	enraged: boolean,
	enrageAt: number?,
	biggestHit: { [string]: number }, -- biggest single hit (x Combat.randomMax) / max HP of the class
	tankDps: number,
	potionHps: number,
	shieldTankHp: number, -- HP the tank loses to the helpers of all shield waves (share of max HP)
	hazards: { phase: number, perTick: { [string]: number }, hps: { [string]: number }, every: number }?,
	-- S84: regular attacks of the shield helpers on the tank, helpers killed, seconds of shield waves, seconds of
	-- active fighting (all phases)
	shieldAttacks: number,
	shieldKills: number,
	shieldSeconds: number,
	activeSeconds: number,
	-- S91: damage per second taken by member i over the whole fight (active phases and shield waves; the shield
	-- helpers hit the tank)
	memberDps: { number },
	-- S93: share of the max HP per minute one member of each class takes from the boss's `all` attacks (Azgor's
	-- meteor under every player; the worst member of the class) over the active phases (casts per minute of
	-- bossCadence weighted by the phases' active seconds x one hit x specialHit, no enrage); S94 reads the same field
	-- for Vaelgrath
	raid: { [string]: number },
	-- S93: one tick of the scripted hazard / the class's max HP (hazards.perTick; empty without a hazard)
	hazardTick: { [string]: number },
	-- S134: the biggest big blow to dodge (`avoid`) one member of each class would take (x Combat.randomMax) / max HP
	biggestAvoidable: { [string]: number },
	mechanics: BossMechanicsReport,
}

-- S92: the helpers of a boss summon as the server spawns them: Boss.spawnSummons -> DungeonService spawnMonster ->
-- MonsterService.SpawnAt(id, "normal", level, at, nil) has no GroupSize attribute, so Monster.new gives them
-- groupDamageMul(nil) = 1 (no S32 group damage reduction, unlike FightSim.group of `count` members).
function Balance.summonHelpers(helperDef: any, level: number, count: number): { any }
	local members = {}
	for _ = 1, count do
		table.insert(members, FightSim.group(helperDef, level, 1)[1])
	end
	return members
end

-- Boss fight of `team` (team[1] is the tank): HP and armour as Balance.boss, phases by HP (def.phases), the real
-- schedule per phase (bossCadence), damage per attack and kind on its targets (threat / nearest -> tank, self
-- circle -> melee, self ring -> ranged, random -> min(count, n) / n each, all -> everyone) x specialHit, the basic
-- attack on the tank every attackInterval / haste outside the casting share, enrage after enrageAfter (x
-- enrageDamage on everything), shield waves (the summon's count of helpers killed by the team while they hit the
-- tank), Vaelgrath's flight in phase 2 and the scripted hazards.
-- S134 (bosses 2.0, Logic/BossMechanics): `avoid` blows land x avoidHit (default 0, dodged); `split`: the party
-- stands together (splitInside, default n) and shares the blow (always lands); `mark`: only the marked member (1 / n
-- each) takes damage x self (the others step away); `channel`: broken when breakPct x HP / dps <= seconds -
-- CHANNEL_REACTION (the boss only stands), otherwise it hits everyone. biggestHit counts only the attacks that cannot
-- be dodged and are no split / channel (mechanics reports those).
function Balance.bossFight(bossId: string, team: { Player }, opts: BossOpts?): BossFight
	local o: BossOpts = opts or {}
	local def = Bosses.byId[bossId] :: any
	if o.level and o.level ~= def.level then
		local shift = o.level - def.level
		def = table.clone(def)
		def.level = o.level
		local summons = {}
		for _, summon in def.summons do
			local copy = table.clone(summon)
			copy.level = math.clamp(summon.level + shift, 1, 100)
			table.insert(summons, copy)
		end
		def.summons = summons
	end
	local n = #team
	local specialHit = o.specialHit or Balance.SPECIAL_HIT
	local avoidHit = o.avoidHit or 0
	local splitInside = o.splitInside or n
	local m = Balance.monster(Balance.bossKind(def), def.level, "boss")
	local function memberDps(i: number, p: Player, target: any): number
		return Balance.dps(p, target) * (if o.dpsMul then o.dpsMul[i] or 1 else 1)
	end
	local dps = 0
	for i, p in team do
		dps += memberDps(i, p, m) * Balance.BOSS_UPTIME
	end
	local tank = team[1]
	local taken: { number } = table.create(n, 0)
	local thresholds = { 1 }
	for _, t in def.phases do
		table.insert(thresholds, t)
	end
	table.insert(thresholds, 0)
	local flight = if bossId == "vaelgrath" then Balance.bossScriptConsts("vaelgrath").FLIGHT_SECONDS or 0 else 0
	local elapsed = 0
	local enrageAt: number? = nil
	local phases: { BossPhase } = {}
	local tankTotal, fightingTotal, shieldTankHp = 0, 0, 0
	local shieldAttacks, shieldKills, shieldTotal = 0, 0, 0
	local biggest: { [string]: number } = {}
	local avoidable: { [string]: number } = {}
	local mech: BossMechanicsReport = {
		split = {},
		hasSplit = false,
		channelSeconds = 0,
		channelLimit = math.huge,
		channelBroken = true,
		hasChannel = false,
		channelHit = {},
	}
	for _, attack in def.attacks do
		if attack.mechanic == "channel" and attack.channel then
			local need = BossMechanics.breakSeconds(attack.channel.breakPct, m.maxHp, dps)
			local limit = attack.channel.seconds - Balance.CHANNEL_REACTION
			mech.hasChannel = true
			mech.channelSeconds = math.max(mech.channelSeconds, need)
			mech.channelLimit = math.min(mech.channelLimit, limit)
			mech.channelBroken = mech.channelBroken and need <= limit
		end
	end
	-- S93: damage of `all` attacks per member over the active phases (per member: a class can be in the team twice)
	local raidTotal: { number } = {}
	for phase = 1, #thresholds - 1 do
		local share = thresholds[phase] - thresholds[phase + 1]
		-- shield waves at the phase start (and every `every` s of the phase)
		local fighting = share * m.maxHp / dps
		local shieldSeconds = 0
		for _, summon in def.summons do
			if summon.phase == phase and summon.shield then
				local count = summon.count -- S134: no helpers per player
				local waves = 1 + (if summon.every then math.floor(fighting / summon.every) else 0)
				local helperDef = Monsters.get(summon.monster) :: any
				-- S92: still with the S32 group reduction (the server has none, Balance.summonHelpers): without it the
				-- frozen 1-20 fixture moves (Grimrok bez wsparcia +18 %); DECYZJE S92, for S93 / the owner
				local members = FightSim.group(helperDef, summon.level, count)
				local lost, attacks = 0, 0
				for k, member in members do
					local teamDps = 0
					for i, p in team do
						teamDps += memberDps(i, p, member)
					end
					local duration = member.maxHp / math.max(1e-6, teamDps)
					shieldSeconds += duration * waves
					for j = k, #members do
						lost += Balance.hit(members[j], tank) * duration / members[j].attackInterval
						attacks += duration / members[j].attackInterval
					end
				end
				shieldTankHp += lost * waves / tank.values.maxHp
				taken[1] += lost * waves
				shieldAttacks += attacks * waves
				shieldKills += count * waves
			end
		end
		-- Vaelgrath (phase 2): FLIGHT_SECONDS invulnerable from the phase start, overlapping the shield wave; past
		-- the wave it attacks while nobody can hit it
		local flightSeconds = if phase == 2 then math.max(0, flight - shieldSeconds) else 0
		local active = fighting + flightSeconds
		local cad = Balance.bossCadence(def, phase, o.cadence)
		local haste = (def.haste or {})[phase] or 1
		local startActive = elapsed + shieldSeconds
		-- enrage: the share of this phase's active time past enrageAfter
		local enragedShare = 0
		if startActive + active > def.enrageAfter then
			enragedShare = math.clamp((startActive + active - def.enrageAfter) / active, 0, 1)
			enrageAt = enrageAt or def.enrageAfter
		end
		local dmgMul = 1 + (def.enrageDamage - 1) * enragedShare
		local tankPerSecond = Balance.hit(m, tank) * haste / m.attackInterval * (1 - cad.casting)
		local raidPerSecond = 0
		local casts = 0
		for _, attack in def.attacks do
			local perMinute = cad.perMinute[attack.id]
			if perMinute and perMinute > 0 then
				casts += perMinute * active / 60
				local kind = attack.damageKind or def.damageKind
				local mechanic = attack.mechanic
				local dodge = BossMechanics.isAvoidable(attack)
				for i, p in team do
					local share: number = 0
					-- S134: the multiplier of one hit and the share of casts that land on this member
					local mul = attack.damage
					local lands = if dodge then avoidHit else specialHit
					if mechanic == "split" then
						local missAll = if attack.split then attack.split.missAll else 0
						mul = BossMechanics.splitShare(attack.damage, splitInside, missAll)
						share = if splitInside <= 0 or i <= splitInside then 1 else 0
						lands = 1
					elseif mechanic == "mark" then
						share = 1 / n
						mul = BossMechanics.markDamage(true, attack.damage, attack.mark :: any)
						lands = 1
					elseif mechanic == "channel" then
						share = if mech.channelBroken then 0 else 1
						lands = 1
					elseif attack.target == "threat" or attack.target == "nearest" then
						share = if i == 1 then 1 else 0
					elseif attack.target == "self" then
						local melee = Balance.MELEE[p.classId] == true
						share = if attack.shape == "ring" then (if melee then 0 else 1) else (if melee then 1 else 0)
					elseif attack.target == "random" then
						share = math.min(attack.count or 1, n) / n
					else -- all
						share = 1
					end
					local hit = Balance.hit(m, p, mul, kind, false)
					local top = hit * Combat.randomMax / p.values.maxHp
					if mechanic == "split" then
						mech.split[p.classId] = math.max(mech.split[p.classId] or 0, top)
						mech.hasSplit = true
					elseif mechanic == "channel" then
						mech.channelHit[p.classId] = math.max(mech.channelHit[p.classId] or 0, top)
					elseif dodge then
						if share > 0 then
							avoidable[p.classId] = math.max(avoidable[p.classId] or 0, top)
						end
					elseif share > 0 then
						biggest[p.classId] = math.max(biggest[p.classId] or 0, top)
					end
					if share > 0 and lands > 0 then
						local perSecond = hit * lands * share * perMinute / 60
						taken[i] += perSecond * active * dmgMul
						if i == 1 then
							tankPerSecond += perSecond
						else
							raidPerSecond += perSecond
						end
						if attack.target == "all" then
							-- S93: meteor per minute (Boss.luau targetsFor: `all` = a circle under every player)
							raidTotal[i] = (raidTotal[i] or 0) + perSecond * active
						end
					end
				end
			end
		end
		taken[1] += Balance.hit(m, tank) * haste / m.attackInterval * (1 - cad.casting) * active * dmgMul
		tankPerSecond *= dmgMul
		raidPerSecond *= dmgMul
		tankTotal += tankPerSecond * active
		fightingTotal += active
		elapsed += shieldSeconds + active
		shieldTotal += shieldSeconds
		table.insert(phases, {
			share = share,
			seconds = active,
			shieldSeconds = shieldSeconds,
			flightSeconds = flightSeconds,
			casts = casts,
			tankDps = tankPerSecond,
			raidDps = raidPerSecond,
		})
	end
	local hazards = nil
	local hazard = Balance.HAZARDS[bossId]
	if hazard then
		local perTick: { [string]: number } = {}
		local hps: { [string]: number } = {}
		for _, p in team do
			local hit = Balance.hit(m, p, hazard.damage, hazard.damageKind, false)
			perTick[p.classId] = hit / p.values.maxHp
			hps[p.classId] = hit / hazard.every
		end
		hazards = { phase = hazard.phase, perTick = perTick, hps = hps, every = hazard.every }
		local share = o.hazardShare or 0
		if share > 0 then
			local ph = phases[hazard.phase]
			local extra = Balance.hit(m, tank, hazard.damage, hazard.damageKind, false) / hazard.every * share
			ph.tankDps += extra
			tankTotal += extra * ph.seconds
			taken[1] += extra * ph.seconds
			for i = 2, n do
				local p = team[i]
				local hps = Balance.hit(m, p, hazard.damage, hazard.damageKind, false) / hazard.every * share
				ph.raidDps += hps
				taken[i] += hps * ph.seconds
			end
		end
	end
	return {
		hp = m.maxHp,
		dps = dps,
		seconds = elapsed,
		phases = phases,
		enraged = enrageAt ~= nil,
		enrageAt = enrageAt,
		biggestHit = biggest,
		tankDps = tankTotal / math.max(1e-9, fightingTotal),
		potionHps = Balance.potionHps(def.level),
		shieldTankHp = shieldTankHp,
		hazards = hazards,
		shieldAttacks = shieldAttacks,
		shieldKills = shieldKills,
		shieldSeconds = shieldTotal,
		activeSeconds = fightingTotal,
		memberDps = (function(): { number }
			local out: { number } = {}
			for i = 1, n do
				out[i] = taken[i] / math.max(1e-9, elapsed)
			end
			return out
		end)(),
		raid = (function(): { [string]: number }
			-- the worst member of each class (members of one class share level and gear in the model)
			local out: { [string]: number } = {}
			for i, total in raidTotal do
				local p = team[i]
				local share = total / math.max(1e-9, fightingTotal) * 60 / p.values.maxHp
				out[p.classId] = math.max(out[p.classId] or 0, share)
			end
			return out
		end)(),
		hazardTick = if hazards then hazards.perTick else {},
		biggestAvoidable = avoidable,
		mechanics = mech,
	}
end

-- A party of `n` players of `level` in the order of the S32 Grimrok check (diag_hard `team`).
Balance.ORDER = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }
-- S91: `withNodes` = each member with the nodes of its class's Balance.COMBAT_BUILD (B1)
function Balance.team(n: number, level: number, withNodes: boolean?): { Player }
	local out = {}
	for i = 1, n do
		local c = Balance.ORDER[(i - 1) % #Balance.ORDER + 1]
		table.insert(
			out,
			if withNodes
				then Balance.player(c, level, { nodes = Balance.COMBAT_BUILD[c] })
				else Balance.player(c, level)
		)
	end
	return out
end

-- S32 targets in one place (S83) ---------------------------------------------------------------------------------

-- One measured number against its band (`low` / `high` missing = a one-sided target; both inclusive).
export type TargetRow = {
	id: string,
	group: string,
	label: string,
	value: number,
	low: number?,
	high: number?,
	classId: string?,
	level: number?,
	report: string?, -- the session that asserts it (a row with `report` never asserts in its block)
}

function Balance.inBand(row: TargetRow): boolean
	local v = row.value
	if v ~= v then
		return false
	end
	return (row.low == nil or v >= row.low) and (row.high == nil or v <= row.high)
end

-- Highest weapon merchant tier at or below `level` (the starting weapon below the first tier).
function Balance.shopTier(level: number): number
	local best = 1
	for _, tier in Shops.WEAPONSMITH_TIERS do
		if tier <= level then
			best = tier
		end
	end
	return best
end

Balance.LEVELS_1_20 = { 1, 2, 5, 10, 15, 18, 20 }
Balance.MAIN = { "Warrior", "Hunter", "Mage" }
-- S32 Elite II checks: kind and spawner level (the top of its cave, as S32 took it).
Balance.ELITE2_1_20 = { { "bandit", 12 }, { "goblinScout", 16 }, { "caveSpider", 18 }, { "goblinShaman", 18 } }
-- S134h: the second Elite IIs of the Meadows' generated caves (spawner levels of their own: kind ranges)
table.insert(Balance.ELITE2_1_20, { "carrionCrow", 11 })
table.insert(Balance.ELITE2_1_20, { "koboldMiner", 15 })
-- S134i: the Elite IIs of the Meadows' hideouts (one level each: the top of lv within the kind's range)
table.insert(Balance.ELITE2_1_20, { "swampToad", 8 })
table.insert(Balance.ELITE2_1_20, { "boar", 10 })

local function target(
	rows: { TargetRow },
	id: string,
	group: string,
	label: string,
	value: number,
	low: number?,
	high: number?,
	classId: string?,
	level: number?
)
	table.insert(rows, {
		id = id,
		group = group,
		label = label,
		value = value,
		low = low,
		high = high,
		classId = classId,
		level = level,
	})
end

-- The numeric targets of the S32 blocks of balance.spec (thresholds as of the start of S83, incl. S64 / S66).
function Balance.targets1_20(): { TargetRow }
	local rows: { TargetRow } = {}
	-- One monster and groups. S91 (B1): every player variant of Balance.buildsAt (bez węzłów, then each reference
	-- build trimmed to the level: ids and labels with "@<build>")
	for _, c in Balance.CLASSES do
		for _, L in Balance.LEVELS_1_20 do
			for _, v in Balance.buildsAt(c, L) do
				local p = Balance.player(c, L, if v.nodes then { nodes = v.nodes } else nil)
				local at = if v.nodes then `@{v.key}` else ""
				local f = Balance.duel(p, Balance.monster(Balance.GENERIC, L))
				local id = `S32.duel.{c}.{L}{at}`
				if L >= 2 then
					-- Clerics fight slower but take less damage (S18 band); S66: the Mage's level 2 duel ~5.49 s.
					local slow = if c == "Cleric" then 11 else 10
					local low = if c == "Cleric" then 0.09 else 0.1
					local fast = if c == "Mage" and L == 2 then 5.4 else 5.5
					target(rows, `{id}.seconds`, "duel", `{c} {L}{at}: 1 na 1 s`, f.seconds, fast, slow, c, L)
					target(rows, `{id}.hp`, "duel", `{c} {L}{at}: 1 na 1 HP`, f.hpLost, low, 0.25, c, L)
				else
					-- Level 1 is a gentle start (S32: below 15 %).
					target(rows, `{id}.hp`, "duel", `{c} 1: łagodny start HP`, f.hpLost, nil, 0.15 - 1e-9, c, L)
				end
				local g = Balance.expectedGroup(p, Balance.GENERIC, L)
				local gid = `S32.group.{c}.{L}{at}`
				if L >= 5 then
					local high = if c == "Mage" then 0.7 else 0.6
					local low = if c == "Cleric" then 0.3 else 0.35
					target(rows, `{gid}.hp`, "group", `{c} {L}{at}: grupa średnio HP`, g.hpLost, low, high, c, L)
				end
				target(rows, `{gid}.size4`, "group", `{c} {L}{at}: grupa 4 HP`, g.bySize[4].hpLost, nil, 1.1, c, L)
			end
		end
	end
	do
		local skill = Balance.SKILL_DPS
		Balance.SKILL_DPS = 1
		for _, c in Balance.CLASSES do
			for _, L in { 3, 5, 6 } do
				local f = Balance.groupFight(Balance.player(c, L), Balance.group("wolf", L, 3))
				target(rows, `S32.wolves.{c}.{L}`, "wolves", `{c} {L}: trzy wilki HP`, f.hpLost, 0.4, 0.95, c, L)
			end
		end
		Balance.SKILL_DPS = skill
	end
	for _, c in Balance.CLASSES do
		for L = 2, 20 do
			-- S91 (B1): without nodes and with each reference build's nodes
			for _, v in Balance.buildsAt(c, L) do
				local p = Balance.player(
					c,
					L,
					{ ilvl = Items.generate.tierFor(L), weaponIlvl = Balance.shopTier(L), nodes = v.nodes }
				)
				local at = if v.nodes then `@{v.key}` else ""
				local f = Balance.duel(p, Balance.monster(Balance.GENERIC, L))
				-- Clerics are slow on purpose (and lose the least HP).
				local slow = if c == "Cleric" then 20 else 15.5
				local id = `S32.shop.{c}.{L}{at}`
				target(rows, `{id}.seconds`, "shop", `{c} {L}{at}: sprzęt ze sklepu s`, f.seconds, nil, slow, c, L)
				target(rows, `{id}.hp`, "shop", `{c} {L}{at}: sprzęt ze sklepu HP`, f.hpLost, nil, 0.36, c, L)
			end
		end
	end
	-- Elites, Elite II, Grimrok
	for _, c in Balance.MAIN do
		for _, L in { 10, 15, 18, 20 } do
			for _, v in Balance.buildsAt(c, L) do
				local p = Balance.player(c, L, if v.nodes then { nodes = v.nodes } else nil)
				local at = if v.nodes then `@{v.key}` else ""
				local f = Balance.elite(p, Balance.GENERIC, L)
				local id = `S32.elite.{c}.{L}{at}`
				target(rows, `{id}.seconds`, "elite", `{c} {L}{at}: Elita s`, f.seconds, 20, 36, c, L)
				target(rows, `{id}.hp`, "elite", `{c} {L}{at}: Elita HP`, f.hpLost, 0.55, 0.95, c, L)
			end
		end
	end
	-- S91 (C3): Elite II counted as S32 (party at min(20, spawner + 2)), thresholds of the regions
	-- (REGION_TARGETS.elite2, S83 / S92: solo at least, two at most, three within)
	local E2 = Balance.REGION_TARGETS.elite2
	for _, spec in Balance.ELITE2_1_20 do
		local kind, spawner = spec[1] :: string, spec[2] :: number
		local L = math.min(20, spawner + 2)
		local w, m, h = Balance.player("Warrior", L), Balance.player("Mage", L), Balance.player("Hunter", L)
		local id = `S32.elite2.{kind}.{spawner}`
		local label = `{kind} {spawner}`
		target(
			rows,
			`{id}.solo`,
			"elite2",
			`{label}: solo HP`,
			Balance.elite2({ w }, kind, spawner).hpLost,
			E2.solo,
			nil,
			nil,
			L
		)
		local duo = Balance.elite2({ w, m }, kind, spawner).hpLost
		target(rows, `{id}.duo`, "elite2", `{label}: 2 graczy HP`, duo, nil, E2.duo, nil, L)
		local trio = Balance.elite2({ w, m, h }, kind, spawner).hpLost
		target(rows, `{id}.trio`, "elite2", `{label}: 3 graczy HP`, trio, E2.trio[1], E2.trio[2], nil, L)
	end
	-- S134: the S32 Grimrok rows (4-6 min for 3-5 players, no hit above 70 % of a Mage) gave way to
	-- Balance.targetsS134 (bosses 2.0: a bigger party kills faster, big blows to dodge)
	-- Items
	for _, c in Balance.CLASSES do
		for _, L in { 5, 10, 20 } do
			local id = `S32.rarity.{c}.{L}`
			local legendary = Balance.rarityGain(c, L, Rarities.LEGENDARY)
			local unique = Balance.rarityGain(c, L, Rarities.UNIQUE)
			local heroic = Balance.rarityGain(c, L, Rarities.HEROIC)
			local mythic = Balance.rarityGain(c, L, Rarities.MYTHIC)
			target(rows, `{id}.unique`, "rarity", `{c} {L}: Unikatowy`, unique, 0.07, 0.15, c, L)
			-- FIX 2026-10-09: Heroic always rolls 3 bonuses (was 2-3), up to ~25.1 %
			target(rows, `{id}.heroic`, "rarity", `{c} {L}: Heroiczny`, heroic, 0.15, 0.26, c, L)
			-- S134g: Legendary = Heroic +~5 % in stats plus a skill effect (no power here): Legendary - Heroic in
			-- (0, 0.08] (was Legendary 0.25-0.42 with its fourth, legendary line)
			target(
				rows,
				`{id}.legendary`,
				"rarity",
				`{c} {L}: Legendarny − Heroiczny`,
				legendary - heroic,
				1e-9,
				0.08,
				c,
				L
			)
			-- Mythic beats Legendary: Mythic - Legendary strictly above 0.
			target(
				rows,
				`{id}.mythic`,
				"rarity",
				`{c} {L}: Mityczny − Legendarny`,
				mythic - legendary,
				1e-9,
				nil,
				c,
				L
			)
		end
	end
	local twoHanded = {
		{ "Warrior", { "sword2h", "axe2h", "hammer2h", "spear2h" } },
		{ "Mage", { "staff", "runestaff" } },
		{ "Cleric", { "holystaff" } },
	}
	for _, case in twoHanded do
		local c = case[1] :: string
		for _, L in { 5, 10, 20 } do
			local base = Balance.power(Balance.player(c, L)) ^ 2
			for _, weapon in case[2] :: { string } do
				local score = Balance.power(Balance.player(c, L, { weapon = weapon, offhand = false })) ^ 2
				-- S64: the shield's Parry and the protection lines pull 1H + shield ahead (lower bound 0.97 -> 0.93).
				local id = `S32.twohand.{c}.{weapon}.{L}`
				target(rows, id, "twohand", `{c} {weapon} {L}: moc² / 1H`, score / base, 0.93, 1.035, c, L)
			end
		end
	end
	do
		local cleaver = Balance.playerFromItems("Warrior", 20, {
			{
				uid = "c",
				id = "unique_grimrok_cleaver",
				rarity = 5,
				ilvl = 20,
				bonuses = {},
				up = 0,
				bound = false,
				n = 1,
			},
		})
		local legendary = Balance.player("Warrior", 20, {
			ilvl = 20,
			weapon = "axe1h",
			rarity = Rarities.LEGENDARY,
			offhand = false,
			armor = false,
			jewellery = false,
		})
		local m = Balance.monster(Balance.GENERIC, 20)
		-- Grimrok's Mythic cleaver beats a Legendary axe of level 20 (ratio strictly above 1).
		local ratio = Balance.dps(cleaver, m) / Balance.dps(legendary, m)
		target(
			rows,
			"S32.cleaver.dps",
			"cleaver",
			"Tasak Grimroka / Legendarny topór L20 (DPS)",
			ratio,
			1 + 1e-9,
			nil,
			"Warrior",
			20
		)
	end
	do
		local armour = (Items.bases.byType.armor_light.stats :: any)(20)
		local talisman = (Items.bases.byType.talisman.stats :: any)(20)
		target(rows, "S32.jewellery.lightArmourHp", "jewellery", "Lekka zbroja L20: HP", armour.hp, 1e-9, nil, nil, 20)
		target(rows, "S32.jewellery.talismanHp", "jewellery", "Talizman L20: HP", talisman.hp, 1e-9, nil, nil, 20)
		target(
			rows,
			"S32.jewellery.talismanArmor",
			"jewellery",
			"Talizman L20: pancerz",
			talisman.armor,
			1e-9,
			nil,
			nil,
			20
		)
		for _, c in Balance.CLASSES do
			local with = Balance.power(Balance.player(c, 20))
			local without = Balance.power(Balance.player(c, 20, { jewellery = false }))
			target(
				rows,
				`S32.jewellery.{c}`,
				"jewellery",
				`{c} 20: biżuteria (moc)`,
				with / without - 1,
				0.08,
				0.3,
				c,
				20
			)
		end
	end
	-- Drops, rewards, gold
	for _, L in { 10, 15, 18 } do
		local pace = Balance.pace("Warrior", L)
		local uniques = (pace.kills + Balance.questKills(L)) * Balance.itemsPerKill("normal", Rarities.UNIQUE)
		local heroic = 3600 / Balance.eliteCadence("Warrior", L) * Balance.itemsPerKill("elite", Rarities.HEROIC)
		target(
			rows,
			`S32.drops.unique.{L}`,
			"drops",
			`{L}: Unikatowe do klasy na poziom`,
			uniques,
			0.5,
			1.6,
			"Warrior",
			L
		)
		target(
			rows,
			`S32.drops.heroic.{L}`,
			"drops",
			`{L}: Heroiczne do klasy na godzinę`,
			heroic,
			0.5,
			1.5,
			"Warrior",
			L
		)
	end
	do
		local bear = MonsterStats.kindReward(Monsters.get("brownBear") :: any)
		local rabbit = MonsterStats.kindReward(Monsters.get("rabbit") :: any)
		target(
			rows,
			"S32.kinds.brownBear",
			"kinds",
			"Niedźwiedź brunatny: mnożnik nagrody (> 1,1)",
			bear,
			1.1 + 1e-9
		)
		target(rows, "S32.kinds.rabbit", "kinds", "Królik: mnożnik nagrody (< 0,7)", rabbit, nil, 0.7 - 1e-9)
	end
	for _, def in Monsters.list do
		if def.region == 1 then
			local L = math.floor((def.levels.min + def.levels.max) / 2)
			local p = Balance.player("Warrior", L)
			local own = Balance.killExp(L, def, L) / Balance.duel(p, Balance.monster(def, L)).seconds
			local generic = Balance.killExp(L, Balance.GENERIC, L)
				/ Balance.duel(p, Balance.monster(Balance.GENERIC, L)).seconds
			target(
				rows,
				`S32.kinds.{def.id}`,
				"kinds",
				`{def.id}: EXP/s ÷ zwykły`,
				own / generic,
				0.85,
				1.2,
				"Warrior",
				L
			)
		end
	end
	for _, c in Balance.CLASSES do
		local eco = Balance.economy(c, 20)
		for _, r in eco.rows do
			if r.level >= 4 then
				local id = `S32.economy.{c}.{r.level}.up3`
				target(
					rows,
					id,
					"economy",
					`{c} {r.level}: +1…+3 broni / dochód poziomu`,
					r.up3 / r.income,
					nil,
					1.05,
					c,
					r.level
				)
			end
		end
		local income = eco.killGold + eco.dropGold + eco.questGold
		target(
			rows,
			`S32.economy.{c}.potions`,
			"economy",
			`{c}: mikstury / dochód 1→20`,
			eco.potionGold / income,
			nil,
			0.15,
			c
		)
		local drops = eco.dropGold / eco.killGold
		target(rows, `S32.economy.{c}.drops`, "economy", `{c}: sprzedaż dropu / złoto z zabić`, drops, 0.3, 0.55, c)
	end
	-- S91: the new targets of the 1-20 retune (ids "S91.*"), asserted by the block "Balance 1-20: S91"
	for _, row in Balance.targetsS91() do
		table.insert(rows, row)
	end
	return rows
end

-- S91: levels 1-20 retuned and frozen ------------------------------------------------------------------------------

-- Thresholds of the new 1-20 targets (docs/sessions S91 "Cele 1–20"; test data, never game numbers).
Balance.S91 = {
	-- tempo (B2, plan D4): m(L) / m(L - 1) <= step for L = from..20, >= mono for L = from..19, h(20) / h(19) <= raw,
	-- sum h(1..19) within hours (definition S91; 05b859d about 2.3 h)
	pace = { from = 8, step = 1.30, mono = 0.97, raw = 1.30, hours = { 1.8, 2.8 } },
	r1Low = 1.6, -- ROZWOJ 0
	r1Factor = 1.15, -- R1 <= 1.15 x D1 of the class (definition S91)
	tsk2Factor = 1.25, -- T-SK2 <= 1.25 x D1 (plan D1)
	gain = 1.03, -- the build's damage / the same build without nodes at L20 (ROZWOJ 2.5)
	smooth = 1.05, -- R1 at 5 / 10 / 15 <= 1.05 x R1 at 20 (S91)
	tsk6 = { 1.0, 2.0 }, -- plan D1, ROZWOJ 0
	-- Grimrok bez wsparcia (owner answer 26, ROZWOJ 7.5; S92 C3 counts Morvane the same): (a) fight <= timeShare x
	-- enrageAfter, (b) damage taken / (potions + regeneration in combat + life steal) <= sustain, (c) no hit above
	-- `hit` x the member's max HP
	noSupport = { timeShare = 0.8, sustain = 1.0, hit = 1.0 },
	-- the damage builds of R1, T-SK2 and the row gain (the Hunter with each weapon of its measurement, S90)
	damage = {
		{ classId = "Warrior", key = "berserker.fury" },
		-- S143 (session rule 4): the Warrior with Sword and Shield (the one-handed pool) holds the S91 targets of 20 too
		{ classId = "Warrior", key = "standard.commander" },
		-- S145 (session rule 4): the Inquisitor plays the Mace and Flail pool (a mace); the light pool's T-SK5 at 20 is a
		-- row of Balance.targetsS145
		{ classId = "Cleric", key = "inquisitor.solo" },
		-- S144 (session rule 4): the Hunter with a bow (the Bow pool: the Marksman's longbow, the Trapper with a bow) and
		-- with a crossbow (the Crossbow pool: the Trapper's crossbow, the Marksman with the heavy crossbow)
		{ classId = "Hunter", key = "marksman.kingslayer" },
		{ classId = "Hunter", key = "marksman.kingslayer", weapon = "heavycrossbow" },
		{ classId = "Hunter", key = "trapper.poacher" },
		{ classId = "Hunter", key = "trapper.poacher", weapon = "bow" },
		{ classId = "Mage", key = "destroyer.destroyerExp", area = true },
		{ classId = "Mage", key = "destroyer.destroyerBoss" },
		{ classId = "Mage", key = "arcanist.arcanistBoss" },
		-- S141 (session rule 4): the Mage with an ice weapon (the ice pool alone) holds the S91 targets of 20 too
		{ classId = "Mage", key = "destroyer.destroyerIce", area = true },
		{ classId = "Mage", key = "arcanist.arcanistIce" },
		-- S142 (session rule 4): the Mage with a lightning weapon (the lightning pool alone) too
		{ classId = "Mage", key = "destroyer.destroyerLightning", area = true },
		{ classId = "Mage", key = "arcanist.arcanistLightning" },
	} :: { { classId: string, key: string, weapon: string?, area: boolean? } },
	-- breakpoints of rank 5 reached by level 20 (ranks 5 at 17 / 19, ROZWOJ 2.5)
	r4Skills = {
		"holyStrike",
		"mightyStrike",
		"aimedShot",
		"firebolt",
		"heal",
		"charge",
		"fireball",
		"iceShard", -- S141: unlock 1 / 3, ranks 5 at 17 / 19
		"hailstorm",
		"lightningBolt", -- S142: unlock 1 / 3, ranks 5 at 17 / 19
		"chainLightning",
		"brutalStrike", -- S143: unlock 1 / 3, ranks 5 at 17 / 19 (the Warrior's pools)
		"cleave",
		"shieldSweep",
		-- S144: unlock 1 / 3, ranks 5 at 17 / 19 (the Hunter's pools); Double Shot left (unlock 15, rank 5 at 31)
		"heavyBolt",
		"arrowRain",
		"piercingArrow",
		-- S145: unlock 1 / 3, ranks 5 at 17 / 19 (the Cleric's pools: Light Ray and Radiance on the Healer, Consecrate on
		-- the Inquisitor)
		"lightRay",
		"radiance",
		"consecrate",
	},
	-- PATH_TARGETS ids whose row at 20 is a target of the 1-20 table (E9): T-SK3 and the solo pace of support and
	-- tank paths; every other row at 20 is printed (bands written for 45-100)
	pathRows = {
		["all.tsk3"] = true,
		["mage.tsk3"] = true,
		["trapper.r3"] = true,
		["warrior.solo"] = true,
		["cleric.solo"] = true,
		["scout.solo"] = true,
	} :: { [string]: boolean },
	-- the Grimrok team without support (L19, from the combat paths trimmed to 19): 3 / 4 / 5 members
	noSupportTeam = {
		"berserker.fury",
		"marksman.kingslayer",
		"arcanist.arcanistBoss",
		"inquisitor.solo",
		"destroyer.destroyerBoss",
	},
}

export type NoSupportMember = {
	key: string,
	classId: string,
	maxHp: number,
	dps: number, -- the skill model's DPS on the boss (x BOSS_UPTIME, as in the fight)
	taken: number, -- damage taken per second over the fight
	sustain: number, -- potions (Balance.potionHps) + regeneration in combat + life steal, per second
	ratio: number,
	biggest: number, -- the biggest single hit this member's class takes / its max HP
	potions: number, -- potions drunk over the fight (taken HP beyond regeneration and life steal / the best potion)
}
export type NoSupport = { seconds: number, limit: number, members: { NoSupportMember }, fight: BossFight }

local noSupportCache: { [string]: NoSupport } = {}
-- S91 (D3, odpowiedź 26, ROZWOJ 7.5): `bossId` against the first `n` builds of S91.noSupportTeam trimmed to
-- `level` (default boss level - 1): no interception, no heals of others, no taunts (own heals and life steal count).
-- The players' damage is the skill model's (tests/SkillModel.fight on the boss for ASSUMPTIONS.bossSeconds, x the
-- convention's BOSS_UPTIME in Balance.bossFight through `dpsMul`), the boss's damage from Balance.bossFight.
-- S134: `gear` = GearOpts of every member (the solo with overpowered gear: Mythic +9), nil = the convention's.
function Balance.bossNoSupport(bossId: string, n: number, level: number?, gear: GearOpts?): NoSupport
	local def = Bosses.byId[bossId] :: any
	local L = level or def.level - 1
	local key = `{bossId}|{n}|{L}|{if gear then `{gear.rarity or "-"}+{gear.up or 0}` else "-"}`
	local cached = noSupportCache[key]
	if cached then
		return cached
	end
	local SkillModel = (require :: any)("./SkillModel")
	local m = Balance.monster(Balance.bossKind(def), def.level, "boss")
	local team: { Player } = {}
	local mul: { number } = {}
	for i = 1, n do
		local buildKey = Balance.S91.noSupportTeam[i]
		local sp = SkillModel.player(SkillModel.build(buildKey), L, if gear then { gear = gear } else nil)
		local skill = SkillModel.fight(sp, { targets = { m }, seconds = SkillModel.ASSUMPTIONS.bossSeconds }).dps
		team[i] = sp.p
		mul[i] = skill / math.max(1e-9, Balance.dps(sp.p, m))
	end
	local fight = Balance.bossFight(bossId, team, { dpsMul = mul })
	local potionHps = Balance.potionHps(L)
	local best = allowedPotions(L)
	local potionHeal = if #best > 0 then best[#best].heal else 0
	local members: { NoSupportMember } = {}
	for i, p in team do
		local own = Balance.dps(p, m) * mul[i] * Balance.BOSS_UPTIME
		local regen = p.values.hpRegenCombat or 0
		local steal = math.min(p.values.lifesteal or 0, 15) / 100 * own -- mirrors Damage.computeDamage's cap of 15
		local sustain = potionHps + regen + steal
		local taken = fight.memberDps[i]
		table.insert(members, {
			key = Balance.S91.noSupportTeam[i],
			classId = p.classId,
			maxHp = p.values.maxHp,
			dps = own,
			taken = taken,
			sustain = sustain,
			ratio = taken / math.max(1e-9, sustain),
			biggest = fight.biggestHit[p.classId] or 0,
			potions = if potionHeal > 0 then math.max(0, taken - regen - steal) * fight.seconds / potionHeal else 0,
		})
	end
	local out: NoSupport = {
		seconds = fight.seconds,
		limit = Balance.S91.noSupport.timeShare * def.enrageAfter,
		members = members,
		fight = fight,
	}
	noSupportCache[key] = out
	return out
end

-- S91 (H1): the new 1-20 targets in one place (ids "S91.<group>..."); balance.spec ("Balance 1-20: S91") asserts
-- the rows without `report`, the report prints them all. The S32 rows (with the variants with nodes) stay above.
function Balance.targetsS91(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S91
	local SkillModel = (require :: any)("./SkillModel")
	local D1 = SkillModel.GUARD_D1
	local function add(
		id: string,
		group: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		c: string?,
		L: number?
	)
		target(rows, `S91.{id}`, group, label, value, low, high, c, L)
	end
	-- tempo: the window model from level 1 (B2), Warrior, GENERIC, rest, no boss quests
	do
		local P = S.pace
		local sum = 0
		for L = 1, 19 do
			sum += Balance.paceWindowAt("Warrior", L).hours
		end
		add("pace.sum", "pace", "Tempo 1 → 20 (okno, bez Grimroka): h", sum, P.hours[1], P.hours[2], "Warrior")
		for L = P.from, 20 do
			local r = Balance.paceWindowMean("Warrior", L) / math.max(1e-9, Balance.paceWindowMean("Warrior", L - 1))
			local low = if L <= 19 then P.mono else nil
			add(`pace.m.{L}`, "pace", `Tempo: m({L}) / m({L - 1})`, r, low, P.step, "Warrior", L)
		end
		local raw = Balance.paceWindowAt("Warrior", 20).hours
			/ math.max(1e-9, Balance.paceWindowAt("Warrior", 19).hours)
		add("pace.raw.20", "pace", "Tempo: h(20) / h(19)", raw, nil, P.raw, "Warrior", 20)
	end
	-- S134: Grimrok's fight length and biggest blows are Balance.targetsS134 rows (bosses 2.0)
	-- T-SK6 (plan D1, S86 F4): the dungeon Healer on the Defender (team S92) at the boss level - 1
	do
		local healer = SkillModel.build("healer.dungeon", "Cleric")
		local r = SkillModel.healerVsBoss(healer, "grimrok", { team = "s92" })
		local label = "T-SK6 Grimrok: Uzdrowiciel lochowy na Obrońcy"
		add("grimrok.tsk6", "grimrok", label, r.tsk6, S.tsk6[1], S.tsk6[2], "Cleric", 19)
	end
	-- Grimrok bez wsparcia (D3)
	for n = 3, 5 do
		local r = Balance.bossNoSupport("grimrok", n)
		add(
			`grimrok.noSupport.{n}.seconds`,
			"noSupport",
			`Grimrok bez wsparcia, {n} graczy: s`,
			r.seconds,
			nil,
			r.limit,
			nil,
			19
		)
		local worst, hit = 0, 0
		for _, mem in r.members do
			worst = math.max(worst, mem.ratio)
			hit = math.max(hit, mem.biggest)
		end
		local label = `Grimrok bez wsparcia, {n} graczy: przyjmowane / podtrzymanie (najgorszy)`
		add(`grimrok.noSupport.{n}.sustain`, "noSupport", label, worst, nil, S.noSupport.sustain, nil, 19)
		local hitLabel = `Grimrok bez wsparcia, {n} graczy: największy cios / HP`
		add(`grimrok.noSupport.{n}.hit`, "noSupport", hitLabel, hit, nil, S.noSupport.hit, nil, 19)
	end
	-- skill layer at L20 (E2): R1, T-SK2, the gain of rows 1-2 of the damage builds, smoothness at 10 / 15
	for _, spec in S.damage do
		local build = SkillModel.build(spec.key, spec.classId)
		if spec.weapon then
			build = SkillModel.withWeapon(build, spec.weapon, "quiver")
		end
		local ids: { string } = {}
		for _, node in build.nodes do
			table.insert(ids, node[1])
		end
		local bare = SkillModel.withoutNodes(build, ids)
		local m, m0 = SkillModel.metrics(build, 20), SkillModel.metrics(bare, 20)
		local c = spec.classId
		local name = build.key
		add(`r1.{name}`, "skills", `R1 {name} L20`, m.r1, S.r1Low, S.r1Factor * D1.tsk1[c], c, 20)
		add(`tsk2.{name}`, "skills", `T-SK2 {name} L20`, m.tsk2, nil, S.tsk2Factor * D1.tsk2[c], c, 20)
		local gain = if spec.area
			then m.aoe3burst / math.max(1e-9, m0.aoe3burst)
			else m.single60 / math.max(1e-9, m0.single60)
		local what = if spec.area then " (obszar 8 s)" else ""
		add(`gain.{name}`, "skills", `{name} L20: obrażenia / bez węzłów{what}`, gain, S.gain, nil, c, 20)
		for _, L in { 10, 15 } do
			local r = SkillModel.metrics(build, L).r1 / math.max(1e-9, m.r1)
			add(`smooth.{name}.{L}`, "skills", `R1 {name} L{L} / L20`, r, nil, S.smooth, c, L)
		end
	end
	for _, c in Balance.CLASSES do
		local base = SkillModel.build("base", c)
		local r20 = SkillModel.metrics(base, 20).r1
		for _, L in { 5, 10, 15 } do
			local r = SkillModel.metrics(base, L).r1 / math.max(1e-9, r20)
			add(`smooth.base.{c}.{L}`, "skills", `R1 podstawy {c} L{L} / L20`, r, nil, S.smooth, c, L)
		end
	end
	-- R4 of the breakpoints of rank 5 reached by 20 (S89 E1 definition; R4_UTILITY options are printed by the paths
	-- block)
	local band = SkillModel.R4_BANDS[5]
	for _, skillId in S.r4Skills do
		local def = SkillData.get(skillId) :: any
		local key = SkillModel.R4_SUPPORT_BUILDS[skillId] or SkillModel.R4_CLASS_BUILDS[def.class]
		local build = SkillModel.build(key)
		local values: { [string]: number } = {}
		for _, choice in { "a", "b" } do
			if SkillModel.R4_UTILITY[`{skillId}:5{choice}`] then
				continue
			end
			local v = SkillModel.optionGain(build, skillId, 5, choice, 20)
			if v then
				local label = `R4 {skillId} 5{string.upper(choice)} L20 ({key})`
				add(`r4.{skillId}.5{choice}`, "r4", label, v, band[1], band[2], def.class, 20)
				if SkillModel.R4_REPORT[`{skillId}:5{choice}`] then
					rows[#rows].report = "właściciel (R4_REPORT)"
				else
					values[choice] = v
				end
			end
		end
		if values.a and values.b then
			local diff = math.abs(values.a - values.b)
			add(
				`r4.{skillId}.5.diff`,
				"r4",
				`R4 {skillId} 5: |A − B| L20`,
				diff,
				nil,
				SkillModel.R4_DIFF,
				def.class,
				20
			)
		end
	end
	-- PATH_TARGETS rows at 20 that are 1-20 targets (E9)
	for _, r in SkillModel.evaluateTargets() do
		if r.L == 20 and S.pathRows[r.id] then
			local note = if r.note then ` {r.note}` else ""
			local id = `path.{r.id}.{r.build}{if r.note then "." .. r.note else ""}`
			add(id, "paths20", `{r.id} {r.build} L20{note}`, r.value, r.low, r.high, r.classId, 20)
		end
	end
	-- H5: rows out of reach of the S91 levers, printed (the why in Balance.S91_REPORT)
	for _, row in rows do
		local why = Balance.S91_REPORT[row.id]
		if why then
			row.report = `właściciel: {why}`
		end
	end
	return rows
end

-- S91 (H5): rows of targetsS91 out of reach of the S91 levers (printed with the reason; docs/DECYZJE.md S91).
Balance.S91_REPORT = {
	-- S143: the one-handed Standard-Bearer's rows 1-2 at 20 deal no damage (support nodes; Battle Cry from 30, the old
	-- Cleave node went to the two-handed pool)
	["S91.gain.standard.commander"] = "Chorąży z bronią jednoręczną: węzły rzędów 1–2 wsparcia, bez obrażeń na 20 (S143)",
	-- S91: obrażenia rzędów 1-2 Strzelca i Trapera z kuszą poza zasięgiem dźwigni S91: węzły rzędów 1-2 (Pewna Ręka,
	-- Jad Myśliwski) są globalne, a Pewna Ręka 1,5-4 (+0,5 pkt) psuje trapper.aoe na 45 (1,15 -> 1,146, S90);
	-- Przebijająca Strzała rzędu 1 ma 2% obrażeń i rangę 3 na 18. (przypięta 4. ranga)
	-- S144: "Królobójca" plays the Bow with a longbow (was the heavy crossbow), the Crossbow measured with the heavy
	-- crossbow; Archer's Rhythm (row 2) works on the Bow's Aimed Shot only
	["S91.gain.marksman.kingslayer"] = "rzędy 1–2 Strzelca z długim łukiem +2,6% (dźwignie globalne psują S90)",
	["S91.gain.marksman.kingslayer@heavycrossbow+quiver"] = "rzędy 1–2 Strzelca z ciężką kuszą +2,9% (S144: Rytm Strzelca tylko na Celnym Strzale łuku)",
	["S91.gain.trapper.poacher"] = "rzędy 1–2 Trapera z kuszą +1,4% (dźwignie globalne psują S90)",
	-- S141: przełomy 5B lodu są płaskie, a ranga 5 przypięta nisko (80, R1 na 20); cięcie do pasma na 20 zrzuca R4 na
	-- 45 / 70 / 100 pod 0,08 (Odłamek 0,108, Grad 0,092)
	["S91.r4.iceShard.5b"] = "Lodowy Odłamek 5B +29% na 20 (płaskie +23 na randze 5 = 80; na 45–100 0,108)",
	["S91.r4.hailstorm.5b"] = "Grad 5B +19% na 20 (płaski przełom na niskiej randze 5; na 45–100 0,092)",
} :: { [string]: string }

-- S140: the Mage's fire pool (DESIGN-18 §6.1, §13; docs/sessions S140 D) ------------------------------------------

-- The fire variants of the Mage's reference builds (Data/Paths/Mage, weapon.element "fire": the fire pool alone) and
-- the levels of their rows. Thresholds are test data (S91's R1 band, the builds' areaCap, DESIGN-18 §6.1 identity).
Balance.S140 = {
	fireBuilds = { "destroyer.destroyerFire", "arcanist.arcanistFire" },
	levels = { 45, 70, 100 },
	tsk4 = { 2.0, 2.8 }, -- the Mage's T-SK4 band (ROZWOJ 12.7, SkillModel.TSK4_BANDS of destroyerExp)
	burnShare = 0.25, -- S140 D2: the burn's share of the fire builds' damage from 45 (dropped by S147, `dropped`)
	-- S147 (docs/DECYZJE.md): not its target; fire's identity is its burn winning 3 targets 8 s (S147.r9.mage.area)
	dropped = "S147: cel wycofany (DECYZJE S147), tożsamość ognia to wygrana z podpaleniem na 3 celach (S147.r9.mage.area)",
	-- DESIGN-18 §6.1 (S147): lightning on one target 1.10-1.20 x fire; fire on 3 targets over 8 s >= lightning
	lightningSingle = { 1.10, 1.20 },
	fireArea = 1.0,
	-- the comparison builds: the same direction with a lightning weapon (S142; before it the lightning element of the
	-- mean builds)
	compare = {
		["destroyer.destroyerFire"] = "destroyer.destroyerLightning",
		["arcanist.arcanistFire"] = "arcanist.arcanistLightning",
	},
}

-- S140 (D): the fire pool's rows (ids "S140.fire.*"). Asserted (balance.spec "Balance S140: fire pool"): R1 of the fire
-- variants at 20 in the S91 band (session rule 4) and T-SK3 within the build's areaCap at 20 / 45 / 70 / 100 (R3).
-- Printed (`report` = the session that asserts them): T-SK4 at 45 / 70 / 100 (S147), the identity of fire (S147:
-- three targets over 8 s against lightning, one target against lightning); the burn's share was dropped by S147.
function Balance.targetsS140(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S140
	local SkillModel = (require :: any)("./SkillModel")
	local D1 = SkillModel.GUARD_D1
	local function add(
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		L: number,
		report: string?
	)
		target(rows, `S140.fire.{id}`, "fire", label, value, low, high, "Mage", L)
		rows[#rows].report = report
	end
	for _, key in S.fireBuilds do
		local build = SkillModel.build(key, "Mage")
		local m20 = SkillModel.metrics(build, 20)
		local cap = build.areaCap or 2.0
		add(`r1.{key}`, `R1 {key} L20 (ogień)`, m20.r1, Balance.S91.r1Low, Balance.S91.r1Factor * D1.tsk1.Mage, 20)
		add(`tsk3.{key}.20`, `T-SK3 {key} L20 (ogień)`, m20.tsk3, nil, cap, 20)
		local other = SkillModel.build(S.compare[key], "Mage")
		for _, L in S.levels do
			local m = SkillModel.metrics(build, L)
			add(`tsk3.{key}.{L}`, `T-SK3 {key} L{L} (ogień)`, m.tsk3, nil, cap, L)
			add(`tsk4.{key}.{L}`, `T-SK4 {key} L{L} (ogień)`, m.tsk4, S.tsk4[1], S.tsk4[2], L, "S147")
			add(
				`burnShare.{key}.{L}`,
				`Udział podpalenia w obrażeniach {key} L{L}`,
				m.shares.burn or 0,
				S.burnShare,
				nil,
				L,
				S.dropped
			)
			local om = SkillModel.metrics(other, L)
			local lightning = if om.byElement then om.byElement.lightning else om
			if key == "destroyer.destroyerFire" then
				add(
					`area.{L}`,
					`Ogień / błyskawica: 3 cele przez 8 s L{L}`,
					m.aoe3burst / math.max(1e-9, lightning.aoe3burst),
					S.fireArea,
					nil,
					L,
					"S147"
				)
			else
				add(
					`single.{L}`,
					`Błyskawica / ogień: jeden cel 60 s L{L}`,
					lightning.single60 / math.max(1e-9, m.single60),
					S.lightningSingle[1],
					S.lightningSingle[2],
					L,
					"S147"
				)
			end
		end
	end
	return rows
end

-- S141: the Mage's ice pool (DESIGN-18 §6.1, §13; docs/sessions S141 C) ---------------------------------------------

-- The ice variants of the Mage's reference builds (Data/Paths/Mage, weapon.element "ice": the ice pool alone; their R1
-- at 20 is a row of the S91 block, session rule 4) and the identity of ice (DESIGN-18 §6.1, asserted by S147).
Balance.S141 = {
	iceBuilds = { "destroyer.destroyerIce", "arcanist.arcanistIce" },
	levels = { 45, 70, 100 },
	tsk4 = { 2.0, 2.8 }, -- the Mage's T-SK4 band (as S140)
	single = { 0.85, 0.95 }, -- ice / fire on one target 60 s (the Arcanist's variants)
	control = 0.6, -- the Elite slowed or frozen at least this share of the fight
	deepChill = 0.5, -- the boss under the Mage's Deep Chill at least this share of the boss window
	taken = 0.85, -- damage taken by the ice variant / the fire variant in the Elite fight (S147: ice < fire, `dropped`)
	dropped = "S147: próg 0,85 zastąpiony celem lód < ogień (S147.r9.mage.taken.ice, DECYZJE S147)",
	compare = {
		["destroyer.destroyerIce"] = "destroyer.destroyerFire",
		["arcanist.arcanistIce"] = "arcanist.arcanistFire",
	},
}

-- S141 (C): the ice pool's rows (ids "S141.ice.*"). Asserted (balance.spec "Balance S141: ice pool"): T-SK3 within the
-- build's areaCap at 20 / 45 / 70 / 100 (R3). Printed (`report` = the session that asserts them): T-SK4 at 45 / 70 /
-- 100 and the identity of ice (one target against fire, the Elite's slow or freeze, the boss's Deep Chill) at 20 / 45 /
-- 70 / 100 (S147); the damage taken against fire at most 0.85 was replaced by S147 (ice < fire).
function Balance.targetsS141(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S141
	local SkillModel = (require :: any)("./SkillModel")
	local function add(
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		L: number,
		report: string?
	)
		target(rows, `S141.ice.{id}`, "ice", label, value, low, high, "Mage", L)
		rows[#rows].report = report
	end
	for _, key in S.iceBuilds do
		local build = SkillModel.build(key, "Mage")
		local fire = SkillModel.build(S.compare[key], "Mage")
		local cap = build.areaCap or 2.0
		for _, L in { 20, 45, 70, 100 } do
			local m = SkillModel.metrics(build, L)
			local mf = SkillModel.metrics(fire, L)
			add(`tsk3.{key}.{L}`, `T-SK3 {key} L{L} (lód)`, m.tsk3, nil, cap, L)
			if L > 20 then
				add(`tsk4.{key}.{L}`, `T-SK4 {key} L{L} (lód)`, m.tsk4, S.tsk4[1], S.tsk4[2], L, "S147")
			end
			if key == "arcanist.arcanistIce" then
				local single = m.single60 / math.max(1e-9, mf.single60)
				add(`single.{L}`, `Lód / ogień: jeden cel 60 s L{L}`, single, S.single[1], S.single[2], L, "S147")
			end
			local ice, flame = SkillModel.chillReport(build, L), SkillModel.chillReport(fire, L)
			add(
				`control.{key}.{L}`,
				`Elita spowolniona albo zamrożona {key} L{L}`,
				ice.chilled,
				S.control,
				nil,
				L,
				"S147"
			)
			add(
				`deepChill.{key}.{L}`,
				`Boss pod Głębokim Chłodem {key} L{L}`,
				ice.deepChilled,
				S.deepChill,
				nil,
				L,
				"S147"
			)
			add(
				`taken.{key}.{L}`,
				`Obrażenia przyjmowane lód / ogień (Elita) {key} L{L}`,
				ice.taken / math.max(1e-9, flame.taken),
				nil,
				S.taken,
				L,
				S.dropped
			)
		end
	end
	return rows
end

-- S142: the Mage's lightning pool and the three elements (DESIGN-18 §6.1, §13; docs/sessions S142 D) ----------------

-- The lightning variants of the Mage's reference builds (Data/Paths/Mage, weapon.element "lightning": the lightning pool
-- alone; their R1 at 20 is a row of the S91 block, session rule 4) and the identity of the three elements (DESIGN-18
-- §6.1, asserted by S147). Thresholds are test data.
Balance.S142 = {
	lightningBuilds = { "destroyer.destroyerLightning", "arcanist.arcanistLightning" },
	levels = { 20, 45, 70, 100 },
	tsk4 = { 2.0, 2.8 }, -- the Mage's T-SK4 band (as S140 / S141)
	single = { 1.10, 1.20 }, -- lightning / fire on one target 60 s (the Arcanist's variants)
	areaLow = 1.0, -- lightning on 3 targets 8 s / fire without its burn: at least this (dropped by S147, `dropped`)
	dropped = "S147: cel wycofany (DECYZJE S147), S147 asertuje ogień z podpaleniem ≥ błyskawica (S147.r9.mage.area)",
	areaHigh = 1.0, -- lightning on 3 targets 8 s / fire with its burn: at most this
	ice = { 0.85, 0.95 }, -- ice / fire on one target 60 s (the Arcanist's variants)
	-- the builds compared, by direction
	fire = { destroyer = "destroyer.destroyerFire", arcanist = "arcanist.arcanistFire" },
	iceOf = { destroyer = "destroyer.destroyerIce", arcanist = "arcanist.arcanistIce" },
	lightning = { destroyer = "destroyer.destroyerLightning", arcanist = "arcanist.arcanistLightning" },
}

-- Damage per second of `build` at L on ASSUMPTIONS.areaTargets GENERIC monsters over burstSeconds (T-SK3's fight), with
-- and without the fire school's burn ticks (Logic/Burn.KEY bucket).
local function areaBurst(build: any, L: number): (number, number)
	local SkillModel = (require :: any)("./SkillModel")
	local A = SkillModel.ASSUMPTIONS
	local sp = SkillModel.player(build, L)
	local three = {}
	for _ = 1, A.areaTargets do
		table.insert(three, Balance.monster(Balance.GENERIC, L))
	end
	local r = SkillModel.fight(sp, { seconds = A.burstSeconds, targets = three })
	local burn = (r.by and r.by.burn) or 0
	local seconds = math.max(1e-9, r.seconds)
	return r.dealt / seconds, (r.dealt - burn) / seconds
end

-- S142 (D): the lightning pool's rows (ids "S142.lightning.*") and the three elements (ids "S142.mage.*"). Asserted
-- (balance.spec "Balance S142: lightning pool"): T-SK3 of the lightning variants within the build's areaCap at 20 / 45 /
-- 70 / 100 (R3). Printed (`report` = the session that asserts them): T-SK4 at 45 / 70 / 100 and the identity of the
-- elements at 20 / 45 / 70 / 100: lightning / fire on one target, lightning / fire on three targets over 8 s (against fire
-- with its burn; without it dropped by S147), ice / fire on one target, damage taken ice < fire < lightning (the Elite
-- fight of SkillModel.chillReport, both directions).
function Balance.targetsS142(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S142
	local SkillModel = (require :: any)("./SkillModel")
	local function add(
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		L: number,
		report: string?
	)
		target(rows, id, "lightning", label, value, low, high, "Mage", L)
		rows[#rows].report = report
	end
	for _, key in S.lightningBuilds do
		local build = SkillModel.build(key, "Mage")
		local cap = build.areaCap or 2.0
		for _, L in S.levels do
			local m = SkillModel.metrics(build, L)
			add(`S142.lightning.tsk3.{key}.{L}`, `T-SK3 {key} L{L} (błyskawica)`, m.tsk3, nil, cap, L)
			if L > 20 then
				add(
					`S142.lightning.tsk4.{key}.{L}`,
					`T-SK4 {key} L{L} (błyskawica)`,
					m.tsk4,
					S.tsk4[1],
					S.tsk4[2],
					L,
					"S147"
				)
			end
		end
	end
	for _, L in S.levels do
		local fireA = SkillModel.metrics(SkillModel.build(S.fire.arcanist, "Mage"), L)
		local iceA = SkillModel.metrics(SkillModel.build(S.iceOf.arcanist, "Mage"), L)
		local boltA = SkillModel.metrics(SkillModel.build(S.lightning.arcanist, "Mage"), L)
		local fireSingle = math.max(1e-9, fireA.single60)
		add(
			`S142.mage.single.lightning.{L}`,
			`Błyskawica / ogień: jeden cel 60 s L{L}`,
			boltA.single60 / fireSingle,
			S.single[1],
			S.single[2],
			L,
			"S147"
		)
		add(
			`S142.mage.single.ice.{L}`,
			`Lód / ogień: jeden cel 60 s L{L}`,
			iceA.single60 / fireSingle,
			S.ice[1],
			S.ice[2],
			L,
			"S147"
		)
		local fireWith, fireWithout = areaBurst(SkillModel.build(S.fire.destroyer, "Mage"), L)
		local bolt = SkillModel.metrics(SkillModel.build(S.lightning.destroyer, "Mage"), L).aoe3burst
		add(
			`S142.mage.area.noBurn.{L}`,
			`Błyskawica / ogień bez podpalenia: 3 cele 8 s L{L}`,
			bolt / math.max(1e-9, fireWithout),
			S.areaLow,
			nil,
			L,
			S.dropped
		)
		add(
			`S142.mage.area.burn.{L}`,
			`Błyskawica / ogień z podpaleniem: 3 cele 8 s L{L}`,
			bolt / math.max(1e-9, fireWith),
			nil,
			S.areaHigh,
			L,
			"S147"
		)
		for _, dir in { "destroyer", "arcanist" } do
			local fire = SkillModel.chillReport(SkillModel.build(S.fire[dir], "Mage"), L).taken
			local ice = SkillModel.chillReport(SkillModel.build(S.iceOf[dir], "Mage"), L).taken
			local storm = SkillModel.chillReport(SkillModel.build(S.lightning[dir], "Mage"), L).taken
			add(
				`S142.mage.taken.ice.{dir}.{L}`,
				`Obrażenia przyjmowane lód / ogień (Elita) {dir} L{L}`,
				ice / math.max(1e-9, fire),
				nil,
				1,
				L,
				"S147"
			)
			add(
				`S142.mage.taken.lightning.{dir}.{L}`,
				`Obrażenia przyjmowane błyskawica / ogień (Elita) {dir} L{L}`,
				storm / math.max(1e-9, fire),
				1,
				nil,
				L,
				"S147"
			)
		end
	end
	return rows
end

-- S143 (D, DESIGN-18 §6.2): the Warrior's two pools ----------------------------------------------------------------

-- Thresholds of the Warrior's pool identity (DESIGN-18 §6.2, §13; test data, never game numbers). The R1 of both pools
-- at 20 is in the block "Balance 1-20: S91" (session rule 4); everything here is printed and asserted by S146.
Balance.S143 = {
	levels = { 20, 45, 70, 100 },
	-- the two-handed pool's damage / the one-handed pool's (one target 60 s, 3 targets 8 s): 1.15-1.25 (§6.2)
	twohand = "berserker.fury",
	onehand = "standard.commander",
	damage = { 1.15, 1.25 },
	-- the one-handed pool's EHP / the two-handed pool's: at least 1.4 (§6.2); the Guardian with a shield
	tank = "guardian.defender",
	ehpLow = 1.4,
	-- the tank's HP per minute (the S32 model of S92-S94) with the Guardian's nodes in front of the party
	tankPerMinute = 3.5,
	-- R7 (S89): the Hunter's / the Warrior's damage on one target (both pools)
	hunter = "marksman.kingslayer",
}

-- S143: the Warrior's identity rows (ids "S143.warrior.*"); balance.spec ("Balance S143: Warrior pools") prints them
-- and checks they exist; the rows carry report = "S146" (DESIGN-18 §13: asserted by S146).
function Balance.targetsS143(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S143
	local SkillModel = (require :: any)("./SkillModel")
	local function add(id: string, label: string, value: number, low: number?, high: number?, L: number)
		target(rows, id, "warrior", label, value, low, high, "Warrior", L)
		rows[#rows].report = "S146"
	end
	local two = SkillModel.build(S.twohand, "Warrior")
	local one = SkillModel.build(S.onehand, "Warrior")
	local tankBuild = SkillModel.build(S.tank, "Warrior")
	local hunter = SkillModel.build(S.hunter, "Hunter")
	for _, L in S.levels do
		local m2, m1 = SkillModel.metrics(two, L), SkillModel.metrics(one, L)
		local mt = SkillModel.metrics(tankBuild, L)
		add(
			`S143.warrior.single.{L}`,
			`Dwuręczna / jednoręczna: jeden cel 60 s L{L}`,
			m2.single60 / math.max(1e-9, m1.single60),
			S.damage[1],
			S.damage[2],
			L
		)
		add(
			`S143.warrior.area.{L}`,
			`Dwuręczna / jednoręczna: 3 cele 8 s L{L}`,
			m2.aoe3burst / math.max(1e-9, m1.aoe3burst),
			S.damage[1],
			S.damage[2],
			L
		)
		add(
			`S143.warrior.ehp.{L}`,
			`EHP jednoręczna (Strażnik) / dwuręczna L{L}`,
			mt.ehp / math.max(1e-9, m2.ehp),
			S.ehpLow,
			nil,
			L
		)
		local mh = SkillModel.metrics(hunter, L)
		add(
			`S143.warrior.r7.twohand.{L}`,
			`R7 Łowca / Wojownik dwuręczny: jeden cel L{L}`,
			mh.single60 / math.max(1e-9, m2.single60),
			nil,
			nil,
			L
		)
		add(
			`S143.warrior.r7.onehand.{L}`,
			`R7 Łowca / Wojownik jednoręczny: jeden cel L{L}`,
			mh.single60 / math.max(1e-9, m1.single60),
			nil,
			nil,
			L
		)
		local bossId = SkillModel.BOSS_AT[L]
		if bossId then
			local def = Bosses.byId[bossId] :: any
			local team = Balance.team(5, def.level - 1)
			team[1] = Balance.player("Warrior", def.level - 1, { nodes = S.tank })
			local perMinute = Balance.boss(bossId, team).tankHpPerMinute
			add(
				`S143.warrior.tank.{bossId}`,
				`{bossId} (model S32): Strażnik jednoręczny, HP na minutę L{def.level - 1}`,
				perMinute,
				nil,
				S.tankPerMinute,
				def.level - 1
			)
		end
	end
	return rows
end

-- S144 (D, DESIGN-18 §6.3): the Hunter's two pools ---------------------------------------------------------------

-- Thresholds of the Hunter's pool identity (DESIGN-18 §6.3, §13; test data, never game numbers). The R1 of both pools
-- at 20 is in the block "Balance 1-20: S91" (session rule 4); everything here is printed and asserted by S147.
Balance.S144 = {
	levels = { 20, 45, 70, 100 },
	-- the Bow / the Crossbow on one target 60 s: the same direction (the Marksman) with a longbow and a heavy crossbow,
	-- within ±10 % (§6.3)
	bow = "marksman.kingslayer",
	crossbowWeapon = "heavycrossbow",
	single = { 0.9, 1.1 },
	-- the damage-over-time share (poison, bleed, burn ticks) of the Crossbow's builds on one target 60 s from 45 (§6.3)
	dotBuilds = { "trapper.poacher", "trapper.poisoner" },
	dotFrom = 45,
	dotShare = 0.25,
	-- the Bow in motion: the share of a fight under Wind Step's and Disengage's movement (a cast on cooldown)
	moveBuild = "scout.tracker",
	-- R7 (S89): the Hunter's / the Warrior's damage on one target (both pools against the Berserker)
	warrior = "berserker.fury",
}

-- S144: the share of a fight a skill keeps its caster moving: the movement effect's seconds (a statBuff with
-- moveSpeed or dodge; Disengage without one: its leap, ASSUMPTIONS-free half a second) over the skill's cooldown at the
-- build's rank and choices; 0 without the rank.
local function movingShare(SkillModel: any, build: any, L: number, skillId: string): number
	local ch = SkillModel.character(build, L)
	local character = ch.character
	local rank = Paths.skillRank(character, skillId)
	if rank <= 0 then
		return 0
	end
	local weapons = Paths.weaponTypesOf(character.equipment)
	local def, behaviour = Paths.effectiveFor(character, skillId, weapons, rank)
	local seconds = 0
	local lists: { { any } } = { def.effects or {}, def.selfEffects or {} }
	for _, list in lists do
		for _, effect in list do
			local stats = effect.stats
			if effect.kind == "statBuff" and stats and (stats.moveSpeed or stats.dodge) then
				seconds = math.max(seconds, Skills.scaled(def, effect.duration, rank))
			end
		end
	end
	if seconds <= 0 and def.type == "blink" then
		seconds = 0.5
	end
	return math.min(1, seconds / math.max(1e-9, Skills.cooldown(def, rank, 0, behaviour)))
end

-- S144: the Hunter's identity rows (ids "S144.hunter.*"); balance.spec ("Balance S144: Hunter pools") prints them and
-- checks they exist; the rows carry report = "S147" (DESIGN-18 §13: asserted by S147).
function Balance.targetsS144(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S144
	local SkillModel = (require :: any)("./SkillModel")
	local function add(id: string, label: string, value: number, low: number?, high: number?, L: number)
		target(rows, id, "hunter", label, value, low, high, "Hunter", L)
		rows[#rows].report = "S147"
	end
	local bow = SkillModel.build(S.bow, "Hunter")
	local crossbow = SkillModel.withWeapon(bow, S.crossbowWeapon, "quiver")
	local warrior = SkillModel.build(S.warrior, "Warrior")
	local mover = SkillModel.build(S.moveBuild, "Hunter")
	for _, L in S.levels do
		local mb, mc = SkillModel.metrics(bow, L), SkillModel.metrics(crossbow, L)
		add(
			`S144.hunter.single.{L}`,
			`Łuk / kusza (Strzelec): jeden cel 60 s L{L}`,
			mb.single60 / math.max(1e-9, mc.single60),
			S.single[1],
			S.single[2],
			L
		)
		add(
			`S144.hunter.area.{L}`,
			`Łuk / kusza (Strzelec): 3 cele 8 s L{L}`,
			mb.aoe3burst / math.max(1e-9, mc.aoe3burst),
			nil,
			nil,
			L
		)
		if L >= S.dotFrom then
			for _, key in S.dotBuilds do
				local m = SkillModel.metrics(SkillModel.build(key, "Hunter"), L)
				add(
					`S144.hunter.dot.{key}.{L}`,
					`Udział obrażeń w czasie {key} L{L}`,
					m.dotShare,
					S.dotShare,
					nil,
					L
				)
			end
		end
		local move = movingShare(SkillModel, mover, L, "windstep") + movingShare(SkillModel, mover, L, "disengage")
		add(
			`S144.hunter.move.{L}`,
			`Łuk w ruchu ({S.moveBuild}): Krok Wiatru i Odskok, udział walki L{L}`,
			math.min(1, move),
			nil,
			nil,
			L
		)
		local mw = SkillModel.metrics(warrior, L)
		add(
			`S144.hunter.r7.bow.{L}`,
			`R7 Łowca z łukiem / Wojownik dwuręczny: jeden cel L{L}`,
			mb.single60 / math.max(1e-9, mw.single60),
			nil,
			nil,
			L
		)
		add(
			`S144.hunter.r7.crossbow.{L}`,
			`R7 Łowca z kuszą / Wojownik dwuręczny: jeden cel L{L}`,
			mc.single60 / math.max(1e-9, mw.single60),
			nil,
			nil,
			L
		)
	end
	return rows
end

-- S145 (D, DESIGN-18 §6.4): the Cleric's two pools ---------------------------------------------------------------

-- Thresholds of the Cleric's pool identity (DESIGN-18 §6.4, §13; test data, never game numbers). The R1 of the hammer
-- pool at 20 is in the block "Balance 1-20: S91" (session rule 4); the light pool's T-SK5 at 20 is asserted here, every
-- other row is printed and asserted by S146.
Balance.S145 = {
	levels = { 20, 45, 70, 100 },
	-- the light pool (the dungeon Healer, a scepter) and the hammer pool (the Inquisitor, a mace)
	light = "healer.dungeon",
	hammer = "inquisitor.solo",
	fortune = "fortune.plunder",
	-- T-SK5 at 20 (session rule 4): not below the S91 value (0.221, G10 printed since S91) and within the S87 band's top
	tsk5At20 = { 0.22, 0.35 },
	-- the reference: the model before S145 (commit S144: the Cleric's builds unchanged since S138), the light pool's heal
	-- per second on the tank of the level's boss (healerVsBoss) and the hammer pool's damage on one target 60 s; both
	-- within ±10 % (§6.4, S146)
	before = {
		hps = { [20] = 62.01, [45] = 487.53, [70] = 1382.92, [100] = 2642.37 },
		single = { [20] = 227.17, [45] = 1581.53, [70] = 3948.49, [100] = 8497.83 },
	},
	identity = { 0.9, 1.1 },
	-- R7 (S89): the Cleric's / the Warrior's damage on one target (the hammer pool against the Berserker)
	warrior = "berserker.fury",
}

-- S145: the Cleric's identity rows (ids "S145.cleric.*"); balance.spec ("Balance S145: Cleric pools") asserts the T-SK5
-- row at 20, prints the rest and checks they exist; those rows carry report = "S146" (DESIGN-18 §13).
function Balance.targetsS145(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S145
	local SkillModel = (require :: any)("./SkillModel")
	local function add(
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		L: number,
		asserted: boolean?
	)
		target(rows, id, "cleric", label, value, low, high, "Cleric", L)
		if not asserted then
			rows[#rows].report = "S146"
		end
	end
	local light = SkillModel.build(S.light, "Cleric")
	local hammer = SkillModel.build(S.hammer, "Cleric")
	local fortune = SkillModel.build(S.fortune, "Cleric")
	local warrior = SkillModel.build(S.warrior, "Warrior")
	for _, L in S.levels do
		local tsk5 = SkillModel.oneHeal(light, L, SkillModel.defenderTank(L))
		local band = if L == 20 then S.tsk5At20 else SkillModel.TSK5_BAND
		add(
			`S145.cleric.tsk5.{L}`,
			`T-SK5 berło (Uzdrowiciel lochowy) na Obrońcy L{L}`,
			tsk5,
			band[1],
			band[2],
			L,
			L == 20
		)
		local vsBoss = SkillModel.healerVsBoss(light, SkillModel.BOSS_AT[L])
		if L > 20 then
			add(`S145.cleric.tsk6.{L}`, `T-SK6 berło na {vsBoss.bossId} L{L}`, vsBoss.tsk6, 1.0, 2.0, L)
		end
		add(
			`S145.cleric.light.hps.{L}`,
			`Berło: leczenie na sekundę / Uzdrowiciel sprzed S145 L{L}`,
			vsBoss.hps / math.max(1e-9, S.before.hps[L]),
			S.identity[1],
			S.identity[2],
			L
		)
		local mh = SkillModel.metrics(hammer, L)
		add(
			`S145.cleric.hammer.single.{L}`,
			`Buzdygan: jeden cel 60 s / Inkwizytor sprzed S145 L{L}`,
			mh.single60 / math.max(1e-9, S.before.single[L]),
			S.identity[1],
			S.identity[2],
			L
		)
		local mw = SkillModel.metrics(warrior, L)
		add(
			`S145.cleric.r7.{L}`,
			`R7 Kapłan z buzdyganem / Wojownik dwuręczny: jeden cel L{L}`,
			mh.single60 / math.max(1e-9, mw.single60),
			nil,
			nil,
			L
		)
		add(
			`S145.cleric.fortune.{L}`,
			`Kapłan Fortuny z buzdyganem / Inkwizytor: jeden cel L{L}`,
			SkillModel.metrics(fortune, L).single60 / math.max(1e-9, mh.single60),
			nil,
			nil,
			L
		)
	end
	return rows
end

-- S146 (DESIGN-18 §13): balance 21-100 after the rework, the Warrior and the Cleric -------------------------------

-- Thresholds of the S146 rows (DESIGN-18 §6.2, §6.4, §13, ROZWOJ 0; test data, never game numbers).
Balance.S146 = {
	levels = { 20, 45, 70, 100 },
	pools = { { "Warrior", "onehand" }, { "Warrior", "twohand" }, { "Cleric", "light" }, { "Cleric", "hammer" } },
	-- R8 (§13): 8 actives at rank 10 and every passive of the pool within SkillPoints.pointsAt(100); at most 10 actives
	-- at rank 10; at 45 the points at most this share of the sum of the pool's rank limits
	r8 = { bar = 8, maxTen = 10, budget45 = 0.75 },
	-- R9 Warrior (§6.2): the two-handed / the one-handed pool's damage (one target 60 s, 3 targets 8 s; the damage
	-- builds of the pools, as S143), the one-handed tank's EHP / the two-handed pool's
	twohand = "berserker.fury",
	onehand = "standard.commander",
	tank = "guardian.defender",
	damage = { 1.15, 1.25 },
	ehpLow = 1.4,
	-- the tank's HP per minute on the level's boss (the S32 model of S92-S94) with the Guardian in front
	tankPerMinute = 3.5,
	-- R9 Cleric (§6.4): the light pool's heal per second on the boss's tank in the T-SK6 band (the dungeon Healer,
	-- T-SK6 = R9 of the light pool), the hammer pool's damage against "Furia" in the Inquisitor's bands (ROZWOJ 9.6)
	light = "healer.dungeon",
	hammer = "inquisitor.solo",
	tsk6 = { 1.0, 2.0 },
	hammerRatio = {
		[45] = { 0.80, 0.86 },
		[70] = { 0.85, 0.91 },
		[100] = { 0.87, 0.93 },
	} :: { [number]: { number } },
	-- R1 (ROZWOJ 0, S89): 1.6 <= R1 <= max(2.0, 1.15 x the build's own R1 at 20), one build per pool (the one-handed
	-- pool on its tank: the Standard-Bearer's R1 holds its own cries and banner, printed)
	r1 = {
		{ pool = "twohand", build = "berserker.fury", classId = "Warrior" },
		{ pool = "onehand", build = "guardian.defender", classId = "Warrior" },
		{ pool = "onehand", build = "standard.commander", classId = "Warrior" },
		{ pool = "hammer", build = "inquisitor.solo", classId = "Cleric" },
	},
	r1Band = { 1.6, 2.0 },
	r1Rel = 1.15,
	-- R5 (S89 R5 in the shape of pools): every weapon type of the pool within 10 % of the mean of the types, in the
	-- pool's metric (one target 60 s; the light pool: heal per second on the boss's tank)
	r5 = {
		{ pool = "onehand", build = "standard.commander", classId = "Warrior" },
		{ pool = "twohand", build = "berserker.fury", classId = "Warrior" },
		{ pool = "light", build = "healer.dungeon", classId = "Cleric" },
		{ pool = "hammer", build = "inquisitor.solo", classId = "Cleric" },
	},
	r5Spread = 0.10,
	-- R6 (S89 E3, now the build's leading direction): a point of rows 4-11 within 0.6-1.5 x the mean (L100)
	r6 = {
		{ build = "berserker.fury", classId = "Warrior" },
		{ build = "guardian.defender", classId = "Warrior" },
		{ build = "standard.commander", classId = "Warrior" },
		{ build = "healer.dungeon", classId = "Cleric" },
		{ build = "fortune.plunder", classId = "Cleric" },
		{ build = "inquisitor.solo", classId = "Cleric" },
	},
	r6Band = { 0.6, 1.5 },
	-- T-SK5 (ROZWOJ 0, 7.5): one Heal of the light pool 25-35 % of the tank's HP (the Defender)
	tsk5 = { 0.25, 0.35 },
	-- R7 (ROZWOJ 0): the Hunter / the Warrior on one target 1.15-1.35, printed (S147 asserts it with the Hunter)
	hunter = "marksman.kingslayer",
	r7 = { 1.15, 1.35 },
	-- ROZWOJ 7.5: Fortune's 4 x (1 + B) + S (dice and wheel on an ally, own damage / "Furia"), printed: 7.5 gives
	-- Fortune survival and loot instead
	fortune = "fortune.plunder",
	support = { 4.9, 5.1 },
}

-- S146: rows printed with the reason (id or a prefix ending in `*`; docs/DECYZJE.md S146). Never an R8 or R4 row.
Balance.S146_REPORT = {
	-- R9 of the Warrior's damage against R1: the one-handed pool's basic attack is about half the two-handed one's
	-- (weapon bases, Rarities.twoHandedBonusMul), so 1.25 needs the one-handed pool's R1 at 2.9-3.4 against its limit
	-- 2.26-2.35; at 45-100 the one-handed area (Earthquake, Shield Sweep, the banner) is as strong as the two-handed one,
	-- and a stronger Fury area slows the Guardian's solo pace (pace / Fury <= 1.5 at 45); 20 is frozen
	["S146.r9.warrior.single.*"] = "S146: poza zasięgiem dźwigni S146: R9 1,15–1,25 sprzeczne z R1 puli jednoręcznej (atak podstawowy broni jednoręcznej ok. 0,5 dwuręcznej; Items/Bases, twoHandedBonusMul); 20 zamrożone; dla właściciela",
	["S146.r9.warrior.area.*"] = "S146: poza zasięgiem dźwigni S146: obszar puli jednoręcznej (Trzęsienie Ziemi, Zamach Tarczą, sztandar) nie mniejszy niż dwuręcznej; mocniejszy obszar Furii psuje tempo Strażnika (≤ 1,5); 20 zamrożone",
	-- T-SK6 (S92 C4): the boss's tank takes 1.5-3.5 max HP a minute (the S32 model), Heal alone (T-SK5 0.28-0.34 every
	-- 3 s) gives T-SK6 above 1.5; T-SK6 x the sustain without support is about 2.55 (every boss without support,
	-- ROZWOJ 7.5); levers: the bosses' damage on the tank (Data/Bosses) or the definition of T-SK6 (the owner, S93 / S94)
	["S146.r9.light.tsk6.45"] = "S146: poza zasięgiem dźwigni S146: tank bossa przyjmuje 1,5–3,5 maks. HP na minutę, samo Leczenie daje > 1,5; T-SK6 × podtrzymanie bez wsparcia ok. 2,55 (S92); decyzja właściciela (S93, S94)",
	["S146.r9.light.tsk6.70"] = "S146: poza zasięgiem dźwigni S146: tank Azgora przyjmuje 1,5 maks. HP na minutę (S93: 12,8 przed przebudową); decyzja właściciela",
	["S146.r9.light.tsk6.100"] = "S146: poza zasięgiem dźwigni S146: tank Vaelgratha przyjmuje ok. 2 maks. HP na minutę (S94: 15,9 przed przebudową); decyzja właściciela",
	-- R1 of the Inquisitor (S89 F4): 4.4-6.2 at 0.86-0.91 x "Furia"; R1 <= 2.4 needs about 0.35 x "Furia"
	["S146.r1.hammer.*"] = "właściciel (F4, S89): R1 Inkwizytora 4,4–6,2 przy 0,86–0,91 Furii; R1 ≤ 2,4 wymaga ok. 0,35 Furii (słaby atak podstawowy Kapłana)",
	-- the Standard-Bearer's R1 holds its own cries and banner (support); the one-handed pool's R1 is the Defender's
	["S146.r1.onehand.standard.commander.*"] = "S146: R1 Chorążego liczy jego okrzyki i sztandar (wsparcie); R1 puli jednoręcznej asertuje Obrońca",
	-- R7 with the Hunter (S147), Fortune's support (ROZWOJ 7.5: survival and loot instead)
	["S146.r7.*"] = "S147: R7 asertuje sesja Łowcy (odniesienie Furii z S146)",
	["S146.fortune.support.*"] = "ROZWOJ 7.5: Fortuna daje przeżycie i łup zamiast 4 × (1 + B) + S (tylko raport)",
	-- R6 of the other directions (S89: the Inquisitor and the Healer F4, the Guardian and Fortune E3)
	["S146.r6.guardian.*"] = "właściciel (E3, S89): rzędy 4–11 Strażnika to obrona i groźba (EHP, nie obrażenia)",
	["S146.r6.fortune.*"] = "właściciel (E3, S89): rzędy 4–11 Fortuny to szczęście i łup (poza metryką)",
	["S146.r6.inquisitor.*"] = "właściciel (F4, S89): środkowa część Inkwizytora to przeżycie i odwet (poza metryką)",
	["S146.r6.healer.*"] = "właściciel (F4, S89): najsłabsza część Uzdrowiciela to ratunek i mana (poza metryką)",
} :: { [string]: string }

-- S146: the rows of Balance.S146 (ids "S146.*"); balance.spec ("Balance S146: Warrior and Cleric") asserts every row
-- without `report`.
function Balance.targetsS146(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S146
	local SkillModel = (require :: any)("./SkillModel")
	local SkillPools = require("../src/shared/Logic/SkillPools")
	local SkillPoints = require("../src/shared/Logic/SkillPoints")
	local function reasonOf(id: string): string?
		local hit = Balance.S146_REPORT[id]
		if hit then
			return hit
		end
		for key, why in Balance.S146_REPORT do
			if string.sub(key, -1) == "*" and string.sub(id, 1, #key - 1) == string.sub(key, 1, -2) then
				return why
			end
		end
		return nil
	end
	local function add(
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		classId: string,
		L: number?
	)
		target(rows, id, "s146", label, value, low, high, classId, L)
		rows[#rows].report = reasonOf(id)
	end
	-- R8: the pool's points against its ranks
	for _, pair in S.pools do
		local classId, poolId = pair[1], pair[2]
		do
			local actives, passiveRanks, cap45 = 0, 0, 0
			for _, id in SkillPools.members(classId, poolId) do
				local def = SkillData.get(id) :: any
				if def.type == "passive" then
					passiveRanks += def.maxLevel
				else
					actives += 1
				end
				cap45 += SkillPoints.cap(def, 45)
			end
			local points = SkillPoints.pointsAt(100)
			add(
				`S146.r8.{poolId}.bar100`,
				`R8 {poolId}: {S.r8.bar} aktywnych na 10 + pasywki / punkty na 100`,
				(S.r8.bar * 10 + passiveRanks) / points,
				nil,
				1,
				classId,
				100
			)
			add(
				`S146.r8.{poolId}.max10`,
				`R8 {poolId}: najwięcej aktywnych z rangą 10 na 100`,
				math.min(actives, math.floor(points / 10)),
				S.r8.bar,
				S.r8.maxTen,
				classId,
				100
			)
			add(
				`S146.r8.{poolId}.budget45`,
				`R8 {poolId}: punkty na 45 / suma limitów rang puli`,
				SkillPoints.pointsAt(45) / math.max(1, cap45),
				nil,
				S.r8.budget45,
				classId,
				45
			)
		end
	end
	local two = SkillModel.build(S.twohand, "Warrior")
	local one = SkillModel.build(S.onehand, "Warrior")
	local tankBuild = SkillModel.build(S.tank, "Warrior")
	local light = SkillModel.build(S.light, "Cleric")
	local hammer = SkillModel.build(S.hammer, "Cleric")
	local hunter = SkillModel.build(S.hunter, "Hunter")
	local fortune = SkillModel.build(S.fortune, "Cleric")
	for _, L in S.levels do
		-- R9 Warrior
		local m2, m1, mt = SkillModel.metrics(two, L), SkillModel.metrics(one, L), SkillModel.metrics(tankBuild, L)
		add(
			`S146.r9.warrior.single.{L}`,
			`R9 dwuręczna / jednoręczna: jeden cel 60 s L{L}`,
			m2.single60 / math.max(1e-9, m1.single60),
			S.damage[1],
			S.damage[2],
			"Warrior",
			L
		)
		add(
			`S146.r9.warrior.area.{L}`,
			`R9 dwuręczna / jednoręczna: 3 cele 8 s L{L}`,
			m2.aoe3burst / math.max(1e-9, m1.aoe3burst),
			S.damage[1],
			S.damage[2],
			"Warrior",
			L
		)
		add(
			`S146.r9.warrior.ehp.{L}`,
			`R9 EHP jednoręczna (Strażnik) / dwuręczna L{L}`,
			mt.ehp / math.max(1e-9, m2.ehp),
			S.ehpLow,
			nil,
			"Warrior",
			L
		)
		local bossId = SkillModel.BOSS_AT[L]
		do
			local def = Bosses.byId[bossId] :: any
			local team = Balance.team(5, def.level - 1)
			team[1] = Balance.player("Warrior", def.level - 1, { nodes = S.tank })
			add(
				`S146.warrior.tank.{L}`,
				`{bossId} (model S32): Strażnik jednoręczny, HP na minutę L{def.level - 1}`,
				Balance.boss(bossId, team).tankHpPerMinute,
				nil,
				S.tankPerMinute,
				"Warrior",
				def.level - 1
			)
		end
		-- R9 Cleric: the light pool's T-SK6 (heal per second / the tank's damage), the hammer pool against "Furia"
		local vsBoss = SkillModel.healerVsBoss(light, bossId)
		add(
			`S146.r9.light.tsk6.{L}`,
			`R9 / T-SK6 berło (Uzdrowiciel lochowy) na {bossId} L{L}`,
			vsBoss.tsk6,
			S.tsk6[1],
			S.tsk6[2],
			"Cleric",
			L
		)
		local mh = SkillModel.metrics(hammer, L)
		local band = S.hammerRatio[L]
		if band then
			add(
				`S146.r9.hammer.ratio.{L}`,
				`R9 buzdygan (Inkwizytor) / Furia: jeden cel 60 s L{L}`,
				mh.single60 / math.max(1e-9, SkillModel.fury(L).single60),
				band[1],
				band[2],
				"Cleric",
				L
			)
		end
		if L > 20 then
			-- T-SK5 of the light pool
			add(
				`S146.tsk5.light.{L}`,
				`T-SK5 berło (Uzdrowiciel lochowy) na Obrońcy L{L}`,
				SkillModel.oneHeal(light, L, SkillModel.defenderTank(L)),
				S.tsk5[1],
				S.tsk5[2],
				"Cleric",
				L
			)
			-- R1 of a build per pool
			for _, spec in S.r1 do
				local build = SkillModel.build(spec.build, spec.classId)
				-- the S89 / S91 table of R1 at 20 where it has the build (the all.r1 rows), else its own R1 at 20
				local own = SkillModel.R1_L20[spec.build] or SkillModel.metrics(build, 20).r1
				add(
					`S146.r1.{spec.pool}.{spec.build}.{L}`,
					`R1 {spec.pool} ({spec.build}) L{L}`,
					SkillModel.metrics(build, L).r1,
					S.r1Band[1],
					math.max(S.r1Band[2], S.r1Rel * own),
					spec.classId,
					L
				)
			end
			-- R5: the weapon types of the pool
			for _, spec in S.r5 do
				local build = SkillModel.build(spec.build, spec.classId)
				local def = SkillPools.def(spec.classId, spec.pool) :: any
				local values: { number } = {}
				local sum = 0
				for _, weapon in def.weapon.main do
					local offhand = if Paths.isTwoHanded(weapon) then nil else build.weapon.offhand
					local b = SkillModel.withWeapon(build, weapon, offhand)
					local v = if spec.pool == "light"
						then SkillModel.healerVsBoss(b, bossId).hps
						else SkillModel.metrics(b, L).single60
					table.insert(values, v)
					sum += v
				end
				local mean = sum / math.max(1, #values)
				local worst = 0
				for _, v in values do
					worst = math.max(worst, math.abs(v / math.max(1e-12, mean) - 1))
				end
				add(
					`S146.r5.{spec.pool}.{L}`,
					`R5 {spec.pool} ({spec.build}): najdalszy typ broni od średniej L{L}`,
					worst,
					nil,
					S.r5Spread,
					spec.classId,
					L
				)
			end
			-- R7 (S147) and Fortune's support (ROZWOJ 7.5), printed
			local mh7 = SkillModel.metrics(hunter, L)
			add(
				`S146.r7.twohand.{L}`,
				`R7 Łowca / Wojownik dwuręczny: jeden cel L{L}`,
				mh7.single60 / math.max(1e-9, m2.single60),
				S.r7[1],
				S.r7[2],
				"Warrior",
				L
			)
			local fb = SkillModel.fortuneBonus(fortune, L)
			local sOwn = SkillModel.metrics(fortune, L).single60 / math.max(1e-9, SkillModel.fury(L).single60)
			add(
				`S146.fortune.support.{L}`,
				`Fortuna: 4 × (1 + B) + S (kości i koło, B = {string.format("%.3f", fb.dice + fb.wheel)}) L{L}`,
				4 * (1 + fb.dice + fb.wheel) + sOwn,
				S.support[1],
				S.support[2],
				"Cleric",
				L
			)
		end
	end
	-- R6 of the leading direction at 100
	for _, spec in S.r6 do
		local parts = SkillModel.r6Parts(SkillModel.build(spec.build, spec.classId))
		add(
			`S146.r6.{spec.build}.low`,
			`R6 {spec.build}: najsłabsza trzecia część / średnia L100`,
			parts.low,
			S.r6Band[1],
			nil,
			spec.classId,
			100
		)
		add(
			`S146.r6.{spec.build}.high`,
			`R6 {spec.build}: najmocniejsza trzecia część / średnia L100`,
			parts.high,
			nil,
			S.r6Band[2],
			spec.classId,
			100
		)
	end
	return rows
end

-- S147 (DESIGN-18 §13): balance 21-100 after the rework, the Hunter, the Mage and the bosses -------------------------

-- Thresholds of the S147 rows (DESIGN-18 §6.1, §6.3, §13, ROZWOJ 0, 11.6, 12.0, 12.7; test data, never game numbers).
Balance.S147 = {
	levels = { 20, 45, 70, 100 },
	pools = {
		{ "Hunter", "bow" },
		{ "Hunter", "crossbow" },
		{ "Mage", "fire" },
		{ "Mage", "ice" },
		{ "Mage", "lightning" },
	},
	-- R8 (§13) as S146
	r8 = { bar = 8, maxTen = 10, budget45 = 0.75 },
	-- R9 Mage (§6.1): the Arcanist's element variants on one target 60 s, the Destroyer's on 3 targets 8 s (fire with
	-- its burn), the ice variants' control of the Elite and Deep Chill on the boss, damage taken in the Elite fight
	-- (SkillModel.chillReport) ice < fire < lightning, both directions
	fire = { destroyer = "destroyer.destroyerFire", arcanist = "arcanist.arcanistFire" },
	ice = { destroyer = "destroyer.destroyerIce", arcanist = "arcanist.arcanistIce" },
	lightning = { destroyer = "destroyer.destroyerLightning", arcanist = "arcanist.arcanistLightning" },
	lightningSingle = { 1.10, 1.20 },
	iceSingle = { 0.85, 0.95 },
	fireArea = 1.0, -- fire with its burn / lightning on 3 targets 8 s: at least this
	control = 0.6,
	deepChill = 0.5,
	-- R9 Hunter (§6.3): the Bow / the Crossbow on one target 60 s (the Marksman with a longbow and a heavy crossbow),
	-- the Crossbow's damage-over-time share from 45 (the Trapper's two builds)
	bow = "marksman.kingslayer",
	crossbowWeapon = "heavycrossbow",
	hunterSingle = { 0.9, 1.1 },
	dotBuilds = { "trapper.poacher", "trapper.poisoner" },
	dotShare = 0.25,
	-- R7 (ROZWOJ 0, 11.6): the Hunter / "Furia" on one target 1.15-1.35 at 45-100, both pools of the Marksman (the
	-- Trapper is r7Exempt, 15.4.2); the Warrior of S146 is the reference
	warrior = "berserker.fury",
	r7 = { 1.15, 1.35 },
	-- R5 (S89 R5 in the shape of pools): every weapon type of the pool within 10 % of the mean, in the build's metric
	-- (one target 60 s; the Trapper: 3 targets 8 s); the Mage: wand + orb, wand + tome, staff, runestaff in one element
	r5 = {
		{ pool = "bow", build = "marksman.kingslayer", classId = "Hunter", metric = "single60" },
		{ pool = "crossbow", build = "trapper.poacher", classId = "Hunter", metric = "aoe3burst" },
		{ pool = "fire", build = "arcanist.arcanistFire", classId = "Mage", metric = "single60" },
		{ pool = "ice", build = "arcanist.arcanistIce", classId = "Mage", metric = "single60" },
		{ pool = "lightning", build = "arcanist.arcanistLightning", classId = "Mage", metric = "single60" },
	},
	r5Spread = 0.10,
	-- R1 (ROZWOJ 0, S89): 1.6 <= R1 <= max(2.0, 1.15 x the build's R1 at 20), one build per pool and leading direction
	r1 = {
		{ pool = "bow", build = "marksman.kingslayer", classId = "Hunter" },
		{ pool = "crossbow", build = "trapper.poacher", classId = "Hunter" },
		{ pool = "fire", build = "destroyer.destroyerFire", classId = "Mage" },
		{ pool = "fire", build = "arcanist.arcanistFire", classId = "Mage" },
		{ pool = "ice", build = "destroyer.destroyerIce", classId = "Mage" },
		{ pool = "ice", build = "arcanist.arcanistIce", classId = "Mage" },
		{ pool = "lightning", build = "destroyer.destroyerLightning", classId = "Mage" },
		{ pool = "lightning", build = "arcanist.arcanistLightning", classId = "Mage" },
	},
	r1Levels = { 45, 100 },
	r1Band = { 1.6, 2.0 },
	r1Rel = 1.15,
	-- T-SK3 / R3: area on 3 targets / one target (burst 8 s) within the build's areaCap (Destroyer 3.0, the rest 2.0)
	tsk3Builds = {
		{ build = "destroyer.destroyerFire", classId = "Mage" },
		{ build = "destroyer.destroyerIce", classId = "Mage" },
		{ build = "destroyer.destroyerLightning", classId = "Mage" },
		{ build = "arcanist.arcanistFire", classId = "Mage" },
		{ build = "arcanist.arcanistIce", classId = "Mage" },
		{ build = "arcanist.arcanistLightning", classId = "Mage" },
		{ build = "trapper.poacher", classId = "Hunter" },
	},
	-- T-SK4 (ROZWOJ 12.0 / 12.7): the element variants of each direction from 45 (the Destroyer 2.0-2.8, the Arcanist
	-- 2.0-2.4); the mean builds of three elements are no longer a player's build (DECYZJE S147)
	tsk4 = {
		destroyer = { 2.0, 2.8 },
		arcanist = { 2.0, 2.4 },
	},
	-- the levels of T-SK4: 45 and the levels of the regional rows R.ashen.tsk4 / R.frostpeak.tsk4 (50-100) it replaces
	tsk4Levels = { 45, 50, 55, 60, 65, 69, 70, 75, 80, 85, 90, 95, 99, 100 },
}

-- S147: rows printed with the reason (id or a prefix ending in `*`; docs/DECYZJE.md S147). Never an R8, R7 or R4 row,
-- never an R9 row of the Mage above 20.
Balance.S147_REPORT = {
	-- 1-20 frozen (session rule 4): the K1 stun of lightning (Static Shock, 0.8 s on an Elite) at 20 makes the
	-- lightning variants take 0.97-1.00 x fire; fire and lightning have the same armour and HP, and neither O1 (Ember
	-- Shield, Storm Armor) is on a bar at 20
	["S147.r9.mage.taken.lightning.destroyer.20"] = "1–20 zamrożone: paraliż Porażenia na Elicie (0,8 s) na 20. daje błyskawicy 0,97 ognia; ten sam pancerz i HP, bez osłon żywiołów na pasku",
	["S147.r9.mage.taken.lightning.arcanist.20"] = "1–20 zamrożone: paraliż Porażenia na Elicie (0,8 s) na 20. daje błyskawicy 0,995 ognia; ten sam pancerz i HP, bez osłon żywiołów na pasku",
	-- session rule 5: at 45 the lightning Arcanist's Static Shock stuns the Elite and the fire Arcanist has no stun yet
	-- (Combustion without a rank); without the stun both take exactly the same (52.4 per second): the identity needs a
	-- defensive skill (O1) on the bar or Elites half immune to paralysis, both outside the numbers of this session
	["S147.r9.mage.taken.lightning.arcanist.45"] = "poza zasięgiem dźwigni S147: bez paraliżu Porażenia błyskawica i ogień przyjmują na 45. tyle samo (ten sam pancerz i HP); 0,991; dla właściciela (osłona żywiołu na pasku albo Elity w połowie odporne na paraliż)",
	-- T-SK4 of the element variants on the regional levels (session rule 5; docs/DECYZJE.md S147): one manaCost.Mage
	-- curve for all six variants, whose T-SK4 at one level spreads wider than the band (the steps of the bought ranks);
	-- the ice Destroyer has no rank of Blizzard yet on 65-95 and its spells are the cheapest (dearer ice spells lift the
	-- ice Arcanist above 2.4); the curve never falls, so 80-85 cannot rise without 90-100
	["S147.tsk4.destroyer.destroyerIce.65"] = "poza zasięgiem dźwigni S147: Niszczyciel lodu na 65–95 bez rang Zamieci, czary lodu najtańsze (1,20–1,82); droższy lód podnosi Arkanistę lodu ponad 2,4",
	["S147.tsk4.destroyer.destroyerIce.69"] = "poza zasięgiem dźwigni S147: Niszczyciel lodu na 65–95 bez rang Zamieci, czary lodu najtańsze (1,20–1,82); droższy lód podnosi Arkanistę lodu ponad 2,4",
	["S147.tsk4.destroyer.destroyerIce.70"] = "poza zasięgiem dźwigni S147: Niszczyciel lodu na 65–95 bez rang Zamieci, czary lodu najtańsze (1,20–1,82); droższy lód podnosi Arkanistę lodu ponad 2,4",
	["S147.tsk4.destroyer.destroyerIce.75"] = "poza zasięgiem dźwigni S147: Niszczyciel lodu na 65–95 bez rang Zamieci, czary lodu najtańsze (1,20–1,82); droższy lód podnosi Arkanistę lodu ponad 2,4",
	["S147.tsk4.destroyer.destroyerIce.80"] = "poza zasięgiem dźwigni S147: Niszczyciel lodu na 65–95 bez rang Zamieci, czary lodu najtańsze (1,20–1,82); droższy lód podnosi Arkanistę lodu ponad 2,4",
	["S147.tsk4.destroyer.destroyerIce.85"] = "poza zasięgiem dźwigni S147: Niszczyciel lodu na 65–95 bez rang Zamieci, czary lodu najtańsze (1,20–1,82); droższy lód podnosi Arkanistę lodu ponad 2,4",
	["S147.tsk4.destroyer.destroyerIce.90"] = "poza zasięgiem dźwigni S147: Niszczyciel lodu na 65–95 bez rang Zamieci, czary lodu najtańsze (1,20–1,82); droższy lód podnosi Arkanistę lodu ponad 2,4",
	["S147.tsk4.destroyer.destroyerIce.95"] = "poza zasięgiem dźwigni S147: Niszczyciel lodu na 65–95 bez rang Zamieci, czary lodu najtańsze (1,20–1,82); droższy lód podnosi Arkanistę lodu ponad 2,4",
	["S147.tsk4.destroyer.destroyerFire.55"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.destroyer.destroyerFire.60"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.destroyer.destroyerLightning.55"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.destroyer.destroyerLightning.60"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.arcanist.arcanistFire.50"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.arcanist.arcanistFire.55"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.arcanist.arcanistFire.60"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.arcanist.arcanistFire.65"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.arcanist.arcanistIce.60"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.arcanist.arcanistIce.65"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.arcanist.arcanistIce.69"] = "poza zasięgiem dźwigni S147: na 50–69 ogień i błyskawica Niszczyciela (2,87–2,98) oraz ogień i lód Arkanisty (1,78–1,999) na jednej krzywej manaCost.Mage (skoki rang); wyższa krzywa wypycha Niszczyciela ponad 2,8",
	["S147.tsk4.destroyer.destroyerFire.90"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.destroyer.destroyerFire.95"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.destroyer.destroyerLightning.80"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.destroyer.destroyerLightning.85"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.arcanist.arcanistFire.85"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.arcanist.arcanistFire.90"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.arcanist.arcanistFire.95"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.arcanist.arcanistFire.99"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.arcanist.arcanistLightning.85"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	["S147.tsk4.arcanist.arcanistLightning.90"] = "poza zasięgiem dźwigni S147: na 80–99 skoki rang na jednej krzywej manaCost.Mage (Arkanista ognia 2,41–2,47 na 90–99 przy Niszczycielu ognia 1,90–1,97 na 90–95); krzywa nie spada, więc 80–85 nie wzrosną bez wzrostu 90–100",
	-- R1 of the Hunter and the Mage after 20: owner (S90, S91) as all.r1 of the path rows
	["S147.r1.*"] = "właściciel (S90, S91): R1 Łowcy i Maga na 45–100 to rangi powyżej 20 (pasma S90: Strzelec × baza, R7, pasma 12.7 Maga)",
} :: { [string]: string }

-- S147: the rows of Balance.S147 (ids "S147.*"); balance.spec ("Balance S147: Hunter, Mage and bosses") asserts every
-- row without `report`.
function Balance.targetsS147(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S147
	local SkillModel = (require :: any)("./SkillModel")
	local SkillPools = require("../src/shared/Logic/SkillPools")
	local SkillPoints = require("../src/shared/Logic/SkillPoints")
	local function reasonOf(id: string): string?
		local hit = Balance.S147_REPORT[id]
		if hit then
			return hit
		end
		for key, why in Balance.S147_REPORT do
			if string.sub(key, -1) == "*" and string.sub(id, 1, #key - 1) == string.sub(key, 1, -2) then
				return why
			end
		end
		return nil
	end
	local function add(
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		classId: string,
		L: number?
	)
		target(rows, id, "s147", label, value, low, high, classId, L)
		rows[#rows].report = reasonOf(id)
	end
	-- R8: the pool's points against its ranks
	for _, pair in S.pools do
		local classId, poolId = pair[1], pair[2]
		local actives, passiveRanks, cap45 = 0, 0, 0
		for _, id in SkillPools.members(classId, poolId) do
			local def = SkillData.get(id) :: any
			if def.type == "passive" then
				passiveRanks += def.maxLevel
			else
				actives += 1
			end
			cap45 += SkillPoints.cap(def, 45)
		end
		local points = SkillPoints.pointsAt(100)
		add(
			`S147.r8.{poolId}.bar100`,
			`R8 {poolId}: {S.r8.bar} aktywnych na 10 + pasywki / punkty na 100`,
			(S.r8.bar * 10 + passiveRanks) / points,
			nil,
			1,
			classId,
			100
		)
		add(
			`S147.r8.{poolId}.max10`,
			`R8 {poolId}: najwięcej aktywnych z rangą 10 na 100`,
			math.min(actives, math.floor(points / 10)),
			S.r8.bar,
			S.r8.maxTen,
			classId,
			100
		)
		add(
			`S147.r8.{poolId}.budget45`,
			`R8 {poolId}: punkty na 45 / suma limitów rang puli`,
			SkillPoints.pointsAt(45) / math.max(1, cap45),
			nil,
			S.r8.budget45,
			classId,
			45
		)
	end
	local function mage(key: string): any
		return SkillModel.build(key, "Mage")
	end
	local bow = SkillModel.build(S.bow, "Hunter")
	local crossbow = SkillModel.withWeapon(bow, S.crossbowWeapon, "quiver")
	local warrior = SkillModel.build(S.warrior, "Warrior")
	for _, L in S.levels do
		-- R9 Mage: one target (the Arcanist's variants), 3 targets 8 s (the Destroyer's), control, damage taken
		local fireA = SkillModel.metrics(mage(S.fire.arcanist), L).single60
		local iceA = SkillModel.metrics(mage(S.ice.arcanist), L).single60
		local boltA = SkillModel.metrics(mage(S.lightning.arcanist), L).single60
		add(
			`S147.r9.mage.single.lightning.{L}`,
			`R9 błyskawica / ogień (Arkanista): jeden cel 60 s L{L}`,
			boltA / math.max(1e-9, fireA),
			S.lightningSingle[1],
			S.lightningSingle[2],
			"Mage",
			L
		)
		add(
			`S147.r9.mage.single.ice.{L}`,
			`R9 lód / ogień (Arkanista): jeden cel 60 s L{L}`,
			iceA / math.max(1e-9, fireA),
			S.iceSingle[1],
			S.iceSingle[2],
			"Mage",
			L
		)
		local fireArea = areaBurst(mage(S.fire.destroyer), L)
		local boltArea = SkillModel.metrics(mage(S.lightning.destroyer), L).aoe3burst
		add(
			`S147.r9.mage.area.{L}`,
			`R9 ogień z podpaleniem / błyskawica (Niszczyciel): 3 cele 8 s L{L}`,
			fireArea / math.max(1e-9, boltArea),
			S.fireArea,
			nil,
			"Mage",
			L
		)
		for _, dir in { "destroyer", "arcanist" } do
			local ice = SkillModel.chillReport(mage(S.ice[dir]), L)
			local fire = SkillModel.chillReport(mage(S.fire[dir]), L)
			local storm = SkillModel.chillReport(mage(S.lightning[dir]), L)
			add(
				`S147.r9.mage.control.{dir}.{L}`,
				`R9 lód ({dir}): Elita spowolniona albo zamrożona, udział walki L{L}`,
				ice.chilled,
				S.control,
				nil,
				"Mage",
				L
			)
			add(
				`S147.r9.mage.deepChill.{dir}.{L}`,
				`R9 lód ({dir}): boss pod Głębokim Chłodem, udział okna L{L}`,
				ice.deepChilled,
				S.deepChill,
				nil,
				"Mage",
				L
			)
			add(
				`S147.r9.mage.taken.ice.{dir}.{L}`,
				`R9 obrażenia przyjmowane lód / ogień ({dir}, Elita) L{L}`,
				ice.taken / math.max(1e-9, fire.taken),
				nil,
				1,
				"Mage",
				L
			)
			add(
				`S147.r9.mage.taken.lightning.{dir}.{L}`,
				`R9 obrażenia przyjmowane błyskawica / ogień ({dir}, Elita) L{L}`,
				storm.taken / math.max(1e-9, fire.taken),
				1,
				nil,
				"Mage",
				L
			)
		end
		-- R9 Hunter: the Bow / the Crossbow on one target, the Crossbow's damage over time
		local mb, mc = SkillModel.metrics(bow, L), SkillModel.metrics(crossbow, L)
		add(
			`S147.r9.hunter.single.{L}`,
			`R9 łuk / kusza (Strzelec): jeden cel 60 s L{L}`,
			mb.single60 / math.max(1e-9, mc.single60),
			S.hunterSingle[1],
			S.hunterSingle[2],
			"Hunter",
			L
		)
		if L > 20 then
			for _, key in S.dotBuilds do
				add(
					`S147.r9.hunter.dot.{key}.{L}`,
					`R9 kusza: udział obrażeń w czasie {key} L{L}`,
					SkillModel.metrics(SkillModel.build(key, "Hunter"), L).dotShare,
					S.dotShare,
					nil,
					"Hunter",
					L
				)
			end
			-- R7: the Hunter / "Furia" on one target, both pools of the Marksman
			local mw = SkillModel.metrics(warrior, L)
			add(
				`S147.r7.bow.{L}`,
				`R7 Łowca z łukiem (Strzelec) / Wojownik dwuręczny: jeden cel L{L}`,
				mb.single60 / math.max(1e-9, mw.single60),
				S.r7[1],
				S.r7[2],
				"Hunter",
				L
			)
			add(
				`S147.r7.crossbow.{L}`,
				`R7 Łowca z kuszą (Strzelec) / Wojownik dwuręczny: jeden cel L{L}`,
				mc.single60 / math.max(1e-9, mw.single60),
				S.r7[1],
				S.r7[2],
				"Hunter",
				L
			)
			-- R5: the weapon types of the pool
			for _, spec in S.r5 do
				local build = SkillModel.build(spec.build, spec.classId)
				local def = SkillPools.def(spec.classId, spec.pool) :: any
				local variants: { { any } } = {}
				for _, weapon in def.weapon.main do
					if spec.classId == "Mage" and weapon == "wand" then
						table.insert(variants, { weapon, "orb" })
						table.insert(variants, { weapon, "tome" })
					elseif spec.classId == "Hunter" then
						table.insert(variants, { weapon, "quiver" })
					else
						table.insert(variants, { weapon, nil })
					end
				end
				local values: { number } = {}
				local sum = 0
				for _, v in variants do
					local m = SkillModel.metrics(SkillModel.withWeapon(build, v[1], v[2]), L) :: any
					table.insert(values, m[spec.metric])
					sum += m[spec.metric]
				end
				local mean = sum / math.max(1, #values)
				local worst = 0
				for _, v in values do
					worst = math.max(worst, math.abs(v / math.max(1e-12, mean) - 1))
				end
				add(
					`S147.r5.{spec.pool}.{L}`,
					`R5 {spec.pool} ({spec.build}): najdalszy typ broni od średniej L{L}`,
					worst,
					nil,
					S.r5Spread,
					spec.classId,
					L
				)
			end
			-- T-SK3 / R3
			for _, spec in S.tsk3Builds do
				local build = SkillModel.build(spec.build, spec.classId)
				local m = SkillModel.metrics(build, L)
				add(
					`S147.tsk3.{spec.build}.{L}`,
					`T-SK3 {spec.build} L{L}`,
					m.tsk3,
					nil,
					build.areaCap or 2.0,
					spec.classId,
					L
				)
			end
		end
	end
	-- T-SK4 of the Mage's element variants on the levels of the regional rows
	for _, spec in S.tsk3Builds do
		if spec.classId == "Mage" then
			local build = SkillModel.build(spec.build, "Mage")
			local dir = string.match(spec.build, "^(%a+)%.") :: string
			local band = S.tsk4[dir]
			for _, L in S.tsk4Levels do
				local v = SkillModel.metrics(build, L).tsk4
				add(`S147.tsk4.{spec.build}.{L}`, `T-SK4 {spec.build} L{L}`, v, band[1], band[2], "Mage", L)
			end
		end
	end
	-- R1 of a build per pool and leading direction (45, 100)
	for _, spec in S.r1 do
		local build = SkillModel.build(spec.build, spec.classId)
		local own = SkillModel.R1_L20[spec.build] or SkillModel.metrics(build, 20).r1
		for _, L in S.r1Levels do
			add(
				`S147.r1.{spec.pool}.{spec.build}.{L}`,
				`R1 {spec.pool} ({spec.build}) L{L}`,
				SkillModel.metrics(build, L).r1,
				S.r1Band[1],
				math.max(S.r1Band[2], S.r1Rel * own),
				spec.classId,
				L
			)
		end
	end
	return rows
end

-- S92: the Dark Forest 20-45 and Morvane (balance plan, renumbered S54 draft) ------------------------------------

local Crafting = require("../src/shared/Data/Crafting")
local Rng = require("../src/shared/Logic/Rng")

Balance.S92 = {
	bossLevel = 44, -- the parties of the Morvane rows (balance plan D4: 3-5 players of level 44)
	basicHit = { 0.07, 0.12 }, -- Morvane's basic hit / HP of a level 45 Mage
	tankPerMinute = 3.5, -- S32 model: the tank's HP per minute from basic and threat attacks
	wave = 1.10, -- HP per member per shield wave (the S32 group limit)
	-- T-SK6 band (plan D1, ROZWOJ 0: 1.0-2.0). S92 (C4): the upper bound is the nearest reachable one (DECYZJE S92):
	-- T-SK6 x the sustain ratio of the Berserker without support is ~2.55 (the Healer's 660 HP/s / a potion chain's
	-- 258 HP/s at 44), and every lever of the heal at 44 (Heal rank 10, Holy Strike 10B) moves the Saving Blow share
	-- of S88 (T1, 0.058 at 70) out of its band
	tsk6 = { 1.0, 2.7 },
	mythicRolls = 500,
	-- pace (B1, plan D4): the window model of S91, Warrior, GENERIC, rest, no boss quests
	pace = { hours = { 11.9, 16.1 }, h44 = { 0.72, 0.98 }, step = 1.30 },
	guardLevels = { 25, 30, 35, 40, 44 },
	-- the region's hunting grounds: at least this many outdoor areas hold every level 21-45 (ashen at 45)
	areas = 2,
	-- gold (plan F)
	up3 = 1.05,
	backpacks = { { id = "backpack_80", level = 25 }, { id = "backpack_100", level = 35 } },
	backpackLevels = { 3, 8 },
	chainPotions = 0.30,
	-- ROZWOJ 7.5: the support and tank paths win an Elite and lose an Elite II on the real spawners
	supportLevels = { 30, 40 },
	supportBuilds = {
		{ "Warrior", "guardian.loner" },
		{ "Warrior", "standard.commander" },
		{ "Cleric", "healer.solo" },
		{ "Cleric", "fortune.plunder" },
		{ "Hunter", "scout.partyHunter" },
	},
	-- part ingredients of a recipe with level 20-45 (J1, J2)
	parts = { "werewolf_claw", "ectoplasm", "cursed_bone", "toad_venom", "crow_feather" },
	-- T-SK4 in the band (G2): the asserted Mage builds of G10 at 25-40 (the global block has 45+)
	tsk4Builds = { "destroyer.destroyerExp", "arcanist.arcanistBoss" },
}

export type WaveLoss = { seconds: number, worst: number, byMember: { number } }

-- S92 (B2): the shield waves of `bossId` against `team` one by one: the summon's count of helpers (S134: fixed) at
-- their level, killed one after another by the whole team (as Balance.bossFight); every living helper attacks a
-- member in turn (helper j -> member (j - 1) % n + 1), so the helpers spread over the party. Per wave: its seconds
-- and the HP each member loses / its max HP (worst = the biggest share of any wave).
function Balance.shieldWaves(bossId: string, team: { Player }, opts: BossOpts?): { WaveLoss }
	local def = Bosses.byId[bossId] :: any
	local n = #team
	local out: { WaveLoss } = {}
	for _, summon in def.summons do
		if summon.shield then
			local count = summon.count -- S134: no helpers per player
			local helperDef = Monsters.get(summon.monster) :: any
			local members = Balance.summonHelpers(helperDef, summon.level, count)
			local lost: { number } = table.create(n, 0)
			local seconds = 0
			for k, member in members do
				local teamDps = 0
				for i, p in team do
					teamDps += Balance.dps(p, member) * (if opts and opts.dpsMul then opts.dpsMul[i] or 1 else 1)
				end
				local duration = member.maxHp / math.max(1e-6, teamDps)
				seconds += duration
				for j = k, #members do
					local i = (j - 1) % n + 1
					lost[i] += Balance.hit(members[j], team[i]) * duration / members[j].attackInterval
				end
			end
			local byMember: { number } = {}
			local worst = 0
			for i, p in team do
				byMember[i] = lost[i] / p.values.maxHp
				worst = math.max(worst, byMember[i])
			end
			table.insert(out, { seconds = seconds, worst = worst, byMember = byMember })
		end
	end
	return out
end

-- S92 (C8, B3): share of the Mythic items `classId` cannot use out of `rolls` personal boss rolls with the Mythic
-- chance 1 (the same check as tests/rarities.spec S87, on the server's function Loot.rollBossItem); `killsToday`
-- (the daily kill counter that changes the chances) varies over 0-9.
function Balance.unusableMythics(bossId: string, classId: string, rolls: number): number
	local always = table.clone(LootTables.bosses[bossId]) :: any
	always.mythicChance = 1
	always.legendaryChance = 0
	local rng = Rng.new(92)
	local bad = 0
	for k = 1, rolls do
		local drop = Loot.rollBossItem(always, (k - 1) % 10, classId, rng) :: any
		local def = Items.get(drop.defId) :: any
		if drop.rarity ~= Rarities.MYTHIC or (def.classes and not table.find(def.classes, classId)) then
			bad += 1
		end
	end
	return bad / rolls
end

-- S92: outdoor hunting grounds (every region) whose `lv` holds `level`.
function Balance.areasAt(level: number): number
	local n = 0
	for _, mapId in Balance.REGION_IDS do
		for _, area in Areas.byMap[mapId].areas do
			if level >= area.lv[1] and level <= area.lv[2] then
				n += 1
			end
		end
	end
	return n
end

-- S92: whether an Elite spawner of the region's caves holds `level` (its drops then have that base level).
function Balance.eliteSpawnerAt(mapId: string, level: number): boolean
	for _, cave in Balance.caveSpawners(mapId) do
		for _, e in cave.elites do
			if level >= e.min and level <= e.max then
				return true
			end
		end
	end
	return false
end

-- S92 (K1): the rows of the Dark Forest beyond the S83 region rows (ids "R.duskwood.<group>..."): Morvane, the pace,
-- the skill guards, support paths on the real spawners, the Elites' drop levels, hunting grounds, gold, parts.
-- balance.spec asserts them with the region (TUNED.duskwood) except the rows with `report` (Balance.S92_REPORT).
function Balance.targetsS92(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S92
	local SkillModel = (require :: any)("./SkillModel")
	local L = S.bossLevel
	local function add(
		id: string,
		group: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		c: string?,
		lv: number?
	)
		target(rows, `R.duskwood.{id}`, group, label, value, low, high, c, lv)
	end
	local def = Bosses.byId.morvane :: any
	-- Morvane: the S83 / S87 model (bossFight with shield waves and BossSchedule), both player variants
	for _, nodes in { false, true } do
		local at = if nodes then "@nodes" else ""
		local suffix = if nodes then " z węzłami" else ""
		-- S134: the fight length and the biggest blows are Balance.targetsS134 rows (bosses 2.0)
		-- the shield waves: HP per member per wave (S32 order)
		for n = 3, 5 do
			local worst = 0
			for _, w in Balance.shieldWaves("morvane", Balance.team(n, L, nodes)) do
				worst = math.max(worst, w.worst)
			end
			local label = `Morvane, fala tarczy, {n} graczy L{L}{suffix}: HP na członka`
			add(`morvane.wave{n}{at}`, "morvane", label, worst, nil, S.wave, nil, L)
		end
	end
	do
		local mage = Balance.boss("morvane", { Balance.player("Mage", 45) }).biggest[1].basic
		local label = "Morvane: zwykły cios / HP Maga L45"
		add("morvane.basic45", "morvane", label, mage, S.basicHit[1], S.basicHit[2], "Mage", 45)
		local tank = Balance.boss("morvane", Balance.team(5, L)).tankHpPerMinute
		add(
			"morvane.tank",
			"morvane",
			`Morvane (model S32): tank HP na minutę, L{L}`,
			tank,
			nil,
			S.tankPerMinute,
			nil,
			L
		)
		-- the tank's whole intake (bossFight, with the curse field on the nearest member): only printed, the S32 row
		-- above counts basic and threat attacks (DECYZJE S92)
		for n = 3, 5 do
			local team = Balance.team(n, L)
			local f = Balance.bossFight("morvane", team)
			local perMinute = f.memberDps[1] * 60 / team[1].values.maxHp
			add(
				`morvane.tankFight{n}`,
				"morvane",
				`Morvane (bossFight): tank HP na minutę, {n} graczy`,
				perMinute,
				nil,
				nil,
				nil,
				L
			)
			rows[#rows].report = "tylko raport: z Polem Klątwy w tanka (miara S32 liczy atak podstawowy i threat)"
		end
		add("morvane.hpMul", "morvane", "Morvane ma hpMul", if def.hpMul ~= nil then 1 else 0, 1, nil)
	end
	-- T-SK6 (C4): the dungeon Healer on the Defender, team S92 at the boss level - 1
	do
		local healer = SkillModel.build("healer.dungeon", "Cleric")
		local r = SkillModel.healerVsBoss(healer, "morvane", { team = "s92" })
		local label = "T-SK6 Morvane: Uzdrowiciel lochowy na Obrońcy"
		add("morvane.tsk6", "morvane", label, r.tsk6, S.tsk6[1], S.tsk6[2], "Cleric", L)
	end
	-- Morvane bez wsparcia (C3): the S91 definition (Balance.bossNoSupport), waves of the same team
	for n = 3, 5 do
		local r = Balance.bossNoSupport("morvane", n, L)
		add(
			`morvane.noSupport.{n}.seconds`,
			"noSupport",
			`Morvane bez wsparcia, {n} graczy: s`,
			r.seconds,
			nil,
			r.limit
		)
		local worst, hit = 0, 0
		for _, mem in r.members do
			worst = math.max(worst, mem.ratio)
			hit = math.max(hit, mem.biggest)
		end
		local label = `Morvane bez wsparcia, {n} graczy: przyjmowane / podtrzymanie (najgorszy)`
		add(`morvane.noSupport.{n}.sustain`, "noSupport", label, worst, nil, Balance.S91.noSupport.sustain, nil, L)
		local hitLabel = `Morvane bez wsparcia, {n} graczy: największy cios / HP`
		add(`morvane.noSupport.{n}.hit`, "noSupport", hitLabel, hit, nil, Balance.S91.noSupport.hit, nil, L)
		local team: { Player } = {}
		local mul: { number } = {}
		local m = Balance.monster(Balance.bossKind(def), def.level, "boss")
		for i, mem in r.members do
			local sp = SkillModel.player(SkillModel.build(mem.key), L)
			team[i] = sp.p
			mul[i] = mem.dps / math.max(1e-9, Balance.dps(sp.p, m) * Balance.BOSS_UPTIME)
		end
		local wave = 0
		for _, w in Balance.shieldWaves("morvane", team, { dpsMul = mul }) do
			wave = math.max(wave, w.worst)
		end
		local waveLabel = `Morvane bez wsparcia, fala tarczy, {n} graczy: HP na członka`
		add(`morvane.noSupport.{n}.wave`, "noSupport", waveLabel, wave, nil, S.wave, nil, L)
	end
	-- the Mythic for every class (C8)
	for _, c in Balance.CLASSES do
		local share = Balance.unusableMythics("morvane", c, S.mythicRolls)
		add(`morvane.mythic.{c}`, "morvane", `Morvane: Mityki nieużyteczne dla {c}`, share, nil, 0, c, 45)
	end
	-- pace 20 -> 45 (B1)
	do
		local P = S.pace
		local sum = 0
		for lv = 20, 44 do
			sum += Balance.paceWindowAt("Warrior", lv).hours
		end
		add("pace.sum", "pace", "Tempo 20 → 45 (okno, bez Morvane): h", sum, P.hours[1], P.hours[2], "Warrior")
		local h44 = Balance.paceWindowAt("Warrior", 44).hours
		add("pace.h44", "pace", "Tempo: h(44)", h44, P.h44[1], P.h44[2], "Warrior", 44)
		for lv = 20, 44 do
			local r = Balance.paceWindowAt("Warrior", lv).hours
				/ math.max(1e-9, Balance.paceWindowAt("Warrior", lv - 1).hours)
			add(`pace.step.{lv}`, "pace", `Tempo: h({lv}) / h({lv - 1})`, r, nil, P.step, "Warrior", lv)
		end
	end
	-- skill guards in the band (G1): bases and the reference builds, T-SK3 of the reference builds. S92 (K2): a guard
	-- of a build whose own value at 45 (the path block of S89-S90, asserted) is already above the limit and not below
	-- the band's value (itself above the limit) is printed: holding 25-44 under the D1 limit would only move the jump to 45 (DECYZJE S92); a
	-- band value above the one at 45 stays asserted unless Balance.S92_REPORT names it
	for _, c in Balance.CLASSES do
		for _, build in SkillModel.builds(c) do
			local lim = SkillModel.GUARD_LIMITS
			local g45 = SkillModel.guards(build, 45)
			for _, lv in S.guardLevels do
				local g = SkillModel.guards(build, lv)
				local key = `{c}.{build.key}.{lv}`
				for _, spec in
					{
						{ "tsk1", "tsk1rel", `T-SK1 {c} {build.key} L{lv} / L20` },
						{ "tsk2", "tsk2rel", `T-SK2 {c} {build.key} L{lv} / L20` },
						{ "tsk3", "tsk3cap", `T-SK3 {c} {build.key} L{lv} / areaCap` },
					}
				do
					local field = spec[2]
					add(`guard.{spec[1]}.{key}`, "guards", spec[3], (g :: any)[field], nil, (lim :: any)[field], c, lv)
					if spec[1] == "tsk3" and build.key == "base" then
						-- the base's T-SK3 only printed (S90 I3: the Mage base 2.1-2.4 by design, ROZWOJ 15.5.3)
						rows[#rows].report = "tylko raport (T-SK3 podstawy, S90 I3)"
					elseif
						(g45 :: any)[field] > (lim :: any)[field]
						and (g :: any)[field] > (lim :: any)[field]
						and (g :: any)[field] <= (g45 :: any)[field]
					then
						rows[#rows].report =
							`poza zasięgiem dźwigni S92: na 45 blok ścieżek S89–S90 trzyma {string.format(
								"%.2f",
								(g45 :: any)[field]
							)}`
					end
				end
			end
		end
	end
	-- T-SK4 of the asserted Mage builds in the band (G2)
	for _, key in S.tsk4Builds do
		local build = SkillModel.build(key, "Mage")
		local band = SkillModel.TSK4_BANDS[key]
		for _, lv in S.guardLevels do
			local v = SkillModel.metrics(build, lv).tsk4
			add(`tsk4.{key}.{lv}`, "guards", `T-SK4 Mage {key} {lv}`, v, band[1], band[2], "Mage", lv)
		end
	end
	-- support and tank paths on the real spawners (B5, ROZWOJ 7.5): Elite won, Elite II lost
	for _, spec in S.supportBuilds do
		local build = SkillModel.build(spec[2], spec[1])
		for _, lv in S.supportLevels do
			local elite, elite2 = SkillModel.eliteKinds(lv)
			local ok = 0
			if elite and elite2 then
				local a = SkillModel.duel(build, lv, elite, "elite")
				local b = SkillModel.duel(build, lv, elite2, "elite2")
				ok = if a.won and not b.won then 1 else 0
			end
			local label = `{spec[2]} L{lv}: Elita wygrana, Elita II przegrana ({elite or "–"} / {elite2 or "–"})`
			add(`support.{spec[2]}.{lv}`, "support", label, ok, 1, 1, spec[1], lv)
		end
	end
	-- the Elites drop every item level 21-45 (H2), hunting grounds (D6)
	for lv = 21, 45 do
		local e = if Balance.eliteSpawnerAt("duskwood", lv) then 1 else 0
		add(`ilvl.elite.{lv}`, "drop", `Spawner Elit Mrocznego Boru trzyma poziom {lv}`, e, 1, nil, nil, lv)
		add(`areas.{lv}`, "areas", `Expowiska z poziomem {lv}`, Balance.areasAt(lv), S.areas, nil, nil, lv)
	end
	-- D5 K0 at 44 (H1: 25 / 30 / 35 / 40 / 44; the S84 region rows stop at 40)
	do
		local d5 = Balance.REGION_TARGETS.d5
		local u, h = d5.uniquePerHour, d5.heroicPerHour
		for _, c in Balance.CLASSES do
			local d = Balance.dropsPerHour(c, 44, "K0", false)
			add(`d5.{c}.44.unique`, "d5", `{c} 44: Unikaty dla klasy na h expienia`, d.unique, u[1], u[2], c, 44)
			add(`d5.{c}.44.heroic`, "d5", `{c} 44: Heroiki dla klasy na h Elit`, d.heroic, h[1], h[2], c, 44)
		end
	end
	-- gold (I): +1..+3 of the weapon, backpacks, chain potions
	for lv = 21, 45 do
		for _, u in Balance.upgradeVsIncome(lv) do
			add(
				`gold.up3.{u.classId}.{lv}`,
				"gold",
				`{u.classId} {lv}: +1…+3 / dochód poziomu`,
				u.up3,
				nil,
				S.up3,
				u.classId,
				lv
			)
		end
		for _, c in Balance.CLASSES do
			local share = Balance.economyAt(c, lv, { potions = "chain" }).potionShare
			add(
				`gold.chain.{c}.{lv}`,
				"gold",
				`{c} {lv}: mikstury łańcuchowe / dochód`,
				share,
				nil,
				S.chainPotions,
				c,
				lv
			)
		end
	end
	for _, b in S.backpacks do
		local item = Items.get(b.id) :: any
		for _, c in Balance.CLASSES do
			local levels = item.buyPrice / math.max(1e-9, Balance.levelIncome(c, b.level))
			local label = `{c}: {b.id} (od {b.level}.) / dochód poziomu`
			add(`gold.{b.id}.{c}`, "gold", label, levels, S.backpackLevels[1], S.backpackLevels[2], c, b.level)
		end
	end
	-- parts (J): every kind of the region drops a part; the region's parts are ingredients of a recipe with level 20-45
	for _, kind in Monsters.list do
		if kind.region == 2 then
			local tbl = LootTables.get(kind.lootTable) :: any
			local has = 0
			for _, m in tbl.materials do
				local item = Items.get(m.id) :: any
				if item and item.type == "part" then
					has = 1
				end
			end
			add(`parts.kind.{kind.id}`, "parts", `{kind.id}: część potwora`, has, 1, nil)
		end
	end
	for _, part in S.parts do
		local used = 0
		for _, r in Recipes.list do
			if r.level >= 20 and r.level <= 45 then
				for _, ing in r.ingredients do
					used += if ing.id == part then 1 else 0
				end
			end
		end
		for _, r in Crafting.list do
			if r.level >= 20 and r.level <= 45 then
				for _, mat in r.materials do
					used += if mat.id == part then 1 else 0
				end
			end
		end
		add(`parts.recipe.{part}`, "parts", `{part}: składnik przepisu 20–45`, used, 1, nil)
	end
	for _, row in rows do
		local why = Balance.S92_REPORT[row.id]
		if why then
			row.report = why
		end
	end
	return rows
end

-- S92 (K2): rows of targetsS92 out of reach of the S92 levers (printed with the reason; docs/DECYZJE.md S92).
Balance.S92_REPORT = {} :: { [string]: string }
-- S134: T-SK6 Morvane poza zasięgiem: the big blows to dodge and the mechanics no longer hit the tank and take the
-- boss's time; the curse field on the tank is held by Morvane bez wsparcia (biggest hit <= 1.0: 11.5 -> 12.3 gives
-- 1.00) and the basic attack by the S32 tank row (<= 3.5 HP / min, 3.38), so the Healer's heal stays ~3.5 x the need
Balance.S92_REPORT["R.duskwood.morvane.tsk6"] =
	"poza zasięgiem dźwigni S134: ok. 3,5 > 2,7 (wielkie ciosy do unikania nie trafiają tanka; Pole Klątwy trzyma noSupport.hit ≤ 1,0, atak podstawowy wiersz tanka S32 ≤ 3,5); dla właściciela"
do
	local R = Balance.S92_REPORT
	-- S92: Elita / Elita II ścieżek wsparcia i tanka poza zasięgiem dźwigni S92: każda ścieżka wygrywa Elitę II solo
	-- z miksturami (HP na koniec 0,43-1,00), a krzywe Elit II trzyma duet <= 150% (1,09-1,41); dane ścieżek S89-S90
	for _, key in { "guardian.loner", "standard.commander", "healer.solo", "fortune.plunder", "scout.partyHunter" } do
		for _, lv in { 30, 40 } do
			R[`R.duskwood.support.{key}.{lv}`] =
				"poza zasięgiem dźwigni S92: wygrywa Elitę II solo z miksturami (krzywe Elit II trzyma duet ≤ 150%); dla właściciela"
		end
	end
	-- S92: T-SK4 Niszczyciela na 44 poza zasięgiem dźwigni S92: 1,90 < 2,0; koszt many na 44 ponad kotwicę 45 (1,89)
	-- albo wyższa kotwica 45 psuje arcanistOverload na 45 (2,98 > 2,8, S90)
	R["R.duskwood.tsk4.destroyer.destroyerExp.44"] =
		"poza zasięgiem dźwigni S92: 1,90 < 2,0 (kotwica 45 trzyma arcanistOverload ≤ 2,8 na 45)"
	-- S92: strażniki Łowcy na 40-44 poza zasięgiem dźwigni S92: baza 1,16 na 44, Zwiadowca 1,17-1,21 (T-SK1) i
	-- 1,30-1,35 (T-SK2) na 40-44, a na 45 1,05-1,23 (Ostrość Zręczności i rangi 45, S90); dla S93
	for _, spec in
		{
			{ "base", { 44 }, { "tsk1" } },
			{ "scout.partyHunter", { 40, 44 }, { "tsk1", "tsk2" } },
			{ "scout.tracker", { 40, 44 }, { "tsk1", "tsk2" } },
		}
	do
		for _, lv in spec[2] do
			for _, metric in spec[3] do
				R[`R.duskwood.guard.{metric}.Hunter.{spec[1]}.{lv}`] =
					"poza zasięgiem dźwigni S92: Łowca na 40–44 ponad limit, na 45 w paśmie (spadek na 45, S90); dla S93"
			end
		end
	end
	-- S92: strażniki ponad wartością na 45 poza zasięgiem dźwigni S92: skok na 44 to węzeł kupiony 44. punktem w
	-- kolejności `reference` S89-S90 (Strzelec Namierzenie, Traper Trujące Sidła, Rzeźnik Rozdarcie, Niszczyciel
	-- Krucha Potęga 3), a rangi na 44 i 45 są te same, więc węzły SkillCurves nie obniżą 44 bez 45 (blok ścieżek);
	-- Łowca spada na 45 (Ostrość Zręczności i rangi 45, S90), Królobójca T-SK2 1,31 już na 40; dla S93
	for _, spec in
		{
			{ "Hunter", "marksman.kingslayer", { 44 }, { "tsk1", "tsk2" } },
			{ "Hunter", "marksman.eliteHunter", { 44 }, { "tsk1", "tsk2" } },
			{ "Hunter", "trapper.poacher", { 44 }, { "tsk1", "tsk2" } },
			{ "Hunter", "trapper.poisoner", { 44 }, { "tsk1", "tsk2" } },
			{ "Warrior", "berserker.butcher", { 44 }, { "tsk1" } },
			{ "Mage", "destroyer.destroyerBoss", { 44 }, { "tsk2" } },
		}
	do
		for _, lv in spec[3] do
			for _, metric in spec[4] do
				R[`R.duskwood.guard.{metric}.{spec[1]}.{spec[2]}.{lv}`] =
					"poza zasięgiem dźwigni S92: skok z węzła ścieżki kupionego 44. punktem (kolejność S89–S90), rangi 44 = 45; dla S93"
			end
		end
	end
	R["R.duskwood.guard.tsk2.Hunter.marksman.kingslayer.40"] =
		"poza zasięgiem dźwigni S92: 1,31 na 40 wobec 1,29 na 45 (rangi z 37–42 trzymają też 45, blok ścieżek); dla S93"
	-- S92: mikstury łańcuchowe poza zasięgiem dźwigni S92: ceny mikstur wspólne z 1-20, odstęp z globalnej krzywej
	-- potionCooldown; Duża mikstura (250) od ok. 32. poziomu podnosi udział do 0,32-0,49 (Kapłan do 0,77)
	for lv = 21, 45 do
		for _, c in Balance.CLASSES do
			R[`R.duskwood.gold.chain.{c}.{lv}`] =
				"poza zasięgiem dźwigni S92: ceny mikstur i krzywa potionCooldown globalne; dla właściciela"
		end
	end
end

-- S93: the Scorched Wastes 45-70 and Azgor (balance plan, renumbered S55 draft) -------------------------------------

Balance.S93 = {
	bossLevel = 69, -- the parties of the Azgor rows (3-5 players of level 69)
	basicHit = { 0.07, 0.12 }, -- Azgor's basic hit / HP of a level 70 Mage
	tankPerMinute = 3.5, -- S32 model: the tank's HP per minute from basic and threat attacks
	wave = 1.10, -- HP per member per shield wave (the S32 group limit)
	meteor = 0.60, -- C4 (a): meteor per minute / HP of a level 70 Mage, phases 1-3
	lava = { 0.15, 0.25 }, -- one lava tick / HP of a level 70 Mage
	-- T-SK6 band (plan D1, ROZWOJ 0: 1.0-2.0; S93 C6: a fallback threshold at most 2.5). S93: NOT DONE, the row is
	-- in Balance.S93_REPORT and in docs/PROGRESS.md "Niedokończone" (12.8, owner's decision)
	tsk6 = { 1.0, 2.5 },
	mythicRolls = 500,
	-- pace (F, plan D4): the window model of S91, Warrior, GENERIC, rest, no boss quests
	pace = { hours = { 21.25, 28.75 }, h69 = { 0.98, 1.32 }, step = 1.30 },
	guardLevels = { 50, 55, 60, 65, 69, 70 },
	areas = 2, -- every level 46-70 in at least two outdoor areas (frostpeak_valley counts at 70)
	-- gold (plan F)
	up3 = 1.05,
	backpacks = { { id = "backpack_130", level = 50 } },
	backpackLevels = { 3, 8 },
	chainPotions = { 0.15, 0.30 },
	potionTiers = { 3, 4, 5 }, -- gold per HP grows with quality: Large <= Great <= Mighty
	supportLevels = { 55, 65 },
	-- the part ingredients of a recipe with level 45-70 (J2, J3)
	parts = { "salamander_scale", "magma_shard", "thick_hide", "crow_feather", "toad_venom", "cursed_bone" },
	-- G2: the four Mage path bands of S90 (SkillModel.TSK4_BANDS)
	tsk4Builds = {
		"destroyer.destroyerExp",
		"destroyer.destroyerBoss",
		"arcanist.arcanistBoss",
		"arcanist.arcanistOverload",
	},
	d5Levels = { 69 }, -- the S84 region rows have 45 / 50 / 55 / 60 / 65
}

-- S93 (B4): part uses: for every material the alchemist (Recipes.list) and smith (Crafting.list) recipes with a level
-- in [minLevel, maxLevel] that take it as an ingredient. S94 calls it for 70-100.
function Balance.partUses(minLevel: number, maxLevel: number): { [string]: { string } }
	local out: { [string]: { string } } = {}
	local function add(material: string, recipeId: string)
		local list = out[material]
		if not list then
			list = {}
			out[material] = list
		end
		if not table.find(list, recipeId) then
			table.insert(list, recipeId)
		end
	end
	for _, r in Recipes.list do
		if r.level >= minLevel and r.level <= maxLevel then
			for _, ing in r.ingredients do
				add(ing.id, r.id)
			end
		end
	end
	for _, r in Crafting.list do
		if r.level >= minLevel and r.level <= maxLevel then
			for _, mat in r.materials do
				add(mat.id, r.id)
			end
		end
	end
	return out
end

-- S93 (H2): whether an Elite of the region's caves drops item level `ilvl`: a spawner of level L drops ilvl
-- ItemRoll.dropLevelRange(L) (Loot.dropBaseLevel takes off the variant's levelAdd), over every spawner level.
function Balance.eliteDropsIlvl(mapId: string, ilvl: number): boolean
	for _, cave in Balance.caveSpawners(mapId) do
		for _, e in cave.elites do
			for L = e.min, e.max do
				local low, high = ItemRoll.dropLevelRange(L)
				if ilvl >= low and ilvl <= high then
					return true
				end
			end
		end
	end
	return false
end

-- S93 (B3, report): the protected +9 of a Legendary weapon at ilvl `ilvl`: gold, scrolls and Legend Cores (from +8,
-- S87), the scrolls' gold at the alchemist, all in levels of income of the Warrior at that level.
export type ProtectedFlow = {
	ilvl: number,
	gold: number,
	scrolls: number,
	cores: number,
	scrollGold: number,
	income: number,
	levels: number, -- (gold + scrollGold) / income
}
function Balance.protectedFlow(ilvl: number): ProtectedFlow
	local item = makeItem(tierId(Balance.LOADOUT.Warrior.weapon, ilvl), ilvl, Rarities.LEGENDARY, 0, {})
	local plan = Balance.upgradePlan(item, 9, true)
	local income = math.max(1e-9, Balance.levelIncome("Warrior", ilvl))
	return {
		ilvl = ilvl,
		gold = plan.gold,
		scrolls = plan.scrolls,
		cores = plan.cores,
		scrollGold = plan.scrollGold,
		income = income,
		levels = (plan.gold + plan.scrollGold) / income,
	}
end

-- S93: gold per HP of the HP potion of `quality` (Data/Items/Consumables).
function Balance.potionGoldPerHp(quality: number): number
	local item = Items.get(`potion_hp_{quality}`) :: any
	return item.buyPrice / item.use.amount
end

-- S93 (K1): the rows of the Scorched Wastes beyond the S83 region rows (ids "R.ashen.<group>..."): Azgor, the pace,
-- the skill guards, support paths on the real spawners, the Elites' drop levels, hunting grounds, gold, parts.
-- balance.spec asserts them with the region (TUNED.ashen) except the rows with `report` (Balance.S93_REPORT).
function Balance.targetsS93(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S93
	local SkillModel = (require :: any)("./SkillModel")
	local L = S.bossLevel
	local function add(
		id: string,
		group: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		c: string?,
		lv: number?
	)
		target(rows, `R.ashen.{id}`, group, label, value, low, high, c, lv)
	end
	local def = Bosses.byId.azgor :: any
	-- Azgor: the S83 / S87 model (bossFight with shield waves and BossSchedule), both player variants
	for _, nodes in { false, true } do
		local at = if nodes then "@nodes" else ""
		local suffix = if nodes then " z węzłami" else ""
		-- S134: the fight length and the biggest blows are Balance.targetsS134 rows (bosses 2.0)
		for n = 3, 5 do
			local worst = 0
			for _, w in Balance.shieldWaves("azgor", Balance.team(n, L, nodes)) do
				worst = math.max(worst, w.worst)
			end
			local label = `Azgor, fala tarczy, {n} graczy L{L}{suffix}: HP na członka`
			add(`azgor.wave{n}{at}`, "azgor", label, worst, nil, S.wave, nil, L)
		end
	end
	do
		local mage = Balance.boss("azgor", { Balance.player("Mage", 70) }).biggest[1].basic
		add(
			"azgor.basic70",
			"azgor",
			"Azgor: zwykły cios / HP Maga L70",
			mage,
			S.basicHit[1],
			S.basicHit[2],
			"Mage",
			70
		)
		local tank = Balance.boss("azgor", Balance.team(5, L)).tankHpPerMinute
		add("azgor.tank", "azgor", `Azgor (model S32): tank HP na minutę, L{L}`, tank, nil, S.tankPerMinute, nil, L)
		-- the tank's whole intake (bossFight): only printed, the S32 row above counts basic and threat attacks
		for n = 3, 5 do
			local team = Balance.team(n, L)
			local f = Balance.bossFight("azgor", team)
			local perMinute = f.memberDps[1] * 60 / team[1].values.maxHp
			add(
				`azgor.tankFight{n}`,
				"azgor",
				`Azgor (bossFight): tank HP na minutę, {n} graczy`,
				perMinute,
				nil,
				nil,
				nil,
				L
			)
			rows[#rows].report =
				"tylko raport: całe przyjęcie tanka z meteorem i falami (miara S32 liczy atak podstawowy i threat)"
		end
		-- meteor per minute and one lava tick on a level 70 Mage (C4, C2; party of 5 with the Mage swapped in)
		local team = Balance.team(5, L)
		team[2] = Balance.player("Mage", 70)
		local f = Balance.bossFight("azgor", team)
		add(
			"azgor.meteor",
			"azgor",
			"Azgor: meteor na minutę / HP Maga L70",
			f.raid.Mage or 0,
			nil,
			S.meteor,
			"Mage",
			70
		)
		local tick = f.hazardTick.Mage or 0
		add("azgor.lava", "azgor", "Azgor: jeden tick lawy / HP Maga L70", tick, S.lava[1], S.lava[2], "Mage", 70)
		add("azgor.hpMul", "azgor", "Azgor ma hpMul", if def.hpMul ~= nil then 1 else 0, 1, nil)
		-- enrage never in the fight (C2)
		for n = 3, 5 do
			local fight = Balance.bossFight("azgor", Balance.team(n, L))
			add(
				`azgor.enrage{n}`,
				"azgor",
				`Azgor, {n} graczy: wściekłość`,
				if fight.enraged then 1 else 0,
				nil,
				0,
				nil,
				L
			)
		end
	end
	-- T-SK6 (C6): the dungeon Healer on the Defender, team S92 at the boss level - 1
	do
		local healer = SkillModel.build("healer.dungeon", "Cleric")
		local r = SkillModel.healerVsBoss(healer, "azgor", { team = "s92" })
		add(
			"azgor.tsk6",
			"azgor",
			"T-SK6 Azgor: Uzdrowiciel lochowy na Obrońcy",
			r.tsk6,
			S.tsk6[1],
			S.tsk6[2],
			"Cleric",
			L
		)
	end
	-- Azgor bez wsparcia (C5): the S91 definition (Balance.bossNoSupport), waves of the same team
	for n = 3, 5 do
		local r = Balance.bossNoSupport("azgor", n, L)
		add(`azgor.noSupport.{n}.seconds`, "noSupport", `Azgor bez wsparcia, {n} graczy: s`, r.seconds, nil, r.limit)
		local worst, hit = 0, 0
		for _, mem in r.members do
			worst = math.max(worst, mem.ratio)
			hit = math.max(hit, mem.biggest)
		end
		local label = `Azgor bez wsparcia, {n} graczy: przyjmowane / podtrzymanie (najgorszy)`
		add(`azgor.noSupport.{n}.sustain`, "noSupport", label, worst, nil, Balance.S91.noSupport.sustain, nil, L)
		local hitLabel = `Azgor bez wsparcia, {n} graczy: największy cios / HP`
		add(`azgor.noSupport.{n}.hit`, "noSupport", hitLabel, hit, nil, Balance.S91.noSupport.hit, nil, L)
		local team: { Player } = {}
		local mul: { number } = {}
		local m = Balance.monster(Balance.bossKind(def), def.level, "boss")
		for i, mem in r.members do
			local sp = SkillModel.player(SkillModel.build(mem.key), L)
			team[i] = sp.p
			mul[i] = mem.dps / math.max(1e-9, Balance.dps(sp.p, m) * Balance.BOSS_UPTIME)
		end
		local wave = 0
		for _, w in Balance.shieldWaves("azgor", team, { dpsMul = mul }) do
			wave = math.max(wave, w.worst)
		end
		local waveLabel = `Azgor bez wsparcia, fala tarczy, {n} graczy: HP na członka`
		add(`azgor.noSupport.{n}.wave`, "noSupport", waveLabel, wave, nil, S.wave, nil, L)
	end
	-- the Mythic for every class (C8)
	for _, c in Balance.CLASSES do
		local share = Balance.unusableMythics("azgor", c, S.mythicRolls)
		add(`azgor.mythic.{c}`, "azgor", `Azgor: Mityki nieużyteczne dla {c}`, share, nil, 0, c, 70)
	end
	-- pace 45 -> 70 (F)
	do
		local P = S.pace
		local sum = 0
		for lv = 45, 69 do
			sum += Balance.paceWindowAt("Warrior", lv).hours
		end
		add("pace.sum", "pace", "Tempo 45 → 70 (okno, bez Azgora): h", sum, P.hours[1], P.hours[2], "Warrior")
		local h69 = Balance.paceWindowAt("Warrior", 69).hours
		add("pace.h69", "pace", "Tempo: h(69)", h69, P.h69[1], P.h69[2], "Warrior", 69)
		for lv = 45, 69 do
			local r = Balance.paceWindowAt("Warrior", lv).hours
				/ math.max(1e-9, Balance.paceWindowAt("Warrior", lv - 1).hours)
			add(`pace.step.{lv}`, "pace", `Tempo: h({lv}) / h({lv - 1})`, r, nil, P.step, "Warrior", lv)
		end
	end
	-- skill guards in the band (G1): bases and the reference builds, T-SK3 of the reference builds. S93 (K2): the S92
	-- rule: a guard of a build whose own value at 45 (S92's end of the band) is already above the limit and not below
	-- the band's value is printed when it is above the limit itself; any other row (70 included) stays asserted unless
	-- Balance.S93_REPORT names it
	for _, c in Balance.CLASSES do
		for _, build in SkillModel.builds(c) do
			local lim = SkillModel.GUARD_LIMITS
			local g45 = SkillModel.guards(build, 45)
			for _, lv in S.guardLevels do
				local g = SkillModel.guards(build, lv)
				local key = `{c}.{build.key}.{lv}`
				for _, spec in
					{
						{ "tsk1", "tsk1rel", `T-SK1 {c} {build.key} L{lv} / L20` },
						{ "tsk2", "tsk2rel", `T-SK2 {c} {build.key} L{lv} / L20` },
						{ "tsk3", "tsk3cap", `T-SK3 {c} {build.key} L{lv} / areaCap` },
					}
				do
					local field = spec[2]
					local v = (g :: any)[field]
					local limit = (lim :: any)[field]
					local at45 = (g45 :: any)[field]
					add(`guard.{spec[1]}.{key}`, "guards", spec[3], v, nil, limit, c, lv)
					if spec[1] == "tsk3" and build.key == "base" then
						rows[#rows].report = "tylko raport (T-SK3 podstawy, S90 I3)"
					elseif at45 > limit and v > limit and v <= at45 + 1e-9 then
						rows[#rows].report =
							`poza zasięgiem dźwigni S93: na 45 (pasmo S92) build ma już {string.format("%.2f", at45)}`
					end
				end
			end
		end
	end
	-- T-SK4 of the asserted Mage builds and T-SK5 of the dungeon Healer on the Defender in the band (G2)
	for _, key in S.tsk4Builds do
		local build = SkillModel.build(key, "Mage")
		local band = SkillModel.TSK4_BANDS[key]
		for _, lv in S.guardLevels do
			local v = SkillModel.metrics(build, lv).tsk4
			add(`tsk4.{key}.{lv}`, "guards", `T-SK4 Mage {key} {lv}`, v, band[1], band[2], "Mage", lv)
		end
	end
	do
		local healer = SkillModel.build("healer.dungeon", "Cleric")
		for _, lv in S.guardLevels do
			local v = SkillModel.oneHeal(healer, lv, SkillModel.defenderTank(lv))
			local band = SkillModel.TSK5_BAND
			add(`tsk5.{lv}`, "guards", `T-SK5 Uzdrowiciel lochowy na Obrońcy {lv}`, v, band[1], band[2], "Cleric", lv)
		end
	end
	-- support and tank paths on the real spawners (D6, ROZWOJ 7.5): Elite won, Elite II lost
	for _, spec in Balance.S92.supportBuilds do
		local build = SkillModel.build(spec[2], spec[1])
		for _, lv in S.supportLevels do
			local elite, elite2 = SkillModel.eliteKinds(lv)
			local ok = 0
			if elite and elite2 then
				local a = SkillModel.duel(build, lv, elite, "elite")
				local b = SkillModel.duel(build, lv, elite2, "elite2")
				ok = if a.won and not b.won then 1 else 0
			end
			local label = `{spec[2]} L{lv}: Elita wygrana, Elita II przegrana ({elite or "–"} / {elite2 or "–"})`
			add(`support.{spec[2]}.{lv}`, "support", label, ok, 1, 1, spec[1], lv)
		end
	end
	-- the Elites drop every item level 46-70 (H2), hunting grounds (D2)
	for lv = 46, 70 do
		local e = if Balance.eliteDropsIlvl("ashen", lv) then 1 else 0
		add(`ilvl.elite.{lv}`, "drop", `Elity Spalonych Pustkowi dropią ilvl {lv}`, e, 1, nil, nil, lv)
		add(`areas.{lv}`, "areas", `Expowiska z poziomem {lv}`, Balance.areasAt(lv), S.areas, nil, nil, lv)
	end
	-- D5 K0 at 69 (H1: 50 / 55 / 60 / 65 / 69; the S84 region rows stop at 65)
	do
		local d5 = Balance.REGION_TARGETS.d5
		local u, h = d5.uniquePerHour, d5.heroicPerHour
		for _, lv in S.d5Levels do
			for _, c in Balance.CLASSES do
				local d = Balance.dropsPerHour(c, lv, "K0", false)
				add(
					`d5.{c}.{lv}.unique`,
					"d5",
					`{c} {lv}: Unikaty dla klasy na h expienia`,
					d.unique,
					u[1],
					u[2],
					c,
					lv
				)
				add(`d5.{c}.{lv}.heroic`, "d5", `{c} {lv}: Heroiki dla klasy na h Elit`, d.heroic, h[1], h[2], c, lv)
			end
		end
	end
	-- gold (I): +1..+3 of the weapon, chain potions (upper bound; the lower one in its own rows), backpack, prices
	for lv = 46, 69 do
		for _, u in Balance.upgradeVsIncome(lv) do
			local label = `{u.classId} {lv}: +1…+3 / dochód poziomu`
			add(`gold.up3.{u.classId}.{lv}`, "gold", label, u.up3, nil, S.up3, u.classId, lv)
		end
		for _, c in Balance.CLASSES do
			local share = Balance.economyAt(c, lv, { potions = "chain" }).potionShare
			local label = `{c} {lv}: mikstury łańcuchowe / dochód`
			add(`gold.chain.{c}.{lv}`, "gold", label, share, nil, S.chainPotions[2], c, lv)
			add(`gold.chainLow.{c}.{lv}`, "gold", `{label} (dolna granica)`, share, S.chainPotions[1], nil, c, lv)
		end
	end
	for _, b in S.backpacks do
		local item = Items.get(b.id) :: any
		for _, c in Balance.CLASSES do
			local levels = item.buyPrice / math.max(1e-9, Balance.levelIncome(c, b.level))
			local label = `{c}: {b.id} (od {b.level}.) / dochód poziomu`
			add(`gold.{b.id}.{c}`, "gold", label, levels, S.backpackLevels[1], S.backpackLevels[2], c, b.level)
		end
	end
	for i = 2, #S.potionTiers do
		local lower, higher = S.potionTiers[i - 1], S.potionTiers[i]
		local d = Balance.potionGoldPerHp(higher) - Balance.potionGoldPerHp(lower)
		add(`gold.potionOrder.{higher}`, "gold", `Złoto za 1 HP: jakość {higher} − jakość {lower}`, d, 0, nil)
	end
	-- parts (J): every kind of the region drops a part; the region's parts are ingredients of a recipe with level 45-70
	for _, kind in Monsters.list do
		if kind.region == 3 then
			local tbl = LootTables.get(kind.lootTable) :: any
			local has = 0
			for _, m in tbl.materials do
				local item = Items.get(m.id) :: any
				if item and item.type == "part" then
					has = 1
				end
			end
			add(`parts.kind.{kind.id}`, "parts", `{kind.id}: część potwora`, has, 1, nil)
		end
	end
	local uses = Balance.partUses(45, 70)
	for _, part in S.parts do
		add(`parts.recipe.{part}`, "parts", `{part}: składnik przepisu 45–70`, #(uses[part] or {}), 1, nil)
	end
	do
		local elixir = Recipes.get("elixir_resFire") :: any
		local v = if elixir then elixir.level else 0
		add("parts.elixirFire", "parts", "elixir_resFire: poziom przepisu", v, 45, 45)
	end
	for _, row in rows do
		local why = Balance.S93_REPORT[row.id]
		if why then
			row.report = why
		end
	end
	return rows
end

-- S93 (K2): rows of targetsS93 out of reach of the S93 levers (printed with the reason; docs/DECYZJE.md S93).
Balance.S93_REPORT = {} :: { [string]: string }
do
	local R = Balance.S93_REPORT
	-- S93: Elita / Elita II ścieżek wsparcia i tanka poza zasięgiem dźwigni S93: każda ścieżka wygrywa Elitę II solo
	-- z miksturami (HP na koniec 0,18-1,00), a krzywe Elit II trzyma duet <= 150% (1,11-1,24); dane ścieżek S89-S90
	for _, spec in Balance.S92.supportBuilds do
		for _, lv in Balance.S93.supportLevels do
			R[`R.ashen.support.{spec[2]}.{lv}`] =
				"poza zasięgiem dźwigni S93: wygrywa Elitę II solo z miksturami (krzywe Elit II trzyma duet ≤ 150%); dla właściciela"
		end
	end
	-- S93: mikstury łańcuchowe (górna granica) poza zasięgiem dźwigni S93: Wielka na najniższej cenie w kolejności
	-- jakości (700, 0,175 zł za 1 HP; próg Dużej 0,167) daje 0,28-0,82 dochodu; ceny jakości 1-3 i krzywa
	-- potionCooldown są globalne
	for lv = 46, 69 do
		for _, c in Balance.CLASSES do
			R[`R.ashen.gold.chain.{c}.{lv}`] =
				"poza zasięgiem dźwigni S93: Wielka 700 to dół kolejności cen (0,175 ≥ 0,167 zł/HP), ceny 1–3 i potionCooldown globalne; dla właściciela"
		end
	end
	-- S93: strażniki T-SK ponad limitem D1 i ponad wartością na 45 (reguła S92 ich nie zwalnia), każda grupa z
	-- powodem i linią w DECYZJE S93; liczby (wartość na 45 → najwyższa w paśmie) w docs/BALANS.md
	local guardReasons = {
		-- S93: poza zasięgiem dźwigni S93: build już na 45 ponad limitem (pasmo S92), w paśmie rośnie z poziomem
		-- (Mag do +28%, Kapłan do +19%, Łowca do +25%, Rzeźnik i Dowódca T-SK1 do +6% nad 45) przez sprzęt, statystyki
		-- i rangi 46-70 całej klasy; węzły SkillCurves na rangach z pasma ruszają też 70 i 71+ (S94), a cięcie obrażeń
		-- klasy zmienia jej cele obrażeń ścieżek; dla właściciela (który kontrakt obowiązuje w paśmie, lista S92)
		rise = "poza zasięgiem dźwigni S93: na 45 już ponad limitem D1 (S92), w paśmie rośnie z poziomem klasy (do +28% nad 45); dla właściciela",
		-- S93: poza zasięgiem dźwigni S93: Furia to zamrożone odniesienie obrażeń (S89, R1 2,4-2,6), T-SK1 1,16-1,18 na
		-- 55-70 (1,13 na 45), T-SK2 1,32 na 70 (węzeł rzędu 9)
		fury = "poza zasięgiem dźwigni S93: Furia to zamrożone odniesienie obrażeń (S89); dla właściciela",
		-- S93: poza zasięgiem dźwigni S93: podstawa Wojownika do 1,5% ponad T-SK1 na 49-53 i 66-70, T-SK2 1,32-1,33 od
		-- 66: ranga 10 Trzęsienia Ziemi z przełomem na 66 (ta sama wartość trzyma Furię, zamrożoną S89)
		warriorBase = "poza zasięgiem dźwigni S93: ranga 10 Trzęsienia Ziemi na 66 (+7% wybuchu) trzyma też Furię (S89); dla właściciela",
		-- S93: Strażnik z Groźbą: T-SK3 do 1,09 × areaCap 2,0 = 2,18 na 55-70; S89 C1: Strażnik ma 2,2 (DECYZJE S89)
		guardian = "poza zasięgiem dźwigni S93: T-SK3 Strażnika ≤ 2,2 (S89 C1, Groźba), tu do 2,18",
		-- S93: poza zasięgiem dźwigni S93: skok na 70 z węzła rzędu 9 ścieżki (wybór na 70., liczby S89) — Rzeźnik T-SK2
		-- 1,17 → 1,42, Dowódca 1,26 → 1,74 (T-SK1 1,20 → 1,29), Opiekun 1,13 → 1,55 (T-SK1 1,11 → 1,19); Dowódca T-SK2
		-- 1,26 na 69 (0,6% ponad, rangi 46-69); strażniki 71-100 sprawdza S94 (R.frostpeak.guard), reszta dla właściciela
		row9 = "poza zasięgiem dźwigni S93: skok na 70 z węzła rzędu 9 ścieżki (S89); dla właściciela",
	}
	for _, spec in
		{
			{ "tsk1", "Warrior.base", { 50, 69, 70 }, "warriorBase" },
			{ "tsk2", "Warrior.base", { 69, 70 }, "warriorBase" },
			{ "tsk1", "Warrior.base.loadout", { 69, 70 }, "warriorBase" },
			{ "tsk2", "Warrior.base.loadout", { 69, 70 }, "warriorBase" },
			{ "tsk3", "Warrior.guardian.defender", { 55, 60, 65, 69, 70 }, "guardian" },
			{ "tsk3", "Warrior.guardian.loner", { 60, 65, 69, 70 }, "guardian" },
			{ "tsk1", "Warrior.berserker.fury", { 55, 60, 65, 69, 70 }, "fury" },
			{ "tsk2", "Warrior.berserker.fury", { 70 }, "fury" },
			{ "tsk1", "Warrior.berserker.butcher", { 50, 55, 60, 65, 69, 70 }, "rise" },
			{ "tsk2", "Warrior.berserker.butcher", { 70 }, "row9" },
			{ "tsk1", "Warrior.standard.commander", { 50, 55, 60, 65, 69 }, "rise" },
			{ "tsk1", "Warrior.standard.commander", { 70 }, "row9" },
			{ "tsk2", "Warrior.standard.commander", { 69, 70 }, "row9" },
			{ "tsk1", "Warrior.standard.warden", { 70 }, "row9" },
			{ "tsk2", "Warrior.standard.warden", { 70 }, "row9" },
			{ "tsk1", "Hunter.marksman.kingslayer", { 50, 55, 60, 69 }, "rise" },
			{ "tsk2", "Hunter.marksman.kingslayer", { 50, 55, 60, 65, 69, 70 }, "rise" },
			{ "tsk1", "Hunter.marksman.eliteHunter", { 50, 69 }, "rise" },
			{ "tsk2", "Hunter.marksman.eliteHunter", { 50, 55, 60, 65, 69, 70 }, "rise" },
			{ "tsk1", "Hunter.trapper.poacher", { 50, 55, 60, 65, 69, 70 }, "rise" },
			{ "tsk2", "Hunter.trapper.poacher", { 50, 55, 60, 65, 69, 70 }, "rise" },
			{ "tsk1", "Hunter.trapper.poisoner", { 50, 55, 60, 65, 69, 70 }, "rise" },
			{ "tsk2", "Hunter.trapper.poisoner", { 50, 55, 60, 65, 69, 70 }, "rise" },
		}
	do
		for _, lv in spec[3] do
			R[`R.ashen.guard.{spec[1]}.{spec[2]}.{lv}`] = (guardReasons :: any)[spec[4]]
		end
	end
	-- Mage and Cleric: the base and every reference build, T-SK1 and T-SK2 on 50-70 (reason `rise`)
	for _, build in
		{
			"Mage.base",
			"Mage.base.loadout",
			"Mage.destroyer.destroyerExp",
			"Mage.destroyer.destroyerBoss",
			"Mage.arcanist.arcanistBoss",
			"Mage.arcanist.arcanistOverload",
			"Cleric.base",
			"Cleric.healer.dungeon",
			"Cleric.healer.solo",
			"Cleric.fortune.plunder",
			"Cleric.inquisitor.solo",
			"Cleric.inquisitor.bulwark",
		}
	do
		for _, metric in { "tsk1", "tsk2" } do
			for _, lv in Balance.S93.guardLevels do
				R[`R.ashen.guard.{metric}.{build}.{lv}`] = guardReasons.rise
			end
		end
	end
	-- S93: T-SK6 Azgora NIEDOKOŃCZONE (asercja ≤ 2,5 z C6 nie przechodzi, wynik 12,8; zasada 4 nie pozwala na raport,
	-- więc to brak S93 w PROGRESS, nie poszerzone pasmo): Uzdrowiciel lochowy na 69 leczy ok. 1820 HP/s (19 maks. HP
	-- Obrońcy na minutę), Obrońca przyjmuje ok. 142 HP/s (1,5 maks. HP na minutę). Samo Leczenie (rangi ≤ 45, odnowienie
	-- 3 s, S91) daje ok. 20 × 0,31 HP tanka na minutę, czyli T-SK6 ok. 4 nawet bez reszty ścieżki; kotwica heal 70
	-- (0,31 → 0,01) zmienia T-SK6 12,8 → 12,5 (część od maks. HP celu, S69); obrażenia w tanka ×5 łamią wiersz tanka
	-- S32 (346%/min ≤ 350%). Dla właściciela: definicja T-SK6 (bez nadleczenia), przepustowość leczenia albo inny cel
	R["R.ashen.azgor.tsk6"] =
		"NIEDOKOŃCZONE S93: T-SK6 12,8 wobec ≤ 2,5 (C6) nieosiągalne dźwigniami S93 (Leczenie z rang ≤ 45 samo daje ok. 4, tank S32 346%/min); decyzja właściciela"
	-- S93: T-SK2 podstawy Łowcy na 65 (1,285) poza zasięgiem dźwigni S93: skok przy progu sprzętu 65 (broń modelu
	-- z progu 65, żadna ranga nie wypada na 65); na 66 Salwa ranga 10 wraca do 1,23
	R["R.ashen.guard.tsk2.Hunter.base.65"] =
		"poza zasięgiem dźwigni S93: skok przy progu sprzętu 65 (żadna ranga na 65), na 64 / 66 1,16 / 1,23; dla właściciela"
	-- S93: T-SK3 Trapera „Kłusownik” na 65 (1,005) poza zasięgiem dźwigni S93: Pole Sideł rangi 1-2 (60, 64); niższa
	-- ranga 1 z węzłem rangi 4 przesuwa rangę 3 trzymającą 70 (blok ścieżek S90)
	R["R.ashen.guard.tsk3.Hunter.trapper.poacher.65"] =
		"poza zasięgiem dźwigni S93: Pole Sideł rangi 1–2 (0,5% ponad), ranga 3 trzyma 70 w bloku ścieżek; dla właściciela"
end

-- S94: the Frost Peaks 70-100, Vaelgrath and the endgame (balance plan, renumbered S56 draft) ---------------------

Balance.S94 = {
	bossLevel = 99, -- the parties of the Vaelgrath rows (3-5 players of level 99)
	basicHit = { 0.07, 0.12 }, -- Vaelgrath's basic hit / HP of a level 100 Mage
	tankPerMinute = 3.5, -- S32 model: the tank's HP per minute from basic and threat attacks
	wave = 1.10, -- HP per member per shield wave (the S32 group limit)
	blizzard = 0.60, -- C3 (a): blizzard per minute / HP of a level 100 Mage, phases 2-3
	storm = { 0.30, 0.45 }, -- one storm tick / HP of a level 100 Mage
	tsk6 = { 1.0, 2.0 }, -- T-SK6 band (plan D1, ROZWOJ 0)
	mythicRolls = 500,
	mythicLadder = { 1.4, 1.6 }, -- expected kills to a Mythic: Vaelgrath / Grimrok (D2)
	-- pace (G, plan D4): the window model of S91, Warrior, GENERIC, rest, no boss quests
	pace = { hours = { 34.9, 47.2 }, h99 = { 1.36, 1.84 }, step = 1.30, total = { 69.7, 94.3 } },
	guardLevels = { 75, 80, 85, 90, 95, 99, 100 },
	areas = 2, -- every level 71-100 in at least two outdoor areas
	-- gold (plan F)
	up3 = 1.05,
	backpacks = { { id = "backpack_160", level = 65 }, { id = "backpack_200", level = 80 } },
	backpackLevels = { 5, 12 },
	chainPotions = { 0.15, 0.30 },
	potionTiers = { 3, 4, 5 }, -- gold per HP grows with quality: Large <= Great <= Mighty
	setHours = { 150, 300 }, -- J5: protected +9 of 10 Legendary ilvl 100 in hours of the best gold area at 99
	ores = { { item = "ore_mithril", level = 70 }, { item = "ore_adamantite", level = 90 } },
	supportLevels = { 80, 95 },
	-- the parts of the Frost Peaks' kinds (K): ingredients of a recipe available at 70-100
	parts = { "yeti_fur", "frost_scale", "thick_hide", "crow_feather", "cursed_bone" },
	partsLate = { "yeti_fur", "frost_scale" }, -- with a recipe of level 70-100
	tsk4Builds = {
		"destroyer.destroyerExp",
		"destroyer.destroyerBoss",
		"arcanist.arcanistBoss",
		"arcanist.arcanistOverload",
	},
	d5Levels = { 99 }, -- the S84 region rows have 70 / 75 / ... / 95
}

-- S94 (B4): expected kills of `bossId` to the first personal Mythic: 1 / the mean of Loot.bossChances(id, k).mythic
-- over k = 0 .. Config.Boss.dailyRuns - 1 (the same mean as the wiki's dayLine), no luck.
function Balance.expectedMythicKills(bossId: string): number
	local runs = Config.Boss.dailyRuns
	local sum = 0
	for k = 0, runs - 1 do
		sum += Loot.bossChances(bossId, k).mythic
	end
	return runs / math.max(1e-12, sum)
end

-- S94 (B3, J5): the protected +9 of the 10 slots (Legendary, ilvl 100; Upgrade.cost does not depend on the slot)
-- against the gold per hour of `classId` on the best gold area at `level` (coins + drop sales, Balance.areaHour).
export type ProtectedSet = {
	goldEq: number,
	cores: number,
	scrolls: number,
	perHour: number,
	area: string,
	hours: number,
}
function Balance.protectedSet(classId: string, level: number): ProtectedSet
	local item = makeItem(tierId(Balance.LOADOUT.Warrior.weapon, 100), 100, Rarities.LEGENDARY, 0, {})
	local plan = Balance.upgradePlan(item, 9, true)
	local slots = 2 + #Balance.ARMOR_SLOTS + #Balance.JEWELLERY
	local best, bestId = 0, "-"
	for _, area in areasCovering(level) do
		local h = Balance.areaHour(classId, level, area)
		local perHour = (h.coinPerKill + h.dropPerKill) * 3600 / h.secondsPerKill
		if perHour > best then
			best, bestId = perHour, area.id
		end
	end
	local goldEq = plan.goldEq * slots
	return {
		goldEq = goldEq,
		cores = plan.cores * slots,
		scrolls = plan.scrolls * slots,
		perHour = best,
		area = bestId,
		hours = goldEq / math.max(1e-9, best),
	}
end

-- S94 (K1): the rows of the Frost Peaks beyond the S83 region rows (ids "R.frostpeak.<group>..."): Vaelgrath, the
-- pace, the skill guards, support paths on the real spawners, the Elites' drop levels, hunting grounds, gold, parts.
-- balance.spec asserts them with the region except the rows with `report` (Balance.S94_REPORT).
function Balance.targetsS94(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S94
	local SkillModel = (require :: any)("./SkillModel")
	local L = S.bossLevel
	local function add(
		id: string,
		group: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		c: string?,
		lv: number?
	)
		target(rows, `R.frostpeak.{id}`, group, label, value, low, high, c, lv)
	end
	local def = Bosses.byId.vaelgrath :: any
	local flight = Balance.bossScriptConsts("vaelgrath").FLIGHT_SECONDS or 0
	-- Vaelgrath: the S83 / S87 model (bossFight with shield waves, flight and BossSchedule), both player variants
	for _, nodes in { false, true } do
		local at = if nodes then "@nodes" else ""
		local suffix = if nodes then " z węzłami" else ""
		-- S134: the fight length and the biggest blows are Balance.targetsS134 rows (bosses 2.0)
		for n = 3, 5 do
			local worst = 0
			for _, w in Balance.shieldWaves("vaelgrath", Balance.team(n, L, nodes)) do
				worst = math.max(worst, w.worst)
			end
			local label = `Vaelgrath, fala tarczy, {n} graczy L{L}{suffix}: HP na członka`
			add(`vaelgrath.wave{n}{at}`, "vaelgrath", label, worst, nil, S.wave, nil, L)
		end
	end
	do
		local mage = Balance.boss("vaelgrath", { Balance.player("Mage", 100) }).biggest[1].basic
		add(
			"vaelgrath.basic100",
			"vaelgrath",
			"Vaelgrath: zwykły cios / HP Maga L100",
			mage,
			S.basicHit[1],
			S.basicHit[2],
			"Mage",
			100
		)
		local tank = Balance.boss("vaelgrath", Balance.team(5, L)).tankHpPerMinute
		local tankLabel = `Vaelgrath (model S32): tank HP na minutę, L{L}`
		add("vaelgrath.tank", "vaelgrath", tankLabel, tank, nil, S.tankPerMinute, nil, L)
		-- the tank's whole intake (bossFight): only printed, the S32 row above counts basic and threat attacks
		for n = 3, 5 do
			local team = Balance.team(n, L)
			local f = Balance.bossFight("vaelgrath", team)
			local perMinute = f.memberDps[1] * 60 / team[1].values.maxHp
			add(
				`vaelgrath.tankFight{n}`,
				"vaelgrath",
				`Vaelgrath (bossFight): tank HP na minutę, {n} graczy`,
				perMinute,
				nil,
				nil,
				nil,
				L
			)
			rows[#rows].report =
				"tylko raport: całe przyjęcie tanka z zamiecią, pierścieniem i falami (miara S32 liczy atak podstawowy i threat)"
		end
		-- blizzard per minute and one storm tick on a level 100 Mage (C3, C4; party of 5 with the Mage swapped in)
		local team = Balance.team(5, L)
		team[2] = Balance.player("Mage", 100)
		local f = Balance.bossFight("vaelgrath", team)
		local blizzardLabel = "Vaelgrath: zamieć na minutę / HP Maga L100"
		add("vaelgrath.blizzard", "vaelgrath", blizzardLabel, f.raid.Mage or 0, nil, S.blizzard, "Mage", 100)
		local tick = f.hazardTick.Mage or 0
		local stormLabel = "Vaelgrath: jeden tick burzy / HP Maga L100"
		add("vaelgrath.storm", "vaelgrath", stormLabel, tick, S.storm[1], S.storm[2], "Mage", 100)
		add("vaelgrath.hpMul", "vaelgrath", "Vaelgrath ma hpMul", if def.hpMul ~= nil then 1 else 0, 1, nil)
		-- the flight (C7): phase 2 invulnerable for max(FLIGHT_SECONDS, the shield wave), 3-5 players
		for n = 3, 5 do
			local fight = Balance.bossFight("vaelgrath", Balance.team(n, L))
			local ph = fight.phases[2]
			local window = ph.shieldSeconds + ph.flightSeconds
			local want = math.max(flight, ph.shieldSeconds)
			local label = `Vaelgrath, {n} graczy: nietykalność fazy 2 / max(lot, fala)`
			add(`vaelgrath.flight{n}`, "vaelgrath", label, window / math.max(1e-9, want), 1 - 1e-9, 1 + 1e-9, nil, L)
			add(
				`vaelgrath.enrage{n}`,
				"vaelgrath",
				`Vaelgrath, {n} graczy: wściekłość`,
				if fight.enraged then 1 else 0,
				nil,
				0,
				nil,
				L
			)
		end
	end
	-- T-SK6 (C6): the dungeon Healer on the Defender, team S92 at the boss level - 1
	do
		local healer = SkillModel.build("healer.dungeon", "Cleric")
		local r = SkillModel.healerVsBoss(healer, "vaelgrath", { team = "s92" })
		add(
			"vaelgrath.tsk6",
			"vaelgrath",
			"T-SK6 Vaelgrath: Uzdrowiciel lochowy na Obrońcy",
			r.tsk6,
			S.tsk6[1],
			S.tsk6[2],
			"Cleric",
			L
		)
	end
	-- Vaelgrath bez wsparcia (C5): the S91 definition (Balance.bossNoSupport), waves of the same team
	for n = 3, 5 do
		local r = Balance.bossNoSupport("vaelgrath", n, L)
		local secondsLabel = `Vaelgrath bez wsparcia, {n} graczy: s`
		add(`vaelgrath.noSupport.{n}.seconds`, "noSupport", secondsLabel, r.seconds, nil, r.limit)
		local worst, hit = 0, 0
		for _, mem in r.members do
			worst = math.max(worst, mem.ratio)
			hit = math.max(hit, mem.biggest)
		end
		local label = `Vaelgrath bez wsparcia, {n} graczy: przyjmowane / podtrzymanie (najgorszy)`
		add(`vaelgrath.noSupport.{n}.sustain`, "noSupport", label, worst, nil, Balance.S91.noSupport.sustain, nil, L)
		local hitLabel = `Vaelgrath bez wsparcia, {n} graczy: największy cios / HP`
		add(`vaelgrath.noSupport.{n}.hit`, "noSupport", hitLabel, hit, nil, Balance.S91.noSupport.hit, nil, L)
		local team: { Player } = {}
		local mul: { number } = {}
		local m = Balance.monster(Balance.bossKind(def), def.level, "boss")
		for i, mem in r.members do
			local sp = SkillModel.player(SkillModel.build(mem.key), L)
			team[i] = sp.p
			mul[i] = mem.dps / math.max(1e-9, Balance.dps(sp.p, m) * Balance.BOSS_UPTIME)
		end
		local wave = 0
		for _, w in Balance.shieldWaves("vaelgrath", team, { dpsMul = mul }) do
			wave = math.max(wave, w.worst)
		end
		local waveLabel = `Vaelgrath bez wsparcia, fala tarczy, {n} graczy: HP na członka`
		add(`vaelgrath.noSupport.{n}.wave`, "noSupport", waveLabel, wave, nil, S.wave, nil, L)
	end
	-- the Mythic for every class (D1) and the slower Mythic ladder (D2)
	for _, c in Balance.CLASSES do
		local share = Balance.unusableMythics("vaelgrath", c, S.mythicRolls)
		add(`vaelgrath.mythic.{c}`, "vaelgrath", `Vaelgrath: Mityki nieużyteczne dla {c}`, share, nil, 0, c, 100)
	end
	do
		local ratio = Balance.expectedMythicKills("vaelgrath") / Balance.expectedMythicKills("grimrok")
		local label = "Vaelgrath: zabicia do Mityka / Grimrok"
		add("vaelgrath.mythicLadder", "vaelgrath", label, ratio, S.mythicLadder[1], S.mythicLadder[2])
	end
	-- pace 70 -> 100 and 1 -> 100 (G)
	do
		local P = S.pace
		local sum = 0
		for lv = 70, 99 do
			sum += Balance.paceWindowAt("Warrior", lv).hours
		end
		local sumLabel = "Tempo 70 → 100 (okno, bez Vaelgratha): h"
		add("pace.sum", "pace", sumLabel, sum, P.hours[1], P.hours[2], "Warrior")
		local h99 = Balance.paceWindowAt("Warrior", 99).hours
		add("pace.h99", "pace", "Tempo: h(99)", h99, P.h99[1], P.h99[2], "Warrior", 99)
		for lv = 70, 99 do
			local r = Balance.paceWindowAt("Warrior", lv).hours
				/ math.max(1e-9, Balance.paceWindowAt("Warrior", lv - 1).hours)
			add(`pace.step.{lv}`, "pace", `Tempo: h({lv}) / h({lv - 1})`, r, nil, P.step, "Warrior", lv)
		end
		local total = 0
		for lv = 1, 99 do
			total += Balance.paceWindowAt("Warrior", lv).hours
		end
		local totalLabel = "Tempo 1 → 100 (okno, bez bossów): h"
		add("pace.total", "pace", totalLabel, total, P.total[1], P.total[2], "Warrior")
	end
	-- skill guards in the band (H1): bases and the reference builds, T-SK3 of the reference builds. The S92 / S93
	-- rule: a guard of a build whose own value at 70 (S93's end of the band) is already above the limit and not
	-- below the band's value is printed when it is above the limit itself (a row within the limit stays asserted);
	-- any other row above the limit stays asserted unless S94_REPORT names it
	for _, c in Balance.CLASSES do
		for _, build in SkillModel.builds(c) do
			local lim = SkillModel.GUARD_LIMITS
			local g70 = SkillModel.guards(build, 70)
			for _, lv in S.guardLevels do
				local g = SkillModel.guards(build, lv)
				local key = `{c}.{build.key}.{lv}`
				for _, spec in
					{
						{ "tsk1", "tsk1rel", `T-SK1 {c} {build.key} L{lv} / L20` },
						{ "tsk2", "tsk2rel", `T-SK2 {c} {build.key} L{lv} / L20` },
						{ "tsk3", "tsk3cap", `T-SK3 {c} {build.key} L{lv} / areaCap` },
					}
				do
					local field = spec[2]
					local v = (g :: any)[field]
					local limit = (lim :: any)[field]
					local at70 = (g70 :: any)[field]
					add(`guard.{spec[1]}.{key}`, "guards", spec[3], v, nil, limit, c, lv)
					if spec[1] == "tsk3" and build.key == "base" then
						rows[#rows].report = "tylko raport (T-SK3 podstawy, S90 I3)"
					elseif at70 > limit and v > limit and v <= at70 + 1e-9 then
						rows[#rows].report =
							`poza zasięgiem dźwigni S94: na 70 (pasmo S93) build ma już {string.format("%.2f", at70)}`
					end
				end
			end
		end
	end
	-- T-SK4 of the asserted Mage builds and T-SK5 of the dungeon Healer on the Defender in the band (H2)
	for _, key in S.tsk4Builds do
		local build = SkillModel.build(key, "Mage")
		local band = SkillModel.TSK4_BANDS[key]
		for _, lv in S.guardLevels do
			local v = SkillModel.metrics(build, lv).tsk4
			add(`tsk4.{key}.{lv}`, "guards", `T-SK4 Mage {key} {lv}`, v, band[1], band[2], "Mage", lv)
		end
	end
	do
		local healer = SkillModel.build("healer.dungeon", "Cleric")
		for _, lv in S.guardLevels do
			local v = SkillModel.oneHeal(healer, lv, SkillModel.defenderTank(lv))
			local band = SkillModel.TSK5_BAND
			add(`tsk5.{lv}`, "guards", `T-SK5 Uzdrowiciel lochowy na Obrońcy {lv}`, v, band[1], band[2], "Cleric", lv)
		end
	end
	-- support and tank paths on the real spawners (E6, ROZWOJ 7.5): Elite won, Elite II lost
	for _, spec in Balance.S92.supportBuilds do
		local build = SkillModel.build(spec[2], spec[1])
		for _, lv in S.supportLevels do
			local elite, elite2 = SkillModel.eliteKinds(lv)
			local ok = 0
			if elite and elite2 then
				local a = SkillModel.duel(build, lv, elite, "elite")
				local b = SkillModel.duel(build, lv, elite2, "elite2")
				ok = if a.won and not b.won then 1 else 0
			end
			local label = `{spec[2]} L{lv}: Elita wygrana, Elita II przegrana ({elite or "–"} / {elite2 or "–"})`
			add(`support.{spec[2]}.{lv}`, "support", label, ok, 1, 1, spec[1], lv)
		end
	end
	-- the Elites drop every item level 71-100 (I2), hunting grounds (E2)
	for lv = 71, 100 do
		local e = if Balance.eliteDropsIlvl("frostpeak", lv) then 1 else 0
		add(`ilvl.elite.{lv}`, "drop", `Elity Lodowych Szczytów dropią ilvl {lv}`, e, 1, nil, nil, lv)
		add(`areas.{lv}`, "areas", `Expowiska z poziomem {lv}`, Balance.areasAt(lv), S.areas, nil, nil, lv)
	end
	-- D5 K0 at 99 (I1: 75 / 80 / 85 / 90 / 95 / 99; the S84 region rows have 70-95)
	do
		local d5 = Balance.REGION_TARGETS.d5
		local u, h = d5.uniquePerHour, d5.heroicPerHour
		for _, lv in S.d5Levels do
			for _, c in Balance.CLASSES do
				local d = Balance.dropsPerHour(c, lv, "K0", false)
				add(
					`d5.{c}.{lv}.unique`,
					"d5",
					`{c} {lv}: Unikaty dla klasy na h expienia`,
					d.unique,
					u[1],
					u[2],
					c,
					lv
				)
				add(`d5.{c}.{lv}.heroic`, "d5", `{c} {lv}: Heroiki dla klasy na h Elit`, d.heroic, h[1], h[2], c, lv)
			end
		end
	end
	-- gold (J): +1..+3 of the weapon, chain potions (upper and lower bound), backpacks, prices, ores, the +9 set
	for lv = 71, 99 do
		for _, u in Balance.upgradeVsIncome(lv) do
			local label = `{u.classId} {lv}: +1…+3 / dochód poziomu`
			add(`gold.up3.{u.classId}.{lv}`, "gold", label, u.up3, nil, S.up3, u.classId, lv)
		end
		for _, c in Balance.CLASSES do
			local share = Balance.economyAt(c, lv, { potions = "chain" }).potionShare
			local label = `{c} {lv}: mikstury łańcuchowe / dochód`
			add(`gold.chain.{c}.{lv}`, "gold", label, share, nil, S.chainPotions[2], c, lv)
			add(`gold.chainLow.{c}.{lv}`, "gold", `{label} (dolna granica)`, share, S.chainPotions[1], nil, c, lv)
		end
	end
	for _, b in S.backpacks do
		local item = Items.get(b.id) :: any
		for _, c in Balance.CLASSES do
			local levels = item.buyPrice / math.max(1e-9, Balance.levelIncome(c, b.level))
			local label = `{c}: {b.id} (od {b.level}.) / dochód poziomu`
			add(`gold.{b.id}.{c}`, "gold", label, levels, S.backpackLevels[1], S.backpackLevels[2], c, b.level)
		end
	end
	do
		local prev = Items.get(S.backpacks[1].id) :: any
		local last = Items.get(S.backpacks[2].id) :: any
		local before = Items.get("backpack_130") :: any
		add("gold.backpackOrder.160", "gold", "Cena plecaka 160 − 130", prev.buyPrice - before.buyPrice, 1, nil)
		add("gold.backpackOrder.200", "gold", "Cena plecaka 200 − 160", last.buyPrice - prev.buyPrice, 1, nil)
	end
	for i = 2, #S.potionTiers do
		local lower, higher = S.potionTiers[i - 1], S.potionTiers[i]
		local d = Balance.potionGoldPerHp(higher) - Balance.potionGoldPerHp(lower)
		add(`gold.potionOrder.{higher}`, "gold", `Złoto za 1 HP: jakość {higher} − jakość {lower}`, d, 0, nil)
	end
	do
		local shop = Shops.get("blacksmith") :: any
		for _, ore in S.ores do
			local level = -1
			for _, e in shop.entries do
				if e.item == ore.item then
					level = e.level or 0
				end
			end
			add(`gold.ore.{ore.item}`, "gold", `Kowal sprzedaje {ore.item} od poziomu`, level, ore.level, ore.level)
		end
	end
	do
		local set = Balance.protectedSet("Warrior", 99)
		local label = `Komplet +9 z ochroną (10 Legendarnych ilvl 100) / złoto na h ({set.area}, Wojownik L99): h`
		add("gold.set9", "gold", label, set.hours, S.setHours[1], S.setHours[2], "Warrior", 99)
	end
	-- parts (K): every kind of the region drops a part; the region's parts are ingredients of a recipe at 70-100
	for _, kind in Monsters.list do
		if kind.region == 4 then
			local tbl = LootTables.get(kind.lootTable) :: any
			local has = 0
			for _, m in tbl.materials do
				local item = Items.get(m.id) :: any
				if item and item.type == "part" then
					has = 1
				end
			end
			add(`parts.kind.{kind.id}`, "parts", `{kind.id}: część potwora`, has, 1, nil)
		end
	end
	local uses = Balance.partUses(1, 100)
	for _, part in S.parts do
		add(
			`parts.recipe.{part}`,
			"parts",
			`{part}: składnik przepisu dostępnego na 70–100`,
			#(uses[part] or {}),
			1,
			nil
		)
	end
	local late = Balance.partUses(70, 100)
	for _, part in S.partsLate do
		add(`parts.late.{part}`, "parts", `{part}: składnik przepisu z poziomem 70–100`, #(late[part] or {}), 1, nil)
	end
	do
		local elixir = Recipes.get("elixir_resIce") :: any
		local v = if elixir then elixir.level else 0
		add("parts.elixirIce", "parts", "elixir_resIce: poziom przepisu", v, 70, 70)
	end
	for _, row in rows do
		local why = Balance.S94_REPORT[row.id]
		if why then
			row.report = why
		end
	end
	return rows
end

-- S94 (L): rows of targetsS94 out of reach of the S94 levers (printed with the reason; docs/DECYZJE.md S94).
Balance.S94_REPORT = {} :: { [string]: string }
do
	local R = Balance.S94_REPORT
	-- S94: T-SK6 Vaelgratha NIEDOKOŃCZONE jak Azgora w S93 (asercja ≤ 2,5 z C6 nie przechodzi, wynik ok. 15,9; decyzja
	-- właściciela z S93 dalej otwarta): Uzdrowiciel lochowy na 99 leczy od maks. HP celu (S69) wielokrotność tego, co
	-- Obrońca przyjmuje, a obrażenia w tanka trzyma wiersz S32 (3,45 maks. HP na minutę ≤ 3,5; przy atkMul 1,3 sprzed
	-- S94 T-SK6 było 6,0 przy tanku 10,6 / min); kotwica heal 100 trzyma T-SK5 (0,35 na 100)
	R["R.frostpeak.vaelgrath.tsk6"] =
		"NIEDOKOŃCZONE S94: T-SK6 15,9 wobec ≤ 2,5 (C6) nieosiągalne dźwigniami S94 (tank S32 3,45 / min ≤ 3,5, leczenie od maks. HP celu, S69); decyzja właściciela jak dla Azgora (S93)"
	-- S94: Elita / Elita II ścieżek wsparcia i tanka poza zasięgiem dźwigni S94: każda ścieżka wygrywa Elitę II solo z
	-- miksturami (HP na koniec 0,46-1,00 na 80 i 95), a krzywe Elit II trzyma duet <= 150 % i trio 60-100 %; dane
	-- ścieżek S89-S90 (jak S92 i S93)
	for _, spec in Balance.S92.supportBuilds do
		for _, lv in Balance.S94.supportLevels do
			R[`R.frostpeak.support.{spec[2]}.{lv}`] =
				"poza zasięgiem dźwigni S94: wygrywa Elitę II solo z miksturami (krzywe Elit II trzyma duet ≤ 150 %); dla właściciela"
		end
	end
	-- S94: mikstury łańcuchowe (górna granica) poza zasięgiem dźwigni S94: Potężna 1800 (0,18 zł za 1 HP) to dół
	-- kolejności cen (Wielka 0,175), a łańcuch daje 0,33-1,04 dochodu na 71-99 (Kapłan najwięcej: długie walki);
	-- ceny jakości 1-4 i krzywa potionCooldown są globalne
	for lv = 71, 99 do
		for _, c in Balance.CLASSES do
			R[`R.frostpeak.gold.chain.{c}.{lv}`] =
				"poza zasięgiem dźwigni S94: Potężna 1800 to dół kolejności cen (0,18 ≥ 0,175 zł/HP), ceny 1–4 i potionCooldown globalne; dla właściciela"
		end
	end
	-- S94: komplet +9 z ochroną poza zasięgiem dźwigni S94: ok. 12 mln złota (83 % to złoto ulepszeń z Config.Upgrade,
	-- S87; esencje 12 %, zwoje 5 %) wobec ok. 33 tys. na godzinę Wojownika L99 na Iglicy Wyrmów = 366 h; materiały
	-- Vaelgratha (Rdzenie, zwoje) prawie nie ruszają goldEq (Rdzeni się nie kupuje), dochód pasma po S94 E-F
	R["R.frostpeak.gold.set9"] =
		"poza zasięgiem dźwigni S94: 366 h wobec 150–300 (złoto ulepszeń z Config.Upgrade, S87, to ok. 83 % kosztu); dla właściciela: goldHigh 20 → ok. 15"
	-- S94: strażniki T-SK ponad limitem D1 w paśmie 71-100 (reguła S92 / S93 ich nie zwalnia), każda grupa z powodem i
	-- linią w DECYZJE S94; liczby (wartość na 70 → najwyższa w paśmie) w docs/BALANS.md
	local guardReasons = {
		-- S94: poza zasięgiem dźwigni S94: build już na 70 ponad limitem D1 (S93), w paśmie rośnie z poziomem przez
		-- sprzęt, statystyki i rangi 71-95 całej klasy; węzły SkillCurves zmieniłyby blok ścieżek S89-S90 na 100
		rise = "poza zasięgiem dźwigni S94: na 70 już ponad limitem D1 (S93), w paśmie rośnie z poziomem klasy; dla właściciela",
		-- S94: Furia to zamrożone odniesienie obrażeń (S89, R1 2,4-2,6)
		fury = "poza zasięgiem dźwigni S94: Furia to zamrożone odniesienie obrażeń (S89); dla właściciela",
		-- S94: Strażnik z Groźbą: T-SK3 1,09 × areaCap 2,0 = 2,18 na 70-100; S89 C1: Strażnik ma 2,2 (DECYZJE S89)
		guardian = "poza zasięgiem dźwigni S94: T-SK3 Strażnika ≤ 2,2 (S89 C1, Groźba), tu 2,18",
		-- S94: Chorąży (Dowódca, Opiekun): skoki z węzłów rzędów 9-11 (70, 80, 90; liczby S89) i rang zwieńczeń do 95
		row10 = "poza zasięgiem dźwigni S94: skoki z węzłów rzędów 9–11 Chorążego (S89) i rang zwieńczenia do 95; dla właściciela",
		-- S94: na 70 w limicie, w paśmie ponad nim o 1-16 % (podstawa Łowcy T-SK2 1,26-1,27 od 85, Zwiadowca T-SK1 do
		-- 1,33 na 100, Traper T-SK3 1,02-1,10): sprzęt i rangi 71-95 klasy; węzeł SkillCurves rusza blok ścieżek S90
		cross = "poza zasięgiem dźwigni S94: przekracza limit D1 w paśmie przez sprzęt i rangi 71–95 klasy (blok ścieżek S90 trzyma 100); dla właściciela",
	}
	for _, spec in
		{
			{ "tsk1", "Warrior.base", { 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Warrior.base", { 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Warrior.base.loadout", { 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk3", "Warrior.guardian.defender", { 75, 80, 85, 90, 95, 99, 100 }, "guardian" },
			{ "tsk3", "Warrior.guardian.loner", { 75, 80, 85, 90, 95, 99, 100 }, "guardian" },
			{ "tsk1", "Warrior.berserker.fury", { 75, 80, 85, 90, 95, 99, 100 }, "fury" },
			{ "tsk2", "Warrior.berserker.fury", { 80, 85, 90, 95, 99, 100 }, "fury" },
			{ "tsk1", "Warrior.berserker.butcher", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Warrior.berserker.butcher", { 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Warrior.standard.commander", { 75, 80, 85, 90, 95, 99, 100 }, "row10" },
			{ "tsk2", "Warrior.standard.commander", { 75, 80, 85, 90, 95, 99, 100 }, "row10" },
			{ "tsk1", "Warrior.standard.warden", { 75, 80, 85, 90, 95, 99, 100 }, "row10" },
			{ "tsk2", "Warrior.standard.warden", { 75, 80, 85, 90, 95, 99, 100 }, "row10" },
			{ "tsk2", "Hunter.base", { 85, 95, 99, 100 }, "cross" },
			{ "tsk1", "Hunter.marksman.kingslayer", { 75, 95, 100 }, "rise" },
			{ "tsk2", "Hunter.marksman.kingslayer", { 75, 95, 99, 100 }, "rise" },
			{ "tsk1", "Hunter.marksman.eliteHunter", { 75, 100 }, "rise" },
			{ "tsk2", "Hunter.marksman.eliteHunter", { 75, 100 }, "rise" },
			{ "tsk2", "Hunter.trapper.poacher", { 99, 100 }, "rise" },
			{ "tsk3", "Hunter.trapper.poacher", { 80, 85, 90, 95 }, "cross" },
			{ "tsk2", "Hunter.trapper.poisoner", { 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk3", "Hunter.trapper.poisoner", { 80, 85, 90, 95, 99, 100 }, "cross" },
			{ "tsk1", "Hunter.scout.partyHunter", { 85, 90, 95, 99, 100 }, "cross" },
			{ "tsk1", "Hunter.scout.tracker", { 85, 90, 95, 99, 100 }, "cross" },
			{ "tsk1", "Mage.base", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Mage.base", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Mage.base.loadout", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Mage.base.loadout", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Mage.destroyer.destroyerExp", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Mage.destroyer.destroyerExp", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Mage.destroyer.destroyerBoss", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Mage.destroyer.destroyerBoss", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Mage.arcanist.arcanistBoss", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Mage.arcanist.arcanistBoss", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Mage.arcanist.arcanistOverload", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Mage.arcanist.arcanistOverload", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Cleric.base", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Cleric.base", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Cleric.healer.dungeon", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Cleric.healer.dungeon", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Cleric.healer.solo", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Cleric.healer.solo", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Cleric.fortune.plunder", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Cleric.fortune.plunder", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Cleric.inquisitor.solo", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Cleric.inquisitor.solo", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk1", "Cleric.inquisitor.bulwark", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
			{ "tsk2", "Cleric.inquisitor.bulwark", { 75, 80, 85, 90, 95, 99, 100 }, "rise" },
		}
	do
		for _, lv in spec[3] do
			R[`R.frostpeak.guard.{spec[1]}.{spec[2]}.{lv}`] = (guardReasons :: any)[spec[4]]
		end
	end
end

-- S134: bosses 2.0 ------------------------------------------------------------------------------------------------

-- Targets of the boss rework (docs/sessions S134 E2; test data, never game numbers): a boss never scales with the
-- party, so 5 players beat it faster than 3 and 3 faster than 2; the big blows (`avoid`) are dodged, the regular
-- attacks stay survivable, the party mechanics need the party, and a solo player loses on equal gear but wins with
-- overpowered gear (the Fury Warrior with a Mythic set +9).
Balance.S134 = {
	bosses = { "grimrok", "morvane", "azgor", "vaelgrath" },
	five = { 3, 4.5 }, -- minutes of 5 players at the boss level - 1
	three = { 5, 7.5 }, -- minutes of 3 players, and at most threeEnrage x enrageAfter
	threeEnrage = 0.8,
	avoid = { 0.60, 0.90 }, -- the biggest big blow / HP of a Mage at the boss level (convention gear)
	avoidTank = 0.70, -- ... of a Warrior at the boss level
	hit = 0.50, -- the biggest blow that cannot be dodged (no split, no channel) / HP of a Mage at the boss level
	split3 = 0.75, -- a split blow on 3 players standing together / HP of the Mage
	splitSolo = 1.0, -- ... on a lone player (kills)
	wave = 1.10, -- HP per member per shield wave, 3 players (the S32 group limit, S92-S94)
	op = { rarity = Rarities.MYTHIC, up = 9 }, -- the overpowered solo: the Fury Warrior (S91.noSupportTeam[1]) with this gear
	opGap = 10, -- Grimrok and Morvane: the same also at the boss level + opGap (Combat.levelGap*)
	opGapBosses = { grimrok = true, morvane = true } :: { [string]: boolean },
}

-- S134: rows of targetsS134 out of reach of the S134 levers (printed with the reason; docs/DECYZJE.md S134).
-- S146: the S143 entry (the Warrior's solo on Vaelgrath with the two-handed pool) is in band again (5.05 s >= 4.5 s)
Balance.S134_REPORT = {} :: { [string]: string }

-- S134 (E2): the boss targets in one place (ids "S134.<boss>..."); balance.spec ("Balance: bosses 2.0 (S134)")
-- asserts every row without `report`.
function Balance.targetsS134(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S134
	local function add(
		id: string,
		group: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		c: string?,
		lv: number?
	)
		target(rows, `S134.{id}`, group, label, value, low, high, c, lv)
	end
	for _, bossId in S.bosses do
		local def = Bosses.byId[bossId] :: any
		local L = def.level - 1
		local name = (string.gsub(bossId, "^%l", string.upper))
		-- the fight gets shorter with the party (both player variants)
		for _, nodes in { false, true } do
			local at = if nodes then "@nodes" else ""
			local suffix = if nodes then " z węzłami" else ""
			local seconds: { [number]: number } = {}
			for n = 2, 5 do
				seconds[n] = Balance.bossFight(bossId, Balance.team(n, L, nodes)).seconds
				local low, high = nil, nil
				if n == 5 then
					low, high = S.five[1], S.five[2]
				elseif n == 3 then
					low, high = S.three[1], math.min(S.three[2], S.threeEnrage * def.enrageAfter / 60)
				end
				local label = `{name}, {n} graczy L{L}{suffix}: min`
				add(`{bossId}.team{n}{at}`, bossId, label, seconds[n] / 60, low, high, nil, L)
			end
			for n = 2, 4 do
				local label = `{name}{suffix}: czas {n + 1} graczy / {n} graczy`
				add(`{bossId}.faster{n + 1}{at}`, bossId, label, seconds[n + 1] / seconds[n], nil, 1 - 1e-9, nil, L)
			end
		end
		-- the big blows and the regular hits on a Mage and a Warrior of the boss level
		do
			local team = Balance.team(5, L)
			team[1] = Balance.player("Warrior", def.level)
			team[2] = Balance.player("Mage", def.level)
			local f = Balance.bossFight(bossId, team)
			local lv = def.level
			local avoidLabel = `{name}: największy cios do uniknięcia / HP Maga L{lv}`
			add(
				`{bossId}.avoid.mage`,
				bossId,
				avoidLabel,
				f.biggestAvoidable.Mage or 0,
				S.avoid[1],
				S.avoid[2],
				"Mage",
				lv
			)
			local tankLabel = `{name}: największy cios do uniknięcia / HP Wojownika L{lv}`
			add(
				`{bossId}.avoid.tank`,
				bossId,
				tankLabel,
				f.biggestAvoidable.Warrior or 0,
				nil,
				S.avoidTank,
				"Warrior",
				lv
			)
			local hitLabel = `{name}: największy cios nie do uniknięcia / HP Maga L{lv}`
			add(`{bossId}.hit.mage`, bossId, hitLabel, f.biggestHit.Mage or 0, nil, S.hit, "Mage", lv)
		end
		-- the mechanics with 3 players standing together and alone (equal gear)
		local three = Balance.bossFight(bossId, Balance.team(3, L))
		local solo = Balance.bossNoSupport(bossId, 1, L)
		local soloMech = solo.fight.mechanics
		local soloClass = solo.members[1].classId
		if three.mechanics.hasSplit then
			local label = `{name}: wspólny cios, 3 graczy razem / HP Maga`
			add(`{bossId}.split3`, bossId, label, three.mechanics.split.Mage or 0, nil, S.split3, "Mage", L)
			local soloLabel = `{name}: wspólny cios w pojedynkę / HP`
			add(
				`{bossId}.split.solo`,
				bossId,
				soloLabel,
				soloMech.split[soloClass] or 0,
				S.splitSolo,
				nil,
				soloClass,
				L
			)
		end
		if three.mechanics.hasChannel then
			local m3 = three.mechanics
			local label = `{name}: przerwanie zaklęcia, 3 graczy: s`
			add(`{bossId}.channel3`, bossId, label, m3.channelSeconds, nil, m3.channelLimit, nil, L)
			local soloLabel = `{name}: przerwanie zaklęcia w pojedynkę: s`
			add(
				`{bossId}.channel.solo`,
				bossId,
				soloLabel,
				soloMech.channelSeconds,
				soloMech.channelLimit + 1e-9,
				nil,
				soloClass,
				L
			)
		end
		do
			local worst = 0
			for _, w in Balance.shieldWaves(bossId, Balance.team(3, L)) do
				worst = math.max(worst, w.worst)
			end
			add(`{bossId}.wave3`, bossId, `{name}, fala tarczy, 3 graczy: HP na członka`, worst, nil, S.wave, nil, L)
		end
		-- solo on equal gear loses: the split kills, the channel is not broken, the intake beats the sustain or the
		-- fight runs into the enrage
		do
			local ratio = solo.members[1].ratio
			local splitKills = (soloMech.split[soloClass] or 0) >= S.splitSolo
			local loses = splitKills
				or not soloMech.channelBroken
				or ratio > Balance.S91.noSupport.sustain
				or solo.seconds > def.enrageAfter
			local label = `{name}: solo na równym sprzęcie przegrywa (1 = tak)`
			add(`{bossId}.solo.loses`, bossId, label, if loses then 1 else 0, 1, nil, soloClass, L)
		end
		-- solo with overpowered gear wins (at the boss level; Grimrok and Morvane also at the boss level + opGap)
		local variants = { { def.level, "" } }
		if S.opGapBosses[bossId] then
			table.insert(variants, { def.level + S.opGap, `@gap{S.opGap}` })
		end
		for _, v in variants do
			local lv, at = v[1], v[2]
			local op = Balance.bossNoSupport(bossId, 1, lv, S.op :: any)
			local mech = op.fight.mechanics
			local c = op.members[1].classId
			local tag = `{name}: solo Mityczny +9 L{lv}`
			if mech.hasSplit then
				add(
					`{bossId}.op{at}.split`,
					bossId,
					`{tag}, wspólny cios / HP`,
					mech.split[c] or 0,
					nil,
					S.splitSolo - 1e-9,
					c,
					lv
				)
			end
			if mech.hasChannel then
				add(
					`{bossId}.op{at}.channel`,
					bossId,
					`{tag}, przerwanie: s`,
					mech.channelSeconds,
					nil,
					mech.channelLimit,
					c,
					lv
				)
			end
			local sustain = Balance.S91.noSupport.sustain
			add(
				`{bossId}.op{at}.sustain`,
				bossId,
				`{tag}, przyjmowane / podtrzymanie`,
				op.members[1].ratio,
				nil,
				sustain,
				c,
				lv
			)
			add(`{bossId}.op{at}.seconds`, bossId, `{tag}: s`, op.seconds, nil, def.timeLimit - 1e-9, c, lv)
		end
	end
	for _, row in rows do
		local why = Balance.S134_REPORT[row.id]
		if why then
			row.report = `właściciel: {why}`
		end
	end
	return rows
end

-- S94 (L3): the cross rows 1-100 no band checked in full (ids "X.<group>..."): the pace step h(L) / h(L - 1) <= 1.3
-- on 20-99 across the band borders 45 and 70, at least two outdoor hunting grounds on 21-100, the cave Elites of some
-- region drop every item level 21-100. The sum 1 -> 100 is R.frostpeak.pace.total; the T-SK guards of the control
-- levels are the band rows (balance.spec checks that every control level has them).
Balance.CROSS_GUARD_LEVELS = { 30, 40, 44, 50, 60, 69, 70, 75, 80, 90, 99, 100 }
function Balance.targetsCross(): { TargetRow }
	local rows: { TargetRow } = {}
	for lv = 20, 99 do
		local r = Balance.paceWindowAt("Warrior", lv).hours
			/ math.max(1e-9, Balance.paceWindowAt("Warrior", lv - 1).hours)
		target(
			rows,
			`X.pace.step.{lv}`,
			"pace",
			`Tempo: h({lv}) / h({lv - 1})`,
			r,
			nil,
			Balance.S94.pace.step,
			"Warrior",
			lv
		)
	end
	for lv = 21, 100 do
		local label = `Expowiska z poziomem {lv}`
		target(rows, `X.areas.{lv}`, "areas", label, Balance.areasAt(lv), Balance.S94.areas, nil, nil, lv)
		local any = 0
		for _, mapId in Balance.REGION_IDS do
			if Balance.eliteDropsIlvl(mapId, lv) then
				any = 1
			end
		end
		target(rows, `X.ilvl.elite.{lv}`, "drop", `Elity dropią ilvl {lv}`, any, 1, nil, nil, lv)
	end
	return rows
end

-- Targets 20-100 (S83, balance plan 2.5) ------------------------------------------------------------------------

Balance.GLOBAL_LEVELS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }
-- D4 (preliminary, the owner's decision is open): hours of the bands 20-45 / 45-70 / 70-100, tolerance +-25 %.
Balance.BAND_HOURS = { { 20, 45, 14 }, { 45, 70, 25 }, { 70, 100, 41 } }
Balance.BAND_HOURS_TOLERANCE = 0.25

local function shopPlayer(classId: string, level: number): Player
	return Balance.player(
		classId,
		level,
		{ ilvl = Items.generate.tierFor(level), weaponIlvl = Balance.shopTier(level) }
	)
end

-- Rows G1-G6 and G11-G13 in the S32 convention (G7-G9 come with S84, G10 with S85-S86). Asserted by balance.spec
-- from S87 (GLOBAL_ASSERT); rows with `report` stay a report. S91: G12 asserted (the new fixture, 0 differences
-- outside BalanceTables.ALLOWED_1_20_DIFFS).
function Balance.targetsGlobal(): { TargetRow }
	local rows: { TargetRow } = {}
	local function add(id: string, label: string, value: number, low: number?, high: number?, c: string?, L: number?)
		table.insert(rows, {
			id = id,
			group = string.match(id, "^(G%d+)") or id,
			label = label,
			value = value,
			low = low,
			high = high,
			classId = c,
			level = L,
		})
	end
	for _, L in Balance.GLOBAL_LEVELS do
		local duelSeconds: { number } = {}
		for _, c in Balance.CLASSES do
			local p = Balance.cachedPlayer(c, L)
			local generic = Balance.monster(Balance.GENERIC, L)
			-- G1: one monster of the level 6-10 s (test 5.5-10), Cleric up to 12 s; 12-25 % HP (test from 10 %), Cleric from 9 %
			local duel = Balance.duel(p, generic)
			table.insert(duelSeconds, duel.seconds)
			add("G1.s", `{c} {L}: 1 na 1 s`, duel.seconds, 5.5, if c == "Cleric" then 12 else 10, c, L)
			add("G1.hp", `{c} {L}: 1 na 1 HP`, duel.hpLost, if c == "Cleric" then 0.09 else 0.1, 0.25, c, L)
			-- G2: an average group 35-60 % (Mage up to 70 %, Cleric from 30 %), a group of 4 up to 110 %
			local g = Balance.expectedGroup(p, Balance.GENERIC, L)
			add(
				"G2.avg",
				`{c} {L}: grupa średnio HP`,
				g.hpLost,
				if c == "Cleric" then 0.3 else 0.35,
				if c == "Mage" then 0.7 else 0.6,
				c,
				L
			)
			add("G2.size4", `{c} {L}: grupa 4 HP`, g.bySize[4].hpLost, nil, 1.1, c, L)
			-- G3: three monsters of the level without skills 40-95 %
			local skill = Balance.SKILL_DPS
			Balance.SKILL_DPS = 1
			local three = Balance.groupFight(p, Balance.group(Balance.GENERIC, L, 3))
			Balance.SKILL_DPS = skill
			add("G3", `{c} {L}: trzy potwory bez umiejętności HP`, three.hpLost, 0.4, 0.95, c, L)
			-- G4: shop gear (up to 9 levels too low): up to 15.5 s (Cleric 20), up to 36 % HP
			local shop = Balance.duel(shopPlayer(c, L), generic)
			add("G4.s", `{c} {L}: sprzęt ze sklepu s`, shop.seconds, nil, if c == "Cleric" then 20 else 15.5, c, L)
			add("G4.hp", `{c} {L}: sprzęt ze sklepu HP`, shop.hpLost, nil, 0.36, c, L)
		end
		-- G5: Hunter / Warrior DPS 1.15-1.35, power 0.95-1.10
		local w, h = Balance.cachedPlayer("Warrior", L), Balance.cachedPlayer("Hunter", L)
		local m = Balance.monster(Balance.GENERIC, L)
		add("G5.dps", `{L}: DPS Łowca / Wojownik`, Balance.dps(h, m) / Balance.dps(w, m), 1.15, 1.35, "Hunter", L)
		add("G5.power", `{L}: moc Łowca / Wojownik`, Balance.power(h) / Balance.power(w), 0.95, 1.1, "Hunter", L)
		-- G6: slowest / fastest class 1 on 1 up to 2.2
		local lo, hi = math.huge, 0
		for _, s in duelSeconds do
			lo, hi = math.min(lo, s), math.max(hi, s)
		end
		add("G6", `{L}: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza)`, hi / lo, nil, 2.2, nil, L)
	end
	-- G11: every attack of every phase of the four bosses at least 50 % of its cooldown rate
	for _, def in Bosses.list do
		for phase = 1, #def.phases + 1 do
			local cad = Balance.bossCadence(def, phase)
			for _, attack in def.attacks do
				local share = cad.rateShare[attack.id]
				if share then
					add(
						"G11",
						`{def.id} faza {phase}: {attack.id} (tempo / odnowienie)`,
						share,
						0.5,
						nil,
						nil,
						def.level
					)
				end
			end
		end
	end
	-- G12: the 1-20 fixture (S91: asserted; balance1_20.spec asserts it too), allowed differences from
	-- BalanceTables.ALLOWED_1_20_DIFFS do not count
	do
		local BalanceTables = require("./BalanceTables")
		local fixture = BalanceTables.fixtureDiff(BalanceTables.ALLOWED_1_20_DIFFS)
		table.insert(rows, {
			id = "G12",
			group = "G12",
			label = "1–20: niedozwolone różnice wobec fixture i brakujące klucze",
			value = fixture.unexpected + #fixture.missing,
			high = 0,
		})
	end
	-- G13 (preliminary): grind hours per level of the generic kind (without quests: a main quest can pay the whole
	-- level) rise over 25-100; band hours (with quests and carry) within D4 +-25 %
	do
		local falls, last = 0, -math.huge
		for L = 25, 99 do
			local pace = Balance.paceAt("Warrior", L, { kind = Balance.GENERIC })
			-- S99: without quests there is nothing to compensate: the curve without the quest budget multiplier
			-- (its steps follow the quest windows and would read as falls)
			local expPerKill = pace.expPerKill / Balance.budgetMul(L)
			local hours = Exp.expToNext(L) / expPerKill * pace.secondsPerKill / 3600
			if hours < last then
				falls += 1
			end
			last = hours
		end
		add("G13.rise", "25–99: spadki h/poziom rodzaju ogólnego bez zadań (Wojownik)", falls, nil, 0)
		for _, band in Balance.BAND_HOURS do
			local hours = Balance.paceBand("Warrior", band[1], band[2]).hours
			local t = Balance.BAND_HOURS_TOLERANCE
			add(
				`G13.band`,
				`{band[1]}–{band[2]}: godzin (cel D4 {band[3]} h)`,
				hours,
				band[3] * (1 - t),
				band[3] * (1 + t),
				"Warrior",
				band[1]
			)
		end
	end
	-- G7-G9 (S84): rarity gain, two-handed parity, upgrades against income (S87 asserts them)
	for _, row in Balance.itemTargets() do
		table.insert(rows, row)
	end
	return rows
end

-- S87 (J1): rows of the global block that this session's levers do not close, each with the session that takes it
-- over (S88 A0, S89 A1, S90-S94 decide it: remove the entry = assert, or keep it with their number). Keys: an `id`
-- (every row of the target), `id|label` (one row) or a prefix of `id|label` ending in `*`. balance.spec asserts every
-- other row without `report`, that each key matches a row and that each session is above S87. The numbers in `why`
-- are the S87 values.
-- S92: G13.band 20-45 removed (14.9 h after the Dark Forest quests: asserted again)
Balance.GLOBAL_REPORT_ONLY = {
	-- S92: poza zasięgiem dźwigni S92: the S84 boss situation at 20 is Morvane moved to level 20 (Balance.bossFightAt,
	-- regionAt(20) = the Dark Forest); its basic attack 1.1 -> 0.42 (S92 C2: 7-12 % of a level 45 Mage) makes the
	-- shield of the one-handed set worth less on that boss (boss 0.920 -> 0.947), the holy staff's mix 1.033 -> 1.040;
	-- the owner decides (S93 proposal: Grimrok as the boss of the situation at 20)
	["G8|Cleric holystaff common +0 L20: z cechami"] = {
		session = "S92",
		why = "poza zasięgiem dźwigni S92: 1.040 > 1.035 (Morvane at 20 in the S84 boss situation, atkMul 0.42 for the 7-12 % basic hit)",
	},
} :: { [string]: { session: string, why: string } }
do
	local R = Balance.GLOBAL_REPORT_ONLY
	local function add(key: string, session: string, why: string)
		assert(R[key] == nil, `GLOBAL_REPORT_ONLY: duplicate {key}`)
		R[key] = { session = session, why = why }
	end
	-- S134g: poza zasięgiem dźwigni S134g (G8 bands unchanged, docs/sessions S134g E3): a rolled two-hander's regular
	-- lines count x Rarities.twoHandedBonusMul (2.7), so the lower Legendary / Mythic rangeMul (1.1 -> 1.05, 1.2 -> 1.1)
	-- and the end of the legendary lines take more from the two-handed set than from weapon + off-hand; the lever is
	-- twoHandedBonusMul per rarity (S87 C2), the owner decides
	local twoHandedWhy = "poza zasięgiem dźwigni S134g: the two-hander's lines (x2.7) lose more of the lower Legendary / "
		.. "Mythic rangeMul than weapon + off-hand (lever: twoHandedBonusMul per rarity, S87 C2)"
	for _, label in
		{
			"Warrior sword2h legendary +0 L20: z cechami",
			"Warrior sword2h legendary +9 L20: z cechami",
			"Warrior sword2h legendary +9 L45: z cechami",
			"Warrior sword2h mythic +0 L45: z cechami",
			"Warrior sword2h mythic +9 L45: z cechami",
			"Warrior sword2h legendary +0 L70: z cechami",
			"Warrior sword2h mythic +0 L70: z cechami",
			"Warrior sword2h legendary +0 L100: z cechami",
			"Warrior sword2h mythic +0 L100: z cechami",
			"Warrior spear2h legendary +0 L20: z cechami",
			"Warrior spear2h mythic +9 L20: bez cech",
			"Mage runestaff mythic +0 L20: bez cech",
		}
	do
		add(`G8|{label}`, "S134g", twoHandedWhy)
	end
	-- G7 (D1): the Hunter's Heroic set "z cechami" (band 15-25 %). S88 (H4): out of reach of the S88 levers: the new
	-- lines are cut to the D1 floor and the bow's traits grow with rarity; an owner decision (a Hunter exception like
	-- the Legendary <= 43 %)
	for L = 25, 100, 5 do
		add(
			`G7|Hunter {L}: heroic (z cechami)`,
			"S88",
			"poza zasięgiem dźwigni S88: Hunter Heroic 0.257-0.273 with traits after the D1 line cuts (owner: exception)"
		)
	end
	-- G9 (D3): at 25 +1..+9 protected 10.7 levels of income (band 12-25, S92's band). S91: at 20 poza zasięgiem
	-- dźwigni S91: the upgrade gold (Config.Upgrade, global) against the income of level 20 (quests and kinds of the
	-- band 20-45, S92); the 1-20 quests do not count at 20
	for _, c in Balance.CLASSES do
		add(
			`G9.up3|{c} 20: +1…+3 broni / dochód poziomu`,
			"S91",
			"poza zasięgiem dźwigni S91: 0.442 < 0.45 (Config.Upgrade global, income of 20 from the band 20-45)"
		)
		add(
			`G9.up9|{c} 20: +1…+9 z ochroną (poziomy dochodu)`,
			"S91",
			"poza zasięgiem dźwigni S91: 10.43 < 12 (Config.Upgrade global, income of 20 from the band 20-45)"
		)
		-- S92: poza zasięgiem dźwigni S92: the upgrade gold is global (Config.Upgrade, G9 S87); for the owner
		add(
			`G9.up9|{c} 25: +1…+9 z ochroną (poziomy dochodu)`,
			"S92",
			"poza zasięgiem dźwigni S92: 11.36 < 12 at 25 (Config.Upgrade global, an owner decision)"
		)
		-- S103: the income of 40 counts the kills of the window model (Balance.levelIncome) and the gold of the nine new
		-- story quests of the band (gold(level), FABULA §2.3); the upgrade gold is global (Config.Upgrade)
		add(
			`G9.up9|{c} 40: +1…+9 z ochroną (poziomy dochodu)`,
			"S103",
			"poza zasięgiem dźwigni S103: 11.06 < 12 at 40 (11.91 with the window kills before S103; the gold of the new story quests of 20-44; Config.Upgrade global, an owner decision)"
		)
	end
	-- S88 (E4): T-SK5 at 30 with Anointment 5 % (8 before; band 0.04-0.06 in `dungeon`): the heal anchors 21-44.
	-- S92: asserted again (Heal's rank 6 knot and the heal anchor 25: 0.269 at 30, 0.254 at 25)
	-- G10 (G2, G3): T-SK5 at 20 / 25 (the heal curve is 1 at 20; 21-44 are S92's anchors). S90: T-SK4 of
	-- destroyerExp and arcanistBoss asserted (path costs, bands 2.0-2.8 / 2.0-2.4 of SkillModel.TSK4_BANDS)
	-- S91: T-SK5 at 20 poza zasięgiem dźwigni S91: Heal's ranks <= 20 can rise at most 1-4 % under the pinned rank 6,
	-- the heal curve is 1 at 20, Blessed Hands (row 1) is global (T-SK5 of 45-100 in the S87 band)
	add(
		"G10|T-SK5 Cleric healer.dungeon na guardian.defender 20",
		"S91",
		"poza zasięgiem dźwigni S91: 0.221 < 0.25 (Heal ranks <= 20 under the pinned rank 6, heal curve 1 at 20)"
	)
	-- G8 (D2): "bez cech" rows out of 0.97-1.035 with twoHandedBonusMul 2.7 / 6.6 % per level (the most rows, Legendary
	-- and Mythic +0 at 45-100 first): legendary and mythic lines get no multiplier. S88 (H4): Data/Rarities is not an
	-- S88 lever; the Legendary rows at 20 go to the 1-20 session
	for _, label in
		{
			"Warrior sword2h legendary +0 L20",
			"Warrior spear2h legendary +0 L20",
			"Mage staff legendary +0 L20",
			"Mage runestaff legendary +0 L20",
		}
	do
		-- S91: poza zasięgiem dźwigni S91 (items are not an S91 lever: Data/Rarities, S87 / S88)
		add(
			`G8|{label}: bez cech`,
			"S91",
			"poza zasięgiem dźwigni S91: 1.036-1.039 at 20 (Legendary lines x2.7, Data/Rarities; items are not an S91 lever)"
		)
	end
	for _, label in
		{
			"Warrior axe2h mythic +0 L20",
			"Warrior axe2h mythic +0 L45",
			"Warrior axe2h mythic +9 L45",
			"Warrior axe2h mythic +0 L70",
			"Warrior axe2h mythic +9 L70",
			"Warrior axe2h mythic +0 L100",
			"Warrior axe2h mythic +9 L100",
			"Mage staff mythic +9 L100",
			"Mage runestaff mythic +9 L100",
		}
	do
		add(
			`G8|{label}: bez cech`,
			"S88",
			"poza zasięgiem dźwigni S88: axe Mythic 0.953-0.969 (L20 since the class-filtered pools), staves Mythic +9 0.966-0.970 (mythic lines without x2.7, Data/Rarities)"
		)
	end
	-- G8 "z cechami": the missing second trait of a two-handed weapon (0.87-0.98). S88 (E6, H4): every row but the ones
	-- in band on the S88 data stays in the report: the Berserker's traits stay in 0.04-0.06 and within 5 % of each other
	-- (C9), the staves are measured on the skill model (Balance.TYPE_SETS; the S84 convention counts Elemental Spark of
	-- the default wand + orb with basicShare 0.4, measured 0.14-0.27), the Holy Staff on the Healer's sets
	local inBand: { [string]: boolean } = {}
	for _, label in
		{
			"Warrior sword2h legendary +0 L20",
			"Warrior sword2h legendary +9 L20",
			"Warrior sword2h mythic +0 L20",
			"Warrior sword2h mythic +9 L20",
			"Warrior sword2h mythic +0 L45",
			"Warrior sword2h mythic +0 L70",
			"Warrior sword2h mythic +0 L100",
			"Warrior sword2h legendary +9 L45",
			"Warrior sword2h mythic +9 L45",
			"Warrior sword2h legendary +0 L70",
			"Warrior sword2h legendary +9 L70",
			"Warrior sword2h mythic +9 L70",
			"Warrior sword2h legendary +0 L100",
			"Warrior sword2h legendary +9 L100",
			"Warrior sword2h mythic +9 L100",
			"Warrior spear2h heroic +9 L20",
			"Warrior spear2h legendary +0 L20",
			"Warrior spear2h legendary +9 L20",
			"Warrior spear2h heroic +9 L70",
			"Cleric holystaff common +0 L20",
		}
	do
		inBand[label] = true
	end
	for _, pair in Balance.G8_PAIRS do
		for _, L in { 20, 45, 70, 100 } do
			for rarity = Rarities.COMMON, Rarities.MYTHIC do
				for _, up in { 0, 9 } do
					local label = `{pair.classId} {pair.weapon} {Rarities.get(rarity).key} +{up} L{L}`
					if not inBand[label] then
						add(
							`G8|{label}: z cechami`,
							"S88",
							"poza zasięgiem dźwigni S88: one trait against two (Berserker 0.90-0.97, staves 0.85-0.96, Holy Staff 1.15-3.66 with Saving Blow solo); owner: an E6 exception for the Warrior"
						)
					end
				end
			end
		end
	end
	-- S146 (DESIGN-18 §13, session rule 5): the Warrior's and the Cleric's rows of S137-S145 that the S146 levers do not
	-- close (the rest of their entries is asserted again; docs/SESJE.md S146 lists them). Never a row of 1-20.
	-- The Warrior's guards: T-SK1 / T-SK2 against the build's own L20 grow past the D1 limits since the pools (S143:
	-- seven skills of the pool at 20, the area skills and the cries from 26-33, the Standard-Bearer's and the Guardian's
	-- cries and banner in the 8 s burst), as the other classes' guards of S93 / S94; R1 is asserted in the S146 block
	-- (the Defender at 45 / 100, Fury 45-100)
	local riseWhy = "poza zasięgiem dźwigni S146: T-SK1 / T-SK2 Wojownika rosną ponad limit D1 względem L20 przez pule "
		.. "(S143); R1 asertuje blok S146"
	for _, key in
		{
			"R.ashen.guard.tsk1.Warrior.base.55",
			"R.ashen.guard.tsk1.Warrior.base.60",
			"R.ashen.guard.tsk1.Warrior.base.65",
			"R.ashen.guard.tsk1.Warrior.base.loadout.50",
			"R.ashen.guard.tsk1.Warrior.guardian.defender.55",
			"R.ashen.guard.tsk1.Warrior.guardian.defender.60",
			"R.ashen.guard.tsk1.Warrior.guardian.defender.65",
			"R.ashen.guard.tsk1.Warrior.guardian.defender.69",
			"R.ashen.guard.tsk1.Warrior.guardian.defender.70",
			"R.ashen.guard.tsk1.Warrior.guardian.loner.69",
			"R.ashen.guard.tsk1.Warrior.guardian.loner.70",
			"R.ashen.guard.tsk1.Warrior.standard.warden.50",
			"R.ashen.guard.tsk1.Warrior.standard.warden.55",
			"R.ashen.guard.tsk1.Warrior.standard.warden.60",
			"R.ashen.guard.tsk1.Warrior.standard.warden.65",
			"R.ashen.guard.tsk1.Warrior.standard.warden.69",
			"R.ashen.guard.tsk2.Warrior.base.55",
			"R.ashen.guard.tsk2.Warrior.base.60",
			"R.ashen.guard.tsk2.Warrior.base.65",
			"R.ashen.guard.tsk2.Warrior.base.loadout.55",
			"R.ashen.guard.tsk2.Warrior.base.loadout.60",
			"R.ashen.guard.tsk2.Warrior.base.loadout.65",
			"R.ashen.guard.tsk2.Warrior.berserker.butcher.60",
			"R.ashen.guard.tsk2.Warrior.berserker.butcher.65",
			"R.ashen.guard.tsk2.Warrior.berserker.butcher.69",
			"R.ashen.guard.tsk2.Warrior.guardian.defender.60",
			"R.ashen.guard.tsk2.Warrior.guardian.defender.65",
			"R.ashen.guard.tsk2.Warrior.guardian.defender.69",
			"R.ashen.guard.tsk2.Warrior.guardian.defender.70",
			"R.ashen.guard.tsk2.Warrior.guardian.loner.60",
			"R.ashen.guard.tsk2.Warrior.guardian.loner.65",
			"R.ashen.guard.tsk2.Warrior.guardian.loner.69",
			"R.ashen.guard.tsk2.Warrior.guardian.loner.70",
			"R.ashen.guard.tsk2.Warrior.standard.commander.50",
			"R.ashen.guard.tsk2.Warrior.standard.commander.55",
			"R.ashen.guard.tsk2.Warrior.standard.commander.60",
			"R.ashen.guard.tsk2.Warrior.standard.commander.65",
			"R.ashen.guard.tsk2.Warrior.standard.warden.50",
			"R.ashen.guard.tsk2.Warrior.standard.warden.55",
			"R.ashen.guard.tsk2.Warrior.standard.warden.60",
			"R.ashen.guard.tsk2.Warrior.standard.warden.65",
			"R.ashen.guard.tsk2.Warrior.standard.warden.69",
			"R.frostpeak.guard.tsk1.Warrior.base.75",
			"R.frostpeak.guard.tsk1.Warrior.base.loadout.75",
			"R.frostpeak.guard.tsk1.Warrior.guardian.defender.85",
			"R.frostpeak.guard.tsk1.Warrior.guardian.loner.75",
			"R.frostpeak.guard.tsk1.Warrior.guardian.loner.80",
			"R.frostpeak.guard.tsk1.Warrior.guardian.loner.85",
			"R.frostpeak.guard.tsk2.Warrior.base.75",
			"R.frostpeak.guard.tsk2.Warrior.base.80",
			"R.frostpeak.guard.tsk2.Warrior.base.loadout.100",
			"R.frostpeak.guard.tsk2.Warrior.base.loadout.75",
			"R.frostpeak.guard.tsk2.Warrior.base.loadout.80",
			"R.frostpeak.guard.tsk2.Warrior.base.loadout.85",
			"R.frostpeak.guard.tsk2.Warrior.base.loadout.90",
			"R.frostpeak.guard.tsk2.Warrior.base.loadout.95",
			"R.frostpeak.guard.tsk2.Warrior.base.loadout.99",
			"R.frostpeak.guard.tsk2.Warrior.guardian.defender.75",
			"R.frostpeak.guard.tsk2.Warrior.guardian.defender.80",
			"R.frostpeak.guard.tsk2.Warrior.guardian.defender.85",
			"R.frostpeak.guard.tsk2.Warrior.guardian.defender.90",
			"R.frostpeak.guard.tsk2.Warrior.guardian.defender.95",
			"R.frostpeak.guard.tsk2.Warrior.guardian.defender.99",
			"R.frostpeak.guard.tsk2.Warrior.guardian.defender.100",
			"R.frostpeak.guard.tsk2.Warrior.guardian.loner.75",
			"R.frostpeak.guard.tsk2.Warrior.guardian.loner.80",
			"R.frostpeak.guard.tsk2.Warrior.guardian.loner.85",
			"R.frostpeak.guard.tsk2.Warrior.guardian.loner.90",
			"R.frostpeak.guard.tsk2.Warrior.guardian.loner.95",
			"R.frostpeak.guard.tsk2.Warrior.guardian.loner.99",
			"R.frostpeak.guard.tsk2.Warrior.guardian.loner.100",
		}
	do
		add(key, "S146", riseWhy)
	end
	-- the two-handed weapon traits (S88 T1 / T2) on the Berserker's new rotation (the bar of 8, Fury from Rage): 1-3 %
	-- past the band; the lever is the trait values (Data/ItemTraits, S88)
	local traitWhy = "poza zasięgiem dźwigni S146: cechy broni dwuręcznej (Data/ItemTraits, S88) na nowej rotacji "
		.. "Berserkera (pasek 8, Furia z pasywki); dla właściciela"
	for _, key in
		{
			"T1|sundering · berserker.fury@hammer2h · L45",
			"T1|sundering · berserker.fury@hammer2h · L70",
			"T1|sundering · berserker.fury@hammer2h · L100",
			"T1|runThrough · berserker.fury@spear2h · L70",
			"T2|berserker · L70",
		}
	do
		add(key, "S146", traitWhy)
	end
	-- the Berserker against the class base: since S143 the base plays the same two-handed pool (Rage, Execute, Rend,
	-- Sunder), so the Berserker leads only by its direction's nodes; stronger nodes move "Furia", the damage reference
	-- of every class (its R1 at 100 2.60 against 2.61)
	for _, L in { 45, 70, 100 } do
		add(
			`path.berserker.fury.L{L}.berserker.base`,
			"S146",
			"poza zasięgiem dźwigni S146: podstawa gra tę samą pulę dwuręczną (S143), Berserker prowadzi tylko węzłami; "
				.. "mocniejsze węzły przesuwają Furię, odniesienie wszystkich klas (R1 na 100 2,60 przy 2,61)"
		)
	end
	-- Fortune plays the Mace and Flail pool (DESIGN-18 §6.4): the light pool's heal passives (Grace, Guiding Light) and
	-- the Healer's nodes are not his
	for _, L in { 70, 100 } do
		add(
			`path.fortune.plunder.L{L}.fortune.healLess`,
			"S146",
			"poza zasięgiem dźwigni S146: Fortuna gra pulę buzdygana, pasywki leczenia berła i węzły Uzdrowiciela nie są jej; dla właściciela"
		)
	end
	-- the lone Healer with the holy staff plays the light pool (three skills with damage: Light Ray, Radiance, Blinding
	-- Light); a Healer grinds with a mace (the hammer pool), and the 1-20 reference build is frozen
	add(
		"path.healer.solo.L100.cleric.solo",
		"S146",
		"poza zasięgiem dźwigni S146: kostur to pula berła (3 umiejętności z obrażeniami), solo expi się buzdyganem; build 1-20 zamrożony"
	)
	-- S147 (DESIGN-18 §13, session rule 5): the Hunter's and the Mage's rows of S137-S145 that the S147 levers do not
	-- close (the rest of their entries is asserted again; docs/SESJE.md S147 lists them). Never a row of 1-20 except
	-- the frozen Fire Bolt 5A.
	-- The guards: T-SK1 / T-SK2 / T-SK3 against the build's own L20 grow past the D1 limits since the pools (the element
	-- variants and both Hunter pools tuned at 20 to the S91 band, the pools' S2 at 15, A2 at 26, K2 at 33, S3 at 40, U at
	-- 60), as the Warrior's of S146; R1 is printed and R9 / T-SK3 asserted in the S147 block
	local guardWhy = "poza zasięgiem dźwigni S147: T-SK1 / T-SK2 / T-SK3 Łowcy i Maga rosną ponad limit D1 względem L20 "
		.. "przez pule (S140–S144); R9 i T-SK3 asertuje blok S147"
	-- T-SK4 of the means of three elements (the S90-S94 Mage builds: a mixed rotation, each element casts only its pool
	-- since S142, so they cast 4-5 spells): the S147 block asserts T-SK4 of the element variants on 45-100
	local tsk4Why = "S147: T-SK4 średniej trzech żywiołów (rotacja sprzed pul, po S142 żywioł rzuca tylko swoją pulę) "
		.. "poniżej pasma po krzywej manaCost.Mage S147; T-SK4 wariantów żywiołów na 45–100 asertuje blok S147 "
		.. "(wiersze poza zasięgiem z powodem zasady 5 w Balance.S147_REPORT; pasmo ROZWOJ 12.7 od 45.)"
	-- the weapon traits of S88 measured on the builds before the pools (the means of three elements, the Trapper with a
	-- bow, the Scout's shortbow); their values live in Data/ItemTraits, outside this session's levers
	local traitWhy = "poza zasięgiem dźwigni S147: cechy broni (S88) mierzone na buildach sprzed pul (średnia żywiołów, "
		.. "Traper z łukiem); wartości w Data/ItemTraits, dla właściciela"
	-- 1-20 frozen: Fire Bolt's 5A (rank 5, level 17) moves the Destroyer's L20 anchor (S91)
	local frozenWhy =
		"1–20 zamrożone: przełom 5A Ognistego Pocisku (ranga 5, poziom 17) rusza kotwicę L20 Niszczyciela (S91)"
	-- the Scout plays the Bow pool, without the Crossbow's traps (Venom Snare, Snare Field) that make the Trapper the
	-- fastest area build
	local scoutWhy = "poza zasięgiem dźwigni S147: Zwiadowca gra pulę łuku bez pułapek kuszy, tempo solo względem "
		.. "Trapera 1,6–2,2; dla właściciela"
	local r6Why =
		"właściciel (E3, S89): rzędy 4–11 Zwiadowcy to wsparcie (średnia części bliska 0, iloraz bez znaczenia)"
	-- the Trapper with a bow: since S144 the Trapper is the Crossbow pool (the bow is the other pool's weapon)
	local bowWhy = "S147: Traper z łukiem gra pulę łuku (od S144 Traper to pula kuszy); R5 puli asertuje blok S147"
	-- targets against the class base of S85 (the base plays both pools / three elements in one rotation)
	local baseWhy = "S147: cel względem bazy klasy sprzed pul (baza gra obie pule albo trzy żywioły w jednej rotacji); "
		.. "tożsamość pul asertuje blok S147 (R9, R7, R5)"
	-- S147: guard (248 rows)
	for _, key in
		{
			"R.ashen.guard.tsk1.Hunter.base.50",
			"R.ashen.guard.tsk1.Hunter.base.55",
			"R.ashen.guard.tsk1.Hunter.base.60",
			"R.ashen.guard.tsk1.Hunter.base.65",
			"R.ashen.guard.tsk1.Hunter.base.69",
			"R.ashen.guard.tsk1.Hunter.base.70",
			"R.ashen.guard.tsk1.Hunter.marksman.eliteHunter.55",
			"R.ashen.guard.tsk1.Hunter.marksman.eliteHunter.70",
			"R.ashen.guard.tsk1.Hunter.marksman.kingslayer.65",
			"R.ashen.guard.tsk1.Hunter.marksman.kingslayer.70",
			"R.ashen.guard.tsk1.Hunter.scout.partyHunter.50",
			"R.ashen.guard.tsk1.Hunter.scout.partyHunter.55",
			"R.ashen.guard.tsk1.Hunter.scout.partyHunter.60",
			"R.ashen.guard.tsk1.Hunter.scout.partyHunter.65",
			"R.ashen.guard.tsk1.Hunter.scout.partyHunter.69",
			"R.ashen.guard.tsk1.Hunter.scout.partyHunter.70",
			"R.ashen.guard.tsk1.Hunter.scout.tracker.50",
			"R.ashen.guard.tsk1.Hunter.scout.tracker.55",
			"R.ashen.guard.tsk1.Hunter.scout.tracker.60",
			"R.ashen.guard.tsk1.Hunter.scout.tracker.65",
			"R.ashen.guard.tsk1.Hunter.scout.tracker.69",
			"R.ashen.guard.tsk1.Hunter.scout.tracker.70",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistFire.50",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistFire.55",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistFire.60",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistFire.65",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistFire.69",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistFire.70",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistIce.50",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistIce.55",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistIce.60",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistIce.65",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistIce.69",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistIce.70",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistLightning.55",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistLightning.60",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistLightning.65",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistLightning.69",
			"R.ashen.guard.tsk1.Mage.arcanist.arcanistLightning.70",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerFire.50",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerFire.55",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerFire.60",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerFire.65",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerFire.69",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerFire.70",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerIce.50",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerIce.55",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerIce.60",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerIce.65",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerIce.69",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerIce.70",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerLightning.50",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerLightning.55",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerLightning.60",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerLightning.65",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerLightning.69",
			"R.ashen.guard.tsk1.Mage.destroyer.destroyerLightning.70",
			"R.ashen.guard.tsk2.Hunter.base.50",
			"R.ashen.guard.tsk2.Hunter.base.55",
			"R.ashen.guard.tsk2.Hunter.base.60",
			"R.ashen.guard.tsk2.Hunter.base.69",
			"R.ashen.guard.tsk2.Hunter.base.70",
			"R.ashen.guard.tsk2.Hunter.scout.partyHunter.50",
			"R.ashen.guard.tsk2.Hunter.scout.partyHunter.55",
			"R.ashen.guard.tsk2.Hunter.scout.partyHunter.60",
			"R.ashen.guard.tsk2.Hunter.scout.partyHunter.65",
			"R.ashen.guard.tsk2.Hunter.scout.partyHunter.69",
			"R.ashen.guard.tsk2.Hunter.scout.partyHunter.70",
			"R.ashen.guard.tsk2.Hunter.scout.tracker.55",
			"R.ashen.guard.tsk2.Hunter.scout.tracker.60",
			"R.ashen.guard.tsk2.Hunter.scout.tracker.65",
			"R.ashen.guard.tsk2.Hunter.scout.tracker.69",
			"R.ashen.guard.tsk2.Hunter.scout.tracker.70",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistFire.55",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistFire.60",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistFire.65",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistFire.69",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistFire.70",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistIce.50",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistIce.55",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistIce.60",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistIce.65",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistIce.69",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistIce.70",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistLightning.55",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistLightning.60",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistLightning.65",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistLightning.69",
			"R.ashen.guard.tsk2.Mage.arcanist.arcanistLightning.70",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerFire.50",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerFire.55",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerFire.60",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerFire.65",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerFire.69",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerFire.70",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerIce.55",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerIce.60",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerIce.65",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerIce.69",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerIce.70",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerLightning.50",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerLightning.55",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerLightning.60",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerLightning.65",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerLightning.69",
			"R.ashen.guard.tsk2.Mage.destroyer.destroyerLightning.70",
			"R.ashen.guard.tsk3.Hunter.trapper.poacher.69",
			"R.ashen.guard.tsk3.Hunter.trapper.poisoner.69",
			"R.duskwood.guard.tsk1.Hunter.base.35",
			"R.duskwood.guard.tsk1.Hunter.base.40",
			"R.duskwood.guard.tsk1.Hunter.marksman.eliteHunter.35",
			"R.duskwood.guard.tsk1.Hunter.marksman.eliteHunter.40",
			"R.duskwood.guard.tsk1.Hunter.marksman.kingslayer.35",
			"R.duskwood.guard.tsk1.Hunter.marksman.kingslayer.40",
			"R.duskwood.guard.tsk1.Mage.base.loadout.40",
			"R.duskwood.guard.tsk2.Hunter.base.30",
			"R.duskwood.guard.tsk2.Hunter.base.35",
			"R.duskwood.guard.tsk2.Hunter.base.40",
			"R.duskwood.guard.tsk2.Hunter.marksman.eliteHunter.30",
			"R.duskwood.guard.tsk2.Hunter.marksman.eliteHunter.35",
			"R.duskwood.guard.tsk2.Hunter.marksman.eliteHunter.40",
			"R.duskwood.guard.tsk2.Hunter.marksman.kingslayer.30",
			"R.duskwood.guard.tsk2.Hunter.marksman.kingslayer.35",
			"R.duskwood.guard.tsk2.Mage.destroyer.destroyerFire.40",
			"R.duskwood.guard.tsk2.Mage.destroyer.destroyerFire.44",
			"R.frostpeak.guard.tsk1.Hunter.base.75",
			"R.frostpeak.guard.tsk1.Hunter.base.80",
			"R.frostpeak.guard.tsk1.Hunter.base.85",
			"R.frostpeak.guard.tsk1.Hunter.base.90",
			"R.frostpeak.guard.tsk1.Hunter.base.95",
			"R.frostpeak.guard.tsk1.Hunter.marksman.eliteHunter.80",
			"R.frostpeak.guard.tsk1.Hunter.marksman.eliteHunter.85",
			"R.frostpeak.guard.tsk1.Hunter.marksman.eliteHunter.90",
			"R.frostpeak.guard.tsk1.Hunter.marksman.eliteHunter.95",
			"R.frostpeak.guard.tsk1.Hunter.marksman.eliteHunter.99",
			"R.frostpeak.guard.tsk1.Hunter.marksman.kingslayer.80",
			"R.frostpeak.guard.tsk1.Hunter.marksman.kingslayer.85",
			"R.frostpeak.guard.tsk1.Hunter.marksman.kingslayer.90",
			"R.frostpeak.guard.tsk1.Hunter.marksman.kingslayer.99",
			"R.frostpeak.guard.tsk1.Hunter.scout.partyHunter.75",
			"R.frostpeak.guard.tsk1.Hunter.scout.partyHunter.80",
			"R.frostpeak.guard.tsk1.Hunter.scout.tracker.75",
			"R.frostpeak.guard.tsk1.Hunter.scout.tracker.80",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poacher.100",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poacher.80",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poacher.85",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poacher.90",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poacher.95",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poacher.99",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poisoner.100",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poisoner.80",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poisoner.85",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poisoner.90",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poisoner.95",
			"R.frostpeak.guard.tsk1.Hunter.trapper.poisoner.99",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistFire.100",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistFire.75",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistFire.80",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistFire.85",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistFire.90",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistFire.95",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistFire.99",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistIce.100",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistIce.75",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistIce.80",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistIce.85",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistIce.90",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistIce.95",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistIce.99",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistLightning.100",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistLightning.75",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistLightning.80",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistLightning.85",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistLightning.90",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistLightning.95",
			"R.frostpeak.guard.tsk1.Mage.arcanist.arcanistLightning.99",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerFire.75",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerFire.80",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerFire.85",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerIce.75",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerIce.80",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerIce.85",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerLightning.75",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerLightning.80",
			"R.frostpeak.guard.tsk1.Mage.destroyer.destroyerLightning.85",
			"R.frostpeak.guard.tsk2.Hunter.base.75",
			"R.frostpeak.guard.tsk2.Hunter.base.80",
			"R.frostpeak.guard.tsk2.Hunter.base.90",
			"R.frostpeak.guard.tsk2.Hunter.marksman.eliteHunter.80",
			"R.frostpeak.guard.tsk2.Hunter.marksman.eliteHunter.85",
			"R.frostpeak.guard.tsk2.Hunter.marksman.eliteHunter.90",
			"R.frostpeak.guard.tsk2.Hunter.marksman.eliteHunter.95",
			"R.frostpeak.guard.tsk2.Hunter.marksman.eliteHunter.99",
			"R.frostpeak.guard.tsk2.Hunter.marksman.kingslayer.80",
			"R.frostpeak.guard.tsk2.Hunter.marksman.kingslayer.85",
			"R.frostpeak.guard.tsk2.Hunter.marksman.kingslayer.90",
			"R.frostpeak.guard.tsk2.Hunter.scout.partyHunter.75",
			"R.frostpeak.guard.tsk2.Hunter.scout.partyHunter.80",
			"R.frostpeak.guard.tsk2.Hunter.scout.partyHunter.85",
			"R.frostpeak.guard.tsk2.Hunter.scout.partyHunter.90",
			"R.frostpeak.guard.tsk2.Hunter.scout.partyHunter.95",
			"R.frostpeak.guard.tsk2.Hunter.scout.tracker.100",
			"R.frostpeak.guard.tsk2.Hunter.scout.tracker.75",
			"R.frostpeak.guard.tsk2.Hunter.scout.tracker.80",
			"R.frostpeak.guard.tsk2.Hunter.scout.tracker.85",
			"R.frostpeak.guard.tsk2.Hunter.scout.tracker.90",
			"R.frostpeak.guard.tsk2.Hunter.scout.tracker.95",
			"R.frostpeak.guard.tsk2.Hunter.scout.tracker.99",
			"R.frostpeak.guard.tsk2.Hunter.trapper.poacher.80",
			"R.frostpeak.guard.tsk2.Hunter.trapper.poacher.90",
			"R.frostpeak.guard.tsk2.Hunter.trapper.poacher.95",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistFire.100",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistFire.75",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistFire.80",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistFire.85",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistFire.90",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistFire.95",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistFire.99",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistIce.100",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistIce.75",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistIce.80",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistIce.85",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistIce.90",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistIce.95",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistIce.99",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistLightning.100",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistLightning.75",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistLightning.80",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistLightning.85",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistLightning.95",
			"R.frostpeak.guard.tsk2.Mage.arcanist.arcanistLightning.99",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerFire.100",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerFire.75",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerFire.80",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerFire.85",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerFire.90",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerFire.95",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerFire.99",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerIce.75",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerIce.80",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerIce.85",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerIce.90",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerIce.95",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerLightning.100",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerLightning.75",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerLightning.80",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerLightning.85",
			"R.frostpeak.guard.tsk2.Mage.destroyer.destroyerLightning.99",
		}
	do
		add(key, "S147", guardWhy)
	end
	-- S147: tsk4 (87 rows)
	for _, key in
		{
			"G10|T-SK4 Mage arcanist.arcanistBoss 100",
			"G10|T-SK4 Mage arcanist.arcanistBoss 45",
			"G10|T-SK4 Mage arcanist.arcanistBoss 50",
			"G10|T-SK4 Mage arcanist.arcanistBoss 55",
			"G10|T-SK4 Mage arcanist.arcanistBoss 60",
			"G10|T-SK4 Mage arcanist.arcanistBoss 65",
			"G10|T-SK4 Mage arcanist.arcanistBoss 70",
			"G10|T-SK4 Mage arcanist.arcanistBoss 75",
			"G10|T-SK4 Mage arcanist.arcanistBoss 80",
			"G10|T-SK4 Mage arcanist.arcanistBoss 85",
			"G10|T-SK4 Mage arcanist.arcanistBoss 90",
			"G10|T-SK4 Mage arcanist.arcanistBoss 95",
			"G10|T-SK4 Mage destroyer.destroyerExp 100",
			"G10|T-SK4 Mage destroyer.destroyerExp 45",
			"G10|T-SK4 Mage destroyer.destroyerExp 50",
			"G10|T-SK4 Mage destroyer.destroyerExp 55",
			"G10|T-SK4 Mage destroyer.destroyerExp 60",
			"G10|T-SK4 Mage destroyer.destroyerExp 70",
			"G10|T-SK4 Mage destroyer.destroyerExp 75",
			"G10|T-SK4 Mage destroyer.destroyerExp 80",
			"G10|T-SK4 Mage destroyer.destroyerExp 85",
			"G10|T-SK4 Mage destroyer.destroyerExp 90",
			"G10|T-SK4 Mage destroyer.destroyerExp 95",
			"R.ashen.tsk4.arcanist.arcanistBoss.50",
			"R.ashen.tsk4.arcanist.arcanistBoss.55",
			"R.ashen.tsk4.arcanist.arcanistBoss.60",
			"R.ashen.tsk4.arcanist.arcanistBoss.65",
			"R.ashen.tsk4.arcanist.arcanistBoss.69",
			"R.ashen.tsk4.arcanist.arcanistBoss.70",
			"R.ashen.tsk4.arcanist.arcanistOverload.50",
			"R.ashen.tsk4.arcanist.arcanistOverload.55",
			"R.ashen.tsk4.arcanist.arcanistOverload.60",
			"R.ashen.tsk4.arcanist.arcanistOverload.65",
			"R.ashen.tsk4.arcanist.arcanistOverload.69",
			"R.ashen.tsk4.arcanist.arcanistOverload.70",
			"R.ashen.tsk4.destroyer.destroyerBoss.60",
			"R.ashen.tsk4.destroyer.destroyerExp.50",
			"R.ashen.tsk4.destroyer.destroyerExp.55",
			"R.ashen.tsk4.destroyer.destroyerExp.60",
			"R.ashen.tsk4.destroyer.destroyerExp.69",
			"R.ashen.tsk4.destroyer.destroyerExp.70",
			"R.duskwood.tsk4.arcanist.arcanistBoss.25",
			"R.duskwood.tsk4.arcanist.arcanistBoss.30",
			"R.duskwood.tsk4.arcanist.arcanistBoss.35",
			"R.duskwood.tsk4.arcanist.arcanistBoss.40",
			"R.duskwood.tsk4.arcanist.arcanistBoss.44",
			"R.duskwood.tsk4.destroyer.destroyerExp.25",
			"R.duskwood.tsk4.destroyer.destroyerExp.30",
			"R.duskwood.tsk4.destroyer.destroyerExp.35",
			"R.duskwood.tsk4.destroyer.destroyerExp.40",
			"R.frostpeak.tsk4.arcanist.arcanistBoss.100",
			"R.frostpeak.tsk4.arcanist.arcanistBoss.75",
			"R.frostpeak.tsk4.arcanist.arcanistBoss.80",
			"R.frostpeak.tsk4.arcanist.arcanistBoss.85",
			"R.frostpeak.tsk4.arcanist.arcanistBoss.90",
			"R.frostpeak.tsk4.arcanist.arcanistBoss.95",
			"R.frostpeak.tsk4.arcanist.arcanistBoss.99",
			"R.frostpeak.tsk4.arcanist.arcanistOverload.100",
			"R.frostpeak.tsk4.arcanist.arcanistOverload.75",
			"R.frostpeak.tsk4.arcanist.arcanistOverload.80",
			"R.frostpeak.tsk4.arcanist.arcanistOverload.85",
			"R.frostpeak.tsk4.arcanist.arcanistOverload.90",
			"R.frostpeak.tsk4.arcanist.arcanistOverload.95",
			"R.frostpeak.tsk4.arcanist.arcanistOverload.99",
			"R.frostpeak.tsk4.destroyer.destroyerBoss.100",
			"R.frostpeak.tsk4.destroyer.destroyerBoss.80",
			"R.frostpeak.tsk4.destroyer.destroyerBoss.85",
			"R.frostpeak.tsk4.destroyer.destroyerBoss.90",
			"R.frostpeak.tsk4.destroyer.destroyerBoss.95",
			"R.frostpeak.tsk4.destroyer.destroyerBoss.99",
			"R.frostpeak.tsk4.destroyer.destroyerExp.100",
			"R.frostpeak.tsk4.destroyer.destroyerExp.75",
			"R.frostpeak.tsk4.destroyer.destroyerExp.80",
			"R.frostpeak.tsk4.destroyer.destroyerExp.85",
			"R.frostpeak.tsk4.destroyer.destroyerExp.90",
			"R.frostpeak.tsk4.destroyer.destroyerExp.95",
			"R.frostpeak.tsk4.destroyer.destroyerExp.99",
			"path.arcanist.arcanistBoss.L100.mage.tsk4",
			"path.arcanist.arcanistBoss.L45.mage.tsk4",
			"path.arcanist.arcanistBoss.L70.mage.tsk4",
			"path.arcanist.arcanistOverload.L100.mage.tsk4|wariant: Przeciążenie",
			"path.arcanist.arcanistOverload.L45.mage.tsk4|wariant: Przeciążenie",
			"path.arcanist.arcanistOverload.L70.mage.tsk4|wariant: Przeciążenie",
			"path.destroyer.destroyerBoss.L100.mage.tsk4|wariant: Oszczędny Splot",
			"path.destroyer.destroyerExp.L100.mage.tsk4",
			"path.destroyer.destroyerExp.L45.mage.tsk4",
			"path.destroyer.destroyerExp.L70.mage.tsk4",
		}
	do
		add(key, "S147", tsk4Why)
	end
	-- S147: trait (14 rows)
	for _, key in
		{
			"T1|easyPrey · trapper.poacher@crossbow · L100",
			"T1|easyPrey · trapper.poacher@crossbow · L45",
			"T1|easyPrey · trapper.poacher@crossbow · L70",
			"T1|elementalMight fire · destroyer.destroyerExp@staff · L100",
			"T1|elementalMight fire · destroyer.destroyerExp@staff · L45",
			"T1|elementalMight fire · destroyer.destroyerExp@staff · L70",
			"T1|elementalMight lightning · destroyer.destroyerExp@staff · L45",
			"T1|elementalMight lightning · destroyer.destroyerExp@staff · L70",
			"T1|elementalSpark fire · arcanist.arcanistBoss@wand · L45",
			"T1|elementalSpark ice · arcanist.arcanistBoss@wand · L100",
			"T1|elementalSpark lightning · arcanist.arcanistBoss@wand · L100",
			"T1|fullDraw · scout.partyHunter@shortbow · L70",
			"T2|trapper · L100",
			"T2|trapper · L70",
		}
	do
		add(key, "S147", traitWhy)
	end
	-- S147: frozen (3 rows)
	for _, key in
		{
			"path.arcanist.arcanistBoss.L100.r4.firebolt.5|a",
			"path.arcanist.arcanistBoss.L45.r4.firebolt.5|a",
			"path.arcanist.arcanistBoss.L70.r4.firebolt.5|a",
		}
	do
		add(key, "S147", frozenWhy)
	end
	-- S147: scout (10 rows)
	for _, key in
		{
			"path.scout.partyHunter.L100.scout.solo|(a) grupa 8 s",
			"path.scout.partyHunter.L100.scout.solo|(b) 3 potwory, które oddają",
			"path.scout.partyHunter.L45.scout.solo|(b) 3 potwory, które oddają",
			"path.scout.partyHunter.L70.scout.solo|(a) grupa 8 s",
			"path.scout.partyHunter.L70.scout.solo|(b) 3 potwory, które oddają",
			"path.scout.partyHunter@shortbow+quiver.L100.scout.solo|(a) grupa 8 s",
			"path.scout.partyHunter@shortbow+quiver.L100.scout.solo|(b) 3 potwory, które oddają",
			"path.scout.partyHunter@shortbow+quiver.L45.scout.solo|(b) 3 potwory, które oddają",
			"path.scout.partyHunter@shortbow+quiver.L70.scout.solo|(a) grupa 8 s",
			"path.scout.partyHunter@shortbow+quiver.L70.scout.solo|(b) 3 potwory, które oddają",
		}
	do
		add(key, "S147", scoutWhy)
	end
	-- S147: r6 (2 rows)
	for _, key in
		{
			"path.scout.partyHunter.L100.r6.scout|najmocniejsza trzecia część / średnia",
			"path.scout.partyHunter.L100.r6.scout|najsłabsza trzecia część / średnia",
		}
	do
		add(key, "S147", r6Why)
	end
	-- S147: bow (8 rows)
	for _, key in
		{
			"path.trapper.poacher.L100.r5.trapper|Kusza, Łuk (obszar 3 cele 8 s)",
			"path.trapper.poacher.L45.r5.trapper|Kusza, Łuk (obszar 3 cele 8 s)",
			"path.trapper.poacher.L70.r5.trapper|Kusza, Łuk (obszar 3 cele 8 s)",
			"path.trapper.poacher@bow+quiver.L100.trapper.aoe",
			"path.trapper.poacher@bow+quiver.L100.trapper.single|bez R7",
			"path.trapper.poacher@bow+quiver.L45.trapper.aoe",
			"path.trapper.poacher@bow+quiver.L45.trapper.single|bez R7",
			"path.trapper.poacher@bow+quiver.L70.trapper.aoe",
		}
	do
		add(key, "S147", bowWhy)
	end
	-- S147: base (20 rows)
	for _, key in
		{
			"path.arcanist.arcanistBoss.L100.arcanist.single",
			"path.arcanist.arcanistBoss.L100.arcanist.vsDestroyer",
			"path.arcanist.arcanistBoss.L45.arcanist.single",
			"path.arcanist.arcanistBoss.L45.arcanist.vsDestroyer",
			"path.arcanist.arcanistBoss.L70.arcanist.single",
			"path.destroyer.destroyerBoss.L100.destroyer.single",
			"path.destroyer.destroyerExp.L45.destroyer.aoe",
			"path.destroyer.destroyerExp.L70.destroyer.aoe",
			"path.marksman.kingslayer.L100.marksman.base",
			"path.marksman.kingslayer.L100.r5a.hunter|Strzelec 1 cel / baza",
			"path.marksman.kingslayer.L45.marksman.base",
			"path.marksman.kingslayer.L45.r5a.hunter|Strzelec 1 cel / baza",
			"path.marksman.kingslayer.L70.r5a.hunter|Strzelec 1 cel / baza",
			"path.marksman.kingslayer@heavycrossbow+quiver.L100.marksman.base",
			"path.marksman.kingslayer@heavycrossbow+quiver.L45.marksman.base",
			"path.marksman.kingslayer@heavycrossbow+quiver.L70.marksman.base",
			"path.trapper.poacher.L100.r5a.hunter|Traper obszar 8 s / baza",
			"path.trapper.poacher.L45.r5a.hunter|Traper obszar 8 s / baza",
			"path.trapper.poacher.L70.r5a.hunter|Traper obszar 8 s / baza",
			"path.trapper.poacher.L70.trapper.single|bez R7",
		}
	do
		add(key, "S147", baseWhy)
	end
end

-- Whether a GLOBAL_REPORT_ONLY key matches `row` (an id, `id|label` or a prefix of it ending in `*`).
function Balance.reportKeyMatches(key: string, row: TargetRow): boolean
	local full = `{row.id}|{row.label}`
	if key == row.id or key == full then
		return true
	end
	return string.sub(key, -1) == "*" and string.sub(full, 1, #key - 1) == string.sub(key, 1, -2)
end

-- The GLOBAL_REPORT_ONLY entry of a row, or nil (S87).
function Balance.reportOnlyFor(row: TargetRow): { session: string, why: string }?
	local R = Balance.GLOBAL_REPORT_ONLY
	local hit = R[`{row.id}|{row.label}`] or R[row.id]
	if hit then
		return hit
	end
	for key, entry in R do
		if Balance.reportKeyMatches(key, row) then
			return entry
		end
	end
	return nil
end

-- Regions (S83): TUNED[mapId] = true once its region session asserted it (S91 Meadows 1-20 in full, S92-S94 the
-- rest); read by balance.spec ("Balance 20-100: regions") and the report. Starting thresholds of the balance plan;
-- region sessions may tune them with a line in DECYZJE.
-- S92: the Dark Forest tuned (20-45 and Morvane). S93: the Scorched Wastes (45-70 and Azgor)
-- S94 (L3): every region tuned; the gate Balance.TUNED removed, balance.spec asserts every region row without `report`
Balance.REGION_TARGETS = {
	-- S91: `classes` = W / Ł / M (the S32 Elite classes; the Cleric's Elites only printed)
	eliteSingle = {
		seconds = { 20, 36 },
		hp = { 0.55, 0.95 },
		shareInBand = 26 / 36,
		hpFloor = 0.45,
		hpCeil = 1.10,
		classes = { "Warrior", "Hunter", "Mage" },
	},
	eliteEncounter = { Warrior = 1.10, Mage = 1.25 }, -- (1 - q) * single + q * pair, q from caveElites
	-- solo at least, duo at most, trio within (the S32 reading: solo dies, two struggle, three win)
	elite2 = { solo = 1.80, duo = 1.50, trio = { 0.60, 1.00 } },
	kinds = { expPerSecond = { 0.85, 1.20 }, casterHpPerExp = 1.25 }, -- caster HP per EXP vs the region average
	bossCadence = 0.5,
	-- S84 (D5): Uniques for the class per hour of grinding, Heroics for the class per hour of cave Elites (profile K0,
	-- no Fortune; S92-S94 set dropFactor per region)
	d5 = { uniquePerHour = { 2, 4 }, heroicPerHour = { 0.5, 1.5 } },
}

-- Rows of one region (group = eliteSingle / eliteEncounter / elite2 / kinds / bossCadence). The Meadows use the S32
-- kind set (passive rabbit included) and the S32 band 0.85-1.20. S91 (B1): `withNodes` = only the cave rows with the
-- players with nodes (Balance.caveElites(mapId, true)), ids "R.<map>.nodes.*"; Elite rows of the classes in
-- eliteSingle.classes (W / Ł / M).
function Balance.targetsRegion(mapId: string, targets: any?, withNodes: boolean?): { TargetRow }
	local T = targets or Balance.REGION_TARGETS
	local rows: { TargetRow } = {}
	local prefix = if withNodes then `R.{mapId}.nodes` else `R.{mapId}`
	local classes = T.eliteSingle.classes
	local function add(
		group: string,
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		c: string?,
		L: number?
	)
		table.insert(rows, {
			id = `{prefix}.{id}`,
			group = group,
			label = label,
			value = value,
			low = low,
			high = high,
			classId = c,
			level = L,
		})
	end
	local single, inBand = 0, 0
	for _, cave in Balance.caveElites(mapId, withNodes) do
		for _, kind in cave.kinds do
			for _, f in kind.fights do
				if classes and not table.find(classes, f.classId) then
					continue
				end
				local key = `{cave.id}.{kind.kind}.{f.level}.{f.classId}{if f.variant then "@" .. f.variant else ""}`
				local s, hp = T.eliteSingle.seconds, T.eliteSingle.hp
				single += 1
				if
					f.single.seconds >= s[1]
					and f.single.seconds <= s[2]
					and f.single.hpLost >= hp[1]
					and f.single.hpLost <= hp[2]
				then
					inBand += 1
				end
				add(
					"eliteSingle",
					`eliteSingle.{key}.hp`,
					`{cave.id} {kind.kind} {f.level} {f.classId}{if f.variant then " " .. f.variant else ""}: Elita HP`,
					f.single.hpLost,
					T.eliteSingle.hpFloor,
					T.eliteSingle.hpCeil,
					f.classId,
					f.level
				)
				local cap = T.eliteEncounter[f.classId]
				if cap then
					add(
						"eliteEncounter",
						`eliteEncounter.{key}`,
						`{cave.id} {kind.kind} {f.level} {f.classId}{if f.variant then " " .. f.variant else ""}: spotkanie Elit (q = {string.format(
							"%.2f",
							cave.pairShare
						)})`,
						f.encounter,
						nil,
						cap,
						f.classId,
						f.level
					)
				end
			end
		end
		for _, e in cave.elite2 do
			local key = `{cave.id}.{e.kind}.{e.spawner}`
			local label = `{cave.id} {e.kind} {e.spawner}`
			add(
				"elite2",
				`elite2.{key}.solo`,
				`{label}: Elita II solo HP`,
				e.byTeam[1].hpLost,
				T.elite2.solo,
				nil,
				nil,
				e.playerLevel
			)
			add(
				"elite2",
				`elite2.{key}.duo`,
				`{label}: Elita II 2 graczy HP`,
				e.byTeam[2].hpLost,
				nil,
				T.elite2.duo,
				nil,
				e.playerLevel
			)
			add(
				"elite2",
				`elite2.{key}.trio`,
				`{label}: Elita II 3 graczy HP`,
				e.byTeam[3].hpLost,
				T.elite2.trio[1],
				T.elite2.trio[2],
				nil,
				e.playerLevel
			)
		end
	end
	-- S134i: the Elite IIs of the hideouts, the same rows (ids "elite2.<hideout>.<kind>.<spawner>")
	for _, lair in Balance.lairElites(mapId, withNodes) do
		for _, e in lair.elite2 do
			local key = `{lair.id}.{e.kind}.{e.spawner}`
			local label = `{lair.id} {e.kind} {e.spawner}`
			add(
				"elite2",
				`elite2.{key}.solo`,
				`{label}: Elita II solo HP`,
				e.byTeam[1].hpLost,
				T.elite2.solo,
				nil,
				nil,
				e.playerLevel
			)
			add(
				"elite2",
				`elite2.{key}.duo`,
				`{label}: Elita II 2 graczy HP`,
				e.byTeam[2].hpLost,
				nil,
				T.elite2.duo,
				nil,
				e.playerLevel
			)
			add(
				"elite2",
				`elite2.{key}.trio`,
				`{label}: Elita II 3 graczy HP`,
				e.byTeam[3].hpLost,
				T.elite2.trio[1],
				T.elite2.trio[2],
				nil,
				e.playerLevel
			)
		end
	end
	if single > 0 then
		add(
			"eliteSingle",
			"eliteSingle.share",
			"Elity solo: udział walk w paśmie czasu i HP",
			inBand / single,
			T.eliteSingle.shareInBand
		)
	end
	if withNodes then
		return rows
	end
	local meadows = mapId == "meadows"
	for _, k in Balance.kindRates(mapId, meadows) do
		local band = T.kinds.expPerSecond
		add(
			"kinds",
			`kinds.{k.kind}.exp`,
			`{k.kind} {k.level}: EXP/s ÷ zwykły`,
			k.expPerSecond,
			band[1],
			band[2],
			"Warrior",
			k.level
		)
		if k.caster and not meadows then
			add(
				"kinds",
				`kinds.{k.kind}.casterHp`,
				`{k.kind} {k.level}: HP/EXP rzucającego ÷ średnia regionu`,
				k.hpPerExp,
				nil,
				T.kinds.casterHpPerExp,
				"Warrior",
				k.level
			)
		end
	end
	local def = Bosses.forRegion(mapId) :: any
	if def then
		for phase = 1, #def.phases + 1 do
			local cad = Balance.bossCadence(def, phase)
			for _, attack in def.attacks do
				local share = cad.rateShare[attack.id]
				if share then
					add(
						"bossCadence",
						`boss.{phase}.{attack.id}`,
						`{def.id} faza {phase}: {attack.id}`,
						share,
						T.bossCadence,
						nil,
						nil,
						def.level
					)
				end
			end
		end
	end
	-- S84 (D5): drops per hour, profile K0 without Fortune, regions 2-4 (the band's levels every 5)
	local r = table.find(Balance.REGION_IDS, mapId) :: number
	if T.d5 and r > 1 then
		local band = Balance.BANDS[r]
		for L = band[1], band[2] - 1, 5 do
			for _, c in Balance.CLASSES do
				local d = Balance.dropsPerHour(c, L, "K0", false)
				local u, h = T.d5.uniquePerHour, T.d5.heroicPerHour
				add("d5", `d5.{c}.{L}.unique`, `{c} {L}: Unikaty dla klasy na h expienia`, d.unique, u[1], u[2], c, L)
				add("d5", `d5.{c}.{L}.heroic`, `{c} {L}: Heroiki dla klasy na h Elit`, d.heroic, h[1], h[2], c, L)
			end
		end
	end
	return rows
end

-- Balance ledger (S83, balance plan 2.6) ------------------------------------------------------------------------

Balance.LEDGER_LEVELS = { 1, 20, 45, 70, 100 }

export type LedgerReasons = {
	BALANCE_MODULES: { { path: string, pick: { string }?, omit: { string }? } },
	CONFIG_KEYS: { string },
	NOT_BALANCE: { [string]: string },
	reasons: { [string]: { { session: string, why: string } } },
}

-- A module of src/shared by its ledger path ("Data/Skills/init" is the directory module).
function Balance.requireShared(path: string): any
	local file = string.gsub(path, "/init$", "")
	return (require :: any)(`../src/shared/{file}`)
end

local function sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then
			return ta < tb -- numbers before strings
		end
		return a < b
	end)
	return keys
end

local function segment(parent: { [any]: any }, key: any): string
	if type(key) == "number" then
		local v = parent[key]
		if type(v) == "table" and type(v.id) == "string" then
			return `[{v.id}]`
		end
		return `[{key}]`
	end
	return `.{key}`
end

-- Function results skipped by the last dataDump (for the report section "Księga: pominięte funkcje").
Balance.skippedFunctions = {} :: { string }

-- Every finite number of the BALANCE_MODULES (and Config.CONFIG_KEYS) as "<module>:<path>" (module without the
-- "Data/" prefix). Segments: ".field", "[id]" for an array element with a text id, "[n]" otherwise, ".f(L)" for the
-- result of a function called with L in LEDGER_LEVELS (pcall; a failing call or a result that is neither a number
-- nor a table is skipped). Every table is dumped once (under its first path in sorted order).
function Balance.dataDump(reasonsModule: LedgerReasons): { [string]: number }
	local out: { [string]: number } = {}
	local skipped: { string } = {}
	local seen: { [any]: boolean } = {}
	local function walk(v: any, path: string, picked: boolean, entry: any)
		local t = type(v)
		if t == "number" then
			if picked and v == v and v ~= math.huge and v ~= -math.huge then
				out[path] = v
			end
		elseif t == "table" then
			if seen[v] then
				return
			end
			seen[v] = true
			for _, k in sortedKeys(v) do
				local name = if type(k) == "string" then k else nil
				if not (name and entry.omit and table.find(entry.omit, name)) then
					local isPicked = picked
						or (name ~= nil and entry.pick ~= nil and table.find(entry.pick, name) ~= nil)
					walk(v[k], path .. segment(v, k), isPicked, entry)
				end
			end
		elseif t == "function" then
			local any = false
			for _, L in Balance.LEDGER_LEVELS do
				local ok, result = pcall(v, L)
				if ok and (type(result) == "number" or type(result) == "table") then
					any = true
					walk(result, `{path}.f({L})`, picked, entry)
				end
			end
			if not any then
				table.insert(skipped, (string.gsub(path, ":%.", ":", 1)))
			end
		end
	end
	for _, entry in reasonsModule.BALANCE_MODULES do
		seen = {} -- per module: a record shared by two modules shows in both
		local module = Balance.requireShared(entry.path)
		local name = string.gsub(entry.path, "^Data/", "")
		walk(module, `{name}:`, entry.pick == nil, entry)
	end
	local config = Balance.requireShared("Config")
	for _, key in reasonsModule.CONFIG_KEYS do
		if key ~= "AdminUserIds" then
			walk(config[key], `Config:{key}`, true, {})
		end
	end
	-- the root path "<module>:" + ".field" reads "<module>:.field"; drop the dot after the colon
	local clean: { [string]: number } = {}
	for k, v in out do
		clean[(string.gsub(k, ":%.", ":", 1))] = v
	end
	table.sort(skipped)
	Balance.skippedFunctions = skipped
	return clean
end

-- Values of every skill's { rank 1, max rank } value pairs at every rank (Skills.valueAt, so knots of
-- Data/SkillCurves count): "Rangi:<skillId>.<field>@<r>". Derived numbers: they show a knot or a changed pair with
-- the rank band (Skills.rankLevel) and need no reason of their own.
function Balance.rankDump(): { [string]: number }
	local out: { [string]: number } = {}
	for id, skill in SkillData.byId do
		for field, value in skill.values do
			if type(value) == "table" then
				for r = 1, skill.maxLevel do
					out[`Rangi:{id}.{field}@{r}`] = Skills.valueAt(skill, field, r)
				end
			end
		end
	end
	return out
end

-- Session number of "S<n>" (nil for anything else). S134b: a follow-up session "S<n><letter>" ("S134b") counts as <n>.
function Balance.sessionNumber(session: string?): number?
	local n = session and string.match(session, "^S(%d+)%l?$")
	return if n then tonumber(n) else nil
end

-- The reasons of `key`: its own entries and those of the longest matching prefix ending in "*" (a newer bulk shift
-- of the whole table explains a key that has an older entry of its own).
function Balance.reasonsFor(reasons: { [string]: { any } }, key: string): { any }?
	local own = reasons[key]
	local best, bestLen = nil, -1
	for pattern, list in reasons do
		if string.sub(pattern, -1) == "*" then
			local prefix = string.sub(pattern, 1, -2)
			if string.sub(key, 1, #prefix) == prefix and #prefix > bestLen then
				best, bestLen = list, #prefix
			end
		end
	end
	if own and best then
		local merged = table.clone(own)
		table.move(best, 1, #best, #merged + 1, merged)
		return merged
	end
	return own or best
end

-- Equal up to the JSON round trip of the snapshot (serde keeps ~15 significant digits).
function Balance.sameNumber(a: number, b: number): boolean
	return a == b or math.abs(a - b) <= 1e-9 * math.max(math.abs(a), math.abs(b), 1e-9)
end

export type LedgerLine = { key: string, before: number?, after: number?, reason: { session: string, why: string }? }
export type Ledger =
	{ changed: { LedgerLine }, added: { LedgerLine }, removed: { LedgerLine }, unexplained: { string } }

-- Changes of the data dump (dataDump + rankDump, the "data" part of a snapshot) since the snapshot of
-- `snapshotSession`. A changed, added or removed number (but `Rangi:`) is explained by a reason (own key or longest
-- `*` prefix) of the snapshot's session or later; `reason` is the latest entry.
function Balance.ledger(
	before: { [string]: number },
	now: { [string]: number },
	reasons: { [string]: { any } },
	snapshotSession: string?
): Ledger
	local from = Balance.sessionNumber(snapshotSession) or 0
	local result: Ledger = { changed = {}, added = {}, removed = {}, unexplained = {} }
	local function explain(key: string): any
		local list = Balance.reasonsFor(reasons, key)
		local latest, latestN = nil, -1
		for _, entry in list or {} do
			local n = Balance.sessionNumber(entry.session)
			if n and n >= from and n >= latestN then
				latest, latestN = entry, n
			end
		end
		if latest == nil and string.sub(key, 1, 6) ~= "Rangi:" then
			table.insert(result.unexplained, key)
		end
		return latest
	end
	for key, a in now do
		local b = before[key]
		if b == nil then
			table.insert(result.added, { key = key, after = a, reason = explain(key) })
		elseif not Balance.sameNumber(a, b) then
			table.insert(result.changed, { key = key, before = b, after = a, reason = explain(key) })
		end
	end
	for key, b in before do
		if now[key] == nil then
			table.insert(result.removed, { key = key, before = b, reason = explain(key) })
		end
	end
	local function byKey(x: LedgerLine, y: LedgerLine): boolean
		return x.key < y.key
	end
	table.sort(result.changed, byKey)
	table.sort(result.added, byKey)
	table.sort(result.removed, byKey)
	table.sort(result.unexplained)
	return result
end

-- dataDump + rankDump: the "data" part of a snapshot.
function Balance.ledgerData(reasonsModule: LedgerReasons): { [string]: number }
	local out = Balance.dataDump(reasonsModule)
	for k, v in Balance.rankDump() do
		out[k] = v
	end
	return out
end

-- Items, loot and monster defence 20-100 (S84) ------------------------------------------------------------------
-- Item traits as expected values in the STATY 14 situations, rarity gain (G7), two-handed parity (G8), upgrades
-- against income (G9), materials, item level gaps, drops per hour with the luck profiles (D5) and the defence of
-- monster families. Game formulas only (ItemRoll, Logic/Traits, Damage, FightSim, Upgrade, Loot, AreaRates,
-- Logic/Luck); the assumptions are the test data at the top (SITUATIONS, MIX, G8_PAIRS, LUCK_PROFILES).

Balance.makeItem = makeItem
Balance.tierId = tierId
Balance.expectedBonuses = expectedBonuses
Balance.ITEM_LEVELS = { 20, 45, 70, 100 }
Balance.GEAR_RARITIES = { Rarities.COMMON, Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC }
local ELEMENTS = { "fire", "ice", "lightning" }

local function optsKey(o: GearOpts?): string
	if not o then
		return ""
	end
	local scale = ""
	if o.traitScale then
		local parts = {}
		for _, id in sortedKeys(o.traitScale) do
			table.insert(parts, `{id}={o.traitScale[id]}`)
		end
		scale = table.concat(parts, ",")
	end
	return `{o.ilvl}|{o.weaponIlvl}|{o.rarity}|{o.up}|{o.weapon}|{o.offhand}|{o.jewellery}|{o.armor}|{o.bonuses}|{o.element}|{scale}`
end

local itemPlayers: { [string]: Player } = {}
-- Balance.player cached by class, level and every gear option (the S84 grids ask for the same sets many times).
function Balance.itemPlayer(classId: string, level: number, opts: GearOpts?): Player
	local key = `{classId}|{level}|{optsKey(opts)}`
	local p = itemPlayers[key]
	if not p then
		p = Balance.player(classId, level, opts)
		itemPlayers[key] = p
	end
	return p
end

-- A copy of `base` with the fields of `extra`.
function Balance.withOpts(base: GearOpts?, extra: { [string]: any }): GearOpts
	local out: any = table.clone(base or {})
	for k, v in extra do
		out[k] = v
	end
	return out
end

-- A copy of `base` with trait `traitId` off (traitValue: "M(with) / M(without)", the other trait stays).
function Balance.withoutTrait(base: GearOpts?, traitId: string): GearOpts
	local scale = table.clone((base and base.traitScale) or {})
	scale[traitId] = 0
	return Balance.withOpts(base, { traitScale = scale })
end

-- Situations ------------------------------------------------------------------------------------------------------

export type SituationCtx = {
	name: string,
	level: number,
	m: any, -- the monster the player hits (DPS) and that hits the player (its regular attack)
	hit: number, -- expected damage of one regular attack on the player (FightSim.hit; group: mean over the sizes)
	attacks: number, -- regular attacks on the player per s of fighting
	seconds: number, -- s on one target (ticks before its death, armour break stacks)
	kills: number, -- kills per s (Reaping)
	targetShare: number, -- share of the attacks coming from the target being hit (weaken, attack slow, stun)
	othersAlive: number, -- share of the time another enemy stands near (Spark's lightning)
	behind: number, -- Run Through: share of basic hits with an enemy in the band behind the target
	controlled: number, -- Easy Prey: share of the fight others keep the target controlled
	still: number, -- Runic Seal: share of the fight the Mage stands still
	bossLike: boolean, -- bosses and Elite II: immune to Concussion
	measure: string, -- "power" (moc²), "ehp" (tank) or "loss" (HP lost per kill, solo)
	rates: { { attacks: number, targetShare: number } }?, -- tank: the attack rates averaged
	-- S88 (F1): the target is a player (Balance.pvpDuel): every trait with its PvP rule (STATY 8, mirrors the PvP
	-- branches of CombatService); nil = against monsters, every number as before
	pvp: boolean?,
}

local bossFights: { [string]: BossFight } = {}
-- S83 boss fight of the region boss of regionAt(level) at `level`, a team of SITUATIONS.bossTeam with `classId`
-- first (the tank) and the next classes of CLASSES; once per (boss, class, level).
function Balance.bossFightAt(classId: string, level: number): (any, BossFight)
	local def = Bosses.forRegion(Balance.REGION_IDS[Balance.regionAt(level)]) :: any
	local key = `{def.id}|{classId}|{level}`
	local f = bossFights[key]
	if not f then
		local team = { Balance.cachedPlayer(classId, level) }
		for _, c in Balance.CLASSES do
			if c ~= classId and #team < Balance.SITUATIONS.bossTeam then
				table.insert(team, Balance.cachedPlayer(c, level))
			end
		end
		f = Balance.bossFight(def.id, team, { level = level })
		bossFights[key] = f
	end
	return def, f :: BossFight
end

-- Group of the S83 model at the player's level: attacks on the player, kills, the target's share of the attacks and
-- the time another member lives (members killed one by one, each living member swings at once, then every interval).
local function groupStats(p: Player, kind: any, level: number): any
	local first = Balance.monster(kind, level)
	local d = first.maxHp / math.max(1e-6, FightSim.dps(p :: any, first, Balance.SKILL_DPS))
	local hits, attacks, seconds, kills, target, others = 0, 0, 0, 0, 0, 0
	for n, w in AreaSpawns.GROUP_SIZE_WEIGHTS do
		local members = FightSim.group(kind, level, n)
		local m = members[1]
		local a, t = n, 1
		for k = 1, n do
			a += (n - k + 1) * d / m.attackInterval
			t += d / m.attackInterval
		end
		hits += w * FightSim.hit(m, p :: any) * a
		attacks += w * a
		seconds += w * n * d
		kills += w * n
		target += w * t
		others += w * (n - 1) * d
	end
	return {
		monster = first,
		hit = hits / attacks,
		attacks = attacks / seconds,
		seconds = d,
		kills = kills / seconds,
		targetShare = target / attacks,
		othersAlive = others / seconds,
	}
end

local situations: { [any]: { [string]: SituationCtx } } = setmetatable({}, { __mode = "k" }) :: any

-- The situation `name` of SITUATION_LIST for player `p` (monster level `level`, default p.level). Cached per player.
function Balance.situationCtx(p: Player, name: string, level: number?): SituationCtx
	local L = level or p.level
	local byPlayer = situations[p]
	if not byPlayer then
		byPlayer = {}
		situations[p] = byPlayer
	end
	local key = `{name}|{L}`
	local cached = byPlayer[key]
	if cached then
		return cached
	end
	local S = Balance.SITUATIONS
	local function make(m: any, seconds: number, measure: string): SituationCtx
		return {
			name = name,
			level = L,
			m = m,
			hit = FightSim.hit(m, p :: any),
			attacks = 1 / m.attackInterval,
			seconds = seconds,
			kills = 1 / seconds,
			targetShare = 1,
			othersAlive = 0,
			behind = 0,
			controlled = 0,
			still = 0,
			bossLike = false,
			measure = measure,
			rates = nil,
		}
	end
	local function duelSeconds(m: any): number
		return m.maxHp / math.max(1e-6, FightSim.dps(p :: any, m, Balance.SKILL_DPS))
	end
	local ctx: SituationCtx
	if name == "group" then
		local g = groupStats(p, Balance.GENERIC, L)
		ctx = make(g.monster, g.seconds, "power")
		ctx.hit, ctx.attacks, ctx.kills = g.hit, g.attacks, g.kills
		ctx.targetShare, ctx.othersAlive, ctx.behind = g.targetShare, g.othersAlive, S.behindShare
	elseif name == "elite" then
		local m = Balance.monster(Balance.GENERIC, L, "elite")
		local d = duelSeconds(m)
		ctx = make(m, d, "power")
		ctx.attacks = (1 + d / m.attackInterval) / d
	elseif name == "boss" then
		local def, f = Balance.bossFightAt(p.classId, L)
		local m = Balance.monster(Balance.bossKind(def), L, "boss")
		ctx = make(m, f.seconds, "power")
		local wave = f.shieldSeconds / math.max(1e-9, f.seconds)
		ctx.attacks = (f.activeSeconds / m.attackInterval + f.shieldAttacks) / math.max(1e-9, f.seconds)
		ctx.kills = f.shieldKills / math.max(1e-9, f.seconds)
		ctx.othersAlive = wave
		ctx.behind = S.behindShare * wave
		ctx.still = S.still
		ctx.bossLike = true
	elseif name == "armored" then
		local defence = Families.defence("undead", "armored") :: Families.Defence
		local kind = table.clone(Balance.GENERIC) :: any
		kind.defMul = defence.defMul or 1
		ctx = make(Balance.monster(kind, L), S.singleSeconds, "power")
	elseif name == "tank" then
		local m = Balance.monster(Balance.GENERIC, L)
		local g = groupStats(p, Balance.GENERIC, L)
		ctx = make(m, duelSeconds(m), "ehp")
		ctx.rates = {
			{ attacks = S.tankRates[1], targetShare = g.targetShare },
			{ attacks = S.tankRates[2], targetShare = 1 },
		}
	elseif name == "solo" then
		local m = Balance.monster(Balance.GENERIC, L)
		local d = duelSeconds(m)
		ctx = make(m, d, "loss")
		ctx.attacks = (1 + d / m.attackInterval) / d
		ctx.kills = 1 / S.killEvery
	else -- single, controlled, still, mana, dungeon
		ctx = make(Balance.monster(Balance.GENERIC, L), S.singleSeconds, "power")
		if name == "controlled" then
			ctx.controlled = S.controlled
		elseif name == "still" then
			ctx.still = S.still
		end
	end
	byPlayer[key] = ctx
	return ctx
end

-- Trait terms (S84 B4) ---------------------------------------------------------------------------------------------

export type TraitTerm = {
	dps: number, -- added share of the DPS (0.04 = +4 %)
	takenMul: number, -- multiplier of the damage taken per second
	sustain: number, -- HP per s of fighting
	armorMul: number, -- multiplier of the target's armour (back to Damage through m.armor)
	inStats: boolean, -- a stat trait (StatCalc) or Parry's block (FightSim.hit): its value comes from traitScale only
}
export type TraitTerms = {
	dpsMul: number,
	takenMul: number,
	sustain: number,
	killHealHp: number, -- HP healed per kill inside `sustain` (sustain holds it x ctx.kills per s)
	armorMul: number,
	dps: number, -- FightSim.dps on the changed armour x basicShare x SKILL_DPS x dpsMul
	baseDps: number, -- the same before dpsMul
	hitAdd: number, -- S88: the hit part of dpsMul - 1 (counters, extra hits, bonuses)
	dotAdd: number, -- S88: the tick part (bleed, poison, burn; x Combat.pvp.dot in PvP)
	byTrait: { [string]: TraitTerm },
	-- the same mechanisms from lines alone (woundChance, killHeal, lifesteal, executioner, ...): outside the S32
	-- convention, so not in the totals; with the trait they count in its term (shared cap, B6)
	lines: { [string]: TraitTerm },
}

local STAT_TRAITS = { criticalForce = true, bodkinBolt = true, learnedFormulae = true, powerLens = true }
STAT_TRAITS.anointment = true
STAT_TRAITS.prosperity = true

local function emptyTerm(inStats: boolean?): TraitTerm
	return { dps = 0, takenMul = 1, sustain = 0, armorMul = 1, inStats = inStats == true }
end

-- Expected value of every trait of `p` (and of the lines sharing its mechanism and cap, B6) in a situation:
-- STATY 14 situations through Logic/Traits and the game numbers of Data/ItemTraits, Data/Combat, Data/BuffCategories.
-- Each contribution counts once: stat traits are in the stats already (inStats), Parry's block in FightSim.hit.
-- S86 (C3, A5): measured situations of tests/SkillModel (SkillModel.situations) instead of the S84 assumptions;
-- a missing field keeps the assumption, no table = S84 exactly.
export type Measured = {
	basicShare: number?,
	skillInterval: number?,
	elementShare: number?,
	iceUptime: number?,
	controlled: number?,
	still: number?,
	areaShare: number?,
}

function Balance.traitTerms(p: Player, m: any, situation: string | SituationCtx, measured: Measured?): TraitTerms
	local ctx: SituationCtx
	if type(situation) == "string" then
		ctx = table.clone(Balance.situationCtx(p, situation))
		ctx.m = m
	else
		ctx = situation :: SituationCtx
	end
	local S = Balance.SITUATIONS
	local mz: Measured = measured or {}
	if measured and (mz.controlled ~= nil or mz.still ~= nil) then
		ctx = table.clone(ctx)
		ctx.controlled = if mz.controlled ~= nil then mz.controlled else ctx.controlled
		ctx.still = if mz.still ~= nil then mz.still else ctx.still
	end
	local skillInterval = mz.skillInterval or S.skillInterval
	local elementShare = mz.elementShare or S.elementShare
	local iceUptimeAssumed = mz.iceUptime or S.iceUptime
	-- area skills roll on-hit effects with Combat.areaProcShare per target (S63); 0 in the S32 convention
	local areaShare = mz.areaShare or 0
	local v, hooks = p.values, p.hooks
	local traits = p.traits or {}
	local byTrait: { [string]: TraitTerm } = {}
	local lines: { [string]: TraitTerm } = {}
	-- a line mechanism without its trait stays outside the S32 convention (shown in `lines`, not in the totals)
	local lineOnly: { [TraitTerm]: boolean } = {}
	local function termOf(traitId: string?, lineId: string): TraitTerm
		local list = if traitId then byTrait else lines
		local id = traitId or lineId
		local t = list[id]
		if not t then
			t = emptyTerm()
			list[id] = t
			lineOnly[t] = traitId == nil
		end
		return t
	end
	for id in traits do
		if STAT_TRAITS[id] or id == "parry" then
			byTrait[id] = emptyTerm(true)
		end
	end
	local bs = mz.basicShare or S.basicShare[p.classId] or 0.5
	local maxHp = math.max(1, v.maxHp or 1)
	local swings = math.max(0.1, v.atkSpeed or 1)
	local double = 1 + (hooks.doubleAttack or 0) / 100
	local hitShare = 1 - Damage.dodgeChance(m.dodge or 0, v.accuracy or 0)
	-- hits that roll on-hit effects: basic attacks that land (no double or secondary hits) and one-target skills
	local procHits = swings * hitShare + 1 / skillInterval * ((1 - areaShare) + areaShare * Combat.areaProcShare)

	-- Sundering (hammer2h): a stack of `value` % per hit (one duration, refreshed by every hit), mean over the time
	-- on the target, capped by enemyArmorItem; physical attackers only (mirrors CombatService.applyTraitEffect).
	local armorMul = 1
	local sunder = traits.sundering
	if sunder and not p.magic then
		local onHit = sunder.def.onHit :: ItemTraits.OnHit
		local stacks = if ctx.pvp then Combat.pvp.armorBreakStacks else onHit.maxStacks or 1
		local cap = math.min(stacks, BuffCategories.caps.enemyArmorItem / math.max(1e-9, sunder.value))
		local full = cap / procHits
		local T = ctx.seconds
		local mean = if T <= full then procHits * T / 2 else cap - cap * full / (2 * T)
		local broken = math.min(sunder.value * mean, BuffCategories.caps.enemyArmor)
		armorMul = 1 - broken / 100
		termOf("sundering", "").armorMul = armorMul
	end
	local target = m
	if armorMul ~= 1 then
		target = table.clone(m)
		target.armor = m.armor * armorMul
	end
	local baseDps = FightSim.dps(p :: any, target, 1 / bs) * bs * Balance.SKILL_DPS
	local basicDps = FightSim.dps(p :: any, target, 1) * bs * Balance.SKILL_DPS
	local skillDps = baseDps - basicDps
	-- one basic swing in the model's scale (dodge counted): extra basic hits copy it
	local swing = basicDps / (swings * double)
	local hitAdd, dotAdd = 0, 0
	local function addHit(t: TraitTerm, share: number)
		t.dps += share
		hitAdd += if lineOnly[t] then 0 else share
	end
	local function addDot(t: TraitTerm, share: number)
		t.dps += share
		dotAdd += if lineOnly[t] then 0 else share
	end

	-- Swordplay: every regular attack on the player rolls Traits.counterChance(riposte) for an instant basic hit
	-- x (1 + counterDamage %) (mirrors CombatService tryCounter).
	local riposte = hooks.riposte or 0
	local pvp = ctx.pvp == true
	local pvpBy = ItemTraits.pvpByHook
	if riposte > 0 then
		local chance = Traits.counterChance(riposte, pvp) / 100
		local bonus = hooks.counterDamage or 0
		if pvp then -- mirrors CombatService tryCounter (Traits.pvpValue of counterDamage)
			bonus = Traits.pvpValue(bonus, pvpBy.counterDamage)
		end
		local t = termOf(if traits.swordplay then "swordplay" else nil, "riposte")
		addHit(t, ctx.attacks * chance * (1 + bonus / 100) * swing / baseDps)
	end
	-- Twin Cut: every `every`-th basic swing strikes again for value % (Traits.twinCut; mirrors
	-- CombatService:tryBasicAttack).
	local twin = traits.twinCut
	if twin then
		local every = (twin.def.params :: any).every
		addHit(termOf("twinCut", ""), swings / every * twin.value / 100 * swing / baseDps)
	end
	-- Run Through: a landed basic hit with an enemy in the band hits it for value % (a dodgeable basic hit; mirrors
	-- CombatService:runThrough).
	local run = traits.runThrough
	if run then
		addHit(termOf("runThrough", ""), swings * hitShare * ctx.behind * run.value / 100 * swing / baseDps)
	end
	-- Full Draw: one boosted basic attack per offensive skill, + Traits.drawBonus(value, weapon speed) % (mirrors
	-- CombatService:tryBasicAttack).
	local draw = traits.fullDraw
	if draw then
		local casts = math.min(swings, 1 / skillInterval)
		local bonus = Traits.drawBonus(draw.value, p.weaponSpeed, if pvp then pvpBy.traitFullDraw else nil)
		addHit(termOf("fullDraw", ""), casts * bonus / 100 * swing / baseDps)
	end
	-- Beheading + executioner lines: below Combat.lowHpFraction the damage is x (1 + Traits.executeBonus): the fight
	-- takes (1 - f) / D + f / (D x (1 + b)) of its time (mirrors CombatService:offensiveMultiplier).
	local execute = Traits.executeBonus(
		hooks.executioner or 0,
		hooks.traitExecute or 0,
		if pvp then pvpBy.traitExecute else nil
	) / 100
	if execute > 0 then
		local f = Combat.lowHpFraction
		local mul = 1 / ((1 - f) + f / (1 + execute))
		addHit(termOf(if traits.beheading then "beheading" else nil, "executioner"), mul - 1)
	end
	-- Bleed (Rending Gash, woundChance) and poison (Toxic Barbs, poisonChance): Traits.chance per hit, pct % of the
	-- hit over the duration in Traits.ticks ticks (+ dotPower), ticks after the target's death lost, maxStacks sums.
	local attackSlow: { [string]: number } = {}
	for _, entry in ItemTraits.onHitList do
		local spec = entry.onHit
		if spec.effect == "bleed" or spec.effect == "poison" then
			local trait = traits[entry.trait.id]
			local grown = if trait then trait.value else 0
			local line = if spec.line then hooks[spec.line] or 0 else 0
			if grown > 0 or line > 0 then
				local chance = Traits.chance(if grown > 0 then spec.chance or 0 else 0, line, 1) / 100
				local pct = if grown > 0 then grown else spec.linePct or 0
				local ticks = Traits.ticks(spec.duration)
				local inFlight = chance * procHits * spec.duration
				local capped = math.min(1, (spec.maxStacks or 1) / math.max(1e-9, inFlight))
				local delivered = math.clamp(1 - (ticks + 1) / 2 / ctx.seconds, 0, 1)
				local share = chance
					* pct
					/ 100
					* (1 + (hooks.dotPower or 0) / 100)
					* (basicDps / double + skillDps)
					* capped
					* delivered
					/ baseDps
					* (if pvp then Combat.pvp.dot else 1) -- mirrors Traits.pvpTick (once, S63)
				addDot(termOf(if grown > 0 then entry.trait.id else nil, spec.line or spec.effect), share)
				if grown > 0 and spec.attackSlow then
					attackSlow[entry.trait.id] = 1 - (1 - chance) ^ (procHits * spec.duration)
				end
			end
		end
	end
	-- Elemental Spark (wand): Traits.chance(value) per landed basic hit wakes the weapon element (Traits.elementPlan
	-- with the Spark params, elementRider, dotPower); every element on its own, the mean when the gear names none
	-- (mirrors CombatService:spark and Skills/Elements:apply).
	local spark = traits.elementalSpark
	local iceUptime = 0
	if spark then
		local params = spark.def.params :: any
		local spec: Traits.ElementSpec = {
			burnPct = params.burnPct,
			burnDuration = params.burnDuration,
			exactTicks = true,
			slowPct = params.slowPct,
			slowDuration = params.slowDuration,
			arcPct = params.arcPct,
			arcRadius = params.arcRadius,
			sameTargetPct = params.sameTargetPct,
		}
		local chance = Traits.chance(spark.value, 0, 1) / 100
		local rate = swings * hitShare * chance
		local list = if p.element then { p.element } else ELEMENTS
		local hit, dmg = 0, 0
		for _, element in list do
			local plan = Traits.elementPlan(element, spec, 1, hooks.elementRider or 0, hooks.dotPower or 0, false)
			if plan and plan.kind == "burn" then
				local ticks = Traits.ticks(plan.duration)
				local capped = math.min(1, 1 / math.max(1e-9, rate * plan.duration))
				local delivered = math.clamp(1 - (ticks + 1) / 2 / ctx.seconds, 0, 1)
				local share = rate / hitShare * plan.pct / 100 * (1 + (hooks.dotPower or 0) / 100)
				dmg += share * swing * capped * delivered / baseDps * (if pvp then Combat.pvp.dot else 1)
			elseif plan and plan.kind == "slow" then
				-- Frostbite: +max(FROSTBITE, frostbite hook) % from you on targets your ice slowed
				local slowFor = plan.duration * (if pvp then Config.PvpCcMultiplier else 1)
				local uptime = 1 - (1 - chance) ^ (swings * hitShare * slowFor)
				local frost = math.max(SkillData.FROSTBITE, hooks.frostbite or 0)
				hit += uptime * frost * (if pvp then Combat.pvp.frostbite else 1) / 100
				iceUptime += uptime / #list
			elseif plan and plan.kind == "arc" then
				local pct = ctx.othersAlive * plan.pct + (1 - ctx.othersAlive) * plan.sameTarget
				hit += rate * pct / 100 * swing / baseDps
			end
		end
		local t = termOf("elementalSpark", "")
		addHit(t, hit / #list)
		addDot(t, dmg / #list)
	end
	-- Elemental Might (staff): element effects of skills + value % (elementShare of the damage); ice: Frostbite of the
	-- staff above SkillData.FROSTBITE while the skills slow the target (iceUptime).
	local might = traits.elementalMight
	if might then
		local list = if p.element then { p.element } else ELEMENTS
		local sum = 0
		for _, element in list do
			if element == "ice" then
				local frost = math.max(SkillData.FROSTBITE, hooks.frostbite or 0)
				local frostMul = if pvp then Combat.pvp.frostbite else 1
				sum += iceUptimeAssumed * (frost - SkillData.FROSTBITE) * frostMul / 100
			else
				sum += elementShare * might.value / 100
			end
		end
		addHit(termOf("elementalMight", ""), sum / #list)
	end
	-- Harrying: Traits.chance(value) per hit, attack slow for the duration; with poison: enemyAttackSlow keeps the
	-- strongest (Traits.slowedInterval caps it).
	local harry = traits.harrying
	local harryUptime = 0
	if harry then
		local onHit = harry.def.onHit :: ItemTraits.OnHit
		local chance = Traits.chance(harry.value, 0, 1) / 100
		local lasts = onHit.duration * (if pvp then Config.PvpCcMultiplier else 1)
		harryUptime = 1 - (1 - chance) ^ (procHits * lasts)
		local slow = math.min(onHit.attackSlow or 0, BuffCategories.caps.enemyAttackSlow)
		termOf("harrying", "").takenMul *= 1 - ctx.targetShare * harryUptime * slow / 100
	end
	for traitId, uptime in attackSlow do
		local onHit = (ItemTraits.get(traitId) :: ItemTraits.TraitDef).onHit :: ItemTraits.OnHit
		local slow = math.min(onHit.attackSlow or 0, BuffCategories.caps.enemyAttackSlow)
		termOf(traitId, "").takenMul *= 1 - ctx.targetShare * uptime * (1 - harryUptime) * slow / 100
	end
	-- Easy Prey: + Traits.controlledBonus while the target is controlled (others in `controlled`, own slows; mirrors
	-- CombatService:offensiveMultiplier).
	local prey = traits.easyPrey
	if prey then
		local share = math.max(ctx.controlled, harryUptime, iceUptime)
		local preyPvp = if pvp then pvpBy.controlledDamage else nil
		addHit(termOf("easyPrey", ""), share * Traits.controlledBonus(prey.value, 0.5, preyPvp) / 100)
	end
	-- Runic Seal: + value % while the Mage stands still (mirrors CombatService:pollSeal and offensiveMultiplier).
	local seal = traits.runicSeal
	if seal then
		local sealValue = if pvp then Traits.pvpValue(seal.value, pvpBy.traitRuneSeal) else seal.value
		addHit(termOf("runicSeal", ""), ctx.still * sealValue / 100)
	end
	-- Bonebreaker: every hit weakens the target by value % (cap enemyDamageDown) for the duration.
	local bone = traits.bonebreaker
	if bone then
		local onHit = bone.def.onHit :: ItemTraits.OnHit
		local uptime = math.min(1, procHits * onHit.duration)
		local grown = if pvp then Traits.pvpValue(bone.value, pvpBy.traitWeaken) else bone.value
		local weaken = math.min(grown, BuffCategories.caps.enemyDamageDown)
		termOf("bonebreaker", "").takenMul *= 1 - ctx.targetShare * uptime * weaken / 100
	end
	-- Concussion: stuns every 1 / (gap + 1 / (chance x hits)) s; the next attack moves to stun + delayShare x
	-- interval (mirrors Monster.DelayAttack: expected delay a² / 2I, a - I / 2 above the interval). Bosses immune.
	local shock = traits.concussion
	if shock and not ctx.bossLike then
		local onHit = shock.def.onHit :: ItemTraits.OnHit
		local chance = Traits.chance(shock.value, 0, 1) / 100
		local interval = m.attackInterval
		local a = onHit.duration + (onHit.delayShare or 0) * interval
		local delay = if a <= interval then a * a / (2 * interval) else a - interval / 2
		if pvp then -- a stunned player loses the stun (x PvpCcMultiplier); Monster.DelayAttack is monsters only
			delay = onHit.duration * Config.PvpCcMultiplier
		end
		local per = 1 / ((onHit.gap or 0) + 1 / math.max(1e-9, chance * procHits))
		termOf("concussion", "").takenMul *= 1 - ctx.targetShare * math.min(1, per * delay)
	end

	-- Sustain: Reaping + killHeal lines (on every kill), Parry's heal on every block, lifesteal and Saving Blow on the
	-- bearer under the lifesteal cap (Traits.savingSelfShare).
	-- mirrors CombatService:reward (killHeal % of max HP per kill, S88: Traits.killHeal caps the sum)
	local killHeal = if pvp then 0 else Traits.killHeal(hooks.killHeal or 0) -- monsters only
	local killHealHp = 0
	if killHeal > 0 then
		termOf(if traits.reaping then "reaping" else nil, "killHeal").sustain += killHeal * maxHp * ctx.kills / 100
		killHealHp = if traits.reaping then killHeal * maxHp / 100 else 0
	end
	-- mirrors CombatService:onBlock (blockHeal % of max HP per block)
	local blockHeal = hooks.blockHeal or 0
	if pvp then -- mirrors CombatService onBlock (Traits.pvpValue of blockHeal)
		blockHeal = Traits.pvpValue(blockHeal, pvpBy.blockHeal)
	end
	if blockHeal > 0 then
		local _, _, block = Damage.avoidance(v.dodge or 0, 0, 0, Traits.blockChance(hooks.block or 0, pvp))
		termOf(if traits.parry then "parry" else nil, "blockHeal").sustain += ctx.attacks * block * blockHeal / 100 * maxHp
	end
	local hitDps = baseDps * (1 + hitAdd)
	local lifesteal = v.lifesteal or 0
	local lsDef = Stats.get("lifesteal")
	local lsCap = if lsDef and lsDef.cap then lsDef.cap else 100
	local saving = traits.savingBlow
	local stealMul = if pvp then Combat.pvp.lifesteal else 1 -- mirrors Damage.computeDamage (PvP lifesteal)
	if lifesteal > 0 then
		-- in PvP the heal comes from the hit after pvpModifier (Damage.computeDamage, CombatService:savingBlow)
		local steal = math.min(lifesteal, lsCap) / 100 * hitDps * stealMul * (if pvp then Combat.pvpModifier else 1)
		termOf(if saving then "savingBlow" else nil, "lifesteal").sustain += steal
	end
	if saving then -- mirrors CombatService:savingBlow
		local pct = if pvp then Traits.pvpValue(saving.value, pvpBy.traitSavingBlow) else saving.value
		local dealt = hitDps * (if pvp then Combat.pvpModifier else 1)
		termOf("savingBlow", "").sustain += Traits.savingSelfShare(pct, lifesteal) / 100 * dealt
	end

	local dpsMul, takenMul, sustain = 1 + hitAdd + dotAdd, 1, 0
	for _, id in sortedKeys(byTrait) do
		local t = byTrait[id]
		takenMul *= t.takenMul
		sustain += t.sustain
	end
	return {
		dpsMul = dpsMul,
		takenMul = takenMul,
		sustain = sustain,
		killHealHp = killHealHp,
		armorMul = armorMul,
		dps = baseDps * dpsMul,
		baseDps = baseDps,
		hitAdd = hitAdd,
		dotAdd = dotAdd,
		byTrait = byTrait,
		lines = lines,
	}
end

-- Power, EHP and HP lost per kill in a situation (S84 B5) ----------------------------------------------------------

-- sqrt(DPS x EHP) with the trait terms: DPS = traitTerms.dps, EHP = max HP / (hit x takenMul - sustain per hit), the
-- sustain at most 0.8 of the hit (EHP never infinite).
function Balance.situationPower(p: Player, ctx: SituationCtx): number
	local t = Balance.traitTerms(p, ctx.m, ctx)
	local taken = ctx.hit * t.takenMul
	local net = taken - math.min(t.sustain / math.max(1e-9, ctx.attacks), 0.8 * taken)
	return math.sqrt(t.dps * p.values.maxHp / math.max(1e-9, net))
end

-- The measure M of a situation and its kind: "power" = moc² (DPS x EHP), "ehp" = EHP of the tank (mean over the
-- attack rates), "loss" = HP lost per kill in a duel (share of max HP; lower is better).
function Balance.situationMeasure(p: Player, situation: string, level: number?): (number, string)
	local ctx = Balance.situationCtx(p, situation, level)
	if ctx.measure == "ehp" then
		local sum = 0
		local rates = ctx.rates :: { { attacks: number, targetShare: number } }
		for _, r in rates do
			local c = table.clone(ctx)
			c.attacks, c.targetShare = r.attacks, r.targetShare
			local t = Balance.traitTerms(p, ctx.m, c)
			local taken = c.attacks * ctx.hit * t.takenMul
			sum += p.values.maxHp / math.max(1e-9, taken - math.min(t.sustain, 0.8 * taken))
		end
		return sum / #rates, "ehp"
	elseif ctx.measure == "loss" then
		local t = Balance.traitTerms(p, ctx.m, ctx)
		local seconds = ctx.m.maxHp / math.max(1e-9, t.dps)
		local incoming = ctx.hit * t.takenMul * (1 + seconds / ctx.m.attackInterval)
		-- the kill heal once per kill, the rest of the sustain per second of the duel
		local perSecond = t.sustain - t.killHealHp * ctx.kills
		local heal = (perSecond + (p.values.hpRegenCombat or 0)) * seconds + t.killHealHp
		return (incoming - math.min(heal, 0.8 * incoming)) / p.values.maxHp, "loss"
	end
	return Balance.situationPower(p, ctx) ^ 2, "power"
end

-- Power in MIX (B5): sum of weight x power in the situation / power of the class's default Common set of the same
-- level in that situation, over the weights (a unitless index, 1 = the default Common set; every situation counts
-- with its MIX weight whatever its scale).
function Balance.powerMix(p: Player, mix: { [string]: number }?): number
	local weights = mix or Balance.MIX
	local base = Balance.itemPlayer(p.classId, p.level)
	local total, sum = 0, 0
	for _, name in sortedKeys(weights) do
		local w = weights[name]
		local opts: PowerOpts = { traits = true, situation = name }
		total += w * Balance.power(p, nil, opts) / Balance.power(base, nil, opts)
		sum += w
	end
	return total / sum
end

-- Value of trait `traitId` (B5, S88 definition): M(with) / M(without) - 1 with traitScale[traitId] = 0 (the other
-- trait of the set stays); M = moc² (power situations and "mix"), EHP (`tank`); `solo`: loss without / loss with - 1.
function Balance.traitValue(
	classId: string,
	level: number,
	gearOpts: GearOpts?,
	traitId: string,
	situation: string
): number
	local with = Balance.itemPlayer(classId, level, gearOpts)
	local without = Balance.itemPlayer(classId, level, Balance.withoutTrait(gearOpts, traitId))
	if situation == "mix" then
		return (Balance.powerMix(with) / Balance.powerMix(without)) ^ 2 - 1
	end
	local a, kind = Balance.situationMeasure(with, situation)
	local b = Balance.situationMeasure(without, situation)
	if kind == "loss" then
		return b / math.max(1e-9, a) - 1
	end
	return a / math.max(1e-9, b) - 1
end

-- Run Through with another band share `behind` instead of SITUATIONS.behindShare (B3: the band is not measured, so
-- the report also shows SITUATIONS.behindReport); `group` or `boss` (its shield waves scale the share the same way).
function Balance.runThroughValue(level: number, rarity: number, up: number, behind: number, situation: string): number
	local classId, gear = Balance.traitGear("runThrough", rarity, up)
	local function measure(p: Player): number
		local ctx = table.clone(Balance.situationCtx(p, situation))
		ctx.behind *= behind / Balance.SITUATIONS.behindShare
		return Balance.situationPower(p, ctx) ^ 2
	end
	local with = Balance.itemPlayer(classId, level, gear)
	local without = Balance.itemPlayer(classId, level, Balance.withoutTrait(gear, "runThrough"))
	return measure(with) / math.max(1e-9, measure(without)) - 1
end

-- Trait table (S84 B7) ---------------------------------------------------------------------------------------------

-- Class and set of each trait (STATY 3, first path: a one-handed weapon with the class's off-hand, an off-hand with
-- the class's weapon, the relic with the Priest of Fortune's scepter) and the situations of its STATY 14 row.
Balance.TRAIT_SETS = {
	swordplay = { "Warrior", "sword1h", "shield", { "group", "elite", "boss", "single" } },
	twinCut = { "Warrior", "saber1h", "shield", { "single", "elite" } },
	reaping = { "Warrior", "axe1h", "shield", { "solo", "boss" } },
	bonebreaker = { "Warrior", "mace1h", "shield", { "tank", "single", "boss" } },
	beheading = { "Warrior", "sword2h", false, { "single", "group", "elite", "boss" } },
	rendingGash = { "Warrior", "axe2h", false, { "single", "elite" } },
	sundering = { "Warrior", "hammer2h", false, { "armored", "single" } },
	runThrough = { "Warrior", "spear2h", false, { "group", "boss" } },
	parry = { "Warrior", "sword1h", "shield", { "tank" } },
	harrying = { "Hunter", "shortbow", "quiver", { "solo" } },
	toxicBarbs = { "Hunter", "bow", "quiver", { "single", "elite" } },
	criticalForce = { "Hunter", "longbow", "quiver", { "single", "group", "elite", "boss" } },
	easyPrey = { "Hunter", "crossbow", "quiver", { "controlled" } },
	bodkinBolt = { "Hunter", "heavycrossbow", "quiver", { "armored", "single" } },
	fullDraw = { "Hunter", "bow", "quiver", { "single", "group", "elite", "boss" } },
	elementalSpark = { "Mage", "wand", "orb", { "single", "group", "boss" } },
	elementalMight = { "Mage", "staff", false, { "single", "group", "boss" } },
	runicSeal = { "Mage", "runestaff", false, { "still", "boss" } },
	learnedFormulae = { "Mage", "wand", "tome", { "mana" } },
	powerLens = { "Mage", "wand", "orb", { "single", "group", "elite", "boss" } },
	anointment = { "Cleric", "scepter", "shield", { "dungeon" } },
	savingBlow = { "Cleric", "holystaff", false, { "solo" } },
	concussion = { "Cleric", "flail1h", "shield", { "group", "single" } },
	prosperity = { "Cleric", "scepter", "relic", {} },
} :: { [string]: { any } }

export type TraitRow = {
	traitId: string,
	classId: string,
	set: string,
	element: string?,
	values: { [string]: number }, -- situation (or "mix") -> traitValue; NaN outside the trait's situations
	setNoTraits: number, -- moc² in MIX of the set with its traits / with NO_TRAITS - 1 (both traits of the set)
	staty: number, -- STATY 14 starting estimate (Data/ItemWeights.traits pct / 100)
}

-- Gear options of a trait's set.
function Balance.traitGear(traitId: string, rarity: number, up: number, element: string?): (string, GearOpts)
	local spec = Balance.TRAIT_SETS[traitId]
	return spec[1] :: string,
		{ weapon = spec[2], offhand = spec[3], rarity = rarity, up = up, element = element } :: GearOpts
end

-- Every trait at `level` with `rarity` and `up` (24 rows, + one row per element of Spark and Might).
function Balance.traitTable(level: number, rarity: number, up: number): { TraitRow }
	local ItemWeights = require("../src/shared/Data/ItemWeights") :: any
	local out: { TraitRow } = {}
	local function row(traitId: string, element: string?)
		local classId, gear = Balance.traitGear(traitId, rarity, up, element)
		local spec = Balance.TRAIT_SETS[traitId]
		local values: { [string]: number } = {}
		for _, name in Balance.SITUATION_LIST do
			values[name] = if table.find(spec[4], name)
				then Balance.traitValue(classId, level, gear, traitId, name)
				else 0 / 0
		end
		values.mix = Balance.traitValue(classId, level, gear, traitId, "mix")
		local with = Balance.itemPlayer(classId, level, gear)
		local without = Balance.itemPlayer(classId, level, Balance.withOpts(gear, { traitScale = Balance.NO_TRAITS }))
		local weight = ItemWeights.traits[traitId]
		table.insert(out, {
			traitId = traitId,
			classId = classId,
			set = `{spec[2]}{if spec[3] then " + " .. spec[3] else ""}`,
			element = element,
			values = values,
			setNoTraits = (Balance.powerMix(with) / Balance.powerMix(without)) ^ 2 - 1,
			staty = if weight then weight.pct / 100 else 0 / 0,
		})
	end
	for _, def in ItemTraits.list do
		row(def.id)
		if def.id == "elementalSpark" or def.id == "elementalMight" then
			for _, element in ELEMENTS do
				row(def.id, element)
			end
		end
	end
	return out
end

-- G7: rarity gain (S84 C) --------------------------------------------------------------------------------------------

export type RarityGain = {
	s32: number, -- Balance.rarityGain (power without options)
	noTraits: number, -- trait model in `single`, NO_TRAITS on both sets
	traits: number, -- trait model in `single` (the G7 measure S87 asserts)
	baseOnly: number, -- the same without random bonuses (rarity baseMul and trait strength)
	linesOnly: number, -- traits - baseOnly
}

local rarityGains: { [string]: RarityGain } = {}
-- A full default set of `rarity` against Common, same ilvl (level - 2).
function Balance.rarityGainAt(classId: string, level: number, rarity: number, opts: { situation: string? }?): RarityGain
	local situation = (opts and opts.situation) or "single"
	local key = `{classId}|{level}|{rarity}|{situation}`
	local cached = rarityGains[key]
	if cached then
		return cached
	end
	local P: PowerOpts = { traits = true, situation = situation }
	local function gain(o: GearOpts?): number
		local common = Balance.itemPlayer(classId, level, o)
		local rare = Balance.itemPlayer(classId, level, Balance.withOpts(o, { rarity = rarity }))
		return Balance.power(rare, nil, P) / Balance.power(common, nil, P) - 1
	end
	local traits = gain(nil)
	local baseOnly = gain({ bonuses = false })
	local result: RarityGain = {
		s32 = Balance.rarityGain(classId, level, rarity),
		noTraits = gain({ traitScale = Balance.NO_TRAITS }),
		traits = traits,
		baseOnly = baseOnly,
		linesOnly = traits - baseOnly,
	}
	rarityGains[key] = result
	return result
end

-- G7 band of a rarity (low, high); Mythic: above the Legendary of the same class and level (no high).
function Balance.g7Band(classId: string, level: number, rarity: number): (number?, number?)
	if rarity == Rarities.UNIQUE then
		return 0.08, 0.15
	elseif rarity == Rarities.HEROIC then
		return 0.15, 0.25
	elseif rarity == Rarities.LEGENDARY then
		-- S134g (A2): Legendary = the Heroic of the same class and level x 1.02-1.08 in power (its edge is a skill
		-- effect, not stats; was 0.25-0.40, Hunter 0.43, with the legendary line)
		local heroic = Balance.rarityGainAt(classId, level, Rarities.HEROIC).traits
		return (1 + heroic) * 1.02 - 1, (1 + heroic) * 1.08 - 1
	end
	return Balance.rarityGainAt(classId, level, Rarities.LEGENDARY).traits, nil
end

-- G8: two-handed parity (S84 D) --------------------------------------------------------------------------------------

export type Parity = { mix: number, single: number, group: number, elite: number, boss: number, worst: number }

local parities: { [string]: Parity } = {}
-- moc² of the set with the two-handed `weapon` (no off-hand) / moc² of the reference (default LOADOUT, or opts.ref),
-- the whole set of `rarity` +`up`; opts.traits = false: NO_TRAITS on both. mix = (powerMix / powerMix)².
function Balance.twoHandedParity(
	classId: string,
	level: number,
	weapon: string,
	rarity: number,
	up: number,
	opts: { traits: boolean?, ref: { weapon: string, offhand: string }? }?
): Parity
	local o = opts or {}
	local scale = if o.traits == false then Balance.NO_TRAITS else nil
	local key = `{classId}|{level}|{weapon}|{rarity}|{up}|{o.traits}|{o.ref and o.ref.weapon}|{o.ref and o.ref.offhand}`
	local cached = parities[key]
	if cached then
		return cached
	end
	local two = Balance.itemPlayer(
		classId,
		level,
		{ weapon = weapon, offhand = false, rarity = rarity, up = up, traitScale = scale }
	)
	local ref = Balance.itemPlayer(classId, level, {
		weapon = o.ref and o.ref.weapon,
		offhand = o.ref and o.ref.offhand,
		rarity = rarity,
		up = up,
		traitScale = scale,
	})
	local result: any = { mix = (Balance.powerMix(two) / Balance.powerMix(ref)) ^ 2 }
	local worst = math.huge
	for _, name in { "single", "group", "elite", "boss" } do
		local P: PowerOpts = { traits = true, situation = name }
		local r = (Balance.power(two, nil, P) / Balance.power(ref, nil, P)) ^ 2
		result[name] = r
		worst = math.min(worst, r)
	end
	result.worst = worst
	parities[key] = result
	return result :: Parity
end

-- The S32 column of G8: (power / power)² without options (weaponScore and the diagnosis), the same rarity and upgrade.
function Balance.twoHandedS32(classId: string, level: number, weapon: string, rarity: number, up: number): number
	local two = Balance.itemPlayer(classId, level, { weapon = weapon, offhand = false, rarity = rarity, up = up })
	local ref = Balance.itemPlayer(classId, level, { rarity = rarity, up = up })
	return (Balance.power(two) / Balance.power(ref)) ^ 2
end

-- G8 band (0.97-1.035; the holy staff at +9 up to 1.06).
function Balance.g8Band(weapon: string, up: number): (number, number)
	return 0.97, if weapon == "holystaff" and up >= 9 then 1.06 else 1.035
end

-- G9: upgrades against income (S84 E) -------------------------------------------------------------------------------

local priceCache: { [string]: number }? = nil
-- Gold of one unit (goldEq): essence dust at the lowest merchant price (Data/Shops), shards and crystals by
-- transmutation and the protection scroll by its recipe (Data/Recipes: ingredients + gold), the rest (herbs) at
-- its Items price.
function Balance.materialPrices(): { [string]: number }
	if priceCache then
		return priceCache
	end
	local prices: { [string]: number } = {}
	local function shopPrice(id: string): number?
		local best: number? = nil
		for _, shopId in sortedKeys(Shops.byId) do
			for _, entry in (Shops.byId[shopId] :: any).entries do
				if entry.item == id and entry.price then
					best = math.min(best or math.huge, entry.price)
				end
			end
		end
		return best
	end
	local function price(id: string): number
		local known = prices[id]
		if known then
			return known
		end
		local value = shopPrice(id)
		if not value then
			for _, recipe in Recipes.list do
				if recipe.result.id == id and recipe.group ~= "blessing" then
					local sum = recipe.gold
					for _, ingredient in recipe.ingredients do
						sum += ingredient.n * price(ingredient.id)
					end
					value = sum / recipe.result.n
					break
				end
			end
		end
		if not value then
			local def = Items.get(id) :: any
			value = if def then def.price or 0 else 0
		end
		prices[id] = value :: number
		return value :: number
	end
	for _, id in { "essence_dust", "essence_shard", "essence_crystal", "scroll_protection", "legend_core" } do
		price(id)
	end
	prices.legend_core = nil -- not sold: Legend Cores stay outside goldEq
	priceCache = prices
	return prices
end

export type UpgradePlan = {
	gold: number,
	attempts: number,
	scrolls: number, -- protection scrolls (one per attempt of a step below 100 %)
	materials: { [string]: number }, -- essences (not Legend Cores)
	cores: number, -- Legend Cores
	scrollGold: number,
	materialGold: number,
	goldEq: number, -- gold + scrollGold + materialGold (Legend Cores outside)
}

-- Expected cost of `item` from +0 to +`to` on Upgrade.cost and Upgrade.chance only. protect: step n takes 1 / p_n
-- attempts and a scroll on each attempt of a step below 100 % (BlacksmithService takes the scroll on every protected
-- attempt); without: a failure drops one level, T_k = (c_k + (1 - p_k) T_(k-1)) / p_k for gold, attempts and every
-- material. The Legend Core threshold comes from Upgrade.cost; opts.coreFrom (report for S87) moves it by rewriting
-- only the result of Upgrade.cost here (no data changes).
function Balance.upgradePlan(item: any, to: number, protect: boolean, opts: { coreFrom: number? }?): UpgradePlan
	local coreFrom = opts and opts.coreFrom
	local function costOf(n: number): Upgrade.Cost
		local cost = Upgrade.cost(item, n)
		if not coreFrom then
			return cost
		end
		local materials = {}
		for _, mat in cost.materials do
			if mat.id ~= "legend_core" then
				table.insert(materials, mat)
			end
		end
		if n >= coreFrom and Rarities.get(item.rarity).legendCore then
			table.insert(materials, { id = "legend_core", n = 1 })
		end
		return { gold = cost.gold, materials = materials }
	end
	local gold, attempts, scrolls, cores = 0, 0, 0, 0
	local materials: { [string]: number } = {}
	local function addMaterial(id: string, n: number)
		if id == "legend_core" then
			cores += n
		else
			materials[id] = (materials[id] or 0) + n
		end
	end
	if protect then
		for n = 1, to do
			local cost = costOf(n)
			local p = Upgrade.chance(n) / 100
			gold += cost.gold / p
			attempts += 1 / p
			if p < 1 then
				scrolls += 1 / p
			end
			for _, mat in cost.materials do
				addMaterial(mat.id, mat.n / p)
			end
		end
	else
		local previous: { [string]: number } = {}
		for k = 1, to do
			local cost = costOf(k)
			local p = Upgrade.chance(k) / 100
			local step: { [string]: number } = { gold = cost.gold, attempts = 1 }
			for _, mat in cost.materials do
				step[mat.id] = (step[mat.id] or 0) + mat.n
			end
			local keys: { [string]: boolean } = {}
			for id in step do
				keys[id] = true
			end
			for id in previous do
				keys[id] = true
			end
			local T: { [string]: number } = {}
			for _, id in sortedKeys(keys) do
				local value = ((step[id] or 0) + (1 - p) * (previous[id] or 0)) / p
				T[id] = value
				if id == "gold" then
					gold += value
				elseif id == "attempts" then
					attempts += value
				else
					addMaterial(id, value)
				end
			end
			previous = T
		end
	end
	local prices = Balance.materialPrices()
	local materialGold = 0
	for _, id in sortedKeys(materials) do
		materialGold += materials[id] * (prices[id] or 0)
	end
	local scrollGold = scrolls * prices.scroll_protection
	return {
		gold = gold,
		attempts = attempts,
		scrolls = scrolls,
		materials = materials,
		cores = cores,
		scrollGold = scrollGold,
		materialGold = materialGold,
		goldEq = gold + scrollGold + materialGold,
	}
end

local incomes: { [string]: number } = {}
-- Gold of a level for G9 (S84): kill gold + drop sales per hour (economyAt) x the hours of the level, with the quest
-- gold of its band (BANDS, questsAt without bosses) spread over the band's levels by the EXP they need, like the S32
-- income (questRewards) and the diagnosis. S103: the hours from the kills of the pace window model (see below).
function Balance.levelIncome(classId: string, level: number): number
	local key = `{classId}|{level}`
	local cached = incomes[key]
	if cached then
		return cached
	end
	local band = Balance.BANDS[Balance.regionAt(level)]
	local gold, need = 0, 0
	for l = band[1], band[2] - 1 do
		gold += Balance.questsAt(l).gold
		need += Exp.expToNext(l)
	end
	local share = Exp.expToNext(level) / math.max(1, need)
	local e = Balance.economyAt(classId, level)
	-- S103: the kills of the level are those of the pace window model (the EXP left after the quest credit of its
	-- window, Balance.questCreditByLevel), the same the S98 compensation keeps per level; the band average of the
	-- quest EXP (`exp * share`, S84) read a band whose story moved its EXP between levels (chapter II: 27.5% -> 10% of
	-- the band, the monsters' multiplier up on 21-36) as 34% more kills on level 20.
	local kills = creditRows({})[level].need / e.pace.expPerKill
	local income = e.incomePerHour * kills * e.pace.secondsPerKill / 3600 + gold * share
	incomes[key] = income
	return income
end

export type UpgradeIncome = {
	classId: string,
	level: number,
	income: number, -- gold of the level (Balance.levelIncome)
	up3: number, -- +1..+3 of the weapon (gold, failures repeat the step) / income
	up6: number,
	up9: number, -- +1..+9 with protection, gold only, in levels of income (G9)
	up9Unprotected: number,
	set9Unprotected: number, -- the whole set (10 items) +9 without protection
	goldEq9: number, -- +1..+9 with protection: gold + scrolls + materials, in levels of income
	scrolls9: number,
}

local upgradeIncomes: { [number]: { UpgradeIncome } } = {}
-- The class's default weapon of ilvl level - 2 against the gold of the level (levelIncome, gross like the S32 income:
-- potions apart).
function Balance.upgradeVsIncome(level: number): { UpgradeIncome }
	local cached = upgradeIncomes[level]
	if cached then
		return cached
	end
	local out: { UpgradeIncome } = {}
	local ilvl = math.max(1, level - Balance.GEAR_GAP)
	for _, c in Balance.CLASSES do
		local item = makeItem(tierId(Balance.LOADOUT[c].weapon, ilvl), ilvl, Rarities.COMMON, 0, {})
		local income = math.max(1e-9, Balance.levelIncome(c, level))
		local p9 = Balance.upgradePlan(item, 9, true)
		local u9 = Balance.upgradePlan(item, 9, false)
		local setSize = 2 + #Balance.ARMOR_SLOTS + #Balance.JEWELLERY
		table.insert(out, {
			classId = c,
			level = level,
			income = income,
			up3 = Balance.upgradePlan(item, 3, true).gold / income,
			up6 = Balance.upgradePlan(item, 6, true).gold / income,
			up9 = p9.gold / income,
			up9Unprotected = u9.gold / income,
			set9Unprotected = setSize * u9.gold / income,
			goldEq9 = p9.goldEq / income,
			scrolls9 = p9.scrolls,
		})
	end
	upgradeIncomes[level] = out
	return out
end

-- Mounts (S97) ------------------------------------------------------------------------------------------------------

export type MountMaterial = { id: string, n: number, kills: number, kind: string? }
export type MountUpgrade = {
	to: number, -- mount level after the step
	level: number, -- character level needed
	gold: number,
	income: number, -- gold of a level at `level` (Balance.levelIncome, mean of the classes)
	share: number, -- gold / income
	speedMul: number,
	mountTime: number,
	mats: { MountMaterial },
}

-- The kind of the band around `level` (levels overlapping level - 10 .. level + 10, normal variant) that drops the most
-- of `id` per kill (Balance.materialsPerKill mirrors the LootTables.PARTS roll), and how much.
local function bestPartKind(id: string, level: number): (string?, number)
	local best, bestKind = 0, nil
	for _, def in Monsters.list do
		if def.levels.min <= level + 10 and def.levels.max >= level - 10 then
			local per = Balance.materialsPerKill(def.id, "normal")[id] or 0
			if per > best then
				best, bestKind = per, def.id
			end
		end
	end
	return bestKind, best
end

-- Every step of Data/Mounts.UPGRADE against the gold of the level it needs (the same income as G9 of S84) and the kills
-- its parts take from the best kind of that band.
function Balance.mountUpgrades(): { MountUpgrade }
	local out: { MountUpgrade } = {}
	for to = 2, Config.Mount.maxLevel do
		local step = MountData.UPGRADE[to]
		local income = 0
		for _, c in Balance.CLASSES do
			income += Balance.levelIncome(c, step.level)
		end
		income = math.max(1e-9, income / #Balance.CLASSES)
		local mats: { MountMaterial } = {}
		for _, m in step.materials do
			local kind, per = bestPartKind(m.id, step.level)
			table.insert(mats, {
				id = m.id,
				n = m.n,
				kind = kind,
				kills = if per > 0 then math.ceil(m.n / per) else math.huge,
			})
		end
		table.insert(out, {
			to = to,
			level = step.level,
			gold = step.gold,
			income = income,
			share = step.gold / income,
			speedMul = MountLogic.speedMul(to),
			mountTime = MountLogic.mountTime(to),
			mats = mats,
		})
	end
	return out
end

export type MountDrop = { boss: string, mount: string?, mountChance: number, kills: number, days: number }

-- The boss mounts (Data/Mounts.BOSS_DROPS): expected kills and days at the daily limit of kills.
function Balance.mountDrops(): { MountDrop }
	local out: { MountDrop } = {}
	for _, bossId in LootTables.regionBoss do
		local drop = MountData.BOSS_DROPS[bossId]
		if drop and drop.mountChance then
			local kills = MountLogic.expectedKills(drop.mountChance)
			table.insert(out, {
				boss = bossId,
				mount = drop.mount,
				mountChance = drop.mountChance,
				kills = kills,
				days = kills / Config.Boss.dailyRuns,
			})
		end
	end
	return out
end

-- Materials (S84 F) -------------------------------------------------------------------------------------------------

Balance.ESSENCES = { "essence_dust", "essence_shard", "essence_crystal", "scroll_protection", "legend_core" }

local function addExpected(list: { any }, mul: number, into: { [string]: number })
	for _, drop in list do
		into[drop.id] = (into[drop.id] or 0) + (drop.chance or 1) * (drop.min + drop.max) / 2 * mul
	end
end

-- Expected materials of one kill of `kind` (mirrors Loot.rollMonsterLoot: the kind's table + the variant's, x the
-- area's materialMul `mul`, default 1).
function Balance.materialsPerKill(kind: string, variant: string, mul: number?): { [string]: number }
	local def = Monsters.get(kind) :: any
	local tableDef = LootTables.byId[def.lootTable]
	local out: { [string]: number } = {}
	addExpected(tableDef.materials, mul or 1, out)
	addExpected(tableDef.variantMaterials[variant] or {}, mul or 1, out)
	return out
end

-- Expected materials of dismantling one dropped +0 item of `variant` (rarity weights; the expected value of
-- Logic/Dismantle.roll: Rarities dismantle, chance x mean amount); `dropFactor` = the region's (S87, default 1).
function Balance.dismantlePerItem(variant: string, topTierMul: number?, dropFactor: number?): { [string]: number }
	local weights = ItemRoll.rarityWeights(variant, topTierMul, dropFactor)
	local total = 0
	for _, w in weights do
		total += w
	end
	local out: { [string]: number } = {}
	for _, rarity in sortedKeys(weights) do
		addExpected(Rarities.get(rarity).dismantle, weights[rarity] / total, out)
	end
	return out
end

export type CaveSpawners = {
	id: string,
	levels: { number },
	q: number, -- share of Elite spawners with two members
	elites: { { kind: string, min: number, max: number } },
	elite2: { min: number, max: number }?, -- S134h: the range over the cave'"'"'s Elite II spawners
	elite2s: { { kind: string, min: number, max: number } }, -- S134h: every Elite II spawner (A, then B)
}

local caveSpawnerCache: { [string]: { CaveSpawners } } = {}
-- The caves of a region from Data/Spawns (Elite kinds with their spawner levels, the Elite II spawner, q pairs).
function Balance.caveSpawners(mapId: string): { CaveSpawners }
	local cached = caveSpawnerCache[mapId]
	if cached then
		return cached
	end
	local out: { CaveSpawners } = {}
	for _, cave in Areas.caves.list do
		if cave.region == mapId then
			local groups, paired = 0, 0
			local elites = {}
			local elite2: { min: number, max: number }? = nil
			local elite2s = {}
			for _, s in Spawns.byMap[cave.id] or {} do
				if s.variant == "elite" then
					groups += 1
					paired += if s.count >= 2 then 1 else 0
					local known = false
					for _, e in elites do
						known = known or e.kind == s.monster
					end
					if not known then
						table.insert(elites, { kind = s.monster, min = s.level.min, max = s.level.max })
					end
				elseif s.variant == "elite2" then
					table.insert(elite2s, { kind = s.monster, min = s.level.min, max = s.level.max })
					local e = elite2
					elite2 = if e
						then { min = math.min(e.min, s.level.min), max = math.max(e.max, s.level.max) }
						else { min = s.level.min, max = s.level.max }
				end
			end
			table.insert(out, {
				id = cave.id,
				levels = cave.levels,
				q = if groups > 0 then paired / groups else 0,
				elites = elites,
				elite2 = elite2,
				elite2s = elite2s,
			})
		end
	end
	caveSpawnerCache[mapId] = out
	return out
end

-- The cave of regionAt(level) whose Elite spawners hold the level, else the one nearest to it.
function Balance.caveAt(level: number): CaveSpawners
	local best, bestGap = nil, math.huge
	for _, cave in Balance.caveSpawners(Balance.REGION_IDS[Balance.regionAt(level)]) do
		if #cave.elites > 0 then
			local low, high = math.huge, -math.huge
			for _, e in cave.elites do
				low, high = math.min(low, e.min), math.max(high, e.max)
			end
			local gap = math.max(low - level, level - high, 0)
			if gap < bestGap then
				best, bestGap = cave, gap
			end
		end
	end
	return best :: CaveSpawners
end

local eliteRates: { [string]: number } = {}
-- Cave Elites per hour at `level`: 3600 (1 + q) / ((1 - q) t1 + q t2), t1 / t2 = a single / a pair of the cave's
-- Elite kinds (mean) with the rest from regeneration, BREAK and WALK (like paceAt); a pair is two kills.
function Balance.elitesPerHour(classId: string, level: number): (number, CaveSpawners)
	local cave = Balance.caveAt(level)
	local key = `{classId}|{level}`
	local cached = eliteRates[key]
	if cached then
		return cached, cave
	end
	local p = Balance.cachedPlayer(classId, level)
	local regen = Stats.Formula.hpRegenPct / 100
	local free = Balance.BREAK + Balance.WALK
	local t1, t2 = 0, 0
	for _, e in cave.elites do
		local def = Monsters.get(e.kind) :: any
		local single = Balance.elite(p, def, level)
		local pair = Balance.groupFight(p, FightSim.group(def, level, 2, "elite"))
		t1 += single.seconds + single.hpLost / regen + free
		t2 += pair.seconds + pair.hpLost / regen + free
	end
	t1 /= #cave.elites
	t2 /= #cave.elites
	local q = cave.q
	local rate = 3600 * (1 + q) / ((1 - q) * t1 + q * t2)
	eliteRates[key] = rate
	return rate, cave
end

-- Upgrade materials of one weapon and of a full set to +6 and +9 (Heroic and Legendary, with and without protection),
-- plus the shards of the protection scrolls (their recipe).
export type MaterialNeed = {
	label: string,
	dust: number,
	shards: number,
	crystals: number,
	cores: number,
	scrolls: number,
	scrollShards: number,
}
function Balance.materialDemand(): { MaterialNeed }
	local out: { MaterialNeed } = {}
	local scroll = Recipes.get("scroll_protection") :: Recipes.Recipe
	local scrollShards = 0
	for _, ingredient in scroll.ingredients do
		if ingredient.id == "essence_shard" then
			scrollShards += ingredient.n / scroll.result.n
		end
	end
	for _, rarity in { Rarities.HEROIC, Rarities.LEGENDARY } do
		local item = makeItem("sword1h_1", 50, rarity, 0, {})
		for _, spec in
			{
				{ "broń", 1 },
				{ "zestaw z jednoręczną", 2 + #Balance.ARMOR_SLOTS + #Balance.JEWELLERY },
				{ "zestaw z dwuręczną", 1 + #Balance.ARMOR_SLOTS + #Balance.JEWELLERY },
			}
		do
			for _, to in { 6, 9 } do
				for _, protect in { true, false } do
					local plan = Balance.upgradePlan(item, to, protect)
					local n = spec[2] :: number
					local label = `{Rarities.get(rarity).key} · {spec[1]} · +{to} · {if protect
						then "z ochroną"
						else "bez ochrony"}`
					table.insert(out, {
						label = label,
						dust = n * (plan.materials.essence_dust or 0),
						shards = n * (plan.materials.essence_shard or 0),
						crystals = n * (plan.materials.essence_crystal or 0),
						cores = n * plan.cores,
						scrolls = n * plan.scrolls,
						scrollShards = n * plan.scrolls * scrollShards,
					})
				end
			end
		end
	end
	return out
end

export type MaterialSupply = {
	level: number,
	killsPerHour: number,
	elitesPerHour: number,
	normal: { [string]: number }, -- per hour of grinding: kill materials + dismantled drops
	elite: { [string]: number }, -- per hour of cave Elites
	elite2: { [string]: number }, -- per Elite II kill (materials + dismantled drops; S134h: the mean of the cave's two)
	elite2PerHour: number, -- Elite II kills per hour of a cave (S134h: both spawners, AreaSpawns.elite2Respawn)
	bossWeek: { [string]: number }, -- Config.Boss.dailyRuns x 7 kills of the region boss (materials only)
}

-- Materials per hour of `classId` at `level` (expected values; paceAt and elitesPerHour of the same level).
function Balance.materialSupply(classId: string, level: number): MaterialSupply
	local mods = Balance.dropMods(Balance.REGION_IDS[Balance.regionAt(level)])
	local factor = Balance.dropFactorAt(level)
	local pace = Balance.paceAt(classId, level)
	local kills = 3600 / pace.secondsPerKill
	local normal: { [string]: number } = {}
	for id, n in Balance.materialsPerKill(pace.kind, "normal", mods.materialMul) do
		normal[id] = n * kills
	end
	local items = AreaRates.itemsPerKill("normal", mods, 0, factor) * kills
	for id, n in Balance.dismantlePerItem("normal", nil, factor) do
		normal[id] = (normal[id] or 0) + n * items
	end
	local eph, cave = Balance.elitesPerHour(classId, level)
	local eliteKind = cave.elites[1].kind
	local elite: { [string]: number } = {}
	for id, n in Balance.materialsPerKill(eliteKind, "elite", mods.materialMul) do
		elite[id] = n * eph
	end
	local eliteItems = AreaRates.itemsPerKill("elite", mods, 0, factor) * eph
	for id, n in Balance.dismantlePerItem("elite", nil, factor) do
		elite[id] = (elite[id] or 0) + n * eliteItems
	end
	-- S134h: the mean kill of the cave'"'"'s Elite IIs (Balance.elite2Seat: their own slot groups, materials and
	-- dismantling) and the kills per hour of all of them (two spawners, each with its respawn)
	local elite2: { [string]: number } = {}
	local elite2PerHour = 0
	for _, e in cave.elite2s do
		local seat = Balance.elite2Seat(classId, e.kind, e.max, { mods = mods })
		for id, n in seat.materials do
			elite2[id] = (elite2[id] or 0) + n / #cave.elite2s
		end
		local respawn = AreaSpawns.elite2Respawn(e.max)
		elite2PerHour += 3600 / ((respawn.min + respawn.max) / 2)
	end
	local bossId = LootTables.regionBoss[Balance.regionAt(level)]
	local bossWeek: { [string]: number } = {}
	addExpected(LootTables.bosses[bossId].materials, Config.Boss.dailyRuns * 7, bossWeek)
	return {
		level = level,
		killsPerHour = kills,
		elitesPerHour = eph,
		normal = normal,
		elite = elite,
		elite2 = elite2,
		elite2PerHour = elite2PerHour,
		bossWeek = bossWeek,
	}
end

-- Hours of a source to gather `need` (dust, shards, crystals) with transmutation (Data/Recipes: 10 dust -> shard,
-- 8 shards -> crystal, each from its recipe level): dust equivalents; below the crystal recipe the crystals come
-- only from drops. NaN when the source never gives a needed material.
function Balance.materialHours(need: MaterialNeed, perHour: { [string]: number }, level: number): number
	local shardRecipe = Recipes.get("transmute_shard") :: Recipes.Recipe
	local crystalRecipe = Recipes.get("transmute_crystal") :: Recipes.Recipe
	local dustPerShard = shardRecipe.ingredients[1].n / shardRecipe.result.n
	local shardsPerCrystal = crystalRecipe.ingredients[1].n / crystalRecipe.result.n
	local d, s, c = perHour.essence_dust or 0, perHour.essence_shard or 0, perHour.essence_crystal or 0
	local shardsNeed = need.shards + need.scrollShards
	local function per(amount: number, rate: number): number
		if amount <= 0 then
			return 0
		end
		return if rate > 0 then amount / rate else 0 / 0
	end
	local function maxOf(a: number, b: number): number
		return if a ~= a or b ~= b then 0 / 0 else math.max(a, b)
	end
	if level < shardRecipe.level then
		return maxOf(maxOf(per(need.dust, d), per(shardsNeed, s)), per(need.crystals, c))
	end
	local function eq(dust: number, shards: number, crystals: number, withCrystal: boolean): number
		return dust + dustPerShard * shards + (if withCrystal then dustPerShard * shardsPerCrystal * crystals else 0)
	end
	if level >= crystalRecipe.level then
		return per(eq(need.dust, shardsNeed, need.crystals, true), eq(d, s, c, true))
	end
	return maxOf(per(eq(need.dust, shardsNeed, 0, false), eq(d, s, 0, false)), per(need.crystals, c))
end

-- Item level gaps and longevity (S84 G) -----------------------------------------------------------------------------

export type IlvlGap = {
	level: number,
	normal: number, -- level - mean ilvl of a normal monster of the level (ItemRoll.dropLevelRange)
	eliteSpawner: number, -- the highest Elite spawner level <= level (any cave up to this region), NaN = none
	elite: number, -- level - mean ilvl of its drop (Loot.dropBaseLevel)
	elite2Spawner: number,
	elite2: number,
	boss: number, -- level - the level of the last boss at or below the level (Legendary / Mythic at the boss level)
}

-- Gaps between the player's level and the item level of each source, every level of the region's band.
function Balance.ilvlGaps(region: number): { IlvlGap }
	local band = Balance.BANDS[region]
	local last = if region == #Balance.BANDS then band[2] else band[2] - 1
	local elites, elite2s = {}, {}
	for r = 1, region do
		for _, cave in Balance.caveSpawners(Balance.REGION_IDS[r]) do
			for _, e in cave.elites do
				table.insert(elites, e)
			end
			if cave.elite2 then
				table.insert(elite2s, cave.elite2)
			end
		end
	end
	local function meanDrop(level: number, variant: string, cap: number): number
		local base = Loot.dropBaseLevel(level, variant, cap)
		local low, high = ItemRoll.dropLevelRange(base, variant)
		return (low + high) / 2
	end
	-- the best spawner level <= L among `ranges`, the mean ilvl of its drop
	local function best(ranges: { any }, L: number, variant: string): (number, number)
		local top, cap = 0 / 0, 0
		for _, range in ranges do
			if range.min <= L then
				local s = math.min(L, range.max)
				if top ~= top or s > top then
					top, cap = s, range.max
				end
			end
		end
		if top ~= top then
			return 0 / 0, 0 / 0
		end
		local add = (Combat.variants :: any)[variant].levelAdd
		return top, L - meanDrop(top + add, variant, cap)
	end
	local out: { IlvlGap } = {}
	for L = band[1], last do
		local low, high = ItemRoll.dropLevelRange(L, "normal")
		local eliteSpawner, eliteGap = best(elites, L, "elite")
		local elite2Spawner, elite2Gap = best(elite2s, L, "elite2")
		local boss = 0 / 0
		for _, def in Bosses.list do
			if def.level <= L and (boss ~= boss or L - def.level < boss) then
				boss = L - def.level
			end
		end
		table.insert(out, {
			level = L,
			normal = L - (low + high) / 2,
			eliteSpawner = eliteSpawner,
			elite = eliteGap,
			elite2Spawner = elite2Spawner,
			elite2 = elite2Gap,
			boss = boss,
		})
	end
	return out
end

-- P2 (diag_longevity): the highest level up to which a full set of `rarity` with item level `ilvl` keeps at least
-- the power (S32) of a set of rarity - 1 at level - 2 (the drops of that level).
function Balance.longevity(classId: string, rarity: number, ilvl: number): number
	local last = ilvl + Balance.GEAR_GAP
	for L = ilvl + Balance.GEAR_GAP, 100 do
		local old = Balance.power(Balance.itemPlayer(classId, L, { ilvl = ilvl, rarity = rarity }))
		local new = Balance.power(Balance.itemPlayer(classId, L, { rarity = rarity - 1 }))
		if old < new then
			break
		end
		last = L
	end
	return last
end

-- Drops per hour with luck (S84 H) ----------------------------------------------------------------------------------

-- Hunting ground multipliers of a region's drops: AreaProfiles.NEUTRAL. The region's LevelCurves.dropFactor goes
-- next to them as the dropFactor argument (Balance.dropFactorAt, S87 C4), as in Loot.rollMonsterLoot.
function Balance.dropMods(_region: string): AreaProfiles.Mods
	return AreaProfiles.NEUTRAL
end

local fortunes: { [string]: { [string]: number } } = {}
-- Raw luck fields of the Priest of Fortune (Paths.luckOfNodes of the luck nodes of the `fortune` path at their top
-- rank); "start" = only the rows open outside the main path (PathData.DIP_ROWS).
function Balance.fortuneLuck(kind: "full" | "start"): { [string]: number }
	local cached = fortunes[kind]
	if cached then
		return cached
	end
	local path = PathData.byId.fortune :: any
	local active = {}
	for r, row in path.rows do
		if kind == "full" or r <= PathData.DIP_ROWS then
			for _, node in row.nodes do
				if node.luck then
					table.insert(active, { node = node, path = path, row = r, rank = node.maxRank, scale = 1 })
				end
			end
		end
	end
	local luck = Paths.luckOfNodes(active :: any)
	fortunes[kind] = luck
	return luck
end

export type LuckProfile = {
	id: string,
	dropBonus: number, -- the player's dropBonus (Luck Member.dropBonus)
	lines: number, -- dropBonus lines of the jewellery
	legendary: number, -- leg_dropBonus lines
	blessing: number,
	guild: number,
	relic: number, -- Prosperity of the relic (ItemRoll.trait)
}

-- A profile of LUCK_PROFILES at `level`: every number from the data.
function Balance.luckProfile(id: string, level: number): LuckProfile
	local spec: any = nil
	for _, p in Balance.LUCK_PROFILES do
		if p.id == id then
			spec = p
		end
	end
	assert(spec, `Balance: unknown luck profile {id}`)
	local ilvl = math.max(1, level - Balance.GEAR_GAP)
	local lines, legendary, blessing, guild, relic = 0, 0, 0, 0, 0
	if spec.jewellery == "heroic" then
		for _, slot in Balance.JEWELLERY do
			for _, line in expectedBonuses(tierId(slot, ilvl), ilvl, Rarities.HEROIC, "Cleric") do
				if line.stat == "dropBonus" then
					lines += line.v
				end
			end
		end
	elseif spec.jewellery == "legendary" then
		lines = #Balance.JEWELLERY * ItemRoll.rollBonusValue("dropBonus", ilvl, Rarities.LEGENDARY, 0.5)
	elseif spec.jewellery == "mythic" then
		lines = #Balance.JEWELLERY * ItemRoll.rollBonusValue("dropBonus", ilvl, Rarities.MYTHIC, 1)
	end
	-- S134g: no item rolls leg_dropBonus any more (Legendary and Mythic roll skill effects); `legendary` stays 0
	if spec.blessing then
		local def = Blessings.of("fortune", spec.blessing) :: any
		blessing = def.stats.dropBonus or 0
	end
	if spec.guild then
		guild = spec.guild * (GuildSkills.byId.luck :: any).perLevel
	end
	if spec.relic then
		local item = makeItem(tierId("relic", ilvl), ilvl, spec.relic.rarity, spec.relic.up, {})
		local trait = ItemRoll.trait(item)
		relic = if trait then trait.value else 0
	end
	return {
		id = id,
		dropBonus = lines + legendary + blessing + guild + relic,
		lines = lines,
		legendary = legendary,
		blessing = blessing,
		guild = guild,
		relic = relic,
	}
end

-- Monster luck of a party: the player with the profile's dropBonus, plus a Priest of Fortune ("full" / "start")
-- as a second Member with luck, as LootService passes them (Logic/Luck.monster caps; the model never does).
function Balance.monsterLuck(profileId: string, level: number, fortune: ("full" | "start")?): Luck.MonsterLuck
	local members: { Luck.Member } =
		{ { name = "player", dropBonus = Balance.luckProfile(profileId, level).dropBonus } }
	if fortune then
		table.insert(members, { name = "fortune", luck = Balance.fortuneLuck(fortune) })
	end
	return Luck.monster(members)
end

local slotTierCache: { [string]: { [number]: { string } } }? = nil
-- mirrors Logic/Loot SLOT_TIER (local there): equipment definitions by slot group and tier, named items excluded.
local function slotTiers(): { [string]: { [number]: { string } } }
	if slotTierCache then
		return slotTierCache
	end
	local out: { [string]: { [number]: { string } } } = {}
	for id, def in Items.byId do
		if def.category == "equipment" and def.slot and def.tier and not def.fixedBonuses then
			out[def.slot] = out[def.slot] or {}
			out[def.slot][def.tier] = out[def.slot][def.tier] or {}
			table.insert(out[def.slot][def.tier], id)
		end
	end
	slotTierCache = out
	return out
end

-- Expected share of the items Loot.pickItem gives that `classId` can wear (slot from the weights, candidates of the
-- tier of `ilvl`, with `classBias` only the class's items; a slot without candidates gives nothing).
function Balance.usableShare(
	slotWeights: { [string]: number },
	ilvl: number,
	classBias: number,
	classId: string
): number
	local tiers = slotTiers()
	local tier = Items.generate.tierFor(ilvl)
	local total = 0
	for _, w in slotWeights do
		total += w
	end
	local sum = 0
	for _, slot in sortedKeys(slotWeights) do
		local candidates = tiers[slot] and tiers[slot][tier]
		if candidates and #candidates > 0 then
			local usable = 0
			for _, id in candidates do
				local def = Items.get(id) :: any
				if def.classes == nil or table.find(def.classes, classId) then
					usable += 1
				end
			end
			local share = (if usable > 0 then classBias else 0) + (1 - classBias) * usable / #candidates
			sum += slotWeights[slot] / total * share
		end
	end
	return sum
end

-- usableShare over the item levels of a drop of base level `level` (ItemRoll.dropLevelRange, uniform).
local function usableAt(slotWeights: { [string]: number }, level: number, classBias: number, classId: string): number
	local low, high = ItemRoll.dropLevelRange(level)
	local sum = 0
	for ilvl = low, high do
		sum += Balance.usableShare(slotWeights, ilvl, classBias, classId)
	end
	return sum / (high - low + 1)
end
Balance.usableAt = usableAt

export type Drops = {
	unique: number, -- Uniques for the class per hour of grinding (paceAt)
	heroic: number, -- Heroics for the class per hour of cave Elites (elitesPerHour)
	legendaryPerElite2: number, -- Legendaries for the class per Elite II kill (topTierMul x elite2Mul; S134h: the mean of
	-- the cave'"'"'s two, each with its own slot groups)
	killsPerHour: number,
	elitesPerHour: number,
	luck: Luck.MonsterLuck,
	beforeCap: number, -- personal + fortune
	capCut: number, -- points the monsterItemCap cut
	eliteCut: number, -- points of itemBonus above what the Elite's item chance can use (min(1, ...) in Loot)
}

local dropCache: { [string]: Drops } = {}
-- D5: drops per hour of `classId` at `level` with luck profile `profileId` and a Priest of Fortune (`fortune`).
function Balance.dropsPerHour(
	classId: string,
	level: number,
	profileId: string,
	fortune: ("full" | "start" | false)?
): Drops
	local factor = Balance.dropFactorAt(level)
	local key = `{classId}|{level}|{profileId}|{fortune}|{factor}`
	local cached = dropCache[key]
	if cached then
		return cached
	end
	local luck = Balance.monsterLuck(profileId, level, if fortune then fortune else nil)
	local mods = Balance.dropMods(Balance.REGION_IDS[Balance.regionAt(level)])
	local pace = Balance.paceAt(classId, level)
	local kills = 3600 / pace.secondsPerKill
	local normalTable = LootTables.byId[(Monsters.get(pace.kind) :: any).lootTable]
	local count, top = AreaRates.itemsPerKill("normal", mods, luck.itemBonus, factor)
	local unique = kills * count * top * usableAt(normalTable.slotWeights, level, normalTable.classBias, classId)
	local eph, cave = Balance.elitesPerHour(classId, level)
	local eliteTable = LootTables.byId[(Monsters.get(cave.elites[1].kind) :: any).lootTable]
	local eliteMax = -math.huge
	for _, e in cave.elites do
		eliteMax = math.max(eliteMax, e.max)
	end
	local eliteBase = Loot.dropBaseLevel(level + (Combat.variants :: any).elite.levelAdd, "elite", eliteMax)
	local eCount, eTop = AreaRates.itemsPerKill("elite", mods, luck.itemBonus, factor)
	local heroic = eph * eCount * eTop * usableAt(eliteTable.slotWeights, eliteBase, eliteTable.classBias, classId)
	local mods2 = table.clone(mods) :: any
	mods2.topTierMul = mods.topTierMul * luck.elite2Mul
	-- S134h: the mean of the cave'"'"'s Elite IIs (each with its own slot groups, Balance.elite2Seat)
	local legendary = 0
	for _, e in cave.elite2s do
		local seat = Balance.elite2Seat(classId, e.kind, level, { mods = mods2, itemBonus = luck.itemBonus })
		legendary += seat.legendary / #cave.elite2s
	end
	local eliteChance = Rarities.itemDrops.elite.chance * mods.itemChanceMul
	local result: Drops = {
		unique = unique,
		heroic = heroic,
		legendaryPerElite2 = legendary,
		killsPerHour = kills,
		elitesPerHour = eph,
		luck = luck,
		beforeCap = luck.personal + luck.fortune,
		capCut = luck.personal + luck.fortune - luck.itemBonus,
		eliteCut = math.max(0, luck.itemBonus - (1 / eliteChance - 1) * 100),
	}
	dropCache[key] = result
	return result
end

-- Elite II loot (S134h, docs/sessions/S134h.md C) -------------------------------------------------------------------
-- Every Elite II drops only its own 2-3 slot groups (LootTables.slotsFor) and every cave has two of them (spawners A and
-- B, each with its own respawn). The model per kill (elite2Seat) and per hour of a cave (elite2Cave) against the state
-- before the session (`legacy`: one spawner, DEFAULT_SLOTS, the old item count and materials), computed by the same
-- code: the targets of C2 are ratios new / legacy.

Balance.S134h = {
	-- the inputs as they were before S134h (one spawner per cave with its kinds picked on every respawn)
	legacy = {
		itemDrops = { chance = 1, min = 2, max = 3 },
		materials = {
			{ id = "essence_shard", chance = 0.8, min = 1, max = 3 },
			{ id = "essence_crystal", chance = 0.3, min = 1, max = 1 },
			{ id = "scroll_protection", chance = 0.08, min = 1, max = 1 },
		},
		-- the caves whose kinds changed (the others: cave.elite2)
		kinds = {
			ashen_mine = { "ashOrc" },
			ashen_lair = { "wyvern" },
			frostpeak_grotto = { "yeti" },
			frostpeak_hold = { "frozenKnight" },
		} :: { [string]: { string } },
	},
	ratio = { 0.85, 1.25 }, -- Heroics / Legendaries for the class per hour of a cave (mean of the 4 classes) / legacy
	classFloor = 0.6, -- a single class / legacy (report: it depends on the assigned groups)
	crystal = 1.25, -- crystal equivalents (shards in crystals, Data/Recipes) per hour of a cave / legacy, at most
	seatShare = 0.25, -- each Elite II: its best class gets at least this share of its items
}

export type Elite2Seat = {
	kind: string,
	items: number, -- items per kill
	usable: number, -- share of them for the class
	heroic: number, -- Heroics for the class per kill
	legendary: number, -- Legendaries for the class per kill
	crystals: number, -- crystal equivalents per kill (drops and the dismantled items)
	scrolls: number, -- protection scrolls per kill
	materials: { [string]: number }, -- every material per kill (drops and the dismantled items)
}

export type Elite2SeatOpts = {
	legacy: boolean?, -- the state before S134h (DEFAULT_SLOTS, Balance.S134h.legacy count and materials)
	mods: AreaProfiles.Mods?, -- default the region's (Balance.dropMods); luck: topTierMul x elite2Mul
	itemBonus: number?, -- % (Loot Modifiers.dropBonus)
}

-- Shards per crystal and dust per shard of the transmutation recipes (Data/Recipes).
local function crystalEquivalent(mats: { [string]: number }): number
	local crystalRecipe = Recipes.get("transmute_crystal") :: Recipes.Recipe
	local shardsPerCrystal = crystalRecipe.ingredients[1].n / crystalRecipe.result.n
	return (mats.essence_crystal or 0) + (mats.essence_shard or 0) / shardsPerCrystal
end

local seatCache: { [string]: Elite2Seat } = {}
-- S134h (C1): one kill of an Elite II of `kind` on a spawner of top level `level` for `classId` (expected values,
-- mirrors Loot.rollMonsterLoot: item count, rarity, the slot groups and the class bias, materials, dismantling).
function Balance.elite2Seat(classId: string, kind: string, level: number, opts: Elite2SeatOpts?): Elite2Seat
	local legacy = opts ~= nil and opts.legacy == true
	local def = Monsters.get(kind) :: any
	local mods = (opts and opts.mods) or Balance.dropMods(def.region)
	local bonus = (opts and opts.itemBonus) or 0
	local key = `{classId}|{kind}|{level}|{legacy}|{mods.topTierMul}|{mods.itemChanceMul}|{mods.materialMul}|{bonus}`
	local cached = seatCache[key]
	if cached then
		return cached
	end
	local factor = LevelCurves.dropFactor(def.region)
	local drops = if legacy then Balance.S134h.legacy.itemDrops else Rarities.itemDrops.elite2
	local chance = math.min(1, drops.chance * (1 + bonus / 100) * mods.itemChanceMul)
	local items = chance * ((drops.min + drops.max) / 2 + ((drops :: any).extra or 0))
	local weights = ItemRoll.rarityWeights("elite2", mods.topTierMul, factor)
	local total = 0
	for _, w in weights do
		total += w
	end
	local tableDef = LootTables.byId[def.lootTable]
	local slots = if legacy then LootTables.defaultSlots else LootTables.slotsFor(kind, "elite2")
	local usable = usableAt(slots, level, tableDef.classBias, classId)
	local mats: { [string]: number } = {}
	addExpected(tableDef.materials, mods.materialMul, mats)
	addExpected(
		if legacy then Balance.S134h.legacy.materials else tableDef.variantMaterials.elite2 or {},
		mods.materialMul,
		mats
	)
	for id, n in Balance.dismantlePerItem("elite2", mods.topTierMul, factor) do
		mats[id] = (mats[id] or 0) + n * items
	end
	local seat: Elite2Seat = {
		kind = kind,
		items = items,
		usable = usable,
		heroic = items * (weights[Rarities.HEROIC] or 0) / total * usable,
		legendary = items * (weights[Rarities.LEGENDARY] or 0) / total * usable,
		crystals = crystalEquivalent(mats),
		scrolls = mats.scroll_protection or 0,
		materials = mats,
	}
	seatCache[key] = seat
	return seat
end

export type Elite2Cave = {
	caveId: string,
	kills: number, -- Elite II kills per hour (every spawner killed as soon as it is back)
	items: number,
	heroic: number,
	legendary: number,
	crystals: number,
	scrolls: number,
	seats: { { seat: Elite2Seat, perHour: number } },
}

-- The Elite II spawners of a cave (Data/Spawns): kind, top level, respawn window.
local function elite2Spawners(
	caveId: string
): { { kind: string, level: number, respawn: { min: number, max: number } } }
	local out = {}
	for _, s in Spawns.byMap[caveId] or {} do
		if s.variant == "elite2" then
			table.insert(out, { kind = s.monster, level = s.level.max, respawn = s.respawn })
		end
	end
	return out
end
Balance.elite2Spawners = elite2Spawners

-- S134h (C1): an hour of a cave's Elite IIs for `classId` (each spawner killed as soon as it is back: 3600 / the mean
-- of its respawn window). `opts.legacy`: the state before S134h (the first spawner only, its kind picked among the
-- legacy kinds on every respawn, DEFAULT_SLOTS and the old count and materials).
function Balance.elite2Cave(classId: string, caveId: string, opts: Elite2SeatOpts?): Elite2Cave
	local cave = assert(Areas.caves.get(caveId), caveId)
	local spawners = elite2Spawners(caveId)
	local legacy = opts ~= nil and opts.legacy == true
	local out: Elite2Cave =
		{ caveId = caveId, kills = 0, items = 0, heroic = 0, legendary = 0, crystals = 0, scrolls = 0, seats = {} }
	local function addSeat(seat: Elite2Seat, perHour: number)
		out.kills += perHour
		out.items += seat.items * perHour
		out.heroic += seat.heroic * perHour
		out.legendary += seat.legendary * perHour
		out.crystals += seat.crystals * perHour
		out.scrolls += seat.scrolls * perHour
		table.insert(out.seats, { seat = seat, perHour = perHour })
	end
	if legacy then
		local first = assert(spawners[1], caveId)
		local kinds = Balance.S134h.legacy.kinds[caveId] or cave.elite2
		local perHour = 3600 / ((first.respawn.min + first.respawn.max) / 2)
		for _, kind in kinds do
			addSeat(Balance.elite2Seat(classId, kind, first.level, opts), perHour / #kinds)
		end
	else
		for _, s in spawners do
			addSeat(Balance.elite2Seat(classId, s.kind, s.level, opts), 3600 / ((s.respawn.min + s.respawn.max) / 2))
		end
	end
	return out
end

-- S134h (C2): the targets in one place (ids "S134h.*"); balance.spec ("Balance: Elite II loot (S134h)") asserts every
-- row without `report`.
function Balance.targetsS134h(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S134h
	local function add(id: string, label: string, value: number, low: number?, high: number?, c: string?, lv: number?)
		target(rows, `S134h.{id}`, "elite2loot", label, value, low, high, c, lv)
	end
	for _, cave in Areas.caves.list do
		local heroic, legendary = 0, 0
		local lv = cave.levels[2]
		for _, c in Balance.CLASSES do
			local now, before = Balance.elite2Cave(c, cave.id), Balance.elite2Cave(c, cave.id, { legacy = true })
			local h = now.heroic / math.max(1e-9, before.heroic)
			local l = now.legendary / math.max(1e-9, before.legendary)
			heroic += h / #Balance.CLASSES
			legendary += l / #Balance.CLASSES
			add(
				`elite2.class.heroic.{cave.id}.{c}`,
				`{cave.id} {c}: Heroiki dla klasy / h przed`,
				h,
				S.classFloor,
				nil,
				c,
				lv
			)
			rows[#rows].report = "S134h"
		end
		add(
			`elite2.cave.heroic.{cave.id}`,
			`{cave.id}: Heroiki dla klasy / h (śr. 4 klas) przed`,
			heroic,
			S.ratio[1],
			S.ratio[2],
			nil,
			lv
		)
		add(
			`elite2.cave.legendary.{cave.id}`,
			`{cave.id}: Legendarne dla klasy / h (śr. 4 klas) przed`,
			legendary,
			S.ratio[1],
			S.ratio[2],
			nil,
			lv
		)
		local now, before =
			Balance.elite2Cave("Warrior", cave.id), Balance.elite2Cave("Warrior", cave.id, { legacy = true })
		add(
			`elite2.cave.crystal.{cave.id}`,
			`{cave.id}: kryształy esencji / h przed`,
			now.crystals / math.max(1e-9, before.crystals),
			nil,
			S.crystal,
			nil,
			lv
		)
		for _, s in elite2Spawners(cave.id) do
			local best = 0
			for _, c in Balance.CLASSES do
				best = math.max(best, Balance.elite2Seat(c, s.kind, s.level).usable)
			end
			add(
				`elite2.seat.share.{s.kind}`,
				`{s.kind} ({cave.id}): udział przedmiotów najlepszej klasy`,
				best,
				S.seatShare,
				nil,
				nil,
				s.level
			)
		end
	end
	return rows
end

-- Elite II hideouts (S134i, docs/sessions/S134i.md C) ----------------------------------------------------------------
-- 2-3 hideouts on every region map, each with one Elite II of its own loot (LootTables.ELITE2_SLOTS) and its respawn
-- (AreaSpawns.elite2Respawn of its top level x Combat.lairElite2RespawnMul). The model per hour of a level band
-- (LootTables.ELITE2_BANDS): every Elite II spawner of the world whose level range overlaps the band, killed as soon as
-- it is back; `before` = the caves alone (the state after S134h, the same code).

Balance.S134i = {
	band = 1.35, -- Heroics / Legendaries for the class (mean of the 4 classes), crystals: per hour of a band / before
	seat = 1, -- one hideout's Heroics + Legendaries for the class per hour / one cave Elite II's of its band (mean)
}

export type Elite2Place = {
	place: string, -- cave id or hideout id
	region: string,
	lair: boolean,
	kind: string,
	min: number,
	max: number,
	respawn: { min: number, max: number },
}

-- Every Elite II spawner of the world's places (Data/Spawns): the caves', then the hideouts'.
function Balance.elite2Places(): { Elite2Place }
	local out: { Elite2Place } = {}
	for _, cave in Areas.caves.list do
		for _, s in Spawns.byMap[cave.id] or {} do
			if s.variant == "elite2" then
				table.insert(out, {
					place = cave.id,
					region = cave.region,
					lair = false,
					kind = s.monster,
					min = s.level.min,
					max = s.level.max,
					respawn = s.respawn,
				})
			end
		end
	end
	for _, mapId in { "meadows", "duskwood", "ashen", "frostpeak" } do
		for _, s in Spawns.byMap[mapId] or {} do
			if s.variant == "elite2" and s.lair then
				table.insert(out, {
					place = s.lair,
					region = mapId,
					lair = true,
					kind = s.monster,
					min = s.level.min,
					max = s.level.max,
					respawn = s.respawn,
				})
			end
		end
	end
	return out
end

export type Elite2Hour = { kills: number, heroic: number, legendary: number, crystals: number, places: number }

-- One place's hour for `classId` (killed as soon as it is back).
function Balance.elite2PlaceHour(classId: string, e: Elite2Place): Elite2Hour
	local perHour = 3600 / ((e.respawn.min + e.respawn.max) / 2)
	local seat = Balance.elite2Seat(classId, e.kind, e.max)
	return {
		kills = perHour,
		heroic = seat.heroic * perHour,
		legendary = seat.legendary * perHour,
		crystals = seat.crystals * perHour,
		places = 1,
	}
end

-- S134i (C2): an hour of every Elite II of a level band { lo, hi } for `classId` (caves and hideouts; `before`: the
-- caves alone).
function Balance.elite2Band(classId: string, band: { number }, before: boolean?): Elite2Hour
	local out: Elite2Hour = { kills = 0, heroic = 0, legendary = 0, crystals = 0, places = 0 }
	for _, e in Balance.elite2Places() do
		if e.max >= band[1] and e.min <= band[2] and not (before and e.lair) then
			local h = Balance.elite2PlaceHour(classId, e)
			out.kills += h.kills
			out.heroic += h.heroic
			out.legendary += h.legendary
			out.crystals += h.crystals
			out.places += 1
		end
	end
	return out
end

-- S134i (C2): the targets in one place (ids "S134i.*"); balance.spec ("Balance: Elite II hideouts (S134i)") asserts
-- every row without `report`.
function Balance.targetsS134i(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S134i
	local function add(id: string, label: string, value: number, low: number?, high: number?, lv: number?)
		target(rows, `S134i.{id}`, "lairs", label, value, low, high, nil, lv)
	end
	for _, band in LootTables.ELITE2_BANDS do
		local name = `{band[1]}-{band[2]}`
		local heroic, legendary = 0, 0
		for _, c in Balance.CLASSES do
			local now, before = Balance.elite2Band(c, band), Balance.elite2Band(c, band, true)
			heroic += now.heroic / math.max(1e-9, before.heroic) / #Balance.CLASSES
			legendary += now.legendary / math.max(1e-9, before.legendary) / #Balance.CLASSES
		end
		add(
			`band.heroic.{name}`,
			`{name}: Heroiki dla klasy / h pasma (śr. 4 klas) / same jaskinie`,
			heroic,
			nil,
			S.band,
			band[2]
		)
		add(
			`band.legendary.{name}`,
			`{name}: Legendarne dla klasy / h pasma (śr. 4 klas) / same jaskinie`,
			legendary,
			nil,
			S.band,
			band[2]
		)
		local now, before = Balance.elite2Band("Warrior", band), Balance.elite2Band("Warrior", band, true)
		add(
			`band.crystal.{name}`,
			`{name}: kryształy esencji / h pasma / same jaskinie`,
			now.crystals / math.max(1e-9, before.crystals),
			nil,
			S.band,
			band[2]
		)
	end
	-- one hideout against one cave Elite II of the band of its top level (mean over the cave Elite IIs of that band)
	local places = Balance.elite2Places()
	for _, e in places do
		if e.lair then
			local band = LootTables.ELITE2_BANDS[1]
			for _, b in LootTables.ELITE2_BANDS do
				if e.max >= b[1] and e.max <= b[2] then
					band = b
					break
				end
			end
			local mine, caves = 0, 0
			for _, c in Balance.CLASSES do
				local h = Balance.elite2PlaceHour(c, e)
				mine += (h.heroic + h.legendary) / #Balance.CLASSES
				local sum, n = 0, 0
				for _, o in places do
					if not o.lair and o.max >= band[1] and o.min <= band[2] then
						local oh = Balance.elite2PlaceHour(c, o)
						sum += oh.heroic + oh.legendary
						n += 1
					end
				end
				caves += sum / math.max(1, n) / #Balance.CLASSES
			end
			add(
				`lair.seat.{e.place}`,
				`{e.place} ({e.kind}): Heroiki + Legendarne dla klasy / h / Elita II jaskini pasma {band[1]}-{band[2]}`,
				mine / math.max(1e-9, caves),
				nil,
				S.seat,
				e.max
			)
		end
	end
	return rows
end

export type BossDrops = { legendary: number, mythic: number, heroic: number, extra: number }
-- P2 (H5): items for the class per day of Config.Boss.dailyRuns kills of `bossId` (Loot.bossChances with Luck.boss
-- of a Priest of Fortune; item luck never counts on bosses, ROZWOJ 6.2). Unique / Heroic items: the boss weights,
-- a Unique ennobled with luck.upgrade, a second item with luck.extra. Mythic as Loot.rollBossItem (S87): a fitting
-- named item, else a rolled Mythic of a base the class can wear.
function Balance.bossDrops(classId: string, bossId: string, fortune: ("full" | "start")?): BossDrops
	local members: { Luck.Member } = { { name = "player" } }
	if fortune then
		table.insert(members, { name = "fortune", luck = Balance.fortuneLuck(fortune) })
	end
	local luck = Luck.boss(members)
	local boss = LootTables.bosses[bossId]
	local slots = LootTables.bossSlots
	local legendaryUsable = Balance.usableShare(slots, boss.level, Config.BossLoot.legendaryClassShare, classId)
	local namedUsable = 0
	for _, id in boss.named do
		local def = Items.get(id) :: any
		if def and (def.classes == nil or table.find(def.classes, classId)) then
			namedUsable = 1
		end
	end
	-- S87: a rolled Mythic (and the substitute when no named item fits) comes from Loot.pickUsable: always for the
	-- class when any slot of the boss tier has a base it can wear, else Loot.pickItem with class bias 1
	local rolledUsable = Balance.usableShare(slots, boss.level, 1, classId)
	local tiers, tier = slotTiers(), Items.generate.tierFor(boss.level)
	for slot, w in slots do
		local candidates = tiers[slot] and tiers[slot][tier]
		if w > 0 and candidates then
			for _, id in candidates do
				local def = Items.get(id) :: any
				if def.classes == nil or table.find(def.classes, classId) then
					rolledUsable = 1
				end
			end
		end
	end
	local named = if #boss.named > 0 then Config.BossLoot.mythicNamedShare else 0
	local mythicUsable = named * (if namedUsable > 0 then 1 else rolledUsable) + (1 - named) * rolledUsable
	local weights = Rarities.dropWeights.boss
	local total = 0
	for _, w in weights do
		total += w
	end
	local heroicShare = (weights[Rarities.HEROIC] or 0) / total
	local uniqueShare = (weights[Rarities.UNIQUE] or 0) / total
	local commonUsable = usableAt(slots, boss.level, Config.BossLoot.legendaryClassShare, classId)
	local legendary, mythic, heroic = 0, 0, 0
	for k = 0, Config.Boss.dailyRuns - 1 do
		local chances = Loot.bossChances(bossId, k, luck)
		legendary += chances.legendary * legendaryUsable
		mythic += chances.mythic * mythicUsable
		local rest = math.max(0, 1 - chances.legendary - chances.mythic)
		heroic += rest * (heroicShare + uniqueShare * luck.upgrade) * commonUsable
	end
	local extra = Config.Boss.dailyRuns * luck.extra * heroicShare * commonUsable
	return { legendary = legendary, mythic = mythic, heroic = heroic, extra = extra }
end

-- Monster defence (S84 I) -------------------------------------------------------------------------------------------

-- Share of the damage `m`'s armour (or magic resistance) removes from a player of `level` (Damage.reduction).
function Balance.armorShare(m: any, level: number, magic: boolean): number
	return Damage.reduction(if magic then m.mres else m.armor, level)
end

-- The generic kind and one kind per (family, defence) of Data/Families with the trait's defMul / mresMul / dodge
-- (same HP and attack: only the defence differs).
function Balance.defenceKinds(): { { id: string, defence: string?, kind: any } }
	local out: { { id: string, defence: string?, kind: any } } = { { id = "zwykły", kind = Balance.GENERIC } }
	for _, family in Families.ids do
		local defences = (Families.byId[family] :: Families.FamilyDef).defences
		for _, defenceId in sortedKeys(defences) do
			local d = defences[defenceId]
			local kind = table.clone(Balance.GENERIC) :: any
			kind.family = family
			kind.defMul = d.defMul or 1
			kind.mresMul = d.mresMul or 1
			kind.dodge = d.dodge or 0
			table.insert(out, { id = `{family} · {defenceId}`, defence = defenceId, kind = kind })
		end
	end
	return out
end

export type DefenceRow = {
	id: string,
	seconds: number,
	hpLost: number,
	defenceShare: number, -- Damage.reduction of the defence that counts against the player (after its pierce)
	dodgeShare: number, -- share of the DPS lost to the monster's dodge (basic attacks only, FightSim)
	secondsNoComp: number, -- the same fight without the S66 HP compensation (report)
	hpLostNoComp: number,
}

-- 1 on 1 of the default Common player of `level` against every defence kind of the level.
function Balance.defenceAt(classId: string, level: number): { DefenceRow }
	local p = Balance.cachedPlayer(classId, level)
	local attacker = Damage.fromStats(level, p.values)
	local out: { DefenceRow } = {}
	for _, entry in Balance.defenceKinds() do
		local m = Balance.monster(entry.kind, level)
		local f = Balance.duel(p, m)
		local defence = Damage.defenseOf(if p.magic then "magic" else "phys", attacker, MonsterStats.asDefender(m), 0)
		local noDodge = table.clone(m)
		noDodge.dodge = 0
		-- mirrors MonsterStats.baseHp (S66): the level part of the HP without Combat.monsterHpComp
		local base = MonsterStats.baseHp(m.level)
		local raw = table.clone(m)
		raw.maxHp = m.maxHp * (Combat.monsterHpBase + (base - Combat.monsterHpBase) / Combat.monsterHpComp) / base
		local g = Balance.duel(p, raw)
		table.insert(out, {
			id = entry.id,
			seconds = f.seconds,
			hpLost = f.hpLost,
			defenceShare = Damage.reduction(defence, level),
			dodgeShare = 1 - Balance.dps(p, m) / Balance.dps(p, noDodge),
			secondsNoComp = g.seconds,
			hpLostNoComp = g.hpLost,
		})
	end
	return out
end

export type VsDefence = { label: string, generic: number, defended: number }
-- DPS gain from breaking or ignoring defence against the generic kind and the defended one (armour: undead armored;
-- magic resistance: undead warded) of `level`, at a constant share (Damage.reduction; STATY 7: Sundering 50 % on
-- armored ~ +17 %, pierce 20 % ~ +6 %).
function Balance.vsDefence(level: number): { VsDefence }
	local ilvl = math.max(1, level - Balance.GEAR_GAP)
	local generic = Balance.monster(Balance.GENERIC, level)
	local function defended(defenceId: string): any
		local d = Families.defence("undead", defenceId) :: Families.Defence
		local kind = table.clone(Balance.GENERIC) :: any
		kind.defMul = d.defMul or 1
		kind.mresMul = d.mresMul or 1
		return Balance.monster(kind, level)
	end
	local armored, warded = defended("armored"), defended("warded")
	local function gain(defence: number, share: number): number
		return (1 - Damage.reduction(defence * (1 - share), level)) / (1 - Damage.reduction(defence, level)) - 1
	end
	local function traitValue(base: string, rarity: number, up: number): number
		local trait = ItemRoll.trait(makeItem(tierId(base, ilvl), ilvl, rarity, up, {})) :: ItemRoll.TraitRoll
		return trait.value
	end
	local out: { VsDefence } = {}
	local function add(label: string, share: number, magic: boolean)
		local a = if magic then generic.mres else generic.armor
		local b = if magic then warded.mres else armored.armor
		table.insert(out, { label = label, generic = gain(a, share), defended = gain(b, share) })
	end
	local sunderOnHit = (ItemTraits.get("sundering") :: ItemTraits.TraitDef).onHit :: ItemTraits.OnHit
	local stacks = sunderOnHit.maxStacks or 1
	add(
		"Niszczenie pancerza, Zwykły +0, pełne stosy",
		Traits.armorBreakCap(traitValue("hammer2h", Rarities.COMMON, 0), stacks) / 100,
		false
	)
	add(
		"Niszczenie pancerza, Mityczny +9, pełne stosy",
		Traits.armorBreakCap(traitValue("hammer2h", Rarities.MYTHIC, 9), stacks) / 100,
		false
	)
	local pierceCap = (Stats.get("pierce") :: any).cap or 100
	add(
		"Bełt przeciwpancerny, Zwykły +0",
		math.min(traitValue("heavycrossbow", Rarities.COMMON, 0), pierceCap) / 100,
		false
	)
	add(
		"Bełt przeciwpancerny, Mityczny +9",
		math.min(traitValue("heavycrossbow", Rarities.MYTHIC, 9), pierceCap) / 100,
		false
	)
	add(
		"linia pierce (Legendarny, środek rzutu)",
		ItemRoll.rollBonusValue("pierce", ilvl, Rarities.LEGENDARY, 0.5) / 100,
		false
	)
	add(
		"linia magicPierce (Legendarny, środek rzutu)",
		ItemRoll.rollBonusValue("magicPierce", ilvl, Rarities.LEGENDARY, 0.5) / 100,
		true
	)
	return out
end

-- Target rows G7-G9 (S84; report until S87) ------------------------------------------------------------------------

local itemTargetCache: { TargetRow }? = nil
-- G7 (the "z cechami" column), G8 ("bez cech" and "z cechami" in MIX) and G9 (+1..+3 / income, +1..+9 with
-- protection in levels of income) for balance.spec's global block (GLOBAL_ASSERT) and the report.
function Balance.itemTargets(): { TargetRow }
	if itemTargetCache then
		return itemTargetCache
	end
	local rows: { TargetRow } = {}
	local function add(id: string, label: string, value: number, low: number?, high: number?, c: string?, L: number?)
		table.insert(rows, {
			id = id,
			group = string.match(id, "^(G%d+)") or id,
			label = label,
			value = value,
			low = low,
			high = high,
			classId = c,
			level = L,
		})
	end
	for _, c in Balance.CLASSES do
		for _, L in Balance.GLOBAL_LEVELS do
			for rarity = Rarities.UNIQUE, Rarities.MYTHIC do
				local low, high = Balance.g7Band(c, L, rarity)
				local name = Rarities.get(rarity).key
				add("G7", `{c} {L}: {name} (z cechami)`, Balance.rarityGainAt(c, L, rarity).traits, low, high, c, L)
			end
		end
	end
	for _, pair in Balance.G8_PAIRS do
		for _, L in Balance.ITEM_LEVELS do
			for _, rarity in Balance.GEAR_RARITIES do
				for _, up in { 0, 9 } do
					local low, high = Balance.g8Band(pair.weapon, up)
					local name = Rarities.get(rarity).key
					local label = `{pair.classId} {pair.weapon} {name} +{up} L{L}`
					local noTraits =
						Balance.twoHandedParity(pair.classId, L, pair.weapon, rarity, up, { traits = false })
					local traits = Balance.twoHandedParity(pair.classId, L, pair.weapon, rarity, up)
					add("G8", `{label}: bez cech`, noTraits.mix, low, high, pair.classId, L)
					add("G8", `{label}: z cechami`, traits.mix, low, high, pair.classId, L)
				end
			end
		end
	end
	for _, L in Balance.GLOBAL_LEVELS do
		for _, u in Balance.upgradeVsIncome(L) do
			add("G9.up3", `{u.classId} {L}: +1…+3 broni / dochód poziomu`, u.up3, 0.45, 1.05, u.classId, L)
			add("G9.up9", `{u.classId} {L}: +1…+9 z ochroną (poziomy dochodu)`, u.up9, 12, 25, u.classId, L)
		end
	end
	itemTargetCache = rows
	return rows
end

-- S88: named Mythics (D4) -------------------------------------------------------------------------------------------

-- Gear options that put a base type in its slot for `classId` (weapon / off-hand; armour and jewellery by default).
local function namedGear(baseType: string): GearOpts
	local base = Bases.byType[baseType] :: any
	if base and base.slot == "weapon" then
		local twoHanded = base.weapon(1).twoHanded
		return { weapon = baseType, offhand = if twoHanded then false else nil }
	elseif base and base.slot == "offhand" then
		return { offhand = baseType }
	end
	return {}
end

-- The items of the S32 set of `classId` at `level` with `item` in place of the first item of its base type.
local function withItem(classId: string, level: number, baseType: string, item: any): { any }
	local items = Balance.gear(classId, level, namedGear(baseType))
	for i, it in items do
		local def = Items.get(it.id) :: any
		if def and def.type == baseType then
			items[i] = item
			return items
		end
	end
	error(`Balance: no {baseType} in the {classId} set`)
end

-- S67 / S84: a family line counts on the model's monster family (GENERIC) with FAMILY_MATCH, as expectedLines
-- spreads the rolled family lines; the named item's fixed line goes there the same way (extra hooks).
local function familyHooks(lines: { any }): { [string]: number }
	local hooks: { [string]: number } = {}
	for _, line in lines do
		local def = Bonuses.get(line.stat) :: any
		if def and def.param and Bonuses.params[def.param].over == "family" then
			local prefix = Bonuses.params[def.param].prefix
			local id = Bonuses.familyLine(prefix, Balance.GENERIC.family)
			hooks[id] = (hooks[id] or 0) + line.v * FAMILY_MATCH
			if line.stat ~= id then
				hooks[line.stat] = (hooks[line.stat] or 0) - line.v -- only the spread part counts
			end
		end
	end
	return hooks
end

export type NamedPower = { itemId: string, classId: string, power: number }

-- D4 (S84 F definition): powerMix of `classId` at the item's level with the named item in its slot / with the
-- expected rolled Mythic of the same base and ilvl (expectedBonuses; a rolled two-handed weapon's lines x
-- twoHandedBonusMul through Balance.itemStats), both Mythic +0.
function Balance.namedPower(itemId: string, classId: string): NamedPower
	local def = Items.get(itemId) :: any
	local L = def.level
	local named = makeItem(itemId, L, Rarities.MYTHIC, 0, {})
	local rolledId = tierId(def.type, L)
	local rolled = makeItem(rolledId, L, Rarities.MYTHIC, 0, expectedBonuses(rolledId, L, Rarities.MYTHIC, classId))
	local a = Balance.playerFromItems(
		classId,
		L,
		withItem(classId, L, def.type, named),
		nil,
		{ hooks = familyHooks(def.fixedBonuses) }
	)
	local b = Balance.playerFromItems(classId, L, withItem(classId, L, def.type, rolled))
	return { itemId = itemId, classId = classId, power = Balance.powerMix(a) / Balance.powerMix(b) }
end

export type NamedLine = { stat: string, v: number, top: number, limit: number, legendary: boolean, ok: boolean }

-- D4: every line of a named item against its limit: a regular line at most NAMED_LINE_MAX x the Mythic top of
-- ItemRoll.bonusRange at the item's level, a legendary line within its own range.
function Balance.namedLines(itemId: string): { NamedLine }
	local def = Items.get(itemId) :: any
	local out: { NamedLine } = {}
	for _, line in def.fixedBonuses do
		local bonusDef = Bonuses.get(line.stat) :: any
		local legendary = bonusDef.tier == "legendary"
		local lo, hi = ItemRoll.bonusRange(line.stat, def.level, Rarities.MYTHIC)
		-- a rolled two-handed weapon's regular lines are x twoHandedBonusMul (S87); a named one keeps its numbers
		local twoHanded = def.weapon and def.weapon.twoHanded
		local mul = if twoHanded and ItemRoll.isRegularLine(line.stat) then Rarities.twoHandedBonusMul else 1
		local limit = if legendary then hi else hi * mul * Balance.NAMED_LINE_MAX
		table.insert(out, {
			stat = line.stat,
			v = line.v,
			top = hi,
			limit = limit,
			legendary = legendary,
			ok = line.v <= limit + 1e-9 and (not legendary or line.v >= lo - 1e-9),
		})
	end
	return out
end

-- S88: PvP (F1) -----------------------------------------------------------------------------------------------------

-- A player seen as the target of another player's hits (the fields FightSim.dps and traitTerms read).
local function asTarget(p: Player): any
	local v = p.values
	return {
		level = p.level,
		maxHp = v.maxHp or 1,
		armor = v.armor or 0,
		mres = v.mres or 0,
		dodge = v.dodge or 0,
		attackInterval = 1 / math.max(0.1, v.atkSpeed or 1),
		damageKind = if p.magic then "magic" else "phys",
		family = nil,
	}
end

export type PvpSide = {
	dps: number, -- damage per s of the attacker on the defender (PvP rules)
	ticks: number, -- the trait / line ticks in it
	heal: number, -- the defender's healing per s from its own traits and lifesteal
	seconds: number, -- time to kill the defender
	stun: number, -- share of the defender's time stunned by the attacker's Concussion
}
-- `seconds`: the fight length of both passes (the PvE reference of F3 takes the PvP length: ticks after death)
export type PvpOpts = { classLines: boolean?, pve: boolean?, still: number?, controlled: number?, seconds: number? }

-- One direction of a duel: `a` hits `b` (both of the same level); `pve` = the same exchange with the rules against
-- monsters (no pvpModifier, halves, tick multiplier, class lines): the reference of the S88 PvP checks.
local function pvpSide(a: Player, b: Player, o: PvpOpts, seconds: number): PvpSide
	local pvp = not o.pve
	local S = Balance.SITUATIONS
	local function ctxOf(p: Player, other: Player): SituationCtx
		local target = asTarget(other)
		return {
			name = "pvp",
			level = p.level,
			m = target,
			hit = 0,
			attacks = math.max(0.1, other.values.atkSpeed or 1), -- the other's regular attacks (counters, block)
			seconds = seconds,
			kills = 0,
			targetShare = 1,
			othersAlive = 0,
			behind = 0,
			controlled = o.controlled or 0,
			still = o.still or 0,
			bossLike = false,
			measure = "power",
			rates = nil,
			pvp = pvp,
		}
	end
	local ta = Balance.traitTerms(a, asTarget(b), ctxOf(a, b))
	local tb = Balance.traitTerms(b, asTarget(a), ctxOf(b, a))
	local m = asTarget(b)
	local v = a.values
	-- block and the crit resistance of the defender on the attacker's hits (FightSim.dps has neither)
	local bs = S.basicShare[a.classId] or 0.5
	local hitShare = 1 - Damage.dodgeChance(m.dodge, v.accuracy or 0)
	local basic = (1 + (v.basicDmg or 0) / 100) * hitShare
	local skill = (1 / bs - 1) * (1 + (v.skillDmg or 0) / 100)
	local basicFrac = basic / math.max(1e-9, basic + skill)
	local _, _, block = Damage.avoidance(0, 0, 0, Traits.blockChance(b.hooks.block or 0, pvp))
	local c = math.min(v.critChance or 0, 100) / 100
	local critDmg = v.critDmg or 150
	local critFix = (1 + c * (Damage.critMultiplier(critDmg, b.values.critResist) - 1)) / (1 + c * (critDmg / 100 - 1))
	local hitMul = critFix * (1 - basicFrac * block)
	if pvp then
		hitMul *= Combat.pvpModifier
		if o.classLines then
			hitMul *= Damage.classLineMul(
				a.hooks[Bonuses.classLine("vs_", b.classId)] or 0,
				b.hooks[Bonuses.classLine("res_", a.classId)] or 0
			)
		end
	end
	-- the defender's own traits slow, weaken and stun the attacker (its takenMul)
	local hits = ta.baseDps * (1 + ta.hitAdd) * hitMul * tb.takenMul
	local ticks = ta.baseDps * ta.dotAdd * tb.takenMul
	local heal = tb.sustain + (b.values.hpRegenCombat or 0)
	local dps = hits + ticks
	-- Concussion of the attacker: stuns per s x the stun (mirrors the traitTerms formula; x PvpCcMultiplier)
	local stun = 0
	local shock = (a.traits or {}).concussion
	if shock then
		local onHit = shock.def.onHit :: ItemTraits.OnHit
		local chance = Traits.chance(shock.value, 0, 1) / 100
		local procHits = math.max(0.1, v.atkSpeed or 1) * hitShare + 1 / S.skillInterval
		local per = 1 / ((onHit.gap or 0) + 1 / math.max(1e-9, chance * procHits))
		stun = per * onHit.duration * (if pvp then Config.PvpCcMultiplier else 1)
	end
	return {
		dps = dps,
		ticks = ticks,
		heal = heal,
		seconds = (b.values.maxHp or 1) / math.max(1e-9, dps - math.min(heal, 0.8 * dps)),
		stun = stun,
	}
end

export type PvpDuel = { ab: PvpSide, ba: PvpSide }

-- F1: a duel of two players of the same level (the S32 convention: basic attacks and skills as SKILL_DPS, no
-- rotation): time to kill in both directions. Every trait with its PvP rule (traitTerms with ctx.pvp), pvpModifier
-- once on hits, Combat.pvp.dot once on ticks, block and counter halves, lifesteal half, class lines with
-- classLineCap (`classLines`).
function Balance.pvpDuel(a: Player, b: Player, opts: PvpOpts?): PvpDuel
	local o: PvpOpts = opts or {}
	if o.seconds then
		return { ab = pvpSide(a, b, o, o.seconds), ba = pvpSide(b, a, o, o.seconds) }
	end
	local ab = pvpSide(a, b, o, 20)
	local ba = pvpSide(b, a, o, 20)
	-- once more with the fight's own length (ticks after death, armour break stacks)
	return { ab = pvpSide(a, b, o, ab.seconds), ba = pvpSide(b, a, o, ba.seconds) }
end

-- F3: the PvP / PvE ratio of one trait of `p` in a mirror duel against `opp`: an attacking trait shortens the kill
-- of `opp`, a defending one (Bonebreaker, Parry, Saving Blow, Swordplay's counters on the defender) lengthens the
-- kill of `p`. `traitScale` turns the trait off. The same situation shares (still, controlled) in both.
Balance.PVP_DEFENSIVE = { bonebreaker = true, parry = true, savingBlow = true } :: { [string]: boolean }
function Balance.pvpTraitValue(
	p: Player,
	pOff: Player,
	opp: Player,
	traitId: string,
	pve: boolean,
	opts: PvpOpts?
): number
	local o = table.clone(opts or {}) :: PvpOpts
	o.pve = pve
	if Balance.PVP_DEFENSIVE[traitId] then
		local with = Balance.pvpDuel(opp, p, o).ab.seconds
		local without = Balance.pvpDuel(opp, pOff, o).ab.seconds
		return with / without - 1
	end
	local with = Balance.pvpDuel(p, opp, o).ab.seconds
	local without = Balance.pvpDuel(pOff, opp, o).ab.seconds
	return without / with - 1
end

-- Login reward (S100, docs/DESIGN-15.md §5) -------------------------------------------------------------------------
-- Outside economyAt and the pace model (a reward per calendar day, not per hour of play; DECYZJE S100): the targets
-- compare a week of rewards with the income of an hour of grinding (balance.spec "Login reward (S100)").

export type LoginDay = { gold: number, items: number, total: number } -- items: the value of the day's items
export type LoginWeek = {
	gold: number,
	potionValue: number, -- potions at their buy price (what the shop would ask)
	essenceValue: number, -- essences at Balance.materialPrices (dust at the merchant, shards / crystals transmuted)
	stoneValue: number, -- Return Stones at their buy price
	blessingValue: number, -- blessings at their item price
	total: number,
	perDay: { LoginDay },
	essence: { id: string, n: number }, -- the band's essence of the whole week
}

local function loginItemValue(id: string, n: number): (string, number)
	local def = Items.get(id) :: any
	assert(def, `loginWeek: unknown item {id}`)
	if def.use and def.use.kind == "potion" then
		return "potion", n * def.buyPrice
	elseif id == "stone_return" then
		return "stone", n * (def.buyPrice or def.price)
	elseif def.use and def.use.kind == "blessing" then
		return "blessing", n * def.price
	end
	local price = Balance.materialPrices()[id]
	assert(price, `loginWeek: no price for {id}`)
	return "essence", n * price
end

-- One week of login rewards of `classId` at `level` (LoginReward.week) in gold; the chest item stays outside (a drop,
-- compared with D5 in loginChest).
function Balance.loginWeek(classId: string, level: number): LoginWeek
	local out: LoginWeek = {
		gold = 0,
		potionValue = 0,
		essenceValue = 0,
		stoneValue = 0,
		blessingValue = 0,
		total = 0,
		perDay = {},
		essence = { id = LoginReward.essenceAt(level).item, n = 0 },
	}
	for _, day in LoginReward.week(level, classId) do
		local value = 0
		for _, entry in day.items do
			local kind, v = loginItemValue(entry.id, entry.n)
			value += v
			if kind == "potion" then
				out.potionValue += v
			elseif kind == "stone" then
				out.stoneValue += v
			elseif kind == "blessing" then
				out.blessingValue += v
			else
				out.essenceValue += v
				if entry.id == out.essence.id then
					out.essence.n += entry.n
				end
			end
		end
		out.gold += day.gold
		table.insert(out.perDay, { gold = day.gold, items = value, total = day.gold + value })
	end
	out.total = out.gold + out.potionValue + out.essenceValue + out.stoneValue + out.blessingValue
	return out
end

-- The week's essence against the essence of that kind the class weapon of ilvl level - 2 needs for its whole band of
-- upgrades without protection (dust +1..+3, shards +4..+6, crystals +7..+9; Logic/Upgrade uses each essence only in
-- its band). Returns (share, need).
function Balance.loginEssenceShare(classId: string, level: number): (number, number)
	local week = Balance.loginWeek(classId, level)
	local id = week.essence.id
	local to = if id == "essence_dust" then 3 elseif id == "essence_shard" then 6 else 9
	local ilvl = math.max(1, level - Balance.GEAR_GAP)
	local item = makeItem(tierId(Balance.LOADOUT[classId].weapon, ilvl), ilvl, Rarities.COMMON, 0, {})
	local need = Balance.upgradePlan(item, to, false).materials[id] or 0
	return week.essence.n / math.max(1e-9, need), need
end

export type LoginShare = {
	classId: string,
	level: number,
	income: number, -- gold per hour of grinding (economyAt)
	week: LoginWeek,
	weekShare: number, -- hours of income
	maxDay16: number, -- the dearest of days 1-6, in hours of income
	day7: number, -- day 7 without the chest item, in hours of income
	essenceShare: number, -- the week's essence / the essence of its upgrade band
	essenceNeed: number,
}

function Balance.loginShare(classId: string, level: number): LoginShare
	local week = Balance.loginWeek(classId, level)
	local income = math.max(1e-9, Balance.economyAt(classId, level).incomePerHour)
	local maxDay = 0
	for d = 1, LoginReward.DAYS - 1 do
		maxDay = math.max(maxDay, week.perDay[d].total)
	end
	local essenceShare, need = Balance.loginEssenceShare(classId, level)
	return {
		classId = classId,
		level = level,
		income = income,
		week = week,
		weekShare = week.total / income,
		maxDay16 = maxDay / income,
		day7 = week.perDay[LoginReward.DAYS].total / income,
		essenceShare = essenceShare,
		essenceNeed = need,
	}
end

-- Expected chest items a week (one chest a week) against D5 at its floor (heroicPerHour[1] Heroics and
-- uniquePerHour[1] Uniques per hour) over an assumed LOGIN_HOURS_PER_WEEK hours of play a week.
Balance.LOGIN_HOURS_PER_WEEK = 7
function Balance.loginChest(): { heroic: number, unique: number, heroicShare: number, uniqueShare: number }
	local weights = LoginRewardData.chest.rarity :: { [number]: number }
	local total = 0
	for _, w in weights do
		total += w
	end
	local heroic = (weights[Rarities.HEROIC] or 0) / total
	local unique = (weights[Rarities.UNIQUE] or 0) / total
	local d5 = Balance.REGION_TARGETS.d5
	return {
		heroic = heroic,
		unique = unique,
		heroicShare = heroic / (d5.heroicPerHour[1] * Balance.LOGIN_HOURS_PER_WEEK),
		uniqueShare = unique / (d5.uniquePerHour[1] * Balance.LOGIN_HOURS_PER_WEEK),
	}
end

-- World events (S101, DESIGN-15 §4): the event reward's EXP as a share of the level's EXP at one event every
-- WORLD_EVENT_HOURS of play (the event at the character's level, a victory, no expBonus), for the class with the
-- longest level. The level's time is its grinding time (expToNext / paceAt.expPerHour, default options): paceAt's
-- `hours` leave out the quest EXP and are 0 on levels the quests cover, and quests only shorten the level, so this
-- is the upper bound. The waves' and the Elite II's kills are ordinary kills that replace grinding on the same
-- ground, so they stay outside. Returns (worst share, its class).
Balance.WORLD_EVENT_HOURS = 2
function Balance.worldEventHours(classId: string, level: number): number
	local pace = Balance.paceAt(classId, level)
	return Exp.expToNext(level) / math.max(1e-9, pace.expPerHour)
end

function Balance.worldEventShare(level: number): (number, string)
	local exp = WorldEvents.reward(level, level, true).exp
	local need = math.max(1, Exp.expToNext(level))
	local worst, worstClass = -1, Balance.CLASSES[1]
	for _, classId in Balance.CLASSES do
		local hours = Balance.worldEventHours(classId, level)
		local share = exp * (hours / Balance.WORLD_EVENT_HOURS) / need
		if share > worst then
			worst, worstClass = share, classId
		end
	end
	return worst, worstClass
end

export type WorldEventRow = {
	level: number,
	exp: number,
	share: number,
	classId: string,
	gold: number,
	goldShare: number, -- event gold over the income of WORLD_EVENT_HOURS hours (the same class)
	minutes: number, -- minutes of grinding the event's EXP is worth (the same class)
}

-- One report row of the world event reward at `level` (balance_report "World events (S101)").
function Balance.worldEventRow(level: number): WorldEventRow
	local share, classId = Balance.worldEventShare(level)
	local r = WorldEvents.reward(level, level, true)
	local hours = Balance.worldEventHours(classId, level)
	local income = math.max(1e-9, Balance.economyAt(classId, level).incomePerHour)
	return {
		level = level,
		exp = r.exp,
		share = share,
		classId = classId,
		gold = r.gold,
		goldShare = r.gold / Balance.WORLD_EVENT_HOURS / income,
		minutes = r.exp / math.max(1, Exp.expToNext(level)) * hours * 60,
	}
end

-- S134c (E1): the Invasion model ----------------------------------------------------------------------------------
-- The waves of Data/WorldEvents.kinds.invasion around the event ground: the party fights the clusters apart (the S83
-- convention: every member its own cluster, the kill rates add up), the Elites apart, the last wave's Elite II and the
-- commander together. The next wave comes when clearShare of the current one is dead (never before minWaveGap) or
-- after waveEvery; what is left alive stays as backlog. The commander comes after the last wave (or at commanderAt),
-- the party first finishes the backlog, then the commander (x BOSS_UPTIME, like a boss with blows to dodge). The
-- commander's blows run on the server's rule (Monster.SetExtraAbilities: the first ready one of the list, its own
-- ability last, a gap after each cast); `avoid` blows land x avoidHit (default 0: dodged), the split is shared by
-- `splitInside` players (default the whole party; 0 = nobody inside: missAll on everyone).

export type InvasionParams = {
	duration: number,
	waves: number,
	waveEvery: number,
	minWaveGap: number,
	clearShare: number,
	commanderAt: number,
	wave: { base: number, perPlayer: number, max: number, cluster: number },
	elitesPerWave: { number },
	lastWaveElite2: boolean,
	commander: { hp: { number }, atk: { number } },
	abilities: { any },
	gap: number,
}

-- S134c: the S101 Invasion (the "before" of the report): waves of 4 + 2 per player (max 16) in clusters of 4, one
-- Elite in waves 3 and 6, no Elite II in the waves, the commander scaled by the players, no extra blows.
Balance.INVASION_S101 = table.freeze({
	duration = 720,
	waves = 6,
	waveEvery = 80,
	minWaveGap = 40,
	clearShare = 0.8,
	commanderAt = 480,
	wave = { base = 4, perPlayer = 2, max = 16, cluster = 4 },
	elitesPerWave = { 0, 0, 1, 0, 0, 1 },
	lastWaveElite2 = false,
	commander = { hp = { 0.45, 0.7, 1.0, 1.2, 1.4 }, atk = { 0.85, 0.95, 1, 1, 1 } },
	abilities = {},
	gap = 0,
}) :: InvasionParams

-- The Invasion of Data/WorldEvents now (Logic/WorldEvents reads the same numbers).
function Balance.invasionParams(): InvasionParams
	local d = WorldEvents.Data.kinds.invasion
	return {
		duration = d.duration,
		waves = d.waves,
		waveEvery = d.waveEvery,
		minWaveGap = d.minWaveGap,
		clearShare = d.clearShare,
		commanderAt = d.commanderAt,
		wave = d.wave,
		elitesPerWave = d.elitesPerWave,
		lastWaveElite2 = d.lastWaveElite2,
		commander = WorldEvents.Data.scale.commander,
		abilities = WorldEvents.commanderAbilities(),
		gap = d.commanderGap,
	}
end

export type InvasionOpts = {
	params: InvasionParams?, -- default Balance.invasionParams()
	avoidHit: number?, -- share of the `avoid` blows that land (default 0)
	splitInside: number?, -- players standing in the split circle (default the whole party)
}

export type Invasion = {
	players: number,
	waveSize: number, -- monsters of a wave without its Elites
	elites: number, -- Elites of all waves
	waveSeconds: number, -- the waves until the commander comes
	commanderAt: number, -- second the commander comes
	backlog: number, -- seconds of wave monsters left when the commander comes
	commanderSeconds: number,
	seconds: number, -- the whole event (to the commander's death)
	duration: number,
	inTime: boolean,
	casts: { [string]: number }, -- the commander's casts by ability over its fight
	-- taken / sustain (potions + regeneration in combat + life steal) of the worst member, at the commander and on one
	-- cluster of the wave with an Elite
	commanderRatio: number,
	waveRatio: number,
	commanderRatioOf: { [string]: number }, -- by class (the worst member of the class)
	-- the biggest blow that cannot be dodged (its basic attack or own ability, x randomMax) / max HP, by class, as if
	-- the member were its target
	biggestHit: { [string]: number },
	biggestAvoidable: { [string]: number }, -- the biggest `avoid` blow / max HP, by class
	split: { [string]: number }, -- the split blow on one player with `splitInside` inside / max HP, by class
	splitAlone: { [string]: number }, -- the split on a lone player standing in it / max HP
	missAll: { [string]: number }, -- the split with nobody inside on each fighter / max HP
}

local function scaleIndex(list: { number }, players: number): number
	return list[math.clamp(math.floor(players), 1, #list)]
end

-- Mean of `f` over a list of monster kinds.
local function meanOver(kinds: { string }, f: (def: any) -> number): number
	local total = 0
	for _, id in kinds do
		total += f(Monsters.get(id))
	end
	return total / math.max(1, #kinds)
end

-- The commander's cast schedule over `seconds` (the server's rule, Monster.SetExtraAbilities): first cast after 4.5 s,
-- then the first ready ability of the list (fromHp: the HP falls evenly over the fight), its own last; the next cast
-- after windup + gap. Returns casts by id and the seconds spent casting.
function Balance.commanderCasts(own: any?, extra: { any }, gap: number, seconds: number): ({ [string]: number }, number)
	local list = table.clone(extra)
	if own then
		table.insert(list, own)
	end
	local nextOf: { [string]: number } = {}
	for _, a in list do
		nextOf[a.id] = 4.5
	end
	local casts: { [string]: number } = {}
	local casting = 0
	local t, nextGlobal = 4.5, 0
	local dt = 0.05
	while t < seconds do
		if t >= nextGlobal then
			local hp = 1 - t / math.max(1e-9, seconds)
			for _, a in list do
				if t >= nextOf[a.id] and (a.fromHp == nil or hp <= a.fromHp) then
					casts[a.id] = (casts[a.id] or 0) + 1
					casting += math.min(a.windup, seconds - t)
					nextOf[a.id] = t + a.windup + a.cooldown
					nextGlobal = t + a.windup + (if #extra > 0 then gap else 0)
					break
				end
			end
		end
		t += dt
	end
	return casts, casting
end

local function sustainOf(p: Player, level: number, dps: number): number
	local steal = math.min(p.values.lifesteal or 0, 15) / 100 * dps
	return Balance.potionHps(level) + (p.values.hpRegenCombat or 0) + steal
end

-- The Invasion of `team` (team[1] is the tank) on hunting ground `areaId` at event level `level`.
function Balance.invasion(team: { Player }, areaId: string, level: number, opts: InvasionOpts?): Invasion
	local o: InvasionOpts = opts or {}
	local P = o.params or Balance.invasionParams()
	local avoidHit = o.avoidHit or 0
	local area = (Areas.areaById(areaId)) :: any
	assert(area, `Balance.invasion: unknown area {areaId}`)
	local n = #team
	local splitInside = o.splitInside or n
	local mods = AreaProfiles.modsOf(areaId)
	local profile = { hpMul = mods.hpMul, atkMul = mods.atkMul }
	local waveKinds = WorldEvents.waveKinds(area)
	local eliteKinds = WorldEvents.eliteKinds(area)
	local hostKinds = WorldEvents.hostKinds(area)
	local cluster = P.wave.cluster
	local size = math.min(P.wave.max, P.wave.base + P.wave.perPlayer * math.max(1, n))
	-- kill rates (monsters per second) of the party: every member fights its own cluster / Elite
	local normalRate, eliteRate = 0, 0
	local waveRatio = 0
	for _, p in team do
		local perNormal = meanOver(waveKinds, function(def): number
			local fight =
				FightSim.groupFight(p :: any, FightSim.group(def, level, cluster, "normal", profile), Balance.SKILL_DPS)
			return fight.seconds / cluster
		end)
		local perElite = if #eliteKinds > 0
			then meanOver(eliteKinds, function(def): number
				return FightSim.groupFight(p :: any, FightSim.group(def, level, 1, "elite", profile), Balance.SKILL_DPS).seconds
			end)
			else 0
		normalRate += 1 / math.max(1e-9, perNormal)
		if perElite > 0 then
			eliteRate += 1 / perElite
		end
		-- one cluster of the wave and an Elite on this member: taken per second against its sustain
		for _, id in waveKinds do
			local members = FightSim.group(Monsters.get(id), level, cluster, "normal", profile)
			if #eliteKinds > 0 then
				table.insert(members, FightSim.group(Monsters.get(eliteKinds[1]), level, 1, "elite", profile)[1])
			end
			local fight = FightSim.groupFight(p :: any, members, Balance.SKILL_DPS)
			local regen = p.values.hpRegenCombat or 0
			local taken = (fight.hpLost * fight.playerHp + regen * fight.seconds) / math.max(1e-9, fight.seconds)
			local own = 0
			for _, m in members do
				own = math.max(own, Balance.dps(p, m))
			end
			waveRatio = math.max(waveRatio, taken / math.max(1e-9, sustainOf(p, level, own)))
		end
	end
	-- the Elite II fought together (the last wave's and the commander): team DPS on it
	local function together(m: any, uptime: number): number
		local dps = 0
		for _, p in team do
			dps += Balance.dps(p, m) * uptime
		end
		return m.maxHp / math.max(1e-9, dps)
	end
	local elite2Seconds = if P.lastWaveElite2 and #hostKinds > 0
		then meanOver(hostKinds, function(def): number
			return together(FightSim.group(def, level, 1, "elite2", profile)[1], 1)
		end)
		else 0
	-- the waves: work (seconds of the party) queue
	local t, backlog, elites = 0, 0, 0
	local commanderAt = P.commanderAt
	for wave = 1, P.waves do
		local eliteCount = P.elitesPerWave[wave] or 0
		elites += eliteCount
		local work = size / normalRate + (if eliteRate > 0 then eliteCount / eliteRate else 0)
		if P.lastWaveElite2 and wave == P.waves then
			work += elite2Seconds
		end
		backlog += work
		-- the next wave (or the commander) when clearShare of this one is dead, after minWaveGap, at most waveEvery
		local need = math.max(0, backlog - (1 - P.clearShare) * work)
		local gap = math.clamp(need, P.minWaveGap, P.waveEvery)
		if t + gap >= P.commanderAt then
			gap = math.max(0, P.commanderAt - t)
		end
		backlog = math.max(0, backlog - gap)
		t += gap
		if t >= P.commanderAt then
			-- the waves not spawned yet never come
			break
		end
	end
	commanderAt = math.min(t, P.commanderAt)
	-- the commander: each host kind in turn, the mean time and the worst hits
	local cLevel = math.min(area.lv[2], level + 1)
	local hpMul = scaleIndex(P.commander.hp, n)
	local atkMul = scaleIndex(P.commander.atk, n)
	local cMods = { hpMul = profile.hpMul * hpMul, atkMul = profile.atkMul * atkMul }
	local commanderSeconds = 0
	local casts: { [string]: number } = {}
	local biggestHit: { [string]: number } = {}
	local biggestAvoidable: { [string]: number } = {}
	local split: { [string]: number } = {}
	local splitAlone: { [string]: number } = {}
	local missAll: { [string]: number } = {}
	local ratioOf: { [string]: number } = {}
	local commanderRatio = 0
	local function keepMax(t2: { [string]: number }, key: string, v: number)
		t2[key] = math.max(t2[key] or 0, v)
	end
	for _, id in hostKinds do
		local def = Monsters.get(id) :: any
		local m = FightSim.group(def, cLevel, 1, "elite2", cMods)[1]
		local seconds = together(m, Balance.BOSS_UPTIME)
		commanderSeconds += seconds / #hostKinds
		local own = m.ability
		local castsOf, casting = Balance.commanderCasts(own, P.abilities, P.gap, seconds)
		for k, v in castsOf do
			casts[k] = (casts[k] or 0) + v / #hostKinds
		end
		local taken: { number } = table.create(n, 0)
		-- basic attacks on the tank outside the casts (the next one half an interval after a cast)
		taken[1] += Balance.hit(m, team[1]) * math.max(0, seconds - casting) / m.attackInterval
		local all = table.clone(P.abilities)
		if own then
			table.insert(all, own)
		end
		for _, a in all do
			local count = castsOf[a.id] or 0
			local dodge = BossMechanics.isAvoidable(a)
			for i, p in team do
				local hit = Balance.hit(m, p, a.damage, a.damageKind, false)
				local top = hit * Combat.randomMax / p.values.maxHp
				local landed = 0
				if a.mechanic == "split" then
					local miss = if a.split then a.split.missAll else 0
					keepMax(split, p.classId, BossMechanics.splitShare(top, splitInside, miss))
					keepMax(splitAlone, p.classId, BossMechanics.splitShare(top, 1, miss))
					keepMax(missAll, p.classId, BossMechanics.splitShare(top, 0, miss))
					local mul = BossMechanics.splitShare(1, splitInside, miss)
					landed = if splitInside <= 0 or i <= splitInside then hit * mul * count else 0
				elseif dodge then
					keepMax(biggestAvoidable, p.classId, top)
					-- the threat cone on the tank, the random ones on 1 / n of the party
					local share = if a.origin == "random" then 1 / n else (if i == 1 then 1 else 0)
					landed = hit * avoidHit * share * count
				else
					-- its own ability: on the tank (SPECIAL_HIT), like Balance.elite2; the biggest hit as if on anyone
					keepMax(biggestHit, p.classId, top)
					if i == 1 then
						landed = hit * Balance.SPECIAL_HIT * count
					end
				end
				taken[i] += landed
			end
		end
		for _, p in team do
			keepMax(biggestHit, p.classId, Balance.hit(m, p) * Combat.randomMax / p.values.maxHp)
		end
		-- the raw intake per second against the sustain (which holds the regeneration)
		for i, p in team do
			local ratio = taken[i] / math.max(1e-9, seconds) / math.max(1e-9, sustainOf(p, cLevel, Balance.dps(p, m)))
			keepMax(ratioOf, p.classId, ratio)
			commanderRatio = math.max(commanderRatio, ratio)
		end
	end
	local seconds = commanderAt + backlog + commanderSeconds
	return {
		players = n,
		waveSize = size,
		elites = elites,
		waveSeconds = commanderAt,
		commanderAt = commanderAt,
		backlog = backlog,
		commanderSeconds = commanderSeconds,
		seconds = seconds,
		duration = P.duration,
		inTime = seconds <= P.duration,
		casts = casts,
		commanderRatio = commanderRatio,
		waveRatio = waveRatio,
		commanderRatioOf = ratioOf,
		biggestHit = biggestHit,
		biggestAvoidable = biggestAvoidable,
		split = split,
		splitAlone = splitAlone,
		missAll = missAll,
	}
end

-- S134c (E2): the Invasion targets (owner 2026-10-15: half way between "a hard group event for 3-5, solo almost
-- impossible" and "medium: solo possible but hard"). Every hunting ground of `areas` at its event level: 3 players
-- (Warrior + Hunter + Cleric, convention gear) end in time with a margin and survive the waves and the commander,
-- 5 players are faster than 3 and 3 faster than 2; solo on equal gear runs out of time, cannot hold the commander or
-- dies to the shared blow; solo with an edge (the event level + opGap, a Heroic set +6) wins in time; the commander's
-- big blows sit in the S134 band on a Mage of the event level, the shared blow is light for 3 and deadly alone.
Balance.S134c = {
	areas = {
		{ "meadows_goblincamp", 15 },
		{ "duskwood_cultvillage", 33 },
		{ "ashen_flats", 47 },
		{ "frostpeak_tundra", 85 },
	},
	teams = {
		[1] = { "Warrior" },
		[2] = { "Warrior", "Hunter" },
		[3] = { "Warrior", "Hunter", "Cleric" },
		[5] = { "Warrior", "Hunter", "Cleric", "Mage", "Warrior" },
	} :: { [number]: { string } },
	blows = { "Warrior", "Hunter", "Mage" }, -- the party whose Mage measures the commander's blows
	share3 = 0.8, -- 3 players: the whole event / duration
	sustain = 1.0, -- taken / sustain at the commander and on a cluster + Elite of the wave (3 players)
	avoid = { 0.60, 0.85 }, -- the biggest big blow / HP of a Mage of the event level (S134)
	split3 = 0.60, -- the shared blow on 3 players together / HP of the Mage
	splitSolo = 1.0, -- ... on a lone player standing in it
	missAll = 0.50, -- ... with nobody inside, on everyone
	soloHard = 0.9, -- solo "almost impossible": missAll + the biggest blow that cannot be dodged / HP of the Mage
	op = { rarity = Rarities.HEROIC, up = 6 }, -- the solo with an edge: this gear ...
	opGap = 5, -- ... at the event level + opGap
}

-- S134c: rows of targetsS134c out of reach of the S134c levers (printed with the reason; docs/DECYZJE.md S134c).
Balance.S134C_REPORT = {} :: { [string]: string }

-- A party of the classes at `level` (convention gear, or `gear`).
function Balance.classTeam(classes: { string }, level: number, gear: GearOpts?): { Player }
	local out: { Player } = {}
	for _, c in classes do
		table.insert(out, Balance.player(c, level, gear))
	end
	return out
end

local invasionCache: { [string]: Invasion } = {}
-- S134c: Balance.invasion cached by the party, the ground, the level and the options (the report and the spec read
-- the same fights).
function Balance.invasionOf(
	classes: { string },
	areaId: string,
	level: number,
	gear: GearOpts?,
	opts: InvasionOpts?,
	playerLevel: number?
): Invasion
	local key = `{table.concat(classes, ",")}|{areaId}|{level}|{playerLevel or level}|{if gear
		then `{gear.rarity or "-"}+{gear.up or 0}`
		else "-"}|{if opts and opts.params == Balance.INVASION_S101 then "S101" else "now"}|{if opts
		then tostring(opts.splitInside)
		else "-"}`
	local cached = invasionCache[key]
	if cached then
		return cached
	end
	local out = Balance.invasion(Balance.classTeam(classes, playerLevel or level, gear), areaId, level, opts)
	invasionCache[key] = out
	return out
end

-- S134c (E2): the Invasion targets in one place (ids "S134c.invasion.<area>..."); balance.spec ("Balance: Invasion
-- (S134c)") asserts every row without `report`.
function Balance.targetsS134c(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S134c
	local function add(
		id: string,
		group: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		lv: number?
	)
		target(rows, `S134c.invasion.{id}`, group, label, value, low, high, nil, lv)
	end
	for _, spec in S.areas do
		local areaId, L = spec[1], spec[2]
		local tag = `{areaId} L{L}`
		local seconds: { [number]: number } = {}
		for _, n in { 1, 2, 3, 5 } do
			seconds[n] = Balance.invasionOf(S.teams[n], areaId, L).seconds
		end
		local three = Balance.invasionOf(S.teams[3], areaId, L)
		add(`{areaId}.team3`, areaId, `{tag}: 3 graczy, czas / limit`, three.seconds / three.duration, nil, S.share3, L)
		add(
			`{areaId}.team3.commander`,
			areaId,
			`{tag}: 3 graczy, dowódca przyjmowane / podtrzymanie`,
			three.commanderRatio,
			nil,
			S.sustain,
			L
		)
		add(
			`{areaId}.team3.wave`,
			areaId,
			`{tag}: 3 graczy, gromada + Elita przyjmowane / podtrzymanie`,
			three.waveRatio,
			nil,
			S.sustain,
			L
		)
		add(`{areaId}.faster5`, areaId, `{tag}: czas 5 graczy / 3 graczy`, seconds[5] / seconds[3], nil, 1 - 1e-9, L)
		add(`{areaId}.faster3`, areaId, `{tag}: czas 3 graczy / 2 graczy`, seconds[3] / seconds[2], nil, 1 - 1e-9, L)
		-- the commander's blows on a Mage of the event level (the split with 3 together, alone, nobody inside)
		local blows = Balance.invasionOf(S.blows, areaId, L)
		add(
			`{areaId}.avoid.mage`,
			areaId,
			`{tag}: największy cios do uniknięcia / HP Maga`,
			blows.biggestAvoidable.Mage or 0,
			S.avoid[1],
			S.avoid[2],
			L
		)
		add(
			`{areaId}.split3.mage`,
			areaId,
			`{tag}: „Rozkaz”, 3 graczy razem / HP Maga`,
			blows.split.Mage or 0,
			nil,
			S.split3,
			L
		)
		add(
			`{areaId}.split.solo`,
			areaId,
			`{tag}: „Rozkaz” w pojedynkę w kręgu / HP Maga`,
			blows.splitAlone.Mage or 0,
			S.splitSolo,
			nil,
			L
		)
		add(
			`{areaId}.missAll.mage`,
			areaId,
			`{tag}: „Rozkaz”, pusty krąg / HP Maga`,
			blows.missAll.Mage or 0,
			nil,
			S.missAll,
			L
		)
		-- solo on equal gear: out of time, the commander out-damages the sustain, or the shared blow + a hit kill
		local solo = Balance.invasionOf(S.teams[1], areaId, L, nil, { splitInside = 0 })
		local combo = (blows.missAll.Mage or 0) + (blows.biggestHit.Mage or 0)
		local hard = not solo.inTime or solo.commanderRatio > S.sustain or combo >= S.soloHard
		add(
			`{areaId}.solo.hard`,
			areaId,
			`{tag}: solo na równym sprzęcie przegrywa albo ledwo (1 = tak)`,
			if hard then 1 else 0,
			1,
			nil,
			L
		)
		add(
			`{areaId}.solo.share`,
			areaId,
			`{tag}: solo na równym sprzęcie, czas / limit`,
			solo.seconds / solo.duration,
			nil,
			nil,
			L
		)
		-- solo with an edge wins in time and holds the commander
		local op = Balance.invasionOf(S.teams[1], areaId, L, S.op :: any, { splitInside = 0 }, L + S.opGap)
		add(
			`{areaId}.op.share`,
			areaId,
			`{tag}: solo L{L + S.opGap} Heroiczny +6, czas / limit`,
			op.seconds / op.duration,
			nil,
			1,
			L
		)
		add(
			`{areaId}.op.commander`,
			areaId,
			`{tag}: solo L{L + S.opGap} Heroiczny +6, dowódca przyjmowane / podtrzymanie`,
			op.commanderRatio,
			nil,
			S.sustain,
			L
		)
	end
	for _, row in rows do
		local why = Balance.S134C_REPORT[row.id]
		if why then
			row.report = `S134c: {why}`
		end
	end
	return rows
end

-- Elite II kit (S134e, docs/sessions/S134e.md C) ----------------------------------------------------------------------
-- Crushing Blow (lethal from the monster's level advantage), Pounce and the throw against kiting, Heavy Blow of the
-- Elites. One Elite II kind of a cave of each region (spawner level -> Elite II level spawner + 4): 26, 46, 66, 96.

Balance.S134e = {
	kinds = {
		{ kind = "werewolf", spawner = 22, map = "duskwood", cave = "duskwood_den" },
		{ kind = "necromancer", spawner = 42, map = "duskwood", cave = "duskwood_cave" },
		{ kind = "flameSmith", spawner = 62, map = "ashen", cave = "ashen_cave" },
		{ kind = "youngFrostDragon", spawner = 92, map = "frostpeak", cave = "frostpeak_cave" },
	},
	gaps = { 0, 5, 10, 15, 18 }, -- levels of the Elite II's advantage in the Crushing Blow table
	owner = { classId = "Mage", level = 48, kind = "flameSmith", spawner = 62 }, -- the owner's fight (2026-10-15)
	ownerGear = { rarity = 3, up = 3 }, -- Heroic +3 (the owner's gear)
	crushEqualMage = { 0.60, 0.80 }, -- a Crushing Blow not dodged at the Elite II's level: big, survivable
	crushEqualWarrior = 0.60,
	crushGap5Mage = 0.95, -- 5 levels below: still survivable from full HP
	crushGap10Mage = 1.05, -- 10 levels below: kills
	crushGap10Warrior = 0.85,
	crushOwner = 1.30,
	crushTrioTank = 0.70, -- on the tank of a trio at the level
	kiteGap15 = 1.0, -- a kiting solo 15 levels below loses (hpLost above it), dodging every telegraph
	kiteEqual = 0.8, -- a kiting solo at the level loses or ends at least this low (S32 "solo dies")
	trioGap10 = 1.0, -- a trio 10 levels below, owner's gear, Crushing Blow dodged: the tank's HP lost at most
	heavyBlowEqualMage = { 0.35, 0.50 }, -- Heavy Blow not dodged on a Mage at the Elite's level (report)
}

-- S134e: rows of targetsS134e out of reach of the S134e levers (printed with the reason; docs/DECYZJE.md S134e).
Balance.S134E_REPORT = {
	["S134e.kite.equal.werewolf.Mage"] = "a kiting Mage at the Elite II's level is not hurt enough by the throws (x1.25 at an equal level, about 0.08-0.09 of its HP every 2.6 s) to lose; the potions heal it between two hits; the lever is the potion interval (S54) or the S32 melee balance, not this session",
	["S134e.kite.equal.necromancer.Mage"] = "as the werewolf row: the throw at an equal level is a regular blow, the potions out-heal it",
	["S134e.kite.equal.flameSmith.Mage"] = "as the werewolf row: the throw at an equal level is a regular blow, the potions out-heal it",
	["S134e.kite.equal.youngFrostDragon.Mage"] = "as the werewolf row: the throw at an equal level is a regular blow, the potions out-heal it",
	["S134e.trio.gap10.werewolf"] = "the S32 melee model (Balance.elite2) has no Cleric healing and no potions; with the tank's potions (at most its max HP a drink) it ends at full HP; the S32 levers (Elite II HP and attack) are not this session's",
	["S134e.trio.gap10.necromancer"] = "as the werewolf row: no Cleric healing and no potions in the S32 model; with potions the tank ends at full HP",
	["S134e.trio.gap10.flameSmith"] = "as the werewolf row: no Cleric healing and no potions in the S32 model; with potions the tank ends at full HP",
	["S134e.trio.gap10.youngFrostDragon"] = "as the werewolf row: no Cleric healing and no potions in the S32 model; with potions the tank ends at full HP",
} :: { [string]: string }

-- S134e: one Crushing Blow not dodged on `classId` `gap` levels below the Elite II (`kind` at `spawner`) / its max HP.
function Balance.crushShare(classId: string, kind: string, spawner: number, gap: number, gear: GearOpts?): number
	local m = Balance.monster(kind, spawner, "elite2")
	local p = Balance.player(classId, m.level - gap, gear)
	return Balance.lethalHit(m, p, MonsterAbilities.get("crush")) / p.values.maxHp
end

-- S134e (D): one Heavy Blow not dodged on `classId` `gap` levels below an Elite (`kind` at `spawner`) / its max HP.
function Balance.heavyBlowShare(classId: string, kind: any, spawner: number, gap: number): number
	local m = Balance.monster(kind, spawner, "elite")
	local p = Balance.player(classId, m.level - gap)
	local blow = MonsterAbilities.get("heavyBlow") :: any
	return Balance.hit(m, p, blow.damage, blow.damageKind, false, blow.canCrit) / p.values.maxHp
end

-- S134e (D): the Elite kind and its spawner level of a cave (the first Elite spawner's kind, its top level).
function Balance.caveElite(mapId: string, caveId: string): (string?, number)
	for _, cave in Balance.caveSpawners(mapId) do
		if cave.id == caveId and #cave.elites > 0 then
			local e = cave.elites[1]
			return e.kind, e.max
		end
	end
	return nil, 0
end

-- S134e (C2): the targets in one place (ids "S134e.*"); balance.spec ("Balance: Elite II kit (S134e)") asserts every
-- row without `report`.
function Balance.targetsS134e(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S134e
	local function add(
		id: string,
		group: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		lv: number?
	)
		target(rows, `S134e.{id}`, group, label, value, low, high, nil, lv)
	end
	for _, spec in S.kinds do
		local kind, spawner = spec.kind, spec.spawner
		local m = Balance.monster(kind, spawner, "elite2")
		local L = m.level
		local tag = `{kind} L{L}`
		add(
			`crush.equal.{kind}.Mage`,
			"crush",
			`{tag}: Druzgocący Cios na Magu L{L} / HP`,
			Balance.crushShare("Mage", kind, spawner, 0),
			S.crushEqualMage[1],
			S.crushEqualMage[2],
			L
		)
		add(
			`crush.equal.{kind}.Warrior`,
			"crush",
			`{tag}: Druzgocący Cios na Wojowniku L{L} / HP`,
			Balance.crushShare("Warrior", kind, spawner, 0),
			nil,
			S.crushEqualWarrior,
			L
		)
		add(
			`crush.gap5.{kind}.Mage`,
			"crush",
			`{tag}: Druzgocący Cios na Magu L{L - 5} / HP`,
			Balance.crushShare("Mage", kind, spawner, 5),
			nil,
			S.crushGap5Mage,
			L
		)
		add(
			`crush.gap10.{kind}.Mage`,
			"crush",
			`{tag}: Druzgocący Cios na Magu L{L - 10} / HP`,
			Balance.crushShare("Mage", kind, spawner, 10),
			S.crushGap10Mage,
			nil,
			L
		)
		add(
			`crush.gap10.{kind}.Warrior`,
			"crush",
			`{tag}: Druzgocący Cios na Wojowniku L{L - 10} / HP`,
			Balance.crushShare("Warrior", kind, spawner, 10),
			S.crushGap10Warrior,
			nil,
			L
		)
		local tank = Balance.team(3, L)[1]
		add(
			`crush.notDodged.trio.{kind}`,
			"crush",
			`{tag}: Druzgocący Cios na tanku trójki L{L} / HP`,
			Balance.lethalHit(m, tank, MonsterAbilities.get("crush")) / tank.values.maxHp,
			nil,
			S.crushTrioTank,
			L
		)
		for _, c in { "Mage", "Hunter" } do
			local kite = Balance.elite2Kite(Balance.player(c, L - 15, S.ownerGear :: any), kind, spawner)
			add(
				`kite.gap15.{kind}.{c}`,
				"kite",
				`{tag}: {c} L{L - 15} (Heroiczne +3) ucieka i unika wszystkiego, HP stracone`,
				kite.hpLost,
				S.kiteGap15 + 1e-9,
				nil,
				L
			)
		end
		local equal = Balance.elite2Kite(Balance.player("Mage", L), kind, spawner)
		add(
			`kite.equal.{kind}.Mage`,
			"kite",
			`{tag}: Mag L{L} ucieka i unika wszystkiego, HP stracone`,
			equal.hpLost,
			S.kiteEqual,
			nil,
			L
		)
		local trio = Balance.elite2(
			Balance.classTeam({ "Warrior", "Mage", "Cleric" }, L - 10, S.ownerGear :: any),
			kind,
			spawner
		)
		add(
			`trio.gap10.{kind}`,
			"trio",
			`{tag}: W + M + K L{L - 10} (Heroiczne +3), cios uniknięty, HP tanka`,
			trio.hpLost,
			nil,
			S.trioGap10,
			L
		)
	end
	local o = S.owner
	local om = Balance.monster(o.kind, o.spawner, "elite2")
	local owner = Balance.player(o.classId, o.level, S.ownerGear :: any)
	add(
		"crush.owner",
		"crush",
		`{o.kind} L{om.level}: Druzgocący Cios na Magu L{o.level} (Heroiczne +3) / HP`,
		Balance.lethalHit(om, owner, MonsterAbilities.get("crush")) / owner.values.maxHp,
		S.crushOwner,
		nil,
		om.level
	)
	add(
		"kite.owner",
		"kite",
		`{o.kind} L{om.level}: Mag L{o.level} (Heroiczne +3) ucieka i unika wszystkiego, HP stracone`,
		Balance.elite2Kite(owner, o.kind, o.spawner).hpLost,
		S.kiteGap15 + 1e-9,
		nil,
		om.level
	)
	for _, row in rows do
		local why = Balance.S134E_REPORT[row.id]
		if why then
			row.report = `S134e: {why}`
		end
	end
	return rows
end

-- Full income (S109, docs/sessions/S109.md E1) ------------------------------------------------------------------------
-- The one-time quest gold in the distribution of the quest EXP credit, the gold of the extras outside economyAt and
-- the pace model (daily and weekly contracts, the boss contract, the login reward, world events) per hour of play, and
-- the full income of a player who does everything.

-- S109 (E1): the assumed player profile of the report and of the full-income targets; it is not a game number.
Balance.PLAY_PROFILE = table.freeze({
	hoursPerDay = 2, -- hours of play a day
	dailies = 3, -- daily contracts a day (Daily.PER_DAY)
	weekly = true, -- the weekly contracts (Weekly.PER_WEEK)
	bossContract = true, -- the weekly boss contract (from the first boss's entry level)
	login = true, -- the 7-day login streak
	eventsPer2h = 1, -- world events joined per 2 hours of play
})
export type PlayProfile = {
	hoursPerDay: number,
	dailies: number,
	weekly: boolean,
	bossContract: boolean,
	login: boolean,
	eventsPer2h: number,
}

export type QuestGoldRow = { main: number, side: number, boss: number, contract: number, total: number }

local questGoldCache: { [number]: QuestGoldRow }? = nil
-- S109 (E1): the gold of the one-time quests per level 1..99 in the distribution of questCreditByLevel (the story in
-- its windows without the boss objectives, SIDE_SHARE of the side quests over their band, the boss quests over their
-- band, the contract on its level; no carry). questsAt(L).gold (economyAt, levelIncome) keeps the quests on their own
-- level and levelIncome spreads them over the band: the band sums are the same (DECYZJE S109).
function Balance.questGoldByLevel(): { [number]: QuestGoldRow }
	if questGoldCache then
		return questGoldCache
	end
	local out: { [number]: QuestGoldRow } = {}
	for L = 1, Config.MaxLevel - 1 do
		out[L] = { main = 0, side = 0, boss = 0, contract = 0, total = 0 }
	end
	local function add(L: number, category: string, value: number)
		local row: any = out[L]
		if not row then
			return
		end
		row[category] += value
		row.total += value
	end
	local sources = questSources(true)
	local starts: { number } = {}
	for _, source in sources do
		for _, q in source.list do
			if CREDIT_RULES[q.category or "main"].spread == "window" and not hasBoss(q) then
				if not table.find(starts, q.level) then
					table.insert(starts, q.level)
				end
			end
		end
	end
	table.sort(starts)
	for _, source in sources do
		for _, q in source.list do
			local category: string = q.category or "main"
			local rule = CREDIT_RULES[category]
			local gold = q.reward.gold or 0
			if rule.spread == "window" then
				if not hasBoss(q) then
					local i = table.find(starts, q.level) :: number
					local last = if starts[i + 1] then starts[i + 1] - 1 else math.max(q.level, Config.MaxLevel - 1)
					local need = 0
					for L = q.level, last do
						need += Exp.expToNext(L)
					end
					for L = q.level, last do
						add(L, category, gold * Exp.expToNext(L) / need)
					end
				end
			elseif rule.spread == "band" then
				if q.level < Config.MaxLevel then
					local lo, hi = QuestBudget.bandOf(q.level)
					local need = 0
					for L = lo, hi do
						need += Exp.expToNext(L)
					end
					for L = lo, hi do
						add(L, category, gold * rule.share * Exp.expToNext(L) / need)
					end
				end
			else
				add(q.level, category, gold * rule.share)
			end
		end
	end
	questGoldCache = out
	return out
end

-- Hours of grinding of `level` for `classId` (the kills of the pace window model at the economyAt pace, like
-- levelIncome).
function Balance.levelHours(classId: string, level: number): number
	local e = Balance.economyAt(classId, level)
	return creditRows({})[level].need / e.pace.expPerKill * e.pace.secondsPerKill / 3600
end

export type Extras = {
	daily: number,
	weekly: number,
	bossContract: number,
	login: number,
	events: number,
	total: number,
}

local function profileOf(profile: PlayProfile?): PlayProfile
	return profile or (Balance.PLAY_PROFILE :: any)
end

-- S109 (E1): gold per hour of play from the extras outside economyAt. Gold only: the reward items (blessings,
-- essences, potions, stones, the chests) are consumables, not income, like the chest items of S100 / S101.
function Balance.extrasPerHour(classId: string, level: number, profile: PlayProfile?): Extras
	local p = profileOf(profile)
	local hpd = p.hoursPerDay
	local function value(r: any): number
		return r.gold or 0
	end
	local daily = p.dailies * value(Quests.Daily.reward(level)) / hpd
	local weekly = if p.weekly then Quests.Weekly.PER_WEEK * value(Quests.Weekly.reward(level)) / (7 * hpd) else 0
	local boss = if p.bossContract and QuestLogic.bossContractFor(level) ~= nil
		then value(Quests.Weekly.bossReward(level)) / (7 * hpd)
		else 0
	local login = if p.login then Balance.loginWeek(classId, level).gold / (7 * hpd) else 0
	local events = p.eventsPer2h / 2 * WorldEvents.reward(level, level, true).gold
	return {
		daily = daily,
		weekly = weekly,
		bossContract = boss,
		login = login,
		events = events,
		total = daily + weekly + boss + login + events,
	}
end

-- S109 (C2): EXP per hour of play from the extras (daily, weekly, the boss contract, world events; the login reward
-- gives no EXP).
function Balance.extrasExpPerHour(level: number, profile: PlayProfile?): Extras
	local p = profileOf(profile)
	local hpd = p.hoursPerDay
	local daily = p.dailies * (Quests.Daily.reward(level).exp or 0) / hpd
	local weekly = if p.weekly then Quests.Weekly.PER_WEEK * (Quests.Weekly.reward(level).exp or 0) / (7 * hpd) else 0
	local boss = if p.bossContract and QuestLogic.bossContractFor(level) ~= nil
		then (Quests.Weekly.bossReward(level).exp or 0) / (7 * hpd)
		else 0
	local events = p.eventsPer2h / 2 * WorldEvents.reward(level, level, true).exp
	return {
		daily = daily,
		weekly = weekly,
		bossContract = boss,
		login = 0,
		events = events,
		total = daily + weekly + boss + events,
	}
end

-- S109 (E1): gold per hour of a player who does everything (grinding + extras).
function Balance.fullIncome(classId: string, level: number): number
	return Balance.economyAt(classId, level).incomePerHour + Balance.extrasPerHour(classId, level).total
end

-- S109 (T-EC4, T-EC5): the gold of a level for a player who does everything: levelIncome plus the extras over the
-- hours of grinding of the level.
function Balance.fullLevelIncome(classId: string, level: number): number
	return Balance.levelIncome(classId, level)
		+ Balance.extrasPerHour(classId, level).total * Balance.levelHours(classId, level)
end

-- S109 (E2): the full-income targets (test tooling, not game numbers). The new gold only lowers relative costs, so
-- the upper bounds of S84 / S92-S94 (upgrades, potions) stay on the grinding income and the lower ones (sinks:
-- backpacks, the +9 set, the chain potions' floor) are checked on the full income.
Balance.FULL_INCOME = table.freeze({
	questGold = 0.25, -- T-EC2: one-time quest gold / grinding income of the level, mean of 5 levels, L 21..99 (max)
	-- S109: T-EC2 poza zasięgiem dźwigni S109 na 21-32: złoto fabuły gold(level) (S27/S32, poza E4); rozdział II ma
	-- zadanie prawie co poziom, a poziom trwa 0,3-0,6 h (raport; od 33. asercja)
	questGoldReportTo = 32,
	extras = 0.35, -- T-EC3: extras / grinding income per hour, mean of the band 20-44, 45-69, 70-99 (max)
	backpacks = {
		{ id = "backpack_80", level = 25 },
		{ id = "backpack_100", level = 35 },
		{ id = "backpack_130", level = 50 },
	},
	backpackLevels = 3, -- T-EC4: levels of full income (min; the max 8 stays on the grinding income)
	bigBackpacks = { { id = "backpack_160", level = 65 }, { id = "backpack_200", level = 80 } },
	bigBackpackLevels = 5, -- T-EC5 (min; the max 12 stays on the grinding income)
	set9Hours = 150, -- T-EC6: the protected +9 set at L99, hours at full income (min; the max 300 on the ground alone)
	chainPotions = 0.15, -- T-EC7: chain potions / full income where S93 / S94 assert the 15% floor (min)
	chainLevels = { { 46, 69 }, { 71, 99 } }, -- the levels of the S93 / S94 chainLow rows
	reportLevels = { 10, 20, 30, 45, 60, 70, 85, 99 }, -- T-EC8
	reportClasses = { "Warrior", "Mage" },
})

export type IncomeRow = {
	id: string,
	label: string,
	value: number,
	band: { lo: number?, hi: number? },
	ok: boolean,
	report: boolean,
	why: string?,
	worst: string?, -- where the value comes from (class, level)
}

-- S109 (E2): the T-EC rows (T-EC2..T-EC7 asserted, one row per target with its worst value).
local fullIncomeCache: { IncomeRow }? = nil
function Balance.fullIncomeRows(): { IncomeRow }
	if fullIncomeCache then
		return fullIncomeCache
	end
	local F = Balance.FULL_INCOME
	local rows: { IncomeRow } = {}
	local function row(id: string, label: string, value: number, lo: number?, hi: number?, worst: string?)
		local ok = (lo == nil or value >= lo) and (hi == nil or value <= hi)
		table.insert(rows, {
			id = id,
			label = label,
			value = value,
			band = { lo = lo, hi = hi },
			ok = ok,
			report = false,
			worst = worst,
		})
	end
	-- T-EC2: one-time quest gold / grinding income of the level, moving mean of 5 levels (the worst class); 21..
	-- questGoldReportTo in the report (FULL_INCOME), the rest asserted
	local gold = Balance.questGoldByLevel()
	local worst = { { value = -1, at = "-" }, { value = -1, at = "-" } }
	for _, c in Balance.CLASSES do
		local share: { [number]: number } = {}
		for L = 20, 99 do
			local e = Balance.economyAt(c, L)
			share[L] = gold[L].total / math.max(1e-9, e.incomePerHour * Balance.levelHours(c, L))
		end
		for L = 21, 99 do
			local sum, n = 0, 0
			for k = math.max(20, L - 2), math.min(99, L + 2) do
				sum += share[k]
				n += 1
			end
			local part = worst[if L <= F.questGoldReportTo then 1 else 2]
			if sum / n > part.value then
				part.value, part.at = sum / n, `{c} {L}`
			end
		end
	end
	local cut = F.questGoldReportTo
	row(
		"T-EC2.21",
		`złoto zadań jednorazowych / dochód poziomu z gry (średnia 5 poziomów, 21–{cut})`,
		worst[1].value,
		nil,
		F.questGold,
		worst[1].at
	)
	rows[#rows].report = true
	rows[#rows].why =
		`poza zasięgiem dźwigni S109: złoto fabuły gold(level) (S27/S32) poza E4; rozdział II ma zadanie prawie co poziom, a poziom trwa 0,3–0,6 h`
	row(
		`T-EC2.{cut + 1}`,
		`złoto zadań jednorazowych / dochód poziomu z gry (średnia 5 poziomów, {cut + 1}–99)`,
		worst[2].value,
		nil,
		F.questGold,
		worst[2].at
	)
	-- T-EC3: extras / grinding income per hour, mean over the band's levels (the worst class)
	for _, band in { { 20, 44 }, { 45, 69 }, { 70, 99 } } do
		local w, at = -1, "-"
		for _, c in Balance.CLASSES do
			local sum, n = 0, 0
			for L = band[1], band[2] do
				sum += Balance.extrasPerHour(c, L).total / math.max(1e-9, Balance.economyAt(c, L).incomePerHour)
				n += 1
			end
			if sum / n > w then
				w, at = sum / n, c
			end
		end
		row(`T-EC3.{band[1]}`, `dodatki / dochód z gry na godzinę, {band[1]}–{band[2]}`, w, nil, F.extras, at)
	end
	-- T-EC4 / T-EC5: backpacks in levels of full income at the shop level (the lowest class)
	local function bags(id: string, list: { any }, min: number)
		for _, b in list do
			local item = Items.get(b.id) :: any
			local low, at = math.huge, "-"
			for _, c in Balance.CLASSES do
				local levels = item.buyPrice / math.max(1e-9, Balance.fullLevelIncome(c, b.level))
				if levels < low then
					low, at = levels, c
				end
			end
			row(`{id}.{b.id}`, `{b.id} (od {b.level}.) w poziomach pełnego dochodu`, low, min, nil, `{at} {b.level}`)
		end
	end
	bags("T-EC4", F.backpacks, F.backpackLevels)
	bags("T-EC5", F.bigBackpacks, F.bigBackpackLevels)
	-- T-EC6: the protected +9 set at L99 at full income on the best gold ground (Warrior, like S94)
	do
		local set = Balance.protectedSet("Warrior", 99)
		local hours = set.goldEq / math.max(1e-9, set.perHour + Balance.extrasPerHour("Warrior", 99).total)
		row(
			"T-EC6",
			`komplet +9 z ochroną (L99) przy pełnym dochodzie ({set.area}): h`,
			hours,
			F.set9Hours,
			nil,
			"Warrior 99"
		)
	end
	-- T-EC7: chain potions / full income on the levels where S93 / S94 assert the floor (the lowest)
	do
		local low, at = math.huge, "-"
		for _, range in F.chainLevels do
			for L = range[1], range[2] do
				for _, c in Balance.CLASSES do
					local e = Balance.economyAt(c, L, { potions = "chain" })
					local share = e.potionGold / math.max(1e-9, e.incomePerHour + Balance.extrasPerHour(c, L).total)
					if share < low then
						low, at = share, `{c} {L}`
					end
				end
			end
		end
		row(
			"T-EC7",
			"mikstury łańcuchowe / pełny dochód (poziomy dolnej granicy S93 / S94)",
			low,
			F.chainPotions,
			nil,
			at
		)
	end
	fullIncomeCache = rows
	return rows
end

export type FullIncomeReport = {
	classId: string,
	level: number,
	grind: number, -- gold per hour of grinding (economyAt)
	quests: number, -- one-time quest gold per hour of the level (questGoldByLevel over the level's hours)
	extras: Extras,
	total: number,
}

-- S109 (T-EC8): one report row (gold per hour of play).
function Balance.fullIncomeReport(classId: string, level: number): FullIncomeReport
	local grind = Balance.economyAt(classId, level).incomePerHour
	local hours = math.max(1e-9, Balance.levelHours(classId, level))
	local quests = Balance.questGoldByLevel()[math.min(level, Config.MaxLevel - 1)].total / hours
	local extras = Balance.extrasPerHour(classId, level)
	return {
		classId = classId,
		level = level,
		grind = grind,
		quests = quests,
		extras = extras,
		total = grind + quests + extras.total,
	}
end

-- S128 (DESIGN-17 §6, H1): Arena Tokens of three player profiles per day and week (from Data/Arena, the same
-- ArenaRules.tokensFor the server calls, the week cap from an empty week) and, per arena shop entry, the days of the
-- profile "3 matches a day, 50% wins" to buy it, with the gold price of the same items at the merchants.
export type ArenaProfile = { id: string, perDay: number, perWeek: number, capDays: number }
export type ArenaShopRow = { key: string, kind: string, price: number, days: number, gold: number? }
export type ArenaTokens = { profiles: { ArenaProfile }, shop: { ArenaShopRow }, cap: number }

function Balance.arenaTokens(): ArenaTokens
	local function day(mode: string, matches: number): number
		local total = 0
		for i = 1, matches do
			-- 50% wins: half a win and half a loss of every match, with the daily bonus of the first ones
			local win = ArenaRules.tokensFor(mode, "win", i - 1, 0, true, false)
			local loss = ArenaRules.tokensFor(mode, "loss", i - 1, 0, true, false)
			total += (win + loss) / 2
		end
		return total
	end
	local cap = ArenaData.tokensWeekCap
	local function profile(id: string, perDay: number): ArenaProfile
		local perWeek = math.min(cap, perDay * 7)
		return { id = id, perDay = perDay, perWeek = perWeek, capDays = cap / perDay }
	end
	local profiles = {
		profile("1v1x3", day("1v1", 3)),
		profile("1v1x10", day("1v1", 10)),
		profile("3v3x3", day("3v3", 3)),
	}
	local base = profiles[1].perDay
	local shop: { ArenaShopRow } = {}
	for _, entry in ArenaData.SHOP do
		local gold: number? = nil
		if entry.kind == "item" then
			local def = Items.get(entry.id)
			-- the merchant's price (an item sold by NPCs has a fixed buyPrice: 5 stones = 5 × 20), else the item price
			local unit = if def
					and def.buyPrice
					and def.buyPrice > 0
				then def.buyPrice
				elseif def then def.price or 0
				else 0
			gold = if def then unit * (entry.n or 1) else nil
		end
		table.insert(
			shop,
			{ key = entry.key, kind = entry.kind, price = entry.price, days = entry.price / base, gold = gold }
		)
	end
	return { profiles = profiles, shop = shop, cap = cap }
end

-- S129: the Blood Moon (Data/ScheduledEvents.bloodMoon): how many Elites a group of an open region brings in one
-- occurrence when it is killed as soon as it respawns (the respawn window of a hunting ground, AreaSpawns.RESPAWN
-- without a profile), and what the participation reward weighs against the arena's week cap.
export type BloodMoonRow = { id: string, respawn: number, respawns: number, elites: number }
export type BloodMoonBalance = {
	duration: number,
	eliteChance: number,
	rows: { BloodMoonRow },
	tokens: number,
	tokensShare: number, -- of Data/Arena.tokensWeekCap
	shards: number,
	perWeek: number, -- occurrences a week
}

function Balance.bloodMoon(): BloodMoonBalance
	local rules = ScheduledEvents.bloodMoon
	local def = ScheduledEvents.get("bloodmoon") :: ScheduledEvents.EventDef
	local rows: { BloodMoonRow } = {}
	local function row(id: string, window: { min: number, max: number })
		local respawn = (window.min + window.max) / 2
		local respawns = def.duration / respawn
		table.insert(rows, { id = id, respawn = respawn, respawns = respawns, elites = respawns * rules.eliteChance })
	end
	row("default", AreaSpawns.RESPAWN)
	for _, id in AreaProfiles.order do
		local profile = AreaProfiles.get(id)
		if profile then
			row(id, profile.respawn)
		end
	end
	return {
		duration = def.duration,
		eliteChance = rules.eliteChance,
		rows = rows,
		tokens = rules.reward.tokens,
		tokensShare = rules.reward.tokens / ArenaData.tokensWeekCap,
		shards = rules.reward.shards,
		perWeek = #def.slots,
	}
end

-- S134g: Legendary and Mythic with skill effects (docs/sessions/S134g.md E) ------------------------------------------
-- The stats of a Legendary / Mythic against a Heroic of the same level, the levels a Heroic needs to catch up
-- (rarityEdge, ItemScore with the expected effect points) and the owner's case (Legendary L36 against Heroic L48).
-- Expected lines here are smooth (the middle of ItemRoll.bonusRange, not rounded): the rounded middle of
-- expectedBonuses turns +5 % of a small integer line into +33 % (3 -> 4), which no player gets on average.

-- S134g test data (targets of the rarity tuning; never game numbers).
Balance.S134g = {
	levels = { 20, 45, 70, 100 }, -- stats and order rows
	edgeLevels = { 20, 45, 70 }, -- edge rows (the Heroic up to 9 levels above stays below the level cap)
	reportLevels = { 20, 36, 45, 70, 90 }, -- the report table
	slots = { "weapon", "armor", "ring", "necklace", "talisman" },
	statsLegendary = { 1.03, 1.07 }, -- A2: ItemScore without effects, Legendary / Heroic of the same level
	statsMythic = { 1.08, 1.12 }, -- A2: Mythic / Heroic
	edgeLegendary = { 2, 5 }, -- E2: levels a Heroic needs to beat a Legendary with its effect
	edgeMythic = { 5, 9 },
	owner = { legendary = 36, heroic = 48 }, -- owner 2026-10-15: a Legendary L36 beat a Heroic L48
	edgeMax = 40, -- the search stops here
	-- the measurement before S134g (state 699ce83: Legendary x1.16 / 1.1 + a legendary line, Mythic x1.22 / 1.2 + 3 lines;
	-- ItemScore of expectedBonuses, levels 20 / 36 / 45 / 70): { legendary edge, mythic edge } per class and slot
	before = {
		Warrior = {
			weapon = { { 1, 5 }, { 1, 6 }, { 2, 7 }, { 3, 9 } },
			armor = { { 6, 27 }, { 7, 28 }, { 8, 30 }, { 9, 32 } },
			ring = { { 40, 40 }, { 40, 40 }, { 40, 40 }, { 40, 40 } },
		},
		Hunter = {
			weapon = { { 1, 5 }, { 2, 7 }, { 2, 8 }, { 3, 10 } },
			armor = { { 9, 37 }, { 9, 39 }, { 10, 40 }, { 12, 40 } },
			ring = { { 40, 40 }, { 40, 40 }, { 40, 40 }, { 40, 40 } },
		},
		Mage = {
			weapon = { { 1, 5 }, { 1, 6 }, { 2, 7 }, { 3, 9 } },
			armor = { { 7, 29 }, { 7, 30 }, { 8, 31 }, { 9, 33 } },
			ring = { { 40, 40 }, { 40, 40 }, { 40, 40 }, { 40, 40 } },
		},
		Cleric = {
			weapon = { { 1, 4 }, { 1, 6 }, { 2, 7 }, { 3, 8 } },
			armor = { { 5, 21 }, { 5, 23 }, { 6, 24 }, { 7, 27 } },
			ring = { { 40, 40 }, { 40, 40 }, { 40, 40 }, { 40, 40 } },
		},
	},
	beforeLevels = { 20, 36, 45, 70 },
	-- the owner's case before (ItemScore Legendary L36 / Heroic L48): weapon 629 / 774, armour 94 / 102, ring 31 / 21,
	-- necklace 31 / 22 (Warrior; the other classes alike)
}

-- The base type of a slot name of S134g.slots for `classId` (the default loadout's weapon and armour weight).
function Balance.s134gBase(classId: string, slot: string): string
	local loadout = Balance.LOADOUT[classId]
	if slot == "weapon" then
		return loadout.weapon
	elseif slot == "armor" then
		return `armor_{loadout.weight}`
	end
	return slot
end

local smoothCache: { [string]: { any } } = {}
-- Expected lines of a new item like expectedBonuses (ItemRoll.inclusion of the weighted pool, family markers spread),
-- with the unrounded middle of every range.
function Balance.smoothBonuses(defId: string, ilvl: number, rarity: number, classId: string?): { any }
	local key = `{defId}|{ilvl}|{rarity}|{classId}`
	local cached = smoothCache[key]
	if cached then
		return cached
	end
	local rarityDef = Rarities.get(rarity)
	local out = {}
	if rarityDef.bonusMax > 0 then
		local weights = ItemRoll.poolWeights(defId, classId)
		local share: { [string]: number } = {}
		local n = rarityDef.bonusMax - rarityDef.bonusMin + 1
		for k = rarityDef.bonusMin, rarityDef.bonusMax do
			for id, p in ItemRoll.inclusion(weights, k) do
				share[id] = (share[id] or 0) + p / n
			end
		end
		local function middle(id: string): number
			local low, high = ItemRoll.bonusRange(id, ilvl, rarity)
			return (low + high) / 2
		end
		for _, id in poolFor(defId, classId) do
			local s = share[id] or 0
			local param = Bonuses.params[id]
			if not param then
				table.insert(out, { stat = id, v = middle(id) * s })
			elseif param.over == "family" then
				for _, family in Families.ids do
					local variant = Bonuses.familyLine(param.prefix, family)
					table.insert(out, { stat = variant, v = middle(variant) * s * FAMILY_MATCH })
				end
			end
		end
	end
	smoothCache[key] = out
	return out
end

-- ItemScore of the expected item of `slot` for `classId` at `ilvl` and `rarity` (+0); `withFx` adds the expected
-- effect points of the rarity (ItemScore.expectedEffectPoints).
function Balance.rarityScore(classId: string, slot: string, ilvl: number, rarity: number, withFx: boolean?): number
	local id = tierId(Balance.s134gBase(classId, slot), ilvl)
	local item = makeItem(id, ilvl, rarity, 0, Balance.smoothBonuses(id, ilvl, rarity, classId))
	local score = ItemScore.score(item, { classId = classId, level = ilvl })
	if withFx then
		score += ItemScore.expectedEffectPoints(classId, rarity)
	end
	return score
end

-- A2: stats (no effects) of `rarity` / Heroic, same slot, level and upgrade.
function Balance.rarityStats(classId: string, slot: string, ilvl: number, rarity: number): number
	return Balance.rarityScore(classId, slot, ilvl, rarity) / Balance.rarityScore(classId, slot, ilvl, Rarities.HEROIC)
end

-- E2: the most levels g a Heroic of the same slot can be above an item of `rarity` at `ilvl` (with its expected
-- effects) and still not beat it (ItemScore; the Heroic at ilvl + g is the same base type at that level, like a drop).
-- Never past the level cap (Config.MaxLevel) or S134g.edgeMax.
function Balance.rarityEdge(classId: string, ilvl: number, rarity: number, slot: string?): number
	local s = slot or "weapon"
	local score = Balance.rarityScore(classId, s, ilvl, rarity, true)
	local g = 0
	while
		g < Balance.S134g.edgeMax
		and ilvl + g + 1 <= Config.MaxLevel
		and Balance.rarityScore(classId, s, ilvl + g + 1, Rarities.HEROIC) <= score
	do
		g += 1
	end
	return g
end

-- S134g: rows of targetsS134g out of reach of the S134g levers (printed with the reason; docs/DECYZJE.md S134g).
Balance.S134G_REPORT = {} :: { [string]: string }
do
	local report = Balance.S134G_REPORT
	local slotWhy = "an effect is a fixed estimate in ItemScore (Data/ItemEffects score, 3-7 % of an axis = 6-14 points) "
		.. "while armour scores 5-10x and jewellery 20-30x fewer points than a weapon, so the same effect is many levels "
		.. "there (jewellery barely grows with the level since S87: its % lines stop at ilvl 20); the levers (effect "
		.. "estimates) are the effects' real value, the weapon rows are asserted"
	for _, c in Balance.CLASSES do
		for _, slot in { "armor", "ring", "necklace", "talisman" } do
			for _, L in Balance.S134g.edgeLevels do
				report[`S134g.edge.legendary.{c}.{slot}.{L}`] = slotWhy
				report[`S134g.edge.mythic.{c}.{slot}.{L}`] = slotWhy
			end
		end
		for _, slot in { "ring", "necklace", "talisman" } do
			report[`S134g.ownerFx.{c}.{slot}`] = "jewellery does not grow with the level (S87: % lines stop at ilvl 20), "
				.. "so any effect > 0 beats a Heroic of any level; the owner's row on jewellery is asserted on the stats"
		end
		local lowWhy = "at L20 a weapon gains about 4 % a level, so +4-9 % of stats (A2: at most 1.07 / 1.12) and an "
			.. "effect worth about 1 % of a weapon's score are 1-3 levels; the band holds from L45"
		report[`S134g.edge.legendary.{c}.weapon.20`] = lowWhy
		report[`S134g.edge.mythic.{c}.weapon.20`] = lowWhy
	end
end

-- S134g (E2): the targets in one place (ids "S134g.*"); balance.spec ("Balance: Legendary and Mythic (S134g)") asserts
-- every row without `report`.
function Balance.targetsS134g(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S134g
	local function add(
		id: string,
		group: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		c: string?,
		L: number?
	)
		target(rows, `S134g.{id}`, group, label, value, low, high, c, L)
	end
	local JEWELLERY: { [string]: boolean } = { ring = true, necklace = true, talisman = true }
	for _, c in Balance.CLASSES do
		for _, slot in S.slots do
			for _, L in S.levels do
				add(
					`stats.legendary.{c}.{slot}.{L}`,
					"stats",
					`{c} {slot} L{L}: Legendarny / Heroiczny (statystyki)`,
					Balance.rarityStats(c, slot, L, Rarities.LEGENDARY),
					S.statsLegendary[1],
					S.statsLegendary[2],
					c,
					L
				)
				add(
					`stats.mythic.{c}.{slot}.{L}`,
					"stats",
					`{c} {slot} L{L}: Mityczny / Heroiczny (statystyki)`,
					Balance.rarityStats(c, slot, L, Rarities.MYTHIC),
					S.statsMythic[1],
					S.statsMythic[2],
					c,
					L
				)
				local h = Balance.rarityScore(c, slot, L, Rarities.HEROIC, true)
				local l = Balance.rarityScore(c, slot, L, Rarities.LEGENDARY, true)
				local m = Balance.rarityScore(c, slot, L, Rarities.MYTHIC, true)
				add(
					`order.legendary.{c}.{slot}.{L}`,
					"order",
					`{c} {slot} L{L}: Legendarny − Heroiczny (z efektem)`,
					l - h,
					1e-9,
					nil,
					c,
					L
				)
				add(
					`order.mythic.{c}.{slot}.{L}`,
					"order",
					`{c} {slot} L{L}: Mityczny − Legendarny (z efektami)`,
					m - l,
					1e-9,
					nil,
					c,
					L
				)
			end
			for _, L in S.edgeLevels do
				add(
					`edge.legendary.{c}.{slot}.{L}`,
					"edge",
					`{c} {slot} L{L}: poziomy, które Heroiczny potrzebuje na Legendarny`,
					Balance.rarityEdge(c, L, Rarities.LEGENDARY, slot),
					S.edgeLegendary[1],
					S.edgeLegendary[2],
					c,
					L
				)
				add(
					`edge.mythic.{c}.{slot}.{L}`,
					"edge",
					`{c} {slot} L{L}: poziomy, które Heroiczny potrzebuje na Mityczny`,
					Balance.rarityEdge(c, L, Rarities.MYTHIC, slot),
					S.edgeMythic[1],
					S.edgeMythic[2],
					c,
					L
				)
			end
			-- The owner's case: Heroic L48 - Legendary L36 above 0. Weapons and armour with the effect; jewellery on its
			-- stats (its lines stop growing at ilvl 20, S87, so any effect beats a Heroic of any level: report row).
			local o = S.owner
			local heroic = Balance.rarityScore(c, slot, o.heroic, Rarities.HEROIC)
			local legendary = Balance.rarityScore(c, slot, o.legendary, Rarities.LEGENDARY, not JEWELLERY[slot])
			local what = if JEWELLERY[slot] then "statystyki" else "z efektem"
			add(
				`owner.{c}.{slot}`,
				"owner",
				`{c} {slot}: Heroiczny L{o.heroic} − Legendarny L{o.legendary} ({what})`,
				heroic - legendary,
				1e-9,
				nil,
				c,
				o.legendary
			)
			if JEWELLERY[slot] then
				add(
					`ownerFx.{c}.{slot}`,
					"owner",
					`{c} {slot}: Heroiczny L{o.heroic} − Legendarny L{o.legendary} (z efektem)`,
					heroic - Balance.rarityScore(c, slot, o.legendary, Rarities.LEGENDARY, true),
					1e-9,
					nil,
					c,
					o.legendary
				)
			end
		end
	end
	for _, row in rows do
		local why = Balance.S134G_REPORT[row.id]
		if why then
			row.report = `S134g: {why}`
		end
	end
	return rows
end

-- Bonus reroll (S134j, docs/sessions/S134j.md F) -------------------------------------------------------------------
-- The class weapon of ilvl L - GEAR_GAP (like upgradeVsIncome) at a rarity; Reroll.costAt for every attempt (the count
-- grows like in the game). goldEq with Balance.materialPrices; hours = essence hours of the level's grinding
-- (materialSupply.normal, materialHours with transmutation) + gold / economyAt.incomePerHour. The reroll is optional
-- and outside the game's pace (no row of G9, the material demand / supply or balance1_20 changes).

Balance.S134j = {
	firstVsUpgrade = { 0.3, 1.0 }, -- first attempt / one +7 upgrade attempt of the same item (goldEq)
	tenHours = { 1, 4 }, -- 10 attempts on a Heroic / Legendary / Mythic at L 45 / 70 / 100, hours of the level
	tenHoursUnique = { 0.5, 2 }, -- 10 attempts on a Unique L20
	sink = { 0.10, 0.35 }, -- essence of 10 attempts on every newly worn item / essence of the band
	stone = 0.10, -- one stone a day / the essence of 2 h of play (L45+)
	stoneHours = 2,
	attempts = 10,
	levels = { 20, 45, 70, 100 },
	-- band -> the rarity worn in it (one item per slot per band; D5 has no "items worn" function: DECYZJE S134j)
	sinkBands = {
		{ band = { 20, 45 }, rarity = 3 },
		{ band = { 45, 70 }, rarity = 4 },
		{ band = { 70, 100 }, rarity = 5 },
	},
}
Balance.S134J_REPORT = {} :: { [string]: string }
-- S134j: first.vsUpgrade 0.3-1.0 poza zasięgiem: with 0.3 of a +7 attempt the first reroll alone costs 0.37-0.55 h of
-- the level's income, so 10 attempts (x21.25 with growth 0.25) take 8-12 h and ten.hours (1-4 h, the owner's ~2 h) fails
-- for every config; ten.hours, sink and stone kept (first attempt 0.02-0.06 of a +7 attempt; docs/DECYZJE.md S134j).
for _, key in { "unique.L20", "heroic.L45", "heroic.L70", "heroic.L100", "legendary.L45" } do
	Balance.S134J_REPORT[`S134j.first.vsUpgrade.{key}`] = "0.3-1.0 poza zasięgiem (sprzeczne z ten.hours)"
end
for _, key in { "legendary.L70", "legendary.L100", "mythic.L45", "mythic.L70", "mythic.L100" } do
	Balance.S134J_REPORT[`S134j.first.vsUpgrade.{key}`] = "0.3-1.0 poza zasięgiem (sprzeczne z ten.hours)"
end
-- S134j: sink.income (+9 of the set with protection + 10 attempts on the set <= the band's gold income) poza zasięgiem:
-- the +9 alone is 6.9-14.9 x the band's income (G9 goldEq9: +9 is a long-term goal paid over many bands, a lever outside
-- Config.Reroll); the reroll adds 0.4-0.5 of the income (docs/DECYZJE.md S134j).
for _, c in Balance.CLASSES do
	for _, spec in Balance.S134j.sinkBands do
		Balance.S134J_REPORT[`S134j.sink.income.{c}.{spec.band[1]}-{spec.band[2]}`] =
			"≤ 1 poza zasięgiem (samo +9 zestawu to wielokrotność dochodu pasma, G9)"
	end
end

export type RerollPlan = {
	gold: number,
	materials: { [string]: number },
	goldEq: number,
	essence: number, -- dust equivalents (Balance.dustEq)
	hours: number, -- NaN without classId and level
}

-- Dust equivalents of essences (Data/Recipes: 10 dust -> shard, 8 shards -> crystal).
function Balance.dustEq(materials: { [string]: number }): number
	local shardRecipe = Recipes.get("transmute_shard") :: Recipes.Recipe
	local crystalRecipe = Recipes.get("transmute_crystal") :: Recipes.Recipe
	local dustPerShard = shardRecipe.ingredients[1].n / shardRecipe.result.n
	local shardsPerCrystal = crystalRecipe.ingredients[1].n / crystalRecipe.result.n
	return (materials.essence_dust or 0)
		+ dustPerShard * (materials.essence_shard or 0)
		+ dustPerShard * shardsPerCrystal * (materials.essence_crystal or 0)
end

-- The reroll item of the model: the class weapon of ilvl level - GEAR_GAP at `rarity`.
function Balance.rerollItem(classId: string, level: number, rarity: number): any
	local ilvl = math.max(1, level - Balance.GEAR_GAP)
	return makeItem(tierId(Balance.LOADOUT[classId].weapon, ilvl), ilvl, rarity, 0, {})
end

-- Cost of `attempts` rerolls of `item` starting after `opts.from` (default 0) earlier ones.
function Balance.rerollPlan(
	item: any,
	attempts: number,
	opts: { classId: string?, level: number?, from: number? }?
): RerollPlan
	local o = opts or {}
	local from = o.from or 0
	local gold = 0
	local materials: { [string]: number } = {}
	for n = from, from + attempts - 1 do
		local cost = Reroll.costAt(item, n)
		gold += cost.gold
		for _, m in cost.materials do
			materials[m.id] = (materials[m.id] or 0) + m.n
		end
	end
	local prices = Balance.materialPrices()
	local goldEq = gold
	for _, id in sortedKeys(materials) do
		goldEq += materials[id] * (prices[id] or 0)
	end
	local hours = 0 / 0
	if o.classId and o.level then
		local supply = Balance.materialSupply(o.classId, o.level)
		local need: MaterialNeed = {
			label = "reroll",
			dust = materials.essence_dust or 0,
			shards = materials.essence_shard or 0,
			crystals = materials.essence_crystal or 0,
			cores = 0,
			scrolls = 0,
			scrollShards = 0,
		}
		local income = math.max(1e-9, Balance.economyAt(o.classId, o.level).incomePerHour)
		hours = Balance.materialHours(need, supply.normal, o.level) + gold / income
	end
	return { gold = gold, materials = materials, goldEq = goldEq, essence = Balance.dustEq(materials), hours = hours }
end

-- goldEq of one upgrade attempt to +`to` (gold + essences; Legend Cores outside like upgradePlan).
function Balance.upgradeAttemptEq(item: any, to: number): number
	local cost = Upgrade.cost(item, to)
	local prices = Balance.materialPrices()
	local eq = cost.gold
	for _, m in cost.materials do
		eq += m.n * (prices[m.id] or 0)
	end
	return eq
end

-- Essence (dust equivalents) a class earns grinding a band { lo, hi } (materialSupply.normal of the middle level x the
-- grinding hours of every level of the band, Balance.levelHours) and those hours.
local bandEssenceCache: { [string]: { number } } = {}
function Balance.bandEssence(classId: string, band: { number }): (number, number)
	local key = `{classId}|{band[1]}|{band[2]}`
	local cached = bandEssenceCache[key]
	if cached then
		return cached[1], cached[2]
	end
	local hours = 0
	for L = band[1], band[2] - 1 do
		hours += Balance.levelHours(classId, L)
	end
	local mid = math.floor((band[1] + band[2]) / 2)
	local perHour = Balance.dustEq(Balance.materialSupply(classId, mid).normal)
	bandEssenceCache[key] = { perHour * hours, hours }
	return perHour * hours, hours
end

local SET_SIZE = 2 + #Balance.ARMOR_SLOTS + #Balance.JEWELLERY
Balance.REROLL_SET = SET_SIZE

export type RerollSink = {
	classId: string,
	band: { number },
	rarity: number,
	essence: number, -- dust eq of the band
	hours: number, -- grinding hours of the band
	reroll: number, -- 10 attempts on each of SET_SIZE items (dust eq)
	upgrade: number, -- +9 with protection on each of SET_SIZE items (dust eq; the scrolls apart)
	share: number, -- reroll / essence
	upgradeShare: number, -- upgrade / essence
	income: number, -- gold income of the band (Balance.levelIncome of every level of the band)
	rerollIncome: number, -- goldEq of the set's 10 attempts / income
	upgradeIncome: number, -- goldEq of the set's +9 with protection (G9 goldEq9 per item) / income
}

-- S134j (F2 sink): 10 attempts on every item of a set (one item per slot per band, at the band's rarity) against the
-- essence of the band; the +9 upgrade of the same set beside it (report), both in goldEq against the band's gold income.
function Balance.rerollSink(classId: string, spec: { band: { number }, rarity: number }): RerollSink
	local S = Balance.S134j
	local mid = math.floor((spec.band[1] + spec.band[2]) / 2)
	local item = Balance.rerollItem(classId, mid, spec.rarity)
	local essence, hours = Balance.bandEssence(classId, spec.band)
	local rerollPlan = Balance.rerollPlan(item, S.attempts)
	local upgradePlan = Balance.upgradePlan(item, 9, true)
	local reroll = SET_SIZE * rerollPlan.essence
	local upgrade = SET_SIZE * Balance.dustEq(upgradePlan.materials)
	local income = 0
	for L = spec.band[1], spec.band[2] - 1 do
		income += Balance.levelIncome(classId, L)
	end
	income = math.max(1e-9, income)
	return {
		classId = classId,
		band = spec.band,
		rarity = spec.rarity,
		essence = essence,
		hours = hours,
		reroll = reroll,
		upgrade = upgrade,
		share = reroll / math.max(1e-9, essence),
		upgradeShare = upgrade / math.max(1e-9, essence),
		income = income,
		rerollIncome = SET_SIZE * rerollPlan.goldEq / income,
		upgradeIncome = SET_SIZE * upgradePlan.goldEq / income,
	}
end

-- The first attempt (count n) paying the capped cost: from it every attempt costs growthCap x the first.
function Balance.rerollCapAttempt(): number
	local R = Config.Reroll
	return math.ceil((R.growthCap - 1) / R.growth)
end

-- Essence of one stone attempt (the dearest rarity of the level, at the capped attempt: a stone pays whatever attempt
-- it is used on and stones stack) against the essence of S134j.stoneHours of grinding.
function Balance.rerollStoneShare(classId: string, level: number): number
	local perHour = Balance.dustEq(Balance.materialSupply(classId, level).normal)
	local best = 0
	local from = Balance.rerollCapAttempt()
	for _, rarity in { Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC } do
		best =
			math.max(best, Balance.rerollPlan(Balance.rerollItem(classId, level, rarity), 1, { from = from }).essence)
	end
	return best / math.max(1e-9, perHour * Balance.S134j.stoneHours)
end

-- S134j (F2): the targets in one place (ids "S134j.*"); balance.spec ("Balance: bonus reroll (S134j)") asserts every
-- row without `report`.
function Balance.targetsS134j(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S134j
	local function add(id: string, label: string, value: number, low: number?, high: number?, c: string?, lv: number?)
		target(rows, `S134j.{id}`, "reroll", label, value, low, high, c, lv)
	end
	local rarities = { Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC }
	-- first attempt against a +7 attempt (the gold curve is the same for every class: the Warrior's weapon)
	for _, rarity in rarities do
		local key = Rarities.get(rarity).key
		for _, L in S.levels do
			if (rarity == Rarities.UNIQUE) == (L == 20) then
				local item = Balance.rerollItem("Warrior", L, rarity)
				add(
					`first.vsUpgrade.{key}.L{L}`,
					`{key} L{L}: 1. przemiana / próba +7 (goldEq)`,
					Balance.rerollPlan(item, 1).goldEq / Balance.upgradeAttemptEq(item, 7),
					S.firstVsUpgrade[1],
					S.firstVsUpgrade[2],
					nil,
					L
				)
			end
		end
	end
	-- 10 attempts in hours of the level
	for _, c in Balance.CLASSES do
		local unique =
			Balance.rerollPlan(Balance.rerollItem(c, 20, Rarities.UNIQUE), S.attempts, { classId = c, level = 20 })
		add(
			`ten.hours.{c}.unique.L20`,
			`{c} unique L20: 10 przemian w godzinach poziomu`,
			unique.hours,
			S.tenHoursUnique[1],
			S.tenHoursUnique[2],
			c,
			20
		)
		for _, rarity in { Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC } do
			local key = Rarities.get(rarity).key
			for _, L in { 45, 70, 100 } do
				local plan =
					Balance.rerollPlan(Balance.rerollItem(c, L, rarity), S.attempts, { classId = c, level = L })
				add(
					`ten.hours.{c}.{key}.L{L}`,
					`{c} {key} L{L}: 10 przemian w godzinach poziomu`,
					plan.hours,
					S.tenHours[1],
					S.tenHours[2],
					c,
					L
				)
			end
		end
	end
	-- growth: monotonic, at most growthCap x the first
	for _, rarity in rarities do
		local item = Balance.rerollItem("Warrior", 70, rarity)
		local first = Balance.rerollPlan(item, 1).goldEq
		local worst, monotonic, previous = 0, 1, 0
		for n = 0, 20 do
			local eq = Balance.rerollPlan(item, 1, { from = n }).goldEq
			if eq < previous then
				monotonic = 0
			end
			previous = eq
			worst = math.max(worst, eq / first)
		end
		local key = Rarities.get(rarity).key
		add(`growth.cap.{key}`, `{key}: najdroższa próba / pierwsza`, worst, 1, Config.Reroll.growthCap + 1e-9)
		add(`growth.monotonic.{key}`, `{key}: koszt próby nie maleje (1 = tak)`, monotonic, 1, 1)
	end
	-- sink: 10 attempts on every item of the band against its essence
	for _, c in Balance.CLASSES do
		for _, spec in S.sinkBands do
			local sink = Balance.rerollSink(c, spec)
			local name = `{spec.band[1]}-{spec.band[2]}`
			add(
				`sink.{c}.{name}`,
				`{c} {name}: esencja 10 przemian × {SET_SIZE} przedmiotów ({Rarities.get(spec.rarity).key}) / esencja pasma`,
				sink.share,
				S.sink[1],
				S.sink[2],
				c,
				spec.band[2]
			)
			add(
				`sink.income.{c}.{name}`,
				`{c} {name}: (+9 zestawu z ochroną + 10 przemian × zestaw) w goldEq / dochód złota pasma`,
				sink.upgradeIncome + sink.rerollIncome,
				nil,
				1,
				c,
				spec.band[2]
			)
		end
	end
	-- the stone: one a day against the essence of 2 h of play (the dearest rarity of the level)
	for _, c in Balance.CLASSES do
		for _, L in { 45, 70, 100 } do
			add(
				`stone.{c}.L{L}`,
				`{c} L{L}: esencja jednej próby (Kamień) / esencja {S.stoneHours} h gry`,
				Balance.rerollStoneShare(c, L),
				nil,
				S.stone,
				c,
				L
			)
		end
	end
	for _, row in rows do
		local why = Balance.S134J_REPORT[row.id]
		if why then
			row.report = `S134j: {why}`
		end
	end
	return rows
end

-- Hunting contracts on a monster kind and Hunter's Marks (S134k, docs/sessions/S134k.md F) ------------------------------
-- The contract time: the kills of the hunting ground it takes to kill n of the kind (n / its share of the area's normal
-- monsters, Logic/ContractGen) at the Warrior's grinding pace of the level (paceAt.secondsPerKill), against S99 (any
-- monster of the area: killsAt(L)). Marks per hour of contracts of the own level = marksFor(L) / that time. The shop's
-- value: the marks of one hour spent on the potions, stones, blessings and essence the level may buy, best gold per
-- mark first (Balance.materialPrices for essence, the merchant price for the rest), a weekly limit giving 1 / 14 of
-- itself per hour (14 h of play a week). The EXP and gold of the contracts did not change (the S109 budget stays).

local ContractGen = require("../src/shared/Logic/ContractGen")
local ContractRules = require("../src/shared/Logic/Contracts")
local HuntShop = require("../src/shared/Logic/HuntShop")
local HuntShopData = require("../src/shared/Data/HuntShop")

Balance.S134k = {
	time = 1.2, -- contract time on a kind / S99 contract time, every level 4-99
	value = { 0.05, 0.15 }, -- shop value of one hour of contracts / the gold income of that hour
	essence = 0.10, -- essence of the weekly limits / the essence of 14 h of grinding of the band
	chestHours = 2, -- the Hunter's Chest in hours of contracts of its band (at least)
	heroicWeekly = 1, -- the Heroic chest per week
	lootHeroics = 1, -- Heroics of the loot per week at 14 h (at least)
	weekHours = 14,
	levels = { 10, 20, 45, 70, 99 },
	bands = { { 20, 44 }, { 45, 69 }, { 70, 99 } },
}
Balance.S134K_REPORT = {} :: { [string]: string }

local contractPicks: { ContractGen.Pick }? = nil
local function picks(): { ContractGen.Pick }
	if not contractPicks then
		contractPicks = ContractGen.picks(Quests.Contracts.RULES)
	end
	return contractPicks :: { ContractGen.Pick }
end

-- Seconds of the contract of `level` (S99 with `legacy`: any monster of the area counts).
function Balance.contractTime(level: number, legacy: boolean?): number
	local rules = Quests.Contracts.RULES
	local kills = ContractGen.killsAt(rules, level)
	if not legacy then
		local contract = Quests.Contracts.forLevel(level) :: Quests.ContractQuest
		local share = picks()[level].share or 1
		kills = contract.objectives[1].n / share
	end
	return kills * Balance.paceAt("Warrior", level).secondsPerKill
end

-- Hunter's Marks per hour of contracts of the own level.
function Balance.huntMarks(level: number): number
	return ContractRules.marksFor(level) * 3600 / math.max(1e-9, Balance.contractTime(level))
end

-- Marks per hour of contracts over the decade of `level` (1-10, 11-20, ...): the milestone contract spread over its
-- ten levels (the value row; one level's marks jump x2-4 on every 10th).
function Balance.huntMarksDecade(level: number): number
	local first = math.floor((level - 1) / 10) * 10 + 1
	local last = math.min(Quests.Contracts.MAX_LEVEL, first + 9)
	local sum = 0
	for L = first, last do
		sum += Balance.huntMarks(L)
	end
	return sum / (last - first + 1)
end

-- Gold of what one purchase of `entry` gives at `level` (nil for chests and cosmetics).
local function entryGold(entry: HuntShopData.Entry, level: number, classId: string): number?
	local grant = HuntShop.grant(entry, level, classId)
	if not grant then
		return nil
	end
	local prices = Balance.materialPrices()
	local def = Items.get(grant.id) :: any
	local unit = prices[grant.id] or (if def then def.buyPrice or def.price or 0 else 0)
	return unit * grant.n
end

-- Gold of the marks of one hour of contracts at `level` (Balance.huntMarksDecade) spent best gold per mark first
-- (weekly limits pro rata).
function Balance.huntMarksValue(classId: string, level: number): number
	local marks = Balance.huntMarksDecade(level)
	local offers: { { perMark: number, price: number, cap: number, gold: number } } = {}
	for _, entry in HuntShopData.ENTRIES do
		local gold = entryGold(entry, level, classId)
		if gold and level >= (entry.minLevel or 1) and HuntShop.offered(entry, level) then
			local cap = if entry.weeklyLimit then entry.weeklyLimit / Balance.S134k.weekHours else math.huge
			local price = HuntShop.priceAt(entry, level)
			table.insert(offers, { perMark = gold / price, price = price, cap = cap, gold = gold })
		end
	end
	table.sort(offers, function(a, b)
		return a.perMark > b.perMark
	end)
	local value = 0
	for _, offer in offers do
		if marks <= 0 then
			break
		end
		local n = math.min(marks / offer.price, offer.cap)
		value += n * offer.gold
		marks -= n * offer.price
	end
	return value
end

-- Essence (dust equivalents) of every weekly limit a character of `level` may buy.
function Balance.huntShopEssence(level: number): number
	local materials: { [string]: number } = {}
	for _, entry in HuntShopData.ENTRIES do
		if entry.group == "essence" and level >= (entry.minLevel or 1) and HuntShop.offered(entry, level) then
			local grant = HuntShop.grant(entry, level, "Warrior") :: HuntShop.Grant
			materials[grant.id] = (materials[grant.id] or 0) + grant.n * (entry.weeklyLimit or 0)
		end
	end
	return Balance.dustEq(materials)
end

-- S134k (F2): the targets in one place (ids "S134k.*"); balance.spec ("Balance: hunting contracts and marks (S134k)")
-- asserts every row without `report`.
function Balance.targetsS134k(): { TargetRow }
	local rows: { TargetRow } = {}
	local S = Balance.S134k
	local function add(id: string, label: string, value: number, low: number?, high: number?, c: string?, lv: number?)
		target(rows, `S134k.{id}`, "huntmarks", label, value, low, high, c, lv)
	end
	for L = 4, Quests.Contracts.MAX_LEVEL do
		add(
			`time.L{L}`,
			`L{L}: czas zlecenia na rodzaj / czas zlecenia S99`,
			Balance.contractTime(L) / Balance.contractTime(L, true),
			nil,
			S.time,
			nil,
			L
		)
	end
	for _, c in Balance.CLASSES do
		for _, L in S.levels do
			local income = math.max(1e-9, Balance.economyAt(c, L).incomePerHour)
			add(
				`value.{c}.L{L}`,
				`{c} L{L}: wartość zakupów za Znaki z 1 h zleceń / dochód złota tej godziny`,
				Balance.huntMarksValue(c, L) / income,
				S.value[1],
				S.value[2],
				c,
				L
			)
		end
	end
	for _, c in Balance.CLASSES do
		for _, band in S.bands do
			local mid = math.floor((band[1] + band[2]) / 2)
			local supply = Balance.dustEq(Balance.materialSupply(c, mid).normal) * S.weekHours
			add(
				`essence.{c}.{band[1]}-{band[2]}`,
				`{c} {band[1]}–{band[2]}: esencja z limitów tygodnia / esencja {S.weekHours} h bicia`,
				Balance.huntShopEssence(mid) / math.max(1e-9, supply),
				nil,
				S.essence,
				c,
				mid
			)
		end
	end
	local chest = HuntShopData.byKey.hunt_chest
	for _, band in S.bands do
		local sum, n = 0, 0
		for L = band[1], band[2] do
			sum += Balance.huntMarks(L)
			n += 1
		end
		add(
			`chest.hours.{band[1]}-{band[2]}`,
			`{band[1]}–{band[2]}: Skrzynia Łowcy w godzinach zleceń pasma`,
			chest.price / (sum / n),
			S.chestHours,
			nil,
			nil,
			band[2]
		)
	end
	local heroic = HuntShopData.byKey.hunt_chest_heroic
	add(
		"chest.heroicWeekly",
		"Heroiczna Skrzynia Łowcy: limit tygodnia",
		heroic.weeklyLimit or math.huge,
		1,
		S.heroicWeekly
	)
	for _, c in Balance.CLASSES do
		for _, L in { 45, 70, 99 } do
			add(
				`chest.loot.{c}.L{L}`,
				`{c} L{L}: Heroiki z łupu na tydzień ({S.weekHours} h jaskiniowych Elit)`,
				Balance.dropsPerHour(c, L, "K0", false).heroic * S.weekHours,
				S.lootHeroics,
				nil,
				c,
				L
			)
		end
	end
	local sum = 0
	for L = 1, Quests.Contracts.MAX_LEVEL do
		sum += ContractRules.marksFor(L)
	end
	add("retro.L99", "retro Znaki postaci 99 / suma marksFor(1..99)", ContractRules.retroMarks(99) / sum, 1, 1)
	for _, row in rows do
		local why = Balance.S134K_REPORT[row.id]
		if why then
			row.report = `S134k: {why}`
		end
	end
	return rows
end

return Balance
