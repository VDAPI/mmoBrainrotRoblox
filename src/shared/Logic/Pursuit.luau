--!strict
-- S162e (owner's tester 2026-10-31: "monsters get stuck on terrain obstacles, so players cheese them"): how a chasing
-- monster gets around what blocks it and when it gives up. Pure: Entities/Monster probes the world, asks
-- PathfindingService and applies the answers; the numbers come from Data/Combat (passed in as `cfg`). No Roblox API.
--
--   advance     studs one step moved towards the point the monster walks to (the target, or the next point of its
--               path): sliding along a wall, jittering in place or backing off counts 0 or less
--   track       the progress record after a step: `pursuitProgress` studs gained towards the goal = progress
--   decide      what a chasing monster does now: chase on, ask for a new path ("repath") or give up ("evade"). It
--               evades when it can neither reach nor hit its target: no progress for `pursuitEvade` seconds, or a path
--               answer "no way" and no progress for `pursuitRepath` seconds. Standing where its blow, shot or throw
--               reaches the target is never stalling (a ranged monster needs no path to its target)
--   take        the server's path budget: a token bucket (`pathPerSecond`, at most `pathBurst` at once)
--   agent       the PathfindingService agent of a body, rounded up to a few sizes (one navmesh per size)
--   stepHeight  how high a step a body walks onto without turning (only its root collides and the humanoid keeps the
--               root `hipHeight` over the floor: lower obstacles pass under it, a hovering flyer's too)

local Pursuit = {}

export type Config = {
	pursuitProgress: number,
	pursuitRepath: number,
	pursuitEvade: number,
	pathPerSecond: number,
	pathBurst: number,
}

export type Action = "chase" | "repath" | "evade"

export type Situation = {
	stalled: number, -- seconds since the last progress
	canHit: boolean, -- its blow, shot or throw reaches the target from where it stands
	asked: boolean, -- a path was asked for since the last progress
	pending: boolean, -- a path is being computed
	noPath: boolean, -- a path answer since the last progress found no way
	mayEvade: boolean, -- false for bosses and their helpers (their arenas have their own rules)
}

export type Bucket = { tokens: number, at: number }

-- Agent sizes (studs): the radius is half the root's wider side + a gap, the height the hip height + the root's.
Pursuit.RADII = table.freeze({ 1.5, 2.5, 4, 6 })
Pursuit.HEIGHTS = table.freeze({ 4, 6, 9, 13, 20 })
Pursuit.RADIUS_GAP = 0.5
-- Shortest step the probes treat as walkable (studs), and the share of the hip height a step may reach.
Pursuit.STEP_MIN = 0.5
Pursuit.STEP_SHARE = 0.8

-- Studs moved from (fx, fz) to (tx, tz) along the direction from (fx, fz) to the goal (gx, gz); 0 at the goal.
function Pursuit.advance(fx: number, fz: number, tx: number, tz: number, gx: number, gz: number): number
	local dx, dz = gx - fx, gz - fz
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		return 0
	end
	return ((tx - fx) * dx + (tz - fz) * dz) / length
end

-- The record after a step of `advance` studs: (new sum, progressed). A step back lowers the sum (jittering back and forth
-- gains nothing), never below -pursuitProgress (a detour backwards is forgotten soon).
function Pursuit.track(acc: number, advance: number, cfg: Config): (number, boolean)
	local sum = math.max(acc + advance, -cfg.pursuitProgress)
	if sum >= cfg.pursuitProgress then
		return 0, true
	end
	return sum, false
end

-- What a chasing monster does now.
function Pursuit.decide(s: Situation, cfg: Config): Action
	if s.canHit then
		return "chase"
	end
	if s.mayEvade and (s.stalled >= cfg.pursuitEvade or (s.noPath and s.stalled >= cfg.pursuitRepath)) then
		return "evade"
	end
	if s.stalled >= cfg.pursuitRepath and not s.asked and not s.pending then
		return "repath"
	end
	return "chase"
end

function Pursuit.newBucket(cfg: Config, now: number): Bucket
	return { tokens = cfg.pathBurst, at = now }
end

-- Takes one path from the server's budget (refilled at pathPerSecond, at most pathBurst saved). Mutates `bucket`.
function Pursuit.take(bucket: Bucket, now: number, cfg: Config): boolean
	bucket.tokens = math.min(cfg.pathBurst, bucket.tokens + math.max(0, now - bucket.at) * cfg.pathPerSecond)
	bucket.at = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

local function roundUp(value: number, sizes: { number }): number
	for _, size in sizes do
		if value <= size then
			return size
		end
	end
	return sizes[#sizes]
end

-- (radius, height) of the PathfindingService agent for a root of size (x, y, z) standing hipHeight over the floor.
function Pursuit.agent(x: number, y: number, z: number, hipHeight: number): (number, number)
	local radius = roundUp(math.max(x, z) / 2 + Pursuit.RADIUS_GAP, Pursuit.RADII)
	local height = roundUp(hipHeight + y, Pursuit.HEIGHTS)
	return radius, height
end

-- Studs over its feet below which an obstacle is walked over (the steering probes cast their low ray there).
function Pursuit.stepHeight(hipHeight: number): number
	return math.max(Pursuit.STEP_MIN, hipHeight * Pursuit.STEP_SHARE)
end

return Pursuit
