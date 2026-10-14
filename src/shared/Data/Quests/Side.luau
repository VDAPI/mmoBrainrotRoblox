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
-- S107: Ashen Wastes side arcs (levels 45–68) on the same band budget (band 45–69, BAND_SCALE[45]); anchors and NPC
-- places in Data/Areas/ashen (ash_* anchors), props in Logic/AshenGen/Quest.
-- S108: Frost Peaks side arcs (levels 70–99) on the same band budget (band 70–99, BAND_SCALE[70]); anchors and NPC
-- places in Data/Areas/frostpeak (fp_* anchors), the NPCs' camps in Logic/FrostpeakGen/SideCamps.

local AshenAreas = require("../Areas/ashen")
local Exp = require("../../Logic/Exp")
local FrostAreas = require("../Areas/frostpeak")
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
	-- S107 (the Ashen side arcs; drawn at the anchor's prop when Logic/AshenGen/Quest has one):
	cairn = true, -- S107: a basalt warning cairn with a red rag
	water = true, -- S107: a dug-out well with dark water
	incense = true, -- S107: smouldering herbs on stones
	drum = true, -- S107: the war drum's skin slashed
	mirror = true, -- S107: a polished shield on a stake facing the den
	-- S108 (the Frost Peaks side arcs; fp_watch_gate uses `candles`):
	cairnOffering = true, -- S108: a flat stone with a bowl of tallow, a bone and a small flame at the Howling Rock
	ribbons = true, -- S108: a stick in the cairn with four cloth ribbons (red, blue, gold, grey)
	snare = true, -- S108: a stake with a wire loop and a red rag
	sledgeRunner = true, -- S108: a new, pale runner beside the sledge, two rope lashings
	dugHorn = true, -- S108: a pit dug in the snow, two snow banks and the long dark horn with its iron band
	toppled = true, -- S108: three scattered boulders and the dark track of their slide
	runeRubbing = true, -- S108: a sheet of parchment pinned to a stone with two lines of charcoal
	runeCarving = true, -- S108: a slab with carved signs glowing pale blue
	iceChipped = true, -- S108: four chipped blocks of ice and a pick leaning on one
	tuskPost = true, -- S108: a post with two tusks lashed on with leather
	juniper = true, -- S108: a sprig of juniper and a small candle
	eggShards = true, -- S108: pale blue eggshells and a dark stain
}

local list: { SideQuest } = {}
-- S106: quests of a band from BAND_FROM without expShare, waiting for settleBands (the weight of each)
local pending: { [SideQuest]: number } = {}
local BAND_SCALE: { [number]: number } = {}

-- The fields of one side quest's definition (S108: named, so the regional constructors keep the types).
type SideDef = {
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

local function side(def: SideDef)
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

-- Ashen Wastes (S107, docs/DESIGN-15.md §3.4): eight arcs, one per corner of the Wastes, with five new NPCs on
-- Areas/ashen npcSpots and the chapter III NPCs of S104 (Ghasha, Kaspar); anchors in Areas/ashen questAnchors (ash_*).
-- EXP from the 45–69 band's side budget (S106 settleBands, DESIGN-15 §3.2 TARGET.side); the S98 model counts
-- SIDE_SHARE of it and compensates monster EXP. Every Ashen arc is off the wiki until S109 (`wiki = false`).
local ASH_SITES = assert(AshenAreas.sites, "Side: ashen sites")
local MINE = ASH_SITES.mineMouth

-- S. Fire in the Cracks (45–48), Salamander Flats: Kesra's scouts burnt by the cracks, hyenas hunting the wounded ---
side({
	id = "side_ash_salve",
	level = 45,
	giver = "alchemist",
	turnIn = "scout_ashen",
	arc = "ashSalamanders",
	pages = 2,
	objectives = { deliver("emberSalve") },
	wiki = false,
	barks = { accept = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("hurry"), Talk.answer("enough", Talk.gift("potion_hp_4", 2)) }),
})
side({
	id = "side_ash_glands",
	level = 46,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	arc = "ashSalamanders",
	pages = 3,
	requires = { "side_ash_salve" },
	objectives = {
		collect(6, "fireGland", "salamander", 0.5, "ashen_flats"),
		use({ "ash_cairn_1", "ash_cairn_2", "ash_cairn_3" }, "quest.use.cairn", 2, "cairn"),
	},
	where = { map = "ashen", area = "ashen_flats" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("rag"),
		Talk.answer("cairns", Talk.focus(2)),
		Talk.answer("glands", Talk.focus(1)),
	}),
})
side({
	id = "side_ash_den",
	level = 48,
	giver = "scout_ashen",
	turnIn = "scout_ashen",
	arc = "ashSalamanders",
	pages = 3,
	requires = { "side_ash_glands" },
	objectives = {
		kill(12, "wasteHyena", "ashen_flats"),
		use({ "ash_hyena_skull" }, "quest.use.smoke", 3, "fire"),
	},
	final = true,
	where = { map = "ashen", area = "ashen_flats" },
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("pitch"),
		Talk.answer("count"),
		Talk.answer("smoke", Talk.focus(2)),
	}),
	recall = { done = "side_ash_glands" },
})

