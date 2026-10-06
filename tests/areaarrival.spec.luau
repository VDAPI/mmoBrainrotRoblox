--!strict
-- S22: arrival points of the monster areas (Data/Areas `arrive`, Logic/AreaArrival) and area advice
-- (Logic/AreaAdvice: bands, recommended, locked, quest areas).

local AreaAdvice = require("../src/shared/Logic/AreaAdvice")
local AreaArrival = require("../src/shared/Logic/AreaArrival")
local Areas = require("../src/shared/Data/Areas")
local Maps = require("../src/shared/Data/Maps")
local Spawns = require("../src/shared/Data/Spawns")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Area arrivals", function()
	it("exist for every area, inside the area and the map", function()
		for mapId, data in Areas.byMap do
			local map = assert(Maps.get(mapId))
			for _, area in data.areas do
				local a = assert(area.arrive, area.id)
				local r = area.rect
				expect(a.x >= r[1] and a.x <= r[3] and a.z >= r[2] and a.z <= r[4]).toBe(true)
				expect(math.abs(a.x) <= map.size.x / 2 - AreaArrival.EDGE).toBe(true)
				expect(math.abs(a.z) <= map.size.z / 2 - AreaArrival.EDGE).toBe(true)
			end
		end
	end)

	it("keep clear of water, portals, spawn points, cave mouths and monster groups", function()
		for mapId, data in Areas.byMap do
			local map = assert(Maps.get(mapId))
			local spawners = Spawns.byMap[mapId] or {}
			for _, area in data.areas do
				local a = assert(area.arrive, area.id)
				expect(AreaArrival.valid(data, spawners :: any, map.size, a.x, a.z)).toBe(true)
				for _, spawner in spawners do
					local d = math.sqrt((spawner.position.x - a.x) ^ 2 + (spawner.position.z - a.z) ^ 2)
					expect(d >= 35).toBe(true)
				end
			end
		end
	end)

	it("match the generator (regenerate the data after changing areas)", function()
		for mapId, data in Areas.byMap do
			local map = assert(Maps.get(mapId))
			local computed = AreaArrival.region(data, map.size, map.spawn)
			for _, area in data.areas do
				local a = assert(area.arrive, area.id)
				local c = assert(computed[area.id], area.id)
				expect(a.x).toBe(c.x)
				expect(a.z).toBe(c.z)
			end
		end
	end)

	it("put the first area's arrival beside the map spawn", function()
		for mapId in Areas.byMap do
			local map = assert(Maps.get(mapId))
			local first = assert(AreaAdvice.default(mapId))
			local a = assert(first.arrive, first.id)
			local d = math.sqrt((a.x - map.spawn.x) ^ 2 + (a.z - map.spawn.z) ^ 2)
			expect(d >= 10 and d <= 60).toBe(true)
		end
	end)
end)

describe("Area advice", function()
	local function mapFor(level: number): string
		return if level <= 20
			then "meadows"
			elseif level <= 45 then "duskwood"
			elseif level <= 70 then "ashen"
			else "frostpeak"
	end

	it("recommends areas around the player's level", function()
		for _, level in { 1, 5, 12, 20, 45, 70, 100 } do
			local mapId = mapFor(level)
			local list = AreaAdvice.recommended(level, mapId)
			expect(#list > 0).toBe(true)
			for _, area in list do
				expect(level >= area.lv[1] - 1 and level <= area.lv[2]).toBe(true)
				expect(AreaAdvice.bandOf(area, level) ~= "red").toBe(true)
			end
			local best = assert(AreaAdvice.best(level, mapId))
			expect(AreaAdvice.isRecommended(best, level)).toBe(true)
		end
	end)

	it("locks areas above the player's level and opens them at the minimum level", function()
		for _, area in AreaAdvice.sorted("meadows") do
			expect(AreaAdvice.locked(area, area.lv[1] - 1)).toBe(true)
			expect(AreaAdvice.locked(area, area.lv[1])).toBe(false)
		end
		-- the default (lowest) area of every map is open from the map's own minimum level
		for mapId in Areas.byMap do
			local map = assert(Maps.get(mapId))
			local first = assert(AreaAdvice.default(mapId))
			expect(first.lv[1] <= map.minLevel).toBe(true)
		end
	end)

	it("colours areas by the nearest end of their range", function()
		local area = { lv = { 10, 15 } } :: any
		expect(AreaAdvice.bandOf(area, 12)).toBe("white")
		expect(AreaAdvice.bandOf(area, 9)).toBe("white")
		expect(AreaAdvice.bandOf(area, 5)).toBe("yellow")
		expect(AreaAdvice.bandOf(area, 1)).toBe("red")
		expect(AreaAdvice.bandOf(area, 20)).toBe("green")
		expect(AreaAdvice.bandOf(area, 30)).toBe("grey")
	end)

	it("sorts areas by level and shows more than one colour on a fresh map", function()
		local seen: { [string]: boolean } = {}
		local last = -1
		for _, area in AreaAdvice.sorted("meadows") do
			expect(area.lv[1] >= last).toBe(true)
			last = area.lv[1]
			seen[AreaAdvice.bandOf(area, 1)] = true
		end
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		expect(kinds >= 3).toBe(true)
	end)

	it("points kill quests at an area with the monster at the player's level", function()
		local area, mapId = AreaAdvice.forKind("wolf", 3)
		expect(mapId).toBe("meadows")
		local a = assert(area, "wolf area")
		expect(table.find(a.kinds, "wolf") ~= nil).toBe(true)
		expect(3 >= a.lv[1] and 3 <= a.lv[2]).toBe(true)
		-- out of range: the lowest area with that kind
		local low = assert((AreaAdvice.forKind("wolf", 99)), "lowest wolf area")
		for _, other in AreaAdvice.sorted("meadows") do
			if table.find(other.kinds, "wolf") then
				expect(low.lv[1] <= other.lv[1]).toBe(true)
			end
		end
		expect((AreaAdvice.forKind("no_such_monster", 5))).toBeNil()
	end)
end)

describe("Quest areas", function()
	it("find the cave of an elite kind", function()
		local Areas2 = require("../src/shared/Data/Areas")
		for _, cave in Areas2.caves.list do
			for _, kind in cave.elites do
				local found, mouth = AreaAdvice.caveFor(kind)
				expect(found ~= nil).toBe(true)
				expect(mouth ~= nil).toBe(true)
			end
		end
		expect((AreaAdvice.caveFor("no_such_monster"))).toBeNil()
	end)
end)
