--!strict
-- Mage paths (docs/ROZWOJ.md 12): destroyer and arcanist on the twoPathExtra rows (2.2). S140 (DESIGN-18 §6.1, §7): skill
-- nodes only in rows 4 and 8 (SKILL_ROWS); Elementalist and Arcane Mind are 3-rank passive nodes (the old ranks 1 / 3 / 5),
-- Mana Shield, Evocation and Focus moved to the common skills, Wrath of Elements (Rain of Meteors) to the fire pool;
-- their rows got nodes of the same ranks (Elemental Echo, Elemental Surge, Arcane Ward, Quick Discharge); Grit (row 10)
-- and Will (row 5, the Arcanist extra) 3 -> 2 ranks, so one whole direction stays within 50 points (DESIGN-18 §7). A third path (12.6) drops the extra nodes and takes the moved C skills; players get a free node refund.
-- Numbers are the ROZWOJ 12.4 / 12.5 starting values ({ rank 1, rank max }, linear); the balance sessions tune them.
-- Shape: Data/Paths/Warrior (S75) and Hunter (S78). Hooks are the S79 / S80 names (Skills/Context, SkillService,
-- Skills/Elements, StatusEffectService, Logic/Skills.cost). Weapons split strictly as in 12.1 (STATY 3). No Mage node
-- gives a party effect, so none needs dipScale. `reference` and `itemWeights` never reach the wiki; both paths are
-- unpublished there (wiki = false, ROZWOJ 3.5).

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
	assert(def, `Paths/Mage: unknown skill {skillId}`)
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

-- The twoPathExtra node of rows 2, 5 and 10 (last in its row).
local function extra(n: PathNode): PathNode
	local out: any = n
	out.extra = true
	return out :: PathNode
end

local function row(choice: boolean, nodes: { PathNode }): PathRow
	return { choice = choice, nodes = nodes }
end

local function ref(field: string): any
	return { ref = field }
end

local D, A = "destroyer", "arcanist"

