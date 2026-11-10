--!strict
-- S29: objective rows of a quest (finished objectives stay, the turn-in line, the one-shot pulse).

local QuestRows = require("../src/shared/Logic/QuestRows")
local Quests = require("../src/shared/Data/Quests")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local OBJECTIVES: { Quests.Objective } = {
	{ type = "kill", monster = "wolf", n = 10 },
	{ type = "talk", npc = "elder", n = 1 },
	{ type = "collect", item = "pelt", n = 3 },
}

local function label(objective: Quests.Objective, have: number): string
	return `{objective.type} {have}/{objective.n}`
end

describe("QuestRows.build", function()
	it("keeps every objective, finished ones marked done", function()
		local list = QuestRows.build(OBJECTIVES, { 10, 0, 2 }, "elder", label)
		expect(#list.rows).toBe(3)
		expect(list.rows[1].done).toBe(true)
		expect(list.rows[1].text).toBe("kill 10/10")
		expect(list.rows[2].done).toBe(false)
		expect(list.rows[3].have).toBe(2)
		expect(list.rows[3].need).toBe(3)
		expect(list.complete).toBe(false)
		expect(list.turnIn).toBeNil()
		expect(list.current).toBe(2)
	end)

	it("carries the turn-in NPC once all objectives are done and keeps the rows", function()
		local list = QuestRows.build(OBJECTIVES, { 10, 1, 3 }, "elder", label)
		expect(#list.rows).toBe(3)
		expect(list.complete).toBe(true)
		expect(list.turnIn).toBe("elder")
		expect(list.current).toBeNil()
		for _, row in list.rows do
			expect(row.done).toBe(true)
		end
	end)

	it("clamps progress and tolerates missing or broken progress", function()
		local list = QuestRows.build(OBJECTIVES, { 99, -4 } :: any, nil, label)
		expect(list.rows[1].have).toBe(10)
		expect(list.rows[2].have).toBe(0)
		expect(list.rows[3].have).toBe(0)
		local empty = QuestRows.build(OBJECTIVES, nil)
		expect(empty.rows[1].text).toBe("")
		expect(empty.complete).toBe(false)
	end)

	it("marks lines with a check or a bullet", function()
		local list = QuestRows.build(OBJECTIVES, { 10, 0, 0 }, nil, label)
		expect(QuestRows.line(list.rows[1])).toBe("✔ kill 10/10")
		expect(QuestRows.line(list.rows[2])).toBe("• talk 0/1")
	end)

	it("works on every story and side quest", function()
		for _, quest in Quests.Main.list do
			local full = {}
			for i, objective in quest.objectives do
				full[i] = objective.n
			end
			local list = QuestRows.build(quest.objectives, full, quest.turnIn)
			expect(list.complete).toBe(true)
			expect(list.turnIn).toBe(quest.turnIn)
		end
		for _, quest in Quests.Side.list do
			local list = QuestRows.build(quest.objectives, {}, quest.turnIn)
			expect(#list.rows).toBe(#quest.objectives)
			expect(list.complete).toBe(#quest.objectives == 0)
		end
	end)
end)

describe("QuestRows.newlyDone", function()
	it("does not pulse rows already done when a quest is first shown", function()
		local seen: QuestRows.Seen = {}
		local fresh = QuestRows.newlyDone(seen, "main:q1", QuestRows.build(OBJECTIVES, { 10, 1, 0 }))
		expect(#fresh).toBe(0)
	end)

	it("pulses a row once in the moment it is finished", function()
		local seen: QuestRows.Seen = {}
		QuestRows.newlyDone(seen, "main:q1", QuestRows.build(OBJECTIVES, { 9, 0, 0 }))
		local fresh = QuestRows.newlyDone(seen, "main:q1", QuestRows.build(OBJECTIVES, { 10, 0, 0 }))
		expect(#fresh).toBe(1)
		expect(fresh[1]).toBe(1)
		-- recomputing with the same progress does not pulse again
		local again = QuestRows.newlyDone(seen, "main:q1", QuestRows.build(OBJECTIVES, { 10, 0, 1 }))
		expect(#again).toBe(0)
	end)

	it("keeps quests apart", function()
		local seen: QuestRows.Seen = {}
		QuestRows.newlyDone(seen, "main:q1", QuestRows.build(OBJECTIVES, { 0, 0, 0 }))
		QuestRows.newlyDone(seen, "side:s1", QuestRows.build(OBJECTIVES, { 0, 0, 0 }))
		local fresh = QuestRows.newlyDone(seen, "side:s1", QuestRows.build(OBJECTIVES, { 0, 1, 3 }))
		expect(#fresh).toBe(2)
		expect(#QuestRows.newlyDone(seen, "main:q1", QuestRows.build(OBJECTIVES, { 0, 0, 0 }))).toBe(0)
	end)
end)

-- Owner 2026-11-10 ("too much text"; UI plan package A): an objective is one tracker line of at most 32 characters.
describe("QuestRows.short", function()
	it("keeps a short line and cuts a long one to 32 characters with an ellipsis", function()
		expect(QuestRows.short("• Pokonaj: Szary wilk 3/8")).toBe("• Pokonaj: Szary wilk 3/8")
		local long = "• Pokonaj: Zgniłozęby Strażnik Kurhanu 3/8 (Pole Wron)"
		local cut = QuestRows.short(long)
		expect(utf8.len(cut) <= QuestRows.LINE_MAX).toBe(true)
		expect(string.sub(cut, -3)).toBe("…")
		expect(string.sub(long, 1, #cut - 3)).toBe(string.sub(cut, 1, #cut - 3))
		-- no space before the ellipsis, and an exact fit stays whole
		expect(string.find(QuestRows.short("abc defgh", 5), " …", 1, true)).toBeNil()
		expect(QuestRows.short(string.rep("ą", 32))).toBe(string.rep("ą", 32))
		expect(utf8.len(QuestRows.short(string.rep("ą", 40)))).toBe(32)
	end)
end)
