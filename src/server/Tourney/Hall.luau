--!strict
-- The Champion's Tournament Hall of Fame (S130, DESIGN-17 §8): the last Data/Arena.TOURNEY.hallWeeks champions of
-- every bracket, newest first, in the DataStore Config.Tourney.hallStore under the key "champions"
-- ({ [bracket] = { { id, name, class, userId, guild? } } }). Market/KeyStore keeps it in memory without DataStore
-- access (Studio: the mock, this server only); every DataStore call goes through KeyStore (Retry.call, pcall). `add` is
-- idempotent: a tournament id already in a bracket's list is not added again. The city board and the statues
-- (TourneyService -> parts tagged "TourneyFameBoard" / "TourneyFamePlinth") and the arena window read `read()`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local KeyStore = require(script.Parent.Parent.Market.KeyStore)

export type Entry = { id: string, name: string, class: string, userId: number, guild: string? }
export type Champions = { [string]: { Entry } }

local KEY = "champions"

local Hall = {}

local store: KeyStore.KeyStore? = nil
local cache: Champions? = nil
local cachedAt = -math.huge

-- TourneyService.Init hands in the DataStore access check (DataService.HasDataStoreAccess).
function Hall.init(hasAccess: () -> boolean)
	store = KeyStore.new(Config.Tourney.hallStore, hasAccess)
end

local function need(): KeyStore.KeyStore
	local s = store
	if not s then
		error("Tourney/Hall: init first")
	end
	return s
end

-- A clean copy of a stored value (unknown brackets and malformed rows dropped).
local function clean(value: any): Champions
	local out: Champions = {}
	if type(value) ~= "table" then
		return out
	end
	for _, b in Arena.BRACKETS do
		local list = value[b.id]
		local rows: { Entry } = {}
		if type(list) == "table" then
			for _, row in list do
				if type(row) == "table" and type(row.id) == "string" and type(row.name) == "string" then
					table.insert(rows, {
						id = row.id,
						name = row.name,
						class = if type(row.class) == "string" then row.class else "warrior",
						userId = tonumber(row.userId) or 0,
						guild = if type(row.guild) == "string" then row.guild else nil,
					})
				end
			end
		end
		out[b.id] = rows
	end
	return out
end

-- The champions (read at most every Config.Tourney.hallRefresh s unless `force`); the last good read when the store
-- fails, an empty table before the first one. Yields.
function Hall.read(now: number, force: boolean?): Champions
	if cache and not force and now - cachedAt < Config.Tourney.hallRefresh then
		return cache
	end
	local ok, value = need():get(KEY)
	cachedAt = now
	if ok then
		cache = clean(value)
	end
	return cache or clean(nil)
end

-- The cached champions without a store read (nil before the first read).
function Hall.peek(): Champions?
	return cache
end

-- Adds a champion of `bracket` (newest first, at most hallWeeks). Yields. True when stored (or already there).
function Hall.add(bracket: string, entry: Entry): boolean
	local ok, stored, err = need():update(KEY, function(current: any?): (any?, string?)
		local all = clean(current)
		local list = all[bracket]
		if list == nil then
			return nil, "unknown"
		end
		for _, row in list do
			if row.id == entry.id then
				return nil, "exists"
			end
		end
		table.insert(list, 1, entry)
		while #list > Arena.TOURNEY.hallWeeks do
			table.remove(list)
		end
		return all, nil
	end)
	if ok then
		cache = clean(stored)
		return true
	end
	return err == "exists"
end

return Hall
