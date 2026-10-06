--!strict
-- The two camps of the Whispering Meadows (S26).
--   * Bandit camp by the merchant road: palisade of pointed stakes with a gate towards the crossroads, tents, a
--     watchtower, a fire, loot sacks and crates, a weapon rack, wanted posters on a post.
--   * Goblin camp in the north-east: a stake fence with skulls, round huts of hides and branches, the tribal totem
--     in the middle, drums, cauldrons over fires, bone piles, hide racks, green and brown rags on poles.
-- A palisade is a plain wall on the server (one collider per segment, seen from afar) and its stakes are client
-- detail. Pure.

local Areas = require("../../Data/Areas/meadows")
local Kit = require("./Kit")
local Palette = require("../TownGen/Palette")
local Parts = require("../TownGen/Parts")

local o = Kit.o
local sites = assert(Areas.sites, "meadows sites")

local Camps = {}

type Build = Kit.Build
type BP = Kit.BP

-- Ring palisade of `n` segments around the frame origin with a gap of `gap` radians centred on angle `door`.
-- Skull caps on every few stakes when `skulls`.
local function palisade(
	b: Build,
	radius: number,
	n: number,
	door: number,
	gap: number,
	h: number,
	wall: Kit.Swatch,
	skulls: boolean
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
			local y1, y2 = Kit.gy(b, x1, z1), Kit.gy(b, x2, z2)
			local base = math.min(y1, y2) - 1
			local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
			local yaw = math.deg(math.atan2(-(z2 - z1), x2 - x1))
			-- server: the wall core
			bp:add(
				"box",
				len + 0.6,
				h - 1 + (math.max(y1, y2) - base),
				1.4,
				(x1 + x2) / 2,
				base + (h - 1 + (math.max(y1, y2) - base)) / 2,
				(z1 + z2) / 2,
				0,
				yaw,
				0,
				o(wall, "shell", { q = true })
			)
			-- client: pointed stakes along it
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
					o({ c = bp:jitter("#5A4632", 0.1), m = "Wood" }, "detail", { col = false })
				)
				bp:add("ball", 0.9, 1.2, 0.9, sx, sy + sh - 0.3, sz, 0, 0, 0, o({ c = "#6E5A40", m = "Wood" }, "fine"))
				if skulls and k % 5 == 2 then
					bp:add("ball", 1, 1.1, 1.1, sx, sy + sh + 0.4, sz, 0, 0, 0, o(Kit.bone, "fine"))
				end
			end
		end
	end
	-- gate posts
	for _, side in { -1, 1 } do
		local a = door + side * gap / 2
		local x, z = math.cos(a) * radius, math.sin(a) * radius
		local gy = Kit.gy(b, x, z)
		bp:add("cyl", h + 3, 2, 2, x, gy + (h + 3) / 2 - 0.5, z, 0, 0, 90, o(Kit.timber, "shell", { q = true }))
		if skulls then
			bp:add("ball", 1.5, 1.6, 1.6, x, gy + h + 3.2, z, 0, 0, 0, o(Kit.bone, "detail"))
			bp:add(
				"ball",
				0.4,
				0.4,
				0.4,
				x - 0.3,
				gy + h + 3.2,
				z - 0.6,
				0,
				0,
				0,
				o({ c = "#141210", m = "SmoothPlastic" }, "fine")
			)
		end
	end
end

local function tent(bp: BP, x: number, y: number, z: number, yaw: number, cloth: Kit.Swatch)
	bp:push(x, y, z, 0, yaw, 0)
	for _, side in { -1, 1 } do
		bp:rbox(8.5, 0.3, 5.6, 0, 2.4, side * 2.05, side * 52, 0, 0, o(cloth, "shell", { q = true }))
	end
	bp:box(0.35, 5, 0.35, 4, 2.3, 0, o(Kit.timber, "detail"))
	bp:box(0.35, 5, 0.35, -4, 2.3, 0, o(Kit.timber, "detail"))
	bp:box(8.6, 0.3, 0.3, 0, 4.6, 0, o(Kit.timber, "detail"))
	for _, side in { -1, 1 } do
		bp:beam(side * 4, 4.6, 0, side * 6.5, 0, 0, 0.1, o(Kit.rope, "fine"))
		bp:box(0.3, 0.6, 0.3, side * 6.5, 0.2, 0, o(Kit.timber, "fine"))
	end
	bp:pop()
end

