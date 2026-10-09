--!strict
-- Mosshollow Cave (16-20) dressing (S48): a green grotto under Bear Ravine; water seeps in from the Meadows'
-- waterfall, the moss glows, Grimrok's goblins camp and the spiders hunt them.
--   1 entrance: a curtain of water behind the exit (waterfall + foam), green daylight through it, a goblin warning
--     totem with a skull and a broken spear, puddles, the first glowing moss leading east,
--   2 the Great Grotto ("wow"): glow-worms on the vault (life), the underground lake in the bay with a waterfall from
--     a crack, a goblin camp gnawed by spiders (torn webbed tents, a dying fire, dropped shields), giant glowing
--     mushrooms on the shore, stalagmites by the north wall,
--   3 the bear den: mossy lairs in the wall's bulges, claw marks, deer bones and fish bones, a log washed down from the
--     ravine, honeycombs, fur, a stake of bone amulets and a bowl of food (the archshaman tames the bears),
--   4 the warriors' barracks: spear racks, red-painted shields, sleeping hides, training dummies made of scarecrows,
--     a drum, a heap of bandit loot, torches,
--   5 the Queen's nest ("wow"): a huge funnel web behind the room lit from behind by glowing moss, a bone altar of the
--     shamans under it (spiral of bones, 6 totems with bowls of green fire, gifts of goblin trinkets), threads,
--   6 the spider hall: webs between stalactites and pillars, cocoons with goblin feet on threads, pale glowing egg
--     sacs, bones and spears, a goblin barricade of shields and burnt webs at the entry,
--   7 the shamans' shrine: a stone circle with green fire, carved totems with faces, glowing hand prints, a mushroom
--     ring, heaps of skulls, bundles of herbs, the altar terrace by the south wall,
--   8 the antechamber of banners ("wow"): two rows of tall red banners with the fang sign, two great war drums,
--     spiked barricades forming an avenue to the gate, a wall of trophies, fire baskets, heaps of skulls, a goblin
--     maw carved round the dungeon gate. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Moss = {}

type Build = Kit.Build
type Env = Kit.Env

local function room(env: Env, i: number)
	return env.T.rooms[i]
end

-- Glowing moss patches and mushrooms round a room's walls (the light of the cave).
local function glowRing(env: Env, out: { Build }, i: number, n: number, lights: number, color: string?)
	local r = room(env, i)
	local b = Kit.build(env, `MossGlow_{i}`, "glow", r.x, r.z, 0)
	local made = 0
	for k = 1, n do
		local a = k * (2 * math.pi / n) + i
		local x, z = Kit.wallSpot(env, r, a, 4)
		if x and z and Kit.free(env, x, z, 1, false) then
			local lx, lz = x - r.x, z - r.z
			local y = Kit.gy(env, b, lx, lz)
			made += 1
			Kit.glowCap(b.bp, lx, y, lz, 0.6 + (k % 3) * 0.25, color, made <= lights)
			b.bp:add(
				"cyl",
				0.12,
				4,
				4,
				lx + 1.6,
				y + 0.06,
				lz,
				0,
				0,
				90,
				o({ c = color or Kit.MOSS, m = "Neon" }, "fine", { col = false, t = 0.55 })
			)
		end
	end
	table.insert(out, b)
end

local function entrance(env: Env, out: { Build })
	local r = room(env, 1)
	-- the curtain of water behind the exit (x -278): sheets of falling water and foam, green daylight through it
	local b = Kit.build(env, "MossEntrance", "landmark", -290, 0, 90)
	local bp = b.bp
	for k = -3, 3 do
		bp:box(
			4,
			22,
			0.3,
			k * 3.6,
			11,
			4,
			{ c = "#9FD8E8", m = "Glass", lod = "detail", col = false, t = 0.45, tag = "waterfall" }
		)
	end
	bp:box(
		26,
		1,
		4,
		0,
		0.4,
		2,
		{ c = "#E8F4F8", m = "SmoothPlastic", lod = "detail", col = false, t = 0.3, tag = "foam" }
	)
	bp:light(0, 10, -2, "#B8FFB0", 30, 1.2, "lamp")
	Kit.lifeAt(env.ctx, b, "dustBeam", 0, 12, -4, 8)
	Kit.lifeAt(env.ctx, b, "mist", 0, 1, 0, 8)
	table.insert(out, b)
	-- the goblin warning totem and a broken spear
	local tx, tz = Kit.spot(env, r, math.rad(-60), 8, 2)
	if tx and tz then
		local t = Kit.build(env, "MossWarningTotem", "landmark", tx, tz, 270)
		Kit.totem(t.bp, 0, Kit.gy(env, t, 0, 0), 0, 7)
		t.bp:rbox(0.3, 6, 0.3, 2, Kit.gy(env, t, 2, 1) + 0.3, 1, 80, 30, 0, o(Kit.wood, "fine", { col = false }))
		Kit.clear(env, tx, tz, 3)
		table.insert(out, t)
	end
	glowRing(env, out, 1, 5, 2)
