--!strict
-- NPC animation (owner 2026-10-26: "after the monsters, the NPCs"): the feet of a standing or walking NPC. Each foot is
-- planted on a spot of the ground (root space of the NPC's HumanoidRootPart, studs, front -Z) and stays there until
-- it steps: the body turns or walks away from it, and the foot lifts and swings to where it belongs. Logic/NpcMotion
-- hands the feet to Logic/BipedPose's leg IK, so a planted foot never slides.
-- * Standing: a foot steps when its spot is too far (or too turned) from its home under the body; the other foot then
--   closes with a smaller step. A turn on the spot is a few steps, the foot on the turning side first, never both at
--   once; each step turns the foot at most MAX_TURN.
-- * Walking: a stride clock advanced by distance (not time) swings the feet in turn; a foot lands ahead of its home by
--   half the stance's travel, so the hip passes over it in mid-stance (no sliding at any speed).
-- * The NPC's own root may move (a server-moved NPC): `shift` keeps the planted spots where they are in the world.
-- Pure (Lune specs in tests/npcmotion.spec.luau).

local NpcSteps = {}

export type Foot = {
	x: number, -- planted spot of the ankle on the ground (root space, studs) and its yaw (rad, + = left)
	z: number,
	yaw: number,
	swing: boolean,
	fx: number, -- swing start
	fz: number,
	fyaw: number,
	tx: number, -- swing target
	tz: number,
	tyaw: number,
	t: number, -- seconds into the swing
	dur: number,
	lift: number, -- studs of the swing's peak
	walk: boolean, -- a walking stride (heel and toe roll) or a small step on the spot
	armed: boolean, -- walking: it has stood through its stance since its last swing (it may lift again)
}
export type Offset = { x: number, z: number, yaw: number } -- a foot's home from the body centre (body frame)
export type Feet = {
	R: Foot,
	L: Foot,
	offset: { [string]: Offset },
	L_: number, -- leg length (studs): every distance below is in leg lengths
	phase: number, -- stride clock 0..1 (R swings from 0, L from 0.5)
	last: string?, -- the foot that stepped last
	since: number, -- seconds since the last landing
	walking: boolean,
	heel: number, -- 0..1: how much the stance heels peel off (eases in and out with the walk)
}
-- Where the body is and goes: its centre on the ground (root space, studs), its facing (rad) now and the facing it
-- turns to, its ground velocity (studs/s, root space).
-- `room`: studs left to where it stops (a foot never lands past it).
export type Body = { x: number, z: number, yaw: number, goalYaw: number, vx: number, vz: number, room: number? }

-- Leg lengths a foot may stray from its home before it steps, and the closing step's smaller threshold.
NpcSteps.STEP_AT = 0.13
NpcSteps.CLOSE_AT = 0.05
NpcSteps.TURN_AT = 0.3 -- rad off its home's yaw before it steps
NpcSteps.CLOSE_TURN = 0.12
NpcSteps.MAX_TURN = 0.95 -- rad a foot turns in one step
NpcSteps.MAX_REACH = 0.55 -- leg lengths a standing step reaches from its home
NpcSteps.STEP_TIME = 0.34 -- seconds of a step on the spot
NpcSteps.STEP_LIFT = 0.06 -- leg lengths
NpcSteps.CLOSE_DELAY = 0.45 -- seconds the body must settle before a closing step
NpcSteps.GAP = 0.04 -- seconds between a landing and the next lift
-- Walking: the stride (two steps) in leg lengths at a stroll and its growth with speed, the swing's share of a stride.
NpcSteps.STRIDE = 1.05
NpcSteps.STRIDE_GROW = 0.15 -- leg lengths per (leg length per second) of speed
NpcSteps.SWING = 0.4
NpcSteps.WALK_LIFT = 0.1
NpcSteps.WALK_FROM = 0.35 -- studs per second above which the clock runs
NpcSteps.SETTLE = 0.5 -- seconds a walking swing takes from lift to landing once the walk has stopped
NpcSteps.MIN_CADENCE = 0.8 -- leg lengths per second the stride clock runs at least (a slow walk takes shorter steps)

local function newFoot(x: number, z: number, yaw: number): Foot
	return {
		x = x,
		z = z,
		yaw = yaw,
		swing = false,
		fx = x,
		fz = z,
		fyaw = yaw,
		tx = x,
		tz = z,
		tyaw = yaw,
		t = 0,
		dur = 0,
		lift = 0,
		walk = false,
		armed = true,
	}
end

-- The shortest signed angle from `a` to `b`.
local function angleTo(a: number, b: number): number
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end
NpcSteps.angleTo = angleTo

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Where the foot `side` belongs under a body at (x, z) facing `yaw`: (x, z, yaw).
function NpcSteps.home(feet: Feet, side: string, x: number, z: number, yaw: number): (number, number, number)
	local o = feet.offset[side]
	local c, s = math.cos(yaw), math.sin(yaw)
	-- a turn by yaw about up: (ox, oz) -> (ox c + oz s, -ox s + oz c)
	return x + o.x * c + o.z * s, z - o.x * s + o.z * c, yaw + o.yaw
end

-- Feet planted at their homes under a body at the origin facing 0; `offset` from the rest ankles, `legLength` studs.
function NpcSteps.new(offset: { [string]: Offset }, legLength: number): Feet
	local feet: Feet = {
		R = newFoot(0, 0, 0),
		L = newFoot(0, 0, 0),
		offset = offset,
		L_ = math.max(0.1, legLength),
		phase = 0,
		last = nil,
		since = 10,
		walking = false,
		heel = 0,
	}
	NpcSteps.reset(feet, 0, 0, 0)
	return feet
end

-- Both feet planted at their homes under a body at (x, z) facing `yaw` (a jump in time or a teleport).
function NpcSteps.reset(feet: Feet, x: number, z: number, yaw: number)
	for _, side in { "R", "L" } do
		local hx, hz, hyaw = NpcSteps.home(feet, side, x, z, yaw)
		local f = (feet :: any)[side] :: Foot
		f.x, f.z, f.yaw, f.swing, f.t = hx, hz, hyaw, false, 0
	end
	feet.since = 10
	feet.walking = false
	feet.heel = 0
end

-- The root moved by (dx, dz) studs and turned by `dyaw` (all in its previous frame): the planted spots stay where they
-- are in the world, so in the new root frame they move the other way.
function NpcSteps.shift(feet: Feet, dx: number, dz: number, dyaw: number)
	local c, s = math.cos(-dyaw), math.sin(-dyaw)
	local function move(x: number, z: number): (number, number)
		local ax, az = x - dx, z - dz
		return ax * c + az * s, -ax * s + az * c
	end
	for _, side in { "R", "L" } do
		local f = (feet :: any)[side] :: Foot
		f.x, f.z = move(f.x, f.z)
		f.fx, f.fz = move(f.fx, f.fz)
		f.tx, f.tz = move(f.tx, f.tz)
		f.yaw -= dyaw
		f.fyaw -= dyaw
		f.tyaw -= dyaw
	end
end

-- How far (leg lengths, with the turn weighed in) a foot is from where it belongs.
local function errorOf(feet: Feet, f: Foot, hx: number, hz: number, hyaw: number): (number, number)
	local d = math.sqrt((f.x - hx) ^ 2 + (f.z - hz) ^ 2) / feet.L_
	return d, math.abs(angleTo(f.yaw, hyaw))
end

local function startSwing(
	feet: Feet,
	f: Foot,
	tx: number,
	tz: number,
	tyaw: number,
	dur: number,
	lift: number,
	walk: boolean
)
	f.swing = true
	f.fx, f.fz, f.fyaw = f.x, f.z, f.yaw
	f.tx, f.tz, f.tyaw = tx, tz, f.yaw + angleTo(f.yaw, tyaw)
	f.t = 0
	f.dur = dur
	f.lift = lift * feet.L_
	f.walk = walk
end

-- A standing step's target: the foot's home under the body as it will stand (turned at most MAX_TURN from the foot,
-- at most MAX_REACH from its home now).
local function standTarget(feet: Feet, side: string, f: Foot, body: Body, ahead: number): (number, number, number)
	local turn = angleTo(body.yaw, body.goalYaw)
	local yaw = body.yaw + math.clamp(turn, -0.6, 0.6) * math.min(1, ahead * 4)
	yaw = f.yaw + math.clamp(angleTo(f.yaw, yaw + feet.offset[side].yaw), -NpcSteps.MAX_TURN, NpcSteps.MAX_TURN)
	local bx, bz = body.x + body.vx * ahead, body.z + body.vz * ahead
	local hx, hz = NpcSteps.home(feet, side, bx, bz, yaw - feet.offset[side].yaw)
	local nx, nz = NpcSteps.home(feet, side, body.x, body.z, body.yaw)
	local reach = NpcSteps.MAX_REACH * feet.L_
	local dx, dz = hx - nx, hz - nz
	local d = math.sqrt(dx * dx + dz * dz)
	if d > reach then
		hx, hz = nx + dx * reach / d, nz + dz * reach / d
	end
	return hx, hz, yaw
end

-- Lands a swinging foot on its target.
local function land(feet: Feet, side: string, f: Foot)
	f.swing = false
	f.x, f.z, f.yaw = f.tx, f.tz, f.tyaw
	feet.since = 0
	feet.last = side
end

-- Where a walking foot lands: its home under the body as it will be at touchdown plus half the stance's travel
-- (`ahead` seconds on), turned toward the body's goal a little, at most MAX_TURN from the foot.
local function walkTarget(feet: Feet, side: string, f: Foot, body: Body, ahead: number): (number, number, number)
	local speed = math.sqrt(body.vx * body.vx + body.vz * body.vz)
	local travel = speed * ahead
	local room = body.room
	if room and travel > room then
		ahead *= room / travel
	end
	local hx, hz, hyaw = NpcSteps.home(
		feet,
		side,
		body.x + body.vx * ahead,
		body.z + body.vz * ahead,
		body.yaw + math.clamp(angleTo(body.yaw, body.goalYaw), -0.5, 0.5)
	)
	return hx, hz, f.fyaw + math.clamp(angleTo(f.fyaw, hyaw), -NpcSteps.MAX_TURN, NpcSteps.MAX_TURN)
end

-- Advances the feet by `dt` for `body`; `still` > 0 (seconds the body has stood without turning) allows the closing
-- step; `pace` scales the steps' tempo (a style's stride rate).
-- A step on the spot runs on its own clock (`t` seconds of `dur`); a walking swing runs on the stride clock (`t` its
-- share 0..1 of the swing, `dur` 1), so it keeps time with the body however the speed changes, and its landing spot
-- follows the body until it lands.
function NpcSteps.step(feet: Feet, dt: number, body: Body, still: number, pace: number?)
	local L = feet.L_
	local tempo = pace or 1
	local speed = math.sqrt(body.vx * body.vx + body.vz * body.vz)
	local walk = speed > NpcSteps.WALK_FROM
	-- swings on their own clock (a walking swing goes on that way once the walk stops)
	for _, side in { "R", "L" } do
		local f = (feet :: any)[side] :: Foot
		if f.swing and not (f.walk and walk) then
			f.t += if f.walk then dt / NpcSteps.SETTLE else dt
			if f.t >= f.dur then
				land(feet, side, f)
			end
		end
	end
	feet.since += dt
	feet.heel += ((if walk then 1 else 0) - feet.heel) * (1 - math.exp(-6 * dt))
	if walk then
		-- walking: the stride clock (stride grows a little with speed)
		local stride = (NpcSteps.STRIDE + NpcSteps.STRIDE_GROW * speed / L) * L
		if not feet.walking then
			-- start with the foot that is farther behind: its swing starts now
			feet.walking = true
			local rx, rz = NpcSteps.home(feet, "R", body.x, body.z, body.yaw)
			local lx, lz = NpcSteps.home(feet, "L", body.x, body.z, body.yaw)
			local back = function(f: Foot, hx: number, hz: number): number
				return ((f.x - hx) * body.vx + (f.z - hz) * body.vz) / speed
			end
			local rBack, lBack = back(feet.R, rx, rz), back(feet.L, lx, lz)
			feet.phase = if feet.R.swing or (rBack < lBack and not feet.L.swing) then 0.5 - 1e-3 else 1 - 1e-3
		end
		local before = feet.phase
		local cadence = math.max(speed, NpcSteps.MIN_CADENCE * L)
		feet.phase = (feet.phase + dt * cadence / stride) % 1
		local swingTime = NpcSteps.SWING * stride / cadence
		local stanceTime = (1 - NpcSteps.SWING) * stride / cadence
		for _, side in { "R", "L" } do
			local start = if side == "R" then 0 else 0.5
			local f = (feet :: any)[side] :: Foot
			local other = if side == "R" then feet.L else feet.R
			local into = (feet.phase - start) % 1
			if into >= NpcSteps.SWING and not f.swing then
				f.armed = true
			end
			if f.swing and f.walk then
				-- the swing on the stride clock; it lands at the end of its share (or a stalled clock's)
				local q = into / NpcSteps.SWING
				if q >= 1 or (into > 0.9 and f.t > 0.5) then
					land(feet, side, f)
				else
					f.t = math.max(f.t, q)
					f.tx, f.tz, f.tyaw = walkTarget(feet, side, f, body, (1 - f.t) * swingTime + stanceTime * 0.5)
				end
			elseif not f.swing and not other.swing and f.armed then
				-- the clock is at this foot's lift-off (or a little past it: the other foot was still finishing a step)
				local crossed = (before - start) % 1 > into or into < NpcSteps.SWING * 0.6
				if crossed then
					f.armed = false
					f.swing = true
					f.fx, f.fz, f.fyaw = f.x, f.z, f.yaw
					f.t = 0
					f.dur = 1
					f.lift = NpcSteps.WALK_LIFT * L
					f.walk = true
					f.tx, f.tz, f.tyaw = walkTarget(feet, side, f, body, swingTime + stanceTime * 0.5)
				end
			end
		end
		return
	end
	local swinging = feet.R.swing or feet.L.swing
	feet.walking = false
	if swinging or feet.since < NpcSteps.GAP then
		return
	end
	-- standing: the foot farthest from home steps (the one on the turning side when both are about as far)
	local best: string? = nil
	local bestErr = 0
	local turn = angleTo(body.yaw, body.goalYaw)
	for _, side in { "R", "L" } do
		local f = (feet :: any)[side] :: Foot
		local hx, hz, hyaw = NpcSteps.home(feet, side, body.x, body.z, body.yaw)
		local d, a = errorOf(feet, f, hx, hz, hyaw)
		local need = math.max(d / NpcSteps.STEP_AT, a / NpcSteps.TURN_AT)
		local close = math.max(d / NpcSteps.CLOSE_AT, a / NpcSteps.CLOSE_TURN)
		local score = if need >= 1 then need elseif still > NpcSteps.CLOSE_DELAY and close >= 1 then close * 0.5 else 0
		if score > 0 then
			-- the turning side first (a left turn opens with the left foot); never the same foot twice running unless
			-- the other is home
			if (turn > 0.15 and side == "L") or (turn < -0.15 and side == "R") then
				score *= 1.25
			end
			if feet.last == side then
				score *= 0.8
			end
			if score > bestErr then
				best, bestErr = side, score
			end
		end
	end
	if best then
		local f = (feet :: any)[best] :: Foot
		local dur = NpcSteps.STEP_TIME / tempo
		local tx, tz, tyaw = standTarget(feet, best, f, body, dur)
		startSwing(feet, f, tx, tz, tyaw, dur, NpcSteps.STEP_LIFT, false)
	end
end

-- The ankle's place for the IK this frame: x, lift (studs over its planted height), z, yaw, foot pitch (+ toes up) and
-- toe bend (+ toes up).
function NpcSteps.pose(feet: Feet, side: string): (number, number, number, number, number, number)
	local f = (feet :: any)[side] :: Foot
	if not f.swing then
		if feet.heel > 0.01 then
			-- late in the stance of a stride the heel peels off the ground (the ankle rises over the toes)
			local start = if side == "R" then 0 else 0.5
			local s = (((feet.phase - start) % 1) - NpcSteps.SWING) / (1 - NpcSteps.SWING)
			local k = smooth((s - 0.7) / 0.3) * feet.heel
			return f.x, 0.07 * feet.L_ * k, f.z, f.yaw, -0.35 * k, 0.3 * k
		end
		return f.x, 0, f.z, f.yaw, 0, 0
	end
	local q = math.clamp(f.t / math.max(1e-3, f.dur), 0, 1)
	local e = smooth(q)
	local x = f.fx + (f.tx - f.fx) * e
	local z = f.fz + (f.tz - f.fz) * e
	local yaw = f.fyaw + (f.tyaw - f.fyaw) * e
	-- the peak early in the swing (the foot clears the ground, then reaches)
	local h = math.sin(math.pi * math.min(1, q * 1.15)) * f.lift
	local pitch, toe = 0, 0
	if f.walk then
		-- the toe-off goes on from the stance's heel lift (heel up, toes bent), then the toes rise before the landing
		local off = math.max(0, 1 - q / 0.3) * feet.heel
		h = math.max(h, 0.07 * feet.L_ * off)
		pitch = -0.35 * off + 0.22 * math.sin(math.clamp((q - 0.45) / 0.55, 0, 1) * math.pi)
		toe = 0.3 * off
	else
		pitch = 0.08 * math.sin(math.pi * q)
	end
	return x, h, z, yaw, pitch, toe
end

-- -1 .. 1: where the weight is (+ over the right foot) while one foot swings, 0 with both down.
function NpcSteps.support(feet: Feet): number
	local function lifted(f: Foot): number
		if not f.swing then
			return 0
		end
		local q = math.clamp(f.t / math.max(1e-3, f.dur), 0, 1)
		-- the weight moves over before the lift and back after the landing
		return math.sin(math.pi * math.min(1, q * 0.85 + 0.15))
	end
	return lifted(feet.L) - lifted(feet.R)
end

return NpcSteps
