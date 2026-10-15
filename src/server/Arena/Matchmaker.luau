--!strict
-- The global arena queue (S127, DESIGN-17 §6): a PairSource of kind "global" (Arena/Types) that ArenaService puts in
-- front of its local queue (ArenaService.AddSource). One queue for the player: "Join 1v1 queue" writes the ticket to
-- MemoryStore (SortedMap ArenaQueue_<mode>_<bracket>, Logic/ArenaQueue); every server polls its own entries:
--   * a partner on another server: the longer waiting side claims both entries (UpdateAsync, fixed key order, given
--     back on a failure), reserves an arena server, writes the match record and announces it (topic ArenaMatch);
--     both servers show the S126 offer card (`arenaLive.offer` with scope "global"); the answers go into the record
--     (ArenaRespond -> Matchmaker.Respond); when both accepted, each server teleports its player (RemoteHost ->
--     Arena/Transfer) and the arena server runs the match (Arena/ArenaHost);
--   * a partner on this server (always in Studio and on the in-memory store): the pair goes through `take` into the
--     unchanged S126 flow (offer, accept, the Ristalle sand);
--   * after Config.ArenaNet.globalWait s without a global partner: a local offer with somebody of this server outside
--     the rating window (Pairing.fallback: declining it costs nothing).
-- Stores: the real Backend below (MemoryStore, MessagingService, TeleportService:ReserveServer; every call in pcall
-- through Market/Retry.call) or Logic/MemoryFake (Studio, /arenanet offline, Config.ArenaNet.offlineAfterErrors store
-- errors in a row for offlineFor s). The fake reserves nothing, so every pair on it is a pair of this server.
-- Races (tests/arenaqueue.spec H3):
--   * one entry never joins two matches: the claim is one UpdateAsync transform on the entry's key; a second one
--     sees "claimed";
--   * A-B and C-B at once: whoever claims B first wins; the other gives its first claim back and retries later;
--   * A-B from both servers (equal times): the same key order on both, so one gets both claims, the other none;
--   * the organizer dies after a claim: the claim runs out after claimHold s and the owner's refresh frees it;
--   * the organizer dies after the record, before the message: the owners read the record when they poll;
--   * both servers see the end of the time: `expire` is a transform, only the first changes the state, and only the
--     server whose write changed it sends "cancel" (ArenaQueue.changed); the same for "go";
--   * a lost "go": the poll reads "accepted" and teleports (within one poll, 3-5 s);
--   * a player cannot queue twice: ProfileStore keeps one session per account, the entry key is "<userId>_<slot>"
--     and pickPartner skips the same user id;
--   * the clock: server time (Workspace:GetServerTimeNow, UTC seconds) everywhere; records keep acceptGrace of
--     slack, no rule depends on a fraction of a second.
-- Cost (MemoryStore limit: 1000 + 100 x players requests a minute per experience, create.roblox.com MemoryStore
-- limits): one GetRangeAsync per waiting player every 3-5 s, one refresh per player every 30 s, record reads only
-- around offers.
-- S128 (3v3): a party team is one entry of its leader with the members' keys (`members`, `teamOf`); its offer goes
-- to every member, a refusal of one member takes the team out (Logic/ArenaQueue.entryAfterTeam), the pairing goes
-- through ArenaQueue.tryTeams (claims of every entry of the pairing, all given back on a failure).
-- Nothing here reads purchases (DESIGN-17 §0.2, tests/paywall.spec).

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Arena = require(Shared.Data.Arena)
local ArenaQueue = require(Shared.Logic.ArenaQueue)
local ArenaRules = require(Shared.Logic.ArenaRules)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local MemoryFake = require(Shared.Logic.MemoryFake)
local RemoteHost = require(script.Parent.RemoteHost)
local Retry = require(script.Parent.Parent.Market.Retry)
local Rng = require(Shared.Logic.Rng)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)
local ArenaTypes = require(script.Parent.Types)

local log = Log.new("Matchmaker")

local NET = Config.ArenaNet
local MAX_TTL = 3888000 -- MemoryStore's longest expiration (45 days)
local RANGE_LIMIT = 200 -- GetRangeAsync count limit

export type Deps = {
	playerOfKey: (key: string) -> Player?,
	state: (player: Player) -> Types.ArenaState?, -- ArenaService.State (the season now)
	inCombat: (player: Player) -> boolean,
	toast: (player: Player, key: string, args: { [string]: any }?, kind: string?) -> (),
	setLive: (player: Player, field: string, value: any) -> (),
	-- the ArenaService side of the player's queue state
	offered: (player: Player) -> (), -- the entry became a global offer (no longer "in the queue")
	requeued: (player: Player, ticket: ArenaRules.Ticket) -> (), -- back in the queue (its old joinedAt)
	dropped: (player: Player) -> (), -- out of the queue for good
	publish: (player: Player) -> (), -- arenaLive.queue changed (scope, window, waitingLocal)
	penalize: (key: string, untilAt: number) -> (), -- the S126 penalty in memory and arenaLive.penaltyUntil
	-- the entrant's values now (rating of the mode, level, name), nil when the character is gone
	refreshInfo: (player: Player, mode: string) -> { rating: number, level: number, name: string }?,
}

