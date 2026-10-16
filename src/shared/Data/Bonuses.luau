--!strict
-- Random item bonuses (DESIGN §5.4). Data only; rolling in Logic/ItemRoll.
--
-- A bonus instance on an item is { stat = <bonus id>, v = <value> }. Each bonus id maps to a StatCalc stat
-- (`stat`) applied as a flat addition or a percentage multiplier (`mode`), or to a special effect `hook`
-- handled by CombatService/LootService (S134g: the legendary and mythic pools are legacy, never rolled; Legendary and
-- Mythic items roll skill effects, Data/ItemEffects).
--
-- Value = lerp(min, max, roll) x scale(ilvl) x rarity.rangeMul, where (constants in SCALING below)
--   scale = 1 + ilvl / 20 for "flat" scaling (primary stats),
--           (6 + 2.2 ilvl) / 8.2 for "curve" scaling (S32: HP, mana, armour, resistance grow like item bases),
--           1 + min(ilvl, 20) / 60 for "pct" scaling (percentages; S87: no growth above ilvl 20, at most x1.33).
-- S32: attack bonuses are percentages of the attack (a flat +5 was +50 % at level 1 and +3 % at level 20), and
-- pools are filtered by class (`CLASS_STATS`): a Warrior's sword never rolls INT or magic attack.
-- S67 (STATY 4): a pool entry starting with "@" is a parameter marker ("@vsFamily", "@resFamily", "@vsClass",
-- "@resClass"); ItemRoll.rollItem expands it to one variant line ("vs_undead", "res_mage") before saving.

local Classes = require("./Classes")
local Families = require("./Families")
local Types = require("../Types")

export type BonusTier = "regular" | "legendary" | "mythic"
-- S68 (tooltip details): how a line works against players. same: like any stat (hits x Combat.pvpModifier); none: not
-- at all; only: only against players; ticks: damage over time x Combat.pvp.dot; half: x Combat.pvp[<stat or hook>].
export type PvpMode = "same" | "none" | "only" | "ticks" | "half"

export type BonusDef = {
	id: string,
	nameKey: string,
	stat: string?, -- StatCalc id (also "hp"/"mana"/"energy" aliases)
	mode: "flat" | "pct", -- flat addition or % multiplier of the stat
	hook: string?, -- special effect id (legendary pool)
	min: number,
	max: number,
	scaling: "flat" | "curve" | "pct" | "none",
	decimals: number,
	percent: boolean, -- display with %
	tier: BonusTier, -- row style in the tooltip and the wiki; replaces guessing by hook or prefix (STATY 2C)
	wiki: boolean, -- exported to the wiki; false for legacy lines
	replacedBy: string?, -- legacy id read as another line (ItemRoll.itemStats, STATY 12)
	param: string?, -- S67: the pool marker this variant comes from ("@vsFamily")
	of: string?, -- S67: family id or class id (Classes.order form, "Mage") of a variant
	capRef: Types.CapRef?, -- S68: cap enforced outside Data/Stats (a stat with a Stats cap needs none)
	pvp: PvpMode?, -- S68: nil = "same"; never on the wiki (only the finished detail texts are)
}

export type Param = { prefix: "vs_" | "res_", over: "family" | "class" }

local DEFS: { [string]: BonusDef } = {}

local function bonus(
	id: string,
	stat: string?,
	mode: "flat" | "pct",
	min: number,
	max: number,
	scaling: "flat" | "curve" | "pct" | "none",
	decimals: number,
	percent: boolean,
	hook: string?,
	tier: BonusTier?
)
	DEFS[id] = {
		id = id,
		nameKey = `bonus.{id}`,
		stat = stat,
		mode = mode,
		hook = hook,
		min = min,
		max = max,
		scaling = scaling,
		decimals = decimals,
		percent = percent,
		tier = tier or "regular",
		wiki = true,
	}
end

