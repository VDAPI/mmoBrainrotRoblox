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
-- S128: a team of a party (3v3) is ONE ticket: `entrant` = the leader (its rating = Elo.sideRating of the members'
-- rating3), `members` = the three fighters with the leader; a solo ticket has no members.
export type Ticket = { entrant: Entrant, mode: string, bracket: string, joinedAt: number, members: { Entrant }? }
-- S128: what the server knows when a player asks for the 3v3 queue (Logic/ArenaRules.canQueue3).
export type Queue3Input = {
	inParty: boolean,
	partySize: number,
	isLeader: boolean,
	sameBracket: boolean,
	anyBusy: boolean,
}
export type SeasonRewardOut = { season: string, tier: string, title: string, cosmetics: { string }, shards: number }
-- `fallback` (S127): a local offer after the global wait (Logic/ArenaQueue.localOffer): declining it costs nothing.
export type Pairing = { mode: string, bracket: string, sides: { { Ticket } }, fallback: boolean? }
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
	return Time.fromCivil(year, month, 1) * 86400
end

-- Unix time the season ends (= the start of the next one).
function ArenaRules.seasonEndsAt(season: string): number
	local year, month = shift(season, 1)
	return Time.fromCivil(year, month, 1) * 86400
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

-- S128: the number of fighters of a ticket (a party team 3, a solo 1).
function ArenaRules.size(t: Ticket): number
	return if t.members then #t.members else 1
end

-- The user ids of a ticket's fighters.
local function usersOf(t: Ticket): { number }
	if t.members then
		local out = {}
		for _, m in t.members do
			table.insert(out, m.userId)
		end
		return out
	end
	return { t.entrant.userId }
end

local function ratingsOf(t: Ticket): { number }
	if t.members then
		local out = {}
		for _, m in t.members do
			table.insert(out, m.rating)
		end
		return out
	end
	return { t.entrant.rating }
end

-- S128: one 3v3 pairing out of the tickets of ONE bracket (deterministic; tests/arena.spec "S128"):
--   1. the tickets sorted by joinedAt, then key (as pair);
--   2. the oldest ticket E starts team A: a party team alone, else E and the next oldest solo tickets of other users
--      within min(window(E), window(X)) of E's rating until A has three fighters; else the next oldest is E;
--   3. team B: the oldest party team whose rating is within min(window(oldest of A), window(candidate)) of A's mean,
--      else the three oldest solo tickets each within that window of A's mean;
--   4. { A, B } or nil. A party team is never split, no ticket is in both teams, no user twice.
-- `anyRating` (the S127 local fallback after the global wait) drops the rating windows.
function ArenaRules.formTeams3(tickets: { Ticket }, now: number, anyRating: boolean?): Pairing?
	if #tickets == 0 then
		return nil
	end
	local bracket = tickets[1].bracket
	for _, t in tickets do
		assert(t.bracket == bracket, "formTeams3: tickets of one bracket")
	end
	local need = (Arena.MODES["3v3"] :: Mode).teamSize
	local sorted = table.clone(tickets)
	table.sort(sorted, older)
	local function w(t: Ticket): number
		return if anyRating then math.huge else ArenaRules.window(now - t.joinedAt)
	end
	for i, e in sorted do
		local sizeE = ArenaRules.size(e)
		if sizeE ~= 1 and sizeE ~= need then
			continue
		end
		local a: { Ticket } = { e }
		local usedIdx: { [number]: boolean } = { [i] = true }
		local users: { [number]: boolean } = {}
		for _, u in usersOf(e) do
			users[u] = true
		end
		local count = sizeE
		if count < need then
			for j, x in sorted do
				if count >= need then
					break
				end
				if usedIdx[j] or ArenaRules.size(x) ~= 1 or users[x.entrant.userId] then
					continue
				end
				if math.abs(x.entrant.rating - e.entrant.rating) <= math.min(w(e), w(x)) then
					table.insert(a, x)
					usedIdx[j] = true
					users[x.entrant.userId] = true
					count += 1
				end
			end
		end
		if count ~= need then
			continue
		end
		local ratingsA: { number } = {}
		local oldestA = a[1]
		for _, t in a do
			for _, r in ratingsOf(t) do
				table.insert(ratingsA, r)
			end
			if older(t, oldestA) then
				oldestA = t
			end
		end
		local meanA = Elo.sideRating(ratingsA)
		local function fits(t: Ticket): boolean
			return math.abs(t.entrant.rating - meanA) <= math.min(w(oldestA), w(t))
		end
		local function free(t: Ticket, taken: { [number]: boolean }): boolean
			for _, u in usersOf(t) do
				if taken[u] then
					return false
				end
			end
			return true
		end
		-- B: a party team first
		local b: { Ticket }? = nil
		for j, x in sorted do
			if not usedIdx[j] and ArenaRules.size(x) == need and free(x, users) and fits(x) then
				b = { x }
				break
			end
		end
		if not b then
			local solo: { Ticket } = {}
			local taken = table.clone(users)
			for j, x in sorted do
				if #solo >= need then
					break
				end
				if not usedIdx[j] and ArenaRules.size(x) == 1 and free(x, taken) and fits(x) then
					table.insert(solo, x)
					taken[x.entrant.userId] = true
				end
			end
			if #solo == need then
				b = solo
			end
		end
		if b then
			return { mode = e.mode, bracket = bracket, sides = { a, b } }
		end
	end
	return nil