local destroyer: Types.PathDef = {
	id = D,
	class = "Mage",
	order = 1,
	role = "damage",
	nameKey = "path.destroyer.name",
	descKey = "path.destroyer.desc",
	titleId = "path_destroyer",
	weapon = { main = { "staff", "wand" }, offhand = { "orb" } },
	statPlan = { int = 4, vit = 1 },
	itemWeights = {
		stats = {
			dotPower = 1.3,
			costReduce = 1.3,
			manaRegen = 1.3,
			maxMana = 1.3,
			skillDmg = 1.15,
			magAtk = 1.15,
			int = 1.15,
			basicDmg = 0.7,
		},
		traits = {
			elementalMight = 1.3,
			powerLens = 1.2,
			elementalSpark = 1,
			learnedFormulae = 0.6,
			runicSeal = 0.3,
		},
	},
	rows = {
		row(false, {
			-- S140: was the skill node of Elementalist (5 ranks bought with skill points); the old ranks 1 / 3 / 5
			node(D, "elementalist", "passive", 3, "✺", {
				values = { bonus = { 3, 15 } },
				passive = { hooks = { elementDamage = "bonus" } },
			}),
			node(D, "sweep", "passive", 3, "◎", {
				values = { sweep = { 2, 6 } },
				passive = { hooks = { areaDamage = "sweep" } },
			}),
		}),
		row(false, {
			node(D, "trace", "passive", 3, "♨", {
				values = { trace = { 0.7, 2 } },
				passive = { hooks = { areaLingering = "trace" } },
			}),
			node(D, "cascade", "passive", 3, "≈", {
				values = { cascade = { 0.5, 1.5 } },
				passive = { hooks = { areaKillMana = "cascade" } },
			}),
			extra(node(D, "wide", "passive", 3, "◯", {
				values = { wide = { 5, 15 } },
				passive = { hooks = { areaRadius = "wide" } },
			})),
		}),
		row(true, {
			node(D, "volatile", "passive", 3, "✹", {
				values = { volatileDmg = { 2, 6 }, volatileCost = { 10, 30 } },
				passive = { hooks = { areaDamage = "volatileDmg", areaCost = "volatileCost" } },
			}),
			node(D, "thrift", "passive", 3, "⌬", {
				values = { thrift = { -4, -12 } },
				passive = { hooks = { areaCost = "thrift" } },
			}),
		}),
		row(false, {
			skill(D, "elementalVortex"),
			node(D, "eye", "modify", 3, "◉", {
				values = { eye = { 1, 3 } },
				modify = { skill = "elementalVortex", bp = { add = { hits = ref("eye") } } },
			}),
		}),
		row(false, {
			node(D, "might", "passive", 3, "✶", {
				values = { might = { 4, 12 } },
				passive = { pct = { magAtk = "might" } },
			}),
			node(D, "veins", "passive", 3, "♆", {
				values = { veins = { 4.4, 13.1 } },
				-- sums with the staff's Elemental Might and the wand's Elemental Spark (STATY 3, S68 nodeHooks)
				passive = { hooks = { elementRider = "veins" } },
			}),
			extra(node(D, "tempered", "passive", 3, "❤", {
				values = { tempered = { 2.3, 6.8 } },
				passive = { pct = { maxHp = "tempered" } },
			})),
		}),
		row(true, {
			node(D, "frail", "passive", 3, "☍", {
				values = { frailDmg = { 2.7, 8 }, frailHp = { -4, -12 } },
				passive = { hooks = { areaDamage = "frailDmg" }, pct = { maxHp = "frailHp" } },
			}),
			node(D, "mantle", "passive", 3, "⛉", {
				values = { mantle = { 4, 12 } },
				passive = { hooks = { vortexGuard = "mantle" } },
			}),
		}),
		row(false, {
			-- S140: Wrath of Elements went to the fire pool; Elemental Echo (one rank, like the skill node) repeats the
			-- Vortex's last wave, and Storm's Wrath shortens the Vortex (cooldown 12 s, so x 0.26 of the 50 s storm's)
			node(D, "echo", "modify", 1, "❉", {
				values = { echo = 100 },
				modify = { skill = "elementalVortex", bp = { echo = { delay = 0.4, pct = ref("echo") } } },
			}),
			node(D, "wrath", "modify", 3, "⚡", {
				values = { wrath = { 0.3, 0.9 } },
				modify = { skill = "elementalVortex", bp = { cdrPerTarget = { sec = ref("wrath"), max = 5 } } },
			}),
		}),
		row(false, { skill(D, "cataclysm") }),
		row(true, {
			node(D, "raging", "modify", 3, "❂", {
				values = { raging = { 0.49, 1.47 } },
				modify = { skill = "elementalVortex", bp = { values = { dmg = ref("raging") } } },
			}),
			node(D, "swift", "modify", 3, "⌛", {
				values = { swift = { 0.935, 0.814 } },
				modify = { skill = "cataclysm", bp = { mul = { cooldown = ref("swift") } } },
			}),
		}),
		row(false, {
			-- S140: Focus is the Mage's common C4; Elemental Surge takes its one rank
			node(D, "surge", "passive", 1, "⇶", {
				values = { surge = 3 },
				passive = { hooks = { areaDamage = "surge" } },
			}),
			node(D, "flow", "passive", 3, "∿", {
				values = { flow = { -1.2, -3.7 } },
				passive = { hooks = { areaCost = "flow" } },
			}),
			extra(node(D, "grit", "passive", 2, "♥", { -- S140: 3 -> 2 ranks (the same top value)
				values = { grit = { 1.4, 4.2 } },
				passive = { pct = { maxHp = "grit" } },
			})),
		}),
		row(false, {
			node(D, "cataclysm2", "modify", 2, "✵", {
				values = { cataclysm2 = { 1, 2 } },
				modify = { skill = "cataclysm", bp = { add = { hits = ref("cataclysm2") } } },
			}),
		}),
	},
	reference = {},
	wiki = false,
}

local arcanist: Types.PathDef = {
	id = A,
	class = "Mage",
	order = 2,
	role = "damage",
	nameKey = "path.arcanist.name",
	descKey = "path.arcanist.desc",
	titleId = "path_arcanist",
	weapon = { main = { "runestaff", "wand" }, offhand = { "tome" } },
	statPlan = { int = 5 },
	itemWeights = {
		stats = {
			critChance = 1.2,
			critDmg = 1.2,
			magicPierce = 1.2,
			skillDmg = 1.2,
			maxMana = 1.2,
			manaRegen = 1.2,
			-- savings do not weaken the Arcanist: its power comes from the charges, whose surcharge costReduce lowers too
			costReduce = 1.2,
			dotPower = 0.8,
			basicDmg = 0.6,
		},
		traits = {
			runicSeal = 1.3,
			learnedFormulae = 1.3,
			elementalSpark = 1,
			powerLens = 0.6,
			elementalMight = 0.3,
		},
	},
	rows = {
		row(false, {
			-- S140: Mana Shield is the Mage's common C2; Arcane Ward takes its one rank (no mana or damage change, so the
			-- 1-20 numbers and T-SK4 of the Arcanist stay)
			node(A, "ward", "passive", 1, "⛨", {
				values = { ward = 3 },
				passive = { pct = { maxHp = "ward" } },
			}),
			node(A, "precision", "passive", 3, "⌖", {
				values = { precision = { 1, 3 } },
				passive = { hooks = { singleDamage = "precision" } },
			}),
		}),
		row(false, {
			node(A, "reserve", "passive", 3, "◍", {
				values = { reserve = { 4, 12 } },
				passive = { pct = { manaReserve = "reserve" } },
			}),
			node(A, "acuity", "passive", 3, "◇", {
				values = { acuity = { 1, 3 } },
				passive = { flat = { critChance = "acuity" } },
			}),
			extra(node(A, "composure", "passive", 3, "☯", {
				values = { composure = { -10, -30 } },
				passive = { hooks = { manaShieldCost = "composure" } },
			})),
		}),
		row(true, {
			node(A, "resonance", "passive", 3, "♒", {
				values = { resonance = { 2, 6 } },
				passive = { hooks = { resonance = "resonance" } },
			}),
			node(A, "overload", "passive", 3, "⚠", {
				values = { overloadDmg = { 2, 6 }, overloadCost = { 9, 27 } }, -- S91: cost 10-30 -> 9-27 (list S90, T-SK4 2.6-2.8)
				passive = { hooks = { spellDamage = "overloadDmg", spellCost = "overloadCost" } },
			}),
		}),
		row(false, {
			skill(A, "arcaneDischarge"),
			node(A, "fullDischarge", "modify", 3, "✷", {
				values = { fullDischarge = { 3, 9.9 } },
				modify = { skill = "arcaneDischarge", bp = { values = { perCharge = ref("fullDischarge") } } },
			}),
		}),
		row(false, {
			node(A, "might", "passive", 3, "✶", {
				values = { might = { 0.3, 1 } },
				passive = { pct = { magAtk = "might" } },
			}),
			node(A, "reclaim", "passive", 3, "↺", {
				values = { reclaim = { 0.035, 0.105 } },
				passive = { hooks = { chargeReclaim = "reclaim" } },
			}),
			extra(node(A, "will", "passive", 2, "♥", { -- S140: 3 -> 2 ranks (the same top value)
				values = { will = { 4, 12 } },
				passive = { pct = { maxHp = "will" } },
			})),
		}),
		row(true, {
			node(A, "mounting", "passive", 3, "⇈", {
				values = { mounting = { 0.17, 0.52 } },
				passive = { hooks = { chargeDamage = "mounting" } },
			}),
			node(A, "coolHead", "passive", 3, "❄", {
				values = { coolHead = { -1.15, -3.44 } },
				passive = { hooks = { chargeCost = "coolHead" } },
			}),
		}),
		row(false, {
			-- S140: Evocation is the Mage's common C3; Quick Discharge takes its one rank
			node(A, "quickening", "modify", 1, "✷", {
				values = { quickening = 0.85 },
				modify = { skill = "arcaneDischarge", bp = { mul = { cooldown = ref("quickening") } } },
			}),
			node(A, "invocation", "modify", 3, "☼", {
				values = { invocation = { 3.9, 11.7 } },
				-- S80: the effect "empowered" after a full channel (SkillService.closeChannel)
				modify = { skill = "evocation", bp = { empower = { pct = ref("invocation"), uses = 3 } } },
			}),
		}),
		row(false, { skill(A, "arcaneTorrent") }),
		row(true, {
			node(A, "rending", "modify", 3, "⟿", {
				values = { rending = { 0.84, 2.53 } },
				modify = { skill = "arcaneTorrent", bp = { values = { growth = ref("rending") } } },
			}),
			node(A, "well", "modify", 3, "◒", {
				values = { well = { -0.12, -0.37 } },
				modify = { skill = "arcaneTorrent", bp = { values = { drain = ref("well") } } },
			}),
		}),
		row(false, {
			-- S140: was the skill node of Arcane Mind (5 ranks bought with skill points); the old ranks 1 / 3 / 5
			node(A, "arcaneMind", "passive", 3, "✦", {
				values = { crit = { 0.35, 1.05 }, critDmg = { 1, 2.8 } }, -- S81 (ROZWOJ 12.5, 15.5.4)
				passive = { flat = { critChance = "crit", critDmg = "critDmg" } },
			}),
			node(A, "masterMind", "passive", 3, "♕", {
				values = { masterMind = { 5.6, 16.9 } },
				passive = { hooks = { channelGuard = "masterMind" } },
			}),
			extra(node(A, "archmage", "modify", 3, "⌚", {
				values = { archmage = { -0.44, -1.31 } },
				-- a shorter channel, the same mana (restored at the end of the channel)
				modify = { skill = "evocation", bp = { add = { duration = ref("archmage") } } },
			})),
		}),
		row(false, {
			node(A, "torrent2", "modify", 2, "≋", {
				values = { torrent2 = { 0.5, 1 } },
				modify = { skill = "arcaneTorrent", bp = { add = { duration = ref("torrent2") } } },
			}),
		}),
	},
	reference = {},
	wiki = false,
}

