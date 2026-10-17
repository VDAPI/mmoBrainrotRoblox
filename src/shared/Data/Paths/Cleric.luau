--!strict
-- Cleric paths (docs/ROZWOJ.md 9.1, 9.3-9.5; S71): Healer, Priest of Fortune, Inquisitor. Numbers are the ROZWOJ 9
-- starting values ({ rank 1, rank max }, linear); the balance sessions tune them. Shape: tests/fixtures/paths.luau.
-- Node numbers follow B3 (Logic/Paths): rank-dependent numbers sit in `values`, passive / luck name the field, in
-- modify.bp a number is { ref = "<field>" }. Behaviour numbers (shieldBurst, stunSplash, misfortune) go through the
-- skill's values (read with ctx.value), the behaviour key keeps only its fixed radius.
-- `reference` and `itemWeights` never reach the wiki; every path is unpublished there (wiki = false, ROZWOJ 3.5).

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
	assert(def, `Paths/Cleric: unknown skill {skillId}`)
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

-- Evil Eye / Ill Omen: Holy Strike lays Misfortune for 6 s with the value of values.misfortune (S61 shape).
local function misfortune(): any
	return { kind = "misfortune", target = "enemy", duration = 6, value = "misfortune", category = "enemyMiss" }
end

local H, F, I = "healer", "fortune", "inquisitor"
-- S138 (DESIGN-18 §7): the relic the Fortune's luck nodes past row 2 need (directions have no weapon of their own)
local RELIC: Types.WeaponReq = { offhand = { "relic" } }

