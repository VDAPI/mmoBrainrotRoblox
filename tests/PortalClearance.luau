--!strict
-- Test helper (W28): which dressing pieces of a map's generator (Logic/WorldGen) reach into the clearance box of a
-- portal from Data/Portals (Data/Portals.clearance: the arch, the dungeon gate), by the separating axis test of each
-- piece's oriented box against the box in the portal's own frame. Pure (Lune).

local MapTerrain = require("../src/shared/Logic/MapTerrain")
local Portals = require("../src/shared/Data/Portals")
local WorldGen = require("../src/shared/Logic/WorldGen")

local PortalClearance = {}

export type Hit = { portal: string, build: string, piece: number, size: { number }, at: { number } }

type Vec = { number }
type Mat = { number } -- row-major 3x3

local function ry(deg: number): Mat
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end

local function mul(a: Mat, b: Mat): Mat
	local out = table.create(9, 0)
	for i = 0, 2 do
		for j = 0, 2 do
			out[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[j + 4] + a[i * 3 + 3] * b[j + 7]
		end
	end
	return out
end

local function transpose(a: Mat): Mat
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end

local function apply(a: Mat, v: Vec): Vec
	return {
		a[1] * v[1] + a[2] * v[2] + a[3] * v[3],
		a[4] * v[1] + a[5] * v[2] + a[6] * v[3],
		a[7] * v[1] + a[8] * v[2] + a[9] * v[3],
	}
end

local function column(a: Mat, j: number): Vec
	return { a[j], a[j + 3], a[j + 6] }
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

-- Whether an oriented box (centre c, axes = columns of r, half sizes h) overlaps the axis-aligned box (centre bc,
-- half sizes bh), by the 15 separating axes.
function PortalClearance.overlaps(c: Vec, r: Mat, h: Vec, bc: Vec, bh: Vec): boolean
	local d = { c[1] - bc[1], c[2] - bc[2], c[3] - bc[3] }
	local A = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	local B = { column(r, 1), column(r, 2), column(r, 3) }
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, A[i])
		table.insert(axes, B[i])
		for j = 1, 3 do
			table.insert(axes, cross(A[i], B[j]))
		end
	end
	for _, axis in axes do
		if dot(axis, axis) > 1e-9 then
			local ra = bh[1] * math.abs(axis[1]) + bh[2] * math.abs(axis[2]) + bh[3] * math.abs(axis[3])
			local rb = 0
			for j = 1, 3 do
				rb += h[j] * math.abs(dot(axis, B[j]))
			end
			if math.abs(dot(axis, d)) > ra + rb - 1e-6 then
				return false
			end
		end
	end
	return true
end

-- Every piece of `mapId`'s dressing inside a portal's clearance (empty when the map has no generator).
function PortalClearance.hits(mapId: string): { Hit }
	local gen = WorldGen.get(mapId)
	local out: { Hit } = {}
	if not gen then
		return out
	end
	local portals = {}
	for _, p in Portals.onMap(mapId) do
		local box = Portals.clearance(p.kind)
		if box then
			table.insert(portals, {
				p = p,
				y = MapTerrain.height(mapId, p.x, p.z) or 0,
				inv = transpose(ry(p.rot)),
				box = box,
			})
		end
	end
	if #portals == 0 then
		return out
	end
	for _, b in gen.all() do
		local frame = ry(b.at.rot)
		for _, q in portals do
			-- quick reject: the build's frame far from the portal (no dressing piece is 120 studs from its frame)
			if (b.at.x - q.p.x) ^ 2 + (b.at.z - q.p.z) ^ 2 < 160 ^ 2 then
				local rot = mul(q.inv, frame)
				for k, piece in b.bp.pieces do
					local world = apply(frame, piece.p)
					local rel = { b.at.x + world[1] - q.p.x, b.at.y + world[2] - q.y, b.at.z + world[3] - q.p.z }
					local c = apply(q.inv, rel)
					local h = { piece.size[1] / 2, piece.size[2] / 2, piece.size[3] / 2 }
					local reach = math.sqrt(h[1] ^ 2 + h[2] ^ 2 + h[3] ^ 2)
					local bc, bh = q.box.center, q.box.half
					if
						math.abs(c[1] - bc[1]) < bh[1] + reach
						and math.abs(c[2] - bc[2]) < bh[2] + reach
						and math.abs(c[3] - bc[3]) < bh[3] + reach
						and PortalClearance.overlaps(c, mul(rot, piece.r), h, bc, bh)
					then
						table.insert(out, { portal = q.p.id, build = b.name, piece = k, size = piece.size, at = c })
					end
				end
			end
		end
	end
	return out
end

return PortalClearance