end

-- Deterministic pairing of one list of tickets at `now`: oldest unpaired ticket first; its candidates share mode and
-- bracket, belong to another user and fit the wider of the two windows; the smallest rating difference wins (tie:
-- the older ticket). Returns the pairs (sides[1] = the older ticket) and the rest in queue order.
-- S128: teamSize > 1 groups the tickets by mode and bracket and forms teams with formTeams3 while it finds any.
function ArenaRules.pair(tickets: { Ticket }, now: number, teamSize: number?): ({ Pairing }, { Ticket })
	if (teamSize or 1) ~= 1 then
		local groups: { [string]: { Ticket } } = {}
		local order: { string } = {}
		local all = table.clone(tickets)
		table.sort(all, older)
		for _, t in all do
			local id = `{t.mode}|{t.bracket}`
			if not groups[id] then
				groups[id] = {}
				table.insert(order, id)
			end
			table.insert(groups[id], t)
		end
		local out: { Pairing } = {}
		local taken: { [Ticket]: boolean } = {}
		for _, id in order do
			local left = groups[id]
			while true do
				local pairing = ArenaRules.formTeams3(left, now)
				if not pairing then
					break
				end
				table.insert(out, pairing)
				for _, side in pairing.sides do
					for _, t in side do
						taken[t] = true
					end
				end
				local rest = {}
				for _, t in left do
					if not taken[t] then
						table.insert(rest, t)
					end
				end
				left = rest
			end
		end
		local rest = {}
		for _, t in all do
			if not taken[t] then
				table.insert(rest, t)
			end
		end
		return out, rest
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

-- S128: who may queue for 3v3 after canQueue passed for every member (`anyBusy` = one of them failed it): a player
-- without a party queues alone; a party queues only as a team of exactly three, by its leader, all in one bracket.
-- No queue for pairs (DECYZJE S128).
function ArenaRules.canQueue3(input: Queue3Input): (boolean, string?)
	if not input.inParty then
		return true, nil
	elseif input.partySize ~= (Arena.MODES["3v3"] :: Mode).teamSize then
		return false, "arena.error.party3"
	elseif not input.isLeader then
		return false, "arena.error.notLeader"
	elseif not input.sameBracket then
		return false, "arena.error.partyBracket"
	elseif input.anyBusy then
		return false, "arena.error.partyBusy"
	end
	return true, nil
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
		-- S128 (DESIGN-17 §6)
		rating3 = ELO.start,
		peak3 = ELO.start,
		wins3 = 0,
		losses3 = 0,
		played3 = 0,
		vs3 = { day = 0 },
		tokensWeek = { week = 0, n = 0 },
		titles = {},
		pendingReward = nil,
	}
