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
--     the ground when the base slab is sunk 1.5 studs),
--   * owner 2026-10-31 (Studio Play: the light of the cave and dungeon exits half in a thick pillar and in the base
--     slab of common_portal_02): a model with its own entry (Data/Portals.MODEL_OPENING) gets the field there
--     instead; the veil, the core, the sparkles, the light, the "E" prompt, the server's range and the zone label all
--     hang on the field,
--   * owner 2026-11-10 (Play on the Meadows: "a gate with no teleport in it, the field weirdly in between"):
--     common_portal_02 is a small shrine, not a ruin: steps up to a rune arch at its front, a slab behind the arch and
--     a stele at its back. W28 turned it for being deeper than wide, so its arch looked sideways and the opening found
--     on 10-31 was the gap between the stele and the arch. An entry now says whether its model turns (this one stands
--     as made, its arch to the path); the model moves forward until its back is inside the arch's footprint
--     (Data/Portals.ARCH.model, which the frames round cave mouths keep free); the server shoots rays through its
--     front once per model (ArchFit.grid, World/Prefabs.fitModel), finds the arch's opening (ArchFit.opening) and puts
--     the field there, its veil the biggest ellipse that fits (ArchFit.inOpening). The entry's shares are the field
--     when the rays find no opening.

local Portals = require("../Data/Portals")

local ArchFit = {}

ArchFit.OPENING_WIDTH = 0.62
ArchFit.OPENING_HEIGHT = 0.78
ArchFit.FOOT = 0.5 -- the field's bottom over the model's foot
-- The rays through a model's front: one every `step` studs across and up its box, each through the front `depth` of
-- the box's depth (the arch and the steps before it, never the stele at a shrine's back); an opening at least
-- `minHeight` studs tall; the veil `margin` studs clear of the stone and at least `minHalf` studs wide on each side.
ArchFit.SCAN = table.freeze({ step = 0.5, depth = 0.45, minHeight = 5, margin = 0.3, minHalf = 1.5 })

export type Field = { w: number, h: number, x: number, y: number, z: number }

export type Fit = {
	turn: boolean,
	scale: number,
	shift: number,
	field: Field,
}

-- The rays through a model's front: column `c` and row `r` shoot from (x0 + (c - 1) * step, y0 + (r - 1) * step,
-- `from`) along the portal's +z for `reach` studs.
export type Grid = { x0: number, y0: number, step: number, cols: number, rows: number, from: number, reach: number }

-- One row of an opening the rays found: its height and the free span between the stone on both sides.
export type Row = { y: number, left: number, right: number }

-- The opening the rays found: its rows from the lowest up (`step` apart), its floor and crown (the rows' outer edges)
-- and the column it stacks on.
export type Scan = { rows: { Row }, step: number, bottom: number, top: number, x: number }

-- Whether the model with this box stands sideways (deeper than wide).
function ArchFit.sideways(lo: { number }, hi: { number }): boolean
	return (hi[3] - lo[3]) > (hi[1] - lo[1])
end

-- The box after turning the model 90 degrees about the frame's y axis (CFrame.Angles(0, pi / 2, 0) about the
-- pivot at the frame's origin: x' = z, z' = -x).
function ArchFit.turned(lo: { number }, hi: { number }): ({ number }, { number })
	return { lo[3], lo[2], -hi[1] }, { hi[3], hi[2], -lo[1] }
end

-- How far a model with its own entry (Data/Portals.MODEL_OPENING) whose box, as it stands, ends at `hi` moves along
-- the portal's z: forward (towards the path) by what it reaches behind the arch's footprint (ARCH.model), never back.
function ArchFit.shift(hi: { number }): number
	return math.min(0, Portals.ARCH.model.d / 2 - hi[3])
end

-- The field of a model whose box (already standing across the portal) is `lo` .. `hi`: its size and centre. `model`
-- is the painted model's name (Assets.Kit); one with an entry in Data/Portals.MODEL_OPENING has its field where the
-- entry's shares say, any other one centred on its box.
function ArchFit.field(lo: { number }, hi: { number }, model: string?): Field
	local spec = Portals.ARCH.field
	local width, height = hi[1] - lo[1], hi[2] - lo[2]
	local opening = if model then Portals.MODEL_OPENING[model] else nil
	if opening then
		local w = math.min(spec.w, width * opening.w)
		local h = math.min(spec.h, height * opening.h)
		return {
			w = w,
			h = h,
			x = (lo[1] + hi[1]) / 2 + width * opening.x,
			y = lo[2] + height * opening.foot + h / 2,
			z = lo[3] + (hi[3] - lo[3]) * opening.z,
		}
	end
	local w = math.min(spec.w, width * ArchFit.OPENING_WIDTH)
	local h = math.min(spec.h, height * ArchFit.OPENING_HEIGHT)
	return {
		w = w,
		h = h,
		x = (lo[1] + hi[1]) / 2,
		y = lo[2] + ArchFit.FOOT + h / 2,
		z = (lo[3] + hi[3]) / 2,
	}
end

-- The whole fit from the box measured right after the model `model` is placed (before any turn): whether it turns
-- (its entry says so; without one, when it is deeper than wide), `scale` the factor on top of the height scaling
-- (always 1: the arch keeps its size), `shift` how far it then moves along the portal's z (only a model with its
-- own entry, ArchFit.shift) and `field` the field's size and centre there (for a model whose arch the rays measure,
-- the field when they find no opening).
function ArchFit.fit(lo: { number }, hi: { number }, model: string?): Fit
	local opening = if model then Portals.MODEL_OPENING[model] else nil
	local turn = if opening then opening.turn else ArchFit.sideways(lo, hi)
	if turn then
		lo, hi = ArchFit.turned(lo, hi)
	end
	local shift = if opening then ArchFit.shift(hi) else 0
	if shift ~= 0 then
		lo, hi = { lo[1], lo[2], lo[3] + shift }, { hi[1], hi[2], hi[3] + shift }
	end
	return { turn = turn, scale = 1, shift = shift, field = ArchFit.field(lo, hi, model) }