-- T. The Last Water (46–49), Dead Oasis: old Orren, the wells under the sand and the merchants' seals --------------
side({
	id = "side_ash_cask",
	level = 46,
	giver = "innkeeper",
	turnIn = "waterkeeper_orren",
	arc = "ashOasis",
	pages = 2,
	objectives = { deliver("waterCask") },
	wiki = false,
	barks = { accept = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("wine"), Talk.answer("who") }),
})
side({
	id = "side_ash_wells",
	level = 47,
	giver = "waterkeeper_orren",
	turnIn = "waterkeeper_orren",
	arc = "ashOasis",
	pages = 3,
	requires = { "side_ash_cask" },
	objectives = {
		-- Orren leads from the jetty over the dry bed to the stranded boat (route checked in tests/ashen.spec S107)
		Talk.escort("waterkeeper_orren", "ashen", -630, 630, 12, "place.strandedBoat", { { x = -600, z = 570 } }),
		use({ "ash_stranded_boat" }, "quest.use.boat", 2, "search"),
		use({ "ash_well_1", "ash_well_2", "ash_well_3" }, "quest.use.well", 3, "water"),
	},
	where = { map = "ashen", area = "ashen_oasis" },
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(1, { Talk.answer("dead"), Talk.answer("boat"), Talk.answer("alone") }),
	companion = Talk.lead("waterkeeper_orren", "ashen", { 1 }, { join = 1, wait = 2, arrive = 1, back = 1 }),
})
side({
	id = "side_ash_seals",
	level = 49,
	giver = "waterkeeper_orren",
	turnIn = "waterkeeper_orren",
	arc = "ashOasis",
	pages = 3,
	requires = { "side_ash_wells" },
	objectives = {
		kill(8, "wasteHyena", "ashen_oasis"),
		collect(5, "caravanSeal", "ashVulture", 0.4, "ashen_oasis"),
	},
	final = true,
	where = { map = "ashen", area = "ashen_oasis" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("families"), Talk.answer("wells", Talk.focus(1)) }),
	recall = { p1 = "side_ash_wells" },
})

-- U. Blood and Ash (50–53), the Hot Spring and the Ash Orc Warcamp: Ghasha (freed in warcampCages) and the young ----
side({
	id = "side_ash_rite",
	level = 50,
	giver = "shaman_ghasha",
	turnIn = "shaman_ghasha",
	arc = "ashSpring",
	pages = 3,
	requires = { "warcampCages" },
	objectives = {
		use({ "ash_spring_stones" }, "quest.use.rite", 3, "incense"),
		{ type = "gather", n = 4, node = "bush_firebloom" },
	},
	where = { map = "ashen", area = "ashen_flats" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("smell"), Talk.answer("cage"), Talk.answer("herbs", Talk.focus(2)) }),
})
side({
	id = "side_ash_drum",
	level = 51,
	giver = "shaman_ghasha",
	turnIn = "shaman_ghasha",
	arc = "ashSpring",
	pages = 3,
	requires = { "side_ash_rite" },
	objectives = {
		kill(10, "ashOrc", "ashen_warcamp"),
		use({ "ash_war_drum" }, "quest.use.drum", 3, "drum"),
	},
	where = { map = "ashen", area = "ashen_warcamp" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(1, { Talk.answer("gold"), Talk.answer("chief") }),
})
side({
	id = "side_ash_fang",
	level = 53,
	giver = "shaman_ghasha",
	turnIn = "shaman_ghasha",
	arc = "ashSpring",
	pages = 4,
	requires = { "side_ash_drum" },
	objectives = {
		kill(8, "ashOrc", "ashen_warcamp"),
		use({ "ash_chief_tent" }, "quest.use.tent", 3, "search"),
	},
	final = true,
	where = { map = "ashen", area = "ashen_warcamp" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("pledge"), Talk.answer("young") }),
	recall = { done = "side_ash_rite" },
})

