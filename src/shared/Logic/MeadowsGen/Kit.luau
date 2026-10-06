--!strict
-- Shared helpers of the Whispering Meadows generator (S26): Build construction on the Meadows ground, local ->
-- world coordinates, colour swatches of the countryside and the "life" points the client animates (perches for
-- crows, the sheep pen, duck water, smoke). Pure.

local Blueprint = require("../TownGen/Blueprint")
local MeadowsTerrain = require("../MeadowsTerrain")
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
-- A point the client brings to life (MeadowsLifeController): crows on perches, sheep in a pen, ducks on water.
export type Life = { kind: string, x: number, y: number, z: number, r: number? }

Kit.o = Parts.o

function Kit.ground(x: number, z: number): number
	return MeadowsTerrain.height(x, z)
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
function Kit.build(name: string, tag: string, x: number, z: number, rot: number, lift: number?): Build
	return {
		name = name,
		bp = Blueprint.new(Kit.seed(name, x, z)),
		at = { x = x, y = Kit.ground(x, z) + (lift or 0), z = z, rot = rot },
		tag = tag,
	}
end

-- Ground height at a local point of a Build, relative to the Build's frame.
function Kit.gy(b: Build, lx: number, lz: number): number
	local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, lx, lz)
	return Kit.ground(wx, wz) - b.at.y
end

-- Lowest and highest ground under a rotated w x d footprint.
function Kit.range(x: number, z: number, w: number, d: number, rot: number): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, f in { { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { 0, 0 } } do
		local wx, wz = Kit.toWorld(x, z, rot, f[1] * w / 2, f[2] * d / 2)
		local h = Kit.ground(wx, wz)
		lo, hi = math.min(lo, h), math.max(hi, h)
	end
	return lo, hi
end

-- Countryside swatches.
Kit.bark = { c = "#4A3A2C", m = "Wood" }
Kit.birchBark = { c = "#CFC8B8", m = "Wood" }
Kit.deadBark = { c = "#5A5048", m = "Wood" }
Kit.charred = { c = "#1F1B19", m = "Wood" }
Kit.ash = { c = "#4A4643", m = "Slate" }
Kit.rope = { c = "#8A7A58", m = "Fabric" }
Kit.cloth = { c = "#8A7A5E", m = "Fabric" }
Kit.straw = { c = "#B89A55", m = "Grass" }
Kit.bone = { c = "#DCD4BE", m = "SmoothPlastic" }
Kit.hide = { c = "#7A5A3E", m = "Fabric" }
Kit.iron = Palette.metal[1]
Kit.stone = { c = "#7A766E", m = "Slate" }
Kit.mossyStone = { c = "#6E7262", m = "Slate" }
Kit.moss = Palette.moss[1]
Kit.planks = Palette.planks[1]
Kit.greyPlanks = Palette.greyPlanks[1]
Kit.timber = Palette.timber[1]
Kit.flame = { c = "#FF8A3A", m = "Neon" }

-- Small campfire at (x, y, z) of the current frame: stones and logs (detail), the embers carry the "fire" tag
-- (client flames and flicker) with a light.
function Kit.campfire(bp: BP, x: number, y: number, z: number, lod: Blueprint.Lod?)
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
	bp:box(1.4, 0.4, 1.4, x, y + 0.5, z, Kit.o(Kit.flame, l, { col = false, tag = "fire", jitter = 0 }))
	bp:light(x, y + 2.2, z, "#FF8A3A", 22, 1.4, "fire")
end

-- Lantern on a post (lamp tag: dim by day, glowing at night).
function Kit.lantern(bp: BP, x: number, y: number, z: number, color: string?, height: number?, lod: Blueprint.Lod?)
	local h = height or 6
	local l: Blueprint.Lod = lod or "detail"
	bp:box(0.4, h, 0.4, x, y + h / 2, z, Kit.o(Kit.timber, l, { col = false }))
	bp:box(1.4, 0.3, 0.3, x + 0.5, y + h - 0.2, z, Kit.o(Kit.timber, l, { col = false }))
	bp:box(0.8, 1, 0.8, x + 1.1, y + h - 1, z, {
		c = color or "#FFC46E",
		m = "Neon",
		lod = l,
		col = false,
		tag = "lamp",
		jitter = 0,
	})
	bp:light(x + 1.1, y + h - 1, z, color or "#FFC46E", 16, 1, "lamp")
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

-- Life points collected while generating (read by the client through MeadowsGen.life()).
Kit.lifePoints = {} :: { Life }

function Kit.life(kind: string, x: number, y: number, z: number, r: number?)
	table.insert(Kit.lifePoints, { kind = kind, x = x, y = y, z = z, r = r })
end

-- Map sketch shapes (minimap and world map) in the format of World/Build: rect / circle / line with a style kind.
Kit.sketch = {} :: { { [string]: any } }

function Kit.rect(kind: string, x: number, z: number, w: number, d: number, rot: number?)
	table.insert(Kit.sketch, { t = "rect", x = x, z = z, w = w, h = d, r = rot, c = kind })
end

function Kit.circle(kind: string, x: number, z: number, r: number)
	table.insert(Kit.sketch, { t = "circle", x = x, z = z, r = r, c = kind })
end

-- Closed ring of `n` segments around (x, z) as a line shape.
function Kit.ring(kind: string, x: number, z: number, r: number, n: number, w: number)
	local pts = {}
	for i = 0, n do
		local a = i * 2 * math.pi / n
		table.insert(pts, x + math.cos(a) * r)
		table.insert(pts, z + math.sin(a) * r)
	end
	table.insert(Kit.sketch, { t = "line", p = pts, w = w, c = kind })
end

-- World position of a local point of a Build (with the frame's y).
function Kit.worldOf(b: Build, lx: number, ly: number, lz: number): (number, number, number)
	local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, lx, lz)
	return wx, b.at.y + ly, wz
end

return Kit
