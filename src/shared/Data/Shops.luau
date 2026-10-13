--!strict
-- Shop assortments (DESIGN §9, §13, §18). Prices come from Logic/ItemValue.buyPrice (S31): the entry's
-- fixed `price`, else the item's fixed `buyPrice`, else value x `buyMul`; `pricePerLevel` makes the price
-- depend on the buyer's level (teacher's Oblivion scroll). Every shop buys player items (for their value).

local Bases = require("./Items/Bases")
local Elements = require("./Elements")
local Rarities = require("./Rarities")

export type Entry = {
	item: string,
	price: number?, -- fixed price (overrides the item's buyPrice and value x buyMul)
	pricePerLevel: number?, -- price = pricePerLevel x character level
	-- Equipment sold at a fixed item level (class vendors, S18 / S95): common, no bonuses.
	key: string?, -- unique id of the entry when one item is sold several ways (elements); default `item`
	ilvl: number?,
	rarity: number?, -- rarity of the sold equipment (class vendors: Common)
	el: string?, -- element of a mage weapon
	level: number?, -- character level needed to buy
	classes: { string }?, -- classes that can use it (S95: only they can buy it, Logic/ShopPrice.usableBy)
	needsPaths: boolean?, -- S57: sold only to classes that have paths in Data/Paths (Logic/ShopPrice.offered)
}

export type ShopDef = {
	id: string,
	entries: { Entry },
	class: string?, -- class vendor (S95): the class whose gear this shop sells; nil for every other shop
	buyMul: number?, -- price = value x buyMul for entries without a fixed price (default Data/ItemValue.buyMul)
}

-- Tiers of the class vendors (name kept for the wiki key `weaponsmithTiers` and tests/balance.spec `shopTier`):
-- 5, 15, ..., 95 (tier 1 is the starting gear).
local WEAPONSMITH_TIERS: { number } = { 5, 15, 25, 35, 45, 55, 65, 75, 85, 95 }

-- Row order of a class vendor inside one tier.
local VENDOR_SLOTS: { string } = { "weapon", "offhand", "helmet", "armor", "gloves", "boots" }

-- S95 DESIGN-15 §1: every base the class can wear in the weapon, off-hand and armour slots, at tiers 5..95, Common,
-- ilvl = level = tier; mage weapons once per element. Price value x buyMul.
local function classVendor(classId: string): { Entry }
	local list = {}
	for _, tier in WEAPONSMITH_TIERS do
		for _, slot in VENDOR_SLOTS do
			for _, base in Bases.list do
				if base.slot ~= slot or not base.classes or not table.find(base.classes, classId) then
					continue
				end
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
			-- S94: the Frost Peaks' ores (~4 x their Materials price, like copper, iron and silver)
			{ item = "ore_mithril", price = 320, level = 70 },
			{ item = "ore_adamantite", price = 640, level = 90 },
		},
	},
	-- S95 (DESIGN-15 §1): one gear vendor per class (replaces the shared weaponsmith) and the dealer who only buys
	-- and sells back (buyback).
	vendor_warrior = { id = "vendor_warrior", class = "Warrior", entries = classVendor("Warrior") },
	vendor_cleric = { id = "vendor_cleric", class = "Cleric", entries = classVendor("Cleric") },
	vendor_hunter = { id = "vendor_hunter", class = "Hunter", entries = classVendor("Hunter") },
	vendor_mage = { id = "vendor_mage", class = "Mage", entries = classVendor("Mage") },
	fence = { id = "fence", entries = {} },
	-- S27: tools sold where they are needed (Wit by Toad Pond, Dobromir at the Old Quarry).
	fisher = { id = "fisher", entries = { { item = "fishing_rod" }, { item = "potion_hp_1" } } },
	miner = { id = "miner", entries = { { item = "pickaxe" }, { item = "potion_hp_2" } } },
	teacher = {
		id = "teacher",
		entries = {
			{ item = "scroll_oblivion", pricePerLevel = 500 }, -- DESIGN §4.3
			-- S57 (ROZWOJ 2.10): Scroll of a New Path, only for classes with paths
			{ item = "scroll_skillreset", pricePerLevel = 400, level = 20, needsPaths = true },
		},
	},
}

-- S95: class id -> its vendor's shop (and NPC) id.
local CLASS_VENDORS: { [string]: string } = {}
for id, shop in SHOPS do
	if shop.class then
		CLASS_VENDORS[shop.class] = id
	end
end

return table.freeze({
	byId = SHOPS,
	get = function(id: string): ShopDef?
		return SHOPS[id]
	end,
	BUYBACK_SIZE = 10,
	WEAPONSMITH_TIERS = table.freeze(WEAPONSMITH_TIERS),
	VENDOR_SLOTS = table.freeze(VENDOR_SLOTS),
	CLASS_VENDORS = table.freeze(CLASS_VENDORS),
	-- The shop (and NPC) id of the vendor who sells gear for `classId`; nil without a class or for an unknown one.
	vendorOf = function(classId: string?): string?
		return if classId then CLASS_VENDORS[classId] else nil
	end,
})
