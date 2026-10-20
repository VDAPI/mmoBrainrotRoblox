--!strict
-- W17-W18 part 2 (docs/wyglad/mapy/pustkowia.md 1.3-1.7): what the map plan still lists after Details (W18 part 1).
-- Built after Details and without clearings of their own, so every earlier Build, tree, rock and node stays where it
-- was (every Build is named Detail_*). Looks only: no collision, nothing on a walked road (the cart ruts lie flat
-- across the procession road), no anchor, NPC or monster group under them.
--   * the ruined caravan stop beside the trail to the oasis, halfway (1.3 step 2): a sagging shelter of poles and torn
--     canvas, a log bench looking south over the white lake bed, a dead fire ring, a dry trough and a hitching post,
--   * the rotten dwarven pier at the oasis' last pond (secret 4, 1.5): a short side landing with a blue rune post, a
--     rod propped toward the fishing spot's buoys, a bucket and a sunken plank,
--   * the dead palm on the dune crest at the edge of the scarp (view 3, 1.6), framing the necropolis below,
--   * the renegades' cart ruts crossing the procession road of the Desert Tombs, a spilt urn and coins (1.4),
--   * embers rising over the Fire Vein and the other lava rivers (1.7: over the Pit, the crater and the Vein). Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o

local Finish = {}

type Build = Kit.Build

local RUNE = { c = "#6BB8FF", m = "Neon" }
local ROTTEN = { c = "#3A3A30", m = "Wood" }
local CANVAS = { c = "#9A8A6A", m = "Fabric" }
local RUT = { c = "#5E4C38", m = "Sand" }

local function nd(): any
	return { col = false, q = false }
end

