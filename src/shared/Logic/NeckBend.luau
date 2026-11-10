--!strict
-- Template animation (owner 2026-11-10: "modele poruszają się nie poruszając głową tak 2d"): the head of a model
-- without bones (one rigid mesh, Data/RigidRigs `gaze`), found from its vertices alone, so client/Anim/MeshHead can
-- hang it on a bone it adds in code and Logic/HeadGaze can turn it. Pure (Lune).
-- * The axis: forward (-z) tilted up by `rise`. The tip: the vertex furthest along it near the midline (within `mid`
--   of the half-width), above `floor` and inside `side`.
-- * The head's piece: what lies ahead of a section across the axis and is joined to the tip along the faces (vertices
--   at one position welded: a texture seam does not cut it), so the legs, the wings and the pincers that reach ahead
--   but join the body behind it stay; loose shells inside its box (eyes, teeth) go with it.
-- * The neck: within `seek` (shares of the length along the axis, from the tip) the first section of the piece
--   narrower than the widest one ahead of it (NARROW: the back of the skull); the head turns whole up to it and the
--   neck bends over the blend behind it (the cut half the blend further back). None: the cut lies at `neck`.
-- * The share of the head's turn: 1 ahead of the cut, 0 behind it, a smooth step over `blend` of the length about
--   it, soft at `floor` and at `side` too: no face is torn, the neck bends.
-- * The joint: the section's centre at the cut, `pivot` of the blend's half behind it.
-- The frame ("N", as Logic/LegFold): the mesh's units turned to the look's axes (x right, y up, z back).

local LegFold = require("./LegFold")
local RigidRigs = require("../Data/RigidRigs")

local NeckBend = {}

export type Options = RigidRigs.Gaze

export type Plan = {
	idx: { number }, -- the vertices that turn with the head (1-based into pos)
	share: { number }, -- their share of its turn (0..1]
	whole: number, -- how many of them turn fully
	loose: number, -- the loose shells taken with the head (eyes, teeth)
	tip: { number }, -- the tip (N)
	joint: { number }, -- the joint the head turns about (N)
	axis: { number }, -- forward along the head (unit, N)
	length: number, -- the model's length along the axis
	cut: number, -- the cut's distance behind the tip along the axis
	half: number, -- the blend's half width
	neck: boolean, -- the cut lies behind where the head narrows into the neck (else at `neck`)
	section: number, -- the section's size where the head narrows, else at the cut (the mean of its width and height)
}

local INF = math.huge
-- Sections across the axis over the model's length.
local SLICES = 48
-- A neck is narrower than the widest section ahead of it by this share; a section spans the slices about it until
-- they hold SECTION_MIN vertices (at most SECTION_REACH each way).
local NARROW = 0.8
local SECTION_MIN, SECTION_REACH = 12, 3
-- The cut lies at least this many of the blend's half behind the tip (a part of the head turns whole).
local HEAD_MIN = 1.25
-- The soft edges of `floor` (share of the height) and of `side` (share of the band), each way.
local FLOOR_SOFT = 0.04
local SIDE_SOFT = 0.25
-- A loose shell goes with the head when it lies inside the head's box (grown by LOOSE_GROW of its size each way)
-- and has at most LOOSE_MAX of the head's vertices.
local LOOSE_GROW = 0.1
local LOOSE_MAX = 0.5
-- Shares under this are none, over 1 - LEAST whole.
local LEAST = 0.002
-- A head needs at least this many vertices turning fully.
local MIN_WHOLE = 4
-- The views printed in Studio: columns along the length, rows at most.
local VIEW_COLS = 56
local VIEW_ROWS = 30

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The views of the plan for Studio (the front on the left): the side (y up) and the top; `H` the head, `+` the
-- bend, `#` the body, `*` the joint.
local function draw(view: { string }, graph: LegFold.Graph, share: { number }, box: { number }, joint: { number })
	local lx, ly, lz, hx, hy, hz = box[1], box[2], box[3], box[4], box[5], box[6]
	local cell = math.max(hz - lz, 1e-6) / VIEW_COLS
	local function one(title: string, across: (a: number) -> number, lo: number, hi: number, jAcross: number)
		local rows = math.clamp(math.ceil((hi - lo) / (2 * cell)), 1, VIEW_ROWS)
		local step = math.max(hi - lo, 1e-6) / rows
		local grid = table.create(rows * VIEW_COLS, 0)
		local function put(c: number, r: number, v: number)
			local at = (math.clamp(r, 0, rows - 1)) * VIEW_COLS + math.clamp(c, 0, VIEW_COLS - 1) + 1
			if v > grid[at] then
				grid[at] = v
			end
		end
		for a = 1, graph.nn do
			local s = share[a]
			local v = if s >= 1 - LEAST then 3 elseif s > 0 then 2 else 1
			put(math.floor((graph.nz[a] - lz) / cell), math.floor((hi - across(a)) / step), v)
		end
		put(math.floor((joint[3] - lz) / cell), math.floor((hi - jAcross) / step), 4)
		table.insert(view, title)
		local chars = { " ", "#", "+", "H", "*" }
		for r = 0, rows - 1 do
			local line = table.create(VIEW_COLS, " ")
			for c = 0, VIEW_COLS - 1 do
				line[c + 1] = chars[grid[r * VIEW_COLS + c + 1] + 1]
			end
			table.insert(view, (string.gsub(table.concat(line), "%s+$", "")))
		end
	end
	one("side (front left, up top):", function(a: number): number
		return graph.ny[a]
	end, ly, hy, joint[2])
	one("top (front left, right side top):", function(a: number): number
		return graph.nx[a]
	end, lx, hx, joint[1])