type Local = {
	key: string,
	ticket: ArenaRules.Ticket,
	backend: ArenaQueue.Backend,
	state: "wait" | "offer" | "go",
	match: string?,
	record: ArenaQueue.MatchRecord?,
	refreshedAt: number,
	combat: boolean, -- seen in combat during the offer (no answer then is excused)
	window: number?,
	waitingLocal: boolean?,
	members: { string }?, -- S128: the member keys of a party team (the leader first)
}

local Matchmaker = {}

local JOB = if game.JobId ~= "" then game.JobId else "studio"
local studio = RunService:IsStudio()

local deps: Deps? = nil
local entries: { [string]: Local } = {}
local ready: { ArenaRules.Pairing } = {}
local avoid: { [string]: { [string]: number } } = {} -- key -> partner key -> until (server time)
local partnerOf: { [string]: string } = {} -- local pairs handed to `take`: on a re-queue the partner is avoided
local teamOf: { [string]: string } = {} -- S128: member key of a party team -> the team's entry key
local errors = 0
local offlineUntil = 0
local forced = false
local lastError: string? = nil
local rng = Rng.new() -- seeded from os.clock: servers started in the same second poll apart

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function need(): Deps
	local d = deps
	if not d then
		error("Arena/Matchmaker: Start first")
	end
	return d
end

-- The real backend -------------------------------------------------------------------------------------------------

local sortedMaps: { [string]: any } = {}
local hashMaps: { [string]: any } = {}

local function sorted(name: string): any
	local map = sortedMaps[name]
	if not map then
		map = MemoryStoreService:GetSortedMap(name)
		sortedMaps[name] = map
	end
	return map
end

local function hash(name: string): any
	local map = hashMaps[name]
	if not map then
		map = MemoryStoreService:GetHashMap(name)
		hashMaps[name] = map
	end
	return map
end

local function ttlOf(ttl: number): number
	return math.clamp(math.floor(ttl), 1, MAX_TTL)
end

local function noteResult(ok: boolean, label: string, err: any?)
	if ok then
		errors = 0
		return
	end
	errors += 1
	lastError = `{label}: {tostring(err)}`
	if errors >= NET.offlineAfterErrors and now() >= offlineUntil then
		offlineUntil = now() + NET.offlineFor
		errors = 0
		log:warn(
			"MemoryStore failing (%s): the arena queue runs on this server for %d s",
			tostring(err),
			NET.offlineFor
		)
	end
end

-- MemoryStore / MessagingService / TeleportService behind the Logic/ArenaQueue Backend interface.
local live: ArenaQueue.Backend = {
	-- MemoryStoreSortedMap:GetRangeAsync(direction, count, exclusiveLowerBound?, exclusiveUpperBound?): bounds are
	-- tables { key?, sortKey? }; returns { { key, value, sortKey } } in the order of the sort key, then the key.
	range = function(map: string, lo: number?, hi: number?, count: number): (boolean, { ArenaQueue.Item }?)
		local ok, result = Retry.call(`{map}.Range`, function()
			return sorted(map):GetRangeAsync(
				Enum.SortDirection.Ascending,
				math.clamp(math.floor(count), 1, RANGE_LIMIT),
				if lo then { sortKey = lo } else nil,
				if hi then { sortKey = hi } else nil
			)
		end)
		noteResult(ok, "GetRangeAsync", result)
		if not ok or type(result) ~= "table" then
			return false, nil
		end
		local out: { ArenaQueue.Item } = {}
		for _, item in result :: { any } do
			if type(item) == "table" and type(item.key) == "string" then
				table.insert(out, { key = item.key, value = item.value, sortKey = tonumber(item.sortKey) })
			end
		end
		return true, out
	end,
	-- MemoryStoreSortedMap:UpdateAsync(key, transform(value, sortKey) -> (value, sortKey) | nil, expiration): the
	-- transform may run several times; nil cancels the write.
	update = function(
		map: string,
		key: string,
		fn: (current: any?) -> (any?, number?),
		ttl: number
	): (boolean, any?, any?)
		local seen: any? = nil
		local wrote: any? = nil
		local ok, err = Retry.call(`{map}.Update`, function()
			seen, wrote = nil, nil
			sorted(map):UpdateAsync(key, function(value: any, _sortKey: any): (any, any)
				seen = value
				local v, s = fn(value)
				wrote = v
				if v == nil then
					return nil, nil
				end
				return v, s
			end, ttlOf(ttl))
		end)
		noteResult(ok, "SortedMap.UpdateAsync", err)
		if not ok then
			return false, nil, nil
		end
		return true, if wrote ~= nil then wrote else seen, seen
	end,
	remove = function(map: string, key: string): boolean
		local ok, err = Retry.call(`{map}.Remove`, function()
			sorted(map):RemoveAsync(key)
		end)
		noteResult(ok, "SortedMap.RemoveAsync", err)
		return ok
	end,
	-- MemoryStoreHashMap:GetAsync(key) -> value or nil
	hget = function(map: string, key: string): (boolean, any?)
		local ok, result = Retry.call(`{map}.Get`, function()
			return hash(map):GetAsync(key)
		end)
		noteResult(ok, "HashMap.GetAsync", result)
		return ok, if ok then result else nil
	end,
	-- MemoryStoreHashMap:UpdateAsync(key, transform(value) -> value | nil, expiration)
	hupdate = function(map: string, key: string, fn: (current: any?) -> any?, ttl: number): (boolean, any?, any?)
		local seen: any? = nil
		local wrote: any? = nil
		local ok, err = Retry.call(`{map}.HUpdate`, function()
			seen, wrote = nil, nil
			hash(map):UpdateAsync(key, function(value: any): any
				seen = value
				local v = fn(value)
				wrote = v
				return v
			end, ttlOf(ttl))
		end)
		noteResult(ok, "HashMap.UpdateAsync", err)
		if not ok then
			return false, nil, nil
		end
		return true, if wrote ~= nil then wrote else seen, seen
	end,
	hremove = function(map: string, key: string): boolean
		local ok, err = Retry.call(`{map}.HRemove`, function()
			hash(map):RemoveAsync(key)
		end)
		noteResult(ok, "HashMap.RemoveAsync", err)
		return ok
	end,
	-- TeleportService:ReserveServer(placeId) -> (accessCode, privateServerId); a reserved server starts only when
	-- somebody joins it (cheap to reserve before the offer).
	reserve = function(): (string?, string?)
		local ok, code, psid = pcall(function()
			return TeleportService:ReserveServer(game.PlaceId)
		end)
		noteResult(ok, "ReserveServer", code)
		if not ok or type(code) ~= "string" or type(psid) ~= "string" then
			return nil, nil
		end
		return code, psid
	end,
	-- MessagingService:PublishAsync(topic, message): best effort (the servers also read the record when they poll)
	publish = function(message: { [string]: any }): boolean
		local ok, err = pcall(function()
			MessagingService:PublishAsync(NET.topic, message)
		end)
		if not ok then
			lastError = `PublishAsync: {tostring(err)}`
		end
		return ok
	end,
}

