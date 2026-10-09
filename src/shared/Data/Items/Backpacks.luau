--!strict
-- Backpacks (DESIGN §5.7): the item in the backpack slot sets the inventory capacity.
-- Sold by the backpack merchant (S06) at these levels and prices.

local Types = require("./Types")

-- `value` (S31): the starting backpack is not sold (buyPrice 0) but still has a value; the rest are worth 1/4.
local DEFS: { { capacity: number, level: number, buyPrice: number, color: string, value: number? } } = {
	{ capacity = 20, level = 1, buyPrice = 0, color = "#B89B5A", value = 25 },
	{ capacity = 30, level = 1, buyPrice = 300, color = "#9C8A72" },
	-- S32: 45 and 60 slots cheaper (2500 / 9000 was everything a player earns up to level 10 / 18).
	{ capacity = 45, level = 8, buyPrice = 1500, color = "#8A6B4A" },
	{ capacity = 60, level = 15, buyPrice = 5000, color = "#6F8F5A" },
	{ capacity = 80, level = 25, buyPrice = 30000, color = "#4A8FE7" },
	{ capacity = 100, level = 35, buyPrice = 80000, color = "#3D6FD6" },
	{ capacity = 130, level = 50, buyPrice = 200000, color = "#B455FF" },
	{ capacity = 160, level = 65, buyPrice = 500000, color = "#FF9F1C" },
	{ capacity = 200, level = 80, buyPrice = 1200000, color = "#E8C25A" },
}

-- 2026-10-10: backpacks from the premium shop (Data/Products, Dragon Shards): no level requirement, never sold by
-- the backpack merchant (buyPrice 0) nor bought by any merchant (noSell; the value only shows in the tooltip).
local PREMIUM: { { capacity: number, color: string } } = {
	{ capacity = 100, color = "#5FD3C4" },
	{ capacity = 150, color = "#C77BFF" },
	{ capacity = 200, color = "#FF6FAE" },
}

local LIST: { Types.ItemDef } = {}
for _, def in DEFS do
	local id = `backpack_{def.capacity}`
	table.insert(LIST, {
		id = id,
		category = "backpack",
		type = "backpack",
		slot = "backpack",
		level = def.level,
		stackable = false,
		maxStack = 1,
		nameKey = `item.{id}.name`,
		icon = { glyph = "▣", color = def.color },
		price = def.value or math.floor(def.buyPrice / 4),
		buyPrice = def.buyPrice,
		capacity = def.capacity,
	})
end
for _, def in PREMIUM do
	local id = `backpack_premium_{def.capacity}`
	table.insert(LIST, {
		id = id,
		category = "backpack",
		type = "backpack",
		slot = "backpack",
		level = 1,
		stackable = false,
		maxStack = 1,
		nameKey = `item.{id}.name`,
		icon = { glyph = "▣", color = def.color },
		price = def.capacity * 10,
		buyPrice = 0,
		capacity = def.capacity,
		noSell = true,
	})
end

return LIST
