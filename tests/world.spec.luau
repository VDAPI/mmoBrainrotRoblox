--!strict
-- S08: world data consistency (maps, links, spawns per map, NPC positions). S19: monster groups from named
-- areas, three caves per region.

local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
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

	it("caves are red; boss caves have their dungeon entrance inside", function()
		for id, map in Maps.byId do
			if map.biome == "cave" or map.biome == "crypt" then
				expect(map.zone).toBe("red")
				local cave = Areas.caves.get(id)
				if not cave then
					error(`{id}: cave without Data/Areas/Caves entry`)
				end
				expect(map.dungeonRegion ~= nil).toBe(cave.boss)
				if cave.boss then
					local e = map.dungeonEntrance
					if not e then
						error(`{id}: missing dungeon entrance`)
					end
					expect(math.abs(e.x) < map.size.x / 2 and math.abs(e.z) < map.size.z / 2).toBe(true)
				end
			end
		end
	end)

	it("every region has three caves with an entrance on the region map, away from the border", function()
		for regionId, data in Areas.byMap do
			local map = Maps.get(regionId) :: Maps.MapDef
			expect(#data.caves).toBe(3)
			local bosses = 0
			for _, entrance in data.caves do
				local cave = Areas.caves.get(entrance.cave)
				if not cave or cave.region ~= regionId then
					error(`{regionId}: entrance to unknown cave {entrance.cave}`)
				end
				if cave.boss then
					bosses += 1
				end
				expect(Maps.get(entrance.cave) ~= nil).toBe(true)
				expect(table.find(map.links, entrance.cave) ~= nil).toBe(true)
				-- Border mountains sit fully outside the map since S19; keep 50 studs for the cave mouth.
				expect(math.abs(entrance.x) <= map.size.x / 2 - 50 and math.abs(entrance.z) <= map.size.z / 2 - 50).toBe(
					true
				)
			end
			expect(bosses).toBe(1)
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
	local function regionOf(mapId: string): string
		local cave = Areas.caves.get(mapId)
		return if cave then cave.region else mapId
	end
	local REGION_NUMBER = { meadows = 1, duskwood = 2, ashen = 3, frostpeak = 4 }

	it("cover every region map and cave", function()
		for regionId, data in Areas.byMap do
			expect(#(Spawns.byMap[regionId] or {}) > 0).toBe(true)
			for _, entrance in data.caves do
				expect(#(Spawns.byMap[entrance.cave] or {}) > 0).toBe(true)
			end
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

	it("are groups of 1-4 (elites 1-2, one Elite II) with one kind per member", function()
		for _, list in Spawns.byMap do
			for _, spawner in list do
				local members = spawner.members or {}
				expect(#members).toBe(spawner.count)
				if spawner.variant == "normal" then
					expect(spawner.count).toBeBetween(1, 4)
				elseif spawner.variant == "elite" then
					expect(spawner.count).toBeBetween(1, 2)
				else
					expect(spawner.count).toBe(1)
				end
				expect(members[1]).toBe(spawner.monster)
			end
		end
	end)

	it("put elites only in red zones", function()
		for mapId, list in Spawns.byMap do
			local map = Maps.get(mapId)
			assert(map, mapId)
			for _, spawner in list do
				if spawner.variant ~= "normal" and map.zone ~= "red" then
					error(`{spawner.id}: elite outside a red zone`)
				end
			end
		end
	end)

	it("use monsters of the map's region within the map's levels", function()
		for mapId, list in Spawns.byMap do
			local map = Maps.get(mapId)
			assert(map, mapId)
			for _, spawner in list do
				for _, kind in spawner.members or { spawner.monster } do
					local def = Monsters.get(kind)
					if not def then
						error(`{spawner.id}: unknown monster {kind}`)
					end
					expect(def.region).toBe(REGION_NUMBER[regionOf(mapId)])
				end
				if spawner.level.min < map.minLevel or spawner.level.max > map.maxLevel then
					error(`{spawner.id}: levels {spawner.level.min}-{spawner.level.max} outside {mapId}`)
				end
			end
		end
	end)

	it("give region maps 45-60 groups, 8-10 kinds and 2-3 kinds per area, spread out and off the roads", function()
		for mapId, data in Areas.byMap do
			local list = Spawns.byMap[mapId]
			if #list < 45 or #list > 60 then
				error(`{mapId}: {#list} groups`)
			end
			local kinds = {}
			for _, area in data.areas do
				expect(#area.kinds).toBeBetween(2, 3)
				for _, kind in area.kinds do
					kinds[kind] = true
				end
			end
			local n = 0
			for _ in kinds do
				n += 1
			end
			expect(n).toBeBetween(8, 10)
			for i, a in list do
				expect(AreaSpawns.nearRoad(data.roads, a.position.x, a.position.z, 10)).toBe(false)
				for j = i + 1, #list do
					local b = list[j]
					local d = math.sqrt((a.position.x - b.position.x) ^ 2 + (a.position.z - b.position.z) ^ 2)
					if d < AreaSpawns.MIN_GROUP_DISTANCE then
						error(`{a.id} and {b.id} are {d} apart`)
					end
				end
			end
		end
	end)

	it("give every cave 2-3 normal kinds, 2 elite kinds and exactly one Elite II", function()
		for _, cave in Areas.caves.list do
			expect(#cave.normal).toBeBetween(2, 3)
			expect(#cave.elites).toBe(2)
			expect(cave.elites[1] ~= cave.elites[2]).toBe(true)
			expect(#cave.elite2).toBeBetween(1, 2)
			expect(cave.eliteGroups).toBeBetween(3, 5)
			expect(cave.oreCount).toBeBetween(6, 10)
			local elites, elite2 = {}, 0
			for _, spawner in Spawns.byMap[cave.id] do
				if spawner.variant == "elite" then
					elites[spawner.monster] = true
				elseif spawner.variant == "elite2" then
					elite2 += 1
					expect(spawner.choices ~= nil).toBe(true)
				end
			end
			local n = 0
			for _ in elites do
				n += 1
			end
			expect(n).toBe(2)
			expect(elite2).toBe(1)
		end
	end)

	it("leave no level without normal monsters (within 2 levels)", function()
		for level = 1, 100 do
			local found = false
			for _, list in Spawns.byMap do
				for _, spawner in list do
					if
						spawner.variant == "normal"
						and level >= spawner.level.min - 2
						and level <= spawner.level.max + 2
					then
						found = true
					end
				end
			end
			if not found then
				error(`no normal monsters around level {level}`)
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
