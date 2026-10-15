--!strict
-- Ranked arena (S126, DESIGN-17 §6): Data/Arena, Logic/Elo and Logic/ArenaRules. Only pure modules: the server
-- (ArenaService, src/server/Arena) calls these functions for every rule it applies.

local Arena = require("../src/shared/Data/Arena")
local ArenaRules = require("../src/shared/Logic/ArenaRules")
local Elo = require("../src/shared/Logic/Elo")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")
local Town = require("../src/shared/Data/Town")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local MODE = Arena.MODES["1v1"]
local DAY = 20758

local function entrant(key: string, userId: number, rating: number): ArenaRules.Entrant
	return {
		key = key,
		userId = userId,
		slot = 1,
		name = key,
		class = "Warrior",
		level = 45,
		rating = rating,
		played = 0,
	}
end

local function ticket(
	key: string,
	userId: number,
	rating: number,
	joinedAt: number,
	bracket: string?
): ArenaRules.Ticket
	return { entrant = entrant(key, userId, rating), mode = "1v1", bracket = bracket or "40_59", joinedAt = joinedAt }
end

local function keysOf(pairs: { ArenaRules.Pairing }): { string }
	local out = {}
	for _, p in pairs do
		table.insert(out, `{p.sides[1][1].entrant.key}+{p.sides[2][1].entrant.key}`)
	end
	return out
end

local function fighter(key: string, hpPct: number, down: boolean?, left: boolean?): ArenaRules.Fighter
	return { key = key, hpPct = hpPct, down = down == true, left = left == true }
end

local function input(over: { [string]: any }?): ArenaRules.ResultInput
	local base: any = {
		mode = MODE,
		season = "202611",
		day = DAY,
		now = DAY * 86400 + 100,
		myKey = "1_1",
		oppKeys = { "2_1" },
		oppRating = 1000,
		oppName = "Rival",
		oppClass = "Mage",
		score = 1,
		rounds = "2:0",
		rated = true,
	}
	for k, v in over or {} do
		base[k] = v
	end
	return base
end

local function state(over: { [string]: any }?): ArenaRules.ArenaState
	local s: any = ArenaRules.emptyState()
	s.season = "202611"
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

T.describe("Arena data (S126)", function()
	T.it("has continuous brackets from MIN_LEVEL to 100 with the shared ids", function()
		local ids = {}
		local next = Arena.MIN_LEVEL
		for _, b in Arena.BRACKETS do
			T.expect(b.min).toBe(next)
			T.expect(b.max >= b.min).toBe(true)
			next = b.max + 1
			table.insert(ids, b.id)
		end
		T.expect(next).toBe(101)
		T.expect(ids).toEqual({ "20_39", "40_59", "60_79", "80_100" })
		T.expect(Arena.MIN_LEVEL).toBe(20)
	end)

	T.it("keeps the 1v1 rules of the contract", function()
		T.expect(MODE.winsNeeded).toBe(2)
		T.expect(MODE.maxRounds).toBe(3)
		T.expect(MODE.roundTime).toBe(180)
		T.expect(MODE.potions).toBe(3)
		T.expect(MODE.teamSize).toBe(1)
		T.expect(MODE.ratingField).toBe("rating")
		T.expect(MODE.board).toBe("arena")
		for _, id in Arena.MODE_ORDER do
			local mode = Arena.MODES[id]
			T.expect(mode ~= nil).toBe(true)
			T.expect(mode.id).toBe(id)
			T.expect(type(mode.ratingField)).toBe("string")
			T.expect(string.find(mode.board, "_", 1, true)).toBeNil()
		end
		T.expect(Arena.mode("1v1")).toBe(MODE)
		T.expect(Arena.mode("3v3")).toBeNil()
		T.expect((Arena.bracket("40_59") :: any).min).toBe(40)
	end)

	T.it("keeps Elo, tiers and the queue window of the contract", function()
		local e = Arena.ELO
		T.expect({ e.start, e.k, e.kNew, e.newGames, e.floor }).toEqual({ 1000, 32, 48, 10, 0 })
		local mins = {}
		for i, tier in Arena.TIERS do
			table.insert(mins, tier.min)
			if i > 1 then
				T.expect(tier.min > Arena.TIERS[i - 1].min).toBe(true)
			end
			T.expect(pl[`arena.tier.{tier.id}`] ~= nil).toBe(true)
			T.expect(en[`arena.tier.{tier.id}`] ~= nil).toBe(true)
		end
		T.expect(mins).toEqual({ 0, 1100, 1300, 1500, 1700 })
		T.expect(Arena.QUEUE.window).toBe(100)
		T.expect(Arena.QUEUE.widen).toBe(100)
		T.expect(Arena.QUEUE.widenEvery).toBe(15)
		T.expect(Arena.LIMITS.sameOpponentDaily).toBe(3)
	end)

	T.it("places the Ristalle spots on the sand and the seats on the full stands", function()
		local venue = Arena.VENUES.ristalle
		local plan = Town.city.arena
		T.expect(venue.map).toBe("city")
		for i = 1, 2 do
			T.expect(venue.sides[i][1]).toEqual({ plan.duel[i][1], plan.duel[i][2] })
			for _, p in venue.sides[i] do
				T.expect(ArenaRules.inside(venue, p[1], p[2], 4)).toBe(true)
			end
		end
		-- the two sides stand on opposite sides of the centre
		local a = venue.sides[1][1][1] - venue.center[1]
		local b = venue.sides[2][1][1] - venue.center[1]
		T.expect(a * b < 0).toBe(true)
		for _, p in venue.stands do
			T.expect(ArenaRules.inside(venue, p[1], p[2])).toBe(false)
			local dx = math.abs(p[1] - venue.center[1])
			local dz = math.abs(p[2] - venue.center[2])
			-- the full stands are the x-axis sides (Logic/TownGen/Specials: the gates are on the z-axis sides)
			T.expect(dx > plan.half and dx < plan.half + plan.stands).toBe(true)
			T.expect(dz < plan.half).toBe(true)
			-- the lord's box sits on the west stand around the centre line
			T.expect(dz >= 12).toBe(true)
		end
		T.expect(venue.exit).toEqual({ plan.exit[1], plan.exit[2] })
		local x, z = ArenaRules.standSpot(venue, 5)
		T.expect({ x, z }).toEqual(venue.stands[1])
		local sx, sz = ArenaRules.spot(venue, 2, 1)
		T.expect({ sx, sz }).toEqual(venue.sides[2][1])
	end)
end)

