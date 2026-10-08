--!strict
-- S46: the Ashen Wastes rebuilt on the shared region engine: the areas of the brief, terrain (heights, materials,
-- determinism, the frozen fixture), lava (continuous rivers falling downstream, never water, nobody stands near it, a
-- bridge at every road crossing), gentle roads into every area, the places a player stands on, every group on safe
-- ground outside the buildings, dunes with valleys, mesa and spire walls, the dry oasis, the generator (budget, Builds
-- on the ground, unique sites, nodes by the areas' character, fishing spots, cave mouths, life and sketch) and the
-- mood (day and night, ambience, decoration themes).

local Ambience = require("../src/shared/Data/Ambience")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local AshenGen = require("../src/shared/Logic/AshenGen")
local Fixture = require("./fixtures/ashenHeights")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local Maps = require("../src/shared/Data/Maps")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local Portals = require("../src/shared/Data/Portals")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local Shapes = require("../src/shared/Data/Terrain")
local TerrainLayers = require("../src/shared/Logic/TerrainLayers")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local T = assert(RegionTerrain.get("ashen"), "ashen terrain")
local SHAPE = Shapes.byMap.ashen
local DATA = Areas.byMap.ashen
local SITES = assert(DATA.sites, "ashen sites")
local MAP = assert(Maps.get("ashen"))
local MAX_SLOPE = math.tan(math.rad(15))
local CLEAR = RegionTerrain.LAVA_CLEARANCE

-- The areas of the brief (S46 "Obszary"): id, levels, kinds, groups, profile.
local BRIEF = {
	{ "ashen_flats", { 45, 50 }, { "salamander", "wasteHyena" }, 8, "exp" },
	{ "ashen_oasis", { 46, 52 }, { "wasteHyena", "ashVulture" }, 6, "loot" },
	{ "ashen_warcamp", { 48, 56 }, { "ashOrc", "ashVulture" }, 7, nil },
	{ "ashen_golemfields", { 52, 60 }, { "fireGolem", "fireImp" }, 7, nil },
	{ "ashen_burntruins", { 55, 61 }, { "fireImp", "desertScorpion" }, 6, "exp" },
	{ "ashen_dunes", { 55, 63 }, { "desertScorpion", "desertMummy" }, 7, "gold" },
	{ "ashen_crags", { 58, 66 }, { "wyvern", "basilisk" }, 6, "exp" },
	{ "ashen_ashroad", { 61, 67 }, { "basilisk", "wyvern" }, 4, "gold" },
	{ "ashen_tombs", { 66, 70 }, { "desertMummy", "basilisk" }, 5, nil },
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

-- Places a player must be able to stand on: portals, the landing from the Frost Peaks, the arrivals in front of the
-- cave mouths, respawn points, the scout, the areas' arrivals.
local function standingPlaces(): { { name: string, x: number, z: number } }
	local list = {}
	for _, p in Portals.onMap("ashen") do
		-- cave portals stand in the mouths at the walls' feet; players arrive in front of them (below)
		if p.kind == "portal" then
			table.insert(list, { name = `portal {p.id}`, x = p.x, z = p.z })
		end
	end
	table.insert(list, { name = "landing from the Frost Peaks", x = 690, z = -690 })
	for _, c in DATA.caves do
		local a = math.rad(c.rot)
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

describe("Ashen Wastes: data", function()
	it("keeps the areas of the brief (ids, levels, kinds, groups, profiles; 56 groups) without overlaps", function()
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
		expect(total).toBe(56)
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
			{ "ashen_mine", -560, -745, 180 },
			{ "ashen_lair", 420, -745, 180 },
			{ "ashen_cave", 745, 0, 90 },
		}
		for i, c in caves do
			local e = DATA.caves[i]
			expect(e.cave).toBe(c[1])
			expect(e.x).toBe(c[2])
			expect(e.z).toBe(c[3])
			expect(e.rot).toBe(c[4])
		end
		local portals: { [string]: { number } } =
			{ ashen_duskwood = { -770, 0 }, ashen_city = { -770, 160 }, ashen_frostpeak = { 740, -740 } }
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
			local mood = assert(Ambience.moodOf("ashen", a.id), `{a.id} mood`)
			expect(#mood.sounds.day > 0 and #mood.sounds.night > 0).toBe(true)
			for _, list in { mood.sounds.day, mood.sounds.night } do
				for _, s in list do
					expect(s.id).toBe("")
					expect(#s.hint > 10).toBe(true)
				end
			end
		end
		expect(Ambience.moodOf("ashen", nil) ~= nil).toBe(true)
		for _, p in Ambience.points.ashen do
			expect(math.abs(p.x) <= 800 and math.abs(p.z) <= 800).toBe(true)
		end
	end)

	it("has day and night, a night of its own, a background build and a part budget", function()
		expect(MAP.dayNight).toBe(true)
		expect(MAP.nightLighting ~= nil and MAP.nightLighting ~= MAP.lighting).toBe(true)
		expect(MAP.buildLate).toBe(true)
		expect(MAP.maxParts).toBe(2400)
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
		for _, name in { "ribcage", "strandedBoat", "bloodPit", "colossus", "belltower", "buriedKing", "pyramid" } do
			expect(seen[name]).toBe("ashen")
		end
	end)
end)

describe("Ashen Wastes: terrain", function()
	it("has a finite height everywhere, inside the writer's range", function()
		for x = -860, 860, 20 do
			for z = -860, 860, 20 do
				local h = T.height(x, z)
				expect(h == h and h > SHAPE.writer.bottom + 2 and h < SHAPE.writer.top - 2).toBe(true)
			end
		end
	end)

	it("paints only terrain materials; its own colours (Asphalt, Concrete) appear on no other map", function()
		local seen: { [string]: boolean } = {}
		for x = -780, 780, 20 do
			for z = -780, 780, 20 do
				local m = T.material(x, z)
				seen[m] = true
				expect(RegionTerrain.MATERIAL_SET[m]).toBe(true)
				expect(m ~= "Water" or T.isWater(x, z)).toBe(true)
			end
		end
		for _, m in { "Asphalt", "Basalt", "CrackedLava", "Sandstone", "Sand", "Concrete", "Ground" } do
			if not seen[m] then
				error(`no {m} on the Ashen Wastes`)
			end
		end
		for _, m in MeadowsTerrain.MATERIALS do
			expect(m ~= "Asphalt" and m ~= "Concrete").toBe(true)
		end
		local D = assert(RegionTerrain.get("duskwood"))
		for x = -780, 780, 40 do
			for z = -780, 780, 40 do
				local m = D.material(x, z)
				expect(m ~= "Asphalt" and m ~= "Concrete").toBe(true)
			end
		end
	end)

	it("is deterministic", function()
		local other = RegionTerrain.new(SHAPE, DATA)
		for _, p in { { 0, 0 }, { 130, 100 }, { -590, -190 }, { 560, 560 }, { 660, -350 }, { -540, 615 } } do
			expect(other.height(p[1], p[2])).toBe(T.height(p[1], p[2]))
			expect(other.material(p[1], p[2])).toBe(T.material(p[1], p[2]))
		end
	end)

	it("matches the frozen heights of S46 (S47 extends the engine without changing the Wastes)", function()
		for _, p in Fixture.points do
			local h = T.height(p[1], p[2])
			if math.abs(h - p[3]) > 0.01 then
				error(`height at {p[1]}, {p[2]}: {h}, fixture {p[3]}`)
			end
			expect(T.water(p[1], p[2]) ~= nil).toBe(p[4] ~= false)
			expect(T.material(p[1], p[2])).toBe(p[5])
		end
	end)

	it("runs every lava river continuously, its surface never rising downstream, never water", function()
		for i, river in assert(SHAPE.lava, "lava").rivers do
			local line = T.lavaLine(i)
			local last = math.huge
			local s = 0
			while s <= line.length do
				local level = T.lavaLevel(i, s)
				expect(level <= last + 1e-6).toBe(true)
				last = level
				local x, z = TerrainLayers.pointAt(line, s)
				if not T.lava(x, z) then
					error(`river {river.id}: no lava at {math.floor(x)}, {math.floor(z)}`)
				end
				expect(T.isWater(x, z)).toBe(false)
				s += 6
			end
		end
		for _, p in assert(SHAPE.lava, "lava").pools do
			expect(T.lava(p.x - p.rx * 0.3, p.z) ~= nil).toBe(true)
			expect(T.isWater(p.x, p.z)).toBe(false)
		end
		-- the Fire Vein falls from the crater's lake to the cooling lakes
		expect(T.lavaLevel(1, 0) - T.lavaLevel(1, T.lavaLine(1).length) > 8).toBe(true)
	end)

	it("puts a stone bridge wherever a road crosses lava, and nowhere else is a road on lava", function()
		local lavaCrossings = 0
		for _, c in T.crossings() do
			if c.lava then
				lavaCrossings += 1
				expect(c.kind).toBe("stone")
				expect(c.deck - c.water >= 1.5).toBe(true)
			end
		end
		expect(lavaCrossings >= 1).toBe(true)
		for ri, road in DATA.roads do
			local line = T.roadLine(ri)
			local s = 0
			while s <= line.length do
				local x, z, dx, dz = TerrainLayers.pointAt(line, s)
				if not nearCrossing(x, z, 2) then
					for _, side in { -1, 0, 1 } do
						local off = side * road.width / 2
						local px, pz = x - dz * off, z + dx * off
						if T.lavaDistance(px, pz) < 0 then
							error(`road {ri} on lava at {math.floor(px)}, {math.floor(pz)}`)
						end
					end
				end
				s += 4
			end
		end
	end)

	it("keeps the roads gentle (< 15 degrees off the bridges) and off the spires and mesas", function()
		local worst, at = 0, ""
		for ri, road in DATA.roads do
			local line = T.roadLine(ri)
			local s = 0
			while s <= line.length do
				local x, z, dx, dz = TerrainLayers.pointAt(line, s)
				if not nearCrossing(x, z, 4) and math.abs(x) < 790 and math.abs(z) < 790 then
					expect(T.rockAt(x, z)).toBe(false)
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
		"gives portals, cave exits, the landing, respawns, the scout and arrivals dry, gentle ground away from lava",
		function()
			for _, p in standingPlaces() do
				local slope = slopeAround(p.x, p.z, 10)
				if slope >= MAX_SLOPE or T.isWater(p.x, p.z) or T.lavaDistance(p.x, p.z) < CLEAR then
					error(
						`{p.name} at {math.floor(p.x)}, {math.floor(p.z)}: slope {math.deg(math.atan(slope))} deg, lava {T.lavaDistance(
							p.x,
							p.z
						)}`
					)
				end
			end
		end
	)

	it("puts no group, standing place or node near lava (walkable = false there, with the 10-stud ring)", function()
		for _, p in assert(SHAPE.lava, "lava").pools do
			expect(MapTerrain.walkable("ashen", p.x + p.rx + 8, p.z, 10)).toBe(false)
			expect(T.walkable(p.x + p.rx + 8, p.z)).toBe(false)
		end
		local glow = assert(SHAPE.cracks, "cracks")[1].points
		expect(T.walkable(glow[3], glow[4] + 8)).toBe(false)
	end)

	it("lets dunes keep their valleys (40%+ of the field walkable), with crests", function()
		local d = assert(SHAPE.dunes, "dunes")[1]
		local n, w, top = 0, 0, 0
		for x = d.rect[1], d.rect[3], 8 do
			for z = d.rect[2], d.rect[4], 8 do
				n += 1
				if T.walkable(x, z) then
					w += 1
				end
				top = math.max(top, T.height(x, z) - 10)
			end
		end
		expect(w / n >= 0.4).toBe(true)
		expect(top >= 6).toBe(true)
	end)

	it("raises the spires 25+ studs over their surroundings, walls and mesa walls nobody stands on", function()
		for _, s in assert(SHAPE.spires, "spires") do
			if s.h >= 25 then
				local foot = math.min(
					T.height(s.x + s.r * 2, s.z),
					T.height(s.x - s.r * 2, s.z),
					T.height(s.x, s.z + s.r * 2),
					T.height(s.x, s.z - s.r * 2)
				)
				if T.height(s.x, s.z) - foot < 25 then
					error(`spire at {s.x}, {s.z} only {T.height(s.x, s.z) - foot} studs`)
				end
				expect(T.walkable(s.x + s.r * 0.6, s.z)).toBe(false)
			end
		end
		for _, m in assert(SHAPE.mesas, "mesas") do
			if m.x and m.rx then
				local wx = m.x + m.rx + m.cliff * 0.5
				expect(T.walkable(wx, m.z or 0)).toBe(false)
			end
		end
	end)

	it("makes the oasis a flat dry bed under its rim with water in the last pond", function()
		local dl = assert(SHAPE.drylakes, "drylakes")[1]
		local pond = DATA.lakes[1]
		local lo, hi = math.huge, -math.huge
		for _, p in { { -680, 600 }, { -620, 560 }, { -460, 640 }, { -420, 600 }, { -520, 680 }, { -640, 660 } } do
			local h = T.height(p[1], p[2])
			lo, hi = math.min(lo, h), math.max(hi, h)
		end
		expect(hi - lo <= 2).toBe(true)
		expect(T.height(dl.x, dl.z - dl.rz - 30) - hi >= 2.5).toBe(true)
		expect(T.isWater(pond.x, pond.z)).toBe(true)
		expect(T.isWater(-620, 560)).toBe(false)
	end)

	it("lets a player walk from the Duskwood portal to every group, arrival, cave, portal, respawn and site", function()
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
		-- sites on top of a spire or in a wall are seen, not walked to
		local aloft = { wyvernStone = true, nestMesa = false, lairMouth = true, mineMouth = true, forgeGate = true }
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

describe("Ashen Wastes: monster groups", function()
	it("places exactly every area's groups on dry, gentle ground, 12+ studs from lava, cracks and water", function()
		local per: { [string]: number } = {}
		for _, s in AreaSpawns.region(DATA, MAP.size) do
			per[s.areaId] = (per[s.areaId] or 0) + 1
			local x, z = s.position.x, s.position.z
			if not MapTerrain.walkable("ashen", x, z, AreaSpawns.CLIFF_CLEARANCE) then
				error(`group {s.id} at {x}, {z} is not on walkable ground`)
			end
			expect(math.abs(s.position.y - T.height(x, z)) <= 1).toBe(true)
			if T.lavaDistance(x, z) < CLEAR then
				error(`group {s.id} at {x}, {z} is {T.lavaDistance(x, z)} studs from lava`)
			end
			if not T.dryAround(x, z, 12) then
				error(`group {s.id} at {x}, {z} is within 12 studs of water`)
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

	it("lets the golems lead groups in the Golem Fields", function()
		local golems = 0
		for _, s in AreaSpawns.region(DATA, MAP.size) do
			if s.areaId == "ashen_golemfields" and s.monster == "fireGolem" then
				golems += 1
			end
		end
		expect(golems >= 2).toBe(true)
	end)
end)

describe("Ashen Wastes: generator", function()
	it(
		"stays within the server part budget (shell + ~300 for portals, signs and nodes); 150+ big dead trees",
		function()
			local c = AshenGen.counts()
			if c.shell + 300 > assert(MAP.maxParts, "maxParts") then
				error(`shell {c.shell} + 300 > {MAP.maxParts}`)
			end
			expect(c.detail > c.shell).toBe(true)
			local trees = AshenGen.trees()
			expect(#trees >= 150 and #trees <= 260).toBe(true)
			for _, t in trees do
				expect(t.kind ~= "gnarledOak" and t.kind ~= "darkPine" and t.kind ~= "mossWillow").toBe(true)
				expect(T.lavaDistance(t.x, t.z) >= 6).toBe(true)
			end
		end
	)

	it("builds every Build on the ground and inside the map", function()
		local aloft: { [string]: boolean } =
			{ bridge = true, trees = true, lava = true, crag = true, pool = true, jetty = true, lavafall = true }
		for _, b in AshenGen.all() do
			if b.tag ~= "trees" and b.tag ~= "lava" and (math.abs(b.at.x) > 800 or math.abs(b.at.z) > 800) then
				error(`{b.name} outside the map`)
			end
			if
				not aloft[b.tag]
				and b.name ~= "wyvernStone"
				and b.name ~= "Crater"
				and b.name ~= "GlowPit"
				and b.name ~= "rockTombs"
			then
				local g = T.height(b.at.x, b.at.z)
				if math.abs(b.at.y - g) > 6 then
					error(`{b.name} stands {b.at.y - g} studs off the ground`)
				end
			end
		end
	end)

	it("dresses the mouth of every cave (a generator Build at each entrance)", function()
		local all = AshenGen.all()
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

	it("places gathering nodes by the areas' character (12 silver, 10 mithril, 26 fire bloom, 2 fishing)", function()
		local per: { [string]: number } = {}
		local nodes = AshenGen.nodes()
		for i, n in nodes do
			per[n.kind] = (per[n.kind] or 0) + 1
			if n.kind ~= "fishing_ashen" then
				expect(T.walkable(n.x, n.z)).toBe(true)
				expect(T.lavaDistance(n.x, n.z) >= CLEAR).toBe(true)
				expect(T.roadDistance(n.x, n.z) > 3).toBe(true)
			end
			for k, other in nodes do
				if k > i and (n.x - other.x) ^ 2 + (n.z - other.z) ^ 2 < 24 * 24 then
					error(`nodes {n.kind} and {other.kind} closer than 24 studs`)
				end
			end
			local theme = T.themeAt(n.x, n.z)
			if n.kind == "vein_mithril" then
				local d = T.lavaDistance(n.x, n.z)
				expect(theme == "crags" or (theme == "lavafield" and d < 40) or (n.z > 210 and n.x > 350)).toBe(true)
			end
		end
		expect(per.vein_silver).toBe(12)
		expect(per.vein_mithril).toBe(10)
		expect(per.bush_firebloom).toBe(26)
		expect(per.fishing_ashen).toBe(2)
	end)

	it("puts the fishing spots on the north shores with water where the buoys float", function()
		local spots = AshenGen.fishingSpots()
		expect(#spots).toBe(2)
		for _, spot in spots do
			expect(T.isWater(spot.x, spot.z)).toBe(false)
			expect(T.isWater(spot.x, spot.z + 9)).toBe(true)
			expect(T.isWater(spot.x, spot.z + 12)).toBe(true)
		end
	end)

	it("gives the client life to animate and the map a sketch with lava", function()
		local kinds: { [string]: number } = {}
		for _, l in AshenGen.life() do
			kinds[l.kind] = (kinds[l.kind] or 0) + 1
		end
		for _, k in
			{ "vulturePerch", "vultures", "embers", "haze", "steam", "smoke", "smokeColumn", "lavaBubbles", "wisp" }
		do
			if (kinds[k] or 0) == 0 then
				error(`no life of kind {k}`)
			end
		end
		local shapes: { [string]: number } = {}
		for _, s in AshenGen.sketch() do
			shapes[s.c] = (shapes[s.c] or 0) + 1
		end
		for _, k in
			{ "lava", "drylake", "dune", "crag", "cliff", "building", "wall", "bridge", "water", "path", "pyramid" }
		do
			if (shapes[k] or 0) == 0 then
				error(`no sketch shapes of kind {k}`)
			end
		end
	end)

	it(
		"tags the effects the client animates (lava, crust, lava fall, embers, vents, forge, glow) and lava lights",
		function()
			local tags: { [string]: number } = {}
			local lavaLights = 0
			for _, b in AshenGen.all() do
				for _, p in b.bp.pieces do
					if p.tag then
						tags[p.tag] = (tags[p.tag] or 0) + 1
					end
				end
				for _, l in b.bp.lights do
					if l.tag == "lava" then
						lavaLights += 1
					end
				end
			end
			for _, k in { "lava", "lavaCrust", "lavafall", "ember", "vent", "forge", "glow", "flag", "smoke", "fire" } do
				if (tags[k] or 0) == 0 then
					error(`no parts tagged {k}`)
				end
			end
			expect(lavaLights >= 12).toBe(true)
		end
	)
end)
