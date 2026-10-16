--!strict
-- S134i: the Elite II hideouts of the region maps (Data/Areas `lairs`, Logic/AreaSpawns.lair, Logic/WorldGen/Lairs):
-- 2-3 on each of the four region maps, each a small dry, gentle corner off roads, water, buildings, caves and portals
-- but near a road, an Elite II alone in the middle and 2-3 guard groups on a ring, levels within its area's; the area
-- groups, their arrival points and the world events' points keep out of it; its own nodes at its edge, no rock, tree
-- or other node inside, its Build with an empty middle; Auto Hunt does not start inside one.

local AreaArrival = require("../src/shared/Logic/AreaArrival")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local AutoGrind = require("../src/shared/Logic/AutoGrind")
local Combat = require("../src/shared/Data/Combat")
local GatherNodes = require("../src/shared/Data/GatherNodes")
local Lairs = require("../src/shared/Logic/WorldGen/Lairs")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local Maps = require("../src/shared/Data/Maps")
local Monsters = require("../src/shared/Data/Monsters")
local Portals = require("../src/shared/Data/Portals")
local Spawns = require("../src/shared/Data/Spawns")
local T = require("./Test")
local WorldEvents = require("../src/shared/Logic/WorldEvents")
local WorldGen = require("../src/shared/Logic/WorldGen")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local REGIONS = { "meadows", "duskwood", "ashen", "frostpeak" }
local REGION_NUMBER = { meadows = 1, duskwood = 2, ashen = 3, frostpeak = 4 }
local LAIR_SPACING = 150 -- from another hideout, a cave mouth and a portal
local ROAD_REACH = 80 -- the road's edge at most this far (the hideout can be found)

local function lairsOf(mapId: string): { Areas.Lair }
	return Areas.byMap[mapId].lairs or {}
end

local function areaOf(mapId: string, id: string): Areas.Area?
	for _, area in Areas.byMap[mapId].areas do
		if area.id == id then
			return area
		end
	end
	return nil
end

-- Distance from the point to the nearest road's edge.
local function roadEdge(mapId: string, x: number, z: number): number
	local best = math.huge
	for _, road in Areas.byMap[mapId].roads do
		local p = road.points
		for i = 1, #p - 3, 2 do
			local ax, az, bx, bz = p[i], p[i + 1], p[i + 2], p[i + 3]
			local dx, dz = bx - ax, bz - az
			local l2 = dx * dx + dz * dz
			local t = if l2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / l2, 0, 1) else 0
			best = math.min(best, math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2) - road.width / 2)
		end
	end
	return best
end

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

