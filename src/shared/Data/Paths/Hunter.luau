--!strict
-- Hunter paths (docs/ROZWOJ.md 11): marksman (single target), trapper (area, traps, poison), scout (party support: marks, falcon, Elite scouting).
-- Numbers are the ROZWOJ 11 starting values ({ rank 1, rank max }, linear); the balance sessions tune them. S144
-- (DESIGN-18 §6.3, §7): the skill nodes went to the weapon pools (Bow, Crossbow) and left nodes of the same ranks
-- (rows and need unchanged); skill nodes only in rows 4 and 8: the Scout's capstone is the Drive (row 8; the Royal
-- Falcon keystone moved to row 10), the Marksman's and the Trapper's capstones are keystones that change a rule (Dead
-- Eye: Logic/DeadEye; Master Trapper: Logic/Crossbow.tipFor) and their rows 4 hold no skill. Nodes that strengthen the
-- falcon, the traps or the aim work while that skill is in the active pool (S138). Shape:
-- Data/Paths/Warrior (S75). Rank-dependent numbers sit in `values`, passive names the field, in modify.bp a number is
-- { ref = "<field>" }. Hooks are the S76 / S77 names (CombatService, Skills/Context, Skills/Companion, Movement.trap);
-- minimapEliteBonus (S78) is read by PartyService and the minimap. `reference` and `itemWeights` never reach the
-- wiki; S148: the directions are published there (DESIGN-18 §14).

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
	assert(def, `Paths/Hunter: unknown skill {skillId}`)
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

-- team hook (S57 marker; S138: 1/3 below TEAM_FULL_POINTS in the direction)
local TEAM_DIP = 1 / 3

local M, T, S = "marksman", "trapper", "scout"

