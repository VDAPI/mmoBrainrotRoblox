--!strict
-- W15-16 part 2 (docs/wyglad/mapy/bor.md A6, A7, A9, A10): the look pass over the whole Duskwood, after every module
-- and the rocks, around the forest:
--   * the view corridors (A9, A6.1 / A6.2): from the dusk gate a wedge 250 studs long and 25 degrees wide towards the
--     Elder Tree, from the wayside shrine a narrower one towards the black waterfall: no giant oaks, half the trees,
--     so the goal shows over the road; groups, roads and terrain unchanged (`keep`, read by WorldGen/Flora),
--   * shafts of light through gaps in the crowns of the Heart (A10.4): faint pale columns slanting down from the
--     afternoon sun, placed where no big tree stands (after the forest, `shafts`),
--   * warning amulets on poles by the main road where the Witch Marsh's groups stand near it (A9 risks): bone chimes
--     and charms on crooked poles at the road's edge, no collision,
--   * lily pads on the shallow water of the marshes (Troll Swamp, Witch Marsh) and of the serpents' pond,
--   * ground mist in the hollows all over the forest (A7: thickest on the Crossroads, already there).
-- No collision anywhere; the trees keep off the poles through the decoration clearings (Env.decorate), which the
-- gathering nodes do not read (their placements stay those of before). Pure.

local AreaSpawns = require("../AreaSpawns")
local Env = require("./Env")
local Flora = require("../WorldGen/Flora")
local Kit = require("../WorldGen/Kit")
local Maps = require("../../Data/Maps")
local Nature = require("./Nature")
local Props = require("./Props")

local o = Kit.o

local Dress = {}

type Build = Kit.Build

-- A corridor: apex, unit direction, length and the cosine of its half angle.
type Wedge = { x: number, z: number, dx: number, dz: number, len: number, cos: number }

local function wedge(ax: number, az: number, tx: number, tz: number, len: number, degrees: number): Wedge
	local dx, dz = tx - ax, tz - az
	local d = math.sqrt(dx * dx + dz * dz)
	return { x = ax, z = az, dx = dx / d, dz = dz / d, len = len, cos = math.cos(math.rad(degrees / 2)) }
end

local function inWedge(w: Wedge, x: number, z: number): boolean
	local vx, vz = x - w.x, z - w.z
	local along = vx * w.dx + vz * w.dz
	if along <= 0 or along > w.len then
		return false
	end
	return along / math.sqrt(vx * vx + vz * vz) >= w.cos
end

-- Stable value in [0, 1) of a point (integer arithmetic: identical on the server and on every client).
local function hash(x: number, z: number): number
	local ix, iz = math.floor(x * 4), math.floor(z * 4)
	local h = (ix * 92821 + iz * 68917) % 1000003
	h = (h * h + 7919) % 1000003
	return h / 1000003
end

local wedges: { Wedge }? = nil

local function corridors(env: Env.Env): { Wedge }
	if not wedges then
		local s = env.sites
		wedges = {
			wedge(s.duskGate.x, s.duskGate.z, s.elderTree.x, s.elderTree.z, 250, 25),
			wedge(s.wayShrine.x, s.wayShrine.z, s.blackFall.x, s.blackFall.z, 200, 16),
		}
	end
	return wedges :: { Wedge }
end

-- WorldGen/Flora `keep`: inside a view corridor no giant oak and every other tree only every second time.
function Dress.keeper(env: Env.Env): (x: number, z: number, kind: string, big: boolean) -> boolean
	local list = corridors(env)
	return function(x: number, z: number, kind: string, _big: boolean): boolean
		for _, w in list do
			if inWedge(w, x, z) then
				return kind ~= "giantOak" and hash(x, z) >= 0.5
			end
		end
		return true
	end
end

-- Warning amulets ---------------------------------------------------------------------------------------------------

