--!strict
-- The wandering merchant (owner 2026-10-20, docs/DESIGN.md §8b): Radoslav's caravan comes every `interval` seconds for
-- `duration` seconds to one place of `spots` (a city square or a respawn camp of a region), the same on every server
-- (Logic/WanderingMerchant: the visit and its stock are seeded from the visit number of the UTC clock, no messages
-- between servers). He sells a few rare things that reroll every visit: equipment of the region's levels (Unique /
-- Heroic for gold, rarely a Legendary for Hunter's Marks, never Mythic), rare materials, one caravan dye (an
-- account cosmetic for gold) and consumables. Every offer has a per-character limit per visit; whatever he sells is
-- bound and never sold back for gold (no gold or mark laundering). No Robux, no Dragon Shards.
-- Balance numbers: tools/balance_reasons.luau (BALANCE_MODULES, session S159w); the checks in
-- tests/wanderingmerchant.spec.luau.

export type Currency = "gold" | "marks"
export type Kind =
	"gear" -- `slot` = Data/LootTables.bossSlots slot: an item of that slot for the buyer's class (Logic.pickGear)
	| "item" -- `id` = Data/Items id, `n` per purchase
	| "potion" -- `id` = "hp" | "resource": `n` potions of the quality the level gets (Logic/LoginReward.potionQuality)
	| "blessing" -- `id` = Data/Blessings line picked for the visit, `rarity` its rarity
	| "dye" -- `id` = Data/Cosmetics id (obtain.merchant)
export type Group = "gear" | "material" | "dye" | "consumable"

-- One offer of a visit's stock (Logic/WanderingMerchant.stock). `key` is unique within the visit.
export type Offer = {
	key: string,
	kind: Kind,
	group: Group,
	id: string?,
	slot: string?,
	rarity: number?,
	n: number,
	currency: Currency,
	price: number?, -- fixed price
	perLevel: number?, -- price x the item level (gear: the item's level; others: the buyer's level in the band)
	minLevel: number, -- character level needed
	limit: number, -- purchases per character per visit
}

-- A pool entry the stock draws from (materials and consumables): `weight` = chance to be drawn, `minLevel` = the
-- character level needed (an entry is drawn only where the band reaches it).
export type PoolEntry = {
	key: string,
	kind: Kind,
	id: string,
	n: number,
	currency: Currency,
	price: number?,
	perLevel: number?,
	minLevel: number,
	limit: number,
	weight: number,
	rarity: number?, -- blessings
}

-- A place of the caravan (map-relative studs): the merchant stands at (x, z) facing `facing` degrees (front = (-sin,
-- -cos) like the city plan), the wagon `behind` studs behind his back. City squares: open ground off the streets and
-- NPCs (tests/wanderingmerchant.spec, Logic/TownTerrain.isOpen); regions: 10 studs south of a respawn point, inside
-- its no-monster circle (Data/Areas avoid).
export type Spot = { id: string, map: string, x: number, z: number, facing: number }

local function spot(id: string, map: string, x: number, z: number, facing: number): Spot
	return table.freeze({ id = id, map = map, x = x, z = z, facing = facing })
end

