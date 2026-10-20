--!strict
-- Presence across servers, pure (S150). One entry per account in the MemoryStore HashMap Config.Friends.presenceMap
-- (key tostring(userId)), written by the player's server every Config.Friends.presenceEvery and at once on a change:
--   { j = JobId, m = server mode ("world" | "arena" | "tournament"), p = a private or reserved server, map, lvl, cls,
--     name = character name, t = os.time of the write, pj = who may join ("friends" | "none") }
-- An invisible player (account.settings.appearOffline) has no entry. Status of an entry seen from a server:
--   here (this server), world (another world server), private (another player's private server: no "Join"),
--   arena, tournament, offline (no entry or older than the TTL), unknown (the read failed).
-- Reads go through `reader`: a cache shared by everyone on the server (Config.Friends.cacheSeconds: two viewers of
-- the same friend cost one read) and a token bucket (`budget`, Config.Friends.readsPerMinute per server) in which
-- window refreshes come first. Without a token a row keeps its last state ("wait"), never an error.
-- The backend is the Logic/ArenaQueue hash map interface (hget / hupdate / hremove): Logic/MemoryFake in the tests
-- and in Studio, MemoryStore through src/server/Friends/Presence in the game.

local Config = require("../Config")

export type Mode = "world" | "arena" | "tournament"
export type Status = "here" | "world" | "private" | "arena" | "tournament" | "offline" | "unknown"
export type Record = {
	j: string,
	m: string,
	p: boolean,
	map: string?,
	lvl: number?,
	cls: string?,
	name: string?,
	t: number,
	pj: string,
}

export type Backend = {
	hget: (map: string, key: string) -> (boolean, any?),
	hupdate: (map: string, key: string, fn: (current: any?) -> any?, ttl: number) -> (boolean, any?, any?),
	hremove: (map: string, key: string) -> boolean,
}

export type Priority = "window" | "other" | "join"

export type BudgetStats = { tokens: number, reads: number, hits: number, denied: number }

export type Budget = {
	take: (priority: Priority) -> boolean,
	hit: () -> (),
	stats: () -> BudgetStats,
}

export type ReadState = "ok" | "fail" | "wait"

export type Reader = {
	write: (userId: number, rec: Record) -> boolean,
	remove: (userId: number) -> boolean,
	read: (userId: number, priority: Priority) -> (ReadState, Record?),
	forget: (userId: number) -> (),
	budget: Budget,
}

local Presence = {}

local F = Config.Friends

Presence.MODES = table.freeze({ world = true, arena = true, tournament = true })
Presence.JOIN = table.freeze({ friends = true, none = true })

-- Sort order of the friends window: here, other world servers, private servers, arena and tournament, unknown,
-- offline.
Presence.ORDER = table.freeze({
	here = 1,
	world = 2,
	private = 3,
	arena = 4,
	tournament = 4,
	unknown = 5,
	offline = 6,
})

function Presence.key(userId: number): string
	return tostring(math.floor(userId))
end

-- A record from known fields (the one constructor; unknown modes count as a world, unknown join rules as "none").
function Presence.record(fields: {
	j: string,
	m: string,
	p: boolean?,
	map: string?,
	lvl: number?,
	cls: string?,
	name: string?,
	t: number,
	pj: string?,
}): Record
	return {
		j = fields.j,
		m = if Presence.MODES[fields.m] then fields.m else "world",
		p = fields.p == true,
		map = fields.map,
		lvl = fields.lvl,
		cls = fields.cls,
		name = fields.name,
		t = fields.t,
		pj = if fields.pj == "friends" then "friends" else "none",
	}
end

-- A stored value as a record, nil when it is not one (garbage, an S133 entry of the old map).
function Presence.parse(value: any): Record?
	if type(value) ~= "table" or type(value.j) ~= "string" or type(value.t) ~= "number" then
		return nil
	end
	if type(value.m) ~= "string" or not Presence.MODES[value.m] then
		return nil
	end
	return Presence.record({
		j = value.j,
		m = value.m,
		p = value.p == true,
		map = if type(value.map) == "string" then value.map else nil,
		lvl = if type(value.lvl) == "number" then value.lvl else nil,
		cls = if type(value.cls) == "string" then value.cls else nil,
		name = if type(value.name) == "string" then value.name else nil,
		t = value.t,
		pj = if type(value.pj) == "string" then value.pj else nil,
	})
end

function Presence.fresh(rec: Record?, now: number, ttl: number?): boolean
	return rec ~= nil and now - rec.t <= (ttl or F.presenceTtl) and rec.t <= now + 60
end

-- Status of `rec` seen from the server `viewerJobId`; `rec == false` = the read failed (unknown).
function Presence.statusOf(rec: Record | false | nil, viewerJobId: string, now: number, ttl: number?): Status
	if rec == false then
		return "unknown"
	end
	if rec == nil or not Presence.fresh(rec, now, ttl) then
		return "offline"
	end
	if rec.j == viewerJobId then
		return "here"
	end
	if rec.m == "arena" or rec.m == "tournament" then
		return rec.m :: Status
	end
	return if rec.p then "private" else "world"
end

-- Whether the status is "in the game" (the online counter of the window).
function Presence.online(status: Status): boolean
	return status ~= "offline" and status ~= "unknown"
end

-- The row text: a Locale key and its arguments (`map` is a map id: the client shows its name).
function Presence.label(status: Status, rec: Record?): (string, { [string]: any })
	local args: { [string]: any } = {}
	if rec then
		args.map = rec.map or ""
		args.lvl = rec.lvl or 0
	end
	return `friends.status.{status}`, args
end

local TAG_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

-- A short fixed tag of a server ("K7QF"): two friends on the same other server show the same tag.
function Presence.serverTag(jobId: string): string
	local h = 5381
	for i = 1, #jobId do
		h = (h * 33 + string.byte(jobId, i)) % 4294967296
	end
	local out = {}
	for _ = 1, 4 do
		local index = h % 32
		h = (h - index) / 32
		table.insert(out, string.sub(TAG_CHARS, index + 1, index + 1))
	end
	return table.concat(out)
end

-- Budget ---------------------------------------------------------------------------------------------------------

-- A token bucket of `perMinute` reads (full at start, refilled continuously). Window refreshes may take every
-- token, other reads (Roblox friends) leave `reserve` of the bucket to them, a join check always reads (counted).
function Presence.budget(perMinute: number, clock: () -> number, reserve: number?): Budget
	local capacity = math.max(1, perMinute)
	local keep = capacity * (reserve or F.otherReserve)
	local tokens = capacity
	local last = clock()
	local reads: { number } = {}
	local hits, denied = 0, 0

	local function refill()
		local now = clock()
		tokens = math.min(capacity, tokens + (now - last) * capacity / 60)
		last = now
		while reads[1] and now - reads[1] >= 60 do
			table.remove(reads, 1)
		end
	end

	local budget = {} :: Budget
	budget.take = function(priority: Priority): boolean
		refill()
		local need = if priority == "other" then keep + 1 else 1
		if priority ~= "join" and tokens < need then
			denied += 1
			return false
		end
		tokens = math.max(0, tokens - 1)
		table.insert(reads, last)
		return true
	end
	budget.hit = function()
		hits += 1
	end
	budget.stats = function(): BudgetStats
		refill()
		return { tokens = math.floor(tokens), reads = #reads, hits = hits, denied = denied }
	end
	return budget
end

-- Reader ---------------------------------------------------------------------------------------------------------

type Cached = { at: number, ok: boolean, rec: Record? }

export type ReaderOptions = { map: string?, ttl: number?, cacheSeconds: number?, budget: Budget? }

-- Reads and writes of one map with the server's cache and budget. `clock` is in seconds (os.time in the game).
function Presence.reader(backend: Backend, clock: () -> number, opts: ReaderOptions?): Reader
	local o: ReaderOptions = opts or {}
	local mapName = o.map or F.presenceMap
	local ttl = o.ttl or F.presenceTtl
	local cacheFor = o.cacheSeconds or F.cacheSeconds
	local budget = o.budget or Presence.budget(F.readsPerMinute, clock)
	local cache: { [string]: Cached } = {}

	local reader = {} :: Reader
	reader.budget = budget
	reader.write = function(userId: number, rec: Record): boolean
		local key = Presence.key(userId)
		cache[key] = nil
		local ok = backend.hupdate(mapName, key, function(_current: any?): any?
			return rec
		end, ttl)
		return ok
	end
	reader.remove = function(userId: number): boolean
		local key = Presence.key(userId)
		cache[key] = nil
		return backend.hremove(mapName, key)
	end
	reader.forget = function(userId: number)
		cache[Presence.key(userId)] = nil
	end
	reader.read = function(userId: number, priority: Priority): (ReadState, Record?)
		local key = Presence.key(userId)
		local now = clock()
		local hit = cache[key]
		if hit and now - hit.at < cacheFor then
			budget.hit()
			return if hit.ok then "ok" else "fail", hit.rec
		end
		if not budget.take(priority) then
			return "wait", if hit then hit.rec else nil
		end
		local ok, value = backend.hget(mapName, key)
		local rec = if ok then Presence.parse(value) else nil
		cache[key] = { at = now, ok = ok, rec = rec }
		return if ok then "ok" else "fail", rec
	end
	return reader
end

return Presence
