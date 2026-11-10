--!strict
-- Synthetic meshes for tests/neckbend.spec.luau (Logic/NeckBend), like a Tripo export (one surface, feet at y = 0,
-- front -Z): a lynx-like cat (a body, a neck rising to a head with ears, loose eyes, four legs, a tail), a neckless
-- toad (one surface, the head the front of the body) and a bird (a head on a short neck, wings spread at the sides).
-- Flat positions and triangles (1-based), plus each part's vertex range.

local LegFoldMesh = require("./LegFoldMesh")

local NeckBendMesh = {}

export type Mesh = LegFoldMesh.Mesh

local function newMesh(): Mesh
	return { pos = {}, tris = {}, parts = {} }
end

local function vert(m: Mesh, x: number, y: number, z: number): number
	table.insert(m.pos, x)
	table.insert(m.pos, y)
	table.insert(m.pos, z)
	return #m.pos // 3
end

local function tri(m: Mesh, a: number, b: number, c: number)
	table.insert(m.tris, a)
	table.insert(m.tris, b)
	table.insert(m.tris, c)
end

-- The vertex of part `name` nearest to vertex `v`.
local function nearest(m: Mesh, name: string, v: number): number
	local range = m.parts[name]
	local best, bestD = range[1], math.huge
	for i = range[1], range[2] do
		local d = (m.pos[i * 3 - 2] - m.pos[v * 3 - 2]) ^ 2
			+ (m.pos[i * 3 - 1] - m.pos[v * 3 - 1]) ^ 2
			+ (m.pos[i * 3] - m.pos[v * 3]) ^ 2
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

