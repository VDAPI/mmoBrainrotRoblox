--!strict
-- Goblin Burrow (12-16) dressing (S48): a low winding warren of goblins, kobold miners and spiders.
--   1 the junk gate: a barrier of planks and a cart wheel, a skull on a stake, a warning totem, heaps of junk,
--   2 the junk village: shacks of planks and loot from the Meadows (a scarecrow's head, half barrels, a farmer's
--     cart), mushroom beds under jar lamps (green), a cauldron on a fire, rope ladders and burrows high in the walls,
--   3 the diggings: a loop of rails with carts, ore heaps, props, kobolds' green lanterns, bellows and picks, the dug
--     step by the wall, webs in a caved-in side gallery,
--   4 the chief's shaft ("wow"): in the niche behind the east wall a shaft (a dark disc in a shallow pit with mist and
--     ore glow, a rail of logs), the kobolds' winch tower with a hanging cage of bones and chains, a butcher's block
--     with hooks, a throne of scrap,
--   5 the spider pit: webs between pillars, a kobold's cocoon with a pick sticking out, egg sacs, an overturned cart
--     of ore. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Warren = {}

type Build = Kit.Build
type Env = Kit.Env

local JAR = "#7CFF5A"

local function jarLamp(bp: Kit.BP, x: number, y: number, z: number, light: boolean)
	bp:box(0.3, 4, 0.3, x, y + 2, z, o(Kit.oldWood, "detail", { col = false }))
	bp:add(
		"cyl",
		1,
		0.9,
		0.9,
		x + 0.6,
		y + 3.6,
		z,
		0,
		0,
		90,
		{ c = JAR, m = "Neon", lod = "detail", col = false, tag = "lamp", jitter = 0, fxColor = JAR, t = 0.2 }
	)
	if light then
		bp:light(x + 0.6, y + 3.6, z, JAR, 14, 0.9, "lamp")
	end
end

local function gate(env: Env, out: { Build })
	local r = env.T.rooms[1]
	local b = Kit.build(env, "JunkGate", "camp", r.x + 18, r.z, 90)
	local bp = b.bp
	for _, s in { -1, 1 } do
		for k = 0, 2 do
			bp:rbox(
				1,
				5,
				0.4,
				s * (6 + k * 1.2),
				Kit.gy(env, b, s * 6, 0) + 2.2,
				k * 0.4,
				0,
				0,
				s * 8,
				o(Kit.planks, "shell", { q = false })
			)
		end
	end
	bp:add("cyl", 0.5, 5, 5, -9, Kit.gy(env, b, -9, 2) + 2.4, 2, 0, 20, 0, o(Kit.wood, "detail", { col = false }))
	Kit.totem(bp, 9, Kit.gy(env, b, 9, -2), -2, 6)
	for k = 1, 5 do
		bp:rbox(
			1.6,
			0.6,
			1.2,
			-12 + k * 1.4,
			Kit.gy(env, b, -12 + k, 6) + 0.3,
			6,
			0,
			k * 40,
			10,
			o({ c = "#6A5A48", m = "CorrodedMetal" }, "fine", { col = false })
		)
	end
	table.insert(out, b)
	Kit.clear(env, r.x + 18, r.z, 10)
end

local function village(env: Env, out: { Build })
	local r = env.T.rooms[2]
	for k, a in { 40, 110, 170, 240, 310 } do
		local x, z = Kit.spot(env, r, math.rad(a), 7, 4)
		if x and z then
			local b = Kit.build(env, `JunkShack_{k}`, "camp", x, z, a + 90)
			local bp = b.bp
			local y = Kit.gy(env, b, 0, 0)
			bp:rbox(6, 4.4, 0.4, 0, y + 2.2, 2, 0, 0, 3, o(Kit.planks, "shell", { q = false }))
			for _, s in { -1, 1 } do
				bp:rbox(0.4, 4, 4, s * 3, y + 2, 0, 0, 0, s * 4, o(Kit.planks, "shell", { q = false }))
			end
			bp:rbox(
				7,
				0.3,
				5,
				0,
				y + 4.6,
				0,
				8,
				0,
				0,
				o({ c = "#6A5A48", m = "CorrodedMetal" }, "detail", { col = false })
			)
			jarLamp(bp, -3.8, y, -2, k <= 3)
			-- a mushroom bed under the lamp
			for m = 0, 2 do
				Kit.glowCap(bp, -1 + m * 1.2, y, -3, 0.35, "#C8B87A", false, "fine")
			end
			if k == 1 then
				bp:add(
					"ball",
					1.6,
					1.8,
					1.6,
					2,
					y + 5.4,
					0,
					0,
					0,
					0,
					o({ c = "#B89A55", m = "Grass" }, "detail", { col = false })
				)
			end
			Kit.clear(env, x, z, 5)
			table.insert(out, b)
		end
	end
	-- the cauldron on a fire, rope ladders to burrows high in the walls, hanging scrap
	local cx, cz = Kit.spot(env, r, math.rad(200), 16, 3)
	if cx and cz then
		local c = Kit.build(env, "VillageCauldron", "camp", cx, cz, 0)
		local y = Kit.gy(env, c, 0, 0)
		Kit.campfire(c.bp, 0, y, 0, "detail")
		c.bp:add("ball", 3.4, 2.6, 3.4, 0, y + 2, 0, 0, 0, 0, o(Kit.iron, "shell", { q = false }))
		Kit.lifeAt(env.ctx, c, "steam", 0, 3.4, 0)
		Kit.clear(env, cx, cz, 4)
		table.insert(out, c)
	end
	local l = Kit.build(env, "VillageLadders", "traces", r.x, r.z, 0)
	for k = 0, 2 do
		local a = k * 2.1 + 0.6
		local x, z = Kit.wallSpot(env, r, a, 2)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local y = Kit.gy(env, l, lx, lz)
			l.bp:box(0.15, 12, 0.15, lx - 0.6, y + 6, lz, o(Kit.rope, "fine", { col = false }))
			l.bp:box(0.15, 12, 0.15, lx + 0.6, y + 6, lz, o(Kit.rope, "fine", { col = false }))
			l.bp:add("ball", 3, 2.4, 1, lx, y + 13, lz, 0, 0, 0, o(Kit.dark, "detail", { col = false }))
		end
	end
	table.insert(out, l)
	Kit.life(env.ctx, "bats", r.x, 22, r.z, 20)
