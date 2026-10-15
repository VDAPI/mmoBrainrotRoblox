--!strict
-- The global arena queue (S127, DESIGN-17 §6), pure: queue entries in MemoryStore sorted maps, the atomic claim of a
-- pair, the match record and its offer, the arrival on the arena server, the way back and the server mode of a
-- reserved server. Nothing here calls Roblox: every store call goes through a Backend (src/server/Arena/Matchmaker
-- builds one on MemoryStoreService / MessagingService / TeleportService; Logic/MemoryFake is the in-memory one used in
-- Studio, after store errors and in tests/arenaqueue.spec). Backend calls may yield on a live server.
--
-- Store layout (Config.ArenaNet):
--   ArenaQueue_<mode>_<bracket>  SortedMap  key "<userId>_<slot>" -> Entry, sort key = rating, ttl entryTtl
--   ArenaMatches                 HashMap    "ArenaMatch_<id>" -> MatchRecord, ttl matchTtl
--   ReservedServers              HashMap    PrivateServerId -> { mode, ref }, ttl registryTtl
--   ArenaPenalty                 HashMap    "<userId>_<slot>" -> until (server time), ttl = the penalty
--   topic ArenaMatch             { op = "offer" | "go" | "cancel", id, jobs? }
--
-- Transforms (claim, refresh, respond, ...) return a function for Backend.update / hupdate: it gets the current value
-- and returns the new one, or nil to write nothing (UpdateAsync semantics). It may run several times (MemoryStore runs
-- it again on a conflict), so it depends only on its input and parameters; the caller reads the decision from the
-- returned value, never from a variable set inside the transform.
--
-- Nothing here reads purchases (DESIGN-17 §0.2, tests/paywall.spec).

local Arena = require("../Data/Arena")
local ArenaRules = require("./ArenaRules")
local Config = require("../Config")
local TableUtil = require("../Util/TableUtil")

local NET = Config.ArenaNet

export type Mode = string -- Data/Arena.MODES id: "1v1" (S128 adds "3v3")
export type Entry = {
	key: string, -- ticket.entrant.key "<userId>_<slot>" (the leaderboard key of S124)
	-- the S126 ticket as is: entrant (userId, slot, name, class, level, rating, played), mode, bracket ("40_59") and
	-- joinedAt (kept through re-queues after a failed offer)
	ticket: ArenaRules.Ticket,
	jobId: string,
	state: "wait" | "claimed",
	match: string?, -- set while claimed
	claimUntil: number?,
}
export type MatchPlayer = {
	key: string,
	userId: number,
	slot: number,
	jobId: string,
	rating: number,
	name: string,
	class: string,
	level: number,
	ok: boolean?,
	arrived: boolean?,
}
export type MatchState = "offered" | "accepted" | "cancelled" | "live" | "done" | "void"
export type MatchRecord = {
	id: string,
	mode: Mode,
	bracket: string,
	state: MatchState,
	spec: ArenaRules.MatchSpec, -- the S126 spec (origin = "global", venue = "pit"), ratings snapshotted
	players: { MatchPlayer }, -- two for 1v1, sorted by key
	org: string, -- jobId of the server that claimed the pair
	sameJob: boolean, -- always false: pairs on one server get no record and go through PairSource.take
	code: string?, -- ReservedServerAccessCode of the arena server
	psid: string?, -- its PrivateServerId
	created: number,
	acceptBy: number,
	reason: string?, -- cancel reason: "declined" | "timeout" | "left" | "teleport" | "noShow" | "server"
	by: string?, -- whose
	result: { winner: string?, noRating: boolean? }?,
}
export type Item = { key: string, value: any, sortKey: number? }
export type Backend = {
	-- SortedMap
	range: (map: string, lo: number?, hi: number?, count: number) -> (boolean, { Item }?),
	-- (ok, the value stored after the call, the value the last transform saw)
	update: (map: string, key: string, fn: (current: any?) -> (any?, number?), ttl: number) -> (boolean, any?, any?),
	remove: (map: string, key: string) -> boolean,
	-- HashMap
	hget: (map: string, key: string) -> (boolean, any?),
	hupdate: (map: string, key: string, fn: (current: any?) -> any?, ttl: number) -> (boolean, any?, any?),
	hremove: (map: string, key: string) -> boolean,
	-- others
	reserve: () -> (string?, string?), -- (accessCode, privateServerId) or nil
	publish: (message: { [string]: any }) -> boolean,
}
export type Cfg = typeof(Config.ArenaNet)
export type Status = "paired" | "local" | "none" | "lost" | "error"
export type PairOptions = {
	avoid: { [string]: boolean }?, -- keys this entry must not meet (declined an offer with it lately)
	force: boolean?, -- skip shouldInitiate (tests: two servers that both believe they initiate)
	fallback: boolean?, -- the local offer after the global wait: a partner of this server, any rating
	locals: { Entry }?, -- with `fallback`: this server's own waiting entries (no range read; the claims check the store)
	acceptSeconds: number?, -- default Data/Arena.QUEUE.acceptSeconds
	self: ((entry: Entry) -> ())?, -- gets the own entry as the range read saw it (a claim by another organizer)
}
export type Message = { op: "offer" | "go" | "cancel", id: string, jobs: { string }? }
export type ServerMode = "world" | "arena" | "tournament"
export type ReturnPlan = { kind: "instance", job: string } | { kind: "public" } | { kind: "kick" }