local function bandits(out: { Build })
	local s = sites.banditCamp
	local b = Kit.build("BanditCamp", "camp", s.x, s.z, 0)
	local bp = b.bp
	-- the gate faces the crossroads (north-west)
	local door = math.atan2(370 - s.z, 300 - s.x)
	palisade(b, 44, 18, door, 0.55, 8, Palette.timber[2], false)
	Kit.circle("ground:Ground", s.x, s.z, 42)
	Kit.ring("wall", s.x, s.z, 44, 18, 2)
	local function gy(lx: number, lz: number): number
		return Kit.gy(b, lx, lz)
	end
	local cloths = { { c = "#6B4A2B", m = "Fabric" }, { c = "#5A5040", m = "Fabric" }, { c = "#7A5A3A", m = "Fabric" } }
	for i, t in { { 20, 12, 30 }, { 4, 26, 80 }, { -18, 18, 140 }, { 22, -14, -20 } } do
		tent(bp, t[1], gy(t[1], t[2]), t[2], t[3], cloths[(i - 1) % 3 + 1])
		Kit.rect("building", s.x + t[1], s.z + t[2], 8, 8, t[3])
	end
	-- watchtower by the gate
	local tx, tz = math.cos(door + 0.55) * 36, math.sin(door + 0.55) * 36
	local ty = gy(tx, tz)
	for _, c in { { -2.2, -2.2 }, { 2.2, -2.2 }, { 2.2, 2.2 }, { -2.2, 2.2 } } do
		bp:box(0.8, 14, 0.8, tx + c[1], ty + 6.5, tz + c[2], o(Kit.timber, "shell", { q = true }))
	end
	bp:box(6.4, 0.6, 6.4, tx, ty + 12, tz, o(Kit.planks, "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:rbox(7.4, 0.3, 4.2, tx, ty + 16.6, tz + side * 1.7, side * 35, 0, 0, o(Palette.shingles[1], "shell"))
		bp:box(6.4, 1.2, 0.3, tx, ty + 13.2, tz + side * 3.1, o(Kit.planks, "detail"))
		bp:box(0.3, 1.2, 6.4, tx + side * 3.1, ty + 13.2, tz, o(Kit.planks, "detail"))
	end
	for k = 0, 7 do
		bp:box(1.6, 0.25, 0.3, tx, ty + 1 + k * 1.4, tz - 3, o(Kit.planks, "detail"))
	end
	bp:beam(tx - 2.2, ty + 4, tz - 2.2, tx + 2.2, ty + 10, tz - 2.2, 0.4, o(Kit.timber, "detail"))
	bp:beam(tx + 2.2, ty + 4, tz + 2.2, tx - 2.2, ty + 10, tz + 2.2, 0.4, o(Kit.timber, "detail"))
	Kit.lantern(bp, tx + 3, ty + 12.3, tz + 3, nil, 2.2)
	-- the fire in the middle, logs to sit on
	Kit.campfire(bp, 0, gy(0, 0), 0)
	bp:box(0.5, 0.4, 0.5, 0, gy(0, 0) + 0.8, 0, o(Kit.charred, "detail", { tag = "smoke", col = false }))
	for k = 0, 2 do
		local a = k * 2.1 + 0.4
		bp:add(
			"cyl",
			4,
			1.1,
			1.1,
			math.cos(a) * 5,
			gy(math.cos(a) * 5, math.sin(a) * 5) + 0.5,
			math.sin(a) * 5,
			0,
			math.deg(-a) + 90,
			0,
			o(Kit.bark, "detail")
		)
	end
	-- loot: sacks, crates, barrels, a chest
	for i = 0, 5 do
		local lx, lz = -24 + (i % 3) * 2.4, -8 - math.floor(i / 3) * 2.6
		bp:add(
			"ball",
			2,
			2.2,
			1.8,
			lx,
			gy(lx, lz) + 0.9,
			lz,
			0,
			i * 30,
			0,
			o({ c = bp:jitter("#9A845A", 0.1), m = "Fabric" }, "detail")
		)
	end
	for i = 0, 3 do
		Parts.crate(bp, -16 + i * 2.2, gy(-16 + i * 2.2, -20), -20, 2 + (i % 2) * 0.5)
	end
	Parts.barrel(bp, -10, gy(-10, -24), -24)
	Parts.barrel(bp, -8, gy(-8, -25.5), -25.5)
	bp:box(3, 1.8, 2, -28, gy(-28, 4) + 0.9, 4, o(Palette.door[1], "detail"))
	bp:box(3.1, 0.3, 2.1, -28, gy(-28, 4) + 1.9, 4, o(Kit.iron, "fine"))
	-- weapon rack
	local wx, wz = 12, -26
	bp:box(5, 0.3, 0.4, wx, gy(wx, wz) + 3, wz, o(Kit.timber, "detail"))
	for _, k in { -2.3, 2.3 } do
		bp:box(0.4, 3.2, 0.4, wx + k, gy(wx, wz) + 1.5, wz, o(Kit.timber, "detail"))
	end
	for k = -1, 1 do
		bp:rbox(
			0.25,
			4,
			0.12,
			wx + k * 1.2,
			gy(wx, wz) + 2.2,
			wz - 0.3,
			8,
			0,
			0,
			o({ c = "#8A8E94", m = "Metal" }, "fine")
		)
	end
	-- wanted posters on a post outside the gate
	local px, pz = math.cos(door - 0.5) * 52, math.sin(door - 0.5) * 52
	local pgy = gy(px, pz)
	bp:box(0.6, 6, 0.6, px, pgy + 2.8, pz, o(Kit.timber, "shell", { q = true }))
	local face = math.deg(math.atan2(-math.sin(door), math.cos(door)))
	for k = 0, 2 do
		bp:add(
			"box",
			1.4,
			1.8,
			0.08,
			px + math.cos(door) * 0.4,
			pgy + 2.8 + k * 0.9 - (k % 2) * 0.3,
			pz + math.sin(door) * 0.4,
			0,
			face + 90 + (k - 1) * 22,
			(k - 1) * 5,
			o({ c = "#D8CCA8", m = "Fabric" }, "fine")
		)
	end
	-- the bandits' banner on a pole
	bp:box(0.4, 10, 0.4, -6, gy(-6, 10) + 5, 10, o(Kit.timber, "detail"))
	bp:box(3, 2, 0.12, -4.4, gy(-6, 10) + 8.6, 10, o({ c = "#6A2A22", m = "Fabric" }, "detail", { tag = "flag" }))
	table.insert(out, b)
end

-- Round goblin hut: a low wall of branches and hides, a domed hide roof, a door hole.
local function hut(bp: BP, x: number, y: number, z: number, r: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	bp:add("cyl", 4, r * 2, r * 2, 0, 1.6, 0, 0, 0, 90, o({ c = "#5A4632", m = "Wood" }, "shell", { q = true }))
	bp:add(
		"ball",
		r * 2.3,
		r * 1.5,
		r * 2.3,
		0,
		3.6,
		0,
		0,
		0,
		0,
		o({ c = bp:jitter("#6A5A3E", 0.1), m = "Fabric" }, "shell", { col = false })
	)
	for i = 0, 5 do
		local a = i * math.pi / 3
		bp:beam(math.cos(a) * r * 0.9, 3, math.sin(a) * r * 0.9, 0, 7 + r * 0.2, 0, 0.3, o(Kit.timber, "detail"))
	end
	bp:box(2.2, 3, 0.3, 0, 1.5, -r - 0.05, o({ c = "#141210", m = "SmoothPlastic" }, "detail", { col = false }))
	bp:rbox(r * 1.6, 0.2, 2, 0, 4.4, -r * 0.6, -30, 0, 0, o({ c = "#4A5A2A", m = "Fabric" }, "detail", { col = false }))
	bp:pop()
end

local function goblins(out: { Build })
	local s = sites.goblinCamp
	local b = Kit.build("GoblinCamp", "camp", s.x, s.z, 0)
	local bp = b.bp
	local function gy(lx: number, lz: number): number
		return Kit.gy(b, lx, lz)
	end
	-- the gate looks west to the road
	palisade(b, 50, 22, math.pi, 0.5, 7, { c = "#4A3A28", m = "Wood" }, true)
	Kit.circle("ground:Ground", s.x, s.z, 48)
	Kit.ring("wall", s.x, s.z, 50, 22, 2)
	-- huts around the totem
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.3
		local d = 30 + (i % 2) * 6
		local lx, lz = math.cos(a) * d, math.sin(a) * d
		hut(bp, lx, gy(lx, lz), lz, 4 + (i % 3) * 0.6, math.deg(-a) - 90)
		Kit.circle("building", s.x + lx, s.z + lz, 4.5)
	end
	-- the totem: stacked carved blocks with faces, wings and horns, rags, a skull on top
	local ty = gy(0, 0)
	bp:add("cyl", 18, 2.4, 2.4, 0, ty + 8.5, 0, 0, 0, 90, o({ c = "#5A4632", m = "Wood" }, "shell", { q = true }))
	local paints = { "#7A2A22", "#3E6A2A", "#C8A040" }
	for k = 0, 3 do
		local yy = ty + 3 + k * 4
		bp:box(3.2, 2.8, 3.2, 0, yy, 0, o({ c = bp:jitter("#6A5034", 0.08), m = "Wood" }, "shell", { q = true }))
		bp:box(2, 0.5, 0.2, 0, yy + 0.6, -1.65, o({ c = paints[k % 3 + 1], m = "SmoothPlastic" }, "detail"))
		bp:box(0.6, 0.6, 0.2, -0.6, yy + 1, -1.68, o({ c = "#141210", m = "SmoothPlastic" }, "fine"))
		bp:box(0.6, 0.6, 0.2, 0.6, yy + 1, -1.68, o({ c = "#141210", m = "SmoothPlastic" }, "fine"))
		bp:box(1.6, 0.4, 0.2, 0, yy - 0.5, -1.68, o({ c = "#E8E0C8", m = "SmoothPlastic" }, "fine"))
	end
	for _, side in { -1, 1 } do
		bp:rbox(5, 0.4, 2.4, side * 3.6, ty + 14.5, 0, 0, 0, side * -20, o({ c = "#5A4632", m = "Wood" }, "detail"))
		bp:beam(side * 1.2, ty + 17.5, 0, side * 3.2, ty + 20.5, -0.5, 0.5, o(Kit.bone, "detail"))
	end
	bp:add("ball", 2.2, 2.4, 2.4, 0, ty + 18.6, 0, 0, 0, 0, o(Kit.bone, "detail"))
	for k = 0, 2 do
		bp:rbox(
			0.15,
			3,
			1,
			1.5,
			ty + 11 - k * 4,
			-1 + k,
			0,
			k * 60,
			0,
			o({ c = paints[k + 1], m = "Fabric" }, "fine", { tag = "flag" })
		)
	end
	-- drums, cauldrons on fires, bone piles, hide racks, rag banners
	for _, p in { { 9, 8 }, { -9, 10 }, { 12, -10 } } do
		local dx, dz = p[1], p[2]
		bp:add("cyl", 2.2, 3, 3, dx, gy(dx, dz) + 1.1, dz, 0, 0, 90, o({ c = "#6A4A2A", m = "Wood" }, "detail"))
		bp:add("cyl", 0.15, 3.1, 3.1, dx, gy(dx, dz) + 2.25, dz, 0, 0, 90, o(Kit.hide, "fine"))
		bp:beam(dx + 1, gy(dx, dz) + 2.6, dz, dx + 2.4, gy(dx, dz) + 4, dz + 0.4, 0.2, o(Kit.bone, "fine"))
	end
	for _, p in { { -12, -8 }, { 6, -16 } } do
		local cx, cz = p[1], p[2]
		local cy = gy(cx, cz)
		Kit.campfire(bp, cx, cy, cz)
		bp:add(
			"cyl",
			2.4,
			3.4,
			3.4,
			cx,
			cy + 2.1,
			cz,
			0,
			0,
			90,
			o({ c = "#2A2826", m = "CorrodedMetal" }, "shell", { q = true })
		)
		bp:add(
			"cyl",
			0.2,
			3,
			3,
			cx,
			cy + 3.3,
			cz,
			0,
			0,
			90,
			o({ c = "#5A6A2A", m = "Neon" }, "detail", { tag = "smoke", jitter = 0 })
		)
		for _, k in { -2.2, 2.2 } do
			bp:box(0.3, 4.6, 0.3, cx + k, cy + 2.2, cz, o(Kit.timber, "detail"))
		end
		bp:box(4.8, 0.25, 0.25, cx, cy + 4.4, cz, o(Kit.timber, "detail"))
	end
	for i = 1, 4 do
		local a = i * 1.5 + 0.4
		local lx, lz = math.cos(a) * 19, math.sin(a) * 19
		local yb = gy(lx, lz)
		for k = 1, 6 do
			bp:rbox(
				1.5,
				0.3,
				0.3,
				lx + (k % 3) * 0.5,
				yb + 0.2 + math.floor(k / 3) * 0.2,
				lz + (k % 2) * 0.6,
				0,
				k * 47,
				0,
				o(Kit.bone, "fine")
			)
		end
		bp:add("ball", 1.1, 1.2, 1.2, lx, yb + 0.6, lz, 0, 0, 0, o(Kit.bone, "detail"))
	end
	for i, p in { { 20, 14 }, { -22, -4 } } do
		local rx, rz = p[1], p[2]
		local ry = gy(rx, rz)
		for _, k in { -2, 2 } do
			bp:box(0.35, 4, 0.35, rx + k, ry + 1.8, rz, o(Kit.timber, "detail"))
		end
		bp:box(4.6, 0.3, 0.3, rx, ry + 3.7, rz, o(Kit.timber, "detail"))
		bp:rbox(3.6, 2.4, 0.15, rx, ry + 2.4, rz, 0, 0, if i == 1 then 4 else -4, o(Kit.hide, "detail"))
	end
	for i, p in { { 26, -24 }, { -30, 22 }, { 0, -40 } } do
		local fx, fz = p[1], p[2]
		local fy = gy(fx, fz)
		bp:box(0.4, 9, 0.4, fx, fy + 4.4, fz, o(Kit.timber, "detail"))
		bp:box(
			2.6,
			1.8,
			0.1,
			fx + 1.4,
			fy + 7.8,
			fz,
			o({ c = if i == 2 then "#5A4A2A" else "#3E5A2A", m = "Fabric" }, "detail", { tag = "flag" })
		)
	end
	table.insert(out, b)
end

function Camps.all(out: { Build })
	bandits(out)
	goblins(out)
end

return Camps
