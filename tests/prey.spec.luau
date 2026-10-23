--!strict
-- Prey hunts (owner 2026-10-23): the daily and weekly "kill N of monster X" contracts (Logic/Prey).
local Monsters = require("../src/shared/Data/Monsters")
local Prey = require("../src/shared/Logic/Prey")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Prey hunts", function()
	it("every level 1-100 has a ground and a known kind", function()
		for level = 1, 100 do
			local objective = Prey.objective(level, 22 + math.floor(level / 5), 8, Rng.new(level * 7))
			expect(objective.type).toBe("kill")
			expect(Monsters.get(objective.monster :: string) ~= nil).toBe(true)
			expect(objective.area ~= nil).toBe(true)
			expect(objective.n >= 8).toBe(true)
		end
	end)

	it("the ground fits the level when one covers it", function()
		for _, ground in Prey.grounds(30) do
			expect(ground.area.lv[1] <= 30 and 30 <= ground.area.lv[2]).toBe(true)
		end
	end)

	it("the daily and weekly lists offer a prey hunt", function()
		local daily, weekly = false, false
		for day = 20000, 20060 do
			for _, entry in QuestLogic.dailyFor(77, "c1", day, 25) do
				if entry.template == "prey" then
					daily = true
					expect(entry.objective.monster ~= nil).toBe(true)
				end
			end
			for _, entry in QuestLogic.weeklyFor(77, "c1", day, 25) do
				weekly = weekly or entry.template == "prey"
			end
		end
		expect(daily).toBe(true)
		expect(weekly).toBe(true)
		expect(Quests.Daily.get("prey") ~= nil).toBe(true)
	end)

	it("the same day draws the same prey", function()
		local a = QuestLogic.dailyFor(5, "x", 20010, 40)
		local b = QuestLogic.dailyFor(5, "x", 20010, 40)
		for i, entry in a do
			expect(entry.objective.monster).toBe(b[i].objective.monster)
			expect(entry.objective.n).toBe(b[i].objective.n)
		end
	end)
end)

return nil
