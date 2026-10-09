--!strict
-- Harpy Rocks (76–83, loot) (S47): a forest of ice-and-rock spires capped with snow round the frozen Harpy Tarn.
--   * the Queen's Spire (the landmark): the tallest spire with a huge nest of branches, bones and feathers on top,
--     trinkets glinting in it,
--   * the fallen climbers' camp at its foot: a torn tent, packs frozen into the ice, coils of rope, pitons in the
--     rock, an ice axe driven into the ice, a rope ladder hanging from a ledge, a frozen lantern,
--   * harpy traces: guano streaks down the spires, feathers on the snow, yellow glints in the clefts at night; yeti
--     tracks by the tarn; the tarn's ice hole with its fishing spot. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local Shapes = require("../../Data/Terrain")

local o = Kit.o

local Harpy = {}

type Build = Kit.Build

local SHAPE = Shapes.byMap.frostpeak

-- A nest of branches on top of a spire (world x, z, top y), feathers and bones in it.
local function nest(bp: Kit.BP, x: number, y: number, z: number, s: number, trinkets: boolean)
	local rng = bp.rng
	for k = 1, 14 do
		local a = k * 0.45
		local r = 3.6 * s
		bp:rbox(
			7 * s,
			0.6 * s,
			0.6 * s,
			x + math.cos(a) * r,
			y + 0.6 * s + (k % 3) * 0.4 * s,
			z + math.sin(a) * r,
			0,
			math.deg(-a) + 90,
			rng:float(-12, 12),
			o(Props.oldWood, if k <= 4 then "shell" else "detail", { col = false, q = false })
		)
	end
	bp:add("cyl", 1.2 * s, 7 * s, 7 * s, x, y + 0.3 * s, z, 0, 0, 90, o(Props.harpyFeather, "detail", { col = false }))
	Kit.bones(bp, x + 1, y + 0.9 * s, z, 4)
	if trinkets then
		for k = 1, 6 do
			local a = k * 1.1
			bp:box(0.5, 0.5, 0.5, x + math.cos(a) * 2 * s, y + 1 * s, z + math.sin(a) * 2 * s, {
				c = if k % 2 == 0 then "#C9A45C" else "#BFE6F7",
				m = "Neon",
				lod = "detail",
				col = false,
				tag = "glow",
				jitter = 0,
				fxColor = Props.HARPY,
			})
		end
	end
end

local function queen(env: Env.Env, out: { Build })
	local s = env.sites.harpyQueen
	local spire = (SHAPE.spires :: { any })[1]
	Env.clear(env, s.x, s.z, 30)
	local top = env.T.height(spire.x, spire.z)
	local b = Kit.buildAt("harpyQueen", "landmark", spire.x, top, spire.z, s.rot)
	local bp = b.bp
	nest(bp, 0, -0.6, 0, 1.6, true)
	-- guano streaks down the walls
	for k = 0, 3 do
		local a = k * 1.6
		bp:rbox(
			1.4,
			18,
			0.2,
			math.cos(a) * 8,
			-12,
			math.sin(a) * 8,
			0,
			math.deg(-a) + 90,
			0,
			o({ c = "#E8E4D4", m = "SmoothPlastic" }, "fine", { col = false, t = 0.2 })
		)
	end
	Kit.lifeAt(env.ctx, b, "eagles", 0, 40, 0, 60)
	table.insert(out, b)
	-- nests on a few more spires
	for i = 2, 7 do
		local sp = (SHAPE.spires :: { any })[i]
		if sp.h >= 30 then
			local nb = Kit.buildAt(`HarpyNest_{i}`, "ice", sp.x, env.T.height(sp.x, sp.z), sp.z, 0)
			nest(nb.bp, 0, -0.4, 0, 0.9, false)
			Kit.lifeAt(env.ctx, nb, "harpyGlint", 0, -6, 0)
			table.insert(out, nb)
		end
	end
end

local function climbersCamp(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "climbersCamp", "landmark", 18)
	local bp = b.bp
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	local y = ground(0, 0)
	-- the torn tent
	bp:push(0, y, 0, 0, 0, 0)
	for _, side in { -1, 1 } do
		bp:rbox(
			0.2,
			4.4,
			6,
			side * 1.5,
			1.6,
			0,
			0,
			0,
			side * -34,
			o({ c = "#8A3A2A", m = "Fabric" }, "shell", { q = false })
		)
	end
	bp:rbox(3, 0.2, 2.6, 2.6, 0.2, 2, 0, 20, 4, o({ c = "#8A3A2A", m = "Fabric" }, "fine", { col = false }))
	bp:pop()
	-- packs frozen into the ice, coils of rope, an ice axe, a frozen lantern
	for k = 0, 2 do
		local lx, lz = -5 + k * 1.8, 4 + (k % 2)
		bp:box(1.4, 1.8, 0.9, lx, ground(lx, lz) + 0.6, lz, o(Props.hide, "detail", { col = false }))
		bp:box(1.6, 0.5, 1.1, lx, ground(lx, lz) + 0.15, lz, o(Props.ice, "fine", { col = false, t = 0.3 }))
	end
	for k = 0, 1 do
		bp:add("cyl", 0.5, 2, 2, 5 + k * 2.4, ground(5, -3) + 0.25, -3, 0, 0, 90, o(Kit.rope, "fine", { col = false }))
	end
	bp:rbox(0.25, 3, 0.25, -3, ground(-3, -4) + 1.2, -4, 0, 0, 16, o(Props.oldWood, "detail", { col = false }))
	bp:box(1.4, 0.3, 0.3, -2.6, ground(-3, -4) + 2.6, -4, o(Props.iron, "fine", { col = false }))
	Kit.lantern(bp, 3, ground(3, 3), 3, "#9FC8E0", 3, "detail")
	-- a rope ladder from a ledge of the spire, pitons
	local sp = (SHAPE.spires :: { any })[1]
	local lx, lz = sp.x - b.at.x, sp.z - b.at.z
	local d = math.sqrt(lx * lx + lz * lz)
	local fx, fz = lx - lx / d * (sp.r * 0.8), lz - lz / d * (sp.r * 0.8)
	for _, side in { -1, 1 } do
		bp:box(0.15, 14, 0.15, fx + side * 0.8, ground(fx, fz) + 7, fz, o(Kit.rope, "detail", { col = false }))
	end
	for k = 1, 9 do
		bp:box(1.8, 0.2, 0.3, fx, ground(fx, fz) + k * 1.5, fz, o(Props.oldWood, "fine", { col = false }))
	end
	table.insert(out, b)
end

-- The tarn: reeds and feathers on the shore, yeti tracks, guano on a boulder.
local function tarn(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.tarn
	local b = Kit.build(ctx, "tarn", "traces", s.x + 50, s.z - 54, 0)
	local bp = b.bp
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	Props.tracks(bp, ground, -10, 0, 250, 9, 2.4, 4)
	for k = 1, 6 do
		local lx, lz = -14 + k * 4, 6 + (k % 2) * 3
		bp:rbox(
			0.5,
			0.06,
			2,
			lx,
			ground(lx, lz) + 0.05,
			lz,
			0,
			k * 40,
			0,
			o(Props.harpyFeather, "fine", { col = false })
		)
	end
	Props.boulder(bp, 8, ground(8, -6), -6, 3)
	table.insert(out, b)
end

function Harpy.all(env: Env.Env, out: { Build })
	queen(env, out)
	climbersCamp(env, out)
	tarn(env, out)
end

return Harpy
