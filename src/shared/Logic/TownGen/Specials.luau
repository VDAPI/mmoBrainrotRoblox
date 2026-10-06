--!strict
-- The city's landmark buildings (S21, MIASTO.md §6): market hall, town hall with a clock tower, temple, castle
-- keep with its curtain wall, forge, tournament stands, and the house-like ones (guild hall, armoury,
-- apothecary, tavern, stable, water mill, granary, guardhouse) built on Houses with their own trimmings. Pure.

local Blueprint = require("./Blueprint")
local Houses = require("./Houses")
local Palette = require("./Palette")
local Parts = require("./Parts")
local Structures = require("./Structures")

type BP = Blueprint.Blueprint
type Swatch = Palette.Swatch
type Build = Structures.Build
type Ground = Houses.Ground

local o = Parts.o

local Specials = {}

local function seedOf(id: string): number
	local h = 7
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 2147483647
	end
	return h
end

local function lookFor(bp: BP, stone: Swatch, roof: Swatch): Parts.Look
	return {
		timber = Palette.pick(bp.rng, Palette.timber),
		plaster = Palette.pick(bp.rng, Palette.plaster),
		planks = Palette.pick(bp.rng, Palette.planks),
		shutter = Palette.pick(bp.rng, Palette.shutter),
		door = Palette.pick(bp.rng, Palette.door),
		stone = stone,
		roof = roof,
	}
end

local function floorOf(sp: any, ground: Ground, pad: number?): (number, number)
	local lo, hi = Houses.groundRange(sp.x, sp.z, sp.w + (pad or 0), sp.d + (pad or 0), sp.rot, ground)
	return hi + 0.2, lo
end

local function banner(bp: BP, x: number, y: number, z: number, w: number, h: number, colour: string)
	bp:box(w + 0.6, 0.3, 0.3, x, y + h / 2 + 0.2, z, o(Palette.timber[1]))
	bp:box(w, h, 0.15, x, y, z, { c = colour, m = "Fabric", lod = "detail", tag = "flag" })
	bp:add(
		"wedge",
		0.15,
		1.4,
		w / 2,
		x - w / 4,
		y - h / 2 - 0.7,
		z,
		0,
		90,
		180,
		{ c = colour, m = "Fabric", lod = "detail" }
	)
	bp:add(
		"wedge",
		0.15,
		1.4,
		w / 2,
		x + w / 4,
		y - h / 2 - 0.7,
		z,
		0,
		-90,
		180,
		{ c = colour, m = "Fabric", lod = "detail" }
	)
end

-- Hanging sign on an iron bracket sticking out of the front wall at height y.
local function sign(bp: BP, x: number, y: number, zf: number, board: string, emblem: string?)
	bp:box(0.25, 0.25, 3, x, y + 1.2, zf - 1.5, o(Palette.metal[1]))
	bp:beam(x, y - 0.4, zf - 0.1, x, y + 1.2, zf - 1.9, 0.2, o(Palette.metal[1]))
	bp:box(0.25, 2.2, 2.4, x, y, zf - 2, { c = board, m = "WoodPlanks", lod = "detail" })
	if emblem then
		bp:box(0.35, 1.2, 1.4, x, y, zf - 2, { c = emblem, m = "SmoothPlastic", lod = "fine" })
	end
end

local function houseLike(
	sp: any,
	ground: Ground,
	style: string,
	kind: string,
	floors: number
): (BP, Houses.Placement, Houses.Info)
	return Houses.build({
		id = sp.id,
		kind = kind,
		style = style,
		x = sp.x,
		z = sp.z,
		w = sp.w,
		d = sp.d,
		rot = sp.rot,
		floors = floors,
		seed = seedOf(sp.id),
	}, ground)
end