local marksman: Types.PathDef = {
	id = M,
	class = "Hunter",
	order = 1,
	role = "damage",
	nameKey = "path.marksman.name",
	descKey = "path.marksman.desc",
	titleId = "path_marksman",
	weapon = { main = { "longbow", "heavycrossbow" } },
	statPlan = { dex = 4, vit = 1 },
	itemWeights = {
		stats = {
			critChance = 1.3,
			critDmg = 1.3,
			pierce = 1.3,
			skillDmg = 1.3,
			atkSpeed = 0.9,
			basicDmg = 0.8,
			poisonChance = 0.8,
			dotPower = 0.8,
		},
		traits = {
			criticalForce = 1.3,
			bodkinBolt = 1.3,
			fullDraw = 1,
			toxicBarbs = 0.3,
			easyPrey = 0.3,
			harrying = 0.3,
		},
	},
	rows = {
		row(false, {
			-- S144: Piercing Arrow is the Crossbow's A1; True Fletching takes its one rank
			node(M, "fletching", "passive", 1, "➵", {
				values = { fletching = 3 },
				passive = { flat = { critDmg = "fletching" } },
			}),
			node(M, "steadyHand", "passive", 3, "✋", {
				values = { steadyHand = { 1, 3 } },
				passive = { flat = { critChance = "steadyHand" } },
			}),
		}),
		row(false, {
			node(M, "rhythm", "modify", 3, "♫", {
				values = { rhythm = { 20, 50 } },
				modify = { skill = "aimedShot", bp = { critCdr = ref("rhythm") } },
			}),
			node(M, "precision", "passive", 3, "✧", {
				values = { precision = { 5, 15 } },
				passive = { flat = { critDmg = "precision" } },
			}),
		}),
		row(true, {
			node(M, "weakSpot", "passive", 3, "⊙", {
				values = { weakSpot = { 3, 9 } },
				passive = { hooks = { weakSpot = "weakSpot" } },
			}),
			node(M, "slayer", "passive", 3, "♛", {
				values = { slayer = { 4, 12 } },
				passive = { hooks = { bossDamage = "slayer", eliteDamage = "slayer" } },
			}),
		}),
		row(false, {
			-- S144: Draw a Bead is the Hunter's common C3; Patience takes its one rank (Draw a Bead +1 crit point)
			node(M, "patience", "modify", 1, "⊚", {
				values = { patience = 1 },
				modify = { skill = "drawBead", bp = { values = { crit = ref("patience") } } },
			}),
			node(M, "heldBreath", "modify", 3, "◌", {
				values = { heldBreath = { 0.25, 0.75 } },
				modify = { skill = "drawBead", bp = { add = { effectDuration = ref("heldBreath") } } },
			}),
		}),
		row(false, {
			node(M, "longShot", "modify", 3, "⟶", {
				values = { longShot = { 3, 8 } },
				modify = { skill = "aimedShot", bp = { values = { dmg = ref("longShot") } } },
			}),
			node(M, "keenSight", "passive", 3, "◉", {
				values = { keenSight = { 0.3, 0.9 } },
				passive = { flat = { critChance = "keenSight" } },
			}),
		}),
		row(true, {
			node(M, "coupDeGrace", "passive", 3, "⚰", {
				values = { coupDeGrace = { 1.7, 5 } },
				passive = { hooks = { executioner = "coupDeGrace" } },
			}),
			node(M, "reflex", "passive", 3, "↯", {
				values = { reflex = { 2, 6 } },
				passive = { flat = { dodge = "reflex" } },
			}),
		}),
		row(false, {
			-- S144: Storm Arrow is the Bow's U; Poise takes its one rank
			node(M, "poise", "passive", 1, "⚖", {
				values = { poise = 0.5 },
				passive = { flat = { critChance = "poise" } },
			}),
			node(M, "tempest", "modify", 3, "☈", {
				values = { tempest = { 0.92, 0.78 } },
				modify = { skill = "stormArrow", bp = { mul = { cooldown = ref("tempest") } } },
			}),
		}),
		-- S144: Heartseeker is the Bow's S3; the capstone is the keystone Dead Eye (DESIGN-18 §7: no skill in row 8 of the
		-- Marksman): the main hits of one-target skills on a target at deadEye % health or more always crit, with any
		-- weapon (Logic/DeadEye; Skills/Context, the model)
		row(false, {
			node(M, "deadEye", "keystone", 1, "◉", {
				values = { deadEye = 80, deadEyeDmg = 10 },
				passive = { flat = { critDmg = "deadEyeDmg" }, hooks = { deadEye = "deadEye" } },
			}),
		}),
		row(true, {
			node(M, "deadlyTip", "modify", 3, "➴", {
				values = { deadlyTip = { 25, 36 } },
				-- the breakpoint overrides the finisher fields it gives (S76): the threshold, not the multiplier
				modify = { skill = "heartseeker", bp = { finisher = { hp = ref("deadlyTip") } } },
			}),
			node(M, "sniper", "modify", 3, "⌖", {
				values = { sniper = { -0.2, -0.6 } },
				modify = { skill = "heartseeker", bp = { add = { castTime = ref("sniper") } } },
			}),
		}),
		row(false, {
			node(M, "grit", "passive", 3, "❤", {
				values = { grit = { 4, 11 } },
				passive = { pct = { maxHp = "grit" } },
			}),
			node(M, "coldBlood", "passive", 3, "❄", {
				values = { coldBlood = { 7, 21 } },
				passive = { pct = { armor = "coldBlood" } },
			}),
		}),
		row(false, {
			node(M, "heartseeker2", "modify", 2, "♚", {
				values = { kingslayer = { 15, 30 } },
				modify = { skill = "heartseeker", bp = { values = { dmg = ref("kingslayer") } } },
			}),
		}),
	},
	reference = {},
}

