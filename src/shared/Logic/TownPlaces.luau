--!strict
-- Teleport targets in the starting city (S29): dev panel "Place in the city", /town tp, /npc. Pure.
--
-- A place gives a start point from the city plan: `rynek` = the city spawn by the fountain; a special building =
-- its door; a square = the middle of its polygon; the arena = its exit; an NPC id = 3 studs in front of the NPC
-- (along its `facing`). From there rings (Logic/Respawn.searchOffsets) look for the first point that is free:
-- open ground inside the walls (TownTerrain.isOpen: no house, special or stall footprint, not the river) and no
-- collidable shell piece of any TownGen Build in the column a character needs (feet to well over the head, so a
-- porch roof, stall awning or market hall never catches the ground ray), clear of every NPC and signpost.
-- WorldService.SafeSpot then checks the real world at that point.

local Respawn = require("./Respawn")
local Town = require("../Data/Town")
local TownGen = require("./TownGen")
local TownGeom = require("./TownGeom")
local TownSigns = require("./TownSigns")
local TownTerrain = require("./TownTerrain")

local TownPlaces = {}

export type Kind = "spawn" | "arena" | "special" | "square" | "npc"
export type Place = { id: string, kind: Kind }
-- Resolved target: the free point and the point to face (map-relative studs).
export type Spot = { x: number, z: number, lookX: number, lookZ: number }

-- Column a character needs over the plan ground: pieces whose top is under FLOOR are floors and kerbs (stand on
-- them), anything reaching into FLOOR..HEADROOM blocks. HEADROOM is over WorldService's ground ray start, so a
-- free point can never put the character on a roof.
TownPlaces.FLOOR = 0.6
TownPlaces.HEADROOM = 18
TownPlaces.PAD = 1.5 -- studs kept from every piece
TownPlaces.NPC_CLEAR = 2.5 -- studs kept from NPCs and signposts
TownPlaces.SEARCH_RADIUS = 60
TownPlaces.NPC_FRONT = 3

local CELL = 16

type Obstacle = {
	cx: number,
	cy: number,
	cz: number,
	r: { number }, -- world rotation, row-major
	e: { number }, -- half size + PAD
}

local grid: { [number]: { Obstacle } }? = nil

local function cellKey(ix: number, iz: number): number
	return (ix + 1000) * 4096 + (iz + 1000)
end

-- Collidable shell pieces of every city Build as oriented boxes, binned in CELL x CELL columns by their
-- horizontal reach. Built once (~3000 pieces, ~0.1 s).
local function obstacles(): { [number]: { Obstacle } }
	if grid then
		return grid
	end
	local out: { [number]: { Obstacle } } = {}
	local pad = TownPlaces.PAD
	for _, build in TownGen.all(Town.city, TownTerrain.heightAt) do
		local at = build.at
		local a = math.rad(at.rot)
		local c, s = math.cos(a), math.sin(a)
		for _, piece in build.bp.pieces do
			if piece.lod ~= "shell" or not piece.col then
				continue
			end
			local p, pr = piece.p, piece.r
			-- World = Ry(rot) * local; Ry rows: (c, 0, s), (0, 1, 0), (-s, 0, c).
			local r = {
				c * pr[1] + s * pr[7],
				c * pr[2] + s * pr[8],
				c * pr[3] + s * pr[9],
				pr[4],
				pr[5],
				pr[6],
				-s * pr[1] + c * pr[7],
				-s * pr[2] + c * pr[8],
				-s * pr[3] + c * pr[9],
			}
			local o: Obstacle = {
				cx = at.x + c * p[1] + s * p[3],
				cy = at.y + p[2],
				cz = at.z - s * p[1] + c * p[3],
				r = r,
				e = { piece.size[1] / 2 + pad, piece.size[2] / 2 + pad, piece.size[3] / 2 + pad },
			}
			-- Horizontal reach: |x| = sum |r_xj| * e_j (and the same for z).
			local hx = math.abs(r[1]) * o.e[1] + math.abs(r[2]) * o.e[2] + math.abs(r[3]) * o.e[3]
			local hz = math.abs(r[7]) * o.e[1] + math.abs(r[8]) * o.e[2] + math.abs(r[9]) * o.e[3]
			for ix = math.floor((o.cx - hx) / CELL), math.floor((o.cx + hx) / CELL) do
				for iz = math.floor((o.cz - hz) / CELL), math.floor((o.cz + hz) / CELL) do
					local key = cellKey(ix, iz)
					local list = out[key]
					if not list then
						list = {}
						out[key] = list
					end
					table.insert(list, o)
				end
			end
		end
	end
	grid = out
	return out
end

