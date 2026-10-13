--!strict
-- S25: quest marks over NPCs (Logic/NpcMarks).

local Config = require("../src/shared/Config")
local NpcMarks = require("../src/shared/Logic/NpcMarks")
local Npcs = require("../src/shared/Data/Npcs")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function state(main: any, mainDone: number, daily: { any }?): any
	return { main = main, mainDone = mainDone, daily = { day = 1, list = daily or {}, rerolls = 0 } }
end

describe("NpcMarks", function()
	it("an available story quest marks its giver", function()
		local first = Quests.Main.list[1]
		local marks = NpcMarks.all(state(nil, 0), 1)
		expect(marks[first.giver]).toBe("available")
	end)

	it("a finished quest marks the turn-in NPC, an open one shows it in progress", function()
		local quest = Quests.Main.list[2]
		local done = {}
		for i, objective in quest.objectives do
			done[i] = objective.n
		end
		expect(NpcMarks.of(quest.turnIn, state({ id = quest.id, progress = done }, 1), 1)).toBe("turnIn")
		local open = QuestLogic.emptyProgress(quest.objectives)
		expect(NpcMarks.of(quest.turnIn, state({ id = quest.id, progress = open }, 1), 1)).toBe("active")
		-- The giver of the next quest has nothing while a quest is active (S27: side quest givers aside).
		local count = 0
		for npcId in NpcMarks.all(state({ id = quest.id, progress = open }, 1), 1) do
			local sideGiver = false
			for _, side in Quests.Side.list do
				sideGiver = sideGiver or side.giver == npcId
			end
			if not sideGiver then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)

	it("no mark when the level is too low", function()
		local index, quest = 0, nil :: Quests.MainQuest?
		for i, candidate in Quests.Main.list do
			if candidate.level - Quests.Main.LEVEL_SLACK > 1 then
				index, quest = i, candidate
				break
			end
		end
		assert(quest, "a quest above level 1")
		expect(NpcMarks.of(quest.giver, state(nil, index - 1), 1)).toBeNil()
		expect(NpcMarks.of(quest.giver, state(nil, index - 1), quest.level)).toBe("available")
	end)

	it("the contract board follows the daily list from dailyFor", function()
		local list: { any } = QuestLogic.dailyFor(123, "char-1", 20000, 10)
		expect(#list > 0).toBe(true)
		expect(NpcMarks.of(NpcMarks.BOARD, state(nil, 999, list), 10)).toBe("active")
		local first = list[1]
		first.progress = first.objective.n
		expect(NpcMarks.of(NpcMarks.BOARD, state(nil, 999, list), 10)).toBe("turnIn")
		for _, entry in list do
			entry.claimed = true
		end
		expect(NpcMarks.of(NpcMarks.BOARD, state(nil, 999, list), 10)).toBeNil()
	end)

	it("marks only NPCs that exist", function()
		for _, quest in Quests.Main.list do
			expect(Npcs.get(quest.giver) ~= nil and Npcs.get(quest.turnIn) ~= nil).toBe(true)
		end
		expect(NpcMarks.all(nil, 1)).toEqual({})
	end)

	it("priority orders turn-in over available over active", function()
		expect(NpcMarks.priority("turnIn") > NpcMarks.priority("available")).toBe(true)
		expect(NpcMarks.priority("available") > NpcMarks.priority("availableLow")).toBe(true)
		expect(NpcMarks.priority("availableLow") > NpcMarks.priority("active")).toBe(true)
		expect(NpcMarks.priority("active") > NpcMarks.priority(nil)).toBe(true)
		expect(NpcMarks.priority(nil)).toBe(0)
	end)

	-- S98 (docs/DESIGN-15.md §3.1): the grey "!", the weekly contracts and the boss quests of the scouts
	local function sideState(done: { [string]: boolean }?, weekly: any?): any
		local s = state(nil, 999)
		s.side = { active = {}, done = done or {} }
		s.weekly = weekly
		return s
	end

	it("an offer more than greyGap levels below is grey, at greyGap it is gold", function()
		local gap = Config.Quest.greyGap
		expect(NpcMarks.isLow(10, 10 + gap)).toBe(false)
		expect(NpcMarks.isLow(10, 10 + gap + 1)).toBe(true)
		local q = Quests.Boss.get("boss_grimrok")
		assert(q, "boss_grimrok")
		expect(NpcMarks.of(q.giver, sideState(), q.level + gap)).toBe("available")
		expect(NpcMarks.of(q.giver, sideState(), q.level + gap + 1)).toBe("availableLow")
	end)

	it("a gold offer wins over a grey one at the same NPC", function()
		-- the stablemaster: side_wagon (10) is grey at 21, the stable arc's first quest (21) is gold
		local wagon = Quests.Side.get("side_wagon")
		local harness = Quests.Side.get("side_stable_harness")
		assert(wagon and harness, "stablemaster quests")
		expect(wagon.giver).toBe("stablemaster")
		expect(harness.giver).toBe("stablemaster")
		expect(NpcMarks.isLow(wagon.level, 21)).toBe(true)
		expect(NpcMarks.of("stablemaster", sideState(), 21)).toBe("available")
		local arcDone = { side_stable_harness = true, side_stable_stallion = true }
		expect(NpcMarks.of("stablemaster", sideState(arcDone), 21)).toBe("availableLow")
	end)

	it("the board shows weekly contracts and the boss contract", function()
		local list: { any } = QuestLogic.weeklyFor(7, "c", 2963, 30)
		local weekly = { week = 2963, list = list, rerolls = 0 }
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBe("active")
		list[1].progress = list[1].objective.n
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBe("turnIn")
		for _, entry in list do
			entry.claimed = true
		end
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBeNil()
		weekly.boss = { boss = "morvane", progress = 0, claimed = false }
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBe("active")
		weekly.boss.progress = Quests.Weekly.bossContract.n
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBe("turnIn")
		weekly.boss.claimed = true
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBeNil()
	end)

	it("the Meadows scout offers Grimrok's Slayer at 15", function()
		local q = Quests.Boss.get("boss_grimrok")
		assert(q, "boss_grimrok")
		expect(q.giver).toBe("scout_meadows")
		expect(NpcMarks.of("scout_meadows", sideState(), 14)).toBeNil()
		expect(NpcMarks.of("scout_meadows", sideState(), 15)).toBe("available")
	end)
end)

return nil
