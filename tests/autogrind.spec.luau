--!strict
-- Auto Hunt (S134d): the time bank with the daily cap, which monsters it fights, the target, the round over the
-- hunting ground, the order of the stops and the reward (Logic/AutoGrind).

local AutoGrind = require("../src/shared/Logic/AutoGrind")
local Config = require("../src/shared/Config")
local Leaderboards = require("../src/shared/Data/Leaderboards")
local Progression = require("../src/shared/Data/Progression")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")
local UseBlocks = require("../src/shared/Logic/UseBlocks")

local DAY = 86400
local NOW = 20000 * DAY + 3600 -- 01:00 UTC of day 20000
local CAP = Config.AutoGrind.dailySeconds

local function candidate(fields: { [string]: any }): AutoGrind.Candidate
	local c: { [string]: any } = {
		ref = fields.ref or "m",
		variant = "normal",
		boss = false,
		summoned = false,
		fromSpawner = true,
		area = "ground",
		targetable = true,
		level = 30,
		distance = 10,
		fightsOther = false,
		attacksMe = false,
	}
	for k, v in fields do
		c[k] = v
	end
	return c :: any
end

local function snapshot(fields: { [string]: any }): AutoGrind.Snapshot
	local s: { [string]: any } = {
		blocked = nil,
		dead = false,
		left = 600,
		todayLeft = 600,
		outside = false,
		bossNear = false,
		hpPct = 100,
		autoPotionHp = false,
		hasHpPotion = true,
		autoLoot = false,
		freeSlots = 10,
		sinceKill = 0,
		manual = false,
	}
	for k, v in fields do
		s[k] = v
	end
	return s :: any
end

T.describe("S134d AutoGrind bank", function()
	T.it("rollDay forgets the seconds used after midnight UTC, keeps the bank", function()
		local s = { bank = 500, day = Time.dayNumber(NOW), used = 100 }
		T.expect(AutoGrind.rollDay(s, NOW)).toEqual(s)
		T.expect(AutoGrind.rollDay(s, NOW + DAY)).toEqual({ bank = 500, day = Time.dayNumber(NOW) + 1, used = 0 })
		T.expect(AutoGrind.rollDay(nil, NOW)).toEqual({ bank = 0, day = Time.dayNumber(NOW), used = 0 })
	end)

	T.it("left = min(bank, what today's cap allows)", function()
		local today = Time.dayNumber(NOW)
		T.expect(AutoGrind.left({ bank = 600, day = today, used = 0 }, NOW)).toBe(600)
		T.expect(AutoGrind.left({ bank = 10 * 3600, day = today, used = 0 }, NOW)).toBe(CAP)
		T.expect(AutoGrind.left({ bank = 10 * 3600, day = today, used = CAP - 50 }, NOW)).toBe(50)
		T.expect(AutoGrind.todayLeft({ bank = 0, day = today, used = CAP + 5 }, NOW)).toBe(0)
		-- a new day: the cap again
		T.expect(AutoGrind.left({ bank = 10 * 3600, day = today - 1, used = CAP }, NOW)).toBe(CAP)
	end)

	T.it("spend never goes below 0 nor past the cap", function()
		local today = Time.dayNumber(NOW)
		local s = AutoGrind.spend({ bank = 100, day = today, used = 0 }, 30, NOW)
		T.expect(s).toEqual({ bank = 70, day = today, used = 30 })
		T.expect(AutoGrind.spend({ bank = 10, day = today, used = 0 }, 30, NOW))
			.toEqual({ bank = 0, day = today, used = 10 })
		T.expect(AutoGrind.spend({ bank = 9999, day = today, used = CAP - 5 }, 30, NOW)).toEqual({
			bank = 9994,
			day = today,
			used = CAP,
		})
		T.expect(AutoGrind.spend({ bank = 100, day = today, used = 0 }, -5, NOW))
			.toEqual({ bank = 100, day = today, used = 0 })
		T.expect(AutoGrind.add({ bank = 100, day = today, used = 7 }, 1800))
			.toEqual({ bank = 1900, day = today, used = 7 })
		T.expect(AutoGrind.add(nil, -5)).toEqual({ bank = 0, day = 0, used = 0 })
	end)

	T.it("canStart: an empty bank, a used up day", function()
		local today = Time.dayNumber(NOW)
		T.expect({ AutoGrind.canStart(nil, NOW) }).toEqual({ false, "autoGrind.error.none" })
		T.expect({ AutoGrind.canStart({ bank = 60, day = today, used = CAP }, NOW) }).toEqual({
			false,
			"autoGrind.error.daily",
		})
		T.expect({ AutoGrind.canStart({ bank = 60, day = today - 1, used = CAP }, NOW) }).toEqual({ true })
	end)
end)

