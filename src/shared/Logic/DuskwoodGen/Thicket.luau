--!strict
-- Werewolf Thicket (20–25) and the way into Duskwood (S45):
--   * the dusk gate: the road enters the dark forest between two giant gnarled oaks under an old warning gate with
--     cold blue lanterns, a board scored by claws and skulls on the posts,
--   * the ravaged hunters' camp by the forest's edge (torn tents, broken bows, an overturned cauldron, a lantern
--     still glowing), the Moon Glade (a clawed menhir in a trampled ring, silver glow at night), the bone tree,
--   * werewolf traces: scored trunks, grey fur on thorns, paw prints along the paths; bear traces: an overturned
--     beehive and a rubbed trunk,
--   * the Wolf Den: the cave opens between the roots of a giant dead oak (a root arch over the mouth, bones,
--     claw marks, fur). Pure.

local Env = require("./Env")
local Flora = require("../WorldGen/Flora")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local Structures = require("../WorldGen/Structures")

local o = Kit.o

local Thicket = {}

type Build = Kit.Build

local function gate(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "duskGate", "gate", 14)
	local bp = b.bp
	-- the giant oaks either side of the road (local X runs across the road)
	for _, side in { -1, 1 } do
		local lx = side * 19
		Flora.species.giantOak(bp, lx, Kit.gy(ctx, b, lx, 3), 3, 1.45, true, ctx)
		local wx, _, wz = Kit.worldOf(b, lx, 0, 3)
		Env.clear(env, wx, wz, 12)
	end
	-- gate posts, crossbar and braces
	for _, side in { -1, 1 } do
		local lx = side * 8.5
		local gy = Kit.gy(ctx, b, lx, 0)
		bp:box(1.4, 12, 1.4, lx, gy + 5.5, 0, o(Kit.darkBark, "shell", { q = true }))
		bp:beam(lx, gy + 7, 0, lx - side * 3, gy + 10.6, 0, 0.6, o(Kit.darkBark, "detail", { col = false }))
		Kit.skull(bp, lx, gy + 11.6, 0, 1.3)
		Kit.lantern(bp, lx + side * 1.2, gy, -1.4, Kit.COLD, 7.5, "detail")
		Props.ragPole(bp, lx + side * 3, gy, 1.5, 6, Kit.rag)
	end
	bp:box(19, 1.2, 1.2, 0, 10.8, 0, o(Kit.darkBark, "shell", { q = false }))
	-- the warning board scored by claws, hung from the crossbar
	for _, side in { -1, 1 } do
		bp:box(0.08, 1.6, 0.08, side * 2.4, 9.4, -0.4, o(Kit.rope, "fine"))
	end
	bp:rbox(6, 2.6, 0.3, 0, 7.6, -0.5, 0, 0, -4, o(Kit.greyPlanks, "detail", { col = false, tag = "flag" }))
	Kit.claws(bp, -1, 7.6, -0.7, 0.8)
	Kit.claws(bp, 1.2, 7.4, -0.7, 0.8)
	Props.charm(bp, -5, 10.2, 0.4, true)
	Props.charm(bp, 4.6, 10.2, 0.4, true)
	Kit.lifeAt(ctx, b, "mist", 0, 1, -30, 18)
	Kit.lifeAt(ctx, b, "mist", 4, 1, 26, 22)
	table.insert(out, b)
end

