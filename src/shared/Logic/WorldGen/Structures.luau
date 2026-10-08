--!strict
-- Shared structures of the region generators (S45): ring palisade, tent, bridges (stone arch, timber, ford stones),
-- the waterfall curtain and stones along a stream. Copied from Logic/MeadowsGen (Camps, Water) and generalised to
-- any map's terrain; the Meadows keep their own copies so their Builds stay identical. Pure.

local Kit = require("./Kit")
local Palette = require("../TownGen/Palette")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o

local Structures = {}

type Build = Kit.Build
type BP = Kit.BP

-- Terrain queries the structures need (Logic/RegionTerrain's API).
export type Ground = {
	height: (x: number, z: number) -> number,
	water: (x: number, z: number) -> number?,
	roadDistance: (x: number, z: number) -> number,
	crossings: () -> { any },
	streamLine: (index: number) -> TerrainLayers.Line,
	streamLevel: (index: number, s: number) -> number,
}

-- Ring palisade of `n` segments around the frame origin with a gap of `gap` radians centred on angle `door`. The
-- server builds one wall core per segment; the pointed stakes are client detail. `cap` decorates every few stakes
-- (skulls, violet rags).
function Structures.palisade(
	ctx: Kit.Ctx,
	b: Build,
	radius: number,
	n: number,
	door: number,
	gap: number,
	h: number,
	wall: Kit.Swatch,
	stake: string,
	cap: ((bp: BP, x: number, y: number, z: number, k: number) -> ())?
)
	local bp = b.bp
	for i = 0, n - 1 do
		local a1 = i * 2 * math.pi / n
		local a2 = (i + 1) * 2 * math.pi / n
		local mid = (a1 + a2) / 2
		local off = math.abs(((mid - door + math.pi) % (2 * math.pi)) - math.pi)
		if off > gap / 2 then
			local x1, z1 = math.cos(a1) * radius, math.sin(a1) * radius
			local x2, z2 = math.cos(a2) * radius, math.sin(a2) * radius
			local y1, y2 = Kit.gy(ctx, b, x1, z1), Kit.gy(ctx, b, x2, z2)
			local base = math.min(y1, y2) - 1
			local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
			local yaw = math.deg(math.atan2(-(z2 - z1), x2 - x1))
			local tall = h - 1 + (math.max(y1, y2) - base)
			bp:add(
				"box",
				len + 0.6,
				tall,
				1.4,
				(x1 + x2) / 2,
				base + tall / 2,
				(z1 + z2) / 2,
				0,
				yaw,
				0,
				o(wall, "shell", { q = true })
			)
			local stakes = math.floor(len / 1.5)
			for k = 0, stakes do
				local t = k / math.max(1, stakes)
				local sx, sz = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
				local sy = y1 + (y2 - y1) * t
				local sh = h + bp.rng:float(-0.6, 0.9)
				bp:add(
					"cyl",
					sh,
					1.3,
					1.3,
					sx,
					sy + sh / 2 - 0.5,
					sz,
					0,
					0,
					90,
					o({ c = bp:jitter(stake, 0.1), m = "Wood" }, "detail", { col = false })
				)
				bp:add("ball", 0.9, 1.2, 0.9, sx, sy + sh - 0.3, sz, 0, 0, 0, o({ c = stake, m = "Wood" }, "fine"))
				if cap and k % 5 == 2 then
					cap(bp, sx, sy + sh, sz, k)
				end
			end
		end
	end
	for _, side in { -1, 1 } do
		local a = door + side * gap / 2
		local x, z = math.cos(a) * radius, math.sin(a) * radius
		local gy = Kit.gy(ctx, b, x, z)
		bp:add("cyl", h + 3, 2, 2, x, gy + (h + 3) / 2 - 0.5, z, 0, 0, 90, o(Kit.timber, "shell", { q = true }))
		if cap then
			cap(bp, x, gy + h + 2.6, z, 0)
		end
	end
end

-- Tent of two cloth planes on poles, ridge along local X of a sub-frame at (x, y, z) turned by `yaw`.
function Structures.tent(bp: BP, x: number, y: number, z: number, yaw: number, cloth: Kit.Swatch, torn: boolean?)
	bp:push(x, y, z, 0, yaw, 0)
	for _, side in { -1, 1 } do
		if torn and side == 1 then
			-- the torn side hangs from the ridge in strips
			for k = -1, 1 do
				bp:rbox(2.2, 0.2, 4.4, k * 2.8, 1.9, 2.4, 70, 0, k * 8, o(cloth, "detail", { col = false }))
			end
		else
			bp:rbox(8.5, 0.3, 5.6, 0, 2.4, side * 2.05, side * 52, 0, 0, o(cloth, "shell", { q = true }))
		end
	end
	bp:box(0.35, 5, 0.35, 4, 2.3, 0, o(Kit.timber, "detail"))
	bp:box(0.35, 5, 0.35, -4, 2.3, 0, o(Kit.timber, "detail"))
	bp:box(8.8, 0.3, 0.3, 0, 4.7, 0, o(Kit.timber, "detail"))
	bp:pop()
end

-- Bridges --------------------------------------------------------------------------------------------------------

local function stoneBridge(b: Build, span: number, width: number, waterY: number, lamp: string?)
	local bp = b.bp
	local stone = Palette.rubble[3]
	local dressed = { c = "#5E5A55", m = "Slate" }
	local half = span / 2
	bp:box(width, 1.2, span + 6, 0, -0.6, 0, o(stone, "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:box(1, 1.4, span + 6, side * (width / 2 - 0.5), 0.7, 0, o(dressed, "shell", { q = true }))
		bp:box(1.2, 0.3, span + 6.2, side * (width / 2 - 0.5), 1.5, 0, o(Kit.mossyStone, "detail"))
		bp:box(width + 1, 6, 4, 0, -3.6, side * (half + 1), o(stone, "shell", { q = true }))
	end
	local n = 9
	local rise = math.max(1.5, -waterY - 1.2)
	for k = 0, n - 1 do
		local t = (k + 0.5) / n
		local zz = -half + span * t
		local thick = 0.6 + rise * (2 * t - 1) ^ 2
		bp:box(
			width - 0.4,
			thick,
			span / n + 0.1,
			0,
			-1.2 - thick / 2,
			zz,
			o(Palette.rubble[(k % 3) + 1], "detail", { col = false })
		)
	end
	Kit.lantern(bp, width / 2 + 0.6, 0, -half - 2, lamp, 6)
	bp:box(width * 0.6, 0.2, 3, 0, -1.25, half - 2, o(Kit.moss, "fine", { col = false }))
end

local function woodBridge(b: Build, span: number, width: number, waterY: number)
	local bp = b.bp
	local half = span / 2 + 2
	bp:box(width, 0.6, span + 4, 0, -0.3, 0, o(Palette.greyPlanks[2], "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:box(0.8, 1, span + 4, side * (width / 2 - 1), -1.1, 0, o(Kit.timber, "detail", { col = false }))
		bp:box(0.4, 0.4, span + 4, side * (width / 2 - 0.2), 2.6, 0, o(Kit.timber, "shell", { q = false }))
		for k = 0, 3 do
			local zz = -half + k * (2 * half) / 3
			bp:box(0.5, 3, 0.5, side * (width / 2 - 0.2), 1.2, zz, o(Kit.timber, "detail"))
			bp:add(
				"cyl",
				-waterY + 3,
				0.9,
				0.9,
				side * (width / 2 - 1),
				(waterY - 3) / 2 - 1,
				zz,
				0,
				0,
				90,
				o(Kit.timber, "detail", { col = false })
			)
		end
	end
	for k = 0, math.floor((span + 4) / 1.3) do
		bp:box(width + 0.1, 0.1, 0.22, 0, 0.02, -half + k * 1.3, o(Palette.greyPlanks[3], "fine"))
	end
end

local function ford(g: Ground, b: Build, span: number)
	local bp = b.bp
	local n = math.floor(span / 2.2)
	for k = 0, n do
		local zz = -span / 2 + k * span / n
		local lx = 7 + (k % 2) * 0.8
		local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, lx, zz)
		local y = g.height(wx, wz) - b.at.y
		local water = g.water(wx, wz)
		local top = if water then water - b.at.y + 0.35 else y + 0.3
		bp:rbox(
			1.8,
			top - y + 0.6,
			1.6,
			lx,
			(top + y - 0.6) / 2,
			zz,
			0,
			k * 23,
			0,
			o(Kit.mossyStone, "shell", { q = false })
		)
	end
end

-- A bridge (or ford stones) at every crossing of a road and a stream; `lamp` is the lantern colour on stone bridges.
function Structures.bridges(ctx: Kit.Ctx, g: Ground, out: { Build }, lamp: string?)
	for i, c in g.crossings() do
		local rot = math.deg(math.atan2(-c.dirX, -c.dirZ))
		local width = if c.kind == "stone" then 13 else 11
		local name = `Bridge_{i}_{c.kind}`
		local b = Kit.buildAt(name, "bridge", c.x, c.deck + 0.05, c.z, rot)
		local waterY = c.water - b.at.y
		if c.kind ~= "ford" then
			Kit.rect(ctx, "bridge", c.x, c.z, width, c.span + 4, rot)
		end
		if c.kind == "stone" then
			stoneBridge(b, c.span, width, waterY, lamp)
		elseif c.kind == "ford" then
			b.at.y = g.height(c.x, c.z)
			ford(g, b, c.span + 6)
		else
			woodBridge(b, c.span, width, waterY)
		end
		table.insert(out, b)
	end
end

-- Waterfall from the lip of stream `head` (a centre-only stream ending at a cliff) down to the start of stream
-- `pool`: slanted sheets of falling water ("waterfall"), foam at the foot ("foam"), rocks of `rock` around.
function Structures.waterfall(
	ctx: Kit.Ctx,
	g: Ground,
	out: { Build },
	head: number,
	pool: number,
	rock: Kit.Swatch,
	water: string?
): Build
	local line = g.streamLine(head)
	local lip = line.pts[#line.pts]
	local prev = line.pts[#line.pts - 1]
	local dx, dz = lip[1] - prev[1], lip[2] - prev[2]
	local len = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / len, dz / len
	local top = g.streamLevel(head, line.length)
	local poolY = g.streamLevel(pool, 0)
	local bx, bz = lip[1], lip[2]
	for k = 1, 40 do
		bx, bz = lip[1] + dx * k, lip[2] + dz * k
		if g.height(bx, bz) < poolY + 1.5 then
			break
		end
	end
	local rot = math.deg(math.atan2(-dx, -dz))
	local b = Kit.buildAt("Waterfall", "waterfall", lip[1], poolY, lip[2], rot)
	local bp = b.bp
	local horiz = math.sqrt((bx - lip[1]) ^ 2 + (bz - lip[2]) ^ 2) + 2
	local drop = top - poolY + 0.6
	local tilt = math.deg(math.atan2(horiz, drop))
	local sheetLen = math.sqrt(horiz * horiz + drop * drop)
	local c = water or "#CFE6F2"
	for k = -1, 1 do
		bp:rbox(
			2.6 - math.abs(k) * 0.6,
			sheetLen,
			0.5,
			k * 1.9,
			drop / 2,
			-horiz / 2,
			tilt,
			0,
			k * 3,
			o({ c = c, m = "Glass" }, "shell", {
				col = false,
				q = false,
				t = 0.3 + math.abs(k) * 0.14,
				tag = if k == 0 then "waterfall" else nil,
				jitter = 0,
			})
		)
	end
	bp:add(
		"ball",
		9,
		1.4,
		8,
		0,
		0.1,
		-horiz - 3,
		0,
		0,
		0,
		o({ c = "#C8D0D0", m = "SmoothPlastic" }, "detail", { col = false, t = 0.5, tag = "foam", jitter = 0 })
	)
	for k = -1, 1, 2 do
		Kit.rock(bp, k * 5.5, drop - 2, 1, 5, rock, "shell")
		Kit.rock(bp, k * 7, 0, -horiz - 1, 4.5, rock, "shell")
	end
	table.insert(out, b)
	local wx, wy, wz = Kit.worldOf(b, 0, 0.5, -horiz - 4)
	Kit.life(ctx, "mist", wx, wy, wz, 12)
	return b
end

-- Stones along a stream (client detail), every `every` studs, off the roads.
function Structures.banks(ctx: Kit.Ctx, g: Ground, out: { Build }, stream: number, every: number, sw: Kit.Swatch)
	local line = g.streamLine(stream)
	local s = 30
	local i = 0
	while s < line.length - 20 do
		local x, z, dx, dz = TerrainLayers.pointAt(line, s)
		i += 1
		local side = if i % 2 == 0 then 1 else -1
		local px, pz = x - dz * side * 8, z + dx * side * 8
		if g.roadDistance(px, pz) > 8 then
			local b = Kit.build(ctx, `StreamStones_{stream}_{i}`, "brook", px, pz, i * 37)
			for k = 1, 4 do
				Kit.rock(b.bp, (k - 2) * 1.6, -0.4, (k % 2) * 1.2, 1.2 + (k % 3) * 0.5, sw, "detail")
			end
			table.insert(out, b)
		end
		s += every
	end
end

return Structures
