--!strict
-- Trees, rocks and bushes of the Whispering Meadows (S26). Not a random sprinkle: every surface theme has its own
-- species and density, and a slow "clump" noise turns the Old Forest into groves with glades between them, the
-- bear plateau into pine stands and the fields into lone trees. Trees keep off roads, water, cliffs, buildings,
-- monster groups, NPC places and quest objects.
--
-- Level of detail: the server builds a tree's trunk (collides, not clickable) and main crown ("shell"); the client
-- adds the other crown lumps, branches, roots, nests (and the undergrowth: saplings, bushes, ferns in clumps) near
-- the camera. Trees are grouped into 128-stud tiles (one Build each, tag "trees").

local AreaSpawns = require("../AreaSpawns")
local Areas = require("../../Data/Areas/meadows")
local AreaTypes = require("../../Data/Areas/Types")
local Blueprint = require("../TownGen/Blueprint")
local Kit = require("./Kit")
local MeadowsTerrain = require("../MeadowsTerrain")
local Rng = require("../Rng")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o

local Nature = {}

export type TreeKind = "oak" | "giantOak" | "birch" | "pine" | "willow" | "dead"

local CROWNS: { [string]: { string } } = {
	oak = { "#3F5F2C", "#46662F", "#3A5528", "#4B6A30" },
	giantOak = { "#36542A", "#3C5B2C" },
	birch = { "#7E9A45", "#8AA650", "#76924A" },
	pine = { "#2F4A2A", "#34502C", "#2A4426" },
	willow = { "#6A8A42", "#5F7D3A", "#728F48" },
}

