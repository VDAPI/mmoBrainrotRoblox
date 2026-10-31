--!strict
-- Level ground under the city's ordinary houses (2026-10-31, the owner's tester: "the doors of the cottages, and the
-- cottages, go into the ground"). Pure: Logic/TownTerrain lays these pads over its plan height, so the terrain
-- writer, the house generator (Logic/TownGen/Houses), the lamps, the props and the client all read the same ground.
--
-- A house's model (Data/Kit `house:*`, Util/KitAssets) is fitted to the lot's longer side and stretched to its front,
-- so it can reach past the lot to the front and the back; `footprint` is the most it can cover. Its pad:
--   * the level is the highest plan ground under that footprint and MARGIN studs round it (no drawn voxel by the
--     house is above its floor); the model stands SEAT under it, its stone skirt down to the plan ground on the low
--     sides (Logic/TownGen/Houses, Util/KitAssets),
--   * under the footprint the ground is flat at the level (the house's own pad wins over a neighbour's); within NEAR
--     studs of a lower neighbour's footprint it takes that one's level, so the 4-stud voxels step up inside the
--     higher house (its skirt shows) and never over the lower one's plinth,
--   * a lip FRONT studs deep before its door (the model's door from Data/Kit, Logic/KitPick) is flat at the level,
--     and the ground falls from it to the street at GRADE (only raised, never cut; no steeper than a street may be),
--     never on a ramp's road or in the river, and within NEAR studs of a footprint never over that house's level.
--
-- Spots (Studio 2026-11-01: a lamp on a river bank stood 1.4 studs in the ground on one side, a farm well 2.6): a
-- small prop whose base would stand on uneven ground gets a level spot of its own, cut and filled to the ground at
-- its middle within SPOT studs round its base (the 4-stud voxels then draw it flat under the whole base) and falling
-- back to the ground round it at BANK. Never on a ramp's road or in water, never under a house, and within NEAR studs
-- of a house never lower than the ground there nor over that house's level.

local KitPick = require("./KitPick")
local KitSeat = require("./KitSeat")

local LotPads = {}

LotPads.FRONT = 1
LotPads.GRADE = 0.45
LotPads.MARGIN = 3
-- the lip reaches this far past the door on either side
LotPads.DOOR = 1
-- a footprint takes a lower neighbour's level this close to it (a voxel: the drawn ground between column centres)
LotPads.NEAR = 4
-- the model's foot stands this far under its pad (the plinth's lower edge in the ground, no seam of light under it)
LotPads.SEAT = 0.25
-- a spot is levelled this far round its base (a voxel and a little: every column the drawn base reads from)
LotPads.SPOT = 3
-- the most the ground under a base may vary before it gets a spot
LotPads.UNEVEN = 0.5
LotPads.BANK = 1

type Lot = { x: number, z: number, w: number, d: number, rot: number, style: string, floors: number }

