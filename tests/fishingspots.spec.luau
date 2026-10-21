--!strict
-- Studio review 2026-10-21 (the Meadows' fishing sign stood in the ravine wall under the waterfall, its buoys on the
-- pool's dry rim): every fishing spot of every map stands on dry, gentle ground at the water's edge with no wall over
-- it, its three buoys float on water the voxels show and the marker keeps clear of the map's builds
-- (Logic/FishingSpots, the rule the generators place them by and the server turns the buoys by).

local fs = require("@lune/fs")

local AshenGen = require("../src/shared/Logic/AshenGen")
local DuskwoodGen = require("../src/shared/Logic/DuskwoodGen")
local FishingSpots = require("../src/shared/Logic/FishingSpots")
local FrostpeakGen = require("../src/shared/Logic/FrostpeakGen")
local MeadowsGen = require("../src/shared/Logic/MeadowsGen")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local TerrainLayers = require("../src/shared/Logic/TerrainLayers")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

type Spot = { x: number, z: number }

local MAPS: { { id: string, T: any, spots: () -> { Spot }, builds: () -> { any }, count: number } } = {
	{ id = "meadows", T = MeadowsTerrain, spots = MeadowsGen.fishingSpots, builds = MeadowsGen.all, count = 3 },
	{
		id = "duskwood",
		T = RegionTerrain.get("duskwood"),
		spots = DuskwoodGen.fishingSpots,
		builds = DuskwoodGen.all,
		count = 2,
	},
	{ id = "ashen", T = RegionTerrain.get("ashen"), spots = AshenGen.fishingSpots, builds = AshenGen.all, count = 2 },
	{
		id = "frostpeak",
		T = RegionTerrain.get("frostpeak"),
		spots = FrostpeakGen.fishingSpots,
		builds = FrostpeakGen.all,
		count = 2,
	},
}

describe("Fishing spots (studio review 2026-10-21)", function()
	it("stand on dry, gentle ground with no wall over them, the buoys on water the voxels show", function()
		for _, map in MAPS do
			local spots = map.spots()
			expect(#spots).toBe(map.count)
			for _, s in spots do
				if not FishingSpots.ok(map.T, s.x, s.z) then
					error(`{map.id}: the fishing spot at {s.x}, {s.z} breaks the rule`)
				end
				-- the water is right beside the spot: the nearest buoy floats within 6 studs
				local face = FishingSpots.face(map.T.height, map.T.water, s.x, s.z) :: number
				local nearest = math.huge
				for _, b in FishingSpots.buoys(s.x, s.z, face) do
					expect(TerrainLayers.voxelWater(map.T.height, map.T.water, b[1], b[2]) ~= nil).toBe(true)
					nearest = math.min(nearest, math.sqrt((b[1] - s.x) ^ 2 + (b[2] - s.z) ^ 2))
				end
				expect(nearest < 6).toBe(true)
			end
		end
	end)

	it("keep the sign and the buoys clear of the builds (jetties, huts, rocks)", function()
		for _, map in MAPS do
			local builds = map.builds()
			for _, s in map.spots() do
				local face = FishingSpots.face(map.T.height, map.T.water, s.x, s.z) :: number
				if not FishingSpots.clearOf(map.T, builds, s.x, s.z, face) then
					error(`{map.id}: the fishing spot at {s.x}, {s.z} stands in a build`)
				end
			end
		end
	end)

	it("puts the Meadows' waterfall spot on the pool's bank, off the ravine wall", function()
		local spot = MeadowsGen.fishingSpots()[2]
		local pool = MeadowsTerrain.streamLevel(1, 0)
		local h = MeadowsTerrain.height(spot.x, spot.z)
		expect(h > pool and h < pool + 2).toBe(true)
		expect(math.sqrt((spot.x - 742) ^ 2 + (spot.z - 270) ^ 2) < 25).toBe(true)
	end)

	it("turns the buoys by the same rule on the server and floats them on the water", function()
		local src = fs.readFile("src/server/Services/GatherService.luau")
		expect(string.find(src, "FishingSpots.face(", 1, true) ~= nil).toBe(true)
		expect(string.find(src, "FishingSpots.buoys(x, z, face)", 1, true) ~= nil).toBe(true)
		expect(string.find(src, "MapTerrain.water(map.id, b[1], b[2])", 1, true) ~= nil).toBe(true)
		-- a turn keeps the buoys' distances from the spot
		for _, face in FishingSpots.FACES do
			for i, b in FishingSpots.buoys(0, 0, face) do
				local o = FishingSpots.BUOYS[i]
				expect(math.abs(math.sqrt(b[1] ^ 2 + b[2] ^ 2) - math.sqrt(o[1] ^ 2 + o[2] ^ 2)) < 1e-9).toBe(true)
			end
		end
		local b = FishingSpots.buoys(10, 20, 90)[3]
		-- the third buoy (9 across, ~8 out): turned a quarter, out is +X
		expect(math.abs(b[1] - (10 + 8 + 5 * math.sin(6.3))) < 1e-6).toBe(true)
	end)
end)