-- Regular bonuses ------------------------------------------------------------------------------------------
bonus("str", "str", "flat", 0.6, 1.8, "flat", 0, false)
bonus("dex", "dex", "flat", 0.6, 1.8, "flat", 0, false)
bonus("int", "int", "flat", 0.6, 1.8, "flat", 0, false)
bonus("vit", "vit", "flat", 0.6, 1.8, "flat", 0, false)
bonus("hp", "maxHp", "flat", 2.5, 6, "curve", 0, false)
bonus("hpPct", "maxHp", "pct", 1, 2, "pct", 1, true)
bonus("mana", "maxMana", "flat", 2.5, 6, "curve", 0, false)
bonus("energy", "maxEnergy", "flat", 3, 8, "pct", 0, false)
bonus("physAtk", "physAtk", "pct", 1, 2.2, "pct", 1, true)
bonus("magAtk", "magAtk", "pct", 1, 2.2, "pct", 1, true)
bonus("armor", "armor", "flat", 1, 2.5, "curve", 0, false)
bonus("mres", "mres", "flat", 1, 2.5, "curve", 0, false)
bonus("critChance", "critChance", "flat", 0.5, 1.2, "pct", 1, true)
bonus("critDmg", "critDmg", "flat", 2, 5, "pct", 0, true)
bonus("atkSpeed", "atkSpeed", "flat", 1, 2.2, "pct", 1, true)
-- legacy flat penetration: read as "pierce" with the same roll quality (ItemRoll.itemStats); in no pool
bonus("armorPen", "armorPen", "flat", 1, 2.5, "curve", 0, false)
bonus("lifesteal", "lifesteal", "flat", 0.5, 1.5, "pct", 1, true)
-- S62 (STATY 4): new regular lines; "pierce" replaces the flat "armorPen".
bonus("pierce", "pierce", "flat", 2.5, 5, "pct", 1, true) -- % of the target's armour ignored, after armour break
bonus("magicPierce", "magicPierce", "flat", 2, 4, "pct", 1, true) -- % of the target's magic resistance ignored
bonus("skillDmg", "skillDmg", "flat", 0.8, 1.8, "pct", 1, true) -- +% skill damage (params.isSkill)
bonus("basicDmg", "basicDmg", "flat", 1, 2.2, "pct", 1, true) -- +% basic attack damage (params.basic)
bonus("healPower", "healPower", "flat", 1.5, 3.5, "pct", 1, true) -- +% heals and shields you cast
bonus("critResist", "critResist", "flat", 3, 6, "pct", 1, true) -- % less crit bonus taken
bonus("costReduce", "costReduce", "flat", 1.5, 3, "none", 1, true) -- % cheaper skills, no scale (STATY 4)
-- S63 (STATY 4): on-hit lines. Hooks summed by EquipmentService and read by CombatService, not StatCalc stats.
bonus("woundChance", nil, "flat", 1.2, 2.4, "pct", 1, true, "woundChance") -- % chance of a deep wound
bonus("poisonChance", nil, "flat", 1.2, 2.4, "pct", 1, true, "poisonChance") -- % chance to poison
bonus("dotPower", nil, "flat", 4, 8, "pct", 1, true, "dotPower") -- +% damage of your bleeds, poisons and burns
bonus("resourceOnHit", nil, "flat", 0.2, 0.5, "none", 2, true, "resourceOnHit") -- % max mana / energy per hit
-- S64 (STATY 4): defensive lines.
bonus("blockChance", nil, "flat", 1, 2, "pct", 1, true, "block") -- % block chance, shared blockCap with Parry
bonus("meleeGuard", "meleeGuard", "flat", 1, 2.5, "pct", 1, true) -- -% damage from melee blows
bonus("rangedGuard", "rangedGuard", "flat", 1, 2.5, "pct", 1, true) -- -% damage from arrows and ranged spells
bonus("accuracy", "accuracy", "flat", 1, 3, "pct", 1, true)
bonus("dodge", "dodge", "flat", 0.5, 1.2, "pct", 1, true)
bonus("resFire", "resFire", "flat", 3, 8, "pct", 0, true)
bonus("resIce", "resIce", "flat", 3, 8, "pct", 0, true)
bonus("resLightning", "resLightning", "flat", 3, 8, "pct", 0, true)
bonus("resPoison", "resPoison", "flat", 3, 8, "pct", 0, true)
bonus("hpRegen", "hpRegen", "flat", 0.3, 1, "curve", 1, false)
bonus("manaRegen", "manaRegen", "flat", 0.3, 1, "curve", 1, false)
bonus("energyRegen", "energyRegen", "flat", 0.3, 1, "pct", 1, false)
bonus("moveSpeed", "moveSpeed", "flat", 2, 5, "pct", 0, true)
bonus("expBonus", "expBonus", "flat", 2, 5, "pct", 0, true)
bonus("goldBonus", "goldBonus", "flat", 3, 8, "pct", 0, true)
bonus("dropBonus", "dropBonus", "flat", 2, 5, "pct", 0, true)