-- Whether the vertical segment (x, y0..y1, z) touches the oriented box (slab test in its local frame).
local function columnHits(o: Obstacle, x: number, y0: number, y1: number, z: number): boolean
	local r = o.r
	local dx, dz = x - o.cx, z - o.cz
	local tMin, tMax = 0, 1
	for axis = 0, 2 do
		-- Local coordinate = (column of R)^T * (point - centre).
		local rx, ry, rz = r[axis + 1], r[axis + 4], r[axis + 7]
		local start = rx * dx + ry * (y0 - o.cy) + rz * dz
		local delta = ry * (y1 - y0)
		local e = o.e[axis + 1]
		if math.abs(delta) < 1e-9 then
			if math.abs(start) > e then
				return false
			end
		else
			local t1, t2 = (-e - start) / delta, (e - start) / delta
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin, tMax = math.max(tMin, t1), math.min(tMax, t2)
			if tMin > tMax then
				return false
			end
		end
	end
	return true
end

local markers: { { number } }? = nil

-- NPC spots and signposts (cached).
local function nearMarker(x: number, z: number): boolean
	if not markers then
		local list = {}
		for _, spot in Town.allNpcSpots() do
			table.insert(list, { spot.x, spot.z })
		end
		for _, sign in TownSigns.list() do
			table.insert(list, { sign.x, sign.z })
		end
		markers = list
	end
	local clear = TownPlaces.NPC_CLEAR ^ 2
	for _, m in markers :: { { number } } do
		if (m[1] - x) ^ 2 + (m[2] - z) ^ 2 < clear then
			return true
		end
	end
	return false
end

-- Whether a character can be put at (x, z): open plan ground inside the walls, no building piece in its column,
-- not on an NPC or a signpost.
function TownPlaces.isFree(x: number, z: number): boolean
	if not TownTerrain.isOpen(x, z, TownPlaces.PAD) or nearMarker(x, z) then
		return false
	end
	local h = TownTerrain.heightAt(x, z)
	local list = obstacles()[cellKey(math.floor(x / CELL), math.floor(z / CELL))]
	if list then
		for _, o in list do
			if columnHits(o, x, h + TownPlaces.FLOOR, h + TownPlaces.HEADROOM, z) then
				return false
			end
		end
	end
	return true
end

-- First free point at (x, z) or on the rings around it (nearest first), or nil.
function TownPlaces.freeNear(x: number, z: number, radius: number?): (number?, number?)
	if TownPlaces.isFree(x, z) then
		return x, z
	end
	for _, offset in Respawn.searchOffsets(radius or TownPlaces.SEARCH_RADIUS) do
		local px, pz = x + offset[1], z + offset[2]
		if TownPlaces.isFree(px, pz) then
			return px, pz
		end
	end
	return nil, nil
end

-- Every named place for the dev panel: the spawn square first, then the arena, special buildings, squares.
function TownPlaces.list(): { Place }
	local out: { Place } = { { id = "rynek", kind = "spawn" }, { id = "arena", kind = "arena" } }
	for _, special in Town.city.specials do
		if special.kind ~= "arena" then
			table.insert(out, { id = special.id, kind = "special" })
		end
	end
	for _, square in Town.city.squares do
		if square.id ~= "rynek" then
			table.insert(out, { id = square.id, kind = "square" })
		end
	end
	return out
end

-- Start point (before the search) and the point to face, or nil for an unknown id. NPC ids work too.
function TownPlaces.start(id: string): (number?, number?, number?, number?)
	local city = Town.city
	if id == "rynek" then
		local fx, fz = TownGeom.front(city.spawn.facing)
		return city.spawn.x, city.spawn.z, city.spawn.x + fx * 10, city.spawn.z + fz * 10
	end
	if id == "arena" then
		return city.arena.exit[1], city.arena.exit[2], city.arena.x, city.arena.z
	end
	local special = Town.special(id)
	if special then
		local x, z = TownGeom.door(special.x, special.z, special.d, special.rot)
		return x, z, special.x, special.z
	end
	for _, square in city.squares do
		if square.id == id then
			local sx, sz = 0, 0
			for _, point in square.poly do
				sx += point[1]
				sz += point[2]
			end
			local x, z = sx / #square.poly, sz / #square.poly
			return x, z, x, z
		end
	end
	local spot = Town.npcSpot(id)
	if spot then
		local fx, fz = TownGeom.front(spot.facing)
		return spot.x + fx * TownPlaces.NPC_FRONT, spot.z + fz * TownPlaces.NPC_FRONT, spot.x, spot.z
	end
	return nil
end

-- Free target for a place or a city NPC, or nil for an unknown id (or no free point in SEARCH_RADIUS).
function TownPlaces.resolve(id: string): Spot?
	local x, z, lookX, lookZ = TownPlaces.start(id)
	if not x or not z then
		return nil
	end
	local fx, fz = TownPlaces.freeNear(x, z)
	if not fx or not fz then
		return nil
	end
	local lx, lz = lookX :: number, lookZ :: number
	if (lx - fx) ^ 2 + (lz - fz) ^ 2 < 0.01 then
		-- Facing a point under the feet (a square's middle): face north.
		lx, lz = fx, fz - 10
	end
	return { x = fx, z = fz, lookX = lx, lookZ = lz }
end

return TownPlaces
