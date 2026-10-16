--!strict
-- S134h: Logic/CavePlan, the one source of a cave's plan: the scale of the 12 caves (1 for the boss chambers and maps
-- without `scale`), the stretched rooms, corridors, features and points, Logic/CaveTerrain and Logic/AreaSpawns on the
-- same rooms, the drawn cave = the plan's column at (x / s, z / s), anchors and the exits in the rooms after the scale.

local Areas = require("../src/shared/Data/Areas")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local CaveGen = require("../src/shared/Logic/CaveGen")
local CavePlan = require("../src/shared/Logic/CavePlan")
local CaveShapes = require("../src/shared/Data/CaveShapes")
local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
local Maps = require("../src/shared/Data/Maps")
local Portals = require("../src/shared/Data/Portals")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local S = 1.35

describe("Cave plan (S134h)", function()
	it("scales the 12 caves by 1.35 and nothing else", function()
		for _, cave in Areas.caves.list do
			expect(CavePlan.scale(cave.id)).toBe(S)
			expect(CavePlan.heightScale(cave.id)).toBeNear(1 + (S - 1) / 2, 1e-9)
		end
		for _, id in { "dungeon_meadows", "dungeon_duskwood", "dungeon_ashen", "dungeon_frostpeak", "meadows", "city" } do
			expect(CavePlan.scale(id)).toBe(1)
			expect(CavePlan.shape(id) == CaveShapes.byMap[id]).toBe(true)
		end
		expect(CavePlan.coord("meadows_cave", 100)).toBeNear(135, 1e-9)
		local x, z = CavePlan.point("ashen_mine", -20, 40)
		expect(x).toBeNear(-27, 1e-9)
		expect(z).toBeNear(54, 1e-9)
	end)

	it("stretches the rooms, the corridors and the features of the plan", function()
		local hideout = assert(Areas.caves.get("meadows_hideout"))
		local base = CaveGen.generate(assert(hideout.seed, "seed"))
		local plan = CavePlan.plan(hideout)
		expect(#plan.rooms).toBe(#base.rooms)
		for i, r in base.rooms do
			local p = plan.rooms[i]
			expect(p.x).toBeNear(r.x * S, 1e-9)
			expect(p.z).toBeNear(r.z * S, 1e-9)
			expect(p.r).toBeNear(r.r * S, 1e-9)
			expect(p.h).toBeNear(r.h * (1 + (S - 1) / 2), 1e-9)
		end
		for i, c in base.corridors do
			expect(plan.corridors[i].bx).toBeNear(c.bx * S, 1e-9)
			expect(plan.corridors[i].w).toBeNear(c.w * S, 1e-9)
		end
		local shape = assert(CavePlan.shape("meadows_cave"))
		local raw = CaveShapes.byMap.meadows_cave
		for i, f in raw.features do
			local g = shape.features[i]
			if f.x then
				expect(g.x).toBeNear(f.x * S, 1e-9)
				expect(g.z).toBeNear(f.z * S, 1e-9)
			end
			if f.level then
				expect(g.level).toBe(f.level) -- floors and liquid levels stay
			end
		end
		-- the authored data stays in plan units
		expect(raw.scale).toBe(S)
		local rooms = assert(assert(Areas.caves.get("meadows_cave")).rooms, "rooms")
		expect(rooms[1].x).toBe(-250)
	end)

	it("lets the terrain and the spawners see the same rooms", function()
		for _, cave in Areas.caves.list do
			local T = assert(CaveTerrain.get(cave.id))
			local rooms = AreaSpawns.caveRooms(cave)
			for i, r in rooms do
				local t = T.rooms[i]
				expect(t.x).toBeNear(r.x, 1e-6)
				expect(t.z).toBeNear(r.z, 1e-6)
				expect(t.r).toBeNear(r.r, 1e-6)
			end
			local map = assert(Maps.get(cave.id))
			expect(T.HALF * 2 >= map.size.x - 4 and T.HALF * 2 <= map.size.x + 8).toBe(true)
			expect(T.shape == CavePlan.shape(cave.id)).toBe(true)
		end
	end)

	it("draws the plan's column at (x / s, z / s), floors kept, headroom grown", function()
		local T = assert(CaveTerrain.get("duskwood_den"))
		local cave = assert(Areas.caves.get("duskwood_den"))
		local r = CavePlan.rooms(cave)[2]
		local c = T.column(r.x, r.z)
		expect(c.open).toBe(true)
		expect(T.headroom(r.x, r.z) >= 16).toBe(true)
		expect(T.roomAt(r.x, r.z)).toBe(2)
		expect(T.inCore(r.x, r.z)).toBe(true)
	end)

	it("keeps the quest anchors and the exits in their rooms after the scale", function()
		for _, cave in Areas.caves.list do
			local T = assert(CaveTerrain.get(cave.id))
			for _, a in CavePlan.anchors(cave) do
				expect(`{a.id} {T.floor(a.x, a.z) ~= nil and T.liquid(a.x, a.z) == nil}`).toBe(`{a.id} true`)
				local found = assert(Areas.anchorById(a.id))
				expect(found.x).toBeNear(a.x, 1e-9)
			end
			for _, p in Portals.onMap(cave.id) do
				expect(`{p.id} {T.roomAt(p.x, p.z) ~= nil}`).toBe(`{p.id} true`)
			end
			local spawn = assert(Maps.get(cave.id)).spawn
			expect(`{cave.id} spawn {T.roomAt(spawn.x, spawn.z)}`).toBe(`{cave.id} spawn 1`)
		end
	end)
end)
