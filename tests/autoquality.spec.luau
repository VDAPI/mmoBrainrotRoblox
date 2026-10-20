--!strict
local AutoQuality = require("../src/shared/Logic/AutoQuality")
local Config = require("../src/shared/Config")
local T = require("./Test")

T.describe("Graphics level on the first entry (W29)", function()
	T.it("phones get low, tablets medium, keyboards keep their level", function()
		local edge = Config.Graphics.phoneShortSide
		T.expect(AutoQuality.pick(true, edge - 1)).toBe("low")
		T.expect(AutoQuality.pick(true, edge)).toBe("medium")
		T.expect(AutoQuality.pick(false, 300)).toBe(nil)
	end)
end)
