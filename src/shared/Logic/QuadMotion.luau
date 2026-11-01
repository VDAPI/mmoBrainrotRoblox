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
-- The heavy quadrupeds (bear, boar, mammoth) add: feet planted by Logic/QuadPose's foot solver along a foot planner
-- (stance: the foot slides back at exactly the ground speed; swing: a lifted path to the next touchdown), plantigrade
-- feet kept flat, a roll about the feet that bear the weight, a trunk swinging like a pendulum behind the head, ears
-- fanning, a gait forced by an action (a charge gallops at the dash's speed).
-- The dragon (2026-10-31, Data/QuadStyles `dragon`) adds Logic/DragonMotion's wings (folded at rest, keyed open, a
-- wingbeat on the timeline, the gallop's pump), the tail's spring, the gait taken from the server's `Gait`, a flight's
-- height on the server's `Dash*` arc (`arc`), the server's stun (a dazed pose) and freeze (the pose held), and feet
-- pinned in the world (`pinFeet`, by the root's place the client passes: `rootAt`).
-- The mounts (2026-11-01, Data/QuadStyles `horse`, `lion`) add gait fields: a head nod with the stride, the head kept
-- steady against the spine's flex, and the tail's own lag and wave.
-- Pure: client/Anim/QuadRig writes the bones, AnimLab evaluates it at a fixed time. The functions the game calls have
-- the names and arguments of Logic/BipedMotion's (step, pick, death, side, length, controlsAt, times).

local DragonMotion = require("./DragonMotion")
local MotionTimeline = require("./MotionTimeline")
local NpcPose = require("./NpcPose")
local QuadPose = require("./QuadPose")
local QuadStyles = require("../Data/QuadStyles")

local QuadMotion = {}

type Vec = { number }
type Controls = QuadPose.Controls

-- `hold` keeps the end pose (AnimLab's stage, which has no server teleport, holds a leap where it landed)
export type ActionRun = { name: string, start: number, hit: number, reach: Vec?, mirror: boolean?, hold: boolean? }
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
	-- the server's gait intent (walk / trot / run) and Effects (Logic/EffectStack text at server time `serverNow`);
	-- AnimLab's stun and freeze without the attribute (read by a style with `stun`)
	flying: boolean?,
	gait: string?,
	effects: string?,
	serverNow: number?,
	stunned: boolean?,
	frozen: boolean?,
	-- (a style with `pinFeet`) where the root stands in the world: { x, z, yaw } (the skeleton's units; yaw + turns the
	-- front, -Z, toward -X), from the client each frame; without it the root goes where `speed` and `yawRate` take it
	rootAt: { number }?,
}
export type Instance = {
	skel: QuadPose.Skeleton,
	style: QuadStyles.Style,
	seed: number,
	rate: number,
	phase: number,
	weights: { [string]: number }, -- gait weights
	move: number,
	spin: number, -- 0..1: how much it steps in place (eased, so a turn that starts or stops does not snap the feet)
	turn: number, -- the eased yaw over a cycle (see `locomotion`)
	yawEase: number, -- the yaw rate the lean into a turn follows (a turn that stops at once does not snap the body)
	combat: number,
	calm: number,
	look: number,
	lookYaw: number,
	lookPitch: number,
	fidget: ActionRun?,
	nextFidget: number,
	lastAction: number,
	lastTime: number,
	planted: boolean, -- a gait plants its feet (the foot keys blend with the action like the leg keys)
	center: { [string]: number }, -- per leg: the stance's centre under the hip or shoulder (QuadMotion.gaitControls)
	trunkReady: boolean,
	trunkS: number, -- the trunk pendulum: where its tip hangs (side, forward; leg lengths) and how fast it swings
	trunkSV: number,
	trunkF: number,
	trunkFV: number,
	dragon: DragonMotion.State?, -- the wings and the tail's spring (a style with `wings` on a rig with wing bones)
	stun: number, -- the dazed pose's weight
	effects: string?, -- the Effects text last parsed and the stun / freeze ends in it (server time)
	stunEnds: number,
	freezeEnds: number,
	posed: QuadPose.Posed?, -- the last pose (held while frozen)
	-- (a style with `pinFeet`) the root's place on the ground, its recent track (time, x, z) for the pace, and per leg
	-- the foot's pin in the world ({ x, z }) and the ease off a pin it let go ({ x, z } where it left, since)
	rootReady: boolean,
	rootX: number,
	rootZ: number,
	rootYaw: number,
	track: { { number } },
	pins: { [string]: { number } },
	slips: { [string]: { number } },
	steps: { [string]: { number } }, -- a foot stepping back under the pose: from ({ x, z } in the world), since, the
	-- lift it was settling from and since when, and the spot it comes down on once over it
	shownYaw: number, -- the heading the body is drawn at (it follows the root's at a bounded rate: a snap is turned)
	shownRate: number, -- how fast that heading turns
	yawOff: number, -- the drawn heading less the root's
	roam: number, -- 0..1: how much the root really travels (an action's legs leave it to the gait as it runs)
	blowHeld: boolean, -- the keyed action has taken the feet over (since its weight was last 0)
	takeOff: number?, -- the drawn heading's offset the feet go to the action's places at as it takes them over
	keyedBefore: { [string]: { number } }, -- per leg the pose's place last frame (about the root bone: x, z, its x, z)
	blowLast: number, -- the blow's weight last frame
	gaitRatio: number, -- the pace (leg lengths a second) the server's gait intent is stepped down by, eased
	gaitName: string?, -- the gait that intent last gave
	gaitSince: number, -- when it gave it
	gaitStill: number, -- s the root has stood since it last moved (a short halt keeps that gait)
	drawnYaw: number?, -- the body's heading in the world as last drawn (its root bone's yaw)
	actionRun: ActionRun?, -- the action (or fidget) the pose had last frame
	actionSeen: number, -- when the pose first had it
	actionIsRun: boolean, -- it is the game's, not a fidget
	actionWLast: number, -- its weight last frame
	fadeRun: ActionRun?, -- one it had before, fading out since `fadeAt`
	fadeAt: number,
	fadeIsRun: boolean,
	controls: Controls?, -- (a mount) the controls of the last frame: QuadMotion.saddle reads the body's from them
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
	local planted = false
	for _, g in style.gaits do
		if g.plant or g.level then
			planted = true
		end
	end
	-- a planted stance is centred under the leg's top joint (the leg upright at mid-stance), not on the rest foot
	local center: { [string]: number } = {}
	for side, chain in skel.chains do
		local top = skel.bones[chain.top].pos
		center[side] = (top[3] - chain.foot[3]) / skel.L
	end
	return {
		skel = skel,
		style = style,
		seed = seed,
		rate = 1 + (hash01(2, seed) * 2 - 1) * style.rate,
		phase = hash01(3, seed),
		weights = { walk = 1 },
		move = 0,
		spin = 0,
		turn = 0,
		yawEase = 0,
		combat = 0,
		calm = 0,
		look = 0,
		lookYaw = 0,
		lookPitch = 0,
		fidget = nil,
		nextFidget = 4 + hash01(4, seed) * 6,
		lastAction = -math.huge,
		lastTime = 0,
		planted = planted,
		center = center,
		trunkReady = false,
		trunkS = 0,
		trunkSV = 0,
		trunkF = 0,
		trunkFV = 0,
		dragon = DragonMotion.new(skel, style.wings, seed),
		stun = 0,
		effects = nil,
		stunEnds = 0,
		freezeEnds = 0,
		posed = nil,
		rootReady = false,
		shownYaw = 0,
		shownRate = 0,
		yawOff = 0,
		roam = 0,
		blowHeld = false,
		takeOff = nil,
		keyedBefore = {},
		blowLast = 0,
		gaitRatio = 0,
		gaitName = nil,
		gaitSince = 0,
		gaitStill = 0,
		drawnYaw = nil,
		actionRun = nil,
		actionSeen = 0,
		actionIsRun = false,
		actionWLast = 0,
		fadeRun = nil,
		fadeAt = 0,
		fadeIsRun = false,
		rootX = 0,
		rootZ = 0,
		rootYaw = 0,
		track = {},
		pins = {},
		slips = {},
		steps = {},
	}
end

---------------------------------------------------------------- locomotion

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The share of a swing's ground covered at `q` (0..1): the foot starts and stops at rest, its speed eased up over the
-- first quarter and down over the last (the integral of that speed, so the swing's peak speed is only 4/3 of its mean).
local function swingShare(q: number): number
	local a = 0.25
	local x = math.clamp(q, 0, 1)
	local w
	if x < a then
		local u = x / a
		w = a * (u * u * u - u * u * u * u / 2)
	elseif x <= 1 - a then
		w = a / 2 + (x - a)
	else
		local u = (1 - x) / a
		w = (1 - a) - a * (u * u * u - u * u * u * u / 2)
	end
	return w / (1 - a)
end

-- Control names per leg (no string building per frame).
local LEG_KEYS: { [string]: { k: string, x: string, y: string, z: string, l: string } } = {}
for _, leg in { "FL", "FR", "HL", "HR" } do
	LEG_KEYS[leg] = { k = leg .. "k", x = leg .. "x", y = leg .. "y", z = leg .. "z", l = leg .. "l" }
end
-- A gait forced by an action, as weights.
local FORCED: { [string]: { [string]: number } } = {
	walk = { walk = 1, trot = 0, gallop = 0 },
	trot = { walk = 0, trot = 1, gallop = 0 },
	gallop = { walk = 0, trot = 0, gallop = 1 },
}
-- The body's own motion in a gait, kept under an action that runs the gait (a charge).
local GAIT_BODY = { "by", "bpitch", "broll", "sflex", "syaw" }
-- The tail's per-bone yaw (no string building per frame).
local TAIL_Y = { "tY1", "tY2", "tY3", "tY4", "tY5", "tY6", "tY7", "tY8" }
local TAIL_P = { "tP1", "tP2", "tP3", "tP4", "tP5", "tP6", "tP7", "tP8" }
-- The server's gait intents (Logic/MonsterMove: wander, going home, the chase).
local SERVER_GAIT: { [string]: string } = { walk = "walk", trot = "trot", run = "gallop" }

-- The gait weights at `ratio` (speed over leg length): a crossfade band around each threshold.
local function gaitWeights(style: QuadStyles.Style, ratio: number): { [string]: number }
	local t = style.thresholds
	local band = 0.35
	local trot = smooth((ratio - (t.trot - band)) / (2 * band))
	local gallop = smooth((ratio - (t.gallop - band)) / (2 * band))
	return { walk = 1 - trot, trot = trot * (1 - gallop), gallop = gallop }
end

-- One gait's controls at `phase` (0..1).
-- `center`: per leg, where its stance is centred (leg lengths behind the foot's rest point: under the hip or shoulder).
-- `turn`: the body's yaw over one cycle (radians, + to the left), which an `onPrint` gait's planted feet turn against
-- about the root (`skel`: their rest points), so they stay on their prints while the body steers; `still`: it turns on
-- the spot (0..1), so an `onPrint` gait steps in place (the feet lifted and set down, carried round by `turn` alone).
local function gaitControls(
	style: QuadStyles.Style,
	name: string,
	phase: number,
	center: { [string]: number },
	turn: number,
	skel: QuadPose.Skeleton,
	still: number
): Controls
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
	-- body: bob twice a cycle (walk / trot) or the gallop's rise and pitch; carried lower by `drop`
	if name == "gallop" then
		out.by = g.bob * math.cos(2 * math.pi * (phase - 0.9)) - (g.drop or 0)
		out.bpitch = g.pitch * math.cos(2 * math.pi * (phase - 0.15)) - (g.stoop or 0)
		out.sflex = g.flex * math.cos(2 * math.pi * (phase - 0.9)) - g.flex * 0.25
	else
		out.by = -g.bob * math.cos(2 * w) - (g.drop or 0)
		out.bpitch = -(g.stoop or 0)
		out.broll = g.roll * math.sin(w)
		out.syaw = g.spineYaw * math.sin(w)
	end
	-- the feet: planted in stance (the solver keeps them on the ground while the body moves over them), lifted along a
	-- path to the next touchdown in swing (leaving and landing at the ground speed); plantigrade feet flat until the
	-- heel peels off late in the stance
	if g.plant or g.level then
		for leg, offset in g.foot do
			local front = string.sub(leg, 1, 1) == "F"
			local duty = if front then (g.dutyFront or g.duty) else g.duty
			local p = (phase - offset) % 1
			local keys = LEG_KEYS[leg]
			local stance = p < duty
			local s = p / duty
			local q = (p - duty) / (1 - duty)
			if g.plant then
				local D = duty * g.k
				local c0 = center[leg] or 0
				if stance then
					local go = if g.onPrint then 1 - still else 1
					out[keys.y], out[keys.z] = 0, c0 + (-D / 2 + D * s) * go
				else
					local lift = if front then (g.liftFront or g.lift or 0.12) else (g.lift or 0.12)
					if g.onPrint then
						-- on the ground the foot keeps still while the body goes on (R: the body's travel over the
						-- swing), so it lifts and lands without skimming; between, it overtakes the body by the whole
						-- stride (D + R)
						local R = D * (1 - duty) / duty
						local z = (D / 2 + R * q - (D + R) * swingShare(q)) * (1 - still)
						out[keys.y], out[keys.z] = lift * math.sin(math.pi * q), c0 + z
					else
						-- Hermite from the lift-off point to the touchdown point, leaving and landing with part of
						-- the stance's speed
						local m = D * math.min((1 - duty) / duty, 1) * 0.6
						local q2, q3 = q * q, q * q * q
						local z = (2 * q3 - 3 * q2 + 1) * (D / 2)
							+ (q3 - 2 * q2 + q) * m
							+ (-2 * q3 + 3 * q2) * (-D / 2)
							+ (q3 - q2) * m
						out[keys.y], out[keys.z] = lift * math.sin(math.pi * q ^ 0.76), c0 + z
					end
				end
				out[keys.k] = 1
				if g.onPrint and turn ~= 0 then
					-- the yaw since mid-stance (the feet land turned ahead into the turn, leave turned behind it):
					-- a point on the ground turns by -yaw about the root in the body's frame
					local yaw = turn * duty * (if stance then s - 0.5 else 0.5 - swingShare(q))
					local foot = skel.chains[leg].foot
					local L = skel.L
					local fx, fz = foot[1] / L, foot[3] / L + out[keys.z]
					out[keys.x] = -fz * yaw
					out[keys.z] += fx * yaw
				end
			end
			if g.level then
				local into = g.levelIn or 0.4
				out[keys.l] = g.level
					* (if stance then 1 - smooth((s - 0.6) / 0.4) else smooth((q - (1 - into)) / into))
			end
		end
	end
	if name ~= "gallop" then
		-- a heavy walk: the roll turns about the feet that bear the weight, the head sways with the steps
		if g.rollPivot then
			out.bpx = -g.rollPivot * math.sin(w)
		end
		if g.headSway then
			out.hyaw = g.headSway * math.sin(w - 0.8)
		end
	end
	-- the head keeps level against the body's pitch (a mount's gait with `headLevel`: that share of the pitch and of
	-- the spine's flex, so a lion's head stays steady over its bounding gallop); a horse's head nods with the stride
	-- (`nod`, lowest at phase `nodAt`: twice a cycle in a walk or trot, once in a gallop); the tail
	if g.headLevel then
		out.npitch = ((out.bpitch or 0) - (out.sflex or 0)) * g.headLevel + g.neck
	else
		out.npitch = (out.bpitch or 0) * 0.8 + g.neck
	end
	if g.nod then
		local beats = if name == "gallop" then 1 else 2
		out.npitch += g.nod * math.cos(2 * math.pi * beats * (phase - (g.nodAt or 0)))
	end
	out.tpitch = g.tail
	-- (a mount's gait) `tailLag`: the wave's lag per bone down the tail; `tailWave`: the tail rising and falling once
	-- a cycle with that lag (a lion's tail following its bounds)
	local lag = g.tailLag or 0.95
	for i = 1, math.min(style.tailBones or 4, #TAIL_Y) do
		out[TAIL_Y[i]] = g.tailSway * math.sin(w - i * lag)
		if g.tailWave then
			out[TAIL_P[i]] = g.tailWave * math.sin(w - i * lag)
		end
	end
	return out
end

---------------------------------------------------------------- pinned feet

-- (a style with `pinFeet`; a real spawn's chase, 2026-10-31: the server moves the root in hops at the chase's speed,
-- which the client sees in network steps, so a stance drawn from the velocity slid the feet a stud or more) a foot the
-- pose holds on the ground is pinned where it came down in the world, whatever the root does; lifted, it eases back
-- onto its gait's path; held down but left more than STEP_FROM off its place (a hop the gait did not keep up with, a
-- stop), it steps there, a couple at a time. The gait's pace is the root's own travel over PACE_WINDOW s (the given
-- speed, if larger, until it has that long a track).
local SPIN_STEP = 1.2 -- radians a cycle of a turn on the spot
local SPIN_RATE = 1.5 -- cycles a second at most (a faster turn is held by the pins and settled by steps)
local PACE_WINDOW = 0.2 -- s of the root's track its pace is read over
local SLIP_TIME = 0.2 -- s a foot let go takes to ease onto its gait's path
local SLIP_FAR = 0.1 -- leg lengths off its path from which a foot let go lifts off its print before it follows it
local STEP_FROM = 0.2 -- leg lengths off its place a pinned foot steps from
local STEP_TIME = 0.24 -- s a step takes
local STEP_LIFT = 0.1 -- leg lengths a step lifts the foot
local STEP_AT_ONCE = 2
local SETTLE_TIME = 0.1 -- s a foot the pose sets down while its ease still lifts it takes to come down onto its pin
local JUMP = 1.2 -- leg lengths the root moves in one frame that are a teleport, not a pace (the client's is 4 studs)
-- (a real spawn's chase, 2026-10-31: the server faces the target in one snap, the Root bone turned 136 degrees in a
-- frame) the body is drawn at a heading that follows the root's within SHOW_FOLLOW per second, at most SHOW_TURN rad/s
local SHOW_FOLLOW = 30
local SHOW_TURN = 6
local BODY_STEP = math.rad(11.5) -- the most the drawn body turns in the world in a frame
-- (the same chase: a blow wound up while the server still closed in, the legs keyed in place under a running root)
-- the root's pace (leg lengths a second) from which an action leaves its legs to the gait, and at which it has
local ROAM_FROM, ROAM_FULL = 0.2, 0.8
local DOWN = 0.03 -- leg lengths over the ground a foot the pose holds still counts as down (a gait fading in or out
-- lifts its feet only that little)

-- Follows the root on the ground; returns the pace (the skeleton's units a second).
local function trackRoot(inst: Instance, input: Input): number
	local L = inst.skel.L
	local at = input.rootAt
	if input.snap or not inst.rootReady then
		inst.rootReady = true
		inst.rootX, inst.rootZ, inst.rootYaw = if at then at[1] else 0, if at then at[2] else 0, if at then at[3] else 0
		inst.track = {}
		inst.pins = {}
		inst.slips = {}
		inst.steps = {}
		inst.shownYaw, inst.shownRate, inst.yawOff, inst.roam = inst.rootYaw, 0, 0, 0
		inst.blowHeld, inst.takeOff, inst.keyedBefore = false, nil, {}
	end
	if not at then
		inst.rootYaw += input.yawRate * input.dt
		inst.rootX -= math.sin(inst.rootYaw) * input.speed * input.dt
		inst.rootZ -= math.cos(inst.rootYaw) * input.speed * input.dt
		return input.speed
	end
	local track = inst.track
	if (at[1] - inst.rootX) ^ 2 + (at[2] - inst.rootZ) ^ 2 > (JUMP * L) ^ 2 then
		-- (a teleport: the pose's own flight to it ends at once, which is no move of a held foot)
		table.clear(track)
		inst.keyedBefore = {}
	end
	inst.rootX, inst.rootZ, inst.rootYaw = at[1], at[2], at[3]
	table.insert(track, { input.now, at[1], at[2] })
	while #track > 2 and input.now - track[2][1] >= PACE_WINDOW do
		table.remove(track, 1)
	end
	local first, last = track[1], track[#track]
	local span = last[1] - first[1]
	if span < 0.05 then
		return input.speed
	end
	local travelled = math.sqrt((last[2] - first[2]) ^ 2 + (last[3] - first[3]) ^ 2) / span
	-- (the given speed, the server's velocity, only while the track is short: under the chase's bursts it reads the
	-- run's full speed or none, a real spawn's chase 2026-11-01)
	if span < PACE_WINDOW * 0.75 then
		return math.max(input.speed, travelled)
	end
	return travelled
end

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- The heading the body is drawn at: it follows the root's (a server's snap is turned over a few frames, not one).
local function showYaw(inst: Instance, input: Input)
	local dt = input.dt
	if input.snap or dt <= 0 then
		if input.snap then
			inst.shownYaw, inst.shownRate = inst.rootYaw, 0
		end
	else
		local d = wrapAngle(inst.rootYaw - inst.shownYaw)
		local turn = math.clamp(d * (1 - math.exp(-SHOW_FOLLOW * dt)), -SHOW_TURN * dt, SHOW_TURN * dt)
		inst.shownYaw = wrapAngle(inst.shownYaw + turn)
		inst.shownRate = approach(inst.shownRate, turn / dt, 15, dt)
	end
	inst.yawOff = wrapAngle(inst.shownYaw - inst.rootYaw)
end

-- Pins the feet the controls hold on the ground (plant 1, no lift) where they came down in the world. `blow`: the
-- weight with which a keyed action keys the legs: as it takes them over, the feet go from their pins to its places
-- (no step of the pins' own starts); once it has (a real spawn's chase, 2026-10-31: the server turned and moved the
-- root under a blow, its keyed feet slid with it), they are pinned and step as in the gait. `holds`: the blow holds its
-- last pose (a death): its feet stay on its places, no step.
local function pinFeet(inst: Instance, controls: Controls, now: number, blow: number, holds: boolean)
	local skel = inst.skel
	local L = skel.L
	local c, s = math.cos(inst.rootYaw), math.sin(inst.rootYaw)
	local function toModel(x: number, z: number): (number, number)
		local dx, dz = x - inst.rootX, z - inst.rootZ
		return dx * c - dz * s, dx * s + dz * c
	end
	local function toWorld(x: number, z: number): (number, number)
		return inst.rootX + x * c + z * s, inst.rootZ - x * s + z * c
	end
	-- the ease of a foot let go at (x, z) in the world off its path's point (px, pz) in the root's frame
	local function letGo(x: number, z: number, px: number, pz: number): { number }
		local tx, tz = toWorld(px, pz)
		if (x - tx) ^ 2 + (z - tz) ^ 2 > (SLIP_FAR * L) ^ 2 then
			return { x, z, now, 1 }
		end
		return { x - tx, z - tz, now, 0 }
	end
	-- where the pose puts each foot (the action's or the gait's place, `keyed`; with the ease off a pin it let go,
	-- `place`) and whether it holds it down
	-- (the body drawn turned by `yawOff` about its root bone: the pose's places turn with it; a step goes where they
	-- will be as it lands, `ahead`)
	local co, so = math.cos(inst.yawOff), math.sin(inst.yawOff)
	local offLand = math.sign(inst.yawOff) * math.max(0, math.abs(inst.yawOff) - SHOW_TURN * STEP_TIME)
	local ca, sa = math.cos(offLand), math.sin(offLand)
	local pivot = skel.bones[skel.rig.body].pos
	local ox, oz = pivot[1] + (controls.bx or 0) * L, pivot[3] + (controls.bz or 0) * L
	local keyed: { [string]: { number } } = {}
	local ahead: { [string]: { number } } = {}
	local raw: { [string]: { number } } = {}
	local place: { [string]: { number } } = {}
	local down: { [string]: boolean } = {}
	local lifts: { [string]: number } = {}
	local stepping = 0
	for leg, keys in LEG_KEYS do
		local chain = skel.chains[leg]
		if chain then
			local kx = chain.foot[1] + (controls[keys.x] or 0) * L - ox
			local kz = chain.foot[3] + (controls[keys.z] or 0) * L - oz
			local px, pz = ox + kx * co + kz * so, oz - kx * so + kz * co
			keyed[leg] = { px, pz }
			ahead[leg] = { ox + kx * ca + kz * sa, oz - kx * sa + kz * ca }
			raw[leg] = { kx, kz }
			-- (held by a blow, a pinned foot goes with the blow's own moves of it, not with the root's)
			local before = inst.keyedBefore[leg]
			if before and inst.blowHeld and blow > 0.999 and inst.pins[leg] and not inst.steps[leg] then
				local bx = before[3] + before[1] * co + before[2] * so
				local bz = before[4] - before[1] * so + before[2] * co
				local dx, dz = px - bx, pz - bz
				-- (a jump of the place is the end of a flight the pose drew, not a move of the foot)
				if dx * dx + dz * dz < (0.5 * L) ^ 2 then
					local pin = inst.pins[leg]
					pin[1] += dx * c + dz * s
					pin[2] += -dx * s + dz * c
				end
			end
			inst.keyedBefore[leg] = { kx, kz, ox, oz }
			down[leg] = (controls[keys.k] or 0) > 0.98 and (controls[keys.y] or 0) < DOWN
			local lift = 0
			local slip = inst.slips[leg]
			if slip then
				local k = (now - slip[3]) / SLIP_TIME
				if k < 1 and slip[5] then
					lift = slip[5] * (1 - smooth(k))
				end
				if k >= 1 then
					inst.slips[leg] = nil
				elseif slip[4] == 0 then
					-- a little off its path: the offset (in the world) fades over the gait's own swing
					local w = 1 - smooth(k)
					local sx, sz = slip[1] * w, slip[2] * w
					px += sx * c - sz * s
					pz += sx * s + sz * c
				else
					-- far off it (a hop, a stop): from where it left the ground onto its path in the world, so it
					-- lifts off its print first whatever the root does, carried as high as a step for one as long (a
					-- gait barely under way lifts a foot only a little)
					local tx, tz = toWorld(px, pz)
					local e = smooth(k)
					px, pz = toModel(slip[1] + (tx - slip[1]) * e, slip[2] + (tz - slip[2]) * e)
					local far = math.clamp(math.sqrt((tx - slip[1]) ^ 2 + (tz - slip[2]) ^ 2) / (STEP_FROM * L), 0, 1)
					lift = math.max(lift, STEP_LIFT * far * math.sin(math.pi * math.max(k, 0)))
				end
			end
			place[leg] = { px, pz }
			lifts[leg] = lift
			if inst.steps[leg] then
				stepping += 1
			end
		end
	end
	if blow <= 0 then
		inst.blowHeld = false
		inst.takeOff = nil
	end
	local taking = blow > 0 and (holds or not inst.blowHeld)
	-- (a blow that gives the legs back before it has them, to a gait that turns it on the spot: the feet are pinned
	-- where it has brought them)
	-- (nor does it keep them while it no longer gains on the gait: a blow under a roam it shares the legs with tops out
	-- short of all of them, and its pins held there dragged behind the running body until it ended; a real spawn's
	-- chase, 2026-11-01)
	local handoff = taking and not holds and (blow > 0.999 or blow < inst.blowLast + 1e-4)
	inst.blowLast = blow
	-- (as a blow takes the feet over, its places are kept at the drawn heading the body will have by then: the turn
	-- of a server's snap does not drag them round)
	local takeOff = inst.takeOff
	if taking and not takeOff then
		takeOff = offLand
		inst.takeOff = offLand
	end
	local ct, st = math.cos(takeOff or 0), math.sin(takeOff or 0)
	local settle = blow <= 0 or (inst.blowHeld and not holds)
	-- the pinned feet left furthest off their places step first (not while a blow takes them over)
	if settle then
		local behind: { { leg: string, off: number } } = {}
		for leg, p in ahead do
			local pin = inst.pins[leg]
			if pin and down[leg] and not inst.steps[leg] then
				local hx, hz = toModel(pin[1], pin[2])
				local off = math.sqrt((hx - p[1]) ^ 2 + (hz - p[2]) ^ 2)
				if off > STEP_FROM * L then
					table.insert(behind, { leg = leg, off = off })
				end
			end
		end
		table.sort(behind, function(a, b)
			return a.off > b.off
		end)
		for _, item in behind do
			if stepping >= STEP_AT_ONCE then
				break
			end
			local leg = item.leg
			local pin = inst.pins[leg]
			-- (a foot still settling onto its pin keeps that lift as it steps on)
			inst.steps[leg] = { pin[1], pin[2], now, pin[3] or 0, pin[4] or 0 }
			inst.pins[leg] = nil
			stepping += 1
		end
	end
	for leg, p in place do
		local keys = LEG_KEYS[leg]
		local foot = skel.chains[leg].foot
		local px, pz = p[1], p[2]
		local lift = lifts[leg]
		local pin, step = inst.pins[leg], inst.steps[leg]
		if step then
			local k = math.min((now - step[3]) / STEP_TIME, 1)
			local tx, tz = toWorld(ahead[leg][1], ahead[leg][2])
			-- up off its print first, over the spot by four fifths of the step, then straight down onto it (the spot kept
			-- from there)
			if step[6] then
				tx, tz = step[6], step[7]
			elseif k >= 0.8 then
				step[6], step[7] = tx, tz
			end
			local e = smooth((k - 0.1) / 0.7)
			local wx, wz = step[1] + (tx - step[1]) * e, step[2] + (tz - step[2]) * e
			local mx, mz = toModel(wx, wz)
			if not down[leg] then
				-- the pose lifts it itself: from here onto its path, the step's lift easing out
				local slip = letGo(wx, wz, px, pz)
				slip[5] = STEP_LIFT * math.sin(math.pi * k)
				inst.slips[leg] = slip
				inst.steps[leg] = nil
				lift = math.max(lift, slip[5])
			elseif k >= 1 then
				inst.pins[leg] = { tx, tz }
				inst.steps[leg] = nil
			else
				lift = math.max(lift, STEP_LIFT * math.sin(math.pi * k))
			end
			local settled = (now - (step[5] or 0)) / SETTLE_TIME
			if (step[4] or 0) > 0 and settled < 1 then
				lift = math.max(lift, step[4] * (1 - smooth(settled)))
			end
			px, pz = mx, mz
		elseif pin then
			local hx, hz = toModel(pin[1], pin[2])
			if pin[3] then
				local k = (now - pin[4]) / SETTLE_TIME
				if k < 1 then
					lift = math.max(lift, pin[3] * (1 - smooth(k)))
				end
			end
			if not down[leg] and settle then
				-- lifted: from the pin onto the gait's path (as a blow takes it over, the blow takes it off the pin)
				inst.slips[leg] = letGo(pin[1], pin[2], px, pz)
				inst.pins[leg] = nil
			end
			px, pz = hx, hz
		elseif down[leg] then
			-- (a foot set down while its ease still lifts it settles onto the pin, not in one frame)
			local x, z = toWorld(px, pz)
			inst.pins[leg] = if lift > 0.005 then { x, z, lift, now } else { x, z }
			inst.slips[leg] = nil
		end
		if taking then
			-- a blow keys its feet: they go from their pins to its places as it takes over (early in its blend, so the
			-- blow's own first moves are not crowded into its end), lifted as a step when that is far (a real spawn's
			-- chase, 2026-10-31: they slid there), and once it has, the pins move there
			local r = raw[leg]
			local a = { ox + r[1] * ct + r[2] * st, oz - r[1] * st + r[2] * ct }
			local f = math.sqrt(blow)
			local far = math.sqrt((a[1] - px) ^ 2 + (a[2] - pz) ^ 2) / (STEP_FROM * L)
			-- (as a step: easing off the pin and down onto the place)
			local e = smooth(f)
			px, pz = px + (a[1] - px) * e, pz + (a[2] - pz) * e
			lift *= 1 - blow
			if far > 0.25 and blow < 0.999 then
				lift = math.max(lift, STEP_LIFT * math.min(far, 1) * math.sin(math.pi * f))
			end
			if handoff and inst.pins[leg] then
				if down[leg] then
					local x, z = toWorld(px, pz)
					inst.pins[leg] = if lift > 0.005 then { x, z, lift, now } else { x, z }
				else
					inst.pins[leg] = nil
				end
			end
		end
		if lift > 0 then
			controls[keys.y] = math.max(controls[keys.y] or 0, lift)
		end
		controls[keys.x] = (px - foot[1]) / L
		controls[keys.z] = (pz - foot[3]) / L
	end
	if handoff then
		inst.blowHeld = true
	end
end

-- The gait the server's intent asks for, a step down when the pace is too slow for it (a slowed chase trots); nil
-- without an intent the style has. `held`: the gait it gave last, which holds on until the pace is GAIT_HOLD of its
-- edge past it (a real spawn's chase, 2026-11-01: the server's bursts of the run's speed flipped a dragon between trot
-- and gallop a few times a second, the two gaits' feet ever half up, one fore paw never down).
local GAIT_HOLD = 0.15
-- the rates the pace the intent is stepped down by follows the pace at, up and down
local GAIT_UP, GAIT_DOWN = 6, 2
-- (Studio, 2026-11-01: a lone trot in a gallop round the server's halts) a gait the intent gives is stepped down from
-- only once it has held GAIT_DWELL s, and a halt shorter than that keeps it and its pace
local GAIT_DWELL = 0.6
local GAIT_RANK: { [string]: number } = { walk = 1, trot = 2, gallop = 3 }
local function serverGait(style: QuadStyles.Style, gait: string?, ratio: number, held: string?): string?
	local name = if gait then SERVER_GAIT[gait] else nil
	if not name or not style.gaits[name] then
		return nil
	end
	local t = style.thresholds
	local gallopAt = 0.7 * t.gallop * (if held == "gallop" then 1 - GAIT_HOLD else 1 + GAIT_HOLD)
	local trotAt = 0.6 * t.trot * (if held == "walk" then 1 + GAIT_HOLD else 1 - GAIT_HOLD)
	if held == nil then
		gallopAt, trotAt = 0.7 * t.gallop, 0.6 * t.trot
	end
	if name == "gallop" and ratio < gallopAt then
		name = "trot"
	end
	if name == "trot" and ratio < trotAt then
		name = "walk"
	end
	return if style.gaits[name] then name else nil
end

-- `forced`: the gait an action runs (blended in fast); `extra`: ground speed of a flight the pose draws itself.
local function locomotion(inst: Instance, input: Input, forced: string?, extra: number): Controls
	local style = inst.style
	local L = inst.skel.L
	local dt = input.dt
	local speed = input.speed + extra
	-- (a style's `stepFrom`: a dragon steps at any crawl rather than glide on its planted feet)
	local stepFrom = (style.stepFrom or 0.3) * L
	local turning = speed < stepFrom and math.abs(input.yawRate) > 1
	local moving = speed >= stepFrom
	local ratio = speed / L
	local force = if forced and style.gaits[forced] then FORCED[forced] else nil
	if not style.serverGait or force or input.snap then
		inst.gaitName = nil
	end
	if input.snap then
		inst.gaitRatio, inst.gaitStill = ratio, 0
	end
	if style.serverGait and not force then
		if moving then
			inst.gaitStill = 0
			local held = inst.gaitName
			inst.gaitRatio = approach(inst.gaitRatio, ratio, if ratio > inst.gaitRatio then GAIT_UP else GAIT_DOWN, dt)
			local name = serverGait(style, input.gait, inst.gaitRatio, held)
			local up = name ~= nil and held ~= nil and (GAIT_RANK[name] or 0) > (GAIT_RANK[held] or 0)
			if name == nil or held == nil or up or input.now - inst.gaitSince >= GAIT_DWELL then
				if name ~= held then
					inst.gaitSince = input.now
				end
				inst.gaitName = name
			end
		else
			inst.gaitStill += dt
			if inst.gaitStill >= GAIT_DWELL then
				inst.gaitName = nil
				inst.gaitRatio = 0
			end
		end
	end
	local intentName = if moving or not turning then inst.gaitName else nil
	local intent = if intentName then FORCED[intentName] else nil
	local targetW = force or intent or gaitWeights(style, if turning then 0.8 else ratio)
	-- (planted feet step at least half a stride: the cadence below makes their stance keep the ground's pace)
	local moveTarget = if moving
		then math.max(math.clamp(ratio / 0.6, 0, 1), if inst.planted then 0.5 else 0)
		elseif turning then 0.7
		else 0
	if input.snap then
		inst.weights = table.clone(targetW)
		inst.move = moveTarget
	else
		local rate = if force then 25 else 6
		for name in style.gaits do
			inst.weights[name] = approach(inst.weights[name] or 0, targetW[name] or 0, rate, dt)
		end
		inst.move = approach(inst.move, moveTarget, if force then 25 else 8, dt)
	end
	local k = 0
	for name, w in inst.weights do
		k += style.gaits[name].k * w
	end
	-- planted feet: the stride shrinks with `move` (slow steps are short ones), so the cadence makes up for it and the
	-- foot in stance still goes back at the ground speed
	local stride = if inst.planted then math.max(inst.move, 0.5) else 1
	-- (pinned feet, 2026-10-31) a turn on the spot steps in place, SPIN_STEP radians a cycle
	local spin = turning and style.pinFeet == true
	local ground = if moving then speed elseif turning then math.abs(input.yawRate) * L * 0.4 else 0
	if spin then
		ground = math.min(math.abs(input.yawRate) / SPIN_STEP, SPIN_RATE) * k * L * stride
	end
	local cadence = ground / math.max(0.2, k * L * stride)
	inst.phase = (inst.phase + dt * cadence) % 1
	-- the yaw over a cycle while it runs on (a chase steers) or turns on the spot with pinned feet
	local turnTarget = if (moving or spin) and cadence > 0.05 then math.clamp(input.yawRate / cadence, -1.2, 1.2) else 0
	if input.snap then
		inst.spin, inst.turn = if spin then 1 else 0, turnTarget
	else
		inst.spin = approach(inst.spin, if spin then 1 else 0, 8, dt)
		inst.turn = approach(inst.turn, turnTarget, 8, dt)
	end
	local turn = inst.turn
	local out: Controls = {}
	if inst.move > 0.005 then
		for name, w in inst.weights do
			if w > 0.005 then
				addAll(
					out,
					gaitControls(style, name, inst.phase, inst.center, turn, inst.skel, inst.spin),
					w * inst.move
				)
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
	-- a heavy quadruped stands on planted feet (the weight shift and the breath bend its legs)
	if style.ground then
		addAll(out, style.ground, still)
	end
	-- the tail
	add(out, "tpitch", style.idle.tail * still)
	for i = 1, math.min(style.tailBones or 4, #TAIL_Y) do
		add(out, TAIL_Y[i], 0.14 * math.sin(t * 2 * math.pi * 0.25 - i * 0.7) * still)
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
	-- a trunk hangs a little curled and drifts; big ears fan now and then
	if style.trunk then
		add(out, "kcurl", 0.12 + 0.05 * math.sin(t * 2 * math.pi * 0.11))
		add(out, "kside", 0.05 * math.sin(t * 2 * math.pi * 0.17))
	end
	local flap = style.earFlap
	if flap then
		local x = t % flap.every
		local e = if x < 1.6 then math.sin(math.pi * x / 1.6) ^ 2 else 0
		add(out, "earL", flap.amp * e)
		add(out, "earR", flap.amp * e)
	end
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
local MIRRORED: { [string]: boolean } = {
	hyaw = true,
	nyaw = true,
	hroll = true,
	byaw = true,
	broll = true,
	syaw = true,
	bx = true,
	bpx = true,
	kside = true,
}
-- A dragon's wings swap sides on a mirrored run (Logic/DragonMotion: the left wing's keys become the right one's).
local WING_SWAP: { { string } } = {}
for letter in string.gmatch("estfhbwpqo", ".") do
	table.insert(WING_SWAP, { "wL" .. letter, "wR" .. letter })
end

local function actionControls(style: QuadStyles.Style, run: ActionRun, t: number): Controls?
	local action = style.actions[run.name]
	if not action then
		return nil
	end
	local first = action.keys[1]
	local start = if first and first.u == 0 and first.seg == "A" then first.pose else style.stance
	local controls = MotionTimeline.at(action, run.hit, t, start)
	if run.mirror and not action.sided then
		controls = table.clone(controls)
		for key in MIRRORED do
			if controls[key] then
				controls[key] = -controls[key]
			end
		end
		for _, pair in WING_SWAP do
			local l, r = controls[pair[1]], controls[pair[2]]
			if l or r then
				-- (a side without the key keeps none: 0)
				controls[pair[1]], controls[pair[2]] = r or 0, l or 0
			end
		end
	end
	return controls
end

-- Stun and freeze ends (server time) from the Effects text, parsed only when it changed (Logic/FlyerMotion's rule).
local function readEffects(inst: Instance, raw: string?)
	if raw == inst.effects then
		return
	end
	inst.effects = raw
	inst.stunEnds, inst.freezeEnds = 0, 0
	if type(raw) ~= "string" then
		return
	end
	for kind, ends in string.gmatch(raw, "(%a+):([%d%.]+)") do
		local t = tonumber(ends) or 0
		if kind == "stun" then
			inst.stunEnds = math.max(inst.stunEnds, t)
		elseif kind == "freeze" then
			inst.freezeEnds = math.max(inst.freezeEnds, t)
		end
	end
end

local FADE_TIME = 0.2 -- s an action that ends or is replaced while it still keys the body takes to fade out

-- One keyed action over `controls` (`isRun`: the game's, not a fidget), its weight eased in from `seen` (when the
-- pose first had it) and scaled by `scale`: the blended controls, its weight, the weight it keys the legs with (pinned
-- feet go to its places) and whether it holds them.
local function keyAction(
	inst: Instance,
	controls: Controls,
	playing: ActionRun,
	isRun: boolean,
	now: number,
	seen: number,
	scale: number
): (Controls, number, number, boolean)
	local style = inst.style
	local L = inst.skel.L
	local actionW, legBlow, legHolds = 0, 0, false
	local action = style.actions[playing.name]
	local t = now - playing.start
	local length = MotionTimeline.length(action, playing.hit)
	local hold = action.hold or (isRun and playing.hold == true)
	if t >= 0 and (t <= length or hold) then
		local keyed = actionControls(style, playing, math.min(t, length)) :: Controls
		-- the gather trembles more and more toward the strike
		if action.tremble and action.tremble > 0 then
			local p = MotionTimeline.gather(action, playing.hit, t)
			-- (only the gather: it settles over the first 0.08 s of the strike instead of shaking on through the
			-- blow and the recovery, which shook a planted heavy body's legs; studio review 2026-10-31)
			local gatherEnd = playing.hit - math.min(action.strike, playing.hit * 0.7)
			local amp = action.tremble * p * p * math.clamp(1 - (t - gatherEnd) / 0.08, 0, 1)
			keyed = table.clone(keyed)
			keyed.bpitch = (keyed.bpitch or 0) + amp * math.sin(now * 2 * math.pi * 18)
			keyed.broll = (keyed.broll or 0) + amp * 0.7 * math.sin(now * 2 * math.pi * 15 + 1.3)
		end
		local travel = keyed.travel
		if travel and playing.reach and action.travel then
			-- the flight ends where the server's teleport puts the root: in the ability's circle
			-- (Entities/Monster.stepCast; studio review 2026-10-31: a landing a body length short of it popped the
			-- body forward by that much at the teleport, the planted hind feet skidding 3.5 studs)
			local rx, rz = playing.reach[1], playing.reach[3]
			keyed = table.clone(keyed)
			keyed.bx = (keyed.bx or 0) + rx * travel / L
			keyed.bz = (keyed.bz or 0) + rz * travel / L
			-- planted feet land with the body
			for _, keys in LEG_KEYS do
				if keyed[keys.k] then
					keyed[keys.x] = (keyed[keys.x] or 0) + rx * travel / L
					keyed[keys.z] = (keyed[keys.z] or 0) + rz * travel / L
				end
			end
		end
		local arc = keyed.arc
		if arc and action.travel then
			-- the flight's height on the server's Dash arc: a quarter of its length, within 1-3 leg lengths (a hop
			-- in place without a flight)
			local flight = 0
			if playing.reach then
				local rx, rz = playing.reach[1], playing.reach[3]
				flight = math.sqrt(rx * rx + rz * rz) / L
			end
			local height = if flight > 0 then math.clamp(0.25 * flight, 1, 3) else 0.3
			keyed = table.clone(keyed)
			keyed.by = (keyed.by or 0) + arc * height
			-- the feet the action holds on targets ride the height over a leg length with the body, so a long
			-- flight's legs keep their keyed tuck and reach instead of hanging straight under it (studio review
			-- 2026-10-31: the hind legs snapped out of and back into reach at the take-off and the landing)
			local over = height - 1
			if over > 0 then
				for _, keys in LEG_KEYS do
					if keyed[keys.k] then
						keyed[keys.y] = (keyed[keys.y] or 0) + arc * over
					end
				end
			end
		end
		-- a heavy body (planted feet) takes a little longer to leave its gait (eased in from when it was first seen: an
		-- action started late, a strike-now blow, does not come in at once)
		local w = math.min(1, math.min(t, now - seen) / (if inst.planted then 0.2 else 0.08))
		if not hold then
			w = math.min(w, math.max(0, (length - t) / 0.18))
		end
		w = MotionTimeline.ease("inout", w) * scale
		actionW = w
		-- an action keys the whole body; moving, the legs keep the gait (unless it keys them fully: then while the
		-- root really runs, a style with pinned feet, but for a pose it holds, a death)
		local legW = if action.full then w * (1 - (if hold then 0 else inst.roam)) else w * (1 - inst.move)
		local blended = lerpControls(controls, keyed, w)
		for key, v in keyed do
			local leg = string.match(key, "^[FH][LR][ufpolkxyz]$")
			if leg then
				blended[key] = (controls[key] or 0) + (v - (controls[key] or 0)) * legW
				-- (a weight left by rounding, w times a roam a hair under 1, is none: it held the pins off their
				-- steps through a whole blow while the body ran on; a real spawn's chase, 2026-11-01)
				legBlow, legHolds = if legW > 1e-3 then legW else 0, hold
			end
		end
		if inst.planted then
			-- the gait's legs and planted feet leave with the legs' weight, not the whole action's (a charge
			-- gallops under its keyed head and body)
			for key, v in controls do
				if keyed[key] == nil and string.match(key, "^[FH][LR][ufpolkxyz]$") then
					blended[key] = v * (1 - legW)
				end
			end
		end
		if action.gait then
			-- the gait the action runs keeps its body motion (bob, pitch, flex) under the keyed pose
			for _, key in GAIT_BODY do
				local v = controls[key]
				if v then
					blended[key] = (blended[key] or 0) + v * w * inst.move
				end
			end
		end
		controls = blended
		controls.travel = nil :: any
		controls.arc = nil :: any
	end
	return controls, actionW, legBlow, legHolds
end

function QuadMotion.step(inst: Instance, input: Input): QuadPose.Posed
	local style = inst.style
	local skel = inst.skel
	local now = input.now
	local dt = input.dt
	local L = skel.L
	-- the server's stun and freeze (a style with a dazed pose): frozen, the pose holds
	local stunned = false
	if style.stun then
		readEffects(inst, input.effects)
		local serverNow = input.serverNow or 0
		if (input.frozen == true or serverNow < inst.freezeEnds) and inst.posed then
			inst.lastTime = now
			return inst.posed :: QuadPose.Posed
		end
		stunned = input.stunned == true or serverNow < inst.stunEnds
	end
	-- (pinned feet) the root's place, and the pace from its own travel
	if style.pinFeet then
		local pace = trackRoot(inst, input)
		showYaw(inst, input)
		input = table.clone(input)
		input.speed = pace
		-- the body turns at its drawn heading's rate, and looks from it
		input.yawRate = inst.shownRate
		local look = input.look
		if look and inst.yawOff ~= 0 then
			local co, so = math.cos(-inst.yawOff), math.sin(-inst.yawOff)
			input.look = { look[1] * co + look[3] * so, look[2], -look[1] * so + look[3] * co }
		end
		-- (the pace is the root's travel over PACE_WINDOW: it eases itself)
		inst.roam = math.clamp((pace / L - ROAM_FROM) / (ROAM_FULL - ROAM_FROM), 0, 1)
	end
	-- 1. locomotion (an action may run a gait: a charge gallops; a flight the pose draws itself is ground speed)
	local run = input.action
	local forced: string? = nil
	local extra = 0
	local runAction = if run then style.actions[run.name] else nil
	if run and runAction and runAction.gait then
		-- from the strike (the dash) to the end of the follow-through: the gather keeps the pace it had
		local t = now - run.start
		local strikeAt = run.hit - math.min(runAction.strike, run.hit * 0.7)
		if t >= strikeAt and t <= run.hit + runAction.follow then
			forced = runAction.gait
			local reach = run.reach
			if reach and runAction.travel and dt > 0 then
				local d = math.sqrt(reach[1] * reach[1] + reach[3] * reach[3])
				local a = actionControls(style, run, t)
				local b = actionControls(style, run, math.max(0, t - dt))
				local da = if a then a.travel or 0 else 0
				local db = if b then b.travel or 0 else 0
				extra = math.abs(da - db) * d / dt
			end
		end
	end
	local controls = locomotion(inst, input, forced, extra)
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
	-- a dragon's wings at rest, the gallop's wingbeat, the tail tip's flicks
	local dragon = inst.dragon
	if dragon then
		local gallop = (inst.weights.gallop or 0) * inst.move
		DragonMotion.base(dragon, controls, now, gallop, inst.phase, 1 - inst.move, 1 - inst.combat)
	end
	-- fidgets when idle, alone and still
	local busy = run ~= nil
		and style.actions[run.name] ~= nil
		and now - run.start < MotionTimeline.length(style.actions[run.name], run.hit)
	if busy then
		inst.lastAction = now
	end
	local fidget = inst.fidget
	-- (2026-11-01, a mount standing under its rider played one fidget and then none: a played one was never let go)
	-- a fidget that has ended makes way for the next one, every `fidgetEvery` s as long as it stands
	local fidgetAction = if fidget then style.actions[fidget.name] else nil
	if
		fidget
		and (
			busy
			or input.combat
			or inst.move > 0.2
			or not fidgetAction
			or now - fidget.start > MotionTimeline.length(fidgetAction, fidget.hit)
		)
	then
		inst.fidget = nil
		fidget = nil
	end
	if
		not fidget
		and not busy
		and not stunned
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
	local legBlow = 0 -- how much it keys the legs (pinned feet go to its places)
	local legHolds = false
	local playing = if run and style.actions[run.name] then run else fidget
	-- (Studio, 2026-11-01: the first bite cut the alert in one frame, the Root bone turned 13.8 degrees) an action that
	-- ends or is replaced while it still keys the body fades out over FADE_TIME s on its own timeline
	if playing ~= inst.actionRun then
		local before = inst.actionRun
		if before and inst.actionWLast > 0.01 and style.actions[before.name] then
			inst.fadeRun, inst.fadeAt, inst.fadeIsRun = before, now, inst.actionIsRun
		end
		inst.actionRun, inst.actionSeen, inst.actionIsRun = playing, now, playing ~= nil and playing == run
	end
	if input.snap then
		-- (a pose set at once: the action as it stands)
		inst.actionSeen, inst.fadeRun = -math.huge, nil
	end
	local fadeRun = inst.fadeRun
	if fadeRun then
		local k = (now - inst.fadeAt) / FADE_TIME
		if k >= 1 or k < 0 then
			inst.fadeRun = nil
		else
			controls, actionW, legBlow, legHolds =
				keyAction(inst, controls, fadeRun, inst.fadeIsRun, now, -math.huge, 1 - smooth(k))
		end
	end
	inst.actionWLast = 0
	if playing then
		local keyed, w, legs, holds = keyAction(inst, controls, playing, playing == run, now, inst.actionSeen, 1)
		controls = keyed
		inst.actionWLast = w
		actionW = math.max(actionW, w)
		if legs > 0 then
			legBlow, legHolds = math.max(legBlow, legs), holds
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
	-- the server's stun: the dazed pose, the head wobbling
	if style.stun then
		local target = if stunned then 1 else 0
		inst.stun = if input.snap then target else approach(inst.stun, target, 5, dt)
		if inst.stun > 0.005 then
			local k = inst.stun * (1 - 0.6 * actionW)
			addAll(controls, style.stun, k)
			local t = now + inst.seed * 2.3
			add(controls, "nyaw", 0.14 * math.sin(t * 2 * math.pi * 0.42) * k)
			add(controls, "hroll", 0.12 * math.sin(t * 2 * math.pi * 0.55 + 1) * k)
			add(controls, "broll", 0.025 * math.sin(t * 2 * math.pi * 0.42 + 0.5) * k)
		end
	end
	-- the lean into turns
	inst.yawEase = if input.snap then input.yawRate else approach(inst.yawEase, input.yawRate, 10, dt)
	local lean = math.clamp(inst.yawEase * 0.25, -0.17, 0.17) * inst.move
	add(controls, "broll", -lean)
	add(controls, "syaw", math.clamp(inst.yawEase * 0.12, -0.14, 0.14) * inst.move)
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
	-- 5. the trunk: a pendulum hanging from the face. Its root is carried by the head's turns, the body's roll and
	-- lunges; the tip follows on a soft spring, so it trails, overshoots and swings out
	local trunk = style.trunk
	if trunk then
		local side = ((controls.nyaw or 0) + (controls.hyaw or 0) + (controls.byaw or 0)) * trunk.arm
			+ (controls.broll or 0) * trunk.height
			- (controls.bx or 0)
		local fwd = -(controls.bz or 0) - 0.6 * ((controls.npitch or 0) + (controls.hpitch or 0))
		if input.snap or not inst.trunkReady then
			inst.trunkS, inst.trunkSV, inst.trunkF, inst.trunkFV = side, 0, fwd, 0
			inst.trunkReady = true
		elseif dt > 0 then
			local omega = 2 * math.pi * trunk.hz
			local steps = math.ceil(dt * 60)
			local h = dt / steps
			for _ = 1, steps do
				local aS = omega * omega * (side - inst.trunkS) - 2 * trunk.damp * omega * inst.trunkSV
				inst.trunkSV += aS * h
				inst.trunkS += inst.trunkSV * h
				local aF = omega * omega * (fwd - inst.trunkF) - 2 * trunk.damp * omega * inst.trunkFV
				inst.trunkFV += aF * h
				inst.trunkF += inst.trunkFV * h
			end
		end
		add(controls, "kside", math.clamp((inst.trunkS - side) * trunk.gain, -0.6, 0.6))
		add(controls, "kpitch", math.clamp((inst.trunkF - fwd) * trunk.gain, -0.6, 0.6))
	end
	-- 6. a dragon: the tail's spring, the wings' controls turned into their joints'
	if dragon then
		-- (owner 2026-11-01) in the air (AnimLab `fly`, the attribute Flying): the wings flat out and beating at 1.1 Hz
		if input.flying then
			controls.wo = math.max(controls.wo or 0, 1.7)
			if (controls.flap or 0) < 0.5 then
				controls.flap, controls.beat = 1, now * 1.1
			end
		end
		DragonMotion.tail(dragon, controls, input.yawRate, dt, input.snap)
		DragonMotion.resolve(dragon, controls, dt, input.snap)
	end
	if style.pinFeet then
		pinFeet(inst, controls, now, legBlow, legHolds)
		-- (Studio, 2026-11-01: the tail's own spin with the drawn heading's follow of a server's turn under it, or a
		-- long frame, turned the Root bone 13.8 degrees in a frame) the body's heading in the world turns at most
		-- BODY_STEP a frame; the rest is carried into the next
		local byaw = (controls.byaw or 0) + inst.yawOff
		local drawn = inst.rootYaw + byaw
		local last = inst.drawnYaw
		if last and not input.snap then
			local d = wrapAngle(drawn - last)
			if math.abs(d) > BODY_STEP then
				local over = d - math.sign(d) * BODY_STEP
				byaw -= over
				drawn -= over
			end
		end
		inst.drawnYaw = wrapAngle(drawn)
		if byaw ~= 0 then
			controls.byaw = byaw
		end
	end
	inst.controls = controls
	local posed = QuadPose.solve(skel, controls)
	inst.posed = posed
	return posed
end

-- (a mount, 2026-11-01) How the body drawn last frame carries a point on its back (`at`: model frame, the skeleton's
-- units, e.g. the saddle): the point's rise and the body's pitch (+ nose up) and roll (+ right side up), so a rider can
-- sit on the saddle as it moves (Logic/RiderPose `saddle`). The spine's flex is left out (a saddle sits mid-back, where
-- it turns least); 0, 0, 0 before the first frame.
function QuadMotion.saddle(inst: Instance, at: Vec): (number, number, number)
	local c = inst.controls
	if not c then
		return 0, 0, 0
	end
	local L = inst.skel.L
	local pitch, roll = c.bpitch or 0, c.broll or 0
	local turn = NpcPose.mul(NpcPose.mul(QuadPose.ry(c.byaw or 0), QuadPose.rx(pitch)), QuadPose.rz(roll))
	local body = inst.skel.bones[inst.skel.rig.body].pos
	-- the body turns about its pivot (bpx, bpy, bpz from the body bone), then moves (QuadPose.world)
	local v = { at[1] - body[1], at[2] - body[2], at[3] - body[3] }
	local pivot = { (c.bpx or 0) * L, (c.bpy or 0) * L, (c.bpz or 0) * L }
	local rv, rp = NpcPose.apply(turn, v), NpcPose.apply(turn, pivot)
	return (c.by or 0) * L + pivot[2] - rp[2] + rv[2] - v[2], pitch, roll
end

---------------------------------------------------------------- the game's choices

-- The gait it draws ("gallop", "trot", "walk", the heaviest weight), "spin" on the spot, or "stand" (a diagnostic:
-- AnimationController puts it on the look in Studio).
function QuadMotion.gaitOf(inst: Instance): string
	if inst.move < 0.1 then
		return "stand"
	end
	if inst.spin > 0.5 then
		return "spin"
	end
	local best, most = "walk", -1
	for name, w in inst.weights do
		if w > most then
			best, most = name, w
		end
	end
	return best
end

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

-- The death of an instance (one of the style's, by its seed): by the side the killing blow came from (`side`,
-- QuadMotion.side) where the style has deaths for it (the dragon's, 2026-10-31).
function QuadMotion.death(inst: Instance, side: string?): string
	local deaths = inst.style.deaths
	local list = if deaths and side and deaths[side] then deaths[side] else inst.style.death
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
