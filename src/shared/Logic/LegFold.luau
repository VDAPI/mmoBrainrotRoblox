--!strict
-- Template animation (owner 2026-10-26: "nogi się nie składają, jedynie postać przewraca się na bok"): the legs of a
-- model without bones (one rigid mesh: caveSpider, desertScorpion) curl in on its death like a dead spider's: each leg
-- folds at the hip, the knee and the ankle toward the underside and the middle. client/Anim/MeshFold moves the
-- vertices of an EditableMesh with it; without one (an older device, the game setting off, the memory budget spent)
-- the rigid death plays as before. Pure (Lune), in two parts:
-- 1. `plan`, once per model (the client caches it): the mesh's vertices sorted into the body and the legs, with no
--    bones or names to go by.
--    * Body: in the top view (the faces rasterised) the region a disc of `open` x the outline's inscribed radius
--      fits in (a morphological opening: the thin legs drop out, the cephalothorax and the abdomen stay); blobs far
--      thinner or smaller than the biggest one (a pincer's hand) are not body.
--    * Legs: what lies outside the body falls into connected pieces (the faces; vertices at one position welded,
--      so the texture seams do not cut a leg). A piece is a leg when it reaches the ground (`ground`) and is long
--      enough (`reach`): the scorpion's raised tail is not. A piece with several far branches (legs fused at the
--      hips) is split between them.
--    * Along each leg: the geodesic distance from the ring where it leaves the body (else from its end nearest to
--      the body), the skeleton from slices of it; the knee at the arch's top (else at the sharpest bend, else 40 % of
--      the length), the ankle half way from the knee to the tip; each segment's elevation in the leg's upright plane
--      (the vertical plane through the hip and the tip).
-- 2. `pose`: the hip, the knee and the ankle turn about their rest points (the innermost first) toward the folded
--    elevations of the model's data (Data/RigidRigs `fold.targets`, down and back under the body); the ankle and the
--    knee lead, the hip follows (the tips curl in off the ground instead of sweeping through it); a vertex near a
--    joint takes a share of its turn (a hinge, no pinching), the ring at the body does not move, each leg curls at
--    its own pace (the seed), legs pointing forward fold by `front.mul` (0: the scorpion's pincers stay). Writes the
--    folded leg vertices, no allocations. The plan keeps the mesh's box at every eighth of the fold, so
--    Logic/RigidMotion lowers the body exactly as far as the legs stop holding it up.
-- The frame of the plan ("N"): the mesh's own units turned to the look's axes (x right, y up, z back); the client
-- maps it to the mesh (`map`, a 3x4 affine) and its boxes to the look.

local NpcPose = require("./NpcPose")

local LegFold = {}

export type Options = {
	open: number, -- the opening disc's radius as a share of the body's inscribed radius (top view)
	ground: number, -- a leg reaches this close to the ground (share of the height)
	reach: number, -- a leg is at least this long (share of the larger horizontal size)
	minLegs: number,
	maxLegs: number,
	targets: { number }, -- the folded elevations (rad) of the femur, the tibia and the tarsus, going down the curl
	front: { cone: number, mul: number }?, -- legs within `cone` (rad) of forward fold by `mul`
	pace: number, -- each leg's pace: the curl's exponent within 1 ± pace
}

-- One leg: the hip (N), its horizontal direction, the knee and the ankle in its upright plane (u along the leg, v up,
-- from the hip), each joint's full turn (rad, + = down), its share; scratch of `pose`.
export type Leg = {
	hx: number,
	hy: number,
	hz: number,
	dx: number,
	dz: number,
	ku: number,
	kv: number,
	au: number,
	av: number,
	d1: number,
	d2: number,
	d3: number,
	mul: number,
	t1: number,
	t2: number,
	t3: number,
	c1: number,
	s1: number,
	c2: number,
	s2: number,
	c3: number,
	s3: number,
}
export type Box = { x0: number, y0: number, z0: number, x1: number, y1: number, z1: number }
export type Plan = {
	count: number, -- vertices of the mesh
	idx: { number }, -- each leg vertex's index in the mesh's vertex list
	leg: { number }, -- its leg
	u: { number }, -- its rest place in the leg's plane (from the hip: along, up, across)
	v: { number },
	w: { number },
	w1: { number }, -- its share of the hip's, the knee's, the ankle's turn
	w2: { number },
	w3: { number },
	legs: { Leg },
	pace: number,
	boxes: { Box }, -- the mesh's box (N) at fold 0, 1/8 .. 1 (the first: at rest)
}

local SQRT2 = math.sqrt(2)
local INF = math.huge
-- Top view: cells along the larger horizontal size (and a border of empty cells).
local GRID = 64
local BORDER = 2
-- Blobs of the opening kept as body: thick (share of the inscribed radius), big (share of the biggest blob) and
-- near the biggest (in opening discs).
local BLOB_THICK = 0.45
local BLOB_AREA = 0.12
local BLOB_NEAR = 2
-- A loose piece (a claw, a foot apart from its leg) joins a leg it comes this near to (cells, 3D).
local JOIN = 1.5
-- Far branches of a piece (beyond this share of its length) that make it several legs: each this big and this long.
local BRANCH_AT = 0.45
local BRANCH_SIZE = 0.06
local BRANCH_LONG = 0.75
-- Slices of a leg's skeleton; the knee is looked for in this share of the length.
local SLICES = 16
local ARCH_FROM, ARCH_TO = 0.12, 0.7
-- The turns are kept within these (rad).
local HIP_MIN, HIP_MAX = math.rad(-30), math.rad(170)
local BEND_MIN, BEND_MAX = math.rad(-40), math.rad(160)
-- The splay (negative fold) never more than this.
local SPLAY = -0.3
-- When each joint turns within the curl (from, to: shares of it): the ankle and the knee first, the hip after; the
-- hip first lifts the leg by up to HIP_LIFT (rad), so the curling tip comes in off the ground, never through it.
local ANKLE_FROM, ANKLE_TO = 0, 0.55
local KNEE_FROM, KNEE_TO = 0.05, 0.6
local HIP_FROM, HIP_TO = 0.45, 1
local HIP_LIFT, LIFT_TO = math.rad(35), 0.85
-- Each leg's own amplitude (a seed's): within 1 ± this.
local AMP = 0.06
-- The box is kept at this many steps of the fold, each the union over the paces (this many on each side of the
-- middle one) and the amplitudes a seed can give a leg.
local BOX_STEPS = 8
local BOX_PACES = 2
local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0 }