local fake: any = MemoryFake.new(now)
fake.canReserve = false -- the in-memory store never teleports: every pair on it is a pair of this server

-- The backend new entries use now.
local function current(): ArenaQueue.Backend
	if studio or forced or now() < offlineUntil then
		return fake
	end
	return live
end

local function scopeOf(backend: ArenaQueue.Backend): "global" | "local"
	return if backend == live then "global" else "local"
end

-- Entries ------------------------------------------------------------------------------------------------------------

local function mapOf(ticket: ArenaRules.Ticket): string
	return ArenaQueue.queueMap(ticket.mode, ticket.bracket)
end

local function playerOf(st: Local): Player?
	return need().playerOfKey(st.key)
end

-- S128: the keys of the fighters of an entry (a party team: its members).
local function keysOf(st: Local): { string }
	return st.members or { st.key }
end

-- S128: the online players of an entry by key.
local function playersOf(st: Local): { [string]: Player }
	local out: { [string]: Player } = {}
	for _, key in keysOf(st) do
		local player = need().playerOfKey(key)
		if player then
			out[key] = player
		end
	end
	return out
end

local function membersOfTicket(ticket: ArenaRules.Ticket): { string }?
	if not ticket.members then
		return nil
	end
	local out = {}
	for _, m in ticket.members do
		table.insert(out, m.key)
	end
	return out
end

local function track(st: Local)
	for _, key in (st.members or {}) :: { string } do
		teamOf[key] = st.key
	end
end

-- The entry of a key (a party team member finds its team).
local function entryOf(key: string): Local?
	return entries[teamOf[key] or key]
end

local function avoidOf(key: string): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local list = avoid[key]
	if list then
		local t = now()
		for other, untilAt in list do
			if untilAt > t then
				out[other] = true
			else
				list[other] = nil
			end
		end
	end
	return out
end

local function addAvoid(key: string, other: string)
	local list = avoid[key] or {}
	list[other] = now() + Arena.QUEUE.declinePenalty
	avoid[key] = list
end

-- Writes the entry of `st` into its backend (yields). False when the store refused.
local function put(st: Local): boolean
	local entry = ArenaQueue.newEntry(st.ticket, JOB)
	local ok = st.backend.update(mapOf(st.ticket), st.key, ArenaQueue.put(entry), NET.entryTtl)
	st.refreshedAt = now()
	return ok
end

local function forget(st: Local, removeEntry: boolean)
	if entries[st.key] == st then
		entries[st.key] = nil
		for _, key in (st.members or {}) :: { string } do
			if teamOf[key] == st.key then
				teamOf[key] = nil
			end
		end
	end
	if removeEntry then
		task.spawn(function()
			st.backend.remove(mapOf(st.ticket), st.key)
		end)
	end
end

-- The queue view of a waiting entry (ArenaService merges it into arenaLive.queue).
local function infoOf(st: Local): { [string]: any }
	return {
		scope = scopeOf(st.backend),
		window = st.window,
		waitingLocal = st.waitingLocal,
	}
end

-- The S126 penalty here and in ArenaPenalty (every server checks it at join).
local function penalize(key: string)
	local untilAt = now() + Arena.QUEUE.declinePenalty
	need().penalize(key, untilAt)
	Matchmaker.RecordPenalty(key, untilAt)
end

-- Offers ---------------------------------------------------------------------------------------------------------------

