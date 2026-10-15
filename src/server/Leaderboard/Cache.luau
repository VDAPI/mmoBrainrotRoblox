--!strict
-- What this server knows of the leaderboards (S124, DESIGN-17 §5): the top (Config.Leaderboard.top) of every board
-- instance and the metadata of its entry keys, read lazily. One board is read at most every Config.Leaderboard.refresh
-- seconds per server (DESIGN-17 §0.4); missing metadata at most metaReadsPerRefresh keys per read and only while the
-- GetAsync budget is above budgetFloor (the rest waits for the next read, rows without metadata show no name). Reads
-- run in their own thread; nothing here blocks a caller except Cache.wait (LeaderboardGet, at most firstWait s).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Stores = require(script.Parent.Stores)

type BoardState = {
	entries: { Leaderboard.Entry }?, -- ordered / sorted boards
	list: { Leaderboard.ListEntry }?, -- list boards
	fetchedAt: number?, -- os.time() of the last successful read
	triedAt: number?, -- os.time() of the last attempt (a failed read is retried after Config.Leaderboard.retryFailed)
	fetching: boolean,
	usedAt: number, -- last LeaderboardGet / town board use
}

local Cache = {
	-- (instanceId) after a read or a local change of a board
	Refreshed = Signal.new(),
}

local boards: { [string]: BoardState } = {}
local meta: { [string]: { value: Leaderboard.Meta?, at: number } } = {}

local function state(instanceId: string): BoardState
	local s = boards[instanceId]
	if not s then
		s = { fetching = false, usedAt = 0 }
		boards[instanceId] = s
	end
	return s :: BoardState
end

-- (entries?, list?, fetchedAt?) without waiting.
function Cache.get(instanceId: string): ({ Leaderboard.Entry }?, { Leaderboard.ListEntry }?, number?)
	local s = boards[instanceId]
	if not s then
		return nil, nil, nil
	end
	return s.entries, s.list, s.fetchedAt
end

-- Waits for the first read of a board, at most `maxWait` s (yields).
function Cache.wait(instanceId: string, maxWait: number)
	local deadline = os.clock() + maxWait
	local s = state(instanceId)
	while s.fetchedAt == nil and s.fetching and os.clock() < deadline do
		task.wait(0.1)
	end
end

function Cache.touch(instanceId: string, now: number)
	state(instanceId).usedAt = now
end

-- Instance ids used since `since` (os.time).
function Cache.usedSince(since: number): { string }
	local out = {}
	for id, s in boards do
		if s.usedAt >= since then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

function Cache.metaOf(key: string): Leaderboard.Meta?
	local m = meta[key]
	return if m then m.value else nil
end

function Cache.putMeta(key: string, value: Leaderboard.Meta?)
	meta[key] = { value = value, at = os.time() }
end

local function readMeta(entries: { Leaderboard.Entry }, now: number)
	local cfg = Config.Leaderboard
	local reads = 0
	for _, e in entries do
		if e.value ~= nil and type(e.value) == "table" then
			-- sorted boards carry the meta in the value
			meta[e.key] = { value = e.value, at = now }
			continue
		end
		local known = meta[e.key]
		if known and now - known.at < cfg.metaTtl then
			continue
		end
		if reads >= cfg.metaReadsPerRefresh then
			break
		end
		if Stores.budget(Enum.DataStoreRequestType.GetAsync) < cfg.budgetFloor then
			break
		end
		reads += 1
		local ok, value = Stores.meta:get(e.key)
		if ok then
			meta[e.key] = { value = if type(value) == "table" then value else nil, at = now }
		end
	end
end

local function fetch(def: Leaderboard.BoardDef, instanceId: string)
	local s = state(instanceId)
	local now = os.time()
	s.triedAt = now
	if def.kind == "list" then
		local ok, value = Stores.lists:get(instanceId)
		if ok then
			s.list = if type(value) == "table" and type(value.entries) == "table" then value.entries else {}
			s.fetchedAt = now
		end
	else
		local board = Stores.board(def.kind, instanceId, def.ttl)
		local ok, entries = board.top(Config.Leaderboard.top)
		if ok then
			s.entries = entries
			-- the names first: a first snapshot stays `loading` until they are read (no row of unknown heroes)
			readMeta(entries, now)
			s.fetchedAt = now
		end
	end
end

-- Reads the board again when its last read is older than Config.Leaderboard.refresh (or always with `force`, only from
-- /lb refresh, which has its own limit). Returns at once; Cache.Refreshed fires after the read.
function Cache.refresh(def: Leaderboard.BoardDef, instanceId: string, force: boolean?)
	local s = state(instanceId)
	if s.fetching then
		return
	end
	local now = os.time()
	if not force then
		if s.fetchedAt and now - s.fetchedAt < Config.Leaderboard.refresh then
			return
		end
		if s.fetchedAt == nil and s.triedAt and now - s.triedAt < Config.Leaderboard.retryFailed then
			return
		end
		if
			s.fetchedAt
			and s.triedAt
			and s.triedAt > s.fetchedAt
			and now - s.triedAt < Config.Leaderboard.retryFailed
		then
			return
		end
	end
	s.fetching = true
	task.spawn(function()
		local ok, err = pcall(function()
			fetch(def, instanceId)
		end)
		s.fetching = false
		if not ok then
			Stores.warnOnce("leaderboard read", err)
		end
		Cache.Refreshed:Fire(instanceId)
	end)
end

-- After an own write: the server shows its own score at once (Leaderboard.mergeLocal).
function Cache.mergeLocal(instanceId: string, key: string, score: number?)
	local s = boards[instanceId]
	if not s or not s.entries then
		return
	end
	s.entries = Leaderboard.mergeLocal(s.entries :: { Leaderboard.Entry }, key, score, Config.Leaderboard.top)
	Cache.Refreshed:Fire(instanceId)
end

-- After an own list write (Hall of Fame): the list as written.
function Cache.setList(instanceId: string, list: { Leaderboard.ListEntry })
	local s = state(instanceId)
	s.list = list
	s.fetchedAt = s.fetchedAt or os.time()
	Cache.Refreshed:Fire(instanceId)
end

-- For /lb info: (boards cached, { { id, age, n } }).
function Cache.stats(now: number): { { id: string, age: number?, n: number } }
	local out = {}
	for id, s in boards do
		local n = if s.entries then #(s.entries :: { any }) elseif s.list then #(s.list :: { any }) else 0
		table.insert(out, { id = id, age = if s.fetchedAt then now - s.fetchedAt else nil, n = n })
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

return Cache