-- Market hall (Sukiennice): long hall on arcades, an upper floor under a decorated parapet (attic).
local function marketHall(sp: any, ground: Ground): Build
	local bp = Blueprint.new(seedOf(sp.id))
	local y0, lo = floorOf(sp, ground)
	local W, D = sp.w, sp.d
	local stone = Palette.ashlar[1]
	local plaster: Swatch = { c = "#C9A27A", m = "Plaster" }
	local look = lookFor(bp, stone, Palette.tiles[1])
	bp:box(W + 1, y0 - lo + 1.5, D + 1, 0, -(y0 - lo + 1.5) / 2, 0, o(stone, "shell", { q = true }))
	local G, U = 10, 9
	local core = W - 9
	bp:box(core, G, D - 4, 0, G / 2, 0, o(plaster, "shell", { q = true }))
	-- arcades along both long sides: pillars every 6 studs, lintels with pointed spandrels
	local bays = math.floor(D / 6)
	local bay = D / bays
	for _, s in { -1, 1 } do
		local x = s * (W / 2 - 0.8)
		for i = 0, bays do
			local z = -D / 2 + i * bay
			bp:box(1.6, G, 1.6, x, G / 2, z, o(stone, "shell", { q = true }))
		end
		for i = 1, bays do
			local z = -D / 2 + (i - 0.5) * bay
			bp:box(1.6, 1.4, bay, x, G - 0.7, z, o(stone, "shell"))
			bp:add("wedge", 1.6, 1.8, 1.6, x, G - 2.3, z - bay / 2 + 1.6, 0, 180, 180, o(stone))
			bp:add("wedge", 1.6, 1.8, 1.6, x, G - 2.3, z + bay / 2 - 1.6, 0, 0, 180, o(stone))
		end
		-- arcade floor
		bp:box(4.5, 0.3, D, s * (W / 2 - 2.25), 0.15, 0, o(Palette.ashlar[3]))
		-- shop windows and doors of the stalls inside the hall
		for i = 1, bays do
			local z = -D / 2 + (i - 0.5) * bay
			if i % 2 == 0 then
				bp:push(s * core / 2, 0, z, 0, s * -90, 0)
				Parts.door(bp, look, 0, -0.05, 3, 6.5, stone)
				bp:pop()
			else
				bp:box(
					0.3,
					3,
					3,
					s * (core / 2 + 0.05),
					4,
					z,
					o(Palette.glass, "detail", { tag = "window", jitter = 0 })
				)
				local aw = Palette.pick(bp.rng, Palette.awning)
				bp:rbox(2.4, 0.2, 3.6, s * (core / 2 + 1.2), 6.2, z, 0, 0, s * -20, o(aw))
			end
		end
	end
	-- upper floor and windows on the long sides
	bp:box(W, U, D, 0, G + U / 2, 0, o(plaster, "shell", { q = true }))
	bp:box(W + 0.6, 0.6, D + 0.6, 0, G + 0.3, 0, o(stone))
	for _, s in { -1, 1 } do
		for i = 1, bays do
			local z = -D / 2 + (i - 0.5) * bay
			bp:push(s * W / 2, 0, z, 0, s * -90, 0)
			bp:box(2.4, 4.2, 0.3, 0, G + U / 2, -0.05, o(stone))
			Parts.window(bp, look, 0, G + U / 2, -0.2, 1.6, 3.4, false, true)
			bp:pop()
		end
	end
	-- attic: a parapet with blind arches and pinnacles hiding the roof base
	local top = G + U
	bp:box(W + 0.4, 3.2, 0.8, 0, top + 1.6, -D / 2 + 0.4, o(plaster, "shell"))
	bp:box(W + 0.4, 3.2, 0.8, 0, top + 1.6, D / 2 - 0.4, o(plaster, "shell"))
	bp:box(0.8, 3.2, D, -W / 2 + 0.4, top + 1.6, 0, o(plaster, "shell"))
	bp:box(0.8, 3.2, D, W / 2 - 0.4, top + 1.6, 0, o(plaster, "shell"))
	for _, s in { -1, 1 } do
		for i = 0, bays do
			local z = -D / 2 + i * bay
			bp:box(0.8, 1.6, 0.8, s * (W / 2 - 0.4), top + 4, z, o(stone))
			bp:add("ball", 1, 1, 1, s * (W / 2 - 0.4), top + 5.2, z, 0, 0, 0, o(stone))
		end
	end
	Parts.roof(bp, look, {
		w = W - 1.6,
		d = D - 1.6,
		zc = 0,
		y = top + 0.4,
		pitch = 38,
		ridgeAlongZ = true,
		eave = 0,
		verge = 0,
		thick = 0.6,
		roof = Palette.tiles[1],
		gable = plaster,
		timber = nil,
	})
	-- stepped gables over the short ends
	for _, e in { -1, 1 } do
		for i = 0, 3 do
			local ww = (W - 2) * (1 - i / 4)
			bp:box(ww, 2.4, 0.9, 0, top + 3.2 + i * 2.2, e * (D / 2 - 0.45), o(plaster, "shell"))
			bp:box(ww + 0.3, 0.3, 1.1, 0, top + 4.4 + i * 2.2, e * (D / 2 - 0.45), o(stone))
		end
	end
	-- the passage through the hall: big arched doors in both short ends
	for _, e in { 0, 180 } do
		bp:push(0, 0, 0, 0, e, 0)
		Parts.door(bp, look, 0, -(D - 4) / 2, 5, 8.5, stone)
		bp:pop()
	end
	for _, s in { -1, 1 } do
		bp:push(s * W / 2, 0, s * D / 4, 0, s * -90, 0)
		banner(bp, 0, G + U / 2, -0.3, 2.5, 5, if s < 0 then "#7A2A22" else "#2E4A6B")
		bp:pop()
	end
	return { name = sp.id, bp = bp, at = { x = sp.x, y = y0, z = sp.z, rot = sp.rot }, tag = "special" }
end

