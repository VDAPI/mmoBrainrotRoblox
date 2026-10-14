--!strict
-- Main story (DESIGN §20): from the arrival in Vaelthorn to the Frost Dragon Vaelgrath and the first spring (S105). The first
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
-- S104 (docs/FABULA.md §2.4): chapter III "Cold Fire" on the Ashen Wastes: ten new quests (deadOasis, warcampCages,
-- mineDepths, emberCores, burntTemple, wyvernLair, ashRoad, runesOfBinding, forgeChains, coldFire; wiki = false until
-- S109) between the five old ones, and the band 45-69 on the story rule (STORY_BANDS 45; azgor keeps its reward).
-- S105 (docs/FABULA.md §2.5): chapter IV "The Long Winter" and the finale "The First Spring" on the Frost Peaks: fifteen
-- new quests between the four old ones (70 quests in all, firstSpring last: reach level 100), the band 70-99 on the
-- story rule (STORY_BANDS 70; vaelgrath keeps its reward, firstSpring gives no EXP).

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

-- S104: one `use` objective over several anchors (progress = distinct anchors done, S27).
local function useAll(anchors: { string }, action: string, hold: number, fx: string): Objective
	assert(Side.FX[fx], `unknown anchor fx {fx}`)
	return { type = "use", n = #anchors, anchors = anchors, action = action, hold = hold, fx = fx }
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

-- Chapter III: Cold Fire (Ashen Wastes and Deepforge, 45–70; docs/FABULA.md §2.4, S104). Brokk, Ghasha and Kaspar stand
-- on Areas/ashen npcSpots; anchors in Areas/ashen and in the ashen_cave cave. The whole band 45-69 is on the story rule
-- (STORY_BANDS 45: the chapter shares TARGET.main of the band by weight); only azgor (the boss quest, outside the pace
-- model) keeps its fixed reward. Ten new quests (wiki = false until S109) between the five old ones.
q({
	id = "ashen",
	level = 45,
	giver = "captain",
	turnIn = "scout_ashen",
	pages = 3,
	objectives = { { type = "reach", n = 1, map = "ashen" }, { type = "kill", n = 15, monster = "salamander" } },
	weight = 1,
	reward = { gold = gold(45), items = { { id = "backpack_100", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S104 chapter III: Brokk leads the player down to his caravan on the dry bed of the Dead Oasis
q({
	id = "deadOasis",
	level = 47,
	giver = "scout_ashen",
	turnIn = "runesmith_brokk",
	pages = 3,
	wiki = false,
	objectives = {
		-- Brokk's camp by the Ribcage Gate -> the main road -> the caravan trail south (Areas/ashen roads) -> down the
		-- oasis rim -> the caravan graveyard (inside its avoid circle: no monster group there), ~55 studs from the chest
		Talk.escort("runesmith_brokk", "ashen", -448, 628, 12, "place.caravanRemains", {
			{ x = -520, z = 0 },
			{ x = -526, z = 200 },
			{ x = -520, z = 380 },
			{ x = -548, z = 480 },
			{ x = -500, z = 560 },
		}),
		use("caravan_chest", "quest.use.chest", 3, "search"),
		kill(10, "wasteHyena", "ashen_oasis"),
	},
	weight = 1,
	reward = { gold = gold(47) },
	barks = { by = "runesmith_brokk", accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, { Talk.answer("notes"), Talk.answer("hands"), Talk.answer("count") }),
	companion = Talk.lead("runesmith_brokk", "ashen", { 1 }, { join = 1, wait = 3, arrive = 2, back = 1 }),
})
-- S104 chapter III: the captives of the caravan and Ghasha in the cages of the ash orcs' warcamp
q({
	id = "warcampCages",
	level = 49,
	giver = "runesmith_brokk",
	turnIn = "scout_ashen",
	pages = 3,
	wiki = false,
	objectives = {
		use("orc_cage", "quest.use.cage", 3, "cageOpen"),
		kill(8, "ashOrc", "ashen_warcamp"),
		talk("shaman_ghasha", "quest.warcampCages.ghasha"),
	},
	weight = 1.2,
	reward = { gold = gold(49) },
	barks = { by = "runesmith_brokk", accept = 1, half = 1, near = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("gate", Talk.focus(2)),
		-- the cages of Areas/ashen SITES.orcCages, at the anchor orc_cage
		Talk.answer("cages", Talk.hint("ashen", -350, -526, "place.orcCages")),
		Talk.answer("why"),
	}),
	recall = { p1 = "deadOasis" },
})
q({
	id = "orcs",
	level = 50,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	pages = 2,
	objectives = { { type = "kill", n = 20, monster = "ashOrc" }, { type = "gather", n = 5, node = "vein_silver" } },
	weight = 1,
	reward = { gold = gold(50) },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S104 chapter III: the cold iron in the Abandoned Mine (the supply ledger of the orc overseers, Elites only)
q({
	id = "mineDepths",
	level = 52,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	pages = 3,
	wiki = false,
	objectives = {
		reach("ashen_mine"),
		kill(4, "ashOrc", "ashen_mine", "elite"),
		collect(1, "supplyLedger", "ashOrc", 0.25, "ashen_mine", "elite"),
	},
	weight = 1,
	reward = { gold = gold(52), items = { { id = "stone_map", n = 2 } } },
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, { Talk.answer("frost"), Talk.answer("dark"), Talk.answer("quick") }),
})
-- S104 chapter III: the ember cores of the fire golems and the eyes of the Sleeping Colossus
q({
	id = "emberCores",
	level = 53,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	pages = 3,
	wiki = false,
	objectives = {
		collect(4, "emberCore", "fireGolem", 0.4, "ashen_golemfields"),
		use("colossus_eyes", "quest.use.eyes", 3, "rune"),
		talk("runesmith_brokk", "quest.emberCores.brokk"),
	},
	weight = 1.2,
	reward = { gold = gold(53) },
	barks = { by = "runesmith_brokk", accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("how"), Talk.answer("colossus", Talk.focus(2)), Talk.answer("why") }),
	recall = { p3 = "deadOasis" },
})
q({
	id = "golems",
	level = 55,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	pages = 2,
	objectives = {
		{ type = "kill", n = 15, monster = "fireGolem" },
		{ type = "kill", n = 10, monster = "desertScorpion" },
	},
	weight = 1,
	reward = { gold = gold(55), items = { { id = "elixir_resFire", n = 3 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S104 chapter III: Brother Kaspar and the cracked bell of the burnt town (a witness of Ilvar)
q({
	id = "burntTemple",
	level = 57,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	pages = 3,
	wiki = false,
	objectives = {
		talk("hermit_kaspar", "quest.burntTemple.kaspar"),
		kill(12, "fireImp", "ashen_burntruins"),
		use("temple_bell", "quest.use.bell", 3, "candles"),
	},
	weight = 1.2,
	reward = { gold = gold(57), items = { { id = "blessing_sage_3", n = 1 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("empty"),
		-- Kaspar's threshold before the burnt temple (Areas/ashen npcSpots.hermit)
		Talk.answer("way", Talk.hint("ashen", 175, 634, "place.kasparThreshold")),
		Talk.answer("candles"),
	}),
})
-- S104 chapter III: the cult's harnesses on the wyverns of the Wyvern Lair (the sky road north)
q({
	id = "wyvernLair",
	level = 59,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	pages = 3,
	wiki = false,
	objectives = {
		reach("ashen_lair"),
		kill(4, "wyvern", "ashen_lair", "elite"),
		collect(2, "cultHarness", "wyvern", 0.35, "ashen_lair", "elite"),
	},
	weight = 1,
	reward = { gold = gold(59), items = { { id = "blessing_hunter_3", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("dead"),
		Talk.answer("heat", Talk.gift("elixir_resFire", 1)),
		Talk.answer("north"),
	}),
})
-- S104 chapter III: Ilvar's letter in the stone caravan on the Ash Road
q({
	id = "ashRoad",
	level = 61,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	pages = 3,
	wiki = false,
	objectives = {
		use("stone_caravan", "quest.use.stoneWagon", 3, "search"),
		kill(10, "basilisk", "ashen_ashroad"),
	},
	weight = 1.2,
	reward = { gold = gold(61) },
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(3, { Talk.answer("what"), Talk.answer("stone"), Talk.answer("hunt", Talk.focus(2)) }),
})
q({
	id = "deepforge",
	level = 62,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	pages = 3,
	objectives = {
		{ type = "reach", n = 1, map = "ashen_cave" },
		{ type = "kill", n = 6, monster = "renegadeDwarf", variant = "elite" },
	},
	weight = 1,
	reward = { gold = gold(62), items = { { id = "backpack_130", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S104 chapter III: the Thorn's spearhead by the half-molten Chains of Winter; Brokk forges a setting of mithril
q({
	id = "runesOfBinding",
	level = 64,
	giver = "scout_ashen",
	turnIn = "runesmith_brokk",
	pages = 3,
	wiki = false,
	objectives = {
		{ type = "gather", n = 5, node = "vein_mithril" },
		kill(4, "magmaGolem", "ashen_cave", "elite"),
		talk("runesmith_brokk", "quest.runesOfBinding.brokk"),
	},
	weight = 1,
	reward = { gold = gold(64) },
	barks = { by = "runesmith_brokk", accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		-- the vein_mithril node nearest to the Ribcage Gate (AshenGen.nodes())
		Talk.answer("where", Talk.hint("ashen", 31, 169, "place.mithrilVein")),
		Talk.answer("spear"),
		Talk.answer("who"),
	}),
	recall = { done = "emberCores" },
})
-- S104 chapter III: Brokk walks through Deepforge with the player and unlocks the chained captives (a red zone)
q({
	id = "forgeChains",
	level = 66,
	giver = "runesmith_brokk",
	turnIn = "scout_ashen",
	pages = 3,
	wiki = false,
	objectives = {
		-- the Smelter, the Renegades' Armoury and the Heart of the Forge (Areas/Caves ashen_cave questAnchors)
		useAll({ "forge_chain_1", "forge_chain_2", "forge_chain_3" }, "quest.use.shackles", 3, "chains"),
		kill(10, "flameSmith", "ashen_cave"),
	},
	weight = 1.2,
	reward = { gold = gold(66), items = { { id = "elixir_resFire", n = 3 } } },
	barks = { by = "runesmith_brokk", accept = 1, half = 1, near = 3, death = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("alone"), Talk.answer("smiths", Talk.focus(2)), Talk.answer("keys") }),
	recall = { p1 = "warcampCages" },
	-- by the cave's respawn point (-240 / 0): Brokk does not stand on the cave map
	companion = Talk.follow(
		"runesmith_brokk",
		"ashen_cave",
		{ 1 },
		{ join = 1, wait = 1, back = 1 },
		{ x = -232, z = 8 }
	),
})
q({
	id = "azgor",
	level = 68,
	giver = "scout_ashen",
	turnIn = "captain",
	pages = 3,
	objectives = { { type = "boss", n = 1, boss = "azgor" } },
	reward = { exp = exp(70, 1.2), gold = gold(70) * 3, items = { { id = "stone_dungeon_ashen", n = 1 } } },
	barks = { accept = 1, done = 1 },
})
-- S104 chapter III end: the Thorn's spearhead to Dorgan (the shaft from the Elder Tree waits in his forge), then Anzelm
q({
	id = "coldFire",
	level = 69,
	giver = "captain",
	turnIn = "captain",
	pages = 4,
	wiki = false,
	objectives = {
		deliver("spearhead", "blacksmith", "quest.coldFire.blacksmith"),
		talk("brother_anzelm", "quest.coldFire.anzelm"),
	},
	weight = 1.5,
	reward = { gold = gold(69), items = { { id = "blessing_guardian_4", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("dorgan", Talk.focus(1)),
		Talk.answer("anzelm", Talk.focus(2)),
		Talk.answer("tired"),
	}),
	recall = { p3 = "burntTemple" },
})

-- Chapter IV: The Long Winter (the Frost Peaks, 70–97) and the finale "The First Spring" (97–100); docs/FABULA.md
-- §2.5, S105. Sigrun and the ghost of Halgrim stand on Areas/frostpeak npcSpots; the anchors are in Areas/frostpeak and
-- in the frostpeak_hold cave. The band 70-99 is on the story rule (STORY_BANDS 70: the chapter shares TARGET.main of
-- the band by weight, the old frostpeak, giants and glacier too); vaelgrath (the boss quest) keeps the reward S97
-- pinned, firstSpring (level 100, nothing left to earn) gives no EXP. Fifteen new quests (wiki = false until S109)
-- between the four old ones; their ids are a contract with S108 (trappersCamp, iceGrotto, iceWatch, dragonTemple).
q({
	id = "frostpeak",
	level = 72,
	giver = "captain",
	turnIn = "scout_frostpeak",
	pages = 3,
	objectives = {
		{ type = "reach", n = 1, map = "frostpeak" },
		{ type = "kill", n = 20, monster = "iceWolf" },
		{ type = "kill", n = 15, monster = "yeti" },
	},
	weight = 1.2,
	reward = { gold = gold(72), items = { { id = "backpack_160", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S105 chapter IV: Sigrun, the trappers' guide, came back alone to the abandoned camp in the valley
q({
	id = "trappersCamp",
	level = 74,
	giver = "scout_frostpeak",
	turnIn = "trapper_sigrun",
	pages = 3,
	wiki = false,
	objectives = {
		reach("frostpeak", -548, -168, 24, "place.trapperCamp"), -- Areas/frostpeak SITES.trapperCamp
		kill(10, "snowLeopard", "frostpeak_valley"),
		talk("trapper_sigrun", "quest.trappersCamp.sigrun"),
	},
	weight = 1,
	reward = { gold = gold(74), items = { { id = "elixir_resIce", n = 2 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("where", Talk.hint("frostpeak", -548, -168, "place.trapperCamp")),
		Talk.answer("sigrun"),
		Talk.answer("alone"),
	}),
})
-- S105 chapter IV: Sigrun walks the player to the Ice Grotto; the trappers froze inside, Arne's journal
q({
	id = "iceGrotto",
	level = 76,
	giver = "trapper_sigrun",
	turnIn = "scout_frostpeak",
	pages = 3,
	wiki = false,
	objectives = {
		reach("frostpeak_grotto"),
		kill(4, "yeti", "frostpeak_grotto", "elite"),
		collect(1, "trapperJournal", "yeti", 0.3, "frostpeak_grotto", "elite"),
	},
	weight = 1.2,
	reward = { gold = gold(76), items = { { id = "stone_return", n = 3 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("promise"),
		Talk.answer("wind"),
		Talk.answer("supplies", Talk.gift("potion_hp_5", 2)),
	}),
	recall = { p1 = "trappersCamp", done = "iceGrotto" },
	-- from her place in the camp up the Yeti Slopes to the Grotto's mouth; she stays outside (another map)
	companion = Talk.follow("trapper_sigrun", "frostpeak", { 1 }, { join = 1, wait = 1, back = 1 }),
})
-- S105 chapter IV: the climbers' camp under the Queen's Spire and the seal of the Ice Guard in a harpy nest
q({
	id = "harpyRocks",
	level = 78,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 2,
	wiki = false,
	objectives = {
		use("climbers_camp", "quest.use.burial", 3, "shroud"),
		kill(10, "peakHarpy", "frostpeak_harpyrocks"),
		collect(1, "orderSeal", "peakHarpy", 0.3, "frostpeak_harpyrocks"),
	},
	weight = 1,
	reward = { gold = gold(78), items = { { id = "stone_map", n = 2 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("shiny"),
		Talk.answer("climbers"),
		-- the anchor climbers_camp of Areas/frostpeak
		Talk.answer("where", Talk.hint("frostpeak", -464, 606, "area.frostpeak_harpyrocks")),
	}),
})
q({
	id = "giants",
	level = 80,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 2,
	objectives = { { type = "kill", n = 15, monster = "frostGiant" }, { type = "upgrade", n = 1, up = 5 } },
	weight = 1,
	reward = { gold = gold(80), items = { { id = "elixir_resIce", n = 3 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S105 chapter IV: the order's armour in the giants' hunting camp on the Mammoth Tundra
q({
	id = "mammothTundra",
	level = 82,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 2,
	wiki = false,
	objectives = {
		use("hunting_camp", "quest.use.gatherArmor", 3, "armor"),
		kill(12, "iceMammoth", "frostpeak_tundra"),
	},
	weight = 1,
	reward = { gold = gold(82) },
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("knights"),
		Talk.answer("herd", Talk.focus(2)),
		Talk.answer("mammoths"),
	}),
})
-- S105 chapter IV: Halvar leads the player across the tundra to the Giants' Breach of the Frozen Hold
q({
	id = "frozenHold",
	level = 84,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 3,
	wiki = false,
	objectives = {
		-- the tundra's map stone -> the road across the tundra (Areas/frostpeak roads, past the Mammoth Graveyard's
		-- tusks) -> 55 studs before the Hold's gate (build/s105_scan.luau: every point MapTerrain.walkable(4), dry)
		Talk.escort("scout_frostpeak", "frostpeak", 298, -690, 14, "place.giantsBreach", {
			{ x = 283, z = -430 },
			{ x = 291, z = -560 },
			{ x = 295, z = -640 },
		}),
		reach("frostpeak_hold"),
		kill(4, "frostGiant", "frostpeak_hold", "elite"),
	},
	weight = 1.2,
	reward = { gold = gold(84), items = { { id = "elixir_resIce", n = 2 } } },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(3, { Talk.answer("order"), Talk.answer("breach") }),
	-- Halvar does not stand on the tundra: he joins by its map stone (Areas/frostpeak tundra `arrive`)
	companion = Talk.lead(
		"scout_frostpeak",
		"frostpeak",
		{ 1 },
		{ join = 1, wait = 1, arrive = 1, back = 1 },
		{ x = 277, z = -336 }
	),
})
-- S105 chapter IV: the crystals of the Frozen Lake beat with the heart under the glacier
q({
	id = "frozenLake",
	level = 86,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 2,
	wiki = false,
	objectives = {
		kill(12, "iceElemental", "frostpeak_lake"),
		use("crystal_garden", "quest.use.shatter", 3, "shatter"),
	},
	weight = 1,
	reward = { gold = gold(86) },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("listen"),
		-- the anchor crystal_garden of Areas/frostpeak
		Talk.answer("where", Talk.hint("frostpeak", 300, 632, "area.frostpeak_lake")),
	}),
})
-- S105 chapter IV: the seal of the Ice Guard to the last brother in the Ice Watch (the delivery moved here from
-- oathWords: the giver of oathWords is Halgrim himself, DECYZJE S105)
q({
	id = "iceWatch",
	level = 88,
	giver = "scout_frostpeak",
	turnIn = "ghost_halgrim",
	pages = 3,
	wiki = false,
	objectives = {
		reach("frostpeak", 628, 570, 30, "place.keep"), -- Areas/frostpeak npcSpots.halgrim (before the keep)
		kill(12, "frozenKnight", "frostpeak_icewatch"),
		deliver("orderSeal", nil, "quest.iceWatch.halgrim"),
	},
	weight = 1,
	reward = { gold = gold(88) },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(3, { Talk.answer("light"), Talk.answer("seal") }),
	recall = { p1 = "iceGrotto" },
})
-- S105 chapter IV: the Frost Flower broken and the oath of the Guard sworn by the sword in the ice (the Thorn whole)
q({
	id = "oathWords",
	level = 90,
	giver = "ghost_halgrim",
	turnIn = "scout_frostpeak",
	pages = 4,
	wiki = false,
	objectives = {
		use("frost_bloom", "quest.use.shatter", 3, "shatter"),
		use("hold_chapel", "quest.use.oath", 5, "oath"),
		kill(4, "frozenKnight", "frostpeak_hold", "elite"),
	},
	weight = 1.5,
	reward = { gold = gold(90) * 2, items = { { id = "blessing_guardian_4", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(4, { Talk.answer("brothers"), Talk.answer("you"), Talk.answer("words") }),
	recall = { done = "oathWords" },
})
q({
	id = "glacier",
	level = 92,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 2,
	objectives = {
		{ type = "reach", n = 1, map = "frostpeak_cave" },
		{ type = "kill", n = 8, monster = "crystalGuardian", variant = "elite" },
	},
	weight = 1.2,
	reward = { gold = gold(92), items = { { id = "backpack_200", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
})
-- S105 chapter IV: the cult's waking song in the Dragon Temple; Ilvar on the sanctuary's steps
q({
	id = "dragonTemple",
	level = 94,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 3,
	wiki = false,
	objectives = {
		kill(15, "dragonspawn", "frostpeak_temple"),
		use("temple_altars", "quest.use.snuff", 3, "snuff"),
		use("temple_colossus", "quest.use.snuff", 3, "snuff"),
	},
	weight = 1.3,
	reward = { gold = gold(94), items = { { id = "stone_dungeon_frostpeak", n = 1 } } },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(3, { Talk.answer("song"), Talk.answer("cult"), Talk.answer("fires", Talk.focus(2)) }),
})
-- S105 chapter IV: the dragonspawn's obelisk calling the wyrms to the lair
q({
	id = "wyrmSpire",
	level = 95,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 2,
	wiki = false,
	objectives = {
		kill(10, "frostWyrm", "frostpeak_wyrmspire"),
		use("wyrm_obelisk", "quest.use.shatter", 3, "shatter"),
	},
	weight = 1,
	reward = { gold = gold(95) },
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("wyrms"),
		-- the anchor wyrm_obelisk of Areas/frostpeak
		Talk.answer("obelisk", Talk.hint("frostpeak", 652, -425, "area.frostpeak_wyrmspire")),
	}),
})
-- S105 chapter IV: before the dragon, Aldric and Anzelm in the city, then the scouts of the four lands at dawn
q({
	id = "eveOfBattle",
	level = 96,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 3,
	wiki = false,
	objectives = {
		talk("captain", "quest.eveOfBattle.captain"),
		talk("brother_anzelm", "quest.eveOfBattle.anzelm"),
		reach("frostpeak", 560, 0, 24, "place.dragonStairs"), -- Areas/frostpeak SITES.dragonStairs
	},
	weight = 0.8,
	reward = { gold = gold(96), items = { { id = "stone_return", n = 5 } } },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("captain", Talk.focus(1)),
		Talk.answer("anzelm", Talk.focus(2)),
		Talk.answer("afraid"),
	}),
})
q({
	id = "vaelgrath",
	level = 97,
	giver = "scout_frostpeak",
	turnIn = "captain",
	pages = 3,
	objectives = { { type = "boss", n = 1, boss = "vaelgrath" } },
	reward = {
		exp = exp(99, 1.5),
		gold = gold(100) * 5,
		-- The one Scroll of Unbinding of the story.
		items = { { id = "scroll_unbind", n = 1 }, { id = "blessing_fortune_4", n = 1 } },
		cosmetic = "mountskin_dragonslayer", -- S97: the Dragonslayer's mount colours
	},
	barks = { accept = 1, done = 1 },
})
-- S105 finale: snow on the feast; the dragon had no heart (the finale's chapter card plays first)
q({
	id = "snowInSummer",
	level = 98,
	giver = "captain",
	turnIn = "scout_frostpeak",
	pages = 3,
	wiki = false,
	objectives = {
		talk("brother_anzelm", "quest.snowInSummer.anzelm"),
		reach("frostpeak_cave"),
	},
	weight = 0.8,
	reward = { gold = gold(98) },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("feast"),
		-- before the Glacier Heart's mouth (Areas/frostpeak caves: 745 / 0, rot 90; 22 studs out like the cave arrivals)
		Talk.answer("where", Talk.hint("frostpeak", 723, 0, "map.frostpeak_cave.name")),
		Talk.answer("anzelm"),
	}),
})
-- S105 finale: the young dragons carried the Heart of Winter away; Sigrun leads the player up the Bone Trail
q({
	id = "dragonsBrood",
	level = 99,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 2,
	wiki = false,
	objectives = {
		kill(6, "youngFrostDragon", "frostpeak_cave", "elite"),
		-- the fork of the tundra road and the Bone Trail -> along the trail (Areas/frostpeak roads) -> before the ribs of
		-- the wyrm's skeleton (they arch over the trail; Sigrun stops short of them, and voiceOfWinter starts there)
		Talk.escort("trapper_sigrun", "frostpeak", 532, -528, 30, "place.wyrmBones", {
			{ x = 360, z = -549 },
			{ x = 420, z = -540 },
			{ x = 490, z = -530 },
		}),
	},
	weight = 1,
	reward = { gold = gold(99) },
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, {
		-- Sigrun waits at the fork (the companion's start)
		Talk.answer("trail", Talk.hint("frostpeak", 300, -556, "npc.trapper_sigrun.name")),
		Talk.answer("brood"),
	}),
	recall = { p1 = "iceGrotto" },
	companion = Talk.lead(
		"trapper_sigrun",
		"frostpeak",
		{ 2 },
		{ join = 2, wait = 2, arrive = 1, back = 1 },
		{ x = 300, z = -556 }
	),
})
-- S105 finale: Ilvar's rite in the Rite Circle under the Spire's summit (Sigrun walks the player up to it)
q({
	id = "voiceOfWinter",
	level = 99,
	giver = "scout_frostpeak",
	turnIn = "scout_frostpeak",
	pages = 4,
	wiki = false,
	objectives = {
		reach("frostpeak", 628, -574, 24, "place.summit"), -- Areas/frostpeak SITES.summitRite
		kill(8, "dragonspawn", "frostpeak_wyrmspire"),
		kill(8, "frostWyrm", "frostpeak_wyrmspire"),
		use("summit_rite", "quest.use.breakRite", 5, "rite"),
	},
	weight = 1.5,
	reward = { gold = gold(99) * 2, items = { { id = "blessing_sage_4", n = 1 } } },
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(4, {
		Talk.answer("alone"),
		Talk.answer("turn"),
		Talk.answer("supplies", Talk.gift("potion_mana_5", 2)),
	}),
	-- where dragonsBrood left her, before the wyrm's ribs
	companion = Talk.follow(
		"trapper_sigrun",
		"frostpeak",
		{ 1 },
		{ join = 1, wait = 1, back = 1 },
		{ x = 532, z = -528 }
	),
})
-- S105 finale: the Thorn of Vael in the Heart of Winter, the hundredth level, and the first spring of Vaelthorn
q({
	id = "firstSpring",
	level = 100,
	giver = "scout_frostpeak",
	turnIn = "captain",
	pages = 4,
	wiki = false,
	objectives = {
		use("summit_thorn", "quest.use.thorn", 5, "thorn"),
		{ type = "level", n = 1, level = 100 },
	},
	-- level 100 needs no EXP (nothing to share of the band 70-99): gold, the title thornbearer (Data/Titles) and the skin
	reward = { exp = 0, gold = gold(100) * 3, cosmetic = "mountskin_spring" },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(4, { Talk.answer("stay"), Talk.answer("city"), Talk.answer("thorn") }),
	recall = { done = "eveOfBattle" },
})

-- S102 (B2a): one EXP rule for the story. A quest with `weight` gets floor(scale(band) x expToNext(level) x weight),
-- where scale is STORY_STEP in the band 1-19 (frozen in S91: the old story already gives more than TARGET.main there)
-- and, in every band listed in STORY_BANDS (S103 adds 20, S104 45, S105 70), the share that makes the band's story
-- EXP (the fixed rewards of its quests without a boss objective plus the weighted ones) equal TARGET.main of the
-- band's EXP. Fixed rewards stay only on the boss quests (chapter finales), the old quests 1-19 and toDuskwood.
local STORY_STEP = 0.05
local STORY_BANDS: { number } = {
	20, -- S103: chapter II
	45, -- S104: chapter III
	70, -- S105: chapter IV
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

-- S102: chapters by region (story.chapter.<n>); a chapter starts at its `first` quest. S105: the finale (n = 5).
export type Chapter = { n: number, first: string, region: string?, final: boolean? }
local CHAPTERS: { Chapter } = {
	{ n = 1, first = "arrival", region = "meadows" },
	{ n = 2, first = "toDuskwood", region = "duskwood" },
	{ n = 3, first = "ashen", region = "ashen" },
	{ n = 4, first = "frostpeak", region = "frostpeak" },
	{ n = 5, first = "snowInSummer", region = "frostpeak", final = true }, -- S105: the finale "The First Spring"
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
