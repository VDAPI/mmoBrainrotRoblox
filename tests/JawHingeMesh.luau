--!strict
-- A synthetic head for tests/jawhinge.spec.luau (Logic/JawHinge), in its frame H: the head bone's joint at the origin,
-- x right, y up, the snout to -z (its tip at z = -1). A skull, an upper jaw, a lower jaw modelled open (one surface
-- with the upper one at the mouth's corner, z = -0.3), teeth (loose pieces), a spike hanging far under the chin and a
-- beard hanging off the lower jaw behind the corner, a neck behind joined to the jaw by the throat, and copies of three
-- lower-jaw vertices (a texture seam). Flat positions, triangles (1-based), each vertex's head skin, each part's vertex range.

local JawHingeMesh = {}

export type Mesh = {
	pos: { number },
	tris: { number },
	head: { number },
	parts: { [string]: { number } },
}

local function vert(m: Mesh, x: number, y: number, z: number, w: number): number
	table.insert(m.pos, x)
	table.insert(m.pos, y)
	table.insert(m.pos, z)
	table.insert(m.head, w)
	return #m.head
end

local function tri(m: Mesh, a: number, b: number, c: number)
	table.insert(m.tris, a)
	table.insert(m.tris, b)
	table.insert(m.tris, c)
end

-- A block of side profile `p` ({ z, y } x 4 round it) `w` wide on each side of x = 0: left vertices 1..4, right 5..8.
local function prism(m: Mesh, name: string, p: { { number } }, w: number, skin: number): { number }
	local first = #m.head + 1
	local v: { number } = {}
	for k = 1, 4 do
		v[k] = vert(m, -w, p[k][2], p[k][1], skin)
	end
	for k = 1, 4 do
		v[k + 4] = vert(m, w, p[k][2], p[k][1], skin)
	end
	-- the two sides, then the four faces round the profile
	tri(m, v[1], v[2], v[3])
	tri(m, v[1], v[3], v[4])
	tri(m, v[5], v[7], v[6])
	tri(m, v[5], v[8], v[7])
	for k = 1, 4 do
		local k2 = k % 4 + 1
		tri(m, v[k], v[k + 4], v[k2 + 4])
		tri(m, v[k], v[k2 + 4], v[k2])
	end
	m.parts[name] = { first, #m.head }
	return v
end

-- A tooth (or a spike): a base of three points and its tip.
local function tooth(m: Mesh, name: string, base: { { number } }, apex: { number }, skin: number)
	local first = #m.head + 1
	local a = vert(m, base[1][1], base[1][2], base[1][3], skin)
	local b = vert(m, base[2][1], base[2][2], base[2][3], skin)
	local c = vert(m, base[3][1], base[3][2], base[3][3], skin)
	local t = vert(m, apex[1], apex[2], apex[3], skin)
	tri(m, a, b, c)
	tri(m, a, t, b)
	tri(m, b, t, c)
	tri(m, c, t, a)
	m.parts[name] = { first, #m.head }
end

-- The lower jaw's top at z (modelled open: from the corner down to the front).
function JawHingeMesh.lowerTop(z: number): number
	return 0.5 * (z + 0.3)
end

-- The head; `closed`: the lower jaw shut against the upper one (no opening); `nearTooth`: an upper tooth near the
-- corner reaching down onto the lower jaw (it closes the opening over a few columns).
function JawHingeMesh.build(opts: { closed: boolean?, nearTooth: boolean? }?): Mesh
	local o = opts or {}
	local m: Mesh = { pos = {}, tris = {}, head = {}, parts = {} }
	prism(m, "skull", { { -0.3, 0.35 }, { 0.25, 0.35 }, { 0.25, -0.2 }, { -0.3, -0.2 } }, 0.3, 1)
	prism(m, "upper", { { -0.3, 0.2 }, { -1.0, 0.15 }, { -1.0, 0.0 }, { -0.3, 0.0 } }, 0.2, 1)
	local frontTop = if o.closed then 0.0 else JawHingeMesh.lowerTop(-0.9)
	local frontBottom = frontTop - 0.12
	local lower =
		prism(m, "lower", { { -0.3, 0.0 }, { -0.9, frontTop }, { -0.9, frontBottom }, { -0.3, -0.18 } }, 0.2, 1)
	if not o.closed then
		for _, z in { -0.85, -0.65 } do
			for _, x in { -0.15, 0.15 } do
				tooth(
					m,
					`upperTooth{z}{x}`,
					{ { x - 0.02, 0, z - 0.03 }, { x + 0.02, 0, z - 0.03 }, { x, 0, z + 0.03 } },
					{ x, -0.06, z },
					1
				)
			end
		end
		for _, z in { -0.8, -0.6 } do
			for _, x in { -0.12, 0.12 } do
				local y = JawHingeMesh.lowerTop(z)
				tooth(
					m,
					`lowerTooth{z}{x}`,
					{ { x - 0.02, y, z - 0.03 }, { x + 0.02, y, z - 0.03 }, { x, y, z + 0.03 } },
					{ x, y + 0.06, z },
					1
				)
			end
		end
		if o.nearTooth then
			tooth(
				m,
				"nearTooth",
				{ { -0.02, 0, -0.47 }, { 0.02, 0, -0.47 }, { 0, 0, -0.43 } },
				{ 0, JawHingeMesh.lowerTop(-0.45) - 0.01, -0.45 },
				1
			)
		end
	end
	-- the spike under the chin: its base on the lower jaw's front bottom edge, hanging far below the jaw
	local p = m.pos
	local function copyOf(v: number, skin: number): number
		return vert(m, p[v * 3 - 2], p[v * 3 - 1], p[v * 3], skin)
	end
	local first = #m.head + 1
	local s1, s2 = copyOf(lower[3], 1), copyOf(lower[7], 1)
	local s3 = vert(m, 0, frontBottom + 0.05, -0.78, 1)
	local tip = vert(m, 0, frontBottom - 0.35, -0.75, 1)
	tri(m, s1, s2, s3)
	tri(m, s1, tip, s2)
	tri(m, s2, tip, s3)
	tri(m, s3, tip, s1)
	m.parts.spike = { first, #m.head }
	-- a beard behind the mouth's corner, hanging off the lower jaw's back bottom edge (part of it on the neck's skin)
	first = #m.head + 1
	local bl, br = lower[4], lower[8]
	local b1, b2 = copyOf(bl, 0.6), copyOf(br, 0.6)
	local b3 = vert(m, 0, -0.22, -0.2, 0.6)
	local b4 = vert(m, 0, -0.55, -0.27, 0.6)
	tri(m, b1, b2, b3)
	tri(m, b1, b4, b2)
	tri(m, b2, b4, b3)
	tri(m, b3, b4, b1)
	m.parts.beard = { first, #m.head }
	-- the neck (skinned to its own bone) and the throat between it and the jaw
	local neck = prism(m, "neck", { { 0.05, -0.15 }, { 0.6, -0.15 }, { 0.6, -0.9 }, { 0.05, -0.9 } }, 0.2, 0)
	local mid = vert(m, 0, -0.2, -0.05, 0.5)
	m.parts.throat = { mid, mid }
	tri(m, bl, br, mid)
	tri(m, mid, neck[5], neck[1])
	tri(m, bl, mid, neck[1])
	tri(m, br, neck[5], mid)
	-- a texture seam: copies of three of the lower jaw's front vertices on a face of their own
	first = #m.head + 1
	local copies: { number } = {}
	for _, v in { lower[2], lower[3], lower[6] } do
		table.insert(copies, copyOf(v, 1))
	end
	tri(m, copies[1], copies[2], copies[3])
	m.parts.seam = { first, #m.head }
	m.parts.lowerFront = { lower[2], lower[3], lower[6] }
	return m
end

-- The same mesh `k` times bigger.
function JawHingeMesh.scaled(m: Mesh, k: number): Mesh
	local pos = table.clone(m.pos)
	for i = 1, #pos do
		pos[i] *= k
	end
	return { pos = pos, tris = m.tris, head = m.head, parts = m.parts }
end

return JawHingeMesh
