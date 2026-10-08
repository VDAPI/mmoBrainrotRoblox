--!strict
-- Shared height function of the shaped regions (S45): one pure function per map built from its shape data
-- (Data/Terrain/<map>, types in Data/Terrain/Types) and its roads, lakes, streams and sites (Data/Areas/<map>). The
-- terrain writer (server), the layout and the generator (Logic/WorldGen), the monster groups (Logic/AreaSpawns via
-- Logic/MapTerrain), the client decorations, the tools and the tests read the same numbers.
--
-- The algorithms are the ones the Whispering Meadows proved in S26 (Logic/MeadowsTerrain, which stays as it is): a
-- 64-stud grid of polyline segments, road profiles sampled every 4 studs, averaged over +-24 studs and limited to an
-- 11% grade, the two nearest roads mixed at junctions, stream levels taken from the lowest ground across the channel
-- minus 1.1 studs and never rising downstream, a gentle valley beside the water, embankments up to bridges, fords.
-- What the Meadows had as one-off features (the ravine, the quarry, the marsh) are lists here: hills, ridges with a
-- scarp side, plateaus with per-vertex cliffs, gorges, basins and marshes with islands.

local AreaTypes = require("../Data/Areas/Types")
local Areas = require("../Data/Areas")
local Shapes = require("../Data/Terrain")
local TerrainLayers = require("./TerrainLayers")
local ShapeTypes = require("../Data/Terrain/Types")

local RegionTerrain = {}

local smoothstep = TerrainLayers.smoothstep
local smootherstep = TerrainLayers.smootherstep
local lerp = TerrainLayers.lerp
local fbm = TerrainLayers.fbm
local segDist = TerrainLayers.segDist
local softRect = TerrainLayers.softRect

local ROAD_SHOULDER = 11 -- studs beside a road over which the ground blends back to its own height
local ROAD_GRADE = 0.11 -- max rise per stud of a road profile
local RAMP_SHOULDER = 6
local STEP = 4 -- sampling step of the road and stream profiles
local CELL = 64
local LAKE_RAGGED = 9
local STEEP = math.tan(math.rad(42))

RegionTerrain.VOXEL = TerrainLayers.VOXEL
RegionTerrain.HALF = 800
RegionTerrain.WALKABLE_SLOPE = math.tan(math.rad(32)) -- the Meadows' limit
-- Monster groups and arrivals keep this far from any water of the terrain (marsh pools, basins, streams).
RegionTerrain.WATER_CLEARANCE = 12
-- S46: ... and this far from lava and glowing cracks (lava is scenery: no damage, nobody stands next to it).
RegionTerrain.LAVA_CLEARANCE = 12
-- Every terrain material a region may paint (the writer converts the names to Enum.Material).
RegionTerrain.MATERIALS = {
	"Grass",
	"LeafyGrass",
	"Ground",
	"Mud",
	"Rock",
	"Slate",
	"Sandstone",
	"Cobblestone",
	"Sand",
	"Salt",
	"Basalt",
	"CrackedLava",
	"Snow",
	"Glacier",
	"Ice",
	"Limestone",
	"Pavement",
	"Asphalt",
	"Concrete",
	"Brick",
	"WoodPlanks",
	"Water",
	"Air",
}

local MATERIAL_SET: { [string]: boolean } = {}
for _, name in RegionTerrain.MATERIALS do
	MATERIAL_SET[name] = true
end
RegionTerrain.MATERIAL_SET = MATERIAL_SET

-- Column record shared by the height, material and water of one column.
export type Info = {
	road: number, -- distance past the road edge (negative on the road)
	roadMat: string, -- terrain material of that road
	ramp: boolean,
	stream: number, -- index of the nearest stream (0: none)
	streamD: number, -- distance past the water edge of that stream
	streamW: number, -- its water level
	streamDepth: number,
	lake: number, -- signed distance to the lake shore line
	marsh: number, -- weight 0..1 of the strongest marsh
	marshWater: number, -- water level of that marsh
	gorge: boolean, -- inside a gorge (floor or walls)
	plateau: boolean, -- on a plateau's top or edge
	basin: number, -- 0..1 how deep in a basin
	-- S46 (math.huge / false / 0 / "" where the shape has none)
	lava: number, -- distance past the edge of the nearest lava or glowing crack (negative inside)
	lavaD: number, -- distance past the edge of the nearest lava river or pool
	lavaLevel: number, -- its surface
	lavaKind: string, -- "" | "river" | "pool" | "crust" | "island"
	lavaBank: number, -- its bank width
	crack: number, -- distance past the edge of the nearest crack
	crackGlow: boolean,
	rock: boolean, -- on a mesa or a spire (top, wall or scree)
	cap: string, -- material of a mesa's or spire's top here ("" elsewhere)
	dune: number, -- 0..1 weight of a dune field
	duneMat: string,
	dry: number, -- 0..1 weight of a dry lake's floor
	dryE: number, -- normalised distance from the dry lake's centre (1 on the old shore)
	dryLake: number, -- index of that dry lake (0: none)
}

export type Crossing = {
	x: number,
	z: number,
	dirX: number, -- along the road
	dirZ: number,
	span: number, -- length a bridge needs along the road (the water channel, plus 4 studs)
	deck: number, -- road surface height at the crossing (before the stream cut it)
	water: number,
	kind: string, -- "stone" | "wood" | "ford"
	road: number,
	stream: number, -- index of the stream (or of the lava river when `lava`)
	lava: boolean?, -- S46: a road over a lava river (`water` is the lava surface)
}

export type Terrain = {
	map: string,
	shape: ShapeTypes.Shape,
	areas: AreaTypes.MapAreas,
	VOXEL: number,
	HALF: number,
	WALKABLE_SLOPE: number,
	MATERIALS: { string },
	sample: (x: number, z: number) -> (number, Info),
	height: (x: number, z: number) -> number,
	water: (x: number, z: number) -> number?,
	isWater: (x: number, z: number) -> boolean,
	slope: (x: number, z: number, step: number?) -> number,
	walkable: (x: number, z: number) -> boolean,
	dryAround: (x: number, z: number, r: number) -> boolean,
	themeAt: (x: number, z: number) -> string,
	materialAt: (x: number, z: number, h: number, slope: number, info: Info) -> string,
	material: (x: number, z: number) -> string,
	voxels: (x0: number, z0: number, nx: number, nz: number, yBottom: number, ny: number) -> TerrainLayers.Voxels,
	crossings: () -> { Crossing },
	streamLevel: (index: number, s: number) -> number,
	streamLine: (index: number) -> TerrainLayers.Line,
	roadLine: (index: number) -> TerrainLayers.Line,
	roadDistance: (x: number, z: number) -> number,
	streamDistance: (x: number, z: number) -> number,
	lakeDistance: (x: number, z: number) -> number,
	marshWeight: (x: number, z: number) -> number,
	gorgeFloor: (x: number, z: number) -> (boolean, number),
	plateauAt: (x: number, z: number) -> (boolean, number),
	basinWeight: (x: number, z: number) -> number,
	-- S46
	lava: (x: number, z: number) -> number?,
	lavaDistance: (x: number, z: number) -> number,
	crackDistance: (x: number, z: number) -> (number, boolean),
	lavaLine: (index: number) -> TerrainLayers.Line,
	lavaLevel: (index: number, s: number) -> number,
	rockAt: (x: number, z: number) -> boolean,
	duneWeight: (x: number, z: number) -> number,
	dryWeight: (x: number, z: number) -> number,
}

-- Spatial index of polyline segments ---------------------------------------------------------------------------

type Seg = { line: number, seg: number, ax: number, az: number, bx: number, bz: number }
type Grid = { [number]: { Seg } }

local function key(cx: number, cz: number): number
	return (cx + 512) * 1024 + (cz + 512)
end

-- Every segment of every line goes into the cells its bounding box (grown by `reach(line)`) touches.
local function index(lines: { TerrainLayers.Line }, reach: (line: number) -> number): Grid
	local grid: Grid = {}
	for li, line in lines do
		local r = reach(li)
		local pts = line.pts
		for si = 1, #pts - 1 do
			local a, b = pts[si], pts[si + 1]
			local seg: Seg = { line = li, seg = si, ax = a[1], az = a[2], bx = b[1], bz = b[2] }
			local x1 = math.floor((math.min(a[1], b[1]) - r) / CELL)
			local x2 = math.floor((math.max(a[1], b[1]) + r) / CELL)
			local z1 = math.floor((math.min(a[2], b[2]) - r) / CELL)
			local z2 = math.floor((math.max(a[2], b[2]) + r) / CELL)
			for cx = x1, x2 do
				for cz = z1, z2 do
					local k = key(cx, cz)
					local list = grid[k]
					if not list then
						list = {}
						grid[k] = list
					end
					table.insert(list, seg)
				end
			end
		end
	end
	return grid
