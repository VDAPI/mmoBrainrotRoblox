--!strict
-- Ash Road (61–67, more gold) (S46): the old royal road of cracked slabs, half buried in ash.
--   * the Avenue of Kings (the landmark): colossal kings on both sides of the road, some standing, some lying broken
--     on the verge,
--   * the stone caravan: a wagon, two oxen and their people frozen in flight, grey as stone (the basilisk's work),
--     coins spilt beside it,
--   * robbed wagons with broken crates and scattered coins (the gold profile), some burnt by wyvern fire, claw
--     furrows in their covers,
--   * obelisks as milestones, the basilisk's pit (a rocky hollow with a shed skin, petrified hyenas and vultures). Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o

local Road = {}

type Build = Kit.Build

local ROYAL = 8 -- index of the royal road in Data/Areas/ashen roads

local function avenue(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "kingsAvenue", "landmark", 12)
	local bp = b.bp
	local stone = { c = "#7A7066", m = "Slate" }
	for k = -3, 3 do
		local lz = k * 40
		for _, side in { -1, 1 } do
			local fallen = (k + side) % 4 == 0
			local lx = side * (if fallen then 22 else 15)
			local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, lx, lz)
			Env.clear(env, wx, wz, 6)
			local y = Kit.gy(ctx, b, lx, lz)
			if fallen then
				-- lying broken on the verge: the body on its side, the head rolled away
				bp:push(lx, y + 1.6, lz, 0, 0, side * 90)
				bp:box(3.4, 7, 2.6, 0, 3, 0, o(stone, "shell", { q = false }))
				bp:box(5, 2, 5, 0, -1, 0, o(stone, "detail", { col = false }))
				bp:pop()
				bp:add(
					"ball",
					2.2,
					2.4,
					2.2,
					lx + side * 4,
					Kit.gy(ctx, b, lx + side * 4, lz + 7) + 0.9,
					lz + 7,
					0,
					0,
					40,
					o(stone, "detail", { col = false })
				)
			else
				Props.king(bp, lx, y - 0.3, lz, 1.5, if side == 1 then 90 else 270, stone)
			end
		end
	end
	Kit.rect(ctx, "building", b.at.x, b.at.z, 34, 260, b.at.rot)
	table.insert(out, b)
end

local function caravan(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "stoneCaravan", "statue", 16)
	local bp = b.bp
	local st = Props.petrified
	bp:box(5, 0.8, 9, 0, 2.4, 0, o(st, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:box(0.4, 1.6, 9, side * 2.5, 3.4, 0, o(st, "detail", { col = false }))
		for _, dz in { -3, 3 } do
			bp:add("cyl", 0.5, 3.2, 3.2, side * 2.8, 1.6, dz, 0, 0, 0, o(st, "detail", { col = false }))
		end
	end
	for k = -1, 1 do
		bp:rbox(5.4, 0.3, 2.4, 0, 5.4, k * 2.8, 0, 0, k * 6, o(st, "detail", { col = false }))
	end
	Props.ox(bp, -1.8, Kit.gy(ctx, b, -1.8, -9), -9, 0, st)
	Props.ox(bp, 1.8, Kit.gy(ctx, b, 1.8, -9), -9, 0, st, "shell")
	for k, p in { { -5, -4, 200 }, { 5, 2, 170 }, { -4, 7, 150 } } do
		Props.person(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2], p[3], k - 2, st)
	end
	Props.coins(bp, 4, Kit.gy(ctx, b, 4, 7), 7, 12)
	Props.crate(bp, -5, Kit.gy(ctx, b, -5, 9), 9, 2.2, true)
	table.insert(out, b)
end

local function robbed(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "robbedWagons", "camp", 16)
	local bp = b.bp
	Props.wagon(bp, -5, Kit.gy(ctx, b, -5, 0), 0, 20, false, true, true)
	Props.wagon(bp, 7, Kit.gy(ctx, b, 7, -8), -8, 120, true, false, true)
	for _ = 1, 5 do
		local lx, lz = bp.rng:float(-12, 12), bp.rng:float(-12, 12)
		Props.crate(bp, lx, Kit.gy(ctx, b, lx, lz), lz, 2.2, true)
		Props.coins(bp, lx, Kit.gy(ctx, b, lx, lz), lz, 5)
	end
	bp:add("ball", 7, 0.1, 5, 2, Kit.gy(ctx, b, 2, 6) + 0.05, 6, 0, 0, 0, o(Props.soot, "fine"))
	Kit.lifeAt(ctx, b, "vultures", 0, 42, 0, 20)
	table.insert(out, b)
end

local function milestones(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local line = env.T.roadLine(ROYAL)
	local i = 0
	local s = 70
	while s < line.length - 40 do
		local x, z, dx, dz = TerrainLayers.pointAt(line, s)
		i += 1
		local side = if i % 2 == 0 then 1 else -1
		local px, pz = x - dz * 12 * side, z + dx * 12 * side
		if Env.isClear(env, px, pz, 2) then
			Env.clear(env, px, pz, 4)
			local b = Kit.build(ctx, `Milestone_{i}`, "statue", px, pz, 0)
			Props.obelisk(b.bp, 0, 0, 0, 10, Props.paleStone)
			table.insert(out, b)
		end
		s += 150
	end
end

local function den(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "basiliskDen", "traces", 26)
	local bp = b.bp
	for k = 0, 8 do
		local a = k * math.pi * 2 / 9
		local lx, lz = math.cos(a) * 22, math.sin(a) * 18
		Kit.rock(
			bp,
			lx,
			Kit.gy(ctx, b, lx, lz) - 0.6,
			lz,
			3 + (k % 3),
			Props.rust,
			if k % 2 == 0 then "shell" else "detail"
		)
	end
	-- the shed skin: a long olive ribbon in coils
	for k = 0, 9 do
		local a = k * 0.7
		local lx, lz = math.cos(a) * (3 + k * 0.6), math.sin(a) * (3 + k * 0.6)
		bp:rbox(
			0.9,
			0.12,
			2.4,
			lx,
			Kit.gy(ctx, b, lx, lz) + 0.08,
			lz,
			0,
			math.deg(-a),
			0,
			o({ c = "#7A8A5A", m = "SmoothPlastic" }, "fine", { t = 0.25 })
		)
	end
	for k, p in { { -12, 4, 30 }, { 9, -8, 200 }, { 14, 6, 120 } } do
		if k == 3 then
			bp:add(
				"ball",
				1.4,
				1.6,
				2,
				p[1],
				Kit.gy(ctx, b, p[1], p[2]) + 0.9,
				p[2],
				0,
				0,
				0,
				o(Props.petrified, "detail", { col = false })
			)
			bp:rbox(
				3.4,
				0.3,
				1.2,
				p[1],
				Kit.gy(ctx, b, p[1], p[2]) + 1.4,
				p[2],
				0,
				0,
				30,
				o(Props.petrified, "detail", { col = false })
			)
		else
			Props.ox(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2], p[3], Props.petrified)
		end
	end
	table.insert(out, b)
end

function Road.all(env: Env.Env, out: { Build })
	avenue(env, out)
	caravan(env, out)
	robbed(env, out)
	milestones(env, out)
	den(env, out)
end

return Road
