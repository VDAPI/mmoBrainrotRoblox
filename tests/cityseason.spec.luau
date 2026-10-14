--!strict
-- S105: the city's season for one character (Logic/CitySeason: snow once the dragon is beaten, the first spring after
-- the finale) and the spring drawn in the city (Logic/TownGen/Spring: flowers in the gardens, the wreath round the
-- fountain, the maypole on the market square, the petals of the orchards).

local CitySeason = require("../src/shared/Logic/CitySeason")
local Fill = require("../src/shared/Logic/TownGen/Fill")
local Quests = require("../src/shared/Data/Quests")
local Spring = require("../src/shared/Logic/TownGen/Spring")
local Test = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGeom = require("../src/shared/Logic/TownGeom")
local TownTerrain = require("../src/shared/Logic/TownTerrain")

local describe, it, expect = Test.describe, Test.it, Test.expect

local indexOf = Quests.Main.indexOf
local city = Town.city
local ground = TownTerrain.heightAt

local function count(builds: { any }): number
	local n = 0
	for _, b in builds do
		n += #b.bp.pieces
	end
	return n
end

describe("City season (S105 G-T1)", function()
	it("summer until the dragon, snow until the finale, spring after it; old and broken tables are summer", function()
		expect(CitySeason.of(nil)).toBe("summer")
		expect(CitySeason.of({})).toBe("summer")
		expect(CitySeason.of("broken")).toBe("summer")
		expect(CitySeason.of({ mainDone = indexOf.vaelgrath - 1 })).toBe("summer")
		expect(CitySeason.of({ mainDone = indexOf.vaelgrath })).toBe("snow")
		expect(CitySeason.of({ mainDone = indexOf.firstSpring - 1 })).toBe("snow")
		expect(CitySeason.of({ mainDone = indexOf.firstSpring })).toBe("spring")
		expect(CitySeason.of({ mainDone = tostring(indexOf.firstSpring) })).toBe("spring")
		expect(CitySeason.of({ mainDone = "x" })).toBe("summer")
		expect(CitySeason.of({ mainDone = -5 })).toBe("summer")
		expect(CitySeason.isSeason("spring")).toBe(true)
		expect(CitySeason.isSeason("auto")).toBe(false)
	end)
end)

describe("The first spring in Vaelthorn (S105 G-T2..G-T5)", function()
	it("G-T2: deterministic (the same Builds twice) and a fixed maypole", function()
		local a = Spring.all(city, ground, false)
		local b = Spring.all(city, ground, false)
		expect(#a).toBe(#b)
		for i, build in a do
			local other = b[i]
			expect(build.name).toBe(other.name)
			expect(build.at).toEqual(other.at)
			expect(#build.bp.pieces).toBe(#other.bp.pieces)
			for k, piece in build.bp.pieces do
				expect(piece.p).toEqual(other.bp.pieces[k].p)
				expect(piece.c).toBe(other.bp.pieces[k].c)
			end
		end
		expect(Spring.MAYPOLE.x).toBe(20)
		expect(Spring.MAYPOLE.z).toBe(-36)
		expect(a[1].name).toBe("Spring_Maypole")
		expect(a[2].name).toBe("Spring_Wreath")
	end)

	it("G-T3: at most 2500 parts (1200 at low detail), nothing collides or is clickable", function()
		local full, low = Spring.all(city, ground, false), Spring.all(city, ground, true)
		expect(count(full) <= 2500).toBe(true)
		expect(count(low) <= 1200).toBe(true)
		expect(count(low) < count(full)).toBe(true)
		for _, list in { full, low } do
			for _, build in list do
				expect(build.tag).toBe("spring")
				for _, piece in build.bp.pieces do
					expect(piece.col).toBe(false)
					expect(piece.q).toBe(false)
				end
			end
		end
	end)

	it(
		"G-T4: flowers inside their gardens and off the streets; the maypole and the wreath clear of everything",
		function()
			local blooming = 0
			for _, g in city.gardens do
				if not Spring.BLOOMING[g.kind] then
					continue
				end
				blooming += 1
				for _, p in Spring.gardenPoints(g, false) do
					expect(`{g.id} {TownGeom.inPoly(g.poly, p[1], p[2])}`).toBe(`{g.id} true`)
					for _, street in city.streets do
						local d = TownGeom.lineDist(street.pts, p[1], p[2])
						expect(`{g.id} {street.id} {d >= street.w / 2}`).toBe(`{g.id} {street.id} true`)
					end
				end
			end
			expect(blooming > 50).toBe(true)
			local px, pz = Spring.MAYPOLE.x, Spring.MAYPOLE.z
			expect(Spring.poleFree(city, px, pz)).toBe(true)
			local rynek: any = nil
			for _, sq in city.squares do
				if sq.id == "rynek" then
					rynek = sq
				end
			end
			expect(TownGeom.inPoly(rynek.poly, px, pz)).toBe(true)
			local fx, fz = city.fountain[1], city.fountain[2]
			expect(math.sqrt((px - fx) ^ 2 + (pz - fz) ^ 2) >= Spring.WELL_R + 10).toBe(true)
			for _, stall in city.stalls do
				expect(math.sqrt((px - stall.x) ^ 2 + (pz - stall.z) ^ 2) >= 8).toBe(true)
			end
			for _, spot in Town.allNpcSpots() do
				expect(math.sqrt((px - spot.x) ^ 2 + (pz - spot.z) ^ 2) >= 8).toBe(true)
			end
			expect(math.sqrt((px - city.spawn.x) ^ 2 + (pz - city.spawn.z) ^ 2) >= 8).toBe(true)
			for _, sp in city.specials do
				expect(TownGeom.inPoly(TownGeom.rect(sp.x, sp.z, sp.w, sp.d, sp.rot), px, pz)).toBe(false)
			end
			-- the wreath's clumps stand on a ring 9+ studs from the fountain's middle
			local wreath = Spring.all(city, ground, false)[2]
			for _, piece in wreath.bp.pieces do
				expect(math.sqrt(piece.p[1] ^ 2 + piece.p[3] ^ 2) >= 9).toBe(true)
			end
		end
	)

	it(
		"G-T5: petals over the 37 orchards and two over the square, all over the ground; half the orchards at low",
		function()
			local orchards = 0
			for _, g in city.gardens do
				if g.kind == "orchard" then
					orchards += 1
				end
			end
			local points = Spring.petals(city, ground, false)
			expect(#points).toBe(orchards + 2)
			expect(orchards).toBe(37)
			for _, p in points do
				expect(p.y > ground(p.x, p.z)).toBe(true)
			end
			expect(#Spring.petals(city, ground, true)).toBe(math.ceil(orchards / 2) + 2)
			local first = Fill.centroid(city.gardens[1].poly)
			expect(type(first)).toBe("number")
		end
	)
end)

return nil
