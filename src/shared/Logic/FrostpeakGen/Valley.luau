--!strict
-- Ice Wolf Valley (70–75) (S47): the way into the Frost Peaks.
--   * the entry: a stone cairn with ram horns and ribbons (flags) by the road, a brazier by the scout,
--   * the abandoned trappers' camp (the landmark): a log cabin whose roof caved in under the snow, empty racks for
--     drying hides, snares on stakes, a sledge with a cracked runner, a buried fire, the trappers' lantern that still
--     smoulders,
--   * the wolves' Howling Rock: a frosted boulder in a ring of trampled snow, tracks, a scattered deer, pale blue fur
--     on the bushes; the leopards' ledge over the brook with leftovers and spotted fur. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Valley = {}

type Build = Kit.Build

local function cairn(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "entryCairn", "landmark", 8)
	local bp = b.bp
	local y = Kit.gy(ctx, b, 0, 0)
	for k = 0, 5 do
		local s = 3.2 - k * 0.45
		bp:rbox(
			s,
			1.4,
			s,
			0,
			y + 0.6 + k * 1.2,
			0,
			0,
			k * 37,
			0,
			o(Props.frostStone, if k < 3 then "shell" else "detail", { q = false })
		)
	end
	-- ram horns on top, ribbons fluttering from a stick
	for _, side in { -1, 1 } do
		bp:beam(0, y + 7.6, 0, side * 1.4, y + 8.6, -0.6, 0.35, o(Kit.bone, "detail", { col = false }))
		bp:beam(side * 1.4, y + 8.6, -0.6, side * 1.6, y + 7.6, -1.4, 0.3, o(Kit.bone, "fine", { col = false }))
	end
	bp:box(0.2, 4, 0.2, 0.6, y + 9.4, 0.4, o(Props.frozenWood, "detail", { col = false }))
	for k, c in { "#8A2A2A", "#2F4A7A", "#C9A45C" } do
		bp:box(
			0.12,
			2.4,
			0.5,
			0.75,
			y + 10.8 - k * 0.4,
			0.4 + k * 0.3,
			{ c = c, m = "Fabric", lod = "detail", col = false, tag = "flag" }
		)
	end
	Props.snowCap(bp, 0, y + 6.6, 0, 2.4, 2.4, "fine")
	table.insert(out, b)
	-- the scout's brazier
	local s = Kit.build(ctx, "ScoutBrazier", "lamp", -680, -46, 0)
	Props.brazier(s.bp, 0, Kit.gy(ctx, s, 0, 0), 0, Kit.FIRE, "shell")
	Env.clear(env, -680, -46, 3)
	table.insert(out, s)
end

