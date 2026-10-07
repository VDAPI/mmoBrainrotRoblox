--!strict
-- Shop assortments (DESIGN §9, §13, §18). Prices default to the item's `buyPrice`; `pricePerLevel` makes
-- the price depend on the buyer's level (teacher's reset scrolls). Every shop buys player items.

local Bases = require("./Items/Bases")
local Elements = require("./Elements")

export type Entry = {
	item: string,
	price: number?, -- overrides the item's buyPrice
	pricePerLevel: number?, -- price = pricePerLevel x character level
	-- Equipment sold at a fixed item level (weaponsmith, S18): common, no bonuses.
	key: string?, -- unique id of the entry when one item is sold several ways (elements); default `item`
	ilvl: number?,
	el: string?, -- element of a mage weapon
	level: number?, -- character level needed to buy
	classes: { string }?, -- classes that can use it (class tabs)
}

export type ShopDef = {
	id: string,
	entries: { Entry },
	classTabs: boolean?, -- the window shows class tabs and tiers up to the player's level + 5
}

-- Weaponsmith (S18, DESIGN §8a): every weapon and off-hand base at every tier, common, ilvl = tier, mage
-- weapons once per element. Price about 4x the sell price of the tier.
local WEAPONSMITH_PRICE_FACTOR = 4

local function weaponsmith(): { Entry }
	local list = {}
	for _, base in Bases.list do
		if base.slot ~= "weapon" and base.slot ~= "offhand" then
			continue
		end
		for _, tier in Bases.tiers do
			local item = `{base.type}_{tier}`
			local price = Bases.priceAt(tier) * WEAPONSMITH_PRICE_FACTOR
			local elements: { string? } = if base.elemental then Elements.WEAPON :: any else { false :: any }
			for _, el in elements do
				local element = if el then el :: string else nil
				table.insert(list, {
					item = item,
					key = if element then `{item}:{element}` else item,
					ilvl = tier,
					el = element,
					level = tier,
					classes = base.classes,
					price = price,
				})
			end
		end
	end
	return list
end

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
	weaponsmith = { id = "weaponsmith", entries = weaponsmith(), classTabs = true },
	-- S27: tools sold where they are needed (Wit by Toad Pond, Dobromir at the Old Quarry).
	fisher = { id = "fisher", entries = { { item = "fishing_rod" }, { item = "potion_hp_1" } } },
	miner = { id = "miner", entries = { { item = "pickaxe" }, { item = "potion_hp_2" } } },
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
