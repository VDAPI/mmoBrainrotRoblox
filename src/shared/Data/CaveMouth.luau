--!strict
-- The generic rock mouth of a cave on a region map (World/Prefabs.caveMouth: the Moss Cave on the Meadows), in the
-- portal's frame (x across, y up from the ground, -z the face the player comes from; Data/Portals.ARCH stands at
-- z 0). Studio review 2026-10-21 ("the rocks look like smooth boxes"): the one 34 x 28 x 10 box behind the hole and
-- the straight lintel became leaning slabs of Rock (a back slab, two buttresses, a crown and a lintel of two stones),
-- each turned a little, in three shades; the stacked boulders of the pillars are Rock too. Six slabs for the two boxes
-- (+4 parts). None reaches into the arch (Data/Portals clearance) or before the dark hole within the arch's width
-- (tests/cavemouth.spec). Partia 6 (W31, the painted arch fitted into Data/Portals.ARCH.model, 16 wide, 6 deep): the
-- mouth keeps out of Data/Portals.frameKeepOut too (the painted arch, its view from the path, the opening before the
-- hole): the pillars' boulders 12 studs from the axis (11 touched the painted pillars), the hole straight behind the
-- arch like every dressed cave mouth's (Data/Portals.HOLE), the back slab behind it, the torches 10 studs out.
-- W31 fix (the painted arch keeps its full size, its real footprint with the base slab 21 x 16.5): the buttresses,
-- the boulders and the torches further out, the hole and the back slab further back (Data/Portals.ARCH.model).

export type Slab = {
	name: string,
	size: { number }, -- studs
	p: { number }, -- centre
	r: { number }, -- degrees about x, y, z (CFrame.Angles order)
	shade: number, -- -1 darker, 0 the rock colour, 1 lighter
}

local SLABS: { Slab } = {
	-- behind the hole, leaning back
	{ name = "Back", size = { 30, 26, 8 }, p = { 0, 11, 15 }, r = { 4, 0, 0 }, shade = -1 },
	-- the buttresses either side, turned towards the path and leaning out
	{ name = "Buttress", size = { 11, 25, 10 }, p = { -18.6, 10.5, 7 }, r = { 3, 14, -5 }, shade = 0 },
	{ name = "Buttress", size = { 10, 23, 9 }, p = { 18, 9.5, 7.5 }, r = { -2, -12, 6 }, shade = 1 },
	-- the crown over everything, tipped back
	{ name = "Crown", size = { 28, 8, 10 }, p = { 0.5, 24.5, 6 }, r = { 8, 3, -3 }, shade = 0 },
	-- the lintel: two stones meeting over the arch
	{ name = "Lintel", size = { 15, 4.2, 6 }, p = { -5.2, 21.4, 1.4 }, r = { 0, 5, 6 }, shade = 1 },
	{ name = "Lintel", size = { 14, 4.6, 6.5 }, p = { 6.3, 21.1, 1.6 }, r = { 0, -7, -5 }, shade = -1 },
}

-- The stacked boulders of the two pillars: side * (x + i * step), y0 + i * rise, z; diameter size - i (i = 0, 1, 2).
local BOULDERS = table.freeze({ x = 14.4, step = 0.6, y0 = 3, rise = 6.5, z = 1, size = 7 })

-- The dark hole the portal stands in front of: its face 9.18 behind the veil (Data/Portals.HOLE: from the arch's back
-- plus margin to HOLE.z + 0.5), 17 wide, from under the ground to 16.75, its visible middle near the veil's.
local HOLE = table.freeze({ size = table.freeze({ 17, 17.5, 0.6 }), p = table.freeze({ 0, 8, 9.48 }) })

-- The two torches before the mouth: side * x across, z before the veil (W31: clear of the painted arch).
local TORCHES = table.freeze({ x = 12.5, z = -6 })

-- Rotation matrix (row-major 3 x 3) of CFrame.Angles(rx, ry, rz) in degrees: Rx * Ry * Rz.
local function matrix(r: { number }): { number }
	local ax, ay, az = math.rad(r[1]), math.rad(r[2]), math.rad(r[3])
	local cx, sx = math.cos(ax), math.sin(ax)
	local cy, sy = math.cos(ay), math.sin(ay)
	local cz, sz = math.cos(az), math.sin(az)
	local X = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	local function mul(a: { number }, b: { number }): { number }
		local out = table.create(9, 0)
		for i = 0, 2 do
			for j = 0, 2 do
				out[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[j + 4] + a[i * 3 + 3] * b[j + 7]
			end
		end
		return out
	end
	return mul(mul(X, Y), Z)
end

return table.freeze({
	SLABS = table.freeze(SLABS),
	BOULDERS = BOULDERS,
	HOLE = HOLE,
	TORCHES = TORCHES,
	matrix = matrix,
})
