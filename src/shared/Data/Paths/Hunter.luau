--!strict
-- Hunter paths (docs/ROZWOJ.md 11): marksman (single target), trapper (area, traps, poison), scout (party support: marks, falcon, Elite scouting).
-- Numbers are the ROZWOJ 11 starting values ({ rank 1, rank max }, linear); the balance sessions tune them. Shape:
-- Data/Paths/Warrior (S75). Rank-dependent numbers sit in `values`, passive names the field, in modify.bp a number is
-- { ref = "<field>" }. Hooks are the S76 / S77 names (CombatService, Skills/Context, Skills/Companion, Movement.trap);
-- minimapEliteBonus (S78) is read by PartyService and the minimap. `reference` and `itemWeights` never reach the
-- wiki; every path is unpublished there (wiki = false, ROZWOJ 3.5).

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

-- team hook (S57 marker): 1/3 outside the main path
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
			skill(M, "piercingArrow"),
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
			skill(M, "drawBead"),
			node(M, "heldBreath", "modify", 3, "◌", {
				values = { heldBreath = { 1, 3 } },
				modify = { skill = "drawBead", bp = { add = { effectDuration = ref("heldBreath") } } },
			}),
		}),
		row(false, {
			node(M, "longShot", "modify", 3, "⟶", {
				values = { longShot = { 10, 30 } },
				modify = { skill = "aimedShot", bp = { values = { dmg = ref("longShot") } } },
			}),
			node(M, "keenSight", "passive", 3, "◉", {
				values = { keenSight = { 1, 3 } },
				passive = { flat = { critChance = "keenSight" } },
			}),
		}),
		row(true, {
			node(M, "coupDeGrace", "passive", 3, "⚰", {
				values = { coupDeGrace = { 5, 15 } },
				passive = { hooks = { executioner = "coupDeGrace" } },
			}),
			node(M, "reflex", "passive", 3, "↯", {
				values = { reflex = { 2, 6 } },
				passive = { flat = { dodge = "reflex" } },
			}),
		}),
		row(false, {
			skill(M, "stormArrow"),
			node(M, "tempest", "modify", 3, "☈", {
				values = { tempest = { 0.93, 0.8 } },
				modify = { skill = "stormArrow", bp = { mul = { cooldown = ref("tempest") } } },
			}),
		}),
		row(false, { skill(M, "heartseeker") }),
		row(true, {
			node(M, "deadlyTip", "modify", 3, "➴", {
				values = { deadlyTip = { 25, 35 } },
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
				values = { grit = { 4, 12 } },
				passive = { pct = { maxHp = "grit" } },
			}),
			node(M, "coldBlood", "passive", 3, "❄", {
				values = { coldBlood = { 5, 15 } },
				passive = { pct = { armor = "coldBlood" } },
			}),
		}),
		row(false, {
			node(M, "heartseeker2", "modify", 2, "♚", {
				values = { kingslayer = { 60, 120 } },
				modify = { skill = "heartseeker", bp = { values = { dmg = ref("kingslayer") } } },
			}),
		}),
	},
	reference = {},
	wiki = false,
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
			skill(T, "frostTrap"),
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
			skill(T, "venomSnare"),
			node(T, "huntingGround", "passive", 3, "⛺", {
				values = { huntingGround = { 7, 20 } },
				passive = { hooks = { areaSkillDamage = "huntingGround" } },
			}),
		}),
		row(false, {
			node(T, "bitingRain", "modify", 3, "☂", {
				values = { bitingWave = { 15, 45 }, bitingField = { 10, 30 } },
				modify = {
					skill = "arrowRain",
					bp = {
						firstWave = ref("bitingWave"),
						lingering = { kind = "poison", duration = 4, pct = ref("bitingField") },
					},
				},
			}),
			node(T, "spoils", "passive", 3, "⚡", {
				values = { spoils = { 2, 4 } },
				passive = { hooks = { trapEnergy = "spoils" } },
			}),
		}),
		row(true, {
			node(T, "blastTrap", "modify", 3, "✹", {
				values = { blastDmg = { 50, 150 }, blastPoison = { 35, 100 } },
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
			skill(T, "camouflage"),
			node(T, "ambush", "modify", 3, "◐", {
				values = { ambush = { 0.9, 0.7 } },
				modify = { skill = "camouflage", bp = { mul = { cooldown = ref("ambush") } } },
			}),
		}),
		row(false, { skill(T, "snarefield") }),
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
				values = { basilisk = { 10, 30 } },
				passive = { hooks = { poisonDamage = "basilisk" } },
			}),
			node(T, "woodsman", "passive", 3, "🌲", {
				values = { woodsman = { 4, 12 } },
				passive = { pct = { maxHp = "woodsman" } },
			}),
		}),
		row(false, {
			node(T, "snarefield2", "modify", 2, "☗", {
				values = { deathField = { 60, 120 } },
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
	wiki = false,
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
			skill(S, "agility"),
			node(S, "eye", "passive", 3, "👁", {
				values = { eye = { 60, 180 } },
				passive = { hooks = { minimapEliteBonus = "eye" } },
				dipScale = TEAM_DIP, -- team hook (S57 marker): 1/3 outside the main path
			}),
		}),
		row(false, {
			node(S, "spotting", "passive", 3, "⌾", {
				values = { spotting = { 2, 6 } },
				passive = { hooks = { spotOnHit = "spotting" } },
				dipScale = TEAM_DIP, -- team hook (S57 marker): 1/3 outside the main path
			}),
			node(S, "vigilance", "passive", 3, "⚠", {
				values = { vigilance = { 10, 20 } },
				passive = { hooks = { vigilanceMove = "vigilance" } },
				dipScale = TEAM_DIP, -- team hook (S57 marker): 1/3 outside the main path
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
			skill(S, "falcon"),
			node(S, "talons", "modify", 3, "⋎", {
				values = { talons = { 5, 15 } },
				modify = { skill = "falcon", bp = { values = { dmg = ref("talons") } } },
			}),
		}),
		row(false, {
			node(S, "bond", "passive", 3, "∞", {
				-- bondDive only for the text: falconBond x HOOK_RULES.royalFalcon.bondDive (Skills/Companion)
				values = { bond = { 2, 6 }, bondDive = { 20, 60 } },
				passive = { hooks = { falconBond = "bond" } },
			}),
			node(S, "hardy", "passive", 3, "⛰", {
				values = { hardy = { 3, 9 } },
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
			skill(S, "huntersMark"),
			node(S, "trail", "modify", 3, "⇢", {
				values = { trail = { 10, 20 } },
				modify = { skill = "huntersMark", bp = { markJump = ref("trail") } },
			}),
		}),
		-- the first keystone of the game: the rule lives in Skills/Companion (S77), the numbers in HOOK_RULES.royalFalcon
		row(false, {
			node(S, "royalFalcon", "keystone", 1, "♔", {
				values = { on = { 1, 1 } },
				passive = { hooks = { royalFalcon = "on" } },
			}),
		}),
		row(true, {
			node(S, "quickMark", "modify", 3, "⌛", {
				values = { quickMark = { 0.93, 0.8 } },
				modify = { skill = "huntersMark", bp = { mul = { cooldown = ref("quickMark") } } },
			}),
			node(S, "duet", "passive", 3, "⚭", {
				values = { duet = { 10, 30 } },
				passive = { hooks = { falconDamage = "duet" } },
			}),
		}),
		row(false, {
			skill(S, "drive"),
			node(S, "beater", "modify", 3, "⚑", {
				values = { beater = { 2, 6 } },
				-- one kind each (S75 add.<kind>Duration): the 10B root stays 1 s
				modify = {
					skill = "drive",
					bp = { add = { vulnerabilityDuration = ref("beater"), slowDuration = ref("beater") } },
				},
			}),
		}),
		row(false, {
			node(S, "royalFalcon2", "passive", 2, "♕", {
				values = { sovereignPace = { 10, 20 }, sovereignMark = { 1, 2 } },
				passive = { hooks = { falconInterval = "sovereignPace", spotBonus = "sovereignMark" } },
			}),
		}),
	},
	reference = {},
	wiki = false,
}

-- Model builds (ROZWOJ 7.5, 11.3-11.5; shape in Data/Paths/Types): each spends exactly pointsAt(100) = 50 points.
-- r7Exempt (Trapper, 15.4.2) and notInZone are read by the balance model, never by the game.
local function build(
	id: string,
	main: string,
	stats: { [string]: number },
	nodes: { { any } },
	bp: { [string]: "a" | "b" },
	rotation: { { [string]: any } },
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
	}
end

-- Marksman ------------------------------------------------------------------------------------------------------
local function marksmanNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "marksman_piercingArrow", 1 },
		{ "marksman_steadyHand", 3 },
		{ "scout_agility", 1 },
		{ "scout_eye", 1 },
		{ "trapper_frostTrap", 1 },
		{ "trapper_venom", 2 },
		{ "marksman_rhythm", 3 },
		{ "marksman_precision", 3 },
		{ "scout_spotting", 3 },
		{ row3, 3 },
		{ "marksman_drawBead", 1 },
		{ "marksman_heldBreath", 3 },
		{ "marksman_longShot", 3 },
		{ "marksman_keenSight", 3 },
		{ row6, 3 },
		{ "marksman_stormArrow", 1 },
		{ "marksman_tempest", 3 },
		{ "marksman_heartseeker", 1 },
		{ row9, 3 },
		{ "marksman_grit", 3 },
		{ "marksman_coldBlood", 3 },
		{ "marksman_heartseeker2", 2 },
	}
end

marksman.reference = {
	build(
		"kingslayer",
		"heavycrossbow", -- the balance model also runs it with the path's other weapon (S90)
		marksman.statPlan :: any,
		marksmanNodes("marksman_slayer", "marksman_coupDeGrace", "marksman_deadlyTip"),
		{
			["aimedShot:5"] = "b",
			["drawBead:5"] = "b",
			["drawBead:10"] = "b",
			["stormArrow:5"] = "b",
			["stormArrow:10"] = "b",
		},
		{
			{ skill = "drawBead" },
			{ skill = "heartseeker", notInZone = true },
			{ skill = "stormArrow" },
			{ skill = "aimedShot" },
			{ skill = "venomArrow" },
			{ skill = "piercingArrow" },
			{ skill = "doubleShot" },
			{ skill = "volley" },
			{ skill = "arrowRain" },
		}
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
		},
		{
			{ skill = "drawBead" },
			{ skill = "heartseeker", notInZone = true },
			{ skill = "stormArrow" },
			{ skill = "volley", minEnemies = 3 },
			{ skill = "arrowRain", minEnemies = 3 },
			{ skill = "aimedShot" },
			{ skill = "venomArrow" },
			{ skill = "piercingArrow" },
			{ skill = "doubleShot" },
		}
	),
}

-- Trapper -------------------------------------------------------------------------------------------------------
-- The 8 ranks outside the path (ROZWOJ gives none): rows 1 of the Marksman and the Scout, as in the 11.6 measurement.
local function trapperNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "trapper_frostTrap", 1 },
		{ "trapper_venom", 3 },
		{ "marksman_piercingArrow", 1 },
		{ "marksman_steadyHand", 3 },
		{ "scout_agility", 1 },
		{ "scout_eye", 3 },
		{ "trapper_virulence", 3 },
		{ "trapper_thrift", 3 },
		{ row3, 3 },
		{ "trapper_venomSnare", 1 },
		{ "trapper_huntingGround", 3 },
		{ "trapper_bitingRain", 3 },
		{ "trapper_spoils", 3 },
		{ row6, 3 },
		{ "trapper_camouflage", 1 },
		{ "trapper_ambush", 3 },
		{ "trapper_snarefield", 1 },
		{ row9, 3 },
		{ "trapper_basilisk", 3 },
		{ "trapper_woodsman", 3 },
		{ "trapper_snarefield2", 2 },
	}
