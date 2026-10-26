--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE.md F5 §6): the styles of imported models without bones,
-- animated by Logic/RigidMotion as one rigid body on the Gait_Body motor. Units: x in body widths W, y in mesh heights
-- h, z in body lengths B (+ = back), angles in radians; distances in studs only where a comment says so.
-- Controls of a key (all optional, 0 = rest):
--   x y z           body offset;  yaw (about the centre) wig (about `wigPivot`: a snake's head stays) spin (yaw, deaths)
--   pitch roll      about the box centre (+ nose up, + right side up);  bow lean: pitch / roll about the ground point
--   rear            pitch about the hind contact (+ front up);  dip: about the front contact (+ rear up, nose down)
--   tip             roll about the ground edge (+ falls onto its right side; the foot it stands on while rocking)
--   sq sl gr        squash (vertical), stretch (along the body), grow: volume kept, only when the rig may scale
--   lunge           0..1 of the gap to the target (Logic/RigidMotion: aimed until the strike, then locked)
--   travel          0..1 of a flight to the target (actions with `flight`; the server's Dash* arc replaces it)
--   shiver shake    amplitude of a 20 Hz shiver / a 5 Hz shake;  alpha: transparency
--   sink fall       below the ground by the whole height (climbing out) / down by the hover (a flyer falling)
--   ground settle   the box never under the ground / lowered onto it (deaths, flips)
--   nP nY hP tC calmTail   bones of a serpent (Data/RigidRigs): neck pitch (+ forward) and yaw, head pitch, tail curl,
--                   the tail's wave stilled
-- `gaits` by speed over body length (`thresholds`), each: stride (B per cycle, a cadence cap `maxRate` Hz makes it
-- longer), the bob (bumps per cycle), sway, wiggle, rock, pitch and its wave, surge, crouch, hops, a flutter's `hz`.

local RigidStyles = {}

export type Pose = { [string]: number }
export type Key = { seg: string, u: number, ease: string?, pose: Pose }
export type Action = {
	keys: { Key },
	strike: number,
	follow: number,
	recover: number,
	hold: boolean?, -- keeps the last pose (deaths)
	tremble: number?, -- rad of the gather's tremble at the end of the anticipation (a charged blow)
	flight: boolean?, -- flies to the target (Dash* arc or `travel`)
	arc: number?, -- the own arc's height factor (no Dash*)
	sided: boolean?, -- turned to the death side
	additive: boolean?, -- laid over the idle (fidgets)
}
export type Hop = {
	ground: number, -- share of the cycle on the ground
	height: number, -- arc height over the hop length
	maxHeight: number, -- in h
	crouch: number,
	squash: number,
	stretch: number,
	pitchUp: number,
	pitchDown: number,
}
export type Gait = {
	stride: number,
	maxRate: number?,
	hz: number?,
	bumps: number,
	bob: number,
	sine: boolean?,
	sharp: number?,
	roll: number,
	rollPhase: number,
	rock: number,
	yaw: number,
	yawLag: number,
	sway: number,
	pitch: number,
	pitchWave: number,
	pitchBumps: number,
	pitchPhase: number,
	surge: number,
	crouch: number,
	jitter: number,
	jitterHz: number,
	hop: Hop?,
}
export type Idle = {
	breath: number,
	rate: number,
	sway: number,
	shift: number,
	crouch: number,
	look: number,
	drift: { x: number, y: number, z: number, yaw: number, hz: number }?,
	weave: { yaw: number, pitch: number, hz: number, bones: number }?,
}
export type Bones = {
	stride: number, -- B per wave cycle while it moves
	idleHz: number,
	idle: number, -- rad of the tail's wave in place
	move: number, -- rad while it moves
	coil: number, -- the coil's share of the wave
	lag: number, -- cycle per bone (the wave travels to the tail)
	sway: number, -- the neck's sway (rad)
	swayHz: number,
	body: number, -- how much the whole body still wiggles
}
export type Style = {
	fly: boolean,
	order: { string },
	thresholds: { number },
	band: number,
	gaits: { [string]: Gait },
	gaitOf: { [string]: string }?, -- the server's `Gait` (walk, trot, run) onto the style's gaits
	burst: { hz: number, bob: number, surge: number }?,
	start: number,
	stop: { over: number, wobble: number },
	turn: { omega: number, bank: number, bankMax: number },
	idle: Idle,
	stance: Pose,
	calm: Pose,
	stalk: Pose?,
	actions: { [string]: Action },
	flinch: { push: number, tilt: number, drop: number, squash: number },
	stun: { roll: number, pitch: number, hz: number, drop: number, twitch: number },
	basic: { string },
	abilities: { [string]: string },
	throw: string?,
	death: { { name: string, weight: number } },
	aggro: string?,
	spawn: string?,
	summon: string?,
	fidgets: { string },
	fidgetEvery: { number },
	rate: number,
	lunge: { min: number, max: number },
	flightPitch: { number },
	footprint: number,
	wigPivot: number,
	bones: Bones?,
}

local function deg(d: number): number
	return math.rad(d)
end

local function from(base: Pose, over: Pose): Pose
	local out = table.clone(base)
	for k, v in over do
		out[k] = v
	end
	return out
end

-- `pose` with `k` = v unless it already keys `k` (a pivot that may be the strike's own: a scorpion rears by its dip).
local function with(pose: Pose, k: string, v: number): Pose
	if pose[k] == nil then
		pose[k] = v
	end
	return pose
end

local function key(seg: string, u: number, ease: string?, pose: Pose): Key
	return { seg = seg, u = u, ease = ease, pose = pose }
end

local function gait(o: { [string]: any }): Gait
	return {
		stride = o.stride,
		maxRate = o.maxRate,
		hz = o.hz,
		bumps = o.bumps or 2,
		bob = o.bob or 0,
		sine = o.sine,
		sharp = o.sharp,
		roll = o.roll or 0,
		rollPhase = o.rollPhase or 0,
		rock = o.rock or 0,
		yaw = o.yaw or 0,
		yawLag = o.yawLag or 0,
		sway = o.sway or 0,
		pitch = o.pitch or 0,
		pitchWave = o.pitchWave or 0,
		pitchBumps = o.pitchBumps or 2,
		pitchPhase = o.pitchPhase or 0,
		surge = o.surge or 0,
		crouch = o.crouch or 0,
		jitter = o.jitter or 0,
		jitterHz = o.jitterHz or 3,
		hop = o.hop,
	}
end

---------------------------------------------------------------- shared shapes (each key is laid over the stance)

-- The first aggro: up about the hind contact (or `pivot`), held with a shiver, dropped with a thump on the hit (0.45).
local function alert(st: Pose, o: { [string]: any }): Action
	local pivot = o.pivot or "rear"
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.1,
		follow = 0.15,
		recover = 0.3,
		keys = {
			key("A", 0.43, "out", s({ [pivot] = o.rear, y = o.up or 0.02, shiver = o.shiver or deg(1) })),
			key("A", 1, "lin", s({ [pivot] = o.rear, y = o.up or 0.02, shiver = o.shiver or deg(1) })),
			key("S", 1, "in", s({ [pivot] = 0, y = o.thump or -0.03, sq = o.squash or -0.08 })),
			key("F", 1, "out", s({ y = (o.thump or -0.03) * 0.3 })),
			key("R", 1, "inout", st),
		},
	}
end

-- A crawler's bite: up about the hind contact with a growing shiver, the front slams forward and down (a short hop)
-- with the lunge onto the target on the hit, worrying it from side to side, then a recoil hop back.
local function bite(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local rear, up, back = o.rear or deg(14), o.up or 0.05, o.back or 0.03
	local slam, hop, shake = o.slam or deg(10), o.hop or 0.1, o.shake or deg(4)
	return {
		strike = o.strike or 0.14,
		follow = o.follow or 0.15,
		recover = o.recover or 0.25,
		keys = {
			key(
				"A",
				0.6,
				"out",
				s({ rear = rear * 0.85, y = up * 0.8, z = back, shiver = (o.shiver or deg(1.5)) * 0.35 })
			),
			key("A", 1, "inout", s({ rear = rear, y = up, z = back, shiver = o.shiver or deg(1.5) })),
			key("S", 0.5, "in", s({ rear = 0, dip = slam * 0.4, y = hop, lunge = 0.6 })),
			key("S", 1, "in", s({ rear = 0, dip = slam, y = 0, lunge = 1, sq = o.squash or -0.1 })),
			key("F", 0.35, "out", s({ rear = 0, dip = slam * 0.85, lunge = 1, yaw = shake })),
			key("F", 0.7, "inout", s({ rear = 0, dip = slam * 0.7, lunge = 1, yaw = -shake })),
			key("F", 1, "inout", s({ rear = 0, dip = slam * 0.5, lunge = 0.95, yaw = shake * 0.3 })),
			key("R", 0.45, "out", s({ lunge = 0.3, y = o.recoil or 0.05, z = back * 0.5 })),
			key("R", 1, "inout", st),
		},
	}
end

-- A lizard's bite: the body winds to one side, then snaps across with the lunge on the hit.
local function snap(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local wind, cross = o.wind or deg(12), o.snap or deg(20)
	return {
		strike = 0.12,
		follow = 0.16,
		recover = 0.28,
		keys = {
			key("A", 1, "out", s({ wig = wind, x = -0.03, rear = o.rear or deg(5), z = 0.03, shiver = deg(0.6) })),
			key("S", 1, "in", s({ wig = -cross, x = 0.02, rear = 0, dip = deg(4), lunge = 1, sq = -0.08 })),
			key("F", 0.5, "out", s({ wig = -cross * 0.8, rear = 0, dip = deg(3), lunge = 1 })),
			key("F", 1, "inout", s({ wig = -cross * 0.3, lunge = 0.8 })),
			key("R", 1, "inout", st),
		},
	}
end

-- A serpent's strike: it coils back (front up, body drawn in), then lunges along its length on the hit and draws back;
-- with bones the neck pulls back and strikes (nP).
local function strike(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local coil, rear, neck, hit = o.coil or 0.08, o.rear or deg(10), o.neck or deg(25), o.hit or deg(35)
	return {
		strike = 0.13,
		follow = 0.16,
		recover = 0.3,
		keys = {
			key("A", 0.7, "out", s({ z = coil, rear = rear, sl = -0.1, nP = -neck, shiver = deg(0.5) })),
			key("A", 1, "lin", s({ z = coil * 1.05, rear = rear * 1.1, sl = -0.1, nP = -neck * 1.1, shiver = deg(1) })),
			key("S", 1, "in", s({ z = 0, rear = 0, dip = deg(5), lunge = 1, sl = 0.12, nP = hit, calmTail = 0.5 })),
			key("F", 0.5, "out", s({ rear = 0, dip = deg(4), lunge = 1, sl = 0.05, nP = hit * 0.8, calmTail = 0.3 })),
			key("F", 1, "inout", s({ lunge = 0.7, nP = hit * 0.4, rear = rear * 0.3 })),
			key("R", 1, "inout", st),
		},
	}
end

-- Spit, breath or venom (an Elite II own blow): up high about `pivot`, held with venom pumps and a growing tremble,
-- snapped forward with a recoil on the hit (the release leaves the front), held a moment for a stream.
local function cast(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local pivot = o.pivot or "rear"
	local rear, up, pump, grow = o.rear or deg(22), o.up or 0.08, o.pump or deg(3), o.grow or 0.05
	local neck = o.neck or deg(25)
	local pumps = o.pumps or 3
	local keys = { key("A", 0.3, "out", s({ [pivot] = rear, y = up, nP = -neck })) }
	for i = 1, pumps do
		table.insert(
			keys,
			key(
				"A",
				0.3 + 0.7 * (i - 0.5) / pumps,
				"inout",
				s({ [pivot] = rear - pump, y = up, gr = grow, nP = -neck * 1.1 })
			)
		)
		table.insert(
			keys,
			key("A", 0.3 + 0.7 * i / pumps, "inout", s({ [pivot] = rear + pump * 0.3, y = up, gr = 0, nP = -neck }))
		)
	end
	local snapTo = o.snap or deg(8)
	local recoil = o.recoil or 0.04
	table.insert(
		keys,
		key("S", 1, "in", s(with({ dip = snapTo, z = recoil, y = 0, nP = neck * 0.6, lunge = o.lunge or 0 }, pivot, 0)))
	)
	local held =
		{ dip = snapTo * 0.85, z = recoil * 0.8, nP = neck * 0.5, shiver = deg(0.6), lunge = (o.lunge or 0) * 0.8 }
	table.insert(keys, key("F", 0.5, "out", s(with(held, pivot, 0))))
	table.insert(
		keys,
		key("F", 1, "inout", s(with({ dip = snapTo * 0.4, z = recoil * 0.4, nP = neck * 0.2 }, pivot, 0)))
	)
	table.insert(keys, key("R", 1, "inout", st))
	return {
		strike = 0.14,
		follow = (o.hold or 0.15) + 0.1,
		recover = 0.35,
		tremble = o.tremble or deg(1.5),
		keys = keys,
	}
end

-- Heavy Blow (Elite, 1.8): reared high with a slow weave, wound to the right, it crashes forward sweeping across (right
-- to left) on the hit.
local function heavy(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local pivot = o.pivot or "rear"
	local rear, weave, slam, sweep = o.rear or deg(25), o.weave or deg(8), o.slam or deg(12), o.sweep or deg(30)
	return {
		strike = 0.14,
		follow = 0.15,
		recover = 0.5,
		tremble = deg(1),
		keys = {
			key("A", 0.35, "out", s({ [pivot] = rear * 0.8, y = 0.05, wig = weave })),
			key("A", 0.55, "inout", s({ [pivot] = rear * 0.9, y = 0.06, wig = -weave })),
			key("A", 0.75, "inout", s({ [pivot] = rear, y = 0.06, wig = weave })),
			key("A", 1, "inout", s({ [pivot] = rear, y = 0.06, wig = -sweep * 0.5, shiver = deg(1) })),
			key("S", 1, "in", s(with({ dip = slam, y = 0, lunge = 1, wig = sweep * 0.5, sq = -0.1 }, pivot, 0))),
			key("F", 1, "out", s(with({ dip = slam * 0.6, lunge = 0.9, wig = sweep * 0.55 }, pivot, 0))),
			key("R", 1, "inout", st),
		},
	}
end

-- Crush (Elite II, 2.2): reared highest, three pumps and a large tremble, the front slammed down on the hit.
local function crush(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local pivot = o.pivot or "rear"
	local rear, slam = o.rear or deg(30), o.slam or deg(12)
	local keys = { key("A", 0.25, "out", s({ [pivot] = rear, y = 0.08 })) }
	for i = 1, 3 do
		table.insert(
			keys,
			key("A", 0.25 + 0.75 * (i - 0.5) / 3, "inout", s({ [pivot] = rear - deg(4), y = 0.08, gr = 0.05 }))
		)
		table.insert(keys, key("A", 0.25 + 0.75 * i / 3, "inout", s({ [pivot] = rear + deg(1), y = 0.08, gr = 0 })))
	end
	table.insert(keys, key("S", 1, "in", s(with({ dip = slam, y = -0.02, lunge = 0.5, sq = -0.15 }, pivot, 0))))
	table.insert(keys, key("F", 1, "out", s(with({ dip = slam * 0.7, y = -0.01, lunge = 0.5 }, pivot, 0))))
	table.insert(keys, key("R", 1, "inout", st))
	return { strike = 0.14, follow = 0.2, recover = 0.5, tremble = deg(2), keys = keys }
end

-- A pounce or leap: a cocked crouch with the hind end wiggling, the flight onto the target (the Dash* arc, the body
-- pitched along it), the landing squash on the hit, a bounce and a shiver.
local function pounce(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local crouch, dip, wiggle = o.crouch or -0.08, o.dip or deg(6), o.wiggle or deg(4)
	local cocked = { y = crouch, dip = dip, sq = -0.06, rear = 0 }
	local keys = { key("A", 0.2, "out", s(cocked)) }
	for i, u in { 0.4, 0.55, 0.7, 0.85 } do
		table.insert(keys, key("A", u, "inout", s(from(cocked, { wig = if i % 2 == 1 then wiggle else -wiggle }))))
	end
	table.insert(keys, key("A", 1, "inout", s(from(cocked, { y = crouch * 1.1, sq = -0.08, shiver = deg(0.8) }))))
	table.insert(keys, key("S", 0, "lin", s(from(cocked, { y = crouch * 1.1, sq = -0.08, travel = 0 }))))
	table.insert(keys, key("S", 0.15, "out", s({ travel = 0.12, sq = 0.1, rear = 0, dip = 0 })))
	table.insert(keys, key("S", 1, "lin", s({ travel = 1, sq = -0.15, rear = 0, dip = 0 })))
	table.insert(keys, key("F", 0.4, "out", s({ travel = 1, y = 0.03, sq = 0.03, shiver = deg(1) })))
	table.insert(keys, key("F", 1, "inout", s({ travel = 1, shiver = deg(0.4) })))
	table.insert(keys, key("R", 1, "inout", st))
	return {
		strike = o.strike or 0.4,
		follow = 0.25,
		recover = 0.45,
		tremble = deg(1),
		flight = true,
		arc = o.arc,
		keys = keys,
	}
end

-- The Elite II throw (0.81): a short rear with one pump, the release on the hit.
local function throw(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local pivot = o.pivot or "rear"
	local rear = o.rear or deg(15)
	return {
		strike = 0.14,
		follow = 0.12,
		recover = 0.3,
		keys = {
			key("A", 0.5, "out", s({ [pivot] = rear, y = 0.04, nP = -deg(20) })),
			key("A", 0.8, "inout", s({ [pivot] = rear * 0.85, y = 0.04, gr = 0.04, nP = -deg(22) })),
			key("A", 1, "inout", s({ [pivot] = rear, y = 0.04, gr = 0, nP = -deg(20) })),
			key("S", 1, "in", s(with({ dip = o.snap or deg(6), z = 0.03, y = 0, nP = deg(15) }, pivot, 0))),
			key("F", 1, "out", s(with({ dip = (o.snap or deg(6)) * 0.5, z = 0.015, nP = deg(6) }, pivot, 0))),
			key("R", 1, "inout", st),
		},
	}
end

-- A new monster (SpawnedAt): fades in out of a crouch (a flyer drops in from above), rises, shakes itself off.
local function spawn(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local y0 = o.y or -0.15
	return {
		strike = 0.25,
		follow = 0.4,
		recover = 0.2,
		keys = {
			key("A", 0, "lin", s({ y = y0, sq = -0.1, alpha = 1 })),
			key("A", 0.8, "out", s({ y = y0 * 0.75, sq = -0.08, alpha = 0 })),
			key("S", 1, "out", s({ y = 0, sq = 0.04 })),
			key("F", 0.15, "inout", s({ shake = o.shake or deg(6) })),
			key("F", 0.8, "inout", s({ shake = o.shake or deg(6) })),
			key("F", 1, "inout", st),
			key("R", 1, "inout", st),
		},
	}
end

-- A boss's helper (Summoned): climbs out of the ground with a shiver (a flyer flutters up from it), a last hop.
local function summon(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local way = if o.fly then "fall" else "sink"
	return {
		strike = 0.2,
		follow = 0.3,
		recover = 0.3,
		keys = {
			key("A", 0, "lin", s({ [way] = 1, shiver = deg(2), sq = -0.06 })),
			key("S", 1, "out", s({ [way] = 0.05, shiver = deg(2) })),
			key("F", 0.4, "out", s({ [way] = 0, y = 0.1, sq = 0.08 })),
			key("F", 1, "in", s({ y = 0, sq = -0.08 })),
			key("R", 1, "inout", st),
		},
	}
end

-- Deaths (started on Dead, the hit = the strike; held). Each falls to the side of `deathSide` (Logic/RigidMotion).

-- Onto its back: a jolt, a flip with an arc (the box never under the ground), a bounce, two twitches.
local function deathFlip(o: { [string]: any }): Action
	local up = o.arc or 0.3
	return {
		strike = 0.12,
		follow = 0.43,
		recover = 0.25,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { y = 0.08, z = 0.03, rear = deg(5), ground = 1 }),
			key("F", 0.5, "out", { roll = -deg(90), y = up, z = 0.02, ground = 1 }),
			key("F", 1, "in", { roll = -deg(180), y = 0, ground = 1, settle = 1, sq = -0.12 }),
			key("R", 0.2, "out", { roll = -deg(176), y = 0.04, ground = 1 }),
			key("R", 0.4, "in", { roll = -deg(180), ground = 1, settle = 1 }),
			key("R", 0.6, "inout", { roll = -deg(184), ground = 1, settle = 1 }),
			key("R", 0.8, "inout", { roll = -deg(178), ground = 1, settle = 1 }),
			key("R", 1, "inout", { roll = -deg(180), ground = 1, settle = 1 }),
		},
	}
end

-- Curled (studio review 2026-10-26: a clear event): a jolt up, the legs fold under (squash, the body drops), it
-- topples about the ground edge onto its side, bounces once and settles curled, one last twitch.
local function deathCurl(o: { [string]: any }): Action
	local tip = o.tip or deg(75)
	return {
		strike = 0.12,
		follow = 0.5,
		recover = 0.35,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { y = 0.14, z = 0.03, rear = deg(8), sq = 0.06, ground = 1 }),
			key("F", 0.35, "in", { y = -0.04, sq = -0.3, dip = deg(5), tip = deg(12), ground = 1 }),
			key("F", 0.8, "in", { sq = -0.28, dip = deg(4), tip = tip, ground = 1, settle = 1 }),
			key("F", 1, "out", { sq = -0.24, tip = tip - deg(8), y = 0.04, ground = 1 }),
			key("R", 0.3, "in", { sq = -0.28, dip = deg(4), tip = tip, ground = 1, settle = 1 }),
			key("R", 0.6, "inout", { sq = -0.32, dip = deg(4), tip = tip, shiver = deg(3), ground = 1, settle = 1 }),
			key("R", 1, "inout", { sq = -0.3, dip = deg(4), tip = tip, ground = 1, settle = 1 }),
		},
	}
end

-- Onto its side (§3.8): a jolt, the legs buckle (squash, the body drops), it rolls 85° about the ground line under
-- that flank (gravity), bounces and twitches.
local function deathSide(o: { [string]: any }): Action
	local tip = o.tip or deg(85)
	return {
		strike = 0.12,
		follow = 0.43,
		recover = 0.25,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { rear = deg(8), z = 0.05, y = 0.02 }),
			key("F", 0.5, "in", { y = o.buckle or -0.05, sq = -0.12, dip = deg(5), tip = deg(10), ground = 1 }),
			key("F", 1, "in", { sq = -0.06, tip = tip, ground = 1, settle = 1 }),
			key("R", 0.3, "out", { tip = tip - deg(5), y = 0.03, ground = 1 }),
			key("R", 0.6, "in", { tip = tip, ground = 1, settle = 1 }),
			key("R", 0.8, "inout", { tip = tip, dip = deg(3), ground = 1, settle = 1 }),
			key("R", 1, "inout", { tip = tip, ground = 1, settle = 1 }),
		},
	}
end

-- A tree's fall: a jolt back, it topples 85° about its base edge with gravity, bounces and starts to fade.
local function deathTopple(o: { [string]: any }): Action
	local tip = o.tip or deg(85)
	return {
		strike = 0.12,
		follow = 0.55,
		recover = 0.25,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { bow = deg(4), y = 0.005 }),
			key("F", 0.15, "out", { bow = deg(2), tip = deg(4) }),
			key("F", 0.75, "in", { tip = tip, ground = 1, settle = 1 }),
			key("F", 0.88, "out", { tip = tip - deg(5), ground = 1 }),
			key("F", 1, "in", { tip = tip, ground = 1, settle = 1 }),
			key("R", 1, "inout", { tip = tip, ground = 1, settle = 1, alpha = 0.35 }),
		},
	}
end

-- A flyer drops dead: a jolt, it falls with gravity spinning, hits the ground, bounces and rolls onto its side or back.
local function deathFall(o: { [string]: any }): Action
	local roll, spin = o.roll or deg(100), o.spin or deg(360)
	return {
		strike = 0.1,
		follow = 0.4,
		recover = 0.3,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { pitch = deg(10), y = 0.08 }),
			-- gravity: a quarter of the fall by half the time, the spin steady
			key(
				"F",
				0.5,
				"inout",
				{ fall = 0.25, spin = spin * 0.45, roll = -roll * 0.3, pitch = -deg(15), ground = 1 }
			),
			key("F", 1, "lin", { fall = 1, spin = spin, roll = -roll * 0.6, pitch = -deg(30), ground = 1, sq = -0.15 }),
			key(
				"R",
				0.15,
				"out",
				{ fall = 1, spin = spin, roll = -roll * 0.8, pitch = -deg(15), y = 0.12, ground = 1 }
			),
			key("R", 0.35, "in", { fall = 1, spin = spin, roll = -roll, ground = 1, settle = 1 }),
			key("R", 1, "inout", { fall = 1, spin = spin, roll = -roll, ground = 1, settle = 1 }),
		},
	}
end

-- A serpent's death: the head rears, then it sinks onto its side, the tail stills, a fade begins.
local function deathSink(o: { [string]: any }): Action
	return {
		strike = 0.12,
		follow = 0.35,
		recover = 0.33,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { rear = deg(10), y = 0.02, nP = -deg(20) }),
			key("F", 1, "inout", { tip = deg(40), y = -0.02, nP = deg(40), calmTail = 1, ground = 1 }),
			key(
				"R",
				1,
				"inout",
				{ tip = o.tip or deg(80), nP = deg(60), calmTail = 1, ground = 1, settle = 1, alpha = 0.3 }
			),
		},
	}
