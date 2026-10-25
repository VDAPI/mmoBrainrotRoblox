--!strict
-- Template animation (docs/ANIM-WZORCE.md F2): the motion of an imported quadruped in layers, from the bottom:
-- 1. locomotion synthesised from the gait tables of its style (walk, trot, gallop: footfall order, duty, stride, body
--    bob and pitch, spine flex, head counter-pitch, tail): one phase advanced by distance, so the feet keep pace with
--    the ground speed; the gaits blend by speed over leg length; stepping on the spot while turning;
-- 2. idle: breathing, weight shift, looking around, the tail's lazy sway, ear flicks and fidgets (sniffing, a head
--    shake); the fighting stance (head low and forward, tail level) while it fights, calm and low while it goes home;
-- 3. keyed actions (Logic/MotionTimeline: anticipation stretched to the server's windup, the strike ending on its hit)
--    with the gather's tremble; head yaw mirrored on every other blow;
-- 4. additive reactions: the flinch by side, the lean into turns, the head looking at the target.
-- Pure: client/Anim/QuadRig writes the bones, AnimLab evaluates it at a fixed time. The functions the game calls have
-- the names and arguments of Logic/BipedMotion's (step, pick, death, side, length, controlsAt, times).

local MotionTimeline = require("./MotionTimeline")
local NpcPose = require("./NpcPose")
local QuadPose = require("./QuadPose")
local QuadStyles = require("../Data/QuadStyles")

local QuadMotion = {}

type Vec = { number }
type Controls = QuadPose.Controls

export type ActionRun = { name: string, start: number, hit: number, reach: Vec?, mirror: boolean? }
export type Input = {
	now: number,
	dt: number,
	speed: number,
	yawRate: number,
	combat: boolean,
	returning: boolean?,
	action: ActionRun?,
	hitAt: number?,
	hitSide: string?,
	look: Vec?,
	snap: boolean?,
}
export type Instance = {
	skel: QuadPose.Skeleton,
	style: QuadStyles.Style,
	seed: number,
	rate: number,
	phase: number,
	weights: { [string]: number }, -- gait weights
	move: number,
	combat: number,
	calm: number,
	look: number,
	lookYaw: number,
	lookPitch: number,
	fidget: ActionRun?,
	nextFidget: number,
	lastAction: number,
	lastTime: number,
}

local function hash01(n: number, seed: number): number
	return NpcPose.hash01(n, seed)
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function add(into: Controls, key: string, v: number)
	into[key] = (into[key] or 0) + v
end

local function addAll(into: Controls, from: Controls, k: number)
	for key, v in from do
		into[key] = (into[key] or 0) + v * k
	end
end

function QuadMotion.new(skel: QuadPose.Skeleton, styleId: string, seed: number): Instance?
	local style = QuadStyles.get(styleId)
	if not style then
		return nil
	end
	return {
		skel = skel,
		style = style,
		seed = seed,
		rate = 1 + (hash01(2, seed) * 2 - 1) * style.rate,
		phase = hash01(3, seed),
		weights = { walk = 1 },
		move = 0,
		combat = 0,
		calm = 0,
		look = 0,
		lookYaw = 0,
		lookPitch = 0,
		fidget = nil,
		nextFidget = 4 + hash01(4, seed) * 6,
		lastAction = -math.huge,
		lastTime = 0,
	}
end

---------------------------------------------------------------- locomotion

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The gait weights at `ratio` (speed over leg length): a crossfade band around each threshold.
local function gaitWeights(style: QuadStyles.Style, ratio: number): { [string]: number }
	local t = style.thresholds
	local band = 0.35
	local trot = smooth((ratio - (t.trot - band)) / (2 * band))
	local gallop = smooth((ratio - (t.gallop - band)) / (2 * band))
	return { walk = 1 - trot, trot = trot * (1 - gallop), gallop = gallop }
end

-- One gait's controls at `phase` (0..1).
local function gaitControls(style: QuadStyles.Style, name: string, phase: number): Controls
	local g = style.gaits[name]
	local out: Controls = {}
	local A = math.asin(math.clamp(g.duty * g.k / 2, 0.15, 0.6))
	for leg, offset in g.foot do
		local front = string.sub(leg, 1, 1) == "F"
		local duty = if front then (g.dutyFront or g.duty) else g.duty
		local p = (phase - offset) % 1
		local u, f, paw
		if p < duty then
			local s = p / duty
			u = A * (1 - 2 * s)
			f = g.foldStance * math.sin(math.pi * s)
			paw = 0
		else
			local q = (p - duty) / (1 - duty)
			u = -A + 2 * A * smooth(q)
			local bump = math.sin(math.pi * math.clamp(q / 0.85, 0, 1))
			f = (if front then g.foldFront else g.foldHind) * bump
			paw = (if front then g.pawFront else g.pawHind) * bump
		end
		out[leg .. "u"] = u
		out[leg .. "f"] = f
		out[leg .. "p"] = paw
	end
	local w = 2 * math.pi * phase
	-- body: bob twice a cycle (walk / trot) or the gallop's rise and pitch
	if name == "gallop" then
		out.by = g.bob * math.cos(2 * math.pi * (phase - 0.9))
		out.bpitch = g.pitch * math.cos(2 * math.pi * (phase - 0.15))
		out.sflex = g.flex * math.cos(2 * math.pi * (phase - 0.9)) - g.flex * 0.25
	else
		out.by = -g.bob * math.cos(2 * w)
		out.bpitch = 0
		out.broll = g.roll * math.sin(w)
		out.syaw = g.spineYaw * math.sin(w)
	end
	-- the head keeps level against the body's pitch; the tail
	out.npitch = (out.bpitch or 0) * 0.8 + g.neck
	out.tpitch = g.tail
	for i = 1, 4 do
		out["tY" .. i] = g.tailSway * math.sin(w - i * 0.95)
	end
	return out
end

local function locomotion(inst: Instance, input: Input): Controls
	local style = inst.style
	local L = inst.skel.L
	local dt = input.dt
	local speed = input.speed
	local turning = speed < 0.3 * L and math.abs(input.yawRate) > 1
	local moving = speed >= 0.3 * L
	local ratio = speed / L
	local targetW = gaitWeights(style, if turning then 0.8 else ratio)
	local moveTarget = if moving then math.clamp(ratio / 0.6, 0, 1) elseif turning then 0.7 else 0
	if input.snap then
		inst.weights = targetW
		inst.move = moveTarget
	else
		for name in style.gaits do
			inst.weights[name] = approach(inst.weights[name] or 0, targetW[name] or 0, 6, dt)
		end
		inst.move = approach(inst.move, moveTarget, 8, dt)
	end
	local k = 0
	for name, w in inst.weights do
		k += style.gaits[name].k * w
	end
	local ground = if moving then speed elseif turning then math.abs(input.yawRate) * L * 0.4 else 0
	inst.phase = (inst.phase + dt * ground / math.max(0.2, k * L)) % 1
	local out: Controls = {}
	if inst.move > 0.005 then
		for name, w in inst.weights do
			if w > 0.005 then
				addAll(out, gaitControls(style, name, inst.phase), w * inst.move)
			end
		end
	end
	return out
end

-- Idle: breathing, weight shift, look-around, tail sway and ear flicks (scaled down while it moves).
local function idleLayer(inst: Instance, now: number, out: Controls)
	local style = inst.style
	local t = now + inst.seed * 5.1
	local still = 1 - inst.move
	local breath = math.sin(t * 2 * math.pi * 0.35)
	add(out, "sflex", 0.017 * breath)
	add(out, "by", 0.004 * breath)
	local shift = math.sin(t * 2 * math.pi * 0.12)
	add(out, "bx", 0.03 * shift * still)
	add(out, "broll", 0.017 * shift * still)
	-- the tail
	add(out, "tpitch", style.idle.tail * still)
	for i = 1, 4 do
		add(out, "tY" .. i, 0.14 * math.sin(t * 2 * math.pi * 0.25 - i * 0.7) * still)
	end
	-- looks around every few seconds (with no target)
	local slot = math.floor(t / 4.2)
	local function target(n: number): (number, number)
		if hash01(n, inst.seed) < 0.35 then
			return 0, 0
		end
		return (hash01(n + 11, inst.seed) * 2 - 1) * 0.6, (hash01(n + 23, inst.seed) * 2 - 1) * 0.17
	end
	local y0, p0 = target(slot - 1)
	local y1, p1 = target(slot)
	local k = smooth((t - slot * 4.2) / 0.35)
	local free = still * (1 - inst.combat) * (1 - inst.look)
	add(out, "hyaw", (y0 + (y1 - y0) * k) * 0.55 * free)
	add(out, "nyaw", (y0 + (y1 - y0) * k) * 0.45 * free)
	add(out, "hpitch", (p0 + (p1 - p0) * k) * free)
	-- ear flicks
	for i, ear in { "earL", "earR" } do
		local e = math.floor(t / 5.3 + i * 0.37)
		local local_t = t - (e - i * 0.37) * 5.3
		if hash01(e + i * 101, inst.seed) < 0.5 and local_t < 0.15 then
			add(out, ear, 0.35 * math.sin(local_t / 0.15 * math.pi))
		end
	end
end

---------------------------------------------------------------- evaluation

local function lerpControls(a: Controls, b: Controls, k: number): Controls
	local out: Controls = {}
	for key, v in a do
		out[key] = v + ((b[key] or 0) - v) * k
	end
	for key, v in b do
		if a[key] == nil then
			out[key] = v * k
		end
	end
	return out
end

-- Head and body yaw are mirrored on a mirrored run (a toss to the other side).
local MIRRORED: { [string]: boolean } =
	{ hyaw = true, nyaw = true, hroll = true, byaw = true, broll = true, syaw = true, bx = true }

local function actionControls(style: QuadStyles.Style, run: ActionRun, t: number): Controls?
	local action = style.actions[run.name]
	if not action then
		return nil
	end
	local first = action.keys[1]
	local start = if first and first.u == 0 and first.seg == "A" then first.pose else style.stance
	local controls = MotionTimeline.at(action, run.hit, t, start)
	if run.mirror then
		controls = table.clone(controls)
		for key in MIRRORED do
			if controls[key] then
				controls[key] = -controls[key]
			end
		end
	end
	return controls
end

function QuadMotion.step(inst: Instance, input: Input): QuadPose.Posed
	local style = inst.style
	local skel = inst.skel
	local now = input.now
	local dt = input.dt
	local L = skel.L
	-- 1. locomotion
	local controls = locomotion(inst, input)
	-- 2. idle, stance, calm
	idleLayer(inst, now, controls)
	local combatTarget = if input.combat then 1 else 0
	local calmTarget = if input.returning then 1 else 0
	inst.combat = if input.snap then combatTarget else approach(inst.combat, combatTarget, 4, dt)
	inst.calm = if input.snap then calmTarget else approach(inst.calm, calmTarget, 3, dt)
	if inst.combat > 0.005 then
		addAll(controls, style.stance, inst.combat * (1 - 0.6 * inst.move))
	end
	if inst.calm > 0.005 then
		addAll(controls, style.calm, inst.calm)
	end
	-- fidgets when idle, alone and still
	local run = input.action
	local busy = run ~= nil
		and style.actions[run.name] ~= nil
		and now - run.start < MotionTimeline.length(style.actions[run.name], run.hit)
	if busy then
		inst.lastAction = now
	end
	local fidget = inst.fidget
	if fidget and (busy or input.combat or inst.move > 0.2) then
		inst.fidget = nil
		fidget = nil
	end
	if
		not fidget
		and not busy
		and not input.combat
		and inst.move < 0.05
		and now >= inst.nextFidget
		and #style.fidgets > 0
	then
		local n = math.floor(now)
		local name = style.fidgets[1 + math.floor(hash01(n, inst.seed) * #style.fidgets) % #style.fidgets]
		inst.fidget = { name = name, start = now, hit = 0.5 }
		inst.nextFidget = now
			+ style.fidgetEvery[1]
			+ hash01(n + 3, inst.seed) * (style.fidgetEvery[2] - style.fidgetEvery[1])
		fidget = inst.fidget
	end
	if now < inst.lastTime then
		inst.fidget = nil
		fidget = nil
		inst.nextFidget = now + 4
	end
	inst.lastTime = now
	-- 3. the keyed action (or a fidget)
	local actionW = 0
	local playing = if run and style.actions[run.name] then run else fidget
	if playing then
		local action = style.actions[playing.name]
		local t = now - playing.start
		local length = MotionTimeline.length(action, playing.hit)
		if t >= 0 and (t <= length or action.hold) then
			local keyed = actionControls(style, playing, math.min(t, length)) :: Controls
			-- the gather trembles more and more toward the strike
			if action.tremble and action.tremble > 0 then
				local p = MotionTimeline.gather(action, playing.hit, t)
				local amp = action.tremble * p * p
				keyed = table.clone(keyed)
				keyed.bpitch = (keyed.bpitch or 0) + amp * math.sin(now * 2 * math.pi * 18)
				keyed.broll = (keyed.broll or 0) + amp * 0.7 * math.sin(now * 2 * math.pi * 15 + 1.3)
			end
			local travel = keyed.travel
			if travel and playing.reach and action.travel then
				-- the flight ends with the jaws at the target, not the body in it (a body length short)
				local rx, rz = playing.reach[1], playing.reach[3]
				local d = math.sqrt(rx * rx + rz * rz)
				local k = if d > 1e-3 then math.max(0, d - 1.1 * L) / d else 0
				keyed = table.clone(keyed)
				keyed.bx = (keyed.bx or 0) + rx * k * travel / L
				keyed.bz = (keyed.bz or 0) + rz * k * travel / L
			end
			local w = math.min(1, t / 0.08)
			if not action.hold then
				w = math.min(w, math.max(0, (length - t) / 0.18))
			end
			w = MotionTimeline.ease("inout", w)
			actionW = w
			-- an action keys the whole body; moving, the legs keep the gait (unless it keys them fully)
			local legW = if action.full then w else w * (1 - inst.move)
			local blended = lerpControls(controls, keyed, w)
			for key, v in keyed do
				local leg = string.match(key, "^[FH][LR][ufpo]$")
				if leg then
					blended[key] = (controls[key] or 0) + (v - (controls[key] or 0)) * legW
				end
			end
			controls = blended
			controls.travel = nil :: any
		end
	end
	-- 4. reactions: the flinch
	local hitAt = input.hitAt
	if hitAt and input.hitSide then
		local t = now - hitAt
		if t >= 0 and t < 0.4 then
			local e = if t < 0.05
				then MotionTimeline.ease("out", t / 0.05)
				else 1 - MotionTimeline.ease("inout", (t - 0.05) / 0.35)
			e *= 1 - 0.6 * actionW
			local f = style.flinch[input.hitSide]
			if f then
				addAll(controls, f, e)
			end
		end
	end
	-- the lean into turns
	local lean = math.clamp(input.yawRate * 0.25, -0.17, 0.17) * inst.move
	add(controls, "broll", -lean)
	add(controls, "syaw", math.clamp(input.yawRate * 0.12, -0.14, 0.14) * inst.move)
	-- the head toward the target
	local look = input.look
	local lookTarget = if look and inst.combat > 0.2 then 1 else 0
	inst.look = if input.snap then lookTarget else approach(inst.look, lookTarget, 5, dt)
	if look then
		local yaw = math.clamp(math.atan2(-look[1], -look[3]), -1.1, 1.1)
		local flat = math.sqrt(look[1] * look[1] + look[3] * look[3])
		local pitch = math.clamp(math.atan2(-look[2], flat), -0.4, 0.4)
		inst.lookYaw = if input.snap then yaw else approach(inst.lookYaw, yaw, 7, dt)
		inst.lookPitch = if input.snap then pitch else approach(inst.lookPitch, pitch, 7, dt)
	end
	local lw = inst.look * (1 - 0.6 * actionW)
	if lw > 0.01 then
		add(controls, "nyaw", inst.lookYaw * 0.5 * lw)
		add(controls, "hyaw", inst.lookYaw * 0.4 * lw)
		add(controls, "hpitch", inst.lookPitch * 0.5 * lw)
	end
	return QuadPose.solve(skel, controls)
end

---------------------------------------------------------------- the game's choices

function QuadMotion.length(action: MotionTimeline.Action, hit: number): number
	return MotionTimeline.length(action, hit)
end

function QuadMotion.times(action: MotionTimeline.Action, hit: number): (number, number, number)
	local seg = MotionTimeline.segments(action, hit)
	return seg.A[2], hit, MotionTimeline.length(action, hit)
end

function QuadMotion.controlsAt(style: QuadStyles.Style, name: string, hit: number, t: number): Controls?
	return actionControls(style, { name = name, start = 0, hit = hit }, t)
end

function QuadMotion.pick(style: QuadStyles.Style, attackId: string?, shot: string?, count: number): string
	if attackId and style.abilities[attackId] then
		return style.abilities[attackId]
	end
	if attackId then
		return if style.actions.heavy then "heavy" else style.basic[1]
	end
	if shot == "throw" and style.throw then
		return style.throw
	end
	return style.basic[1 + (count - 1) % #style.basic]
end

-- Whether the blow `count` tosses the head to the other side.
function QuadMotion.mirror(count: number): boolean
	return count % 2 == 0
end

function QuadMotion.death(inst: Instance): string
	local list = inst.style.death
	return list[1 + math.floor(hash01(5, inst.seed) * #list) % #list]
end

function QuadMotion.side(dir: Vec): string
	local x, z = dir[1], dir[3]
	if math.abs(z) >= math.abs(x) then
		return if z > 0 then "front" else "back"
	end
	return if x > 0 then "left" else "right"
end

return QuadMotion
