--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE.md F3): the styles of imported flyers animated by
-- Logic/FlyerMotion (controls in Logic/FlyerPose; angles in radians, distances in dump units = studs at scale 1).
-- * `modes`: the wingbeat of a hover, the forward flight and hard flapping (after a hit, the spawn, a keyed climb):
--   beats per second at scale 1 (divided by the square root of the model's scale), the humerus elevation at the top and
--   the bottom of the stroke, its sweep at mid-downstroke (+ forward) and mid-upstroke, the forearm's fold and the
--   hand's twist at mid-upstroke, the body's rise (at the end of the downstroke), pitch swing and the tail's counter;
--   the modes blend by speed and by the hard flapping's weight;
-- * `glide`: the held wings of a glide (straight flight for `after` s, a `chance` every `every` s, never in a fight or
--   on the way home), `cruise`: the speed (studs/s) of the full forward `lean`; `bank`: the roll into a turn at most;
-- * `flare`: the brake (speed falling faster than 6 studs/s^2); `hang` / `tuck`: the legs in a hover / in flight;
-- * `stance`: added while it fights; `calm`: while it goes home; `drift`: the hover's slow figure 8 and yaw;
--   `saccade`: the bird's head jumps (yaw, pitch at most, hold in s); `stun`: added while stunned;
-- * `actions`: keyed motions on Logic/MotionTimeline. Besides the pose's controls a key may set (Logic/FlyerMotion):
--   `flap` how much of the wingbeat runs on over the keyed wings (0 = held), `hard` the hard flapping's weight,
--   `travel` 0..1 of the way to the target (studs, `reachMax` at most; `arc` lifts it on the pounce's arc), `drop`
--   0..1 of the way down to the ground (straight), `fall` the same under gravity (the value squared), `shake` the
--   amplitude of a head shake at 8 Hz;
-- * `flinch`: additive controls by side; `fidgets`: idle actions now and then (every `fidgetEvery` s).
-- The vulture's export has no wing bones (FlyerRigs): its wing controls do nothing until a re-rig lists them, the body,
-- head, legs and tail still fly.

local MotionTimeline = require("../Logic/MotionTimeline")

local FlyerStyles = {}

type Controls = { [string]: number }

export type Mode = {
	hz: number,
	top: number,
	bottom: number,
	fore: number,
	back: number,
	fold: number,
	twist: number,
	bob: number,
	pitch: number,
	tail: number,
}
export type Style = {
	modes: { hover: Mode, flight: Mode, hard: Mode },
	glide: {
		elevation: number,
		sweep: number,
		fold: number,
		pitch: number,
		wobble: number,
		chance: number,
		every: number,
		after: number,
		length: { number },
	},
	cruise: number,
	lean: number,
	bank: number,
	flare: Controls,
	hang: Controls,
	tuck: Controls,
	stance: Controls,
	calm: Controls,
	drift: { x: number, z: number, yaw: number, hz: number },
	saccade: { yaw: number, pitch: number, hold: { number } },
	stun: Controls,
	actions: { [string]: MotionTimeline.Action },
	flinch: { [string]: Controls },
	basic: { string },
	abilities: { [string]: string },
	throw: string?,
	death: { string },
	aggro: string?,
	spawn: string?,
	fidgets: { string },
	fidgetEvery: { number },
	rate: number,
}

local function deg(d: number): number
	return math.rad(d)
end

-- Several control tables into one (later ones win).
local function merge(...: Controls): Controls
	local out: Controls = {}
	for i = 1, select("#", ...) do
		for k, v in (select(i, ...)) do
			out[k] = v
		end
	end
	return out
end

-- Both wings (or one: `side` "L" / "R"): e elevation, s sweep, t twist, f elbow fold, h wrist fold, b w p bends, q
-- hand twist.
local function wings(c: Controls, side: string?): Controls
	local out: Controls = {}
	local sides: { string } = if side then { side } else { "L", "R" }
	for _, sd in sides do
		for k, v in c do
			out["w" .. sd .. k] = v
		end
	end
	return out
end

-- Both legs: s swing (+ forward), f fold, c toes curled, o out.
local function legs(c: Controls, side: string?): Controls
	local out: Controls = {}
	local sides: { string } = if side then { side } else { "L", "R" }
	for _, sd in sides do
		for k, v in c do
			out["l" .. sd .. k] = v
		end
	end
	return out
end

local function key(seg: string, u: number, ease: string?, pose: Controls): MotionTimeline.Key
	return { seg = seg, u = u, ease = ease, pose = pose }
end

---------------------------------------------------------------- vulture (ashVulture)

local TUCK = legs({ s = deg(-60), f = deg(70), c = deg(50) })
local HANG = legs({ s = deg(-18), f = deg(22), c = deg(20) })
-- the fighting hover: neck a little forward, tail spread, legs hanging lower
local STANCE: Controls = merge({ npitch = deg(-6), hpitch = deg(4), tpitch = deg(4), fan = deg(10) })
local function s(...: Controls): Controls
	return merge(STANCE, ...)
end

-- the wings held at mid-stroke (the beat runs on over it with `flap`)
local MID = wings({ e = deg(10), s = 0, f = deg(10) })

local VULTURE: Style = {
	modes = {
		hover = {
			hz = 1.7,
			top = deg(55),
			bottom = deg(-35),
			fore = deg(10),
			back = deg(-15),
			fold = deg(45),
			twist = deg(20),
			bob = 0.12,
			pitch = deg(3),
			tail = deg(5),
		},
		flight = {
			hz = 2.0,
			top = deg(45),
			bottom = deg(-30),
			fore = deg(5),
			back = deg(-10),
			fold = deg(35),
			twist = deg(20),
			bob = 0.08,
			pitch = deg(2),
			tail = deg(4),
		},
		hard = {
			hz = 2.6,
			top = deg(65),
			bottom = deg(-45),
			fore = deg(15),
			back = deg(-20),
			fold = deg(55),
			twist = deg(25),
			bob = 0.2,
			pitch = deg(4),
			tail = deg(7),
		},
	},
	glide = {
		elevation = deg(8),
		sweep = deg(-5),
		fold = deg(5),
		pitch = deg(-5),
		wobble = deg(2),
		chance = 0.4,
		every = 3,
		after = 1.5,
		length = { 1, 2 },
	},
	cruise = 13,
	lean = deg(-8),
	bank = deg(35),
	flare = merge(
		{ bpitch = deg(15), npitch = deg(-8), fan = deg(25), tpitch = deg(-10) },
		wings({ e = deg(40), s = deg(25) })
	),
	hang = HANG,
	tuck = TUCK,
	stance = STANCE,
	calm = { npitch = deg(4), hpitch = deg(-2) },
	drift = { x = 0.15, z = 0.1, yaw = deg(6), hz = 0.2 },
	saccade = { yaw = deg(40), pitch = deg(12), hold = { 0.4, 1.2 } },
	stun = merge({ hpitch = deg(-12), npitch = deg(-8), tpitch = deg(-8) }, wings({ e = deg(-10), f = deg(15) })),
	basic = { "volley" },
	abilities = {
		wail = "wail",
		heavyBlow = "rake",
		crush = "stoop",
		pounce = "pounce",
		leap = "pounce",
		slam = "stoop",
	},
	throw = "volley",
	death = { "deathL", "deathR" },
	aggro = "screech",
	spawn = "spawn",
	fidgets = { "scan", "ruffle" },
	fidgetEvery = { 5, 10 },
	rate = 0.07,
	flinch = {
		front = merge(
			{ bz = 0.35, by = -0.25, bpitch = deg(8), npitch = deg(10), hpitch = deg(-6) },
			wings({ e = deg(30) })
		),
		back = merge({ bz = -0.35, by = -0.25, bpitch = deg(-8), tpitch = deg(15) }, wings({ e = deg(30) })),
		left = merge({ bx = 0.35, by = -0.25, broll = deg(-12), hyaw = deg(-10) }, wings({ e = deg(30) })),
		right = merge({ bx = -0.35, by = -0.25, broll = deg(12), hyaw = deg(10) }, wings({ e = deg(30) })),
	},
	actions = {
		-- the feather volley (W 0.5; Elite 0.6, Elite II 0.675, the Elite II throw 0.81): a flare with the wings high and
		-- back, one violent downstroke that throws the volley from the beak on the hit, the recoil back, the beat resumes
		volley = {
			strike = 0.14,
			follow = 0.15,
			recover = 0.2,
			keys = {
				key(
					"A",
					1,
					"inout",
					s(
						{
							bpitch = deg(20),
							by = 0.3,
							npitch = deg(15),
							hpitch = deg(-8),
							fan = deg(28),
							tpitch = deg(8),
						},
						wings({ e = deg(70), s = deg(-25), f = 0, h = 0, t = deg(-10) }),
						legs({ s = deg(-10), f = deg(30), c = deg(30) })
					)
				),
				key(
					"S",
					1,
					"in",
					s(
						{ bpitch = deg(5), by = 0.22, bz = 0.25, npitch = deg(-14), hpitch = deg(-6), fan = deg(20) },
						wings({ e = deg(-40), s = deg(10), w = deg(18), p = deg(12) }),
						legs({ s = deg(-20), f = deg(40), c = deg(40) })
					)
				),
				key(
					"F",
					1,
					"out",
					s(
						{ bpitch = deg(2), by = 0.1, bz = 0.15, npitch = deg(-8), hpitch = deg(-10), fan = deg(14) },
						wings({ e = deg(-30), s = deg(5), f = deg(15), w = deg(-6) }),
						legs({ s = deg(-18), f = deg(30), c = deg(30) })
					)
				),
				key("R", 1, "inout", merge(s(MID), { flap = 0.6 })),
			},
		},
		-- the wail (Elite II own, W 1.2): it rises and spreads to the full span, held with small beats while it trembles
		-- more and more, then the neck thrusts and the wings snap forward and down on the hit; the scream is held
		wail = {
			strike = 0.14,
			follow = 0.3,
			recover = 0.35,
			tremble = deg(1.8),
			keys = {
				key(
					"A",
					0.28,
					"out",
					s(
						{
							by = 0.5,
							bpitch = deg(15),
							npitch = deg(20),
							hpitch = deg(8),
							fan = deg(32),
							tpitch = deg(10),
						},
						wings({ e = deg(20), s = 0, f = 0, h = 0 }),
						legs({ s = deg(-10), f = deg(30), c = deg(25) }),
						{ flap = 0.22, hard = 0.6 }
					)
				),
				key(
					"A",
					1,
					"inout",
					s(
						{
							by = 0.55,
							bpitch = deg(18),
							npitch = deg(26),
							hpitch = deg(10),
							fan = deg(34),
							tpitch = deg(12),
						},
						wings({ e = deg(22), s = deg(-4), f = 0, h = 0 }),
						legs({ s = deg(-10), f = deg(32), c = deg(30) }),
						{ flap = 0.18, hard = 0.6 }
					)
				),
				key(
					"S",
					1,
					"in",
					s(
						{ by = 0.4, bz = 0.3, bpitch = deg(2), npitch = deg(-30), hpitch = deg(-10), fan = deg(30) },
						wings({ e = deg(0), s = deg(25), f = deg(5), w = deg(10) }),
						legs({ s = deg(-25), f = deg(45), c = deg(45) })
					)
				),
				key(
					"F",
					1,
					"lin",
					s(
						{ by = 0.35, bz = 0.2, bpitch = deg(4), npitch = deg(-26), hpitch = deg(-8), fan = deg(26) },
						wings({ e = deg(5), s = deg(18), f = deg(8) }),
						legs({ s = deg(-22), f = deg(40), c = deg(40) }),
						{ shake = deg(5), flap = 0.15 }
					)
				),
				key("R", 1, "inout", merge(s(MID), { flap = 0.6 })),
			},
		},
		-- the talon rake (Elite Heavy Blow, W 1.8): it climbs with hard beats, the legs swing forward with the talons open,
		-- hovers there trembling, swoops forward and down raking the legs through on the hit, pulls up and goes back
		rake = {
			strike = 0.14,
			follow = 0.2,
			recover = 0.5,
			tremble = deg(1.2),
			keys = {
				key(
					"A",
					0.7,
					"out",
					s({
						by = 0.8,
						bpitch = deg(25),
						npitch = deg(10),
						hpitch = deg(-12),
						fan = deg(30),
						tpitch = deg(-6),
					}, legs({ s = deg(70), f = deg(-10), c = deg(-30) }), MID, { flap = 1, hard = 1 })
				),
				key(
					"A",
					1,
					"inout",
					s({
						by = 0.85,
						bpitch = deg(30),
						npitch = deg(12),
						hpitch = deg(-14),
						fan = deg(32),
						tpitch = deg(-8),
					}, legs({ s = deg(72), f = deg(-12), c = deg(-35) }), MID, { flap = 0.7, hard = 1 })
				),
				key(
					"S",
					1,
					"in",
					s(
						{ by = 0, bz = -1.5, bpitch = deg(5), npitch = deg(-6), hpitch = deg(-6), fan = deg(20) },
						legs({ s = deg(-20), f = deg(20), c = deg(45) }),
						wings({ e = deg(5), s = deg(8), f = 0, w = deg(14) })
					)
				),
				key(
					"F",
					1,
					"out",
					s(
						{ by = 0.4, bz = -1.0, bpitch = deg(15), npitch = deg(-4), fan = deg(24) },
						legs({ s = deg(-40), f = deg(40), c = deg(50) }),
						MID,
						{ flap = 1, hard = 1 }
					)
				),
				key("R", 1, "inout", merge(s(MID), { flap = 1, hard = 0.4 })),
			},
		},
		-- the stoop (Elite II Crushing Blow, W 2.2): a climb of 3 studs with hard beats, the wings fold and the nose goes
		-- down, then a dive along an arc toward the target (at most 6 studs out, down to the ground) with the talons
		-- forward and the wings flaring open on the hit; it pulls up and climbs back
		stoop = {
			strike = 0.3,
			follow = 0.25,
			recover = 0.55,
			tremble = deg(0.8),
			keys = {
				key(
					"A",
					0.84,
					"inout",
					s(
						{ by = 3, bpitch = deg(20), npitch = deg(-10), hpitch = deg(-20), fan = deg(28) },
						TUCK,
						MID,
						{ flap = 1, hard = 1 }
					)
				),
				key(
					"A",
					1,
					"in",
					s(
						{ by = 3.1, bpitch = deg(-50), npitch = deg(20), hpitch = deg(30), fan = 0, tpitch = deg(10) },
						TUCK,
						wings({ e = deg(-10), s = deg(-20), f = deg(80), h = deg(60) })
					)
				),
				key(
					"S",
					1,
					"in",
					s(
						{
							by = 0,
							bpitch = deg(10),
							npitch = deg(-5),
							hpitch = deg(-10),
							fan = deg(34),
							tpitch = deg(-12),
							travel = 1,
							reachMax = 6,
							drop = 1,
						},
						legs({ s = deg(65), f = deg(-10), c = deg(-30) }),
						wings({ e = deg(60), s = deg(20), f = 0, h = 0 })
					)
				),
				key(
					"F",
					1,
					"out",
					s(
						{ by = 0.6, bpitch = deg(20), fan = deg(24), travel = 0.8, reachMax = 6, drop = 0.5 },
						legs({ s = deg(-20), f = deg(40), c = deg(50) }),
						MID,
						{ flap = 1, hard = 1 }
					)
				),
				key("R", 1, "inout", merge(s(MID), { flap = 1, hard = 0.5, reachMax = 6 })),
			},
		},
		-- the pounce (Elite II, W 1.4; the server moves it on the hit): it sinks low with the wings cocked high, then
		-- flies the leap's arc with hard beats, talons forward on the hit
		pounce = {
			strike = 0.4,
			follow = 0.2,
			recover = 0.4,
			tremble = deg(1),
			keys = {
				key(
					"A",
					0.7,
					"out",
					s(
						{ by = -0.4, bpitch = deg(10), npitch = deg(-8), hpitch = deg(-10), fan = deg(20) },
						wings({ e = deg(70), s = deg(-15), f = deg(10) }),
						legs({ s = deg(20), f = deg(20), c = deg(10) }),
						{ flap = 0.15 }
					)
				),
				key(
					"S",
					0.5,
					"inout",
					s(
						{ by = -0.1, bpitch = deg(-10), npitch = deg(-10), hpitch = deg(-6), travel = 0.45, arc = 0.25 },
						legs({ s = deg(40), f = deg(10), c = deg(-10) }),
						MID,
						{ flap = 1, hard = 1 }
					)
				),
				key(
					"S",
					1,
					"in",
					s(
						{ by = -0.2, bpitch = deg(15), npitch = deg(-6), hpitch = deg(-12), travel = 1, arc = 0.25 },
						legs({ s = deg(70), f = deg(-10), c = deg(-30) }),
						wings({ e = deg(50), s = deg(15), f = 0 })
					)
				),
				key(
					"F",
					1,
					"out",
					s({ bpitch = deg(5) }, legs({ s = deg(10), f = deg(30), c = deg(50) }), MID, { flap = 1, hard = 1 })
				),
				key("R", 1, "inout", merge(s(MID), { flap = 1, hard = 0.4 })),
			},
		},
		-- the alert: one hard beat, the head snaps to the target and the neck stretches up in a short screech
		screech = {
			strike = 0.15,
			follow = 0.3,
			recover = 0.3,
			keys = {
				key(
					"A",
					1,
					"out",
					s({ by = 0.15, npitch = deg(-6), hpitch = deg(-4), fan = deg(24) }, { flap = 1, hard = 1 })
				),
				key(
					"S",
					1,
					"out",
					s({ by = 0.2, npitch = deg(15), hpitch = deg(12), fan = deg(30) }, { flap = 0.5, hard = 1 })
				),
				key(
					"F",
					1,
					"lin",
					s({ by = 0.15, npitch = deg(13), hpitch = deg(10), fan = deg(26), shake = deg(3) }, { flap = 0.6 })
				),
				key("R", 1, "inout", merge(s(MID), { flap = 1 })),
			},
		},
		-- the spawn: up from the ground to the hover with hard beats
		spawn = {
			strike = 0.25,
			follow = 0.4,
			recover = 0.4,
			keys = {
				key(
					"A",
					0,
					"lin",
					merge(
						{ drop = 0.85, bpitch = deg(25), npitch = deg(10) },
						legs({ s = deg(10), f = deg(30) }),
						MID,
						{ flap = 1, hard = 1 }
					)
				),
				key(
					"S",
					1,
					"out",
					merge({ drop = 0.35, bpitch = deg(15), npitch = deg(5) }, HANG, MID, { flap = 1, hard = 1 })
				),
				key(
					"F",
					1,
					"inout",
					merge({ drop = 0, by = 0.15, bpitch = deg(5) }, HANG, MID, { flap = 1, hard = 1 })
				),
				key("R", 1, "inout", merge(HANG, MID, { flap = 1, hard = 0.3 })),
			},
		},
		-- idle: looks down and around at the ground below
		scan = {
			strike = 0.3,
			follow = 0.9,
			recover = 0.5,
			keys = {
				key(
					"S",
					1,
					"inout",
					merge({ npitch = deg(-25), hpitch = deg(-15), hyaw = deg(25) }, MID, { flap = 1 })
				),
				key(
					"F",
					0.5,
					"inout",
					merge({ npitch = deg(-25), hpitch = deg(-12), hyaw = deg(-25) }, MID, { flap = 1 })
				),
				key(
					"F",
					1,
					"inout",
					merge({ npitch = deg(-20), hpitch = deg(-10), hyaw = deg(-5) }, MID, { flap = 1 })
				),
				key("R", 1, "inout", merge(MID, { flap = 1 })),
			},
		},
		-- idle: a quick ruffle of the feathers (a shake through the body and the tail)
		ruffle = {
			strike = 0.2,
			follow = 0.4,
			recover = 0.3,
			keys = {
				key(
					"S",
					1,
					"out",
					merge({ npitch = deg(8), fan = deg(30), tpitch = deg(8), shake = deg(9) }, MID, { flap = 0.5 })
				),
				key("F", 1, "lin", merge({ npitch = deg(4), fan = deg(10), shake = deg(6) }, MID, { flap = 0.8 })),
				key("R", 1, "inout", merge(MID, { flap = 1 })),
			},
		},
	},
}

-- Death to one side (`side` 1: the right side goes up, it falls on its left): a jolt, the wings stop (the upper one
-- folds up, the lower one hangs), nose down; it falls under gravity rolling 60 degrees, hits the ground on the hit and
-- bounces, and lies on its side with the lower wing spread on the ground, the upper one folded over, the neck limp.
local function deathFlyer(side: number): MotionTimeline.Action
	local up = if side > 0 then "L" else "R" -- the wing that ends on top (the side that goes up)
	local down = if side > 0 then "R" else "L"
	return {
		strike = 0.5,
		follow = 0.3,
		recover = 0,
		hold = true,
		keys = {
			key("A", 1, "out", merge({ bz = 0.1, bpitch = deg(10), npitch = deg(12) }, wings({ e = deg(30), f = 0 }))),
			key(
				"S",
				0.2,
				"inout",
				merge(
					{ bpitch = deg(-25), broll = side * deg(15), npitch = deg(-10), hpitch = deg(-10), fall = 0.12 },
					wings({ e = deg(60), f = deg(30), h = deg(30) }, up),
					wings({ e = deg(-45), f = deg(15) }, down),
					legs({ s = deg(-20), f = deg(20), c = deg(30) })
				)
			),
			key(
				"S",
				1,
				"lin",
				merge(
					{ bpitch = deg(-30), broll = side * deg(60), npitch = deg(-25), hpitch = deg(-15), fall = 1 },
					wings({ e = deg(70), f = deg(70), h = deg(55) }, up),
					wings({ e = deg(-20), f = deg(10) }, down),
					legs({ s = deg(-10), f = deg(30), c = deg(45) })
				)
			),
			key(
				"F",
				0.27,
				"out",
				merge(
					{
						by = 0.12,
						bpitch = deg(-15),
						broll = side * deg(85),
						npitch = deg(-30),
						hpitch = deg(-18),
						fall = 1,
					},
					wings({ e = deg(70), f = deg(75), h = deg(60) }, up),
					wings({ e = deg(-5), f = deg(5) }, down),
					legs({ s = deg(-10), f = deg(35), c = deg(55) })
				)
			),
			key(
				"F",
				1,
				"in",
				merge(
					{
						bpitch = deg(-5),
						broll = side * deg(100),
						npitch = deg(-40),
						hpitch = deg(-20),
						tpitch = deg(-10),
						fall = 1,
					},
					wings({ e = deg(80), f = deg(80), h = deg(65) }, up),
					wings({ e = deg(0), s = deg(-5), f = 0, h = 0 }, down),
					legs({ s = deg(-20), f = deg(30), c = deg(60) })
				)
			),
		},
	}
end

VULTURE.actions.deathL = deathFlyer(1)
VULTURE.actions.deathR = deathFlyer(-1)

---------------------------------------------------------------- harpy (peakHarpy, docs/ANIM-WZORCE §4.5)

-- A style built on another: `over` replaces fields, `actions` adds or replaces actions.
local function variant(base: Style, over: { [string]: any }): Style
	local out = table.clone(base) :: any
	for k, v in over do
		if k == "actions" then
			local actions = table.clone(base.actions)
			for name, action in v do
				actions[name] = action
			end
			out.actions = actions
		else
			out[k] = v
		end
	end
	return out :: Style
end

-- legs dangle in a hover (knees a little bent, talons half closed), drawn up in flight
local H_HANG = legs({ s = deg(6), f = deg(14), c = deg(20) })
local H_TUCK = legs({ s = deg(-35), f = deg(55), c = deg(40) })
local H_STANCE: Controls = { spitch = deg(-6), npitch = deg(-4), hpitch = deg(4), tpitch = deg(4) }
local function hs(...: Controls): Controls
	return merge(H_STANCE, ...)
end
local H_MID = wings({ e = deg(12), s = 0, f = deg(12) })

-- Tumbling backwards: a jolt, the wing-arms thrown up, it falls on its back turning over, lands, rocks and lies spread
-- (on its back the body's rear points down: the wings lie flat swept a little forward, else their tips dig in).
local function deathBack(side: number): MotionTimeline.Action
	return {
		strike = 0.5,
		follow = 0.35,
		recover = 0,
		hold = true,
		keys = {
			key("A", 1, "out", merge({ bz = 0.15, bpitch = deg(12), hpitch = deg(15) }, wings({ e = deg(40), f = 0 }))),
			key(
				"S",
				0.3,
				"inout",
				merge(
					{ bpitch = deg(35), broll = side * deg(8), npitch = deg(15), hpitch = deg(20), fall = 0.2 },
					wings({ e = deg(55), s = deg(-20), f = deg(10) }),
					legs({ s = deg(35), f = deg(25), c = deg(30) })
				)
			),
			key(
				"S",
				1,
				"lin",
				merge({
					bpitch = deg(80),
					broll = side * deg(10),
					npitch = deg(20),
					hpitch = deg(15),
					tpitch = deg(-30),
					fall = 1,
				}, wings({ e = deg(10), s = deg(-5), f = deg(20) }), legs({ s = deg(50), f = deg(30), c = deg(40) }))
			),
			key(
				"F",
				0.25,
				"out",
				merge({
					by = 0.12,
					bpitch = deg(92),
					broll = side * deg(8),
					npitch = deg(25),
					hpitch = deg(10),
					tpitch = deg(-38),
					fall = 1,
				}, wings({ e = deg(-4), s = deg(4), f = deg(15) }), legs({ s = deg(45), f = deg(40), c = deg(50) }))
			),
			key(
				"F",
				1,
				"in",
				merge(
					{
						bpitch = deg(95),
						broll = side * deg(6),
						npitch = deg(30),
						hpitch = deg(5),
						tpitch = deg(-42),
						fall = 1,
					},
					wings({ e = deg(-8), s = deg(6), f = deg(10), h = deg(10) }),
					legs({ s = deg(30), f = deg(50), c = deg(60) })
				)
			),
		},
	}
end

-- the wail's thrust on the hit: head and wings forward
local H_WAIL_HIT = hs(
	{ by = 0.3, bz = 0.25, bpitch = deg(-6), spitch = deg(10), npitch = deg(-25), hpitch = deg(-15) },
	wings({ e = deg(0), s = deg(22), f = deg(5) }),
	legs({ s = deg(20), f = deg(30), c = deg(40) })
)

local HARPY = variant(VULTURE, {
	modes = {
		hover = {
			hz = 1.5,
			top = deg(60),
			bottom = deg(-35),
			fore = deg(12),
			back = deg(-15),
			fold = deg(50),
			twist = deg(20),
			bob = 0.14,
			pitch = deg(3),
			tail = deg(5),
		},
		flight = {
			hz = 1.8,
			top = deg(48),
			bottom = deg(-32),
			fore = deg(6),
			back = deg(-12),
			fold = deg(40),
			twist = deg(20),
			bob = 0.1,
			pitch = deg(2),
			tail = deg(4),
		},
		hard = {
			hz = 2.4,
			top = deg(68),
			bottom = deg(-45),
			fore = deg(15),
			back = deg(-20),
			fold = deg(58),
			twist = deg(25),
			bob = 0.22,
			pitch = deg(4),
			tail = deg(7),
		},
	},
	lean = deg(-14),
	hang = H_HANG,
	tuck = H_TUCK,
	stance = H_STANCE,
	calm = { spitch = deg(2), hpitch = deg(-2) },
	flare = merge(
		{ bpitch = deg(12), spitch = deg(-6), tpitch = deg(-10) },
		wings({ e = deg(40), s = deg(25) }),
		legs({ s = deg(30), f = deg(10), c = deg(-10) })
	),
	stun = merge({ hpitch = deg(-14), spitch = deg(8), npitch = deg(-6) }, wings({ e = deg(-10), f = deg(15) })),
	basic = { "fling" },
	throw = "fling",
	death = { "deathBackL", "deathBackR" },
	fidgets = { "scan", "stretch" },
	actions = {
		-- the lightning fling (W 0.5): both wing-arms raised high and back with the chest open, flung forward on the
		-- hit (the bolt leaves between the wing tips), the follow-through low in front, the beat resumes
		fling = {
			strike = 0.16,
			follow = 0.17,
			recover = 0.22,
			keys = {
				key(
					"A",
					1,
					"inout",
					hs(
						{ bpitch = deg(8), by = 0.25, spitch = deg(-12), npitch = deg(-6), hpitch = deg(-4) },
						wings({ e = deg(62), s = deg(-35), t = deg(20), f = deg(5), h = 0 }),
						legs({ s = deg(-10), f = deg(30), c = deg(10) })
					)
				),
				key(
					"S",
					1,
					"in",
					hs(
						{
							bpitch = deg(-6),
							by = 0.15,
							bz = -0.15,
							spitch = deg(12),
							npitch = deg(-8),
							hpitch = deg(-6),
						},
						wings({ e = deg(5), s = deg(30), t = deg(-10), f = 0, h = 0, w = deg(-8) }),
						legs({ s = deg(15), f = deg(25), c = deg(40) })
					)
				),
				key(
					"F",
					1,
					"out",
					hs(
						{ bpitch = deg(-3), by = 0.1, bz = 0.1, spitch = deg(8), npitch = deg(-4), hpitch = deg(-8) },
						wings({ e = deg(-15), s = deg(25), f = deg(12) }),
						legs({ s = deg(8), f = deg(20), c = deg(30) })
					)
				),
				key("R", 1, "inout", merge(hs(H_MID), { flap = 0.6 })),
			},
		},
		-- the wail: rises with the wings wide and the head thrown back, trembling; head and wings thrust forward on the
		-- hit and the scream is held
		wail = {
			strike = 0.14,
			follow = 0.3,
			recover = 0.35,
			tremble = deg(1.6),
			keys = {
				key(
					"A",
					0.28,
					"out",
					hs(
						{ by = 0.4, bpitch = deg(6), spitch = deg(-14), npitch = deg(20), hpitch = deg(30) },
						wings({ e = deg(25), s = deg(5), f = 0, h = 0 }),
						legs({ s = deg(10), f = deg(20), c = deg(10) }),
						{ flap = 0.2, hard = 0.6 }
					)
				),
				key(
					"A",
					1,
					"inout",
					hs(
						{ by = 0.45, bpitch = deg(8), spitch = deg(-16), npitch = deg(24), hpitch = deg(36) },
						wings({ e = deg(27), s = deg(2), f = 0, h = 0 }),
						legs({ s = deg(10), f = deg(22), c = deg(15) }),
						{ flap = 0.16, hard = 0.6 }
					)
				),
				key("S", 1, "in", H_WAIL_HIT),
				key(
					"F",
					1,
					"lin",
					hs(
						{
							by = 0.25,
							bz = 0.15,
							bpitch = deg(-4),
							spitch = deg(8),
							npitch = deg(-22),
							hpitch = deg(-12),
						},
						wings({ e = deg(5), s = deg(16), f = deg(8) }),
						legs({ s = deg(15), f = deg(25), c = deg(35) }),
						{ shake = deg(5), flap = 0.15 }
					)
				),
				key("R", 1, "inout", merge(hs(H_MID), { flap = 0.6 })),
			},
		},
		-- idle: stretches one wing-arm out and back (a preen)
		stretch = {
			strike = 0.4,
			follow = 0.7,
			recover = 0.5,
			keys = {
				key(
					"S",
					1,
					"inout",
					merge(
						{ hyaw = deg(-30), hpitch = deg(-6), spitch = deg(-4) },
						wings({ e = deg(5), s = deg(-25), f = 0, h = 0, t = deg(15) }, "R"),
						H_MID,
						{ flap = 0.3 }
					)
				),
				key(
					"F",
					1,
					"inout",
					merge(
						{ hyaw = deg(-20), hpitch = deg(-4) },
						wings({ e = deg(10), s = deg(-15), f = 0, h = 0 }, "R"),
						H_MID,
						{ flap = 0.4 }
					)
				),
				key("R", 1, "inout", merge(H_MID, { flap = 1 })),
			},
		},
		deathBackL = deathBack(1),
		deathBackR = deathBack(-1),
	},
})

local STYLES: { [string]: Style } = {
	vulture = VULTURE,
	harpy = HARPY,
}

function FlyerStyles.get(id: string): Style?
	return STYLES[id]
end

-- The states `/animlab mob <id> <state>` shows for a flyer (besides the actions of its style by name).
FlyerStyles.LAB_STATES = {
	"idle",
	"alert",
	"walk",
	"trot",
	"run",
	"turn",
	"home",
	"glide",
	"brake",
	"stun",
	"freeze",
	"attack1",
	"attack2",
	"cast",
	"volley",
	"fling",
	"wail",
	"rake",
	"stoop",
	"pounce",
	"screech",
	"scan",
	"ruffle",
	"stretch",
	"hit",
	"hitBack",
	"hitLeft",
	"hitRight",
	"death",
	"deathL",
	"deathR",
	"deathBackL",
	"deathBackR",
	"spawn",
	"fight",
}

return FlyerStyles