end

local function diggings(env: Env, out: { Build })
	local r = env.T.rooms[3]
	local b = Kit.build(env, "Diggings", "camp", r.x, r.z, 0)
	local bp = b.bp
	-- a loop of rails round the core with carts
	local rr = r.core + 4
	for k = 0, 23 do
		local a = k * math.pi / 12
		local lx, lz = math.cos(a) * rr, math.sin(a) * rr
		if env.T.floor(r.x + lx, r.z + lz) then
			local y = Kit.gy(env, b, lx, lz)
			bp:rbox(0.3, 0.2, 6, lx, y + 0.1, lz, 0, math.deg(-a), 0, o(Kit.iron, "detail", { col = false }))
		end
	end
	for k = 0, 1 do
		local a = k * math.pi + 0.4
		local lx, lz = math.cos(a) * rr, math.sin(a) * rr
		if Kit.free(env, r.x + lx, r.z + lz, 2) then
			local y = Kit.gy(env, b, lx, lz)
			bp:rbox(2.6, 1.8, 3.4, lx, y + 1.2, lz, 0, math.deg(-a), 0, o(Kit.iron, "shell", { q = false }))
			bp:rbox(
				2.2,
				0.8,
				3,
				lx,
				y + 2.2,
				lz,
				0,
				math.deg(-a),
				0,
				o({ c = "#8A8C90", m = "Slate" }, "detail", { col = false })
			)
		end
	end
	-- props, ore heaps, green lanterns, bellows and picks
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.3
		local x, z = Kit.spot(env, r, a, 4, 2)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local y = Kit.gy(env, b, lx, lz)
			bp:box(0.8, 10, 0.8, lx, y + 5, lz, o(Kit.wood, "shell", { q = false }))
			if k % 2 == 0 then
				jarLamp(bp, lx + 1, y, lz, true)
			else
				bp:add(
					"ball",
					3.4,
					2,
					3.4,
					lx * 0.92,
					y + 0.6,
					lz * 0.92,
					0,
					0,
					0,
					o({ c = "#7A6A5A", m = "Slate" }, "detail", { col = false })
				)
			end
		end
	end
	table.insert(out, b)
	-- webs in the caved-in side gallery (the dug step)
	local w = Kit.build(env, "DiggingsWebs", "traces", -40, -84, 0)
	Kit.web(w.bp, -4, Kit.gy(env, w, -4, 0) + 1, 0, 4, Kit.gy(env, w, 4, 0) + 9, 0)
	Kit.web(w.bp, 0, Kit.gy(env, w, 0, -3) + 1, -3, 3, Kit.gy(env, w, 3, 3) + 8, 3)
	table.insert(out, w)
end

