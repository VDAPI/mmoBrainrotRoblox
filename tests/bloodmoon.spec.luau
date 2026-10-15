--!strict
-- Blood Moon rules (S129, DESIGN-17 §7): regions and the red-zone overlay, points, the sort key, reward tiers, the
-- character state, the Elite roll, the title and frame data and the in-memory board the ranking falls back to
-- (Logic/BloodMoon, Logic/Leaderboard.memoryBoard behind Leaderboard/Stores.sorted).
local Blessings = require("../src/shared/Data/Blessings")
local BloodMoon = require("../src/shared/Logic/BloodMoon")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Items = require("../src/shared/Data/Items")
local Leaderboard = require("../src/shared/Logic/Leaderboard")
local Maps = require("../src/shared/Data/Maps")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Schedule = require("../src/shared/Logic/Schedule")
local ScheduledEvents = require("../src/shared/Data/ScheduledEvents")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")
local TitleData = require("../src/shared/Data/Titles")
local Titles = require("../src/shared/Logic/Titles")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local RULES = ScheduledEvents.bloodMoon
local REGIONS = { "meadows", "duskwood", "ashen", "frostpeak" }
local START = 1791918000 -- Tuesday 2026-10-13 19:00 UTC

T.describe("BloodMoon: regions", function()
	T.it("the four open regions and their caves count, the city and dungeons do not", function()
		T.expect(RULES.regions).toEqual(REGIONS)
		for _, id in REGIONS do
			T.expect(BloodMoon.regionOf(id)).toBe(id)
			T.expect(BloodMoon.isEventMap(id)).toBe(true)
		end
		local caves = 0
		for id, map in Maps.byId do
			if map.biome == "cave" or map.biome == "crypt" then
				caves += 1
				local region = BloodMoon.regionOf(id)
				T.expect({ id, region ~= nil and table.find(REGIONS, region) ~= nil }).toEqual({ id, true })
				T.expect(BloodMoon.isEventMap(id)).toBe(false)
			elseif map.biome == "dungeon" then
				T.expect({ id, BloodMoon.regionOf(id) }).toEqual({ id, nil })
			end
		end
		T.expect(caves >= 4).toBe(true)
		T.expect(BloodMoon.regionOf("city")).toBeNil()
		T.expect(BloodMoon.regionOf("dungeon_meadows")).toBeNil()
		T.expect(BloodMoon.regionOf("meadows_cave")).toBe("meadows")
		T.expect(BloodMoon.isEventMap("meadows_cave")).toBe(false)
		T.expect(BloodMoon.regionOf("no_such_map")).toBeNil()
	end)

	T.it("turns yellow red in the open regions only while active", function()
		T.expect(BloodMoon.forcedZone("meadows", "yellow", true)).toBe("red")
		T.expect(BloodMoon.forcedZone("meadows", "yellow", false)).toBe("yellow")
		T.expect(BloodMoon.forcedZone("meadows", "green", true)).toBe("green")
		T.expect(BloodMoon.forcedZone("city", "green", true)).toBe("green")
		T.expect(BloodMoon.forcedZone("meadows_cave", "red", true)).toBe("red")
		T.expect(BloodMoon.forcedZone("meadows_cave", "yellow", true)).toBe("yellow")
		T.expect(BloodMoon.forcedZone("frostpeak", "yellow", true)).toBe("red")
	end)
end)

T.describe("BloodMoon: points", function()
	T.it("10 for a player unless far weaker or counted twice; Elites 1 and 5", function()
		T.expect(BloodMoon.playerPoints({ killerLevel = 30, victimLevel = 23, prior = 0 })).toBe(10)
		T.expect(BloodMoon.playerPoints({ killerLevel = 30, victimLevel = 22, prior = 0 })).toBe(0)
		T.expect(BloodMoon.playerPoints({ killerLevel = 30, victimLevel = 40, prior = 0 })).toBe(10)
		T.expect(BloodMoon.playerPoints({ killerLevel = 30, victimLevel = 30, prior = 1 })).toBe(10)
		T.expect(BloodMoon.playerPoints({ killerLevel = 30, victimLevel = 30, prior = 2 })).toBe(0)
		T.expect(BloodMoon.noPointsKey({ killerLevel = 30, victimLevel = 22, prior = 0 }))
			.toBe("bloodmoon.noPoints.level")
		T.expect(BloodMoon.noPointsKey({ killerLevel = 30, victimLevel = 30, prior = 2 }))
			.toBe("bloodmoon.noPoints.repeat")
		T.expect(BloodMoon.noPointsKey({ killerLevel = 30, victimLevel = 30, prior = 0 })).toBeNil()
		T.expect(BloodMoon.monsterPoints("elite")).toBe(1)
		T.expect(BloodMoon.monsterPoints("elite2")).toBe(5)
		T.expect(BloodMoon.monsterPoints("normal")).toBe(0)
	end)

	T.it("sorts by points, then by who reached them first", function()
		T.expect(BloodMoon.sortKey(25, START + 100, START) > BloodMoon.sortKey(25, START + 200, START)).toBe(true)
		T.expect(BloodMoon.sortKey(26, START + 1700, START) > BloodMoon.sortKey(25, START, START)).toBe(true)
		T.expect(BloodMoon.pointsOf(BloodMoon.sortKey(37, START + 900, START))).toBe(37)
		T.expect(BloodMoon.sortKey(5, START - 50, START)).toBe(BloodMoon.sortKey(5, START, START))
		T.expect(BloodMoon.pointsOf(BloodMoon.sortKey(5, START + 99999, START))).toBe(5)
		T.expect(BloodMoon.sortKey(0, START, START) >= 0).toBe(true)
	end)
end)

