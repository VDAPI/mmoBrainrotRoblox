--!strict
-- City walls, towers, gatehouses, retaining walls, ramps and stairs, bridges and street lamps (S21).
-- Each function returns a list of Builds (one Model each, so streaming works per piece). Pure.

local Blueprint = require("./Blueprint")
local Palette = require("./Palette")
local Parts = require("./Parts")

type BP = Blueprint.Blueprint
type Swatch = Palette.Swatch

local o = Parts.o

local Structures = {}

export type Ground = (x: number, z: number) -> number
export type Build = {
	name: string,
	bp: BP,
	at: { x: number, y: number, z: number, rot: number },
	tag: string?, -- "wall", "tower", "gate", "retaining", "ramp", "bridge", "lamp"
	gate: any?, -- gate data for gatehouses (portal attributes)
}

-- Wall height above the highest ground under a wall piece, and the gatehouse half width along the wall.
Structures.WALL_HEIGHT = 16
Structures.WALL_THICK = 6
Structures.GATE_HALF = 15
Structures.TOWER_CLEAR = 30

local WALL_STONE: Swatch = { c = "#67625B", m = "Cobblestone" }
local WALL_CAP: Swatch = { c = "#7A746B", m = "Slate" }
local SLIT: Swatch = { c = "#1E1C1A", m = "SmoothPlastic" }

local function rotOf(ux: number, uz: number): number
	-- rot (degrees) whose local +X points along (ux, uz)
	return math.deg(math.atan2(-uz, ux))
end

local function hash(x: number, z: number): number
	return math.floor(math.abs(x * 73.13 + z * 19.71) * 1000) % 2147483647 + 1
end

local function segDist(ax: number, az: number, bx: number, bz: number, x: number, z: number): (number, number)
	local vx, vz = bx - ax, bz - az
	local len2 = vx * vx + vz * vz
	local t = if len2 > 0 then math.clamp(((x - ax) * vx + (z - az) * vz) / len2, 0, 1) else 0
	return math.sqrt((ax + vx * t - x) ^ 2 + (az + vz * t - z) ^ 2), t
end

-- Where the polyline `pts` crosses segment a-b: distance along a-b, or nil.
local function crossing(ax: number, az: number, bx: number, bz: number, pts: { { number } }): number?
	local rx, rz = bx - ax, bz - az
	for i = 1, #pts - 1 do
		local cx, cz = pts[i][1], pts[i][2]
		local sx, sz = pts[i + 1][1] - cx, pts[i + 1][2] - cz
		local den = rx * sz - rz * sx
		if math.abs(den) > 1e-9 then
			local t = ((cx - ax) * sz - (cz - az) * sx) / den
			local u = ((cx - ax) * rz - (cz - az) * rx) / den
			if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
				return t * math.sqrt(rx * rx + rz * rz)
			end
		end
	end
	return nil
end

