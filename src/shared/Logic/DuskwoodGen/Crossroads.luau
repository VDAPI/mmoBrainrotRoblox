--!strict
-- Misty Crossroads (30–36, fast EXP) (S45): a bowl full of mist around the junction.
--   * the wayside shrine (the landmark and lure): a mossy figure under a little roof, a lit lantern, candles; a
--     violet rag and a carved sign of the cult on it,
--   * the gallows with an empty noose and a crow, the crooked signpost of many arms at the junction,
--   * serpent sheds in the reeds by the Black Stream. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")

local o = Kit.o

local Crossroads = {}

type Build = Kit.Build

local function shrine(env: Env.Env, out: { Build })
	local b = Env.atSite(env, "wayShrine", "shrine", 10)
	local bp = b.bp
	bp:box(3.6, 3, 3, 0, 1, 0, o(Kit.mossyStone, "shell", { q = true }))
	bp:box(0.5, 4, 0.5, -1.6, 4.4, 1.3, o(Kit.darkBark, "detail", { col = false }))
	bp:box(0.5, 4, 0.5, 1.6, 4.4, 1.3, o(Kit.darkBark, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:rbox(
			2.6,
			0.3,
			4,
			side * 1.1,
			6.9,
			0.2,
			0,
			0,
			side * -34,
			o({ c = "#3A3632", m = "WoodPlanks" }, "shell", { q = false })
		)
	end
	-- the mossy figure with its hands folded
	bp:box(1.2, 2.2, 0.9, 0, 3.6, 0.4, o(Kit.mossyStone, "detail", { col = false }))
	bp:add("ball", 1, 1.1, 1, 0, 5.1, 0.4, 0, 0, 0, o(Kit.mossyStone, "detail", { col = false }))
	bp:box(1.4, 0.4, 1, 0, 2.6, 0.3, o(Kit.moss, "fine"))
	Kit.lantern(bp, 2.4, 0, -1.6, nil, 4.5, "detail")
	Kit.candle(bp, -0.8, 2.5, -1.2, 0.6)
	Kit.candle(bp, 0.6, 2.5, -1.3, 0.9)
	bp:box(0.1, 1.4, 1, -1.85, 5.2, 1.3, o(Kit.violet, "fine", { tag = "flag" }))
	bp:box(0.7, 0.7, 0.05, 0, 1.6, -1.53, o({ c = "#7A4AA0", m = "SmoothPlastic" }, "fine"))
	table.insert(out, b)
end

local function gallows(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "gallows", "gallows", 10)
	local bp = b.bp
	bp:box(1.2, 12, 1.2, -3, 5.6, 0, o(Kit.darkBark, "shell", { q = true }))
	bp:box(8, 1, 1, 0.6, 11.2, 0, o(Kit.darkBark, "shell", { q = false }))
	bp:beam(-3, 8, 0, -0.6, 11, 0, 0.5, o(Kit.darkBark, "detail", { col = false }))
	bp:box(0.12, 4, 0.12, 3.6, 8.8, 0, o(Kit.rope, "detail", { col = false, tag = "flag" }))
	bp:add("cyl", 0.3, 1.4, 1.4, 3.6, 6.6, 0, 0, 0, 0, o(Kit.rope, "fine"))
	bp:box(5, 1.2, 4, 2.4, 0.4, 0, o(Kit.greyPlanks, "detail", { col = false }))
	Kit.lifeAt(ctx, b, "perch", 4.4, 12, 0)
	table.insert(out, b)
end

local function signpost(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local x, z = 372, -24
	Env.clear(env, x, z, 4)
	local b = Kit.build(ctx, "CrookedSign", "signs", x, z, 0)
	local bp = b.bp
	bp:rbox(0.8, 9, 0.8, 0, 4.2, 0, 4, 0, -3, o(Kit.darkBark, "shell", { q = false }))
	for i, a in { 0, 70, 150, 215, 290 } do
		bp:push(0, 5.6 + i * 0.7, 0, 0, a, bp.rng:float(-12, 12))
		bp:box(4, 0.8, 0.2, 2, 0, 0, o(Kit.greyPlanks, "detail", { col = false }))
		bp:add("wedge", 0.2, 0.8, 0.8, 4.3, 0, 0, 0, 90, 0, o(Kit.greyPlanks, "fine"))
		bp:pop()
	end
	bp:box(0.1, 1.6, 1, 0.45, 7.6, 0, o(Kit.violet, "fine", { tag = "flag" }))
	table.insert(out, b)
end

-- Serpent sheds in the reeds on the stream banks near the crossroads.
local SHEDS = { { 452, -152 }, { 312, -122 }, { 240, -78 }, { 214, -6 } }

local function sheds(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in SHEDS do
		local b = Kit.build(ctx, `SerpentShed_{i}`, "traces", p[1], p[2] + 10, i * 60)
		local bp = b.bp
		for k = 0, 4 do
			bp:rbox(
				1.4,
				0.15,
				0.7,
				k * 1.2,
				Kit.gy(ctx, b, k * 1.2, math.sin(k) * 0.6) + 0.12,
				math.sin(k) * 0.6,
				0,
				k * 25,
				0,
				{
					c = "#CFC8A8",
					m = "SmoothPlastic",
					lod = "fine",
					col = false,
					t = 0.3,
				}
			)
		end
		table.insert(out, b)
	end
end

function Crossroads.all(env: Env.Env, out: { Build })
	shrine(env, out)
	gallows(env, out)
	signpost(env, out)
	sheds(env, out)
	-- the fog stands in the bowl around the junction and over the stream
	for _, p in { { 330, -110, 60 }, { 230, -60, 40 }, { 420, -170, 40 }, { 300, -200, 40 } } do
		Kit.life(env.ctx, "mist", p[1], env.T.height(p[1], p[2]), p[2], p[3])
	end
	for _, p in { { 380, -128 }, { 280, -90 } } do
		Kit.life(env.ctx, "wisp", p[1], env.T.height(p[1], p[2]) + 2, p[2], 14)
	end
end

return Crossroads
