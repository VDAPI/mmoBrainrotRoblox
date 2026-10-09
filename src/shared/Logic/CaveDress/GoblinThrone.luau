--!strict
-- Grimrok's Chamber (boss 20) dressing (S48), round the flat arena (the contract: nothing collidable within 50 studs
-- of the fight's centre (0, -10), the entry lane |x| < 14 free):
--   * 10 war totems with skulls and torches on a ring of 56 round (0, -10) every 36 degrees (only the post collides),
--     none on the axis of the entry,
--   * the throne niche in the north: a dais of skull steps, a throne of scrap and bone under a giant bear skull,
--     banners, fire baskets, trampled earth,
--   * galleries east and west (unreachable ledges +12): war drums, banners, torches,
--   * heaps of skulls, trophies and broken shields at the walls' feet. Pure.

local Kit = require("./Kit")

local o = Kit.o

local GoblinThrone = {}

type Build = Kit.Build
type Env = Kit.Env

local CX, CZ = 0, -10

local function totems(env: Env, out: { Build })
	for i = 0, 9 do
		local a = i * math.pi * 2 / 10 + math.pi / 2 + math.pi / 10
		local x, z = CX + math.cos(a) * 56, CZ + math.sin(a) * 56
		if not (math.abs(x) < 14 and z > CZ) then
			local b = Kit.build(env, `WarTotem_{i}`, "landmark", x, z, math.deg(math.atan2(-(x - CX), -(z - CZ))))
			local bp = b.bp
			local y = Kit.gy(env, b, 0, 0)
			bp:box(1.4, 12, 1.4, 0, y + 6, 0, o(Kit.oldWood, "shell", { q = false }))
			for k = 0, 2 do
				Kit.skull(bp, 0, y + 7 + k * 1.8, -0.8, 1.6, 0)
			end
			for _, s in { -1, 1 } do
				bp:beam(0, y + 11, 0, s * 2, y + 12.6, 0, 0.35, o(Kit.bone, "detail", { col = false }))
			end
			bp:box(2, 3, 0.1, 0, y + 4.6, -0.75, o(Kit.red, "fine", { col = false }))
			Kit.fire(bp, 0, y + 12.4, 0, 1, Kit.FIRE, "detail")
			table.insert(out, b)
		end
	end
end

local function throne(env: Env, out: { Build })
	local b = Kit.build(env, "GrimrokThrone", "landmark", 0, -106, 0)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	-- skull steps up the dais (the terrace is +4)
	for k = 0, 3 do
		for m = -3, 3 do
			Kit.skull(bp, m * 1.4, Kit.gy(env, b, m * 1.4, 10 - k * 1.4) + 0.1, 10 - k * 1.4, 1.1, m * 20)
		end
	end
	-- the throne of scrap and bone under a giant bear skull
	bp:box(6, 3, 5, 0, y + 1.5, 0, o({ c = "#5A4E44", m = "CorrodedMetal" }, "shell", { q = false }))
	bp:box(6, 9, 1.4, 0, y + 6, 2.2, o({ c = "#5A4E44", m = "CorrodedMetal" }, "shell", { q = false }))
	for _, s in { -1, 1 } do
		bp:box(1, 4, 4, s * 3.2, y + 3.4, 0, o(Kit.bone, "detail", { col = false }))
		bp:beam(s * 2, y + 10, 2, s * 4.6, y + 13, 2.6, 0.6, o(Kit.bone, "detail", { col = false }))
	end
	bp:add("ball", 5, 4, 6, 0, y + 12, 2.4, 0, 0, 0, o(Kit.oldBone, "detail", { col = false }))
	for _, s in { -1, 1 } do
		bp:box(1.2, 1, 0.3, s * 1.2, y + 12.4, -0.4, o(Kit.dark, "fine", { col = false }))
		Kit.banner(bp, s * 9, y, 3, 12, Kit.red)
		bp:box(0.6, 3, 0.6, s * 6, y + 1.4, -4, o(Kit.iron, "detail", { col = false }))
		Kit.fire(bp, s * 6, y + 3.3, -4, 1.4, Kit.FIRE, "detail")
	end
	bp:add("cyl", 0.1, 16, 16, 0, y + 0.06, 6, 0, 0, 90, o({ c = "#5A4A38", m = "Ground" }, "fine", { col = false }))
	table.insert(out, b)
end

local function galleries(env: Env, out: { Build })
	for _, s in { -1, 1 } do
		local x = s * 100
		local b =
			Kit.build(env, if s < 0 then "GalleryWest" else "GalleryEast", "landmark", x, CZ, if s < 0 then 270 else 90)
		local bp = b.bp
		local y = Kit.gy(env, b, 0, 0)
		for k = -1, 1 do
			bp:add("cyl", 3.4, 5, 5, k * 6, y + 1.7, 2, 0, 0, 90, o(Kit.hide, "shell", { q = false }))
			Kit.banner(bp, k * 6 + 3, y, 6, 10, Kit.red)
		end
		for k = -1, 1, 2 do
			Kit.torch(bp, k * 10, y, -2, Kit.FIRE)
		end
		table.insert(out, b)
	end
end

local function walls(env: Env, out: { Build })
	local b = Kit.build(env, "ChamberTrophies", "traces", CX, CZ, 0)
	local bp = b.bp
	for k = 0, 11 do
		local a = k * math.pi / 6 + 0.25
		local lx, lz = math.cos(a) * 80, math.sin(a) * 80
		if env.T.floor(CX + lx, CZ + lz) and not (math.abs(lx) < 14 and lz > 0) then
			local y = Kit.gy(env, b, lx, lz)
			for m = 0, 3 do
				Kit.skull(bp, lx + (m % 2) * 1.2, y + math.floor(m / 2) * 1, lz + m * 0.5, 1.2, m * 50)
			end
			bp:add(
				"cyl",
				0.3,
				2.6,
				2.6,
				lx * 0.98,
				y + 1,
				lz * 0.98,
				70,
				k * 30,
				0,
				o(Kit.red, "fine", { col = false })
			)
		end
	end
	table.insert(out, b)
	Kit.life(env.ctx, "drips", CX, 30, CZ, 40)
end

function GoblinThrone.all(env: Env, out: { Build })
	totems(env, out)
	throne(env, out)
	galleries(env, out)
	walls(env, out)
end

return GoblinThrone
