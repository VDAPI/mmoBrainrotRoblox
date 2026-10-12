--!strict
-- Warrior paths (docs/ROZWOJ.md 10.1, 10.3-10.5; S75): Guardian, Berserker, Standard-Bearer. Numbers are the ROZWOJ 10
-- starting values ({ rank 1, rank max }, linear); the balance sessions tune them. Shape: tests/fixtures/paths.luau and
-- Data/Paths/Cleric (S71). Rank-dependent numbers sit in `values`, passive names the field, in modify.bp a number is
-- { ref = "<field>" }; numbers of effects and behaviours go through new fields of the skill's values (read by name).
-- Hooks are the S64 / S72 names (Logic/Fury, CombatService). `reference` and `itemWeights` never reach the wiki;
-- every path is unpublished there (wiki = false, ROZWOJ 3.5).

local SkillData = require("../Skills")
local Types = require("./Types")

type PathNode = Types.PathNode
type PathRow = Types.PathRow

local function node(pathId: string, name: string, kind: string, maxRank: number, glyph: string, fields: any): PathNode
	local out: any = {
		id = `{pathId}_{name}`,
		kind = kind,
		maxRank = maxRank,
		glyph = glyph,
		nameKey = `path.{pathId}.{name}.name`,
		descKey = `path.{pathId}.{name}.desc`,
	}
	for key, value in fields do
		out[key] = value
	end
	return out :: PathNode
end

-- A skill node: the skill's own glyph and texts.
local function skill(pathId: string, skillId: string): PathNode
	local def = SkillData.get(skillId)
	assert(def, `Paths/Warrior: unknown skill {skillId}`)
	local out: any = {
		id = `{pathId}_{skillId}`,
		kind = "skill",
		maxRank = 1,
		skill = skillId,
		glyph = def.glyph,
		nameKey = def.nameKey,
		descKey = def.descKey,
	}
	return out :: PathNode
end

local function row(choice: boolean, nodes: { PathNode }): PathRow
	return { choice = choice, nodes = nodes }
end

local function ref(field: string): any
	return { ref = field }
end

local G, B, S = "guardian", "berserker", "standard"