-- Town hall with the treasury: two stone storeys, an arcaded porch, and a clock tower on one corner.
local function townHall(sp: any, ground: Ground): Build
	local bp = Blueprint.new(seedOf(sp.id))
	local y0, lo = floorOf(sp, ground)
	local W, D = sp.w, sp.d
	local stone = Palette.ashlar[2]
	local look = lookFor(bp, stone, Palette.slateRoof[1])
	local G, U = 11, 10
	bp:box(W + 1, y0 - lo + 1.5, D + 1, 0, -(y0 - lo + 1.5) / 2, 0, o(stone, "shell", { q = true }))
	bp:box(W, G + U, D, 0, (G + U) / 2, 0, o(stone, "shell", { q = true }))
	bp:box(W + 0.6, 0.6, D + 0.6, 0, G, 0, o(Palette.ashlar[3]))
	-- tall windows on both storeys (front and back), barred on the ground floor (treasury)
	for _, face in { 0, 180 } do
		bp:push(0, 0, if face == 0 then -D / 2 else D / 2, 0, face, 0)
		local n = math.floor(W / 5)
		for i = 1, n do
			local x = -W / 2 + (i - 0.5) * W / n
			if face ~= 0 or (math.abs(x) > 6 and x > -W / 2 + 9.5) then
				bp:box(2.4, 5, 0.3, x, G + U / 2, -0.05, o(Palette.ashlar[3]))
				Parts.window(bp, look, x, G + U / 2, -0.2, 1.6, 4.2, false, true)
				Parts.window(bp, look, x, G / 2, -0.05, 1.4, 2.4, false, true)
				for k = -1, 1 do
					bp:box(0.15, 2.6, 0.12, x + k * 0.45, G / 2, -0.35, o(Palette.metal[1], "fine"))
				end
			end
		end
		bp:pop()
	end
	-- porch: three arches in front of the door, with steps
	local pz = -D / 2 - 3
	for _, x in { -7.5, -3, 3, 7.5 } do
		bp:box(1.6, G - 1, 1.6, x, (G - 1) / 2, pz - 2, o(Palette.ashlar[3], "shell", { q = true }))
	end
	bp:box(17, 1.6, 6, 0, G - 0.4, pz, o(stone, "shell"))
	bp:box(17, 0.6, 6, 0, -0.1, pz, o(Palette.ashlar[3], "shell", { q = true }))
	Parts.door(bp, look, 0, -D / 2, 4, 8.5, Palette.ashlar[3])
	-- coat of arms over the porch
	bp:add(
		"cyl",
		0.4,
		3.4,
		3.4,
		0,
		G + 2.6,
		-D / 2 - 0.25,
		0,
		90,
		0,
		{ c = "#8A2A22", m = "SmoothPlastic", lod = "detail" }
	)
	bp:add("cyl", 0.5, 1.6, 1.6, 0, G + 2.6, -D / 2 - 0.35, 0, 90, 0, { c = "#C8A040", m = "Metal", lod = "detail" })
	-- roof with dormers
	Parts.roof(bp, look, {
		w = W,
		d = D,
		zc = 0,
		y = G + U,
		pitch = 50,
		ridgeAlongZ = false,
		eave = 0.8,
		verge = 0.4,
		thick = 0.6,
		roof = Palette.slateRoof[1],
		gable = stone,
		timber = nil,
	})
	-- clock tower on the front-left corner
	local tx, tz = -W / 2 + 4.5, -D / 2 + 4.5
	local th = G + U + 22
	bp:box(9, th, 9, tx, th / 2, tz, o(stone, "shell", { q = true }))
	bp:box(10, 0.8, 10, tx, th - 7, tz, o(Palette.ashlar[3]))
	for _, f in { 0, 90, 180, 270 } do
		bp:push(tx, 0, tz, 0, f, 0)
		bp:add("cyl", 0.4, 5, 5, 0, th - 4, -4.6, 0, 90, 0, { c = "#E8DCC0", m = "SmoothPlastic", lod = "detail" })
		bp:add("cyl", 0.5, 5.6, 5.6, 0, th - 4, -4.5, 0, 90, 0, o(Palette.ashlar[3]))
		bp:box(0.25, 1.8, 0.2, 0, th - 3.3, -4.9, { c = "#1E1C1A", m = "SmoothPlastic", lod = "fine" })
		bp:rbox(0.25, 1.3, 0.2, 0.45, th - 4.3, -4.9, 0, 0, 60, { c = "#1E1C1A", m = "SmoothPlastic", lod = "fine" })
		-- belfry openings
		bp:box(1.6, 3.4, 0.3, 0, th - 10, -4.6, o(Palette.glass, "detail", { jitter = 0 }))
		bp:pop()
	end
	-- spire: two crossing steep gable roofs and a gilded ball
	bp:push(tx, 0, tz)
	for _, along in { true, false } do
		Parts.roof(bp, look, {
			w = 9.6,
			d = 9.6,
			zc = 0,
			y = th,
			pitch = 72,
			ridgeAlongZ = along,
			eave = 0.5,
			verge = 0.5,
			thick = 0.5,
			roof = Palette.slateRoof[2],
			gable = Palette.slateRoof[2],
			timber = nil,
		})
	end
	bp:pop()
	bp:add(
		"ball",
		1.4,
		1.4,
		1.4,
		tx,
		th + 4.8 * math.tan(math.rad(72)) + 1.2,
		tz,
		0,
		0,
		0,
		{ c = "#C8A040", m = "Metal", lod = "detail" }
	)
	bp:box(0.3, 5, 0.3, tx, th + 4.8 * math.tan(math.rad(72)) + 3.5, tz, o(Palette.metal[1]))
	banner(bp, W / 4, G + U / 2, -D / 2 - 0.3, 2.6, 6, "#7A2A22")
	return { name = sp.id, bp = bp, at = { x = sp.x, y = y0, z = sp.z, rot = sp.rot }, tag = "special" }
end

