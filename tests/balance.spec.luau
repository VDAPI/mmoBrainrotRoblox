--!strict
-- DESIGN §15.1 (after the S17 tests): with gear of their level a player kills a normal monster of their
-- level in about 6-10 s and loses 15-30% HP. The Warrior is the reference; the other classes get a wider
-- band (Hunters scale faster with DEX, Clerics fight slower but take less damage).
local Balance = require("./Balance")
local T = require("./Test")

local LEVELS = { 2, 5, 10, 30, 60, 90 }

T.describe("Monster balance", function()
	for _, level in LEVELS do
		T.it(`Warrior level {level}: 6-10 s per kill, 10-30% HP lost`, function()
			local fight = Balance.fight("Warrior", level)
			T.expect(fight.killSeconds).toBeBetween(6, 10)
			T.expect(fight.hpLost).toBeBetween(0.10, 0.30)
		end)
	end

	for _, classId in { "Hunter", "Mage", "Cleric" } do
		T.it(`{classId}: every level stays in the wider band`, function()
			for _, level in LEVELS do
				local fight = Balance.fight(classId, level)
				T.expect(fight.killSeconds).toBeBetween(3, 13)
				T.expect(fight.hpLost).toBeBetween(0.05, 0.32)
			end
		end)
	end

	T.it("no class dies to one monster of its level", function()
		for classId in Balance.LOADOUT do
			for _, level in LEVELS do
				T.expect(Balance.fight(classId, level).hpLost < 0.5).toBe(true)
			end
		end
	end)
end)