local guardian: Types.PathDef = {
	id = G,
	class = "Warrior",
	order = 1,
	role = "tank",
	nameKey = "path.guardian.name",
	descKey = "path.guardian.desc",
	titleId = "path_guardian",
	weapon = { main = { "sword1h", "axe1h", "mace1h", "saber1h" }, offhand = { "shield" } },
	statPlan = { str = 2, vit = 3 },
	itemWeights = {
		axes = { surv = 1.5, dmg = 0.7 },
		stats = { blockChance = 1.3, energyRegen = 1.7 },
		traits = { swordplay = 1.9, bonebreaker = 0.9, reaping = 0.7, twinCut = 1.4 },
	},
	rows = {
		row(false, {
			skill(G, "fortitude"),
			node(G, "frontline", "passive", 3, "⚑", {
				values = { frontline = { 1.5, 3.5 } },
				passive = { hooks = { guardPerEnemy = "frontline" } },
			}),
		}),
		row(false, {
			node(G, "block", "passive", 3, "◈", {
				values = { block = { 4, 10 } },
				passive = { hooks = { block = "block" } },
				weapon = { offhand = { "shield" } },
			}),
			node(G, "cover", "aura", 3, "⛉", {
				values = { cover = { 4, 10 } },
				aura = { category = "allyGuard", stats = { value = "cover" }, radius = 15, shape = "behind" },
			}),
		}),
		row(true, {
			node(G, "vow", "modify", 3, "✋", {
				values = { vow = { 4, 8 } },
				modify = {
					skill = "taunt",
					bp = {
						shieldPerHit = { hpPct = "vowShield", max = 5, duration = 6 },
						values = { vowShield = ref("vow") },
					},
				},
			}),
			node(G, "retaliation", "passive", 3, "⤺", {
				values = { retaliation = { 4, 12 } },
				passive = { hooks = { riposte = "retaliation" } },
			}),
		}),
		row(false, {
			skill(G, "intercept"),
			node(G, "sacrifice", "modify", 3, "✠", {
				values = { sacrificeTime = { 0.5, 1.5 }, sacrifice = { 5, 15 } },
				modify = {
					skill = "intercept",
					bp = {
						add = { effectDuration = ref("sacrificeTime") },
						values = { sacrificeGuard = ref("sacrifice") },
						-- only while intercepting: the self variant skips selfEffects (Movement.guard, S75)
						selfEffect = {
							kind = "damageReduction",
							duration = 4,
							value = "sacrificeGuard",
							target = "self",
							category = "own",
						},
					},
				},
			}),
		}),
		row(false, {
			node(G, "menace", "passive", 3, "☠", {
				values = { menaceThreat = { 30, 90 }, menaceDamage = { 1, 3 } },
				passive = { hooks = { threat = "menaceThreat", damagePerEnemy = "menaceDamage" } },
			}),
			node(G, "shieldMastery", "passive", 3, "⬢", {
				values = { shieldMastery = { 3, 9 } },
				passive = { hooks = { block = "shieldMastery" } },
			}),
		}),
		row(true, {
			node(G, "grit", "passive", 3, "✊", {
				values = { grit = { 10, 30 } },
				passive = { hooks = { lastStand = "grit" } },
			}),
			node(G, "aegis", "modify", 3, "◎", {
				values = { aegis = { 5, 15 } },
				modify = {
					skill = "intercept",
					bp = {
						allyShield = { hpPct = "aegisShield", duration = 4 },
						values = { aegisShield = ref("aegis") },
					},
				},
			}),
		}),
		row(false, {
			skill(G, "lastBastion"),
			node(G, "bastionCover", "modify", 3, "⛫", {
				values = { bastionCover = { 10, 30 } },
				modify = {
					skill = "lastBastion",
					bp = {
						behindEffect = {
							kind = "damageReduction",
							duration = 10,
							value = "bastionGuard",
							target = "allies",
							category = "allyGuard",
						},
						values = { bastionGuard = ref("bastionCover") },
					},
				},
			}),
		}),
		row(false, { skill(G, "shieldWall") }),
		row(true, {
			node(G, "martyr", "passive", 3, "✝", {
				values = { martyr = { 10, 30 } },
				passive = { hooks = { interceptMitigation = "martyr" } },
			}),
			node(G, "retribution", "passive", 3, "✴", {
				values = { retribution = { 10, 30 } },
				passive = { hooks = { interceptThorns = "retribution" } },
			}),
		}),
		row(false, {
			node(G, "fortress", "modify", 3, "♜", {
				values = { fortress = { 0.92, 0.75 } },
				modify = { skill = "shieldWall", bp = { mul = { cooldown = ref("fortress") } } },
			}),
			node(G, "veteran", "passive", 3, "✪", {
				values = { veteran = { 4, 12 } },
				passive = { pct = { armor = "veteran", maxHp = "veteran" } },
			}),
		}),
		row(false, {
			node(G, "shieldWall2", "modify", 2, "▦", {
				values = { wallTime = { 1, 2 }, wallShare = { 2.5, 5 } },
				modify = {
					skill = "shieldWall",
					bp = { add = { effectDuration = ref("wallTime") }, values = { share = ref("wallShare") } },
				},
			}),
		}),
	},
	reference = {},
	wiki = false,
}

