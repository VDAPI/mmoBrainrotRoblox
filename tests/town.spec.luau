--!strict
-- Starting city plan (S21): the generated data in Data/Town must stay buildable and walkable. Mirrors
-- docs/miasto/tools/validate.py.

local Props = require("../src/shared/Logic/TownGen/Props")
local Spring = require("../src/shared/Logic/TownGen/Spring")
local T = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGeom = require("../src/shared/Logic/TownGeom")
local TownSigns = require("../src/shared/Logic/TownSigns")
local TownTerrain = require("../src/shared/Logic/TownTerrain")

local city = Town.city

type Vec2 = { number }
type Box = { id: string, poly: { Vec2 } }

-- S124: footprint of the Hall of Fame board (its stone step) and of a plinth's lowest step
local FAME_BOARD_W, FAME_BOARD_D = 15, 2.4
local FAME_PLINTH = 4.4

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
	-- S124: the Hall of Fame (Data/Town/fame, Logic/TownGen/Props fameHall): the board with its step and the plinths
	local fame = Town.fame
	table.insert(out, {
		id = "fameBoard",
		poly = TownGeom.rect(fame.board.x, fame.board.z, FAME_BOARD_W, FAME_BOARD_D, fame.board.facing),
	})
	for i, p in fame.plinths do
		table.insert(out, { id = `famePlinth{i}`, poly = TownGeom.rect(p.x, p.z, FAME_PLINTH, FAME_PLINTH, p.facing) })
	end
	-- S128: the arena Hall of Fame (the same build)
	local arenaFame = fame.arena
	table.insert(out, {
		id = "arenaFameBoard",
		poly = TownGeom.rect(arenaFame.board.x, arenaFame.board.z, FAME_BOARD_W, FAME_BOARD_D, arenaFame.board.facing),
	})
	for i, p in arenaFame.plinths do
		table.insert(
			out,
			{ id = `arenaFamePlinth{i}`, poly = TownGeom.rect(p.x, p.z, FAME_PLINTH, FAME_PLINTH, p.facing) }
		)
	end
	-- S130: the Champions of Vaelthorn (the same build)
	local tourneyFame = fame.tourney
	table.insert(out, {
		id = "tourneyFameBoard",
		poly = TownGeom.rect(
			tourneyFame.board.x,
			tourneyFame.board.z,
			FAME_BOARD_W,
			FAME_BOARD_D,
			tourneyFame.board.facing
		),
	})
	for i, p in tourneyFame.plinths do
		table.insert(
			out,
			{ id = `tourneyFamePlinth{i}`, poly = TownGeom.rect(p.x, p.z, FAME_PLINTH, FAME_PLINTH, p.facing) }
		)
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

	T.it("W28: lights every street evenly with tall lamps placed by rule", function()
		local TownLamps = require("../src/shared/Logic/TownLamps")
		-- the data is the generator's output (lune run tools/town_lamps.luau after a plan change)
		local placed = TownLamps.place(city)
		T.expect(#city.lamps).toBe(#placed)
		for i, l in placed do
			local d = city.lamps[i]
			T.expect({ d.id, d.kind, d.x, d.z, d.rot }).toEqual({ l.id, l.kind, l.x, l.z, l.rot })
		end
		-- no dark gap on any street centre line
		for _, p in TownLamps.samples(city) do
			local d = TownLamps.nearest(city.lamps, p[1], p[2])
			if d > TownLamps.COVER then
				error(`street point ({p[1]}, {p[2]}) is {d} studs from the nearest lamp`)
			end
		end
		-- on open ground, off the arena, the NPCs, the doors and each other
		local a = city.arena
		for _, l in city.lamps do
			T.expect({ l.id, TownTerrain.isOpen(l.x, l.z, 0.8) }).toEqual({ l.id, true })
			local inArena = math.abs(l.x - a.x) < a.half + a.stands + 5 and math.abs(l.z - a.z) < a.half + a.stands + 5
			T.expect({ l.id, inArena }).toEqual({ l.id, false })
			for id, spot in Town.allNpcSpots() do
				local d = math.sqrt((l.x - spot.x) ^ 2 + (l.z - spot.z) ^ 2)
				T.expect({ l.id, id, d >= 4 }).toEqual({ l.id, id, true })
			end
			for _, sp in city.specials do
				if sp.kind ~= "arena" then
					local dx, dz = TownGeom.door(sp.x, sp.z, sp.d, sp.rot)
					T.expect({ l.id, sp.id, math.sqrt((l.x - dx) ^ 2 + (l.z - dz) ^ 2) >= 5 }).toEqual({
						l.id,
						sp.id,
						true,
					})
				end
			end
		end
	end)

	T.it("puts NPCs next to their buildings", function()
		for id, spot in Town.allNpcSpots() do
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
		for id, spot in Town.allNpcSpots() do
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
		-- S124: the player walks up to the Hall of Fame board (its prompt opens the Rankings window)
		local board = Town.fame.board
		local fx, fz = TownGeom.front(board.facing)
		reach("the Hall of Fame board", board.x + fx * 4, board.z + fz * 4)
	end)

	T.it("puts the Hall of Fame by the town hall on open market ground (S124)", function()
		local fame = Town.fame
		local rynek
		for _, q in city.squares do
			if q.id == "rynek" then
				rynek = q
			end
		end
		T.expect(rynek ~= nil).toBe(true)
		local function far(what: string, x: number, z: number, ox: number, oz: number, min: number)
			local d = math.sqrt((x - ox) ^ 2 + (z - oz) ^ 2)
			if d < min then
				error(`{what}: {d} studs at ({x}, {z}), needs {min}`)
			end
		end
		local points = { { what = "board", p = fame.board } }
		for i, p in fame.plinths do
			table.insert(points, { what = `plinth {i}`, p = p })
		end
		for _, item in points do
			local x, z, what = item.p.x, item.p.z, item.what
			T.expect({ what, TownGeom.inPoly((rynek :: any).poly, x, z) }).toEqual({ what, true })
			T.expect({ what, TownTerrain.isOpen(x, z, 2) }).toEqual({ what, true })
			for id, spot in Town.allNpcSpots() do
				far(`{what} by NPC {id}`, x, z, spot.x, spot.z, 4)
			end
			for _, sign in TownSigns.list() do
				far(`{what} by sign {sign.key}`, x, z, sign.x, sign.z, 3)
			end
			for _, lamp in city.lamps do
				far(`{what} by lamp {lamp.id}`, x, z, lamp.x, lamp.z, 4)
			end
			for _, sp in city.specials do
				local poly = TownGeom.rect(sp.x, sp.z, sp.w, sp.d, sp.rot)
				if TownGeom.inPoly(poly, x, z) or TownGeom.edgeDist(poly, x, z) < 2 then
					error(`{what} touches {sp.id}`)
				end
			end
			for _, st in city.stalls do
				local poly = TownGeom.rect(st.x, st.z, 10, 5, st.rot)
				if TownGeom.inPoly(poly, x, z) or TownGeom.edgeDist(poly, x, z) < 2 then
					error(`{what} touches {st.id}`)
				end
			end
			far(`{what} by the maypole`, x, z, Spring.MAYPOLE.x, Spring.MAYPOLE.z, 8)
			far(`{what} by the pillory`, x, z, Props.PILLORY.x, Props.PILLORY.z, 6)
			far(`{what} by the fountain`, x, z, city.fountain[1], city.fountain[2], 10)
		end
		-- the board does not narrow a street
		local b = fame.board
		local corners = TownGeom.rect(b.x, b.z, FAME_BOARD_W, FAME_BOARD_D, b.facing)
		table.insert(corners, { b.x, b.z })
		for _, street in city.streets do
			for _, c in corners do
				local gap = TownGeom.lineDist(street.pts, c[1], c[2]) - street.w / 2
				if gap < 3 then
					error(`the Hall of Fame board is {gap} studs from street {street.id}`)
				end
			end
		end
		-- facing the market (from the north side, toward +z)
		local fx, fz = TownGeom.front(b.facing)
		T.expect(math.abs(fx) < 1e-6 and fz > 0.99).toBe(true)
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

T.describe("S128 arena Hall of Fame", function()
	local Arena = require("../src/shared/Data/Arena")

	for _, which in { "arena", "tourney" } do
		T.it(
			`{which}: stands on open ground by the Ristalle, off the arena, the streets and the NPCs, one plinth a bracket`,
			function()
				local spec = (Town.fame :: any)[which]
				T.expect(#spec.plinths).toBe(#Arena.BRACKETS)
				local a = city.arena
				local points = { { what = "board", p = spec.board } }
				for i, p in spec.plinths do
					table.insert(points, { what = `plinth {i}`, p = p })
				end
				for _, item in points do
					local x, z, what = item.p.x, item.p.z, item.what
					T.expect({ what, TownTerrain.isOpen(x, z, 2) }).toEqual({ what, true })
					local outside = math.abs(x - a.x) > a.half + a.stands + 3
						or math.abs(z - a.z) > a.half + a.stands + 3
					T.expect({ what, outside }).toEqual({ what, true })
					for id, spot in Town.allNpcSpots() do
						local d = math.sqrt((x - spot.x) ^ 2 + (z - spot.z) ^ 2)
						T.expect({ what, id, d >= 4 }).toEqual({ what, id, true })
					end
					for _, lamp in city.lamps do
						local d = math.sqrt((x - lamp.x) ^ 2 + (z - lamp.z) ^ 2)
						T.expect({ what, lamp.id, d >= 4 }).toEqual({ what, lamp.id, true })
					end
					for _, street in city.streets do
						local gap = TownGeom.lineDist(street.pts, x, z) - street.w / 2
						T.expect({ what, street.id, gap >= 3 }).toEqual({ what, street.id, true })
					end
				end
				-- near the arena's way out (the players walk over from the Ristalle)
				local d = math.sqrt((spec.board.x - a.exit[1]) ^ 2 + (spec.board.z - a.exit[2]) ^ 2)
				T.expect(d < 60).toBe(true)
			end
		)
	end
end)