local function shaft(env: Env, out: { Build })
	local r = env.T.rooms[4]
	local ctx = env.ctx
	-- the shaft in the niche (180, 0): a dark disc in the pit, mist and ore glow, a rail of logs, the winch tower
	local s = Kit.build(env, "ChiefShaft", "landmark", 180, 0, 90)
	local bp = s.bp
	local y = Kit.gy(env, s, 0, 0)
	bp:add("cyl", 0.2, 10, 10, 0, y + 0.1, 0, 0, 0, 90, o(Kit.dark, "detail", { col = false }))
	bp:add("cyl", 0.1, 11, 11, 0, y + 0.2, 0, 0, 0, 90, {
		c = "#B87333",
		m = "Neon",
		lod = "detail",
		col = false,
		t = 0.7,
		tag = "glow",
		jitter = 0,
		fxColor = "#B87333",
	})
	for k = 0, 7 do
		local a = k * math.pi / 4
		local lx, lz = math.cos(a) * 9, math.sin(a) * 9
		bp:rbox(
			0.6,
			0.6,
			7,
			lx,
			Kit.gy(env, s, lx, lz) + 2.6,
			lz,
			0,
			math.deg(-a),
			0,
			o(Kit.oldWood, "detail", { col = false })
		)
	end
	for _, sx in { -1, 1 } do
		bp:box(0.8, 14, 0.8, sx * 5, Kit.gy(env, s, sx * 5, -6) + 7, -6, o(Kit.wood, "shell", { q = false }))
	end
	bp:box(11, 0.8, 0.8, 0, Kit.gy(env, s, 0, -6) + 13.6, -6, o(Kit.wood, "detail", { col = false }))
	bp:add("cyl", 2.4, 2.4, 2.4, 0, Kit.gy(env, s, 0, -6) + 13.6, -6, 0, 90, 0, o(Kit.wood, "detail", { col = false }))
	bp:box(0.12, 6, 0.12, 0, y + 8, 0, o(Kit.iron, "fine", { col = false }))
	bp:box(3, 3.4, 3, 0, y + 4.4, 0, o(Kit.iron, "detail", { col = false, t = 0.5 }))
	Kit.bones(bp, 0, y + 3, 0, 4)
	Kit.lifeAt(ctx, s, "mist", 0, 0.5, 0, 6)
	table.insert(out, s)
	-- the butcher's block with hooks, the throne of scrap (by the walls, out of the core)
	for k, a in { 300, 60 } do
		local x, z = Kit.spot(env, r, math.rad(a), 7, 3)
		if x and z then
			local b = Kit.build(env, if k == 1 then "ButcherBlock" else "ScrapThrone", "landmark", x, z, a + 90)
			local by = Kit.gy(env, b, 0, 0)
			if k == 1 then
				b.bp:add("cyl", 2, 3, 3, 0, by + 1, 0, 0, 0, 90, o(Kit.oldWood, "shell", { q = false }))
				b.bp:box(4, 0.3, 0.3, 0, by + 6, -1, o(Kit.iron, "detail", { col = false }))
				for m = -1, 1 do
					b.bp:box(0.15, 1.4, 0.15, m * 1.4, by + 5.2, -1, o(Kit.iron, "fine", { col = false }))
				end
			else
				b.bp:box(4, 2, 3, 0, by + 1, 0, o({ c = "#6A5A48", m = "CorrodedMetal" }, "shell", { q = false }))
				b.bp:box(4, 5, 0.8, 0, by + 4, 1.2, o({ c = "#6A5A48", m = "CorrodedMetal" }, "shell", { q = false }))
				Kit.skull(b.bp, 0, by + 6.6, 1.2, 1.4, 0)
				Kit.torch(b.bp, 3, by, 0, Kit.FIRE)
			end
			Kit.clear(env, x, z, 4)
			table.insert(out, b)
		end
	end
end

local function spiderpit(env: Env, out: { Build })
	local r = env.T.rooms[5]
	local b = Kit.build(env, "SpiderPit", "traces", r.x, r.z, 0)
	local bp = b.bp
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.2
		local x, z = Kit.wallSpot(env, r, a, 4)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local fy = Kit.gy(env, b, lx, lz)
			local cy = (Kit.ceil(env, x, z) or (fy + 12 + b.at.y)) - b.at.y
			Kit.web(bp, lx, fy + 1, lz, lx * 0.8, cy - 1, lz * 0.8)
			if k == 2 then
				Kit.cocoon(bp, lx * 0.85, fy + 3, lz * 0.85, cy, false)
				bp:rbox(
					0.2,
					3,
					0.2,
					lx * 0.85 + 0.6,
					fy + 4.6,
					lz * 0.85,
					0,
					0,
					30,
					o(Kit.iron, "fine", { col = false })
				)
			end
			if k % 3 == 1 then
				bp:add("ball", 2, 1.7, 2, lx * 0.9, fy + 0.8, lz * 0.9, 0, 0, 0, {
					c = "#D8E8C8",
					m = "Neon",
					lod = "detail",
					col = false,
					q = false,
					tag = "glow",
					jitter = 0,
					fxColor = "#D8E8C8",
					t = 0.4,
				})
			end
		end
	end
	-- the overturned cart of ore
	local cx, cz = Kit.spot(env, r, math.rad(200), 8, 3)
	if cx and cz then
		local lx, lz = cx - r.x, cz - r.z
		local y = Kit.gy(env, b, lx, lz)
		bp:rbox(2.6, 1.8, 3.4, lx, y + 1, lz, 0, 30, 80, o(Kit.iron, "shell", { q = false }))
		bp:add(
			"ball",
			3,
			0.8,
			2,
			lx + 2,
			y + 0.3,
			lz,
			0,
			0,
			0,
			o({ c = "#8A8C90", m = "Slate" }, "detail", { col = false })
		)
		Kit.clear(env, cx, cz, 4)
	end
	table.insert(out, b)
	Kit.life(env.ctx, "spiders", r.x, 12, r.z, 18)
end

function Warren.all(env: Env, out: { Build })
	gate(env, out)
	village(env, out)
	diggings(env, out)
	shaft(env, out)
	spiderpit(env, out)
	Kit.life(env.ctx, "drips", 40, 10, -10, 30)
end

return Warren
