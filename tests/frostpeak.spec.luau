--!strict
-- S47: the Frost Peaks rebuilt on the shared region engine: the areas of the brief, terrain (heights, materials,
-- determinism), real ridges instead of the old "lakes" in the pass, the frozen lakes (flat walkable ice, water in
-- the ice holes and under the ice), the frozen brook, crevasses with a way out, glacier tongues, gentle roads into
-- every area, the places a player stands on, the walk from the portal to everything, every group on safe ground,
-- the generator (budget, Builds on the ground, cave mouths, nodes by the areas' character, fishing spots, life and
-- sketch) and the mood (day and night, ambience, decoration themes, wind everywhere).

local Ambience = require("../src/shared/Data/Ambience")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local FrostpeakGen = require("../src/shared/Logic/FrostpeakGen")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local Maps = require("../src/shared/Data/Maps")
local Portals = require("../src/shared/Data/Portals")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local Shapes = require("../src/shared/Data/Terrain")
local TerrainLayers = require("../src/shared/Logic/TerrainLayers")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local T = assert(RegionTerrain.get("frostpeak"), "frostpeak terrain")
local SHAPE = Shapes.byMap.frostpeak
local DATA = Areas.byMap.frostpeak
local SITES = assert(DATA.sites, "frostpeak sites")
local MAP = assert(Maps.get("frostpeak"))
local MAX_SLOPE = math.tan(math.rad(15))

-- The areas of the brief (S47 "Obszary Szczytów"): id, levels, kinds, groups, profile.
local BRIEF = {
	{ "frostpeak_valley", { 70, 75 }, { "iceWolf", "snowLeopard" }, 8, nil },
	{ "frostpeak_slopes", { 74, 80 }, { "yeti", "snowLeopard" }, 7, "exp" },
	{ "frostpeak_harpyrocks", { 76, 83 }, { "peakHarpy", "yeti" }, 6, "loot" },
	{ "frostpeak_pass", { 78, 86 }, { "frostGiant", "peakHarpy" }, 7, nil },
	{ "frostpeak_lake", { 82, 90 }, { "iceElemental", "iceMammoth" }, 6, "loot" },
	{ "frostpeak_tundra", { 82, 89 }, { "iceMammoth", "frostGiant" }, 6, "exp" },
	{ "frostpeak_temple", { 85, 95 }, { "dragonspawn", "frozenKnight" }, 7, "gold" },
	{ "frostpeak_icewatch", { 88, 95 }, { "frozenKnight", "iceElemental" }, 5, "exp" },
	{ "frostpeak_wyrmspire", { 94, 100 }, { "frostWyrm", "dragonspawn" }, 5, nil },
}

local function inRect(r: { number }, x: number, z: number): boolean
	return x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4]
end

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

-- Places a player must be able to stand on: portals, the arrivals in front of the cave mouths, respawn points, the
-- scout, the areas' arrivals.
local function standingPlaces(): { { name: string, x: number, z: number } }
	local list = {}
	for _, p in Portals.onMap("frostpeak") do
		if p.kind == "portal" then
			table.insert(list, { name = `portal {p.id}`, x = p.x, z = p.z })
		end
	end
	for _, c in DATA.caves do
		local a = math.rad(c.rot)
		table.insert(list, { name = `cave {c.cave}`, x = c.x - math.sin(a) * 22, z = c.z - math.cos(a) * 22 })
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

-- The buoys of a fishing spot (Services/GatherService): x + 9 cos(2.1 i), z + 8 + 5 sin(2.1 i).
local function buoys(x: number, z: number): { { number } }
	local out = {}
	for i = 1, 3 do
		table.insert(out, { x + 9 * math.cos(2.1 * i), z + 8 + 5 * math.sin(2.1 * i) })
	end
	return out
end

