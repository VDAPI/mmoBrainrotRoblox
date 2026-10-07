--!strict
-- S26: the Whispering Meadows height function (Logic/MeadowsTerrain): finite heights, gentle roads and NPC places,
-- dry portals, cave mouths and arrivals, a continuous brook from the waterfall to Toad Pond, a deep Bear Ravine,
-- determinism and the voxel blocks of the terrain writer.

local Areas = require("../src/shared/Data/Areas")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local Portals = require("../src/shared/Data/Portals")
local Shape = require("../src/shared/Data/Terrain/meadows")
local TerrainLayers = require("../src/shared/Logic/TerrainLayers")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local DATA = Areas.byMap.meadows
local MAX_SLOPE = math.tan(math.rad(15))

-- Steepest slope within `r` studs of a point (centre and a ring of 8).
local function slopeAround(x: number, z: number, r: number): number
	local worst = MeadowsTerrain.slope(x, z, 2)
	for i = 0, 7 do
		local a = i * math.pi / 4
		worst = math.max(worst, MeadowsTerrain.slope(x + math.cos(a) * r, z + math.sin(a) * r, 2))
	end
	return worst
end

local function nearCrossing(x: number, z: number, extra: number): boolean
	for _, c in MeadowsTerrain.crossings() do
		if math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) < c.span / 2 + extra then
			return true
		end
	end
	return false
end