local function smooth(x: number): number
	local t = if x < 0 then 0 elseif x > 1 then 1 else x
	return t * t * (3 - 2 * t)
end

local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- The two-pass chamfer distance (cells: 1 straight, √2 diagonal) of every cell of the gx x gz grid to the nearest
-- cell whose `mask` is `want`.
local function chamfer(gx: number, gz: number, mask: { number }, want: number, out: { number })
	for i = 1, gx * gz do
		out[i] = if mask[i] == want then 0 else INF
	end
	for z = 0, gz - 1 do
		for x = 0, gx - 1 do
			local i = z * gx + x + 1
			local d = out[i]
			if d > 0 then
				if x > 0 then
					d = math.min(d, out[i - 1] + 1)
				end
				if z > 0 then
					d = math.min(d, out[i - gx] + 1)
					if x > 0 then
						d = math.min(d, out[i - gx - 1] + SQRT2)
					end
					if x < gx - 1 then
						d = math.min(d, out[i - gx + 1] + SQRT2)
					end
				end
				out[i] = d
			end
		end
	end
	for z = gz - 1, 0, -1 do
		for x = gx - 1, 0, -1 do
			local i = z * gx + x + 1
			local d = out[i]
			if d > 0 then
				if x < gx - 1 then
					d = math.min(d, out[i + 1] + 1)
				end
				if z < gz - 1 then
					d = math.min(d, out[i + gx] + 1)
					if x < gx - 1 then
						d = math.min(d, out[i + gx + 1] + SQRT2)
					end
					if x > 0 then
						d = math.min(d, out[i + gx - 1] + SQRT2)
					end
				end
				out[i] = d
			end
		end
	end
end

-- A binary min-heap of (node, distance) for Dijkstra (lazy: stale entries are skipped by the caller).
type Heap = { node: { number }, dist: { number }, n: number }

local function push(h: Heap, node: number, dist: number)
	local n = h.n + 1
	h.n = n
	local hn, hd = h.node, h.dist
	while n > 1 do
		local p = n // 2
		if hd[p] <= dist then
			break
		end
		hn[n], hd[n] = hn[p], hd[p]
		n = p
	end
	hn[n], hd[n] = node, dist
end

local function pop(h: Heap): (number, number)
	local hn, hd = h.node, h.dist
	local topNode, topDist = hn[1], hd[1]
	local n = h.n
	local lastNode, lastDist = hn[n], hd[n]
	h.n = n - 1
	n -= 1
	local i = 1
	while true do
		local c = i * 2
		if c > n then
			break
		end
		if c < n and hd[c + 1] < hd[c] then
			c += 1
		end
		if hd[c] >= lastDist then
			break
		end
		hn[i], hd[i] = hn[c], hd[c]
		i = c
	end
	if n >= 1 then
		hn[i], hd[i] = lastNode, lastDist
	end
	return topNode, topDist
end

-- A leg's turns at its own share `s` of the curl (-0.3 splayed .. 1) and amplitude: the ankle and the knee lead, the
-- hip follows, lifting the leg first (a splay turns them all alike).
local function bend(leg: Leg, s: number, amp: number)
	local s1, s2, s3 = s, s, s
	local lift = 0
	if s > 0 then
		s1 = smooth((s - HIP_FROM) / (HIP_TO - HIP_FROM))
		s2 = smooth((s - KNEE_FROM) / (KNEE_TO - KNEE_FROM))
		s3 = smooth((s - ANKLE_FROM) / (ANKLE_TO - ANKLE_FROM))
		lift = HIP_LIFT * math.sin(math.pi * math.min(1, s / LIFT_TO)) * amp
	end
	local t1, t2, t3 = s1 * amp * leg.d1 - lift, s2 * amp * leg.d2, s3 * amp * leg.d3
	leg.t1, leg.t2, leg.t3 = t1, t2, t3
	leg.c1, leg.s1 = math.cos(t1), math.sin(t1)
	leg.c2, leg.s2 = math.cos(t2), math.sin(t2)
	leg.c3, leg.s3 = math.cos(t3), math.sin(t3)
end

