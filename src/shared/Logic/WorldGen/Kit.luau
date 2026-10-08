--!strict
-- Shared kit of the region generators (S45, generalised from Logic/MeadowsGen/Kit, which stays as it is): Builds
-- standing on a map's ground, local -> world coordinates, swatches, small props (campfire, lantern, rock) and, per
-- generator context, the "life" points the client animates and the map sketch shapes. Pure.
--
-- A context (`Kit.new(mapId)`) owns its ground function (Logic/MapTerrain), life points and sketch, so several
-- regions can be generated in one process (tests, tools, the wiki) without sharing tables.

local Blueprint = require("../TownGen/Blueprint")
local MapTerrain = require("../MapTerrain")
local Palette = require("../TownGen/Palette")
local Parts = require("../TownGen/Parts")

local Kit = {}

export type BP = Blueprint.Blueprint
export type Swatch = Palette.Swatch
export type Build = {
	name: string,
	bp: BP,
	at: { x: number, y: number, z: number, rot: number },
	tag: string,
}
-- A point the client brings to life (Controllers/WorldLifeController): bats, crows, wisps, mist, moths...
export type Life = { kind: string, x: number, y: number, z: number, r: number? }
export type Shape = { [string]: any }

export type Ctx = {
	map: string,
	ground: (x: number, z: number) -> number,
	life: { Life },
	sketch: { Shape },
	perch: string?, -- S46: life kind of the birds on black dead trees (default "perch", crows)
}

Kit.o = Parts.o

-- New generator context for a map (ground from Logic/MapTerrain unless given).
function Kit.new(mapId: string, ground: ((x: number, z: number) -> number)?): Ctx
	return {
		map = mapId,
		ground = ground or function(x: number, z: number): number
			return MapTerrain.height(mapId, x, z) or 0
		end,
		life = {},
		sketch = {},
	}
end

-- World position of a point given in a frame at (x, z) rotated by rot degrees (the Build convention).
function Kit.toWorld(x: number, z: number, rot: number, lx: number, lz: number): (number, number)
	local r = math.rad(rot)
	local c, s = math.cos(r), math.sin(r)
	return x + c * lx + s * lz, z - s * lx + c * lz
end

-- Seed from a name and a position (stable across runs).
function Kit.seed(name: string, x: number, z: number): number
	local h = 17
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 1000003
	end
	return (h + math.floor(x * 7 + z * 13)) % 999983 + 1
end

-- New Build standing on the ground at (x, z): the frame's y is the ground there (`lift` studs higher).
function Kit.build(ctx: Ctx, name: string, tag: string, x: number, z: number, rot: number, lift: number?): Build
	return {
		name = name,
		bp = Blueprint.new(Kit.seed(name, x, z)),
		at = { x = x, y = ctx.ground(x, z) + (lift or 0), z = z, rot = rot },
		tag = tag,
	}
end

-- Build with its frame at an explicit height.
function Kit.buildAt(name: string, tag: string, x: number, y: number, z: number, rot: number): Build
	return { name = name, bp = Blueprint.new(Kit.seed(name, x, z)), at = { x = x, y = y, z = z, rot = rot }, tag = tag }
end

-- Ground height at a local point of a Build, relative to the Build's frame.
function Kit.gy(ctx: Ctx, b: Build, lx: number, lz: number): number
	local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, lx, lz)
	return ctx.ground(wx, wz) - b.at.y
end

