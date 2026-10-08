--!strict
-- S45: the shared height function of the shaped regions (Logic/RegionTerrain) on Duskwood: finite heights inside the
-- writer's range, gentle roads, dry and flat portals, cave mouths, respawn points, the scout, arrivals and sites,
-- the Black Stream continuous and falling from the cliffs to the swamp, bridges over water and a shallow ford, a deep
-- Heart hollow and a tall scarp, everything reachable on foot from the Meadows portal (flood fill), determinism,
-- terrain-only materials and the voxel blocks; plus the frozen heights fixture (S46/S47 must keep it).

local Areas = require("../src/shared/Data/Areas")
local Fixture = require("./fixtures/duskwoodHeights")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local Portals = require("../src/shared/Data/Portals")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local Shapes = require("../src/shared/Data/Terrain")
local TerrainLayers = require("../src/shared/Logic/TerrainLayers")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local T = assert(RegionTerrain.get("duskwood"), "duskwood terrain")
local SHAPE = Shapes.byMap.duskwood
local DATA = Areas.byMap.duskwood
local SITES = assert(DATA.sites, "duskwood sites")
local MAX_SLOPE = math.tan(math.rad(15))

local function slopeAround(x: number, z: number, r: number): number
	local worst = T.slope(x, z, 2)
	for i = 0, 7 do
		local a = i * math.pi / 4
		worst = math.max(worst, T.slope(x + math.cos(a) * r, z + math.sin(a) * r, 2))
	end
	return worst
end

local function nearCrossing(x: number, z: number, extra: number): boolean
	for _, c in T.crossings() do
		if math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) < c.span / 2 + extra then
			return true
		end
	end
	return false
end

-- Places a player must be able to stand on (portals, cave mouths, respawns, the scout, arrivals).
local function standingPlaces(): { { name: string, x: number, z: number } }
	local list = {}
	for _, p in Portals.onMap("duskwood") do
		table.insert(list, { name = `portal {p.id}`, x = p.x, z = p.z })
	end
	for _, c in DATA.caves do
		local a = math.rad(c.rot)
		-- the arrival in front of the mouth (Data/Areas arrivalOf)
		table.insert(list, { name = `cave {c.cave}`, x = c.x - math.sin(a) * 26, z = c.z - math.cos(a) * 26 })
	end
	for i, r in SHAPE.respawns do
		table.insert(list, { name = `respawn {i}`, x = r.x, z = r.z })
	end
	table.insert(list, { name = "scout", x = -690, z = -36 })
	for _, area in DATA.areas do
		local a = assert(area.arrive, area.id)
		table.insert(list, { name = `arrive {area.id}`, x = a.x, z = a.z })
	end
	return list
end