-- Legacy legendary lines (S134g: never rolled; items from before S134g convert to skill effects) ----------------
bonus("leg_bossDamage", nil, "flat", 6, 10, "none", 1, true, "bossDamage", "legendary") -- +% damage against bosses
bonus("leg_eliteDamage", nil, "flat", 8, 12, "none", 1, true, "eliteDamage", "legendary") -- +% damage against elites
bonus("leg_doubleAttack", nil, "flat", 4, 6, "none", 1, true, "doubleAttack", "legendary") -- % chance to hit twice
bonus("leg_killHeal", nil, "flat", 2, 4, "none", 1, true, "killHeal", "legendary") -- % max HP healed on kill
bonus("leg_thorns", nil, "flat", 6, 10, "none", 1, true, "thorns", "legendary") -- % of damage taken reflected
bonus("leg_manaOnHit", nil, "flat", 1, 3, "none", 1, true, "manaOnHit", "legendary") -- % max mana restored per hit
bonus("leg_executioner", nil, "flat", 12, 18, "none", 1, true, "executioner", "legendary") -- +% damage below 30 % HP
bonus("leg_lastStand", nil, "flat", 12, 18, "none", 1, true, "lastStand", "legendary") -- -% damage taken below 30 % HP
bonus("leg_expBonus", "expBonus", "flat", 12, 18, "none", 0, true, nil, "legendary")
bonus("leg_goldBonus", "goldBonus", "flat", 15, 25, "none", 0, true, nil, "legendary")
bonus("leg_dropBonus", "dropBonus", "flat", 10, 15, "none", 0, true, nil, "legendary")
bonus("leg_lifesteal", "lifesteal", "flat", 2, 4, "none", 1, true, nil, "legendary")
bonus("leg_moveSpeed", "moveSpeed", "flat", 6, 10, "none", 0, true, nil, "legendary")
bonus("leg_critDmg", "critDmg", "flat", 20, 30, "none", 0, true, nil, "legendary")
-- S64 (STATY 2C, owner answer 26): no scaling like the other leg_/myth_ lines, capped by Combat.cdrCap.
bonus("leg_cooldown", nil, "flat", 6, 10, "none", 1, true, "cooldownReduction", "legendary") -- -% skill cooldowns

-- Legacy mythic lines (FIX 2026-10-09 to S134g: one on every mythic item; S134g: never rolled, converted to effects).
-- Stronger versions of the legendary effects; the hooks add up with legendary lines of the same effect.
bonus("myth_bossDamage", nil, "flat", 15, 20, "none", 1, true, "bossDamage", "mythic")
bonus("myth_eliteDamage", nil, "flat", 18, 25, "none", 1, true, "eliteDamage", "mythic")
bonus("myth_doubleAttack", nil, "flat", 8, 12, "none", 1, true, "doubleAttack", "mythic")
bonus("myth_killHeal", nil, "flat", 5, 8, "none", 1, true, "killHeal", "mythic")
bonus("myth_executioner", nil, "flat", 25, 35, "none", 1, true, "executioner", "mythic")
bonus("myth_lastStand", nil, "flat", 25, 35, "none", 1, true, "lastStand", "mythic")
bonus("myth_critDmg", "critDmg", "flat", 40, 60, "none", 0, true, nil, "mythic")
bonus("myth_hpPct", "maxHp", "pct", 8, 12, "none", 1, true, nil, "mythic")
bonus("myth_physAtk", "physAtk", "pct", 8, 12, "none", 1, true, nil, "mythic")
bonus("myth_magAtk", "magAtk", "pct", 8, 12, "none", 1, true, nil, "mythic")
bonus("myth_cooldown", nil, "flat", 12, 16, "none", 1, true, "cooldownReduction", "mythic")

