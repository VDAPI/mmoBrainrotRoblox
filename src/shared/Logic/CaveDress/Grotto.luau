--!strict
-- Ice Grotto (74-83) dressing (S51): the yeti's burrows melted and clawed into the glacier. Light comes from the ice;
-- the one warm light is the trappers' lantern by the entrance.
--   1 the Mouth of Icicles: fangs of icicles over the exit, the drift blown in, tracks of yeti and wolves leading in,
--     the trappers' abandoned camp (an overturned sled, snares, a hide on a frame, a lantern still smouldering), huge
--     hand prints in the ice at head height,
--   2 the Hall of Icefalls ("wow"): three frozen waterfalls in bays (curtains of ice from the vault to the frozen
--     pool, glowing blue from inside), the yeti's ice hole with fish bones, hacked blocks and a frozen fish, claw and
--     hand marks on the falls,
--   3 the Harpies' Chimney ("wow"): the shaft to the sky with icicles round its rim, snow falling in the moonbeam on
--     the drift, the harpies' nests of branches, bones and feathers with glinting loot on unreachable ledges, the
--     climbers' gear under them (torn ropes hanging from the nests, pitons, crampons, a torn pack, an ice axe),
--   4 the Mountain King's Den (Elite II): the throne of mammoth tusks and ice blocks with furs on its dais, the wall
--     of trophies behind it (wolf skulls, ibex horns, a giant's helmet), the ice window with the frozen mammoth calf
--     lit from behind, the larder (ibex carcasses on ice hooks, a mammoth leg), heaps of gnawed bones, a bed of furs,
--   5 the Wolf Den: four burrows in the walls lined with fur, trodden ruts in the snow, ibex bones, a torn leopard
--     skin, scratches on the ice, the frozen brook. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Grotto = {}

type Build = Kit.Build
type Env = Kit.Env
type BP = Kit.BP

local ICE = { c = "#A8D8F0", m = "Ice" }
local ICEGLASS = { c = "#BFE8FF", m = "Glass" }
local GLOW = "#9FE0FF"
local MOON = "#CFE0FF"
local FUR = { c = "#C8DDEB", m = "Fabric" }
local YETI = { c = "#E4EAF0", m = "Fabric" }
local HARPY = "#E8E25A"
local WOOD = { c = "#5A4632", m = "Wood" }

local function glowBox(
	bp: BP,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: string,
	t: number?
)
	bp:box(sx, sy, sz, x, y, z, {
		c = color,
		m = "Neon",
		lod = "detail",
		col = false,
		q = false,
		t = t or 0.2,
		tag = "glow",
		jitter = 0,
		fxColor = color,
	})
end

-- Icicles hanging from the ceiling round a point (detail, no collision).
local function icicles(env: Env, bp: BP, b: Build, lx: number, lz: number, r: number, n: number)
	for k = 1, n do
		local a = k * 2.4
		local d = r * ((k % 4) / 4 + 0.2)
		local px, pz = lx + math.cos(a) * d, lz + math.sin(a) * d
		local top = env.T.ceiling(b.at.x + px, b.at.z + pz)
		if top and top < 9000 then
			local len = 1.5 + (k % 3) * 1.2
			bp:add("cyl", len, 0.7, 0.7, px, top - b.at.y - len / 2, pz, 0, 0, 90, o(ICE, "fine", { col = false }))
		end
	end
end

-- A frozen waterfall (icefall feature): curtains of ice from the vault to the frozen pool, glowing blue from inside.
function Grotto.icefall(env: Env, out: { Build }, f: { [string]: any }, i: number)
	local b = Kit.build(env, `Icefall_{i}`, "glow", f.x, f.z, f.yaw or 0)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	local top = math.min(f.top, ((Kit.ceil(env, f.x, f.z) or (y + f.top)) - b.at.y) - y)
	local w = f.w or 12
	for k = 0, 3 do
		local h = top * (1 - k * 0.12)
		bp:rbox(
			w * (1 - k * 0.15),
			h,
			1.6,
			(k % 2) * 1.2 - 0.6,
			y + top - h / 2,
			4 - k * 1.4,
			-4,
			0,
			0,
			o(ICEGLASS, "detail", { col = false, t = 0.35 })
		)
	end
	glowBox(bp, w * 0.7, top * 0.8, 0.3, 0, y + top * 0.45, 4.8, GLOW, 0.3)
	bp:light(0, y + top * 0.4, 2, GLOW, 30, 1.3, "crystal")
	icicles(env, bp, b, 0, 2, w / 2, 8)
	Kit.lifeAt(env.ctx, b, "sparkle", 0, y + 4, 2, 4)
	table.insert(out, b)
end

-- An ice window (T.windows()): a translucent pane in the wall with a dark silhouette and light behind it.
function Grotto.window(
	env: Env,
	out: { Build },
	w: { x: number, z: number, w: number, h: number, yaw: number },
	name: string,
	shape: string
)
	local b = Kit.build(env, name, "glow", w.x, w.z, w.yaw)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	glowBox(bp, w.w, w.h, 0.2, 0, y + 2 + w.h / 2, -1.6, GLOW, 0.45)
	if shape == "mammoth" then
		bp:add(
			"ball",
			w.w * 0.6,
			w.h * 0.45,
			2,
			0,
			y + 2 + w.h * 0.45,
			-1.2,
			0,
			0,
			0,
			o({ c = "#2A3440", m = "SmoothPlastic" }, "detail", { col = false })
		)
		bp:beam(
			w.w * 0.25,
			y + 2 + w.h * 0.45,
			-1.1,
			w.w * 0.4,
			y + 3,
			-1.1,
			0.6,
			o({ c = "#2A3440", m = "SmoothPlastic" }, "detail", { col = false })
		)
	elseif shape == "fallen" then
		for k = -2, 2 do
			bp:box(
				1.6,
				5 + (k % 2) * 3,
				1,
				k * w.w / 5,
				y + 4.5,
				-1.2,
				o({ c = "#1E2630", m = "SmoothPlastic" }, "detail", { col = false })
			)
			bp:rbox(
				0.3,
				4,
				0.3,
				k * w.w / 5 + 0.8,
				y + 7,
				-1.15,
				0,
				0,
				30 * (if k % 2 == 0 then 1 else -1),
				o({ c = "#1E2630", m = "SmoothPlastic" }, "fine", { col = false })
			)
		end
	end
	bp:add(
		"ball",
		w.w + 2,
		w.h + 2,
		3,
		0,
		y + 2 + w.h / 2,
		-0.6,
		0,
		0,
		0,
		o(ICEGLASS, "detail", { col = false, t = 0.4 })
	)
	bp:light(0, y + 2 + w.h / 2, -3, GLOW, 24, 1.1, "crystal")
	table.insert(out, b)
end

local function mouth(env: Env, out: { Build })
	local r = env.T.rooms[1]
	-- fangs of icicles over the exit (-211, 0)
	local f = Kit.build(env, "IcicleFangs", "landmark", -214, 0, 90)
	local top = (Kit.ceil(env, -214, 0) or 20) - f.at.y
	for k = -4, 4 do
		local len = 3 + (4 - math.abs(k)) * 0.8
		f.bp:add("cyl", len, 1.2, 1.2, k * 2.2, top - len / 2, 0, 0, 0, 90, o(ICE, "detail", { col = false }))
	end
	table.insert(out, f)
	-- the trappers' abandoned camp
	local x, z = Kit.spot(env, r, math.rad(60), 6, 4)
	if x and z then
		local c = Kit.build(env, "TrappersCamp", "camp", x, z, 30)
		local bp = c.bp
		local y = Kit.gy(env, c, 0, 0)
		bp:rbox(6, 0.6, 2.4, 0, y + 1.1, 0, 0, 0, 80, o(WOOD, "shell", { q = false })) -- the sled on its side
		for _, s in { -1, 1 } do
			bp:rbox(6.4, 0.3, 0.3, 0, y + 0.2, s * 1.2, 0, 0, 80, o(WOOD, "fine", { col = false }))
		end
		bp:box(0.3, 4, 0.3, 4, y + 2, 2, o(WOOD, "detail", { col = false }))
		bp:box(0.3, 4, 0.3, 7, y + 2, 2, o(WOOD, "detail", { col = false }))
		bp:box(3, 3, 0.15, 5.5, y + 2.4, 2, o({ c = "#8A6A4A", m = "Fabric" }, "detail", { col = false })) -- the hide
		Kit.lantern(bp, -3, y, 2, "#FFB25A", 2, "detail")
		for k = 0, 2 do
			bp:add("cyl", 0.1, 1.4, 1.4, -2 + k * 1.6, y + 0.06, -3, 0, 0, 90, o(Kit.iron, "fine", { col = false })) -- snares
		end
		Kit.clear(env, x, z, 5)
		table.insert(out, c)
	end
	-- tracks of yeti and wolves leading in, hand prints in the ice
	local t = Kit.build(env, "SnowTracks", "traces", -180, 4, 0)
	for k = 0, 9 do
		local lx = -14 + k * 4
		t.bp:rbox(
			1.6,
			0.06,
			2.4,
			lx,
			Kit.gy(env, t, lx, (k % 2) * 2) + 0.05,
			(k % 2) * 2,
			0,
			90,
			0,
			o({ c = "#BFD0DC", m = "Snow" }, "fine", { col = false })
		)
		t.bp:rbox(
			0.7,
			0.06,
			0.9,
			lx + 1,
			Kit.gy(env, t, lx + 1, -6) + 0.05,
			-6 + (k % 2),
			0,
			90,
			0,
			o({ c = "#BFD0DC", m = "Snow" }, "fine", { col = false })
		)
	end
	table.insert(out, t)
	Kit.life(env.ctx, "snowGust", -205, 0.5, 0, 8)
	Kit.life(env.ctx, "drips", r.x, 16, r.z, 16)
end

local function icefalls(env: Env, out: { Build })
	local r = env.T.rooms[2]
	for i, f in env.T.icefalls() do
		if (f.x - r.x) ^ 2 + (f.z - r.z) ^ 2 < (r.r + 30) ^ 2 then
			Grotto.icefall(env, out, f, i)
		end
	end
	-- the yeti's ice hole (-90, -42): fish bones, hacked blocks, a frozen fish
	local h = Kit.build(env, "YetiIceHole", "traces", -86, -36, 0)
	local y = Kit.gy(env, h, 0, 0)
	for k = 0, 3 do
		h.bp:rbox(
			1.6,
			1.2,
			1.4,
			math.cos(k * 1.6) * 3,
			y + 0.6,
			math.sin(k * 1.6) * 3,
			10,
			k * 40,
			0,
			o(ICE, "detail", { col = false })
		)
	end
	h.bp:rbox(
		1.6,
		0.4,
		0.5,
		2,
		y + 0.2,
		1,
		0,
		30,
		0,
		o({ c = "#7A9AB0", m = "SmoothPlastic" }, "fine", { col = false })
	)
	Kit.bones(h.bp, -2, y, 2, 4)
	table.insert(out, h)
	Kit.life(env.ctx, "drips", r.x, 22, r.z, 30)
end

local function chimney(env: Env, out: { Build })
	local r = env.T.rooms[3]
	-- the shaft: icicles round its rim, snow in the moonbeam
	local s = Kit.build(env, "HarpyChimney", "traces", 20, 80, 0)
	local y = Kit.gy(env, s, 0, 0)
	for k = 0, 11 do
		local a = k * math.pi / 6
		local px, pz = math.cos(a) * 11.5, math.sin(a) * 11.5
		local top = env.T.ceiling(20 + px, 80 + pz)
		if top and top < 9000 then
			local len = 2 + (k % 3)
			s.bp:add("cyl", len, 1, 1, px, top - s.at.y - len / 2, pz, 0, 0, 90, o(ICE, "detail", { col = false }))
		end
	end
	s.bp:light(0, y + 20, 0, MOON, 40, 1.4, "crystal")
	Kit.lifeAt(env.ctx, s, "snowBeam", 0, y + 34, 0, 9)
	Kit.lifeAt(env.ctx, s, "dustBeam", 0, y + 12, 0, 9)
	table.insert(out, s)
	-- the harpies' nests on the ledges, the climbers' gear under them
	local n = Kit.build(env, "HarpyNests", "traces", r.x, r.z, 0)
	for k, p in { { -29, 59 }, { 68, 74 }, { 50, 95 } } do
		local f = env.T.floor(p[1], p[2])
		if f then
			local lx, lz = p[1] - r.x, p[2] - r.z
			local ny = f - n.at.y
			for m = 0, 7 do
				local a = m * math.pi / 4
				n.bp:rbox(
					0.4,
					0.4,
					3,
					lx + math.cos(a) * 2,
					ny + 0.4,
					lz + math.sin(a) * 2,
					10,
					math.deg(-a),
					0,
					o(WOOD, "detail", { col = false })
				)
			end
			glowBox(n.bp, 0.5, 0.5, 0.5, lx + 0.6, ny + 0.6, lz, HARPY, 0.1)
			for m = 0, 2 do
				n.bp:rbox(
					0.2,
					0.05,
					1.2,
					lx - 1 + m,
					ny + 0.5,
					lz + 1,
					0,
					m * 50,
					20,
					o({ c = "#C9B8A0", m = "Fabric" }, "fine", { col = false })
				)
			end
			-- a torn rope hanging down from the nest
			local fy = Kit.gy(env, n, lx * 0.85, lz * 0.85)
			n.bp:box(
				0.15,
				math.max(1, ny - fy - 1),
				0.15,
				lx * 0.9,
				(ny + fy) / 2,
				lz * 0.9,
				o(Kit.rope, "fine", { col = false })
			)
			if k == 2 then
				n.bp:rbox(0.25, 3, 0.25, lx * 0.8, fy + 1, lz * 0.8, 20, 0, 10, o(Kit.iron, "fine", { col = false })) -- the ice axe
				n.bp:rbox(
					1.6,
					1.2,
					1,
					lx * 0.8 + 2,
					fy + 0.5,
					lz * 0.8,
					0,
					30,
					70,
					o({ c = "#6A4A3A", m = "Fabric" }, "fine", { col = false })
				)
			end
		end
	end
	table.insert(out, n)
	Kit.life(env.ctx, "drips", r.x, 20, r.z, 24)
end

local function kingden(env: Env, out: { Build })
	local r = env.T.rooms[4]
	-- the throne of mammoth tusks and ice blocks on its dais (175, -14), the wall of trophies behind
	local t = Kit.build(env, "MountainThrone", "landmark", 175, -14, 270)
	local bp = t.bp
	local y = Kit.gy(env, t, 0, 0)
	bp:box(6, 3, 4, 0, y + 1.5, 0, o(ICE, "shell", { q = false }))
	bp:box(6, 6, 1.4, 0, y + 6, 1.8, o(ICE, "detail", { col = false }))
	for _, s in { -1, 1 } do
		bp:beam(s * 3.4, y + 1, -1, s * 4.6, y + 10, 2.4, 0.9, o(Kit.bone, "detail", { col = false }))
	end
	bp:box(5, 0.5, 3.6, 0, y + 3.2, -0.2, o(YETI, "fine", { col = false }))
	for k = -2, 2 do
		Kit.skull(bp, k * 2.4, y + 9 + (k % 2), 3.4, 1.1, 0)
	end
	bp:add("ball", 3, 2.4, 3, 6, y + 1.2, 3, 0, 0, 0, o({ c = "#6A7A8A", m = "Metal" }, "detail", { col = false })) -- a giant's helmet
	Kit.clear(env, 175, -14, 6)
	table.insert(out, t)
	-- the ice window with the frozen mammoth calf
	for _, w in env.T.windows() do
		if (w.x - r.x) ^ 2 + (w.z - r.z) ^ 2 < (r.r + 20) ^ 2 then
			Grotto.window(env, out, w, "MammothWindow", "mammoth")
		end
	end
	-- the larder, heaps of bones, the bed of furs
	for k, a in { 60, 120, 250 } do
		local x, z = Kit.spot(env, r, math.rad(a), 5, 3, false)
		if x and z then
			local p = Kit.build(env, `KingDen_{k}`, "traces", x, z, a)
			local py = Kit.gy(env, p, 0, 0)
			if k == 1 then
				for m = 0, 2 do
					p.bp:box(0.3, 6, 0.3, m * 2.4, py + 3, 0, o(ICE, "detail", { col = false }))
					p.bp:add(
						"ball",
						1.4,
						3,
						1.2,
						m * 2.4,
						py + 2.6,
						0,
						0,
						0,
						0,
						o({ c = "#8A5A44", m = "SmoothPlastic" }, "fine", { col = false })
					)
				end
			elseif k == 2 then
				Kit.bones(p.bp, 0, py, 0, 10)
			else
				p.bp:add("ball", 8, 1, 6, 0, py + 0.3, 0, 0, 0, 0, o(YETI, "detail", { col = false }))
			end
			table.insert(out, p)
		end
	end
	Kit.life(env.ctx, "drips", r.x, 20, r.z, 24)
end

local function wolfden(env: Env, out: { Build })
	local r = env.T.rooms[5]
	local b = Kit.build(env, "WolfBurrows", "traces", r.x, r.z, 0)
	for _, p in { { -22, -70 }, { 5, -104 }, { 52, -90 }, { 58, -62 } } do
		local f = env.T.floor(p[1], p[2])
		if f then
			b.bp:add(
				"ball",
				5,
				0.6,
				5,
				p[1] - r.x,
				f - b.at.y + 0.2,
				p[2] - r.z,
				0,
				0,
				0,
				o(FUR, "detail", { col = false })
			)
			Kit.bones(b.bp, p[1] - r.x + 1, f - b.at.y, p[2] - r.z, 3)
		end
	end
	b.bp:rbox(
		4,
		0.08,
		2.6,
		6,
		Kit.gy(env, b, 6, 6) + 0.05,
		6,
		0,
		30,
		0,
		o({ c = "#C8A050", m = "Fabric" }, "fine", { col = false })
	) -- the leopard skin
	table.insert(out, b)
	Kit.life(env.ctx, "drips", r.x, 12, r.z, 18)
end

function Grotto.all(env: Env, out: { Build })
	mouth(env, out)
	icefalls(env, out)
	chimney(env, out)
	kingden(env, out)
	wolfden(env, out)
end

return Grotto