describe("Meadows terrain", function()
	it("has a finite height everywhere, inside the writer's range", function()
		for x = -860, 860, 20 do
			for z = -860, 860, 20 do
				local h = MeadowsTerrain.height(x, z)
				expect(h == h and h > -24 and h < 48).toBe(true)
			end
		end
	end)

	it("keeps the roads gentle (< 15 degrees; bridges and the ford carry the road over the water)", function()
		local worst, at = 0, ""
		for ri, road in DATA.roads do
			local line = MeadowsTerrain.roadLine(ri)
			local s = 0
			while s <= line.length do
				local x, z, dx, dz = TerrainLayers.pointAt(line, s)
				if not nearCrossing(x, z, 4) then
					for _, side in { -1, 0, 1 } do
						local off = side * (road.width / 2 - 1.5)
						local px, pz = x - dz * off, z + dx * off
						local slope = MeadowsTerrain.slope(px, pz, 2)
						if slope > worst then
							worst, at = slope, `road {ri} at {math.floor(px)}, {math.floor(pz)}`
						end
					end
				end
				s += 6
			end
		end
		if worst >= MAX_SLOPE then
			error(`steepest road {math.deg(math.atan(worst))} deg at {at}`)
		end
	end)

	it("gives the NPC places of S27 flat, dry ground within 10 studs", function()
		for name, spot in assert(DATA.npcSpots, "npc spots") do
			local slope = slopeAround(spot.x, spot.z, 10)
			if slope >= MAX_SLOPE or MeadowsTerrain.isWater(spot.x, spot.z) then
				error(`npc spot {name}: slope {math.deg(math.atan(slope))} deg`)
			end
		end
	end)

	it("puts portals, cave mouths and area arrivals on dry ground off the ravine walls", function()
		for _, portal in Portals.onMap("meadows") do
			local x, z = portal.x, portal.z
			if portal.kind == "cave" then
				local a = assert(Areas.arrivalOf(portal.target), portal.target)
				x, z = a.x, a.z
			end
			expect(MeadowsTerrain.walkable(x, z)).toBe(true)
		end
		for _, area in DATA.areas do
			local a = assert(area.arrive, area.id)
			expect(MeadowsTerrain.walkable(a.x, a.z)).toBe(true)
		end
	end)

	it("runs the brook from the waterfall to Toad Pond without a gap, always downhill", function()
		for si, stream in assert(DATA.streams, "streams") do
			local line = MeadowsTerrain.streamLine(si)
			local last = math.huge
			local s = 0
			while s <= line.length do
				local x, z = TerrainLayers.pointAt(line, s)
				local level = MeadowsTerrain.streamLevel(si, s)
				expect(level <= last + 1e-6).toBe(true)
				last = level
				-- the centre line is under water (above the waterfall the stream ends at the cliff)
				if stream.into ~= "fall" or s < line.length - 8 then
					if not MeadowsTerrain.isWater(x, z) then
						error(`{stream.id}: no water at {math.floor(x)}, {math.floor(z)}`)
					end
				end
				s += 4
			end
			if stream.into == "lake" then
				expect(last).toBeNear(MeadowsTerrain.LAKE_LEVEL, 0.01)
			end
		end
		-- the brook starts in the pool under the waterfall and the upper brook ends on the cliff above it
		local brook = MeadowsTerrain.streamLine(1)
		local upper = MeadowsTerrain.streamLine(3)
		local top = MeadowsTerrain.streamLevel(3, upper.length)
		expect(top - MeadowsTerrain.streamLevel(1, 0) > 12).toBe(true)
		local lip = upper.pts[#upper.pts]
		local pool = brook.pts[1]
		expect(math.sqrt((lip[1] - pool[1]) ^ 2 + (lip[2] - pool[2]) ^ 2) < 40).toBe(true)
	end)

	it("cuts Bear Ravine at least 12 studs under its rims", function()
		local pts = Shape.ravine.pts
		for i = 2, #pts do
			local p = pts[i]
			if p.x >= 560 then
				local floor = MeadowsTerrain.height(p.x, p.z)
				local rimN = MeadowsTerrain.height(p.x, p.z - p.half - Shape.ravine.wall - 8)
				local rimS = MeadowsTerrain.height(p.x, p.z + p.half + Shape.ravine.wall + 8)
				-- the path down from the hunter's camp lowers the south rim in places
				expect(math.max(rimN, rimS) - floor >= 12).toBe(true)
				expect(math.min(rimN, rimS) - floor >= 2).toBe(true)
			end
		end
	end)

	it("keeps the ford shallow and the bridges over the water", function()
		local kinds: { [string]: number } = {}
		for _, c in MeadowsTerrain.crossings() do
			kinds[c.kind] = (kinds[c.kind] or 0) + 1
			if c.kind == "ford" then
				local h = MeadowsTerrain.height(c.x, c.z)
				expect(c.water - h <= 1.3).toBe(true)
			else
				expect(c.deck - c.water >= 1.5).toBe(true)
			end
		end
		expect((kinds.stone or 0) + (kinds.wood or 0) >= 3).toBe(true)
		expect(kinds.stone or 0).toBe(1)
		expect(kinds.ford or 0).toBe(1)
	end)

	it("is deterministic", function()
		for _, p in { { -700, 0 }, { 10, 161 }, { 560, -120 }, { 718, 300 }, { -480, 530 }, { 123.4, -567.8 } } do
			local a = MeadowsTerrain.height(p[1], p[2])
			local b = MeadowsTerrain.height(p[1], p[2])
			expect(a).toBe(b)
			expect(MeadowsTerrain.material(p[1], p[2])).toBe(MeadowsTerrain.material(p[1], p[2]))
		end
	end)

	it("uses only materials Roblox terrain accepts (Pebble is part-only: WorldService.Init failed in S26)", function()
		-- Enum.Material values valid for Terrain:WriteVoxels / SetMaterialColor (plus Air and Water).
		local terrain: { [string]: boolean } = {}
		for _, name in
			{
				"Air",
				"Water",
				"Asphalt",
				"Basalt",
				"Brick",
				"Cobblestone",
				"Concrete",
				"CrackedLava",
				"Glacier",
				"Grass",
				"Ground",
				"Ice",
				"LeafyGrass",
				"Limestone",
				"Mud",
				"Pavement",
				"Rock",
				"Salt",
				"Sand",
				"Sandstone",
				"Slate",
				"Snow",
				"WoodPlanks",
			}
		do
			terrain[name] = true
		end
		for _, list in { MeadowsTerrain.MATERIALS, TownTerrain.MATERIALS } do
			for _, name in list do
				if not terrain[name] then
					error(`{name} is not a terrain material`)
				end
			end
		end
	end)

	it("fills voxel blocks with known materials and water in the pond", function()
		local known: { [string]: boolean } = {}
		for _, name in MeadowsTerrain.MATERIALS do
			known[name] = true
		end
		local block = MeadowsTerrain.voxels(-500, 500, 4, 4, -24, 18)
		local hasWater = false
		for i = 1, 4 do
			for j = 1, 18 do
				for k = 1, 4 do
					local m = block.materials[i][j][k]
					expect(known[m]).toBe(true)
					local o = block.occupancy[i][j][k]
					expect(o >= 0 and o <= 1).toBe(true)
					if m == "Water" then
						hasWater = true
					end
				end
			end
		end
		expect(hasWater).toBe(true)
		for x = -780, 780, 60 do
			for z = -780, 780, 60 do
				expect(known[MeadowsTerrain.material(x, z)]).toBe(true)
			end
		end
	end)
end)
