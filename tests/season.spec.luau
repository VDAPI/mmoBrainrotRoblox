--!strict
-- S152: the season pass rules (Logic/Season) on the data of Data/Seasons: the state, the season clock, points with the
-- daily monster limit, the growing weekly cap and the catch-up, claiming both tracks, buying the premium track.

local Market = require("../src/shared/Data/Market")
local Season = require("../src/shared/Logic/Season")
local Seasons = require("../src/shared/Data/Seasons")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")

local def = Seasons.get("s1") :: Seasons.SeasonDef
local DAY = 86400
local WEEK = Seasons.WEEK
local START = def.start
local TP = Seasons.TIER_POINTS

-- A state of season 1 with `points` (and `premium`).
local function at(points: number, premium: boolean?): any
	local s = Season.fresh("s1")
	s.points = points
	s.premium = premium == true
	return s
end

T.describe("Season data (S152)", function()
	T.it("season 1: Monday 2 November 2026 00:00 UTC, 8 weeks, 40 tiers", function()
		T.expect({ def.weeks, def.tiers, def.nameKey }).toEqual({ 8, 40, "season.s1.name" })
		T.expect({ Time.civil(START) }).toEqual({ 2026, 11, 2 })
		T.expect(Time.weekStart(Time.weekNumber(START))).toBe(START)
		for _, d in Seasons.list do
			T.expect({ d.id, Time.weekStart(Time.weekNumber(d.start)) == d.start }).toEqual({ d.id, true })
		end
	end)

	T.it("free rewards every 2 tiers, premium on every tier, tier 40 on both", function()
		local free, premium = 0, 0
		for tier = 1, def.tiers do
			if def.rewards.free[tier] then
				free += 1
				T.expect({ tier, tier % 2 }).toEqual({ tier, 0 })
			end
			T.expect({ tier, def.rewards.premium[tier] ~= nil }).toEqual({ tier, true })
			premium += 1
		end
		T.expect({ free, premium }).toEqual({ 20, 40 })
		T.expect((def.rewards.premium[40] :: Seasons.Reward).kind).toBe("cosmetic")
		T.expect((def.rewards.free[40] :: Seasons.Reward).kind).toBe("cosmetic")
	end)

	T.it("at, next and lastEnded", function()
		T.expect(Seasons.at(START - 1)).toBeNil()
		T.expect((Seasons.at(START) :: any).id).toBe("s1")
		T.expect((Seasons.at(Season.ends(def) - 1) :: any).id).toBe("s1")
		T.expect(Seasons.at(Season.ends(def))).toBeNil()
		T.expect((Seasons.next(START - 1) :: any).id).toBe("s1")
		T.expect(Seasons.lastEnded(Season.ends(def) - 1)).toBeNil()
		T.expect((Seasons.lastEnded(Season.ends(def)) :: any).id).toBe("s1")
	end)
end)

T.describe("Season state (S152)", function()
	T.it("sanitize repairs rubbish", function()
		local s = Season.sanitize({
			id = "s1",
			points = -5.5,
			day = "x",
			dayKill = 0 / 0,
			premium = "yes",
			free = { [2] = true, ["4"] = true, [0] = true, [41] = true, ["x"] = true, [6] = false, [1.5] = true },
			prem = "nope",
			mailed = { s0 = true, [3] = true, bad = 1 },
		})
		T.expect(s).toEqual({
			id = "s1",
			points = 0,
			day = 0,
			dayKill = 0,
			premium = false,
			free = { ["2"] = true, ["4"] = true },
			prem = {},
			mailed = { s0 = true },
		})
		T.expect(Season.sanitize(nil)).toEqual(Season.fresh(""))
		T.expect(Season.sanitize({ points = 1234.9 }).points).toBe(1234)
	end)

	T.it("roll keeps the running season and starts a clean one otherwise (mailed stays)", function()
		local mid = START + 3 * DAY
		local same = Season.roll(at(5000), mid)
		T.expect(same.points).toBe(5000)
		local old = Season.sanitize({ id = "s0", points = 9000, premium = true, mailed = { s0 = true } })
		local new = Season.roll(old, mid)
		T.expect(new).toEqual({
			id = "s1",
			points = 0,
			day = 0,
			dayKill = 0,
			premium = false,
			free = {},
			prem = {},
			mailed = { s0 = true },
		})
		T.expect(old.points).toBe(9000)
		T.expect(Season.roll(at(5000), Season.ends(def)).id).toBe("")
		T.expect(Season.roll(nil, START - 1).id).toBe("")
	end)
end)