local ArenaQueue = {}

local function copy<T>(value: T): T
	return TableUtil.deepCopy(value)
end

-- Keys and names ---------------------------------------------------------------------------------------------------

function ArenaQueue.entryKey(userId: number, slot: number): string
	return `{math.floor(userId)}_{math.floor(slot)}`
end

function ArenaQueue.queueMap(mode: Mode, bracket: string): string
	return `{NET.queuePrefix}_{mode}_{bracket}`
end

function ArenaQueue.matchKey(id: string): string
	return "ArenaMatch_" .. id
end

-- The value of a ReservedServers entry (the one place that knows its shape; ServerMode.register and tryPair use it,
-- decideMode reads it).
function ArenaQueue.registryEntry(mode: ServerMode, ref: string): { mode: string, ref: string }
	return { mode = mode, ref = ref }
end

-- Entries ----------------------------------------------------------------------------------------------------------

-- A waiting entry of a ticket on this server (`ticket.joinedAt` is kept: a re-queue keeps its place).
function ArenaQueue.newEntry(ticket: ArenaRules.Ticket, jobId: string): Entry
	return {
		key = ticket.entrant.key,
		ticket = copy(ticket),
		jobId = jobId,
		state = "wait",
		match = nil,
		claimUntil = nil,
	}
end

local function sortKeyOf(entry: Entry): number
	return math.floor(entry.ticket.entrant.rating)
end

local function isEntry(value: any): boolean
	return type(value) == "table"
		and type(value.key) == "string"
		and type(value.ticket) == "table"
		and type(value.ticket.entrant) == "table"
		and type(value.jobId) == "string"
end

-- Writes `entry` (the player is on this server now: an older entry of the key from another server is replaced).
function ArenaQueue.put(entry: Entry): (current: any?) -> (any?, number?)
	return function(_current: any?): (any?, number?)
		return copy(entry), sortKeyOf(entry)
	end
end

-- The owner's refresh: the same entry with the rating, level and name now (renews the ttl). A claim whose time ran
-- out (the organizer died) goes back to "wait". No entry, or the entry of another server: nothing written.
function ArenaQueue.refresh(
	jobId: string,
	info: { rating: number, level: number, name: string },
	now: number
): (current: any?) -> (any?, number?)
	return function(current: any?): (any?, number?)
		if not isEntry(current) or current.jobId ~= jobId then
			return nil, nil
		end
		local e = copy(current) :: Entry
		e.ticket.entrant.rating = info.rating
		e.ticket.entrant.level = info.level
		e.ticket.entrant.name = info.name
		if e.state == "claimed" and (e.claimUntil or 0) < now then
			e.state = "wait"
			e.match = nil
			e.claimUntil = nil
		end
		return e, sortKeyOf(e)
	end
end

-- The atomic claim: a waiting entry (or one whose claim ran out) becomes claimed by `matchId` until now + hold.
-- UpdateAsync on one key is serialised, so a second claim sees "claimed" and writes nothing.
function ArenaQueue.claim(matchId: string, now: number, hold: number): (current: any?) -> (any?, number?)
	return function(current: any?): (any?, number?)
		if not isEntry(current) then
			return nil, nil
		end
		if current.state == "wait" or (current.state == "claimed" and (current.claimUntil or 0) < now) then
			local e = copy(current) :: Entry
			e.state = "claimed"
			e.match = matchId
			e.claimUntil = now + hold
			return e, sortKeyOf(e)
		end
		return nil, nil
	end
