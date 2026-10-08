--!strict
-- Troll Swamp (32–40, fast EXP) (S45): a great marsh of mud, pools, rotten logs, willows with beards of moss and
-- dead stumps; dry islands joined by causeways of logs.
--   * the sunken tower (the landmark): a leaning watchtower half under water with a troll's nest on top,
--   * the trolls' village on an island: domed huts of logs, moss and bones, a throne of boulders, the hearth with a
--     great cauldron, a heap of bones, three-toed prints in the mud,
--   * the abandoned village on stilts with its walkways, the jetty with a boat and a lantern (the fishing spot and
--     lure), serpent skins on the reeds and a nest of eggs, witches' charms on the stumps. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Swamp = {}

type Build = Kit.Build

local WATER = -1
local LOG = { c = "#3E3226", m = "Wood" }

local function sunkenTower(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.sunkenTower
	Env.clear(env, s.x, s.z, 14)
	local b = Kit.buildAt("SunkenTower", "landmark", s.x, env.T.height(s.x, s.z) - 2, s.z, s.rot)
	local bp = b.bp
	local H = 30
	bp:push(0, 0, 0, 13, 0, 0)
	bp:add("cyl", H, 13, 13, 0, H / 2, 0, 0, 0, 90, o({ c = "#5E5A52", m = "Cobblestone" }, "shell", { q = true }))
	bp:add(
		"cyl",
		1.4,
		14.4,
		14.4,
		0,
		H,
		0,
		0,
		0,
		90,
		o({ c = "#4E4A44", m = "Cobblestone" }, "detail", { col = false })
	)
	for k = 0, 7 do
		local a = k * math.pi / 4
		if k ~= 3 then
			bp:rbox(
				2.4,
				2.2,
				1.6,
				math.cos(a) * 6.4,
				H + 1.8,
				math.sin(a) * 6.4,
				0,
				-math.deg(a),
				0,
				o({ c = "#5E5A52", m = "Cobblestone" }, "detail", { col = false })
			)
		end
	end
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.4
		bp:box(
			1,
			2.6,
			0.4,
			math.cos(a) * 6.55,
			10 + k * 4.5,
			math.sin(a) * 6.55,
			o(Kit.dark, "detail", { col = false })
		)
	end
	-- the troll's nest of sticks and bones on top
	bp:add(
		"ball",
		11,
		3.4,
		11,
		0,
		H + 2.4,
		0,
		0,
		0,
		0,
		o({ c = "#4A3C2C", m = "Wood" }, "shell", { col = false, q = false })
	)
	for k = 0, 9 do
		local a = k * 0.63
		bp:beam(
			math.cos(a) * 3,
			H + 3.4,
			math.sin(a) * 3,
			math.cos(a) * 6.4,
			H + 2.4 + (k % 3),
			math.sin(a) * 6.4,
			0.4,
			o(LOG, "fine")
		)
	end
	Kit.bones(bp, 1, H + 3.6, -1, 4)
	bp:pop()
	-- moss and rubble at the waterline
	for k = 1, 5 do
		local a = k * 1.25
		Kit.rock(bp, math.cos(a) * 9, 0.6, math.sin(a) * 9, 2.4, Kit.mossyStone, "detail")
	end
	Kit.circle(ctx, "ruins", s.x, s.z, 7)
	Kit.lifeAt(ctx, b, "perch", 2, H + 6, 4)
	table.insert(out, b)
end

local function trollVillage(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "trollVillage", "camp", 28)
	local bp = b.bp
	for i, a in { 0.5, 2.6, 4.4 } do
		local hx, hz = math.cos(a) * 15, math.sin(a) * 15
		Props.domeHut(bp, hx, Kit.gy(ctx, b, hx, hz) - 0.6, hz, math.deg(math.atan2(hx, hz)) + 180, 6 + (i % 2))
		Kit.circle(ctx, "building", b.at.x + hx, b.at.z + hz, 6)
	end
	-- the throne of boulders
	local ty = Kit.gy(ctx, b, -2, 10)
	bp:rbox(5, 3, 4, -2, ty + 1.2, 10, 0, 160, 0, o(Kit.mossyStone, "shell", { q = true }))
	bp:rbox(5, 7, 2, -2.6, ty + 3.4, 12, 8, 160, 0, o(Kit.mossyStone, "shell", { q = true }))
	Kit.skull(bp, -3.6, ty + 7, 12.4, 1.6)
	-- the hearth with the great cauldron, smoke, bones
	local cy = Kit.gy(ctx, b, 4, -2)
	Props.cauldron(bp, 4, cy, -2, 5, "#6A7A3A", Kit.FIRE)
	bp:box(0.6, 0.6, 0.6, 4, cy + 6, -2, o(Kit.dark, "detail", { col = false, t = 1, tag = "smoke" }))
	bp:add("ball", 6, 2.4, 5, -8, Kit.gy(ctx, b, -8, -6), -6, 0, 0, 0, o(Kit.oldBone, "detail", { col = false }))
	Kit.bones(bp, -8, Kit.gy(ctx, b, -8, -9) + 1, -9, 6)
	for k = 0, 5 do
		local a = k * 1.05
		Props.trollPrint(
			bp,
			math.cos(a) * 22,
			Kit.gy(ctx, b, math.cos(a) * 22, math.sin(a) * 22),
			math.sin(a) * 22,
			k * 60
		)
	end
	table.insert(out, b)
end

local function jetty(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.swampJetty
	Env.clear(env, s.x, s.z, 12)
	local b = Kit.buildAt("SwampJetty", "jetty", s.x, WATER, s.z, s.rot)
	local bp = b.bp
	bp:box(4.4, 0.5, 24, 0, 1.4, -10, o(Kit.greyPlanks, "shell", { q = true }))
	for k = 0, 4 do
		for _, side in { -1, 1 } do
			bp:add("cyl", 5, 0.8, 0.8, side * 2.1, -0.6, 1 - k * 5.4, 0, 0, 90, o(LOG, "detail", { col = false }))
		end
	end
	-- the boat tied to the jetty and the lantern on its end
	bp:rbox(3.6, 1.2, 9, 4.6, 0.3, -16, 0, 6, 4, o({ c = "#3E3226", m = "WoodPlanks" }, "shell", { q = false }))
	bp:rbox(3, 0.3, 8, 4.6, 0.85, -16, 0, 6, 4, o(Kit.dark, "detail", { col = false }))
	bp:beam(2.2, 1.8, -16, 4, 0.9, -15, 0.1, o(Kit.rope, "fine"))
	Kit.lantern(bp, -2, 1.6, -21, nil, 5, "detail")
	Kit.rect(ctx, "bridge", s.x, s.z + 10, 4.4, 24, 0)
	table.insert(out, b)
end

local function stiltVillage(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "stiltVillage", "home", 30, nil, 0)
	b.at.y = WATER
	local bp = b.bp
	local huts = { { 0, 0, 0 }, { 15, -12, 25 }, { -12, 14, -15 } }
	for i, h in huts do
		local x, z = h[1], h[2]
		local deck = 3.6
		local tilt = if i == 3 then 9 else 0
		bp:push(x, 0, z, tilt, h[3], 0)
		bp:box(9, 0.6, 9, 0, deck, 0, o(Kit.greyPlanks, "shell", { q = true }))
		bp:box(7, 5, 7, 0, deck + 2.8, 0.6, o({ c = "#4E4436", m = "WoodPlanks" }, "shell", { q = true }))
		for _, side in { -1, 1 } do
			bp:rbox(
				5,
				0.4,
				8.6,
				side * 2.2,
				deck + 6.6,
				0.6,
				0,
				0,
				side * -32,
				o(Kit.straw, if i == 3 then "detail" else "shell", { q = false })
			)
		end
		bp:box(2, 3.4, 0.3, 0, deck + 1.9, -2.95, o(Kit.dark, "detail", { col = false }))
		for _, c in { { -4, -4 }, { 4, -4 }, { 4, 4 }, { -4, 4 } } do
			bp:add("cyl", deck + 4, 0.7, 0.7, c[1], (deck - 4) / 2, c[2], 0, 0, 90, o(LOG, "detail", { col = false }))
		end
		bp:pop()
		Kit.rect(ctx, "building", b.at.x + z, b.at.z - x, 9, 9, 0)
	end
	-- walkways between the huts (one broken)
	for i, w in { { 1, 2 }, { 1, 3 } } do
		local a, c = huts[w[1]], huts[w[2]]
		bp:beam(
			a[1],
			3.9,
			a[2],
			c[1],
			if i == 2 then 2.4 else 3.9,
			c[2],
			1.6,
			o(Kit.greyPlanks, if i == 1 then "shell" else "detail", { col = i == 1 }),
			0.4
		)
	end
	Kit.lifeAt(ctx, b, "fireflies", 0, 2, 0, 24)
	table.insert(out, b)
end

-- Causeways of logs between the dry banks and the islands (a shell deck, logs across it on the client).
local CAUSEWAYS = {
	{ 414, 436, 500, 456 },
	{ 500, 456, 594, 486 },
	{ 666, 344, 676, 420 },
	{ 676, 420, 702, 600 },
	{ 702, 612, 640, 716 },
	{ 530, 668, 640, 716 },
}

local function causeways(env: Env.Env, out: { Build })
	for i, c in CAUSEWAYS do
		local ax, az, bx, bz = c[1], c[2], c[3], c[4]
		local mx, mz = (ax + bx) / 2, (az + bz) / 2
		local b = Kit.buildAt(`Causeway_{i}`, "bridge", mx, WATER, mz, 0)
		local bp = b.bp
		local ya = math.max(env.T.height(ax, az), WATER + 0.4) - WATER
		local yb = math.max(env.T.height(bx, bz), WATER + 0.4) - WATER
		bp:beam(ax - mx, ya, az - mz, bx - mx, yb, bz - mz, 4, o(LOG, "shell", { q = true }), 0.6)
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local dx, dz = (bx - ax) / len, (bz - az) / len
		local yaw = math.deg(math.atan2(-dz, dx))
		for k = 0, math.floor(len / 1.8) do
			local t = k * 1.8 / len
			local lx, lz = ax - mx + (bx - ax) * t, az - mz + (bz - az) * t
			bp:add(
				"cyl",
				5,
				1,
				1,
				lx,
				ya + (yb - ya) * t + 0.35,
				lz,
				0,
				yaw + 90,
				0,
				o(LOG, "detail", { col = false, jitter = 0.1 })
			)
		end
		Kit.line(env.ctx, "bridge", { ax, az, bx, bz }, 4)
		for k = 0, 4 do
			Env.clear(env, ax + (bx - ax) * k / 4, az + (bz - az) * k / 4, 5)
		end
		table.insert(out, b)
	end
end

-- Witches' charms on stumps, serpent skins on the reeds, a nest of eggs.
local CHARMS = { { 396, 520 }, { 560, 760 }, { 748, 470 } }

local function traces(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in CHARMS do
		Env.clear(env, p[1], p[2], 5)
		local b = Kit.build(ctx, `WitchStump_{i}`, "traces", p[1], p[2], i * 70)
		local bp = b.bp
		bp:add("cyl", 4, 2.2, 2.2, 0, 1.5, 0, 0, 0, 90, o(Kit.blackBark, "shell", { q = false }))
		bp:beam(0, 3.2, 0, 1.6, 5, 0.4, 0.3, o(Kit.blackBark, "detail", { col = false }))
		Props.charm(bp, 1.4, 4.8, 0.4, i % 2 == 0)
		Props.charm(bp, -0.6, 3.6, 1, i % 2 == 1)
		Props.doll(bp, 0, 3.5, 0)
		table.insert(out, b)
	end
	local nest = Kit.build(ctx, "SerpentNest", "traces", 470, 402, 0)
	Env.clear(env, 470, 402, 5)
	nest.bp:add("ball", 3.6, 1, 3.6, 0, 0.3, 0, 0, 0, 0, o(Kit.straw, "detail", { col = false }))
	for k = 0, 4 do
		nest.bp:add(
			"ball",
			0.8,
			1,
			0.8,
			math.cos(k * 1.3) * 0.9,
			0.9,
			math.sin(k * 1.3) * 0.9,
			0,
			0,
			0,
			o({ c = "#DCD6C0", m = "SmoothPlastic" }, "fine")
		)
	end
	nest.bp:rbox(2.4, 0.15, 0.8, 2.6, 0.4, 1, 0, 30, 0, o({ c = "#CFC8A8", m = "SmoothPlastic" }, "fine", { t = 0.3 }))
	table.insert(out, nest)
end

function Swamp.all(env: Env.Env, out: { Build })
	sunkenTower(env, out)
	trollVillage(env, out)
	jetty(env, out)
	stiltVillage(env, out)
	causeways(env, out)
	traces(env, out)
	local ctx = env.ctx
	for _, p in { { 540, 530 }, { 640, 640 }, { 470, 610 }, { 600, 420 } } do
		Kit.life(ctx, "wisp", p[1], WATER + 2.5, p[2], 30)
	end
	for _, p in { { 560, 560, 70 }, { 470, 470, 40 }, { 680, 680, 50 } } do
		Kit.life(ctx, "mist", p[1], WATER, p[2], p[3])
	end
	for _, p in { { 400, 380 }, { 760, 560 }, { 520, 760 } } do
		Kit.life(ctx, "fireflies", p[1], env.T.height(p[1], p[2]) + 1.5, p[2], 26)
	end
end

return Swamp