local healer: Types.PathDef = {
	id = H,
	class = "Cleric",
	order = 1,
	role = "healer",
	nameKey = "path.healer.name",
	descKey = "path.healer.desc",
	titleId = "path_healer",
	weapon = { main = { "scepter", "holystaff" } },
	statPlan = { int = 1, vit = 1 },
	itemWeights = {
		axes = { support = 1.5, dmg = 0.7 },
		stats = { healPower = 1.5, manaRegen = 1.3, maxMana = 1.2, costReduce = 1.2, vit = 1.2, maxHp = 1.2 },
		traits = { anointment = 1.3, savingBlow = 1.3, prosperity = 0.5 },
	},
	rows = {
		row(false, {
			skill(H, "renew"),
			node(H, "blessedHands", "passive", 3, "✙", {
				values = { blessedHands = { 3, 9 } },
				passive = { hooks = { healBonus = "blessedHands" } },
			}),
		}),
		row(false, {
			node(H, "providence", "passive", 3, "❤", {
				values = { providence = { 8, 25 } },
				passive = { hooks = { lowHpHealBonus = "providence" } },
			}),
			node(H, "faithShield", "modify", 3, "🛡", {
				values = { faithShield = { 2, 6 } },
				modify = { skill = "shieldOfFaith", bp = { values = { shieldHp = ref("faithShield") } } },
			}),
		}),
		row(true, {
			node(H, "vigil", "modify", 3, "❦", {
				values = { vigil = { 1, 3 } },
				modify = { skill = "renew", bp = { add = { duration = ref("vigil") } } },
			}),
			node(H, "quietPrayer", "passive", 3, "🕯", {
				values = { quietPrayer = { 8, 25 } },
				passive = { pct = { manaRegen = "quietPrayer" } },
			}),
		}),
		row(false, {
			skill(H, "sanctuary"),
			node(H, "radiantCircle", "modify", 3, "◌", {
				values = { radiantCircle = { 1, 3 } },
				modify = { skill = "circleOfLight", bp = { values = { healHp = ref("radiantCircle") } } },
			}),
		}),
		row(false, {
			node(H, "shatter", "modify", 3, "✧", {
				values = { shatter = { 15, 45 } },
				modify = {
					skill = "shieldOfFaith",
					bp = { shieldBurst = { radius = 10 }, values = { shieldBurst = ref("shatter") } },
				},
			}),
			node(H, "grace", "passive", 3, "♥", {
				values = { grace = { 8, 24 } },
				passive = { hooks = { allyHealBonus = "grace" } },
			}),
		}),
		row(true, {
			node(H, "bulwark", "modify", 3, "⛨", {
				values = { bulwark = { 2, 6 }, bulwarkTime = { 1, 3 } },
				modify = {
					skill = "shieldOfFaith",
					bp = { values = { shieldHp = ref("bulwark") }, add = { duration = ref("bulwarkTime") } },
				},
			}),
			node(H, "wellspring", "modify", 3, "☔", {
				values = { wellspring = { 3, 9 } },
				modify = { skill = "renew", bp = { values = { healHp = ref("wellspring") } } },
			}),
		}),
		row(false, {
			skill(H, "divineIntervention"),
			node(H, "salvation", "modify", 3, "☩", {
				values = { salvation = { 0.92, 0.75 } },
				modify = { skill = "divineIntervention", bp = { mul = { cooldown = ref("salvation") } } },
			}),
		}),
		row(false, { skill(H, "guardianAngel") }),
		row(true, {
			node(H, "haste", "modify", 3, "⇉", {
				values = { haste = { 0.9, 0.7 } },
				modify = { skill = "heal", bp = { mul = { cooldown = ref("haste") } } },
			}),
			node(H, "wide", "modify", 3, "❂", {
				values = { wide = { 2, 6 } },
				modify = { skill = "sanctuary", bp = { add = { radius = ref("wide") } } },
			}),
		}),
		row(false, {
			node(H, "hope", "passive", 3, "✦", {
				values = { hope = { 2, 6 } },
				passive = { hooks = { allyHealBonus = "hope" } },
			}),
			node(H, "endurance", "passive", 3, "⛰", {
				values = { endurance = { 2, 6 }, enduranceMana = { 5, 15 } },
				passive = { pct = { maxHp = "endurance", manaRegen = "enduranceMana" } },
			}),
		}),
		row(false, {
			node(H, "choir", "modify", 2, "✟", {
				values = { choir = { 2, 4 }, choirHeal = { 10, 20 } },
				modify = {
					skill = "guardianAngel",
					bp = { add = { effectDuration = ref("choir") }, values = { saveHeal = ref("choirHeal") } },
				},
			}),
		}),
	},
	reference = {},
	wiki = false,
}

