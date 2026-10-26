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
-- Pure (numbers in, Transforms out through Logic/BipedPose); client/Anim/BipedRig writes the bones and AnimLab
-- evaluates it at a fixed time.

local BipedClip = require("./BipedClip")
local BipedClips = require("../Data/BipedClips")
local BipedPose = require("./BipedPose")
local BipedStyles = require("../Data/BipedStyles")
local NpcPose = require("./NpcPose")

local BipedMotion = {}

type Vec = { number }
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
	combat: number,
	look: number,
	lookYaw: number,
	lookPitch: number,
	lastAction: ActionRun?,
	grip: { number }?, -- the model's own blade direction (Data/MonsterAssets `grip`), else the style's
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
		combat = 0,
		look = 0,
		lookYaw = 0,
		lookPitch = 0,
		lastAction = nil,
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

-- The action's segment times: anticipation stretched to the windup, strike ending on the hit.
local function segments(action: BipedStyles.Action, hit: number): { [string]: { number } }
	local s = math.min(action.strike, hit * 0.7)
	local a = math.max(0, hit - s)
	return {
		A = { 0, a },
		S = { a, s },
		F = { hit, action.follow },
		R = { hit + action.follow, action.recover },
	}
end

-- Seconds an action lasts (to the end of its recovery).
function BipedMotion.length(action: BipedStyles.Action, hit: number): number
	return hit + action.follow + action.recover
end

-- The controls of `action` at `t` seconds (hit at `hit`), starting from `startPose`.
local function keyed(action: BipedStyles.Action, hit: number, t: number, startPose: Controls): Controls
	local seg = segments(action, hit)
	local prevT, prevPose = 0, startPose
	for _, key in action.keys do
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
	local body = keyed(action, run.hit, t, startPose)
	local lag = action.lag
	if not lag then
		return body
	end
	local head = if (lag.head or 0) > 0 then keyed(action, run.hit, math.max(0, t - lag.head), startPose) else nil
	local free = if (lag.free or 0) > 0 then keyed(action, run.hit, math.max(0, t - lag.free), startPose) else nil
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

-- The controls of action `name` of `style` at `t` (hit at `hit`), the head and the free arm trailing: AnimLab's pose
-- sheets and the tests read the keyed timeline without the layers.
function BipedMotion.controlsAt(style: BipedStyles.Style, name: string, hit: number, t: number): Controls?
	local action = style.actions[name]
	if not action then
		return nil
	end
	local first = action.keys[1]
	local startPose = if first and first.u == 0 and first.seg == "A" then first.pose else style.guard
	return sampleAction(action, { name = name, start = 0, hit = hit }, t, startPose)
end

