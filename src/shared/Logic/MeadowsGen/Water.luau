--!strict
-- Water features of the Whispering Meadows (S26): bridges where roads cross the streams (a stone arch bridge on
-- the merchant road, timber bridges elsewhere), stepping stones at the ford of the forest path, the waterfall into
-- Bear Ravine (a curtain of falling water with spray and mist on the client) and stones along the brook. Pure.

local Areas = require("../../Data/Areas/meadows")
local Kit = require("./Kit")
local MeadowsTerrain = require("../MeadowsTerrain")
local Palette = require("../TownGen/Palette")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o

local Water = {}

type Build = Kit.Build

-- Stone arch bridge along local -Z (the road), deck at y = 0 of the frame.
local function stoneBridge(b: Build, span: number, width: number, waterY: number)
	local bp = b.bp
	local stone = Palette.rubble[2]
	local dressed = Palette.ashlar[1]
	local half = span / 2
	bp:box(width, 1.2, span + 6, 0, -0.6, 0, o(stone, "shell", { q = true }))
	for _, side in { -1, 1 } do
		-- parapets
		bp:box(1, 1.4, span + 6, side * (width / 2 - 0.5), 0.7, 0, o(dressed, "shell", { q = true }))
		bp:box(1.2, 0.3, span + 6.2, side * (width / 2 - 0.5), 1.5, 0, o(Palette.ashlar[2], "detail"))
		-- abutments down to the banks
		bp:box(width + 1, 6, 4, 0, -3.6, side * (half + 1), o(stone, "shell", { q = true }))
	end
	-- arch: voussoirs under the deck from bank to bank
	local n = 9
	local rise = math.max(1.5, -waterY - 1.2)
	for k = 0, n - 1 do
		local t = (k + 0.5) / n
		local zz = -half + span * t
		-- the arch's underside: just under the deck in the middle, down to the banks at the ends
		local thick = 0.6 + rise * (2 * t - 1) ^ 2
		bp:box(
			width - 0.4,
			thick,
			span / n + 0.1,
			0,
			-1.2 - thick / 2,
			zz,
			o(Palette.rubble[(k % 3) + 1], "detail", { col = false })
		)
	end
	-- lamp at one end and moss
	Kit.lantern(bp, width / 2 + 0.6, 0, -half - 2, nil, 6)
	bp:box(width * 0.6, 0.2, 3, 0, -1.25, half - 2, o(Kit.moss, "fine", { col = false }))
end