T.describe("Season clock (S152)", function()
	T.it("week, tierOf, capAt and the line at the edges", function()
		T.expect(Season.week(def, START - 1)).toBe(0)
		T.expect(Season.week(def, START)).toBe(1)
		T.expect(Season.week(def, START + WEEK - 1)).toBe(1)
		T.expect(Season.week(def, START + WEEK)).toBe(2)
		T.expect(Season.week(def, Season.ends(def) - 1)).toBe(8)
		T.expect(Season.week(def, Season.ends(def) + WEEK)).toBe(8)
		T.expect(Season.ends(def)).toBe(START + 8 * WEEK)
		T.expect({ Season.tierOf(0, def), Season.tierOf(999, def), Season.tierOf(1000, def) }).toEqual({ 0, 0, 1 })
		T.expect(Season.tierOf(10 ^ 9, def)).toBe(40)
		T.expect(Season.progress(12345)).toBe(345)
		T.expect(Season.capAt(def, START)).toBe(6500)
		T.expect(Season.capAt(def, START + 2 * WEEK)).toBe(19500)
		T.expect(Season.capAt(def, Season.ends(def) - 1)).toBe(40 * TP)
		T.expect(Season.lineAt(def, START)).toBe(0)
		T.expect(Season.lineAt(def, START + 4 * WEEK)).toBe(math.floor(0.6 * 40 * TP * 0.5))
	end)
end)

