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
-- 2026-10-31 (the owner's Mixamo download): actions, hit reactions and the armed stance on mocap where a style names a
-- clip (Data/BipedStyles ClipRef): a blow's clip time-warped so its contact lands exactly on the server's hit (the
-- lead-in squeezed or stretched onto the windup, the strike and the follow-through at the clip's own pace), a leap's
-- ground travel laid onto the target, falls, shouts and getting up at their own pace; the keys stay the fallback.
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
local ACTION_OUT = 0.18
-- seconds a boss's keyed action fades in (blended in root axes over its stances, a longer fade lets a turn far from
-- the stance's take the long way round)
local BOSS_IN = 0.1
-- An action fades in from the pose it finds over FADE_IN_SHARE of the time to its hit, within these (s): no bone whips
-- round in its first frames (2026-10-31 Studio re-review: 70-110 deg in the first 0.1 s), and it is whole well before
-- the hit, so the blow lands on it.
local FADE_IN_SHARE = 0.55
local FADE_IN_MIN = 0.12
local FADE_IN_MAX = 0.3
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
-- A clip action's fade in and (by default) out (s); how much a blow's lead-in may be squeezed onto a short windup
-- (more starts the clip later) and how hard a long windup's ease into the coil may get.
local CLIP_OUT = 0.3
local SQUEEZE_MAX = 1.5
local STRETCH_MAX = 3
-- A giant's blow reaching down (a clip action's `low`): the most it bows at the waist (rad) and crouches (leg lengths),
-- the least angle (rad) the striking hand stays ahead of straight down from the waist (it reaches out, not under the
-- body), how long before the strike the bow starts (s), and the share of the follow-through it is held.
local LOW_BOW = 1.1
local LOW_CROUCH = 0.3
local LOW_AHEAD = 0.6
local LOW_LEAD = 0.2
local LOW_HOLD = 0.5
-- Onto a spot ahead (a clip action's `ahead`): the share of the arm's length the shoulder is brought within (the elbow
-- a little bent), the bows tried (LOW_BOW / LOW_STEPS apart) and how long before the hit the hand is drawn onto it (s).
local LOW_ARM = 0.9
local LOW_STEPS = 22
local LOW_DRAW = 0.1
-- A mocap hit reaction: held for HIT_HOLD s, gone after HIT_FADE more; the push of its step (share of the clip's,
-- leg lengths at most).
local HIT_HOLD = 0.28
local HIT_FADE = 0.3
local HIT_PUSH = 0.35
local HIT_PUSH_MAX = 0.12
-- Planted feet (2026-10-31, the Studio review of the mocap): while the biped stands, a foot within PLANT_HIGH (leg
-- lengths) over its rest height stays where it landed, turned back by the root's turn (a turn on the spot steps round
-- on it); carried farther than PLANT_SLIP by the pose or the turn (PLANT_SETTLE once no action runs: the feet settle
-- back under the stance) it steps there over PLANT_STEP s, lifted PLANT_LIFT_SHARE of the step's length at the top
-- (PLANT_LIFT to PLANT_LIFT_MAX) and carried across between PLANT_UP and PLANT_DOWN of it, in the air (2026-10-31
-- Studio round 3: the backhand's step travelled low and read as a slide), the other foot following from half way; let
-- go it eases back onto the pose at PLANT_EASE /s. No foot goes under the floor (2026-10-31 Studio re-review: toes 0.1-0.4 stud under it): the ball stays over its
-- rest height, the ankle no more than PLANT_HEEL under its own (a clip's flat foot sits its heel a little lower).
local PLANT_HIGH = 0.09
local PLANT_SLIP = 0.12
local PLANT_SETTLE = 0.05
local PLANT_STEP = 0.24
local PLANT_LIFT = 0.12
local PLANT_LIFT_MAX = 0.25
local PLANT_LIFT_SHARE = 0.4
local PLANT_UP = 0.15
local PLANT_DOWN = 0.8
-- (a turn on the spot: a step lands this far (rad, at most; PLANT_SLIP's worth at the foot) ahead of the turn)
local PLANT_LEAD = 0.7
local PLANT_EASE = 16
local PLANT_HEEL = 0.05
-- The bones a mocap hit reaction turns (the arms less: one may be swinging a blow).
local HIT_BONES: { [string]: number } = {
	Spine = 1,
	Spine1 = 1,
	Spine2 = 1,
	Neck = 1,
	Head = 1,
	RightShoulder = 0.5,
	RightArm = 0.4,
	RightForeArm = 0.4,
	RightHand = 0.4,
	LeftShoulder = 0.5,
	LeftArm = 0.5,
	LeftForeArm = 0.5,
	LeftHand = 0.5,
}

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

-- A clip ready to sample on this skeleton: its fit (played mirrored: `mirror`), its baked ground speed, and the pose of
-- its first frame (a hit reaction's base, filled on first use).
export type LoadedClip = {
	clip: BipedClip.Clip,
	fit: { [string]: NpcPose.Mat },
	speed: number?,
	mirror: boolean?,
	first: World?,
}
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
-- A foot held on the ground: its spot (root space) while `held`, the step it is taking (`stepAt`, from `sx`, `sz`) when
-- the pose has carried it too far, and the correction (`cx`, `cz`) laid on the pose's foot, eased away once let go.
type Plant = {
	held: boolean,
	x: number,
	z: number,
	cx: number,
	cy: number,
	cz: number,
	stepAt: number?,
	sx: number,
	sz: number,
	h: number, -- the step's lift (studs)
	-- the step's spot on the floor (root space, turned with the root), once fixed: a turn's from its start, any other's
	-- as it comes down (it no longer follows the pose's foot)
	fixed: boolean,
	lx: number,
	lz: number,
}

-- A giant's blow reaching down (a clip action's `low`), worked out once from the clip's pose at the hit: the bow (rad)
-- and the crouch (studs) of its run and, onto a spot ahead (`ahead`), the striking hand's side and the spot (root
-- space) it is drawn onto.
type LowPlan = { name: string, start: number, bow: number, crouch: number, side: string?, spot: Vec? }

export type Instance = {
	skel: BipedPose.Skeleton,
	style: BipedStyles.Style,
	seed: number,
	rate: number,
	clips: { [string]: LoadedClip },
	acts: { [string]: LoadedClip | false }, -- the actions' clips, loaded on first use (false: none of that name)
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
	-- (`joints`: a mocap action's, blended joint by joint: BipedPose.blendLocal)
	-- (`bow`, `crouch`: a giant's reach down laid over it, `reach` the weight of its hand drawn onto `low`'s spot:
	-- reachDown)
	lastPose: {
		world: BipedPose.World?,
		shift: Vec,
		upper: number,
		legs: number,
		joints: boolean?,
		bow: number?,
		crouch: number?,
		low: LowPlan?,
		reach: number?,
	},
	cut: {
		world: BipedPose.World,
		shift: Vec,
		upper: number,
		legs: number,
		at: number,
		joints: boolean?,
		bow: number?,
		crouch: number?,
		low: LowPlan?,
		reach: number?,
	}?,
	grip: { number }?, -- the model's own blade direction (Data/MonsterAssets `grip`), else the style's
	rage: number, -- weights of a boss's enraged and shielded stances
	shield: number,
	feet: { [string]: Plant }, -- the planted feet by side ("R", "L")
	low: LowPlan?, -- a giant's blow reaching down (a clip action's `low`)
}

local function hash01(n: number, seed: number): number
	return NpcPose.hash01(n, seed)
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- Clip `name` fitted to `skel` (mirrored; `blade`: the model's blade `grip` laid along the clip's), nil without it.
local function loadClip(skel: BipedPose.Skeleton, name: string, mirror: boolean?, grip: { number }?): LoadedClip?
	local source = BipedClips.get(name)
	if not source then
		return nil
	end
	local clip = BipedClip.decode(source)
	local fit = BipedClip.fit(source, skel.dirs, { mirror = mirror, knuckles = skel.knuckles, grip = grip })
	return { clip = clip, fit = fit, speed = source.speed, mirror = mirror }
end

-- An animated biped of `style` on skeleton `skel`; `seed` makes each instance its own.
function BipedMotion.new(skel: BipedPose.Skeleton, styleId: string, seed: number, grip: { number }?): Instance?
	local style = BipedStyles.get(styleId)
	if not style then
		return nil
	end
	local blade = grip or style.grip
	local clips: { [string]: LoadedClip } = {}
	local function load(name: string, withBlade: boolean?)
		if clips[name] then
			return
		end
		local loaded = loadClip(skel, name, nil, if withBlade then blade else nil)
		if loaded then
			clips[name] = loaded
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
		local combat = list.combat
		if combat then
			load(combat.idle, combat.blade)
			load(combat.walk, combat.blade)
		end
		first = list.idle[1 + math.floor(hash01(1, seed) * #list.idle) % #list.idle]
	end
	return {
		skel = skel,
		style = style,
		seed = seed,
		rate = 1 + (hash01(2, seed) * 2 - 1) * style.rate,
		clips = clips,
		acts = {},
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
		feet = {
			R = {
				held = false,
				x = 0,
				z = 0,
				cx = 0,
				cy = 0,
				cz = 0,
				stepAt = nil,
				sx = 0,
				sz = 0,
				h = 0,
				fixed = false,
				lx = 0,
				lz = 0,
			},
			L = {
				held = false,
				x = 0,
				z = 0,
				cx = 0,
				cy = 0,
				cz = 0,
				stepAt = nil,
				sx = 0,
				sz = 0,
				h = 0,
				fixed = false,
				lx = 0,
				lz = 0,
			},
		},
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

---------------------------------------------------------------- mocap actions (2026-10-31)

-- The hit of a clip action's clip and the strike before it (clip seconds): the style's `hit` over the clip's own.
local function clipHit(ref: BipedStyles.ClipRef, source: BipedClip.Source): (number, number)
	local hc = ref.hit or source.hit or 0
	local sc = source.strike or 0.2
	return hc, math.min(sc, math.max(0, hc - (ref.from or 0)))
end

-- Seconds from the start of an action played at its clip's own pace (`free`: a fall, a shout, getting up) to its hit;
-- nil for any other action (its hit is the server's).
function BipedMotion.ownHit(action: BipedStyles.Action): number?
	local ref = action.clip
	if not ref or not ref.free then
		return nil
	end
	local source = BipedClips.get(ref.name)
	if not source then
		return nil
	end
	local hc = clipHit(ref, source)
	return math.max(0, hc - (ref.from or 0)) / (ref.rate or 1)
end

-- The clip time of clip action `action` (its clip `source`) `t` s into a run whose hit is at `hit`. A free clip plays
-- at its rate. A blow: the lead-in (the clip from `from` to its coil, the strike before its hit) laid onto the
-- anticipation, squeezed at most SQUEEZE_MAX times (a longer lead-in starts later) or stretched (the clip's pace at
-- first, easing into the coil, which it holds); the strike at the clip's pace (faster only when the windup is too short
-- for it), so the clip's contact lands exactly on the hit; after it the clip's own pace.
function BipedMotion.clipTime(action: BipedStyles.Action, source: BipedClip.Source, hit: number, t: number): number
	local ref = action.clip :: BipedStyles.ClipRef
	local from = ref.from or 0
	if ref.free then
		return from + math.max(0, t) * (ref.rate or 1)
	end
	local hc, sc = clipHit(ref, source)
	if t >= hit then
		return hc + (t - hit)
	end
	local s = math.min(action.strike, hit * 0.7)
	local a = hit - s
	local coil = hc - sc
	if t >= a then
		return coil + (t - a) * sc / math.max(s, 1e-3)
	end
	local span = coil - from
	if a <= 1e-4 or span <= 1e-4 then
		return math.max(from, coil)
	end
	local x = math.max(0, t) / a
	if span >= a then
		local used = math.min(span, a * SQUEEZE_MAX)
		return coil - used + used * x
	end
	local p = math.min(a / span, STRETCH_MAX)
	return from + span * (1 - (1 - x) ^ p)
end

-- Seconds an action fades in over (`hit`: its hit, a free clip's own).
local function fadeIn(hit: number): number
	return math.clamp(hit * FADE_IN_SHARE, FADE_IN_MIN, FADE_IN_MAX)
end

-- Seconds an action lasts (to the end of its recovery; `hold`: a channel's; a free clip's own hit).
function BipedMotion.length(action: BipedStyles.Action, hit: number, hold: number?): number
	return (BipedMotion.ownHit(action) or hit) + held(action, hold) + action.follow + action.recover
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
	local own = BipedMotion.ownHit(action) or hit
	local seg = segments(action, own, hold)
	return seg.A[2], own, BipedMotion.length(action, own, hold)
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

local function distance(a: Vec, b: Vec): number
	local x, y, z = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math.sqrt(x * x + y * y + z * z)
end

local function lerpVec(a: Vec, b: Vec, k: number): Vec
	return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }
end

-- An action's (or a hit reaction's) clip, loaded on first use; nil without it (the keys play).
local function actionClip(inst: Instance, name: string, mirror: boolean?, blade: boolean?): LoadedClip?
	local key = name .. (if mirror then "|m" else "") .. (if blade then "|b" else "")
	local loaded = inst.acts[key]
	if loaded == nil then
		local fresh = loadClip(inst.skel, name, mirror, if blade then inst.grip else nil)
		inst.acts[key] = if fresh then fresh else false
		return fresh
	elseif loaded == false then
		return nil
	end
	return loaded :: LoadedClip
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

-- A walk's swinging feet lifted `gain` times as high as its clip lifts them (`clips.lift`; 2026-10-31 Studio round 3:
-- the yeti's lumbering walk lifted its toes a quarter of a stud and read as a shuffle): in place on the walk's pose,
-- the run left as it is.
local function liftSteps(inst: Instance, world: World, shift: Vec, gain: number)
	local skel = inst.skel
	local m = inst.move * (1 - inst.run)
	if m < 0.01 then
		return
	end
	local targets: { [string]: Vec? }? = nil
	for side, key in FEET do
		local bone = skel.bones[key]
		local ankle = if bone then BipedPose.jointAt(skel, world, shift, key) else nil
		if bone and ankle then
			local up = ankle[2] - bone.pos[2]
			if up > 1e-3 then
				local list: { [string]: Vec? } = targets or {}
				list[side] = { ankle[1], ankle[2] + up * (gain - 1) * m, ankle[3] }
				targets = list
			end
		end
	end
	if targets then
		BipedPose.nudgeLegs(skel, world, shift, targets)
	end
end

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
	-- (a turn on the spot: a boss treads round on its walk, the others stand and step round on their planted feet)
	local moveTarget = if moving then walkWeight elseif turning and style.boss then 0.65 else 0
	local runTarget = math.clamp((speed - walkSpeed * 1.1) / math.max(0.5, runSpeed * 0.75 - walkSpeed * 1.1), 0, 1)
	if input.snap then
		inst.move, inst.run = moveTarget, runTarget
	else
		inst.move = approach(inst.move, moveTarget, MOVE_RATE, dt)
		inst.run = approach(inst.run, runTarget, RUN_RATE, dt)
	end
	-- the armed stance's own idle and walk while it fights (2026-10-31: Data/BipedStyles clips.combat)
	local combat = clips.combat
	local armed = if combat then inst.combat else 0
	local walkStride = walkSpeed * walkLen
	if armed > 0.01 then
		local guardSpeed, guardLen = gait(inst, combat.walk)
		walkStride += (guardSpeed * guardLen - walkStride) * armed
	end
	-- one phase for both cycles: the cycle covers this many studs at the blend
	local stride = walkStride + (runSpeed * runLen - walkStride) * inst.run
	local ground = if moving then speed elseif turning then math.abs(input.yawRate) * inst.skel.legLength * 0.5 else 0
	inst.phase = (inst.phase + dt * ground / math.max(0.1, stride)) % 1
	local idleWorld, idleShift = idleLayer(inst, input.now)
	if armed > 0.01 then
		local gw, gs = clipPose(inst, combat.idle, (input.now + inst.seed * 5.1) * inst.rate)
		if gw and gs then
			idleWorld = BipedPose.blend(idleWorld, gw, armed)
			idleShift = lerpVec(idleShift, gs, armed)
		end
	end
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
	if armed > 0.01 and walkW and walkS then
		local wl, gl = inst.clips[clips.walk], inst.clips[combat.walk]
		if wl and gl then
			local offset = (gl.clip.source.contact or 0) - (wl.clip.source.contact or 0)
			local gw, gs = clipPose(inst, combat.walk, ((inst.phase + offset) % 1) * gl.clip.length)
			if gw and gs then
				walkW = BipedPose.blend(walkW, gw, armed)
				walkS = lerpVec(walkS, gs, armed)
			end
		end
	end
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
	elseif clips.lift then
		liftSteps(inst, blended, moved, clips.lift)
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

---------------------------------------------------------------- mocap layers (2026-10-31)

-- The Hips offset (studs) of a clip action at clip time `tc` (`off`: the clip's, hip heights): a travelling clip's
-- ground travel from its start (`c0`) to its hit (`hc`) replaced by the run's reach (none once the server has moved the
-- root there: the controller drops the reach), an in-place clip carried there over its flight (`fly`).
local function clipShift(
	inst: Instance,
	ref: BipedStyles.ClipRef,
	loaded: LoadedClip,
	run: ActionRun,
	off: Vec,
	tc: number,
	c0: number,
	hc: number
): Vec
	local L = inst.skel.legLength
	local x, y, z = off[1] * L, off[2] * L, off[3] * L
	local reach = run.reach
	local rx = if reach then reach[1] else 0
	local rz = if reach then reach[3] else 0
	if ref.travel then
		local m = if ref.mirror then -1 else 1
		local x0, _, z0 = BipedClip.hipsAt(loaded.clip, c0, false)
		local xh, _, zh = BipedClip.hipsAt(loaded.clip, hc, false)
		x0, xh = x0 * m, xh * m
		local vx, vz = xh - x0, zh - z0
		local d2 = vx * vx + vz * vz
		if d2 > 0.01 then
			local p = if tc >= hc then 1 else math.clamp(((off[1] - x0) * vx + (off[3] - z0) * vz) / d2, 0, 1)
			x += p * (rx - vx * L)
			z += p * (rz - vz * L)
		end
	elseif ref.fly and reach then
		local f = ref.fly
		local k = if tc >= hc then 1 else ease("inout", (tc - f[1]) / math.max(0.05, f[2] - f[1]))
		x += rx * k
		z += rz * k
	end
	return { x, y, z }
end

-- A mocap hit reaction (the style's `hits` by side) laid over `world` (in place) `t` s after the hit with strength `e`:
-- the upper body turns as the clip's does from its first frame (the arms less), the body pushed by a little of its
-- step. Returns the shift with the push, nil without the clip.
local function hitClip(inst: Instance, world: World, shift: Vec, name: string, t: number, e: number): Vec?
	local loaded = actionClip(inst, name)
	if not loaded then
		return nil
	end
	local first = loaded.first
	if not first then
		first = (BipedClip.sample(loaded.clip, 0, false, loaded.fit))
		loaded.first = first
	end
	local now, off = BipedClip.sample(loaded.clip, t, false, loaded.fit)
	for key, share in HIT_BONES do
		local w, a, b = world[key], now[key], (first :: World)[key]
		if w and a and b then
			local delta = NpcPose.mul(a, NpcPose.transpose(b))
			world[key] = NpcPose.mul(BipedPose.slerp(NpcPose.IDENTITY, delta, e * share), w)
		end
	end
	local x0, _, z0 = BipedClip.hipsAt(loaded.clip, 0, false)
	local L = inst.skel.legLength
	local px = math.clamp((off[1] - x0) * HIT_PUSH, -HIT_PUSH_MAX, HIT_PUSH_MAX) * L * e
	local pz = math.clamp((off[3] - z0) * HIT_PUSH, -HIT_PUSH_MAX, HIT_PUSH_MAX) * L * e
	return { shift[1] + px, shift[2], shift[3] + pz }
end

-- Planted feet: while the biped stands (`hold`), a foot on the ground stays where it landed (in the world: turned back
-- by the root's own turn), the leg solved onto it; carried too far by the pose, or beyond the leg's reach, it steps there
-- (one foot at a time); lifted by the pose, or once the biped walks, it lets go, easing back onto the pose. The spot
-- held is the ball of the foot where the skeleton has a toe (a heel the pose lifts or turns pivots on it), else the
-- ankle. The blends into and out of an action, a clip on a model of other proportions and the push of a hit no longer
-- slide the feet.
-- Where a foot stepping in a turn on the spot (`at` the stance's ball of the foot, `ankle` its ankle) lands, root space
-- now: where the turn will have carried the stance's foot by the end of the step and PLANT_LEAD ahead of it (as far
-- as the leg reaches), so the next step waits; a spot of the floor meanwhile.
local function turnLanding(
	inst: Instance,
	input: Input,
	world: World,
	shift: Vec,
	side: string,
	ankle: Vec,
	at: Vec,
	slip: number
): (number, number)
	local skel = inst.skel
	local L = skel.legLength
	local sign = if input.yawRate > 0 then 1 else -1
	local x, z = at[1], at[3]
	local r = math.sqrt(x * x + z * z)
	local lead = math.min(PLANT_LEAD, PLANT_LEAD * slip / math.max(r, 0.1 * L)) * sign
	local lc, ls = math.cos(lead), math.sin(lead)
	local ox, oz = x * lc + z * ls - x, z * lc - x * ls - z
	local hip = BipedPose.jointAt(skel, world, shift, (if side == "R" then "Right" else "Left") .. "UpLeg")
	if hip then
		local leg = skel.leg[side]
		local px, py, pz = ankle[1] - hip[1], ankle[2] - hip[2], ankle[3] - hip[3]
		local d0 = math.sqrt(px * px + py * py + pz * pz)
		local d1 = math.sqrt((px + ox) ^ 2 + py * py + (pz + oz) ^ 2)
		local reach = math.max(0.97 * (leg.l1 + leg.l2), d0)
		local k = if d1 <= reach then 1 else math.clamp((reach - d0) / math.max(d1 - d0, 1e-6), 0, 1)
		x, z = x + ox * k, z + oz * k
	end
	local ahead = input.yawRate * PLANT_STEP
	local ac, as = math.cos(ahead), math.sin(ahead)
	return x * ac + z * as, z * ac - x * as
end

local function plantFeet(
	inst: Instance,
	input: Input,
	world: World,
	shift: Vec,
	ground: boolean,
	hold: boolean,
	acting: boolean
)
	local skel = inst.skel
	local L = skel.legLength
	local slip = (if acting or math.abs(input.yawRate) > TURN_STEP then PLANT_SLIP else PLANT_SETTLE) * L
	local now, dt = input.now, input.dt
	local turn = -input.yawRate * dt
	local c, s = math.cos(turn), math.sin(turn)
	local targets: { [string]: Vec? }? = nil
	for side, key in FEET do
		local foot = inst.feet[side]
		local bone = skel.bones[key]
		local ankle = if bone then BipedPose.jointAt(skel, world, shift, key) else nil
		if not bone or not ankle then
			continue
		end
		if input.snap then
			foot.held, foot.stepAt, foot.cx, foot.cy, foot.cz = false, nil, 0, 0, 0
		end
		-- the ball of the foot: the toe's joint as the pose turns the foot
		local toe = skel.bones[TOES[side]]
		local at, ball = ankle, bone.pos[2]
		if toe then
			local o = NpcPose.apply(world[key] or NpcPose.IDENTITY, {
				toe.pos[1] - bone.pos[1],
				toe.pos[2] - bone.pos[2],
				toe.pos[3] - bone.pos[3],
			})
			at, ball = { ankle[1] + o[1], ankle[2] + o[2], ankle[3] + o[3] }, toe.pos[2]
		end
		local lift = 0
		if hold and at[2] < ball + PLANT_HIGH * L then
			if foot.held then
				foot.x, foot.z = foot.x * c + foot.z * s, foot.z * c - foot.x * s
				if foot.stepAt then
					foot.sx, foot.sz = foot.sx * c + foot.sz * s, foot.sz * c - foot.sx * s
					foot.lx, foot.lz = foot.lx * c + foot.lz * s, foot.lz * c - foot.lx * s
				end
			else
				-- (from where it is: a correction still easing away is kept)
				foot.held, foot.x, foot.z = true, at[1] + foot.cx, at[3] + foot.cz
			end
			local x, z = foot.x, foot.z
			local stepAt = foot.stepAt
			if stepAt then
				local u = math.max(0, (now - stepAt) / PLANT_STEP)
				if not foot.fixed and u >= PLANT_DOWN then
					foot.lx, foot.lz, foot.fixed = at[1], at[3], true
				end
				local lx, lz = at[1], at[3]
				if foot.fixed then
					lx, lz = foot.lx, foot.lz
				end
				if u >= 1 then
					foot.stepAt, foot.x, foot.z = nil, lx, lz
					x, z = lx, lz
				else
					-- (up first, then across while it is up, then down onto the spot; a longer step lifted higher, the
					-- height kept if the spot runs on)
					local ax, az = lx - foot.sx, lz - foot.sz
					local high =
						math.clamp(PLANT_LIFT_SHARE * math.sqrt(ax * ax + az * az), PLANT_LIFT * L, PLANT_LIFT_MAX * L)
					foot.h = math.max(foot.h, high)
					local k = ease("inout", math.clamp((u - PLANT_UP) / (PLANT_DOWN - PLANT_UP), 0, 1))
					x, z = foot.sx + ax * k, foot.sz + az * k
					lift = foot.h * math.sin(math.pi * u)
				end
			else
				local dx, dz = at[1] - x, at[3] - z
				local d2 = dx * dx + dz * dz
				local far = d2 > slip * slip
				-- (one foot at a time: the other follows from half way through its step, at once when far behind)
				local other = inst.feet[if side == "R" then "L" else "R"].stepAt
				if far and other and now - other < PLANT_STEP * 0.5 and d2 < 4 * slip * slip then
					far = false
				elseif not far and not other then
					-- (a spot the leg cannot reach from the hip any more, farther than the pose's own foot)
					local hip =
						BipedPose.jointAt(skel, world, shift, (if side == "R" then "Right" else "Left") .. "UpLeg")
					local leg = skel.leg[side]
					if hip then
						local ax, ay, az =
							ankle[1] + x - at[1] - hip[1], ankle[2] - hip[2], ankle[3] + z - at[3] - hip[3]
						local px, pz = ankle[1] - hip[1], ankle[3] - hip[3]
						local reach =
							math.max(0.97 * (leg.l1 + leg.l2), math.sqrt(px * px + ay * ay + pz * pz) + 0.02 * L)
						far = ax * ax + ay * ay + az * az > reach * reach
					end
				end
				if far then
					foot.stepAt, foot.sx, foot.sz, foot.h = now, x, z, 0
					foot.fixed = math.abs(input.yawRate) > TURN_STEP * 0.5
					if foot.fixed then
						foot.lx, foot.lz = turnLanding(inst, input, world, shift, side, ankle, at, slip)
					end
				end
			end
			foot.cx, foot.cy, foot.cz = x - at[1], lift, z - at[3]
		else
			-- (a step cut short lands as the correction eases away)
			foot.held, foot.stepAt = false, nil
			local k = math.exp(-PLANT_EASE * dt)
			foot.cx *= k
			foot.cy *= k
			foot.cz *= k
		end
		-- (over the floor: the ball no lower than it stands at rest, the ankle within PLANT_HEEL of its rest height)
		local sink = if ground then math.max(0, ball - at[2], bone.pos[2] - PLANT_HEEL * L - ankle[2]) else 0
		if math.abs(foot.cx) + math.abs(foot.cy) + math.abs(foot.cz) + sink > 1e-4 * L then
			local list: { [string]: Vec? } = targets or {}
			list[side] = { ankle[1] + foot.cx, ankle[2] + foot.cy + sink, ankle[3] + foot.cz }
			targets = list
		end
	end
	if targets then
		BipedPose.nudgeLegs(skel, world, shift, targets)
	end
end

-- The bow and the crouch that bring the striking hand of clip action `ref` (its clip `loaded`, hit at clip time `hc`)
-- down to `ref.low` studs over the feet, from the pose it is laid over (`world`, `shift`): the hand farther ahead at
-- the hit turned about the waist (the Spine's joint) in the body's own plane, as far as LOW_BOW and no nearer straight
-- down than LOW_AHEAD, the rest crouched; with `ref.ahead`, onto that spot ahead of the root, drawn there by the arm
-- (returns its side and the spot, root space).
local function lowPlan(
	inst: Instance,
	ref: BipedStyles.ClipRef,
	loaded: LoadedClip,
	world: World,
	shift: Vec,
	hc: number
): (number, number, string?, Vec?)
	local skel = inst.skel
	local aw = BipedClip.sample(loaded.clip, hc, false, loaded.fit, ref.mirror)
	local at = BipedPose.positions(skel, BipedPose.blend(world, aw, 1, UPPER_MASK), shift)
	local spine, right, left = at.Spine, at.RightHand, at.LeftHand
	if not spine or not right or not left then
		return 0, 0
	end
	local hand = if left[3] < right[3] then left else right
	local floor = math.huge
	for _, key in TOES do
		local bone = skel.bones[key]
		floor = math.min(floor, if bone then bone.pos[2] else math.huge)
	end
	if floor == math.huge then
		floor = math.min(skel.bones.RightFoot.pos[2], skel.bones.LeftFoot.pos[2])
	end
	local f, u = spine[3] - hand[3], hand[2] - spine[2]
	local h = floor + (ref.low or 0) - spine[2]
	if u <= h then
		return 0, 0
	end
	local r = math.sqrt(f * f + u * u)
	local a = math.atan2(f, u)
	local L = skel.legLength
	local side = if hand == left then "Left" else "Right"
	local shoulder, elbow = at[side .. "Arm"], at[side .. "ForeArm"]
	if ref.ahead and shoulder and elbow then
		-- (onto a spot ahead of the root (2026-10-31 Studio round 3: Hrimvald's arm is longer than his waist is high,
		-- so the straight arm swung down met the ground 20 studs beyond the player): the least bow that brings the
		-- shoulder within LOW_ARM of the arm's length of the spot crouched by half LOW_CROUCH at most (between the
		-- bows tried, so it changes smoothly with the pose), else the one that comes nearest, the rest crouched; the
		-- arm bends to put the hand on it (lower))
		local spot = { 0, floor + (ref.low or 0), -ref.ahead * L }
		local arm = LOW_ARM * (distance(shoulder, elbow) + distance(elbow, hand))
		local sf, su = spine[3] - shoulder[3], shoulder[2] - spine[2]
		local rs, as = math.sqrt(sf * sf + su * su), math.atan2(sf, su)
		local tf, tu, dx = spine[3] - spot[3], spot[2] - spine[2], shoulder[1] - spot[1]
		local most = LOW_CROUCH * L * 0.5
		local bow, crouch, last = 0, math.huge, math.huge
		for i = 0, LOW_STEPS do
			local b = LOW_BOW * i / LOW_STEPS
			local f, u = rs * math.sin(as + b), rs * math.cos(as + b)
			local room = arm * arm - dx * dx - (f - tf) * (f - tf)
			local need = if room > 0 then math.max(0, u - tu - math.sqrt(room)) else math.huge
			if need <= most then
				if i > 0 and last < math.huge then
					return b - LOW_BOW / LOW_STEPS * (most - need) / (last - need), most, side, spot
				end
				return b, need, side, spot
			end
			if need < crouch then
				bow, crouch = b, need
			end
			last = need
		end
		return bow, math.min(crouch, LOW_CROUCH * L), side, spot
	end
	local most = math.min(LOW_BOW, math.pi - LOW_AHEAD - a)
	local bow = math.clamp(math.acos(math.clamp(h / math.max(r, 1e-6), -1, 1)) - a, 0, math.max(0, most))
	return bow, math.clamp(r * math.cos(a + bow) - h, 0, LOW_CROUCH * L)
end

-- `world` (in place) bowed at the waist by `bow` rad and `shift` crouched by `crouch` studs over the ankles where they
-- are, the striking hand of `plan` drawn `reach` of the way onto its spot; returns the shift.
local function lower(
	inst: Instance,
	world: World,
	shift: Vec,
	bow: number,
	crouch: number,
	plan: LowPlan?,
	reach: number
): Vec
	if bow > 1e-4 then
		BipedPose.turnSubtree(world, "Spine", BipedPose.rx(-bow))
	end
	local skel = inst.skel
	if crouch > 1e-4 then
		local targets: { [string]: Vec? } = {}
		for side, key in FEET do
			targets[side] = BipedPose.jointAt(skel, world, shift, key)
		end
		shift = { shift[1], shift[2] - crouch, shift[3] }
		BipedPose.nudgeLegs(skel, world, shift, targets)
	end
	if plan and plan.side and plan.spot and reach > 1e-4 then
		BipedPose.reachArm(skel, world, shift, plan.side, plan.spot, reach)
	end
	return shift
end

-- Clip action `ref`'s reach down onto its target `t` s into its run (`hit`, `length`, weight `w`): the body bowed and
-- crouched over the feet where they stand. Returns the shift.
local function reachDown(
	inst: Instance,
	action: BipedStyles.Action,
	ref: BipedStyles.ClipRef,
	loaded: LoadedClip,
	run: ActionRun,
	world: World,
	shift: Vec,
	hit: number,
	hc: number,
	t: number,
	length: number,
	w: number
): Vec
	local plan = inst.low
	if not plan or plan.name ~= run.name or plan.start ~= run.start then
		local bow, crouch, side, spot = lowPlan(inst, ref, loaded, world, shift, hc)
		plan = { name = run.name, start = run.start, bow = bow, crouch = crouch, side = side, spot = spot }
		inst.low = plan
	end
	local p = plan :: LowPlan
	local s = math.min(action.strike, hit * 0.7)
	local from = math.max(0, hit - s - LOW_LEAD)
	local hold = hit + action.follow * LOW_HOLD
	local e = if t < hit
		then ease("inout", math.clamp((t - from) / math.max(hit - from, 1e-3), 0, 1))
		elseif t <= hold then 1
		else 1 - ease("inout", math.clamp((t - hold) / math.max(length - hold, 1e-3), 0, 1))
	e *= w
	-- (kept for a cut: the next action fades out of the bow, not out of the clip alone)
	local kept = inst.lastPose
	-- (the hand drawn onto its spot over the last LOW_DRAW s of the strike, as the swing comes down: drawn sooner, it
	-- cut through the body and its arm turned over)
	local reach = if t < hit then ease("inout", math.clamp((t - hit) / LOW_DRAW + 1, 0, 1)) * w else e
	kept.bow, kept.crouch, kept.low, kept.reach = p.bow * e, p.crouch * e, p, reach
	return lower(inst, world, shift, p.bow * e, p.crouch * e, p, reach)
end

---------------------------------------------------------------- evaluation

-- One frame: the bones' Transforms of the biped for `input` (and the weights it keeps between frames).
function BipedMotion.step(inst: Instance, input: Input): BipedPose.Posed
	local skel = inst.skel
	local style = inst.style
	local now = input.now
	local dt = input.dt
	-- (the combat weight first: the armed stance's clips ride on it in the locomotion)
	local boss = style.boss
	local combatTarget = if input.combat then 1 elseif boss then boss.calm else 0
	inst.combat = if input.snap then combatTarget else approach(inst.combat, combatTarget, COMBAT_RATE, dt)
	-- 1. locomotion
	local world, shift = locomotion(inst, input)
	-- 2. combat stance (a boss keeps some of it out of the fight; its enraged and shielded stances ease in)
	if boss then
		local rage = if input.enraged then 1 else 0
		local shield = if input.shielded then 1 else 0
		inst.rage = if input.snap then rage else approach(inst.rage, rage, STANCE_RATE, dt)
		inst.shield = if input.snap then shield else approach(inst.shield, shield, STANCE_RATE, dt)
	end
	local guard = guardControls(inst, now)
	local armedClips = style.clips and style.clips.combat
	if inst.combat > 0.01 and not armedClips then
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
			then {
				world = from,
				shift = kept.shift,
				upper = kept.upper,
				legs = kept.legs,
				at = now,
				joints = kept.joints,
				bow = kept.bow,
				crouch = kept.crouch,
				low = kept.low,
				reach = kept.reach,
			}
			else nil
	end
	inst.lastAction = run
	kept.world, kept.upper, kept.legs, kept.joints, kept.bow, kept.crouch = nil, 0, 0, nil, nil, nil
	kept.low, kept.reach = nil, nil
	-- (the weight of the actions: the look, the scan and the lean give way to it)
	local actionW = 0
	local cut = inst.cut
	if cut then
		local k = (now - cut.at) / ACTION_CUT
		if k >= 1 or k < 0 or input.snap then
			inst.cut = nil
		else
			local fade = 1 - ease("inout", k)
			local mask = maskWith(cut.upper * fade, cut.legs * fade)
			world = if cut.joints
				then BipedPose.blendLocal(world, cut.world, 1, mask)
				else BipedPose.blend(world, cut.world, 1, mask)
			shift = lerpVec(shift, cut.shift, cut.legs * fade)
			shift = lower(
				inst,
				world,
				shift,
				(cut.bow or 0) * fade,
				(cut.crouch or 0) * fade,
				cut.low,
				(cut.reach or 0) * fade
			)
			actionW = cut.upper * fade
		end
	end
	local action = if run then style.actions[run.name] else nil
	local ref = action and action.clip
	local loaded = if ref then actionClip(inst, ref.name, ref.mirror, ref.blade) else nil
	-- (the feet are held through a blow standing its ground, not through a fall, a leap or a boss's keyed blow)
	local plantable = true
	if run and action and ref and loaded then
		-- a mocap action: the clip time-warped onto the run (its contact on the hit), faded in and out
		local source = loaded.clip.source
		local hit = BipedMotion.ownHit(action) or run.hit
		local t = now - run.start
		local length = BipedMotion.length(action, hit, run.hold)
		if t >= 0 and (t <= length or action.hold) then
			-- (a leap stands on its feet until they leave the ground, and again once it has landed where the server put
			-- it: the reach dropped after the hit; only on its way there are they the clip's alone. 2026-10-31 Studio
			-- round 3: the pounce's feet slid as it crouched to spring and its front foot slid back as it recovered)
			local flying = (ref.travel or ref.fly) and t >= hit and run.reach ~= nil
			plantable = not (ref.free or flying)
			local tc = BipedMotion.clipTime(action, source, hit, if action.hold then t else math.min(t, length))
			local aw, off = BipedClip.sample(loaded.clip, tc, false, loaded.fit, ref.mirror)
			local hc = clipHit(ref, source)
			local as = clipShift(inst, ref, loaded, run, off, tc, BipedMotion.clipTime(action, source, hit, 0), hc)
			local w = math.min(1, t / fadeIn(hit))
			if not action.hold then
				w = math.min(w, math.max(0, (length - t) / (ref.out or CLIP_OUT)))
			end
			w = ease("inout", w) * (1 - (1 - (ref.moving or 1)) * inst.move)
			actionW = math.max(actionW, w)
			local legs = if ref.upper then 0 elseif action.full then w elseif action.legs then w * (1 - inst.move) else 0
			if ref.upper then
				-- (above the hips alone: the chest takes the clip's turn in the root's axes, so the blow keeps its way
				-- where the clip's hips turned with it (2026-10-31 Studio re-review: a boss's swipe went out to the
				-- side); the joints above it still blend one by one, an arm far from the guard's not the long way round)
				aw.Hips = world.Hips
			end
			world = BipedPose.blendLocal(world, aw, 1, maskWith(w, legs))
			shift = lerpVec(shift, as, legs)
			kept.world, kept.shift, kept.upper, kept.legs, kept.joints = aw, as, w, legs, true
			if ref.low then
				shift = reachDown(inst, action, ref, loaded, run, world, shift, hit, hc, t, length, w)
			end
		end
	elseif run and action then
		local t = now - run.start
		local length = BipedMotion.length(action, run.hit, run.hold)
		if t >= 0 and (t <= length or action.hold) then
			plantable = not (boss or action.travel or action.full or action.leap or action.channel)
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
			local w = math.min(1, t / (if boss then BOSS_IN else fadeIn(run.hit)))
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
	-- 4. reactions
	local hitAt = input.hitAt
	local hitSide = input.hitSide
	-- (a style with mocap reactions: one of its clips for that side, by the blow and the instance)
	local hits = style.hits
	local hitList = if hits and hitSide then hits[hitSide] else nil
	local mocapHit = false
	if hitAt and hitList and #hitList > 0 then
		local t = now - hitAt
		if t >= 0 and t < HIT_HOLD + HIT_FADE then
			local e = if t < HIT_HOLD then 1 else 1 - ease("inout", (t - HIT_HOLD) / HIT_FADE)
			e *= (style.hitScale or 1) * (1 - (if boss then boss.castDamp else 0.5) * actionW)
			local name = hitList[1 + math.floor(hash01(math.floor(hitAt * 7), inst.seed) * #hitList) % #hitList]
			local pushed = hitClip(inst, world, shift, name, t, e)
			if pushed then
				shift = pushed
				mocapHit = true
			end
		end
	end
	if hitAt and hitSide and not mocapHit then
		local t = now - hitAt
		if t >= 0 and t < FLINCH_RISE + FLINCH_FALL then
			local e = if t < FLINCH_RISE
				then ease("out", t / FLINCH_RISE)
				else (1 - ease("inout", (t - FLINCH_RISE) / FLINCH_FALL)) * (1 + 0.15 * math.sin(t * 25))
			-- an action keeps going: the flinch is lighter on a body that swings (a boss's big cast barely stirs)
			e *= 1 - (if boss then boss.castDamp else 0.5) * actionW
			local f = style.flinch[hitSide]
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
	-- 5. feet on the floor, planted while it stands or turns on the spot (a boss's blows keep its own stance:
	-- Data/BossStyles)
	local ground = plantable and not boss and not style.float and not style.procedural and not input.flying
	local hold = ground and input.speed < STAND_SPEED and inst.move < 0.3
	plantFeet(inst, input, world, shift, ground, hold, actionW > 0.01)
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

-- The action of an attack: an ability by its id, the thrown blow, else the regular blows in turn (`count`), each
-- instance (`seed`) starting at a place of its own in the turn.
function BipedMotion.pick(
	style: BipedStyles.Style,
	attackId: string?,
	shot: string?,
	count: number,
	seed: number?
): string
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
	local n = #style.basic
	local from = if seed then math.floor(hash01(9, seed) * n) else 0
	return style.basic[1 + (count - 1 + from) % n]
end

-- The death of an instance (one of the style's, by its seed): by the side the killing blow came from (`side`,
-- BipedMotion.side) where the style has deaths for it.
function BipedMotion.death(inst: Instance, side: string?): string
	local deaths = inst.style.deaths
	local list = if deaths and side and deaths[side] then deaths[side] else inst.style.death
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