local berserker: Types.PathDef = {
	id = B,
	class = "Warrior",
	order = 2,
	role = "damage",
	nameKey = "path.berserker.name",
	descKey = "path.berserker.desc",
	titleId = "path_berserker",
	weapon = { main = { "sword2h", "axe2h", "hammer2h", "spear2h" } },
	statPlan = { str = 4, vit = 1 },
	itemWeights = {
		axes = { dmg = 1.2, surv = 0.8 },
		stats = {
			woundChance = 1.25,
			dotPower = 1.25,
			lifesteal = 1.6,
			vit = 1.25,
			maxHp = 1.25,
			blockChance = 0,
		},
		traits = { rendingGash = 1.1, sundering = 0.85, runThrough = 0.85 },
	},
	rows = {
		row(false, {
			skill(B, "cleave"),
			node(B, "wounds", "passive", 3, "♦", {
				values = { wounds = { 10, 30 } },
				passive = { hooks = { bleedDamage = "wounds" } },
			}),
		}),
		row(false, {
			node(B, "rhythm", "passive", 3, "♫", {
				values = { rhythmMax = { 4, 10 }, rhythmSpeed = 1 },
				passive = { hooks = { furyMax = "rhythmMax", furySpeed = "rhythmSpeed" } },
			}),
			node(B, "bloodthirst", "modify", 3, "⚱", {
				values = { bloodthirst = { 2, 6 } },
				modify = {
					skill = "bloodlust",
					bp = {
						extendOnKill = { seconds = 1, max = "bloodthirstMax" },
						values = { bloodthirstMax = ref("bloodthirst") },
					},
				},
			}),
		}),
		row(true, {
			node(B, "amok", "passive", 3, "»", {
				values = { amok = { 1, 2 } },
				passive = { hooks = { furySpeed = "amok" } },
			}),
			node(B, "ferocity", "passive", 3, "✷", {
				values = { ferocity = { 0.4, 1.2 } },
				passive = { hooks = { furyDamage = "ferocity" } },
			}),
		}),
		row(false, {
			skill(B, "rend"),
			node(B, "executioner", "passive", 3, "⚰", {
				values = { executioner = { 5, 15 } },
				passive = { hooks = { executioner = "executioner" } },
			}),
		}),
		row(false, {
			node(B, "rendingCuts", "modify", 3, "≋", {
				values = { rendingCuts = { 1, 3 } },
				modify = { skill = "cleave", bp = { add = { effectDuration = ref("rendingCuts") } } },
			}),
			node(B, "might", "passive", 3, "⚒", {
				values = { might = { 3, 9 } },
				passive = { pct = { physAtk = "might" } },
			}),
		}),
		row(true, {
			node(B, "bloodfury", "passive", 3, "♥", {
				values = { bloodfury = { 0.2, 0.5 } },
				passive = { hooks = { furyLifesteal = "bloodfury" } },
			}),
			node(B, "relentless", "passive", 3, "⛊", {
				values = { relentless = { 5, 15 } },
				passive = { hooks = { furyGuard = "relentless" } },
			}),
		}),
		row(false, {
			skill(B, "titansWrath"),
			node(B, "thunder", "modify", 3, "☇", {
				values = { thunder = { 0.93, 0.8 } },
				modify = { skill = "titansWrath", bp = { mul = { cooldown = ref("thunder") } } },
			}),
		}),
		row(false, { skill(B, "carnage") }),
		row(true, {
			node(B, "drinker", "passive", 3, "⚗", {
				values = { drinker = { 2, 6 } },
				passive = { hooks = { killHeal = "drinker" } },
			}),
			node(B, "giantSlayer", "passive", 3, "♛", {
				values = { giantSlayer = { 4, 12 } },
				passive = { hooks = { bossDamage = "giantSlayer", eliteDamage = "giantSlayer" } },
			}),
		}),
		row(false, {
			node(B, "openWounds", "passive", 3, "✂", {
				values = { openWounds = { 10, 30 } },
				passive = { hooks = { bleedDamage = "openWounds" } },
			}),
			node(B, "hardened", "passive", 3, "⛰", {
				values = { hardened = { 4, 12 } },
				passive = { pct = { maxHp = "hardened" } },
			}),
		}),
		row(false, {
			node(B, "carnage2", "modify", 2, "☄", {
				values = { carnageTime = { 1, 2 }, carnageFury = { 5, 10 } },
				modify = {
					skill = "carnage",
					bp = {
						add = { effectDuration = ref("carnageTime") },
						values = { furyRestore = ref("carnageFury") },
					},
				},
			}),
		}),
	},
	reference = {},
	wiki = false,
}

