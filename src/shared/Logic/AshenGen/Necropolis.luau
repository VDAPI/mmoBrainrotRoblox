--!strict
-- Desert Tombs (66–70) (S46): the necropolis on its terrace.
--   * the stepped pyramid (the landmark) with an entrance glowing cold turquoise (#6BE0FF) and a stair up its face,
--   * the procession road through an avenue of guardian statues with basilisk heads, obelisks,
--   * two sunken courtyards with sarcophagi, canopic urns and altars (faint lights and turquoise wisps at night),
--   * tombs carved in the scarp under the dunes: rows of niches and doorways, linen strips in the wind. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Necropolis = {}

type Build = Kit.Build

local STONE = { c = "#B8A07A", m = "Sandstone" }
local DARK = { c = "#8A7656", m = "Sandstone" }

local function turquoise(lod: string, t: number?): any
	return { c = Props.TURQUOISE, m = "Neon", lod = lod, col = false, q = false, t = t, tag = "glow", jitter = 0 }
end

local function pyramid(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "pyramid", "pyramid", 46)
	local bp = b.bp
	local size, step = 54, 5
	for k = 0, 5 do
		local w = size - k * 9
		bp:box(
			w,
			step,
			w,
			0,
			k * step + step / 2 - 0.6,
			0,
			o(if k % 2 == 0 then STONE else DARK, "shell", { q = true })
		)
	end
	-- the shrine on top
	bp:box(10, 6, 10, 0, 6 * step + 2.4, 0, o(STONE, "shell", { q = false }))
	bp:add("wedge", 10, 3, 5, 0, 6 * step + 6.9, -2.5, 0, 0, 0, o(DARK, "detail", { col = false }))
	bp:add("wedge", 10, 3, 5, 0, 6 * step + 6.9, 2.5, 0, 180, 0, o(DARK, "detail", { col = false }))
	-- the entrance on the north face: a dark recess with a turquoise glow, guardians and obelisks on both sides
	bp:box(9, 12, 6, 0, 5.4, -size / 2 - 1, o(DARK, "shell", { q = true }))
	bp:box(6, 8, 0.4, 0, 4, -size / 2 - 4.1, turquoise("shell", 0.1))
	bp:box(10, 1.6, 7, 0, 12.2, -size / 2 - 1, o(Props.gold, "detail", { col = false }))
	bp:light(0, 5, -size / 2 - 7, Props.TURQUOISE, 34, 1.4, "glow")
	for _, side in { -1, 1 } do
		Props.obelisk(bp, side * 11, 0, -size / 2 - 8, 14, Props.paleStone)
	end
	-- a stair up the middle of the north face (detail)
	for k = 0, 11 do
		bp:box(6, 2.5, 2.4, 0, 6 + k * 2.5, -size / 2 + 5 + k * 1.9, o(DARK, "detail", { col = false }))
	end
	Kit.lifeAt(ctx, b, "wisp", 0, 4, -size / 2 - 10, 10)
	Kit.rect(ctx, "pyramid", b.at.x, b.at.z, size, size, 0)
	table.insert(out, b)
end

-- Guardian with a basilisk's head (olive scales, yellow eyes).
local function guardian(bp: Kit.BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(3.6, 1.6, 3.6, 0, 0.5, 0, o(DARK, "shell", { q = false }))
	bp:box(2.6, 6, 2, 0, 4.2, 0, o(STONE, "shell", { q = false }))
	bp:box(3.4, 1.2, 2.2, 0, 7.4, 0, o(STONE, "detail", { col = false }))
	bp:add("ball", 2.2, 2, 2.6, 0, 8.8, -0.4, 0, 0, 0, o({ c = "#5A6B3A", m = "Slate" }, "detail", { col = false }))
	bp:box(1.4, 1, 2.4, 0, 8.4, -2, o({ c = "#5A6B3A", m = "Slate" }, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:box(0.4, 0.3, 0.2, side * 0.6, 9.2, -1.7, o({ c = "#E8E25A", m = "Neon" }, "fine"))
		bp:rbox(0.4, 0.4, 1.6, side * 0.8, 9.8, 0.4, 30, side * 20, 0, o({ c = "#5A6B3A", m = "Slate" }, "fine"))
	end
	bp:box(0.4, 7, 0.4, 1.6, 4.4, -1, o(Props.gold, "fine"))
	bp:pop()
end

local function procession(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local x, z = 603, 66
	Env.clear(env, x, z, 8)
	for lz = -70, 66, 14 do
		Env.clear(env, x, z + lz, 16)
	end
	local b = Kit.build(ctx, "ProcessionAvenue", "statue", x, z, 0)
	local bp = b.bp
	for k = -2, 2 do
		local lz = k * 22
		for _, side in { -1, 1 } do
			local lx = side * 13
			local wx, wz = x + lx, z + lz
			Env.clear(env, wx, wz, 5)
			guardian(bp, lx, Kit.gy(ctx, b, lx, lz) - 0.3, lz, if side == 1 then 270 else 90)
		end
	end
	for _, side in { -1, 1 } do
		Props.obelisk(bp, side * 14, Kit.gy(ctx, b, side * 14, -60), -60, 16, Props.paleStone)
	end
	-- linen strips tied to the guardians' staffs
	for k = 1, 3 do
		bp:box(0.1, 2.4, 0.8, 14.6, 6, -40 + k * 22, o(Props.linen, "fine", { tag = "flag" }))
	end
	table.insert(out, b)
end

local function courtyard(env: Env.Env, out: { Build }, name: string)
	local ctx = env.ctx
	local b = Env.atSite(env, name, "tomb", 30)
	local bp = b.bp
	local function gy(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	local list: { { any } } = { { -9, 2, 0, false }, { 0, 6, 90, true }, { 9, 0, 10, true } }
	for k, p in list do
		Props.sarcophagus(
			bp,
			p[1] :: number,
			gy(p[1] :: number, p[2] :: number),
			p[2] :: number,
			p[3] :: number,
			p[4] :: boolean
		)
		if k == 2 then
			Props.coins(bp, 2, gy(2, 12), 12, 6)
		end
	end
	-- the altar with urns and a cold flame
	bp:box(6, 2.4, 3, 0, gy(0, -8) + 1.2, -8, o(DARK, "shell", { q = false }))
	Kit.candle(bp, -2, gy(0, -8) + 2.4, -8, 0.9, Props.TURQUOISE)
	Kit.candle(bp, 2, gy(0, -8) + 2.4, -8, 0.7, Props.TURQUOISE)
	for k = -2, 2 do
		Props.urn(bp, k * 2.4, gy(k * 2.4, -12), -12)
	end
	-- low walls round the courtyard's floor, broken here and there
	for k = 0, 11 do
		if k % 4 ~= 1 then
			local a = k * math.pi / 6
			local lx, lz = math.cos(a) * 20, math.sin(a) * 19
			bp:rbox(
				9,
				3,
				1.4,
				lx,
				gy(lx, lz) + 1,
				lz,
				0,
				math.deg(-a) + 90,
				0,
				o(STONE, if k % 2 == 0 then "shell" else "detail", { q = false })
			)
		end
	end
	bp:light(0, gy(0, 0) + 6, 0, Props.TURQUOISE, 24, 0.7, "glow")
	Kit.lifeAt(ctx, b, "wisp", 0, gy(0, 0) + 3, 0, 14)
	Kit.lifeAt(ctx, b, "wisp", 6, gy(6, 6) + 3, 6, 10)
	table.insert(out, b)
end

-- Tombs carved in the scarp under the dunes (the facades face north, into the necropolis).
local function rockTombs(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for g, cx in { 520, 664 } do
		local fz = 270
		Env.clear(env, cx, fz, 30)
		local b = Kit.buildAt(if g == 1 then "rockTombs" else `RockTombs_{g}`, "tomb", cx, env.T.height(cx, fz), fz, 0)
		local bp = b.bp
		for k = -2, 2 do
			local lx = k * 11
			bp:box(9, 12, 3, lx, 5.4, 11, o(STONE, "shell", { q = true }))
			bp:box(4, 7, 0.6, lx, 3.4, 9.3, o(Kit.dark, "detail", { col = false }))
			bp:box(6, 1.2, 1.6, lx, 7.6, 9.4, o(DARK, "detail", { col = false }))
			for _, side in { -1, 1 } do
				bp:box(1.2, 7, 1.2, lx + side * 3.2, 3.4, 9.2, o(DARK, "detail", { col = false }))
			end
			-- niches over the doorways, one with a mummy's linen hanging out
			for n = -1, 1 do
				bp:box(1.6, 2.4, 0.6, lx + n * 2.6, 10.4, 9.4, o(Kit.dark, "fine"))
			end
			if k % 2 == 0 then
				bp:box(0.8, 2.6, 0.1, lx + 1.2, 2.6, 9, o(Props.linen, "fine", { tag = "flag" }))
			end
		end
		Kit.rect(ctx, "building", cx, fz + 10, 56, 4, 0)
		table.insert(out, b)
	end
end

function Necropolis.all(env: Env.Env, out: { Build })
	pyramid(env, out)
	procession(env, out)
	courtyard(env, out, "courtyardWest")
	courtyard(env, out, "courtyardEast")
	rockTombs(env, out)
	local d = env.T.shape.plateaus[2]
	local poly = assert(d.poly, "poly")
	Kit.line(env.ctx, "cliff", { poly[3], poly[4], poly[5], poly[6], poly[7], poly[8], poly[9], poly[10] }, 6)
end

return Necropolis
