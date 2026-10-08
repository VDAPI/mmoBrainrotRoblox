--!strict
-- Bear Hollow (21–27, better drop) (S45): a gorge full of roots and ferns.
--   * the fallen giant: a colossal trunk lying across the gorge like a bridge (collides, walkable), its root plate
--     on one rim and the broken crown on the other,
--   * the lost hunters' camp on the gorge floor (collapsed shelter, bedrolls, a rack of raw hides, a broken chest, a
--     crossbow, scattered arrows, a lantern on a branch): the hollow's lure and its better drop,
--   * bear dens under upturned root plates with fish bones and broken brush, the werewolf's trail of paw prints
--     down from the thicket with grey fur on the roots. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Hollow = {}

type Build = Kit.Build

local EARTH = { c = "#3A3128", m = "Ground" }

-- Upturned root plate (a disc of earth and roots standing on edge) facing local -Z, at (x, y, z) of the frame.
local function rootPlate(bp: Kit.BP, x: number, y: number, z: number, yaw: number, d: number, lod: any)
	bp:push(x, y, z, 0, yaw, 0)
	bp:add("cyl", 2.6, d, d, 0, d * 0.42, 0, 0, 90, 0, o(EARTH, lod, { q = false }))
	for i = 0, 7 do
		local a = i * math.pi / 4
		bp:beam(
			math.cos(a) * d * 0.2,
			d * 0.42 + math.sin(a) * d * 0.2,
			-1.4,
			math.cos(a) * d * 0.55,
			d * 0.42 + math.sin(a) * d * 0.55,
			-2.4,
			0.5,
			o(Kit.darkBark, "detail", { col = false })
		)
	end
	bp:pop()
end

