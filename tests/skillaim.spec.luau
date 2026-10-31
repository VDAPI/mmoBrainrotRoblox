--!strict
-- Owner 2026-10-31: what a point skill aims at (Logic/SkillAim); Blink on a phone never lands in the target.

local SkillAim = require("../src/shared/Logic/SkillAim")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

T.describe("Skill aim", function()
	T.it("PC aims at the cursor, also Blink with a monster selected", function()
		T.expect(SkillAim.source("blink", false, true, true)).toBe("cursor")
		T.expect(SkillAim.source("circleTarget", false, true, true)).toBe("cursor")
		T.expect(SkillAim.source("banner", false, true, false)).toBe("cursor")
	end)
	T.it("Blink on touch goes the way you move, never into the selected monster", function()
		T.expect(SkillAim.source("blink", true, false, true)).toBe("move")
		T.expect(SkillAim.source("blink", true, false, false)).toBe("move")
		-- a stray cursor point on a touch device does not count
		T.expect(SkillAim.source("blink", true, true, true)).toBe("move")
	end)
	T.it("other touch skills keep the target, then their fallback", function()
		T.expect(SkillAim.source("circleTarget", true, false, true)).toBe("target")
		T.expect(SkillAim.source("circleTarget", true, false, false)).toBe("front")
		T.expect(SkillAim.source("banner", true, false, false)).toBe("feet")
	end)
	T.it("PC without a ground point under the cursor falls back as before", function()
		T.expect(SkillAim.source("blink", false, false, true)).toBe("target")
		T.expect(SkillAim.source("blink", false, false, false)).toBe("move")
		T.expect(SkillAim.source("circleTarget", false, false, false)).toBe("front")
	end)
	T.it("Blink texts say cursor, not the direction of movement", function()
		for _, key in { "skill.blink.desc", "skill.blink.short" } do
			T.expect(string.find(pl[key], "kursor", 1, true) ~= nil).toBe(true)
			T.expect(string.find(en[key], "cursor", 1, true) ~= nil).toBe(true)
			T.expect(string.find(pl[key], "kierunku ruchu", 1, true)).toBe(nil)
		end
	end)
end)
