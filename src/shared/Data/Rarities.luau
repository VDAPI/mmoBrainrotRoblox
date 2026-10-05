--!strict
-- Item rarities and drop chances (DESIGN §5.2, §5.5). Data only.

export type RarityDef = {
	id: number,
	key: string, -- "common" .. "legendary", "unique"
	nameKey: string,
	color: string,
	bonusCount: number,
	baseMul: number, -- base stat multiplier
	rangeMul: number, -- multiplier of random bonus values
	legendaryBonus: boolean, -- +1 bonus from the legendary pool
	sellMul: number, -- "mnożnik rzadkości" in the sell price formula (DESIGN §18)
}

local LIST: { RarityDef } = {
	{
		id = 1,
		key = "common",
		nameKey = "rarity.common",
		color = "#C9CED6",
		bonusCount = 0,
		baseMul = 1.0,
		rangeMul = 1.0,
		legendaryBonus = false,
		sellMul = 1,
	},
	{
		id = 2,
		key = "uncommon",
		nameKey = "rarity.uncommon",
		color = "#4FD16B",
		bonusCount = 1,
		baseMul = 1.08,
		rangeMul = 1.0,
		legendaryBonus = false,
		sellMul = 1.08,
	},
	{
		id = 3,
		key = "rare",
		nameKey = "rarity.rare",
		color = "#3D8BFF",
		bonusCount = 2,
		baseMul = 1.16,
		rangeMul = 1.1,
		legendaryBonus = false,
		sellMul = 1.16,
	},
	{
		id = 4,
		key = "epic",
		nameKey = "rarity.epic",
		color = "#B455FF",
		bonusCount = 3,
		baseMul = 1.25,
		rangeMul = 1.25,
		legendaryBonus = false,
		sellMul = 1.25,
	},
	{
		id = 5,
		key = "legendary",
		nameKey = "rarity.legendary",
		color = "#FF9F1C",
		bonusCount = 4,
		baseMul = 1.40,
		rangeMul = 1.5,
		legendaryBonus = true,
		sellMul = 1.40,
	},
	{
		id = 6,
		key = "unique",
		nameKey = "rarity.unique",
		color = "#E8C25A",
		bonusCount = 0,
		baseMul = 1.0,
		rangeMul = 1.0,
		legendaryBonus = false,
		sellMul = 1.5,
	},
}

local COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, UNIQUE = 1, 2, 3, 4, 5, 6

-- Rarity weights per monster variant (DESIGN §5.5). Weights, not percentages.
local DROP_WEIGHTS: { [string]: { [number]: number } } = {
	normal = { [COMMON] = 72, [UNCOMMON] = 20, [RARE] = 6.5, [EPIC] = 1.4, [LEGENDARY] = 0.1 },
	elite = { [COMMON] = 45, [UNCOMMON] = 30, [RARE] = 17, [EPIC] = 7, [LEGENDARY] = 1 },
	elite2 = { [COMMON] = 20, [UNCOMMON] = 30, [RARE] = 30, [EPIC] = 15, [LEGENDARY] = 5 },
	boss = { [UNCOMMON] = 10, [RARE] = 35, [EPIC] = 38, [LEGENDARY] = 17 },
}

-- Chance that a kill drops an item at all, and how many (DESIGN §5.5). Drop bonus multiplies `chance`.
-- Raised after the S17 tests: normal 20 %, elite 75 % (+25 % for a second), Elite II 2-3 items.
local ITEM_DROPS: { [string]: { chance: number, min: number, max: number, extra: number? } } = {
	normal = { chance = 0.20, min = 1, max = 1 },
	elite = { chance = 0.75, min = 1, max = 1, extra = 0.25 },
	elite2 = { chance = 1.0, min = 2, max = 3 },
	boss = { chance = 1.0, min = 3, max = 4 },
}

return table.freeze({
	list = LIST,
	get = function(id: number): RarityDef?
		return LIST[id]
	end,
	COMMON = COMMON,
	UNCOMMON = UNCOMMON,
	RARE = RARE,
	EPIC = EPIC,
	LEGENDARY = LEGENDARY,
	UNIQUE = UNIQUE,
	dropWeights = DROP_WEIGHTS,
	itemDrops = ITEM_DROPS,
	bossUniqueChance = 0.25,
	-- Each upgrade level adds this share of the item's base stats (DESIGN §6: +6 % per level, +9 = +54 %).
	upgradeStatPerLevel = 0.06,
})