end

-- Lengthens the claim of `matchId` (the offer exists: until acceptBy + acceptGrace).
function ArenaQueue.extend(matchId: string, untilTs: number): (current: any?) -> (any?, number?)
	return function(current: any?): (any?, number?)
		if not isEntry(current) or current.match ~= matchId then
			return nil, nil
		end
		local e = copy(current) :: Entry
		e.claimUntil = untilTs
		return e, sortKeyOf(e)
	end
end

-- Gives the entry back to the queue (the claim of `matchId` only; joinedAt kept).
function ArenaQueue.unclaim(matchId: string): (current: any?) -> (any?, number?)
	return function(current: any?): (any?, number?)
		if not isEntry(current) or current.match ~= matchId then
			return nil, nil
		end
		local e = copy(current) :: Entry
		e.state = "wait"
		e.match = nil
		e.claimUntil = nil
		return e, sortKeyOf(e)
	end
end

-- Back to the queue after the match `matchId` fell through: the claim of that match is given back, a missing entry is
-- written again (`entry`, its old joinedAt), a claim of ANOTHER match stays (a new offer is already under way).
function ArenaQueue.release(matchId: string, entry: Entry): (current: any?) -> (any?, number?)
	return function(current: any?): (any?, number?)
		if not isEntry(current) then
			return copy(entry), sortKeyOf(entry)
		end
		if current.state == "claimed" and current.match ~= matchId then
			return nil, nil
		end
		local e = copy(entry)
		return e, sortKeyOf(e)
	end
end

-- Pairing ----------------------------------------------------------------------------------------------------------

local function older(a: Entry, b: Entry): boolean
	if a.ticket.joinedAt ~= b.ticket.joinedAt then
		return a.ticket.joinedAt < b.ticket.joinedAt
	end
	return a.key < b.key
end

local function claimedNow(e: Entry, now: number): boolean
	return e.state == "claimed" and (e.claimUntil or 0) >= now
end

-- The partner for `me` among `candidates`: the same condition as ArenaRules.pair (S126): same mode and bracket,
-- another user, |rating difference| <= the wider of the two windows; the smallest difference wins, then the older
-- ticket, then the key. Skips me, claimed entries and the `avoid` keys. `anyRating` (the local fallback) drops the
-- window.
function ArenaQueue.pickPartner(
	me: Entry,
	candidates: { Entry },
	now: number,
	opts: { avoid: { [string]: boolean }?, anyRating: boolean? }?
): Entry?
	local avoid = if opts and opts.avoid then opts.avoid else {}
	local anyRating = opts ~= nil and opts.anyRating == true
	local best: Entry? = nil
	local bestDiff = math.huge
	local mine = me.ticket
	for _, other in candidates do
		if not isEntry(other) then
			continue
		end
		local t = other.ticket
		if
			other.key == me.key
			or t.entrant.userId == mine.entrant.userId
			or claimedNow(other, now)
			or t.mode ~= mine.mode
			or t.bracket ~= mine.bracket
			or avoid[other.key]
		then
			continue
		end
		local diff = math.abs(t.entrant.rating - mine.entrant.rating)
		local window = math.max(ArenaRules.window(now - mine.joinedAt), ArenaRules.window(now - t.joinedAt))
		if not anyRating and diff > window then
			continue
		end
		local b = best
		if b == nil or diff < bestDiff or (diff == bestDiff and older(other, b)) then
			best, bestDiff = other, diff
		end
	end
	return best
end

-- Only the server of the longer waiting entry builds the pair (fewer collisions; correctness comes from the claims).
function ArenaQueue.shouldInitiate(me: Entry, other: Entry): boolean
	return me.ticket.joinedAt < other.ticket.joinedAt
		or (me.ticket.joinedAt == other.ticket.joinedAt and me.key < other.key)
end

-- The order of the claims: the smaller key first, the same on every server.
function ArenaQueue.lockOrder(a: Entry, b: Entry): (Entry, Entry)
	if a.key < b.key then
		return a, b
	end
	return b, a
end