-- The times of an action's segments: the end of the anticipation (the peak), the hit, the end.
function BipedMotion.times(action: BipedStyles.Action, hit: number): (number, number, number)
	local seg = segments(action, hit)
	return seg.A[2], hit, BipedMotion.length(action, hit)
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
	if input.snap then
		inst.move, inst.run = moveTarget, runTarget
	else
		inst.move = approach(inst.move, moveTarget, MOVE_RATE * 0.7, dt)
		inst.run = approach(inst.run, runTarget, RUN_RATE * 0.7, dt)
	end
	local w, r = gaitDef.walk, gaitDef.run
	local function mix(key: string): number
		return w[key] + (r[key] - w[key]) * inst.run
	end
	local k = mix("k")
	local ground = if moving then speed elseif turning then math.abs(input.yawRate) * L * 0.35 else 0
	inst.phase = (inst.phase + dt * ground / math.max(0.2, k * L)) % 1
	local out: Controls = table.clone(gaitDef.rest)
	local t = input.now + inst.seed * 3.7
	local breath = math.sin(t * 2 * math.pi / 3.6)
	out.spitch = (out.spitch or 0) + 0.03 * breath
	out.aRo = (out.aRo or 0) + 0.04 * breath
	out.aLo = (out.aLo or 0) + 0.04 * breath
	local m = inst.move
	if m > 0.005 then
		local duty, lift = mix("duty"), mix("lift")
		local stride = k * 0.5 -- each foot covers half the cycle's distance
		local feet: { [string]: number } = { L = 0, R = 0.5 }
		for side, offset in feet do
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
			end
			out["f" .. side .. "z"] = (out["f" .. side .. "z"] or 0) + z * m
			out["f" .. side .. "y"] = (out["f" .. side .. "y"] or 0) + y * m
			out["t" .. side] = (out["t" .. side] or 0) + toe * m
		end
		local a = 2 * math.pi * inst.phase
		out.py = (out.py or 0) - mix("bob") * math.cos(2 * a) * m
		out.proll = (out.proll or 0) + mix("sway") * math.sin(a) * m
		out.px = (out.px or 0) + mix("sway") * 0.4 * math.sin(a) * m
		out.pyaw = (out.pyaw or 0) + mix("yaw") * math.sin(a) * m
		out.syaw = (out.syaw or 0) - mix("yaw") * 0.8 * math.sin(a) * m
		out.hyaw = (out.hyaw or 0) - mix("yaw") * 0.4 * math.sin(a) * m
		out.ppitch = (out.ppitch or 0) + mix("lean") * m
		out.hpitch = (out.hpitch or 0) - mix("lean") * 0.7 * m + 0.04 * math.cos(2 * a) * m
		out.aRp = (out.aRp or 0) + 0.12 * math.sin(a) * m
		out.aLp = (out.aLp or 0) - 0.12 * math.sin(a) * m
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
	local moveTarget = if moving then math.clamp(speed / (walkSpeed * 0.5), 0, 1) elseif turning then 0.65 else 0
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
	return BipedPose.blend(idleWorld, world, inst.move), lerpVec(idleShift, shift, inst.move)
end

-- The guard with breathing, a slow sway of the weight and a small bob (per instance).
local function guardControls(inst: Instance, now: number): Controls
	local out = table.clone(inst.style.guard)
	local t = now + inst.seed * 3.1
	local breath = math.sin(t * 2 * math.pi / 3.2)
	local sway = math.sin(t * 2 * math.pi / 5.7)
	out.spitch = (out.spitch or 0) + 0.025 * breath
	out.cRu = (out.cRu or 0) + 0.02 * breath
	out.cLu = (out.cLu or 0) + 0.02 * breath
	out.py = (out.py or 0) + 0.006 * breath
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

---------------------------------------------------------------- evaluation

-- One frame: the bones' Transforms of the biped for `input` (and the weights it keeps between frames).
function BipedMotion.step(inst: Instance, input: Input): BipedPose.Posed
	local skel = inst.skel
	local style = inst.style
	local now = input.now
	local dt = input.dt
	-- 1. locomotion
	local world, shift = locomotion(inst, input)
	-- 2. combat stance
	local combatTarget = if input.combat then 1 else 0
	inst.combat = if input.snap then combatTarget else approach(inst.combat, combatTarget, COMBAT_RATE, dt)
	local guard = guardControls(inst, now)
	if inst.combat > 0.01 then
		local gw, gs = BipedPose.world(skel, guard, inst.grip)
		local upper = inst.combat * (1 - 0.65 * inst.run)
		local legs = inst.combat * (1 - inst.move)
		world = BipedPose.blend(world, gw, 1, maskWith(upper, legs))
		shift = lerpVec(shift, gs, legs)
	end
	-- 3. the keyed action
	local run = input.action
	local actionW = 0
	if run then
		local action = style.actions[run.name]
		if action then
			local t = now - run.start
			local length = BipedMotion.length(action, run.hit)
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
				local w = math.min(1, t / ACTION_IN)
				if not action.hold then
					w = math.min(w, math.max(0, (length - t) / ACTION_OUT))
				end
				w = ease("inout", w)
				actionW = w
				local aw, as = BipedPose.world(skel, controls, inst.grip)
				local legs = if action.full then w elseif action.legs then w * (1 - inst.move) else 0
				world = BipedPose.blend(world, aw, 1, maskWith(w, legs))
				shift = lerpVec(shift, as, legs)
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
			-- an action keeps going: the flinch is lighter on a body that swings
			e *= 1 - 0.5 * actionW
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
