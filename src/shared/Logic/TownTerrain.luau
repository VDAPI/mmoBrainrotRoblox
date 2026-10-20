--!strict
-- Ground height of the starting city (S21): one pure function shared by the terrain writer (server), the house
-- generator, NPC placement and the Lune tests. It matches the Python reference in docs/miasto/tools/plan.py
-- (tests/fixtures/cityHeights.luau holds reference values).
--
-- Layers, in order: base (gentle noise inside the walls, rolling fields outside), plateaus (max; "soft" edges
-- fall off over `blend` studs, "wall"/"cliff" edges are sharp; outside the walls every edge is soft), the moat
-- (outside only), ramps (override: the road height at the nearest point of the ramp polyline) and the river.

local TerrainLayers = require("./TerrainLayers")
local Town = require("../Data/Town")
local TownGeom = require("./TownGeom")

local TownTerrain = {}

local city = Town.city
local T = city.terrain

local smoothstep = TerrainLayers.smoothstep

-- Smooth deterministic noise from sines, about 0..1 (S26: shared with the Meadows in Logic/TerrainLayers).
TownTerrain.noise = TerrainLayers.sineNoise

-- Road height and ramp at (x, z) when the point lies on a ramp band (nearest ramp wins), else nil.
function TownTerrain.rampAt(x: number, z: number): (number?, any)
	local bestD, bestY, bestRamp = math.huge, nil :: number?, nil :: any
	for _, ramp in T.ramps do
		local pts = ramp.pts
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local d, t = TownGeom.segDist(a[1], a[2], b[1], b[2], x, z)
			if d <= ramp.w / 2 and d < bestD then
				bestD, bestY, bestRamp = d, a[3] + (b[3] - a[3]) * t, ramp
			end
		end
	end
	return bestY, bestRamp
end

function TownTerrain.insideWalls(x: number, z: number): boolean
	return TownGeom.inPoly(city.wall, x, z)
end

-- Ground height (map-relative y) at x/z. `noRamps` skips the ramp layer (used to fit ramp ends).
function TownTerrain.heightAt(x: number, z: number, noRamps: boolean?): number
	local h = 0
	local dWall = TownGeom.edgeDist(city.wall, x, z)
	local inside = TownGeom.inPoly(city.wall, x, z)
	if not inside then
		local o = T.outside
		local rise = math.max(0, math.max(math.abs(x), math.abs(z)) - o.riseFrom) * o.rise
		local hills = o.base + o.amp * TownTerrain.noise(x / o.scale, z / o.scale, o.seed) + rise
		h = math.max(h, smoothstep(dWall / o.fade) * hills)
	else
		local n = T.insideNoise
		h = math.max(h, n.amp * TownTerrain.noise(x / n.scale, z / n.scale, n.seed))
	end
	for _, plateau in T.plateaus do
		local d = if TownGeom.inPoly(plateau.poly, x, z) then 0 else TownGeom.edgeDist(plateau.poly, x, z)
		local blend = if inside then plateau.blend else math.max(plateau.blend, T.outside.fade)
		if d <= 0 then
			h = math.max(h, plateau.y)
		elseif d < blend then
			h = math.max(h, plateau.y * (1 - smoothstep(d / blend)))
		end
	end
	if not inside then
		local m = 1 - smoothstep(math.abs(dWall - T.moat.center) / T.moat.half)
		h += (T.moat.bed - h) * m
	end
	if not noRamps then
		local rampY = TownTerrain.rampAt(x, z)
		if rampY then
			h = rampY
		end
	end
	local river = T.river
	local d = TownGeom.lineDist(river.pts, x, z)
	local half = river.width / 2
	local brim = river.water + 0.5
	if d < half then
		h = river.bed + (brim - river.bed) * (d / half) ^ 4
	elseif d < half + river.bank then
		local t = smoothstep((d - half) / river.bank)
		h = math.min(h, brim + (h - brim) * t)
	end
	return h
end

