--!strict
-- Main story (DESIGN §20): 32 quests from the arrival in Vaelthorn to the Frost Dragon Vaelgrath. The first
-- ten are the tutorial (talking, potions, the healer, the blacksmith and +1, the portal, fighting, loot,
-- gear, stat points, skills). Texts: quest.<id>.title / .text / .done (Localization).
-- S101b (DESIGN-15 §3.5): comments during the quests 1-20 (`barks`, quest.<id>.bark.<event><n>; Logic/Barks).
-- S102 (docs/FABULA.md §2): chapters by region (CHAPTERS, chapterOf), offer pages (`pages`: quest.<id>.p1..pN), the
-- four new quests of chapter I "The Frost Sign" (frostRuins, frostSign, warrenCharms, warCouncil; wiki = false until
-- S109) and one EXP rule for the story quests (`weight`, settleStory). New story quests are inserted anywhere in the
-- list: the save keeps the last quest handed in (quests.mainLast, Logic/StoryProgress), never a position.
-- S103 (docs/FABULA.md §2.3): chapter II "The Forgotten House" in Duskwood: nine new quests (moonstone, lostHunters,
-- houseOfVael, elderHeart, turncoat, barrow, witchCounsel, cryptGate, queensLegacy; wiki = false until S109) between
-- the eight old ones, and the whole band 20-44 on the story rule (STORY_BANDS 20: the chapter shares TARGET.main of
-- the band by weight; fixed rewards only on toDuskwood and the boss quest morvane).

local Exp = require("../../Logic/Exp")
local QuestBudget = require("../../Logic/QuestBudget")
local QuestBudgetData = require("../QuestBudget")
local Side = require("./Side")
local Talk = require("./Talk")
local Types = require("./Types")

type MainQuest = Types.MainQuest
type Objective = Types.Objective

-- EXP reward: a fraction of what the recommended level needs to level up.
local function exp(level: number, fraction: number): number
	return math.floor(Exp.expToNext(level) * fraction)
end

local function gold(level: number): number
	return 60 + level * 45
end