type Pad = {
	x: number,
	z: number,
	c: number, -- cos(rot)
	s: number, -- sin(rot)
	hw: number, -- half the footprint's width
	hd: number, -- half the footprint's depth
	door: number, -- half the width of the lip before the door (centred: the model's door may sit either way)
	level: number,
}

type Spot = { x: number, z: number, flat: number, reach: number, level: number }

export type Pads = {
	pads: { Pad },
	cells: { [number]: { number } },
	spots: { Spot },
	spotCells: { [number]: { number } },
}

local CELL = 32
-- the farthest a spot's bank reaches past its level ground
local REACH = 24

-- The house's width (the generator's front, the model's stretch) and the most its model can reach front to back: the
-- model's widest side is the larger of the two (Data/Kit `fit = "width"`), its width at most that.
function LotPads.footprint(lot: Lot): (number, number)
	local detached = lot.style == "craft" or lot.style == "cottage"
	local W = lot.w - (if detached then 0.6 else 0.3)
	local D = math.max(W, lot.d - 0.6)
	return W, D
end

-- Half the width of the lip before the house's door: the city's model for the lot (Logic/KitPick picks it from the
-- slot's key and the lot's middle; the city's map offset is 0) and its door (Data/Kit), else the whole front.
function LotPads.doorHalf(lot: Lot): number
	local W, D = LotPads.footprint(lot)
	local choice = KitPick.pick(`house:{lot.style}:{lot.floors}`, "city", lot.x, lot.z, D)
	local door = choice and choice.variant.door
	if not door then
		return W / 2
	end
	return math.min(W / 2, (math.abs(door[1]) + door[2]) * W + LotPads.DOOR)
end

local function key(i: number, k: number): number
	return i * 4096 + k
end

-- Local coordinates of a world point in a pad's frame (front to -z).
local function toLocal(pad: Pad, x: number, z: number): (number, number)
	local dx, dz = x - pad.x, z - pad.z
	return dx * pad.c - dz * pad.s, dx * pad.s + dz * pad.c
end

-- The pads of `lots` (the city plan's, Data/Town) over the plan ground `height` (built once; the level samples the
-- plan every 2 studs).
function LotPads.new(lots: { any }, height: (x: number, z: number) -> number): Pads
	local out: Pads = { pads = {}, cells = {}, spots = {}, spotCells = {} }
	for _, lot in lots do
		local W, D = LotPads.footprint(lot)
		local r = math.rad(lot.rot)
		local pad: Pad = {
			x = lot.x,
			z = lot.z,
			c = math.cos(r),
			s = math.sin(r),
			hw = W / 2,
			hd = D / 2,
			door = LotPads.doorHalf(lot),
			level = 0,
		}
		local level, low = -math.huge, math.huge
		local x0, x1 = -pad.hw - LotPads.MARGIN, pad.hw + LotPads.MARGIN
		local z0, z1 = -pad.hd - LotPads.FRONT - LotPads.MARGIN, pad.hd + LotPads.MARGIN
		local nx, nz = math.ceil((x1 - x0) / 2), math.ceil((z1 - z0) / 2)
		for i = 0, nx do
			for k = 0, nz do
				local lx, lz = x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * k / nz
				local h = height(lot.x + lx * pad.c + lz * pad.s, lot.z - lx * pad.s + lz * pad.c)
				level, low = math.max(level, h), math.min(low, h)
			end
		end
		pad.level = level
		table.insert(out.pads, pad)
		local index = #out.pads
		-- as far as the fall from the lip can stand over ground a few studs under the lowest plan ground round it
		local reach = math.sqrt(pad.hw ^ 2 + (pad.hd + LotPads.FRONT) ^ 2) + (level - low + 4) / LotPads.GRADE
		for i = math.floor((lot.x - reach) / CELL), math.floor((lot.x + reach) / CELL) do
			for k = math.floor((lot.z - reach) / CELL), math.floor((lot.z + reach) / CELL) do
				local list = out.cells[key(i, k)]
				if not list then
					list = {}
					out.cells[key(i, k)] = list
				end
				table.insert(list, index)
			end
		end
	end
	return out
end

-- The level of the pad of the `i`-th lot.
function LotPads.level(pads: Pads, i: number): number
	return pads.pads[i].level
end

-- Whether (x, z) is within NEAR + `extra` studs of a house's footprint.
local function nearHouse(pads: Pads, x: number, z: number, extra: number): boolean
	local list = pads.cells[key(math.floor(x / CELL), math.floor(z / CELL))]
	if not list then
		return false
	end
	for _, index in list do
		local pad = pads.pads[index]
		local lx, lz = toLocal(pad, x, z)
		local ox, oz = math.max(math.abs(lx) - pad.hw, 0), math.max(math.abs(lz) - pad.hd, 0)
		if ox * ox + oz * oz < (LotPads.NEAR + extra) ^ 2 then
			return true
		end
	end
	return false
end

-- Adds the spots of small props (each { x, z, r }: the middle and the radius of its base) over the ground `ground`
-- (the plan with these pads; `wet` true where no spot may change it: a ramp's road, the moat). Only a base on uneven
-- drawn ground (more than UNEVEN under it and a little round it, Logic/KitSeat) gets one, never under `floor` (dry: a
-- lamp at a river's edge stands on a little shore). Returns how many it added.
function LotPads.addSpots(
	pads: Pads,
	props: { { number } },
	ground: (x: number, z: number) -> number,
	wet: (x: number, z: number) -> boolean,
	floor: number
): number
	local added = 0
	for _, p in props do
		local x, z, r = p[1], p[2], p[3]
		local flat = r + LotPads.SPOT
		local lo, hi = KitSeat.range(ground, x, z, r * 1.4)
		-- by a house the spot only fills (the ground there is the house's: its door's lip, its plinth), to the highest
		-- ground under the base; elsewhere it is cut and filled to the ground at its middle
		local level = math.max(if nearHouse(pads, x, z, flat) then hi else ground(x, z), floor)
		lo, hi = math.min(lo, level), math.max(hi, level)
		-- the bank reaches as far as the ground strays from the level more than it may (a slope steeper than BANK
		-- never meets it: no spot)
		local reach: number? = nil
		if hi - lo > LotPads.UNEVEN and not wet(x, z) then
			for d = flat + 1, flat + REACH do
				local fits = true
				for i = 0, 23 do
					local a = i * math.pi / 12
					if
						math.abs(ground(x + math.cos(a) * d, z + math.sin(a) * d) - level)
						> LotPads.BANK * (d - flat)
					then
						fits = false
						break
					end
				end
				if fits then
					reach = d + 1
					break
				end
			end
		end
		if reach then
			local spot: Spot = { x = x, z = z, flat = flat, reach = reach, level = level }
			table.insert(pads.spots, spot)
			local index = #pads.spots
			for i = math.floor((x - spot.reach) / CELL), math.floor((x + spot.reach) / CELL) do
				for k = math.floor((z - spot.reach) / CELL), math.floor((z + spot.reach) / CELL) do
					local list = pads.spotCells[key(i, k)]
					if not list then
						list = {}
						pads.spotCells[key(i, k)] = list
					end
					table.insert(list, index)
				end
			end
			added += 1
		end
	end
	return added
end

-- The spots over the ground `g` at (x, z); near a house (`own`: the level of the lowest footprint within NEAR) only
-- filled up to that level.
local function spotsAt(pads: Pads, x: number, z: number, g: number, own: number): number
	local list = pads.spotCells[key(math.floor(x / CELL), math.floor(z / CELL))]
	if not list then
		return g
	end
	local out = g
	for _, index in list do
		local spot = pads.spots[index]
		local d = math.sqrt((x - spot.x) ^ 2 + (z - spot.z) ^ 2)
		if d < spot.reach then
			local bank = LotPads.BANK * math.max(d - spot.flat, 0)
			out = math.clamp(out, spot.level - bank, spot.level + bank)
		end
	end
	if own < math.huge then
		out = math.clamp(out, g, math.max(g, own))
	end
	return out
end

-- Ground at (x, z) with the pads over the plan ground `h` there. `free` false (a ramp's road, the river) keeps the
-- plan ground outside the footprints; `wet` (a ramp's road, water) keeps it from the spots too.
function LotPads.at(pads: Pads, x: number, z: number, h: number, free: boolean?, wet: boolean?): number
	local list = pads.cells[key(math.floor(x / CELL), math.floor(z / CELL))]
	if not list then
		return if wet then h else spotsAt(pads, x, z, h, math.huge)
	end
	local inside = false
	local own = math.huge
	local best = h
	for _, index in list do
		local pad = pads.pads[index]
		local lx, lz = toLocal(pad, x, z)
		local ox, oz = math.abs(lx) - pad.hw, math.abs(lz) - pad.hd
		if ox <= 0 and oz <= 0 then
			inside = true
		end
		if math.max(ox, 0) ^ 2 + math.max(oz, 0) ^ 2 < LotPads.NEAR * LotPads.NEAR then
			own = math.min(own, pad.level)
		end
		if free ~= false and lz <= pad.hd and (ox > 0 or oz > 0) then
			-- the fall from the lip (x within the door's reach, z from the front to FRONT before it); nothing behind
			-- the house's back
			local ax = math.max(math.abs(lx) - pad.door, 0)
			local az = math.max(-pad.hd - LotPads.FRONT - lz, lz + pad.hd, 0)
			best = math.max(best, pad.level - LotPads.GRADE * math.sqrt(ax * ax + az * az))
		end
	end
	if inside then
		return own
	end
	-- by a house the fall from a neighbour's lip stays under its floor
	local g = math.max(h, math.min(best, own))
	return if wet then g else spotsAt(pads, x, z, g, own)
end

return LotPads