-- Open walkable ground for placing a character (S21): inside the walls, not in the river, not inside a house,
-- special building or stall footprint (with `margin` studs around it). Used to validate a saved logout position
-- (an old position may now be inside a building) and admin teleports.
function TownTerrain.isOpen(x: number, z: number, margin: number?): boolean
	local m = margin or 1.5
	if not TownGeom.inPoly(city.wall, x, z) or TownGeom.edgeDist(city.wall, x, z) < 8 then
		return false
	end
	if TownTerrain.heightAt(x, z) < T.river.water + 0.5 then
		return false
	end
	local function blocked(cx: number, cz: number, w: number, d: number, rot: number): boolean
		if (x - cx) ^ 2 + (z - cz) ^ 2 > (w + d + 2 * m) ^ 2 then
			return false
		end
		local poly = TownGeom.rect(cx, cz, w, d, rot)
		return TownGeom.inPoly(poly, x, z) or TownGeom.edgeDist(poly, x, z) < m
	end
	for _, lot in city.lots do
		if blocked(lot.x, lot.z, lot.w, lot.d, lot.rot) then
			return false
		end
	end
	for _, sp in city.specials do
		if sp.kind ~= "arena" and blocked(sp.x, sp.z, sp.w, sp.d, sp.rot) then
			return false
		end
	end
	for _, st in city.stalls do
		if blocked(st.x, st.z, 10, 5, st.rot) then
			return false
		end
	end
	return true
end

-- Surface materials (S21) ---------------------------------------------------------------------------------------
-- Material names (Enum.Material) by surface. The writer maps them to Enum values once; tests check the table.

TownTerrain.WATER_LEVEL = T.river.water
TownTerrain.VOXEL = 4
-- Lawns, fields and verges: LeafyGrass, never Grass. Roblox grows its waist-high decoration grass on Grass only
-- (Terrain.Decoration, no script can switch it off), and the owner wants a tidy city with clear streets and roads.
-- The city's look tints LeafyGrass like the old grass (Data/MapLooks city `terrainColors`).
TownTerrain.LAWN = "LeafyGrass"
local LAWN = TownTerrain.LAWN

local GARDEN_MATERIAL: { [string]: string } = {
	orchard = LAWN,
	vegetables = "Ground",
	vineyard = "Ground",
	formal = LAWN,
	yard = "Ground",
	backGarden = LAWN,
	paddock = "Mud",
	herbs = "Ground",
	trainingYard = "Sand",
	meadow = LAWN,
	pasture = LAWN,
}
local STREET_MATERIAL: { [string]: string } = { main = "Cobblestone", lane = "Pavement", alley = "Ground" }
local STEEP = math.tan(math.rad(40))

TownTerrain.MATERIALS = {
	"LeafyGrass",
	"Ground",
	"Mud",
	"Rock",
	"Sand",
	"Cobblestone",
	"Pavement",
	"Limestone",
	"Water",
	"Air",
}

type Box = { x1: number, z1: number, x2: number, z2: number }
type Shape = { box: Box, poly: { { number } }?, pts: { { number } }?, half: number, value: string }

local function boxOf(pts: { { number } }, pad: number): Box
	local b = { x1 = math.huge, z1 = math.huge, x2 = -math.huge, z2 = -math.huge }
	for _, p in pts do
		b.x1, b.z1 = math.min(b.x1, p[1] - pad), math.min(b.z1, p[2] - pad)
		b.x2, b.z2 = math.max(b.x2, p[1] + pad), math.max(b.z2, p[2] + pad)
	end
	return b
end

local function inBox(b: Box, x: number, z: number): boolean
	return x >= b.x1 and x <= b.x2 and z >= b.z1 and z <= b.z2
end

local function polys(list: { any }, value: (any) -> string): { Shape }
	local out: { Shape } = {}
	for _, item in list do
		table.insert(out, { box = boxOf(item.poly, 0), poly = item.poly, half = 0, value = value(item) })
	end
	return out
end

local function lines(list: { any }, value: (any) -> string): { Shape }
	local out: { Shape } = {}
	for _, item in list do
		local pts = item.pts
		table.insert(out, { box = boxOf(pts, item.w / 2), pts = pts, half = item.w / 2, value = value(item) })
	end
	return out
end

local function hit(shapes: { Shape }, x: number, z: number): string?
	for _, shape in shapes do
		if inBox(shape.box, x, z) then
			if shape.poly then
				if TownGeom.inPoly(shape.poly, x, z) then
					return shape.value
				end
			elseif shape.pts and TownGeom.lineDist(shape.pts, x, z) <= shape.half then
				return shape.value
			end
		end
	end
	return nil
end

