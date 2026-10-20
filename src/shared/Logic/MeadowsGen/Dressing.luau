--!strict
-- W13-W14, part 2 (laki.md 1.2-1.4, 1.7): the props that tell each hunting ground's story and the missing details of
-- the Meadows' landmarks. Decoration only: client detail and fine without collision, server shapes only where a thing
-- must be seen from afar (the frosted tower stump, the fallen lintel, the upper falls) or walked on (the boardwalk
-- planks). Every spot keeps off roads, water, NPC places, quest objects and monster groups (Nature.isClear) and asks
-- the trees to keep off it (Kit.keepClear, read by Nature.forest).
--   * Frosted Watchtower (1.2): the tall side of the ruin raised to a 22-26 stud stump with a crown of frost, ice
--     down the inner face, frost on the ground, a gate frame on the north with the thorned-petal crest over it, crows
--     and a nest on top.
--   * Stone circle (1.2): the fallen lintel, one piece on the ground, one leaning on a stone.
--   * Waterfall of Bear Ravine (1.2): the upper step where the brook falls off the border rocks onto the plateau,
--     mist at both steps.
--   * Rabbit Fields (1.4): a pasture fence with a gap the wolves broke, wattle knocked down at the vegetable plot.
--   * Wolf Hills: the pack's trodden trails between the dens.
--   * Toad Pond: plank boardwalks on hummocks, Wit's nets on the shore, low mist over the water, snares and empty
--     cages at the poachers' camps (also the pen in the Old Forest).
--   * Merchant Road: the merchant's marked crates among the bandits' loot, the torn tarp with the same sign at Lucjan's
--     wreck, kobolds' ditches on the verge.
--   * Goblin Camp: a pile of loot from the farms.
--   * The road's rests (1.3): a bench and a well by Mira at the gate, a bench on the saddle, a stone bench, a horse
--     trough and a milestone at the stone bridge.
-- Pure.

local Areas = require("../../Data/Areas/meadows")
local AreaTypes = require("../../Data/Areas/Types")
local Kit = require("./Kit")
local MeadowsTerrain = require("../MeadowsTerrain")
local Nature = require("./Nature")
local Palette = require("../TownGen/Palette")
local Parts = require("../TownGen/Parts")
local Props = require("../TownGen/Props")

local o = Kit.o
local sites = assert(Areas.sites, "meadows sites")

local Dressing = {}

type Build = Kit.Build
type BP = Kit.BP

local STONE = { c = "#6E6A63", m = "Cobblestone" } -- the ruin's stone (TownGen/Outside ruin)
local SNOW = { c = "#E6ECEF", m = "Snow" }
local ICE = { c = "#BFD8E6", m = "Glacier" }
local MERCHANT = { c = "#3E5A7A", m = "Fabric" } -- the merchant's tarp and sign (Landmarks.sunkenWagon)
local MERCHANT_SIGN = { c = "#C9A45C", m = "SmoothPlastic" }
local EARTH = { c = "#5A4A36", m = "Ground" }
local DARK_EARTH = { c = "#3E3226", m = "Ground" }
local WOOL = { c = "#E2DCCC", m = "Fabric" }
local KOBOLD_LIGHT = "#8CFF7A"

-- Free ground for a prop: `road` studs past the road's edge, off water, not on an NPC place, quest object, crossing or monster group.
local function free(x: number, z: number, extra: number, road: number?): boolean
	return Nature.isClear(x, z, extra)
		and MeadowsTerrain.roadDistance(x, z) > (road or 4)
		and MeadowsTerrain.streamDistance(x, z) > 3
		and not MeadowsTerrain.isWater(x, z)
end

local function keep(x: number, z: number, r: number)
	table.insert(Kit.keepClear, { x = x, z = z, r = r })
end

-- Frosted Watchtower ----------------------------------------------------------------------------------------

-- The thorned petal of the Lady on a shield plate, its face at local -Z (petal: three crossed bars, the thorn through it).
local function crest(bp: BP, x: number, y: number, z: number, frost: boolean)
	bp:box(2.2, 2.6, 0.35, x, y, z, o({ c = "#4A5A6A", m = "Slate" }, "detail", { col = false }))
	bp:add(
		"wedge",
		0.35,
		0.9,
		2.2,
		x,
		y - 1.75,
		z,
		180,
		90,
		0,
		o({ c = "#4A5A6A", m = "Slate" }, "detail", { col = false })
	)
	for k = 0, 2 do
		bp:rbox(0.18, 1.6, 0.1, x, y + 0.1, z - 0.22, 0, 0, k * 60, o({ c = "#E8F0F4", m = "SmoothPlastic" }, "fine"))
	end
	bp:rbox(0.16, 2.4, 0.12, x + 0.1, y - 0.1, z - 0.3, 0, 0, -32, o({ c = "#2A2620", m = "SmoothPlastic" }, "fine"))
	bp:add(
		"wedge",
		0.12,
		0.5,
		0.16,
		x + 0.75,
		y + 1.05,
		z - 0.3,
		0,
		90,
		-32,
		o({ c = "#2A2620", m = "SmoothPlastic" }, "fine")
	)
	if frost then
		bp:box(2.4, 0.3, 0.6, x, y + 1.4, z, o(SNOW, "fine", { col = false }))
	end