T.describe("Arena rules (S126)", function()
	T.it("puts levels in brackets", function()
		local cases = {
			{ 1, nil },
			{ 19, nil },
			{ 20, "20_39" },
			{ 39, "20_39" },
			{ 40, "40_59" },
			{ 79, "60_79" },
			{ 80, "80_100" },
			{ 100, "80_100" },
		}
		for _, c in cases do
			T.expect({ c[1], ArenaRules.bracketOf(c[1] :: number) }).toEqual({ c[1], c[2] })
		end
	end)

	T.it("counts seasons by the UTC month", function()
		for _, t in { 0, 1793491199, 1793491200, 1798761600, 1800000000 } do
			T.expect(ArenaRules.seasonOf(t)).toBe(Time.monthKey(t))
		end
		T.expect(ArenaRules.seasonOf(1793491199)).toBe("202610")
		T.expect(ArenaRules.seasonOf(1793491200)).toBe("202611")
		T.expect(ArenaRules.seasonOf(1798761600)).toBe("202701")
		T.expect(ArenaRules.seasonStart("202611")).toBe(1793491200)
		T.expect(ArenaRules.seasonEndsAt("202611")).toBe(ArenaRules.seasonStart("202612"))
		T.expect(ArenaRules.seasonStart("202701")).toBe(1798761600)
		T.expect(ArenaRules.prevSeason("202701")).toBe("202612")
		T.expect(ArenaRules.nextSeason("202612")).toBe("202701")
		T.expect(ArenaRules.boardId(MODE, "202611", "40_59")).toBe("arena_202611_40_59")
	end)

	T.it("computes Elo", function()
		T.expect(Elo.expected(1200, 1000) + Elo.expected(1000, 1200)).toBeNear(1, 1e-9)
		T.expect(Elo.delta(1000, 1000, 1, 32)).toBe(16)
		T.expect(Elo.delta(1000, 1000, 1, 48)).toBe(24)
		T.expect(Elo.delta(1000, 1000, 0, 32)).toBe(-16)
		T.expect(Elo.delta(1000, 1000, 0.5, 32)).toBe(0)
		T.expect(Elo.delta(1000, 1200, 0.5, 32) > 0).toBe(true)
		for played = 0, 9 do
			T.expect(Elo.k(played)).toBe(48)
		end
		T.expect(Elo.k(10)).toBe(32)
		T.expect(Elo.apply(10, -50)).toBe(0)
		T.expect(Elo.sideRating({ 1000 })).toBe(1000)
		T.expect(Elo.sideRating({ 1000, 1100, 1200 })).toBe(1100)
	end)

	T.it("rolls the season with a soft reset", function()
		local same = state({ rating = 1234 })
		local s1, c1 = ArenaRules.rollSeason(same, "202611")
		T.expect(c1).toBeNil()
		T.expect(s1).toEqual(same)
		T.expect(s1 ~= same).toBe(true)

		local fresh: any = ArenaRules.emptyState()
		local s2, c2 = ArenaRules.rollSeason(fresh, "202611")
		T.expect(c2).toBeNil()
		T.expect(s2.season).toBe("202611")
		T.expect(s2.rating).toBe(1000)

		for _, case in { { 1400, 1200 }, { 800, 900 }, { 1000, 1000 } } do
			local old = state({
				rating = case[1],
				peak = 1500,
				wins = 7,
				losses = 3,
				played = 10,
				tokens = 40,
				daily = { day = 5, n = 2 },
				vs = { day = 5, ["9_1"] = 2 },
				history = {
					{
						t = 1,
						mode = "1v1",
						opp = "x",
						oppClass = "Mage",
						oppRating = 1000,
						score = 1,
						rounds = "2:0",
						delta = 16,
						rated = true,
					},
				},
			})
			local before = deepCopy(old)
			local s, closed = ArenaRules.rollSeason(old, "202612")
			T.expect(old).toEqual(before)
			T.expect(s.rating).toBe(case[2])
			T.expect(s.peak).toBe(case[2])
			T.expect({ s.wins, s.losses, s.played }).toEqual({ 0, 0, 0 })
			T.expect(s.season).toBe("202612")
			T.expect(closed).toEqual({
				season = "202611",
				rating = case[1],
				peak = 1500,
				wins = 7,
				losses = 3,
				played = 10,
				rewarded = false,
			})
			T.expect(s.last).toEqual(closed)
			T.expect(s.tokens).toBe(40)
			T.expect(s.daily).toEqual(old.daily)
			T.expect(s.vs).toEqual(old.vs)
			T.expect(s.history).toEqual(old.history)
		end

		-- no rated match in the season: the older `last` stays
		local quiet = state({
			rating = 1100,
			played = 0,
			last = { season = "202609", rating = 1300, peak = 1350, wins = 5, losses = 1, played = 6, rewarded = true },
		})
		local s3, c3 = ArenaRules.rollSeason(quiet, "202612")
		T.expect(c3).toBeNil()
		T.expect((s3.last :: any).season).toBe("202609")
		T.expect(s3.rating).toBe(1050)
	end)

	T.it("names tiers and the way to the next one", function()
		local cases = {
			{ 1099, "bronze" },
			{ 1100, "silver" },
			{ 1299, "silver" },
			{ 1300, "gold" },
			{ 1500, "diamond" },
			{ 1699, "diamond" },
			{ 1700, "master" },
		}
		for _, c in cases do
			T.expect({ c[1], ArenaRules.tierOf(c[1] :: number) }).toEqual({ c[1], c[2] })
		end
		T.expect({ ArenaRules.tierProgress(1250) }).toEqual({ "gold", 50 })
		T.expect({ ArenaRules.tierProgress(1800) }).toEqual({ nil, 0 } :: any)
	end)

	T.it("widens the window and pairs tickets deterministically", function()
		T.expect(ArenaRules.window(0)).toBe(100)
		T.expect(ArenaRules.window(14)).toBe(100)
		T.expect(ArenaRules.window(15)).toBe(200)
		T.expect(ArenaRules.window(45)).toBe(400)

		local p1, r1 = ArenaRules.pair({ ticket("a", 1, 1000, 0), ticket("b", 2, 1080, 1) }, 1)
		T.expect(keysOf(p1)).toEqual({ "a+b" })
		T.expect(#r1).toBe(0)

		local far = { ticket("a", 1, 1000, 0), ticket("b", 2, 1150, 0) }
		local p2, r2 = ArenaRules.pair(far, 0)
		T.expect(#p2).toBe(0)
		T.expect(#r2).toBe(2)
		local p3 = ArenaRules.pair(far, 15)
		T.expect(keysOf(p3)).toEqual({ "a+b" })

		local apart = { ticket("a", 1, 1000, 0), ticket("b", 2, 1000, 0, "60_79") }
		T.expect(#(ArenaRules.pair(apart, 1000))).toBe(0)
		local otherMode = { ticket("a", 1, 1000, 0), ticket("b", 2, 1000, 0) }
		otherMode[2].mode = "3v3"
		T.expect(#(ArenaRules.pair(otherMode, 1000))).toBe(0)
		local sameUser = { ticket("a", 1, 1000, 0), ticket("b", 1, 1000, 0) }
		T.expect(#(ArenaRules.pair(sameUser, 1000))).toBe(0)

		local three = { ticket("c", 3, 1090, 2), ticket("a", 1, 1000, 0), ticket("b", 2, 1020, 1) }
		local p4, r4 = ArenaRules.pair(three, 3)
		T.expect(keysOf(p4)).toEqual({ "a+b" })
		T.expect(#r4).toBe(1)
		T.expect(r4[1].entrant.key).toBe("c")
		local p5 = ArenaRules.pair(deepCopy(three), 3)
		T.expect(keysOf(p5)).toEqual(keysOf(p4))

		local rest = { ticket("z", 9, 1000, 5, "20_39"), ticket("y", 8, 1000, 1, "60_79"), ticket("x", 7, 1000, 3) }
		local _, r6 = ArenaRules.pair(rest, 6)
		T.expect({ r6[1].entrant.key, r6[2].entrant.key, r6[3].entrant.key }).toEqual({ "y", "x", "z" })

		T.expect(function()
			ArenaRules.pair({}, 0, 3)
		end).toThrow("S128")
	end)

	T.it("checks who may join the queue, in a fixed order", function()
		local function q(over: { [string]: any }?): ArenaRules.QueueInput
			local base: any = {
				level = 45,
				dead = false,
				inDungeon = false,
				inDuel = false,
				inMatch = false,
				queued = false,
				offered = false,
				penaltyUntil = nil,
				now = 100,
				mode = "1v1",
			}
			for k, v in over or {} do
				base[k] = v
			end
			return base
		end
		T.expect(ArenaRules.canQueue(q())).toBeNil()
		T.expect(ArenaRules.canQueue(q({ mode = "3v3" }))).toBe("arena.error.mode")
		T.expect(ArenaRules.canQueue(q({ level = 19 }))).toBe("arena.error.level")
		T.expect(ArenaRules.canQueue(q({ dead = true }))).toBe("arena.error.dead")
		T.expect(ArenaRules.canQueue(q({ inDungeon = true }))).toBe("arena.error.dungeon")
		T.expect(ArenaRules.canQueue(q({ inDuel = true }))).toBe("arena.error.duel")
		T.expect(ArenaRules.canQueue(q({ inMatch = true }))).toBe("arena.error.inMatch")
		T.expect(ArenaRules.canQueue(q({ queued = true }))).toBe("arena.error.queued")
		T.expect(ArenaRules.canQueue(q({ offered = true }))).toBe("arena.error.queued")
		T.expect(ArenaRules.canQueue(q({ penaltyUntil = 200 }))).toBe("arena.error.penalty")
		T.expect(ArenaRules.canQueue(q({ penaltyUntil = 100 }))).toBeNil()
		T.expect(ArenaRules.canQueue(q({ level = 15, inDungeon = true }))).toBe("arena.error.level")
		T.expect(ArenaRules.canQueue(q({ dead = true, inMatch = true, queued = true }))).toBe("arena.error.dead")
		for _, key in
			{
				"arena.error.mode",
				"arena.error.level",
				"arena.error.dead",
				"arena.error.dungeon",
				"arena.error.duel",
				"arena.error.inMatch",
				"arena.error.queued",
				"arena.error.penalty",
			}
		do
			T.expect({ key, pl[key] ~= nil and en[key] ~= nil }).toEqual({ key, true })
		end
	end)

	T.it("decides rounds for one fighter and for teams", function()
		local function one(a: ArenaRules.Fighter, b: ArenaRules.Fighter, timedOut: boolean?)
			return ArenaRules.roundOutcome({ { a }, { b } }, timedOut == true, "hpPct")
		end
		T.expect(one(fighter("a", 1), fighter("b", 1))).toBeNil()
		T.expect(one(fighter("a", 0.4, true), fighter("b", 0.8))).toEqual({ winner = 2, reason = "ko", draw = false })
		T.expect((one(fighter("a", 0, true), fighter("b", 0, true)) :: any).draw).toBe(true)
		T.expect(one(fighter("a", 1), fighter("b", 1, false, true)))
			.toEqual({ winner = 1, reason = "left", draw = false })
		T.expect(one(fighter("a", 0.6), fighter("b", 0.4), true)).toEqual({ winner = 1, reason = "time", draw = false })
		T.expect(one(fighter("a", 0.5), fighter("b", 0.5), true))
			.toEqual({ winner = nil, reason = "time", draw = true })

		local teamA = { fighter("a1", 0.9), fighter("a2", 0, true), fighter("a3", 0.3) }
		local teamB = { fighter("b1", 0.5), fighter("b2", 0.5), fighter("b3", 0.1) }
		T.expect(ArenaRules.roundOutcome({ teamA, teamB }, false, "sumHpPct")).toBeNil()
		T.expect(ArenaRules.roundOutcome({ teamA, teamB }, true, "sumHpPct")).toEqual({
			winner = 1,
			reason = "time",
			draw = false,
		})
		local downB = { fighter("b1", 0, true), fighter("b2", 0, true), fighter("b3", 0, false, true) }
		T.expect(ArenaRules.roundOutcome({ teamA, downB }, false, "sumHpPct")).toEqual({
			winner = 1,
			reason = "ko",
			draw = false,
		})
	end)

	T.it("decides matches", function()
		local function winner(r: ArenaRules.MatchResult?): any
			return if r then { r.winner, r.reason } else "go on"
		end
		T.expect(winner(ArenaRules.matchOutcome({ 2, 0 }, 2, MODE))).toEqual({ 1, "score" })
		T.expect(winner(ArenaRules.matchOutcome({ 1, 1 }, 2, MODE))).toBe("go on")
		T.expect(winner(ArenaRules.matchOutcome({ 2, 1 }, 3, MODE))).toEqual({ 1, "score" })
		T.expect(winner(ArenaRules.matchOutcome({ 1, 0 }, 3, MODE))).toEqual({ 1, "score" })
		T.expect(winner(ArenaRules.matchOutcome({ 0, 0 }, 3, MODE))).toEqual({ nil, "draw" } :: any)
		T.expect(winner(ArenaRules.matchOutcome({ 1, 0 }, 1, MODE, 1))).toEqual({ 2, "forfeit" })
		local r = ArenaRules.matchOutcome({ 2, 1 }, 3, MODE) :: ArenaRules.MatchResult
		T.expect(ArenaRules.scoreOf(r, 1)).toBe(1)
		T.expect(ArenaRules.scoreOf(r, 2)).toBe(0)
		T.expect(ArenaRules.roundsText(r.score, 2)).toBe("1:2")
		local d = ArenaRules.matchOutcome({ 0, 0 }, 3, MODE) :: ArenaRules.MatchResult
		T.expect(ArenaRules.scoreOf(d, 1)).toBe(0.5)
	end)

	T.it("writes a match result", function()
		local s0 = state()
		local before = deepCopy(s0)
		local s1, r1 = ArenaRules.applyResult(s0, input())
		T.expect(s0).toEqual(before)
		T.expect(r1).toEqual({ delta = 24, rated = true })
		T.expect({ s1.rating, s1.played, s1.wins, s1.losses, s1.peak }).toEqual({ 1024, 1, 1, 0, 1024 })
		T.expect(s1.history[1].rated).toBe(true)
		T.expect(s1.history[1].delta).toBe(24)
		T.expect(s1.history[1].opp).toBe("Rival")
		T.expect(s1.daily).toEqual({ day = DAY, n = 1 })
		T.expect(s1.vs).toEqual({ day = DAY, ["2_1"] = 1 })

		local s2 = ArenaRules.applyResult(s1, input({ score = 0, rounds = "0:2" }))
		T.expect(s2.losses).toBe(1)
		T.expect(s2.rating < s1.rating).toBe(true)

		-- the fourth match of the day against the same opponent changes nothing but the history and the counters
		local s3 = ArenaRules.applyResult(s2, input())
		local s4, r4 = ArenaRules.applyResult(s3, input())
		T.expect(r4).toEqual({ delta = 0, rated = false })
		T.expect({ s4.rating, s4.played, s4.wins, s4.losses, s4.peak }).toEqual({
			s3.rating,
			s3.played,
			s3.wins,
			s3.losses,
			s3.peak,
		})
		T.expect(s4.history[1].delta).toBe(0)
		T.expect(s4.history[1].rated).toBe(false)
		T.expect(s4.vs["2_1"]).toBe(4)
		T.expect(ArenaRules.isRated(s3, "2_1", DAY)).toBe(false)
		T.expect(ArenaRules.vsCount(s3, "day", DAY)).toBe(0)

		-- a new day resets the counters
		local s5, r5 = ArenaRules.applyResult(s4, input({ day = DAY + 1 }))
		T.expect(r5.rated).toBe(true)
		T.expect(s5.daily).toEqual({ day = DAY + 1, n = 1 })
		T.expect(s5.vs).toEqual({ day = DAY + 1, ["2_1"] = 1 })

		-- a tournament (rated = false) never moves the rating
		local s6, r6 = ArenaRules.applyResult(s0, input({ rated = false }))
		T.expect(r6).toEqual({ delta = 0, rated = false })
		T.expect(s6.rating).toBe(1000)
		T.expect(s6.played).toBe(0)

		-- history: newest first, at most LIMITS.history
		local s = s0
		for i = 1, 12 do
			s = ArenaRules.applyResult(s, input({ oppKeys = { `{i + 10}_1` }, oppName = `R{i}` }))
		end
		T.expect(#s.history).toBe(Arena.LIMITS.history)
		T.expect(s.history[1].opp).toBe("R12")

		-- the floor
		local low = ArenaRules.applyResult(state({ rating = 10, played = 20 }), input({ score = 0, oppRating = 10 }))
		T.expect(low.rating).toBe(0)

		-- another season first: the soft reset, then the result
		local old = state({ season = "202610", rating = 1400, played = 12, peak = 1400 })
		local rolled = ArenaRules.applyResult(old, input())
		T.expect(rolled.season).toBe("202611")
		T.expect(rolled.rating).toBe(1200 + Elo.delta(1200, 1000, 1, 48))
		T.expect((rolled.last :: any).season).toBe("202610")

		-- the rating field of the mode (S128 rating3)
		local mode3: any = table.clone(MODE)
		mode3.id = "3v3"
		mode3.ratingField = "rating3"
		local s7: any = ArenaRules.applyResult(s0, input({ mode = mode3 }))
		T.expect(s7.rating3).toBe(1024)
		T.expect(s7.rating).toBe(1000)
		T.expect(s7.history[1].mode).toBe("3v3")
	end)

	T.it("S127: the pit venue has the shape of the Ristalle and lies in the arena server layout", function()
		local ArenaPit = require("../src/shared/Data/ArenaPit")
		local pit = Arena.venue("pit") :: Arena.Venue
		local ristalle = Arena.venue("ristalle") :: Arena.Venue
		local fieldsOf = function(v: any): { string }
			local out = {}
			for k in v do
				table.insert(out, k)
			end
			table.sort(out)
			return out
		end
		T.expect(fieldsOf(pit)).toEqual(fieldsOf(ristalle))
		T.expect(pit.map).toBe("arena_pit")
		T.expect(#pit.sides).toBe(#ristalle.sides)
		local layout = ArenaPit.layout("arena")
		local half = layout.size / 2
		for side = 1, #pit.sides do
			for i = 1, #pit.sides[side] do
				local x, z = ArenaRules.spot(pit, side, i)
				T.expect(math.abs(x) <= half and math.abs(z) <= half).toBe(true)
			end
			local x1, z1 = ArenaRules.spot(pit, side, 1)
			T.expect(ArenaRules.inside(pit, x1, z1)).toBe(true)
		end
		for i = 1, #pit.stands do
			local x, z = ArenaRules.standSpot(pit, i)
			T.expect(math.abs(x) <= half and math.abs(z) <= half).toBe(true)
			T.expect(ArenaRules.inside(pit, x, z)).toBe(false)
		end
		T.expect(math.abs(pit.exit[1]) <= half and math.abs(pit.exit[2]) <= half).toBe(true)
	end)

	T.it("S127: ArenaRules.pair never marks a pairing as the fallback offer", function()
		local pairs = ArenaRules.pair({ ticket("a", 1, 1000, 0), ticket("b", 2, 1010, 0) }, 10)
		T.expect(#pairs).toBe(1)
		T.expect(pairs[1].fallback).toBeNil()
	end)
end)