local function opponentOf(record: ArenaQueue.MatchRecord, key: string): ArenaQueue.MatchPlayer?
	for _, p in record.players do
		if p.key ~= key then
			return p
		end
	end
	return nil
end

-- S128: the side of a player key in a record (1v1: the spec sides of one entrant each).
local function sideIn(record: ArenaQueue.MatchRecord, key: string): number?
	for side, list in record.spec.sides do
		for _, e in list do
			if e.key == key then
				return side
			end
		end
	end
	return nil
end

local function offerView(record: ArenaQueue.MatchRecord, player: Player, myKey: string): { [string]: any }?
	local side = sideIn(record, myKey)
	local opp: ArenaQueue.MatchPlayer? = nil
	local oppKeys: { string } = {}
	local mineNames, themNames = {}, {}
	for s, list in record.spec.sides do
		for _, e in list do
			if s == side then
				table.insert(mineNames, e.name)
			else
				table.insert(themNames, e.name)
				table.insert(oppKeys, e.key)
			end
		end
	end
	for _, p in record.players do
		if p.key == oppKeys[1] then
			opp = p
		end
	end
	opp = opp or opponentOf(record, myKey)
	if not opp then
		return nil
	end
	local o = opp :: ArenaQueue.MatchPlayer
	local mine: ArenaQueue.MatchPlayer? = nil
	for _, p in record.players do
		if p.key == myKey then
			mine = p
		end
	end
	local state = need().state(player)
	local day = Time.dayNumber(Clock.now())
	local mode = Arena.mode(record.mode)
	local field = if mode then mode.vsField else "vs"
	local team = mode ~= nil and mode.teamSize > 1
	local unrated, vs = false, 0
	if state then
		local against: { string } = if #oppKeys > 0 then oppKeys else { o.key }
		for _, key in against do
			if not ArenaRules.isRated(state, key, day, field) then
				unrated = true
			end
			vs = math.max(vs, ArenaRules.vsCount(state, key, day, field))
		end
	end
	return {
		id = record.id,
		expiresAt = record.acceptBy,
		accepted = mine ~= nil and mine.ok == true,
		mode = record.mode,
		unrated = unrated,
		vs = vs,
		opp = { name = o.name, class = o.class, level = o.level, rating = o.rating },
		scope = "global",
		combat = need().inCombat(player),
		mine = if team then mineNames else nil,
		them = if team then themNames else nil,
	}
end

local function onOffer(st: Local, record: ArenaQueue.MatchRecord)
	local players = playersOf(st)
	if next(players) == nil then
		return
	end
	local first = st.state ~= "offer"
	st.state = "offer"
	st.match = record.id
	st.record = record
	if first then
		st.combat = false
	end
	for key, player in players do
		if first then
			need().offered(player)
		end
		need().setLive(player, "offer", offerView(record, player, key))
	end
end

local function backToQueue(st: Local, _player: Player, toastKey: string?)
	local old = st.match
	st.state = "wait"
	st.match = nil
	st.record = nil
	st.waitingLocal = nil
	local players = playersOf(st)
	for _, p in players do
		need().setLive(p, "offer", nil)
	end
	task.spawn(function()
		local ok
		if old then
			-- give back the claim of that match only (a newer claim of this entry means a new offer is coming)
			local entry = ArenaQueue.newEntry(st.ticket, JOB)
			ok = st.backend.update(mapOf(st.ticket), st.key, ArenaQueue.release(old, entry), NET.entryTtl)
			st.refreshedAt = now()
		else
			ok = put(st)
		end
		if not ok and entries[st.key] == st then
			-- the store refused: out of the global queue (the player may join again, the local queue takes it)
			forget(st, false)
			for _, p in players do
				need().dropped(p)
				need().toast(p, "arena.net.offline", nil, "warning")
			end
			return
		end
		if entries[st.key] == st then
			for _, p in players do
				need().requeued(p, st.ticket)
			end
		end
	end)
	if toastKey then
		for _, p in players do
			need().toast(p, toastKey, nil, "info")
		end
	end
end

