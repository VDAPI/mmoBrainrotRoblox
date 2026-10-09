--!strict
-- Abandoned Mine (49-56) dressing (S50): a dwarven silver and mithril mine taken by the Ash Orcs. The rails lead the
-- player in (tunnels 1-2, 2-3, 3-4, flat detail without collision), props every ~12 studs in the tunnels.
--   1 the Pithead: the timbered adit, dwarven runes smeared with red orc paint and hand prints, two overturned carts
--     as a barricade with a way through, a skull on a stake, a war drum, stakes with chains for the hyenas, lanterns,
--   2 the Lift Hall (berserkers, a hyena): the wooden headframe and wheel in the shaft, the cage hanging askew on one
--     chain halfway up, the coiled torn rope and a smashed cage in the rubble, ash falling in a pale beam, a turntable
--     and carts of ore, orc banners nailed over dwarven reliefs, a rack of two-handed axes, a spit over a fire,
--   3 the Camp in the Pump Chamber (hyenas, orcs): the huge dry pump wheel hung with trophies, hide tents in the south
--     niche, a long fire with a spit, a trough and gnawed bones for the hyenas, stakes with chains, a drum, dwarven
--     helmets as bowls, the first blue glint of mithril in the tunnel east,
--   4 the Chief's Hall by the Mithril Vein ("wow"): the great glowing vein through the east wall, the chief's throne
--     on the terrace made of an ore cart, dwarven shields and a headless king (the head at his feet), stakes with
--     helmets, banners; the vultures' shaft over the north part with nests on beams, white streaks, feathers and a
--     pile of carrion under it,
--   5 the Kennel by the Breakthrough: the pool of magma behind broken props and a torn-out iron bulkhead door with a
--     dwarven warning rune, steam, embers, the hyenas' kennels of carts and logs, gnawed bones, chewed boots. Pure.

local TerrainLayers = require("../TerrainLayers")
local Kit = require("./Kit")

local o = Kit.o

local Mine = {}

type Build = Kit.Build
type Env = Kit.Env
type BP = Kit.BP

local RUNE = "#6FB8FF"
local ORC = "#B0261A"
local SILVER = "#D8DCE6"
local MITHRIL = "#9FD8FF"
local TIMBER = { c = "#5A4632", m = "Wood" }
local RAIL = { c = "#4A4A50", m = "CorrodedMetal" }
local IRON = { c = "#3A3A40", m = "CorrodedMetal" }
local ORCRAG = { c = "#7A2A1E", m = "Fabric" }
local HIDE = { c = "#7A5A3E", m = "Fabric" }
local STONE = { c = "#5A5250", m = "Slate" }

local function glowBox(
	bp: BP,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: string,
	tag: string?
)
	bp:box(sx, sy, sz, x, y, z, {
		c = color,
		m = "Neon",
		lod = "detail",
		col = false,
		q = false,
		tag = tag or "glow",
		jitter = 0,
		fxColor = color,
	})
end

local function cart(bp: BP, x: number, y: number, z: number, yaw: number, tipped: boolean, ore: string?, lod: any?)
	bp:push(x, y, z, if tipped then 70 else 0, yaw, 0)
	bp:box(3, 1.8, 4.4, 0, if tipped then 1.6 else 1.5, 0, o(IRON, lod or "shell", { q = false }))
	for _, s in { -1, 1 } do
		for _, t in { -1, 1 } do
			bp:add("cyl", 0.4, 1.2, 1.2, s * 1.6, 0.6, t * 1.4, 0, 0, 0, o(RAIL, "fine", { col = false }))
		end
	end
	if ore then
		glowBox(bp, 2.4, 0.5, 3.6, 0, 2.5, 0, ore, "glow")
	end
	bp:pop()
end

