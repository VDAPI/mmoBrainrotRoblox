--!strict
-- Smugglers' Hideout (7-12) dressing (S48): the gang's den under the Merchants' Road.
--   1 the lookout: a barricade of crates with a gap, an alarm bell on a rope, a lantern, the sentry's stool with dice
--     and a mug, the gang's sign (crossed keys) scratched in the rock,
--   2 the landing: the black stream from a crack, a jetty with a moored boat and a lantern, crates and barrels with
--     merchants' marks, a hand crane with a net of goods, coils of rope, a plank over the stream in the tunnel,
--   3 the council hall under the sinkhole ("wow"): moonlight and dust through the hole, roots hanging, crows in the
--     shaft and nests on ledges, a hoist rope with a net of crates, a long table with a map, candles and knives, a
--     barrel bar, the lookout terrace with a rope rail, stakes with chains and a trough for the war boars,
--   4 the chief's room ("wow"): a curtain of sacks, a rug, a bed of furs, a bound chest, heaps of loot (cloth, silver,
--     candlesticks, a chest of gold with a warm glow), a weapon rack, Bloody Ruben's wanted poster pinned with a dagger,
--     an iron perch with a crow skull, a chandelier of candles,
--   5 the war boars' pen: a log fence by the walls, troughs, hay, a spiked harness, gnawed bones, the cage door. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Smugglers = {}

type Build = Kit.Build
type Env = Kit.Env

local WARM = "#FFC46E"
local MOON = "#BFD8FF"

local function lantern(env: Env, out: { Build }, name: string, x: number, z: number, height: number?)
	if Kit.free(env, x, z, 1) then
		local b = Kit.build(env, name, "lamp", x, z, 0)
		Kit.lantern(b.bp, 0, Kit.gy(env, b, 0, 0), 0, WARM, height or 6, "shell")
		Kit.clear(env, x, z, 2)
		table.insert(out, b)
	end
end

local function lookout(env: Env, out: { Build })
	local r = env.T.rooms[1]
	local b = Kit.build(env, "Lookout", "camp", r.x + 16, r.z, 90)
	local bp = b.bp
	for k = -3, 3 do
		if math.abs(k) >= 2 then
			Kit.crate(bp, k * 2.8, Kit.gy(env, b, k * 2.8, 0), 0, 1, k * 13)
		end
	end
	bp:box(0.3, 6, 0.3, 6, Kit.gy(env, b, 6, 3) + 3, 3, o(Kit.wood, "detail", { col = false }))
	bp:add("ball", 1, 1.2, 1, 6, Kit.gy(env, b, 6, 3) + 5.4, 3.6, 0, 0, 0, o(Kit.gold, "fine", { col = false }))
	bp:box(1.2, 1.2, 1.2, -6, Kit.gy(env, b, -6, 5) + 0.6, 5, o(Kit.wood, "fine", { col = false }))
	table.insert(out, b)
	Kit.clear(env, r.x + 16, r.z, 9)
	lantern(env, out, "LookoutLantern", r.x + 10, r.z + 14)
end

local function landing(env: Env, out: { Build })
	local r = env.T.rooms[2]
	local ctx = env.ctx
	-- the jetty along the stream's bend (stream at ~ (-120, -62)) with a moored boat
	local b = Kit.build(env, "Jetty", "landmark", -112, -58, 50)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	bp:box(4, 0.4, 14, 0, y + 0.6, -3, o(Kit.planks, "shell", { q = false }))
	for _, s in { -1, 1 } do
		for k = 0, 2 do
			bp:box(0.5, 3, 0.5, s * 1.8, y - 0.6, -9 + k * 5, o(Kit.oldWood, "detail", { col = false }))
		end
	end
	bp:box(3.4, 1.2, 8, 3.6, y - 0.2, -8, o(Kit.wood, "detail", { col = false }))
	Kit.lantern(bp, -1.6, y + 0.8, 2, WARM, 4, "detail")
	table.insert(out, b)
	-- crates and barrels with merchants' marks, a hand crane with a net, rope
	for k, a in { 300, 330, 20, 60 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 3)
		if x and z then
			local c = Kit.build(env, `Contraband_{k}`, "camp", x, z, a)
			local cy = Kit.gy(env, c, 0, 0)
			Kit.crate(c.bp, 0, cy, 0, 1, 10)
			Kit.barrel(c.bp, 2.8, Kit.gy(env, c, 2.8, 1), 1, 0.9)
			Kit.ropeCoil(c.bp, -2.6, Kit.gy(env, c, -2.6, 0), 0)
			if k == 2 then
				c.bp:box(0.5, 8, 0.5, -1, cy + 4, -3, o(Kit.wood, "shell", { q = false }))
				c.bp:box(5, 0.4, 0.4, 1.2, cy + 7.8, -3, o(Kit.wood, "detail", { col = false }))
				c.bp:add("ball", 2.4, 2, 2.4, 3.4, cy + 5, -3, 0, 0, 0, o(Kit.rope, "detail", { col = false, t = 0.2 }))
			end
			Kit.clear(env, x, z, 4)
			table.insert(out, c)
		end
	end
	-- the plank over the stream in the tunnel to the pen
	local p = Kit.build(env, "StreamPlank", "bridge", -85, -88, 0)
	p.bp:box(3, 0.4, 12, 0, 0.2, 0, o(Kit.planks, "shell", { q = false }))
	table.insert(out, p)
	Kit.life(ctx, "drips", r.x, 16, r.z, 24)