DEFS.armorPen.wiki = false
DEFS.armorPen.replacedBy = "pierce"

-- S134g (STATY 2C): nothing rolls the legendary and mythic lines any more (Legendary and Mythic items roll skill
-- effects, Data/ItemEffects). The definitions stay for items not yet converted (mail, auctions; Logic/ItemEffects
-- .migrateItem) and are off the wiki.
for _, def in DEFS do
	if def.tier ~= "regular" then
		def.wiki = false
	end
end

-- S68: caps and PvP behaviour of the lines for the tooltip details (the numbers stay where they are enforced).
local function cap(source: "stat" | "combat" | "category" | "luck", key: string): Types.CapRef
	return table.freeze({ source = source, key = key })
end
local function rule(ids: { string }, capRef: Types.CapRef?, pvp: PvpMode?)
	for _, id in ids do
		DEFS[id].capRef = capRef
		DEFS[id].pvp = pvp
	end
end
rule({ "blockChance" }, cap("combat", "blockCap"), "half") -- CombatService: Traits.blockChance(.., pvp) x pvp.block
rule({ "leg_cooldown", "myth_cooldown" }, cap("combat", "cdrCap"))
rule({ "leg_executioner", "myth_executioner" }, cap("combat", "executionerCap"))
rule({ "leg_lastStand", "myth_lastStand" }, cap("category", "damageReduction")) -- own entry under the shared cap (S53)
rule({ "woundChance", "poisonChance" }, cap("combat", "onHitChanceCap"), "ticks")
rule({ "dotPower" }, nil, "ticks")
rule({ "resourceOnHit" }, cap("combat", "resourceOnHitCap"))
rule({ "dropBonus", "leg_dropBonus" }, cap("luck", "monsterItemCap"), "none")
rule({
	"expBonus",
	"goldBonus",
	"leg_expBonus",
	"leg_goldBonus",
	"leg_killHeal",
	"myth_killHeal",
	"leg_bossDamage",
	"myth_bossDamage",
	"leg_eliteDamage",
	"myth_eliteDamage",
	"leg_thorns",
}, nil, "none")
rule({ "lifesteal", "leg_lifesteal" }, nil, "half") -- Damage.computeDamage: x Combat.pvp.lifesteal

-- S67 (STATY 4): lines with a parameter. Each variant is a hook under its own id (summed like other hooks): vs_<family>
-- read by CombatService on monsters of that family, res_<family> as a damage reduction against them (Combat.familyResCap),
-- vs_/res_<class> only in PvP (Combat.classLineCap each side).
local PARAMS: { [string]: Param } = {
	["@vsFamily"] = { prefix = "vs_", over = "family" },
	["@resFamily"] = { prefix = "res_", over = "family" },
	["@vsClass"] = { prefix = "vs_", over = "class" },
	["@resClass"] = { prefix = "res_", over = "class" },
}
-- S88 (answer 23, STATY 4): at ilvl 20+ ("pct" scale x4/3) a Common line rolls vs_<family> 5-12, res_<family> 5-11,
-- vs_/res_<class> 4-9; the Mythic top 14.4 / 13.2 / 10.8 (ItemRoll.bonusRange, balance.spec S88).
local PARAM_RANGES: { [string]: { number } } = {
	["@vsFamily"] = { 3.75, 9 },
	["@resFamily"] = { 3.75, 8.25 },
	["@vsClass"] = { 3, 6.75 },
	["@resClass"] = { 3, 6.75 },
}
local PARAM_ORDER = { "@vsFamily", "@resFamily", "@vsClass", "@resClass" }

