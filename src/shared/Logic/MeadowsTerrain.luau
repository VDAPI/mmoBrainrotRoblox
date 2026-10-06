--!strict
-- Ground of the Whispering Meadows (S26): one pure height function shared by the terrain writer (server), the
-- layout (buildings, trees, props), the monster groups (Logic/AreaSpawns), the client decorations and the tests.
-- Shape data: Data/Terrain/meadows; roads, lakes, streams and sites: Data/Areas/meadows.
--
-- Layers, in order (see Data/Terrain/meadows): rolling ground, hills, the eastern highland, Bear Ravine, the Old
-- Quarry, the marsh, flats, roads (each road follows a smoothed, grade-limited profile of the ground under it),
-- ramps, lakes and streams. Every stream's water surface falls monotonically from its source to its mouth and
-- stays at least a stud under the banks, so water never stands above the ground beside it.
--
-- Queries along polylines (roads, streams) go through a 64-stud grid of candidate segments, so a column costs
-- the same anywhere on the map.

local AreaTypes = require("../Data/Areas/Types")
local Areas = require("../Data/Areas/meadows")
local Shape = require("../Data/Terrain/meadows")
local TerrainLayers = require("./TerrainLayers")

local MeadowsTerrain = {}

local smoothstep = TerrainLayers.smoothstep
local smootherstep = TerrainLayers.smootherstep
local lerp = TerrainLayers.lerp
local fbm = TerrainLayers.fbm
local segDist = TerrainLayers.segDist
local softRect = TerrainLayers.softRect

local SEED = Shape.seed
local LAKE = Shape.lakeLevel
local ROAD_SHOULDER = 11 -- studs beside a road over which the ground blends back to its own height
local ROAD_GRADE = 0.11 -- max rise per stud of a road profile
local RAMP_SHOULDER = 6
local STEP = 4 -- sampling step of the road and stream profiles
-- Streams run in a gentle valley: outside the channel the ground may rise at most VALLEY per stud of distance from
-- the water's edge (about 10 degrees), up to VALLEY_REACH studs away; roads keep their embankment across it.
local VALLEY = 0.17
local VALLEY_REACH = 50
local CELL = 64