local fortune: Types.PathDef = {
	id = F,
	class = "Cleric",
	order = 2,
	role = "luck",
	nameKey = "path.fortune.name",
	descKey = "path.fortune.desc",
	titleId = "path_fortune",
	weapon = { offhand = { "relic" } },
	statPlan = { int = 1, vit = 1 },
	itemWeights = {
		axes = { util = 1.5, support = 1.1, dmg = 0.9 },
		stats = { dropBonus = 1.5, goldBonus = 1.3, dodge = 1.2, critChance = 1.1 },
		traits = { prosperity = 1.5, anointment = 1.1 },
	},
	rows = {
		row(false, {
			skill(F, "resurrection"),
			node(F, "blessedFate", "luck", 3, "✳", {
				values = { blessedFate = { 2, 6 } },
				luck = { bossLegendary = "blessedFate" },
			}),
		}),
		row(false, {
			node(F, "evilEye", "modify", 3, "👁", {
				values = { evilEye = { 2, 6 } },
				modify = {
					skill = "holyStrike",
					bp = { values = { misfortune = ref("evilEye") }, effect = misfortune() },
				},
			}),
			node(F, "smile", "passive", 3, "✦", {
				values = { smileCrit = { 1, 3 }, smileDodge = { 1, 3 } },
				passive = { flat = { critChance = "smileCrit", dodge = "smileDodge" } },
			}),
		}),
		row(true, {
			node(F, "luckyStep", "passive", 3, "🍃", {
				values = { luckyStep = { 2, 6 } },
				passive = { flat = { dodge = "luckyStep" } },
			}),
			node(F, "luckyHeal", "passive", 3, "✙", {
				values = { luckyHeal = { 100 / 3, 100 } },
				passive = { hooks = { healCrit = "luckyHeal" } },
			}),
		}),
		row(false, {
			skill(F, "fortuneDice"),
			node(F, "luckyHand", "luck", 3, "✧", {
				weapon = RELIC, -- S138: the Fortune's luck past row 2 needs the relic (on the node, DESIGN-18 §7)
				values = { luckyHand = { 10, 30 } },
				luck = { monsterItem = "luckyHand" },
			}),
		}),
		row(false, {
			node(F, "generousLoot", "luck", 3, "⚜", {
				weapon = RELIC, -- S138: the Fortune's luck past row 2 needs the relic (on the node, DESIGN-18 §7)
				values = { generousLoot = { 12, 35 } },
				luck = { bossUpgrade = "generousLoot" },
			}),
			node(F, "grace", "luck", 3, "✺", {
				weapon = RELIC, -- S138: the Fortune's luck past row 2 needs the relic (on the node, DESIGN-18 §7)
				values = { fortuneGrace = { 2, 7 } },
				luck = { bossLegendary = "fortuneGrace" },
			}),
		}),
		row(true, {
			node(F, "loadedDice", "modify", 3, "⚄", {
				values = { loadedDice = { 10, 30 } },
				modify = { skill = "fortuneDice", bp = { values = { boost = ref("loadedDice") } } },
			}),
			node(F, "quickDice", "modify", 3, "↺", {
				values = { quickDice = { 0.92, 0.75 } },
				modify = { skill = "fortuneDice", bp = { mul = { cooldown = ref("quickDice") } } },
			}),
		}),
		row(false, {
			skill(F, "prayer"),
			node(F, "goldVein", "luck", 3, "◉", {
				weapon = RELIC, -- S138: the Fortune's luck past row 2 needs the relic (on the node, DESIGN-18 §7)
				values = { goldVein = { 5, 15 }, goldVeinElite = { 7, 20 } },
				luck = { gold = "goldVein", elite2 = "goldVeinElite" },
			}),
		}),
		row(false, { skill(F, "wheelOfFortune") }),
		row(true, {
			node(F, "omen", "modify", 3, "☠", {
				values = { omen = { 2, 6 } },
				modify = {
					skill = "holyStrike",
					bp = { values = { misfortune = ref("omen") }, effect = misfortune() },
				},
			}),
			node(F, "streak", "modify", 3, "∞", {
				values = { streak = { 1, 3 } },
				modify = { skill = "fortuneDice", bp = { add = { effectDuration = ref("streak") } } },
			}),
		}),
		row(false, {
			node(F, "gift", "luck", 3, "✹", {
				weapon = RELIC, -- S138: the Fortune's luck past row 2 needs the relic (on the node, DESIGN-18 §7)
				values = { gift = { 5, 15 } },
				luck = { bossExtra = "gift" },
			}),
			node(F, "favored", "passive", 3, "⛨", {
				values = { favored = { 2, 6 }, favoredArmor = { 3, 9 } },
				passive = { pct = { maxHp = "favored", armor = "favoredArmor" } },
			}),
		}),
		row(false, {
			node(F, "eternalWheel", "modify", 2, "✺", {
				values = { eternalWheel = { 2, 4 }, eternalWheelCd = { 0.89, 0.78 } },
				modify = {
					skill = "wheelOfFortune",
					bp = { add = { effectDuration = ref("eternalWheel") }, mul = { cooldown = ref("eternalWheelCd") } },
				},
			}),
		}),
	},
	reference = {},
	wiki = false,
}

