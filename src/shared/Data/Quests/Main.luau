--!strict
-- Main story (DESIGN §20): 32 quests from the arrival in Vaelthorn to the Frost Dragon Vaelgrath. The first
-- ten are the tutorial (talking, potions, the healer, the blacksmith and +1, the portal, fighting, loot,
-- gear, stat points, skills). Texts: quest.<id>.title / .text / .done (Localization).

local Exp = require("../../Logic/Exp")
local Types = require("./Types")

type MainQuest = Types.MainQuest

-- EXP reward: a fraction of what the recommended level needs to level up.
local function exp(level: number, fraction: number): number
	return math.floor(Exp.expToNext(level) * fraction)
end

local function gold(level: number): number
	return 60 + level * 45
end

local list: { MainQuest } = {}

local function q(def: MainQuest)
	table.insert(list, def)
end

-- Tutorial (city and the meadows) ----------------------------------------------------------------------
q({
	id = "arrival",
	level = 1,
	giver = "captain",
	turnIn = "captain",
	objectives = { { type = "talk", n = 1, npc = "captain" } },
	reward = { exp = exp(1, 0.3), gold = 100, items = { { id = "potion_hp_1", n = 5 } } },
})
q({
	id = "healer",
	level = 1,
	giver = "captain",
	turnIn = "healer",
	objectives = { { type = "potion", n = 1 }, { type = "talk", n = 1, npc = "healer" } },
	reward = { exp = exp(1, 0.4), gold = 300, items = { { id = "essence_dust", n = 6 } } },
})
q({
	id = "smith",
	level = 1,
	giver = "healer",
	turnIn = "blacksmith",
	objectives = { { type = "upgrade", n = 1, up = 1 }, { type = "talk", n = 1, npc = "blacksmith" } },
	reward = { exp = exp(1, 0.5), gold = 150, items = { { id = "potion_mana_1", n = 5 } } },
})
q({
	id = "portal",
	level = 1,
	giver = "blacksmith",
	turnIn = "scout_meadows",
	objectives = { { type = "reach", n = 1, map = "meadows" } },
	reward = { exp = exp(1, 0.4), gold = 100 },
})
q({
	id = "firstHunt",
	level = 1,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	objectives = { { type = "kill", n = 5, monster = "rabbit" }, { type = "loot", n = 1 } },
	reward = { exp = exp(2, 0.6), gold = gold(2) },
})
q({
	id = "gearUp",
	level = 2,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	objectives = { { type = "equip", n = 1 }, { type = "stats", n = 1 } },
	reward = { exp = exp(2, 0.6), gold = gold(2), items = { { id = "backpack_30", n = 1 } } },
})
q({
	id = "wolves",
	level = 3,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	objectives = { { type = "kill", n = 8, monster = "wolf" }, { type = "learn", n = 1 } },
	reward = { exp = exp(3, 0.7), gold = gold(3) },
})
q({
	id = "wolfFangs",
	level = 4,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	objectives = { { type = "collect", n = 6, monster = "wolf", item = "wolfFang", chance = 0.5 } },
	reward = { exp = exp(4, 0.8), gold = gold(4), items = { { id = "blessing_hunter_1", n = 1 } } },
})
q({
	id = "boars",
	level = 6,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	objectives = { { type = "kill", n = 10, monster = "boar" } },
	reward = { exp = exp(6, 0.8), gold = gold(6) },
})
q({
	id = "herbs",
	level = 7,
	giver = "scout_meadows",
	turnIn = "healer",
	objectives = { { type = "gather", n = 5, node = "bush_meadowsweet" } },
	reward = { exp = exp(7, 0.8), gold = gold(7), items = { { id = "potion_hp_2", n = 10 } } },
})

