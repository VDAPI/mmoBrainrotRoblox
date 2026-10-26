--!strict
-- Template animation (owner 2026-10-25): the styles of imported biped monsters animated by Logic/BipedMotion instead of
-- their baked clips. A style holds:
-- * `clips`: the mocap of the base layer (Data/BipedClips): idle variants, walk and run (their ground speed is baked);
-- * `guard`: the combat stance (Logic/BipedPose controls) laid over the base while the monster fights;
-- * `actions`: keyed motions (attacks, abilities, reactions, death, spawn). A key sits in one of four segments of the
--   action's timeline: "A" anticipation (stretched to the server's windup), "S" strike (ends exactly on the server's
--   hit), "F" follow-through, "R" recovery; `u` is the place in its segment (0..1), `ease` the curve that reaches it
--   ("in" accelerates into the key, "out" decelerates, "inout" both, "lin"). The pose of a key is the guard with its
--   own controls laid over; the action starts and ends in the guard.
-- * `flinch`: additive turns of a hit by side; `pick`: which action plays an attack.
-- Distances in controls are leg lengths (hip joint over the ground), so a style fits every biped of its family.

local BossStyles = require("./BossStyles")

local BipedStyles = {}

export type Key = { seg: string, u: number, ease: string?, pose: { [string]: number } }
export type Action = {
	keys: { Key },
	strike: number, -- seconds of the strike segment (shorter when the windup is short)
	follow: number,
	recover: number,
	legs: boolean, -- the action keys the legs (else the locomotion keeps them)
	hold: boolean?, -- the last key holds (death)
	travel: boolean?, -- the pelvis and feet travel toward the target (Input.action.reach) by the key's `travel`
	full: boolean?, -- weight 1 on the legs even while moving (death)
	lag: { [string]: number }?, -- seconds the head / free arm trail the body (overlapping action)
	-- the bosses (Data/BossStyles, 2026-10-26): a channel holds the blow for the run's `hold` (keys in segment "H"
	-- between the hit and the follow-through) and turns the body by the run's `turn` (`turnFeet`: the share of the
	-- turn the feet take, the rest twists the body); a leap flies the run's arc over its last `arc` seconds
	channel: boolean?,
	turnFeet: number?,
	leap: boolean?,
}
export type Style = {
	grip: { number }?, -- the blade's direction in the right hand at rest (root space): keys aim it with bRx bRy bRz
	clips: { idle: { string }, walk: string, run: string }?, -- nil: the procedural gait of `procedural`
	guard: { [string]: number },
	actions: { [string]: Action },
	flinch: { [string]: { [string]: number } },
	basic: { string }, -- the regular blow cycles through these
	abilities: { [string]: string }, -- ability id (Data/MonsterAbilities) -> action
	throw: string?,
	death: { string },
	aggro: string?,
	spawn: string?,
	idleEvery: { number }, -- seconds between idle variants (min, max)
	rate: number, -- spread of the playback rate between instances (+-)
	float: boolean?, -- a floating body (ghosts): no steps, a drifting bob instead of walk and run
	-- a procedural gait instead of mocap (Logic/BipedMotion): the rest pose, walk and run (stride k in leg lengths, duty,
	-- foot lift, pelvis bob / sway / yaw, forward lean) and the wingbeat in the air
	procedural: { [string]: any }?,
	-- a floating spirit on its bones (Logic/SpiritMotion): bob (leg lengths) and bobHz, sway (rad) and swayHz, lean (rad
	-- at `speed` studs/s) and leanLag (s), flicker { mid, amplitude, Hz } of the look's fade, trail (the specter's robe:
	-- pitch and roll gains, lag and lag2 of its halves, flutter)
	spirit: { [string]: any }?,
	boss: BossLayer?, -- a boss's weight, stances and roars (Data/BossStyles)
}
-- The boss layer (Data/BossStyles, 2026-10-26): the weight of its walk, its stance out of the fight and in its states,
-- its roars.
export type BossLayer = {
	dip: number, -- leg lengths the pelvis drops after each footfall (the knees take it, the feet stay planted)
	roll: number, -- rad the pelvis rolls over the standing leg
	lean: number, -- rad the spine leans into the walk
	wide: number, -- leg lengths each foot steps wider than the clip's
	calm: number, -- the guard's weight out of the fight (a boss never idles like a passer-by)
	scan: number, -- rad of the slow head scan out of the fight
	breath: { number }, -- seconds and depth (rad of the chest) of a breath
	castDamp: number, -- how much a running action damps the flinch (0..1: a big cast is not interrupted)
	rage: { [string]: number }, -- the stance once enraged (attribute Enraged, the last phase)
	shield: { [string]: number }?, -- the stance while its helpers shield it (attribute Shielded)
	roar: string, -- the phase roar
	rageRoar: string, -- the roar into the last phase and at the enrage
	stagger: string, -- a broken channel (attribute Staggered)
	roarHit: number, -- seconds from a roar's start to its peak
}

-- A pose: the base with `over` laid on (absolute values).
local function from(base: { [string]: number }, over: { [string]: number }): { [string]: number }
	local out = table.clone(base)
	for k, v in over do
		out[k] = v
	end
	return out
end

---------------------------------------------------------------- humanoid, one-handed weapon (bandit)

-- The fighting stance: left foot forward, the weight low, the sword held forward at chest height, the free hand up.
local GUARD = {
	py = -0.1,
	pz = 0.02,
	pyaw = -0.3,
	ppitch = 0.06,
	syaw = 0.18,
	spitch = 0.14,
	hyaw = 0.12,
	hpitch = -0.08,
	cRu = 0.05,
	cLu = 0.03,
	aRp = 0.55,
	aRo = 0.42,
	aRy = 0.12,
	eR = 1.45,
	wRp = -0.55,
	bRx = -0.12,
	bRy = 0.58,
	bRz = -0.8,
	aLp = 0.65,
	aLo = 0.3,
	aLy = 0.55,
	eL = 1.35,
	fLz = -0.2,
	fLx = -0.03,
	fRz = 0.16,
	fRx = 0.05,
	fRyaw = -0.55,
	fLyaw = -0.15,
	fRp = 0.08,
}

local function g(over: { [string]: number }): { [string]: number }
	return from(GUARD, over)
end

