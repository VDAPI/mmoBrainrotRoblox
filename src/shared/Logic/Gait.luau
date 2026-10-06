--!strict
-- Procedural poses for placeholder monster rigs (no animation assets). RigBuilder joins the limbs with
-- Motor6Ds named "Gait_<part>" carrying the attributes Role, Side, Phase and Amp; the client
-- (AnimationController) turns the monster's movement and combat events into a Motion every frame and asks
-- this module for each joint's rotation and offset. Pure numbers only, so it runs in Lune.

local Gait = {}

-- S24 adds: flap (wings of the generated looks), segment (a wave along a chain: serpents, tails, trunks),
-- claw (pincers open in the windup), sting (a tail strikes forward), jaw (opens to bite), orbit (slow turn
-- around Y: shards, skulls). Every role is at rest (all zeros) for the rest motion (time 0, nothing going on);
-- the continuous ones fade in over the first second of `time`, which in game is never near 0.
export type Role =
	"body"
	| "leg"
	| "spiderLeg"
	| "arm"
	| "head"
	| "tail"
	| "wing"
	| "flap"
	| "segment"
	| "claw"
	| "sting"
	| "jaw"
	| "orbit"

Gait.ROLES = {
	"body",
	"leg",
	"spiderLeg",
	"arm",
	"head",
	"tail",
	"wing",
	"flap",
	"segment",
	"claw",
	"sting",
	"jaw",
	"orbit",
}

export type Joint = {
	role: Role,
	side: number, -- -1 left, 1 right, 0 centre
	phase: number, -- 0..1 offset in the walk cycle
	amp: number, -- amplitude multiplier (1 = default; body: hover height for flyers)
}

export type Motion = {
	cycle: number, -- walk cycle angle (radians), advanced by Gait.advance
	move: number, -- 0..1 how much the monster is walking
	time: number, -- seconds, for idle motion (already offset per monster)
	raise: number, -- 0..1 attack windup (limb raised / head reared)
	strike: number, -- 0..1 attack strike (lunge / bite)
	hit: number, -- 0..1 flinch after taking damage
	dead: number, -- 0..1 collapse progress
}

-- Rotation in radians around the joint's X, Y, Z and offset in studs at scale 1 (the caller scales it).
export type Pose = { rx: number, ry: number, rz: number, x: number, y: number, z: number }

-- Attack timing (seconds).
Gait.STRIKE_SECONDS = 0.14
Gait.RECOVER_SECONDS = 0.35
Gait.DEFAULT_WINDUP = 0.22
-- Stride length (studs at scale 1): one full cycle covers this distance.
Gait.STRIDE = 4.5

local TAU = 2 * math.pi

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Advances the walk cycle by the distance travelled; bigger monsters take longer strides.
function Gait.advance(cycle: number, dt: number, speed: number, scale: number): number
	local stride = Gait.STRIDE * math.max(scale, 0.2)
	return (cycle + dt * speed / stride * TAU) % TAU
end

-- Attack curve after `elapsed` seconds: (raise, strike), both 0..1. The limb rises during the windup,
-- snaps forward during the strike and settles back. Returns zeros before and after.
function Gait.attack(elapsed: number, windup: number): (number, number)
	if elapsed < 0 then
		return 0, 0
	end
	windup = math.max(windup, 0.05)
	if elapsed < windup then
		return smooth(elapsed / windup), 0
	end
	local t = elapsed - windup
	if t < Gait.STRIKE_SECONDS then
		local k = t / Gait.STRIKE_SECONDS
		return 1 - k * 0.8, k
	end
	t -= Gait.STRIKE_SECONDS
	if t < Gait.RECOVER_SECONDS then
		local k = smooth(t / Gait.RECOVER_SECONDS)
		return 0.2 * (1 - k), 1 - k
	end
	return 0, 0
end

-- Total length of an attack with the given windup.
function Gait.attackLength(windup: number): number
	return math.max(windup, 0.05) + Gait.STRIKE_SECONDS + Gait.RECOVER_SECONDS
end

local function pose(rx: number, ry: number, rz: number, x: number, y: number, z: number): Pose
	return { rx = rx, ry = ry, rz = rz, x = x, y = y, z = z }
end

