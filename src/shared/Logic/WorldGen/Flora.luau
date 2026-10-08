--!strict
-- Trees and undergrowth of the shaped regions (S45, generalised from Logic/MeadowsGen/Nature.forest, which stays
-- as it is). Every surface theme of the map (Data/Terrain/<map> `flora`) has its own species, density and clumps;
-- trees keep off roads, water, cliffs, buildings, monster groups and everything the generator marks as clear.
--
-- Level of detail: the server builds a big tree's trunk (collides, not clickable) and main crown ("shell"); the
-- client adds the other crown lumps, branches and roots, the filler trees (whole trees without collision that make
-- the forest dense around the camera) and the undergrowth. Trees are grouped into 128-stud tiles (tag "trees").
--
-- Species registry: `Flora.species[kind] = function(bp, x, y, z, s, big)`; S46/S47 add their own.

local Blueprint = require("../TownGen/Blueprint")
local Kit = require("./Kit")
local Rng = require("../Rng")
local ShapeTypes = require("../../Data/Terrain/Types")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o

local Flora = {}

export type TreeInfo = { x: number, z: number, kind: string }
-- `big`: a server tree (trunk and main crown in the shell); false: a client-only filler tree.
export type SpeciesFn = (bp: Kit.BP, x: number, y: number, z: number, s: number, big: boolean, ctx: Kit.Ctx) -> ()

local function leaf(c: string): Kit.Swatch
	return { c = c, m = "LeafyGrass" }
end

local function trunk(big: boolean): Blueprint.Options
	return { c = "#2E2620", m = "Wood", lod = if big then "shell" else "detail", col = big, q = false, jitter = 0.06 }
end

local function crownLod(big: boolean): Blueprint.Lod
	return if big then "shell" else "detail"
end

Flora.species = {} :: { [string]: SpeciesFn }

-- Dark gnarled oak: thick leaning trunk, a broad low crown of dark lumps, knotted roots.
Flora.species.gnarledOak = function(bp, x, y, z, s, big, _ctx)
	local rng = bp.rng
	local h = 5.5 * s
	local lean = rng:float(-7, 7)
	local opt = trunk(big)
	opt.c = "#3A2E24"
	bp:add("cyl", h + 1, 2.4 * s, 2.4 * s, x, y + h / 2, z, lean, rng:float(0, 180), 90, opt)
	local w = 14 * s
	local list = { "#24361F", "#2A3C22", "#1F301C", "#2E4024" }
	bp:add(
		"ball",
		w,
		w * 0.5,
		w,
		x,
		y + h + w * 0.16,
		z,
		0,
		0,
		0,
		o(leaf(list[rng:int(1, 4)]), crownLod(big), { col = false, q = false, jitter = 0.05 })
	)
	for _ = 1, 3 do
		local a = rng:float(0, math.pi * 2)
		local r = w * rng:float(0.3, 0.45)
		local lw = w * rng:float(0.45, 0.6)
		bp:add(
			"ball",
			lw,
			lw * 0.55,
			lw,
			x + math.cos(a) * r,
			y + h + rng:float(-0.5, 1.6) * s,
			z + math.sin(a) * r,
			0,
			0,
			0,
			o(leaf(list[rng:int(1, 4)]), "detail", { col = false, q = false, jitter = 0.06 })
		)
	end
	for i = 1, 3 do
		local a = i * 2.1 + rng:float(-0.3, 0.3)
		bp:beam(
			x,
			y + h * 0.75,
			z,
			x + math.cos(a) * w * 0.38,
			y + h + 0.6 * s,
			z + math.sin(a) * w * 0.38,
			0.8 * s,
			o(Kit.darkBark, "detail", { col = false, q = false })
		)
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + rng:float(-0.3, 0.3)
		bp:beam(
			x,
			y + 1.4 * s,
			z,
			x + math.cos(a) * 3.2 * s,
			y - 0.4,
			z + math.sin(a) * 3.2 * s,
			0.9 * s,
			o(Kit.darkBark, "detail", { col = false, q = false })
		)
	end
	if rng:chance(0.3) then
		bp:box(1.4 * s, 0.3, 1.2 * s, x + 1.1 * s, y + 2.6 * s, z, o(Kit.moss, "fine", { col = false }))
	end
end

