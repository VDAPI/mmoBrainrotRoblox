--!strict
-- S25: route between maps (Logic/MapRoute) and the portal data it uses (Data/Portals).

local Areas = require("../src/shared/Data/Areas")
local MapRoute = require("../src/shared/Logic/MapRoute")
local Maps = require("../src/shared/Data/Maps")
local Portals = require("../src/shared/Data/Portals")
local Town = require("../src/shared/Data/Town")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("MapRoute", function()
	it("reaches every open map from the city and back", function()
		local missing = {}
		for id, map in Maps.byId do
			if map.buildMode ~= "none" then
				local there = MapRoute.path("city", id)
				local back = MapRoute.path(id, "city")
				if not there or not back then
					table.insert(missing, id)
				end
			end
		end
		table.sort(missing)
		expect(missing).toEqual({})
	end)

	it("a map to itself is the map alone", function()
		expect(MapRoute.path("meadows", "meadows")).toEqual({ "meadows" })
		expect(MapRoute.nextExit("meadows", "meadows")).toBeNil()
		expect(MapRoute.hops("ashen", "ashen")).toBe(0)
	end)

	it("from a cave to the city goes through its region map", function()
		for _, cave in Areas.caves.list do
			local route = MapRoute.path(cave.id, "city")
			assert(route, cave.id)
			expect({ cave = cave.id, second = route[2], last = route[#route] }).toEqual({
				cave = cave.id,
				second = cave.region,
				last = "city",
			})
		end
	end)

	it("the next exit stands on the start map and leads along the route", function()
		local exit = MapRoute.nextExit("duskwood", "city")
		assert(exit, "exit")
		expect(exit.id).toBe("duskwood_city")
		local portal = Portals.get(exit.id)
		assert(portal, "portal")
		expect(portal.map).toBe("duskwood")
		expect({ exit.x, exit.z }).toEqual({ portal.x, portal.z })
		-- From the city to a cave of the second region: through Duskwood's gate first.
		expect(MapRoute.path("city", "duskwood_den")).toEqual({ "city", "duskwood", "duskwood_den" })
		local first = MapRoute.nextExit("city", "duskwood_den")
		assert(first, "first")
		expect(first.kind).toBe("gate")
	end)

	it("skips maps that are not open", function()
		local function open(id: string): boolean
			return id ~= "duskwood"
		end
		-- Without Duskwood the Ashen Wastes are still reachable straight from the city gate.
		expect(MapRoute.path("city", "ashen", open)).toEqual({ "city", "ashen" })
		expect(MapRoute.path("city", "duskwood", open)).toBeNil()
		expect(MapRoute.path("city", "duskwood_den", open)).toBeNil()
		expect(MapRoute.nextExit("city", "duskwood", open)).toBeNil()
	end)

	it("is deterministic", function()
		local a = MapRoute.path("frostpeak_hold", "meadows_burrow")
		for _ = 1, 5 do
			expect(MapRoute.path("frostpeak_hold", "meadows_burrow")).toEqual(a)
		end
		expect(a).toEqual({ "frostpeak_hold", "frostpeak", "city", "meadows", "meadows_burrow" })
	end)

	it("reaches the boss chambers through the dungeon gate", function()
		expect(MapRoute.path("city", "dungeon_meadows")).toEqual({
			"city",
			"meadows",
			"meadows_cave",
			"dungeon_meadows",
		})
		local exit = MapRoute.nextExit("meadows_cave", "dungeon_meadows")
		assert(exit, "gate")
		expect(exit.kind).toBe("dungeon")
	end)

	it("unknown maps have no route", function()
		expect(MapRoute.path("city", "nowhere")).toBeNil()
		expect(MapRoute.path("nowhere", "city")).toBeNil()
	end)
end)

describe("Portals data", function()
	it("every portal stands on a map and leads to an existing map", function()
		local bad = {}
		for _, portal in Portals.list do
			if not Maps.get(portal.map) or not Maps.get(portal.target) or portal.map == portal.target then
				table.insert(bad, portal.id)
			end
		end
		expect(bad).toEqual({})
	end)

	it("portals stand inside their map", function()
		local outside = {}
		for _, portal in Portals.list do
			local map = Maps.get(portal.map)
			if map and (math.abs(portal.x) > map.size.x / 2 or math.abs(portal.z) > map.size.z / 2) then
				table.insert(outside, portal.id)
			end
		end
		expect(outside).toEqual({})
	end)

	it("every map link of Data/Maps has a portal", function()
		local missing = {}
		for id, map in Maps.byId do
			for _, link in map.links do
				local found = false
				for _, portal in Portals.onMap(id) do
					if portal.target == link then
						found = true
					end
				end
				if not found then
					table.insert(missing, `{id}->{link}`)
				end
			end
		end
		table.sort(missing)
		expect(missing).toEqual({})
	end)

	it("city gates come from the city plan", function()
		for _, gate in Town.city.gates do
			local portal = Portals.get(gate.portal)
			assert(portal, gate.portal)
			expect({ portal.map, portal.target, portal.x, portal.z }).toEqual({ "city", gate.target, gate.x, gate.z })
		end
	end)

	it("portals back to the city land inside its gate", function()
		for _, portal in Portals.list do
			if portal.target == "city" and portal.kind == "portal" then
				local gate = Town.gate(portal.map)
				assert(gate and portal.arrive, portal.id)
				expect({ portal.arrive.x, portal.arrive.z }).toEqual({ gate.arrive[1], gate.arrive[2] })
			end
		end
	end)
end)

return nil