end

-- A serpent's death throes: it rears, thrashes from side to side (the tail curling), flops onto its side, stills.
local function deathWrithe(o: { [string]: any }): Action
	local tip = o.tip or deg(70)
	return {
		strike = 0.12,
		follow = 0.5,
		recover = 0.35,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { rear = deg(14), y = 0.03, nP = -deg(25), tC = deg(20) }),
			key("F", 0.25, "inout", { rear = deg(8), wig = deg(18), tC = deg(30), nY = deg(20) }),
			key("F", 0.5, "inout", { rear = deg(5), wig = -deg(14), tC = -deg(20), nY = -deg(15) }),
			key("F", 0.75, "inout", { rear = deg(3), wig = deg(9), tC = deg(15), nY = deg(10), calmTail = 0.5 }),
			key("F", 1, "in", { wig = deg(3), tip = tip, nP = deg(50), calmTail = 1, ground = 1, settle = 1 }),
			key("R", 0.3, "out", { wig = deg(3), tip = tip - deg(6), nP = deg(45), calmTail = 1, ground = 1 }),
			key(
				"R",
				1,
				"inout",
				{ wig = deg(3), tip = tip, nP = deg(55), calmTail = 1, ground = 1, settle = 1, alpha = 0.25 }
			),
		},
	}