function Gait.pose(joint: Joint, m: Motion): Pose
	local amp = joint.amp
	local swing = math.sin(m.cycle + joint.phase * TAU)
	local alive = 1 - m.dead
	local idle = 1 - m.move
	local role = joint.role

	if role == "body" then
		-- Breathing bob (or hovering for flyers), a lean into the strike, a flinch when hit, then the collapse.
		local hover = if amp > 1 then amp - 1 else 0
		local bob = math.sin(m.time * 2) * 0.05 + math.sin(m.time * 1.6) * hover
		local step = math.abs(swing) * 0.08 * m.move
		local lean = -m.strike * 0.14 + m.raise * 0.06 + m.hit * 0.12
		return pose(
			lean * alive,
			0,
			m.dead * 1.35,
			0,
			(bob + step) * alive - m.dead * 0.4,
			-m.strike * 0.5 * alive + m.hit * 0.15
		)
	elseif role == "leg" then
		local walk = swing * 0.65 * amp * m.move
		return pose(walk * alive + m.dead * 0.5, 0, 0, 0, 0, 0)
	elseif role == "spiderLeg" then
		-- Legs stick out sideways: swing forward/back around Y, lift around Z.
		local lift = math.max(0, math.cos(m.cycle + joint.phase * TAU)) * 0.35 * m.move
		local twitch = math.sin(m.time * 9 + joint.phase * TAU) * 0.04 * idle
		return pose(
			0,
			swing * 0.4 * amp * m.move * alive,
			joint.side * (lift + twitch) * alive + joint.side * m.dead * 0.6,
			0,
			0,
			0
		)
	elseif role == "arm" then
		-- Arms swing against the legs; the right arm (side 1) carries the attack, the left follows a little.
		local walk = -swing * 0.5 * amp * m.move
		local share = if joint.side > 0 then 1 else 0.3
		local attack = (m.raise * 2.3 - m.strike * 0.5 * (1 - m.raise)) * share
		local sway = math.sin(m.time * 1.8 + joint.side) * 0.04 * idle
		return pose((walk + attack + sway) * alive, 0, joint.side * (0.05 + m.raise * 0.15 * share) * alive, 0, 0, 0)
	elseif role == "head" then
		-- Looks around while idle, rears up in the windup, bites down on the strike.
		local look = math.sin(m.time * 0.7) * 0.25 * idle
		local nod = math.sin(m.cycle * 2) * 0.05 * m.move
		local rx = m.raise * 0.45 - m.strike * 0.55 + nod - m.hit * 0.2
		return pose(rx * alive - m.dead * 0.3, look * alive, 0, 0, 0, 0)
	elseif role == "tail" then
		local wag = math.sin(m.time * 2.4) * 0.35 + math.sin(m.cycle) * 0.25 * m.move
		return pose(math.sin(m.time * 1.3) * 0.08 * alive, wag * amp * alive, 0, 0, 0, 0)
	elseif role == "flap" then
		-- Generated wings: quick beats while moving or attacking, slow ones while hovering; folded when dead.
		local ramp = math.clamp(m.time, 0, 1)
		local busy = math.max(m.move, m.raise)
		local speed = 5 + 7 * busy
		local width = 0.32 + 0.3 * busy
		local beat = math.sin(m.time * speed) * width * ramp
		return pose(0, 0, joint.side * (beat * amp * alive - m.dead * 0.7), 0, 0, 0)
	elseif role == "segment" then
		-- A wave runs along the chain (phase = position in it); the chain whips forward on a strike.
		local ramp = math.clamp(m.time, 0, 1)
		local speed = 1.6 + 2.4 * m.move
		local wave = math.sin(m.time * speed - joint.phase * TAU) * 0.28 * amp * ramp
		return pose((-m.strike * 0.25 + m.raise * 0.12) * amp * alive, wave * alive, 0, 0, 0, 0)
	elseif role == "claw" then
		-- Pincers open in the windup and snap shut on the strike.
		return pose((-m.raise * 0.6 + m.strike * 0.25) * alive, 0, 0, 0, 0, 0)
	elseif role == "sting" then
		-- The tail curls back in the windup and stabs forward on the strike.
		local ramp = math.clamp(m.time, 0, 1)
		local sway = math.sin(m.time * 1.5 + joint.phase * TAU) * 0.05 * idle * ramp
		return pose((m.raise * 0.35 - m.strike * 0.85) * amp * alive, sway * alive, 0, 0, 0, 0)
	elseif role == "jaw" then
		-- Opens wide in the windup, bites on the strike, gapes when dead.
		local open = m.raise * 0.5 + m.strike * 0.15 * (1 - m.raise) + m.hit * 0.15
		return pose(-open * amp * alive - m.dead * 0.35, 0, 0, 0, 0, 0)
	elseif role == "orbit" then
		-- Slow turn around Y (keeps turning after death, slower).
		local ramp = math.clamp(m.time, 0, 1)
		local angle = (m.time * (0.8 - m.dead * 0.5) * amp) % TAU
		return pose(0, angle * ramp, 0, 0, 0, 0)
	elseif role == "wing" then
		-- Faster, wider flaps while moving or attacking; folded when dead.
		local speed = 3 + 4 * math.max(m.move, m.raise)
		local width = 0.3 + 0.25 * math.max(m.move, m.raise)
		local flap = 0.15 + math.sin(m.time * speed) * width
		return pose(0, 0, joint.side * flap * amp * alive - joint.side * m.dead * 0.6, 0, 0, 0)
	end
	return pose(0, 0, 0, 0, 0, 0)
end

-- True when a pose leaves the joint at rest (used by the client to skip work and by tests).
function Gait.isRest(p: Pose): boolean
	local e = 1e-6
	return math.abs(p.rx) < e
		and math.abs(p.ry) < e
		and math.abs(p.rz) < e
		and math.abs(p.x) < e
		and math.abs(p.y) < e
		and math.abs(p.z) < e
end

return Gait
