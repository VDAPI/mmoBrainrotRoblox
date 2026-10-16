--!strict
-- S134f: low health warning (Logic/LowHp).
local Config = require("../src/shared/Config")
local LowHp = require("../src/shared/Logic/LowHp")
local T = require("./Test")

local cfg = Config.LowHp

T.describe("LowHp.state", function()
	T.it("turns on below 25 % and stays off above", function()
		T.expect((LowHp.state(24, 100, false, cfg))).toBe(true)
		T.expect((LowHp.state(26, 100, false, cfg))).toBe(false)
		T.expect((LowHp.state(25, 100, false, cfg))).toBe(false)
	end)

	T.it("does not turn off between 25 and 28 % (hysteresis), turns off above 28 %", function()
		T.expect((LowHp.state(26, 100, true, cfg))).toBe(true)
		T.expect((LowHp.state(28, 100, true, cfg))).toBe(true)
		T.expect((LowHp.state(29, 100, true, cfg))).toBe(false)
	end)

	T.it("intensity grows from 0 at 25 % to 1 at 5 % and below", function()
		local _, at25 = LowHp.state(25, 100, true, cfg)
		local _, at15 = LowHp.state(15, 100, true, cfg)
		local _, at5 = LowHp.state(5, 100, true, cfg)
		local _, at1 = LowHp.state(1, 100, true, cfg)
		T.expect(at25).toBeNear(0)
		T.expect(at15).toBeNear(0.5)
		T.expect(at5).toBeNear(1)
		T.expect(at1).toBe(1)
	end)

	T.it("is off when dead or without max HP", function()
		T.expect((LowHp.state(0, 100, true, cfg))).toBe(false)
		T.expect((LowHp.state(10, 0, true, cfg))).toBe(false)
		T.expect((LowHp.state(nil, 100, false, cfg))).toBe(false)
	end)
end)

T.describe("LowHp.beatInterval", function()
	T.it("stays within [beatFast, beatSlow] and shortens with intensity", function()
		local previous = math.huge
		for step = 0, 10 do
			local interval = LowHp.beatInterval(step / 10, cfg)
			T.expect(interval).toBeBetween(cfg.beatFast, cfg.beatSlow)
			T.expect(interval < previous).toBe(true)
			previous = interval
		end
		T.expect(LowHp.beatInterval(0, cfg)).toBeNear(cfg.beatSlow)
		T.expect(LowHp.beatInterval(1, cfg)).toBeNear(cfg.beatFast)
	end)
end)