local SPOTS: { Spot } = {
	-- the city (levels 1-100): the market square and the squares by the gates
	spot("rynek", "city", 8, -48, 180),
	spot("placPolnocny", "city", 52, -276, 180),
	spot("placZachodni", "city", -268, 52, 90),
	spot("placPoludniowy", "city", -28, 272, 0),
	spot("placSwiatynny", "city", -72, -120, 0),
	-- the regions: by the respawn camps (Data/Terrain respawns, the Meadows' in Data/Terrain/meadows flats)
	spot("meadowsGate", "meadows", -700, 40, 0),
	spot("meadowsTrail", "meadows", 120, 310, 0),
	spot("meadowsDiggings", "meadows", 395, -140, 0),
	spot("duskwoodGate", "duskwood", -700, 62, 0),
	spot("duskwoodMarsh", "duskwood", 112, 94, 0),
	spot("duskwoodCrossroads", "duskwood", 400, -252, 0),
	spot("ashenGate", "ashen", -700, 62, 0),
	spot("ashenOasis", "ashen", -110, 40, 0),
	spot("ashenCamp", "ashen", 296, 260, 0),
	spot("frostpeakGate", "frostpeak", -700, 66, 0),
	spot("frostpeakPass", "frostpeak", -130, 50, 0),
	spot("frostpeakHold", "frostpeak", 430, 54, 0),
}

-- Level bands of the maps (the same as Data/Maps minLevel / maxLevel, tests/wanderingmerchant.spec): the gear's item
-- level is the buyer's level clamped into the band, and a pool entry is drawn only where the band reaches its level.
local BANDS: { [string]: { number } } = {
	city = { 1, 100 },
	meadows = { 1, 20 },
	duskwood = { 20, 45 },
	ashen = { 45, 70 },
	frostpeak = { 70, 100 },
}

-- Chance of each map to get the visit (then a spot of the map, uniform); never the same spot twice in a row.
local MAP_WEIGHTS: { [string]: number } = { city = 2, meadows = 1, duskwood = 1, ashen = 1, frostpeak = 1 }

-- Materials (2 a visit, different): rare essences, ores, herbs and fish. Gold ~3-4x their merchant value; the
-- essences 1 a visit (the upgrade path stays on the loot and the Huntmaster's weekly limits, Data/HuntShop).
local MATERIALS: { PoolEntry } = {
	{
		key = "mat_dust",
		kind = "item",
		id = "essence_dust",
		n = 20,
		currency = "gold",
		price = 600,
		minLevel = 1,
		limit = 1,
		weight = 3,
	},
	{
		key = "mat_shard",
		kind = "item",
		id = "essence_shard",
		n = 5,
		currency = "gold",
		price = 1200,
		minLevel = 20,
		limit = 1,
		weight = 3,
	},
	{
		key = "mat_crystal",
		kind = "item",
		id = "essence_crystal",
		n = 1,
		currency = "gold",
		price = 1500,
		minLevel = 45,
		limit = 1,
		weight = 2,
	},
	{
		key = "mat_core",
		kind = "item",
		id = "legend_core",
		n = 1,
		currency = "marks",
		price = 150,
		minLevel = 60,
		limit = 1,
		weight = 1,
	},
	{
		key = "mat_moonpetal",
		kind = "item",
		id = "herb_moonpetal",
		n = 3,
		currency = "gold",
		price = 1200,
		minLevel = 30,
		limit = 2,
		weight = 2,
	},
	{
		key = "mat_goldfin",
		kind = "item",
		id = "fish_goldfin",
		n = 2,
		currency = "gold",
		price = 2000,
		minLevel = 30,
		limit = 2,
		weight = 1,
	},
	{
		key = "mat_silver",
		kind = "item",
		id = "ore_silver",
		n = 10,
		currency = "gold",
		price = 1200,
		minLevel = 45,
		limit = 2,
		weight = 2,
	},
	{
		key = "mat_mithril",
		kind = "item",
		id = "ore_mithril",
		n = 10,
		currency = "gold",
		price = 2800,
		minLevel = 70,
		limit = 2,
		weight = 2,
	},
	{
		key = "mat_adamantite",
		kind = "item",
		id = "ore_adamantite",
		n = 5,
		currency = "gold",
		price = 2800,
		minLevel = 90,
		limit = 2,
		weight = 1,
	},
}

-- Consumables (3 a visit, different). Potions: 10 of the level's quality at 80 % of the alchemist's price
-- (`price` = the share, Logic.priceOf); a blessing of a line picked for the visit (Heroic, 30 min); stones; rarely a
-- Scroll of Protection (otherwise only from bosses and Elites).
local CONSUMABLES: { PoolEntry } = {
	{
		key = "con_potion_hp",
		kind = "potion",
		id = "hp",
		n = 10,
		currency = "gold",
		price = 0.8,
		minLevel = 1,
		limit = 3,
		weight = 3,
	},
	{
		key = "con_potion_resource",
		kind = "potion",
		id = "resource",
		n = 10,
		currency = "gold",
		price = 0.8,
		minLevel = 1,
		limit = 3,
		weight = 3,
	},
	{
		key = "con_blessing",
		kind = "blessing",
		id = "line",
		n = 1,
		currency = "gold",
		perLevel = 60,
		minLevel = 20,
		limit = 2,
		weight = 3,
		rarity = 3,
	},
	{
		key = "con_stone_map",
		kind = "item",
		id = "stone_map",
		n = 3,
		currency = "gold",
		price = 480,
		minLevel = 1,
		limit = 2,
		weight = 2,
	},
	{
		key = "con_stone_dungeon",
		kind = "item",
		id = "stone_dungeon",
		n = 1,
		currency = "gold",
		price = 450,
		minLevel = 10,
		limit = 2,
		weight = 2,
	},
	{
		key = "con_protection",
		kind = "item",
		id = "scroll_protection",
		n = 1,
		currency = "gold",
		perLevel = 400,
		minLevel = 20,
		limit = 1,
		weight = 1,
	},
}

local GROUPS: { Group } = { "gear", "material", "dye", "consumable" }

export type GearPrice = { currency: Currency, perLevel: number?, price: number? }
-- by rarity: gold = perLevel x item level (about 120 / 360 normal kills of that level, Combat.goldPerLevel 3), the
-- Legendary for Hunter's Marks only (the Huntmaster's Heroic chest is 200)
local GEAR_PRICES: { [number]: GearPrice } = {
	[2] = { currency = "gold", perLevel = 360 },
	[3] = { currency = "gold", perLevel = 1080 },
	[4] = { currency = "marks", price = 400 },
}

return table.freeze({
	-- the clock (UTC): a visit starts at offset + k x interval and lasts `duration`
	schedule = table.freeze({
		interval = 3 * 3600, -- every 3 h
		offset = 5400, -- 01:30, 04:30, ..., 22:30 UTC: off the full hours of the other events
		duration = 45 * 60, -- 45 min
		warn = table.freeze({ 600, 60 }), -- announcements before the arrival (seconds, descending)
		leaving = 300, -- "he packs up" this many seconds before the end
		salt = 4111, -- moves the seed away from other seeded rolls
	}),
	npc = "wanderer", -- Data/Npcs id (Npcs.WANDERER, outside Npcs.list: it has no fixed place)
	spots = table.freeze(SPOTS),
	bands = table.freeze(BANDS),
	mapWeights = table.freeze(MAP_WEIGHTS),
	-- the tab order of the window
	groups = table.freeze(GROUPS),
	gear = table.freeze({
		count = 3, -- offers a visit, different slots (weights of Data/LootTables.bossSlots)
		-- Rarities.UNIQUE / HEROIC / LEGENDARY; never Mythic (tests/wanderingmerchant.spec)
		rarity = table.freeze({ [2] = 70, [3] = 27, [4] = 3 }) :: { [number]: number },
		-- price by rarity (GEAR_PRICES)
		price = table.freeze(GEAR_PRICES),
		limit = 1, -- the character needs the band's bottom level (the item level is never above the buyer's)
	}),
	materials = table.freeze(MATERIALS),
	materialCount = 2,
	consumables = table.freeze(CONSUMABLES),
	consumableCount = 3,
	-- one caravan dye a visit (Data/Cosmetics obtain.merchant), account-wide, for gold
	dyes = table.freeze({ "dye_caravan_saffron", "dye_caravan_plum", "dye_caravan_teal", "dye_caravan_rust" }),
	dyePrice = 12000,
	blessingLines = table.freeze({ "warrior", "hunter", "sage", "guardian", "fortune" }),
	-- the caravan's look (WanderingMerchantService; looks, not balance)
	look = table.freeze({
		behind = 7, -- studs from the merchant to the wagon's centre
		canvas = "#D8A43A",
		canvas2 = "#7A3E5A",
		wood = "#5A3E26",
		mule = "#7A6A5A",
	}),
})