-- Model builds (ROZWOJ 7.5, 12.4, 12.5, 12.7; shape in Data/Paths/Types): each spends exactly pointsAt(100) = 50
-- points, the nodes in the priority order of the class design. areaCap (15.5.3) is read by the balance model only.
-- S140 (DESIGN-18 §6.1, §13): `element` = the weapon element of a variant measured in that pool alone (the fire
-- variants with `ranks`, the order the model buys skill ranks in); without it the model averages the three elements.
local function build(
	id: string,
	main: string,
	stats: { [string]: number },
	nodes: { { any } },
	bp: { [string]: "a" | "b" },
	rotation: { { [string]: any } },
	areaCap: number?,
	element: string?,
	ranks: { string }?,
	bar: { string }?
): Types.ReferenceBuild
	return {
		id = id,
		bar = bar,
		areaCap = areaCap,
		weapon = { main = main, element = element },
		nodes = nodes,
		bp = bp,
		stats = stats,
		rotation = rotation,
		ranks = ranks,
	}
end

-- Destroyer -----------------------------------------------------------------------------------------------------
-- S140: the moved skill nodes replaced by Elemental Echo and Elemental Surge; Elementalist's two more ranks after row 3
-- (rank 1 at 10 as before): the points of 10-14 go to the Arcanist's row 1 (Arcane Ward, Precision 2) first, as the
-- old Mana Shield node took the one of 10 (a direction with an open row 1 spends there otherwise); Grit 3 -> 2 (its new
-- maximum), no Tempered (50 points).
local function destroyerNodes(row3: string, row6: string): { { any } }
	return {
		{ "destroyer_elementalist", 1 },
		{ "destroyer_sweep", 3 },
		{ "arcanist_ward", 1 },
		{ "arcanist_precision", 2 },
		{ "destroyer_trace", 3 },
		{ row3, 3 },
		{ "destroyer_elementalist", 2 },
		{ "destroyer_elementalVortex", 1 },
		{ "destroyer_eye", 3 },
		{ "destroyer_might", 3 },
		{ row6, 3 },
		{ "destroyer_echo", 1 },
		{ "destroyer_wrath", 3 },
		{ "destroyer_cataclysm", 1 },
		{ "destroyer_cascade", 3 },
		{ "destroyer_raging", 3 },
		{ "destroyer_surge", 1 },
		{ "destroyer_flow", 3 },
		{ "destroyer_cataclysm2", 2 },
		{ "destroyer_grit", 2 },
		{ "destroyer_wide", 3 },
		{ "destroyer_veins", 3 },
	}
