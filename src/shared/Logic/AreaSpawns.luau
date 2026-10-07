--!strict
-- Monster groups from named areas (S19, DESIGN §3.5, §3.6, §15.1). Pure and deterministic (seed = area /
-- cave id), so the server, the tests and the map all see the same groups.
--   * region maps: `groups` groups of 1–4 per area (30 / 30 / 25 / 15 %), 45+ studs apart, away from
--     roads, water (lakes and, S26, streams), portals, spawn points and cave entrances, and on maps with a height
--     function (Logic/MapTerrain) only on dry, gentle ground with the spawner at the ground's height;
--     members mix the area's kinds; S33: an area with a profile (Data/AreaProfiles) gets its own group sizes and
--     respawn: the same roll read on the profile's size weights (a fast-EXP group is never smaller, a better-drop
--     group never bigger than without the profile), extra members from a second generator, so the group
--     positions (and the `arrive` points) never move;
--   * caves: normal groups in every room but the entrance (and the boss antechamber), 3–5 elite groups of
--     1–2 of the two elite kinds, one Elite II spawner in the deepest room.

local AreaProfiles = require("../Data/AreaProfiles")
local AreaTypes = require("../Data/Areas/Types")
local CaveGen = require("./CaveGen")
local MapTerrain = require("./MapTerrain")
local Monsters = require("../Data/Monsters")
local Rng = require("./Rng")
local SpawnTypes = require("../Data/Spawns/Types")

type Spawner = SpawnTypes.Spawner

local AreaSpawns = {}

AreaSpawns.GROUP_SIZE_WEIGHTS = { [1] = 30, [2] = 30, [3] = 25, [4] = 15 }
AreaSpawns.MIN_GROUP_DISTANCE = 45
AreaSpawns.MIN_CAVE_GROUP_DISTANCE = 16
AreaSpawns.ROAD_CLEARANCE = 14
AreaSpawns.WATER_CLEARANCE = 16
AreaSpawns.CAVE_CLEARANCE = 45
AreaSpawns.STREAM_CLEARANCE = 12 -- from a stream's water edge (S26)
AreaSpawns.CLIFF_CLEARANCE = 10 -- radius of gentle, dry ground around a group (S26, maps with a height function)
AreaSpawns.EDGE = 40
AreaSpawns.RESPAWN = { min = 30, max = 45 }
AreaSpawns.ELITE_RESPAWN = { min = 90, max = 150 }
AreaSpawns.ELITE2_RESPAWN = { min = 600, max = 1200 }

local function seedOf(text: string): number
	local seed = 7
	for i = 1, #text do
		seed = (seed * 31 + string.byte(text, i)) % 2147483647
	end
	return seed
end

-- Distance from a point to a segment.
local function segmentDistance(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local lengthSq = dx * dx + dz * dz
	local t = if lengthSq > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSq, 0, 1) else 0
	local cx, cz = ax + dx * t, az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

function AreaSpawns.nearRoad(roads: { AreaTypes.Road }, x: number, z: number, clearance: number): boolean
	for _, road in roads do
		local p = road.points
		for i = 1, #p - 3, 2 do
			if segmentDistance(x, z, p[i], p[i + 1], p[i + 2], p[i + 3]) < road.width / 2 + clearance then
				return true
			end
		end
	end
	return false
end

-- Within `clearance` studs of a stream's water (S26); the widest width of a segment counts.
function AreaSpawns.nearStream(streams: { AreaTypes.Stream }?, x: number, z: number, clearance: number): boolean
	for _, stream in (streams or {}) :: { AreaTypes.Stream } do
		local p, widths = stream.points, stream.widths
		for i = 1, #p - 3, 2 do
			local k = (i + 1) // 2
			local half = math.max(widths[k] or 0, widths[k + 1] or 0) / 2
			if segmentDistance(x, z, p[i], p[i + 1], p[i + 2], p[i + 3]) < half + clearance then
				return true
			end
		end
	end
	return false
end

local function inCircles(circles: { AreaTypes.Circle }, x: number, z: number, extra: number): boolean
	for _, c in circles do
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 < (c.r + extra) ^ 2 then
			return true
		end
	end
	return false
end

