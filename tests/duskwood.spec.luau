--!strict
-- S45: Duskwood rebuilt on the shared region engine: the areas of the brief, their themes and moods, every area's
-- groups on dry gentle ground away from the water, landmarks, unique site names, gathering nodes by the areas'
-- character, fishing spots with water where the buoys float, the server part budget, every Build on the ground and
-- inside the map, a dressed mouth at every cave, life and sketch for the client, and the map's background build.

local Ambience = require("../src/shared/Data/Ambience")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local DuskwoodGen = require("../src/shared/Logic/DuskwoodGen")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local Maps = require("../src/shared/Data/Maps")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local DATA = Areas.byMap.duskwood
local Lairs = require("../src/shared/Logic/WorldGen/Lairs")
local T = assert(RegionTerrain.get("duskwood"))
local MAP = assert(Maps.get("duskwood"))

-- The areas of the brief (S45 "Kontekst"): id, name key, levels, kinds, groups, profile.
local BRIEF = {
	{ "duskwood_werethicket", { 20, 25 }, { "werewolf", "blackBear" }, 8, "exp" },
	{ "duskwood_bearhollow", { 21, 27 }, { "blackBear", "werewolf" }, 6, "loot" },
	{ "duskwood_ruins", { 24, 31 }, { "forestWraith", "ghoul" }, 7, "gold" },
	{ "duskwood_heart", { 26, 33 }, { "rotEnt", "ghoul" }, 7, "exp" },
	{ "duskwood_cultvillage", { 29, 37 }, { "darkCultist", "bogSerpent" }, 7, "gold" },
	{ "duskwood_crossroads", { 30, 36 }, { "bogSerpent", "darkCultist", "forestWraith" }, 5, "exp" },
	{ "duskwood_swamp", { 32, 40 }, { "swampTroll", "bogSerpent", "marshWitch" }, 7, "exp" },
	{ "duskwood_witchmarsh", { 36, 44 }, { "marshWitch", "swampTroll" }, 4, "loot" }, -- S92: 42 -> 44
	{ "duskwood_bloodcliffs", { 40, 45 }, { "bloodBat", "marshWitch" }, 6, nil },
}

local function inRect(r: { number }, x: number, z: number): boolean
	return x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4]
end

