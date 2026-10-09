--!strict
-- Cave engine (S48): the rock, floor, ceiling and liquids of a cave or boss chamber from Data/CaveShapes and the room
-- plan (Data/Areas/Caves rooms, or Logic/CaveGen from the seed of a generated cave). Pure (Lune). Column model:
-- every column (x, z) has at most one gap of air between `floor` and `ceiling`; outside it is rock. Read by the
-- server (World/CaveTerrainWriter, ground lookups through Logic/MapTerrain), Logic/AreaSpawns (the spawners' y),
-- the dressing (Logic/CaveDress), the client (decorations, moods, lights) and the tools.
--
-- `CaveTerrain.get(mapId)` (cached, lazy: no grid is computed up front) returns nil for maps without a shape, else:
--   floor(x, z), ceiling(x, z)        surfaces (nil = rock)
--   solid(x, y, z), material(x, y, z)
--   liquid(x, z)                      { kind = "water" | "lava" | "ice", level } or nil
--   walkable(x, z, r?)                floor, dry (ice is fine), <= 32 degrees within r, at least 12 studs of headroom
--   headroom(x, z)                    ceiling - floor (0 in rock)
--   roomAt(x, z)                      index of the room (plan rooms first, then extraRooms) or nil in tunnels and rock
--   rooms                             every room { x, z, r, h, role, fight, core, ... } in that order
--   voxels(x0, z0, nx, nz, yBottom, ny), outline(step), MATERIALS, HALF, VOXEL, BOTTOM, TOP
-- Does not require Logic/AreaSpawns (AreaSpawns -> MapTerrain -> CaveTerrain).

local CaveGen = require("./CaveGen")
local CaveShapes = require("../Data/CaveShapes")
local Caves = require("../Data/Areas/Caves")
local TerrainLayers = require("./TerrainLayers")

local fbm = TerrainLayers.fbm
local smoothstep = TerrainLayers.smoothstep
local lerp = TerrainLayers.lerp

local CaveTerrain = {}

CaveTerrain.VOXEL = 4
CaveTerrain.BOTTOM = -24
CaveTerrain.WALKABLE_SLOPE = math.tan(math.rad(32))
CaveTerrain.HEADROOM = 12
CaveTerrain.CORE_SCALE = 0.65 -- core radius = 0.65 r + 8 (the spawn area of Logic/AreaSpawns.cave plus a margin)
CaveTerrain.CORE_PAD = 8

local SKY = 1e4 -- ceiling of a column open to the sky

export type Room = {
	x: number,
	z: number,
	r: number,
	h: number,
	role: string,
	decor: string?,
	dy: number,
	floor: string?,
	flat: boolean,
	fight: boolean,
	core: number, -- radius of the core (0: none)
	seed: number,
	-- S49: architecture (round = the S48 natural room)
	plan: string, -- "round" | "rect" | "octagon"
	hx: number, -- rect half sizes (along x and z before `rot`)
	hz: number,
	rot: number, -- degrees
	ceil: string?, -- "vault" | "corbel" | "dome" (default dome; `flat` keeps the S48 flat ceiling)
}

export type Liquid = { kind: string, level: number }

export type Column = {
	open: boolean,
	floor: number,
	ceiling: number,
	liquid: Liquid?,
	floorMat: string,
	room: number?,
}

export type Cave = {
	mapId: string,
	shape: CaveShapes.Shape,
	rooms: { Room },
	floor: (x: number, z: number) -> number?,
	ceiling: (x: number, z: number) -> number?,
	solid: (x: number, y: number, z: number) -> boolean,
	material: (x: number, y: number, z: number) -> string,
	liquid: (x: number, z: number) -> Liquid?,
	walkable: (x: number, z: number, r: number?) -> boolean,
	headroom: (x: number, z: number) -> number,
	roomAt: (x: number, z: number) -> number?,
	column: (x: number, z: number) -> Column,
	voxels: (x0: number, z0: number, nx: number, nz: number, yBottom: number, ny: number) -> TerrainLayers.Voxels,
	outline: (step: number) -> { { x: number, z: number, w: number, d: number } },
	inCore: (x: number, z: number) -> boolean,
	niches: () -> { { x: number, z: number, yaw: number, room: number, tiers: number, w: number, h: number } },
	MATERIALS: { string },
	HALF: number,
	VOXEL: number,
	BOTTOM: number,
	TOP: number,
}

local cache: { [string]: Cave } = {}

-- Sizes of the maps on the engine (Data/Maps; kept here to avoid requiring the map list from pure logic).
local function halfOf(mapId: string): number
	if string.sub(mapId, 1, 8) == "dungeon_" then
		return 150
	end
	local cave = Caves.get(mapId)
	if cave and cave.rooms then
		return 320
	end
	return CaveGen.SIZE / 2
end

local function seedOf(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 1000003
	end
	return h
end

-- Distance from (x, z) to the segment a-b and the parameter t (0..1) of the nearest point.
local function segment(ax: number, az: number, bx: number, bz: number, x: number, z: number): (number, number, number)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) else 0
	local px, pz = ax + dx * t, az + dz * t
	-- signed side (left of a->b positive)
	local side = dx * (z - az) - dz * (x - ax)
	return math.sqrt((x - px) ^ 2 + (z - pz) ^ 2), t, if side >= 0 then 1 else -1
end

local function build(mapId: string, shape: CaveShapes.Shape): Cave
	local SEED = seedOf(mapId)
	local F = shape.floorY or 0
	local mats = shape.materials
	local wallAmp, wallScale = shape.wall.amp, shape.wall.scale
	local ceilAmp, ceilScale = shape.ceiling.amp, shape.ceiling.scale
	local tunnelH = shape.tunnelH or 14
	local masonry = shape.masonry == true -- S49: straight vaulted corridors of constant width
	local wiggle = if masonry then 0 else shape.wiggle or 6

	-- Rooms: the plan's, then the extra rooms, then the niches (small rooms behind the walls).
	local cave = Caves.get(mapId)
	local rooms: { Room } = {}
	local corridors: { CaveShapes.Tunnel } = {}
	if cave then
		local planRooms
		if cave.rooms then
			planRooms = cave.rooms
		else
			local plan = CaveGen.generate(cave.seed or 1)
			planRooms = plan.rooms
			for _, c in plan.corridors do
				table.insert(corridors, { ax = c.ax, az = c.az, bx = c.bx, bz = c.bz, w = c.w })
			end
		end
		local last = if cave.boss then #planRooms - 1 else #planRooms
		for i, r in planRooms do
			local rs = (shape.rooms or {})[i]
			local fight = i >= 2 and i <= last
			table.insert(rooms, {
				x = r.x,
				z = r.z,
				r = r.r,
				h = if rs and rs.h then rs.h else r.h,
				role = if rs then rs.role else (if i == 1 then "entrance" else "room"),
				decor = rs and rs.decor,
				dy = rs and rs.dy or 0,
				floor = rs and rs.floor,
				flat = rs ~= nil and rs.flat == true,
				fight = fight,
				core = if fight then r.r * CaveTerrain.CORE_SCALE + CaveTerrain.CORE_PAD else 0,
				seed = SEED + i * 17,
				plan = rs and rs.plan or "round",
				hx = rs and rs.hx or r.r,
				hz = rs and rs.hz or r.r,
				rot = rs and rs.rot or 0,
				ceil = rs and rs.ceil,
			})
		end
	end
	for i, e in shape.extraRooms or {} :: { CaveShapes.ExtraRoom } do
		table.insert(rooms, {
			x = e.x,
			z = e.z,
			r = e.r,
			h = e.h,
			role = e.role,
			decor = e.decor,
			dy = e.dy or 0,
			floor = e.floor,
			flat = e.flat == true,
			fight = false,
			-- the arena of a chamber keeps a core too: nothing collidable within 50 studs of the fight (its floor is
			-- flat anyway: arenas have no floor noise)
			core = if e.role == "arena" then 50 else 0,
			seed = SEED + 500 + i * 17,
			plan = e.plan or "round",
			hx = e.hx or e.r,
			hz = e.hz or e.r,
			rot = e.rot or 0,
			ceil = e.ceil,
		})
	end
	local nRooms = #rooms
	for i, f in shape.features do
		if f.kind == "niche" then
			table.insert(rooms, {
				x = f.x,
				z = f.z,
				r = f.r,
				h = f.h,
				role = "niche",
				dy = f.dy or 0,
				flat = false,
				fight = false,
				core = 0,
				seed = SEED + 900 + i * 17,
				plan = f.plan or "round",
				hx = f.hx or f.r,
				hz = f.hz or f.r,
				rot = f.rot or 0,
				ceil = f.ceil,
			})
		end
	end
	for _, t in shape.tunnels or {} :: { CaveShapes.Tunnel } do
		table.insert(corridors, t)
	end

	-- Floor of the room an end of a tunnel lies in (the tunnel's floor blends between them).
	local function roomFloorAt(x: number, z: number): number
		local best, bestD = F, math.huge
		for _, r in rooms do
			local d = math.sqrt((x - r.x) ^ 2 + (z - r.z) ^ 2) - r.r
			if d < bestD then
				best, bestD = F + r.dy, d
			end
		end
		return best
	end
	type TunnelData = { t: CaveShapes.Tunnel, fa: number, fb: number, len: number, h: number, seed: number }
	local tunnels: { TunnelData } = {}
	for i, t in corridors do
		table.insert(tunnels, {
			t = t,
			fa = roomFloorAt(t.ax, t.az),
			fb = roomFloorAt(t.bx, t.bz),
			len = math.sqrt((t.bx - t.ax) ^ 2 + (t.bz - t.az) ^ 2),
			h = t.h or tunnelH,
			seed = SEED + 300 + i * 13,
		})
	end

	local features = shape.features
	local streams: { { line: TerrainLayers.Line, f: CaveShapes.Feature } } = {}
	for _, f in features do
		if f.kind == "stream" then
			table.insert(streams, { line = TerrainLayers.line(TerrainLayers.pairs(f.points)), f = f })
		end
	end

	local maxH = 0
	for _, r in rooms do
		maxH = math.max(maxH, r.h + r.dy)
	end
	local TOP = math.ceil((F + maxH + 14) / 4) * 4
	local HALF = halfOf(mapId)

	-- Core of a fighting room (and of an arena) at a point.
	local function inCore(x: number, z: number): boolean
		for _, r in rooms do
			if r.core > 0 then
				local dx, dz = x - r.x, z - r.z
				if dx * dx + dz * dz < r.core * r.core then
					return true
				end
			end
		end
		return false
	end

	-- One room's contribution: openness 0..1, floor, ceiling.
	-- S49: an architectural room (rect or octagon): straight walls without noise, a short wall zone (near-vertical
	-- walls), ceiling profiles vault / corbel / dome / flat. `depth` = distance from the point to the nearest wall.
	local function archPart(r: Room, x: number, z: number): (number, number, number)
		local dx, dz = x - r.x, z - r.z
		local reach = math.max(r.hx, r.hz) * 1.5 + 2
		if math.abs(dx) > reach or math.abs(dz) > reach then
			return 0, 0, 0
		end
		local a = math.rad(r.rot)
		local lx = dx * math.cos(a) - dz * math.sin(a)
		local lz = dx * math.sin(a) + dz * math.cos(a)
		local depth, inradius
		if r.plan == "rect" then
			depth = math.min(r.hx - math.abs(lx), r.hz - math.abs(lz))
			inradius = math.min(r.hx, r.hz)
		else
			local m = math.max(math.abs(lx), math.abs(lz), (math.abs(lx) + math.abs(lz)) / math.sqrt(2))
			depth = r.r - m
			inradius = r.r
		end
		if depth <= 0 then
			return 0, 0, 0
		end
		local edge = 2.5
		local o = if depth >= edge then 1 else smoothstep(depth / edge)
		local base = F + r.dy
		local fl = base + (1 - o) * 4
		local h = r.h
		local dome
		local kind = if r.flat then "flat" else (r.ceil or "dome")
		if kind == "flat" then
			dome = h
		elseif kind == "vault" then
			-- a barrel vault along the longer axis: the ceiling rises in an arc from the side walls to the ridge
			local half = if r.plan == "rect" then math.min(r.hx, r.hz) else r.r
			local lateral = if r.plan == "rect" and r.hx < r.hz then math.abs(lx) else math.abs(lz)
			local u = math.clamp(lateral / half, 0, 1)
			dome = h * (0.55 + 0.45 * math.sqrt(1 - u * u))
		elseif kind == "corbel" then
			-- a corbelled vault: the ceiling rises in steps of 4 studs towards the middle (a beehive dome)
			local t = math.clamp(1 - depth / inradius, 0, 1)
			local rise = (h * 0.45) * (1 - t)
			dome = h * 0.55 + math.floor(rise / 4 + 0.5) * 4
		else
			local t = math.clamp(1 - depth / inradius, 0, 1)
			dome = h * (1 - 0.4 * t * t)
		end
		local gap = math.max(0, dome) * o ^ 0.6
		return o, fl, fl + gap
	end

	local function roomPart(r: Room, x: number, z: number): (number, number, number)
		if r.plan ~= "round" then
			return archPart(r, x, z)
		end
		local dx, dz = x - r.x, z - r.z
		local reach = r.r + wallAmp * 1.6 + 1
		if math.abs(dx) > reach or math.abs(dz) > reach then
			return 0, 0, 0
		end
		local d = math.sqrt(dx * dx + dz * dz)
		local a = math.atan2(dz, dx)
		-- the wall bulges out by 0..1.6 amp (never in: the plan's room stays open)
		local n = fbm(r.x + math.cos(a) * 60, r.z + math.sin(a) * 60, wallScale, r.seed, 3)
		local R = r.r + wallAmp * math.clamp(0.5 + (n - 0.5) * 3.2, 0, 1.6)
		if d >= R then
			return 0, 0, 0
		end
		-- the wall zone (floor rising, ceiling falling) never reaches into the core
		local edgeStart = math.max(R - math.min(10, r.r * 0.3), r.core + 1)
		local edge = math.max(R - edgeStart, 1)
		local o = if d <= edgeStart then 1 else 1 - smoothstep((d - edgeStart) / edge)
		local base = F + r.dy
		local inside = r.core > 0 and d < r.core
		local fl = base + (1 - o) * 6
		if not inside and r.role ~= "entrance" and r.role ~= "antechamber" and r.role ~= "arena" then
			fl += 1.4 * (fbm(x, z, 14, r.seed + 3, 2) - 0.5) * 2 * math.min(1, (d - r.core) / 8 + 0.5)
		end
		local dome
		if r.flat then
			dome = r.h
		else
			dome = r.h * (1 - 0.4 * (d / R) ^ 2)
			if not inside then
				dome += ceilAmp * (fbm(x, z, ceilScale, r.seed + 5, 2) - 0.5) * 2
			end
		end
		local gap = math.max(0, dome) * o ^ 0.6
		return o, fl, fl + gap
	end

	local function tunnelPart(td: TunnelData, x: number, z: number): (number, number, number)
		local t = td.t
		local pad = t.w / 2 + wiggle + 4
		if
			x < math.min(t.ax, t.bx) - pad
			or x > math.max(t.ax, t.bx) + pad
			or z < math.min(t.az, t.bz) - pad
			or z > math.max(t.az, t.bz) + pad
		then
			return 0, 0, 0
		end
		local d, s, side = segment(t.ax, t.az, t.bx, t.bz, x, z)
		if s <= 0 or s >= 1 then
			-- past the ends the rooms take over
			if d > t.w / 2 then
				return 0, 0, 0
			end
		end
		local along = s * td.len
		local w = wiggle * math.clamp((fbm(along, td.seed, 36, td.seed, 2) - 0.5) * 4, -1, 1) * math.sin(math.pi * s)
		-- distance from the winding centre line (w = its sideways shift)
		local p = math.abs(side * d - w)
		if masonry then
			local half = t.w / 2
			if p >= half then
				return 0, 0, 0
			end
			local o = if p <= half - 1.5 then 1 else smoothstep((half - p) / 1.5)
			local fl = lerp(td.fa, td.fb, s) + (1 - o) * 3
			local u = math.clamp(p / half, 0, 1)
			local h = td.h * (0.7 + 0.3 * math.sqrt(1 - u * u))
			return o, fl, fl + h * o ^ 0.6
		end
		local half = t.w / 2 * (0.88 + 0.24 * fbm(x, z, 16, td.seed + 1, 2))
		if p >= half then
			return 0, 0, 0
		end
		local o = if p <= half - 3 then 1 else 1 - smoothstep((p - (half - 3)) / 3)
		local fl = lerp(td.fa, td.fb, smoothstep(s)) + (1 - o) * 3
		local h = td.h + 1.5 * (fbm(x, z, 20, td.seed + 2, 2) - 0.5) * 2
		return o, fl, fl + h * o ^ 0.6
	end

	-- Cones on a jittered grid inside a circle (stalagmites / stalactites): height at a point.
	local function cones(f: CaveShapes.Feature, x: number, z: number, height: number, seed: number): number
		local sp = f.spacing
		local gx, gz = math.floor(x / sp), math.floor(z / sp)
		local best = 0
		for i = -1, 1 do
			for k = -1, 1 do
				local cx, cz = gx + i, gz + k
				local jx = (cx + 0.2 + 0.6 * TerrainLayers.hash(cx, cz, seed)) * sp
				local jz = (cz + 0.2 + 0.6 * TerrainLayers.hash(cx, cz, seed + 1)) * sp
				if (jx - f.x) ^ 2 + (jz - f.z) ^ 2 < f.r * f.r then
					local rr = sp * (0.25 + 0.2 * TerrainLayers.hash(cx, cz, seed + 2))
					local d = math.sqrt((x - jx) ^ 2 + (z - jz) ^ 2)
					if d < rr then
						local hh = height * (0.5 + TerrainLayers.hash(cx, cz, seed + 3))
						best = math.max(best, hh * (1 - d / rr) ^ 1.4)
					end
				end
			end
		end
		return best
	end

	local function streamAt(x: number, z: number): (number, number, CaveShapes.Feature?)
		for _, st in streams do
			local f = st.f
			local d, s = TerrainLayers.nearest(st.line, x, z)
			local half = f.width / 2 * (0.85 + 0.3 * fbm(x, z, 12, SEED + 41, 2))
			if d < half + 2 then
				local level = f.level - f.drop * (s / st.line.length)
				return d - half, level, f
			end
		end
		return math.huge, 0, nil
	end

	-- S49: dry causeways across liquids.
	local onCauseway: (x: number, z: number) -> boolean
	local causeways: { { line: TerrainLayers.Line, half: number } } = {}
	for _, f in features do
		if f.kind == "causeway" then
			table.insert(causeways, { line = TerrainLayers.line(TerrainLayers.pairs(f.points)), half = f.width / 2 })
		end
	end
	onCauseway = function(x: number, z: number): boolean
		for _, c in causeways do
			if (TerrainLayers.nearest(c.line, x, z)) < c.half then
				return true
			end
		end
		return false
	end

	-- The column at (x, z).
	local function column(x: number, z: number): Column
		local open, fl, ce = 0, math.huge, -math.huge
		local best, room = 0, nil :: number?
		for i, r in rooms do
			local o, f, c = roomPart(r, x, z)
			if o > 0 then
				open = math.max(open, o)
				if o > 0.02 then
					fl = math.min(fl, f)
					ce = math.max(ce, c)
				end
				if i <= nRooms and o > best then
					best, room = o, i
				end
			end
		end
		for _, td in tunnels do
			local o, f, c = tunnelPart(td, x, z)
			if o > 0 then
				open = math.max(open, o)
				if o > 0.02 then
					fl = math.min(fl, f)
					ce = math.max(ce, c)
				end
			end
		end
		local liquid: Liquid? = nil
		local floorMat = mats.floor
		if room then
			local fm = rooms[room :: number].floor
			if fm then
				floorMat = fm
			end
		end
		-- a stream carves its own channel
		local sd, sLevel, sf = streamAt(x, z)
		if sf and sd < 0 then
			local bed = sLevel - sf.depth
			if open <= 0.02 then
				open, fl, ce = 1, bed, sLevel + 9
			else
				fl = math.min(fl, bed)
				ce = math.max(ce, sLevel + 9)
			end
			liquid = { kind = sf.liquid or "water", level = sLevel }
			floorMat = mats.bed
		elseif sf and sd < 2 and open > 0.02 then
			fl = math.min(fl, sLevel + 0.4 + sd * 0.3)
			floorMat = mats.bed
		end
		if open <= 0.02 or fl == math.huge then
			return { open = false, floor = 0, ceiling = 0, floorMat = mats.wall, room = nil }
		end
		local core = inCore(x, z)
		for _, f in features do
			local kind = f.kind
			if kind == "pool" and not core then
				local dx, dz = x - f.x, z - f.z
				if math.abs(dx) < f.r + 8 and math.abs(dz) < f.r + 8 then
					local d = math.sqrt(dx * dx + dz * dz) + (f.ragged or 0) * (fbm(x, z, 10, SEED + 51, 2) - 0.5) * 2
					-- S49: a ring of water (`inner`): dry inside, the shore slopes in towards the middle
					local inner = f.inner or 0
					if inner > 0 and d < inner then
						if d > inner - 6 and not onCauseway(x, z) then
							fl = math.min(fl, lerp(fl, f.level + 0.2, smoothstep((d - (inner - 6)) / 6)))
						end
					elseif onCauseway(x, z) then
						-- a dry causeway across the water
						fl = math.min(fl, f.level + 0.6)
					elseif d < f.r then
						local bed = f.level - f.depth * (1 - (d / f.r) ^ 2) - 0.4
						fl = math.min(fl, bed)
						liquid = { kind = f.liquid or "water", level = f.level }
						floorMat = mats.bed
					elseif d < f.r + 6 then
						-- the shore slopes down to the water
						fl = math.min(fl, lerp(f.level + 0.2, fl, smoothstep((d - f.r) / 6)))
						if mats.moss and d < f.r + 4 then
							floorMat = mats.moss
						end
					end
				end
			elseif (kind == "terrace" or kind == "pit") and not core then
				local dx, dz = x - f.x, z - f.z
				if math.abs(dx) < f.r and math.abs(dz) < f.r then
					local d = math.sqrt(dx * dx + dz * dz)
					-- S49: a ring terrace (`inner`) with gaps (`gaps` = { { fromDeg, toDeg } }, 0 = +x, 90 = +z)
					local skip = f.inner ~= nil and d < f.inner
					if not skip and f.gaps then
						local deg = math.deg(math.atan2(dz, dx)) % 360
						for _, g in f.gaps do
							local a0, a1 = g[1] % 360, g[2] % 360
							if (a0 <= a1 and deg >= a0 and deg <= a1) or (a0 > a1 and (deg >= a0 or deg <= a1)) then
								skip = true
							end
						end
					end
					if d < f.r and not skip then
						local w = if d <= f.r - f.blend then 1 else 1 - smoothstep((d - (f.r - f.blend)) / f.blend)
						if f.inner then
							w = math.min(w, if d >= f.inner + f.blend then 1 else smoothstep((d - f.inner) / f.blend))
						end
						if kind == "terrace" then
							fl += f.dy * w
						else
							fl -= math.min(f.depth, 8) * w
						end
					end
				end
			elseif kind == "pillar" then
				local dx, dz = x - f.x, z - f.z
				if dx * dx + dz * dz < f.r * f.r then
					return { open = false, floor = 0, ceiling = 0, floorMat = mats.wall, room = nil }
				end
			elseif kind == "stalagmites" and not core then
				if math.abs(x - f.x) < f.r + 8 and math.abs(z - f.z) < f.r + 8 then
					fl += cones(f, x, z, f.height, SEED + 61)
				end
			elseif kind == "stalactites" and not core then
				if math.abs(x - f.x) < f.r + 8 and math.abs(z - f.z) < f.r + 8 then
					ce -= cones(f, x, z, f.length, SEED + 71)
				end
			elseif kind == "chimney" then
				-- S49: the ceiling raised over a point (a shaft over a well)
				local dx, dz = x - f.x, z - f.z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < f.r then
					ce = math.max(ce, fl + f.h * (1 - (d / f.r) ^ 2 * 0.3))
				end
			elseif kind == "dais" and not core then
				-- S49: a podium `h` studs high with stairs on one side (`dir`: degrees, 0 = +x, 90 = +z), steps of <= 2
				-- studs every 4 studs; the other sides drop straight
				local dx, dz = x - f.x, z - f.z
				local d = math.sqrt(dx * dx + dz * dz)
				local run = math.ceil(f.h / 2) * 4
				if d < f.r then
					fl += f.h
				elseif d < f.r + run then
					local b = math.rad(f.dir or 0)
					local along = (dx * math.cos(b) + dz * math.sin(b)) / math.max(d, 0.01)
					if along > 0.8 then
						local steps = math.ceil(f.h / 2)
						local k = math.floor((d - f.r) / 4)
						fl += f.h * (1 - (k + 1) / (steps + 1))
					end
				end
			elseif kind == "ring" then
				-- S49: a mosaic in the floor material: bands round a centre and spokes
				local dx, dz = x - f.x, z - f.z
				local d = math.sqrt(dx * dx + dz * dz)
				for _, band in f.bands or {} do
					if d >= band[1] and d <= band[2] then
						floorMat = band[3]
					end
				end
				local sp = f.spokes
				if sp and d >= (sp.from or 0) and d <= (sp.to or math.huge) then
					local a = math.atan2(dz, dx)
					local sector = 2 * math.pi / sp.n
					local off = math.abs(((a + sector / 2) % sector) - sector / 2) * d
					if off < sp.width / 2 then
						floorMat = sp.material
					end
				end
			elseif kind == "skyhole" then
				local dx, dz = x - f.x, z - f.z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < f.r then
					ce = SKY
				end
			end
		end
		if ce - fl < 1.5 then
			return { open = false, floor = 0, ceiling = 0, floorMat = mats.wall, room = nil }
		end
		-- moss on ledges and by the water in mossy caves
		if mats.moss and floorMat == mats.floor and liquid == nil then
			local n = fbm(x, z, 18, SEED + 81, 2)
			if n > 0.62 then
				floorMat = mats.moss
			end
		end
		return { open = true, floor = fl, ceiling = ce, liquid = liquid, floorMat = floorMat, room = room }
	end

	local T = {} :: Cave
	T.mapId = mapId
	T.shape = shape
	T.rooms = rooms
	T.HALF = HALF
	T.VOXEL = CaveTerrain.VOXEL
	T.BOTTOM = CaveTerrain.BOTTOM
	T.TOP = TOP
	T.column = column
	T.inCore = inCore

	local matSet: { [string]: boolean } = { Water = true, Air = true }
	for _, m in { mats.wall, mats.floor, mats.accent, mats.bed, mats.moss or mats.floor } :: { string } do
		if m then
			matSet[m] = true
		end
	end
	for _, r in rooms do
		if r.floor then
			matSet[r.floor] = true
		end
	end
	for _, f in features do
		if f.kind == "ring" then
			for _, band in f.bands or {} do
				matSet[band[3]] = true
			end
			if f.spokes then
				matSet[f.spokes.material] = true
			end
		end
	end
	local list = {}
	for m in matSet do
		table.insert(list, m)
	end
	table.sort(list)
	T.MATERIALS = list

	function T.floor(x: number, z: number): number?
		local c = column(x, z)
		return if c.open then c.floor else nil
	end

	function T.ceiling(x: number, z: number): number?
		local c = column(x, z)
		return if c.open then c.ceiling else nil
	end

	function T.liquid(x: number, z: number): Liquid?
		return column(x, z).liquid
	end

	function T.headroom(x: number, z: number): number
		local c = column(x, z)
		return if c.open then c.ceiling - c.floor else 0
	end

	function T.solid(x: number, y: number, z: number): boolean
		local c = column(x, z)
		return not c.open or y < c.floor or y > c.ceiling
	end

	-- Rock material: the wall with bands of the accent.
	local function wallMat(x: number, y: number, z: number): string
		local band = (y + 3 * fbm(x, z, 30, SEED + 91, 2)) % 9
		return if band < 1.6 then mats.accent else mats.wall
	end

	function T.material(x: number, y: number, z: number): string
		local c = column(x, z)
		if c.open and y < c.floor and y > c.floor - 3 then
			return c.floorMat
		end
		return wallMat(x, y, z)
	end

	function T.walkable(x: number, z: number, r: number?): boolean
		local c = column(x, z)
		if not c.open or (c.liquid and c.liquid.kind ~= "ice") then
			return false
		end
		if c.ceiling - c.floor < CaveTerrain.HEADROOM then
			return false
		end
		local rr = r or 2
		local pts = { { 0, 0 } }
		for i = 0, 7 do
			local a = i * math.pi / 4
			table.insert(pts, { math.cos(a) * rr, math.sin(a) * rr })
		end
		for _, o in pts do
			local px, pz = x + o[1], z + o[2]
			local p = column(px, pz)
			if not p.open or (p.liquid and p.liquid.kind ~= "ice") then
				return false
			end
			local gx = (T.floor(px + 1.5, pz) or p.floor + 99) - (T.floor(px - 1.5, pz) or p.floor + 99)
			local gz = (T.floor(px, pz + 1.5) or p.floor + 99) - (T.floor(px, pz - 1.5) or p.floor + 99)
			if math.sqrt(gx * gx + gz * gz) / 3 > CaveTerrain.WALKABLE_SLOPE then
				return false
			end
		end
		return true
	end

	function T.roomAt(x: number, z: number): number?
		for i = 1, nRooms do
			local r = rooms[i]
			local dx, dz = x - r.x, z - r.z
			if dx * dx + dz * dz < (r.r + 2) ^ 2 then
				return i
			end
		end
		return nil
	end

	-- Voxels of a block (TerrainLayers.Voxels: materials[x][y][z], occupancy), y layers from yBottom.
	function T.voxels(x0: number, z0: number, nx: number, nz: number, yBottom: number, ny: number): TerrainLayers.Voxels
		local V = CaveTerrain.VOXEL
		local materials: { { { string } } } = table.create(nx)
		local occupancy: { { { number } } } = table.create(nx)
		for i = 1, nx do
			local mi, oi = table.create(ny), table.create(ny)
			for j = 1, ny do
				mi[j], oi[j] = table.create(nz, "Air"), table.create(nz, 0)
			end
			for k = 1, nz do
				local x, z = x0 + V * (i - 0.5), z0 + V * (k - 0.5)
				local c = column(x, z)
				for j = 1, ny do
					local y = yBottom + V * (j - 1)
					if not c.open then
						mi[j][k], oi[j][k] = wallMat(x, y, z), 1
					else
						local low = math.clamp((c.floor - y) / V, 0, 1)
						local high = math.clamp((y + V - c.ceiling) / V, 0, 1)
						local liquid = c.liquid
						if low >= 0.5 then
							mi[j][k], oi[j][k] = if y + V > c.floor - 3 then c.floorMat else wallMat(x, y, z), low
						elseif liquid and liquid.kind == "water" and y < liquid.level then
							mi[j][k], oi[j][k] = "Water", math.clamp((liquid.level - y) / V, 0, 1)
						elseif high > 0 then
							mi[j][k], oi[j][k] = wallMat(x, y, z), high
						elseif low > 0 then
							mi[j][k], oi[j][k] = c.floorMat, low
						end
					end
				end
			end
			materials[i], occupancy[i] = mi, oi
		end
		return { materials = materials, occupancy = occupancy }
	end

	-- S49: places of wall niches (`niches` features: rows along a room's walls): x, z on the floor by the wall, yaw
	-- facing into the room, the room's index. The terrain keeps a plain wall; the dressing builds the shelves.
	function T.niches(): { { x: number, z: number, yaw: number, room: number, tiers: number, w: number, h: number } }
		local out = {}
		for _, f in features do
			if f.kind == "niches" then
				local room = rooms[f.room]
				if room then
					local spacing = f.spacing or 8
					local n = math.floor(2 * math.pi * room.r / spacing)
					for k = 0, n - 1 do
						local a = k * 2 * math.pi / n
						-- walk out to the wall
						local d = 4
						local lastX, lastZ = room.x, room.z
						while d < room.r * 1.6 do
							local px, pz = room.x + math.cos(a) * d, room.z + math.sin(a) * d
							local c = column(px, pz)
							if not c.open or c.ceiling - c.floor < (f.h or 6) * (f.tiers or 1) * 0.6 then
								break
							end
							lastX, lastZ = px, pz
							d += 1
						end
						-- skip tunnel mouths (open ground straight behind the wall)
						local bx, bz = room.x + math.cos(a) * (d + 4), room.z + math.sin(a) * (d + 4)
						if not column(bx, bz).open and d > room.r * 0.6 then
							table.insert(out, {
								x = lastX,
								z = lastZ,
								yaw = math.deg(math.atan2(math.cos(a), math.sin(a))),
								room = f.room,
								tiers = f.tiers or 1,
								w = f.w or 5,
								h = f.h or 5,
							})
						end
					end
				end
			end
		end
		return out
	end

	-- Floor of the map as rectangles on a grid of `step` studs (rows merged greedily), for the map sketch.
	function T.outline(step: number): { { x: number, z: number, w: number, d: number } }
		local n = math.floor(HALF * 2 / step)
		local out = {}
		local prev: { [string]: { x: number, z: number, w: number, d: number } } = {}
		for k = 0, n - 1 do
			local z = -HALF + (k + 0.5) * step
			local row: { [string]: { x: number, z: number, w: number, d: number } } = {}
			local i = 0
			while i < n do
				local x = -HALF + (i + 0.5) * step
				if column(x, z).open then
					local start = i
					while i < n and column(-HALF + (i + 0.5) * step, z).open do
						i += 1
					end
					local key = `{start}:{i}`
					local rect = prev[key]
					if rect then
						rect.d += step
						rect.z += step / 2
						row[key] = rect
					else
						local new = { x = -HALF + (start + i) / 2 * step, z = z, w = (i - start) * step, d = step }
						table.insert(out, new)
						row[key] = new
					end
				else
					i += 1
				end
			end
			prev = row
		end
		return out
	end

	return T
end

-- The cave of a map (nil for maps without a shape).
function CaveTerrain.get(mapId: string): Cave?
	local cached = cache[mapId]
	if cached then
		return cached
	end
	local shape = CaveShapes.byMap[mapId]
	if not shape then
		return nil
	end
	local cave = build(mapId, shape)
	cache[mapId] = cave
	return cave
end

function CaveTerrain.has(mapId: string): boolean
	return CaveShapes.byMap[mapId] ~= nil
end

-- Room index under (x, z) on a map (nil: no shape, tunnel or rock).
function CaveTerrain.roomAt(mapId: string, x: number, z: number): number?
	local cave = CaveTerrain.get(mapId)
	return if cave then cave.roomAt(x, z) else nil
end

return CaveTerrain