end

-- The plan of a mesh: `pos` its vertices (N, flat x y z), `tris` its triangles (flat, 1-based; nil: the pieces by
-- nearness), `o` the model's `gaze`, `midline` the look's middle (x in N; nil: the middle of the mesh's box);
-- `yield` (if given) is called now and then so a client can spread the work over frames; `view` (if given) gets the
-- side and the top views. Nil and why when the head cannot be found, else the plan and what was found.
function NeckBend.plan(
	pos: { number },
	tris: { number }?,
	o: Options,
	midline: number?,
	yield: (() -> ())?,
	view: { string }?
): (Plan?, string)
	local n = #pos // 3
	if n < 16 then
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
	-- the box
	local lx, ly, lz, hx, hy, hz = INF, INF, INF, -INF, -INF, -INF
	for i = 0, n - 1 do
		local x, y, z = pos[i * 3 + 1], pos[i * 3 + 2], pos[i * 3 + 3]
		lx, ly, lz = math.min(lx, x), math.min(ly, y), math.min(lz, z)
		hx, hy, hz = math.max(hx, x), math.max(hy, y), math.max(hz, z)
	end
	local width, height, depth = hx - lx, hy - ly, hz - lz
	if width <= 0 or height <= 0 or depth <= 0 then
		return nil, "a flat mesh"
	end
	local cx = midline or (lx + hx) / 2
	local half = math.max(hx - cx, cx - lx)
	-- the axis (forward, tilted up), across it upward, and the soft edges of the floor and the side band
	local rise = math.rad(o.rise)
	local ay, az = math.sin(rise), -math.cos(rise)
	local uy, uz = -az, ay
	local floorAt, floorSoft = ly + o.floor * height, FLOOR_SOFT * height
	local band = if o.side then o.side * half else nil
	local function edge(x: number, y: number): number
		local s = if o.floor > 0 then smooth((y - floorAt + floorSoft) / (2 * floorSoft)) else 1
		if band then
			local soft = SIDE_SOFT * band
			s *= 1 - smooth((math.abs(x - cx) - band + soft) / (2 * soft))
		end
		return s
	end
	-- the tip
	local mid = o.mid * half
	local tipI, tipD, lowD = 0, -INF, INF
	for i = 0, n - 1 do
		local x, y, z = pos[i * 3 + 1], pos[i * 3 + 2], pos[i * 3 + 3]
		local d = y * ay + z * az
		lowD = math.min(lowD, d)
		if d > tipD and math.abs(x - cx) <= mid and edge(x, y) >= 1 - LEAST then
			tipI, tipD = i + 1, d
		end
	end
	step(n)
	if tipI == 0 then
		return nil, "no tip (nothing near the midline above the floor and inside the side band)"
	end
	local length = tipD - lowD
	if length <= 0 then
		return nil, "nothing behind the tip"
	end
	-- the welded graph, each node's distance behind the tip and its soft edges
	-- (no faces: the neighbours within a radius from the vertices' mean spacing over about half the box's surface)
	local spacing = math.sqrt((width * height + height * depth + width * depth) / n)
	local graph = LegFold.graph(pos, tris, math.max(math.max(width, height, depth) / 64 * 1.6, 2 * spacing), step)
	local nodeOf, nn, start, adj = graph.nodeOf, graph.nn, graph.start, graph.adj
	local nx, ny, nz = graph.nx, graph.ny, graph.nz
	local t = table.create(nn, 0)
	local e = table.create(nn, 0)
	for a = 1, nn do
		t[a] = tipD - (ny[a] * ay + nz[a] * az)
		e[a] = edge(nx[a], ny[a])
	end
	step(nn)
	local tipNode = nodeOf[tipI]
	-- the nodes joined to `from` ahead of `limit` inside the soft edges, marked `id` (unmarked: below 3 and not
	-- `skip`); their count
	local mark = table.create(nn, 0)
	local queue = table.create(nn, 0)
	local function fill(from: number, limit: number, id: number, skip: number): number
		mark[from] = id
		queue[1] = from
		local head, tail = 1, 1
		while head <= tail do
			local a = queue[head]
			head += 1
			for k = start[a], start[a + 1] - 1 do
				local b = adj[k]
				local m = mark[b]
				if m ~= id and m ~= skip and m < 3 and t[b] <= limit and e[b] > 0 then
					mark[b] = id
					tail += 1
					queue[tail] = b
				end
			end
		end
		step(tail * 4)
		return tail
	end
	-- the neck: the first section of the head's piece in the window narrower than the widest ahead of it; the
	-- head keeps a part that turns whole (the cut at least HEAD_MIN of the blend's half behind the tip)
	local slice = length / SLICES
	local hb = math.max(o.blend * length / 2, length * 1e-4)
	local least = HEAD_MIN * hb
	local cut = math.max(o.neck * length, least)
	local found = false
	local section = 0
	local seek = o.seek
	local from, to = if seek then math.max(seek[1] * length, least) else 0, if seek then seek[2] * length else 0
	if to > from then
		fill(tipNode, to, 1, -1)
		local count = math.max(1, math.ceil(to / slice))
		local x0, x1 = table.create(count, INF), table.create(count, -INF)
		local u0, u1 = table.create(count, INF), table.create(count, -INF)
		local held = table.create(count, 0)
		for a = 1, nn do
			if mark[a] == 1 then
				local k = math.clamp(math.floor(t[a] / slice) + 1, 1, count)
				local u = ny[a] * uy + nz[a] * uz
				x0[k], x1[k] = math.min(x0[k], nx[a]), math.max(x1[k], nx[a])
				u0[k], u1[k] = math.min(u0[k], u), math.max(u1[k], u)
				held[k] += 1
			end
		end
		-- each section over its slices and the ones about it until they hold SECTION_MIN vertices (a sparse mesh)
		local ahead = 0
		local best, bestK = 0, 0
		local first = math.floor(from / slice) + 1
		local sizes: { string }? = if view then {} else nil
		for k = 1, count do
			local xa, xb, ua, ub, got = INF, -INF, INF, -INF, 0
			for r = 0, SECTION_REACH do
				for j = k - r, k + r, math.max(1, 2 * r) do
					if j >= 1 and j <= count then
						xa, xb = math.min(xa, x0[j]), math.max(xb, x1[j])
						ua, ub = math.min(ua, u0[j]), math.max(ub, u1[j])
						got += held[j]
					end
				end
				if got >= SECTION_MIN then
					break
				end
			end
			local w = if got > 0 then ((xb - xa) + (ub - ua)) / 2 else -1
			if sizes then
				table.insert(sizes, string.format(if k >= first then "%.2f" else "(%.2f)", w))
			end
			if bestK == 0 and k >= first and w > 0 and w < NARROW * ahead then
				best, bestK = w, k
			end
			ahead = math.max(ahead, w)
		end
		if bestK > 0 then
			-- the head turns whole up to where it narrows into the neck, the neck bends behind it
			cut = math.max((bestK - 0.5) * slice + hb, least)
			found = true
			section = best
		end
		if view and sizes then
			-- (each section's size from the tip back, one per 1/SLICES of the length; before the window in brackets)
			table.insert(
				view,
				`sections from the tip (every {math.round(slice * 1000) / 1000}): {table.concat(sizes, " ")}`
			)
		end
		for a = 1, nn do
			mark[a] = 0
		end
	end
	-- the head's piece ahead of the blend's end, and each node's share
	local limit = cut + hb
	local headCount = fill(tipNode, limit, 2, -1)
	local share = table.create(nn, 0)
	local bx0, by0, bz0, bx1, by1, bz1 = INF, INF, INF, -INF, -INF, -INF
	for a = 1, nn do
		if t[a] <= limit and e[a] > 0 then
			share[a] = (1 - smooth((t[a] - cut + hb) / (2 * hb))) * e[a]
		end
		if mark[a] == 2 then
			bx0, by0, bz0 = math.min(bx0, nx[a]), math.min(by0, ny[a]), math.min(bz0, nz[a])
			bx1, by1, bz1 = math.max(bx1, nx[a]), math.max(by1, ny[a]), math.max(bz1, nz[a])
		end
	end
	step(nn)
	-- loose shells ahead of the blend's end inside the head's box (grown) go with it; other pieces stay
	local gx, gy, gz = (bx1 - bx0) * LOOSE_GROW, (by1 - by0) * LOOSE_GROW, (bz1 - bz0) * LOOSE_GROW
	local taken: { [number]: boolean } = { [2] = true }
	local loose = 0
	local id = 2
	for a = 1, nn do
		if mark[a] < 3 and mark[a] ~= 2 and t[a] <= limit and e[a] > 0 then
			id += 1
			local count = fill(a, limit, id, 2)
			local inside = count <= LOOSE_MAX * headCount
			for k = 1, if inside then count else 0 do
				local b = queue[k]
				if
					nx[b] < bx0 - gx
					or nx[b] > bx1 + gx
					or ny[b] < by0 - gy
					or ny[b] > by1 + gy
					or nz[b] < bz0 - gz
					or nz[b] > bz1 + gz
				then
					inside = false
					break
				end
			end
			if inside then
				taken[id] = true
				loose += 1
			end
		end
	end
	for a = 1, nn do
		if not taken[mark[a]] then
			share[a] = 0
		end
	end
	step(nn)
	-- the joint: the centre of the head's section at the cut, `pivot` of the blend's half behind it
	local tx, ty, tz = pos[tipI * 3 - 2], pos[tipI * 3 - 1], pos[tipI * 3]
	local jx, jy, jz = tx, ty - ay * cut, tz - az * cut
	for widen = 1, 3 do
		local sx, sy, sz, sn = 0, 0, 0, 0
		local xa, xb, ua, ub = INF, -INF, INF, -INF
		for a = 1, nn do
			if mark[a] == 2 and math.abs(t[a] - cut) <= slice * widen then
				sx, sy, sz, sn = sx + nx[a], sy + ny[a], sz + nz[a], sn + 1
				local u = ny[a] * uy + nz[a] * uz
				xa, xb, ua, ub = math.min(xa, nx[a]), math.max(xb, nx[a]), math.min(ua, u), math.max(ub, u)
			end
		end
		if sn >= 3 then
			jx, jy, jz = sx / sn, sy / sn, sz / sn
			if not found then
				section = ((xb - xa) + (ub - ua)) / 2
			end
			break
		end
	end
	local back = o.pivot * hb
	jy, jz = jy - ay * back, jz - az * back
	-- each vertex its node's share
	local idx: { number } = {}
	local out: { number } = {}
	local whole = 0
	for i = 1, n do
		local s = share[nodeOf[i]]
		if s >= LEAST then
			if s > 1 - LEAST then
				s = 1
				whole += 1
			end
			table.insert(idx, i)
			table.insert(out, s)
		end
	end
	step(n)
	if view then
		draw(view, graph, share, { lx, ly, lz, hx, hy, hz }, { jx, jy, jz })
	end
	if whole < MIN_WHOLE then
		return nil, `the head is too small ({whole} vertices turn fully)`
	end
	local plan: Plan = {
		idx = idx,
		share = out,
		whole = whole,
		loose = loose,
		tip = { tx, ty, tz },
		joint = { jx, jy, jz },
		axis = { 0, ay, az },
		length = length,
		cut = cut,
		half = hb,
		neck = found,
		section = section,
	}
	return plan, if found then "the neck found" else "the neck at the data's share"
end

-- Each vertex's share (0..1) of the head's turn, for `n` vertices.
function NeckBend.shares(plan: Plan, n: number): { number }
	local out = table.create(n, 0)
	for j, i in plan.idx do
		out[i] = plan.share[j]
	end
	return out
end

return NeckBend