-- Black spruce: tall dark cone of three tiers.
Flora.species.darkPine = function(bp, x, y, z, s, big, _ctx)
	local rng = bp.rng
	local h = 12 * s
	bp:add("cyl", h, 1.1 * s, 1.1 * s, x, y + h / 2 - 0.5, z, 0, 0, 90, trunk(big))
	local list = { "#1B2E22", "#20352A", "#172A1F" }
	local c = list[rng:int(1, 3)]
	bp:add(
		"ball",
		8.5 * s,
		13 * s,
		8.5 * s,
		x,
		y + 8 * s,
		z,
		0,
		0,
		0,
		o(leaf(c), crownLod(big), { col = false, q = false })
	)
	bp:add("ball", 6 * s, 9 * s, 6 * s, x, y + 13.5 * s, z, 0, 0, 0, o(leaf(c), "detail", { col = false, q = false }))
	bp:add(
		"ball",
		3.4 * s,
		5 * s,
		3.4 * s,
		x,
		y + 17.5 * s,
		z,
		0,
		0,
		0,
		o(leaf(c), "detail", { col = false, q = false })
	)
	bp:add("ball", 10 * s, 4 * s, 10 * s, x, y + 3.6 * s, z, 0, 0, 0, o(leaf(c), "detail", { col = false, q = false }))
end

-- Black dead tree with clawing branches (a perch for crows).
Flora.species.blackDead = function(bp, x, y, z, s, big, ctx)
	local rng = bp.rng
	local h = 11 * s
	local opt = trunk(big)
	opt.c = "#1C1917"
	bp:add("cyl", h, 1.3 * s, 1.3 * s, x, y + h / 2 - 0.5, z, 0, rng:float(0, 90), 90 + rng:float(-5, 5), opt)
	local tipX, tipZ = x + 4.4 * s, z + 1.2 * s
	bp:beam(
		x,
		y + h * 0.62,
		z,
		tipX,
		y + h * 0.98,
		tipZ,
		0.6 * s,
		o(Kit.blackBark, crownLod(big), { col = false, q = false })
	)
	for i = 1, 4 do
		local a = i * 1.7 + rng:float(-0.4, 0.4)
		local by = y + h * rng:float(0.4, 0.88)
		local ex, ey, ez = x + math.cos(a) * 3.6 * s, by + rng:float(1, 3) * s, z + math.sin(a) * 3.6 * s
		bp:beam(x, by, z, ex, ey, ez, 0.42 * s, o(Kit.blackBark, "detail", { col = false, q = false }))
		-- claw tips
		bp:beam(
			ex,
			ey,
			ez,
			ex + math.cos(a + 0.6) * 1.4 * s,
			ey + 1.1 * s,
			ez + math.sin(a + 0.6) * 1.4 * s,
			0.22 * s,
			o(Kit.blackBark, "fine", { col = false, q = false })
		)
	end
	if big then
		Kit.life(ctx, "perch", tipX, y + h * 0.98 + 0.6, tipZ)
	end
end

-- Willow with beards of moss hanging from a low wide crown.
Flora.species.mossWillow = function(bp, x, y, z, s, big, _ctx)
	local rng = bp.rng
	local h = 4.8 * s
	bp:add("cyl", h, 2 * s, 2 * s, x, y + h / 2 - 0.5, z, 0, 0, 90 + rng:float(-8, 8), trunk(big))
	bp:add(
		"ball",
		13 * s,
		6.5 * s,
		13 * s,
		x,
		y + h + 2.4 * s,
		z,
		0,
		0,
		0,
		o(leaf("#3E4E2C"), crownLod(big), { col = false, q = false })
	)
	for i = 0, 8 do
		local a = i * math.pi * 2 / 9 + rng:float(-0.2, 0.2)
		local r = 5.4 * s
		bp:rbox(
			1.6 * s,
			rng:float(5, 8) * s,
			0.4,
			x + math.cos(a) * r,
			y + h - 0.6 * s,
			z + math.sin(a) * r,
			0,
			-math.deg(a) + 90,
			0,
			o({ c = "#6E7A4A", m = "Grass" }, "detail", { col = false, q = false, jitter = 0.1 })
		)
	end
end

