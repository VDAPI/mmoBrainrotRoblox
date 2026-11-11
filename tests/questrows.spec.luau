--!strict
-- S29: objective rows of a quest (finished objectives stay, the turn-in line, the one-shot pulse).

local fs = require("@lune/fs")

local Areas = require("../src/shared/Data/Areas")
local Locale = require("../src/shared/Util/Locale")
local Monsters = require("../src/shared/Data/Monsters")
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

-- Package A review (owner 2026-11-10): cut by `short`, "• Pokonaj: Ognisty Chochlik 0/12 (Spalone Ruiny)" read
-- "• Pokonaj: Ognisty Chochlik 0/1…": the tracker's line keeps the count whole and last, cuts only the name before it
-- and leaves the area for the tooltip.
describe("QuestRows.oneLine", function()
	it("keeps the count whole and last, cuts the name, leaves the area out", function()
		local head, count = QuestRows.oneLine("• Pokonaj: Ognisty Chochlik 0/12 (Spalone Ruiny)", 0, 12)
		expect(head).toBe("• Pokonaj: Ognisty Chochlik")
		expect(count).toBe("0/12")
		head, count = QuestRows.oneLine("• Pokonaj: Rycerz Lodowej Straży 0/4", 0, 4)
		expect(count).toBe("0/4")
		expect(string.sub(head, -3)).toBe("…")
		local width = utf8.len(`{head} {count}`)
		expect(width).toBe(QuestRows.LINE_MAX)
		-- a count past the need reads as the need; a line without its count is cut as `short` cuts it
		head, count = QuestRows.oneLine("✔ Pokonaj: Szary wilk 8/8", 9, 8)
		expect({ head = head, count = count }).toEqual({ head = "✔ Pokonaj: Szary wilk", count = "8/8" })
		head, count = QuestRows.oneLine("• Porozmawiaj: Starszy Wioski Eldoran z Polany Królików", 0, 1)
		expect(count).toBeNil()
		expect(head).toBe(QuestRows.short("• Porozmawiaj: Starszy Wioski Eldoran z Polany Królików"))
	end)

	it("keeps the count of every kill and collect objective of the story, side and boss quests", function()
		-- the tracker's line of an objective as UI/QuestText words it ("Defeat: <monster> 3/8" and " (<area>)")
		local function label(o: Quests.Objective, have: number, lang: string): string?
			local count = `{have}/{o.n}`
			local area = if o.area then Areas.areaById(o.area) else nil
			local where = if area
				then Locale.T("quest.obj.inArea", { area = Locale.T(area.nameKey, nil, lang) }, lang)
				else ""
			local monster = if o.monster then Monsters.get(o.monster) else nil
			local name = if monster
				then Locale.T(
					if o.variant == "elite" then monster.nameKeys.elite else monster.nameKeys.normal,
					nil,
					lang
				)
				else nil
			if o.type == "kill" and name then
				return Locale.T("quest.obj.kill", { monster = name, count = count }, lang) .. where
			elseif o.type == "collect" and o.item then
				local item = Locale.T(`quest.item.{o.item}`, nil, lang)
				if o.variant == "elite" and name then
					return Locale.T("quest.obj.collectFrom", { item = item, monster = name, count = count }, lang)
						.. where
				end
				return Locale.T("quest.obj.collect", { item = item, count = count }, lang) .. where
			end
			return nil
		end
		local checked = 0
		local sets: { { any } } = { Quests.Main.list :: any, Quests.Side.list :: any, Quests.Boss.list :: any }
		for _, set in sets do
			for _, quest in set do
				for _, objective in quest.objectives :: { Quests.Objective } do
					for _, lang in { "pl", "en" } do
						for _, have in { 0, objective.n - 1, objective.n } do
							local text = label(objective, have, lang)
							if not text then
								continue
							end
							checked += 1
							local full = `{QuestRows.OPEN_MARK} {text}`
							local head, count = QuestRows.oneLine(full, have, objective.n)
							local where = `{quest.id} {lang} {full}`
							expect({ at = where, count = count }).toEqual({ at = where, count = `{have}/{objective.n}` })
							local fits = (utf8.len(`{head} {count}`) or math.huge) <= QuestRows.LINE_MAX
							expect({ at = where, fits = fits }).toEqual({ at = where, fits = true })
						end
					end
				end
			end
		end
		expect(checked > 600).toBe(true)
	end)

	it("the tracker draws the count in a label of its own after the name", function()
		local src = fs.readFile("src/client/UI/Screens/Hud/QuestTracker.luau")
		expect(string.find(src, "QuestRows.oneLine(full, row.have, row.need)", 1, true) ~= nil).toBe(true)
		expect(string.find(src, 'part("Count", count, false)', 1, true) ~= nil).toBe(true)
		expect(string.find(src, "QuestRows.short(", 1, true) == nil).toBe(true)
	end)
end)