local inquisitor: Types.PathDef = {
	id = I,
	class = "Cleric",
	order = 3,
	role = "damage",
	nameKey = "path.inquisitor.name",
	descKey = "path.inquisitor.desc",
	titleId = "path_inquisitor",
	weapon = { main = { "mace1h", "flail1h" } },
	statPlan = { int = 1, vit = 2 },
	itemWeights = {
		axes = { dmg = 1.3, surv = 1.1, support = 0.6 },
		stats = {
			int = 1.2,
			magAtk = 1.2,
			critChance = 1.2,
			critDmg = 1.2,
			skillDmg = 1.2,
			magicPierce = 1.2,
			healPower = 0.4,
		},
		traits = { concussion = 1.2, bonebreaker = 1.2 },
	},
	rows = {
		row(false, {
			skill(I, "purify"),
			node(I, "zeal", "passive", 3, "✦", {
				values = { zeal = { 3, 7 } }, -- S91: { 4, 10 } -> { 3, 7 } (Cleric group at 20 with the node >= 30 % HP, S32)
				passive = { pct = { magAtk = "zeal" } },
			}),
		}),
		row(false, {
			node(I, "burningFaith", "passive", 3, "☀", {
				values = { burningFaith = { 4, 12 } },
				passive = { hooks = { holyDamage = "burningFaith" } },
			}),
			node(I, "heavyHand", "modify", 3, "🔨", {
				values = { heavyHand = { 14, 40 } },
				modify = { skill = "holyStrike", bp = { values = { dmg = ref("heavyHand") } } },
			}),
		}),
		row(true, {
			node(I, "shield", "passive", 3, "🛡", {
				weapon = { offhand = { "shield" } },
				values = { shieldArmor = { 6, 18 }, shieldBody = { 2, 6 } },
				passive = { pct = { armor = "shieldArmor", maxHp = "shieldBody" } },
			}),
			node(I, "relic", "passive", 3, "⚜", {
				weapon = { offhand = { "relic" } },
				values = { relic = { 4, 10 } },
				passive = { hooks = { holyDamage = "relic" } },
			}),
		}),
		row(false, {
			skill(I, "brandOfLight"),
			node(I, "ember", "passive", 3, "✹", {
				values = { ember = { 2, 6 } },
				passive = { flat = { critChance = "ember" } },
			}),
		}),
		row(false, {
			node(I, "finalVerdict", "modify", 3, "⚖", {
				values = { finalVerdict = { 20, 50 } },
				modify = {
					skill = "judgement",
					bp = { stunSplash = { radius = 6 }, values = { stunSplash = ref("finalVerdict") } },
				},
			}),
			node(I, "grit", "passive", 3, "⛰", {
				values = { grit = { 2.5, 7.5 } },
				passive = { pct = { maxHp = "grit" } },
			}),
		}),
		row(true, {
			node(I, "holyWrath", "passive", 3, "⚜", {
				values = { holyWrath = { 100 / 3, 100 } },
				passive = { hooks = { holyHealAll = "holyWrath" } },
			}),
			node(I, "fervor", "passive", 3, "⇶", {
				values = { fervor = { 0.3, 1 } },
				passive = { hooks = { zealCdr = "fervor" } },
			}),
		}),
		row(false, {
			skill(I, "auraOfEndurance"),
			node(I, "faithArmor", "passive", 3, "⛨", {
				values = { faithArmor = { 5, 15 } },
				passive = { pct = { armor = "faithArmor", mres = "faithArmor" } },
			}),
		}),
		row(false, { skill(I, "hammerOfHeaven") }),
		row(true, {
			node(I, "inquisition", "modify", 3, "⚖", {
				values = { inquisition = { 0.93, 0.8 } },
				modify = { skill = "judgement", bp = { mul = { cooldown = ref("inquisition") } } },
			}),
			node(I, "executioner", "modify", 3, "⚔", {
				values = { executioner = { 20, 50 } },
				modify = { skill = "judgement", bp = { execute = ref("executioner") } },
			}),
		}),
		row(false, {
			node(I, "truth", "modify", 3, "✹", {
				values = { truth = { 5, 15 } },
				modify = { skill = "brandOfLight", bp = { values = { dot = ref("truth") } } },
			}),
			node(I, "retribution", "passive", 3, "⤺", {
				values = { retribution = { 4, 12 } },
				passive = { hooks = { riposte = "retribution" } },
			}),
		}),
		row(false, {
			node(I, "thunder", "modify", 2, "⚒", {
				values = { thunder = { 0.85, 0.7 }, thunderRadius = { 1, 2 } },
				modify = {
					skill = "hammerOfHeaven",
					bp = { mul = { cooldown = ref("thunder") }, add = { radius = ref("thunderRadius") } },
				},
			}),
		}),
	},
	reference = {},
	wiki = false,
}

