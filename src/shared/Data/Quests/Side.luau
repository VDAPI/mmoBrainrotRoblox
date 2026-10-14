--!strict
-- Side quests of the Whispering Meadows (S27, DESIGN §20): the city hands out the work, the Meadows are where it
-- is done. Nine arcs, one per Meadows area, each with an NPC who lives there (Data/Npcs, spots from S26) and
-- something to do in the world besides killing (quest anchors of S26: `use` objectives). Rewards: EXP as a share
-- of what the quest's level needs (0.25, the arc's last quest 0.45: all of them ~40% of the EXP from level 1 to 20,
-- see docs/DECYZJE.md S27), gold half of the base main-quest formula (main quests 4-16 pay x2 since S91), and the last
-- quest of an arc (★) lets the player pick one of three items for their class. Texts: quest.<id>.title,
-- .p1..pN (pages), .progress, .done; arcs quest.arc.<arc>; quest items quest.item.<item>.
-- S96: the stable arc (levels 21-22, taken from 20 through `minLevel`) ends with a mount (`reward.mount`) instead of
-- an item choice; S97 publishes it on the wiki and adds a mount skin to its last quest (`reward.cosmetic`).
-- S101b (DESIGN-15 §3.5): comments during every quest (`barks`), answers with small effects in side_venom, side_bears
-- and side_den (`choices`, Data/Quests/Talk), side_den's first page answering side_bears (`recall`) and Borys walking
-- with the player through side_den (`companion`).
-- S106: Duskwood side arcs (levels 20–44, docs/DESIGN-15.md §3.4). From level 20 on a side quest's EXP is not a
-- fraction of its level but a share of its band's side budget (Data/QuestBudget TARGET.side of the band's EXP,
-- Logic/QuestBudget.bandExp), split in proportion to expToNext(level) × weight (normal 1, arc end 1.8); quests with an
-- explicit fraction (the S96 stable arc) keep it and count against the same budget. The Meadows numbers (levels 1–19)
-- do not change. Gold of the banded quests: gold(level) × GOLD_FROM_20. Anchors and NPC places of the Duskwood arcs:
-- Data/Areas/duskwood (dw_* anchors).

local Exp = require("../../Logic/Exp")
local QuestBudget = require("../../Logic/QuestBudget")
local QuestBudgetData = require("../QuestBudget")
local Talk = require("./Talk")
local Town = require("../Town")
local Types = require("./Types")

type SideQuest = Types.SideQuest
type Objective = Types.Objective

local NORMAL_EXP = 0.25
local FINAL_EXP = 0.45

local function exp(level: number, fraction: number): number
	return math.floor(Exp.expToNext(level) * fraction)
end

-- S106: side quests from this level on share their band's side budget (see the header).
local BAND_FROM = 20
local WEIGHT = table.freeze({ normal = 1, final = 1.8 })
-- S106: gold of the banded side quests (from BAND_FROM, without expShare) against gold(level): with the full gold the
-- Duskwood arcs lift a level's income so that +1..+3 of a weapon at 40 falls to 0.449 of it (G9, band 0.45-1.05)
local GOLD_FROM_20 = 0.8

-- Half of the base main-quest gold (Main.luau: 60 + level * 45; main quests 4-16 pay x2 of it since S91).
local function gold(level: number): number
	return math.floor((60 + level * 45) * 0.5)
end