T.describe("BloodMoon: rewards", function()
	T.it("every tier needs participation", function()
		local none = BloodMoon.tierOf(4, 1)
		T.expect(none).toEqual({ participation = false, title = false, frame = false, winner = false })
		T.expect(BloodMoon.tierOf(5, nil))
			.toEqual({ participation = true, title = false, frame = false, winner = false })
		T.expect(BloodMoon.tierOf(5, 100))
			.toEqual({ participation = true, title = true, frame = false, winner = false })
		T.expect(BloodMoon.tierOf(5, 101))
			.toEqual({ participation = true, title = false, frame = false, winner = false })
		T.expect(BloodMoon.tierOf(5, 10)).toEqual({ participation = true, title = true, frame = true, winner = false })
		T.expect(BloodMoon.tierOf(5, 1)).toEqual({ participation = true, title = true, frame = true, winner = true })
		T.expect(BloodMoon.tierIndex(BloodMoon.tierOf(5, 1))).toBe(4)
		T.expect(BloodMoon.tierIndex(none)).toBe(0)
	end)

	T.it("rewards from the data (DESIGN-17 §7)", function()
		local winner = BloodMoon.rewardsOf(BloodMoon.tierOf(50, 1))
		T.expect(winner).toEqual({
			tokens = 20,
			blessing = true,
			titleId = "bloodmoon",
			titleDays = 7,
			frameId = "frame_bloodmoon",
			shards = 100,
		})
		local part = BloodMoon.rewardsOf(BloodMoon.tierOf(5, nil))
		T.expect(part).toEqual({ tokens = 20, blessing = true, shards = 0 })
		T.expect(BloodMoon.rewardsOf(BloodMoon.tierOf(4, 1))).toEqual({ tokens = 0, blessing = false, shards = 0 })
		T.expect(BloodMoon.rewardsOf(BloodMoon.tierOf(9, 7)).shards).toBe(0)
		T.expect(BloodMoon.rewardsOf(BloodMoon.tierOf(9, 7)).frameId).toBe("frame_bloodmoon")
	end)

	T.it("best rank among the regions with points", function()
		local state = BloodMoon.addPoints(BloodMoon.newState("x"), "meadows", 10, START + 5)
		state = BloodMoon.addPoints(state, "ashen", 5, START + 9)
		local ranks = { meadows = { k = 40 }, ashen = { k = 3 }, duskwood = { k = 1 } }
		T.expect(BloodMoon.bestRank(state, "k", ranks)).toBe(3)
		T.expect(BloodMoon.bestRank(state, "other", ranks)).toBeNil()
		T.expect(BloodMoon.bestRank(state, "k", nil)).toBeNil()
	end)
end)