-- One tree standing at (x, y, z) of the current frame, scale `s`.
function Nature.tree(bp: Kit.BP, kind: TreeKind, x: number, y: number, z: number, s: number, nest: boolean?)
	local rng = bp.rng
	local trunkOpt = function(sw: Kit.Swatch)
		return o(sw, "shell", { col = true, q = false, jitter = 0.06 })
	end
	local leafSw = function(): Kit.Swatch
		local list = CROWNS[kind] or CROWNS.oak
		return { c = list[rng:int(1, #list)], m = "LeafyGrass" }
	end
	local crown = function(lod: Blueprint.Lod): Blueprint.Options
		return o(leafSw(), lod, { col = false, q = false, jitter = 0.05 })
	end
	if kind == "pine" then
		local h = 9 * s
		bp:add("cyl", h, 1.1 * s, 1.1 * s, x, y + h / 2 - 0.5, z, 0, 0, 90, trunkOpt(Kit.bark))
		bp:add("ball", 8 * s, 12 * s, 8 * s, x, y + 7.5 * s, z, 0, 0, 0, crown("shell"))
		bp:add("ball", 6 * s, 8 * s, 6 * s, x, y + 12.5 * s, z, 0, 0, 0, crown("detail"))
		bp:add("ball", 3.6 * s, 5 * s, 3.6 * s, x, y + 16 * s, z, 0, 0, 0, crown("detail"))
		bp:add("ball", 9.5 * s, 4 * s, 9.5 * s, x, y + 3.6 * s, z, 0, 0, 0, crown("detail"))
	elseif kind == "dead" then
		local h = 10 * s
		bp:add(
			"cyl",
			h,
			1.2 * s,
			1.2 * s,
			x,
			y + h / 2 - 0.5,
			z,
			0,
			rng:float(0, 90),
			90 + rng:float(-4, 4),
			trunkOpt(Kit.deadBark)
		)
		bp:beam(
			x,
			y + h * 0.6,
			z,
			x + 4 * s,
			y + h * 0.95,
			z + 1 * s,
			0.6 * s,
			o(Kit.deadBark, "shell", { col = false, q = false })
		)
		for i = 1, 3 do
			local a = i * 2.1 + rng:float(-0.4, 0.4)
			local by = y + h * rng:float(0.45, 0.85)
			bp:beam(
				x,
				by,
				z,
				x + math.cos(a) * 3.2 * s,
				by + rng:float(1, 2.6) * s,
				z + math.sin(a) * 3.2 * s,
				0.4 * s,
				o(Kit.deadBark, "detail", { col = false, q = false })
			)
		end
		Kit.life("perch", x + 4 * s, y + h * 0.95 + 0.6, z + 1 * s)
	elseif kind == "willow" then
		local h = 4.5 * s
		bp:add("cyl", h, 1.8 * s, 1.8 * s, x, y + h / 2 - 0.5, z, 0, 0, 90 + rng:float(-6, 6), trunkOpt(Kit.bark))
		bp:add("ball", 12 * s, 7 * s, 12 * s, x, y + h + 2.5 * s, z, 0, 0, 0, crown("shell"))
		-- hanging curtains of twigs
		for i = 0, 7 do
			local a = i * math.pi / 4 + rng:float(-0.2, 0.2)
			local r = 5.2 * s
			bp:rbox(
				2.4 * s,
				6 * s,
				0.4,
				x + math.cos(a) * r,
				y + h + 0.2 * s,
				z + math.sin(a) * r,
				0,
				-math.deg(a) + 90,
				0,
				o({ c = "#7A9A4E", m = "LeafyGrass" }, "detail", { col = false, q = false, jitter = 0.08 })
			)
		end
	else
		-- oak, giant oak, birch
		local giant = kind == "giantOak"
		local birch = kind == "birch"
		local h = (if birch then 8 elseif giant then 6.5 else 6) * s
		local thick = (if birch then 0.9 elseif giant then 2.6 else 1.5) * s
		bp:add(
			"cyl",
			h,
			thick,
			thick,
			x,
			y + h / 2 - 0.5,
			z,
			0,
			0,
			90,
			trunkOpt(if birch then Kit.birchBark else Kit.bark)
		)
		local w = (if birch then 6.5 elseif giant then 15 else 10) * s
		local ch = if birch then w * 1.35 else w * 0.75
		bp:add("ball", w, ch, w, x, y + h + ch * 0.32, z, 0, 0, 0, crown("shell"))
		local lumps = if giant then 4 elseif birch then 1 else 2
		for _ = 1, lumps do
			local a = rng:float(0, math.pi * 2)
			local r = w * rng:float(0.25, 0.4)
			local lw = w * rng:float(0.5, 0.7)
			bp:add(
				"ball",
				lw,
				lw * 0.8,
				lw,
				x + math.cos(a) * r,
				y + h + ch * rng:float(0.1, 0.5),
				z + math.sin(a) * r,
				0,
				0,
				0,
				crown("detail")
			)
		end
		if birch then
			for i = 1, 3 do
				bp:box(
					thick + 0.06,
					0.25,
					0.4,
					x,
					y + h * (0.2 + i * 0.2),
					z + thick / 2 - 0.1,
					o({ c = "#2A2622", m = "Wood" }, "fine", { col = false })
				)
			end
		else
			-- branches into the crown and roots
			for i = 1, (if giant then 4 else 2) do
				local a = i * 2.3 + rng:float(-0.3, 0.3)
				bp:beam(
					x,
					y + h * 0.7,
					z,
					x + math.cos(a) * w * 0.3,
					y + h + ch * 0.1,
					z + math.sin(a) * w * 0.3,
					thick * 0.35,
					o(Kit.bark, "detail", { col = false, q = false })
				)
			end
			if giant then
				for i = 0, 4 do
					local a = i * 2 * math.pi / 5 + rng:float(-0.2, 0.2)
					bp:beam(
						x + math.cos(a) * thick * 0.3,
						y + 1.2 * s,
						z + math.sin(a) * thick * 0.3,
						x + math.cos(a) * thick * 1.3,
						y - 0.3,
						z + math.sin(a) * thick * 1.3,
						0.9 * s,
						o(Kit.bark, "detail", { col = false, q = false })
					)
				end
			end
		end
	end
	if nest then
		bp:add(
			"ball",
			2,
			1.1,
			2,
			x + 0.6 * s,
			y + 8 * s,
			z + 0.4 * s,
			0,
			0,
			0,
			o({ c = "#4A3A28", m = "Wood" }, "fine", { col = false })
		)
	end
end

-- Undergrowth (client only): a sapling, a bush or a fern clump at (x, y, z).
function Nature.undergrowth(bp: Kit.BP, kind: string, x: number, y: number, z: number)
	local rng = bp.rng
	if kind == "sapling" then
		local s = rng:float(0.45, 0.7)
		bp:add("cyl", 4 * s, 0.6 * s, 0.6 * s, x, y + 2 * s, z, 0, 0, 90, o(Kit.bark, "detail", { col = false }))
		bp:add(
			"ball",
			6 * s,
			6 * s,
			6 * s,
			x,
			y + 5.5 * s,
			z,
			0,
			0,
			0,
			o({ c = "#46662F", m = "LeafyGrass" }, "detail", { col = false, jitter = 0.08 })
		)
	elseif kind == "juniper" then
		local s = rng:float(0.7, 1.2)
		bp:add(
			"ball",
			3 * s,
			5 * s,
			3 * s,
			x,
			y + 2 * s,
			z,
			0,
			0,
			0,
			o({ c = "#2E4A3A", m = "LeafyGrass" }, "detail", { col = false, jitter = 0.06 })
		)
		bp:add(
			"ball",
			2.4 * s,
			3 * s,
			2.4 * s,
			x + 1.2 * s,
			y + 1.4 * s,
			z + 0.6 * s,
			0,
			0,
			0,
			o({ c = "#35503E", m = "LeafyGrass" }, "detail", { col = false })
		)
	elseif kind == "reedbed" then
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
				o({ c = "#8A9450", m = "Grass" }, "detail", { col = false, jitter = 0.1 })
			)
		end
	else -- bush
		local s = rng:float(0.8, 1.3)
		bp:add(
			"ball",
			4.5 * s,
			3.2 * s,
			4.5 * s,
			x,
			y + 1.2 * s,
			z,
			0,
			0,
			0,
			o({ c = "#4A6A32", m = "LeafyGrass" }, "detail", { col = false, jitter = 0.08 })
		)
		if rng:chance(0.4) then
			for i = 1, 4 do
				local a = i * 1.6
				bp:add(
					"ball",
					0.5,
					0.5,
					0.5,
					x + math.cos(a) * 1.6 * s,
					y + 1.8 * s,
					z + math.sin(a) * 1.6 * s,
					0,
					0,
					0,
					{ c = "#9A2A2A", m = "SmoothPlastic", lod = "fine" }
				)
			end
		end
	end
end

-- Placement rules ---------------------------------------------------------------------------------------------

type Rule = { spacing: number, dense: number, sparse: number, clump: number, kinds: { [string]: number } }

-- Per theme: probability of a big tree on a candidate where the clump noise is over `clump` (dense) or under
-- (sparse), and the species weights.
local RULES: { [string]: Rule } = {
	forest = {
		spacing = 17,
		dense = 0.82,
		sparse = 0.1,
		clump = 0.47,
		kinds = { oak = 48, pine = 22, birch = 16, giantOak = 7, dead = 5 },
	},
	ravine = { spacing = 17, dense = 0.62, sparse = 0.08, clump = 0.5, kinds = { pine = 80, birch = 10, dead = 10 } },
	meadow = { spacing = 22, dense = 0.22, sparse = 0.02, clump = 0.66, kinds = { oak = 60, birch = 40 } },
	hills = { spacing = 22, dense = 0.16, sparse = 0.03, clump = 0.62, kinds = { pine = 70, oak = 15, dead = 15 } },
	wet = { spacing = 22, dense = 0.14, sparse = 0.04, clump = 0.6, kinds = { willow = 40, birch = 35, dead = 25 } },
	marsh = { spacing = 22, dense = 0.1, sparse = 0.04, clump = 0.6, kinds = { dead = 55, willow = 45 } },
	field = { spacing = 24, dense = 0.06, sparse = 0.012, clump = 0.7, kinds = { dead = 70, oak = 30 } },
	road = { spacing = 22, dense = 0.26, sparse = 0.025, clump = 0.64, kinds = { oak = 70, birch = 30 } },
	quarry = { spacing = 22, dense = 0.06, sparse = 0.012, clump = 0.66, kinds = { birch = 50, pine = 30, dead = 20 } },
	goblin = { spacing = 20, dense = 0.32, sparse = 0.05, clump = 0.6, kinds = { pine = 50, dead = 35, oak = 15 } },
}

-- Undergrowth per theme: count per 128-stud tile and kinds.
local UNDER: { [string]: { n: number, kinds: { [string]: number } } } = {
	forest = { n = 26, kinds = { sapling = 5, bush = 5 } },
	ravine = { n = 12, kinds = { juniper = 3, bush = 2, sapling = 2 } },
	meadow = { n = 6, kinds = { bush = 4, sapling = 1 } },
	hills = { n = 12, kinds = { juniper = 6, bush = 1 } },
	wet = { n = 8, kinds = { bush = 2, reedbed = 3 } },
	marsh = { n = 10, kinds = { reedbed = 5, bush = 1 } },
	field = { n = 3, kinds = { bush = 1 } },
	road = { n = 7, kinds = { bush = 4, sapling = 1 } },
	quarry = { n = 4, kinds = { bush = 2, juniper = 1 } },
	goblin = { n = 8, kinds = { juniper = 2, bush = 2, sapling = 1 } },
}

local TILE = 128

type Clear = { x: number, z: number, r: number }

-- Places a tree may not stand: buildings, NPCs, quest objects, crossings, cave mouths, portals, monster groups.
local function clearings(): { Clear }
	local list: { Clear } = {}
	for _, c in Areas.avoid do
		table.insert(list, { x = c.x, z = c.z, r = c.r })
	end
	for _, a in (Areas.questAnchors or {}) :: { AreaTypes.QuestAnchor } do
		table.insert(list, { x = a.x, z = a.z, r = 8 })
	end
	for _, c in Areas.caves do
		table.insert(list, { x = c.x, z = c.z, r = 34 })
	end
	for _, c in MeadowsTerrain.crossings() do
		table.insert(list, { x = c.x, z = c.z, r = c.span / 2 + 8 })
	end
	local sites = assert(Areas.sites, "meadows sites")
	table.insert(list, { x = sites.wallow.x, z = sites.wallow.z, r = 24 })
	for _, s in AreaSpawns.region(Areas, { x = 1600, z = 1600 }) do
		table.insert(list, { x = s.position.x, z = s.position.z, r = 9 })
	end
	return list
end

local clearCache: { Clear }? = nil

-- Whether a point is free of buildings, NPC places, quest objects, crossings, cave mouths and monster groups
-- (other generators place dens and fallen trees with it).
function Nature.isClear(x: number, z: number, extra: number): boolean
	if not clearCache then
		clearCache = clearings()
	end
	for _, c in clearCache :: { Clear } do
		local r = c.r + extra
		if math.abs(x - c.x) < r and math.abs(z - c.z) < r and (x - c.x) ^ 2 + (z - c.z) ^ 2 < r * r then
			return false
		end
	end
	return true
end

local function clear(list: { Clear }, x: number, z: number, extra: number): boolean
	for _, c in list do
		local r = c.r + extra
		if math.abs(x - c.x) < r and math.abs(z - c.z) < r and (x - c.x) ^ 2 + (z - c.z) ^ 2 < r * r then
			return false
		end
	end
	return true
end

-- Ground a tree can stand on: dry, off roads and banks, not on a cliff, not in the quarry pit.
local function treeGround(x: number, z: number): boolean
	if math.abs(x) > 790 or math.abs(z) > 790 then
		return false
	end
	if MeadowsTerrain.roadDistance(x, z) < 4 or MeadowsTerrain.streamDistance(x, z) < 3 then
		return false
	end
	if MeadowsTerrain.lakeDistance(x, z) < 3 or MeadowsTerrain.quarryRadius(x, z) < 1.12 then
		return false
	end
	if MeadowsTerrain.isWater(x, z) then
		return false
	end
	return MeadowsTerrain.slope(x, z, 3) < 0.75
end

local function pick(rng: Rng.Rng, weights: { [string]: number }): string
	return rng:weighted(weights)
end

export type TreeInfo = { x: number, z: number, kind: string }

-- Every tree tile (Builds tagged "trees") and the list of big trees (for the map's forest patches).
function Nature.forest(): ({ Kit.Build }, { TreeInfo })
	local avoid = clearings()
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
				bp = Blueprint.new(key * 7 + 3),
				at = { x = (tx + 0.5) * TILE, y = 0, z = (tz + 0.5) * TILE, rot = 0 },
				tag = "trees",
			}
			tiles[key] = b
			table.insert(order, b)
			tile = b
		end
		return tile :: Kit.Build
	end
	local rng = Rng.new(2604)
	local half = 800
	-- big trees on a jittered grid; the grid spacing follows the theme (dense forest closer)
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
			local theme = MeadowsTerrain.themeAt(px, pz)
			local rule = RULES[theme] or RULES.meadow
			-- sparser themes use a coarser grid: skip candidates to match their spacing
			local thin = (step / rule.spacing) ^ 2
			local clump = TerrainLayers.fbm(px, pz, 95, 77, 2)
			local p = (if clump > rule.clump then rule.dense else rule.sparse) * thin
			if roll < p and clear(avoid, px, pz, 0) and treeGround(px, pz) then
				local weights = rule.kinds
				-- willows lean over the water
				if (theme == "meadow" or theme == "road") and MeadowsTerrain.streamDistance(px, pz) < 14 then
					weights = { willow = 70, birch = 30 }
				end
				local r = Rng.new(math.floor(kindRoll * 1e6) + 1)
				local kind = pick(r, weights) :: TreeKind
				local s = 0.85 + scaleRoll * 0.45
				if kind == "giantOak" then
					s = 1.25 + scaleRoll * 0.35
				end
				local tile = tileFor(px, pz)
				local y = MeadowsTerrain.height(px, pz)
				local nest = (kind == "oak" or kind == "giantOak") and theme == "forest" and r:chance(0.1)
				Nature.tree(tile.bp, kind :: any, px - tile.at.x, y, pz - tile.at.z, s, nest)
				table.insert(trees, { x = px, z = pz, kind = kind })
			end
			z += step
		end
		x += step
	end
	-- undergrowth: a fixed number of tries per tile, by the theme at each point
	for tx = -7, 6 do
		for tz = -7, 6 do
			local cx, cz = (tx + 0.5) * TILE, (tz + 0.5) * TILE
			local theme = MeadowsTerrain.themeAt(cx, cz)
			local under = UNDER[theme] or UNDER.meadow
			for _ = 1, under.n do
				local px, pz = cx + rng:float(-TILE / 2, TILE / 2), cz + rng:float(-TILE / 2, TILE / 2)
				local localTheme = MeadowsTerrain.themeAt(px, pz)
				local spec = UNDER[localTheme] or under
				local kind = pick(rng, spec.kinds)
				local wet = kind == "reedbed"
				local ok = clear(avoid, px, pz, -4)
				if ok then
					if wet then
						-- reeds only on banks and shores, just out of the water
						local sd, ld = MeadowsTerrain.streamDistance(px, pz), MeadowsTerrain.lakeDistance(px, pz)
						ok = (sd > -1 and sd < 5) or (ld > -2 and ld < 6) or MeadowsTerrain.marshWeight(px, pz) > 0.5
						ok = ok and not MeadowsTerrain.isWater(px, pz)
					else
						ok = treeGround(px, pz)
					end
				end
				if ok then
					local tile = tileFor(px, pz)
					Nature.undergrowth(tile.bp, kind, px - tile.at.x, MeadowsTerrain.height(px, pz), pz - tile.at.z)
				end
			end
		end
	end
	return order, trees
end

-- Rock outcrops (shell lumps collide): on the Wolf Hills, the bear plateau and ravine floor, the goblin hills and
-- around the quarry rim; mossy in the ravine.
function Nature.rocks(): { Kit.Build }
	local avoid = clearings()
	local rng = Rng.new(2605)
	local out: { Kit.Build } = {}
	local wanted: { [string]: number } =
		{ hills = 22, ravine = 20, goblin = 10, quarry = 10, forest = 8, meadow = 4, road = 5 }
	local placed: { [string]: number } = {}
	local tries = 0
	while tries < 6000 do
		tries += 1
		local x, z = rng:float(-780, 780), rng:float(-780, 780)
		local theme = MeadowsTerrain.themeAt(x, z)
		local want = wanted[theme]
		if want and (placed[theme] or 0) < want and clear(avoid, x, z, 4) then
			local slopeOk = MeadowsTerrain.slope(x, z, 3) < 0.9
			if
				slopeOk
				and not MeadowsTerrain.isWater(x, z)
				and MeadowsTerrain.roadDistance(x, z) > 6
				and MeadowsTerrain.streamDistance(x, z) > 3
				and MeadowsTerrain.quarryRadius(x, z) > 1.1
			then
				placed[theme] = (placed[theme] or 0) + 1
				local b = Kit.build(`Rocks_{theme}_{placed[theme]}`, "rocks", x, z, rng:float(0, 360))
				local sw = if theme == "ravine" or theme == "forest" then Kit.mossyStone else Kit.stone
				local size = rng:float(3.5, 7.5)
				Kit.rock(b.bp, 0, -0.6, 0, size, sw, "shell")
				if rng:chance(0.6) then
					Kit.rock(b.bp, size * 0.8, Kit.gy(b, size * 0.8, 1) - 0.4, 1, size * 0.6, sw, "shell")
				end
				for _ = 1, rng:int(1, 3) do
					local a = rng:float(0, math.pi * 2)
					local d = size * rng:float(0.8, 1.4)
					local lx, lz = math.cos(a) * d, math.sin(a) * d
					Kit.rock(b.bp, lx, Kit.gy(b, lx, lz) - 0.2, lz, size * rng:float(0.25, 0.45), sw, "detail")
				end
				if theme == "ravine" or theme == "forest" then
					b.bp:box(size * 0.9, 0.3, size * 0.7, 0, size * 0.62, 0, o(Kit.moss, "fine", { col = false }))
				end
				table.insert(out, b)
			end
		end
	end
	return out
end

return Nature