end

local function grotto(env: Env, out: { Build })
	local r = room(env, 2)
	local ctx = env.ctx
	-- the goblin camp gnawed by spiders on the dry west side (outside the core)
	local camp = 0
	for _, a in { 150, 200, 235 } do
		local x, z = Kit.spot(env, r, math.rad(a), 12, 5)
		if x and z then
			camp += 1
			local t = Kit.build(env, `GoblinTent_{camp}`, "camp", x, z, a + 90)
			local tb = t.bp
			local y = Kit.gy(env, t, 0, 0)
			for _, s in { -1, 1 } do
				tb:rbox(
					0.2,
					5,
					6,
					s * 1.8,
					y + 1.8,
					0,
					0,
					0,
					s * -32,
					o({ c = "#4F6B2E", m = "Fabric" }, "shell", { q = false })
				)
			end
			tb:rbox(
				2.4,
				0.2,
				2,
				2.4,
				y + 0.2,
				2.4,
				0,
				30,
				6,
				o({ c = "#4F6B2E", m = "Fabric" }, "fine", { col = false })
			)
			Kit.web(tb, -2, y + 4.2, -3, 2.4, y + 0.5, 3)
			tb:add("cyl", 0.3, 2.6, 2.6, 3.2, y + 0.8, -2.2, 70, 20, 0, o(Kit.red, "fine", { col = false }))
			Kit.clear(env, x, z, 5)
			table.insert(out, t)
		end
	end
	local fx, fz = Kit.spot(env, r, math.rad(190), 24, 3)
	if fx and fz then
		local f = Kit.build(env, "GrottoFire", "camp", fx, fz, 0)
		Kit.campfire(f.bp, 0, Kit.gy(env, f, 0, 0), 0, "detail")
		Kit.lifeAt(ctx, f, "smoke", 0, 1, 0)
		Kit.clear(env, fx, fz, 3)
		table.insert(out, f)
	end
	-- giant glowing mushrooms on the lake's shore and moss carpets
	local lake = Kit.build(env, "GrottoShore", "glow", 44, 62, 0)
	for k = 0, 4 do
		local a = math.rad(200 + k * 30)
		local x, z = 44 + math.cos(a) * 27, 62 + math.sin(a) * 27
		if Kit.free(env, x, z, 2, false) then
			local lx, lz = x - 44, z - 62
			Kit.glowCap(lake.bp, lx, Kit.gy(env, lake, lx, lz), lz, 1.8 + (k % 2) * 0.8, Kit.MOSS, k % 2 == 0, "shell")
		end
	end
	-- the waterfall from the crack over the east shore: a column of falling water and a light from above
	lake.bp:box(
		3,
		22,
		1.2,
		14,
		11,
		12,
		{ c = "#9FD8E8", m = "Glass", lod = "detail", col = false, t = 0.4, tag = "waterfall" }
	)
	lake.bp:box(
		8,
		0.6,
		6,
		14,
		-0.8,
		12,
		{ c = "#E8F4F8", m = "SmoothPlastic", lod = "detail", col = false, t = 0.3, tag = "foam" }
	)
	Kit.lifeAt(ctx, lake, "dustBeam", 14, 20, 12, 6)
	Kit.lifeAt(ctx, lake, "mist", 14, 0, 12, 10)
	table.insert(out, lake)
	-- glow-worms on the vault, drops from the stalactites, bats high up
	Kit.life(ctx, "glowworms", r.x, (Kit.ceil(env, r.x, r.z) or 30) - 1, r.z, r.r * 0.9)
	Kit.life(ctx, "drips", r.x - 20, 20, r.z - 30, 30)
	Kit.life(ctx, "bats", r.x, 24, r.z, 30)
	glowRing(env, out, 2, 10, 4)