-- Rails and props along a corridor (from the plan): a pair of rails every 4 studs (detail, flat, no collision) and a
-- pair of props every ~12 studs (some broken and bent).
local function railway(env: Env, out: { Build }, n: number, ax: number, az: number, bx: number, bz: number, w: number)
	local line = TerrainLayers.line({ { ax, az }, { bx, bz } })
	local b = Kit.build(env, `Rails_{n}`, "traces", ax, az, 0)
	local s = 0
	local k = 0
	while s < line.length do
		local x, z, dx, dz = TerrainLayers.pointAt(line, s)
		local f = env.T.floor(x, z)
		if f and not env.T.liquid(x, z) then
			local lx, lz = x - b.at.x, z - b.at.z
			local y = f - b.at.y
			local yaw = math.deg(math.atan2(dx, dz))
			for _, side in { -1, 1 } do
				b.bp:rbox(
					0.3,
					0.25,
					4.2,
					lx + dz * side * 1.3,
					y + 0.15,
					lz - dx * side * 1.3,
					0,
					yaw,
					0,
					o(RAIL, "detail", { col = false })
				)
			end
			b.bp:rbox(3.6, 0.2, 0.6, lx, y + 0.08, lz, 0, yaw, 0, o(TIMBER, "fine", { col = false }))
			k += 1
			if k % 3 == 0 and env.T.roomAt(x, z) == nil then
				-- props: two posts and a cap beam across the tunnel
				local half = w / 2 - 1.5
				local broken = k % 9 == 0
				for _, side in { -1, 1 } do
					local px, pz = lx + dz * side * half, lz - dx * side * half
					local py = (env.T.floor(x + dz * side * half, z - dx * side * half) or f) - b.at.y
					local head = (env.T.ceiling(x + dz * side * half, z - dx * side * half) or (f + 10)) - b.at.y
					local h = math.max(4, math.min(head - py - 0.5, 11))
					b.bp:rbox(
						0.9,
						h,
						0.9,
						px,
						py + h / 2,
						pz,
						0,
						yaw,
						if broken and side == 1 then 8 else 0,
						o(TIMBER, "detail", { col = false })
					)
				end
				local cy = (env.T.ceiling(x, z) or (f + 10)) - b.at.y
				local ch = math.min(cy - y - 0.6, 11)
				b.bp:rbox(
					w - 2,
					0.9,
					0.9,
					lx,
					y + ch,
					lz,
					0,
					yaw,
					if broken then 6 else 0,
					o(TIMBER, "detail", { col = false })
				)
			end
		end
		s += 4
	end
	table.insert(out, b)
end

local function rails(env: Env, out: { Build })
	local cave = env.cave
	if not cave then
		return
	end
	local rooms = env.T.rooms
	-- the exit to the Lift Hall, the Pump Chamber and the Chief's Hall (rooms 1-2, 2-3, 3-4)
	railway(env, out, 1, -205, 0, rooms[2].x, rooms[2].z, 14)
	railway(env, out, 2, rooms[2].x, rooms[2].z, rooms[3].x, rooms[3].z, 12)
	railway(env, out, 3, rooms[3].x, rooms[3].z, rooms[4].x, rooms[4].z, 12)
end