T.describe("Elite II hideouts: data (S134i)", function()
	T.it("puts 2-3 hideouts on each of the four region maps (10-12), unique ids and names in both languages", function()
		local total = 0
		local seen: { [string]: boolean } = {}
		for _, mapId in REGIONS do
			local list = lairsOf(mapId)
			T.expect(`{mapId} {#list >= 2 and #list <= 3}`).toBe(`{mapId} true`)
			total += #list
			local areas: { [string]: boolean } = {}
			for _, lair in list do
				T.expect(seen[lair.id] == nil).toBe(true)
				seen[lair.id] = true
				T.expect(lair.nameKey).toBe(`lair.{lair.id}.name`)
				T.expect(pl[lair.nameKey] ~= nil and en[lair.nameKey] ~= nil).toBe(true)
				-- each in another area
				T.expect(areas[lair.area] == nil).toBe(true)
				areas[lair.area] = true
			end
		end
		T.expect(total >= 10 and total <= 12).toBe(true)
	end)

	T.it("sizes a hideout small, inside its area, levels and kinds of the area, a known theme and nodes", function()
		for _, mapId in REGIONS do
			for _, lair in lairsOf(mapId) do
				local at = `{mapId}/{lair.id}`
				local area = assert(areaOf(mapId, lair.area), at)
				T.expect(lair.r >= 18 and lair.r <= 26).toBe(true)
				local rect = area.rect
				T.expect(`{at} {lair.x >= rect[1] and lair.x <= rect[3] and lair.z >= rect[2] and lair.z <= rect[4]}`)
					.toBe(`{at} true`)
				-- 2-3 levels within the area's
				T.expect(lair.lv[2] - lair.lv[1] >= 1 and lair.lv[2] - lair.lv[1] <= 2).toBe(true)
				T.expect(`{at} {lair.lv[1] >= area.lv[1] and lair.lv[2] <= area.lv[2]}`).toBe(`{at} true`)
				-- the Elite II: a kind of the region with Elites and an Elite II name
				local def = assert(Monsters.get(lair.elite2), lair.elite2)
				T.expect(def.region).toBe(REGION_NUMBER[mapId])
				T.expect(def.elites).toBe(true)
				T.expect(pl[`monster.{lair.elite2}.elite2`] ~= nil and en[`monster.{lair.elite2}.elite2`] ~= nil)
					.toBe(true)
				-- guards: 1-2 normal kinds of the area, 2-3 groups
				T.expect(#lair.guards >= 1 and #lair.guards <= 2).toBe(true)
				for _, kind in lair.guards do
					T.expect(`{at} {kind} {table.find(area.kinds, kind) ~= nil}`).toBe(`{at} {kind} true`)
				end
				T.expect(lair.guardGroups >= 2 and lair.guardGroups <= 3).toBe(true)
				-- nodes: 2-3 gathering kinds of the region's level
				T.expect(#lair.nodes >= 2 and #lair.nodes <= 3).toBe(true)
				local map = assert(Maps.get(mapId))
				for _, kind in lair.nodes do
					local node = assert(GatherNodes.get(kind), kind)
					T.expect(`{kind} {node.level <= map.maxLevel}`).toBe(`{kind} true`)
				end
				T.expect(table.find(Lairs.THEMES, lair.theme) ~= nil).toBe(true)
			end
		end
	end)

	T.it("stands on dry, gentle ground in the whole circle", function()
		for _, mapId in REGIONS do
			for _, lair in lairsOf(mapId) do
				T.expect(`{lair.id} {MapTerrain.walkable(mapId, lair.x, lair.z, lair.r)}`).toBe(`{lair.id} true`)
				for dx = -lair.r, lair.r, 4 do
					for dz = -lair.r, lair.r, 4 do
						if dx * dx + dz * dz <= lair.r * lair.r then
							local ok = MapTerrain.walkable(mapId, lair.x + dx, lair.z + dz)
							T.expect(`{lair.id} {dx} {dz} {ok}`).toBe(`{lair.id} {dx} {dz} true`)
						end
					end
				end
			end
		end
	end)

	T.it("keeps away from other hideouts, caves, portals, roads, water and buildings, but near a road", function()
		for _, mapId in REGIONS do
			local data = Areas.byMap[mapId]
			for _, lair in lairsOf(mapId) do
				for _, other in lairsOf(mapId) do
					if other ~= lair then
						T.expect(dist(lair.x, lair.z, other.x, other.z) >= LAIR_SPACING).toBe(true)
					end
				end
				for _, cave in data.caves do
					T.expect(dist(lair.x, lair.z, cave.x, cave.z) >= LAIR_SPACING).toBe(true)
				end
				for _, portal in Portals.onMap(mapId) do
					T.expect(`{lair.id} {portal.id} {dist(lair.x, lair.z, portal.x, portal.z) >= LAIR_SPACING}`)
						.toBe(`{lair.id} {portal.id} true`)
				end
				local edge = roadEdge(mapId, lair.x, lair.z)
				T.expect(`{lair.id} {edge >= AreaSpawns.ROAD_CLEARANCE + lair.r and edge <= ROAD_REACH}`)
					.toBe(`{lair.id} true`)
				for _, lake in data.lakes do
					T.expect(dist(lair.x, lair.z, lake.x, lake.z) >= lake.r + AreaSpawns.WATER_CLEARANCE + lair.r)
						.toBe(true)
				end
				T.expect(AreaSpawns.nearStream(data.streams, lair.x, lair.z, AreaSpawns.STREAM_CLEARANCE + lair.r))
					.toBe(false)
				for _, c in data.avoid do
					T.expect(dist(lair.x, lair.z, c.x, c.z) >= c.r + lair.r).toBe(true)
				end
			end
		end
	end)
end)

T.describe("Elite II hideouts: spawners (S134i)", function()
	T.it("gives a hideout one Elite II in the middle and 2-3 guard groups on a ring (deterministic)", function()
		for _, mapId in REGIONS do
			for _, lair in lairsOf(mapId) do
				local list = AreaSpawns.lair(mapId, lair)
				T.expect(AreaSpawns.lair(mapId, lair)).toEqual(list)
				local boss = list[1]
				T.expect(boss.id).toBe(`{lair.id}_elite2`)
				T.expect(boss.variant).toBe("elite2")
				T.expect(boss.monster).toBe(lair.elite2)
				T.expect(boss.choices).toBeNil()
				T.expect(boss.count).toBe(1)
				T.expect(boss.radius).toBe(3)
				T.expect(boss.position.x).toBe(lair.x)
				T.expect(boss.position.z).toBe(lair.z)
				T.expect(boss.respawn).toEqual(AreaSpawns.elite2Respawn(lair.lv[2], Combat.lairElite2RespawnMul))
				T.expect(#list).toBe(1 + lair.guardGroups)
				local inner = math.max(0.55 * lair.r, AreaSpawns.LAIR_GUARD_GAP)
				for i, s in list do
					T.expect(s.lair).toBe(lair.id)
					T.expect(s.areaId).toBe(lair.id)
					T.expect(s.level.min >= lair.lv[1] and s.level.max <= lair.lv[2]).toBe(true)
					T.expect(
						`{s.id} {MapTerrain.walkable(mapId, s.position.x, s.position.z, AreaSpawns.CLIFF_CLEARANCE)}`
					)
						.toBe(`{s.id} true`)
					if i > 1 then
						T.expect(s.variant).toBe("normal")
						T.expect(s.count >= 1 and s.count <= 3).toBe(true)
						for _, kind in s.members or {} do
							T.expect(table.find(lair.guards, kind) ~= nil).toBe(true)
						end
						local d = dist(s.position.x, s.position.z, lair.x, lair.z)
						T.expect(`{s.id} {d >= inner - 1 and d <= 0.9 * lair.r + 1}`).toBe(`{s.id} true`)
						for k = i + 1, #list do
							local o = list[k]
							T.expect(
								dist(s.position.x, s.position.z, o.position.x, o.position.z)
									>= AreaSpawns.LAIR_GUARD_GAP - 1
							).toBe(true)
						end
					end
				end
			end
		end
	end)

	T.it("adds the hideouts' spawners to the region maps after the area groups", function()
		for _, mapId in REGIONS do
			local data = Areas.byMap[mapId]
			local groups = AreaSpawns.region(data, (Maps.get(mapId) :: any).size)
			local lairs = AreaSpawns.lairs(data)
			local all = Spawns.byMap[mapId]
			T.expect(#all).toBe(#groups + #lairs)
			for i, s in lairs do
				T.expect(all[#groups + i].id).toBe(s.id)
			end
		end
	end)

	T.it(
		"keeps the area groups, arrival points and world event points out of every hideout and its clearance",
		function()
			for _, mapId in REGIONS do
				local data = Areas.byMap[mapId]
				local circles = AreaSpawns.lairCircles(data)
				local function outside(what: string, x: number, z: number)
					for _, c in circles do
						if dist(x, z, c.x, c.z) < c.r then
							error(`{what} at {x}, {z} inside a hideout's clearance on {mapId}`, 0)
						end
					end
				end
				for _, g in AreaSpawns.region(data, (Maps.get(mapId) :: any).size) do
					outside(g.id, g.position.x, g.position.z)
				end
				local arrivals = AreaArrival.region(data, (Maps.get(mapId) :: any).size)
				for _, area in data.areas do
					local stored = assert(area.arrive, area.id)
					outside(`{area.id} arrival`, stored.x, stored.z)
					local p = arrivals[area.id]
					if p then
						outside(`{area.id} computed arrival`, p.x, p.z)
					end
					for _, point in WorldEvents.spawnPoints(mapId, area.id) do
						outside(`{area.id} event point`, point.x, point.z)
					end
				end
			end
		end
	)

	T.it("lets Auto Hunt start beside a hideout, never inside one", function()
		for _, mapId in REGIONS do
			local map = assert(Maps.get(mapId))
			for _, lair in lairsOf(mapId) do
				local wx, wz = lair.x + map.offset.x, lair.z + map.offset.z
				T.expect(AutoGrind.groundAt(mapId, wx, wz)).toBeNil()
				T.expect(AutoGrind.groundAt(mapId, wx + lair.r * 0.9, wz)).toBeNil()
				local area = AutoGrind.groundAt(mapId, wx + lair.r + 2, wz)
				T.expect(area).toBe(lair.area)
			end
		end
	end)
end)

T.describe("Elite II hideouts: dressing and nodes (S134i)", function()
	T.it("gives every hideout its nodes at the edge, no other node inside, 24 studs from any other node", function()
		for _, mapId in REGIONS do
			local data = Areas.byMap[mapId]
			local nodes = (WorldGen.get(mapId) :: any).nodes()
			for _, lair in lairsOf(mapId) do
				local own: { [string]: number } = {}
				for _, n in nodes do
					local d = dist(n.x, n.z, lair.x, lair.z)
					if d < lair.r + 6 then
						T.expect(`{lair.id} {n.kind} {table.find(lair.nodes, n.kind) ~= nil and d <= lair.r}`)
							.toBe(`{lair.id} {n.kind} true`)
						T.expect(MapTerrain.walkable(mapId, n.x, n.z)).toBe(true)
						own[n.kind] = (own[n.kind] or 0) + 1
					end
				end
				for _, kind in lair.nodes do
					T.expect(`{lair.id} {kind} {(own[kind] or 0) >= 1}`).toBe(`{lair.id} {kind} true`)
				end
			end
			for i, n in nodes do
				if Lairs.at(data, n.x, n.z) then
					for k, o in nodes do
						if k ~= i and dist(n.x, n.z, o.x, o.z) < Lairs.NODE_GAP then
							error(`{mapId}: hideout node {n.kind} {n.x}, {n.z} next to {o.kind} {o.x}, {o.z}`, 0)
						end
					end
				end
			end
		end
	end)

	T.it("builds one dressed Build per hideout with an empty middle, no rock or tree inside", function()
		for _, mapId in REGIONS do
			local gen = WorldGen.get(mapId) :: any
			local all = gen.all()
			for _, lair in lairsOf(mapId) do
				local found = 0
				for _, b in all do
					if b.name == `Lair_{lair.id}` then
						found += 1
						T.expect(b.tag).toBe("lair")
						T.expect(#b.bp.pieces >= 20).toBe(true)
						local c, s = math.cos(math.rad(b.at.rot)), math.sin(math.rad(b.at.rot))
						for _, piece in b.bp.pieces do
							local px = b.at.x + c * piece.p[1] + s * piece.p[3]
							local pz = b.at.z - s * piece.p[1] + c * piece.p[3]
							local d = dist(px, pz, lair.x, lair.z)
							if d < Lairs.FREE or d > lair.r + 3 then
								error(`{lair.id}: a piece at {d} studs from the middle`, 0)
							end
						end
					elseif b.tag == "rocks" then
						T.expect(dist(b.at.x, b.at.z, lair.x, lair.z) >= lair.r).toBe(true)
					end
				end
				T.expect(found).toBe(1)
				for _, tree in gen.trees() do
					if dist(tree.x, tree.z, lair.x, lair.z) < lair.r then
						error(`{lair.id}: a tree at {tree.x}, {tree.z}`, 0)
					end
				end
			end
		end
	end)
end)
