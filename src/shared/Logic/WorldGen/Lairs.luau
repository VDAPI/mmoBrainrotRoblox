--!strict
-- Elite II hideouts of the region maps (S134i, Data/Areas `lairs`): one shared builder for the four region generators.
-- `Lairs.all(ctx, def)` returns one Build per hideout (tag "lair") dressed by its theme, `Lairs.nodes(def)` the
-- gathering nodes at its edge (the generators append them to their own). Pure and deterministic.
--
-- The frame of a hideout is its centre turned by `rot` (front = local -Z, towards the road). The middle (LAIR_FREE
-- studs) stays empty: the Elite II stands there and its Pounce and Crushing Blow (S134e) need room. Big shapes are
-- "shell" (seen from afar: tent, stakes, standing stones, a fallen column, a banner), the small ones "detail" / "fine"
-- (bones, candles, a weapon rack). Every hideout has one chest as a prop (no loot: the Elite II and the nodes give it).
-- Themes (one per region, colours of the region): "poachers" (Meadows: tent, stake fence, campfire, drying hides),
-- "gallows" (Duskwood: dead gallows trees with ropes, a stone ring, candles, bones), "bonepit" (Wastes: bones, skulls,
-- a fallen column, embers), "frozencamp" (Peaks: a snowed-in tent, icicles, a dead campfire, a torn banner).

local AreaTypes = require("../../Data/Areas/Types")
local Kit = require("./Kit")
local Structures = require("./Structures")

local o = Kit.o

local Lairs = {}

type Build = Kit.Build
type BP = Kit.BP
type Lair = AreaTypes.Lair
export type NodePlacement = { kind: string, x: number, z: number }

Lairs.FREE = 8 -- studs around the centre without any prop (tests/lairs.spec)
Lairs.NODE_EDGE = 0.86 -- nodes at this share of the radius
Lairs.CHEST_AT = { -0.3, 0.62 } -- the chest: local x, z as shares of the radius (behind the Elite II)
Lairs.NODE_GAP = 24 -- least distance of a hideout's node from any other node (the generators' rule)
local NODE_SHIFTS = { 0, 20, -20, 40, -40, 60, -60 } -- degrees tried around a node's angle when another node is near

-- Node angles (degrees from the front, clockwise seen from above) by node count: the back half, apart.
local NODE_ANGLES: { [number]: { number } } = {
	[1] = { 180 },
	[2] = { 125, 235 },
	[3] = { 95, 180, 265 },
}

local SNOW = { c = "#E8EEF4", m = "Snow" }
local ICE = { c = "#A8D8F0", m = "Ice" }
local CANVAS = { c = "#9C8F74", m = "Fabric" }
local SNOWED_CANVAS = { c = "#C9CCC8", m = "Fabric" }
local SAND_STONE = { c = "#9A7B55", m = "Sandstone" }
local BANNER = { c = "#5A1E1E", m = "Fabric" }
local EMBERS = "#FF5A1E"

-- Local (x, z) of a point at `angle` degrees from the front (-Z) at `d` studs.
local function polar(angle: number, d: number): (number, number)
	local a = math.rad(angle)
	return math.sin(a) * d, -math.cos(a) * d
end

-- Distance of an inner prop: `k` of the radius, never closer than FREE + 4 to the middle (small hideouts).
local function inner(r: number, k: number): number
	return math.max(r * k, Lairs.FREE + 4)
end

local function far(list: { NodePlacement }, x: number, z: number): boolean
	for _, n in list do
		if (n.x - x) ^ 2 + (n.z - z) ^ 2 < Lairs.NODE_GAP * Lairs.NODE_GAP then
			return false
		end
	end
	return true
end

