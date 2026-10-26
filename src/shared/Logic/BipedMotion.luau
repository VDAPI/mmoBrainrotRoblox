--!strict
-- Template animation (owner 2026-10-25): the motion of an imported biped monster in layers, from the bottom:
-- 1. locomotion mocap (Data/BipedClips): idle variants crossfading every few seconds; walk and run phase-synced and
--    played at the monster's ground speed (stride matched: the planted foot does not slide), stepping in place while
--    it turns on the spot;
-- 2. the combat stance (Data/BipedStyles guard) laid over the upper body while it fights (over the legs too when it
--    stands), breathing and swaying;
-- 3. keyed actions (attacks, abilities, the aggro shout, spawn, death) on a timeline whose anticipation stretches to
--    the server's windup and whose strike ends exactly on the server's hit; the head and the free arm trail the body;
-- 4. additive reactions: the flinch of a hit by its side, the lean into turns, the head looking at the target.
-- The bosses (Data/BossStyles, 2026-10-26) add a layer of their own (a style's `boss`): the walk at full weight however
-- slow a giant's stride, the pelvis dropping after each footfall onto planted feet, the stance never quite let go out
-- of the fight, the enraged and shielded stances; their actions hold a channel ("H" keys), turn the body with a sweeping
-- cast, fly a leap's arc, and key a tremble, a whole-body spin and a hop (`tremble`, `spin`, `air`).
-- Pure (numbers in, Transforms out through Logic/BipedPose); client/Anim/BipedRig writes the bones and AnimLab
-- evaluates it at a fixed time.

local BipedClip = require("./BipedClip")
local BipedClips = require("../Data/BipedClips")
local BipedPose = require("./BipedPose")
local BipedStyles = require("../Data/BipedStyles")
local NpcPose = require("./NpcPose")

local BipedMotion = {}

type Vec = { number }
type Mat = { number }
type World = BipedPose.World
type Controls = BipedPose.Controls

-- Seconds an idle variant takes to cross into the next, the weights' follow rates (1/s), the action's fades.
local IDLE_FADE = 0.8
local MOVE_RATE = 9
local RUN_RATE = 6
local COMBAT_RATE = 4
local LOOK_RATE = 5
local ACTION_IN = 0.1
local ACTION_OUT = 0.18
-- seconds an interrupted action (a stagger breaking a cast, a death in mid-blow) fades out from its last pose
local ACTION_CUT = 0.2
-- Ground speed (studs/s) under which the monster stands, and the turn rate (rad/s) at which it steps on the spot.
local STAND_SPEED = 0.6
local TURN_STEP = 1.2
-- The flinch: rise and fall (s); the lean into turns (rad per stud/s x rad/s) and its limit.
local FLINCH_RISE = 0.05
local FLINCH_FALL = 0.38
local LEAN = 0.012
local LEAN_MAX = 0.22
-- How far the head (and the chest) turn toward a target, and the limit of the turn.
local LOOK_HEAD = 0.6
local LOOK_CHEST = 0.25
local LOOK_MAX = 1.1
-- How fast a boss's enraged and shielded stances ease in and out (1/s).
local STANCE_RATE = 1.5

local FREE_ARM: { [string]: boolean } = {}
for _, key in { "aLp", "aLo", "aLy", "aLt", "eL", "wLp", "wLy", "wLr", "cLu", "cLf" } do
	FREE_ARM[key] = true
end
local HEAD: { [string]: boolean } = { hyaw = true, hpitch = true, hroll = true }

-- Bone masks: the upper body, the legs (with the Hips).
local UPPER_MASK: { [string]: number } = {}
local LEG_MASK: { [string]: number } = {}
for _, key in BipedPose.KEYS do
	if string.find(key, "Leg") or string.find(key, "Foot") or string.find(key, "Toe") or key == "Hips" then
		LEG_MASK[key] = 1
	else
		UPPER_MASK[key] = 1
	end
end

export type LoadedClip = { clip: BipedClip.Clip, fit: { [string]: NpcPose.Mat }, speed: number? }
export type ActionRun = {
	name: string,
	start: number, -- the motion clock when it started
	hit: number, -- seconds from the start to the server's hit
	reach: Vec?, -- root-space offset (studs) to the target (travelling actions)
	-- a boss's channel (an action with `channel`): seconds the blow is held after the hit and the body's turn over it
	-- ({ from, to } rad, + = left: Logic/HazardGesture.turnOf); a leap (`leap`): its arc ({ height in studs, flight s })
	hold: number?,
	turn: { number }?,
	arc: { number }?,
}
export type Input = {
	now: number,
	dt: number,
	speed: number, -- ground speed (studs/s)
	yawRate: number, -- rad/s, + = turning left
	combat: boolean,
	action: ActionRun?,
	hitAt: number?,
	hitSide: string?, -- "front" | "back" | "left" | "right"
	look: Vec?, -- root-space direction to the target (nil = none)
	snap: boolean?, -- AnimLab: weights jump to their targets
	flying: boolean?, -- a winged biped in the air (the attribute Flying): wingbeats, the legs tucked
	gait: string?, -- the server's gait (attribute Gait: "walk" | "trot" | "run"); a style's `hop` bounds on "run"
	enraged: boolean?, -- a boss enraged or in its last phase (its `boss.rage` stance)
	shielded: boolean?, -- a boss shielded by its helpers (attribute Shielded: its `boss.shield` stance)
}
export type Instance = {
	skel: BipedPose.Skeleton,
	style: BipedStyles.Style,
	seed: number,
	rate: number,
	clips: { [string]: LoadedClip },
	idle: { name: string, from: string?, at: number, next: number },
	phase: number,
	move: number,
	run: number,
	hop: number, -- weight of a style's bounding gait (Data/BipedStyles procedural `hop`)
	combat: number,
	look: number,
	lookYaw: number,
	lookPitch: number,
	lastAction: ActionRun?, -- the action of the last frame and its pose (world, shift and weights), kept for a cut
	lastPose: { world: BipedPose.World?, shift: Vec, upper: number, legs: number },
	cut: { world: BipedPose.World, shift: Vec, upper: number, legs: number, at: number }?,
	grip: { number }?, -- the model's own blade direction (Data/MonsterAssets `grip`), else the style's
	rage: number, -- weights of a boss's enraged and shielded stances
	shield: number,
}

local function hash01(n: number, seed: number): number
	return NpcPose.hash01(n, seed)
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- An animated biped of `style` on skeleton `skel`; `seed` makes each instance its own.
function BipedMotion.new(skel: BipedPose.Skeleton, styleId: string, seed: number, grip: { number }?): Instance?
	local style = BipedStyles.get(styleId)
	if not style then
		return nil
	end
	local clips: { [string]: LoadedClip } = {}
	local function load(name: string)
		if clips[name] then
			return
		end
		local source = BipedClips.get(name)
		if source then
			local clip = BipedClip.decode(source)
			clips[name] = { clip = clip, fit = BipedClip.fit(source, skel.dirs), speed = source.speed }
		end
	end
	local first = ""
	local list = style.clips
	if list then
		for _, name in list.idle do
			load(name)
		end
		load(list.walk)
		load(list.run)
		first = list.idle[1 + math.floor(hash01(1, seed) * #list.idle) % #list.idle]
	end
	return {
		skel = skel,
		style = style,
		seed = seed,
		rate = 1 + (hash01(2, seed) * 2 - 1) * style.rate,
		clips = clips,
		idle = { name = first, from = nil, at = -math.huge, next = 0 },
		phase = hash01(3, seed),
		grip = grip or style.grip,
		move = 0,
		run = 0,
		hop = 0,
		combat = 0,
		look = 0,
		lookYaw = 0,
		lookPitch = 0,
		lastAction = nil,
		lastPose = { world = nil, shift = { 0, 0, 0 }, upper = 0, legs = 0 },
		cut = nil,
		rage = 0,
		shield = 0,
	}
end

---------------------------------------------------------------- easing and keys

local function ease(kind: string?, x: number): number
	local t = math.clamp(x, 0, 1)
	if kind == "in" then
		return t * t * t
	elseif kind == "out" then
		local u = 1 - t
		return 1 - u * u * u
	elseif kind == "lin" then
		return t
	end
	return t * t * t * (t * (t * 6 - 15) + 10) -- smootherstep
end

-- Seconds a channel holds its blow (0 for any other action).
local function held(action: BipedStyles.Action, hold: number?): number
	return if action.channel then math.max(0, hold or 0) else 0
end

-- The action's segment times: anticipation stretched to the windup, strike ending on the hit, a channel's hold.
local function segments(action: BipedStyles.Action, hit: number, hold: number?): { [string]: { number } }
	local s = math.min(action.strike, hit * 0.7)
	local a = math.max(0, hit - s)
	local h = held(action, hold)
	return {
		A = { 0, a },
		S = { a, s },
		H = { hit, h },
		F = { hit + h, action.follow },
		R = { hit + h + action.follow, action.recover },
	}
end

-- Seconds an action lasts (to the end of its recovery; `hold`: a channel's).
function BipedMotion.length(action: BipedStyles.Action, hit: number, hold: number?): number
	return hit + held(action, hold) + action.follow + action.recover
end

-- The controls of `action` at `t` seconds (hit at `hit`), starting from `startPose`.
local function keyed(action: BipedStyles.Action, hit: number, t: number, startPose: Controls, hold: number?): Controls
	local seg = segments(action, hit, hold)
	local prevT, prevPose = 0, startPose
	-- (a channel held for no time goes from its strike straight on to its follow-through)
	local noHold = seg.H[2] <= 0
	for _, key in action.keys do
		if noHold and key.seg == "H" then
			continue
		end
		local span = seg[key.seg]
		local kt = span[1] + key.u * span[2]
		if t <= kt then
			if kt - prevT < 1e-4 then
				return key.pose
			end
			local k = ease(key.ease, (t - prevT) / (kt - prevT))
			return BipedPose.lerp(prevPose, key.pose, k)
		end
		prevT, prevPose = kt, key.pose
	end
	return prevPose
end

-- The action's controls with the head and the free arm trailing (their own, slightly earlier, time).
local function sampleAction(action: BipedStyles.Action, run: ActionRun, t: number, startPose: Controls): Controls
	local hold = run.hold
	local body = keyed(action, run.hit, t, startPose, hold)
	local lag = action.lag
	if not lag then
		return body
	end
	local head = if (lag.head or 0) > 0 then keyed(action, run.hit, math.max(0, t - lag.head), startPose, hold) else nil
	local free = if (lag.free or 0) > 0 then keyed(action, run.hit, math.max(0, t - lag.free), startPose, hold) else nil
	local out = table.clone(body)
	if head then
		for key in HEAD do
			out[key] = head[key]
		end
	end
	if free then
		for key in FREE_ARM do
			out[key] = free[key]
		end
	end
	return out
end

-- The controls of action `name` of `style` at `t` (hit at `hit`, a channel held `hold` s), the head and the free arm
-- trailing: AnimLab's pose sheets and the tests read the keyed timeline without the layers.
function BipedMotion.controlsAt(
	style: BipedStyles.Style,
	name: string,
	hit: number,
	t: number,
	hold: number?
): Controls?
	local action = style.actions[name]
	if not action then
		return nil
	end
	local first = action.keys[1]
	local startPose = if first and first.u == 0 and first.seg == "A" then first.pose else style.guard
	return sampleAction(action, { name = name, start = 0, hit = hit, hold = hold }, t, startPose)
end

-- The times of an action's segments: the end of the anticipation (the peak), the hit, the end.
function BipedMotion.times(action: BipedStyles.Action, hit: number, hold: number?): (number, number, number)
	local seg = segments(action, hit, hold)
	return seg.A[2], hit, BipedMotion.length(action, hit, hold)
end

---------------------------------------------------------------- layers

local function clipPose(inst: Instance, name: string, time: number): (World?, Vec?)
	local loaded = inst.clips[name]
	if not loaded then
		return nil, nil
	end
	local world, off = BipedClip.sample(loaded.clip, time, true, loaded.fit)
	local L = inst.skel.legLength
	return world, { off[1] * L, off[2] * L, off[3] * L }
end

local function lerpVec(a: Vec, b: Vec, k: number): Vec
	return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }
end

-- Ground speed (studs/s) of a locomotion clip at rate 1, and its cycle length (s).
local function gait(inst: Instance, name: string): (number, number)
	local loaded = inst.clips[name]
	if not loaded then
		return 1, 1
	end
	return (loaded.speed or 1) * inst.skel.legLength, loaded.clip.length
end

local function idleLayer(inst: Instance, now: number): (World, Vec)
	local idle = inst.idle
	local style = inst.style
	if not style.clips then
		return {}, { 0, 0, 0 }
	end
	if now >= idle.next then
		local list = (style.clips :: any).idle
		local n = math.floor(now)
		local pick = list[1 + math.floor(hash01(n, inst.seed) * #list) % #list]
		if pick ~= idle.name then
			idle.from = idle.name
			idle.name = pick
			idle.at = now
		end
		local span = style.idleEvery
		idle.next = now + span[1] + hash01(n + 17, inst.seed) * (span[2] - span[1])
	end
	local t = (now + inst.seed * 7.3) * inst.rate
	local world, shift = clipPose(inst, idle.name, t)
	local k = (now - idle.at) / IDLE_FADE
	if idle.from and k < 1 then
		local w0, s0 = clipPose(inst, idle.from, t)
		if world and w0 and shift and s0 then
			local e = ease("inout", k)
			world = BipedPose.blend(w0, world, e)
			shift = lerpVec(s0, shift, e)
		end
	end
	return world or {}, shift or { 0, 0, 0 }
end

local SIDES = { "L", "R" }

-- One bound of the hopping gait laid over `out` with weight `wgt` (phase `p`, stance until `duty`): the body crouches
-- in the stance and flies an arc, leaning in, the head countering; the wings beat once per bound, from their top at
-- mid-stance down through the push-off (`hop.up` / `hop.down`: full wing poses).
local function hopControls(out: Controls, hop: any, p: number, duty: number, wgt: number)
	local y: number
	if p < duty then
		y = -hop.crouch * math.sin(math.pi * p / duty)
	else
		y = hop.height * math.sin(math.pi * (p - duty) / (1 - duty))
	end
	out.py = (out.py or 0) + y * wgt
	out.ppitch = (out.ppitch or 0) + hop.lean * wgt
	out.spitch = (out.spitch or 0) - hop.lean * 0.3 * wgt
	out.hpitch = (out.hpitch or 0) - hop.lean * 0.6 * wgt
	local lift = 0.5 + 0.5 * math.cos(2 * math.pi * (p - duty * 0.5))
	for key, down in hop.down do
		local beat = down + (hop.up[key] - down) * lift
		local base = out[key] or 0
		out[key] = base + (beat - base) * wgt
	end
end

-- A procedural walk and run for a biped without mocap that fits it (dragons on their hind legs): the feet planted in
-- stance and swung in an arc by leg IK, the pelvis bobbing, swaying and turning with the stride, the chest and head
-- countering it, the folded wings swinging a little; one phase advanced by distance.
local function proceduralControls(inst: Instance, input: Input): Controls
	local style = inst.style
	local gaitDef = style.procedural :: any
	local dt = input.dt
	local speed = input.speed
	local L = inst.skel.legLength
	local ratio = speed / L
	local turning = speed < STAND_SPEED and math.abs(input.yawRate) > TURN_STEP * 0.6
	local moving = speed >= STAND_SPEED
	local moveTarget = if moving then math.clamp(ratio / 0.5, 0, 1) elseif turning then 0.6 else 0
	local runTarget = math.clamp((ratio - gaitDef.runAt + 0.4) / 0.8, 0, 1)
	-- the rate the gaits blend at (a style whose gaits differ a lot in cadence blends faster: `blend` per second)
	local blend = gaitDef.blend or RUN_RATE * 0.7
	if input.snap then
		inst.move, inst.run = moveTarget, runTarget
	else
		inst.move = approach(inst.move, moveTarget, MOVE_RATE * 0.7, dt)
		inst.run = approach(inst.run, runTarget, blend, dt)
	end
	local w, r = gaitDef.walk, gaitDef.run
	local function mix(key: string): number
		return w[key] + (r[key] - w[key]) * inst.run
	end
	-- a bounding gait (the wyvern's wing-assisted hops): on the server's "run", else above `hop.at` leg lengths a second
	local hopDef = gaitDef.hop
	local h = 0
	if hopDef then
		local hopTarget = if not moving
			then 0
			elseif input.gait then (if input.gait == "run" then 1 else 0)
			else math.clamp((ratio - hopDef.at) + 0.5, 0, 1)
		inst.hop = if input.snap then hopTarget else approach(inst.hop, hopTarget, blend, dt)
		h = inst.hop
	end
	local kGait = mix("k")
	local k = kGait
	if h > 0 then
		k += (hopDef.k - k) * h
	end
	local ground = if moving then speed elseif turning then math.abs(input.yawRate) * L * 0.35 else 0
	inst.phase = (inst.phase + dt * ground / math.max(0.2, k * L)) % 1
	local out: Controls = table.clone(gaitDef.rest)
	local t = input.now + inst.seed * 3.7
	local breath = math.sin(t * 2 * math.pi / 3.6)
	out.spitch = (out.spitch or 0) + 0.03 * breath
	out.aRo = (out.aRo or 0) + 0.04 * breath
	out.aLo = (out.aLo or 0) + 0.04 * breath
	local m = inst.move
	if m > 0.005 and not gaitDef.float then
		local duty, lift = mix("duty"), mix("lift")
		local stride = k * 0.5 -- each foot covers half the cycle's distance
		if h > 0 then
			-- bounding: both feet together, planted for the whole stance; the stride blends between the two gaits' own
			-- (never longer than either while the cycle stretches)
			duty += (hopDef.duty - duty) * h
			lift += (hopDef.lift - lift) * h
			stride = kGait * 0.5 + (hopDef.duty * hopDef.k - kGait * 0.5) * h
		end
		-- a style's feet may step about a point ahead of their rest (`footZ` leg lengths: a digitigrade leg whose ankle
		-- rests behind the hip reaches back less) and roll the toes off into the swing (`toeRoll`)
		local footZ = gaitDef.footZ or 0
		for _, side in SIDES do
			local offset = if side == "R" then 0.5 * (1 - h) else 0
			local p = (inst.phase + offset) % 1
			local z: number, y: number, toe: number
			if p < duty then
				local q = p / duty
				z = -stride / 2 + stride * q
				y = 0
				toe = -0.25 * math.max(0, q - 0.7) / 0.3
			else
				local q = (p - duty) / (1 - duty)
				local e = q * q * (3 - 2 * q)
				z = stride / 2 - stride * e
				y = lift * math.sin(math.pi * q)
				toe = 0.35 * math.sin(math.pi * q)
				if gaitDef.toeRoll then
					toe -= 0.25 * (1 - q) ^ 3
				end
			end
			out["f" .. side .. "z"] = (out["f" .. side .. "z"] or 0) + (z + footZ) * m
			out["f" .. side .. "y"] = (out["f" .. side .. "y"] or 0) + y * m
			out["t" .. side] = (out["t" .. side] or 0) + toe * m
		end
		local a = 2 * math.pi * inst.phase
		local g = m * (1 - h)
		out.py = (out.py or 0) - mix("bob") * math.cos(2 * a) * g
		out.proll = (out.proll or 0) + mix("sway") * math.sin(a) * g
		out.px = (out.px or 0) + mix("sway") * 0.4 * math.sin(a) * g
		out.pyaw = (out.pyaw or 0) + mix("yaw") * math.sin(a) * g
		out.syaw = (out.syaw or 0) - mix("yaw") * 0.8 * math.sin(a) * g
		out.hyaw = (out.hyaw or 0) - mix("yaw") * 0.4 * math.sin(a) * g
		out.ppitch = (out.ppitch or 0) + mix("lean") * g
		out.hpitch = (out.hpitch or 0) - mix("lean") * 0.7 * g + 0.04 * math.cos(2 * a) * g
		out.aRp = (out.aRp or 0) + 0.12 * math.sin(a) * g
		out.aLp = (out.aLp or 0) - 0.12 * math.sin(a) * g
		if h > 0 then
			hopControls(out, hopDef, inst.phase, duty, m * h)
		end
	end
	if input.flying then
		-- in the air: slow heavy wingbeats, the legs tucked under, the body riding each beat
		local f = gaitDef.flap
		local b = 2 * math.pi * f.rate * t
		local beat = math.sin(b)
		for _, side in { "R", "L" } do
			out["a" .. side .. "o"] = f.out + f.amp * beat
			out["a" .. side .. "p"] = f.pitch + 0.35 * math.sin(b + 1.2)
			out["a" .. side .. "y"] = -0.25
			out["e" .. side] = 0.3 + 0.5 * math.max(0, -math.sin(b - 0.6))
			out["f" .. side .. "z"] = 0.6
			out["f" .. side .. "y"] = 0.75
			out["t" .. side] = 1
		end
		out.py = (out.py or 0) + 0.06 * math.sin(b + math.pi)
		out.ppitch = f.lean or 0.18
		out.spitch = (out.spitch or 0) - 0.05 * beat
		out.hpitch = (out.hpitch or 0) - (f.lean or 0.18) * 0.6
	end
	return out
end

local FEET: { [string]: string } = { R = "RightFoot", L = "LeftFoot" }
local TOES: { [string]: string } = { R = "RightToeBase", L = "LeftToeBase" }

-- A boss's weight in its walk (its `boss`): the pelvis drops after each footfall of the walk's cycle and rolls over the
-- standing leg, the feet step a little wider than the clip's, and the legs are solved again onto those planted feet
-- (the knees take the drop). In place on the walk's pose.
local function heavyStep(inst: Instance, world: World, shift: Vec, walk: string)
	local boss = inst.style.boss :: BipedStyles.BossLayer
	local skel = inst.skel
	local L = skel.legLength
	local m = inst.move
	local loaded = inst.clips[walk]
	local contact = if loaded then loaded.clip.source.contact or 0 else 0
	-- two footfalls a cycle: the drop over the first 40 % of each half
	local u = ((inst.phase - contact) % 0.5) / 0.5
	local drop = if u < 0.4 then math.sin(math.pi * u / 0.4) else 0
	local at = BipedPose.positions(skel, world, shift)
	local targets: { [string]: Vec? } = {}
	local keep: { [string]: Mat } = {}
	for side, key in FEET do
		local p = at[key]
		if p then
			local out = if side == "R" then 1 else -1
			targets[side] = { p[1] + out * boss.wide * L * m, p[2], p[3] }
		end
		local foot, toe = world[key], world[TOES[side]]
		if foot then
			keep[key] = foot
		end
		if toe then
			keep[TOES[side]] = toe
		end
	end
	-- the standing leg is the lower foot: the body sways over it
	local right, left = at.RightFoot, at.LeftFoot
	local stand = if right and left then math.clamp((left[2] - right[2]) / (0.08 * L), -1, 1) else 0
	local roll = -boss.roll * stand * m
	if math.abs(roll) > 1e-4 then
		BipedPose.turnSubtree(world, "Hips", BipedPose.rz(roll))
	end
	for key, turn in keep do
		world[key] = turn
	end
	shift[2] -= boss.dip * L * drop * m
	BipedPose.fixLegs(skel, world, shift, targets)
end

local function locomotion(inst: Instance, input: Input): (World, Vec)
	local style = inst.style
	if style.procedural then
		return BipedPose.world(inst.skel, proceduralControls(inst, input), inst.grip)
	end
	local clips = style.clips :: any
	local dt = input.dt
	local speed = input.speed
	local walkSpeed, walkLen = gait(inst, clips.walk)
	local runSpeed, runLen = gait(inst, clips.run)
	local turning = speed < STAND_SPEED and math.abs(input.yawRate) > TURN_STEP
	local moving = speed >= STAND_SPEED
	-- a boss walks at full weight however slow its stride (a giant's cadence is slow; a half blend would slide)
	local walkWeight = if style.boss then 1 else math.clamp(speed / (walkSpeed * 0.5), 0, 1)
	local moveTarget = if moving then walkWeight elseif turning then 0.65 else 0
	local runTarget = math.clamp((speed - walkSpeed * 1.1) / math.max(0.5, runSpeed * 0.75 - walkSpeed * 1.1), 0, 1)
	if input.snap then
		inst.move, inst.run = moveTarget, runTarget
	else
		inst.move = approach(inst.move, moveTarget, MOVE_RATE, dt)
		inst.run = approach(inst.run, runTarget, RUN_RATE, dt)
	end
	-- one phase for both cycles: the cycle covers this many studs at the blend
	local stride = walkSpeed * walkLen + (runSpeed * runLen - walkSpeed * walkLen) * inst.run
	local ground = if moving then speed elseif turning then math.abs(input.yawRate) * inst.skel.legLength * 0.5 else 0
	inst.phase = (inst.phase + dt * ground / math.max(0.1, stride)) % 1
	local idleWorld, idleShift = idleLayer(inst, input.now)
	if style.float then
		-- a floating body drifts: no steps, a slow bob and a lean into the way it goes
		local t = input.now + inst.seed * 2.3
		local bob = 0.04 * math.sin(t * 2 * math.pi / 2.6) * inst.skel.legLength
		return idleWorld, { idleShift[1], idleShift[2] + bob, idleShift[3] }
	end
	if inst.move < 0.01 then
		return idleWorld, idleShift
	end
	local walkW, walkS = clipPose(inst, clips.walk, inst.phase * walkLen)
	local world, shift = walkW, walkS
	if inst.run > 0.01 then
		local wl, rl = inst.clips[clips.walk], inst.clips[clips.run]
		local offset = if wl and rl then (rl.clip.source.contact or 0) - (wl.clip.source.contact or 0) else 0
		local runW, runS = clipPose(inst, clips.run, ((inst.phase + offset) % 1) * runLen)
		if world and runW and shift and runS then
			world = BipedPose.blend(world, runW, inst.run)
			shift = lerpVec(shift, runS, inst.run)
		end
	end
	if not world or not shift then
		return idleWorld, idleShift
	end
	local blended, moved = BipedPose.blend(idleWorld, world, inst.move), lerpVec(idleShift, shift, inst.move)
	if style.boss then
		heavyStep(inst, blended, moved, clips.walk)
	end
	return blended, moved
end

-- `out` eased toward `pose` by `k` (a boss's stance laid over its guard).
local function toward(out: Controls, pose: Controls, k: number)
	for key, v in pose do
		local base = out[key] or 0
		out[key] = base + (v - base) * k
	end
end

-- The guard with breathing, a slow sway of the weight and a small bob (per instance); a boss breathes slower and
-- deeper and takes its enraged and shielded stances, shaking with rage.
local function guardControls(inst: Instance, now: number): Controls
	local out = table.clone(inst.style.guard)
	local t = now + inst.seed * 3.1
	local boss = inst.style.boss
	if boss then
		local shield = boss.shield
		if shield and inst.shield > 0.005 then
			toward(out, shield, inst.shield)
		end
		if inst.rage > 0.005 then
			toward(out, boss.rage, inst.rage)
			local shake = 0.012 * inst.rage
			out.sroll = (out.sroll or 0) + shake * math.sin(t * 2 * math.pi * 7.3)
			out.hpitch = (out.hpitch or 0) + shake * math.sin(t * 2 * math.pi * 8.9 + 1.3)
		end
		local breath = math.sin(t * 2 * math.pi / boss.breath[1])
		local depth = boss.breath[2]
		out.spitch = (out.spitch or 0) + depth * breath
		out.cRu = (out.cRu or 0) + depth * breath
		out.cLu = (out.cLu or 0) + depth * breath
		out.py = (out.py or 0) + 0.2 * depth * breath
		out.hpitch = (out.hpitch or 0) - 0.5 * depth * breath
	else
		local breath = math.sin(t * 2 * math.pi / 3.2)
		out.spitch = (out.spitch or 0) + 0.025 * breath
		out.cRu = (out.cRu or 0) + 0.02 * breath
		out.cLu = (out.cLu or 0) + 0.02 * breath
		out.py = (out.py or 0) + 0.006 * breath
	end
	local sway = math.sin(t * 2 * math.pi / 5.7)
	out.proll = (out.proll or 0) + 0.03 * sway
	out.px = (out.px or 0) + 0.012 * sway
	out.syaw = (out.syaw or 0) + 0.04 * sway
	out.aRp = (out.aRp or 0) + 0.03 * math.sin(t * 2 * math.pi / 2.6)
	return out
end

local function maskWith(upper: number, legs: number): { [string]: number }
	local m: { [string]: number } = {}
	for key in UPPER_MASK do
		m[key] = upper
	end
	for key in LEG_MASK do
		m[key] = legs
	end
	return m
end

---------------------------------------------------------------- a boss's actions

-- Turns the body in the action's controls `c` (in place) by `twist` rad over the planted feet (the pelvis, the chest
-- and the head share it).
local function twistBody(c: Controls, twist: number)
	if math.abs(twist) > 1e-5 then
		c.pyaw = (c.pyaw or 0) + twist * 0.3
		c.syaw = (c.syaw or 0) + twist * 0.45
		c.hyaw = (c.hyaw or 0) + twist * 0.25
	end
end

-- A channel's body turn `t` s into its run (Logic/Gait.turnOf's shape): toward `from` over the anticipation, on to
-- `to` over the hold (evenly, with the sweeping cone), back over the follow-through and the recovery.
local function channelTurn(action: BipedStyles.Action, run: ActionRun, t: number): number
	local turn = run.turn
	if not turn or t <= 0 then
		return 0
	end
	local from, to = turn[1], turn[2]
	local hit = math.max(run.hit, 0.05)
	local h = held(action, run.hold)
	if t <= hit then
		return from * ease("inout", t / hit)
	elseif t <= hit + h then
		return from + (to - from) * (t - hit) / h
	end
	local back = math.max(0.05, action.follow + action.recover)
	return to * (1 - ease("inout", (t - hit - h) / back))
end

-- The meta controls of a boss's action laid into its pose (a copy): `tremble` (rad of a fast shake of the body and the
-- arms: a gathering strain), `air` (leg lengths the whole body is lifted: a hop), a channel's turn and a leap's flight
-- on its arc toward the target (the server lands it there at the hit). Also the rad the whole body turns as one piece
-- about the pelvis, feet and all (`spin`, the share of a channel's turn the feet step round): the caller turns the
-- posed body by it (a turn of the controls would wind the knees round with many turns of the feet).
local function bossMeta(
	inst: Instance,
	action: BipedStyles.Action,
	run: ActionRun,
	c: Controls,
	t: number,
	now: number
): (Controls, number)
	local out = table.clone(c)
	local L = inst.skel.legLength
	local tremble = out.tremble
	if tremble then
		local k = tremble
		out.spitch = (out.spitch or 0) + k * math.sin(now * 2 * math.pi * 11)
		out.sroll = (out.sroll or 0) + 0.6 * k * math.sin(now * 2 * math.pi * 13.7 + 1.1)
		out.hpitch = (out.hpitch or 0) + 0.5 * k * math.sin(now * 2 * math.pi * 12.3 + 0.7)
		out.aRp = (out.aRp or 0) + 0.8 * k * math.sin(now * 2 * math.pi * 9.3 + 2)
		out.aLp = (out.aLp or 0) + 0.8 * k * math.sin(now * 2 * math.pi * 10.1 + 0.4)
		out.tremble = nil :: any
	end
	local air = out.air
	if air then
		out.py = (out.py or 0) + air
		out.fLy = (out.fLy or 0) + air
		out.fRy = (out.fRy or 0) + air
		out.air = nil :: any
	end
	local whole = out.spin or 0
	out.spin = nil :: any
	local twist = 0
	if action.channel and run.turn then
		local turn = channelTurn(action, run, t)
		local feet = action.turnFeet or 0.25
		whole += turn * feet
		twist += turn * (1 - feet)
	end
	twistBody(out, twist)
	if action.leap then
		-- the flight: the last `fly` s before the hit, on the boss's arc (Data/BossMotions arc, Logic/Gait.leapArc)
		local arc = run.arc
		local fly = if arc then arc[2] else math.min(action.strike, run.hit * 0.7)
		local height = if arc then arc[1] else 0.8 * L
		local k = (t - (run.hit - fly)) / math.max(fly, 0.05)
		if k > 0 then
			k = math.min(k, 1)
			local lift = 4 * height * k * (1 - k) / L
			local reach = run.reach
			local dx = if reach then reach[1] * k / L else 0
			local dz = if reach then reach[3] * k / L else 0
			out.px = (out.px or 0) + dx
			out.pz = (out.pz or 0) + dz
			out.py = (out.py or 0) + lift
			for _, side in SIDES do
				out["f" .. side .. "x"] = (out["f" .. side .. "x"] or 0) + dx
				out["f" .. side .. "z"] = (out["f" .. side .. "z"] or 0) + dz
				out["f" .. side .. "y"] = (out["f" .. side .. "y"] or 0) + lift
			end
		end
	end
	return out, whole
end

---------------------------------------------------------------- evaluation

-- One frame: the bones' Transforms of the biped for `input` (and the weights it keeps between frames).
function BipedMotion.step(inst: Instance, input: Input): BipedPose.Posed
	local skel = inst.skel
	local style = inst.style
	local now = input.now
	local dt = input.dt
	-- 1. locomotion
	local world, shift = locomotion(inst, input)
	-- 2. combat stance (a boss keeps some of it out of the fight; its enraged and shielded stances ease in)
	local boss = style.boss
	local combatTarget = if input.combat then 1 elseif boss then boss.calm else 0
	inst.combat = if input.snap then combatTarget else approach(inst.combat, combatTarget, COMBAT_RATE, dt)
	if boss then
		local rage = if input.enraged then 1 else 0
		local shield = if input.shielded then 1 else 0
		inst.rage = if input.snap then rage else approach(inst.rage, rage, STANCE_RATE, dt)
		inst.shield = if input.snap then shield else approach(inst.shield, shield, STANCE_RATE, dt)
	end
	local guard = guardControls(inst, now)
	if inst.combat > 0.01 then
		local gw, gs = BipedPose.world(skel, guard, inst.grip)
		local upper = inst.combat * (1 - 0.65 * inst.run)
		local legs = inst.combat * (1 - inst.move)
		world = BipedPose.blend(world, gw, 1, maskWith(upper, legs))
		shift = lerpVec(shift, gs, legs)
	end
	-- 3. the keyed action; one cut short by another (or by none) fades out from its last pose
	local run = input.action
	local last = inst.lastAction
	local kept = inst.lastPose
	if last and (not run or run.name ~= last.name or run.start ~= last.start) then
		local from = kept.world
		inst.cut = if from
				and kept.upper > 0.02
				and not input.snap
			then { world = from, shift = kept.shift, upper = kept.upper, legs = kept.legs, at = now }
			else nil
	end
	inst.lastAction = run
	kept.world, kept.upper, kept.legs = nil, 0, 0
	-- (the weight of the actions: the look, the scan and the lean give way to it)
	local actionW = 0
	local cut = inst.cut
	if cut then
		local k = (now - cut.at) / ACTION_CUT
		if k >= 1 or k < 0 or input.snap then
			inst.cut = nil
		else
			local fade = 1 - ease("inout", k)
			world = BipedPose.blend(world, cut.world, 1, maskWith(cut.upper * fade, cut.legs * fade))
			shift = lerpVec(shift, cut.shift, cut.legs * fade)
			actionW = cut.upper * fade
		end
	end
	if run then
		local action = style.actions[run.name]
		if action then
			local t = now - run.start
			local length = BipedMotion.length(action, run.hit, run.hold)
			if t >= 0 and (t <= length or action.hold) then
				local startPose = action.keys[1]
						and action.keys[1].u == 0
						and action.keys[1].seg == "A"
						and action.keys[1].pose
					or guard
				local controls = sampleAction(action, run, math.min(t, length), startPose)
				local travel = controls.travel
				if travel and run.reach and action.travel then
					local L = skel.legLength
					local dx, dz = run.reach[1] * travel / L, run.reach[3] * travel / L
					controls = table.clone(controls)
					for _, key in { "px", "fLx", "fRx" } do
						controls[key] = (controls[key] or 0) + dx
					end
					for _, key in { "pz", "fLz", "fRz" } do
						controls[key] = (controls[key] or 0) + dz
					end
				end
				if controls.travel ~= nil then
					controls = table.clone(controls)
					controls.travel = nil :: any
				end
				local spin = 0
				if
					action.channel
					or action.leap
					or controls.tremble ~= nil
					or controls.air ~= nil
					or controls.spin ~= nil
				then
					controls, spin = bossMeta(inst, action, run, controls, math.min(t, length), now)
				end
				local w = math.min(1, t / ACTION_IN)
				if not action.hold then
					w = math.min(w, math.max(0, (length - t) / ACTION_OUT))
				end
				w = ease("inout", w)
				actionW = math.max(actionW, w)
				local aw, as = BipedPose.world(skel, controls, inst.grip)
				if math.abs(spin) > 1e-5 then
					BipedPose.turnSubtree(aw, "Hips", BipedPose.ry(spin))
				end
				local legs = if action.full then w elseif action.legs then w * (1 - inst.move) else 0
				world = BipedPose.blend(world, aw, 1, maskWith(w, legs))
				shift = lerpVec(shift, as, legs)
				kept.world, kept.shift, kept.upper, kept.legs = aw, as, w, legs
			end
		end
	end
	-- 4. reactions
	local hitAt = input.hitAt
	if hitAt and input.hitSide then
		local t = now - hitAt
		if t >= 0 and t < FLINCH_RISE + FLINCH_FALL then
			local e = if t < FLINCH_RISE
				then ease("out", t / FLINCH_RISE)
				else (1 - ease("inout", (t - FLINCH_RISE) / FLINCH_FALL)) * (1 + 0.15 * math.sin(t * 25))
			-- an action keeps going: the flinch is lighter on a body that swings (a boss's big cast barely stirs)
			e *= 1 - (if boss then boss.castDamp else 0.5) * actionW
			local f = style.flinch[input.hitSide]
			if f then
				BipedPose.turnSubtree(
					world,
					"Spine",
					BipedPose.body((f.syaw or 0) * e, (f.spitch or 0) * e, (f.sroll or 0) * e)
				)
				BipedPose.turnSubtree(world, "Neck", BipedPose.body(0, (f.hpitch or 0) * e, (f.hroll or 0) * e))
				local L = skel.legLength
				shift = { shift[1] + (f.px or 0) * L * e, shift[2], shift[3] + (f.pz or 0) * L * e }
			end
		end
	end
	-- the lean into turns while moving
	local lean = math.clamp(input.yawRate * input.speed * LEAN, -LEAN_MAX, LEAN_MAX) * inst.move
	if math.abs(lean) > 1e-3 then
		BipedPose.turnSubtree(world, "Spine", BipedPose.rz(lean))
	end
	-- a boss leans into its walk
	if boss then
		local forward = boss.lean * inst.move * (1 - actionW)
		if forward > 1e-3 then
			BipedPose.turnSubtree(world, "Spine", BipedPose.rx(-forward))
		end
	end
	-- the head (and a little the chest) toward the target
	local look = input.look
	local lookTarget = if look and inst.combat > 0.2 then 1 else 0
	inst.look = if input.snap then lookTarget else approach(inst.look, lookTarget, LOOK_RATE, dt)
	if look then
		local yaw = math.clamp(math.atan2(-look[1], -look[3]), -LOOK_MAX, LOOK_MAX)
		local flat = math.sqrt(look[1] * look[1] + look[3] * look[3])
		local pitch = math.clamp(math.atan2(-look[2], flat), -0.5, 0.5)
		inst.lookYaw = if input.snap then yaw else approach(inst.lookYaw, yaw, LOOK_RATE * 1.5, dt)
		inst.lookPitch = if input.snap then pitch else approach(inst.lookPitch, pitch, LOOK_RATE * 1.5, dt)
	end
	local lw = inst.look * (1 - 0.7 * actionW)
	if lw > 0.01 then
		BipedPose.turnSubtree(world, "Spine2", BipedPose.ry(inst.lookYaw * LOOK_CHEST * lw))
		BipedPose.turnSubtree(
			world,
			"Neck",
			BipedPose.body(inst.lookYaw * LOOK_HEAD * lw, inst.lookPitch * 0.6 * lw, 0)
		)
	end
	-- a boss with no one to look at scans its ground slowly
	if boss then
		local scan = boss.scan * (1 - inst.look) * (1 - actionW)
		if scan > 1e-3 then
			local ts = now + inst.seed * 5.3
			local yaw = scan * (0.8 * math.sin(ts * 2 * math.pi / 11) + 0.2 * math.sin(ts * 2 * math.pi / 4.3))
			BipedPose.turnSubtree(world, "Neck", BipedPose.ry(yaw))
		end
	end
	return BipedPose.transforms(skel, world, shift)
end

---------------------------------------------------------------- choosing the action

-- The action of an attack: an ability by its id, the thrown blow, else the regular blows in turn (`count`).
function BipedMotion.pick(style: BipedStyles.Style, attackId: string?, shot: string?, count: number): string
	if attackId and style.abilities[attackId] then
		return style.abilities[attackId]
	end
	if attackId then
		-- an unknown ability: the heaviest blow the style has
		return if style.actions.heavy then "heavy" else style.basic[1]
	end
	if shot == "throw" and style.throw then
		return style.throw
	end
	return style.basic[1 + (count - 1) % #style.basic]
end

-- The death of an instance (one of the style's, by its seed).
function BipedMotion.death(inst: Instance): string
	local list = inst.style.death
	return list[1 + math.floor(hash01(5, inst.seed) * #list) % #list]
end

-- The flinch side of a blow coming along `dir` (root-space unit direction from the attacker into the monster).
function BipedMotion.side(dir: Vec): string
	local x, z = dir[1], dir[3]
	if math.abs(z) >= math.abs(x) then
		-- pushed backward (+z) means the blow came from the front
		return if z > 0 then "front" else "back"
	end
	return if x > 0 then "left" else "right"
end

return BipedMotion
