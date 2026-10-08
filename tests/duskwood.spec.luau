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
	{ "duskwood_witchmarsh", { 36, 42 }, { "marshWitch", "swampTroll" }, 4, "loot" },
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
				expect(s.id).toBe("")
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
			per[n.kind] = (per[n.kind] or 0) + 1
			expect(T.walkable(n.x, n.z)).toBe(true)
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