end

-- A deep copy (the input of every rule stays untouched). Unknown fields of the input are dropped on purpose.
local function copy(state: ArenaState): ArenaState
	local s: any = state
	local out: any = ArenaRules.emptyState()
	for _, field in { "season", "tokens" } do
		if s[field] ~= nil then
			out[field] = s[field]
		end
	end
	-- the numbers and the day counters of every mode (S128: rating3, peak3, wins3, losses3, played3, vs3)
	for _, mode in Arena.MODES do
		for _, field in { mode.ratingField, mode.peakField, mode.winsField, mode.lossesField, mode.playedField } do
			if type(s[field]) == "number" then
				out[field] = s[field]
			end
		end
		local vs = s[mode.vsField]
		if type(vs) == "table" then
			out[mode.vsField] = table.clone(vs)
			out[mode.vsField].day = out[mode.vsField].day or 0
		end
	end
	if type(s.daily) == "table" then
		out.daily = { day = s.daily.day or 0, n = s.daily.n or 0 }
	end
	if type(s.tokensWeek) == "table" then
		out.tokensWeek = { week = tonumber(s.tokensWeek.week) or 0, n = tonumber(s.tokensWeek.n) or 0 }
	end
	if type(s.titles) == "table" then
		out.titles = table.clone(s.titles)
	end
	if type(s.pendingReward) == "table" then
		out.pendingReward = table.clone(s.pendingReward)
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
	-- S128: a season with rated matches of any mode closes into `last` (with the 3v3 numbers)
	if out.played + out.played3 > 0 then
		summary = {
			season = out.season,
			rating = out.rating,
			peak = out.peak,
			wins = out.wins,
			losses = out.losses,
			played = out.played,
			rewarded = false,
			rating3 = out.rating3,
			peak3 = out.peak3,
			wins3 = out.wins3,
			losses3 = out.losses3,
			played3 = out.played3,
		}
		out.last = table.clone(summary :: ArenaSeasonSummary)
	end
	-- the soft reset of every mode: rating, peak = the new rating, wins / losses / played = 0
	local fields: any = out
	for _, mode in Arena.MODES do
		local value = fields[mode.ratingField]
		if type(value) ~= "number" then
			value = ELO.start
		end
		local reset = Elo.apply(math.floor(ELO.start + (value - ELO.start) * Arena.SEASON.keep + 0.5), 0)
		fields[mode.ratingField] = reset
		fields[mode.peakField] = reset
		fields[mode.winsField] = 0
		fields[mode.lossesField] = 0
		fields[mode.playedField] = 0
	end
	out.season = season
	return out, summary
end

-- Matches against `oppKey` on UTC day `day` (the key "day" of `vs` is the day, never an opponent). S128: `field` =
-- the mode's vsField ("vs3" for 3v3; default "vs").
function ArenaRules.vsCount(state: ArenaState, oppKey: string, day: number, field: string?): number
	local vs = (state :: any)[field or "vs"]
	if type(vs) ~= "table" or vs.day ~= day or oppKey == "day" then
		return 0
	end
	return tonumber(vs[oppKey]) or 0
end

