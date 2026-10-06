--!strict
-- Homesteads and small places of the Whispering Meadows (S26): the timber gate behind the city portal, the old oak
-- with the wayside shrine, the farmstead (house, barn, well, vegetable plot, hives, sheep pen), the fisherman's
-- hut with the jetty and a boat, the woodcutter's hut with log piles, the hunter's camp on the ravine rim and the
-- rabbit warrens of the glade. Houses and the barn come from the city generator (TownGen), so they look like the
-- city's cottages. Pure.

local Areas = require("../../Data/Areas/meadows")
local AreaTypes = require("../../Data/Areas/Types")
local Houses = require("../TownGen/Houses")
local Kit = require("./Kit")
local MeadowsTerrain = require("../MeadowsTerrain")
local Nature = require("./Nature")
local Outside = require("../TownGen/Outside")
local Palette = require("../TownGen/Palette")
local Parts = require("../TownGen/Parts")
local Props = require("../TownGen/Props")

local o = Kit.o
local sites = assert(Areas.sites, "meadows sites")

local Homes = {}

type Build = Kit.Build
type BP = Kit.BP

local function ground(x: number, z: number): number
	return MeadowsTerrain.height(x, z)
end

-- A cottage from the city generator at a world point, front facing `rot`.
local function cottage(
	name: string,
	x: number,
	z: number,
	rot: number,
	w: number,
	d: number,
	seed: number,
	floors: number?
): Build
	local bp, at = Houses.build({
		id = name,
		kind = "cottage",
		style = "cottage",
		x = x,
		z = z,
		w = w,
		d = d,
		rot = rot,
		floors = floors or 1,
		seed = seed,
	}, ground)
	Kit.rect("building", x, z, w, d, rot)
	return { name = name, bp = bp, at = at, tag = "home" }
end

