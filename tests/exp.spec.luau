--!strict
local Exp = require("../src/shared/Logic/Exp")
local T = require("./Test")

T.describe("Exp", function()
	T.it("expToNext matches DESIGN control values", function()
		T.expect(Exp.expToNext(1)).toBe(100)
		T.expect(Exp.expToNext(10)).toBeNear(3240, 10)
		T.expect(Exp.expToNext(50)).toBeNear(67400, 700) -- DESIGN rounds loosely ("~67 400")
		T.expect(Exp.expToNext(99)).toBeNear(249000, 2500)
	end)

	T.it("expToNext grows with level", function()
		for l = 1, 99 do
			T.expect(Exp.expToNext(l + 1) > Exp.expToNext(l)).toBe(true)
		end
	end)

	T.it("monsterExp and variants", function()
		T.expect(Exp.monsterExp(1)).toBe(14)
		T.expect(Exp.monsterExp(10)).toBe(math.floor(8 + 6 * 10 ^ 1.25 + 0.5))
		T.expect(Exp.monsterExp(10, "elite")).toBe(Exp.monsterExp(10) * 4)
		T.expect(Exp.monsterExp(10, "elite2")).toBe(Exp.monsterExp(10) * 12)
		T.expect(Exp.monsterExp(10, "boss")).toBe(Exp.monsterExp(10) * 60)
	end)

	T.it("levelDiffMultiplier follows the penalty and bonus rules", function()
		T.expect(Exp.levelDiffMultiplier(10, 10)).toBe(1)
		T.expect(Exp.levelDiffMultiplier(15, 10)).toBe(1)
		T.expect(Exp.levelDiffMultiplier(16, 10)).toBeNear(0.85)
		T.expect(Exp.levelDiffMultiplier(20, 10)).toBeNear(0.25)
		T.expect(Exp.levelDiffMultiplier(40, 10)).toBeNear(0.05)
		T.expect(Exp.levelDiffMultiplier(10, 12)).toBeNear(1.08)
		T.expect(Exp.levelDiffMultiplier(10, 30)).toBeNear(1.2)
	end)

	T.it("applyExp without level up", function()
		local level, exp, gained = Exp.applyExp(1, 10, 50, 100)
		T.expect({ level, exp, gained }).toEqual({ 1, 60, 0 })
	end)

	T.it("applyExp handles several levels at once", function()
		local total = Exp.expToNext(1) + Exp.expToNext(2) + Exp.expToNext(3) + 7
		local level, exp, gained = Exp.applyExp(1, 0, total, 100)
		T.expect({ level, exp, gained }).toEqual({ 4, 7, 3 })
	end)

	T.it("applyExp caps at the max level", function()
		local level, exp, gained = Exp.applyExp(99, 0, 10 ^ 9, 100)
		T.expect({ level, exp, gained }).toEqual({ 100, 0, 1 })
		level, exp, gained = Exp.applyExp(100, 0, 5000, 100)
		T.expect({ level, exp, gained }).toEqual({ 100, 0, 0 })
	end)

	T.it("applyExp ignores negative gains", function()
		local level, exp = Exp.applyExp(5, 20, -100, 100)
		T.expect({ level, exp }).toEqual({ 5, 20 })
	end)

	T.it("points: 5 stat per level, 1 skill per level from level 2 (99 total)", function()
		T.expect({ Exp.pointsForLevels(1, 2) }).toEqual({ 5, 1 })
		T.expect({ Exp.pointsForLevels(1, 100) }).toEqual({ 495, 99 })
		T.expect({ Exp.pointsForLevels(10, 10) }).toEqual({ 0, 0 })
	end)

	T.it("progress", function()
		T.expect(Exp.progress(1, 50, 100)).toBeNear(0.5)
		T.expect(Exp.progress(100, 0, 100)).toBe(1)
	end)
end)

return nil