-- A UV ellipsoid of `rings` x `cols` (finer than tests/LegFoldMesh's); `seam`: the faces of the first column use
-- copies of their vertices (a texture seam).
function NeckBendMesh.ellipsoid(
	m: Mesh,
	name: string,
	c: { number },
	r: { number },
	rings: number,
	cols: number,
	seam: boolean?
)
	local first = #m.pos // 3 + 1
	local top = vert(m, c[1], c[2] + r[2], c[3])
	local grid: { { number } } = {}
	for i = 1, rings - 1 do
		local phi = math.pi * i / rings
		grid[i] = {}
		for j = 0, cols - 1 do
			local th = 2 * math.pi * j / cols
			grid[i][j] = vert(
				m,
				c[1] + r[1] * math.sin(phi) * math.cos(th),
				c[2] + r[2] * math.cos(phi),
				c[3] + r[3] * math.sin(phi) * math.sin(th)
			)
		end
	end
	local bottom = vert(m, c[1], c[2] - r[2], c[3])
	local copies: { number } = {}
	if seam then
		for i = 1, rings - 1 do
			local v = grid[i][0]
			copies[i] = vert(m, m.pos[v * 3 - 2], m.pos[v * 3 - 1], m.pos[v * 3])
		end
	end
	local function at(i: number, j: number): number
		if j == cols then
			return if seam then copies[i] else grid[i][0]
		end
		return grid[i][j]
	end
	for j = 0, cols - 1 do
		tri(m, top, at(1, j), at(1, j + 1))
		tri(m, bottom, at(rings - 1, j + 1), at(rings - 1, j))
		for i = 1, rings - 2 do
			tri(m, at(i, j), at(i + 1, j), at(i + 1, j + 1))
			tri(m, at(i, j), at(i + 1, j + 1), at(i, j + 1))
		end
	end
	m.parts[name] = { first, #m.pos // 3 }
end

-- A tube along `path` (radius r0 to r1, rings every 0.1), its first ring bridged to part `from` and its last to part
-- `to` (one surface), else capped.
function NeckBendMesh.tube(
	m: Mesh,
	name: string,
	path: { { number } },
	r0: number,
	r1: number,
	from: string?,
	to: string?
)
	local first = #m.pos // 3 + 1
	local pts: { { number } } = { path[1] }
	for k = 2, #path do
		local a, b = path[k - 1], path[k]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		local steps = math.max(1, math.ceil(len / 0.1))
		for s = 1, steps do
			local t = s / steps
			table.insert(pts, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t })
		end
	end
	local sides = 8
	local rings: { { number } } = {}
	for k, p in pts do
		local q = pts[math.min(#pts, k + 1)]
		local o = pts[math.max(1, k - 1)]
		local tx, ty, tz = q[1] - o[1], q[2] - o[2], q[3] - o[3]
		local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
		tx, ty, tz = tx / tl, ty / tl, tz / tl
		local ax, ay, az = tz, 0, -tx
		local al = math.sqrt(ax * ax + az * az)
		if al < 0.2 then
			ax, ay, az = 0, -tz, ty
			al = math.sqrt(ay * ay + az * az)
		end
		ax, ay, az = ax / al, ay / al, az / al
		local bx, by, bz = ty * az - tz * ay, tz * ax - tx * az, tx * ay - ty * ax
		local r = r0 + (r1 - r0) * (k - 1) / math.max(1, #pts - 1)
		local ring: { number } = {}
		for s = 0, sides - 1 do
			local a = 2 * math.pi * s / sides
			local ca, sa = math.cos(a) * r, math.sin(a) * r
			ring[s] = vert(m, p[1] + ax * ca + bx * sa, p[2] + ay * ca + by * sa, p[3] + az * ca + bz * sa)
		end
		rings[k] = ring
	end
	for k = 1, #rings - 1 do
		for s = 0, sides - 1 do
			local s1 = (s + 1) % sides
			tri(m, rings[k][s], rings[k + 1][s], rings[k + 1][s1])
			tri(m, rings[k][s], rings[k + 1][s1], rings[k][s1])
		end
	end
	local function close(ring: { number }, part: string?, at: { number })
		if part then
			for s = 0, sides - 1 do
				local v = ring[s]
				tri(m, v, nearest(m, part, v), ring[(s + 1) % sides])
			end
		else
			local cap = vert(m, at[1], at[2], at[3])
			for s = 0, sides - 1 do
				tri(m, ring[s], cap, ring[(s + 1) % sides])
			end
		end
	end
	close(rings[1], from, pts[1])
	close(rings[#rings], to, pts[#pts])
	m.parts[name] = { first, #m.pos // 3 }
end

-- The cat: about the lynx's rig dump (1.83 x 3.61 x 4.07). `o.stray`: a loose piece beside the head (it stays);
-- `o.eyes = false`: no loose eyes.
function NeckBendMesh.cat(o: { [string]: any }?): Mesh
	local opt = o or {}
	local m = newMesh()
	LegFoldMesh.ellipsoid(m, "body", { 0, 1.6, 0.4 }, { 0.55, 0.5, 1.3 }, true)
	LegFoldMesh.ellipsoid(m, "head", { 0, 2.65, -1.45 }, { 0.38, 0.32, 0.45 })
	NeckBendMesh.tube(
		m,
		"neck",
		{ { 0, 2.45, -1.15 }, { 0, 2.1, -0.85 }, { 0, 1.85, -0.65 } },
		0.24,
		0.3,
		"head",
		"body"
	)
	for side = -1, 1, 2 do
		NeckBendMesh.tube(
			m,
			`ear{side}`,
			{ { side * 0.18, 2.88, -1.35 }, { side * 0.22, 3.3, -1.3 } },
			0.08,
			0.02,
			"head"
		)
		if opt.eyes ~= false then
			LegFoldMesh.ellipsoid(m, `eye{side}`, { side * 0.2, 2.75, -1.76 }, { 0.07, 0.07, 0.07 })
		end
		for i, z in { -0.55, 1.2 } do
			NeckBendMesh.tube(
				m,
				`leg{side}{i}`,
				{ { side * 0.35, 1.25, z }, { side * 0.36, 0.6, z - 0.05 }, { side * 0.36, 0.02, z - 0.1 } },
				0.13,
				0.09,
				"body"
			)
		end
	end
	NeckBendMesh.tube(m, "tail", { { 0, 1.75, 1.65 }, { 0, 2.0, 2.1 }, { 0, 2.2, 2.4 } }, 0.12, 0.06, "body")
	if opt.stray then
		LegFoldMesh.ellipsoid(m, "stray", { 1.5, 2.6, -1.5 }, { 0.2, 0.2, 0.2 })
	end
	return m
end

-- The toad: one surface, the head the front of a broad squat body, four splayed legs at the sides.
function NeckBendMesh.toad(): Mesh
	local m = newMesh()
	NeckBendMesh.ellipsoid(m, "body", { 0, 0.85, 0 }, { 1.1, 0.75, 1.45 }, 24, 40, true)
	for side = -1, 1, 2 do
		for i, z in { -0.6, 0.7 } do
			NeckBendMesh.tube(
				m,
				`leg{side}{i}`,
				{ { side * 0.8, 0.6, z }, { side * 1.3, 0.35, z - 0.1 }, { side * 1.35, 0.03, z - 0.2 } },
				0.16,
				0.1,
				"body"
			)
		end
	end
	return m
end

-- The bird: about the old crow's dump (1.94 x 1.83 x 1.94): a body, a short neck up to the head with a beak, the
-- wings spread at the sides (one surface with the body), two legs.
function NeckBendMesh.bird(): Mesh
	local m = newMesh()
	LegFoldMesh.ellipsoid(m, "body", { 0, 0.95, 0.15 }, { 0.35, 0.35, 0.6 }, true)
	LegFoldMesh.ellipsoid(m, "head", { 0, 1.45, -0.45 }, { 0.2, 0.2, 0.24 })
	NeckBendMesh.tube(m, "beak", { { 0, 1.42, -0.62 }, { 0, 1.38, -0.95 } }, 0.07, 0.01, "head")
	NeckBendMesh.tube(m, "neck", { { 0, 1.32, -0.35 }, { 0, 1.16, -0.25 } }, 0.13, 0.16, "head", "body")
	for side = -1, 1, 2 do
		NeckBendMesh.tube(
			m,
			`wing{side}`,
			{ { side * 0.3, 1.05, 0.0 }, { side * 0.6, 1.25, -0.2 }, { side * 0.95, 1.3, 0.1 } },
			0.12,
			0.05,
			"body"
		)
		NeckBendMesh.tube(
			m,
			`leg{side}`,
			{ { side * 0.12, 0.65, 0.2 }, { side * 0.12, 0.02, 0.25 } },
			0.04,
			0.03,
			"body"
		)
	end
	return m
end

-- Each vertex of the parts whose names start with `prefix`.
function NeckBendMesh.each(m: Mesh, prefix: string, fn: (number) -> ())
	for name, range in m.parts do
		if string.sub(name, 1, #prefix) == prefix then
			for i = range[1], range[2] do
				fn(i)
			end
		end
	end
end

return NeckBendMesh