T.describe("S134d AutoGrind targets", function()
	T.it("eligible: ordinary monsters of the ground only", function()
		T.expect(AutoGrind.eligible(candidate({}), 30, "ground")).toBe(true)
		local cases: { { [string]: any } } = {
			{ variant = "elite" },
			{ variant = "elite2" },
			{ variant = "boss" },
			{ boss = true },
			{ summoned = true },
			{ fromSpawner = false },
			{ area = "other" },
			{ targetable = false },
			{ fightsOther = true },
			{ level = 30 + Config.AutoGrind.levelGap + 1 },
			{ level = 30 - Config.AutoGrind.levelGap - 1 },
		}
		for i, change in cases do
			T.expect({ i, AutoGrind.eligible(candidate(change), 30, "ground") }).toEqual({ i, false })
		end
		T.expect(AutoGrind.eligible(candidate({ level = 30 + Config.AutoGrind.levelGap }), 30, "ground")).toBe(true)
	end)

	T.it("pickTarget: the attacker before the nearest, nothing past seekRadius", function()
		local near = candidate({ ref = "near", distance = 5 })
		local attacker = candidate({ ref = "attacker", distance = 25, attacksMe = true })
		local far = candidate({ ref = "far", distance = Config.AutoGrind.seekRadius + 1 })
		local elite = candidate({ ref = "elite", distance = 1, variant = "elite", attacksMe = true })
		local picked = AutoGrind.pickTarget({ near, attacker, far, elite }, 30, "ground")
		T.expect(picked and picked.ref).toBe("attacker")
		picked = AutoGrind.pickTarget({ far, near }, 30, "ground")
		T.expect(picked and picked.ref).toBe("near")
		T.expect(AutoGrind.pickTarget({ far, elite }, 30, "ground")).toBeNil()
		-- an attacker further than seekRadius still counts (it is hitting the player)
		local farAttacker =
			candidate({ ref = "farAttacker", distance = Config.AutoGrind.seekRadius + 20, attacksMe = true })
		picked = AutoGrind.pickTarget({ near, farAttacker }, 30, "ground")
		T.expect(picked and picked.ref).toBe("farAttacker")
	end)

	T.it("nextGoal walks the whole ground, skips empty groups, starts the round again", function()
		local groups: { AutoGrind.Group } = {
			{ id = "a", area = "ground", x = 10, z = 0, ready = true },
			{ id = "b", area = "ground", x = 50, z = 0, ready = true },
			{ id = "c", area = "ground", x = 100, z = 0, ready = false },
			{ id = "x", area = "elsewhere", x = 1, z = 0, ready = true },
		}
		local visited: { [string]: boolean } = {}
		local at = { x = 0, z = 0 }
		local goal = AutoGrind.nextGoal(groups, visited, at, "ground")
		T.expect(goal and goal.id).toBe("a")
		visited.a = true
		goal = AutoGrind.nextGoal(groups, visited, { x = 10, z = 0 }, "ground")
		T.expect(goal and goal.id).toBe("b")
		visited.b = true
		-- every ready group visited: the round starts again (c waits for its respawn, x is another ground)
		goal = AutoGrind.nextGoal(groups, visited, { x = 50, z = 0 }, "ground")
		T.expect(goal and goal.id).toBe("b")
		T.expect(visited.a).toBeNil()
		T.expect(AutoGrind.nextGoal({ groups[3], groups[4] }, {}, at, "ground")).toBeNil()
		T.expect(AutoGrind.arrived({ x = 0, z = 0 }, { x = Config.AutoGrind.arrive, z = 0 })).toBe(true)
		T.expect(AutoGrind.arrived({ x = 0, z = 0 }, { x = Config.AutoGrind.arrive + 1, z = 0 })).toBe(false)
	end)

	T.it("inside: the rectangle widened by the margin", function()
		local rect = { -100, -50, 100, 50 }
		T.expect(AutoGrind.inside(rect, 0, 0, 0)).toBe(true)
		T.expect(AutoGrind.inside(rect, 120, 0, 0)).toBe(false)
		T.expect(AutoGrind.inside(rect, 120, 0, Config.AutoGrind.leaveMargin)).toBe(true)
		T.expect(AutoGrind.inside(rect, 0, -50 - Config.AutoGrind.leaveMargin - 1, Config.AutoGrind.leaveMargin))
			.toBe(false)
	end)

	T.it("groundAt: a named area or a whole cave, nothing on other maps", function()
		local area, rect, nameKey = AutoGrind.groundAt("meadows_cave", 4000, 4000)
		T.expect(area).toBe("meadows_cave")
		T.expect(rect ~= nil and nameKey ~= nil).toBe(true)
		T.expect(AutoGrind.groundAt("city", 0, 0)).toBeNil()
		T.expect(AutoGrind.groundAt("nowhere", 0, 0)).toBeNil()
	end)
end)