-- V. Silver and Mithril (50–56), the warcamp's dump, the Abandoned Mine and the Golem Fields: Dragan's debts ---------
side({
	id = "side_ash_silver",
	level = 50,
	giver = "prospector_dragan",
	turnIn = "prospector_dragan",
	arc = "ashProspector",
	pages = 2,
	objectives = {
		{ type = "gather", n = 6, node = "vein_silver" },
		kill(8, "ashVulture", "ashen_warcamp"),
	},
	where = { map = "ashen", area = "ashen_warcamp" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("debt"), Talk.answer("town"), Talk.answer("vultures", Talk.focus(2)) }),
})
side({
	id = "side_ash_partners",
	level = 52,
	giver = "prospector_dragan",
	turnIn = "prospector_dragan",
	arc = "ashProspector",
	pages = 3,
	requires = { "side_ash_silver" },
	objectives = {
		{ type = "reach", n = 1, map = "ashen_mine" },
		collect(3, "minerTag", "wasteHyena", 0.5, nil, "elite"),
	},
	where = { map = "ashen_mine" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	-- the hint: the ground before the mine's adit (the cave arrival, 26 studs out of the mouth)
	choices = Talk.onPage(1, {
		Talk.answer("names"),
		Talk.answer("way", Talk.hint("ashen", MINE.x, MINE.z + 26, "map.ashen_mine.name")),
	}),
})
side({
	id = "side_ash_columns",
	level = 54,
	giver = "prospector_dragan",
	turnIn = "prospector_dragan",
	arc = "ashProspector",
	pages = 3,
	requires = { "side_ash_partners" },
	objectives = {
		kill(10, "fireGolem", "ashen_golemfields"),
		use({ "ash_columns_sample" }, "quest.use.sample", 3, "mark"),
	},
	where = { map = "ashen", area = "ashen_golemfields" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("dream"), Talk.answer("sample", Talk.focus(2)) }),
})
side({
	id = "side_ash_claim",
	level = 56,
	giver = "prospector_dragan",
	turnIn = "blacksmith",
	arc = "ashProspector",
	pages = 3,
	requires = { "side_ash_columns" },
	objectives = {
		{ type = "gather", n = 4, node = "vein_mithril" },
		use({ "ash_dragan_claim" }, "quest.use.claim", 2, "tracks"),
	},
	final = true,
	where = { map = "ashen", area = "ashen_golemfields" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("share"), Talk.answer("dorgan") }),
	recall = { done = "side_ash_silver" },
})

-- W. Names of the Dead (57–61), Burnt Ruins: Kaspar (after burntTemple) writes down the dead and the taken -----------
side({
	id = "side_ash_chimneys",
	level = 57,
	giver = "hermit_kaspar",
	turnIn = "hermit_kaspar",
	arc = "ashRuins",
	pages = 3,
	requires = { "burntTemple" },
	objectives = {
		kill(10, "fireImp", "ashen_burntruins"),
		use({ "ash_hearth_1", "ash_hearth_2", "ash_hearth_3" }, "quest.use.names", 2, "candles"),
	},
	where = { map = "ashen", area = "ashen_burntruins" },
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("why"), Talk.answer("knew"), Talk.answer("imps", Talk.focus(1)) }),
})
side({
	id = "side_ash_heirlooms",
	level = 59,
	giver = "hermit_kaspar",
	turnIn = "hermit_kaspar",
	arc = "ashRuins",
	pages = 3,
	requires = { "side_ash_chimneys" },
	objectives = {
		use({ "ash_dry_fountain" }, "quest.use.fountain", 3, "search"),
		collect(5, "heirloom", "desertScorpion", 0.4, "ashen_burntruins"),
	},
	where = { map = "ashen", area = "ashen_burntruins" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("water"), Talk.answer("drifts", Talk.focus(2)) }),
})
side({
	id = "side_ash_names",
	level = 61,
	giver = "hermit_kaspar",
	turnIn = "brother_anzelm",
	arc = "ashRuins",
	pages = 3,
	requires = { "side_ash_heirlooms" },
	objectives = { kill(8, "desertScorpion", "ashen_burntruins"), deliver("kasparList") },
	final = true,
	where = { map = "ashen", area = "ashen_burntruins" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("forge"), Talk.answer("anzelm") }),
	recall = { p2 = "side_ash_chimneys" },
})

-- X. The Crag Hunt (58–62), Wyvern Crags: Wiesława, Mirko turning to stone, the great nest --------------------------
side({
	id = "side_ash_lookout",
	level = 58,
	giver = "wyvernhunter_wieslawa",
	turnIn = "wyvernhunter_wieslawa",
	arc = "ashCrags",
	pages = 3,
	objectives = {
		kill(10, "wyvern", "ashen_crags"),
		use({ "ash_wyvern_lookout" }, "quest.use.lookout", 2, "tracks"),
	},
	where = { map = "ashen", area = "ashen_crags" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(1, { Talk.answer("bold"), Talk.answer("driven"), Talk.answer("mark", Talk.focus(2)) }),
})
side({
	id = "side_ash_eyes",
	level = 60,
	giver = "wyvernhunter_wieslawa",
	turnIn = "alchemist",
	arc = "ashCrags",
	pages = 3,
	requires = { "side_ash_lookout" },
	objectives = { collect(4, "basiliskEye", "basilisk", 0.4, "ashen_crags") },
	where = { map = "ashen", area = "ashen_crags" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("mirko"), Talk.answer("road", Talk.gift("potion_mana_3", 2)) }),
})
side({
	id = "side_ash_nest",
	level = 62,
	giver = "alchemist",
	turnIn = "wyvernhunter_wieslawa",
	arc = "ashCrags",
	pages = 3,
	requires = { "side_ash_eyes" },
	objectives = {
		deliver("stoneDraught"),
		use({ "ash_great_nest" }, "quest.use.nest", 3, "fire"),
	},
	final = true,
	where = { map = "ashen", area = "ashen_crags" },
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("draught", Talk.focus(1)), Talk.answer("nest", Talk.focus(2)) }),
	recall = { done = "side_ash_lookout" },
})