end

-- The base breakpoints both boss builds take (ROZWOJ 12.2: B is single target and damage).
local BASE_BOSS_BP: { [string]: "a" | "b" } = {
	["firebolt:5"] = "b",
	["firebolt:10"] = "b",
	["fireball:10"] = "b",
	["meteor:5"] = "b",
	["iceShard:5"] = "b",
	["iceShard:10"] = "b",
	["chainLightning:5"] = "b",
	["chainLightning:10"] = "b",
	["firewall:5"] = "b",
	["firewall:10"] = "b",
	["frostNova:10"] = "b",
}

local function withBase(extraBp: { [string]: any }): { [string]: "a" | "b" }
	local out: { [string]: any } = table.clone(BASE_BOSS_BP)
	for key, option in extraBp do
		out[key] = option
	end
	return out
end

-- S140: the fire pool of the area variant: A options (area and burn), Rain of Meteors' 10B
local FIRE_AREA_BP: { [string]: "a" | "b" } = {
	["flameWave:5"] = "a",
	["flameWave:10"] = "a",
	["pyroblast:5"] = "a",
	["pyroblast:10"] = "a",
	["combustion:5"] = "b",
	["combustion:10"] = "b",
	["immolate:5"] = "a",
	["immolate:10"] = "b",
	["meteorStorm:10"] = "b",
}
-- S140: the fire pool of the single-target variant: B options
local FIRE_SINGLE_BP: { [string]: "a" | "b" } = {
	["flameWave:5"] = "b",
	["flameWave:10"] = "b",
	["pyroblast:5"] = "b",
	["pyroblast:10"] = "b",
	["combustion:5"] = "b",
	["combustion:10"] = "b",
	["immolate:5"] = "b",
	["immolate:10"] = "b",
}

