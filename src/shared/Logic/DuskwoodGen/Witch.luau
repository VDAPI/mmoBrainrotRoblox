--!strict
-- Witch Marsh (36–42, better drop) (S45).
--   * the witch's hut on stilts (the landmark): crooked walls, a patched roof, smoke from a bent chimney, bunches of
--     herbs, skulls with candles on poles; under it the lure: shelves of jars and a chest of charms,
--   * the bubbling cauldron with a green glow, the hanging tree with charms and bone chimes, straw dolls, candles on
--     stumps, a ring of glowing toadstools and crows,
--   * the troll's trail: a trampled path through the reeds and knocked-over poles. Pure.

local Env = require("./Env")
local Flora = require("../WorldGen/Flora")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Witch = {}

type Build = Kit.Build

local PLANK = { c = "#4A3E34", m = "WoodPlanks" }
local PATCH = { c = "#5E4A3A", m = "WoodPlanks" }
local THATCH = { c = "#5A5038", m = "Grass" }

local function hut(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "witchHut", "home", 22)
	local bp = b.bp
	local deck = 4.6
	for _, c in { { -5, -4 }, { 5, -4 }, { 5, 4 }, { -5, 4 }, { 0, 4.4 } } do
		local gy = Kit.gy(ctx, b, c[1], c[2])
		bp:add(
			"cyl",
			deck - gy + 1.4,
			0.9,
			0.9,
			c[1],
			(deck + gy) / 2 - 0.6,
			c[2],
			0,
			0,
			90 + c[1] * 0.8,
			o(Kit.blackBark, "detail", { col = false })
		)
	end
	bp:box(12, 0.6, 10, 0, deck, 0, o(Kit.greyPlanks, "shell", { q = true }))
	-- crooked walls and the patched roof
	bp:push(0, deck, 0, 0, 0, 4)
	bp:box(8.4, 6, 7, 0, 3.2, 0.6, o(PLANK, "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:rbox(6.4, 0.5, 9.4, side * 2.8, 7.8, 0.6, 0, side * 4, side * -40, o(THATCH, "shell", { q = false }))
		bp:rbox(2.2, 0.55, 2.4, side * 2.6, 8.1, -1.6 + side, 0, 20, side * -40, o(PATCH, "detail", { col = false }))
	end
	bp:box(2.2, 3.8, 0.3, -1.4, 2.1, -2.95, o(Kit.dark, "detail", { col = false }))
	bp:box(1.4, 1.2, 0.2, 2.2, 3.6, -2.95, {
		c = "#3A4A2A",
		m = "Glass",
		lod = "detail",
		col = false,
		tag = "lamp",
		jitter = 0,
		fxColor = Kit.GREEN,
	})
	-- the bent chimney with smoke
	bp:beam(3, 7, 2.6, 3.6, 10.6, 2.8, 1.2, o({ c = "#4A4440", m = "Cobblestone" }, "detail", { col = false }))
	bp:beam(3.6, 10.6, 2.8, 2.8, 12.4, 3.2, 1.1, o({ c = "#4A4440", m = "Cobblestone" }, "detail", { col = false }))
	bp:box(0.6, 0.6, 0.6, 2.8, 12.8, 3.2, o(Kit.dark, "detail", { col = false, t = 1, tag = "smoke" }))
	for k = 0, 4 do
		bp:box(0.5, 1.4, 0.5, -3.6 + k * 1.6, 5.3, -3.4, o({ c = "#5A7A3A", m = "Grass" }, "fine"))
	end
	bp:pop()
	-- the ladder
	for k = 0, 5 do
		bp:box(2.6, 0.25, 0.4, -1.4, deck - 0.6 - k * 0.8, -5.6 - k * 0.25, o(Kit.timber, "detail", { col = false }))
	end
	-- skulls with candles on poles around the hut
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.8
		local lx, lz = math.cos(a) * 11, math.sin(a) * 9
		Props.skullCandle(bp, lx, Kit.gy(ctx, b, lx, lz), lz, 5, Kit.GREEN)
	end
	-- the lure under the hut: shelves of jars and a chest of charms
	local sy = Kit.gy(ctx, b, 2, 0)
	for k = 0, 1 do
		bp:box(5, 0.3, 1.4, 2, sy + 1 + k * 1.4, 0, o(Kit.greyPlanks, "detail", { col = false }))
		for j = 0, 3 do
			bp:add("cyl", 0.9, 0.7, 0.7, 0.4 + j * 1.1, sy + 1.6 + k * 1.4, 0, 0, 0, 90, {
				c = if (j + k) % 2 == 0 then "#4A7A4A" else "#7A4A6A",
				m = "Glass",
				lod = "fine",
				col = false,
				t = 0.2,
			})
		end
	end
	bp:box(3.6, 2, 2.2, -2.6, sy + 1, 1, o({ c = "#3A2A20", m = "WoodPlanks" }, "detail", { col = false }))
	Props.charm(bp, -2.6, sy + 2.6, -0.2, false)
	Props.coins(bp, -2.6, sy + 2, 1, 3)
	-- the cauldron beside the hut
	local cy = Kit.gy(ctx, b, 11, -4)
	Props.cauldron(bp, 11, cy, -4, 3.6, "#5AE07A", Kit.GREEN)
	Kit.rect(ctx, "building", b.at.x, b.at.z, 12, 10, b.at.rot)
	Kit.lifeAt(ctx, b, "perch", 3, deck + 9.4, 1.4)
	table.insert(out, b)
end

local function hangingTree(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "hangingTree", "landmark", 14)
	local bp = b.bp
	Flora.species.blackDead(bp, 0, 0, 0, 1.55, true, ctx)
	for i = 1, 7 do
		local a = i * 0.9
		local r = 3 + (i % 3) * 1.4
		Props.charm(bp, math.cos(a) * r, 11 + (i % 4), math.sin(a) * r, i % 2 == 0)
	end
	for i = 0, 2 do
		local a = i * 2.1
		Props.doll(bp, math.cos(a) * 4.6, 8.6, math.sin(a) * 4.6)
	end
	-- candles on stumps and the ring of glowing toadstools
	for i = 0, 3 do
		local a = i * 1.57 + 0.4
		local lx, lz = math.cos(a) * 7, math.sin(a) * 7
		local gy = Kit.gy(ctx, b, lx, lz)
		bp:add("cyl", 1.4, 1.6, 1.6, lx, gy + 0.6, lz, 0, 0, 90, o(Kit.blackBark, "detail", { col = false }))
		Kit.candle(bp, lx, gy + 1.3, lz, 0.6)
	end
	for i = 0, 7 do
		local a = i * math.pi / 4
		local lx, lz = math.cos(a) * 10, math.sin(a) * 10
		Flora.under.toadstools(bp, lx, Kit.gy(ctx, b, lx, lz), lz)
	end
	table.insert(out, b)
end

-- The troll's trail through the reeds: trampled reeds and knocked-over poles.
local function trail(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in { { 160, 150 }, { 120, 120 }, { 70, 130 }, { 20, 170 } } do
		Env.clear(env, p[1], p[2], 4)
		local b = Kit.build(ctx, `TrollTrail_{i}`, "traces", p[1], p[2], i * 35)
		local bp = b.bp
		for k = 0, 5 do
			bp:rbox(
				0.25,
				3.4,
				0.25,
				k * 0.8 - 2,
				Kit.gy(ctx, b, k * 0.8 - 2, 1) + 0.3,
				1,
				82,
				k * 12,
				0,
				o({ c = "#6E7244", m = "Grass" }, "detail", { col = false })
			)
		end
		Props.trollPrint(bp, 0, Kit.gy(ctx, b, 0, -2), -2, 30)
		if i % 2 == 0 then
			bp:rbox(
				0.3,
				5,
				0.3,
				3,
				Kit.gy(ctx, b, 3, -1) + 0.3,
				-1,
				80,
				20,
				0,
				o(Kit.darkBark, "detail", { col = false })
			)
		end
		table.insert(out, b)
	end
end

function Witch.all(env: Env.Env, out: { Build })
	hut(env, out)
	hangingTree(env, out)
	trail(env, out)
	local ctx = env.ctx
	for _, p in { { -40, 100 }, { -110, 140 }, { 30, 130 } } do
		Kit.life(ctx, "wisp", p[1], env.T.height(p[1], p[2]) + 2.5, p[2], 16)
	end
	Kit.life(ctx, "mist", -50, env.T.height(-50, 120), 120, 50)
	Kit.life(ctx, "fireflies", 120, env.T.height(120, 160) + 1.5, 160, 24)
end

return Witch