-- Y. The Sleep of Kings (63–68), Scorpion Dunes and Desert Tombs: Ezra, the masks of the Ash Kings ----------------
local KING = ASH_SITES.buriedKing
side({
	id = "side_ash_king",
	level = 63,
	giver = "tombwarden_ezra",
	turnIn = "tombwarden_ezra",
	arc = "ashTombs",
	pages = 3,
	objectives = {
		-- Ezra leads along the main road and up the sand road's cut, away from the courtyards (tests/ashen.spec S107)
		Talk.escort("tombwarden_ezra", "ashen", KING.x, KING.z, 24, "place.buriedKing", {
			{ x = 560, z = 10 },
			{ x = 420, z = -6 },
			{ x = 290, z = 50 },
			{ x = 360, z = 215 },
			{ x = 420, z = 360 },
			{ x = 490, z = 460 },
		}),
		kill(12, "desertMummy", "ashen_dunes"),
	},
	where = { map = "ashen", area = "ashen_dunes" },
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1, death = 1 },
	choices = Talk.onPage(1, { Talk.answer("faces"), Talk.answer("legs"), Talk.answer("lead") }),
	companion = Talk.lead("tombwarden_ezra", "ashen", { 1 }, { join = 1, wait = 1, arrive = 1, back = 1 }),
})
side({
	id = "side_ash_wards",
	level = 64,
	giver = "tombwarden_ezra",
	turnIn = "tombwarden_ezra",
	arc = "ashTombs",
	pages = 3,
	requires = { "side_ash_king" },
	objectives = {
		use({ "ash_sarcophagus_1", "ash_sarcophagus_2", "ash_sarcophagus_3" }, "quest.use.ward", 2, "rune"),
		kill(8, "desertScorpion", "ashen_dunes"),
	},
	where = { map = "ashen", area = "ashen_dunes" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("sign"), Talk.answer("scorp", Talk.focus(2)) }),
	recall = { p1 = "side_ash_king" },
})
side({
	id = "side_ash_altar",
	level = 66,
	giver = "tombwarden_ezra",
	turnIn = "tombwarden_ezra",
	arc = "ashTombs",
	pages = 3,
	requires = { "side_ash_wards" },
	objectives = {
		kill(10, "desertMummy", "ashen_tombs"),
		use({ "ash_courtyard_altar" }, "quest.use.altar", 3, "incense"),
	},
	where = { map = "ashen", area = "ashen_tombs" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("priest"), Talk.answer("potions", Talk.gift("potion_hp_4", 2)) }),
})
side({
	id = "side_ash_masks",
	level = 68,
	giver = "tombwarden_ezra",
	turnIn = "tombwarden_ezra",
	arc = "ashTombs",
	pages = 4,
	requires = { "side_ash_altar" },
	objectives = {
		collect(3, "funeralMask", "desertMummy", 0.35, "ashen_tombs"),
		use({ "ash_pyramid_door" }, "quest.use.door", 3, "rune"),
	},
	final = true,
	where = { map = "ashen", area = "ashen_tombs" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(3, { Talk.answer("door"), Talk.answer("after") }),
	recall = { p4 = "side_ash_king" },
})

-- Z. The Salt Caravans (64–67), Ash Road: Bogna's caravan, the toll coins and the shield at the basilisk's pit ------
-- (not `ashRoad`: that is the story quest of S104; Bogna's is another, later caravan)
local AVENUE = ASH_SITES.kingsAvenue
side({
	id = "side_ash_wagons",
	level = 64,
	giver = "wagoner_bogna",
	turnIn = "wagoner_bogna",
	arc = "ashCaravans",
	pages = 3,
	objectives = {
		use({ "ash_wagon_1", "ash_wagon_2", "ash_wagon_3" }, "quest.use.wagon", 2, "crate"),
		kill(10, "basilisk", "ashen_ashroad"),
	},
	where = { map = "ashen", area = "ashen_ashroad" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("oxen"),
		Talk.answer("husband"),
		Talk.answer("basilisks", Talk.focus(2)),
	}),
})
side({
	id = "side_ash_avenue",
	level = 65,
	giver = "wagoner_bogna",
	turnIn = "wagoner_bogna",
	arc = "ashCaravans",
	pages = 2,
	requires = { "side_ash_wagons" },
	objectives = {
		{ type = "reach", n = 1, map = "ashen", x = AVENUE.x, z = AVENUE.z, radius = 24, place = "place.kingsAvenue" },
		collect(5, "tollCoin", "wyvern", 0.4, "ashen_ashroad"),
	},
	where = { map = "ashen", area = "ashen_ashroad" },
	wiki = false,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(1, { Talk.answer("kings"), Talk.answer("toll") }),
})
side({
	id = "side_ash_mirror",
	level = 67,
	giver = "wagoner_bogna",
	turnIn = "wagoner_bogna",
	arc = "ashCaravans",
	pages = 3,
	requires = { "side_ash_avenue" },
	objectives = {
		kill(12, "basilisk", "ashen_ashroad"),
		use({ "ash_basilisk_den" }, "quest.use.mirror", 3, "mirror"),
	},
	final = true,
	where = { map = "ashen", area = "ashen_ashroad" },
	wiki = false,
	barks = { accept = 1, half = 1, near = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("shield"), Talk.answer("faith") }),
	recall = { done = "side_ash_wagons" },
})