-- 1.3 step 2: the caravan stop halfway down the trail, east of it (the trail's edge 13+ studs away), no collision.
local function caravanStop(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Kit.build(ctx, "Detail_CaravanStop", "ruins", -499, 374, 0)
	local bp = b.bp
	-- the shelter: four poles, one snapped, the canvas roof sagging toward the broken corner
	local poles = { { -4, -3, 5.2 }, { 4, -3, 5.2 }, { -4, 3, 4.6 }, { 4, 3, 2.2 } }
	for _, p in poles do
		local gy = Kit.gy(ctx, b, p[1], p[2])
		bp:box(0.5, p[3], 0.5, p[1], gy + p[3] / 2, p[2], o(Kit.deadBark, "detail", nd()))
	end
	local g0 = Kit.gy(ctx, b, 0, 0)
	bp:rbox(4.4, 0.4, 0.4, 2.2, g0 + 0.3, 4.4, 0, 30, 0, o(Kit.deadBark, "detail", nd())) -- the snapped top
	bp:rbox(8.6, 0.12, 3.4, 0, g0 + 5, -1.6, -6, 0, 0, o(CANVAS, "detail", nd()))
	bp:rbox(4.4, 0.12, 3.4, -2.1, g0 + 4.4, 1.6, 14, 0, -4, o(CANVAS, "detail", { col = false, q = false }))
	bp:rbox(4.2, 0.12, 3.2, 2.4, g0 + 3, 1.8, 24, 0, 22, o(Kit.rag, "fine", { col = false, q = false, tag = "flag" }))
	bp:box(8.4, 0.3, 0.3, 0, g0 + 5.2, -3, o(Kit.timber, "detail", nd()))
	-- the log bench under it, looking south over the dry lake
	for _, lx in { -2.4, 2.4 } do
		bp:add("ball", 1, 0.8, 1, lx, Kit.gy(ctx, b, lx, 1) + 0.35, 1, 0, 0, 0, o(Props.ash, "detail", nd()))
	end
	bp:add("cyl", 6, 0.9, 0.9, 0, g0 + 1.05, 1, 0, 0, 0, o(Kit.deadBark, "detail", nd()))
	-- the dead fire ring before it: stones, charred logs, grey ash
	local fx, fz = 0, 7.5
	local fy = Kit.gy(ctx, b, fx, fz)
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7
		bp:rbox(
			0.8,
			0.5,
			0.8,
			fx + math.cos(a) * 1.7,
			fy + 0.2,
			fz + math.sin(a) * 1.7,
			0,
			math.deg(a),
			0,
			o(Props.ashDark, "detail", nd())
		)
	end
	for i = 0, 1 do
		bp:add("cyl", 2.6, 0.5, 0.5, fx, fy + 0.3, fz, 0, 40 + i * 70, 8, o(Kit.charred, "fine", nd()))
	end
	bp:add("cyl", 0.2, 2.6, 2.6, fx, fy + 0.08, fz, 0, 0, 90, o(Props.ash, "fine", nd()))
	-- a dry trough of planks and the hitching post with a frayed rope end
	local ty = Kit.gy(ctx, b, 7, -1)
	bp:box(1.6, 0.9, 4.6, 7, ty + 0.45, -1, o(Kit.greyPlanks, "detail", nd()))
	bp:box(1.1, 0.3, 4.1, 7, ty + 0.8, -1, o(Props.salt, "fine", nd()))
	local hy = Kit.gy(ctx, b, -7, -2)
	bp:box(0.5, 3.4, 0.5, -7, hy + 1.7, -2, o(Kit.timber, "detail", nd()))
	bp:rbox(0.15, 1.6, 0.15, -6.8, hy + 2.2, -2.3, 20, 0, 10, o(Kit.rope, "fine", nd()))
	-- a broken wheel against the trough
	bp:rbox(0.3, 3, 3, 8, ty + 1.3, 2.4, 0, 0, 14, o(Kit.charred, "detail", nd()))
	table.insert(out, b)
end

-- Secret 4: the rotten dwarven landing at the foot of the oasis jetty (west of it; the fishing spot is east).
local function dwarfPier(env: Env.Env, out: { Build })
	local s = env.sites.oasisJetty
	local lake = env.areas.lakes[1]
	local top = math.max(env.T.height(s.x, 490), env.T.shape.lakeLevel) + 2.4 -- the jetty's deck (Oasis.jetty)
	local endZ = lake.z - lake.r + 4
	local b = Kit.buildAt("Detail_DwarfPier", "jetty", s.x - 6, top - 0.2, endZ - 3, 0)
	local bp = b.bp
	local water = env.T.shape.lakeLevel - b.at.y
	-- the side landing: dark rotten planks, one gone, one sunk into the pond
	for k = 0, 3 do
		if k ~= 2 then
			bp:box(1.4, 0.3, 4.4, -1.6 + k * 1.5, 0, 0, o(ROTTEN, "detail", nd()))
		end
	end
	bp:rbox(1.4, 0.3, 4.4, 1.6, water + 0.3, 3.2, 18, 0, 10, o(ROTTEN, "fine", nd()))
	for _, p in { { -2.4, -2 }, { 2.6, -2 }, { -2.4, 2 } } do
		local g = env.T.height(b.at.x + p[1], b.at.z + p[2]) - b.at.y
		bp:add("cyl", -g + 0.4, 0.7, 0.7, p[1], g / 2 + 0.2, p[2], 0, 0, 90, o(ROTTEN, "detail", nd()))
	end
	-- the dwarven mooring post with its blue rune, facing the jetty
	local g = env.T.height(b.at.x - 2.4, b.at.z + 2) - b.at.y
	bp:box(0.9, 2.2 - g, 0.9, -2.4, (2.2 + g) / 2, 2, o(Props.basalt, "detail", nd()))
	bp:box(0.1, 0.5, 0.4, -1.9, 1.5, 2, o(RUNE, "fine", nd()))
	bp:box(0.1, 0.25, 0.25, -1.9, 1.0, 2, o(RUNE, "fine", nd()))
	-- the rod propped on a forked stick, its line down to the water toward the spot's buoys
	bp:rbox(0.16, 0.16, 7.5, 1, 1.2, 2.6, -18, 20, 0, o(Kit.timber, "fine", nd()))
	bp:rbox(0.2, 1.2, 0.2, 0.8, 0.6, 0.8, 0, 0, 12, o(Kit.deadBark, "fine", nd()))
	bp:beam(2.3, 2.3, 6, 2.6, water + 0.1, 7.2, 0.04, o(Kit.rope, "fine", nd()))
	-- a bucket and a coil of rope
	bp:add("cyl", 1, 0.9, 0.9, -0.8, 0.65, -1.2, 0, 0, 90, o(Kit.greyPlanks, "fine", nd()))
	bp:add("cyl", 0.3, 1.1, 1.1, 0.9, 0.3, -1.4, 0, 0, 90, o(Kit.rope, "fine", nd()))
	table.insert(out, b)
end

-- View 3: a dead palm on the dune crest at the edge of the scarp, in the foreground of the necropolis.
local function crestPalm(env: Env.Env, out: { Build })
	local b = Kit.build(env.ctx, "Detail_CrestPalm", "trees", 440, 294, 0)
	Props.palm(b.bp, 0, -0.3, 0, 1.05, true, false)
	table.insert(out, b)
end

-- 1.4 Desert Tombs: the renegades' cart ruts across the procession road between two pairs of guardians, a spilt urn.
local function cartRuts(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local cx, cz = 603, 77
	local b = Kit.build(ctx, "Detail_CartRuts", "traces", cx, cz, 0)
	local bp = b.bp
	-- a gentle arc from the west courtyard's side toward the east, 1.6 studs between the wheels
	for k = -6, 6 do
		local lx = k * 3.6
		local lz = (k * k) * 0.06 - 2 + k * 0.25
		local yaw = -math.deg(math.atan((0.12 * k + 0.25) / 3.6)) -- along the arc
		for _, side in { -0.8, 0.8 } do
			local px, pz = lx, lz + side
			bp:rbox(3.9, 0.06, 0.45, px, Kit.gy(ctx, b, px, pz) + 0.04, pz, 0, yaw, 0, o(RUT, "fine", nd()))
		end
	end
	-- a canopic urn fallen off a cart on the verge, its gold lid rolled away, coins
	local ux, uz = 24, 1.5
	local uy = Kit.gy(ctx, b, ux, uz)
	bp:rbox(1.4, 1, 1, ux, uy + 0.45, uz, 0, 30, 90, o(Props.darkSand, "fine", nd()))
	bp:add("ball", 0.8, 0.7, 0.8, ux + 1.6, uy + 0.3, uz + 0.9, 0, 0, 0, o(Props.gold, "fine", nd()))
	Props.coins(bp, ux - 1, uy, uz + 0.5, 4)
	table.insert(out, b)
end

-- 1.7: embers rising over the lava rivers (the Fire Vein first), every ~70 studs.
local function riverEmbers(env: Env.Env)
	local T = env.T
	for i in assert(T.shape.lava, "lava").rivers do
		local line = T.lavaLine(i)
		local s = 30
		while s < line.length - 20 do
			local x, z = TerrainLayers.pointAt(line, s)
			Kit.life(env.ctx, "embers", x, T.lavaLevel(i, s) + 1, z, 5)
			s += 70
		end
	end
end

function Finish.all(env: Env.Env, out: { Build })
	caravanStop(env, out)
	dwarfPier(env, out)
	crestPalm(env, out)
	cartRuts(env, out)
	riverEmbers(env)
end

return Finish
