--!strict
-- Reusable building parts for TownGen (S21): timber-framed floors, windows, doors, roofs, chimneys.
-- Every function draws into a Blueprint in its current frame (front = -Z). Pure.

local Blueprint = require("./Blueprint")
local Palette = require("./Palette")

type BP = Blueprint.Blueprint
type Swatch = Palette.Swatch

local Parts = {}

export type Look = {
	timber: Swatch,
	plaster: Swatch,
	planks: Swatch,
	shutter: Swatch,
	door: Swatch,
	stone: Swatch,
	roof: Swatch,
}

local function o(s: Swatch, lod: Blueprint.Lod?, extra: { [string]: any }?): Blueprint.Options
	local opts: any = { c = s.c, m = s.m, lod = lod or "detail" }
	if extra then
		for k, v in extra do
			opts[k] = v
		end
	end
	return opts
end
Parts.o = o

-- Window on a wall plane facing -Z at z = zf (the wall surface), centred at (x, y). `ww` x `wh` glass.
function Parts.window(
	bp: BP,
	look: Look,
	x: number,
	y: number,
	zf: number,
	ww: number,
	wh: number,
	flowers: boolean,
	plain: boolean?
)
	local rng = bp.rng
	bp:box(ww, wh, 0.2, x, y, zf - 0.04, o(Palette.glass, "detail", { tag = "window", jitter = 0 }))
	-- leaded cross
	bp:box(0.16, wh, 0.12, x, y, zf - 0.16, o(look.timber, "fine"))
	bp:box(ww, 0.16, 0.12, x, y + wh * 0.12, zf - 0.16, o(look.timber, "fine"))
	-- sill and lintel
	bp:box(ww + 0.7, 0.25, 0.55, x, y - wh / 2 - 0.12, zf - 0.22, o(look.timber))
	bp:box(ww + 0.5, 0.3, 0.3, x, y + wh / 2 + 0.15, zf - 0.1, o(look.timber))
	-- open shutters (hinged at the window edges, swung 60 degrees out)
	if not plain and rng:chance(0.75) then
		local sw = ww / 2
		for _, side in { -1, 1 } do
			local hx = x + side * (ww / 2 + 0.05)
			local a = math.rad(60)
			local cx = hx + side * math.cos(a) * sw / 2
			local cz = zf - 0.1 - math.sin(a) * sw / 2
			bp:rbox(sw, wh + 0.1, 0.14, cx, y, cz, 0, side * -60, 0, o(look.shutter))
		end
	end
	if flowers then
		bp:box(ww + 0.2, 0.5, 0.6, x, y - wh / 2 - 0.55, zf - 0.4, o(look.planks, "fine"))
		local colours = { "#B03A3A", "#D8B03A", "#8A4AA0", "#E0D8C0", "#C8603A" }
		for i = 1, 3 do
			local c = colours[rng:int(1, #colours)]
			bp:add(
				"ball",
				0.7,
				0.6,
				0.7,
				x + (i - 2) * ww / 3,
				y - wh / 2 - 0.15,
				zf - 0.45,
				0,
				0,
				0,
				{ c = c, m = "Grass", lod = "fine", jitter = 0.08 }
			)
		end
	end
end

-- Arched plank door in a wall facing -Z at z = zf; bottom at y = 0 of the current frame.
function Parts.door(bp: BP, look: Look, x: number, zf: number, dw: number, dh: number, stone: Swatch?)
	local frame = stone or look.timber
	bp:box(dw, dh - dw / 2, 0.3, x, (dh - dw / 2) / 2, zf - 0.08, o(look.door))
	-- round top of the leaf and the arch around it (cylinders with the axis along Z)
	bp:add("cyl", 0.3, dw, dw, x, dh - dw / 2, zf - 0.08, 0, 90, 0, o(look.door))
	bp:add("cyl", 0.36, dw + 1.2, dw + 1.2, x, dh - dw / 2, zf - 0.02, 0, 90, 0, o(frame))
	for _, side in { -1, 1 } do
		bp:box(0.6, dh - dw / 2, 0.42, x + side * (dw / 2 + 0.3), (dh - dw / 2) / 2, zf - 0.05, o(frame))
	end
	-- iron studs and ring
	bp:add("ball", 0.35, 0.35, 0.35, x + dw * 0.28, dh * 0.45, zf - 0.3, 0, 0, 0, o(Palette.metal[1], "fine"))
	bp:box(dw * 0.9, 0.2, 0.08, x, dh * 0.25, zf - 0.26, o(Palette.metal[1], "fine"))
	bp:box(dw * 0.9, 0.2, 0.08, x, dh * 0.62, zf - 0.26, o(Palette.metal[1], "fine"))
end

-- Stone steps in front of a door when the street is lower than the floor (drop in studs, positive).
function Parts.steps(bp: BP, look: Look, x: number, zf: number, width: number, drop: number)
	local n = math.min(4, math.ceil(drop / 0.6))
	if drop < 0.3 then
		return
	end
	local rise = drop / n
	for i = 1, n do
		local h = drop - (i - 1) * rise
		bp:box(width, h, 1, x, -drop + h / 2, zf - (i - 0.5), o(look.stone, "shell", { q = true }))
	end
end

-- Timber frame of one storey on a wall plane facing -Z at z = zf, spanning x in [-w/2, w/2] and y in [y0, y0+h].
-- `windows` = how likely each panel gets a window. Returns nothing; draws posts, rails, braces and windows.
function Parts.timberWall(
	bp: BP,
	look: Look,
	w: number,
	y0: number,
	h: number,
	zf: number,
	windows: number,
	flowers: number,
	plain: boolean?
)
	local rng = bp.rng
	local panels = math.max(1, math.floor(w / 3.4 + 0.5))
	local pw = w / panels
	local t = 0.55
	-- sill and head rails
	bp:box(w + 0.3, 0.6, 0.38, 0, y0 + 0.3, zf - 0.1, o(look.timber))
	bp:box(w + 0.3, 0.5, 0.38, 0, y0 + h - 0.25, zf - 0.1, o(look.timber))
	-- posts (corner posts are a little thicker), slightly out of plumb
	for i = 0, panels do
		local x = -w / 2 + i * pw
		local corner = i == 0 or i == panels
		local px = if i == 0 then x + 0.3 elseif i == panels then x - 0.3 else x
		bp:rbox(
			if corner then 0.75 else t,
			h - 0.9,
			0.34,
			px,
			y0 + h / 2 + 0.05,
			zf - 0.1,
			0,
			0,
			rng:float(-0.8, 0.8),
			o(look.timber)
		)
	end
	-- panels
	local wantWindow = windows
	for i = 1, panels do
		local x0 = -w / 2 + (i - 1) * pw
		local cx = x0 + pw / 2
		local inner = pw - t
		if rng:chance(wantWindow) and inner >= 1.8 then
			local ww = math.clamp(inner - 1.3, 1.4, 2.4)
			local wh = math.min(2.8, h - 3)
			Parts.window(bp, look, cx, y0 + h * 0.5, zf, ww, wh, rng:chance(flowers), plain)
			-- breast rail under the window
			bp:box(inner, 0.4, 0.3, cx, y0 + h * 0.5 - wh / 2 - 0.55, zf - 0.08, o(look.timber))
		else
			local a, b = x0 + t / 2, x0 + pw - t / 2
			local lo, hi = y0 + 0.6, y0 + h - 0.5
			local pattern = rng:int(1, 4)
			if pattern == 1 then -- St Andrew's cross
				bp:beam(a, lo, zf - 0.1, b, hi, zf - 0.1, 0.42, o(look.timber))
				bp:beam(a, hi, zf - 0.1, b, lo, zf - 0.1, 0.42, o(look.timber))
			elseif pattern == 2 then -- single brace towards the nearer corner post
				if cx < 0 then
					bp:beam(a, hi, zf - 0.1, b, lo, zf - 0.1, 0.45, o(look.timber))
				else
					bp:beam(a, lo, zf - 0.1, b, hi, zf - 0.1, 0.45, o(look.timber))
				end
			elseif pattern == 3 then -- mid rail with two short braces ("man" figure)
				local mid = (lo + hi) / 2
				bp:box(pw - t, 0.4, 0.3, cx, mid, zf - 0.08, o(look.timber))
				bp:beam(cx, mid, zf - 0.1, a, hi, zf - 0.1, 0.4, o(look.timber))
				bp:beam(cx, mid, zf - 0.1, b, hi, zf - 0.1, 0.4, o(look.timber))
			else -- plain panel with a mid rail
				bp:box(pw - t, 0.4, 0.3, cx, (lo + hi) / 2, zf - 0.08, o(look.timber))
			end
		end
	end
end

-- Projecting joist ends under a jetty: the floor above sticks out by `jetty` studs at height y.
function Parts.joists(bp: BP, look: Look, w: number, y: number, zf: number, jetty: number)
	local n = math.max(2, math.floor(w / 2.4))
	for i = 0, n do
		local x = -w / 2 + 0.4 + i * (w - 0.8) / n
		bp:box(0.5, 0.55, jetty + 0.5, x, y - 0.3, zf - (jetty + 0.5) / 2 + 0.25, o(look.timber, "fine"))
	end
	bp:box(w + 0.4, 0.5, 0.4, 0, y - 0.25, zf - jetty + 0.05, o(look.timber))
end

export type RoofSpec = {
	w: number, -- wall width under the roof (x)
	d: number, -- wall depth under the roof (z), centred at z = zc
	zc: number,
	y: number, -- wall top
	pitch: number, -- degrees
	ridgeAlongZ: boolean, -- true: gables face front and back; false: eaves face front and back
	eave: number, -- overhang at the eaves
	verge: number, -- overhang at the gables
	thick: number,
	roof: Swatch,
	gable: Swatch, -- gable triangle fill
	timber: Swatch?, -- timber on the gables (nil = plain)
}

-- Gable roof. Returns the ridge height (absolute y in the frame).
function Parts.roof(bp: BP, look: Look, spec: RoofSpec): number
	local rng = bp.rng
	local p = math.rad(spec.pitch)
	local tanp = math.tan(p)
	local span = if spec.ridgeAlongZ then spec.w else spec.d
	local length = if spec.ridgeAlongZ then spec.d else spec.w
	local rise = span / 2 * tanp
	local yR = spec.y + rise
	local hs = span / 2 + spec.eave
	local th = spec.thick
	-- The underside of each plate runs from the ridge (0, yR) through the wall top edge down to the eave.
	local plateLen = hs / math.cos(p)
	local off = hs / 2 + th / 2 * math.sin(p)
	local cy = yR - hs / 2 * tanp + th / 2 * math.cos(p)
	for _, s in { -1, 1 } do
		local sag = rng:float(-0.6, 0.6)
		if spec.ridgeAlongZ then
			bp:rbox(
				plateLen,
				th,
				length + 2 * spec.verge,
				s * off,
				cy,
				spec.zc,
				0,
				0,
				-s * spec.pitch + sag,
				o(spec.roof, "shell", { q = true })
			)
		else
			bp:rbox(
				spec.w + 2 * spec.verge,
				th,
				plateLen,
				0,
				cy,
				spec.zc + s * off,
				s * spec.pitch + sag,
				0,
				0,
				o(spec.roof, "shell", { q = true })
			)
		end
	end
	-- ridge cap: a square beam turned 45 degrees, resting in the notch where the two plates meet
	local cap = math.max(0.9, th * 1.3)
	local capY = yR + th * math.cos(p) + cap * 0.2
	if spec.ridgeAlongZ then
		bp:rbox(cap, cap, length + 2 * spec.verge, 0, capY, spec.zc, 0, 0, 45, o(spec.roof))
	else
		bp:rbox(spec.w + 2 * spec.verge, cap, cap, 0, capY, spec.zc, 45, 0, 0, o(spec.roof))
	end
	-- gable triangles (two wedges each) and their timber
	local half = span / 2
	for _, e in { -1, 1 } do
		if spec.ridgeAlongZ then
			local z = spec.zc + e * (length / 2 - 0.2)
			bp:add("wedge", 0.4, rise, half, -half / 2, spec.y + rise / 2, z, 0, 90, 0, o(spec.gable, "shell"))
			bp:add("wedge", 0.4, rise, half, half / 2, spec.y + rise / 2, z, 0, -90, 0, o(spec.gable, "shell"))
		else
			local x = e * (spec.w / 2 - 0.2)
			bp:add("wedge", 0.4, rise, half, x, spec.y + rise / 2, spec.zc - half / 2, 0, 0, 0, o(spec.gable, "shell"))
			bp:add(
				"wedge",
				0.4,
				rise,
				half,
				x,
				spec.y + rise / 2,
				spec.zc + half / 2,
				0,
				180,
				0,
				o(spec.gable, "shell")
			)
		end
	end
	if spec.timber then
		local tb = spec.timber :: Swatch
		for _, e in { -1, 1 } do
			-- work in a frame on the gable plane, facing outwards (-Z of the sub frame)
			if spec.ridgeAlongZ then
				bp:push(0, 0, spec.zc + e * (length / 2), 0, if e < 0 then 0 else 180, 0)
			else
				bp:push(e * (spec.w / 2), 0, spec.zc, 0, if e < 0 then 90 else -90, 0)
			end
			local zf = -0.1
			-- king post, collar beam, two braces, barge boards
			bp:box(0.5, rise - 0.8, 0.3, 0, spec.y + (rise - 0.8) / 2, zf - 0.1, o(tb))
			local cy2 = spec.y + rise * 0.42
			local cw = span * (1 - 0.42) - 0.6
			bp:box(cw, 0.42, 0.3, 0, cy2, zf - 0.1, o(tb))
			bp:beam(-cw / 2 + 0.2, spec.y + 0.2, zf - 0.12, -0.3, cy2, zf - 0.12, 0.38, o(tb))
			bp:beam(cw / 2 - 0.2, spec.y + 0.2, zf - 0.12, 0.3, cy2, zf - 0.12, 0.38, o(tb))
			for _, s in { -1, 1 } do
				bp:beam(
					s * (half + spec.eave * 0.9),
					spec.y - spec.eave * 0.9 * tanp - 0.2,
					zf - spec.verge + 0.1,
					0,
					yR - 0.1,
					zf - spec.verge + 0.1,
					0.5,
					o(look.planks)
				)
			end
			bp:pop()
		end
	end
	return yR
end

-- Brick chimney rising through the roof at (x, z); `from` = bottom y, `top` = top y.
function Parts.chimney(bp: BP, x: number, z: number, from: number, top: number, smoke: boolean)
	local brick = Palette.pick(bp.rng, Palette.brick)
	bp:box(2, top - from, 2, x, (from + top) / 2, z, o(brick, "shell"))
	bp:box(2.6, 0.45, 2.6, x, top + 0.2, z, o(Palette.slate[1]))
	bp:box(1.2, 0.2, 1.2, x, top + 0.45, z, o(Palette.soot, "detail", { tag = if smoke then "smoke" else nil }))
end

-- Patches of moss on a roof plate: called inside a frame aligned with the plate (top surface at y = 0).
function Parts.moss(bp: BP, count: number, length: number, width: number)
	local rng = bp.rng
	for _ = 1, count do
		local m = Palette.pick(rng, Palette.moss)
		bp:box(
			rng:float(1.5, 3.5),
			0.18,
			rng:float(1.2, 2.6),
			rng:float(-length / 2 + 2, length / 2 - 2),
			0.05,
			rng:float(-width / 2 + 1, width / 2 - 1),
			o(m, "fine")
		)
	end
end

export type TreeKind = "apple" | "oak" | "pine" | "yew" | "birch" | "willow"

local CROWN: { [string]: { string } } = {
	apple = { "#4F6B35", "#5B7340", "#567036" },
	oak = { "#3F5F2C", "#46662F", "#3A5528" },
	pine = { "#2F4A2A", "#34502C", "#2A4426" },
	yew = { "#24382A", "#2A3F2E" },
	birch = { "#7E9A45", "#8AA650" },
	willow = { "#5F7D3A", "#6A8642" },
}

-- Tree standing at (x, y, z) of the current frame; `lod` lets orchards go "detail" and far forests "shell".
function Parts.tree(bp: BP, x: number, y: number, z: number, kind: TreeKind, scale: number, lod: Blueprint.Lod?)
	local rng = bp.rng
	local s = scale * rng:float(0.85, 1.15)
	local l: Blueprint.Lod = lod or "detail"
	local crown = CROWN[kind]
	local leaf = { c = crown[rng:int(1, #crown)], m = "LeafyGrass" }
	local bark = { c = if kind == "birch" then "#CFC8B8" else "#4A3A2C", m = "Wood" }
	local trunkH = (if kind == "pine" or kind == "yew" then 4 elseif kind == "apple" then 3.2 else 5.5) * s
	bp:add("cyl", trunkH, 1 * s, 1 * s, x, y + trunkH / 2, z, 0, 0, 90, o(bark, l, { col = l == "shell", q = false }))
	if kind == "pine" then
		for i = 0, 2 do
			local w = (7 - i * 2) * s
			bp:add(
				"ball",
				w,
				w * 0.9,
				w,
				x,
				y + trunkH + i * 2.6 * s,
				z,
				0,
				0,
				0,
				o(leaf, l, { col = false, q = false })
			)
		end
	elseif kind == "yew" then
		bp:add(
			"ball",
			3.6 * s,
			10 * s,
			3.6 * s,
			x,
			y + trunkH + 3 * s,
			z,
			0,
			0,
			0,
			o(leaf, l, { col = false, q = false })
		)
	else
		local w = (if kind == "apple" then 6 elseif kind == "willow" then 8 else 8.5) * s
		bp:add("ball", w, w * 0.8, w, x, y + trunkH + w * 0.3, z, 0, 0, 0, o(leaf, l, { col = false, q = false }))
		bp:add(
			"ball",
			w * 0.7,
			w * 0.6,
			w * 0.7,
			x + rng:float(-1.2, 1.2) * s,
			y + trunkH + w * 0.55,
			z + rng:float(-1.2, 1.2) * s,
			0,
			0,
			0,
			o(leaf, l, { col = false, q = false })
		)
		if kind == "apple" then
			for _ = 1, 4 do
				local a = rng:float(0, math.pi * 2)
				bp:add(
					"ball",
					0.45,
					0.45,
					0.45,
					x + math.cos(a) * w * 0.45,
					y + trunkH + w * rng:float(0.15, 0.45),
					z + math.sin(a) * w * 0.45,
					0,
					0,
					0,
					{ c = if rng:chance(0.7) then "#A8322A" else "#C8A83A", m = "SmoothPlastic", lod = "fine" }
				)
			end
		end
	end
end

-- Fence from (ax, az) to (bx, bz) at ground heights ya / yb (current frame). kind: "rail", "wattle", "picket".
function Parts.fence(bp: BP, ax: number, ya: number, az: number, bx: number, yb: number, bz: number, kind: string)
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	if len < 1 then
		return
	end
	local wood = Palette.pick(bp.rng, if kind == "wattle" then Palette.planks else Palette.greyPlanks)
	local posts = math.max(1, math.floor(len / 4))
	for i = 0, posts do
		local t = i / posts
		local y = ya + (yb - ya) * t
		bp:box(0.4, 3, 0.4, ax + (bx - ax) * t, y + 1.2, az + (bz - az) * t, o(wood))
	end
	if kind == "wattle" then
		bp:beam(ax, ya + 1.1, az, bx, yb + 1.1, bz, 0.4, o(wood), 1.8)
	elseif kind == "picket" then
		bp:beam(ax, ya + 1, az, bx, yb + 1, bz, 0.25, o(wood))
		bp:beam(ax, ya + 2, az, bx, yb + 2, bz, 0.25, o(wood))
	else
		bp:beam(ax, ya + 1.1, az, bx, yb + 1.1, bz, 0.3, o(wood))
		bp:beam(ax, ya + 2.3, az, bx, yb + 2.3, bz, 0.3, o(wood))
	end
end

-- Small props shared by special buildings, gardens, the market and the farms. All stand on y in the current frame.

function Parts.barrel(bp: BP, x: number, y: number, z: number)
	bp:add("cyl", 2.2, 1.8, 1.8, x, y + 1.1, z, 0, 0, 90, o(Palette.pick(bp.rng, Palette.planks)))
	bp:add("cyl", 0.25, 1.9, 1.9, x, y + 0.5, z, 0, 0, 90, o(Palette.metal[1], "fine"))
	bp:add("cyl", 0.25, 1.9, 1.9, x, y + 1.7, z, 0, 0, 90, o(Palette.metal[1], "fine"))
end

function Parts.crate(bp: BP, x: number, y: number, z: number, s: number)
	bp:rbox(s, s, s, x, y + s / 2, z, 0, bp.rng:float(-15, 15), 0, o(Palette.pick(bp.rng, Palette.planks)))
end

-- Plank bench along local X, turned by `ry` degrees.
function Parts.bench(bp: BP, x: number, y: number, z: number, ry: number, len: number)
	local wood = Palette.pick(bp.rng, Palette.planks)
	bp:push(x, y, z, 0, ry, 0)
	bp:box(len, 0.35, 1.3, 0, 1.6, 0, o(wood))
	bp:box(0.4, 1.45, 1.1, -len / 2 + 0.6, 0.72, 0, o(wood))
	bp:box(0.4, 1.45, 1.1, len / 2 - 0.6, 0.72, 0, o(wood))
	bp:pop()
end

-- Round haystack of radius r.
function Parts.haystack(bp: BP, x: number, y: number, z: number, r: number, lod: Blueprint.Lod?)
	local hay = { c = bp:jitter("#B89A55", 0.08), m = "Grass" }
	bp:add("cyl", r, 2 * r, 2 * r, x, y + r / 2, z, 0, 0, 90, o(hay, lod or "detail", { col = false, q = false }))
	bp:add("ball", 2 * r, 1.7 * r, 2 * r, x, y + r, z, 0, 0, 0, o(hay, lod or "detail", { col = false, q = false }))
end

-- Two-wheeled hand cart, shafts toward local -Z, turned by `ry`.
function Parts.cart(bp: BP, x: number, y: number, z: number, ry: number)
	local wood = Palette.pick(bp.rng, Palette.planks)
	bp:push(x, y, z, 0, ry, 0)
	bp:box(3.2, 0.4, 5, 0, 1.7, 0.4, o(wood))
	bp:box(0.3, 1.1, 5, -1.45, 2.4, 0.4, o(wood))
	bp:box(0.3, 1.1, 5, 1.45, 2.4, 0.4, o(wood))
	bp:box(3.2, 1.1, 0.3, 0, 2.4, 2.75, o(wood))
	for _, s in { -1, 1 } do
		bp:add("cyl", 0.35, 2.8, 2.8, s * 1.85, 1.4, 0.6, 0, 0, 0, o(Palette.timber[1]))
		bp:beam(s * 1, 1.7, -2, s * 0.8, 0.6, -5, 0.3, o(Palette.timber[1]))
	end
	bp:pop()
end

-- Stack of split logs against a wall, along local X.
function Parts.woodpile(bp: BP, x: number, y: number, z: number, ry: number, len: number)
	local bark = { c = "#5A4634", m = "Wood" }
	bp:push(x, y, z, 0, ry, 0)
	for row = 0, 2 do
		bp:add("cyl", len - row * 0.6, 1.2, 1.2, 0, 0.6 + row * 1, (row % 2) * 0.5 - 0.25, 0, 0, 0, o(bark))
		bp:add("cyl", len - row * 0.6, 1.2, 1.2, 0, 0.6 + row * 1, (row % 2) * 0.5 + 0.95, 0, 0, 0, o(bark))
	end
	bp:pop()
end

return Parts