-- One straight piece of the town wall between two points; local +X along the wall, local -Z faces outwards.
local function wallPiece(
	ax: number,
	az: number,
	bx: number,
	bz: number,
	ground: Ground,
	water: { bed: number, level: number }?
): Build
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local mx, mz = (ax + bx) / 2, (az + bz) / 2
	local rot = rotOf((bx - ax) / len, (bz - az) / len)
	local bp = Blueprint.new(hash(mx, mz))
	local lo, hi = math.huge, -math.huge
	for k = 0, 4 do
		local t = k / 4
		local h = ground(ax + (bx - ax) * t, az + (bz - az) * t)
		lo, hi = math.min(lo, h), math.max(hi, h)
	end
	local T = Structures.WALL_THICK
	local top = math.max(hi, 0) + Structures.WALL_HEIGHT
	local base = lo - 3
	if water then
		-- water gate: the wall rests on an arch over the river, an iron grate closes the opening
		local springY = water.level + 6.5
		bp:box(len, top - springY, T, 0, (top + springY) / 2, 0, o(WALL_STONE, "shell", { q = true }))
		local bars = math.floor(len / 1.4)
		for i = 0, bars do
			local x = -len / 2 + 0.7 + i * (len - 1.4) / bars
			bp:box(
				0.35,
				springY - water.bed + 1,
				0.35,
				x,
				(springY + water.bed - 1) / 2,
				-T / 2 + 1,
				o(Palette.metal[1], "shell", { q = false })
			)
		end
		for _, y in { water.level + 1, springY - 1.5 } do
			bp:box(len, 0.35, 0.35, 0, y, -T / 2 + 1, o(Palette.metal[1], "shell", { q = false }))
		end
		for _, side in { -1, 1 } do
			bp:add("wedge", T, 3.5, 4, side * (len / 2 - 2), springY + 1.75, 0, 0, side * 90, 180, o(WALL_STONE))
		end
	else
		bp:box(len, top - base, T, 0, (top + base) / 2, 0, o(WALL_STONE, "shell", { q = true }))
	end
	-- coping, merlons on the outer edge, arrow slits, a string course
	bp:box(len + 0.2, 0.6, T + 0.6, 0, top + 0.3, 0, o(WALL_CAP))
	local n = math.max(1, math.floor(len / 3.4))
	for i = 0, n - 1 do
		local x = -len / 2 + (i + 0.5) * len / n
		bp:box(1.9, 2.6, 1.3, x, top + 1.9, -T / 2 + 0.65, o(WALL_STONE))
	end
	for i = 1, math.floor(len / 9) do
		local x = -len / 2 + i * len / (math.floor(len / 9) + 1)
		bp:box(0.5, 2.6, 0.3, x, top - 5, -T / 2 - 0.1, o(SLIT, "detail", { jitter = 0 }))
	end
	bp:box(len, 0.6, 0.5, 0, top - 8, -T / 2 - 0.2, o(WALL_CAP))
	-- inner buttress and creeping ivy on the outside
	if len > 14 then
		local bh = top - lo - 3
		bp:add("wedge", 2.6, bh, 3.4, 0, lo - 0.5 + bh / 2, T / 2 + 1.7, 0, 180, 0, o(WALL_STONE))
	end
	if bp.rng:chance(0.4) then
		local iv = Palette.pick(bp.rng, Palette.moss)
		local ih = bp.rng:float(4, 9)
		bp:box(bp.rng:float(3, 7), ih, 0.3, bp.rng:float(-len / 3, len / 3), lo + ih / 2, -T / 2 - 0.15, o(iv, "fine"))
	end
	return { name = "Wall", bp = bp, at = { x = mx, y = 0, z = mz, rot = rot }, tag = "wall" }
end

local function tower(x: number, z: number, ground: Ground, flag: boolean): Build
	local bp = Blueprint.new(hash(x, z))
	local lo, hi = math.huge, -math.huge
	for _, d in { { 0, 0 }, { 7, 0 }, { -7, 0 }, { 0, 7 }, { 0, -7 } } do
		local h = ground(x + d[1], z + d[2])
		lo, hi = math.min(lo, h), math.max(hi, h)
	end
	local top = math.max(hi, 0) + Structures.WALL_HEIGHT + 6
	local base = lo - 3
	local r = 7.5
	-- vertical cylinder: Roblox cylinders run along local X, turn them up with rz = 90
	bp:add("cyl", top - base, r * 2, r * 2, 0, (top + base) / 2, 0, 0, 0, 90, o(WALL_STONE, "shell", { q = true }))
	bp:add("cyl", 0.8, r * 2 + 1, r * 2 + 1, 0, top - 0.4, 0, 0, 0, 90, o(WALL_CAP))
	bp:add("cyl", 0.6, r * 2 + 0.6, r * 2 + 0.6, 0, top - 9, 0, 0, 0, 90, o(WALL_CAP))
	for i = 0, 9 do
		local a = i * 36
		local ra = math.rad(a)
		bp:rbox(2, 2.8, 1.2, math.sin(ra) * (r - 0.1), top + 1.4, math.cos(ra) * (r - 0.1), 0, a, 0, o(WALL_STONE))
	end
	for i = 0, 3 do
		local ra = math.rad(i * 90 + 45)
		bp:rbox(
			0.5,
			2.6,
			0.4,
			math.sin(ra) * (r + 0.05),
			top - 6,
			math.cos(ra) * (r + 0.05),
			0,
			i * 90 + 45,
			0,
			o(SLIT, "detail", { jitter = 0 })
		)
	end
	if flag then
		bp:add("cyl", 9, 0.35, 0.35, 0, top + 4.5, 0, 0, 0, 90, o(Palette.timber[1]))
		bp:box(4.5, 2.6, 0.12, 2.3, top + 7.4, 0, { c = "#7A2A22", m = "Fabric", lod = "detail", tag = "flag" })
	end
	return { name = "Tower", bp = bp, at = { x = x, y = 0, z = z, rot = 0 }, tag = "tower" }