-- Temple of Light: gothic nave and aisles with buttresses, lancet windows of coloured glass, a front tower with
-- a spire, a rose window over the portal and a round apse.
local function temple(sp: any, ground: Ground): Build
	local bp = Blueprint.new(seedOf(sp.id))
	local y0, lo = floorOf(sp, ground)
	local W, D = sp.w, sp.d
	local stone = Palette.ashlar[1]
	local look = lookFor(bp, stone, Palette.slateRoof[1])
	local nave, aisle = 18, (W - 18) / 2
	local NH, AH = 24, 12
	local towerD = 12
	local zs, ze = -D / 2 + towerD, D / 2 - 9 -- nave between the tower and the apse
	local len = ze - zs
	local zc = (zs + ze) / 2
	bp:box(W + 2, y0 - lo + 1.5, D + 2, 0, -(y0 - lo + 1.5) / 2, 0, o(stone, "shell", { q = true }))
	bp:box(nave, NH, len, 0, NH / 2, zc, o(stone, "shell", { q = true }))
	for _, s in { -1, 1 } do
		local ax = s * (nave / 2 + aisle / 2)
		bp:box(aisle, AH, len, ax, AH / 2, zc, o(stone, "shell", { q = true }))
		-- aisle lean-to roof
		local run = aisle + 1
		local rise = 4
		local ang = math.deg(math.atan2(rise, run))
		bp:rbox(
			math.sqrt(run * run + rise * rise),
			0.6,
			len + 1,
			ax + s * 0.5,
			AH + rise / 2 + 0.3,
			zc,
			0,
			0,
			-s * ang,
			o(Palette.slateRoof[1], "shell")
		)
		-- buttresses and lancet windows
		local bays = math.floor(len / 7)
		for i = 0, bays do
			local z = zs + i * len / bays
			bp:add("wedge", 1.6, AH + 2, 3, s * (W / 2 + 1.5), (AH + 2) / 2, z, 0, -s * 90, 0, o(Palette.ashlar[2]))
		end
		for i = 1, bays do
			local z = zs + (i - 0.5) * len / bays
			local glass = ({ "#3A5FA0", "#A0403A", "#C8A040", "#4A8A5A" })[bp.rng:int(1, 4)]
			bp:box(
				0.3,
				7,
				1.8,
				s * (W / 2 + 0.05),
				AH / 2,
				z,
				{ c = glass, m = "Glass", lod = "detail", tag = "window" }
			)
			bp:box(0.4, 1, 1.8, s * (W / 2 + 0.1), AH / 2 + 3.9, z, o(Palette.ashlar[3]))
			bp:box(
				0.3,
				5,
				1.6,
				s * (nave / 2 + 0.05),
				AH + 7.6,
				z,
				{ c = glass, m = "Glass", lod = "detail", tag = "window" }
			)
		end
	end
	Parts.roof(bp, look, {
		w = nave,
		d = len,
		zc = zc,
		y = NH,
		pitch = 55,
		ridgeAlongZ = true,
		eave = 0.8,
		verge = 0.6,
		thick = 0.7,
		roof = Palette.slateRoof[1],
		gable = stone,
		timber = nil,
	})
	-- apse: a cylinder half hidden in the nave end, with its own low cap
	bp:add("cyl", NH - 4, nave, nave, 0, (NH - 4) / 2, ze, 0, 0, 90, o(stone, "shell", { q = true }))
	bp:add("ball", nave + 1, 9, nave + 1, 0, NH - 4, ze, 0, 0, 0, o(Palette.slateRoof[1], "shell"))
	-- front tower with the portal and the rose window
	local tz = -D / 2 + towerD / 2
	local TH = 44
	bp:box(towerD + 1, TH, towerD + 1, 0, TH / 2, tz + 0.5, o(stone, "shell", { q = true }))
	bp:box(towerD + 3, 0.8, towerD + 1, 0, NH, tz, o(Palette.ashlar[3]))
	bp:box(towerD + 3, 0.8, towerD + 1, 0, TH - 8, tz, o(Palette.ashlar[3]))
	-- portal: a projecting frame with a pointed gable (wimperg) over the door
	bp:box(9, 13, 1.2, 0, 6.5, -D / 2 - 0.6, o(Palette.ashlar[2], "shell", { q = true }))
	Parts.door(bp, look, 0, -D / 2 - 1.2, 5, 10, Palette.ashlar[3])
	bp:add("wedge", 1.2, 4, 4.5, -2.25, 15, -D / 2 - 0.6, 0, 90, 0, o(Palette.ashlar[2]))
	bp:add("wedge", 1.2, 4, 4.5, 2.25, 15, -D / 2 - 0.6, 0, -90, 0, o(Palette.ashlar[2]))
	bp:add(
		"cyl",
		0.3,
		6.5,
		6.5,
		0,
		19.5,
		-D / 2 - 0.1,
		0,
		90,
		0,
		{ c = "#4A6AB0", m = "Glass", lod = "detail", tag = "window" }
	)
	bp:add("cyl", 0.4, 7.4, 7.4, 0, 19.5, -D / 2 + 0.05, 0, 90, 0, o(Palette.ashlar[3]))
	for i = 0, 3 do
		bp:rbox(0.25, 6.4, 0.2, 0, 19.5, -D / 2 - 0.3, 0, 0, i * 45, o(Palette.ashlar[3], "fine"))
	end
	-- belfry openings and spire
	for _, f in { 0, 90, 180, 270 } do
		bp:push(0, 0, tz + 0.5, 0, f, 0)
		bp:box(2.2, 5, 0.3, -2, TH - 4, -(towerD + 1) / 2 - 0.05, o(Palette.glass, "detail", { jitter = 0 }))
		bp:box(2.2, 5, 0.3, 2, TH - 4, -(towerD + 1) / 2 - 0.05, o(Palette.glass, "detail", { jitter = 0 }))
		bp:pop()
	end
	for _, along in { true, false } do
		Parts.roof(bp, look, {
			w = towerD + 1,
			d = towerD + 1,
			zc = tz + 0.5,
			y = TH,
			pitch = 76,
			ridgeAlongZ = along,
			eave = 0.4,
			verge = 0.4,
			thick = 0.5,
			roof = Palette.slateRoof[2],
			gable = Palette.slateRoof[2],
			timber = nil,
		})
	end
	local spireTop = TH + (towerD + 1) / 2 * math.tan(math.rad(76))
	bp:box(0.4, 4, 0.4, 0, spireTop + 2, tz + 0.5, o(Palette.metal[1]))
	bp:add(
		"ball",
		1.6,
		1.6,
		1.6,
		0,
		spireTop + 4.4,
		tz + 0.5,
		0,
		0,
		0,
		{ c = "#F0D070", m = "Neon", lod = "detail", tag = "lamp" }
	)
	bp:light(0, spireTop + 4.4, tz + 0.5, "#FFE08A", 30, 1.2, "lamp")
	-- warm light from the portal at night and two braziers on the steps
	for _, s in { -1, 1 } do
		bp:add("cyl", 2.4, 1.2, 1.2, s * 5, 1.2, -D / 2 - 2.5, 0, 0, 90, o(Palette.metal[1], "shell"))
		bp:box(1, 0.8, 1, s * 5, 2.8, -D / 2 - 2.5, { c = "#FF9A3A", m = "Neon", lod = "detail", tag = "fire" })
		bp:light(s * 5, 3.4, -D / 2 - 2.5, "#FF9A50", 16, 1, "lamp")
	end
	return { name = sp.id, bp = bp, at = { x = sp.x, y = y0, z = sp.z, rot = sp.rot }, tag = "special" }
end