T.describe("Season points (S152)", function()
	local day3 = START + 2 * DAY + 3600

	T.it("a source gives its points, n times, never changing the input", function()
		local s = at(0)
		-- at the very start the catch-up line is 0
		local out, gained, why = Season.add(s, def, "quest", START)
		T.expect({ out.points, gained, why }).toEqual({ Seasons.POINTS.quest, Seasons.POINTS.quest, nil })
		T.expect(s.points).toBe(0)
		local more, n = Season.add(out, def, "daily", START, 3)
		T.expect(n).toBe(3 * Seasons.POINTS.daily)
		T.expect(more.points).toBe(Seasons.POINTS.quest + 3 * Seasons.POINTS.daily)
	end)

	T.it("unknown source and no season", function()
		T.expect({ select(2, Season.add(at(0), def, "robux", day3)) }).toEqual({ 0, "unknown" })
		T.expect({ select(2, Season.add(at(0), nil, "quest", day3)) }).toEqual({ 0, "noSeason" })
		T.expect({ select(2, Season.add(at(0), def, "quest", START - 1)) }).toEqual({ 0, "noSeason" })
		T.expect({ select(2, Season.add(at(0), def, "quest", Season.ends(def))) }).toEqual({ 0, "noSeason" })
		T.expect({ select(2, Season.add(Season.fresh("s0"), def, "quest", day3)) }).toEqual({ 0, "noSeason" })
	end)

	T.it("the daily monster limit, reset at UTC midnight; Elite II and the rest are not limited", function()
		local limit = Seasons.LIMITS.killPerDay
		local s = at(5000) -- above the line: no catch-up
		local now = START + 3 * DAY + 3600
		local out, gained, why = Season.add(s, def, "kill", now, limit) -- 2 x limit points asked
		T.expect({ gained, why, out.dayKill }).toEqual({ limit, "killCap", limit })
		local again, g2, why2 = Season.add(out, def, "elite", now + 60)
		T.expect({ g2, why2 }).toEqual({ 0, "killCap" })
		local e2, g3 = Season.add(again, def, "elite2", now + 60)
		T.expect(g3).toBe(Seasons.POINTS.elite2)
		local midnight = Time.nextDayAt(now)
		local _, g4, why4 = Season.add(e2, def, "kill", midnight - 1)
		T.expect({ g4, why4 }).toEqual({ 0, "killCap" })
		local next, g5, why5 = Season.add(e2, def, "kill", midnight)
		T.expect({ g5, why5, next.dayKill }).toEqual({ Seasons.POINTS.kill, nil, Seasons.POINTS.kill })
	end)

	T.it("the growing cap: 6500 in week 1, 19 500 in week 3, nothing above it", function()
		local cap = Seasons.LIMITS.weekCap
		local nearly = at(cap - 10)
		local out, gained, why = Season.add(nearly, def, "weekly", START + 5 * DAY)
		T.expect({ out.points, gained, why }).toEqual({ cap, 10, "cap" })
		local _, none, why2 = Season.add(out, def, "worldBoss", START + WEEK - 1)
		T.expect({ none, why2 }).toEqual({ 0, "cap" })
		local week2, g = Season.add(out, def, "weekly", START + WEEK)
		T.expect(g).toBe(Seasons.POINTS.weekly)
		T.expect(week2.points).toBe(cap + Seasons.POINTS.weekly)
		-- a player who did not play the first two weeks may hold 19 500 in week 3 (catch-up of missed weeks)
		local late = at(19500 - 100)
		local full, g3, why3 = Season.add(late, def, "weekly", START + 2 * WEEK + DAY)
		T.expect({ full.points, g3, why3 }).toEqual({ 19500, 100, "cap" })
		-- never above the last tier
		local last, g4 = Season.add(at(40 * TP - 5), def, "weekly", Season.ends(def) - 1)
		T.expect({ last.points, g4 }).toEqual({ 40 * TP, 5 })
	end)

	T.it("catch-up x1.5 below the line, up to the line, nothing above it", function()
		local now = START + 4 * WEEK -- line 12 000
		local line = Season.lineAt(def, now)
		T.expect(line).toBe(12000)
		local _, g1 = Season.add(at(0), def, "weekly", now)
		T.expect(g1).toBe(math.floor(Seasons.POINTS.weekly * Seasons.CATCHUP.mul))
		local _, g2 = Season.add(at(line - 50), def, "weekly", now)
		T.expect(g2).toBe(Seasons.POINTS.weekly + 50)
		local _, g3 = Season.add(at(line), def, "weekly", now)
		T.expect(g3).toBe(Seasons.POINTS.weekly)
		local _, g4 = Season.add(at(line + 1), def, "weekly", now)
		T.expect(g4).toBe(Seasons.POINTS.weekly)
		-- the catch-up counts against the daily monster limit like any point
		local s, g5 = Season.add(at(0), def, "kill", now, Seasons.LIMITS.killPerDay)
		T.expect({ g5, s.dayKill }).toEqual({ Seasons.LIMITS.killPerDay, Seasons.LIMITS.killPerDay })
	end)

	T.it("the premium track never changes the points", function()
		for source in Seasons.POINTS do
			for _, points in { 0, 3000, 20000 } do
				local now = START + 3 * WEEK + 3600
				local _, a = Season.add(at(points, false), def, source, now, 3)
				local _, b = Season.add(at(points, true), def, source, now, 3)
				T.expect({ source, points, a }).toEqual({ source, points, b })
			end
		end
	end)
end)

