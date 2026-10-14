--!strict
-- S105: the first spring in Vaelthorn (the end of the story, Logic/CitySeason "spring"), drawn on the client for the
-- characters who finished the finale (CitySeasonController): flowers in the gardens, a wreath of flowers round the
-- fountain with four planters, a maypole on the market square with a crown of flowers and ribbons in the city's
-- colours, and the points of the petals drifting off the orchards. Deterministic (Logic/Rng seeded from the plan's
-- gardens), no collision, nothing clickable; the Builds have the shape of Logic/TownGen (`tag = "spring"`). Pure.

local Blueprint = require("./Blueprint")
local Fill = require("./Fill")
local Rng = require("../Rng")
local Town = require("../../Data/Town")
local TownGeom = require("../TownGeom")

type BP = Blueprint.Blueprint
type Vec2 = { number }
type Ground = (x: number, z: number) -> number

export type Build = {
	name: string,
	bp: BP,
	at: { x: number, y: number, z: number, rot: number },
	tag: string?,
}

local Spring = {}

-- The flowers of the spring (the anchor effect `thorn` uses them too, so the player knows the motif).
Spring.FLOWERS = table.freeze({ "#F2D24A", "#E86A8A", "#F4F0E8", "#9A7AE0", "#F29A3A" })
Spring.LEAF = "#5E8A4A"
Spring.CITY_COLOURS = table.freeze({ "#7A1F2B", "#C9A45C", "#F4F0E8", "#5E8A4A" })
-- Gardens that bloom (not vegetables, vineyards, paddocks, training yards; the orchards drop petals instead).
Spring.BLOOMING =
	table.freeze({ formal = true, herbs = true, yard = true, backGarden = true, meadow = true, pasture = true })
Spring.CLUMPS = 7 -- clumps per garden at most (the part budget: <= 2500 parts in all)
Spring.CLUMPS_LOW = 4 -- at low world detail
Spring.WREATH = { r = 10, clumps = 18, planters = 4, plantersR = 12 }
Spring.POLE = 16 -- the maypole's height
Spring.RIBBONS = 8
Spring.RIBBON_R = 7
Spring.WELL_R = 8.5 -- the fountain's basin (TownGen/Props: diameter 17)

local function flowerOpts(color: string): Blueprint.Options
	return { c = color, m = "SmoothPlastic", lod = "detail", col = false, q = false, jitter = 0 }
end

local LEAF_OPTS: Blueprint.Options = { c = Spring.LEAF, m = "LeafyGrass", lod = "detail", col = false, q = false }

