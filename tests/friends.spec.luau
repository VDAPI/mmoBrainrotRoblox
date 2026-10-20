--!strict
-- S150 friends 2.0: presence across servers (Logic/Presence on Logic/MemoryFake with the test's clock and two
-- "servers"), the read budget and the shared cache, "Join" (Logic/FriendJoin.canJoin), party invitations through one
-- topic and the arrival into the inviter's party; the friendJoin blocks (Logic/UseBlocks) and their texts.

local fs = require("@lune/fs")

local Config = require("../src/shared/Config")
local FriendJoin = require("../src/shared/Logic/FriendJoin")
local MemoryFake = require("../src/shared/Logic/MemoryFake")
local Presence = require("../src/shared/Logic/Presence")
local T = require("./Test")
local UseBlocks = require("../src/shared/Logic/UseBlocks")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local F = Config.Friends

type Clock = { now: number }

local function newClock(start: number?): (Clock, () -> number)
	local c: Clock = { now = start or 1000000 }
	return c, function()
		return c.now
	end
end

local function backendOf(fake: any): Presence.Backend
	return { hget = fake.hget, hupdate = fake.hupdate, hremove = fake.hremove }
end

local function rec(fields: { [string]: any }): Presence.Record
	local base: any = { j = "job-A", m = "world", t = 1000000, pj = "friends", map = "town", lvl = 40, name = "Borys" }
	for k, v in fields do
		base[k] = v
	end
	return Presence.record(base)
end

local function view(extra: { [string]: any }?): FriendJoin.View
	local base: any = { friend = true, ignored = false, status = "world", pj = "friends", hereMode = "world" }
	for k, v in extra or {} do
		base[k] = v
	end
	return base
end