-- Every leg vertex at its leg's turns (`bend`), mapped by `map`, into `out`.
local function place(plan: Plan, map: { number }, out: { number }, angles: { number }?)
	local legs = plan.legs
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 =
		map[1], map[2], map[3], map[4], map[5], map[6], map[7], map[8], map[9]
	local mx, my, mz = map[10], map[11], map[12]
	local U, V, W, W1, W2, W3, L = plan.u, plan.v, plan.w, plan.w1, plan.w2, plan.w3, plan.leg
	for j = 1, #plan.idx do
		local leg = legs[L[j]]
		local u, v = U[j], V[j]
		local turn = 0
		-- the ankle, the knee, the hip: each about its rest point, the innermost first
		local w = W3[j]
		if w > 0 then
			local c, s = leg.c3, leg.s3
			if w < 1 then
				local t = leg.t3 * w
				c, s = math.cos(t), math.sin(t)
			end
			turn += leg.t3 * w
			local du, dv = u - leg.au, v - leg.av
			u, v = leg.au + du * c + dv * s, leg.av + dv * c - du * s
		end
		w = W2[j]
		if w > 0 then
			local c, s = leg.c2, leg.s2
			if w < 1 then
				local t = leg.t2 * w
				c, s = math.cos(t), math.sin(t)
			end
			turn += leg.t2 * w
			local du, dv = u - leg.ku, v - leg.kv
			u, v = leg.ku + du * c + dv * s, leg.kv + dv * c - du * s
		end
		w = W1[j]
		if w > 0 then
			local c, s = leg.c1, leg.s1
			if w < 1 then
				local t = leg.t1 * w
				c, s = math.cos(t), math.sin(t)
			end
			turn += leg.t1 * w
			u, v = u * c + v * s, v * c - u * s
		end
		if angles then
			angles[j] = turn
		end
		-- back to N (across = up x along), then the map
		local across = W[j]
		local x = leg.hx + u * leg.dx + across * leg.dz
		local y = leg.hy + v
		local z = leg.hz + u * leg.dz - across * leg.dx
		out[j * 3 - 2] = r00 * x + r01 * y + r02 * z + mx
		out[j * 3 - 1] = r10 * x + r11 * y + r12 * z + my
		out[j * 3] = r20 * x + r21 * y + r22 * z + mz
	end
end

