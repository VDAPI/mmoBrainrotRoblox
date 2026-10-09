--!strict
-- Mammoth Tundra (82–89, fast EXP) (S47): a windswept plateau, thin snow with frozen ground and grey gravel,
-- erratic boulders.
--   * the Mammoth Graveyard (the landmark): a field of giant skeletons, the biggest with its tusks crossed over the
--     road,
--   * the giants' hunting camp: hide tents on frames of bones, meat drying racks, racks of 15-stud spears, a heap of
--     skulls, a hearth, a shallow pit trap with stakes; smoke by day,
--   * mammoth traces: trampled trails of the herd, snow scraped down to frozen grass (grazing), tufts of fur on
--     boulders they rub against. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Tundra = {}

type Build = Kit.Build

local function graveyard(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.mammothGraveyard
	Env.clear(env, s.x, s.z, 34)
	local b = Kit.build(ctx, "mammothGraveyard", "landmark", s.x, s.z, s.rot)
	local bp = b.bp
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	-- the biggest lies beside the road (local +Z is east of the site at rot 90: the road runs past at ~+45 studs)
	Props.mammothSkeleton(bp, ground, 0, 0, 1.6, 20, "shell")
	for k, p in { { -22, 14, 0.9, 130 }, { 18, -20, 1.1, 250 }, { -16, -24, 0.8, 60 }, { 26, 16, 0.7, 300 } } do
		Props.mammothSkeleton(bp, ground, p[1], p[2], p[3], p[4], if k <= 2 then "detail" else "fine")
	end
	table.insert(out, b)
	-- the tusk arch over the tundra road
	local ax, az = 285, -470
	local arch = Kit.build(ctx, "TuskArch", "landmark", ax, az, 0)
	local abp = arch.bp
	for _, side in { -1, 1 } do
		local base = Kit.gy(ctx, arch, side * 9, 0)
		abp:beam(side * 9, base - 1, 0, side * 7, base + 10, -1, 1.4, o(Props.tusk, "shell", { q = false }))
		abp:beam(side * 7, base + 10, -1, side * -2, base + 17, -1.6, 1.1, o(Props.tusk, "shell", { q = false }))
		abp:add("ball", 3.4, 3.4, 3.4, side * 9, base + 0.6, 0, 0, 0, 0, o(Kit.oldBone, "detail", { col = false }))
	end
	Env.clear(env, ax, az, 12)
	table.insert(out, arch)
end

local function huntingCamp(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.huntingCamp
	Env.clear(env, s.x, s.z, 30)
	local hearth = Kit.build(ctx, "huntingCamp", "camp", s.x, s.z, s.rot)
	local bp = hearth.bp
	local y = Kit.gy(ctx, hearth, 0, 0)
	Kit.campfire(bp, 0, y, 0, "shell")
	bp:add("cyl", 1, 8, 8, 0, y + 0.1, 0, 0, 0, 90, o({ c = "#3A342E", m = "Slate" }, "detail", { col = false }))
	Kit.lifeAt(ctx, hearth, "smokeColumn", 0, 2, 0)
	-- a smoking rack of meat over the embers (the smoke tag: the client's chimney smoke)
	bp:box(1.6, 0.6, 1.6, 0, y + 6.4, 0, o(Props.oldWood, "shell", { q = false, tag = "smoke" }))
	-- racks of giant spears, a drying rack of meat, a heap of skulls
	for k = 0, 1 do
		local lx = -10 + k * 20
		for _, side in { -1, 1 } do
			bp:box(
				0.6,
				7,
				0.6,
				lx + side * 3,
				Kit.gy(ctx, hearth, lx, -12) + 3.4,
				-12,
				o(Props.oldWood, "detail", { col = false })
			)
		end
		bp:box(7, 0.5, 0.5, lx, Kit.gy(ctx, hearth, lx, -12) + 6.6, -12, o(Props.oldWood, "detail", { col = false }))
		for m = -2, 2 do
			if k == 0 then
				bp:rbox(
					0.5,
					15,
					0.5,
					lx + m * 1.2,
					Kit.gy(ctx, hearth, lx, -12) + 7,
					-12.6,
					10,
					0,
					m * 2,
					o(Props.oldWood, "detail", { col = false })
				)
				bp:add(
					"wedge",
					0.6,
					2,
					0.8,
					lx + m * 1.2 + 0.2,
					Kit.gy(ctx, hearth, lx, -12) + 15,
					-14,
					10,
					0,
					0,
					o(Kit.stone, "fine", { col = false })
				)
			else
				bp:box(
					1,
					2.4,
					0.6,
					lx + m * 1.2,
					Kit.gy(ctx, hearth, lx, -12) + 5,
					-12,
					o({ c = "#6A2A22", m = "SmoothPlastic" }, "fine", { col = false })
				)
			end
		end
	end
	for k = 1, 7 do
		local a = k * 0.9
		Kit.skull(
			bp,
			12 + math.cos(a) * 1.4,
			Kit.gy(ctx, hearth, 12, 8) + (if k > 4 then 1 else 0),
			8 + math.sin(a) * 1.4,
			2.4,
			k * 50
		)
	end
	-- the pit trap with stakes
	bp:add(
		"cyl",
		0.3,
		8,
		8,
		-14,
		Kit.gy(ctx, hearth, -14, 10) + 0.05,
		10,
		0,
		0,
		90,
		o(Kit.dark, "detail", { col = false, t = 0.2 })
	)
	for k = 0, 5 do
		local a = k * math.pi / 3
		bp:rbox(
			0.4,
			3,
			0.4,
			-14 + math.cos(a) * 2.4,
			Kit.gy(ctx, hearth, -14, 10) + 0.6,
			10 + math.sin(a) * 2.4,
			14,
			math.deg(a),
			0,
			o(Props.oldWood, "fine", { col = false })
		)
	end
	table.insert(out, hearth)
	-- hide tents round the hearth
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.6
		local tx, tz = s.x + math.cos(a) * 20, s.z + math.sin(a) * 20
		local t = Kit.build(ctx, `HuntTent_{k}`, "camp", tx, tz, math.deg(math.atan2(math.cos(a), math.sin(a))))
		Props.hideTent(t.bp, 0, Kit.gy(ctx, t, 0, 0), 0, 1.4, 0, true)
		Env.clear(env, tx, tz, 8)
		table.insert(out, t)
	end
end

-- Erratic boulders with fur where the mammoths rub, grazing patches, herd trails.
local function traces(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in { { 60, -420 }, { 180, -640 }, { 400, -460 }, { 40, -560 }, { 420, -720 } } do
		if Env.isClear(env, p[1], p[2], 6) and env.T.roadDistance(p[1], p[2]) > 12 then
			local b = Kit.build(ctx, `Erratic_{i}`, "rocks", p[1], p[2], i * 47)
			local bp = b.bp
			local y = Kit.gy(ctx, b, 0, 0)
			Props.boulder(bp, 0, y, 0, 6 + (i % 2) * 2)
			Props.fur(bp, 3.4, y + 2, 1, Props.mammothFur)
			Props.fur(bp, -2, y + 3, 3, Props.mammothFur)
			for k = 1, 3 do
				local lx, lz = 8 + k * 3, -6 + k * 4
				bp:add(
					"cyl",
					0.1,
					5,
					5,
					lx,
					Kit.gy(ctx, b, lx, lz) + 0.06,
					lz,
					0,
					0,
					90,
					o({ c = "#6E7244", m = "Grass" }, "fine", { col = false })
				)
			end
			Env.clear(env, p[1], p[2], 10)
			table.insert(out, b)
		end
	end
	local trail = Kit.build(ctx, "HerdTrail", "traces", 120, -540, 0)
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, trail, lx, lz)
	end
	for k = 0, 3 do
		Props.tracks(trail.bp, ground, -60 + k * 5, 60 - k * 3, 40, 20, 3, 6)
	end
	table.insert(out, trail)
end

function Tundra.all(env: Env.Env, out: { Build })
	graveyard(env, out)
	huntingCamp(env, out)
	traces(env, out)
end

return Tundra