-- S141: the ice pool of the area variant: B (damage) options but Frozen Orb's and Glacial Spike's 5A (radius, splash),
-- Deep Freeze's 10A (more freezes) and Blizzard's 5A (one more wave)
local ICE_AREA_BP: { [string]: "a" | "b" } = {
	["hailstorm:5"] = "b",
	["hailstorm:10"] = "b",
	["glacialSpike:5"] = "a",
	["glacialSpike:10"] = "b",
	["frozenOrb:5"] = "a",
	["frozenOrb:10"] = "b",
	["deepFreeze:5"] = "b",
	["deepFreeze:10"] = "a",
	["shatter:5"] = "a",
	["shatter:10"] = "b",
	["blizzard:5"] = "a",
	["blizzard:10"] = "b",
}
-- S141: the ice pool of the single-target variant: B options
local ICE_SINGLE_BP: { [string]: "a" | "b" } = {
	["hailstorm:5"] = "b",
	["hailstorm:10"] = "b",
	["glacialSpike:5"] = "b",
	["glacialSpike:10"] = "b",
	["frozenOrb:5"] = "b",
	["frozenOrb:10"] = "b",
	["deepFreeze:5"] = "b",
	["deepFreeze:10"] = "b",
	["shatter:5"] = "b",
	["shatter:10"] = "b",
	["blizzard:5"] = "b",
	["blizzard:10"] = "b",
}

-- S142: the lightning pool of the area variant: A options of the area skills (jumps, bolts, radius, splash, width), B
-- of the rest
local LIGHTNING_AREA_BP: { [string]: "a" | "b" } = {
	["lightningBolt:5"] = "b",
	["lightningBolt:10"] = "b",
	["chainLightning:5"] = "a",
	["chainLightning:10"] = "b",
	["staticShock:5"] = "b",
	["staticShock:10"] = "b",
	["thunderStrike:5"] = "a",
	["thunderStrike:10"] = "b",
	["firewall:5"] = "a",
	["firewall:10"] = "b",
	["ballLightning:5"] = "a",
	["ballLightning:10"] = "b",
	["lightningLance:5"] = "b",
	["lightningLance:10"] = "b",
	["tempest:5"] = "a",
	["tempest:10"] = "b",
}
-- S142: the lightning pool of the single-target variant: B options
local LIGHTNING_SINGLE_BP: { [string]: "a" | "b" } = {
	["lightningBolt:5"] = "b",
	["lightningBolt:10"] = "b",
	["staticShock:5"] = "b",
	["staticShock:10"] = "b",
	["thunderStrike:5"] = "b",
	["thunderStrike:10"] = "b",
	["ballLightning:5"] = "b",
	["ballLightning:10"] = "b",
	["lightningLance:5"] = "b",
	["lightningLance:10"] = "b",
	["tempest:5"] = "b",
	["tempest:10"] = "b",
}

local function merged(a: { [string]: any }, b: { [string]: any }): { [string]: "a" | "b" }
	local out: { [string]: any } = table.clone(a)
	for key, option in b do
		out[key] = option
	end
	return out
end

-- S140: the skill ranks of the fire variants, bought in this order (DESIGN-18 §13): the rotation's core first, the
-- passives at their unlock, utility last (the model never casts Blink, Ember Shield or Mana Shield)
local FIRE_AREA_RANKS = {
	"fireball",
	"firebolt",
	"flameWave",
	"pyroblast",
	"kindling",
	"meteor",
	"elementalVortex",
	"combustion",
	"immolate",
	"focus",
	"phoenixHeart",
	"meteorStorm",
	"cataclysm",
	"evocation",
	"blink",
	"emberShield",
	"manaShield",
}
local FIRE_SINGLE_RANKS = {
	"firebolt",
	"fireball",
	"pyroblast",
	"flameWave",
	"kindling",
	"meteor",
	"arcaneDischarge",
	"immolate",
	"combustion",
	"focus",
	"phoenixHeart",
	"arcaneTorrent",
	"meteorStorm",
	"evocation",
	"blink",
	"emberShield",
	"manaShield",
}

