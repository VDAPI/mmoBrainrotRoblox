--!strict
-- Owner 2026-10-21 (the quest tracker took ~40 % of the screen): Logic/TrackerFold, the folded groups of the tracker
-- (account.settings.trackerFold), and the one-line progress of QuestRows.compact / withoutCount.

local QuestRows = require("../src/shared/Logic/QuestRows")
local Quests = require("../src/shared/Data/Quests")
local T = require("./Test")
local TrackerFold = require("../src/shared/Logic/TrackerFold")

T.describe("TrackerFold", function()
	T.it("without a setting only the weekly set is folded", function()
		for _, id in TrackerFold.GROUPS do
			T.expect(TrackerFold.isFolded(nil, id)).toBe(id == "weekly")
			T.expect(TrackerFold.isFolded({}, id)).toBe(id == "weekly")
		end
	end)

	T.it("a saved value wins over the default", function()
		T.expect(TrackerFold.isFolded({ weekly = false }, "weekly")).toBe(false)
		T.expect(TrackerFold.isFolded({ contracts = true }, "contracts")).toBe(true)
		T.expect(TrackerFold.isFolded({ contracts = "yes" }, "contracts")).toBe(false)
	end)

	T.it("with() toggles one group and keeps only the differences from the defaults", function()
		local a = TrackerFold.with({}, "daily", true)
		T.expect(a.daily).toBe(true)
		T.expect(a.weekly).toBeNil()
		local b = TrackerFold.with(a, "weekly", false)
		T.expect(b.daily).toBe(true)
		T.expect(b.weekly).toBe(false)
		local c = TrackerFold.with(b, "daily", false)
		T.expect(c.daily).toBeNil()
		T.expect(TrackerFold.isFolded(c, "weekly")).toBe(false)
		-- unknown groups are dropped
		local d = TrackerFold.with({ nope = true } :: any, "all", true)
		T.expect((d :: any).nope).toBeNil()
		T.expect(d.all).toBe(true)
	end)

	T.it("same() compares what is folded, not the shape", function()
		T.expect(TrackerFold.same({}, { weekly = true })).toBe(true)
		T.expect(TrackerFold.same({ daily = true }, {})).toBe(false)
		T.expect(TrackerFold.same(nil, {})).toBe(true)
	end)

	T.it("valid() takes only known groups with booleans", function()
		T.expect(TrackerFold.valid({})).toBe(true)
		T.expect(TrackerFold.valid({ all = true, weekly = false, ach = true })).toBe(true)
		T.expect(TrackerFold.valid({ nope = true })).toBe(false)
		T.expect(TrackerFold.valid({ daily = 1 })).toBe(false)
		T.expect(TrackerFold.valid({ true })).toBe(false)
		T.expect(TrackerFold.valid("daily")).toBe(false)
		T.expect(TrackerFold.valid(nil)).toBe(false)
	end)

	T.it("every value with() returns passes the server validator", function()
		local saved: any = {}
		for _, id in TrackerFold.GROUPS do
			saved = TrackerFold.with(saved, id, not TrackerFold.isFolded(saved, id))
			T.expect(TrackerFold.valid(saved)).toBe(true)
		end
	end)
end)

local function label(objective: Quests.Objective, have: number): string
	return `{objective.type} {have}/{objective.n}`
end

T.describe("QuestRows.compact", function()
	T.it("one counted objective: its count", function()
		local list = QuestRows.build({ { type = "kill", monster = "wolf", n = 15 } }, { 3 }, nil, label)
		T.expect(QuestRows.compact(list)).toBe("3/15")
	end)

	T.it("one uncounted objective: nothing until it is done", function()
		local list = QuestRows.build({ { type = "talk", npc = "captain", n = 1 } }, { 0 }, "captain", label)
		T.expect(QuestRows.compact(list)).toBe("")
	end)

	T.it("several objectives: the finished ones of all", function()
		local objectives: { Quests.Objective } = {
			{ type = "potion", n = 1 },
			{ type = "talk", npc = "healer", n = 1 },
			{ type = "kill", monster = "wolf", n = 8 },
		}
		T.expect(QuestRows.compact(QuestRows.build(objectives, { 1, 0, 4 }, nil, label))).toBe("1/3")
	end)

	T.it("complete: the done mark", function()
		local list = QuestRows.build({ { type = "kill", monster = "wolf", n = 5 } }, { 5 }, nil, label)
		T.expect(QuestRows.compact(list)).toBe(QuestRows.DONE_MARK)
	end)
end)

T.describe("QuestRows.withoutCount", function()
	T.it("drops the count, also before an area suffix", function()
		T.expect(QuestRows.withoutCount("Pokonaj: Wilk 3/8", 3, 8)).toBe("Pokonaj: Wilk")
		T.expect(QuestRows.withoutCount("Pokonaj: Wilk 3/8 (Pole Wron)", 3, 8)).toBe("Pokonaj: Wilk (Pole Wron)")
		T.expect(QuestRows.withoutCount("Pokonaj potwory od 25. poziomu 37/37", 40, 37))
			.toBe("Pokonaj potwory od 25. poziomu")
	end)

	T.it("keeps a label without the count as it is", function()
		T.expect(QuestRows.withoutCount("Porozmawiaj: Kapitan", 0, 1)).toBe("Porozmawiaj: Kapitan")
	end)
end)
