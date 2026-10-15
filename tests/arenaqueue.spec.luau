--!strict
-- The global arena queue (S127, DESIGN-17 §6): Logic/ArenaQueue on Logic/MemoryFake (one fake, one clock and several
-- "servers" in one test: the races of D8), the arena server's decisions, the arena_pit map and the wiring of the
-- server modules (static checks on the file text: Roblox-style requires do not run in Lune).

local fs = require("@lune/fs")

local Arena = require("../src/shared/Data/Arena")
local ArenaPit = require("../src/shared/Data/ArenaPit")
local ArenaQueue = require("../src/shared/Logic/ArenaQueue")
local ArenaRules = require("../src/shared/Logic/ArenaRules")
local Config = require("../src/shared/Config")
local Maps = require("../src/shared/Data/Maps")
local MemoryFake = require("../src/shared/Logic/MemoryFake")
local T = require("./Test")

local NET = Config.ArenaNet
local MAP = ArenaQueue.queueMap("1v1", "40_59")

type Clock = { now: number }

local function newClock(start: number?): (Clock, () -> number)
	local c: Clock = { now = start or 1000000 }
	return c, function()
		return c.now
	end
end

local function ticket(userId: number, rating: number, joinedAt: number, slot: number?): ArenaRules.Ticket
	local s = slot or 1
	return {
		entrant = {
			key = ArenaQueue.entryKey(userId, s),
			userId = userId,
			slot = s,
			name = `P{userId}`,
			class = "Warrior",
			level = 45,
			rating = rating,
			played = 0,
		},
		mode = "1v1",
		bracket = "40_59",
		joinedAt = joinedAt,
	}
end

-- Puts a waiting entry of `job` into the fake; returns it as the store holds it.
local function enter(fake: any, job: string, t: ArenaRules.Ticket): ArenaQueue.Entry
	local entry = ArenaQueue.newEntry(t, job)
	local ok, stored = fake.update(MAP, entry.key, ArenaQueue.put(entry), NET.entryTtl)
	assert(ok, "put failed")
	return stored
end

local function stored(fake: any, key: string): any
	for _, item in fake:items(MAP) do
		if item.key == key then
			return item.value
		end
	end
	return nil
end

local function records(fake: any): { ArenaQueue.MatchRecord }
	local out = {}
	for _, item in fake:items(NET.matchMap) do
		table.insert(out, item.value)
	end
	return out
end

local idN = 0
local function newId(): string
	idN += 1
	return `m{idN}`
end

