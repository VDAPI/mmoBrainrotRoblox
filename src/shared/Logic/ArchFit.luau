--!strict
-- How the painted portal model (Assets.Kit common_portal_01 / 02, World/Prefabs.portal) stands on a portal and where
-- its purple field goes, from the model's box in the portal's frame (x across, y up from the ground, -z the face;
-- `lo` / `hi` the box's corners as { x, y, z }). Pure, so tests/portals.spec checks it on the measured box.
--   * a model deeper than wide stands sideways and is turned 90 degrees about its pivot (W28),
--   * it keeps the size the arch's height gives it (Data/Portals.ARCH.height): W31 regression (Studio Play after
--     930a1ef0: every painted arch at a third of its size, the veil a small ball over it) when it was scaled into
--     a 16 x 18 x 6 box, its base slab making it 16 deep,
--   * the field fills the model's opening (W28 shares of its width and height, never over Data/Portals.ARCH.field)
--     and stands half a stud over the model's foot, centred on the model's box (the veil reaches about a stud under
--     the ground when the base slab is sunk 1.5 studs).

local Portals = require("../Data/Portals")

local ArchFit = {}

ArchFit.OPENING_WIDTH = 0.62
ArchFit.OPENING_HEIGHT = 0.78
ArchFit.FOOT = 0.5 -- the field's bottom over the model's foot

export type Fit = {
	turn: boolean,
	scale: number,
	field: { w: number, h: number, x: number, y: number, z: number },
}

-- Whether the model with this box stands sideways (deeper than wide).
function ArchFit.sideways(lo: { number }, hi: { number }): boolean
	return (hi[3] - lo[3]) > (hi[1] - lo[1])
end

-- The box after turning the model 90 degrees about the frame's y axis (CFrame.Angles(0, pi / 2, 0) about the
-- pivot at the frame's origin: x' = z, z' = -x).
function ArchFit.turned(lo: { number }, hi: { number }): ({ number }, { number })
	return { lo[3], lo[2], -hi[1] }, { hi[3], hi[2], -lo[1] }
end

-- The fit of a model whose box (already standing across the portal) is `lo` .. `hi`: `scale` is the factor on top
-- of the height scaling (always 1: the arch keeps its size), `field` the field's size and centre.
function ArchFit.field(lo: { number }, hi: { number }): { w: number, h: number, x: number, y: number, z: number }
	local spec = Portals.ARCH.field
	local w = math.min(spec.w, (hi[1] - lo[1]) * ArchFit.OPENING_WIDTH)
	local h = math.min(spec.h, (hi[2] - lo[2]) * ArchFit.OPENING_HEIGHT)
	return {
		w = w,
		h = h,
		x = (lo[1] + hi[1]) / 2,
		y = lo[2] + ArchFit.FOOT + h / 2,
		z = (lo[3] + hi[3]) / 2,
	}
end

-- The whole fit from the box measured right after the model is placed (before any turn).
function ArchFit.fit(lo: { number }, hi: { number }): Fit
	local turn = ArchFit.sideways(lo, hi)
	if turn then
		lo, hi = ArchFit.turned(lo, hi)
	end
	return { turn = turn, scale = 1, field = ArchFit.field(lo, hi) }
end

return ArchFit
