--!strict
-- Dodgeable hazards (owner 2026-10-21, "bosses: flying projectiles you really have to dodge"): projectiles, lobbed
-- rocks, travelling waves and walls, expanding rings and sweeping breaths. Pure: the server (HazardService) steps the
-- hazards and decides every hit, the clients (Vfx/HazardFx) expand the same pattern from the same seed and step the
-- same kinematics to draw them, so one small event describes a whole volley. No Roblox API (Lune).
--
-- A pattern (Data/HazardPatterns) is a list of emitters; `expand` turns it into instances for one cast: each appears
-- `at` s after the cast (its warning starts: an orb in the hand, a lane on the ground, a landing circle) and starts to
-- move (or lands) `delay` s later. Kinds:
--   bolt   a projectile from (x, z) along angle `a` at `speed`, radius `radius`; optional homing (deg/s towards its
--          target), bounces off the arena circle, boomerang return after `range`; hits along its swept segment
--   lob    an arc from the caster to (tx, tz) landing after `delay` (its flight); a circle of `radius` at the landing
--   wave   a front moving from (x, z) along `a` over `length` at `speed`: `width` across, `thick` deep, an optional
--          safe gap (`gapAt` from the axis, `gap` wide); walls of ice and runs of fire
--   ring   a ring growing from (x, z) at `speed` up to `maxRadius`, `thick` deep, optional gaps; `low` = it can be
--          jumped over
--   sweep  a cone of `radius` and `cone` degrees turning from `from` to `to` (radians off `a`) over `seconds`
-- Angles are in the x / z plane: angle a points along (cos a, sin a).

local Rng = require("./Rng")

local Hazards = {}

export type Kind = "bolt" | "lob" | "wave" | "ring" | "sweep"
export type Aim = "target" | "forward" | "around" | "scatter"

-- One emitter of a pattern (Data/HazardPatterns; every field but kind optional, defaults in `expand`).
export type Emitter = {
	kind: Kind,
	aim: Aim?, -- target: one set per target; forward: the cast's direction; around: evenly round 360; scatter: random
	count: number?, -- per set: a fan of bolts, lobs per target, walls round, rings in a row
	spread: number?, -- degrees of a fan of bolts / waves
	shots: number?, -- repeated shots of a set (bolts, lobs)
	every: number?, -- seconds between the shots (and between the rings of a row)
	turn: number?, -- degrees the aim turns with every shot (a spiral)
	arms: number?, -- `around`: directions evenly round 360
	speed: number?,
	radius: number?, -- bolt / lob hit radius, sweep length
	range: number?, -- bolt: distance before it fades (or returns)
	life: number?, -- bolt: seconds of flight at most
	homing: number?, -- bolt: degrees per second it turns towards its target
	bounce: number?, -- bolt: bounces off the arena edge
	returns: boolean?, -- bolt: flies back to its start after `range`
	delay: number?, -- seconds of warning before it moves (lob: the flight)
	scatter: number?, -- lob: random offset round its point; `scatter` aim: the radius round the cast origin
	width: number?, -- wave: across
	thick: number?, -- wave / ring: depth of the front
	length: number?, -- wave: distance travelled
	back: number?, -- wave: starts this far behind the origin (walls from the arena edge)
	gap: number?, -- wave: width of the safe gap (0 = none)
	maxRadius: number?, -- ring
	gaps: number?, -- ring: gaps evenly round
	gapAngle: number?, -- ring: degrees of each gap
	low: boolean?, -- ring: can be jumped over
	cone: number?, -- sweep: degrees wide
	from: number?, -- sweep: degrees off the aim at the start
	to: number?, -- sweep: ... at the end (the side is picked at random)
	seconds: number?, -- sweep: how long it turns
	offset: number?, -- studs in front of the origin the emitter starts (a hand, a mouth)
	share: number?, -- damage x the cast's damage (default 1)
	look: string?, -- the client's look (Vfx/HazardFx), default the pattern's
}