T.describe("ArenaQueue H1: MemoryFake", function()
	T.it("range: sort key then key, exclusive bounds, count, nil = no bound", function()
		local _, clock = newClock()
		local fake = MemoryFake.new(clock)
		for i, score in { 30, 10, 20, 20, 40 } do
			fake.update("m", `k{i}`, function()
				return { i = i }, score
			end, 120)
		end
		local _, all = fake.range("m", nil, nil, 10)
		local keys = {}
		for _, item in all do
			table.insert(keys, item.key)
		end
		T.expect(keys).toEqual({ "k2", "k3", "k4", "k1", "k5" })
		local _, mid = fake.range("m", 10, 40, 10)
		T.expect(#mid).toBe(3)
		T.expect(mid[1].key).toBe("k3")
		local _, cut = fake.range("m", nil, nil, 2)
		T.expect(#cut).toBe(2)
		local _, high = fake.range("m", 20, nil, 10)
		T.expect(high[1].key).toBe("k1")
	end)

	T.it("ttl: an entry lives 120 s from its last write; update renews it", function()
		local c, clock = newClock(100)
		local fake = MemoryFake.new(clock)
		fake.update("m", "a", function()
			return { v = 1 }, 1
		end, 120)
		c.now = 219
		T.expect(fake.hget("m", "a")).toBe(true)
		local _, v = fake.hget("m", "a")
		T.expect(v.v).toBe(1)
		fake.update("m", "a", function(cur)
			return cur, 1
		end, 120)
		c.now = 330
		local _, still = fake.hget("m", "a")
		T.expect(still ~= nil).toBe(true)
		c.now = 341
		local _, gone = fake.hget("m", "a")
		T.expect(gone).toBeNil()
	end)

	T.it("a transform returning nil writes nothing and returns the current value", function()
		local _, clock = newClock()
		local fake = MemoryFake.new(clock)
		fake.hupdate("h", "a", function()
			return { v = 1 }
		end, 60)
		local ok, value = fake.hupdate("h", "a", function()
			return nil
		end, 60)
		T.expect(ok).toBe(true)
		T.expect(value.v).toBe(1)
	end)

	T.it("a conflict runs the transform again on the new value; five conflicts fail", function()
		local _, clock = newClock()
		local fake = MemoryFake.new(clock)
		fake.hupdate("h", "a", function()
			return { n = 1 }
		end, 60)
		local calls = 0
		local once = false
		fake:onBeforeCommit(function(map, key)
			if not once then
				once = true
				fake.hupdate(map, key, function()
					return { n = 10 }
				end, 60)
			end
		end)
		local ok, value = fake.hupdate("h", "a", function(cur)
			calls += 1
			return { n = cur.n + 1 }
		end, 60)
		T.expect(ok).toBe(true)
		T.expect(calls).toBe(2)
		T.expect(value.n).toBe(11)
		local spins = 0
		fake:onBeforeCommit(function(map, key)
			spins += 1
			fake.hupdate(map, key, function(cur)
				return { n = cur.n + 100 }
			end, 60)
		end)
		local ok2 = fake.hupdate("h", "a", function(cur)
			return { n = cur.n + 1 }
		end, 60)
		T.expect(ok2).toBe(false)
		T.expect(spins).toBe(5)
		fake:onBeforeCommit(nil)
	end)

	T.it("fail(op, n) fails the next n calls; values are copies", function()
		local _, clock = newClock()
		local fake = MemoryFake.new(clock)
		fake:fail("update", 1)
		local first = fake.update("m", "a", function()
			return { list = { 1 } }, 1
		end, 60)
		T.expect(first).toBe(false)
		local ok, value = fake.update("m", "a", function()
			return { list = { 1 } }, 1
		end, 60)
		T.expect(ok).toBe(true)
		value.list[1] = 99
		local _, again = fake.hget("m", "a")
		T.expect(again.list[1]).toBe(1)
	end)
end)

T.describe("ArenaQueue H2: entries and pairing", function()
	T.it("keys and map names", function()
		T.expect(ArenaQueue.entryKey(123, 2)).toBe("123_2")
		T.expect(ArenaQueue.queueMap("1v1", "40_59")).toBe("ArenaQueue_1v1_40_59")
		T.expect(ArenaQueue.matchKey("x")).toBe("ArenaMatch_x")
	end)

	T.it("claim, unclaim and refresh", function()
		local now = 5000
		local e = ArenaQueue.newEntry(ticket(1, 1000, now), "jobA")
		local claimed = ArenaQueue.claim("m1", now, 20)(e)
		T.expect(claimed.state).toBe("claimed")
		T.expect(claimed.match).toBe("m1")
		T.expect(claimed.claimUntil).toBe(now + 20)
		T.expect(ArenaQueue.claim("m2", now + 5, 20)(claimed)).toBeNil()
		local taken = ArenaQueue.claim("m2", now + 21, 20)(claimed)
		T.expect(taken.match).toBe("m2")
		T.expect(ArenaQueue.claim("m1", now, 20)(nil)).toBeNil()
		T.expect(ArenaQueue.unclaim("other")(claimed)).toBeNil()
		local back = ArenaQueue.unclaim("m1")(claimed)
		T.expect(back.state).toBe("wait")
		T.expect(back.ticket.joinedAt).toBe(now)
		local info = { rating = 1010, level = 46, name = "P1" }
		T.expect(ArenaQueue.refresh("jobB", info, now)(e)).toBeNil()
		T.expect(ArenaQueue.refresh("jobA", info, now + 5)(claimed).state).toBe("claimed")
		local freed = ArenaQueue.refresh("jobA", info, now + 21)(claimed)
		T.expect(freed.state).toBe("wait")
		T.expect(freed.ticket.entrant.rating).toBe(1010)
	end)

	T.it("release gives back only the claim of the failed match", function()
		local now = 5000
		local e = ArenaQueue.newEntry(ticket(1, 1000, now - 50), "jobA")
		local mine = ArenaQueue.claim("m1", now, 20)(e)
		T.expect(ArenaQueue.release("m1", e)(mine).state).toBe("wait")
		local other = ArenaQueue.claim("m2", now, 20)(e)
		T.expect(ArenaQueue.release("m1", e)(other)).toBeNil()
		local back = ArenaQueue.release("m1", e)(nil)
		T.expect(back.state).toBe("wait")
		T.expect(back.ticket.joinedAt).toBe(now - 50)
	end)

	T.it("pickPartner: closest rating in the window, older on a tie, skips what it must", function()
		local now = 10000
		local me = ArenaQueue.newEntry(ticket(1, 1000, now - 60), "j1")
		local a = ArenaQueue.newEntry(ticket(2, 1040, now - 10), "j2")
		local b = ArenaQueue.newEntry(ticket(3, 960, now - 20), "j3")
		local far = ArenaQueue.newEntry(ticket(4, 2000, now - 5), "j4")
		local same = ArenaQueue.newEntry(ticket(1, 1001, now - 5, 2), "j5")
		local busy = ArenaQueue.claim("x", now, 20)(ArenaQueue.newEntry(ticket(6, 1000, now - 5), "j6"))
		local pick = ArenaQueue.pickPartner(me, { a, b, far, same, busy, me }, now)
		T.expect(pick and pick.key).toBe(b.key) -- 40 = 40: b waits longer
		local avoided = ArenaQueue.pickPartner(me, { a, b }, now, { avoid = { [b.key] = true } })
		T.expect(avoided and avoided.key).toBe(a.key)
		T.expect(ArenaQueue.pickPartner(me, { far }, now)).toBeNil()
		local other = ArenaQueue.newEntry(ticket(7, 1000, now - 5), "j7")
		other.ticket.bracket = "60_79"
		T.expect(ArenaQueue.pickPartner(me, { other }, now)).toBeNil()
	end)

	T.it("pickPartner chooses what ArenaRules.pair chooses for the oldest ticket", function()
		local now = 20000
		local sets = {
			{ { 1, 1000, 100 }, { 2, 1080, 30 }, { 3, 920, 20 }, { 4, 1300, 10 } },
			{ { 1, 1500, 50 }, { 2, 1400, 40 }, { 3, 1650, 40 }, { 4, 1520, 5 } },
			{ { 1, 900, 200 }, { 2, 1250, 10 }, { 3, 1190, 15 } },
		}
		for _, set in sets do
			local tickets, entries = {}, {}
			for _, row in set do
				local t = ticket(row[1], row[2], now - row[3])
				table.insert(tickets, t)
				table.insert(entries, ArenaQueue.newEntry(t, `j{row[1]}`))
			end
			local pairs = ArenaRules.pair(tickets, now)
			local mine = ArenaQueue.pickPartner(entries[1], entries, now)
			if #pairs == 0 then
				T.expect(mine).toBeNil()
			else
				local expected = pairs[1].sides[2][1].entrant.key
				T.expect(mine and mine.key).toBe(expected)
			end
		end
	end)

	T.it("shouldInitiate is antisymmetric; lockOrder ignores the argument order", function()
		local a = ArenaQueue.newEntry(ticket(1, 1000, 50), "j1")
		local b = ArenaQueue.newEntry(ticket(2, 1000, 60), "j2")
		local c = ArenaQueue.newEntry(ticket(3, 1000, 60), "j3")
		T.expect(ArenaQueue.shouldInitiate(a, b) ~= ArenaQueue.shouldInitiate(b, a)).toBe(true)
		T.expect(ArenaQueue.shouldInitiate(b, c) ~= ArenaQueue.shouldInitiate(c, b)).toBe(true)
		local x1, y1 = ArenaQueue.lockOrder(a, c)
		local x2, y2 = ArenaQueue.lockOrder(c, a)
		T.expect(x1.key).toBe(x2.key)
		T.expect(y1.key).toBe(y2.key)
	end)

	T.it("the window is ArenaRules.window (Data/Arena.QUEUE)", function()
		local now = 30000
		local gap = Arena.QUEUE.window + Arena.QUEUE.widen / 2
		local me = ArenaQueue.newEntry(ticket(1, 1000, now), "j1")
		local other = ArenaQueue.newEntry(ticket(2, 1000 + gap, now), "j2")
		T.expect(ArenaQueue.pickPartner(me, { other }, now)).toBeNil()
		me.ticket.joinedAt = now - Arena.QUEUE.widenEvery
		local pick = ArenaQueue.pickPartner(me, { other }, now)
		T.expect(pick and pick.key).toBe(other.key)
	end)
end)

T.describe("ArenaQueue H3: races of two and three servers", function()
	local function setup()
		local c, clock = newClock(50000)
		local fake = MemoryFake.new(clock)
		return c, fake
	end

	T.it("two servers, in turn: exactly one record, both entries claimed by it", function()
		local c, fake = setup()
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 30))
		local b = enter(fake, "S2", ticket(2, 1010, c.now - 20))
		local s1 = ArenaQueue.tryPair(fake, a, NET, c.now, newId, "S1")
		local s2 = ArenaQueue.tryPair(fake, stored(fake, b.key), NET, c.now, newId, "S2", { force = true })
		T.expect(s1).toBe("paired")
		T.expect(s2 == "none" or s2 == "lost").toBe(true)
		local list = records(fake)
		T.expect(#list).toBe(1)
		T.expect(stored(fake, a.key).match).toBe(list[1].id)
		T.expect(stored(fake, b.key).match).toBe(list[1].id)
	end)

	T.it("interleaved: server 2 runs a whole tryPair inside server 1's claim; one record, no dangling claim", function()
		local c, fake = setup()
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 30))
		local b = enter(fake, "S2", ticket(2, 1010, c.now - 20))
		local d = enter(fake, "S3", ticket(3, 1005, c.now - 25))
		local fired = false
		fake:onBeforeCommit(function(map, key)
			if not fired and map == MAP and key == b.key then
				fired = true
				ArenaQueue.tryPair(fake, stored(fake, d.key), NET, c.now, newId, "S3", { force = true })
			end
		end)
		ArenaQueue.tryPair(fake, a, NET, c.now, newId, "S1", { force = true })
		fake:onBeforeCommit(nil)
		local list = records(fake)
		local ids: { [string]: boolean } = {}
		for _, r in list do
			ids[r.id] = true
		end
		local claimedBy: { [string]: number } = {}
		for _, key in { a.key, b.key, d.key } do
			local e = stored(fake, key)
			if e.state == "claimed" then
				T.expect(ids[e.match]).toBe(true)
				claimedBy[e.match] = (claimedBy[e.match] or 0) + 1
			end
		end
		for _, r in list do
			T.expect(claimedBy[r.id]).toBe(2)
		end
		T.expect(#list).toBe(1)
	end)

	T.it("A-B on server 1 and C-B on server 3: at most one match with B, the loser gave its claim back", function()
		local c, fake = setup()
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 30))
		local b = enter(fake, "S2", ticket(2, 1000, c.now - 40))
		local cc = enter(fake, "S3", ticket(3, 1000, c.now - 35))
		local fired = false
		fake:onBeforeCommit(function(map, key)
			if not fired and map == MAP and key == b.key then
				fired = true
				ArenaQueue.tryPair(fake, stored(fake, cc.key), NET, c.now, newId, "S3", { force = true })
			end
		end)
		ArenaQueue.tryPair(fake, a, NET, c.now, newId, "S1", { force = true })
		fake:onBeforeCommit(nil)
		local withB = 0
		for _, r in records(fake) do
			for _, p in r.players do
				if p.key == b.key then
					withB += 1
				end
			end
		end
		T.expect(withB <= 1).toBe(true)
		local ea, ec = stored(fake, a.key), stored(fake, cc.key)
		T.expect(ea.state == "wait" or ec.state == "wait").toBe(true)
	end)

	T.it("equal times, both servers initiate: lockOrder gives one record", function()
		local c, fake = setup()
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 30))
		local b = enter(fake, "S2", ticket(2, 1000, c.now - 30))
		local fired = false
		fake:onBeforeCommit(function(map, _key)
			if not fired and map == MAP then
				fired = true
				ArenaQueue.tryPair(fake, stored(fake, b.key), NET, c.now, newId, "S2", { force = true })
			end
		end)
		ArenaQueue.tryPair(fake, a, NET, c.now, newId, "S1", { force = true })
		fake:onBeforeCommit(nil)
		T.expect(#records(fake)).toBe(1)
	end)

	T.it("an organizer dies after the first claim: refresh frees the entry after claimHold, ttl removes it", function()
		local c, fake = setup()
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 30))
		enter(fake, "S2", ticket(2, 1000, c.now - 20))
		fake:fail("update", 0)
		-- the first claim goes through, the second update "never happens" (the organizer died)
		local calls = 0
		fake:onBeforeCommit(function()
			calls += 1
			if calls == 2 then
				error("organizer died", 0)
			end
		end)
		pcall(ArenaQueue.tryPair, fake, a, NET, c.now, newId, "S1")
		fake:onBeforeCommit(nil)
		T.expect(stored(fake, a.key).state).toBe("claimed")
		c.now += NET.claimHold + 1
		local info = { rating = 1000, level = 45, name = "P1" }
		local _, after = fake.update(MAP, a.key, ArenaQueue.refresh("S1", info, c.now), NET.entryTtl)
		T.expect(after.state).toBe("wait")
		c.now += NET.entryTtl + 1
		T.expect(stored(fake, a.key)).toBeNil()
	end)

	T.it("reserve fails: both entries wait again, no record; publish fails: the match exists anyway", function()
		local c, fake = setup()
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 30))
		local b = enter(fake, "S2", ticket(2, 1000, c.now - 20))
		fake:fail("reserve", 1)
		local status = ArenaQueue.tryPair(fake, a, NET, c.now, newId, "S1")
		T.expect(status).toBe("error")
		T.expect(#records(fake)).toBe(0)
		T.expect(stored(fake, a.key).state).toBe("wait")
		T.expect(stored(fake, b.key).state).toBe("wait")
		fake:fail("publish", 1)
		local status2, record = ArenaQueue.tryPair(fake, stored(fake, a.key), NET, c.now, newId, "S1")
		T.expect(status2).toBe("paired")
		local _, read = fake.hget(NET.matchMap, ArenaQueue.matchKey(record.id))
		T.expect(ArenaQueue.entryAfter(read, b.key, stored(fake, b.key), c.now)).toBe("wait")
	end)

	T.it("a pair on one server: local pairing, nothing reserved or sent, entries removed", function()
		local c, fake = setup()
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 30))
		local b = enter(fake, "S1", ticket(2, 1000, c.now - 40))
		local status, pairing = ArenaQueue.tryPair(fake, b, NET, c.now, newId, "S1")
		T.expect(status).toBe("local")
		T.expect(pairing.sides[1][1].entrant.key).toBe(b.key)
		T.expect(pairing.sides[2][1].entrant.key).toBe(a.key)
		T.expect(fake.calls.reserve or 0).toBe(0)
		T.expect(fake.calls.publish or 0).toBe(0)
		T.expect(#records(fake)).toBe(0)
		T.expect(#fake:items(NET.registryMap)).toBe(0)
		T.expect(stored(fake, a.key)).toBeNil()
		T.expect(stored(fake, b.key)).toBeNil()
	end)

	T.it("a pair of two servers: the registry entry and the record", function()
		local c, fake = setup()
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 30))
		local b = enter(fake, "S2", ticket(2, 1050, c.now - 20))
		local status, record = ArenaQueue.tryPair(fake, a, NET, c.now, newId, "S1")
		T.expect(status).toBe("paired")
		local _, reg = fake.hget(NET.registryMap, record.psid)
		T.expect(reg).toEqual({ mode = "arena", ref = record.id })
		T.expect(record.code ~= nil).toBe(true)
		T.expect(record.players[1].key < record.players[2].key).toBe(true)
		T.expect(record.spec.origin).toBe("global")
		T.expect(record.spec.venue).toBe("pit")
		T.expect(record.spec.rated).toBe(true)
		T.expect(record.spec.sides[1][1].rating).toBe(1000)
		T.expect(record.spec.sides[2][1].rating).toBe(1050)
		T.expect(record.acceptBy).toBe(c.now + Arena.QUEUE.acceptSeconds)
		T.expect(stored(fake, b.key).claimUntil).toBe(record.acceptBy + NET.acceptGrace)
		T.expect(fake.sent[1].op).toBe("offer")
	end)