local function farFrom(points: { { number } }, x: number, z: number, distance: number): boolean
	for _, p in points do
		if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < distance * distance then
			return false
		end
	end
	return true
end

-- Key of { [key] = weight } at quantile `u` (0..1), in the order Rng.weighted uses (Rng.weighted = this with
-- rng:next()).
local function weightedAt<K>(weights: { [K]: number }, u: number): K
	local keys: { K } = {}
	local total = 0
	for key, weight in weights do
		if weight > 0 then
			table.insert(keys, key)
			total += weight
		end
	end
	table.sort(keys, function(a: any, b: any)
		return tostring(a) < tostring(b)
	end)
	local roll = u * total
	for _, key in keys do
		roll -= weights[key]
		if roll < 0 then
			return key
		end
	end
	return keys[#keys]
end

-- Members: the first kind is the group's main kind; the others repeat it 65 % of the time.
local function members(kinds: { string }, count: number, rng: Rng.Rng): { string }
	local main = rng:pick(kinds)
	local list = { main }
	for _ = 2, count do
		table.insert(list, if #kinds > 1 and not rng:chance(0.65) then rng:pick(kinds) else main)
	end
	return list
end

-- Level range of a group: the area range narrowed to what its members naturally have (when they overlap).
local function levelRange(range: { number }, kinds: { string }): { min: number, max: number }
	local low, high = math.huge, -math.huge
	for _, id in kinds do
		local def = Monsters.get(id)
		if def then
			low = math.min(low, def.levels.min)
			high = math.max(high, def.levels.max)
		end
	end
	local min, max = math.max(range[1], low), math.min(range[2], high)
	if min > max then
		return { min = range[1], max = range[2] }
	end
	return { min = min, max = max }
end

-- Groups of a region map.
function AreaSpawns.region(def: AreaTypes.MapAreas, size: { x: number, z: number }): { Spawner }
	local spawners: { Spawner } = {}
	local placed: { { number } } = {}
	local hx, hz = size.x / 2 - AreaSpawns.EDGE, size.z / 2 - AreaSpawns.EDGE
	local caves: { AreaTypes.Circle } = {}
	for _, entrance in def.caves do
		table.insert(caves, { x = entrance.x, z = entrance.z, r = AreaSpawns.CAVE_CLEARANCE })
	end
	for _, area in def.areas do
		local rng = Rng.new(seedOf(area.id))
		local profile = AreaProfiles.get(area.profile)
		local profileRng = Rng.new(seedOf(`{area.id}#profile`))
		local x1, z1 = math.max(area.rect[1], -hx), math.max(area.rect[2], -hz)
		local x2, z2 = math.min(area.rect[3], hx), math.min(area.rect[4], hz)
		local made = 0
		local tries = 0
		while made < area.groups and tries < area.groups * 60 do
			tries += 1
			local x, z = rng:float(x1, x2), rng:float(z1, z2)
			local ok = farFrom(placed, x, z, AreaSpawns.MIN_GROUP_DISTANCE)
				and not AreaSpawns.nearRoad(def.roads, x, z, AreaSpawns.ROAD_CLEARANCE)
				and not inCircles(def.lakes, x, z, AreaSpawns.WATER_CLEARANCE)
				and not inCircles(def.avoid, x, z, 0)
				and not inCircles(caves, x, z, 0)
				and not AreaSpawns.nearStream(def.streams, x, z, AreaSpawns.STREAM_CLEARANCE)
				and MapTerrain.walkable(def.map, x, z, AreaSpawns.CLIFF_CLEARANCE)
			if ok then
				made += 1
				local u = rng:next()
				local count = weightedAt(AreaSpawns.GROUP_SIZE_WEIGHTS, u)
				local kinds = members(area.kinds, count, rng)
				if profile then
					-- The layout generator keeps its sequence: the profile reads the same roll on its weights,
					-- drops members from the end or adds some from its own generator.
					count = weightedAt(profile.sizeWeights, u)
					local main = kinds[1]
					while #kinds > count do
						table.remove(kinds)
					end
					while #kinds < count do
						local more = #area.kinds > 1 and not profileRng:chance(0.65)
						table.insert(kinds, if more then profileRng:pick(area.kinds) else main)
					end
				end
				table.insert(placed, { x, z })
				table.insert(spawners, {
					id = `{area.id}_{made}`,
					monster = kinds[1],
					members = kinds,
					variant = "normal",
					level = levelRange(area.lv, kinds),
					position = {
						x = math.floor(x + 0.5),
						y = math.floor((MapTerrain.height(def.map, x, z) or 0) + 0.5),
						z = math.floor(z + 0.5),
					},
					radius = rng:int(5, 8),
					count = count,
					respawn = if profile then profile.respawn else AreaSpawns.RESPAWN,
					areaId = area.id,
				})
			end
		end
	end
	return spawners
end

-- Room plan of a cave: listed rooms (boss caves) or the generated plan.
function AreaSpawns.caveRooms(cave: AreaTypes.Cave): { AreaTypes.Room }
	if cave.rooms then
		return cave.rooms
	end
	return CaveGen.generate(cave.seed or seedOf(cave.id)).rooms
end

-- Rooms that hold monsters: all but the entrance (and the boss antechamber).
local function fightRooms(cave: AreaTypes.Cave): { AreaTypes.Room }
	local rooms = AreaSpawns.caveRooms(cave)
	local list = {}
	local last = if cave.boss then #rooms - 1 else #rooms
	for i = 2, last do
		table.insert(list, rooms[i])
	end
	return list
end

function AreaSpawns.cave(cave: AreaTypes.Cave): { Spawner }
	local rng = Rng.new(seedOf(cave.id))
	local spawners: { Spawner } = {}
	local placed: { { number } } = {}
	local rooms = fightRooms(cave)
	local range = { cave.levels[1], cave.levels[2] }

	local function pointIn(room: AreaTypes.Room): (number?, number?)
		for _ = 1, 40 do
			local angle = rng:float(0, math.pi * 2)
			local distance = math.sqrt(rng:next()) * room.r * 0.65
			local x, z = room.x + math.cos(angle) * distance, room.z + math.sin(angle) * distance
			if farFrom(placed, x, z, AreaSpawns.MIN_CAVE_GROUP_DISTANCE) then
				return x, z
			end
		end
		return nil, nil
	end

	local function add(id: string, variant: any, kinds: { string }, room: AreaTypes.Room, respawn: any, extra: any?)
		local x, z = pointIn(room)
		if not x or not z then
			return
		end
		table.insert(placed, { x, z })
		local spawner: Spawner = {
			id = `{cave.id}_{id}`,
			monster = kinds[1],
			members = kinds,
			variant = variant,
			level = levelRange(range, kinds),
			position = { x = math.floor(x + 0.5), y = 0, z = math.floor(z + 0.5) },
			radius = if variant == "elite2" then 4 else rng:int(5, 7),
			count = #kinds,
			respawn = respawn,
			areaId = cave.id,
		}
		if extra then
			spawner.choices = extra
		end
		table.insert(spawners, spawner)
	end

	-- Elite II in the deepest (easternmost) room.
	local deepest = rooms[1]
	for _, room in rooms do
		if room.x > deepest.x then
			deepest = room
		end
	end
	add("elite2", "elite2", { cave.elite2[1] }, deepest, AreaSpawns.ELITE2_RESPAWN, cave.elite2)

	-- Elite groups, alternating the two kinds, spread over the rooms.
	for i = 1, cave.eliteGroups do
		local kind = cave.elites[(i - 1) % #cave.elites + 1]
		local count = if rng:chance(0.5) then 2 else 1
		local kinds = table.create(count, kind)
		add(`elite_{i}`, "elite", kinds, rooms[(i - 1) % #rooms + 1], AreaSpawns.ELITE_RESPAWN)
	end

	-- Normal groups: two per room (one in small rooms).
	local n = 0
	for _, room in rooms do
		local per = if room.r >= 45 then 2 else 1
		for _ = 1, per do
			n += 1
			local count = rng:weighted(AreaSpawns.GROUP_SIZE_WEIGHTS)
			add(`group_{n}`, "normal", members(cave.normal, count, rng), room, AreaSpawns.RESPAWN)
		end
	end
	return spawners
end

return AreaSpawns