-- One clump: 3-4 balls of one colour (2 at low detail) over a green ball of leaves at (x, y, z) (y = the ground).
local function clump(bp: BP, rng: Rng.Rng, x: number, y: number, z: number, low: boolean?)
	local color = Spring.FLOWERS[rng:int(1, #Spring.FLOWERS)]
	bp:add("ball", 1.3, 0.7, 1.3, x, y + 0.3, z, 0, 0, 0, LEAF_OPTS)
	local n = if low then 2 else rng:int(3, 4)
	for k = 1, n do
		local s = rng:float(0.5, 0.7)
		local a = k / n * math.pi * 2 + rng:float(-0.3, 0.3)
		bp:add(
			"ball",
			s,
			s,
			s,
			x + math.cos(a) * 0.4,
			y + 0.5 + rng:float(0, 0.2),
			z + math.sin(a) * 0.4,
			0,
			0,
			0,
			flowerOpts(color)
		)
	end
end

-- Flower clumps of the blooming gardens (one Build per garden, local to its centroid like Logic/TownGen/Gardens), off
-- the streets.
function Spring.gardenPoints(g: any, low: boolean): { Vec2 }
	local cx, cz = Fill.centroid(g.poly)
	local poly = Fill.localPoly(g.poly, cx, cz)
	local pts = Fill.scatter(poly, Rng.new(g.seed + 105), 5, 1.5)
	local most = if low then Spring.CLUMPS_LOW else Spring.CLUMPS
	local out: { Vec2 } = {}
	for _, p in pts do
		if #out >= most then
			break
		end
		local x, z = cx + p[1], cz + p[2]
		-- a few plots touch a street's edge: no flowers on the paving
		local onStreet = false
		for _, street in Town.city.streets do
			if TownGeom.lineDist(street.pts, x, z) < street.w / 2 + 1 then
				onStreet = true
				break
			end
		end
		if not onStreet then
			table.insert(out, { x, z })
		end
	end
	return out
end

local function gardens(city: any, ground: Ground, low: boolean, out: { Build })
	for _, g in city.gardens do
		if not Spring.BLOOMING[g.kind] then
			continue
		end
		local pts = Spring.gardenPoints(g, low)
		if #pts == 0 then
			continue
		end
		local cx, cz = Fill.centroid(g.poly)
		local y0 = ground(cx, cz)
		local bp = Blueprint.new(g.seed + 105)
		for _, p in pts do
			clump(bp, bp.rng, p[1] - cx, ground(p[1], p[2]) - y0, p[2] - cz, low)
		end
		table.insert(out, { name = `Spring_{g.id}`, bp = bp, at = { x = cx, y = y0, z = cz, rot = 0 }, tag = "spring" })
	end
end

-- The wreath round the fountain: clumps on a ring and planters (stone tubs with flowers) on the diagonals.
local function wreath(city: any, ground: Ground, low: boolean, out: { Build })
	local fx, fz = city.fountain[1], city.fountain[2]
	local y0 = ground(fx, fz)
	local bp = Blueprint.new(10501)
	local n = if low then Spring.WREATH.clumps / 2 else Spring.WREATH.clumps
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local x, z = math.cos(a) * Spring.WREATH.r, math.sin(a) * Spring.WREATH.r
		clump(bp, bp.rng, x, ground(fx + x, fz + z) - y0, z, low)
	end
	for k = 0, Spring.WREATH.planters - 1 do
		local a = math.pi / 4 + k * math.pi / 2
		local x, z = math.cos(a) * Spring.WREATH.plantersR, math.sin(a) * Spring.WREATH.plantersR
		local y = ground(fx + x, fz + z) - y0
		bp:add(
			"cyl",
			1.4,
			2.2,
			2.2,
			x,
			y + 0.7,
			z,
			0,
			0,
			90,
			{ c = "#8A7A6A", m = "Cobblestone", lod = "detail", col = false, q = false }
		)
		clump(bp, bp.rng, x, y + 1.3, z, low)
	end
	table.insert(out, { name = "Spring_Wreath", bp = bp, at = { x = fx, y = y0, z = fz, rot = 0 }, tag = "spring" })
end

-- Distance from (x, z) to a rotated rectangle (w along its local X, d along local Z).
local function rectDist(x: number, z: number, cx: number, cz: number, w: number, d: number, rot: number): number
	local poly = TownGeom.rect(cx, cz, w, d, rot)
	if TownGeom.inPoly(poly, x, z) then
		return 0
	end
	return TownGeom.edgeDist(poly, x, z)
end

-- Whether the maypole may stand at (x, z) (the rules of tests/cityseason G-T4).
function Spring.poleFree(city: any, x: number, z: number): boolean
	local square: any = nil
	for _, sq in city.squares do
		if sq.id == "rynek" then
			square = sq
		end
	end
	if not square or not TownGeom.inPoly(square.poly, x, z) or TownGeom.edgeDist(square.poly, x, z) < 4 then
		return false
	end
	local fx, fz = city.fountain[1], city.fountain[2]
	if math.sqrt((x - fx) ^ 2 + (z - fz) ^ 2) < Spring.WELL_R + 10 then
		return false
	end
	for _, stall in city.stalls do
		if rectDist(x, z, stall.x, stall.z, 8, 5, stall.rot) < 8 then
			return false
		end
	end
	for _, spot in Town.allNpcSpots() do
		if math.sqrt((x - spot.x) ^ 2 + (z - spot.z) ^ 2) < 8 then
			return false
		end
	end
	if math.sqrt((x - city.spawn.x) ^ 2 + (z - city.spawn.z) ^ 2) < 8 then
		return false
	end
	for _, sp in city.specials do
		if rectDist(x, z, sp.x, sp.z, sp.w, sp.d, sp.rot) < 8 then
			return false
		end
	end
	for _, lamp in city.lamps do
		if math.sqrt((x - lamp.x) ^ 2 + (z - lamp.z) ^ 2) < 8 then
			return false
		end
	end
	return true
end

-- The maypole's place: the first point of a 4-stud grid in the market square, looked at from the square's centre
-- outwards, that keeps clear of the fountain, the stalls, the NPCs, the spawn, the buildings and the lamps.
local function maypolePlace(city: any): { x: number, z: number }
	local square: any = nil
	for _, sq in city.squares do
		if sq.id == "rynek" then
			square = sq
		end
	end
	assert(square, "Spring: no market square")
	local x1, z1, x2, z2 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in square.poly do
		x1, z1 = math.min(x1, p[1]), math.min(z1, p[2])
		x2, z2 = math.max(x2, p[1]), math.max(z2, p[2])
	end
	local cx, cz = Fill.centroid(square.poly)
	local cells: { { number } } = {}
	local x = math.floor(x1 / 4) * 4
	while x <= x2 do
		local z = math.floor(z1 / 4) * 4
		while z <= z2 do
			table.insert(cells, { x, z, (x - cx) ^ 2 + (z - cz) ^ 2 })
			z += 4
		end
		x += 4
	end
	table.sort(cells, function(a, b)
		if a[3] ~= b[3] then
			return a[3] < b[3]
		end
		if a[1] ~= b[1] then
			return a[1] < b[1]
		end
		return a[2] < b[2]
	end)
	for _, c in cells do
		if Spring.poleFree(city, c[1], c[2]) then
			return { x = c[1], z = c[2] }
		end
	end
	error("Spring: no free place for the maypole")
end

Spring.MAYPOLE = table.freeze(maypolePlace(Town.city))

-- The maypole: a pole of pale wood, a crown of flowers, ribbons in the city's colours down to pegs in the paving.
local function maypole(ground: Ground, out: { Build })
	local px, pz = Spring.MAYPOLE.x, Spring.MAYPOLE.z
	local y0 = ground(px, pz)
	local bp = Blueprint.new(10502)
	local wood = { c = "#B89A6A", m = "Wood", lod = "detail" :: Blueprint.Lod, col = false, q = false }
	bp:add("cyl", Spring.POLE, 0.7, 0.7, 0, Spring.POLE / 2, 0, 0, 0, 90, wood)
	bp:add("ball", 0.9, 0.9, 0.9, 0, Spring.POLE + 0.3, 0, 0, 0, 0, wood)
	local top = Spring.POLE - 1
	bp:add("cyl", 0.6, 3.6, 3.6, 0, top, 0, 0, 0, 90, LEAF_OPTS)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local color = Spring.FLOWERS[k % #Spring.FLOWERS + 1]
		bp:add("ball", 0.7, 0.7, 0.7, math.cos(a) * 1.6, top + 0.2, math.sin(a) * 1.6, 0, 0, 0, flowerOpts(color))
	end
	for k = 0, Spring.RIBBONS - 1 do
		local a = (k + 0.5) / Spring.RIBBONS * math.pi * 2
		local rx, rz = math.cos(a) * Spring.RIBBON_R, math.sin(a) * Spring.RIBBON_R
		local gy = ground(px + rx, pz + rz) - y0
		local color = Spring.CITY_COLOURS[k % #Spring.CITY_COLOURS + 1]
		bp:beam(
			math.cos(a) * 1.4,
			top - 0.4,
			math.sin(a) * 1.4,
			rx,
			gy + 0.6,
			rz,
			0.08,
			{ c = color, m = "Fabric", lod = "detail", col = false, q = false, jitter = 0 },
			0.35
		)
		bp:add("box", 0.3, 0.6, 0.3, rx, gy + 0.3, rz, 0, 0, 0, wood)
	end
	table.insert(out, { name = "Spring_Maypole", bp = bp, at = { x = px, y = y0, z = pz, rot = 0 }, tag = "spring" })
end

-- Every Build of the spring in the city (the maypole and the wreath first: the first frame of the controller builds
-- them, so the finale's last scene shows them).
function Spring.all(city: any, ground: Ground, low: boolean): { Build }
	local out: { Build } = {}
	maypole(ground, out)
	wreath(city, ground, low, out)
	gardens(city, ground, low, out)
	return out
end

-- Points of the petal emitters: over every orchard (its apple trees, 7 studs up) and two over the market square
-- (by the maypole and over the fountain); at low detail every second orchard.
function Spring.petals(city: any, ground: Ground, low: boolean): { { x: number, y: number, z: number } }
	local out: { { x: number, y: number, z: number } } = {}
	local n = 0
	for _, g in city.gardens do
		if g.kind == "orchard" then
			n += 1
			if not low or n % 2 == 1 then
				local cx, cz = Fill.centroid(g.poly)
				table.insert(out, { x = cx, y = ground(cx, cz) + 7, z = cz })
			end
		end
	end
	local px, pz = Spring.MAYPOLE.x, Spring.MAYPOLE.z
	table.insert(out, { x = px, y = ground(px, pz) + Spring.POLE + 2, z = pz })
	local fx, fz = city.fountain[1], city.fountain[2]
	table.insert(out, { x = fx, y = ground(fx, fz) + 12, z = fz })
	return out
end

return Spring