local function fallenGiant(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.fallenGiant
	Env.clear(env, s.x, s.z, 18)
	-- the gorge runs north-east -> south-west here; the trunk lies across it
	local gx, gz = -0.807, 0.59
	local px, pz = gz, -gx -- perpendicular
	local half = 46
	local ax, az = s.x - px * half, s.z - pz * half
	local bx, bz = s.x + px * half, s.z + pz * half
	local b = Kit.buildAt("FallenGiant", "landmark", s.x, 0, s.z, 0)
	local bp = b.bp
	local ya, yb = env.T.height(ax, az) + 2.6, env.T.height(bx, bz) + 2.6
	local dx, dy, dz = bx - ax, yb - ya, bz - az
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	local yaw = math.deg(math.atan2(-dz, dx))
	local pitch = math.deg(math.asin(dy / len))
	bp:add(
		"cyl",
		len,
		7.5,
		7.5,
		(ax + bx) / 2 - s.x,
		(ya + yb) / 2,
		(az + bz) / 2 - s.z,
		0,
		yaw,
		pitch,
		o({ c = "#3A2E24", m = "Wood" }, "shell", { q = true, col = true })
	)
	-- the root plate at the north-west end, the broken crown at the other
	rootPlate(bp, ax - s.x - px * 4, ya - 4.5, az - s.z - pz * 4, yaw + 90, 16, "shell")
	for i = 1, 4 do
		local a = i * 1.5
		bp:beam(
			bx - s.x,
			yb + 1,
			bz - s.z,
			bx - s.x + px * 10 + math.cos(a) * 5,
			yb + 3 + math.sin(a) * 4,
			bz - s.z + pz * 10 + math.sin(a) * 5,
			1.4,
			o(Kit.darkBark, if i == 1 then "shell" else "detail", { col = false })
		)
	end
	-- moss and ferns on the trunk
	for k = 1, 6 do
		local t = k / 7
		bp:box(
			3,
			0.4,
			2.4,
			ax + dx * t - s.x,
			ya + dy * t + 3.6,
			az + dz * t - s.z,
			o(Kit.moss, "fine", { col = false })
		)
	end
	Kit.circle(ctx, "bridge", s.x, s.z, 4)
	Kit.line(ctx, "bridge", { ax, az, bx, bz }, 7)
	table.insert(out, b)
end

local function lostCamp(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "lostCamp", "camp", 14)
	local bp = b.bp
	-- collapsed lean-to
	local gy = Kit.gy(ctx, b, 0, 4)
	bp:rbox(9, 0.4, 6, 0, gy + 1.6, 4, -20, 0, 8, o(Kit.greyPlanks, "shell", { q = true }))
	bp:rbox(0.5, 4.5, 0.5, -4, gy + 1.8, 1.5, 0, 0, 30, o(Kit.timber, "detail", { col = false }))
	bp:rbox(0.5, 3, 0.5, 4, gy + 1.4, 1.5, 0, 0, -10, o(Kit.timber, "detail", { col = false }))
	Props.bedroll(bp, -2, Kit.gy(ctx, b, -2, 6), 6, 90)
	Props.bedroll(bp, 3, Kit.gy(ctx, b, 3, 7), 7, 70)
	Props.rack(bp, 8, Kit.gy(ctx, b, 8, -3), -3, 60, Kit.hide, 3)
	-- the broken chest, the crossbow and arrows, a lantern on a branch
	local cy = Kit.gy(ctx, b, -6, -4)
	bp:rbox(3, 1.6, 2, -6, cy + 0.8, -4, 0, 20, 0, o(Kit.planks, "detail", { col = false }))
	bp:rbox(3, 0.3, 2, -6.4, cy + 2.2, -5.4, 50, 20, 0, o(Kit.planks, "detail", { col = false }))
	Props.coins(bp, -6, cy + 1.6, -4, 4)
	bp:rbox(2.4, 0.3, 0.4, -2, Kit.gy(ctx, b, -2, -7) + 0.2, -7, 0, 30, 0, o(Kit.timber, "fine"))
	bp:rbox(0.3, 0.2, 2.2, -2, Kit.gy(ctx, b, -2, -7) + 0.3, -7, 0, 30, 0, o(Kit.iron, "fine"))
	Props.brokenBow(bp, 2, Kit.gy(ctx, b, 2, -6), -6, 100)
	Kit.lantern(bp, 6, Kit.gy(ctx, b, 6, 5), 5, nil, 5, "detail")
	local fy = Kit.gy(ctx, b, 1, -1)
	for i = 0, 2 do
		bp:add("cyl", 2.6, 0.5, 0.5, 1, fy + 0.3, -1, 0, i * 60, 8, o(Kit.charred, "detail", { col = false }))
	end
	table.insert(out, b)
end

-- Bear dens under upturned root plates (fish bones, broken brush) and the werewolf's trail into the gorge.
local DENS = { { -700, 486, 120 }, { -436, 640, 300 }, { -560, 744, 200 } }
local TRAIL = { { -612, 300 }, { -604, 350 }, { -590, 396 }, { -572, 444 }, { -562, 490 }, { -548, 530 } }

local function dens(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, d in DENS do
		Env.clear(env, d[1], d[2], 14)
		local b = Kit.build(ctx, `BearDen_{i}`, "den", d[1], d[2], d[3])
		local bp = b.bp
		rootPlate(bp, 0, Kit.gy(ctx, b, 0, 2) - 2, 2, 0, 13, "shell")
		bp:add(
			"cyl",
			18,
			3.4,
			3.4,
			0,
			Kit.gy(ctx, b, 0, 12) + 1.2,
			12,
			0,
			90,
			4,
			o(Kit.darkBark, "shell", { q = false })
		)
		bp:add("ball", 8, 3, 6, 0, Kit.gy(ctx, b, 0, -3) - 0.6, -3, 0, 0, 0, o(Kit.dark, "detail", { col = false }))
		for k = 1, 3 do
			local lx, lz = -4 + k * 2.4, -7 - k
			local gy = Kit.gy(ctx, b, lx, lz)
			bp:rbox(1.4, 0.1, 0.2, lx, gy + 0.08, lz, 0, k * 40, 0, o(Kit.oldBone, "fine"))
			for f = -1, 1 do
				bp:rbox(0.06, 0.06, 0.5, lx + f * 0.3, gy + 0.1, lz, 0, k * 40, 0, o(Kit.oldBone, "fine"))
			end
		end
		for k = 1, 4 do
			local a = k * 1.6
			bp:beam(
				math.cos(a) * 6,
				Kit.gy(ctx, b, math.cos(a) * 6, math.sin(a) * 6) + 0.2,
				math.sin(a) * 6,
				math.cos(a) * 8,
				Kit.gy(ctx, b, math.cos(a) * 8, math.sin(a) * 8) + 1.6,
				math.sin(a) * 8,
				0.3,
				o(Kit.darkBark, "detail", { col = false })
			)
		end
		Props.clawedStump(bp, 7, Kit.gy(ctx, b, 7, -4), -4, 5, 30)
		table.insert(out, b)
	end
	for i, p in TRAIL do
		local x, z = p[1] + 7, p[2]
		local b = Kit.build(ctx, `WolfTrail_{i}`, "traces", x, z, 0)
		for k = 0, 2 do
			local lz = k * 6
			Props.paw(b.bp, (k % 2) * 1.6, Kit.gy(ctx, b, (k % 2) * 1.6, lz), lz, 180, true)
		end
		if i % 2 == 0 then
			Props.fur(b.bp, 2.5, Kit.gy(ctx, b, 2.5, 3) + 0.5, 3)
		end
		table.insert(out, b)
	end
end

function Hollow.all(env: Env.Env, out: { Build })
	fallenGiant(env, out)
	lostCamp(env, out)
	dens(env, out)
	-- mist lies on the gorge floor
	Kit.life(env.ctx, "mist", -520, -4.5, 560, 30)
	Kit.life(env.ctx, "mist", -640, -6, 690, 30)
	Kit.life(env.ctx, "mist", -420, -4, 510, 26)
end

return Hollow