local trapper: Types.PathDef = {
	id = T,
	class = "Hunter",
	order = 2,
	role = "damage",
	nameKey = "path.trapper.name",
	descKey = "path.trapper.desc",
	titleId = "path_trapper",
	weapon = { main = { "crossbow", "bow" } },
	statPlan = { dex = 3, vit = 1 },
	itemWeights = {
		stats = {
			poisonChance = 1.5,
			dotPower = 1.5,
			skillDmg = 1.2,
			critChance = 0.8,
			critDmg = 0.8,
		},
		traits = {
			toxicBarbs = 1.3,
			easyPrey = 1.3,
			fullDraw = 1,
			criticalForce = 0.3,
			bodkinBolt = 0.3,
			harrying = 0.3,
		},
	},
	rows = {
		row(false, {
			-- S144: Frost Trap is the Crossbow's K1; Hunter's Leathers take its one rank
			node(T, "leathers", "passive", 1, "▤", {
				values = { leathers = 1 },
				passive = { pct = { maxHp = "leathers" } },
			}),
			node(T, "venom", "passive", 3, "☠", {
				values = { venom = { 10, 30 } },
				passive = { hooks = { poisonDamage = "venom" } },
			}),
		}),
		row(false, {
			node(T, "virulence", "modify", 3, "⚗", {
				values = { virulence = { 2, 6 } },
				modify = {
					skill = "venomArrow",
					bp = { add = { effectDuration = ref("virulence") }, poisonStacks = 3 },
				},
			}),
			node(T, "thrift", "passive", 3, "⚖", {
				values = { thrift = { 10, 30 } },
				passive = { hooks = { trapCost = "thrift" } },
			}),
		}),
		row(true, {
			node(T, "contagion", "passive", 3, "☣", {
				values = { contagion = { 1, 3 } },
				passive = { hooks = { poisonSpread = "contagion" } },
			}),
			node(T, "toxicologist", "passive", 3, "⚕", {
				values = { toxicologist = { 4, 10 } },
				passive = { hooks = { poisonedGuard = "toxicologist" } },
			}),
		}),
		row(false, {
			-- S144: Venom Snare is the Crossbow's A2; Bait takes its one rank (Venom Snare's poison +10 points)
			node(T, "bait", "modify", 1, "⚘", {
				values = { bait = 10 },
				modify = { skill = "venomSnare", bp = { values = { poison = ref("bait") } } },
			}),
			node(T, "huntingGround", "passive", 3, "⛺", {
				values = { huntingGround = { 2, 5 } },
				passive = { hooks = { areaSkillDamage = "huntingGround" } },
			}),
		}),
		row(false, {
			node(T, "bitingRain", "modify", 3, "☂", {
				values = { bitingWave = { 4, 11 }, bitingField = { 2.5, 7.5 } },
				modify = {
					skill = "arrowRain",
					bp = {
						firstWave = ref("bitingWave"),
						lingering = { kind = "poison", duration = 4, pct = ref("bitingField") },
					},
				},
			}),
			node(T, "spoils", "passive", 3, "⚡", {
				values = { spoils = { 1, 2 } },
				passive = { hooks = { trapEnergy = "spoils" } },
			}),
		}),
		row(true, {
			node(T, "blastTrap", "modify", 3, "✹", {
				values = { blastDmg = { 12, 38 }, blastPoison = { 9, 25 } },
				modify = {
					skill = "frostTrap",
					bp = {
						values = { dmg = ref("blastDmg"), poison = ref("blastPoison") },
						-- the same effect as Frost Trap 5B: it merges, the poison values add up (S78 D4)
						effect = { kind = "poison", duration = 6, value = "poison" },
					},
				},
			}),
			node(T, "entrap", "passive", 3, "⛓", {
				values = { entrap = { 0.5, 1.5 } },
				passive = { hooks = { trapRootDuration = "entrap" } },
			}),
		}),
		row(false, {
			-- S144: Camouflage is the Crossbow's O1; Stalker takes its one rank
			node(T, "stalker", "passive", 1, "◗", {
				values = { stalker = 1 },
				passive = { flat = { dodge = "stalker" } },
			}),
			node(T, "ambush", "modify", 3, "◐", {
				values = { ambush = { 0.9, 0.7 } },
				modify = { skill = "camouflage", bp = { mul = { cooldown = ref("ambush") } } },
			}),
		}),
		-- S144: Snarefield is the Crossbow's U; the capstone is the keystone Master Trapper (DESIGN-18 §7: no skill in row
		-- 8 of the Trapper): every hit of a trap adds a stack of the tip poison worth at least masterTip % without the
		-- tip's gap (Logic/Crossbow.tipFor; Toxic Tips not needed), and every poison of the Hunter is stronger
		row(false, {
			node(T, "masterTrapper", "keystone", 1, "⛓", {
				values = { masterTip = 15, masterVenom = 10 },
				passive = { hooks = { masterTrapper = "masterTip", poisonDamage = "masterVenom" } },
			}),
		}),
		row(true, {
			node(T, "denseSnares", "modify", 3, "⁜", {
				values = { denseSnares = { 1, 3 } },
				modify = { skill = "snarefield", bp = { add = { hits = ref("denseSnares") } } },
			}),
			node(T, "numbingVenom", "passive", 3, "≈", {
				values = { numbingVenom = { 10, 20 } },
				passive = { hooks = { poisonSlow = "numbingVenom" } },
			}),
		}),
		row(false, {
			node(T, "basilisk", "passive", 3, "🐍", {
				values = { basilisk = { 2.5, 7.5 } },
				passive = { hooks = { poisonDamage = "basilisk" } },
			}),
			node(T, "woodsman", "passive", 3, "🌲", {
				values = { woodsman = { 5, 14 } },
				passive = { pct = { maxHp = "woodsman" } },
			}),
		}),
		row(false, {
			node(T, "snarefield2", "modify", 2, "☗", {
				values = { deathField = { 24, 47 } },
				modify = {
					skill = "snarefield",
					bp = {
						values = { poison = ref("deathField") },
						effect = { kind = "poison", duration = 6, value = "poison" },
					},
				},
			}),
		}),
	},
	reference = {},
}