end

local function bearden(env: Env, out: { Build })
	local r = room(env, 3)
	local b = Kit.build(env, "BearDen", "traces", r.x, r.z, 0)
	local bp = b.bp
	for _, n in { { -182, -162 }, { -122, -170 } } do
		local lx, lz = n[1] - r.x, n[2] - r.z
		local y = Kit.gy(env, b, lx, lz)
		bp:add("ball", 9, 1.6, 7, lx, y + 0.2, lz, 0, 20, 0, o(Kit.moss, "detail", { col = false }))
		Kit.bones(bp, lx + 3, 0, lz + 2, 5, function(px: number, pz: number): number
			return Kit.gy(env, b, px, pz)
		end)
	end
	-- the log from the ravine, honeycombs, fur, the archshaman's amulet stake and bowl
	local lx, lz = 24, 10
	if Kit.free(env, r.x + lx, r.z + lz, 3) then
		bp:add(
			"cyl",
			14,
			1.6,
			1.6,
			lx,
			Kit.gy(env, b, lx, lz) + 0.8,
			lz,
			0,
			60,
			4,
			o(Kit.oldWood, "shell", { q = false })
		)
	end
	for k = 1, 3 do
		bp:rbox(
			1.6,
			0.4,
			1.2,
			-20 + k * 2,
			Kit.gy(env, b, -20 + k * 2, 24) + 0.2,
			24,
			0,
			k * 40,
			0,
			o({ c = "#D8A83A", m = "SmoothPlastic" }, "fine", { col = false })
		)
	end
	local sx, sz = Kit.wallSpot(env, r, math.rad(120), 6)
	if sx and sz then
		local px, pz = sx - r.x, sz - r.z
		local y = Kit.gy(env, b, px, pz)
		bp:box(0.4, 4, 0.4, px, y + 2, pz, o(Kit.wood, "detail", { col = false }))
		for k = 1, 4 do
			bp:add(
				"ball",
				0.4,
				0.6,
				0.4,
				px + 0.4,
				y + 3.6 - k * 0.5,
				pz,
				0,
				0,
				0,
				o(Kit.bone, "fine", { col = false })
			)
		end
		bp:add("cyl", 0.6, 1.6, 1.6, px + 1.4, y + 0.3, pz, 0, 0, 90, o(Kit.oldWood, "fine", { col = false }))
	end
	table.insert(out, b)
	glowRing(env, out, 3, 4, 1, "#A8C850")
end

local function barracks(env: Env, out: { Build })
	local r = room(env, 4)
	for k, a in { 30, 110, 200, 300 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 3)
		if x and z then
			local b = Kit.build(env, `Barracks_{k}`, "camp", x, z, a + 90)
			local bp = b.bp
			local y = Kit.gy(env, b, 0, 0)
			if k % 2 == 1 then
				-- a spear rack and red shields
				bp:box(5, 0.4, 0.4, 0, y + 3.6, 0, o(Kit.wood, "shell", { q = false }))
				for m = -2, 2 do
					bp:rbox(0.25, 6, 0.25, m, y + 3, 0.3, 8, 0, 0, o(Kit.wood, "detail", { col = false }))
				end
				for m = -1, 1 do
					bp:add(
						"cyl",
						0.3,
						2.4,
						2.4,
						m * 2.6,
						y + 1.3,
						-0.6,
						80,
						0,
						0,
						o(Kit.red, "detail", { col = false })
					)
				end
				Kit.torch(bp, 3.4, y, 1, Kit.FIRE)
			else
				-- a training dummy (a scarecrow from the Crow Field) and sleeping hides
				bp:box(0.4, 5, 0.4, 0, y + 2.5, 0, o(Kit.wood, "shell", { q = false }))
				bp:box(3, 0.4, 0.4, 0, y + 4, 0, o(Kit.wood, "detail", { col = false }))
				bp:add(
					"ball",
					1.4,
					1.6,
					1.4,
					0,
					y + 5.4,
					0,
					0,
					0,
					0,
					o({ c = "#B89A55", m = "Grass" }, "detail", { col = false })
				)
				for m = 0, 2 do
					bp:rbox(3, 0.2, 2, -3 + m * 3, y + 0.15, 3, 0, m * 20, 0, o(Kit.hide, "fine", { col = false }))
				end
			end
			Kit.clear(env, x, z, 3)
			table.insert(out, b)
		end
	end
	-- the drum
	local x, z = Kit.spot(env, r, math.rad(250), 6, 3)
	if x and z then
		local d = Kit.build(env, "BarracksDrum", "camp", x, z, 0)
		d.bp:add("cyl", 2.6, 3.4, 3.4, 0, Kit.gy(env, d, 0, 0) + 1.3, 0, 0, 0, 90, o(Kit.hide, "shell", { q = false }))
		table.insert(out, d)
	end
