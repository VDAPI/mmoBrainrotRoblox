--!strict
-- W15 (bor.md A8): the Duskwood's own dead trees and undergrowth, drawn from parts until the kit has models for them
-- (the kit slots keep the shared keys, so a model under "tree:blackDead" / "under:fern" in Data/Kit takes their
-- place by itself):
--   * duskDead: a dead rotting tree: the black trunk with a snapped top, a dark hollow at its foot, root flares,
--     bare clawing branches, beards of grey moss, pale bracket fungi and ivy (the server keeps the same two shell
--     pieces as WorldGen/Flora's blackDead: the trunk and the leaning main branch),
--   * duskFern: arched fronds in two segments (the tips and the curled fiddleheads are fine), a brown dead frond,
--   * deadfall: a fallen mossy branch with broken twigs and a bracket fungus,
--   * stump: a broken stump with moss and a cluster of small pale toadstools.
-- Registered into WorldGen/Flora's registries when this module is required (DuskwoodGen requires it before the
-- forest). Client undergrowth only, no collision. Pure.

local Flora = require("../WorldGen/Flora")
local Kit = require("../WorldGen/Kit")

local o = Kit.o

local Nature = {}

local BARKS = { "#1C1917", "#241F1B", "#2E2822" }
local MOSS_BEARD = { c = "#7A8466", m = "Fabric" }
local FUNGUS = { c = "#C8B894", m = "SmoothPlastic" }
local IVY = { c = "#2A3E24", m = "LeafyGrass" }
local FRONDS = { "#2E4A26", "#3A5630", "#44582C" }
local DEAD_FROND = { c = "#6A5236", m = "LeafyGrass" }

