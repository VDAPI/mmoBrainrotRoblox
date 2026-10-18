--!strict
-- Warrior paths (docs/ROZWOJ.md 10.1, 10.3-10.5; S75): Guardian, Berserker, Standard-Bearer. Numbers are the ROZWOJ 10
-- starting values ({ rank 1, rank max }, linear); the balance sessions tune them. S143 (DESIGN-18 §6.2, §7): skill nodes
-- only in rows 4 and 8 (Last Bastion, Carnage and Order to Advance: the capstones of row 8); the skills that went
-- to the weapon pools left nodes of the same ranks (Stalwart, Shield Bash Mastery, Twin Guard, Scars, Frenzy, Reaper,
-- Pennant, Herald, Drill). The Berserker's Fury nodes raise Rage's Fury (the two-handed P1): without Rage no Fury. Shape: tests/fixtures/paths.luau and
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

-- S138 (DESIGN-18 §7): a node with its own weapon requirement (directions have none).
local function needs(n: PathNode, weapon: Types.WeaponReq): PathNode
	local out: any = n
	out.weapon = weapon
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
	statPlan = { str = 7, vit = 5 },
	itemWeights = {
		axes = { surv = 1.5, dmg = 0.7 },
		stats = { blockChance = 1.3, energyRegen = 1.7 },
		traits = { swordplay = 1.9, bonebreaker = 0.9, reaping = 0.7, twinCut = 1.4 },
	},
	rows = {
		row(false, {
			-- S143: Fortitude is the one-handed P1; Stalwart takes its one rank
			node(G, "stalwart", "passive", 1, "✚", {
				values = { stalwart = 1 },
				passive = { pct = { maxHp = "stalwart" } },
			}),
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
			-- S143: Intercept is the one-handed O1; Twin Guard takes its one rank: Intercept also covers the second most
			-- wounded ally (secondTarget, free of the 10A choice)
			node(G, "twinGuard", "modify", 1, "⇉", {
				values = { twinGuard = 100 },
				modify = { skill = "intercept", bp = { secondTarget = ref("twinGuard") } },
			}),
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
				values = { menaceThreat = { 30, 90 }, menaceDamage = { 2, 6 } },
				passive = { hooks = { threat = "menaceThreat", damagePerEnemy = "menaceDamage" } },
			}),
			node(G, "shieldMastery", "passive", 3, "⬢", {
				values = { shieldMastery = { 2, 6 } },
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
			-- S143: Last Bastion moved to the capstone (row 8); Shield Bash Mastery takes its one rank (the stun 0.5 s longer)
			node(G, "bashMastery", "modify", 1, "⬟", {
				values = { bashStun = 0.5 },
				modify = { skill = "shieldBash", bp = { add = { effectDuration = ref("bashStun") } } },
			}),
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
		-- S143: Shield Wall is the one-handed U; Last Bastion is the Guardian's capstone (DESIGN-18 §7: rows 4 and 8)
		row(false, { skill(G, "lastBastion") }),
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
				values = { veteran = { 1.5, 4.5 } },
				passive = { pct = { armor = "veteran", maxHp = "veteran" } },
			}),
		}),
		row(false, {
			-- S143: the capstone's upgrade follows the capstone (Shield Wall moved to the one-handed pool)
			node(G, "lastBastion2", "modify", 2, "▦", {
				values = { bastionTime = { 1, 2 }, bastionHold = { 2.5, 5 } },
				modify = {
					skill = "lastBastion",
					bp = {
						add = { effectDuration = ref("bastionTime") },
						values = { reduction = ref("bastionHold") },
					},
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
			-- S143: Cleave is the two-handed A1; Scars take its one rank
			node(B, "scars", "passive", 1, "≡", {
				values = { scars = 1 },
				passive = { pct = { maxHp = "scars" } },
			}),
			node(B, "wounds", "passive", 3, "♦", {
				values = { wounds = { 10, 30 } },
				passive = { hooks = { bleedDamage = "wounds" } },
			}),
		}),
		row(false, {
			-- S143: the cap above Rage's 6 stacks: 8 / 9 / 10 (HOOK_RULES.fury.maxStacks)
			node(B, "rhythm", "passive", 3, "♫", {
				values = { rhythmMax = { 2, 4 }, rhythmSpeed = 1 },
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
			-- S143: Rend is the two-handed S2; Frenzy takes its one rank (more damage per Fury stack, only with Rage)
			node(B, "frenzy", "passive", 1, "✹", {
				values = { frenzy = 0.3 },
				passive = { hooks = { furyDamage = "frenzy" } },
			}),
			node(B, "executioner", "passive", 3, "⚰", {
				values = { executioner = { 1.5, 4.5 } },
				passive = { hooks = { executioner = "executioner" } },
			}),
		}),
		row(false, {
			node(B, "rendingCuts", "modify", 3, "≋", {
				values = { rendingCuts = { 1.5, 4.5 } },
				modify = { skill = "cleave", bp = { add = { effectDuration = ref("rendingCuts") } } },
			}),
			node(B, "might", "passive", 3, "⚒", {
				values = { might = { 1, 3 } },
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
			-- S143: Titan's Wrath is the two-handed U; Reaper takes its one rank (Execute's threshold 30 -> 35 %)
			node(B, "reaper", "modify", 1, "⚚", {
				values = { reaper = 35 },
				modify = { skill = "execute", bp = { finisher = { hp = ref("reaper") } } },
			}),
			node(B, "thunder", "modify", 3, "☇", {
				values = { thunder = { 0.93, 0.8 } },
				modify = { skill = "titansWrath", bp = { mul = { cooldown = ref("thunder") } } },
			}),
		}),
		-- S138: Carnage needs a two-handed weapon (the old Berserker path weapon, now on the node)
		row(false, { needs(skill(B, "carnage"), { main = { "sword2h", "axe2h", "hammer2h", "spear2h" } }) }),
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
				values = { openWounds = { 1, 3 } },
				passive = { hooks = { bleedDamage = "openWounds" } },
			}),
			node(B, "hardened", "passive", 3, "⛰", {
				values = { hardened = { 2, 6 } },
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
			-- S143: Battle Cry is the Warrior's common C3; Pennant takes its one rank
			node(S, "pennant", "passive", 1, "⚑", {
				values = { pennant = 3 },
				passive = { pct = { armor = "pennant" } },
			}),
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
			-- S146: 4-12 -> 5-15 (the Standard-Bearer's own damage S >= 0.55 at 70 with the banner on its bar)
			node(S, "fervor", "modify", 3, "✹", {
				values = { fervor = { 5, 15 } },
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
			-- S143: War Banner is the one-handed K2; Herald takes its one rank (Battle Cry 4 s longer)
			node(S, "herald", "modify", 1, "♪", {
				values = { herald = 4 },
				modify = { skill = "battleCry", bp = { add = { effectDuration = ref("herald") } } },
			}),
			node(S, "colours", "modify", 3, "⚐", {
				values = { colours = { 1, 3 } },
				modify = { skill = "warBanner", bp = { add = { duration = ref("colours") } } },
			}),
		}),
		row(false, {
			node(S, "grit", "passive", 3, "❣", {
				values = { bearerGrit = { 3, 9 } },
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
			-- S143: Crushing Blow is the one-handed S2; Drill takes its one rank (War Banner's cooldown x0.85)
			node(S, "drill", "modify", 1, "⚒", {
				values = { drill = 0.85 },
				modify = { skill = "warBanner", bp = { mul = { cooldown = ref("drill") } } },
			}),
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
				values = { campaign = { 6, 18 } },
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
-- S143 (DESIGN-18 §6.2, §13): one build per pool and leading direction (Guardian and Standard-Bearer with Sword and
-- Shield, Berserker with Two-Handed), the moved skill nodes replaced by the nodes of the same ranks, `ranks` = the order
-- the model buys skill ranks in (the rotation's core first, the school passive at its unlock, utility last).
local function build(
	id: string,
	main: string,
	offhand: string?,
	stats: { [string]: number },
	nodes: { { any } },
	bp: { [string]: "a" | "b" },
	rotation: { { [string]: any } },
	ranks: { string },
	damageReference: boolean?,
	bar: { string }?
): Types.ReferenceBuild
	return {
		id = id,
		damageReference = damageReference,
		bar = bar,
		weapon = { main = main, offhand = offhand },
		nodes = nodes,
		bp = bp,
		stats = stats,
		rotation = rotation,
		ranks = ranks,
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
	["shieldSweep:5"] = "b",
	["shieldSweep:10"] = "b",
	["shieldBash:5"] = "b",
	["shieldBash:10"] = "a",
	["vindicate:5"] = "a",
	["vindicate:10"] = "b",
}
-- S143: the Sword and Shield rotation (Shield Sweep and Shield Bash for Blade Whirl and Cleave, Crushing Blow and
-- Vindicate from the pool)
local function guardianRotation(intercept: { [string]: any }): { { [string]: any } }
	return {
		intercept,
		{ skill = "taunt" },
		{ skill = "shieldWall" },
		{ skill = "battleCry" },
		{ skill = "crushingBlow" },
		{ skill = "vindicate" },
		{ skill = "mightyStrike" },
		{ skill = "shieldSweep" },
		{ skill = "shieldBash" },
		{ skill = "earthquake" },
	}
end
-- S146 (B1): the actives of the bar at 100, then the pool's passives, then the rest; skills open at 20 keep their order
local GUARDIAN_RANKS = {
	"mightyStrike",
	"shieldSweep",
	"intercept",
	"taunt",
	"fortitude",
	"crushingBlow",
	"shieldBash",
	"earthquake",
	"shieldWall",
	"steelSkin",
	"riposte",
	"vindicate",
	"lastBastion",
	"battleCry",
	"warBanner",
	"charge",
}

-- S146 (DESIGN-18 §4.1, §13): the 8 slots of the bar in priority (the first ones the character can cast at a level);
-- Shield Bash's stun before Vindicate's burst (the tank's T-SK1 / T-SK2 guards at 90-100)
local GUARDIAN_BAR = {
	"intercept",
	"taunt",
	"shieldWall",
	"crushingBlow",
	"mightyStrike",
	"shieldSweep",
	"earthquake",
	"shieldBash",
	"vindicate",
	"battleCry",
	"lastBastion",
	"charge",
}

guardian.reference = {
	build("defender", "sword1h", "shield", guardian.statPlan :: any, {
		{ "guardian_stalwart", 1 },
		{ "guardian_frontline", 3 },
		{ "berserker_scars", 1 },
		{ "berserker_wounds", 1 },
		{ "standard_pennant", 1 },
		{ "standard_breath", 3 },
		{ "guardian_block", 3 },
		{ "guardian_cover", 3 },
		{ "berserker_rhythm", 2 },
		{ "guardian_vow", 3 },
		{ "guardian_twinGuard", 1 },
		{ "guardian_sacrifice", 3 },
		{ "guardian_menace", 3 },
		{ "guardian_shieldMastery", 3 },
		{ "guardian_aegis", 3 },
		{ "guardian_bashMastery", 1 },
		{ "guardian_bastionCover", 3 },
		{ "guardian_lastBastion", 1 },
		{ "guardian_martyr", 3 },
		{ "guardian_fortress", 3 },
		{ "guardian_veteran", 3 },
		{ "guardian_lastBastion2", 2 },
	}, GUARDIAN_BP, guardianRotation({ skill = "intercept", target = "allyInZone" }), GUARDIAN_RANKS, nil, GUARDIAN_BAR),
	build("loner", "sword1h", "shield", guardian.statPlan :: any, {
		{ "guardian_stalwart", 1 },
		{ "guardian_frontline", 3 },
		{ "berserker_scars", 1 },
		{ "berserker_wounds", 3 },
		{ "standard_pennant", 1 },
		{ "standard_breath", 3 },
		{ "guardian_block", 3 },
		{ "berserker_rhythm", 3 },
		{ "berserker_bloodthirst", 3 },
		{ "guardian_retaliation", 3 },
		{ "guardian_twinGuard", 1 },
		{ "guardian_sacrifice", 3 },
		{ "guardian_menace", 3 },
		{ "guardian_shieldMastery", 3 },
		{ "guardian_grit", 3 },
		{ "guardian_bashMastery", 1 },
		{ "guardian_lastBastion", 1 },
		{ "guardian_retribution", 3 },
		{ "guardian_fortress", 3 },
		{ "guardian_veteran", 3 },
		{ "guardian_lastBastion2", 2 },
	}, GUARDIAN_BP, guardianRotation({ skill = "intercept", target = "self" }), GUARDIAN_RANKS, nil, GUARDIAN_BAR),
}

-- Berserker -----------------------------------------------------------------------------------------------------
local BERSERKER_BP: { [string]: "a" | "b" } = {
	["brutalStrike:5"] = "b",
	["brutalStrike:10"] = "b",
	["bladeWhirl:5"] = "b",
	["bladeWhirl:10"] = "a",
	["cleave:5"] = "a",
	["cleave:10"] = "a",
	["rend:5"] = "a",
	["rend:10"] = "a",
	["titansWrath:5"] = "b",
	["titansWrath:10"] = "a",
	["carnage:5"] = "a",
	["carnage:10"] = "a",
	["bloodlust:5"] = "b",
	["bloodlust:10"] = "b",
	["sunder:5"] = "b",
	["sunder:10"] = "b",
	["warStomp:5"] = "b",
	["warStomp:10"] = "b",
	["execute:5"] = "b",
	["execute:10"] = "b",
}
-- S143: the Two-Handed rotation (Brutal Strike for Mighty Strike, Sunder, War Stomp and Execute from the pool, no
-- Earthquake); minFury holds only with Fury (Rage, from 20; tests/SkillModel)
local BERSERKER_ROTATION: { { [string]: any } } = {
	{ skill = "carnage", minFury = 10 },
	{ skill = "battleCry" },
	{ skill = "bloodlust" },
	{ skill = "sunder" },
	{ skill = "rend", minFury = 8 },
	{ skill = "execute", minFury = 8 },
	{ skill = "titansWrath", minEnemies = 3 },
	{ skill = "warStomp", minEnemies = 2 },
	{ skill = "brutalStrike" },
	{ skill = "cleave" },
	{ skill = "bladeWhirl" },
	{ skill = "charge" },
}
-- S146 (B1): the actives of the bar at 100, then the pool's passives, then the rest; skills open at 20 keep their order
local BERSERKER_RANKS = {
	"brutalStrike",
	"cleave",
	"rend",
	"sunder",
	"bloodlust",
	"rage",
	"bladeWhirl",
	"execute",
	"titansWrath",
	"carnage",
	"steelSkin",
	"unstoppable",
	"battleCry",
	"warStomp",
	"charge",
	"taunt",
}
-- S143: Battle Rhythm before the other directions' rows 1-2 (Fury from Rage at 20 grows with it; the old Cleave node
-- gave the damage of rows 1-2 at 20)
local function berserkerNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "berserker_scars", 1 },
		{ "berserker_wounds", 3 },
		{ "berserker_rhythm", 3 },
		{ "guardian_stalwart", 1 },
		{ "guardian_frontline", 3 },
		{ "berserker_bloodthirst", 3 },
		{ "berserker_rendingCuts", 3 },
		{ row3, 3 },
		{ "standard_pennant", 1 },
		{ "standard_breath", 3 },
		{ "berserker_frenzy", 1 },
		{ "berserker_executioner", 3 },
		{ "berserker_might", 3 },
		{ row6, 3 },
		{ "berserker_reaper", 1 },
		{ "berserker_thunder", 3 },
		{ "berserker_carnage", 1 },
		{ row9, 3 },
		{ "berserker_openWounds", 3 },
		{ "berserker_hardened", 3 },
		{ "berserker_carnage2", 2 },
	}
end

-- S146: the bar (at 100 Bloodlust, Battle Cry, War Stomp and Charge leave it for Execute, Carnage and Titan's Wrath;
-- the damage reference within 1 % of its whole rotation before S146)
local BERSERKER_BAR = {
	"brutalStrike",
	"rend",
	"execute",
	"carnage",
	"sunder",
	"bladeWhirl",
	"titansWrath",
	"cleave",
	"bloodlust",
	"battleCry",
	"warStomp",
	"charge",
}

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
		BERSERKER_RANKS,
		true,
		BERSERKER_BAR
	),
	build(
		"butcher",
		"axe2h",
		nil,
		berserker.statPlan :: any,
		berserkerNodes("berserker_ferocity", "berserker_relentless", "berserker_drinker"),
		BERSERKER_BP,
		BERSERKER_ROTATION,
		BERSERKER_RANKS,
		nil,
		BERSERKER_BAR
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
	["shieldSweep:5"] = "b",
	["shieldSweep:10"] = "b",
	["shieldBash:5"] = "b",
	["shieldBash:10"] = "b",
	["vindicate:5"] = "b",
	["vindicate:10"] = "b",
}
-- S143: the Sword and Shield rotation of the Standard-Bearer (the banner first, then the cries and the pool's blows)
local STANDARD_ROTATION: { { [string]: any } } = {
	{ skill = "warBanner", opener = true },
	{ skill = "battleCry" },
	{ skill = "advanceOrder" },
	{ skill = "crushingBlow" },
	{ skill = "vindicate" },
	{ skill = "mightyStrike" },
	{ skill = "shieldSweep" },
	{ skill = "shieldBash" },
	{ skill = "earthquake" },
}
-- S146: the bar's blows first, then the cries and the banner, Intercept and Taunt (not on the Standard-Bearer's bar)
-- last; every skill open at 20 before Charge reaches its limit there, so 1-20 is unchanged
local STANDARD_RANKS = {
	"mightyStrike",
	"shieldSweep",
	"crushingBlow",
	"fortitude",
	"vindicate",
	"earthquake",
	"shieldBash",
	"battleCry",
	"warBanner",
	"advanceOrder",
	"steelSkin",
	"riposte",
	"intercept",
	"taunt",
	"shieldWall",
	"charge",
}
local function standardNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "standard_pennant", 1 },
		{ "standard_breath", 3 },
		{ "guardian_stalwart", 1 },
		{ "guardian_frontline", 3 },
		{ "berserker_scars", 1 },
		{ "berserker_wounds", 1 },
		{ "standard_command", 3 },
		{ "standard_march", 3 },
		{ "berserker_rhythm", 2 },
		{ row3, 3 },
		{ "standard_herald", 1 },
		{ "standard_colours", 3 },
		{ "standard_grit", 3 },
		{ "standard_wide", 3 },
		{ row6, 3 },
		{ "standard_drill", 1 },
		{ "standard_sunder", 3 },
		{ "standard_advanceOrder", 1 },
		{ row9, 3 },
		{ "standard_stamina", 3 },
		{ "standard_veteran", 3 },
		{ "standard_advanceOrder2", 2 },
	}
end

-- S146: the bar (the banner and the cries first, Shield Bash leaves it at 100)
local STANDARD_BAR = {
	"warBanner",
	"battleCry",
	"advanceOrder",
	"crushingBlow",
	"vindicate",
	"mightyStrike",
	"shieldSweep",
	"earthquake",
	"shieldBash",
	"charge",
}

standard.reference = {
	build(
		"commander",
		"sword1h",
		"shield",
		standard.statPlan :: any,
		standardNodes("standard_fervor", "standard_inspire", "standard_glory"),
		STANDARD_BP,
		STANDARD_ROTATION,
		STANDARD_RANKS,
		nil,
		STANDARD_BAR
	),
	build(
		"warden",
		"saber1h",
		"shield",
		standard.statPlan :: any,
		standardNodes("standard_formation", "standard_rally", "standard_oath"),
		STANDARD_BP,
		STANDARD_ROTATION,
		STANDARD_RANKS,
		nil,
		STANDARD_BAR
	),
}

return { guardian, berserker, standard } :: { Types.PathDef }