describe("Duskwood terrain", function()
	it("has a finite height everywhere, inside the writer's range", function()
		for x = -860, 860, 20 do
			for z = -860, 860, 20 do
				local h = T.height(x, z)
				expect(h == h and h > SHAPE.writer.bottom + 2 and h < SHAPE.writer.top - 2).toBe(true)
			end
		end
	end)

	it("keeps the roads gentle (< 15 degrees; bridges and the ford carry them over the water)", function()
		local worst, at = 0, ""
		for ri, road in DATA.roads do
			local line = T.roadLine(ri)
			local s = 0
			while s <= line.length do
				local x, z, dx, dz = TerrainLayers.pointAt(line, s)
				if not nearCrossing(x, z, 4) and math.abs(x) < 790 and math.abs(z) < 790 then
					for _, side in { -1, 0, 1 } do
						local off = side * (road.width / 2 - 1.5)
						local px, pz = x - dz * off, z + dx * off
						local slope = T.slope(px, pz, 2)
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

	it("gives portals, cave mouths, respawn points, the scout and arrivals dry ground under 15 degrees", function()
		for _, p in standingPlaces() do
			local slope = slopeAround(p.x, p.z, 10)
			if slope >= MAX_SLOPE or T.isWater(p.x, p.z) then
				error(`{p.name} at {math.floor(p.x)}, {math.floor(p.z)}: slope {math.deg(math.atan(slope))} deg`)
			end
		end
	end)

	it("keeps every site on dry ground", function()
		local wet = { sunkenTower = true, swampJetty = true, stiltVillage = true, blackFall = true, serpentPond = true }
		for name, s in SITES do
			if not wet[name] and T.isWater(s.x, s.z) then
				error(`site {name} is under water`)
			end
		end
	end)

	it("runs the Black Stream continuously, falling from the cliffs to the swamp", function()
		local line = T.streamLine(1)
		local last = math.huge
		local s = 0
		while s <= line.length do
			local level = T.streamLevel(1, s)
			expect(level <= last + 1e-6).toBe(true)
			last = level
			local x, z = TerrainLayers.pointAt(line, s)
			if not nearCrossing(x, z, 2) then
				local w = T.water(x, z)
				if not w then
					error(`no water at {math.floor(x)}, {math.floor(z)} (s = {s})`)
				end
			end
			s += 8
		end
		expect(T.streamLevel(1, 0) - T.streamLevel(1, line.length) > 3).toBe(true)
		-- the head on the plateau stands high over the start of the stream below (the black waterfall)
		local head = T.streamLine(2)
		expect(T.streamLevel(2, head.length) - T.streamLevel(1, 0) >= 10).toBe(true)
	end)

	it("puts the bridges over water and keeps the ford shallow", function()
		local kinds: { [string]: number } = {}
		for _, c in T.crossings() do
			kinds[c.kind] = (kinds[c.kind] or 0) + 1
			expect(c.deck > c.water).toBe(true)
			if c.kind == "ford" then
				local h = T.height(c.x, c.z)
				expect(c.water - h < 1.6).toBe(true)
			end
		end
		expect(kinds.stone).toBe(1)
		expect((kinds.wood or 0) >= 1).toBe(true)
		expect(kinds.ford).toBe(1)
	end)

	it("sinks the Heart's hollow 8+ studs under its rim and raises the scarp 10+ studs", function()
		local tree = SITES.elderTree
		local rim = 0
		for i = 0, 7 do
			local a = i * math.pi / 4
			rim += T.height(tree.x + math.cos(a) * 150, tree.z + math.sin(a) * 140)
		end
		rim /= 8
		expect(rim - T.height(tree.x - 40, tree.z + 10) >= 8).toBe(true)
		for _, z in { -200, -100, 60, 120 } do
			local top, foot = T.height(640, z), T.height(586, z)
			if top - foot < 10 then
				error(`scarp only {top - foot} studs at z = {z}`)
			end
		end
		local floor, deep = T.gorgeFloor(-514, 566)
		expect(floor).toBe(true)
		expect(T.height(-487, 603) - deep >= 9).toBe(true)
	end)

	it("lets a player walk from the Meadows portal to every group, arrival, cave, portal, respawn and site", function()
		-- flood fill on an 8-stud grid: a step is allowed when the rise is at most 32 degrees; shallow water counts
		local STEP = 8
		local N = math.floor(1560 / STEP)
		local function idx(i: number, k: number): number
			return i * (N + 1) + k
		end
		local hs: { number } = {}
		local deep: { boolean } = {}
		for i = 0, N do
			for k = 0, N do
				local x, z = -780 + i * STEP, -780 + k * STEP
				local h = T.height(x, z)
				local w = T.water(x, z)
				hs[idx(i, k)] = h
				deep[idx(i, k)] = w ~= nil and w - h > 3.5
			end
		end
		local function cell(x: number, z: number): (number, number)
			return math.clamp(math.floor((x + 780) / STEP + 0.5), 0, N),
				math.clamp(math.floor((z + 780) / STEP + 0.5), 0, N)
		end
		local seen: { [number]: boolean } = {}
		local si, sk = cell(-740, 0)
		local queue = { { si, sk } }
		seen[idx(si, sk)] = true
		local maxRise = math.tan(math.rad(32)) * STEP
		local head = 1
		while head <= #queue do
			local c = queue[head]
			head += 1
			local h = hs[idx(c[1], c[2])]
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local ni, nk = c[1] + d[1], c[2] + d[2]
				if ni >= 0 and ni <= N and nk >= 0 and nk <= N then
					local key = idx(ni, nk)
					if not seen[key] and not deep[key] and math.abs(hs[key] - h) <= maxRise then
						seen[key] = true
						table.insert(queue, { ni, nk })
					end
				end
			end
		end
		local function reached(x: number, z: number): boolean
			-- the nearest open cell within 12 studs (a target may sit on a cliff's edge or a bridge)
			for dx = -12, 12, STEP / 2 do
				for dz = -12, 12, STEP / 2 do
					local i, k = cell(x + dx, z + dz)
					if seen[idx(i, k)] then
						return true
					end
				end
			end
			return false
		end
		local targets = standingPlaces()
		for name, s in SITES do
			table.insert(targets, { name = `site {name}`, x = s.x, z = s.z })
		end
		local Spawns = require("../src/shared/Logic/AreaSpawns")
		for _, g in Spawns.region(DATA, { x = 1600, z = 1600 }) do
			table.insert(targets, { name = `group {g.id}`, x = g.position.x, z = g.position.z })
		end
		for _, t in targets do
			if not reached(t.x, t.z) then
				error(`{t.name} at {math.floor(t.x)}, {math.floor(t.z)} cannot be reached on foot`)
			end
		end
	end)

	it("is deterministic", function()
		local other = RegionTerrain.new(SHAPE, DATA)
		for _, p in { { 0, 0 }, { 150, 372 }, { 640, -100 }, { -514, 566 }, { 580, 520 } } do
			expect(other.height(p[1], p[2])).toBe(T.height(p[1], p[2]))
			expect(other.material(p[1], p[2])).toBe(T.material(p[1], p[2]))
		end
	end)

	it("paints only terrain materials, with the same list as the Meadows'", function()
		for _, m in MeadowsTerrain.MATERIALS do
			expect(RegionTerrain.MATERIAL_SET[m]).toBe(true)
		end
		local seen: { [string]: boolean } = {}
		for x = -780, 780, 24 do
			for z = -780, 780, 24 do
				local m = T.material(x, z)
				seen[m] = true
				expect(RegionTerrain.MATERIAL_SET[m]).toBe(true)
			end
		end
		-- the cliffs' red rock, the manor's courtyard and the forest floor appear
		expect(seen.Sandstone).toBe(true)
		expect(seen.Cobblestone).toBe(true)
		expect(seen.LeafyGrass and seen.Mud and seen.Ground).toBe(true)
	end)

	it("writes voxel blocks with known materials and water", function()
		local block = T.voxels(560, 480, 16, 16, SHAPE.writer.bottom, 18)
		local water = 0
		for i = 1, 16 do
			for j = 1, 18 do
				for k = 1, 16 do
					local m = block.materials[i][j][k]
					expect(RegionTerrain.MATERIAL_SET[m]).toBe(true)
					if m == "Water" then
						water += 1
					end
				end
			end
		end
		expect(water > 0).toBe(true)
	end)

	it("matches the frozen heights of S45 (S46 and S47 extend the engine without changing Duskwood)", function()
		for _, p in Fixture.points do
			local h = T.height(p[1], p[2])
			if math.abs(h - p[3]) > 0.01 then
				error(`height at {p[1]}, {p[2]}: {h}, fixture {p[3]}`)
			end
			local w = T.water(p[1], p[2])
			expect(w ~= nil).toBe(p[4] ~= false)
			expect(T.material(p[1], p[2])).toBe(p[5])
		end
	end)
end)
