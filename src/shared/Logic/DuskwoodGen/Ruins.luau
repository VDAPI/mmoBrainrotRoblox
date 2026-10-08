--!strict
-- Haunted Ruins (24–31, more gold) (S45): an overgrown noble manor on its rise.
--   * the manor: broken walls, a collapsed tower, stairs to nowhere, ivy and cobwebs; its windows glow with a cold
--     light at night (lamp tag, cold colour),
--   * the courtyard: a cracked fountain of black water, headless statues, a weeping angel, the bent gate,
--   * the family cemetery behind a bent iron fence: gravestones, dug-up graves with heaps of earth, gnawed coffins
--     with their lids pushed aside, bones dragged along the path (ghouls); wisps between the graves (wraiths),
--   * the chapel with a broken stained-glass window and claw marks on its door, a candle on the altar,
--   * the lure: the open family crypt with its grate swung aside and coins glinting inside. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Ruins = {}

type Build = Kit.Build
type BP = Kit.BP

local STONE = { c = "#6E6A70", m = "Slate" }
local STONE_DARK = { c = "#57545A", m = "Slate" }
local IVY = { c = "#2E4426", m = "LeafyGrass" }
local SLATE_ROOF = { c = "#3A3C40", m = "Slate" }

-- Wall run from (x1, z1) to (x2, z2) of the frame, `h` tall, standing on the ground, with a ragged top (detail).
local function wall(ctx: Kit.Ctx, b: Build, x1: number, z1: number, x2: number, z2: number, h: number, sw: Kit.Swatch)
	local bp = b.bp
	local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
	local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	local yaw = math.deg(math.atan2(-(z2 - z1), x2 - x1))
	local gy = math.min(Kit.gy(ctx, b, x1, z1), Kit.gy(ctx, b, x2, z2), Kit.gy(ctx, b, mx, mz)) - 0.6
	bp:add("box", len, h, 1.8, mx, gy + h / 2, mz, 0, yaw, 0, o(sw, "shell", { q = true }))
	-- ragged top stones and ivy
	local n = math.floor(len / 3)
	for k = 0, n - 1 do
		local t = (k + 0.5) / n
		local px, pz = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
		if bp.rng:chance(0.55) then
			local sh = bp.rng:float(0.6, 2.2)
			bp:add("box", 2.4, sh, 1.9, px, gy + h + sh / 2, pz, 0, yaw, 0, o(sw, "detail", { col = false }))
		end
		if bp.rng:chance(0.35) then
			bp:add(
				"box",
				2.6,
				bp.rng:float(2, h * 0.8),
				2.1,
				px,
				gy + h * 0.45,
				pz,
				0,
				yaw,
				0,
				o(IVY, "fine", { col = false })
			)
		end
	end
	return gy
end

