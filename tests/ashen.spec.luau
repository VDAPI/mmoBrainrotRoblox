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
local Config = require("../src/shared/Config")
local Fixture = require("./fixtures/ashenHeights")
local Kit = require("../src/shared/Logic/WorldGen/Kit")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local Maps = require("../src/shared/Data/Maps")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local Portals = require("../src/shared/Data/Portals")
local Quest = require("../src/shared/Logic/AshenGen/Quest")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local Shapes = require("../src/shared/Data/Terrain")
local TerrainLayers = require("../src/shared/Logic/TerrainLayers")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local T = assert(RegionTerrain.get("ashen"), "ashen terrain")
local SHAPE = Shapes.byMap.ashen
local DATA = Areas.byMap.ashen
local Lairs = require("../src/shared/Logic/WorldGen/Lairs")
local SITES = assert(DATA.sites, "ashen sites")
local MAP = assert(Maps.get("ashen"))
local MAX_SLOPE = math.tan(math.rad(15))
local CLEAR = RegionTerrain.LAVA_CLEARANCE
-- S107: the NPC places of the side arcs (key -> NPC); the S104 cases below look at the story's places only
local S107_SPOTS = {
	waterkeeper = "waterkeeper_orren",
	prospector = "prospector_dragan",
	wyvernhunter = "wyvernhunter_wieslawa",
	tombwarden = "tombwarden_ezra",
	wagoner = "wagoner_bogna",
}