-- Frost Peaks (S108, 70–99): eight arcs, docs/DESIGN-15.md §3.4 ------------------------------------------------------
-- Seven new NPCs on Areas/frostpeak npcSpots (camps in Logic/FrostpeakGen/SideCamps), Sigrun of S105 and two NPCs of
-- the city / the scout; anchors in Areas/frostpeak questAnchors (fp_*). EXP from the 70–99 band's side budget (S106
-- settleBands, BAND_SCALE[70], DESIGN-15 §3.2 TARGET.side); the S98 model counts SIDE_SHARE of it and compensates
-- monster EXP. Every Frost Peaks arc is off the wiki until S109 (`wiki = false`, set by `fp`).
local FP_SITES = assert(FrostAreas.sites, "Side: frostpeak sites")
local FP_SPOTS = assert(FrostAreas.npcSpots, "Side: frostpeak npc spots")

local function fp(def: SideDef)
	def.wiki = false
	side(def)
end

-- A `reach` objective with a named place on a map.
local function reachPlace(map: string, x: number, z: number, radius: number, place: string): Objective
	return { type = "reach", n = 1, map = map, x = x, z = z, radius = radius, place = place }
end

-- A `reach` objective of a cave (the elites of the next objectives live there).
local function reachCave(map: string): Objective
	return { type = "reach", n = 1, map = map }
end

-- Where a player comes out of a cave mouth of the Peaks (22 studs before it, tests/frostpeak.spec standingPlaces).
local function caveExit(cave: string): (number, number)
	for _, c in FrostAreas.caves do
		if c.cave == cave then
			local a = math.rad(c.rot)
			return c.x - math.sin(a) * 22, c.z - math.cos(a) * 22
		end
	end
	error(`Side: no frostpeak cave {cave}`)
end

local function sitePoint(name: string): (number, number)
	local s = FP_SITES[name]
	return s.x, s.z
end

-- A. The Horned Cairn (70–73), Ice Wolf Valley: Old Ingrid keeps the ribbons of those who went up the mountains ------
fp({
	id = "side_fp_flask",
	level = 70,
	minLevel = 70,
	giver = "scout_frostpeak",
	turnIn = "cairn_ingrid",
	arc = "fp_cairn",
	pages = 2,
	objectives = { deliver("halvarFlask") },
	barks = { accept = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("drink"), Talk.answer("who"), Talk.answer("word") }),
})
fp({
	id = "side_fp_ribbons",
	level = 71,
	minLevel = 70,
	giver = "cairn_ingrid",
	turnIn = "cairn_ingrid",
	arc = "fp_cairn",
	pages = 3,
	requires = { "side_fp_flask" },
	objectives = {
		kill(10, "iceWolf", "frostpeak_valley"),
		collect(6, "cairnRibbon", "iceWolf", 0.4, "frostpeak_valley"),
	},
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, { Talk.answer("names"), Talk.answer("wolves"), Talk.answer("first", Talk.focus(2)) }),
})
local HOWL_X, HOWL_Z = sitePoint("howlRock")
fp({
	id = "side_fp_howl",
	level = 73,
	giver = "cairn_ingrid",
	turnIn = "cairn_ingrid",
	arc = "fp_cairn",
	pages = 3,
	requires = { "side_fp_ribbons" },
	objectives = {
		use({ "fp_howl_offering" }, "quest.use.offering", 3, "cairnOffering"),
		use({ "fp_cairn_ribbons" }, "quest.use.ribbons", 2, "ribbons"),
	},
	final = true,
	barks = { accept = 1, near = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("believe"),
		Talk.answer("little"),
		Talk.answer("road", Talk.hint("frostpeak", HOWL_X, HOWL_Z, "place.howlRock")),
	}),
	recall = { done = "side_fp_ribbons" },
})

-- B. The Trappers' Last Catch (74–78), the trappers' camp and the Leopards' Ledge: Sigrun of S105 after the Grotto ----
fp({
	id = "side_fp_snares",
	level = 74,
	giver = "trapper_sigrun",
	turnIn = "trapper_sigrun",
	arc = "fp_trappers",
	pages = 3,
	requires = { "trappersCamp" },
	objectives = {
		use({ "fp_snare_1", "fp_snare_2", "fp_snare_3" }, "quest.use.snare", 2, "snare"),
		kill(8, "snowLeopard", "frostpeak_valley"),
	},
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, { Talk.answer("eat"), Talk.answer("learn"), Talk.answer("which", Talk.focus(2)) }),
})
fp({
	id = "side_fp_ledge",
	level = 76,
	giver = "trapper_sigrun",
	turnIn = "trapper_sigrun",
	arc = "fp_trappers",
	pages = 3,
	requires = { "side_fp_snares", "iceGrotto" },
	objectives = {
		-- Sigrun leads south along the brook's east bank, off its ice (route checked in tests/frostpeak.spec S108)
		Talk.escort("trapper_sigrun", "frostpeak", -582, -286, 14, "place.leopardLedge", {
			{ x = -556, z = -204 },
			{ x = -568, z = -240 },
			{ x = -578, z = -268 },
		}),
		collect(1, "arneKnife", "snowLeopard", 0.3, "frostpeak_valley"),
	},
	barks = { accept = 1, near = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("knife"), Talk.answer("alone"), Talk.answer("lead") }),
	companion = Talk.lead("trapper_sigrun", "frostpeak", { 1 }, { join = 1, wait = 1, arrive = 1, back = 1 }),
})
fp({
	id = "side_fp_sledge",
	level = 78,
	giver = "trapper_sigrun",
	turnIn = "trapper_sigrun",
	arc = "fp_trappers",
	pages = 4,
	requires = { "side_fp_ledge" },
	objectives = {
		use({ "fp_trapper_sledge" }, "quest.use.sledge", 3, "sledgeRunner"),
		kill(10, "snowLeopard", "frostpeak_slopes"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("bury"),
		Talk.answer("stay"),
		Talk.answer("rope", Talk.gift("potion_hp_5", 2)),
	}),
	recall = { done = "side_fp_ledge" },
})