-- Client effects at an anchor once its `use` is done (QuestAnchorController builds them).
local FX = {
	candles = true, -- lit candles at the wayside shrine
	plank = true, -- a fresh fence board
	net = true, -- the net pulled out onto the shore
	mark = true, -- a chalk mark on a log pile
	search = true, -- dug-up ashes with a scorched chest
	crate = true, -- an opened crate with cloth spilling out
	seal = true, -- planks nailed across a tunnel mouth
	fire = true, -- the goblin totem burning
	tracks = true, -- a hunter's marker stick with a red rag
	halter = true, -- a stake with a cut halter rope and trampled grass where the stallion was calmed (S96)
	frost = true, -- S102: rime crust and a frosted crest on the tower ruins (story quest frostRuins)
	-- S103 (story chapter II; drawn in the frame of the anchor's prop, Logic/DuskwoodGen/Quest):
	frostbreak = true, -- the frost rune on the Moon Glade's menhir cracked, rime scattered, the silver light back
	heartglow = true, -- a warm golden glow in the Elder Tree's crack, the ice shard melted into a puddle
	sealbreak = true, -- the cult's seal on the Crypt Gate shattered on the ground, a torn chain
	-- S104 (story chapter III, the Ashen Wastes and Deepforge):
	cageOpen = true, -- the door of an orc cage torn off and leant on the ground, a broken padlock
	rune = true, -- a slate with a glowing blue rune and its light (the Sleeping Colossus; S107 uses it too)
	chains = true, -- two open shackles on the ground, one broken in halves, and a run of links from the post
	-- S105 (story chapter IV and the finale, the Frost Peaks and the Frozen Hold):
	shroud = true, -- a tent cloth stretched over the fallen climbers, a cairn with an ice axe on top
	armor = true, -- the order's armour laid in a row on the snow under a planted pennant (navy and silver)
	shatter = true, -- shards of crystal on the ground, the glow gone grey (a short flash when first built)
	snuff = true, -- bowls of fire put out: black embers and thin threads of smoke
	oath = true, -- the block of ice on the altar split, the order's sword glowing gold and blue
	rite = true, -- the Rite Circle broken: cracked monoliths, the ring scattered, Ilvar's statue of ice by the altar
	thorn = true, -- the Thorn of Vael in the Heart of Winter, a gold glow, melted snow with grass and flowers
	-- S106 (the Duskwood side arcs):
	lamp = true, -- S106: a road lantern set up again, burning cold blue
	smoke = true, -- S106: a smoking smudge pot under a wild hive
	wreath = true, -- S106: a heather wreath and a candle on a cleaned grave
	cage = true, -- S106: a cage door hanging open, the rope cut
	ward = true, -- S106: a hex charm burnt, a small white-painted ward board in its place
	spill = true, -- S106: the witches' cauldron knocked over, the brew soaking into the mud
}

local list: { SideQuest } = {}
-- S106: quests of a band from BAND_FROM without expShare, waiting for settleBands (the weight of each)
local pending: { [SideQuest]: number } = {}
local BAND_SCALE: { [number]: number } = {}

local function side(
	def: {
		id: string,
		level: number,
		giver: string,
		turnIn: string,
		arc: string,
		pages: number,
		requires: { string }?,
		objectives: { Objective },
		final: boolean?,
		where: { map: string, area: string?, x: number?, z: number? }?,
		expShare: number?, -- S96: EXP share of the quest level instead of NORMAL_EXP / FINAL_EXP
		mount: string?, -- S96: a mount on hand-in (the arc's end without an item choice)
		cosmetic: string?, -- S97: an account cosmetic on hand-in (Reward.cosmetic)
		minLevel: number?, -- S96
		wiki: boolean?, -- S96
		category: Types.Category?, -- S98: "side" when nil (the S96 stable arc too)
		-- S101b (DESIGN-15 §3.5): answers, page variants by an earlier answer, comments, companion
		choices: Types.ChoicePage?,
		recall: { [string]: string }?,
		barks: Types.BarkSet?,
		companion: Types.CompanionDef?,
	}
)
	local final = def.final == true
	local share = def.expShare or (if final then FINAL_EXP else NORMAL_EXP)
	-- S106: from BAND_FROM on, quests without expShare get their EXP from the band's budget (settleBands)
	local banded = def.level >= BAND_FROM and def.expShare == nil
	local quest: SideQuest = {
		id = def.id,
		level = def.level,
		giver = def.giver,
		turnIn = def.turnIn,
		arc = def.arc,
		pages = def.pages,
		requires = def.requires,
		objectives = def.objectives,
		reward = {
			exp = if banded then 0 else exp(def.level, share),
			gold = if banded then math.floor(gold(def.level) * GOLD_FROM_20) else gold(def.level),
			choice = if final and not def.mount then "final" else nil,
			mount = def.mount,
			cosmetic = def.cosmetic,
		},
		where = def.where,
		minLevel = def.minLevel,
		wiki = def.wiki,
		category = def.category or "side",
		choices = def.choices,
		recall = def.recall,
		barks = def.barks,
		companion = def.companion,
	}
	table.insert(list, quest)
	if banded then
		pending[quest] = if final then WEIGHT.final else WEIGHT.normal
	end
end

local function use(anchors: { string }, action: string, hold: number, fx: string): Objective
	assert(FX[fx], `unknown anchor fx {fx}`)
	if #anchors == 1 then
		return { type = "use", n = 1, anchor = anchors[1], action = action, hold = hold, fx = fx }
	end
	return { type = "use", n = #anchors, anchors = anchors, action = action, hold = hold, fx = fx }
end

local function deliver(item: string, npc: string?): Objective
	return { type = "deliver", n = 1, item = item, npc = npc }
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
	variant: string?
): Objective
	return {
		type = "collect",
		n = n,
		item = item,
		monster = monster,
		chance = chance,
		area = area,
		variant = variant,
	}
end

-- A. Bartosz's farm (1–5), Rabbit Glade ---------------------------------------------------------------------
side({
	id = "side_granary",
	level = 1,
	giver = "granary_keeper",
	turnIn = "farmer_bartosz",
	arc = "farm",
	pages = 3,
	objectives = { deliver("grainOrder") },
	barks = { accept = 1, done = 1 },
})
side({
	id = "side_rabbits",
	level = 1,
	giver = "farmer_bartosz",
	turnIn = "farmer_bartosz",
	arc = "farm",
	pages = 2,
	requires = { "side_granary" },
	objectives = { kill(10, "rabbit", "meadows_rabbitfields") },
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_fence",
	level = 2,
	giver = "farmer_bartosz",
	turnIn = "farmer_bartosz",
	arc = "farm",
	pages = 2,
	requires = { "side_rabbits" },
	objectives = { use({ "fence_1", "fence_2", "fence_3", "fence_4" }, "quest.use.fence", 2, "plank") },
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_sheep",
	level = 3,
	giver = "farmer_bartosz",
	turnIn = "farmer_bartosz",
	arc = "farm",
	pages = 3,
	requires = { "side_fence" },
	objectives = { collect(5, "sheepBell", "wolf", 0.4) },
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_grainCart",
	level = 4,
	giver = "farmer_bartosz",
	turnIn = "granary_keeper",
	arc = "farm",
	pages = 3,
	requires = { "side_sheep" },
	objectives = { deliver("grainSack"), kill(6, "wolf") },
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
})

-- B. The shrine under the old oak (2–7) ------------------------------------------------------------------------
side({
	id = "side_shrine",
	level = 2,
	giver = "brother_anzelm",
	turnIn = "brother_anzelm",
	arc = "shrine",
	pages = 3,
	objectives = {
		use({ "shrine_candles" }, "quest.use.candles", 3, "candles"),
		{ type = "gather", n = 3, node = "bush_meadowsweet" },
	},
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_stoneCircle",
	level = 5,
	giver = "brother_anzelm",
	turnIn = "brother_anzelm",
	arc = "shrine",
	pages = 3,
	requires = { "side_shrine" },
	objectives = {
		-- the stone circle on the Wolf Hills ridge (Areas/meadows sites.stonecircle)
		{ type = "reach", n = 1, map = "meadows", x = -340, z = -150, radius = 20, place = "place.stonecircle" },
		kill(8, "lynx", "meadows_wolfhills"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
})

-- C. Toad Pond (4–8) -----------------------------------------------------------------------------------------
side({
	id = "side_father",
	level = 4,
	giver = "fishwife",
	turnIn = "fisher_wit",
	arc = "pond",
	pages = 2,
	objectives = { deliver("breadBasket") },
	barks = { accept = 1, done = 1 },
})
side({
	id = "side_toads",
	level = 5,
	giver = "fisher_wit",
	turnIn = "fisher_wit",
	arc = "pond",
	pages = 2,
	requires = { "side_father" },
	objectives = { kill(12, "swampToad") },
	where = { map = "meadows", area = "meadows_toadmire" },
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_venom",
	level = 6,
	giver = "fisher_wit",
	turnIn = "alchemist",
	arc = "pond",
	pages = 3,
	requires = { "side_toads" },
	objectives = { collect(6, "toadVenom", "swampToad", 0.5) },
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	-- S101b: Wit marks where the toads croak loudest (a point on dry land in the marsh, checked in docs/SESJE.md S101b)
	choices = Talk.onPage(2, {
		Talk.answer("where", Talk.hint("meadows", -630, 430, "area.meadows_toadmire")),
		Talk.answer("luck"),
		Talk.answer("jagna"),
	}),
})
side({
	id = "side_net",
	level = 7,
	giver = "fisher_wit",
	turnIn = "fishwife",
	arc = "pond",
	pages = 3,
	requires = { "side_venom" },
	objectives = { use({ "net_shore" }, "quest.use.net", 3, "net"), { type = "fish", n = 3 } },
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
})

-- D. The Old Forest (6–11) -----------------------------------------------------------------------------------
side({
	id = "side_roast",
	level = 6,
	giver = "innkeeper",
	turnIn = "innkeeper",
	arc = "forest",
	pages = 2,
	objectives = { collect(6, "boarHaunch", "boar", 0.5) },
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_woodcutter",
	level = 7,
	giver = "innkeeper",
	turnIn = "woodcutter_gerwazy",
	arc = "forest",
	pages = 2,
	requires = { "side_roast" },
	objectives = { deliver("aleBarrel") },
	barks = { accept = 1, done = 1 },
})
side({
	id = "side_logs",
	level = 8,
	giver = "woodcutter_gerwazy",
	turnIn = "woodcutter_gerwazy",
	arc = "forest",
	pages = 3,
	requires = { "side_woodcutter" },
	objectives = {
		use({ "logpile_1", "logpile_2", "logpile_3", "logpile_4", "logpile_5" }, "quest.use.logs", 1.5, "mark"),
		kill(8, "carrionCrow"),
	},
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_shiny",
	level = 9,
	giver = "woodcutter_gerwazy",
	turnIn = "miller_widow",
	arc = "forest",
	pages = 3,
	requires = { "side_logs" },
	objectives = { collect(5, "shinyTrinket", "carrionCrow", 0.4) },
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
})

-- E. The burnt mill (9–13): Crow Field and the Smugglers' Hideout ---------------------------------------------
side({
	id = "side_mill",
	level = 9,
	giver = "miller_widow",
	turnIn = "miller_widow",
	arc = "mill",
	pages = 3,
	-- Hanna recognises her husband's signet among the crows' trinkets (arc D).
	requires = { "side_shiny" },
	objectives = {
		use({ "mill_ruin" }, "quest.use.ruin", 3, "search"),
		kill(6, "bandit", "meadows_crowfield"),
	},
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_smugglers",
	level = 11,
	giver = "miller_widow",
	turnIn = "sergeant",
	arc = "mill",
	pages = 4,
	requires = { "side_mill" },
	objectives = {
		{ type = "reach", n = 1, map = "meadows_hideout" },
		kill(1, "bandit", nil, "elite"),
		collect(1, "ledger", "bandit", 1, nil, "elite"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
})

-- F. The merchant road (10–14) -------------------------------------------------------------------------------
side({
	id = "side_wagon",
	level = 10,
	giver = "stablemaster",
	turnIn = "merchant_lucjan",
	arc = "road",
	pages = 2,
	objectives = { { type = "talk", n = 1, npc = "merchant_lucjan" } },
	barks = { accept = 1, done = 1 },
})
side({
	id = "side_goods",
	level = 11,
	giver = "merchant_lucjan",
	turnIn = "merchant_lucjan",
	arc = "road",
	pages = 3,
	requires = { "side_wagon" },
	objectives = {
		use({ "wagon_goods" }, "quest.use.wagon", 2, "crate"),
		collect(8, "clothBale", "bandit", 0.5, "meadows_banditroad"),
	},
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_wanted",
	level = 13,
	giver = "sergeant",
	turnIn = "sergeant",
	arc = "road",
	pages = 2,
	requires = { "side_goods" },
	objectives = { kill(15, "bandit", "meadows_banditroad") },
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
})

-- G. The Old Quarry (11–16) ----------------------------------------------------------------------------------
side({
	id = "side_ore",
	level = 11,
	giver = "blacksmith",
	turnIn = "miner_dobromir",
	arc = "quarry",
	pages = 2,
	objectives = { deliver("smithLetter") },
	barks = { accept = 1, done = 1 },
})
side({
	id = "side_tools",
	level = 12,
	giver = "miner_dobromir",
	turnIn = "miner_dobromir",
	arc = "quarry",
	pages = 3,
	requires = { "side_ore" },
	objectives = { collect(6, "minerPick", "koboldMiner", 0.5) },
	where = { map = "meadows", area = "meadows_diggings" },
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_tunnels",
	level = 14,
	giver = "miner_dobromir",
	turnIn = "blacksmith",
	arc = "quarry",
	pages = 3,
	requires = { "side_tools" },
	objectives = {
		use({ "tunnel_1", "tunnel_2", "tunnel_3" }, "quest.use.tunnel", 3, "seal"),
		{ type = "gather", n = 8, node = "vein_iron" },
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
})

-- H. The Goblin Camp (14–18) ---------------------------------------------------------------------------------
side({
	id = "side_totem",
	level = 15,
	giver = "sergeant",
	turnIn = "sergeant",
	arc = "goblins",
	pages = 3,
	objectives = {
		kill(12, "goblinScout", "meadows_goblincamp"),
		use({ "totem_goblin" }, "quest.use.totem", 3, "fire"),
	},
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_foreman",
	level = 16,
	giver = "sergeant",
	turnIn = "miner_dobromir",
	arc = "goblins",
	pages = 3,
	requires = { "side_totem" },
	objectives = {
		{ type = "reach", n = 1, map = "meadows_burrow" },
		kill(2, "koboldMiner", nil, "elite"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
})

-- I. Bear Ravine (16–20) -------------------------------------------------------------------------------------
side({
	id = "side_hunter",
	level = 16,
	giver = "innkeeper",
	turnIn = "hunter_borys",
	arc = "ravine",
	pages = 2,
	objectives = { deliver("hunterSupplies") },
	barks = { accept = 1, done = 1 },
})
side({
	id = "side_bears",
	level = 17,
	giver = "hunter_borys",
	turnIn = "hunter_borys",
	arc = "ravine",
	pages = 3,
	requires = { "side_hunter" },
	objectives = { kill(10, "brownBear"), collect(4, "bearClaw", "brownBear", 0.4) },
	where = { map = "meadows", area = "meadows_bearridge" },
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	-- S101b: two small healing potions for the asking; side_den remembers the other answers (recall)
	choices = Talk.onPage(2, {
		Talk.answer("supplies", Talk.gift("potion_hp_1", 2)),
		Talk.answer("quiet"),
		Talk.answer("fire"),
	}),
})
side({
	id = "side_den",
	level = 19,
	giver = "hunter_borys",
	turnIn = "hunter_borys",
	arc = "ravine",
	pages = 3,
	requires = { "side_bears" },
	objectives = {
		use({ "bear_den" }, "quest.use.den", 3, "tracks"),
		kill(6, "goblinScout", "meadows_bearridge"),
	},
	final = true,
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1, stuck = 1 },
	-- S101b: which objective the tracker leads to first; the first page answers what was said in side_bears; Borys
	-- walks with the player to the den and through the ravine (no new objective: progress and the ledger unchanged)
	choices = Talk.onPage(3, {
		Talk.answer("denFirst", Talk.focus(1)),
		Talk.answer("goblinsFirst", Talk.focus(2)),
		Talk.answer("drums"),
	}),
	recall = { p1 = "side_bears" },
	companion = Talk.follow("hunter_borys", "meadows", { 1, 2 }, { join = 2, wait = 1, back = 1 }),
})

-- J. The Stable (20–22) -------------------------------------------------------------------------------------------
-- S96 (docs/DESIGN-15.md §2): the stablemaster's arc gives every character its first mount once. The EXP is symbolic
-- (the mount is the reward); S98 puts the arc into the quest EXP budget.
local STABLE_EXP = 0.1
local STABLE_MIN = 20 -- = Config.Mount.minLevel (Data does not require Config; tests/mounts.spec checks it)
local stable = Town.npcSpot("stablemaster")
assert(stable, "Side: no stablemaster spot in the city plan")
side({
	id = "side_stable_harness",
	level = 21,
	giver = "stablemaster",
	turnIn = "stablemaster",
	arc = "stable",
	pages = 3,
	objectives = { collect(3, "harnessPiece", "goblinScout", 0.4, "meadows_goblincamp") },
	expShare = STABLE_EXP,
	minLevel = STABLE_MIN,
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_stable_stallion",
	level = 21,
	giver = "stablemaster",
	turnIn = "hunter_borys",
	arc = "stable",
	pages = 3,
	requires = { "side_stable_harness" },
	objectives = {
		use({ "wild_stallion" }, "quest.use.calm", 3, "halter"),
		kill(6, "brownBear", "meadows_bearridge"),
	},
	expShare = STABLE_EXP,
	minLevel = STABLE_MIN,
	barks = { accept = 1, half = 1, done = 1 },
})
side({
	id = "side_stable_ride",
	level = 22,
	giver = "hunter_borys",
	turnIn = "stablemaster",
	arc = "stable",
	pages = 2,
	requires = { "side_stable_stallion" },
	objectives = {
		{ type = "reach", n = 1, map = "city", x = stable.x, z = stable.z, radius = 14, place = "place.stable" },
	},
	final = true,
	mount = "mount_horse",
	cosmetic = "mountskin_meadow",
	expShare = STABLE_EXP,
	minLevel = STABLE_MIN,
	barks = { accept = 1, done = 1 },
})

-- K. The Dusk Lanterns (20–24), Werewolf Thicket and the Wolf Den ------------------------------------------------
-- S106 (docs/DESIGN-15.md §3.4): Wanda keeps the cold lanterns by the road; her brother Stach is the werewolf who
-- knocks them down. Every Duskwood arc is off the wiki until S109 (`wiki = false`).
side({
	id = "side_moonOil",
	level = 20,
	giver = "sergeant",
	turnIn = "huntress_wanda",
	arc = "lanterns",
	pages = 2,
	objectives = { deliver("moonOil") },
	minLevel = 20,
	wiki = false,
	barks = { accept = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("why"), Talk.answer("quick") }),
})
side({
	id = "side_darkLanterns",
	level = 21,
	giver = "huntress_wanda",
	turnIn = "huntress_wanda",
	arc = "lanterns",
	pages = 3,
	requires = { "side_moonOil" },
	objectives = {
		use({ "dw_lantern_1", "dw_lantern_2", "dw_lantern_3" }, "quest.use.lantern", 2.5, "lamp"),
		kill(8, "werewolf", "duskwood_werethicket"),
	},
	minLevel = 20,
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("lanterns", Talk.focus(1)),
		Talk.answer("wolves", Talk.focus(2)),
		Talk.answer("alone"),
	}),
})
side({
	id = "side_boneTree",
	level = 23,
	giver = "huntress_wanda",
	turnIn = "huntress_wanda",
	arc = "lanterns",
	pages = 3,
	requires = { "side_darkLanterns" },
	objectives = {
		-- Wanda leads from the Dusk Gate up the old hunters' trail to the Bone Tree (route checked in docs/SESJE.md S106)
		Talk.escort(
			"huntress_wanda",
			"duskwood",
			-540,
			200,
			10,
			"place.boneTree",
			{ { x = -600, z = 70 }, { x = -572, z = 140 } }
		),
		use({ "dw_bonetree" }, "quest.use.trophies", 3, "tracks"),
		kill(6, "blackBear", "duskwood_werethicket"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(3, { Talk.answer("brother"), Talk.answer("silent") }),
	companion = Talk.lead("huntress_wanda", "duskwood", { 1 }, { join = 1, wait = 2, arrive = 1, back = 1 }),
})
side({
	id = "side_lampLighter",
	level = 24,
	giver = "huntress_wanda",
	turnIn = "huntress_wanda",
	arc = "lanterns",
	pages = 4,
	requires = { "side_boneTree" },
	objectives = {
		{ type = "reach", n = 1, map = "duskwood_den" },
		kill(1, "werewolf", nil, "elite"),
		collect(1, "stachLantern", "werewolf", 1, nil, "elite"),
	},
	final = true,
	cosmetic = "mountskin_lantern", -- S106: the Lantern Warden's caparison (Data/Cosmetics, obtain.quest)
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(4, {
		Talk.answer("promise"),
		Talk.answer("come", Talk.gift("potion_hp_3", 2)),
	}),
	recall = { p1 = "side_boneTree" },
})

-- L. The Ravine Hives (22–27), Werewolf Thicket, Bear Hollow and the Wolf Den -------------------------------------
side({
	id = "side_clayJars",
	level = 22,
	giver = "innkeeper",
	turnIn = "beekeeper_maciej",
	arc = "apiary",
	pages = 2,
	objectives = { deliver("clayJars") },
	wiki = false,
	barks = { accept = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("mead"), Talk.answer("maciej") }),
})
side({
	id = "side_smokedHives",
	level = 23,
	giver = "beekeeper_maciej",
	turnIn = "beekeeper_maciej",
	arc = "apiary",
	pages = 3,
	requires = { "side_clayJars" },
	objectives = {
		-- the first hive is the fallen one at the Thicket's edge, the other two in the gorge
		use({ "dw_hive_1", "dw_hive_2", "dw_hive_3" }, "quest.use.hive", 2.5, "smoke"),
		kill(8, "blackBear", "duskwood_bearhollow"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("hive", Talk.focus(1)),
		Talk.answer("bears", Talk.focus(2)),
		Talk.answer("sting"),
	}),
})
side({
	id = "side_stolenHoney",
	level = 25,
	giver = "beekeeper_maciej",
	turnIn = "innkeeper",
	arc = "apiary",
	pages = 3,
	requires = { "side_smokedHives" },
	objectives = { collect(6, "wildHoneycomb", "blackBear", 0.4, "duskwood_bearhollow") },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(3, { Talk.answer("fur"), Talk.answer("shaggy") }),
})
side({
	id = "side_oldShaggy",
	level = 27,
	giver = "innkeeper",
	turnIn = "beekeeper_maciej",
	arc = "apiary",
	pages = 4,
	requires = { "side_stolenHoney" },
	objectives = {
		{ type = "reach", n = 1, map = "duskwood_den" },
		kill(2, "blackBear", nil, "elite"),
		collect(1, "fatherBell", "blackBear", 1, nil, "elite"),
	},
	final = true,
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(4, {
		Talk.answer("bell", Talk.gift("potion_hp_3", 2)),
		Talk.answer("revenge"),
	}),
	recall = { p1 = "side_stolenHoney" },
})

-- M. The Nameless (24–29), Haunted Ruins -----------------------------------------------------------------------
side({
	id = "side_nameless",
	level = 24,
	giver = "gravedigger_bogumil",
	turnIn = "gravedigger_bogumil",
	arc = "cemetery",
	pages = 3,
	objectives = {
		use({ "dw_grave_1", "dw_grave_2", "dw_grave_3", "dw_grave_4" }, "quest.use.grave", 2, "wreath"),
		kill(8, "ghoul", "duskwood_ruins"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("graves", Talk.focus(1)),
		Talk.answer("ghouls", Talk.focus(2)),
		Talk.answer("pay"),
	}),
})
side({
	id = "side_servantTokens",
	level = 26,
	giver = "gravedigger_bogumil",
	turnIn = "gravedigger_bogumil",
	arc = "cemetery",
	pages = 3,
	requires = { "side_nameless" },
	objectives = { collect(6, "servantToken", "forestWraith", 0.4, "duskwood_ruins") },
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("numbers"), Talk.answer("fear") }),
})
side({
	id = "side_householdRoll",
	level = 27,
	giver = "gravedigger_bogumil",
	turnIn = "brother_anzelm",
	arc = "cemetery",
	pages = 2,
	requires = { "side_servantTokens" },
	objectives = { deliver("householdRoll") },
	wiki = false,
	barks = { accept = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("careful"), Talk.answer("why") }),
})
side({
	id = "side_restingPlace",
	level = 29,
	giver = "brother_anzelm",
	turnIn = "gravedigger_bogumil",
	arc = "cemetery",
	pages = 4,
	requires = { "side_householdRoll" },
	objectives = {
		use({ "dw_ossuary" }, "quest.use.tablet", 3, "candles"),
		kill(10, "forestWraith", "duskwood_ruins"),
	},
	final = true,
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(4, {
		Talk.answer("keep", Talk.gift("potion_mana_3", 2)),
		Talk.answer("ask"),
	}),
	recall = { done = "side_nameless" },
})

-- N. The Cold Rot (27–31), Heart of the Forest ----------------------------------------------------------------------
side({
	id = "side_rotSap",
	level = 27,
	giver = "herbalist_dobrawa",
	turnIn = "herbalist_dobrawa",
	arc = "rot",
	pages = 3,
	objectives = {
		collect(5, "rotSap", "rotEnt", 0.4, "duskwood_heart"),
		{ type = "gather", n = 4, node = "bush_moonpetal" },
	},
	where = { map = "duskwood", area = "duskwood_heart" },
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("sap", Talk.focus(1)),
		Talk.answer("petals", Talk.focus(2)),
		Talk.answer("alch"),
	}),
	-- Dobrawa walks with the player while they gather (she does not fight)
	companion = Talk.follow("herbalist_dobrawa", "duskwood", { 1, 2 }, { join = 2, back = 1 }),
})
side({
	id = "side_ghoulBurrows",
	level = 29,
	giver = "herbalist_dobrawa",
	turnIn = "herbalist_dobrawa",
	arc = "rot",
	pages = 3,
	requires = { "side_rotSap" },
	objectives = {
		use({ "dw_burrow_1", "dw_burrow_2", "dw_burrow_3" }, "quest.use.burrow", 3, "seal"),
		kill(10, "ghoul", "duskwood_heart"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("burrows", Talk.focus(1)),
		Talk.answer("ghouls", Talk.focus(2)),
		Talk.answer("smell"),
	}),
})
side({
	id = "side_rotCure",
	level = 31,
	giver = "herbalist_dobrawa",
	turnIn = "alchemist",
	arc = "rot",
	pages = 3,
	requires = { "side_ghoulBurrows" },
	objectives = { deliver("rotTincture"), kill(8, "rotEnt", "duskwood_heart") },
	final = true,
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("test"), Talk.answer("drink") }),
	recall = { done = "side_rotSap" },
})