-- Model builds (ROZWOJ 7.5, 9.3-9.5; shape in Data/Paths/Types): each spends exactly pointsAt(100) = 50 points.
local function build(
	id: string,
	main: string,
	offhand: string?,
	stats: { [string]: number },
	nodes: { { any } },
	bp: { [string]: "a" | "b" },
	rotation: { { [string]: any } }
): Types.ReferenceBuild
	return {
		id = id,
		weapon = { main = main, offhand = offhand },
		nodes = nodes,
		bp = bp,
		stats = stats,
		rotation = rotation,
	}
end

local HEALER_NODES: { { any } } = {
	{ "healer_renew", 1 },
	{ "healer_blessedHands", 3 },
	{ "fortune_resurrection", 1 },
	{ "fortune_blessedFate", 3 },
	{ "inquisitor_purify", 1 },
	{ "inquisitor_zeal", 3 },
	{ "healer_providence", 3 },
	{ "healer_faithShield", 3 },
	{ "healer_quietPrayer", 3 },
	{ "healer_sanctuary", 1 },
	{ "healer_radiantCircle", 3 },
	{ "healer_shatter", 3 },
	{ "healer_grace", 3 },
	{ "healer_bulwark", 3 },
	{ "healer_divineIntervention", 1 },
	{ "healer_salvation", 3 },
	{ "healer_guardianAngel", 1 },
	{ "healer_haste", 3 },
	{ "healer_hope", 3 },
	{ "healer_endurance", 3 },
	{ "healer_choir", 2 },
}
local HEALER_BP: { [string]: "a" | "b" } = {
	["heal:10"] = "b",
	["circleOfLight:10"] = "b",
	["holyStrike:10"] = "b",
	["radiance:5"] = "b",
	["sanctuary:10"] = "b",
	["divineIntervention:10"] = "b",
	["resurrection:5"] = "b",
}

healer.reference = {
	build("dungeon", "scepter", "shield", healer.statPlan :: any, HEALER_NODES, HEALER_BP, {
		{ skill = "guardianAngel", beforeRedZone = true },
		{ skill = "shieldOfFaith", target = "tank" },
		{ skill = "renew", target = "tank" },
		{ skill = "sanctuary", target = "meleeAllies" },
		{ skill = "circleOfLight", minWounded = 3 },
		{ skill = "heal", target = "mostWounded" },
		{ skill = "holyStrike" },
	}),
	build("solo", "holystaff", nil, healer.statPlan :: any, HEALER_NODES, HEALER_BP, {
		{ skill = "heal", target = "self", belowHp = 50 },
		{ skill = "judgement" },
		{ skill = "holyStrike" },
		{ skill = "radiance", minEnemies = 2 },
	}),
}

