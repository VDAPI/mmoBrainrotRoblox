--!strict
-- W20 (docs/wyglad/mapy/szczyty.md 1.5): the secrets of Frostpeak for players who look around. Built after
-- everything (trees included) and without clearings, so nothing earlier moves; every Build is named Detail_*.
--   1. the order's cairn with a shield (the petal and the thorn) on the Gate Spur lookout,
--   2. the queen's relief on the upper terrace's retaining wall north of the stairs: a woman with a spear over a
--      sleeping dragon, the same scene as the Vael manor's window in the Duskwood,
--   3. bare human footprints on the Bone Trail between the brood's tracks, up to the Rite Circle,
--   4. by the Harpy Tarn's ice hole: the angler's sled overturned and a small fire (warmth = safety);
-- and from the 1.4 table: the pilgrims' armour thrown down by the Buried Camp. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Details = {}

type Build = Kit.Build

local function cairn(env: Env.Env, out: { Build })
	local b = Kit.build(env.ctx, "Detail_OrderCairn", "traces", 95, -190, 200)
	local bp = b.bp
	local gy = Kit.gy(env.ctx, b, 0, 0)
	for k = 0, 4 do
		local s = 1.8 - k * 0.3
		Kit.rock(bp, (k % 2) * 0.3, gy + k * 0.75, 0, s, Props.frostStone, if k < 2 then "shell" else "detail")
	end
	-- the shield driven into the stones, facing local -Z
	bp:rbox(2.2, 2.8, 0.25, 0, gy + 2.6, -1.1, -10, 0, 4, o(Props.orderDark, "detail", { col = false }))
	bp:rbox(0.9, 1.3, 0.1, 0, gy + 2.7, -1.27, -10, 0, 4, o(Props.orderPale, "fine", { col = false }))
	bp:rbox(0.1, 1.7, 0.1, 0.1, gy + 2.6, -1.33, -10, 0, 40, o(Props.iron, "fine", { col = false }))
	Props.snowCap(bp, 0, gy + 3.6, 0, 1.4, 1.2, "fine")
	table.insert(out, b)
end

local function queenRelief(out: { Build })
	-- the upper terrace wall (Temple EDGES[3]: x 650, base 42): its west face at x 641.5, north of the stairs
	local b = Kit.buildAt("Detail_QueenRelief", "wall", 641.2, 44, -34, 0)
	local bp = b.bp
	local worn = { c = "#A8B4BE", m = "Slate" }
	bp:box(0.3, 4.6, 8, 0, 2.6, 0, o(Props.darkStone, "detail", { col = false }))
	-- the sleeping dragon along the bottom, head on its forepaws
	bp:add("ball", 0.4, 1.3, 5.4, -0.2, 1.1, 0.6, 0, 0, 0, o(worn, "detail", { col = false }))
	bp:add("ball", 0.4, 0.9, 1.3, -0.2, 1, -2.6, 0, 0, 0, o(worn, "fine", { col = false }))
	bp:rbox(0.35, 0.3, 1.6, -0.2, 1.6, 3.6, 30, 0, 0, o(worn, "fine", { col = false }))
	-- the queen standing over it, the spear held down toward its head
	bp:rbox(0.4, 2.6, 1.1, -0.25, 3.3, -0.4, 0, 0, 0, o(worn, "detail", { col = false }))
	bp:add("ball", 0.4, 0.7, 0.6, -0.25, 4.9, -0.4, 0, 0, 0, o(worn, "fine", { col = false }))
	bp:rbox(0.2, 0.2, 4.2, -0.3, 2.9, -1.7, -32, 0, 0, o(worn, "fine", { col = false }))
	table.insert(out, b)
end

local function barefoot(env: Env.Env, out: { Build })
	local x1, z1, x2, z2 = 420, -540, 622, -572
	local b = Kit.build(env.ctx, "Detail_BarefootSteps", "traces", x1, z1, 0)
	local bp = b.bp
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	local ux, uz = dx / len, dz / len
	local yaw = math.deg(math.atan2(-ux, -uz))
	local n = math.floor(len / 3.2)
	for i = 0, n do
		local side = if i % 2 == 0 then 0.35 else -0.35
		local lx, lz = ux * i * 3.2 - uz * side, uz * i * 3.2 + ux * side
		bp:rbox(
			0.45,
			0.06,
			1,
			lx,
			Kit.gy(env.ctx, b, lx, lz) + 0.05,
			lz,
			0,
			yaw,
			0,
			o({ c = "#9AAAB6", m = "Snow" }, "fine", { col = false })
		)
	end
	table.insert(out, b)
end

local function anglerCamp(env: Env.Env, out: { Build })
	-- on the dry shore east of the ice hole (the fishing spot stays clear)
	local b = Kit.build(env.ctx, "Detail_AnglerCamp", "traces", -537, 622, 90)
	local bp = b.bp
	local gy = Kit.gy(env.ctx, b, 0, 0)
	-- the sled on its side: two runners up, the slatted bed
	bp:rbox(1.6, 0.25, 4, 2.6, gy + 0.8, 0, 0, 0, 80, o(Props.oldWood, "detail", { col = false }))
	for _, s in { -1, 1 } do
		bp:rbox(0.15, 0.3, 4.4, 2.1, gy + 0.8 + s * 0.7, 0.1, 0, 0, 80, o(Props.iron, "fine", { col = false }))
	end
	-- a small fire ringed with stones, smoke rising
	Kit.campfire(bp, -1.6, gy, 0.6, "detail")
	Kit.lifeAt(env.ctx, b, "smoke", -1.6, gy + 2, 0.6, 1)
	-- the rod propped on a forked stick toward the hole
	bp:beam(-0.6, gy + 0.6, -1.4, 1.2, gy + 2.6, -4.6, 0.08, o(Props.oldWood, "fine", { col = false }))
	table.insert(out, b)
end

-- 1.4: the pilgrims' armour thrown down outside the Buried Camp (546, 50, r 22), half under the snow (the north side,
-- away from the road).
local function pilgrimArmour(env: Env.Env, out: { Build })
	local b = Kit.build(env.ctx, "Detail_PilgrimArmour", "traces", 546, 78, 0)
	local bp = b.bp
	for k, p in { { -8, 0 }, { 0, 2 }, { 9, -1 } } do
		local lx, lz = p[1], p[2]
		local gy = Kit.gy(env.ctx, b, lx, lz)
		bp:rbox(1.8, 0.9, 1.4, lx, gy + 0.3, lz, 70, k * 50, 0, o(Props.iron, "detail", { col = false }))
		bp:add("ball", 1, 0.9, 1.1, lx + 1.4, gy + 0.3, lz + 0.6, 0, k * 30, 30, o(Props.iron, "fine", { col = false }))
		bp:rbox(1.6, 0.1, 1.2, lx - 0.4, gy + 0.08, lz - 0.9, 0, k * 40, 0, o(Props.cultBlue, "fine", { col = false }))
		Props.snowCap(bp, lx, gy + 0.6, lz, 2.4, 1.8, "fine")
	end
	table.insert(out, b)
end

function Details.all(env: Env.Env, out: { Build })
	cairn(env, out)
	queenRelief(out)
	barefoot(env, out)
	anglerCamp(env, out)
	pilgrimArmour(env, out)
end

return Details