local function pithead(env: Env, out: { Build })
	local r = env.T.rooms[1]
	-- the timbered adit round the exit (-211, 0)
	local a = Kit.build(env, "Adit", "landmark", -206, 0, 90)
	for t = 0, 2 do
		for _, s in { -1, 1 } do
			a.bp:box(1.4, 14, 1.4, s * 8, 7, t * 4, o(TIMBER, "detail", { col = false }))
		end
		a.bp:box(18, 1.4, 1.6, 0, 14, t * 4, o(TIMBER, "detail", { col = false }))
	end
	-- dwarven runes smeared with orc paint and hand prints
	for t = -2, 2 do
		glowBox(a.bp, 1.2, 1.6, 0.1, t * 2.6, 16.4, 0.6, RUNE)
		a.bp:box(
			1.6,
			1.8,
			0.12,
			t * 2.6 + 0.4,
			16.2,
			0.5,
			o({ c = ORC, m = "SmoothPlastic" }, "fine", { col = false, t = 0.2 })
		)
	end
	table.insert(out, a)
	-- the barricade of overturned carts with a way through, the skull on a stake, the drum, the hyenas' stakes
	local b = Kit.build(env, "OrcBarricade", "traces", -172, 0, 90)
	local y = Kit.gy(env, b, 0, 0)
	cart(b.bp, -8, y, 0, 80, true, nil)
	cart(b.bp, 8, y, 0, 100, true, nil)
	b.bp:box(0.4, 7, 0.4, -12, y + 3.5, 3, o(TIMBER, "detail", { col = false }))
	Kit.skull(b.bp, -12, y + 7, 3, 1.4, 0)
	b.bp:add("cyl", 2, 3, 3, 12, y + 1, 4, 0, 0, 90, o(HIDE, "detail", { col = false }))
	table.insert(out, b)
	for k = 0, 2 do
		local x, z = Kit.spot(env, r, math.rad(60 + k * 100), 5, 1, false)
		if x and z then
			local s = Kit.build(env, `HyenaStake_{k}`, "traces", x, z, k * 40)
			local sy = Kit.gy(env, s, 0, 0)
			s.bp:box(0.5, 3, 0.5, 0, sy + 1.5, 0, o(TIMBER, "detail", { col = false }))
			s.bp:beam(0, sy + 2.6, 0, 3, sy + 0.2, 1, 0.2, o(IRON, "fine", { col = false }))
			Kit.lantern(s.bp, 1, sy, -1.5, "#FFB25A", 5, "detail")
			table.insert(out, s)
		end
	end
	Kit.life(env.ctx, "dustBeam", -205, 6, 0, 8)
	Kit.life(env.ctx, "drips", r.x, 14, r.z, 20)
end

local function lift(env: Env, out: { Build })
	local r = env.T.rooms[2]
	-- the headframe and wheel in the shaft (-114, -62), the cage askew on one chain, the torn rope, the smashed cage
	local b = Kit.build(env, "LiftHeadframe", "landmark", -114, -62, 30)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	for _, s in { -1, 1 } do
		for _, t in { -1, 1 } do
			bp:beam(
				s * 5,
				y,
				t * 5,
				s * 3,
				y + 34,
				t * 3,
				0.9,
				o(TIMBER, if t == -1 then "shell" else "detail", { q = false, col = t == -1 })
			)
		end
	end
	bp:add("cyl", 1, 8, 8, 0, y + 34, 0, 0, 0, 0, o(TIMBER, "detail", { col = false }))
	bp:box(0.25, 12, 0.25, 1, y + 22, 0, o(IRON, "fine", { col = false }))
	bp:rbox(4, 5, 4, 1.4, y + 14, 0.5, 8, 15, 14, o(IRON, "detail", { col = false, t = 0.3 }))
	bp:rbox(4.4, 1.6, 4.4, -2, y + 0.8, 3, 20, 30, 40, o(IRON, "detail", { col = false, t = 0.3 }))
	for k = 0, 5 do
		local a = k * 1.05
		bp:add(
			"cyl",
			0.5,
			2.6 - k * 0.2,
			2.6 - k * 0.2,
			3.5,
			y + 0.25 + k * 0.4,
			-2.5,
			0,
			a,
			90,
			o(Kit.rope, "fine", { col = false })
		)
	end
	Kit.lifeAt(env.ctx, b, "ashBeam", 0, 30, 0, 4)
	Kit.lifeAt(env.ctx, b, "dustBeam", 0, 12, 0, 5)
	Kit.lifeAt(env.ctx, b, "bats", 0, 26, 0, 6)
	Kit.clear(env, -114, -62, 7)
	table.insert(out, b)
	-- the turntable, carts of ore, banners, the rack of axes, the spit
	for k, pr in { { a = 200, kind = "carts" }, { a = 120, kind = "rack" }, { a = 20, kind = "spit" } } do
		local x, z = Kit.spot(env, r, math.rad(pr.a), 6, 3)
		if x and z then
			local p = Kit.build(env, `LiftHall_{k}`, "traces", x, z, pr.a)
			local py = Kit.gy(env, p, 0, 0)
			local kind = pr.kind
			if kind == "carts" then
				p.bp:add("cyl", 0.3, 7, 7, 0, py + 0.15, 0, 0, 0, 90, o(RAIL, "detail", { col = false }))
				cart(p.bp, 0, py, 0, 30, false, SILVER)
				cart(p.bp, 5, py, 2, 60, false, nil, "detail")
			elseif kind == "rack" then
				p.bp:box(6, 0.5, 1, 0, py + 3.5, 0, o(TIMBER, "shell", { q = false }))
				for t = -2, 2 do
					p.bp:rbox(0.3, 5, 0.3, t * 1.2, py + 2.4, 0.2, 0, 0, 6, o(TIMBER, "fine", { col = false }))
					p.bp:box(1.8, 1.4, 0.2, t * 1.2, py + 4.6, 0.2, o(IRON, "fine", { col = false }))
				end
			else
				Kit.campfire(p.bp, 0, py, 0, "detail")
				for _, s in { -1, 1 } do
					p.bp:beam(s * 2.4, py, 0, s * 1.6, py + 3, 0, 0.2, o(TIMBER, "fine", { col = false }))
				end
				p.bp:box(4, 0.2, 0.2, 0, py + 3, 0, o(IRON, "fine", { col = false }))
				p.bp:add(
					"ball",
					1.6,
					1,
					1,
					0,
					py + 2.6,
					0,
					0,
					0,
					0,
					o({ c = "#7A3A22", m = "SmoothPlastic" }, "fine", { col = false })
				)
			end
			Kit.clear(env, x, z, 4)
			table.insert(out, p)
		end
	end
	local f = Kit.build(env, "OrcBanners", "traces", r.x, r.z, 0)
	for k = 0, 2 do
		local x, z = Kit.wallSpot(env, r, k * 2.1 + 0.3, 1)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			Kit.banner(f.bp, lx, Kit.gy(env, f, lx, lz), lz, 9, ORCRAG)
		end
	end
	table.insert(out, f)
