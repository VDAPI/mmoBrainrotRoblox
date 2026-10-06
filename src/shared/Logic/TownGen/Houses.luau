--!strict
-- Ordinary houses of the city (S21): timber-framed townhouses with jetties, craftsmen's houses with a lean-to,
-- thatched cottages, and stone patrician houses. One lot from Data/Town -> one Blueprint. Pure, deterministic
-- (same lot + same ground = same pieces), so the server (shell) and every client (detail) agree.

local Blueprint = require("./Blueprint")
local Palette = require("./Palette")
local Parts = require("./Parts")

type BP = Blueprint.Blueprint
type Look = Parts.Look

local o = Parts.o

local Houses = {}

export type Ground = (x: number, z: number) -> number
export type Placement = { x: number, y: number, z: number, rot: number }
-- Where things ended up, for callers that decorate a house (special buildings): local coordinates.
export type Info = {
	zFront: number, -- ground floor front wall
	zBack: number,
	ground: number, -- ground floor height
	top: number, -- wall top under the roof
	ridge: number,
	bodyW: number,
	bodyX: number,
	gableFront: boolean,
}

type Lot = {
	id: string,
	kind: string,
	style: string,
	x: number,
	z: number,
	w: number,
	d: number,
	rot: number,
	floors: number,
	seed: number,
	arcade: boolean?,
}