-- Giant mushroom: pale stem, a broad cap; the gills glow at night (lamp tag, detail).
Flora.species.giantMushroom = function(bp, x, y, z, s, big, _ctx)
	local rng = bp.rng
	local h = 7 * s
	bp:add(
		"cyl",
		h,
		1.8 * s,
		1.8 * s,
		x,
		y + h / 2 - 0.3,
		z,
		0,
		0,
		90 + rng:float(-6, 6),
		{ c = "#CFC6B0", m = "SmoothPlastic", lod = if big then "shell" else "detail", col = big, q = false }
	)
	local caps = { "#6E3A5E", "#5A3A6E", "#7A4A3A" }
	local w = 10 * s
	bp:add(
		"ball",
		w,
		3.2 * s,
		w,
		x,
		y + h + 0.6 * s,
		z,
		0,
		0,
		0,
		o({ c = caps[rng:int(1, 3)], m = "SmoothPlastic" }, crownLod(big), { col = false, q = false })
	)
	bp:add("cyl", 0.4, w * 0.85, w * 0.85, x, y + h - 0.2, z, 0, 0, 0, {
		c = "#9BE8C0",
		m = "SmoothPlastic",
		lod = "detail",
		col = false,
		tag = "lamp",
		jitter = 0,
		fxColor = "#9BE8C0",
	})
	for _ = 1, 4 do
		local a = rng:float(0, math.pi * 2)
		bp:add(
			"ball",
			0.9 * s,
			0.4 * s,
			0.9 * s,
			x + math.cos(a) * w * 0.3,
			y + h + 1.9 * s,
			z + math.sin(a) * w * 0.3,
			0,
			0,
			0,
			o({ c = "#E8DCC8", m = "SmoothPlastic" }, "fine")
		)
	end
end

-- Old oak (rare giants of the thicket's entrance).
Flora.species.giantOak = function(bp, x, y, z, s, big, _ctx)
	local rng = bp.rng
	local h = 7 * s
	local thick = 3.2 * s
	local opt = trunk(big)
	opt.c = "#3A2E24"
	bp:add("cyl", h, thick, thick, x, y + h / 2 - 0.5, z, 0, 0, 90, opt)
	local w = 18 * s
	bp:add(
		"ball",
		w,
		w * 0.6,
		w,
		x,
		y + h + w * 0.2,
		z,
		0,
		0,
		0,
		o(leaf("#283C22"), crownLod(big), { col = false, q = false })
	)
	for _ = 1, 4 do
		local a = rng:float(0, math.pi * 2)
		local r = w * rng:float(0.25, 0.4)
		local lw = w * rng:float(0.5, 0.65)
		bp:add(
			"ball",
			lw,
			lw * 0.7,
			lw,
			x + math.cos(a) * r,
			y + h + w * rng:float(0.1, 0.4),
			z + math.sin(a) * r,
			0,
			0,
			0,
			o(leaf("#2E4426"), "detail", { col = false, q = false })
		)
	end
	for i = 0, 4 do
		local a = i * 2 * math.pi / 5 + rng:float(-0.2, 0.2)
		bp:beam(
			x + math.cos(a) * thick * 0.3,
			y + 1.4 * s,
			z + math.sin(a) * thick * 0.3,
			x + math.cos(a) * thick * 1.4,
			y - 0.3,
			z + math.sin(a) * thick * 1.4,
			1 * s,
			o(Kit.darkBark, "detail", { col = false, q = false })
		)
	end
end

-- Undergrowth (client only) -------------------------------------------------------------------------------------

export type UnderFn = (bp: Kit.BP, x: number, y: number, z: number) -> ()

Flora.under = {} :: { [string]: UnderFn }

Flora.under.fern = function(bp, x, y, z)
	local rng = bp.rng
	for i = 0, 4 do
		local a = i * 72 + rng:float(-15, 15)
		bp:push(x, y, z, 0, a, 0)
		bp:rbox(
			0.7,
			0.12,
			3,
			0,
			0.7,
			-1.3,
			-30,
			0,
			0,
			o({ c = "#3E5A2E", m = "LeafyGrass" }, "detail", { col = false })
		)
		bp:pop()
	end
end

Flora.under.bramble = function(bp, x, y, z)
	local rng = bp.rng
	local s = rng:float(0.8, 1.3)
	bp:add(
		"ball",
		4 * s,
		2.4 * s,
		4 * s,
		x,
		y + 0.9 * s,
		z,
		0,
		0,
		0,
		o({ c = "#2E3A24", m = "LeafyGrass" }, "detail", { col = false, jitter = 0.08 })
	)
	for i = 1, 3 do
		local a = i * 2.1
		bp:beam(
			x,
			y + 0.6,
			z,
			x + math.cos(a) * 2.6 * s,
			y + 1.6 * s,
			z + math.sin(a) * 2.6 * s,
			0.15,
			o({ c = "#3A2A22", m = "Wood" }, "fine")
		)
	end
end

Flora.under.thorns = function(bp, x, y, z)
	local rng = bp.rng
	for i = 1, 5 do
		local a = i * 1.3 + rng:float(-0.3, 0.3)
		bp:beam(
			x,
			y,
			z,
			x + math.cos(a) * 2.2,
			y + rng:float(1.4, 2.6),
			z + math.sin(a) * 2.2,
			0.18,
			o({ c = "#3A2A26", m = "Wood" }, "detail", { col = false })
		)
	end
	bp:add("ball", 2.4, 1.2, 2.4, x, y + 0.4, z, 0, 0, 0, o({ c = "#4A3A2E", m = "Grass" }, "detail", { col = false }))
end

Flora.under.sapling = function(bp, x, y, z)
	local rng = bp.rng
	local s = rng:float(0.45, 0.7)
	bp:add("cyl", 4 * s, 0.6 * s, 0.6 * s, x, y + 2 * s, z, 0, 0, 90, o(Kit.darkBark, "detail", { col = false }))
	bp:add("ball", 5 * s, 6 * s, 5 * s, x, y + 5.5 * s, z, 0, 0, 0, o(leaf("#20352A"), "detail", { col = false }))
end

Flora.under.berryBush = function(bp, x, y, z)
	local rng = bp.rng
	local s = rng:float(0.8, 1.2)
	bp:add("ball", 4 * s, 2.8 * s, 4 * s, x, y + 1 * s, z, 0, 0, 0, o(leaf("#34452A"), "detail", { col = false }))
	for i = 1, 5 do
		local a = i * 1.25
		bp:add(
			"ball",
			0.45,
			0.45,
			0.45,
			x + math.cos(a) * 1.5 * s,
			y + 1.7 * s,
			z + math.sin(a) * 1.5 * s,
			0,
			0,
			0,
			{ c = "#B0222A", m = "SmoothPlastic", lod = "fine" }
		)
	end
end

Flora.under.toadstools = function(bp, x, y, z)
	local rng = bp.rng
	for _ = 1, 4 do
		local px, pz = x + rng:float(-1.6, 1.6), z + rng:float(-1.6, 1.6)
		local h = rng:float(0.6, 1.3)
		bp:add("cyl", h, 0.3, 0.3, px, y + h / 2, pz, 0, 0, 90, o({ c = "#D8D0BC", m = "SmoothPlastic" }, "detail"))
		bp:add("ball", 1.1, 0.5, 1.1, px, y + h, pz, 0, 0, 0, {
			c = "#7CFFC0",
			m = "Neon",
			lod = "detail",
			col = false,
			jitter = 0.1,
		})
	end
end

Flora.under.reedbed = function(bp, x, y, z)
	local rng = bp.rng
	for _ = 1, 5 do
		local px, pz = x + rng:float(-2, 2), z + rng:float(-2, 2)
		bp:rbox(
			0.25,
			4,
			0.25,
			px,
			y + 1.8,
			pz,
			rng:float(-8, 8),
			0,
			rng:float(-8, 8),
			o({ c = "#6E7244", m = "Grass" }, "detail", { col = false, jitter = 0.1 })
		)
	end
end

-- Placement -------------------------------------------------------------------------------------------------------

local TILE = 128

-- Ground queries Flora needs from the map's terrain (Logic/RegionTerrain's API).
export type Ground = {
	height: (x: number, z: number) -> number,
	themeAt: (x: number, z: number) -> string,
	isWater: (x: number, z: number) -> boolean,
	slope: (x: number, z: number, step: number?) -> number,
	roadDistance: (x: number, z: number) -> number,
	streamDistance: (x: number, z: number) -> number,
	lakeDistance: (x: number, z: number) -> number,
	marshWeight: (x: number, z: number) -> number,
}