end

-- A last leap: it springs up, lands nose first, rolls onto its side, the hind legs kick (shivers).
local function deathHop(o: { [string]: any }): Action
	local tip = o.tip or deg(85)
	return {
		strike = 0.15,
		follow = 0.45,
		recover = 0.5,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { y = o.up or 0.3, rear = deg(15), sq = 0.08 }),
			key("F", 0.45, "in", { dip = deg(10), sq = -0.12, tip = deg(20), ground = 1 }),
			key("F", 1, "in", { tip = tip, sq = -0.04, ground = 1, settle = 1 }),
			key("R", 0.25, "inout", { tip = tip, shiver = deg(4), ground = 1, settle = 1 }),
			key("R", 0.5, "inout", { tip = tip, ground = 1, settle = 1 }),
			key("R", 0.7, "inout", { tip = tip, shiver = deg(3), ground = 1, settle = 1 }),
			key("R", 1, "inout", { tip = tip, ground = 1, settle = 1 }),
		},
	}
end

-- A tree falling on its face: a jolt back, it topples forward about the front of its roots with gravity, a twist, a
-- bounce, it starts to fade.
local function deathFallForward(o: { [string]: any }): Action
	local dip = o.dip or deg(82)
	return {
		strike = 0.12,
		follow = 0.55,
		recover = 0.25,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { rear = deg(4), y = 0.005 }),
			key("F", 0.15, "out", { rear = deg(2), dip = deg(3), yaw = deg(3) }),
			key("F", 0.75, "in", { dip = dip, yaw = deg(8), ground = 1, settle = 1 }),
			key("F", 0.88, "out", { dip = dip - deg(4), yaw = deg(8), ground = 1 }),
			key("F", 1, "in", { dip = dip, yaw = deg(8), ground = 1, settle = 1 }),
			key("R", 1, "inout", { dip = dip, yaw = deg(8), ground = 1, settle = 1, alpha = 0.35 }),
		},
	}