-- Lowest and highest ground under a rotated w x d footprint.
function Kit.range(ctx: Ctx, x: number, z: number, w: number, d: number, rot: number): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, f in { { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { 0, 0 } } do
		local wx, wz = Kit.toWorld(x, z, rot, f[1] * w / 2, f[2] * d / 2)
		local h = ctx.ground(wx, wz)
		lo, hi = math.min(lo, h), math.max(hi, h)
	end
	return lo, hi
end

-- World position of a local point of a Build (with the frame's y).
function Kit.worldOf(b: Build, lx: number, ly: number, lz: number): (number, number, number)
	local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, lx, lz)
	return wx, b.at.y + ly, wz
end

function Kit.life(ctx: Ctx, kind: string, x: number, y: number, z: number, r: number?)
	table.insert(ctx.life, { kind = kind, x = x, y = y, z = z, r = r })
end

-- Life point at a local point of a Build.
function Kit.lifeAt(ctx: Ctx, b: Build, kind: string, lx: number, ly: number, lz: number, r: number?)
	local x, y, z = Kit.worldOf(b, lx, ly, lz)
	Kit.life(ctx, kind, x, y, z, r)
end

-- Map sketch shapes (minimap, world map, wiki) in the format of World/Build: rect / circle / line.
function Kit.rect(ctx: Ctx, kind: string, x: number, z: number, w: number, d: number, rot: number?)
	table.insert(ctx.sketch, { t = "rect", x = x, z = z, w = w, h = d, r = rot, c = kind })
end

function Kit.circle(ctx: Ctx, kind: string, x: number, z: number, r: number)
	table.insert(ctx.sketch, { t = "circle", x = x, z = z, r = r, c = kind })
end

function Kit.line(ctx: Ctx, kind: string, pts: { number }, w: number)
	table.insert(ctx.sketch, { t = "line", p = pts, w = w, c = kind })
end

-- Closed ring of `n` segments around (x, z) as a line shape.
function Kit.ring(ctx: Ctx, kind: string, x: number, z: number, r: number, n: number, w: number)
	local pts = {}
	for i = 0, n do
		local a = i * 2 * math.pi / n
		table.insert(pts, x + math.cos(a) * r)
		table.insert(pts, z + math.sin(a) * r)
	end
	Kit.line(ctx, kind, pts, w)
end

-- Swatches ------------------------------------------------------------------------------------------------------

Kit.bark = { c = "#4A3A2C", m = "Wood" }
Kit.darkBark = { c = "#2E2620", m = "Wood" }
Kit.blackBark = { c = "#1C1917", m = "Wood" }
Kit.deadBark = { c = "#5A5048", m = "Wood" }
Kit.charred = { c = "#1F1B19", m = "Wood" }
Kit.rope = { c = "#8A7A58", m = "Fabric" }
Kit.cloth = { c = "#8A7A5E", m = "Fabric" }
Kit.rag = { c = "#6B6050", m = "Fabric" }
Kit.violet = { c = "#4A2A5E", m = "Fabric" }
Kit.straw = { c = "#B89A55", m = "Grass" }
Kit.bone = { c = "#DCD4BE", m = "SmoothPlastic" }
Kit.oldBone = { c = "#BFB59C", m = "SmoothPlastic" }
Kit.hide = { c = "#7A5A3E", m = "Fabric" }
Kit.fur = { c = "#6E6A64", m = "Fabric" }
Kit.iron = Palette.metal[1]
Kit.stone = { c = "#7A766E", m = "Slate" }
Kit.darkStone = { c = "#4E4B4E", m = "Slate" }
Kit.mossyStone = { c = "#5E6656", m = "Slate" }
Kit.redRock = { c = "#6E2F2A", m = "Sandstone" }
Kit.redRockDark = { c = "#56241F", m = "Sandstone" }
Kit.moss = Palette.moss[1]
Kit.planks = Palette.planks[1]
Kit.greyPlanks = Palette.greyPlanks[1]
Kit.timber = Palette.timber[1]
Kit.flame = { c = "#FF8A3A", m = "Neon" }
Kit.dark = { c = "#08080A", m = "SmoothPlastic" }

-- Colours of flames and glows (FxColor attribute and lights).
Kit.FIRE = "#FF8A3A"
Kit.VIOLET = "#B060FF"
Kit.COLD = "#7FB8FF"
Kit.GREEN = "#7CFF8A"

-- Small campfire at (x, y, z) of the current frame: stones and logs (detail), the embers carry the "fire" tag
-- (client flames and flicker) with a light. `color` changes the flame (violet ritual fire, cold blue flames).
function Kit.campfire(bp: BP, x: number, y: number, z: number, lod: Blueprint.Lod?, color: string?)
	local l: Blueprint.Lod = lod or "detail"
	for i = 0, 7 do
		local a = i * math.pi / 4
		bp:rbox(
			0.9,
			0.6,
			0.9,
			x + math.cos(a) * 1.9,
			y + 0.25,
			z + math.sin(a) * 1.9,
			0,
			math.deg(a),
			0,
			Kit.o(Kit.stone, l, { col = false })
		)
	end
	for i = 0, 2 do
		bp:add("cyl", 3.2, 0.6, 0.6, x, y + 0.45, z, 0, i * 60, 12, Kit.o(Kit.charred, l, { col = false }))
	end
	local c = color or Kit.FIRE
	bp:box(
		1.4,
		0.4,
		1.4,
		x,
		y + 0.5,
		z,
		{ c = c, m = "Neon", lod = l, col = false, tag = "fire", jitter = 0, fxColor = color }
	)
	bp:light(x, y + 2.2, z, c, 22, 1.4, "fire")
end

-- Brazier / bowl of fire on a stand (no logs), e.g. the altar's violet fire.
function Kit.fire(bp: BP, x: number, y: number, z: number, size: number, color: string, lod: Blueprint.Lod?)
	local l: Blueprint.Lod = lod or "detail"
	bp:box(
		size,
		size * 0.4,
		size,
		x,
		y,
		z,
		{ c = color, m = "Neon", lod = l, col = false, tag = "fire", jitter = 0, fxColor = color }
	)
	bp:light(x, y + size, z, color, 18 + size * 2, 1.6, "fire")
end

-- Candle (client detail): wax stick and a tiny flame with the "candle" tag.
function Kit.candle(bp: BP, x: number, y: number, z: number, h: number?, color: string?)
	local height = h or 0.8
	bp:add(
		"cyl",
		height,
		0.3,
		0.3,
		x,
		y + height / 2,
		z,
		0,
		0,
		90,
		Kit.o({ c = "#E8E0C8", m = "SmoothPlastic" }, "fine")
	)
	bp:box(
		0.14,
		0.3,
		0.14,
		x,
		y + height + 0.15,
		z,
		{ c = color or "#FFC46E", m = "Neon", lod = "fine", col = false, tag = "candle", jitter = 0, fxColor = color }
	)
end

-- Lantern on a post (lamp tag: dim by day, glowing at night); `color` is the glass and light colour.
function Kit.lantern(bp: BP, x: number, y: number, z: number, color: string?, height: number?, lod: Blueprint.Lod?)
	local h = height or 6
	local l: Blueprint.Lod = lod or "detail"
	local c = color or "#FFC46E"
	bp:box(0.4, h, 0.4, x, y + h / 2, z, Kit.o(Kit.timber, l, { col = false }))
	bp:box(1.4, 0.3, 0.3, x + 0.5, y + h - 0.2, z, Kit.o(Kit.timber, l, { col = false }))
	bp:box(0.8, 1, 0.8, x + 1.1, y + h - 1, z, {
		c = c,
		m = "Neon",
		lod = l,
		col = false,
		tag = "lamp",
		jitter = 0,
		fxColor = color,
	})
	bp:light(x + 1.1, y + h - 1, z, c, 16, 1, "lamp")
end

-- Rock lump: a rotated block (shell lumps collide).
function Kit.rock(bp: BP, x: number, y: number, z: number, size: number, sw: Swatch?, lod: Blueprint.Lod?)
	local rng = bp.rng
	local l: Blueprint.Lod = lod or "shell"
	bp:rbox(
		size * rng:float(1, 1.5),
		size * rng:float(0.6, 0.95),
		size * rng:float(0.9, 1.3),
		x,
		y + size * 0.25,
		z,
		rng:float(-12, 12),
		rng:float(0, 180),
		rng:float(-12, 12),
		Kit.o(sw or Kit.stone, l, { col = l == "shell", q = false, jitter = 0.08 })
	)
end

-- Skull (fine): a ball with two dark eye holes, facing -Z of the frame.
function Kit.skull(bp: BP, x: number, y: number, z: number, s: number?, yaw: number?)
	local k = s or 1
	bp:push(x, y, z, 0, yaw or 0, 0)
	bp:add("ball", 1 * k, 0.9 * k, 1.1 * k, 0, 0.45 * k, 0, 0, 0, 0, Kit.o(Kit.bone, "fine", { col = false }))
	for _, side in { -1, 1 } do
		bp:box(0.22 * k, 0.2 * k, 0.1, side * 0.22 * k, 0.5 * k, -0.52 * k, Kit.o(Kit.dark, "fine", { col = false }))
	end
	bp:pop()
end

-- Scatter of bones (detail/fine) around (x, y, z): long bones, ribs, a skull.
function Kit.bones(bp: BP, x: number, y: number, z: number, n: number, ground: ((lx: number, lz: number) -> number)?)
	local rng = bp.rng
	for i = 1, n do
		local a = rng:float(0, math.pi * 2)
		local d = rng:float(0, 2.6)
		local bx, bz = x + math.cos(a) * d, z + math.sin(a) * d
		local by = if ground then ground(bx, bz) else y
		bp:rbox(
			rng:float(1.2, 2.2),
			0.25,
			0.25,
			bx,
			by + 0.12,
			bz,
			0,
			rng:float(0, 180),
			rng:float(-8, 8),
			Kit.o(Kit.oldBone, if i <= 2 then "detail" else "fine", { col = false })
		)
	end
	Kit.skull(bp, x + 0.6, (if ground then ground(x + 0.6, z) else y) - 0.05, z, 0.9, rng:float(0, 360))
end

-- Claw marks (fine): three dark slashes on a surface facing -Z at (x, y, z) of the current frame.
function Kit.claws(bp: BP, x: number, y: number, z: number, s: number?)
	local k = s or 1
	for i = -1, 1 do
		bp:rbox(0.18, 2.2 * k, 0.12, x + i * 0.45 * k, y, z, 0, 0, 14, Kit.o({ c = "#C9B79A", m = "Wood" }, "fine"))
	end
end

return Kit
