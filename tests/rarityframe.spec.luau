--!strict
-- W28: rarity frame geometry (Logic/RarityFrame): thicker with rarity, scaled to the slot, never over the icon.

local RarityFrame = require("../src/shared/Logic/RarityFrame")
local Rarities = require("../src/shared/Data/Rarities")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("RarityFrame W28", function()
	it("grows with the rarity and Unique is thicker than Common", function()
		for _, size in { 36, 40, 56, 64, 84 } do
			local before = 0
			for id = Rarities.COMMON, Rarities.MYTHIC do
				local band = RarityFrame.band(id, size)
				expect(band >= before).toBe(true)
				before = band
			end
			expect(RarityFrame.band(Rarities.UNIQUE, size) > RarityFrame.band(Rarities.COMMON, size)).toBe(true)
		end
		expect(RarityFrame.band(Rarities.UNIQUE, 64)).toBe(3)
		expect(RarityFrame.band(Rarities.MYTHIC, 64)).toBe(4)
	end)

	it("scales with the slot size and keeps a readable minimum on phone slots", function()
		expect(RarityFrame.band(Rarities.LEGENDARY, 40) < RarityFrame.band(Rarities.LEGENDARY, 84)).toBe(true)
		for id = Rarities.COMMON, Rarities.MYTHIC do
			expect(RarityFrame.band(id, 20) >= 1.5).toBe(true)
			expect(RarityFrame.band(id, 200) <= 6).toBe(true)
		end
	end)

	it("keeps band and glow inside the icon margin", function()
		for _, size in { 36, 40, 52, 64, 84 } do
			for id = Rarities.COMMON, Rarities.MYTHIC do
				local glow = RarityFrame.glow(id, size)
				expect(glow >= RarityFrame.band(id, size)).toBe(true)
				expect(glow <= math.max(RarityFrame.band(id, size), size * RarityFrame.ICON_MARGIN)).toBe(true)
			end
		end
	end)

	it("gives studs and a tint only from Unique", function()
		expect(RarityFrame.stud(Rarities.COMMON, 64)).toBe(0)
		expect(RarityFrame.tint(Rarities.COMMON)).toBe(1)
		for id = Rarities.UNIQUE, Rarities.MYTHIC do
			expect(RarityFrame.stud(id, 40) >= 4).toBe(true)
			expect(RarityFrame.tint(id) < 1).toBe(true)
		end
	end)
end)
