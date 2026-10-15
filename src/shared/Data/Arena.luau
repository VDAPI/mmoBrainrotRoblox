--!strict
-- Ranked arena (DESIGN-17 §6, S126): level brackets, match modes, Elo, seasons, tiers, the queue and the venues.
-- S126: mode "1v1" on this server's Ristalle; S127 adds the global queue and arena servers (same rules); S128 adds
-- mode "3v3" (a new MODES entry, rating3, its board prefix) and the tokens / shop / season rewards.
-- Pure data (Lune). Balance ledger: Data/Arena is in BALANCE_MODULES (VENUES omitted: geometry). Nothing here may
-- depend on purchases (DESIGN-17 §0.2, tests/paywall.spec "Arena (S126)").

local ArenaPit = require("./ArenaPit")
local Blessings = require("./Blessings")
local Town = require("./Town")

export type Bracket = { id: string, min: number, max: number }
export type Mode = {
	id: string, -- "1v1" (S126), "3v3" (S128)
	enabled: boolean,
	teamSize: number,
	winsNeeded: number, -- rounds to win the match
	maxRounds: number, -- after this many rounds the match ends on the round score
	roundTime: number, -- s
	countdown: number, -- s before each round
	between: number, -- s between rounds
	potions: number, -- potions per fighter per match
	ratingField: string, -- field of character.arena that holds this mode's rating ("rating"; S128 "rating3")
	-- S128: the other fields of character.arena this mode writes (1v1 "peak", "wins", "losses", "played", "vs"; 3v3
	-- "peak3", "wins3", "losses3", "played3", "vs3"); `daily` stays shared (the daily token bonus counts both modes)
	peakField: string,
	winsField: string,
	lossesField: string,
	playedField: string,
	vsField: string,
	board: string, -- leaderboard prefix: board id = `<board>_<season>_<bracket>` ("arena"; S128 "arena3")
	tieBreak: "hpPct" | "sumHpPct", -- at the end of the round time (1v1: own %HP; 3v3: the side's sum of %HP)
}
export type Tier = { id: string, min: number }
-- A venue: a square of sand (map coordinates), the start spots of each side (the first one of every side is the
-- 1v1 spot; the others are for S128 teams), the spectator seats and the way out. S127 adds `pit` (the arena server
-- map) and S130 `pit_1` .. `pit_4` with the same shape.
export type Venue = {
	id: string,
	map: string,
	center: { number },
	half: number,
	sides: { { { number } } },
	stands: { { number } },
	exit: { number },
	-- S128: the bench of each side in 3v3 = an index into `stands` on the side's half (side 1 west, side 2 east); a
	-- knocked out fighter watches the rest of the fight from there
	bench: { number },
}
-- S128 (DESIGN-17 §6): an entry of the arena shop at the Arena Master (prices in Arena Tokens).
export type ArenaShopEntry = {
	key: string,
	kind: "cosmetic" | "item",
	id: string, -- cosmetic id (Data/Cosmetics, obtain.arena = "shop") or item id (Data/Items)
	n: number?, -- stack size for items (default 1)
	price: number, -- Arena Tokens
	level: number?, -- character level needed (default: the arena minimum, MIN_LEVEL)
	group: "cosmetic" | "blessing" | "travel", -- the group of the shop tab
}
-- S128: the reward of the best tier of a finished season (Data/Titles id, Data/Cosmetics ids, Dragon Shards by mail).
export type SeasonReward = { title: string, cosmetics: { string }?, shards: number? }
-- S130 (DESIGN-17 §8): the Champion's Tournament reward of a place (1 champion, 2 finalist, 3 both semifinal
-- losers): Dragon Shards, a timed title (Data/Titles req.kind "timed") for `titleDays` and cosmetics never sold
-- (Data/Cosmetics obtain.event = "tourney"); everything by one mail parcel.
export type TourneyReward =
	{ place: number, shards: number?, title: string?, titleDays: number?, cosmetics: { string }? }
export type TourneyWindow = { open: number, close: number, organize: number, invite: number }
export type Tourney = {
	cap: number,
	minPlayers: number,
	window: TourneyWindow,
	fields: number,
	restBetween: number,
	hallWeeks: number,
	participantTokens: number,
	rewards: { TourneyReward },
}