end

local function camp(env: Env, out: { Build })
	local r = env.T.rooms[3]
	-- the dry pump wheel by the west wall, hung with trophies
	local x, z = Kit.spot(env, r, math.rad(180), 4, 4)
	if x and z then
		local w = Kit.build(env, "PumpWheel", "landmark", x, z, 90)
		local y = Kit.gy(env, w, 0, 0)
		w.bp:add("cyl", 1.4, 18, 18, 0, y + 10, 0, 0, 0, 0, o(TIMBER, "detail", { col = false }))
		w.bp:box(2, 4, 2, 0, y + 2, 0, o(STONE, "shell", { q = false }))
		for k = 0, 5 do
			local a = k * math.pi / 3
			w.bp:beam(
				0,
				y + 10,
				0,
				math.cos(a) * 8.6,
				y + 10 + math.sin(a) * 8.6,
				0,
				0.5,
				o(TIMBER, "fine", { col = false })
			)
			Kit.skull(w.bp, math.cos(a) * 8.6, y + 9 + math.sin(a) * 8.6, -0.8, 1, 0)
		end
		Kit.clear(env, x, z, 4)
		table.insert(out, w)
	end
	-- the hide tents in the south niche (6, 100)
	local t = Kit.build(env, "OrcTents", "landmark", 6, 100, 0)
	for k = -1, 1 do
		local lx = k * 9
		local ty = Kit.gy(env, t, lx, 0)
		t.bp:rbox(7, 0.3, 6, lx - 2, ty + 3, 0, 0, 0, 50, o(HIDE, "detail", { col = false }))
		t.bp:rbox(7, 0.3, 6, lx + 2, ty + 3, 0, 0, 0, -50, o(HIDE, "detail", { col = false }))
		t.bp:box(0.4, 5.6, 0.4, lx, ty + 2.8, 0, o(TIMBER, "shell", { q = false }))
	end
	table.insert(out, t)
	-- the long fire with a spit, the trough and bones, the drum, helmets as bowls
	local fx, fz = Kit.spot(env, r, math.rad(320), 8, 4)
	if fx and fz then
		local f = Kit.build(env, "CampFire", "camp", fx, fz, 30)
		local y = Kit.gy(env, f, 0, 0)
		Kit.campfire(f.bp, -2, y, 0, "detail")
		Kit.campfire(f.bp, 2, y, 0, "detail")
		f.bp:box(8, 0.2, 0.2, 0, y + 3, 0, o(IRON, "fine", { col = false }))
		f.bp:box(3, 1, 1.4, 0, y + 0.5, 4, o(TIMBER, "detail", { col = false }))
		Kit.bones(f.bp, 0, y, 5, 6)
		f.bp:add("cyl", 2, 3, 3, -5, y + 1, -3, 0, 0, 90, o(HIDE, "detail", { col = false }))
		for k = 0, 2 do
			f.bp:add("ball", 1.4, 0.8, 1.4, 4 + k, y + 0.4, -3, 180, 0, 0, o(IRON, "fine", { col = false }))
		end
		Kit.lifeAt(env.ctx, f, "smoke", 0, 3, 0, 2)
		Kit.clear(env, fx, fz, 5)
		table.insert(out, f)
	end
	Kit.life(env.ctx, "drips", r.x, 16, r.z, 26)
