--!strict
-- W30: the owner's NPC models fitted to the figure (Logic/NpcAssetFit).

local NpcAssetFit = require("../src/shared/Logic/NpcAssetFit")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("NpcAssetFit.scale", function()
	it("makes the model as tall as the figure", function()
		expect(NpcAssetFit.scale(2, 5)).toBeNear(2.5)
		expect(NpcAssetFit.scale(10, 5)).toBeNear(0.5)
	end)
	it("applies the model's Scale attribute within bounds", function()
		expect(NpcAssetFit.scale(5, 5, 0.85)).toBeNear(0.85)
		expect(NpcAssetFit.scale(5, 5, 1.1)).toBeNear(1.1)
		expect(NpcAssetFit.scale(5, 5, 7)).toBeNear(1)
		expect(NpcAssetFit.scale(5, 5, "big")).toBeNear(1)
	end)
	it("gives nil for a model without height", function()
		expect(NpcAssetFit.scale(0, 5)).toBe(nil)
	end)
end)

describe("NpcAssetFit.yaw", function()
	it("reads degrees and ignores anything else", function()
		expect(NpcAssetFit.yaw(180)).toBeNear(math.pi)
		expect(NpcAssetFit.yaw(nil)).toBe(0)
		expect(NpcAssetFit.yaw(9999)).toBe(0)
		expect(NpcAssetFit.yaw(0 / 0)).toBe(0)
	end)
end)