end

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
		},
		{
			{ skill = "snarefield", opener = true },
			{ skill = "venomSnare" },
			{ skill = "arrowRain" },
			{ skill = "volley" },
			{ skill = "venomArrow" },
			{ skill = "frostTrap" },
			{ skill = "aimedShot" },
			{ skill = "piercingArrow" },
			{ skill = "doubleShot" },
		},
		true
	),
	build(
		"poisoner",
		"bow",
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
		},
		{
			{ skill = "venomSnare" },
			{ skill = "venomArrow" },
			{ skill = "snarefield" },
			{ skill = "frostTrap" },
			{ skill = "aimedShot" },
			{ skill = "piercingArrow" },
			{ skill = "doubleShot" },
			{ skill = "arrowRain" },
			{ skill = "volley", minEnemies = 3 },
		},
		true
	),
}

-- Scout ---------------------------------------------------------------------------------------------------------
local function scoutNodes(row3: string, row6: string, row9: string): { { any } }
	return {
		{ "scout_agility", 1 },
		{ "scout_eye", 3 },
		{ "marksman_piercingArrow", 1 },
		{ "marksman_steadyHand", 3 },
		{ "scout_spotting", 3 },
		{ "scout_vigilance", 3 },
		{ "marksman_rhythm", 3 },
		{ "marksman_precision", 3 },
		{ row3, 3 },
		{ "scout_falcon", 1 },
		{ "scout_talons", 3 },
		{ "scout_bond", 3 },
		{ "scout_hardy", 3 },
		{ row6, 3 },
		{ "scout_huntersMark", 1 },
		{ "scout_trail", 3 },
		{ "scout_royalFalcon", 1 },
		{ row9, 3 },
		{ "scout_drive", 1 },
		{ "scout_beater", 3 },
		{ "scout_royalFalcon2", 2 },
	}
end

local SCOUT_ROTATION: { { [string]: any } } = {
	{ skill = "huntersMark" },
	{ skill = "falcon", opener = true },
	{ skill = "drive", minEnemies = 3 },
	{ skill = "aimedShot" },
	{ skill = "venomArrow" },
	{ skill = "doubleShot" },
	{ skill = "piercingArrow" },
	{ skill = "arrowRain", minEnemies = 3 },
	{ skill = "volley", minEnemies = 3 },
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
		},
		SCOUT_ROTATION
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
		},
		SCOUT_ROTATION
	),
}

return { marksman, trapper, scout } :: { Types.PathDef }