-- C. The Avalanche Horn (77–80), the Yeti Slopes and the Ice Grotto: Eskil, whose kin blow the warning horn ---------
local CONE_X, CONE_Z = sitePoint("avalanche")
local GROTTO_X, GROTTO_Z = caveExit("frostpeak_grotto")
fp({
	id = "side_fp_horn",
	level = 77,
	giver = "hornblower_eskil",
	turnIn = "hornblower_eskil",
	arc = "fp_horn",
	pages = 3,
	objectives = {
		use({ "fp_avalanche_horn" }, "quest.use.digHorn", 3, "dugHorn"),
		kill(10, "yeti", "frostpeak_slopes"),
	},
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("count"),
		Talk.answer("why"),
		Talk.answer("where", Talk.hint("frostpeak", CONE_X, CONE_Z, "place.avalanche")),
	}),
})
fp({
	id = "side_fp_boulders",
	level = 79,
	giver = "hornblower_eskil",
	turnIn = "hornblower_eskil",
	arc = "fp_horn",
	pages = 3,
	requires = { "side_fp_horn" },
	objectives = {
		use({ "fp_boulders_1", "fp_boulders_2", "fp_boulders_3" }, "quest.use.topple", 2, "toppled"),
		kill(8, "snowLeopard", "frostpeak_slopes"),
	},
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, { Talk.answer("purpose"), Talk.answer("nobody"), Talk.answer("cats", Talk.focus(2)) }),
})
fp({
	id = "side_fp_matriarch",
	level = 80,
	giver = "hornblower_eskil",
	turnIn = "hornblower_eskil",
	arc = "fp_horn",
	pages = 3,
	requires = { "side_fp_boulders" },
	objectives = {
		reachCave("frostpeak_grotto"),
		kill(3, "yeti", nil, "elite"),
		collect(1, "hornMouthpiece", "yeti", 1, nil, "elite"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("trinkets"),
		Talk.answer("flee"),
		Talk.answer("cave", Talk.hint("frostpeak", GROTTO_X, GROTTO_Z, "map.frostpeak_grotto.name")),
	}),
	recall = { done = "side_fp_horn" },
})

-- D. The Giants' Saga (82–86), the Giants' Pass: Ragnvald the skald and the runes of the colossi and the thrones -----
local THRONES_X, THRONES_Z = sitePoint("thrones")
fp({
	id = "side_fp_colossi",
	level = 82,
	giver = "skald_ragnvald",
	turnIn = "skald_ragnvald",
	arc = "fp_saga",
	pages = 3,
	objectives = {
		use({ "fp_colossus_north", "fp_colossus_south" }, "quest.use.rubbing", 3, "runeRubbing"),
		kill(10, "frostGiant", "frostpeak_pass"),
	},
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("sing"),
		Talk.answer("giants"),
		Talk.answer("charcoal", Talk.gift("potion_mana_5", 2)),
	}),
})
fp({
	id = "side_fp_thrones",
	level = 84,
	giver = "skald_ragnvald",
	turnIn = "skald_ragnvald",
	arc = "fp_saga",
	pages = 3,
	requires = { "side_fp_colossi" },
	objectives = {
		reachPlace("frostpeak", THRONES_X, THRONES_Z, 22, "place.thrones"),
		collect(3, "throneRune", "frostGiant", 0.35, "frostpeak_pass"),
	},
	barks = { accept = 1, near = 1, half = 1, done = 1, death = 1, stuck = 1 },
	choices = Talk.onPage(2, { Talk.answer("come"), Talk.answer("danger"), Talk.answer("why") }),
	-- Ragnvald walks with the player from the Gate to the Hall of Thrones and stays while the runes are taken
	companion = Talk.follow("skald_ragnvald", "frostpeak", { 1, 2 }, { join = 2, back = 1 }),
})
fp({
	id = "side_fp_verse",
	level = 86,
	giver = "skald_ragnvald",
	turnIn = "skald_ragnvald",
	arc = "fp_saga",
	pages = 4,
	requires = { "side_fp_thrones" },
	objectives = {
		collect(4, "sagaPage", "peakHarpy", 0.4, "frostpeak_pass"),
		use({ "fp_saga_stone" }, "quest.use.carve", 3, "runeCarving"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("write"), Talk.answer("harpies"), Talk.answer("truth") }),
	recall = { p1 = "side_fp_thrones" },
})

