--!strict
-- OrderedDataStore / MemoryStore / DataStore access for leaderboards (S124, DESIGN-17 §0.4 and §5) with retries
-- (Market/Retry) and an in-memory fallback (Logic/Leaderboard.memoryBoard): without DataStore access (Studio without
-- "Enable Studio Access to API Services") every board, the metadata and the lists live on this server only ("this
-- server only" in the Rankings window); MemoryStore is probed once per server (wzór Market/Index). Every call may yield; callers run them on the
-- LeaderboardService worker, never in Init or a game loop.
--   ordered  OrderedDataStore Config.Leaderboard.orderedPrefix .. instance id: key -> whole-number score
--   sorted   MemoryStore SortedMap Config.Leaderboard.sortedPrefix .. instance id: key -> { s = score, m = meta? },
--            sort key = the score, entries expire after the board's ttl. API used (MemoryStoreSortedMap with sort
--            keys, 2023): SetAsync(key, value, expiration, sortKey), UpdateAsync(key, fn(value, sortKey) -> (value,
--            sortKey), expiration), GetRangeAsync(direction, count) -> { { key, value, sortKey } }.
--   meta     DataStore Config.Leaderboard.metaStore (KeyStore): entry key -> Logic/Leaderboard.Meta
--   lists    DataStore Config.Leaderboard.listStore (KeyStore): list instance id -> { entries = { ListEntry } }

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local KeyStore = require(script.Parent.Parent.Market.KeyStore)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Log = require(Shared.Util.Log)
local Retry = require(script.Parent.Parent.Market.Retry)

local log = Log.new("LeaderboardStores")

local MAX_EXPIRATION = 3888000 -- 45 days, the MemoryStore limit
local ORDERED_PAGE = 100 -- GetSortedAsync page size limit
local SORTED_PAGE = 200 -- GetRangeAsync count limit

export type Board = {
	-- (ok) sets the score (and the meta of a sorted board)
	set: (key: string, score: number, meta: Leaderboard.Meta?) -> boolean,
	-- (ok) adds to the score of a sorted board (UpdateAsync); ordered boards refuse
	add: (key: string, delta: number, meta: Leaderboard.Meta?) -> boolean,
	remove: (key: string) -> boolean,
	-- (ok, entries best first; a sorted entry's value is its meta)
	top: (n: number) -> (boolean, { Leaderboard.Entry }),
	isMock: () -> boolean,
}

local Stores = {}

local hasAccess: () -> boolean = function()
	return false
end
local sortedMock: boolean? = nil
local ordered: { [string]: Board } = {}
local sorted: { [string]: Board } = {}
local warned: { [string]: boolean } = {}

Stores.meta = (nil :: any) :: KeyStore.KeyStore
Stores.lists = (nil :: any) :: KeyStore.KeyStore

-- One warning per kind of failure, never a flood (wzór Guild/Bus).
function Stores.warnOnce(what: string, err: any)
	if not warned[what] then
		warned[what] = true
		log:warn("%s failed (%s); leaderboards keep running with what this server has", what, tostring(err))
	end
end

function Stores.init(hasDataStoreAccess: () -> boolean)
	hasAccess = hasDataStoreAccess
	Stores.meta = KeyStore.new(Config.Leaderboard.metaStore, hasDataStoreAccess)
	Stores.lists = KeyStore.new(Config.Leaderboard.listStore, hasDataStoreAccess)
end

-- The DataStore budget of a request type (0 when unknown); in-memory mode has no budget to save.
function Stores.budget(requestType: Enum.DataStoreRequestType): number
	if not hasAccess() then
		return math.huge
	end
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(requestType)
	end)
	return if ok and type(budget) == "number" then budget else 0
end

