--!strict
-- Monetisation (DESIGN §21), without pay-to-win: Dragon Shard packs (and starter packs) are Developer
-- Products, Gamepasses, the VIP subscription (S121) and the premium shop that sells services for shards.
--
-- IDs ARE PLACEHOLDERS (0). The owner creates the products and passes in the Creator Hub
-- (Monetization -> Developer Products / Passes) and pastes the ids here. With id 0 (or in Studio) the
-- purchase is simulated, so everything can be tested without real Robux.
-- S120: every shop entry has a `cat` (tab section) and optional daily / weekly limits; Logic/Premium.canBuy is the
-- only purchase rule (shop window and server).
-- S122: the Elixir of Wholeness (potion_full_*) and the Cloak of Luring (lure_*) are the two explicit exceptions of
-- DESIGN-17 §0.2 (healing outside fights with players and bosses, faster farming without strength), listed with their
-- limits in tests/paywall.spec.luau.
-- S134j: the Stone of Transmutation (reroll_stone) is an exception like the Scroll of Protection (1 a day, only the
-- essence of one bonus reroll, account-bound), see tests/paywall.spec.luau.
-- S134d: Auto Potions (autopotion_*, comfort) and Auto Hunt (hunt_*, the third exception: faster farming without
-- playing, x0.7 EXP and gold, daily cap, never in the weekly ranking), see tests/paywall.spec.luau.

export type ShardPack = { key: string, productId: number, shards: number, robux: number }
export type Pass = {
	key: string,
	passId: number,
	robux: number,
	icon: string,
	-- S121: nil = enabled; false = hidden in the shop and on the wiki, the server refuses the purchase (owners keep it)
	enabled: boolean?,
	-- S121: key of the pass that must be owned first (Character Slot 5 needs Character Slot 4)
	requires: string?,
}
-- S121: Experience Subscription (Creator Hub -> Monetization -> Subscriptions). The price is a Roblox price tier set in
-- the Creator Hub, not here; paste the id (EXP-...) into subscriptionId. Empty id: simulated in Studio, "coming soon" on
-- live servers.
export type Subscription = { key: string, subscriptionId: string, enabled: boolean }
export type ShopCat = "scroll" | "service" | "consumable" | "backpack"
export type ShopEntry = {
	key: string,
	-- how the server grants it (S122: "lure" = Cloak of Luring time; S134d: "autoPotion" = Auto Potions time or forever,
	-- "autoGrind" = Auto Hunt seconds in the bank)
	kind: "item" | "rename" | "lure" | "autoPotion" | "autoGrind",
	cat: ShopCat, -- the section of the "Items" tab (DESIGN-17 §1)
	itemId: string?,
	n: number?, -- S122: stack size of an item entry, default 1 (the price is per pack)
	seconds: number?, -- S122: lure time added by a `lure` entry (real time, account.lure.untilTs); S134d: service time
	permanent: boolean?, -- S134d: an autoPotion entry bought once per account, forever (no `seconds`)
	price: number, -- Dragon Shards
	dailyLimit: number?, -- purchases per account and UTC day
	weeklyLimit: number?, -- purchases per account and week (Monday 00:00 UTC, Logic/Time.weekNumber)
	unavailable: boolean?, -- listed but not for sale yet: the shop shows "Soon", the server refuses
}
-- S97: a premium mount (Developer Product, granted to the active character; Data/Mounts entry with source "premium").
export type MountProduct = { key: string, productId: number, robux: number, mount: string, enabled: boolean }
-- Starter packs (S123, DESIGN-17 §4): Developer Products, once per account (account.packs[key]). Shards,
-- cosmetics only obtainable here (Data/Cosmetics obtain.pack) and passes granted in the profile
-- (account.grantedPasses, honoured by MonetizationService.HasPass). No stats, no gold, no EXP (paywall.spec).
export type StarterPack = {
	key: string,
	productId: number, -- 0 = placeholder (owner pastes the id from the Creator Hub)
	robux: number,
	shards: number,
	cosmetics: { string },
	passes: { string },
	icon: string,
}