-- The plan of a mesh: `pos` its vertices (N, flat x y z), `tris` its triangles (flat, 1-based vertex indices; nil:
-- the pieces are found by nearness instead), `o` the model's options; `yield` (if given) is called now and then so a
-- client can spread the work over frames. Nil and why when the legs cannot be told apart.
function LegFold.plan(pos: { number }, tris: { number }?, o: Options, yield: (() -> ())?): (Plan?, string)
	local n = #pos // 3
	if n < 8 then
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
	local span = math.max(width, depth)
	if span <= 0 or height <= 0 then
		return nil, "flat mesh"
	end
	-- 1. nodes: vertices at one position welded (a texture seam splits them in the mesh)
	local q = math.max(width, height, depth) * 1e-5
	local key: { [number]: number } = {}
	local nodeOf = table.create(n, 0)
	local nx: { number }, ny: { number }, nz: { number } = {}, {}, {}
	local nn = 0
	for i = 1, n do
		local x, y, z = pos[i * 3 - 2], pos[i * 3 - 1], pos[i * 3]
		local k = math.floor((x - lx) / q + 0.5)
			+ 131072 * (math.floor((y - ly) / q + 0.5) + 131072 * math.floor((z - lz) / q + 0.5))
		local found = key[k]
		if found then
			nodeOf[i] = found
		else
			nn += 1
			key[k] = nn
			nx[nn], ny[nn], nz[nn] = x, y, z
			nodeOf[i] = nn
		end
	end
	step(n)
	-- 2. the graph of the nodes (CSR): the faces' edges, else neighbours within a radius
	local cs = span / GRID
	local start = table.create(nn + 1, 0)
	local adj: { number } = {}
	if tris and #tris >= 3 then
		local deg = table.create(nn, 0)
		local m = #tris // 3
		for f = 0, m - 1 do
			local a, b, c = nodeOf[tris[f * 3 + 1]], nodeOf[tris[f * 3 + 2]], nodeOf[tris[f * 3 + 3]]
			if a and b and c then
				if a ~= b then
					deg[a] += 1
					deg[b] += 1
				end
				if b ~= c then
					deg[b] += 1
					deg[c] += 1
				end
				if c ~= a then
					deg[c] += 1
					deg[a] += 1
				end
			end
		end
		local at = 1
		for i = 1, nn do
			start[i] = at
			at += deg[i]
			deg[i] = start[i]
		end
		start[nn + 1] = at
		adj = table.create(at - 1, 0)
		local function link(a: number, b: number)
			adj[deg[a]] = b
			deg[a] += 1
			adj[deg[b]] = a
			deg[b] += 1
		end
		for f = 0, m - 1 do
			local a, b, c = nodeOf[tris[f * 3 + 1]], nodeOf[tris[f * 3 + 2]], nodeOf[tris[f * 3 + 3]]
			if a and b and c then
				if a ~= b then
					link(a, b)
				end
				if b ~= c then
					link(b, c)
				end
				if c ~= a then
					link(c, a)
				end
			end
		end
		step(m * 2)
	else
		-- no faces: neighbours within 1.6 cells (a spatial hash of cells that size)
		local r = cs * 1.6
		local cells: { [number]: { number } } = {}
		local function cellKey(cx: number, cy: number, cz: number): number
			return cx + 4096 * (cy + 4096 * cz)
		end
		for i = 1, nn do
			local k = cellKey(
				math.floor((nx[i] - lx) / r) + 1,
				math.floor((ny[i] - ly) / r) + 1,
				math.floor((nz[i] - lz) / r) + 1
			)
			local list = cells[k]
			if not list then
				list = {}
				cells[k] = list
			end
			table.insert(list, i)
		end
		local lists: { { number } } = table.create(nn)
		for i = 1, nn do
			local mine: { number } = {}
			local cx = math.floor((nx[i] - lx) / r) + 1
			local cy = math.floor((ny[i] - ly) / r) + 1
			local cz = math.floor((nz[i] - lz) / r) + 1
			for ox = -1, 1 do
				for oy = -1, 1 do
					for oz = -1, 1 do
						local list = cells[cellKey(cx + ox, cy + oy, cz + oz)]
						if list then
							for _, j in list do
								if j ~= i then
									local ex, ey, ez = nx[j] - nx[i], ny[j] - ny[i], nz[j] - nz[i]
									if ex * ex + ey * ey + ez * ez <= r * r then
										table.insert(mine, j)
									end
								end
							end
						end
					end
				end
			end
			lists[i] = mine
		end
		local at = 1
		for i = 1, nn do
			start[i] = at
			for _, j in lists[i] do
				adj[at] = j
				at += 1
			end
		end
		start[nn + 1] = at
		step(nn * 4)
	end
	-- 3. the top view: the faces' shadows (else the nodes, a cell around), the distance inside it, the opening
	local gx = math.ceil(width / cs) + 2 * BORDER + 1
	local gz = math.ceil(depth / cs) + 2 * BORDER + 1
	local ox, oz = lx - BORDER * cs, lz - BORDER * cs
	local occ = table.create(gx * gz, 0)
	local function mark(fx: number, fz: number)
		local x, z = math.floor(fx), math.floor(fz)
		if x >= 0 and x < gx and z >= 0 and z < gz then
			occ[z * gx + x + 1] = 1
		end
	end
	if tris and #tris >= 3 then
		local m = #tris // 3
		for f = 0, m - 1 do
			local a, b, c = tris[f * 3 + 1], tris[f * 3 + 2], tris[f * 3 + 3]
			local ax, az = (pos[a * 3 - 2] - ox) / cs, (pos[a * 3] - oz) / cs
			local bx, bz = (pos[b * 3 - 2] - ox) / cs, (pos[b * 3] - oz) / cs
			local cx, cz = (pos[c * 3 - 2] - ox) / cs, (pos[c * 3] - oz) / cs
			-- the edges (a thin, upright face still leaves its line)
			for e = 1, 3 do
				local px, pz, qx, qz = ax, az, bx, bz
				if e == 2 then
					px, pz, qx, qz = bx, bz, cx, cz
				elseif e == 3 then
					px, pz, qx, qz = cx, cz, ax, az
				end
				local steps = math.ceil(math.max(math.abs(qx - px), math.abs(qz - pz)) * 2)
				for s = 0, steps do
					local k = if steps > 0 then s / steps else 0
					mark(px + (qx - px) * k, pz + (qz - pz) * k)
				end
			end
			-- the inside (cell centres)
			local area = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
			if math.abs(area) > 1e-9 then
				for z = math.max(0, math.floor(math.min(az, bz, cz))), math.min(gz - 1, math.floor(math.max(az, bz, cz))) do
					for x = math.max(0, math.floor(math.min(ax, bx, cx))), math.min(gx - 1, math.floor(math.max(ax, bx, cx))) do
						local px, pz = x + 0.5, z + 0.5
						local w0 = ((bx - px) * (cz - pz) - (bz - pz) * (cx - px)) / area
						local w1 = ((cx - px) * (az - pz) - (cz - pz) * (ax - px)) / area
						if w0 >= 0 and w1 >= 0 and w0 + w1 <= 1 then
							occ[z * gx + x + 1] = 1
						end
					end
				end
			end
		end
		step(m * 3)
	else
		for i = 1, nn do
			local fx, fz = (nx[i] - ox) / cs, (nz[i] - oz) / cs
			for ex = -1, 1 do
				for ez = -1, 1 do
					mark(fx + ex, fz + ez)
				end
			end
		end
	end
	local inside = table.create(gx * gz, 0)
	chamfer(gx, gz, occ, 0, inside)
	local radius = 0
	for i = 1, gx * gz do
		radius = math.max(radius, inside[i])
	end
	if radius < 2 then
		return nil, "no body in the top view"
	end
	local disc = math.max(1.5, o.open * radius)
	local core = table.create(gx * gz, 0)
	for i = 1, gx * gz do
		core[i] = if inside[i] >= disc then 1 else 0
	end
	local toCore = table.create(gx * gz, 0)
	chamfer(gx, gz, core, 1, toCore)
	-- the opening's blobs; the thick and big ones are the body
	local blob = table.create(gx * gz, 0)
	local blobArea: { number } = {}
	local blobThick: { number } = {}
	local stack: { number } = {}
	for i = 1, gx * gz do
		if blob[i] == 0 and occ[i] == 1 and toCore[i] <= disc + 1 then
			local id = #blobArea + 1
			blobArea[id], blobThick[id] = 0, 0
			blob[i] = id
			table.insert(stack, i)
			while #stack > 0 do
				local c = table.remove(stack) :: number
				blobArea[id] += 1
				blobThick[id] = math.max(blobThick[id], inside[c])
				local cx, cz = (c - 1) % gx, (c - 1) // gx
				for e = 1, 4 do
					local x, z = cx, cz
					if e == 1 then
						x -= 1
					elseif e == 2 then
						x += 1
					elseif e == 3 then
						z -= 1
					else
						z += 1
					end
					if x >= 0 and x < gx and z >= 0 and z < gz then
						local j = z * gx + x + 1
						if blob[j] == 0 and occ[j] == 1 and toCore[j] <= disc + 1 then
							blob[j] = id
							table.insert(stack, j)
						end
					end
				end
			end
		end
	end
	local biggest, main = 0, 0
	for id, area in blobArea do
		if area > biggest then
			biggest, main = area, id
		end
	end
	-- a blob counts only near the biggest one (the abdomen by the cephalothorax, not a pincer's hand)
	local isMain = table.create(gx * gz, 0)
	for i = 1, gx * gz do
		isMain[i] = if blob[i] == main then 1 else 0
	end
	local toMain = table.create(gx * gz, 0)
	chamfer(gx, gz, isMain, 1, toMain)
	local blobNear: { number } = table.create(#blobArea, INF)
	for i = 1, gx * gz do
		local id = blob[i]
		if id > 0 then
			blobNear[id] = math.min(blobNear[id], toMain[i])
		end
	end
	local foot = table.create(gx * gz, 0)
	for i = 1, gx * gz do
		local id = blob[i]
		if
			id > 0
			and blobThick[id] >= BLOB_THICK * radius
			and blobArea[id] >= BLOB_AREA * biggest
			and blobNear[id] <= BLOB_NEAR * disc + 2
		then
			foot[i] = 1
		end
	end
	local toFoot = table.create(gx * gz, 0)
	chamfer(gx, gz, foot, 1, toFoot)
	step(gx * gz * 6)
	-- 4. the body's nodes: over the body in the top view
	local cellOf = table.create(nn, 0)
	local body = table.create(nn, false)
	for i = 1, nn do
		local x = math.clamp(math.floor((nx[i] - ox) / cs), 0, gx - 1)
		local z = math.clamp(math.floor((nz[i] - oz) / cs), 0, gz - 1)
		local c = z * gx + x + 1
		cellOf[i] = c
		body[i] = foot[c] == 1
	end
	-- 5. the pieces outside it, each with its ring (where it leaves the body, else its end nearest to the body)
	local piece = table.create(nn, 0)
	local pieces: { { number } } = {}
	for i = 1, nn do
		if not body[i] and piece[i] == 0 then
			local list = { i }
			local id = #pieces + 1
			piece[i] = id
			local head = 1
			while head <= #list do
				local a = list[head]
				head += 1
				for e = start[a], start[a + 1] - 1 do
					local b = adj[e]
					if not body[b] and piece[b] == 0 then
						piece[b] = id
						table.insert(list, b)
					end
				end
			end
			pieces[id] = list
		end
	end
	step(nn)
	local heap: Heap = { node = {}, dist = {}, n = 0 }
	local geo = table.create(nn, INF)
	-- the geodesic distance from `ring` over the nodes where `inside(node)`; returns the farthest
	local function geodesic(ring: { number }, member: { boolean }): number
		heap.n = 0
		for _, r in ring do
			geo[r] = 0
			push(heap, r, 0)
		end
		local far = 0
		while heap.n > 0 do
			local a, d = pop(heap)
			if d <= geo[a] then
				far = math.max(far, d)
				for e = start[a], start[a + 1] - 1 do
					local b = adj[e]
					if member[b] then
						local ex, ey, ez = nx[b] - nx[a], ny[b] - ny[a], nz[b] - nz[a]
						local nd = d + math.sqrt(ex * ex + ey * ey + ez * ez)
						if nd < geo[b] then
							geo[b] = nd
							push(heap, b, nd)
						end
					end
				end
			end
		end
		return far
	end
	local member = table.create(nn, false)
	local function ringOf(list: { number }): { number }
		local ring: { number } = {}
		for _, a in list do
			for e = start[a], start[a + 1] - 1 do
				if body[adj[e]] then
					table.insert(ring, a)
					break
				end
			end
		end
		if #ring == 0 then
			local near = INF
			for _, a in list do
				near = math.min(near, toFoot[cellOf[a]])
			end
			for _, a in list do
				if toFoot[cellOf[a]] <= near + 1.5 then
					table.insert(ring, a)
				end
			end
		end
		return ring
	end
	-- a piece is a leg when it reaches the ground, is long enough and starts at the body
	type Found = { nodes: { number }, ring: { number }, far: number }
	local found: { Found } = {}
	local minReach = o.reach * span
	for _, list in pieces do
		local low, nearest = INF, INF
		for _, a in list do
			low = math.min(low, ny[a])
			nearest = math.min(nearest, toFoot[cellOf[a]])
		end
		if low - ly <= o.ground * height and nearest <= 4 and #list >= 4 then
			for _, a in list do
				member[a] = true
				geo[a] = INF
			end
			local ring = ringOf(list)
			local far = geodesic(ring, member)
			-- legs fused at the hips: one leg per far branch
			local branches: { { number } } = {}
			if far >= minReach then
				local seen: { [number]: boolean } = {}
				for _, a in list do
					if geo[a] > BRANCH_AT * far and geo[a] < INF and not seen[a] then
						local br = { a }
						seen[a] = true
						local head = 1
						local reach = geo[a]
						while head <= #br do
							local x = br[head]
							head += 1
							reach = math.max(reach, geo[x])
							for e = start[x], start[x + 1] - 1 do
								local b = adj[e]
								if member[b] and not seen[b] and geo[b] > BRANCH_AT * far and geo[b] < INF then
									seen[b] = true
									table.insert(br, b)
								end
							end
						end
						if #br >= math.max(4, BRANCH_SIZE * #list) and reach >= BRANCH_LONG * far then
							table.insert(branches, br)
						end
					end
				end
			end
			if #branches <= 1 then
				if far >= minReach then
					table.insert(found, { nodes = list, ring = ring, far = far })
				end
			else
				-- each node of the shared base to the branch nearest along the surface
				local owner = table.create(nn, 0)
				local dist = table.create(nn, INF)
				heap.n = 0
				for b, br in branches do
					for _, a in br do
						owner[a] = b
						dist[a] = 0
						push(heap, a, 0)
					end
				end
				while heap.n > 0 do
					local a, d = pop(heap)
					if d <= dist[a] then
						for e = start[a], start[a + 1] - 1 do
							local b = adj[e]
							if member[b] then
								local ex, ey, ez = nx[b] - nx[a], ny[b] - ny[a], nz[b] - nz[a]
								local nd = d + math.sqrt(ex * ex + ey * ey + ez * ez)
								if nd < dist[b] then
									dist[b] = nd
									owner[b] = owner[a]
									push(heap, b, nd)
								end
							end
						end
					end
				end
				for _, a in list do
					member[a] = false
				end
				for b = 1, #branches do
					local nodes: { number } = {}
					for _, a in list do
						if owner[a] == b then
							table.insert(nodes, a)
						end
					end
					for _, a in nodes do
						member[a] = true
						geo[a] = INF
					end
					local subRing = ringOf(nodes)
					local subFar = geodesic(subRing, member)
					for _, a in nodes do
						member[a] = false
					end
					if subFar >= minReach then
						table.insert(found, { nodes = nodes, ring = subRing, far = subFar })
					end
				end
				for _, a in list do
					member[a] = true
				end
			end
			for _, a in list do
				member[a] = false
			end
		end
		step(#list * 4)
	end
	if #found < o.minLegs or #found > o.maxLegs then
		return nil, `{#found} legs found ({o.minLegs}..{o.maxLegs} expected)`
	end
	-- 6. each leg's skeleton, joints and turns
	local legs: { Leg } = {}
	local legOfNode = table.create(nn, 0)
	local gOf = table.create(nn, 0)
	local zones: { { number } } = {}
	local targets = o.targets
	local bend2, bend3 = targets[2] - targets[1], targets[3] - targets[2]
	for l, f in found do
		-- geodesics again (a split leg's were measured on its own)
		for _, a in f.nodes do
			member[a] = true
			geo[a] = INF
		end
		local far = geodesic(f.ring, member)
		for _, a in f.nodes do
			member[a] = false
			legOfNode[a] = l
			gOf[a] = if geo[a] < INF then geo[a] else far
		end
		-- the hip (the ring's centre) and the ring's size
		local hx0, hy0, hz0 = 0, 0, 0
		for _, a in f.ring do
			hx0 += nx[a]
			hy0 += ny[a]
			hz0 += nz[a]
		end
		hx0, hy0, hz0 = hx0 / #f.ring, hy0 / #f.ring, hz0 / #f.ring
		local ringR = 0
		for _, a in f.ring do
			local ex, ey, ez = nx[a] - hx0, ny[a] - hy0, nz[a] - hz0
			ringR = math.max(ringR, math.sqrt(ex * ex + ey * ey + ez * ez))
		end
		-- the slices' centres
		local sx, sy, sz, sc =
			table.create(SLICES, 0), table.create(SLICES, 0), table.create(SLICES, 0), table.create(SLICES, 0)
		for _, a in f.nodes do
			local s = math.clamp(math.floor(gOf[a] / far * SLICES) + 1, 1, SLICES)
			sx[s] += nx[a]
			sy[s] += ny[a]
			sz[s] += nz[a]
			sc[s] += 1
		end
		for s = 1, SLICES do
			if sc[s] > 0 then
				sx[s], sy[s], sz[s] = sx[s] / sc[s], sy[s] / sc[s], sz[s] / sc[s]
			end
		end
		-- empty slices take their neighbours' (a long thin face skips a slice)
		for s = 1, SLICES do
			if sc[s] == 0 then
				local p, nxt = s - 1, s + 1
				while p >= 1 and sc[p] == 0 do
					p -= 1
				end
				while nxt <= SLICES and sc[nxt] == 0 do
					nxt += 1
				end
				if p >= 1 and nxt <= SLICES then
					local k = (s - p) / (nxt - p)
					sx[s] = sx[p] + (sx[nxt] - sx[p]) * k
					sy[s] = sy[p] + (sy[nxt] - sy[p]) * k
					sz[s] = sz[p] + (sz[nxt] - sz[p]) * k
				elseif p >= 1 then
					sx[s], sy[s], sz[s] = sx[p], sy[p], sz[p]
				elseif nxt <= SLICES then
					sx[s], sy[s], sz[s] = sx[nxt], sy[nxt], sz[nxt]
				else
					sx[s], sy[s], sz[s] = hx0, hy0, hz0
				end
			end
		end
		-- the tip and the leg's plane (hip to tip; an upright leg: away from the body's middle)
		local tx, ty, tz = sx[SLICES], sy[SLICES], sz[SLICES]
		local dx, dz = tx - hx0, tz - hz0
		local flat = math.sqrt(dx * dx + dz * dz)
		if flat < 0.15 * math.sqrt(flat * flat + (ty - hy0) ^ 2) then
			dx, dz = hx0 - (lx + hx) / 2, hz0 - (lz + hz) / 2
			flat = math.sqrt(dx * dx + dz * dz)
		end
		if flat < 1e-6 then
			dx, dz, flat = 1, 0, 1
		end
		dx, dz = dx / flat, dz / flat
		local function plane(px: number, py: number, pz: number): (number, number)
			return (px - hx0) * dx + (pz - hz0) * dz, py - hy0
		end
		-- the knee: the arch's top, else the sharpest bend, else 40 % of the length
		local tu, tv = plane(tx, ty, tz)
		local knee = 0
		local top = -INF
		for s = 1, SLICES do
			local at = (s - 0.5) / SLICES
			if at >= ARCH_FROM and at <= ARCH_TO then
				local _, v = plane(sx[s], sy[s], sz[s])
				if v > top then
					top, knee = v, s
				end
			end
		end
		if knee == 0 or top < math.max(0, tv) + 0.06 * far then
			knee = 0
			local sharpest = math.rad(20)
			for s = 2, SLICES - 1 do
				local at = (s - 0.5) / SLICES
				if at >= ARCH_FROM and at <= ARCH_TO then
					local u0, v0 = plane(sx[s - 1], sy[s - 1], sz[s - 1])
					local u1, v1 = plane(sx[s], sy[s], sz[s])
					local u2, v2 = plane(sx[s + 1], sy[s + 1], sz[s + 1])
					local turn = math.abs(wrap(math.atan2(v2 - v1, u2 - u1) - math.atan2(v1 - v0, u1 - u0)))
					if turn > sharpest then
						sharpest, knee = turn, s
					end
				end
			end
		end
		local gk = if knee > 0 then (knee - 0.5) / SLICES * far else 0.4 * far
		local ga = gk + 0.5 * (far - gk)
		local function at(g: number): (number, number)
			local s = math.clamp(g / far * SLICES + 0.5, 1, SLICES)
			local s0 = math.floor(s)
			local s1 = math.min(SLICES, s0 + 1)
			local k = s - s0
			return plane(sx[s0] + (sx[s1] - sx[s0]) * k, sy[s0] + (sy[s1] - sy[s0]) * k, sz[s0] + (sz[s1] - sz[s0]) * k)
		end
		local ku, kv = at(gk)
		local au, av = at(ga)
		-- the rest elevations, the bends, the turns that fold them to the targets
		local e1 = math.atan2(kv, ku)
		local e2 = math.atan2(av - kv, au - ku)
		local e3 = math.atan2(tv - av, tu - au)
		local d1 = math.clamp(wrap(e1 - targets[1]), HIP_MIN, HIP_MAX)
		local d2 = math.clamp(wrap(e2 - e1) - bend2, BEND_MIN, BEND_MAX)
		local d3 = math.clamp(wrap(e3 - e2) - bend3, BEND_MIN, BEND_MAX)
		local mul = 1
		local front = o.front
		if front and -dz >= math.cos(front.cone) then
			mul = front.mul
		end
		legs[l] = {
			hx = hx0,
			hy = hy0,
			hz = hz0,
			dx = dx,
			dz = dz,
			ku = ku,
			kv = kv,
			au = au,
			av = av,
			d1 = d1,
			d2 = d2,
			d3 = d3,
			mul = mul,
			t1 = 0,
			t2 = 0,
			t3 = 0,
			c1 = 1,
			s1 = 0,
			c2 = 1,
			s2 = 0,
			c3 = 1,
			s3 = 0,
		}
		-- the hinge zones: the hip's twist out of the ring, the knee's and the ankle's bend
		local zh = math.clamp(2 * ringR, 0.05 * far, 0.25 * math.max(gk, 0.2 * far))
		local zk = 0.12 * far
		zones[l] = { zh, gk - zk / 2, zk, ga - zk / 2, zk }
		step(#f.nodes * 3)
	end
	-- loose pieces that touch a leg join it (a claw modelled apart from its arm): from the nearest leg node on
	local near = JOIN * cs
	local legCells: { [number]: { number } } = {}
	local function cellKey(x: number, y: number, z: number): number
		return math.floor((x - lx) / near)
			+ 1
			+ 4096 * (math.floor((y - ly) / near) + 1 + 4096 * (math.floor((z - lz) / near) + 1))
	end
	for a = 1, nn do
		if legOfNode[a] > 0 then
			local k = cellKey(nx[a], ny[a], nz[a])
			local list = legCells[k]
			if not list then
				list = {}
				legCells[k] = list
			end
			table.insert(list, a)
		end
	end
	for _, list in pieces do
		local taken = false
		for _, a in list do
			if legOfNode[a] > 0 then
				taken = true
				break
			end
		end
		if not taken then
			local best, bestD = 0, near
			for _, a in list do
				for ex = -1, 1 do
					for ey = -1, 1 do
						for ez = -1, 1 do
							local cell = legCells[cellKey(nx[a] + ex * near, ny[a] + ey * near, nz[a] + ez * near)]
							if cell then
								for _, b in cell do
									local fx, fy, fz = nx[b] - nx[a], ny[b] - ny[a], nz[b] - nz[a]
									local d = math.sqrt(fx * fx + fy * fy + fz * fz)
									if d < bestD then
										best, bestD = b, d
									end
								end
							end
						end
					end
				end
			end
			if best > 0 then
				local l, g0 = legOfNode[best], gOf[best]
				for _, a in list do
					local fx, fy, fz = nx[best] - nx[a], ny[best] - ny[a], nz[best] - nz[a]
					legOfNode[a] = l
					gOf[a] = g0 + math.sqrt(fx * fx + fy * fy + fz * fz)
				end
			end
		end
		step(#list)
	end
	-- 7. the leg vertices
	local plan: Plan = {
		count = n,
		idx = {},
		leg = {},
		u = {},
		v = {},
		w = {},
		w1 = {},
		w2 = {},
		w3 = {},
		legs = legs,
		pace = o.pace,
		boxes = {},
	}
	for i = 1, n do
		local node = nodeOf[i]
		local l = legOfNode[node]
		if l > 0 then
			local leg = legs[l]
			local z = zones[l]
			local g = gOf[node]
			local ex, ey, ez = pos[i * 3 - 2] - leg.hx, pos[i * 3 - 1] - leg.hy, pos[i * 3] - leg.hz
			table.insert(plan.idx, i)
			table.insert(plan.leg, l)
			table.insert(plan.u, ex * leg.dx + ez * leg.dz)
			table.insert(plan.v, ey)
			table.insert(plan.w, ex * leg.dz - ez * leg.dx)
			table.insert(plan.w1, smooth(g / z[1]))
			table.insert(plan.w2, smooth((g - z[2]) / z[3]))
			table.insert(plan.w3, smooth((g - z[4]) / z[5]))
		end
	end
	local share = #plan.idx / n
	if share < 0.05 or share > 0.85 then
		return nil, `legs are {math.floor(share * 100 + 0.5)} % of the mesh`
	end
	-- 8. the box along the fold (the body's vertices stay; no seed: every leg alike)
	local isLeg = table.create(n, false)
	for _, i in plan.idx do
		isLeg[i] = true
	end
	local still: Box = { x0 = INF, y0 = INF, z0 = INF, x1 = -INF, y1 = -INF, z1 = -INF }
	for i = 1, n do
		if not isLeg[i] then
			local x, y, z = pos[i * 3 - 2], pos[i * 3 - 1], pos[i * 3]
			still.x0, still.y0, still.z0 = math.min(still.x0, x), math.min(still.y0, y), math.min(still.z0, z)
			still.x1, still.y1, still.z1 = math.max(still.x1, x), math.max(still.y1, y), math.max(still.z1, z)
		end
	end
	local out = table.create(#plan.idx * 3, 0)
	for k = 0, BOX_STEPS do
		local p = k / BOX_STEPS
		local box = table.clone(still)
		-- every pace and amplitude a seed can give a leg (its lowest point when it lags or leads the others)
		for e = -BOX_PACES, BOX_PACES do
			for a = -1, 1 do
				local s = if p > 0 then p ^ (1 + o.pace * e / BOX_PACES) else 0
				for _, leg in legs do
					bend(leg, s, leg.mul * (1 + AMP * a))
				end
				place(plan, IDENTITY, out, nil)
				for j = 1, #plan.idx do
					local x, y, z = out[j * 3 - 2], out[j * 3 - 1], out[j * 3]
					box.x0, box.y0, box.z0 = math.min(box.x0, x), math.min(box.y0, y), math.min(box.z0, z)
					box.x1, box.y1, box.z1 = math.max(box.x1, x), math.max(box.y1, y), math.max(box.z1, z)
				end
				step(#plan.idx)
			end
		end
		plan.boxes[k + 1] = box
	end
	-- never smaller than any later box: the body only ever comes down (no bounce), nothing under the ground; the
	-- first (at rest) exact
	for k = BOX_STEPS, 2, -1 do
		local a, b = plan.boxes[k], plan.boxes[k + 1]
		a.x0, a.y0, a.z0 = math.min(a.x0, b.x0), math.min(a.y0, b.y0), math.min(a.z0, b.z0)
		a.x1, a.y1, a.z1 = math.max(a.x1, b.x1), math.max(a.y1, b.y1), math.max(a.z1, b.z1)
	end
	return plan, `{#legs} legs, {#plan.idx} of {n} vertices`
end

-- The leg vertices folded by `fold` (0 rest, 1 curled; down to -0.3 splayed), each leg at its own pace for `seed`
-- (nil: all alike), mapped by the affine `map` (rows r00 r01 r02 r10 .. r22, then the translation) into `out` (flat
-- x y z, in the order of `plan.idx`). `angles` (optional) gets each vertex's whole turn (rad, + = down), the turn of
-- its normal.
function LegFold.pose(plan: Plan, fold: number, seed: number?, map: { number }, out: { number }, angles: { number }?)
	local p = math.clamp(fold, SPLAY, 1)
	for l, leg in plan.legs do
		local s = p
		local amp = leg.mul
		if seed then
			if p > 0 then
				s = p ^ (1 + plan.pace * (NpcPose.hash01(l, seed) * 2 - 1))
			end
			amp *= 1 + AMP * (NpcPose.hash01(l + 50, seed) * 2 - 1)
		end
		bend(leg, s, amp)
	end
	place(plan, map, out, angles)
end

-- A direction (N) of a vertex of leg `l` turned by `turn` (rad, + = down) in the leg's plane: its normal.
function LegFold.turn(plan: Plan, l: number, turn: number, x: number, y: number, z: number): (number, number, number)
	local leg = plan.legs[l]
	local u = x * leg.dx + z * leg.dz
	local across = x * leg.dz - z * leg.dx
	local c, s = math.cos(turn), math.sin(turn)
	local u2, v2 = u * c + y * s, y * c - u * s
	return u2 * leg.dx + across * leg.dz, v2, u2 * leg.dz - across * leg.dx
end

return LegFold