local function memoryBoardOf(ttl: number?): Board
	local memory = Leaderboard.memoryBoard()
	local board = {}
	function board.set(key: string, score: number, meta: Leaderboard.Meta?): boolean
		memory.set(key, math.floor(score), meta, if ttl then os.time() + ttl else nil)
		return true
	end
	function board.add(key: string, delta: number, meta: Leaderboard.Meta?): boolean
		if not ttl then
			error("Stores: add on an ordered board")
		end
		local now = os.time()
		memory.update(key, function(old)
			return (if old then old.score else 0) + delta, meta or (old and old.value)
		end, now + (ttl :: number), now)
		return true
	end
	function board.remove(key: string): boolean
		memory.remove(key)
		return true
	end
	function board.top(n: number): (boolean, { Leaderboard.Entry })
		return true, memory.top(n, os.time())
	end
	function board.isMock(): boolean
		return true
	end
	return board :: Board
end

-- Picks the in-memory board or the real one on every call (like KeyStore: the DataStore state is known only once
-- ProfileStore checked it, so the choice is never frozen too early).
local function switching(mock: Board, live: Board, useMock: () -> boolean): Board
	local board = {}
	function board.set(key: string, score: number, meta: Leaderboard.Meta?): boolean
		return (if useMock() then mock else live).set(key, score, meta)
	end
	function board.add(key: string, delta: number, meta: Leaderboard.Meta?): boolean
		return (if useMock() then mock else live).add(key, delta, meta)
	end
	function board.remove(key: string): boolean
		return (if useMock() then mock else live).remove(key)
	end
	function board.top(n: number): (boolean, { Leaderboard.Entry })
		return (if useMock() then mock else live).top(n)
	end
	function board.isMock(): boolean
		return useMock()
	end
	return board :: Board
end

local function orderedLive(instanceId: string): Board
	local name = Config.Leaderboard.orderedPrefix .. instanceId
	local store: OrderedDataStore? = nil
	local function real(): OrderedDataStore
		if not store then
			store = DataStoreService:GetOrderedDataStore(name)
		end
		return store :: OrderedDataStore
	end
	local live = {}
	function live.set(key: string, score: number, _meta: Leaderboard.Meta?): boolean
		Retry.waitBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync)
		local ok, err = Retry.call(`{name}.Set`, function()
			real():SetAsync(key, math.floor(score))
		end)
		if not ok then
			Stores.warnOnce("OrderedDataStore.SetAsync", err)
		end
		return ok
	end
	function live.add(_key: string, _delta: number, _meta: Leaderboard.Meta?): boolean
		error("Stores: add on an ordered board")
	end
	function live.remove(key: string): boolean
		Retry.waitBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync)
		local ok, err = Retry.call(`{name}.Remove`, function()
			real():RemoveAsync(key)
		end)
		if not ok then
			Stores.warnOnce("OrderedDataStore.RemoveAsync", err)
		end
		return ok
	end
	function live.top(n: number): (boolean, { Leaderboard.Entry })
		Retry.waitBudget(Enum.DataStoreRequestType.GetSortedAsync)
		local ok, result = Retry.call(`{name}.Top`, function()
			local pages = real():GetSortedAsync(false, math.clamp(math.floor(n), 1, ORDERED_PAGE))
			return pages:GetCurrentPage()
		end)
		if not ok then
			Stores.warnOnce("OrderedDataStore.GetSortedAsync", result)
			return false, {}
		end
		local out: { Leaderboard.Entry } = {}
		for _, item in result :: { any } do
			if type(item.key) == "string" and type(item.value) == "number" then
				table.insert(out, { key = item.key, score = item.value })
			end
		end
		return true, out
	end
	function live.isMock(): boolean
		return false
	end
	return live :: Board
end

-- A permanent board (OrderedDataStore), created on first use.
function Stores.ordered(instanceId: string): Board
	local existing = ordered[instanceId]
	if existing then
		return existing
	end
	local board = switching(memoryBoardOf(nil), orderedLive(instanceId), function()
		return not hasAccess()
	end)
	ordered[instanceId] = board
	return board
end

local function sortedMap(name: string): any
	return MemoryStoreService:GetSortedMap(name)
end