-- S141: the skill ranks of the ice variants (the same rule as the fire ones)
local ICE_AREA_RANKS = {
	"hailstorm",
	"iceShard",
	"frostNova",
	"glacialSpike",
	"wintersGrip",
	"frozenOrb",
	"elementalVortex",
	"deepFreeze",
	"shatter",
	"focus",
	"iceBlood",
	"blizzard",
	"cataclysm",
	"evocation",
	"blink",
	"iceBarrier",
	"manaShield",
}
local ICE_SINGLE_RANKS = {
	"iceShard",
	"glacialSpike",
	"hailstorm",
	"frostNova",
	"wintersGrip",
	"arcaneDischarge",
	"deepFreeze",
	"shatter",
	"focus",
	"frozenOrb",
	"iceBlood",
	"arcaneTorrent",
	"blizzard",
	"evocation",
	"blink",
	"iceBarrier",
	"manaShield",
}

-- S142: the skill ranks of the lightning variants (the same rule as the fire and ice ones)
local LIGHTNING_AREA_RANKS = {
	"chainLightning",
	"lightningBolt",
	"staticShock",
	"thunderStrike",
	"overcharge",
	"firewall",
	"elementalVortex",
	"ballLightning",
	"lightningLance",
	"focus",
	"conductor",
	"tempest",
	"cataclysm",
	"evocation",
	"blink",
	"stormArmor",
	"manaShield",
}
local LIGHTNING_SINGLE_RANKS = {
	"lightningBolt",
	"thunderStrike",
	"chainLightning",
	"staticShock",
	"overcharge",
	"arcaneDischarge",
	"firewall",
	"lightningLance",
	"focus",
	"conductor",
	"ballLightning",
	"arcaneTorrent",
	"tempest",
	"evocation",
	"blink",
	"stormArmor",
	"manaShield",
}

-- S147 (DESIGN-18 §4.1, §13): the 8 slots of the bar of the element variants in priority (the first ones the character
-- can cast at a level); the mean builds of three elements cast at most 8 actives of one pool anyway
local FIRE_AREA_BAR = {
	"meteorStorm",
	"cataclysm",
	"elementalVortex",
	"meteor",
	"flameWave",
	"combustion",
	"fireball",
	"pyroblast",
	"immolate",
	"firebolt",
}
local FIRE_SINGLE_BAR = {
	"arcaneTorrent",
	"arcaneDischarge",
	"pyroblast",
	"immolate",
	"combustion",
	"meteor",
	"fireball",
	"firebolt",
	"evocation",
}
local ICE_AREA_BAR = {
	"blizzard",
	"cataclysm",
	"elementalVortex",
	"frozenOrb",
	"hailstorm",
	"frostNova",
	"glacialSpike",
	"deepFreeze",
	"shatter",
	"iceShard",
}
local ICE_SINGLE_BAR = {
	"arcaneTorrent",
	"arcaneDischarge",
	"deepFreeze",
	"glacialSpike",
	"shatter",
	"frostNova",
	"iceShard",
	"frozenOrb",
	"hailstorm",
	"evocation",
}
local LIGHTNING_AREA_BAR = {
	"tempest",
	"cataclysm",
	"elementalVortex",
	"firewall",
	"ballLightning",
	"chainLightning",
	"thunderStrike",
	"lightningLance",
	"staticShock",
	"lightningBolt",
}
local LIGHTNING_SINGLE_BAR = {
	"arcaneTorrent",
	"arcaneDischarge",
	"thunderStrike",
	"lightningLance",
	"staticShock",
	"firewall",
	"chainLightning",
	"lightningBolt",
	"evocation",
}