-- The areas of the brief (S46 "Obszary"): id, levels, kinds, groups, profile.
local BRIEF = {
	{ "ashen_flats", { 45, 50 }, { "salamander", "wasteHyena" }, 8, "exp" },
	{ "ashen_oasis", { 46, 52 }, { "wasteHyena", "ashVulture" }, 6, "loot" },
	{ "ashen_warcamp", { 48, 56 }, { "ashOrc", "ashVulture" }, 7, nil },
	{ "ashen_golemfields", { 52, 60 }, { "fireGolem", "fireImp" }, 7, nil },
	{ "ashen_burntruins", { 55, 61 }, { "fireImp", "desertScorpion" }, 6, "exp" },
	{ "ashen_dunes", { 55, 63 }, { "desertScorpion", "desertMummy" }, 7, "gold" },
	{ "ashen_crags", { 58, 66 }, { "wyvern", "basilisk" }, 6, "exp" },
	{ "ashen_ashroad", { 61, 69 }, { "basilisk", "wyvern" }, 4, "gold" }, -- S93: to 69
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
-- cave mouths, respawn points, the scout, the areas' arrivals; S104: the story NPCs' places and the quest anchors
-- (`anchor` = true: an anchor stands by its landmark, on a 20-degree slope at most within 4 studs).
local function standingPlaces(): { { name: string, x: number, z: number, anchor: boolean? } }
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
	for name, spot in DATA.npcSpots or {} do
		table.insert(list, { name = `npc {name}`, x = spot.x, z = spot.z })
	end
	for _, a in DATA.questAnchors or {} do
		table.insert(list, { name = `anchor {a.id}`, x = a.x, z = a.z, anchor = true })
	end
	return list
end

local ANCHOR_SLOPE = math.tan(math.rad(20))

-- S107 (side arcs of the Wastes): the places of the five new NPCs, the 28 ash_* anchors, their props and the routes of
-- the two companions, all on the frozen map ---------------------------------------------------------------------------

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local function inAvoid(x: number, z: number): boolean
	for _, c in DATA.avoid do
		if dist(x, z, c.x, c.z) <= c.r - 2 then
			return true
		end
	end
	return false
end

-- The name of a Build whose solid piece (shell or colliding) a player standing at (x, z) would touch within `margin`
-- studs (its rotated box, 0.5-3.5 studs over the ground), nil: none.
local function touchesSolid(x: number, z: number, margin: number): string?
	for _, b in AshenGen.all() do
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

local S107_ANCHORS = {
	"ash_cairn_1",
	"ash_cairn_2",
	"ash_cairn_3",
	"ash_hyena_skull",
	"ash_stranded_boat",
	"ash_well_1",
	"ash_well_2",
	"ash_well_3",
	"ash_spring_stones",
	"ash_war_drum",
	"ash_chief_tent",
	"ash_columns_sample",
	"ash_dragan_claim",
	"ash_hearth_1",
	"ash_hearth_2",
	"ash_hearth_3",
	"ash_dry_fountain",
	"ash_wyvern_lookout",
	"ash_great_nest",
	"ash_sarcophagus_1",
	"ash_sarcophagus_2",
	"ash_sarcophagus_3",
	"ash_courtyard_altar",
	"ash_pyramid_door",
	"ash_wagon_1",
	"ash_wagon_2",
	"ash_wagon_3",
	"ash_basilisk_den",
}
-- anchors standing by an existing build: the build and how far its nearest solid piece may be (the prompt sits by the
-- thing the text names, Config.SideQuest.useRange is 10)
local AT_THING: { [string]: string } = {
	ash_hyena_skull = "hyenaDen",
	ash_stranded_boat = "strandedBoat",
	ash_war_drum = "warDrum",
	ash_chief_tent = "chiefTent",
	ash_hearth_1 = "chimneyRow",
	ash_hearth_2 = "chimneyRow",
	ash_hearth_3 = "chimneyRow",
	ash_dry_fountain = "ruinsSquare",
	ash_great_nest = "nestMesa",
	ash_sarcophagus_1 = "sarcophagi",
	ash_sarcophagus_2 = "sarcophagi",
	ash_sarcophagus_3 = "sarcophagi",
	ash_courtyard_altar = "courtyardEast",
	ash_pyramid_door = "pyramid",
	ash_wagon_1 = "robbedWagons",
	ash_wagon_2 = "robbedWagons",
	ash_wagon_3 = "robbedWagons",
	ash_basilisk_den = "basiliskDen",
}
-- the nest mesa's top is rock (walkable): the one place where the rock rule is waived
local ON_ROCK = { ash_great_nest = true }

local function standingProblems(x: number, z: number, rock: boolean?): string?
	if math.abs(x) > 770 or math.abs(z) > 770 then
		return "outside the map"
	elseif not T.walkable(x, z) then
		return "not walkable"
	elseif slopeAround(x, z, 6) >= MAX_SLOPE then
		return `slope {math.floor(math.deg(math.atan(slopeAround(x, z, 6))))}`
	elseif T.isWater(x, z) then
		return "water"
	elseif T.lavaDistance(x, z) < CLEAR then
		return "lava"
	elseif not rock and T.rockAt(x, z) then
		return "rock"
	elseif T.roadDistance(x, z) <= 4 then
		return "road"
	elseif not inAvoid(x, z) then
		return "outside the avoid circles"
	end
	return nil
end

local function escortPoints(): { { name: string, x: number, z: number } }
	local Quests = require("../src/shared/Data/Quests")
	local out = {}
	for _, id in { "side_ash_wells", "side_ash_king" } do
		local quest = assert(Quests.Side.get(id), id)
		for _, objective in quest.objectives do
			if objective.type == "escort" then
				for i, v in objective.via or {} do
					table.insert(out, { name = `{id} via {i}`, x = v.x, z = v.z })
				end
				table.insert(out, { name = `{id} goal`, x = objective.x :: number, z = objective.z :: number })
			end
		end
	end
	return out
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
					-- W27 (owner decision 2026-10-20): ids from ProSoundEffects / APMOfficial, empty = not found
					expect(s.id == "" or string.match(s.id, "^rbxassetid://%d+$") ~= nil).toBe(true)
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
		-- S107: its NPC place keys (npc:<key>) and anchor ids are unique among the sites, areas, NPC places and anchors
		-- of every map too (/tparea looks them up on all maps)
		local names: { [string]: string } = {}
		local count: { [string]: number } = {}
		local function add(name: string, what: string)
			names[name] = what
			count[name] = (count[name] or 0) + 1
		end
		for mapId, data in Areas.byMap do
			for name in (data.sites or {}) :: { [string]: any } do
				add(name, `site of {mapId}`)
			end
			for _, area in data.areas do
				add(area.id, `area of {mapId}`)
			end
			for key in (data.npcSpots or {}) :: { [string]: any } do
				add(key, `npc place of {mapId}`)
			end
			for _, a in data.questAnchors or {} do
				add(a.id, `anchor of {mapId}`)
			end
		end
		for key in S107_SPOTS do
			expect(names[key]).toBe("npc place of ashen")
			expect(`{key} {count[key]}`).toBe(`{key} 1`)
		end
		for _, a in DATA.questAnchors or {} do
			if string.sub(a.id, 1, 4) == "ash_" then
				expect(`{a.id} {count[a.id]}`).toBe(`{a.id} 1`)
			end
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
				local slope = if p.anchor then slopeAround(p.x, p.z, 4) else slopeAround(p.x, p.z, 10)
				local limit = if p.anchor then ANCHOR_SLOPE else MAX_SLOPE
				if slope >= limit or T.isWater(p.x, p.z) or T.lavaDistance(p.x, p.z) < CLEAR then
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
		-- S107: the waypoints and goals of Orren's and Ezra's escorts
		for _, p in escortPoints() do
			table.insert(targets, p)
		end
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
			-- S134i: a hideout's own nodes stand by the hideout, not by the areas' character (tests/lairs.spec)
			local inLair = Lairs.at(DATA, n.x, n.z) ~= nil
			if not inLair then
				per[n.kind] = (per[n.kind] or 0) + 1
			end
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
			if n.kind == "vein_mithril" and not inLair then
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

-- S104 (story chapter III): the places of Brokk, Ghasha and Kaspar and the quest anchors on the frozen map --------------

describe("Ashen Wastes: story places of chapter III (S104)", function()
	local NEAR: { [string]: { x: number, z: number, max: number } } = {
		caravan_chest = { x = SITES.caravanChest.x, z = SITES.caravanChest.z, max = 12 },
		orc_cage = { x = SITES.orcCages.x, z = SITES.orcCages.z, max = 12 },
		-- the Colossus's head (-143 / 92) lies on the hill's 40-degree flank: the anchor stands at its foot before the
		-- face (the nearest gentle ground inside the colossus circle is 20 studs from the head)
		colossus_eyes = { x = -143, z = 92, max = 22 },
		temple_bell = { x = SITES.belltower.x, z = SITES.belltower.z, max = 12 },
		stone_caravan = { x = SITES.stoneCaravan.x, z = SITES.stoneCaravan.z, max = 12 },
	}

	it(
		"puts every NPC place and anchor inside an avoid circle, off the water; circles, areas and groups unchanged",
		function()
			local spots = assert(DATA.npcSpots, "npcSpots")
			local anchors = assert(DATA.questAnchors, "questAnchors")
			local points: { { name: string, x: number, z: number } } = {}
			for name, spot in spots do
				if not S107_SPOTS[name] then
					table.insert(points, { name = name, x = spot.x, z = spot.z })
				end
				expect(spot.wiki).toBeNil() -- S109: published on the wiki
			end
			for _, a in anchors do
				if string.sub(a.id, 1, 4) ~= "ash_" then -- S107's anchors: the side arc block below
					table.insert(points, { name = a.id, x = a.x, z = a.z })
				end
				expect(a.wiki).toBeNil() -- S109: published on the wiki
			end
			expect(#points).toBe(8)
			for _, p in points do
				local inside = false
				for _, c in DATA.avoid do
					if math.sqrt((p.x - c.x) ^ 2 + (p.z - c.z) ^ 2) <= c.r - 2 then
						inside = true
					end
				end
				expect(`{p.name} {inside}`).toBe(`{p.name} true`)
				expect(T.isWater(p.x, p.z)).toBe(false)
				for _, lake in DATA.lakes do
					expect(math.sqrt((p.x - lake.x) ^ 2 + (p.z - lake.z) ^ 2) > lake.r).toBe(true)
				end
			end
			-- the S46 data (tests above pin the areas and their 56 groups): the avoid circles stay 52
			expect(#DATA.avoid).toBe(52)
			expect(#AreaSpawns.region(DATA, MAP.size)).toBe(56)
			-- NPC places are named apart from every site of every map (/tparea looks at npcSpots first)
			for name in spots do
				for _, data in Areas.byMap do
					expect(`{name} {(data.sites or {} :: any)[name] == nil}`).toBe(`{name} true`)
				end
			end
		end
	)

	it("stands every anchor by its landmark, never in its middle", function()
		for _, a in assert(DATA.questAnchors, "questAnchors") do
			if string.sub(a.id, 1, 4) == "ash_" then
				continue -- S107 (the side arc block below)
			end
			local near = assert(NEAR[a.id], a.id)
			local d = math.sqrt((a.x - near.x) ^ 2 + (a.z - near.z) ^ 2)
			expect(`{a.id} {d <= near.max and d >= 2.5}`).toBe(`{a.id} true`)
		end
	end)

	it("keeps the cave anchors on the floor of their rooms in Deepforge", function()
		local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
		local cave = assert(Areas.caves.get("ashen_cave"))
		local terrain = assert(CaveTerrain.get("ashen_cave"))
		local rooms = { forge_chain_1 = 4, forge_chain_2 = 6, forge_chain_3 = 7 }
		-- S134h: the anchors and rooms as drawn in the scaled cave (Logic/CavePlan)
		local CavePlan = require("../src/shared/Logic/CavePlan")
		local anchors = CavePlan.anchors(cave)
		expect(#anchors).toBe(3)
		for _, a in anchors do
			local room = CavePlan.rooms(cave)[assert(rooms[a.id], a.id)]
			expect(terrain.floor(a.x, a.z) ~= nil).toBe(true)
			expect(terrain.liquid(a.x, a.z)).toBeNil()
			expect(math.sqrt((a.x - room.x) ^ 2 + (a.z - room.z) ^ 2) <= 0.65 * room.r).toBe(true)
			local _, mapId = Areas.anchorById(a.id)
			expect(mapId).toBe("ashen_cave")
		end
	end)

	it(
		"keeps the gathering nodes of S46 and builds the camp, the rest and the threshold inside their circles",
		function()
			-- the nodes before S104 (build/s104_nodes_before.json): 50 nodes, coordinate sums -11331 / 1059
			local sx, sz = 0, 0
			-- S134i: without the Elite II hideouts' own nodes (every other node unchanged)
			local nodes = {}
			for _, n in AshenGen.nodes() do
				if Lairs.at(DATA, n.x, n.z) == nil then
					table.insert(nodes, n)
				end
			end
			for _, n in nodes do
				sx += n.x
				sz += n.z
			end
			expect(#nodes).toBe(50)
			expect(sx).toBe(-11331)
			expect(sz).toBe(1059)
			local found: { [string]: boolean } = {}
			for _, b in AshenGen.all() do
				if b.name == "RunesmithCamp" or b.name == "ShamanRest" or b.name == "HermitThreshold" then
					found[b.name] = true
					local inside = false
					for _, c in DATA.avoid do
						if math.sqrt((b.at.x - c.x) ^ 2 + (b.at.z - c.z) ^ 2) <= c.r - 4 then
							inside = true
						end
					end
					expect(`{b.name} {inside}`).toBe(`{b.name} true`)
					for _, piece in b.bp.pieces do
						expect(piece.col).toBe(false)
						expect(piece.lod ~= "shell").toBe(true)
					end
				end
			end
			expect(found).toEqual({ RunesmithCamp = true, ShamanRest = true, HermitThreshold = true })
		end
	)
end)

describe("Ashen Wastes: side quest places (S107)", function()
	it(
		"the five NPC places: standing ground inside avoid circles, off roads and solid parts, on the wiki (S109)",
		function()
			local spots = assert(DATA.npcSpots, "npcSpots")
			for key, npcId in S107_SPOTS do
				local spot = assert(spots[key], key)
				expect(`{key} {standingProblems(spot.x, spot.z)}`).toBe(`{key} nil`)
				expect(`{key} {touchesSolid(spot.x, spot.z, 3)}`).toBe(`{key} nil`)
				expect(spot.facing >= 0 and spot.facing < 360).toBe(true)
				expect(spot.wiki).toBeNil() -- S109: published on the wiki
				for other, o in spots do
					if other ~= key then
						expect(`{key}-{other} {dist(spot.x, spot.z, o.x, o.z) >= 8}`).toBe(`{key}-{other} true`)
					end
				end
				local npc = assert(require("../src/shared/Data/Npcs").get(npcId), npcId)
				expect(npc.position.x).toBe(spot.x)
				expect(npc.position.z).toBe(spot.z)
				expect(npc.facing).toBe(spot.facing)
			end
		end
	)

	it("the 28 ash_* anchors: unique, standing ground in avoid circles, 8+ apart, 3+ from solid parts", function()
		local spots = assert(DATA.npcSpots, "npcSpots")
		local anchors = assert(DATA.questAnchors, "questAnchors")
		local n = 0
		for _, a in anchors do
			if string.sub(a.id, 1, 4) == "ash_" then
				n += 1
				expect(table.find(S107_ANCHORS, a.id) ~= nil).toBe(true)
				local found, mapId = Areas.anchorById(a.id)
				expect(found).toBe(a)
				expect(mapId).toBe("ashen")
				expect(a.wiki).toBeNil() -- S109: published on the wiki
				expect(`{a.id} {standingProblems(a.x, a.z, ON_ROCK[a.id])}`).toBe(`{a.id} nil`)
				expect(`{a.id} {touchesSolid(a.x, a.z, 3)}`).toBe(`{a.id} nil`)
				for mapName, data in Areas.byMap do
					for _, other in data.questAnchors or {} do
						if other ~= a then
							expect(other.id ~= a.id).toBe(true)
							if mapName == "ashen" then
								expect(`{a.id}-{other.id} {dist(a.x, a.z, other.x, other.z) >= 8}`).toBe(
									`{a.id}-{other.id} true`
								)
							end
						end
					end
				end
				for key, spot in spots do
					expect(`{a.id}-{key} {dist(a.x, a.z, spot.x, spot.z) >= 8}`).toBe(`{a.id}-{key} true`)
				end
			end
		end
		expect(n).toBe(#S107_ANCHORS)
	end)

	it("anchors without a prop stand by their thing: a solid piece of that build within reach of the prompt", function()
		local all = AshenGen.all()
		for id, name in AT_THING do
			local a = assert(Areas.anchorById(id), id)
			local best = math.huge
			for _, b in all do
				if b.name == name then
					for _, p in b.bp.pieces do
						if p.lod == "shell" or p.col then
							local px, _, pz = Kit.worldOf(b, p.p[1], p.p[2], p.p[3])
							best = math.min(best, dist(a.x, a.z, px, pz) - math.max(p.size[1], p.size[3]) / 2)
						end
					end
				end
			end
			expect(`{id} {best <= Config.SideQuest.useRange}`).toBe(`{id} true`)
			expect(Quest.kindOf(id)).toBeNil()
		end
	end)

	it("monster groups keep 12+ studs from the new places; the S46 data stays (52 circles, 56 groups)", function()
		local points: { { name: string, x: number, z: number } } = {}
		for key in S107_SPOTS do
			local spot = assert(DATA.npcSpots)[key]
			table.insert(points, { name = key, x = spot.x, z = spot.z })
		end
		for _, id in S107_ANCHORS do
			local a = assert(Areas.anchorById(id), id)
			table.insert(points, { name = id, x = a.x, z = a.z })
		end
		for _, g in AreaSpawns.region(DATA, MAP.size) do
			for _, p in points do
				if dist(p.x, p.z, g.position.x, g.position.z) < 12 then
					error(`group {g.id} stands {dist(p.x, p.z, g.position.x, g.position.z)} studs from {p.name}`)
				end
			end
		end
		expect(#DATA.avoid).toBe(52)
		expect(#AreaSpawns.region(DATA, MAP.size)).toBe(56)
	end)

	it(
		"a prop at the nine anchors of AshenGen/Quest, on the ground by its anchor, clear of trees, rocks and nodes",
		function()
			local all = AshenGen.all()
			local rocks: { any } = {}
			local props = 0
			local others = 0
			for _, b in all do
				if b.tag == "rocks" then
					table.insert(rocks, b)
				end
				if string.match(b.name, "^QuestProp_") then
					props += 1
				elseif b.tag == "lair" then
					continue -- S134i: the Elite II hideouts
				elseif string.match(b.name, "^Detail_") then
					continue -- W18: the map plan's details (AshenGen/Details), after the quest props
				else
					others += 1
				end
			end
			-- the Builds before S107 (build/s107_before.json: 527, names and places unchanged)
			-- S134i: one rock less (Rocks_crags_9 stood in the bone nest hideout)
			expect(others).toBe(527 - 1)
			expect(props).toBe(9)
			for _, id in S107_ANCHORS do
				local a = assert(Areas.anchorById(id), id)
				if Quest.kindOf(id) then
					local build: any = nil
					for _, b in all do
						if b.name == `QuestProp_{id}` then
							build = b
						end
					end
					local b = assert(build, `QuestProp_{id}`)
					expect(b.tag).toBe("questprop")
					local d = dist(a.x, a.z, b.at.x, b.at.z)
					expect(`{id} {d >= 1 and d <= 4}`).toBe(`{id} true`)
					expect(math.abs(b.at.y - T.height(b.at.x, b.at.z)) <= 1).toBe(true)
					expect(T.lavaDistance(b.at.x, b.at.z) >= 8).toBe(true)
					expect(T.isWater(b.at.x, b.at.z)).toBe(false)
					expect(#b.bp.pieces <= 8).toBe(true)
					for _, piece in b.bp.pieces do
						expect(piece.col).toBe(false)
						expect(piece.lod ~= "shell").toBe(true)
					end
					for _, t in AshenGen.trees() do
						expect(`{id} {dist(b.at.x, b.at.z, t.x, t.z) >= 4}`).toBe(`{id} true`)
					end
					for _, r in rocks do
						expect(`{id} {dist(b.at.x, b.at.z, r.at.x, r.at.z) >= 4}`).toBe(`{id} true`)
					end
					for _, node in AshenGen.nodes() do
						expect(dist(b.at.x, b.at.z, node.x, node.z) >= 4).toBe(true)
					end
				end
			end
		end
	)

	it("Orren and Ezra lead on walkable, dry ground away from lava, legs within legMax", function()
		local Companion = require("../src/shared/Logic/Companion")
		local Quests = require("../src/shared/Data/Quests")
		local Npcs = require("../src/shared/Data/Npcs")
		for id, npcId in { side_ash_wells = "waterkeeper_orren", side_ash_king = "tombwarden_ezra" } do
			local quest = assert(Quests.Side.get(id), id)
			local def = assert(quest.companion, id)
			expect(def.mode).toBe("lead")
			expect(def.npc).toBe(npcId)
			expect(def.during).toEqual({ 1 })
			local escort, index = Companion.escortOf(quest)
			local e = assert(escort, id)
			expect(index).toBe(1)
			local start = assert(Companion.fromOf(def))
			local npc = assert(Npcs.get(npcId))
			expect(start.x).toBe(npc.position.x)
			expect(start.z).toBe(npc.position.z)
			local route = Companion.route(def, e, start)
			expect(#route >= 3).toBe(true)
			for i, p in route do
				expect(`{id} {i} {MapTerrain.walkable("ashen", p.x, p.z, 4)}`).toBe(`{id} {i} true`)
				expect(T.isWater(p.x, p.z)).toBe(false)
				expect(T.lavaDistance(p.x, p.z) >= CLEAR).toBe(true)
				expect(T.rockAt(p.x, p.z)).toBe(false)
				for _, lake in DATA.lakes do
					expect(dist(p.x, p.z, lake.x, lake.z) > lake.r).toBe(true)
				end
				if i > 1 then
					local before = route[i - 1]
					expect(dist(p.x, p.z, before.x, before.z) <= Config.Companion.legMax).toBe(true)
				end
			end
		end
	end)
end)
