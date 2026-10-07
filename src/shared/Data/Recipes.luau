--!strict
-- Alchemist recipes (DESIGN §10): fixed results, real-time brewing, unlocked by character level.
-- Groups: blessings (5 lines x Common..Epic), scrolls and stones, material transmutation, resistance elixirs.

local Blessings = require("./Blessings")

export type Ingredient = { id: string, n: number }

export type Group = "blessing" | "travel" | "material" | "elixir"

export type Recipe = {
	id: string,
	group: Group,
	result: { id: string, n: number },
	ingredients: { Ingredient },
	gold: number,
	time: number, -- seconds
	level: number, -- required character level
}

local list: { Recipe } = {}
local byId: { [string]: Recipe } = {}

local function add(recipe: Recipe)
	assert(byId[recipe.id] == nil, `duplicate recipe {recipe.id}`)
	byId[recipe.id] = recipe
	table.insert(list, recipe)
end

-- Blessings: herb by rarity + one ingredient typical for the line (+ essence shards from Rare up).
local BLESSING_LEVEL = { 1, 15, 35, 60 }
local BLESSING_GOLD = { 100, 400, 1500, 5000 }
-- S29: halved with the blessing duration (30 min); brewing never takes longer than the blessing lasts.
local BLESSING_MINUTES = { 3, 8, 15, 30 }
local BLESSING_HERB = { "herb_meadowsweet", "herb_nightshade", "herb_firebloom", "herb_frostleaf" }
local LINE_INGREDIENT: { [string]: string } = {
	warrior = "wolf_pelt",
	hunter = "spider_silk",
	sage = "herb_moonpetal",
	guardian = "ore_iron",
	fortune = "fish_goldfin",
}

for _, line in Blessings.lines do
	for rarity = 1, 4 do
		local ingredients: { Ingredient } = {
			{ id = BLESSING_HERB[rarity], n = 2 + rarity },
			{ id = LINE_INGREDIENT[line], n = rarity },
		}
		if rarity >= 3 then
			table.insert(ingredients, { id = "essence_shard", n = rarity - 2 })
		end
		add({
			id = `blessing_{line}_{rarity}`,
			group = "blessing",
			result = { id = `blessing_{line}_{rarity}`, n = 1 },
			ingredients = ingredients,
			gold = BLESSING_GOLD[rarity],
			time = BLESSING_MINUTES[rarity] * 60,
			level = BLESSING_LEVEL[rarity],
		})
	end
end

-- Scrolls and teleport stones
add({
	id = "scroll_protection",
	group = "travel",
	result = { id = "scroll_protection", n = 1 },
	ingredients = { { id = "essence_shard", n = 2 }, { id = "herb_moonpetal", n = 2 } },
	gold = 2000,
	time = 20 * 60,
	level = 20,
})
add({
	id = "stone_map",
	group = "travel",
	result = { id = "stone_map", n = 2 },
	ingredients = { { id = "ore_copper", n = 3 }, { id = "fish_pike", n = 2 } },
	gold = 300,
	time = 10 * 60,
	level = 10,
})

-- One stone per boss dungeon (DESIGN §3.2): region ore + a shard.
local DUNGEONS: { { region: string, level: number, ore: string } } = {
	{ region = "meadows", level = 20, ore = "ore_copper" },
	{ region = "duskwood", level = 45, ore = "ore_iron" },
	{ region = "ashen", level = 70, ore = "ore_silver" },
	{ region = "frostpeak", level = 100, ore = "ore_mithril" },
}
for _, dungeon in DUNGEONS do
	local id = `stone_dungeon_{dungeon.region}`
	add({
		id = id,
		group = "travel",
		result = { id = id, n = 1 },
		ingredients = { { id = dungeon.ore, n = 4 }, { id = "essence_shard", n = 1 } },
		gold = dungeon.level * 30,
		time = 20 * 60,
		level = dungeon.level - 5,
	})
end

-- Transmutation (DESIGN §10): 10 Dust -> 1 Shard, 8 Shards -> 1 Crystal, 5 min.
add({
	id = "transmute_shard",
	group = "material",
	result = { id = "essence_shard", n = 1 },
	ingredients = { { id = "essence_dust", n = 10 } },
	gold = 50,
	time = 5 * 60,
	level = 20,
})
add({
	id = "transmute_crystal",
	group = "material",
	result = { id = "essence_crystal", n = 1 },
	ingredients = { { id = "essence_shard", n = 8 } },
	gold = 300,
	time = 5 * 60,
	level = 45,
})

-- Resistance elixirs (1 h, +15 %).
local ELIXIR_INGREDIENTS: { [string]: { Ingredient } } = {
	resFire = { { id = "herb_firebloom", n = 3 }, { id = "salamander_scale", n = 2 } },
	resIce = { { id = "herb_frostleaf", n = 3 }, { id = "yeti_fur", n = 2 } },
	resLightning = { { id = "herb_moonpetal", n = 2 }, { id = "fish_eel", n = 3 } },
	resPoison = { { id = "herb_nightshade", n = 3 }, { id = "spider_silk", n = 2 } },
}
for _, stat in Blessings.ELIXIRS do
	local id = `elixir_{stat}`
	add({
		id = id,
		group = "elixir",
		result = { id = id, n = 2 },
		ingredients = ELIXIR_INGREDIENTS[stat],
		gold = 400,
		time = 15 * 60,
		level = 30,
	})
end

return table.freeze({
	list = list,
	byId = byId,
	get = function(id: string): Recipe?
		return byId[id]
	end,
	groups = { "blessing", "travel", "material", "elixir" } :: { Group },
	dungeons = DUNGEONS,
	-- Parallel orders (DESIGN §10); VIP adds one.
	QUEUE_SLOTS = 3,
	QUEUE_SLOTS_VIP = 4,
})