local standard: Types.PathDef = {
	id = S,
	class = "Warrior",
	order = 3,
	role = "support",
	nameKey = "path.standard.name",
	descKey = "path.standard.desc",
	titleId = "path_standard",
	weapon = { main = { "saber1h", "sword1h" } },
	statPlan = { str = 3, vit = 2 },
	itemWeights = {
		stats = {
			energyRegen = 1.5,
			maxEnergy = 1.5,
			costReduce = 1.5,
			cooldownReduction = 1.5,
			atkSpeed = 1.1,
			critChance = 1.1,
		},
		traits = { twinCut = 1.2 },
	},
	rows = {
		row(false, {
			skill(S, "battleCry"),
			node(S, "breath", "modify", 3, "☁", {
				values = { breath = { 0.8, 0.4 } },
				modify = { skill = "battleCry", bp = { mul = { cost = ref("breath") } } },
			}),
		}),
		row(false, {
			node(S, "command", "modify", 3, "🗣", {
				values = { command = { 1, 3 } },
				modify = {
					skill = "battleCry",
					bp = {
						values = { cmdAtk = ref("command") },
						allyEffect = {
							kind = "statBuff",
							duration = 20,
							stats = { physAtk = "cmdAtk", magAtk = "cmdAtk" },
							pct = true,
							target = "allies",
							category = "allyAttack",
						},
					},
				},
			}),
			node(S, "march", "passive", 3, "⇶", {
				values = { march = { 3, 9 } },
				passive = { flat = { moveSpeed = "march" } },
			}),
		}),
		row(true, {
			node(S, "fervor", "modify", 3, "✹", {
				values = { fervor = { 4, 12 } },
				modify = { skill = "battleCry", bp = { values = { atk = ref("fervor") } } },
			}),
			node(S, "formation", "modify", 3, "▤", {
				values = { formation = { 3, 9 } },
				modify = {
					skill = "battleCry",
					bp = {
						values = { cmdVigor = ref("formation") },
						allyEffect = {
							kind = "statBuff",
							duration = 20,
							stats = { armor = "cmdVigor", mres = "cmdVigor" },
							pct = true,
							target = "allies",
							category = "allyVigor",
						},
					},
				},
			}),
		}),
		row(false, {
			skill(S, "warBanner"),
			node(S, "colours", "modify", 3, "⚐", {
				values = { colours = { 1, 3 } },
				modify = { skill = "warBanner", bp = { add = { duration = ref("colours") } } },
			}),
		}),
		row(false, {
			node(S, "grit", "passive", 3, "❣", {
				values = { bearerGrit = { 4, 12 } },
				passive = { pct = { maxHp = "bearerGrit" } },
			}),
			node(S, "wide", "modify", 3, "◯", {
				values = { wide = { 2, 6 } },
				modify = { skill = "warBanner", bp = { add = { radius = ref("wide") } } },
			}),
		}),
		row(true, {
			node(S, "inspire", "modify", 3, "✦", {
				values = { inspire = { 1, 3 } },
				modify = {
					skill = "warBanner",
					bp = {
						values = { inspireCrit = ref("inspire") },
						-- a circle pulse like the banner's own effects (1.5 s nominal, S74)
						allyEffect = {
							kind = "statBuff",
							duration = 1.5,
							stats = { critChance = "inspireCrit" },
							target = "allies",
							category = "allyCrit",
						},
					},
				},
			}),
			node(S, "rally", "modify", 3, "✚", {
				values = { rally = { 3, 9 } },
				modify = {
					skill = "battleCry",
					bp = { allyHeal = { hpPct = "rallyHeal" }, values = { rallyHeal = ref("rally") } },
				},
			}),
		}),
		row(false, {
			skill(S, "crushingBlow"),
			node(S, "sunder", "modify", 3, "⛏", {
				values = { sunder = { 2, 6 } },
				modify = { skill = "crushingBlow", bp = { add = { armorBreakDuration = ref("sunder") } } },
			}),
		}),
		row(false, { skill(S, "advanceOrder") }),
		row(true, {
			node(S, "oath", "modify", 3, "⚜", {
				values = { oath = { 4, 10 } },
				modify = {
					skill = "warBanner",
					bp = {
						values = { oathGuard = ref("oath") },
						allyEffect = {
							kind = "damageReduction",
							duration = 1.5,
							value = "oathGuard",
							target = "allies",
							category = "allyGuard",
						},
					},
				},
			}),
			node(S, "glory", "modify", 3, "☼", {
				values = { glory = { 1, 3 } },
				modify = { skill = "advanceOrder", bp = { add = { effectDuration = ref("glory") } } },
			}),
		}),
		row(false, {
			node(S, "stamina", "passive", 3, "∞", {
				values = { stamina = { 0.5, 1.5 } },
				passive = { flat = { energyRegen = "stamina" } },
			}),
			node(S, "veteran", "passive", 3, "✯", {
				values = { campaign = { 4, 12 } },
				passive = { pct = { armor = "campaign" } },
			}),
		}),
		row(false, {
			node(S, "advanceOrder2", "modify", 2, "♚", {
				values = { orderTime = { 1, 2 }, orderRadius = { 5, 10 } },
				modify = {
					skill = "advanceOrder",
					bp = { add = { effectDuration = ref("orderTime"), radius = ref("orderRadius") } },
				},
			}),
		}),
	},
	reference = {},
	wiki = false,
}