local SQUARES = polys(city.squares, function(q)
	return q.mat
end)
local STREETS = lines(city.streets, function(s)
	return STREET_MATERIAL[s.kind] or "Pavement"
end)
local GARDENS = polys(city.gardens, function(g)
	return GARDEN_MATERIAL[g.kind] or LAWN
end)
local FIELDS = polys(city.outside.fields, function(f)
	return if f.crop == "ploughed" then "Ground" else LAWN
end)
local ROADS = lines(city.outside.roads, function()
	return "Ground"
end)
local CEMETERY: { Shape } = { { box = boxOf(city.cemetery, 0), poly = city.cemetery, half = 0, value = LAWN } }

-- W28: the Ristalle's square (sand + stands) plus `margin` studs around it. The colosseum stands on its own stone
-- foundation there (Logic/TownGen/Specials arena); the ground around it is paved, so no grass, tufts or flowers grow
-- through its floor or against its walls (DecorController skips the whole square with ARENA_MARGIN).
TownTerrain.ARENA_MARGIN = 4 -- the nearest gardens start 4.8 studs off the stands
function TownTerrain.inArena(x: number, z: number, margin: number?): boolean
	local a = city.arena
	local r = a.half + a.stands + (margin or 0)
	return math.abs(x - a.x) <= r and math.abs(z - a.z) <= r
end

-- Surface material at (x, z) for ground height `h` and slope `slope` (rise per stud; 0 when unknown).
-- First match wins: river bed, arena sand (W28: its forecourt paved), squares, ramps, streets, river banks, steep ground (rock), gardens,
-- cemetery, then the base: lawn inside the walls; moat, roads, fields and forest outside (no Grass anywhere: LAWN).
function TownTerrain.materialAt(x: number, z: number, h: number, slope: number): string
	local river = T.river
	if h < river.water then
		return "Mud"
	end
	local arena = city.arena
	if math.abs(x - arena.x) <= arena.half and math.abs(z - arena.z) <= arena.half then
		return "Sand"
	end
	if TownTerrain.inArena(x, z, TownTerrain.ARENA_MARGIN) then
		return "Pavement" -- W28: the colosseum's forecourt (no grass against its walls)
	end
	local inside = TownGeom.inPoly(city.wall, x, z)
	if inside then
		local square = hit(SQUARES, x, z)
		if square then
			return square
		end
		if TownTerrain.rampAt(x, z) then
			return "Cobblestone"
		end
		local street = hit(STREETS, x, z)
		if street then
			return street
		end
	end
	if TownGeom.lineDist(river.pts, x, z) < river.width / 2 + river.bank then
		return "Mud"
	end
	if slope > STEEP then
		return "Rock"
	end
	if inside then
		return hit(GARDENS, x, z) or hit(CEMETERY, x, z) or LAWN
	end
	local dWall = TownGeom.edgeDist(city.wall, x, z)
	if math.abs(dWall - T.moat.center) < T.moat.half then
		return "Mud"
	end
	local road = hit(ROADS, x, z) or hit(FIELDS, x, z)
	if road then
		return road
	end
	if math.max(math.abs(x), math.abs(z)) >= city.outside.forestStart then
		return if TownTerrain.noise(x / 17, z / 17, 11) > 0.7 then "Mud" else LAWN
	end
	return LAWN
end

export type Voxels = TerrainLayers.Voxels

local function waterAt(_x: number, _z: number, h: number, _info: any): number?
	return if h < TownTerrain.WATER_LEVEL then TownTerrain.WATER_LEVEL else nil
end

-- Voxel block for Terrain:WriteVoxels (resolution 4): nx * ny * nz cells, cell [i][j][k] covers
-- x0 + 4(i-1) .. x0 + 4i, yBottom + 4(j-1) .. yBottom + 4j, z0 + 4(k-1) .. z0 + 4k (map-relative studs).
-- Ground fills each cell up to the height at its centre column; cells under the river/moat level are water.
-- Material names are strings (see TownTerrain.MATERIALS); the writer converts them to Enum.Material.
function TownTerrain.voxels(x0: number, z0: number, nx: number, nz: number, yBottom: number, ny: number): Voxels
	return TerrainLayers.voxels(function(x: number, z: number): (number, any)
		return TownTerrain.heightAt(x, z), nil
	end, function(x: number, z: number, h: number, slope: number, _info: any): string
		return TownTerrain.materialAt(x, z, h, slope)
	end, waterAt, x0, z0, nx, nz, yBottom, ny)
end

return TownTerrain
