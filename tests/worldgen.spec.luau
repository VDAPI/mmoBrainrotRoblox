--!strict
-- S45: the region engine's registries: Logic/WorldGen knows the Meadows (MeadowsGen unchanged), Duskwood and (S46)
-- the Ashen Wastes,
-- Logic/MapTerrain answers for Duskwood what Logic/RegionTerrain does, generator contexts do not share their life
-- points and sketch, and the eternal dusk clock of Logic/DayCycle.

local AshenGen = require("../src/shared/Logic/AshenGen")
local DayCycle = require("../src/shared/Logic/DayCycle")
local DuskwoodGen = require("../src/shared/Logic/DuskwoodGen")
local FrostpeakGen = require("../src/shared/Logic/FrostpeakGen")
local Kit = require("../src/shared/Logic/WorldGen/Kit")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local MeadowsGen = require("../src/shared/Logic/MeadowsGen")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local Test = require("./Test")
local WorldGen = require("../src/shared/Logic/WorldGen")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("WorldGen registry", function()
	it("knows the Meadows, Duskwood, the Ashen Wastes (S46) and the Frost Peaks (S47), nothing else yet", function()
		expect(WorldGen.get("meadows") == (MeadowsGen :: any)).toBe(true)
		expect(WorldGen.get("duskwood") == (DuskwoodGen :: any)).toBe(true)
		expect(WorldGen.get("ashen") == (AshenGen :: any)).toBe(true)
		expect(WorldGen.get("frostpeak") == (FrostpeakGen :: any)).toBe(true)
		expect(WorldGen.get("city")).toBe(nil)
		expect(WorldGen.maps()).toEqual({ "ashen", "duskwood", "frostpeak", "meadows" })
	end)

	it("keeps the Meadows on their own terrain and generator", function()
		expect(RegionTerrain.get("meadows")).toBe(nil)
		expect(MapTerrain.height("meadows", 100, -200)).toBe(MeadowsTerrain.height(100, -200))
		expect(MeadowsGen.counts().builds > 300).toBe(true)
	end)

	it("answers Duskwood's ground through MapTerrain like RegionTerrain", function()
		local T = assert(RegionTerrain.get("duskwood"))
		expect(RegionTerrain.has("duskwood")).toBe(true)
		expect(MapTerrain.has("duskwood")).toBe(true)
		expect(MapTerrain.has("ashen")).toBe(true)
		expect(MapTerrain.has("frostpeak")).toBe(true) -- S47
		expect(MapTerrain.has("frostpeak_cave")).toBe(false)
		for _, p in { { 0, 0 }, { 150, 372 }, { 640, -100 }, { 580, 520 }, { -690, -36 } } do
			expect(MapTerrain.height("duskwood", p[1], p[2])).toBe(T.height(p[1], p[2]))
			expect(MapTerrain.water("duskwood", p[1], p[2])).toBe(T.water(p[1], p[2]))
		end
		expect(MapTerrain.height("frostpeak_cave", 0, 0)).toBe(nil)
		expect(MapTerrain.walkable("frostpeak_cave", 0, 0, 10)).toBe(true)
	end)

	it("gives every generator context its own life points and sketch", function()
		local a, b = Kit.new("duskwood"), Kit.new("duskwood")
		Kit.life(a, "mist", 0, 0, 0)
		Kit.circle(a, "marsh", 0, 0, 10)
		expect(#a.life).toBe(1)
		expect(#b.life).toBe(0)
		expect(#b.sketch).toBe(0)
		expect(a.ground(150, 372)).toBe(MapTerrain.height("duskwood", 150, 372))
	end)

	it("is deterministic: the same Builds on every machine", function()
		local all = DuskwoodGen.all()
		expect(DuskwoodGen.all() == all).toBe(true)
		local first = all[1]
		expect(first.name).toBe("duskGate")
	end)
end)

describe("Eternal dusk (DayCycle.duskClock)", function()
	it("shows the day's hours as a low sun and keeps the night clock", function()
		expect(DayCycle.duskClock(6.5, 0, 17.4, 18.3) >= 17.4).toBe(true)
		expect(math.abs(DayCycle.duskClock(12.5, 0, 17.4, 18.3) - 17.85) < 1e-9).toBe(true)
		expect(DayCycle.duskClock(18.99, 0, 17.4, 18.3) <= 18.3).toBe(true)
		expect(DayCycle.duskClock(23, 1, 17.4, 18.3)).toBe(23)
		expect(DayCycle.duskClock(2, 1, 17.4, 18.3)).toBe(2)
		-- while the light is still mostly night at dawn, the real clock stays
		expect(DayCycle.duskClock(6.1, 0.7, 17.4, 18.3)).toBe(6.1)
	end)
end)