end

local function council(env: Env, out: { Build })
	local r = env.T.rooms[3]
	local ctx = env.ctx
	-- moonlight through the sinkhole (-5, 72)
	local sky = Kit.build(env, "Sinkhole", "landmark", -5, 72, 0)
	local sb = sky.bp
	local y = Kit.gy(env, sky, 0, 0)
	sb:light(0, y + 24, 0, MOON, 40, 1.4, "lamp")
	for k = 0, 7 do
		local a = k * math.pi / 4
		sb:beam(
			math.cos(a) * 9,
			y + 28,
			math.sin(a) * 9,
			math.cos(a) * 8,
			y + 18 + (k % 3) * 2,
			math.sin(a) * 8,
			0.3,
			o({ c = "#3A2E24", m = "Wood" }, "fine", { col = false })
		)
	end
	-- the hoist rope with a net of crates
	sb:box(0.15, 26, 0.15, 3, y + 15, 2, o(Kit.rope, "detail", { col = false }))
	sb:add("ball", 3, 3, 3, 3, y + 4, 2, 0, 0, 0, o(Kit.rope, "detail", { col = false, t = 0.3 }))
	Kit.lifeAt(ctx, sky, "dustBeam", 0, 14, 0, 10)
	Kit.lifeAt(ctx, sky, "perch", 6, 22, -4)
	Kit.lifeAt(ctx, sky, "perch", -7, 20, 3)
	table.insert(out, sky)
	-- the long table with a map, candles and knives, stools, the barrel bar (west side, out of the core)
	local tx, tz = Kit.spot(env, r, math.rad(180), 12, 5)
	if tx and tz then
		local t = Kit.build(env, "CouncilTable", "camp", tx, tz, 90)
		local tb = t.bp
		local ty = Kit.gy(env, t, 0, 0)
		tb:box(10, 0.4, 3.4, 0, ty + 2.6, 0, o(Kit.planks, "shell", { q = false }))
		for _, s in { -1, 1 } do
			tb:box(0.4, 2.4, 3, s * 4.6, ty + 1.2, 0, o(Kit.wood, "detail", { col = false }))
			for k = -1, 1 do
				tb:box(1, 1.4, 1, k * 3, ty + 0.7, s * 2.6, o(Kit.wood, "fine", { col = false }))
			end
		end
		tb:box(4, 0.06, 2.6, 0, ty + 2.84, 0, o({ c = "#D8C9A0", m = "Fabric" }, "fine", { col = false }))
		Kit.candles(tb, -3.6, ty + 2.8, 0.6, 3, WARM)
		Kit.barrel(tb, 7, Kit.gy(env, t, 7, 0), 0, 1)
		Kit.clear(env, tx, tz, 7)
		table.insert(out, t)
	end
	-- stakes with chains, a trough and gnawed buckets (east wall, the boars watch the council)
	local px, pz = Kit.spot(env, r, math.rad(10), 8, 3)
	if px and pz then
		local p = Kit.build(env, "BoarStakes", "traces", px, pz, 270)
		for k = -1, 1 do
			p.bp:box(0.6, 3, 0.6, k * 3, Kit.gy(env, p, k * 3, 0) + 1.4, 0, o(Kit.oldWood, "shell", { q = false }))
			p.bp:beam(
				k * 3,
				Kit.gy(env, p, k * 3, 0) + 2,
				0,
				k * 3 + 1,
				Kit.gy(env, p, k * 3, -2) + 0.2,
				-2,
				0.15,
				o(Kit.iron, "fine", { col = false })
			)
		end
		p.bp:box(5, 1, 1.6, 0, Kit.gy(env, p, 0, 3) + 0.5, 3, o(Kit.wood, "detail", { col = false }))
		table.insert(out, p)
	end
	lantern(env, out, "CouncilLantern", r.x - 30, r.z - 20)
	-- the lookout terrace's rope rail (terrace at (24, -14))
	local rail = Kit.build(env, "LookoutRail", "traces", 24, -14, 0)
	for k = 0, 5 do
		local a = math.rad(200 + k * 25)
		local lx, lz = math.cos(a) * 11, math.sin(a) * 11
		rail.bp:box(0.3, 3, 0.3, lx, Kit.gy(env, rail, lx, lz) + 1.4, lz, o(Kit.wood, "detail", { col = false }))
	end
	table.insert(out, rail)
end

