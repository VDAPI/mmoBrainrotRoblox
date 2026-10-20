--!strict
-- W19-20 (docs/wyglad/mapy/szczyty.md, part 2): the look of the Frost Peaks the plan still asked for, built after the
-- secrets (./Details) without clearings, so nothing earlier moves; every Build is named Detail_* and nothing in here
-- collides (no path, NPC, anchor, portal or monster group is blocked):
--   * 1.10.2 / the shared language ("warmth saves"): a warm brazier with two log seats and a stack of firewood beside
--     every respawn point, off the road and the spot itself, behind the way the player looks,
--   * 1.6 view 2: the order's cairn with a banner frozen in mid-flap on the South Ridge's saddle beside the lake road
--     (the foreground of the view south over the lake),
--   * 1.9 Z1, drawn as props (the plan's fallback: no road entry, so no group or node moves): the pilgrims' trail of
--     trodden snow from the temple road south to the corner of the Ice Watch's patrol ring (the ground on the way is
--     already flat and walkable), two baskets of blue fire where it leaves the temple road. Pure.

local AreaSpawns = require("../AreaSpawns")
local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Maps = require("../../Data/Maps")
local Props = require("./Props")
local Shapes = require("../../Data/Terrain")

local o = Kit.o

local Scenery = {}

type Build = Kit.Build

local SHAPE = Shapes.byMap.frostpeak
local WARM = "#FF9A3A" -- szczyty.md: warm light only where people are
local TRODDEN = { c = "#C6D0D8", m = "Snow" }
local FIREWOOD = { c = "#5A4636", m = "Wood" }

-- Points nothing of this module may stand on or crowd: monster groups, NPC places, quest anchors, portals, caves.
local function keepOut(env: Env.Env): { { x: number, z: number, r: number } }
	local out = {}
	local map = Maps.get("frostpeak")
	for _, s in AreaSpawns.region(env.areas, if map then map.size else { x = 1600, z = 1600 }) do
		table.insert(out, { x = s.position.x, z = s.position.z, r = 12 })
	end
	for _, spot in assert(env.areas.npcSpots, "npcSpots") do
		table.insert(out, { x = spot.x, z = spot.z, r = 6 })
	end
	for _, a in assert(env.areas.questAnchors, "questAnchors") do
		table.insert(out, { x = a.x, z = a.z, r = 6 })
	end
	for _, p in { { -770, 0 }, { -770, 160 } } do
		table.insert(out, { x = p[1], z = p[2], r = 24 })
	end
	for _, c in env.areas.caves do
		table.insert(out, { x = c.x, z = c.z, r = 28 })
	end
	return out
end

local function free(env: Env.Env, keep: { { x: number, z: number, r: number } }, x: number, z: number): boolean
	local T = env.T
	if not Env.safe(env, x, z, 8) or T.roadDistance(x, z) < 3 or T.slope(x, z, 2) > 0.45 then
		return false
	end
	for _, k in keep do
		if (x - k.x) ^ 2 + (z - k.z) ^ 2 < k.r * k.r then
			return false
		end
	end
	return true
end

-- A brazier of warm fire, two logs to sit on and a stack of firewood, around the Build's origin.
local function restFire(env: Env.Env, b: Build)
	local bp = b.bp
	local gy = Kit.gy(env.ctx, b, 0, 0)
	Props.brazier(bp, 0, gy, 0, WARM, "detail")
	for _, side in { -1, 1 } do
		local lx, lz = side * 3.2, 1.2
		bp:add(
			"cyl",
			3,
			1,
			1,
			lx,
			Kit.gy(env.ctx, b, lx, lz) + 0.45,
			lz,
			0,
			side * 25,
			0,
			o(Props.frozenWood, "detail", { col = false })
		)
		Props.snowCap(bp, lx, Kit.gy(env.ctx, b, lx, lz) + 0.95, lz, 2.4, 0.8, "fine")
	end
	for k = 0, 2 do
		bp:add(
			"cyl",
			1.8,
			0.5,
			0.5,
			0,
			Kit.gy(env.ctx, b, 0, -2.6) + 0.25 + k * 0.45,
			-2.6 + (k % 2) * 0.2,
			0,
			90,
			0,
			o(FIREWOOD, "fine", { col = false })
		)
	end
end