export type Pattern = {
	emitters: { Emitter },
	hits: number?, -- hits a player can take from one cast (default 1)
	hitGap: number?, -- seconds between two hits of one cast on one player (default 0.6)
	look: string, -- Vfx/HazardFx look
	color: string, -- hex
	sound: string?, -- Data/Sfx key at the launch
	impactSound: string?, -- Data/Sfx key where it lands / hits
	big: boolean?, -- a heavy blow: the camera of a player it hits shakes harder
	-- a monster's regular ranged blow (an arrow, a bolt, the Elite II throw): its draw is the warning (no MIN_WARN), the
	-- target's dodge and block count, it hits only its target
	regular: boolean?,
	lead: number?, -- regular shots: share of the target's movement over the flight it is aimed ahead
}

export type Point = { x: number, y: number, z: number }

-- What the cast knows: where it starts, where it faces, whom it aims at, the arena it bounces in, the seed.
export type Cast = {
	seed: number,
	origin: Point,
	yaw: number, -- radians, Hazards angle convention
	targets: { Point },
	arena: { x: number, z: number, r: number }?,
	delay: number?, -- overrides the first shot's warning (a boss attack's windup)
}

export type Inst = {
	index: number,
	emitter: number,
	kind: Kind,
	look: string,
	at: number,
	delay: number,
	x: number,
	y: number,
	z: number,
	a: number,
	speed: number,
	radius: number,
	share: number,
	range: number,
	life: number,
	homing: number,
	target: number?, -- index into Cast.targets
	bounce: number,
	returns: boolean,
	-- lob
	tx: number,
	tz: number,
	ty: number,
	-- wave
	width: number,
	thick: number,
	length: number,
	gapAt: number,
	gap: number,
	-- ring
	maxRadius: number,
	gaps: number,
	gapAngle: number,
	gapStart: number,
	low: boolean,
	-- sweep
	cone: number,
	from: number,
	to: number,
	seconds: number,
}

-- The moving state of one instance (bolts step; the other kinds are functions of time, the state keeps the last time).
export type State = {
	t: number, -- seconds since the cast at the last advance
	prevT: number,
	x: number,
	z: number,
	px: number, -- position at the previous advance (the swept segment)
	pz: number,
	a: number,
	travelled: number,
	bounces: number,
	returning: boolean,
	done: boolean,
}

-- Fairness and hit tolerance (balance-neutral looks of the rules; tests/hazards.spec checks them).
Hazards.MIN_WARN = 0.6 -- every instance shows itself at least this long before it can hit
Hazards.PLAYER_RADIUS = 1.0 -- studs added to a bolt's radius (the body), less than the real ~1.5: lag forgiveness
Hazards.BOLT_HEIGHT = 2.6 -- studs over the ground a bolt flies
Hazards.HEIGHT_TOL = 4.5 -- studs between a bolt's height and the player's root that still hit
Hazards.AREA_HEIGHT = 9 -- studs between an area's ground and the player's root that still hit (slopes)
Hazards.JUMP_CLEAR = 6 -- studs over the ground the root must be to jump a `low` ring (standing = ~3)
Hazards.STEP = 1 / 30 -- seconds: the longest step of a bolt (homing and bounces)
Hazards.ROOT_HEIGHT = 3 -- studs over the ground a standing character's root is

-- Casts at once per kind (audit 2026-10-21): monster shots (`regular` patterns) and boss / world boss patterns each
-- have their own budget, so a hunting ground full of archers never pushes a boss pattern out. A monster shot past its
-- budget falls back to the instant blow (CombatService); the pattern budget only stops a runaway. The client budget is
-- what one screen draws (Vfx/HazardFx).
export type Budget = { regular: number, patterns: number }
Hazards.SERVER_BUDGET = table.freeze({ regular = 300, patterns = 200 }) :: Budget
Hazards.CLIENT_BUDGET = table.freeze({ regular = 30, patterns = 40 }) :: Budget

-- Whether one more cast of a kind fits: `regular` = a monster shot; the live counts of both kinds.
function Hazards.admit(budget: Budget, regular: boolean, regularLive: number, patternLive: number): boolean
	if regular then
		return regularLive < budget.regular
	end
	return patternLive < budget.patterns
end

local TAU = 2 * math.pi

local function num(v: number?, default: number): number
	return if v == nil then default else v
end

local function wrap(a: number): number
	a = a % TAU
	if a > math.pi then
		a -= TAU
	end
	return a
end
Hazards.wrap = wrap

