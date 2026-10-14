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

local Exp = require("../../Logic/Exp")
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
}

local list: { SideQuest } = {}

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
	table.insert(list, {
		id = def.id,
		level = def.level,
		giver = def.giver,
		turnIn = def.turnIn,
		arc = def.arc,
		pages = def.pages,
		requires = def.requires,
		objectives = def.objectives,
		reward = {
			exp = exp(def.level, share),
			gold = gold(def.level),
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
	})
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

-- Arcs in journal order (one per Meadows area; S96: the stable last).
local ARCS = { "farm", "shrine", "pond", "forest", "mill", "road", "quarry", "goblins", "ravine", "stable" }

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
	get = function(id: string): SideQuest?
		return byId[id]
	end,
})