-- The S126 pairing of two entries (sides[1] = the older one, as ArenaRules.pair).
function ArenaQueue.pairingOf(a: Entry, b: Entry, fallback: boolean?): ArenaRules.Pairing
	local first, second = a, b
	if older(b, a) then
		first, second = b, a
	end
	return {
		mode = first.ticket.mode,
		bracket = first.ticket.bracket,
		sides = { { copy(first.ticket) }, { copy(second.ticket) } },
		fallback = if fallback then true else nil,
	}
end

-- The match record of a claimed pair from two servers (ratings snapshotted from the tickets).
function ArenaQueue.newRecord(
	id: string,
	a: Entry,
	b: Entry,
	org: string,
	now: number,
	acceptSeconds: number,
	code: string?,
	psid: string?
): MatchRecord
	local pairing = ArenaQueue.pairingOf(a, b)
	local sides: { { ArenaRules.Entrant } } = {}
	for i, list in pairing.sides do
		sides[i] = { copy(list[1].entrant) }
	end
	local players: { MatchPlayer } = {}
	for _, e in { a, b } do
		local en = e.ticket.entrant
		table.insert(players, {
			key = e.key,
			userId = en.userId,
			slot = en.slot,
			jobId = e.jobId,
			rating = en.rating,
			name = en.name,
			class = en.class,
			level = en.level,
		})
	end
	table.sort(players, function(x: MatchPlayer, y: MatchPlayer): boolean
		return x.key < y.key
	end)
	return {
		id = id,
		mode = pairing.mode,
		bracket = pairing.bracket,
		state = "offered",
		spec = {
			id = id,
			mode = pairing.mode,
			bracket = pairing.bracket,
			season = ArenaRules.seasonOf(now),
			rated = true,
			unrated = {},
			sides = sides,
			venue = "pit",
			origin = "global",
			createdAt = now,
		},
		players = players,
		org = org,
		sameJob = false,
		code = code,
		psid = psid,
		created = now,
		acceptBy = now + acceptSeconds,
	}
end

local function unclaimBoth(backend: Backend, map: string, a: Entry, b: Entry?, matchId: string, ttl: number)
	backend.update(map, a.key, ArenaQueue.unclaim(matchId), ttl)
	if b then
		backend.update(map, b.key, ArenaQueue.unclaim(matchId), ttl)
	end
end

