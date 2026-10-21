--!strict
-- W31: the generic cave mouth round a portal's arch (World/Prefabs.caveMouth, the Meadows' Hideout, Burrow and Moss
-- Cave): the rock wall, the dark oval mouth in it, the hole straight behind the arch (Data/Portals.HOLE), two piles of
-- boulders and the lintel, in the portal's own frame (x across, y up from the ground, -z its face, +z into the rock).
-- Pure, so tests/portals.spec checks it against the painted arch like the generated frames.
--
-- W28 kept the boulders out of the old 14.5-wide arch; the Studio review (2026-10-21) found the painted arch 16 wide:
-- the boulders stand clear of it, the wall behind its depth, the hole centred on the veil.

local Portals = require("../Data/Portals")

local CaveMouth = {}

export type Piece = {
	name: string,
	shape: "box" | "ball",
	size: { number },
	at: { number },
	roll: number?, -- degrees about the frame's z (the lintel's tilt)
	r: { number }?, -- the same as a row-major rotation (tests)
	color: string,
	material: string,
	collide: boolean,
}

local DARK = "#050506"

local function rolled(deg: number): { number }
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

-- The pieces of the mouth; `rock` colours the wall, the boulders and the lintel.
function CaveMouth.pieces(rock: string?): { Piece }
	local stone = rock or "#5A5650"
	local hole = Portals.HOLE
	local out: { Piece } = {
		-- the rock face behind the arch's depth
		{
			name = "Back",
			shape = "box",
			size = { 34, 28, 10 },
			at = { 0, 12, 9.3 },
			color = stone,
			material = "Slate",
			collide = true,
		},
		-- the dark oval of the mouth on the face, round the arch
		{
			name = "Mouth",
			shape = "ball",
			size = { 22, 24, 0.2 },
			at = { 0, 8, 4.25 },
			color = DARK,
			material = "SmoothPlastic",
			collide = false,
		},
		-- the hole straight behind the arch (as Logic/WorldGen/Kit.portalHole)
		{
			name = "Hole",
			shape = "box",
			size = { hole.w, hole.top + 2, hole.d },
			at = { 0, (hole.top - 2) / 2, hole.z + hole.d / 2 },
			color = DARK,
			material = "SmoothPlastic",
			collide = false,
		},
		{
			name = "Lintel",
			shape = "box",
			size = { 28, 4, 6 },
			at = { 0, 21.6, 1 },
			roll = 4,
			r = rolled(4),
			color = stone,
			material = "Slate",
			collide = false,
		},
	}
	-- two pillars of stacked boulders beside the arch
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			local d = 7 - i
			table.insert(out, {
				name = "Boulder",
				shape = "ball",
				size = { d, d, d },
				at = { side * (12.6 + i * 0.4), 3 + i * 6.5, 1.5 },
				color = stone,
				material = "Slate",
				collide = true,
			})
		end
	end
	return out
end

return CaveMouth