-- O. False Waymarks (30–34), Misty Crossroads and the Cultist Village ---------------------------------------------
side({
	id = "side_falseMarks",
	level = 30,
	giver = "warden_zbyszko",
	turnIn = "warden_zbyszko",
	arc = "waymarks",
	pages = 3,
	objectives = {
		use({ "dw_waymark_1", "dw_waymark_2", "dw_waymark_3" }, "quest.use.waymark", 2, "mark"),
		kill(8, "bogSerpent", "duskwood_crossroads"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, { Talk.answer("chalk"), Talk.answer("follow") }),
})
side({
	id = "side_lostLetters",
	level = 32,
	giver = "warden_zbyszko",
	turnIn = "warden_zbyszko",
	arc = "waymarks",
	pages = 3,
	requires = { "side_falseMarks" },
	objectives = { collect(5, "travellerLetter", "darkCultist", 0.35, "duskwood_crossroads") },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("names"), Talk.answer("read") }),
})
side({
	id = "side_cultCages",
	level = 34,
	giver = "warden_zbyszko",
	turnIn = "warden_zbyszko",
	arc = "waymarks",
	pages = 4,
	requires = { "side_lostLetters" },
	objectives = {
		use({ "dw_cage_1", "dw_cage_2" }, "quest.use.cage", 3, "cage"),
		kill(10, "darkCultist", "duskwood_cultvillage"),
	},
	final = true,
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	-- the hint: the yard between the two cages, west of the village's centre
	choices = Talk.onPage(4, {
		Talk.answer("glove"),
		Talk.answer("where", Talk.hint("duskwood", 535, -577, "place.cultCages")),
	}),
	recall = { done = "side_lostLetters" },
})

