--!strict
-- S26: Whispering Meadows data and generator: area ids and levels unchanged, decoration themes and moods, NPC places
-- and quest anchors for S27, monster groups on dry ground, the server part budget, gathering nodes by the areas'
-- character, bridges and fishing spots.

local Ambience = require("../src/shared/Data/Ambience")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local Maps = require("../src/shared/Data/Maps")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local MeadowsGen = require("../src/shared/Logic/MeadowsGen")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local Spawns = require("../src/shared/Data/Spawns")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local DATA = Areas.byMap.meadows

-- The areas as the S26 brief lists them (ids and levels must not change: quests, maps and spawns use them).
local EXPECTED: { [string]: { number } } = {
	meadows_rabbitfields = { 1, 4 },
	meadows_wolfhills = { 3, 7 },
	meadows_toadmire = { 4, 8 },
	meadows_oldforest = { 6, 11 },
	meadows_crowfield = { 8, 12 },
	meadows_banditroad = { 9, 14 },
	meadows_diggings = { 11, 15 },
	meadows_goblincamp = { 13, 18 },
	meadows_bearridge = { 16, 20 },
}

local THEMES = {
	meadow = true,
	hills = true,
	marsh = true,
	forest = true,
	field = true,
	road = true,
	quarry = true,
	goblin = true,
	ravine = true,
}

local function inSpawnRect(x: number, z: number): boolean
	for _, area in DATA.areas do
		local r = area.rect
		if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
			return true
		end
	end
	return false
end

local function inAvoid(x: number, z: number): boolean
	for _, c in DATA.avoid do
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 < c.r * c.r then
			return true
		end
	end
	return false
end

