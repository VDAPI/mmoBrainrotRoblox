--!strict
-- Ranked arena (DESIGN-17 §6, S126): level brackets, match modes, Elo, seasons, tiers, the queue and the venues.
-- S126: mode "1v1" on this server's Ristalle; S127 adds the global queue and arena servers (same rules); S128 adds
-- mode "3v3" (a new MODES entry, rating3, its board prefix) and the tokens / shop / season rewards.
-- Pure data (Lune). Balance ledger: Data/Arena is in BALANCE_MODULES (VENUES omitted: geometry). Nothing here may
-- depend on purchases (DESIGN-17 §0.2, tests/paywall.spec "Arena (S126)").

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
		board = "arena",
		tieBreak = "hpPct",
	}),
}

-- Order of the modes in the arena window (S128 appends "3v3").
local MODE_ORDER = { "1v1" }

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

-- Venues (geometry from the city plan, never typed by hand).
local PLAN = Town.city.arena
local STAND_OFFSET = PLAN.half + PLAN.stands * 0.6 -- on the third row of the full (x-axis) stands
local STAND_Z = 20 -- away from the lord's box (west stand, around the centre line) and from the gates (z-axis sides)

local function side(spot: { number }): { { number } }
	return { { spot[1], spot[2] }, { spot[1], spot[2] - 8 }, { spot[1], spot[2] + 8 } }
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
	},
}

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
