--!strict
-- S134f: the after-fight meter (Logic/FightStats).
local Config = require("../src/shared/Config")
local FightStats = require("../src/shared/Logic/FightStats")
local T = require("./Test")

local NAMES = { [1] = "Ala", [2] = "Olek", [3] = "Obcy", [4] = "Ewa" }
local CLASSES = { [1] = "Warrior", [2] = "Cleric", [3] = "Mage", [4] = "Hunter" }

local function sample()
	local fight = FightStats.new("elite2", "e1", 100)
	FightStats.add(fight, 1, "dmg", 600)
	FightStats.add(fight, 2, "dmg", 200)
	FightStats.add(fight, 2, "heal", 900)
	FightStats.add(fight, 3, "dmg", 5000) -- a stranger hitting the same Elite II
	FightStats.add(fight, 4, "dmg", 200)
	FightStats.add(fight, 4, "heal", 50)
	FightStats.add(fight, 1, "taken", 1234.6)
	FightStats.add(fight, 1, "shield", 10)
	FightStats.add(fight, 2, "intercept", 77)
	return fight
end

T.describe("FightStats.rows", function()
	T.it("shows only the party and counts the damage share inside it", function()
		local rows = FightStats.rows(sample(), { 1, 2, 4 }, NAMES, CLASSES)
		T.expect(#rows).toBe(3)
		local sum = 0
		for _, row in rows do
			T.expect(row.n ~= "Obcy").toBe(true)
			sum += row.d
		end
		T.expect(sum).toBeNear(1, 0.001)
		T.expect(rows[1].n).toBe("Ala")
		T.expect(rows[1].d).toBeNear(0.6, 0.001)
		T.expect(rows[1].t).toBe(1234)
	end)

	T.it("sorts by damage, then healing", function()
		local rows = FightStats.rows(sample(), { 1, 2, 4 }, NAMES, CLASSES)
		T.expect(rows[2].n).toBe("Olek") -- 200 damage, 900 healing
		T.expect(rows[3].n).toBe("Ewa") -- 200 damage, 50 healing
	end)

	T.it("keeps the S60 summary fields for the boss reward card", function()
		local row = FightStats.rows(sample(), { 2 }, NAMES, CLASSES)[1]
		T.expect(row.n).toBe("Olek")
		T.expect(row.c).toBe("Cleric")
		T.expect(row.d).toBe(1)
		T.expect(row.h).toBe(900)
		T.expect(row.s).toBe(0)
		T.expect(row.i).toBe(77)
	end)

	T.it("solo is one row", function()
		local fight = FightStats.new("boss", "meadows", 0)
		FightStats.add(fight, 9, "dmg", 50)
		local rows = FightStats.rows(fight, { 9 }, { [9] = "Solo" }, {})
		T.expect(#rows).toBe(1)
		T.expect(rows[1].d).toBe(1)
	end)
end)

T.describe("FightStats.summary", function()
	T.it("counts time, deaths in order and dodged = aimed - hit", function()
		local fight = sample()
		FightStats.death(fight, 2, "Olek", 130)
		FightStats.death(fight, 3, "Obcy", 131)
		FightStats.death(fight, 1, "Ala", 190)
		-- three blows aimed at Ala, one hit her; two at Olek, both hit
		FightStats.add(fight, 1, "aimed", 3)
		FightStats.add(fight, 1, "dodged", 2)
		FightStats.add(fight, 2, "aimed", 2)
		FightStats.finish(fight, 322, "win")
		local s = FightStats.summary(fight, { 1, 2, 4 })
		T.expect(s.time).toBe(222)
		T.expect(s.outcome).toBe("win")
		T.expect(#s.deaths).toBe(2)
		T.expect(s.deaths[1].n).toBe("Olek")
		T.expect(s.deaths[1].at).toBe(30)
		T.expect(s.deaths[2].n).toBe("Ala")
		T.expect(s.dodged).toBe(2)
		T.expect(s.aimed).toBe(5)
		local row = FightStats.rows(fight, { 1, 2, 4 }, NAMES, CLASSES)[1]
		T.expect(row.x).toBe(1)
		T.expect(row.v).toBe(2)
		T.expect(row.w).toBe(3)
	end)

	T.it("ignores numbers after the end and keeps deaths over a reset", function()
		local fight = sample()
		FightStats.death(fight, 1, "Ala", 110)
		FightStats.reset(fight)
		T.expect(FightStats.rows(fight, { 1 }, NAMES, CLASSES)[1].a).toBe(0)
		T.expect(FightStats.rows(fight, { 1 }, NAMES, CLASSES)[1].x).toBe(1)
		FightStats.finish(fight, 200, "fail")
		FightStats.add(fight, 1, "dmg", 100)
		T.expect(FightStats.rows(fight, { 1 }, NAMES, CLASSES)[1].a).toBe(0)
	end)
end)

T.describe("FightStats.worthSending", function()
	T.it("needs minSeconds and some party damage", function()
		local min = Config.FightLog.minSeconds
		local short = FightStats.new("elite2", "e", 0)
		FightStats.add(short, 1, "dmg", 10)
		FightStats.finish(short, min - 1, "win")
		T.expect(FightStats.worthSending(short, { 1 }, min)).toBe(false)
		local long = FightStats.new("elite2", "e", 0)
		FightStats.add(long, 1, "heal", 10)
		FightStats.add(long, 3, "dmg", 10)
		FightStats.finish(long, min + 10, "win")
		T.expect(FightStats.worthSending(long, { 1 }, min)).toBe(false)
		T.expect(FightStats.worthSending(long, { 1, 3 }, min)).toBe(true)
	end)
end)

T.describe("FightStats.dropView", function()
	T.it("lists own items, the others' from Legendary up and counts the rest", function()
		local view = FightStats.dropView({ { id = "a", r = 1 } }, {
			{ n = "Olek", items = { { id = "b", r = 4 }, { id = "c", r = 2 }, { id = "d", r = 5, up = 1 } } },
			{ n = "Ewa", items = { { id = "e", r = 3 } } },
		}, 4)
		T.expect(#view.mine).toBe(1)
		T.expect(#view.party).toBe(2)
		T.expect(view.party[1].n).toBe("Olek")
		T.expect(view.party[2].id).toBe("d")
		T.expect(view.more).toBe(2)
	end)
end)