local function familyLine(prefix: "vs_" | "res_", familyId: string): string
	return prefix .. familyId
end

local function classLine(prefix: "vs_" | "res_", classId: string): string
	return prefix .. string.lower(classId)
end

local VARIANTS: { [string]: { string } } = {}
for _, paramId in PARAM_ORDER do
	local param = PARAMS[paramId]
	local range = PARAM_RANGES[paramId]
	local list: { string } = {}
	local sources: { string } = if param.over == "family" then Families.ids :: any else Classes.order :: any
	for _, of in sources do
		local id = if param.over == "family" then familyLine(param.prefix, of) else classLine(param.prefix, of)
		bonus(id, nil, "flat", range[1], range[2], "pct", 1, true, id)
		DEFS[id].param = paramId
		DEFS[id].of = of
		if param.over == "class" then
			rule({ id }, cap("combat", "classLineCap"), "only")
		elseif param.prefix == "res_" then
			rule({ id }, cap("combat", "familyResCap"), "none")
		else
			rule({ id }, nil, "none")
		end
		table.insert(list, id)
	end
	VARIANTS[paramId] = table.freeze(list)
end

-- Pools per bonus group (item definitions name their group) --------------------------------------------------
local POOLS: { [string]: { string } } = {
	weapon = {
		"physAtk",
		"magAtk",
		"critChance",
		"critDmg",
		"atkSpeed",
		"pierce",
		"lifesteal",
		"accuracy",
		"str",
		"dex",
		"int",
		"magicPierce",
		"skillDmg",
		"basicDmg",
		"healPower",
		"woundChance",
		"poisonChance",
		"dotPower",
		"@vsFamily",
	},
	shield = {
		"armor",
		"hp",
		"hpPct",
		"mres",
		"vit",
		"resFire",
		"resIce",
		"resLightning",
		"resPoison",
		"critResist",
		"blockChance", -- S64; hpRegen left the shield pool to keep it at 13 lines (STATY 9)
		"meleeGuard",
		"rangedGuard",
		"@resFamily",
	},
	quiver = {
		"physAtk",
		"critChance",
		"critDmg",
		"atkSpeed",
		"accuracy",
		"dex",
		"pierce",
		"skillDmg",
		"basicDmg",
		"costReduce",
		"woundChance",
		"poisonChance",
	},
	magicOffhand = {
		"magAtk",
		"mana",
		"manaRegen",
		"int",
		"critChance",
		"critDmg",
		"mres",
		"hpRegen",
		"magicPierce",
		"skillDmg",
		"healPower",
		"costReduce",
	},
	helmet = {
		"hp",
		"armor",
		"mres",
		"int",
		"vit",
		"manaRegen",
		"hpRegen",
		"resIce",
		"resLightning",
		"healPower",
		"critResist",
		"costReduce",
		"rangedGuard",
		"@resFamily",
	},
	armor = {
		"hp",
		"hpPct",
		"armor",
		"mres",
		"vit",
		"str",
		"resFire",
		"resIce",
		"resLightning",
		"resPoison",
		"critResist",
		"meleeGuard",
		"rangedGuard",
		"@resFamily",
	},
	gloves = {
		"physAtk",
		"magAtk",
		"critChance",
		"atkSpeed",
		"accuracy",
		"str",
		"dex",
		"armor",
		"pierce",
		"magicPierce",
		"basicDmg",
		"woundChance",
		"poisonChance",
		"resourceOnHit",
	},
	boots = { "moveSpeed", "dodge", "hp", "armor", "dex", "energyRegen", "resPoison", "meleeGuard" },
	necklace = {
		"str",
		"dex",
		"int",
		"vit",
		"hp",
		"mana",
		"critChance",
		"critDmg",
		"expBonus",
		"goldBonus",
		"dropBonus",
		"hpRegen",
		"skillDmg",
		"costReduce",
		"dotPower",
		"@vsFamily", -- S67: manaRegen left the necklace to keep the Mage pool at 14 (STATY 9)
	},
	ring = {
		"str",
		"dex",
		"int",
		"vit",
		"critChance",
		"dodge",
		"accuracy",
		"lifesteal",
		"goldBonus",
		"dropBonus",
		"energy",
		"pierce",
		"basicDmg",
		"resourceOnHit",
		"@vsClass",
		"@resClass",
	},
	talisman = {
		"str",
		"dex",
		"int",
		"vit",
		"mres",
		"expBonus",
		"dropBonus",
		"energyRegen",
		"manaRegen",
		"hpPct",
		"critResist",
		"@resFamily",
		"@vsClass",
		"@resClass",
	},
	-- S134g: legacy lists of the old legendary / mythic lines; never rolled (ItemRoll.rollItem rolls skill effects)
	legendary = {
		"leg_bossDamage",
		"leg_eliteDamage",
		"leg_doubleAttack",
		"leg_killHeal",
		"leg_thorns",
		"leg_manaOnHit",
		"leg_executioner",
		"leg_lastStand",
		"leg_expBonus",
		"leg_goldBonus",
		"leg_dropBonus",
		"leg_lifesteal",
		"leg_moveSpeed",
		"leg_critDmg",
		"leg_cooldown",
	},
	mythic = {
		"myth_bossDamage",
		"myth_eliteDamage",
		"myth_doubleAttack",
		"myth_killHeal",
		"myth_executioner",
		"myth_lastStand",
		"myth_critDmg",
		"myth_hpPct",
		"myth_physAtk",
		"myth_magAtk",
		"myth_cooldown",
	},
}

