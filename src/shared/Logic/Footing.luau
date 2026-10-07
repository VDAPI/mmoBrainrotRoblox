--!strict
-- Feet on the ground (S29). Pure: NpcService passes the parts of a placed figure as plain boxes (centre, 3x3
-- rotation, size) and gets back how far to move the model up (or down) so its lowest point rests on the ground.
-- Every box counts with its 8 corners, so rotated parts (a bent leg, a tilted foot) are measured exactly.

local Footing = {}

-- Feet rest this far above the ground, so they never clip into terrain voxels.
Footing.CLEARANCE = 0.02

-- p = centre { x, y, z }; r = rotation, row-major (the order of CFrame:GetComponents() after the position);
-- size = { x, y, z }. A box without `r` is axis-aligned.
export type Box = { p: { number }, r: { number }?, size: { number } }

-- Lowest world y over the corners of every box, or nil for an empty list.
function Footing.lowest(boxes: { Box }): number?
	local low: number? = nil
	for _, box in boxes do
		local r = box.r
		local hx, hy, hz = box.size[1] / 2, box.size[2] / 2, box.size[3] / 2
		-- Row 2 of the rotation gives world y of a local offset: y = r4 * lx + r5 * ly + r6 * lz.
		local r4, r5, r6 = 0, 1, 0
		if r then
			r4, r5, r6 = r[4], r[5], r[6]
		end
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local y = box.p[2] + r4 * sx * hx + r5 * sy * hy + r6 * sz * hz
					if low == nil or y < (low :: number) then
						low = y
					end
				end
			end
		end
	end
	return low
end

-- Vertical offset that puts the lowest corner at groundY + CLEARANCE: positive when the feet are under the
-- ground (lift), negative when the figure hangs in the air (lower). 0 for an empty list.
function Footing.liftFor(boxes: { Box }, groundY: number): number
	local low = Footing.lowest(boxes)
	if low == nil then
		return 0
	end
	return groundY + Footing.CLEARANCE - low
end

-- Humanoid.HipHeight that matches feet at groundY + CLEARANCE for a root part of height rootSizeY centred at
-- rootY (R15: the distance from the bottom of the root part to the ground). Never negative.
function Footing.hipHeight(rootY: number, rootSizeY: number, groundY: number): number
	return math.max(0, rootY - rootSizeY / 2 - (groundY + Footing.CLEARANCE))
end

return Footing
