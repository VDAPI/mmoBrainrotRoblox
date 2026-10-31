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
-- * `flinch`: additive controls by side; `fidgets`: idle actions now and then (every `fidgetEvery` s);
-- * `spread`: the fingers fanned at mid-downstroke (rad; half of it drawn in on the upstroke); `jitter`: an erratic
--   flyer's beat rate wander (share), hover darts (dump units, rad) and their rate; `perch`: it lands when it hovers
--   still out of a fight (Logic/FlyerMotion: its pose on the ground on top of the map's, the toes' depth under the
--   lowest leg pivot, s of stillness before, s down and up, the hops, idles on the ground); `summon`: the climb out of
--   the ground of a boss's helper (else `spawn`).
-- Keys may also set `jaw` (+ open; a map with a jaw bone) and `lunge` (0..1 of the way to the target for a blow with no
-- area: aimed until the strike, `reachMax` dump units at most). The perch's idles key its pose themselves.
-- The old vulture export has no wing bones (FlyerRigs): its wing controls do nothing, the body, head, legs and tail
-- still fly; its new export (2026-10-31) beats its wings. The crow and the bat (Data/RigidStyles with their old
-- models) fly here with their new exports, their actions under the rigid ones' names (Data/MotionFx).

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
	spread: number?,
	jitter: { rate: number, hz: number, x: number, y: number, roll: number }?,
	perch: Perch?,
	summon: string?,
}
export type Perch = {
	pose: Controls,
	toe: number,
	after: { number },
	land: number,
	rise: number,
	hop: { every: { number }, length: number, height: number, reach: number, turn: number, air: Controls },
	fidgets: { string },
	every: { number },
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
					}, legs({ s = deg(62), f = deg(-8), c = deg(-25) }), MID, { flap = 0.7, hard = 1 })
				),
				key(
					"S",
					1,
					"in",
					s(
						{ by = 0, bz = -1.5, bpitch = deg(5), npitch = deg(-6), hpitch = deg(-6), fan = deg(20) },
						legs({ s = deg(-8), f = deg(15), c = deg(35) }),
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
							drop = 0.9,
						},
						legs({ s = deg(55), f = deg(-8), c = deg(-20) }),
						wings({ e = deg(60), s = deg(20), f = 0, h = 0 })
					)
				),
				key(
					"F",
					1,
					"out",
					s(
						{ by = 0.6, bpitch = deg(20), fan = deg(24), travel = 0.8, reachMax = 6, drop = 0.5 },
						legs({ s = deg(-10), f = deg(35), c = deg(40) }),
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
-- folds up at once, the lower one stays level), nose down; it falls under gravity rolling 60 degrees, the lower wing
-- raised with the roll so it stays about level (never hanging under the body into the ground), hits the ground on the
-- hit and bounces, and lies on its side with the lower wing spread on the ground (raised toward the back as the body
-- rolls onto it, so it lies flat instead of digging in), the upper one folded over, the neck limp.
local function deathFlyer(side: number): MotionTimeline.Action
	local up = if side > 0 then "R" else "L" -- the wing that ends on top (roll + raises the right side)
	local down = if side > 0 then "L" else "R"
	return {
		strike = 0.5,
		follow = 0.3,
		recover = 0,
		hold = true,
		keys = {
			key("A", 1, "out", merge({ bz = 0.1, bpitch = deg(10), npitch = deg(12) }, wings({ e = deg(30), f = 0 }))),
			key(
				"S",
				0.35,
				"inout",
				merge(
					{ bpitch = deg(-15), broll = side * deg(15), npitch = deg(-5), hpitch = deg(-8), fall = 0.12 },
					wings({ e = deg(50), f = deg(35), h = deg(30) }, up),
					wings({ e = deg(20), f = deg(10) }, down),
					legs({ s = deg(-15), f = deg(20), c = deg(25) })
				)
			),
			key(
				"S",
				1,
				"lin",
				merge(
					{ bpitch = deg(-30), broll = side * deg(60), npitch = deg(-25), hpitch = deg(-15), fall = 1 },
					wings({ e = deg(70), f = deg(90), h = deg(75) }, up),
					wings({ e = deg(55), f = deg(10) }, down),
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
					wings({ e = deg(70), s = deg(-30), f = deg(110), h = deg(100) }, up),
					wings({ e = deg(80), f = deg(5) }, down),
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
					wings({ e = deg(75), s = deg(-50), f = deg(150), h = deg(150) }, up),
					wings({ e = deg(96), s = deg(-5), f = 0, h = 0 }, down),
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

---------------------------------------------------------------- crow (carrionCrow, its new export)

-- A small black bird: quick rowing beats, short glides, legs drawn up in flight; it lands when it hovers still out of a
-- fight and hops about. The same action names as its rigid recipe (Data/RigidStyles crow, Data/MotionFx).
local C_HANG = legs({ s = deg(15), c = deg(25) })
local C_TUCK = legs({ s = deg(-75), c = deg(60) })
local C_STANCE: Controls = { npitch = deg(-6), hpitch = deg(6), tpitch = deg(4), fan = deg(12) }
local function cs(...: Controls): Controls
	return merge(C_STANCE, ...)
end
local C_MID = wings({ e = deg(12), s = 0, f = deg(10) })
-- folded on the ground: swept back along the body, the elbow and the wrist closed, the primaries drawn in
local C_FOLD = wings({ e = deg(-5), s = deg(-80), f = deg(165), h = deg(165), n = deg(-25) })
-- half folded (out of the ground: the summon)
local C_HALF = wings({ e = deg(0), s = deg(-45), f = deg(90), h = deg(90), n = deg(-15) })
-- standing: the body up on its legs (straight under it), the head level, the tail lifted clear of the ground
local C_PERCH: Controls = merge(
	{ bpitch = deg(22), npitch = deg(-5), hpitch = deg(-18), tpitch = deg(24), fan = deg(-4) },
	legs({ s = deg(-22), c = deg(-10) }),
	C_FOLD
)
local function cp(...: Controls): Controls
	return merge(C_PERCH, ...)
end

-- Death of a small flyer (the crow, the bat; started on Dead, the hit = the strike): a jolt on the strike, the wings
-- stop; it falls under gravity through the follow-through (the ground at its end, where Data/MotionFx raises the
-- dust), bounces and lies on its side (the lower wing spread flat on the ground, the upper one folded over it) or, with
-- `back`, flipped over backwards onto its back (the wings out to the sides, the legs up); `over` replaces controls of the
-- lying pose (a body carried at another pitch).
local function deathDrop(side: number, back: boolean, over: Controls?): MotionTimeline.Action
	local up = if side > 0 then "R" else "L"
	local down = if side > 0 then "L" else "R"
	local tumble: Controls
	local contact: Controls
	local lie: Controls
	if back then
		tumble = merge(
			{ bpitch = deg(80), broll = side * deg(10), npitch = deg(15), hpitch = deg(15), fall = 0.5 },
			wings({ e = deg(50), s = deg(-15), f = deg(15) }),
			legs({ s = deg(30), c = deg(30) })
		)
		contact = merge({
			bpitch = deg(160),
			broll = side * deg(12),
			npitch = deg(-5),
			hpitch = deg(-5),
			tpitch = deg(15),
			fall = 1,
		}, wings({ e = deg(10), s = deg(5), f = deg(15) }), legs({ s = deg(45), c = deg(50) }))
		lie = merge(
			-- (the body upside down: a negative pitch lifts the head off the ground)
			{
				bpitch = deg(172),
				broll = side * deg(8),
				npitch = deg(-18),
				hpitch = deg(-12),
				tpitch = deg(10),
				fall = 1,
			},
			over or {},
			wings({ e = deg(0), s = deg(6), f = deg(10), h = deg(10), n = deg(-10) }),
			legs({ s = deg(30), c = deg(60) })
		)
	else
		tumble = merge(
			{ bpitch = deg(-30), broll = side * deg(45), npitch = deg(-20), hpitch = deg(-12), fall = 0.5 },
			wings({ e = deg(60), f = deg(40), h = deg(35) }, up),
			wings({ e = deg(-25), f = deg(10) }, down),
			legs({ s = deg(-15), c = deg(35) })
		)
		contact = merge(
			{ bpitch = deg(-15), broll = side * deg(88), npitch = deg(-30), hpitch = deg(-18), fall = 1 },
			wings({ e = deg(65), s = deg(-40), f = deg(120), h = deg(110) }, up),
			wings({ e = deg(85), s = deg(-5), f = deg(5) }, down),
			legs({ s = deg(-10), c = deg(50) })
		)
		lie = merge(
			{
				bpitch = deg(-5),
				broll = side * deg(100),
				npitch = deg(-40),
				hpitch = deg(-20),
				tpitch = deg(-8),
				fall = 1,
			},
			wings({ e = deg(70), s = deg(-70), f = deg(160), h = deg(160), n = deg(-20) }, up),
			wings({ e = deg(100), s = deg(-5), f = 0, h = 0 }, down),
			legs({ s = deg(-20), c = deg(60) })
		)
	end
	local bounce = merge(lie, { by = 0.1 })
	return {
		strike = 0.1,
		follow = 0.4,
		recover = 0.3,
		hold = true,
		keys = {
			key(
				"S",
				1,
				"out",
				merge(
					{ bz = 0.1, by = 0.1, bpitch = deg(12), npitch = deg(14), hpitch = deg(8), jaw = deg(30) },
					wings({ e = deg(35), f = 0 })
				)
			),
			-- gravity: a quarter of the way down by half the time (`fall` squared)
			key("F", 0.5, "lin", tumble),
			key("F", 1, "lin", contact),
			key("R", 0.35, "out", bounce),
			key("R", 1, "inout", lie),
		},
	}
end

local CROW: Style = {
	modes = {
		hover = {
			hz = 4.2,
			top = deg(62),
			bottom = deg(-42),
			fore = deg(12),
			back = deg(-18),
			fold = deg(55),
			twist = deg(22),
			bob = 0.1,
			pitch = deg(4),
			tail = deg(6),
		},
		flight = {
			hz = 3.6,
			top = deg(45),
			bottom = deg(-32),
			fore = deg(6),
			back = deg(-12),
			fold = deg(40),
			twist = deg(20),
			bob = 0.06,
			pitch = deg(2),
			tail = deg(4),
		},
		hard = {
			hz = 5.2,
			top = deg(70),
			bottom = deg(-48),
			fore = deg(15),
			back = deg(-22),
			fold = deg(60),
			twist = deg(25),
			bob = 0.16,
			pitch = deg(5),
			tail = deg(8),
		},
	},
	glide = {
		elevation = deg(6),
		sweep = deg(-8),
		fold = deg(8),
		pitch = deg(-4),
		wobble = deg(3),
		chance = 0.25,
		every = 3,
		after = 2,
		length = { 0.5, 1 },
	},
	cruise = 10,
	lean = deg(-10),
	bank = deg(40),
	flare = merge(
		{ bpitch = deg(18), npitch = deg(-6), fan = deg(28), tpitch = deg(-12) },
		wings({ e = deg(40), s = deg(25), n = deg(15) }),
		legs({ s = deg(30), c = deg(-20) })
	),
	hang = C_HANG,
	tuck = C_TUCK,
	stance = C_STANCE,
	calm = { npitch = deg(4), hpitch = deg(-2) },
	drift = { x = 0.1, z = 0.08, yaw = deg(8), hz = 0.25 },
	saccade = { yaw = deg(50), pitch = deg(15), hold = { 0.25, 0.8 } },
	stun = merge({ hpitch = deg(-14), npitch = deg(-10), tpitch = deg(-8) }, wings({ e = deg(-10), f = deg(15) })),
	basic = { "shot" },
	abilities = { wail = "wail", heavyBlow = "rake", crush = "stoop", pounce = "pounce" },
	throw = "shot",
	death = { "deathFall", "deathFallBack" },
	aggro = "alert",
	spawn = "spawn",
	summon = "summon",
	fidgets = { "preen", "look" },
	fidgetEvery = { 3, 7 },
	rate = 0.08,
	spread = deg(12),
	perch = {
		pose = C_PERCH,
		toe = 0.06,
		after = { 4, 9 },
		land = 0.8,
		rise = 0.35,
		hop = {
			every = { 1.2, 3.5 },
			length = 0.28,
			height = 0.22,
			reach = 0.6,
			turn = deg(35),
			-- in the air: the wings flick open, the legs draw up
			air = merge(
				{ bpitch = deg(-6) },
				wings({ e = deg(25), s = deg(20), f = deg(-40), h = deg(-40) }),
				legs({ s = deg(15), c = deg(25) })
			),
		},
		fidgets = { "peck", "perchLook", "perchPreen" },
		every = { 1.5, 4 },
	},
	flinch = {
		front = merge(
			{ bz = 0.3, by = -0.2, bpitch = deg(10), npitch = deg(10), hpitch = deg(-6) },
			wings({ e = deg(30) })
		),
		back = merge({ bz = -0.3, by = -0.2, bpitch = deg(-10), tpitch = deg(15) }, wings({ e = deg(30) })),
		left = merge({ bx = 0.3, by = -0.2, broll = deg(-14), hyaw = deg(-12) }, wings({ e = deg(30) })),
		right = merge({ bx = -0.3, by = -0.2, broll = deg(14), hyaw = deg(12) }, wings({ e = deg(30) })),
	},
	actions = {
		-- the shot (W 0.5): a flare with the wings high and back, one hard downstroke that flings it with the head
		-- thrust forward on the hit, the recoil back, the beat resumes
		shot = {
			strike = 0.14,
			follow = 0.15,
			recover = 0.25,
			keys = {
				key(
					"A",
					1,
					"inout",
					cs(
						{
							bpitch = deg(18),
							by = 0.2,
							npitch = deg(12),
							hpitch = deg(-6),
							fan = deg(25),
							tpitch = deg(8),
						},
						wings({ e = deg(65), s = deg(-25), f = 0, h = 0, t = deg(-10) }),
						legs({ s = deg(-10), c = deg(30) })
					)
				),
				key(
					"S",
					1,
					"in",
					cs(
						{ bpitch = deg(4), by = 0.15, bz = 0.2, npitch = deg(-16), hpitch = deg(-8), fan = deg(18) },
						wings({ e = deg(-40), s = deg(10), w = deg(18), p = deg(12), n = deg(15) }),
						legs({ s = deg(-20), c = deg(40) })
					)
				),
				key(
					"F",
					1,
					"out",
					cs(
						{ bpitch = deg(2), by = 0.08, bz = 0.12, npitch = deg(-8), hpitch = deg(-10), fan = deg(12) },
						wings({ e = deg(-25), s = deg(5), f = deg(15), w = deg(-6) }),
						legs({ s = deg(-18), c = deg(30) })
					)
				),
				key("R", 1, "inout", merge(cs(C_MID), { flap = 0.6 })),
			},
		},
		-- the wail (Elite II own, W 1.2): it rises with the wings spread wide and the head thrown back, trembling more
		-- and more, then the neck thrusts out and the wings snap forward on the hit; the caw is held
		wail = {
			strike = 0.14,
			follow = 0.3,
			recover = 0.35,
			tremble = deg(2),
			keys = {
				key(
					"A",
					0.25,
					"out",
					cs(
						{
							by = 0.35,
							bpitch = deg(15),
							npitch = deg(22),
							hpitch = deg(14),
							fan = deg(32),
							tpitch = deg(10),
						},
						wings({ e = deg(25), s = 0, f = 0, h = 0, n = deg(15) }),
						legs({ s = deg(-10), c = deg(25) }),
						{ flap = 0.25, hard = 0.6 }
					)
				),
				key(
					"A",
					1,
					"inout",
					cs(
						{
							by = 0.38,
							bpitch = deg(18),
							npitch = deg(28),
							hpitch = deg(16),
							fan = deg(34),
							tpitch = deg(12),
						},
						wings({ e = deg(27), s = deg(-4), f = 0, h = 0, n = deg(18) }),
						legs({ s = deg(-10), c = deg(30) }),
						{ flap = 0.2, hard = 0.6 }
					)
				),
				key(
					"S",
					1,
					"in",
					cs(
						{ by = 0.2, bz = 0.25, bpitch = deg(-4), npitch = deg(-30), hpitch = deg(-12), fan = deg(30) },
						wings({ e = deg(0), s = deg(25), f = deg(5), w = deg(10) }),
						legs({ s = deg(-25), c = deg(45) })
					)
				),
				key(
					"F",
					0.6,
					"out",
					cs(
						{ by = 0.22, bz = 0.15, bpitch = deg(2), npitch = deg(-26), hpitch = deg(-8), fan = deg(26) },
						wings({ e = deg(5), s = deg(18), f = deg(8) }),
						legs({ s = deg(-22), c = deg(40) }),
						{ shake = deg(6), flap = 0.15 }
					)
				),
				key(
					"F",
					1,
					"inout",
					cs({ by = 0.15, bz = 0.08, npitch = deg(-10), fan = deg(18) }, C_MID, { flap = 0.4 })
				),
				key("R", 1, "inout", merge(cs(C_MID), { flap = 0.6 })),
			},
		},
		-- the talon rake (Elite Heavy Blow, W 1.8): up with hard beats, the legs swing forward with the talons open,
		-- trembling, then a swoop forward and down raking them through on the hit, it pulls up and goes back
		rake = {
			strike = 0.14,
			follow = 0.15,
			recover = 0.5,
			tremble = deg(1.5),
			keys = {
				key(
					"A",
					0.65,
					"out",
					cs({
						by = 0.6,
						bpitch = deg(22),
						npitch = deg(10),
						hpitch = deg(-12),
						fan = deg(30),
						tpitch = deg(-6),
					}, legs({ s = deg(70), c = deg(-35) }), C_MID, { flap = 1, hard = 1 })
				),
				key(
					"A",
					1,
					"inout",
					cs({
						by = 0.62,
						bpitch = deg(28),
						npitch = deg(12),
						hpitch = deg(-14),
						fan = deg(32),
						tpitch = deg(-8),
					}, legs({ s = deg(52), c = deg(-25) }), C_MID, { flap = 0.7, hard = 1 })
				),
				key(
					"S",
					1,
					"in",
					cs(
						{ by = -0.35, bz = -1.2, bpitch = deg(-2), npitch = deg(-6), hpitch = deg(-6), fan = deg(20) },
						legs({ s = deg(22), c = deg(30) }),
						wings({ e = deg(5), s = deg(8), f = 0, w = deg(14) })
					)
				),
				key(
					"F",
					1,
					"out",
					cs(
						{ by = -0.1, bz = -0.9, bpitch = deg(12), npitch = deg(-4), fan = deg(24) },
						legs({ s = deg(-25), c = deg(50) }),
						C_MID,
						{ flap = 1, hard = 1 }
					)
				),
				key("R", 1, "inout", merge(cs(C_MID), { flap = 1, hard = 0.4 })),
			},
		},
		-- the stoop (Elite II Crushing Blow, W 2.2): a climb of 2 studs with hard beats turning on the target, the
		-- wings fold and the nose goes down, a dive along an arc toward it (6 studs out at most, down to the ground) with
		-- the talons forward and the wings flaring open on the hit; it pulls up and climbs back
		stoop = {
			strike = 0.3,
			follow = 0.2,
			recover = 0.5,
			tremble = deg(1.5),
			keys = {
				key(
					"A",
					0.6,
					"out",
					cs(
						{ by = 2, bpitch = deg(15), npitch = deg(-8), hpitch = deg(-14), fan = deg(28) },
						C_TUCK,
						C_MID,
						{
							flap = 1,
							hard = 1,
						}
					)
				),
				key(
					"A",
					0.85,
					"inout",
					cs(
						{ by = 2.1, bpitch = deg(-40), npitch = deg(18), hpitch = deg(26), fan = 0, tpitch = deg(10) },
						C_TUCK,
						wings({ e = deg(-10), s = deg(-20), f = deg(80), h = deg(60), n = deg(-20) })
					)
				),
				key(
					"A",
					1,
					"inout",
					cs(
						{ by = 2.1, bpitch = deg(-50), npitch = deg(20), hpitch = deg(30), fan = 0, tpitch = deg(10) },
						C_TUCK,
						wings({ e = deg(-12), s = deg(-22), f = deg(85), h = deg(65), n = deg(-20) })
					)
				),
				key(
					"S",
					1,
					"in",
					cs(
						{
							by = 0,
							bpitch = deg(15),
							npitch = deg(-5),
							hpitch = deg(-10),
							fan = deg(34),
							tpitch = deg(-12),
							travel = 1,
							reachMax = 6,
							drop = 0.8,
						},
						legs({ s = deg(65), c = deg(-35) }),
						wings({ e = deg(60), s = deg(20), f = 0, h = 0, n = deg(20) })
					)
				),
				key(
					"F",
					1,
					"out",
					cs(
						{ by = 0.5, bpitch = deg(20), fan = deg(24), travel = 0.8, reachMax = 6, drop = 0.4 },
						legs({ s = deg(-20), c = deg(50) }),
						C_MID,
						{ flap = 1, hard = 1 }
					)
				),
				key("R", 1, "inout", merge(cs(C_MID), { flap = 1, hard = 0.5, reachMax = 6 })),
			},
		},
		-- the pounce (Elite II, W 1.4; the server moves it on the hit): it sinks with the wings cocked high, then flies
		-- the leap's arc with hard beats, talons forward on the hit
		pounce = {
			strike = 0.4,
			follow = 0.25,
			recover = 0.45,
			tremble = deg(1),
			keys = {
				key(
					"A",
					0.7,
					"out",
					cs(
						{ by = -0.3, bpitch = deg(10), npitch = deg(-8), hpitch = deg(-10), fan = deg(20) },
						wings({ e = deg(70), s = deg(-15), f = deg(10) }),
						legs({ s = deg(20), c = deg(10) }),
						{ flap = 0.15 }
					)
				),
				key(
					"S",
					0.5,
					"inout",
					cs(
						{ by = -0.1, bpitch = deg(-10), npitch = deg(-10), hpitch = deg(-6), travel = 0.45, arc = 0.6 },
						legs({ s = deg(40), c = deg(-10) }),
						C_MID,
						{ flap = 1, hard = 1 }
					)
				),
				key(
					"S",
					1,
					"in",
					cs(
						{ by = -0.2, bpitch = deg(15), npitch = deg(-6), hpitch = deg(-12), travel = 1, arc = 0.6 },
						legs({ s = deg(70), c = deg(-35) }),
						wings({ e = deg(50), s = deg(15), f = 0, n = deg(15) })
					)
				),
				key(
					"F",
					1,
					"out",
					cs(
						{ bpitch = deg(5), travel = 1 },
						legs({ s = deg(10), c = deg(50) }),
						C_MID,
						{ flap = 1, hard = 1 }
					)
				),
				key("R", 1, "inout", merge(cs(C_MID), { flap = 1, hard = 0.4 })),
			},
		},
		-- the alert: one hard beat, the head snaps to the target and the neck stretches up in a caw
		alert = {
			strike = 0.1,
			follow = 0.15,
			recover = 0.3,
			keys = {
				key(
					"A",
					1,
					"out",
					cs({ by = 0.15, npitch = deg(-6), hpitch = deg(-4), fan = deg(24) }, { flap = 1, hard = 1 })
				),
				key(
					"S",
					1,
					"out",
					cs({ by = 0.2, npitch = deg(18), hpitch = deg(14), fan = deg(30) }, { flap = 0.5, hard = 1 })
				),
				key(
					"F",
					1,
					"lin",
					cs({ by = 0.15, npitch = deg(15), hpitch = deg(10), fan = deg(26), shake = deg(4) }, { flap = 0.6 })
				),
				key("R", 1, "inout", merge(cs(C_MID), { flap = 1 })),
			},
		},
		-- the spawn: up from the ground to the hover with hard beats
		spawn = {
			strike = 0.25,
			follow = 0.4,
			recover = 0.2,
			keys = {
				key(
					"A",
					0,
					"lin",
					merge(
						{ drop = 0.85, bpitch = deg(25), npitch = deg(10) },
						legs({ s = deg(10), c = deg(20) }),
						C_MID,
						{ flap = 1, hard = 1 }
					)
				),
				key(
					"S",
					1,
					"out",
					merge({ drop = 0.35, bpitch = deg(15), npitch = deg(5) }, C_HANG, C_MID, { flap = 1, hard = 1 })
				),
				key(
					"F",
					1,
					"inout",
					merge(
						{ drop = 0, by = 0.15, bpitch = deg(5), shake = deg(5) },
						C_HANG,
						C_MID,
						{ flap = 1, hard = 1 }
					)
				),
				key("R", 1, "inout", merge(C_HANG, C_MID, { flap = 1, hard = 0.3 })),
			},
		},
		-- a boss's helper: it bursts up out of the ground (wings half folded, opening into hard beats on the way up), a
		-- last bob into the hover
		summon = {
			strike = 0.2,
			follow = 0.3,
			recover = 0.3,
			keys = {
				key("A", 0, "lin", merge({ drop = 1, bpitch = deg(20), npitch = deg(-10), shake = deg(4) }, C_HALF)),
				key(
					"A",
					1,
					"inout",
					merge(
						{ drop = 0.8, bpitch = deg(24), npitch = deg(0) },
						wings({ e = deg(25), s = deg(-15), f = deg(40), h = deg(35), n = deg(-5) }),
						{ flap = 0.4, hard = 1 }
					)
				),
				key(
					"S",
					1,
					"out",
					merge({ drop = 0.4, bpitch = deg(25), npitch = deg(10) }, C_HANG, C_MID, { flap = 1, hard = 1 })
				),
				key(
					"F",
					0.4,
					"out",
					merge({ drop = 0, by = 0.2, bpitch = deg(10) }, C_HANG, C_MID, { flap = 1, hard = 1 })
				),
				key("F", 1, "in", merge({ by = 0 }, C_HANG, C_MID, { flap = 1, hard = 0.5 })),
				key("R", 1, "inout", merge(C_HANG, C_MID, { flap = 1 })),
			},
		},
		deathFall = deathDrop(1, false),
		deathFallBack = deathDrop(-1, true),
		-- idle: it turns its head back to a wing and nibbles at the feathers, the wing a little open
		preen = {
			strike = 0.2,
			follow = 0.7,
			recover = 0.25,
			keys = {
				key(
					"S",
					1,
					"out",
					merge(
						{ hyaw = deg(60), nyaw = deg(30), hpitch = deg(-25), npitch = deg(-8) },
						wings({ e = deg(15), s = deg(-15) }, "L"),
						C_MID,
						{ flap = 0.5 }
					)
				),
				key(
					"F",
					0.5,
					"inout",
					merge(
						{ hyaw = deg(66), nyaw = deg(32), hpitch = deg(-30), npitch = deg(-10), shake = deg(4) },
						wings({ e = deg(15), s = deg(-15) }, "L"),
						C_MID,
						{ flap = 0.5 }
					)
				),
				key(
					"F",
					1,
					"inout",
					merge(
						{ hyaw = deg(58), nyaw = deg(28), hpitch = deg(-22), npitch = deg(-8) },
						wings({ e = deg(15), s = deg(-15) }, "L"),
						C_MID,
						{ flap = 0.5 }
					)
				),
				key("R", 1, "inout", merge(C_MID, { flap = 1 })),
			},
		},
		-- idle: a long look to one side, then the other
		look = {
			strike = 0.1,
			follow = 0.9,
			recover = 0.25,
			keys = {
				key("S", 1, "out", merge({ hyaw = deg(35), nyaw = deg(15), hroll = deg(-8) }, C_MID, { flap = 1 })),
				key(
					"F",
					0.45,
					"inout",
					merge({ hyaw = deg(35), nyaw = deg(15), hroll = deg(-8) }, C_MID, { flap = 1 })
				),
				key("F", 0.6, "out", merge({ hyaw = deg(-30), nyaw = deg(-12), hroll = deg(8) }, C_MID, { flap = 1 })),
				key("F", 1, "inout", merge({ hyaw = deg(-30), nyaw = deg(-12) }, C_MID, { flap = 1 })),
				key("R", 1, "inout", merge(C_MID, { flap = 1 })),
			},
		},
		-- on the ground: two quick pecks at something there
		peck = {
			strike = 0.12,
			follow = 0.45,
			recover = 0.25,
			keys = {
				key("S", 1, "in", cp({ bpitch = deg(-12), npitch = deg(-48), hpitch = deg(-30), tpitch = deg(38) })),
				key("F", 0.3, "out", cp({ bpitch = deg(-2), npitch = deg(-35), hpitch = deg(-22), tpitch = deg(32) })),
				key("F", 0.55, "in", cp({ bpitch = deg(-13), npitch = deg(-50), hpitch = deg(-32), tpitch = deg(40) })),
				key("F", 1, "out", cp({ bpitch = deg(6), npitch = deg(-25), hpitch = deg(-15), tpitch = deg(28) })),
				key("R", 1, "inout", C_PERCH),
			},
		},
		-- on the ground: the head cocked to one side (one eye on the sky), then the other
		perchLook = {
			strike = 0.1,
			follow = 1,
			recover = 0.25,
			keys = {
				key("S", 1, "out", cp({ hyaw = deg(45), nyaw = deg(15), hroll = deg(-20) })),
				key("F", 0.5, "inout", cp({ hyaw = deg(45), nyaw = deg(15), hroll = deg(-20) })),
				key("F", 0.62, "out", cp({ hyaw = deg(-40), nyaw = deg(-12), hroll = deg(18) })),
				key("F", 1, "inout", cp({ hyaw = deg(-40), nyaw = deg(-12), hroll = deg(18) })),
				key("R", 1, "inout", C_PERCH),
			},
		},
		-- on the ground: it preens under a half-open wing
		perchPreen = {
			strike = 0.25,
			follow = 0.8,
			recover = 0.3,
			keys = {
				key(
					"S",
					1,
					"out",
					cp(
						{ hyaw = deg(70), nyaw = deg(35), hpitch = deg(-25), npitch = deg(-10) },
						wings({ e = deg(5), s = deg(-35), f = deg(60), h = deg(60), n = 0 }, "L")
					)
				),
				key(
					"F",
					0.5,
					"inout",
					cp(
						{ hyaw = deg(75), nyaw = deg(38), hpitch = deg(-30), npitch = deg(-12), shake = deg(4) },
						wings({ e = deg(5), s = deg(-35), f = deg(60), h = deg(60), n = 0 }, "L")
					)
				),
				key(
					"F",
					1,
					"inout",
					cp(
						{ hyaw = deg(65), nyaw = deg(32), hpitch = deg(-22), npitch = deg(-10) },
						wings({ e = deg(0), s = deg(-40), f = deg(70), h = deg(70), n = 0 }, "L")
					)
				),
				key("R", 1, "inout", C_PERCH),
			},
		},
	},
}

---------------------------------------------------------------- bat (bloodBat, its new export)

-- A bat: fast deep beats with the membrane fingers fanned on the downstroke, an erratic hover that never holds still,
-- a melee dive bite (the jaw opens on the strike) aimed at its target; it never lands (it would hang from a ceiling
-- it does not have). The same action names as its rigid recipe (Data/RigidStyles bat, Data/MotionFx).
local B_STANCE: Controls = { npitch = deg(-4), hpitch = deg(6), jaw = deg(8) }
local function bs(...: Controls): Controls
	return merge(B_STANCE, ...)
end
local B_MID = wings({ e = deg(10), s = 0, f = deg(15), n = deg(-10) })

local BAT: Style = variant(CROW, {
	modes = {
		hover = {
			hz = 6,
			top = deg(70),
			bottom = deg(-50),
			fore = deg(15),
			back = deg(-20),
			fold = deg(60),
			twist = deg(25),
			bob = 0.14,
			pitch = deg(5),
			tail = deg(6),
		},
		flight = {
			hz = 5.4,
			top = deg(55),
			bottom = deg(-40),
			fore = deg(8),
			back = deg(-14),
			fold = deg(50),
			twist = deg(22),
			bob = 0.1,
			pitch = deg(3),
			tail = deg(5),
		},
		hard = {
			hz = 8,
			top = deg(75),
			bottom = deg(-55),
			fore = deg(16),
			back = deg(-22),
			fold = deg(65),
			twist = deg(28),
			bob = 0.18,
			pitch = deg(6),
			tail = deg(8),
		},
	},
	glide = {
		elevation = deg(4),
		sweep = deg(-6),
		fold = deg(10),
		pitch = deg(-4),
		wobble = deg(4),
		chance = 0.15,
		every = 3,
		after = 2,
		length = { 0.3, 0.6 },
	},
	cruise = 11,
	lean = deg(-12),
	bank = deg(45),
	flare = merge(
		{ bpitch = deg(20), npitch = deg(-6), tpitch = deg(-15) },
		wings({ e = deg(45), s = deg(25), n = deg(25) })
	),
	hang = {},
	tuck = {},
	stance = B_STANCE,
	calm = { npitch = deg(4), hpitch = deg(-2), jaw = 0 },
	drift = { x = 0.12, z = 0.08, yaw = deg(10), hz = 0.27 },
	saccade = { yaw = deg(30), pitch = deg(12), hold = { 0.3, 0.9 } },
	stun = merge(
		{ hpitch = deg(-16), npitch = deg(-10), jaw = deg(20), tpitch = deg(-10) },
		wings({ e = deg(-15), f = deg(25), n = deg(-20) })
	),
	basic = { "dive" },
	throw = "dive",
	death = { "deathFallBack", "deathFall" },
	fidgets = { "flutter", "look" },
	fidgetEvery = { 2, 5 },
	rate = 0.1,
	spread = deg(22),
	jitter = { rate = 0.25, hz = 2.2, x = 0.12, y = 0.1, roll = deg(7) },
	actions = {
		-- the dive bite (the basic melee blow): up with the wings high, a swoop forward and down at the target (aimed
		-- until the strike, then locked; 2.5 studs at most) dropping almost half its height to the target's chest
		-- with the jaw opening, the bite on the hit, back up
		dive = {
			strike = 0.18,
			follow = 0.12,
			recover = 0.35,
			keys = {
				key(
					"A",
					1,
					"out",
					bs(
						{ by = 0.3, bz = 0.1, bpitch = deg(15), npitch = deg(8), hpitch = deg(4) },
						wings({ e = deg(70), s = deg(-25), f = 0, n = deg(20) }),
						{ hard = 0.6 }
					)
				),
				key(
					"S",
					0.5,
					"in",
					bs({
						by = 0.05,
						bpitch = deg(-25),
						npitch = deg(-6),
						jaw = deg(25),
						lunge = 0.55,
						reachMax = 2.5,
						drop = 0.2,
					}, wings({ e = deg(10), s = deg(10), f = deg(10) }))
				),
				key(
					"S",
					1,
					"in",
					bs({
						by = -0.1,
						bpitch = deg(-15),
						npitch = deg(-12),
						hpitch = deg(-10),
						jaw = deg(45),
						lunge = 1,
						reachMax = 2.5,
						drop = 0.45,
					}, wings({ e = deg(-40), s = deg(20), n = deg(25) }))
				),
				key(
					"F",
					1,
					"out",
					bs(
						{ by = -0.05, bpitch = deg(5), jaw = deg(5), lunge = 0.9, reachMax = 2.5, drop = 0.35 },
						wings({ e = deg(-20), s = deg(10) }),
						{ flap = 0.5 }
					)
				),
				key(
					"R",
					0.5,
					"out",
					bs({ by = 0.15, bpitch = deg(8), lunge = 0.3, reachMax = 2.5, drop = 0.1 }, B_MID, { flap = 1 })
				),
				key("R", 1, "inout", merge(bs(B_MID), { flap = 1 })),
			},
		},
		-- the wail: it rears up with the wings spread and the jaw wide, trembling, thrusts its head out on the hit
		-- screaming, the scream held
		wail = {
			strike = 0.14,
			follow = 0.3,
			recover = 0.35,
			tremble = deg(2),
			keys = {
				key(
					"A",
					0.25,
					"out",
					bs({
						by = 0.35,
						bpitch = deg(20),
						npitch = deg(18),
						hpitch = deg(12),
						jaw = deg(20),
						tpitch = deg(-10),
					}, wings({ e = deg(30), s = 0, f = 0, h = 0, n = deg(25) }), { flap = 0.25, hard = 0.6 })
				),
				key(
					"A",
					1,
					"inout",
					bs({
						by = 0.38,
						bpitch = deg(22),
						npitch = deg(22),
						hpitch = deg(14),
						jaw = deg(30),
						tpitch = deg(-12),
					}, wings({ e = deg(32), s = deg(-4), f = 0, h = 0, n = deg(28) }), { flap = 0.2, hard = 0.6 })
				),
				key(
					"S",
					1,
					"in",
					bs(
						{ by = 0.2, bz = 0.2, bpitch = deg(-4), npitch = deg(-25), hpitch = deg(-10), jaw = deg(55) },
						wings({ e = deg(0), s = deg(25), f = deg(5), w = deg(10), n = deg(20) })
					)
				),
				key(
					"F",
					0.6,
					"out",
					bs(
						{ by = 0.22, bz = 0.15, npitch = deg(-22), hpitch = deg(-8), jaw = deg(50) },
						wings({ e = deg(5), s = deg(18), f = deg(8) }),
						{ shake = deg(6), flap = 0.15 }
					)
				),
				key(
					"F",
					1,
					"inout",
					bs({ by = 0.15, bz = 0.08, npitch = deg(-10), jaw = deg(20) }, B_MID, { flap = 0.4 })
				),
				key("R", 1, "inout", merge(bs(B_MID), { flap = 0.6 })),
			},
		},
		-- the alert: a hard beat, the head snaps to the target with a hiss (the jaw open)
		alert = {
			strike = 0.1,
			follow = 0.15,
			recover = 0.3,
			keys = {
				key("A", 1, "out", bs({ by = 0.15, npitch = deg(-6), hpitch = deg(-4) }, { flap = 1, hard = 1 })),
				key(
					"S",
					1,
					"out",
					bs({ by = 0.2, npitch = deg(12), hpitch = deg(10), jaw = deg(45) }, { flap = 0.6, hard = 1 })
				),
				key(
					"F",
					1,
					"lin",
					bs({ by = 0.15, npitch = deg(10), hpitch = deg(8), jaw = deg(40), shake = deg(4) }, { flap = 0.8 })
				),
				key("R", 1, "inout", merge(bs(B_MID), { flap = 1 })),
			},
		},
		-- idle: a burst of hard beats with a hop up and a shake
		flutter = {
			strike = 0.12,
			follow = 0.4,
			recover = 0.25,
			keys = {
				key("S", 1, "out", merge({ by = 0.2, bpitch = deg(8), shake = deg(5) }, { flap = 1, hard = 1 })),
				key("F", 1, "inout", merge({ by = 0.12, bpitch = deg(4), shake = deg(3) }, { flap = 1, hard = 0.6 })),
				key("R", 1, "inout", { flap = 1 }),
			},
		},
		-- idle: the head turns to one side and back, the ears pricked
		look = {
			strike = 0.1,
			follow = 0.9,
			recover = 0.25,
			keys = {
				key("S", 1, "out", merge({ hyaw = deg(30), nyaw = deg(12), hroll = deg(-10) }, { flap = 1 })),
				key("F", 0.5, "inout", merge({ hyaw = deg(30), nyaw = deg(12), hroll = deg(-10) }, { flap = 1 })),
				key("F", 0.62, "out", merge({ hyaw = deg(-25), nyaw = deg(-10), hroll = deg(8) }, { flap = 1 })),
				key("F", 1, "inout", merge({ hyaw = deg(-25), nyaw = deg(-10) }, { flap = 1 })),
				key("R", 1, "inout", { flap = 1 }),
			},
		},
		deathFall = deathDrop(1, false),
		-- (its body hangs nose-up in the air: less of a flip lays it flat, the tail membrane drawn up off the ground)
		deathFallBack = deathDrop(
			-1,
			true,
			merge(
				{ bpitch = deg(145), tpitch = deg(-70) },
				wings({ e = deg(12), s = deg(6), f = deg(10), h = deg(10) })
			)
		),
	},
})
-- (it never perches)
BAT.perch = nil

local STYLES: { [string]: Style } = {
	vulture = VULTURE,
	harpy = HARPY,
	crow = CROW,
	bat = BAT,
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

-- The states `/animlab mob <id> <state>` shows for a flyer style: LAB_STATES with the kit's slots (as the rigid kinds
-- name them: heavy, crush, pounce, throw, summon) and `perch` where the style has them, and every action by name;
-- `with` (a kind on both templates: the crow, the bat) is added first.
function FlyerStyles.labStates(id: string, with: { string }?): { string }
	local out: { string } = if with then table.clone(with) else {}
	local function add(name: string)
		if not table.find(out, name) then
			table.insert(out, name)
		end
	end
	for _, name in FlyerStyles.LAB_STATES do
		add(name)
	end
	local style = STYLES[id]
	if style then
		local slots: { [string]: boolean } = {
			heavy = style.abilities.heavyBlow ~= nil,
			crush = style.abilities.crush ~= nil,
			pounce = style.abilities.pounce ~= nil,
			throw = style.throw ~= nil,
			summon = style.summon ~= nil,
			perch = style.perch ~= nil,
		}
		for _, slot in { "heavy", "crush", "pounce", "throw", "summon", "perch" } do
			if slots[slot] then
				add(slot)
			end
		end
		local names: { string } = {}
		for name in style.actions do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			add(name)
		end
	end
	return out
end

return FlyerStyles