-- Keep on the castle hill; the curtain wall around the plateau is built by castleWall.
local function keep(sp: any, ground: Ground): Build
	local bp = Blueprint.new(seedOf(sp.id))
	local y0, lo = floorOf(sp, ground)
	local W = sp.w
	local stone: Swatch = { c = "#6E6962", m = "Cobblestone" }
	local H = 32
	bp:box(W + 1, y0 - lo + 1.5, W + 1, 0, -(y0 - lo + 1.5) / 2, 0, o(stone, "shell", { q = true }))
	bp:box(W, H, W, 0, H / 2, 0, o(stone, "shell", { q = true }))
	bp:box(W + 1, 0.7, W + 1, 0, H, 0, o(Palette.slate[1]))
	for _, f in { 0, 90, 180, 270 } do
		bp:push(0, 0, 0, 0, f, 0)
		local n = math.floor(W / 3.4)
		for i = 0, n - 1 do
			bp:box(1.9, 2.8, 1.2, -W / 2 + (i + 0.5) * W / n, H + 1.75, -W / 2 + 0.6, o(stone))
		end
		for _, y in { 10, 18, 25 } do
			bp:box(
				0.7,
				2.8,
				0.3,
				bp.rng:float(-W / 3, W / 3),
				y,
				-W / 2 - 0.05,
				o(Palette.glass, "detail", { tag = "window", jitter = 0 })
			)
		end
		bp:box(W + 0.6, 0.6, 0.6, 0, 13, -W / 2 - 0.2, o(Palette.slate[1]))
		bp:pop()
	end
	-- corner turrets
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local x, z = c[1] * W / 2, c[2] * W / 2
		bp:add("cyl", H + 8, 6, 6, x, (H + 8) / 2, z, 0, 0, 90, o(stone, "shell", { q = true }))
		for i = 0, 5 do
			local ra = math.rad(i * 60)
			bp:rbox(1.4, 2, 0.9, x + math.sin(ra) * 2.7, H + 9, z + math.cos(ra) * 2.7, 0, i * 60, 0, o(stone))
		end
	end
	-- upper hall on the roof with a steep roof, and the banner
	local look = lookFor(bp, stone, Palette.slateRoof[1])
	bp:box(W - 10, 6, W - 10, 0, H + 3, 0, o(stone, "shell", { q = true }))
	Parts.roof(bp, look, {
		w = W - 10,
		d = W - 10,
		zc = 0,
		y = H + 6,
		pitch = 55,
		ridgeAlongZ = true,
		eave = 0.6,
		verge = 0.5,
		thick = 0.6,
		roof = Palette.slateRoof[1],
		gable = stone,
		timber = nil,
	})
	bp:add("cyl", 12, 0.4, 0.4, 0, H + 18, 0, 0, 0, 90, o(Palette.timber[1]))
	bp:box(6, 3.6, 0.15, 3.1, H + 22, 0, { c = "#6B2A24", m = "Fabric", lod = "detail", tag = "flag" })
	-- door with stairs, iron-bound
	Parts.door(bp, look, 0, -W / 2, 4, 7.5, Palette.ashlar[2])
	return { name = sp.id, bp = bp, at = { x = sp.x, y = y0, z = sp.z, rot = sp.rot }, tag = "special" }
end

-- Open forge: stone smithy with a roofed working bay in front, hearth, anvil, quench tub and a big chimney.
local function forge(sp: any, ground: Ground): Build
	local bp = Blueprint.new(seedOf(sp.id))
	local y0, lo = floorOf(sp, ground)
	local W, D = sp.w, sp.d
	local stone = Palette.rubble[1]
	local look = lookFor(bp, stone, Palette.shingles[2])
	local back = D * 0.55 -- closed stone part at the back
	local zb, zf = D / 2, D / 2 - back
	bp:box(W + 0.6, y0 - lo + 1.5, D + 0.6, 0, -(y0 - lo + 1.5) / 2, 0, o(stone, "shell", { q = true }))
	bp:box(W, 9, back, 0, 4.5, (zb + zf) / 2, o(stone, "shell", { q = true }))
	Parts.roof(bp, look, {
		w = W,
		d = back,
		zc = (zb + zf) / 2,
		y = 9,
		pitch = 42,
		ridgeAlongZ = false,
		eave = 1,
		verge = 0.6,
		thick = 0.6,
		roof = look.roof,
		gable = stone,
		timber = nil,
	})
	-- working bay: posts and a lean-to roof
	local bayD = D - back
	for _, x in { -W / 2 + 0.5, -W / 6, W / 6, W / 2 - 0.5 } do
		bp:box(0.8, 7.5, 0.8, x, 3.75, -D / 2 + 0.6, o(look.timber, "shell", { q = true }))
	end
	bp:box(W, 0.6, 0.8, 0, 7.6, -D / 2 + 0.6, o(look.timber))
	local ang = math.deg(math.atan2(2, bayD))
	bp:rbox(W + 1, 0.5, math.sqrt(bayD * bayD + 4) + 1, 0, 8.6, (zf - D / 2) / 2, -ang, 0, 0, o(look.roof, "shell"))
	-- hearth with fire, chimney with smoke
	local hx, hz = -W / 4, zf - 2
	bp:box(6, 3, 4, hx, 1.5, hz, o(Palette.brick[1], "shell", { q = true }))
	bp:box(4.4, 0.4, 2.6, hx, 3.1, hz, { c = "#FF7A2A", m = "Neon", lod = "detail", tag = "fire" })
	bp:light(hx, 4, hz, "#FF8A3A", 20, 1.6, "fire")
	bp:box(4, 4, 3, hx, 6, hz + 0.5, o(Palette.brick[1]))
	Parts.chimney(bp, hx, zf + 1, 8, 17, true)
	-- anvil, quench tub, grindstone, racks
	local ax, az = W / 8, -D / 2 + bayD / 2
	bp:add("cyl", 1.6, 1.8, 1.8, ax, 0.8, az, 0, 0, 90, o(Palette.timber[1]))
	bp:box(2.6, 0.9, 1.1, ax, 2, az, o(Palette.metal[2]))
	bp:add("wedge", 1.1, 0.8, 1, ax + 1.8, 2.05, az, 0, -90, 0, o(Palette.metal[2]))
	bp:add("cyl", 1.6, 2.6, 2.6, W / 3, 0.8, zf - 2, 0, 0, 90, o(Palette.planks[1]))
	bp:add("cyl", 0.2, 2.2, 2.2, W / 3, 1.62, zf - 2, 0, 0, 90, { c = "#3A4A55", m = "Glass", lod = "detail" })
	bp:add("cyl", 0.6, 3, 3, W / 2 - 3, 2, -D / 2 + 3, 0, 0, 0, o(Palette.slate[2]))
	for i = 0, 3 do
		bp:box(0.2, 3.4, 0.2, -W / 2 + 2 + i * 1.2, 4.5, zf - 0.4, o(Palette.metal[1], "fine"))
	end
	for _ = 1, 3 do
		Parts.barrel(bp, bp.rng:float(W / 4, W / 2 - 2), 0, bp.rng:float(zf + 1, zb - 2))
	end
	-- coal heap
	bp:add("ball", 4, 1.6, 3, -W / 2 + 3, 0.4, -D / 2 + 3, 0, 0, 0, { c = "#1E1C1A", m = "Slate", lod = "detail" })
	sign(bp, W / 2 - 1, 6.5, -D / 2 + 0.6, "#4A3424", "#8A8A8A")
	return { name = sp.id, bp = bp, at = { x = sp.x, y = y0, z = sp.z, rot = sp.rot }, tag = "special" }
end

