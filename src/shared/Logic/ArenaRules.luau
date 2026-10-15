--!strict
-- Ranked arena rules (DESIGN-17 §6, S126), pure: brackets, seasons, tiers, the matchmaking window and the pairing,
-- the queue checks, rounds and matches, and the result written to character.arena. Time, day and season always come
-- in as arguments (Lune: tests/arena.spec). The exchange types below hold no Roblox instances: S127 sends them
-- through MemoryStore and TeleportData. Nothing here reads the account, gear or purchases (DESIGN-17 §0.2).

local Arena = require("../Data/Arena")
local Elo = require("./Elo")
local Time = require("./Time")
local Types = require("../Types")

export type ArenaState = Types.ArenaState
export type ArenaSeasonSummary = Types.ArenaSeasonSummary
export type ArenaHistoryEntry = Types.ArenaHistoryEntry
export type Mode = Arena.Mode
export type Venue = Arena.Venue

-- A character in the queue: entry key "<userId>_<slot>", the rating of the mode and the rated matches of the season.
export type Entrant = {
	key: string,
	userId: number,
	slot: number,
	name: string,
	class: string,
	level: number,
	rating: number,
	played: number,
}
export type Ticket = { entrant: Entrant, mode: string, bracket: string, joinedAt: number }
export type Pairing = { mode: string, bracket: string, sides: { { Ticket } } }
export type MatchSpec = {
	id: string,
	mode: string,
	bracket: string,
	season: string,
	rated: boolean, -- false: tournament (S130) or admin test; never changes ratings
	unrated: { [string]: boolean }, -- entrant keys whose rating this match will not change (same opponent > 3 today)
	sides: { { Entrant } }, -- ratings snapshotted when the match was made
	venue: string, -- Data/Arena.VENUES id ("ristalle"; S127 "pit")
	origin: string, -- "local" (S126), "global" (S127), "tournament" (S130), "admin"
	createdAt: number,
}
export type Fighter = { key: string, hpPct: number, down: boolean, left: boolean }
export type RoundOutcome = { winner: number?, reason: "ko" | "time" | "left", draw: boolean }
export type MatchResult = {
	winner: number?,
	score: { number },
	rounds: number,
	reason: "score" | "forfeit" | "draw" | "aborted",
	forfeits: { [string]: boolean },
}
export type QueueInput = {
	level: number,
	dead: boolean,
	inDungeon: boolean,
	inDuel: boolean,
	inMatch: boolean,
	queued: boolean,
	offered: boolean,
	penaltyUntil: number?,
	now: number,
	mode: string,
}
export type ResultInput = {
	mode: Mode,
	season: string,
	day: number,
	now: number,
	myKey: string,
	oppKeys: { string },
	oppRating: number,
	oppName: string,
	oppClass: string,
	score: number, -- 1 win, 0.5 draw, 0 loss
	rounds: string, -- "2:1" (own:opponent)
	rated: boolean,
}

local ELO = Arena.ELO
local QUEUE = Arena.QUEUE
local LIMITS = Arena.LIMITS
local TIE = 0.001

local ArenaRules = {}

-- Brackets and modes -------------------------------------------------------------------------------------------------