MeadowsTerrain.VOXEL = TerrainLayers.VOXEL
MeadowsTerrain.LAKE_LEVEL = LAKE
MeadowsTerrain.HALF = 800 -- half the map size
MeadowsTerrain.MATERIALS = {
	"Grass",
	"LeafyGrass",
	"Ground",
	"Mud",
	"Rock",
	"Slate",
	"Sand",
	"Pebble",
	"Water",
	"Air",
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

-- Arc length at segment `si`, parameter `t` of a line.
local function arcAt(line: TerrainLayers.Line, si: number, t: number): number
	return line.along[si] + (line.along[si + 1] - line.along[si]) * t
end

-- Value of a profile sampled every STEP studs at arc length s.
local function profileAt(profile: { number }, s: number): number
	local f = s / STEP + 1
	local i = math.clamp(math.floor(f), 1, #profile)
	local j = math.min(i + 1, #profile)
	return lerp(profile[i], profile[j], math.clamp(f - i, 0, 1))
end

-- Data --------------------------------------------------------------------------------------------------------

local ROADS = Areas.roads
local roadLines: { TerrainLayers.Line } = {}
for _, road in ROADS do
	table.insert(roadLines, TerrainLayers.line(TerrainLayers.pairs(road.points)))
end
local roadGrid = index(roadLines, function(li: number): number
	return ROADS[li].width / 2 + ROAD_SHOULDER + 2
end)

local STREAMS: { AreaTypes.Stream } = Areas.streams or {}
local streamLines: { TerrainLayers.Line } = {}
local streamMaxReach = 0
for _, stream in STREAMS do
	table.insert(streamLines, TerrainLayers.line(TerrainLayers.pairs(stream.points)))
	local widest = 0
	for _, w in stream.widths do
		widest = math.max(widest, w)
	end
	streamMaxReach = math.max(streamMaxReach, widest / 2 + stream.bank)
end
local streamGrid = index(streamLines, function(li: number): number
	local widest = 0
	for _, w in STREAMS[li].widths do
		widest = math.max(widest, w)
	end
	return widest / 2 + math.max(STREAMS[li].bank, VALLEY_REACH) + 2
end)

local RAVINE = Shape.ravine
local ravinePts: { { number } } = {}
local ravineReach = 0
for _, p in RAVINE.pts do
	table.insert(ravinePts, { p.x, p.z })
	ravineReach = math.max(ravineReach, p.half + RAVINE.wall + 6)
end
local ravineLine = TerrainLayers.line(ravinePts)
local ravineBox = {
	ravineLine.box[1] - ravineReach,
	ravineLine.box[2] - ravineReach,
	ravineLine.box[3] + ravineReach,
	ravineLine.box[4] + ravineReach,
}

local LAKES = Areas.lakes
local lakeBoxes: { { number } } = {}
for _, lake in LAKES do
	local r = lake.r + Shape.lakeShore + 10
	table.insert(lakeBoxes, { lake.x - r, lake.z - r, lake.x + r, lake.z + r })
end

-- Layers ------------------------------------------------------------------------------------------------------

local function baseHeight(x: number, z: number): number
	local amp = Shape.detail.amp
	for _, zone in Shape.zones do
		local w = softRect(zone.rect, zone.blend, x, z)
		if w > 0 then
			amp = lerp(amp, zone.amp, w)
		end
	end
	return Shape.swell.amp * fbm(x, z, Shape.swell.scale, SEED, 2)
		+ amp * fbm(x, z, Shape.detail.scale, SEED + 1, 3)
		+ Shape.fine.amp * fbm(x, z, Shape.fine.scale, SEED + 2, 2)
end

local function hills(x: number, z: number): number
	local add = 0
	for _, hill in Shape.hills do
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

-- Bear Ravine: distance to the centre line, local floor half-width and height (nil far away).
local function ravineAt(x: number, z: number): (number?, number, number)
	if x < ravineBox[1] or x > ravineBox[3] or z < ravineBox[2] or z > ravineBox[4] then
		return nil, 0, 0
	end
	local d, _, si, t = TerrainLayers.nearest(ravineLine, x, z)
	local a, b = RAVINE.pts[si], RAVINE.pts[si + 1]
	local half = lerp(a.half, b.half, t) + 6 * (fbm(x, z, 26, SEED + 5, 2) - 0.5)
	return d, half, lerp(a.floor, b.floor, t)
end

local function quarryE(x: number, z: number): number
	local q = Shape.quarry
	return TerrainLayers.ellipse(q.x, q.z, q.rx, q.rz, 0, x, z)
end

-- Marsh weight 0..1: a soft ellipse whose edge is pushed in and out by noise.
local function marshWeight(x: number, z: number): number
	local m = Shape.marsh
	if math.abs(x - m.x) > m.rx * 1.6 or math.abs(z - m.z) > m.rz * 1.6 then
		return 0
	end
	local e = TerrainLayers.ellipse(m.x, m.z, m.rx, m.rz, 0, x, z)
	e += m.ragged * (fbm(x, z, 60, SEED + 14, 2) - 0.5) * 2
	return 1 - smoothstep((e - (1 - m.edge)) / m.edge)
end
MeadowsTerrain.marshWeight = marshWeight

-- Ground before flats, roads and water: base, hills, highland, ravine, quarry, marsh.
local function raw(x: number, z: number): number
	local h = baseHeight(x, z) + hills(x, z)
	local hl = Shape.highland
	local w = softRect(hl.rect, hl.blend, x, z)
	if w > 0 then
		h += hl.h * w
	end
	local d, half, floor = ravineAt(x, z)
	if d then
		local wall = RAVINE.wall + 3 * (fbm(x, z, 11, SEED + 6, 2) - 0.5)
		if d < half then
			h = floor + 0.9 * (fbm(x, z, 9, SEED + 7, 2) - 0.5)
		elseif d < half + wall then
			h = floor + (h - floor) * smootherstep((d - half) / wall)
		end
	end
	local e = quarryE(x, z)
	local levels = Shape.quarry.levels
	if e < levels[1].e then
		for i = 1, #levels - 1 do
			local a, b = levels[i], levels[i + 1]
			if e <= a.e and e >= b.e then
				local ya = a.y or h
				local yb = b.y or h
				if ya == yb then
					h = ya
				else
					h = lerp(ya, yb, smootherstep((a.e - e) / (a.e - b.e)))
				end
				break
			end
		end
		h += 0.35 * (fbm(x, z, 7, SEED + 8, 1) - 0.5)
	end
	local m = Shape.marsh
	local mw = marshWeight(x, z)
	if mw > 0 then
		local target = m.level + m.amp * (fbm(x, z, m.scale, SEED + 9, 2) - 0.5) * 2
		h = lerp(h, target, mw * m.strength)
	end
	return h
end

local flatTargets: { number } = {}
for i, flat in Shape.flats do
	flatTargets[i] = flat.y or raw(flat.x, flat.z)
end

local function flats(x: number, z: number, h: number): number
	for i, flat in Shape.flats do
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

-- Junctions: a road that starts or ends on another road takes that road's height there, blended over 40 studs,
-- so the surfaces meet without a step (each profile is smoothed along its own road).
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

-- Nearest road: distance, half width and the road surface there.
local function roadAt(x: number, z: number): (number, number, number)
	local d, li, si, t = nearestIn(roadGrid, x, z)
	if li == 0 then
		return math.huge, 0, 0
	end
	return d, ROADS[li].width / 2, profileAt(roadProfiles[li], arcAt(roadLines[li], si, t))
end

-- How much a road owns a point: 1 on it, falling to 0 at the end of its shoulder.
local function roadWeight(d: number, half: number): number
	if d < half + 1 then
		return 1
	elseif d < half + ROAD_SHOULDER then
		return 1 - smoothstep((d - half - 1) / (ROAD_SHOULDER - 1))
	end
	return 0
end

-- Road surface over the ground `h`: the nearest road, and where two roads meet (junctions, roads side by side)
-- the two nearest roads mixed by distance, so their surfaces join without a step.
local function roads(x: number, z: number, h: number): number
	local list = roadGrid[key(math.floor(x / CELL), math.floor(z / CELL))]
	if not list then
		return h
	end
	local d1, l1, s1, t1 = math.huge, 0, 0, 0
	local d2, l2, s2, t2 = math.huge, 0, 0, 0
	-- nearest segment of each road, keeping the best two roads
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
for _, ramp in Shape.ramps do
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

-- Nearest ramp: distance, half width, ramp height (math.huge when none is near).
local function rampAt(x: number, z: number): (number, number, number)
	local best, bestHalf, bestY = math.huge, 0, 0
	for _, ramp in ramps do
		local b = ramp.box
		if x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4] then
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

-- Signed distance to the union of the lake circles (negative inside), with a ragged shore line (+-LAKE_RAGGED).
local LAKE_RAGGED = 9
local function lakeDist(x: number, z: number): number
	local best = math.huge
	for i, lake in LAKES do
		local b = lakeBoxes[i]
		if x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4] then
			local d = math.sqrt((x - lake.x) ^ 2 + (z - lake.z) ^ 2) - lake.r
			if d < best then
				best = d
			end
		end
	end
	if best < Shape.lakeShore + LAKE_RAGGED then
		best += LAKE_RAGGED * (fbm(x, z, 34, SEED + 13, 2) - 0.5) * 2
	end
	return best
end

local function lakes(h: number, d: number): number
	if d <= 0 then
		return math.min(h, LAKE - math.clamp(0.6 + -d * 0.16, 0, Shape.lakeDepth))
	elseif d < Shape.lakeShore then
		return math.min(h, lerp(LAKE + 0.35, h, smoothstep(d / Shape.lakeShore)))
	end
	return h
end

-- Ground with everything but the streams (their water profiles are measured on it).
local function preStream(x: number, z: number): number
	local h = applyRamps(x, z, roads(x, z, preRoad(x, z)))
	return lakes(h, lakeDist(x, z))
end

-- Stream channel depth at a point (shallows lower it).
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

-- Water profiles of the streams: the lowest ground across the channel (or the centre line) minus a stud, never
-- rising downstream, never under the level of what the stream flows into.
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
			low = math.min(low, preStream(x - dz * reach, z + dx * reach), preStream(x + dz * reach, z - dx * reach))
		end
		level = math.min(level, low - 1.1)
		profile[i] = level
	end
	-- the mouth: a lake level, or the level of the stream it joins there
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
	elseif into == "fall" then
		floorLevel = -math.huge
	end
	for i = 1, n do
		profile[i] = math.max(profile[i], floorLevel)
	end
	-- the clamp may have lifted a later sample over an earlier one: keep it monotone
	for i = n - 1, 1, -1 do
		profile[i] = math.max(profile[i], profile[i + 1])
	end
	streamProfiles[si] = profile
end

-- Fords: the road dips to the water (0.4 over it) where it crosses a stream at a "ford" hint, at the road's grade.
for ri, rline in roadLines do
	local profile = roadProfiles[ri]
	local changed = false
	for _, hint in Shape.crossings do
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
							changed = true
						end
					end
				end
			end
		end
	end
	if changed then
		roadProfiles[ri] = profile
	end
end

-- Nearest stream: distance, stream index, water level, half width, arc length (index 0 when none is near).
local function streamAt(x: number, z: number): (number, number, number, number, number)
	local d, li, si, t = nearestIn(streamGrid, x, z)
	if li == 0 then
		return math.huge, 0, 0, 0, 0
	end
	local s = arcAt(streamLines[li], si, t)
	return d, li, profileAt(streamProfiles[li], s), TerrainLayers.atSegment(STREAMS[li].widths, si, t) / 2, s
end

-- Column record shared by the height, material and water of one column.
export type Info = {
	road: number, -- distance past the road edge (negative on the road)
	ramp: boolean,
	stream: number, -- index of the nearest stream (0: none)
	streamD: number, -- distance past the water edge of that stream
	streamW: number, -- its water level
	streamDepth: number,
	lake: number, -- signed distance to the lake shore line
	marsh: number, -- marsh weight 0..1
	ravine: boolean, -- inside Bear Ravine (floor or walls)
	quarry: number, -- normalised quarry radius (1 = rim)
}

-- Height and the column record.
function MeadowsTerrain.sample(x: number, z: number): (number, Info)
	local rd, rhalf = roadAt(x, z)
	local h = roads(x, z, preRoad(x, z))
	local pd, phalf, py = rampAt(x, z)
	if pd < phalf then
		h = py
	elseif pd < phalf + RAMP_SHOULDER then
		h = lerp(py, h, smoothstep((pd - phalf) / RAMP_SHOULDER))
	end
	local ld = lakeDist(x, z)
	h = lakes(h, ld)
	local rv, ravineHalf = ravineAt(x, z)
	local inRavine = rv ~= nil and rv < ravineHalf + RAVINE.wall + 12
	local sd, sIndex, sw, shalf = streamAt(x, z)
	local depth = 0
	if sIndex > 0 then
		local stream = STREAMS[sIndex]
		depth = depthAt(stream, x, z)
		if sd < shalf then
			h = math.min(h, sw + 0.2 - (depth + 0.2) * (1 - (sd / shalf) ^ 2))
		else
			local over = sd - shalf
			-- no valley in Bear Ravine (the gorge is the valley) nor above the waterfall
			local target = if inRavine or stream.centreOnly then math.huge else sw + 0.2 + over * VALLEY
			if over < stream.bank then
				target = math.min(target, lerp(sw + 0.2, h, smoothstep(over / stream.bank)))
			end
			if rd < rhalf + ROAD_SHOULDER then
				-- the road crosses on an embankment up to the water's edge; the bridge spans the channel
				local onRoad = if rd < rhalf + 1 then 1 else 1 - smoothstep((rd - rhalf - 1) / (ROAD_SHOULDER - 1))
				target = lerp(target, h, onRoad)
			end
			h = math.min(h, target)
		end
	end
	local info: Info = {
		road = rd - rhalf,
		ramp = pd < phalf + 0.5,
		stream = sIndex,
		streamD = sd - shalf,
		streamW = sw,
		streamDepth = depth,
		lake = ld,
		marsh = marshWeight(x, z),
		ravine = rv ~= nil and rv < ravineHalf + RAVINE.wall + 2,
		quarry = quarryE(x, z),
	}
	return h, info
end

function MeadowsTerrain.height(x: number, z: number): number
	return (MeadowsTerrain.sample(x, z))
end

-- Water surface over a column (nil when dry): streams (only as deep as their channel, so the end of a stream at a
-- cliff never makes a hanging column of water), lakes and marsh pools.
local function waterOf(h: number, info: Info): number?
	if info.stream > 0 and info.streamD < STREAMS[info.stream].bank and h < info.streamW then
		if info.streamW - h <= info.streamDepth + 0.8 then
			return info.streamW
		end
	end
	if (info.lake < Shape.lakeShore or info.marsh > 0.02) and h < LAKE then
		return LAKE
	end
	return nil
end

function MeadowsTerrain.water(x: number, z: number): number?
	local h, info = MeadowsTerrain.sample(x, z)
	return waterOf(h, info)
end

-- Whether a point is under water.
function MeadowsTerrain.isWater(x: number, z: number): boolean
	return MeadowsTerrain.water(x, z) ~= nil
end

-- Steepest rise per stud around a point (central differences over `step` studs).
function MeadowsTerrain.slope(x: number, z: number, step: number?): number
	local s = step or 2
	local gx = (MeadowsTerrain.height(x + s, z) - MeadowsTerrain.height(x - s, z)) / (2 * s)
	local gz = (MeadowsTerrain.height(x, z + s) - MeadowsTerrain.height(x, z - s)) / (2 * s)
	return math.sqrt(gx * gx + gz * gz)
end

MeadowsTerrain.WALKABLE_SLOPE = math.tan(math.rad(32))

-- Dry ground a monster group or a player can stand on: no water and gentle slope at the point and 4 studs
-- around it (cliffs of the ravine and the quarry are not walkable).
function MeadowsTerrain.walkable(x: number, z: number): boolean
	if MeadowsTerrain.isWater(x, z) then
		return false
	end
	for _, o in { { 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } } do
		if MeadowsTerrain.slope(x + o[1], z + o[2]) > MeadowsTerrain.WALKABLE_SLOPE then
			return false
		end
	end
	return true
end

-- Surface theme at a point (borders dithered by noise, so neighbouring themes mix over ~50 studs).
function MeadowsTerrain.themeAt(x: number, z: number): string
	local j = Shape.themeJitter
	local jx = x + j * (fbm(x, z, 37, SEED + 11, 2) - 0.5) * 2
	local jz = z + j * (fbm(x, z, 37, SEED + 12, 2) - 0.5) * 2
	if marshWeight(jx, jz) > 0.45 then
		return "marsh"
	end
	for _, theme in Shape.themes do
		local r = theme.rect
		if jx >= r[1] and jx <= r[3] and jz >= r[2] and jz <= r[4] then
			return theme.theme
		end
	end
	return "meadow"
end

local STEEP = math.tan(math.rad(42))
local ROCKY = math.tan(math.rad(30))

local THEME_GROUND: { [string]: (n: number) -> string } = {
	meadow = function(n)
		return if n > 0.66 then "LeafyGrass" else "Grass"
	end,
	hills = function(n)
		return if n > 0.72 then "Pebble" elseif n < 0.24 then "LeafyGrass" else "Grass"
	end,
	marsh = function(n)
		return if n > 0.5 then "Mud" elseif n > 0.3 then "LeafyGrass" else "Grass"
	end,
	wet = function(n)
		return if n > 0.7 then "Mud" elseif n > 0.45 then "LeafyGrass" else "Grass"
	end,
	forest = function(n)
		return if n > 0.76 then "Mud" elseif n < 0.24 then "Grass" else "LeafyGrass"
	end,
	field = function(n)
		return if n > 0.56 then "Ground" elseif n > 0.3 then "Grass" else "LeafyGrass"
	end,
	road = function(n)
		return if n > 0.78 then "Ground" elseif n < 0.22 then "LeafyGrass" else "Grass"
	end,
	quarry = function(n)
		return if n > 0.62 then "Ground" elseif n < 0.26 then "Pebble" else "Grass"
	end,
	goblin = function(n)
		return if n > 0.56 then "Ground" elseif n < 0.24 then "Mud" else "LeafyGrass"
	end,
	ravine = function(n)
		return if n > 0.74 then "Rock" elseif n > 0.42 then "LeafyGrass" else "Grass"
	end,
}

-- Surface material of a column (first match wins): stream / lake bed, ramps and roads, cliffs (slate in the
-- ravine and the quarry, rock elsewhere), banks and shores, rocky slopes, quarry terraces, the ravine floor, painted
-- patches (camps, the wallow, the vegetable plot), then the area theme.
function MeadowsTerrain.materialAt(x: number, z: number, h: number, slope: number, info: Info): string
	local n = fbm(x, z, 21, SEED + 20, 2)
	local water = waterOf(h, info)
	if water then
		if info.stream > 0 and info.streamD < 0 then
			return if info.ravine or n > 0.62 then "Pebble" else "Sand"
		end
		return "Mud"
	end
	if info.ramp then
		return "Ground"
	end
	if info.road < -0.6 + 1.6 * (n - 0.5) then
		return "Ground"
	end
	if slope > STEEP then
		return if info.ravine or info.quarry < 1.1 then "Slate" else "Rock"
	end
	if info.stream > 0 and info.streamD < 2.5 then
		return if info.marsh > 0.3 or n < 0.3 then "Mud" elseif info.ravine then "Pebble" else "Sand"
	end
	if info.lake < 4 and info.lake > -1 then
		return if info.marsh > 0.3 then "Mud" else "Sand"
	end
	if slope > ROCKY and n > 0.42 then
		return if info.ravine then "Slate" else "Rock"
	end
	if info.quarry < 1.0 then
		return if n > 0.55 then "Ground" else "Pebble"
	end
	if info.ravine then
		return if n > 0.7 then "Pebble" elseif n > 0.4 then "LeafyGrass" else "Ground"
	end
	for _, patch in Shape.patches do
		local d = math.sqrt((x - patch.x) ^ 2 + (z - patch.z) ^ 2)
		if d < patch.r + 4 * (n - 0.5) then
			return patch.material
		end
	end
	local theme = MeadowsTerrain.themeAt(x, z)
	local pick = THEME_GROUND[theme] or THEME_GROUND.meadow
	return pick(fbm(x, z, 31, SEED + 21, 3))
end

-- Material of the surface at a point (tools, admin).
function MeadowsTerrain.material(x: number, z: number): string
	local h, info = MeadowsTerrain.sample(x, z)
	local s = MeadowsTerrain.slope(x, z, 2)
	return MeadowsTerrain.materialAt(x, z, h, s, info)
end

-- Voxel block for Terrain:WriteVoxels (see TerrainLayers.voxels).
function MeadowsTerrain.voxels(
	x0: number,
	z0: number,
	nx: number,
	nz: number,
	yBottom: number,
	ny: number
): TerrainLayers.Voxels
	return TerrainLayers.voxels(
		MeadowsTerrain.sample,
		MeadowsTerrain.materialAt,
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

-- Features for the layout, the map and the client ---------------------------------------------------------------

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
	stream: number,
}

local crossingCache: { Crossing }? = nil

-- Where roads cross streams (segment intersections), with the bridge kind from Data/Terrain (nearest hint within
-- 24 studs; "wood" without one).
function MeadowsTerrain.crossings(): { Crossing }
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
							-- the channel measured along the road (an oblique crossing needs a longer bridge)
							local slen = math.sqrt(sx * sx + sz * sz)
							local sin = math.max(math.abs(rx * sz - rz * sx) / (len * slen), 0.4)
							local cos = math.abs(rx * sx + rz * sz) / (len * slen)
							local kind = "wood"
							for _, hint in Shape.crossings do
								if (hint.x - x) ^ 2 + (hint.z - z) ^ 2 < 24 * 24 then
									kind = hint.kind
								end
							end
							local s = arcAt(sline, k, u)
							local dupe = false
							for _, other in out do
								if (other.x - x) ^ 2 + (other.z - z) ^ 2 < 36 then
									dupe = true
								end
							end
							if dupe then
								continue
							end
							table.insert(out, {
								x = x,
								z = z,
								dirX = rx / len,
								dirZ = rz / len,
								span = (2 * (half + 1.5) + ROADS[ri].width * cos) / sin + 4,
								deck = profileAt(roadProfiles[ri], arcAt(rline, i, t)),
								water = profileAt(streamProfiles[si], s),
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
	crossingCache = out
	return out
end

-- Water level at a point of a stream's centre line (arc length s) and the stream's line (layout, waterfall).
function MeadowsTerrain.streamLevel(index: number, s: number): number
	return profileAt(streamProfiles[index], s)
end

function MeadowsTerrain.streamLine(index: number): TerrainLayers.Line
	return streamLines[index]
end

function MeadowsTerrain.roadLine(index: number): TerrainLayers.Line
	return roadLines[index]
end

-- Distance to the nearest road edge (negative on the road) and to the nearest stream's water edge.
function MeadowsTerrain.roadDistance(x: number, z: number): number
	local d, half = roadAt(x, z)
	return d - half
end

function MeadowsTerrain.streamDistance(x: number, z: number): number
	local d, li, _, half = streamAt(x, z)
	return if li == 0 then math.huge else d - half
end

-- Signed distance to the Toad Pond shore line (negative in the water).
MeadowsTerrain.lakeDistance = lakeDist

-- Bear Ravine: whether a point is on its floor, and its floor height there.
function MeadowsTerrain.ravineFloor(x: number, z: number): (boolean, number)
	local d, half, floor = ravineAt(x, z)
	return d ~= nil and d < half, floor
end

-- Normalised radius of the Old Quarry pit (1 = rim).
MeadowsTerrain.quarryRadius = quarryE

return MeadowsTerrain