local function wardPole(env: Env.Env, n: number, x: number, z: number, face: number): Build
	local ctx = env.ctx
	local b = Kit.build(ctx, `WardPole_{n}`, "traces", x, z, face)
	local bp = b.bp
	local h = 6.5 + (n % 3) * 0.6
	bp:rbox(0.4, h, 0.4, 0, h / 2 - 0.4, 0, 3, 0, -4, o(Kit.blackBark, "detail", { col = false }))
	bp:rbox(3.4, 0.3, 0.3, 0.1, h - 1.2, 0, 0, 0, 8, o(Kit.blackBark, "detail", { col = false }))
	Props.charm(bp, -1.3, h - 1.3, 0, true)
	Props.charm(bp, 1.4, h - 1, 0, n % 2 == 0)
	-- a stag's antler crowning the pole and a few small bones tied under the bar
	bp:beam(0, h - 0.4, 0, 0.8, h + 0.8, 0.2, 0.18, o(Kit.oldBone, "fine"))
	bp:beam(0.5, h + 0.3, 0.1, 1.2, h + 0.6, -0.4, 0.12, o(Kit.oldBone, "fine"))
	bp:box(0.1, 1.2, 1, 0.1, h - 2.2, 0.3, o(Kit.rag, "fine", { tag = "flag" }))
	return b
end