end

-- Gatehouse: two square towers with steep roofs, a vaulted passage with a raised portcullis and the portal
-- field inside the passage (tag "portal"; the instantiator copies the gate's portal attributes onto it).
local function gatehouse(gate: any, ground: Ground): Build
	local bp = Blueprint.new(hash(gate.x, gate.z))
	local hi = -math.huge
	local lo = math.huge
	for _, d in { { 0, 0 }, { 12, 0 }, { -12, 0 }, { 0, 8 }, { 0, -8 } } do
		local r = math.rad(gate.rot)
		local wx = gate.x + d[1] * math.cos(r) + d[2] * math.sin(r)
		local wz = gate.z - d[1] * math.sin(r) + d[2] * math.cos(r)
		local h = ground(wx, wz)
		hi, lo = math.max(hi, h), math.min(lo, h)
	end
	local floor = math.max(ground(gate.x, gate.z), 0)
	local wallTop = math.max(hi, 0) + Structures.WALL_HEIGHT
	local towerTop = wallTop + 9
	local base = lo - 3
	local pw = 14 -- passage width
	local tw = 10 -- tower width
	local depth = 12
	local look: Parts.Look = {
		timber = Palette.timber[1],
		plaster = Palette.plaster[2],
		planks = Palette.planks[1],
		shutter = Palette.shutter[1],
		door = Palette.door[1],
		stone = WALL_STONE,
		roof = Palette.tiles[2],
	}
	for _, s in { -1, 1 } do
		local cx = s * (pw / 2 + tw / 2)
		bp:box(tw, towerTop - base, depth, cx, (towerTop + base) / 2, 0, o(WALL_STONE, "shell", { q = true }))
		bp:box(tw + 0.8, 0.7, depth + 0.8, cx, towerTop - 0.3, 0, o(WALL_CAP))
		bp:push(cx, 0, 0)
		Parts.roof(bp, look, {
			w = tw + 0.4,
			d = depth + 0.4,
			zc = 0,
			y = towerTop,
			pitch = 58,
			ridgeAlongZ = false,
			eave = 0.8,
			verge = 0.6,
			thick = 0.6,
			roof = Palette.tiles[2],
			gable = WALL_STONE,
			timber = nil,
		})
		bp:pop()
		for _, y in { towerTop - 6, towerTop - 13 } do
			bp:box(0.6, 2.8, 0.3, cx, y, -depth / 2 - 0.1, o(SLIT, "detail", { jitter = 0 }))
		end
		-- torches beside the inner mouth of the passage
		bp:box(0.3, 1.2, 0.3, s * (pw / 2 + 1), floor + 7, depth / 2 + 0.6, o(Palette.metal[1]))
		bp:box(
			0.6,
			0.8,
			0.6,
			s * (pw / 2 + 1),
			floor + 7.9,
			depth / 2 + 0.6,
			{ c = "#FF9A3A", m = "Neon", lod = "detail", tag = "fire" }
		)
		bp:light(s * (pw / 2 + 1), floor + 8.2, depth / 2 + 1.2, "#FF9A50", 18, 1, "lamp")
	end
	-- block over the passage, the arch (two spandrels) and battlements
	local arch = floor + 14
	bp:box(pw, wallTop + 2 - arch, depth, 0, (wallTop + 2 + arch) / 2, 0, o(WALL_STONE, "shell", { q = true }))
	for _, s in { -1, 1 } do
		bp:add("wedge", depth, 3, 3, s * (pw / 2 - 1.5), arch - 1.5, 0, 0, s * 90, 180, o(WALL_STONE))
	end
	for i = 0, 3 do
		bp:box(1.9, 2.6, 1.3, -pw / 2 + 1.75 + i * 3.5, wallTop + 3.3, -depth / 2 + 0.65, o(WALL_STONE))
	end
	-- passage floor and the raised portcullis
	bp:box(pw, 0.6, depth + 2, 0, floor + 0.3 - 0.4, 0, o(Palette.rubble[1], "shell", { q = true }))
	for i = 0, 6 do
		bp:box(0.35, 4, 0.35, -pw / 2 + 1 + i * (pw - 2) / 6, arch + 0.6, -depth / 2 + 1.2, o(Palette.metal[1]))
	end
	for _, y in { arch - 0.8, arch + 1.6 } do
		bp:box(pw - 1, 0.35, 0.35, 0, y, -depth / 2 + 1.2, o(Palette.metal[1]))
	end
	-- portal field fills the passage; collision off, clickable
	bp:box(pw - 0.6, arch - floor - 0.4, 0.5, 0, floor + (arch - floor) / 2, -1, {
		c = "#7A5CFF",
		m = "Neon",
		lod = "shell",
		col = false,
		q = true,
		t = 0.35,
		tag = "portal",
		jitter = 0,
	})
	bp:light(0, floor + 6, -1, "#8A6CFF", 22, 1.2, "portal")
	-- invisible barrier at the outer end of the passage: players never leave the city on foot (the field is the exit)
	bp:box(pw, arch - floor + 6, 0.4, 0, floor + (arch - floor + 6) / 2, -depth / 2 + 0.6, {
		c = "#000000",
		m = "SmoothPlastic",
		lod = "shell",
		col = true,
		q = false,
		t = 1,
		tag = "barrier",
		jitter = 0,
	})
	-- banner over the passage (inside face)
	bp:box(4, 6, 0.15, 0, arch + 4, depth / 2 + 0.2, { c = "#6B2A24", m = "Fabric", lod = "detail", tag = "flag" })
	return {
		name = `Gate_{gate.id}`,
		bp = bp,
		at = { x = gate.x, y = 0, z = gate.z, rot = gate.rot },
		tag = "gate",
		gate = gate,
	}
end

-- Town wall: pieces of at most 24 studs between the wall corners, a round tower on every corner, gatehouses
-- where the gates are and water gates where the river crosses the wall.
function Structures.walls(city: any, ground: Ground): { Build }
	local out: { Build } = {}
	local wall = city.wall
	local river = city.terrain.river
	local n = #wall
	local inside = function(x: number, z: number): boolean
		-- even-odd test against the wall polygon
		local c = false
		local j = n
		for i = 1, n do
			local xi, zi, xj, zj = wall[i][1], wall[i][2], wall[j][1], wall[j][2]
			if (zi > z) ~= (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi then
				c = not c
			end
			j = i
		end
		return c
	end
	for i = 1, n do
		local a, b = wall[i], wall[i % n + 1]
		local ax, az, bx, bz = a[1], a[2], b[1], b[2]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local ux, uz = (bx - ax) / len, (bz - az) / len
		-- make local -Z (front) face out of the city: front of rotOf(u) is (uz, -ux)
		if inside((ax + bx) / 2 + uz * 8, (az + bz) / 2 - ux * 8) then
			ax, az, bx, bz = bx, bz, ax, az
			ux, uz = -ux, -uz
		end
		-- cut points: corners (tower radius), gates, the river
		local cuts: { { number } } = {} -- { from, to, kind } along the segment, kind 0 = wall, 1 = water gate
		local skip: { { number } } = { { 0, 6 }, { len - 6, len } }
		for _, gate in city.gates do
			local d, t = segDist(ax, az, bx, bz, gate.x, gate.z)
			if d < 4 then
				local at = t * len
				table.insert(skip, { at - Structures.GATE_HALF, at + Structures.GATE_HALF })
			end
		end
		table.sort(skip, function(p, q)
			return p[1] < q[1]
		end)
		local cur = 0
		for _, s in skip do
			if s[1] > cur then
				table.insert(cuts, { cur, s[1] })
			end
			cur = math.max(cur, s[2])
		end
		if cur < len then
			table.insert(cuts, { cur, len })
		end
		local riverAt = crossing(ax, az, bx, bz, river.pts)
		for _, c in cuts do
			local from, to = c[1], c[2]
			local spans: { { number } } = {}
			if riverAt and riverAt > from and riverAt < to then
				local w0, w1 = math.max(from, riverAt - 16), math.min(to, riverAt + 16)
				if w0 > from + 1 then
					table.insert(spans, { from, w0, 0 })
				end
				table.insert(spans, { w0, w1, 1 })
				if w1 < to - 1 then
					table.insert(spans, { w1, to, 0 })
				end
			else
				table.insert(spans, { from, to, 0 })
			end
			for _, sp in spans do
				local L = sp[2] - sp[1]
				local pieces = math.max(1, math.ceil(L / 24))
				for k = 0, pieces - 1 do
					local s0 = sp[1] + L * k / pieces
					local s1 = sp[1] + L * (k + 1) / pieces
					table.insert(
						out,
						wallPiece(
							ax + ux * s0,
							az + uz * s0,
							ax + ux * s1,
							az + uz * s1,
							ground,
							if sp[3] == 1 then { bed = river.bed, level = river.water } else nil
						)
					)
				end
			end
		end
	end
	for i, corner in wall do
		local nearGate = false
		for _, gate in city.gates do
			if math.sqrt((gate.x - corner[1]) ^ 2 + (gate.z - corner[2]) ^ 2) < Structures.TOWER_CLEAR then
				nearGate = true
			end
		end
		if not nearGate then
			table.insert(out, tower(corner[1], corner[2], ground, i % 3 == 0))
		end
	end
	for _, gate in city.gates do
		table.insert(out, gatehouse(gate, ground))
	end
	return out
end

-- Retaining walls, castle cliffs and ramp side walls from the plan (Data/Town retaining).
function Structures.retaining(city: any, ground: Ground): { Build }
	local out: { Build } = {}
	for _, w in city.retaining do
		local ax, az, bx, bz = w.a[1], w.a[2], w.b[1], w.b[2]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		if len >= 0.5 then
			local ux, uz = (bx - ax) / len, (bz - az) / len
			local mx, mz = (ax + bx) / 2, (az + bz) / 2
			-- local -Z must face the low side
			local nx, nz = uz, -ux
			if ground(mx + nx * 4, mz + nz * 4) > ground(mx - nx * 4, mz - nz * 4) then
				ux, uz = -ux, -uz
			end
			local bp = Blueprint.new(hash(mx, mz))
			local h = w.top - w.bottom
			local L = len + 1.2
			if w.kind == "cliff" then
				local rock: Swatch = { c = "#5C5752", m = "Rock" }
				bp:box(L, h, 3, 0, (w.top + w.bottom) / 2, 0, o(rock, "shell", { q = true }))
				for _ = 1, 3 do
					local s = bp.rng:float(2.5, 5)
					bp:rbox(
						s,
						s * bp.rng:float(0.6, 1.2),
						s,
						bp.rng:float(-L / 2, L / 2),
						w.bottom + bp.rng:float(1, h * 0.7),
						-1.5 - s * 0.2,
						bp.rng:float(-20, 20),
						bp.rng:float(0, 90),
						bp.rng:float(-20, 20),
						o(rock, "detail", { jitter = 0.08 })
					)
				end
			else
				bp:box(L, h, 2.5, 0, (w.top + w.bottom) / 2, 0, o(WALL_STONE, "shell", { q = true }))
				bp:box(L + 0.3, 0.5, 3.1, 0, w.top + 0.25, 0, o(WALL_CAP))
				if h > 7 then
					for i = 1, math.floor(L / 8) do
						local x = -L / 2 + i * L / (math.floor(L / 8) + 1)
						bp:add("wedge", 1.8, h - 3, 2, x, w.bottom + (h - 3) / 2, -2.25, 0, 0, 0, o(WALL_STONE))
					end
				end
				if bp.rng:chance(0.35) then
					local iv = Palette.pick(bp.rng, Palette.moss)
					local ih = bp.rng:float(2, math.max(2.5, h * 0.6))
					bp:box(
						bp.rng:float(2, 5),
						ih,
						0.3,
						bp.rng:float(-L / 3, L / 3),
						w.top - ih / 2,
						-1.4,
						o(iv, "fine")
					)
				end
			end
			table.insert(out, {
				name = "Retaining",
				bp = bp,
				at = { x = mx, y = 0, z = mz, rot = rotOf(ux, uz) },
				tag = "retaining",
			})
		end
	end
	return out
end

-- Paved surfaces of the ramps and the steps of the grand stairs.
function Structures.ramps(city: any): { Build }
	local out: { Build } = {}
	for _, ramp in city.terrain.ramps do
		local pts = ramp.pts
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local dx, dz, dy = b[1] - a[1], b[2] - a[2], b[3] - a[3]
			local run = math.sqrt(dx * dx + dz * dz)
			local mx, mz, my = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2
			local bp = Blueprint.new(hash(mx, mz))
			local stone = Palette.rubble[2]
			if ramp.stairs then
				local steps = math.max(2, math.floor(math.abs(dy) / 0.4 + 0.5))
				local tread = run / steps
				for k = 1, steps do
					local top = a[3] + dy * k / steps
					local x = -run / 2 + (k - 0.5) * tread
					bp:box(
						tread + 0.05,
						top - a[3] + 1,
						ramp.w,
						x,
						(top + a[3] - 1) / 2,
						0,
						o(Palette.ashlar[1], "shell", { q = true })
					)
				end
			else
				local len = math.sqrt(run * run + dy * dy)
				local pitch = math.deg(math.atan2(dy, run))
				bp:rbox(len + 1, 0.8, ramp.w, 0, my - 0.3, 0, 0, 0, pitch, o(stone, "shell", { q = true }))
			end
			-- landing slab at the top of every segment
			bp:box(ramp.w, 0.8, ramp.w, run / 2, b[3] - 0.35, 0, o(stone, "shell", { q = true }))
			table.insert(out, {
				name = `Ramp_{ramp.id}`,
				bp = bp,
				at = { x = mx, y = 0, z = mz, rot = rotOf(dx / run, dz / run) },
				tag = "ramp",
			})
		end
	end
	return out
end

-- Stone or timber bridges over the river.
function Structures.bridges(city: any, ground: Ground): { Build }
	local out: { Build } = {}
	local river = city.terrain.river
	for _, b in city.bridges do
		local bp = Blueprint.new(hash(b.x, b.z))
		local r = math.rad(b.rot)
		-- local Z runs along the bridge; ends at +-len/2
		local function endGround(s: number): number
			return ground(b.x + s * (b.len / 2) * math.sin(r), b.z + s * (b.len / 2) * math.cos(r))
		end
		local deck = math.max(endGround(-1), endGround(1), river.water + 1.5) + 0.2
		if b.kind == "stone" then
			local stone = Palette.ashlar[2]
			bp:box(b.w, 1.4, b.len, 0, deck - 0.7, 0, o(stone, "shell", { q = true }))
			for _, s in { -1, 1 } do
				bp:box(1, 1.6, b.len, s * (b.w / 2 - 0.5), deck + 0.8, 0, o(stone, "shell", { q = true }))
				bp:box(1.4, 0.3, b.len + 0.2, s * (b.w / 2 - 0.5), deck + 1.75, 0, o(Palette.ashlar[1]))
				-- piers with cutwaters
				bp:box(b.w, deck - river.bed, 3, 0, (deck + river.bed) / 2 - 1.4, s * b.len / 5, o(stone, "shell"))
				bp:add(
					"wedge",
					b.w * 0.6,
					4,
					3,
					s * (b.w / 2 + 1.2),
					river.water + 1,
					s * b.len / 5,
					0,
					s * -90,
					0,
					o(stone)
				)
				-- lamp posts at the bridge ends
				bp:add(
					"cyl",
					6,
					0.5,
					0.5,
					s * (b.w / 2 - 0.5),
					deck + 4.5,
					s * (b.len / 2 - 1),
					0,
					0,
					90,
					o(Palette.metal[1])
				)
				bp:box(
					1,
					1.2,
					1,
					s * (b.w / 2 - 0.5),
					deck + 8,
					s * (b.len / 2 - 1),
					{ c = "#FFD08A", m = "Neon", lod = "detail", t = 0.15, tag = "lamp" }
				)
				bp:light(s * (b.w / 2 - 0.5), deck + 8, s * (b.len / 2 - 1), "#FFB860", 16, 0.8, "lamp")
			end
			-- arch faces (visual) between the piers
			for _, face in { -1, 1 } do
				bp:add(
					"wedge",
					1,
					2.5,
					b.len / 5,
					face * (b.w / 2 - 0.5),
					deck - 2.6,
					-b.len / 10,
					0,
					180,
					180,
					o(stone)
				)
				bp:add("wedge", 1, 2.5, b.len / 5, face * (b.w / 2 - 0.5), deck - 2.6, b.len / 10, 0, 0, 180, o(stone))
			end
		else
			local plank = Palette.greyPlanks[1]
			bp:box(b.w, 0.6, b.len, 0, deck - 0.3, 0, o(plank, "shell", { q = true }))
			local posts = math.floor(b.len / 6)
			for i = 0, posts do
				local z = -b.len / 2 + i * b.len / posts
				for _, s in { -1, 1 } do
					bp:add(
						"cyl",
						deck - river.bed + 3,
						0.8,
						0.8,
						s * (b.w / 2 - 0.3),
						(deck + river.bed + 3) / 2,
						z,
						0,
						0,
						90,
						o(Palette.timber[2], "shell")
					)
				end
			end
			for _, s in { -1, 1 } do
				bp:box(0.4, 0.4, b.len, s * (b.w / 2 - 0.3), deck + 2.6, 0, o(Palette.timber[2], "shell", { q = true }))
				bp:box(0.3, 0.3, b.len, s * (b.w / 2 - 0.3), deck + 1.4, 0, o(Palette.timber[2]))
			end
		end
		table.insert(
			out,
			{ name = `Bridge_{b.id}`, bp = bp, at = { x = b.x, y = 0, z = b.z, rot = b.rot }, tag = "bridge" }
		)
	end
	return out
end

-- Street lamps: iron post with an arm and a lantern (tag "lamp" + a light the client switches on at night).
function Structures.lamps(city: any, ground: Ground): { Build }
	local out: { Build } = {}
	for _, l in city.lamps do
		local y = ground(l.x, l.z)
		local bp = Blueprint.new(hash(l.x, l.z))
		local hgt = if l.kind == "rampLantern" then 6 else 9
		bp:box(1.2, 0.6, 1.2, 0, 0.3, 0, o(Palette.slate[1], "shell"))
		bp:add("cyl", hgt, 0.45, 0.45, 0, hgt / 2, 0, 0, 0, 90, o(Palette.metal[1], "shell", { q = false }))
		bp:box(2, 0.25, 0.25, 0.9, hgt - 0.3, 0, o(Palette.metal[1]))
		bp:box(0.9, 1.2, 0.9, 1.7, hgt - 1.3, 0, { c = "#FFD08A", m = "Neon", lod = "detail", t = 0.15, tag = "lamp" })
		bp:box(1.2, 0.3, 1.2, 1.7, hgt - 0.6, 0, o(Palette.metal[1]))
		bp:light(1.7, hgt - 1.3, 0, "#FFB860", 16, 0.8, "lamp")
		table.insert(
			out,
			{ name = "Lamp", bp = bp, at = { x = l.x, y = y, z = l.z, rot = bp.rng:float(0, 360) }, tag = "lamp" }
		)
	end
	return out
end

return Structures
