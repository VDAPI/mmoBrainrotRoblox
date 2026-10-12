--!strict
-- Random item bonuses (DESIGN §5.4). Data only; rolling in Logic/ItemRoll.
--
-- A bonus instance on an item is { stat = <bonus id>, v = <value> }. Each bonus id maps to a StatCalc stat
-- (`stat`) applied as a flat addition or a percentage multiplier (`mode`), or to a special effect `hook`
-- handled by CombatService/LootService (legendary and mythic pools).
--
-- Value = lerp(min, max, roll) x scale(ilvl) x rarity.rangeMul, where
--   scale = 1 + ilvl / 20 for "flat" scaling (primary stats),
--           (6 + 2.2 ilvl) / 8.2 for "curve" scaling (S32: HP, mana, armour, resistance grow like item bases),
--           1 + ilvl / 60 for "pct" scaling (percentages).
-- S32: attack bonuses are percentages of the attack (a flat +5 was +50 % at level 1 and +3 % at level 20), and
-- pools are filtered by class (`CLASS_STATS`): a Warrior's sword never rolls INT or magic attack.

export type BonusTier = "regular" | "legendary" | "mythic"

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
}

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
bonus("pierce", "pierce", "flat", 3, 6, "pct", 1, true) -- % of the target's armour ignored, after armour break
bonus("magicPierce", "magicPierce", "flat", 3, 6, "pct", 1, true) -- % of the target's magic resistance ignored
bonus("skillDmg", "skillDmg", "flat", 1, 2.2, "pct", 1, true) -- +% skill damage (params.isSkill)
bonus("basicDmg", "basicDmg", "flat", 1.5, 3.3, "pct", 1, true) -- +% basic attack damage (params.basic)
bonus("healPower", "healPower", "flat", 1.5, 3.5, "pct", 1, true) -- +% heals and shields you cast
bonus("critResist", "critResist", "flat", 3, 6, "pct", 1, true) -- % less crit bonus taken
bonus("costReduce", "costReduce", "flat", 1.5, 3, "none", 1, true) -- % cheaper skills, no scale (STATY 4)
-- S63 (STATY 4): on-hit lines. Hooks summed by EquipmentService and read by CombatService, not StatCalc stats.
bonus("woundChance", nil, "flat", 2, 4, "pct", 1, true, "woundChance") -- % chance of a deep wound
bonus("poisonChance", nil, "flat", 2, 4, "pct", 1, true, "poisonChance") -- % chance to poison
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

-- Legendary pool (one extra bonus on every legendary item) --------------------------------------------------
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

-- Mythic pool (FIX 2026-10-09: one line on every mythic item, on top of its 2 legendary lines). Stronger
-- versions of the legendary effects; the hooks add up with legendary lines of the same effect.
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
		"manaRegen",
		"skillDmg",
		"costReduce",
		"dotPower",
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
	},
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
	-- S63: no Cleric until the Cleric has damage over time (S70 adds them with the burn).
	woundChance = { "Warrior", "Hunter" },
	poisonChance = { "Hunter" },
	dotPower = { "Warrior", "Hunter", "Mage" },
	blockChance = { "Warrior", "Cleric" }, -- S64: shields only
}

return table.freeze({
	byId = DEFS,
	pools = POOLS,
	classStats = CLASS_STATS,
	get = function(id: string): BonusDef?
		return DEFS[id]
	end,
})
