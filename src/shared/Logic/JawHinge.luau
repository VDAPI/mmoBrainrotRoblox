--!strict
-- Template animation (owner 2026-11-01: Vaelgrath's mouth is modelled open and the model has no jaw bone, so it
-- cannot move): a jaw found in the mesh and hung on a new bone under the head bone, closed at rest and opened by the
-- actions (Data/BipedRigs `jaw`). client/Anim/MeshJaw adds the bone to the model's skinned mesh (an EditableMesh) and
-- skins the lower jaw to it; without one (an older client, the game setting off, the memory budget spent, a mesh
-- whose mouth cannot be found) the mouth stays as modelled. Pure (Lune), in three parts:
-- 1. `plan`, once per mesh (the client caches it), in the head's frame "H": the head bone's joint at the origin, the
--    look's axes (x right, y up, z back: the snout points to -z), studs. With no names to go by:
--    * the head: the vertices skinned to the head bone (and those under it) by at least `headWeight`; the snout runs
--      from the joint to the furthest of them ahead (its length L: every share of the data is of it);
--    * the side view (z, y) of the head's faces in cells of L / `cells`: a column ahead of `from` with empty cells
--      between its lowest and highest shadow looks through the open mouth. The enclosed cells' pieces (a tooth that
--      closes up to BRIDGE columns does not split one); the mouth is the piece over the most columns reaching into the
--      front half of the snout, at least `gapMin` high and `minColumns` long;
--    * the seam: a line through the middles of the opening; the corner: the opening's back end; the hinge `hinge`
--      behind and under it;
--    * the lower jaw: the head's vertices under the opening in its columns, and whatever hangs off them along the
--      mesh (welded, so a texture seam does not cut it; a chin spike, a beard): under the seam, not behind the
--      blend, at most `below` under the jaw, with at least `grow` head skin. Each takes a share of the jaw: all of it
--      ahead of the hinge, none `blend.back` behind it, and near the seam behind the opening (the corner of the mouth)
--      a share growing from the seam down (the cheek stretches instead of tearing);
--    * closed: the lower jaw turns up about the hinge until its top (the lower teeth's tips) would meet the upper
--      jaw's underside (the upper teeth's tips) anywhere from `contact` of the mouth's length forward: both cut from the
--      faces on lines across the opening (one through every tooth tip), short of contact by `margin` at the tip.
-- 2. `reweigh`: a vertex's bones and weights with its share of the head's skin moved onto the jaw bone (at most four
--    bones, summing to 1).
-- 3. `open`: the jaw's opening (degrees from closed) of an action at a time on its timeline (Logic/ActionFx marks).

local ActionFx = require("./ActionFx")
local BipedRigs = require("../Data/BipedRigs")
local LegFold = require("./LegFold")
local MotionFx = require("../Data/MotionFx")

local JawHinge = {}

export type Options = BipedRigs.Jaw

