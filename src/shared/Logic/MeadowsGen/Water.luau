--!strict
-- Water features of the Whispering Meadows (S26): bridges where roads cross the streams (a stone arch bridge on
-- the merchant road, timber bridges elsewhere), stepping stones at the ford of the forest path, the waterfall into
-- Bear Ravine (a curtain of falling water with spray and mist on the client) and stones along the brook. Pure.

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

-- The waterfall: from the lip of the upper brook down the ravine wall into the pool, a few slanted sheets of
-- falling water ("waterfall": spray streaks), foam on the pool ("foam": mist and splashes), rocks around.
function Water.waterfall(out: { Build })
	local line = MeadowsTerrain.streamLine(3)
	local lip = line.pts[#line.pts]
	local prev = line.pts[#line.pts - 1]
	local dx, dz = lip[1] - prev[1], lip[2] - prev[2]
	local len = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / len, dz / len
	local top = MeadowsTerrain.streamLevel(3, line.length)
	-- the pool is where the brook below starts; walk down the flow direction to the foot of the wall
	local pool = MeadowsTerrain.streamLevel(1, 0)
	local bx, bz = lip[1], lip[2]
	for k = 1, 40 do
		bx, bz = lip[1] + dx * k, lip[2] + dz * k
		if MeadowsTerrain.height(bx, bz) < pool + 1.5 then
			break
		end
	end
	local rot = math.deg(math.atan2(-dx, -dz))
	local b: Build = {
		name = "Waterfall",
		bp = Kit.build("Waterfall", "waterfall", lip[1], lip[2], rot).bp,
		at = { x = lip[1], y = pool, z = lip[2], rot = rot },
		tag = "waterfall",
	}
	local bp = b.bp
	local horiz = math.sqrt((bx - lip[1]) ^ 2 + (bz - lip[2]) ^ 2) + 2
	local drop = top - pool + 0.6
	local tilt = math.deg(math.atan2(horiz, drop))
	local sheetLen = math.sqrt(horiz * horiz + drop * drop)
	for k = -1, 1 do
		bp:rbox(
			3.2 - math.abs(k) * 0.6,
			sheetLen,
			0.5,
			k * 2.4,
			drop / 2,
			-horiz / 2,
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
		10,
		1.4,
		9,
		0,
		0.1,
		-horiz - 3,
		0,
		0,
		0,
		o({ c = "#E8F2F6", m = "SmoothPlastic" }, "detail", { col = false, t = 0.45, tag = "foam", jitter = 0 })
	)
	for k = -1, 1, 2 do
		Kit.rock(bp, k * 6, drop - 2, 1, 6, Kit.mossyStone, "shell")
		Kit.rock(bp, k * 7.5, 0, -horiz - 1, 5, Kit.mossyStone, "shell")
	end
	table.insert(out, b)
	local wx, wy, wz = Kit.worldOf(b, 0, 0.5, -horiz - 4)
	Kit.life("mist", wx, wy, wz, 14)
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
