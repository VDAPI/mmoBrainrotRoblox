--!strict
local LevelBand = require("../src/shared/Logic/LevelBand")
local T = require("./Test")

T.describe("LevelBand", function()
	T.it("matches the design bands", function()
		local cases = {
			{ 1, 20, "grey" },
			{ 10, 20, "grey" },
			{ 11, 20, "green" },
			{ 17, 20, "green" },
			{ 18, 20, "white" },
			{ 22, 20, "white" },
			{ 23, 20, "yellow" },
			{ 25, 20, "yellow" },
			{ 26, 20, "red" },
		}
		for _, c in cases do
			T.expect(LevelBand.of(c[1] :: number, c[2] :: number)).toBe(c[3])
		end
	end)

	T.it("every band has a colour", function()
		for _, band in { "grey", "green", "white", "yellow", "red" } do
			T.expect(string.match((LevelBand.COLORS :: any)[band], "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
		end
	end)
end)