local scout: Types.PathDef = {
	id = S,
	class = "Hunter",
	order = 3,
	role = "support",
	nameKey = "path.scout.name",
	descKey = "path.scout.desc",
	titleId = "path_scout",
	weapon = { main = { "shortbow", "bow" } },
	statPlan = { dex = 3, vit = 2 },
	itemWeights = {
		stats = {
			atkSpeed = 1.3,
			basicDmg = 1.3,
			dodge = 1.2,
			vit = 1.2,
			maxHp = 1.2,
		},
		traits = {
			harrying = 1.3,
			fullDraw = 1.2,
			toxicBarbs = 1,
			criticalForce = 0.3,
			bodkinBolt = 0.3,
			easyPrey = 0.3,
		},
	},
	rows = {
		row(false, {
			-- S144: Agility is the Bow's P2; Fleet Foot takes its one rank
			node(S, "fleet", "passive", 1, "⇢", {
				values = { fleet = 3 },
				passive = { flat = { moveSpeed = "fleet" } },
			}),
			node(S, "eye", "passive", 3, "👁", {
				values = { eye = { 60, 180 } },
				passive = { hooks = { minimapEliteBonus = "eye" } },
				dipScale = TEAM_DIP, -- team hook (S57 marker; S138: 1/3 below TEAM_FULL_POINTS in the direction)
			}),
		}),
		row(false, {
			node(S, "spotting", "passive", 3, "⌾", {
				values = { spotting = { 2, 6 } },
				passive = { hooks = { spotOnHit = "spotting" } },
				dipScale = TEAM_DIP, -- team hook (S57 marker; S138: 1/3 below TEAM_FULL_POINTS in the direction)
			}),
			node(S, "vigilance", "passive", 3, "⚠", {
				values = { vigilance = { 10, 20 } },
				passive = { hooks = { vigilanceMove = "vigilance" } },
				dipScale = TEAM_DIP, -- team hook (S57 marker; S138: 1/3 below TEAM_FULL_POINTS in the direction)
			}),
		}),
		row(true, {
			node(S, "quickFingers", "passive", 3, "»", {
				values = { quickFingers = { 3, 9 } },
				passive = { flat = { atkSpeed = "quickFingers" } },
			}),
			node(S, "lightStep", "passive", 3, "〰", {
				values = { lightStep = { 2, 6 } },
				passive = { flat = { dodge = "lightStep" } },
			}),
		}),
		row(false, {
			-- S144: the Falcon is the Bow's K2; Falconer takes its one rank (the Falcon stays 2 s longer)
			node(S, "falconer", "modify", 1, "⌒", {
				values = { falconer = 2 },
				modify = { skill = "falcon", bp = { add = { duration = ref("falconer") } } },
			}),
			node(S, "talons", "modify", 3, "⋎", {
				values = { talons = { 10, 29 } },
				modify = { skill = "falcon", bp = { values = { dmg = ref("talons") } } },
			}),
		}),
		row(false, {
			node(S, "bond", "passive", 3, "∞", {
				-- bondDive only for the text: falconBond x HOOK_RULES.royalFalcon.bondDive (Skills/Companion)
				values = { bond = { 1.3, 3.8 }, bondDive = { 13, 38 } },
				passive = { hooks = { falconBond = "bond" } },
			}),
			node(S, "hardy", "passive", 3, "⛰", {
				values = { hardy = { 0.8, 2.5 } },
				passive = { pct = { maxHp = "hardy" } },
			}),
		}),
		row(true, {
			node(S, "retreat", "modify", 3, "⤺", {
				values = { retreat = { 0.9, 0.7 } },
				modify = { skill = "disengage", bp = { mul = { cooldown = ref("retreat") } } },
			}),
			node(S, "warning", "passive", 3, "⛉", {
				values = { warning = { 5, 15 } },
				passive = { hooks = { vigilanceGuard = "warning" } },
			}),
		}),
		row(false, {
			-- S144: Hunter's Mark is the Hunter's common C2; Keen Mark takes its one rank (+0.5 vulnerability points)
			node(S, "keenMark", "modify", 1, "⌖", {
				values = { keenMark = 0.5 },
				modify = { skill = "huntersMark", bp = { values = { vuln = ref("keenMark") } } },
			}),
			node(S, "trail", "modify", 3, "⇢", {
				values = { trail = { 10, 20 } },
				modify = { skill = "huntersMark", bp = { markJump = ref("trail") } },
			}),
		}),
		-- S144: the Drive is the Scout's capstone (row 8, DESIGN-18 §7); the Royal Falcon keystone moved to row 10
		row(false, { skill(S, "drive") }),
		row(true, {
			node(S, "quickMark", "modify", 3, "⌛", {
				values = { quickMark = { 0.91, 0.74 } },
				modify = { skill = "huntersMark", bp = { mul = { cooldown = ref("quickMark") } } },
			}),
			node(S, "duet", "passive", 3, "⚭", {
				values = { duet = { 10, 30 } },
				passive = { hooks = { falconDamage = "duet" } },
			}),
		}),
		row(false, {
			-- the first keystone of the game: the rule lives in Skills/Companion (S77), the numbers in
			-- HOOK_RULES.royalFalcon. S144: row 10 (was the capstone of row 8; the Drive took row 8)
			node(S, "royalFalcon", "keystone", 1, "♔", {
				values = { on = { 1, 1 } },
				passive = { hooks = { royalFalcon = "on" } },
			}),
			node(S, "beater", "modify", 3, "⚑", {
				values = { beater = { 1.8, 5.5 } },
				-- one kind each (S75 add.<kind>Duration): the 10B root stays 1 s
				modify = {
					skill = "drive",
					bp = { add = { vulnerabilityDuration = ref("beater"), slowDuration = ref("beater") } },
				},
			}),
		}),
		row(false, {
			node(S, "royalFalcon2", "passive", 2, "♕", {
				values = { sovereignPace = { 19, 38 }, sovereignMark = { 0.1, 0.2 } },
				passive = { hooks = { falconInterval = "sovereignPace", spotBonus = "sovereignMark" } },
			}),
		}),
	},
	reference = {},
}

