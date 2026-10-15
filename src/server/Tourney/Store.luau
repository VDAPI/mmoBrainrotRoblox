--!strict
-- The Champion's Tournament between servers (S130, DESIGN-17 §0.4/§8): the signup lists, the organizer's lock and the
-- records of the tournament servers. A plain module (no service). Every store call goes through a Logic/ArenaQueue
-- Backend: the real one of Arena/Matchmaker (MemoryStore and ReserveServer, every call in pcall with retries,
-- Market/Retry) or this module's in-memory fake (Logic/MemoryFake: Studio, no API access, a store failure; the
-- tournament of this server only). No third fake and no own registry of reserved servers: the mode of a tournament
-- server is the S127 ReservedServers entry (Arena/ServerMode.register).
--   * SortedMap "<signupMap>_<id>_<bracket>": key = the character key, value { n, c, r, l, t } (name, class, rating,
--     level, signup time), sort key = Logic/Tourney.sortKey (the best first);
--   * HashMap <serverMap>: "lock_<id>" = { j = JobId, t } (one organizer per tournament), "srv_<id>_<bracket>" = Record.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaQueue = require(ReplicatedStorage.Shared.Logic.ArenaQueue)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Matchmaker = require(script.Parent.Parent.Arena.Matchmaker)
local MemoryFake = require(ReplicatedStorage.Shared.Logic.MemoryFake)
local Tourney = require(ReplicatedStorage.Shared.Logic.Tourney)

local log = Log.new("TourneyStore")

local CFG = Config.Tourney
local RANGE = 200 -- GetRangeAsync count limit (one page holds the 32 + every overflow worth reading)

export type Mode = "global" | "local"
-- The record of one bracket of one tournament: "open" (a server reserved: `code`, `ps`) or "cancelled" (too few, a
-- store or reservation error: `reason`). `players` = the picked ones (key, name, class, rating, signup time).
export type Record = {
	state: "open" | "cancelled",
	reason: string?,
	code: string?,
	ps: string?,
	keys: { string },
	players: { { k: string, n: string, c: string, r: number, t: number } },
	n: number,
	startAt: number,
	minRating: number?,
}

local Store = {}

-- The in-memory store of this server (the local mode and Studio); never reserves a server.
local fake: any = MemoryFake.new(function(): number
	return os.time()
end)
fake.canReserve = false

local probed: boolean? = nil
local counts: { [string]: { at: number, n: number?, threshold: number? } } = {}
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string, ...: any)
	if warned[key] then
		return
	end
	warned[key] = true
	log:warn(message, ...)
end

-- Whether the cross-server stores answer (yields once; Studio is always false). The result is remembered for the
-- server's life unless `again`.
function Store.probe(again: boolean?): boolean
	if probed ~= nil and not again then
		return probed
	end
	if RunService:IsStudio() then
		probed = false
		return false
	end
	local ok, err = pcall(function()
		return MemoryStoreService:GetHashMap(CFG.serverMap):GetAsync("probe")
	end)
	if not ok then
		warnOnce("probe", "MemoryStore unavailable (%s): the tournament runs on this server only", tostring(err))
	end
	probed = ok
	return ok
end

-- The backend of a mode: the Matchmaker's real one ("global") or the fake of this server ("local").
function Store.backend(mode: Mode): ArenaQueue.Backend
	if mode == "global" then
		return Matchmaker.Backend()
	end
	return fake :: ArenaQueue.Backend
end

local function signupMap(id: string, bracket: string): string
	return `{CFG.signupMap}_{id}_{bracket}`
end

-- A signup (the sort key from the rating and the seconds since the signups opened).
function Store.signup(
	mode: Mode,
	id: string,
	bracket: string,
	key: string,
	entry: { n: string, c: string, r: number, l: number, t: number },
	openAt: number
): boolean
	local sortKey = Tourney.sortKey(entry.r, entry.t - openAt)
	local ok = Store.backend(mode).update(signupMap(id, bracket), key, function(_current: any?): (any?, number?)
		return entry, sortKey
	end, CFG.signupTtl)
	counts[`{id}_{bracket}`] = nil
	return ok
end

function Store.unsign(mode: Mode, id: string, bracket: string, key: string): boolean
	local ok = Store.backend(mode).remove(signupMap(id, bracket), key)
	counts[`{id}_{bracket}`] = nil
	return ok
end

-- Every signup of a bracket as Logic/Tourney entries (the best first); nil when the read failed.
function Store.readSignups(mode: Mode, id: string, bracket: string): { Tourney.Entry }?
	local ok, items = Store.backend(mode).range(signupMap(id, bracket), nil, nil, RANGE)
	if not ok or items == nil then
		return nil
	end
	local out: { Tourney.Entry } = {}
	for _, item in items do
		local v = item.value
		if type(v) == "table" then
			table.insert(out, {
				key = item.key,
				rating = tonumber(v.r) or 0,
				t = tonumber(v.t) or 0,
				name = if type(v.n) == "string" then v.n else "?",
				class = if type(v.c) == "string" then v.c else "warrior",
			})
		end
	end
	return out
end

-- (count, threshold rating when over the cap) of a bracket, read at most every Config.Tourney.infoCache s.
function Store.count(mode: Mode, id: string, bracket: string, now: number): (number?, number?)
	local key = `{id}_{bracket}`
	local cached = counts[key]
	if cached and now - cached.at < CFG.infoCache then
		return cached.n, cached.threshold
	end
	local entries = Store.readSignups(mode, id, bracket)
	local n: number? = nil
	local threshold: number? = nil
	if entries then
		n = #entries
		local _, _, t = Tourney.pick(entries, Tourney.RULES.cap)
		threshold = t
	end
	counts[key] = { at = now, n = n, threshold = threshold }
	return n, threshold
end

-- The organizer's lock of a tournament: true only for the server whose JobId got written.
function Store.tryLock(mode: Mode, id: string, jobId: string): boolean
	local ok, after = Store.backend(mode).hupdate(CFG.serverMap, `lock_{id}`, function(current: any?): any?
		if type(current) == "table" then
			return nil -- taken: no write
		end
		return { j = jobId, t = os.time() }
	end, CFG.lockTtl)
	return ok and type(after) == "table" and after.j == jobId
end

-- The holder of the lock (admin info), nil when none or unknown.
function Store.lockHolder(mode: Mode, id: string): string?
	local ok, value = Store.backend(mode).hget(CFG.serverMap, `lock_{id}`)
	return if ok and type(value) == "table" and type(value.j) == "string" then value.j else nil
end

function Store.writeServer(mode: Mode, id: string, bracket: string, record: Record): boolean
	local ok = Store.backend(mode).hupdate(CFG.serverMap, `srv_{id}_{bracket}`, function(_current: any?): any?
		return record
	end, CFG.recordTtl)
	return ok
end

-- The record of a bracket: (ok, record?) - ok = false only when the read failed.
function Store.readServer(mode: Mode, id: string, bracket: string): (boolean, Record?)
	local ok, value = Store.backend(mode).hget(CFG.serverMap, `srv_{id}_{bracket}`)
	if not ok then
		return false, nil
	end
	if type(value) == "table" and (value.state == "open" or value.state == "cancelled") then
		return true, value :: Record
	end
	return true, nil
end

-- A reserved server for a bracket: (accessCode, privateServerId) or nil.
function Store.reserve(mode: Mode): (string?, string?)
	return Store.backend(mode).reserve()
end

-- Admin /tourney close on a test tournament and the tests: forget the cached counts.
function Store.forget()
	table.clear(counts)
end

return Store