-- Whispering Meadows and Mosshollow Cave ----------------------------------------------------------------
q({
	id = "banditRoad",
	level = 10,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	objectives = { { type = "kill", n = 12, monster = "bandit" } },
	reward = { exp = exp(10, 0.8), gold = gold(10), items = { { id = "backpack_45", n = 1 } } },
})
q({
	id = "banditOrders",
	level = 12,
	giver = "scout_meadows",
	turnIn = "captain",
	objectives = { { type = "collect", n = 1, monster = "bandit", item = "banditOrders", chance = 0.25 } },
	reward = { exp = exp(12, 0.9), gold = gold(12), items = { { id = "stone_map", n = 2 } } },
})
q({
	id = "goblinCamp",
	level = 14,
	giver = "captain",
	turnIn = "scout_meadows",
	objectives = { { type = "kill", n = 15, monster = "goblinScout" } },
	reward = { exp = exp(14, 0.9), gold = gold(14) },
})
q({
	id = "mosshollow",
	level = 16,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	objectives = {
		{ type = "reach", n = 1, map = "meadows_cave" },
		{ type = "kill", n = 3, monster = "goblinScout", variant = "elite" },
	},
	reward = { exp = exp(16, 1), gold = gold(16), items = { { id = "blessing_warrior_2", n = 1 } } },
})
q({
	id = "grimrok",
	level = 18,
	giver = "scout_meadows",
	turnIn = "captain",
	objectives = { { type = "boss", n = 1, boss = "grimrok" } },
	reward = { exp = exp(20, 1.2), gold = gold(20) * 3, items = { { id = "stone_dungeon_meadows", n = 1 } } },
})

-- Duskwood and the Crypt -------------------------------------------------------------------------------
q({
	id = "toDuskwood",
	level = 20,
	giver = "captain",
	turnIn = "scout_duskwood",
	objectives = { { type = "reach", n = 1, map = "duskwood" } },
	reward = { exp = exp(20, 0.6), gold = gold(20), items = { { id = "backpack_60", n = 1 } } },
})
q({
	id = "werewolves",
	level = 21,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	objectives = { { type = "kill", n = 15, monster = "werewolf" } },
	reward = { exp = exp(21, 0.9), gold = gold(21) },
})
q({
	id = "ruins",
	level = 24,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	objectives = {
		{ type = "kill", n = 12, monster = "forestWraith" },
		{ type = "collect", n = 5, monster = "forestWraith", item = "wraithEssence", chance = 0.4 },
	},
	reward = { exp = exp(24, 1), gold = gold(24) },
})
q({
	id = "ents",
	level = 27,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	objectives = { { type = "kill", n = 10, monster = "rotEnt" }, { type = "gather", n = 4, node = "bush_nightshade" } },
	reward = { exp = exp(27, 1), gold = gold(27), items = { { id = "blessing_guardian_2", n = 1 } } },
})
q({
	id = "cult",
	level = 30,
	giver = "scout_duskwood",
	turnIn = "captain",
	objectives = {
		{ type = "kill", n = 15, monster = "darkCultist" },
		{ type = "collect", n = 3, monster = "darkCultist", item = "cultSigil", chance = 0.3 },
	},
	reward = { exp = exp(30, 1), gold = gold(30), items = { { id = "backpack_80", n = 1 } } },
})
q({
	id = "swamp",
	level = 33,
	giver = "captain",
	turnIn = "scout_duskwood",
	objectives = { { type = "kill", n = 12, monster = "swampTroll" }, { type = "fish", n = 3 } },
	reward = { exp = exp(33, 1), gold = gold(33) },
})
q({
	id = "crypt",
	level = 37,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	objectives = {
		{ type = "reach", n = 1, map = "duskwood_cave" },
		{ type = "kill", n = 5, monster = "skeletonGuard", variant = "elite" },
	},
	reward = { exp = exp(37, 1), gold = gold(37), items = { { id = "blessing_sage_3", n = 1 } } },
})
q({
	id = "morvane",
	level = 43,
	giver = "scout_duskwood",
	turnIn = "captain",
	objectives = { { type = "boss", n = 1, boss = "morvane" } },
	reward = { exp = exp(45, 1.2), gold = gold(45) * 3, items = { { id = "stone_dungeon_duskwood", n = 1 } } },
})