-- A story quest definition: a MainQuest whose reward EXP may come from `weight` (settleStory, B2a) instead of a number.
type MainDef = {
	id: string,
	level: number,
	giver: string,
	turnIn: string,
	objectives: { Objective },
	reward: {
		exp: number?, -- nil with `weight`
		gold: number,
		items: { { id: string, n: number } }?,
		cosmetic: string?,
	},
	weight: number?, -- S102: share of the story EXP rule (1 a plain quest, 1.2 a discovery, 1.5 a chapter's end)
	pages: number?,
	wiki: boolean?,
	choices: Types.ChoicePage?,
	recall: { [string]: string }?,
	barks: Types.BarkSet?,
	companion: Types.CompanionDef?,
}

local list: { MainQuest } = {}
local STORY_WEIGHT: { [string]: number } = {}

local function q(def: MainDef)
	assert(def.weight == nil or def.reward.exp == nil, `Main: {def.id} has both a weight and a fixed EXP reward`)
	assert(def.weight ~= nil or def.reward.exp ~= nil, `Main: {def.id} has neither a weight nor an EXP reward`)
	if def.weight then
		STORY_WEIGHT[def.id] = def.weight
	end
	table.insert(list, {
		id = def.id,
		level = def.level,
		giver = def.giver,
		turnIn = def.turnIn,
		objectives = def.objectives,
		reward = {
			exp = def.reward.exp or 0, -- weighted quests: settleStory below
			gold = def.reward.gold,
			items = def.reward.items,
			cosmetic = def.reward.cosmetic,
		},
		category = "main", -- S98 (Data/Quests.CATEGORIES)
		pages = def.pages,
		wiki = def.wiki,
		choices = def.choices,
		recall = def.recall,
		barks = def.barks,
		companion = def.companion,
	})
end

-- S102: objective helpers (the same shapes as Side.luau).
local function talk(npc: string, line: string?): Objective
	return { type = "talk", n = 1, npc = npc, line = line }
end

local function use(anchor: string, action: string, hold: number, fx: string): Objective
	assert(Side.FX[fx], `unknown anchor fx {fx}`)
	return { type = "use", n = 1, anchor = anchor, action = action, hold = hold, fx = fx }
end

local function deliver(item: string, npc: string?, line: string?): Objective
	return { type = "deliver", n = 1, item = item, npc = npc, line = line }
end

local function kill(n: number, monster: string, area: string?, variant: string?): Objective
	return { type = "kill", n = n, monster = monster, area = area, variant = variant }
end

local function collect(
	n: number,
	item: string,
	monster: string,
	chance: number,
	area: string?,
	variant: string? -- S103: "elite" = drops only from Elites (QuestLogic.amount)
): Objective
	return { type = "collect", n = n, item = item, monster = monster, chance = chance, area = area, variant = variant }
end

local function reach(map: string, x: number?, z: number?, radius: number?, place: string?): Objective
	return { type = "reach", n = 1, map = map, x = x, z = z, radius = radius, place = place }
end

-- Tutorial (city and the meadows) ----------------------------------------------------------------------
q({
	id = "arrival",
	level = 1,
	giver = "captain",
	turnIn = "captain",
	pages = 2,
	objectives = { { type = "talk", n = 1, npc = "captain" } },
	reward = { exp = exp(1, 0.3), gold = 100, items = { { id = "potion_hp_1", n = 5 } } },
	barks = { accept = 1, done = 1 },
})
q({
	id = "healer",
	level = 1,
	giver = "captain",
	turnIn = "healer",
	pages = 2,
	objectives = { { type = "potion", n = 1 }, { type = "talk", n = 1, npc = "healer" } },
	reward = { exp = exp(1, 0.4), gold = 300, items = { { id = "essence_dust", n = 6 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "smith",
	level = 1,
	giver = "healer",
	turnIn = "blacksmith",
	pages = 2,
	objectives = { { type = "upgrade", n = 1, up = 1 }, { type = "talk", n = 1, npc = "blacksmith" } },
	reward = { exp = exp(1, 0.5), gold = 150, items = { { id = "potion_mana_1", n = 5 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "portal",
	level = 1,
	giver = "blacksmith",
	turnIn = "scout_meadows",
	pages = 2,
	objectives = { { type = "reach", n = 1, map = "meadows" } },
	reward = { exp = exp(1, 0.4), gold = 100 },
	barks = { accept = 1, done = 1 },
})
q({
	id = "firstHunt",
	level = 1,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	pages = 2,
	objectives = { { type = "kill", n = 5, monster = "rabbit" }, { type = "loot", n = 1 } },
	reward = { exp = exp(2, 0.6), gold = gold(2) },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "gearUp",
	level = 2,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	pages = 2,
	objectives = { { type = "equip", n = 1 }, { type = "stats", n = 1 } },
	reward = { exp = exp(2, 0.4), gold = gold(2), items = { { id = "backpack_30", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "wolves",
	level = 3,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	pages = 2,
	-- S56: "learn" = a skill put on the bar
	objectives = { { type = "kill", n = 8, monster = "wolf" }, { type = "learn", n = 1 } },
	reward = { exp = exp(3, 0.2), gold = gold(3) },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "wolfFangs",
	level = 4,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	pages = 2,
	objectives = { { type = "collect", n = 6, monster = "wolf", item = "wolfFang", chance = 0.5 } },
	reward = { exp = exp(4, 1), gold = gold(4) * 2, items = { { id = "blessing_hunter_1", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "boars",
	level = 6,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	pages = 2,
	objectives = { { type = "kill", n = 10, monster = "boar" } },
	reward = { exp = exp(6, 0.4), gold = gold(6) * 2 },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "herbs",
	level = 7,
	giver = "scout_meadows",
	turnIn = "healer",
	pages = 2,
	objectives = { { type = "gather", n = 5, node = "bush_meadowsweet" } },
	reward = { exp = exp(7, 1.55), gold = gold(7) * 2, items = { { id = "potion_hp_2", n = 10 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S102 chapter I: the frost on the tower ruins in the Old Forest (Mira walks along to the ruins)
q({
	id = "frostRuins",
	level = 7,
	giver = "healer",
	turnIn = "scout_meadows",
	pages = 3,
	wiki = false,
	objectives = {
		reach("meadows", -150, -380, 25, "place.towerRuins"),
		use("tower_crest", "quest.use.crest", 2, "frost"),
		kill(6, "carrionCrow", "meadows_oldforest"),
	},
	weight = 1,
	reward = { gold = gold(7) },
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("go"),
		Talk.answer("exaggerate"),
		Talk.answer("supplies", Talk.gift("potion_hp_1", 2)),
	}),
	companion = Talk.follow("scout_meadows", "meadows", { 1, 2 }, { join = 1, wait = 1, back = 1 }),
})

-- Whispering Meadows and Mosshollow Cave ----------------------------------------------------------------
q({
	id = "banditRoad",
	level = 10,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	pages = 2,
	objectives = { { type = "kill", n = 12, monster = "bandit" } },
	reward = { exp = exp(10, 0.88), gold = gold(10) * 2, items = { { id = "backpack_45", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "banditOrders",
	level = 12,
	giver = "scout_meadows",
	turnIn = "captain",
	pages = 3,
	objectives = { { type = "collect", n = 1, monster = "bandit", item = "banditOrders", chance = 0.25 } },
	reward = { exp = exp(12, 0.87), gold = gold(12) * 2, items = { { id = "stone_map", n = 2 } } },
	barks = { accept = 1, done = 1 },
})
-- S102 chapter I: who paid the bandits; Sergeant Dobiesław leads the player to the temple
q({
	id = "frostSign",
	level = 12,
	giver = "captain",
	turnIn = "captain",
	pages = 3,
	wiki = false,
	objectives = {
		talk("sergeant", "quest.frostSign.sergeant"),
		-- the guardhouse by the east gate -> the market street -> past the fountain -> the temple (every point
		-- TownPlaces.isFree; S102 build/s102_cand.luau: only the leg through the temple lane is not a straight line)
		Talk.escort("sergeant", "city", -118, -128, 10, "place.temple", {
			{ x = 234, z = -12 },
			{ x = 120, z = -8 },
			{ x = 60, z = -28 },
			{ x = -4, z = -58 },
			{ x = -62, z = -78 },
			{ x = -90, z = -80 },
			{ x = -110, z = -100 },
		}),
		talk("brother_anzelm", "quest.frostSign.anzelm"),
	},
	weight = 1,
	reward = { gold = gold(12) },
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, { Talk.answer("chance"), Talk.answer("same"), Talk.answer("who") }),
	recall = { done = "frostSign" },
	companion = Talk.lead("sergeant", "city", { 2 }, { join = 1, wait = 1, arrive = 1, back = 1 }),
})
q({
	id = "goblinCamp",
	level = 14,
	giver = "captain",
	turnIn = "scout_meadows",
	pages = 2,
	objectives = { { type = "kill", n = 15, monster = "goblinScout" } },
	reward = { exp = exp(14, 0.86), gold = gold(14) * 2 },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S102 chapter I: the frost charms of the goblin warriors in the Goblin Warren
q({
	id = "warrenCharms",
	level = 14,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	pages = 3,
	wiki = false,
	objectives = {
		reach("meadows_burrow"),
		kill(4, "goblinScout", "meadows_burrow", "elite"),
		collect(3, "frostCharm", "goblinScout", 0.3, "meadows_burrow"),
	},
	weight = 1,
	reward = { gold = gold(14) },
	barks = { accept = 1, half = 1, done = 1, death = 1, stuck = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("count", Talk.hint("meadows", 420, -719, "map.meadows_burrow.name")),
		Talk.answer("jewelry"),
		Talk.answer("ready"),
	}),
})
q({
	id = "mosshollow",
	level = 16,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	pages = 2,
	objectives = {
		{ type = "reach", n = 1, map = "meadows_cave" },
		{ type = "kill", n = 3, monster = "goblinScout", variant = "elite" },
	},
	reward = { exp = exp(16, 1.9), gold = gold(16) * 2, items = { { id = "blessing_warrior_2", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
q({
	id = "grimrok",
	level = 18,
	giver = "scout_meadows",
	turnIn = "captain",
	pages = 3,
	objectives = { { type = "boss", n = 1, boss = "grimrok" } },
	reward = { exp = exp(20, 0.8), gold = gold(20) * 3, items = { { id = "stone_dungeon_meadows", n = 1 } } },
	barks = { accept = 1, done = 1 },
})
-- S102 chapter I end: the war council in Vaelthorn (the smith and the alchemist read Grimrok's axe and the charm)
q({
	id = "warCouncil",
	level = 16,
	giver = "captain",
	turnIn = "captain",
	pages = 4,
	wiki = false,
	objectives = {
		talk("blacksmith", "quest.warCouncil.blacksmith"),
		deliver("frostCharm", "alchemist", "quest.warCouncil.alchemist"),
	},
	weight = 1.5,
	reward = { gold = gold(16), items = { { id = "blessing_hunter_2", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("smithFirst", Talk.focus(1)),
		Talk.answer("alchemistFirst", Talk.focus(2)),
		Talk.answer("burn"),
	}),
	recall = { p1 = "warrenCharms" },
})

-- Chapter II: The Forgotten House (Duskwood, 20–45), docs/FABULA.md §2.3 ----------------------------------------
-- S92 (F2) raised werewolves .. crypt to 1.1-1.7 of their level's EXP; S103 puts the whole chapter on the story rule
-- (`weight`, settleStory: TARGET.main of the band 20-44), only toDuskwood (the bridge over level 20) and morvane (the
-- boss quest, outside the pace model) keep fixed rewards. Nine new quests (wiki = false until S109) between the eight
-- old ones; the story NPCs of Duskwood stand on Areas/duskwood npcSpots, the anchors and props are S103's.
-- S103 weights: the pace model of S94 has most story EXP of the band on 21-26 (S92's levers on werewolves and ruins:
-- monsters give only 48-57% of those levels), so the quests of 21-26 weigh 1.6-2.2 (houseOfVael 2.2: the window
-- 25-26 of one quest), turncoat 1.4 (window 31-32), queensLegacy 1.5 and the rest 0.8: tools/quest_budget.luau then
-- compensates every level 20-44 without clamping at MUL_MAX (worst 1.237 on 25-26; with 1 / 1.2 / 1.5 levels 21-26
-- and 31-32 hit 1.25 and the pace of 20 -> 45 broke).
q({
	id = "toDuskwood",
	level = 20,
	giver = "captain",
	turnIn = "scout_duskwood",
	pages = 3,
	objectives = { { type = "reach", n = 1, map = "duskwood" } },
	reward = { exp = exp(20, 0.6), gold = gold(20), items = { { id = "backpack_60", n = 1 } } },
	barks = { accept = 1, done = 1 },
})
q({
	id = "werewolves",
	level = 21,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 2,
	objectives = { { type = "kill", n = 15, monster = "werewolf" } },
	weight = 1.8,
	reward = { gold = gold(21) },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S103 chapter II: the frost rune on the Moon Glade's menhir; Radomir survived the attack on the hunters' camp
q({
	id = "moonstone",
	level = 22,
	giver = "scout_duskwood",
	turnIn = "forester_radomir",
	pages = 3,
	wiki = false,
	objectives = {
		talk("forester_radomir", "quest.moonstone.radomir"),
		use("moonstone_rune", "quest.use.moonRune", 3, "frostbreak"),
		kill(8, "werewolf", "duskwood_werethicket"),
	},
	weight = 1.8,
	reward = { gold = gold(22), items = { { id = "potion_hp_3", n = 5 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(3, {
		-- the Moon Glade = the site `moonstone` of Areas/duskwood
		Talk.answer("believe", Talk.hint("duskwood", -606, -262, "place.moonGlade")),
		Talk.answer("doubt"),
		Talk.answer("wolves", Talk.gift("potion_hp_3", 2)),
	}),
})
-- S103 chapter II: Radomir leads the player down Bear Hollow to the lost hunters' camp
q({
	id = "lostHunters",
	level = 23,
	giver = "forester_radomir",
	turnIn = "scout_duskwood",
	pages = 3,
	wiki = false,
	objectives = {
		-- the ravaged camp -> the main road by the dusk gate -> the road into Bear Hollow -> down the ramp by the
		-- fallen giant -> along the gorge floor to the lost camp (S103 build/s103_route.luau: every point
		-- MapTerrain.walkable(4) and dry; the ramp's middle point is too narrow for walkable(4), so the leg from its
		-- top to its foot is one leg of 84 studs, PathfindingService follows the ramp)
		Talk.escort("forester_radomir", "duskwood", -614, 652, 12, "place.lostCamp", {
			{ x = -630, z = 14 },
			{ x = -620, z = 92 },
			{ x = -612, z = 260 },
			{ x = -566, z = 420 },
			{ x = -566, z = 470 },
			{ x = -534, z = 548 },
			{ x = -566, z = 604 },
		}),
		use("lost_camp", "quest.use.searchCamp", 3, "tracks"),
		kill(8, "blackBear", "duskwood_bearhollow"),
	},
	weight = 1.8,
	reward = { gold = gold(23), items = { { id = "blessing_hunter_2", n = 1 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("together"),
		Talk.answer("son"),
		Talk.answer("bears", Talk.gift("potion_hp_3", 2)),
	}),
	recall = { p1 = "moonstone", done = "lostHunters" },
	companion = Talk.lead("forester_radomir", "duskwood", { 1 }, { join = 2, wait = 2, arrive = 2, back = 1 }),
})
q({
	id = "ruins",
	level = 24,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 2,
	objectives = {
		{ type = "kill", n = 12, monster = "forestWraith" },
		{ type = "collect", n = 5, monster = "forestWraith", item = "wraithEssence", chance = 0.4 },
	},
	weight = 1.6,
	reward = { gold = gold(24) },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S103 chapter II: the manor of House Vael, the stained glass with the queen and the ghost of the steward
q({
	id = "houseOfVael",
	level = 25,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 3,
	wiki = false,
	objectives = {
		reach("duskwood", -130, -436, 30, "place.manor"), -- Areas/duskwood SITES.manor
		use("chapel_window", "quest.use.stainedGlass", 2, "candles"),
		use("family_crypt", "quest.use.examineCrypt", 2, "search"),
		talk("ghost_oswin", "quest.houseOfVael.oswin"),
	},
	weight = 2.2,
	reward = { gold = gold(25), items = { { id = "stone_map", n = 2 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("ghosts"),
		Talk.answer("whose"),
		-- the chapel = the site `chapel` of Areas/duskwood
		Talk.answer("way", Talk.hint("duskwood", 4, -586, "place.chapel")),
	}),
})
q({
	id = "ents",
	level = 27,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 2,
	objectives = { { type = "kill", n = 10, monster = "rotEnt" }, { type = "gather", n = 4, node = "bush_nightshade" } },
	weight = 0.8,
	reward = { gold = gold(27), items = { { id = "blessing_guardian_2", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S103 chapter II: the shard of ice in the Elder Tree's crack; the tree gives a branch from its heart
q({
	id = "elderHeart",
	level = 28,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 2,
	wiki = false,
	objectives = {
		use("elder_tree", "quest.use.iceShard", 3, "heartglow"),
		kill(8, "ghoul", "duskwood_heart"),
	},
	weight = 0.8,
	reward = { gold = gold(28), items = { { id = "essence_shard", n = 2 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("cold"),
		Talk.answer("ghouls", Talk.focus(2)),
		-- before the crack: the anchor elder_tree of Areas/duskwood
		Talk.answer("path", Talk.hint("duskwood", 150, 381, "place.elderTree")),
	}),
	recall = { p1 = "houseOfVael" },
})
q({
	id = "cult",
	level = 30,
	giver = "scout_duskwood",
	turnIn = "captain",
	pages = 2,
	objectives = {
		{ type = "kill", n = 15, monster = "darkCultist" },
		{ type = "collect", n = 3, monster = "darkCultist", item = "cultSigil", chance = 0.3 },
	},
	weight = 0.8,
	reward = { gold = gold(30), items = { { id = "backpack_80", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S103 chapter II: a runaway cultist at the wayside shrine names the three seals
q({
	id = "turncoat",
	level = 31,
	giver = "captain",
	turnIn = "captain",
	pages = 3,
	wiki = false,
	objectives = {
		reach("duskwood", 392, -78, 18, "place.wayShrine"), -- Areas/duskwood SITES.wayShrine
		talk("defector_jorund", "quest.turncoat.jorund"),
		kill(10, "darkCultist", "duskwood_crossroads"),
	},
	weight = 1.4,
	reward = { gold = gold(31), items = { { id = "potion_mana_3", n = 5 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(3, { Talk.answer("trust"), Talk.answer("bring"), Talk.answer("hunters", Talk.focus(3)) }),
	recall = { done = "turncoat" },
})
q({
	id = "swamp",
	level = 33,
	giver = "captain",
	turnIn = "scout_duskwood",
	pages = 2,
	objectives = { { type = "kill", n = 12, monster = "swampTroll" }, { type = "fish", n = 3 } },
	weight = 0.8,
	reward = { gold = gold(33) },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S103 chapter II: the rite in the Heart of the Barrow is over; the Book of Rites
q({
	id = "barrow",
	level = 35,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 2,
	wiki = false,
	objectives = {
		reach("duskwood_barrow"),
		kill(4, "darkCultist", "duskwood_barrow", "elite"),
		collect(1, "riteBook", "darkCultist", 0.2, "duskwood_barrow", "elite"),
	},
	weight = 0.8,
	reward = { gold = gold(35), items = { { id = "blessing_warrior_3", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1, death = 1, stuck = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("late"),
		Talk.answer("book", Talk.focus(3)),
		Talk.answer("supplies", Talk.gift("potion_mana_3", 2)),
	}),
})
q({
	id = "crypt",
	level = 37,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 2,
	objectives = {
		{ type = "reach", n = 1, map = "duskwood_cave" },
		{ type = "kill", n = 5, monster = "skeletonGuard", variant = "elite" },
	},
	weight = 0.8,
	reward = { gold = gold(37), items = { { id = "blessing_sage_3", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S103 chapter II: Ragna of the Stilts and the bone chimes of the witches' coven; she walks to the Witch Marsh
q({
	id = "witchCounsel",
	level = 39,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 3,
	wiki = false,
	objectives = {
		talk("witch_ragna", "quest.witchCounsel.ragna"),
		kill(8, "marshWitch", "duskwood_witchmarsh"),
		collect(3, "boneChime", "marshWitch", 0.4, "duskwood_witchmarsh"),
	},
	weight = 0.8,
	reward = { gold = gold(39), items = { { id = "potion_hp_4", n = 5 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("witch"),
		Talk.answer("trust"),
		-- Ragna's place by the stilt village (Areas/duskwood npcSpots.ragna)
		Talk.answer("way", Talk.hint("duskwood", 416, 592, "place.stiltVillage")),
	}),
	companion = Talk.follow("witch_ragna", "duskwood", { 2, 3 }, { join = 1, back = 1 }),
})
-- S103 chapter II: the cult's seal on the Crypt Gate and the first sight of Ilvar (a projection in the frost)
q({
	id = "cryptGate",
	level = 41,
	giver = "scout_duskwood",
	turnIn = "scout_duskwood",
	pages = 2,
	wiki = false,
	objectives = {
		reach("duskwood", 742, 0, 22, "place.cryptGate"), -- the courtyard before the gate (Data/Terrain/duskwood flat)
		use("crypt_seal", "quest.use.breakSeal", 3, "sealbreak"),
		kill(4, "specter", "duskwood_cave", "elite"),
	},
	weight = 0.8,
	reward = { gold = gold(41), items = { { id = "stone_return", n = 2 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("ready"),
		Talk.answer("seal"),
		Talk.answer("supplies", Talk.gift("potion_hp_4", 2)),
	}),
})
q({
	id = "morvane",
	level = 43,
	giver = "scout_duskwood",
	turnIn = "captain",
	pages = 3,
	objectives = { { type = "boss", n = 1, boss = "morvane" } },
	reward = { exp = exp(45, 1.2), gold = gold(45) * 3, items = { { id = "stone_dungeon_duskwood", n = 1 } } },
	barks = { accept = 1, done = 1 },
})
-- S103 chapter II end: the queen's ring and the branch of the Elder Tree before Brother Anzelm, then Ysolde (the branch
-- is the Thorn's shaft; both items come with the quest as deliveries, FABULA §2.3)
q({
	id = "queensLegacy",
	level = 44,
	giver = "captain",
	turnIn = "captain",
	pages = 3,
	wiki = false,
	objectives = {
		deliver("queenRing", "brother_anzelm", "quest.queensLegacy.anzelm"),
		deliver("heartBranch", "brother_anzelm"),
		talk("alchemist", "quest.queensLegacy.alchemist"),
	},
	weight = 1.5,
	reward = {
		gold = gold(44) * 2,
		items = { { id = "blessing_fortune_3", n = 1 }, { id = "essence_crystal", n = 2 } },
	},
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(3, { Talk.answer("rest"), Talk.answer("anzelm"), Talk.answer("east", Talk.focus(3)) }),
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
		cosmetic = "mountskin_dragonslayer", -- S97: the Dragonslayer's mount colours
	},
})

-- S102 (B2a): one EXP rule for the story. A quest with `weight` gets floor(scale(band) x expToNext(level) x weight),
-- where scale is STORY_STEP in the band 1-19 (frozen in S91: the old story already gives more than TARGET.main there)
-- and, in every band listed in STORY_BANDS (S103 adds 20, S104 45, S105 70), the share that makes the band's story
-- EXP (the fixed rewards of its quests without a boss objective plus the weighted ones) equal TARGET.main of the
-- band's EXP. Fixed rewards stay only on the boss quests (chapter finales), the old quests 1-19 and toDuskwood.
local STORY_STEP = 0.05
local STORY_BANDS: { number } = {
	20, -- S103: chapter II
}
local STORY_SCALE: { [number]: number } = {}

local function hasBoss(quest: MainQuest): boolean
	for _, objective in quest.objectives do
		if objective.type == "boss" then
			return true
		end
	end
	return false
end

local function settleStory()
	local weighted: { [number]: number } = {} -- band start -> sum of expToNext x weight
	for _, quest in list do
		local weight = STORY_WEIGHT[quest.id]
		if weight then
			local lo = QuestBudget.bandOf(quest.level)
			weighted[lo] = (weighted[lo] or 0) + Exp.expToNext(quest.level) * weight
		end
	end
	for lo, sum in weighted do
		if table.find(STORY_BANDS, lo) then
			local fixed = 0
			for _, quest in list do
				if STORY_WEIGHT[quest.id] == nil and not hasBoss(quest) and QuestBudget.bandOf(quest.level) == lo then
					fixed += quest.reward.exp
				end
			end
			local budget = math.floor(QuestBudget.bandExp(lo) * QuestBudgetData.TARGET.main) - fixed
			assert(budget > 0, `Main: no story EXP left in the band from {lo} (fixed {fixed})`)
			STORY_SCALE[lo] = budget / sum
		elseif lo == 1 then
			STORY_SCALE[1] = STORY_STEP
		else
			for _, quest in list do
				if STORY_WEIGHT[quest.id] and QuestBudget.bandOf(quest.level) == lo then
					error(`Main: {quest.id} has a weight in the band from {lo}: add the band to STORY_BANDS`)
				end
			end
		end
	end
	for _, quest in list do
		local weight = STORY_WEIGHT[quest.id]
		if weight then
			local lo = QuestBudget.bandOf(quest.level)
			quest.reward.exp = math.floor(STORY_SCALE[lo] * Exp.expToNext(quest.level) * weight)
		end
	end
end
settleStory()

local byId: { [string]: MainQuest } = {}
local indexOf: { [string]: number } = {}
for i, quest in list do
	byId[quest.id] = quest
	indexOf[quest.id] = i
end

-- S102: chapters by region (story.chapter.<n>); a chapter starts at its `first` quest. S105 adds
-- { n = 5, first = "snowInSummer", final = true }.
export type Chapter = { n: number, first: string, region: string?, final: boolean? }
local CHAPTERS: { Chapter } = {
	{ n = 1, first = "arrival", region = "meadows" },
	{ n = 2, first = "toDuskwood", region = "duskwood" },
	{ n = 3, first = "ashen", region = "ashen" },
	{ n = 4, first = "frostpeak", region = "frostpeak" },
}

-- The chapter of a story quest (the highest one whose first quest is not after it; unknown ids: 1).
local function chapterOf(questId: string): number
	local index = indexOf[questId]
	if not index then
		return 1
	end
	local best = 1
	for _, chapter in CHAPTERS do
		local first = indexOf[chapter.first]
		if first and first <= index and chapter.n > best then
			best = chapter.n
		end
	end
	return best
end

return table.freeze({
	list = list,
	byId = byId,
	indexOf = indexOf,
	get = function(id: string): MainQuest?
		return byId[id]
	end,
	CHAPTERS = table.freeze(CHAPTERS),
	chapterOf = chapterOf,
	-- S102 (B2a): the story EXP rule (tests and the S109 report read it)
	STORY_STEP = STORY_STEP,
	STORY_BANDS = table.freeze(STORY_BANDS),
	STORY_SCALE = table.freeze(STORY_SCALE),
	STORY_WEIGHT = table.freeze(STORY_WEIGHT),
	-- A quest can be accepted this many levels before its recommended level.
	LEVEL_SLACK = 2,
})