local function ravagedCamp(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "ravagedCamp", "camp", 18)
	local bp = b.bp
	local cloth = { c = "#7A6A50", m = "Fabric" }
	Structures.tent(bp, -6, Kit.gy(ctx, b, -6, 2), 2, 20, cloth, true)
	Structures.tent(bp, 7, Kit.gy(ctx, b, 7, 4), 4, -35, cloth, false)
	-- the second tent is knocked over: its far pole lies on the ground
	bp:rbox(0.35, 5, 0.35, 9.5, Kit.gy(ctx, b, 9.5, 7) + 0.4, 7, 0, 30, 84, o(Kit.timber, "detail", { col = false }))
	-- cold fire, overturned cauldron, broken bows, crates, a lantern still glowing
	local fy = Kit.gy(ctx, b, 0, -6)
	for i = 0, 2 do
		bp:add("cyl", 3, 0.6, 0.6, 0, fy + 0.3, -6, 0, i * 60, 8, o(Kit.charred, "detail", { col = false }))
	end
	bp:add("cyl", 2.4, 3, 3, 3.6, fy + 1.2, -7.5, 0, 30, 18, o(Kit.iron, "detail", { col = false }))
	Props.brokenBow(bp, -3, Kit.gy(ctx, b, -3, -9), -9, 40)
	Props.brokenBow(bp, 5, Kit.gy(ctx, b, 5, 0), 0, 160)
	Props.crate(bp, -10, Kit.gy(ctx, b, -10, -3), -3, 2.4, 25)
	bp:rbox(2.4, 0.3, 2.4, -12.2, Kit.gy(ctx, b, -12, -5) + 0.2, -5, 0, 60, 6, o(Kit.planks, "detail", { col = false }))
	Props.bedroll(bp, -4, Kit.gy(ctx, b, -4, 6), 6, 80)
	Kit.lantern(bp, 10, Kit.gy(ctx, b, 10, -4), -4, nil, 4.5, "detail")
	Kit.bones(bp, 1, Kit.gy(ctx, b, 1, 9), 9, 4)
	Kit.claws(bp, 4, 2.6, 2.6, 0.7)
	Props.fur(bp, -8, Kit.gy(ctx, b, -8, 8) + 0.4, 8)
	Props.paw(bp, 12, Kit.gy(ctx, b, 12, 10), 10, 30, true)
	Props.paw(bp, 15, Kit.gy(ctx, b, 15, 14), 14, 30, true)
	table.insert(out, b)
end

local function moonGlade(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "moonstone", "landmark", 16)
	local bp = b.bp
	bp:rbox(3.6, 11, 2.4, 0, 4.8, 0, 3, 20, 2, o({ c = "#6E6C6A", m = "Slate" }, "shell", { q = true }))
	bp:push(0, 0, 0, 0, 20, 0)
	Kit.claws(bp, -0.6, 6.5, -1.25, 1.6)
	Kit.claws(bp, 0.7, 4.2, -1.25, 1.3)
	-- silver glow on the stone's face at night (lamp tag)
	bp:box(0.4, 5, 0.1, 0.2, 7, -1.26, {
		c = "#CFE0FF",
		m = "Neon",
		lod = "detail",
		col = false,
		tag = "lamp",
		jitter = 0,
		fxColor = "#CFE0FF",
	})
	bp:pop()
	-- the trampled ring and a circle of small stones
	for i = 0, 13 do
		local a = i * 2 * math.pi / 14
		local lx, lz = math.cos(a) * 10, math.sin(a) * 10
		Kit.rock(bp, lx, Kit.gy(ctx, b, lx, lz) - 0.3, lz, 1.1, Kit.mossyStone, "detail")
	end
	for i = 1, 4 do
		local a = i * 1.6
		Props.fur(bp, math.cos(a) * 6, Kit.gy(ctx, b, math.cos(a) * 6, math.sin(a) * 6) + 0.25, math.sin(a) * 6)
		Props.paw(bp, math.cos(a) * 4, Kit.gy(ctx, b, math.cos(a) * 4, math.sin(a) * 4), math.sin(a) * 4, i * 90, true)
	end
	Kit.circle(ctx, "ruins", b.at.x, b.at.z, 10)
	Kit.lifeAt(ctx, b, "mist", 0, 0.5, 0, 14)
	table.insert(out, b)
end

local function boneTree(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "boneTree", "landmark", 12)
	local bp = b.bp
	Flora.species.blackDead(bp, 0, 0, 0, 1.5, true, ctx)
	for i = 1, 3 do
		local a = i * 2.2
		local lx, lz = math.cos(a) * 3.5, math.sin(a) * 3.5
		Kit.bones(bp, lx, Kit.gy(ctx, b, lx, lz), lz, 5)
	end
	-- antlers
	for _, side in { -1, 1 } do
		bp:beam(1, 0.4, 2, 1 + side * 1.6, 2, 3, 0.25, o(Kit.oldBone, "detail", { col = false }))
		bp:beam(1 + side * 1.6, 2, 3, 1 + side * 2.6, 2.6, 2.4, 0.18, o(Kit.oldBone, "fine"))
	end
	table.insert(out, b)
end