end

local function chief(env: Env, out: { Build })
	local r = env.T.rooms[4]
	-- the great mithril vein through the east wall
	local v = Kit.build(env, "MithrilVein", "glow", r.x, r.z, 0)
	for k = -6, 6 do
		local a = k * 0.09
		local x, z = Kit.wallSpot(env, r, a, 0, 6)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local y = Kit.gy(env, v, lx, lz)
			v.bp:rbox(1.2, 2.4, 6, lx + 1, y + 6 + math.sin(k * 0.8) * 2.4, lz, 0, math.deg(-a), 10, {
				c = MITHRIL,
				m = "Neon",
				lod = "detail",
				col = false,
				q = false,
				tag = "glow",
				jitter = 0,
				fxColor = MITHRIL,
			})
			if k % 3 == 0 then
				v.bp:light(lx - 2, y + 6, lz, MITHRIL, 26, 1.2, "crystal")
			end
		end
	end
	table.insert(out, v)
	-- the chief's throne on the terrace (154, 50): an ore cart, dwarven shields, the headless king
	local t = Kit.build(env, "ChiefThrone", "landmark", 154, 50, 270)
	local y = Kit.gy(env, t, 0, 0)
	cart(t.bp, 0, y, 0, 0, false, nil)
	t.bp:box(3.6, 6, 0.8, 0, y + 4.4, 2.2, o(IRON, "detail", { col = false }))
	for k = -1, 1 do
		t.bp:add(
			"cyl",
			0.3,
			2.8,
			2.8,
			k * 2.4,
			y + 7.6,
			2.4,
			90,
			0,
			0,
			o({ c = "#8A6A3A", m = "Metal" }, "detail", { col = false })
		)
	end
	t.bp:box(3, 8, 2.4, 6, y + 4, 3, o(STONE, "detail", { col = false }))
	t.bp:box(2.2, 2.2, 2.2, 7.6, y + 1.1, 0, o(STONE, "detail", { col = false })) -- the head at his feet
	for k = 0, 2 do
		t.bp:box(0.4, 6, 0.4, -6 + k * 1.2, y + 3, 2 - k * 2, o(TIMBER, "detail", { col = false }))
		t.bp:add("ball", 1.4, 1, 1.4, -6 + k * 1.2, y + 6.2, 2 - k * 2, 0, 0, 0, o(IRON, "fine", { col = false }))
	end
	Kit.banner(t.bp, -4, y, 4, 10, ORCRAG)
	Kit.banner(t.bp, 4, y, 5, 10, ORCRAG)
	Kit.clear(env, 154, 50, 6)
	table.insert(out, t)
	-- the vultures' shaft (116, 26): nests on beams, white streaks, feathers, the pile of carrion
	local s = Kit.build(env, "VultureShaft", "traces", 116, 26, 0)
	local sy = Kit.gy(env, s, 0, 0)
	local top = (Kit.ceil(env, 126, 26) or 30) - s.at.y
	for k = 0, 2 do
		local a = k * 2.1
		s.bp:beam(
			math.cos(a) * 10,
			top - 2 - k * 3,
			math.sin(a) * 10,
			math.cos(a + 1) * 10,
			top - 3 - k * 3,
			math.sin(a + 1) * 10,
			0.8,
			o(TIMBER, "detail", { col = false })
		)
		s.bp:add(
			"ball",
			3,
			1,
			3,
			math.cos(a) * 9,
			top - 1.6 - k * 3,
			math.sin(a) * 9,
			0,
			0,
			0,
			o(Kit.wood, "fine", { col = false })
		)
	end
	s.bp:add(
		"ball",
		5,
		1.2,
		4,
		3,
		sy + 0.4,
		-2,
		0,
		0,
		0,
		o({ c = "#6A4A3A", m = "SmoothPlastic" }, "detail", { col = false })
	)
	Kit.bones(s.bp, 3, 0, -2, 8, function(lx, lz)
		return Kit.gy(env, s, lx, lz)
	end)
	for k = 0, 4 do
		s.bp:rbox(
			0.15,
			0.06,
			1,
			-3 + k * 1.3,
			sy + 0.05,
			3 + (k % 2),
			0,
			k * 60,
			0,
			o({ c = "#3A2E2A", m = "Fabric" }, "fine", { col = false })
		)
	end
	Kit.lifeAt(env.ctx, s, "vultures", 0, top, 0, 18)
	Kit.lifeAt(env.ctx, s, "vulturePerch", 3, sy + 1, -2, 4)
	Kit.lifeAt(env.ctx, s, "ashBeam", 0, top - 2, 0, 6)
	table.insert(out, s)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 24)