end

-- The legs give way: a jolt, it sinks flat (squash), the head end drops, it slumps onto a flank.
local function deathSlump(o: { [string]: any }): Action
	local tip = o.tip or deg(20)
	return {
		strike = 0.12,
		follow = 0.5,
		recover = 0.4,
		hold = true,
		sided = true,
		keys = {
			key("S", 1, "out", { rear = deg(6), y = 0.03, z = 0.03 }),
			key("F", 0.5, "in", { sq = -0.15, dip = deg(5), tip = deg(5), ground = 1 }),
			key("F", 1, "inout", { sq = -0.13, dip = deg(7), tip = tip, ground = 1, settle = 1 }),
			key("R", 0.4, "inout", { sq = -0.13, dip = deg(6), tip = tip - deg(3), ground = 1, settle = 1 }),
			key("R", 1, "inout", { sq = -0.13, dip = deg(8), tip = tip, ground = 1, settle = 1 }),
		},
	}
end

-- Idle fidgets (hit 0.5: a pause, the move on the hit, a hold, back), laid over the idle (additive).
local function fidget(pose: Pose, holdFor: number, o: { [string]: any }?): Action
	local over: { [string]: any } = o or {}
	local keys = { key("A", 0, "lin", {}), key("S", 1, over.ease or "out", pose) }
	local mid = over.mid
	if mid then
		table.insert(keys, key("F", 0.5, "inout", mid))
	end
	table.insert(keys, key("F", 1, "inout", over.last or pose))
	table.insert(keys, key("R", 1, "inout", {}))
	return {
		strike = over.strike or 0.12,
		follow = holdFor,
		recover = over.recover or 0.25,
		keys = keys,
		additive = true,
	}
end

---------------------------------------------------------------- spider (caveSpider)

-- Low and spread, the front a little up and ready.
local SPIDER_STANCE: Pose = { y = -0.03, rear = deg(3) }

local SPIDER: Style = {
	fly = false,
	order = { "skitter" },
	thresholds = {},
	band = 0.3,
	gaits = {
		-- 8 legs in two alternating tetrads: two bumps a cycle, the sway as the tetrads swap, spurts
		skitter = gait({
			stride = 0.3,
			maxRate = 5.5,
			bumps = 2,
			bob = 0.04,
			sharp = 0.7,
			roll = deg(2.5),
			yaw = deg(1.5),
			yawLag = 0.25,
			pitch = deg(-5),
		}),
	},
	burst = { hz = 0.8, bob = 0.3, surge = 0.02 },
	start = 0.05,
	stop = { over = 0.015, wobble = deg(2) },
	turn = { omega = 14, bank = 0.035, bankMax = deg(6) },
	idle = { breath = 0.01, rate = 0.5, sway = deg(0.5), shift = 0, crouch = -0.02, look = deg(8) },
	stance = SPIDER_STANCE,
	calm = { pitch = deg(-2) },
	flinch = { push = 0.03, tilt = deg(10), drop = -0.03, squash = -0.05 },
	stun = { roll = deg(6), pitch = deg(3), hz = 1.1, drop = -0.04, twitch = deg(6) },
	basic = { "bite" },
	abilities = { poisonPool = "pool", heavyBlow = "heavy", crush = "crush", pounce = "pounce" },
	throw = "spit",
	death = { { name = "deathFlip", weight = 0.6 }, { name = "deathCurl", weight = 0.4 } },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "twitch", "settle", "taste" },
	fidgetEvery = { 2, 6 },
	rate = 0.04,
	lunge = { min = 0.09, max = 0.45 },
	flightPitch = { deg(25), deg(30) },
	footprint = 0.85,
	wigPivot = 0,
	actions = {
		alert = alert(SPIDER_STANCE, { rear = deg(18), shiver = deg(1), thump = -0.03, squash = -0.08 }),
		bite = bite(SPIDER_STANCE, { rear = deg(14), up = 0.05, back = 0.03, slam = deg(10), hop = 0.1 }),
		pool = cast(SPIDER_STANCE, { rear = deg(22), up = 0.1, pump = deg(3), snap = deg(8), recoil = 0.04 }),
		heavy = heavy(SPIDER_STANCE, { rear = deg(25), weave = deg(8), slam = deg(12), sweep = deg(30) }),
		crush = crush(SPIDER_STANCE, { rear = deg(30), slam = deg(12) }),
		pounce = pounce(SPIDER_STANCE, { crouch = -0.08, dip = deg(6), wiggle = deg(4) }),
		spit = throw(SPIDER_STANCE, { rear = deg(15) }),
		spawn = spawn(SPIDER_STANCE, {}),
		summon = summon(SPIDER_STANCE, {}),
		deathFlip = deathFlip({}),
		deathCurl = deathCurl({}),
		twitch = fidget({ yaw = deg(5) }, 0.8),
		settle = fidget({ y = -0.03, sq = -0.04 }, 0.2, { strike = 0.1, last = { y = 0.004 } }),
		taste = fidget({ rear = deg(6), y = 0.01 }, 0.6, { strike = 0.2 }),
	},
}

---------------------------------------------------------------- scorpion (desertScorpion)

-- Pincers forward, the sting held high (the front a touch down).
local SCORPION_STANCE: Pose = { y = -0.02, dip = deg(3) }

local function pincer(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.13,
		follow = 0.18,
		recover = 0.28,
		keys = {
			key("A", 1, "out", s({ dip = 0, rear = deg(10), z = 0.03, y = 0.03, shiver = deg(0.8) })),
			key("S", 1, "in", s({ dip = deg(4), rear = 0, lunge = 1, y = 0, sq = -0.06 })),
			key("F", 0.5, "out", s({ dip = deg(4), lunge = 1, shiver = deg(1.2) })),
			key("F", 1, "inout", s({ dip = deg(3), lunge = 0.85 })),
			key("R", 1, "inout", st),
		},
	}
end

-- The sting: nose down (the tail goes up and over), drawn back, a jab forward on the hit.
local function sting(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.12,
		follow = 0.15,
		recover = 0.3,
		keys = {
			key("A", 0.7, "out", s({ dip = deg(10), z = 0.04, shiver = deg(0.6) })),
			key("A", 1, "lin", s({ dip = deg(11), z = 0.045, shiver = deg(1.2) })),
			key("S", 1, "in", s({ dip = deg(15), z = 0, lunge = 1, sl = 0.08 })),
			key("F", 1, "out", s({ dip = deg(12), lunge = 0.9 })),
			key("R", 1, "inout", st),
		},
	}
end

local SCORPION: Style = {
	fly = false,
	order = { "skitter" },
	thresholds = {},
	band = 0.3,
	gaits = {
		skitter = gait({
			stride = 0.35,
			maxRate = 4.5,
			bumps = 2,
			bob = 0.03,
			sharp = 0.8,
			roll = deg(2),
			yaw = deg(1),
			yawLag = 0.25,
			pitch = deg(-3),
			surge = 0.01,
		}),
	},
	burst = { hz = 0.6, bob = 0.2, surge = 0.012 },
	start = 0.04,
	stop = { over = 0.012, wobble = deg(1.5) },
	turn = { omega = 12, bank = 0.03, bankMax = deg(5) },
	idle = { breath = 0.008, rate = 0.4, sway = deg(0.4), shift = 0, crouch = -0.01, look = deg(8) },
	stance = SCORPION_STANCE,
	calm = { dip = 0 },
	flinch = { push = 0.025, tilt = deg(8), drop = -0.025, squash = -0.05 },
	stun = { roll = deg(5), pitch = deg(3), hz = 1, drop = -0.04, twitch = deg(5) },
	basic = { "pincer", "sting" },
	abilities = { poisonPool = "pool", heavyBlow = "heavy", crush = "crush", pounce = "pounce" },
	throw = "spit",
	death = { { name = "deathFlip", weight = 0.5 }, { name = "deathCurl", weight = 0.5 } },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "twitch", "settle", "tail" },
	fidgetEvery = { 3, 7 },
	rate = 0.04,
	lunge = { min = 0.08, max = 0.4 },
	flightPitch = { deg(20), deg(25) },
	footprint = 0.85,
	wigPivot = 0,
	actions = {
		alert = alert(SCORPION_STANCE, { pivot = "dip", rear = deg(12), shiver = deg(1.2), thump = -0.02 }),
		pincer = pincer(SCORPION_STANCE),
		sting = sting(SCORPION_STANCE),
		-- venom from the sting: the tail high over the back (nose down), pumps, a squirt on the hit
		pool = cast(
			SCORPION_STANCE,
			{ pivot = "dip", rear = deg(12), up = 0.04, pump = deg(3), snap = deg(16), lunge = 0.3 }
		),
		heavy = heavy(SCORPION_STANCE, { rear = deg(18), weave = deg(6), slam = deg(10), sweep = deg(30) }),
		crush = crush(SCORPION_STANCE, { rear = deg(22), slam = deg(12) }),
		pounce = pounce(SCORPION_STANCE, { crouch = -0.06, dip = deg(4), wiggle = deg(3), arc = 0.8 }),
		spit = throw(SCORPION_STANCE, { pivot = "dip", rear = deg(12), snap = deg(14) }),
		spawn = spawn(SCORPION_STANCE, {}),
		summon = summon(SCORPION_STANCE, {}),
		deathFlip = deathFlip({ arc = 0.25 }),
		deathCurl = deathCurl({ tip = deg(70) }),
		twitch = fidget({ yaw = deg(4) }, 0.8),
		settle = fidget({ y = -0.03, sq = -0.04 }, 0.2, { strike = 0.1, last = { y = 0.004 } }),
		tail = fidget({ dip = deg(5), shiver = deg(0.6) }, 0.5, { strike = 0.2 }),
	},
}