-- Model builds (ROZWOJ 7.5, 11.3-11.5; shape in Data/Paths/Types): each spends exactly pointsAt(100) = 50 points.
-- r7Exempt (Trapper, 15.4.2) and notInZone are read by the balance model, never by the game.
-- S144 (DESIGN-18 §6.3, §13): one build per pool and leading direction (the Marksman with a longbow and the Scout with a
-- shortbow in the Bow pool, the Trapper with a crossbow in the Crossbow pool), the moved skill nodes replaced by the
-- nodes of the same ranks, `ranks` = the order the model buys skill ranks in. A rotation lists the skills of both pools
-- (a skill of the other pool has no rank and is skipped), so the model measures a build with the other weapon too (S90).
local function build(
	id: string,
	main: string,
	stats: { [string]: number },
	nodes: { { any } },
	bp: { [string]: "a" | "b" },
	rotation: { { [string]: any } },
	ranks: { string },
	r7Exempt: boolean?
): Types.ReferenceBuild
	return {
		id = id,
		r7Exempt = r7Exempt,
		weapon = { main = main, offhand = "quiver" },
		nodes = nodes,
		bp = bp,
		stats = stats,
		rotation = rotation,
		ranks = ranks,
	}
end

-- Marksman ------------------------------------------------------------------------------------------------------
local function marksmanNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "marksman_fletching", 1 },
		{ "marksman_steadyHand", 3 },
		{ "scout_fleet", 1 },
		{ "scout_eye", 1 },
		{ "trapper_leathers", 1 },
		{ "trapper_venom", 2 },
		{ "marksman_rhythm", 3 },
		{ "marksman_precision", 3 },
		{ "scout_spotting", 3 },
		{ row3, 3 },
		{ "marksman_patience", 1 },
		{ "marksman_heldBreath", 3 },
		{ "marksman_longShot", 3 },
		{ "marksman_keenSight", 3 },
		{ row6, 3 },
		{ "marksman_poise", 1 },
		{ "marksman_tempest", 3 },
		{ "marksman_deadEye", 1 },
		{ row9, 3 },
		{ "marksman_grit", 3 },
		{ "marksman_coldBlood", 3 },
		{ "marksman_heartseeker2", 2 },
	}
