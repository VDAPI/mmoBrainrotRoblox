--!strict
-- Fishing spots of the height-function maps (studio review 2026-10-21: the Meadows' spot under the waterfall stood in
-- the ravine wall and its buoys lay on the pool's dry rim). One rule for every map, its generator (MeadowsGen,
-- DuskwoodGen, AshenGen, FrostpeakGen) picks the spots with it and the tests check them all with it:
--   * the spot stands on dry, gentle ground (the map's `walkable`), on a dry voxel, with no wall over it: the ground
--     within WALL studs rises at most RISE over the spot's own,
--   * its three buoys (Services/GatherService builds the marker) float on water the voxels show
--     (TerrainLayers.voxelWater: a pond's shallow rim is written as ground), so the water is right beside the spot,
--   * the buoys face the water: local +Z (south) when all three float there, else the nearest turn by 45 degrees that
--     puts all three on water (`face`; the server works it out again from the same terrain),
--   * the sign and the buoys keep clear of the map's builds (`clearOf`: a jetty, a hut, a rock).
-- Pure, no Roblox API.

local TerrainLayers = require("./TerrainLayers")

local FishingSpots = {}

-- The buoys in the spot's own frame (x across, z out over the water), as GatherService has placed them since S26.
local BUOYS: { { number } } = {}
for i = 1, 3 do
	table.insert(BUOYS, { 9 * math.cos(2.1 * i), 8 + 5 * math.sin(2.1 * i) })
end
FishingSpots.BUOYS = table.freeze(BUOYS)
FishingSpots.WALL = 6
FishingSpots.RISE = 2.5
-- Turns tried for the buoys, in order (degrees about the vertical; 0 = +Z).
FishingSpots.FACES = table.freeze({ 0, 45, -45, 90, -90, 135, -135, 180 })

export type HeightFn = (x: number, z: number) -> number
export type WaterFn = (x: number, z: number) -> number?
-- A map's terrain as the generators see it (Logic/MeadowsTerrain, a Logic/RegionTerrain map).
export type Terrain = {
	height: HeightFn,
	water: WaterFn,
	walkable: (x: number, z: number) -> boolean,
}

-- The buoys of a spot at (x, z) turned by `face` degrees: map-relative { x, z } each.
function FishingSpots.buoys(x: number, z: number, face: number): { { number } }
	local a = math.rad(face)
	local c, s = math.cos(a), math.sin(a)
	local out = {}
	for _, b in BUOYS do
		table.insert(out, { x + b[1] * c + b[2] * s, z - b[1] * s + b[2] * c })
	end
	return out
end

-- The first turn of FACES whose three buoys all float on water the voxels show, or nil.
function FishingSpots.face(height: HeightFn, water: WaterFn, x: number, z: number): number?
	for _, face in FishingSpots.FACES do
		local ok = true
		for _, b in FishingSpots.buoys(x, z, face) do
			if TerrainLayers.voxelWater(height, water, b[1], b[2]) == nil then
				ok = false
				break
			end
		end
		if ok then
			return face
		end
	end
	return nil
end

-- Whether a fishing spot may stand at (x, z) (the rules at the top).
function FishingSpots.ok(T: Terrain, x: number, z: number): boolean
	if not T.walkable(x, z) or TerrainLayers.voxelWater(T.height, T.water, x, z) ~= nil then
		return false
	end
	local h = T.height(x, z)
	for _, r in { FishingSpots.WALL / 2, FishingSpots.WALL } do
		for i = 0, 7 do
			local a = i * math.pi / 4
			if T.height(x + math.cos(a) * r, z + math.sin(a) * r) - h > FishingSpots.RISE then
				return false
			end
		end
	end
	return FishingSpots.face(T.height, T.water, x, z) ~= nil
end

-- Whether a point lies within `margin` studs of a collidable piece of a build (its box in its own frame).
local function inPiece(b: any, piece: any, x: number, y: number, z: number, margin: number): boolean
	-- the point in the build's frame (Kit.toWorld turned back), then in the piece's (its rotation transposed)
	local a = math.rad(b.at.rot)
	local c, s = math.cos(a), math.sin(a)
	local wx, wy, wz = x - b.at.x, y - b.at.y, z - b.at.z
	local bx, bz = c * wx - s * wz, s * wx + c * wz
	local dx, dy, dz = bx - piece.p[1], wy - piece.p[2], bz - piece.p[3]
	local r = piece.r
	local lx = r[1] * dx + r[4] * dy + r[7] * dz
	local ly = r[2] * dx + r[5] * dy + r[8] * dz
	local lz = r[3] * dx + r[6] * dy + r[9] * dz
	local size = piece.size
	return math.abs(lx) < size[1] / 2 + margin
		and math.abs(ly) < size[2] / 2 + margin
		and math.abs(lz) < size[3] / 2 + margin
end

-- Whether the marker of a spot at (x, z) with buoys turned by `face` keeps clear of every collidable piece of
-- `builds` (the generator's Builds): the post and its sign (6 studs over the ground) by 1.5 studs, each buoy by one.
function FishingSpots.clearOf(T: Terrain, builds: { any }, x: number, z: number, face: number): boolean
	local g = T.height(x, z)
	local points: { { number } } = { { x, g + 0.5, z, 1.5 }, { x, g + 3, z, 1.5 }, { x, g + 5.4, z, 1.5 } }
	for _, b in FishingSpots.buoys(x, z, face) do
		table.insert(points, { b[1], T.water(b[1], b[2]) or g, b[2], 1 })
	end
	for _, b in builds do
		if (b.at.x - x) ^ 2 + (b.at.z - z) ^ 2 < 120 * 120 then
			for _, piece in b.bp.pieces do
				if piece.col then
					for _, p in points do
						if inPiece(b, piece, p[1], p[2], p[3], p[4]) then
							return false
						end
					end
				end
			end
		end
	end
	return true
end

-- Offsets within `reach` studs, nearest first (then west to east, north to south).
local function ring(reach: number): { { number } }
	local out = {}
	for dx = -reach, reach do
		for dz = -reach, reach do
			if dx * dx + dz * dz <= reach * reach then
				table.insert(out, { dx, dz, dx * dx + dz * dz })
			end
		end
	end
	table.sort(out, function(a: { number }, b: { number }): boolean
		if a[3] ~= b[3] then
			return a[3] < b[3]
		elseif a[1] ~= b[1] then
			return a[1] < b[1]
		end
		return a[2] < b[2]
	end)
	return out
end

-- The spot nearest to (cx, cz) within `reach` whole studs, clear of `builds`, or nil.
function FishingSpots.find(
	T: Terrain,
	builds: { any },
	cx: number,
	cz: number,
	reach: number
): { x: number, z: number }?
	local near = {}
	for _, b in builds do
		if (b.at.x - cx) ^ 2 + (b.at.z - cz) ^ 2 < (reach + 120) ^ 2 then
			table.insert(near, b)
		end
	end
	for _, o in ring(reach) do
		local x, z = cx + o[1], cz + o[2]
		if FishingSpots.ok(T, x, z) then
			local face = FishingSpots.face(T.height, T.water, x, z) :: number
			if FishingSpots.clearOf(T, near, x, z, face) then
				return { x = x, z = z }
			end
		end
	end
	return nil
end

return FishingSpots
