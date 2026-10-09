--!strict
-- Monetisation (DESIGN §21), without pay-to-win: Dragon Shard packs and the instant respawn are Developer
-- Products, four Gamepasses, and the premium shop that sells services for shards.
--
-- IDs ARE PLACEHOLDERS (0). The owner creates the products and passes in the Creator Hub
-- (Monetization -> Developer Products / Passes) and pastes the ids here. With id 0 (or in Studio) the
-- purchase is simulated, so everything can be tested without real Robux.

export type ShardPack = { key: string, productId: number, shards: number, robux: number }
export type Pass = { key: string, passId: number, robux: number, icon: string }
export type ShopEntry = {
	key: string,
	kind: "item" | "rename",
	itemId: string?,
	price: number, -- Dragon Shards
	dailyLimit: number?, -- per account and UTC day
}

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
	{ key = "scroll_oblivion", kind = "item", itemId = "scroll_oblivion", price = 120 },
	{ key = "scroll_skillreset", kind = "item", itemId = "scroll_skillreset", price = 120 },
	{ key = "scroll_unbind", kind = "item", itemId = "scroll_unbind", price = 150 },
	{ key = "scroll_protection", kind = "item", itemId = "scroll_protection", price = 60, dailyLimit = 5 },
	{ key = "rename", kind = "rename", price = 400 },
	-- 2026-10-10: big backpacks without the level requirement.
	{ key = "backpack_premium_100", kind = "item", itemId = "backpack_premium_100", price = 300 },
	{ key = "backpack_premium_150", kind = "item", itemId = "backpack_premium_150", price = 600 },
	{ key = "backpack_premium_200", kind = "item", itemId = "backpack_premium_200", price = 1000 },
}

local packByKey: { [string]: ShardPack } = {}
for _, pack in SHARD_PACKS do
	packByKey[pack.key] = pack
end
local passByKey: { [string]: Pass } = {}
for _, pass in PASSES do
	passByKey[pass.key] = pass
end
local shopByKey: { [string]: ShopEntry } = {}
for _, entry in SHOP do
	shopByKey[entry.key] = entry
end

return table.freeze({
	shardPacks = SHARD_PACKS,
	respawn = RESPAWN_PRODUCT,
	passes = PASSES,
	shop = SHOP,
	getPack = function(key: string): ShardPack?
		return packByKey[key]
	end,
	getPass = function(key: string): Pass?
		return passByKey[key]
	end,
	getShop = function(key: string): ShopEntry?
		return shopByKey[key]
	end,
	VAULT_PASS_SLOTS = 60,
	AUTO_LOOT_RANGE = 15,
})
