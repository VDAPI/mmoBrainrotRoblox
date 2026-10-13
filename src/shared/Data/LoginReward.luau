--!strict
-- Daily login reward (DESIGN-15 §5, S100): a 7-day streak per account in UTC days; the character that claims the
-- day gets it, scaled by its level. Pure data; Logic/LoginReward builds the contents and rolls the day 7 chest.
-- Balance numbers: tools/balance_reasons.luau (BALANCE_MODULES), targets in tests/balance.spec.luau ("Login reward").

export type DayDef = {
	gold: number?, -- multiple of the gold unit (gold.base + gold.perLevel x level)
	potions: number?, -- multiple of the potion count of the quality (HP + the class resource)
	essence: number?, -- multiple of the essence count of the level band
	stones: number?, -- Return Stones
	blessing: number?, -- blessing rarity (1 Common, 2 Unique) of the class line
	chest: boolean?, -- day 7: one Unique / Heroic item for the level and class
}
export type PotionBand = { from: number, quality: number, n: number }
-- `item`, not `id`: two bands hold shards (the ledger dump keys records by `id`)
export type EssenceBand = { from: number, item: string, n: number }

local DAYS: { DayDef } = {
	{ gold = 1, stones = 2 }, -- 1
	{ potions = 1 }, -- 2
	{ gold = 1, essence = 1 }, -- 3
	{ blessing = 1, stones = 1 }, -- 4
	{ gold = 1.5, potions = 1 }, -- 5
	{ gold = 1, essence = 1 }, -- 6
	{ gold = 1.5, blessing = 2, chest = true }, -- 7: the chest (DESIGN-15 §5: up to Heroic + a Unique blessing)
}

-- Potion quality by character level (the highest band with from <= level whose potion the level may drink,
-- Logic/Potions.canDrink, S87) and potions of each kind for potions = 1. Great potions (700) from 70: from 60 day 5
-- of a Mage passed 0.12 h of income (G3); no Mighty potions (1800).
local POTION_BANDS: { PotionBand } = {
	{ from = 1, quality = 1, n = 5 },
	{ from = 12, quality = 2, n = 3 },
	{ from = 35, quality = 3, n = 1 },
	{ from = 70, quality = 4, n = 1 },
}

-- Essence by level: dust (+1..+3) up to 19, shards (+4..+6) from 20. No crystals: one crystal is worth ~3 900 gold
-- (transmuted, the S84 material prices), alone ~0.25 h of income at 45 against the 0.12 h day cap (G3).
local ESSENCE_BANDS: { EssenceBand } = {
	{ from = 1, item = "essence_dust", n = 3 },
	{ from = 20, item = "essence_shard", n = 1 },
	{ from = 45, item = "essence_shard", n = 2 },
}

return table.freeze({
	DAYS = 7,
	-- Gold unit at level L: base + perLevel x L, rounded to 5. A daily contract pays 50 + 30 x L (Quests/Daily).
	gold = table.freeze({ base = 10, perLevel = 8, round = 5 }),
	days = table.freeze(DAYS),
	potionBands = table.freeze(POTION_BANDS),
	essenceBands = table.freeze(ESSENCE_BANDS),
	-- Blessing line of each class (never "fortune": the login reward gives no EXP bonus, DESIGN-15 §3.2 pace).
	classLine = table.freeze({ Warrior = "warrior", Hunter = "hunter", Mage = "sage", Cleric = "guardian" }),
	chest = table.freeze({
		-- Rarities.UNIQUE / HEROIC weights (numeric keys: Data stays free of Data/Rarities for two constants). 0.15
		-- Heroics a week = 4.3% of the D5 floor over 7 h of play (0.5 / h; T-LR5 <= 5%; 35% would be 10%).
		rarity = table.freeze({ [2] = 85, [3] = 15 }),
		bound = true, -- bound to the character (no alt-account farming for the market)
	}),
})
