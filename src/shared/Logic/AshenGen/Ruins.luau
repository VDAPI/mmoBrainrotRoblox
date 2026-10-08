--!strict
-- Burnt Ruins (55–61, fast EXP) (S46): a burnt little town on its knoll.
--   * charred walls of roofless houses, fallen beams, cellars full of glowing coal (the imps' nests), sooty windows,
--   * the alley of lone chimneys, the square with a dry fountain full of embers, the town gate by the road from the
--     bridge,
--   * the temple with a fallen dome and the bell tower that still smoulders (the landmark): its windows glow at
--     night, smoke rises from it, the cracked bell lies at its foot,
--   * sand from the dunes drifting into the streets from the east, scorpion burrows and shed carapaces in it. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Ruins = {}

type Build = Kit.Build

local WALL = { c = "#4A423C", m = "Cobblestone" }
local SOOT = { c = "#25211E", m = "Cobblestone" }

local HOUSES = {
	{ -70, 556, 10 },
	{ -84, 640, 95 },
	{ -40, 694, 5 },
	{ 52, 548, 180 },
	{ 60, 692, 270 },
	{ 132, 694, 0 },
	{ -150, 598, 80 },
	{ -132, 690, 20 },
	{ -12, 744, 180 },
	{ 130, 540, 100 },
}

-- A roofless house: four charred walls (shell) with gaps for a door and windows, fallen beams, a cellar of coal.
local function house(env: Env.Env, out: { Build }, i: number, x: number, z: number, rot: number)
	local ctx = env.ctx
	Env.clear(env, x, z, 12)
	local b = Kit.build(ctx, `BurntHouse_{i}`, "ruins", x, z, rot)
	local bp = b.bp
	local w, d = 12 + (i % 3) * 2, 9 + (i % 2) * 2
	local h1 = 7 + (i % 4)
	local low, high = Kit.range(ctx, x, z, w, d, rot)
	local base = low - b.at.y - 0.5
	local tall = h1 + (high - low)
	local function wall(len: number, cx: number, cz: number, yaw: number, gap: boolean, hh: number)
		local sw = if i % 2 == 0 then WALL else SOOT
		if gap then
			local side = (len - 3) / 2
			bp:rbox(
				side,
				hh,
				1,
				cx - (len / 2 - side / 2) * math.cos(math.rad(yaw)),
				base + hh / 2,
				cz + (len / 2 - side / 2) * math.sin(math.rad(yaw)),
				0,
				yaw,
				0,
				o(sw, "shell", { q = true })
			)
			bp:rbox(
				side,
				hh * 0.7,
				1,
				cx + (len / 2 - side / 2) * math.cos(math.rad(yaw)),
				base + hh * 0.35,
				cz - (len / 2 - side / 2) * math.sin(math.rad(yaw)),
				0,
				yaw,
				0,
				o(sw, "shell", { q = true })
			)
		else
			bp:rbox(len, hh, 1, cx, base + hh / 2, cz, 0, yaw, 0, o(sw, "shell", { q = true }))
		end
	end
	wall(w, 0, -d / 2, 0, true, tall)
	wall(w, 0, d / 2, 0, false, tall * 0.8)
	wall(d, -w / 2, 0, 90, false, tall * 0.9)
	wall(d, w / 2, 0, 90, i % 2 == 0, tall * 0.6)
	-- sooty window holes, a fallen beam, rubble
	for _, lx in { -w / 4, w / 4 } do
		bp:box(1.8, 1.8, 1.1, lx, base + tall * 0.62, d / 2, o(Kit.dark, "detail", { col = false }))
		Props.scorch(bp, lx, base + tall * 0.8, d / 2 + 0.56, 2.4, 2)
	end
	bp:beam(-w / 2 + 1, base + tall - 1, -1, w / 2 - 2, base + 0.6, 2, 0.8, o(Kit.charred, "detail", { col = false }))
	bp:beam(-w / 2 + 2, base + 0.4, -2, w / 2 - 1, base + tall * 0.5, 1, 0.7, o(Kit.charred, "detail", { col = false }))
	for k = 1, 4 do
		bp:rbox(
			2,
			1,
			1.6,
			bp.rng:float(-w / 3, w / 3),
			base + 0.8,
			bp.rng:float(-d / 3, d / 3),
			k * 20,
			k * 40,
			0,
			o(WALL, "fine")
		)
	end
	if i % 3 ~= 1 then
		-- the imps' nest: a cellar hole full of glowing coal
		Props.embers(bp, 0, base + 0.4, 0, 1.8, i % 3 == 0)
		Kit.claws(bp, -w / 2 + 0.6, base + 2.4, 0, 1.1)
	end
	if i % 2 == 0 then
		Kit.lifeAt(ctx, b, "smoke", 0, base + 1, 0, 1)
	end
	Kit.rect(ctx, "ruins", x, z, w, d, rot)
	table.insert(out, b)
end

local function chimneyRow(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "chimneyRow", "ruins", 26)
	local bp = b.bp
	-- the alley runs along local Z (the site faces west)
	for k = 0, 4 do
		for _, side in { -1, 1 } do
			if (k + (if side == 1 then 1 else 0)) % 3 ~= 2 then
				local lx, lz = side * 9, -20 + k * 10
				local y = Kit.gy(ctx, b, lx, lz)
				local h = 12 + bp.rng:float(-2, 4)
				bp:box(3, h, 3, lx, y + h / 2 - 0.5, lz, o(SOOT, "shell", { q = false }))
				bp:box(3.6, 0.8, 3.6, lx, y + h, lz, o(WALL, "detail", { col = false }))
				bp:box(2.2, 2, 0.4, lx, y + 1, lz - side * 1.6, o(Kit.dark, "detail", { col = false }))
				Kit.rock(bp, lx + 2, y - 0.4, lz + 2, 1.4, WALL, "detail")
			end
		end
	end
	table.insert(out, b)
end

local function square(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "ruinsSquare", "square", 20)
	local bp = b.bp
	-- the dry fountain full of embers
	for k = 0, 7 do
		local a = k * math.pi / 4
		bp:rbox(
			4.6,
			1.6,
			1.2,
			math.cos(a) * 5.4,
			0.6,
			math.sin(a) * 5.4,
			0,
			math.deg(-a) + 90,
			0,
			o(WALL, "shell", { q = true })
		)
	end
	bp:add("cyl", 4, 2, 2, 0, 2, 0, 0, 0, 90, o(WALL, "detail", { col = false }))
	bp:add("ball", 3.6, 1.2, 3.6, 0, 4.2, 0, 0, 0, 0, o(WALL, "detail", { col = false }))
	Props.embers(bp, 0, 0.3, 0, 3.2, true)
	Kit.lifeAt(ctx, b, "embers", 0, 1, 0, 4)
	table.insert(out, b)
end

local function gate(env: Env.Env, out: { Build })
	local b = Env.atSite(env, "ruinsGate", "gate", 10)
	local bp = b.bp
	for _, side in { -1, 1 } do
		bp:box(3, 12, 3, side * 8.5, 5.5, 0, o(WALL, "shell", { q = true }))
		bp:box(4, 1, 4, side * 8.5, 11.8, 0, o(SOOT, "detail", { col = false }))
		bp:rbox(4, 1.4, 2.4, side * 5.6, 12.6, 0, 0, 0, side * -18, o(WALL, "detail", { col = false }))
		Props.scorch(bp, side * 8.5, 6, -1.55, 2.4, 6)
	end
	bp:rbox(7, 1.4, 2.4, 3, 0.6, -5, 0, 30, 0, o(WALL, "detail", { col = false })) -- the fallen arch
	table.insert(out, b)
end

-- The temple with its fallen dome and the smouldering bell tower.
local function temple(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "burntTemple", "temple", 30)
	local bp = b.bp
	local stone = { c = "#6A5E52", m = "Limestone" }
	local low = Kit.range(ctx, b.at.x, b.at.z, 30, 22, b.at.rot)
	local base = low - b.at.y - 0.5
	-- nave (front faces the square, west)
	for _, side in { -1, 1 } do
		bp:box(1.6, 14, 30, side * 11, base + 7, 0, o(stone, "shell", { q = true }))
		for k = -1, 1 do
			bp:box(1.7, 4.4, 2.6, side * 11, base + 9, k * 9, o(Kit.dark, "detail", { col = false }))
		end
	end
	bp:box(22, 14, 1.6, 0, base + 7, 15, o(stone, "shell", { q = true }))
	bp:box(7, 14, 1.6, -7.5, base + 7, -15, o(stone, "shell", { q = true }))
	bp:box(7, 14, 1.6, 7.5, base + 7, -15, o(stone, "shell", { q = true }))
	bp:box(8, 4, 1.6, 0, base + 12, -15, o(stone, "detail", { col = false }))
	-- the fallen dome: a broken half shell on the floor, a ring of the drum still standing
	for k = 0, 9 do
		local a = k * math.pi / 5
		if k ~= 3 and k ~= 4 then
			bp:rbox(
				4.6,
				3,
				1.2,
				math.cos(a) * 8.4,
				base + 15.2,
				4 + math.sin(a) * 8.4,
				0,
				math.deg(-a) + 90,
				0,
				o(stone, "detail", { col = false })
			)
		end
	end
	bp:add("ball", 14, 6, 12, 2, base + 2, 2, 20, 30, 10, o(SOOT, "detail", { col = false }))
	for k = 1, 5 do
		bp:rbox(
			3,
			2,
			2.6,
			bp.rng:float(-8, 8),
			base + 1,
			bp.rng:float(-10, 10),
			k * 15,
			k * 50,
			k * 9,
			o(stone, "detail", { col = false })
		)
	end
	Props.embers(bp, -3, base + 0.6, 6, 2.4, true)
	Kit.lifeAt(ctx, b, "smoke", 0, base + 3, 4, 3)
	Kit.rect(ctx, "building", b.at.x, b.at.z, 22, 30, b.at.rot)
	table.insert(out, b)

	-- the bell tower: windows glowing like embers, smoke from its top, the cracked bell at its foot
	local t = Env.atSite(env, "belltower", "landmark", 10)
	local tp = t.bp
	local ty = Kit.range(ctx, t.at.x, t.at.z, 9, 9, t.at.rot) - t.at.y - 0.5
	tp:box(8, 30, 8, 0, ty + 15, 0, o(stone, "shell", { q = true }))
	tp:box(9, 1.2, 9, 0, ty + 30.6, 0, o(SOOT, "detail", { col = false }))
	for _, side in { -1, 1 } do
		tp:box(2.4, 5, 8.2, 0, ty + 25, 0, o(Kit.dark, "detail", { col = false }))
		tp:box(8.2, 5, 2.4, 0, ty + 25, 0, o(Kit.dark, "detail", { col = false }))
		tp:box(1.8, 3.4, 0.3, 0, ty + 25, side * 4.15, {
			c = Props.EMBER,
			m = "Neon",
			lod = "shell",
			col = false,
			q = false,
			tag = "glow",
			jitter = 0,
		})
		tp:box(0.3, 3.4, 1.8, side * 4.15, ty + 25, 0, {
			c = Props.EMBER,
			m = "Neon",
			lod = "detail",
			col = false,
			q = false,
			tag = "glow",
			jitter = 0,
		})
	end
	tp:light(0, ty + 25, 0, Props.EMBER, 30, 1.4, "glow")
	tp:box(2, 1, 2, 0, ty + 31.6, 0, o(SOOT, "shell", { q = false, tag = "smoke" }))
	-- the cracked bell lying at the tower's foot
	tp:add(
		"cyl",
		5,
		4.6,
		4.6,
		-7,
		Kit.gy(ctx, t, -7, -4) + 1.6,
		-4,
		0,
		30,
		70,
		o({ c = "#5A4A32", m = "Metal" }, "detail", { col = false })
	)
	tp:box(0.2, 3, 0.6, -7.4, Kit.gy(ctx, t, -7, -4) + 2.4, -6.3, o(Kit.dark, "fine"))
	Kit.lifeAt(ctx, t, "smokeColumn", 0, ty + 32, 0, 3)
	Kit.lifeAt(ctx, t, "embers", 0, ty + 26, 0, 3)
	Kit.rect(ctx, "building", t.at.x, t.at.z, 8, 8, 0)
	table.insert(out, t)
end

local function nests(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "scorpionNests", "traces", 16)
	local bp = b.bp
	for k, p in { { -6, -4 }, { 7, 2 }, { -2, 9 }, { 10, -9 } } do
		Props.burrow(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2])
		if k % 2 == 0 then
			Props.husk(bp, p[1] - 3, Kit.gy(ctx, b, p[1] - 3, p[2] + 3), p[2] + 3, k * 70)
		end
	end
	table.insert(out, b)
end

function Ruins.all(env: Env.Env, out: { Build })
	gate(env, out)
	square(env, out)
	chimneyRow(env, out)
	temple(env, out)
	for i, h in HOUSES do
		house(env, out, i, h[1], h[2], h[3])
	end
	nests(env, out)
end

return Ruins