-- Every hideout's nodes of a region map (data order of `lair.nodes`) at the edge of its circle, each NODE_GAP from
-- the nodes in `taken` (the generator's own) and from each other: its angle, else the first of NODE_SHIFTS that fits
-- (none fits: the angle itself; tests/lairs.spec keeps the gap).
function Lairs.nodes(def: AreaTypes.MapAreas, taken: { NodePlacement }?): { NodePlacement }
	local out: { NodePlacement } = {}
	local all: { NodePlacement } = table.clone(taken or {})
	for _, lair in (def.lairs or {}) :: { Lair } do
		local angles = NODE_ANGLES[#lair.nodes] or NODE_ANGLES[3]
		for i, kind in lair.nodes do
			local base = angles[i] or (i * 120)
			local node: NodePlacement? = nil
			for _, shift in NODE_SHIFTS do
				local lx, lz = polar(base + shift, lair.r * Lairs.NODE_EDGE)
				local x, z = Kit.toWorld(lair.x, lair.z, lair.rot, lx, lz)
				local candidate = { kind = kind, x = math.floor(x + 0.5), z = math.floor(z + 0.5) }
				node = node or candidate
				if far(all, candidate.x, candidate.z) then
					node = candidate
					break
				end
			end
			local placed = node :: NodePlacement
			table.insert(out, placed)
			table.insert(all, placed)
		end
	end
	return out
end

-- The hideout of the map at a map-relative point (its circle grown by `extra`), or nil.
function Lairs.at(def: AreaTypes.MapAreas, x: number, z: number, extra: number?): Lair?
	for _, lair in (def.lairs or {}) :: { Lair } do
		local r = lair.r + (extra or 0)
		if (x - lair.x) ^ 2 + (z - lair.z) ^ 2 < r * r then
			return lair
		end
	end
	return nil
end

-- Removes from `list` (Builds or node placements, from index `from` on) what stands in a hideout: the generators
-- place their rocks and nodes before the hideouts and drop the few that fell inside, so every other one stays where
-- it was.
function Lairs.prune<T>(def: AreaTypes.MapAreas, list: { T }, extra: number, from: number?, keep: ((item: T) -> boolean)?)
	local i = from or 1
	while i <= #list do
		local item: any = list[i]
		local x = if item.at then item.at.x else item.x
		local z = if item.at then item.at.z else item.z
		if Lairs.at(def, x, z, extra) and not (keep and keep(item)) then
			table.remove(list, i)
		else
			i += 1
		end
	end
end

-- Chest prop (detail; the body collides): planks, iron bands, a lid a little open.
local function chest(ctx: Kit.Ctx, b: Build, lx: number, lz: number, yaw: number)
	local bp = b.bp
	local y = Kit.gy(ctx, b, lx, lz)
	bp:push(lx, y, lz, 0, yaw, 0)
	bp:box(3, 1.6, 1.8, 0, 0.8, 0, o(Kit.planks, "shell", { q = false }))
	bp:rbox(3.1, 0.35, 1.9, 0, 1.75, 0.15, -14, 0, 0, o(Kit.planks, "detail", { col = false }))
	for _, sx in { -1.05, 1.05 } do
		bp:box(0.2, 1.7, 1.9, sx, 0.85, 0, o(Kit.iron, "detail", { col = false }))
	end
	bp:box(0.5, 0.5, 0.15, 0, 1.15, -0.95, o(Kit.iron, "fine", { col = false }))
	bp:pop()
end

-- Weapon rack (detail / fine): two posts, a bar and three leaning blades or spears.
local function rack(ctx: Kit.Ctx, b: Build, lx: number, lz: number, yaw: number, metal: Kit.Swatch)
	local bp = b.bp
	local y = Kit.gy(ctx, b, lx, lz)
	bp:push(lx, y, lz, 0, yaw, 0)
	for _, sx in { -1.6, 1.6 } do
		bp:box(0.3, 2.6, 0.3, sx, 1.3, 0, o(Kit.timber, "detail", { col = false }))
	end
	bp:box(3.6, 0.25, 0.25, 0, 2.2, 0, o(Kit.timber, "detail", { col = false }))
	for k = -1, 1 do
		bp:rbox(0.18, 3, 0.4, k * 0.9, 1.4, 0.35, 12, 0, k * 4, o(metal, "fine", { col = false }))
	end
	bp:pop()
end

-- Poachers' camp (Meadows): a stake fence open to the front, a tent, a campfire, drying hides on a rack.
local function poachers(ctx: Kit.Ctx, b: Build, lair: Lair)
	local bp, r = b.bp, lair.r
	-- the front (-Z) is local angle -90 degrees in the palisade's (cos, sin) frame
	Structures.palisade(ctx, b, r - 1, 18, -math.pi / 2, math.rad(150), 3.2, Kit.bark, "#6A5440")
	local tx, tz = polar(220, math.max(r * 0.62, Lairs.FREE + 7))
	Structures.tent(bp, tx, Kit.gy(ctx, b, tx, tz), tz, 40, CANVAS, false)
	local fx, fz = polar(130, inner(r, 0.5))
	Kit.campfire(bp, fx, Kit.gy(ctx, b, fx, fz), fz, "detail")
	-- drying rack with hides
	local hx, hz = polar(80, r * 0.66)
	local hy = Kit.gy(ctx, b, hx, hz)
	bp:push(hx, hy, hz, 0, 80, 0)
	for _, sx in { -2, 2 } do
		bp:box(0.35, 3.4, 0.35, sx, 1.7, 0, o(Kit.timber, "shell"))
	end
	bp:box(4.6, 0.3, 0.3, 0, 3.2, 0, o(Kit.timber, "detail", { col = false }))
	for k = -1, 1, 2 do
		bp:rbox(1.6, 2, 0.12, k * 1, 2.1, 0, 0, 0, k * 4, o(Kit.hide, "detail", { col = false }))
	end
	bp:pop()
	do
		local kx, kz = polar(290, r * 0.64)
		rack(ctx, b, kx, kz, 290 + 180, Kit.iron)
	end
	for i, angle in { 160, 300 } do
		local px, pz = polar(angle, inner(r, 0.48))
		Kit.bones(bp, px, Kit.gy(ctx, b, px, pz), pz, 2 + i, function(lx: number, lz: number): number
			return Kit.gy(ctx, b, lx, lz)
		end)
	end
	local lx, lz = polar(330, r * 0.8)
	Kit.lantern(bp, lx, Kit.gy(ctx, b, lx, lz), lz, nil, 5, "detail")
end

-- Hanged men's ring (Duskwood): standing stones in a broken ring, dead gallows trees with ropes, candles and bones.
local function gallows(ctx: Kit.Ctx, b: Build, lair: Lair)
	local bp, r = b.bp, lair.r
	for k = 0, 8 do
		local angle = 30 + k * 37.5
		local sx, sz = polar(angle, r * 0.88)
		local sy = Kit.gy(ctx, b, sx, sz)
		bp:rbox(1.6, 4.4 + (k % 3) * 0.8, 1.2, sx, sy + 1.8, sz, (k % 2) * 6 - 3, angle, 0, o(Kit.mossyStone, "shell"))
	end
	for i, angle in { 120, 245 } do
		local gx, gz = polar(angle, r * 0.62)
		local gy = Kit.gy(ctx, b, gx, gz)
		bp:push(gx, gy, gz, 0, angle + 90, 0)
		bp:box(0.9, 7.5, 0.9, 0, 3.6, 0, o(Kit.deadBark, "shell"))
		bp:rbox(4.2, 0.6, 0.6, 1.7, 6.9, 0, 0, 0, 8, o(Kit.deadBark, "shell"))
		bp:rbox(0.5, 1.6, 0.5, -0.6, 5.8, 0, 0, 0, -35, o(Kit.deadBark, "detail", { col = false }))
		-- the rope and its frayed end
		bp:box(0.14, 2.6, 0.14, 3.2, 5.6, 0, o(Kit.rope, "detail", { col = false }))
		bp:rbox(0.5, 0.18, 0.5, 3.2, 4.2, 0, 0, 45, 0, o(Kit.rope, "fine", { col = false }))
		bp:pop()
		Kit.lifeAt(ctx, b, "perch", gx, gy + 7.4, gz)
		local cx, cz = polar(angle + 25, inner(r, 0.5))
		local cy = Kit.gy(ctx, b, cx, cz)
		for c = 0, 2 + i do
			local a = c * 2.1
			Kit.candle(bp, cx + math.cos(a) * 1.2, cy, cz + math.sin(a) * 1.2, 0.6 + (c % 2) * 0.4, "#C9FFB0")
		end
	end
	for _, angle in { 170, 300, 60 } do
		local px, pz = polar(angle, inner(r, 0.52))
		Kit.bones(bp, px, Kit.gy(ctx, b, px, pz), pz, 3, function(lx: number, lz: number): number
			return Kit.gy(ctx, b, lx, lz)
		end)
	end
	do
		local kx, kz = polar(330, r * 0.66)
		rack(ctx, b, kx, kz, 330 + 180, Kit.iron)
	end
end

-- Bone pit (Wastes): a ring of ribs, scattered bones and skulls, a fallen column, embers in a pit.
local function bonepit(ctx: Kit.Ctx, b: Build, lair: Lair)
	local bp, r = b.bp, lair.r
	-- ribs of a great carcass along the back (shell arcs of two tilted bones each)
	for k = 0, 4 do
		local angle = 140 + k * 20
		local rx, rz = polar(angle, r * 0.78)
		local ry = Kit.gy(ctx, b, rx, rz)
		bp:rbox(0.9, 6.5, 0.9, rx, ry + 2.8, rz, 0, angle, 22, o(Kit.oldBone, "shell"))
	end
	-- the fallen column and its drum
	local cx, cz = polar(70, r * 0.66)
	local cy = Kit.gy(ctx, b, cx, cz)
	bp:add("cyl", 9, 2.2, 2.2, cx, cy + 1, cz, 0, 160, 4, o(SAND_STONE, "shell"))
	bp:add("cyl", 1.6, 2.6, 2.6, cx + 3.4, cy + 0.8, cz - 2.2, 0, 0, 90, o(SAND_STONE, "detail", { col = false }))
	-- embers in a shallow pit
	local ex, ez = polar(285, inner(r, 0.5))
	local ey = Kit.gy(ctx, b, ex, ez)
	for i = 0, 5 do
		local a = i * math.pi / 3
		bp:rbox(
			1,
			0.5,
			1,
			ex + math.cos(a) * 1.8,
			ey + 0.2,
			ez + math.sin(a) * 1.8,
			0,
			math.deg(a),
			0,
			o(Kit.charred, "detail", { col = false })
		)
	end
	Kit.fire(bp, ex, ey + 0.3, ez, 1.6, EMBERS, "detail")
	for _, angle in { 30, 110, 200, 250, 330 } do
		local px, pz = polar(angle, inner(r, 0.5))
		Kit.bones(bp, px, Kit.gy(ctx, b, px, pz), pz, 4, function(lx: number, lz: number): number
			return Kit.gy(ctx, b, lx, lz)
		end)
	end
	for k = 0, 3 do
		local sx, sz = polar(10 + k * 95, r * 0.84)
		Kit.skull(bp, sx, Kit.gy(ctx, b, sx, sz) - 0.05, sz, 1.3, k * 70)
	end
	do
		local kx, kz = polar(320, r * 0.68)
		rack(ctx, b, kx, kz, 320 + 180, Kit.iron)
	end
end

-- Frozen camp (Peaks): a snowed-in tent, icicles on a broken frame, a dead campfire, a torn banner.
local function frozencamp(ctx: Kit.Ctx, b: Build, lair: Lair)
	local bp, r = b.bp, lair.r
	local tx, tz = polar(215, math.max(r * 0.62, Lairs.FREE + 7))
	local ty = Kit.gy(ctx, b, tx, tz)
	Structures.tent(bp, tx, ty, tz, 35, SNOWED_CANVAS, true)
	bp:rbox(7, 1.2, 4.5, tx, ty + 0.4, tz, 0, 35, 0, o(SNOW, "shell", { q = false }))
	-- a broken frame hung with icicles
	local fx, fz = polar(125, r * 0.64)
	local fy = Kit.gy(ctx, b, fx, fz)
	bp:push(fx, fy, fz, 0, 125, 0)
	for _, sx in { -2.4, 2.4 } do
		bp:box(0.4, 4.2, 0.4, sx, 2.1, 0, o(Kit.timber, "shell"))
	end
	bp:rbox(5.6, 0.4, 0.4, 0, 4, 0, 0, 0, 6, o(Kit.timber, "shell"))
	for k = -2, 2 do
		bp:add("wedge", 0.3, 1.2 + (k % 2) * 0.7, 0.3, k * 1, 3.2, 0, 180, 0, 0, o(ICE, "fine", { col = false }))
	end
	bp:pop()
	-- the dead campfire: stones and charred logs, no flame
	local cx, cz = polar(150, inner(r, 0.42))
	local cy = Kit.gy(ctx, b, cx, cz)
	for i = 0, 7 do
		local a = i * math.pi / 4
		bp:rbox(
			0.9,
			0.6,
			0.9,
			cx + math.cos(a) * 1.9,
			cy + 0.25,
			cz + math.sin(a) * 1.9,
			0,
			math.deg(a),
			0,
			o(Kit.stone, "detail", { col = false })
		)
	end
	for i = 0, 2 do
		bp:add("cyl", 3, 0.6, 0.6, cx, cy + 0.4, cz, 0, i * 60, 10, o(Kit.charred, "detail", { col = false }))
	end
	bp:box(2.6, 0.3, 2.6, cx, cy + 0.6, cz, o(SNOW, "fine", { col = false }))
	-- the torn banner on a pole
	local bx, bz = polar(300, r * 0.7)
	local by = Kit.gy(ctx, b, bx, bz)
	bp:box(0.4, 8, 0.4, bx, by + 4, bz, o(Kit.darkBark, "shell"))
	bp:box(0.3, 0.3, 3, bx, by + 7.7, bz + 1.4, o(Kit.darkBark, "detail", { col = false }))
	bp:box(0.12, 3.2, 2.6, bx, by + 6, bz + 1.5, o(BANNER, "detail", { col = false, tag = "flag" }))
	for _, angle in { 60, 250 } do
		local px, pz = polar(angle, inner(r, 0.55))
		Kit.bones(bp, px, Kit.gy(ctx, b, px, pz), pz, 2, function(lx: number, lz: number): number
			return Kit.gy(ctx, b, lx, lz)
		end)
	end
	for k = 0, 5 do
		local sx, sz = polar(20 + k * 60, r * 0.9)
		Kit.rock(bp, sx, Kit.gy(ctx, b, sx, sz) - 0.5, sz, 1.6 + (k % 3) * 0.5, SNOW, "detail")
	end
	do
		local kx, kz = polar(60, r * 0.7)
		rack(ctx, b, kx, kz, 60 + 180, Kit.iron)
	end
end

local THEMES: { [string]: (ctx: Kit.Ctx, b: Build, lair: Lair) -> () } = {
	poachers = poachers,
	gallows = gallows,
	bonepit = bonepit,
	frozencamp = frozencamp,
}
Lairs.THEMES = { "poachers", "gallows", "bonepit", "frozencamp" }

-- The Build of one hideout: its theme's dressing and the chest.
function Lairs.build(ctx: Kit.Ctx, lair: Lair): Build
	local b = Kit.build(ctx, `Lair_{lair.id}`, "lair", lair.x, lair.z, lair.rot)
	local theme = THEMES[lair.theme]
	if theme then
		theme(ctx, b, lair)
	end
	local cx, cz = Lairs.CHEST_AT[1] * lair.r, Lairs.CHEST_AT[2] * lair.r
	chest(ctx, b, cx, cz, 180 + 15)
	return b
end

-- Every hideout of a region map, in data order.
function Lairs.all(ctx: Kit.Ctx, def: AreaTypes.MapAreas): { Build }
	local out: { Build } = {}
	for _, lair in (def.lairs or {}) :: { Lair } do
		table.insert(out, Lairs.build(ctx, lair))
	end
	return out
end

return Lairs