-- Bonuses only some classes use (S32): an item rolls them only when one of its classes (or, for class-free
-- jewellery, the class it dropped for) is listed. Everything else is useful to every class.
local CLASS_STATS: { [string]: { string } } = {
	str = { "Warrior" },
	dex = { "Hunter" },
	int = { "Mage", "Cleric" },
	physAtk = { "Warrior", "Hunter" },
	pierce = { "Warrior", "Hunter" },
	magicPierce = { "Mage", "Cleric" },
	healPower = { "Cleric" },
	magAtk = { "Mage", "Cleric" },
	mana = { "Mage", "Cleric" },
	manaRegen = { "Mage", "Cleric" },
	leg_manaOnHit = { "Mage", "Cleric" },
	myth_physAtk = { "Warrior", "Hunter" },
	myth_magAtk = { "Mage", "Cleric" },
	energy = { "Warrior", "Hunter" },
	energyRegen = { "Warrior", "Hunter" },
	-- S63: wounds and poison only for classes that bleed / poison; S70: the Cleric burns (Brand of Light), so dotPower.
	woundChance = { "Warrior", "Hunter" },
	poisonChance = { "Hunter" },
	dotPower = { "Warrior", "Hunter", "Mage", "Cleric" },
	blockChance = { "Warrior", "Cleric" }, -- S64: shields only
}

-- Bonus value scaling by item level (ItemRoll.scaleFor). S87 (balance plan C1): "pct" stops growing at
-- ilvl pctCapIlvl (x1.33 instead of x2.67 at 100); 1-20 unchanged.
local SCALING = table.freeze({
	flatPer = 20,
	curveBase = 6,
	curveSlope = 2.2,
	curveDiv = 8.2,
	pctPer = 60,
	pctCapIlvl = 20,
})

return table.freeze({
	byId = DEFS,
	scaling = SCALING,
	pools = POOLS,
	classStats = CLASS_STATS,
	get = function(id: string): BonusDef?
		return DEFS[id]
	end,
	-- S67: pool markers and their variants.
	params = table.freeze(PARAMS),
	isParam = function(id: string): boolean
		return PARAMS[id] ~= nil
	end,
	familyLine = familyLine,
	classLine = classLine,
	-- Variant ids of a marker in a fixed order (Families.ids / Classes.order); empty for anything else.
	variants = function(paramId: string): { string }
		return VARIANTS[paramId] or {}
	end,
})
