--!strict
-- Owner 2026-10-20: out-levelled elites and bosses are locked; ordinary monsters and the world boss never.
local T = require("./Test")
local Config = require("../src/shared/Config")
local LevelLock = require("../src/shared/Logic/LevelLock")

T.describe("LevelLock", function()
	T.it("locks elites, Elite II and dungeon bosses from the gap on", function()
		local gap = Config.LevelLock.gap
		for _, variant in { "elite", "elite2", "boss" } do
			T.expect({ variant, LevelLock.blocked(30 + gap - 1, 30, variant) }).toEqual({ variant, false })
			T.expect({ variant, LevelLock.blocked(30 + gap, 30, variant) }).toEqual({ variant, true })
		end
	end)

	T.it("never locks ordinary monsters nor the world boss", function()
		T.expect(LevelLock.blocked(100, 1, "normal")).toBe(false)
		T.expect(LevelLock.blocked(100, 1, "boss", true)).toBe(false)
		T.expect(LevelLock.blocked(100, 1, nil)).toBe(false)
	end)
end)

return nil