local function chief(env: Env, out: { Build })
	local r = env.T.rooms[4]
	-- loot heaps, the bed, the chest of gold with a warm glow, the weapon rack, the wanted poster, the crow perch
	for k, a in { 20, 80, 150, 230, 300 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 3)
		if x and z then
			local b = Kit.build(env, `ChiefLoot_{k}`, "landmark", x, z, a + 90)
			local bp = b.bp
			local y = Kit.gy(env, b, 0, 0)
			if k == 1 then
				Kit.crate(bp, 0, y, 0, 1.2, 0)
				bp:box(2.8, 0.6, 2.8, 0, y + 2.9, 0, {
					c = "#E8C25A",
					m = "Neon",
					lod = "detail",
					col = false,
					tag = "glow",
					jitter = 0,
					fxColor = "#E8C25A",
				})
				bp:light(0, y + 4, 0, "#FFC46E", 16, 1.1, "lamp")
			elseif k == 2 then
				bp:box(6, 1, 3.6, 0, y + 0.6, 0, o(Kit.wood, "shell", { q = false }))
				bp:box(6, 0.6, 3.4, 0, y + 1.3, 0, o(Kit.fur, "detail", { col = false }))
			elseif k == 3 then
				bp:box(4, 0.4, 0.4, 0, y + 3, 0, o(Kit.wood, "shell", { q = false }))
				for m = -1, 1 do
					bp:rbox(0.2, 3.4, 0.6, m * 1.2, y + 1.8, 0.2, 0, 0, 6, o(Kit.iron, "detail", { col = false }))
				end
				bp:box(1.6, 2, 0.05, 0, y + 5, -0.3, o({ c = "#D8C9A0", m = "Fabric" }, "fine", { col = false }))
			elseif k == 4 then
				for m = 0, 3 do
					bp:rbox(
						2.4,
						0.8,
						1.6,
						(m % 2) * 1.6,
						y + 0.4 + math.floor(m / 2) * 0.8,
						0,
						0,
						m * 30,
						0,
						o({ c = "#6A3A5A", m = "Fabric" }, "detail", { col = false })
					)
				end
				bp:add(
					"cyl",
					1.4,
					0.6,
					0.6,
					2,
					y + 0.7,
					2,
					0,
					0,
					90,
					o({ c = "#C8C8D0", m = "Metal" }, "fine", { col = false })
				)
			else
				bp:box(0.4, 5, 0.4, 0, y + 2.5, 0, o(Kit.iron, "detail", { col = false }))
				bp:box(2, 0.3, 0.3, 0, y + 5, 0, o(Kit.iron, "detail", { col = false }))
				Kit.skull(bp, 0.8, y + 5.1, 0, 0.6, 0)
			end
			Kit.clear(env, x, z, 4)
			table.insert(out, b)
		end
	end
	-- the chandelier of candles over the room and a rug
	local c = Kit.build(env, "ChiefChandelier", "lamp", r.x, r.z, 0)
	local cy = (Kit.ceil(env, r.x, r.z) or 20) - c.at.y
	c.bp:add("cyl", 0.4, 6, 6, 0, cy - 6, 0, 0, 0, 90, o(Kit.iron, "detail", { col = false }))
	c.bp:box(0.15, 6, 0.15, 0, cy - 3, 0, o(Kit.iron, "fine", { col = false }))
	Kit.candles(c.bp, 0, cy - 5.8, 0, 6, WARM)
	c.bp:light(0, cy - 7, 0, WARM, 24, 1, "candle")
	c.bp:box(10, 0.06, 7, 0, 0.04, 0, o({ c = "#6A2A22", m = "Fabric" }, "fine", { col = false }))
	table.insert(out, c)
end

local function pen(env: Env, out: { Build })
	local r = env.T.rooms[5]
	local b = Kit.build(env, "BoarPen", "camp", r.x, r.z, 0)
	local bp = b.bp
	for k = 0, 13 do
		local a = k * (2 * math.pi / 14)
		local x, z = Kit.spot(env, r, a, 6, 1)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			bp:box(0.6, 4, 0.6, lx, Kit.gy(env, b, lx, lz) + 1.8, lz, o(Kit.oldWood, "shell", { q = false }))
			bp:rbox(
				0.4,
				0.4,
				7,
				lx,
				Kit.gy(env, b, lx, lz) + 2.6,
				lz,
				0,
				math.deg(-a),
				0,
				o(Kit.oldWood, "detail", { col = false })
			)
		end
	end
	for k = 0, 2 do
		local a = k * 2.1 + 0.5
		local lx, lz = math.cos(a) * (r.r - 10), math.sin(a) * (r.r - 10)
		bp:add(
			"ball",
			4,
			2,
			4,
			lx,
			Kit.gy(env, b, lx, lz) + 0.4,
			lz,
			0,
			0,
			0,
			o({ c = "#B89A55", m = "Grass" }, "detail", { col = false })
		)
	end
	Kit.bones(bp, 6, 0, -14, 5, function(px: number, pz: number): number
		return Kit.gy(env, b, px, pz)
	end)
	table.insert(out, b)
	lantern(env, out, "PenLantern", r.x + r.r - 14, r.z + 10)
end

function Smugglers.all(env: Env, out: { Build })
	lookout(env, out)
	landing(env, out)
	council(env, out)
	chief(env, out)
	pen(env, out)
end

return Smugglers
