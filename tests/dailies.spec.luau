--!strict
-- S159 (owner 2026-10-20, docs/DESIGN.md §20): daily and weekly sets: groups, weights, the reroll, the set bonus, the
-- account's streak and the Dragon Shards ceiling, and the EXP of the sets against the pre-S159 pace.

local Config = require("../src/shared/Config")
local Dailies = require("../src/shared/Logic/Dailies")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local Products = require("../src/shared/Data/Products")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Daily, Weekly = Quests.Daily, Quests.Weekly

local function slotOf(entry: any): string?
	local template = Daily.get(entry.template)
	return template and template.slot
end

describe("Daily sets: the draw (S159)", function()
	it("4 distinct contracts a day, one combat and one gather first, never PvP in those slots", function()
		for day = 20000, 20200 do
			for _, level in { 1, 12, 30, 60, 99 } do
				local list = QuestLogic.dailyFor(777, "char-x", day, level)
				expect(#list).toBe(Daily.PER_DAY)
				expect(slotOf(list[1])).toBe("combat")
				expect(slotOf(list[2])).toBe("gather")
				local seen: { [string]: boolean } = {}
				for i, entry in list do
					expect(seen[entry.template]).toBeNil()
					seen[entry.template] = true
					local template = Daily.get(entry.template)
					assert(template, entry.template)
					expect(template.minLevel <= level).toBe(true)
					if i <= #Daily.SLOTS then
						expect(template.pvp == true).toBe(false)
					end
				end
			end
		end
	end)

	it("is deterministic and varies from day to day", function()
		local a = QuestLogic.dailyFor(42, "c1", 20500, 40)
		local b = QuestLogic.dailyFor(42, "c1", 20500, 40)
		for i, entry in a do
			expect(b[i].template).toBe(entry.template)
		end
		local seen: { [string]: number } = {}
		for day = 20500, 20899 do
			for _, entry in QuestLogic.dailyFor(42, "c1", day, 40) do
				seen[entry.template] = (seen[entry.template] or 0) + 1
			end
		end
		-- every template open at 40 comes up; the PvP one (half weight, free slots only) the least of its group
		for _, template in Daily.templates do
			expect((seen[template.id] or 0) > 0).toBe(true)
		end
		expect(seen.duels < seen.handin).toBe(true)
	end)

	it("the hunts count monsters in the level range only", function()
		local hunt = (Daily.get("hunt") :: any).objective(30)
		expect(hunt.lvMin).toBe(25)
		expect(hunt.region).toBeNil()
		expect(QuestLogic.amount(hunt, "kill", { monsterId = "wolf", level = 24 }, 0)).toBe(0)
		expect(QuestLogic.amount(hunt, "kill", { monsterId = "wolf", level = 25 }, 0)).toBe(1)
		expect(QuestLogic.amount(hunt, "kill", { monsterId = "wolf", level = 60 }, 0)).toBe(1)
		expect(((Daily.get("hunt") :: any).objective(1)).lvMin).toBe(1)
		local elites = (Weekly.get("elites") :: any).objective(50)
		expect(QuestLogic.amount(elites, "kill", { monsterId = "wolf", level = 50, variant = "normal" }, 0)).toBe(0)
		expect(QuestLogic.amount(elites, "kill", { monsterId = "wolf", level = 50, variant = "elite" }, 0)).toBe(1)
	end)

	it("hand-ins and dismantles count every item of the event", function()
		local handin = { type = "handin", n = 2 }
		expect(QuestLogic.amount(handin, "quest", { kind = "contract", n = 3 }, 0)).toBe(3)
		expect(QuestLogic.amount(handin, "quest", { kind = "side", questId = "x" }, 0)).toBe(1)
		expect(QuestLogic.amount(handin, "kill", {}, 0)).toBe(0)
		local dismantle = { type = "dismantle", n = 5 }
		expect(QuestLogic.amount(dismantle, "dismantle", { n = 4 }, 0)).toBe(4)
		expect(QuestLogic.amount(dismantle, "dismantle", {}, 0)).toBe(1)
		local duel = { type = "duel", n = 2 }
		expect(QuestLogic.amount(duel, "duel", { won = false, arena = true }, 0)).toBe(1)
	end)
end)

describe("Daily sets: the reroll (S159)", function()
	it("replaces an open contract by another of the same group not on the list", function()
		for day = 21000, 21100 do
			local list = QuestLogic.dailyFor(9, "c", day, 50)
			for index = 1, #list do
				local entry = QuestLogic.rerollDaily(list, index, 9, "c", day, 50, 1)
				assert(entry, "entry")
				expect(entry.progress).toBe(0)
				for _, other in list do
					expect(entry.template ~= other.template).toBe(true)
				end
				local gathers = 0
				for _, other in list do
					gathers += if slotOf(other) == "gather" then 1 else 0
				end
				if index == 2 and gathers < 3 then
					expect(slotOf(entry)).toBe("gather") -- another of herbs / ore / fish while one is left
				end
			end
		end
	end)

	it("one free reroll a day, never on a claimed or finished contract", function()
		local list = QuestLogic.dailyFor(9, "c", 21000, 50)
		local daily: any = { day = 21000, list = list, rerolls = 0, swaps = 0 }
		expect((Dailies.canReroll(daily, 1))).toBe(true)
		expect((Dailies.canReroll(daily, 9))).toBe(false)
		daily.list[1].progress = daily.list[1].objective.n
		local ok, err = Dailies.canReroll(daily, 1)
		expect(ok).toBe(false)
		expect(err).toBe("quest.reroll.done")
		daily.list[2].claimed = true
		expect((Dailies.canReroll(daily, 2))).toBe(false)
		daily.swaps = Daily.REROLLS
		ok, err = Dailies.canReroll(daily, 3)
		expect(ok).toBe(false)
		expect(err).toBe("quest.reroll.used")
		-- an old save without `swaps`
		expect((Dailies.canReroll({ list = QuestLogic.dailyFor(9, "c", 21001, 50) }, 1))).toBe(true)
	end)
end)

describe("Daily sets: the bonus and the streak (S159)", function()
	it("the bonus is due once every contract is claimed, once", function()
		local list = QuestLogic.dailyFor(1, "c", 22000, 20)
		local daily: any = { day = 22000, list = list }
		expect(Dailies.bonusDue(daily)).toBe(false)
		for _, entry in list do
			entry.progress = entry.objective.n
		end
		expect(Dailies.progress(list).complete).toBe(#list)
		expect(Dailies.bonusDue(daily)).toBe(false)
		for _, entry in list do
			entry.claimed = true
		end
		expect(Dailies.bonusDue(daily)).toBe(true)
		daily.bonus = true
		expect(Dailies.bonusDue(daily)).toBe(false)
		expect(Dailies.bonusDue({ list = {} })).toBe(false)
	end)

	it("the streak grows day by day, keeps on the same day and starts again after a gap", function()
		local s = Dailies.fresh()
		local streak
		s, streak = Dailies.fullDay(s, 100)
		expect(streak).toBe(1)
		s, streak = Dailies.fullDay(s, 100) -- another character the same day
		expect(streak).toBe(1)
		s, streak = Dailies.fullDay(s, 101)
		expect(streak).toBe(2)
		expect(Dailies.streakNow(s, 102)).toBe(2)
		expect(Dailies.nextStreak(s, 102)).toBe(3)
		expect(Dailies.streakNow(s, 103)).toBe(0)
		s, streak = Dailies.fullDay(s, 104)
		expect(streak).toBe(1)
		expect(Dailies.sanitize({ streak = -3, last = "x" })).toEqual(Dailies.fresh())
	end)

	it("the bonus grows with the streak up to the cap and pays shards once per account and period", function()
		local L = 40
		local last = 0
		for streak = 1, Daily.STREAK_CAP + 3 do
			local b = Daily.bonus(L, streak)
			expect(b.exp >= last).toBe(true)
			last = b.exp
		end
		expect(Daily.bonus(L, Daily.STREAK_CAP + 3).exp).toBe(Daily.bonus(L, Daily.STREAK_CAP).exp)
		expect(Daily.bonus(L, 1).shards).toBe(Daily.BONUS.shards)
		expect(Daily.bonus(L, Daily.BONUS.streakShardsFrom).shards).toBe(Daily.BONUS.shards + Daily.BONUS.streakShards)
		local s = Dailies.fresh()
		expect(Dailies.dayShardsDue(s, 5, Daily.SHARD_MIN_LEVEL - 1)).toBe(false)
		expect(Dailies.dayShardsDue(s, 5, Daily.SHARD_MIN_LEVEL)).toBe(true)
		s.shardDay = 5
		expect(Dailies.dayShardsDue(s, 5, 50)).toBe(false)
		expect(Dailies.dayShardsDue(s, 6, 50)).toBe(true)
		s.shardWeek = 2963
		expect(Dailies.weekShardsDue(s, 2963, 50)).toBe(false)
		expect(Dailies.weekShardsDue(s, 2964, 50)).toBe(true)
		for _, level in { 1, 15, 35, 45, 99 } do
			for _, reward in { Daily.bonus(level, 3), Weekly.bonus(level), Daily.reward(level), Weekly.reward(level) } do
				for _, item in reward.items or {} do
					expect(Items.get(item.id) ~= nil).toBe(true)
				end
			end
		end
	end)
end)

describe("Daily sets: economy (S159)", function()
	it("the shards of the sets stay far below VIP and the shop: at most 30 a week", function()
		local cap = Dailies.weekShardCap()
		expect(cap).toBe(29) -- 7 x 3 at a full streak + 8 for the week (DESIGN §20)
		expect(cap <= 0.3 * 7 * Config.Vip.dailyShards).toBe(true)
		-- the season pass takes 20+ weeks of full sets, the cheapest shop entry about two
		expect(Products.seasonPass.price / cap >= 20).toBe(true)
		local cheapest = math.huge
		for _, entry in Products.shop do
			cheapest = math.min(cheapest, entry.price)
		end
		expect(cheapest / cap >= 1.5).toBe(true)
	end)

	it("the EXP of a full week of sets stays within 10% of the pre-S159 pace", function()
		for _, L in { 5, 20, 45, 70, 99 } do
			local need = Exp.expToNext(L)
			local now = 7 * Daily.dayExp(L, Daily.STREAK_CAP)
				+ Weekly.PER_WEEK * Weekly.reward(L).exp
				+ Weekly.bonus(L).exp
				+ Weekly.bossReward(L).exp
			local before = (7 * 3 * 0.15 + 3 * 0.30 + 0.5) * need -- S11 / S98: 4.55 levels a week
			expect(now <= before * 1.10).toBe(true)
			expect(now >= before * 0.95).toBe(true)
		end
	end)

	it("every template and the new texts exist in both languages", function()
		for _, lang in { pl, en } :: { any } do
			for _, template in Daily.templates do
				expect(lang[`daily.{template.id}.title`] ~= nil).toBe(true)
			end
			for _, template in Weekly.templates do
				expect(lang[`weekly.{template.id}.title`] ~= nil).toBe(true)
			end
			for _, t in { "handin", "dismantle", "killLevel", "killEliteLevel" } do
				expect(lang[`quest.obj.{t}`] ~= nil).toBe(true)
			end
		end
	end)
end)

return nil