-- One organizer step for the waiting entry `me` (synchronous with the backend). Status:
--   "paired" + MatchRecord: a pair with another server, the record is written and announced (offer);
--   "local" + ArenaRules.Pairing: both entries were on this server (or the local fallback): the entries are removed
--     and the pairing goes through PairSource.take into the S126 offer;
--   "none": no partner (or the partner's server initiates); "lost": a claim was taken by somebody else (retry at the
--   next poll); "error": a store call failed (both claims given back).
function ArenaQueue.tryPair(
	backend: Backend,
	me: Entry,
	cfg: Cfg,
	now: number,
	newId: () -> string,
	jobId: string,
	opts: PairOptions?
): (Status, any?)
	local o: PairOptions = opts or {}
	local map = ArenaQueue.queueMap(me.ticket.mode, me.ticket.bracket)
	-- 1. the candidates around my rating (bounds are exclusive; the initiator waits longer, so its window is wider)
	-- (the fallback with `locals` reads nothing: a range read of the whole bracket holds only the lowest ratings)
	local candidates: { Entry } = {}
	local locals = if o.fallback then o.locals else nil
	if locals then
		for _, e in locals do
			if isEntry(e) and e.jobId == jobId then
				table.insert(candidates, e)
			end
		end
	else
		local lo, hi = nil, nil
		if not o.fallback then
			local w = ArenaRules.window(now - me.ticket.joinedAt)
			lo, hi = me.ticket.entrant.rating - w - 1, me.ticket.entrant.rating + w + 1
		end
		local ok, items = backend.range(map, lo, hi, cfg.rangeCount)
		if not ok or not items then
			return "error", nil
		end
		for _, item in items do
			local e = item.value
			if isEntry(e) and e.key == me.key and o.self then
				o.self(e)
			end
			if isEntry(e) and (not o.fallback or e.jobId == jobId) then
				table.insert(candidates, e)
			end
		end
	end
	-- 2. the partner
	local partner = ArenaQueue.pickPartner(me, candidates, now, { avoid = o.avoid, anyRating = o.fallback })
	if not partner then
		return "none", nil
	end
	if not o.force and not o.fallback and not ArenaQueue.shouldInitiate(me, partner) then
		return "none", nil
	end
	-- 3-4. the claims in a fixed key order, the first one given back when the second fails
	local matchId = newId()
	local first, second = ArenaQueue.lockOrder(me, partner)
	local ok1, got1 = backend.update(map, first.key, ArenaQueue.claim(matchId, now, cfg.claimHold), cfg.entryTtl)
	if not ok1 or type(got1) ~= "table" or got1.match ~= matchId then
		return "lost", nil
	end
	local ok2, got2 = backend.update(map, second.key, ArenaQueue.claim(matchId, now, cfg.claimHold), cfg.entryTtl)
	if not ok2 or type(got2) ~= "table" or got2.match ~= matchId then
		unclaimBoth(backend, map, first, nil, matchId, cfg.entryTtl)
		return "lost", nil
	end
	local a, b = got1 :: Entry, got2 :: Entry
	-- 5. both here: no reservation, record or message; the pair goes to the S126 offer on this server
	if a.jobId == b.jobId then
		backend.remove(map, a.key)
		backend.remove(map, b.key)
		return "local", ArenaQueue.pairingOf(a, b, o.fallback)
	end
	local code, psid = backend.reserve()
	if not code or not psid then
		unclaimBoth(backend, map, first, second, matchId, cfg.entryTtl)
		return "error", nil
	end
	-- 6. the registry of the reserved server, then the record (never over an existing one)
	local okReg = backend.hupdate(cfg.registryMap, psid, function(_current: any?): any?
		return ArenaQueue.registryEntry("arena", matchId)
	end, cfg.registryTtl)
	if not okReg then
		unclaimBoth(backend, map, first, second, matchId, cfg.entryTtl)
		return "error", nil
	end
	local accept = o.acceptSeconds or Arena.QUEUE.acceptSeconds
	local record = ArenaQueue.newRecord(matchId, a, b, jobId, now, accept, code, psid)
	local okRec, stored = backend.hupdate(cfg.matchMap, ArenaQueue.matchKey(matchId), function(current: any?): any?
		if current == nil then
			return copy(record)
		end
		return nil
	end, cfg.matchTtl)
	if not okRec or type(stored) ~= "table" or stored.id ~= matchId or stored.org ~= jobId then
		unclaimBoth(backend, map, first, second, matchId, cfg.entryTtl)
		return "error", nil
	end
	-- 7. the claims live until the offer is over (errors do not matter: refresh never frees an entry of a live record)
	local hold = record.acceptBy + cfg.acceptGrace
	backend.update(map, a.key, ArenaQueue.extend(matchId, hold), cfg.entryTtl)
	backend.update(map, b.key, ArenaQueue.extend(matchId, hold), cfg.entryTtl)
	-- 8. the message (best effort: the servers also read the record when they poll)
	backend.publish({ op = "offer", id = matchId, jobs = { record.players[1].jobId, record.players[2].jobId } })
	return "paired", record
end

-- Offers -----------------------------------------------------------------------------------------------------------

local function isRecord(value: any): boolean
	return type(value) == "table" and type(value.id) == "string" and type(value.players) == "table"
end

local function playerIn(record: MatchRecord, key: string): MatchPlayer?
	for _, p in record.players do
		if p.key == key then
			return p
		end
	end
	return nil
end

-- A player's answer: accept marks ok (both ok -> "accepted"), a refusal cancels ("declined", or `reason` such as
-- "left"). Only while "offered" and before acceptBy.
function ArenaQueue.respond(key: string, accept: boolean, now: number, reason: string?): (current: any?) -> any?
	return function(current: any?): any?
		if not isRecord(current) or current.state ~= "offered" or now > current.acceptBy then
			return nil
		end
		local r = copy(current) :: MatchRecord
		local p = playerIn(r, key)
		if not p then
			return nil
		end
		if accept then
			if p.ok then
				return nil
			end
			p.ok = true
			local all = true
			for _, other in r.players do
				if not other.ok then
					all = false
				end
			end
			if all then
				r.state = "accepted"
			end
		else
			r.state = "cancelled"
			r.reason = reason or "declined"
			r.by = key
		end
		return r
	end
end