end

local function kennel(env: Env, out: { Build })
	local r = env.T.rooms[5]
	-- the broken props and the torn-out bulkhead door before the breakthrough (32, -116)
	local b = Kit.build(env, "Breakthrough", "landmark", 32, -104, 0)
	local y = Kit.gy(env, b, 0, 0)
	for _, s in { -1, 1 } do
		b.bp:rbox(1, 10, 1, s * 6, y + 4, 0, 0, 0, s * 12, o(TIMBER, "detail", { col = false }))
	end
	b.bp:rbox(12, 1, 1, 1, y + 6, 0, 0, 0, 14, o(TIMBER, "detail", { col = false }))
	b.bp:rbox(6, 9, 0.6, 8, y + 0.6, 3, -80, 30, 0, o(IRON, "detail", { col = false }))
	glowBox(b.bp, 1.6, 1.6, 0.1, 8, y + 1.1, 3, RUNE)
	Kit.lifeAt(env.ctx, b, "steam", 0, 1, -10, 5)
	table.insert(out, b)
	-- the hyenas' kennels of carts and logs, gnawed bones, chewed boots, tufts of fur
	for k, a in { 150, 190, 230 } do
		local x, z = Kit.spot(env, r, math.rad(a), 5, 3)
		if x and z then
			local kb = Kit.build(env, `HyenaKennel_{k}`, "traces", x, z, a)
			local ky = Kit.gy(env, kb, 0, 0)
			if k == 2 then
				cart(kb.bp, 0, ky, 0, 90, true, nil)
			else
				for t = 0, 2 do
					kb.bp:add(
						"cyl",
						6,
						1.4,
						1.4,
						0,
						ky + 0.7 + t * 1.2,
						0,
						0,
						0,
						0,
						o(TIMBER, if t == 0 then "shell" else "detail", { q = false, col = t == 0 })
					)
				end
			end
			Kit.bones(kb.bp, 3, ky, 2, 5)
			kb.bp:rbox(
				1.2,
				0.8,
				2,
				-3,
				ky + 0.4,
				2,
				0,
				40,
				20,
				o({ c = "#4A3020", m = "Fabric" }, "fine", { col = false })
			)
			Kit.clear(env, x, z, 4)
			table.insert(out, kb)
		end
	end
	Kit.life(env.ctx, "embers", 32, -8, -116, 5)
	Kit.life(env.ctx, "drips", r.x, 14, r.z, 18)
end

function Mine.all(env: Env, out: { Build })
	rails(env, out)
	pithead(env, out)
	lift(env, out)
	camp(env, out)
	chief(env, out)
	kennel(env, out)
end

return Mine