end

-- S144: the one target skills of both pools first (Bow: Aimed Shot, Heartseeker, Storm Arrow; Crossbow: Heavy Bolt,
-- the Executioner's Bolt on the poison stacks, Venom Arrow); Pinning Shot as a filler
local MARKSMAN_RANKS = {
	"aimedShot",
	"heavyBolt",
	"doubleShot",
	"venomArrow",
	"hawkEye",
	"toxicTips",
	"arrowRain",
	"piercingArrow",
	"pinningShot",
	"frostTrap",
	"drawBead",
	"heartseeker",
	"deadlyBolt",
	"stormArrow",
	"snarefield",
	"predatorInstinct",
	"agility",
	"quickReload",
	"volley",
	"venomSnare",
	"huntersMark",
	"falcon",
	"netShot",
	"disengage",
	"windstep",
	"camouflage",
}

marksman.reference = {
	build(
		"kingslayer",
		"longbow", -- S144: the Bow (was the heavy crossbow); the balance model also runs it with the heavy crossbow
		marksman.statPlan :: any,
		marksmanNodes("marksman_slayer", "marksman_coupDeGrace", "marksman_deadlyTip"),
		{
			["aimedShot:5"] = "b",
			["drawBead:5"] = "b",
			["drawBead:10"] = "b",
			["stormArrow:5"] = "b",
			["stormArrow:10"] = "b",
			["heavyBolt:5"] = "b",
			["heavyBolt:10"] = "b",
			["deadlyBolt:5"] = "b",
			["deadlyBolt:10"] = "b",
			["pinningShot:5"] = "b",
			["pinningShot:10"] = "b",
		},
		{
			{ skill = "drawBead" },
			{ skill = "heartseeker", notInZone = true },
			{ skill = "stormArrow" },
			{ skill = "deadlyBolt" },
			{ skill = "aimedShot" },
			{ skill = "heavyBolt" },
			{ skill = "venomArrow" },
			{ skill = "piercingArrow" },
			{ skill = "doubleShot" },
			{ skill = "pinningShot" },
			{ skill = "volley" },
			{ skill = "arrowRain" },
		},
		MARKSMAN_RANKS
	),
	build(
		"eliteHunter",
		"longbow",
		marksman.statPlan :: any,
		marksmanNodes("marksman_weakSpot", "marksman_reflex", "marksman_sniper"),
		{
			["drawBead:5"] = "b",
			["drawBead:10"] = "b",
			["stormArrow:5"] = "b",
			["stormArrow:10"] = "b",
			["heartseeker:5"] = "b",
			["heartseeker:10"] = "b",
			["heavyBolt:5"] = "a",
			["heavyBolt:10"] = "a",
			["deadlyBolt:5"] = "b",
			["deadlyBolt:10"] = "b",
			["pinningShot:5"] = "b",
			["pinningShot:10"] = "b",
		},
		{
			{ skill = "drawBead" },
			{ skill = "heartseeker", notInZone = true },
			{ skill = "stormArrow" },
			{ skill = "volley", minEnemies = 3 },
			{ skill = "arrowRain", minEnemies = 3 },
			{ skill = "piercingArrow", minEnemies = 3 },
			{ skill = "deadlyBolt" },
			{ skill = "aimedShot" },
			{ skill = "heavyBolt" },
			{ skill = "venomArrow" },
			{ skill = "doubleShot" },
			{ skill = "pinningShot" },
		},
		MARKSMAN_RANKS
	),
}

-- Trapper -------------------------------------------------------------------------------------------------------
-- The 8 ranks outside the path (ROZWOJ gives none): rows 1 of the Marksman and the Scout, as in the 11.6 measurement.
local function trapperNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "trapper_leathers", 1 },
		{ "trapper_venom", 3 },
		{ "marksman_fletching", 1 },
		{ "marksman_steadyHand", 3 },
		{ "scout_fleet", 1 },
		{ "scout_eye", 3 },
		{ "trapper_virulence", 3 },
		{ "trapper_thrift", 3 },
		{ row3, 3 },
		{ "trapper_bait", 1 },
		{ "trapper_huntingGround", 3 },
		{ "trapper_bitingRain", 3 },
		{ "trapper_spoils", 3 },
		{ row6, 3 },
		{ "trapper_stalker", 1 },
		{ "trapper_ambush", 3 },
		{ "trapper_masterTrapper", 1 },
		{ row9, 3 },
		{ "trapper_basilisk", 3 },
		{ "trapper_woodsman", 3 },
		{ "trapper_snarefield2", 2 },
	}
