--!strict
-- S08: world data consistency (maps, links, spawns per map, NPC positions).

local Maps = require("../src/shared/Data/Maps")
local Monsters = require("../src/shared/Data/Monsters")
local Npcs = require("../src/shared/Data/Npcs")
local Spawns = require("../src/shared/Data/Spawns")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("World maps", function()
	it("lists every map from DESIGN §3.2", function()
		for _, id in
			{
				"city",
				"meadows",
				"meadows_cave",
				"duskwood",
				"duskwood_cave",
				"ashen",
				"ashen_cave",
				"frostpeak",
				"frostpeak_cave",
				"dungeon_meadows",
				"dungeon_duskwood",
				"dungeon_ashen",
				"dungeon_frostpeak",
			}
		do
			expect(Maps.get(id) ~= nil).toBe(true)
		end
	end)

	it("links only existing maps, both ways", function()
		for id, map in Maps.byId do
			for _, link in map.links do
				local other = Maps.get(link)
				if not other then
					error(`{id}: unknown link {link}`)
				end
				if not table.find(other.links, id) then
					error(`{id} -> {link} has no way back`)
				end
			end
		end
	end)

	it("caves are red and have their dungeon entrance inside", function()
		for id, map in Maps.byId do
			if map.biome == "cave" or map.biome == "crypt" then
				expect(map.zone).toBe("red")
				expect(map.dungeonRegion ~= nil).toBe(true)
				if map.buildMode == "generated" then
					local e = map.dungeonEntrance
					if not e then
						error(`{id}: missing dungeon entrance`)
					end
					expect(math.abs(e.x) < map.size.x / 2 and math.abs(e.z) < map.size.z / 2).toBe(true)
				end
			end
		end
	end)

	it("has lighting values in range", function()
		for _, map in Maps.byId do
			local l = map.lighting
			expect(l.clockTime >= 0 and l.clockTime <= 24).toBe(true)
			expect(l.fogEnd > 50).toBe(true)
			expect(l.atmosphere.density >= 0 and l.atmosphere.density <= 1).toBe(true)
		end
	end)
end)

describe("World spawns", function()
	it("cover the four built region maps", function()
		for _, id in
			{
				"meadows",
				"meadows_cave",
				"duskwood",
				"duskwood_cave",
				"ashen",
				"ashen_cave",
				"frostpeak",
				"frostpeak_cave",
			}
		do
			expect(#(Spawns.byMap[id] or {}) > 0).toBe(true)
		end
	end)

	it("stay inside their map", function()
		for mapId, list in Spawns.byMap do
			local map = Maps.get(mapId)
			assert(map, mapId)
			for _, spawner in list do
				local x, z = spawner.position.x, spawner.position.z
				if math.abs(x) + spawner.radius > map.size.x / 2 or math.abs(z) + spawner.radius > map.size.z / 2 then
					error(`{spawner.id} lies outside {mapId}`)
				end
			end
		end
	end)

	it("put elites only in red zones and normal monsters outside caves", function()
		for mapId, list in Spawns.byMap do
			local map = Maps.get(mapId)
			assert(map, mapId)
			for _, spawner in list do
				if spawner.variant ~= "normal" and map.zone ~= "red" then
					error(`{spawner.id}: elite outside a red zone`)
				end
				if spawner.variant == "normal" and map.zone == "red" then
					error(`{spawner.id}: normal monster in a cave`)
				end
			end
		end
	end)

	it("use monsters of the map's region within the map's levels", function()
		local regionOf = {
			meadows = 1,
			meadows_cave = 1,
			duskwood = 2,
			duskwood_cave = 2,
			ashen = 3,
			ashen_cave = 3,
			frostpeak = 4,
			frostpeak_cave = 4,
		}
		for mapId, list in Spawns.byMap do
			local map = Maps.get(mapId)
			assert(map, mapId)
			for _, spawner in list do
				local def = Monsters.get(spawner.monster)
				assert(def, spawner.monster)
				expect(def.region).toBe(regionOf[mapId])
				if spawner.level.min < map.minLevel or spawner.level.max > map.maxLevel then
					error(`{spawner.id}: levels {spawner.level.min}-{spawner.level.max} outside {mapId}`)
				end
			end
		end
	end)

	it("spawn 6-10 normal monsters per spawner", function()
		for _, list in Spawns.byMap do
			for _, spawner in list do
				if spawner.variant == "normal" then
					expect(spawner.count >= 6 and spawner.count <= 10).toBe(true)
				end
			end
		end
	end)
end)

describe("NPCs", function()
	it("stand inside the city walls or inside their map", function()
		for _, npc in Npcs.list do
			local map = Maps.get(npc.map)
			assert(map, npc.map)
			if npc.map == "city" then
				expect(math.abs(npc.position.x) < 290 and math.abs(npc.position.z) < 290).toBe(true)
			else
				expect(math.abs(npc.position.x) < map.size.x / 2 and math.abs(npc.position.z) < map.size.z / 2).toBe(
					true
				)
			end
		end
	end)
end)