describe("Meadows data (S26)", function()
	it("keeps the area ids and levels of the brief", function()
		local seen = 0
		for _, area in DATA.areas do
			local lv = EXPECTED[area.id]
			expect(lv ~= nil).toBe(true)
			expect(area.lv[1]).toBe(lv[1])
			expect(area.lv[2]).toBe(lv[2])
			seen += 1
		end
		expect(seen).toBe(9)
	end)

	it("gives every area a decoration theme and a mood with sounds to fill in", function()
		for _, area in DATA.areas do
			expect(THEMES[area.decor or ""]).toBe(true)
			local mood = Ambience.areas[area.id]
			expect(mood ~= nil).toBe(true)
			expect(#mood.sounds.day > 0).toBe(true)
			expect(#mood.sounds.night > 0).toBe(true)
		end
		for _, sound in Ambience.allSounds() do
			expect(#sound.hint > 5).toBe(true)
			expect(sound.volume > 0 and sound.volume <= 1).toBe(true)
			expect(sound.id == "" or string.match(sound.id, "^rbxassetid://%d+$") ~= nil).toBe(true)
		end
	end)

	it("prepares the NPC places of S27: inside the map, dry, outside the monster areas or kept free", function()
		local spots = assert(DATA.npcSpots, "npc spots")
		for _, name in { "farmer", "fisher", "woodcutter", "merchant", "miner", "hunter", "shrine" } do
			local s = spots[name]
			expect(s ~= nil).toBe(true)
			expect(math.abs(s.x) <= 780 and math.abs(s.z) <= 780).toBe(true)
			expect(not MeadowsTerrain.isWater(s.x, s.z)).toBe(true)
			expect(not inSpawnRect(s.x, s.z) or inAvoid(s.x, s.z)).toBe(true)
			expect(s.facing >= 0 and s.facing < 360).toBe(true)
		end
	end)

	it("prepares the quest anchors of S27", function()
		local want = {
			"shrine_candles",
			"fence_1",
			"fence_2",
			"fence_3",
			"fence_4",
			"net_shore",
			"logpile_1",
			"logpile_2",
			"logpile_3",
			"logpile_4",
			"logpile_5",
			"mill_ruin",
			"wagon_goods",
			"tunnel_1",
			"tunnel_2",
			"tunnel_3",
			"totem_goblin",
			"bear_den",
		}
		local byId: { [string]: Areas.QuestAnchor } = {}
		for _, a in assert(DATA.questAnchors, "anchors") do
			expect(byId[a.id]).toBeNil()
			byId[a.id] = a
		end
		for _, id in want do
			local a = byId[id]
			if not a then
				error(`missing anchor {id}`)
			end
			expect(math.abs(a.x) <= 780 and math.abs(a.z) <= 780).toBe(true)
			if MeadowsTerrain.isWater(a.x, a.z) then
				error(`anchor {id} is in the water`)
			end
			if inSpawnRect(a.x, a.z) and not inAvoid(a.x, a.z) then
				-- quest objects in a monster area keep 10 studs from every group
				for _, s in Spawns.byMap.meadows do
					local d = math.sqrt((s.position.x - a.x) ^ 2 + (s.position.z - a.z) ^ 2)
					if d < 10 then
						error(`anchor {id} sits on group {s.id}`)
					end
				end
			end
		end
	end)

	it("puts every monster group on dry, gentle ground at the ground's height", function()
		for _, s in Spawns.byMap.meadows do
			local x, z = s.position.x, s.position.z
			if not MapTerrain.walkable("meadows", x, z, AreaSpawns.CLIFF_CLEARANCE) then
				error(`group {s.id} at {x}, {z} is not on walkable ground`)
			end
			expect(math.abs(s.position.y - MeadowsTerrain.height(x, z)) <= 1).toBe(true)
			expect(AreaSpawns.nearStream(DATA.streams, x, z, AreaSpawns.STREAM_CLEARANCE)).toBe(false)
		end
	end)
end)

describe("Meadows generator (S26)", function()
	it("stays within the server part budget (S20 map ~2150 parts, +30%)", function()
		local counts = MeadowsGen.counts()
		local map = assert(Maps.get("meadows"))
		-- portals, cave mouths, signposts and road lanterns from Prefabs add ~300 more parts
		expect(counts.shell + 300 <= (map.maxParts or 0)).toBe(true)
		expect(counts.detail > counts.shell).toBe(true)
	end)

	it("builds every Build on the ground and inside the map", function()
		for _, b in MeadowsGen.all() do
			-- (tree tiles are framed on a 128-stud grid, their trees stay inside the map)
			expect(math.abs(b.at.x) <= 840 and math.abs(b.at.z) <= 840).toBe(true)
			expect(b.at.y == b.at.y and b.at.y > -24 and b.at.y < 48).toBe(true)
			expect(#b.bp.pieces > 0).toBe(true)
		end
	end)

	it("places gathering nodes by the areas' character", function()
		local counts: { [string]: number } = {}
		local nodes = MeadowsGen.nodes()
		for i, n in nodes do
			counts[n.kind] = (counts[n.kind] or 0) + 1
			if n.kind ~= "fishing_meadows" then
				expect(MeadowsTerrain.walkable(n.x, n.z)).toBe(true)
				expect(AreaSpawns.nearRoad(DATA.roads, n.x, n.z, 4)).toBe(false)
			end
			for k = i + 1, #nodes do
				local o = nodes[k]
				expect((n.x - o.x) ^ 2 + (n.z - o.z) ^ 2 >= 23 * 23).toBe(true)
			end
			if n.kind == "bush_nightshade" then
				expect(MeadowsTerrain.themeAt(n.x, n.z)).toBe("forest")
			elseif n.kind == "bush_moonpetal" then
				local near = MeadowsTerrain.streamDistance(n.x, n.z) < 26 or MeadowsTerrain.lakeDistance(n.x, n.z) < 26
				expect(near).toBe(true)
			end
		end
		expect(counts.vein_copper or 0).toBe(14)
		expect(counts.vein_iron or 0).toBe(12)
		expect(counts.bush_meadowsweet or 0).toBe(14)
		expect(counts.bush_nightshade or 0).toBe(10)
		expect(counts.bush_moonpetal or 0).toBe(8)
		expect(counts.fishing_meadows or 0).toBe(3)
	end)

	it("puts fishing spots on the shore with water where the buoys float", function()
		for _, spot in MeadowsGen.fishingSpots() do
			expect(MeadowsTerrain.isWater(spot.x, spot.z)).toBe(false)
			expect(MeadowsTerrain.isWater(spot.x, spot.z + 9)).toBe(true)
		end
	end)

	it("gives the client life to animate and the map a sketch", function()
		local kinds: { [string]: number } = {}
		for _, p in MeadowsGen.life() do
			kinds[p.kind] = (kinds[p.kind] or 0) + 1
		end
		expect((kinds.perch or 0) >= 5).toBe(true)
		expect((kinds.sheep or 0) >= 1).toBe(true)
		expect((kinds.ducks or 0) >= 1).toBe(true)
		local shapes: { [string]: number } = {}
		for _, shape in MeadowsGen.sketch() do
			shapes[shape.c] = (shapes[shape.c] or 0) + 1
		end
		expect((shapes.building or 0) >= 8).toBe(true)
		expect((shapes.bridge or 0) >= 3).toBe(true)
		expect((shapes.field or 0) >= 3).toBe(true)
		expect(#MeadowsGen.trees() > 200).toBe(true)
	end)
end)