T.describe("S150 Presence: entries across servers", function()
	T.it("an entry written on one server is read on another and expires after the TTL", function()
		local c, clock = newClock()
		local fake = MemoryFake.new(clock)
		local serverA = Presence.reader(backendOf(fake), clock, { cacheSeconds = 0 })
		local serverB = Presence.reader(backendOf(fake), clock, { cacheSeconds = 0 })
		T.expect(serverA.write(42, rec({ t = c.now }))).toBe(true)
		local state, entry = serverB.read(42, "window")
		T.expect(state).toBe("ok")
		T.expect(entry and entry.name).toBe("Borys")
		T.expect(Presence.statusOf(entry, "job-B", c.now)).toBe("world")
		T.expect(Presence.statusOf(entry, "job-A", c.now)).toBe("here")
		c.now += F.presenceTtl + 1
		local after, gone = serverB.read(42, "window")
		T.expect(after).toBe("ok")
		T.expect(gone).toBeNil()
		T.expect(Presence.statusOf(gone, "job-B", c.now)).toBe("offline")
	end)

	T.it("an invisible player has no entry (removed at once)", function()
		local c, clock = newClock()
		local fake = MemoryFake.new(clock)
		local serverA = Presence.reader(backendOf(fake), clock, { cacheSeconds = 0 })
		local serverB = Presence.reader(backendOf(fake), clock, { cacheSeconds = 0 })
		serverA.write(7, rec({ t = c.now }))
		T.expect(serverA.remove(7)).toBe(true)
		local _, entry = serverB.read(7, "window")
		T.expect(entry).toBeNil()
		T.expect(Presence.statusOf(entry, "job-B", c.now)).toBe("offline")
	end)

	T.it("statusOf: here, world, private, arena, tournament, offline, unknown", function()
		local now = 1000000
		T.expect(Presence.statusOf(rec({}), "job-A", now)).toBe("here")
		T.expect(Presence.statusOf(rec({}), "job-B", now)).toBe("world")
		T.expect(Presence.statusOf(rec({ p = true }), "job-B", now)).toBe("private")
		T.expect(Presence.statusOf(rec({ m = "arena", p = true }), "job-B", now)).toBe("arena")
		T.expect(Presence.statusOf(rec({ m = "tournament" }), "job-B", now)).toBe("tournament")
		T.expect(Presence.statusOf(rec({ t = now - F.presenceTtl - 1 }), "job-B", now)).toBe("offline")
		T.expect(Presence.statusOf(nil, "job-B", now)).toBe("offline")
		T.expect(Presence.statusOf(false, "job-B", now)).toBe("unknown")
	end)

	T.it("a failed read is unknown, never an error", function()
		local c, clock = newClock()
		local fake = MemoryFake.new(clock)
		local reader = Presence.reader(backendOf(fake), clock, { cacheSeconds = 0 })
		reader.write(42, rec({ t = c.now }))
		fake:fail("hget", 1)
		local state, entry = reader.read(42, "window")
		T.expect(state).toBe("fail")
		T.expect(entry).toBeNil()
		T.expect(Presence.statusOf(if state == "fail" then false else entry, "job-B", c.now)).toBe("unknown")
	end)

	T.it("parse drops garbage and S133 entries of the old map", function()
		T.expect(Presence.parse({ j = "x", t = 1, m = "town", l = 5 })).toBeNil()
		T.expect(Presence.parse("x")).toBeNil()
		local parsed = Presence.parse({ j = "x", t = 1, m = "arena", pj = "weird", lvl = "5" }) :: Presence.Record
		T.expect(parsed.pj).toBe("none")
		T.expect(parsed.lvl).toBeNil()
		T.expect(Presence.record({ j = "x", m = "moon", t = 1 }).m).toBe("world")
	end)

	T.it("label: key and arguments of the row", function()
		local key, args = Presence.label("world", rec({ map = "meadows", lvl = 33 }))
		T.expect(key).toBe("friends.status.world")
		T.expect(args).toEqual({ map = "meadows", lvl = 33 })
		for _, status in { "here", "world", "private", "arena", "tournament", "offline", "unknown" } do
			local k = Presence.label(status :: any, nil)
			T.expect({ k, pl[k] ~= nil, en[k] ~= nil }).toEqual({ k, true, true })
		end
	end)

	T.it("serverTag: four fixed characters, the same for one job, different for others", function()
		local a = Presence.serverTag("0f2a6c3e-1111-4a4a-9b9b-aaaaaaaaaaaa")
		T.expect(#a).toBe(4)
		T.expect(Presence.serverTag("0f2a6c3e-1111-4a4a-9b9b-aaaaaaaaaaaa")).toBe(a)
		local seen: { [string]: boolean } = {}
		local distinct = 0
		for i = 1, 50 do
			local tag = Presence.serverTag(`job-{i}-{i * 7919}`)
			T.expect(string.match(tag, "^[A-Z2-9][A-Z2-9][A-Z2-9][A-Z2-9]$") ~= nil).toBe(true)
			if not seen[tag] then
				seen[tag] = true
				distinct += 1
			end
		end
		T.expect(distinct >= 48).toBe(true)
	end)

	T.it("sort order: here, world servers, private, arena and tournament, unknown, offline", function()
		local O = Presence.ORDER
		T.expect(O.here < O.world and O.world < O.private and O.private < O.arena).toBe(true)
		T.expect(O.arena == O.tournament and O.tournament < O.unknown and O.unknown < O.offline).toBe(true)
	end)
end)

T.describe("S150 Presence: read budget and shared cache", function()
	T.it("a second viewer of the same friend reads from the cache without a token", function()
		local c, clock = newClock()
		local fake = MemoryFake.new(clock)
		local budget = Presence.budget(10, clock, 0.25)
		local reader = Presence.reader(backendOf(fake), clock, { budget = budget, cacheSeconds = 20 })
		reader.write(42, rec({ t = c.now }))
		reader.read(42, "window")
		local before = budget.stats()
		local state = reader.read(42, "window")
		local after = budget.stats()
		T.expect(state).toBe("ok")
		T.expect(after.tokens).toBe(before.tokens)
		T.expect(after.hits).toBe(before.hits + 1)
		T.expect(fake.calls.hget).toBe(1)
		c.now += 21
		reader.read(42, "window")
		T.expect(fake.calls.hget).toBe(2)
	end)

	T.it("without tokens a row waits with its last state; other reads leave a reserve to windows", function()
		local c, clock = newClock()
		local fake = MemoryFake.new(clock)
		local budget = Presence.budget(8, clock, 0.25)
		local reader = Presence.reader(backendOf(fake), clock, { budget = budget, cacheSeconds = 0 })
		for i = 1, 8 do
			T.expect(reader.read(i, "window")).toBe("ok")
		end
		T.expect(reader.read(9, "window")).toBe("wait")
		T.expect(budget.stats().denied).toBe(1)
		-- a join check still reads (it is rare and counted)
		T.expect(reader.read(10, "join")).toBe("ok")
		c.now += 30 -- 4 tokens back
		T.expect(budget.stats().tokens).toBe(4)
		-- Roblox friends ("other") need more than the reserve of 2 tokens
		T.expect(budget.take("other")).toBe(true)
		T.expect(budget.take("other")).toBe(true)
		T.expect(budget.take("other")).toBe(false)
		T.expect(budget.take("window")).toBe(true)
		c.now += 61
		T.expect(budget.stats().reads).toBe(0)
	end)

	T.it("estimate of a full server stays within the platform quota", function()
		-- 40 players, a quarter with the window open, 50 friends each, refreshed every refreshEvery seconds; every
		-- player's entry written every presenceEvery seconds; the per-server budget caps the reads
		local players, watching, friends = 40, 10, 50
		local wanted = watching * friends * 60 / F.refreshEvery
		local reads = math.min(wanted, F.readsPerMinute)
		local writes = players * 60 / F.presenceEvery
		local quotaShare = 120 * players -- the per-user part of 1000 + 120 x CCU that this server brings
		T.expect(reads + writes <= quotaShare).toBe(true)
		T.expect(F.readsPerMinute <= 1000 / 2).toBe(true)
	end)
end)

T.describe("S150 FriendJoin.canJoin", function()
	T.it("joins a friend on another public world server", function()
		T.expect(FriendJoin.canJoin(view(), 100)).toBe(true)
	end)

	T.it("every reason, in order", function()
		local function why(extra: { [string]: any }): string?
			local _, reason = FriendJoin.canJoin(view(extra), 100)
			return reason
		end
		T.expect(why({ friend = false })).toBe("friends.join.notFriend")
		-- an ignored pair hears "offline": the ignore stays secret
		T.expect(why({ ignored = true })).toBe("friends.join.offline")
		T.expect(why({ status = "offline" })).toBe("friends.join.offline")
		T.expect(why({ status = "unknown" })).toBe("friends.join.unknown")
		T.expect(why({ status = "arena" })).toBe("friends.join.arena")
		T.expect(why({ status = "tournament" })).toBe("friends.join.tournament")
		T.expect(why({ status = "private" })).toBe("friends.join.private")
		T.expect(why({ status = "here" })).toBe("friends.join.sameServer")
		T.expect(why({ pj = "none" })).toBe("friends.join.closed")
		T.expect(why({ hereMode = "arena" })).toBe("friends.join.notHere")
		T.expect(why({ block = "dead" })).toBe("friends.block.dead")
		T.expect(why({ block = "worldBoss" })).toBe("friends.block.worldBoss")
		T.expect(why({ cooldownUntil = 160 })).toBe("friends.join.cooldown")
		T.expect(why({ cooldownUntil = 100 })).toBeNil()
	end)

	T.it("the inviter's view of another server", function()
		T.expect(FriendJoin.canInvite(view())).toBe(true)
		T.expect(FriendJoin.canInvite(view({ status = "private" }))).toBe(true)
		T.expect(select(2, FriendJoin.canInvite(view({ status = "arena" })))).toBe("friends.join.arena")
		T.expect(select(2, FriendJoin.canInvite(view({ pj = "none" })))).toBe("friends.join.closed")
		T.expect(select(2, FriendJoin.canInvite(view({ hereMode = "tournament" })))).toBe("friends.party.notHere")
		T.expect(select(2, FriendJoin.canInvite(view({ ignored = true })))).toBe("friends.join.offline")
	end)

	T.it("an inviter whom the friend could not join cannot invite from another server (only here)", function()
		-- accepting is canJoin against the inviter: a private server, appearing offline or "nobody" always fail
		T.expect(select(2, FriendJoin.canInvite(view({ selfPrivate = true })))).toBe("friends.party.private")
		T.expect(select(2, FriendJoin.canInvite(view({ selfHidden = true })))).toBe("friends.party.invisible")
		T.expect(select(2, FriendJoin.canInvite(view({ selfPj = "none" })))).toBe("friends.party.closedSelf")
		T.expect(FriendJoin.canInvite(view({ selfPj = "friends", selfHidden = false, selfPrivate = false }))).toBe(true)
		T.expect(FriendJoin.canInvite(view({ status = "here", selfHidden = true, selfPj = "none" }))).toBe(true)
		-- the inviter's side does not change their own Join
		T.expect(FriendJoin.canJoin(view({ selfHidden = true, selfPj = "none", selfPrivate = true }), 100)).toBe(true)
	end)

	T.it("teleport failures by result", function()
		T.expect(FriendJoin.failKey("GameFull")).toBe("friends.join.full")
		T.expect(FriendJoin.failKey("GameNotFound")).toBe("friends.join.gone")
		T.expect(FriendJoin.failKey("GameEnded")).toBe("friends.join.gone")
		T.expect(FriendJoin.failKey("Flooded")).toBe("friends.join.failed")
		T.expect(FriendJoin.failKey("")).toBe("friends.join.failed")
		for _, key in { "friends.join.full", "friends.join.gone", "friends.join.failed", "friends.join.studio" } do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)
end)

T.describe("S150 party invitations through one topic", function()
	-- Two "servers" on one fake: each keeps the invitations shown to its own players.
	local function server(fake: any, players: { [number]: { ignores: { [number]: boolean }?, pj: string? } }, clock)
		local shown: { FriendJoin.Invite } = {}
		fake:subscribe(function(message: { [string]: any })
			local invite = FriendJoin.parseInvite(message)
			if not invite then
				return
			end
			local p = players[invite.to]
			local ok = FriendJoin.acceptInvite(invite, {
				here = p ~= nil,
				ignoresSender = p ~= nil and p.ignores ~= nil and p.ignores[invite.from] == true,
				pj = if p then p.pj or "friends" else nil,
			}, clock())
			if ok then
				table.insert(shown, invite)
			end
		end)
		return shown
	end

	T.it("the addressee on the other server gets it, nobody else; expired, ignoring and closed are dropped", function()
		local c, clock = newClock()
		local fake = MemoryFake.new(clock)
		local onA = server(fake, { [1] = {} }, clock)
		local onB = server(fake, { [2] = {}, [3] = { ignores = { [1] = true } }, [4] = { pj = "none" } }, clock)
		local function send(to: number, seconds: number?)
			local message = FriendJoin.inviteMessage({
				to = to,
				from = 1,
				name = "Borys",
				lvl = 40,
				cls = "Warrior",
				j = "job-A",
				now = c.now,
				seconds = seconds,
			})
			fake.publish(message :: any)
			return message
		end
		local message = send(2)
		T.expect(message.exp).toBe(c.now + F.inviteSeconds)
		T.expect(#onB).toBe(1)
		T.expect(onB[1].to).toBe(2)
		T.expect(#onA).toBe(0)
		send(3)
		send(4)
		send(99)
		T.expect(#onB).toBe(1)
		send(2, 0) -- already expired
		T.expect(#onB).toBe(1)
		-- far below the 1 KiB message limit
		T.expect(#`{message.to}{message.from}{message.name}{message.lvl}{message.cls}{message.j}{message.exp}` < 200)
			.toBe(true)
	end)

	T.it("at most invitesPerMinute per sender in any minute", function()
		local limiter = FriendJoin.limiter(3)
		T.expect(limiter.allow(1, 100)).toBe(true)
		T.expect(limiter.allow(1, 110)).toBe(true)
		T.expect(limiter.allow(1, 120)).toBe(true)
		T.expect(limiter.allow(1, 130)).toBe(false)
		T.expect(limiter.allow(2, 130)).toBe(true)
		T.expect(limiter.allow(1, 161)).toBe(true)
		T.expect(F.invitesPerMinute).toBe(3)
	end)

	T.it("arrival: the leader here with room joins the party; otherwise the invitation expired", function()
		local data = FriendJoin.teleportData("friendParty", 1, 500)
		local base = { inviteKnown = true, leaderHere = true, canLead = true, size = 2, max = 5 }
		T.expect(FriendJoin.arrival(data, base)).toBe("join")
		local function with(extra: { [string]: any }): string
			local ctx: any = table.clone(base)
			for k, v in extra do
				ctx[k] = v
			end
			return FriendJoin.arrival(data, ctx)
		end
		T.expect(with({ size = 5 })).toBe("expired")
		T.expect(with({ leaderHere = false })).toBe("expired")
		T.expect(with({ canLead = false })).toBe("expired")
		T.expect(with({ inviteKnown = false })).toBe("expired")
		T.expect(FriendJoin.arrival(FriendJoin.teleportData("friend", 1), base)).toBe("none")
		T.expect(FriendJoin.arrival(nil, base)).toBe("none")
	end)
end)

T.describe("S150 UseBlocks friendJoin", function()
	T.it("the list and the text of every reason", function()
		T.expect(UseBlocks.LISTS.friendJoin).toEqual({
			"dead",
			"duel",
			"arena",
			"dungeon",
			"pvpLock",
			"bloodMoon",
			"tourney",
			"trade",
			"combat",
			"worldBoss",
		})
		T.expect(UseBlocks.key("friendJoin", "trade")).toBe("friends.block.trade")
		T.expect(FriendJoin.blockKey("combat")).toBe("friends.block.combat")
		for _, reason in UseBlocks.LISTS.friendJoin do
			local key = FriendJoin.blockKey(reason)
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)

	T.it("the new reasons are registered by the services that know them", function()
		local owners = {
			trade = "src/server/Services/TradeService.luau",
			combat = "src/server/Services/ResourceService.luau",
			worldBoss = "src/server/Services/WorldBossService.luau",
		}
		for reason, path in owners do
			local text = fs.readFile(path)
			T.expect({ reason, string.find(text, `UseGuards.register("{reason}"`, 1, true) ~= nil })
				.toEqual({ reason, true })
		end
	end)
end)

T.describe("S150 wiring", function()
	T.it("remotes have types and limits; FriendsStatus is gone", function()
		local Definitions = require("../src/shared/Net/Definitions")
		local defs: any = Definitions
		T.expect(defs.FriendJoin).toEqual({ kind = "function", dir = "c2s", rate = 0.2, args = { "integer" } })
		T.expect(defs.FriendPartyInvite).toEqual({ kind = "function", dir = "c2s", rate = 0.2, args = { "integer" } })
		T.expect(defs.FriendsWatch).toEqual({ kind = "event", dir = "c2s", rate = 2, args = { "boolean" } })
		T.expect(defs.FriendsRobloxHint.args).toEqual({ "table" })
		T.expect(defs.FriendPartyRespond.args).toEqual({ "boolean" })
		T.expect(defs.FriendsStatus).toBeNil()
	end)

	T.it("one presence writer and one cross-server module", function()
		local service = fs.readFile("src/server/Services/FriendService.luau")
		T.expect(string.find(service, "Presence.write(", 1, true) ~= nil).toBe(true)
		T.expect(string.find(service, "Transfer.toServer(", 1, true) ~= nil).toBe(true)
		T.expect(fs.isFile("src/server/Social/Presence.luau")).toBe(false)
		local social = fs.readFile("src/server/Services/SocialService.luau")
		T.expect(string.find(social, "Presence.write", 1, true)).toBeNil()
		T.expect(string.find(social, "appearOffline", 1, true) ~= nil).toBe(true)
	end)
end)