-- Model builds (ROZWOJ 7.5, 10.3-10.5; shape in Data/Paths/Types): each spends exactly pointsAt(100) = 50 points.
local function build(
	id: string,
	main: string,
	offhand: string?,
	stats: { [string]: number },
	nodes: { { any } },
	bp: { [string]: "a" | "b" },
	rotation: { { [string]: any } },
	damageReference: boolean?
): Types.ReferenceBuild
	return {
		id = id,
		damageReference = damageReference,
		weapon = { main = main, offhand = offhand },
		nodes = nodes,
		bp = bp,
		stats = stats,
		rotation = rotation,
	}
end

-- Guardian ------------------------------------------------------------------------------------------------------
-- "Loner": ROZWOJ gives no breakpoints, it takes the Defender's (S75).
local GUARDIAN_BP: { [string]: "a" | "b" } = {
	["intercept:5"] = "a",
	["intercept:10"] = "b",
	["shieldWall:5"] = "b",
	["shieldWall:10"] = "a",
	["lastBastion:5"] = "b",
	["lastBastion:10"] = "b",
	["taunt:5"] = "b",
	["taunt:10"] = "b",
}
local function guardianRotation(intercept: { [string]: any }): { { [string]: any } }
	return {
		intercept,
		{ skill = "taunt" },
		{ skill = "shieldWall" },
		{ skill = "battleCry" },
		{ skill = "mightyStrike" },
		{ skill = "bladeWhirl" },
		{ skill = "cleave" },
		{ skill = "earthquake" },
	}
end

guardian.reference = {
	build("defender", "sword1h", "shield", guardian.statPlan :: any, {
		{ "guardian_fortitude", 1 },
		{ "guardian_frontline", 3 },
		{ "berserker_cleave", 1 },
		{ "berserker_wounds", 1 },
		{ "standard_battleCry", 1 },
		{ "standard_breath", 3 },
		{ "guardian_block", 3 },
		{ "guardian_cover", 3 },
		{ "berserker_rhythm", 2 },
		{ "guardian_vow", 3 },
		{ "guardian_intercept", 1 },
		{ "guardian_sacrifice", 3 },
		{ "guardian_menace", 3 },
		{ "guardian_shieldMastery", 3 },
		{ "guardian_aegis", 3 },
		{ "guardian_lastBastion", 1 },
		{ "guardian_bastionCover", 3 },
		{ "guardian_shieldWall", 1 },
		{ "guardian_martyr", 3 },
		{ "guardian_fortress", 3 },
		{ "guardian_veteran", 3 },
		{ "guardian_shieldWall2", 2 },
	}, GUARDIAN_BP, guardianRotation({ skill = "intercept", target = "allyInZone" })),
	build("loner", "sword1h", "shield", guardian.statPlan :: any, {
		{ "guardian_fortitude", 1 },
		{ "guardian_frontline", 3 },
		{ "berserker_cleave", 1 },
		{ "berserker_wounds", 3 },
		{ "standard_battleCry", 1 },
		{ "standard_breath", 3 },
		{ "guardian_block", 3 },
		{ "berserker_rhythm", 3 },
		{ "berserker_bloodthirst", 3 },
		{ "guardian_retaliation", 3 },
		{ "guardian_intercept", 1 },
		{ "guardian_sacrifice", 3 },
		{ "guardian_menace", 3 },
		{ "guardian_shieldMastery", 3 },
		{ "guardian_grit", 3 },
		{ "guardian_lastBastion", 1 },
		{ "guardian_shieldWall", 1 },
		{ "guardian_retribution", 3 },
		{ "guardian_fortress", 3 },
		{ "guardian_veteran", 3 },
		{ "guardian_shieldWall2", 2 },
	}, GUARDIAN_BP, guardianRotation({ skill = "intercept", target = "self" })),
}