T.describe("S134d AutoGrind stops and reward", function()
	T.it("stopReason follows one order", function()
		T.expect(AutoGrind.stopReason(snapshot({}))).toBeNil()
		T.expect({ AutoGrind.stopReason(snapshot({ blocked = "city", dead = true, left = 0 })) }).toEqual({
			"blocked",
			"city",
		})
		T.expect(AutoGrind.stopReason(snapshot({ dead = true, left = 0, manual = true }))).toBe("dead")
		T.expect(AutoGrind.stopReason(snapshot({ left = 0, outside = true }))).toBe("noTime")
		T.expect(AutoGrind.stopReason(snapshot({ left = 0, todayLeft = 0 }))).toBe("daily")
		T.expect(AutoGrind.stopReason(snapshot({ outside = true, bossNear = true }))).toBe("left")
		T.expect(AutoGrind.stopReason(snapshot({ bossNear = true, hpPct = 1 }))).toBe("bossNear")
		T.expect(AutoGrind.stopReason(snapshot({ hpPct = Config.AutoGrind.stopHpPct - 1 }))).toBe("lowHp")
		-- with Auto Potions drinking HP: low HP is theirs, no potions stops
		T.expect(AutoGrind.stopReason(snapshot({ hpPct = 1, autoPotionHp = true }))).toBeNil()
		T.expect(AutoGrind.stopReason(snapshot({ autoPotionHp = true, hasHpPotion = false }))).toBe("noPotions")
		T.expect(AutoGrind.stopReason(snapshot({ autoLoot = true, freeSlots = 0, sinceKill = 9999 }))).toBe("bagFull")
		T.expect(AutoGrind.stopReason(snapshot({ autoLoot = false, freeSlots = 0 }))).toBeNil()
		T.expect(AutoGrind.stopReason(snapshot({ sinceKill = Config.AutoGrind.stuckSeconds, manual = true })))
			.toBe("stuck")
		T.expect(AutoGrind.stopReason(snapshot({ manual = true }))).toBe("manual")
	end)

	T.it("every stop and every block has a text", function()
		local pl = require("../src/shared/Data/Localization/pl") :: any
		local en = require("../src/shared/Data/Localization/en") :: any
		for _, stop in AutoGrind.STOPS do
			if stop ~= "blocked" then
				local key = AutoGrind.stopKey(stop, nil)
				T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			end
		end
		for _, reason in UseBlocks.LISTS.autoGrind do
			local key = AutoGrind.stopKey("blocked", reason)
			T.expect(key).toBe(`autoGrind.block.{reason}`)
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)

	T.it("the reward is 70 % of EXP and gold with the source outside the weekly ranking", function()
		T.expect(Progression.autoGrindExpPct).toBe(70)
		T.expect(Progression.autoGrindGoldPct).toBe(70)
		T.expect({ AutoGrind.reward(100, 10) }).toEqual({ 70, 7, "autoGrind" })
		T.expect({ AutoGrind.reward(1, 1) }).toEqual({ 1, 1, "autoGrind" })
		T.expect({ AutoGrind.reward(0, 0) }).toEqual({ 0, 0, "autoGrind" })
		T.expect(Leaderboards.WEEK_SOURCES[AutoGrind.SOURCE]).toBeNil()
		T.expect(Leaderboards.WEEK_SOURCES.monster).toBe(true)
		local args = AutoGrind.descArgs()
		T.expect(args.hours).toBe(Config.AutoGrind.dailySeconds / 3600)
		T.expect(args.scroll).toBe(Config.AutoGrind.scrollSeconds // 60)
	end)
end)

return nil