-- Every respawn point: the first free spot 7-9 studs away, starting behind and to the left of the way it looks.
local function restFires(env: Env.Env, keep: { { x: number, z: number, r: number } }, out: { Build })
	for i, r in SHAPE.respawns do
		local look = math.atan2((r.lookZ or r.z) - r.z, (r.lookX or r.x + 1) - r.x)
		local done = false
		for _, d in { 8, 9, 7 } do
			for step = 0, 11 do
				local a = look + math.pi * 0.75 + (if step % 2 == 0 then 1 else -1) * (step // 2) * math.pi / 6
				local x, z = r.x + math.cos(a) * d, r.z + math.sin(a) * d
				if free(env, keep, x, z) then
					-- the logs' side (local Z) faces the respawn point
					local yaw = math.deg(math.atan2(-(r.x - x), -(r.z - z))) + 180
					local b = Kit.build(env.ctx, `Detail_RestFire_{i}`, "traces", x, z, yaw)
					restFire(env, b)
					table.insert(out, b)
					done = true
					break
				end
			end
			if done then
				break
			end
		end
	end
end

-- The order's cairn with a frozen banner on the saddle, beside the highest point of the lake road.
local function saddleCairn(env: Env.Env, keep: { { x: number, z: number, r: number } }, out: { Build })
	local T = env.T
	local x1, z1, x2, z2 = 0, 0, 120, 440 -- the lake road (Data/Areas/frostpeak roads[4])
	local best, bestH = 0.5, -math.huge
	for t = 0.4, 0.85, 0.01 do
		local h = T.height(x1 + (x2 - x1) * t, z1 + (z2 - z1) * t)
		if h > bestH then
			bestH, best = h, t
		end
	end
	local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	local ux, uz = (x2 - x1) / len, (z2 - z1) / len
	local cx, cz = x1 + (x2 - x1) * best, z1 + (z2 - z1) * best
	for _, off in { 10, 12, 14, -10, -12, -14 } do
		for _, along in { 6, 0, 12 } do
			-- west of the road (left looking south) first, a little down the south side
			local x, z = cx - uz * off + ux * along, cz + ux * off + uz * along
			if free(env, keep, x, z) then
				local b = Kit.build(env.ctx, "Detail_SaddleCairn", "traces", x, z, 0)
				local bp = b.bp
				local gy = Kit.gy(env.ctx, b, 0, 0)
				for k = 0, 4 do
					Kit.rock(bp, (k % 2) * 0.3 - 0.15, gy + k * 0.7, 0, 1.7 - k * 0.28, Props.frostStone, "detail")
				end
				Props.snowCap(bp, 0, gy + 3.4, 0, 1.3, 1.1, "fine")
				Props.banner(bp, 1.2, gy, 0.6, 7, Props.orderDark, Props.orderPale, true, "detail")
				table.insert(out, b)
				return
			end
		end
	end
end

-- Z1 as props: the trodden trail (one strip per ~6 studs, tilted with the ground) and two baskets of blue fire.
local PILGRIM = { { 470, 12 }, { 470, 250 }, { 520, 400 }, { 548, 474 } }

local function pilgrimTrail(env: Env.Env, keep: { { x: number, z: number, r: number } }, out: { Build })
	local T = env.T
	-- a Build per ten strips, so the client builds only the stretch near its camera
	local b: Build? = nil
	local strips, n = 0, 0
	for i = 1, #PILGRIM - 1 do
		local a, c = PILGRIM[i], PILGRIM[i + 1]
		local dx, dz = c[1] - a[1], c[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		local count = math.max(1, math.floor(len / 6 + 0.5))
		local seg = len / count
		local yaw = math.deg(math.atan2(-ux, -uz))
		for k = 0, count - 1 do
			local s0, s1 = k * seg, (k + 1) * seg
			local x0, z0 = a[1] + ux * s0, a[2] + uz * s0
			local x1, z1 = a[1] + ux * s1, a[2] + uz * s1
			local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
			if Env.safe(env, mx, mz, 4) and T.roadDistance(mx, mz) > 1 then
				if not b or strips >= 10 then
					n += 1
					strips = 0
					b = Kit.build(env.ctx, `Detail_PilgrimTrail_{n}`, "traces", mx, mz, 0)
					table.insert(out, b :: Build)
				end
				local tb = b :: Build
				strips += 1
				local h0, h1 = T.height(x0, z0), T.height(x1, z1)
				-- a strip along its local -Z (yaw), pitched up toward the higher end
				local pitch = math.deg(math.atan2(h1 - h0, seg))
				tb.bp:push(mx - tb.at.x, (h0 + h1) / 2 - tb.at.y + 0.05, mz - tb.at.z, 0, yaw, 0)
				tb.bp:rbox(5.4, 0.1, seg + 0.6, 0, 0, 0, pitch, 0, 0, o(TRODDEN, "detail", { col = false }))
				tb.bp:pop()
			end
		end
	end
	-- the two baskets either side of the trail where it leaves the temple road
	local first, second = PILGRIM[1], PILGRIM[2]
	local along = 14 / (second[2] - first[2])
	for i, side in { -1, 1 } do
		local x, z = first[1] + side * 6, first[2] + (second[2] - first[2]) * along
		if free(env, keep, x, z) then
			local bb = Kit.build(env.ctx, `Detail_PilgrimFire_{i}`, "traces", x, z, 0)
			Props.brazier(bb.bp, 0, Kit.gy(env.ctx, bb, 0, 0), 0, Props.ICEFIRE, "detail")
			table.insert(out, bb)
		end
	end
end

function Scenery.all(env: Env.Env, out: { Build })
	local keep = keepOut(env)
	restFires(env, keep, out)
	saddleCairn(env, keep, out)
	pilgrimTrail(env, keep, out)
end

return Scenery