export type Options = {
	ctx: Kit.Ctx,
	ground: Ground,
	rules: { [string]: ShapeTypes.FloraRule },
	default: string, -- theme whose rule applies to themes without one
	seed: number,
	half: number,
	-- false where nothing may grow (buildings, groups, crossings...); `extra` grows the clearings
	clear: (x: number, z: number, extra: number) -> boolean,
}

local function treeGround(g: Ground, half: number, x: number, z: number, maxSlope: number): boolean
	if math.abs(x) > half - 10 or math.abs(z) > half - 10 then
		return false
	end
	if g.roadDistance(x, z) < 4 or g.streamDistance(x, z) < 3 or g.lakeDistance(x, z) < 3 then
		return false
	end
	if g.isWater(x, z) then
		return false
	end
	return g.slope(x, z, 3) < maxSlope
end

-- Every tree tile (Builds tagged "trees") and the list of big trees (map forest patches, wiki).
function Flora.forest(opts: Options): ({ Kit.Build }, { TreeInfo })
	local g = opts.ground
	local tiles: { [number]: Kit.Build } = {}
	local order: { Kit.Build } = {}
	local trees: { TreeInfo } = {}
	local function tileFor(x: number, z: number): Kit.Build
		local tx, tz = math.floor(x / TILE), math.floor(z / TILE)
		local key = (tx + 64) * 256 + (tz + 64)
		local tile = tiles[key]
		if not tile then
			local b: Kit.Build = {
				name = `Trees_{tx}_{tz}`,
				bp = Blueprint.new(key * 7 + 3 + opts.seed),
				at = { x = (tx + 0.5) * TILE, y = 0, z = (tz + 0.5) * TILE, rot = 0 },
				tag = "trees",
			}
			tiles[key] = b
			table.insert(order, b)
			tile = b
		end
		return tile :: Kit.Build
	end
	local function ruleOf(theme: string): ShapeTypes.FloraRule
		return opts.rules[theme] or opts.rules[opts.default]
	end
	local rng = Rng.new(opts.seed)
	local half = opts.half
	local step = 17
	local x = -half + step / 2
	while x < half do
		local z = -half + step / 2
		while z < half do
			local px = x + rng:float(-0.42, 0.42) * step
			local pz = z + rng:float(-0.42, 0.42) * step
			local roll = rng:next()
			local kindRoll = rng:next()
			local scaleRoll = rng:next()
			local theme = g.themeAt(px, pz)
			local rule = ruleOf(theme)
			local thin = (step / rule.spacing) ^ 2
			local clump = TerrainLayers.fbm(px, pz, 95, opts.seed + 77, 2)
			local p = (if clump > rule.clump then rule.dense else rule.sparse) * thin
			if roll < p and opts.clear(px, pz, 0) and treeGround(g, half, px, pz, 0.75) then
				local r = Rng.new(math.floor(kindRoll * 1e6) + 1)
				local weights = rule.kinds
				-- willows lean over the water, mushrooms ring the rot
				if g.streamDistance(px, pz) < 14 or g.marshWeight(px, pz) > 0.2 then
					weights = { mossWillow = 55, blackDead = 45 }
				end
				local kind = r:weighted(weights)
				local fn = Flora.species[kind] or Flora.species.gnarledOak
				local s = 0.85 + scaleRoll * 0.4
				if kind == "giantOak" then
					s = 1.2 + scaleRoll * 0.3
				end
				local tile = tileFor(px, pz)
				fn(tile.bp, px - tile.at.x, g.height(px, pz), pz - tile.at.z, s, true, opts.ctx)
				table.insert(trees, { x = px, z = pz, kind = kind })
			end
			z += step
		end
		x += step
	end
	-- filler trees and undergrowth: a fixed number of tries per tile, by the theme at each point
	local tilesAcross = math.ceil(half / TILE)
	for tx = -tilesAcross, tilesAcross - 1 do
		for tz = -tilesAcross, tilesAcross - 1 do
			local cx, cz = (tx + 0.5) * TILE, (tz + 0.5) * TILE
			local rule = ruleOf(g.themeAt(cx, cz))
			for _ = 1, rule.filler or 0 do
				local px, pz = cx + rng:float(-TILE / 2, TILE / 2), cz + rng:float(-TILE / 2, TILE / 2)
				local local_ = ruleOf(g.themeAt(px, pz))
				local kinds = local_.fillerKinds or local_.kinds
				local kind = rng:weighted(kinds)
				local s = rng:float(0.7, 1.05)
				if opts.clear(px, pz, -2) and treeGround(g, half, px, pz, 0.7) then
					local tile = tileFor(px, pz)
					local fn = Flora.species[kind] or Flora.species.gnarledOak
					fn(tile.bp, px - tile.at.x, g.height(px, pz), pz - tile.at.z, s, false, opts.ctx)
				end
			end
			local under = rule.under
			if under then
				for _ = 1, under.n do
					local px, pz = cx + rng:float(-TILE / 2, TILE / 2), cz + rng:float(-TILE / 2, TILE / 2)
					local spec = ruleOf(g.themeAt(px, pz)).under or under
					local kind = rng:weighted(spec.kinds)
					local ok = opts.clear(px, pz, -4)
					if ok then
						if kind == "reedbed" then
							local sd, ld = g.streamDistance(px, pz), g.lakeDistance(px, pz)
							ok = (sd > -1 and sd < 5) or (ld > -2 and ld < 6) or g.marshWeight(px, pz) > 0.3
							ok = ok and not g.isWater(px, pz)
						else
							ok = treeGround(g, half, px, pz, 0.8)
						end
					end
					local fn = Flora.under[kind]
					if ok and fn then
						local tile = tileFor(px, pz)
						fn(tile.bp, px - tile.at.x, g.height(px, pz), pz - tile.at.z)
					end
				end
			end
		end
	end
	return order, trees
end

return Flora