end

local function queennest(env: Env, out: { Build })
	local r = room(env, 5)
	local ctx = env.ctx
	-- the funnel web in the niche behind the room, lit from behind by glowing moss
	local nb = Kit.build(env, "QueenWeb", "landmark", 158, -200, 160)
	local bp = nb.bp
	local y = Kit.gy(env, nb, 0, 0)
	for k = 0, 11 do
		local a = k * math.pi / 6
		bp:beam(
			0,
			y + 8,
			0,
			math.cos(a) * 14,
			y + 8 + math.sin(a) * 10,
			-2,
			0.12,
			o(Kit.silk, "detail", { col = false, t = 0.25 })
		)
	end
	for ring = 1, 4 do
		bp:add("cyl", 0.08, ring * 6, ring * 6, 0, y + 8, -1, 90, 0, 0, o(Kit.silk, "detail", { col = false, t = 0.5 }))
	end
	for k = 0, 5 do
		local a = k * math.pi / 3
		Kit.glowCap(
			bp,
			math.cos(a) * 9,
			Kit.gy(env, nb, math.cos(a) * 9, math.sin(a) * 4 + 4),
			math.sin(a) * 4 + 4,
			0.8,
			Kit.MOSS,
			k % 2 == 0
		)
	end
	table.insert(out, nb)
	-- the shamans' bone altar under it: a spiral of bones, six totems with bowls of green fire, trinkets
	local ax, az = Kit.spot(env, r, math.rad(115), 10, 6)
	if ax and az then
		local alt = Kit.build(env, "QueenAltar", "landmark", ax, az, 0)
		local ab = alt.bp
		local ay = Kit.gy(env, alt, 0, 0)
		for k = 0, 18 do
			local a = k * 0.55
			local d = 1 + k * 0.28
			ab:rbox(
				1.6,
				0.3,
				0.3,
				math.cos(a) * d,
				ay + 0.15,
				math.sin(a) * d,
				0,
				math.deg(-a),
				0,
				o(Kit.bone, "detail", { col = false })
			)
		end
		for k = 0, 5 do
			local a = k * math.pi / 3
			local tx, tz = math.cos(a) * 6.5, math.sin(a) * 6.5
			local ty = Kit.gy(env, alt, tx, tz)
			ab:box(0.6, 4, 0.6, tx, ty + 2, tz, o(Kit.oldWood, if k % 2 == 0 then "shell" else "detail", { q = false }))
			Kit.fire(ab, tx, ty + 4.3, tz, 0.7, Kit.GREEN, "detail")
		end
		for k = 1, 6 do
			ab:box(
				0.4,
				0.4,
				0.4,
				math.cos(k) * 2,
				ay + 0.3,
				math.sin(k) * 2,
				{ c = "#E8C25A", m = "Neon", lod = "fine", col = false }
			)
		end
		Kit.clear(env, ax, az, 8)
		table.insert(out, alt)
	end
	-- threads through the vault
	local t = Kit.build(env, "QueenThreads", "traces", r.x, r.z, 0)
	for k = 0, 5 do
		local a = k * 1.05
		local px, pz = math.cos(a) * r.r * 0.7, math.sin(a) * r.r * 0.7
		local top = (Kit.ceil(env, r.x + px, r.z + pz) or 20) - t.at.y
		t.bp:beam(px, top, pz, -px * 0.4, top - 2, -pz * 0.4, 0.08, o(Kit.silk, "fine", { col = false, t = 0.35 }))
	end
	table.insert(out, t)
	Kit.life(ctx, "spiders", r.x, 14, r.z, 18)