T.describe("Season rewards (S152)", function()
	local now = START + 3 * WEEK

	T.it("canClaim: every refusal", function()
		local s = at(10 * TP)
		T.expect({ Season.canClaim(s, def, 2, "free", now) }).toEqual({ true, nil })
		T.expect({ Season.canClaim(s, def, 12, "free", now) }).toEqual({ false, "season.error.tier" })
		T.expect({ Season.canClaim(s, def, 3, "free", now) }).toEqual({ false, "season.error.noReward" })
		T.expect({ Season.canClaim(s, def, 41, "premium", now) }).toEqual({ false, "season.error.noReward" })
		T.expect({ Season.canClaim(s, def, 2, "gold", now) }).toEqual({ false, "season.error.noReward" })
		T.expect({ Season.canClaim(s, def, 1, "premium", now) }).toEqual({ false, "season.error.noPremium" })
		local claimed = Season.claim(s, 2, "free")
		T.expect({ Season.canClaim(claimed, def, 2, "free", now) }).toEqual({ false, "season.error.claimed" })
		T.expect({ Season.canClaim(Season.fresh("s0"), def, 2, "free", now) }).toEqual({
			false,
			"season.error.noSeason",
		})
		local after = Season.claimUntil(def)
		T.expect({ Season.canClaim(s, def, 2, "free", after) }).toEqual({ true, nil })
		T.expect({ Season.canClaim(s, def, 2, "free", after + 1) }).toEqual({ false, "season.error.ended" })
		T.expect(after).toBe(Season.ends(def) + Seasons.GRACE_DAYS * 86400)
	end)

	T.it("premium tiers reached before the purchase are claimed afterwards", function()
		local s = at(25 * TP)
		T.expect({ Season.canClaim(s, def, 1, "premium", now) }).toEqual({ false, "season.error.noPremium" })
		local bought = Season.buy(s)
		for tier = 1, 25 do
			T.expect({ tier, Season.canClaim(bought, def, tier, "premium", now) }).toEqual({ tier, true })
		end
		T.expect({ Season.canClaim(bought, def, 26, "premium", now) }).toEqual({ false, "season.error.tier" })
	end)

	T.it("claimable and unclaimed", function()
		local s = at(6 * TP)
		T.expect(Season.claimable(s, def)).toEqual({
			{ tier = 2, track = "free" },
			{ tier = 4, track = "free" },
			{ tier = 6, track = "free" },
		})
		local bought = Season.claim(Season.buy(s), 4, "free")
		local list = Season.claimable(bought, def)
		T.expect(#list).toBe(2 + 6)
		T.expect(list[1]).toEqual({ tier = 1, track = "premium" })
		T.expect(list[2]).toEqual({ tier = 2, track = "free" })
		local rewards = Season.unclaimed(bought, def)
		T.expect(#rewards).toBe(8)
		T.expect(rewards[1]).toEqual(def.rewards.premium[1])
		T.expect(Season.claimable(Season.fresh("s0"), def)).toEqual({})
		T.expect(Season.unclaimed(at(0), def)).toEqual({})
	end)

	T.it("pack: a full premium season's items fit one parcel; merged, split at the stack size, chunked", function()
		local full = at(def.tiers * TP, true)
		local counts: { Season.ItemCount } = {}
		for _, reward in Season.unclaimed(full, def) do
			if reward.kind == "item" and reward.id then
				table.insert(counts, { id = reward.id, n = reward.n or 1 })
			end
		end
		T.expect(#counts > Market.Mail.maxItemsPerParcel).toBe(true)
		local parcels = Season.pack(counts)
		T.expect(#parcels).toBe(1)
		T.expect(#parcels[1] <= Market.Mail.maxItemsPerParcel).toBe(true)
		T.expect(Season.pack({ { id = "stone_return", n = 3 }, { id = "stone_return", n = 5 } })).toEqual({
			{ { id = "stone_return", n = 8 } },
		})
		T.expect(Season.pack({ { id = "stone_return", n = 2000 } })).toEqual({
			{ { id = "stone_return", n = 999 }, { id = "stone_return", n = 999 }, { id = "stone_return", n = 2 } },
		})
		local bags = Season.pack({ { id = "backpack_20", n = 3 }, { id = "stone_return", n = 1 } }, 2)
		T.expect(bags).toEqual({
			{ { id = "backpack_20", n = 1 }, { id = "backpack_20", n = 1 } },
			{ { id = "backpack_20", n = 1 }, { id = "stone_return", n = 1 } },
		})
		T.expect(Season.pack({ { id = "stone_return", n = 0 } })).toEqual({})
	end)

	T.it("canBuy: a running season, once", function()
		local s = at(0)
		T.expect({ Season.canBuy(s, def, START) }).toEqual({ true, nil })
		T.expect({ Season.canBuy(s, def, Season.ends(def) - 1) }).toEqual({ true, nil })
		T.expect({ Season.canBuy(s, def, Season.ends(def)) }).toEqual({ false, "season.error.noSeason" })
		T.expect({ Season.canBuy(s, nil, START) }).toEqual({ false, "season.error.noSeason" })
		T.expect({ Season.canBuy(Season.buy(s), def, START) }).toEqual({ false, "season.error.owned" })
		T.expect({ Season.canBuy(Season.fresh("s0"), def, START) }).toEqual({ false, "season.error.noSeason" })
	end)
end)