-- Ashen Wastes and Deepforge ---------------------------------------------------------------------------
q({
	id = "ashen",
	level = 45,
	giver = "captain",
	turnIn = "scout_ashen",
	objectives = { { type = "reach", n = 1, map = "ashen" }, { type = "kill", n = 15, monster = "salamander" } },
	reward = { exp = exp(45, 0.9), gold = gold(45), items = { { id = "backpack_100", n = 1 } } },
})
q({
	id = "orcs",
	level = 50,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	objectives = { { type = "kill", n = 20, monster = "ashOrc" }, { type = "gather", n = 5, node = "vein_silver" } },
	reward = { exp = exp(50, 1), gold = gold(50) },
})
q({
	id = "golems",
	level = 55,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	objectives = {
		{ type = "kill", n = 15, monster = "fireGolem" },
		{ type = "kill", n = 10, monster = "desertScorpion" },
	},
	reward = { exp = exp(55, 1), gold = gold(55), items = { { id = "elixir_resFire", n = 3 } } },
})
q({
	id = "deepforge",
	level = 62,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	objectives = {
		{ type = "reach", n = 1, map = "ashen_cave" },
		{ type = "kill", n = 6, monster = "renegadeDwarf", variant = "elite" },
	},
	reward = { exp = exp(62, 1), gold = gold(62), items = { { id = "backpack_130", n = 1 } } },
})
q({
	id = "azgor",
	level = 68,
	giver = "scout_ashen",
	turnIn = "captain",
	objectives = { { type = "boss", n = 1, boss = "azgor" } },
	reward = { exp = exp(70, 1.2), gold = gold(70) * 3, items = { { id = "stone_dungeon_ashen", n = 1 } } },
})

-- Frostpeak and the Glacier Heart ------------------------------------------------------------------------
q({
	id = "frostpeak",
	level = 72,
	giver = "captain",
	turnIn = "scout_frostpeak",
	objectives = {
		{ type = "reach", n = 1, map = "frostpeak" },
		{ type = "kill", n = 20, monster = "iceWolf" },
		{ type = "kill", n = 15, monster = "yeti" },
	},
	reward = { exp = exp(72, 1), gold = gold(72), items = { { id = "backpack_160", n = 1 } } },
})
q({
	id = "giants",
	level = 80,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	objectives = { { type = "kill", n = 15, monster = "frostGiant" }, { type = "upgrade", n = 1, up = 5 } },
	reward = { exp = exp(80, 1), gold = gold(80), items = { { id = "elixir_resIce", n = 3 } } },
})
q({
	id = "glacier",
	level = 92,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	objectives = {
		{ type = "reach", n = 1, map = "frostpeak_cave" },
		{ type = "kill", n = 8, monster = "crystalGuardian", variant = "elite" },
	},
	reward = { exp = exp(92, 1), gold = gold(92), items = { { id = "backpack_200", n = 1 } } },
})
q({
	id = "vaelgrath",
	level = 97,
	giver = "scout_frostpeak",
	turnIn = "captain",
	objectives = { { type = "boss", n = 1, boss = "vaelgrath" } },
	reward = {
		exp = exp(99, 1.5),
		gold = gold(100) * 5,
		-- The one Scroll of Unbinding of the story.
		items = { { id = "scroll_unbind", n = 1 }, { id = "blessing_fortune_4", n = 1 } },
	},
})

local byId: { [string]: MainQuest } = {}
local indexOf: { [string]: number } = {}
for i, quest in list do
	byId[quest.id] = quest
	indexOf[quest.id] = i
end

return table.freeze({
	list = list,
	byId = byId,
	indexOf = indexOf,
	get = function(id: string): MainQuest?
		return byId[id]
	end,
	-- A quest can be accepted this many levels before its recommended level.
	LEVEL_SLACK = 2,
})