-- Lowest and highest ground under a rotated footprint (corners, edge midpoints and centre).
function Houses.groundRange(x: number, z: number, w: number, d: number, rot: number, ground: Ground): (number, number)
	local r = math.rad(rot)
	local c, s = math.cos(r), math.sin(r)
	local lo, hi = math.huge, -math.huge
	for _, f in { { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { 0, 0 } } do
		local lx, lz = f[1] * w / 2, f[2] * d / 2
		local h = ground(x + lx * c + lz * s, z - lx * s + lz * c)
		lo, hi = math.min(lo, h), math.max(hi, h)
	end
	return lo, hi
end

local function pickLook(bp: BP, style: string): Look
	local rng = bp.rng
	local stone = if style == "patrician" then Palette.pick(rng, Palette.ashlar) else Palette.pick(rng, Palette.rubble)
	local roof
	if style == "cottage" then
		roof = if rng:chance(0.7) then Palette.pick(rng, Palette.thatch) else Palette.pick(rng, Palette.shingles)
	elseif style == "craft" then
		roof = if rng:chance(0.75) then Palette.pick(rng, Palette.shingles) else Palette.pick(rng, Palette.tiles)
	elseif style == "patrician" then
		roof = if rng:chance(0.6) then Palette.pick(rng, Palette.tiles) else Palette.pick(rng, Palette.slateRoof)
	else
		roof = if rng:chance(0.55) then Palette.pick(rng, Palette.tiles) else Palette.pick(rng, Palette.shingles)
	end
	return {
		timber = Palette.pick(rng, Palette.timber),
		plaster = Palette.pick(rng, if style == "patrician" then Palette.richPlaster else Palette.plaster),
		planks = Palette.pick(rng, if style == "cottage" then Palette.greyPlanks else Palette.planks),
		shutter = Palette.pick(rng, Palette.shutter),
		door = Palette.pick(rng, Palette.door),
		stone = stone,
		roof = roof,
	}
end

-- Stone plinth from below the lowest ground up to the floor (y = 0).
local function plinth(bp: BP, look: Look, w: number, zf: number, zb: number, depth: number)
	bp:box(w + 0.5, depth, zb - zf + 0.5, 0, -depth / 2, (zf + zb) / 2, o(look.stone, "shell", { q = true }))
end

-- Plain storey block (shell) between z = zf (front) and zb (back).
local function block(bp: BP, swatch: Palette.Swatch, w: number, y0: number, h: number, zf: number, zb: number)
	bp:box(w, h, zb - zf, 0, y0 + h / 2, (zf + zb) / 2, o(swatch, "shell", { q = true }))
end

-- Timber frame on all four sides of a storey. `side` windows only on detached houses.
local function frameStorey(
	bp: BP,
	look: Look,
	w: number,
	y0: number,
	h: number,
	zf: number,
	zb: number,
	detached: boolean,
	flowers: number
)
	-- front
	bp:push(0, 0, zf)
	Parts.timberWall(bp, look, w, y0, h, 0, 0.7, flowers)
	bp:pop()
	-- back
	bp:push(0, 0, zb, 0, 180, 0)
	Parts.timberWall(bp, look, w, y0, h, 0, 0.35, 0, true)
	bp:pop()
	-- sides
	local depth = zb - zf
	for _, e in { -1, 1 } do
		bp:push(e * w / 2, 0, (zf + zb) / 2, 0, if e < 0 then 90 else -90, 0)
		if detached then
			Parts.timberWall(bp, look, depth, y0, h, 0, 0.3, 0, true)
		else
			-- party wall: rails only, the neighbour hides the rest
			bp:box(depth + 0.2, 0.6, 0.3, 0, y0 + 0.3, -0.1, o(look.timber))
			bp:box(depth + 0.2, 0.5, 0.3, 0, y0 + h - 0.25, -0.1, o(look.timber))
		end
		bp:pop()
	end
end

-- Stone ground floor details: door, small windows or a shop front, corner quoins for rich houses.
local function groundFront(
	bp: BP,
	look: Look,
	w: number,
	h: number,
	zf: number,
	shop: boolean,
	quoins: boolean,
	drop: number
)
	local rng = bp.rng
	local doorX = if w >= 15 then rng:float(-w / 4, w / 4) else rng:float(-1, 1)
	local dw = 3.2
	Parts.door(bp, look, doorX, zf, dw, math.min(h - 1.6, 7), Palette.pick(rng, Palette.ashlar))
	Parts.steps(bp, look, doorX, zf, dw + 1.4, drop)
	-- windows left and right of the door
	for _, side in { -1, 1 } do
		local room = if side < 0 then doorX - dw / 2 - 1 + w / 2 else w / 2 - (doorX + dw / 2 + 1)
		if room >= 3.2 then
			local cx = if side < 0 then -w / 2 + room / 2 else w / 2 - room / 2
			if shop and room >= 4.5 then
				-- shop front: wide opening, folded-down counter shutter and a cloth awning
				local sw = math.min(room - 1.4, 5)
				bp:box(sw, 3, 0.2, cx, 3.4, zf - 0.04, o(Palette.glass, "detail", { tag = "window", jitter = 0 }))
				bp:box(sw + 0.4, 0.35, 1.4, cx, 1.85, zf - 0.7, o(look.planks))
				local aw = Palette.pick(rng, Palette.awning)
				bp:rbox(sw + 1, 0.2, 3, cx, 5.6, zf - 1.35, -22, 0, 0, o(aw))
				bp:beam(cx - sw / 2 - 0.3, 6.1, zf - 0.1, cx - sw / 2 - 0.3, 5.0, zf - 2.7, 0.2, o(look.timber))
				bp:beam(cx + sw / 2 + 0.3, 6.1, zf - 0.1, cx + sw / 2 + 0.3, 5.0, zf - 2.7, 0.2, o(look.timber))
			else
				Parts.window(bp, look, cx, h * 0.52, zf, 1.6, 2, false)
				-- iron grille
				bp:box(0.12, 2, 0.1, cx - 0.4, h * 0.52, zf - 0.3, o(Palette.metal[1], "fine"))
				bp:box(0.12, 2, 0.1, cx + 0.4, h * 0.52, zf - 0.3, o(Palette.metal[1], "fine"))
			end
		end
	end
	if quoins then
		for _, side in { -1, 1 } do
			local y = 0.6
			local i = 0
			while y < h - 0.6 do
				local long = i % 2 == 0
				local qw = if long then 1.6 else 1
				bp:box(qw, 0.9, 0.35, side * (w / 2 - qw / 2 + 0.05), y, zf - 0.12, o(look.stone))
				y += 1
				i += 1
			end
		end
	end
	-- string course between the stone floor and the timber above
	bp:box(w + 0.5, 0.45, 0.6, 0, h - 0.2, zf - 0.2, o(look.stone))
end

-- Arcade (podcienia) on the rynek: the ground floor is set back, stone pillars carry the floor above.
local function arcade(bp: BP, look: Look, w: number, h: number, zFront: number, depthBack: number)
	local n = if w >= 15 then 3 else 2
	local bay = w / n
	for i = 0, n do
		local x = -w / 2 + i * bay
		local px = if i == 0 then x + 0.7 elseif i == n then x - 0.7 else x
		bp:box(1.4, h, 1.4, px, h / 2, zFront + 0.7, o(look.stone, "shell", { q = true }))
		bp:box(1.8, 0.5, 1.8, px, 0.25, zFront + 0.7, o(look.stone))
		bp:box(1.8, 0.5, 1.8, px, h - 1.5, zFront + 0.7, o(look.stone))
	end
	for i = 1, n do
		local cx = -w / 2 + (i - 0.5) * bay
		local inner = bay - 1.4
		-- lintel and two spandrel wedges give each bay a pointed-arch outline
		bp:box(bay, 1.3, 1.4, cx, h - 0.65, zFront + 0.7, o(look.stone, "shell"))
		local sw = math.min(1.8, inner / 2 - 0.2)
		bp:add("wedge", 1.3, 1.8, sw, cx - inner / 2 + sw / 2, h - 1.3 - 0.9, zFront + 0.7, 0, -90, 180, o(look.stone))
		bp:add("wedge", 1.3, 1.8, sw, cx + inner / 2 - sw / 2, h - 1.3 - 0.9, zFront + 0.7, 0, 90, 180, o(look.stone))
		-- hanging lantern in every other bay
		if i % 2 == 1 then
			bp:box(0.2, 0.8, 0.2, cx, h - 1.7, zFront + 1.4, o(Palette.metal[1]))
			bp:box(
				0.7,
				0.9,
				0.7,
				cx,
				h - 2.5,
				zFront + 1.4,
				{ c = "#FFD08A", m = "Neon", lod = "detail", t = 0.2, tag = "lamp" }
			)
			bp:light(cx, h - 2.5, zFront + 1.4, "#FFB860", 12, 0.6, "lamp")
		end
	end
	-- arcade floor (stone slabs) and the back wall of the walkway is the ground floor front
	bp:box(w, 0.3, depthBack, 0, 0.15, zFront + depthBack / 2, o(Palette.pick(bp.rng, Palette.ashlar)))
end

-- Lean-to shed on one side of a craftsman's house (open front, sloped roof, woodpile and barrels).
local function leanTo(bp: BP, look: Look, side: number, x0: number, width: number, h: number, zf: number, zb: number)
	local rng = bp.rng
	local cx = x0 + side * width / 2
	local depth = zb - zf
	local low = h * 0.6
	-- back wall (planks) and outer side wall
	bp:box(width, h, 0.4, cx, h / 2, zb - 0.2, o(look.planks, "shell", { q = true }))
	bp:box(0.4, low, depth, x0 + side * (width - 0.2), low / 2, (zf + zb) / 2, o(look.planks, "shell", { q = true }))
	-- posts at the open front
	bp:box(0.6, low, 0.6, x0 + side * (width - 0.4), low / 2, zf + 0.4, o(look.timber, "shell"))
	-- roof plate sloping down and out
	local run = width + 0.8
	local drop = h - low
	local len = math.sqrt(run * run + drop * drop)
	local ang = math.deg(math.atan2(drop, run))
	bp:rbox(
		len,
		0.4,
		depth + 1,
		cx + side * 0.4,
		low + drop / 2 + 0.3,
		(zf + zb) / 2,
		0,
		0,
		-side * ang,
		o(look.roof, "shell")
	)
	-- contents: woodpile, barrel, chopping block
	for i = 0, 2 do
		for j = 0, 2 - i do
			bp:add(
				"cyl",
				2.4,
				0.9,
				0.9,
				cx,
				0.45 + i * 0.8,
				zb - 1 - j * 0.95 - i * 0.45,
				0,
				0,
				0,
				o(Palette.pick(rng, Palette.planks), "detail", { jitter = 0.1 })
			)
		end
	end
	bp:add("cyl", 2.4, 1.8, 1.8, cx, 1.2, zf + 2, 0, 0, 90, o(look.planks))
	bp:add("cyl", 1, 1.4, 1.4, cx + side * 1.2, 0.5, zf + 3.5, 0, 0, 90, o(look.timber))
end

-- Log walls of a cottage: horizontal logs, crossing at the corners.
local function logWalls(bp: BP, look: Look, w: number, d: number, h: number)
	local rows = math.floor(h / 1)
	for i = 0, rows - 1 do
		local y = 0.5 + i
		local shift = if i % 2 == 0 then 0 else 0.5
		for _, e in { -1, 1 } do
			bp:add(
				"cyl",
				w + 1.6,
				1.05,
				1.05,
				0,
				y + shift * 0,
				e * (d / 2),
				0,
				0,
				0,
				o(look.planks, "detail", { jitter = 0.08 })
			)
			bp:add(
				"cyl",
				d + 1.6,
				1.05,
				1.05,
				e * (w / 2),
				y + 0.5,
				0,
				0,
				90,
				0,
				o(look.planks, "detail", { jitter = 0.08 })
			)
		end
	end
end

-- Builds one ordinary house. Returns its blueprint and where to put it (map-relative, rot in degrees).
function Houses.build(lot: Lot, ground: Ground): (BP, Placement, Info)
	local bp = Blueprint.new(lot.seed)
	local rng = bp.rng
	local style = lot.style
	local look = pickLook(bp, style)
	local lo, hi = Houses.groundRange(lot.x, lot.z, lot.w, lot.d, lot.rot, ground)
	local y0 = hi + 0.2
	local depthBelow = y0 - lo + 1.5
	local fx, fz = -math.sin(math.rad(lot.rot)), -math.cos(math.rad(lot.rot))
	local doorGround = ground(lot.x + fx * (lot.d / 2 + 1), lot.z + fz * (lot.d / 2 + 1))
	local drop = y0 - doorGround

	local detached = style == "craft" or style == "cottage"
	local W = lot.w - (if detached then 0.6 else 0.3)
	local floors = lot.floors
	local G = if style == "patrician" then 10 elseif style == "cottage" then 7.5 elseif style == "craft" then 8.5 else 9
	local U = if style == "patrician" then 8 else 7.5
	local jetty = if style == "patrician" then 0.6 elseif style == "cottage" then 0.8 else 1
	local zb = lot.d / 2 - 0.3
	local zf0 = -lot.d / 2 + 0.3 + jetty * (floors - 1)
	local stoneHouse = style == "patrician" and rng:chance(0.5)
	local leanSide = 0
	local bodyW = W
	if lot.kind == "workshopHouse" and W >= 14 then
		leanSide = if rng:chance(0.5) then -1 else 1
		bodyW = W - 4.5
	end
	-- the main body is shifted away from the lean-to
	local bodyX = -leanSide * (W - bodyW) / 2
	bp:push(bodyX, 0, 0)

	plinth(bp, look, bodyW, zf0, zb, depthBelow)

	local yTop = 0
	local zfTop = zf0
	if style == "cottage" then
		-- one storey of logs or wattle and daub, attic in the roof
		if rng:chance(0.4) then
			block(bp, look.planks, bodyW - 0.4, 0, G, zf0 + 0.2, zb - 0.2)
			logWalls(bp, look, bodyW - 0.6, zb - zf0 - 0.6, G)
			bp:push(0, 0, zf0 + 0.1)
			Parts.door(bp, look, rng:float(-1.5, 1.5), -0.2, 3, 6.2, nil)
			Parts.window(bp, look, -bodyW / 4 - 0.8, 4, -0.25, 1.4, 1.6, rng:chance(0.3))
			bp:pop()
		else
			block(bp, look.plaster, bodyW, 0, G, zf0, zb)
			frameStorey(bp, look, bodyW, 0, G, zf0, zb, true, 0.3)
			bp:push(0, 0, zf0)
			Parts.door(bp, look, rng:float(-1, 1), -0.12, 3, 6.2, nil)
			bp:pop()
		end
		yTop = G
		if floors >= 2 then
			block(bp, look.plaster, bodyW, G, U, zf0 - jetty, zb)
			frameStorey(bp, look, bodyW, G, U, zf0 - jetty, zb, true, 0.3)
			Parts.joists(bp, look, bodyW, G, zf0, jetty)
			yTop = G + U
			zfTop = zf0 - jetty
		end
	else
		local groundFront0 = if lot.arcade then zf0 + 4.5 else zf0
		-- ground floor: stone (townhouses, rich houses) or timber (most craftsmen)
		local stoneGround = style ~= "craft" or rng:chance(0.35)
		if stoneGround then
			block(bp, look.stone, bodyW, 0, G, groundFront0, zb)
			bp:push(0, 0, groundFront0)
			groundFront(
				bp,
				look,
				bodyW,
				G,
				0,
				style == "burgher" and not lot.arcade and rng:chance(0.55),
				style == "patrician",
				if lot.arcade then 0 else drop
			)
			bp:pop()
		else
			block(bp, look.plaster, bodyW, 0, G, groundFront0, zb)
			frameStorey(bp, look, bodyW, 0, G, groundFront0, zb, detached, 0.1)
			bp:push(0, 0, groundFront0)
			Parts.door(bp, look, rng:float(-2, 2), -0.12, 4.2, 7, nil)
			bp:pop()
		end
		if lot.arcade then
			arcade(bp, look, bodyW, G, zf0, 4.5)
		end
		yTop = G
		for k = 1, floors - 1 do
			local zf = zf0 - jetty * k
			if stoneHouse then
				block(bp, look.plaster, bodyW, yTop, U, zf, zb)
				-- rich stone house: plaster facade with stone window frames and a cornice
				bp:push(0, 0, zf)
				local n = math.max(2, math.floor(bodyW / 4.2))
				for i = 1, n do
					local cx = -bodyW / 2 + (i - 0.5) * bodyW / n
					bp:box(2.6, 3.6, 0.25, cx, yTop + U * 0.52, -0.05, o(look.stone))
					Parts.window(bp, look, cx, yTop + U * 0.52, -0.2, 1.8, 2.9, rng:chance(0.3))
				end
				bp:box(bodyW + 0.4, 0.5, 0.5, 0, yTop + U - 0.25, -0.2, o(look.stone))
				bp:pop()
			else
				block(bp, look.plaster, bodyW, yTop, U, zf, zb)
				frameStorey(bp, look, bodyW, yTop, U, zf, zb, detached, if style == "burgher" then 0.3 else 0.15)
				Parts.joists(bp, look, bodyW, yTop, zf + jetty, jetty)
			end
			yTop += U
			zfTop = zf
		end
	end

	-- roof: narrow houses turn the gable to the street, wide ones the eaves
	local depthTop = zb - zfTop
	local gableFront = if style == "cottage" then bodyW < 13 and rng:chance(0.5) else bodyW <= 15.5 or rng:chance(0.3)
	local pitch = if style == "cottage"
		then rng:float(48, 54)
		elseif gableFront then rng:float(50, 56)
		else rng:float(42, 48)
	local thatch = look.roof.m == "Grass"
	local spec: Parts.RoofSpec = {
		w = bodyW,
		d = depthTop,
		zc = (zfTop + zb) / 2,
		y = yTop,
		pitch = pitch,
		ridgeAlongZ = gableFront,
		eave = if thatch then 1.6 elseif detached then 1.2 else 0.9,
		verge = if detached then 0.9 elseif gableFront then 0.9 else 0.2,
		thick = if thatch then 1.4 else 0.6,
		roof = look.roof,
		gable = look.plaster,
		timber = if stoneHouse then nil else look.timber,
	}
	if not gableFront and not detached then
		spec.eave = 1
	end
	if gableFront and not detached then
		spec.eave = 0.25 -- neighbours share the eaves line
	end
	local ridge = Parts.roof(bp, look, spec)
	-- stepped stone gable on rich stone houses that face the street with the gable
	if stoneHouse and gableFront then
		local rise = ridge - yTop
		local steps = 4
		for i = 0, steps - 1 do
			local hh = rise * (i + 1) / steps
			local ww = bodyW * (1 - i / steps)
			bp:box(
				ww,
				rise / steps + 0.6,
				0.8,
				0,
				yTop + hh - rise / steps / 2 + 0.3,
				zfTop - 0.1,
				o(look.stone, "shell")
			)
		end
	end
	-- dormers on wide eaves-front roofs
	if not gableFront and bodyW >= 14 and not thatch then
		local count = if bodyW >= 17 then 2 else 1
		local tanp = math.tan(math.rad(pitch))
		local zc = (zfTop + zb) / 2
		local zd = zc - (ridge - yTop - 2.2) / tanp
		for i = 1, count do
			local x = if count == 1 then rng:float(-1.5, 1.5) else (i - 1.5) * bodyW * 0.45
			local yb = yTop + 1.2
			bp:box(3, 3.2, 3.4, x, yb + 1.6, zd + 1.4, o(look.plaster, "shell"))
			Parts.window(bp, look, x, yb + 1.7, zd - 0.3, 1.4, 1.7, false)
			for _, s in { -1, 1 } do
				bp:rbox(2.4, 0.35, 4.4, x + s * 1, yb + 3.6, zd + 1.2, 0, 0, -s * 45, o(look.roof))
			end
		end
	end
	-- chimney
	if rng:chance(if style == "cottage" then 0.5 else 0.85) then
		local cx, cz
		if gableFront then
			cx = rng:float(0.8, 2) * (if rng:chance(0.5) then 1 else -1)
			cz = (zfTop + zb) / 2 + rng:float(-depthTop / 4, depthTop / 4)
		else
			cx = rng:float(-bodyW / 3, bodyW / 3)
			cz = (zfTop + zb) / 2 + rng:float(0.8, 2) * (if rng:chance(0.5) then 1 else -1)
		end
		Parts.chimney(bp, cx, cz, yTop - 2, ridge + 2.2, rng:chance(0.35))
	end
	-- moss on the lower roof edges (in the frame of one roof plate)
	local mossCount = rng:int(0, if style == "cottage" then 4 else 2)
	if mossCount > 0 and not thatch then
		local tanp = math.tan(math.rad(pitch))
		if gableFront then
			local hs = bodyW / 2 + spec.eave
			bp:push(hs * 0.7, ridge - hs * 0.7 * tanp + 0.6, (zfTop + zb) / 2, 0, 0, -pitch)
			Parts.moss(bp, mossCount, hs * 0.5, depthTop)
			bp:pop()
		else
			local hs = depthTop / 2 + spec.eave
			bp:push(0, ridge - hs * 0.7 * tanp + 0.6, (zfTop + zb) / 2 - hs * 0.7, -pitch, 0, 0)
			Parts.moss(bp, mossCount, bodyW, hs * 0.4)
			bp:pop()
		end
	end
	bp:pop()

	if leanSide ~= 0 then
		local x0 = bodyX + leanSide * bodyW / 2
		leanTo(bp, look, leanSide, x0, W - bodyW, math.min(G, 7.5), zf0 + 1, zb)
	end
	-- house sign on some burgher houses (hanging board on an iron bracket)
	if style == "burgher" and rng:chance(0.3) and not lot.arcade then
		local sx = bodyX + (bodyW / 2 - 1.2) * (if rng:chance(0.5) then 1 else -1)
		bp:box(0.2, 0.2, 2.4, sx, G + 0.8, zf0 - 1.2, o(Palette.metal[1]))
		bp:box(0.2, 1.6, 1.8, sx, G - 0.2, zf0 - 1.6, o(Palette.pick(rng, Palette.planks)))
	end
	return bp,
		{ x = lot.x, y = y0, z = lot.z, rot = lot.rot },
		{
			zFront = if lot.arcade then zf0 + 4.5 else zf0,
			zBack = zb,
			ground = G,
			top = yTop,
			ridge = ridge,
			bodyW = bodyW,
			bodyX = bodyX,
			gableFront = gableFront,
		}
end

return Houses
