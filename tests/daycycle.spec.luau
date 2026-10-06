--!strict
-- S21: day and night clock (Logic/DayCycle).

local DayCycle = require("../src/shared/Logic/DayCycle")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local LENGTH = 2400
local SHARE = 0.25

describe("DayCycle", function()
	it("starts the cycle at dawn and reaches dusk after the day share", function()
		expect(DayCycle.clock(0, LENGTH, SHARE)).toBeNear(6, 1e-9)
		expect(DayCycle.clock(LENGTH * 0.75, LENGTH, SHARE)).toBeNear(19, 1e-9)
		expect(DayCycle.clock(LENGTH, LENGTH, SHARE)).toBeNear(6, 1e-9)
		expect(DayCycle.clock(LENGTH * 0.375, LENGTH, SHARE)).toBeNear(12.5, 1e-9)
	end)

	it("spends the night share of real time in the night", function()
		local night = 0
		local samples = 4800
		for i = 0, samples - 1 do
			if DayCycle.isNight(DayCycle.clock(i * LENGTH / samples, LENGTH, SHARE)) then
				night += 1
			end
		end
		expect(night / samples).toBeNear(SHARE, 0.005)
	end)

	it("runs the clock forward and wraps past midnight", function()
		local previous = DayCycle.clock(0, LENGTH, SHARE)
		local wraps = 0
		for s = 1, LENGTH, 5 do
			local c = DayCycle.clock(s, LENGTH, SHARE)
			expect(c >= 0 and c < 24).toBe(true)
			if c < previous then
				wraps += 1
			end
			previous = c
		end
		expect(wraps).toBe(1)
	end)

	it("finds the offset that shows a wanted hour", function()
		for _, now in { 0, 123.4, 99999.9, 1.7e9 } do
			for _, hour in { 0, 3.5, 6, 12, 18.9, 19, 22, 23.99 } do
				local offset = DayCycle.offsetFor(now, hour, LENGTH, SHARE)
				expect(offset >= 0 and offset < LENGTH).toBe(true)
				local shown = DayCycle.clock(now + offset, LENGTH, SHARE)
				local diff = math.abs(shown - hour)
				expect(math.min(diff, 24 - diff) < 1e-4).toBe(true)
			end
		end
	end)

	it("is dark at night and bright at noon", function()
		expect(DayCycle.nightness(12)).toBe(0)
		expect(DayCycle.nightness(0)).toBe(1)
		expect(DayCycle.nightness(23)).toBe(1)
		expect(DayCycle.nightness(4)).toBe(1)
		expect(DayCycle.nightness(19)).toBeNear(0.5, 1e-9)
		expect(DayCycle.nightness(6)).toBeNear(0.5, 1e-9)
		expect(DayCycle.isNight(19)).toBe(true)
		expect(DayCycle.isNight(6)).toBe(false)
	end)

	it("lights a stable ~60% of windows", function()
		local lit = 0
		local total = 0
		for x = -200, 200, 7 do
			for z = -200, 200, 11 do
				local y = 4 + (x + z) % 9
				total += 1
				if DayCycle.windowLit(x + 0.3, y, z - 0.6) then
					lit += 1
				end
				expect(DayCycle.windowLit(x + 0.3, y, z - 0.6)).toBe(DayCycle.windowLit(x + 0.3, y, z - 0.6))
			end
		end
		expect(lit / total).toBeBetween(0.55, 0.65)
	end)
end)
