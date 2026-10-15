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
		-- S128: the 3v3 mode exists (its own block below)
		T.expect((Arena.mode("3v3") :: any).teamSize).toBe(3)
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
				-- S128: the 3v3 numbers of the season (untouched here)
				rating3 = 1000,
				peak3 = 1000,
				wins3 = 0,
				losses3 = 0,
				played3 = 0,
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

		-- S128: teamSize 3 forms teams (block "S128 teams")
		T.expect(#(ArenaRules.pair({}, 0, 3))).toBe(0)
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
		T.expect(ArenaRules.canQueue(q({ mode = "3v3" }))).toBeNil() -- S128
		T.expect(ArenaRules.canQueue(q({ mode = "5v5" }))).toBe("arena.error.mode")
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

-- S128 (DESIGN-17 §6): 3v3, Arena Tokens, the arena shop and the season rewards ----------------------------------------

local Blessings = require("../src/shared/Data/Blessings")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Items = require("../src/shared/Data/Items")
local TitleData = require("../src/shared/Data/Titles")

local MODE3 = Arena.MODES["3v3"]

local function solo(key: string, userId: number, rating: number, joinedAt: number): ArenaRules.Ticket
	return { entrant = entrant(key, userId, rating), mode = "3v3", bracket = "40_59", joinedAt = joinedAt }
end

local function team(key: string, userIds: { number }, ratings: { number }, joinedAt: number): ArenaRules.Ticket
	local members = {}
	for i, userId in userIds do
		table.insert(members, entrant(`{key}{i}`, userId, ratings[i]))
	end
	local lead = table.clone(members[1])
	lead.key = `{key}1`
	lead.rating = Elo.sideRating(ratings)
	return { entrant = lead, mode = "3v3", bracket = "40_59", joinedAt = joinedAt, members = members }
end

local function sideKeys(p: ArenaRules.Pairing?): { string }
	if not p then
		return {}
	end
	local out = {}
	for _, side in p.sides do
		local keys = {}
		for _, t in side do
			table.insert(keys, t.entrant.key)
		end
		table.insert(out, table.concat(keys, ","))
	end
	return out
end

T.describe("S128 arena data", function()
	T.it("adds the 3v3 mode of the contract with its own fields", function()
		T.expect(MODE3.teamSize).toBe(3)
		T.expect(MODE3.roundTime).toBe(240)
		T.expect(MODE3.winsNeeded).toBe(1)
		T.expect(MODE3.maxRounds).toBe(1)
		T.expect(MODE3.tieBreak).toBe("sumHpPct")
		T.expect(MODE3.ratingField).toBe("rating3")
		T.expect(MODE3.board).toBe("arena3")
		T.expect(MODE3.potions).toBe(MODE.potions)
		T.expect(Arena.MODE_ORDER).toEqual({ "1v1", "3v3" })
		local template: any = ArenaRules.emptyState()
		for _, mode in Arena.MODES do
			for _, field in { mode.ratingField, mode.peakField, mode.winsField, mode.lossesField, mode.playedField } do
				T.expect({ field, type(template[field]) }).toEqual({ field, "number" })
			end
			T.expect({ mode.vsField, type(template[mode.vsField]) }).toEqual({ mode.vsField, "table" })
		end
		T.expect({ MODE.peakField, MODE.winsField, MODE.lossesField, MODE.playedField, MODE.vsField }).toEqual({
			"peak",
			"wins",
			"losses",
			"played",
			"vs",
		})
	end)

	T.it("keeps the token numbers of the contract", function()
		local t = Arena.TOKENS
		T.expect(t.win1v1 > t.loss1v1 and t.loss1v1 > 0).toBe(true)
		T.expect(t.win3v3 > t.loss3v3 and t.loss3v3 > 0).toBe(true)
		T.expect({ t.win1v1, t.loss1v1, t.win3v3, t.loss3v3 }).toEqual({ 10, 4, 12, 5 })
		T.expect(t.firstMatches).toBe(3)
		T.expect(t.firstMul).toBe(2)
		T.expect(Arena.tokensWeekCap).toBe(600)
	end)

	T.it("sells only arena cosmetics, blessings up to Heroic and Return Stones", function()
		local keys: { [string]: boolean } = {}
		local blessings: { [string]: boolean } = {}
		for _, entry in Arena.SHOP do
			T.expect({ entry.key, keys[entry.key] }).toEqual({ entry.key, nil })
			keys[entry.key] = true
			T.expect({ entry.key, entry.price > 0 and entry.price % 1 == 0 }).toEqual({ entry.key, true })
			T.expect(Arena.shopByKey[entry.key]).toBe(entry)
			if entry.kind == "item" then
				T.expect({ entry.id, Items.get(entry.id) ~= nil }).toEqual({ entry.id, true })
				local line, rarity = string.match(entry.id, "^blessing_(%a+)_(%d)$")
				if line then
					T.expect(tonumber(rarity) :: number <= Arena.SHOP_MAX_BLESSING_RARITY).toBe(true)
					blessings[entry.id] = true
				else
					T.expect(entry.id).toBe("stone_return")
				end
			else
				local def = Cosmetics.get(entry.id)
				T.expect({ entry.id, def and def.obtain and def.obtain.arena }).toEqual({ entry.id, "shop" })
			end
		end
		T.expect(Arena.SHOP_MAX_BLESSING_RARITY).toBe(3)
		for _, line in Blessings.lines do
			for rarity = 1, 3 do
				T.expect({ line, rarity, blessings[`blessing_{line}_{rarity}`] }).toEqual({ line, rarity, true })
			end
		end
		-- every shop cosmetic of the arena is in the shop
		for _, def in Cosmetics.list do
			if def.obtain and def.obtain.arena == "shop" then
				local entry = Arena.shopOf(def.id)
				T.expect({ def.id, entry and entry.kind }).toEqual({ def.id, "cosmetic" })
			end
		end
	end)

	T.it("lists the season rewards of every tier, growing with the tier", function()
		local previous: { string } = {}
		for _, tier in Arena.TIERS do
			local reward = Arena.SEASON_REWARDS[tier.id]
			T.expect({ tier.id, reward ~= nil }).toEqual({ tier.id, true })
			local title = TitleData.get(reward.title)
			T.expect({ tier.id, title and title.req.kind, title and (title.req :: any).tier }).toEqual({
				tier.id,
				"arenaSeason",
				tier.id,
			})
			local cosmetics = reward.cosmetics or {}
			for _, id in cosmetics do
				local def = Cosmetics.get(id)
				T.expect({ id, def and def.obtain and def.obtain.arena }).toEqual({ id, "season" })
			end
			for _, id in previous do
				T.expect({ tier.id, id, table.find(cosmetics, id) ~= nil }).toEqual({ tier.id, id, true })
			end
			previous = cosmetics
		end
		local shards = {}
		for _, tier in Arena.TIERS do
			table.insert(shards, Arena.SEASON_REWARDS[tier.id].shards or 0)
		end
		T.expect(shards).toEqual({ 0, 0, 0, 150, 300 })
		T.expect(Arena.seasonMinPlayed).toBe(5)
	end)

	T.it("seats each 3v3 side on the sand and benches it on its own stand", function()
		for _, id in { "ristalle", "pit" } do
			local venue = Arena.venue(id) :: Arena.Venue
			for side = 1, 2 do
				T.expect(#venue.sides[side]).toBe(3)
				for _, p in venue.sides[side] do
					T.expect({ id, ArenaRules.inside(venue, p[1], p[2]) }).toEqual({ id, true })
				end
				local i = ArenaRules.benchIndex(venue, side)
				local x, z = ArenaRules.standSpot(venue, i)
				T.expect(ArenaRules.inside(venue, x, z)).toBe(false)
				-- the bench is on the side's half (side 1 west, side 2 east)
				local sx = venue.sides[side][1][1] - venue.center[1]
				T.expect({ id, side, (x - venue.center[1]) * sx > 0 }).toEqual({ id, side, true })
			end
		end
	end)
end)

T.describe("S128 teams", function()
	T.it("forms teams of solo tickets and pairs party teams, never splitting one", function()
		local six = {}
		for i = 1, 6 do
			table.insert(six, solo(`s{i}`, i, 1000 + i, i))
		end
		local p1 = ArenaRules.formTeams3(six, 10)
		T.expect(sideKeys(p1)).toEqual({ "s1,s2,s3", "s4,s5,s6" })
		local pairs, rest = ArenaRules.pair(six, 10, 3)
		T.expect(#pairs).toBe(1)
		T.expect(#rest).toBe(0)

		-- a party team and three solo
		local mixed = { team("t", { 11, 12, 13 }, { 1000, 1000, 1000 }, 0), solo("a", 1, 1000, 1) }
		table.insert(mixed, solo("b", 2, 1000, 2))
		table.insert(mixed, solo("c", 3, 1000, 3))
		T.expect(sideKeys(ArenaRules.formTeams3(mixed, 5))).toEqual({ "t1", "a,b,c" })

		-- two party teams
		local two =
			{ team("t", { 11, 12, 13 }, { 1000, 1000, 1000 }, 0), team("u", { 21, 22, 23 }, { 1050, 990, 1000 }, 1) }
		T.expect(sideKeys(ArenaRules.formTeams3(two, 5))).toEqual({ "t1", "u1" })

		-- five solo: nothing
		local five = {}
		for i = 1, 5 do
			table.insert(five, solo(`s{i}`, i, 1000, i))
		end
		T.expect(ArenaRules.formTeams3(five, 10)).toBeNil()

		-- a team is never split: team + 2 solo + team = team vs team, the solo wait
		local split = {
			solo("a", 1, 1000, 0),
			solo("b", 2, 1000, 1),
			team("t", { 11, 12, 13 }, { 1000, 1000, 1000 }, 2),
			team("u", { 21, 22, 23 }, { 1000, 1000, 1000 }, 3),
		}
		local p2, r2 = ArenaRules.pair(split, 5, 3)
		T.expect(sideKeys(p2[1])).toEqual({ "t1", "u1" })
		T.expect(#r2).toBe(2)
	end)

	T.it("waits for the window and is deterministic", function()
		local far = {}
		for i = 1, 3 do
			table.insert(far, solo(`a{i}`, i, 1000, 0))
		end
		for i = 1, 3 do
			table.insert(far, solo(`b{i}`, 10 + i, 1250, 0))
		end
		T.expect(ArenaRules.formTeams3(far, 0)).toBeNil()
		-- 30 s later the window is 300: the high three join the low ones' mean
		local later = ArenaRules.formTeams3(far, 30)
		T.expect(#sideKeys(later)).toBe(2)
		local shuffled = { far[4], far[2], far[6], far[1], far[5], far[3] }
		T.expect(sideKeys(ArenaRules.formTeams3(shuffled, 30))).toEqual(sideKeys(later))
		-- no ticket in both teams, no user twice
		local seen: { [number]: boolean } = {}
		for _, side in (later :: ArenaRules.Pairing).sides do
			for _, t in side do
				T.expect(seen[t.entrant.userId]).toBeNil()
				seen[t.entrant.userId] = true
			end
		end
		-- one user twice in the queue is never twice in a match
		local same = {}
		for i = 1, 6 do
			table.insert(same, solo(`x{i}`, if i <= 2 then 1 else i, 1000, i))
		end
		T.expect(ArenaRules.formTeams3(same, 10)).toBeNil()
		-- one bracket only
		local mixedBrackets = { solo("a", 1, 1000, 0), solo("b", 2, 1000, 0) }
		mixedBrackets[2].bracket = "60_79"
		T.expect(function()
			ArenaRules.formTeams3(mixedBrackets, 0)
		end).toThrow("one bracket")
		-- pair groups by bracket
		local p, r = ArenaRules.pair(mixedBrackets, 0, 3)
		T.expect(#p).toBe(0)
		T.expect(#r).toBe(2)
	end)

	T.it("decides a 3v3 round and the match in one round", function()
		local a = { fighter("a1", 0.5), fighter("a2", 0, true), fighter("a3", 0, false, true) }
		local b = { fighter("b1", 0, true), fighter("b2", 0, true), fighter("b3", 0, true) }
		T.expect(ArenaRules.roundOutcome({ a, b }, false, MODE3.tieBreak)).toEqual({
			winner = 1,
			reason = "ko",
			draw = false,
		})
		local c = { fighter("a1", 0.5), fighter("a2", 0.5), fighter("a3", 0.5) }
		local d = { fighter("b1", 0.4), fighter("b2", 0.4), fighter("b3", 0.4) }
		T.expect((ArenaRules.roundOutcome({ c, d }, true, MODE3.tieBreak) :: any).winner).toBe(1)
		-- a downed fighter counts 0 at the end of the time
		local e = { fighter("a1", 1, true), fighter("a2", 0.6), fighter("a3", 0.6) }
		local f = { fighter("b1", 0.5), fighter("b2", 0.4), fighter("b3", 0.4) }
		T.expect((ArenaRules.roundOutcome({ e, f }, true, MODE3.tieBreak) :: any).winner).toBe(2)
		local g = { fighter("a1", 0.5), fighter("a2", 0.5), fighter("a3", 0.5) }
		T.expect((ArenaRules.roundOutcome({ c, g }, true, MODE3.tieBreak) :: any).draw).toBe(true)
		local none = { fighter("a1", 0, true), fighter("a2", 0, true), fighter("a3", 0, true) }
		T.expect((ArenaRules.roundOutcome({ none, b }, false, MODE3.tieBreak) :: any).draw).toBe(true)
		local m = ArenaRules.matchOutcome({ 1, 0 }, 1, MODE3) :: ArenaRules.MatchResult
		T.expect({ m.winner, m.reason }).toEqual({ 1, "score" } :: any)
		local dr = ArenaRules.matchOutcome({ 0, 0 }, 1, MODE3) :: ArenaRules.MatchResult
		T.expect({ dr.winner, dr.reason }).toEqual({ nil, "draw" } :: any)
	end)

	T.it("lets a solo player or a full party team queue", function()
		local function q(over: { [string]: any }?): ArenaRules.Queue3Input
			local base: any = { inParty = false, partySize = 0, isLeader = false, sameBracket = true, anyBusy = false }
			for k, v in over or {} do
				base[k] = v
			end
			return base
		end
		T.expect({ ArenaRules.canQueue3(q()) }).toEqual({ true } :: any)
		T.expect({ ArenaRules.canQueue3(q({ inParty = true, partySize = 3, isLeader = true })) })
			.toEqual({ true } :: any)
		T.expect({ ArenaRules.canQueue3(q({ inParty = true, partySize = 3 })) })
			.toEqual({ false, "arena.error.notLeader" })
		T.expect({ ArenaRules.canQueue3(q({ inParty = true, partySize = 2, isLeader = true })) }).toEqual({
			false,
			"arena.error.party3",
		})
		T.expect({ ArenaRules.canQueue3(q({ inParty = true, partySize = 4, isLeader = true })) }).toEqual({
			false,
			"arena.error.party3",
		})
		T.expect({ ArenaRules.canQueue3(q({ inParty = true, partySize = 3, isLeader = true, sameBracket = false })) })
			.toEqual({ false, "arena.error.partyBracket" })
		T.expect({ ArenaRules.canQueue3(q({ inParty = true, partySize = 3, isLeader = true, anyBusy = true })) })
			.toEqual({ false, "arena.error.partyBusy" })
		for _, key in
			{ "arena.error.party3", "arena.error.notLeader", "arena.error.partyBracket", "arena.error.partyBusy" }
		do
			T.expect({ key, pl[key] ~= nil and en[key] ~= nil }).toEqual({ key, true })
		end
	end)

	T.it("writes a 3v3 result into the team fields only", function()
		local s0 = state()
		local before = deepCopy(s0)
		local opp = Elo.sideRating({ 1000, 1000, 1000 })
		local s1: any, r1 =
			ArenaRules.applyResult(s0, input({ mode = MODE3, oppKeys = { "7_1", "8_1", "9_1" }, oppRating = opp }))
		T.expect(s0).toEqual(before)
		T.expect(r1).toEqual({ delta = 24, rated = true })
		T.expect({ s1.rating3, s1.wins3, s1.played3, s1.peak3 }).toEqual({ 1024, 1, 1, 1024 })
		T.expect({ s1.rating, s1.wins, s1.played, s1.peak }).toEqual({ 1000, 0, 0, 1000 })
		T.expect(s1.vs).toEqual({ day = 0 })
		T.expect(s1.vs3).toEqual({ day = DAY, ["7_1"] = 1, ["8_1"] = 1, ["9_1"] = 1 })
		T.expect(s1.daily).toEqual({ day = DAY, n = 1 })
		-- a teammate past newGames gets K 32
		local vet = state({ played3 = 12 })
		local _, rv = ArenaRules.applyResult(vet, input({ mode = MODE3, oppKeys = { "7_1" } }))
		T.expect(rv.delta).toBe(16)
		T.expect(rv.delta < r1.delta).toBe(true)
		-- the fourth match today against one of them is unrated
		local s = s0
		for _ = 1, 3 do
			s = ArenaRules.applyResult(s, input({ mode = MODE3, oppKeys = { "7_1", "8_1", "9_1" } }))
		end
		local s4: any, r4 = ArenaRules.applyResult(s, input({ mode = MODE3, oppKeys = { "9_1", "5_1", "6_1" } }))
		T.expect(r4.rated).toBe(false)
		T.expect(s4.played3).toBe((s :: any).played3)
		-- the 1v1 counters do not see the 3v3 opponents
		T.expect(ArenaRules.isRated(s4, "9_1", DAY)).toBe(true)
		T.expect(ArenaRules.isRated(s4, "9_1", DAY, "vs3")).toBe(false)
		-- the floor
		local low: any = ArenaRules.applyResult(
			state({ rating3 = 5, played3 = 30 }),
			input({ mode = MODE3, score = 0, oppRating = 5 })
		)
		T.expect(low.rating3).toBe(0)
	end)
end)

T.describe("S128 tokens", function()
	T.it("pays a match with the daily bonus, the cap and no pay for leaving or a farmed opponent", function()
		local function tf(...): { any }
			return { ArenaRules.tokensFor(...) }
		end
		T.expect(tf("1v1", "win", 0, 0, true, false)).toEqual({ 20, "arena.tokens.bonus" })
		T.expect(tf("1v1", "win", 2, 0, true, false)).toEqual({ 20, "arena.tokens.bonus" })
		T.expect(tf("1v1", "win", 3, 0, true, false)).toEqual({ 10 } :: any)
		T.expect(tf("1v1", "loss", 5, 0, true, false)).toEqual({ 4 } :: any)
		T.expect(tf("3v3", "loss", 5, 0, true, false)).toEqual({ 5 } :: any)
		T.expect(tf("3v3", "loss", 0, 0, true, false)).toEqual({ 10, "arena.tokens.bonus" })
		T.expect(tf("3v3", "win", 4, 0, true, false)).toEqual({ 12 } :: any)
		T.expect(tf("3v3", "draw", 4, 0, true, false)).toEqual({ 5 } :: any)
		T.expect(tf("1v1", "draw", 4, 0, true, false)).toEqual({ 4 } :: any)
		T.expect(tf("1v1", "loss", 0, 0, true, true)).toEqual({ 0, "arena.tokens.left" })
		T.expect(tf("1v1", "win", 0, 0, false, false)).toEqual({ 0, "arena.tokens.sameOpponent" })
		T.expect(tf("1v1", "win", 0, 595, true, false)).toEqual({ 5, "arena.tokens.cappedPart" })
		T.expect(tf("1v1", "win", 0, 600, true, false)).toEqual({ 0, "arena.tokens.capped" })
		for _, key in
			{
				"arena.tokens.bonus",
				"arena.tokens.left",
				"arena.tokens.sameOpponent",
				"arena.tokens.capped",
				"arena.tokens.cappedPart",
				"arena.tokens.gain",
			}
		do
			T.expect({ key, pl[key] ~= nil and en[key] ~= nil }).toEqual({ key, true })
		end
	end)

	T.it("adds tokens on a copy and starts a new week on Monday 00:00 UTC", function()
		local week = 2965
		local monday = Time.weekStart(week)
		local s0 = state({ tokens = 50, tokensWeek = { week = week - 1, n = 590 } })
		local before = deepCopy(s0)
		local s1, balance = ArenaRules.addTokens(s0, 20, monday)
		T.expect(s0).toEqual(before)
		T.expect(balance).toBe(70)
		T.expect(s1.tokensWeek).toEqual({ week = week, n = 20 })
		local s2 = ArenaRules.addTokens(s1, 5, monday + 3600)
		T.expect(s2.tokensWeek).toEqual({ week = week, n = 25 })
		T.expect(ArenaRules.weekTokens(s2, monday - 1)).toBe(0)
		T.expect(ArenaRules.weekTokens(s2, monday + 7 * 86400 - 1)).toBe(25)
		T.expect(ArenaRules.weekTokens(s2, monday + 7 * 86400)).toBe(0)
		T.expect(ArenaRules.weekOf(monday - 1)).toBe(week - 1)
		T.expect(ArenaRules.weekOf(monday)).toBe(week)
		-- the daily counter before a match
		T.expect(ArenaRules.dailyCount(state({ daily = { day = DAY, n = 2 } }), DAY)).toBe(2)
		T.expect(ArenaRules.dailyCount(state({ daily = { day = DAY - 1, n = 7 } }), DAY)).toBe(0)
	end)
end)

T.describe("S128 season rewards", function()
	local function last(over: { [string]: any }): ArenaRules.ArenaSeasonSummary
		local base: any = {
			season = "202611",
			rating = 1000,
			peak = 1000,
			wins = 0,
			losses = 0,
			played = 0,
			rewarded = false,
			rating3 = 1000,
			peak3 = 1000,
			wins3 = 0,
			losses3 = 0,
			played3 = 0,
		}
		for k, v in over do
			base[k] = v
		end
		return base
	end

	T.it("rewards the better peak of the season once, with a minimum of matches", function()
		T.expect(ArenaRules.seasonTier(1050, 1320)).toBe("gold")
		T.expect(ArenaRules.seasonReward(nil)).toBeNil()
		T.expect(ArenaRules.seasonReward(last({ played = 2, played3 = 2 }))).toBeNil()
		T.expect(ArenaRules.seasonReward(last({ played = 9, rewarded = true }))).toBeNil()
		local master = ArenaRules.seasonReward(last({ played = 3, played3 = 2, peak3 = 1720 })) :: any
		T.expect(master.tier).toBe("master")
		T.expect(master.shards).toBe(300)
		T.expect(master.title).toBe("arena_master")
		T.expect(master.season).toBe("202611")
		local bronze = ArenaRules.seasonReward(last({ played = 5 })) :: any
		T.expect({ bronze.tier, bronze.shards, #bronze.cosmetics }).toEqual({ "bronze", 0, 0 })
		-- a summary written before S128 (no 3v3 fields)
		local old: any =
			{ season = "202610", rating = 1310, peak = 1350, wins = 5, losses = 1, played = 6, rewarded = false }
		T.expect((ArenaRules.seasonReward(old) :: any).tier).toBe("gold")
		T.expect({ ArenaRules.seasonLabel("202611") }).toEqual({ "11", "2026" })
		T.expect({ ArenaRules.seasonLabel("202601") }).toEqual({ "01", "2026" })
		T.expect(ArenaRules.prevSeason("202601")).toBe("202512")
		T.expect(ArenaRules.prevSeason("202611")).toBe("202610")
	end)

	T.it("soft resets the 3v3 rating and closes a season of 3v3 matches only", function()
		local old = state({ rating3 = 1400, peak3 = 1450, wins3 = 4, losses3 = 2, played3 = 6, played = 0 })
		local s: any, closed = ArenaRules.rollSeason(old, "202612")
		T.expect(s.rating3).toBe(1200)
		T.expect(s.peak3).toBe(1200)
		T.expect({ s.played3, s.wins3, s.losses3 }).toEqual({ 0, 0, 0 })
		T.expect(closed ~= nil).toBe(true)
		T.expect({ (closed :: any).peak3, (closed :: any).played3 }).toEqual({ 1450, 6 })
		T.expect((s.last :: any).season).toBe("202611")
		-- titles and the pending reward survive a roll
		local kept: any = ArenaRules.rollSeason(
			state({ titles = { gold = "202610" }, pendingReward = { season = "202610", tier = "gold", shards = 0 } }),
			"202612"
		)
		T.expect(kept.titles).toEqual({ gold = "202610" })
		T.expect(kept.pendingReward).toEqual({ season = "202610", tier = "gold", shards = 0 })
	end)
end)

T.describe("S128 arena shop", function()
	T.it("checks a purchase like the server", function()
		local entry = Arena.shopByKey["aura_gladiator"]
		local char = { level = 45, arena = state({ tokens = entry.price }) }
		T.expect({ ArenaRules.canBuyShop(entry, char, {}) }).toEqual({ true } :: any)
		T.expect({ ArenaRules.canBuyShop(entry, { level = 45, arena = state({ tokens = entry.price - 1 }) }, {}) })
			.toEqual({ false, "arena.shop.error.tokens" })
		T.expect({ ArenaRules.canBuyShop(entry, char, { aura_gladiator = true }) }).toEqual({
			false,
			"arena.shop.error.owned",
		})
		T.expect({ ArenaRules.canBuyShop(entry, { level = 19, arena = state({ tokens = 9999 }) }, {}) }).toEqual({
			false,
			"arena.shop.error.level",
		})
		T.expect({ ArenaRules.canBuyShop(Arena.shopByKey["nope"], char, {}) }).toEqual({ false, "error.badRequest" })
		for _, key in { "arena.shop.error.tokens", "arena.shop.error.owned", "arena.shop.error.level" } do
			T.expect({ key, pl[key] ~= nil and en[key] ~= nil }).toEqual({ key, true })
		end
	end)
end)
