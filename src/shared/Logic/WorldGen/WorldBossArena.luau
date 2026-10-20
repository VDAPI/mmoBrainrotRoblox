--!strict
-- The world boss's arena (S149b, DESIGN §15.6): the Forefather's Barrow on the spot of Data/WorldBoss (one Build,
-- tag "worldBossArena", on the map the boss wakes on). Pure and deterministic, built by the region's generator
-- (Logic/FrostpeakGen) like the S134i hideouts: the generator drops its rocks and gathering nodes inside the circle
-- (`prune`), keeps its trees out (a clearing of radius r) and appends `build(ctx, spot)`.
--
-- The frame is the spot's centre, front = local -Z (the opening in the ring). Everything that stands up sits on the rim:
-- the middle (r - spot.free studs) holds no collision and no prop taller than the floor slabs, so the S149 blows, the
-- shared stone and the three brands have room (tests/frostpeak.spec). LOD: "shell" the ring of rune stones and the
-- two clan banners (seen from afar, collision), "detail" the frozen remains of giant weapons, bones, cold braziers and
-- the ice floor slabs, "fine" icicles and runes. Colours of the Peaks (snow, ice, grey stone, the giants' dark red).
-- Between the occurrences the barrow stands empty: it shows where the boss will come.

local Kit = require("./Kit")
local WorldBossData = require("../../Data/WorldBoss")

local o = Kit.o

local WorldBossArena = {}

type Build = Kit.Build
type Spot = WorldBossData.Spot

WorldBossArena.TAG = "worldBossArena"
WorldBossArena.STONES = 11 -- rune stones on the rim (an opening at the front)
WorldBossArena.OPENING = 34 -- degrees of the opening at the front (local -Z)

local SNOW = { c = "#E8EEF4", m = "Snow" }
local ICE = { c = "#A8D8F0", m = "Ice" }
local ICE_FLOOR = { c = "#BFE3F5", m = "Glacier" }
local RUNE_STONE = { c = "#6E7480", m = "Slate" }
local RUNE = { c = "#9FD8FF", m = "Neon" }
local GIANT_STEEL = { c = "#5C6670", m = "CorrodedMetal" }
local BANNER = { c = "#4A1A1E", m = "Fabric" }
local BANNER_MARK = { c = "#C9D8E4", m = "Fabric" }

-- Local (x, z) of a point at `angle` degrees from the front (-Z), clockwise seen from above, at `d` studs.
local function polar(angle: number, d: number): (number, number)
	local a = math.rad(angle)
	return math.sin(a) * d, -math.cos(a) * d
end

-- The spot of the world boss on map `mapId`, or nil (only the boss's map has one).
function WorldBossArena.spotOn(mapId: string): Spot?
	if mapId ~= WorldBossData.map then
		return nil
	end
	return WorldBossData.spots[1]
end

-- Removes from `list` (Builds or node placements, from index `from` on) what stands in the arena of map `mapId` (its
-- circle grown by `extra`), unless `keep` says otherwise; every other item stays where it was.
function WorldBossArena.prune<T>(mapId: string, list: { T }, extra: number, keep: ((item: T) -> boolean)?)
	local spot = WorldBossArena.spotOn(mapId)
	if not spot then
		return
	end
	local r = spot.r + extra
	local i = 1
	while i <= #list do
		local item: any = list[i]
		local x = if item.at then item.at.x else item.x
		local z = if item.at then item.at.z else item.z
		if (x - spot.x) ^ 2 + (z - spot.z) ^ 2 < r * r and not (keep and keep(item)) then
			table.remove(list, i)
		else
			i += 1
		end
	end
end

-- One rune stone on the rim (shell), leaning a little outwards, with a rune on its inner face and icicles (fine).
local function stone(ctx: Kit.Ctx, b: Build, angle: number, d: number, k: number)
	local bp = b.bp
	local x, z = polar(angle, d)
	local y = Kit.gy(ctx, b, x, z)
	local height = 9 + (k % 3) * 1.6
	bp:push(x, y, z, 0, -angle, 0)
	bp:rbox(2.6, height, 1.8, 0, height / 2 - 0.6, 0, -4, 0, (k % 2) * 4 - 2, o(RUNE_STONE, "shell"))
	bp:box(2.8, 0.6, 2, 0, height - 0.5, 0, o(SNOW, "detail", { col = false }))
	-- the rune faces the middle (local +Z after the turn is outwards: the inner face is -Z)
	bp:box(0.5, 2.2, 0.08, 0, height * 0.55, -0.95, o(RUNE, "fine", { col = false, jitter = 0 }))
	bp:box(1.4, 0.35, 0.08, 0, height * 0.55 + 0.6, -0.95, o(RUNE, "fine", { col = false, jitter = 0 }))
	for s = -1, 1 do
		bp:add(
			"wedge",
			0.3,
			0.9 + (s + 1) * 0.3,
			0.3,
			s * 0.8,
			height - 1.3,
			-0.9,
			180,
			0,
			0,
			o(ICE, "fine", { col = false })
		)
	end
	bp:pop()
end

-- A clan banner on a tall pole (shell pole, detail cloth with the giants' white mark).
local function banner(ctx: Kit.Ctx, b: Build, angle: number, d: number)
	local bp = b.bp
	local x, z = polar(angle, d)
	local y = Kit.gy(ctx, b, x, z)
	bp:push(x, y, z, 0, -angle, 0)
	bp:box(0.6, 14, 0.6, 0, 7, 0, o(Kit.darkBark, "shell"))
	bp:box(0.4, 0.4, 5, 0, 13.4, -2.2, o(Kit.darkBark, "detail", { col = false }))
	bp:box(0.15, 6.5, 4.2, 0, 9.8, -2.4, o(BANNER, "detail", { col = false, tag = "flag" }))
	bp:box(0.18, 2.2, 1.2, 0, 10.4, -2.4, o(BANNER_MARK, "fine", { col = false }))
	bp:box(0.18, 0.5, 2.6, 0, 11.6, -2.4, o(BANNER_MARK, "fine", { col = false }))
	bp:pop()
end

-- A cold brazier (detail): a stone stand and an iron bowl full of snow, never lit.
local function brazier(ctx: Kit.Ctx, b: Build, angle: number, d: number)
	local bp = b.bp
	local x, z = polar(angle, d)
	local y = Kit.gy(ctx, b, x, z)
	bp:box(1.4, 2.4, 1.4, x, y + 1.2, z, o(Kit.darkStone, "detail", { col = false }))
	bp:add("cyl", 0.8, 3.2, 3.2, x, y + 2.7, z, 0, 0, 90, o(Kit.iron, "detail", { col = false }))
	bp:add("cyl", 0.3, 2.6, 2.6, x, y + 3.05, z, 0, 0, 90, o(Kit.charred, "fine", { col = false }))
	bp:box(2, 0.3, 2, x, y + 3.25, z, o(SNOW, "fine", { col = false }))
end

-- The frozen remains of a giant's weapon (detail, no collision): a sword blade standing in the snow, an axe head, a
-- broken spear.
local function sword(ctx: Kit.Ctx, b: Build, angle: number, d: number)
	local bp = b.bp
	local x, z = polar(angle, d)
	local y = Kit.gy(ctx, b, x, z)
	bp:push(x, y, z, 0, -angle, 0)
	bp:rbox(1.6, 11, 0.4, 0, 4.6, 0, 0, 0, 9, o(GIANT_STEEL, "detail", { col = false }))
	bp:rbox(5, 0.8, 0.9, 0.9, 10, 0, 0, 0, 9, o(GIANT_STEEL, "detail", { col = false }))
	bp:rbox(0.7, 3, 0.7, 1.15, 11.9, 0, 0, 0, 9, o(Kit.darkBark, "detail", { col = false }))
	bp:rbox(1.8, 0.6, 1.2, 0, 0.2, 0, 0, 20, 0, o(SNOW, "fine", { col = false }))
	bp:rbox(0.4, 3.6, 0.45, -0.3, 3.4, -0.1, 0, 0, 9, o(ICE, "fine", { col = false }))
	bp:pop()
end

local function axe(ctx: Kit.Ctx, b: Build, angle: number, d: number)
	local bp = b.bp
	local x, z = polar(angle, d)
	local y = Kit.gy(ctx, b, x, z)
	bp:push(x, y, z, 0, -angle + 30, 0)
	bp:rbox(0.9, 0.9, 12, 0, 0.5, 0, 6, 0, 0, o(Kit.darkBark, "detail", { col = false }))
	bp:rbox(0.5, 4.4, 3.4, 0, 1.6, -5, 6, 0, 0, o(GIANT_STEEL, "detail", { col = false }))
	bp:rbox(2.6, 0.5, 4, 0, 0.3, -3.5, 0, 15, 0, o(SNOW, "fine", { col = false }))
	bp:pop()
end

local function spear(ctx: Kit.Ctx, b: Build, angle: number, d: number)
	local bp = b.bp
	local x, z = polar(angle, d)
	local y = Kit.gy(ctx, b, x, z)
	bp:push(x, y, z, 0, -angle, 0)
	bp:rbox(0.7, 7.5, 0.7, 0, 3.2, 0, -14, 0, 6, o(Kit.darkBark, "detail", { col = false }))
	bp:rbox(0.6, 0.6, 9, 1.6, 0.3, 1.5, 0, 25, 0, o(Kit.darkBark, "detail", { col = false }))
	bp:add("wedge", 0.3, 2.4, 1, 0.4, 7.4, -0.9, -14, 0, 6, o(GIANT_STEEL, "detail", { col = false }))
	bp:pop()
end

-- The ice floor of the middle: flat slabs at the ground's height (detail, no collision, 0.3 thick: never in the way),
-- a ring of rune slabs around the centre (fine).
local function floor(ctx: Kit.Ctx, b: Build, r: number)
	local bp = b.bp
	local rng = bp.rng
	for k = 0, 17 do
		local angle = k * 20 + rng:float(-6, 6)
		local d = if k % 2 == 0 then r * 0.32 else r * 0.62
		local x, z = polar(angle, d)
		local y = Kit.gy(ctx, b, x, z)
		bp:rbox(
			rng:float(9, 14),
			0.3,
			rng:float(7, 11),
			x,
			y + 0.08,
			z,
			0,
			rng:float(0, 180),
			0,
			o(ICE_FLOOR, "detail", { col = false })
		)
	end
	local cy = Kit.gy(ctx, b, 0, 0)
	bp:add("cyl", 0.25, 16, 16, 0, cy + 0.06, 0, 0, 0, 90, o(ICE_FLOOR, "detail", { col = false }))
	for k = 0, 11 do
		local x, z = polar(k * 30, 11)
		local y = Kit.gy(ctx, b, x, z)
		bp:rbox(2.2, 0.2, 1.1, x, y + 0.12, z, 0, -k * 30, 0, o(RUNE, "fine", { col = false, jitter = 0 }))
	end
end

-- S156 (owner 2026-10-20): the barrow is a cave hollow: a ring of cliff walls just outside the rune stones (shell, with
-- collision: the way in is the opening), each with a ledge leaning in at the top (detail) and icicles hanging from it
-- (fine), never over the free middle; the opening stays open towards the vestibule.
local CLIFF = { c = "#4A4E58", m = "Slate" }
local CLIFF_DARK = { c = "#3A3D46", m = "Rock" }
local WALL_SEGMENTS = 22
local WALL_OPENING = 40 -- degrees left open at the front (wider than the stones' opening)

local function walls(ctx: Kit.Ctx, b: Build, r: number)
	local bp = b.bp
	local rng = bp.rng
	local d = r + 5
	local span = 360 - WALL_OPENING
	local width = 2 * math.pi * d * (span / 360) / WALL_SEGMENTS + 3
	for k = 0, WALL_SEGMENTS - 1 do
		local angle = WALL_OPENING / 2 + span * (k + 0.5) / WALL_SEGMENTS
		local x, z = polar(angle, d)
		local y = Kit.gy(ctx, b, x, z)
		local height = rng:float(26, 36)
		bp:push(x, y, z, 0, -angle, 0)
		-- the wall leans a little inwards (local -Z is the middle)
		bp:rbox(
			width,
			height,
			7,
			0,
			height / 2 - 1,
			1,
			-6,
			0,
			rng:float(-3, 3),
			o(if k % 2 == 0 then CLIFF else CLIFF_DARK, "shell")
		)
		-- the ledge at the top leaning over the rim (no collision), snow on it, icicles under it
		bp:rbox(width + 1, 2.4, 9, 0, height - 2, -4.5, 14, 0, 0, o(CLIFF_DARK, "detail", { col = false }))
		bp:rbox(width, 0.8, 8, 0, height - 0.6, -4, 14, 0, 0, o(SNOW, "detail", { col = false }))
		for s = -2, 2 do
			bp:add(
				"wedge",
				0.6,
				rng:float(2, 4.5),
				0.6,
				s * width / 5,
				height - 5,
				-7.5,
				180,
				0,
				0,
				o(ICE, "fine", { col = false })
			)
		end
		bp:pop()
	end
end

-- S156: the vestibule in front of the opening (Data/WorldBoss.antechamber, always free of PvP): two short cliff walls
-- making a passage, an ice arch at its outer end, stone slabs on the floor and two warm braziers that burn at every hour.
local WARM_FIRE = "#FF9A3A"
local function vestibule(ctx: Kit.Ctx, b: Build, r: number)
	local bp = b.bp
	local a = WorldBossData.antechamber
	local near, far = r + 2, r + a.d + a.r
	local half = 14
	local mid = (near + far) / 2
	local length = far - near
	for _, side in { -1, 1 } do
		local x, z = side * (half + 3), -mid
		local y = Kit.gy(ctx, b, x, z)
		bp:rbox(6, 22, length, x, y + 10, z, 0, 0, side * 5, o(CLIFF, "shell"))
		bp:rbox(7, 0.8, length, x - side * 1.5, y + 21.4, z, 0, 0, side * 5, o(SNOW, "detail", { col = false }))
		-- warm braziers along the passage
		local bx, bz = side * (half - 3), -(near + length * 0.55)
		local by = Kit.gy(ctx, b, bx, bz)
		bp:box(1.6, 2.6, 1.6, bx, by + 1.3, bz, o(Kit.darkStone, "detail", { col = false }))
		bp:add("cyl", 0.8, 3.4, 3.4, bx, by + 2.9, bz, 0, 0, 90, o(Kit.iron, "detail", { col = false }))
		Kit.fire(bp, bx, by + 3.5, bz, 1.6, WARM_FIRE)
	end
	-- the ice arch at the outer end
	local ay = Kit.gy(ctx, b, 0, -far)
	for _, side in { -1, 1 } do
		bp:box(3, 18, 3, side * half, ay + 9, -far, o(ICE, "shell"))
	end
	bp:box(half * 2 + 3, 3, 3, 0, ay + 18.5, -far, o(ICE, "shell"))
	bp:rbox(half * 2 + 4, 1, 3.4, 0, ay + 20.4, -far, 0, 0, 0, o(SNOW, "detail", { col = false }))
	-- floor slabs
	for k = 0, 5 do
		local z = -(near + length * (k + 0.5) / 6)
		local y = Kit.gy(ctx, b, 0, z)
		bp:rbox(
			half * 1.6,
			0.3,
			length / 6 - 0.6,
			0,
			y + 0.1,
			z,
			0,
			bp.rng:float(-4, 4),
			0,
			o(Kit.darkStone, "detail", { col = false })
		)
	end
end

-- The Build of the barrow on `spot` (Data/WorldBoss.spots).
function WorldBossArena.build(ctx: Kit.Ctx, spot: Spot): Build
	local b = Kit.build(ctx, `WorldBossArena_{spot.id}`, WorldBossArena.TAG, spot.x, spot.z, 0)
	local r = spot.r
	local rim = r - 3
	-- the ring: STONES rune stones evenly over the circle without the opening at the front
	local span = 360 - WorldBossArena.OPENING
	for k = 0, WorldBossArena.STONES - 1 do
		local angle = WorldBossArena.OPENING / 2 + span * k / (WorldBossArena.STONES - 1)
		stone(ctx, b, angle, rim, k)
	end
	-- two clan banners at the opening
	banner(ctx, b, -WorldBossArena.OPENING / 2 - 4, r - 6)
	banner(ctx, b, WorldBossArena.OPENING / 2 + 4, r - 6)
	-- cold braziers, giant weapons and bones between the stones, all at least `free` inside the rim
	local inner = r - spot.free + 2
	for _, angle in { 70, 160, 250, 300 } do
		brazier(ctx, b, angle, inner + 1)
	end
	sword(ctx, b, 125, inner + 2)
	axe(ctx, b, 205, inner + 3)
	spear(ctx, b, 330, inner + 2)
	for i, angle in { 45, 100, 185, 230, 280 } do
		local x, z = polar(angle, inner + 1)
		Kit.bones(b.bp, x, Kit.gy(ctx, b, x, z), z, 2 + i % 3, function(lx: number, lz: number): number
			return Kit.gy(ctx, b, lx, lz)
		end)
	end
	do
		local x, z = polar(145, inner + 3)
		Kit.skull(b.bp, x, Kit.gy(ctx, b, x, z) - 0.2, z, 3.2, 200)
	end
	floor(ctx, b, r)
	walls(ctx, b, r)
	vestibule(ctx, b, r)
	return b
end

-- The arena Build of map `mapId` (one list, empty off the boss's map).
function WorldBossArena.all(ctx: Kit.Ctx, mapId: string): { Build }
	local spot = WorldBossArena.spotOn(mapId)
	return if spot then { WorldBossArena.build(ctx, spot) } else {}
end

return WorldBossArena