local SHARD_PACKS: { ShardPack } = {
	{ key = "shards_100", productId = 0, shards = 100, robux = 99 },
	{ key = "shards_550", productId = 0, shards = 550, robux = 499 },
	{ key = "shards_1200", productId = 0, shards = 1200, robux = 999 },
	{ key = "shards_2600", productId = 0, shards = 2600, robux = 1999 },
	{ key = "shards_7000", productId = 0, shards = 7000, robux = 4999 },
}

-- W28 (owner): the instant respawn is bought only for Dragon Shards (Config.RespawnNowCost, DeathService RespawnNow);
-- the Robux Developer Product "respawn" is gone.

local PASSES: { Pass } = {
	{ key = "autoLoot", passId = 0, robux = 199, icon = "✋" },
	{ key = "vault", passId = 0, robux = 149, icon = "▤" },
	{ key = "fastRespawn", passId = 0, robux = 99, icon = "⟲" },
	-- S121: kept as "VIP forever" (owner decides; it would also grant the daily shards forever). The VIP is the
	-- subscription in SUBSCRIPTIONS.
	{ key = "vip", passId = 0, robux = 399, icon = "★", enabled = false },
	-- S121 (DESIGN-17 §2): comfort passes.
	{ key = "pockets", passId = 0, robux = 249, icon = "▣" }, -- +POCKETS_SLOTS in every backpack
	{ key = "slot4", passId = 0, robux = 99, icon = "♟" }, -- character slot 4 (SLOT_PASSES)
	{ key = "slot5", passId = 0, robux = 149, icon = "♟", requires = "slot4" }, -- character slot 5
	{ key = "wardrobePlus", passId = 0, robux = 79, icon = "♛" }, -- OUTFITS_PLUS saved looks instead of OUTFITS_FREE
}

-- S121: Experience Subscriptions (see the Subscription type).
local SUBSCRIPTIONS: { Subscription } = {
	{ key = "vip", subscriptionId = "", enabled = true },
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
	-- S134j: 1 a day, pays the essence of one bonus reroll (gold always), account-bound; paywall.spec exception
	{
		key = "reroll_stone",
		kind = "item",
		cat = "scroll",
		itemId = "reroll_stone",
		price = 80,
		dailyLimit = 1,
	},
	-- S156 (owner 2026-10-20): 1 a day, rerolls every regular line of one item at the smith (gold x3 of one reroll,
	-- no essence), account-bound; paywall.spec exception
	{
		key = "transmute_scroll",
		kind = "item",
		cat = "scroll",
		itemId = "transmute_scroll",
		price = 240,
		dailyLimit = 1,
	},
	{ key = "rename", kind = "rename", cat = "service", price = 400 },
	-- 2026-10-10: big backpacks without the level requirement.
	{ key = "backpack_premium_100", kind = "item", cat = "backpack", itemId = "backpack_premium_100", price = 300 },
	{ key = "backpack_premium_150", kind = "item", cat = "backpack", itemId = "backpack_premium_150", price = 600 },
	{ key = "backpack_premium_200", kind = "item", cat = "backpack", itemId = "backpack_premium_200", price = 1000 },
	-- S122 (DESIGN-17 §3): Elixir of Wholeness packs (account-bound, 3 min cooldown, 10 a day, Logic/UseBlocks).
	{ key = "potion_full_5", kind = "item", cat = "consumable", itemId = "potion_full", n = 5, price = 120 },
	{ key = "potion_full_20", kind = "item", cat = "consumable", itemId = "potion_full", n = 20, price = 400 },
	-- S122 (DESIGN-17 §3): Cloak of Luring, real time added to account.lure.untilTs (also offline).
	{ key = "lure_1h", kind = "lure", cat = "service", seconds = 3600, price = 150 },
	{ key = "lure_7d", kind = "lure", cat = "service", seconds = 7 * 86400, price = 990 },
	-- S134d: Auto Potions (comfort: the own potions at the thresholds, the same cooldown, never against players):
	-- timed (real time, adds up) or forever (once per account; timed entries are refused after it)
	{ key = "autopotion_1d", kind = "autoPotion", cat = "service", seconds = 86400, price = 60 },
	{ key = "autopotion_7d", kind = "autoPotion", cat = "service", seconds = 7 * 86400, price = 250 },
	{ key = "autopotion_perm", kind = "autoPotion", cat = "service", permanent = true, price = 800 },
	-- S134d (DESIGN-17 §0.2, third exception): Auto Hunt seconds into account.autoGrind.bank (spent only while hunting,
	-- at most Config.AutoGrind.dailySeconds a day, EXP and gold x0.7, outside the weekly ranking)
	{ key = "hunt_1h", kind = "autoGrind", cat = "service", seconds = 3600, price = 100 },
	{ key = "hunt_5h", kind = "autoGrind", cat = "service", seconds = 5 * 3600, price = 420 },
	{ key = "hunt_24h", kind = "autoGrind", cat = "service", seconds = 24 * 3600, price = 1500 },
}

