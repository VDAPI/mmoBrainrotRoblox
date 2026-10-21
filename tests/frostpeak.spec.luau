--!strict
-- S47: the Frost Peaks rebuilt on the shared region engine: the areas of the brief, terrain (heights, materials,
-- determinism), real ridges instead of the old "lakes" in the pass, the frozen lakes (flat walkable ice, water in
-- the ice holes and under the ice), the frozen brook, crevasses with a way out, glacier tongues, gentle roads into
-- every area, the places a player stands on, the walk from the portal to everything, every group on safe ground,
-- the generator (budget, Builds on the ground, cave mouths, nodes by the areas' character, fishing spots, life and
-- sketch) and the mood (day and night, ambience, decoration themes, wind everywhere).
-- S108: NPC spots and quest anchors of the side arcs (with the camps and the companions' routes): places a player must
-- stand on and walk to, see the last block.

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
local Lairs = require("../src/shared/Logic/WorldGen/Lairs")
local WorldBossArena = require("../src/shared/Logic/WorldGen/WorldBossArena") -- S149b
local WorldBossData = require("../src/shared/Data/WorldBoss")
local SITES = assert(DATA.sites, "frostpeak sites")
local MAP = assert(Maps.get("frostpeak"))
local MAX_SLOPE = math.tan(math.rad(15))

-- The areas of the brief (S47 "Obszary Szczytów"): id, levels, kinds, groups, profile.
local BRIEF = {
	{ "frostpeak_valley", { 70, 75 }, { "iceWolf", "snowLeopard" }, 8, nil },
	{ "frostpeak_slopes", { 71, 80 }, { "yeti", "snowLeopard" }, 7, "exp" }, -- S94: from 71
	{ "frostpeak_harpyrocks", { 76, 83 }, { "peakHarpy", "yeti" }, 6, "loot" },
	{ "frostpeak_pass", { 78, 86 }, { "frostGiant", "peakHarpy" }, 7, nil },
	{ "frostpeak_lake", { 82, 90 }, { "iceElemental", "iceMammoth" }, 6, "loot" },
	{ "frostpeak_tundra", { 82, 89 }, { "iceMammoth", "frostGiant" }, 6, "exp" },
	{ "frostpeak_temple", { 85, 95 }, { "dragonspawn", "frozenKnight" }, 7, "gold" },
	{ "frostpeak_icewatch", { 88, 100 }, { "frozenKnight", "iceElemental" }, 5, "exp" }, -- S94: to 100
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
					-- W27 (owner decision 2026-10-20): ids from ProSoundEffects / APMOfficial, empty = not found
					expect(s.id == "" or string.match(s.id, "^rbxassetid://%d+$") ~= nil).toBe(true)
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
			-- S134i: a hideout's own nodes stand by the hideout, not by the areas' character (tests/lairs.spec)
			local inLair = Lairs.at(DATA, n.x, n.z) ~= nil
			if not inLair then
				per[n.kind] = (per[n.kind] or 0) + 1
			end
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
			if inLair then
				continue
			elseif n.kind == "vein_adamantite" then
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

-- S105 (story chapter IV and the finale): the places of Sigrun and Halgrim, the quest anchors, the Rite Circle ------------

-- S108: the routes of the side arcs' companions: Sigrun to the Leopards' Ledge, Torvi over the ice to the boat (start =
-- the NPC's place, the escort's waypoints and goal), Ragnvald from his place to the Hall of Thrones (the player leads).
local function sideRoutes(): { [string]: { { x: number, z: number } } }
	local Quests = require("../src/shared/Data/Quests")
	local spots = assert(DATA.npcSpots, "npcSpots")
	local out: { [string]: { { x: number, z: number } } } = {}
	for _, item in { { "side_fp_ledge", "trapper" }, { "side_fp_boat", "icefisher" } } do
		local quest = assert(Quests.Side.get(item[1]), item[1])
		local spot = assert(spots[item[2]], item[2])
		local route = { { x = spot.x, z = spot.z } }
		for _, objective in quest.objectives do
			if objective.type == "escort" then
				for _, v in objective.via or {} do
					table.insert(route, { x = v.x, z = v.z })
				end
				table.insert(route, { x = objective.x :: number, z = objective.z :: number })
			end
		end
		out[item[1]] = route
	end
	local skald = assert(spots.skald, "skald")
	out.side_fp_thrones = { { x = skald.x, z = skald.z }, { x = SITES.thrones.x, z = SITES.thrones.z } }
	return out
end

local function sideRoutePoints(): { { name: string, x: number, z: number } }
	local out = {}
	for id, route in sideRoutes() do
		for i, p in route do
			if i > 1 then
				table.insert(out, { name = `{id} point {i}`, x = p.x, z = p.z })
			end
		end
	end
	return out
end

describe("Frost Peaks: story places (S105)", function()
	local Kit = require("../src/shared/Logic/WorldGen/Kit")
	local Npcs = require("../src/shared/Data/Npcs")
	local Rite = require("../src/shared/Logic/FrostpeakGen/Rite")

	-- the site each NPC place and anchor belongs to (its avoid circle)
	local OWNER: { [string]: string } = {
		trapper = "trapperCamp",
		halgrim = "keep",
		climbers_camp = "climbersCamp",
		hunting_camp = "huntingCamp",
		crystal_garden = "crystals",
		temple_altars = "offeringAltars",
		temple_colossus = "sanctuary",
		wyrm_obelisk = "wyrmObelisk",
		summit_rite = "summit",
		summit_thorn = "summit",
	}
	-- the building rectangles of the map's sketch (FrostpeakGen buildingSketch): the trappers' cabin and the keep
	local RECTS = {
		{ x = SITES.trapperCamp.x, z = SITES.trapperCamp.z + 4, w = 12, d = 10, rot = SITES.trapperCamp.rot },
		{ x = SITES.keep.x + 10, z = SITES.keep.z, w = 30, d = 26, rot = 0 },
		{ x = SITES.sanctuary.x, z = SITES.sanctuary.z, w = 40, d = 30, rot = 0, floor = true },
	}

	local function circleOf(site: string): { x: number, z: number, r: number }?
		local s = SITES[site]
		for _, c in DATA.avoid do
			if c.x == s.x and c.z == s.z then
				return c
			end
		end
		return nil
	end

	local function inRectOf(x: number, z: number, r: any): boolean
		local a = math.rad(r.rot)
		local dx, dz = x - r.x, z - r.z
		local lx, lz = math.cos(a) * dx - math.sin(a) * dz, math.sin(a) * dx + math.cos(a) * dz
		return math.abs(lx) <= r.w / 2 and math.abs(lz) <= r.d / 2
	end

	local function places(): { { name: string, x: number, z: number, anchor: boolean } }
		local out = {}
		for name, spot in assert(DATA.npcSpots, "npcSpots") do
			table.insert(out, { name = name, x = spot.x, z = spot.z, anchor = false })
		end
		for _, a in assert(DATA.questAnchors, "questAnchors") do
			table.insert(out, { name = a.id, x = a.x, z = a.z, anchor = true })
		end
		return out
	end

	it("F-T1/F-T2: NPC places and anchors on firm, gentle ground inside the avoid circle of their site", function()
		-- S108: the places and anchors of the side arcs have their own block below
		local list = {}
		for _, p in places() do
			if OWNER[p.name] then
				table.insert(list, p)
			end
		end
		expect(#list).toBe(10)
		for _, p in list do
			local tag = `{p.name} at {math.floor(p.x)}, {math.floor(p.z)}`
			local circle = assert(circleOf(assert(OWNER[p.name], p.name)), p.name)
			local d = math.sqrt((p.x - circle.x) ^ 2 + (p.z - circle.z) ^ 2)
			expect(`{tag} inside {d <= circle.r - 2}`).toBe(`{tag} inside true`)
			-- the crystal garden grows out of the Frozen Lake's walkable ice
			if p.name ~= "crystal_garden" then
				expect(`{tag} ice {T.ice(p.x, p.z) == nil}`).toBe(`{tag} ice true`)
			end
			expect(T.isWater(p.x, p.z)).toBe(false)
			expect(T.crevasseDistance(p.x, p.z) > 10).toBe(true)
			expect(T.glacierAt(p.x, p.z)).toBe(false)
			expect(T.mountainAt(p.x, p.z)).toBe(false)
			expect(`{tag} slope {slopeAround(p.x, p.z, 6) < MAX_SLOPE}`).toBe(`{tag} slope true`)
			local road = AreaSpawns.nearRoad(DATA.roads, p.x, p.z, if p.anchor then 4 else 6)
			expect(`{tag} road {road}`).toBe(`{tag} road false`)
			for _, r in RECTS do
				if not r.floor then
					expect(`{tag} building {inRectOf(p.x, p.z, r)}`).toBe(`{tag} building false`)
				end
			end
		end
		for i, a in list do
			for k, b in list do
				if k > i then
					local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
					local least = if a.anchor and b.anchor then 4 else 5
					expect(`{a.name}/{b.name} {d >= least}`).toBe(`{a.name}/{b.name} true`)
				end
			end
		end
		-- no new avoid circle (the Rite Circle lies inside the summit's), the groups and nodes of S47 stay
		expect(#DATA.avoid).toBe(38)
		for _, spot in DATA.npcSpots :: any do
			expect(spot.wiki).toBeNil() -- S109: published on the wiki
		end
		for _, a in DATA.questAnchors :: any do
			expect(a.wiki).toBeNil() -- S109: published on the wiki
		end
	end)

	it("F-T1: Sigrun and Halgrim stand exactly on their places; the places are named apart from every site", function()
		local spots = assert(DATA.npcSpots, "npcSpots")
		for id, spotId in { trapper_sigrun = "trapper", ghost_halgrim = "halgrim" } do
			local npc = assert(Npcs.get(id), id)
			local spot = assert(spots[spotId], spotId)
			expect(npc.map).toBe("frostpeak")
			expect(npc.position.x).toBe(spot.x)
			expect(npc.position.z).toBe(spot.z)
			expect(npc.facing).toBe(spot.facing)
		end
		for name in spots do
			for _, data in Areas.byMap do
				expect(`{name} {(data.sites or {} :: any)[name] == nil}`).toBe(`{name} true`)
			end
		end
		-- Halgrim keeps 8+ studs from the frozen weapon racks of the courtyard (keep-local x -26..-14, z -26)
		local keep = SITES.keep
		for m = 0, 2 do
			local rx, rz = Kit.toWorld(keep.x + 10, keep.z, keep.rot, -26 + m * 6, -26)
			expect(math.sqrt((spots.halgrim.x - rx) ^ 2 + (spots.halgrim.z - rz) ^ 2) >= 8).toBe(true)
		end
	end)

	it(
		"F-T3: every NPC place, anchor and the Rite Circle can be walked to from the Ashen portal (the Ice Watch's walls in the way)",
		function()
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
			-- the Ice Watch's walls, towers, gatehouse and keep stop the walk (their collidable pieces up to head height,
			-- footprints grown by STEP / 4 so a 4-stud wall always covers a row of cells): Halgrim's courtyard is reached
			-- only through the gate, whose icicles and frozen sentries have no collision (Fortress.gate)
			local gatePieces = 0
			for _, b in FrostpeakGen.all() do
				local name = b.name
				local fort = name == "icewatchGate"
					or name == "keep"
					or string.sub(name, 1, 13) == "IceWatchWall_"
					or string.sub(name, 1, 14) == "IceWatchTower_"
				if not fort then
					continue
				end
				for _, piece in b.bp.pieces do
					local r, s, p = piece.r, piece.size, piece.p
					if name == "icewatchGate" and math.abs(p[1]) < 6 and p[2] < 12 then
						gatePieces += 1
						expect(`gate piece col {piece.col}`).toBe("gate piece col false")
					end
					local ex = (math.abs(r[1]) * s[1] + math.abs(r[2]) * s[2] + math.abs(r[3]) * s[3]) / 2
					local ey = (math.abs(r[4]) * s[1] + math.abs(r[5]) * s[2] + math.abs(r[6]) * s[3]) / 2
					local ez = (math.abs(r[7]) * s[1] + math.abs(r[8]) * s[2] + math.abs(r[9]) * s[3]) / 2
					if piece.col and p[2] - ey < 7 then
						local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
						for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
							local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, p[1] + c[1] * ex, p[3] + c[2] * ez)
							x0, z0, x1, z1 = math.min(x0, wx), math.min(z0, wz), math.max(x1, wx), math.max(z1, wz)
						end
						local grow = STEP / 4
						for i = math.ceil((x0 - grow + 780) / STEP), math.floor((x1 + grow + 780) / STEP) do
							for k = math.ceil((z0 - grow + 780) / STEP), math.floor((z1 + grow + 780) / STEP) do
								if i >= 0 and i <= N and k >= 0 and k <= N then
									blocked[idx(i, k)] = true
								end
							end
						end
					end
				end
			end
			-- the icicles barring the gate (11) and nothing collidable under the arch
			expect(gatePieces >= 11).toBe(true)
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
			local targets = places()
			table.insert(
				targets,
				{ name = "site summitRite", x = SITES.summitRite.x, z = SITES.summitRite.z, anchor = false }
			)
			-- the companions' starts of the chapter (Data/Quests/Main: frozenHold, dragonsBrood, voiceOfWinter)
			for _, p in { { 277, -336 }, { 300, -556 }, { 532, -528 } } do
				table.insert(targets, { name = `companion {p[1]}, {p[2]}`, x = p[1], z = p[2], anchor = false })
			end
			-- S108: the waypoints and goals of the side arcs' companions (Sigrun, Torvi; Ragnvald's goal is a site);
			-- places() already holds every NPC place and anchor of the side arcs
			for _, p in sideRoutePoints() do
				table.insert(targets, { name = p.name, x = p.x, z = p.z, anchor = false })
			end
			for _, t in targets do
				if not reached(t.x, t.z) then
					error(`{t.name} at {math.floor(t.x)}, {math.floor(t.z)} cannot be reached on foot`)
				end
			end
		end
	)

	it("F-T4: the monster groups and the gathering nodes of S47 are unchanged (57 groups, 50 nodes)", function()
		-- before S105 (build/s105_before.json): 57 groups, 50 nodes; the sums of their coordinates
		-- S149b: the one adamantite vein that grew in the world boss's barrow grows outside it now (-4923, 738 before)
		-- (studio review 2026-10-21: one fishing spot moved 4 studs west and 2 south, Logic/FishingSpots: -4773 / 814)
		local NODE_SUM_X, NODE_SUM_Z, GROUP_SUM_X, GROUP_SUM_Z = -4777, 816, 2719, 169
		local groups = AreaSpawns.region(DATA, MAP.size)
		expect(#groups).toBe(57)
		-- S134i: without the Elite II hideouts' own nodes (every other node unchanged)
		local nodes = {}
		for _, n in FrostpeakGen.nodes() do
			if Lairs.at(DATA, n.x, n.z) == nil then
				table.insert(nodes, n)
			end
		end
		expect(#nodes).toBe(50)
		local sx, sz = 0, 0
		for _, n in nodes do
			sx += n.x
			sz += n.z
		end
		local gx, gz = 0, 0
		for _, g in groups do
			gx += g.position.x
			gz += g.position.z
		end
		expect(math.floor(sx + 0.5)).toBe(NODE_SUM_X)
		expect(math.floor(sz + 0.5)).toBe(NODE_SUM_Z)
		expect(math.floor(gx + 0.5)).toBe(GROUP_SUM_X)
		expect(math.floor(gz + 0.5)).toBe(GROUP_SUM_Z)
	end)

	it(
		"F-T5: the Rite Circle stands on the ground with the Heart of Winter beating; the anchors face its altar",
		function()
			local found = false
			for _, b in FrostpeakGen.all() do
				if b.name == "summitRite" then
					found = true
					expect(math.abs(b.at.y - T.height(b.at.x, b.at.z)) <= 6).toBe(true)
					local heart, shell = 0, 0
					for _, piece in b.bp.pieces do
						if piece.tag == "heart" then
							heart += 1
						end
						if piece.lod == "shell" then
							shell += 1
						end
					end
					expect(heart >= 1).toBe(true)
					expect(shell <= 14).toBe(true)
				end
			end
			expect(found).toBe(true)
			-- the circle's middle is 9 / 4 studs behind summit_rite / summit_thorn (QuestAnchorController `rite`, `thorn`)
			local anchors: { [string]: any } = {}
			for _, a in assert(DATA.questAnchors, "questAnchors") do
				anchors[a.id] = a
			end
			local site = SITES.summitRite
			for id, back in { summit_rite = 9, summit_thorn = 4 } do
				local a = anchors[id]
				local cx, cz = Kit.toWorld(a.x, a.z, a.rot, 0, back)
				expect(math.abs(cx - site.x) < 0.01 and math.abs(cz - site.z) < 0.01).toBe(true)
			end
			-- the anchors stay off the monoliths and the altar (Logic/FrostpeakGen/Rite)
			for _, id in { "summit_rite", "summit_thorn" } do
				local a = anchors[id]
				for _, st in Rite.stones() do
					local sx, sz = Kit.toWorld(site.x, site.z, site.rot, st.x, st.z)
					expect(math.sqrt((a.x - sx) ^ 2 + (a.z - sz) ^ 2) > 3).toBe(true)
				end
				expect(math.sqrt((a.x - site.x) ^ 2 + (a.z - site.z) ^ 2) > Rite.ALTAR.d / 2 + 1).toBe(true)
			end
		end
	)

	it("keeps the cave anchors on the floor of their rooms in the Frozen Hold", function()
		local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
		local cave = assert(Areas.caves.get("frostpeak_hold"))
		local terrain = assert(CaveTerrain.get("frostpeak_hold"))
		local rooms = { frost_bloom = 3, hold_chapel = 4 }
		local anchors = assert(cave.questAnchors, "questAnchors")
		expect(#anchors).toBe(2)
		for _, a in anchors do
			expect(a.wiki).toBeNil() -- S109: published on the wiki
			expect(terrain.floor(a.x, a.z) ~= nil).toBe(true)
			expect(terrain.liquid(a.x, a.z)).toBeNil()
			expect(terrain.headroom(a.x, a.z) >= 8).toBe(true)
			expect(terrain.roomAt(a.x, a.z)).toBe(rooms[a.id])
			local _, mapId = Areas.anchorById(a.id)
			expect(mapId).toBe("frostpeak_hold")
		end
		-- the chapel's altar (130 / -78, a 6 x 3 block) stays clear of the anchor
		local chapel = anchors[2]
		expect(chapel.id).toBe("hold_chapel")
		expect(math.abs(chapel.z - -78) - 1.5 >= 4).toBe(true)
	end)
end)

-- S108: the side arcs of the Peaks: seven NPC places with their camps, 25 fp_* anchors and three companions' routes,
-- all without a new avoid circle (the groups and the gathering nodes of S47 stay; F-T4 of S105 checks their sums) ------

local S108_SPOTS = {
	cairn = "cairn_ingrid",
	horn = "hornblower_eskil",
	skald = "skald_ragnvald",
	icefisher = "icefisher_torvi",
	bonecarver = "bonecarver_gunnar",
	squire = "squire_asmund",
	scholar = "scholar_vigdis",
}
-- anchors on the walkable ice of the Frozen Lake (the boat and the hoard); no other anchor stands on ice
local ON_LAKE_ICE = { fp_frozen_boat = true, fp_hoard_1 = true, fp_hoard_2 = true, fp_hoard_3 = true }
-- anchors of one objective (8+ studs apart so their prompts never overlap)
local SAME_OBJECTIVE = {
	{ "fp_snare_1", "fp_snare_2", "fp_snare_3" },
	{ "fp_boulders_1", "fp_boulders_2", "fp_boulders_3" },
	{ "fp_colossus_north", "fp_colossus_south" },
	{ "fp_hoard_1", "fp_hoard_2", "fp_hoard_3" },
	{ "fp_watch_shield_1", "fp_watch_shield_2", "fp_watch_shield_3" },
	{ "fp_brood_1", "fp_brood_2", "fp_brood_3" },
}

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- The avoid circle a point lies in (2 studs inside its edge), nil: none.
local function avoidOf(x: number, z: number): { x: number, z: number, r: number }?
	for _, c in DATA.avoid do
		if dist(x, z, c.x, c.z) <= c.r - 2 then
			return c
		end
	end
	return nil
end

-- F-T4: the name of a Build whose solid piece (shell or colliding; trees aside) a player standing at (x, z) would
-- touch within `margin` studs: its rotated box at 0.5-3.5 studs over the ground (a horizontal-only check would forbid
-- the ground under the gatehouse's arch, which nobody touches), nil: none.
local function touchesSolid(x: number, z: number, margin: number): string?
	for _, b in FrostpeakGen.all() do
		if b.tag ~= "trees" and (b.at.x - x) ^ 2 + (b.at.z - z) ^ 2 < 150 * 150 then
			local r = math.rad(b.at.rot)
			local c, s = math.cos(r), math.sin(r)
			local dx, dz = x - b.at.x, z - b.at.z
			local lx, lz = c * dx - s * dz, s * dx + c * dz
			local g = T.height(x, z) - b.at.y
			for _, p in b.bp.pieces do
				if p.lod == "shell" or p.col then
					for _, h in { 0.5, 2, 3.5 } do
						local vx, vy, vz = lx - p.p[1], g + h - p.p[2], lz - p.p[3]
						local R = p.r
						local ux = R[1] * vx + R[4] * vy + R[7] * vz
						local uy = R[2] * vx + R[5] * vy + R[8] * vz
						local uz = R[3] * vx + R[6] * vy + R[9] * vz
						if
							math.abs(ux) < p.size[1] / 2 + margin
							and math.abs(uy) < p.size[2] / 2 + 0.5
							and math.abs(uz) < p.size[3] / 2 + margin
						then
							return b.name
						end
					end
				end
			end
		end
	end
	return nil
end

local function sideAnchors(): { any }
	local out = {}
	for _, a in assert(DATA.questAnchors, "questAnchors") do
		if string.sub(a.id, 1, 3) == "fp_" then
			table.insert(out, a)
		end
	end
	return out
end

local function groundProblem(x: number, z: number, r: number): string?
	if T.isWater(x, z) then
		return "water"
	elseif T.crevasseDistance(x, z) <= 10 then
		return "crevasse"
	elseif T.glacierAt(x, z) then
		return "glacier"
	elseif T.mountainAt(x, z) then
		return "mountain"
	elseif slopeAround(x, z, r) >= MAX_SLOPE then
		return `slope {math.floor(math.deg(math.atan(slopeAround(x, z, r))))}`
	end
	return nil
end

describe("Frost Peaks: side quest places (S108)", function()
	local SideCamps = require("../src/shared/Logic/FrostpeakGen/SideCamps")
	local Npcs = require("../src/shared/Data/Npcs")
	local Config = require("../src/shared/Config")

	it(
		"F-T1/F-T2: the seven NPC places stand on firm ground inside an avoid circle, off the roads, 5+ apart",
		function()
			local spots = assert(DATA.npcSpots, "npcSpots")
			for key, npcId in S108_SPOTS do
				local spot = assert(spots[key], key)
				local tag = `{key} at {spot.x}, {spot.z}`
				expect(`{tag} {groundProblem(spot.x, spot.z, 6)}`).toBe(`{tag} nil`)
				expect(`{tag} ice {T.ice(spot.x, spot.z) == nil}`).toBe(`{tag} ice true`)
				expect(`{tag} avoid {avoidOf(spot.x, spot.z) ~= nil}`).toBe(`{tag} avoid true`)
				expect(`{tag} road {AreaSpawns.nearRoad(DATA.roads, spot.x, spot.z, 6)}`).toBe(`{tag} road false`)
				expect(spot.facing >= 0 and spot.facing <= 359).toBe(true)
				expect(spot.wiki).toBeNil() -- S109: published on the wiki
				for other, o in spots do
					if other ~= key then
						expect(`{key}/{other} {dist(spot.x, spot.z, o.x, o.z) >= 5}`).toBe(`{key}/{other} true`)
					end
				end
				for _, a in assert(DATA.questAnchors, "questAnchors") do
					expect(`{key}/{a.id} {dist(spot.x, spot.z, a.x, a.z) >= 5}`).toBe(`{key}/{a.id} true`)
				end
				local npc = assert(Npcs.get(npcId), npcId)
				expect(npc.position.x).toBe(spot.x)
				expect(npc.position.z).toBe(spot.z)
				expect(npc.facing).toBe(spot.facing)
			end
		end
	)

	it("F-T1/F-T3: the 25 fp_* anchors: firm ground, in an avoid circle or 12+ studs from every group", function()
		local anchors = sideAnchors()
		expect(#anchors).toBe(25)
		local groups = AreaSpawns.region(DATA, MAP.size)
		for _, a in anchors do
			local tag = `{a.id} at {a.x}, {a.z}`
			expect(`{tag} {groundProblem(a.x, a.z, 3)}`).toBe(`{tag} nil`)
			if T.ice(a.x, a.z) ~= nil then
				-- the lake's ice only, never the frozen brook's
				expect(`{tag} lake ice {ON_LAKE_ICE[a.id] == true and T.streamDistance(a.x, a.z) > 30}`).toBe(
					`{tag} lake ice true`
				)
			end
			if not avoidOf(a.x, a.z) then
				for _, g in groups do
					local d = dist(a.x, a.z, g.position.x, g.position.z)
					expect(`{tag} group {g.id} {d >= 12}`).toBe(`{tag} group {g.id} true`)
				end
			end
			for _, lake in DATA.lakes do
				expect(`{tag} hole {dist(a.x, a.z, lake.x, lake.z) >= lake.r + 4}`).toBe(`{tag} hole true`)
			end
			local found, mapId = Areas.anchorById(a.id)
			expect(found).toBe(a)
			expect(mapId).toBe("frostpeak")
			expect(a.wiki).toBeNil() -- S109: published on the wiki
			-- 6+ studs from the story's anchors of S105, 4+ from every other anchor
			for _, other in assert(DATA.questAnchors, "questAnchors") do
				if other ~= a then
					local d = dist(a.x, a.z, other.x, other.z)
					local least = if string.sub(other.id, 1, 3) == "fp_" then 4 else 6
					expect(`{a.id}/{other.id} {d >= least}`).toBe(`{a.id}/{other.id} true`)
				end
			end
		end
		for _, group in SAME_OBJECTIVE do
			for i, id in group do
				for k = i + 1, #group do
					local a, b = assert(Areas.anchorById(id)), assert(Areas.anchorById(group[k]))
					expect(`{id}/{group[k]} {dist(a.x, a.z, b.x, b.z) >= 8}`).toBe(`{id}/{group[k]} true`)
				end
			end
		end
		-- no new avoid circle: the 38 of S105
		expect(#DATA.avoid).toBe(38)
	end)

	it("F-T4: NPC places and anchors keep out of the solid parts of every generator Build (the camps too)", function()
		local spots = assert(DATA.npcSpots, "npcSpots")
		for key in S108_SPOTS do
			local spot = spots[key]
			expect(`{key} {touchesSolid(spot.x, spot.z, 2)}`).toBe(`{key} nil`)
		end
		for _, a in sideAnchors() do
			expect(`{a.id} {touchesSolid(a.x, a.z, 1)}`).toBe(`{a.id} nil`)
		end
	end)

	it(
		"C3: a camp behind each new NPC, on the ground, few parts and one light, its clearing in the avoid circle + 6",
		function()
			local spots = assert(DATA.npcSpots, "npcSpots")
			local camps: { [string]: any } = {}
			local others = 0
			local rocks: { any } = {}
			for _, b in FrostpeakGen.all() do
				local key = string.match(b.name, "^SideCamp_(.+)$")
				if key then
					camps[key] = b
				elseif string.match(b.name, "^Detail_") then
					continue -- W20: the map plan's secrets (FrostpeakGen/Details), after everything
				elseif b.tag ~= "lair" and b.tag ~= "worldBossArena" then -- S134i: the Elite II hideouts; S149b the barrow
					others += 1
				end
				if b.tag == "rocks" then
					table.insert(rocks, b)
				end
			end
			-- the Builds before S108 (build/s108_before.json: 365, names, places and parts unchanged)
			-- S149b: two rocks stood in the world boss's barrow (Rocks_dragontemple_4, Rocks_icefort_5): 365 before
			expect(others).toBe(363)
			expect(#SideCamps.keys()).toBe(7)
			for _, key in SideCamps.keys() do
				expect(S108_SPOTS[key] ~= nil).toBe(true)
				local b = assert(camps[key], key)
				local spot = spots[key]
				local x, z = SideCamps.at(spot)
				expect(b.at.x).toBe(x)
				expect(b.at.z).toBe(z)
				expect(b.at.rot).toBe(spot.facing)
				expect(b.tag).toBe("camp")
				expect(dist(x, z, spot.x, spot.z) >= 3 and dist(x, z, spot.x, spot.z) <= 6).toBe(true)
				expect(math.abs(b.at.y - T.height(x, z)) <= 1).toBe(true)
				expect(#b.bp.pieces <= 30).toBe(true)
				expect(#b.bp.lights <= 1).toBe(true)
				local inside = false
				for _, c in DATA.avoid do
					inside = inside or dist(x, z, c.x, c.z) + SideCamps.CLEAR <= c.r + 6
				end
				expect(`{key} clearing {inside}`).toBe(`{key} clearing true`)
				for _, t in FrostpeakGen.trees() do
					expect(`{key} tree {dist(x, z, t.x, t.z) >= SideCamps.CLEAR}`).toBe(`{key} tree true`)
				end
				for _, r in rocks do
					expect(`{key} rock {dist(x, z, r.at.x, r.at.z) >= SideCamps.CLEAR + 2}`).toBe(`{key} rock true`)
				end
				for _, node in FrostpeakGen.nodes() do
					expect(dist(x, z, node.x, node.z) >= SideCamps.CLEAR + 4).toBe(true)
				end
			end
		end
	)

	it("F-T6: the companions' routes run on firm ground, legs <= legMax, never over a hole or a crevasse", function()
		for id, route in sideRoutes() do
			expect(#route >= 2).toBe(true)
			for i, p in route do
				local tag = `{id} {i} at {p.x}, {p.z}`
				expect(`{tag} {MapTerrain.walkable("frostpeak", p.x, p.z, 4)}`).toBe(`{tag} true`)
				expect(`{tag} {groundProblem(p.x, p.z, 3)}`).toBe(`{tag} nil`)
				-- the lake's ice only on Torvi's way to the boat
				if T.ice(p.x, p.z) ~= nil then
					expect(`{tag} ice {id == "side_fp_boat"}`).toBe(`{tag} ice true`)
				end
				if i > 1 then
					local a = route[i - 1]
					local leg = dist(a.x, a.z, p.x, p.z)
					expect(`{tag} leg {leg <= Config.Companion.legMax}`).toBe(`{tag} leg true`)
					local n = math.max(1, math.floor(leg / 4))
					for k = 0, n do
						local x, z = a.x + (p.x - a.x) * k / n, a.z + (p.z - a.z) * k / n
						for _, lake in DATA.lakes do
							expect(`{tag} hole {dist(x, z, lake.x, lake.z) >= lake.r + 4}`).toBe(`{tag} hole true`)
						end
						expect(`{tag} mountain {T.mountainAt(x, z)}`).toBe(`{tag} mountain false`)
						expect(`{tag} crevasse {T.crevasseDistance(x, z) > 4}`).toBe(`{tag} crevasse true`)
					end
				end
			end
		end
		-- Torvi keeps 30+ studs from the ice hole by the boat; Sigrun's goal is the Leopards' Ledge
		for _, p in sideRoutes().side_fp_boat do
			expect(dist(p.x, p.z, DATA.lakes[1].x, DATA.lakes[1].z) >= 30).toBe(true)
		end
		local ledge = sideRoutes().side_fp_ledge
		local goal = ledge[#ledge]
		expect(dist(goal.x, goal.z, SITES.leopardLedge.x, SITES.leopardLedge.z) <= 14).toBe(true)
	end)
end)

describe("Frost Peaks: the world boss's barrow (S149b)", function()
	local spot = WorldBossData.spots[1]

	it("stands on the spot: rune stones and banners on the rim, the middle free of collision and tall props", function()
		local arena: any = nil
		for _, b in FrostpeakGen.all() do
			if b.tag == WorldBossArena.TAG then
				expect(arena).toBe(nil)
				arena = b
			end
		end
		assert(arena, "no world boss arena")
		expect({ arena.at.x, arena.at.z }).toEqual({ spot.x, spot.z })
		local free = spot.r - spot.free
		local shell = 0
		for _, piece in arena.bp.pieces do
			local x, z = piece.p[1], piece.p[3]
			local d = math.sqrt(x * x + z * z)
			if piece.lod == "shell" then
				shell += 1
			end
			if piece.col or piece.lod == "shell" then
				-- the footprint's half diagonal inside the rim
				local half = math.sqrt(piece.size[1] ^ 2 + piece.size[3] ^ 2) / 2
				if d - half < free then
					error(`a solid piece {d - half} studs from the centre (free {free})`)
				end
			elseif d < free then
				-- the floor slabs and runes only: flat at the ground (0.3 high or a lying disc)
				local flat = piece.size[2] <= 0.35 or (piece.s == "cyl" and piece.size[1] <= 0.35)
				if not flat then
					error(`a tall prop {d} studs from the centre`)
				end
			end
		end
		expect(shell >= WorldBossArena.STONES + 2).toBe(true)
	end)

	it("keeps rocks, gathering nodes and trees out of the circle", function()
		for _, b in FrostpeakGen.all() do
			if b.tag == "rocks" and (b.at.x - spot.x) ^ 2 + (b.at.z - spot.z) ^ 2 < (spot.r + 4) ^ 2 then
				error(`{b.name} in the world boss's arena`)
			end
		end
		for _, n in FrostpeakGen.nodes() do
			if (n.x - spot.x) ^ 2 + (n.z - spot.z) ^ 2 < (spot.r + 6) ^ 2 then
				error(`node {n.kind} in the world boss's arena`)
			end
		end
		for _, t in FrostpeakGen.trees() do
			if (t.x - spot.x) ^ 2 + (t.z - spot.z) ^ 2 < spot.r ^ 2 then
				error(`tree in the world boss's arena`)
			end
		end
		-- the faint choir over the barrow (Data/Ambience)
		local found = false
		for _, p in Ambience.points.frostpeak do
			if p.x == spot.x and p.z == spot.z then
				found = true
			end
		end
		expect(found).toBe(true)
	end)
end)
