--!strict
-- Wyvern Lair (56-63) dressing (S50): a volcanic cave open to the sky under the Wyvern Spires.
--   1 the Scorched Maw: a fan of soot on the vault, deep claw furrows, a pile of bones with a cracked giant egg, a
--     melted shield and a charred explorer's pack, sand blown in with scorpion tracks,
--   2 the Imps' Chimneys: the pool of lava in the niche the imps tend, nests of glowing charcoal in the hollows, hand
--     prints in the soot, scratched flame signs, skull lanterns with embers inside, a hissing fumarole, heaps of
--     trinkets (melted coins, buckles) on ledges,
--   3 the Sand Nests: the stream of sand pouring through the hole onto the cone, sand on the floor, scorpion burrows
--     in a ring by the walls, shed carapaces, dried webbed victims, a half-buried wyvern skeleton, the fumarole where
--     imps warm themselves,
--   4 the Wyvern Roosts: the great hole in the east wall with a hot beam, ash and smoke; nests of charred branches,
--     wagon wheels and bones on the unreachable ledges, smaller eggs, fans of soot, basalt pillars scored by claws, a
--     carpet of bones by the walls, a torn caravan tarp hanging from a ledge,
--   5 the Larder: carcasses of caravan animals with hide, a smashed wagon, slit bales of cloth, scattered jars and
--     coins, a shed wyvern skin on the rocks, the red half-light of the glowing crack,
--   6 the Queen's Nest ("wow"): the huge nest on the basalt mound ringed with lava, woven of charred trunks, wagon
--     wheels and bones, five glowing eggs (one with a hatchling's claw sticking out), the great chimney with heat haze
--     going up and ash coming down, a red glow on the vault, spilled treasure (coins, goblets, a crown), scales. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Lair = {}

type Build = Kit.Build
type Env = Kit.Env
type BP = Kit.BP

local EMBER = "#FF7A1A"
local EGG = "#FFB060"
local SOOT = { c = "#141012", m = "Slate" }
local CHAR = { c = "#1F1B19", m = "Wood" }
local SAND = { c = "#C2A878", m = "Sand" }
local SCALE = { c = "#6B2E25", m = "SmoothPlastic" }
local GOLD = { c = "#C9A45C", m = "Metal" }
local SHELL = { c = "#C29A5B", m = "SmoothPlastic" }

local function glowBall(
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
	bp:add("ball", sx, sy, sz, x, y, z, 0, 0, 0, {
		c = color,
		m = "Neon",
		lod = "detail",
		col = false,
		q = false,
		t = 0.15,
		tag = tag or "glow",
		jitter = 0,
		fxColor = color,
	})
end

-- A nest of charred branches, wheels and bones (radius s*4) with `eggs` eggs.
local function nest(bp: BP, x: number, y: number, z: number, s: number, eggs: number, glow: boolean)
	for k = 0, 9 do
		local a = k * math.pi / 5
		bp:rbox(
			0.5 * s,
			0.5 * s,
			4 * s,
			x + math.cos(a) * 3 * s,
			y + 0.5 * s,
			z + math.sin(a) * 3 * s,
			10,
			math.deg(-a),
			0,
			o(CHAR, "detail", { col = false })
		)
	end
	bp:add("cyl", 0.4 * s, 3 * s, 3 * s, x + 3 * s, y + 1 * s, z, 70, 20, 0, o(Kit.wood, "fine", { col = false })) -- a wheel
	for k = 1, eggs do
		local a = k * 2.4
		local d = s * (0.8 + (k % 2))
		local ex, ez = x + math.cos(a) * d, z + math.sin(a) * d
		if glow then
			glowBall(bp, 1.6 * s, 2.2 * s, 1.6 * s, ex, y + 1.4 * s, ez, EGG, "glow")
		else
			bp:add(
				"ball",
				1.2 * s,
				1.6 * s,
				1.2 * s,
				ex,
				y + 1 * s,
				ez,
				0,
				0,
				0,
				o({ c = "#C8B89A", m = "SmoothPlastic" }, "fine", { col = false })
			)
		end
	end
end

local function maw(env: Env, out: { Build })
	local r = env.T.rooms[1]
	local b = Kit.build(env, "ScorchedMaw", "traces", r.x, r.z, 0)
	local bp = b.bp
	local top = (Kit.ceil(env, r.x - 14, r.z) or 20) - b.at.y
	bp:rbox(24, 0.3, 14, -14, top - 0.4, 0, 0, 0, 0, o(SOOT, "detail", { col = false }))
	-- claw furrows on both walls
	for _, side in { -1, 1 } do
		local x, z = Kit.wallSpot(env, r, math.rad(if side == 1 then 80 else 280), 1)
		if x and z then
			bp:push(x - r.x, Kit.gy(env, b, x - r.x, z - r.z) + 4, z - r.z, 0, if side == 1 then 0 else 180, 0)
			Kit.claws(bp, 0, 0, 0, 3)
			bp:pop()
		end
	end
	table.insert(out, b)
	local x, z = Kit.spot(env, r, math.rad(140), 6, 3, false)
	if x and z then
		local p = Kit.build(env, "CrackedEgg", "traces", x, z, 20)
		local y = Kit.gy(env, p, 0, 0)
		Kit.bones(p.bp, 0, y, 0, 9)
		for k = 0, 2 do
			p.bp:rbox(
				2.4,
				3,
				0.3,
				math.cos(k * 2.1) * 1.4,
				y + 1.2,
				math.sin(k * 2.1) * 1.4,
				10,
				k * 120,
				20,
				o({ c = "#B8A890", m = "SmoothPlastic" }, "detail", { col = false })
			)
		end
		p.bp:add(
			"cyl",
			0.3,
			3,
			3,
			3,
			y + 0.15,
			-2,
			0,
			0,
			90,
			o({ c = "#6A6060", m = "Metal" }, "fine", { col = false })
		) -- the melted shield
		p.bp:box(1.6, 1.4, 1, -3, y + 0.7, 2, o(CHAR, "fine", { col = false })) -- the charred pack
		table.insert(out, p)
	end
	local s = Kit.build(env, "BlownSand", "traces", -198, 6, 0)
	local sy = Kit.gy(env, s, 0, 0)
	s.bp:add("ball", 14, 0.8, 8, 0, sy + 0.1, 0, 0, 20, 0, o(SAND, "detail", { col = false }))
	for k = 0, 5 do
		s.bp:box(
			0.3,
			0.06,
			0.5,
			-4 + k * 1.6,
			sy + 0.5,
			(k % 2) * 0.8,
			o({ c = "#8A7650", m = "Sand" }, "fine", { col = false })
		)
	end
	table.insert(out, s)
	Kit.life(env.ctx, "dustBeam", -205, 6, 0, 8)
	Kit.life(env.ctx, "drips", r.x, 14, r.z, 16)
end

local function chimneys(env: Env, out: { Build })
	local r = env.T.rooms[2]
	-- nests of glowing charcoal in the hollows, skull lanterns, hand prints, trinkets
	for k = 0, 4 do
		local a = k * 1.25 + 0.5
		local x, z = Kit.wallSpot(env, r, a, 3)
		if x and z and Kit.free(env, x, z, 1.5, false) then
			local b = Kit.build(env, `ImpNest_{k}`, "ember", x, z, math.deg(-a))
			local y = Kit.gy(env, b, 0, 0)
			b.bp:add("ball", 3, 0.8, 3, 0, y + 0.3, 0, 0, 0, 0, o(CHAR, "detail", { col = false }))
			for t = 0, 4 do
				b.bp:box(
					0.5,
					0.4,
					0.5,
					math.cos(t * 1.3) * 0.8,
					y + 0.7,
					math.sin(t * 1.3) * 0.8,
					Kit.lavaOpts(EMBER, 0.1, "ember")
				)
			end
			if k % 2 == 0 then
				Kit.skull(b.bp, 1.6, y + 0.6, 0, 1, 0)
				b.bp:box(0.4, 0.4, 0.4, 1.6, y + 1, 0, Kit.lavaOpts(EMBER, 0.2, "ember"))
				b.bp:light(1.6, y + 1.6, 0, EMBER, 12, 0.8, "fire")
			end
			for t = 0, 2 do
				b.bp:add("cyl", 0.1, 0.5, 0.5, -1.4 + t * 0.4, y + 0.6, 1, 0, 0, 90, o(GOLD, "fine", { col = false }))
			end
			Kit.lifeAt(env.ctx, b, "embers", 0, 1, 0, 1.5)
			table.insert(out, b)
		end
	end
	local w = Kit.build(env, "SootPrints", "traces", r.x, r.z, 0)
	for k = 0, 5 do
		local a = k * 1.05 + 0.2
		local x, z = Kit.wallSpot(env, r, a, 0)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			w.bp:rbox(
				1.2,
				1.4,
				0.1,
				lx,
				Kit.gy(env, w, lx, lz) + 3 + (k % 2),
				lz,
				0,
				math.deg(-a) + 90,
				0,
				o(SOOT, "fine", { col = false })
			)
		end
	end
	table.insert(out, w)
	Kit.life(env.ctx, "smoke", -46, 14, -89, 4)
	Kit.life(env.ctx, "drips", r.x, 16, r.z, 20)
end

local function sands(env: Env, out: { Build })
	local r = env.T.rooms[3]
	-- the stream of sand pouring through the hole (13, 116) onto the cone
	local s = Kit.build(env, "SandFall", "landmark", 13, 118, 0)
	local y = Kit.gy(env, s, 0, 0)
	s.bp:add("cyl", 26, 1.4, 1.4, 0, y + 13, 0, 0, 0, 90, o(SAND, "detail", { col = false, t = 0.35 }))
	Kit.lifeAt(env.ctx, s, "sandfall", 0, y + 26, 0, 2)
	Kit.lifeAt(env.ctx, s, "dustBeam", 0, y + 10, 0, 8)
	table.insert(out, s)
	-- scorpion burrows in a ring by the walls, shed carapaces, webbed victims
	local b = Kit.build(env, "ScorpionBurrows", "traces", r.x, r.z, 0)
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.3
		local x, z = Kit.wallSpot(env, r, a, 4)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local fy = Kit.gy(env, b, lx, lz)
			b.bp:add("ball", 3.4, 1.2, 3.4, lx, fy + 0.2, lz, 0, 0, 0, o(SAND, "detail", { col = false }))
			b.bp:add("cyl", 0.3, 1.6, 1.6, lx, fy + 0.85, lz, 0, 0, 90, o(Kit.dark, "fine", { col = false }))
			if k % 3 == 0 then
				b.bp:rbox(
					2,
					0.6,
					3,
					lx * 0.9,
					Kit.gy(env, b, lx * 0.9, lz * 0.9) + 0.3,
					lz * 0.9,
					0,
					k * 40,
					0,
					o(SHELL, "fine", { col = false, t = 0.3 })
				)
			end
		end
	end
	table.insert(out, b)
	-- the half-buried wyvern skeleton in the west part
	local x, z = Kit.spot(env, r, math.rad(190), 10, 6, false)
	if x and z then
		local k = Kit.build(env, "WyvernSkeleton", "landmark", x, z, 30)
		local ky = Kit.gy(env, k, 0, 0)
		for t = 0, 7 do
			k.bp:beam(-8 + t * 2, ky + 0.4, 0, -8 + t * 2, ky + 2.6, 1.8, 0.25, o(Kit.bone, "detail", { col = false }))
			k.bp:beam(-8 + t * 2, ky + 0.4, 0, -8 + t * 2, ky + 2.6, -1.8, 0.25, o(Kit.bone, "detail", { col = false }))
		end
		k.bp:beam(-10, ky + 0.6, 0, 8, ky + 0.8, 0, 0.5, o(Kit.bone, "detail", { col = false }))
		k.bp:box(3, 1.6, 2, 10, ky + 1, 0, o(Kit.bone, "detail", { col = false }))
		k.bp:beam(-2, ky + 1, 0, -6, ky + 8, 8, 0.3, o(Kit.bone, "fine", { col = false })) -- a wing bone
		k.bp:add("ball", 10, 1, 6, 0, ky + 0.2, 0, 0, 0, 0, o(SAND, "detail", { col = false }))
		table.insert(out, k)
	end
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 24)
end

local function roosts(env: Env, out: { Build })
	local r = env.T.rooms[4]
	-- the great hole in the east wall: the beam, ash, smoke
	Kit.life(env.ctx, "dustBeam", 174, 16, -14, 12)
	Kit.life(env.ctx, "ashBeam", 174, 34, -14, 12)
	Kit.life(env.ctx, "smokeColumn", 174, 24, -14, 4)
	-- nests on the unreachable ledges (r ~50 from the centre)
	local n = Kit.build(env, "WyvernNests", "traces", r.x, r.z, 0)
	for k = 0, 5 do
		local deg = k * 60 + 20
		if not (deg > 120 and deg < 170) and not (deg > 250 and deg < 300) then
			local a = math.rad(deg)
			local lx, lz = math.cos(a) * 50, math.sin(a) * 50
			local f = env.T.floor(r.x + lx, r.z + lz)
			if f then
				nest(n.bp, lx, f - n.at.y, lz, 1, 3, false)
			end
		end
	end
	-- soot fans on the floor, the carpet of bones by the walls, the tarp hanging from a ledge
	for k = 0, 3 do
		local a = k * 1.6
		local lx, lz = math.cos(a) * 30, math.sin(a) * 30
		n.bp:rbox(
			10,
			0.06,
			6,
			lx,
			Kit.gy(env, n, lx, lz) + 0.04,
			lz,
			0,
			math.deg(a),
			0,
			o(SOOT, "fine", { col = false })
		)
		Kit.bones(n.bp, lx * 1.3, 0, lz * 1.3, 6, function(x, z)
			return Kit.gy(env, n, x, z)
		end)
	end
	local tx, tz = math.cos(math.rad(80)) * 46, math.sin(math.rad(80)) * 46
	local tf = env.T.floor(r.x + tx, r.z + tz)
	if tf then
		n.bp:rbox(
			6,
			7,
			0.15,
			tx,
			tf - n.at.y - 2,
			tz,
			6,
			80,
			0,
			o({ c = "#B8A880", m = "Fabric" }, "detail", { col = false })
		)
	end
	table.insert(out, n)
	-- basalt pillars scored by claws (outside the core)
	for k, a in { 30, 200, 330 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 2.5)
		if x and z then
			local p = Kit.build(env, `ClawPillar_{k}`, "landmark", x, z, a)
			local y = Kit.gy(env, p, 0, 0)
			p.bp:add("cyl", 14, 3.6, 3.6, 0, y + 7, 0, 0, 0, 90, o(Kit.basalt, "shell", { q = false }))
			for t = 0, 2 do
				p.bp:rbox(0.2, 4, 0.3, -0.6 + t * 0.6, y + 6, -1.8, 0, 0, 12, o(SOOT, "fine", { col = false }))
			end
			Kit.clear(env, x, z, 3)
			table.insert(out, p)
		end
	end
	Kit.life(env.ctx, "drips", r.x, 22, r.z, 20)
end

local function larder(env: Env, out: { Build })
	local r = env.T.rooms[5]
	for k, pr in
		{
			{ a = 30, kind = "wagon" },
			{ a = 110, kind = "carcass" },
			{ a = 250, kind = "bales" },
			{ a = 330, kind = "skin" },
		}
	do
		local a = math.rad(pr.a)
		local x, z = Kit.spot(env, r, a, 6, 3, pr.kind == "wagon")
		if x and z then
			local b = Kit.build(env, `Larder_{k}`, "traces", x, z, pr.a)
			local y = Kit.gy(env, b, 0, 0)
			local kind = pr.kind
			if kind == "wagon" then
				b.bp:rbox(5, 1.4, 9, 0, y + 1.2, 0, 0, 0, 14, o(Kit.wood, "shell", { q = false }))
				b.bp:add("cyl", 0.5, 4, 4, 2.8, y + 2, 3, 0, 0, 0, o(Kit.wood, "detail", { col = false }))
				b.bp:add("cyl", 0.5, 4, 4, -4, y + 0.3, -2, 0, 30, 90, o(Kit.wood, "detail", { col = false }))
				for t = 0, 3 do
					b.bp:add(
						"ball",
						1,
						1.4,
						1,
						-2 + t,
						y + 0.5,
						4 + (t % 2),
						0,
						0,
						80,
						o({ c = "#8A6A4A", m = "SmoothPlastic" }, "fine", { col = false })
					)
				end
			elseif kind == "carcass" then
				b.bp:add(
					"ball",
					6,
					2.4,
					3,
					0,
					y + 0.8,
					0,
					0,
					20,
					0,
					o({ c = "#6A4A32", m = "Fabric" }, "detail", { col = false })
				)
				for t = 0, 4 do
					b.bp:beam(-2 + t, y + 1.4, 0, -2 + t, y + 0.2, 2.2, 0.2, o(Kit.bone, "fine", { col = false }))
				end
			elseif kind == "bales" then
				for t = 0, 2 do
					b.bp:rbox(
						2.4,
						1.6,
						1.6,
						t * 2.6,
						y + 0.8,
						(t % 2) * 1.2,
						0,
						t * 30,
						0,
						o({ c = "#8A3A5A", m = "Fabric" }, "detail", { col = false })
					)
				end
				for t = 0, 4 do
					b.bp:add(
						"cyl",
						0.08,
						0.4,
						0.4,
						-2 + t * 0.5,
						y + 0.05,
						-2,
						0,
						0,
						90,
						o(GOLD, "fine", { col = false })
					)
				end
			else
				b.bp:rbox(7, 0.2, 4, 0, y + 1.2, 0, 10, 0, 20, o(SCALE, "detail", { col = false }))
			end
			table.insert(out, b)
		end
	end
	Kit.life(env.ctx, "drips", r.x, 14, r.z, 20)
end

local function queen(env: Env, out: { Build })
	-- the huge nest on the mound (202, -162) inside the ring of lava: five glowing eggs, one with a claw
	local b = Kit.build(env, "QueenNest", "landmark", 202, -162, 0)
	local y = Kit.gy(env, b, 0, 0)
	nest(b.bp, 0, y, 0, 2, 5, true)
	b.bp:beam(
		1.6,
		y + 3.4,
		2,
		2.4,
		y + 4.6,
		2.6,
		0.3,
		o({ c = "#2A1A14", m = "SmoothPlastic" }, "fine", { col = false })
	) -- the claw
	b.bp:light(0, y + 4, 0, EGG, 30, 1.6, "crystal")
	Kit.lifeAt(env.ctx, b, "haze", 0, 2, 0, 8)
	Kit.lifeAt(env.ctx, b, "ashBeam", 0, 30, 0, 8)
	table.insert(out, b)
	-- the spilled treasure, the scales, the scorched floor
	local r = env.T.rooms[6]
	local t = Kit.build(env, "QueenTreasure", "traces", 180, -160, 0)
	local ty = Kit.gy(env, t, 0, 0)
	for k = 0, 11 do
		local a = k * 2.4
		local d = 1 + (k % 4)
		t.bp:add(
			"cyl",
			0.1,
			0.6,
			0.6,
			math.cos(a) * d,
			ty + 0.06,
			math.sin(a) * d,
			0,
			0,
			90,
			o(GOLD, "fine", { col = false })
		)
	end
	t.bp:add("cyl", 1, 0.8, 0.8, 2, ty + 0.5, -1, 0, 0, 90, o(GOLD, "fine", { col = false }))
	for k = -2, 2 do
		t.bp:box(0.2, 0.6, 0.2, -2 + k * 0.3, ty + 0.4, 2, o(GOLD, "fine", { col = false })) -- the crown
	end
	for k = 0, 4 do
		t.bp:rbox(
			0.8,
			0.1,
			0.8,
			-4 + k * 2,
			ty + 0.06,
			-3 + (k % 2) * 2,
			0,
			k * 40,
			0,
			o(SCALE, "fine", { col = false })
		)
	end
	table.insert(out, t)
	Kit.life(env.ctx, "embers", r.x + 20, -4, r.z, 10)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 20)
end

function Lair.all(env: Env, out: { Build })
	maw(env, out)
	chimneys(env, out)
	sands(env, out)
	roosts(env, out)
	larder(env, out)
	queen(env, out)
end

return Lair
