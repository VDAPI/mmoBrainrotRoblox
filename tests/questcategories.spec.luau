--!strict
-- S98 (docs/DESIGN-15.md §3.1): quest categories, boss quests, weeks, weekly contracts and the boss contract.

local fs = require("@lune/fs")

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Bosses = require("../src/shared/Data/Bosses")
local BossScaling = require("../src/shared/Logic/BossScaling")
local Caves = require("../src/shared/Data/Areas/Caves")
local Items = require("../src/shared/Data/Items")
local Npcs = require("../src/shared/Data/Npcs")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local SideQuests = require("../src/shared/Logic/SideQuests")
local Time = require("../src/shared/Logic/Time")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function emptyQuests(): any
	return {
		main = nil,
		mainDone = 999,
		daily = { day = 0, list = {}, rerolls = 0 },
		side = { active = {}, done = {} },
	}
end

describe("Quest categories (S98)", function()
	it("every quest has its category", function()
		for _, q in Quests.Main.list do
			expect(q.category).toBe("main")
		end
		for _, q in Quests.Side.list do
			expect(q.category).toBe("side")
		end
		for _, q in Quests.Boss.list do
			expect(q.category).toBe("boss")
		end
		local stable = 0
		for _, q in Quests.Side.list do
			if q.arc == "stable" then
				stable += 1
				expect(q.category).toBe("side")
			end
		end
		expect(stable).toBe(3)
		expect(Quests.categoryOf("arrival")).toBe("main")
		expect(Quests.categoryOf("side_stable_ride")).toBe("side")
		expect(Quests.categoryOf("boss_grimrok")).toBe("boss")
		expect(Quests.categoryOf("nope")).toBeNil()
		expect(Quests.CATEGORIES).toEqual({ "main", "side", "contract", "boss", "daily", "weekly" })
	end)

	it("npcList is the side quests and the boss quests without duplicates", function()
		expect(#Quests.npcList).toBe(#Quests.Side.list + #Quests.Boss.list)
		local seen: { [string]: boolean } = {}
		for _, q in Quests.npcList do
			expect(seen[q.id]).toBeNil()
			seen[q.id] = true
			expect(Quests.npcQuest(q.id)).toBe(q)
		end
		expect(Quests.npcQuest("boss_morvane")).toBe(Quests.Boss.get("boss_morvane"))
		expect(Quests.npcQuest(Quests.Side.list[1].id)).toBe(Quests.Side.list[1])
	end)
end)

describe("Boss quests (S98)", function()
	it("one Slayer quest per boss at the region's scout from the entry level", function()
		expect(#Quests.Boss.list).toBe(#Bosses.list)
		for _, def in Bosses.list do
			local q = Quests.Boss.ofBoss(def.id)
			assert(q, `no boss quest for {def.id}`)
			expect(q.id).toBe("boss_" .. def.id)
			expect(q.giver).toBe("scout_" .. def.region)
			expect(q.turnIn).toBe(q.giver)
			expect(Npcs.get(q.giver) ~= nil).toBe(true)
			local entry = BossScaling.requiredLevel(def.level)
			expect(q.level).toBe(entry)
			expect(q.minLevel).toBe(entry)
			expect(#q.objectives).toBe(1)
			expect(q.objectives[1].type).toBe("boss")
			expect(q.objectives[1].boss).toBe(def.id)
			local where = q.where
			assert(where, "where")
			local cave = Caves.get(where.map)
			assert(cave, `no cave {where.map}`)
			expect(cave.boss).toBe(true)
			expect(cave.region).toBe(def.region)
			local items = q.reward.items or {}
			expect(items[1].id).toBe("stone_dungeon_" .. def.region)
			expect(Items.get(items[1].id) ~= nil).toBe(true)
			expect(q.reward.choice).toBeNil()
		end
	end)

	it("can be taken from the entry level, not a level below", function()
		local q = Quests.Boss.get("boss_grimrok")
		assert(q, "boss_grimrok")
		local ok, reason = SideQuests.canAccept(emptyQuests(), q.level - 1, q)
		expect(ok).toBe(false)
		expect(reason).toBe("level")
		expect((SideQuests.canAccept(emptyQuests(), q.level, q))).toBe(true)
	end)

	it("progress only from a won dungeon run, never from the daily limit", function()
		local objective = Quests.Boss.get("boss_grimrok").objectives[1]
		expect(QuestLogic.amount(objective, "kill", { monsterId = "grimrok", variant = "boss" }, 0)).toBe(0)
		expect(QuestLogic.amount(objective, "boss", { bossId = "morvane" }, 0)).toBe(0)
		expect(QuestLogic.amount(objective, "boss", { bossId = "grimrok" }, 0)).toBe(1)
		for _, path in
			{
				"src/shared/Logic/QuestLogic.luau",
				"src/shared/Logic/SideQuests.luau",
				"src/shared/Data/Quests/Boss.luau",
				"src/shared/Data/Quests/Weekly.luau",
				"src/shared/Data/Quests/init.luau",
				"src/shared/Data/Quests/Side.luau",
				"src/shared/Data/Quests/Main.luau",
				"src/shared/Data/Quests/Daily.luau",
				"src/shared/Data/Quests/Contracts.luau",
			}
		do
			expect(string.find(fs.readFile(path), "bossRuns", 1, true)).toBeNil()
		end
	end)
end)

describe("Weeks (S98)", function()
	it("weeks start on Monday 00:00 UTC", function()
		expect(Time.weekNumber(1791763200)).toBe(2963) -- Monday 2026-10-12 00:00 UTC
		expect(Time.weekNumber(1791763199)).toBe(2962)
		expect(Time.weekStart(2963)).toBe(1791763200)
		for t = 1791763200, 1791763200 + 7 * 86400 - 1, 3600 do
			expect(Time.weekNumber(t)).toBe(2963)
		end
		expect(Time.weekNumber(1791763200 + 7 * 86400 - 1)).toBe(2963)
		expect(Time.weekNumber(1791763200 + 7 * 86400)).toBe(2964)
		local d, h, m = Time.split(6 * 86400 + 5 * 3600 + 7 * 60)
		expect({ d, h, m }).toEqual({ 6, 5, 7 })
	end)

	it("weeklyFor picks 3 distinct visible templates, the same for the same week", function()
		local first = QuestLogic.weeklyFor(4242, "char-a", 2963, 30)
		expect(#first).toBe(Quests.Weekly.PER_WEEK)
		local again = QuestLogic.weeklyFor(4242, "char-a", 2963, 30)
		local differs = false
		for week = 2964, 2983 do
			local list = QuestLogic.weeklyFor(4242, "char-a", week, 30)
			local seen: { [string]: boolean } = {}
			for i, entry in list do
				expect(seen[entry.template]).toBeNil()
				seen[entry.template] = true
				expect(entry.template ~= "event").toBe(true)
				differs = differs or entry.template ~= first[i].template
			end
		end
		for i, entry in first do
			expect(again[i].template).toBe(entry.template)
		end
		expect(differs).toBe(true)
		for _, entry in QuestLogic.weeklyFor(4242, "char-a", 2963, 5) do
			local template = Quests.Weekly.get(entry.template)
			assert(template, entry.template)
			expect(template.minLevel <= 5).toBe(true)
		end
		expect(Quests.Weekly.get("event").hidden).toBe(true)
	end)

	it("dailyFor keeps its lists after the S98 refactor", function()
		-- pinned before the refactor (build/s98_daily_before.txt)
		local list = QuestLogic.dailyFor(8919, "char31", 20003, 8)
		local ids = {}
		for _, entry in list do
			table.insert(ids, entry.template)
		end
		expect(ids).toEqual({ "upgrade", "herbs", "ore" })
	end)

	it("the boss contract is the highest boss open to the level", function()
		expect(QuestLogic.bossContractFor(14)).toBeNil()
		expect(QuestLogic.bossContractFor(15)).toBe("grimrok")
		expect(QuestLogic.bossContractFor(40)).toBe("morvane")
		expect(QuestLogic.bossContractFor(64)).toBe("morvane")
		expect(QuestLogic.bossContractFor(65)).toBe("azgor")
		expect(QuestLogic.bossContractFor(95)).toBe("vaelgrath")
		expect(QuestLogic.bossContractFor(100)).toBe("vaelgrath")
	end)

	it("weekly rewards are twice the daily EXP, real items, no cores or stones", function()
		for _, L in { 1, 20, 50, 99 } do
			expect(math.abs(Quests.Weekly.reward(L).exp - 2 * Quests.Daily.reward(L).exp) <= 1).toBe(true)
		end
		for _, L in { 1, 15, 20, 35, 45, 70, 100 } do
			for _, reward in { Quests.Weekly.reward(L), Quests.Weekly.bossReward(L) } do
				for _, item in reward.items or {} do
					expect(Items.get(item.id) ~= nil).toBe(true)
					expect(item.id ~= "legend_core").toBe(true)
					expect(string.find(item.id, "stone_dungeon", 1, true)).toBeNil()
				end
			end
		end
	end)

	it("an elite2 objective counts Elite II only, elite counts both", function()
		local monster = "bandit"
		local elite2 = { type = "kill", n = 3, variant = "elite2" }
		expect(QuestLogic.amount(elite2, "kill", { monsterId = monster, variant = "elite2" }, 0)).toBe(1)
		expect(QuestLogic.amount(elite2, "kill", { monsterId = monster, variant = "elite" }, 0)).toBe(0)
		expect(QuestLogic.amount(elite2, "kill", { monsterId = monster, variant = "normal" }, 0)).toBe(0)
		local elite = { type = "kill", n = 3, variant = "elite" }
		expect(QuestLogic.amount(elite, "kill", { monsterId = monster, variant = "elite2" }, 0)).toBe(1)
	end)

	it("the save has the weekly and contract branches, S99 fills the 99 contracts", function()
		local character: any = AccountSchema.characterTemplate()
		expect(character.quests.weekly).toEqual({ week = 0, list = {}, rerolls = 0 })
		expect(character.quests.contract).toEqual({ done = 0 })
		expect(#Quests.Contracts.list).toBe(99)
		expect((Quests.Contracts.forLevel(5) :: any).id).toBe("contract_5")
		expect(Quests.categoryOf("contract_5")).toBe("contract")
		expect(Quests.Contracts.MAX_LEVEL).toBe(99)
	end)

	it("every boss quest and weekly template has its texts in both languages", function()
		for _, lang in { pl, en } :: { any } do
			for _, q in Quests.Boss.list do
				for _, suffix in { "title", "p1", "p2", "progress", "done" } do
					expect(lang[`quest.{q.id}.{suffix}`] ~= nil).toBe(true)
				end
			end
			for _, template in Quests.Weekly.templates do
				expect(lang[`weekly.{template.id}.title`] ~= nil).toBe(true)
			end
		end
	end)
end)

return nil