end

local function frostedTower(out: { Build })
	local s = sites.ruins
	local b = Kit.build("FrostedTower", "ruins", s.x, s.z, 0)
	local bp = b.bp
	-- the ruin's ring (TownGen/Outside ruin: 14 segments at radius 6, tallest towards 0.6 rad); the tall side is cased
	-- in slightly bigger blocks of the same stone, so the old segments sit inside the new ones
	local n, R = 14, 6
	local side = 2 * (R + 0.8) * math.tan(math.pi / n) + 0.1
	local heights = { { 0, 22 }, { 1, 26 }, { 2, 24.5 }, { 3, 19 } }
	for k, seg in heights do
		local a = seg[1] * 360 / n
		local ra = math.rad(a)
		local h = seg[2]
		local x, z = math.sin(ra) * R, math.cos(ra) * R
		local gy = Kit.gy(b, x, z)
		bp:rbox(side + 0.15, h + 1, 1.75, x, gy + h / 2 - 0.5, z, 0, a, 0, o(STONE, "shell", { q = true }))
		-- broken teeth on the top
		local tx, tz = math.cos(ra) * side * 0.25, -math.sin(ra) * side * 0.25
		bp:rbox(side * 0.45, 1.6, 1.6, x + tx, gy + h + 0.7, z + tz, 0, a, 0, o(STONE, "detail"))
		-- the crown of frost: snow on the top, ice running down the inner face, frost on the upper outer face
		bp:rbox(side + 0.35, 0.5, 2.05, x, gy + h + 0.2, z, 0, a, 0, o(SNOW, "detail", { col = false }))
		bp:rbox(side * 0.5, 0.45, 1.7, x + tx, gy + h + 1.65, z + tz, 0, a, 0, o(SNOW, "fine", { col = false }))
		local inner = (R - 1.0) / R
		bp:rbox(
			side * 0.85,
			h * 0.45,
			0.25,
			x * inner,
			gy + h * 0.74,
			z * inner,
			0,
			a,
			0,
			o(ICE, "detail", { col = false, t = 0.15 })
		)
		local outer = (R + 1.0) / R
		bp:rbox(
			side * 0.7,
			h * 0.3,
			0.2,
			x * outer,
			gy + h * 0.82,
			z * outer,
			0,
			a,
			0,
			o(ICE, "detail", { col = false })
		)
		-- icicles along the inner top edge
		for i = -1, 1 do
			local ix, iz = x * inner + math.cos(ra) * i * side * 0.3, z * inner - math.sin(ra) * i * side * 0.3
			bp:add(
				"wedge",
				0.25,
				1.2 + ((i + k) % 2) * 0.8,
				0.3,
				ix,
				gy + h - 0.9,
				iz,
				180,
				a,
				0,
				o(ICE, "fine", { col = false })
			)
		end
		if k == 2 then
			-- a crows' nest of twigs on the top
			bp:add(
				"ball",
				2.2,
				0.8,
				2.2,
				x,
				gy + h + 0.75,
				z,
				0,
				0,
				0,
				o({ c = "#4A3A28", m = "Wood" }, "detail", { col = false })
			)
		end
		if k == 2 or k == 4 then
			local wx, wy, wz = Kit.worldOf(b, x, gy + h + 1.2, z)
			Kit.life("perch", wx, wy, wz)
		end
	end
	-- frost on the ground in the ring and at its foot (the boot prints of the secret lead off to the south-east)
	local rng = bp.rng
	for i = 1, 9 do
		local a = i * 0.7 + 2
		local d = if i % 3 == 0 then rng:float(1, 3.5) else rng:float(7.5, 11)
		local lx, lz = math.sin(a) * d, math.cos(a) * d
		local size = rng:float(2.2, 4.2)
		bp:add(
			"cyl",
			0.1,
			size,
			size * rng:float(0.7, 1),
			lx,
			Kit.gy(b, lx, lz) + 0.05,
			lz,
			0,
			rng:float(0, 180),
			90,
			o(SNOW, "detail", { col = false })
		)
	end
	-- the gate on the north (towards the quest's crest anchor): two jambs, a lintel, the crest over it under frost
	local ga = 200
	local gr = math.rad(ga)
	local gx, gz = math.sin(gr) * 6.5, math.cos(gr) * 6.5
	bp:push(gx, Kit.gy(b, gx, gz), gz, 0, ga + 180, 0) -- local -Z outward
	for _, sx in { -1.9, 1.9 } do
		bp:box(1.1, 6.4, 1.3, sx, 2.7, 0, o(STONE, "detail", { col = false }))
		bp:box(1.2, 0.3, 1.4, sx, 6.05, 0, o(SNOW, "fine", { col = false }))
	end
	bp:box(5.2, 1.1, 1.4, 0, 6.4, 0, o(STONE, "detail", { col = false }))
	bp:box(5.3, 0.3, 1.5, 0, 7.05, 0, o(SNOW, "fine", { col = false }))
	crest(bp, 0, 8.5, -0.1, true)
	bp:pop()
	table.insert(out, b)
end

-- Stone circle: the fallen lintel between the first two stones ----------------------------------------------

local function fallenLintel(out: { Build })
	local s = sites.stonecircle
	local a = math.rad(20)
	local lx, lz = math.cos(a) * 14.5, math.sin(a) * 14.5
	local b = Kit.build("CircleLintel", "stonecircle", s.x + lx, s.z + lz, 70) -- local X along the ring
	local bp = b.bp
	local mossy = { c = "#6E7262", m = "Slate" }
	bp:rbox(4.4, 1.4, 2.2, -1.6, Kit.gy(b, -1.6, 0) + 0.55, 0, 0, 8, 3, o(mossy, "shell", { q = true }))
	bp:box(3.6, 0.2, 1.6, -1.6, Kit.gy(b, -1.6, 0) + 1.3, 0, o(Kit.moss, "fine", { col = false }))
	-- the other half leans with one end on the ground towards the next stone
	bp:rbox(3.8, 1.3, 2.1, 2.6, Kit.gy(b, 2.6, -1.2) + 1.6, -1.2, 0, 14, 32, o(mossy, "detail"))
	for k = 1, 4 do
		local px, pz = 0.6 + k * 0.4, 1.4 + (k % 2) * 0.5
		bp:rbox(0.6, 0.4, 0.5, px, Kit.gy(b, px, pz) + 0.2, pz, k * 20, k * 50, 0, o(mossy, "fine", { col = false }))
	end
	table.insert(out, b)
end

-- Waterfall: the upper step and the mist of both ---------------------------------------------------------

local function upperFalls(out: { Build })
	local line = MeadowsTerrain.streamLine(3)
	local src, nxt = line.pts[1], line.pts[2]
	local dx, dz = nxt[1] - src[1], nxt[2] - src[2]
	local len = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / len, dz / len
	local top = MeadowsTerrain.streamLevel(3, 0)
	local rot = math.deg(math.atan2(-dx, -dz)) -- local -Z downstream
	local fx, fz = src[1] - dx * 4, src[2] - dz * 4 -- a little upstream of where the brook starts (past the map edge)
	local b: Build = {
		name = "UpperFalls",
		bp = Kit.build("UpperFalls", "waterfall", fx, fz, rot).bp,
		at = { x = fx, y = top, z = fz, rot = rot },
		tag = "waterfall",
	}
	local bp = b.bp
	-- the rock step: two tiers of border rock behind the fall (they stand past the map edge)
	for _, r in { { -6, 0, 9, 10 }, { 6, 0, 9, 10 }, { 0, -0.5, 12, 11 }, { -3.5, 6, 11, 8 }, { 3.5, 6, 11, 8 } } do
		Kit.rock(bp, r[1], r[2], r[3], r[4], Kit.stone, "shell")
	end
	bp:rbox(4.4, 1.2, 3.4, 0, 10.4, 6, -8, 0, 0, o(Kit.mossyStone, "shell", { q = false }))
	-- the sheets from the lip of the step into the head of the brook
	local ay, az = 10.6, 4.8
	local by, bz = 0.2, 1
	local sheet = math.sqrt((ay - by) ^ 2 + (az - bz) ^ 2)
	local tilt = math.deg(math.atan2(az - bz, ay - by))
	for k = -1, 1 do
		bp:rbox(
			2.6 - math.abs(k) * 0.6,
			sheet,
			0.4,
			k * 1.9,
			(ay + by) / 2,
			(az + bz) / 2,
			tilt,
			0,
			k * 3,
			o({ c = "#CFE6F2", m = "Glass" }, "shell", {
				col = false,
				q = false,
				t = 0.35 + math.abs(k) * 0.12,
				tag = if k == 0 then "waterfall" else nil,
				jitter = 0,
			})
		)
	end
	bp:add(
		"ball",
		7,
		1.1,
		5,
		0,
		0.1,
		0,
		0,
		0,
		0,
		o({ c = "#E8F2F6", m = "SmoothPlastic" }, "detail", { col = false, t = 0.45, tag = "foam", jitter = 0 })
	)
	table.insert(out, b)
	local wx, wy, wz = Kit.worldOf(b, 0, 0.4, 0)
	Kit.life("mist", wx, wy, wz, 5)
	-- spray where the brook leaves the plateau (the lower fall's own mist lies on the pool, Water.waterfall)
	local lip = line.pts[#line.pts]
	Kit.life("mist", lip[1], MeadowsTerrain.streamLevel(3, line.length), lip[2], 5)
end

-- Rabbit Fields: the broken pasture fence and the knocked-down wattle --------------------------------------

local function pastureFence(out: { Build })
	local x0, z0, z1 = -548, -170, -42
	local b = Kit.build("PastureFence", "field", x0, (z0 + z1) / 2, 0)
	local bp = b.bp
	local rng = bp.rng
	local seg = 8
	local broken = { [8] = true, [9] = true }
	local k = 0
	local z = z0
	while z < z1 - 0.5 do
		k += 1
		local za, zb = z, math.min(z + seg, z1)
		local mid = (za + zb) / 2
		local lx = rng:float(-0.6, 0.6)
		local la, lb = za - b.at.z, zb - b.at.z
		if free(x0, mid, -3) then
			keep(x0, mid, 5)
			if broken[k] then
				-- the gap: one post knocked flat, one leaning, the rails on the grass, wool on the splinters
				bp:rbox(
					0.4,
					3,
					0.4,
					lx,
					Kit.gy(b, lx, la) + 0.9,
					la + 0.6,
					0,
					0,
					38,
					o(Kit.greyPlanks, "detail", { col = false })
				)
				bp:rbox(
					0.4,
					0.4,
					3,
					lx + 1,
					Kit.gy(b, lx + 1, la + 3) + 0.2,
					la + 3,
					0,
					20,
					0,
					o(Kit.greyPlanks, "detail", { col = false })
				)
				for i = 1, 2 do
					local rx = lx + (i - 1.5) * 2.4
					bp:rbox(
						0.3,
						0.3,
						seg * 0.8,
						rx,
						Kit.gy(b, rx, (la + lb) / 2) + 0.15,
						(la + lb) / 2,
						0,
						(i * 2 - 3) * 14,
						0,
						o(Kit.greyPlanks, "detail", { col = false })
					)
				end
				for i = 1, 3 do
					local wx, wz = lx + rng:float(-1.5, 1.5), la + i * 2.2
					bp:add(
						"ball",
						0.7,
						0.5,
						0.7,
						wx,
						Kit.gy(b, wx, wz) + 0.3,
						wz,
						0,
						0,
						0,
						o(WOOL, "fine", { col = false })
					)
				end
				bp:add(
					"ball",
					0.5,
					0.4,
					0.5,
					lx,
					Kit.gy(b, lx, la) + 1.6,
					la + 0.9,
					0,
					0,
					0,
					o(WOOL, "fine", { col = false })
				)
			else
				Parts.fence(bp, lx, Kit.gy(b, lx, la), la, lx, Kit.gy(b, lx, lb), lb, "rail")
			end
		end
		z = zb
	end
	table.insert(out, b)
	-- the vegetable plot (fence_1..4 at its corners): two wattle panels torn off and trampled north of it
	local p = Kit.build("TornWattle", "farm", -611, -220, 0)
	for i, w in { { -3.5, 0, 12 }, { 3, 0.6, -18 } } do
		local wx, wz = w[1], w[2]
		p.bp:rbox(
			4,
			0.35,
			1.8,
			wx,
			Kit.gy(p, wx, wz) + 0.25,
			wz,
			0,
			w[3],
			if i == 1 then 4 else -6,
			o(Palette.planks[1], "detail", { col = false })
		)
		p.bp:rbox(
			0.4,
			3,
			0.4,
			wx + 2.4,
			Kit.gy(p, wx + 2.4, wz) + 1,
			wz + 0.4,
			0,
			0,
			if i == 1 then -30 else 24,
			o(Palette.planks[2], "detail", { col = false })
		)
	end
	table.insert(out, p)
end

-- Wolf Hills: trodden trails of the pack between the dens -------------------------------------------------

local TRAILS: { { { number } } } = {
	{ { -282, -244 }, { -300, -212 }, { -322, -182 }, { -364, -126 }, { -388, -90 }, { -398, -48 } },
	{ { -396, -34 }, { -386, -4 }, { -362, 40 }, { -332, 80 }, { -306, 104 } },
	{ { -306, 118 }, { -340, 160 }, { -386, 202 }, { -424, 242 } },
}

local function wolfTrails(out: { Build })
	for ti, pts in TRAILS do
		local first = pts[1]
		local b = Kit.build(`WolfTrail_{ti}`, "den", first[1], first[2], 0)
		local bp = b.bp
		local rng = bp.rng
		local sinceKeep = 99
		for i = 1, #pts - 1 do
			local a, c = pts[i], pts[i + 1]
			local seglen = math.sqrt((c[1] - a[1]) ^ 2 + (c[2] - a[2]) ^ 2)
			local steps = math.floor(seglen / 3)
			for k = 0, steps - 1 do
				local t1, t2 = k / steps, (k + 1) / steps
				local wobble = math.sin((i * 7 + k) * 0.7) * 1.2
				local x1, z1 = a[1] + (c[1] - a[1]) * t1 + wobble, a[2] + (c[2] - a[2]) * t1
				local x2, z2 = a[1] + (c[1] - a[1]) * t2 + wobble, a[2] + (c[2] - a[2]) * t2
				local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
				if
					MeadowsTerrain.roadDistance(mx, mz) > 1
					and MeadowsTerrain.streamDistance(mx, mz) > 4
					and not MeadowsTerrain.isWater(mx, mz)
					and MeadowsTerrain.slope(mx, mz, 2) < 0.8
				then
					local l1x, l1z = x1 - b.at.x, z1 - b.at.z
					local l2x, l2z = x2 - b.at.x, z2 - b.at.z
					bp:beam(
						l1x,
						Kit.gy(b, l1x, l1z) + 0.06,
						l1z,
						l2x,
						Kit.gy(b, l2x, l2z) + 0.06,
						l2z,
						rng:float(1.3, 2),
						o({ c = bp:jitter("#6E5E44", 0.08), m = "Ground" }, "detail", { col = false }),
						0.12
					)
					sinceKeep += 3
					if sinceKeep >= 9 then
						keep(mx, mz, 3)
						sinceKeep = 0
					end
				end
			end
		end
		table.insert(out, b)
	end
end

-- Toad Pond ---------------------------------------------------------------------------------------------

-- Boardwalks of planks over the shallows from hummock to hummock (the planks are walkable, like the jetty).
local BOARDWALKS: { { number } } = {
	{ -596, 436, -560, 470 },
	{ -656, 652, -612, 658 },
	{ -492, 612, -440, 622 },
}

local function boardwalks(out: { Build })
	local deck = MeadowsTerrain.LAKE_LEVEL + 0.55
	for i, r in BOARDWALKS do
		local x1, z1, x2, z2 = r[1], r[2], r[3], r[4]
		local b = Kit.build(`Boardwalk_{i}`, "jetty", x1, z1, 0)
		b.at.y = deck
		local bp = b.bp
		local rng = bp.rng
		local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
		local yaw = math.deg(math.atan2(-(z2 - z1), x2 - x1))
		local n = math.floor(len / 3)
		local px, pz = math.sin(math.rad(yaw)), math.cos(math.rad(yaw)) -- across the walk
		for k = 0, n do
			local t = k / n
			local wx, wz = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
			local h = MeadowsTerrain.height(wx, wz)
			local w = MeadowsTerrain.water(wx, wz)
			local shallow = (w ~= nil and w - h < 2.6) or (w == nil and h < deck - 0.15)
			if shallow and Nature.isClear(wx, wz, 0) and k % 5 ~= 3 then
				local lx, lz = wx - b.at.x, wz - b.at.z
				local gy = h - deck
				bp:rbox(
					2.9,
					0.3,
					1.5,
					lx,
					0,
					lz,
					rng:float(-2, 2),
					yaw + rng:float(-6, 6),
					0,
					o(Palette.greyPlanks[2], "shell", { q = true })
				)
				bp:rbox(2.9, 0.08, 0.15, lx, 0.18, lz, 0, yaw, 0, o(Palette.greyPlanks[1], "fine", { col = false }))
				if k % 2 == 0 then
					-- the hummock the plank rests on: a tuft of sedge just out of the water
					bp:add(
						"ball",
						3.2,
						math.max(1.2, -gy + 0.6),
						2.6,
						lx,
						gy + 0.1,
						lz,
						0,
						k * 30,
						0,
						o(EARTH, "detail", { col = false })
					)
					bp:add(
						"ball",
						2.2,
						0.9,
						2,
						lx + px * 2,
						0.05,
						lz + pz * 2,
						0,
						k * 30,
						0,
						o({ c = "#6A7A3A", m = "LeafyGrass" }, "detail", { col = false })
					)
				else
					bp:add(
						"cyl",
						0.6 - gy,
						0.4,
						0.4,
						lx + px * 0.9,
						gy / 2 + 0.15,
						lz + pz * 0.9,
						0,
						0,
						90,
						o(Kit.timber, "detail", { col = false })
					)
				end
			end
		end
		table.insert(out, b)
	end
	-- low mist lying on the open water
	Kit.life("mist", -480, MeadowsTerrain.LAKE_LEVEL + 0.5, 530, 34)
	Kit.life("mist", -548, MeadowsTerrain.LAKE_LEVEL + 0.5, 612, 26)
end

-- Wit's nets drying on the shore by the net quest's place (net_shore keeps its room).
local function shoreNets(out: { Build })
	local x, z = -513, 415
	if not free(x, z, -2, 3) then
		return
	end
	keep(x, z, 7)
	local b = Kit.build("ShoreNets", "fisher", x, z, 25)
	local bp = b.bp
	for _, k in { -3, 3 } do
		bp:box(0.4, 4.6, 0.4, k, Kit.gy(b, k, 0) + 2.1, 0, o(Kit.timber, "detail"))
	end
	bp:box(6.6, 0.25, 0.25, 0, Kit.gy(b, 0, 0) + 4.3, 0, o(Kit.timber, "detail"))
	bp:box(5.8, 3, 0.1, 0, Kit.gy(b, 0, 0) + 2.8, 0, o({ c = "#8A8670", m = "Fabric" }, "detail", { t = 0.4 }))
	-- cork floats along the top of the net, a rolled net and a creel
	for k = -2, 2 do
		bp:add(
			"ball",
			0.35,
			0.35,
			0.35,
			k * 1.2,
			Kit.gy(b, 0, 0) + 4.05,
			-0.1,
			0,
			0,
			0,
			o({ c = "#C8A86A", m = "Wood" }, "fine")
		)
	end
	bp:add(
		"cyl",
		3,
		1.1,
		1.1,
		1,
		Kit.gy(b, 1, -3) + 0.5,
		-3,
		0,
		15,
		0,
		o({ c = "#7A7660", m = "Fabric" }, "detail", { col = false })
	)
	bp:add(
		"cyl",
		1.2,
		1.4,
		1.4,
		-2.2,
		Kit.gy(b, -2.2, -2.6) + 0.6,
		-2.6,
		0,
		0,
		90,
		o(Kit.straw, "detail", { col = false })
	)
	table.insert(out, b)
end

-- Snares and empty cages around the poachers' hideouts (outside their circle).
local function cage(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	local wood = Palette.timber[1]
	bp:box(2.4, 0.25, 2, 0, 0.12, 0, o(Palette.planks[2], "detail", { col = false }))
	for _, c in { { -1.1, -0.9 }, { 1.1, -0.9 }, { 1.1, 0.9 }, { -1.1, 0.9 } } do
		bp:box(0.2, 1.9, 0.2, c[1], 1, c[2], o(wood, "detail", { col = false }))
	end
	bp:box(2.4, 0.2, 2, 0, 1.95, 0, o(Palette.planks[2], "detail", { col = false }))
	for k = -2, 2 do
		bp:box(0.08, 1.7, 0.08, k * 0.45, 1, 0.92, o(wood, "fine", { col = false }))
		bp:box(0.08, 1.7, 0.08, k * 0.45, 1, -0.92, o(wood, "fine", { col = false }))
	end
	-- the door hangs open
	bp:rbox(0.1, 1.6, 1.6, 1.6, 1, -0.2, 0, 35, 0, o(wood, "fine", { col = false }))
	bp:pop()
end

local function snare(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	-- a bent sapling with the cord and a noose of cord on the ground
	bp:beam(0, 0, 0, 0.6, 3.2, 1.6, 0.18, o(Kit.bark, "detail", { col = false }))
	bp:beam(0.6, 3.2, 1.6, 0, 0.3, 2.6, 0.04, o(Kit.rope, "fine", { col = false }))
	for k = 0, 3 do
		local a = k * math.pi / 2
		local ax, az = math.cos(a) * 0.5, 2.6 + math.sin(a) * 0.5
		local bx, bz = math.cos(a + math.pi / 2) * 0.5, 2.6 + math.sin(a + math.pi / 2) * 0.5
		bp:beam(ax, 0.1, az, bx, 0.1, bz, 0.05, o(Kit.rope, "fine", { col = false }))
	end
	bp:box(0.2, 0.6, 0.2, 0, 0.2, 3.4, o(Kit.timber, "fine", { col = false }))
	bp:pop()
end

local function poacherTraps(out: { Build })
	for _, lair in (Areas.lairs or {}) :: { AreaTypes.Lair } do
		if lair.theme == "poachers" then
			local b = Kit.build(`PoacherTraps_{lair.id}`, "lair", lair.x, lair.z, 0)
			local bp = b.bp
			local placed = 0
			for i = 0, 11 do
				local a = math.rad(lair.rot + 180 + (i - 5.5) * 24)
				local d = lair.r + 4 + (i % 3) * 2
				local wx, wz = lair.x + math.sin(a) * d, lair.z + math.cos(a) * d
				if placed < 5 and free(wx, wz, -2) then
					placed += 1
					keep(wx, wz, 3)
					local lx, lz = wx - b.at.x, wz - b.at.z
					local y = Kit.gy(b, lx, lz)
					if placed % 2 == 1 then
						snare(bp, lx, y, lz, math.deg(a) + 90)
					else
						cage(bp, lx, y, lz, math.deg(a))
					end
				end
			end
			if placed > 0 then
				table.insert(out, b)
			end
		end
	end
end

-- Merchant Road -------------------------------------------------------------------------------------------

local function markedCrate(bp: BP, x: number, y: number, z: number, s: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(s, s, s, 0, s / 2, 0, o(Palette.planks[2], "detail"))
	bp:box(s * 0.55, s * 0.55, 0.08, 0, s * 0.55, -s / 2 - 0.05, o(MERCHANT, "fine", { col = false }))
	bp:add(
		"cyl",
		0.06,
		s * 0.28,
		s * 0.28,
		0,
		s * 0.55,
		-s / 2 - 0.1,
		0,
		90,
		0,
		o(MERCHANT_SIGN, "fine", { col = false })
	)
	bp:pop()
end

local function merchantGoods(out: { Build })
	-- the merchant's crates among the bandits' loot (inside the palisade, by the sacks)
	local c = sites.banditCamp
	local b = Kit.build("StolenCrates", "camp", c.x - 26, c.z - 15, 0)
	local bp = b.bp
	markedCrate(bp, 0, Kit.gy(b, 0, 0), 0, 2.2, 12)
	markedCrate(bp, 2.4, Kit.gy(b, 2.4, -0.8), -0.8, 2, -8)
	markedCrate(bp, 0.6, Kit.gy(b, 0, 0) + 2.2, -0.2, 1.8, 30)
	markedCrate(bp, -1.2, Kit.gy(b, -1.2, -3), -3, 1.8, 50)
	-- a pried-open one with a bolt of the merchant's cloth spilling out
	bp:rbox(
		2,
		0.25,
		2,
		-2.6,
		Kit.gy(b, -2.6, 1.4) + 0.12,
		1.4,
		0,
		20,
		0,
		o(Palette.planks[1], "detail", { col = false })
	)
	bp:rbox(0.9, 0.9, 2.8, -2.4, Kit.gy(b, -2.4, 1.6) + 0.45, 1.6, 0, 60, 0, o(MERCHANT, "fine", { col = false }))
	table.insert(out, b)
	-- Lucjan's wreck: the torn tarp with the same sign, thrown off the cargo
	local w = sites.wagon
	local tx, tz = Kit.toWorld(w.x, w.z, w.rot, 4.5, -2)
	local t = Kit.build("WreckTarp", "wagon", tx, tz, w.rot + 20)
	t.bp:rbox(4.2, 0.15, 3.2, 0, Kit.gy(t, 0, 0) + 0.25, 0, 6, 0, -4, o(MERCHANT, "detail", { col = false }))
	t.bp:rbox(1.6, 0.6, 2.6, 1.5, Kit.gy(t, 1.5, 0) + 0.35, 0.2, 0, 10, 20, o(MERCHANT, "detail", { col = false }))
	t.bp:add(
		"cyl",
		0.06,
		1.2,
		1.2,
		-0.6,
		Kit.gy(t, 0, 0) + 0.38,
		0.2,
		0,
		0,
		90,
		o(MERCHANT_SIGN, "fine", { col = false })
	)
	table.insert(out, t)
end

-- Kobolds dig ditches on the road's verge (for ore and whatever falls off the carts): a trench, spoil, tools, their
-- small green lantern on a stake.
local DITCHES: { { number } } = { { 254, 356, -32 }, { 407, 336, 33 } }

local function koboldDitches(out: { Build })
	for i, d in DITCHES do
		local x, z, rot = d[1], d[2], d[3]
		if free(x, z, -3, 2) then
			keep(x, z, 7)
			local b = Kit.build(`KoboldDitch_{i}`, "quarry", x, z, rot) -- local X along the road
			local bp = b.bp
			bp:rbox(9, 0.4, 1.8, 0, Kit.gy(b, 0, 0) - 0.12, 0, 0, 0, 0, o(DARK_EARTH, "detail", { col = false }))
			for k = -1, 1 do
				local mx = k * 3.2
				bp:add(
					"ball",
					3,
					1.2,
					2,
					mx,
					Kit.gy(b, mx, 2.2) + 0.2,
					2.2,
					0,
					k * 20,
					0,
					o(EARTH, "detail", { col = false })
				)
			end
			-- a spade stuck in the spoil, a pick on the ground
			local sy = Kit.gy(b, 2.6, 2.2)
			bp:rbox(0.18, 3, 0.18, 2.6, sy + 1.6, 2.2, 0, 0, -14, o(Kit.planks, "fine", { col = false }))
			bp:rbox(0.9, 1, 0.12, 2.35, sy + 0.4, 2.2, 0, 0, -14, o(Kit.iron, "fine", { col = false }))
			local py = Kit.gy(b, -3.6, -1.6)
			bp:rbox(0.18, 0.18, 2.6, -3.6, py + 0.15, -1.6, 0, 30, 0, o(Kit.planks, "fine", { col = false }))
			bp:rbox(1.6, 0.18, 0.25, -3.6 + 0.65, py + 0.18, -1.6 - 1.1, 0, 30, 0, o(Kit.iron, "fine", { col = false }))
			Kit.lantern(bp, -4.8, Kit.gy(b, -4.8, 2.6), 2.6, KOBOLD_LIGHT, 2.6)
			table.insert(out, b)
		end
	end
end

-- Goblin Camp: loot from the farms ---------------------------------------------------------------------------

local function goblinLoot(out: { Build })
	local c = sites.goblinCamp
	local b = Kit.build("GoblinLoot", "camp", c.x - 24, c.z + 6, 0)
	local bp = b.bp
	local function gy(lx: number, lz: number): number
		return Kit.gy(b, lx, lz)
	end
	-- grain sacks, cabbages, a cart wheel, a pitchfork, a butter churn, a wicker hen coop, a bundle of hay
	for i, p in { { -1.5, 0.5 }, { 0.6, -0.8 }, { -0.2, 1.8 } } do
		bp:add(
			"ball",
			2,
			2.3,
			1.7,
			p[1],
			gy(p[1], p[2]) + 0.9,
			p[2],
			0,
			i * 40,
			0,
			o({ c = bp:jitter("#B8A27A", 0.06), m = "Fabric" }, "detail", { col = false })
		)
	end
	for k = 1, 5 do
		local lx, lz = 2 + (k % 3) * 0.9, 1.4 + math.floor(k / 3) * 0.9
		bp:add(
			"ball",
			1.1,
			0.9,
			1.1,
			lx,
			gy(lx, lz) + 0.45,
			lz,
			0,
			k * 30,
			0,
			o({ c = "#6E9A4A", m = "LeafyGrass" }, "fine", { col = false })
		)
	end
	bp:rbox(0.4, 3, 3, -3.4, gy(-3.4, -1) + 1.4, -1, 0, 20, -18, o(Palette.timber[1], "detail", { col = false }))
	bp:add("cyl", 0.5, 0.8, 0.8, -3.2, gy(-3.4, -1) + 1.4, -1, 0, 20, -18, o(Kit.iron, "fine", { col = false }))
	local fy = gy(3.4, -2.2)
	bp:rbox(0.16, 4.4, 0.16, 3.4, fy + 1.9, -2.2, 18, 0, 10, o(Kit.planks, "fine", { col = false }))
	for k = -1, 1 do
		bp:rbox(
			0.08,
			0.9,
			0.08,
			3.4 + k * 0.22 + 0.7,
			fy + 3.95,
			-2.2 + 0.7,
			18,
			0,
			10,
			o(Kit.iron, "fine", { col = false })
		)
	end
	local cy = gy(-1.4, -3.2)
	bp:add("cyl", 2.4, 1.3, 1.3, -1.4, cy + 1.2, -3.2, 0, 0, 90, o(Palette.planks[3], "detail", { col = false }))
	bp:add("cyl", 0.2, 1.4, 1.4, -1.4, cy + 2.45, -3.2, 0, 0, 90, o(Palette.planks[4], "fine", { col = false }))
	bp:box(0.12, 1.6, 0.12, -1.4, cy + 3, -3.2, o(Kit.planks, "fine", { col = false }))
	local hx, hz = 1.6, -4.2
	bp:rbox(2.2, 1.4, 1.6, hx, gy(hx, hz) + 0.7, hz, 0, -12, 0, o(Kit.straw, "detail", { col = false }))
	bp:rbox(
		2.25,
		0.5,
		1.65,
		hx,
		gy(hx, hz) + 1.2,
		hz,
		0,
		-12,
		0,
		o({ c = "#8A7040", m = "Grass" }, "fine", { col = false })
	)
	Parts.haystack(bp, -0.2, gy(-0.2, 3.6), 3.6, 1.1, "detail")
	table.insert(out, b)
end

-- The road's rests ----------------------------------------------------------------------------------------------

local function stoneBench(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	for _, sx in { -1.6, 1.6 } do
		bp:box(0.9, 1.4, 1.2, sx, 0.6, 0, o(Palette.rubble[2], "detail"))
	end
	bp:box(4.4, 0.45, 1.5, 0, 1.45, 0, o(Palette.ashlar[2], "detail"))
	bp:pop()
end

local function trough(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(4.6, 1.5, 1.8, 0, 0.6, 0, o(Palette.ashlar[1], "detail"))
	bp:box(4, 0.1, 1.2, 0, 1.3, 0, o({ c = "#3A5A6A", m = "Glass" }, "fine", { col = false, t = 0.3 }))
	bp:pop()
end

local function rests(out: { Build })
	-- by Mira behind the gate: a well and a bench (the scout stands at -690, -36)
	local g = Kit.build("GateRest", "home", -678, -54, 0)
	if free(g.at.x, g.at.z, -4, 3) then
		keep(g.at.x, g.at.z, 12)
		Props.well(g.bp, 0, Kit.gy(g, 0, 0), 0, 20)
		Parts.bench(g.bp, -11, Kit.gy(g, -11, 4), 4, 10, 4.5)
		Parts.barrel(g.bp, 3.2, Kit.gy(g, 3.2, 2.6), 2.6)
		table.insert(out, g)
	end
	-- on the saddle of the Wolf Hills, south of the road, facing east over Crow Field
	local s = Kit.build("SaddleBench", "milestone", -298, 52, 0)
	if free(s.at.x, s.at.z, -4, 3) then
		keep(s.at.x, s.at.z, 5)
		Parts.bench(s.bp, 0, Kit.gy(s, 0, 0), 0, 78, 4)
		table.insert(out, s)
	end
	-- at the stone bridge: a stone bench, a horse trough, a milestone
	local r = Kit.build("BridgeRest", "milestone", 21, 141, 70)
	if free(r.at.x, r.at.z, -4, 3) then
		keep(r.at.x, r.at.z, 8)
		stoneBench(r.bp, 0, Kit.gy(r, 0, 0), 0, 0)
		trough(r.bp, 5.6, Kit.gy(r, 5.6, 0.6), 0.6, 0)
		local m = r.bp
		local my = Kit.gy(r, -4, -1)
		m:box(1.6, 2.6, 0.9, -4, my + 1, -1, o(Palette.ashlar[2], "shell", { q = true }))
		m:add("cyl", 0.9, 1.6, 1.6, -4, my + 2.3, -1, 0, 90, 0, o(Palette.ashlar[2], "detail"))
		table.insert(out, r)
	end
end

function Dressing.all(out: { Build })
	frostedTower(out)
	fallenLintel(out)
	upperFalls(out)
	pastureFence(out)
	wolfTrails(out)
	boardwalks(out)
	shoreNets(out)
	poacherTraps(out)
	merchantGoods(out)
	koboldDitches(out)
	goblinLoot(out)
	rests(out)
end

return Dressing