-- Tournament ground (Ristalle): wooden stands with four tiers on four sides, entrances in the middle of the
-- north and south sides, a fenced sand ring, the lord's box with a canopy and banners on poles.
local function arena(sp: any, city: any, ground: Ground): Build
	local a = city.arena
	local bp = Blueprint.new(seedOf(sp.id))
	local y0 = ground(a.x, a.z) + 0.1
	local h, st = a.half, a.stands
	local plank = Palette.planks[2]
	for _, f in { 0, 90, 180, 270 } do
		bp:push(0, 0, 0, 0, f, 0)
		local gate = f == 0 or f == 180
		for tier = 0, 3 do
			local depth = st / 4
			local z = -h - depth * (tier + 0.5)
			local y = 1.2 + tier * 1.6
			local parts: { { number } } = if gate then { { -h - st, -6 }, { 6, h + st } } else { { -h, h } }
			for _, span in parts do
				local x0, x1 = span[1], span[2]
				bp:box(x1 - x0, y, depth, (x0 + x1) / 2, y / 2, z, o(plank, "shell", { q = true }))
			end
		end
		-- fence around the sand
		local parts: { { number } } = if gate then { { -h, -6 }, { 6, h } } else { { -h, h } }
		for _, span in parts do
			Parts.fence(bp, span[1], 0, -h + 0.5, span[2], 0, -h + 0.5, "rail")
		end
		-- banners on poles at the back of the stands
		for _, x in { -h * 0.6, h * 0.6 } do
			bp:add("cyl", 14, 0.4, 0.4, x, 7, -h - st - 0.5, 0, 0, 90, o(Palette.timber[1]))
			bp:box(
				2.4,
				5,
				0.15,
				x,
				11,
				-h - st - 0.5,
				{ c = if f % 180 == 0 then "#7A2A22" else "#2E4A6B", m = "Fabric", lod = "detail", tag = "flag" }
			)
		end
		bp:pop()
	end
	-- lord's box on the west stand
	bp:push(0, 0, 0, 0, 90, 0)
	for _, x in { -6, 6 } do
		bp:box(0.6, 8, 0.6, x, 10, -h - 2, o(Palette.timber[1]))
		bp:box(0.6, 8, 0.6, x, 10, -h - 9, o(Palette.timber[1]))
	end
	bp:rbox(14, 0.3, 9, 0, 14.4, -h - 5.5, -8, 0, 0, { c = "#6B2A24", m = "Fabric", lod = "detail" })
	bp:box(13, 1.2, 0.4, 0, 7.4, -h - 1.6, { c = "#C8A040", m = "Fabric", lod = "detail" })
	bp:pop()
	-- torches at the two entrances
	for _, s in { -1, 1 } do
		for _, x in { -7, 7 } do
			bp:add("cyl", 5, 0.5, 0.5, x, 2.5, s * (h + st + 1), 0, 0, 90, o(Palette.timber[1]))
			bp:box(0.8, 0.8, 0.8, x, 5.3, s * (h + st + 1), { c = "#FF9A3A", m = "Neon", lod = "detail", tag = "fire" })
			bp:light(x, 5.8, s * (h + st + 1), "#FF9A50", 16, 1, "lamp")
		end
	end
	return { name = sp.id, bp = bp, at = { x = a.x, y = y0, z = a.z, rot = 0 }, tag = "special" }
end

