--!strict
-- Owner 2026-11-10 ("they may block, but no climbing"): a monster's blocker (Data/BodyGroups) stands over the highest a
-- player's body gets beside it, but any finite column can still be landed on from above (a ledge, a cliff, a jump off a
-- rock), and a Humanoid on its top rides the monster. The client checks its own character about ten times a second
-- against the replicated blockers of the monsters near it (client MovementController) and, when it stands on one or is
-- coming down onto one, slides it off: a push on the ground plane away from the column's centre (along the character's
-- facing when dead centre), fast and long enough to carry the body past the column's edge, so it drops beside the
-- monster. Geometry, not a ray: an ordinary ray passes through the blocker (its group never meets the world's,
-- Data/BodyGroups.APART), and one down the root's centre would miss a column the body stands on with its edge only.
-- The body is over the column's footprint grown by its half width, and its feet (the root's bottom less HipHeight) are
-- within SINK of the column's top, or over it and falling from not far above. A body on the ground beside a monster (a
-- walker or a rider) has its feet a whole column under the top, and a dead monster's column no longer collides, so
-- neither is ever pushed. Pure (Lune): tests/blockerguard.spec.

local BlockerGuard = {}

BlockerGuard.EVERY = 0.1 -- seconds between checks
BlockerGuard.RANGE = 20 -- studs on the ground plane from the character's root to a column worth checking
BlockerGuard.SINK = 0.6 -- studs: feet this close to the top, over or under it, stand on it
BlockerGuard.ABOVE = 4 -- studs: feet falling from at most this far over the top are about to land on it
-- Studs a second down: a body sinking slower stands (on a bridge or a ledge over a column), it is not falling onto it.
BlockerGuard.FALLING = 1
BlockerGuard.CENTRE = 0.1 -- studs from the column's centre that count as dead centre (the facing picks the way)
BlockerGuard.PAST = 0.5 -- studs past the grown footprint's edge a push carries the body
-- Speed of a push relative to the column (studs a second): it covers its way in PUSH_TIME, never slower than MIN_SPEED
-- (a slide, not a creep) nor faster than MAX_SPEED (a wide boss's column takes longer).
BlockerGuard.PUSH_TIME = 0.25
BlockerGuard.MIN_SPEED = 12
BlockerGuard.MAX_SPEED = 40
-- Turns (degrees) of the push after 0, 1, 2, 3 pushes in a row: a wall may stand where the first one went.
BlockerGuard.TURNS = table.freeze({ 0, 90, -90, 180 })

-- The local character, on the ground plane (x, z) and in height.
export type Body = {
	x: number, -- the root's centre
	z: number,
	feet: number, -- the feet: the root's bottom less HipHeight (R6: less its legs too)
	half: number, -- half the body's width (the root's larger flat side)
	vy: number, -- vertical velocity, up +
	lookX: number, -- its facing (need not be unit)
	lookZ: number,
}

-- A monster's blocker as the client sees it.
export type Column = {
	x: number, -- its centre
	y: number,
	z: number,
	rightX: number, -- its right vector on the ground plane (need not be unit)
	rightZ: number,
	width: number, -- its size along the right vector
	height: number,
	depth: number,
	vx: number, -- its velocity on the ground plane (it walks with the monster)
	vz: number,
	collides: boolean, -- false once the monster is dead (RigBuilder.dropBlocker)
}

-- The push: the ground-plane velocity to hold (vx, vz, world), for `time` seconds, and the unit way it goes.
export type Push = { vx: number, vz: number, time: number, dirX: number, dirZ: number }

-- The column's right vector, unit (its X axis; the depth axis is (-z, x)).
local function axes(column: Column): (number, number)
	local length = math.sqrt(column.rightX * column.rightX + column.rightZ * column.rightZ)
	if length < 1e-6 then
		return 1, 0
	end
	return column.rightX / length, column.rightZ / length
end

-- A world ground-plane vector in the column's frame (along its width and its depth).
local function toColumn(column: Column, x: number, z: number): (number, number)
	local rx, rz = axes(column)
	return x * rx + z * rz, -x * rz + z * rx
end

-- Whether the body is over the column's footprint grown by the body's half width.
function BlockerGuard.over(body: Body, column: Column): boolean
	local lx, lz = toColumn(column, body.x - column.x, body.z - column.z)
	return math.abs(lx) <= column.width / 2 + body.half and math.abs(lz) <= column.depth / 2 + body.half
end

-- Whether the body stands on the column (its feet within SINK of the top) or is coming down onto it (falling, its
-- feet over the top by at most ABOVE). Never for a column that no longer collides.
function BlockerGuard.on(body: Body, column: Column): boolean
	if not column.collides or not BlockerGuard.over(body, column) then
		return false
	end
	local rise = body.feet - (column.y + column.height / 2)
	if math.abs(rise) <= BlockerGuard.SINK then
		return true
	end
	return rise > 0 and rise <= BlockerGuard.ABOVE and body.vy < -BlockerGuard.FALLING
end

-- The unit way off the column: away from its centre (the facing when dead centre, the column's right vector when the
-- facing is straight up or down), turned by TURNS after `attempt` pushes in a row.
function BlockerGuard.direction(body: Body, column: Column, attempt: number): (number, number)
	local dx, dz = body.x - column.x, body.z - column.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < BlockerGuard.CENTRE then
		dx, dz = body.lookX, body.lookZ
		length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-6 then
			dx, dz = axes(column)
			length = 1
		end
	end
	dx, dz = dx / length, dz / length
	local turn = math.rad(BlockerGuard.TURNS[attempt % #BlockerGuard.TURNS + 1])
	local c, s = math.cos(turn), math.sin(turn)
	return dx * c - dz * s, dx * s + dz * c
end

-- Studs the body moves along the unit way (dirX, dirZ) until it leaves the grown footprint (0 when already out).
function BlockerGuard.exit(body: Body, column: Column, dirX: number, dirZ: number): number
	local px, pz = toColumn(column, body.x - column.x, body.z - column.z)
	local ex, ez = toColumn(column, dirX, dirZ)
	local hx, hz = column.width / 2 + body.half, column.depth / 2 + body.half
	local best = math.huge
	if math.abs(ex) > 1e-6 then
		best = math.min(best, (hx - px * math.sign(ex)) / math.abs(ex))
	end
	if math.abs(ez) > 1e-6 then
		best = math.min(best, (hz - pz * math.sign(ez)) / math.abs(ez))
	end
	return if best == math.huge then 0 else math.max(0, best)
end

-- The push that slides the body off the column, or nil when it is not on it (BlockerGuard.on). `attempt`: pushes in a
-- row before this one. The velocity is the column's own plus the slide, so a walking monster does not carry the body
-- back under it; the slide covers the way past the edge (PAST) in `time`.
function BlockerGuard.push(body: Body, column: Column, attempt: number?): Push?
	if not BlockerGuard.on(body, column) then
		return nil
	end
	local dirX, dirZ = BlockerGuard.direction(body, column, attempt or 0)
	local way = BlockerGuard.exit(body, column, dirX, dirZ) + BlockerGuard.PAST
	local speed = math.clamp(way / BlockerGuard.PUSH_TIME, BlockerGuard.MIN_SPEED, BlockerGuard.MAX_SPEED)
	return {
		vx = column.vx + dirX * speed,
		vz = column.vz + dirZ * speed,
		time = way / speed,
		dirX = dirX,
		dirZ = dirZ,
	}
end

return BlockerGuard
