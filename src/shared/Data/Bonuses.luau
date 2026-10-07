--!strict
-- Random item bonuses (DESIGN §5.4). Data only; rolling in Logic/ItemRoll.
--
-- A bonus instance on an item is { stat = <bonus id>, v = <value> }. Each bonus id maps to a StatCalc stat
-- (`stat`) applied as a flat addition or a percentage multiplier (`mode`), or to a special effect `hook`
-- handled by CombatService/LootService (legendary pool).
--
-- Value = lerp(min, max, roll) x scale(ilvl) x rarity.rangeMul, where
--   scale = 1 + ilvl / 20 for "flat" scaling (primary stats),
--           (6 + 2.2 ilvl) / 8.2 for "curve" scaling (S32: HP, mana, armour, resistance grow like item bases),
--           1 + ilvl / 60 for "pct" scaling (percentages).
-- S32: attack bonuses are percentages of the attack (a flat +5 was +50 % at level 1 and +3 % at level 20), and
-- pools are filtered by class (`CLASS_STATS`): a Warrior's sword never rolls INT or magic attack.

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
	hook: string?
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
bonus("armorPen", "armorPen", "flat", 1, 2.5, "curve", 0, false)
bonus("lifesteal", "lifesteal", "flat", 0.5, 1.5, "pct", 1, true)
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
bonus("leg_bossDamage", nil, "flat", 6, 10, "none", 1, true, "bossDamage") -- +% damage against bosses
bonus("leg_eliteDamage", nil, "flat", 8, 12, "none", 1, true, "eliteDamage") -- +% damage against elites
bonus("leg_doubleAttack", nil, "flat", 4, 6, "none", 1, true, "doubleAttack") -- % chance to hit twice
bonus("leg_killHeal", nil, "flat", 2, 4, "none", 1, true, "killHeal") -- % max HP healed on kill
bonus("leg_thorns", nil, "flat", 6, 10, "none", 1, true, "thorns") -- % of damage taken reflected
bonus("leg_manaOnHit", nil, "flat", 1, 3, "none", 1, true, "manaOnHit") -- % max mana restored per hit
bonus("leg_executioner", nil, "flat", 12, 18, "none", 1, true, "executioner") -- +% damage below 30 % HP
bonus("leg_lastStand", nil, "flat", 12, 18, "none", 1, true, "lastStand") -- -% damage taken below 30 % HP
bonus("leg_expBonus", "expBonus", "flat", 12, 18, "none", 0, true)
bonus("leg_goldBonus", "goldBonus", "flat", 15, 25, "none", 0, true)
bonus("leg_dropBonus", "dropBonus", "flat", 10, 15, "none", 0, true)
bonus("leg_lifesteal", "lifesteal", "flat", 2, 4, "none", 1, true)
bonus("leg_moveSpeed", "moveSpeed", "flat", 6, 10, "none", 0, true)
bonus("leg_critDmg", "critDmg", "flat", 20, 30, "none", 0, true)

-- Pools per bonus group (item definitions name their group) --------------------------------------------------
local POOLS: { [string]: { string } } = {
	weapon = {
		"physAtk",
		"magAtk",
		"critChance",
		"critDmg",
		"atkSpeed",
		"armorPen",
		"lifesteal",
		"accuracy",
		"str",
		"dex",
		"int",
	},
	shield = { "armor", "hp", "hpPct", "mres", "vit", "resFire", "resIce", "resLightning", "resPoison", "hpRegen" },
	quiver = { "physAtk", "critChance", "critDmg", "atkSpeed", "accuracy", "dex", "armorPen" },
	magicOffhand = { "magAtk", "mana", "manaRegen", "int", "critChance", "critDmg", "mres", "hpRegen" },
	helmet = { "hp", "armor", "mres", "int", "vit", "manaRegen", "hpRegen", "resIce", "resLightning" },
	armor = { "hp", "hpPct", "armor", "mres", "vit", "str", "resFire", "resIce", "resLightning", "resPoison" },
	gloves = { "physAtk", "magAtk", "critChance", "atkSpeed", "accuracy", "str", "dex", "armor" },
	boots = { "moveSpeed", "dodge", "hp", "armor", "dex", "energyRegen", "resPoison" },
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
	},
	talisman = { "str", "dex", "int", "vit", "mres", "expBonus", "dropBonus", "energyRegen", "manaRegen", "hpPct" },
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
	},
}

-- Bonuses only some classes use (S32): an item rolls them only when one of its classes (or, for class-free
-- jewellery, the class it dropped for) is listed. Everything else is useful to every class.
local CLASS_STATS: { [string]: { string } } = {
	str = { "Warrior" },
	dex = { "Hunter" },
	int = { "Mage", "Cleric" },
	physAtk = { "Warrior", "Hunter" },
	armorPen = { "Warrior", "Hunter" },
	magAtk = { "Mage", "Cleric" },
	mana = { "Mage", "Cleric" },
	manaRegen = { "Mage", "Cleric" },
	leg_manaOnHit = { "Mage", "Cleric" },
	energy = { "Warrior", "Hunter" },
	energyRegen = { "Warrior", "Hunter" },
}

return table.freeze({
	byId = DEFS,
	pools = POOLS,
	classStats = CLASS_STATS,
	get = function(id: string): BonusDef?
		return DEFS[id]
	end,
})