-- Window on a wall plane facing the frame's yaw: dark glass that glows cold at night.
local function coldWindow(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:add("box", 2, 3, 2, x, y, z, 0, yaw, 0, {
		c = "#1A2028",
		m = "Glass",
		lod = "detail",
		col = false,
		tag = "lamp",
		jitter = 0,
		fxColor = "#9FC8FF",
	})
end

local function manor(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "manor", "manor", 36)
	local bp = b.bp
	-- the courtyard in front stays open (no trees between the gate and the hall)
	local cx, _, cz = Kit.worldOf(b, 0, 0, -30)
	Env.clear(env, cx, cz, 26)
	-- the hall (local -Z is the front, towards the courtyard)
	wall(ctx, b, -20, -9, -11, -9, 15, STONE)
	wall(ctx, b, -11, -9, -3, -9, 9, STONE_DARK)
	wall(ctx, b, 3, -9, 12, -9, 14, STONE)
	wall(ctx, b, 12, -9, 20, -9, 4, STONE_DARK)
	wall(ctx, b, -20, 17, -4, 17, 16, STONE)
	wall(ctx, b, -4, 17, 8, 17, 12, STONE_DARK)
	wall(ctx, b, 8, 17, 20, 17, 16, STONE)
	wall(ctx, b, -20, -9, -20, 4, 15, STONE)
	wall(ctx, b, -20, 4, -20, 17, 6, STONE_DARK)
	wall(ctx, b, 20, -9, 20, 17, 16, STONE)
	for _, x in { -16, -8, 7, 15 } do
		coldWindow(bp, x, Kit.gy(ctx, b, x, -9) + 8, -9, 0)
		coldWindow(bp, x, Kit.gy(ctx, b, x, 17) + 9, 17, 0)
	end
	coldWindow(bp, 20, Kit.gy(ctx, b, 20, 4) + 7, 4, 90)
	-- the collapsed tower at the back corner and its fallen top
	local ty = Kit.gy(ctx, b, 20, 17) - 1
	bp:add("cyl", 30, 12, 12, 21, ty + 15, 18, 0, 0, 90, o(STONE, "shell", { q = true }))
	bp:add("cyl", 4, 12.6, 12.6, 21, ty + 28, 18, 0, 0, 90, o(STONE_DARK, "detail", { col = false }))
	bp:rbox(7, 6, 7, 31, Kit.gy(ctx, b, 31, 8) + 2.2, 8, 20, 30, 70, o(STONE_DARK, "shell", { q = true }))
	for k = 1, 6 do
		Kit.rock(bp, 26 + k * 1.6, Kit.gy(ctx, b, 26 + k * 1.6, 12 - k) - 0.3, 12 - k, 1.8, STONE, "detail")
	end
	-- stairs to nowhere inside the hall
	local sy = Kit.gy(ctx, b, -12, 6)
	bp:add("wedge", 5, 9, 14, -12, sy + 4.5, 6, 0, 180, 0, o(STONE, "shell", { q = true }))
	for k = 0, 8 do
		bp:box(5.2, 0.4, 1.4, -12, sy + 1 + k, 12.4 - k * 1.55, o(STONE_DARK, "detail", { col = false }))
	end
	-- cobwebs in the corners, rubble on the floor
	for _, c in { { -19, -8 }, { 19, 16 }, { -19, 16 } } do
		bp:rbox(4, 4, 0.05, c[1], Kit.gy(ctx, b, c[1], c[2]) + 8, c[2], 0, 45, 0, {
			c = "#D8D8D8",
			m = "SmoothPlastic",
			lod = "fine",
			col = false,
			t = 0.65,
			jitter = 0,
		})
	end
	for _ = 1, 7 do
		local lx, lz = bp.rng:float(-17, 17), bp.rng:float(-6, 14)
		Kit.rock(bp, lx, Kit.gy(ctx, b, lx, lz) - 0.3, lz, bp.rng:float(1, 2.2), STONE, "detail")
	end
	-- the courtyard: cracked fountain of black water, headless statues, the weeping angel, the gate
	local fy = Kit.gy(ctx, b, 0, -26)
	bp:add("cyl", 1.8, 12, 12, 0, fy + 0.6, -26, 0, 0, 90, o(STONE, "shell", { q = true }))
	bp:add(
		"cyl",
		0.2,
		10.4,
		10.4,
		0,
		fy + 1.4,
		-26,
		0,
		0,
		90,
		o({ c = "#0E1216", m = "Glass" }, "detail", { col = false, t = 0.1 })
	)
	bp:add("cyl", 5, 1.6, 1.6, 0, fy + 3, -26, 0, 0, 90, o(STONE_DARK, "detail", { col = false }))
	bp:rbox(4.4, 0.8, 4.4, 1.2, fy + 1.8, -24.4, 0, 20, 24, o(STONE, "detail", { col = false }))
	for _, side in { -1, 1 } do
		local sx, sz = side * 11, -34
		local py = Kit.gy(ctx, b, sx, sz)
		bp:box(3, 2.4, 3, sx, py + 1.2, sz, o(STONE_DARK, "shell", { q = true }))
		bp:box(2.2, 4.4, 1.4, sx, py + 4.6, sz, o(STONE, "shell", { q = false }))
		bp:box(3.4, 0.8, 1.2, sx, py + 6.4, sz, o(STONE, "detail", { col = false }))
		bp:rbox(
			1.2,
			1,
			1.2,
			sx + side * 1.8,
			Kit.gy(ctx, b, sx + side * 1.8, sz - 2) + 0.4,
			sz - 2,
			30,
			10,
			0,
			o(STONE, "fine")
		)
	end
	local ay = Kit.gy(ctx, b, -15, -18)
	bp:box(2.6, 2, 2.6, -15, ay + 1, -18, o(STONE_DARK, "shell", { q = true }))
	bp:rbox(1.8, 4.6, 1.2, -15, ay + 4.3, -18, 12, 0, 0, o({ c = "#8A8680", m = "Marble" }, "detail", { col = false }))
	bp:add(
		"ball",
		1.1,
		1.2,
		1.1,
		-15,
		ay + 6.6,
		-18.8,
		0,
		0,
		0,
		o({ c = "#8A8680", m = "Marble" }, "detail", { col = false })
	)
	for _, side in { -1, 1 } do
		bp:rbox(
			0.3,
			4,
			2.4,
			-15 + side * 1.2,
			ay + 5,
			-17.4,
			0,
			side * 30,
			side * 12,
			o({ c = "#8A8680", m = "Marble" }, "detail", { col = false })
		)
	end
	for _, side in { -1, 1 } do
		local gx = side * 8
		local gy = Kit.gy(ctx, b, gx, -45)
		bp:box(2.2, 8, 2.2, gx, gy + 3.6, -45, o(STONE, "shell", { q = true }))
		bp:add("ball", 1.8, 1.8, 1.8, gx, gy + 8.2, -45, 0, 0, 0, o(STONE_DARK, "detail", { col = false }))
		-- the bent iron gate: one wing hanging, one lying
		for k = 0, 4 do
			bp:rbox(
				0.2,
				6,
				0.2,
				gx - side * (1.6 + k * 1.1),
				gy + 3.2,
				-45 - (if side > 0 then k * 0.5 else 0),
				if side > 0 then 0 else 70,
				side * 20,
				0,
				o(Kit.iron, "detail", { col = false })
			)
		end
	end
	Kit.rect(ctx, "ruins", b.at.x, b.at.z - 4, 40, 26, b.at.rot)
	Kit.circle(ctx, "plaza", b.at.x, b.at.z + 30, 14)
	Kit.lifeAt(ctx, b, "wisp", 0, 4, 6, 12)
	Kit.lifeAt(ctx, b, "wisp", -4, 2, -26, 8)
	table.insert(out, b)
end

local function cemetery(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "cemetery", "cemetery", 26)
	local bp = b.bp
	-- the bent iron fence (gap at the front)
	local W, D = 23, 17
	local corners = { { -W, -D }, { W, -D }, { W, D }, { -W, D } }
	for i = 1, 4 do
		local a, c = corners[i], corners[i % 4 + 1]
		local len = math.sqrt((c[1] - a[1]) ^ 2 + (c[2] - a[2]) ^ 2)
		local n = math.floor(len / 2.4)
		for k = 0, n do
			local t = k / n
			local fx, fz = a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t
			if not (i == 1 and math.abs(fx) < 4) then
				local lean = if (k + i) % 7 == 0 then 24 else bp.rng:float(-4, 4)
				bp:rbox(
					0.22,
					4.2,
					0.22,
					fx,
					Kit.gy(ctx, b, fx, fz) + 1.9,
					fz,
					lean,
					0,
					0,
					o(Kit.iron, "detail", { col = false })
				)
			end
		end
		if i ~= 1 then
			local yaw = math.deg(math.atan2(-(c[2] - a[2]), c[1] - a[1]))
			local my = Kit.gy(ctx, b, (a[1] + c[1]) / 2, (a[2] + c[2]) / 2)
			bp:add(
				"box",
				len,
				0.2,
				0.2,
				(a[1] + c[1]) / 2,
				my + 3.4,
				(a[2] + c[2]) / 2,
				0,
				yaw,
				0,
				o(Kit.iron, "detail", { col = false })
			)
		end
	end
	-- graves: rows of stones, some dug up
	local dug = { [3] = true, [7] = true, [12] = true, [16] = true, [18] = true }
	local n = 0
	for row = 0, 3 do
		for col = 0, 4 do
			n += 1
			local gx, gz = -16 + col * 8, -10 + row * 7
			local gy = Kit.gy(ctx, b, gx, gz)
			Props.gravestone(bp, gx, gy, gz + 1.6, bp.rng:float(-8, 8), bp.rng:float(-10, 10), n % 4 == 1)
			if dug[n] then
				bp:add(
					"ball",
					4,
					1.6,
					3,
					gx + 3,
					gy + 0.2,
					gz - 1,
					0,
					0,
					0,
					o({ c = "#3A3026", m = "Ground" }, "detail", { col = false })
				)
				bp:box(2.2, 0.2, 4, gx, gy + 0.05, gz - 1, o(Kit.dark, "detail", { col = false }))
				bp:rbox(
					2,
					0.4,
					4.2,
					gx - 0.4,
					gy + 0.6,
					gz - 1,
					0,
					8,
					0,
					o({ c = "#3E3024", m = "WoodPlanks" }, "detail", { col = false })
				)
				bp:rbox(
					2,
					0.25,
					4.2,
					gx - 2.6,
					gy + 0.4,
					gz - 1.6,
					0,
					30,
					18,
					o({ c = "#4A3A2C", m = "WoodPlanks" }, "fine")
				)
				Kit.bones(bp, gx + 1, gy, gz - 3.4, 3)
			end
		end
	end
	-- bones dragged along the path out of the gate
	for k = 1, 6 do
		local lz = -D - k * 3
		local lx = (k % 2) * 1.2
		bp:rbox(1.6, 0.2, 0.25, lx, Kit.gy(ctx, b, lx, lz) + 0.12, lz, 0, k * 50, 0, o(Kit.oldBone, "fine"))
	end
	Kit.rect(ctx, "cemetery", b.at.x, b.at.z, W * 2, D * 2, b.at.rot)
	for _, p in { { -10, -4 }, { 8, 2 }, { -2, 9 }, { 14, -8 } } do
		Kit.lifeAt(ctx, b, "wisp", p[1], 2.5, p[2], 8)
	end
	table.insert(out, b)
end

local function chapel(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "chapel", "chapel", 16)
	local bp = b.bp
	local lo = math.min(Kit.gy(ctx, b, -6, -9), Kit.gy(ctx, b, 6, 9), Kit.gy(ctx, b, 6, -9), Kit.gy(ctx, b, -6, 9))
	local base = lo - 0.6
	local h = 9
	for _, w in { { -6, -4, 2.4 }, { 4, 6, 2.4 } } do
		bp:box(w[2] - w[1], h, 1.4, (w[1] + w[2]) / 2, base + h / 2, -9, o(STONE, "shell", { q = true }))
	end
	bp:box(4, 2.6, 1.4, 0, base + h - 1.3, -9, o(STONE, "detail", { col = false }))
	bp:box(12, h, 1.4, 0, base + h / 2, 9, o(STONE, "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:box(1.4, h, 18, side * 6, base + h / 2, 0, o(STONE, "shell", { q = true }))
		bp:rbox(9.4, 0.8, 20, side * 3.3, base + h + 3, 0, 0, 0, side * -42, o(SLATE_ROOF, "shell", { q = false }))
	end
	-- front gable and the bell turret
	bp:add("wedge", 12, 6, 1.4, 0, base + h + 3, -9, 0, 0, 0, o(STONE, "detail", { col = false }))
	bp:box(2.4, 4, 2.4, 0, base + h + 7.4, -8, o(STONE_DARK, "detail", { col = false }))
	-- the door with claw marks, the broken stained-glass window, the altar candle
	bp:box(3.6, 6, 0.4, 0, base + 3, -9.6, o({ c = "#3A2A1E", m = "WoodPlanks" }, "detail", { col = false }))
	Kit.claws(bp, -0.8, base + 3.6, -9.85, 1.1)
	Kit.claws(bp, 0.9, base + 2.8, -9.85, 0.9)
	local glass = { "#7A2A3A", "#2A4A7A", "#B08A2A", "#2A6A4A" }
	for k = 0, 7 do
		if k ~= 2 and k ~= 5 then
			bp:box(0.9, 0.9, 0.2, -1.4 + (k % 4) * 0.95, base + 6 + math.floor(k / 4) * 0.95, 9.75, {
				c = glass[(k % 4) + 1],
				m = "Neon",
				lod = "fine",
				col = false,
				jitter = 0.05,
			})
		end
	end
	bp:box(4.4, 2.6, 0.4, 0, base + 6.4, 9.72, o(Kit.dark, "detail", { col = false }))
	bp:box(4, 2.2, 2, 0, base + 1.1, 6.6, o(STONE_DARK, "detail", { col = false }))
	Kit.candle(bp, -0.8, base + 2.2, 6.6, 0.9)
	Kit.candle(bp, 0.9, base + 2.2, 6.6, 0.6)
	Kit.rect(ctx, "building", b.at.x, b.at.z, 12, 18, b.at.rot)
	table.insert(out, b)
end

local function familyCrypt(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "familyCrypt", "crypt", 12)
	local bp = b.bp
	local lo = math.min(Kit.gy(ctx, b, -5, -6), Kit.gy(ctx, b, 5, 6), Kit.gy(ctx, b, 5, -6), Kit.gy(ctx, b, -5, 6))
	local base = lo - 0.5
	bp:box(10, 7, 1.2, 0, base + 3.5, 6, o(STONE_DARK, "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:box(1.2, 7, 12, side * 5, base + 3.5, 0, o(STONE_DARK, "shell", { q = true }))
		bp:box(1.4, 6.4, 1.4, side * 3.2, base + 3.2, -6, o(STONE, "detail", { col = false }))
	end
	bp:box(11.6, 1.4, 13.6, 0, base + 7.6, 0, o(STONE, "shell", { q = false }))
	bp:add("wedge", 11.6, 2.4, 2, 0, base + 9.4, -5.6, 0, 0, 0, o(STONE, "detail", { col = false }))
	bp:box(8.6, 6.8, 10, 0, base + 3.4, 0.4, o(Kit.dark, "detail", { col = false, t = 0.15 }))
	-- the grate swung aside, the sarcophagus and the coins inside
	for k = 0, 4 do
		bp:rbox(
			0.2,
			5.6,
			0.2,
			-2.8 - math.cos(math.rad(60)) * k * 0.9,
			base + 2.8,
			-6 - math.sin(math.rad(60)) * k * 0.9,
			0,
			0,
			0,
			o(Kit.iron, "detail", { col = false })
		)
	end
	bp:box(3, 2, 6, 0, base + 1, 2, o(STONE, "detail", { col = false }))
	bp:rbox(3.2, 0.5, 6.2, 1.4, base + 1.9, 2.4, 0, 14, 10, o(STONE_DARK, "fine"))
	Props.coins(bp, -1.6, base + 0.1, -1, 10)
	Props.coins(bp, 0.4, base + 2.1, 2, 6)
	Props.sack(bp, -2.4, base, 3.4, true)
	Kit.rect(ctx, "building", b.at.x, b.at.z, 10, 12, b.at.rot)
	table.insert(out, b)
end

function Ruins.all(env: Env.Env, out: { Build })
	manor(env, out)
	cemetery(env, out)
	chapel(env, out)
	familyCrypt(env, out)
end

return Ruins
