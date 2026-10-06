--!strict
-- Arrival points of the monster areas (S22, DESIGN §3.6): where a portal (or a map stone) brings a player who
-- picked an area. A point on a road, 12-20 studs inside the area from where the road enters it, clear of
-- water, portals and spawn points (`avoid`), cave mouths, the map edge and every monster group. Pure and
-- deterministic; the results are stored in Data/Areas (`arrive`) and checked by tests/areaarrival.spec.

local AreaSpawns = require("./AreaSpawns")
local MapTerrain = require("./MapTerrain")
local AreaTypes = require("../Data/Areas/Types")

local AreaArrival = {}

AreaArrival.DEPTH_MIN = 12 -- studs along the road from where it enters the area
AreaArrival.DEPTH_BEST = 16
AreaArrival.GROUP_CLEARANCE = 35 -- from every monster group spawner of the map
AreaArrival.EDGE = 20 -- from the map edge
AreaArrival.WATER_CLEARANCE = 8
AreaArrival.CAVE_CLEARANCE = 40
AreaArrival.BESIDE_SPAWN = 20 -- preferred distance from the map spawn in the area that holds it
local STEP = 2

type Point = { x: number, z: number }

local function inRect(rect: { number }, x: number, z: number, inset: number): boolean
	return x >= rect[1] + inset and x <= rect[3] - inset and z >= rect[2] + inset and z <= rect[4] - inset
end

-- Whether a player may arrive at x/z on this map.
function AreaArrival.valid(
	def: AreaTypes.MapAreas,
	spawners: { { position: { x: number, z: number } } },
	size: { x: number, z: number },
	x: number,
	z: number
): boolean
	if math.abs(x) > size.x / 2 - AreaArrival.EDGE or math.abs(z) > size.z / 2 - AreaArrival.EDGE then
		return false
	end
	for _, c in def.avoid do
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 < c.r * c.r then
			return false
		end
	end
	for _, c in def.lakes do
		local r = c.r + AreaArrival.WATER_CLEARANCE
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 < r * r then
			return false
		end
	end
	for _, cave in def.caves do
		if (x - cave.x) ^ 2 + (z - cave.z) ^ 2 < AreaArrival.CAVE_CLEARANCE ^ 2 then
			return false
		end
	end
	-- S26: never in a stream or on a bridge over one, never at a cliff
	if
		AreaSpawns.nearStream(def.streams, x, z, AreaArrival.WATER_CLEARANCE) or not MapTerrain.walkable(def.map, x, z)
	then
		return false
	end
	local g = AreaArrival.GROUP_CLEARANCE
	for _, spawner in spawners do
		if (x - spawner.position.x) ^ 2 + (z - spawner.position.z) ^ 2 < g * g then
			return false
		end
	end
	return true
end

-- Points every STEP studs along a road polyline with the travelled distance.
local function samples(points: { number }): { { number } }
	local out = {}
	local travelled = 0
	for i = 1, #points - 3, 2 do
		local ax, az, bx, bz = points[i], points[i + 1], points[i + 2], points[i + 3]
		local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local n = math.max(1, math.floor(length / STEP))
		for k = 0, n - 1 do
			local t = k / n
			table.insert(out, { ax + (bx - ax) * t, az + (bz - az) * t, travelled + length * t })
		end
		travelled += length
	end
	table.insert(out, { points[#points - 1], points[#points], travelled })
	return out
end

-- Depth of every road sample inside the rect: distance along the road from the nearest point where the road
-- entered the rect (from either direction). Samples on a road that starts inside count from that start.
local function depths(list: { { number } }, rect: { number }): { number? }
	local out: { number? } = table.create(#list)
	local entry: number? = nil
	for i, p in list do
		if inRect(rect, p[1], p[2], 0) then
			if entry == nil then
				entry = if i == 1 then p[3] - 1e6 else p[3]
			end
			out[i] = p[3] - (entry :: number)
		else
			entry = nil
		end
	end
	entry = nil
	for i = #list, 1, -1 do
		local p = list[i]
		if inRect(rect, p[1], p[2], 0) then
			if entry == nil then
				entry = if i == #list then p[3] + 1e6 else p[3]
			end
			local d = (entry :: number) - p[3]
			local current = out[i]
			out[i] = if current then math.min(current, d) else d
		else
			entry = nil
		end
	end
	return out
end

-- Arrival point of one area: the valid road sample closest to DEPTH_BEST studs deep (at least DEPTH_MIN);
-- when the map's spawn point lies in the area (the first area by the city portal), the valid road sample
-- about BESIDE_SPAWN studs from it instead, so the arrival is beside the spawn, not on it. Without a usable road, the valid
-- point nearest to the area's centre on an 8-stud grid.
function AreaArrival.compute(
	def: AreaTypes.MapAreas,
	area: AreaTypes.Area,
	spawners: { { position: { x: number, z: number } } },
	size: { x: number, z: number },
	spawn: { x: number, z: number }?
): Point?
	local near = if spawn and inRect(area.rect, spawn.x, spawn.z, 0) then spawn else nil
	local best: Point? = nil
	local bestScore = math.huge
	for _, road in def.roads do
		local list = samples(road.points)
		local deep = depths(list, area.rect)
		for i, p in list do
			local depth = deep[i]
			if
				depth
				and depth >= AreaArrival.DEPTH_MIN
				and inRect(area.rect, p[1], p[2], 6)
				and AreaArrival.valid(def, spawners, size, p[1], p[2])
			then
				local score = if near
					then math.abs(math.sqrt((p[1] - near.x) ^ 2 + (p[2] - near.z) ^ 2) - AreaArrival.BESIDE_SPAWN)
					else math.abs(depth - AreaArrival.DEPTH_BEST)
				-- S26: of two equally deep road entries, the one nearer to the map's spawn (the way in from the city)
				if spawn and not near then
					score += 0.002 * math.sqrt((p[1] - spawn.x) ^ 2 + (p[2] - spawn.z) ^ 2)
				end
				if score < bestScore then
					bestScore = score
					best = { x = math.floor(p[1] + 0.5), z = math.floor(p[2] + 0.5) }
				end
			end
		end
	end
	if best then
		return best
	end
	local r = area.rect
	local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	for x = r[1] + 8, r[3] - 8, 8 do
		for z = r[2] + 8, r[4] - 8, 8 do
			if AreaArrival.valid(def, spawners, size, x, z) then
				local score = (x - cx) ^ 2 + (z - cz) ^ 2
				if score < bestScore then
					bestScore = score
					best = { x = x, z = z }
				end
			end
		end
	end
	return best
end

-- Every area of a region map -> its arrival point (nil when none is valid; the tests forbid that).
function AreaArrival.region(
	def: AreaTypes.MapAreas,
	size: { x: number, z: number },
	spawn: { x: number, z: number }?
): { [string]: Point }
	local spawners = AreaSpawns.region(def, size)
	local out: { [string]: Point } = {}
	for _, area in def.areas do
		local point = AreaArrival.compute(def, area, spawners :: any, size, spawn)
		if point then
			out[area.id] = point
		end
	end
	return out
end

return AreaArrival