---------------------------------------------------------------- lizard (basilisk, salamander)

local LIZARD_STANCE: Pose = { y = -0.01, rear = deg(4) }

local LIZARD: Style = {
	fly = false,
	order = { "waddle", "sprint" },
	thresholds = { 2.0 },
	band = 0.35,
	gaitOf = { walk = "waddle", trot = "waddle", run = "sprint" },
	gaits = {
		-- the sprawling walk: the body swings about its middle, the head and tail opposite
		waddle = gait({
			stride = 0.8,
			maxRate = 3.5,
			bumps = 2,
			bob = 0.02,
			roll = deg(3),
			yaw = deg(10),
			yawLag = 0,
			sway = 0.035,
			pitch = deg(-2),
		}),
		-- running: longer bounds, the head up, less swing
		sprint = gait({
			stride = 1.0,
			maxRate = 4,
			bumps = 2,
			bob = 0.03,
			sharp = 0.8,
			roll = deg(2),
			yaw = deg(7),
			yawLag = 0,
			sway = 0.025,
			pitch = deg(3),
		}),
	},
	burst = { hz = 0.5, bob = 0.15, surge = 0.015 },
	start = 0.04,
	stop = { over = 0.02, wobble = deg(2) },
	turn = { omega = 12, bank = 0.03, bankMax = deg(5) },
	idle = { breath = 0.008, rate = 0.35, sway = deg(0.4), shift = 0, crouch = -0.01, look = deg(10) },
	stance = LIZARD_STANCE,
	calm = { rear = 0 },
	flinch = { push = 0.03, tilt = deg(9), drop = -0.03, squash = -0.05 },
	stun = { roll = deg(6), pitch = deg(3), hz = 1.1, drop = -0.04, twitch = deg(8) },
	basic = { "bite" },
	abilities = {
		poisonPool = "spit",
		fireBreath = "breath",
		heavyBlow = "heavy",
		crush = "crush",
		pounce = "pounce",
	},
	throw = "spitShot",
	death = { { name = "deathFlip", weight = 0.7 }, { name = "deathSide", weight = 0.3 } },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "pushups", "headUp", "twitch" },
	fidgetEvery = { 5, 10 },
	rate = 0.05,
	lunge = { min = 0.1, max = 0.5 },
	flightPitch = { deg(20), deg(25) },
	footprint = 0.8,
	wigPivot = 0,
	actions = {
		alert = alert(LIZARD_STANCE, { rear = deg(12), up = 0.04, shiver = deg(0.8) }),
		bite = snap(LIZARD_STANCE, { wind = deg(12), snap = deg(20) }),
		-- the front rises about the hind feet, held with a shiver, the spit or the stream forward with a recoil
		spit = cast(
			LIZARD_STANCE,
			{ rear = deg(15), up = 0.03, pump = deg(2), snap = deg(6), recoil = 0.04, neck = 0 }
		),
		breath = cast(
			LIZARD_STANCE,
			{ rear = deg(15), up = 0.03, pump = deg(1.5), snap = deg(6), recoil = 0.05, hold = 0.35, pumps = 2 }
		),
		heavy = heavy(LIZARD_STANCE, { rear = deg(18), weave = deg(10), slam = deg(8), sweep = deg(40) }),
		crush = crush(LIZARD_STANCE, { rear = deg(22), slam = deg(10) }),
		pounce = pounce(LIZARD_STANCE, { crouch = -0.06, dip = deg(4), wiggle = deg(6) }),
		spitShot = throw(LIZARD_STANCE, { rear = deg(12) }),
		spawn = spawn(LIZARD_STANCE, {}),
		summon = summon(LIZARD_STANCE, {}),
		deathFlip = deathFlip({ arc = 0.35 }),
		deathSide = deathSide({ tip = deg(80) }),
		pushups = fidget(
			{ y = 0.05, rear = deg(4) },
			0.35,
			{ strike = 0.16, mid = { y = 0, rear = deg(2) }, last = { y = 0.05, rear = deg(4) } }
		),
		headUp = fidget({ rear = deg(8), y = 0.01 }, 1.0, { strike = 0.25 }),
		twitch = fidget({ wig = deg(6) }, 0.7),
	},
}

---------------------------------------------------------------- serpent (bogSerpent; frostWyrm with bones)

local SERPENT_STANCE: Pose = { rear = deg(6) }

local SERPENT: Style = {
	fly = false,
	order = { "slither" },
	thresholds = {},
	band = 0.3,
	gaits = {
		-- the body swings about a point behind the head (the head stays, the tail sweeps)
		slither = gait({
			stride = 0.9,
			maxRate = 3,
			bumps = 2,
			bob = 0.008,
			roll = deg(4),
			rollPhase = 0.25,
			yaw = deg(12),
			yawLag = 0,
			sway = 0.03,
		}),
	},
	start = 0.02,
	stop = { over = 0.02, wobble = deg(2) },
	turn = { omega = 10, bank = 0.03, bankMax = deg(5) },
	idle = {
		breath = 0.008,
		rate = 0.3,
		sway = 0,
		shift = 0,
		crouch = 0,
		look = deg(6),
		-- the cobra sway in place
		weave = { yaw = deg(10), pitch = deg(2), hz = 0.4, bones = 0.25 },
	},
	stance = SERPENT_STANCE,
	calm = { rear = 0 },
	flinch = { push = 0.03, tilt = deg(8), drop = -0.02, squash = -0.04 },
	stun = { roll = deg(6), pitch = deg(4), hz = 0.9, drop = -0.03, twitch = deg(8) },
	basic = { "strike" },
	abilities = {
		poisonPool = "spit",
		frostBreath = "breath",
		heavyBlow = "heavy",
		crush = "crush",
		pounce = "pounce",
	},
	throw = "spitShot",
	death = { { name = "deathSink", weight = 0.6 }, { name = "deathWrithe", weight = 0.4 } },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "coil", "taste" },
	fidgetEvery = { 4, 9 },
	rate = 0.05,
	lunge = { min = 0.1, max = 0.5 },
	flightPitch = { deg(15), deg(20) },
	footprint = 0.7,
	wigPivot = -0.15,
	-- frostWyrm's skeleton: a wave down the tail and the coil, the neck sways (Data/RigidRigs)
	bones = {
		stride = 0.9,
		idleHz = 0.15,
		idle = deg(5),
		move = deg(16),
		coil = 0.5,
		lag = 0.11,
		sway = deg(10),
		swayHz = 0.4,
		body = 0.25,
	},
	actions = {
		alert = alert(SERPENT_STANCE, { rear = deg(16), up = 0.03, shiver = deg(1.2), thump = -0.01, squash = -0.05 }),
		strike = strike(SERPENT_STANCE, {}),
		spit = cast(
			SERPENT_STANCE,
			{ rear = deg(15), up = 0.03, pump = deg(2), snap = deg(6), recoil = 0.05, neck = deg(25) }
		),
		breath = cast(
			SERPENT_STANCE,
			{ rear = deg(15), up = 0.03, pump = deg(1.5), snap = deg(6), recoil = 0.05, hold = 0.35, pumps = 2 }
		),
		heavy = heavy(SERPENT_STANCE, { rear = deg(18), weave = deg(12), slam = deg(8), sweep = deg(36) }),
		crush = crush(SERPENT_STANCE, { rear = deg(22), slam = deg(10) }),
		pounce = pounce(SERPENT_STANCE, { crouch = -0.04, dip = deg(3), wiggle = deg(8), arc = 0.7 }),
		spitShot = throw(SERPENT_STANCE, { rear = deg(12) }),
		spawn = spawn(SERPENT_STANCE, {}),
		summon = summon(SERPENT_STANCE, {}),
		deathSink = deathSink({}),
		deathWrithe = deathWrithe({}),
		coil = fidget({ tC = deg(25), wig = deg(5), rear = deg(3) }, 1.0, { strike = 0.3 }),
		taste = fidget({ rear = deg(10), nP = -deg(15), shiver = deg(0.6) }, 0.6, { strike = 0.2 }),
	},
}

---------------------------------------------------------------- rigid flyers (carrionCrow, bloodBat)

-- Shared flyer blows: the body sells the flight (no wings to beat).
local FLYER_STANCE: Pose = { y = 0.05, pitch = deg(-4) }

-- A ranged shot: a flare up (nose up), a thrust forward on the release, a recoil.
local function shot(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.14,
		follow = 0.15,
		recover = 0.25,
		keys = {
			key("A", 1, "out", s({ y = 0.2, pitch = deg(20), z = 0.05, shiver = deg(0.8) })),
			key("S", 1, "in", s({ y = 0.05, pitch = deg(-12), z = -0.1 })),
			key("F", 1, "out", s({ y = 0.08, pitch = deg(-5), z = 0.15 })),
			key("R", 1, "inout", st),
		},
	}