-- P. The Swamp Toll (34–38), Troll Swamp ----------------------------------------------------------------------------
side({
	id = "side_eelTraps",
	level = 34,
	giver = "ferryman_oldrzych",
	turnIn = "ferryman_oldrzych",
	arc = "ferry",
	pages = 3,
	objectives = {
		use({ "dw_trap_1", "dw_trap_2" }, "quest.use.trap", 2.5, "net"),
		kill(8, "bogSerpent", "duskwood_swamp"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("traps", Talk.focus(1)),
		Talk.answer("snakes", Talk.focus(2)),
		Talk.answer("reeds"),
	}),
})
side({
	id = "side_trollToll",
	level = 36,
	giver = "ferryman_oldrzych",
	turnIn = "ferryman_oldrzych",
	arc = "ferry",
	pages = 3,
	requires = { "side_eelTraps" },
	objectives = { collect(6, "ferryCoin", "swampTroll", 0.4, "duskwood_swamp") },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, { Talk.answer("pay"), Talk.answer("guard") }),
})
side({
	id = "side_trollHoard",
	level = 38,
	giver = "ferryman_oldrzych",
	turnIn = "ferryman_oldrzych",
	arc = "ferry",
	pages = 4,
	requires = { "side_trollToll" },
	objectives = {
		{ type = "reach", n = 1, map = "duskwood", x = 702, z = 612, radius = 24, place = "place.trollVillage" },
		use({ "dw_troll_hoard" }, "quest.use.hoard", 3, "search"),
		kill(8, "swampTroll", "duskwood_swamp"),
	},
	final = true,
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("island", Talk.hint("duskwood", 702, 612, "place.trollVillage")),
		Talk.answer("box"),
	}),
})

