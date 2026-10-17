--!strict
-- W12: the horizon ring beyond a map's edge (Data/Horizons, Logic/HorizonGen).

local HorizonGen = require("../src/shared/Logic/HorizonGen")
local Horizons = require("../src/shared/Data/Horizons")
local Maps = require("../src/shared/Data/Maps")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- The closest other map (studs between the offsets) of `mapId`.
local function nearest(mapId: string): number
	local self = Maps.get(mapId) :: any
	local best = math.huge
	for id, map in Maps.byId do
		if id ~= mapId then
			local dx, dz = map.offset.x - self.offset.x, map.offset.z - self.offset.z
			best = math.min(best, math.sqrt(dx * dx + dz * dz))
		end
	end
	return best
end

describe("Horizon (W12)", function()
	it("is deterministic and has pieces in every arc", function()
		for mapId, def in Horizons.byMap do
			local a = HorizonGen.pieces(mapId)
			local b = HorizonGen.pieces(mapId)
			expect(#a > 0).toBe(true)
			expect(a).toEqual(b)
			expect(#HorizonGen.pieces(mapId, true) < #a).toBe(true)
			for _, arc in def.arcs do
				expect(arc.to > arc.from and arc.step > 0).toBe(true)
			end
		end
	end)

	it("stays beyond the playable area and away from every other map, within the part budget", function()
		for mapId, def in Horizons.byMap do
			local map = Maps.get(mapId) :: any
			local half = math.max(map.size.x, map.size.z) / 2
			local room = nearest(mapId) - half
			local pieces = HorizonGen.pieces(mapId)
			expect(#pieces <= 600).toBe(true)
			for _, p in pieces do
				local r = math.sqrt(p.x * p.x + p.z * p.z)
				-- a piece's reach toward the centre and away from it
				local reach = math.max(p.sx, p.sz) / 2
				expect(`{mapId} {r - reach >= half - 40}`).toBe(`{mapId} true`)
				expect(`{mapId} {r + reach < room}`).toBe(`{mapId} true`)
			end
			for _, mark in def.landmarks do
				expect(mark.dist > half and mark.dist + mark.height < room).toBe(true)
			end
		end
	end)

	it("puts compass degrees where the doc says (0 north = -Z, 90 east = +X)", function()
		local x, z = HorizonGen.at(0, 100)
		expect(math.abs(x) < 1e-9 and math.abs(z + 100) < 1e-9).toBe(true)
		x, z = HorizonGen.at(90, 100)
		expect(math.abs(x - 100) < 1e-9 and math.abs(z) < 1e-9).toBe(true)
	end)
end)