end

-- A dive at the target: up in the anticipation, a swoop forward and down along an arc to contact on the hit, back up.
local function dive(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = o.strike or 0.18,
		follow = 0.12,
		recover = 0.35,
		keys = {
			key("A", 1, "out", s({ y = o.up or 0.25, pitch = deg(10), z = 0.06 })),
			key("S", 0.5, "in", s({ y = (o.up or 0.25) * 0.2, pitch = deg(-25), lunge = 0.55 })),
			key("S", 1, "in", s({ y = o.down or -0.2, pitch = deg(-15), lunge = 1, sq = -0.08 })),
			key("F", 1, "out", s({ y = (o.down or -0.2) * 0.5, pitch = deg(5), lunge = 0.9, shiver = deg(1) })),
			key("R", 0.5, "out", s({ y = 0.15, pitch = deg(8), lunge = 0.3 })),
			key("R", 1, "inout", st),
		},
	}
end

-- Wail (Elite II own, 1.2): rears back and grows, trembling; thrusts forward on the hit with a recoil, screaming.
local function wail(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.14,
		follow = 0.3,
		recover = 0.35,
		tremble = deg(2),
		keys = {
			key("A", 0.25, "out", s({ y = 0.35, pitch = deg(25), gr = 0.06 })),
			key("A", 1, "inout", s({ y = 0.38, pitch = deg(25), gr = 0.08 })),
			key("S", 1, "in", s({ y = 0.2, pitch = deg(-15), z = -0.12, gr = 0.04 })),
			key("F", 0.6, "out", s({ y = 0.22, pitch = deg(-8), z = 0.15, gr = 0.02, shake = deg(4) })),
			key("F", 1, "inout", s({ y = 0.15, pitch = deg(-4), z = 0.08 })),
			key("R", 1, "inout", st),
		},
	}
end

-- Heavy Blow (Elite, 1.8) "talon rake": up and hovering, trembling, a swoop forward and down on the hit.
local function rake(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.14,
		follow = 0.15,
		recover = 0.5,
		tremble = deg(1.5),
		keys = {
			key("A", 0.65, "out", s({ y = 0.6, pitch = deg(15) })),
			key("A", 1, "inout", s({ y = 0.62, pitch = deg(18), shiver = deg(1) })),
			key("S", 1, "in", s({ y = -0.35, pitch = deg(-20), lunge = 1, sq = -0.08 })),
			key("F", 1, "out", s({ y = -0.1, pitch = deg(8), lunge = 0.8 })),
			key("R", 1, "inout", st),
		},
	}
end

-- Crush (Elite II, 2.2) "stoop": climbs high turning on the target, folds (nose down), dives along an arc to just over
-- the ground on the hit, pulls up.
local function stoop(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.3,
		follow = 0.2,
		recover = 0.5,
		tremble = deg(1.5),
		keys = {
			key("A", 0.6, "out", s({ y = 2.0, pitch = deg(10) })),
			key("A", 0.85, "inout", s({ y = 2.1, pitch = deg(-40), sl = 0.06 })),
			key("A", 1, "inout", s({ y = 2.1, pitch = deg(-50), sl = 0.08 })),
			key("S", 1, "in", s({ y = 0, fall = 0.8, pitch = deg(20), lunge = 1, sq = -0.1 })),
			key("F", 1, "out", s({ y = 0.2, fall = 0.6, pitch = deg(15), lunge = 0.8 })),
			key("R", 1, "inout", st),
		},
	}
end

local CROW_STANCE: Pose = FLYER_STANCE

local CROW: Style = {
	fly = true,
	order = { "hover", "flight" },
	thresholds = { 1.5 },
	band = 0.5,
	gaits = {
		-- a vibrato: the body bobs and nods with the hidden beat
		hover = gait({
			stride = 1,
			hz = 4,
			bumps = 1,
			bob = 0.042,
			sine = true,
			pitchWave = deg(4),
			pitchBumps = 1,
			pitchPhase = 0.25,
		}),
		flight = gait({
			stride = 1,
			hz = 4.5,
			bumps = 1,
			bob = 0.05,
			sine = true,
			pitchWave = deg(3),
			pitchBumps = 1,
			pitchPhase = 0.25,
			pitch = deg(-10),
			roll = deg(2),
		}),
	},
	start = 0,
	stop = { over = 0.04, wobble = deg(4) },
	turn = { omega = 8, bank = 0.35, bankMax = deg(25) },
	idle = {
		breath = 0,
		rate = 0.3,
		sway = 0,
		shift = 0,
		crouch = 0,
		look = deg(12),
		drift = { x = 0.1, y = 0.06, z = 0.06, yaw = deg(6), hz = 0.2 },
	},
	stance = CROW_STANCE,
	calm = { pitch = deg(-6) },
	flinch = { push = 0.23, tilt = deg(12), drop = -0.17, squash = -0.05 },
	stun = { roll = deg(8), pitch = deg(4), hz = 0.9, drop = -0.42, twitch = deg(10) },
	basic = { "shot" },
	abilities = { wail = "wail", heavyBlow = "rake", crush = "stoop", pounce = "pounce" },
	throw = "shot",
	death = { { name = "deathFall", weight = 0.6 }, { name = "deathFallBack", weight = 0.4 } },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "preen", "look" },
	fidgetEvery = { 3, 7 },
	rate = 0.06,
	lunge = { min = 0.1, max = 1.5 },
	flightPitch = { deg(25), deg(35) },
	footprint = 0.8,
	wigPivot = 0,
	actions = {
		alert = alert(
			CROW_STANCE,
			{ pivot = "pitch", rear = deg(15), up = 0.25, shiver = deg(1.5), thump = 0, squash = 0 }
		),
		shot = shot(CROW_STANCE),
		wail = wail(CROW_STANCE),
		rake = rake(CROW_STANCE),
		stoop = stoop(CROW_STANCE),
		pounce = pounce(CROW_STANCE, { crouch = -0.1, dip = 0, wiggle = deg(5), arc = 0.6 }),
		spawn = spawn(CROW_STANCE, { y = 0.5, shake = deg(5) }),
		summon = summon(CROW_STANCE, { fly = true }),
		deathFall = deathFall({ roll = deg(100) }),
		deathFallBack = deathFall({ roll = deg(180), spin = deg(300) }),
		preen = fidget({ pitch = deg(-15), roll = deg(10), shiver = deg(0.8) }, 0.7, { strike = 0.2 }),
		look = fidget({ yaw = deg(25) }, 0.9, { strike = 0.1 }),
	},
}

local BAT: Style = table.clone(CROW)
BAT.gaits = {
	-- an erratic flutter: a fast bob with jitter
	hover = gait({
		stride = 1,
		hz = 6,
		bumps = 1,
		bob = 0.042,
		sine = true,
		pitchWave = deg(3),
		pitchBumps = 1,
		pitchPhase = 0.25,
		jitter = 0.03,
		jitterHz = 3,
	}),
	flight = gait({
		stride = 1,
		hz = 6.5,
		bumps = 1,
		bob = 0.05,
		sine = true,
		pitchWave = deg(3),
		pitchBumps = 1,
		pitchPhase = 0.25,
		pitch = deg(-12),
		jitter = 0.02,
		jitterHz = 3.5,
	}),
}
BAT.idle = {
	breath = 0,
	rate = 0.3,
	sway = 0,
	shift = 0,
	crouch = 0,
	look = deg(15),
	drift = { x = 0.12, y = 0.08, z = 0.06, yaw = deg(10), hz = 0.27 },
}
BAT.basic = { "dive" }
BAT.throw = "dive"
BAT.death = { { name = "deathFallBack", weight = 0.7 }, { name = "deathFall", weight = 0.3 } }
BAT.fidgets = { "flutter", "look" }
BAT.fidgetEvery = { 2, 5 }
BAT.lunge = { min = 0.15, max = 1.4 }
BAT.actions = table.clone(CROW.actions)
BAT.actions.dive = dive(CROW_STANCE, { up = 0.25, down = -0.2 })
BAT.actions.flutter = fidget({ y = 0.15, shake = deg(5) }, 0.4, { strike = 0.12 })

---------------------------------------------------------------- toad (swampToad)

local TOAD_STANCE: Pose = { y = -0.02, rear = deg(3) }

-- The basic "squash": squeezed down, then a lunge with a stretch on the hit, the landing squash.
local function squashBlow(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.16,
		follow = 0.15,
		recover = 0.3,
		keys = {
			key("A", 1, "out", s({ y = -0.06, sq = -0.12, rear = 0, z = 0.03 })),
			key("S", 0.5, "out", s({ y = 0.12, sq = 0.1, rear = deg(8), lunge = 0.6 })),
			key("S", 1, "in", s({ y = 0, sq = 0.06, sl = 0.08, rear = 0, dip = deg(4), lunge = 1 })),
			key("F", 0.5, "out", s({ y = -0.02, sq = -0.1, lunge = 1 })),
			key("F", 1, "inout", s({ lunge = 0.9 })),
			key("R", 1, "inout", st),
		},
	}
end