-- E. The Ice Hole (85–89), the Frozen Lake: Torvi, his father's boat in the ice and the drowned village's hoard -------
local BOAT_X, BOAT_Z = sitePoint("frozenBoat")
fp({
	id = "side_fp_icehole",
	level = 85,
	giver = "icefisher_torvi",
	turnIn = "icefisher_torvi",
	arc = "fp_icefish",
	pages = 2,
	objectives = {
		{ type = "fish", n = 3 },
		kill(8, "iceElemental", "frostpeak_lake"),
	},
	where = { map = "frostpeak", area = "frostpeak_lake" },
	barks = { accept = 1, near = 1, half = 1, done = 1 },
	choices = Talk.onPage(1, {
		Talk.answer("bait"),
		Talk.answer("why"),
		Talk.answer("where", Talk.hint("frostpeak", BOAT_X, BOAT_Z, "place.frozenBoat")),
	}),
})
fp({
	id = "side_fp_boat",
	level = 87,
	giver = "icefisher_torvi",
	turnIn = "icefisher_torvi",
	arc = "fp_icefish",
	pages = 3,
	requires = { "side_fp_icehole" },
	objectives = {
		-- Torvi leads east along the shore, down the gentle cut onto the ice and round to the boat, 30+ studs from the
		-- ice hole (tests/frostpeak.spec S108)
		Talk.escort("icefisher_torvi", "frostpeak", 192, 550, 10, "place.frozenBoat", {
			{ x = 190, z = 432 },
			{ x = 238, z = 472 },
			{ x = 226, z = 512 },
		}),
		use({ "fp_frozen_boat" }, "quest.use.chipIce", 3, "iceChipped"),
		collect(4, "frostCore", "iceElemental", 0.4, "frostpeak_lake"),
	},
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("lead"), Talk.answer("father"), Talk.answer("straight") }),
	companion = Talk.lead("icefisher_torvi", "frostpeak", { 1, 2 }, { join = 1, wait = 1, arrive = 1, back = 1 }),
})
fp({
	id = "side_fp_hoard",
	level = 89,
	giver = "icefisher_torvi",
	turnIn = "icefisher_torvi",
	arc = "fp_icefish",
	pages = 3,
	requires = { "side_fp_boat" },
	objectives = {
		use({ "fp_hoard_1", "fp_hoard_2", "fp_hoard_3" }, "quest.use.chipIce", 2, "iceChipped"),
		kill(8, "iceMammoth", "frostpeak_lake"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("families"), Talk.answer("keep"), Talk.answer("mammoths", Talk.focus(2)) }),
	recall = { done = "side_fp_icehole" },
})

-- F. The Mammoth Graveyard (87–91), the Mammoth Tundra and the Frozen Hold: Gunnar and the herds driven to war ------
local HOLD_X, HOLD_Z = caveExit("frostpeak_hold")
fp({
	id = "side_fp_tusks",
	level = 87,
	giver = "bonecarver_gunnar",
	turnIn = "bonecarver_gunnar",
	arc = "fp_bones",
	pages = 3,
	objectives = {
		collect(5, "mammothTusk", "iceMammoth", 0.4, "frostpeak_tundra"),
		use({ "fp_tusk_arch" }, "quest.use.tusks", 2, "tuskPost"),
	},
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("rule"), Talk.answer("carve"), Talk.answer("arch") }),
})
fp({
	id = "side_fp_stampede",
	level = 89,
	giver = "bonecarver_gunnar",
	turnIn = "bonecarver_gunnar",
	arc = "fp_bones",
	pages = 3,
	requires = { "side_fp_tusks" },
	objectives = {
		kill(12, "iceMammoth", "frostpeak_tundra"),
		kill(6, "frostGiant", "frostpeak_tundra"),
	},
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, { Talk.answer("war"), Talk.answer("pity", Talk.focus(2)), Talk.answer("many") }),
})
fp({
	id = "side_fp_warhorn",
	level = 91,
	giver = "bonecarver_gunnar",
	turnIn = "bonecarver_gunnar",
	arc = "fp_bones",
	pages = 3,
	requires = { "side_fp_stampede" },
	objectives = {
		reachCave("frostpeak_hold"),
		kill(3, "frostGiant", nil, "elite"),
		collect(1, "giantHorn", "frostGiant", 1, nil, "elite"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("horn", Talk.hint("frostpeak", HOLD_X, HOLD_Z, "map.frostpeak_hold.name")),
		Talk.answer("cold", Talk.gift("potion_hp_5", 2)),
		Talk.answer("hang"),
	}),
	recall = { done = "side_fp_stampede" },
})

