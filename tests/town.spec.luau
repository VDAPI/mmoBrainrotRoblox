--!strict
-- Starting city plan (S21): the generated data in Data/Town must stay buildable and walkable. Mirrors
-- docs/miasto/tools/validate.py.

local T = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGeom = require("../src/shared/Logic/TownGeom")
local TownTerrain = require("../src/shared/Logic/TownTerrain")

local city = Town.city

type Vec2 = { number }
type Box = { id: string, poly: { Vec2 } }

-- Footprints of everything solid on the ground: houses, special buildings (the arena only by its stands, which
-- leave 12-stud entrances in the middle of the north and south sides), stalls, the fountain and wells.
local function footprints(): { Box }
	local out: { Box } = {}
	for _, lot in city.lots do
		table.insert(out, { id = lot.id, poly = TownGeom.rect(lot.x, lot.z, lot.w, lot.d, lot.rot) })
	end
	for _, s in city.specials do
		if s.kind == "arena" then
			local a = city.arena
			local h, o = a.half, a.half + a.stands
			local x, z = a.x, a.z
			for _, r in
				{
					{ x - o, z - o, x - h, z + o },
					{ x + h, z - o, x + o, z + o },
					{ x - h, z - o, x - 6, z - h },
					{ x + 6, z - o, x + h, z - h },
					{ x - h, z + h, x - 6, z + o },
					{ x + 6, z + h, x + h, z + o },
				}
			do
				table.insert(out, {
					id = "arenaStand",
					poly = { { r[1], r[2] }, { r[3], r[2] }, { r[3], r[4] }, { r[1], r[4] } },
				})
			end
		else
			table.insert(out, { id = s.id, poly = TownGeom.rect(s.x, s.z, s.w, s.d, s.rot) })
		end
	end
	for _, s in city.stalls do
		table.insert(out, { id = s.id, poly = TownGeom.rect(s.x, s.z, 10, 5, s.rot) })
	end
	return out
end