-- Q. Hexes of the Marsh (37–40), Witch Marsh ----------------------------------------------------------------------
side({
	id = "side_hexCharms",
	level = 37,
	giver = "exorcist_kalina",
	turnIn = "exorcist_kalina",
	arc = "charms",
	pages = 3,
	objectives = {
		use({ "dw_charm_1", "dw_charm_2", "dw_charm_3" }, "quest.use.charm", 2.5, "ward"),
		kill(8, "marshWitch", "duskwood_witchmarsh"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("bare"),
		Talk.answer("pray", Talk.gift("potion_mana_3", 2)),
	}),
})
side({
	id = "side_hexPouches",
	level = 39,
	giver = "exorcist_kalina",
	turnIn = "brother_anzelm",
	arc = "charms",
	pages = 3,
	requires = { "side_hexCharms" },
	objectives = { collect(5, "hexPouch", "marshWitch", 0.4, "duskwood_witchmarsh") },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("names"), Talk.answer("burn") }),
})
side({
	id = "side_witchCauldron",
	level = 40,
	giver = "brother_anzelm",
	turnIn = "exorcist_kalina",
	arc = "charms",
	pages = 4,
	requires = { "side_hexPouches" },
	objectives = {
		{ type = "reach", n = 1, map = "duskwood", x = -66, z = 122, radius = 18, place = "place.witchHut" },
		use({ "dw_cauldron" }, "quest.use.cauldron", 3, "spill"),
		kill(6, "swampTroll", "duskwood_witchmarsh"),
	},
	final = true,
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(3, {
		Talk.answer("cauldron", Talk.focus(2)),
		Talk.answer("trolls", Talk.focus(3)),
		Talk.answer("kalina"),
	}),
	recall = { p1 = "side_hexPouches" },
})