destroyer.reference = {
	build(
		"destroyerExp",
		"staff", -- the balance model averages the three elements (ROZWOJ 12.7)
		destroyer.statPlan :: any,
		destroyerNodes("destroyer_volatile", "destroyer_mantle"),
		{ ["firewall:10"] = "b", ["meteorStorm:10"] = "b" },
		{
			{ skill = "elementalVortex", minEnemies = 2 },
			{ skill = "cataclysm" },
			{ skill = "meteorStorm" },
			{ skill = "meteor" },
			{ skill = "frostNova", minEnemies = 2 },
			{ skill = "firewall" },
			{ skill = "fireball" },
			{ skill = "chainLightning" },
			{ skill = "iceShard" },
			{ skill = "lightningBolt" }, -- S142: the lightning pool's S1 (Fire Bolt is fire only)
			{ skill = "firebolt" },
		},
		3.0
	),
	build(
		"destroyerBoss",
		"staff",
		destroyer.statPlan :: any,
		destroyerNodes("destroyer_thrift", "destroyer_frail"),
		withBase({
			["meteorStorm:5"] = "b",
			["meteorStorm:10"] = "b",
			["elementalVortex:5"] = "b",
			["cataclysm:5"] = "b",
			["cataclysm:10"] = "b",
		}),
		-- ROZWOJ gives no boss rotation: every damaging spell on cooldown, the strongest first
		{
			{ skill = "cataclysm" },
			{ skill = "meteorStorm" },
			{ skill = "meteor" },
			{ skill = "firewall" },
			{ skill = "frostNova" },
			{ skill = "elementalVortex" },
			{ skill = "fireball" },
			{ skill = "chainLightning" },
			-- S142: the S2 and K1 of every pool (every damaging spell on cooldown, the strongest first)
			{ skill = "thunderStrike" },
			{ skill = "pyroblast" },
			{ skill = "glacialSpike" },
			{ skill = "staticShock" },
			{ skill = "flameWave" },
			{ skill = "iceShard" },
			{ skill = "lightningBolt" },
			{ skill = "firebolt" },
		},
		3.0
	),
	-- S140: the Destroyer with a fire weapon (the fire pool alone): area first, burns stacked for Combustion
	build(
		"destroyerFire",
		"staff",
		destroyer.statPlan :: any,
		destroyerNodes("destroyer_volatile", "destroyer_mantle"),
		FIRE_AREA_BP,
		{
			{ skill = "elementalVortex", minEnemies = 2 },
			{ skill = "cataclysm" },
			{ skill = "meteorStorm" },
			{ skill = "meteor" },
			{ skill = "flameWave" },
			{ skill = "combustion" },
			{ skill = "fireball" },
			{ skill = "pyroblast" },
			{ skill = "immolate" },
			{ skill = "firebolt" },
		},
		3.0,
		"fire",
		FIRE_AREA_RANKS,
		FIRE_AREA_BAR
	),
	-- S141: the Destroyer with an ice weapon (the ice pool alone): area and slows first, freezes for Shatter
	build(
		"destroyerIce",
		"staff",
		destroyer.statPlan :: any,
		destroyerNodes("destroyer_volatile", "destroyer_mantle"),
		merged(withBase({}), ICE_AREA_BP),
		{
			{ skill = "elementalVortex", minEnemies = 2 },
			{ skill = "cataclysm" },
			{ skill = "blizzard" },
			{ skill = "frozenOrb" },
			{ skill = "hailstorm" },
			{ skill = "frostNova", minEnemies = 2 },
			{ skill = "deepFreeze" },
			{ skill = "glacialSpike" },
			{ skill = "shatter" },
			{ skill = "iceShard" },
		},
		3.0,
		"ice",
		ICE_AREA_RANKS,
		ICE_AREA_BAR
	),
	-- S142: the Destroyer with a lightning weapon (the lightning pool alone): area first, jumps and bolts
	build(
		"destroyerLightning",
		"staff",
		destroyer.statPlan :: any,
		destroyerNodes("destroyer_volatile", "destroyer_mantle"),
		merged(withBase({}), LIGHTNING_AREA_BP),
		{
			{ skill = "elementalVortex", minEnemies = 2 },
			{ skill = "cataclysm" },
			{ skill = "tempest" },
			{ skill = "firewall" },
			{ skill = "ballLightning" },
			{ skill = "chainLightning" },
			{ skill = "thunderStrike" },
			{ skill = "lightningLance" },
			{ skill = "staticShock" },
			{ skill = "lightningBolt" },
		},
		3.0,
		"lightning",
		LIGHTNING_AREA_RANKS,
		LIGHTNING_AREA_BAR
	),
}