end)

T.describe("ArenaQueue H4: offers", function()
	local function offered(now: number): ArenaQueue.MatchRecord
		local a = ArenaQueue.newEntry(ticket(1, 1000, now - 30), "S1")
		local b = ArenaQueue.newEntry(ticket(2, 1000, now - 20), "S2")
		return ArenaQueue.newRecord("m", a, b, "S1", now, 15, "code", "psid")
	end

	T.it("both accept: accepted, and only the second write says so", function()
		local now = 1000
		local r = offered(now)
		local r1 = ArenaQueue.respond("1_1", true, now)(r)
		T.expect(r1.state).toBe("offered")
		T.expect(ArenaQueue.changed(r, r1)).toBeNil()
		local r2 = ArenaQueue.respond("2_1", true, now)(r1)
		T.expect(r2.state).toBe("accepted")
		T.expect(ArenaQueue.changed(r1, r2)).toBe("accepted")
		T.expect(ArenaQueue.changed(r2, r2)).toBeNil()
	end)

	T.it("a refusal cancels; a later accept changes nothing", function()
		local now = 1000
		local r = ArenaQueue.respond("1_1", false, now)(offered(now))
		T.expect(r.state).toBe("cancelled")
		T.expect(r.reason).toBe("declined")
		T.expect(r.by).toBe("1_1")
		T.expect(ArenaQueue.respond("2_1", true, now)(r)).toBeNil()
	end)

	T.it("expire: nothing before acceptBy, timeout after it, only the first of two servers", function()
		local now = 1000
		local r = offered(now)
		T.expect(ArenaQueue.expire(now + 10, NET)(r)).toBeNil()
		local half = ArenaQueue.respond("1_1", true, now)(r)
		local _, clock = newClock(now + 16)
		local fake = MemoryFake.new(clock)
		fake.hupdate(NET.matchMap, "k", function()
			return half
		end, 600)
		local _, after1, before1 = fake.hupdate(NET.matchMap, "k", ArenaQueue.expire(now + 16, NET), 600)
		local _, after2, before2 = fake.hupdate(NET.matchMap, "k", ArenaQueue.expire(now + 16, NET), 600)
		T.expect(after1.state).toBe("cancelled")
		T.expect(after1.reason).toBe("timeout")
		T.expect(after1.by).toBe("2_1")
		T.expect(ArenaQueue.changed(before1, after1)).toBe("cancelled")
		T.expect(ArenaQueue.changed(before2, after2)).toBeNil()
	end)

	T.it("entryAfter", function()
		local now = 1000
		local r = offered(now)
		local accepted = table.clone(r)
		accepted.state = "accepted"
		T.expect(ArenaQueue.entryAfter(accepted, "1_1", nil, now)).toBe("teleport")
		local mine = ArenaQueue.respond("1_1", false, now)(r)
		T.expect(ArenaQueue.entryAfter(mine, "1_1", nil, now)).toBe("penalty")
		T.expect(ArenaQueue.entryAfter(mine, "2_1", nil, now)).toBe("requeue")
		local tp = ArenaQueue.cancel("teleport", "2_1")(accepted)
		T.expect(ArenaQueue.entryAfter(tp, "1_1", nil, now)).toBe("requeue")
		local done = ArenaQueue.finish({ winner = "1_1" })(ArenaQueue.goLive()(accepted))
		T.expect(ArenaQueue.entryAfter(done, "1_1", nil, now)).toBe("remove")
		T.expect(ArenaQueue.entryAfter(r, "1_1", nil, now)).toBe("wait")
		local e = ArenaQueue.claim("m", now - 100, 20)(ArenaQueue.newEntry(ticket(1, 1000, now - 200), "S1"))
		T.expect(ArenaQueue.entryAfter(nil, "1_1", e, now)).toBe("requeue")
	end)

	T.it("a re-queue keeps joinedAt", function()
		local _, clock = newClock(9000)
		local fake = MemoryFake.new(clock)
		local t = ticket(1, 1000, 8000)
		enter(fake, "S1", t)
		fake.remove(MAP, t.entrant.key)
		enter(fake, "S1", t)
		T.expect(stored(fake, t.entrant.key).ticket.joinedAt).toBe(8000)
	end)
end)