fortune.reference = {
	build("plunder", "mace1h", "relic", fortune.statPlan :: any, {
		{ "fortune_resurrection", 1 },
		{ "fortune_blessedFate", 3 },
		{ "inquisitor_purify", 1 },
		{ "inquisitor_zeal", 3 },
		{ "healer_renew", 1 },
		{ "fortune_evilEye", 3 },
		{ "fortune_smile", 3 },
		{ "inquisitor_heavyHand", 3 },
		{ "fortune_luckyHeal", 3 },
		{ "fortune_fortuneDice", 1 },
		{ "fortune_luckyHand", 3 },
		{ "fortune_generousLoot", 3 },
		{ "fortune_grace", 3 },
		{ "fortune_quickDice", 3 },
		{ "fortune_prayer", 1 },
		{ "fortune_goldVein", 3 },
		{ "fortune_wheelOfFortune", 1 },
		{ "fortune_streak", 3 },
		{ "fortune_gift", 3 },
		{ "fortune_favored", 3 },
		{ "fortune_eternalWheel", 2 },
	}, {
		["radiance:10"] = "b",
		["shieldOfFaith:5"] = "b",
		["resurrection:5"] = "b",
		["fortuneDice:10"] = "b",
		["prayer:5"] = "b",
		["wheelOfFortune:10"] = "b",
	}, {
		{ skill = "wheelOfFortune", opener = true, elite = true },
		{ skill = "fortuneDice" },
		{ skill = "circleOfLight", minWounded = 3 },
		{ skill = "heal", target = "mostWounded" },
		{ skill = "holyStrike" },
	}),
}

local function inquisitorNodes(offhandNode: string): { { any } }
	return {
		{ "inquisitor_purify", 1 },
		{ "inquisitor_zeal", 3 },
		{ "healer_renew", 1 },
		{ "healer_blessedHands", 3 },
		{ "fortune_resurrection", 1 },
		{ "fortune_blessedFate", 3 },
		{ "inquisitor_burningFaith", 3 },
		{ "inquisitor_heavyHand", 3 },
		{ offhandNode, 3 },
		{ "inquisitor_brandOfLight", 1 },
		{ "inquisitor_ember", 3 },
		{ "inquisitor_finalVerdict", 3 },
		{ "inquisitor_grit", 3 },
		{ "inquisitor_holyWrath", 3 },
		{ "inquisitor_auraOfEndurance", 1 },
		{ "inquisitor_faithArmor", 3 },
		{ "inquisitor_hammerOfHeaven", 1 },
		{ "inquisitor_inquisition", 3 },
		{ "inquisitor_truth", 3 },
		{ "inquisitor_retribution", 3 },
		{ "inquisitor_thunder", 2 },
	}
end
local INQUISITOR_BP: { [string]: "a" | "b" } = {
	["holyStrike:5"] = "b",
	["judgement:5"] = "b",
	["judgement:10"] = "b",
	["radiance:5"] = "b",
	["radiance:10"] = "b",
	["hammerOfHeaven:10"] = "b",
	["heal:5"] = "b",
	["purify:5"] = "b",
	["purify:10"] = "b",
	["auraOfEndurance:10"] = "b",
	["resurrection:5"] = "b",
}
local INQUISITOR_ROTATION: { { [string]: any } } = {
	{ skill = "purify", target = "self", belowHp = 50 },
	{ skill = "purify", target = "self", debuff = "poison" },
	{ skill = "auraOfEndurance" },
	{ skill = "brandOfLight" },
	{ skill = "judgement" },
	{ skill = "holyStrike" },
	{ skill = "hammerOfHeaven", minEnemies = 3 },
	{ skill = "radiance", minEnemies = 2 },
}

inquisitor.reference = {
	build(
		"solo",
		"mace1h",
		"relic",
		inquisitor.statPlan :: any,
		inquisitorNodes("inquisitor_relic"),
		INQUISITOR_BP,
		INQUISITOR_ROTATION
	),
	build(
		"bulwark",
		"mace1h",
		"shield",
		inquisitor.statPlan :: any,
		inquisitorNodes("inquisitor_shield"),
		INQUISITOR_BP,
		INQUISITOR_ROTATION
	),
}

return { healer, fortune, inquisitor } :: { Types.PathDef }