end

-- S144: the Crossbow's area, traps and poison first (Piercing Bolt, Venom Arrow and Toxic Tips feed the Executioner's
-- Bolt), then the Bow's for the other weapon
local TRAPPER_RANKS = {
	"heavyBolt",
	"piercingArrow",
	"venomArrow",
	"toxicTips",
	"frostTrap",
	"aimedShot",
	"arrowRain",
	"doubleShot",
	"hawkEye",
	"venomSnare",
	"volley",
	"netShot",
	"deadlyBolt",
	"snarefield",
	"predatorInstinct",
	"quickReload",
	"agility",
	"pinningShot",
	"camouflage",
	"drawBead",
	"huntersMark",
	"heartseeker",
	"stormArrow",
	"falcon",
	"disengage",
	"windstep",
}

trapper.reference = {
	build(
		"poacher",
		"crossbow", -- the balance model also runs it with the bow (S90)
		trapper.statPlan :: any,
		trapperNodes("trapper_contagion", "trapper_blastTrap", "trapper_denseSnares"),
		{
			["frostTrap:5"] = "b",
			["frostTrap:10"] = "b",
			["venomSnare:5"] = "b",
			["snarefield:10"] = "b",
			["arrowRain:10"] = "b",
			["heavyBolt:5"] = "a",
			["heavyBolt:10"] = "a",
			["netShot:5"] = "b",
			["netShot:10"] = "b",
			["deadlyBolt:5"] = "a",
			["deadlyBolt:10"] = "a",
		},
		{
			{ skill = "snarefield", opener = true },
			{ skill = "venomSnare" },
			{ skill = "arrowRain" },
			{ skill = "volley" },
			{ skill = "piercingArrow" },
			{ skill = "netShot" },
			{ skill = "venomArrow" },
			{ skill = "deadlyBolt" },
			{ skill = "frostTrap" },
			{ skill = "heavyBolt" },
			{ skill = "aimedShot" },
			{ skill = "doubleShot" },
		},
		TRAPPER_RANKS,
		true
	),
	build(
		"poisoner",
		"crossbow", -- S144: the Crossbow (was the bow: the traps and the poison are the Crossbow's school)
		trapper.statPlan :: any,
		trapperNodes("trapper_toxicologist", "trapper_blastTrap", "trapper_numbingVenom"),
		{
			["frostTrap:5"] = "b",
			["frostTrap:10"] = "b",
			["venomSnare:5"] = "b",
			["venomSnare:10"] = "b",
			["snarefield:10"] = "b",
			["arrowRain:10"] = "b",
			["venomArrow:10"] = "b",
			["heavyBolt:5"] = "a",
			["heavyBolt:10"] = "b",
			["netShot:5"] = "b",
			["netShot:10"] = "b",
			["deadlyBolt:5"] = "b",
			["deadlyBolt:10"] = "a",
		},
		{
			{ skill = "venomSnare" },
			{ skill = "venomArrow" },
			{ skill = "deadlyBolt" },
			{ skill = "snarefield" },
			{ skill = "frostTrap" },
			{ skill = "heavyBolt" },
			{ skill = "aimedShot" },
			{ skill = "piercingArrow" },
			{ skill = "doubleShot" },
			{ skill = "arrowRain" },
			{ skill = "netShot", minEnemies = 3 },
			{ skill = "volley", minEnemies = 3 },
		},
		TRAPPER_RANKS,
		true
	),
}

-- Scout ---------------------------------------------------------------------------------------------------------
local function scoutNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "scout_fleet", 1 },
		{ "scout_eye", 3 },
		{ "marksman_fletching", 1 },
		{ "marksman_steadyHand", 3 },
		{ "scout_spotting", 3 },
		{ "scout_vigilance", 3 },
		{ "marksman_rhythm", 3 },
		{ "marksman_precision", 3 },
		{ row3, 3 },
		{ "scout_falconer", 1 },
		{ "scout_talons", 3 },
		{ "scout_bond", 3 },
		{ "scout_hardy", 3 },
		{ row6, 3 },
		{ "scout_keenMark", 1 },
		{ "scout_trail", 3 },
		{ "scout_drive", 1 },
		{ row9, 3 },
		{ "scout_royalFalcon", 1 },
		{ "scout_beater", 3 },
		{ "scout_royalFalcon2", 2 },
	}