-- Poles at the road's edge on the side of every Witch Marsh group standing within 40 studs of a road.
local function wards(env: Env.Env, out: { Build })
	local map = Maps.get("duskwood")
	local n = 0
	for _, g in AreaSpawns.region(env.areas, if map then map.size else { x = 1600, z = 1600 }) do
		local gx, gz = g.position.x, g.position.z
		if g.areaId == "duskwood_witchmarsh" and env.T.roadDistance(gx, gz) < 40 then
			local picked: { { number } } = {}
			for dx = -44, 44, 2 do
				for dz = -44, 44, 2 do
					local x, z = gx + dx, gz + dz
					local d = math.sqrt(dx * dx + dz * dz)
					local rd = env.T.roadDistance(x, z)
					if
						d >= 14
						and d <= 44
						and rd >= 7
						and rd <= 9
						and not env.T.isWater(x, z)
						and env.T.streamDistance(x, z) > 4
						and env.T.slope(x, z, 2) < 0.6
						and Env.isClear(env, x, z, 0)
						and Env.decorClear(env, x, z, 2)
					then
						table.insert(picked, { x, z, d })
					end
				end
			end
			table.sort(picked, function(a, c)
				return a[3] < c[3]
			end)
			local placed: { { number } } = {}
			for _, p in picked do
				local apart = true
				for _, q in placed do
					if (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 < 14 * 14 then
						apart = false
					end
				end
				if apart and #placed < 3 then
					table.insert(placed, p)
					n += 1
					-- the bar across the road, facing the travellers
					local face = math.deg(math.atan2(gx - p[1], gz - p[2]))
					table.insert(out, wardPole(env, n, p[1], p[2], face))
					Env.decorate(env, p[1], p[2], 3)
				end
			end
		end
	end
end

-- Lily pads ----------------------------------------------------------------------------------------------------------

-- Shallow, calm water (no stream current) in the marshes and the serpents' pond, in clusters 8 studs apart.
local PATCHES = { { 604, 566, 230 }, { -60, 110, 110 }, { 436, -640, 14 } }

-- One Build per 64-stud cell, so the client loads only the pads near the camera.
local CELL = 64

local function lilies(env: Env.Env, out: { Build })
	for i, p in PATCHES do
		local cx, cz, r = p[1], p[2], p[3]
		local level = env.T.water(cx, cz) or -1
		local cells: { [string]: Build } = {}
		local order: { Build } = {}
		local step = if r < 30 then 5 else 8
		local count = 0
		for x = cx - r, cx + r, step do
			for z = cz - r, cz + r, step do
				local w = env.T.water(x, z)
				if
					w
					and math.abs(w - level) < 0.5
					and w - env.T.height(x, z) < 2.6
					and env.T.streamDistance(x, z) > 10
					and hash(x, z) < 0.3
				then
					count += 1
					local kx, kz = math.floor(x / CELL), math.floor(z / CELL)
					local key = `{kx}_{kz}`
					if cells[key] == nil then
						local nb =
							Kit.buildAt(`Lilies_{i}_{key}`, "pool", (kx + 0.5) * CELL, level, (kz + 0.5) * CELL, 0)
						cells[key] = nb
						table.insert(order, nb)
					end
					local cb: Build = cells[key]
					Nature.pads(cb.bp, x - cb.at.x, w - level, z - cb.at.z, 2 + count % 3)
				end
			end
		end
		for _, b in order do
			table.insert(out, b :: any)
		end
	end
end

-- Shafts of light ----------------------------------------------------------------------------------------------------

-- The afternoon sun stands in the south-west (bor.md A7: clock 15.5): the shafts lean towards the north-east.
local LEAN_X, LEAN_Z = 0.3, -0.22

function Dress.shafts(env: Env.Env, out: { Build }, trees: { Flora.TreeInfo })
	local s = env.sites.elderTree
	local b = Kit.build(env.ctx, "HeartShafts", "landmark", s.x, s.z, 0)
	local bp = b.bp
	local placed: { { number } } = {}
	for k = 0, 47 do
		if #placed >= 7 then
			break
		end
		local a = k * 2.39996
		local r = 44 + (k % 8) * 9
		local x, z = s.x + math.cos(a) * r, s.z + math.sin(a) * r
		local gap = not env.T.isWater(x, z)
		for _, t in trees do
			if gap and (t.x - x) ^ 2 + (t.z - z) ^ 2 < 11 * 11 then
				gap = false
			end
		end
		for _, q in placed do
			if gap and (q[1] - x) ^ 2 + (q[2] - z) ^ 2 < 30 * 30 then
				gap = false
			end
		end
		if gap then
			table.insert(placed, { x, z })
			local gy = env.T.height(x, z) - b.at.y
			local len = 42
			-- the column's foot on the ground, its top up in the crowns towards the sun
			local lx, lz = x - s.x, z - s.z
			local tx, ty, tz = lx - LEAN_X * len, gy + len, lz - LEAN_Z * len
			local w = 5 + (#placed % 3) * 1.5
			bp:beam(lx, gy, lz, tx, ty, tz, w, {
				c = "#F4EED8",
				m = "Neon",
				lod = "detail",
				col = false,
				q = false,
				-- owner review 2026-10-21: in Studio the Neon box read as a white slab; one faint column, no core
				t = 0.975,
				jitter = 0,
			}, w)
			Kit.lifeAt(env.ctx, b, "spores", lx, gy + 4, lz, 5)
		end
	end
	if #placed > 0 then
		table.insert(out, b)
	end
end

-- Ground mist --------------------------------------------------------------------------------------------------------

-- Hollows of the thicket, the cemetery under the manor, the lower ruins, the cult's clearing edge and the foot of the
-- cliffs (the Crossroads, the gorge, the Heart and the marshes have theirs).
local MIST = {
	{ -560, -180, 34 },
	{ -470, 160, 30 },
	{ -620, 420, 30 },
	{ -40, -380, 36 },
	{ -250, -420, 30 },
	{ 470, -520, 30 },
	{ 560, 120, 30 },
	{ 560, -300, 26 },
}

local function mist(env: Env.Env)
	for _, p in MIST do
		Kit.life(env.ctx, "mist", p[1], env.T.height(p[1], p[2]), p[2], p[3])
	end
end

-- Everything of the pass that goes before the forest.
function Dress.all(env: Env.Env, out: { Build })
	wards(env, out)
	lilies(env, out)
	mist(env)
end

return Dress