end

local function spiderhall(env: Env, out: { Build })
	local r = room(env, 6)
	local ctx = env.ctx
	local b = Kit.build(env, "SpiderHall", "traces", r.x, r.z, 0)
	local bp = b.bp
	for k = 0, 9 do
		local a = k * (2 * math.pi / 10) + 0.2
		local x, z = Kit.wallSpot(env, r, a, 4)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local fy = Kit.gy(env, b, lx, lz)
			local cy = (Kit.ceil(env, x, z) or (fy + 14 + b.at.y)) - b.at.y
			Kit.web(bp, lx, fy + 1, lz, lx * 0.8, cy - 1, lz * 0.8)
			if k % 2 == 0 then
				Kit.cocoon(bp, lx * 0.85, fy + 4, lz * 0.85, cy, k % 4 == 0)
			end
			if k % 3 == 0 then
				-- pale glowing egg sacs
				bp:add("ball", 2.4, 2, 2.4, lx * 0.9, fy + 1, lz * 0.9, 0, 0, 0, {
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
	Kit.bones(bp, 10, 0, 18, 6, function(px: number, pz: number): number
		return Kit.gy(env, b, px, pz)
	end)
	table.insert(out, b)
	-- the goblin barricade of shields and burnt webs at the entry (the tunnel from the grotto comes from the south)
	local bx, bz = r.x + 8, r.z + r.r - 6
	if Kit.free(env, bx, bz, 3) then
		local bar = Kit.build(env, "GoblinBarricade", "camp", bx, bz, 0)
		for m = -2, 2 do
			bar.bp:add(
				"cyl",
				0.3,
				2.6,
				2.6,
				m * 2.4 + 10,
				Kit.gy(env, bar, m * 2.4 + 10, 0) + 1.3,
				0,
				90,
				0,
				0,
				o(Kit.red, "shell", { q = false })
			)
		end
		Kit.torch(bar.bp, 14, Kit.gy(env, bar, 14, 2), 2, Kit.FIRE)
		table.insert(out, bar)
	end
	glowRing(env, out, 6, 5, 2, Kit.PALE)
	Kit.life(ctx, "spiders", r.x, 18, r.z, 26)
	Kit.life(ctx, "drips", r.x, 18, r.z, 30)
end

local function shrine(env: Env, out: { Build })
	local r = room(env, 7)
	-- the stone circle with green fire (on the altar terrace by the south wall)
	local b = Kit.build(env, "ShamanShrine", "landmark", 90, 278, 180)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	for k = 0, 7 do
		local a = k * math.pi / 4
		bp:rbox(
			1.4,
			4,
			1,
			math.cos(a) * 6,
			y + 1.6,
			math.sin(a) * 6,
			0,
			math.deg(-a),
			0,
			o(Kit.rock, "shell", { q = false })
		)
	end
	Kit.fire(bp, 0, y + 0.6, 0, 2, Kit.GREEN, "detail")
	for k = 0, 2 do
		-- carved totems with faces
		local tx = -8 + k * 8
		bp:box(1.6, 7, 1.6, tx, y + 3.5, -8, o(Kit.oldWood, "shell", { q = false }))
		bp:box(
			1.2,
			0.5,
			0.2,
			tx,
			y + 5.4,
			-8.9,
			{ c = Kit.GREEN, m = "Neon", lod = "detail", col = false, tag = "glow", jitter = 0, fxColor = Kit.GREEN }
		)
	end
	table.insert(out, b)
	-- glowing hand prints on the walls, a mushroom ring, heaps of skulls, bundles of herbs
	local m = Kit.build(env, "ShrineMarks", "glow", r.x, r.z, 0)
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.3
		local x, z = Kit.wallSpot(env, r, a, 2)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			m.bp:box(
				1.2,
				1.4,
				0.1,
				lx,
				Kit.gy(env, m, lx, lz) + 4,
				lz,
				{ c = Kit.GREEN, m = "Neon", lod = "fine", col = false, t = 0.3 }
			)
		end
	end
	for k = 0, 8 do
		local a = k * math.pi * 2 / 9
		local lx, lz = math.cos(a) * 30, math.sin(a) * 30
		if Kit.free(env, r.x + lx, r.z + lz, 1, false) then
			Kit.glowCap(m.bp, lx, Kit.gy(env, m, lx, lz), lz, 0.5, Kit.MOSS, false, "fine")
		end
	end
	table.insert(out, m)
	glowRing(env, out, 7, 6, 2)
end

local function antechamber(env: Env, out: { Build })
	local r = room(env, 8)
	-- two rows of tall red banners with the fang sign along the avenue to the gate (x 205..262, z ±12)
	local b = Kit.build(env, "BannerAvenue", "landmark", 235, 0, 0)
	local bp = b.bp
	for k = 0, 3 do
		local lx = -26 + k * 14
		for _, s in { -1, 1 } do
			local lz = s * 13
			local y = Kit.gy(env, b, lx, lz)
			bp:box(0.6, 14, 0.6, lx, y + 7, lz, o(Kit.wood, "shell", { q = false }))
			bp:box(
				0.2,
				8,
				3,
				lx,
				y + 9,
				lz - s * 1.4,
				{ c = "#8A2A22", m = "Fabric", lod = "detail", col = false, tag = "flag" }
			)
			bp:box(
				0.25,
				1.4,
				1.4,
				lx + s * 0.05,
				y + 10,
				lz - s * 1.4,
				o({ c = "#E8E0C8", m = "SmoothPlastic" }, "fine", { col = false })
			)
		end
	end
	-- two great war drums and fire baskets by the gate, spiked barricades, trophies, skulls
	for _, s in { -1, 1 } do
		local lx, lz = 18, s * 22
		local y = Kit.gy(env, b, lx, lz)
		bp:add("cyl", 4, 6, 6, lx, y + 2, lz, 0, 0, 90, o(Kit.hide, "shell", { q = false }))
		bp:add("cyl", 0.3, 6.2, 6.2, lx, y + 4.1, lz, 0, 0, 90, o(Kit.red, "detail", { col = false }))
		Kit.fire(bp, 30, Kit.gy(env, b, 30, s * 14) + 3, s * 14, 1.4, Kit.FIRE, "detail")
		bp:box(0.6, 3, 0.6, 30, Kit.gy(env, b, 30, s * 14) + 1.4, s * 14, o(Kit.iron, "detail", { col = false }))
		for m = 0, 2 do
			bp:rbox(
				0.4,
				6,
				0.4,
				-36 + m * 5,
				Kit.gy(env, b, -36 + m * 5, s * 20) + 1.6,
				s * 20,
				s * 30,
				0,
				0,
				o(Kit.oldWood, "detail", { col = false })
			)
		end
		for m = 0, 4 do
			Kit.skull(bp, 4 + m * 1.6, Kit.gy(env, b, 4 + m, s * 28), s * 28, 1.2, m * 40)
		end
	end
	-- the goblin maw carved round the gate (x 272): fangs over the arch
	for k = -3, 3 do
		bp:add(
			"wedge",
			1.2,
			4,
			1.2,
			33,
			15 - math.abs(k) * 0.6,
			k * 2.2,
			180,
			90,
			0,
			o(Kit.bone, "detail", { col = false })
		)
	end
	table.insert(out, b)
	local _ = r
end

-- The tunnels: moss, drops, goblin paintings towards the shrine, threads towards the nest.
local function tunnels(env: Env, out: { Build })
	local b = Kit.build(env, "TunnelMarks", "traces", 0, 0, 0)
	for k = 0, 3 do
		local x, z = -10 + k * 18, 92 + k * 20
		if env.T.floor(x, z) then
			b.bp:box(
				2,
				1.4,
				0.1,
				x,
				Kit.gy(env, b, x, z) + 4,
				z,
				o({ c = "#8A2A22", m = "SmoothPlastic" }, "fine", { col = false })
			)
		end
	end
	table.insert(out, b)
	Kit.life(env.ctx, "drips", -150, 12, -60, 20)
	Kit.life(env.ctx, "drips", 110, 12, 0, 20)
end

function Moss.all(env: Env, out: { Build })
	entrance(env, out)
	grotto(env, out)
	bearden(env, out)
	barracks(env, out)
	queennest(env, out)
	spiderhall(env, out)
	shrine(env, out)
	antechamber(env, out)
	tunnels(env, out)
end

return Moss