local function deadTree(bp: Kit.BP, x: number, y: number, z: number, s: number, big: boolean, ctx: Kit.Ctx)
	local rng = bp.rng
	local h = 11 * s
	local bark = BARKS[rng:int(1, #BARKS)]
	local barkSw = { c = bark, m = "Wood" }
	-- shell (big trees): the trunk and the leaning main branch, as Flora's blackDead
	local yaw = rng:float(0, 90)
	bp:add("cyl", h, 1.3 * s, 1.3 * s, x, y + h / 2 - 0.5, z, 0, yaw, 90 + rng:float(-5, 5), {
		c = bark,
		m = "Wood",
		lod = if big then "shell" else "detail",
		col = big,
		q = false,
		jitter = 0.06,
	})
	local tipX, tipZ = x + 4.4 * s, z + 1.2 * s
	bp:beam(
		x,
		y + h * 0.62,
		z,
		tipX,
		y + h * 0.98,
		tipZ,
		0.6 * s,
		o(barkSw, if big then "shell" else "detail", { col = false, q = false })
	)
	-- the snapped top: two jagged splinters
	for k = 0, 1 do
		bp:rbox(
			0.5 * s,
			1.6 * s,
			0.5 * s,
			x + (k - 0.5) * 0.5 * s,
			y + h - 0.2 + k * 0.4 * s,
			z,
			rng:float(-14, 14),
			yaw + k * 60,
			rng:float(-10, 10),
			o(barkSw, "detail", { col = false, q = false })
		)
	end
	-- the hollow at the foot and the root flares
	local ha = rng:float(0, math.pi * 2)
	bp:add(
		"ball",
		1 * s,
		1.6 * s,
		0.5 * s,
		x + math.cos(ha) * 0.55 * s,
		y + 0.9 * s,
		z + math.sin(ha) * 0.55 * s,
		0,
		-math.deg(ha) + 90,
		0,
		o(Kit.dark, "detail", { col = false, q = false })
	)
	for i = 0, 2 do
		local a = ha + 1.2 + i * 1.6
		bp:beam(
			x,
			y + 1.2 * s,
			z,
			x + math.cos(a) * 2.6 * s,
			y - 0.3,
			z + math.sin(a) * 2.6 * s,
			0.7 * s,
			o(barkSw, "detail", { col = false, q = false })
		)
	end
	-- bare branches with clawing tips, beards of moss on two of them
	for i = 1, 4 do
		local a = i * 1.7 + rng:float(-0.4, 0.4)
		local by = y + h * rng:float(0.4, 0.88)
		local ex, ey, ez = x + math.cos(a) * 3.6 * s, by + rng:float(1, 3) * s, z + math.sin(a) * 3.6 * s
		bp:beam(x, by, z, ex, ey, ez, 0.42 * s, o(barkSw, "detail", { col = false, q = false }))
		bp:beam(
			ex,
			ey,
			ez,
			ex + math.cos(a + 0.6) * 1.4 * s,
			ey + 1.1 * s,
			ez + math.sin(a + 0.6) * 1.4 * s,
			0.22 * s,
			o(barkSw, "fine", { col = false, q = false })
		)
		if i % 2 == 0 then
			local len = rng:float(1.8, 3) * s
			bp:rbox(
				0.6 * s,
				len,
				0.08,
				(x + ex) / 2,
				(by + ey) / 2 - len / 2,
				(z + ez) / 2,
				0,
				-math.deg(a),
				rng:float(-6, 6),
				o(MOSS_BEARD, "fine", { col = false, q = false, t = 0.1, jitter = 0.08 })
			)
		end
	end
	-- pale bracket fungi up the trunk and a patch of ivy on the other side
	local fa = ha + math.pi
	bp:rbox(
		1.1 * s,
		0.22 * s,
		0.7 * s,
		x + math.cos(fa) * 0.75 * s,
		y + 2.6 * s,
		z + math.sin(fa) * 0.75 * s,
		0,
		-math.deg(fa) + 90,
		0,
		o(FUNGUS, "fine", { col = false, q = false, jitter = 0.08 })
	)
	local ia = ha + math.pi * 0.5
	local ivy = rng:float(-8, 8)
	bp:rbox(
		1.2 * s,
		3.4 * s,
		0.2,
		x + math.cos(ia) * 0.68 * s,
		y + 2 * s,
		z + math.sin(ia) * 0.68 * s,
		0,
		-math.deg(ia) + 90,
		ivy,
		o(IVY, "fine", { col = false, q = false })
	)
	if big then
		Kit.life(ctx, ctx.perch or "perch", tipX, y + h * 0.98 + 0.6, tipZ)
	end
end

local function fern(bp: Kit.BP, x: number, y: number, z: number)
	local rng = bp.rng
	local s = rng:float(0.85, 1.25)
	local c = FRONDS[rng:int(1, #FRONDS)]
	local n = 6
	for i = 0, n - 1 do
		local a = i * 360 / n + rng:float(-14, 14)
		local dead = i == 0 and rng:chance(0.4)
		local sw = if dead then DEAD_FROND else { c = c, m = "LeafyGrass" }
		bp:push(x, y, z, 0, a, 0)
		-- the inner half rises; every second frond arches its tip down (fine)
		bp:rbox(
			0.75 * s,
			0.12,
			1.8 * s,
			0,
			0.75 * s,
			-0.8 * s,
			-38,
			0,
			0,
			o(sw, "detail", { col = false, jitter = 0.07 })
		)
		if i % 2 == 1 then
			bp:rbox(
				0.6 * s,
				0.1,
				1.7 * s,
				0,
				1.15 * s,
				-2.3 * s,
				14,
				0,
				0,
				o(sw, "fine", { col = false, jitter = 0.07 })
			)
		end
		bp:pop()
	end
end

local function deadfall(bp: Kit.BP, x: number, y: number, z: number)
	local rng = bp.rng
	local len = rng:float(4, 6)
	local d = rng:float(0.8, 1.2)
	local yaw = rng:float(0, 180)
	local bark = { c = BARKS[rng:int(1, #BARKS)], m = "Wood" }
	bp:push(x, y, z, 0, yaw, 0)
	bp:add("cyl", len, d, d, 0, d * 0.35, 0, 0, 0, rng:float(-4, 4), o(bark, "detail", { col = false, q = false }))
	bp:box(len * 0.7, 0.2, d * 0.7, 0.3, d * 0.85, 0, o(Kit.moss, "fine", { col = false }))
	for k = 0, 1 do
		local bx = (k - 0.5) * len * 0.6
		bp:beam(
			bx,
			d * 0.5,
			0,
			bx + 0.6,
			d * 0.5 + rng:float(0.9, 1.5),
			(k - 0.5) * 1.6,
			0.16,
			o(bark, "detail", { col = false, q = false })
		)
	end
	bp:rbox(0.8, 0.18, 0.5, -len * 0.3, d * 0.45, -d * 0.5, 0, 0, 0, o(FUNGUS, "fine", { col = false }))
	bp:pop()
end

local function stump(bp: Kit.BP, x: number, y: number, z: number)
	local rng = bp.rng
	local h = rng:float(1, 1.8)
	local d = rng:float(1.4, 2)
	local bark = { c = BARKS[rng:int(1, #BARKS)], m = "Wood" }
	bp:add("cyl", h + 0.4, d, d, x, y + h / 2 - 0.2, z, 0, 0, 90 + rng:float(-6, 6), o(bark, "detail", { col = false }))
	bp:rbox(0.4, 0.8, 0.3, x + d * 0.25, y + h + 0.2, z, 0, rng:float(0, 180), 12, o(bark, "fine", { col = false }))
	bp:add("cyl", 0.15, d * 0.95, d * 0.95, x, y + h, z, 0, 0, 90, o(Kit.moss, "fine", { col = false }))
	for k = 0, 1 do
		local a = rng:float(0, math.pi * 2)
		local px, pz = x + math.cos(a) * (d * 0.5 + 0.3), z + math.sin(a) * (d * 0.5 + 0.3)
		local th = 0.3 + k * 0.12
		bp:add("cyl", th, 0.14, 0.14, px, y + th / 2, pz, 0, 0, 90, o(FUNGUS, "fine", { col = false }))
		bp:add("ball", 0.42, 0.2, 0.42, px, y + th, pz, 0, 0, 0, o({ c = "#B8A07A", m = "SmoothPlastic" }, "fine"))
	end
end

-- Wraps a species / undergrowth into its kit slot (WorldGen/Flora wraps its own registries the same way at load).
local function register()
	Flora.species.duskDead = function(bp, x, y, z, s, big, ctx)
		bp:beginKit("tree:blackDead", x, y, z, s, if big then "shell" else "detail")
		deadTree(bp, x, y, z, s, big, ctx)
		bp:endKit()
	end
	local under: { [string]: { key: string, fn: Flora.UnderFn } } = {
		duskFern = { key = "under:fern", fn = fern },
		deadfall = { key = "under:deadfall", fn = deadfall },
		stump = { key = "under:stump", fn = stump },
	}
	for kind, def in under do
		Flora.under[kind] = function(bp, x, y, z)
			bp:beginKit(def.key, x, y, z, 1, "detail")
			def.fn(bp, x, y, z)
			bp:endKit()
		end
	end
end
register()

-- A cluster of `n` lily pads floating at local height `ly` (the water level), a pale flower now and then (client
-- fine, no collision).
function Nature.pads(bp: Kit.BP, lx: number, ly: number, lz: number, n: number)
	local rng = bp.rng
	for c = 1, n do
		local px, pz = lx + rng:float(-1.8, 1.8), lz + rng:float(-1.8, 1.8)
		local d = rng:float(1.2, 2.2)
		bp:add(
			"cyl",
			0.08,
			d,
			d,
			px,
			ly + 0.05,
			pz,
			0,
			rng:float(0, 180),
			90,
			o({ c = if c % 2 == 0 then "#3E5A2C" else "#344E26", m = "LeafyGrass" }, "fine", { col = false })
		)
	end
	if rng:chance(0.35) then
		bp:add("ball", 0.55, 0.4, 0.55, lx, ly + 0.28, lz, 0, 0, 0, {
			c = if rng:chance(0.5) then "#E6E2D6" else "#C8B8D8",
			m = "SmoothPlastic",
			lod = "fine",
			col = false,
		})
	end
end

return Nature
