--!strict
-- S48: the cave engine, written for every map with an entry in Data/CaveShapes (S49-S51 only add entries): the frozen
-- room plans and spawners of all 12 caves (only the spawners' y may change), determinism, flat landing places with
-- headroom, spawners and ore nodes on walkable floor, the walk from the exit to every room and the gate and back,
-- cores dry, headroom over walkable floor, terrain materials, voxels, the outline, the arena contract, the dressing
-- (budget, nothing collidable in cores, by spawners or on the kept points, Builds on the floor), life and moods.

local fs = require("@lune/fs")

local Ambience = require("../src/shared/Data/Ambience")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local BossConsts = require("../tools/WikiData/Bosses")
local CaveDress = require("../src/shared/Logic/CaveDress")
local CaveGen = require("../src/shared/Logic/CaveGen")
local CaveShapes = require("../src/shared/Data/CaveShapes")
local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
local Fixture = require("./fixtures/caveRooms")
local ShapeFixture = require("./fixtures/caveShapes")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local Maps = require("../src/shared/Data/Maps")
local Portals = require("../src/shared/Data/Portals")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local Test = require("./Test")
local WorldGen = require("../src/shared/Logic/WorldGen")

local describe, it, expect = Test.describe, Test.it, Test.expect

local MAPS = CaveDress.maps()

-- Points that must be flat floor at y 0 with headroom: exits, gates, respawn points, the dungeon entrance and the
-- landing points in front of it, the chamber's respawn and landing line.
local function landings(mapId: string): { { name: string, x: number, z: number } }
	local list = {}
	for _, p in Portals.onMap(mapId) do
		table.insert(list, { name = `portal {p.id}`, x = p.x, z = p.z })
	end
	local map = assert(Maps.get(mapId))
	local e = map.dungeonEntrance
	if e then
		table.insert(list, { name = "dungeon entrance", x = e.x, z = e.z })
		for dx = 20, 24, 2 do
			table.insert(list, { name = `landing {dx}`, x = e.x - dx, z = e.z })
		end
	end
	if string.sub(mapId, 1, 8) == "dungeon_" then
		table.insert(list, { name = "respawn", x = 0, z = 60 })
		for x = -10, 10, 5 do
			table.insert(list, { name = `party {x}`, x = x, z = 55 })
		end
	else
		table.insert(list, { name = "spawn", x = map.spawn.x, z = map.spawn.z })
	end
	return list
end

describe("Cave engine: frozen plans", function()
	it("keeps the room plans of the generated caves and every cave spawner's x/z (only y may change)", function()
		for id, plan in Fixture.plans do
			local cave = assert(Areas.caves.get(id), id)
			local now = CaveGen.generate(assert(cave.seed, id))
			expect(#now.rooms).toBe(#plan.rooms)
			for i, r in plan.rooms do
				expect(math.abs(now.rooms[i].x - r[1]) < 1e-3 and math.abs(now.rooms[i].z - r[2]) < 1e-3).toBe(true)
				expect(now.rooms[i].r).toBe(r[3])
			end
			expect(#now.corridors).toBe(#plan.corridors)
		end
		local byId: { [string]: any } = {}
		for _, cave in Areas.caves.list do
			for _, s in AreaSpawns.cave(cave) do
				byId[s.id] = s
			end
		end
		local n = 0
		for _, f in Fixture.spawners do
			local s = byId[f[1]]
			if not s then
				error(`spawner {f[1]} is gone`)
			end
			n += 1
			expect(s.position.x).toBe(f[2])
			expect(s.position.z).toBe(f[3])
			expect(s.variant).toBe(f[4])
			expect(s.monster).toBe(f[5])
			expect(s.members).toEqual(f[6])
			expect(s.count).toBe(f[7])
			expect(s.radius).toBe(f[8])
		end
		local total = 0
		for _ in byId do
			total += 1
		end
		expect(total).toBe(n)
	end)
end)

describe("Cave engine: terrain", function()
	it("matches the frozen shapes (S49-S51 add maps without changing these)", function()
		for id, points in ShapeFixture :: { [string]: { { any } } } do
			local T = assert(CaveTerrain.get(id), id)
			for _, p in points do
				local c = T.column(p[1], p[2])
				expect(c.open).toBe(p[3] ~= false)
				if c.open then
					if math.abs(c.floor - p[3]) > 0.01 or math.abs(math.min(c.ceiling, 9999) - p[4]) > 0.01 then
						error(`{id} at {p[1]}, {p[2]}: floor {c.floor} / {p[3]}, ceiling {c.ceiling} / {p[4]}`)
					end
					expect(c.floorMat).toBe(p[6])
				end
				expect(c.liquid ~= nil).toBe(p[5] ~= false)
			end
		end
	end)

	it(
		"knows the caves on the engine (S48 the Meadows, S49 Duskwood, S50 the Ashen Wastes, S51 the Frost Peaks)",
		function()
			for _, id in { "dungeon_meadows", "meadows_burrow", "meadows_cave", "meadows_hideout" } do
				expect(table.find(MAPS, id) ~= nil).toBe(true)
			end
			-- S49: the caves of Duskwood and the Tomb of Morvane
			for _, id in { "duskwood_den", "duskwood_barrow", "duskwood_cave", "dungeon_duskwood" } do
				expect(table.find(MAPS, id) ~= nil).toBe(true)
			end
			-- S50: the caves of the Ashen Wastes and Azgor's Furnace
			for _, id in { "ashen_mine", "ashen_lair", "ashen_cave", "dungeon_ashen" } do
				expect(table.find(MAPS, id) ~= nil).toBe(true)
			end
			-- S51: the caves of the Frost Peaks and Vaelgrath's Lair
			for _, id in { "frostpeak_grotto", "frostpeak_hold", "frostpeak_cave", "dungeon_frostpeak" } do
				expect(table.find(MAPS, id) ~= nil).toBe(true)
			end
			expect(CaveTerrain.get("meadows")).toBe(nil)
			expect(MapTerrain.has("meadows_cave")).toBe(true)
			expect(RegionTerrain.get("meadows_cave")).toBe(nil)
		end
	)

	it("is deterministic and paints only terrain materials", function()
		for _, id in MAPS do
			local T = assert(CaveTerrain.get(id))
			for _, m in T.MATERIALS do
				expect(RegionTerrain.MATERIAL_SET[m]).toBe(true)
			end
			local shape = CaveShapes.byMap[id]
			expect(shape ~= nil).toBe(true)
			for x = -T.HALF, T.HALF, 37 do
				for z = -T.HALF, T.HALF, 41 do
					expect(T.floor(x, z)).toBe(T.floor(x, z))
					local m = T.material(x, 0, z)
					expect(RegionTerrain.MATERIAL_SET[m]).toBe(true)
				end
			end
		end
	end)

	it(
		"keeps exits, gates, respawns, the dungeon entrance and the landings flat at y 0 with 20+ studs of headroom",
		function()
			for _, id in MAPS do
				local T = assert(CaveTerrain.get(id))
				for _, p in landings(id) do
					local f = T.floor(p.x, p.z)
					if f == nil or math.abs(f) > 0.3 or T.headroom(p.x, p.z) < 20 then
						error(`{id} {p.name} at {p.x}, {p.z}: floor {f}, headroom {T.headroom(p.x, p.z)}`)
					end
					expect(T.walkable(p.x, p.z, 4)).toBe(true)
				end
			end
		end
	)

	it(
		"puts every spawner on walkable floor (radius + 2), 16+ studs of headroom, away from liquids, y = floor",
		function()
			for _, id in MAPS do
				local cave = Areas.caves.get(id)
				if cave then
					local T = assert(CaveTerrain.get(id))
					for _, s in AreaSpawns.cave(cave) do
						local x, z = s.position.x, s.position.z
						if not T.walkable(x, z, s.radius + 2) then
							error(`{s.id} at {x}, {z} not walkable`)
						end
						expect(T.headroom(x, z) >= 16).toBe(true)
						expect(math.abs(s.position.y - (T.floor(x, z) or 0)) <= 1).toBe(true)
						for dx = -(s.radius + 6), s.radius + 6, 3 do
							for dz = -(s.radius + 6), s.radius + 6, 3 do
								local l = T.liquid(x + dx, z + dz)
								if l and l.kind ~= "ice" then
									error(`{s.id} at {x}, {z} near a liquid`)
								end
							end
						end
					end
				end
			end
		end
	)

	it("keeps the cores of the fighting rooms dry and gentle with headroom", function()
		for _, id in MAPS do
			local T = assert(CaveTerrain.get(id))
			for i, r in T.rooms do
				if r.core > 0 then
					for a = 0, 7 do
						for _, f in { 0, 0.5, 0.95 } do
							local x = r.x + math.cos(a * math.pi / 4) * r.core * f
							local z = r.z + math.sin(a * math.pi / 4) * r.core * f
							if T.liquid(x, z) or not T.walkable(x, z, 2) then
								error(`{id} room {i} core not dry and walkable at {math.floor(x)}, {math.floor(z)}`)
							end
						end
					end
				end
			end
		end
	end)

	it("lets a player walk from the exit to every room and the gate, and back from everywhere reached", function()
		for _, id in MAPS do
			local T = assert(CaveTerrain.get(id))
			local STEP = 4
			local N = math.floor(T.HALF * 2 / STEP)
			local function key(i: number, k: number): number
				return i * (N + 1) + k
			end
			local floor: { [number]: number } = {}
			for i = 0, N do
				for k = 0, N do
					local x, z = -T.HALF + i * STEP, -T.HALF + k * STEP
					local c = T.column(x, z)
					if c.open and c.ceiling - c.floor >= 6 then
						local f = c.floor
						if c.liquid and c.liquid.kind == "water" then
							f = math.max(f, c.liquid.level)
						end
						floor[key(i, k)] = f
					end
				end
			end
			local function cell(x: number, z: number): (number, number)
				return math.floor((x + T.HALF) / STEP + 0.5), math.floor((z + T.HALF) / STEP + 0.5)
			end
			local start = landings(id)[1]
			local si, sk = cell(start.x, start.z)
			local seen: { [number]: boolean } = { [key(si, sk)] = true }
			local queue = { { si, sk } }
			local head = 1
			while head <= #queue do
				local c = queue[head]
				head += 1
				local h = floor[key(c[1], c[2])]
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local ni, nk = c[1] + d[1], c[2] + d[2]
					local nkey = key(ni, nk)
					local nh = floor[nkey]
					if nh and not seen[nkey] and nh - h <= 2 then
						seen[nkey] = true
						table.insert(queue, { ni, nk })
					end
				end
			end
			-- back: from every reached cell to the exit, climbing at most 2 studs per step (reverse search)
			local back: { [number]: boolean } = { [key(si, sk)] = true }
			queue = { { si, sk } }
			head = 1
			while head <= #queue do
				local c = queue[head]
				head += 1
				local h = floor[key(c[1], c[2])]
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local ni, nk = c[1] + d[1], c[2] + d[2]
					local nkey = key(ni, nk)
					local nh = floor[nkey]
					-- the player steps from (ni, nk) to c: a climb of h - nh
					if nh and not back[nkey] and h - nh <= 2 then
						back[nkey] = true
						table.insert(queue, { ni, nk })
					end
				end
			end
			for nkey in seen do
				if not back[nkey] then
					local i, k = nkey // (N + 1), nkey % (N + 1)
					error(`{id}: no way back from {-T.HALF + i * STEP}, {-T.HALF + k * STEP}`)
				end
			end
			local targets = landings(id)
			for i, r in T.rooms do
				if r.role ~= "gallery" and r.role ~= "niche" then
					table.insert(targets, { name = `room {i} {r.role}`, x = r.x, z = r.z })
				end
			end
			for _, t in targets do
				local ti, tk = cell(t.x, t.z)
				local ok = false
				for di = -2, 2 do
					for dk = -2, 2 do
						if seen[key(ti + di, tk + dk)] then
							ok = true
						end
					end
				end
				if not ok then
					error(`{id}: {t.name} at {t.x}, {t.z} cannot be reached from the exit`)
				end
			end
		end
	end)

	it("has headroom of 10+ studs over walkable floor, writes known voxels and an outline over the floor", function()
		for _, id in MAPS do
			local T = assert(CaveTerrain.get(id))
			for x = -T.HALF + 6, T.HALF - 6, 23 do
				for z = -T.HALF + 6, T.HALF - 6, 19 do
					if T.walkable(x, z, 1) then
						expect(T.headroom(x, z) >= 10).toBe(true)
					end
				end
			end
			local ny = (T.TOP - T.BOTTOM) // 4
			local vox = T.voxels(-40, -16, 8, 8, T.BOTTOM, ny)
			local known: { [string]: boolean } = {}
			for _, m in T.MATERIALS do
				known[m] = true
			end
			for i = 1, 8 do
				for j = 1, ny do
					for k = 1, 8 do
						expect(known[vox.materials[i][j][k]]).toBe(true)
					end
				end
			end
			local rects = T.outline(8)
			local inside, total = 0, 0
			for _, r in rects do
				local c = T.column(r.x, r.z)
				total += 1
				if c.open then
					inside += 1
				end
			end
			expect(total > 0 and inside / total >= 0.85).toBe(true)
		end
	end)

	it(
		"keeps the arena contract: flat floor of radius 74 round (0, -10), nothing collidable within 50, lanes free",
		function()
			for _, id in MAPS do
				local shape = CaveShapes.byMap[id]
				if shape.arena then
					local T = assert(CaveTerrain.get(id))
					for r = 0, 74, 6 do
						for a = 0, 15 do
							local x, z = math.cos(a * math.pi / 8) * r, -10 + math.sin(a * math.pi / 8) * r
							local f = T.floor(x, z)
							if f == nil or math.abs(f) > 0.25 then
								error(`{id}: arena floor {f} at {math.floor(x)}, {math.floor(z)}`)
							end
						end
					end
					for _, b in CaveDress.all(id) do
						local rot = math.rad(b.at.rot)
						for _, p in b.bp.pieces do
							if p.lod == "shell" and p.col then
								local lx, lz = p.p[1], p.p[3]
								local x = b.at.x + math.cos(rot) * lx + math.sin(rot) * lz
								local z = b.at.z - math.sin(rot) * lx + math.cos(rot) * lz
								if math.sqrt(x * x + (z + 10) ^ 2) < 50 then
									error(`{id}: {b.name} collides within 50 studs of the fight`)
								end
								expect(math.abs(x) < 14 and z > -10 and z < 80).toBe(false)
							end
						end
					end
					-- the summons ring 14 studs from the centre
					for a = 0, 3 do
						expect(T.walkable(math.cos(a * math.pi / 2) * 14, -10 + math.sin(a * math.pi / 2) * 14, 3)).toBe(
							true
						)
					end
				end
			end
		end
	)
end)

describe("Cave engine: dressing", function()
	it("registers every cave on the engine in WorldGen and stays in the part budget", function()
		for _, id in MAPS do
			local gen = assert(WorldGen.get(id), id)
			local c = gen.counts()
			local map = assert(Maps.get(id))
			if c.shell + 120 > assert(map.maxParts, `{id} maxParts`) then
				error(`{id}: shell {c.shell} + 120 > {map.maxParts}`)
			end
			expect(c.detail >= c.shell).toBe(true)
			expect(#gen.trees()).toBe(0)
		end
	end)

	it(
		"keeps collidable props out of cores, clear of spawners (radius + 4) and of the kept points; Builds on the floor",
		function()
			for _, id in MAPS do
				local T = assert(CaveTerrain.get(id))
				local cave = Areas.caves.get(id)
				local spawners = if cave then AreaSpawns.cave(cave) else {}
				local keep = landings(id)
				for _, b in CaveDress.all(id) do
					local f = T.floor(b.at.x, b.at.z)
					if b.tag ~= "bridge" and (f == nil or math.abs(b.at.y - f) > 6) then
						error(`{id}: {b.name} off the floor ({f})`)
					end
					local rot = math.rad(b.at.rot)
					for _, p in b.bp.pieces do
						if p.lod == "shell" and p.col then
							local lx, lz = p.p[1], p.p[3]
							local x = b.at.x + math.cos(rot) * lx + math.sin(rot) * lz
							local z = b.at.z - math.sin(rot) * lx + math.cos(rot) * lz
							if T.inCore(x, z) then
								error(`{id}: {b.name} collides in a core at {math.floor(x)}, {math.floor(z)}`)
							end
							for _, s in spawners do
								if (x - s.position.x) ^ 2 + (z - s.position.z) ^ 2 < (s.radius + 4) ^ 2 then
									error(`{id}: {b.name} by spawner {s.id}`)
								end
							end
							for _, k in keep do
								if (x - k.x) ^ 2 + (z - k.z) ^ 2 < 36 then
									error(`{id}: {b.name} on {k.name}`)
								end
							end
						end
					end
				end
			end
		end
	)

	it("puts the ore nodes on the floor with headroom, gives life points and moods for every room", function()
		for _, id in MAPS do
			local T = assert(CaveTerrain.get(id))
			local cave = Areas.caves.get(id)
			local nodes = CaveDress.nodes(id)
			if cave then
				expect(#nodes).toBe(cave.oreCount)
			end
			for _, n in nodes do
				expect(T.floor(n.x, n.z) ~= nil and T.headroom(n.x, n.z) >= 16).toBe(true)
			end
			local kinds: { [string]: boolean } = {}
			for _, l in CaveDress.life(id) do
				kinds[l.kind] = true
			end
			expect(kinds.drips).toBe(true)
			local map = assert(Maps.get(id))
			expect(map.lighting ~= nil).toBe(true)
			expect(Ambience.moodOf(id, nil) ~= nil).toBe(true)
			local rooms = Ambience.rooms[id]
			expect(rooms ~= nil).toBe(true)
			for i, r in T.rooms do
				if r.role ~= "niche" then
					local mood = (rooms :: any)[i]
					if not mood then
						error(`{id}: no mood for room {i}`)
					end
					for _, s in mood.sounds.day do
						expect(s.id).toBe("")
						expect(#s.hint > 10).toBe(true)
					end
				end
			end
		end
		local grotto: { [string]: boolean } = {}
		for _, l in CaveDress.life("meadows_cave") do
			grotto[l.kind] = true
		end
		for _, k in { "glowworms", "dustBeam", "bats", "spiders", "mist" } do
			if not grotto[k] then
				error(`Mosshollow: no life {k}`)
			end
		end
	end)

	it("finds the room under a point (centres) and nothing in the rock", function()
		local T = assert(CaveTerrain.get("meadows_cave"))
		for i, r in T.rooms do
			if r.role ~= "niche" then
				expect(T.roomAt(r.x, r.z)).toBe(i)
			end
		end
		expect(T.roomAt(300, 300)).toBe(nil)
		expect(CaveTerrain.roomAt("meadows_cave", -30, 0)).toBe(2)
	end)
end)

-- S50: lava (decoration) in the engine: its rules for every map with lava, bridges, Azgor's Furnace.
local function lavaMaps(): { string }
	local list = {}
	for _, id in MAPS do
		for _, f in CaveShapes.byMap[id].features do
			if f.liquid == "lava" or f.kind == "vent" or f.kind == "crack" or f.kind == "moat" then
				table.insert(list, id)
				break
			end
		end
	end
	return list
end

-- Tunnel edges and the routes in the rooms (from each tunnel's end to the centre of its room) of a map.
local function routes(
	id: string,
	T: CaveTerrain.Cave
): { { ax: number, az: number, bx: number, bz: number, w: number } }
	local list = {}
	local cave = Areas.caves.get(id)
	local tunnels: { any } = {}
	if cave and cave.seed then
		for _, c in CaveGen.generate(cave.seed).corridors do
			table.insert(tunnels, c)
		end
	end
	for _, t in CaveShapes.byMap[id].tunnels or {} do
		table.insert(tunnels, t)
	end
	for _, t in tunnels do
		table.insert(list, { ax = t.ax, az = t.az, bx = t.bx, bz = t.bz, w = t.w })
		for _, e in { { t.ax, t.az }, { t.bx, t.bz } } do
			local i = T.roomAt(e[1], e[2])
			if i then
				local r = T.rooms[i]
				table.insert(list, { ax = e[1], az = e[2], bx = r.x, bz = r.z, w = 0 })
			end
		end
	end
	return list
end

local function segDist(ax: number, az: number, bx: number, bz: number, x: number, z: number): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) else 0
	return math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2)
end

describe("Cave engine: lava (S50)", function()
	it("has the Ashen Wastes' caves with lava", function()
		local list = lavaMaps()
		for _, id in { "ashen_mine", "ashen_lair", "ashen_cave", "dungeon_ashen" } do
			expect(table.find(list, id) ~= nil).toBe(true)
		end
	end)

	it("keeps lava away from spawners, cores, tunnels, routes, the kept points and ore nodes", function()
		for _, id in lavaMaps() do
			local T = assert(CaveTerrain.get(id))
			local cave = Areas.caves.get(id)
			local spawners = if cave then AreaSpawns.cave(cave) else {}
			local keep = landings(id)
			local nodes = CaveDress.nodes(id)
			local lanes = routes(id, T)
			local bridges = {}
			for _, f in CaveShapes.byMap[id].features do
				if f.kind == "bridge" then
					table.insert(bridges, f)
				end
			end
			local n = 0
			for x = -T.HALF, T.HALF, 3 do
				for z = -T.HALF, T.HALF, 3 do
					local l = T.liquid(x, z)
					if l and l.kind == "lava" then
						n += 1
						if T.inCore(x, z) then
							error(`{id}: lava in a core at {x}, {z}`)
						end
						for _, sp in spawners do
							local d = math.sqrt((x - sp.position.x) ^ 2 + (z - sp.position.z) ^ 2)
							if d < sp.radius + 6 then
								error(`{id}: lava at {x}, {z} by spawner {sp.id}`)
							end
						end
						for _, k in keep do
							if (x - k.x) ^ 2 + (z - k.z) ^ 2 < 36 then
								error(`{id}: lava at {x}, {z} on {k.name}`)
							end
						end
						for _, nd in nodes do
							if (x - nd.x) ^ 2 + (z - nd.z) ^ 2 < 36 then
								error(`{id}: lava at {x}, {z} by an ore node`)
							end
						end
						local byBridge = false
						for _, b in bridges do
							if segDist(b.ax, b.az, b.bx, b.bz, x, z) < 30 then
								byBridge = true
							end
						end
						if not byBridge then
							for _, t in lanes do
								if segDist(t.ax, t.az, t.bx, t.bz, x, z) < t.w / 2 + 6 then
									error(`{id}: lava at {x}, {z} within 6 studs of a tunnel or a route`)
								end
							end
						end
						expect(T.walkable(x, z)).toBe(false)
						expect(MapTerrain.water(id, x, z)).toBe(nil)
						expect(MapTerrain.walkable(id, x, z, 2)).toBe(false)
						expect(T.lavaDistance(x, z) <= 3).toBe(true)
					end
				end
			end
			expect(n > 0).toBe(true)
		end
	end)

	it("lays the lava's surface 0.4-2.6 studs under the dry floor beside it, solid CrackedLava, never Water", function()
		for _, id in lavaMaps() do
			local T = assert(CaveTerrain.get(id))
			local probe: { number }? = nil
			-- glowing cracks and vents follow the floor's slope (they are only a little sunk)
			local function fissure(x: number, z: number): boolean
				for _, f in CaveShapes.byMap[id].features do
					if f.kind == "vent" and (x - f.x) ^ 2 + (z - f.z) ^ 2 < (f.r + 1) ^ 2 then
						return true
					elseif f.kind == "crack" then
						local p = f.points
						for k = 1, #p - 3, 2 do
							if segDist(p[k], p[k + 1], p[k + 2], p[k + 3], x, z) < f.width / 2 + 1 then
								return true
							end
						end
					end
				end
				return false
			end
			-- the decks of the bridges stand high over the lava beside them
			local function onBridge(x: number, z: number): boolean
				for _, f in CaveShapes.byMap[id].features do
					if f.kind == "bridge" and segDist(f.ax, f.az, f.bx, f.bz, x, z) < f.width / 2 + 1 then
						return true
					end
				end
				return false
			end
			for x = -T.HALF, T.HALF, 2 do
				for z = -T.HALF, T.HALF, 2 do
					local l = T.liquid(x, z)
					if l and l.kind == "lava" then
						expect(T.column(x, z).floorMat).toBe("CrackedLava")
						for _, d in if fissure(x, z) then {} else { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } } do
							local c = T.column(x + d[1], z + d[2])
							if c.open and c.liquid == nil and not onBridge(x + d[1], z + d[2]) then
								local drop = c.floor - l.level
								if drop < 0.4 or drop > 2.6 then
									error(`{id}: lava at {x}, {z} lies {drop} under the floor beside it`)
								end
							end
						end
						probe = probe or { x, z }
					end
				end
			end
			local p = assert(probe, id)
			local V = T.VOXEL
			local x0 = math.floor(p[1] / V) * V - V * 4
			local z0 = math.floor(p[2] / V) * V - V * 4
			local ny = (T.TOP - T.BOTTOM) // V
			local vox = T.voxels(x0, z0, 8, 8, T.BOTTOM, ny)
			local lava = 0
			for i = 1, 8 do
				for j = 1, ny do
					for k = 1, 8 do
						local m = vox.materials[i][j][k]
						expect(m == "Water").toBe(false)
						if m == "CrackedLava" then
							lava += 1
						end
					end
				end
			end
			expect(lava > 0).toBe(true)
		end
	end)

	it("lays every bridge as a continuous floor with lava on both sides", function()
		for _, id in lavaMaps() do
			local T = assert(CaveTerrain.get(id))
			for _, f in CaveShapes.byMap[id].features do
				if f.kind == "bridge" then
					local len = math.sqrt((f.bx - f.ax) ^ 2 + (f.bz - f.az) ^ 2)
					local ux, uz = (f.bx - f.ax) / len, (f.bz - f.az) / len
					local last: number? = nil
					local both = false
					local s = 2
					while s < len - 2 do
						local x, z = f.ax + ux * s, f.az + uz * s
						local fl = T.floor(x, z)
						if fl == nil or T.liquid(x, z) ~= nil then
							error(`{id}: bridge broken at {x}, {z}`)
						end
						if last and math.abs(fl - last) > 2 then
							error(`{id}: bridge steps at {x}, {z}`)
						end
						last = fl
						local off = f.width / 2 + 3
						local l1 = T.liquid(x - uz * off, z + ux * off)
						local l2 = T.liquid(x + uz * off, z - ux * off)
						if l1 and l2 and l1.kind == "lava" and l2.kind == "lava" then
							both = true
						end
						s += 2
					end
					expect(both).toBe(true)
				end
			end
		end
	end)

	it(
		"keeps Azgor's Furnace: flat to his burning ring, no liquid within 80, nothing standing in the circle",
		function()
			local consts = BossConsts.scriptConsts(fs.readFile("src/server/Entities/BossScripts/azgor.luau"))
			local lavaR = assert(consts.LAVA_RADIUS, "LAVA_RADIUS")
			expect(lavaR).toBe(64)
			local shape = CaveShapes.byMap.dungeon_ashen
			local arena = assert(shape.arena, "arena")
			expect(lavaR + 10 <= arena.r).toBe(true)
			local T = assert(CaveTerrain.get("dungeon_ashen"))
			for r = 0, 80, 4 do
				for a = 0, 35 do
					local x, z = math.cos(a * math.pi / 18) * r, -10 + math.sin(a * math.pi / 18) * r
					if T.liquid(x, z) then
						error(`Furnace: liquid at {math.floor(x)}, {math.floor(z)}`)
					end
					if r <= lavaR + 10 then
						local f = T.floor(x, z)
						if f == nil or math.abs(f) > 0.25 then
							error(`Furnace: floor {f} at {math.floor(x)}, {math.floor(z)}`)
						end
					end
				end
			end
			for _, b in CaveDress.all("dungeon_ashen") do
				local rot = math.rad(b.at.rot)
				for _, p in b.bp.pieces do
					local lx, lz = p.p[1], p.p[3]
					local x = b.at.x + math.cos(rot) * lx + math.sin(rot) * lz
					local z = b.at.z - math.sin(rot) * lx + math.cos(rot) * lz
					local d = math.sqrt(x * x + (z + 10) ^ 2)
					if p.lod == "shell" and p.col and d < 75 then
						error(`Furnace: {b.name} collides within 75 studs of the fight`)
					end
					if d < arena.r and b.at.y + p.p[2] + p.size[2] / 2 > 0.15 then
						error(`Furnace: {b.name} stands in the circle at {math.floor(x)}, {math.floor(z)}`)
					end
				end
			end
			local spots = { { 0, 70 }, { 0, 78 }, { 0, 60 }, { -10, 55 }, { 0, 55 }, { 10, 55 } }
			for a = 0, 3 do
				table.insert(spots, { math.cos(a * math.pi / 2) * 14, -10 + math.sin(a * math.pi / 2) * 14 })
			end
			for _, sp in spots do
				expect(T.walkable(sp[1], sp[2], 3)).toBe(true)
				expect(T.lavaDistance(sp[1], sp[2]) >= 6).toBe(true)
			end
		end
	)

	it(
		"gives the Forge embers, steam and sparks, the Mine and the Lair ash in the shafts' beams, the Lair sand",
		function()
			local function kinds(id: string): { [string]: boolean }
				local out = {}
				for _, l in CaveDress.life(id) do
					out[l.kind] = true
				end
				return out
			end
			local forge = kinds("ashen_cave")
			for _, k in { "embers", "steam", "sparks", "haze" } do
				expect(forge[k]).toBe(true)
			end
			local mine = kinds("ashen_mine")
			for _, k in { "ashBeam", "vultures", "vulturePerch", "bats" } do
				expect(mine[k]).toBe(true)
			end
			local lair = kinds("ashen_lair")
			for _, k in { "ashBeam", "sandfall", "embers" } do
				expect(lair[k]).toBe(true)
			end
		end
	)
end)

-- S51: ice, the Frost Peaks' scenes, Vaelgrath's braziers, the whole series on the engine.
local function bracesPoints(text: string, name: string): { { number } }
	local body = assert(string.match(text, "local " .. name .. " = (%b{})"), name)
	local out = {}
	for a, b, c in string.gmatch(body, "Vector3%.new%(([%-%d%.]+), ([%-%d%.]+), ([%-%d%.]+)%)") do
		table.insert(out, { tonumber(a) :: number, tonumber(c) :: number })
		local _ = b
	end
	if #out == 0 then
		for a, b in string.gmatch(body, "{ ([%-%d%.]+), ([%-%d%.]+) }") do
			table.insert(out, { tonumber(a) :: number, tonumber(b) :: number })
		end
	end
	return out
end

describe("Cave engine: ice and the Frost Peaks (S51)", function()
	it("makes frozen pools and icefalls walkable ice; only water keeps spawners away", function()
		for _, id in { "frostpeak_grotto", "frostpeak_cave" } do
			local T = assert(CaveTerrain.get(id))
			local n = 0
			for _, f in T.icefalls() do
				n += 1
				local l = T.liquid(f.x, f.z)
				expect(l ~= nil and l.kind == "ice").toBe(true)
				expect(T.column(f.x, f.z).floorMat).toBe("Ice")
				expect(T.walkable(f.x, f.z, 1)).toBe(true)
			end
			expect(n > 0).toBe(true)
		end
		local G = assert(CaveTerrain.get("frostpeak_grotto"))
		local hole = G.liquid(-90, -42)
		expect(hole ~= nil and hole.kind == "water").toBe(true)
	end)

	it(
		"keeps the Grotto: the chimney open to the sky, the King's Den above the Chimney, the nests out of reach",
		function()
			local T = assert(CaveTerrain.get("frostpeak_grotto"))
			expect(T.ceiling(20, 80) or 0).toBe(1e4)
			local r3, r4 = T.rooms[3], T.rooms[4]
			expect((T.floor(r4.x, r4.z) or 0) >= (T.floor(r3.x, r3.z) or 0) + 3).toBe(true)
			for _, p in { { -29, 59 }, { 68, 74 }, { 50, 95 } } do
				local top = T.floor(p[1], p[2])
				if top then
					expect(top >= (T.floor(r3.x, r3.z) or 0) + 8).toBe(true)
				end
			end
		end
	)

	it("keeps the Hold's tunnels 20+ studs high and its halls architectural", function()
		local shape = CaveShapes.byMap.frostpeak_hold
		expect(shape.masonry).toBe(true)
		expect((shape.tunnelH or 0) >= 20).toBe(true)
		for _, r in shape.rooms or {} do
			expect(r.plan == "rect" or r.plan == "octagon").toBe(true)
			expect((r.h or 0) >= 24).toBe(true)
		end
	end)

	it(
		"keeps the Heart's Dragon's Way free from the respawn to the gate, the skull's passage open, the beat in budget",
		function()
			local T = assert(CaveTerrain.get("frostpeak_cave"))
			for _, b in CaveDress.all("frostpeak_cave") do
				local rot = math.rad(b.at.rot)
				for _, p in b.bp.pieces do
					if p.lod == "shell" and p.col then
						local lx, lz = p.p[1], p.p[3]
						local x = b.at.x + math.cos(rot) * lx + math.sin(rot) * lz
						local z = b.at.z - math.sin(rot) * lx + math.cos(rot) * lz
						if x > -240 and x < 284 and math.abs(z) < 9 then
							error(`Heart: {b.name} collides on the Dragon's Way at {math.floor(x)}, {math.floor(z)}`)
						end
					end
				end
			end
			for x = 150, 170, 4 do
				for _, z in { -6, 0, 6 } do
					expect(T.headroom(x, z) >= 18).toBe(true)
					expect(T.walkable(x, z, 1)).toBe(true)
				end
			end
			local parts, lights = 0, 0
			for _, b in CaveDress.all("frostpeak_cave") do
				for _, p in b.bp.pieces do
					if p.tag == "heart" then
						parts += 1
					end
				end
				for _, l in b.bp.lights do
					if l.tag == "heart" then
						lights += 1
					end
				end
			end
			expect(parts > 0 and parts <= 60).toBe(true)
			expect(lights > 0 and lights <= 12).toBe(true)
		end
	)

	it(
		"keeps Vaelgrath's Lair: the braziers of the layout, the script and the shape agree, warm discs, a high dome",
		function()
			local layout = bracesPoints(fs.readFile("src/server/World/Layouts/dungeon_frostpeak.luau"), "BRAZIERS")
			local scriptText = fs.readFile("src/server/Entities/BossScripts/vaelgrath.luau")
			local script = bracesPoints(scriptText, "BRAZIERS")
			local shape = CaveShapes.byMap.dungeon_frostpeak
			local data = assert(shape.braziers, "braziers")
			expect(#layout).toBe(4)
			expect(#script).toBe(4)
			expect(#data).toBe(4)
			for i = 1, 4 do
				expect(script[i][1] + 0).toBe(layout[i][1])
				expect(script[i][2] - 10).toBe(layout[i][2])
				expect(data[i][1]).toBe(layout[i][1])
				expect(data[i][2]).toBe(layout[i][2])
			end
			local warm = assert(BossConsts.scriptConsts(scriptText).WARM_RADIUS, "WARM_RADIUS")
			local T = assert(CaveTerrain.get("dungeon_frostpeak"))
			local discs = 0
			for _, b in CaveDress.all("dungeon_frostpeak") do
				local rot = math.rad(b.at.rot)
				for _, p in b.bp.pieces do
					local lx, lz = p.p[1], p.p[3]
					local x = b.at.x + math.cos(rot) * lx + math.sin(rot) * lz
					local z = b.at.z - math.sin(rot) * lx + math.cos(rot) * lz
					if p.lod == "shell" and p.col and math.sqrt(x * x + (z + 10) ^ 2) < 50 then
						error(`Lair: {b.name} collides within 50 studs of the fight`)
					end
					if p.s == "cyl" and math.abs(p.size[2] - warm * 2) < 0.01 then
						discs += 1
						expect(p.size[1] <= 0.2).toBe(true)
					end
				end
			end
			expect(discs).toBe(4)
			for r = 0, 62, 8 do
				for a = 0, 7 do
					local x, z = math.cos(a * math.pi / 4) * r, -10 + math.sin(a * math.pi / 4) * r
					expect(T.headroom(x, z) >= 40).toBe(true)
				end
			end
			for _, p in data do
				expect(T.walkable(p[1], p[2], 3)).toBe(true)
			end
		end
	)

	it(
		"has every cave and boss chamber on the engine with its own preset and moods (the series is complete)",
		function()
			local PENDING: { string } = {} -- maps still on the old generator (empty: S48-S51 done)
			for id, map in Maps.byId do
				if map.biome == "cave" or map.biome == "crypt" or map.biome == "dungeon" then
					if not table.find(PENDING, id) then
						if not CaveShapes.byMap[id] then
							error(`{id} is not on the cave engine`)
						end
					end
					if map.lighting == nil then
						error(`{id} has no preset`)
					end
					expect(Ambience.maps[id] ~= nil).toBe(true)
				end
			end
		end
	)
end)