-- Whether the next match against `oppKey` today still changes the rating (S128: `field` as vsCount).
function ArenaRules.isRated(state: ArenaState, oppKey: string, day: number, field: string?): boolean
	return ArenaRules.vsCount(state, oppKey, day, field) < LIMITS.sameOpponentDaily
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
	local mode = input.mode
	-- S128: the counters of the mode (Data/Arena Mode fields; a mode without them writes the 1v1 fields)
	local fields: any = out
	local vsField = mode.vsField or "vs"
	local playedField = mode.playedField or "played"
	local winsField = mode.winsField or "wins"
	local lossesField = mode.lossesField or "losses"
	local peakField = mode.peakField or "peak"
	if type(fields[vsField]) ~= "table" or fields[vsField].day ~= input.day then
		fields[vsField] = { day = input.day }
	end
	local rated = input.rated
	for _, key in input.oppKeys do
		if not ArenaRules.isRated(out, key, input.day, vsField) then
			rated = false
		end
	end
	for _, key in input.oppKeys do
		if key ~= "day" then
			fields[vsField][key] = (tonumber(fields[vsField][key]) or 0) + 1
		end
	end
	local delta = 0
	if rated then
		local before = ArenaRules.ratingOf(out, mode)
		local played = tonumber(fields[playedField]) or 0
		delta = Elo.delta(before, input.oppRating, input.score, Elo.k(played))
		local after = Elo.apply(before, delta)
		delta = after - before
		fields[mode.ratingField] = after
		fields[playedField] = played + 1
		if input.score >= 1 then
			fields[winsField] = (tonumber(fields[winsField]) or 0) + 1
		elseif input.score <= 0 then
			fields[lossesField] = (tonumber(fields[lossesField]) or 0) + 1
		end
		fields[peakField] = math.max(tonumber(fields[peakField]) or after, after)
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

-- Arena Tokens (S128) --------------------------------------------------------------------------------------------------

-- The token week of a moment (Monday 00:00 UTC, S98 Time.weekNumber).
function ArenaRules.weekOf(now: number): number
	return Time.weekNumber(now)
end

-- Matches of UTC day `day` before the next one (the shared daily counter of 1v1 and 3v3).
function ArenaRules.dailyCount(state: ArenaState, day: number): number
	local daily = state.daily
	return if type(daily) == "table" and daily.day == day then tonumber(daily.n) or 0 else 0
end

-- Tokens earned in the week of `now`.
function ArenaRules.weekTokens(state: ArenaState, now: number): number
	local week = (state :: any).tokensWeek
	return if type(week) == "table" and week.week == ArenaRules.weekOf(now) then tonumber(week.n) or 0 else 0
end

-- The tokens of one match for one fighter (DESIGN-17 §6) and the reason shown with them (nil: a plain gain):
--   left (gave up the match) -> 0 "arena.tokens.left"; not rated (over the same-opponent limit) -> 0
--   "arena.tokens.sameOpponent"; a win pays TOKENS.win<mode>, a loss or a draw TOKENS.loss<mode>; the first
--   TOKENS.firstMatches matches of the day (`dailyBefore` = matches today before this one) pay x firstMul
--   ("arena.tokens.bonus"); at most what is left of tokensWeekCap ("arena.tokens.capped" / "cappedPart").
-- Nothing about the account, VIP or purchases comes in (tests/paywall.spec).
function ArenaRules.tokensFor(
	modeId: string,
	outcome: "win" | "loss" | "draw",
	dailyBefore: number,
	weekGot: number,
	rated: boolean,
	left: boolean
): (number, string?)
	if left then
		return 0, "arena.tokens.left"
	elseif not rated then
		return 0, "arena.tokens.sameOpponent"
	end
	local TOKENS: any = Arena.TOKENS
	local base = tonumber(TOKENS[if outcome == "win" then `win{modeId}` else `loss{modeId}`]) or 0
	local reason: string? = nil
	if dailyBefore < Arena.TOKENS.firstMatches then
		base *= Arena.TOKENS.firstMul
		reason = "arena.tokens.bonus"
	end
	local room = math.max(0, Arena.tokensWeekCap - weekGot)
	if room <= 0 then
		return 0, "arena.tokens.capped"
	elseif base > room then
		return room, "arena.tokens.cappedPart"
	end
	return base, reason
end

