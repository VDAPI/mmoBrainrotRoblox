--!strict
-- Template animation (docs/ANIM-WZORCE.md F4, 2026-10-31): a dragon's wings and its reptile's extras over
-- Logic/QuadMotion (the legs, the gaits, the neck and the tail are the quadruped's, Data/QuadStyles `dragon`).
-- The wings (Logic/QuadPose's wing controls, the Logic/FlyerPose letters) rest folded high along the back (the wrists
-- up by the shoulders, the fingers swept back toward the tail). The model's wings rest spread, so the fold is computed
-- once from the wing's own rest joints (Data/QuadStyles `wings.fold`: the elbow and wrist folds, then the shoulder
-- turn that lays the humerus back and up over the flank with the membrane's top side out), and the rig map needs no
-- hand-tuned angles. The styles key the wings by
--   wo (both) / wLo / wRo   openness: 0 folded, 1 spread as modelled, 2 flat and straight out (a flight wing); the
--                           poses between are blended per joint;
--   we ws wt wf wh wb ww wp wq   both wings' offsets on top of the openness (rad, the Logic/FlyerPose letters: lift,
--                           sweep forward, leading edge up, elbow fold, wrist fold, forearm / hand / fingers bent up,
--                           hand twist), w<S><letter> one wing's (S = L / R);
--   flap, beat              a wingbeat of size `flap` (0..1) at phase `beat` (cycles: keyed, so the strokes land on the
--                           action's timeline; the downstroke runs from a whole number to + 0.45, Logic/FlyerMotion's
--                           stroke);
-- and adds the gallop's pump (the wings half open and held up, one beat a stride, its downstroke as the hind feet
-- push off), the folded wings' breath, the tail's spring (its tip trails the body's turns and swings past), the tail
-- tip's flicks and the neck's slow sway. Pure; no allocation per frame.

local NpcPose = require("./NpcPose")
local QuadPose = require("./QuadPose")
local QuadStyles = require("../Data/QuadStyles")

local DragonMotion = {}

type Vec = { number }
type Mat = { number }
type Controls = QuadPose.Controls

-- One wing's raw controls by letter.
type Pose = { [string]: number }
export type Side = {
	name: string, -- "L" / "R"
	m: number, -- -1 / 1
	keys: { [string]: string }, -- raw control names by letter (Logic/QuadPose WING_KEYS): keyed, they are this wing's
	-- offsets, read and then replaced by the raw value
	open: string, -- w<S>o
	fold: Pose, -- folded along the body
	spread: Pose, -- as modelled
	flat: Pose, -- flat and straight out
}
export type State = {
	style: QuadStyles.Wings,
	sides: { Side },
	seed: number,
	tailBones: number, -- the rig's tail bones (up to 8)
	-- the tail's spring: where its tip points (rad of yaw) and how fast it swings
	tailS: number,
	tailV: number,
	tailReady: boolean,
	-- each wing's openness as drawn (by side index), following the keyed one at a bounded pace (nil: not drawn yet)
	open: { number },
}

local LETTERS = { "e", "s", "t", "f", "h", "b", "w", "p", "q" }
-- both wings' offsets by letter
local SHARED: { [string]: string } = {}
for _, letter in LETTERS do
	SHARED[letter] = "w" .. letter
end
local TAIL_Y = { "tY1", "tY2", "tY3", "tY4", "tY5", "tY6", "tY7", "tY8" }
local TAU = 2 * math.pi
-- the fastest a wing opens or folds (openness per second; studio review 2026-10-31: no joint turning more than ~12
-- degrees a frame): the elbow and the wrist unfold between 0 and 1, the shoulder alone turns on to flat beyond it
local OPEN_RATE, SPREAD_RATE = 4.2, 9

local mul, transpose, apply = NpcPose.mul, NpcPose.transpose, NpcPose.apply

local function unit(v: Vec): Vec
	local n = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	if n < 1e-9 then
		return { 0, 1, 0 }
	end
	return { v[1] / n, v[2] / n, v[3] / n }
end
local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
-- b made orthogonal to the unit vector a, unit length
local function across(a: Vec, b: Vec): Vec
	local d = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	return unit({ b[1] - a[1] * d, b[2] - a[2] * d, b[3] - a[3] * d })
end
local function columns(x: Vec, y: Vec, z: Vec): Mat
	return { x[1], y[1], z[1], x[2], y[2], z[2], x[3], y[3], z[3] }
end
-- The shoulder's elevation, sweep and twist (Logic/QuadPose zyx: Rz(a) Ry(b) Rx(c)) of turn `g` on side `m`.
local function shoulderOf(g: Mat, m: number): (number, number, number)
	local a = math.atan2(g[4], g[1])
	local b = math.asin(math.clamp(-g[7], -1, 1))
	local c = math.atan2(g[8], g[9])
	return a * m, b * m, c
end

local function pose(): Pose
	local out: Pose = {}
	for _, letter in LETTERS do
		out[letter] = 0
	end
	return out
end

-- The wing of side `name` posed folded, as modelled and flat (nil without the wing's bones).
local function sideOf(skel: QuadPose.Skeleton, name: string, spec: QuadStyles.Wings): Side?
	local map = skel.rig.wings and skel.rig.wings[name]
	local w = map and skel.wings[map.humerus]
	if not map or not w then
		return nil
	end
	local m = w.side
	-- as modelled: the shoulder turn that undoes the fit (the chain's joints at rest)
	local spread = pose()
	spread.e, spread.s, spread.t = shoulderOf(transpose(w.fit), m)
	-- folded: the elbow and wrist folds, then the shoulder turn taking the humerus (in the flat frame) onto the wanted
	-- direction and the flat wing's top side onto the wanted membrane side (the right wing's numbers, mirrored)
	local f = spec.fold
	local fold = pose()
	fold.f, fold.h = f.f, f.h
	fold.b, fold.w, fold.p, fold.q = f.b or 0, f.w or 0, f.p or 0, f.q or 0
	local shoulder = skel.bones[map.humerus].pos
	local elbow = skel.bones[map.forearm].pos
	local u1 = unit(apply(w.fit, { elbow[1] - shoulder[1], elbow[2] - shoulder[2], elbow[3] - shoulder[3] }))
	local y1 = across(u1, { 0, 1, 0 })
	local hum = unit({ f.hum[1] * m, f.hum[2], f.hum[3] })
	local nrm = across(hum, { f.nrm[1] * m, f.nrm[2], f.nrm[3] })
	local g = mul(columns(hum, nrm, cross(hum, nrm)), transpose(columns(u1, y1, cross(u1, y1))))
	fold.e, fold.s, fold.t = shoulderOf(g, m)
	local keys = QuadPose.WING_KEYS[name]
	return {
		name = name,
		m = m,
		keys = keys,
		open = "w" .. name .. "o",
		fold = fold,
		spread = spread,
		flat = pose(),
	}
end

-- The dragon layer of a skeleton with wings in a style with `wings` (nil otherwise: the controls stay as keyed).
function DragonMotion.new(skel: QuadPose.Skeleton, spec: QuadStyles.Wings?, seed: number): State?
	if not spec then
		return nil
	end
	local sides: { Side } = {}
	for _, name in { "L", "R" } do
		local side = sideOf(skel, name, spec)
		if side then
			table.insert(sides, side)
		end
	end
	if #sides == 0 then
		return nil
	end
	return {
		style = spec,
		sides = sides,
		seed = seed,
		tailBones = math.min(#skel.rig.tail, #TAIL_Y),
		tailS = 0,
		tailV = 0,
		tailReady = false,
		open = {},
	}
end

-- Humerus elevation through a beat at phase `p` (0..1): down from the top over 0.45 of the cycle, up again over the
-- rest, fastest mid-stroke (Logic/FlyerMotion's stroke).
local function elevation(top: number, bottom: number, p: number): number
	p %= 1
	if p < 0.45 then
		return top + (bottom - top) * (1 - math.cos(math.pi * p / 0.45)) / 2
	end
	return bottom + (top - bottom) * (1 - math.cos(math.pi * (p - 0.45) / 0.55)) / 2
end

-- Adds a wingbeat of size `amp` at phase `p` to both wings' offsets (the hand and the fingers trail the arm).
local function beatInto(d: State, controls: Controls, p: number, amp: number)
	local b = d.style.beat
	local e = elevation(b.top, b.bottom, p)
	local lagHand = elevation(b.top, b.bottom, p - 0.06) - e
	local lagTip = elevation(b.top, b.bottom, p - 0.1) - e
	local q = p % 1
	local down = q < 0.45
	local s = if down then q / 0.45 else (q - 0.45) / 0.55
	local arch = math.sin(math.pi * s)
	controls.we = (controls.we or 0) + e * amp
	controls.ws = (controls.ws or 0) + (if down then b.fore else b.back) * arch * amp
	local fold = if down then 0 else b.fold * arch * amp
	controls.wf = (controls.wf or 0) + fold
	controls.wh = (controls.wh or 0) + fold * 0.7
	controls.ww = (controls.ww or 0) + lagHand * amp
	controls.wp = (controls.wp or 0) + lagTip * 0.6 * amp
	controls.wq = (controls.wq or 0) + (if down then 0 else b.twist * arch * amp)
	controls.wt = (controls.wt or 0) + (if down then -0.08 * arch * amp else 0)
end

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The layer under the keyed actions: the gallop's pump (`gallop`: the gallop's weight times the motion, at gait
-- phase `phase`), the folded wings' breath, the tail tip's flicks and the neck's sway (`still`: 1 standing, 0
-- moving; `free`: not fighting).
function DragonMotion.base(
	d: State,
	controls: Controls,
	now: number,
	gallop: number,
	phase: number,
	still: number,
	free: number
)
	local style = d.style
	local pump = style.pump
	if gallop > 0.005 then
		controls.wo = (controls.wo or 0) + pump.open * gallop
		controls.we = (controls.we or 0) + pump.lift * gallop
		controls.ww = (controls.ww or 0) + pump.hand * gallop
		controls.wp = (controls.wp or 0) + pump.tips * gallop
		beatInto(d, controls, phase - pump.at, pump.amp * gallop)
	end
	local t = now + d.seed * 3.7
	-- the folded wings rise and settle with the breath
	local breath = math.sin(t * TAU * 0.35)
	controls.we = (controls.we or 0) + 0.025 * breath * still
	-- the neck's slow sway, the head kept on its look
	local sway = math.sin(t * TAU * 0.13) * still * free
	controls.nyaw = (controls.nyaw or 0) + 0.06 * sway
	controls.hyaw = (controls.hyaw or 0) - 0.04 * sway
	-- now and then a flick of the tail's tip (in slots of 3.1 s, half of them)
	local slot = math.floor(t / 3.1)
	local x = t - slot * 3.1
	if x < 0.55 and d.tailBones >= 2 and NpcPose.hash01(slot, d.seed + 41) < 0.5 then
		local dir = if NpcPose.hash01(slot + 7, d.seed + 41) < 0.5 then -1 else 1
		local k = math.sin(math.pi * x / 0.55)
		local last = d.tailBones
		controls[TAIL_Y[last]] = (controls[TAIL_Y[last]] or 0) + 0.32 * dir * k * still
		controls[TAIL_Y[last - 1]] = (controls[TAIL_Y[last - 1]] or 0) - 0.18 * dir * k * still
	end
end

-- The tail's spring (after the keyed actions): the tip trails the body's turns (its keyed yaw and the turn rate) and
-- swings past them, so a spin whips the tail through.
function DragonMotion.tail(d: State, controls: Controls, yawRate: number, dt: number, snap: boolean?)
	local spring = d.style.tail
	local drive = (controls.byaw or 0) + (controls.syaw or 0) + math.clamp(yawRate * 0.12, -0.3, 0.3)
	if snap or not d.tailReady then
		d.tailS, d.tailV, d.tailReady = drive, 0, true
	elseif dt > 0 then
		local omega = TAU * spring.hz
		local steps = math.ceil(dt * 60)
		local h = dt / steps
		for _ = 1, steps do
			local a = omega * omega * (drive - d.tailS) - 2 * spring.damp * omega * d.tailV
			d.tailV += a * h
			d.tailS += d.tailV * h
		end
	end
	local lag = math.clamp((d.tailS - drive) * spring.gain, -0.5, 0.5)
	local n = d.tailBones
	-- the tail's back half takes the lag, growing to the tip
	local from = math.max(1, math.floor(n / 2))
	local total = 0
	for i = from, n do
		total += i - from + 1
	end
	for i = from, n do
		local key = TAIL_Y[i]
		controls[key] = (controls[key] or 0) + lag * (i - from + 1) / total
	end
end

-- The wing controls keyed and layered (openness, offsets, the beat) turned into the raw ones Logic/QuadPose reads,
-- right before the solve. With the frame's `dt` each wing's openness follows the keyed one at a bounded pace (a blow
-- that throws the wings open, a new rig's first frame), `snap` takes it at once; without `dt` (a pose on its own) it
-- is the keyed one.
function DragonMotion.resolve(d: State, controls: Controls, dt: number?, snap: boolean?)
	local flap = controls.flap
	if flap and flap > 0.001 then
		beatInto(d, controls, controls.beat or 0, math.min(flap, 1.5))
	end
	local open = controls.wo or 0
	for index, side in d.sides do
		local o = math.clamp(open + (controls[side.open] or 0), 0, 2.3)
		local drawn = d.open[index]
		if dt and drawn and not snap then
			local rate = if math.min(o, drawn) < 1 then OPEN_RATE else SPREAD_RATE
			o = drawn + math.clamp(o - drawn, -rate * dt, rate * dt)
		end
		if dt then
			d.open[index] = o
		end
		local a, b, k = side.fold, side.spread, o
		if o > 1 then
			a, b, k = side.spread, side.flat, o - 1
		end
		-- the folds close a little ahead of the arm's swing back, and open after it (so the long fingers never sweep
		-- out through the body): the elbow and wrist ease, the shoulder runs straight
		local kf = smooth(k)
		local keys = side.keys
		for _, letter in LETTERS do
			local from, to = a[letter], b[letter]
			local share = if letter == "f" or letter == "h" then kf else k
			local key = keys[letter]
			controls[key] = from + (to - from) * share + (controls[SHARED[letter]] or 0) + (controls[key] or 0)
		end
		-- the shoulder blade takes a share of the arm's turn away from the wing as modelled
		local spread = side.spread
		controls[keys.u] = 0.25 * (controls[keys.e] - spread.e)
		controls[keys.v] = 0.2 * (controls[keys.s] - spread.s)
	end
end

-- The wing poses of a state (Lune specs, AnimLab): folded, as modelled, flat, by side.
function DragonMotion.poses(d: State): { [string]: { fold: Pose, spread: Pose, flat: Pose } }
	local out = {}
	for _, side in d.sides do
		out[side.name] = { fold = side.fold, spread = side.spread, flat = side.flat }
	end
	return out
end

return DragonMotion
