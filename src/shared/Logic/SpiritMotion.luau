--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE §6.4 / §7): floating spirits on their bones (the specter's
-- Mixamo rig, the ice elemental's Tripo biped: Data/BipedRigs). Logic/BipedMotion poses the body and the arms (the
-- style's rest and guard, the caster's bolt released from the hands at W, the wail, the burst, the deaths); this layer
-- floats it, on the Transforms BipedMotion returns:
-- * the body bobs and sways slowly and leans into the way it drifts, on springs (the lag of a body without feet), and
--   banks into turns; it turns about the skeleton's pivot (the elemental's middle);
-- * the specter's robe below the waist (its legs, no feet) hangs from the hips and trails behind the drift and outward
--   in turns, the lower half lagging the upper one, with a slow flutter;
-- * keyed meta controls of the style's actions: `fade` (0..1 over the style's flicker: the specter's flicker
--   0.15-0.35 at 0.5 Hz, the deaths fading out, the appear fading in) and `shiver` (a fast tremble of the body);
--   client/Anim/BipedRig sets the look's transparency from `SpiritMotion.fade`.
-- Pure (numbers in, Transforms out); the same rig interface as BipedMotion (new, step, pick, death, side, length).

local BipedMotion = require("./BipedMotion")
local BipedPose = require("./BipedPose")
local BipedStyles = require("../Data/BipedStyles")
local NpcPose = require("./NpcPose")

local SpiritMotion = {}

type Vec = { number }
type Mat = { number }

local mul, transpose, apply = NpcPose.mul, NpcPose.transpose, NpcPose.apply

-- Spring follow of a value: the natural frequency (rad/s) of a lag `lag` seconds, damping ratio.
local DAMP = 0.62
local STEP = 1 / 30
-- The bank into turns (rad per stud/s x rad/s) and its limit; the robe's swing out of a turn.
local BANK = 0.016
local BANK_MAX = 0.3
local SWING = 0.03
local SWING_MAX = 0.6
-- The shiver: rad of the body at full `shiver`, and its rate (Hz).
local SHIVER = 0.06
local SHIVER_HZ = 17
-- The drift's inertia: the speed the body moves by follows the ground speed at this rate (1/s).
local DRIFT_RATE = 5
local LEGS = { { "LeftUpLeg", "LeftLeg" }, { "RightUpLeg", "RightLeg" } }
local ZERO: Vec = { 0, 0, 0 }

export type Spring = { x: number, v: number }
export type Instance = {
	base: BipedMotion.Instance,
	style: BipedStyles.Style,
	skel: BipedPose.Skeleton,
	seed: number,
	lean: Spring,
	bank: Spring,
	trail: Spring,
	trail2: Spring,
	swing: Spring,
	swing2: Spring,
	fade: number,
	meta: { [string]: boolean }, -- actions with keyed `fade` / `shiver`
	speed: number, -- the drift's speed (the ground speed eased)
	feed: { [string]: any }, -- the input handed on to Logic/BipedMotion (reused each frame)
}

-- Whether a Data/BipedStyles style is a spirit's (this module drives it).
function SpiritMotion.handles(styleId: string): boolean
	local style = BipedStyles.get(styleId)
	return style ~= nil and style.spirit ~= nil
end

local function spring(): Spring
	return { x = 0, v = 0 }
end

function SpiritMotion.new(skel: BipedPose.Skeleton, styleId: string, seed: number, grip: { number }?): Instance?
	local base = BipedMotion.new(skel, styleId, seed, grip)
	if not base then
		return nil
	end
	local meta: { [string]: boolean } = {}
	for name, action in base.style.actions do
		for _, key in action.keys do
			if key.pose.fade ~= nil or key.pose.shiver ~= nil then
				meta[name] = true
			end
		end
	end
	return {
		base = base,
		style = base.style,
		skel = skel,
		seed = seed,
		lean = spring(),
		bank = spring(),
		trail = spring(),
		trail2 = spring(),
		swing = spring(),
		swing2 = spring(),
		fade = 0,
		meta = meta,
		speed = 0,
		feed = {},
	}
end

local function follow(s: Spring, target: number, lag: number, dt: number, snap: boolean?)
	if snap then
		s.x, s.v = target, 0
		return
	end
	local w = 1 / math.max(0.05, lag)
	local left = math.min(dt, 0.25)
	while left > 1e-6 do
		local h = math.min(STEP, left)
		s.v += (w * w * (target - s.x) - 2 * DAMP * w * s.v) * h
		s.x += s.v * h
		left -= h
	end
end

-- The keyed meta controls of the running action (`fade`, `shiver`), 0 without.
local function metaOf(inst: Instance, input: BipedMotion.Input): (number, number)
	local run = input.action
	if not run or not inst.meta[run.name] then
		return 0, 0
	end
	local action = inst.style.actions[run.name]
	local length = BipedMotion.length(action, run.hit)
	local t = input.now - run.start
	if t < 0 or (t > length and not action.hold) then
		return 0, 0
	end
	local c = BipedMotion.controlsAt(inst.style, run.name, run.hit, math.min(t, length))
	if not c then
		return 0, 0
	end
	return c.fade or 0, c.shiver or 0
end

-- `posed` key's rotation turned by `turn` (root axes, about the bone's own joint): R^T * turn * R * rot, or only the
-- turn from its parent at rest (`fresh`).
local function turnEntry(skel: BipedPose.Skeleton, posed: BipedPose.Posed, key: string, turn: Mat, fresh: boolean?)
	local entry = posed[key]
	local bone = skel.bones[key]
	if entry and bone then
		local r = bone.rest
		local turned = mul(mul(transpose(r), turn), r)
		entry.rot = if fresh then turned else mul(turned, entry.rot)
	end