-- Separating axis test for two convex quads shrunk by `inset` studs (touching edges are fine).
local function overlaps(a: { Vec2 }, b: { Vec2 }, inset: number): boolean
	for _, poly in { a, b } do
		for i = 1, #poly do
			local p, q = poly[i], poly[i % #poly + 1]
			local ex, ez = q[1] - p[1], q[2] - p[2]
			local len = math.sqrt(ex * ex + ez * ez)
			local nx, nz = -ez / len, ex / len
			local minA, maxA, minB, maxB = math.huge, -math.huge, math.huge, -math.huge
			for _, v in a do
				local d = v[1] * nx + v[2] * nz
				minA, maxA = math.min(minA, d), math.max(maxA, d)
			end
			for _, v in b do
				local d = v[1] * nx + v[2] * nz
				minB, maxB = math.min(minB, d), math.max(maxB, d)
			end
			if maxA - inset <= minB + inset or maxB - inset <= minA + inset then
				return false
			end
		end
	end
	return true
end

local function inWallsBy(x: number, z: number, margin: number): boolean
	return TownGeom.inPoly(city.wall, x, z) and TownGeom.edgeDist(city.wall, x, z) >= margin
end

T.describe("Town plan", function()
	T.it("has unique ids", function()
		local seen = {}
		for _, list in { city.lots, city.specials, city.gardens, city.retaining, city.lamps, city.stalls } do
			for _, item in list :: { any } do
				T.expect(seen[item.id]).toBeNil()
				seen[item.id] = true
			end
		end
	end)

	T.it("keeps every footprint inside the walls and apart", function()
		local boxes = footprints()
		for _, b in boxes do
			if b.id ~= "arenaStand" then
				for _, v in b.poly do
					if not inWallsBy(v[1], v[2], 8) then
						error(`{b.id} sticks out of the walls`)
					end
				end
			end
		end
		for i = 1, #boxes do
			for j = i + 1, #boxes do
				local a, b = boxes[i], boxes[j]
				if not (a.id == "arenaStand" and b.id == "arenaStand") and overlaps(a.poly, b.poly, 0.3) then
					error(`{a.id} overlaps {b.id}`)
				end
			end
		end
	end)

	T.it("puts NPCs next to their buildings", function()
		for id, spot in city.npcs do
			local at = spot.at
			if at then
				local special = Town.special(at)
				if special then
					local dx, dz = TownGeom.door(special.x, special.z, special.d, special.rot)
					local dist = math.sqrt((dx - spot.x) ^ 2 + (dz - spot.z) ^ 2)
					if dist > 16 then
						error(`{id} is {dist} studs from the door of {at}`)
					end
				else
					local found = false
					for _, stall in city.stalls do
						if stall.id == at then
							found = true
							T.expect(math.sqrt((stall.x - spot.x) ^ 2 + (stall.z - spot.z) ^ 2) <= 9).toBe(true)
						end
					end
					T.expect(found).toBe(true)
				end
			end
		end
	end)

	T.it("keeps streets walkable and ramps gentle", function()
		local function onBridge(x: number, z: number): boolean
			for _, b in city.bridges do
				if TownGeom.inPoly(TownGeom.rect(b.x, b.z, b.w + 4, b.len + 4, b.rot), x, z) then
					return true
				end
			end
			return false
		end
		for _, street in city.streets do
			local pts = street.pts
			for i = 1, #pts - 1 do
				local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
				local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
				local prev: number? = nil
				for k = 0, math.floor(len / 2) do
					local t = k * 2 / len
					local x, z = ax + (bx - ax) * t, az + (bz - az) * t
					if onBridge(x, z) then
						prev = nil
					else
						local h = TownTerrain.heightAt(x, z)
						if prev and math.abs(h - prev) > 1 then
							error(`street {street.id} too steep at {x},{z}`)
						end
						prev = h
					end
				end
			end
		end
		for _, ramp in city.terrain.ramps do
			local pts = ramp.pts
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local grade = math.abs(b[3] - a[3]) / math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
				T.expect(grade <= (if ramp.stairs then 0.5 else 0.25) + 1e-6).toBe(true)
			end
			for _, ends in { { pts[1], pts[2] }, { pts[#pts], pts[#pts - 1] } } do
				local e, n = ends[1], ends[2]
				local dx, dz = e[1] - n[1], e[2] - n[2]
				local len = math.sqrt(dx * dx + dz * dz)
				local reach = ramp.w / 2 + 1.5
				local ground = TownTerrain.heightAt(e[1] + dx / len * reach, e[2] + dz / len * reach, true)
				if math.abs(ground - e[3]) > 0.8 then
					error(`ramp {ramp.id} end {e[1]},{e[2]} at {e[3]} but ground {ground}`)
				end
			end
		end
	end)

	T.it("lets a player walk from the spawn to every NPC, gate, door and duel spot", function()
		local CELL = 2
		local half = city.size / 2
		local n = city.size // CELL
		local function cellOf(x: number, z: number): number
			local i = math.floor((x + half) / CELL)
			local j = math.floor((z + half) / CELL)
			return i * n + j
		end
		local function centre(c: number): (number, number)
			return -half + (c // n + 0.5) * CELL, -half + (c % n + 0.5) * CELL
		end
		local blocked: { [number]: boolean } = {}
		local function rasterize(poly: { Vec2 })
			local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
			for _, v in poly do
				minX, maxX = math.min(minX, v[1]), math.max(maxX, v[1])
				minZ, maxZ = math.min(minZ, v[2]), math.max(maxZ, v[2])
			end
			for x = math.floor((minX + half) / CELL), math.floor((maxX + half) / CELL) do
				for z = math.floor((minZ + half) / CELL), math.floor((maxZ + half) / CELL) do
					local c = x * n + z
					local cx, cz = centre(c)
					if TownGeom.inPoly(poly, cx, cz) then
						blocked[c] = true
					end
				end
			end
		end
		local function disc(x: number, z: number, r: number)
			for i = math.floor((x - r + half) / CELL), math.floor((x + r + half) / CELL) do
				for j = math.floor((z - r + half) / CELL), math.floor((z + r + half) / CELL) do
					local c = i * n + j
					local cx, cz = centre(c)
					if (cx - x) ^ 2 + (cz - z) ^ 2 <= r * r then
						blocked[c] = true
					end
				end
			end
		end
		for _, b in footprints() do
			rasterize(b.poly)
		end
		disc(city.fountain[1], city.fountain[2], 11)
		for _, w in city.wells do
			disc(w[1], w[2], 3.5)
		end
		for _, w in city.retaining do
			local ax, az, bx, bz = w.a[1], w.a[2], w.b[1], w.b[2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local ux, uz = (bx - ax) / len, (bz - az) / len
			rasterize({
				{ ax - uz * 1.25, az + ux * 1.25 },
				{ bx - uz * 1.25, bz + ux * 1.25 },
				{ bx + uz * 1.25, bz - ux * 1.25 },
				{ ax + uz * 1.25, az - ux * 1.25 },
			})
		end
		local river = city.terrain.river
		local bridges = {}
		for _, b in city.bridges do
			table.insert(bridges, TownGeom.rect(b.x, b.z, b.w, b.len, b.rot))
		end
		local height: { [number]: number } = {}
		local function walkable(c: number): boolean
			if blocked[c] then
				return false
			end
			local h = height[c]
			if h then
				return true
			end
			local x, z = centre(c)
			if not inWallsBy(x, z, 8) then
				blocked[c] = true
				return false
			end
			local onBridge = false
			for _, poly in bridges do
				if TownGeom.inPoly(poly, x, z) then
					onBridge = true
				end
			end
			if not onBridge and TownGeom.lineDist(river.pts, x, z) < river.width / 2 + 1 then
				blocked[c] = true
				return false
			end
			local ground = TownTerrain.heightAt(x, z)
			height[c] = if onBridge then math.max(ground, 0.8) else ground
			return true
		end
		local start = cellOf(city.spawn.x, city.spawn.z)
		T.expect(walkable(start)).toBe(true)
		local seen = { [start] = true }
		local queue = { start }
		local head = 1
		while head <= #queue do
			local c = queue[head]
			head += 1
			local i, j = c // n, c % n
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local ni, nj = i + d[1], j + d[2]
				if ni >= 0 and nj >= 0 and ni < n and nj < n then
					local nc = ni * n + nj
					if not seen[nc] and walkable(nc) and math.abs(height[nc] - height[c]) <= 1.9 then
						seen[nc] = true
						table.insert(queue, nc)
					end
				end
			end
		end
		local function reach(what: string, x: number, z: number)
			if not seen[cellOf(x, z)] then
				error(`{what} ({x}, {z}) cannot be reached from the spawn`)
			end
		end
		for id, spot in city.npcs do
			reach(`NPC {id}`, spot.x, spot.z)
		end
		for _, gate in city.gates do
			reach(`gate {gate.id} arrival`, gate.arrive[1], gate.arrive[2])
			reach(`gate {gate.id} passage`, gate.x - gate.out[1] * 14, gate.z - gate.out[2] * 14)
		end
		reach("arena exit", city.arena.exit[1], city.arena.exit[2])
		for _, spot in city.arena.duel do
			reach("duel spot", spot[1], spot[2])
		end
		for _, s in city.specials do
			if s.kind ~= "arena" then
				local dx, dz = TownGeom.door(s.x, s.z, s.d, s.rot)
				reach(`door of {s.id}`, dx, dz)
			end
		end
		for _, lot in city.lots do
			local dx, dz = TownGeom.door(lot.x, lot.z, lot.d, lot.rot)
			reach(`door of {lot.id}`, dx, dz)
		end
	end)

	T.it("has sane gardens and retaining walls", function()
		for _, g in city.gardens do
			T.expect(#g.poly >= 3).toBe(true)
			for _, v in g.poly do
				T.expect(TownGeom.inPoly(city.wall, v[1], v[2])).toBe(true)
			end
		end
		for _, w in city.retaining do
			T.expect(w.top > w.bottom).toBe(true)
			T.expect(w.top - w.bottom <= 26).toBe(true)
		end
	end)
end)