-- Decides once whether MemoryStore works here (wzór Market/Index.useMock); without DataStore access everything stays
-- in memory and nothing is decided yet.
local function useSortedMock(): boolean
	if not hasAccess() then
		return true
	end
	if sortedMock == nil then
		local ok, err = pcall(function()
			sortedMap(Config.Leaderboard.sortedPrefix .. "probe"):GetRangeAsync(Enum.SortDirection.Descending, 1)
		end)
		sortedMock = not ok
		if not ok then
			log:warn("MemoryStore unavailable (%s): periodic leaderboards live on this server only", tostring(err))
		end
	end
	return sortedMock == true
end

local function sortedLive(instanceId: string, ttl: number): Board
	local name = Config.Leaderboard.sortedPrefix .. instanceId
	local expiration = math.clamp(math.floor(ttl), 60, MAX_EXPIRATION)
	local map: any = nil
	local function real(): any
		if not map then
			map = sortedMap(name)
		end
		return map
	end
	local live = {}
	function live.set(key: string, score: number, meta: Leaderboard.Meta?): boolean
		local s = math.floor(score)
		local ok, err = Retry.call(`{name}.Set`, function()
			real():SetAsync(key, { s = s, m = meta }, expiration, s)
		end)
		if not ok then
			Stores.warnOnce("SortedMap.SetAsync", err)
		end
		return ok
	end
	function live.add(key: string, delta: number, meta: Leaderboard.Meta?): boolean
		local ok, err = Retry.call(`{name}.Add`, function()
			real():UpdateAsync(key, function(old: any, _sortKey: any)
				local before = if type(old) == "table" and type(old.s) == "number" then old.s else 0
				local s = math.floor(before + delta)
				return { s = s, m = meta or (if type(old) == "table" then old.m else nil) }, s
			end, expiration)
		end)
		if not ok then
			Stores.warnOnce("SortedMap.UpdateAsync", err)
		end
		return ok
	end
	function live.remove(key: string): boolean
		local ok, err = Retry.call(`{name}.Remove`, function()
			real():RemoveAsync(key)
		end)
		if not ok then
			Stores.warnOnce("SortedMap.RemoveAsync", err)
		end
		return ok
	end
	function live.top(n: number): (boolean, { Leaderboard.Entry })
		local ok, result = Retry.call(`{name}.Top`, function()
			return real():GetRangeAsync(Enum.SortDirection.Descending, math.clamp(math.floor(n), 1, SORTED_PAGE))
		end)
		if not ok then
			Stores.warnOnce("SortedMap.GetRangeAsync", result)
			return false, {}
		end
		local out: { Leaderboard.Entry } = {}
		for _, item in result :: { any } do
			local value = item.value
			if type(item.key) == "string" and type(value) == "table" and type(value.s) == "number" then
				table.insert(out, { key = item.key, score = value.s, value = value.m })
			end
		end
		table.sort(out, Leaderboard.better)
		return true, out
	end
	function live.isMock(): boolean
		return false
	end
	return live :: Board
end

-- A periodic board (MemoryStore SortedMap, entries live `ttl` s), created on first use. S124 has none; S125 exp_week,
-- S129 bloodmoon.
function Stores.sorted(instanceId: string, ttl: number): Board
	local existing = sorted[instanceId]
	if existing then
		return existing
	end
	local board = switching(memoryBoardOf(ttl), sortedLive(instanceId, ttl), useSortedMock)
	sorted[instanceId] = board
	return board
end

-- The board of a definition kind ("ordered" | "sorted"); lists go through Stores.lists.
function Stores.board(kind: string, instanceId: string, ttl: number?): Board
	if kind == "sorted" then
		return Stores.sorted(instanceId, ttl or MAX_EXPIRATION)
	end
	return Stores.ordered(instanceId)
end

-- "local" while any layer the leaderboards use runs in memory (S124: no DataStore access).
function Stores.mode(kind: string?): "global" | "local"
	if not hasAccess() then
		return "local"
	end
	if kind == "sorted" and useSortedMock() then
		return "local"
	end
	return "global"
end

return Stores
