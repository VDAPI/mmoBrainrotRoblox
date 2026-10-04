--!strict
-- Backpacks (DESIGN §5.7): the item in the backpack slot sets the inventory capacity.
-- Sold by the backpack merchant (S06) at these levels and prices.

local Types = require("./Types")

local DEFS: { { capacity: number, level: number, buyPrice: number, color: string } } = {
	{ capacity = 20, level = 1, buyPrice = 0, color = "#B89B5A" },
	{ capacity = 30, level = 1, buyPrice = 300, color = "#9C8A72" },
	{ capacity = 45, level = 8, buyPrice = 2500, color = "#8A6B4A" },
	{ capacity = 60, level = 15, buyPrice = 9000, color = "#6F8F5A" },
	{ capacity = 80, level = 25, buyPrice = 30000, color = "#4A8FE7" },
	{ capacity = 100, level = 35, buyPrice = 80000, color = "#3D6FD6" },
	{ capacity = 130, level = 50, buyPrice = 200000, color = "#B455FF" },
	{ capacity = 160, level = 65, buyPrice = 500000, color = "#FF9F1C" },
	{ capacity = 200, level = 80, buyPrice = 1200000, color = "#E8C25A" },
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
		price = math.floor(def.buyPrice / 4),
		buyPrice = def.buyPrice,
		capacity = def.capacity,
	})
end

return LIST