local HUMANOID_1H: Style = {
	grip = { 0.42, -0.87, -0.22 },
	clips = { idle = { "idle", "idleShift", "idleLook" }, walk = "walk", run = "run" },
	guard = GUARD,
	idleEvery = { 7, 13 },
	rate = 0.06,
	basic = { "slash", "backhand", "slash", "thrust" },
	abilities = {
		cleave = "cleave",
		heavyBlow = "heavy",
		crush = "crush",
		pounce = "pounce",
		slam = "crush",
		leap = "pounce",
		charge = "charge",
		-- 2026-10-26 (Data/MotionFx): the breath from the mouth, a nova from the blade slammed into the ground
		fireBreath = "breath",
		frostBreath = "breath",
		emberNova = "crush",
		frostNova = "crush",
		boneNova = "crush",
	},
	throw = "throw",
	death = { "deathBack", "deathFwd" },
	aggro = "aggro",
	spawn = "spawn",
	flinch = {
		front = { spitch = -0.3, hpitch = -0.25, pz = 0.05, aRo = 0.15, aLo = 0.2, cRu = 0.08, cLu = 0.08 },
		back = { spitch = 0.32, hpitch = 0.2, pz = -0.04, ppitch = 0.06 },
		left = { sroll = -0.28, hroll = -0.2, syaw = 0.12, px = 0.04 },
		right = { sroll = 0.28, hroll = 0.2, syaw = -0.12, px = -0.04 },
	},
	actions = {
		-- forehand diagonal cut: the sword rises over the right shoulder, the body coils, then cuts across and down
		-- with a step of the front foot
		slash = {
			strike = 0.12,
			follow = 0.22,
			recover = 0.32,
			legs = true,
			lag = { head = 0.05, free = 0.07 },
			keys = {
				{
					seg = "A",
					u = 0.75,
					ease = "inout",
					pose = g({
						py = -0.13,
						pz = 0.07,
						pyaw = -0.45,
						syaw = -0.42,
						spitch = 0.0,
						sroll = 0.06,
						hyaw = 0.42,
						cRu = 0.2,
						aRp = 2.0,
						aRo = 0.75,
						aRy = -0.35,
						eR = 1.75,
						wRp = 0.35,
						bRx = 0.307,
						bRy = 0.767,
						bRz = 0.563,
						wRr = 0.2,
						aLp = 0.9,
						aLo = 0.45,
						aLy = 0.75,
						eL = 0.9,
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.14,
						pz = 0.08,
						pyaw = -0.5,
						syaw = -0.5,
						spitch = -0.03,
						sroll = 0.08,
						hyaw = 0.48,
						cRu = 0.24,
						aRp = 2.15,
						aRo = 0.8,
						aRy = -0.4,
						eR = 1.85,
						wRp = 0.4,
						bRx = 0.352,
						bRy = 0.553,
						bRz = 0.755,
						wRr = 0.25,
						aLp = 0.95,
						aLo = 0.5,
						aLy = 0.8,
						eL = 0.85,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.2,
						pz = -0.14,
						pyaw = 0.12,
						syaw = 0.55,
						spitch = 0.32,
						sroll = -0.05,
						hyaw = -0.3,
						hpitch = 0.05,
						cRu = 0,
						cRf = 0.18,
						aRp = 0.85,
						aRo = 0.1,
						aRy = 0.95,
						eR = 0.25,
						wRp = -0.4,
						bRx = -0.549,
						bRy = -0.249,
						bRz = -0.798,
						wRr = -0.15,
						aLp = -0.25,
						aLo = 0.55,
						aLy = 0,
						eL = 0.5,
						fLz = -0.34,
						fLyaw = -0.05,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.21,
						pz = -0.15,
						pyaw = 0.2,
						syaw = 0.72,
						spitch = 0.36,
						hyaw = -0.4,
						cRf = 0.22,
						aRp = 0.55,
						aRo = 0.1,
						aRy = 1.2,
						eR = 0.35,
						wRp = -1.0,
						bRx = -0.755,
						bRy = -0.553,
						bRz = -0.352,
						aLp = -0.35,
						aLo = 0.6,
						aLy = -0.1,
						eL = 0.45,
						fLz = -0.34,
						fLyaw = -0.05,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- backhand: from the left side, a flat cut back to the right
		backhand = {
			strike = 0.12,
			follow = 0.2,
			recover = 0.3,
			legs = true,
			lag = { head = 0.05, free = 0.06 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = g({
						py = -0.12,
						pyaw = 0.05,
						syaw = 0.55,
						spitch = 0.18,
						hyaw = -0.35,
						cRf = 0.2,
						aRp = 1.15,
						aRo = 0.05,
						aRy = 1.15,
						eR = 1.55,
						wRp = 0.7,
						bRx = -0.56,
						bRy = 0.56,
						bRz = 0.611,
						wRr = -0.6,
						aLp = 0.2,
						aLo = 0.55,
						aLy = 0,
						eL = 0.9,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.17,
						pz = -0.1,
						pyaw = -0.45,
						syaw = -0.55,
						spitch = 0.2,
						hyaw = 0.4,
						aRp = 1.2,
						aRo = 0.95,
						aRy = -0.55,
						eR = 0.2,
						wRp = -0.5,
						bRx = 0.552,
						bRy = -0.05,
						bRz = -0.833,
						wRr = 0.3,
						aLp = 0.7,
						aLo = 0.25,
						aLy = 0.85,
						eL = 1.1,
						fLz = -0.28,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.17,
						pz = -0.1,
						pyaw = -0.55,
						syaw = -0.7,
						spitch = 0.2,
						hyaw = 0.5,
						aRp = 1.05,
						aRo = 1.15,
						aRy = -0.85,
						eR = 0.3,
						wRp = -0.55,
						bRx = 0.862,
						bRy = 0.0,
						bRz = -0.507,
						aLp = 0.75,
						aLy = 0.9,
						eL = 1.2,
						fLz = -0.28,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- thrust: the arm draws back, then drives the point forward in a lunge
		thrust = {
			strike = 0.1,
			follow = 0.18,
			recover = 0.34,
			legs = true,
			lag = { head = 0.04, free = 0.06 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = g({
						py = -0.13,
						pz = 0.1,
						pyaw = -0.55,
						syaw = -0.35,
						spitch = 0.05,
						hyaw = 0.45,
						aRp = 0.35,
						aRo = 0.55,
						aRy = -0.35,
						eR = 2.1,
						wRp = -1.65,
						bRx = 0.0,
						bRy = 0.05,
						bRz = -0.999,
						aLp = 0.95,
						aLo = 0.2,
						aLy = 0.75,
						eL = 0.6,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.22,
						pz = -0.2,
						pyaw = 0.1,
						syaw = 0.3,
						spitch = 0.3,
						hyaw = -0.15,
						cRf = 0.3,
						aRp = 1.45,
						aRo = 0.15,
						aRy = 0.15,
						eR = 0.08,
						wRp = -0.7,
						bRx = -0.05,
						bRy = 0.0,
						bRz = -0.999,
						aLp = -0.3,
						aLo = 0.5,
						aLy = 0,
						eL = 0.4,
						fLz = -0.42,
						fRz = 0.2,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.22,
						pz = -0.21,
						pyaw = 0.12,
						syaw = 0.32,
						spitch = 0.33,
						cRf = 0.32,
						aRp = 1.4,
						aRo = 0.15,
						aRy = 0.18,
						eR = 0.1,
						wRp = -0.7,
						bRx = -0.05,
						bRy = 0.0,
						bRz = -0.999,
						aLp = -0.32,
						aLo = 0.5,
						eL = 0.4,
						fLz = -0.42,
						fRz = 0.2,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- Cleave (cone 100 deg, windup 1.0): a wide coil with both hands low on the right, then a sweep across the front
		cleave = {
			strike = 0.16,
			follow = 0.3,
			recover = 0.45,
			legs = true,
			lag = { head = 0.06, free = 0.04 },
			keys = {
				{
					seg = "A",
					u = 0.35,
					ease = "inout",
					pose = g({
						py = -0.16,
						pz = 0.06,
						pyaw = -0.55,
						syaw = -0.45,
						hyaw = 0.5,
						aRp = 0.6,
						aRo = 0.55,
						aRy = -0.65,
						eR = 1.0,
						wRp = 2.0,
						bRx = 0.752,
						bRy = 0.1,
						bRz = 0.652,
						wRr = 0.6,
						aLp = 0.75,
						aLo = 0.1,
						aLy = 1.05,
						eL = 1.15,
						fLz = -0.24,
						fRz = 0.2,
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.24,
						pz = 0.1,
						pyaw = -0.8,
						ppitch = 0.12,
						syaw = -0.85,
						spitch = 0.18,
						sroll = 0.1,
						hyaw = 0.85,
						aRp = 0.55,
						aRo = 0.85,
						aRy = -1.05,
						eR = 0.7,
						wRp = 2.55,
						bRx = 0.6,
						bRy = 0.0,
						bRz = 0.8,
						wRr = 0.75,
						aLp = 0.55,
						aLo = 0.05,
						aLy = 1.15,
						eL = 1.25,
						fLz = -0.26,
						fRz = 0.24,
						fRyaw = -0.8,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.27,
						pz = -0.12,
						pyaw = 0.35,
						ppitch = 0.1,
						syaw = 0.7,
						spitch = 0.25,
						sroll = -0.08,
						hyaw = -0.35,
						cRf = 0.2,
						aRp = 1.0,
						aRo = 0.25,
						aRy = 1.05,
						eR = 0.12,
						wRp = -0.3,
						bRx = -0.301,
						bRy = 0.0,
						bRz = -0.954,
						wRr = -0.25,
						aLp = 0.1,
						aLo = 0.85,
						aLy = -0.2,
						eL = 0.45,
						fLz = -0.36,
						fLyaw = 0.3,
						fRz = 0.18,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.27,
						pz = -0.13,
						pyaw = 0.6,
						syaw = 1.0,
						spitch = 0.27,
						hyaw = -0.5,
						cRf = 0.25,
						aRp = 0.8,
						aRo = 0.15,
						aRy = 1.45,
						eR = 0.25,
						wRp = -0.45,
						bRx = -0.909,
						bRy = -0.101,
						bRz = -0.404,
						aLp = 0.0,
						aLo = 0.95,
						aLy = -0.3,
						eL = 0.4,
						fLz = -0.36,
						fLyaw = 0.4,
						fRz = 0.18,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- Heavy Blow (the Elite's cone, windup 1.8): both hands raise the sword high over the head, the body arches back
		-- and trembles at the top, then chops down into a deep lunge; the blade hangs a moment before the recovery
		heavy = {
			strike = 0.14,
			follow = 0.38,
			recover = 0.5,
			legs = true,
			lag = { head = 0.06, free = 0.03 },
			keys = {
				{
					seg = "A",
					u = 0.55,
					ease = "inout",
					pose = g({
						py = -0.06,
						pz = 0.05,
						pyaw = -0.15,
						syaw = 0.0,
						spitch = -0.15,
						hpitch = -0.15,
						cRu = 0.35,
						cLu = 0.35,
						aRp = 2.55,
						aRo = 0.3,
						aRy = 0.25,
						eR = 1.1,
						wRp = 0.75,
						bRx = 0.05,
						bRy = -0.301,
						bRz = 0.952,
						aLp = 2.45,
						aLo = 0.15,
						aLy = 0.55,
						eL = 1.35,
						fLz = -0.18,
						fRz = 0.18,
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.04,
						pz = 0.08,
						pyaw = -0.12,
						syaw = 0.02,
						spitch = -0.26,
						hpitch = -0.22,
						cRu = 0.42,
						cLu = 0.42,
						aRp = 2.8,
						aRo = 0.32,
						aRy = 0.3,
						eR = 1.3,
						wRp = 0.6,
						bRx = 0.05,
						bRy = -0.552,
						bRz = 0.833,
						aLp = 2.7,
						aLo = 0.18,
						aLy = 0.6,
						eL = 1.5,
						fLz = -0.18,
						fRz = 0.2,
						fLp = 0.05,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.32,
						pz = -0.18,
						pyaw = 0.05,
						ppitch = 0.18,
						syaw = 0.05,
						spitch = 0.6,
						hpitch = 0.15,
						cRu = 0,
						cLu = 0,
						cRf = 0.25,
						cLf = 0.25,
						aRp = 0.55,
						aRo = 0.15,
						aRy = 0.35,
						eR = 0.15,
						wRp = -0.5,
						bRx = 0.0,
						bRy = -0.707,
						bRz = -0.707,
						aLp = 0.5,
						aLo = 0.05,
						aLy = 0.7,
						eL = 0.3,
						fLz = -0.42,
						fRz = 0.22,
					}),
				},
				{
					seg = "F",
					u = 0.6,
					ease = "out",
					pose = g({
						py = -0.34,
						pz = -0.19,
						pyaw = 0.06,
						ppitch = 0.2,
						syaw = 0.05,
						spitch = 0.66,
						hpitch = 0.12,
						cRf = 0.28,
						cLf = 0.28,
						aRp = 0.4,
						aRo = 0.15,
						aRy = 0.35,
						eR = 0.15,
						wRp = -0.65,
						bRx = 0.0,
						bRy = -0.894,
						bRz = -0.447,
						aLp = 0.38,
						aLy = 0.7,
						eL = 0.35,
						fLz = -0.42,
						fRz = 0.22,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = g({
						py = -0.3,
						pz = -0.16,
						ppitch = 0.16,
						spitch = 0.55,
						aRp = 0.45,
						aRy = 0.3,
						eR = 0.25,
						wRp = -0.6,
						bRx = 0.0,
						bRy = -0.8,
						bRz = -0.6,
						aLp = 0.4,
						aLy = 0.65,
						eL = 0.45,
						fLz = -0.4,
						fRz = 0.2,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- Crush (Elite II, windup 2.2, a lethal circle on the target): a long gathering crouch with the sword raised in
		-- both hands, a short hop and a slam of the blade into the ground; the body stays low after it
		crush = {
			strike = 0.22,
			follow = 0.5,
			recover = 0.55,
			legs = true,
			lag = { head = 0.07, free = 0.04 },
			keys = {
				{
					seg = "A",
					u = 0.45,
					ease = "inout",
					pose = g({
						py = -0.28,
						pz = 0.06,
						pyaw = -0.2,
						ppitch = 0.22,
						syaw = 0.0,
						spitch = 0.35,
						hpitch = -0.35,
						aRp = 1.4,
						aRo = 0.2,
						aRy = 0.4,
						eR = 1.6,
						wRp = -0.8,
						bRx = 0.0,
						bRy = 0.995,
						bRz = 0.1,
						aLp = 1.3,
						aLo = 0.1,
						aLy = 0.7,
						eL = 1.6,
						fLz = -0.22,
						fRz = 0.2,
						fLx = -0.06,
						fRx = 0.06,
					}),
				},
				{
					seg = "A",
					u = 0.88,
					ease = "inout",
					pose = g({
						py = -0.34,
						pz = 0.08,
						pyaw = -0.15,
						ppitch = 0.3,
						spitch = 0.2,
						hpitch = -0.5,
						cRu = 0.4,
						cLu = 0.4,
						aRp = 2.75,
						aRo = 0.25,
						aRy = 0.35,
						eR = 1.25,
						wRp = 0.5,
						bRx = 0.05,
						bRy = -0.2,
						bRz = 0.979,
						aLp = 2.65,
						aLo = 0.15,
						aLy = 0.6,
						eL = 1.45,
						fLz = -0.22,
						fRz = 0.2,
						fLx = -0.07,
						fRx = 0.07,
					}),
				},
				{
					seg = "S",
					u = 0.45,
					ease = "out",
					pose = g({
						py = 0.12,
						pz = -0.08,
						pyaw = -0.05,
						ppitch = -0.05,
						spitch = -0.2,
						hpitch = -0.3,
						cRu = 0.45,
						cLu = 0.45,
						aRp = 2.95,
						aRo = 0.2,
						aRy = 0.3,
						eR = 1.35,
						wRp = 0.3,
						bRx = 0.05,
						bRy = -0.447,
						bRz = 0.893,
						aLp = 2.85,
						aLo = 0.12,
						aLy = 0.55,
						eL = 1.55,
						fLz = -0.24,
						fRz = 0.12,
						fLy = 0.14,
						fRy = 0.1,
						fLp = -0.4,
						fRp = -0.4,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.42,
						pz = -0.2,
						ppitch = 0.4,
						syaw = 0.05,
						spitch = 0.7,
						hpitch = 0.1,
						cRf = 0.3,
						cLf = 0.3,
						aRp = 0.45,
						aRo = 0.12,
						aRy = 0.4,
						eR = 0.1,
						wRp = -0.95,
						bRx = 0.0,
						bRy = -0.862,
						bRz = -0.507,
						aLp = 0.42,
						aLy = 0.75,
						eL = 0.2,
						fLz = -0.4,
						fRz = 0.25,
						fLx = -0.08,
						fRx = 0.08,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.38,
						pz = -0.18,
						ppitch = 0.35,
						spitch = 0.6,
						hpitch = -0.15,
						cRf = 0.25,
						cLf = 0.25,
						aRp = 0.5,
						aRy = 0.4,
						eR = 0.2,
						wRp = -1.0,
						bRx = 0.0,
						bRy = -0.914,
						bRz = -0.406,
						aLp = 0.45,
						aLy = 0.7,
						eL = 0.3,
						fLz = -0.4,
						fRz = 0.25,
						fLx = -0.08,
						fRx = 0.08,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- Pounce (Elite II leap at a kiting player, windup 1.4): a deep crouch, the spring, the body flies to the target
		-- in the last part and lands with a downward cut
		pounce = {
			strike = 0.4,
			follow = 0.3,
			recover = 0.4,
			legs = true,
			travel = true,
			lag = { head = 0.05, free = 0.05 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = g({
						py = -0.36,
						pz = 0.1,
						pyaw = -0.2,
						ppitch = 0.35,
						spitch = 0.45,
						hpitch = -0.45,
						aRp = 0.1,
						aRo = 0.55,
						aRy = -0.4,
						eR = 1.2,
						wRp = 2.1,
						bRx = 0.406,
						bRy = -0.304,
						bRz = 0.862,
						aLp = -0.2,
						aLo = 0.45,
						eL = 0.6,
						fLz = -0.18,
						fRz = 0.22,
						fLx = -0.05,
						fRx = 0.05,
					}),
				},
				{
					seg = "S",
					u = 0.55,
					ease = "out",
					pose = from(
						g({
							py = 0.55,
							pz = -0.15,
							ppitch = 0.0,
							spitch = -0.15,
							hpitch = -0.2,
							cRu = 0.4,
							aRp = 2.7,
							aRo = 0.4,
							aRy = 0.2,
							eR = 1.4,
							wRp = 0.3,
							bRx = 0.05,
							bRy = -0.2,
							bRz = 0.979,
							aLp = 1.6,
							aLo = 0.6,
							eL = 0.6,
							fLz = -0.3,
							fRz = 0.15,
							fLy = 0.32,
							fRy = 0.38,
							fLp = -0.5,
							fRp = -0.6,
						}),
						{ travel = 0.65 }
					),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = from(
						g({
							py = -0.32,
							pz = -0.15,
							ppitch = 0.3,
							spitch = 0.55,
							hpitch = 0.05,
							cRf = 0.25,
							aRp = 0.6,
							aRo = 0.15,
							aRy = 0.6,
							eR = 0.15,
							wRp = -0.45,
							bRx = 0.0,
							bRy = -0.707,
							bRz = -0.707,
							aLp = -0.2,
							aLo = 0.7,
							eL = 0.4,
							fLz = -0.32,
							fRz = 0.22,
							fLx = -0.06,
							fRx = 0.06,
						}),
						{ travel = 1 }
					),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = from(
						g({
							py = -0.3,
							pz = -0.12,
							ppitch = 0.26,
							spitch = 0.45,
							aRp = 0.55,
							aRy = 0.7,
							eR = 0.25,
							aLp = -0.1,
							aLo = 0.6,
							fLz = -0.3,
							fRz = 0.22,
						}),
						{ travel = 1 }
					),
				},
				{ seg = "R", u = 1, ease = "inout", pose = from(GUARD, { travel = 1 }) },
			},
		},
		-- Charge (a line, windup 1.0): the body sinks and leans forward with the shoulder in front, the sword held low,
		-- then drives forward in a shoulder rush
		charge = {
			strike = 0.25,
			follow = 0.25,
			recover = 0.4,
			legs = true,
			lag = { head = 0.04, free = 0.05 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = g({
						py = -0.3,
						pz = 0.12,
						pyaw = -0.6,
						ppitch = 0.35,
						syaw = -0.2,
						spitch = 0.45,
						hpitch = -0.5,
						hyaw = 0.5,
						aRp = 0.2,
						aRo = 0.6,
						aRy = -0.5,
						eR = 1.4,
						wRp = -1.1,
						bRx = 0.101,
						bRy = -0.404,
						bRz = -0.909,
						aLp = 0.9,
						aLo = 0.2,
						aLy = 0.9,
						eL = 1.6,
						fLz = -0.3,
						fRz = 0.3,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.28,
						pz = -0.25,
						pyaw = -0.3,
						ppitch = 0.4,
						syaw = -0.1,
						spitch = 0.5,
						hpitch = -0.45,
						hyaw = 0.3,
						aRp = 0.9,
						aRo = 0.5,
						aRy = 0.2,
						eR = 0.6,
						wRp = -0.7,
						bRx = 0.0,
						bRy = -0.1,
						bRz = -0.995,
						aLp = 1.1,
						aLo = 0.1,
						aLy = 1.0,
						eL = 1.8,
						fLz = -0.5,
						fRz = 0.35,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = g({ py = -0.22, pz = -0.2, spitch = 0.35, aRp = 0.9, eR = 0.7 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- the regular thrown blow (Elite II): the free hand reaches back over the shoulder, then hurls forward
		throw = {
			strike = 0.12,
			follow = 0.25,
			recover = 0.35,
			legs = true,
			lag = { head = 0.04, free = 0.0 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = g({
						py = -0.12,
						pz = 0.1,
						pyaw = 0.4,
						syaw = 0.45,
						spitch = -0.05,
						hyaw = -0.4,
						aRp = 0.3,
						aRo = 0.5,
						aRy = 0.3,
						eR = 1.0,
						wRp = -0.2,
						bRx = 0.398,
						bRy = -0.597,
						bRz = -0.697,
						cLu = 0.25,
						aLp = 2.4,
						aLo = 0.55,
						aLy = -0.3,
						eL = 1.75,
						wLp = -0.4,
						fLz = -0.24,
						fRz = 0.2,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.16,
						pz = -0.1,
						pyaw = -0.35,
						syaw = -0.45,
						spitch = 0.3,
						hyaw = 0.3,
						aRp = 0.0,
						aRo = 0.6,
						aRy = -0.3,
						eR = 0.8,
						wRp = 0.3,
						bRx = 0.3,
						bRy = -0.699,
						bRz = -0.649,
						cLf = 0.3,
						aLp = 1.3,
						aLo = 0.05,
						aLy = 0.7,
						eL = 0.2,
						wLp = 0.5,
						fLz = -0.32,
						fRz = 0.2,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.16,
						pz = -0.1,
						pyaw = -0.45,
						syaw = -0.55,
						spitch = 0.35,
						aRp = 0.0,
						aRo = 0.6,
						eR = 0.8,
						aLp = 0.7,
						aLy = 0.9,
						eL = 0.3,
						fLz = -0.32,
						fRz = 0.2,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- the first aggro: the sword points at the target, the chin rises in a shout, then back to the guard
		aggro = {
			strike = 0.15,
			follow = 0.45,
			recover = 0.3,
			legs = false,
			lag = { head = 0.06, free = 0.08 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = g({
						spitch = -0.1,
						hpitch = -0.3,
						cRu = 0.2,
						cLu = 0.25,
						aRp = 1.4,
						aRo = 0.3,
						aRy = 0.1,
						eR = 0.15,
						wRp = -0.7,
						bRx = 0.0,
						bRy = 0.1,
						bRz = -0.995,
						aLp = 0.4,
						aLo = 0.9,
						eL = 1.2,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = g({
						spitch = -0.18,
						hpitch = -0.42,
						cRu = 0.25,
						cLu = 0.3,
						aRp = 1.55,
						aRo = 0.3,
						aRy = 0.1,
						eR = 0.1,
						wRp = -0.8,
						bRx = 0.0,
						bRy = 0.15,
						bRz = -0.989,
						aLp = 0.5,
						aLo = 1.05,
						eL = 1.3,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = g({
						spitch = -0.12,
						hpitch = -0.32,
						aRp = 1.45,
						eR = 0.15,
						wRp = -0.75,
						bRx = 0.0,
						bRy = 0.1,
						bRz = -0.995,
						aLo = 0.95,
						eL = 1.25,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- a breath (fireBreath / frostBreath cone, windup 1.3: the dragonspawn): the chest swells and the head rears back
		-- with the arms opening, then the head thrusts forward and sweeps across the cone while it breathes (the stream
		-- follows the head: Data/MotionFx)
		breath = {
			strike = 0.18,
			follow = 0.9,
			recover = 0.5,
			legs = true,
			lag = { head = 0.05, free = 0.08 },
			keys = {
				{
					seg = "A",
					u = 0.6,
					ease = "inout",
					pose = g({
						pz = 0.05,
						spitch = -0.2,
						hpitch = -0.38,
						cRu = 0.18,
						cLu = 0.18,
						aRo = 0.6,
						eR = 1.2,
						aLp = 0.4,
						aLo = 0.75,
						eL = 0.9,
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = g({
						py = -0.04,
						pz = 0.07,
						spitch = -0.28,
						hpitch = -0.48,
						cRu = 0.24,
						cLu = 0.24,
						aRo = 0.7,
						eR = 1.1,
						aLp = 0.35,
						aLo = 0.85,
						eL = 0.8,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = g({
						py = -0.14,
						pz = -0.06,
						ppitch = 0.18,
						spitch = 0.32,
						hpitch = 0.12,
						syaw = 0.42,
						hyaw = 0.4,
						cRu = 0.0,
						cLu = 0.0,
						aRo = 0.55,
						aLp = 0.5,
						aLo = 0.6,
						eL = 1.1,
						fLz = -0.3,
					}),
				},
				{
					seg = "F",
					u = 0.85,
					ease = "inout",
					pose = g({
						py = -0.14,
						pz = -0.06,
						ppitch = 0.18,
						spitch = 0.32,
						hpitch = 0.12,
						syaw = -0.12,
						hyaw = -0.42,
						aRo = 0.55,
						aLp = 0.5,
						aLo = 0.6,
						eL = 1.1,
						fLz = -0.3,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.12,
						pz = -0.04,
						ppitch = 0.14,
						spitch = 0.24,
						hpitch = 0.05,
						syaw = -0.08,
						hyaw = -0.36,
						fLz = -0.3,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- a summoned or new monster: from a crouch with the head down it straightens and raises the guard
		spawn = {
			strike = 0.3,
			follow = 0.3,
			recover = 0.3,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 0,
					ease = "lin",
					pose = g({
						py = -0.42,
						ppitch = 0.45,
						spitch = 0.6,
						hpitch = 0.4,
						aRp = 0.1,
						aRo = 0.3,
						eR = 0.5,
						wRp = -0.1,
						bRx = 0.202,
						bRy = -0.807,
						bRz = -0.555,
						aLp = 0.3,
						aLo = 0.2,
						eL = 0.6,
						fLz = -0.1,
						fRz = 0.15,
						fLx = -0.06,
						fRx = 0.06,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = g({ py = -0.04, ppitch = 0.0, spitch = -0.05, hpitch = -0.2, aRp = 0.7, eR = 1.2 }),
				},
				{ seg = "F", u = 1, ease = "inout", pose = GUARD },
				{ seg = "R", u = 1, ease = "inout", pose = GUARD },
			},
		},
		-- death backward: the blow throws the head back, the knees buckle, the body falls on its back and settles
		deathBack = {
			strike = 0.18,
			follow = 0.5,
			recover = 0.35,
			legs = true,
			hold = true,
			full = true,
			lag = { head = 0.06, free = 0.08 },
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.08,
						pz = 0.1,
						ppitch = -0.15,
						spitch = -0.4,
						hpitch = -0.5,
						cRu = 0.25,
						cLu = 0.25,
						aRp = 0.6,
						aRo = 0.9,
						eR = 0.6,
						wRp = 0.5,
						aLp = 0.5,
						aLo = 1.0,
						eL = 0.7,
						fLz = -0.15,
						fRz = 0.15,
					}),
				},
				{
					seg = "F",
					u = 0.45,
					ease = "in",
					pose = g({
						py = -0.45,
						pz = 0.3,
						ppitch = -0.55,
						spitch = -0.25,
						hpitch = -0.3,
						aRp = 0.9,
						aRo = 1.1,
						eR = 0.7,
						wRp = 0.4,
						aLp = 0.8,
						aLo = 1.2,
						eL = 0.6,
						fLz = -0.3,
						fRz = -0.1,
						fLp = 0.3,
						fRp = 0.4,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "in",
					pose = {
						py = -0.83,
						pz = 0.55,
						ppitch = -1.45,
						proll = 0.08,
						spitch = 0.12,
						sroll = -0.06,
						hpitch = 0.35,
						hyaw = 0.6,
						aRp = 1.0,
						aRo = 1.45,
						aRy = -0.2,
						eR = 0.35,
						wRp = 0.2,
						aLp = 0.6,
						aLo = 1.35,
						eL = 0.6,
						fLz = -0.55,
						fRz = -0.45,
						fLx = -0.08,
						fRx = 0.1,
						fLy = -0.02,
						fRy = -0.02,
						fLp = 1.2,
						fRp = 1.1,
						fLyaw = -0.5,
						fRyaw = 0.4,
					},
				},
				{
					seg = "R",
					u = 0.4,
					ease = "out",
					pose = {
						py = -0.8,
						pz = 0.56,
						ppitch = -1.38,
						proll = 0.08,
						spitch = 0.18,
						hpitch = 0.4,
						hyaw = 0.65,
						aRp = 1.05,
						aRo = 1.4,
						aRy = -0.2,
						eR = 0.4,
						aLp = 0.65,
						aLo = 1.3,
						eL = 0.65,
						fLz = -0.55,
						fRz = -0.45,
						fLx = -0.08,
						fRx = 0.1,
						fLp = 1.2,
						fRp = 1.1,
						fLyaw = -0.5,
						fRyaw = 0.4,
					},
				},
				{
					seg = "R",
					u = 1,
					ease = "inout",
					pose = {
						py = -0.84,
						pz = 0.56,
						ppitch = -1.48,
						proll = 0.1,
						spitch = 0.1,
						hpitch = 0.45,
						hyaw = 0.7,
						aRp = 1.0,
						aRo = 1.5,
						aRy = -0.2,
						eR = 0.3,
						aLp = 0.6,
						aLo = 1.4,
						eL = 0.55,
						fLz = -0.56,
						fRz = -0.46,
						fLx = -0.08,
						fRx = 0.1,
						fLy = -0.02,
						fRy = -0.02,
						fLp = 1.25,
						fRp = 1.15,
						fLyaw = -0.55,
						fRyaw = 0.45,
					},
				},
			},
		},
		-- death forward: the body folds over the wound, drops to the knees, then falls on its face
		deathFwd = {
			strike = 0.2,
			follow = 0.65,
			recover = 0.35,
			legs = true,
			hold = true,
			full = true,
			lag = { head = 0.07, free = 0.08 },
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = g({
						py = -0.18,
						pz = 0.05,
						ppitch = 0.25,
						spitch = 0.6,
						hpitch = 0.3,
						aRp = 0.4,
						aRo = 0.2,
						aRy = 0.6,
						eR = 1.3,
						wRp = -1.9,
						aLp = 0.5,
						aLo = 0.1,
						aLy = 0.8,
						eL = 1.6,
						fLz = -0.15,
						fRz = 0.12,
					}),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "in",
					pose = {
						py = -0.5,
						pz = 0.05,
						ppitch = 0.15,
						spitch = 0.55,
						hpitch = 0.35,
						aRp = 0.2,
						aRo = 0.3,
						aRy = 0.2,
						eR = 0.6,
						wRp = 0.3,
						aLp = 0.2,
						aLo = 0.3,
						eL = 0.6,
						fLz = 0.25,
						fRz = 0.3,
						fLy = 0.0,
						fRy = 0.0,
						fLp = 0.0,
						fRp = 0.0,
					},
				},
				{
					seg = "F",
					u = 1,
					ease = "in",
					pose = {
						py = -0.84,
						pz = -0.4,
						ppitch = 1.45,
						proll = -0.1,
						spitch = 0.1,
						sroll = 0.05,
						hpitch = -0.2,
						hyaw = -0.8,
						aRp = 2.0,
						aRo = 0.9,
						aRy = 0.2,
						eR = 0.6,
						wRp = 0.3,
						aLp = 1.4,
						aLo = 0.4,
						aLy = 0.3,
						eL = 1.4,
						fLz = 0.55,
						fRz = 0.62,
						fLx = -0.05,
						fRx = 0.08,
						fLy = 0.02,
						fRy = 0.02,
						fLp = -1.3,
						fRp = -1.4,
					},
				},
				{
					seg = "R",
					u = 1,
					ease = "out",
					pose = {
						py = -0.86,
						pz = -0.41,
						ppitch = 1.5,
						proll = -0.1,
						spitch = 0.05,
						hpitch = -0.25,
						hyaw = -0.85,
						aRp = 2.05,
						aRo = 0.95,
						aRy = 0.2,
						eR = 0.55,
						aLp = 1.45,
						aLo = 0.45,
						aLy = 0.3,
						eL = 1.35,
						fLz = 0.56,
						fRz = 0.63,
						fLx = -0.05,
						fRx = 0.08,
						fLy = 0.02,
						fRy = 0.02,
						fLp = -1.35,
						fRp = -1.45,
					},
				},
			},
		},
	},
}

---------------------------------------------------------------- variants of the humanoid template (owner 2026-10-26)

-- A style made from another: the same clips, reactions and abilities, its own stance, blows and the rest given.
local function variant(base: Style, over: { [string]: any }): Style
	local out = table.clone(base) :: any
	out.actions = table.clone(base.actions)
	for key, value in over do
		if key == "actions" then
			for name, action in value do
				out.actions[name] = action
			end
		else
			out[key] = value
		end
	end
	return out :: Style
end

-- Caster (a staff or a wand in the right hand, the free hand casting): the regular blow is a bolt cast from the staff
-- head, the abilities a nova slammed into the ground or a pool called onto the target.
local CASTER_GUARD = {
	py = -0.06,
	pyaw = -0.15,
	syaw = 0.1,
	spitch = 0.08,
	hpitch = -0.06,
	aRp = 0.45,
	aRo = 0.28,
	aRy = 0.15,
	eR = 1.25,
	bRx = 0.0,
	bRy = 1,
	bRz = -0.15,
	aLp = 0.55,
	aLo = 0.4,
	aLy = 0.35,
	eL = 1.1,
	wLp = 0.3,
	fLz = -0.12,
	fRz = 0.1,
	fRyaw = -0.3,
}
local function cg(over: { [string]: number }): { [string]: number }
	return from(CASTER_GUARD, over)
end

local CASTER: Style = variant(HUMANOID_1H, {
	grip = { 0, 1, 0 },
	guard = CASTER_GUARD,
	basic = { "spell", "spellLeft" },
	abilities = {
		boneNova = "nova",
		frostNova = "nova",
		emberNova = "nova",
		voidPool = "pool",
		poisonPool = "pool",
		heavyBlow = "nova",
		crush = "pool",
		pounce = "pounce",
		slam = "nova",
		cleave = "nova",
		leap = "pounce",
		charge = "charge",
	},
	actions = {
		-- the bolt: the staff draws back and up while the free hand gathers the spell, then both thrust at the target
		spell = {
			strike = 0.12,
			follow = 0.25,
			recover = 0.35,
			legs = true,
			lag = { head = 0.05, free = 0.05 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = cg({
						pz = 0.06,
						pyaw = -0.35,
						syaw = -0.3,
						spitch = -0.08,
						hpitch = -0.12,
						aRp = 1.5,
						aRo = 0.55,
						aRy = -0.2,
						eR = 1.4,
						bRx = 0.2,
						bRy = 0.9,
						bRz = 0.4,
						aLp = 0.9,
						aLo = 0.55,
						aLy = 0.6,
						eL = 1.6,
						wLp = -0.4,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = cg({
						py = -0.1,
						pz = -0.08,
						pyaw = 0.05,
						syaw = 0.25,
						spitch = 0.2,
						aRp = 1.35,
						aRo = 0.2,
						aRy = 0.25,
						eR = 0.25,
						bRx = 0,
						bRy = 0.35,
						bRz = -0.95,
						aLp = 1.4,
						aLo = 0.15,
						aLy = 0.25,
						eL = 0.1,
						wLp = 0.5,
						fLz = -0.24,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = cg({
						py = -0.1,
						pz = -0.08,
						syaw = 0.28,
						spitch = 0.22,
						aRp = 1.3,
						aRo = 0.2,
						aRy = 0.3,
						eR = 0.3,
						bRx = 0,
						bRy = 0.3,
						bRz = -0.95,
						aLp = 1.3,
						aLo = 0.2,
						eL = 0.2,
						fLz = -0.24,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = CASTER_GUARD },
			},
		},
		-- the same bolt thrown from the free hand, the staff held back
		spellLeft = {
			strike = 0.12,
			follow = 0.25,
			recover = 0.35,
			legs = true,
			lag = { head = 0.05 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = cg({
						pz = 0.05,
						pyaw = 0.25,
						syaw = 0.35,
						hyaw = -0.2,
						aLp = 0.5,
						aLo = 0.9,
						aLy = -0.4,
						eL = 1.7,
						wLp = -0.6,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = cg({
						py = -0.1,
						pz = -0.08,
						pyaw = -0.2,
						syaw = -0.3,
						spitch = 0.2,
						hyaw = 0.15,
						aLp = 1.45,
						aLo = 0.1,
						aLy = 0.4,
						eL = 0.05,
						wLp = 0.6,
						fLz = -0.24,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = cg({
						py = -0.1,
						pz = -0.08,
						syaw = -0.32,
						spitch = 0.22,
						aLp = 1.4,
						aLy = 0.4,
						eL = 0.1,
						fLz = -0.24,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = CASTER_GUARD },
			},
		},
		-- a nova (a circle around the caster): the staff rises in both hands over the head, the body arches, then the
		-- staff butt slams the ground in a crouch
		nova = {
			strike = 0.16,
			follow = 0.45,
			recover = 0.45,
			legs = true,
			lag = { head = 0.06, free = 0.04 },
			keys = {
				{
					seg = "A",
					u = 0.5,
					ease = "inout",
					pose = cg({
						py = -0.02,
						spitch = -0.2,
						hpitch = -0.3,
						cRu = 0.35,
						cLu = 0.35,
						aRp = 2.6,
						aRo = 0.3,
						eR = 0.6,
						bRx = 0,
						bRy = 1,
						bRz = 0.1,
						aLp = 2.5,
						aLo = 0.4,
						aLy = 0.3,
						eL = 0.5,
						fLz = -0.14,
						fRz = 0.14,
						fLx = -0.05,
						fRx = 0.05,
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = cg({
						py = 0.0,
						spitch = -0.28,
						hpitch = -0.38,
						cRu = 0.42,
						cLu = 0.42,
						aRp = 2.8,
						aRo = 0.3,
						eR = 0.4,
						bRx = 0,
						bRy = 1,
						bRz = 0.15,
						aLp = 2.7,
						aLo = 0.45,
						aLy = 0.3,
						eL = 0.35,
						fLz = -0.14,
						fRz = 0.14,
						fLx = -0.05,
						fRx = 0.05,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = cg({
						py = -0.32,
						pz = -0.05,
						ppitch = 0.2,
						spitch = 0.5,
						hpitch = 0.1,
						aRp = 0.9,
						aRo = 0.2,
						aRy = 0.3,
						eR = 0.5,
						bRx = 0,
						bRy = -1,
						bRz = -0.1,
						aLp = 0.8,
						aLo = 0.3,
						aLy = 0.4,
						eL = 0.6,
						fLz = -0.2,
						fRz = 0.16,
						fLx = -0.08,
						fRx = 0.08,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = cg({
						py = -0.3,
						ppitch = 0.18,
						spitch = 0.45,
						aRp = 0.9,
						aRy = 0.3,
						eR = 0.55,
						bRx = 0,
						bRy = -1,
						bRz = -0.1,
						aLp = 0.5,
						aLo = 0.7,
						eL = 0.5,
						fLz = -0.2,
						fRz = 0.16,
						fLx = -0.08,
						fRx = 0.08,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = CASTER_GUARD },
			},
		},
		-- a pool on the target: the staff swings high and back, then points down at the target while the free hand claws
		pool = {
			strike = 0.16,
			follow = 0.4,
			recover = 0.4,
			legs = true,
			lag = { head = 0.05, free = 0.06 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = cg({
						pz = 0.05,
						spitch = -0.15,
						hpitch = -0.2,
						cRu = 0.3,
						aRp = 2.7,
						aRo = 0.35,
						aRy = -0.1,
						eR = 0.5,
						bRx = 0.1,
						bRy = 0.8,
						bRz = 0.55,
						aLp = 1.0,
						aLo = 0.9,
						eL = 1.2,
						wLp = -0.5,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = cg({
						py = -0.12,
						pz = -0.1,
						spitch = 0.3,
						hpitch = 0.12,
						aRp = 1.45,
						aRo = 0.2,
						aRy = 0.15,
						eR = 0.15,
						bRx = 0,
						bRy = -0.45,
						bRz = -0.9,
						aLp = 1.2,
						aLo = 0.6,
						aLy = 0.3,
						eL = 0.4,
						wLp = 0.6,
						fLz = -0.25,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = cg({
						py = -0.12,
						pz = -0.1,
						spitch = 0.32,
						hpitch = 0.12,
						aRp = 1.4,
						aRy = 0.15,
						eR = 0.2,
						bRx = 0,
						bRy = -0.5,
						bRz = -0.87,
						aLp = 1.1,
						aLo = 0.7,
						eL = 0.5,
						fLz = -0.25,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = CASTER_GUARD },
			},
		},
	},
})

-- Brute (unarmed: claws and fists; beasts, golems, trolls): a hunched wide stance with the arms ready, the regular blow a
-- right and a left swipe in turn, the abilities the humanoid's heavy moves done with bare hands.
local BRUTE_GUARD = {
	py = -0.16,
	pz = 0.03,
	ppitch = 0.12,
	spitch = 0.3,
	hpitch = -0.28,
	cRu = 0.12,
	cLu = 0.12,
	aRp = 0.55,
	aRo = 0.55,
	aRy = 0.1,
	eR = 1.0,
	aLp = 0.55,
	aLo = 0.55,
	aLy = 0.1,
	eL = 1.0,
	fLz = -0.12,
	fRz = 0.1,
	fLx = -0.1,
	fRx = 0.1,
	fRyaw = -0.25,
	fLyaw = 0.15,
}
local function bg(over: { [string]: number }): { [string]: number }
	return from(BRUTE_GUARD, over)
end
-- The swiping arm's controls written for the right side, laid on side `m` (-1: the left arm, the body turns mirrored).
local function onSide(r: { [string]: number }, m: number): { [string]: number }
	local out: { [string]: number } = {}
	for key, v in r do
		local k = key
		if m < 0 then
			local first, second = string.sub(key, 1, 1), string.sub(key, 2, 2)
			if (first == "a" or first == "e" or first == "w" or first == "c") and second == "R" then
				k = first .. "L" .. string.sub(key, 3)
			elseif key == "syaw" or key == "pyaw" or key == "hyaw" or key == "sroll" then
				v = -v
			end
		end
		out[k] = v
	end
	return out
end
local function swipe(m: number): Action
	return {
		strike = 0.12,
		follow = 0.2,
		recover = 0.32,
		legs = true,
		lag = { head = 0.05, free = 0.07 },
		keys = {
			{
				seg = "A",
				u = 1,
				ease = "inout",
				pose = bg(onSide({
					pz = 0.08,
					pyaw = -0.35,
					syaw = -0.55,
					spitch = 0.2,
					hyaw = 0.45,
					cRu = 0.3,
					aRp = 1.9,
					aRo = 0.95,
					aRy = -0.45,
					eR = 1.3,
				}, m)),
			},
			{
				seg = "S",
				u = 1,
				ease = "in",
				pose = bg(onSide({
					py = -0.22,
					pz = -0.14,
					pyaw = 0.2,
					syaw = 0.55,
					spitch = 0.42,
					hyaw = -0.3,
					cRf = 0.25,
					aRp = 0.95,
					aRo = 0.15,
					aRy = 1.1,
					eR = 0.35,
					fLz = -0.32,
				}, m)),
			},
			{
				seg = "F",
				u = 1,
				ease = "out",
				pose = bg(onSide({
					py = -0.22,
					pz = -0.15,
					pyaw = 0.28,
					syaw = 0.7,
					spitch = 0.45,
					hyaw = -0.35,
					aRp = 0.7,
					aRo = 0.2,
					aRy = 1.35,
					eR = 0.45,
					fLz = -0.32,
				}, m)),
			},
			{ seg = "R", u = 1, ease = "inout", pose = BRUTE_GUARD },
		},
	}
end

local BRUTE: Style = variant(HUMANOID_1H, {
	guard = BRUTE_GUARD,
	basic = { "clawR", "clawL" },
	actions = { clawR = swipe(1), clawL = swipe(-1) },
	abilities = {
		cleave = "cleave",
		heavyBlow = "heavy",
		crush = "crush",
		pounce = "pounce",
		slam = "crush",
		leap = "pounce",
		charge = "charge",
		boneNova = "crush",
		emberNova = "crush",
		frostNova = "crush",
		fireBreath = "heavy",
		frostBreath = "heavy",
	},
})
BRUTE.grip = nil

-- Ghost (a floating caster: wraiths): the caster without steps, drifting.
local GHOST: Style = variant(CASTER, { float = true })
GHOST.grip = nil

---------------------------------------------------------------- wyvern (owner 2026-10-26: Vaelgrath, the wyvern)

-- A winged dragon on its hind legs, the wings its arms (Vaelgrath: Tripo biped rig, the wing fingers on the hands): a
-- heavy procedural walk (Logic/BipedMotion.procedural), the wings folded at the sides, spread for the roar, the breath,
-- the buffet and in the air. Wing controls are the arm's: out (a?o) spreads, pitch (a?p) raises forward, yaw (a?y)
-- sweeps back (-) and forward (+), the elbow (e?) folds the wing's forearm.
local WING_FOLD = { aRp = -0.15, aRo = 0.3, aRy = -0.35, eR = 1.9, aLp = -0.15, aLo = 0.3, aLy = -0.35, eL = 1.9 }
local function wings(over: { [string]: number }): { [string]: number }
	return from(WING_FOLD, over)
end
local function spread(o: number, p: number, y: number, e: number): { [string]: number }
	return { aRo = o, aLo = o, aRp = p, aLp = p, aRy = y, aLy = y, eR = e, eL = e }
end
local WYVERN_REST = from(WING_FOLD, { ppitch = 0.5, spitch = 0.3, hpitch = -0.5, fLx = -0.06, fRx = 0.06 })
local WYVERN_GUARD = from(WYVERN_REST, {
	py = -0.12,
	ppitch = 0.62,
	spitch = 0.36,
	hpitch = -0.62,
	aRo = 0.75,
	aLo = 0.75,
	aRp = 0.15,
	aLp = 0.15,
	eR = 1.2,
	eL = 1.2,
	fLz = -0.15,
	fRz = 0.12,
	fLx = -0.1,
	fRx = 0.1,
})
local function wg(over: { [string]: number }): { [string]: number }
	return from(WYVERN_GUARD, over)
end
local function merge2(a: { [string]: number }, b: { [string]: number }): { [string]: number }
	local out = table.clone(a)
	for k, v in b do
		out[k] = v
	end
	return out
end

local WYVERN: Style = {
	guard = WYVERN_GUARD,
	procedural = {
		rest = WYVERN_REST,
		runAt = 2.2,
		walk = { k = 1.5, duty = 0.62, lift = 0.16, bob = 0.035, sway = 0.07, yaw = 0.12, lean = 0.05 },
		run = { k = 2.4, duty = 0.42, lift = 0.28, bob = 0.06, sway = 0.05, yaw = 0.08, lean = 0.22 },
		flap = { rate = 0.9, out = 1.25, amp = 0.75, pitch = 0.3, lean = 0.7 },
	},
	idleEvery = { 6, 10 },
	rate = 0.04,
	basic = { "bite", "claw", "bite", "clawL" },
	abilities = {
		frostBreath = "breath",
		fireBreath = "breath",
		wingBuffet = "buffet",
		tailSwipe = "tail",
		blizzard = "roar",
		glacialRing = "stomp",
		avalanche = "stomp",
		iceComet = "roar",
		frostTomb = "roar",
		absoluteZero = "roar",
		cleave = "claw",
		slam = "stomp",
		leap = "stomp",
		pounce = "stomp",
		crush = "stomp",
		heavyBlow = "claw",
		charge = "buffet",
	},
	death = { "deathDragon" },
	aggro = "roar",
	spawn = "spawnDragon",
	flinch = {
		front = { spitch = -0.18, hpitch = -0.2, pz = 0.03, aRo = 0.2, aLo = 0.2 },
		back = { spitch = 0.18, hpitch = 0.15, pz = -0.03 },
		left = { sroll = -0.15, hroll = -0.15, syaw = 0.1, px = 0.03 },
		right = { sroll = 0.15, hroll = 0.15, syaw = -0.1, px = -0.03 },
	},
	actions = {
		-- the bite: the neck coils back with the weight, then the head strikes forward and down, a shake after
		bite = {
			strike = 0.16,
			follow = 0.25,
			recover = 0.45,
			legs = true,
			lag = { head = 0.06, free = 0.08 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = wg({
						pz = 0.12,
						py = -0.08,
						ppitch = 0.1,
						spitch = -0.15,
						hpitch = -0.45,
						hyaw = 0.1,
						aRo = 0.95,
						aLo = 0.95,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = wg({
						pz = -0.18,
						py = -0.18,
						ppitch = 0.42,
						spitch = 0.5,
						hpitch = 0.35,
						aRo = 0.85,
						aLo = 0.85,
						fLz = -0.3,
					}),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = wg({
						pz = -0.17,
						py = -0.17,
						ppitch = 0.4,
						spitch = 0.45,
						hpitch = 0.3,
						hyaw = 0.3,
						hroll = 0.2,
						fLz = -0.3,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = wg({
						pz = -0.16,
						py = -0.16,
						ppitch = 0.38,
						spitch = 0.42,
						hpitch = 0.28,
						hyaw = -0.25,
						hroll = -0.15,
						fLz = -0.3,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = WYVERN_GUARD },
			},
		},
		-- the claw: the right wing's wrist rises high and back, then rakes down and across with the body
		claw = {
			strike = 0.14,
			follow = 0.25,
			recover = 0.45,
			legs = true,
			lag = { head = 0.06, free = 0.08 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = wg({
						pyaw = -0.3,
						syaw = -0.35,
						spitch = 0.0,
						hyaw = 0.3,
						aRp = 1.6,
						aRo = 1.1,
						aRy = -0.5,
						eR = 1.0,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = wg({
						py = -0.2,
						pz = -0.12,
						pyaw = 0.25,
						syaw = 0.45,
						spitch = 0.45,
						hyaw = -0.2,
						aRp = 0.6,
						aRo = 0.5,
						aRy = 0.9,
						eR = 0.6,
						fLz = -0.3,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = wg({
						py = -0.2,
						pz = -0.12,
						pyaw = 0.32,
						syaw = 0.55,
						spitch = 0.45,
						aRp = 0.4,
						aRo = 0.5,
						aRy = 1.1,
						eR = 0.8,
						fLz = -0.3,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = WYVERN_GUARD },
			},
		},
		-- the frost breath (a cone in front): the dragon rears with the wings spread and the chest swelling, then thrusts
		-- the neck forward and sweeps the head across the cone while it breathes
		breath = {
			strike = 0.2,
			follow = 1.2,
			recover = 0.55,
			legs = true,
			lag = { head = 0.05 },
			keys = {
				{
					seg = "A",
					u = 0.6,
					ease = "inout",
					pose = merge2(
						wg({ py = 0.0, pz = 0.08, ppitch = 0.0, spitch = -0.3, hpitch = -0.55, cRu = 0.2, cLu = 0.2 }),
						spread(1.5, 0.55, -0.35, 0.35)
					),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = merge2(
						wg({
							py = 0.02,
							pz = 0.1,
							ppitch = -0.05,
							spitch = -0.38,
							hpitch = -0.6,
							cRu = 0.25,
							cLu = 0.25,
						}),
						spread(1.6, 0.6, -0.4, 0.3)
					),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = merge2(
						wg({
							py = -0.15,
							pz = -0.12,
							ppitch = 0.35,
							spitch = 0.35,
							hpitch = 0.15,
							hyaw = 0.45,
							syaw = 0.2,
							fLz = -0.3,
						}),
						spread(1.3, 0.2, -0.2, 0.5)
					),
				},
				{
					seg = "F",
					u = 0.85,
					ease = "inout",
					pose = merge2(
						wg({
							py = -0.15,
							pz = -0.12,
							ppitch = 0.35,
							spitch = 0.35,
							hpitch = 0.15,
							hyaw = -0.45,
							syaw = -0.2,
							fLz = -0.3,
						}),
						spread(1.3, 0.2, -0.2, 0.5)
					),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = merge2(
						wg({
							py = -0.12,
							pz = -0.1,
							ppitch = 0.3,
							spitch = 0.25,
							hpitch = 0.05,
							hyaw = -0.4,
							fLz = -0.3,
						}),
						spread(1.1, 0.15, -0.2, 0.7)
					),
				},
				{ seg = "R", u = 1, ease = "inout", pose = WYVERN_GUARD },
			},
		},
		-- the wing buffet: the wings open wide and back, then beat forward hard (the wind), a second smaller beat
		buffet = {
			strike = 0.16,
			follow = 0.45,
			recover = 0.5,
			legs = true,
			lag = { head = 0.05 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = merge2(
						wg({ py = 0.02, pz = 0.08, ppitch = 0.05, spitch = -0.25, hpitch = -0.35 }),
						spread(1.6, 0.75, -0.75, 0.25)
					),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = merge2(
						wg({ py = -0.1, pz = -0.05, ppitch = 0.3, spitch = 0.3, hpitch = -0.05 }),
						spread(1.05, 0.55, 0.9, 0.6)
					),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "out",
					pose = merge2(wg({ py = -0.05, ppitch = 0.15, spitch = 0.05 }), spread(1.5, 0.6, -0.5, 0.3)),
				},
				{
					seg = "F",
					u = 1,
					ease = "in",
					pose = merge2(wg({ py = -0.1, ppitch = 0.28, spitch = 0.25 }), spread(1.15, 0.5, 0.6, 0.6)),
				},
				{ seg = "R", u = 1, ease = "inout", pose = WYVERN_GUARD },
			},
		},
		-- the tail swipe: the body winds up, then whips round so the tail sweeps the side behind it
		tail = {
			strike = 0.18,
			follow = 0.3,
			recover = 0.5,
			legs = true,
			lag = { head = 0.08, free = 0.08 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = wg({ pyaw = 0.55, syaw = 0.35, hyaw = -0.5, py = -0.15, aRo = 1.0, aLo = 0.5 }),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = wg({
						pyaw = -0.9,
						syaw = -0.55,
						hyaw = 0.7,
						py = -0.18,
						ppitch = 0.35,
						aRo = 0.5,
						aLo = 1.2,
						fLz = -0.25,
						fRz = 0.2,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = wg({
						pyaw = -1.05,
						syaw = -0.6,
						hyaw = 0.75,
						py = -0.16,
						aRo = 0.55,
						aLo = 1.1,
						fLz = -0.25,
						fRz = 0.2,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = WYVERN_GUARD },
			},
		},
		-- the stomp (glacialRing, avalanche: a ring round it): it rears up with the wings high, then crashes down
		stomp = {
			strike = 0.16,
			follow = 0.4,
			recover = 0.55,
			legs = true,
			lag = { head = 0.07 },
			keys = {
				{
					seg = "A",
					u = 0.55,
					ease = "inout",
					pose = merge2(
						wg({
							py = 0.08,
							pz = 0.12,
							ppitch = -0.25,
							spitch = -0.3,
							hpitch = -0.4,
							fLz = 0.02,
							fRz = 0.02,
						}),
						spread(1.6, 1.0, -0.3, 0.3)
					),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = merge2(
						wg({
							py = 0.12,
							pz = 0.14,
							ppitch = -0.35,
							spitch = -0.38,
							hpitch = -0.45,
							fLz = 0.02,
							fRz = 0.02,
						}),
						spread(1.7, 1.15, -0.35, 0.25)
					),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = merge2(
						wg({
							py = -0.32,
							pz = -0.08,
							ppitch = 0.45,
							spitch = 0.45,
							hpitch = 0.1,
							fLz = -0.25,
							fRz = 0.2,
							fLx = -0.15,
							fRx = 0.15,
						}),
						spread(1.0, 0.1, 0.2, 0.8)
					),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = merge2(
						wg({
							py = -0.28,
							pz = -0.06,
							ppitch = 0.4,
							spitch = 0.38,
							hpitch = 0.0,
							fLz = -0.25,
							fRz = 0.2,
							fLx = -0.15,
							fRx = 0.15,
						}),
						spread(1.05, 0.15, 0.1, 0.9)
					),
				},
				{ seg = "R", u = 1, ease = "inout", pose = WYVERN_GUARD },
			},
		},
		-- the roar (the first aggro, the spells: blizzard, iceComet, frostTomb, absoluteZero): rearing back with the wings
		-- spread high and the head up, then the roar thrust forward, held
		roar = {
			strike = 0.2,
			follow = 0.7,
			recover = 0.5,
			legs = true,
			lag = { head = 0.07 },
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = merge2(
						wg({ py = 0.05, pz = 0.1, ppitch = -0.1, spitch = -0.4, hpitch = -0.7, cRu = 0.3, cLu = 0.3 }),
						spread(1.7, 0.9, -0.45, 0.3)
					),
				},
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = merge2(
						wg({ py = -0.05, pz = -0.05, ppitch = 0.22, spitch = 0.15, hpitch = -0.3, cRu = 0.1, cLu = 0.1 }),
						spread(1.75, 0.7, -0.25, 0.35)
					),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = merge2(
						wg({ py = -0.06, pz = -0.06, ppitch = 0.24, spitch = 0.18, hpitch = -0.25, hyaw = 0.12 }),
						spread(1.72, 0.65, -0.25, 0.35)
					),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = merge2(
						wg({ py = -0.06, pz = -0.06, ppitch = 0.24, spitch = 0.18, hpitch = -0.25, hyaw = -0.12 }),
						spread(1.65, 0.6, -0.25, 0.4)
					),
				},
				{ seg = "R", u = 1, ease = "inout", pose = WYVERN_GUARD },
			},
		},
		-- a summoned or new dragon: from a low crouch wrapped in its wings it rises and opens them
		spawnDragon = {
			strike = 0.4,
			follow = 0.4,
			recover = 0.3,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 0,
					ease = "lin",
					pose = wings({
						py = -0.4,
						ppitch = 0.5,
						spitch = 0.5,
						hpitch = 0.4,
						fLx = -0.1,
						fRx = 0.1,
						aRp = 0.5,
						aLp = 0.5,
						aRy = 0.6,
						aLy = 0.6,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = merge2(
						wg({ py = 0.0, ppitch = 0.0, spitch = -0.2, hpitch = -0.4 }),
						spread(1.6, 0.6, -0.3, 0.3)
					),
				},
				{ seg = "F", u = 1, ease = "inout", pose = WYVERN_GUARD },
				{ seg = "R", u = 1, ease = "inout", pose = WYVERN_GUARD },
			},
		},
		-- the death: a last rear with the wings flaring, the legs buckle, it crashes onto its side, one wing spread on the
		-- ground, the head falling last
		deathDragon = {
			strike = 0.25,
			follow = 0.9,
			recover = 0.5,
			legs = true,
			hold = true,
			full = true,
			lag = { head = 0.12, free = 0.1 },
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = merge2(
						wg({ py = 0.05, pz = 0.1, ppitch = -0.2, spitch = -0.4, hpitch = -0.6 }),
						spread(1.6, 0.8, -0.3, 0.4)
					),
				},
				{
					seg = "F",
					u = 0.4,
					ease = "in",
					pose = merge2(
						wg({
							py = -0.45,
							pz = 0.05,
							ppitch = 0.35,
							spitch = 0.3,
							hpitch = 0.2,
							fLz = -0.1,
							fRz = 0.15,
							fLp = 0.3,
							fRp = 0.3,
						}),
						spread(1.2, 0.3, 0.0, 0.8)
					),
				},
				{
					seg = "F",
					u = 1,
					ease = "in",
					pose = {
						py = -0.68,
						px = -0.35,
						proll = 1.25,
						ppitch = 0.2,
						spitch = 0.1,
						sroll = 0.15,
						hpitch = 0.4,
						hroll = 0.3,
						aRo = 2.45,
						aRp = 0.55,
						aRy = 0.1,
						eR = 0.95,
						aLo = 0.4,
						aLp = 1.0,
						aLy = 0.5,
						eL = 1.6,
						fLz = -0.3,
						fRz = 0.1,
						fLx = -0.2,
						fRx = 0.1,
						fLy = 0.05,
						fRy = 0.2,
						fLp = 0.6,
						fRp = 0.8,
					},
				},
				{
					seg = "R",
					u = 0.4,
					ease = "out",
					pose = {
						py = -0.64,
						px = -0.35,
						proll = 1.2,
						ppitch = 0.2,
						spitch = 0.12,
						sroll = 0.15,
						hpitch = 0.45,
						hroll = 0.3,
						aRo = 2.45,
						aRp = 0.55,
						aRy = 0.1,
						eR = 0.95,
						aLo = 0.45,
						aLp = 1.0,
						aLy = 0.5,
						eL = 1.6,
						fLz = -0.3,
						fRz = 0.1,
						fLx = -0.2,
						fRx = 0.1,
						fLy = 0.05,
						fRy = 0.2,
						fLp = 0.6,
						fRp = 0.8,
					},
				},
				{
					seg = "R",
					u = 1,
					ease = "inout",
					pose = {
						py = -0.69,
						px = -0.35,
						proll = 1.27,
						ppitch = 0.2,
						spitch = 0.1,
						sroll = 0.15,
						hpitch = 0.5,
						hroll = 0.35,
						aRo = 2.45,
						aRp = 0.55,
						aRy = 0.1,
						eR = 0.95,
						aLo = 0.4,
						aLp = 1.0,
						aLy = 0.5,
						eL = 1.65,
						fLz = -0.3,
						fRz = 0.1,
						fLx = -0.2,
						fRx = 0.1,
						fLy = 0.05,
						fRy = 0.2,
						fLp = 0.6,
						fRp = 0.8,
					},
				},
			},
		},
	},
}
WYVERN.actions.clawL = (function(): Action
	-- the claw of the left wing: the right one mirrored
	local right = WYVERN.actions.claw
	local keys = {}
	for _, key in right.keys do
		local pose = table.clone(key.pose)
		local swapped: { [string]: number } = {}
		for k, v in pose do
			local first, second = string.sub(k, 1, 1), string.sub(k, 2, 2)
			if (first == "a" or first == "e" or first == "w" or first == "c") and (second == "R" or second == "L") then
				swapped[first .. (if second == "R" then "L" else "R") .. string.sub(k, 3)] = v
			elseif
				k == "pyaw"
				or k == "syaw"
				or k == "hyaw"
				or k == "sroll"
				or k == "hroll"
				or k == "proll"
				or k == "px"
			then
				swapped[k] = -v
			else
				swapped[k] = v
			end
		end
		table.insert(keys, { seg = key.seg, u = key.u, ease = key.ease, pose = swapped })
	end
	return {
		strike = right.strike,
		follow = right.follow,
		recover = right.recover,
		legs = true,
		lag = right.lag,
		keys = keys,
	}
end)()
WYVERN.actions.heavy = WYVERN.actions.roar

---------------------------------------------------------------- spirits on their bones (owner 2026-10-26)

-- The specter (Mixamo rig) and the ice elemental (Tripo biped, only its body and arms usable: Data/BipedRigs): floating
-- casters without mocap. Logic/SpiritMotion floats them (bob, sway, the lean into the drift with lag, the specter's
-- trailing robe and flicker); these keys pose the arms and the body: the bolt thrown from both hands at W, the
-- specter's wail (rise, arms wide, the head thrown back, thrust at W, the scream held), the burst (heavyBlow, the
-- elemental's frostNova: compressed and shivering, then flung open at W), the pool on the target, a swoop for the
-- pounce, the deaths (the specter rises, turns and fades; the elemental shivers and shatters) and the appear (fading
-- in from below). `fade` and `shiver` are meta controls SpiritMotion reads from the keys.
local SPIRIT_REST = { spitch = 0.06, hpitch = -0.04, aRp = 0.2, aRo = 0.3, eR = 0.5, aLp = 0.2, aLo = 0.3, eL = 0.5 }
local SPIRIT_GUARD = {
	spitch = 0.14,
	hpitch = -0.1,
	cRu = 0.08,
	cLu = 0.08,
	aRp = 0.6,
	aRo = 0.4,
	aRy = 0.15,
	eR = 0.9,
	wRp = -0.3,
	aLp = 0.6,
	aLo = 0.4,
	aLy = 0.15,
	eL = 0.9,
	wLp = -0.3,
}
local function sg(over: { [string]: number }): { [string]: number }
	return from(SPIRIT_GUARD, over)
end
-- arms flung wide and up (the wail, the burst)
local SPIRIT_WIDE =
	{ aRp = 0.7, aRo = 1.45, aRy = -0.1, eR = 0.2, wRp = 0.2, aLp = 0.7, aLo = 1.45, aLy = -0.1, eL = 0.2, wLp = 0.2 }

local SPIRIT_ACTIONS: { [string]: Action } = {
	-- the bolt (the regular shot and the throw): the right hand draws back and up while the left gathers in front, then
	-- both thrust at the target; the shot leaves the right hand at W (the look dips solid)
	bolt = {
		strike = 0.12,
		follow = 0.22,
		recover = 0.35,
		legs = true,
		lag = { head = 0.05 },
		keys = {
			{
				seg = "A",
				u = 1,
				ease = "inout",
				pose = sg({
					py = 0.03,
					pz = 0.05,
					pyaw = -0.25,
					syaw = -0.25,
					spitch = -0.1,
					hpitch = -0.15,
					aRp = 1.5,
					aRo = 0.7,
					aRy = -0.35,
					eR = 1.5,
					wRp = -0.6,
					aLp = 1.0,
					aLo = 0.35,
					aLy = 0.6,
					eL = 1.5,
				}),
			},
			{
				seg = "S",
				u = 1,
				ease = "in",
				pose = sg({
					py = -0.01,
					pz = -0.06,
					pyaw = 0.08,
					syaw = 0.15,
					spitch = 0.22,
					hpitch = 0.05,
					aRp = 1.45,
					aRo = 0.25,
					aRy = 0.2,
					eR = 0.15,
					wRp = 0.3,
					aLp = 1.35,
					aLo = 0.2,
					aLy = 0.3,
					eL = 0.2,
					wLp = 0.3,
					fade = -0.25,
				}),
			},
			{
				seg = "F",
				u = 1,
				ease = "out",
				pose = sg({
					pz = -0.05,
					syaw = 0.15,
					spitch = 0.2,
					aRp = 1.35,
					aRo = 0.25,
					aRy = 0.25,
					eR = 0.3,
					aLp = 1.25,
					aLo = 0.25,
					eL = 0.3,
				}),
			},
			{ seg = "R", u = 1, ease = "inout", pose = SPIRIT_GUARD },
		},
	},
	-- the wail (the specter's Elite II, W 1.2, a cone 15 / 90): it rises with the arms flung wide and the head thrown
	-- back, holds trembling, then thrusts forward into the scream at W and holds it shaking
	wail = {
		strike = 0.16,
		follow = 0.35,
		recover = 0.4,
		legs = true,
		lag = { head = 0.06 },
		keys = {
			{
				seg = "A",
				u = 0.3,
				ease = "out",
				pose = merge2(
					sg({ py = 0.08, pz = 0.06, spitch = -0.28, hpitch = -0.5, cRu = 0.2, cLu = 0.2 }),
					SPIRIT_WIDE
				),
			},
			{
				seg = "A",
				u = 1,
				ease = "inout",
				pose = merge2(
					sg({ py = 0.1, pz = 0.08, spitch = -0.32, hpitch = -0.55, cRu = 0.25, cLu = 0.25, shiver = 0.6 }),
					SPIRIT_WIDE
				),
			},
			{
				seg = "S",
				u = 1,
				ease = "in",
				pose = from(
					sg({
						py = 0.06,
						pz = -0.06,
						spitch = 0.3,
						hpitch = 0.15,
						aRo = 0.95,
						aLo = 0.95,
						eR = 0.25,
						eL = 0.25,
					}),
					{ aRp = 1.2, aLp = 1.2, shiver = 0.3 }
				),
			},
			{
				seg = "F",
				u = 1,
				ease = "inout",
				pose = from(
					sg({ py = 0.06, pz = -0.05, spitch = 0.28, hpitch = 0.12, aRo = 1.0, aLo = 1.0, eR = 0.3, eL = 0.3 }),
					{ aRp = 1.15, aLp = 1.15, shiver = 1 }
				),
			},
			{ seg = "R", u = 1, ease = "inout", pose = SPIRIT_GUARD },
		},
	},
	-- the burst (heavyBlow, frostNova: a circle round it): it folds in, the arms crossed over the chest, sinking and
	-- shivering harder, then bursts open at W, arched back, rising
	burst = {
		strike = 0.12,
		follow = 0.35,
		recover = 0.45,
		legs = true,
		lag = { head = 0.05 },
		keys = {
			{
				seg = "A",
				u = 0.4,
				ease = "inout",
				pose = sg({
					py = -0.04,
					spitch = 0.35,
					hpitch = 0.2,
					cRu = -0.05,
					cLu = -0.05,
					aRp = 0.9,
					aRo = 0.1,
					aRy = 1.0,
					eR = 2.0,
					aLp = 0.9,
					aLo = 0.1,
					aLy = 1.0,
					eL = 2.0,
					shiver = 0.3,
				}),
			},
			{
				seg = "A",
				u = 1,
				ease = "in",
				pose = sg({
					py = -0.06,
					spitch = 0.42,
					hpitch = 0.25,
					cRu = -0.08,
					cLu = -0.08,
					aRp = 0.85,
					aRo = 0.05,
					aRy = 1.1,
					eR = 2.1,
					aLp = 0.85,
					aLo = 0.05,
					aLy = 1.1,
					eL = 2.1,
					shiver = 1,
				}),
			},
			{
				seg = "S",
				u = 1,
				ease = "out",
				pose = merge2(
					sg({ py = 0.06, spitch = -0.3, hpitch = -0.3, cRu = 0.2, cLu = 0.2, shiver = 0 }),
					SPIRIT_WIDE
				),
			},
			{
				seg = "F",
				u = 1,
				ease = "out",
				pose = merge2(sg({ py = 0.05, spitch = -0.25, hpitch = -0.25, cRu = 0.15, cLu = 0.15 }), SPIRIT_WIDE),
			},
			{ seg = "R", u = 1, ease = "inout", pose = SPIRIT_GUARD },
		},
	},
	-- the swoop (the Elite II pounce, the server lands it at W): it draws up and back with the arms raised, then
	-- swoops along to the target reaching forward
	swoop = {
		strike = 0.4,
		follow = 0.3,
		recover = 0.45,
		legs = true,
		travel = true,
		lag = { head = 0.06 },
		keys = {
			{
				seg = "A",
				u = 1,
				ease = "inout",
				pose = sg({
					py = 0.08,
					pz = 0.08,
					spitch = -0.25,
					hpitch = -0.3,
					aRp = 2.2,
					aRo = 0.6,
					eR = 0.6,
					aLp = 2.2,
					aLo = 0.6,
					eL = 0.6,
				}),
			},
			{
				seg = "S",
				u = 1,
				ease = "in",
				pose = from(
					sg({
						py = -0.02,
						pz = -0.06,
						spitch = 0.4,
						hpitch = 0.1,
						aRp = 1.5,
						aRo = 0.35,
						eR = 0.2,
						aLp = 1.5,
						aLo = 0.35,
						eL = 0.2,
					}),
					{ travel = 1 }
				),
			},
			{
				seg = "F",
				u = 1,
				ease = "out",
				pose = from(sg({ spitch = 0.3, aRp = 1.2, aLp = 1.2, eR = 0.4, eL = 0.4 }), { travel = 1 }),
			},
			{ seg = "R", u = 1, ease = "inout", pose = from(SPIRIT_GUARD, { travel = 1 }) },
		},
	},
	-- the specter's death: a jolt, then it rises 1.5 studs (scale 1) turning a quarter round, the arms drifting up, and
	-- fades out by 0.8 s
	deathRise = {
		strike = 0.15,
		follow = 0.65,
		recover = 0.4,
		legs = true,
		hold = true,
		full = true,
		lag = { head = 0.1 },
		keys = {
			{
				seg = "S",
				u = 1,
				ease = "out",
				pose = merge2(sg({ py = 0.0, spitch = -0.25, hpitch = -0.4, fade = 0.1 }), SPIRIT_WIDE),
			},
			{
				seg = "F",
				u = 1,
				ease = "inout",
				pose = from(SPIRIT_WIDE, {
					py = 0.33,
					pyaw = 1.57,
					spitch = -0.15,
					hpitch = -0.5,
					aRp = 1.4,
					aLp = 1.4,
					aRo = 1.1,
					aLo = 1.1,
					fade = 1,
				}),
			},
			{
				seg = "R",
				u = 1,
				ease = "out",
				pose = from(SPIRIT_WIDE, {
					py = 0.38,
					pyaw = 1.7,
					spitch = -0.15,
					hpitch = -0.5,
					aRp = 1.5,
					aLp = 1.5,
					aRo = 1.1,
					aLo = 1.1,
					fade = 1,
				}),
			},
		},
	},
	-- the elemental's death: it seizes, shivering hard with the arms thrown out, then shatters, fading out by 0.4 s
	deathShatter = {
		strike = 0.25,
		follow = 0.15,
		recover = 0.3,
		legs = true,
		hold = true,
		full = true,
		keys = {
			{
				seg = "S",
				u = 1,
				ease = "out",
				pose = merge2(sg({ py = 0.02, spitch = -0.2, hpitch = -0.2, shiver = 1, fade = 0.1 }), SPIRIT_WIDE),
			},
			{
				seg = "F",
				u = 1,
				ease = "in",
				pose = merge2(sg({ py = -0.05, spitch = 0.1, shiver = 1, fade = 1 }), SPIRIT_WIDE),
			},
			{
				seg = "R",
				u = 1,
				ease = "lin",
				pose = merge2(sg({ py = -0.08, spitch = 0.15, shiver = 0, fade = 1 }), SPIRIT_WIDE),
			},
		},
	},
	-- the appear (a spawn, a summon): it rises out of the ground fading in, the arms opening
	spawnSpirit = {
		strike = 0.3,
		follow = 0.2,
		recover = 0.3,
		legs = true,
		full = true,
		keys = {
			{
				seg = "A",
				u = 0,
				ease = "lin",
				pose = sg({
					py = -0.25,
					spitch = 0.4,
					hpitch = 0.3,
					aRp = 0.2,
					aLp = 0.2,
					eR = 1.6,
					eL = 1.6,
					fade = 1,
				}),
			},
			{
				seg = "S",
				u = 1,
				ease = "out",
				pose = merge2(sg({ py = 0.04, spitch = -0.15, hpitch = -0.2, fade = 0 }), SPIRIT_WIDE),
			},
			{ seg = "F", u = 1, ease = "inout", pose = SPIRIT_GUARD },
			{ seg = "R", u = 1, ease = "inout", pose = SPIRIT_GUARD },
		},
	},
}

-- The floating spirit made from the ghost: its own rest, stance and blows, the caster's pool kept.
local function spirit(over: { [string]: any }): Style
	local out = variant(GHOST, {
		guard = SPIRIT_GUARD,
		procedural = {
			float = true,
			rest = SPIRIT_REST,
			runAt = 99,
			walk = { k = 1, duty = 1, lift = 0, bob = 0, sway = 0, yaw = 0, lean = 0 },
			run = { k = 1, duty = 1, lift = 0, bob = 0, sway = 0, yaw = 0, lean = 0 },
		},
		basic = { "bolt" },
		throw = "bolt",
		abilities = {
			wail = "wail",
			frostNova = "burst",
			boneNova = "burst",
			emberNova = "burst",
			heavyBlow = "burst",
			slam = "burst",
			cleave = "burst",
			crush = "pool",
			voidPool = "pool",
			poisonPool = "pool",
			pounce = "swoop",
			leap = "swoop",
			charge = "swoop",
		},
		aggro = "wail",
		spawn = "spawnSpirit",
		actions = SPIRIT_ACTIONS,
	})
	for key, value in over do
		(out :: any)[key] = value
	end
	out.clips = nil
	out.float = nil
	return out
end

local SPECTER = spirit({
	death = { "deathRise" },
	spirit = {
		speed = 13,
		bob = 0.033,
		bobHz = 0.45,
		sway = 0.05,
		swayHz = 0.3,
		lean = 0.21,
		leanLag = 0.25,
		flicker = { 0.25, 0.1, 0.5 },
		trail = { pitch = 0.55, lag = 0.3, lag2 = 0.55, flutter = 0.06 },
	},
})
local ICE_ELEMENTAL = spirit({
	death = { "deathShatter" },
	spirit = { speed = 13, bob = 0.035, bobHz = 0.4, sway = 0.035, swayHz = 0.25, lean = 0.15, leanLag = 0.3 },
})

---------------------------------------------------------------- the regular wyvern (owner 2026-10-26, docs/ANIM-WZORCE §5.8)

-- The wyvern monster (Tripo Auto Rig, Data/BipedRigs `wyvern`) in Vaelgrath's wyvern style: the same choreography,
-- turned onto its own rig. Its export already stands leaning forward with the neck up (Vaelgrath's rest pitches), so
-- every key loses them; its wings are long fingers that rest half spread, so the wing controls of each key are read as
-- how open, raised and swept Vaelgrath's wing is and laid on this rig's own wing poses (fitted to the dump: folded along
-- the back, lifted in the guard, spread, the top and the bottom of a beat). A ground monster (§9 Q5): it walks on its
-- hind legs with the wings folded, trots, and chases in wing-assisted bounds (one beat per bound); a fire spit from the
-- jaw (release at W), the pounce a flapping leap onto its target.
local WING_KEYS = { "p", "o", "y", "t", "e", "wp", "wy", "wr" }
local function wingPose(r: { number }, l: { number }): { [string]: number }
	local out: { [string]: number } = {}
	for i, k in WING_KEYS do
		local first = string.sub(k, 1, 1)
		local rest = string.sub(k, 2)
		local rKey = if first == "e" then "eR" elseif first == "w" then "wR" .. rest else "aR" .. k
		local lKey = if first == "e" then "eL" elseif first == "w" then "wL" .. rest else "aL" .. k
		out[rKey] = r[i]
		out[lKey] = l[i]
	end
	return out
end
-- p o y t e wp wy wr per side (right, left)
local RW_FOLD = wingPose(
	{ -0.75, 2.14, -1.2, 0.91, 1.46, -0.12, 0.42, -1.32 },
	{ -0.42, 2.28, -1.34, 1.15, 1.59, -0.35, 0.14, -1.23 }
)
local RW_HALF = wingPose(
	{ -0.65, 1.99, -0.69, 0.78, 1.07, -0.11, 0.24, -1.26 },
	{ -0.5, 2.3, -0.71, 1.27, 1.41, -0.31, 0.07, -1.1 }
)
local RW_SPREAD = wingPose(
	{ -0.11, 1.76, -0.09, 0.09, -0.27, 0.13, -0.04, -0.46 },
	{ -0.07, 1.84, -0.07, 0.11, -0.41, 0.21, -0.06, -0.84 }
)
local RW_UP = wingPose(
	{ 0.16, 2.25, -0.64, 0.26, -0.17, 0.01, -0.23, -0.09 },
	{ -0.14, 2.3, -0.18, 0.59, -0.25, -0.04, -0.08, -0.33 }
)
local RW_DOWN = wingPose(
	{ -0.17, 0.87, 0.32, 0.1, -0.15, -0.3, 0.05, -0.51 },
	{ -0.03, 0.92, 0.32, 0.04, -0.42, -0.27, 0.06, -0.77 }
)
-- Vaelgrath's rest pitches (WYVERN_REST), which this export has already
local REBASE: { [string]: number } = { ppitch = -0.5, spitch = -0.3, hpitch = 0.5 }

-- One side's wing of a Vaelgrath key on this rig: the openness from its out-lift (0 folded, 0.35 the guard, 1 spread),
-- this rig's pose there, plus how much more it is raised, swept and bent than Vaelgrath's at that openness.
local function wingFrom(pose: { [string]: number }, side: string, out: { [string]: number })
	local o = pose["a" .. side .. "o"] or 0
	local k = math.clamp((o - 0.3) / 1.3, 0, 1.3)
	local base: { [string]: number }, to: { [string]: number }, u: number
	local p0: number, y0: number, e0: number
	if k <= 0.35 then
		u = k / 0.35
		base, to = RW_FOLD, RW_HALF
		p0, y0, e0 = -0.15 + 0.3 * u, -0.35, 1.9 - 0.7 * u
	else
		u = (k - 0.35) / 0.65
		base, to = RW_HALF, RW_SPREAD
		p0, y0, e0 = 0.15 + 0.45 * u, -0.35 + 0.05 * u, 1.2 - 0.9 * u
	end
	for _, name in WING_KEYS do
		local first = string.sub(name, 1, 1)
		local key = if first == "e"
			then "e" .. side
			elseif first == "w" then "w" .. side .. string.sub(name, 2)
			else "a" .. side .. name
		out[key] = base[key] + (to[key] - base[key]) * u
	end
	out["a" .. side .. "p"] += (pose["a" .. side .. "p"] or 0) - p0
	out["a" .. side .. "y"] += (pose["a" .. side .. "y"] or 0) - y0
	out["e" .. side] += ((pose["e" .. side] or 0) - e0) * 0.6
end

-- How far back the pelvis of this rig may pitch (its long tail would sweep the ground); the spine bends back for it,
-- softened past SPINE_BACK (the head stays over the feet when it rears).
local PELVIS_BACK = -0.15
local SPINE_BACK = -0.45

-- A key of Vaelgrath's on this rig.
local function regular(pose: { [string]: number }): { [string]: number }
	local out = table.clone(pose)
	for key, d in REBASE do
		out[key] = (pose[key] or 0) + d
	end
	if out.ppitch < PELVIS_BACK then
		out.spitch += out.ppitch - PELVIS_BACK
		out.ppitch = PELVIS_BACK
	end
	if out.spitch < SPINE_BACK then
		out.spitch = SPINE_BACK + (out.spitch - SPINE_BACK) * 0.6
	end
	wingFrom(pose, "R", out)
	wingFrom(pose, "L", out)
	return out
end

local function regularAction(action: Action): Action
	local keys = {}
	for _, key in action.keys do
		table.insert(keys, { seg = key.seg, u = key.u, ease = key.ease, pose = regular(key.pose) })
	end
	local out = table.clone(action)
	out.keys = keys
	return out
end

-- Only the wings of Vaelgrath's spread(o, p, y, e) on this rig.
local function rwing(o: number, p: number, y: number, e: number): { [string]: number }
	local out: { [string]: number } = {}
	local pose = spread(o, p, y, e)
	wingFrom(pose, "R", out)
	wingFrom(pose, "L", out)
	return out
end

local RW_REST = from(RW_FOLD, {})
local RW_GUARD = regular(WYVERN_GUARD)
local function rg(over: { [string]: number }): { [string]: number }
	return from(RW_GUARD, over)
end

local REGULAR_WYVERN: Style = {
	guard = RW_GUARD,
	procedural = {
		rest = RW_REST,
		runAt = 4.6,
		-- its hock rests behind the hip: the feet step about a point a quarter leg ahead, strides it can reach
		footZ = -0.25,
		toeRoll = true,
		-- its cadence differs a lot between the walk, the run and the bounds: they blend fast (a slow blend would step
		-- the walk's short strides at the run's speed)
		blend = 10,
		walk = { k = 1.6, duty = 0.6, lift = 0.18, bob = 0.035, sway = 0.06, yaw = 0.1, lean = 0.05 },
		run = { k = 2.2, duty = 0.42, lift = 0.3, bob = 0.06, sway = 0.05, yaw = 0.08, lean = 0.18 },
		-- the chase: bounds of 4.5 leg lengths (about 1.7 a second at full speed), both feet together, the wings
		-- beating once per bound
		hop = {
			at = 6.5,
			k = 4.5,
			duty = 0.25,
			lift = 0.45,
			height = 0.35,
			crouch = 0.1,
			lean = 0.22,
			up = RW_UP,
			down = RW_DOWN,
		},
		flap = { rate = 1.2, out = 1.6, amp = 0.65, pitch = 0.1, lean = 0.2 },
	},
	idleEvery = { 6, 10 },
	rate = 0.05,
	basic = { "spit" },
	abilities = {
		fireBreath = "breath",
		frostBreath = "breath",
		wingBuffet = "buffet",
		tailSwipe = "tail",
		heavyBlow = "claw",
		crush = "stomp",
		slam = "stomp",
		pounce = "pounce",
		leap = "pounce",
		cleave = "claw",
		charge = "buffet",
	},
	throw = "spit",
	death = { "deathDragon" },
	aggro = "roar",
	spawn = "spawnDragon",
	flinch = WYVERN.flinch,
	actions = {},
}
for name, action in WYVERN.actions do
	REGULAR_WYVERN.actions[name] = regularAction(action)
end
-- the death on this rig: after Vaelgrath's last rear and the buckling legs it lies on its left side, the lower wing
-- spread on the ground, the upper one draped over the body, the head limp on the ground (fitted on the dump: nothing
-- under the ground but the small forearms pressed under the chest)
do
	local keys = REGULAR_WYVERN.actions.deathDragon.keys
	local lying = from(keys[#keys].pose, {
		py = -0.69,
		px = -0.24,
		proll = 1.1,
		ppitch = 0.18,
		spitch = 0.39,
		sroll = 0.01,
		hpitch = 1.2,
		hroll = 0.8,
		hyaw = 0.6,
		-- the legs reaching forward along the ground, the upper one bent over the lower (Vaelgrath's feet where they stood
		-- would stretch the raised leg and turn the lower knee over)
		fLx = -0.26,
		fLy = -0.23,
		fLz = -0.73,
		fRx = -0.24,
		fRy = -0.07,
		fRz = -0.62,
	})
	for key, value in wingPose({ -0.01, 0, 0.21, 0.74, 0, 0, 0, 0 }, { 1.79, 0.1, 0.56, 1.18, 2.6, 0.14, -0.43, -0.78 }) do
		lying[key] = value
	end
	-- the legs buckling: the pelvis tips forward so the tail stays off the ground
	local buckle = keys[2].pose
	keys[2].pose = from(buckle, { ppitch = buckle.ppitch + 0.25, spitch = buckle.spitch - 0.25 })
	keys[#keys - 2].pose = from(lying, { py = -0.71, proll = 1.12, hpitch = 1.0, hroll = 0.6 })
	keys[#keys - 1].pose = from(lying, { py = -0.66, hpitch = 1.1, hroll = 0.7 })
	keys[#keys].pose = lying
end
-- the fire spit (the regular shot and the throw, W 0.5-0.81): the neck draws back and up with the chest swelling and
-- the wings lifting, then the head thrusts forward and down, the shot leaving the jaw at W; a recoil after
REGULAR_WYVERN.actions.spit = {
	strike = 0.12,
	follow = 0.2,
	recover = 0.35,
	legs = true,
	lag = { head = 0.04 },
	keys = {
		{
			seg = "A",
			u = 1,
			ease = "inout",
			pose = merge2(
				rg({ py = -0.02, pz = 0.08, ppitch = -0.05, spitch = -0.2, hpitch = -0.4, cRu = 0.15, cLu = 0.15 }),
				rwing(1.0, 0.35, -0.4, 0.8)
			),
		},
		{
			seg = "S",
			u = 1,
			ease = "in",
			pose = merge2(
				rg({ py = -0.1, pz = -0.06, ppitch = 0.22, spitch = 0.25, hpitch = 0.3, fLz = -0.22 }),
				rwing(0.85, 0.2, 0.0, 0.9)
			),
		},
		{
			seg = "F",
			u = 1,
			ease = "out",
			pose = merge2(
				rg({ py = -0.08, pz = 0.02, ppitch = 0.16, spitch = 0.15, hpitch = 0.12, fLz = -0.22 }),
				rwing(0.8, 0.15, -0.1, 1.0)
			),
		},
		{ seg = "R", u = 1, ease = "inout", pose = RW_GUARD },
	},
}
-- the pounce (Elite II, W 1.4, the server lands it on its target at W): a crouch with the wings raised high, the
-- spring with a great downbeat, the flight to the target (the body travels to it by W), landing on both feet
REGULAR_WYVERN.actions.pounce = {
	strike = 0.4,
	follow = 0.3,
	recover = 0.45,
	legs = true,
	travel = true,
	lag = { head = 0.06 },
	keys = {
		{
			seg = "A",
			u = 1,
			ease = "inout",
			pose = merge2(
				rg({ py = -0.3, pz = 0.1, ppitch = 0.3, spitch = 0.1, hpitch = -0.35, fLz = -0.05, fRz = 0.05 }),
				RW_UP
			),
		},
		{
			seg = "S",
			u = 0.45,
			ease = "out",
			pose = merge2(
				from(
					rg({
						py = 0.5,
						pz = -0.1,
						ppitch = 0.2,
						spitch = -0.05,
						hpitch = -0.2,
						fLy = 0.4,
						fRy = 0.4,
						fLz = -0.2,
						fRz = -0.15,
						tL = 0.8,
						tR = 0.8,
					}),
					{ travel = 0.55 }
				),
				RW_DOWN
			),
		},
		{
			seg = "S",
			u = 1,
			ease = "in",
			pose = merge2(
				from(
					rg({
						py = -0.25,
						pz = -0.05,
						ppitch = 0.3,
						spitch = 0.2,
						hpitch = 0.1,
						fLz = -0.2,
						fRz = 0.1,
						fLx = -0.08,
						fRx = 0.08,
					}),
					{ travel = 1 }
				),
				RW_SPREAD
			),
		},
		{
			seg = "F",
			u = 1,
			ease = "out",
			pose = from(
				rg({ py = -0.2, ppitch = 0.25, spitch = 0.15, hpitch = 0.05, fLz = -0.2, fRz = 0.1 }),
				{ travel = 1 }
			),
		},
		{ seg = "R", u = 1, ease = "inout", pose = from(RW_GUARD, { travel = 1 }) },
	},
}

-- The young frost dragon (2026-10-26, until its new model): today's model is a wyvern on four limbs with no forelegs to
-- speak of (Data/BipedRigs youngFrostDragon: the arms rebuilt in the air under the chest), so it takes the regular
-- wyvern's style; it fights in melee (bites and claws instead of the spit). Its colour is the frost of its element
-- (Data/Monsters ice: the breath's cone and the blows' sparks), the style has none of its own.
local FROST_DRAGON = variant(REGULAR_WYVERN, { basic = { "bite", "claw", "bite", "clawL" } })

local STYLES: { [string]: Style } = {
	wyvern = WYVERN,
	wyvernRegular = REGULAR_WYVERN,
	frostDragon = FROST_DRAGON,
	specter = SPECTER,
	iceElemental = ICE_ELEMENTAL,
	humanoid1h = HUMANOID_1H,
	caster = CASTER,
	brute = BRUTE,
	ghost = GHOST,
}

-- the humanoid bosses (Data/BossStyles), by the boss's id
for id, style in BossStyles.STYLES do
	STYLES[id] = style :: any
end

function BipedStyles.get(id: string): Style?
	return STYLES[id]
end

-- The states AnimLab `mob <id> <state>` shows for a biped (besides Logic/LookAnim's slots).
BipedStyles.LAB_STATES = {
	"spit",
	"bolt",
	"wail",
	"burst",
	"swoop",
	"deathRise",
	"deathShatter",
	"spawnSpirit",
	"trot",
	"bite",
	"claw",
	"clawL",
	"breath",
	"buffet",
	"tail",
	"stomp",
	"roar",
	"fly",
	"spawnDragon",
	"deathDragon",
	"spell",
	"spellLeft",
	"nova",
	"pool",
	"clawR",
	"clawL",
	"idle",
	"alert",
	"walk",
	"run",
	"turn",
	"attack1",
	"attack2",
	"cast",
	"slash",
	"backhand",
	"thrust",
	"cleave",
	"heavy",
	"crush",
	"pounce",
	"charge",
	"throw",
	"aggro",
	"hit",
	"hitBack",
	"hitLeft",
	"hitRight",
	"death",
	"deathBack",
	"deathFwd",
	"spawn",
	"fight",
}
-- and the bosses' (Data/BossStyles: their blows, casts, roars, stagger)
for _, state in BossStyles.LAB_STATES do
	if not table.find(BipedStyles.LAB_STATES, state) then
		table.insert(BipedStyles.LAB_STATES, state)
	end
end

return BipedStyles
