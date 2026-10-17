--!strict
-- The Huntmaster's shop (S134k, DESIGN-15 §3.3): what Hunter's Marks (character.quests.contract.marks, paid by the
-- hunting contracts, Logic/Contracts.marksFor) buy at the Huntmaster by the contract board. Rules in Logic/HuntShop
-- (the same check on the server and in the window). Everything bought here is bound (no gold through trade or the
-- auction house) and nothing is above the loot: potions of the character's quality, stones, Fortune blessings up to
-- Heroic, essence with a weekly limit, chests with one Unique or Heroic item for the class (never Legendary or
-- Mythic) and two cosmetics. Marks are never sold (tests/paywall.spec, tests/huntshop.spec). Prices and limits only
-- here; balance numbers (tools/balance_reasons.luau, Balance.targetsS134k).

export type Kind =
	"item" -- `id` = Data/Items id, `n` items
	| "potion" -- `id` = "hp" | "resource": `n` potions of the quality Logic/LoginReward.potionQuality gives the level
	| "chest" -- `id` = the rarity key ("unique" | "heroic"): one item rolled on purchase (Logic/LoginReward.rollItem)
	| "cosmetic" -- `id` = Data/Cosmetics id (obtain.hunt = "shop")
export type Group = "consumable" | "essence" | "chest" | "cosmetic"
export type Entry = {
	key: string,
	kind: Kind,
	id: string,
	n: number?, -- items / potions per purchase (default 1)
	price: number, -- Hunter's Marks
	-- potions: the price by the quality the level gets (index = quality 1..4; Logic/HuntShop.priceAt), else `price`
	qualityPrices: { number }?,
	group: Group,
	minLevel: number?, -- character level needed (default 1)
	maxLevel: number?, -- the last character level it is sold to (default: every level)
	weeklyLimit: number?, -- purchases per week (Monday 00:00 UTC, Logic/Time.weekNumber), per character
}

local function entry(e: Entry): Entry
	return e
end

-- The tab order of the window.
local GROUPS: { Group } = { "consumable", "essence", "chest", "cosmetic" }

local ENTRIES: { Entry } = {
	-- potions (5 of the level's quality, the price grows with it: 50 / 300 / 1250 / 3500 gold of the alchemist) and
	-- stones (25 gold a mark: the shop's value of an hour of contracts stays 5-15 % of its gold, Balance.targetsS134k)
	entry({
		key = "potion_hp",
		kind = "potion",
		id = "hp",
		n = 5,
		price = 4,
		qualityPrices = { 4, 6, 10, 20 },
		group = "consumable",
	}),
	entry({
		key = "potion_resource",
		kind = "potion",
		id = "resource",
		n = 5,
		price = 4,
		qualityPrices = { 4, 6, 10, 20 },
		group = "consumable",
	}),
	entry({ key = "stone_return", kind = "item", id = "stone_return", n = 5, price = 4, group = "consumable" }),
	entry({ key = "stone_map", kind = "item", id = "stone_map", n = 2, price = 16, group = "consumable" }),
	-- Fortune blessings up to Heroic (the contract milestones give the same line)
	entry({ key = "blessing_fortune_1", kind = "item", id = "blessing_fortune_1", price = 6, group = "consumable" }),
	entry({
		key = "blessing_fortune_2",
		kind = "item",
		id = "blessing_fortune_2",
		price = 14,
		group = "consumable",
		minLevel = 20,
	}),
	entry({
		key = "blessing_fortune_3",
		kind = "item",
		id = "blessing_fortune_3",
		price = 30,
		group = "consumable",
		minLevel = 45,
	}),
	-- essence with a weekly limit (the upgrades and the transmutation stay on the loot): at most 10 % of the essence of
	-- 14 h of grinding of the band (Balance.targetsS134k): 10 dust (all levels), 5 shards (45-69), 1 crystal (70+); one
	-- crystal is 80 dust, so the shards stop where it starts
	entry({
		key = "essence_dust",
		kind = "item",
		id = "essence_dust",
		n = 10,
		price = 8,
		group = "essence",
		weeklyLimit = 1,
	}),
	entry({
		key = "essence_shard",
		kind = "item",
		id = "essence_shard",
		price = 6,
		group = "essence",
		minLevel = 45,
		maxLevel = 69,
		weeklyLimit = 5,
	}),
	entry({
		key = "essence_crystal",
		kind = "item",
		id = "essence_crystal",
		price = 15,
		group = "essence",
		minLevel = 70,
		weeklyLimit = 1,
	}),
	-- chests: one item for the character's class and level, bound
	entry({ key = "hunt_chest", kind = "chest", id = "unique", price = 60, group = "chest", minLevel = 10 }),
	entry({
		key = "hunt_chest_heroic",
		kind = "chest",
		id = "heroic",
		price = 200,
		group = "chest",
		minLevel = 20,
		weeklyLimit = 1,
	}),
	-- cosmetics (account-wide, Data/Cosmetics obtain.hunt = "shop")
	entry({ key = "title_bountyhunter", kind = "cosmetic", id = "title_bountyhunter", price = 200, group = "cosmetic" }),
	entry({ key = "frame_trophy", kind = "cosmetic", id = "frame_trophy", price = 400, group = "cosmetic" }),
}

local byKey: { [string]: Entry } = {}
for _, e in ENTRIES do
	assert(byKey[e.key] == nil, `Data/HuntShop: duplicate key {e.key}`)
	assert(e.price > 0 and e.price % 1 == 0, `Data/HuntShop: bad price of {e.key}`)
	byKey[e.key] = e
end

return table.freeze({
	GROUPS = GROUPS,
	ENTRIES = ENTRIES,
	byKey = byKey,
	-- the chest rarities (Data/Rarities numbers: Data stays free of Data/Rarities for two constants)
	CHEST_RARITY = table.freeze({ unique = 2, heroic = 3 }),
	CHEST_BOUND = true, -- bound to the character (no alt-account farming for the market)
})