-- Gate: two posts over the road with a little shingle roof and lanterns.
local function gate(out: { Build })
	local s = sites.gate
	local b = Kit.build("MeadowsGate", "gate", s.x, s.z, s.rot)
	local bp = b.bp
	local half = 9
	for _, side in { -1, 1 } do
		local gy = Kit.gy(b, side * half, 0)
		bp:box(1.6, 11 - gy, 1.6, side * half, gy + (11 - gy) / 2 - 0.5, 0, o(Kit.timber, "shell", { q = true }))
		bp:box(2.2, 1.2, 2.2, side * half, gy + 0.4, 0, o(Palette.rubble[1], "detail"))
		-- braces
		bp:beam(side * half, 8, 0, side * (half - 3), 10.6, 0, 0.5, o(Kit.timber, "detail"))
		Kit.lantern(bp, side * (half + 1.2), gy, -1.5, nil, 5.5)
		-- a few rails of fence running off the road
		for k = 1, 3 do
			local x1, x2 = side * (half + 1 + (k - 1) * 6), side * (half + 1 + k * 6)
			Parts.fence(bp, x1, Kit.gy(b, x1, 0), 0, x2, Kit.gy(b, x2, 0), 0, "rail")
		end
	end
	bp:box(2 * half + 3, 1.1, 1.4, 0, 11, 0, o(Kit.timber, "shell"))
	for _, side in { -1, 1 } do
		bp:rbox(2 * half + 5, 0.35, 2.6, 0, 12.2, side * 1.05, side * 32, 0, 0, o(Palette.shingles[2], "shell"))
	end
	-- carved board under the beam (the map's name sign stands beside the road, World/Meadows)
	bp:box(8, 1.8, 0.3, 0, 9.4, -0.75, o(Palette.planks[3], "detail"))
	bp:box(7, 0.25, 0.1, 0, 9.4, -0.95, o({ c = "#C9A45C", m = "SmoothPlastic" }, "fine"))
	table.insert(out, b)
	-- the first view from the portal: trees framing the road (the old oak on its knoll stays in sight), bushes
	local g = Kit.build("EntranceGrove", "trees", -700, 0, 0)
	local trees: { { any } } = {
		{ "birch", -712, -21, 1 },
		{ "birch", -706, 23, 1.1 },
		{ "birch", -722, 30, 0.95 },
		{ "oak", -668, 48, 1.15 },
		{ "oak", -650, 64, 1.05 },
		{ "oak", -680, 72, 1.25 },
		{ "oak", -728, -52, 1.1 },
		{ "birch", -718, -88, 1 },
		{ "oak", -640, -118, 1.2 },
	}
	for _, t in trees do
		local lx, lz = (t[2] :: number) - g.at.x, (t[3] :: number) - g.at.z
		Nature.tree(g.bp, t[1] :: any, lx, Kit.gy(g, lx, lz), lz, t[4] :: number, false)
	end
	for _, p in { { -716, 12 }, { -694, 13 }, { -684, -12 }, { -660, 30 }, { -672, 58 }, { -718, -34 } } do
		local lx, lz = p[1] - g.at.x, p[2] - g.at.z
		Nature.undergrowth(g.bp, "bush", lx, Kit.gy(g, lx, lz), lz)
	end
	table.insert(out, g)
end

-- The old oak with a wayside shrine (kapliczka) under it: candles, flowers, a bench.
local function shrine(out: { Build })
	local s = sites.shrine
	local b = Kit.build("Shrine", "shrine", s.x, s.z, s.rot)
	local bp = b.bp
	-- the oak stands behind the shrine
	Nature.tree(bp, "giantOak", 2, Kit.gy(b, 2, 9), 9, 1.55, false)
	-- shrine: stone plinth, pillar, roofed niche
	bp:box(3.2, 1, 3.2, 0, 0.3, 0, o(Palette.rubble[2], "shell", { q = true }))
	bp:box(1.8, 5, 1.8, 0, 3.2, 0, o(Palette.ashlar[1], "shell", { q = true }))
	bp:box(2.6, 2.8, 2.2, 0, 7, 0, o(Palette.ashlar[2], "detail"))
	bp:box(1.6, 2, 0.3, 0, 7, -1, o({ c = "#2A2A30", m = "Slate" }, "detail"))
	bp:add("ball", 0.8, 1.6, 0.6, 0, 6.9, -0.9, 0, 0, 0, o({ c = "#D8D0C0", m = "Marble" }, "fine"))
	for _, side in { -1, 1 } do
		bp:rbox(3.4, 0.3, 1.9, 0, 9.1, side * 0.7, side * 38, 0, 0, o(Palette.shingles[1], "shell"))
	end
	bp:box(0.2, 1.4, 0.2, 0, 10.4, 0, o(Kit.iron, "fine"))
	bp:box(0.9, 0.2, 0.2, 0, 10.6, 0, o(Kit.iron, "fine"))
	-- candles on the plinth (always lit) and flowers
	for i = -1, 1 do
		bp:box(0.25, 0.7, 0.25, i * 0.7, 1.15, -1.3, o({ c = "#E8E0C8", m = "SmoothPlastic" }, "fine"))
		bp:box(0.18, 0.3, 0.18, i * 0.7, 1.65, -1.3, o(Kit.flame, "fine", { tag = "candle", jitter = 0 }))
	end
	bp:light(0, 1.8, -1.6, "#FFB45A", 10, 0.8, "fire")
	for i = 1, 6 do
		local a = i * 1.05
		bp:add("ball", 0.6, 0.6, 0.6, math.cos(a) * 2.3, 0.4, math.sin(a) * 2.3 - 0.6, 0, 0, 0, {
			c = if i % 2 == 0 then "#E8C84A" else "#C84A6A",
			m = "SmoothPlastic",
			lod = "fine",
		})
	end
	Parts.bench(bp, 5.5, Kit.gy(b, 5.5, -4), -4, 70, 4)
	table.insert(out, b)
	Kit.life("butterflies", s.x, b.at.y + 2, s.z, 18)
end

-- Farmstead: house and barn from the city generator, yard fence, well, haystacks, cart, woodpile, the fenced
-- vegetable plot east of the barn (its corners are the quest anchors fence_1..4), beehives and a sheep pen.
local function farm(out: { Build })
	local s = sites.farm
	table.insert(out, cottage("Farmhouse", s.x - 16, s.z - 10, 180, 14, 10, 6101, 2))
	table.insert(out, Outside.barn(s.x + 12, s.z - 28, 180, 6102, ground) :: any)
	Kit.rect("building", s.x + 12, s.z - 28, 18, 12, 180)
	Kit.rect("garden", -611, -195, 20, 38, 0)
	local b = Kit.build("Farmyard", "farm", s.x, s.z, 0)
	local bp = b.bp
	local function gy(lx: number, lz: number): number
		return Kit.gy(b, lx, lz)
	end
	Props.well(bp, -8, gy(-8, 4), 4, 15)
	Parts.haystack(bp, 20, gy(20, -10), -10, 2.4, "shell")
	Parts.haystack(bp, 19, gy(19, -3), -3, 1.9, "detail")
	Parts.cart(bp, 14, gy(14, 12), 12, 120)
	Parts.woodpile(bp, -28, gy(-28, -6), -6, 90, 6)
	Parts.bench(bp, -10, gy(-10, -3.5), -3.5, 0, 4)
	-- yard fence (rails), open towards the road (south)
	local yard = { { -40, -40 }, { 28, -40 }, { 28, 22 }, { 8, 22 } }
	for i = 1, #yard - 1 do
		local a, c = yard[i], yard[i + 1]
		Parts.fence(bp, a[1], gy(a[1], a[2]), a[2], c[1], gy(c[1], c[2]), c[2], "rail")
	end
	Parts.fence(bp, -40, gy(-40, -40), -40, -40, gy(-40, 6), 6, "rail")
	-- vegetable plot (world x -621..-601, z -214..-176): wattle fence and cabbage rows
	local px1, px2 = -621 - s.x, -601 - s.x
	local pz1, pz2 = -214 - s.z, -176 - s.z
	local corners = { { px1, pz1 }, { px1, pz2 }, { px2, pz2 }, { px2, pz1 } }
	for i = 1, 4 do
		local a, c = corners[i], corners[i % 4 + 1]
		if i ~= 3 then
			Parts.fence(bp, a[1], gy(a[1], a[2]), a[2], c[1], gy(c[1], c[2]), c[2], "wattle")
		else
			-- the gate side has a gap
			local mx = (a[1] + c[1]) / 2
			Parts.fence(bp, a[1], gy(a[1], a[2]), a[2], mx - 2, gy(mx - 2, a[2]), a[2], "wattle")
			Parts.fence(bp, mx + 2, gy(mx + 2, a[2]), a[2], c[1], gy(c[1], c[2]), c[2], "wattle")
		end
	end
	for row = 0, 5 do
		local rx = px1 + 2.5 + row * 3
		for k = 0, 9 do
			local rz = pz1 + 2.5 + k * 3.4
			bp:add(
				"ball",
				1.6,
				1,
				1.6,
				rx,
				gy(rx, rz) + 0.5,
				rz,
				0,
				0,
				0,
				o({ c = "#5E8A4A", m = "LeafyGrass" }, "detail", { col = false, jitter = 0.1 })
			)
		end
	end
	-- beehives (straw skeps) on a plank stand west of the house
	local hx, hz = -36, 14
	bp:box(7, 0.4, 1.8, hx, gy(hx, hz) + 1.2, hz, o(Kit.planks, "detail"))
	for i = -1, 1 do
		bp:add(
			"ball",
			1.7,
			2.1,
			1.7,
			hx + i * 2.2,
			gy(hx, hz) + 2.3,
			hz,
			0,
			0,
			0,
			o(Kit.straw, "detail", { col = false })
		)
		bp:box(
			0.5,
			0.3,
			0.2,
			hx + i * 2.2,
			gy(hx, hz) + 1.6,
			hz - 0.85,
			o({ c = "#1A1612", m = "SmoothPlastic" }, "fine")
		)
	end
	-- sheep pen south-west of the yard
	local pen = { { -62, 4 }, { -42, 4 }, { -42, 28 }, { -62, 28 } }
	for i = 1, 4 do
		local a, c = pen[i], pen[i % 4 + 1]
		Parts.fence(bp, a[1], gy(a[1], a[2]), a[2], c[1], gy(c[1], c[2]), c[2], "rail")
	end
	bp:box(4, 0.8, 1.4, -52, gy(-52, 25) + 0.4, 25, o(Kit.planks, "detail")) -- trough
	local wx, wy, wz = Kit.worldOf(b, -52, gy(-52, 16), 16)
	Kit.life("sheep", wx, wy, wz, 8)
	Kit.life("butterflies", s.x + 30, b.at.y + 2, s.z + 10, 20)
	table.insert(out, b)
end

-- Fisherman's hut on the north shore, drying nets, an upturned boat; the jetty with a moored boat and a lantern.
local function fisher(out: { Build })
	local s = sites.fisher
	table.insert(out, cottage("FisherHut", s.x, s.z, s.rot, 10, 8, 6201, 1))
	local b = Kit.build("FisherYard", "fisher", s.x, s.z, s.rot)
	local bp = b.bp
	-- net rack beside the hut
	local nx, nz = 8, -4
	for _, k in { -2.5, 2.5 } do
		bp:box(0.4, 5, 0.4, nx + k, Kit.gy(b, nx + k, nz) + 2.3, nz, o(Kit.timber, "detail"))
	end
	bp:box(5.6, 0.3, 0.3, nx, Kit.gy(b, nx, nz) + 4.8, nz, o(Kit.timber, "detail"))
	bp:box(5, 3.2, 0.1, nx, Kit.gy(b, nx, nz) + 3.1, nz, o({ c = "#8A8670", m = "Fabric" }, "detail", { t = 0.35 }))
	-- barrels, a fish trap, the upturned boat
	Parts.barrel(bp, -6.5, Kit.gy(b, -6.5, -5), -5)
	Parts.barrel(bp, -8.6, Kit.gy(b, -8.6, -4), -4)
	bp:add("cyl", 2.6, 1.6, 1.6, -4, Kit.gy(b, -4, -8) + 0.8, -8, 0, 30, 0, o(Kit.rope, "detail"))
	local bx, bz = 2, -12
	local by = Kit.gy(b, bx, bz)
	bp:rbox(2.6, 1, 7, bx, by + 0.5, bz, 0, 70, 180, o(Palette.planks[2], "detail"))
	bp:rbox(2, 0.6, 6, bx, by + 0.9, bz, 0, 70, 180, o(Palette.planks[4], "detail"))
	table.insert(out, b)

	-- jetty: from the shore south into the pond, deck over the water
	local j = sites.jetty
	local deckY = math.max(MeadowsTerrain.LAKE_LEVEL + 1.3, MeadowsTerrain.height(j.x, j.z - 4) + 0.3)
	local jb: Build = {
		name = "Jetty",
		bp = Kit.build("Jetty", "jetty", j.x, j.z, j.rot).bp,
		at = { x = j.x, y = deckY, z = j.z, rot = j.rot },
		tag = "jetty",
	}
	local jp = jb.bp
	local len = 24
	-- local -Z is the front (rot 180: south); the deck runs from the shore (z = +4) out to z = -len
	jp:box(4.4, 0.6, len + 4, 0, 0, -len / 2 + 2, o(Palette.greyPlanks[2], "shell", { q = true }))
	for k = 0, 3 do
		for _, side in { -1, 1 } do
			local pz = 2 - k * (len / 3)
			jp:add(
				"cyl",
				6,
				0.8,
				0.8,
				side * 2.1,
				-2.6,
				pz,
				0,
				0,
				90,
				o(Kit.timber, if k % 2 == 0 then "shell" else "detail", { q = false })
			)
		end
	end
	for k = 0, math.floor(len / 1.6) do
		jp:box(4.5, 0.12, 0.2, 0, 0.32, 3 - k * 1.6, o(Palette.greyPlanks[1], "fine"))
	end
	Kit.lantern(jp, 1.9, 0.3, -len + 1, nil, 4.5)
	-- moored boat beside the end
	local mx, mz = -4.2, -len + 4
	jp:box(2.4, 0.9, 7, mx, -0.9, mz, o(Palette.planks[2], "detail", { col = false }))
	for _, side in { -1, 1 } do
		jp:box(0.3, 0.9, 7, mx + side * 1.25, -0.5, mz, o(Palette.planks[4], "detail", { col = false }))
	end
	jp:box(2.4, 0.25, 0.8, mx, -0.3, mz + 1, o(Kit.planks, "fine"))
	jp:beam(mx, -0.2, mz - 3.5, -2.2, 0.3, mz - 4, 0.12, o(Kit.rope, "fine"))
	table.insert(out, jb)
	local cx, cz = Kit.toWorld(j.x, j.z, j.rot, 0, -len / 2 + 2)
	Kit.rect("bridge", cx, cz, 4.4, len + 4, j.rot)
	Kit.life("ducks", j.x - 30, MeadowsTerrain.LAKE_LEVEL, j.z + 50, 40)
	Kit.life("ducks", -560, MeadowsTerrain.LAKE_LEVEL, 600, 30)
end

-- A stack of logs (shell: one collider) at a world point.
local function logStack(name: string, x: number, z: number, rot: number, len: number): Build
	local b = Kit.build(name, "logs", x, z, rot)
	local bp = b.bp
	bp:box(len, 2.6, 3.4, 0, 1.1, 0, o({ c = "#4A3A2C", m = "Wood" }, "shell", { q = false, t = 0 }))
	for row = 0, 2 do
		for k = 0, 2 - row do
			bp:add(
				"cyl",
				len + 0.2,
				1.15,
				1.15,
				0,
				0.6 + row * 1,
				-1.15 + k * 1.15 + row * 0.57,
				0,
				0,
				0,
				o({ c = "#5A4634", m = "Wood" }, "detail", { col = false })
			)
			bp:add(
				"cyl",
				0.12,
				1,
				1,
				len / 2 + 0.12,
				0.6 + row * 1,
				-1.15 + k * 1.15 + row * 0.57,
				0,
				0,
				0,
				o({ c = "#B89A6A", m = "Wood" }, "fine")
			)
		end
	end
	return b
end

-- Woodcutter's hut (log cottage) on a clearing by the forest path: chopping block with an axe, sawhorse, stumps,
-- log piles (logpile_1..5 anchors stand by the piles).
local function woodcutter(out: { Build })
	local s = sites.woodcutter
	table.insert(out, cottage("WoodcutterHut", s.x, s.z, s.rot, 12, 9, 6301, 1))
	local b = Kit.build("WoodcutterYard", "woodcutter", s.x, s.z, s.rot)
	local bp = b.bp
	local function gy(lx: number, lz: number): number
		return Kit.gy(b, lx, lz)
	end
	-- chopping block and axe in front
	local cx, cz = -3, -10
	bp:add("cyl", 1.4, 2.2, 2.2, cx, gy(cx, cz) + 0.7, cz, 0, 0, 90, o(Kit.bark, "detail"))
	bp:beam(cx, gy(cx, cz) + 1.4, cz, cx + 1.2, gy(cx, cz) + 3, cz + 0.4, 0.22, o(Kit.planks, "fine"))
	bp:box(0.2, 0.9, 1.1, cx, gy(cx, cz) + 1.5, cz, o(Kit.iron, "fine"))
	-- sawhorse with a log
	local sx, sz = 6, -11
	for _, k in { -1.6, 1.6 } do
		bp:rbox(0.3, 2.6, 0.3, sx + k, gy(sx, sz) + 1.2, sz, 25, 0, 0, o(Kit.planks, "detail"))
		bp:rbox(0.3, 2.6, 0.3, sx + k, gy(sx, sz) + 1.2, sz, -25, 0, 0, o(Kit.planks, "detail"))
	end
	bp:add("cyl", 6, 1, 1, sx, gy(sx, sz) + 2.3, sz, 0, 0, 0, o(Kit.bark, "detail"))
	-- stumps around the clearing
	for i = 1, 7 do
		local a = i * 0.9 + 0.4
		local d = 18 + (i % 3) * 5
		local lx, lz = math.cos(a) * d, math.sin(a) * d
		bp:add("cyl", 1.4, 2.2, 2.2, lx, gy(lx, lz) + 0.4, lz, 0, 0, 90, o(Kit.bark, "detail"))
		bp:add("cyl", 0.1, 2, 2, lx, gy(lx, lz) + 1.12, lz, 0, 0, 90, o({ c = "#B89A6A", m = "Wood" }, "fine"))
	end
	Parts.woodpile(bp, -2, gy(-2, 7.5), 7.5, 0, 7)
	table.insert(out, b)
	-- log piles (quest anchors logpile_1..5 stand beside them)
	local rot = 0
	for i, a in (Areas.questAnchors or {}) :: { AreaTypes.QuestAnchor } do
		if string.sub(a.id, 1, 8) == "logpile_" then
			rot += 47
			table.insert(out, logStack(`LogPile_{i}`, a.x + 3, a.z + 2, rot, 6))
		end
	end
end

-- Hunter's camp on the south rim of Bear Ravine: lean-to, fire, drying rack with hides, antlers.
local function hunter(out: { Build })
	local s = sites.hunterCamp
	local b = Kit.build("HunterCamp", "hunter", s.x, s.z, s.rot)
	local bp = b.bp
	-- lean-to shelter facing the fire
	for _, side in { -1, 1 } do
		bp:box(0.5, 5, 0.5, side * 3.5, Kit.gy(b, side * 3.5, -2) + 2.4, -2, o(Kit.timber, "shell", { q = true }))
	end
	bp:rbox(8, 0.4, 6.4, 0, 2.6, 0.4, -40, 0, 0, o(Kit.hide, "shell"))
	bp:rbox(8, 0.3, 6.6, 0, 2.7, 0.4, -40, 0, 0, o({ c = "#3A5228", m = "LeafyGrass" }, "detail"))
	bp:box(6, 0.4, 3, 0, 0.3, 1.5, o(Kit.hide, "detail", { col = false }))
	Kit.rect("building", s.x, s.z, 8, 6, s.rot)
	Kit.campfire(bp, 0, Kit.gy(b, 0, -6), -6)
	-- drying rack with hides
	local rx, rz = 7, -4
	for _, k in { -2, 2 } do
		bp:box(0.35, 4.5, 0.35, rx, Kit.gy(b, rx, rz + k) + 2.1, rz + k, o(Kit.timber, "detail"))
	end
	bp:box(0.3, 0.3, 4.6, rx, Kit.gy(b, rx, rz) + 4.2, rz, o(Kit.timber, "detail"))
	bp:rbox(0.15, 2.8, 2, rx + 0.1, Kit.gy(b, rx, rz) + 2.7, rz - 1, 0, 0, 4, o(Kit.hide, "detail"))
	bp:rbox(
		0.15,
		2.4,
		1.8,
		rx + 0.1,
		Kit.gy(b, rx, rz) + 2.9,
		rz + 1.1,
		0,
		0,
		-3,
		o({ c = "#5A4030", m = "Fabric" }, "detail")
	)
	-- log seats, a bow on a stand, antlers on the post
	bp:add("cyl", 4, 1.1, 1.1, -4, Kit.gy(b, -4, -7) + 0.5, -7, 0, 70, 0, o(Kit.bark, "detail"))
	bp:add("cyl", 4, 1.1, 1.1, 3.5, Kit.gy(b, 3.5, -8.5) + 0.5, -8.5, 0, -40, 0, o(Kit.bark, "detail"))
	bp:beam(-6, Kit.gy(b, -6, 0) + 0.2, 0, -6.2, Kit.gy(b, -6, 0) + 4.4, -0.3, 0.2, o(Kit.planks, "fine"))
	bp:box(0.08, 4, 0.08, -5.6, Kit.gy(b, -6, 0) + 2.3, -0.2, o({ c = "#D8D0B8", m = "Fabric" }, "fine"))
	for _, side in { -1, 1 } do
		bp:beam(side * 3.5, 4.6, -2, side * 4.8, 6, -2.2, 0.15, o(Kit.bone, "fine"))
	end
	table.insert(out, b)
end

-- Rabbit warrens in the glade: earth mounds with dark holes.
local function warrens(out: { Build })
	local spots = {
		{ -640, -40 },
		{ -690, 120 },
		{ -560, 150 },
		{ -720, -110 },
		{ -600, 260 },
		{ -520, -230 },
		{ -700, 230 },
		{ -560, 40 },
	}
	for i, p in spots do
		if MeadowsTerrain.roadDistance(p[1], p[2]) > 6 then
			local b = Kit.build(`Warren_{i}`, "warren", p[1], p[2], i * 40)
			local bp = b.bp
			for k = 0, 2 do
				local a = k * 2.1
				local lx, lz = math.cos(a) * 3, math.sin(a) * 3
				bp:add(
					"ball",
					3.4,
					1.4,
					3,
					lx,
					Kit.gy(b, lx, lz),
					lz,
					0,
					k * 30,
					0,
					o({ c = "#6A5A42", m = "Ground" }, "detail", { col = false })
				)
				bp:rbox(
					1.2,
					0.9,
					0.3,
					lx * 0.7,
					Kit.gy(b, lx, lz) + 0.45,
					lz * 0.7,
					-20,
					-math.deg(a) + 90,
					0,
					o({ c = "#16120E", m = "SmoothPlastic" }, "detail", { col = false })
				)
			end
			table.insert(out, b)
		end
	end
end

function Homes.all(out: { Build })
	gate(out)
	shrine(out)
	farm(out)
	fisher(out)
	woodcutter(out)
	hunter(out)
	warrens(out)
end

return Homes