T.describe("BloodMoon: state", function()
	T.it("starts empty and adds without touching the input", function()
		local fresh = BloodMoon.newState("x")
		T.expect(fresh).toEqual({ id = "x", points = 0, kills = {}, regions = {}, at = 0, paid = false })
		local one = BloodMoon.addPoints(fresh, "meadows", 10, START + 60)
		T.expect(fresh.points).toBe(0)
		T.expect(fresh.regions.meadows).toBeNil()
		T.expect(one.points).toBe(10)
		T.expect(one.regions.meadows).toBe(10)
		T.expect(one.at).toBe(START + 60)
		local two = BloodMoon.addPoints(one, "meadows", 5, START + 90)
		T.expect(two.regions.meadows).toBe(15)
		T.expect(one.regions.meadows).toBe(10)
		local zero = BloodMoon.addPoints(two, "ashen", 0, START + 120)
		T.expect(zero.at).toBe(START + 90)
		T.expect(zero.regions.ashen).toBeNil()
		local killed = BloodMoon.countKill(two, "5_1")
		T.expect(killed.kills["5_1"]).toBe(1)
		T.expect(two.kills["5_1"]).toBeNil()
		T.expect(BloodMoon.countKill(killed, "5_1").kills["5_1"]).toBe(2)
	end)

	T.it("knows the span of an occurrence from its id", function()
		T.expect({ BloodMoon.spanOf("20261013") }).toEqual({ START, START + 1800 })
		T.expect({ BloodMoon.spanOf("20261015") }).toEqual({ START + 2 * 86400, START + 2 * 86400 + 1800 })
		local forced = BloodMoon.forcedId(START + 5 * 60 + 7)
		T.expect(forced).toBe("t202610131145")
		T.expect(BloodMoon.isForcedId(forced)).toBe(true)
		T.expect(BloodMoon.isForcedId("20261013")).toBe(false)
		T.expect((BloodMoon.spanOf(forced))).toBe(START + 5 * 60)
		T.expect({ BloodMoon.spanOf("garbage") }).toEqual({})
		for day = 0, 800 do
			local t = 1767225600 + day * 86400
			local year, month, d = string.match(Schedule.dateKey(t), "(%d+)(%d%d)(%d%d)$")
			T.expect(Time.fromCivil(tonumber(year) :: number, tonumber(month) :: number, tonumber(d) :: number))
				.toBe(t // 86400)
		end
	end)

	T.it("shows the panel 10 min before, during and while results are published", function()
		T.expect(BloodMoon.phaseOf(START - 601, "", 0, START, false)).toBeNil()
		T.expect(BloodMoon.phaseOf(START - 600, "", 0, START, false)).toBe("soon")
		T.expect(BloodMoon.phaseOf(START + 5, "20261013", START + 1800, START + 2 * 86400, false)).toBe("active")
		T.expect(BloodMoon.phaseOf(START + 1800, "", START + 1800, START + 2 * 86400, true)).toBe("ended")
		T.expect(BloodMoon.phaseOf(START + 1800, "", START + 1800, START + 2 * 86400, false)).toBeNil()
		T.expect({ BloodMoon.when(START) }).toEqual({ 2, "19:00" })
	end)
end)

T.describe("BloodMoon: Elites", function()
	T.it("rolls about eliteChance, the same on the same seed", function()
		local rng = Rng.new(129)
		local hits = 0
		local n = 20000
		for _ = 1, n do
			if BloodMoon.rollElite(rng) then
				hits += 1
			end
		end
		T.expect(hits / n).toBeNear(RULES.eliteChance, RULES.eliteChance * 0.1)
		local a, b = Rng.new(7), Rng.new(7)
		for _ = 1, 50 do
			T.expect(BloodMoon.rollElite(a)).toBe(BloodMoon.rollElite(b))
		end
	end)
end)

T.describe("BloodMoon: title, frame and blessing data", function()
	T.it("the title is timed, the frame is never sold, the blessing exists for every line", function()
		local title = TitleData.get(RULES.reward.titleId)
		T.expect(title ~= nil).toBe(true)
		T.expect((title :: any).req.kind).toBe("timed")
		T.expect((title :: any).nameKey).toBe("title.bloodmoon")
		T.expect(pl["title.bloodmoon"] ~= nil and en["title.bloodmoon"] ~= nil).toBe(true)
		T.expect(Titles.timedUntil({ timedTitles = { bloodmoon = 100 } }, "bloodmoon")).toBe(100)
		local frame = Cosmetics.get(RULES.reward.frameId)
		T.expect(frame ~= nil).toBe(true)
		T.expect((frame :: any).kind).toBe("frame")
		T.expect((frame :: any).obtain).toEqual({ event = "bloodmoon" })
		T.expect((frame :: any).frame ~= nil).toBe(true)
		T.expect(pl["cosmetic.frame_bloodmoon"] ~= nil and en["cosmetic.frame_bloodmoon"] ~= nil).toBe(true)
		T.expect(RULES.reward.blessingRarity).toBe(Rarities.UNIQUE)
		for _, line in Blessings.lines do
			T.expect({ line, Items.get(BloodMoon.blessingItem(line)) ~= nil }).toEqual({ line, true })
		end
	end)
end)

T.describe("BloodMoon: board fallback", function()
	T.it("the in-memory board ranks by sort key and overwrites a key", function()
		local board = Leaderboard.memoryBoard()
		board.set("a", BloodMoon.sortKey(10, START + 50, START), { n = "A" })
		board.set("b", BloodMoon.sortKey(20, START + 80, START), { n = "B" })
		board.set("c", BloodMoon.sortKey(10, START + 20, START), { n = "C" })
		local top = board.top(2, START)
		T.expect({ top[1].key, top[2].key }).toEqual({ "b", "c" })
		board.set("a", BloodMoon.sortKey(30, START + 400, START), { n = "A" })
		top = board.top(3, START)
		T.expect({ top[1].key, top[2].key, top[3].key }).toEqual({ "a", "b", "c" })
		T.expect(BloodMoon.pointsOf(top[1].score)).toBe(30)
		T.expect(BloodMoon.boardId("20261013", "ashen")).toBe("BloodMoon_20261013_ashen")
	end)
end)