-- The end of time: an offer past acceptBy is cancelled ("timeout", by the first player without an answer); an
-- accepted or live record near the end of its ttl becomes "void" (cleaning up).
function ArenaQueue.expire(now: number, cfg: Cfg): (current: any?) -> any?
	return function(current: any?): any?
		if not isRecord(current) then
			return nil
		end
		local r = copy(current) :: MatchRecord
		if r.state == "offered" and now > r.acceptBy then
			r.state = "cancelled"
			r.reason = "timeout"
			for _, p in r.players do
				if not p.ok then
					r.by = p.key
					break
				end
			end
			return r
		elseif (r.state == "accepted" or r.state == "live") and now > r.created + cfg.matchTtl - 30 then
			r.state = "void"
			return r
		end
		return nil
	end
end

-- A cancel from "offered" or "accepted" (reasons "left", "teleport", "noShow", "server").
function ArenaQueue.cancel(reason: string, by: string?): (current: any?) -> any?
	return function(current: any?): any?
		if not isRecord(current) or (current.state ~= "offered" and current.state ~= "accepted") then
			return nil
		end
		local r = copy(current) :: MatchRecord
		r.state = "cancelled"
		r.reason = reason
		r.by = by
		return r
	end
end

-- The arena server's steps: "accepted" -> "live" (the match starts), a player arrived, "live" -> "done" with the
-- result, "accepted" / "live" -> "void" (the server closes mid-match: no rating change beyond what was written).
function ArenaQueue.goLive(): (current: any?) -> any?
	return function(current: any?): any?
		if not isRecord(current) or current.state ~= "accepted" then
			return nil
		end
		local r = copy(current) :: MatchRecord
		r.state = "live"
		return r
	end
end

function ArenaQueue.arrived(key: string): (current: any?) -> any?
	return function(current: any?): any?
		if not isRecord(current) or (current.state ~= "accepted" and current.state ~= "live") then
			return nil
		end
		local r = copy(current) :: MatchRecord
		local p = playerIn(r, key)
		if not p or p.arrived then
			return nil
		end
		p.arrived = true
		return r
	end
end

function ArenaQueue.finish(result: { winner: string?, noRating: boolean? }): (current: any?) -> any?
	return function(current: any?): any?
		if not isRecord(current) or (current.state ~= "live" and current.state ~= "accepted") then
			return nil
		end
		local r = copy(current) :: MatchRecord
		r.state = "done"
		r.result = copy(result)
		return r
	end
end

function ArenaQueue.void(): (current: any?) -> any?
	return function(current: any?): any?
		if not isRecord(current) or (current.state ~= "live" and current.state ~= "accepted") then
			return nil
		end
		local r = copy(current) :: MatchRecord
		r.state = "void"
		return r
	end
end

-- Whether THIS write changed the state to "accepted" or "cancelled" (`before` = the value the transform saw, `after`
-- = the value stored now). Only that server sends "go" / "cancel"; the others react to the message or to the record
-- they read when they poll.
function ArenaQueue.changed(before: any?, after: any?): ("accepted" | "cancelled")?
	if not isRecord(after) then
		return nil
	end
	local was: string? = if isRecord(before) then before.state else nil
	local now: string = after.state
	if now == was then
		return nil
	elseif now == "accepted" then
		return "accepted"
	elseif now == "cancelled" then
		return "cancelled"
	end
	return nil
end

export type After = "teleport" | "requeue" | "remove" | "penalty" | "wait"

-- What the server of player `key` does with its entry after reading the record (nil record: none found; `entry` =
-- the entry the server holds, for a claim that ran out without a record).
function ArenaQueue.entryAfter(record: any?, key: string, entry: Entry?, now: number): After
	if not isRecord(record) then
		if entry and entry.state == "claimed" and (entry.claimUntil or 0) < now then
			return "requeue"
		end
		return "wait"
	end
	local r = record :: MatchRecord
	if r.state == "accepted" then
		return "teleport"
	elseif r.state == "offered" or r.state == "live" then
		return "wait"
	elseif r.state == "cancelled" then
		if r.by == key then
			if r.reason == "declined" or r.reason == "timeout" or r.reason == "left" then
				return "penalty"
			end
			-- my own teleport failure or no-show: the arena server already decided; out of the queue
			return "remove"
		end
		return "requeue"
	end
	return "remove" -- done, void
end

-- The arena server ---------------------------------------------------------------------------------------------------

