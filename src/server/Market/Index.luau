--!strict
-- Auction search index (ARCHITECTURE §5): one MemoryStore SortedMap per category ("AuctionIndex_<cat>"),
-- keys from Logic/Auction.indexKey (sorted by price), values = Auction.Summary. Plus the price history
-- (HashMap "AuctionHistory": item id -> last unit prices). When MemoryStore fails on first use the server
-- switches to in-memory tables for the session (Studio without API access).

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Auction = require(ReplicatedStorage.Shared.Logic.Auction)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Retry = require(script.Parent.Retry)

local log = Log.new("AuctionIndex")

local Index = {}

local MAX_EXPIRATION = 3888000 -- 45 days, the MemoryStore limit
local PAGE = 200

local mock: boolean? = nil
local mockMaps: { [string]: { [string]: any } } = {}
local mockHistory: { [string]: { number } } = {}
local maps: { [string]: MemoryStoreSortedMap } = {}
local historyMap: MemoryStoreHashMap? = nil

local function map(category: string): MemoryStoreSortedMap
	local m = maps[category]
	if not m then
		m = MemoryStoreService:GetSortedMap(`AuctionIndex_{category}`)
		maps[category] = m
	end
	return m :: MemoryStoreSortedMap
end

-- Decides once whether MemoryStore works here.
local function useMock(): boolean
	if mock == nil then
		local ok, err = pcall(function()
			map("weapon"):GetRangeAsync(Enum.SortDirection.Ascending, 1)
		end)
		mock = not ok
		if not ok then
			log:warn("MemoryStore unavailable (%s): the auction index lives on this server only", tostring(err))
		end
	end
	return mock == true
end

function Index.isMock(): boolean
	return useMock()
end

function Index.set(category: string, key: string, summary: Auction.Summary, seconds: number): boolean
	if useMock() then
		mockMaps[category] = mockMaps[category] or {}
		mockMaps[category][key] = table.clone(summary)
		return true
	end
	local ok = Retry.call(`index set {key}`, function()
		map(category):SetAsync(key, summary, math.clamp(math.floor(seconds), 60, MAX_EXPIRATION))
	end)
	return ok
end

function Index.remove(category: string, key: string)
	if useMock() then
		if mockMaps[category] then
			mockMaps[category][key] = nil
		end
		return
	end
	Retry.call(`index remove {key}`, function()
		map(category):RemoveAsync(key)
	end)
end

-- Up to `limit` entries sorted by price. Returns (ok, { { key, value } }).
function Index.range(category: string, descending: boolean, limit: number): (boolean, { { key: string, value: any } })
	if useMock() then
		local list = {}
		local entries = mockMaps[category]
		if entries then
			for key, value in entries do
				table.insert(list, { key = key, value = value })
			end
		end
		table.sort(list, function(a, b)
			return if descending then a.key > b.key else a.key < b.key
		end)
		while #list > limit do
			table.remove(list)
		end
		return true, list
	end
	local result: { { key: string, value: any } } = {}
	local direction = if descending then Enum.SortDirection.Descending else Enum.SortDirection.Ascending
	local bound: string? = nil
	while #result < limit do
		local count = math.min(PAGE, limit - #result)
		local ok, page = Retry.call(`index range {category}`, function()
			if descending then
				return map(category):GetRangeAsync(direction, count, nil, bound)
			end
			return map(category):GetRangeAsync(direction, count, bound, nil)
		end)
		if not ok then
			return #result > 0, result
		end
		for _, entry in page do
			table.insert(result, { key = entry.key, value = entry.value })
		end
		if #page < count then
			break
		end
		bound = page[#page].key
	end
	return true, result
end

-- Price history ------------------------------------------------------------------------------------

local function history(): MemoryStoreHashMap
	if not historyMap then
		historyMap = MemoryStoreService:GetHashMap("AuctionHistory")
	end
	return historyMap :: MemoryStoreHashMap
end

function Index.pushHistory(itemId: string, unitPrice: number)
	if useMock() then
		mockHistory[itemId] = Auction.pushHistory(mockHistory[itemId], unitPrice)
		return
	end
	Retry.call(`history {itemId}`, function()
		history():UpdateAsync(itemId, function(current: any)
			return Auction.pushHistory(if type(current) == "table" then current else nil, unitPrice)
		end, MAX_EXPIRATION)
	end)
end

function Index.history(itemId: string): { number }?
	if useMock() then
		return mockHistory[itemId]
	end
	local ok, value = Retry.call(`history get {itemId}`, function()
		return history():GetAsync(itemId)
	end)
	return if ok and type(value) == "table" then value else nil
end

return Index