-- The angle from (x0, z0) towards (x1, z1).
function Hazards.angleTo(x0: number, z0: number, x1: number, z1: number): number
	return math.atan2(z1 - z0, x1 - x0)
end

-- Distance from (px, pz) to the segment (ax, az) - (bx, bz).
function Hazards.segmentDistance(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local k = if len2 > 1e-9 then math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) else 0
	local cx, cz = ax + dx * k, az + dz * k
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

local function blank(index: number, emitter: number, e: Emitter, look: string): Inst
	return {
		index = index,
		emitter = emitter,
		kind = e.kind,
		look = e.look or look,
		at = 0,
		delay = num(e.delay, Hazards.MIN_WARN),
		x = 0,
		y = 0,
		z = 0,
		a = 0,
		speed = num(e.speed, 20),
		radius = num(e.radius, 1.5),
		share = num(e.share, 1),
		range = num(e.range, 40),
		life = num(e.life, 6),
		homing = num(e.homing, 0),
		target = nil,
		bounce = num(e.bounce, 0),
		returns = e.returns == true,
		tx = 0,
		tz = 0,
		ty = 0,
		width = num(e.width, 6),
		thick = num(e.thick, 2.5),
		length = num(e.length, 40),
		gapAt = 0,
		gap = num(e.gap, 0),
		maxRadius = num(e.maxRadius, 20),
		gaps = num(e.gaps, 0),
		gapAngle = math.rad(num(e.gapAngle, 30)),
		gapStart = 0,
		low = e.low == true,
		cone = math.rad(num(e.cone, 40)),
		from = 0,
		to = 0,
		seconds = num(e.seconds, 2),
	}
end