T.describe("ArenaQueue H5: the arena server and the way back", function()
	T.it("decideMode", function()
		local function mode(info: any): (string, string?)
			return ArenaQueue.decideMode(info)
		end
		T.expect((mode({ privateServerId = "", ownerId = 0 }))).toBe("world")
		T.expect((mode({ privateServerId = "p", ownerId = 55, registry = { mode = "arena", ref = "m1" } })))
			.toBe("world")
		local m, ref = mode({ privateServerId = "p", ownerId = 0, registry = { mode = "arena", ref = "m1" } })
		T.expect(m).toBe("arena")
		T.expect(ref).toBe("m1")
		T.expect((mode({ privateServerId = "p", ownerId = 0, registry = { mode = "tournament", ref = "t" } })))
			.toBe("tournament")
		T.expect((mode({ privateServerId = "p", ownerId = 0, registry = { mode = "bogus", ref = "t" } }))).toBe("world")
		local m2, ref2 = mode({
			privateServerId = "p",
			ownerId = 0,
			joinData = { TeleportData = { serverMode = "arena", arenaMatch = "m9" } },
		})
		T.expect(m2).toBe("arena")
		T.expect(ref2).toBe("m9")
		T.expect((mode({ privateServerId = "p", ownerId = 0, joinData = { TeleportData = 5 } }))).toBe("world")
		T.expect((mode({ privateServerId = "p", ownerId = 0, joinData = "x" }))).toBe("world")
	end)

	local function accepted(): ArenaQueue.MatchRecord
		local a = ArenaQueue.newEntry(ticket(1, 1000, 0, 2), "S1")
		local b = ArenaQueue.newEntry(ticket(2, 1000, 0, 1), "S2")
		local r = ArenaQueue.newRecord("m", a, b, "S1", 100, 15, "c", "p")
		r.state = "accepted"
		return r
	end

	T.it("allowed: the record decides", function()
		local r = accepted()
		T.expect(ArenaQueue.allowed(r, 1, 2)).toBe(true)
		T.expect(ArenaQueue.allowed(r, 1, 1)).toBe(false)
		T.expect(ArenaQueue.allowed(r, 3, 1)).toBe(false)
		local cancelled = ArenaQueue.cancel("server", nil)(r)
		T.expect(ArenaQueue.allowed(cancelled, 1, 2)).toBe(false)
	end)

	T.it("arrival", function()
		local r = accepted()
		local status = ArenaQueue.arrival(r, { ["1_2"] = true }, 0, NET.arriveTimeout - 1, NET)
		T.expect(status).toBe("wait")
		T.expect((ArenaQueue.arrival(r, { ["1_2"] = true, ["2_1"] = true }, 0, 5, NET))).toBe("start")
		local late, missing = ArenaQueue.arrival(r, { ["1_2"] = true }, 0, NET.arriveTimeout, NET)
		T.expect(late).toBe("noShow")
		T.expect(missing).toEqual({ "2_1" })
	end)

	T.it("returnPlan", function()
		local n = NET.teleportRetries
		for i = 1, n do
			T.expect(ArenaQueue.returnPlan(i, "job", NET)).toEqual({ kind = "instance", job = "job" })
		end
		for i = n + 1, 2 * n do
			T.expect(ArenaQueue.returnPlan(i, "job", NET).kind).toBe("public")
		end
		T.expect(ArenaQueue.returnPlan(2 * n + 1, "job", NET).kind).toBe("kick")
		T.expect(ArenaQueue.returnPlan(1, nil, NET).kind).toBe("public")
	end)

	T.it("parseMessage", function()
		T.expect(ArenaQueue.parseMessage({ op = "offer", id = "m", jobs = { "a", "b" } })).toEqual({
			op = "offer",
			id = "m",
			jobs = { "a", "b" },
		})
		T.expect(ArenaQueue.parseMessage({ op = "go", id = "m" }) ~= nil).toBe(true)
		T.expect(ArenaQueue.parseMessage({ op = "cancel", id = "m" }) ~= nil).toBe(true)
		T.expect(ArenaQueue.parseMessage({ op = "boom", id = "m" })).toBeNil()
		T.expect(ArenaQueue.parseMessage({ op = "go", id = 5 })).toBeNil()
		T.expect(ArenaQueue.parseMessage({ op = "go", id = string.rep("x", 65) })).toBeNil()
		T.expect(ArenaQueue.parseMessage({ op = "go", id = "m", jobs = "a" })).toBeNil()
	end)

	T.it("scope and localOffer", function()
		T.expect(ArenaQueue.scope({ backendOk = true, studio = true, offlineUntil = 0, now = 10 })).toBe("local")
		T.expect(ArenaQueue.scope({ backendOk = true, studio = false, offlineUntil = 20, now = 10 })).toBe("local")
		T.expect(ArenaQueue.scope({ backendOk = false, studio = false, offlineUntil = 0, now = 10 })).toBe("local")
		T.expect(ArenaQueue.scope({ backendOk = true, studio = false, offlineUntil = 5, now = 10 })).toBe("global")
		T.expect(ArenaQueue.localOffer(44, 45, true)).toBe(false)
		T.expect(ArenaQueue.localOffer(45, 45, true)).toBe(true)
		T.expect(ArenaQueue.localOffer(60, 45, false)).toBe(false)
	end)

	T.it("the local fallback pairs two entries of this server outside the window, marked fallback", function()
		local c, clock = newClock(70000)
		local fake = MemoryFake.new(clock)
		local a = enter(fake, "S1", ticket(1, 1000, c.now - 60))
		enter(fake, "S1", ticket(2, 1900, c.now - 5))
		enter(fake, "S2", ticket(3, 1001, c.now - 5))
		local status, pairing = ArenaQueue.tryPair(fake, a, NET, c.now, newId, "S1", { fallback = true })
		T.expect(status).toBe("local")
		T.expect(pairing.fallback).toBe(true)
		T.expect(pairing.sides[2][1].entrant.key).toBe("2_1")
	end)

	T.it("the local fallback with this server's entries finds a partner a whole-bracket read would miss", function()
		local c, clock = newClock(70000)
		local fake = MemoryFake.new(clock)
		local a = enter(fake, "S1", ticket(1, 2500, c.now - 60))
		local b = enter(fake, "S1", ticket(2, 2400, c.now - 5))
		for i = 1, 3 do
			enter(fake, "S2", ticket(10 + i, 900 + i, c.now - 5))
		end
		local cfg = table.clone(NET)
		cfg.rangeCount = 3 -- the read holds only the three lowest ratings (all of S2)
		local miss = ArenaQueue.tryPair(fake, a, cfg, c.now, newId, "S1", { fallback = true })
		T.expect(miss).toBe("none")
		local status, pairing = ArenaQueue.tryPair(fake, a, cfg, c.now, newId, "S1", {
			fallback = true,
			locals = { ArenaQueue.newEntry(b.ticket, "S1"), ArenaQueue.newEntry(ticket(13, 903, c.now - 5), "S2") },
		})
		T.expect(status).toBe("local")
		T.expect(pairing.fallback).toBe(true)
		T.expect(pairing.sides[2][1].entrant.key).toBe("2_1")
		T.expect(stored(fake, "2_1")).toBe(nil)
	end)

	T.it("the local fallback loses a local entry another organizer claimed", function()
		local c, clock = newClock(70000)
		local fake = MemoryFake.new(clock)
		local a = enter(fake, "S1", ticket(1, 2500, c.now - 60))
		local b = enter(fake, "S1", ticket(2, 2400, c.now - 5))
		fake.update(MAP, b.key, ArenaQueue.claim("other", c.now, NET.claimHold), NET.entryTtl)
		local status = ArenaQueue.tryPair(fake, a, NET, c.now, newId, "S1", {
			fallback = true,
			locals = { ArenaQueue.newEntry(b.ticket, "S1") },
		})
		T.expect(status).toBe("lost")
		T.expect(stored(fake, "1_1").state).toBe("wait")
	end)
end)