-- S128: the whole entry out of the queue for good (every member's offer card closed).
local function dropAll(st: Local)
	for _, p in playersOf(st) do
		need().setLive(p, "offer", nil)
		need().dropped(p)
	end
	forget(st, true)
end

local function onGo(st: Local, record: ArenaQueue.MatchRecord)
	if st.state == "go" then
		return
	end
	local players = playersOf(st)
	if next(players) == nil or not record.code then
		return
	end
	st.state = "go"
	st.record = record
	for _, p in players do
		need().setLive(p, "offer", nil)
	end
	forget(st, true)
	entries[st.key] = st -- kept while the teleport runs (leave() knows it is no refusal)
	track(st)
	local host = Matchmaker.host
	if host then
		host:start(record.spec, players)
	end
end

-- Acts on a record read for a local entry (a message, a poll, an own write).
local function apply(st: Local, record: any?)
	local player = playerOf(st)
	if not player then
		return
	end
	local t = now()
	if record == nil then
		if st.state == "offer" and st.record and t > st.record.acceptBy + NET.acceptGrace then
			backToQueue(st, player, "arena.cancelled")
		end
		return
	end
	local r = record :: ArenaQueue.MatchRecord
	local member = false
	for _, p in (if type(r.players) == "table" then r.players else {}) :: { ArenaQueue.MatchPlayer } do
		if p.key == st.key or p.entry == st.key then
			member = true
		end
	end
	if not member then
		return
	end
	local after: ArenaQueue.After, guilty: { string }? = ArenaQueue.entryAfter(r, st.key, nil, t), nil
	if st.members then
		-- S128: a party team: one member's refusal takes the team out, the penalty only for the members who refused
		-- or did not answer
		after, guilty = ArenaQueue.entryAfterTeam(r, st.key, st.members, t)
		if after == "penalty" and st.state == "offer" then
			local players = playersOf(st)
			local penalized = guilty or {}
			dropAll(st)
			local name = "?"
			for _, p in r.players do
				if p.key == penalized[1] then
					name = p.name
				end
			end
			for key, p in players do
				if table.find(penalized, key) then
					if r.reason == "timeout" and (st.combat or need().inCombat(p)) then
						need().toast(p, "arena.net.cancelled.combat", nil, "warning")
					else
						penalize(key)
						need().toast(p, "arena.penalty", { time = Time.format(Arena.QUEUE.declinePenalty) }, "warning")
					end
				else
					need().toast(p, "arena.queue3.teamLeft", { name = name }, "warning")
				end
			end
			return
		end
	end
	if after == "wait" then
		if r.state == "offered" then
			onOffer(st, r)
		end
	elseif after == "teleport" then
		onGo(st, r)
	elseif after == "requeue" or (after == "penalty" and st.state == "wait") then
		if st.state == "wait" then
			-- an offer this server never showed (its message was lost and it ended): free the entry, no penalty
			local entry = ArenaQueue.newEntry(st.ticket, JOB)
			task.spawn(st.backend.update, mapOf(st.ticket), st.key, ArenaQueue.release(r.id, entry), NET.entryTtl)
		elseif st.state == "offer" then
			-- the entry of whoever refused is avoided for a while (S128: the team entry of a member)
			if r.by and r.by ~= st.key then
				local byEntry = r.by
				for _, p in r.players do
					if p.key == r.by and p.entry then
						byEntry = p.entry
					end
				end
				addAvoid(st.key, byEntry)
			end
			local key = if r.reason == "declined"
					or r.reason == "timeout"
					or r.reason == "left"
				then "arena.oppDeclined"
				else "arena.cancelled"
			backToQueue(st, player, key)
		end
	elseif after == "penalty" then
		if st.state == "offer" then
			need().setLive(player, "offer", nil)
			forget(st, true)
			need().dropped(player)
			if r.reason == "timeout" and (st.combat or need().inCombat(player)) then
				-- no answer during a fight: no penalty, out of the queue (DECYZJE S127)
				need().toast(player, "arena.net.cancelled.combat", nil, "warning")
			else
				penalize(st.key)
				need().toast(player, "arena.penalty", { time = Time.format(Arena.QUEUE.declinePenalty) }, "warning")
			end
		end
	else -- remove
		if st.state ~= "go" then
			dropAll(st) -- S128: every member of a party team
		end
	end
end

local function readRecord(st: Local, id: string): (boolean, any?)
	return st.backend.hget(NET.matchMap, ArenaQueue.matchKey(id))
end

local function announce(backend: ArenaQueue.Backend, kind: string?, record: any?)
	if (kind == "accepted" or kind == "cancelled") and type(record) == "table" and backend == live then
		local jobs = {}
		for _, p in record.players do
			table.insert(jobs, p.jobId)
		end
		task.spawn(live.publish, { op = if kind == "accepted" then "go" else "cancel", id = record.id, jobs = jobs })
	end
end

-- The poll ------------------------------------------------------------------------------------------------------------

local function pollWaiting(st: Local, t: number)
	local player = playerOf(st)
	if not player then
		forget(st, true)
		return
	end
	-- 1. the refresh (renews the ttl; a level-up into another bracket moves the entry with its old joinedAt; S128: a
	-- party team keeps the ratings of its ticket)
	if t - st.refreshedAt >= NET.refreshEvery then
		local info = if st.members then nil else need().refreshInfo(player, st.ticket.mode)
		if info then
			local e = st.ticket.entrant
			e.rating, e.level, e.name = info.rating, info.level, info.name
			local bracket = ArenaRules.bracketOf(info.level)
			if bracket and bracket ~= st.ticket.bracket then
				local old = mapOf(st.ticket)
				st.ticket.bracket = bracket
				task.spawn(function()
					st.backend.remove(old, st.key)
				end)
				if put(st) then
					need().requeued(player, st.ticket)
				else
					forget(st, false)
					need().dropped(player)
					need().toast(player, "arena.net.left", { reason = "@arena.net.reason.bracket" }, "warning")
				end
				return
			end
		end
		local value = {
			rating = st.ticket.entrant.rating,
			level = st.ticket.entrant.level,
			name = st.ticket.entrant.name,
		}
		local ok, stored = st.backend.update(mapOf(st.ticket), st.key, ArenaQueue.refresh(JOB, value, t), NET.entryTtl)
		st.refreshedAt = t
		if ok and (stored == nil or (type(stored) == "table" and stored.jobId ~= JOB)) then
			put(st) -- the entry vanished (ttl, removed) or another server wrote it: back with its old joinedAt
		end
	end
	if st.state ~= "wait" or entries[st.key] ~= st then
		return
	end
	-- 2. the pairing; the range read also shows this entry: a claim by another organizer means an offer whose message
	-- may be lost, so its record is read now
	local me = ArenaQueue.newEntry(st.ticket, JOB)
	local seenSelf: any? = nil
	local waited = t - st.ticket.joinedAt
	local window = ArenaRules.window(waited)
	local waitingLocal = scopeOf(st.backend) == "global" and waited >= NET.globalWait
	if st.window ~= window or st.waitingLocal ~= waitingLocal then
		st.window = window
		st.waitingLocal = waitingLocal
		need().publish(player)
	end
	local mode = Arena.mode(st.ticket.mode)
	local teams = mode ~= nil and mode.teamSize > 1
	-- S128: 3v3 forms teams
	local try: typeof(ArenaQueue.tryPair) = if teams then ArenaQueue.tryTeams else ArenaQueue.tryPair
	local status, result = try(
		st.backend,
		me,
		NET,
		t,
		function()
			return HttpService:GenerateGUID(false)
		end,
		JOB,
		{
			avoid = avoidOf(st.key),
			self = function(entry: ArenaQueue.Entry)
				seenSelf = entry
			end,
		}
	)
	if status ~= "paired" and status ~= "local" and type(seenSelf) == "table" then
		local own = seenSelf :: ArenaQueue.Entry
		if own.state == "claimed" and own.match and own.jobId == JOB then
			local okRec, record = readRecord(st, own.match)
			if okRec and type(record) == "table" then
				apply(st, record)
				return
			end
		end
	end
	if status == "none" and waitingLocal then
		-- F1: somebody of this server waits in the same bracket outside the window: the local offer
		local locals: { ArenaQueue.Entry } = {}
		for key, other in entries do
			if
				key ~= st.key
				and other.state == "wait"
				and other.backend == st.backend
				and other.ticket.mode == st.ticket.mode
				and other.ticket.bracket == st.ticket.bracket
			then
				table.insert(locals, ArenaQueue.newEntry(other.ticket, JOB))
			end
		end
		if ArenaQueue.localOffer(waited, NET.globalWait, #locals > 0) then
			status, result = try(st.backend, me, NET, t, function()
				return HttpService:GenerateGUID(false)
			end, JOB, { avoid = avoidOf(st.key), fallback = true, locals = locals })
		end
	end
	if status == "paired" then
		onOffer(st, result :: ArenaQueue.MatchRecord)
	elseif status == "local" then
		local pairing = result :: ArenaRules.Pairing
		local keys = {}
		for _, side in pairing.sides do
			for _, ticket in side do
				table.insert(keys, ticket.entrant.key)
			end
		end
		for _, key in keys do
			local other = entryOf(key)
			if other then
				forget(other, false)
			end
		end
		if #keys == 2 then
			partnerOf[keys[1]] = keys[2]
			partnerOf[keys[2]] = keys[1]
		end
		table.insert(ready, pairing)
	end
end

local function pollOffer(st: Local, t: number)
	local player = playerOf(st)
	if not player then
		return
	end
	local record = st.record
	if not record or not st.match then
		return
	end
	if need().inCombat(player) then
		st.combat = true
	end
	local key = ArenaQueue.matchKey(st.match)
	if t > record.acceptBy then
		local ok, after, before = st.backend.hupdate(NET.matchMap, key, ArenaQueue.expire(t, NET), NET.matchTtl)
		if ok then
			announce(st.backend, ArenaQueue.changed(before, after), after)
			apply(st, after)
		elseif t > record.acceptBy + NET.acceptGrace then
			apply(st, nil)
		end
		return
	end
	local ok, value = readRecord(st, st.match)
	if ok then
		apply(st, value)
	end
end

-- Moves waiting entries to the backend used now (MemoryStore came back, or went away).
local function migrate()
	local target = current()
	for _, st in table.clone(entries) do
		if st.state == "wait" and st.backend ~= target then
			local old = st.backend
			st.backend = target
			task.spawn(function()
				old.remove(mapOf(st.ticket), st.key)
			end)
			put(st)
			local player = playerOf(st)
			if player then
				if target == fake then
					need().toast(player, "arena.net.offline", nil, "warning")
				end
				need().publish(player)
			end
		end
	end
end

local function poll()
	local t = now()
	migrate()
	for _, st in table.clone(entries) do
		if entries[st.key] ~= st then
			continue
		end
		local ok, err = pcall(function()
			if st.state == "wait" then
				pollWaiting(st, t)
			elseif st.state == "offer" then
				pollOffer(st, t)
			end
		end)
		if not ok then
			log:error("poll of %s failed: %s", st.key, tostring(err))
		end
	end
end

local function onMessage(data: any)
	local message = ArenaQueue.parseMessage(data)
	if not message then
		return
	end
	if message.jobs and not table.find(message.jobs, JOB) then
		return
	end
	for _, st in table.clone(entries) do
		if st.backend == live and (st.match == message.id or (message.op == "offer" and st.state == "wait")) then
			task.spawn(function()
				local ok, record = readRecord(st, message.id)
				if ok and type(record) == "table" then
					local mine = false
					for _, p in record.players do
						if (p.key == st.key or p.entry == st.key) and p.jobId == JOB then
							mine = true
						end
					end
					if mine then
						apply(st, record)
					end
				end
			end)
		end
	end
end

-- The PairSource -------------------------------------------------------------------------------------------------------

local source = {} :: any
source.kind = "global"

-- (false, "arena.error.penalty") under a penalty of any server; (false, nil) when the store failed (ArenaService
-- then tries the local queue).
function source.join(_self: ArenaTypes.PairSource, ticket: ArenaRules.Ticket): (boolean, string?)
	local key = ticket.entrant.key
	local existing = entryOf(key)
	if existing and existing.state ~= "go" then
		return false, "arena.error.queued"
	end
	local backend = current()
	local okPen, untilAt = backend.hget(NET.penaltyMap, key)
	if okPen and type(untilAt) == "number" and untilAt > now() then
		need().penalize(key, untilAt)
		return false, "arena.error.penalty"
	end
	local st: Local = {
		key = key,
		ticket = table.clone(ticket),
		backend = backend,
		state = "wait",
		refreshedAt = now(),
		combat = false,
		members = membersOfTicket(ticket),
	}
	entries[key] = st
	track(st)
	if not put(st) then
		forget(st, false)
		return false, nil
	end
	return true, nil
end

-- Out of the queue. Never yields (CharacterLeaving): the store calls run in a task. Leaving during a global offer
-- answers it with "left" (a penalty: the other player lost the match).
function source.leave(_self: ArenaTypes.PairSource, memberKey: string)
	local st = entryOf(memberKey)
	if not st then
		return
	end
	local key = memberKey -- S128: the refusal is the leaving member's (a team entry is st.key)
	forget(st, false)
	if st.members and st.state == "offer" then
		-- S128: the other members of the party team lose the offer with it
		for k, p in playersOf(st) do
			if k ~= key then
				need().setLive(p, "offer", nil)
				need().dropped(p)
			end
		end
	end
	if st.state == "wait" then
		forget(st, true)
	elseif st.state == "offer" and st.match then
		local match = st.match :: string
		local backend = st.backend
		task.spawn(function()
			local ok, after, before = backend.hupdate(
				NET.matchMap,
				ArenaQueue.matchKey(match),
				ArenaQueue.respond(key, false, now(), "left"),
				NET.matchTtl
			)
			local change = if ok then ArenaQueue.changed(before, after) else nil
			if ok then
				announce(backend, change, after)
			end
			-- the penalty only for the refusal this write made (an offer the opponent had declined already is free;
			-- a store error keeps the penalty, nobody else is left to write it)
			if not ok or (change == "cancelled" and type(after) == "table" and after.by == key) then
				Matchmaker.RecordPenalty(key, now() + Arena.QUEUE.declinePenalty)
			end
		end)
		forget(st, true)
	end
end

function source.has(_self: ArenaTypes.PairSource, key: string): boolean
	local st = entryOf(key)
	return st ~= nil and st.state == "wait"
end

-- A local pair from `take` that did not start (S126 offer refused or cancelled): back with the old joinedAt; the
-- partner of that pair is avoided for the penalty time.
function source.requeue(_self: ArenaTypes.PairSource, ticket: ArenaRules.Ticket)
	local key = ticket.entrant.key
	local partner = partnerOf[key]
	partnerOf[key] = nil
	if partner then
		addAvoid(key, partner)
	end
	if entries[key] then
		return
	end
	local st: Local = {
		key = key,
		ticket = table.clone(ticket),
		backend = current(),
		state = "wait",
		refreshedAt = 0, -- written by the next poll
		combat = false,
		members = membersOfTicket(ticket),
	}
	entries[key] = st
	track(st)
	task.spawn(put, st)
end

function source.take(_self: ArenaTypes.PairSource, _now: number): { ArenaRules.Pairing }
	local out = ready
	ready = {}
	return out
end

function source.waiting(_self: ArenaTypes.PairSource, _mode: string, _bracket: string): number?
	return nil -- unknown across servers: the window shows the rating window instead
end

function source.tickets(_self: ArenaTypes.PairSource): { ArenaRules.Ticket }
	local out = {}
	for _, st in entries do
		if st.state == "wait" then
			table.insert(out, st.ticket)
		end
	end
	return out
end

-- S127: the queue view of a key (merged into arenaLive.queue by ArenaService).
function source.info(_self: ArenaTypes.PairSource, key: string): { [string]: any }?
	local st = entries[key]
	return if st then infoOf(st) else nil
end

-- S127: the scope of new entries ("global" | "local"), for ArenaStatus.
function source.scope(_self: ArenaTypes.PairSource): string
	return ArenaQueue.scope({
		backendOk = current() == live,
		studio = studio,
		offlineUntil = if forced then math.huge else offlineUntil,
		now = now(),
	})
end

-- Public API -----------------------------------------------------------------------------------------------------------

-- The RemoteHost ArenaService registers as hosts["remote"] (SetHost); Matchmaker starts it on "go".
Matchmaker.host = nil :: ArenaTypes.Host?

function Matchmaker.source(): ArenaTypes.PairSource
	return source :: ArenaTypes.PairSource
end

-- The answer to a global offer (ArenaRespond, the offer of scope "global"). ArenaService checked the fight rules.
function Matchmaker.Respond(player: Player, key: string, accept: boolean): (boolean, string?)
	local st = entryOf(key)
	if not st or st.state ~= "offer" or not st.match or not st.record then
		return false, "arena.error.offer"
	end
	if now() > st.record.acceptBy then
		return false, "arena.error.offer"
	end
	local ok, after, before = st.backend.hupdate(
		NET.matchMap,
		ArenaQueue.matchKey(st.match),
		ArenaQueue.respond(key, accept, now()),
		NET.matchTtl
	)
	if not ok then
		return false, "arena.error.offer"
	end
	announce(st.backend, ArenaQueue.changed(before, after), after)
	if type(after) == "table" then
		apply(st, after)
	end
	local _ = player
	return true, nil
end

-- Whether `key` has a global offer now.
function Matchmaker.HasOffer(key: string): boolean
	local st = entryOf(key)
	return st ~= nil and (st.state == "offer" or st.state == "go")
end

-- Writes a penalty into ArenaPenalty (every server reads it at join). Never yields.
function Matchmaker.RecordPenalty(key: string, untilAt: number)
	local backend = current()
	if backend ~= live then
		return -- the in-memory penalty of ArenaService covers this server
	end
	task.spawn(function()
		live.hupdate(NET.penaltyMap, key, function(cur: any?): any?
			return math.max(tonumber(cur) or 0, untilAt)
		end, math.max(1, untilAt - now()))
	end)
end

-- The backend of the arena server (always MemoryStore; the arena server exists only when it works).
function Matchmaker.Backend(): ArenaQueue.Backend
	return if studio then fake else live
end

function Matchmaker.JobId(): string
	return JOB
end

-- Admin /arenanet offline | online.
function Matchmaker.SetOffline(on: boolean)
	forced = on
	if not on then
		offlineUntil = 0
		errors = 0
	end
end

export type Status = {
	backend: string,
	queued: { [string]: number },
	offers: number,
	err: string,
}

function Matchmaker.Status(): Status
	local queued: { [string]: number } = {}
	local offers = 0
	for _, st in entries do
		if st.state == "wait" then
			queued[st.ticket.bracket] = (queued[st.ticket.bracket] or 0) + 1
		else
			offers += 1
		end
	end
	local backend = if studio
		then "fake"
		elseif forced then "fake (offline)"
		elseif now() < offlineUntil then `offline {math.ceil(offlineUntil - now())} s`
		else "memorystore"
	return { backend = backend, queued = queued, offers = offers, err = lastError or "-" }
end

-- Starts the subscription and the poll. `remoteFor` builds the RemoteHost's tickets (code, TeleportData, onFail).
function Matchmaker.Start(d: Deps)
	deps = d
	Matchmaker.host = RemoteHost.new(function(spec: ArenaRules.MatchSpec, player: Player): RemoteHost.Ticket?
		for key, st in entries do
			local mine: string? = nil
			if st.state == "go" and st.record and st.record.id == spec.id then
				for _, k in keysOf(st) do
					if d.playerOfKey(k) == player then
						mine = k
					end
				end
			end
			if mine then
				local record = st.record :: ArenaQueue.MatchRecord
				local slot = st.ticket.entrant.slot
				for _, m in (st.ticket.members or {}) :: { ArenaRules.Entrant } do
					if m.key == mine then
						slot = m.slot
					end
				end
				return {
					code = record.code :: string,
					data = {
						serverMode = "arena",
						arenaMatch = record.id,
						returnJob = JOB,
						slot = slot,
						team = if st.members then true else nil, -- S128: the party is lost on the way
					},
					onFail = function(p: Player, _reason: string)
						-- the teleport failed: the match is off (no penalty), back to the queue with the old place
						task.spawn(function()
							local ok, after, before = live.hupdate(
								NET.matchMap,
								ArenaQueue.matchKey(record.id),
								ArenaQueue.cancel("teleport", mine),
								NET.matchTtl
							)
							if ok then
								announce(live, ArenaQueue.changed(before, after), after)
							end
						end)
						if p.Parent then
							st.state = "offer" -- backToQueue resets it to "wait"
							entries[key] = st
							backToQueue(st, p, "arena.net.teleportFailed")
						end
					end,
				}
			end
		end
		return nil
	end)
	if not studio then
		task.spawn(function()
			-- MessagingService:SubscribeAsync(topic, callback(packet)): packet.Data is the published table
			local ok, err = pcall(function()
				MessagingService:SubscribeAsync(NET.topic, function(packet: any)
					local data = if type(packet) == "table" then packet.Data else nil
					onMessage(data)
				end)
			end)
			if not ok then
				log:warn(
					"ArenaMatch topic unavailable (%s): the servers read the records when they poll",
					tostring(err)
				)
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(rng:float(NET.pollMin, NET.pollMax))
			local ok, err = pcall(function()
				poll()
			end)
			if not ok then
				log:error("arena queue poll failed: %s", tostring(err))
			end
		end
	end)
end

return Matchmaker