local MIN_LEVEL = 20

-- Bracket ids are shared by S127-S130 (queue keys ArenaQueue_<mode>_<bracket>, boards arena_<season>_<bracket>,
-- Tourney_<date>_<bracket>): exactly these strings.
local BRACKETS: { Bracket } = {
	{ id = "20_39", min = 20, max = 39 },
	{ id = "40_59", min = 40, max = 59 },
	{ id = "60_79", min = 60, max = 79 },
	{ id = "80_100", min = 80, max = 100 },
}

local function mode(def: Mode): Mode
	return def
end

local MODES: { [string]: Mode } = {
	["1v1"] = mode({
		id = "1v1",
		enabled = true,
		teamSize = 1,
		winsNeeded = 2,
		maxRounds = 3,
		roundTime = 180,
		countdown = 3,
		between = 5, -- S126 decision (DECYZJE)
		potions = 3,
		ratingField = "rating",
		peakField = "peak",
		winsField = "wins",
		lossesField = "losses",
		playedField = "played",
		vsField = "vs",
		board = "arena",
		tieBreak = "hpPct",
	}),
}

-- S128 (DESIGN-17 §6): team matches, a second MODES entry (S126 Mode type). One round, the team with fighters left
-- wins; at the time limit the sum of the fighters' HP fractions decides (a fighter knocked out counts 0). Same match
-- rules as 1v1 otherwise (potions, blessings suspended, no Full Elixir, no mounts).
MODES["3v3"] = mode({
	id = "3v3",
	enabled = true,
	teamSize = 3,
	winsNeeded = 1,
	maxRounds = 1,
	roundTime = 240,
	countdown = MODES["1v1"].countdown,
	between = 0,
	potions = MODES["1v1"].potions,
	ratingField = "rating3",
	peakField = "peak3",
	winsField = "wins3",
	lossesField = "losses3",
	playedField = "played3",
	vsField = "vs3",
	board = "arena3",
	tieBreak = "sumHpPct",
})

-- Order of the modes in the arena window.
local MODE_ORDER = { "1v1", "3v3" }

local ELO = { start = 1000, k = 32, kNew = 48, newGames = 10, floor = 0, scale = 400 }

-- Soft reset at a new season: start + (rating - start) x keep.
local SEASON = { keep = 0.5 }

-- Ascending; colour and glyph live on the client (UI/Screens/ArenaWindow).
local TIERS: { Tier } = {
	{ id = "bronze", min = 0 },
	{ id = "silver", min = 1100 },
	{ id = "gold", min = 1300 },
	{ id = "diamond", min = 1500 },
	{ id = "master", min = 1700 },
}

-- Matchmaking: rating window +-window, widened by `widen` every `widenEvery` s of waiting; the offer is accepted
-- within `acceptSeconds`; declining (or not answering) closes the queue for `declinePenalty` s; the queue is
-- looked at every `tick` s. Accept and penalty are the S127 contract numbers, used locally already (DECYZJE S126).
local QUEUE = { window = 100, widen = 100, widenEvery = 15, acceptSeconds = 15, declinePenalty = 300, tick = 1 }

-- More than `sameOpponentDaily` matches a UTC day against the same opponent do not change the rating; the arena
-- window keeps the last `history` matches.
local LIMITS = { sameOpponentDaily = 3, history = 10 }

-- S128: Arena Tokens per match (DESIGN-17 §6): the first `firstMatches` matches of a UTC day (1v1 and 3v3 together)
-- pay `firstMul` times; a draw pays the loss. A week (Monday 00:00 UTC, Logic/Time.weekNumber) pays at most
-- tokensWeekCap. Tokens are never sold (tests/paywall.spec).
local TOKENS = { win1v1 = 10, loss1v1 = 4, win3v3 = 12, loss3v3 = 5, firstMatches = 3, firstMul = 2 }
local tokensWeekCap = 600