end

-- Nearest indexed segment: distance, line, segment index, parameter (math.huge when no candidate is near).
local function nearestIn(grid: Grid, x: number, z: number): (number, number, number, number)
	local list = grid[key(math.floor(x / CELL), math.floor(z / CELL))]
	local best, bl, bs, bt = math.huge, 0, 0, 0
	if list then
		for _, s in list do
			local d, t = segDist(s.ax, s.az, s.bx, s.bz, x, z)
			if d < best then
				best, bl, bs, bt = d, s.line, s.seg, t
			end
		end
	end
	return best, bl, bs, bt
end

local function arcAt(line: TerrainLayers.Line, si: number, t: number): number
	return line.along[si] + (line.along[si + 1] - line.along[si]) * t
end

local function profileAt(profile: { number }, s: number): number
	local f = s / STEP + 1
	local i = math.clamp(math.floor(f), 1, #profile)
	local j = math.min(i + 1, #profile)
	return lerp(profile[i], profile[j], math.clamp(f - i, 0, 1))
end

local function inBox(b: { number }, x: number, z: number): boolean
	return x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4]
end

-- Signed distance to a closed polygon { x1, z1, ... } (negative inside), the nearest edge and its parameter.
local function polygonDist(poly: { number }, x: number, z: number): (number, number, number)
	local n = #poly // 2
	local best, bestI, bestT = math.huge, 1, 0
	local inside = false
	for i = 1, n do
		local j = i % n + 1
		local ax, az = poly[2 * i - 1], poly[2 * i]
		local bx, bz = poly[2 * j - 1], poly[2 * j]
		local d, t = segDist(ax, az, bx, bz, x, z)
		if d < best then
			best, bestI, bestT = d, i, t
		end
		if (az > z) ~= (bz > z) and x < (bx - ax) * (z - az) / (bz - az) + ax then
			inside = not inside
		end
	end
	return if inside then -best else best, bestI, bestT
end

-- S46: seams of a polygon pattern (salt crust, crusted lava): how close (x, z) lies to the border between two cells
-- of a jittered grid `size` studs wide (0 on the border).
local function cellSeam(x: number, z: number, size: number, seed: number): number
	local gx, gz = math.floor(x / size), math.floor(z / size)
	local d1, d2 = math.huge, math.huge
	for i = -1, 1 do
		for k = -1, 1 do
			local cx, cz = gx + i, gz + k
			local px = (cx + 0.15 + 0.7 * TerrainLayers.hash(cx, cz, seed)) * size
			local pz = (cz + 0.15 + 0.7 * TerrainLayers.hash(cx, cz, seed + 7)) * size
			local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
			if d < d1 then
				d1, d2 = d, d1
			elseif d < d2 then
				d2 = d
			end
		end
	end
	return (d2 - d1) / 2
end
RegionTerrain.cellSeam = cellSeam

-- Builds the height function of one map --------------------------------------------------------------------------

function RegionTerrain.new(shape: ShapeTypes.Shape, areas: AreaTypes.MapAreas): Terrain
	local SEED = shape.seed
	local LAKE = shape.lakeLevel
	local VALLEY = if shape.valley then shape.valley.slope else 0.17
	local VALLEY_REACH = if shape.valley then shape.valley.reach else 50

	-- Roads
	local ROADS = areas.roads
	local roadLines: { TerrainLayers.Line } = {}
	local roadMats: { string } = {}
	for i, road in ROADS do
		table.insert(roadLines, TerrainLayers.line(TerrainLayers.pairs(road.points)))
		roadMats[i] = if MATERIAL_SET[road.material] then road.material else "Ground"
	end
	local roadGrid = index(roadLines, function(li: number): number
		return ROADS[li].width / 2 + ROAD_SHOULDER + 2
	end)

	-- Streams
	local STREAMS: { AreaTypes.Stream } = areas.streams or {}
	local streamLines: { TerrainLayers.Line } = {}
	for _, stream in STREAMS do
		table.insert(streamLines, TerrainLayers.line(TerrainLayers.pairs(stream.points)))
	end
	local streamGrid = index(streamLines, function(li: number): number
		local widest = 0
		for _, w in STREAMS[li].widths do
			widest = math.max(widest, w)
		end
		return widest / 2 + math.max(STREAMS[li].bank, VALLEY_REACH) + 2
	end)

	-- Ridges
	type RidgeData =
		{ line: TerrainLayers.Line, hs: { number }, ws: { number }, box: { number }, src: ShapeTypes.Ridge }
	local ridges: { RidgeData } = {}
	for _, ridge in shape.ridges do
		local pts, hs, ws = {}, {}, {}
		local reach = 0
		for _, p in ridge.pts do
			table.insert(pts, { p[1], p[2] })
			table.insert(hs, p[3])
			table.insert(ws, p[4])
			reach = math.max(reach, p[4], ridge.cliff or 0)
		end
		local line = TerrainLayers.line(pts)
		table.insert(ridges, {
			line = line,
			hs = hs,
			ws = ws,
			box = { line.box[1] - reach, line.box[2] - reach, line.box[3] + reach, line.box[4] + reach },
			src = ridge,
		})
	end

	-- Plateaus
	type PlateauData = { src: ShapeTypes.Plateau, box: { number }, maxCliff: number }
	local plateaus: { PlateauData } = {}
	for _, p in shape.plateaus do
		local maxCliff = 0
		if type(p.cliff) == "number" then
			maxCliff = p.cliff
		else
			for _, c in p.cliff :: { number } do
				maxCliff = math.max(maxCliff, c)
			end
		end
		local box
		if p.poly then
			box = { math.huge, math.huge, -math.huge, -math.huge }
			for i = 1, #p.poly - 1, 2 do
				box[1], box[2] = math.min(box[1], p.poly[i]), math.min(box[2], p.poly[i + 1])
				box[3], box[4] = math.max(box[3], p.poly[i]), math.max(box[4], p.poly[i + 1])
			end
		else
			local r = math.max(p.rx or 0, p.rz or 0)
			box = { (p.x or 0) - r, (p.z or 0) - r, (p.x or 0) + r, (p.z or 0) + r }
		end
		box = { box[1] - maxCliff, box[2] - maxCliff, box[3] + maxCliff, box[4] + maxCliff }
		table.insert(plateaus, { src = p, box = box, maxCliff = maxCliff })
	end

	-- Gorges
	type GorgeData = { src: ShapeTypes.Gorge, line: TerrainLayers.Line, box: { number } }
	local gorges: { GorgeData } = {}
	for _, g in shape.gorges do
		local pts = {}
		local reach = 0
		for _, p in g.pts do
			table.insert(pts, { p.x, p.z })
			reach = math.max(reach, p.half + g.wall + 14)
		end
		local line = TerrainLayers.line(pts)
		table.insert(gorges, {
			src = g,
			line = line,
			box = { line.box[1] - reach, line.box[2] - reach, line.box[3] + reach, line.box[4] + reach },
		})
	end

	-- Lakes
	local LAKES = areas.lakes
	local lakeBoxes: { { number } } = {}
	for _, lake in LAKES do
		local r = lake.r + shape.lakeShore + 10
		table.insert(lakeBoxes, { lake.x - r, lake.z - r, lake.x + r, lake.z + r })
	end

	-- S46: dunes, mesas, spires, cracks, dry lakes and lava (all optional; maps without them are unchanged).
	local DUNES: { ShapeTypes.Dunes } = shape.dunes or {}
	local MESAS: { ShapeTypes.Mesa } = shape.mesas or {}
	local SPIRES: { ShapeTypes.Spire } = shape.spires or {}
	local CRACKS: { ShapeTypes.Crack } = shape.cracks or {}
	local DRYLAKES: { ShapeTypes.DryLake } = shape.drylakes or {}
	local LAVA: ShapeTypes.Lava = shape.lava or { rivers = {}, pools = {}, falls = {} }
	local CAP = shape.capMaterial or "Basalt"
	local FALLBACK = shape.fallback or "LeafyGrass"
	local LAVA_REACH = 36 -- lava and crack distances are exact up to this far from the edge

	local mesaBoxes: { { number } } = {}
	for _, m in MESAS do
		local reach = m.cliff + m.skirt + m.ragged * 2 + 4
		local box
		if m.poly then
			box = { math.huge, math.huge, -math.huge, -math.huge }
			for i = 1, #m.poly - 1, 2 do
				box[1], box[2] = math.min(box[1], m.poly[i]), math.min(box[2], m.poly[i + 1])
				box[3], box[4] = math.max(box[3], m.poly[i]), math.max(box[4], m.poly[i + 1])
			end
		else
			local r = math.max(m.rx or 0, m.rz or 0)
			box = { (m.x or 0) - r, (m.z or 0) - r, (m.x or 0) + r, (m.z or 0) + r }
		end
		table.insert(mesaBoxes, { box[1] - reach, box[2] - reach, box[3] + reach, box[4] + reach })
	end

	local crackLines: { TerrainLayers.Line } = {}
	for _, c in CRACKS do
		table.insert(crackLines, TerrainLayers.line(TerrainLayers.pairs(c.points)))
	end
	local crackGrid = index(crackLines, function(li: number): number
		return CRACKS[li].width / 2 + LAVA_REACH
	end)

	local RIVERS = LAVA.rivers
	local POOLS = LAVA.pools
	local riverLines: { TerrainLayers.Line } = {}
	for _, r in RIVERS do
		table.insert(riverLines, TerrainLayers.line(TerrainLayers.pairs(r.points)))
	end
	local riverGrid = index(riverLines, function(li: number): number
		local widest = 0
		for _, w in RIVERS[li].widths do
			widest = math.max(widest, w)
		end
		return widest / 2 + math.max(RIVERS[li].bank, LAVA_REACH) + 2
	end)
	local poolBoxes: { { number } } = {}
	for _, p in POOLS do
		local r = math.max(p.rx, p.rz) * 1.1 + math.max(p.bank, LAVA_REACH) + 2
		table.insert(poolBoxes, { p.x - r, p.z - r, p.x + r, p.z + r })
	end
	local dryEdge: { number } = {}
	for i, dl in DRYLAKES do
		dryEdge[i] = math.clamp(dl.shore / ((dl.rx + dl.rz) / 2), 0.05, 0.6)
	end

	-- Layers --------------------------------------------------------------------------------------------------

	local function baseHeight(x: number, z: number): number
		local amp = shape.detail.amp
		for _, zone in shape.zones do
			local w = softRect(zone.rect, zone.blend, x, z)
			if w > 0 then
				amp = lerp(amp, zone.amp, w)
			end
		end
		return shape.swell.amp * fbm(x, z, shape.swell.scale, SEED, 2)
			+ amp * fbm(x, z, shape.detail.scale, SEED + 1, 3)
			+ shape.fine.amp * fbm(x, z, shape.fine.scale, SEED + 2, 2)
	end

	local function hills(x: number, z: number): number
		local add = 0
		for _, hill in shape.hills do
			local reach = math.max(hill.rx, hill.rz)
			if math.abs(x - hill.x) < reach and math.abs(z - hill.z) < reach then
				local d = TerrainLayers.ellipse(hill.x, hill.z, hill.rx, hill.rz, hill.rot, x, z)
				if d < 1 then
					add += hill.h * smoothstep((1 - d) / (1 - hill.flat))
				end
			end
		end
		return add
	end

	local function ridgeAdd(x: number, z: number): number
		local add = 0
		for _, r in ridges do
			if inBox(r.box, x, z) then
				local d, _, si, t = TerrainLayers.nearest(r.line, x, z)
				local w = TerrainLayers.atSegment(r.ws, si, t)
				local steep = r.src.steep
				if steep then
					local a, b = r.line.pts[si], r.line.pts[si + 1]
					local cross = (b[1] - a[1]) * (z - a[2]) - (b[2] - a[2]) * (x - a[1])
					-- the left side of travel has a negative cross product with z pointing "down" the map
					local side = if cross < 0 then 1 else -1
					if side == steep then
						w = r.src.cliff or w * 0.25
					end
				end
				if d < w then
					local f = 1 - smoothstep(d / w)
					local sharp = r.src.sharp or 1
					if sharp ~= 1 then
						f = f ^ sharp
					end
					add += TerrainLayers.atSegment(r.hs, si, t) * f
				end
			end
		end
		return add
	end

	-- Plateau weight 0..1 (1 on the top) and its height, for the strongest plateau at a point.
	local function plateauOf(x: number, z: number): (number, number)
		local bestW, bestY = 0, 0
		for _, p in plateaus do
			if inBox(p.box, x, z) then
				local src = p.src
				local d, cliff
				if src.poly then
					local i, t
					d, i, t = polygonDist(src.poly, x, z)
					if type(src.cliff) == "number" then
						cliff = src.cliff
					else
						local list = src.cliff :: { number }
						local n = #list
						cliff = lerp(list[i], list[i % n + 1], t)
					end
				else
					local e =
						TerrainLayers.ellipse(src.x or 0, src.z or 0, src.rx or 1, src.rz or 1, src.rot or 0, x, z)
					d = (e - 1) * ((src.rx or 1) + (src.rz or 1)) / 2
					cliff = src.cliff :: number
				end
				-- the edge line wanders a little, so the scarp is not ruled
				d += 4 * (fbm(x, z, 23, SEED + 31, 2) - 0.5)
				local w = if d <= 0 then 1 elseif d < cliff then 1 - smootherstep(d / cliff) else 0
				if w > bestW then
					bestW = w
					bestY = src.y + (src.noise or 0) * (fbm(x, z, 40, SEED + 32, 2) - 0.5) * 2
				end
			end
		end
		return bestW, bestY
	end

	-- Gorge: distance to the centre line, floor half-width, floor height, wall width (nil far away).
	local function gorgeAt(x: number, z: number): (number?, number, number, number)
		local best: number?, bh, bf, bw = nil, 0, 0, 0
		for gi, g in gorges do
			if inBox(g.box, x, z) then
				local d, _, si, t = TerrainLayers.nearest(g.line, x, z)
				local a, b = g.src.pts[si], g.src.pts[si + 1]
				local half = lerp(a.half, b.half, t) + 6 * (fbm(x, z, 26, SEED + 5 + gi, 2) - 0.5)
				if best == nil or d - half < (best :: number) - bh then
					best, bh, bf, bw = d, half, lerp(a.floor, b.floor, t), g.src.wall
				end
			end
		end
		return best, bh, bf, bw
	end

	local function basins(x: number, z: number): (number, number)
		local sub, weight = 0, 0
		for _, b in shape.basins do
			local reach = math.max(b.rx, b.rz)
			if math.abs(x - b.x) < reach and math.abs(z - b.z) < reach then
				local d = TerrainLayers.ellipse(b.x, b.z, b.rx, b.rz, b.rot, x, z)
				if d < 1 then
					local w = smoothstep((1 - d) / (1 - b.flat))
					sub += b.depth * w
					weight = math.max(weight, w)
				end
			end
		end
		return sub, weight
	end

	-- Marsh weight 0..1 of one marsh (islands cut out), and of the strongest marsh with its index.
	local function oneMarsh(m: ShapeTypes.Marsh, mi: number, x: number, z: number): number
		if math.abs(x - m.x) > m.rx * 1.6 or math.abs(z - m.z) > m.rz * 1.6 then
			return 0
		end
		local e = TerrainLayers.ellipse(m.x, m.z, m.rx, m.rz, 0, x, z)
		e += m.ragged * (fbm(x, z, 60, SEED + 14 + mi, 2) - 0.5) * 2
		return 1 - smoothstep((e - (1 - m.edge)) / m.edge)
	end

	local function islandMask(m: ShapeTypes.Marsh, x: number, z: number): (number, number)
		local best, h = 0, 0
		for _, isl in m.islands or {} :: { ShapeTypes.Island } do
			local reach = isl.r + 12
			local dx, dz = x - isl.x, z - isl.z
			if math.abs(dx) < reach and math.abs(dz) < reach then
				local d = math.sqrt(dx * dx + dz * dz) + 5 * (fbm(x, z, 17, SEED + 41, 2) - 0.5)
				local w = if d <= isl.r then 1 elseif d < isl.r + 12 then 1 - smoothstep((d - isl.r) / 12) else 0
				if w > best then
					best, h = w, isl.h
				end
			end
		end
		return best, h
	end

	local function marshAt(x: number, z: number): (number, number)
		local best, bestI = 0, 0
		for mi, m in shape.marshes do
			local w = oneMarsh(m, mi, x, z)
			if w > 0 then
				local cut = islandMask(m, x, z)
				w *= 1 - cut
			end
			if w > best then
				best, bestI = w, mi
			end
		end
		return best, bestI
	end

	local function marshWater(mi: number): number
		local m = shape.marshes[mi]
		return if m and m.water then m.water else LAKE
	end

	-- S46 layers ---------------------------------------------------------------------------------------------------

	-- Dune field: height added, the field's weight and its material.
	local function dunesAt(x: number, z: number): (number, number, string)
		for _, d in DUNES do
			local w = softRect(d.rect, d.blend, x, z)
			if w > 0 then
				local b = math.rad(d.wind)
				local along = x * math.sin(b) - z * math.cos(b) + d.wander * (fbm(x, z, 170, SEED + 50, 2) - 0.5) * 2
				local u = along / d.wave
				local f = u - math.floor(u)
				local prof
				if f < d.valley then
					prof = 0
				elseif f < 1 - d.lee then
					prof = smoothstep((f - d.valley) / (1 - d.lee - d.valley))
				else
					prof = 1 - smoothstep((f - (1 - d.lee)) / d.lee)
				end
				local amp = d.height * (0.6 + 0.4 * fbm(x, z, 140, SEED + 52, 2))
				return amp * prof * w, w, d.material or "Sand"
			end
		end
		return 0, 0, ""
	end

	-- Body of a mesa over the ground `g`: its height (nil outside) and whether the point is on the flat top.
	local function mesaHeight(mi: number, x: number, z: number, g: number): (number?, boolean)
		local m = MESAS[mi]
		local d
		if m.poly then
			d = polygonDist(m.poly, x, z)
		else
			local rx, rz = m.rx or 1, m.rz or 1
			d = (TerrainLayers.ellipse(m.x or 0, m.z or 0, rx, rz, m.rot or 0, x, z) - 1) * (rx + rz) / 2
		end
		-- a ragged outline cut by gullies
		d += m.ragged * ((fbm(x, z, 23, SEED + 60 + mi, 2) - 0.5) * 2 + 0.6 * (fbm(x, z, 8, SEED + 61 + mi, 1) - 0.5) * 2)
		if d <= 0 then
			return m.top + 0.6 * (fbm(x, z, 15, SEED + 62, 2) - 0.5), true
		end
		local foot = g + m.skirtH
		if d < m.cliff then
			return lerp(m.top, foot, smootherstep(d / m.cliff)), false
		end
		local s = d - m.cliff
		if s < m.skirt then
			return g + m.skirtH * (1 - s / m.skirt) ^ 1.3, false
		end
		return nil, false
	end

	-- Body of a spire over the ground `g`: its height (nil outside) and whether the point is on its cap.
	local function spireHeight(si: number, x: number, z: number, g: number): (number?, boolean)
		local s = SPIRES[si]
		local dx, dz = x - s.x, z - s.z
		if math.abs(dx) > s.r * 1.5 or math.abs(dz) > s.r * 1.5 then
			return nil, false
		end
		local d = math.sqrt(dx * dx + dz * dz)
		local a = math.atan2(dz, dx)
		local wob = fbm(s.x + math.cos(a) * 40, s.z + math.sin(a) * 40, 11, SEED + 70 + si, 2)
		local rr = s.r * (0.8 + 0.4 * wob)
		local k = 1
		if s.lean and s.asym and d > 0.01 then
			local b = math.rad(s.lean)
			k = 1 + s.asym * (dx * math.sin(b) - dz * math.cos(b)) / d
		end
		local t = d * k / rr
		local top = s.top or 0.25
		local f
		if t <= top then
			f = 1
		elseif t < 1 then
			f = 0.1 + 0.9 * (1 - ((t - top) / (1 - top)) ^ 2.4)
		elseif t < 1.4 then
			f = 0.1 * (1 - (t - 1) / 0.4) ^ 2
		else
			return nil, false
		end
		return g + s.h * f, f > 0.86
	end

	local function crackAt(x: number, z: number): (number, number)
		local d, li = nearestIn(crackGrid, x, z)
		if li == 0 then
			return math.huge, 0
		end
		local half = CRACKS[li].width / 2 * (0.7 + 0.6 * fbm(x, z, 13, SEED + 80, 2))
		return d - half, li
	end

	local function dryAt(x: number, z: number): (number, number, number)
		for i, dl in DRYLAKES do
			local reach = math.max(dl.rx, dl.rz) * 1.3
			if math.abs(x - dl.x) < reach and math.abs(z - dl.z) < reach then
				local e = TerrainLayers.ellipse(dl.x, dl.z, dl.rx, dl.rz, dl.rot, x, z)
					+ 0.06 * (fbm(x, z, 50, SEED + 90 + i, 2) - 0.5) * 2
				if e < 1.25 then
					local edge = dryEdge[i]
					return 1 - smoothstep((e - (1 - edge)) / edge), e, i
				end
			end
		end
		return 0, math.huge, 0
	end

	-- What the last call of `raw` found at its point (read by `sample` right after, never across points).
	local lastRock, lastCap, lastDune, lastDuneMat = false, "", 0, ""
	local lastDry, lastDryE, lastDryI, lastCrack, lastCrackI = 0, math.huge, 0, math.huge, 0

	-- Ground before flats, roads and water.
	local dryFloor: { number } = {}
	local function raw(x: number, z: number, noDry: boolean?): number
		local h = baseHeight(x, z) + hills(x, z) + ridgeAdd(x, z)
		local pw, py = plateauOf(x, z)
		if pw > 0 then
			h = lerp(h, py, pw)
		end
		lastRock, lastCap, lastDune, lastDuneMat = false, "", 0, ""
		lastDry, lastDryE, lastDryI, lastCrack, lastCrackI = 0, math.huge, 0, math.huge, 0
		if #DUNES > 0 then
			local add, w, mat = dunesAt(x, z)
			h += add
			lastDune, lastDuneMat = w, mat
		end
		if #MESAS > 0 then
			local g = h
			for mi, box in mesaBoxes do
				if inBox(box, x, z) then
					local mh, onTop = mesaHeight(mi, x, z, g)
					if mh and mh > h - 0.01 then
						h = math.max(h, mh)
						lastRock = true
						lastCap = if onTop then MESAS[mi].cap or "" else ""
					end
				end
			end
		end
		if #SPIRES > 0 then
			local g = h
			for si in SPIRES do
				local sh, onCap = spireHeight(si, x, z, g)
				if sh and sh > h - 0.01 then
					h = math.max(h, sh)
					lastRock = true
					lastCap = if onCap then SPIRES[si].cap or CAP else ""
				end
			end
		end
		local d, half, floor, wallW = gorgeAt(x, z)
		if d then
			local wall = wallW + 3 * (fbm(x, z, 11, SEED + 6, 2) - 0.5)
			if d < half then
				h = floor + 0.9 * (fbm(x, z, 9, SEED + 7, 2) - 0.5)
			elseif d < half + wall then
				h = floor + (h - floor) * smootherstep((d - half) / wall)
			end
		end
		local sub = basins(x, z)
		h -= sub
		for mi, m in shape.marshes do
			local mw = oneMarsh(m, mi, x, z)
			if mw > 0 then
				local target = m.level + m.amp * (fbm(x, z, m.scale, SEED + 9 + mi, 2) - 0.5) * 2
				local marshed = lerp(h, target, mw * m.strength)
				local cut, ih = islandMask(m, x, z)
				if cut > 0 then
					marshed = lerp(marshed, marshWater(mi) + ih, cut)
				end
				h = marshed
			end
		end
		if #DRYLAKES > 0 and not noDry then
			local w, e, i = dryAt(x, z)
			if i > 0 then
				lastDry, lastDryE, lastDryI = w, e, i
				if w > 0 then
					h = lerp(h, dryFloor[i] + 0.3 * (fbm(x, z, 24, SEED + 91, 2) - 0.5), w)
				end
			end
		end
		if #CRACKS > 0 then
			local cd, ci = crackAt(x, z)
			lastCrack, lastCrackI = cd, ci
			if ci > 0 and cd < 3 then
				h -= CRACKS[ci].depth * (1 - smoothstep(math.max(cd, 0) / 3))
			end
		end
		return h
	end

	for i, dl in DRYLAKES do
		dryFloor[i] = dl.y or raw(dl.x, dl.z, true) - dl.depth
	end

	local flatTargets: { number } = {}
	for i, flat in shape.flats do
		flatTargets[i] = flat.y or raw(flat.x, flat.z)
	end

	local function flats(x: number, z: number, h: number): number
		for i, flat in shape.flats do
			local reach = flat.r + flat.blend
			local dx, dz = x - flat.x, z - flat.z
			if math.abs(dx) < reach and math.abs(dz) < reach then
				local d = math.sqrt(dx * dx + dz * dz)
				if d < reach then
					local w = if d <= flat.r then 1 else 1 - smoothstep((d - flat.r) / flat.blend)
					h = lerp(h, flatTargets[i], w)
				end
			end
		end
		return h
	end

	local function preRoad(x: number, z: number): number
		return flats(x, z, raw(x, z))
	end

	-- Road profiles: the ground along the centre line every STEP studs, averaged over +-24 studs and limited to
	-- ROAD_GRADE both ways.
	local roadProfiles: { { number } } = {}
	for li, line in roadLines do
		local n = math.floor(line.length / STEP) + 1
		local rawY = table.create(n, 0)
		for i = 1, n do
			local x, z = TerrainLayers.pointAt(line, (i - 1) * STEP)
			rawY[i] = preRoad(x, z)
		end
		local smooth = table.create(n, 0)
		for i = 1, n do
			local sum, count = 0, 0
			for k = math.max(1, i - 6), math.min(n, i + 6) do
				sum += rawY[k]
				count += 1
			end
			smooth[i] = sum / count
		end
		local g = ROAD_GRADE * STEP
		for i = 2, n do
			smooth[i] = math.clamp(smooth[i], smooth[i - 1] - g, smooth[i - 1] + g)
		end
		for i = n - 1, 1, -1 do
			smooth[i] = math.clamp(smooth[i], smooth[i + 1] - g, smooth[i + 1] + g)
		end
		roadProfiles[li] = smooth
	end

	-- Junctions: a road that starts or ends on another road takes that road's height there, blended over 40 studs.
	for ri, line in roadLines do
		local profile = roadProfiles[ri]
		local n = #profile
		for _, endAt in { 0, line.length } do
			local ex, ez = TerrainLayers.pointAt(line, endAt)
			for oi, other in roadLines do
				if oi ~= ri and oi < ri then
					local d, _, si, t = TerrainLayers.nearest(other, ex, ez)
					if d < 3 then
						local target = profileAt(roadProfiles[oi], arcAt(other, si, t))
						local here = profileAt(profile, endAt)
						for i = 1, n do
							local off = math.abs((i - 1) * STEP - endAt)
							if off < 40 then
								profile[i] += (target - here) * (1 - smoothstep(off / 40))
							end
						end
						break
					end
				end
			end
		end
	end

	local function roadAt(x: number, z: number): (number, number, number, number)
		local d, li, si, t = nearestIn(roadGrid, x, z)
		if li == 0 then
			return math.huge, 0, 0, 0
		end
		return d, ROADS[li].width / 2, profileAt(roadProfiles[li], arcAt(roadLines[li], si, t)), li
	end

	local function roadWeight(d: number, half: number): number
		if d < half + 1 then
			return 1
		elseif d < half + ROAD_SHOULDER then
			return 1 - smoothstep((d - half - 1) / (ROAD_SHOULDER - 1))
		end
		return 0
	end

	local function roads(x: number, z: number, h: number): number
		local list = roadGrid[key(math.floor(x / CELL), math.floor(z / CELL))]
		if not list then
			return h
		end
		local d1, l1, s1, t1 = math.huge, 0, 0, 0
		local d2, l2, s2, t2 = math.huge, 0, 0, 0
		for _, seg in list do
			local d, t = segDist(seg.ax, seg.az, seg.bx, seg.bz, x, z)
			if seg.line == l1 then
				if d < d1 then
					d1, s1, t1 = d, seg.seg, t
				end
			elseif seg.line == l2 then
				if d < d2 then
					d2, s2, t2 = d, seg.seg, t
					if d2 < d1 then
						d1, l1, s1, t1, d2, l2, s2, t2 = d2, l2, s2, t2, d1, l1, s1, t1
					end
				end
			elseif d < d1 then
				d2, l2, s2, t2 = d1, l1, s1, t1
				d1, l1, s1, t1 = d, seg.line, seg.seg, t
			elseif d < d2 then
				d2, l2, s2, t2 = d, seg.line, seg.seg, t
			end
		end
		if l1 == 0 then
			return h
		end
		local w1 = roadWeight(d1, ROADS[l1].width / 2)
		if w1 <= 0 then
			return h
		end
		local y1 = profileAt(roadProfiles[l1], arcAt(roadLines[l1], s1, t1))
		local w2 = if l2 > 0 then roadWeight(d2, ROADS[l2].width / 2) else 0
		if w2 <= 0 then
			return lerp(h, y1, w1)
		end
		local y2 = profileAt(roadProfiles[l2], arcAt(roadLines[l2], s2, t2))
		local k1, k2 = w1 / (d1 + 2), w2 / (d2 + 2)
		return lerp(h, (y1 * k1 + y2 * k2) / (k1 + k2), math.max(w1, w2))
	end

	-- Ramps: explicit heights (nil ends take the ground there before the ramp).
	type RampData = { line: TerrainLayers.Line, ys: { number }, half: number, box: { number } }
	local ramps: { RampData } = {}
	for _, ramp in shape.ramps do
		local pts: { { number } } = {}
		local ys: { number } = {}
		for _, p in ramp.pts do
			table.insert(pts, { p[1], p[2] })
			table.insert(ys, p[3] or roads(p[1], p[2], preRoad(p[1], p[2])))
		end
		local line = TerrainLayers.line(pts)
		local r = ramp.w / 2 + RAMP_SHOULDER + 1
		table.insert(ramps, {
			line = line,
			ys = ys,
			half = ramp.w / 2,
			box = { line.box[1] - r, line.box[2] - r, line.box[3] + r, line.box[4] + r },
		})
	end

	local function rampAt(x: number, z: number): (number, number, number)
		local best, bestHalf, bestY = math.huge, 0, 0
		for _, ramp in ramps do
			if inBox(ramp.box, x, z) then
				local d, _, si, t = TerrainLayers.nearest(ramp.line, x, z)
				if d < best then
					best, bestHalf, bestY = d, ramp.half, TerrainLayers.atSegment(ramp.ys, si, t)
				end
			end
		end
		return best, bestHalf, bestY
	end

	local function applyRamps(x: number, z: number, h: number): number
		local d, half, y = rampAt(x, z)
		if d < half then
			return y
		elseif d < half + RAMP_SHOULDER then
			return lerp(y, h, smoothstep((d - half) / RAMP_SHOULDER))
		end
		return h
	end

	local function lakeDist(x: number, z: number): number
		local best = math.huge
		for i, lake in LAKES do
			if inBox(lakeBoxes[i], x, z) then
				local d = math.sqrt((x - lake.x) ^ 2 + (z - lake.z) ^ 2) - lake.r
				if d < best then
					best = d
				end
			end
		end
		if best < shape.lakeShore + LAKE_RAGGED then
			best += LAKE_RAGGED * (fbm(x, z, 34, SEED + 13, 2) - 0.5) * 2
		end
		return best
	end

	local function lakes(h: number, d: number): number
		if d <= 0 then
			return math.min(h, LAKE - math.clamp(0.6 + -d * 0.16, 0, shape.lakeDepth))
		elseif d < shape.lakeShore then
			return math.min(h, lerp(LAKE + 0.35, h, smoothstep(d / shape.lakeShore)))
		end
		return h
	end

	local function preStream(x: number, z: number): number
		local h = applyRamps(x, z, roads(x, z, preRoad(x, z)))
		return lakes(h, lakeDist(x, z))
	end

	local function depthAt(stream: AreaTypes.Stream, x: number, z: number): number
		local depth = stream.depth
		for _, s in (stream.shallows or {}) :: { { x: number, z: number, r: number, depth: number } } do
			local d = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2)
			if d < s.r then
				depth = lerp(depth, math.min(depth, s.depth), smoothstep((s.r - d) / (s.r * 0.5)))
			end
		end
		return depth
	end

	-- Water profiles of the streams.
	local streamProfiles: { { number } } = {}
	for si, stream in STREAMS do
		local line = streamLines[si]
		local n = math.floor(line.length / STEP) + 1
		local profile = table.create(n, 0)
		local level = math.huge
		for i = 1, n do
			local x, z, dx, dz = TerrainLayers.pointAt(line, (i - 1) * STEP)
			local low = preStream(x, z)
			if not stream.centreOnly then
				local _, _, segI, t = TerrainLayers.nearest(line, x, z)
				local reach = TerrainLayers.atSegment(stream.widths, segI, t) / 2 + stream.bank
				low =
					math.min(low, preStream(x - dz * reach, z + dx * reach), preStream(x + dz * reach, z - dx * reach))
			end
			level = math.min(level, low - 1.1)
			profile[i] = level
		end
		local floorLevel = LAKE
		local into = stream.into
		if string.sub(into, 1, 7) == "stream:" then
			local target = tonumber(string.sub(into, 8)) or 1
			local tp = streamProfiles[target]
			if tp then
				local last = line.pts[#line.pts]
				local _, _, segI, t = TerrainLayers.nearest(streamLines[target], last[1], last[2])
				floorLevel = profileAt(tp, arcAt(streamLines[target], segI, t))
			end
		elseif string.sub(into, 1, 6) == "marsh:" then
			floorLevel = marshWater(tonumber(string.sub(into, 7)) or 1)
		elseif into == "fall" then
			floorLevel = -math.huge
		end
		for i = 1, n do
			profile[i] = math.max(profile[i], floorLevel)
		end
		for i = n - 1, 1, -1 do
			profile[i] = math.max(profile[i], profile[i + 1])
		end
		streamProfiles[si] = profile
	end

	-- Fords: the road dips to the water (0.4 over it) where it crosses a stream at a "ford" hint.
	for ri, rline in roadLines do
		local profile = roadProfiles[ri]
		for _, hint in shape.crossings do
			if hint.kind == "ford" then
				local d, _, segI, t = TerrainLayers.nearest(rline, hint.x, hint.z)
				if d < 2 then
					local sd, sli, ssi, st = nearestIn(streamGrid, hint.x, hint.z)
					if sli > 0 and sd < 4 then
						local water = profileAt(streamProfiles[sli], arcAt(streamLines[sli], ssi, st))
						local stream = STREAMS[sli]
						local reach = TerrainLayers.atSegment(stream.widths, ssi, st) / 2 + stream.bank
						local at = arcAt(rline, segI, t)
						for i = 1, #profile do
							local off = math.abs((i - 1) * STEP - at)
							local target = water + 0.4 + math.max(0, off - reach) * ROAD_GRADE * 0.8
							if target < profile[i] then
								profile[i] = target
							end
						end
					end
				end
			end
		end
	end

	local function streamAt(x: number, z: number): (number, number, number, number)
		local d, li, si, t = nearestIn(streamGrid, x, z)
		if li == 0 then
			return math.huge, 0, 0, 0
		end
		local s = arcAt(streamLines[li], si, t)
		return d, li, profileAt(streamProfiles[li], s), TerrainLayers.atSegment(STREAMS[li].widths, si, t) / 2
	end

	-- S46: lava. Pool shores, then the river profiles (like the streams: the lowest ground across the channel minus
	-- `sink`, never rising downstream, never under the pool it flows into; a river leaving a pool keeps its level
	-- while inside it).
	local function poolDist(i: number, x: number, z: number): number
		local p = POOLS[i]
		local e = TerrainLayers.ellipse(p.x, p.z, p.rx, p.rz, p.rot, x, z)
			+ 0.08 * (fbm(x, z, 29, SEED + 101 + i, 2) - 0.5) * 2
		return (e - 1) * (p.rx + p.rz) / 2
	end

	local function poolIndex(ref: string?, prefix: string): number?
		if ref and string.sub(ref, 1, #prefix) == prefix then
			return tonumber(string.sub(ref, #prefix + 1))
		end
		return nil
	end

	local riverProfiles: { { number } } = {}
	for ri, river in RIVERS do
		local line = riverLines[ri]
		local n = math.floor(line.length / STEP) + 1
		local profile = table.create(n, 0)
		local from = poolIndex(river.from, "pool:")
		local level = river.level
		for i = 1, n do
			local x, z, dx, dz = TerrainLayers.pointAt(line, (i - 1) * STEP)
			if not (from and POOLS[from] and poolDist(from, x, z) < 2) then
				local _, _, segI, t = TerrainLayers.nearest(line, x, z)
				local reach = TerrainLayers.atSegment(river.widths, segI, t) / 2 + 2
				local low = math.min(
					preStream(x, z),
					preStream(x - dz * reach, z + dx * reach),
					preStream(x + dz * reach, z - dx * reach)
				)
				level = math.min(level, low - river.sink)
			end
			profile[i] = level
		end
		local into = poolIndex(river.into, "pool:")
		if into and POOLS[into] then
			local floorLevel = POOLS[into].level
			for i = 1, n do
				profile[i] = math.max(profile[i], floorLevel)
			end
		end
		for i = n - 1, 1, -1 do
			profile[i] = math.max(profile[i], profile[i + 1])
		end
		riverProfiles[ri] = profile
	end

	-- Nearest lava: distance past its edge (negative inside), surface, kind, bank width, wall height, lift of a
	-- crust island.
	local function lavaAt(x: number, z: number): (number, number, string, number, number, number)
		local best, level, kind, bank, wall, lift = math.huge, 0, "", 0, 0, 0
		if #RIVERS > 0 then
			local d, li, si, t = nearestIn(riverGrid, x, z)
			if li > 0 then
				local r = RIVERS[li]
				local half = TerrainLayers.atSegment(r.widths, si, t) / 2 * (0.9 + 0.2 * fbm(x, z, 17, SEED + 100, 2))
				best = d - half
				level = profileAt(riverProfiles[li], arcAt(riverLines[li], si, t))
				kind, bank, wall = "river", r.bank, r.wall
			end
		end
		for i, p in POOLS do
			if inBox(poolBoxes[i], x, z) then
				local pd = poolDist(i, x, z)
				if pd < best then
					best, level, bank, wall, lift = pd, p.level, p.bank, p.wall, 0
					kind = if p.crust then "crust" else "pool"
					if pd < 0 then
						for _, isl in p.islands or {} :: { ShapeTypes.Island } do
							local dd = math.sqrt((x - isl.x) ^ 2 + (z - isl.z) ^ 2)
								+ 4 * (fbm(x, z, 11, SEED + 102, 2) - 0.5)
							if dd < isl.r then
								kind, lift = "island", isl.h * smoothstep((isl.r - dd) / 5)
							end
						end
					end
				end
			end
		end
		return best, level, kind, bank, wall, lift
	end

	local T = {} :: Terrain
	T.map = areas.map
	T.shape = shape
	T.areas = areas
	T.VOXEL = RegionTerrain.VOXEL
	T.HALF = RegionTerrain.HALF
	T.WALKABLE_SLOPE = RegionTerrain.WALKABLE_SLOPE
	T.MATERIALS = RegionTerrain.MATERIALS

	function T.sample(x: number, z: number): (number, Info)
		local rd, rhalf, _, rli = roadAt(x, z)
		local h = roads(x, z, preRoad(x, z))
		local rock, cap, dune, duneMat = lastRock, lastCap, lastDune, lastDuneMat
		local dry, dryE, dryI, crack, crackI = lastDry, lastDryE, lastDryI, lastCrack, lastCrackI
		local pd, phalf, py = rampAt(x, z)
		if pd < phalf then
			h = py
		elseif pd < phalf + RAMP_SHOULDER then
			h = lerp(py, h, smoothstep((pd - phalf) / RAMP_SHOULDER))
		end
		local ld = lakeDist(x, z)
		h = lakes(h, ld)
		local gd, gHalf, _, gWall = gorgeAt(x, z)
		local inGorge = gd ~= nil and gd < gHalf + gWall + 12
		local sd, sIndex, sw, shalf = streamAt(x, z)
		local depth = 0
		if sIndex > 0 then
			local stream = STREAMS[sIndex]
			depth = depthAt(stream, x, z)
			if sd < shalf then
				h = math.min(h, sw + 0.2 - (depth + 0.2) * (1 - (sd / shalf) ^ 2))
			else
				local over = sd - shalf
				local target = if inGorge or stream.centreOnly then math.huge else sw + 0.2 + over * VALLEY
				if over < stream.bank then
					target = math.min(target, lerp(sw + 0.2, h, smoothstep(over / stream.bank)))
				end
				if rd < rhalf + ROAD_SHOULDER then
					local onRoad = if rd < rhalf + 1 then 1 else 1 - smoothstep((rd - rhalf - 1) / (ROAD_SHOULDER - 1))
					target = lerp(target, h, onRoad)
				end
				h = math.min(h, target)
			end
		end
		-- S46: lava fills its channels and pools (flat surface), low banks hold it, ground over the bank is cut
		local lavaD, lavaLevel, lavaKind, lavaBank, lavaWall, lift = math.huge, 0, "", 0, 0, 0
		if #RIVERS > 0 or #POOLS > 0 then
			lavaD, lavaLevel, lavaKind, lavaBank, lavaWall, lift = lavaAt(x, z)
			if lavaKind ~= "" then
				if lavaD < 0 then
					h = lavaLevel + lift
				else
					h = math.min(h, lavaLevel + lavaWall + lavaD * 0.6)
					if lavaD < lavaBank then
						h = math.max(h, lavaLevel + lavaWall * (1 - smoothstep(lavaD / lavaBank)))
					end
				end
			end
		end
		local crackGlow = crackI > 0 and CRACKS[crackI].glow
		local lavaAll = math.min(lavaD, if crackGlow then crack else math.huge)
		if lavaKind == "island" then
			lavaAll = math.max(lavaAll, 0)
		end
		local mw, mi = marshAt(x, z)
		local pw = plateauOf(x, z)
		local _, bw = basins(x, z)
		local info: Info = {
			lava = lavaAll,
			lavaD = lavaD,
			lavaLevel = lavaLevel,
			lavaKind = lavaKind,
			lavaBank = lavaBank,
			crack = crack,
			crackGlow = crackGlow,
			rock = rock,
			cap = cap,
			dune = dune,
			duneMat = duneMat,
			dry = dry,
			dryE = dryE,
			dryLake = dryI,
			road = rd - rhalf,
			roadMat = if rli > 0 then roadMats[rli] else "Ground",
			ramp = pd < phalf + 0.5,
			stream = sIndex,
			streamD = sd - shalf,
			streamW = sw,
			streamDepth = depth,
			lake = ld,
			marsh = mw,
			marshWater = marshWater(mi),
			gorge = gd ~= nil and gd < gHalf + gWall + 2,
			plateau = pw > 0.02,
			basin = bw,
		}
		return h, info
	end

	function T.height(x: number, z: number): number
		return (T.sample(x, z))
	end

	-- Water surface over a column (nil when dry): streams (only as deep as their channel), lakes, marsh pools.
	local function waterOf(h: number, info: Info): number?
		if info.stream > 0 and info.streamD < STREAMS[info.stream].bank and h < info.streamW then
			if info.streamW - h <= info.streamDepth + 0.8 then
				return info.streamW
			end
		end
		if info.lake < shape.lakeShore and h < LAKE then
			return LAKE
		end
		if info.marsh > 0.02 and h < info.marshWater then
			return info.marshWater
		end
		return nil
	end

	function T.water(x: number, z: number): number?
		local h, info = T.sample(x, z)
		return waterOf(h, info)
	end

	function T.isWater(x: number, z: number): boolean
		return T.water(x, z) ~= nil
	end

	function T.slope(x: number, z: number, step: number?): number
		local s = step or 2
		local gx = (T.height(x + s, z) - T.height(x - s, z)) / (2 * s)
		local gz = (T.height(x, z + s) - T.height(x, z - s)) / (2 * s)
		return math.sqrt(gx * gx + gz * gz)
	end

	-- S46: distance past the edge of the nearest lava or glowing crack (math.huge on maps without them).
	function T.lavaDistance(x: number, z: number): number
		local best = math.huge
		if #RIVERS > 0 or #POOLS > 0 then
			best = (lavaAt(x, z))
		end
		if #CRACKS > 0 then
			local cd, ci = crackAt(x, z)
			if ci > 0 and CRACKS[ci].glow then
				best = math.min(best, cd)
			end
		end
		return best
	end

	-- Lava surface over a column (nil when there is no lava; crust islands are not lava).
	function T.lava(x: number, z: number): number?
		if #RIVERS == 0 and #POOLS == 0 then
			return nil
		end
		local d, level, kind = lavaAt(x, z)
		if d < 0 and kind ~= "island" then
			return level
		end
		return nil
	end

	function T.crackDistance(x: number, z: number): (number, boolean)
		if #CRACKS == 0 then
			return math.huge, false
		end
		local cd, ci = crackAt(x, z)
		return cd, ci > 0 and CRACKS[ci].glow
	end

	-- Dry, gentle ground at the point and 4 studs around it (S46: and LAVA_CLEARANCE from lava and glowing cracks).
	function T.walkable(x: number, z: number): boolean
		if T.isWater(x, z) then
			return false
		end
		if T.lavaDistance(x, z) < RegionTerrain.LAVA_CLEARANCE then
			return false
		end
		for _, o in { { 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } } do
			if T.slope(x + o[1], z + o[2]) > RegionTerrain.WALKABLE_SLOPE then
				return false
			end
		end
		return true
	end

	-- No water of the terrain within `r` studs (two rings of 8 samples).
	function T.dryAround(x: number, z: number, r: number): boolean
		for _, d in { r * 0.5, r } do
			for i = 0, 7 do
				local a = i * math.pi / 4
				if T.isWater(x + math.cos(a) * d, z + math.sin(a) * d) then
					return false
				end
			end
		end
		return true
	end

	function T.marshWeight(x: number, z: number): number
		return (marshAt(x, z))
	end

	function T.themeAt(x: number, z: number): string
		local j = shape.themeJitter
		local jx = x + j * (fbm(x, z, 37, SEED + 11, 2) - 0.5) * 2
		local jz = z + j * (fbm(x, z, 37, SEED + 12, 2) - 0.5) * 2
		local mw, mi = marshAt(jx, jz)
		if mw > 0.45 then
			local m = shape.marshes[mi]
			if m.theme then
				return m.theme
			end
		end
		for _, theme in shape.themes do
			local r = theme.rect
			if jx >= r[1] and jx <= r[3] and jz >= r[2] and jz <= r[4] then
				return theme.theme
			end
		end
		return shape.defaultTheme
	end

	local function themeMatches(want: string | { string }, theme: string): boolean
		if type(want) == "string" then
			return want == theme
		end
		return table.find(want :: { string }, theme) ~= nil
	end

	-- S46: horizontal rock layers of the mesa and spire walls (rule material "@strata").
	local function strataAt(x: number, z: number, h: number): string
		local st = shape.strata
		if not st then
			return "Sandstone"
		end
		local f = (h + 1.2 * (fbm(x, z, 40, SEED + 112, 2) - 0.5)) / st.period
		f -= math.floor(f)
		for _, band in st.bands do
			if f >= band[2] and f < band[3] then
				return band[1]
			end
		end
		return st.base
	end

	-- Surface material (first match wins): water beds, ramps, roads (their own material), stream banks and lake
	-- shores, painted patches, then the shape's material rules. S46: lava, crack bottoms and lava banks come before
	-- the roads, dry lake floors and mesa / spire caps after them.
	function T.materialAt(x: number, z: number, h: number, slope: number, info: Info): string
		local n = fbm(x, z, 21, SEED + 20, 2)
		local water = waterOf(h, info)
		if water then
			return if n > 0.7 then "Ground" else "Mud"
		end
		-- S46: lava (cooling lakes: dark crust with glowing seams), its basalt banks, crack bottoms
		if info.lavaKind ~= "" then
			if info.lavaD < 0 then
				if info.lavaKind == "island" then
					return "Basalt"
				elseif info.lavaKind == "crust" then
					return if cellSeam(x, z, 10, SEED + 110) < 1.4 then "CrackedLava" else "Basalt"
				end
				return "CrackedLava"
			elseif info.lavaD < info.lavaBank * 0.6 then
				return "Basalt"
			end
		end
		if info.crack < 0 then
			return if info.crackGlow then "CrackedLava" else "Basalt"
		end
		if info.ramp then
			return "Ground"
		end
		if info.road < -0.6 + 1.6 * (n - 0.5) then
			return info.roadMat
		end
		-- S46: the floor of a dry lake (salt crust cracked into polygons) and its old waterline
		if info.dry > 0.55 and slope < STEEP then
			local dl = DRYLAKES[info.dryLake]
			local line = 1 - dryEdge[info.dryLake]
			if info.dryE > line - 0.05 and info.dryE < line + 0.07 then
				return dl.line or "Sand"
			end
			return if cellSeam(x, z, 15, SEED + 111) < 0.9 then dl.seam or "Ground" else dl.crust or "Concrete"
		end
		if info.cap ~= "" and slope < STEEP then
			return info.cap
		end
		if slope < STEEP then
			if info.stream > 0 and info.streamD < 2.5 then
				return if n < 0.6 then "Mud" else "Ground"
			end
			if info.lake < 4 and info.lake > -1 then
				return "Mud"
			end
			for _, patch in shape.patches do
				local d = math.sqrt((x - patch.x) ^ 2 + (z - patch.z) ^ 2)
				if d < patch.r + 4 * (n - 0.5) then
					return patch.material
				end
			end
		end
		local deg = math.deg(math.atan(slope))
		local noise = fbm(x, z, 31, SEED + 21, 3)
		local theme: string? = nil
		for _, rule in shape.materialRules do
			if rule.minSlope and deg < rule.minSlope then
				continue
			end
			if rule.maxSlope and deg > rule.maxSlope then
				continue
			end
			if rule.minY and h < rule.minY then
				continue
			end
			if rule.maxY and h > rule.maxY then
				continue
			end
			if rule.minNoise and noise < rule.minNoise then
				continue
			end
			if rule.maxNoise and noise > rule.maxNoise then
				continue
			end
			if rule.gorge ~= nil and rule.gorge ~= info.gorge then
				continue
			end
			if rule.plateau ~= nil and rule.plateau ~= info.plateau then
				continue
			end
			if rule.marsh ~= nil and rule.marsh ~= (info.marsh > 0.3) then
				continue
			end
			if rule.minLava and info.lava < rule.minLava then
				continue
			end
			if rule.maxLava and info.lava > rule.maxLava then
				continue
			end
			if rule.rock ~= nil and rule.rock ~= info.rock then
				continue
			end
			if rule.dune ~= nil and rule.dune ~= (info.dune > 0.5) then
				continue
			end
			if rule.drylake ~= nil and rule.drylake ~= (info.dry > 0.3) then
				continue
			end
			if rule.theme then
				if not theme then
					theme = T.themeAt(x, z)
				end
				if not themeMatches(rule.theme, theme :: string) then
					continue
				end
			end
			if rule.mat == "@strata" then
				return strataAt(x, z, h)
			elseif rule.mat == "@dune" then
				return if info.duneMat ~= "" then info.duneMat else "Sand"
			end
			return rule.mat
		end
		return FALLBACK
	end

	function T.material(x: number, z: number): string
		local h, info = T.sample(x, z)
		return T.materialAt(x, z, h, T.slope(x, z, 2), info)
	end

	function T.voxels(x0: number, z0: number, nx: number, nz: number, yBottom: number, ny: number): TerrainLayers.Voxels
		return TerrainLayers.voxels(
			T.sample,
			T.materialAt :: any,
			function(_x: number, _z: number, h: number, info: any): number?
				return waterOf(h, info)
			end,
			x0,
			z0,
			nx,
			nz,
			yBottom,
			ny
		)
	end

	local crossingCache: { Crossing }? = nil

	-- Where roads cross streams, with the bridge kind from the shape (nearest hint within 24 studs; "wood" without).
	function T.crossings(): { Crossing }
		if crossingCache then
			return crossingCache
		end
		local out: { Crossing } = {}
		for ri, rline in roadLines do
			for si, sline in streamLines do
				local rp, sp = rline.pts, sline.pts
				for i = 1, #rp - 1 do
					local a, b = rp[i], rp[i + 1]
					for k = 1, #sp - 1 do
						local c, d = sp[k], sp[k + 1]
						local rx, rz = b[1] - a[1], b[2] - a[2]
						local sx, sz = d[1] - c[1], d[2] - c[2]
						local den = rx * sz - rz * sx
						if math.abs(den) > 1e-9 then
							local t = ((c[1] - a[1]) * sz - (c[2] - a[2]) * sx) / den
							local u = ((c[1] - a[1]) * rz - (c[2] - a[2]) * rx) / den
							if t >= -1e-6 and t <= 1 + 1e-6 and u >= -1e-6 and u <= 1 + 1e-6 then
								local x, z = a[1] + rx * t, a[2] + rz * t
								local len = math.sqrt(rx * rx + rz * rz)
								local stream = STREAMS[si]
								local half = TerrainLayers.atSegment(stream.widths, k, u) / 2
								local slen = math.sqrt(sx * sx + sz * sz)
								local sin = math.max(math.abs(rx * sz - rz * sx) / (len * slen), 0.4)
								local cos = math.abs(rx * sx + rz * sz) / (len * slen)
								local kind = "wood"
								for _, hint in shape.crossings do
									if (hint.x - x) ^ 2 + (hint.z - z) ^ 2 < 24 * 24 then
										kind = hint.kind
									end
								end
								local dupe = false
								for _, other in out do
									if (other.x - x) ^ 2 + (other.z - z) ^ 2 < 36 then
										dupe = true
									end
								end
								if not dupe then
									table.insert(out, {
										x = x,
										z = z,
										dirX = rx / len,
										dirZ = rz / len,
										span = (2 * (half + 1.5) + ROADS[ri].width * cos) / sin + 4,
										deck = profileAt(roadProfiles[ri], arcAt(rline, i, t)),
										water = profileAt(streamProfiles[si], arcAt(sline, k, u)),
										kind = kind,
										road = ri,
										stream = si,
									})
								end
							end
						end
					end
				end
			end
		end
		-- S46: stone bridges where roads cross lava rivers (the span covers the lava and most of its banks)
		for ri, rline in roadLines do
			for li, lline in riverLines do
				local rp, lp = rline.pts, lline.pts
				for i = 1, #rp - 1 do
					local a, b = rp[i], rp[i + 1]
					for k = 1, #lp - 1 do
						local c, d = lp[k], lp[k + 1]
						local rx, rz = b[1] - a[1], b[2] - a[2]
						local sx, sz = d[1] - c[1], d[2] - c[2]
						local den = rx * sz - rz * sx
						if math.abs(den) > 1e-9 then
							local t = ((c[1] - a[1]) * sz - (c[2] - a[2]) * sx) / den
							local u = ((c[1] - a[1]) * rz - (c[2] - a[2]) * rx) / den
							if t >= -1e-6 and t <= 1 + 1e-6 and u >= -1e-6 and u <= 1 + 1e-6 then
								local x, z = a[1] + rx * t, a[2] + rz * t
								local len = math.sqrt(rx * rx + rz * rz)
								local river = RIVERS[li]
								local half = TerrainLayers.atSegment(river.widths, k, u) / 2 * 1.1 + river.bank * 0.5
								local slen = math.sqrt(sx * sx + sz * sz)
								local sin = math.max(math.abs(rx * sz - rz * sx) / (len * slen), 0.4)
								local cos = math.abs(rx * sx + rz * sz) / (len * slen)
								for _, other in out do
									if (other.x - x) ^ 2 + (other.z - z) ^ 2 < 36 then
										x = math.huge
									end
								end
								if x == math.huge then
									continue
								end
								table.insert(out, {
									x = x,
									z = z,
									dirX = rx / len,
									dirZ = rz / len,
									span = (2 * (half + 1.5) + ROADS[ri].width * cos) / sin + 4,
									deck = profileAt(roadProfiles[ri], arcAt(rline, i, t)),
									water = profileAt(riverProfiles[li], arcAt(lline, k, u)),
									kind = "stone",
									road = ri,
									stream = li,
									lava = true,
								})
							end
						end
					end
				end
			end
		end
		crossingCache = out
		return out
	end

	function T.streamLevel(i: number, s: number): number
		return profileAt(streamProfiles[i], s)
	end

	function T.streamLine(i: number): TerrainLayers.Line
		return streamLines[i]
	end

	function T.roadLine(i: number): TerrainLayers.Line
		return roadLines[i]
	end

	function T.roadDistance(x: number, z: number): number
		local d, half = roadAt(x, z)
		return d - half
	end

	function T.streamDistance(x: number, z: number): number
		local d, li, _, half = streamAt(x, z)
		return if li == 0 then math.huge else d - half
	end

	T.lakeDistance = lakeDist

	function T.gorgeFloor(x: number, z: number): (boolean, number)
		local d, half, floor = gorgeAt(x, z)
		return d ~= nil and d < half, floor
	end

	function T.plateauAt(x: number, z: number): (boolean, number)
		local w, y = plateauOf(x, z)
		return w >= 1, y
	end

	function T.basinWeight(x: number, z: number): number
		local _, w = basins(x, z)
		return w
	end

	function T.lavaLine(i: number): TerrainLayers.Line
		return riverLines[i]
	end

	function T.lavaLevel(i: number, s: number): number
		return profileAt(riverProfiles[i], s)
	end

	-- On a mesa or a spire (top, wall or scree).
	function T.rockAt(x: number, z: number): boolean
		raw(x, z)
		return lastRock
	end

	function T.duneWeight(x: number, z: number): number
		raw(x, z)
		return lastDune
	end

	function T.dryWeight(x: number, z: number): number
		raw(x, z)
		return lastDry
	end

	return T
end

local cache: { [string]: Terrain } = {}

-- Height function of a shaped region (nil for maps without Data/Terrain/<map>), built once per map.
function RegionTerrain.get(mapId: string): Terrain?
	local cached = cache[mapId]
	if cached then
		return cached
	end
	local shape = Shapes.byMap[mapId]
	local areas = Areas.byMap[mapId]
	if not shape or not areas then
		return nil
	end
	local terrain = RegionTerrain.new(shape, areas)
	cache[mapId] = terrain
	return terrain
end

-- Whether a map has a shaped region terrain.
function RegionTerrain.has(mapId: string): boolean
	return Shapes.byMap[mapId] ~= nil
end

return RegionTerrain
