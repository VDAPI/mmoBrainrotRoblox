--!strict
-- S25: quest marks over NPCs (Logic/NpcMarks).

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
		-- The giver of the next quest has nothing while a quest is active.
		local count = 0
		for _ in NpcMarks.all(state({ id = quest.id, progress = open }, 1), 1) do
			count += 1
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
		expect(NpcMarks.priority("available") > NpcMarks.priority("active")).toBe(true)
		expect(NpcMarks.priority(nil)).toBe(0)
	end)
end)

return nil
