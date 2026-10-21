--!strict
-- Owner 2026-10-21: the cost number in a skill slot's corner (Logic/SkillCostBadge).

local SkillCostBadge = require("../src/shared/Logic/SkillCostBadge")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

T.describe("Skill cost badge", function()
	T.it("rounds a cost up like the tooltip", function()
		T.expect(SkillCostBadge.label(12, "mana")).toBe("12")
		T.expect(SkillCostBadge.label(12.2, "energy")).toBe("13")
		T.expect(SkillCostBadge.label(12.0000001, "mana")).toBe("12")
		T.expect(SkillCostBadge.label(0.4, "mana")).toBe("1")
	end)
	T.it("shortens big costs", function()
		T.expect(SkillCostBadge.label(999, "mana")).toBe("999")
		T.expect(SkillCostBadge.label(1000, "mana")).toBe("1k")
		T.expect(SkillCostBadge.label(1540, "mana")).toBe("1.5k")
		T.expect(SkillCostBadge.label(24400, "mana")).toBe("24k")
	end)
	T.it("draws nothing for a free skill or an unknown resource", function()
		T.expect(SkillCostBadge.label(0, "mana")).toBe(nil)
		T.expect(SkillCostBadge.label(nil, "mana")).toBe(nil)
		T.expect(SkillCostBadge.label(0 / 0, "mana")).toBe(nil)
		T.expect(SkillCostBadge.label(10, nil)).toBe(nil)
		T.expect(SkillCostBadge.label(10, "rage")).toBe(nil)
	end)
	T.it("has a colour for every resource a skill costs", function()
		for _, skill in SkillData.byId do
			if skill.resource then
				T.expect(SkillCostBadge.COLORS[skill.resource] ~= nil).toBe(true)
			end
		end
	end)
	T.it("follows the rank: a skill's badge is the cost Skills.cost gives at that rank", function()
		for _, skill in SkillData.byId do
			if skill.resource and skill.cost then
				local low = Skills.cost(skill, 1, 1, skill.class, nil)
				T.expect(SkillCostBadge.label(low, skill.resource))
					.toBe(if low > 0 then tostring(math.max(1, math.ceil(low - 1e-6))) else nil)
				return
			end
		end
	end)
end)

return nil