-- G. The Squire of the Watch (90–93), the Ice Watch: Asmund, who ran on the night the frost came (no jests) ---------
-- The arc does not depend on Brother Halgrim's ghost (he may be gone after oathWords): Asmund gives and takes it all.
fp({
	id = "side_fp_squire",
	level = 90,
	giver = "squire_asmund",
	turnIn = "squire_asmund",
	arc = "fp_squire",
	pages = 4,
	requires = { "iceWatch" },
	objectives = { kill(10, "frozenKnight", "frostpeak_icewatch") },
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(3, { Talk.answer("why"), Talk.answer("know"), Talk.answer("how") }),
})
fp({
	id = "side_fp_shields",
	level = 92,
	giver = "squire_asmund",
	turnIn = "squire_asmund",
	arc = "fp_squire",
	pages = 3,
	requires = { "side_fp_squire" },
	objectives = {
		use({ "fp_watch_shield_1", "fp_watch_shield_2", "fp_watch_shield_3" }, "quest.use.juniper", 2, "juniper"),
		collect(4, "knightSigil", "frozenKnight", 0.35, "frostpeak_icewatch"),
	},
	barks = { accept = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("names"), Talk.answer("juniper"), Talk.answer("seals", Talk.focus(2)) }),
})
fp({
	id = "side_fp_spurs",
	level = 93,
	giver = "squire_asmund",
	turnIn = "squire_asmund",
	arc = "fp_squire",
	pages = 3,
	requires = { "side_fp_shields" },
	objectives = {
		use({ "fp_watch_gate" }, "quest.use.spurs", 3, "candles"),
		kill(8, "iceElemental", "frostpeak_icewatch"),
	},
	final = true,
	barks = { accept = 1, near = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("forgive"), Talk.answer("enter"), Talk.answer("wind") }),
	recall = { done = "side_fp_squire" },
})

-- H. Wyrm Bones (94–99), the Wyrm Spire: Vigdis the scholar, Brother Anzelm's letters and the treatise on the brood ---
-- (the pages hold before and after vaelgrath: they never say whether the dragon lives)
local SCHOLAR = FP_SPOTS.scholar
local BURROWS_X, BURROWS_Z = sitePoint("wyrmBurrows")
local BONES_X, BONES_Z = sitePoint("wyrmBones")
fp({
	id = "side_fp_letter",
	level = 94,
	giver = "brother_anzelm",
	turnIn = "scholar_vigdis",
	arc = "fp_wyrms",
	pages = 2,
	requires = { "dragonTemple" },
	objectives = { deliver("anzelmLetter") },
	barks = { accept = 1, done = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("who"),
		Talk.answer("warn"),
		Talk.answer("where", Talk.hint("frostpeak", SCHOLAR.x, SCHOLAR.z, "place.dragonStairs")),
	}),
})
fp({
	id = "side_fp_clutches",
	level = 96,
	giver = "scholar_vigdis",
	turnIn = "scholar_vigdis",
	arc = "fp_wyrms",
	pages = 3,
	requires = { "side_fp_letter" },
	objectives = {
		use({ "fp_brood_1", "fp_brood_2", "fp_brood_3" }, "quest.use.brood", 3, "eggShards"),
		kill(12, "dragonspawn", "frostpeak_wyrmspire"),
	},
	barks = { accept = 1, half = 1, done = 1, death = 1 },
	choices = Talk.onPage(2, {
		Talk.answer("spawn"),
		Talk.answer("eggs"),
		Talk.answer("burrows", Talk.hint("frostpeak", BURROWS_X, BURROWS_Z, "place.wyrmBurrows")),
	}),
})
fp({
	id = "side_fp_bonetrail",
	level = 97,
	giver = "scholar_vigdis",
	turnIn = "scholar_vigdis",
	arc = "fp_wyrms",
	pages = 3,
	requires = { "side_fp_clutches" },
	objectives = {
		reachPlace("frostpeak", BONES_X, BONES_Z, 24, "place.wyrmBones"),
		collect(3, "wyrmScale", "frostWyrm", 0.35, "frostpeak_wyrmspire"),
	},
	barks = { accept = 1, near = 1, half = 1, done = 1 },
	choices = Talk.onPage(2, { Talk.answer("age"), Talk.answer("scales", Talk.focus(2)), Talk.answer("trail") }),
})
fp({
	id = "side_fp_treatise",
	level = 99,
	giver = "scholar_vigdis",
	turnIn = "brother_anzelm",
	arc = "fp_wyrms",
	pages = 4,
	requires = { "side_fp_bonetrail" },
	objectives = {
		kill(10, "frostWyrm", "frostpeak_wyrmspire"),
		deliver("vigdisTreatise"),
	},
	final = true,
	barks = { accept = 1, half = 1, done = 1, stuck = 1 },
	choices = Talk.onPage(2, { Talk.answer("title"), Talk.answer("down"), Talk.answer("blood") }),
	recall = { p1 = "side_fp_clutches" },
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
	-- S107: the Ashen arcs by level
	"ashSalamanders",
	"ashOasis",
	"ashSpring",
	"ashProspector",
	"ashRuins",
	"ashCrags",
	"ashTombs",
	"ashCaravans",
	-- S108: the Frost Peaks arcs by level
	"fp_cairn",
	"fp_trappers",
	"fp_horn",
	"fp_saga",
	"fp_icefish",
	"fp_bones",
	"fp_squire",
	"fp_wyrms",
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
