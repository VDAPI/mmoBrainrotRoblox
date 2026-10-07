--!strict
-- Shop assortments (DESIGN §9, §13, §18). Prices come from Logic/ItemValue.buyPrice (S31): the entry's
-- fixed `price`, else the item's fixed `buyPrice`, else value x `buyMul`; `pricePerLevel` makes the price
-- depend on the buyer's level (teacher's reset scrolls). Every shop buys player items (for their value).

local Bases = require("./Items/Bases")
local Elements = require("./Elements")
local Rarities = require("./Rarities")

export type Entry = {
	item: string,
	price: number?, -- fixed price (overrides the item's buyPrice and value x buyMul)
	pricePerLevel: number?, -- price = pricePerLevel x character level
	-- Equipment sold at a fixed item level (weaponsmith, S18): common, no bonuses.
	key: string?, -- unique id of the entry when one item is sold several ways (elements); default `item`
	ilvl: number?,
	rarity: number?, -- rarity of the sold equipment (weaponsmith: Common)
	el: string?, -- element of a mage weapon
	level: number?, -- character level needed to buy
	classes: { string }?, -- classes that can use it (class tabs)
}

export type ShopDef = {
	id: string,
	entries: { Entry },
	classTabs: boolean?, -- the window shows class tabs grouped by tier (weaponsmith)
	buyMul: number?, -- price = value x buyMul for entries without a fixed price (default Data/ItemValue.buyMul)
}

-- Weaponsmith (S18, S31 DESIGN §8a): every weapon and off-hand base at tiers 5, 15, ..., 95 (tier 1 is the
-- starting gear), Common, ilvl = tier, mage weapons once per element. No fixed price: value x buyMul.
local WEAPONSMITH_TIERS: { number } = { 5, 15, 25, 35, 45, 55, 65, 75, 85, 95 }

local function weaponsmith(): { Entry }
	local list = {}
	for _, base in Bases.list do
		if base.slot ~= "weapon" and base.slot ~= "offhand" then
			continue
		end
		for _, tier in WEAPONSMITH_TIERS do
			local item = `{base.type}_{tier}`
			local elements: { string? } = if base.elemental then Elements.WEAPON :: any else { false :: any }
			for _, el in elements do
				local element = if el then el :: string else nil
				table.insert(list, {
					item = item,
					key = if element then `{item}:{element}` else item,
					ilvl = tier,
					rarity = Rarities.COMMON,
					el = element,
					level = tier,
					classes = base.classes,
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
	WEAPONSMITH_TIERS = table.freeze(WEAPONSMITH_TIERS),
})
