--!strict
-- Monetisation (DESIGN §21), without pay-to-win: Dragon Shard packs and the instant respawn are Developer
-- Products, four Gamepasses, and the premium shop that sells services for shards.
--
-- IDs ARE PLACEHOLDERS (0). The owner creates the products and passes in the Creator Hub
-- (Monetization -> Developer Products / Passes) and pastes the ids here. With id 0 (or in Studio) the
-- purchase is simulated, so everything can be tested without real Robux.
-- S120: every shop entry has a `cat` (tab section) and optional daily / weekly limits; Logic/Premium.canBuy is the
-- only purchase rule (shop window and server).

export type ShardPack = { key: string, productId: number, shards: number, robux: number }
export type Pass = { key: string, passId: number, robux: number, icon: string }
export type ShopCat = "scroll" | "service" | "consumable" | "backpack"
export type ShopEntry = {
	key: string,
	kind: "item" | "rename", -- how the server grants it (S122 adds its own kinds)
	cat: ShopCat, -- the section of the "Items" tab (DESIGN-17 §1)
	itemId: string?,
	price: number, -- Dragon Shards
	dailyLimit: number?, -- purchases per account and UTC day
	weeklyLimit: number?, -- purchases per account and week (Monday 00:00 UTC, Logic/Time.weekNumber)
	unavailable: boolean?, -- listed but not for sale yet: the shop shows "Soon", the server refuses
}
-- S97: a premium mount (Developer Product, granted to the active character; Data/Mounts entry with source "premium").
export type MountProduct = { key: string, productId: number, robux: number, mount: string, enabled: boolean }

local SHARD_PACKS: { ShardPack } = {
	{ key = "shards_100", productId = 0, shards = 100, robux = 99 },
	{ key = "shards_550", productId = 0, shards = 550, robux = 499 },
	{ key = "shards_1200", productId = 0, shards = 1200, robux = 999 },
	{ key = "shards_2600", productId = 0, shards = 2600, robux = 1999 },
	{ key = "shards_7000", productId = 0, shards = 7000, robux = 4999 },
}

-- Instant respawn bought with Robux on the death screen (the shard price is Config.RespawnNowCost).
local RESPAWN_PRODUCT = { key = "respawn", productId = 0, robux = 15 }

local PASSES: { Pass } = {
	{ key = "autoLoot", passId = 0, robux = 199, icon = "✋" },
	{ key = "vault", passId = 0, robux = 149, icon = "▤" },
	{ key = "fastRespawn", passId = 0, robux = 99, icon = "⟲" },
	{ key = "vip", passId = 0, robux = 399, icon = "★" },
}

local SHOP: { ShopEntry } = {
	{ key = "scroll_oblivion", kind = "item", cat = "scroll", itemId = "scroll_oblivion", price = 120 },
	{ key = "scroll_skillreset", kind = "item", cat = "scroll", itemId = "scroll_skillreset", price = 120 },
	{ key = "scroll_unbind", kind = "item", cat = "scroll", itemId = "scroll_unbind", price = 150 },
	-- S120: 1 a day (DESIGN-17 §1): the only item that touches item power, see tests/paywall.spec.luau
	{
		key = "scroll_protection",
		kind = "item",
		cat = "scroll",
		itemId = "scroll_protection",
		price = 60,
		dailyLimit = 1,
	},
	{ key = "rename", kind = "rename", cat = "service", price = 400 },
	-- 2026-10-10: big backpacks without the level requirement.
	{ key = "backpack_premium_100", kind = "item", cat = "backpack", itemId = "backpack_premium_100", price = 300 },
	{ key = "backpack_premium_150", kind = "item", cat = "backpack", itemId = "backpack_premium_150", price = 600 },
	{ key = "backpack_premium_200", kind = "item", cat = "backpack", itemId = "backpack_premium_200", price = 1000 },
}

-- S97: disabled until the owner decides (price in Robux, product id from the Creator Hub). Same speed cap as every
-- mount (no pay2win): startLevel in Data/Mounts. Disabled = not sold (MonetizationService refuses even in Studio), not
-- shown in the premium shop (Logic/Premium.mountOffers) and never on the wiki.
local MOUNTS: { MountProduct } = {
	{ key = "mount_royal", productId = 0, robux = 0, mount = "mount_royal", enabled = false },
}

local packByKey: { [string]: ShardPack } = {}
for _, pack in SHARD_PACKS do
	packByKey[pack.key] = pack
end
local passByKey: { [string]: Pass } = {}
for _, pass in PASSES do
	passByKey[pass.key] = pass
end
-- Sections of the "Items" tab in order (S120; `consumable` stays empty until S122).
local SHOP_CATS: { ShopCat } = { "scroll", "service", "consumable", "backpack" }

local shopByKey: { [string]: ShopEntry } = {}
local shopByCat: { [string]: { ShopEntry } } = {}
for _, cat in SHOP_CATS do
	shopByCat[cat] = {}
end
for _, entry in SHOP do
	shopByKey[entry.key] = entry
	table.insert(shopByCat[entry.cat], entry)
end
local mountByKey: { [string]: MountProduct } = {}
for _, entry in MOUNTS do
	mountByKey[entry.key] = entry
end

return table.freeze({
	shardPacks = SHARD_PACKS,
	respawn = RESPAWN_PRODUCT,
	passes = PASSES,
	shop = SHOP,
	shopCats = SHOP_CATS,
	mounts = MOUNTS,
	getPack = function(key: string): ShardPack?
		return packByKey[key]
	end,
	getPass = function(key: string): Pass?
		return passByKey[key]
	end,
	getShop = function(key: string): ShopEntry?
		return shopByKey[key]
	end,
	-- S120: the entries of one section in list order.
	shopIn = function(cat: ShopCat): { ShopEntry }
		return shopByCat[cat] or {}
	end,
	getMount = function(key: string): MountProduct?
		return mountByKey[key]
	end,
	VAULT_PASS_SLOTS = 60,
	AUTO_LOOT_RANGE = 15,
})