T.describe("ArenaQueue H6: the arena_pit map", function()
	T.it("arena_pit: modes, hidden, no links, no world map node, the layout's size", function()
		local pit = Maps.get("arena_pit") :: Maps.MapDef
		T.expect(pit ~= nil).toBe(true)
		T.expect(table.find(pit.serverModes or {}, "arena") ~= nil).toBe(true)
		T.expect(table.find(pit.serverModes or {}, "tournament") ~= nil).toBe(true)
		T.expect(pit.hidden).toBe(true)
		T.expect(#pit.links).toBe(0)
		T.expect(pit.worldMap).toEqual({ x = 0, y = 0 })
		-- S130: the map is as large as the largest layout (the tournament's four fields)
		for _, mode in { "arena", "tournament" } do
			T.expect(pit.size.x >= ArenaPit.layout(mode).size).toBe(true)
		end
	end)

	T.it("every server-mode map has a layout file and is hidden; no world map links to one", function()
		for id, map in Maps.byId do
			if map.serverModes then
				T.expect(fs.isFile(`src/server/World/Layouts/{id}.luau`)).toBe(true)
				T.expect(map.hidden).toBe(true)
			end
		end
		for _, map in Maps.byId do
			for _, link in map.links do
				local target = Maps.get(link)
				T.expect(target == nil or target.serverModes == nil).toBe(true)
			end
		end
	end)

	T.it("the layout fits the map; starts inside the sand and apart; unknown modes fall back", function()
		local layout = ArenaPit.layout("arena")
		T.expect(#layout.fields >= 1).toBe(true)
		-- S130: every layout (the tournament's four fields too)
		for _, mode in { "arena", "tournament" } do
			local l = ArenaPit.layout(mode)
			for _, f in l.fields do
				T.expect(math.abs(f.x) + f.half + f.stands <= l.size / 2).toBe(true)
				T.expect(math.abs(f.z) + f.half + f.stands <= l.size / 2).toBe(true)
				T.expect(#f.starts).toBe(2)
				for _, s in f.starts do
					T.expect(math.abs(s[1]) < f.half and math.abs(s[2]) < f.half).toBe(true)
				end
				local dx, dz = f.starts[1][1] - f.starts[2][1], f.starts[1][2] - f.starts[2][2]
				T.expect(math.sqrt(dx * dx + dz * dz) >= 30).toBe(true)
			end
		end
		T.expect(ArenaPit.layout("tournament") ~= layout).toBe(true)
		T.expect(ArenaPit.layout("nieznany")).toBe(layout)
		T.expect(ArenaPit.field("arena", "pit1") ~= nil).toBe(true)
	end)
end)

T.describe("ArenaQueue H7: wiring of the server modules", function()
	local function has(path: string, text: string)
		if not string.find(fs.readFile(path), text, 1, true) then
			error(`{path}: missing "{text}"`, 0)
		end
	end

	T.it("ServerMode resolves before the loader; the world builds by mode", function()
		local init = fs.readFile("src/server/init.server.luau")
		local a = string.find(init, "ServerMode.resolve()", 1, true)
		local b = string.find(init, "Loader.load(", 1, true)
		T.expect(a ~= nil and b ~= nil and a < b).toBe(true)
		has("src/server/Services/WorldService.luau", "WorldBuilder.build(ServerMode.get())")
		has("src/server/World/WorldBuilder.luau", "serverModes")
		has("src/server/Arena/ServerMode.luau", "PrivateServerOwnerId")
		has("src/server/Arena/ServerMode.luau", "IsStudio")
	end)

	T.it("the Matchmaker pairs through ArenaQueue on a guarded backend with the fake as fallback", function()
		-- S128: 1v1 through tryPair, 3v3 through tryTeams (one call site picks the function)
		has("src/server/Arena/Matchmaker.luau", "ArenaQueue.tryPair")
		has("src/server/Arena/Matchmaker.luau", "ArenaQueue.tryTeams")
		has("src/server/Arena/Matchmaker.luau", "Retry.call")
		has("src/server/Arena/Matchmaker.luau", "pcall")
		has("src/server/Arena/Matchmaker.luau", "MemoryFake")
	end)

	T.it("the location comes back before the profile ends; services stay off on arena servers", function()
		has("src/server/Services/CharacterService.luau", "rt.home")
		has("src/server/Services/NpcService.luau", "ServerMode.isWorld()")
		has("src/server/Services/MonsterService.luau", "ServerMode.isWorld()")
		has("src/server/Services/DuelService.luau", "ServerMode.isWorld()")
		has("src/server/Arena/ArenaHost.luau", "TravelService.AddGuard")
		has("src/server/Arena/ArenaHost.luau", "ArenaService.RunMatch(")
		has("src/server/Services/ArenaService.luau", "AddSource(")
		has("src/server/Services/ArenaService.luau", 'SetHost("remote"')
	end)

	T.it("a server-mode map is never visited nor a map stone target", function()
		local travel = fs.readFile("src/server/Services/TravelService.luau")
		local _, count = string.gsub(travel, 'map%.biome == "dungeon" or map%.serverModes ~= nil then', "")
		T.expect(count).toBe(2) -- MarkVisited and the map stone (toMap)
		has("src/client/UI/Screens/StonePicker.luau", "map.serverModes == nil")
	end)

	T.it("one offer card on the client, one ArenaRespond remote", function()
		local cards = 0
		local function walk(dir: string)
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					walk(path)
				elseif name == "ArenaOffer.luau" then
					cards += 1
				end
			end
		end
		walk("src/client")
		T.expect(cards).toBe(1)
		local defs = fs.readFile("src/shared/Net/Definitions.luau")
		local n = 0
		for _ in string.gmatch(defs, "ArenaRespond%s*=") do
			n += 1
		end
		T.expect(n).toBe(1)
	end)
end)

-- S128 (DESIGN-17 §6): global 3v3 -----------------------------------------------------------------------------------

local MAP3 = ArenaQueue.queueMap("3v3", "40_59")

local function ticket3(userId: number, rating: number, joinedAt: number): ArenaRules.Ticket
	local t = ticket(userId, rating, joinedAt)
	t.mode = "3v3"
	return t
end

local function party3(userIds: { number }, rating: number, joinedAt: number): ArenaRules.Ticket
	local members = {}
	for _, userId in userIds do
		table.insert(members, ticket3(userId, rating, joinedAt).entrant)
	end
	local t = ticket3(userIds[1], rating, joinedAt)
	t.members = members
	return t
end

local function enter3(fake: any, job: string, t: ArenaRules.Ticket): ArenaQueue.Entry
	local entry = ArenaQueue.newEntry(t, job)
	local ok, value = fake.update(MAP3, entry.key, ArenaQueue.put(entry), NET.entryTtl)
	assert(ok, "put failed")
	return value
end

local function stored3(fake: any, key: string): any
	for _, item in fake:items(MAP3) do
		if item.key == key then
			return item.value
		end
	end
	return nil
end

T.describe("ArenaQueue S128 teams", function()
	local function setup()
		local c, clock = newClock(70000)
		local fake = MemoryFake.new(clock)
		return c, fake
	end

	T.it("six solo entries of three servers: one record with two teams of three, every entry claimed", function()
		local c, fake = setup()
		local entries = {}
		for i = 1, 6 do
			table.insert(entries, enter3(fake, `S{(i - 1) % 3 + 1}`, ticket3(i, 1000 + i, c.now - 60 + i)))
		end
		local status, record = ArenaQueue.tryTeams(fake, entries[1], NET, c.now, newId, "S1")
		T.expect(status).toBe("paired")
		T.expect(record.mode).toBe("3v3")
		T.expect(#record.players).toBe(6)
		T.expect(#(record.teams :: any)[1]).toBe(3)
		T.expect(#(record.teams :: any)[2]).toBe(3)
		T.expect(#record.spec.sides[1]).toBe(3)
		for _, e in entries do
			T.expect(stored3(fake, e.key).state).toBe("claimed")
			T.expect(stored3(fake, e.key).match).toBe(record.id)
		end
		T.expect(#records(fake)).toBe(1)
		-- only the oldest entry's server builds it
		local c2, fake2 = setup()
		local later = {}
		for i = 1, 6 do
			table.insert(later, enter3(fake2, `S{i}`, ticket3(i, 1000, c2.now - 60 + i)))
		end
		T.expect((ArenaQueue.tryTeams(fake2, later[3], NET, c2.now, newId, "S3"))).toBe("none")
	end)

	T.it("a party team and three solo entries make a pair; the team stays one entry", function()
		local c, fake = setup()
		local team = enter3(fake, "S1", party3({ 11, 12, 13 }, 1000, c.now - 50))
		T.expect(team.size).toBe(3)
		for i = 1, 3 do
			enter3(fake, "S2", ticket3(i, 1000, c.now - 40 + i))
		end
		local status, record = ArenaQueue.tryTeams(fake, team, NET, c.now, newId, "S1")
		T.expect(status).toBe("paired")
		T.expect(#record.players).toBe(6)
		T.expect(#ArenaQueue.playersOfEntry(record, team.key)).toBe(3)
		local jobs = {}
		for _, p in record.players do
			jobs[p.jobId] = true
		end
		T.expect(jobs).toEqual({ S1 = true, S2 = true })
	end)

	T.it("one entry taken by another server: lost, every other entry waits again with its old joinedAt", function()
		local c, fake = setup()
		local entries = {}
		for i = 1, 6 do
			table.insert(entries, enter3(fake, `S{i}`, ticket3(i, 1000, c.now - 60 + i)))
		end
		local victim = entries[5].key
		local fired = false
		fake:onBeforeCommit(function(map, key)
			if not fired and map == MAP3 and key == victim then
				fired = true
				fake.update(MAP3, victim, ArenaQueue.claim("other", c.now, NET.claimHold), NET.entryTtl)
			end
		end)
		local status = ArenaQueue.tryTeams(fake, entries[1], NET, c.now, newId, "S1")
		fake:onBeforeCommit(nil)
		T.expect(status).toBe("lost")
		for i, e in entries do
			local now = stored3(fake, e.key)
			if e.key == victim then
				T.expect(now.match).toBe("other")
			else
				T.expect({ i, now.state, now.ticket.joinedAt }).toEqual({ i, "wait", e.ticket.joinedAt })
			end
		end
		T.expect(#records(fake)).toBe(0)
	end)

	T.it("two servers interleaved: exactly one record", function()
		local c, fake = setup()
		local entries = {}
		for i = 1, 6 do
			table.insert(entries, enter3(fake, `S{i}`, ticket3(i, 1000, c.now - 60)))
		end
		local inner: string? = nil
		local fired = false
		fake:onBeforeCommit(function(map, key)
			if not fired and map == MAP3 and key == entries[4].key then
				fired = true
				inner =
					ArenaQueue.tryTeams(fake, stored3(fake, entries[2].key), NET, c.now, newId, "S2", { force = true })
			end
		end)
		local outer = ArenaQueue.tryTeams(fake, entries[1], NET, c.now, newId, "S1", { force = true })
		fake:onBeforeCommit(nil)
		T.expect(#records(fake)).toBe(1)
		T.expect((outer == "paired") ~= (inner == "paired")).toBe(true)
	end)

	T.it("all six on this server: a local pairing, nothing reserved, entries removed", function()
		local c, fake = setup()
		local entries = {}
		for i = 1, 6 do
			table.insert(entries, enter3(fake, "S1", ticket3(i, 1000, c.now - 60 + i)))
		end
		local status, pairing = ArenaQueue.tryTeams(fake, entries[1], NET, c.now, newId, "S1")
		T.expect(status).toBe("local")
		T.expect(#pairing.sides).toBe(2)
		T.expect(#records(fake)).toBe(0)
		for _, e in entries do
			T.expect(stored3(fake, e.key)).toBeNil()
		end
	end)

	T.it("a refusal of six: the refuser alone is penalized, the others go back", function()
		local c, fake = setup()
		local entries = {}
		for i = 1, 6 do
			table.insert(entries, enter3(fake, `S{i}`, ticket3(i, 1000, c.now - 60 + i)))
		end
		local _, record = ArenaQueue.tryTeams(fake, entries[1], NET, c.now, newId, "S1")
		local key = ArenaQueue.matchKey(record.id)
		for i = 1, 5 do
			fake.hupdate(NET.matchMap, key, ArenaQueue.respond(entries[i].key, true, c.now), NET.matchTtl)
		end
		local _, after = fake.hupdate(NET.matchMap, key, ArenaQueue.respond(entries[6].key, false, c.now), NET.matchTtl)
		T.expect(after.state).toBe("cancelled")
		T.expect(after.by).toBe(entries[6].key)
		for i, e in entries do
			local want = if i == 6 then "penalty" else "requeue"
			T.expect({ i, ArenaQueue.entryAfter(after, e.key, nil, c.now) }).toEqual({ i, want })
		end
		-- a party team: a member's refusal takes the whole team out, the penalty only for that member
		local members = { "11_1", "12_1", "13_1" }
		local cancelled = { state = "cancelled", reason = "declined", by = "12_1", players = {}, id = "x" }
		T.expect({ ArenaQueue.entryAfterTeam(cancelled, "11_1", members, c.now) }).toEqual({ "penalty", { "12_1" } })
		local other = { state = "cancelled", reason = "declined", by = "99_1", players = {}, id = "x" }
		T.expect({ ArenaQueue.entryAfterTeam(other, "11_1", members, c.now) }).toEqual({ "requeue" } :: any)
		-- all six accepted
		local c2, fake2 = setup()
		local es = {}
		for i = 1, 6 do
			table.insert(es, enter3(fake2, `S{i}`, ticket3(i, 1000, c2.now - 60 + i)))
		end
		local _, r2 = ArenaQueue.tryTeams(fake2, es[1], NET, c2.now, newId, "S1")
		local last: any = nil
		for i = 1, 6 do
			local _, a = fake2.hupdate(
				NET.matchMap,
				ArenaQueue.matchKey(r2.id),
				ArenaQueue.respond(es[i].key, true, c2.now),
				NET.matchTtl
			)
			last = a
		end
		T.expect(last.state).toBe("accepted")
	end)

	T.it("the local fallback: this server's entries, any rating, without the oldest-initiates check", function()
		local c, fake = setup()
		local entries = {}
		for i = 1, 6 do
			-- ratings far apart (outside every window), one more entry of another server
			table.insert(entries, enter3(fake, "S1", ticket3(i, 1000 + 400 * i, c.now - 60 + i)))
		end
		enter3(fake, "S2", ticket3(7, 1000, c.now - 100))
		local me = entries[6]
		T.expect((ArenaQueue.tryTeams(fake, me, NET, c.now, newId, "S1"))).toBe("none")
		local locals = {}
		for i = 1, 5 do
			table.insert(locals, ArenaQueue.newEntry(entries[i].ticket, "S1"))
		end
		local status, pairing =
			ArenaQueue.tryTeams(fake, me, NET, c.now, newId, "S1", { fallback = true, locals = locals })
		T.expect(status).toBe("local")
		T.expect(pairing.fallback).toBe(true)
		local keys = {}
		for _, side in pairing.sides do
			for _, t in side do
				keys[t.entrant.key] = true
			end
		end
		T.expect(keys["7_1"]).toBeNil()
		for _, e in entries do
			T.expect(keys[e.key]).toBe(true)
		end
	end)

	T.it("a timeout of six: every player without an answer is penalized, the others go back", function()
		local c, fake = setup()
		local entries = {}
		for i = 1, 6 do
			table.insert(entries, enter3(fake, `S{i}`, ticket3(i, 1000, c.now - 60 + i)))
		end
		local _, record = ArenaQueue.tryTeams(fake, entries[1], NET, c.now, newId, "S1")
		local key = ArenaQueue.matchKey(record.id)
		for i = 1, 4 do
			fake.hupdate(NET.matchMap, key, ArenaQueue.respond(entries[i].key, true, c.now), NET.matchTtl)
		end
		local _, after = fake.hupdate(NET.matchMap, key, ArenaQueue.expire(record.acceptBy + 1, NET), NET.matchTtl)
		T.expect(after.state).toBe("cancelled")
		T.expect(after.reason).toBe("timeout")
		T.expect(#after.silent).toBe(2)
		for i, e in entries do
			local want = if i >= 5 then "penalty" else "requeue"
			T.expect({ i, ArenaQueue.entryAfter(after, e.key, nil, c.now) }).toEqual({ i, want })
		end
		-- a party team with two silent members: both penalized, the team out
		local members = { "11_1", "12_1", "13_1" }
		local timedOut = {
			state = "cancelled",
			reason = "timeout",
			by = "12_1",
			silent = { "12_1", "13_1" },
			players = {},
			id = "x",
		}
		T.expect({ ArenaQueue.entryAfterTeam(timedOut, "11_1", members, c.now) }).toEqual({
			"penalty",
			{ "12_1", "13_1" },
		})
	end)

	T.it("arrival of five of six after the time: noShow with the missing one", function()
		local c, fake = setup()
		local entries = {}
		for i = 1, 6 do
			table.insert(entries, enter3(fake, `S{i}`, ticket3(i, 1000, c.now - 60 + i)))
		end
		local _, record = ArenaQueue.tryTeams(fake, entries[1], NET, c.now, newId, "S1")
		local present = {}
		for i = 1, 5 do
			present[entries[i].key] = true
		end
		T.expect({ ArenaQueue.arrival(record, present, c.now, c.now + 1, NET) }).toEqual({ "wait", { entries[6].key } })
		T.expect({ ArenaQueue.arrival(record, present, c.now, c.now + NET.arriveTimeout, NET) }).toEqual({
			"noShow",
			{ entries[6].key },
		})
	end)

	T.it("the 3v3 starts of the pit lie on the sand", function()
		local pit = Arena.venue("pit") :: Arena.Venue
		for side = 1, 2 do
			T.expect(#pit.sides[side]).toBe(3)
			for i = 1, 3 do
				local x, z = ArenaRules.spot(pit, side, i)
				T.expect(ArenaRules.inside(pit, x, z)).toBe(true)
			end
		end
	end)
end)