end

-- S144: the Bow's falcon and marks first (Hunter's Mark from 12, the Falcon from 33)
local SCOUT_ROTATION: { { [string]: any } } = {
	{ skill = "huntersMark" },
	{ skill = "falcon", opener = true },
	{ skill = "drive", minEnemies = 3 },
	{ skill = "aimedShot" },
	{ skill = "heavyBolt" },
	{ skill = "venomArrow" },
	{ skill = "doubleShot" },
	{ skill = "deadlyBolt" },
	{ skill = "piercingArrow" },
	{ skill = "pinningShot" },
	{ skill = "arrowRain", minEnemies = 3 },
	{ skill = "volley", minEnemies = 3 },
}
local SCOUT_RANKS = {
	"aimedShot",
	"heavyBolt",
	"huntersMark",
	"doubleShot",
	"venomArrow",
	"hawkEye",
	"toxicTips",
	"arrowRain",
	"piercingArrow",
	"disengage",
	"pinningShot",
	"windstep",
	"falcon",
	"drive",
	"volley",
	"deadlyBolt",
	"predatorInstinct",
	"agility",
	"quickReload",
	"drawBead",
	"heartseeker",
	"stormArrow",
	"frostTrap",
	"venomSnare",
	"netShot",
	"snarefield",
	"camouflage",
}

scout.reference = {
	-- the model build of ROZWOJ 7.5 for the Hunter (support); the balance model also runs it with the shortbow (S90)
	build(
		"partyHunter",
		"bow",
		scout.statPlan :: any,
		scoutNodes("scout_lightStep", "scout_warning", "scout_quickMark"),
		{
			["huntersMark:10"] = "b",
			["drive:5"] = "b",
			["disengage:5"] = "b",
			["disengage:10"] = "b",
			["pinningShot:5"] = "b",
			["pinningShot:10"] = "b",
			["windstep:5"] = "b",
			["windstep:10"] = "b",
		},
		SCOUT_ROTATION,
		SCOUT_RANKS
	),
	build(
		"tracker",
		"shortbow",
		scout.statPlan :: any,
		scoutNodes("scout_quickFingers", "scout_retreat", "scout_duet"),
		{
			["huntersMark:5"] = "b",
			["huntersMark:10"] = "b",
			["drive:5"] = "b",
			["disengage:5"] = "b",
			["disengage:10"] = "b",
			["pinningShot:5"] = "b",
			["pinningShot:10"] = "b",
			["windstep:5"] = "b",
			["windstep:10"] = "b",
		},
		SCOUT_ROTATION,
		SCOUT_RANKS
	),
}

return { marksman, trapper, scout } :: { Types.PathDef }
