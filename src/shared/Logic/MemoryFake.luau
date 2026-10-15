--!strict
-- In-memory stand-in for MemoryStore (sorted maps and hash maps), MessagingService and TeleportService:ReserveServer
-- (S127, DESIGN-17 §0.4): one object with the Logic/ArenaQueue Backend interface. The arena queue runs on it in
-- Studio, with "/arenanet offline" and after a run of store errors (src/server/Arena/Matchmaker), and in the Lune
-- tests, where several "servers" share one fake and one clock (tests/arenaqueue.spec).
-- Every map is a Logic/Leaderboard.memoryBoard (S124; score = the sort key, 0 for a hash map), so there is one
-- in-memory store in the game. What the leaderboard does not need lives here: maps by name, write conflicts, failures,
-- reservations and messages. Semantics copied from MemoryStore:
--   * range(map, lo, hi, count): lo < sortKey < hi (nil = no bound), ascending by sort key, then by key, at most count;
--   * an entry vanishes `ttl` s after its last write (the clock decides; tests move it);
--   * update / hupdate run a transform on the current value; nil from the transform writes nothing. The transform may
--     run more than once: `onBeforeCommit(fn(map, key))` runs between the transform and the write, and when it changed
--     that key the transform runs again on the new value (at most MAX_TRIES times, then the call fails);
--   * fail(op, n): the next n calls of `op` fail;
--   * values are deep copies both ways (a caller never changes the store through a reference).
-- Returns of update / hupdate: (ok, the value stored now, the value the last transform saw).

local Leaderboard = require("./Leaderboard")
local TableUtil = require("../Util/TableUtil")

export type Item = { key: string, value: any, sortKey: number }

local MAX_TRIES = 5

local MemoryFake = {}

function MemoryFake.new(clock: () -> number)
	local maps: { [string]: Leaderboard.MemoryBoard } = {}
	local versions: { [string]: number } = {}
	local failing: { [string]: number } = {}
	local hook: ((map: string, key: string) -> ())? = nil
	local inHook = false
	local subscribers: { (message: { [string]: any }) -> () } = {}
	local reserved = 0

	local fake = {} :: any
	fake.sent = {} :: { { [string]: any } }
	fake.calls = {} :: { [string]: number }
	fake.canReserve = true

	local function board(name: string): Leaderboard.MemoryBoard
		local b = maps[name]
		if not b then
			b = Leaderboard.memoryBoard()
			maps[name] = b
		end
		return b
	end

	local function vkey(map: string, key: string): string
		return map .. "\0" .. key
	end

	local function bump(map: string, key: string)
		local k = vkey(map, key)
		versions[k] = (versions[k] or 0) + 1
	end

	-- Counts the call and answers whether it must fail now.
	local function failsNow(op: string): boolean
		fake.calls[op] = (fake.calls[op] or 0) + 1
		local n = failing[op]
		if n and n > 0 then
			failing[op] = n - 1
			return true
		end
		return false
	end

	local function current(map: string, key: string): (any?, number?)
		local e = board(map).get(key, clock())
		if not e then
			return nil, nil
		end
		local stored = e.value :: { value: any }
		return TableUtil.deepCopy(stored.value), e.score
	end

	local function write(map: string, key: string, value: any, sortKey: number, ttl: number)
		local now = clock()
		board(map).set(key, sortKey, { value = TableUtil.deepCopy(value) }, now + ttl)
		bump(map, key)
	end

	-- The one transform loop of update and hupdate (conflicts as UpdateAsync: run again on the new value).
	local function transform(
		op: string,
		map: string,
		key: string,
		fn: (current: any?) -> (any?, number?),
		ttl: number,
		sorted: boolean
	): (boolean, any?, any?)
		if failsNow(op) then
			return false, nil, nil
		end
		for _ = 1, MAX_TRIES do
			local before = versions[vkey(map, key)] or 0
			local cur = current(map, key)
			local value, sortKey = fn(TableUtil.deepCopy(cur))
			local h = hook
			if h and not inHook then
				inHook = true
				local ok, err = pcall(function()
					h(map, key)
				end)
				inHook = false
				if not ok then
					error(err, 0)
				end
			end
			if (versions[vkey(map, key)] or 0) ~= before then
				continue -- somebody wrote this key meanwhile: the transform runs again
			end
			if value == nil then
				return true, cur, cur
			end
			write(map, key, value, if sorted then tonumber(sortKey) or 0 else 0, ttl)
			return true, TableUtil.deepCopy(value), cur
		end
		return false, nil, nil
	end

	-- Sorted maps -------------------------------------------------------------------------------------------------

	function fake.range(map: string, lo: number?, hi: number?, count: number): (boolean, { Item }?)
		if failsNow("range") then
			return false, nil
		end
		local out: { Item } = {}
		for _, e in board(map).range(lo, hi, count, clock()) do
			local stored = e.value :: { value: any }
			table.insert(out, { key = e.key, value = TableUtil.deepCopy(stored.value), sortKey = e.score })
		end
		return true, out
	end

	function fake.update(
		map: string,
		key: string,
		fn: (current: any?) -> (any?, number?),
		ttl: number
	): (boolean, any?, any?)
		return transform("update", map, key, fn, ttl, true)
	end

	function fake.remove(map: string, key: string): boolean
		if failsNow("remove") then
			return false
		end
		board(map).remove(key)
		bump(map, key)
		return true
	end

	-- Hash maps ---------------------------------------------------------------------------------------------------

	function fake.hget(map: string, key: string): (boolean, any?)
		if failsNow("hget") then
			return false, nil
		end
		return true, (current(map, key))
	end

	function fake.hupdate(map: string, key: string, fn: (current: any?) -> any?, ttl: number): (boolean, any?, any?)
		return transform("hupdate", map, key, function(cur: any?): (any?, number?)
			return fn(cur), 0
		end, ttl, false)
	end

	function fake.hremove(map: string, key: string): boolean
		if failsNow("hremove") then
			return false
		end
		board(map).remove(key)
		bump(map, key)
		return true
	end

	-- Reservations and messages -----------------------------------------------------------------------------------

	-- ("fake-code-<n>", "fake-psid-<n>"); nil when this fake cannot reserve (the game's fallback: no teleports).
	function fake.reserve(): (string?, string?)
		if failsNow("reserve") or not fake.canReserve then
			return nil, nil
		end
		reserved += 1
		return `fake-code-{reserved}`, `fake-psid-{reserved}`
	end

	function fake.publish(message: { [string]: any }): boolean
		if failsNow("publish") then
			return false
		end
		local copy = TableUtil.deepCopy(message)
		table.insert(fake.sent, copy)
		for _, fn in table.clone(subscribers) do
			fn(TableUtil.deepCopy(copy))
		end
		return true
	end

	-- Test and tooling hooks ----------------------------------------------------------------------------------------

	function fake.subscribe(_self: any, fn: (message: { [string]: any }) -> ())
		table.insert(subscribers, fn)
	end

	function fake.onBeforeCommit(_self: any, fn: ((map: string, key: string) -> ())?)
		hook = fn
	end

	function fake.fail(_self: any, op: string, n: number)
		failing[op] = n
	end

	-- Every live item of a map, ascending (admin status, tests).
	function fake.items(_self: any, map: string): { Item }
		local _, list = fake.range(map, nil, nil, math.huge)
		fake.calls.range -= 1
		return list or {}
	end

	return fake
end

return MemoryFake