local function trapperCamp(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "trapperCamp", "landmark", 26)
	local bp = b.bp
	local y = Kit.gy(ctx, b, 0, 4)
	-- the log cabin: walls of stacked logs, the roof caved in under a hump of snow
	local logs = Props.oldWood
	for k = 0, 5 do
		local ly = y + 0.6 + k * 1.1
		for _, side in { -1, 1 } do
			bp:add(
				"cyl",
				12,
				1.1,
				1.1,
				0,
				ly,
				4 + side * 4.4,
				0,
				0,
				0,
				o(logs, if k < 3 then "shell" else "detail", { q = false })
			)
			bp:add(
				"cyl",
				10,
				1.1,
				1.1,
				side * 5.6,
				ly + 0.5,
				4,
				0,
				90,
				0,
				o(logs, if k < 3 then "shell" else "detail", { q = false })
			)
		end
	end
	bp:box(2.4, 4, 0.3, -1, y + 2, -0.45, o(Kit.dark, "detail", { col = false })) -- doorway
	bp:rbox(13, 0.6, 6, 0, y + 6.4, 1.6, 26, 0, 0, o(Props.frozenWood, "detail", { col = false }))
	bp:rbox(13, 0.6, 6, 1, y + 3.6, 6.4, -14, 4, 8, o(Props.frozenWood, "detail", { col = false })) -- the fallen half
	Props.snowCap(bp, 0, y + 7, 2, 13, 6, "shell")
	Props.snowCap(bp, 1, y + 4.6, 6.4, 12, 6)
	Props.icicles(bp, 0, y + 6, -0.8, 12, 10, 1.6)
	-- drying racks for hides, empty and one with a stiff hide
	for k = 0, 2 do
		local lx = -12 + k * 5
		for _, side in { -1, 1 } do
			bp:box(0.4, 5, 0.4, lx + side * 1.8, Kit.gy(ctx, b, lx, -8) + 2.4, -8, o(logs, "detail", { col = false }))
		end
		bp:box(4, 0.35, 0.35, lx, Kit.gy(ctx, b, lx, -8) + 4.6, -8, o(logs, "detail", { col = false }))
		if k == 1 then
			bp:rbox(
				3,
				3.2,
				0.15,
				lx,
				Kit.gy(ctx, b, lx, -8) + 2.9,
				-8,
				4,
				0,
				0,
				o(Props.paleHide, "fine", { col = false })
			)
		end
	end
	-- snares on stakes, the sledge with a cracked runner, a buried fire
	for k = 0, 3 do
		local lx, lz = 9 + k * 2.4, -10 + (k % 2) * 3
		bp:box(0.25, 1.4, 0.25, lx, Kit.gy(ctx, b, lx, lz) + 0.6, lz, o(logs, "fine", { col = false }))
		bp:add(
			"cyl",
			0.08,
			1,
			1,
			lx,
			Kit.gy(ctx, b, lx, lz) + 0.4,
			lz - 0.6,
			90,
			0,
			0,
			o(Props.iron, "fine", { col = false })
		)
	end
	bp:box(3, 0.4, 7, 10, Kit.gy(ctx, b, 10, 2) + 1, 2, o(Props.oldWood, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:rbox(
			0.3,
			0.4,
			8,
			10 + side * 1.4,
			Kit.gy(ctx, b, 10, 2) + 0.3,
			2,
			if side < 0 then 6 else 0,
			0,
			0,
			o(Props.iron, "fine", { col = false })
		)
	end
	Props.snowCap(bp, 10, Kit.gy(ctx, b, 10, 2) + 1.3, 2, 3, 6, "fine")
	Props.snowCap(bp, -4, Kit.gy(ctx, b, -4, -2) + 0.2, -2, 3.4, 3.4)
	for i = 0, 5 do
		local a = i * math.pi / 3
		bp:rbox(
			0.8,
			0.5,
			0.8,
			-4 + math.cos(a) * 1.8,
			Kit.gy(ctx, b, -4, -2) + 0.3,
			-2 + math.sin(a) * 1.8,
			0,
			math.deg(a),
			0,
			o(Props.frostStone, "fine", { col = false })
		)
	end
	-- the trappers' lantern that still smoulders (the lure seen from the road)
	Kit.lantern(bp, -7, Kit.gy(ctx, b, -7, -1), -1, "#FFB46E", 6, "shell")
	Kit.lifeAt(ctx, b, "smoke", -4, 1, -2)
	table.insert(out, b)
end

local function howlRock(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "howlRock", "traces", 16)
	local bp = b.bp
	local y = Kit.gy(ctx, b, 0, 0)
	bp:rbox(9, 7, 7, 0, y + 2.6, 0, 8, 20, -6, o(Props.frostStone, "shell", { q = false }))
	bp:rbox(5, 4, 4, 2.6, y + 6, 1, 0, 40, 18, o(Props.frostStone, "shell", { q = false }))
	Props.snowCap(bp, 1, y + 7.8, 0.6, 6, 4)
	bp:add("cyl", 0.1, 26, 26, 0, y + 0.08, 0, 0, 0, 90, o(Props.trackColor, "detail", { col = false, t = 0.2 }))
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	for k = 0, 4 do
		Props.tracks(bp, ground, math.cos(k * 1.26) * 13, math.sin(k * 1.26) * 13, k * 72 + 90, 6, 0.9, 2.2)
	end
	-- the scattered deer, blue fur on the bushes
	Kit.bones(bp, -8, 0, 7, 6, ground)
	bp:rbox(2.4, 0.2, 1.6, -9, ground(-9, 9) + 0.1, 9, 0, 30, 0, o(Props.hide, "fine", { col = false }))
	for k = 1, 4 do
		local lx, lz = 9 + k * 1.6, -6 + k * 2
		bp:add("ball", 2, 1.4, 2, lx, ground(lx, lz) + 0.6, lz, 0, 0, 0, o(Props.rime, "detail", { col = false }))
		Props.fur(bp, lx, ground(lx, lz) + 1.3, lz, Props.wolfFur)
	end
	table.insert(out, b)
end

local function leopardLedge(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "leopardLedge", "traces", 14)
	local bp = b.bp
	local y = Kit.gy(ctx, b, 0, 0)
	bp:rbox(10, 5, 8, 0, y + 1.8, 0, 0, 10, 4, o(Props.darkStone, "shell", { q = false }))
	bp:rbox(9, 1.2, 6, -1.4, y + 4.6, -1, 0, 10, 0, o(Props.frostStone, "shell", { q = false }))
	Props.snowCap(bp, 1, y + 5.4, 1.6, 4, 3, "fine")
	Kit.bones(bp, -2, y + 5.2, -1.4, 4)
	Props.fur(bp, 1.4, y + 5.4, -2, Props.leopardFur)
	bp:box(0.9, 0.2, 0.4, 1.8, y + 5.5, -2.2, o({ c = "#5A5A66", m = "Fabric" }, "fine", { col = false }))
	-- claw marks on a dead tree by the ledge
	bp:add("cyl", 12, 1.3, 1.3, 6, y + 5.4, 5, 0, 0, 90, o(Props.frozenWood, "shell", { q = false }))
	bp:push(6, 0, 5 - 0.66, 0, 0, 0)
	Kit.claws(bp, 0, y + 8, 0, 1)
	bp:pop()
	table.insert(out, b)
end

function Valley.all(env: Env.Env, out: { Build })
	cairn(env, out)
	trapperCamp(env, out)
	howlRock(env, out)
	leopardLedge(env, out)
end

return Valley
