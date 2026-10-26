--!strict
-- Synthetic meshes for tests/legfold.spec.luau (Logic/LegFold): a Tripo-like cave spider (abdomen, cephalothorax,
-- eight arched legs as tubes) and a scorpion (a flat body, a raised tail curling forward, two pincers, eight short
-- legs); feet at y = 0, front -Z. Flat positions and triangles (1-based), plus each part's vertex range.

local LegFoldMesh = {}

export type Mesh = { pos: { number }, tris: { number }, parts: { [string]: { number } } }

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

-- A UV ellipsoid; `seam`: the faces of the first column use copies of their vertices (a texture seam).
function LegFoldMesh.ellipsoid(m: Mesh, name: string, c: { number }, r: { number }, seam: boolean?)
	local first = #m.pos // 3 + 1
	local rings, cols = 10, 16
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

-- A tube along `path` (points), radius from r0 to r1, capped; the first ring bridged to the nearest vertices of the
-- part `fuse` (one surface with the body) when given.
function LegFoldMesh.tube(
	m: Mesh,
	name: string,
	path: { { number } },
	r0: number,
	r1: number,
	fuse: string?,
	step: number?
)
	local first = #m.pos // 3 + 1
	-- resample the path every 0.1
	local pts: { { number } } = { path[1] }
	for k = 2, #path do
		local a, b = path[k - 1], path[k]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		local steps = math.max(1, math.ceil(len / (step or 0.1)))
		for s = 1, steps do
			local t = s / steps
			table.insert(pts, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t })
		end
	end
	local sides = 6
	local rings: { { number } } = {}
	for k, p in pts do
		local q = pts[math.min(#pts, k + 1)]
		local o = pts[math.max(1, k - 1)]
		local tx, ty, tz = q[1] - o[1], q[2] - o[2], q[3] - o[3]
		local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
		tx, ty, tz = tx / tl, ty / tl, tz / tl
		-- a side vector: tangent x up (or x when upright)
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
	local tip = pts[#pts]
	local cap = vert(m, tip[1], tip[2], tip[3])
	for s = 0, sides - 1 do
		tri(m, rings[#rings][s], cap, rings[#rings][(s + 1) % sides])
	end
	if fuse then
		local range = m.parts[fuse]
		for s = 0, sides - 1 do
			local v = rings[1][s]
			local best, bestD = range[1], math.huge
			for i = range[1], range[2] do
				local d = (m.pos[i * 3 - 2] - m.pos[v * 3 - 2]) ^ 2
					+ (m.pos[i * 3 - 1] - m.pos[v * 3 - 1]) ^ 2
					+ (m.pos[i * 3] - m.pos[v * 3]) ^ 2
				if d < bestD then
					best, bestD = i, d
				end
			end
			tri(m, v, best, rings[1][(s + 1) % sides])
		end
	end
	m.parts[name] = { first, #m.pos // 3 }
end

-- The cave spider (about the rig dump: 5 wide, 2.35 high, 4.6 deep); `fused`: legs one surface with the body;
-- `o` varies it: `thick` (the legs' radius at the hip), `knee` (how high the knee arches over the hip), `step` (the
-- length of the leg's faces: a decimated mesh), `palps` (two short feelers at the front).
function LegFoldMesh.spider(fused: boolean?, o: { [string]: any }?): Mesh
	local opt = o or {}
	local m = newMesh()
	LegFoldMesh.ellipsoid(m, "abdomen", { 0, 1.45, 0.9 }, { 0.85, 0.7, 1.05 }, true)
	LegFoldMesh.ellipsoid(m, "head", { 0, 1.25, -0.55 }, { 0.6, 0.45, 0.65 })
	local angles = { 40, 75, 110, 145 }
	for side = -1, 1, 2 do
		for i, deg in angles do
			local a = math.rad(deg)
			local dx, dz = side * math.sin(a), -math.cos(a)
			local hip = { side * 0.45, 1.2, -0.95 + (i - 1) * 0.3 }
			local knee = { hip[1] + dx * 1.0, hip[2] + (opt.knee or 0.75), hip[3] + dz * 1.0 }
			local tip = { knee[1] + dx * 1.2, 0.05, knee[3] + dz * 1.2 }
			LegFoldMesh.tube(
				m,
				`leg{side}{i}`,
				{ hip, knee, tip },
				opt.thick or 0.09,
				0.05,
				if fused then "head" else nil,
				opt.step
			)
		end
		if opt.palps then
			local base = { side * 0.25, 1.05, -1.1 }
			LegFoldMesh.tube(
				m,
				`palp{side}`,
				{ base, { side * 0.35, 0.8, -1.45 }, { side * 0.35, 0.08, -1.6 } },
				0.06,
				0.04,
				if fused then "head" else nil
			)
		end
	end
	return m
end

-- The scorpion: a flat body, the tail up and over it, two pincers forward, eight short legs.
function LegFoldMesh.scorpion(): Mesh
	local m = newMesh()
	LegFoldMesh.ellipsoid(m, "body", { 0, 0.75, 0.3 }, { 0.75, 0.4, 1.3 })
	LegFoldMesh.tube(
		m,
		"tail",
		{ { 0, 0.9, 1.4 }, { 0, 1.4, 2.0 }, { 0, 2.2, 2.2 }, { 0, 2.9, 1.8 }, { 0, 3.1, 1.2 } },
		0.2,
		0.12,
		"body"
	)
	for side = -1, 1, 2 do
		LegFoldMesh.tube(
			m,
			`pincer{side}`,
			{ { side * 0.4, 0.7, -0.85 }, { side * 0.9, 0.5, -1.6 }, { side * 0.9, 0.3, -2.3 } },
			0.12,
			0.1,
			"body"
		)
		LegFoldMesh.ellipsoid(m, `claw{side}`, { side * 0.95, 0.35, -2.5 }, { 0.28, 0.2, 0.45 })
		for i = 1, 4 do
			local a = math.rad(55 + (i - 1) * 25)
			local dx, dz = side * math.sin(a), -math.cos(a)
			local hip = { side * 0.6, 0.6, -0.4 + (i - 1) * 0.4 }
			local knee = { hip[1] + dx * 0.7, 0.85, hip[3] + dz * 0.7 }
			local tip = { knee[1] + dx * 0.6, 0.04, knee[3] + dz * 0.6 }
			LegFoldMesh.tube(m, `leg{side}{i}`, { hip, knee, tip }, 0.08, 0.05, "body")
		end
	end
	return m
end

return LegFoldMesh
