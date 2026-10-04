--!strict
-- Blessings (DESIGN §11): 1 hour real-time buffs (counting offline too), one active at a time.
-- 5 lines x 5 rarities. Each blessing is also a consumable item "blessing_<line>_<rarity>".
-- Stats use StatCalc ids; legendary blessings add the special bonus (+10 % EXP and +10 % drop).

export type BlessingDef = {
	id: string, -- "warrior_3"
	line: string,
	rarity: number,
	stats: { [string]: number }, -- flat additions (percent stats in percent points)
	nameKey: string,
	itemId: string,
}

local DURATION = 3600

-- Per line: stats for Common, Uncommon, Rare, Epic, Legendary (DESIGN §11 Warrior line, others analogous).
local LINES: { [string]: { { [string]: number } } } = {
	warrior = {
		{ maxHp = 100, str = 5 },
		{ maxHp = 200, str = 8, atkSpeed = 2 },
		{ maxHp = 350, str = 12, atkSpeed = 4 },
		{ maxHp = 500, str = 16, atkSpeed = 6, critChance = 3 },
		{ maxHp = 800, str = 22, atkSpeed = 8, critChance = 5 },
	},
	hunter = {
		{ maxHp = 100, dex = 5 },
		{ maxHp = 200, dex = 8, critChance = 2 },
		{ maxHp = 350, dex = 12, critChance = 3 },
		{ maxHp = 500, dex = 16, critChance = 4, critDmg = 10 },
		{ maxHp = 800, dex = 22, critChance = 5, critDmg = 15 },
	},
	sage = {
		{ maxMana = 80, int = 5 },
		{ maxMana = 150, int = 8, manaRegen = 2 },
		{ maxMana = 250, int = 12, manaRegen = 3 },
		{ maxMana = 400, int = 16, manaRegen = 5, critChance = 3 },
		{ maxMana = 600, int = 22, manaRegen = 8, critChance = 5 },
	},
	guardian = {
		{ maxHp = 150, vit = 5 },
		{ maxHp = 300, vit = 8, armor = 20 },
		{ maxHp = 500, vit = 12, armor = 40 },
		{ maxHp = 750, vit = 16, armor = 60, mres = 40 },
		{ maxHp = 1100, vit = 22, armor = 90, mres = 60 },
	},
	fortune = {
		{ expBonus = 5, goldBonus = 5 },
		{ expBonus = 8, goldBonus = 8, dropBonus = 3 },
		{ expBonus = 12, goldBonus = 12, dropBonus = 5, maxHp = 100 },
		{ expBonus = 16, goldBonus = 16, dropBonus = 8, maxHp = 200 },
		{ expBonus = 22, goldBonus = 25, dropBonus = 12, maxHp = 300 },
	},
}

local LINE_ORDER = { "warrior", "hunter", "sage", "guardian", "fortune" }

-- Legendary special bonus (DESIGN §11 example).
local LEGENDARY_SPECIAL: { [string]: number } = { expBonus = 10, dropBonus = 10 }

local byId: { [string]: BlessingDef } = {}
local list: { BlessingDef } = {}

for _, line in LINE_ORDER do
	for rarity, base in LINES[line] do
		local stats = table.clone(base)
		if rarity == 5 then
			for stat, value in LEGENDARY_SPECIAL do
				stats[stat] = (stats[stat] or 0) + value
			end
		end
		local def: BlessingDef = {
			id = `{line}_{rarity}`,
			line = line,
			rarity = rarity,
			stats = stats,
			nameKey = `blessing.{line}`,
			itemId = `blessing_{line}_{rarity}`,
		}
		byId[def.id] = def
		table.insert(list, def)
	end
end

return table.freeze({
	byId = byId,
	list = list,
	lines = LINE_ORDER,
	get = function(id: string): BlessingDef?
		return byId[id]
	end,
	DURATION = DURATION,
	-- Resistance elixirs (DESIGN §10): 1 hour, +15 % to one element.
	ELIXIR_DURATION = 3600,
	ELIXIR_VALUE = 15,
	ELIXIRS = { "resFire", "resIce", "resLightning", "resPoison" },
})
