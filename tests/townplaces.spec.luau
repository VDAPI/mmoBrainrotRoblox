--!strict
-- S29: dev teleport targets in the city (Logic/TownPlaces): every place resolves to open ground, never inside or
-- on a building.

local Town = require("../src/shared/Data/Town")
local TownPlaces = require("../src/shared/Logic/TownPlaces")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local city = Town.city

describe("TownPlaces", function()
	it("puts rynek on the city spawn", function()
		local spot = TownPlaces.resolve("rynek")
		expect(spot).toBeTruthy()
		local s = spot :: TownPlaces.Spot
		expect(s.x).toBe(city.spawn.x)
		expect(s.z).toBe(city.spawn.z)
	end)

	it("lists every special building and square once", function()
		local seen: { [string]: boolean } = {}
		for _, place in TownPlaces.list() do
			expect(seen[place.id]).toBeNil()
			seen[place.id] = true
		end
		for _, special in city.specials do
			if special.kind ~= "arena" then
				expect(seen[special.id]).toBe(true)
			end
		end
		for _, square in city.squares do
			expect(seen[square.id]).toBe(true)
		end
		expect(seen.arena).toBe(true)
	end)

	it("gives every place a free point inside the walls, off every building", function()
		local half = city.size / 2
		for _, place in TownPlaces.list() do
			local spot = TownPlaces.resolve(place.id)
			if not spot then
				error(`no free point for {place.id}`)
			end
			local s = spot :: TownPlaces.Spot
			expect(math.abs(s.x) <= half and math.abs(s.z) <= half).toBe(true)
			expect(TownTerrain.insideWalls(s.x, s.z)).toBe(true)
			expect(TownTerrain.isOpen(s.x, s.z)).toBe(true)
			expect(TownPlaces.isFree(s.x, s.z)).toBe(true)
		end
	end)

	it("gives every city NPC a free point near it", function()
		for id, npc in Town.allNpcSpots() do
			local spot = TownPlaces.resolve(id)
			if not spot then
				error(`no free point for NPC {id}`)
			end
			local s = spot :: TownPlaces.Spot
			expect(TownPlaces.isFree(s.x, s.z)).toBe(true)
			expect(math.sqrt((s.x - npc.x) ^ 2 + (s.z - npc.z) ^ 2) <= TownPlaces.SEARCH_RADIUS + 5).toBe(true)
			expect(s.lookX).toBe(npc.x)
			expect(s.lookZ).toBe(npc.z)
		end
	end)

	it("rejects the old broken targets: the market hall, the castle and building pieces", function()
		-- Middle of the rynek polygon is inside the market hall (the S23 bug).
		expect(TownPlaces.isFree(20, -15)).toBe(false)
		-- The fountain is not a footprint in TownTerrain.isOpen, only a TownGen piece.
		expect(TownTerrain.isOpen(city.fountain[1], city.fountain[2])).toBe(true)
		expect(TownPlaces.isFree(city.fountain[1], city.fountain[2])).toBe(false)
	end)

	it("returns nil for an unknown place", function()
		expect(TownPlaces.resolve("nowhere")).toBeNil()
	end)
end)