describe("Frost Peaks: data", function()
	it("keeps the areas of the brief (ids, levels, kinds, groups, profiles; 57 groups) without overlaps", function()
		expect(#DATA.areas).toBe(#BRIEF)
		local total = 0
		for i, b in BRIEF do
			local a = DATA.areas[i]
			expect(a.id).toBe(b[1])
			expect(a.nameKey).toBe(`area.{b[1]}`)
			expect(a.lv).toEqual(b[2])
			expect(a.kinds).toEqual(b[3])
			expect(a.groups).toBe(b[4])
			expect(a.profile).toBe(b[5])
			total += a.groups
		end
		expect(total).toBe(57)
		for i, a in DATA.areas do
			for k, other in DATA.areas do
				if k > i then
					local r, o = a.rect, other.rect
					if r[1] < o[3] and o[1] < r[3] and r[2] < o[4] and o[2] < r[4] then
						error(`{a.id} overlaps {other.id}`)
					end
				end
			end
		end
	end)

	it("keeps the cave mouths and the portals where they were", function()
		local caves = {
			{ "frostpeak_grotto", -300, -745, 180 },
			{ "frostpeak_hold", 300, -745, 180 },
			{ "frostpeak_cave", 745, 0, 90 },
		}
		for i, c in caves do
			local e = DATA.caves[i]
			expect(e.cave).toBe(c[1])
			expect(e.x).toBe(c[2])
			expect(e.z).toBe(c[3])
			expect(e.rot).toBe(c[4])
		end
		local portals: { [string]: { number } } = { frostpeak_ashen = { -770, 0 }, frostpeak_city = { -770, 160 } }
		for id, p in portals do
			local portal = assert(Portals.get(id), id)
			expect(portal.x).toBe(p[1])
			expect(portal.z).toBe(p[2])
		end
	end)

	it("gives every area a decoration theme, a landmark (its site) and a mood with sounds to fill in", function()
		for _, a in DATA.areas do
			expect(type(a.decor)).toBe("string")
			local mark = assert(a.landmark, `{a.id} landmark`)
			expect(inRect(a.rect, mark.x, mark.z)).toBe(true)
			local isSite = false
			for _, s in SITES do
				if s.x == mark.x and s.z == mark.z then
					isSite = true
				end
			end
			expect(isSite).toBe(true)
			local mood = assert(Ambience.moodOf("frostpeak", a.id), `{a.id} mood`)
			expect(#mood.sounds.day > 0 and #mood.sounds.night > 0).toBe(true)
			for _, list in { mood.sounds.day, mood.sounds.night } do
				for _, s in list do
					expect(s.id).toBe("")
					expect(#s.hint > 10).toBe(true)
				end
			end
		end
		expect(Ambience.moodOf("frostpeak", nil) ~= nil).toBe(true)
		for _, p in Ambience.points.frostpeak do
			expect(math.abs(p.x) <= 800 and math.abs(p.z) <= 800).toBe(true)
		end
	end)

	it("has day and night, a night of its own, a background build and a part budget", function()
		expect(MAP.dayNight).toBe(true)
		expect(MAP.nightLighting ~= nil and MAP.nightLighting ~= MAP.lighting).toBe(true)
		expect(MAP.buildLate).toBe(true)
		expect(MAP.maxParts).toBe(2600)
	end)

	it("names its sites uniquely across all maps (/tparea finds them on any map)", function()
		local seen: { [string]: string } = {}
		for mapId, data in Areas.byMap do
			for name in (data.sites or {}) :: { [string]: any } do
				if seen[name] then
					error(`site {name} on {mapId} and {seen[name]}`)
				end
				seen[name] = mapId
			end
		end
		for _, name in { "trapperCamp", "giantsGate", "frozenBoat", "dragonStairs", "wyrmBones", "summit" } do
			expect(seen[name]).toBe("frostpeak")
		end
	end)

	it(
		"keeps only ice holes in `lakes` (water in the middle of every circle, no ridges pretending to be lakes)",
		function()
			expect(#DATA.lakes).toBe(2)
			for _, lake in DATA.lakes do
				expect(T.water(lake.x, lake.z) ~= nil).toBe(true)
				expect(lake.r >= 18).toBe(true)
			end
		end
	)

	it("covers the whole map with wind zones (snowfall, plumes, the wind's loudness)", function()
		for x = -780, 780, 60 do
			for z = -780, 780, 60 do
				local dir, strength, gust = T.windAt(x, z)
				expect(dir >= 0 and dir < 360).toBe(true)
				expect(strength > 0.05 and strength <= 1).toBe(true)
				expect(gust >= 0 and gust <= 1).toBe(true)
			end
		end
		local _, valley = T.windAt(-640, 100)
		local _, spire = T.windAt(650, -560)
		expect(spire > valley + 0.3).toBe(true)
	end)
end)

describe("Frost Peaks: terrain", function()
	it("has a finite height everywhere, inside the writer's range", function()
		for x = -860, 860, 20 do
			for z = -860, 860, 20 do
				local h = T.height(x, z)
				expect(h == h and h > SHAPE.writer.bottom + 2 and h < SHAPE.writer.top - 2).toBe(true)
			end
		end
	end)

	it("paints only terrain materials, snow, ice and glacier among them", function()
		local seen: { [string]: boolean } = {}
		for x = -780, 780, 16 do
			for z = -780, 780, 16 do
				local m = T.material(x, z)
				seen[m] = true
				expect(RegionTerrain.MATERIAL_SET[m]).toBe(true)
				expect(m ~= "Water" or T.isWater(x, z)).toBe(true)
			end
		end
		for _, m in { "Snow", "Ice", "Glacier", "Slate", "Rock", "Salt", "Ground", "Cobblestone" } do
			if not seen[m] then
				error(`no {m} on the Frost Peaks`)
			end
		end
	end)

	it("is deterministic", function()
		local other = RegionTerrain.new(SHAPE, DATA)
		for _, p in { { 0, 0 }, { 60, -280 }, { 166, 584 }, { -560, 612 }, { 690, -650 }, { 745, 0 } } do
			expect(other.height(p[1], p[2])).toBe(T.height(p[1], p[2]))
			expect(other.material(p[1], p[2])).toBe(T.material(p[1], p[2]))
		end
	end)

	it("raises the North and South Ridge 45+ studs over the pass floor; their walls are not to stand on", function()
		local floor = T.height(60, 0)
		expect(floor >= 26 and floor <= 36).toBe(true)
		local north, south = 0, 0
		for x = -60, 200, 4 do
			for z = -340, -250, 4 do
				north = math.max(north, T.height(x, z))
			end
			for z = 270, 340, 4 do
				south = math.max(south, T.height(x, z))
			end
		end
		expect(north - floor >= 45).toBe(true)
		expect(south - floor >= 45).toBe(true)
		-- the steep walls facing the pass
		expect(T.walkable(-20, -270)).toBe(false)
		expect(T.walkable(150, 300)).toBe(false)
		expect(T.mountainAt(60, -278)).toBe(true)
		-- the horn rises over its plateau and nobody stands on it
		local summit = T.height(690, -650)
		expect(summit >= 130).toBe(true)
		expect(T.walkable(690, -650)).toBe(false)
		expect(T.walkable(660, -650)).toBe(false)
	end)

	it("lets the lake road cross the South Ridge only at its saddle (y ~38)", function()
		local h = T.height(82, 300)
		expect(h >= 32 and h <= 46).toBe(true)
		local crest = T.height(20, 302)
		expect(crest - h >= 30).toBe(true)
	end)

	it("makes the frozen lakes flat walkable ice with water under it and open water in the ice holes", function()
		for fi, fl in assert(SHAPE.frozenLakes, "frozenLakes") do
			local lobe = fl.lobes[1]
			if lobe.rx < 50 then
				continue -- the pool under the falls lies against the cliff
			end
			local lo, hi = math.huge, -math.huge
			for _, f in { { 0, 0 }, { 0.4, 0 }, { -0.4, 0.2 }, { 0, 0.45 }, { 0.3, -0.4 }, { -0.35, -0.3 } } do
				local x, z = lobe.x + f[1] * lobe.rx, lobe.z + f[2] * lobe.rz
				local onHole = false
				for _, lake in DATA.lakes do
					if (x - lake.x) ^ 2 + (z - lake.z) ^ 2 < (lake.r + 3) ^ 2 then
						onHole = true
					end
				end
				if not onHole then
					local h = T.height(x, z)
					lo, hi = math.min(lo, h), math.max(hi, h)
					expect(T.water(x, z)).toBe(nil)
					expect(T.ice(x, z) ~= nil).toBe(true)
					expect(T.walkable(x, z) or not T.dryAround(x, z, 1)).toBe(true)
					expect(T.material(x, z) == "Ice" or T.material(x, z) == "Glacier").toBe(true)
				end
			end
			if hi - lo > 2 then
				error(`frozen lake {fi} not flat: {lo}..{hi}`)
			end
		end
		-- the voxel column under the ice: water between the bed and the ice
		local lobe = assert(SHAPE.frozenLakes, "frozenLakes")[1].lobes[1]
		local ny = 12
		local vox = T.voxels(lobe.x - 60, lobe.z - 40, 1, 1, SHAPE.writer.bottom + 16, ny)
		local hasWater, hasIce = false, false
		for j = 1, ny do
			local m = vox.materials[1][j][1]
			if m == "Water" then
				hasWater = true
			elseif m == "Ice" or m == "Glacier" then
				expect(hasWater).toBe(true)
				hasIce = true
			end
		end
		expect(hasWater and hasIce).toBe(true)
		for _, lake in DATA.lakes do
			expect(T.water(lake.x, lake.z) ~= nil).toBe(true)
			expect(T.ice(lake.x, lake.z)).toBe(nil)
		end
	end)

	it("freezes the Ice Brook: a continuous ribbon of ice whose level never rises downstream", function()
		local streams = assert(DATA.streams, "streams")
		expect(streams[1].frozen).toBe(true)
		local line = T.streamLine(1)
		local last = math.huge
		local s = 0
		while s <= line.length do
			local x, z = TerrainLayers.pointAt(line, s)
			local level = T.streamLevel(1, s)
			expect(level <= last + 1e-6).toBe(true)
			last = level
			if not nearCrossing(x, z, 0) and T.ice(x, z) == nil then
				error(`no ice on the brook at {math.floor(x)}, {math.floor(z)}`)
			end
			expect(T.water(x, z)).toBe(nil)
			s += 6
		end
	end)

	it("keeps crevasses shallow with a way out of every stretch, and nobody near them", function()
		for ci, c in assert(SHAPE.crevasses, "crevasses") do
			local pts = TerrainLayers.pairs(c.points)
			local line = TerrainLayers.line(pts)
			-- the ends meet the surface
			for _, s in { 0, line.length } do
				local x, z = TerrainLayers.pointAt(line, s)
				local around = (T.height(x + 12, z) + T.height(x - 12, z) + T.height(x, z + 12) + T.height(x, z - 12))
					/ 4
				expect(math.abs(T.height(x, z) - around) < 4).toBe(true)
			end
			local deepest = 0
			local s = 4
			while s < line.length - 4 do
				local x, z = TerrainLayers.pointAt(line, s)
				local ox, oz = TerrainLayers.pointAt(line, s)
				local dx, dz = select(3, TerrainLayers.pointAt(line, s))
				local lip = math.max(T.height(ox - dz * 14, oz + dx * 14), T.height(ox + dz * 14, oz - dx * 14))
				local depth = lip - T.height(x, z)
				deepest = math.max(deepest, depth)
				if depth > 14 + 4 then
					error(`crevasse {ci} {depth} studs deep at {math.floor(x)}, {math.floor(z)}`)
				end
				expect(T.walkable(x, z)).toBe(false)
				expect(T.walkable(ox - dz * (c.width / 2 + 4), oz + dx * (c.width / 2 + 4))).toBe(false)
				-- the floor never drops faster than ~32 degrees along the line (the ramps to the ends and bridges)
				local ahead = T.height(TerrainLayers.pointAt(line, s + 4))
				expect(math.abs(ahead - T.height(x, z)) <= math.tan(math.rad(32)) * 4 + 0.6).toBe(true)
				s += 4
			end
			expect(deepest >= 5).toBe(true)
			expect(T.roadDistance(pts[1][1], pts[1][2]) > 20).toBe(true)
		end
	end)

	it("lays glacier tongues: glacier ice on the axis and a front wall 8+ studs over the ground before it", function()
		for gi, g in assert(SHAPE.glaciers, "glaciers") do
			local a, b = g.pts[#g.pts - 1], g.pts[#g.pts]
			local ux, uz = b[1] - a[1], b[2] - a[2]
			local len = math.sqrt(ux * ux + uz * uz)
			ux, uz = ux / len, uz / len
			-- 30 studs back from the front, off any cleft or niche on the axis
			local bx, bz = b[1] - ux * 30 + uz * (b[3] * 0.6), b[2] - uz * 30 - ux * (b[3] * 0.6)
			expect(T.glacierAt(bx, bz)).toBe(true)
			local mat = T.material(bx, bz)
			expect(mat == "Glacier" or mat == "Ice").toBe(true)
			local fx, fz =
				b[1] + ux * (g.front + 16) + uz * (b[3] * 0.6), b[2] + uz * (g.front + 16) - ux * (b[3] * 0.6)
			if T.height(bx, bz) - T.height(fx, fz) < 8 then
				error(`glacier {gi}: front only {T.height(bx, bz) - T.height(fx, fz)} studs`)
			end
			-- the tongue ends in a wall across its axis, not in a half-disc
			expect(T.glacierAt(b[1] + ux * (g.front + 6), b[2] + uz * (g.front + 6))).toBe(false)
		end
	end)

	it("cuts flat places into the glaciers for the Frozen Hold and the Glacier Heart, with a road to each", function()
		for _, c in DATA.caves do
			if c.cave ~= "frostpeak_grotto" then
				local a = math.rad(c.rot)
				local x, z = c.x - math.sin(a) * 18, c.z - math.cos(a) * 18
				expect(slopeAround(x, z, 8) < MAX_SLOPE).toBe(true)
				expect(T.roadDistance(c.x - math.sin(a) * 26, c.z - math.cos(a) * 26) < 20).toBe(true)
			end
		end
	end)

	it("keeps the roads gentle (< 15 degrees off the bridges), off the ridges, crevasses and ice holes", function()
		local worst, at = 0, ""
		for ri, road in DATA.roads do
			local line = T.roadLine(ri)
			local s = 0
			while s <= line.length do
				local x, z, dx, dz = TerrainLayers.pointAt(line, s)
				if not nearCrossing(x, z, 4) and math.abs(x) < 790 and math.abs(z) < 790 then
					expect(T.crevasseDistance(x, z) > 8).toBe(true)
					expect(T.water(x, z)).toBe(nil)
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

	it("leads a road into every area (no fallback arrivals)", function()
		for _, area in DATA.areas do
			local found = false
			for _, road in DATA.roads do
				local p = road.points
				for i = 1, #p - 3, 2 do
					for t = 0, 1, 0.05 do
						local x, z = p[i] + (p[i + 2] - p[i]) * t, p[i + 1] + (p[i + 3] - p[i + 1]) * t
						if inRect(area.rect, x, z) then
							found = true
						end
					end
				end
			end
			if not found then
				error(`no road into {area.id}`)
			end
		end
	end)

	it(
		"gives portals, cave exits, respawns, the scout and arrivals dry, gentle ground off ice holes and crevasses",
		function()
			for _, p in standingPlaces() do
				local slope = slopeAround(p.x, p.z, 10)
				if slope >= MAX_SLOPE or T.isWater(p.x, p.z) or T.crevasseDistance(p.x, p.z) < 10 then
					error(`{p.name} at {math.floor(p.x)}, {math.floor(p.z)}: slope {math.deg(math.atan(slope))} deg`)
				end
			end
		end
	)

	it("lets a player walk from the Ashen portal to every group, arrival, cave, portal, respawn and site", function()
		local STEP = 8
		local N = math.floor(1560 / STEP)
		local function idx(i: number, k: number): number
			return i * (N + 1) + k
		end
		local hs: { number } = {}
		local blocked: { boolean } = {}
		for i = 0, N do
			for k = 0, N do
				local x, z = -780 + i * STEP, -780 + k * STEP
				local h = T.height(x, z)
				local w = T.water(x, z)
				hs[idx(i, k)] = h
				blocked[idx(i, k)] = (w ~= nil and w - h > 3.5) or (w ~= nil and T.ice(x, z) == nil and w > h + 0.5)
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
					if not seen[key] and not blocked[key] and math.abs(hs[key] - h) <= maxRise then
						seen[key] = true
						table.insert(queue, { ni, nk })
					end
				end
			end
		end
		local function reached(x: number, z: number): boolean
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
		-- sites on a spire, a horn or in a wall are seen, not walked to
		local aloft = { harpyQueen = true, summit = true, frozenFalls = true, grottoMouth = true, holdGate = true }
		aloft.glacierMouth = true
		for name, s in SITES do
			if not aloft[name] then
				table.insert(targets, { name = `site {name}`, x = s.x, z = s.z })
			end
		end
		for _, g in AreaSpawns.region(DATA, MAP.size) do
			table.insert(targets, { name = `group {g.id}`, x = g.position.x, z = g.position.z })
		end
		for _, t in targets do
			if not reached(t.x, t.z) then
				error(`{t.name} at {math.floor(t.x)}, {math.floor(t.z)} cannot be reached on foot`)
			end
		end
	end)
end)

describe("Frost Peaks: monster groups", function()
	it("places exactly every area's groups on gentle ground, off ridges, crevasses, ice holes and buildings", function()
		local per: { [string]: number } = {}
		for _, s in AreaSpawns.region(DATA, MAP.size) do
			per[s.areaId] = (per[s.areaId] or 0) + 1
			local x, z = s.position.x, s.position.z
			if not MapTerrain.walkable("frostpeak", x, z, AreaSpawns.CLIFF_CLEARANCE) then
				error(`group {s.id} at {x}, {z} is not on walkable ground`)
			end
			expect(math.abs(s.position.y - T.height(x, z)) <= 1).toBe(true)
			expect(T.mountainAt(x, z)).toBe(false)
			expect(T.crevasseDistance(x, z) > RegionTerrain.CREVASSE_CLEARANCE).toBe(true)
			for _, lake in DATA.lakes do
				if math.sqrt((x - lake.x) ^ 2 + (z - lake.z) ^ 2) - lake.r < 16 then
					error(`group {s.id} at {x}, {z} by an ice hole`)
				end
			end
			if T.streamDistance(x, z) < 12 then
				error(`group {s.id} at {x}, {z} by the brook`)
			end
			for name, site in SITES do
				if (x - site.x) ^ 2 + (z - site.z) ^ 2 < 12 * 12 then
					error(`group {s.id} stands in {name}`)
				end
			end
		end
		for _, a in DATA.areas do
			expect(per[a.id]).toBe(a.groups)
		end
	end)
end)

describe("Frost Peaks: generator", function()
	it("stays within the server part budget (shell + ~300 for portals, signs and nodes); detail over shell", function()
		local c = FrostpeakGen.counts()
		if c.shell + 300 > assert(MAP.maxParts, "maxParts") then
			error(`shell {c.shell} + 300 > {MAP.maxParts}`)
		end
		expect(c.detail > c.shell).toBe(true)
		local trees = FrostpeakGen.trees()
		expect(#trees >= 150).toBe(true)
		for _, t in trees do
			expect(t.kind == "snowPine" or t.kind == "frozenDead" or t.kind == "iceSpike").toBe(true)
			expect(T.ice(t.x, t.z)).toBe(nil)
			expect(T.height(t.x, t.z) < 70 or t.kind == "iceSpike").toBe(true)
		end
	end)

	it("builds every Build on the ground and inside the map", function()
		local aloft: { [string]: boolean } = { bridge = true, trees = true, ice = true, peak = true }
		for _, b in FrostpeakGen.all() do
			if b.tag ~= "trees" and (math.abs(b.at.x) > 800 or math.abs(b.at.z) > 800) then
				error(`{b.name} outside the map`)
			end
			if not aloft[b.tag] then
				local g = T.height(b.at.x, b.at.z)
				if math.abs(b.at.y - g) > 6 then
					error(`{b.name} stands {b.at.y - g} studs off the ground`)
				end
			end
		end
	end)

	it("dresses the mouth of every cave (a generator Build at each entrance)", function()
		local all = FrostpeakGen.all()
		for _, c in DATA.caves do
			local found = false
			for _, b in all do
				if b.tag == "cave" and (b.at.x - c.x) ^ 2 + (b.at.z - c.z) ^ 2 < 10 * 10 then
					found = true
				end
			end
			if not found then
				error(`no Build at the mouth of {c.cave}`)
			end
		end
	end)

	it("places gathering nodes by the areas' character (11 mithril, 11 adamantite, 26 frostleaf, 2 fishing)", function()
		local per: { [string]: number } = {}
		local nodes = FrostpeakGen.nodes()
		for i, n in nodes do
			per[n.kind] = (per[n.kind] or 0) + 1
			if n.kind ~= "fishing_frostpeak" then
				expect(T.walkable(n.x, n.z)).toBe(true)
				expect(T.roadDistance(n.x, n.z) > 3).toBe(true)
				expect(T.ice(n.x, n.z)).toBe(nil)
			end
			expect(T.crevasseDistance(n.x, n.z) > RegionTerrain.CREVASSE_CLEARANCE).toBe(true)
			for k, other in nodes do
				if k > i and (n.x - other.x) ^ 2 + (n.z - other.z) ^ 2 < 24 * 24 then
					error(`nodes {n.kind} and {other.kind} closer than 24 studs`)
				end
			end
			local theme = T.themeAt(n.x, n.z)
			if n.kind == "vein_adamantite" then
				expect(theme ~= "snowforest" and theme ~= "harpyrocks").toBe(true)
			elseif n.kind == "vein_mithril" then
				expect(theme ~= "dragontemple" and theme ~= "icefort" and theme ~= "wyrmpeak").toBe(true)
			end
		end
		expect(per.vein_mithril).toBe(11)
		expect(per.vein_adamantite).toBe(11)
		expect(per.bush_frostleaf).toBe(26)
		expect(per.fishing_frostpeak).toBe(2)
	end)

	it("puts the fishing spots on dry ice by the ice holes, with all three buoys in the water", function()
		local spots = FrostpeakGen.fishingSpots()
		expect(#spots).toBe(2)
		for _, spot in spots do
			expect(T.water(spot.x, spot.z)).toBe(nil)
			expect(T.slope(spot.x, spot.z, 2) < 0.3).toBe(true)
			for _, b in buoys(spot.x, spot.z) do
				if T.water(b[1], b[2]) == nil then
					error(`buoy of the spot at {spot.x}, {spot.z} on dry ice at {b[1]}, {b[2]}`)
				end
			end
		end
	end)

	it("gives the client life to animate and the map a sketch with ice, glaciers and ridges", function()
		local kinds: { [string]: number } = {}
		for _, l in FrostpeakGen.life() do
			kinds[l.kind] = (kinds[l.kind] or 0) + 1
		end
		for _, k in { "snowPlume", "steam", "smoke", "smokeColumn", "eagles", "avalanche", "icicleDust" } do
			if (kinds[k] or 0) == 0 then
				error(`no life of kind {k}`)
			end
		end
		local shapes: { [string]: number } = {}
		for _, s in FrostpeakGen.sketch() do
			shapes[s.c] = (shapes[s.c] or 0) + 1
		end
		for _, k in
			{ "ice", "glacier", "moraine", "crevasse", "ridge", "spire", "building", "wall", "bridge", "water", "path" }
		do
			if (shapes[k] or 0) == 0 then
				error(`no sketch shapes of kind {k}`)
			end
		end
	end)

	it("tags the effects the client animates (glow, fire, smoke, flags) and keeps blue fire blue", function()
		local tags: { [string]: number } = {}
		for _, b in FrostpeakGen.all() do
			for _, p in b.bp.pieces do
				if p.tag then
					tags[p.tag] = (tags[p.tag] or 0) + 1
				end
			end
		end
		for _, k in { "glow", "flag", "smoke", "fire" } do
			if (tags[k] or 0) == 0 then
				error(`no parts tagged {k}`)
			end
		end
	end)
end)
