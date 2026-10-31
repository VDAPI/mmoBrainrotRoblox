--!strict
-- Item binding (owner 2026-10-31: "not everything should be bound, some items only once equipped", docs/DESIGN.md
-- §5.6): which items bind and when. Pure data; the rules in Logic/Binding, the table for the owner in the project
-- files (wyglad/WIAZANIE-PRZEDMIOTOW.md). Three rules:
--   "none"   never binds: trade, the auction house, mail and the guild vault take it
--   "equip"  free until it is first equipped, then bound to the character (bind on equip)
--   "pickup" bound from the moment it comes (bind on pickup)
-- A bound item still goes into the account deposit (to another character of the account), to a merchant (unless
-- noSell / ns) and can be destroyed; a Scroll of Unbinding frees bound equipment. The strongest rule wins: the
-- item definition (`bind`, else its category), the rarity (Data/Rarities bindOnPickup: Mythic) and the source.

export type Rule = "none" | "equip" | "pickup"
-- Where an item comes from (Logic/Binding.apply); every item grant of the server names one.
export type Source = "drop" | "craft" | "gold" | "boss" | "quest" | "reward" | "currency" | "shop" | "premium"
-- What a source adds: `gear` for equipment and backpacks, `goods` for materials and tools, `consumable` for what is
-- used up (potions, elixirs, blessings, scrolls, stones). nil = the item's own rule.
export type SourceRule = { gear: Rule?, goods: Rule?, consumable: Rule? }

-- The rule of an item by its category; a definition's own `bind` wins (named boss items, premium consumables).
local CATEGORY: { [string]: Rule } = {
	equipment = "equip",
	backpack = "none", -- capacity only, no stats: never binds, worn or not (premium backpacks: the premium source)
	consumable = "none",
	scroll = "none",
	stone = "none",
	material = "none",
	tool = "none",
}

-- Categories the source rules count as `consumable`; every other stack category is `goods`.
local CONSUMABLE: { [string]: boolean } = { consumable = true, scroll = true, stone = true }

local SOURCES: { [Source]: SourceRule } = {
	-- monsters, Elites, Elite II, the dungeon boss's shared materials, gathering, fishing
	drop = {},
	-- the blacksmith and the alchemist
	craft = {},
	-- bought for gold: the class vendors, the alchemist, the general store, the wandering merchant's gold offers
	gold = {},
	-- the personal roll of a dungeon boss (with Fortune's second item) and of the world boss: the item's own rule,
	-- Unique, Heroic and Legendary on equip (S149), Mythic on pickup by its rarity (owner 2026-10-31: less binding)
	boss = {},
	-- the reward chosen for a side quest: the item's own rule, gear binds on equip (owner 2026-10-31: less binding)
	quest = {},
	-- the login chest, the first drop, event chests (Invasion, Champion), the tutorial reward: gear binds on pickup
	-- (no alt-account farming for the market); potions, stones, blessings and materials stay free
	reward = { gear = "pickup" },
	-- Hunter's Marks and Arena Tokens (earned, never sold): gear and materials bind, consumables stay free
	currency = { gear = "pickup", goods = "pickup" },
	-- the premium shop (Dragon Shards): the item's own rule (owner 2026-10-31: less binding): the scrolls stay free,
	-- the premium backpacks bind on equip, the Full Elixir, the stones and the Transmutation Scroll on pickup
	shop = {},
	-- the Portal Master and the season pass (whose premium track is bought for shards and comes merged with the free
	-- one): everything binds on pickup, as before
	premium = { gear = "pickup", goods = "pickup", consumable = "pickup" },
}

-- Materials a currency shop sells (the Huntmaster's essence for marks): a bound stack of them may be such a purchase,
-- so the migration of old saves leaves it bound (Logic/Binding.migrateItem). Every other bound stack whose own rule is
-- "none" was bound only by the old rules and comes free.
local KEEP_BOUND_TYPES: { [string]: boolean } = { essence = true }

-- Binding version of a mail parcel (Logic/Mail.Parcel.bv): parcels without it were sent before these rules and their
-- stacks go through the migration when claimed.
local VERSION = 1

return table.freeze({
	CATEGORY = table.freeze(CATEGORY),
	CONSUMABLE = table.freeze(CONSUMABLE),
	SOURCES = table.freeze(SOURCES),
	KEEP_BOUND_TYPES = table.freeze(KEEP_BOUND_TYPES),
	VERSION = VERSION,
})