-- S97: disabled until the owner decides (price in Robux, product id from the Creator Hub). Same speed cap as every
-- mount (no pay2win): startLevel in Data/Mounts. Disabled = not sold (MonetizationService refuses even in Studio), not
-- shown in the premium shop (Logic/Premium.mountOffers) and never on the wiki.
local MOUNTS: { MountProduct } = {
	{ key = "mount_royal", productId = 0, robux = 0, mount = "mount_royal", enabled = false },
}

local STARTER_PACKS: { StarterPack } = {
	{
		key = "starter_wanderer",
		productId = 0,
		robux = 199,
		shards = 500,
		cosmetics = { "outfit_wayfarer", "pet_hound" },
		passes = {},
		icon = "✣",
	},
	{
		key = "starter_hero",
		productId = 0,
		robux = 799,
		shards = 2200,
		cosmetics = { "aura_valor" },
		passes = { "pockets" },
		icon = "✠",
	},
}

-- S152 (docs/DESIGN.md §21b): the premium track of the running season pass, bought once per season and account for
-- Dragon Shards (no Robux product of its own: shards are bought in packs). It gives nothing by itself: the rewards of
-- the premium track are won with season points (Logic/Season); never stats, EXP, gold, shards or tiers.
export type SeasonPass = { key: string, price: number }
local SEASON_PASS: SeasonPass = { key = "season_pass", price = 800 }

local packByKey: { [string]: ShardPack } = {}
for _, pack in SHARD_PACKS do
	packByKey[pack.key] = pack
end
local passByKey: { [string]: Pass } = {}
for _, pass in PASSES do
	passByKey[pass.key] = pass
end
-- Sections of the "Items" tab in order (S120; S122 fills `consumable` with the Elixir of Wholeness).
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
local subByKey: { [string]: Subscription } = {}
for _, sub in SUBSCRIPTIONS do
	subByKey[sub.key] = sub
end
local mountByKey: { [string]: MountProduct } = {}
for _, entry in MOUNTS do
	mountByKey[entry.key] = entry
end
local starterByKey: { [string]: StarterPack } = {}
for _, pack in STARTER_PACKS do
	starterByKey[pack.key] = pack
end

return table.freeze({
	shardPacks = SHARD_PACKS,
	passes = PASSES,
	subscriptions = SUBSCRIPTIONS,
	shop = SHOP,
	shopCats = SHOP_CATS,
	mounts = MOUNTS,
	starterPacks = STARTER_PACKS, -- S123
	seasonPass = SEASON_PASS, -- S152
	getPack = function(key: string): ShardPack?
		return packByKey[key]
	end,
	getPass = function(key: string): Pass?
		return passByKey[key]
	end,
	getSubscription = function(key: string): Subscription?
		return subByKey[key]
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
	-- S123
	getStarterPack = function(key: string): StarterPack?
		return starterByKey[key]
	end,
	VAULT_PASS_SLOTS = 60,
	AUTO_LOOT_RANGE = 15,
	-- S121 (DESIGN-17 §2)
	POCKETS_SLOTS = 10, -- Merchant's Pockets: extra slots in every backpack (Logic/Inventory.capacityOf)
	OUTFITS_FREE = 1, -- saved looks without Wardrobe+
	OUTFITS_PLUS = 5, -- saved looks with Wardrobe+
	-- passes needed to CREATE a character on a slot above Config.FreeCharacters (playing one never needs them)
	SLOT_PASSES = table.freeze({ [4] = { "slot4" }, [5] = { "slot4", "slot5" } }) :: { [number]: { string } },
})