-- S128: the arena shop (DESIGN-17 §6). Blessings of every line up to Heroic, the Return Stone and the arena
-- cosmetics; nothing with bonuses. Items bought here are bound (no gold through trade or auction).
local SHOP_MAX_BLESSING_RARITY = 3 -- Heroic, DESIGN-17 §6
local BLESSING_PRICE = { 15, 35, 70 } -- by rarity 1..SHOP_MAX_BLESSING_RARITY
local SHOP: { ArenaShopEntry } = {
	{ key = "stone_return_5", kind = "item", id = "stone_return", n = 5, price = 10, group = "travel" },
}
for rarity = 1, SHOP_MAX_BLESSING_RARITY do
	for _, line in Blessings.lines do
		local id = `blessing_{line}_{rarity}`
		table.insert(
			SHOP,
			{ key = id, kind = "item", id = id, n = 1, price = BLESSING_PRICE[rarity], group = "blessing" }
		)
	end
end
for _, entry in
	{
		{ id = "frame_gladiator", price = 250 },
		{ id = "chatframe_gladiator", price = 250 },
		{ id = "title_ironwill", price = 400 },
		{ id = "title_sandveteran", price = 600 },
		{ id = "aura_gladiator", price = 1200 },
	}
do
	table.insert(SHOP, { key = entry.id, kind = "cosmetic", id = entry.id, price = entry.price, group = "cosmetic" })
end
local shopByKey: { [string]: ArenaShopEntry } = {}
for _, entry in SHOP do
	assert(shopByKey[entry.key] == nil, `Data/Arena: duplicate shop key {entry.key}`)
	assert(entry.price > 0 and entry.price % 1 == 0, `Data/Arena: bad price of {entry.key}`)
	shopByKey[entry.key] = entry
end

-- S128: season rewards (DESIGN-17 §6), by the best tier of the finished season (ArenaRules.seasonTier), written out
-- in full for every tier (a higher tier lists what the lower ones give). Titles are Data/Titles ids, cosmetics
-- Data/Cosmetics ids (obtain.arena = "season"); shards go by mail.
local SEASON_REWARDS: { [string]: SeasonReward } = {
	bronze = { title = "arena_bronze" },
	silver = { title = "arena_silver", cosmetics = { "frame_arena_season" } },
	gold = { title = "arena_gold", cosmetics = { "frame_arena_season", "aura_arena_season" } },
	diamond = { title = "arena_diamond", cosmetics = { "frame_arena_season", "aura_arena_season" }, shards = 150 },
	master = { title = "arena_master", cosmetics = { "frame_arena_season", "aura_arena_season" }, shards = 300 },
}
local seasonMinPlayed = 5 -- matches (1v1 + 3v3) in the finished season needed for any season reward

-- S130 (DESIGN-17 §8): the Champion's Tournament. Offsets in seconds relative to the bracket start (the "tourney" slot
-- of Data/ScheduledEvents, Saturday 19:00 UTC): signups 18:00-18:50, the organizer at 18:55, `invite` s to accept.
-- Brackets are the arena brackets (ArenaRules). Rewards are mailed (the S129 parcel); every seeded player who showed
-- up gets `participantTokens` on top of the place reward (outside the weekly token cap, like the S129 event tokens).
local function reward(def: TourneyReward): TourneyReward
	return def
end
local TOURNEY: Tourney = {
	cap = 32, -- signups taken per bracket; above it the highest 1v1 ratings get in (ties: earlier signup)
	minPlayers = 4, -- fewer signed (at the close) or present (at the start) cancels the bracket
	window = { open = -3600, close = -600, organize = -300, invite = 120 },
	fields = 4, -- fighting fields on a tournament server (a local tournament has one: Ristalle)
	restBetween = 30, -- seconds a player rests after a match before the next one is called
	hallWeeks = 4, -- champions kept per bracket on the Hall of Fame board
	participantTokens = 30,
	rewards = {
		reward({ place = 1, shards = 200, title = "tourney_champion", titleDays = 7, cosmetics = { "aura_champion" } }),
		reward({ place = 2, shards = 100, cosmetics = { "frame_tourney" } }),
		reward({ place = 3, shards = 50 }), -- both semifinal losers (no match for third place)
	},
}

-- Venues (geometry from the city plan, never typed by hand).
local PLAN = Town.city.arena
local STAND_OFFSET = PLAN.half + PLAN.stands * 0.6 -- on the third row of the full (x-axis) stands
local STAND_Z = 20 -- away from the lord's box (west stand, around the centre line) and from the gates (z-axis sides)