-- The aim directions of one emitter: { angle, target index? } per set.
local function aims(e: Emitter, cast: Cast, rng: Rng.Rng): { { a: number, target: number? } }
	local aim = e.aim or "target"
	local o = cast.origin
	local out: { { a: number, target: number? } } = {}
	if aim == "target" and #cast.targets > 0 then
		for i, t in cast.targets do
			local d = math.abs(t.x - o.x) + math.abs(t.z - o.z)
			table.insert(out, { a = if d > 0.05 then Hazards.angleTo(o.x, o.z, t.x, t.z) else cast.yaw, target = i })
		end
	elseif aim == "around" then
		local arms = math.max(1, math.floor(num(e.arms, 8)))
		local base = cast.yaw + rng:float(0, TAU / arms)
		for i = 0, arms - 1 do
			table.insert(out, { a = base + TAU * i / arms, target = nil })
		end
	elseif aim == "scatter" then
		table.insert(out, { a = rng:float(0, TAU), target = nil })
	else
		table.insert(out, { a = cast.yaw, target = if #cast.targets > 0 then 1 else nil })
	end
	return out
end

-- Every instance of `pattern` for `cast`, in a fixed order (server and clients get the same list from the same cast).
function Hazards.expand(pattern: Pattern, cast: Cast): { Inst }
	local rng = Rng.new(cast.seed)
	local list: { Inst } = {}
	local o = cast.origin
	for ei, e in pattern.emitters do
		local kind = e.kind
		local count = math.max(1, math.floor(num(e.count, 1)))
		local shots = math.max(1, math.floor(num(e.shots, 1)))
		local every = num(e.every, 0)
		local spread = math.rad(num(e.spread, 0))
		local turn = math.rad(num(e.turn, 0))
		local offset = num(e.offset, 0)
		local delay = math.max(cast.delay or 0, num(e.delay, Hazards.MIN_WARN))
		for _, aim in aims(e, cast, rng) do
			for s = 1, shots do
				for k = 1, count do
					local inst = blank(#list + 1, ei, e, pattern.look)
					inst.at = (s - 1) * every
					inst.delay = delay
					inst.target = aim.target
					local fan = if count > 1 then spread * ((k - 1) / (count - 1) - 0.5) else 0
					local a = aim.a + turn * (s - 1) + fan
					inst.a = a
					inst.x = o.x + math.cos(a) * offset
					inst.z = o.z + math.sin(a) * offset
					inst.y = o.y
					if kind == "lob" then
						local px, pz, py
						local t = if aim.target then cast.targets[aim.target] else nil
						if e.aim == "scatter" then
							local d = math.sqrt(rng:next()) * num(e.scatter, 20)
							local q = rng:float(0, TAU)
							px, pz, py = o.x + math.cos(q) * d, o.z + math.sin(q) * d, o.y
						elseif t then
							px, pz, py = t.x, t.z, t.y
						else
							local reach = num(e.range, 12)
							px, pz, py = o.x + math.cos(a) * reach, o.z + math.sin(a) * reach, o.y
						end
						if e.aim ~= "scatter" and (e.scatter or 0) > 0 and (k > 1 or s > 1) then
							-- the first rock of a target lands on it, the others round it
							local d = math.sqrt(rng:next()) * num(e.scatter, 0)
							local q = rng:float(0, TAU)
							px += math.cos(q) * d
							pz += math.sin(q) * d
						end
						inst.tx, inst.tz, inst.ty = px, pz, py
						inst.x, inst.z = o.x, o.z
						inst.at = ((s - 1) * count + (k - 1)) * every
					elseif kind == "wave" then
						local back = num(e.back, 0)
						inst.x = o.x - math.cos(a) * back + math.cos(a) * offset
						inst.z = o.z - math.sin(a) * back + math.sin(a) * offset
						if inst.gap > 0 then
							local half = inst.width / 2 - inst.gap / 2 - 1
							inst.gapAt = if half > 0 then rng:float(-half, half) else 0
						end
					elseif kind == "ring" then
						local t = if aim.target and e.aim == "target" then cast.targets[aim.target] else nil
						if t then
							inst.x, inst.z, inst.y = t.x, t.z, t.y
						else
							inst.x, inst.z = o.x, o.z
						end
						inst.at = ((s - 1) * count + (k - 1)) * every
						inst.gapStart = rng:float(0, TAU)
					elseif kind == "sweep" then
						local side = if rng:next() < 0.5 then -1 else 1
						inst.from = math.rad(num(e.from, -45)) * side
						inst.to = math.rad(num(e.to, 45)) * side
					end
					table.insert(list, inst)
				end
			end
		end
	end
	return list
end

-- The first moment an instance can hit (seconds after the cast) and its warning (MIN_WARN rule).
function Hazards.liveFrom(inst: Inst): number
	return inst.at + inst.delay
end

-- The last moment an instance can still be there (seconds after the cast), a safe upper bound.
function Hazards.endsBy(inst: Inst): number
	local start = Hazards.liveFrom(inst)
	if inst.kind == "bolt" then
		return start + inst.life
	elseif inst.kind == "lob" then
		return start + 0.05
	elseif inst.kind == "wave" then
		return start + inst.length / math.max(0.1, inst.speed)
	elseif inst.kind == "ring" then
		return start + inst.maxRadius / math.max(0.1, inst.speed)
	end
	return start + inst.seconds
end

-- The longest instance of a cast (the server drops the cast after it).
function Hazards.castEnds(list: { Inst }): number
	local last = 0
	for _, inst in list do
		last = math.max(last, Hazards.endsBy(inst))
	end
	return last
end

function Hazards.newState(inst: Inst): State
	return {
		t = 0,
		prevT = 0,
		x = inst.x,
		z = inst.z,
		px = inst.x,
		pz = inst.z,
		a = inst.a,
		travelled = 0,
		bounces = inst.bounce,
		returning = false,
		done = false,
	}
end

-- One bolt step of `dt` seconds (aim: the target's position for homing, nil = straight on).
local function boltStep(inst: Inst, st: State, dt: number, aimX: number?, aimZ: number?, arena: any?)
	if st.returning then
		local back = Hazards.angleTo(st.x, st.z, inst.x, inst.z)
		st.a = back
		local d = math.sqrt((inst.x - st.x) ^ 2 + (inst.z - st.z) ^ 2)
		local move = inst.speed * dt
		if d <= move then
			st.x, st.z = inst.x, inst.z
			st.done = true
			return
		end
	elseif inst.homing > 0 and aimX and aimZ then
		local want = Hazards.angleTo(st.x, st.z, aimX, aimZ)
		local diff = wrap(want - st.a)
		local max = math.rad(inst.homing) * dt
		st.a += math.clamp(diff, -max, max)
	end
	local move = inst.speed * dt
	local nx, nz = st.x + math.cos(st.a) * move, st.z + math.sin(st.a) * move
	if arena and not st.returning then
		local dx, dz = nx - arena.x, nz - arena.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d > arena.r then
			local ux, uz = dx / d, dz / d
			local vx, vz = math.cos(st.a), math.sin(st.a)
			local outward = vx * ux + vz * uz
			if st.bounces > 0 and outward > 0 then
				st.bounces -= 1
				vx, vz = vx - 2 * outward * ux, vz - 2 * outward * uz
				st.a = math.atan2(vz, vx)
				nx, nz = arena.x + ux * arena.r, arena.z + uz * arena.r
			elseif inst.bounce > 0 and st.bounces <= 0 then
				st.done = true
			end
		end
	end
	st.x, st.z = nx, nz
	st.travelled += move
	if not st.returning and st.travelled >= inst.range then
		if inst.returns then
			st.returning = true
		else
			st.done = true
		end
	end
end

-- Moves the state to `t` seconds after the cast. `aim` gives the homing target's (x, z) now (nil = none).
function Hazards.advance(inst: Inst, st: State, t: number, aim: ((target: number) -> (number?, number?))?, arena: any?)
	st.prevT = st.t
	st.px, st.pz = st.x, st.z
	if st.done then
		st.t = t
		return
	end
	local start = Hazards.liveFrom(inst)
	if inst.kind == "bolt" then
		local from = math.max(st.t, start)
		if t > from then
			local ax, az = nil, nil
			if aim and inst.target and inst.homing > 0 then
				ax, az = aim(inst.target)
			end
			local left = t - from
			while left > 1e-6 and not st.done do
				local dt = math.min(Hazards.STEP, left)
				boltStep(inst, st, dt, ax, az, arena)
				left -= dt
			end
			if t - start >= inst.life then
				st.done = true
			end
		end
	elseif t >= Hazards.endsBy(inst) then
		st.done = true
	end
	st.t = t
end

-- The front of a wave / the radius of a ring `tau` seconds after it starts moving.
local function frontAt(inst: Inst, tau: number): number
	local limit = if inst.kind == "ring" then inst.maxRadius else inst.length
	return math.clamp(inst.speed * tau, 0, limit)
end
Hazards.frontAt = frontAt

-- The sweep's angle (absolute) `tau` seconds after it starts.
function Hazards.sweepAngle(inst: Inst, tau: number): number
	local k = math.clamp(tau / math.max(0.05, inst.seconds), 0, 1)
	return inst.a + inst.from + (inst.to - inst.from) * k
end

-- Whether a ring angle (absolute) falls into one of the ring's gaps.
function Hazards.inRingGap(inst: Inst, angle: number): boolean
	if inst.gaps <= 0 then
		return false
	end
	for i = 0, inst.gaps - 1 do
		local centre = inst.gapStart + TAU * i / inst.gaps
		if math.abs(wrap(angle - centre)) <= inst.gapAngle / 2 then
			return true
		end
	end
	return false
end

-- Whether the player at (px, py, pz) was hit between the state's previous and current time. `groundY` = the ground
-- under the player (jumping over a `low` ring).
function Hazards.hits(inst: Inst, st: State, px: number, py: number, pz: number, groundY: number?): boolean
	local start = Hazards.liveFrom(inst)
	local t0, t1 = st.prevT, st.t
	if t1 < start then
		return false
	end
	local kind = inst.kind
	if kind == "bolt" then
		if t1 <= start then
			return false
		end
		if math.abs(py - (inst.y + Hazards.BOLT_HEIGHT)) > Hazards.HEIGHT_TOL then
			return false
		end
		local d = Hazards.segmentDistance(px, pz, st.px, st.pz, st.x, st.z)
		return d <= inst.radius + Hazards.PLAYER_RADIUS
	elseif kind == "lob" then
		-- lands once: the step that crosses the landing time
		if not (t0 < start and t1 >= start) then
			return false
		end
		if math.abs(py - (inst.ty + Hazards.ROOT_HEIGHT)) > Hazards.AREA_HEIGHT then
			return false
		end
		return math.sqrt((px - inst.tx) ^ 2 + (pz - inst.tz) ^ 2) <= inst.radius
	end
	if math.abs(py - (inst.y + Hazards.ROOT_HEIGHT)) > Hazards.AREA_HEIGHT then
		return false
	end
	local tau0, tau1 = math.max(0, t0 - start), t1 - start
	local dx, dz = px - inst.x, pz - inst.z
	if kind == "wave" then
		local ux, uz = math.cos(inst.a), math.sin(inst.a)
		local along = dx * ux + dz * uz
		local side = -dx * uz + dz * ux
		if math.abs(side) > inst.width / 2 then
			return false
		end
		if inst.gap > 0 and math.abs(side - inst.gapAt) <= inst.gap / 2 then
			return false
		end
		if tau0 >= inst.length / math.max(0.1, inst.speed) + 0.001 then
			return false
		end
		local f0, f1 = frontAt(inst, tau0), frontAt(inst, tau1)
		return along >= f0 - inst.thick / 2 and along <= f1 + inst.thick / 2
	elseif kind == "ring" then
		if inst.low and groundY and py - groundY > Hazards.JUMP_CLEAR then
			return false
		end
		if tau0 >= inst.maxRadius / math.max(0.1, inst.speed) + 0.001 then
			return false
		end
		local d = math.sqrt(dx * dx + dz * dz)
		local r0, r1 = frontAt(inst, tau0), frontAt(inst, tau1)
		if d < r0 - inst.thick / 2 or d > r1 + inst.thick / 2 then
			return false
		end
		return not Hazards.inRingGap(inst, math.atan2(dz, dx))
	end
	-- sweep
	if tau0 > inst.seconds then
		return false
	end
	local d = math.sqrt(dx * dx + dz * dz)
	if d > inst.radius then
		return false
	end
	if d < 1 then
		return true
	end
	local phi = math.atan2(dz, dx)
	local a0 = Hazards.sweepAngle(inst, tau0)
	local a1 = Hazards.sweepAngle(inst, math.min(tau1, inst.seconds))
	local half = inst.cone / 2
	-- inside the swept wedge: between a0 and a1 (the short way) widened by half the cone
	local mid = a0 + wrap(a1 - a0) / 2
	local span = math.abs(wrap(a1 - a0)) / 2 + half
	return math.abs(wrap(phi - mid)) <= span
end

-- Where an instance is now (x, z; the lob's landing point, the wave's front centre, the ring's / sweep's origin).
function Hazards.positionOf(inst: Inst, st: State): (number, number)
	if inst.kind == "bolt" then
		return st.x, st.z
	elseif inst.kind == "lob" then
		return inst.tx, inst.tz
	elseif inst.kind == "wave" then
		local f = frontAt(inst, math.max(0, st.t - Hazards.liveFrom(inst)))
		return inst.x + math.cos(inst.a) * f, inst.z + math.sin(inst.a) * f
	end
	return inst.x, inst.z
end

-- The studs round the cast origin a player must be within to be worth checking (a safe upper bound).
function Hazards.reach(list: { Inst }, origin: Point): number
	local best = 10
	for _, inst in list do
		local dx, dz = inst.x - origin.x, inst.z - origin.z
		local base = math.sqrt(dx * dx + dz * dz)
		local r = 0
		if inst.kind == "bolt" then
			r = inst.speed * inst.life + inst.radius
		elseif inst.kind == "lob" then
			r = math.sqrt((inst.tx - origin.x) ^ 2 + (inst.tz - origin.z) ^ 2) + inst.radius - base
		elseif inst.kind == "wave" then
			r = inst.length + inst.width / 2 + inst.thick
		elseif inst.kind == "ring" then
			r = inst.maxRadius + inst.thick
		else
			r = inst.radius
		end
		best = math.max(best, base + r + 2)
	end
	return best
end

-- The damage multiplier of one hit of `inst` in a cast of `damage`.
function Hazards.damageOf(inst: Inst, damage: number): number
	return damage * inst.share
end

-- Whether one more hit of a cast may land on a player who took `taken` hits, the last at `lastAt` (cast seconds).
function Hazards.mayHit(pattern: Pattern, taken: number, lastAt: number?, t: number): boolean
	if taken >= math.max(1, pattern.hits or 1) then
		return false
	end
	return lastAt == nil or t - lastAt >= (pattern.hitGap or 0.6)
end

return Hazards
