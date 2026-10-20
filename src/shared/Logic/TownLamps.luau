--!strict
-- W28: street lamps of the city, placed by rule instead of by hand (owner 2026-10-20: the old lamps were low, few
-- and scattered, the town dark and patchy at night). `tools/town_lamps.luau` runs `place` and writes the result into
-- Data/Town/city.luau (`lamps`), so the game only reads data. Order of the passes: the old ramp lanterns stay, then
-- a pair at each gate, at the entrances of the special buildings, at both ends of every bridge, between the market
-- stalls and in the corners of the squares, then along every street (alternating sides every SPACING studs, the
-- arm over the road), and last a fill pass that adds a lamp wherever a point of a street centre line is still
-- farther than COVER studs from the nearest lamp. Every lamp stands on open ground (TownTerrain.isOpen), beside the
-- streets and ramps, off doors, NPCs, escort waypoints, signs, wells, the fountain, the spawn, the arena (another session rebuilds
-- it) and the Halls of Fame. Pure; tests/town.spec checks the coverage on the data.

local Quests = require("../Data/Quests")
local Town = require("../Data/Town")
local TownGeom = require("./TownGeom")
local TownSigns = require("./TownSigns")
local TownTerrain = require("./TownTerrain")

type Vec2 = { number }
export type Lamp = { id: string, kind: "post" | "rampLantern", x: number, z: number, rot: number? }

local TownLamps = {}

TownLamps.SPACING = 24 -- along a street, alternating sides
TownLamps.COVER = 18 -- no point of a street centre line farther than this from a lamp
TownLamps.MIN_GAP = 10 -- between two lamps
TownLamps.STEP = 2 -- sampling step of the street centre lines

local PILLORY = { 72, -42 } -- TownGen/Props.PILLORY (not required here: Props pulls the whole generator)

-- Sample points of every street centre line (x, z), STEP studs apart, ends included.
function TownLamps.samples(city: any): { Vec2 }
	local out: { Vec2 } = {}
	for _, street in city.streets do
		local pts = street.pts
		for i = 1, #pts - 1 do
			local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local n = math.max(1, math.ceil(len / TownLamps.STEP))
			for k = 0, n do
				local t = k / n
				table.insert(out, { ax + (bx - ax) * t, az + (bz - az) * t })
			end
		end
	end
	return out
end

-- Distance from (x, z) to the nearest lamp of `lamps`.
function TownLamps.nearest(lamps: { Lamp }, x: number, z: number): number
	local best = math.huge
	for _, l in lamps do
		local d = (l.x - x) ^ 2 + (l.z - z) ^ 2
		if d < best then
			best = d
		end
	end
	return math.sqrt(best)
end

-- Rotation of a lamp whose arm (local +X) points from (x, z) toward (tx, tz).
local function aim(x: number, z: number, tx: number, tz: number): number
	local dx, dz = tx - x, tz - z
	if dx * dx + dz * dz < 1e-6 then
		return 0
	end
	local r = math.deg(math.atan2(-dz, dx)) % 360
	return math.floor(r * 10 + 0.5) / 10
end

-- Nearest point of any street centre line to (x, z).
local function nearestStreetPoint(city: any, x: number, z: number): (number, number)
	local best, bx, bz = math.huge, x, z
	for _, street in city.streets do
		local pts = street.pts
		for i = 1, #pts - 1 do
			local ax, az, cx, cz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
			local ex, ez = cx - ax, cz - az
			local len2 = ex * ex + ez * ez
			local t = if len2 > 0 then math.clamp(((x - ax) * ex + (z - az) * ez) / len2, 0, 1) else 0
			local px, pz = ax + ex * t, az + ez * t
			local d = (px - x) ^ 2 + (pz - z) ^ 2
			if d < best then
				best, bx, bz = d, px, pz
			end
		end
	end
	return bx, bz
end