-- What `plan` found (H frame, studs).
export type Plan = {
	idx: { number }, -- each jaw vertex's index in the list it was given
	share: { number }, -- its share of the jaw (1: all its head skin moves with the jaw)
	hinge: { number }, -- the hinge (y, z; its axis is the look's x)
	closed: number, -- rad: the turn up about the hinge that closes the mouth (+ closes)
	snout: number, -- L
	corner: { number }, -- the mouth's back corner (y, z)
	seam: { number }, -- the seam y = a + b z
	columns: number, -- side-view columns the opening spans
	full: number, -- jaw vertices that move wholly with it
	tipRadius: number, -- the lower jaw's front from the hinge
	tipAngle: number, -- rad: the opening there as modelled (the closed turn plus the margin's)
}

local INF = math.huge
-- A tooth that closes the opening over at most this many columns does not split the mouth.
local BRIDGE = 3
-- A share under this is no share.
local LEAST = 0.004
-- The corner where the opening's top and bottom meet, at most this much of the snout behind its last column.
local APEX = 0.2

local function smooth(x: number): number
	local t = if x < 0 then 0 elseif x > 1 then 1 else x
	return t * t * (3 - 2 * t)
end

-- The least-squares line y = a + b z through the points (flat when they do not spread along z).
local function fitLine(zs: { number }, ys: { number }): (number, number)
	local n = #zs
	local sz, sy, szz, szy = 0, 0, 0, 0
	for k = 1, n do
		sz += zs[k]
		sy += ys[k]
		szz += zs[k] * zs[k]
		szy += zs[k] * ys[k]
	end
	local mz, my = sz / n, sy / n
	local varZ = szz / n - mz * mz
	local b = if varZ > 1e-12 then (szy / n - mz * my) / varZ else 0
	return my - b * mz, b
end

-- The heights a triangle (side view: its corners' y and z) covers between z = za and z = zb (lo > hi: none).
local function clipY(ys: { number }, zs: { number }, za: number, zb: number): (number, number)
	local lo, hi = INF, -INF
	for k = 1, 3 do
		local y, z = ys[k], zs[k]
		if z >= za and z <= zb then
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
		local k2 = k % 3 + 1
		local y2, z2 = ys[k2], zs[k2]
		if z ~= z2 then
			for _, edge in { za, zb } do
				local w = (edge - z) / (z2 - z)
				if w > 0 and w < 1 then
					local ye = y + (y2 - y) * w
					lo, hi = math.min(lo, ye), math.max(hi, ye)
				end
			end
		end
	end
	return lo, hi
end

-- Marks parsed once (Data/MotionFx).
local marks: { [string]: MotionFx.Mark } = {}
local function markOf(text: string): MotionFx.Mark
	local m = marks[text]
	if not m then
		m = MotionFx.mark(text)
		marks[text] = m
	end
	return m
end

-- The plan of a head: `pos` the vertices (H, flat x y z), `head` each one's skin on the head bone and the bones under
-- it (0..1), `tris` the triangles (flat, 1-based indices; nil: the side view by the vertices alone and the mesh by
-- nearness), `o` the model's jaw; `yield` (if given) is called now and then. Nil and why when the mouth is not found;
-- then `view` (if given) gets the side view, a line per row from the top, the snout's tip on the left: `#` a face,
-- `o` the opening taken for the mouth, `.` another enclosed gap, `|` the `from` line (MeshJaw prints it in Studio).
function JawHinge.plan(
	pos: { number },
	head: { number },
	tris: { number }?,
	o: Options,
	yield: (() -> ())?,
	view: { string }?
): (Plan?, string)
	local n = #pos // 3
	if n < 8 or #head < n then
		return nil, "too few vertices"
	end
	local tick = 0
	local function step(k: number)
		if yield then
			tick += k
			if tick >= 4000 then
				tick = 0
				yield()
			end
		end
	end
	local bridge = o.bridge or BRIDGE
	-- 1. the head and its snout
	local isHead = table.create(n, false)
	local count = 0
	local tipZ, backZ, yLo, yHi = 0, -INF, INF, -INF
	for i = 1, n do
		if head[i] >= o.headWeight then
			isHead[i] = true
			count += 1
			local y, z = pos[i * 3 - 1], pos[i * 3]
			tipZ, backZ = math.min(tipZ, z), math.max(backZ, z)
			yLo, yHi = math.min(yLo, y), math.max(yHi, y)
		end
	end
	if count < 8 then
		return nil, "no head in the skin"
	end
	local L = -tipZ
	if L <= 1e-6 or yHi <= yLo then
		return nil, "no snout ahead of the head bone"
	end
	-- 2. the side view: the shadows of the head's faces (else its vertices, a cell around)
	local cs = L / o.cells
	local z0 = tipZ - 2 * cs
	local y0 = yLo - 2 * cs
	local gz = math.ceil((math.min(backZ, L) - z0) / cs) + 2
	local gy = math.ceil((yHi - y0) / cs) + 2
	local occ = table.create(gz * gy, 0)
	local function mark(fz: number, fy: number)
		local c, r = math.floor(fz), math.floor(fy)
		if c >= 0 and c < gz and r >= 0 and r < gy then
			occ[c * gy + r + 1] = 1
		end
	end
	local faced = tris ~= nil and #tris >= 3
	if tris and faced then
		local m = #tris // 3
		for f = 0, m - 1 do
			local a, b, c = tris[f * 3 + 1], tris[f * 3 + 2], tris[f * 3 + 3]
			if isHead[a] and isHead[b] and isHead[c] then
				local az, ay = (pos[a * 3] - z0) / cs, (pos[a * 3 - 1] - y0) / cs
				local bz, by = (pos[b * 3] - z0) / cs, (pos[b * 3 - 1] - y0) / cs
				local cz, cy = (pos[c * 3] - z0) / cs, (pos[c * 3 - 1] - y0) / cs
				-- the edges (a face seen edge-on still leaves its line)
				for e = 1, 3 do
					local pz, py, qz, qy = az, ay, bz, by
					if e == 2 then
						pz, py, qz, qy = bz, by, cz, cy
					elseif e == 3 then
						pz, py, qz, qy = cz, cy, az, ay
					end
					local steps = math.ceil(math.max(math.abs(qz - pz), math.abs(qy - py)) * 2)
					for s = 0, steps do
						local k = if steps > 0 then s / steps else 0
						mark(pz + (qz - pz) * k, py + (qy - py) * k)
					end
				end
				-- the inside (cell centres)
				local area = (bz - az) * (cy - ay) - (by - ay) * (cz - az)
				if math.abs(area) > 1e-9 then
					for c2 = math.max(0, math.floor(math.min(az, bz, cz))), math.min(gz - 1, math.floor(math.max(az, bz, cz))) do
						for r = math.max(0, math.floor(math.min(ay, by, cy))), math.min(gy - 1, math.floor(math.max(ay, by, cy))) do
							local pz, py = c2 + 0.5, r + 0.5
							local w0 = ((bz - pz) * (cy - py) - (by - py) * (cz - pz)) / area
							local w1 = ((cz - pz) * (ay - py) - (cy - py) * (az - pz)) / area
							if w0 >= 0 and w1 >= 0 and w0 + w1 <= 1 then
								occ[c2 * gy + r + 1] = 1
							end
						end
					end
				end
			end
		end
		step(m * 2)
	else
		for i = 1, n do
			if isHead[i] then
				local fz, fy = (pos[i * 3] - z0) / cs, (pos[i * 3 - 1] - y0) / cs
				for ez = -1, 1 do
					for ey = -1, 1 do
						mark(fz + ez, fy + ey)
					end
				end
			end
		end
	end
	-- 3. the columns ahead of `from`: the empty cells between their lowest and highest shadow
	local enclosed = table.create(gz * gy, 0)
	for c = 0, gz - 1 do
		if z0 + (c + 0.5) * cs <= -o.from * L then
			local lo, hi = -1, -1
			for r = 0, gy - 1 do
				if occ[c * gy + r + 1] == 1 then
					if lo < 0 then
						lo = r
					end
					hi = r
				end
			end
			for r = lo + 1, hi - 1 do
				if occ[c * gy + r + 1] == 0 then
					enclosed[c * gy + r + 1] = 1
				end
			end
		end
	end
	-- 4. their pieces (a jump of up to BRIDGE columns along a row joins them); the mouth
	local label = table.create(gz * gy, 0)
	local best, bestSpan, bestArea = 0, 0, 0
	local pieces = 0
	local stack: { number } = {}
	local function visit(c: number, r: number, id: number)
		if c >= 0 and c < gz and r >= 0 and r < gy then
			local j = c * gy + r + 1
			if enclosed[j] == 1 and label[j] == 0 then
				label[j] = id
				table.insert(stack, j)
			end
		end
	end
	for first = 1, gz * gy do
		if enclosed[first] == 1 and label[first] == 0 then
			pieces += 1
			local id = pieces
			label[first] = id
			table.insert(stack, first)
			local cMin, cMax, area = gz, -1, 0
			while #stack > 0 do
				local cell = table.remove(stack) :: number
				area += 1
				local c, r = (cell - 1) // gy, (cell - 1) % gy
				cMin, cMax = math.min(cMin, c), math.max(cMax, c)
				visit(c, r - 1, id)
				visit(c, r + 1, id)
				for j = 1, bridge + 1 do
					visit(c - j, r, id)
					visit(c + j, r, id)
				end
			end
			local span = cMax - cMin + 1
			local front = z0 + cMin * cs
			if front <= -0.5 * L and (span > bestSpan or (span == bestSpan and area > bestArea)) then
				best, bestSpan, bestArea = id, span, area
			end
		end
	end
	step(gz * gy)
	local function render()
		if not view then
			return
		end
		local fromCol = math.floor((-o.from * L - z0) / cs)
		for r = gy - 1, 0, -1 do
			local row = table.create(gz, " ")
			for c = 0, gz - 1 do
				local j = c * gy + r + 1
				row[c + 1] = if occ[j] == 1
					then "#"
					elseif label[j] ~= 0 and label[j] == best then "o"
					elseif enclosed[j] == 1 then "."
					elseif c == fromCol then "|"
					else " "
			end
			table.insert(view, table.concat(row))
		end
	end
	if best == 0 then
		render()
		return nil, `no opening between the jaws in the side view ({pieces} enclosed gaps, none at the front)`
	end
	-- the opening per column: its bottom (the lower jaw's top) and top (the upper jaw's underside)
	local bot: { [number]: number } = {}
	local top: { [number]: number } = {}
	local cMin, cMax, tallest = gz, -1, 0
	for c = 0, gz - 1 do
		local lo, hi = -1, -1
		for r = 0, gy - 1 do
			if label[c * gy + r + 1] == best then
				if lo < 0 then
					lo = r
				end
				hi = r
			end
		end
		if lo >= 0 then
			bot[c] = y0 + lo * cs
			top[c] = y0 + (hi + 1) * cs
			cMin, cMax = math.min(cMin, c), math.max(cMax, c)
			tallest = math.max(tallest, hi - lo + 1)
		end
	end
	if cMax - cMin + 1 < o.minColumns or tallest * cs < o.gapMin * L then
		render()
		return nil,
			`the opening is too small ({cMax - cMin + 1} columns, {math.floor(tallest * cs / L * 1000 + 0.5) / 10}% of the snout high)`
	end
	-- the bounds to the faces (the raster's are a cell out): per column, the highest face under the opening's middle
	-- and the lowest over it, over the column's width
	if tris and faced then
		local under: { [number]: number } = {}
		local over: { [number]: number } = {}
		local cy: { number }, cz: { number } = { 0, 0, 0 }, { 0, 0, 0 }
		local m = #tris // 3
		for f = 0, m - 1 do
			local a, b, c = tris[f * 3 + 1], tris[f * 3 + 2], tris[f * 3 + 3]
			if isHead[a] and isHead[b] and isHead[c] then
				cy[1], cy[2], cy[3] = pos[a * 3 - 1], pos[b * 3 - 1], pos[c * 3 - 1]
				cz[1], cz[2], cz[3] = pos[a * 3], pos[b * 3], pos[c * 3]
				local first = math.max(cMin, math.floor((math.min(cz[1], cz[2], cz[3]) - z0) / cs))
				local last = math.min(cMax, math.floor((math.max(cz[1], cz[2], cz[3]) - z0) / cs))
				for col = first, last do
					local t, u = top[col], bot[col]
					if t and u then
						local lo, hi = clipY(cy, cz, z0 + col * cs, z0 + (col + 1) * cs)
						local middle = (t + u) / 2
						if hi <= middle then
							under[col] = math.max(under[col] or -INF, hi)
						elseif lo >= middle then
							over[col] = math.min(over[col] or INF, lo)
						end
					end
				end
			end
		end
		step(m)
		for col = cMin, cMax do
			if under[col] and over[col] and over[col] > under[col] then
				bot[col], top[col] = under[col], over[col]
			end
		end
	end
	-- 5. the opening's top and bottom as lines; the seam halfway between them, the corner where they meet (else the
	-- opening's back end; at most APEX behind it)
	local zs: { number }, ts: { number }, bs: { number } = {}, {}, {}
	for c = cMin, cMax do
		local t, b = top[c], bot[c]
		if t and b then
			table.insert(zs, z0 + (c + 0.5) * cs)
			table.insert(ts, t)
			table.insert(bs, b)
		end
	end
	local aT, bT = fitLine(zs, ts)
	local aB, bB = fitLine(zs, bs)
	local a0, slope = (aT + aB) / 2, (bT + bB) / 2
	local function seamAt(z: number): number
		return a0 + slope * z
	end
	-- 6. the corner and the hinge behind and under it
	local zc = z0 + (cMax + 1) * cs
	if bB - bT > 1e-9 then
		local meet = (aT - aB) / (bB - bT)
		if meet > zc then
			zc = math.min(meet, zc + APEX * L)
		end
	end
	local yc = seamAt(zc)
	local zh = zc + o.hinge.back * L
	local yh = yc - o.hinge.down * L
	local function column(z: number): number
		return math.floor((z - z0) / cs)
	end
	local function inMouth(c: number): boolean
		return c >= cMin and c <= cMax
	end
	-- 7. the lower jaw: under the opening in its columns, and what hangs off it along the mesh
	local graph = LegFold.graph(pos, tris, cs * 1.6, step)
	local nodeOf, nn, start, adj = graph.nodeOf, graph.nn, graph.start, graph.adj
	local ny, nz = graph.ny, graph.nz
	local skin = table.create(nn, 0)
	for i = 1, n do
		local node = nodeOf[i]
		skin[node] = math.max(skin[node], head[i])
	end
	local inJaw = table.create(nn, false)
	local queue: { number } = {}
	local lowest = INF
	for i = 1, n do
		if isHead[i] then
			local c = column(pos[i * 3])
			local b = bot[c]
			local y = pos[i * 3 - 1]
			if inMouth(c) and b and y <= b + 0.5 * cs and not inJaw[nodeOf[i]] then
				inJaw[nodeOf[i]] = true
				table.insert(queue, nodeOf[i])
				lowest = math.min(lowest, y)
			end
		end
	end
	if #queue == 0 then
		return nil, "nothing under the opening"
	end
	local floorY = lowest - o.below * L
	local backLimit = zh + o.blend.back * L
	local function joins(b: number): boolean
		if inJaw[b] or skin[b] < o.grow or nz[b] > backLimit or ny[b] < floorY then
			return false
		end
		local c = column(nz[b])
		local under = bot[c]
		if inMouth(c) and under then
			return ny[b] <= under + 0.5 * cs
		end
		return ny[b] < seamAt(nz[b])
	end
	local at = 1
	while at <= #queue do
		local node = queue[at]
		at += 1
		for e = start[node], start[node + 1] - 1 do
			local b = adj[e]
			if joins(b) then
				inJaw[b] = true
				table.insert(queue, b)
			end
		end
	end
	step(#queue * 4)
	-- 8. the shares: the blend behind the hinge, and under the seam where the opening ends
	local idx: { number } = {}
	local share: { number } = {}
	local full = 0
	local span = (o.blend.back + o.blend.front) * L
	for i = 1, n do
		if inJaw[nodeOf[i]] then
			local y, z = pos[i * 3 - 1], pos[i * 3]
			local along = smooth((zh - z + o.blend.back * L) / span)
			local c = column(z)
			local down = if inMouth(c) and bot[c] then 1 else smooth((seamAt(z) - y) / (o.blend.seam * L))
			local s = along * down
			if s > LEAST then
				table.insert(idx, i)
				table.insert(share, s)
				if s >= 0.999 then
					full += 1
				end
			end
		end
	end
	if full == 0 then
		return nil, "no vertex moves wholly with the jaw"
	end
	-- 9. the closed turn: across the opening, on lines three a column and one through every head vertex there (the
	-- teeth's tips), the lower jaw's top and the upper jaw's underside from the faces (else the side view's), about the
	-- hinge; a column a tooth closes counts as touching on the seam. The upper one's angle at each lower point's
	-- distance from the hinge, less the lower point's, is how far the jaw can turn up there
	local lines: { number } = {}
	for c = cMin, cMax do
		for j = 0, 2 do
			table.insert(lines, z0 + (c + (j + 0.5) / 3) * cs)
		end
	end
	if tris and faced then
		for i = 1, n do
			if isHead[i] and inMouth(column(pos[i * 3])) then
				table.insert(lines, pos[i * 3])
			end
		end
	end
	table.sort(lines)
	-- (lines closer than a twelfth of a cell are one)
	local kept: { number } = {}
	for _, z in lines do
		if #kept == 0 or z - kept[#kept] > cs / 12 then
			table.insert(kept, z)
		end
	end
	lines = kept
	local upY = table.create(#lines, INF)
	local lowY = table.create(#lines, -INF)
	if tris and faced then
		local cy: { number }, cz: { number } = { 0, 0, 0 }, { 0, 0, 0 }
		local m = #tris // 3
		for f = 0, m - 1 do
			local a, b, c = tris[f * 3 + 1], tris[f * 3 + 2], tris[f * 3 + 3]
			if isHead[a] and isHead[b] and isHead[c] then
				cy[1], cy[2], cy[3] = pos[a * 3 - 1], pos[b * 3 - 1], pos[c * 3 - 1]
				cz[1], cz[2], cz[3] = pos[a * 3], pos[b * 3], pos[c * 3]
				local zLo, zHi = math.min(cz[1], cz[2], cz[3]), math.max(cz[1], cz[2], cz[3])
				-- the first line at or past the face (a binary search)
				local lo, hi = 1, #lines + 1
				while lo < hi do
					local mid = (lo + hi) // 2
					if lines[mid] < zLo then
						lo = mid + 1
					else
						hi = mid
					end
				end
				local j = lo
				while j <= #lines and lines[j] <= zHi do
					local z = lines[j]
					local col = column(z)
					local t, u = top[col], bot[col]
					if t and u then
						local yLo2, yHi2 = clipY(cy, cz, z, z)
						local middle = (t + u) / 2
						if yLo2 <= yHi2 then
							if yHi2 <= middle then
								lowY[j] = math.max(lowY[j], yHi2)
							elseif yLo2 >= middle then
								upY[j] = math.min(upY[j], yLo2)
							end
						end
					end
					j += 1
				end
				step(j - lo + 1)
			end
		end
	end
	local ur: { number }, ua: { number } = {}, {}
	local lr: { number }, la: { number } = {}, {}
	for j, z in lines do
		local col = column(z)
		local t, b = top[col], bot[col]
		if not t or not b then
			t, b = seamAt(z), seamAt(z)
		elseif upY[j] < INF and lowY[j] > -INF and upY[j] > lowY[j] then
			t, b = upY[j], lowY[j]
		end
		local f = zh - z
		local ut, ub = t - yh, b - yh
		table.insert(ur, math.sqrt(f * f + ut * ut))
		table.insert(ua, math.atan2(ut, f))
		table.insert(lr, math.sqrt(f * f + ub * ub))
		table.insert(la, math.atan2(ub, f))
	end
	-- (the upper points from the hinge outward)
	local order: { number } = {}
	for j = 1, #ur do
		order[j] = j
	end
	table.sort(order, function(p: number, q: number): boolean
		return ur[p] < ur[q]
	end)
	local function upperAt(r: number): number?
		local first, last = order[1], order[#order]
		if r < ur[first] - cs or r > ur[last] + cs then
			return nil
		end
		if r <= ur[first] then
			return ua[first]
		end
		for j = 2, #order do
			local p, q = order[j - 1], order[j]
			if r <= ur[q] then
				local d = ur[q] - ur[p]
				local w = if d > 1e-9 then (r - ur[p]) / d else 1
				return ua[p] + (ua[q] - ua[p]) * w
			end
		end
		return ua[last]
	end
	local rMin, rMax = INF, -INF
	for j = 1, #lr do
		rMin, rMax = math.min(rMin, lr[j]), math.max(rMax, lr[j])
	end
	local rFrom = rMin + o.contact * (rMax - rMin)
	local contact, tipR, tipA = INF, -INF, 0
	for j = 1, #lr do
		local u = upperAt(lr[j])
		if u then
			local gap = u - la[j]
			if lr[j] >= rFrom then
				contact = math.min(contact, gap)
			end
			if lr[j] > tipR then
				tipR, tipA = lr[j], gap
			end
		end
	end
	if contact == INF or tipR <= 0 then
		return nil, "the jaws do not face each other"
	end
	local closed = math.clamp(contact - o.margin * L / tipR, 0, math.rad(o.maxClosed))
	if o.closed then
		closed = math.rad(o.closed)
	end
	step(#lr * #lr)
	local plan: Plan = {
		idx = idx,
		share = share,
		hinge = { yh, zh },
		closed = closed,
		snout = L,
		corner = { yc, zc },
		seam = { a0, slope },
		columns = cMax - cMin + 1,
		full = full,
		tipRadius = tipR,
		tipAngle = tipA,
	}
	local function r2(x: number): number
		return math.floor(x * 100 + 0.5) / 100
	end
	return plan,
		`{#idx} jaw vertices ({full} whole), hinge {r2(-zh)} ahead of and {r2(-yh)} under the head joint, `
			.. `closed {r2(math.deg(closed))} deg, opening over {cMax - cMin + 1} columns`
end

-- A vertex's skin with `share` of its head skin (the bones of `headSet`) moved onto bone `jaw`: at most four bones,
-- summing to 1 (the strongest kept). Nil when it has no head skin (it is left as it is).
function JawHinge.reweigh(
	bones: { number },
	weights: { number },
	headSet: { [number]: boolean },
	share: number,
	jaw: number
): ({ number }?, { number }?)
	local moved = 0
	local total = 0
	for k, b in bones do
		local w = weights[k] or 0
		total += w
		if headSet[b] then
			moved += w * share
		end
	end
	if moved <= 0 or total <= 0 then
		return nil, nil
	end
	local list: { { bone: number, w: number } } = {}
	for k, b in bones do
		local w = weights[k] or 0
		if headSet[b] then
			w *= 1 - share
		end
		if w > 1e-6 and b ~= jaw then
			table.insert(list, { bone = b, w = w })
		end
	end
	table.insert(list, { bone = jaw, w = moved })
	table.sort(list, function(p, q): boolean
		return p.w > q.w
	end)
	local outB: { number } = {}
	local outW: { number } = {}
	local sum = 0
	for k = 1, math.min(4, #list) do
		outB[k] = list[k].bone
		outW[k] = list[k].w
		sum += list[k].w
	end
	for k = 1, #outW do
		outW[k] /= sum
	end
	return outB, outW
end

-- The jaw's opening (degrees from closed) of action `name` (its timing `action`, hit at `hit`) `t` s into its run: the
-- data's keys eased between, 0 before the first, the last held after it; 0 for an action without keys.
function JawHinge.open(o: Options, name: string, action: ActionFx.Timed, hit: number, t: number): number
	local keys = o.actions[name]
	if not keys or #keys == 0 then
		return 0
	end
	local prevT, prevV = 0, 0
	for j, key in keys do
		local kt = ActionFx.time(action, hit, markOf(key.at))
		if t <= kt then
			if j == 1 then
				return if t >= kt then key.open else 0
			end
			if kt - prevT < 1e-6 then
				return key.open
			end
			return prevV + (key.open - prevV) * smooth((t - prevT) / (kt - prevT))
		end
		prevT, prevV = kt, key.open
	end
	return prevV
end

-- A point (H: y, z) turned up about the hinge by `angle` (rad; the jaw's own turn: + closes).
function JawHinge.turn(plan: Plan, angle: number, y: number, z: number): (number, number)
	local yh, zh = plan.hinge[1], plan.hinge[2]
	local u, f = y - yh, zh - z
	local c, s = math.cos(angle), math.sin(angle)
	return yh + f * s + u * c, zh - (f * c - u * s)
end

-- The opening at the lower jaw's front (studs, the chord) with the jaw turned by `angle` (0: as modelled).
function JawHinge.gap(plan: Plan, angle: number): number
	return 2 * plan.tipRadius * math.sin((plan.tipAngle - angle) / 2)
end

return JawHinge