-- R. The Stonemason's Apprentice (41–44), Blood Cliffs and the Crypt ----------------------------------------------
side({
	id = "side_roadCut",
	level = 41,
	giver = "mason_wojslaw",
	turnIn = "mason_wojslaw",
	arc = "masons",
	pages = 3,
	objectives = {
		use({ "dw_shore_1", "dw_shore_2", "dw_shore_3" }, "quest.use.shore", 3, "plank"),
		kill(10, "bloodBat", "duskwood_bloodcliffs"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("beams", Talk.focus(1)),
		Talk.answer("bats", Talk.focus(2)),
		Talk.answer("stone"),
	}),
})
side({
	id = "side_batRoost",
	level = 42,
	giver = "mason_wojslaw",
	turnIn = "mason_wojslaw",
	arc = "masons",
	pages = 3,
	requires = { "side_roadCut" },
	objectives = {
		{ type = "reach", n = 1, map = "duskwood", x = 616, z = -40, radius = 20, place = "place.batRoost" },
		collect(5, "apprenticeChisel", "bloodBat", 0.35, "duskwood_bloodcliffs"),
	},
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("leszek"), Talk.answer("bats") }),
})
side({
	id = "side_apprentice",
	level = 44,
	giver = "mason_wojslaw",
	turnIn = "mason_wojslaw",
	arc = "masons",
	pages = 4,
	requires = { "side_batRoost" },
	objectives = {
		{ type = "reach", n = 1, map = "duskwood_cave" },
		kill(2, "skeletonGuard", nil, "elite"),
		collect(1, "apprenticeRing", "skeletonGuard", 1, nil, "elite"),
	},
	final = true,
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(4, { Talk.answer("lay"), Talk.answer("bring") }),
})

