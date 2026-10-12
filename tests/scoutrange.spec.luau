--!strict
-- S78 (ROZWOJ 11.5): Scout's Eye range on the minimap (Logic/ScoutRange).

local PathData = require("../src/shared/Data/Paths")
local ScoutRange = require("../src/shared/Logic/ScoutRange")
local T = require("./Test")

local SHARE = PathData.HOOK_RULES.scoutEye.shareRange

local function member(id: number, range: number?, x: number, extra: { [string]: any }?): any
	local m: { [string]: any } = { id = id, map = "meadows", x = x, z = 0, dead = false, scoutRange = range }
	for k, v in extra or {} do
		m[k] = v
	end
	return m
end

local function bonus(own: number, members: { any }?): number
	return ScoutRange.bonus(own, members, 1, "meadows", 0, 0, SHARE)
end

T.describe("ScoutRange.bonus", function()
	T.it("shares within 80 studs on the same map, living members only", function()
		T.expect(SHARE).toBe(80)
		T.expect(bonus(0, nil)).toBe(0)
		T.expect(bonus(120, nil)).toBe(120)
		T.expect(bonus(0, { member(2, 180, 70) })).toBe(180)
		T.expect(bonus(0, { member(2, 180, 90) })).toBe(0)
		T.expect(bonus(0, { member(2, 180, 10, { map = "duskwood" }) })).toBe(0)
		T.expect(bonus(0, { member(2, 180, 10, { dead = true }) })).toBe(0)
		T.expect(bonus(30, { member(1, 180, 0) })).toBe(30) -- own entry skipped
		T.expect(bonus(0, { member(2, 60, 10), member(3, 180, 20) })).toBe(180)
		T.expect(bonus(180, { member(2, 60, 10) })).toBe(180)
		T.expect(bonus(0, { member(2, nil, 10) })).toBe(0)
	end)
end)

return nil