describe("Duskwood", function()
	it("keeps the areas of the brief (ids, levels, kinds, groups, profiles) without overlaps", function()
		expect(#DATA.areas).toBe(#BRIEF)
		for i, b in BRIEF do
			local a = DATA.areas[i]
			expect(a.id).toBe(b[1])
			expect(a.nameKey).toBe(`area.{b[1]}`)
			expect(a.lv).toEqual(b[2])
			expect(a.kinds).toEqual(b[3])
			expect(a.groups).toBe(b[4])
			expect(a.profile).toBe(b[5])
		end
		for i, a in DATA.areas do
			for k, other in DATA.areas do
				if k > i then
					local r, o = a.rect, other.rect
					local overlap = r[1] < o[3] and o[1] < r[3] and r[2] < o[4] and o[2] < r[4]
					if overlap then
						error(`{a.id} overlaps {other.id}`)
					end
				end
			end
		end
	end)

	it("gives every area a decoration theme, a landmark and a mood with sounds to fill in", function()
		for _, a in DATA.areas do
			expect(type(a.decor)).toBe("string")
			local mark = assert(a.landmark, `{a.id} landmark`)
			expect(inRect(a.rect, mark.x, mark.z)).toBe(true)
			local mood = assert(Ambience.moodOf("duskwood", a.id), `{a.id} mood`)
			expect(#mood.sounds.day > 0 and #mood.sounds.night > 0).toBe(true)
			for _, s in mood.sounds.day do
				-- W27 (owner decision 2026-10-20): ids from ProSoundEffects / APMOfficial, empty = not found
				expect(s.id == "" or string.match(s.id, "^rbxassetid://%d+$") ~= nil).toBe(true)
				expect(#s.hint > 10).toBe(true)
			end
		end
		expect(Ambience.moodOf("duskwood", nil) ~= nil).toBe(true)
	end)

	it("places exactly every area's groups on dry, gentle ground, 12+ studs from any water", function()
		local per: { [string]: number } = {}
		for _, s in AreaSpawns.region(DATA, MAP.size) do
			per[s.areaId] = (per[s.areaId] or 0) + 1
			local x, z = s.position.x, s.position.z
			if not MapTerrain.walkable("duskwood", x, z, AreaSpawns.CLIFF_CLEARANCE) then
				error(`group {s.id} at {x}, {z} is not on walkable ground`)
			end
			expect(math.abs(s.position.y - T.height(x, z)) <= 1).toBe(true)
			if not T.dryAround(x, z, 12) or T.streamDistance(x, z) < 12 then
				error(`group {s.id} at {x}, {z} is within 12 studs of water`)
			end
		end
		for _, a in DATA.areas do
			expect(per[a.id]).toBe(a.groups)
		end
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
		for _, name in { "moonstone", "fallenGiant", "manor", "elderTree", "ritualCircle", "wayShrine" } do
			expect(seen[name]).toBe("duskwood")
		end
		for _, name in { "sunkenTower", "witchHut", "cryptGate" } do
			expect(seen[name]).toBe("duskwood")
		end
	end)

	it("places gathering nodes by the areas' character, at least as many as before", function()
		local per: { [string]: number } = {}
		for _, n in DuskwoodGen.nodes() do
			expect(T.walkable(n.x, n.z)).toBe(true)
			-- S134i: a hideout's own nodes stand by the hideout, not by the areas' character (tests/lairs.spec)
			if Lairs.at(DATA, n.x, n.z) then
				continue
			end
			per[n.kind] = (per[n.kind] or 0) + 1
			local theme = T.themeAt(n.x, n.z)
			if n.kind == "vein_iron" then
				expect(theme == "thicket" or theme == "hollow" or (T.gorgeFloor(n.x, n.z))).toBe(true)
			elseif n.kind == "vein_silver" then
				expect(theme == "cliffs" or (T.plateauAt(n.x, n.z))).toBe(true)
			end
		end
		expect(per.vein_iron >= 12).toBe(true)
		expect(per.vein_silver >= 10).toBe(true)
		expect(per.bush_nightshade >= 14).toBe(true)
		expect(per.bush_moonpetal >= 12).toBe(true)
		expect(per.fishing_duskwood).toBe(2)
	end)

	it("puts fishing spots on the shore with water where the buoys float", function()
		for _, spot in DuskwoodGen.fishingSpots() do
			expect(T.isWater(spot.x, spot.z)).toBe(false)
			expect(T.isWater(spot.x, spot.z + 9)).toBe(true)
			expect(T.isWater(spot.x, spot.z + 12)).toBe(true)
		end
	end)

	it("stays within the server part budget (generator shell + ~300 for portals, signs and nodes)", function()
		local c = DuskwoodGen.counts()
		local limit = assert(MAP.maxParts, "duskwood maxParts")
		if c.shell + 300 > limit then
			error(`shell {c.shell} + 300 > {limit}`)
		end
		expect(#DuskwoodGen.trees() >= 700).toBe(true)
	end)

	it("builds every Build on the ground and inside the map", function()
		for _, b in DuskwoodGen.all() do
			-- tree tiles are 128-stud cells (their frame may lie past the edge, their trees do not)
			if b.tag ~= "trees" and (math.abs(b.at.x) > 800 or math.abs(b.at.z) > 800) then
				error(`{b.name} outside the map`)
			end
			if b.tag ~= "trees" and b.tag ~= "bridge" and b.tag ~= "jetty" and b.tag ~= "cliff" then
				local g = T.height(b.at.x, b.at.z)
				if
					math.abs(b.at.y - g) > 6
					and b.name ~= "SunkenTower"
					and b.tag ~= "pool"
					and b.name ~= "Waterfall"
				then
					error(`{b.name} stands {b.at.y - g} studs off the ground`)
				end
			end
		end
	end)

	it("dresses the mouth of every cave (a generator Build at each entrance)", function()
		local all = DuskwoodGen.all()
		for _, c in DATA.caves do
			local found = false
			for _, b in all do
				if (b.tag == "cave" or b.tag == "cryptGate") and (b.at.x - c.x) ^ 2 + (b.at.z - c.z) ^ 2 < 40 * 40 then
					found = true
				end
			end
			if not found then
				error(`no Build at the mouth of {c.cave}`)
			end
		end
	end)

	it("gives the client life to animate and the map a sketch", function()
		local kinds: { [string]: number } = {}
		for _, l in DuskwoodGen.life() do
			kinds[l.kind] = (kinds[l.kind] or 0) + 1
		end
		for _, k in { "batRoost", "bats", "perch", "wisp", "mist", "moths", "fireflies", "spores" } do
			expect((kinds[k] or 0) > 0).toBe(true)
		end
		local shapes: { [string]: number } = {}
		for _, s in DuskwoodGen.sketch() do
			shapes[s.c] = (shapes[s.c] or 0) + 1
		end
		for _, k in
			{ "marsh", "basin", "ravine", "cliff", "plateau", "building", "bridge", "wall", "cemetery", "water" }
		do
			expect((shapes[k] or 0) > 0).toBe(true)
		end
	end)

	it("builds in the background with day, night and an eternal dusk", function()
		expect(MAP.buildLate).toBe(true)
		expect(MAP.dayNight).toBe(true)
		expect(MAP.nightLighting ~= nil).toBe(true)
		local clock = assert(MAP.dayClock, "dayClock")
		expect(clock[1] >= 16 and clock[2] <= 19 and clock[1] < clock[2]).toBe(true)
	end)
end)

-- S103: places of the story chapter II (NPC spots, quest anchors, the props of DuskwoodGen/Quest) ------------------

local Kit = require("../src/shared/Logic/WorldGen/Kit")
local Npcs = require("../src/shared/Data/Npcs")
local Quest = require("../src/shared/Logic/DuskwoodGen/Quest")
local Spawns = require("../src/shared/Data/Spawns")

local SITES = assert(DATA.sites, "sites")
-- spot -> NPC, site of its avoid circle and the local point of the plan (D3)
local SPOTS = {
	radomir = { npc = "forester_radomir", site = "ravagedCamp", lx = -6, lz = -11 },
	oswin = { npc = "ghost_oswin", site = "chapel", lx = 3, lz = -14 },
	jorund = { npc = "defector_jorund", site = "wayShrine", lx = -5, lz = -6 },
	ragna = { npc = "witch_ragna", site = "stiltVillage" },
}
-- anchor -> site and local point (D4)
local ANCHORS = {
	moonstone_rune = { site = "moonstone", lx = 0, lz = -4 },
	lost_camp = { site = "lostCamp", lx = -3, lz = -7 },
	chapel_window = { site = "chapel", lx = 0, lz = 4 },
	family_crypt = { site = "familyCrypt", lx = 0, lz = -8 },
	elder_tree = { site = "elderTree", lx = 0, lz = -9 },
	crypt_seal = { site = "cryptGate", lx = 15, lz = -21 },
}

local function avoidRadius(site: string): number
	local s = SITES[site]
	for _, c in DATA.avoid do
		if c.x == s.x and c.z == s.z then
			return c.r
		end
	end
	error(`no avoid circle at {site}`)
end

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- The name of a Build whose colliding piece a player standing at (x, z) would touch within `margin` (nil: none).
local function blockedBy(x: number, z: number, margin: number): string?
	for _, b in DuskwoodGen.all() do
		if b.tag ~= "trees" and (b.at.x - x) ^ 2 + (b.at.z - z) ^ 2 < 120 * 120 then
			local r = math.rad(b.at.rot)
			local c, s = math.cos(r), math.sin(r)
			local dx, dz = x - b.at.x, z - b.at.z
			local lx, lz = c * dx - s * dz, s * dx + c * dz
			local g = T.height(x, z) - b.at.y
			for _, p in b.bp.pieces do
				if p.col then
					for _, h in { 0.5, 2, 3.5, 5 } do
						local vx, vy, vz = lx - p.p[1], g + h - p.p[2], lz - p.p[3]
						local R = p.r
						local ux = R[1] * vx + R[4] * vy + R[7] * vz
						local uy = R[2] * vx + R[5] * vy + R[8] * vz
						local uz = R[3] * vx + R[6] * vy + R[9] * vz
						if
							math.abs(ux) < p.size[1] / 2 + margin
							and math.abs(uy) < p.size[2] / 2
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

describe("Duskwood story places (S103)", function()
	it(
		"the four NPC places: in their site's avoid circle, on dry walkable ground, apart, hidden from the wiki",
		function()
			local spots = assert(DATA.npcSpots, "npcSpots")
			local list = {}
			for key, plan in SPOTS do
				local spot = assert(spots[key], key)
				local site = SITES[plan.site]
				expect(`{key} {dist(spot.x, spot.z, site.x, site.z) < avoidRadius(plan.site)}`).toBe(`{key} true`)
				expect(`{key} {MapTerrain.walkable("duskwood", spot.x, spot.z, 2)}`).toBe(`{key} true`)
				expect(T.dryAround(spot.x, spot.z, 3)).toBe(true)
				expect(T.water(spot.x, spot.z)).toBeNil()
				expect(T.streamDistance(spot.x, spot.z) >= 6).toBe(true)
				expect(`{key} {blockedBy(spot.x, spot.z, 2)}`).toBe(`{key} nil`)
				expect(dist(spot.x, spot.z, -690, -36) >= 8).toBe(true)
				expect(spot.wiki).toBeNil() -- S109: published on the wiki
				local npc = assert(Npcs.get(plan.npc), plan.npc)
				expect(npc.position.x).toBe(spot.x)
				expect(npc.position.z).toBe(spot.z)
				expect(npc.facing).toBe(spot.facing)
				table.insert(list, spot)
			end
			for i, a in list do
				for k, b in list do
					if k > i then
						expect(dist(a.x, a.z, b.x, b.z) >= 8).toBe(true)
					end
				end
			end
		end
	)

	it("the six anchors: in their site's avoid circle, dry, walkable, apart from every anchor and NPC place", function()
		local spots = assert(DATA.npcSpots, "npcSpots")
		for id, plan in ANCHORS do
			local anchor, mapId = Areas.anchorById(id)
			local a = assert(anchor, id)
			expect(mapId).toBe("duskwood")
			local site = SITES[plan.site]
			expect(`{id} {dist(a.x, a.z, site.x, site.z) < avoidRadius(plan.site)}`).toBe(`{id} true`)
			expect(T.water(a.x, a.z)).toBeNil()
			expect(`{id} {MapTerrain.walkable("duskwood", a.x, a.z, 2)}`).toBe(`{id} true`)
			expect(a.wiki).toBeNil() -- S109: published on the wiki
			expect(a.rot).toBe(site.rot)
			for mapName, data in Areas.byMap do
				for _, other in data.questAnchors or {} do
					if other ~= a then
						expect(other.id ~= id).toBe(true)
						expect(`{id}-{mapName}:{other.id} {dist(a.x, a.z, other.x, other.z) >= 6}`).toBe(
							`{id}-{mapName}:{other.id} true`
						)
					end
				end
			end
			for key, spot in spots do
				expect(`{id}-{key} {dist(a.x, a.z, spot.x, spot.z) >= 5}`).toBe(`{id}-{key} true`)
			end
		end
		-- the seal's prompt clear of the Crypt's mouth; the window inside the chapel
		local seal = assert(Areas.anchorById("crypt_seal"))
		local cave = assert(Areas.entranceOf("duskwood_cave"))
		expect(dist(seal.x, seal.z, cave.x, cave.z) >= 12).toBe(true)
		local plan = ANCHORS.chapel_window
		expect(math.abs(plan.lx) < 5 and plan.lz > -8 and plan.lz < 5).toBe(true)
	end)

	it("atSite of Areas/duskwood agrees with Kit.toWorld", function()
		local spots = assert(DATA.npcSpots, "npcSpots")
		for key, plan in SPOTS do
			if plan.lx then
				local s = SITES[plan.site]
				local x, z = Kit.toWorld(s.x, s.z, s.rot, plan.lx :: number, plan.lz :: number)
				expect(math.abs(spots[key].x - x) < 1e-9 and math.abs(spots[key].z - z) < 1e-9).toBe(true)
			end
		end
		for id, plan in ANCHORS do
			local s = SITES[plan.site]
			local x, z = Kit.toWorld(s.x, s.z, s.rot, plan.lx, plan.lz)
			local a = assert(Areas.anchorById(id))
			expect(math.abs(a.x - x) < 1e-9 and math.abs(a.z - z) < 1e-9).toBe(true)
		end
	end)

	it("one prop of at most 8 pieces at every anchor of DuskwoodGen/Quest, without collisions", function()
		local found: { [string]: number } = {}
		for _, b in DuskwoodGen.all() do
			local id = string.match(b.name, "^QuestProp_(.+)$")
			if id then
				found[id] = (found[id] or 0) + 1
				expect(b.tag).toBe("questprop")
				expect(#b.bp.pieces <= 8).toBe(true)
				for _, piece in b.bp.pieces do
					expect(piece.col).toBe(false)
					expect(piece.lod ~= "shell").toBe(true)
				end
			end
		end
		for _, id in { "moonstone_rune", "elder_tree", "crypt_seal" } do
			expect(found[id]).toBe(1)
			expect(Quest.kindOf(id) ~= nil).toBe(true)
			expect(Quest.frame(id) ~= nil).toBe(true)
		end
		expect(Quest.frame("lost_camp")).toBeNil()
	end)

	it("monster groups and gathering nodes are those of before S103 (count and position checksum)", function()
		-- S134i: without the Elite II hideouts' spawners and nodes (every other one unchanged)
		local groups = {}
		for _, g in Spawns.byMap.duskwood do
			if g.lair == nil then
				table.insert(groups, g)
			end
		end
		local gs = 0
		for _, g in groups do
			gs += g.position.x + 3 * g.position.z
		end
		expect(#groups).toBe(57)
		expect(string.format("%.3f", gs)).toBe("7475.000")
		local nodes = {}
		for _, n in DuskwoodGen.nodes() do
			if Lairs.at(DATA, n.x, n.z) == nil then
				table.insert(nodes, n)
			end
		end
		local ns = 0
		for _, n in nodes do
			ns += n.x + 3 * n.z
		end
		expect(#nodes).toBe(50)
		expect(string.format("%.3f", ns)).toBe("12269.000")
	end)
end)

-- S106: places of the Duskwood side arcs (NPC spots, dw_* anchors, the props of DuskwoodGen/Quest) -------------------

-- spot -> NPC of the side arcs
local SIDE_SPOTS = {
	huntress = "huntress_wanda",
	beekeeper = "beekeeper_maciej",
	gravedigger = "gravedigger_bogumil",
	herbalist = "herbalist_dobrawa",
	warden = "warden_zbyszko",
	ferryman = "ferryman_oldrzych",
	exorcist = "exorcist_kalina",
	mason = "mason_wojslaw",
}
-- dw_* anchors without a prop of their own -> the generator Build they stand at
local AT_BUILD = {
	dw_bonetree = "boneTree",
	dw_hive_1 = "Beehive",
	dw_grave_1 = "cemetery",
	dw_grave_2 = "cemetery",
	dw_grave_3 = "cemetery",
	dw_grave_4 = "cemetery",
	dw_burrow_1 = "GhoulBurrow_1",
	dw_burrow_2 = "GhoulBurrow_3",
	dw_burrow_3 = "GhoulBurrow_4",
	dw_cage_1 = "CultVillage",
	dw_cage_2 = "CultVillage",
	dw_troll_hoard = "trollVillage",
	dw_charm_1 = "hangingTree",
	dw_cauldron = "witchHut",
}

local function inAvoid(x: number, z: number): boolean
	for _, c in DATA.avoid do
		if dist(x, z, c.x, c.z) < c.r then
			return true
		end
	end
	return false
end

local function sideAnchors(): { [string]: any }
	local out = {}
	for _, a in DATA.questAnchors or {} do
		if string.sub(a.id, 1, 3) == "dw_" then
			out[a.id] = a
		end
	end
	return out
end

describe("Duskwood side arc places (S106)", function()
	it(
		"the eight NPC places: inside avoid circles, dry walkable ground, apart, clear of builds, on the wiki (S109)",
		function()
			local spots = assert(DATA.npcSpots, "npcSpots")
			for key, npcId in SIDE_SPOTS do
				local spot = assert(spots[key], key)
				expect(math.abs(spot.x) < 800 and math.abs(spot.z) < 800).toBe(true)
				expect(`{key} {inAvoid(spot.x, spot.z)}`).toBe(`{key} true`)
				expect(`{key} {MapTerrain.walkable("duskwood", spot.x, spot.z, 2)}`).toBe(`{key} true`)
				expect(`{key} {T.dryAround(spot.x, spot.z, 3)}`).toBe(`{key} true`)
				expect(T.streamDistance(spot.x, spot.z) >= 6).toBe(true)
				expect(spot.facing >= 0 and spot.facing < 360).toBe(true)
				expect(`{key} {blockedBy(spot.x, spot.z, 1)}`).toBe(`{key} nil`)
				expect(`{key} {AreaSpawns.nearRoad(DATA.roads, spot.x, spot.z, 6)}`).toBe(`{key} false`)
				expect(dist(spot.x, spot.z, -690, -36) >= 8).toBe(true)
				expect(spot.wiki).toBeNil() -- S109: published on the wiki
				for other, o in spots do
					if other ~= key then
						expect(`{key}-{other} {dist(spot.x, spot.z, o.x, o.z) >= 8}`).toBe(`{key}-{other} true`)
					end
				end
				local npc = assert(Npcs.get(npcId), npcId)
				expect(npc.map).toBe("duskwood")
				expect(npc.position.x).toBe(spot.x)
				expect(npc.position.z).toBe(spot.z)
				expect(npc.facing).toBe(spot.facing)
				expect(npc.wiki).toBeNil() -- S109: published on the wiki
			end
		end
	)

	it("the 30 dw_* anchors: unique, dry, walkable, in an avoid circle or 10+ studs from groups, apart", function()
		local anchors = sideAnchors()
		local spots = assert(DATA.npcSpots, "npcSpots")
		local groups = AreaSpawns.region(DATA, MAP.size)
		local n = 0
		for id, a in anchors do
			n += 1
			local found, mapId = Areas.anchorById(id)
			expect(found).toBe(a)
			expect(mapId).toBe("duskwood")
			expect(math.abs(a.x) < 800 and math.abs(a.z) < 800).toBe(true)
			expect(T.water(a.x, a.z)).toBeNil()
			expect(`{id} {MapTerrain.walkable("duskwood", a.x, a.z, 2)}`).toBe(`{id} true`)
			expect(a.wiki).toBeNil() -- S109: published on the wiki
			if not inAvoid(a.x, a.z) then
				for _, g in groups do
					if dist(a.x, a.z, g.position.x, g.position.z) < 10 then
						error(`{id} is {dist(a.x, a.z, g.position.x, g.position.z)} studs from group {g.id}`)
					end
				end
			end
			for mapName, data in Areas.byMap do
				for _, other in data.questAnchors or {} do
					if other ~= a then
						expect(other.id ~= id).toBe(true)
						if mapName == "duskwood" then
							expect(`{id}-{other.id} {dist(a.x, a.z, other.x, other.z) >= 6}`).toBe(
								`{id}-{other.id} true`
							)
						end
					end
				end
			end
			for key, spot in spots do
				expect(`{id}-{key} {dist(a.x, a.z, spot.x, spot.z) >= 5}`).toBe(`{id}-{key} true`)
			end
			expect(`{id} {blockedBy(a.x, a.z, 0.5)}`).toBe(`{id} nil`)
		end
		expect(n).toBe(30)
	end)

	it("a prop of DuskwoodGen/Quest at 16 anchors, an existing build at the other 14", function()
		local anchors = sideAnchors()
		local all = DuskwoodGen.all()
		local props = 0
		for id, a in anchors do
			if Quest.kindOf(id) then
				props += 1
				local found = 0
				for _, b in all do
					if b.name == `QuestProp_{id}` then
						found += 1
						expect(b.tag).toBe("questprop")
						expect(dist(a.x, a.z, b.at.x, b.at.z) <= 3).toBe(true)
						expect(#b.bp.pieces <= 8).toBe(true)
						for _, piece in b.bp.pieces do
							expect(piece.col).toBe(false)
							expect(piece.lod ~= "shell").toBe(true)
						end
					end
				end
				expect(`{id} {found}`).toBe(`{id} 1`)
			else
				local name = AT_BUILD[id]
				if not name then
					error(`{id}: neither a prop nor a build`)
				end
				local near = false
				for _, b in all do
					if b.name == name then
						for _, piece in b.bp.pieces do
							local px, _, pz = Kit.worldOf(b, piece.p[1], piece.p[2], piece.p[3])
							near = near or dist(a.x, a.z, px, pz) <= 6
						end
					end
				end
				expect(`{id} {near}`).toBe(`{id} true`)
			end
		end
		expect(props).toBe(16)
	end)

	it("the anchors at sites agree with Kit.toWorld", function()
		local plan = {
			dw_bonetree = { "boneTree", 0, -6 },
			dw_grave_1 = { "cemetery", -16, -10.5 },
			dw_grave_4 = { "cemetery", 16, 10.5 },
			dw_ossuary = { "cemetery", 0, 22 },
			dw_troll_hoard = { "trollVillage", -11, -8 },
			dw_cauldron = { "witchHut", 11, -1 },
		}
		for id, p in plan do
			local s = SITES[p[1]]
			local x, z = Kit.toWorld(s.x, s.z, s.rot, p[2], p[3])
			local a = assert(Areas.anchorById(id), id)
			expect(math.abs(a.x - x) < 0.01 and math.abs(a.z - z) < 0.01).toBe(true)
			expect(a.rot).toBe(s.rot)
		end
		-- the cages: the village is built without a turn
		local v = SITES.cultVillage
		local cage = assert(Areas.anchorById("dw_cage_1"))
		expect(cage.x).toBe(v.x - 30)
		expect(cage.z).toBe(v.z - 9.5)
	end)
end)