-- S106: the EXP of the quests waiting in `pending`: for each band holding one, TARGET.side of the band's EXP minus the
-- fixed rewards of its other side quests from BAND_FROM (the stable arc), split by expToNext(level) × weight.
local function settleBands()
	local bands: { number } = {}
	for _, quest in list do
		local lo = QuestBudget.bandOf(quest.level)
		if pending[quest] and not table.find(bands, lo) then
			table.insert(bands, lo)
		end
	end
	table.sort(bands)
	for _, lo in bands do
		local fixed, weights = 0, 0
		for _, quest in list do
			if quest.level >= BAND_FROM and QuestBudget.bandOf(quest.level) == lo then
				local weight = pending[quest]
				if weight then
					weights += Exp.expToNext(quest.level) * weight
				else
					fixed += quest.reward.exp
				end
			end
		end
		local budget = math.floor(QuestBudget.bandExp(lo) * QuestBudgetData.TARGET.side) - fixed
		assert(budget > 0, `Side: the fixed side quests of the band from {lo} use up its budget ({fixed} EXP)`)
		local scale = budget / weights
		BAND_SCALE[lo] = scale
		for _, quest in list do
			local weight = pending[quest]
			if weight and QuestBudget.bandOf(quest.level) == lo then
				quest.reward.exp = math.floor(Exp.expToNext(quest.level) * weight * scale)
			end
		end
	end
