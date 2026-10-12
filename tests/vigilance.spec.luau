--!strict
-- S77 (ROZWOJ 11.5, 7.3): the Scout's red-zone reaction, Logic/Vigilance on the rules of Data/Paths HOOK_RULES.
local Vigilance = require("../src/shared/Logic/Vigilance")
local T = require("./Test")

T.describe("Vigilance (S77)", function()
	local zone: Vigilance.Zone = { windup = 2, monsterDistance = 10 }

	T.it("first trigger, then once per 8 s", function()
		T.expect(Vigilance.ready(nil, 100, zone)).toBe(true)
		T.expect(Vigilance.ready(100, 107.9, zone)).toBe(false)
		T.expect(Vigilance.ready(100, 108, zone)).toBe(true)
	end)

	T.it("only red zones (a windup) of monsters within 30 studs", function()
		T.expect(Vigilance.ready(nil, 100, { windup = 0, monsterDistance = 10 })).toBe(false)
		T.expect(Vigilance.ready(nil, 100, { windup = 2, monsterDistance = 31 })).toBe(false)
		T.expect(Vigilance.ready(nil, 100, { windup = 2, monsterDistance = 30 })).toBe(true)
	end)

	T.it("each kind has its own trigger", function()
		local moveAt = 100
		local guardAt: number? = nil
		T.expect(Vigilance.ready(moveAt, 103, zone)).toBe(false)
		T.expect(Vigilance.ready(guardAt, 103, zone)).toBe(true)
	end)

	T.it("lasts the windup + 0.5 s", function()
		T.expect(Vigilance.duration(1.4)).toBeNear(1.9)
		T.expect(Vigilance.duration(2.2)).toBeNear(2.7)
	end)
end)

return nil