-- Whether both fighters are here ("start"), one is late ("wait") or the time ran out ("noShow" + the missing keys).
function ArenaQueue.arrival(
	record: MatchRecord,
	present: { [string]: boolean },
	bootTs: number,
	now: number,
	cfg: Cfg
): ("wait" | "start" | "noShow", { string })
	local missing: { string } = {}
	for _, p in record.players do
		if not present[p.key] then
			table.insert(missing, p.key)
		end
	end
	if #missing == 0 then
		return "start", missing
	end
	if now - bootTs >= cfg.arriveTimeout then
		return "noShow", missing
	end
	return "wait", missing
end

-- Whether user `userId` with character slot `slot` belongs in this match (TeleportData is only a hint: the record
-- decides).
function ArenaQueue.allowed(record: any?, userId: number, slot: number): boolean
	if not isRecord(record) or (record.state ~= "accepted" and record.state ~= "live") then
		return false
	end
	for _, p in (record :: MatchRecord).players do
		if p.userId == userId and p.slot == slot then
			return true
		end
	end
	return false
end

-- The way back from the arena server, attempt 1, 2, ...: the server the player came from (`returnJob`), then any
-- public server, then a kick (the player rejoins as usual).
function ArenaQueue.returnPlan(attempt: number, returnJob: string?, cfg: Cfg): ReturnPlan
	local tries = cfg.teleportRetries
	local n = attempt
	if type(returnJob) == "string" and returnJob ~= "" then
		if n <= tries then
			return { kind = "instance", job = returnJob }
		end
		n -= tries
	end
	if n <= tries then
		return { kind = "public" }
	end
	return { kind = "kick" }
end

local MODES: { [string]: ServerMode } = { arena = "arena", tournament = "tournament" }

-- The mode of this server at boot. Ordinary servers and players' private servers are "world"; a reserved server takes
-- its mode from the ReservedServers entry, else from the first player's TeleportData; without either it runs as a
-- world (a reserved server that does not know why it exists breaks nothing).
function ArenaQueue.decideMode(info: {
	privateServerId: string,
	ownerId: number,
	registry: any?,
	joinData: any?,
}): (ServerMode, string?)
	if info.privateServerId == "" or info.ownerId ~= 0 then
		return "world", nil
	end
	local reg = info.registry
	if type(reg) == "table" and type(reg.mode) == "string" and MODES[reg.mode] and type(reg.ref) == "string" then
		return MODES[reg.mode], reg.ref
	end
	local join = info.joinData
	local data = if type(join) == "table" then join.TeleportData else nil
	if type(data) == "table" and type(data.serverMode) == "string" and MODES[data.serverMode] then
		local ref = if type(data.arenaMatch) == "string"
			then data.arenaMatch
			elseif type(data.tourney) == "string" then data.tourney
			else nil
		if ref then
			return MODES[data.serverMode], ref
		end
	end
	return "world", nil
end

local OPS = { offer = true, go = true, cancel = true }

-- A topic message, nil when malformed.
function ArenaQueue.parseMessage(data: any): Message?
	if type(data) ~= "table" or type(data.op) ~= "string" or not OPS[data.op] then
		return nil
	end
	if type(data.id) ~= "string" or #data.id == 0 or #data.id > 64 then
		return nil
	end
	local jobs: { string }? = nil
	if data.jobs ~= nil then
		if type(data.jobs) ~= "table" then
			return nil
		end
		local list: { string } = {}
		for _, j in data.jobs do
			if type(j) ~= "string" then
				return nil
			end
			table.insert(list, j)
		end
		jobs = list
	end
	return { op = data.op :: any, id = data.id, jobs = jobs }
end

-- Fallback (F1) ------------------------------------------------------------------------------------------------------

-- "global" while the stores answer; "local" in Studio, without a backend or until `offlineUntil`.
function ArenaQueue.scope(
	s: { backendOk: boolean, studio: boolean, offlineUntil: number, now: number }
): "global" | "local"
	if s.studio or not s.backendOk or s.now < s.offlineUntil then
		return "local"
	end
	return "global"
end

-- Whether a player waiting `waited` s gets the local offer (somebody on this server waits in the same bracket).
function ArenaQueue.localOffer(waited: number, globalWait: number, localCandidate: boolean): boolean
	return localCandidate and waited >= globalWait
end

return ArenaQueue