-- Curtain wall around the castle plateau with round towers and a gatehouse where Ulica Zamkowa enters.
local function castleWall(city: any, out: { Build })
	local plateau
	for _, p in city.terrain.plateaus do
		if p.id == "castle" then
			plateau = p
		end
	end
	if not plateau then
		return
	end
	local cx, cz, n = 0, 0, #plateau.poly
	for _, v in plateau.poly do
		cx += v[1] / n
		cz += v[2] / n
	end
	local R = math.sqrt((plateau.poly[1][1] - cx) ^ 2 + (plateau.poly[1][2] - cz) ^ 2) - 4
	local road
	for _, r in city.terrain.ramps do
		if r.id == "zamkowa" then
			road = r
		end
	end
	local gateAngle = 0
	if road then
		local last = road.pts[#road.pts - 1]
		gateAngle = math.atan2(last[2] - cz, last[1] - cx)
	end
	local stone: Swatch = { c = "#6E6962", m = "Cobblestone" }
	local segs = 14
	for i = 0, segs - 1 do
		local a0 = gateAngle + (i + 0.5) / segs * math.pi * 2
		local a1 = gateAngle + (i + 1.5) / segs * math.pi * 2
		local isGate = i == segs - 1
		local ax, az = cx + math.cos(a0) * R, cz + math.sin(a0) * R
		local bx, bz = cx + math.cos(a1) * R, cz + math.sin(a1) * R
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local mx, mz = (ax + bx) / 2, (az + bz) / 2
		local bp = Blueprint.new(i + 900)
		local y = plateau.y
		local top = y + 11
		-- local -Z faces out (away from the centre)
		local rot = math.deg(math.atan2(-(bz - az), bx - ax))
		local fx, fz = -math.sin(math.rad(rot)), -math.cos(math.rad(rot))
		if (mx + fx - cx) ^ 2 + (mz + fz - cz) ^ 2 < (mx - cx) ^ 2 + (mz - cz) ^ 2 then
			rot += 180
		end
		if isGate then
			-- gatehouse over the road: two square towers and an arch
			for _, s in { -1, 1 } do
				bp:box(6, top + 6 - y + 2, 7, s * 7, (top + 6 + y - 2) / 2, 0, o(stone, "shell", { q = true }))
				for k = 0, 1 do
					bp:box(1.8, 2.4, 1.2, s * 7 + (k - 0.5) * 3, top + 7.2, -2.9, o(stone))
				end
			end
			bp:box(8, top - (y + 9), 7, 0, (top + y + 9) / 2, 0, o(stone, "shell", { q = true }))
			for k = 0, 2 do
				bp:box(1.8, 2.4, 1.2, -2.6 + k * 2.6, top + 1.2, -2.9, o(stone))
			end
			for _, s in { -1, 1 } do
				bp:add("wedge", 7, 2.4, 2.2, s * 2.9, y + 7.8, 0, 0, s * 90, 180, o(stone))
			end
			for k = 0, 4 do
				bp:box(0.3, 3, 0.3, -3 + k * 1.5, y + 9.5, -3, o(Palette.metal[1]))
			end
			bp:box(3, 4.5, 0.15, 0, top - 2, 3.6, { c = "#6B2A24", m = "Fabric", lod = "detail", tag = "flag" })
		else
			bp:box(len + 0.8, top - y + 3, 4, 0, (top + y - 3) / 2, 0, o(stone, "shell", { q = true }))
			bp:box(len + 1, 0.5, 4.6, 0, top + 0.25, 0, o(Palette.slate[1]))
			for k = 0, math.floor(len / 3.4) - 1 do
				bp:box(1.8, 2.4, 1, -len / 2 + (k + 0.5) * len / math.floor(len / 3.4), top + 1.7, -1.5, o(stone))
			end
		end
		table.insert(out, { name = "CastleWall", bp = bp, at = { x = mx, y = 0, z = mz, rot = rot }, tag = "wall" })
		-- tower on every other joint (not next to the gate)
		if i % 2 == 0 and i ~= 0 then
			local tbp = Blueprint.new(i + 950)
			tbp:add(
				"cyl",
				top + 6 - y + 3,
				8,
				8,
				0,
				(top + 6 + y - 3) / 2,
				0,
				0,
				0,
				90,
				o(stone, "shell", { q = true })
			)
			for k = 0, 7 do
				local ra = math.rad(k * 45)
				tbp:rbox(1.6, 2.4, 0.9, math.sin(ra) * 3.7, top + 7.2, math.cos(ra) * 3.7, 0, k * 45, 0, o(stone))
			end
			table.insert(
				out,
				{ name = "CastleTower", bp = tbp, at = { x = ax, y = 0, z = az, rot = 0 }, tag = "tower" }
			)
		end
	end
end

-- Builds every special building of the plan.
-- Style, house kind and floors of the house-like specials (everything without its own builder).
local HOUSE_LIKE: { [string]: { any } } = {
	default = { "burgher", "townhouse", 2 },
	guildHall = { "patrician", "townhouse", 3 },
	workshop = { "craft", "workshopHouse", 2 },
	apothecary = { "burgher", "townhouse", 2 },
	tavern = { "burgher", "townhouse", 3 },
	stable = { "craft", "workshopHouse", 1 },
	watermill = { "craft", "workshopHouse", 2 },
	granary = { "patrician", "townhouse", 3 },
	guardhouse = { "patrician", "townhouse", 2 },
}

function Specials.all(city: any, ground: Ground): { Build }
	local out: { Build } = {}
	for _, sp in city.specials do
		local kind = sp.kind
		if kind == "marketHall" then
			table.insert(out, marketHall(sp, ground))
		elseif kind == "townHall" then
			table.insert(out, townHall(sp, ground))
		elseif kind == "temple" then
			table.insert(out, temple(sp, ground))
		elseif kind == "keep" then
			table.insert(out, keep(sp, ground))
		elseif kind == "forge" then
			table.insert(out, forge(sp, ground))
		elseif kind == "arena" then
			table.insert(out, arena(sp, city, ground))
		else
			-- house-like specials: a big house plus trimmings in its local frame
			local look = HOUSE_LIKE[kind] or HOUSE_LIKE.default
			local style, hk, floors = look[1], look[2], look[3]
			local bp, at, info = houseLike(sp, ground, style, hk, floors)
			local zf = info.zFront
			local G = info.ground
			-- the first upper storey juts out by up to 1 stud: things hung on it go in front of that
			local zu = zf - 1.1
			if kind == "guildHall" then
				banner(bp, -sp.w / 4, G + 4.5, zf - 1.6, 2.6, 7, "#2E4A6B")
				banner(bp, sp.w / 4, G + 4.5, zf - 1.6, 2.6, 7, "#2E4A6B")
				bp:add("cyl", 0.5, 4, 4, 0, G + 3.5, zu, 0, 90, 0, { c = "#C8A040", m = "Metal", lod = "detail" })
				bp:add("cyl", 10, 0.4, 0.4, 0, info.ridge + 4, (zf + info.zBack) / 2, 0, 0, 90, o(Palette.timber[1]))
				bp:box(
					5,
					3,
					0.15,
					2.6,
					info.ridge + 7.4,
					(zf + info.zBack) / 2,
					{ c = "#2E4A6B", m = "Fabric", lod = "detail", tag = "flag" }
				)
			elseif kind == "workshop" then
				sign(bp, sp.w / 2 - 2, 6, zf, "#4A3424", "#A0A0A8")
				for i = 0, 3 do
					bp:rbox(0.25, 4.5, 0.25, -sp.w / 4 + i * 0.9, 2.3, zf - 0.8, 12, 0, 0, o(Palette.metal[1]))
				end
				bp:box(4.6, 0.4, 0.8, -sp.w / 4 + 1.35, 1.2, zf - 1.3, o(Palette.timber[1]))
				bp:add(
					"cyl",
					0.3,
					2.6,
					2.6,
					sp.w / 4,
					4.5,
					zf - 0.25,
					0,
					90,
					0,
					{ c = "#7A2A22", m = "Metal", lod = "detail" }
				)
			elseif kind == "apothecary" then
				sign(bp, sp.w / 2 - 2, 6.5, zf, "#2E4A3A", "#5AA060")
				bp:box(6, 0.3, 1.2, 0, 1.6, zf - 1, o(Palette.planks[1]))
				for i = 0, 4 do
					local c = ({ "#5AA060", "#A04A8A", "#4A7AC0", "#C8A040", "#C0503A" })[i + 1]
					bp:add(
						"cyl",
						1,
						0.6,
						0.6,
						-2 + i,
						2.25,
						zf - 1,
						0,
						0,
						90,
						{ c = c, m = "Neon", lod = "fine", t = 0.2 }
					)
				end
				-- bunches of herbs drying under the jetty
				for i = 0, 5 do
					bp:box(0.5, 1.4, 0.5, -3 + i * 1.2, G - 1.2, zf - 0.5, { c = "#6A7A3A", m = "Grass", lod = "fine" })
				end
				bp:light(0, 3, zf - 1.5, "#7AE08A", 10, 0.5, "lamp")
			elseif kind == "tavern" then
				sign(bp, -sp.w / 2 + 2.5, 7, zf, "#3E2A1E", "#9A2A22")
				-- beer garden: two tables with benches in front of the door
				for _, x in { -sp.w / 4, sp.w / 4 } do
					bp:box(6, 0.3, 2.2, x, 2.6, zf - 5, o(Palette.planks[3]))
					bp:box(0.4, 2.4, 0.4, x - 2.4, 1.3, zf - 5, o(Palette.timber[1]))
					bp:box(0.4, 2.4, 0.4, x + 2.4, 1.3, zf - 5, o(Palette.timber[1]))
					bp:box(6, 0.3, 0.9, x, 1.5, zf - 3.4, o(Palette.planks[3]))
					bp:box(6, 0.3, 0.9, x, 1.5, zf - 6.6, o(Palette.planks[3]))
				end
				Parts.barrel(bp, sp.w / 2 - 1.6, 0, zf - 1.5)
				Parts.barrel(bp, sp.w / 2 - 3.8, 0, zf - 1.5)
				Parts.crate(bp, -sp.w / 2 + 1.5, 0, zf - 1.5, 1.6)
				-- lanterns hanging from the jetty
				for _, x in { -sp.w / 3, 0, sp.w / 3 } do
					bp:box(0.2, 1, 0.2, x, G - 0.6, zf - 0.6, o(Palette.metal[1]))
					bp:box(
						0.8,
						1,
						0.8,
						x,
						G - 1.6,
						zf - 0.6,
						{ c = "#FFD08A", m = "Neon", lod = "detail", t = 0.2, tag = "lamp" }
					)
					bp:light(x, G - 1.6, zf - 0.6, "#FFB860", 14, 0.7, "lamp")
				end
			elseif kind == "stable" then
				-- open stalls along the front: half doors, round hay bales, a trough
				local n = math.floor(sp.w / 6)
				for i = 0, n - 1 do
					local x = -sp.w / 2 + (i + 0.5) * sp.w / n
					bp:box(3.4, 2.6, 0.3, x, 1.3, zf - 0.2, o(Palette.planks[2]))
					if i % 2 == 0 then
						bp:add(
							"cyl",
							2.6,
							2.2,
							2.2,
							x + 1.5,
							1.1,
							zf - 2.2,
							0,
							90,
							0,
							{ c = "#C8A85A", m = "Grass", lod = "detail" }
						)
					end
				end
				bp:box(6, 1.2, 1.4, sp.w / 2 - 5, 0.6, zf - 4, o(Palette.planks[1]))
				bp:box(5.4, 0.2, 0.9, sp.w / 2 - 5, 1.15, zf - 4, { c = "#3A5A6A", m = "Glass", lod = "detail" })
			elseif kind == "watermill" then
				-- undershot water wheel behind the back wall, reaching into the river. Tag "wheel": the client spins
				-- every piece with this tag around the X axis of the "wheelAxle" piece of the same model.
				local wx, wy, wz = sp.w / 4, 2.5, info.zBack + 7
				bp:add(
					"cyl",
					4.6,
					1.2,
					1.2,
					wx,
					wy,
					wz,
					0,
					0,
					0,
					{ c = "#3A2C22", m = "Wood", lod = "detail", tag = "wheelAxle" }
				)
				for _, s in { -1, 1 } do
					bp:add(
						"cyl",
						0.3,
						13,
						13,
						wx + s * 0.9,
						wy,
						wz,
						0,
						0,
						0,
						{ c = "#5A4632", m = "WoodPlanks", lod = "detail", tag = "wheel" }
					)
					bp:box(0.8, wy + 4, 0.8, wx + s * 2.2, (wy - 4) / 2, wz, o(Palette.timber[1]))
				end
				for i = 0, 11 do
					local a = i * 30
					local ra = math.rad(a)
					bp:rbox(
						1.6,
						2.6,
						0.4,
						wx,
						wy + math.cos(ra) * 6.2,
						wz + math.sin(ra) * 6.2,
						a,
						0,
						0,
						{ c = "#4E3B2A", m = "WoodPlanks", lod = "detail", tag = "wheel" }
					)
				end
				-- millrace: a wooden trough from the wall over the top of the wheel
				bp:box(2.2, 0.8, 6, wx, wy + 7.4, info.zBack + 3, o(Palette.planks[1]))
			elseif kind == "granary" then
				-- hoist beam under the eaves with a rope and a sack
				bp:box(0.8, 0.8, 3.2, 0, info.top - 1, zf - 2.6, o(Palette.timber[1]))
				bp:box(0.1, 5, 0.1, 0, info.top - 4, zf - 3.8, { c = "#9A8A6A", m = "Fabric", lod = "fine" })
				bp:add(
					"ball",
					1.6,
					2,
					1.6,
					0,
					info.top - 7.2,
					zf - 3.8,
					0,
					0,
					0,
					{ c = "#B8A070", m = "Fabric", lod = "detail" }
				)
				for i = 0, 4 do
					bp:add(
						"ball",
						1.6,
						1.4,
						1.2,
						-sp.w / 4 + i * 1.3,
						0.6,
						zf - 1.5,
						0,
						0,
						0,
						{ c = "#B8A070", m = "Fabric", lod = "detail" }
					)
				end
			elseif kind == "guardhouse" then
				banner(bp, 0, G + 4, zf - 1, 3, 6, "#7A2A22")
				for i = 0, 2 do
					bp:rbox(0.25, 5, 0.25, sp.w / 4 + i * 0.9, 2.6, zf - 1.2, 10, 0, 0, o(Palette.metal[1]))
				end
				bp:add("cyl", 1.4, 2, 2, -sp.w / 4, 0.7, zf - 2.5, 0, 0, 90, o(Palette.metal[1]))
				bp:box(
					1.4,
					0.6,
					1.4,
					-sp.w / 4,
					1.6,
					zf - 2.5,
					{ c = "#FF8A2A", m = "Neon", lod = "detail", tag = "fire" }
				)
				bp:light(-sp.w / 4, 2.4, zf - 2.5, "#FF9A50", 14, 1, "fire")
			end
			table.insert(out, { name = sp.id, bp = bp, at = at, tag = "special" })
		end
	end
	castleWall(city, out)
	return out
end

return Specials