end

-- One frame: BipedMotion's pose floated (Transforms per bone key).
function SpiritMotion.step(inst: Instance, input: BipedMotion.Input): BipedPose.Posed
	local dt = input.dt
	local snap = input.snap
	-- a body without feet has inertia: it eases into and out of its drift (the ground speed may step)
	inst.speed = if snap
		then input.speed
		else inst.speed + (input.speed - inst.speed) * (1 - math.exp(-DRIFT_RATE * dt))
	local feed = inst.feed
	table.clear(feed)
	for key, value in input :: any do
		feed[key] = value
	end
	feed.speed = inst.speed
	input = feed :: any
	local posed = BipedMotion.step(inst.base, input)
	local spirit = inst.style.spirit :: any
	local skel = inst.skel
	local t = input.now + inst.seed * 1.7
	local L = skel.legLength
	local v = math.clamp(input.speed / spirit.speed, 0, 1.2)
	local fade, shiver = metaOf(inst, input)
	-- the drift: lean into the way it goes, bank into turns, a slow sway and bob
	follow(inst.lean, spirit.lean * v, spirit.leanLag, dt, snap)
	follow(inst.bank, math.clamp(input.yawRate * input.speed * BANK, -BANK_MAX, BANK_MAX), spirit.leanLag, dt, snap)
	local swayHz = spirit.swayHz
	local swayRoll = spirit.sway * math.sin(2 * math.pi * swayHz * t)
	local swayPitch = spirit.sway * 0.7 * math.sin(2 * math.pi * swayHz * 0.77 * t + 1.3)
	local bob = spirit.bob * L * math.sin(2 * math.pi * spirit.bobHz * t)
	local pitch = inst.lean.x + swayPitch
	local roll = inst.bank.x + swayRoll
	if shiver > 0 then
		pitch += SHIVER * shiver * math.sin(2 * math.pi * SHIVER_HZ * t)
		roll += SHIVER * shiver * math.sin(2 * math.pi * SHIVER_HZ * 1.31 * t + 0.7)
	end
	local hips = posed.Hips
	local hipsBone = skel.bones.Hips
	if hips and hipsBone then
		local r = hipsBone.rest
		local w = mul(mul(r, hips.rot), transpose(r))
		local e = BipedPose.body(0, pitch, roll)
		local w2 = mul(e, w)
		local move = apply(r, hips.offset or ZERO)
		local pivot = skel.pivot
		if pivot then
			-- the turn about the pivot: the joint swings round it
			local d = { pivot[1] - hipsBone.pos[1], pivot[2] - hipsBone.pos[2], pivot[3] - hipsBone.pos[3] }
			local a, b = apply(w, d), apply(w2, d)
			move = { move[1] + a[1] - b[1], move[2] + a[2] - b[2], move[3] + a[3] - b[3] }
		end
		move[2] += bob
		hips.rot = mul(mul(transpose(r), w2), r)
		hips.offset = apply(transpose(r), move)
	end
	-- the robe: trailing behind the drift and out of turns, against the body's own lean (it hangs), the lower half later
	local trail = spirit.trail
	if trail then
		local trailTarget = trail.pitch * v - pitch * 0.7
		local swingTarget = math.clamp(input.yawRate * input.speed * SWING, -SWING_MAX, SWING_MAX) - roll * 0.8
		follow(inst.trail, trailTarget, trail.lag, dt, snap)
		follow(inst.trail2, trailTarget, trail.lag2, dt, snap)
		follow(inst.swing, swingTarget, trail.lag, dt, snap)
		follow(inst.swing2, swingTarget, trail.lag2, dt, snap)
		local flutter = trail.flutter * math.sin(2 * math.pi * 0.4 * t)
		local flutterSide = trail.flutter * math.sin(2 * math.pi * 0.27 * t + 2.1)
		local upper = BipedPose.body(0, inst.trail.x + flutter, inst.swing.x + flutterSide)
		local lower = BipedPose.body(
			0,
			inst.trail2.x - inst.trail.x + flutter * 0.8,
			inst.swing2.x - inst.swing.x + flutterSide * 0.8
		)
		for _, pair in LEGS do
			-- the legs hang from the hips whatever the motion keyed for them, then trail
			turnEntry(skel, posed, pair[1], upper, true)
			turnEntry(skel, posed, pair[2], lower, true)
		end
	end
	-- the look's fade: the flicker and the action's own
	local flicker = 0
	local f = spirit.flicker
	if f then
		flicker = f[1] + f[2] * math.sin(2 * math.pi * f[3] * t)
	end
	inst.fade = math.clamp(flicker + fade, 0, 1)
	return posed
end

-- How faded the look is (0 solid .. 1 gone) after the last step.
function SpiritMotion.fade(inst: Instance): number
	return inst.fade
end

-- The rest of the rig interface is BipedMotion's.
SpiritMotion.length = BipedMotion.length
SpiritMotion.times = BipedMotion.times
SpiritMotion.controlsAt = BipedMotion.controlsAt
SpiritMotion.pick = BipedMotion.pick
SpiritMotion.side = BipedMotion.side

function SpiritMotion.death(inst: Instance): string
	return BipedMotion.death(inst.base)
end

return SpiritMotion
