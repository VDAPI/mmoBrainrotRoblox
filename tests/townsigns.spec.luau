--!strict
-- S21: service signs beside the city NPCs (Logic/TownSigns).

local Town = require("../src/shared/Data/Town")
local TownSigns = require("../src/shared/Logic/TownSigns")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Town signs", function()
	local signs = TownSigns.list()

	it("give every service building one sign", function()
		local wanted: { [string]: boolean } = {}
		for _, spot in Town.city.npcs do
			if spot.at and Town.special(spot.at) then
				wanted[spot.at] = true
			end
		end
		local seen: { [string]: number } = {}
		for _, sign in signs do
			seen[sign.at] = (seen[sign.at] or 0) + 1
		end
		for at in wanted do
			expect(seen[at]).toBe(1)
		end
	end)

	it("stand on open ground, clear of the NPCs, near their NPC", function()
		for _, sign in signs do
			expect(TownTerrain.isOpen(sign.x, sign.z, 1.5)).toBe(true)
			local nearest = math.huge
			for _, spot in Town.city.npcs do
				local d = math.sqrt((spot.x - sign.x) ^ 2 + (spot.z - sign.z) ^ 2)
				expect(d >= 2.5).toBe(true)
				if spot.at == sign.at then
					nearest = math.min(nearest, d)
				end
			end
			expect(nearest <= TownSigns.SIDE * 2 + 0.01).toBe(true)
		end
	end)

	it("have text in both languages", function()
		for _, sign in signs do
			expect(type((pl :: any)[sign.key])).toBe("string")
			expect(type((en :: any)[sign.key])).toBe("string")
		end
	end)
end)