-- Arcanist ------------------------------------------------------------------------------------------------------
-- S140: Arcane Ward and Quick Discharge for the moved skill nodes, Arcane Mind's two more ranks (will 3 -> 1).
local function arcanistNodes(row3: string): { { any } }
	return {
		{ "arcanist_ward", 1 },
		{ "arcanist_precision", 3 },
		{ "destroyer_elementalist", 1 },
		{ "arcanist_reserve", 3 },
		{ row3, 3 },
		{ "arcanist_arcaneDischarge", 1 },
		{ "arcanist_fullDischarge", 3 },
		{ "arcanist_might", 3 },
		{ "arcanist_mounting", 3 },
		{ "arcanist_quickening", 1 },
		{ "arcanist_invocation", 3 },
		{ "arcanist_arcaneTorrent", 1 },
		{ "arcanist_rending", 3 },
		{ "arcanist_arcaneMind", 3 },
		{ "arcanist_archmage", 3 },
		{ "arcanist_masterMind", 3 },
		{ "arcanist_torrent2", 2 },
		{ "arcanist_reclaim", 3 },
		{ "arcanist_acuity", 3 },
		{ "arcanist_will", 1 },
		{ "arcanist_composure", 3 },
	}
end

local ARCANIST_ROTATION: { { [string]: any } } = {
	{ skill = "evocation", maxManaPct = 35 },
	{ skill = "arcaneDischarge", minCharges = 4 },
	{ skill = "arcaneTorrent", minManaPct = 90 }, -- "at full mana", with room for regeneration
	{ skill = "meteor" },
	{ skill = "fireball" },
	{ skill = "firewall" },
	{ skill = "frostNova" },
	{ skill = "chainLightning" },
	{ skill = "iceShard" },
	{ skill = "lightningBolt" }, -- S142
	{ skill = "firebolt" },
}

arcanist.reference = {
	build(
		"arcanistBoss",
		"runestaff",
		arcanist.statPlan :: any,
		arcanistNodes("arcanist_resonance"),
		withBase({}),
		ARCANIST_ROTATION
	),
	build(
		"arcanistOverload",
		"runestaff",
		arcanist.statPlan :: any,
		arcanistNodes("arcanist_overload"),
		withBase({}),
		ARCANIST_ROTATION
	),
	-- S140: the Arcanist with a fire weapon: one target at range (no Flame Wave), Pyroblast and Immolate on stacked burns
	build(
		"arcanistFire",
		"runestaff",
		arcanist.statPlan :: any,
		arcanistNodes("arcanist_resonance"),
		merged(withBase({}), FIRE_SINGLE_BP),
		{
			{ skill = "evocation", maxManaPct = 35 },
			{ skill = "arcaneDischarge", minCharges = 4 },
			{ skill = "arcaneTorrent", minManaPct = 90 },
			{ skill = "pyroblast" },
			{ skill = "immolate" },
			{ skill = "combustion" },
			{ skill = "meteor" },
			{ skill = "fireball" },
			{ skill = "firebolt" },
		},
		nil,
		"fire",
		FIRE_SINGLE_RANKS,
		FIRE_SINGLE_BAR
	),
	-- S141: the Arcanist with an ice weapon: one target, Deep Freeze then Glacial Spike and Shatter on the frozen target
	build(
		"arcanistIce",
		"runestaff",
		arcanist.statPlan :: any,
		arcanistNodes("arcanist_resonance"),
		merged(withBase({}), ICE_SINGLE_BP),
		{
			{ skill = "evocation", maxManaPct = 35 },
			{ skill = "arcaneDischarge", minCharges = 4 },
			{ skill = "arcaneTorrent", minManaPct = 90 },
			{ skill = "deepFreeze" },
			{ skill = "glacialSpike" },
			{ skill = "shatter" },
			{ skill = "frostNova" },
			{ skill = "frozenOrb" },
			{ skill = "hailstorm" },
			{ skill = "iceShard" },
		},
		nil,
		"ice",
		ICE_SINGLE_RANKS,
		ICE_SINGLE_BAR
	),
	-- S142: the Arcanist with a lightning weapon: one target, Thunder Strike and the sure crit of the Lance
	build(
		"arcanistLightning",
		"runestaff",
		arcanist.statPlan :: any,
		arcanistNodes("arcanist_resonance"),
		merged(withBase({}), LIGHTNING_SINGLE_BP),
		{
			{ skill = "evocation", maxManaPct = 35 },
			{ skill = "arcaneDischarge", minCharges = 4 },
			{ skill = "arcaneTorrent", minManaPct = 90 },
			{ skill = "thunderStrike" },
			{ skill = "lightningLance" },
			{ skill = "staticShock" },
			{ skill = "firewall" },
			{ skill = "chainLightning" },
			{ skill = "lightningBolt" },
		},
		nil,
		"lightning",
		LIGHTNING_SINGLE_RANKS,
		LIGHTNING_SINGLE_BAR
	),
}

return { destroyer, arcanist } :: { Types.PathDef }