local function round1(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end

-- Everything a lamp must keep clear of, built once per `place` call.
local function makeChecker(city: any)
	local points: { { number } } = {} -- { x, z, min distance }
	for _, spot in Town.allNpcSpots() do
		table.insert(points, { spot.x, spot.z, 5 })
	end
	for _, sign in TownSigns.list() do
		table.insert(points, { sign.x, sign.z, 4 })
	end
	for _, w in city.wells do
		table.insert(points, { w[1], w[2], 5 })
	end
	table.insert(points, { city.fountain[1], city.fountain[2], 13 })
	table.insert(points, { city.spawn.x, city.spawn.z, 6 })
	table.insert(points, { PILLORY[1], PILLORY[2], 5 })
	for _, lot in city.lots do
		local dx, dz = TownGeom.door(lot.x, lot.z, lot.d, lot.rot)
		table.insert(points, { dx, dz, 4.5 })
	end
	for _, sp in city.specials do
		if sp.kind ~= "arena" then
			local dx, dz = TownGeom.door(sp.x, sp.z, sp.d, sp.rot)
			table.insert(points, { dx, dz, 5 })
		end
	end
	for _, g in city.gates do
		table.insert(points, { g.x, g.z, 9 })
		table.insert(points, { g.arrive[1], g.arrive[2], 5 })
	end
	-- the Halls of Fame (another session owns their statues): the boards and plinths with a wide berth
	local fame: any = Town.fame
	for _, hall in { fame, fame.arena, fame.tourney } do
		if hall then
			table.insert(points, { hall.board.x, hall.board.z, 11 })
			for _, p in hall.plinths do
				table.insert(points, { p.x, p.z, 7 })
			end
		end
	end
	-- the escort routes through the city (Dobiesław's frostSign walk): every waypoint stays free (tests/companion.spec)
	for _, q in Quests.Main.byId :: any do
		local c = q.companion
		if c and c.map == "city" and c.mode == "lead" then
			for _, obj in q.objectives do
				if obj.type == "escort" then
					for _, v in obj.via or {} do
						table.insert(points, { v.x, v.z, 6 })
					end
					if obj.x and obj.z then
						table.insert(points, { obj.x, obj.z, 6 })
					end
				end
			end
		end
	end
	local a = city.arena
	local arenaHalf = a.half + a.stands + 5
	-- `tight`: the fallback for streets lined by house fronts: the lamp may stand on the edge of the road itself
	-- (up to 1.2 studs in from its side) and 0.8 studs from a wall
	return function(x: number, z: number, tight: boolean?): boolean
		if not TownTerrain.isOpen(x, z, if tight then 0.8 else 1.5) then
			return false
		end
		if math.abs(x - a.x) < arenaHalf and math.abs(z - a.z) < arenaHalf then
			return false
		end
		for _, p in points do
			if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < p[3] * p[3] then
				return false
			end
		end
		for _, street in city.streets do
			if TownGeom.lineDist(street.pts, x, z) < street.w / 2 + (if tight then -1.2 else 0.8) then
				return false
			end
		end
		for _, ramp in city.terrain.ramps do
			local pts = {}
			for _, p in ramp.pts do
				table.insert(pts, { p[1], p[2] })
			end
			if TownGeom.lineDist(pts, x, z) < ramp.w / 2 + 1.5 then
				return false
			end
		end
		for _, w in city.retaining do
			local d = TownGeom.segDist(w.a[1], w.a[2], w.b[1], w.b[2], x, z)
			if d < 2.5 then
				return false
			end
		end
		for _, b in city.bridges do
			local poly = TownGeom.rect(b.x, b.z, b.w, b.len, b.rot)
			if TownGeom.inPoly(poly, x, z) or TownGeom.edgeDist(poly, x, z) < 1 then
				return false
			end
		end
		for _, st in city.stalls do
			local poly = TownGeom.rect(st.x, st.z, 10, 5, st.rot)
			if TownGeom.edgeDist(poly, x, z) < 2.5 then
				return false
			end
		end
		return true
	end
end

function TownLamps.place(city: any): { Lamp }
	local free = makeChecker(city)
	local lamps: { Lamp } = {}
	local function spaced(x: number, z: number, gap: number): boolean
		return TownLamps.nearest(lamps, x, z) >= gap
	end
	local function add(x: number, z: number, kind: "post" | "rampLantern", rot: number)
		table.insert(lamps, { id = "", kind = kind, x = round1(x), z = round1(z), rot = rot })
	end
	-- Tries (x, z), then shifts along (ux, uz) by up to `reach` studs; the arm points to (tx, tz) or the street.
	local function try(
		x: number,
		z: number,
		ux: number,
		uz: number,
		reach: number,
		gap: number,
		tx: number?,
		tz: number?,
		tight: boolean?
	): boolean
		for _, s in { 0, 2, -2, 4, -4, 6, -6, 8, -8, 10, -10 } do
			if math.abs(s) <= reach then
				local px, pz = x + ux * s, z + uz * s
				if free(px, pz, tight) and spaced(px, pz, gap) then
					local ax, az = tx, tz
					if ax == nil or az == nil then
						ax, az = nearestStreetPoint(city, px, pz)
					end
					add(px, pz, "post", aim(px, pz, ax :: number, az :: number))
					return true
				end
			end
		end
		return false
	end

	-- 1. the ramp lanterns of the plan stay as they were (low lanterns at the ends of the ramps)
	for _, l in city.lamps do
		if l.kind == "rampLantern" then
			table.insert(lamps, { id = "", kind = "rampLantern", x = l.x, z = l.z, rot = l.rot or 0 })
		end
	end
	-- 2. gates: a lamp on each side of the way in, a little inside the wall
	for _, g in city.gates do
		local ux, uz = g.arrive[1] - g.x, g.arrive[2] - g.z
		local len = math.sqrt(ux * ux + uz * uz)
		ux, uz = ux / len, uz / len
		for _, side in { -1, 1 } do
			for _, off in { 11, 13, 15 } do
				local x, z = g.x + ux * 12 - uz * side * off, g.z + uz * 12 + ux * side * off
				if try(x, z, ux, uz, 6, TownLamps.MIN_GAP, g.arrive[1], g.arrive[2]) then
					break
				end
			end
		end
	end
	-- 3. entrances of the special buildings (temple, keep, town hall, guild, tavern...): one lamp each side
	for _, sp in city.specials do
		if sp.kind ~= "arena" then
			local fx, fz = TownGeom.front(sp.rot)
			local dx, dz = TownGeom.door(sp.x, sp.z, sp.d, sp.rot)
			for _, side in { -1, 1 } do
				for _, off in { 6, 8, 10 } do
					local x, z = dx + fx * 3 - fz * side * off, dz + fz * 3 + fx * side * off
					if try(x, z, fx, fz, 2, TownLamps.MIN_GAP, dx + fx * 6, dz + fz * 6) then
						break
					end
				end
			end
		end
	end
	-- 4. bridges: one lamp at each end, on alternate sides
	for _, b in city.bridges do
		local fx, fz = TownGeom.front(b.rot) -- along the bridge (its local -Z)
		for i, e in { -1, 1 } do
			local side = if i == 1 then 1 else -1
			local ex, ez = b.x + fx * e * (b.len / 2 + 2), b.z + fz * e * (b.len / 2 + 2)
			local x, z = ex - fz * side * (b.w / 2 + 1.5), ez + fx * side * (b.w / 2 + 1.5)
			try(x, z, fx * e, fz * e, 6, TownLamps.MIN_GAP, b.x, b.z)
		end
	end
	-- 5. the stall row: lamps in the gaps between neighbouring stalls and at both ends of the row
	local stalls = table.clone(city.stalls)
	table.sort(stalls, function(p: any, q: any)
		return p.x < q.x
	end)
	for i, st in stalls do
		local fx, fz = TownGeom.front(st.rot)
		if i == 1 then
			try(st.x - 8, st.z, fx, fz, 2, TownLamps.MIN_GAP, st.x + fx * 6, st.z + fz * 6)
		end
		local nxt = stalls[i + 1]
		if nxt and math.abs(nxt.z - st.z) < 1 and nxt.x - st.x > 14 then
			try((st.x + nxt.x) / 2, st.z, fx, fz, 2, TownLamps.MIN_GAP, (st.x + nxt.x) / 2 + fx * 6, st.z + fz * 6)
		elseif not nxt then
			try(st.x + 8, st.z, fx, fz, 2, TownLamps.MIN_GAP, st.x + fx * 6, st.z + fz * 6)
		end
	end
	-- 6. corners of the squares, 5 studs in toward the middle
	for _, sq in city.squares do
		local cx, cz = 0, 0
		for _, v in sq.poly do
			cx += v[1] / #sq.poly
			cz += v[2] / #sq.poly
		end
		for _, v in sq.poly do
			local dx, dz = cx - v[1], cz - v[2]
			local len = math.sqrt(dx * dx + dz * dz)
			if len > 8 then
				try(v[1] + dx / len * 5, v[2] + dz / len * 5, dx / len, dz / len, 4, 14, cx, cz)
			end
		end
	end
	-- 7. along the streets: every SPACING studs, alternating sides, the arm over the road
	for _, street in city.streets do
		local pts = street.pts
		local side = 1
		local carry = TownLamps.SPACING / 2
		for i = 1, #pts - 1 do
			local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local ux, uz = (bx - ax) / len, (bz - az) / len
			local k = carry
			while k < len do
				local px, pz = ax + ux * k, az + uz * k
				if TownLamps.nearest(lamps, px, pz) > TownLamps.SPACING / 2 then
					local off = street.w / 2 + 1.5
					local placed = false
					for _, s in { side, -side } do
						for _, extra in { 0, 1.5, 3 } do
							local x, z = px - uz * s * (off + extra), pz + ux * s * (off + extra)
							if try(x, z, ux, uz, 6, TownLamps.MIN_GAP, px, pz) then
								placed = true
								break
							end
						end
						if placed then
							break
						end
					end
				end
				side = -side
				k += TownLamps.SPACING
			end
			carry = k - len
		end
	end
	-- 8. fill: wherever a street point is still dark, the nearest free spot beside the road
	for _ = 1, 3 do
		for _, p in TownLamps.samples(city) do
			if TownLamps.nearest(lamps, p[1], p[2]) > TownLamps.COVER - 1 then
				local done = false
				for _, street in city.streets do
					if done then
						break
					end
					if TownGeom.lineDist(street.pts, p[1], p[2]) < 0.5 then
						-- the direction of the street here: from the nearest segment
						local pts = street.pts
						for i = 1, #pts - 1 do
							local d = TownGeom.segDist(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], p[1], p[2])
							if d < 0.5 then
								local ux, uz = pts[i + 1][1] - pts[i][1], pts[i + 1][2] - pts[i][2]
								local len = math.sqrt(ux * ux + uz * uz)
								ux, uz = ux / len, uz / len
								for _, extra in { 1.5, 3, 5, 8, -0.4, -1 } do
									for _, s in { 1, -1 } do
										local off = street.w / 2 + extra
										local x, z = p[1] - uz * s * off, p[2] + ux * s * off
										if try(x, z, ux, uz, 10, 8, p[1], p[2], extra < 0) then
											done = true
											break
										end
									end
									if done then
										break
									end
								end
								break
							end
						end
					end
				end
			end
		end
	end
	for i, l in lamps do
		l.id = string.format("l%03d", i)
	end
	return lamps
end

return TownLamps
