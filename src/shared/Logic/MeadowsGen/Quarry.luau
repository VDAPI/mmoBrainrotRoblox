--!strict
-- Old Quarry dressing (S26): scaffolds against the terrace walls, rails with ore carts on the first terrace, heaps
-- of copper and iron ore, small green kobold lanterns, three boarded tunnel mouths (the quest anchors tunnel_1..3
-- stand in front of them), a winch on the rim and the miner's shed. Pure.

local Areas = require("../../Data/Areas/meadows")
local AreaTypes = require("../../Data/Areas/Types")
local Kit = require("./Kit")
local MeadowsTerrain = require("../MeadowsTerrain")
local Palette = require("../TownGen/Palette")
local Parts = require("../TownGen/Parts")
local Shape = require("../../Data/Terrain/meadows")

local o = Kit.o
local sites = assert(Areas.sites, "meadows sites")
local Q = Shape.quarry

local Quarry = {}

type Build = Kit.Build

local KOBOLD_LIGHT = "#8CFF7A"

-- Point on the quarry ellipse at normalised radius e and angle a (radians, x = cos, z = sin).
local function ring(e: number, a: number): (number, number)
	return Q.x + Q.rx * e * math.cos(a), Q.z + Q.rz * e * math.sin(a)
end

-- Yaw (degrees) that turns a Build's front (-Z) towards the quarry centre from (x, z).
local function faceCentre(x: number, z: number): number
	local dx, dz = Q.x - x, Q.z - z
	return math.deg(math.atan2(-dx, -dz))
end

-- Boarded tunnel mouth in a terrace wall: timber frame, dark hole, planks nailed across.
local function tunnel(out: { Build }, i: number, x: number, z: number)
	-- stand the frame against the wall: 3 studs further out than the anchor
	local dx, dz = x - Q.x, z - Q.z
	local len = math.sqrt(dx * dx + dz * dz)
	local fx, fz = x + dx / len * 3, z + dz / len * 3
	local b = Kit.build(`QuarryTunnel_{i}`, "quarry", fx, fz, faceCentre(fx, fz))
	b.at.y = MeadowsTerrain.height(x, z)
	local bp = b.bp
	bp:box(4.6, 5, 0.4, 0, 2.5, 0.6, o({ c = "#0E0C0A", m = "SmoothPlastic" }, "shell", { col = false }))
	for _, side in { -1, 1 } do
		bp:box(0.8, 5.6, 0.8, side * 2.6, 2.8, 0, o(Kit.timber, "shell", { q = true }))
	end
	bp:box(6.4, 0.9, 1, 0, 5.8, 0, o(Kit.timber, "shell", { q = true }))
	for k = 0, 3 do
		bp:rbox(
			5.4,
			0.6,
			0.25,
			0,
			1 + k * 1.2,
			-0.3,
			0,
			0,
			(k % 2) * 10 - 5,
			o(Palette.greyPlanks[k % 3 + 1], "detail")
		)
	end
	bp:box(0.25, 0.25, 0.1, 1.8, 2.2, -0.5, o(Kit.iron, "fine"))
	Kit.lantern(bp, 3.6, 0, -1.4, KOBOLD_LIGHT, 3.2)
	table.insert(out, b)
end

-- Scaffold against a terrace wall: posts, two platforms, a ladder.
local function scaffold(out: { Build }, i: number, e: number, a: number, h: number)
	local x, z = ring(e, a)
	local b = Kit.build(`QuarryScaffold_{i}`, "quarry", x, z, faceCentre(x, z))
	local bp = b.bp
	for _, c in { { -3, -1.5 }, { 3, -1.5 }, { -3, 1.5 }, { 3, 1.5 } } do
		bp:box(0.5, h + 1, 0.5, c[1], (h + 1) / 2 + Kit.gy(b, c[1], c[2]) - 0.5, c[2], o(Kit.timber, "detail"))
	end
	for _, y in { h * 0.5, h } do
		bp:box(7, 0.35, 3.6, 0, y, 0, o(Palette.greyPlanks[2], if y == h then "shell" else "detail", { q = true }))
		bp:box(7, 0.25, 0.25, 0, y + 1.1, -1.7, o(Kit.timber, "detail"))
	end
	for k = 0, math.floor(h / 1.2) do
		bp:box(1.4, 0.2, 0.25, -3.6, 0.6 + k * 1.2, -1.2, o(Kit.planks, "detail"))
	end
	bp:beam(-3, 0.5, -1.5, 3, h, -1.5, 0.3, o(Kit.timber, "detail"))
	table.insert(out, b)