end

-- The rays through the front of a model whose box, as it stands on the portal, is `lo` .. `hi`: columns and rows
-- SCAN.step apart, centred on the box, each from a stud in front of the box through its front SCAN.depth.
function ArchFit.grid(lo: { number }, hi: { number }): Grid
	local step = ArchFit.SCAN.step
	local width, height = hi[1] - lo[1], hi[2] - lo[2]
	local cols = math.max(1, math.floor(width / step))
	local rows = math.max(1, math.floor(height / step))
	return {
		x0 = lo[1] + (width - (cols - 1) * step) / 2,
		y0 = lo[2] + (height - (rows - 1) * step) / 2,
		step = step,
		cols = cols,
		rows = rows,
		from = lo[3] - 1,
		reach = 1 + (hi[3] - lo[3]) * ArchFit.SCAN.depth,
	}
end

-- The opening the rays of `grid` found (`blocked[(row - 1) * cols + col]`: that ray met the model within its reach):
-- in every row the runs of free rays with stone on both sides (a run reaching a side of the box is the air beside the
-- arch, over its crown or round a pillar), the column inside such runs in the most rows (the nearer to the middle on a
-- tie) and the tallest stack of rows whose run holds it, from the steps or the slab up to the crown. Nil when no such
-- stack is SCAN.minHeight tall (the model's collision fills its arch, or the rays met nothing).
function ArchFit.opening(grid: Grid, blocked: { boolean }): Scan?
	local cols, rows, step = grid.cols, grid.rows, grid.step
	local runs: { { [number]: { number } } } = {}
	local count = table.create(cols, 0)
	for r = 1, rows do
		local row: { [number]: { number } } = {}
		local c = 1
		while c <= cols do
			if not blocked[(r - 1) * cols + c] then
				local c0 = c
				while c < cols and not blocked[(r - 1) * cols + c + 1] do
					c += 1
				end
				if c0 > 1 and c < cols then
					local run = { c0, c }
					for k = c0, c do
						row[k] = run
						count[k] += 1
					end
				end
			end
			c += 1
		end
		runs[r] = row
	end
	local mid = (cols + 1) / 2
	local best, most = 0, 0
	for c = 1, cols do
		if count[c] > most or (count[c] == most and most > 0 and math.abs(c - mid) < math.abs(best - mid)) then
			best, most = c, count[c]
		end
	end
	if best == 0 then
		return nil
	end
	local start, length, first, tallest = 0, 0, 0, 0
	for r = 1, rows do
		if runs[r][best] then
			if length == 0 then
				start = r
			end
			length += 1
			if length > tallest then
				first, tallest = start, length
			end
		else
			length = 0
		end
	end
	if tallest * step < ArchFit.SCAN.minHeight then
		return nil
	end
	local found: { Row } = {}
	for r = first, first + tallest - 1 do
		local run = runs[r][best]
		table.insert(found, {
			y = grid.y0 + (r - 1) * step,
			left = grid.x0 + (run[1] - 1) * step - step / 2,
			right = grid.x0 + (run[2] - 1) * step + step / 2,
		})
	end
	return {
		rows = found,
		step = step,
		bottom = found[1].y - step / 2,
		top = found[#found].y + step / 2,
		x = grid.x0 + (best - 1) * step,
	}
end

-- The field in the opening `scan` found, at the arch's middle `z`: its veil (Data/Portals.LOOK.veil, the field's
-- share) the biggest ellipse that stands SCAN.margin clear of the opening's sides, crown and floor, centred across
-- on the middle of the opening's rows, standing on its floor, never bigger than ARCH.field's veil. Nil when no
-- ellipse SCAN.minHalf wide on each side fits.
function ArchFit.inOpening(scan: Scan, z: number): Field?
	local spec, veil, margin = Portals.ARCH.field, Portals.LOOK.veil, ArchFit.SCAN.margin
	local maxA, maxB = spec.w * veil.w / 2, spec.h * veil.h / 2
	local rows = scan.rows
	local mids = {}
	for _, row in rows do
		table.insert(mids, (row.left + row.right) / 2)
	end
	table.sort(mids)
	local cx = mids[math.floor((#mids + 1) / 2)]
	local half = scan.step / 2
	local bottom = scan.bottom + margin
	local bestA, bestB, bestArea = 0, 0, 0
	for k = #rows, 1, -1 do
		local top = rows[k].y + half - margin
		local b = math.min(maxB, (top - bottom) / 2)
		if b * 2 < ArchFit.SCAN.minHeight - 2 * margin then
			break
		end
		local cy = bottom + b
		local a = maxA
		for _, row in rows do
			local y = math.clamp(cy, row.y - half, row.y + half)
			local t = (y - cy) / b
			if math.abs(t) < 1 then
				local room = math.min(cx - row.left, row.right - cx) - margin
				a = math.min(a, room / math.sqrt(1 - t * t))
			end
		end
		if a >= ArchFit.SCAN.minHalf and a * b > bestArea then
			bestA, bestB, bestArea = a, b, a * b
		end
	end
	if bestArea <= 0 then
		return nil
	end
	return {
		w = bestA * 2 / veil.w,
		h = bestB * 2 / veil.h,
		x = cx,
		y = bottom + bestB,
		z = z,
	}
end

return ArchFit