-- Timber bridge: plank deck on two beams, posts in the water, rails.
local function woodBridge(b: Build, span: number, width: number, waterY: number)
	local bp = b.bp
	local half = span / 2 + 2
	bp:box(width, 0.6, span + 4, 0, -0.3, 0, o(Palette.greyPlanks[2], "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:box(0.8, 1, span + 4, side * (width / 2 - 1), -1.1, 0, o(Kit.timber, "detail", { col = false }))
		bp:box(0.4, 0.4, span + 4, side * (width / 2 - 0.2), 2.6, 0, o(Kit.timber, "shell", { q = false }))
		for k = 0, 3 do
			local zz = -half + k * (2 * half) / 3
			bp:box(0.5, 3, 0.5, side * (width / 2 - 0.2), 1.2, zz, o(Kit.timber, "detail"))
			bp:add(
				"cyl",
				-waterY + 3,
				0.9,
				0.9,
				side * (width / 2 - 1),
				(waterY - 3) / 2 - 1,
				zz,
				0,
				0,
				90,
				o(Kit.timber, "detail", { col = false })
			)
		end
	end
	for k = 0, math.floor((span + 4) / 1.3) do
		bp:box(width + 0.1, 0.1, 0.22, 0, 0.02, -half + k * 1.3, o(Palette.greyPlanks[3], "fine"))
	end
end

-- Stepping stones across a ford beside the road.
local function ford(b: Build, span: number)
	local bp = b.bp
	local n = math.floor(span / 2.2)
	for k = 0, n do
		local zz = -span / 2 + k * span / n
		local lx = 7 + (k % 2) * 0.8
		local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, lx, zz)
		local y = MeadowsTerrain.height(wx, wz) - b.at.y
		local water = MeadowsTerrain.water(wx, wz)
		local top = if water then water - b.at.y + 0.35 else y + 0.3
		bp:rbox(
			1.8,
			top - y + 0.6,
			1.6,
			lx,
			(top + y - 0.6) / 2,
			zz,
			0,
			k * 23,
			0,
			o(Kit.mossyStone, "shell", { q = false })
		)
	end
	-- a post with a rope across for the deeper middle
	for _, side in { -1, 1 } do
		local zz = side * (span / 2 - 1)
		local wx, wz = Kit.toWorld(b.at.x, b.at.z, b.at.rot, -6.5, zz)
		local y = MeadowsTerrain.height(wx, wz) - b.at.y
		bp:box(0.5, 4, 0.5, -6.5, y + 1.6, zz, o(Kit.timber, "detail"))
	end
	bp:beam(-6.5, 3.2, -span / 2 + 1, -6.5, 2.6, span / 2 - 1, 0.12, o(Kit.rope, "fine"))
end

function Water.bridges(out: { Build })
	for i, c in MeadowsTerrain.crossings() do
		-- the frame's -Z runs along the road
		local rot = math.deg(math.atan2(-c.dirX, -c.dirZ))
		local width = if c.kind == "stone" then 13 else 11
		local name = `Bridge_{i}_{c.kind}`
		local b: Build = {
			name = name,
			bp = Kit.build(name, "bridge", c.x, c.z, rot).bp,
			at = { x = c.x, y = c.deck + 0.05, z = c.z, rot = rot },
			tag = "bridge",
		}
		local waterY = c.water - b.at.y
		if c.kind ~= "ford" then
			Kit.rect("bridge", c.x, c.z, width, c.span + 4, rot)
		end
		if c.kind == "stone" then
			stoneBridge(b, c.span, width, waterY)
		elseif c.kind == "ford" then
			b.at.y = MeadowsTerrain.height(c.x, c.z)
			ford(b, c.span + 6)
		else
			woodBridge(b, c.span, width, waterY)
		end
		table.insert(out, b)
	end
end

-- The waterfall (W30, owner: "no falling water"): the brook leaves the plateau at the edge of the ravine wall (where
-- the ground first drops under its surface) and falls clear of the wall into the pool. Before, the sheets ran from the
-- lip on the plateau straight to the foot of the wall and most of them lay inside the rock. Now: three sheets from the
-- edge to the first water of the pool, never in the rock (tests/meadowsterrain.spec); the middle one is "waterfall"
-- (the client hangs curved camera-facing beams with scrolling streaks and falling drops on it, TownFxController),
-- two layers of foam on the pool ("foam": mist and splashes), dark wet rocks at the edge, beside the curtain and
-- round the pool.
Water.FALL = table.freeze({ main = 6.4, side = 2.8, sideAt = 3.8, thick = 0.5 })

local WET = { c = "#3E4850", m = "Slate" } -- rock darkened by the spray
local WET_MOSS = { c = "#44513F", m = "Slate" }
local FALL_WATER = { c = "#CFE6F2", m = "Glass" }

export type FallGeometry = {
	x: number, -- the edge (map-relative)
	z: number,
	dx: number, -- downstream direction (unit, horizontal)
	dz: number,
	top: number, -- the brook's surface on the plateau
	pool: number, -- the pool's surface
	horiz: number, -- horizontal distance from the edge to the foot of the fall (in the pool)
}

-- Where the fall is (pure; the build below and the test read the same numbers).
function Water.fallGeometry(): FallGeometry
	local line = MeadowsTerrain.streamLine(3)
	local lip = line.pts[#line.pts]
	local prev = line.pts[#line.pts - 1]
	local dx, dz = lip[1] - prev[1], lip[2] - prev[2]
	local len = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / len, dz / len
	local top = MeadowsTerrain.streamLevel(3, line.length)
	local pool = MeadowsTerrain.streamLevel(1, 0)
	-- the edge: the last step of the brook's own water on the plateau
	local edge = 0
	for t = 0, 30, 0.5 do
		if MeadowsTerrain.water(lip[1] + dx * t, lip[2] + dz * t) == nil then
			break
		end
		edge = t
	end
	local ex, ez = lip[1] + dx * edge, lip[2] + dz * edge
	-- the water falls straight down the face of the wall (its steepest way down below the edge), which meets the
	-- brook at a slant: along the brook one side of the curtain would lie on the rock
	local fx, fz = ex + dx * 2, ez + dz * 2
	local gx = MeadowsTerrain.height(fx + 1, fz) - MeadowsTerrain.height(fx - 1, fz)
	local gz = MeadowsTerrain.height(fx, fz + 1) - MeadowsTerrain.height(fx, fz - 1)
	local glen = math.sqrt(gx * gx + gz * gz)
	if glen > 1 then
		dx, dz = -gx / glen, -gz / glen
	end
	-- the foot (studio review 2026-10-21: before, it lay on the pool's shallow rim, which the voxels write as dry
	-- ground, so the curtain and the foam ended on a bank short of the water): the nearest point where the voxels show
	-- the pool's water there and a stud back toward the wall (TerrainLayers.voxelWater; the plunge pool of
	-- Data/Terrain/meadows brings it to the foot of the wall) and the whole curtain clears the wall
	local function wet(t: number): boolean
		return TerrainLayers.voxelWater(MeadowsTerrain.height, MeadowsTerrain.water, ex + dx * t, ez + dz * t) ~= nil
	end
	local drop = top - pool
	local reach = Water.FALL.sideAt + Water.FALL.side / 2
	local function clears(horiz: number): boolean
		for f = 0.05, 0.97, 0.02 do
			local y = top - drop * f
			if y > pool + 0.8 and y < top - 1.5 then
				for u = -reach, reach, reach / 4 do
					-- (the side sheets hang a little behind the middle one)
					local t = horiz * f - (if math.abs(u) > Water.FALL.main / 2 then 0.5 else 0.2)
					if MeadowsTerrain.height(ex + dx * t - dz * u, ez + dz * t + dx * u) > y - 0.3 then
						return false
					end
				end
			end
		end
		return true
	end
	local horiz = 10
	for t = 3, 30, 0.5 do
		if wet(t) and wet(t - 1) and clears(t) then
			horiz = t
			break
		end
	end
	return { x = ex, z = ez, dx = dx, dz = dz, top = top, pool = pool, horiz = horiz }
end

function Water.waterfall(out: { Build })
	local g = Water.fallGeometry()
	local rot = math.deg(math.atan2(-g.dx, -g.dz)) -- local -Z downstream
	local b: Build = {
		name = "Waterfall",
		bp = Kit.build("Waterfall", "waterfall", g.x, g.z, rot).bp,
		at = { x = g.x, y = g.pool, z = g.z, rot = rot },
		tag = "waterfall",
	}
	local bp = b.bp
	local horiz = g.horiz
	local drop = g.top - g.pool + 0.3
	local tilt = math.deg(math.atan2(horiz, drop))
	local sheetLen = math.sqrt(horiz * horiz + drop * drop)
	local F = Water.FALL
	-- the curtain: the wide middle sheet and two narrower ones a little behind it, slightly turned
	for k = -1, 1 do
		local side = k ~= 0
		bp:rbox(
			if side then F.side else F.main,
			sheetLen,
			if side then F.thick * 0.8 else F.thick,
			k * F.sideAt,
			drop / 2,
			-horiz / 2 + (if side then 0.35 else 0),
			tilt,
			0,
			k * 3,
			o(FALL_WATER, "shell", {
				col = false,
				q = false,
				t = if side then 0.5 else 0.4,
				tag = if side then nil else "waterfall",
				jitter = 0,
			})
		)
	end
	-- the white water where the brook tips over the edge
	bp:rbox(
		F.main + 1,
		0.4,
		1.6,
		0,
		drop - 0.1,
		-0.4,
		-12,
		0,
		0,
		o({ c = "#EEF6FA", m = "SmoothPlastic" }, "detail", { col = false, q = false, t = 0.35, jitter = 0 })
	)
	-- foam where it hits the pool: a wide ring and a brighter core
	bp:add(
		"ball",
		12,
		1.2,
		9,
		0,
		0.15,
		-horiz - 1,
		0,
		0,
		0,
		o({ c = "#E8F2F6", m = "SmoothPlastic" }, "detail", { col = false, t = 0.5, tag = "foam", jitter = 0 })
	)
	bp:add(
		"ball",
		7,
		1,
		4.5,
		0,
		0.3,
		-horiz + 0.5,
		0,
		0,
		0,
		o({ c = "#F6FBFD", m = "SmoothPlastic" }, "detail", { col = false, t = 0.35, jitter = 0 })
	)
	-- wet rocks: on both sides of the edge, beside the curtain on the wall, round the pool
	-- (each stands on the ground, its side clear of the curtain: the sheets reach FALL.sideAt + side / 2 = 5.2)
	for k = -1, 1, 2 do
		for i, r in { { 8.8, 0.8, 4 }, { 8.6, -horiz * 0.35, 4 }, { 9, -horiz - 1.5, 5 } } do
			local lx, lz = k * r[1], r[2]
			Kit.rock(bp, lx, math.max(Kit.gy(b, lx, lz), -0.8), lz, r[3], if i == 2 then WET_MOSS else WET, "shell")
		end
		Kit.rock(bp, k * 6.5, -0.6, -horiz - 6, 3, WET_MOSS, "detail")
	end
	table.insert(out, b)
	local wx, wy, wz = Kit.worldOf(b, 0, 0.5, -horiz - 2)
	Kit.life("mist", wx, wy, wz, 14)
end

-- W21 (laki.md 4.9): a thin curtain of water from the plateau over the mouth of the Moss Cave, so the way in looks the
-- same from both sides (the cave's own entrance is behind a curtain of water); no collision, the mouth stays where it is.
-- Studio review 2026-10-21: the curtain stood 1.6-1.9 studs before the portal and was Glass, which Roblox draws over
-- every transparent part behind it: the portal's glowing veil and core were gone. It hangs in the mouth now, behind
-- the veil (z 0) and before the dark hole (World/Prefabs.caveMouth, z 2.9), out of the portal's clearance box
-- (Data/Portals, half depth 1.25), and is SmoothPlastic (tests/portalglass.spec: no Glass before any portal).
Water.CURTAIN_Z = 1.75 -- the middle sheet; the side ones 0.3 deeper
function Water.caveCurtain(out: { Build })
	local m = { x = 745, z = 330, rot = 45 }
	for _, mouth in (Areas :: any).caves or {} do
		if mouth.cave == "meadows_cave" then
			m = mouth
		end
	end
	local b = Kit.build("CaveCurtain", "waterfall", m.x, m.z, m.rot)
	b.frames = "meadows_meadows_cave"
	local bp = b.bp
	local gy = Kit.gy(b, 0, 0)
	for k = -1, 1 do
		bp:box(
			3.4 - math.abs(k) * 0.5,
			16,
			0.3,
			k * 3,
			gy + 8,
			Water.CURTAIN_Z + math.abs(k) * 0.3, -- behind the veil (W28: never through the purple field)
			o({ c = "#CFE6F2", m = "SmoothPlastic" }, "detail", {
				col = false,
				q = false,
				t = 0.5 + math.abs(k) * 0.12,
				tag = if k == 0 then "waterfall" else nil,
				jitter = 0,
			})
		)
	end
	table.insert(out, b)
	local wx, wy, wz = Kit.worldOf(b, 0, gy + 0.5, 0)
	Kit.life("mist", wx, wy, wz, 6)
end

-- Stones and gravel bars along the brook (client detail), and a few logs across the forest brook.
function Water.banks(out: { Build })
	for si = 1, 2 do
		local line = MeadowsTerrain.streamLine(si)
		local s = 30
		local i = 0
		while s < line.length - 20 do
			local x, z, dx, dz = TerrainLayers.pointAt(line, s)
			i += 1
			local side = if i % 2 == 0 then 1 else -1
			local px, pz = x - dz * side * 7, z + dx * side * 7
			if MeadowsTerrain.roadDistance(px, pz) > 8 then
				local b = Kit.build(`BrookStones_{si}_{i}`, "brook", px, pz, i * 37)
				for k = 1, 4 do
					Kit.rock(b.bp, (k - 2) * 1.6, -0.4, (k % 2) * 1.2, 1.2 + (k % 3) * 0.5, Kit.mossyStone, "detail")
				end
				table.insert(out, b)
			end
			s += if si == 1 then 70 else 90
		end
	end
end

return Water