-- Berserker -----------------------------------------------------------------------------------------------------
local BERSERKER_BP: { [string]: "a" | "b" } = {
	["mightyStrike:5"] = "b",
	["mightyStrike:10"] = "b",
	["bladeWhirl:5"] = "b",
	["bladeWhirl:10"] = "a",
	["cleave:5"] = "a",
	["cleave:10"] = "a",
	["rend:5"] = "a",
	["rend:10"] = "a",
	["titansWrath:5"] = "b",
	["titansWrath:10"] = "b",
	["carnage:5"] = "a",
	["carnage:10"] = "a",
	["bloodlust:5"] = "b",
	["bloodlust:10"] = "b",
}
local BERSERKER_ROTATION: { { [string]: any } } = {
	{ skill = "carnage", minFury = 10 },
	{ skill = "battleCry" },
	{ skill = "bloodlust" },
	{ skill = "rend", minFury = 8 },
	{ skill = "titansWrath", minEnemies = 3 },
	{ skill = "mightyStrike" },
	{ skill = "cleave" },
	{ skill = "bladeWhirl" },
	{ skill = "earthquake" },
	{ skill = "charge" },
}
local function berserkerNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "berserker_cleave", 1 },
		{ "berserker_wounds", 3 },
		{ "guardian_fortitude", 1 },
		{ "guardian_frontline", 3 },
		{ "standard_battleCry", 1 },
		{ "standard_breath", 3 },
		{ "berserker_rhythm", 3 },
		{ "berserker_bloodthirst", 3 },
		{ row3, 3 },
		{ "berserker_rend", 1 },
		{ "berserker_executioner", 3 },
		{ "berserker_rendingCuts", 3 },
		{ "berserker_might", 3 },
		{ row6, 3 },
		{ "berserker_titansWrath", 1 },
		{ "berserker_thunder", 3 },
		{ "berserker_carnage", 1 },
		{ row9, 3 },
		{ "berserker_openWounds", 3 },
		{ "berserker_hardened", 3 },
		{ "berserker_carnage2", 2 },
	}
end

berserker.reference = {
	-- the only damage reference in the game: the damage target of every class (ROZWOJ 7.5)
	build(
		"fury",
		"axe2h",
		nil,
		berserker.statPlan :: any,
		berserkerNodes("berserker_amok", "berserker_bloodfury", "berserker_giantSlayer"),
		BERSERKER_BP,
		BERSERKER_ROTATION,
		true
	),
	build(
		"butcher",
		"axe2h",
		nil,
		berserker.statPlan :: any,
		berserkerNodes("berserker_ferocity", "berserker_relentless", "berserker_drinker"),
		BERSERKER_BP,
		BERSERKER_ROTATION
	),
}

-- Standard-Bearer -----------------------------------------------------------------------------------------------
local STANDARD_BP: { [string]: "a" | "b" } = {
	["battleCry:5"] = "b",
	["battleCry:10"] = "a",
	["warBanner:5"] = "a",
	["warBanner:10"] = "a",
	["crushingBlow:5"] = "b",
	["crushingBlow:10"] = "b",
	["advanceOrder:5"] = "a",
	["advanceOrder:10"] = "a",
}
local STANDARD_ROTATION: { { [string]: any } } = {
	{ skill = "warBanner", opener = true },
	{ skill = "battleCry" },
	{ skill = "advanceOrder" },
	{ skill = "crushingBlow" },
	{ skill = "mightyStrike" },
	{ skill = "cleave" },
	{ skill = "bladeWhirl" },
}
local function standardNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "standard_battleCry", 1 },
		{ "standard_breath", 3 },
		{ "guardian_fortitude", 1 },
		{ "guardian_frontline", 3 },
		{ "berserker_cleave", 1 },
		{ "berserker_wounds", 1 },
		{ "standard_command", 3 },
		{ "standard_march", 3 },
		{ "berserker_rhythm", 2 },
		{ row3, 3 },
		{ "standard_warBanner", 1 },
		{ "standard_colours", 3 },
		{ "standard_grit", 3 },
		{ "standard_wide", 3 },
		{ row6, 3 },
		{ "standard_crushingBlow", 1 },
		{ "standard_sunder", 3 },
		{ "standard_advanceOrder", 1 },
		{ row9, 3 },
		{ "standard_stamina", 3 },
		{ "standard_veteran", 3 },
		{ "standard_advanceOrder2", 2 },
	}
end

standard.reference = {
	build(
		"commander",
		"sword1h",
		"shield",
		standard.statPlan :: any,
		standardNodes("standard_fervor", "standard_inspire", "standard_glory"),
		STANDARD_BP,
		STANDARD_ROTATION
	),
	build(
		"warden",
		"saber1h",
		"shield",
		standard.statPlan :: any,
		standardNodes("standard_formation", "standard_rally", "standard_oath"),
		STANDARD_BP,
		STANDARD_ROTATION
	),
}

return { guardian, berserker, standard } :: { Types.PathDef }