end

-- Rails along the first terrace from angle a1 to a2 with sleepers, and an ore cart on them.
local function rails(out: { Build }, i: number, e: number, a1: number, a2: number, cart: number)
	local x0, z0 = ring(e, (a1 + a2) / 2)
	local b = Kit.build(`QuarryRails_{i}`, "quarry", x0, z0, 0)
	local bp = b.bp
	local steps = math.floor(math.abs(a2 - a1) * Q.rx * e / 3)
	local prev: { number }? = nil
	for k = 0, steps do
		local a = a1 + (a2 - a1) * k / steps
		local wx, wz = ring(e, a)
		local lx, lz = wx - x0, wz - z0
		local y = MeadowsTerrain.height(wx, wz) - b.at.y
		local tx, tz = -math.sin(a) * Q.rx, math.cos(a) * Q.rz
		local tl = math.sqrt(tx * tx + tz * tz)
		tx, tz = tx / tl, tz / tl
		local yaw = math.deg(math.atan2(-tz, tx))
		bp:add("box", 0.4, 0.25, 3.4, lx, y + 0.12, lz, 0, yaw, 0, o(Kit.planks, "detail", { col = false }))
		if prev then
			for _, side in { -1, 1 } do
				local nx, nz = -tz * side * 1.2, tx * side * 1.2
				bp:beam(
					prev[1] + nx,
					prev[3] + 0.4,
					prev[2] + nz,
					lx + nx,
					y + 0.4,
					lz + nz,
					0.22,
					o(Kit.iron, "detail", { col = false })
				)
			end
		end
		if k == cart then
			bp:push(lx, y + 0.5, lz, 0, yaw + 90, 0)
			bp:box(2.6, 1.8, 3.6, 0, 1.4, 0, o({ c = "#4A4440", m = "CorrodedMetal" }, "shell", { q = true }))
			bp:add("ball", 2.4, 1.2, 3, 0, 2.4, 0, 0, 0, 0, o({ c = "#B8743A", m = "Slate" }, "detail"))
			for _, c in { { -1.4, -1.2 }, { 1.4, -1.2 }, { -1.4, 1.2 }, { 1.4, 1.2 } } do
				bp:add("cyl", 0.35, 1.1, 1.1, c[1], 0.5, c[2], 0, 0, 0, o(Kit.iron, "detail"))
			end
			bp:pop()
		end
		prev = { lx, lz, y }
	end
	table.insert(out, b)
end

-- Heap of ore: copper (orange-green) or iron (rust red).
local function oreHeap(out: { Build }, i: number, x: number, z: number, copper: boolean)
	local b = Kit.build(`OreHeap_{i}`, "quarry", x, z, i * 40)
	local bp = b.bp
	local main = if copper then "#9A6A3A" else "#7A4A3A"
	bp:add("ball", 6, 3, 5, 0, 0.6, 0, 0, 0, 0, o({ c = main, m = "Slate" }, "shell", { q = false }))
	for k = 1, 6 do
		local a = k * 1.05
		bp:rbox(
			1,
			0.8,
			1,
			math.cos(a) * 3.2,
			0.3,
			math.sin(a) * 2.6,
			k * 20,
			k * 30,
			0,
			o({ c = if copper and k % 2 == 0 then "#4A8A6A" else main, m = "Slate" }, "detail", { col = false })
		)
	end
	table.insert(out, b)
end