-- The toad's spit: it inflates with a shiver (the throat swells), a recoil on the release.
local function inflate(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.14,
		follow = 0.2,
		recover = 0.35,
		tremble = o.tremble or deg(1.2),
		keys = {
			key("A", 0.35, "out", s({ gr = 0.05, sq = -0.04, rear = deg(5) })),
			key("A", 1, "inout", s({ gr = 0.08, sq = -0.06, rear = deg(8), shiver = deg(0.6) })),
			key("S", 1, "in", s({ gr = -0.02, sq = 0.05, rear = 0, dip = deg(5), z = 0.05 })),
			key("F", 1, "out", s({ gr = 0, sq = -0.04, dip = deg(2), z = 0.03 })),
			key("R", 1, "inout", st),
		},
	}
end

local TOAD: Style = {
	fly = false,
	order = { "hop" },
	thresholds = {},
	band = 0.3,
	gaits = {
		hop = gait({
			stride = 0.5,
			maxRate = 3,
			bumps = 1,
			hop = {
				ground = 0.4,
				height = 0.35,
				maxHeight = 0.4,
				crouch = 0.08,
				squash = 0.15,
				stretch = 0.1,
				pitchUp = deg(12),
				pitchDown = deg(8),
			},
		}),
	},
	start = 0.06,
	stop = { over = 0.01, wobble = deg(2) },
	turn = { omega = 10, bank = 0.02, bankMax = deg(3) },
	idle = { breath = 0.015, rate = 0.6, sway = 0, shift = 0, crouch = 0, look = deg(6) },
	stance = TOAD_STANCE,
	calm = {},
	flinch = { push = 0.03, tilt = deg(8), drop = -0.04, squash = -0.08 },
	stun = { roll = deg(5), pitch = deg(3), hz = 1, drop = -0.04, twitch = deg(6) },
	basic = { "squash" },
	abilities = { poisonPool = "spit", heavyBlow = "heavy", crush = "crush", pounce = "pounce" },
	throw = "spitShot",
	death = { { name = "deathFlip", weight = 0.7 }, { name = "deathCurl", weight = 0.3 } },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "settle", "gulp" },
	fidgetEvery = { 3, 8 },
	rate = 0.05,
	lunge = { min = 0.1, max = 0.45 },
	flightPitch = { deg(20), deg(20) },
	footprint = 0.8,
	wigPivot = 0,
	actions = {
		alert = alert(TOAD_STANCE, { rear = deg(10), up = 0.03, shiver = deg(0.8), squash = -0.1 }),
		squash = squashBlow(TOAD_STANCE),
		spit = inflate(TOAD_STANCE, {}),
		heavy = heavy(TOAD_STANCE, { rear = deg(15), weave = deg(6), slam = deg(8), sweep = deg(20) }),
		crush = crush(TOAD_STANCE, { rear = deg(18), slam = deg(8) }),
		pounce = pounce(TOAD_STANCE, { crouch = -0.1, dip = 0, wiggle = deg(3) }),
		spitShot = inflate(TOAD_STANCE, { tremble = 0 }),
		spawn = spawn(TOAD_STANCE, {}),
		summon = summon(TOAD_STANCE, {}),
		deathFlip = deathFlip({ arc = 0.3 }),
		deathCurl = deathCurl({ tip = deg(60) }),
		settle = fidget(
			{ roll = deg(3), y = -0.02 },
			0.4,
			{ strike = 0.12, mid = { roll = deg(-3), y = -0.02 }, last = { y = -0.01 } }
		),
		gulp = fidget({ gr = 0.04, y = 0.01 }, 0.25, { strike = 0.15, last = { gr = 0 } }),
	},
}

---------------------------------------------------------------- hare (rabbit, §8)

local HARE_STANCE: Pose = { y = -0.04, dip = deg(3) }

local HARE: Style = {
	fly = false,
	order = { "bound" },
	thresholds = {},
	band = 0.3,
	gaits = {
		-- a bound: the hind feet push together, the fore feet land first (nose down), the body arcs
		bound = gait({
			stride = 0.8,
			maxRate = 4,
			bumps = 1,
			hop = {
				ground = 0.3,
				height = 0.3,
				maxHeight = 0.3,
				crouch = 0.06,
				squash = 0.12,
				stretch = 0.12,
				pitchUp = deg(14),
				pitchDown = deg(12),
			},
		}),
	},
	start = 0.06,
	stop = { over = 0.02, wobble = deg(2) },
	turn = { omega = 14, bank = 0.02, bankMax = deg(3) },
	idle = { breath = 0.012, rate = 0.9, sway = 0, shift = 0, crouch = 0, look = deg(12) },
	stance = HARE_STANCE,
	calm = {},
	flinch = { push = 0.04, tilt = deg(10), drop = -0.04, squash = -0.06 },
	stun = { roll = deg(6), pitch = deg(3), hz = 1.2, drop = -0.04, twitch = deg(8) },
	basic = { "bite" },
	abilities = {},
	throw = nil,
	death = { { name = "deathSide", weight = 0.6 }, { name = "deathHop", weight = 0.4 } },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "nose", "sitUp", "groom", "nose" },
	fidgetEvery = { 2, 5 },
	rate = 0.05,
	lunge = { min = 0.1, max = 0.5 },
	flightPitch = { deg(20), deg(25) },
	footprint = 0.8,
	wigPivot = 0,
	actions = {
		alert = alert(HARE_STANCE, { rear = deg(20), up = 0.03, shiver = deg(1.2), squash = -0.06 }),
		-- the wolf's hop-bite at 60 %: a quick crouch, a low hop at the target, the bite as the fore feet land
		bite = bite(HARE_STANCE, { rear = deg(8), up = 0.02, back = 0.04, slam = deg(8), hop = 0.15, shake = deg(3) }),
		spawn = spawn(HARE_STANCE, {}),
		summon = summon(HARE_STANCE, {}),
		deathSide = deathSide({ tip = deg(85), buckle = -0.04 }),
		deathHop = deathHop({}),
		-- nose twitch bursts, sitting up on the haunches, grooming
		nose = fidget({ shiver = deg(1.5) }, 0.3, { strike = 0.05 }),
		sitUp = fidget(
			{ rear = deg(35), y = 0.02 },
			1.5,
			{ strike = 0.3, recover = 0.4, mid = { rear = deg(34), shiver = deg(0.8) } }
		),
		groom = fidget({ dip = deg(8), roll = deg(4), shiver = deg(0.6) }, 0.8, { strike = 0.2 }),
	},
}

---------------------------------------------------------------- heavy tree (rotEnt)

local ENT_STANCE: Pose = { dip = deg(3) }

-- The branch blow: leans back about the roots, whips forward on the hit.
local function branch(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local back, whip = o.back or deg(12), o.whip or deg(18)
	return {
		strike = 0.16,
		follow = 0.2,
		recover = 0.4,
		keys = {
			key("A", 0.7, "out", s({ dip = 0, rear = back, yaw = o.wind or deg(8), y = 0.01 })),
			key(
				"A",
				1,
				"inout",
				s({ dip = 0, rear = back * 1.05, yaw = o.wind or deg(8), y = 0.01, shiver = deg(0.4) })
			),
			key("S", 1, "in", s({ rear = 0, dip = whip, yaw = -(o.wind or deg(8)) * 0.5, lunge = 1 })),
			key("F", 1, "out", s({ rear = 0, dip = whip * 0.7, yaw = -(o.wind or deg(8)) * 0.6, lunge = 0.9 })),
			key("R", 1, "inout", st),
		},
	}
end

-- The slam (Elite II own, 1.4; also the crush): rises and leans back, crashes down on the hit.
local function slam(st: Pose, o: { [string]: any }): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	local rise = o.rise or 0.022
	return {
		strike = 0.16,
		follow = 0.25,
		recover = 0.45,
		tremble = o.tremble or deg(1),
		keys = {
			key("A", 0.45, "out", s({ y = rise, dip = 0, rear = deg(10) })),
			key("A", 1, "inout", s({ y = rise * 1.1, dip = 0, rear = deg(11), shiver = deg(0.6) })),
			key("S", 1, "in", s({ y = 0, rear = 0, dip = deg(6), sq = -0.06 })),
			key("F", 1, "out", s({ y = 0, rear = 0, dip = deg(5) })),
			key("R", 1, "inout", st),
		},
	}
end

local ENT: Style = {
	fly = false,
	order = { "stomp" },
	thresholds = {},
	band = 0.3,
	gaits = {
		-- heavy steps: the weight rocks onto each foot (a tip about it), a slow yaw, a lean forward, a small bob
		stomp = gait({
			stride = 0.45,
			maxRate = 1.6,
			bumps = 2,
			bob = 0.008,
			sharp = 1.5,
			rock = deg(4),
			yaw = deg(4),
			yawLag = 0.25,
			pitch = deg(-3),
		}),
	},
	start = 0.01,
	stop = { over = 0.01, wobble = deg(1.5) },
	turn = { omega = 6, bank = 0.02, bankMax = deg(2) },
	idle = { breath = 0.004, rate = 0.2, sway = deg(0.8), shift = 0, crouch = 0, look = deg(5) },
	stance = ENT_STANCE,
	calm = {},
	flinch = { push = 0.01, tilt = deg(4), drop = -0.01, squash = -0.02 },
	stun = { roll = deg(3), pitch = deg(2), hz = 0.5, drop = -0.01, twitch = deg(3) },
	basic = { "branch" },
	abilities = { slam = "slam", heavyBlow = "sweep", crush = "crush", pounce = "pounce" },
	throw = "fling",
	death = { { name = "deathTopple", weight = 0.6 }, { name = "deathFallForward", weight = 0.4 } },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "rustle", "creak" },
	fidgetEvery = { 4, 9 },
	rate = 0.04,
	lunge = { min = 0.02, max = 0.15 },
	flightPitch = { deg(10), deg(12) },
	footprint = 0.6,
	wigPivot = 0,
	actions = {
		alert = alert(ENT_STANCE, { rear = deg(6), up = 0.01, shiver = deg(0.6), thump = 0 }),
		branch = branch(ENT_STANCE, {}),
		slam = slam(ENT_STANCE, {}),
		sweep = branch(ENT_STANCE, { back = deg(10), whip = deg(14), wind = deg(25) }),
		crush = slam(ENT_STANCE, { rise = 0.03, tremble = deg(1.5) }),
		pounce = pounce(ENT_STANCE, { crouch = -0.02, dip = deg(2), wiggle = deg(1), arc = 0.3 }),
		fling = branch(ENT_STANCE, { back = deg(10), whip = deg(12) }),
		spawn = spawn(ENT_STANCE, { y = -0.08, shake = deg(2) }),
		summon = summon(ENT_STANCE, {}),
		deathTopple = deathTopple({}),
		deathFallForward = deathFallForward({}),
		rustle = fidget({ shiver = deg(0.8), lean = deg(1.5) }, 0.8, { strike = 0.2 }),
		creak = fidget({ bow = deg(2), yaw = deg(4) }, 1.0, { strike = 0.4 }),
	},
}