end
settleBands()

-- Arcs in journal order (one per Meadows area; S96: the stable last; S106: the Duskwood arcs by level).
local ARCS = {
	"farm",
	"shrine",
	"pond",
	"forest",
	"mill",
	"road",
	"quarry",
	"goblins",
	"ravine",
	"stable",
	"lanterns",
	"apiary",
	"cemetery",
	"rot",
	"waymarks",
	"ferry",
	"charms",
	"masons",
}

local byId: { [string]: SideQuest } = {}
local byArc: { [string]: { SideQuest } } = {}
for _, quest in list do
	assert(byId[quest.id] == nil, `duplicate side quest {quest.id}`)
	byId[quest.id] = quest
	local arc = byArc[quest.arc]
	if not arc then
		arc = {}
		byArc[quest.arc] = arc
	end
	table.insert(arc, quest)
end

return table.freeze({
	list = list,
	byId = byId,
	byArc = byArc,
	ARCS = ARCS,
	FX = FX,
	STABLE_MIN = STABLE_MIN,
	-- S106: the band budget of side quests from level 20 (BAND_SCALE: band's first level -> EXP per expToNext × weight)
	BAND_FROM = BAND_FROM,
	GOLD_FROM_20 = GOLD_FROM_20,
	WEIGHT = WEIGHT,
	BAND_SCALE = table.freeze(BAND_SCALE),
	get = function(id: string): SideQuest?
		return byId[id]
	end,
})