-- Miner's shed on the rim: plank walls, a lean-to roof, tools, a grinding stone.
local function shed(out: { Build })
	local s = sites.minerShed
	local b = Kit.build("MinerShed", "quarry", s.x, s.z, s.rot)
	local bp = b.bp
	local w, d = 9, 6
	Kit.rect("building", s.x, s.z, w, d, s.rot)
	local lo = select(1, Kit.range(s.x, s.z, w, d, s.rot)) - b.at.y
	bp:box(w + 0.4, 1 - lo, d + 0.4, 0, (lo - 1) / 2 + 0.2, 0, o(Palette.rubble[1], "shell", { q = true }))
	bp:box(w, 6, 0.4, 0, 3.4, d / 2, o(Palette.greyPlanks[1], "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:box(0.4, 6, d, side * w / 2, 3.4, 0, o(Palette.greyPlanks[2], "shell", { q = true }))
	end
	bp:box(w, 2, 0.4, 0, 5.6, -d / 2, o(Palette.greyPlanks[3], "detail"))
	bp:rbox(w + 1.4, 0.4, d + 2, 0, 6.8, 0, -14, 0, 0, o(Palette.shingles[3], "shell"))
	-- tools on the wall and by the door
	for k = -1, 1 do
		bp:rbox(0.2, 3.6, 0.2, k * 1.4, 2.8, d / 2 - 0.3, 0, 0, 10 * k, o(Kit.planks, "fine"))
		bp:box(0.9, 0.3, 0.2, k * 1.4 + 0.3, 4.4, d / 2 - 0.3, o(Kit.iron, "fine"))
	end
	bp:add("cyl", 0.6, 2.4, 2.4, -3, 1.5, -d / 2 - 2, 0, 0, 0, o(Kit.stone, "detail"))
	Parts.barrel(bp, 3.5, 0, -d / 2 - 1.6)
	Parts.crate(bp, 2, 0, -d / 2 - 2.6, 1.8)
	Kit.lantern(bp, -4.8, 0, -d / 2 - 0.8, nil, 5)
	table.insert(out, b)
end

-- Winch over the rim: an A-frame with a rope and a bucket.
local function winch(out: { Build })
	local a = math.rad(-110)
	local x, z = ring(1.1, a)
	local b = Kit.build("QuarryWinch", "quarry", x, z, faceCentre(x, z))
	local bp = b.bp
	for _, side in { -1, 1 } do
		bp:beam(side * 2.4, Kit.gy(b, side * 2.4, 1), 1, side * 0.4, 7, -1, 0.5, o(Kit.timber, "detail"))
	end
	bp:add("cyl", 4, 0.8, 0.8, 0, 7, -1, 0, 0, 0, o(Kit.timber, "shell", { q = false }))
	bp:box(0.12, 6, 0.12, 0, 4, -2.4, o(Kit.rope, "fine"))
	bp:add("cyl", 1.2, 1.4, 1.4, 0, 1, -2.4, 0, 0, 90, o(Kit.planks, "detail"))
	table.insert(out, b)
end

function Quarry.all(out: { Build })
	Kit.circle("quarry", Q.x, Q.z, (Q.rx + Q.rz) / 2)
	Kit.circle("quarryMid", Q.x, Q.z, (Q.rx + Q.rz) / 2 * 0.8)
	Kit.circle("quarryDeep", Q.x, Q.z, (Q.rx + Q.rz) / 2 * 0.53)
	for i, a in (Areas.questAnchors or {}) :: { AreaTypes.QuestAnchor } do
		if string.sub(a.id, 1, 7) == "tunnel_" then
			tunnel(out, i, a.x, a.z)
		end
	end
	-- scaffolds on the outer wall (first terrace) and the inner wall (second terrace)
	scaffold(out, 1, 0.86, math.rad(-80), 5)
	scaffold(out, 2, 0.86, math.rad(60), 5)
	scaffold(out, 3, 0.6, math.rad(200), 5)
	scaffold(out, 4, 0.6, math.rad(-20), 5)
	rails(out, 1, 0.91, math.rad(185), math.rad(260), 6)
	rails(out, 2, 0.67, math.rad(20), math.rad(110), 10)
	local heaps: { { e: number, a: number, copper: boolean } } = {
		{ e = 0.35, a = 30, copper = true },
		{ e = 0.3, a = 170, copper = false },
		{ e = 0.66, a = 140, copper = true },
		{ e = 0.9, a = 290, copper = false },
		{ e = 0.68, a = 250, copper = false },
	}
	for i, p in heaps do
		local x, z = ring(p.e, math.rad(p.a))
		oreHeap(out, i, x, z, p.copper)
	end
	for i, p in { { 0.92, 120 }, { 0.92, 320 }, { 0.68, 300 }, { 0.4, 90 }, { 0.4, 250 } } do
		local x, z = ring(p[1], math.rad(p[2]))
		local b = Kit.build(`KoboldLamp_{i}`, "quarry", x, z, 0)
		Kit.lantern(b.bp, 0, 0, 0, KOBOLD_LIGHT, 3.4)
		table.insert(out, b)
	end
	shed(out)
	winch(out)
end

return Quarry
