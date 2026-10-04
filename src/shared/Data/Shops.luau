--!strict
-- Shop assortments (DESIGN §9, §13, §18). Prices default to the item's `buyPrice`; `pricePerLevel` makes
-- the price depend on the buyer's level (teacher's reset scrolls). Every shop buys player items.

export type Entry = {
	item: string,
	price: number?, -- overrides the item's buyPrice
	pricePerLevel: number?, -- price = pricePerLevel x character level
}

export type ShopDef = {
	id: string,
	entries: { Entry },
}

local function potions(): { Entry }
	local list = {}
	for _, resource in { "hp", "mana", "energy" } do
		for quality = 1, 5 do
			table.insert(list, { item = `potion_{resource}_{quality}` })
		end
	end
	return list
end

local SHOPS: { [string]: ShopDef } = {
	healer = { id = "healer", entries = potions() },
	merchant = {
		id = "merchant",
		entries = {
			{ item = "stone_return" },
			{ item = "pickaxe" },
			{ item = "fishing_rod" },
			{ item = "essence_dust", price = 40 },
			{ item = "ore_copper", price = 25 },
			{ item = "ore_iron", price = 60 },
			{ item = "potion_hp_1" },
			{ item = "potion_mana_1" },
		},
	},
	blacksmith = {
		id = "blacksmith",
		entries = {
			{ item = "ore_copper", price = 25 },
			{ item = "ore_iron", price = 60 },
			{ item = "ore_silver", price = 140 },
			{ item = "essence_dust", price = 40 },
		},
	},
	teacher = {
		id = "teacher",
		entries = {
			{ item = "scroll_oblivion", pricePerLevel = 500 }, -- DESIGN §4.3
			{ item = "scroll_skillreset", pricePerLevel = 400 },
		},
	},
}

return table.freeze({
	byId = SHOPS,
	get = function(id: string): ShopDef?
		return SHOPS[id]
	end,
	BUYBACK_SIZE = 10,
})
