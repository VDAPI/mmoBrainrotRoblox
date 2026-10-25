--!strict
-- S162m (owner 2026-10-25, docs/ANIM-WZORCE §9 R1, R2, Q6): how a monster moves, so its walk, trot and run, its blows
-- and its leaps read on the clients. Pure: Entities/Monster applies the answers, the numbers come from Data/Combat
-- (passed in as `cfg`) and Data/MonsterAbilities. No Roblox API (Lune).
--
--   gaitOf        the pace of an AI state: idle (wandering, patrolling, spreading back to its spot) walks, going home
--                 trots, a fight (chase, cast) runs; replicated as the model attribute "Gait"
--   speedMul      x moveSpeed of a pace (Data/Combat.wanderSpeedMul, returnSpeedMultiplier, 1)
--   stopDistance  how close to its target a monster walks before it stands: a melee one meleeApproach x its reach (never
--                 into the target's body), a ranged one its reach (it keeps its distance)
--   approach      the point `stop` studs short of the target on the line from the monster (where MoveTo ends)
--   dashLanding   where a running dash (Data/MonsterAbilities `dash` without `leap`) ends: in front of the aimed point,
--                 never past `maxTravel`
--   arcHeight     the apex of a dash's flight in studs (0 = a run on the ground)
--   dashStart     how many seconds after the announcement the flight starts (it lands with the blow)
--   flightProgress the clients' progress of an announced flight (Dash* attributes) at a server time

local MonsterMove = {}

export type Gait = "walk" | "trot" | "run"

export type Config = {
	wanderSpeedMul: number,
	returnSpeedMultiplier: number,
	meleeApproach: number,
}

export type Dash = { seconds: number, arc: number, arcMin: number?, arcMax: number? }

-- Studs a monster keeps between its body and its target's (a melee one stops no closer than its half depth + this).
MonsterMove.BODY_GAP = 1.5
-- A running dash is skipped when its landing lies more than this many studs above or below the monster's ground (a
-- ledge or a drop: the humanoid would fall or stop at the wall).
MonsterMove.DASH_CLIMB = 6
-- A running dash shorter than this is no dash (the monster already stands there).
MonsterMove.DASH_MIN = 0.5

-- The pace of an AI state (Entities/Monster State).
function MonsterMove.gaitOf(state: string): Gait
	if state == "idle" then
		return "walk"
	elseif state == "return" then
		return "trot"
	end
	return "run"
end

-- Multiplier of the kind's moveSpeed at a pace.
function MonsterMove.speedMul(gait: Gait, cfg: Config): number
	if gait == "walk" then
		return cfg.wanderSpeedMul
	elseif gait == "trot" then
		return cfg.returnSpeedMultiplier
	end
	return 1
end

-- Flat studs from the target's centre where the monster stands: melee meleeApproach x reach, but never closer than its
-- own half depth + BODY_GAP (and never past the reach); ranged the reach itself.
function MonsterMove.stopDistance(attack: string, reach: number, halfDepth: number, cfg: Config): number
	if attack ~= "melee" then
		return reach
	end
	return math.min(reach, math.max(reach * cfg.meleeApproach, halfDepth + MonsterMove.BODY_GAP))
end

-- The point (x, z) `stop` studs short of (tx, tz) on the line from (fx, fz); the target itself when the monster stands
-- on it. Also returns the flat distance between them.
function MonsterMove.approach(fx: number, fz: number, tx: number, tz: number, stop: number): (number, number, number)
	local dx, dz = tx - fx, tz - fz
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-6 then
		return tx, tz, 0
	end
	local k = math.max(0, distance - stop) / distance
	return fx + dx * k, fz + dz * k, distance
end

-- Where a running dash from (fx, fz) at the point (ax, az) ends: `stop` studs short of it, at most `maxTravel` studs
-- away. Returns (x, z, travel); travel 0 = no dash (closer than DASH_MIN, or nothing to travel).
function MonsterMove.dashLanding(
	fx: number,
	fz: number,
	ax: number,
	az: number,
	stop: number,
	maxTravel: number
): (number, number, number)
	local dx, dz = ax - fx, az - fz
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-6 then
		return fx, fz, 0
	end
	local travel = math.clamp(distance - stop, 0, math.max(0, maxTravel))
	if travel < MonsterMove.DASH_MIN then
		return fx, fz, 0
	end
	local k = travel / distance
	return fx + dx * k, fz + dz * k, travel
end

-- Studs of the flight's apex over the straight line for a dash of `travel` studs (arcMin / arcMax x the look scale).
function MonsterMove.arcHeight(dash: Dash, travel: number, scale: number): number
	if dash.arc <= 0 then
		return 0
	end
	local low = (dash.arcMin or 0) * scale
	local high = (dash.arcMax or math.huge) * scale
	return math.clamp(dash.arc * travel, low, math.max(low, high))
end

-- Seconds after the announcement the flight starts: `windup - seconds`, never before the announcement, and the
-- flight's length (never longer than the windup).
function MonsterMove.dashStart(dash: Dash, windup: number): (number, number)
	local seconds = math.clamp(dash.seconds, 0, windup)
	return windup - seconds, seconds
end

-- For the clients: the progress 0..1 of a flight announced by the Dash* attributes at server time `now` (DashAt,
-- DashTime), nil before it starts or after it lands. The point on the flight is Logic/Gait.leapArc(k, DashFrom, DashTo,
-- DashArc).
function MonsterMove.flightProgress(now: number, dashAt: number, seconds: number): number?
	if now < dashAt or now > dashAt + seconds then
		return nil
	end
	return if seconds > 0 then (now - dashAt) / seconds else 1
end

return MonsterMove
