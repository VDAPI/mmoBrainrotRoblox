--!strict
-- Mage paths (docs/ROZWOJ.md 12): destroyer and arcanist on the twoPathExtra rows (2.2). A third path (12.6) drops the extra nodes and takes the moved C skills; players get a free node refund.
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
			skill(D, "elementalist"),
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
				values = { might = { 2, 6 } },
				passive = { pct = { magAtk = "might" } },
			}),
			node(D, "veins", "passive", 3, "♆", {
				values = { veins = { 10, 30 } },
				-- sums with the staff's Elemental Might and the wand's Elemental Spark (STATY 3, S68 nodeHooks)
				passive = { hooks = { elementRider = "veins" } },
			}),
			extra(node(D, "tempered", "passive", 3, "❤", {
				values = { tempered = { 4, 12 } },
				passive = { pct = { maxHp = "tempered" } },
			})),
		}),
		row(true, {
			node(D, "frail", "passive", 3, "☍", {
				values = { frailDmg = { 2, 6 }, frailHp = { -4, -12 } },
				passive = { hooks = { areaDamage = "frailDmg" }, pct = { maxHp = "frailHp" } },
			}),
			node(D, "mantle", "passive", 3, "⛉", {
				values = { mantle = { 4, 12 } },
				passive = { hooks = { vortexGuard = "mantle" } },
			}),
		}),
		row(false, {
			skill(D, "meteorStorm"),
			node(D, "wrath", "modify", 3, "⚡", {
				values = { wrath = { 1, 3 } },
				modify = { skill = "meteorStorm", bp = { cdrPerTarget = { sec = ref("wrath"), max = 5 } } },
			}),
		}),
		row(false, { skill(D, "cataclysm") }),
		row(true, {
			node(D, "raging", "modify", 3, "❂", {
				values = { raging = { 0.5, 1.5 } },
				modify = { skill = "elementalVortex", bp = { values = { dmg = ref("raging") } } },
			}),
			node(D, "swift", "modify", 3, "⌛", {
				values = { swift = { 0.93, 0.8 } },
				modify = { skill = "cataclysm", bp = { mul = { cooldown = ref("swift") } } },
			}),
		}),
		row(false, {
			skill(D, "focus"),
			node(D, "flow", "passive", 3, "∿", {
				values = { flow = { -3, -9 } },
				passive = { hooks = { areaCost = "flow" } },
			}),
			extra(node(D, "grit", "passive", 3, "♥", {
				values = { grit = { 4, 12 } },
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
			skill(A, "manaShield"),
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
				values = { overloadDmg = { 2, 6 }, overloadCost = { 10, 30 } },
				passive = { hooks = { spellDamage = "overloadDmg", spellCost = "overloadCost" } },
			}),
		}),
		row(false, {
			skill(A, "arcaneDischarge"),
			node(A, "fullDischarge", "modify", 3, "✷", {
				values = { fullDischarge = { 3, 10 } },
				modify = { skill = "arcaneDischarge", bp = { values = { perCharge = ref("fullDischarge") } } },
			}),
		}),
		row(false, {
			node(A, "might", "passive", 3, "✶", {
				values = { might = { 1, 3 } },
				passive = { pct = { magAtk = "might" } },
			}),
			node(A, "reclaim", "passive", 3, "↺", {
				values = { reclaim = { 0.1, 0.3 } },
				passive = { hooks = { chargeReclaim = "reclaim" } },
			}),
			extra(node(A, "will", "passive", 3, "♥", {
				values = { will = { 4, 12 } },
				passive = { pct = { maxHp = "will" } },
			})),
		}),
		row(true, {
			node(A, "mounting", "passive", 3, "⇈", {
				values = { mounting = { 0.5, 1.5 } },
				passive = { hooks = { chargeDamage = "mounting" } },
			}),
			node(A, "coolHead", "passive", 3, "❄", {
				values = { coolHead = { -4, -12 } },
				passive = { hooks = { chargeCost = "coolHead" } },
			}),
		}),
		row(false, {
			skill(A, "evocation"),
			node(A, "invocation", "modify", 3, "☼", {
				values = { invocation = { 5, 15 } },
				-- S80: the effect "empowered" after a full channel (SkillService.closeChannel)
				modify = { skill = "evocation", bp = { empower = { pct = ref("invocation"), uses = 3 } } },
			}),
		}),
		row(false, { skill(A, "arcaneTorrent") }),
		row(true, {
			node(A, "rending", "modify", 3, "⟿", {
				values = { rending = { 0.5, 1.5 } },
				modify = { skill = "arcaneTorrent", bp = { values = { growth = ref("rending") } } },
			}),
			node(A, "well", "modify", 3, "◒", {
				values = { well = { -0.25, -0.75 } },
				modify = { skill = "arcaneTorrent", bp = { values = { drain = ref("well") } } },
			}),
		}),
		row(false, {
			skill(A, "arcaneMind"),
			node(A, "masterMind", "passive", 3, "♕", {
				values = { masterMind = { 4, 12 } },
				passive = { hooks = { channelGuard = "masterMind" } },
			}),
			extra(node(A, "archmage", "modify", 3, "⌚", {
				values = { archmage = { -0.5, -1.5 } },
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
local function build(
	id: string,
	main: string,
	stats: { [string]: number },
	nodes: { { any } },
	bp: { [string]: "a" | "b" },
	rotation: { { [string]: any } },
	areaCap: number?
): Types.ReferenceBuild
	return {
		id = id,
		areaCap = areaCap,
		weapon = { main = main },
		nodes = nodes,
		bp = bp,
		stats = stats,
		rotation = rotation,
	}
end

-- Destroyer -----------------------------------------------------------------------------------------------------
local function destroyerNodes(row3: string, row6: string): { { any } }
	return {
		{ "destroyer_elementalist", 1 },
		{ "destroyer_sweep", 3 },
		{ "destroyer_trace", 3 },
		{ row3, 3 },
		{ "destroyer_elementalVortex", 1 },
		{ "destroyer_eye", 3 },
		{ "destroyer_might", 3 },
		{ row6, 3 },
		{ "destroyer_meteorStorm", 1 },
		{ "destroyer_wrath", 3 },
		{ "destroyer_cataclysm", 1 },
		{ "destroyer_cascade", 3 },
		{ "destroyer_raging", 3 },
		{ "destroyer_focus", 1 },
		{ "destroyer_flow", 3 },
		{ "destroyer_cataclysm2", 2 },
		{ "destroyer_grit", 3 },
		{ "destroyer_wide", 3 },
		{ "destroyer_tempered", 3 },
		{ "destroyer_veins", 3 },
		{ "arcanist_manaShield", 1 },
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
			{ skill = "iceShard" },
			{ skill = "firebolt" },
		},
		3.0
	),
}

-- Arcanist ------------------------------------------------------------------------------------------------------
local function arcanistNodes(row3: string): { { any } }
	return {
		{ "arcanist_manaShield", 1 },
		{ "arcanist_precision", 3 },
		{ "destroyer_elementalist", 1 },
		{ "arcanist_reserve", 3 },
		{ row3, 3 },
		{ "arcanist_arcaneDischarge", 1 },
		{ "arcanist_fullDischarge", 3 },
		{ "arcanist_might", 3 },
		{ "arcanist_mounting", 3 },
		{ "arcanist_evocation", 1 },
		{ "arcanist_invocation", 3 },
		{ "arcanist_arcaneTorrent", 1 },
		{ "arcanist_rending", 3 },
		{ "arcanist_arcaneMind", 1 },
		{ "arcanist_archmage", 3 },
		{ "arcanist_masterMind", 3 },
		{ "arcanist_torrent2", 2 },
		{ "arcanist_reclaim", 3 },
		{ "arcanist_acuity", 3 },
		{ "arcanist_will", 3 },
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
}

return { destroyer, arcanist } :: { Types.PathDef }
