--!strict
-- Room plan of a generated cave (S19): a chain of 3–5 rooms from the entrance (west) to the east, plus 1–2
-- side rooms, joined by corridors. Deterministic from the seed, pure (Lune): the server carves it
-- (World/Layouts/CaveTemplate) and Logic/AreaSpawns places the monster groups in the same rooms.

local Rng = require("./Rng")

export type Room = { x: number, z: number, r: number, h: number }
export type Corridor = { ax: number, az: number, bx: number, bz: number, w: number }
export type Plan = { rooms: { Room }, corridors: { Corridor } }

local CaveGen = {}

CaveGen.SIZE = 480 -- map size (studs) of a generated cave
CaveGen.ENTRANCE = { x = -185, z = 0, r = 36, h = 22 }

local EDGE = 26 -- rooms keep this far from the map edge
local GAP = 14 -- minimum rock between two rooms

local function fits(rooms: { Room }, candidate: Room): boolean
	local half = CaveGen.SIZE / 2 - EDGE
	if math.abs(candidate.x) + candidate.r > half or math.abs(candidate.z) + candidate.r > half then
		return false
	end
	for _, room in rooms do
		local dx, dz = room.x - candidate.x, room.z - candidate.z
		if math.sqrt(dx * dx + dz * dz) < room.r + candidate.r + GAP then
			return false
		end
	end
	return true
end

function CaveGen.generate(seed: number): Plan
	local rng = Rng.new(seed)
	local entrance = CaveGen.ENTRANCE
	local rooms: { Room } = { { x = entrance.x, z = entrance.z, r = entrance.r, h = entrance.h } }
	local corridors: { Corridor } = {}

	local function link(a: Room, b: Room)
		table.insert(corridors, { ax = a.x, az = a.z, bx = b.x, bz = b.z, w = rng:int(14, 18) })
	end

	-- Main chain eastwards.
	local chain = rng:int(3, 5)
	local step = (CaveGen.SIZE / 2 - EDGE - 50 - (entrance.x + entrance.r)) / chain
	local previous = rooms[1]
	for i = 1, chain do
		local placed: Room? = nil
		for _ = 1, 30 do
			local r = rng:int(40, 56)
			local candidate = {
				x = entrance.x + entrance.r + step * i - step * 0.4 + rng:float(-12, 12),
				z = rng:float(-80, 80),
				r = r,
				h = rng:int(22, 30),
			}
			if fits(rooms, candidate) then
				placed = candidate
				break
			end
		end
		if placed then
			table.insert(rooms, placed)
			link(previous, placed)
			previous = placed
		end
	end

	-- Side rooms off the chain (north or south).
	local sides = rng:int(1, 2)
	for _ = 1, sides do
		for _ = 1, 30 do
			local parent = rooms[rng:int(2, #rooms)]
			local direction = if rng:chance(0.5) then 1 else -1
			local r = rng:int(36, 48)
			local candidate = {
				x = parent.x + rng:float(-30, 30),
				z = parent.z + direction * (parent.r + r + rng:float(GAP + 6, GAP + 30)),
				r = r,
				h = rng:int(20, 26),
			}
			if fits(rooms, candidate) then
				table.insert(rooms, candidate)
				link(parent, candidate)
				break
			end
		end
	end
	return { rooms = rooms, corridors = corridors }
end

return CaveGen