---------------------------------------------------------------- rigid cat (lynx, snowLeopard: no bones)

-- Crouched and ready: low, the head end a touch lower.
local CAT_STANCE: Pose = { y = -0.05, pitch = deg(-2) }

-- The swat and bite: weight back on the haunches, a rear-up (the paw raised), a forward surge onto the target with the
-- front coming down on the hit, a toss to the side.
local function swat(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.14,
		follow = 0.17,
		recover = 0.32,
		keys = {
			key("A", 0.45, "out", s({ z = 0.05, y = -0.06, pitch = deg(-4) })),
			key("A", 1, "inout", s({ z = 0.03, y = 0.03, pitch = 0, rear = deg(14), shiver = deg(0.5) })),
			key("S", 0.5, "in", s({ y = 0.04, pitch = 0, rear = deg(6), lunge = 0.6 })),
			key("S", 1, "in", s({ y = -0.02, pitch = 0, rear = 0, dip = deg(8), lunge = 1, sq = -0.08 })),
			key("F", 0.5, "out", s({ y = -0.03, rear = 0, dip = deg(6), lunge = 1, yaw = deg(6) })),
			key("F", 1, "inout", s({ rear = 0, dip = deg(3), lunge = 0.9, yaw = deg(2) })),
			key("R", 0.5, "inout", s({ lunge = 0.35, z = 0.02 })),
			key("R", 1, "inout", st),
		},
	}
end

-- The hiss at the first aggro: the back up, a shiver, a short spit forward.
local function hiss(st: Pose): Action
	local function s(p: Pose): Pose
		return from(st, p)
	end
	return {
		strike = 0.1,
		follow = 0.3,
		recover = 0.3,
		keys = {
			key("A", 0.5, "out", s({ y = 0.04, pitch = deg(3), z = 0.03, sq = 0.05, shiver = deg(0.8) })),
			key("A", 1, "lin", s({ y = 0.04, pitch = deg(3), z = 0.03, sq = 0.05, shiver = deg(1.2) })),
			key("S", 1, "out", s({ y = 0.02, pitch = deg(-2), z = -0.03, sq = 0 })),
			key("F", 1, "inout", s({ y = 0.01, shiver = deg(0.5) })),
			key("R", 1, "inout", st),
		},
	}
end

local CAT: Style = {
	fly = false,
	order = { "walk", "trot", "gallop" },
	thresholds = { 1.85, 2.85 },
	band = 0.3,
	gaitOf = { walk = "walk", trot = "trot", run = "gallop" },
	gaits = {
		-- the 4-beat walk: a dip on every footfall, the front and hind ends pitching in turn, a roll from side to side
		walk = gait({
			stride = 0.9,
			bumps = 4,
			bob = 0.012,
			roll = deg(2),
			pitchWave = deg(1.5),
			pitchBumps = 2,
			pitchPhase = 0.1,
			yaw = deg(1.5),
			yawLag = 0.25,
			crouch = -0.01,
		}),
		trot = gait({
			stride = 1.15,
			bumps = 2,
			bob = 0.03,
			roll = deg(2),
			pitchWave = deg(1),
			pitchBumps = 2,
			yaw = deg(1),
			yawLag = 0.25,
		}),
		-- the gallop: one suspension a stride, the body rocking nose up in the gather and down on the fore landing
		gallop = gait({
			stride = 1.6,
			maxRate = 3,
			bumps = 1,
			bob = 0.06,
			sharp = 0.8,
			pitchWave = deg(7),
			pitchBumps = 1,
			pitchPhase = 0.25,
			surge = 0.02,
			pitch = deg(-2),
		}),
	},
	start = 0.04,
	stop = { over = 0.02, wobble = deg(1.5) },
	turn = { omega = 12, bank = 0.035, bankMax = deg(6) },
	idle = { breath = 0.006, rate = 0.3, sway = deg(0.3), shift = 0, crouch = 0, look = deg(10) },
	stance = CAT_STANCE,
	calm = {},
	-- stalking: low and slow while it fights at a walk
	stalk = { y = -0.04, pitch = deg(-1.5) },
	flinch = { push = 0.04, tilt = deg(7), drop = -0.03, squash = -0.05 },
	stun = { roll = deg(4), pitch = deg(2), hz = 0.8, drop = -0.04, twitch = deg(6) },
	basic = { "swat" },
	abilities = { leap = "leap", heavyBlow = "heavy", crush = "crush", pounce = "pounce" },
	throw = "fling",
	death = { { name = "deathSide", weight = 0.65 }, { name = "deathSlump", weight = 0.35 } },
	aggro = "hiss",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "lick", "stretch", "sit" },
	fidgetEvery = { 5, 10 },
	rate = 0.04,
	lunge = { min = 0.1, max = 0.8 },
	flightPitch = { deg(20), deg(25) },
	footprint = 0.8,
	wigPivot = -0.15,
	actions = {
		hiss = hiss(CAT_STANCE),
		swat = swat(CAT_STANCE),
		-- the Elite II leap on the Dash* arc (W 1.2, the last 0.35 s in the air): a crouch, the rear wiggle, the spring
		leap = pounce(CAT_STANCE, { crouch = -0.1, dip = deg(3), wiggle = deg(5), strike = 0.35 }),
		heavy = heavy(CAT_STANCE, { rear = deg(25), weave = deg(5), slam = deg(10), sweep = deg(24) }),
		crush = crush(CAT_STANCE, { rear = deg(30), slam = deg(10) }),
		pounce = pounce(CAT_STANCE, { crouch = -0.1, dip = deg(3), wiggle = deg(5) }),
		fling = throw(CAT_STANCE, { rear = deg(14) }),
		spawn = spawn(CAT_STANCE, {}),
		summon = summon(CAT_STANCE, {}),
		deathSide = deathSide({}),
		deathSlump = deathSlump({}),
		lick = fidget({ dip = deg(6), roll = deg(3), shiver = deg(0.5) }, 1.0, { strike = 0.25 }),
		stretch = fidget(
			{ dip = deg(10), z = 0.03 },
			0.9,
			{ strike = 0.35, mid = { dip = deg(10), z = 0.03 }, last = { rear = deg(5), z = 0 } }
		),
		sit = fidget({ rear = deg(15), y = 0.01 }, 2.0, { strike = 0.35, recover = 0.4 }),
	},
}

local STYLES: { [string]: Style } = {
	spider = SPIDER,
	scorpion = SCORPION,
	lizard = LIZARD,
	serpent = SERPENT,
	crow = CROW,
	bat = BAT,
	toad = TOAD,
	hare = HARE,
	ent = ENT,
	cat = CAT,
}

function RigidStyles.get(id: string): Style?
	return STYLES[id]
end

function RigidStyles.ids(): { string }
	local out = {}
	for id in STYLES do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

-- AnimLab states every rigid kind has (LookAnim's slots map onto them), then the style's own actions by name.
RigidStyles.LAB_STATES = {
	"idle",
	"alert",
	"walk",
	"trot",
	"run",
	"turn",
	"home",
	"attack1",
	"attack2",
	"cast",
	"heavy",
	"crush",
	"pounce",
	"throw",
	"hit",
	"hitBack",
	"hitLeft",
	"hitRight",
	"stun",
	"freeze",
	"death",
	"spawn",
	"summon",
	"fight",
}

function RigidStyles.labStates(id: string): { string }
	local style = STYLES[id]
	local out = table.clone(RigidStyles.LAB_STATES)
	if style then
		-- the kit's slots only where the kind has the blow (the hare has no Elites)
		local kit: { [string]: boolean } = {
			cast = next(style.abilities) ~= nil,
			heavy = style.abilities.heavyBlow ~= nil,
			crush = style.abilities.crush ~= nil,
			pounce = style.abilities.pounce ~= nil,
			throw = style.throw ~= nil,
		}
		for slot, present in kit do
			local at = table.find(out, slot)
			if at and not present then
				table.remove(out, at)
			end
		end
		local names = {}
		for name in style.actions do
			if not table.find(out, name) then
				table.insert(names, name)
			end
		end
		table.sort(names)
		for _, name in names do
			table.insert(out, name)
		end
	end
	return out
end

return RigidStyles