-- Adds `gain` tokens to a copy of the state (a new week resets tokensWeek first). The only place tokens are added
-- (ArenaService.AddTokens). S129/S130: event rewards call ArenaService.AddTokens, which uses this; whether they count
-- to the week cap is their decision. Returns the copy and the new balance.
-- S129: `opts.uncapped` (event rewards: Blood Moon, S130 tournament) adds to the balance without counting toward the
-- week's tokensWeekCap, so an event never eats the cap of matches (DECYZJE S129).
function ArenaRules.addTokens(
	state: ArenaState,
	gain: number,
	now: number,
	opts: { uncapped: boolean? }?
): (ArenaState, number)
	local out = copy(state)
	local week = ArenaRules.weekOf(now)
	if out.tokensWeek.week ~= week then
		out.tokensWeek = { week = week, n = 0 }
	end
	local n = math.max(0, math.floor(gain))
	out.tokens += n
	if not (opts and opts.uncapped) then
		out.tokensWeek.n += n
	end
	return out, out.tokens
end

-- Season rewards (S128) ------------------------------------------------------------------------------------------------

-- The tier of a finished season: the better of the 1v1 and the 3v3 peak (DECYZJE S128).
function ArenaRules.seasonTier(peak: number, peak3: number): string
	return ArenaRules.tierOf(math.max(peak, peak3))
end

-- The reward of the season closed into `last` (nil: none, already given, or fewer than seasonMinPlayed matches).
function ArenaRules.seasonReward(last: ArenaSeasonSummary?): SeasonRewardOut?
	if last == nil or last.rewarded then
		return nil
	end
	local played = (tonumber(last.played) or 0) + (tonumber(last.played3) or 0)
	if played < Arena.seasonMinPlayed then
		return nil
	end
	local tier = ArenaRules.seasonTier(tonumber(last.peak) or 0, tonumber(last.peak3) or 0)
	local reward = Arena.SEASON_REWARDS[tier]
	if not reward then
		return nil
	end
	return {
		season = last.season,
		tier = tier,
		title = reward.title,
		cosmetics = if reward.cosmetics then table.clone(reward.cosmetics) else {},
		shards = reward.shards or 0,
	}
end

-- Month and year of a season for "{month}.{year}" ("202611" -> "11", "2026"); ("?", "?") for a bad key.
function ArenaRules.seasonLabel(season: string): (string, string)
	local year, month = Time.monthLabel(season)
	if not year or not month then
		return "?", "?"
	end
	return string.format("%02d", month), tostring(year)
end

-- Arena shop (S128) ----------------------------------------------------------------------------------------------------

-- Whether a character may buy a shop entry (the same rule on the server and in the window). The server also checks
-- the distance to the Arena Master and the room in the backpack.
function ArenaRules.canBuyShop(
	entry: Arena.ArenaShopEntry?,
	character: any,
	ownedCosmetics: { [string]: boolean }?
): (boolean, string?)
	if entry == nil then
		return false, "error.badRequest"
	end
	local e = entry :: Arena.ArenaShopEntry
	local level = if type(character) == "table" then tonumber(character.level) or 0 else 0
	if level < (e.level or Arena.MIN_LEVEL) then
		return false, "arena.shop.error.level"
	end
	if e.kind == "cosmetic" and ownedCosmetics ~= nil and ownedCosmetics[e.id] == true then
		return false, "arena.shop.error.owned"
	end
	local arena = if type(character) == "table" then character.arena else nil
	local tokens = if type(arena) == "table" then tonumber(arena.tokens) or 0 else 0
	if tokens < e.price then
		return false, "arena.shop.error.tokens"
	end
	return true, nil
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

-- S128: the stand index of a side's bench (3v3: a knocked out fighter leaves the sand for it).
function ArenaRules.benchIndex(venue: Venue, side: number): number
	local bench = (venue :: any).bench
	return if type(bench) == "table" and bench[side] then bench[side] else 1
end

return ArenaRules