-- The Wolf Den: the cave mouth between the roots of a giant dead oak (the portal stands in the opening).
local function wolfDen(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local cave = env.areas.caves[1]
	Env.clear(env, cave.x, cave.z, 26)
	local b = Kit.build(ctx, "WolfDen", "cave", cave.x, cave.z, cave.rot)
	local bp = b.bp
	-- the dead oak behind the opening and the earth bank under it
	bp:add("cyl", 26, 11, 11, 0, 12, 13, 0, 0, 90, o(Kit.blackBark, "shell", { q = true }))
	bp:add("ball", 38, 18, 26, 0, 2, 14, 0, 0, 0, o({ c = "#3A3128", m = "Ground" }, "shell", { q = true }))
	bp:box(15, 16, 1, 0, 7.5, 4.6, o(Kit.dark, "shell", { q = false }))
	-- the root arch over the mouth
	for _, side in { -1, 1 } do
		bp:beam(side * 11, -0.5, 0, side * 7, 15, 3, 2.4, o(Kit.blackBark, "shell", { q = false }))
		bp:beam(side * 7, 15, 3, 0, 20, 5, 2.2, o(Kit.blackBark, "detail", { col = false }))
		bp:beam(side * 14, -0.5, 4, side * 9, 11, 7, 1.6, o(Kit.blackBark, "detail", { col = false }))
	end
	-- dead branches up top
	for i = 1, 3 do
		local a = i * 2
		bp:beam(0, 22, 13, math.cos(a) * 9, 30, 13 + math.sin(a) * 9, 1.2, o(Kit.blackBark, "detail", { col = false }))
	end
	Kit.claws(bp, -3, 8, 7.4, 1.6)
	Kit.claws(bp, 3, 9, 7.4, 1.4)
	for _, p in { { -8, -8 }, { 7, -6 }, { 0, -12 } } do
		Kit.bones(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2], 4)
	end
	for i = 1, 4 do
		Props.fur(bp, -10 + i * 4, Kit.gy(ctx, b, -10 + i * 4, -2) + 0.6, -2)
	end
	Kit.lifeAt(ctx, b, "perch", 6, 30, 16)
	table.insert(out, b)
end

-- Werewolf and bear traces beside the thicket's paths: scored stumps with fur, paw prints, a beehive, a rubbed trunk.
local MARKS = { { -462, -60 }, { -436, -260 }, { -404, -560 }, { -560, 16 }, { -706, -120 }, { -650, 250 } }

local function traces(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in MARKS do
		local x, z = p[1], p[2]
		if env.T.roadDistance(x, z) < 6 then
			x += 10
		end
		Env.clear(env, x, z, 6)
		local b = Kit.build(ctx, `Marks_{i}`, "traces", x, z, i * 47)
		Props.clawedStump(b.bp, 0, 0, 0, 3.5 + (i % 3), i * 30)
		for k = 1, 3 do
			local lx, lz = 3 + k * 2.6, -k * 3.2
			Props.paw(b.bp, lx, Kit.gy(ctx, b, lx, lz), lz, 200, true)
		end
		Flora.under.thorns(b.bp, -3, Kit.gy(ctx, b, -3, 2), 2)
		Props.fur(b.bp, -3, Kit.gy(ctx, b, -3, 2) + 1.4, 2)
		table.insert(out, b)
	end
	-- the overturned beehive and the rubbed trunk (bear)
	local hive = Kit.build(ctx, "Beehive", "traces", -690, 330, 30)
	Env.clear(env, -690, 330, 8)
	hive.bp:add("cyl", 5, 2.4, 2.4, 0, 0.9, 0, 0, 0, 6, o(Kit.darkBark, "detail", { col = false }))
	hive.bp:add("cyl", 0.3, 1.8, 1.8, 2.6, 0.9, 0, 0, 0, 0, o(Kit.dark, "detail", { col = false }))
	for k = 1, 4 do
		hive.bp:rbox(
			1.2,
			0.2,
			0.9,
			3.4 + k * 0.8,
			0.15,
			k - 2,
			0,
			k * 40,
			0,
			o({ c = "#D8A43A", m = "SmoothPlastic" }, "fine")
		)
	end
	Props.clawedStump(hive.bp, -6, Kit.gy(ctx, hive, -6, 3), 3, 6, 70)
	table.insert(out, hive)
end

function Thicket.all(env: Env.Env, out: { Build })
	gate(env, out)
	ravagedCamp(env, out)
	moonGlade(env, out)
	boneTree(env, out)
	wolfDen(env, out)
	traces(env, out)
end

return Thicket
