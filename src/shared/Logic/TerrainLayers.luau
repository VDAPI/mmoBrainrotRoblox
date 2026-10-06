--!strict
-- Shared building blocks of the height-function terrains (S26): the starting city (Logic/TownTerrain) and the
-- Whispering Meadows (Logic/MeadowsTerrain). Pure, no Roblox API.
--   * smoothstep / smootherstep, the city's sine noise (unchanged formula) and a hashed value noise (fbm) that
--     does not repeat like the sines,
--   * polyline helpers (nearest point with arc length), soft rectangles and ellipses,
--   * `voxels`: turns height / material / water functions into the material and occupancy arrays of
--     Terrain:WriteVoxels (resolution 4). The city's voxels go through it with the same result as before.

local TerrainLayers = {}

TerrainLayers.VOXEL = 4

function TerrainLayers.smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function TerrainLayers.smootherstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

function TerrainLayers.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Smooth deterministic noise from sines, about 0..1 (the city's formula since S21; do not change it).
function TerrainLayers.sineNoise(x: number, z: number, seed: number): number
	return 0.5
		+ 0.22 * math.sin(0.9 * x + seed * 1.3) * math.cos(0.8 * z - seed * 0.7)
		+ 0.18 * math.sin(0.53 * (x + z) + seed * 2.1)
		+ 0.1 * math.cos(1.7 * x - 1.1 * z + seed)
end

-- Stable pseudo-random 0..1 for a lattice point.
local function hash(ix: number, iz: number, seed: number): number
	local n = math.sin(ix * 127.1 + iz * 311.7 + seed * 74.7) * 43758.5453
	return n - math.floor(n)
end
TerrainLayers.hash = hash

-- Value noise 0..1 with smooth (quintic) interpolation between lattice points one unit apart.
function TerrainLayers.valueNoise(x: number, z: number, seed: number): number
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = x - ix, z - iz
	local ux = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
	local uz = fz * fz * fz * (fz * (fz * 6 - 15) + 10)
	local a = hash(ix, iz, seed)
	local b = hash(ix + 1, iz, seed)
	local c = hash(ix, iz + 1, seed)
	local d = hash(ix + 1, iz + 1, seed)
	return a + (b - a) * ux + (c - a) * uz + (a - b - c + d) * ux * uz
end

-- Fractal value noise 0..1: `octaves` layers, each twice as fine and half as strong. `scale` = studs per lattice
-- cell of the first octave.
function TerrainLayers.fbm(x: number, z: number, scale: number, seed: number, octaves: number?): number
	local total, amp, norm = 0, 1, 0
	local f = 1 / scale
	for i = 1, octaves or 3 do
		total += amp * TerrainLayers.valueNoise(x * f + i * 17.3, z * f - i * 9.1, seed + i * 13)
		norm += amp
		amp *= 0.5
		f *= 2
	end
	return total / norm
end

-- Distance from (x, z) to segment a-b and the segment parameter t (0..1) of the nearest point.
function TerrainLayers.segDist(ax: number, az: number, bx: number, bz: number, x: number, z: number): (number, number)
	local vx, vz = bx - ax, bz - az
	local len2 = vx * vx + vz * vz
	local t = 0
	if len2 > 0 then
		t = math.clamp(((x - ax) * vx + (z - az) * vz) / len2, 0, 1)
	end
	local nx, nz = ax + vx * t, az + vz * t
	return math.sqrt((x - nx) ^ 2 + (z - nz) ^ 2), t
end

-- Distance outside an axis-aligned rectangle { x1, z1, x2, z2 } (0 inside).
function TerrainLayers.rectDist(rect: { number }, x: number, z: number): number
	local dx = math.max(rect[1] - x, 0, x - rect[3])
	local dz = math.max(rect[2] - z, 0, z - rect[4])
	return math.sqrt(dx * dx + dz * dz)
end

-- 1 inside the rectangle, falling smoothly to 0 at `blend` studs outside.
function TerrainLayers.softRect(rect: { number }, blend: number, x: number, z: number): number
	local d = TerrainLayers.rectDist(rect, x, z)
	if d <= 0 then
		return 1
	end
	return 1 - TerrainLayers.smoothstep(d / blend)
end

-- Normalised distance from an ellipse centre (1 on its outline), rotated by `rot` degrees.
function TerrainLayers.ellipse(
	cx: number,
	cz: number,
	rx: number,
	rz: number,
	rot: number,
	x: number,
	z: number
): number
	local r = math.rad(rot)
	local c, s = math.cos(r), math.sin(r)
	local dx, dz = x - cx, z - cz
	local u = (dx * c + dz * s) / rx
	local v = (-dx * s + dz * c) / rz
	return math.sqrt(u * u + v * v)
end

-- Polyline sampled for fast nearest-point queries: points { {x, z} }, cumulative arc length, bounding box.
export type Line = {
	pts: { { number } },
	along: { number }, -- arc length at every point
	length: number,
	box: { number }, -- x1, z1, x2, z2
}

function TerrainLayers.line(pts: { { number } }): Line
	local along = { 0 }
	local box = { math.huge, math.huge, -math.huge, -math.huge }
	for i, p in pts do
		if i > 1 then
			local q = pts[i - 1]
			along[i] = along[i - 1] + math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2)
		end
		box[1], box[2] = math.min(box[1], p[1]), math.min(box[2], p[2])
		box[3], box[4] = math.max(box[3], p[1]), math.max(box[4], p[2])
	end
	return { pts = pts, along = along, length = along[#along], box = box }
end

-- Flat {x1, z1, x2, z2, ...} -> { {x, z} }.
function TerrainLayers.pairs(flat: { number }): { { number } }
	local out = {}
	for i = 1, #flat - 1, 2 do
		table.insert(out, { flat[i], flat[i + 1] })
	end
	return out
end

-- Nearest point of a polyline: distance, arc length there, segment index and parameter.
function TerrainLayers.nearest(line: Line, x: number, z: number): (number, number, number, number)
	local best, bestS, bestI, bestT = math.huge, 0, 1, 0
	local pts = line.pts
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local d, t = TerrainLayers.segDist(a[1], a[2], b[1], b[2], x, z)
		if d < best then
			best, bestI, bestT = d, i, t
			bestS = line.along[i] + (line.along[i + 1] - line.along[i]) * t
		end
	end
	return best, bestS, bestI, bestT
end

-- Point at arc length `s` of a polyline, with the unit direction there.
function TerrainLayers.pointAt(line: Line, s: number): (number, number, number, number)
	local pts = line.pts
	local along = line.along
	s = math.clamp(s, 0, line.length)
	for i = 1, #pts - 1 do
		if s <= along[i + 1] or i == #pts - 1 then
			local a, b = pts[i], pts[i + 1]
			local seg = along[i + 1] - along[i]
			local t = if seg > 0 then (s - along[i]) / seg else 0
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(1e-6, math.sqrt(dx * dx + dz * dz))
			return a[1] + dx * t, a[2] + dz * t, dx / len, dz / len
		end
	end
	local p = pts[#pts]
	return p[1], p[2], 1, 0
end

-- Value of a per-point list at a segment index and parameter (widths, heights along a polyline).
function TerrainLayers.atSegment(values: { number }, i: number, t: number): number
	local a = values[i]
	local b = values[i + 1] or a
	return a + (b - a) * t
end

export type Voxels = { materials: { { { string } } }, occupancy: { { { number } } } }
-- Ground height at a column and an optional per-column record the material and water functions read (the Meadows
-- keep their road / stream / lake lookups there so every column is probed once).
export type SampleFn = (x: number, z: number) -> (number, any)
export type MaterialFn = (x: number, z: number, h: number, slope: number, info: any) -> string
-- Water surface over a column with ground height `h`, or nil when the column is dry.
export type WaterFn = (x: number, z: number, h: number, info: any) -> number?

-- Voxel block for Terrain:WriteVoxels (resolution 4): nx * ny * nz cells, cell [i][j][k] covers
-- x0 + 4(i-1) .. x0 + 4i, yBottom + 4(j-1) .. yBottom + 4j, z0 + 4(k-1) .. z0 + 4k (map-relative studs).
-- Ground fills each cell up to the height at its centre column; cells between the ground and the water surface
-- are water. Material names are strings; the writer converts them to Enum.Material.
function TerrainLayers.voxels(
	sample: SampleFn,
	material: MaterialFn,
	water: WaterFn,
	x0: number,
	z0: number,
	nx: number,
	nz: number,
	yBottom: number,
	ny: number
): Voxels
	local V = TerrainLayers.VOXEL
	-- heights at cell centres, with a one-cell ring for the slope
	local heights: { { number } } = {}
	local infos: { { any } } = {}
	for i = 0, nx + 1 do
		local row, info = {}, {}
		for k = 0, nz + 1 do
			row[k], info[k] = sample(x0 + V * (i - 0.5), z0 + V * (k - 0.5))
		end
		heights[i], infos[i] = row, info
	end
	local materials: { { { string } } } = table.create(nx)
	local occupancy: { { { number } } } = table.create(nx)
	for i = 1, nx do
		local mi, oi = table.create(ny), table.create(ny)
		for j = 1, ny do
			mi[j], oi[j] = table.create(nz, "Air"), table.create(nz, 0)
		end
		for k = 1, nz do
			local x, z = x0 + V * (i - 0.5), z0 + V * (k - 0.5)
			local h = heights[i][k]
			local info = infos[i][k]
			local gx = (heights[i + 1][k] - heights[i - 1][k]) / (2 * V)
			local gz = (heights[i][k + 1] - heights[i][k - 1]) / (2 * V)
			local mat = material(x, z, h, math.sqrt(gx * gx + gz * gz), info)
			local level = water(x, z, h, info)
			for j = 1, ny do
				local y = yBottom + V * (j - 1)
				local solid = math.clamp((h - y) / V, 0, 1)
				if solid >= 0.5 or (solid > 0 and level == nil) then
					mi[j][k], oi[j][k] = mat, solid
				elseif level and y < level then
					mi[j][k], oi[j][k] = "Water", math.clamp((level - y) / V, 0, 1)
				end
			end
		end
		materials[i], occupancy[i] = mi, oi
	end
	return { materials = materials, occupancy = occupancy }
end

return TerrainLayers