-- Bracket id of a level; nil below Data/Arena.MIN_LEVEL.
function ArenaRules.bracketOf(level: number): string?
	local l = math.floor(tonumber(level) or 0)
	if l < Arena.MIN_LEVEL then
		return nil
	end
	for _, b in Arena.BRACKETS do
		if l >= b.min and l <= b.max then
			return b.id
		end
	end
	local last = Arena.BRACKETS[#Arena.BRACKETS]
	return if l > last.max then last.id else nil
end

-- The modes a player may queue for (MODE_ORDER, enabled only).
function ArenaRules.enabledModes(): { Mode }
	local out = {}
	for _, id in Arena.MODE_ORDER do
		local mode = Arena.MODES[id]
		if mode and mode.enabled then
			table.insert(out, mode)
		end
	end
	return out
end

-- Leaderboard instance id of a mode, season and bracket: "<board>_<season>_<bracket>" ("arena_202611_40_59").
function ArenaRules.boardId(mode: Mode, season: string, bracket: string): string
	return `{mode.board}_{season}_{bracket}`
end

-- Seasons ------------------------------------------------------------------------------------------------------------

-- The season of a moment: the UTC month "YYYYMM" (S121 Time.monthKey).
function ArenaRules.seasonOf(t: number): string
	return Time.monthKey(t)
end

-- Day number of a UTC date ("days from civil", H. Hinnant; the inverse of Time.civil).
local function daysFromCivil(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = y // 400
	local yoe = y - era * 400
	local mp = if month > 2 then month - 3 else month + 9
	local doy = (153 * mp + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

local function shift(season: string, by: number): (number, number)
	local year, month = Time.monthLabel(season)
	if not year or not month then
		error(`ArenaRules: bad season {season}`)
	end
	local index = year * 12 + (month - 1) + by
	return index // 12, index % 12 + 1
end

-- Unix time the season starts (the 1st of its month, 00:00 UTC).
function ArenaRules.seasonStart(season: string): number
	local year, month = shift(season, 0)
	return daysFromCivil(year, month, 1) * 86400
end

-- Unix time the season ends (= the start of the next one).
function ArenaRules.seasonEndsAt(season: string): number
	local year, month = shift(season, 1)
	return daysFromCivil(year, month, 1) * 86400
end

function ArenaRules.prevSeason(season: string): string
	local year, month = shift(season, -1)
	return string.format("%04d%02d", year, month)
end

function ArenaRules.nextSeason(season: string): string
	local year, month = shift(season, 1)
	return string.format("%04d%02d", year, month)
end

-- Tiers --------------------------------------------------------------------------------------------------------------

function ArenaRules.tierOf(rating: number): string
	local id = Arena.TIERS[1].id
	for _, tier in Arena.TIERS do
		if rating >= tier.min then
			id = tier.id
		end
	end
	return id
end

-- The next tier and the points missing to it; (nil, 0) at the top tier.
function ArenaRules.tierProgress(rating: number): (string?, number)
	for _, tier in Arena.TIERS do
		if rating < tier.min then
			return tier.id, tier.min - rating
		end
	end
	return nil, 0
end

-- Queue --------------------------------------------------------------------------------------------------------------

-- Rating window after `wait` seconds in the queue.
function ArenaRules.window(wait: number): number
	return QUEUE.window + QUEUE.widen * math.floor(math.max(0, wait) / QUEUE.widenEvery)
end

local function older(a: Ticket, b: Ticket): boolean
	if a.joinedAt ~= b.joinedAt then
		return a.joinedAt < b.joinedAt
	end
	return a.entrant.key < b.entrant.key
end

-- Deterministic pairing of one list of tickets at `now`: oldest unpaired ticket first; its candidates share mode and
-- bracket, belong to another user and fit the wider of the two windows; the smallest rating difference wins (tie:
-- the older ticket). Returns the pairs (sides[1] = the older ticket) and the rest in queue order. Only teamSize 1
-- here; S128 adds the team branch in this function.
function ArenaRules.pair(tickets: { Ticket }, now: number, teamSize: number?): ({ Pairing }, { Ticket })
	if (teamSize or 1) ~= 1 then
		error("pair: teamSize > 1 is S128")
	end
	local sorted = table.clone(tickets)
	table.sort(sorted, older)
	local used: { [number]: boolean } = {}
	local pairs: { Pairing } = {}
	for i, a in sorted do
		if used[i] then
			continue
		end
		local best: number? = nil
		local bestDiff = math.huge
		for j = i + 1, #sorted do
			local b = sorted[j]
			if used[j] or b.mode ~= a.mode or b.bracket ~= a.bracket or b.entrant.userId == a.entrant.userId then
				continue
			end
			local diff = math.abs(a.entrant.rating - b.entrant.rating)
			local window = math.max(ArenaRules.window(now - a.joinedAt), ArenaRules.window(now - b.joinedAt))
			if diff <= window and diff < bestDiff then
				best, bestDiff = j, diff
			end
		end
		if best then
			used[i] = true
			used[best] = true
			table.insert(pairs, { mode = a.mode, bracket = a.bracket, sides = { { a }, { sorted[best] } } })
		end
	end
	local rest = {}
	for i, t in sorted do
		if not used[i] then
			table.insert(rest, t)
		end
	end
	return pairs, rest
end

-- Why a character may not join the queue now (the first reason in a fixed order), nil = it may.
function ArenaRules.canQueue(input: QueueInput): string?
	local mode = Arena.MODES[input.mode]
	if not mode or not mode.enabled then
		return "arena.error.mode"
	elseif ArenaRules.bracketOf(input.level) == nil then
		return "arena.error.level"
	elseif input.dead then
		return "arena.error.dead"
	elseif input.inDungeon then
		return "arena.error.dungeon"
	elseif input.inDuel then
		return "arena.error.duel"
	elseif input.inMatch then
		return "arena.error.inMatch"
	elseif input.queued or input.offered then
		return "arena.error.queued"
	elseif input.penaltyUntil ~= nil and input.penaltyUntil > input.now then
		return "arena.error.penalty"
	end
	return nil
end

-- State --------------------------------------------------------------------------------------------------------------

-- A fresh character.arena (the template of Logic/AccountSchema).
function ArenaRules.emptyState(): ArenaState
	return {
		season = "",
		rating = ELO.start,
		wins = 0,
		losses = 0,
		peak = ELO.start,
		played = 0,
		tokens = 0,
		daily = { day = 0, n = 0 },
		vs = { day = 0 },
		history = {},
		last = nil,
	}
end

-- A deep copy (the input of every rule stays untouched). Unknown fields of the input are dropped on purpose.
local function copy(state: ArenaState): ArenaState
	local s: any = state
	local out: any = ArenaRules.emptyState()
	for _, field in { "season", "rating", "wins", "losses", "peak", "played", "tokens" } do
		if s[field] ~= nil then
			out[field] = s[field]
		end
	end
	-- mode rating fields beyond "rating" (S128 rating3)
	for _, mode in Arena.MODES do
		if mode.ratingField ~= "rating" and type(s[mode.ratingField]) == "number" then
			out[mode.ratingField] = s[mode.ratingField]
		end
	end
	if type(s.daily) == "table" then
		out.daily = { day = s.daily.day or 0, n = s.daily.n or 0 }
	end
	if type(s.vs) == "table" then
		out.vs = table.clone(s.vs)
		out.vs.day = out.vs.day or 0
	end
	if type(s.history) == "table" then
		local list = {}
		for _, entry in s.history do
			table.insert(list, table.clone(entry))
		end
		out.history = list
	end
	if type(s.last) == "table" then
		out.last = table.clone(s.last)
	end
	return out
end

ArenaRules.copy = copy

-- Moves the state to `season`. Same season: an unchanged copy. Never played (""): only the season. A new season: the
-- soft reset start + (rating - start) x keep, peak = the new rating, wins / losses / played = 0; the closed season
-- goes to `last` only when it had rated matches (else the older `last` stays). Returns the copy and the summary of
-- the closed season (nil when nothing closed).
function ArenaRules.rollSeason(state: ArenaState, season: string): (ArenaState, ArenaSeasonSummary?)
	local out = copy(state)
	if out.season == season then
		return out, nil
	end
	if out.season == "" then
		out.season = season
		return out, nil
	end
	local summary: ArenaSeasonSummary? = nil
	if out.played > 0 then
		summary = {
			season = out.season,
			rating = out.rating,
			peak = out.peak,
			wins = out.wins,
			losses = out.losses,
			played = out.played,
			rewarded = false,
		}
		out.last = table.clone(summary :: ArenaSeasonSummary)
	end
	local reset = ELO.start + (out.rating - ELO.start) * Arena.SEASON.keep
	out.rating = Elo.apply(math.floor(reset + 0.5), 0)
	local fields: any = out
	for _, mode in Arena.MODES do
		local field = mode.ratingField
		local value = fields[field]
		if field ~= "rating" and type(value) == "number" then
			fields[field] = Elo.apply(math.floor(ELO.start + (value - ELO.start) * Arena.SEASON.keep + 0.5), 0)
		end
	end
	out.peak = out.rating
	out.wins = 0
	out.losses = 0
	out.played = 0
	out.season = season
	return out, summary
end

-- Matches against `oppKey` on UTC day `day` (the key "day" of `vs` is the day, never an opponent).
function ArenaRules.vsCount(state: ArenaState, oppKey: string, day: number): number
	local vs = state.vs
	if type(vs) ~= "table" or vs.day ~= day or oppKey == "day" then
		return 0
	end
	return tonumber(vs[oppKey]) or 0
end

-- Whether the next match against `oppKey` today still changes the rating.
function ArenaRules.isRated(state: ArenaState, oppKey: string, day: number): boolean
	return ArenaRules.vsCount(state, oppKey, day) < LIMITS.sameOpponentDaily
end

-- The rating of a mode in a state (S128 rating3 starts at ELO.start).
function ArenaRules.ratingOf(state: ArenaState, mode: Mode): number
	local value = (state :: any)[mode.ratingField]
	return if type(value) == "number" then value else ELO.start
end

-- Rounds and matches ---------------------------------------------------------------------------------------------------

local function sideOut(list: { Fighter }): (boolean, boolean)
	local out, allLeft = true, true
	for _, f in list do
		if not f.down and not f.left then
			out = false
		end
		if not f.left then
			allLeft = false
		end
	end
	return out, allLeft
end

-- The outcome of a round, nil while it goes on. A side whose fighters are all down or gone loses ("ko"; "left" when
-- all of them left); all sides out at once is a draw; at the end of the time the higher sum of %HP wins ("time", down
-- and gone count 0; equal within 0.001 = draw). Same function for 1v1 and teams (tieBreak "hpPct" with one fighter is
-- the sum; the parameter stays for S128).
function ArenaRules.roundOutcome(sides: { { Fighter } }, timedOut: boolean, _tieBreak: string): RoundOutcome?
	local alive: { number } = {}
	local leftOnly = true
	for i, list in sides do
		local out, allLeft = sideOut(list)
		if not out then
			table.insert(alive, i)
		elseif not allLeft then
			leftOnly = false
		end
	end
	if #alive == 0 then
		return { winner = nil, reason = if leftOnly then "left" else "ko", draw = true }
	end
	if #alive == 1 and #sides > 1 then
		return { winner = alive[1], reason = if leftOnly then "left" else "ko", draw = false }
	end
	if not timedOut then
		return nil
	end
	local best: number? = nil
	local bestSum = -math.huge
	local tie = false
	for i, list in sides do
		local sum = 0
		for _, f in list do
			if not f.down and not f.left then
				sum += math.clamp(f.hpPct, 0, 1)
			end
		end
		if best == nil or sum > bestSum + TIE then
			best, bestSum, tie = i, sum, false
		elseif math.abs(sum - bestSum) <= TIE then
			tie = true
		end
	end
	if tie then
		return { winner = nil, reason = "time", draw = true }
	end
	return { winner = best, reason = "time", draw = false }
end

-- The match result after a round, nil while it goes on. `forfeitSide` loses at once; `winsNeeded` round wins end it;
-- after `maxRounds` rounds more won rounds win and equal is a draw (Elo 0.5).
function ArenaRules.matchOutcome(
	score: { number },
	roundsPlayed: number,
	mode: Mode,
	forfeitSide: number?
): MatchResult?
	local scoreCopy = table.clone(score)
	if forfeitSide then
		local winner: number? = nil
		if #score == 2 then
			winner = 3 - forfeitSide
		end
		return { winner = winner, score = scoreCopy, rounds = roundsPlayed, reason = "forfeit", forfeits = {} }
	end
	for side, wins in score do
		if wins >= mode.winsNeeded then
			return { winner = side, score = scoreCopy, rounds = roundsPlayed, reason = "score", forfeits = {} }
		end
	end
	if roundsPlayed >= mode.maxRounds then
		local best: number? = nil
		local bestWins = -1
		local tie = false
		for side, wins in score do
			if wins > bestWins then
				best, bestWins, tie = side, wins, false
			elseif wins == bestWins then
				tie = true
			end
		end
		if tie then
			return { winner = nil, score = scoreCopy, rounds = roundsPlayed, reason = "draw", forfeits = {} }
		end
		return { winner = best, score = scoreCopy, rounds = roundsPlayed, reason = "score", forfeits = {} }
	end
	return nil
end

-- Score of a side in a result: 1 win, 0.5 draw (or no winner), 0 loss.
function ArenaRules.scoreOf(result: MatchResult, side: number): number
	if result.winner == nil then
		return 0.5
	end
	return if result.winner == side then 1 else 0
end

-- "own:others" rounds of a side ("2:1"; teams: the best other side).
function ArenaRules.roundsText(score: { number }, side: number): string
	local other = 0
	for i, wins in score do
		if i ~= side then
			other = math.max(other, wins)
		end
	end
	return `{score[side] or 0}:{other}`
end

-- Writes one match into a state (the only rule that changes character.arena after a match):
--   1. the season first (a match ended after midnight at the turn of the month counts for the new season);
--   2. the day counters: a new day resets `daily` and `vs`; the match is rated when `input.rated` and every opponent
--      was met fewer than LIMITS.sameOpponentDaily times today (counted before this match), then `vs` counts it;
--   3. rated: Elo on the mode's rating field with K from `played`, then played, wins / losses (a draw: neither), peak;
--   4. unrated: rating, played, wins, losses and peak stay;
--   5. history: the new entry first, cut to LIMITS.history.
-- The input stays untouched. Gets nothing from the account, gear or purchases (DESIGN-17 §0.2).
function ArenaRules.applyResult(state: ArenaState, input: ResultInput): (ArenaState, { delta: number, rated: boolean })
	local out = ArenaRules.rollSeason(state, input.season)
	if out.daily.day ~= input.day then
		out.daily = { day = input.day, n = 0 }
	end
	out.daily.n += 1
	if out.vs.day ~= input.day then
		out.vs = { day = input.day }
	end
	local rated = input.rated
	for _, key in input.oppKeys do
		if not ArenaRules.isRated(out, key, input.day) then
			rated = false
		end
	end
	for _, key in input.oppKeys do
		if key ~= "day" then
			out.vs[key] = (tonumber(out.vs[key]) or 0) + 1
		end
	end
	local delta = 0
	local mode = input.mode
	if rated then
		local before = ArenaRules.ratingOf(out, mode)
		delta = Elo.delta(before, input.oppRating, input.score, Elo.k(out.played))
		local after = Elo.apply(before, delta)
		delta = after - before
		local fields: any = out
		fields[mode.ratingField] = after
		out.played += 1
		if input.score >= 1 then
			out.wins += 1
		elseif input.score <= 0 then
			out.losses += 1
		end
		if mode.ratingField == "rating" then
			out.peak = math.max(out.peak, after)
		end
	end
	local entry: ArenaHistoryEntry = {
		t = input.now,
		mode = mode.id,
		opp = input.oppName,
		oppClass = input.oppClass,
		oppRating = input.oppRating,
		score = input.score,
		rounds = input.rounds,
		delta = delta,
		rated = rated,
	}
	table.insert(out.history, 1, entry)
	while #out.history > LIMITS.history do
		table.remove(out.history)
	end
	return out, { delta = delta, rated = rated }
end

-- Venues -------------------------------------------------------------------------------------------------------------

-- Whether map point (x, z) is on the sand; `margin` > 0 shrinks the square, < 0 grows it.
function ArenaRules.inside(venue: Venue, x: number, z: number, margin: number?): boolean
	local m = margin or 0
	local reach = venue.half - m
	return math.abs(x - venue.center[1]) <= reach and math.abs(z - venue.center[2]) <= reach
end

-- Start spot of fighter `index` of `side` (the first spot of a side is the 1v1 one).
function ArenaRules.spot(venue: Venue, side: number, index: number): (number, number)
	local list = venue.sides[side] or venue.sides[1]
	local p = list[index] or list[1]
	return p[1], p[2]
end

-- Spectator seat `i` (any i: the seats repeat in turn).
function ArenaRules.standSpot(venue: Venue, i: number): (number, number)
	local n = #venue.stands
	local p = venue.stands[((math.floor(i) - 1) % n) + 1]
	return p[1], p[2]
end

return ArenaRules