local function side(spot: { number }): { { number } }
	return { { spot[1], spot[2] }, { spot[1], spot[2] - 8 }, { spot[1], spot[2] + 8 } }
end

-- S128: the bench of each side (stands 1-2 west, 3-4 east; side 1 starts west of the centre on both venues).
local BENCH = { 1, 3 }

-- S127: the sand of an arena server field (Data/ArenaPit), the same shape as the Ristalle.
local function pitVenue(id: string, f: ArenaPit.Field): Venue
	local offset = f.half + f.stands * 0.6
	return {
		id = id,
		map = "arena_pit",
		center = { f.x, f.z },
		half = f.half,
		sides = {
			side({ f.x + f.starts[1][1], f.z + f.starts[1][2] }),
			side({ f.x + f.starts[2][1], f.z + f.starts[2][2] }),
		},
		stands = {
			{ f.x - offset, f.z - STAND_Z },
			{ f.x - offset, f.z + STAND_Z },
			{ f.x + offset, f.z - STAND_Z },
			{ f.x + offset, f.z + STAND_Z },
		},
		exit = { f.x + f.exit[1], f.z + f.exit[2] },
		bench = table.clone(BENCH),
	}
end

local VENUES: { [string]: Venue } = {
	ristalle = {
		id = "ristalle",
		map = "city",
		center = { PLAN.x, PLAN.z },
		half = PLAN.half,
		sides = { side(PLAN.duel[1]), side(PLAN.duel[2]) },
		stands = {
			{ PLAN.x - STAND_OFFSET, PLAN.z - STAND_Z },
			{ PLAN.x - STAND_OFFSET, PLAN.z + STAND_Z },
			{ PLAN.x + STAND_OFFSET, PLAN.z - STAND_Z },
			{ PLAN.x + STAND_OFFSET, PLAN.z + STAND_Z },
		},
		exit = { PLAN.exit[1], PLAN.exit[2] },
		bench = table.clone(BENCH),
	},
	-- S127: the arena server (map arena_pit, Data/ArenaPit layout "arena"); S130 adds pit_1 .. pit_4
	pit = pitVenue("pit", ArenaPit.layout("arena").fields[1]),
}
-- S130: the four fields of a tournament server ("pit_1" .. "pit_4" = ArenaPit tournament fields pit1 .. pit4)
for i, f in ArenaPit.layout("tournament").fields do
	VENUES[`pit_{i}`] = pitVenue(`pit_{i}`, f)
end

local Arena = {
	MIN_LEVEL = MIN_LEVEL,
	BRACKETS = BRACKETS,
	MODES = MODES,
	MODE_ORDER = MODE_ORDER,
	ELO = ELO,
	SEASON = SEASON,
	TIERS = TIERS,
	QUEUE = QUEUE,
	LIMITS = LIMITS,
	VENUES = VENUES,
	-- S128
	TOKENS = TOKENS,
	tokensWeekCap = tokensWeekCap,
	SHOP_MAX_BLESSING_RARITY = SHOP_MAX_BLESSING_RARITY,
	BLESSING_PRICE = BLESSING_PRICE,
	SHOP = SHOP,
	shopByKey = shopByKey,
	SEASON_REWARDS = SEASON_REWARDS,
	seasonMinPlayed = seasonMinPlayed,
	-- S130
	TOURNEY = TOURNEY,
}

function Arena.bracket(id: string): Bracket?
	for _, b in BRACKETS do
		if b.id == id then
			return b
		end
	end
	return nil
end

function Arena.mode(id: string): Mode?
	return MODES[id]
end

function Arena.venue(id: string): Venue?
	return VENUES[id]
end

-- S128: the shop entry selling a cosmetic or item id (nil when the shop does not sell it).
function Arena.shopOf(id: string): ArenaShopEntry?
	for _, entry in SHOP do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

local function deepFreeze(value: any): any
	if type(value) == "table" and not table.isfrozen(value) then
		for _, v in value do
			deepFreeze(v)
		end
		table.freeze(value)
	end
	return value
end

deepFreeze(Arena)

return Arena
