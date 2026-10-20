--!strict
-- Skill animations of characters (S28, DESIGN §14): one procedural motion per active skill, played by
-- AnimationController through Logic/SkillPose (Motor6D.Transform over the default animation, like the S22 attack
-- poses). Same joint frame as Data/AttackMotions — degrees, CFrame.fromEulerAnglesYXZ(x, y, z) in the torso frame:
--   arms (rShoulder, rElbow, rWrist, lShoulder, lElbow, lWrist): z tilts the hanging limb sideways (+ towards the
--     character's right), x lifts it forward / up, y turns the lifted limb to the left; elbows / wrists bend with +x;
--   waist: + x leans back, + y turns the upper body left;
--   root (whole body, the RootJoint; HumanoidRootPart is not moved): { pitch (+ leans back), yaw (+ left), roll,
--     lift in studs } — a visual jump or crouch only, the physics body stays where it is;
--   rHip, lHip: x lifts the leg forward, z sideways (+ right); rKnee, lKnee: { bend } (+ the shin folds back).
-- `keys` are { t, pose, ease } (t = seconds from the start, poses absolute; a joint missing from every key is left
-- to the default animation, so a motion without legs keeps walking); after the last key the pose returns to rest
-- over `recover`. Events: `hit` (melee blow, area burst — the server delays the damage by it, at most 0.6 s),
-- `release` (projectile leaves), `land` (end of a jump). `loop` repeats a stretch while a channel lasts; `lock`
-- holds the character still while the motion plays (unless a breakpoint lets it move, Data/Skills castMove);
-- `trail` shows the weapon trail from..to (seconds).
-- `clip` (S113): a real clip `{ id, hit = "Hit", speed?, hitTime? }` plays instead of the keys; its marker is fitted to
-- the motion's `hit` (or `release`) (Logic/ClipFit); the keys stay as the fallback. Never on a channel (`loop`).
-- `variants` (S114): other keys for a weapon family (Data/AttackMotions.byWeapon: "slash2h", "thrust", …), a number of
-- waves of the cast (the `w` of the cast event: breakpoints and nodes adding hits) or a cast while walking (castMove,
-- the `mv` of the cast event). A variant has no events: hit / release / land / loop / lock always come from the motion
-- itself, so the server's times never change (tests/fixtures/skill_timing). Logic/SkillPose.pick chooses the first
-- variant whose given conditions all hold (`hits` = at least that many waves); a clip plays only for the motion itself.

export type Joint = string
export type Pose = { [Joint]: { number } }
export type Ease = "linear" | "in" | "out" | "inOut"
export type Key = { t: number, pose: Pose, ease: Ease? }
-- A real clip (same shape as Data/AttackMotions.Clip, Logic/ClipFit): "rbxassetid://<digits>", the marker name, the
-- speed without a marker time, the marker's time at speed 1.
export type Clip = { id: string, hit: string?, speed: number?, hitTime: number? }

-- S114: other keys of a motion under a condition (no events: those stay the motion's).
export type Variant = {
	weapon: string?, -- weapon family (AttackMotions.byWeapon value) of the caster's weapon
	hits: number?, -- at least this many waves (cast event `w`)
	move: boolean?, -- the cast lets the caster walk (cast event `mv`)
	keys: { Key },
	recover: number?,
	trail: { from: number, to: number }?,
}

export type Motion = {
	keys: { Key },
	recover: number,
	hit: number?,
	release: number?,
	land: number?,
	loop: { from: number, to: number }?,
	lock: boolean?,
	trail: { from: number, to: number }?,
	clip: Clip?, -- S113: e.g. clip = { id = "rbxassetid://1234567890", hit = "Hit", hitTime = 0.42 }
	variants: { Variant }?, -- S114
}

local SkillMotions = {}

SkillMotions.ARM_JOINTS = { "rShoulder", "rElbow", "rWrist", "lShoulder", "lElbow", "lWrist" }
SkillMotions.JOINTS = {
	"rShoulder",
	"rElbow",
	"rWrist",
	"lShoulder",
	"lElbow",
	"lWrist",
	"waist",
	"root",
	"rHip",
	"lHip",
	"rKnee",
	"lKnee",
}
-- Values per joint (root has a lift, knees only bend).
SkillMotions.SIZE = { root = 4, rKnee = 1, lKnee = 1 }
SkillMotions.MAX_HIT = 0.6

-- Pose helpers -----------------------------------------------------------------------------------------------

local function merge(...: Pose): Pose
	local out: Pose = {}
	for i = 1, select("#", ...) do
		local pose = select(i, ...)
		for joint, value in pose do
			out[joint] = value
		end
	end
	return out
end

-- Knees bent and the body lowered (depth 0..1.5).
local function crouch(depth: number): Pose
	return {
		root = { 0, 0, 0, -0.9 * depth },
		rHip = { 38 * depth, 0, 2 },
		lHip = { 38 * depth, 0, -2 },
		rKnee = { 70 * depth },
		lKnee = { 70 * depth },
	}
end

-- Legs straight (back to the stance after a crouch / a jump).
local STAND: Pose = {
	root = { 0, 0, 0, 0 },
	rHip = { 0, 0, 0 },
	lHip = { 0, 0, 0 },
	rKnee = { 0 },
	lKnee = { 0 },
}

-- Airborne: the body up by `lift`, legs tucked.
local function air(lift: number, tuck: number?): Pose
	local k = tuck or 1
	return {
		root = { 0, 0, 0, lift },
		rHip = { 45 * k, 0, 4 },
		lHip = { 30 * k, 0, -4 },
		rKnee = { 70 * k },
		lKnee = { 55 * k },
	}
end

-- Lunge: right leg forward.
local function lunge(depth: number): Pose
	return {
		root = { -6 * depth, 0, 0, -0.5 * depth },
		rHip = { 50 * depth, 0, 4 },
		lHip = { -22 * depth, 0, -4 },
		rKnee = { 55 * depth },
		lKnee = { 20 * depth },
	}
end

-- Kneeling on the left knee.
local KNEEL: Pose = {
	root = { 0, 0, 0, -1.3 },
	rHip = { 80, 0, 6 },
	lHip = { -8, 0, -4 },
	rKnee = { 85 },
	lKnee = { 100 },
}

-- Both arms high over the head (two-handed grip).
local OVERHEAD: Pose = {
	rShoulder = { 172, 0, 12 },
	rElbow = { 45, 0, 0 },
	lShoulder = { 160, 0, 28 },
	lElbow = { 50, 0, 0 },
}

-- Both arms down in front (after a slam).
local SLAMMED: Pose = {
	rShoulder = { 25, 0, -6 },
	rElbow = { 6, 0, 0 },
	lShoulder = { 28, 0, 14 },
	lElbow = { 10, 0, 0 },
}

-- Warrior poses shared by several motions (S74).
-- Battle Cry: the weapon thrust up, the roar.
local ROAR: Pose = merge(STAND, {
	rShoulder = { 175, 0, 10 },
	rElbow = { 10, 0, 0 },
	lShoulder = { 60, 0, -40 },
	lElbow = { 90, 0, 0 },
	waist = { 18, 0, 0 },
	root = { 6, 0, 0, 0.2 },
})
-- Charge: bent forward, running.
local CHARGE_RUN: Pose = {
	root = { -22, 0, 0, -0.3 },
	waist = { -12, 0, 0 },
	rShoulder = { -35, 0, 10 },
	rElbow = { 40, 0, 0 },
	lShoulder = { 40, 0, -10 },
	lElbow = { 70, 0, 0 },
	rHip = { 45, 0, 0 },
	lHip = { -25, 0, 0 },
	rKnee = { 60 },
	lKnee = { 20 },
}
-- Bloodlust: the hunch before the roar.
local HUNCH: Pose = merge(crouch(0.4), {
	waist = { -22, 0, 0 },
	rShoulder = { 40, 0, 10 },
	rElbow = { 115, 0, 0 },
	lShoulder = { 40, 0, -10 },
	lElbow = { 115, 0, 0 },
})
-- Last Bastion guard: low stance, shield arm forward, weapon held back (shared by Intercept and Shield Wall).
local GUARD: Pose = merge(crouch(0.45), {
	lShoulder = { 88, 10, -22 },
	lElbow = { 72, 0, 0 },
	rShoulder = { 22, 0, 30 },
	rElbow = { 65, 0, 0 },
	waist = { -10, 10, 0 },
})

local function k(t: number, pose: Pose, ease: Ease?): Key
	return { t = t, pose = pose, ease = ease }
end

-- S114: a typed variant (the checker cannot unify table literals with different optional fields in one list).
local function variant(def: Variant): Variant
	return def
end

local motions: { [string]: Motion } = {}

-- Warrior ----------------------------------------------------------------------------------------------------

-- Mighty Strike: the blade raised high over the right shoulder (weight on the back leg), a lunge and a heavy diagonal
-- cut: the arm crosses the shoulder line exactly at the hit (0.3), the blade runs on low to the left hip and bounces back
-- a little. S114: a two-handed weapon (slash2h) holds the hilt with both hands and winds up a little longer.
local MIGHTY_WINDUP: Pose = {
	root = { 4, -8, 0, -0.25 },
	rHip = { 8, 0, 4 },
	lHip = { -14, 0, -4 },
	rKnee = { 18 },
	lKnee = { 30 },
	rShoulder = { 170, 0, 25 },
	rElbow = { 60, 0, 0 },
	rWrist = { -20, 0, 0 },
	lShoulder = { 40, 0, -15 },
	waist = { 10, -18, 0 },
}
local MIGHTY_CUT: Pose = merge(lunge(0.9), {
	rShoulder = { 95, 0, -12 },
	rElbow = { 10, 0, 0 },
	rWrist = { 10, 0, 0 },
	lShoulder = { 0, 0, -12 },
	waist = { -10, 14, 0 },
})
local MIGHTY_LOW: Pose = merge(lunge(1), {
	rShoulder = { 20, 0, -40 },
	rElbow = { 4, 0, 0 },
	rWrist = { 22, 0, 0 },
	lShoulder = { -10, 0, -10 },
	waist = { -15, 24, 0 },
})
local MIGHTY_BOUNCE: Pose =
	merge(lunge(1), { rShoulder = { 28, 0, -30 }, rWrist = { 12, 0, 0 }, waist = { -12, 18, 0 } })
-- The left hand on the hilt of a two-handed weapon (S114 variant): the left arm follows the right one.
local function twoHanded(pose: Pose, left: { number }, elbow: number): Pose
	return merge(pose, { lShoulder = left, lElbow = { elbow, 0, 0 } })
end
motions.mightyStrike = {
	keys = {
		k(0.22, MIGHTY_WINDUP, "out"),
		k(0.3, MIGHTY_CUT, "in"),
		k(0.4, MIGHTY_LOW, "out"),
		k(0.46, MIGHTY_BOUNCE),
	},
	recover = 0.3,
	hit = 0.3,
	trail = { from = 0.2, to = 0.4 },
	variants = {
		variant({
			weapon = "slash2h",
			keys = {
				k(0.25, twoHanded(MIGHTY_WINDUP, { 158, 0, 34 }, 70), "out"),
				k(0.3, twoHanded(MIGHTY_CUT, { 88, 0, 14 }, 30), "in"),
				k(0.4, twoHanded(MIGHTY_LOW, { 26, 0, -14 }, 12), "out"),
				k(0.46, twoHanded(MIGHTY_BOUNCE, { 32, 0, -8 }, 14)),
			},
			trail = { from = 0.24, to = 0.4 },
		}),
	},
}

-- Battle Cry: weapon raised, the body arched back, a roar.
motions.battleCry = {
	keys = {
		k(
			0.12,
			merge(crouch(0.35), {
				rShoulder = { -25, 0, 20 },
				rElbow = { 40, 0, 0 },
				lShoulder = { 20, 0, -20 },
				lElbow = { 80, 0, 0 },
				waist = { -18, 0, 0 },
			}),
			"out"
		), -- walka-wk: the breath drawn in, the weapon low
		k(0.25, ROAR, "out"),
		k(
			0.75,
			merge(STAND, {
				rShoulder = { 178, 0, 14 },
				rElbow = { 6, 0, 0 },
				lShoulder = { 70, 0, -55 },
				lElbow = { 85, 0, 0 },
				waist = { 22, 0, 0 },
				root = { 8, 0, 0, 0.2 },
			})
		),
	},
	recover = 0.3,
	hit = 0.3,
	lock = true,
}

-- Charge: bent forward running at the target (the server moves the body at 0.15), a shoulder bash at the end. S114:
-- the server deals the damage 0.15 s after the event (Movement.charge), so the bash peaks at 0.30 (the run held to
-- 0.27); the hit stays 0.15 (the event).
local BASH: Pose = {
	root = { -18, -28, 0, -0.2 },
	waist = { -6, -25, 0 },
	lShoulder = { 70, 30, -40 },
	lElbow = { 100, 0, 0 },
	rShoulder = { -20, 0, 20 },
	rElbow = { 30, 0, 0 },
	rHip = { 20, 0, 0 },
	lHip = { 10, 0, 0 },
	rKnee = { 25 },
	lKnee = { 30 },
}
motions.charge = {
	keys = {
		k(0.12, CHARGE_RUN, "out"),
		k(0.27, merge(CHARGE_RUN, { root = { -24, -8, 0, -0.35 }, waist = { -12, -10, 0 } })),
		k(0.3, BASH, "in"),
		k(0.4, merge(BASH, { root = { -8, -18, 0, -0.1 }, waist = { 0, -16, 0 }, lShoulder = { 55, 25, -30 } }), "out"),
	},
	recover = 0.3,
	hit = 0.15,
}

-- Blade Whirl: the blade out to the side, turns of the body in a low stance. S114: the blade (right arm out to the
-- right) passes the front (turn 90°) at every server wave (0.18 / 0.38 / 0.58, `interval` 0.2), one turn per wave,
-- easing out to a stop at a whole number of turns minus the 20° of the wind-up. Variants: 4 waves (10B, the 4th at
-- 0.78), walking (5A castMove: arms and turns only, the default animation walks the legs), two-handed (slash2h).
local WHIRL_STEP = 0.2 -- seconds between two waves (Data/Skills/Warrior bladeWhirl interval)
local function whirl(waves: number, legs: boolean, twoHands: boolean): { Key }
	local function at(yaw: number): Pose
		local pose: Pose = {
			rShoulder = { 10, 0, 92 },
			rElbow = { 5, 0, 0 },
			rWrist = { 0, 0, 0 },
			lShoulder = if twoHands then { 40, 60, 0 } else { 10, 0, -70 },
			lElbow = if twoHands then { 70, 0, 0 } else { 20, 0, 0 },
			waist = { -6, -25, 0 },
			root = { 0, yaw, 0, if legs then -0.35 else 0 },
		}
		return if legs then merge(crouch(0.35), pose) else pose
	end
	local keys = { k(0.1, at(-20), "out") }
	for wave = 1, waves do
		table.insert(
			keys,
			k(0.18 + (wave - 1) * WHIRL_STEP, at(90 + 360 * (wave - 1)), if wave == 1 then "in" else "linear")
		)
	end
	local last = 0.18 + (waves - 1) * WHIRL_STEP
	table.insert(keys, k(last + 0.12, at(360 * waves - 20), "out"))
	return keys
end
motions.bladeWhirl = {
	keys = whirl(3, true, false),
	recover = 0.25,
	hit = 0.18,
	lock = true,
	trail = { from = 0.1, to = 0.7 },
	variants = {
		variant({ hits = 4, move = true, keys = whirl(4, false, false), trail = { from = 0.1, to = 0.9 } }),
		variant({ hits = 4, keys = whirl(4, true, false), trail = { from = 0.1, to = 0.9 } }),
		variant({ move = true, keys = whirl(3, false, false) }),
		variant({ weapon = "slash2h", keys = whirl(3, true, true) }),
	},
}

-- Cleave: a wide two-handed horizontal sweep from left to right (the Berserker's two-handed weapon is the base). S114:
-- the blade crosses the middle of the cone exactly at the hit (0.27), runs on to the right and slows (0.36).
motions.cleave = {
	keys = {
		k(
			0.2,
			merge(STAND, {
				rShoulder = { 85, 65, 0 },
				rElbow = { 35, 0, 0 },
				lShoulder = { 80, 55, 0 },
				lElbow = { 45, 0, 0 },
				waist = { 0, 38, 0 },
				root = { 0, 10, 0, -0.2 },
			}),
			"out"
		),
		k(
			0.27,
			merge(lunge(0.4), {
				rShoulder = { 88, -8, 0 },
				rElbow = { 8, 0, 0 },
				lShoulder = { 84, 2, 0 },
				lElbow = { 22, 0, 0 },
				waist = { -2, 0, 0 },
				root = { -2, 0, 0, -0.25 },
			}),
			"in"
		),
		k(
			0.36,
			merge(lunge(0.6), {
				rShoulder = { 82, -88, 0 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 76, -70, 0 },
				lElbow = { 20, 0, 0 },
				waist = { -4, -44, 0 },
				root = { -4, -12, 0, -0.3 },
			}),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.27,
	trail = { from = 0.18, to = 0.36 },
}

-- Taunt: a breath in (S114: the upper body draws back for 0.1 s), then the arms thrown wide, chest out, a challenge
-- peaking at the hit (0.2).
motions.taunt = {
	keys = {
		k(
			0.1,
			merge(STAND, {
				rShoulder = { 35, 0, 30 },
				rElbow = { 50, 0, 0 },
				lShoulder = { 35, 0, -30 },
				lElbow = { 50, 0, 0 },
				waist = { -6, 0, 0 },
				root = { -3, 0, 0, -0.1 },
			}),
			"out"
		),
		k(
			0.2,
			merge(STAND, {
				rShoulder = { 20, 0, 100 },
				rElbow = { 20, 0, 0 },
				lShoulder = { 20, 0, -100 },
				lElbow = { 20, 0, 0 },
				waist = { 16, 0, 0 },
				root = { 4, 0, 0, 0 },
			}),
			"in"
		),
		k(
			0.55,
			merge(STAND, {
				rShoulder = { 30, 0, 95 },
				lShoulder = { 30, 0, -95 },
				waist = { 20, 0, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.2,
	lock = true,
}

-- Earthquake: crouch, a jump with the weapon over the head, a two-handed blow into the ground.
motions.earthquake = {
	keys = {
		k(
			0.16,
			merge(crouch(0.9), { rShoulder = { -30, 0, 10 }, lShoulder = { -30, 0, -10 }, waist = { -12, 0, 0 } }),
			"out"
		),
		k(0.36, merge(air(2.4), OVERHEAD, { waist = { 12, 0, 0 } }), "out"),
		k(0.48, merge(crouch(1.1), SLAMMED, { waist = { -28, 0, 0 }, root = { -12, 0, 0, -1 } }), "in"),
		k(0.62, merge(crouch(0.9), SLAMMED, { waist = { -24, 0, 0 }, root = { -10, 0, 0, -0.8 } })),
	},
	recover = 0.35,
	hit = 0.48,
	land = 0.48,
	lock = true,
	trail = { from = 0.36, to = 0.5 },
}

-- Bloodlust: hunched, fists clenched, then a roar with the arms out.
motions.bloodlust = {
	keys = {
		k(0.16, HUNCH, "out"),
		k(
			0.4,
			merge(STAND, {
				waist = { 26, 0, 0 },
				root = { 8, 0, 0, 0.2 },
				rShoulder = { 30, 0, 75 },
				rElbow = { 40, 0, 0 },
				lShoulder = { 30, 0, -75 },
				lElbow = { 40, 0, 0 },
			}),
			"out"
		),
		k(0.7, merge(STAND, { waist = { 22, 0, 0 }, rShoulder = { 25, 0, 70 }, lShoulder = { 25, 0, -70 } })),
	},
	recover = 0.3,
	hit = 0.4,
	lock = true,
}

-- Crushing Blow: both hands over the head, a hop forward and a crushing smash.
motions.crushingBlow = {
	keys = {
		k(0.28, merge(air(0.6, 0.4), OVERHEAD, { waist = { 15, 0, 0 }, root = { 8, 0, 0, 0.6 } }), "out"),
		k(0.4, merge(lunge(1.1), SLAMMED, { waist = { -30, 0, 0 }, root = { -15, 0, 0, -0.6 } }), "in"),
		k(0.55, merge(lunge(1), SLAMMED, { waist = { -26, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.4,
	trail = { from = 0.28, to = 0.42 },
}

-- Last Bastion: a low guard, shield arm forward, the weapon held back.
motions.lastBastion = {
	keys = {
		k(
			0.07,
			merge(STAND, {
				lShoulder = { 60, 10, -10 },
				lElbow = { 60, 0, 0 },
				rShoulder = { 40, 0, 20 },
				rElbow = { 50, 0, 0 },
				waist = { 6, 0, 0 },
				root = { 4, 0, 0, 0.15 },
			}),
			"out"
		), -- walka-wk: a rise before dropping into the guard
		k(
			0.18,
			merge(crouch(0.45), {
				lShoulder = { 85, 10, -20 },
				lElbow = { 70, 0, 0 },
				rShoulder = { 20, 0, 30 },
				rElbow = { 65, 0, 0 },
				waist = { -8, 10, 0 },
			}),
			"out"
		),
		k(0.8, GUARD),
	},
	recover = 0.3,
	hit = 0.18,
}

-- S74 (ROZWOJ 14.2): the six path skills, from the poses above.
-- Intercept: the Charge sprint to the ally (the server moves the body at the hit), ending in the guard.
motions.intercept = {
	keys = { k(0.12, CHARGE_RUN, "out"), k(0.26, GUARD, "in"), k(0.7, GUARD) },
	recover = 0.3,
	hit = 0.15,
}

-- Shield Wall: the guard, the shield raised, then its edge driven into the ground in a crouch.
local WALL_DOWN: Pose = merge(crouch(0.6), {
	lShoulder = { 35, 10, -14 },
	lElbow = { 10, 0, 0 },
	rShoulder = { 25, 0, 30 },
	rElbow = { 65, 0, 0 },
	waist = { -26, 10, 0 },
	root = { -10, 0, 0, -0.6 },
})
motions.shieldWall = {
	keys = {
		k(0.18, GUARD, "out"),
		k(
			0.34,
			merge(crouch(0.6), {
				lShoulder = { 125, 10, -18 },
				lElbow = { 35, 0, 0 },
				rShoulder = { 30, 0, 30 },
				rElbow = { 65, 0, 0 },
				waist = { 8, 10, 0 },
			}),
			"out"
		),
		k(0.46, WALL_DOWN, "in"),
		k(0.9, WALL_DOWN),
	},
	recover = 0.35,
	hit = 0.46,
	lock = true,
}

-- Rend: a two-handed swing over the head, a lunge and a diagonal cut down.
motions.rend = {
	keys = {
		k(0.2, merge(STAND, OVERHEAD, { waist = { 14, -10, 0 } }), "out"),
		k(0.32, merge(lunge(1), SLAMMED, { waist = { -24, 20, 0 }, root = { -10, 0, 0, -0.5 } }), "in"),
		k(0.46, merge(lunge(1), SLAMMED, { waist = { -20, 16, 0 } })),
	},
	recover = 0.3,
	hit = 0.32,
	trail = { from = 0.18, to = 0.36 },
}

-- Carnage: the Bloodlust hunch, then a roar with the weapon raised over the head in a wide stance (S114: unlike
-- Bloodlust the weapon goes up and the feet apart; the roar peaks at the hit, 0.4).
local WIDE: Pose = { rHip = { 0, 0, 16 }, lHip = { 0, 0, -16 } }
motions.carnage = {
	keys = {
		k(0.16, HUNCH, "out"),
		k(0.4, merge(STAND, OVERHEAD, WIDE, { waist = { 24, 0, 0 }, root = { 8, 0, 0, 0.1 } }), "out"),
		k(0.75, merge(STAND, OVERHEAD, WIDE, { waist = { 20, 0, 0 }, root = { 0, 0, 0, -0.1 } })),
	},
	recover = 0.3,
	hit = 0.4,
	lock = true,
}

-- War Banner: the haft raised, a kneel and the banner planted (Earthquake without the jump).
motions.warBanner = {
	keys = {
		k(0.18, merge(STAND, OVERHEAD, { waist = { 10, 0, 0 } }), "out"),
		k(0.4, merge(crouch(0.5), SLAMMED, { waist = { -24, 0, 0 }, root = { -8, 0, 0, -0.45 } }), "in"),
		k(0.7, merge(crouch(0.5), SLAMMED, { waist = { -18, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.4,
	lock = true,
}

-- Order to Advance: the Battle Cry roar, then a two-handed blow into the ground.
motions.advanceOrder = {
	keys = {
		k(0.22, ROAR, "out"),
		k(0.4, merge(STAND, OVERHEAD, { waist = { 14, 0, 0 }, root = { 4, 0, 0, 0.1 } }), "inOut"),
		k(0.54, merge(crouch(0.8), SLAMMED, { waist = { -26, 0, 0 }, root = { -10, 0, 0, -0.7 } }), "in"),
		k(0.8, merge(crouch(0.7), SLAMMED, { waist = { -20, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.54,
	lock = true,
}

-- Titan's Wrath: three leaping blows, each landing with a wave (the server's waves 0.45 s apart).
local function leap(base: number, yaw: number): { Key }
	return {
		k(
			base + 0.07,
			merge(crouch(0.8), { rShoulder = { -20, 0, 10 }, lShoulder = { -20, 0, -10 }, root = { 0, yaw, 0, -0.7 } }),
			"out"
		),
		k(base + 0.2, merge(air(1.8), OVERHEAD, { waist = { 10, 0, 0 }, root = { 0, yaw, 0, 1.8 } }), "out"),
		k(base + 0.3, merge(crouch(1), SLAMMED, { waist = { -26, 0, 0 }, root = { -10, yaw, 0, -0.9 } }), "in"),
	}
end
-- S114: 4 waves (10B) leap a fourth time straight ahead, landing at 1.65 (hit + 3 x interval).
local function leaps(yaws: { number }): { Key }
	local keys = {}
	for i, yaw in yaws do
		for _, key in leap((i - 1) * 0.45, yaw) do
			table.insert(keys, key)
		end
	end
	local last = (#yaws - 1) * 0.45 + 0.3
	table.insert(keys, k(last + 0.25, merge(crouch(0.8), SLAMMED, { waist = { -20, 0, 0 } })))
	return keys
end
motions.titansWrath = {
	keys = leaps({ 0, 35, -35 }),
	recover = 0.35,
	hit = 0.3,
	land = 0.3,
	lock = true,
	trail = { from = 0.2, to = 1.2 },
	variants = { variant({ hits = 4, keys = leaps({ 0, 35, -35, 0 }), trail = { from = 0.2, to = 1.65 } }) },
}

-- S143 (DESIGN-18 §6.2): the Warrior pools' new skills from the poses above (the same rule as S140-S142); the look
-- apart is their SkillVfx. A full motion pass comes with W03-W07.
-- Shield Sweep: from the guard the shield arm sweeps from right to left across the cone; the shield's face crosses the
-- middle at the hit (0.24).
motions.shieldSweep = {
	keys = {
		k(0.14, merge(GUARD, { lShoulder = { 82, 70, -14 }, lElbow = { 40, 0, 0 }, waist = { -6, 32, 0 } }), "out"),
		k(
			0.24,
			merge(lunge(0.5), {
				lShoulder = { 88, 0, -10 },
				lElbow = { 18, 0, 0 },
				rShoulder = { 22, 0, 30 },
				rElbow = { 65, 0, 0 },
				waist = { -4, 0, 0 },
			}),
			"in"
		),
		k(
			0.36,
			merge(lunge(0.6), {
				lShoulder = { 80, -70, -10 },
				lElbow = { 14, 0, 0 },
				rShoulder = { 22, 0, 30 },
				rElbow = { 65, 0, 0 },
				waist = { -6, -34, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.24,
}
-- Shield Bash: the guard, then the shield driven straight into the target's face with a short lunge (hit 0.22).
local BASH_OUT: Pose = merge(lunge(0.8), {
	lShoulder = { 96, 0, -4 },
	lElbow = { 4, 0, 0 },
	rShoulder = { 20, 0, 30 },
	rElbow = { 65, 0, 0 },
	waist = { -12, -16, 0 },
	root = { -6, -12, 0, -0.2 },
})
motions.shieldBash = {
	keys = { k(0.12, GUARD, "out"), k(0.22, BASH_OUT, "in"), k(0.42, merge(GUARD, { waist = { -8, 0, 0 } })) },
	recover = 0.3,
	hit = 0.22,
}
-- Vindicate: Mighty Strike's diagonal cut with the shield held up in the guard (the left arm stays on the shield).
local SHIELD_UP: Pose = { lShoulder = { 85, 10, -20 }, lElbow = { 70, 0, 0 } }
motions.vindicate = {
	keys = {
		k(0.22, merge(MIGHTY_WINDUP, SHIELD_UP), "out"),
		k(0.3, merge(MIGHTY_CUT, SHIELD_UP), "in"),
		k(0.4, merge(MIGHTY_LOW, SHIELD_UP), "out"),
		k(0.46, merge(MIGHTY_BOUNCE, SHIELD_UP)),
	},
	recover = 0.3,
	hit = 0.3,
	trail = { from = 0.2, to = 0.4 },
}
-- Brutal Strike: Mighty Strike's two-handed variant (both hands on the hilt, a longer wind-up).
motions.brutalStrike = {
	keys = {
		k(0.25, twoHanded(MIGHTY_WINDUP, { 158, 0, 34 }, 70), "out"),
		k(0.3, twoHanded(MIGHTY_CUT, { 88, 0, 14 }, 30), "in"),
		k(0.4, twoHanded(MIGHTY_LOW, { 26, 0, -14 }, 12), "out"),
		k(0.46, twoHanded(MIGHTY_BOUNCE, { 32, 0, -8 }, 14)),
	},
	recover = 0.3,
	hit = 0.3,
	trail = { from = 0.24, to = 0.4 },
}
-- Sunder: the weapon over the head turned to the right, a heavy slanting blow down across the target's armour (0.32).
motions.sunder = {
	keys = {
		k(0.2, merge(STAND, OVERHEAD, { waist = { 10, 26, 0 } }), "out"),
		k(0.32, merge(lunge(0.9), SLAMMED, { waist = { -20, -26, 0 }, root = { -8, -20, 0, -0.4 } }), "in"),
		k(0.46, merge(lunge(0.9), SLAMMED, { waist = { -16, -20, 0 } })),
	},
	recover = 0.3,
	hit = 0.32,
	trail = { from = 0.18, to = 0.36 },
}
-- War Stomp: the right knee pulled up with the arms out, the foot stamped down in a crouch (the ground shakes at 0.3).
motions.warStomp = {
	keys = {
		k(
			0.15,
			merge(STAND, {
				rHip = { 62, 0, 0 },
				rKnee = { 72 },
				waist = { 8, 0, 0 },
				rShoulder = { 40, 0, 45 },
				lShoulder = { 40, 0, -45 },
			}),
			"out"
		),
		k(
			0.3,
			merge(crouch(0.6), {
				rHip = { 12, 0, 0 },
				rKnee = { 22 },
				rShoulder = { 20, 0, 55 },
				lShoulder = { 20, 0, -55 },
				waist = { -14, 0, 0 },
			}),
			"in"
		),
		k(0.6, merge(crouch(0.5), { rShoulder = { 18, 0, 50 }, lShoulder = { 18, 0, -50 }, waist = { -10, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.3,
	lock = true,
}
-- Execute: the two-handed weapon raised high behind the head, a deep lunge and a chop straight down (0.4).
motions.execute = {
	keys = {
		k(0.28, merge(STAND, OVERHEAD, { waist = { 20, 0, 0 }, root = { 6, 0, 0, 0.2 } }), "out"),
		k(0.4, merge(lunge(1.2), SLAMMED, { waist = { -36, 0, 0 }, root = { -16, 0, 0, -0.7 } }), "in"),
		k(0.56, merge(lunge(1.1), SLAMMED, { waist = { -30, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.4,
	trail = { from = 0.26, to = 0.42 },
}

-- Hunter -----------------------------------------------------------------------------------------------------

-- S115 (DESIGN-16 §6): every shot is built by one function from a shooting rig, so a crossbow plays the same shot with
-- its own hold (a `weapon = "crossbow"` variant, never a copy of the keys). The bow stands upright in the LEFT hand
-- (lWrist -60 as the basic attack, Data/AttackMotions bow): `aim` = the string half drawn, `full` = drawn to the cheek,
-- `loose` = the right hand snapped back past the ear (the arrow leaves: a key exactly at the release), `after` = the
-- hand settling behind the ear, `reach` = the right hand at the quiver over the right shoulder (the next arrow). The
-- crossbow (Data/AttackMotions crossbow): the stock at the cheek, the left hand under the fore-end, the right on the
-- trigger (`aim` / `full`), `loose` = the kick (shoulders back 8°, the bolt up 6°), `reach` = the right hand cranking at
-- the stock. `yaw` = how far the upper body turns side-on.
export type ShotRig = { aim: Pose, full: Pose, loose: Pose, after: Pose, reach: Pose, yaw: number }

local BOW: ShotRig = {
	aim = {
		lShoulder = { 90, 28, 0 },
		lElbow = { 0, 0, 0 },
		lWrist = { -60, 0, 0 },
		rShoulder = { 90, -45, 0 },
		rElbow = { 120, 0, 0 },
		rWrist = { 0, 0, 0 },
		waist = { 0, -28, 0 },
	},
	full = {
		lShoulder = { 90, 28, 0 },
		lElbow = { 0, 0, 0 },
		lWrist = { -60, 0, 0 },
		rShoulder = { 90, -50, 0 },
		rElbow = { 140, 0, 0 },
		rWrist = { 0, 0, 0 },
		waist = { 0, -28, 0 },
	},
	loose = {
		lShoulder = { 95, 28, 0 },
		lElbow = { 0, 0, 0 },
		lWrist = { -60, 0, 0 },
		rShoulder = { 88, -68, 0 },
		rElbow = { 150, 0, 0 },
		rWrist = { 0, 0, 0 },
		waist = { 0, -28, 0 },
	},
	after = {
		lShoulder = { 94, 28, 0 },
		lElbow = { 0, 0, 0 },
		lWrist = { -60, 0, 0 },
		rShoulder = { 85, -80, 0 },
		rElbow = { 140, 0, 0 },
		rWrist = { 0, 0, 0 },
		waist = { 0, -28, 0 },
	},
	reach = {
		lShoulder = { 82, 28, 0 },
		lElbow = { 0, 0, 0 },
		lWrist = { -60, 0, 0 },
		rShoulder = { 150, -10, 25 },
		rElbow = { 120, 0, 0 },
		rWrist = { 0, 0, 0 },
		waist = { 0, -24, 0 },
	},
	yaw = -28,
}

local CROSSBOW: ShotRig = {
	aim = {
		rShoulder = { 55, 30, 0 },
		rElbow = { 60, 0, 0 },
		rWrist = { -40, 0, 0 },
		lShoulder = { 60, 12, 0 },
		lElbow = { 10, 0, 0 },
		lWrist = { -60, 0, 0 },
		waist = { 0, -8, 0 },
	},
	full = {
		rShoulder = { 62, 30, 0 },
		rElbow = { 65, 0, 0 },
		rWrist = { -40, 0, 0 },
		lShoulder = { 66, 12, 0 },
		lElbow = { 10, 0, 0 },
		lWrist = { -60, 0, 0 },
		waist = { 0, -8, 0 },
	},
	loose = {
		rShoulder = { 68, 30, 0 },
		rElbow = { 65, 0, 0 },
		rWrist = { -40, 0, 0 },
		lShoulder = { 72, 12, 0 },
		lElbow = { 10, 0, 0 },
		lWrist = { -60, 0, 0 },
		waist = { 8, -8, 0 },
	},
	after = {
		rShoulder = { 64, 30, 0 },
		rElbow = { 65, 0, 0 },
		rWrist = { -40, 0, 0 },
		lShoulder = { 68, 12, 0 },
		lElbow = { 10, 0, 0 },
		lWrist = { -60, 0, 0 },
		waist = { 4, -8, 0 },
	},
	reach = {
		rShoulder = { 35, 10, 0 },
		rElbow = { 95, 0, 0 },
		rWrist = { 0, 0, 0 },
		lShoulder = { 50, 12, 0 },
		lElbow = { 20, 0, 0 },
		lWrist = { -60, 0, 0 },
		waist = { -6, -8, 0 },
	},
	yaw = -8,
}

-- The upper body of a shot: leaning back by `lean` (+ back) and turned `extra` degrees past the rig's side-on yaw.
local function body(rig: ShotRig, lean: number, extra: number?): Pose
	return { waist = { lean, rig.yaw + (extra or 0), 0 } }
end

-- Both arms raised by `deg` (a shot at the sky, a bow lifted to the clouds).
local function lifted(pose: Pose, deg: number): Pose
	local out = table.clone(pose)
	for _, joint in { "lShoulder", "rShoulder" } do
		local v = pose[joint]
		if v then
			out[joint] = { v[1] + deg, v[2], v[3] }
		end
	end
	return out
end

-- The drawing elbow a little tighter (the tremble of a held draw).
local function tremble(pose: Pose, deg: number): Pose
	local v = pose.rElbow or { 0, 0, 0 }
	return merge(pose, { rElbow = { v[1] + deg, v[2], v[3] } })
end

-- The crossbow variant of a shot built by `build` (and of its waves, `hits`).
local function crossbowOf(build: (ShotRig) -> { Key }, hits: number?): Variant
	return variant({ weapon = "crossbow", hits = hits, keys = build(CROSSBOW) })
end

-- Aimed Shot: a long draw to the cheek (0.4), a still moment with the elbow trembling, the release exactly at the
-- server's release (0.58), the right hand thrown back behind the ear (0.66).
-- The whole body stands side-on (root turned 30° right, the chest turned back so the weapon still aims at the target).
local SIDE_ON: Pose = { root = { 0, -30, 0, 0 } }
local function aimedShotKeys(rig: ShotRig): { Key }
	return {
		k(0.4, merge(rig.full, body(rig, 0, 30), SIDE_ON), "out"),
		k(0.48, merge(tremble(rig.full, 3), body(rig, 0, 30), SIDE_ON), "inOut"),
		k(0.55, merge(rig.full, body(rig, 0, 30), SIDE_ON), "inOut"),
		k(0.58, merge(rig.loose, body(rig, 3, 30), SIDE_ON), "out"),
		k(0.66, merge(rig.after, body(rig, 4, 30), SIDE_ON), "out"),
	}
end
motions.aimedShot = {
	keys = aimedShotKeys(BOW),
	recover = 0.3,
	release = 0.58,
	lock = true,
	variants = { crossbowOf(aimedShotKeys) },
}

-- Double Shot: quick draws without the full stretch; each arrow leaves at its server shot (release 0.16, then every
-- `interval` 0.15: 0.31, 0.46 with 5A), the right hand at the quiver (a crossbow: the crank) between two shots.
local DOUBLE_STEP = 0.15 -- seconds between two arrows (Data/Skills/Hunter doubleShot interval)
local function doubleShotKeys(shots: number): (ShotRig) -> { Key }
	return function(rig: ShotRig): { Key }
		local keys = { k(0.12, rig.full, "out"), k(0.16, rig.loose, "out") }
		local last = 0.16
		for shot = 2, shots do
			last = 0.16 + (shot - 1) * DOUBLE_STEP
			table.insert(keys, k(last - 0.09, rig.reach, "out"))
			table.insert(keys, k(last - 0.04, rig.full, "out"))
			table.insert(keys, k(last, rig.loose, "out"))
		end
		table.insert(keys, k(last + 0.08, rig.after, "out"))
		return keys
	end
end
motions.doubleShot = {
	keys = doubleShotKeys(2)(BOW),
	recover = 0.25,
	release = 0.16,
	variants = {
		crossbowOf(doubleShotKeys(3), 3),
		crossbowOf(doubleShotKeys(2)),
		variant({ hits = 3, keys = doubleShotKeys(3)(BOW) }),
	},
}

-- Disengage: a crouch and a backflip (the server moves the body back at once), landing crouched with the bow already
-- raised at the enemy (0.5).
motions.disengage = {
	keys = {
		k(
			0.08,
			merge(crouch(0.8), { rShoulder = { -40, 0, 10 }, lShoulder = { -40, 0, -10 }, waist = { -10, 0, 0 } }),
			"out"
		),
		k(
			0.25,
			merge(air(2.4, 1.3), { root = { 180, 0, 0, 2.6 }, rShoulder = { 120, 0, 20 }, lShoulder = { 120, 0, -20 } }),
			"linear"
		),
		k(
			0.42,
			merge(air(0.6, 1), { root = { 360, 0, 0, 0.6 }, rShoulder = { 60, 0, 30 }, lShoulder = { 60, 0, -30 } }),
			"linear"
		),
		k(
			0.52,
			merge(crouch(0.8), {
				root = { 360, 0, 0, -0.7 },
				rShoulder = { 70, -30, 20 },
				rElbow = { 90, 0, 0 },
				lShoulder = { 82, 25, 0 },
				lElbow = { 0, 0, 0 },
				lWrist = { -60, 0, 0 },
				waist = { 0, -20, 0 },
			}),
			"out"
		),
	},
	recover = 0.25,
	hit = 0.05,
	land = 0.5,
}

-- Arrow Rain: the bow aimed high at the sky, the body leaning back, the release at the event (0.3) and the eyes up.
local function arrowRainKeys(rig: ShotRig): { Key }
	return {
		k(0.2, merge(STAND, lifted(rig.aim, 70), body(rig, 22, 8), { root = { 6, 0, 0, 0 } }), "out"),
		k(0.27, merge(STAND, lifted(rig.full, 75), body(rig, 26, 8), { root = { 7, 0, 0, 0 } }), "inOut"),
		k(0.3, merge(STAND, lifted(rig.loose, 75), body(rig, 28, 8), { root = { 7, 0, 0, 0 } }), "out"),
		k(0.42, merge(STAND, lifted(rig.after, 70), body(rig, 24, 8), { root = { 5, 0, 0, 0 } }), "out"),
	}
end
motions.arrowRain = {
	keys = arrowRainKeys(BOW),
	recover = 0.3,
	release = 0.3,
	hit = 0.3,
	variants = { crossbowOf(arrowRainKeys) },
}

-- Venom Arrow: the arrow dipped low at the quiver in a crouch (0.14), the crouched draw and the release (0.36).
local function venomArrowKeys(rig: ShotRig): { Key }
	return {
		k(
			0.14,
			merge(crouch(0.5), rig.aim, { rShoulder = { -25, 0, 20 }, rElbow = { 40, 0, 0 }, waist = { -10, -10, 0 } }),
			"out"
		),
		k(0.3, merge(crouch(0.5), rig.full), "out"),
		k(0.36, merge(crouch(0.5), rig.loose), "out"),
		k(0.44, merge(crouch(0.45), rig.after), "out"),
	}
end
motions.venomArrow = {
	keys = venomArrowKeys(BOW),
	recover = 0.3,
	release = 0.36,
	variants = { crossbowOf(venomArrowKeys) },
}

-- Frost Trap: a kneel, the trap laid on the ground: the palm touches the ground at the set (0.35), then up.
motions.frostTrap = {
	keys = {
		k(
			0.2,
			merge(
				KNEEL,
				{ rShoulder = { 60, 0, 10 }, rElbow = { 35, 0, 0 }, lShoulder = { 30, 0, -20 }, waist = { -22, 0, 0 } }
			),
			"out"
		),
		k(
			0.35,
			merge(KNEEL, {
				rShoulder = { 38, 0, 8 },
				rElbow = { 8, 0, 0 },
				rWrist = { 20, 0, 0 },
				lShoulder = { 35, 0, -20 },
				waist = { -32, 0, 0 },
			}),
			"in"
		),
		k(
			0.5,
			merge(
				KNEEL,
				{ rShoulder = { 45, 0, 10 }, rElbow = { 20, 0, 0 }, lShoulder = { 35, 0, -20 }, waist = { -26, 0, 0 } }
			)
		),
	},
	recover = 0.3,
	hit = 0.35,
	lock = true,
}

-- Piercing Arrow (Marksman): a wide stance side-on, the draw brought down from over the head to the line (0.36), a heavy
-- release with the shoulders kicked back (0.4). A heavy crossbow shoots kneeling.
local WIDE_STANCE: Pose = {
	root = { 0, -30, 0, -0.4 },
	rHip = { 10, 0, 18 },
	lHip = { 10, 0, -18 },
	rKnee = { 25 },
	lKnee = { 25 },
}
local function piercingKeys(stance: Pose, turn: number): (ShotRig) -> { Key }
	-- `turn` = the chest turned back by the stance's own turn, so the weapon still aims at the target
	return function(rig: ShotRig): { Key }
		return {
			k(0.2, merge(lifted(rig.aim, 50), stance, body(rig, 10, turn)), "out"),
			k(0.36, merge(rig.full, stance, body(rig, -4, turn)), "inOut"),
			k(0.4, merge(rig.loose, stance, body(rig, 8, turn)), "out"),
			k(0.52, merge(rig.after, stance, body(rig, 6, turn)), "out"),
		}
	end
end
motions.piercingArrow = {
	keys = piercingKeys(WIDE_STANCE, 30)(BOW),
	recover = 0.35,
	hit = 0.4,
	release = 0.4,
	lock = true,
	variants = { crossbowOf(piercingKeys(KNEEL, 0)) },
}

-- Hunter's Mark (Scout): the left arm straight and high at the prey, the right hand at the eye (0.22), a short nod.
local MARK_POINT: Pose = {
	lShoulder = { 110, 20, 0 },
	lElbow = { 0, 0, 0 },
	lWrist = { 0, 0, 0 },
	rShoulder = { 125, 25, 0 },
	rElbow = { 135, 0, 0 },
	waist = { 0, -15, 0 },
}
motions.huntersMark = {
	keys = {
		k(0.22, merge(STAND, MARK_POINT), "out"),
		k(0.32, merge(STAND, MARK_POINT, { waist = { -8, -15, 0 }, root = { -4, 0, 0, 0 } }), "inOut"),
		k(0.5, merge(STAND, MARK_POINT, { lShoulder = { 106, 20, 0 } })),
	},
	recover = 0.25,
	hit = 0.22,
}

-- Volley: drawn to the left (0.18), the first arrow at the event (0.22), then the body turns right while the arrows
-- fly (the server's arrows every 0.06 s: the turn ends with the last one, 0.64 for 7, 0.70 for 8 with 5A).
local VOLLEY_STEP = 0.06 -- seconds between two arrows of the server (Offense.cone)
local function volleyKeys(arrows: number): (ShotRig) -> { Key }
	return function(rig: ShotRig): { Key }
		local last = 0.22 + VOLLEY_STEP * arrows
		return {
			k(0.18, merge(rig.full, body(rig, 0, 15), { root = { 0, 25, 0, 0 } }), "out"),
			k(0.22, merge(rig.loose, body(rig, 2, 12), { root = { 0, 20, 0, 0 } }), "out"),
			k(last, merge(rig.loose, body(rig, 2, -22), { root = { 0, -25, 0, 0 } }), "linear"),
			k(last + 0.1, merge(rig.after, body(rig, 3, -24), { root = { 0, -27, 0, 0 } }), "out"),
		}
	end
end
motions.volley = {
	keys = volleyKeys(7)(BOW),
	recover = 0.3,
	release = 0.22,
	hit = 0.22,
	variants = {
		crossbowOf(volleyKeys(8), 8),
		crossbowOf(volleyKeys(7)),
		variant({ hits = 8, keys = volleyKeys(8)(BOW) }),
	},
}

-- Camouflage: a crouch, the cloak pulled across the face (0.2), still.
motions.camouflage = {
	keys = {
		k(
			0.2,
			merge(crouch(0.85), {
				rShoulder = { 70, 55, 0 },
				rElbow = { 115, 0, 0 },
				lShoulder = { 70, -55, 0 },
				lElbow = { 115, 0, 0 },
				waist = { -18, 0, 0 },
			}),
			"out"
		),
		k(
			0.5,
			merge(crouch(0.9), {
				rShoulder = { 72, 55, 0 },
				rElbow = { 118, 0, 0 },
				lShoulder = { 72, -55, 0 },
				lElbow = { 118, 0, 0 },
				waist = { -20, 0, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.2,
}

-- Storm Arrow (Marksman): the arrow raised to the sky to catch the storm (0.25), the full draw forward, a held breath,
-- the release exactly at the server's release (0.58).
local function stormArrowKeys(rig: ShotRig): { Key }
	-- leaning into the shot over the forward right leg (unlike Aimed Shot's still, side-on stance)
	local low: Pose = merge(lunge(0.9), { root = { -5, 0, 0, -0.45 } })
	return {
		k(0.25, merge(STAND, lifted(rig.aim, 70), body(rig, 18, 18)), "out"),
		k(0.5, merge(rig.full, body(rig, 0, 0), low), "inOut"),
		k(0.55, merge(tremble(rig.full, 2), body(rig, 0, 0), low), "inOut"),
		k(0.58, merge(rig.loose, body(rig, 6, 0), low), "out"),
		k(0.68, merge(rig.after, body(rig, 5, 0), low), "out"),
	}
end
motions.stormArrow = {
	keys = stormArrowKeys(BOW),
	recover = 0.35,
	release = 0.58,
	lock = true,
	variants = { crossbowOf(stormArrowKeys) },
}

-- S77 (ROZWOJ 11.3-11.5): path skills of the Hunter.
-- Draw a Bead (Marksman): the bow levelled at the prey and the string to the eye at the mark (0.25), then a slow draw
-- held still (0.55-0.7). Unlike Hunter's Mark the weapon aims (Mark: a bare pointing arm and a nod).
local function drawBeadKeys(rig: ShotRig): { Key }
	return {
		k(0.25, merge(STAND, rig.aim, body(rig, 0, 4)), "out"),
		k(0.55, merge(STAND, rig.full, body(rig, 0, -4)), "inOut"),
		k(0.7, merge(STAND, tremble(rig.full, 2), body(rig, 0, -4))),
	}
end
motions.drawBead = {
	keys = drawBeadKeys(BOW),
	recover = 0.3,
	hit = 0.25,
	variants = { crossbowOf(drawBeadKeys) },
}

-- Heartseeker (Marksman, capstone): kneeling, a full draw held for the whole aim (the loop lasts castTime, its ends the
-- same pose so the loop does not jump; a breath of the elbow in the middle), the release 0.02 s after the loop's end,
-- when the server's shot comes. No hit, no release, no lock (moving cancels the aim; the pin and the S77 test).
local function heartseekerKeys(rig: ShotRig): { Key }
	return {
		k(0.3, merge(KNEEL, rig.aim, body(rig, -4, 0)), "out"),
		k(0.5, merge(KNEEL, rig.full, body(rig, -4, -2)), "inOut"),
		k(0.65, merge(KNEEL, tremble(rig.full, 2), body(rig, -4, -3)), "inOut"),
		k(0.8, merge(KNEEL, rig.full, body(rig, -4, -2)), "inOut"),
		k(0.82, merge(KNEEL, rig.loose, body(rig, 6, -2)), "out"),
		k(0.92, merge(KNEEL, rig.after, body(rig, 5, -2)), "out"),
	}
end
motions.heartseeker = {
	keys = heartseekerKeys(BOW),
	recover = 0.4,
	loop = { from = 0.5, to = 0.8 },
	variants = { crossbowOf(heartseekerKeys) },
}

-- Venom Snare (Trapper): kneeling, the snare thrown underhand: it leaves the hand at 0.14 (SkillVfx toss) and lands on
-- the point at the set (0.34), the arm following through.
motions.venomSnare = {
	keys = {
		k(
			0.08,
			merge(KNEEL, {
				rShoulder = { -35, 0, 15 },
				rElbow = { 45, 0, 0 },
				lShoulder = { 30, 0, -20 },
				waist = { -15, 10, 0 },
			}),
			"out"
		),
		k(
			0.14,
			merge(KNEEL, {
				rShoulder = { 80, 0, 10 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 30, 0, -20 },
				waist = { -25, -10, 0 },
			}),
			"out"
		),
		k(
			0.34,
			merge(
				KNEEL,
				{ rShoulder = { 65, 0, 10 }, rElbow = { 15, 0, 0 }, lShoulder = { 32, 0, -20 }, waist = { -24, -8, 0 } }
			),
			"inOut"
		),
		k(
			0.5,
			merge(
				KNEEL,
				{ rShoulder = { 55, 0, 10 }, rElbow = { 20, 0, 0 }, lShoulder = { 32, 0, -20 }, waist = { -20, -6, 0 } }
			)
		),
	},
	recover = 0.3,
	hit = 0.34,
	lock = true,
}

-- Snarefield (Trapper, capstone): crouched, the snares scattered in a sweep from right to left (0.15-0.45); they leave
-- the hand one by one along the sweep (SkillVfx toss 0.2-0.4) and land on the ring at the set (0.45).
motions.snarefield = {
	keys = {
		k(
			0.15,
			merge(crouch(0.8), {
				rShoulder = { 40, 40, 0 },
				rElbow = { 60, 0, 0 },
				lShoulder = { 30, 0, -20 },
				waist = { -20, 30, 0 },
				root = { 0, 25, 0, -0.72 },
			}),
			"out"
		),
		k(
			0.45,
			merge(crouch(0.8), {
				rShoulder = { 60, -60, 0 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 30, 0, -20 },
				waist = { -20, -40, 0 },
				root = { 0, -25, 0, -0.72 },
			}),
			"linear"
		),
		k(
			0.6,
			merge(crouch(0.8), {
				rShoulder = { 45, -50, 0 },
				rElbow = { 15, 0, 0 },
				lShoulder = { 30, 0, -20 },
				waist = { -18, -35, 0 },
				root = { 0, -20, 0, -0.72 },
			})
		),
	},
	recover = 0.35,
	hit = 0.45,
	lock = true,
}

-- Falcon (Scout): the left forearm raised (0.15), the bird released upwards (0.35), the arm left up a moment.
motions.falcon = {
	keys = {
		k(
			0.15,
			merge(STAND, {
				lShoulder = { 60, 0, -10 },
				lElbow = { 95, 0, 0 },
				rShoulder = { 20, 0, 10 },
				rElbow = { 10, 0, 0 },
				waist = { 0, -10, 0 },
			}),
			"out"
		),
		k(
			0.35,
			merge(STAND, {
				lShoulder = { 165, 10, -10 },
				lElbow = { 10, 0, 0 },
				rShoulder = { 20, 0, 10 },
				rElbow = { 10, 0, 0 },
				waist = { 8, -10, 0 },
			}),
			"out"
		),
		k(
			0.6,
			merge(STAND, {
				lShoulder = { 150, 10, -10 },
				lElbow = { 15, 0, 0 },
				rShoulder = { 20, 0, 10 },
				rElbow = { 10, 0, 0 },
				waist = { 5, -10, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.35,
}

-- The Drive (Scout, capstone): the bow raised to the sky, a sweep from the outside in (the drive), the release (0.38).
-- Unlike Arrow Rain the body turns through the sweep and the arrows land on the rim (SkillVfx rim).
local function driveKeys(rig: ShotRig): { Key }
	return {
		k(0.2, merge(STAND, lifted(rig.aim, 75), body(rig, 25, 43), { root = { 6, 25, 0, 0 } }), "out"),
		k(0.38, merge(STAND, lifted(rig.loose, 75), body(rig, 28, -17), { root = { 6, -25, 0, 0 } }), "linear"),
		k(0.5, merge(STAND, lifted(rig.after, 73), body(rig, 26, -14), { root = { 5, -22, 0, 0 } })),
	}
end
motions.drive = {
	keys = driveKeys(BOW),
	recover = 0.3,
	release = 0.38,
	hit = 0.38,
	variants = { crossbowOf(driveKeys) },
}

-- S144 (DESIGN-18 §6.3): the Hunter pools' new skills from the shooting rigs (S115: one function per shot, the crossbow
-- variant through crossbowOf; the Crossbow's skills always play it, the Bow's with a crossbow only in AnimLab); the look
-- apart is their SkillVfx. A full motion pass comes with W03-W07.
-- Heavy Bolt (the Crossbow's S1): a braced stance with the left foot forward, a slow full draw (0.36) and a heavy
-- release with the shoulders kicked back (0.42, the server's release).
local BRACED: Pose = {
	root = { 0, 0, 0, -0.2 },
	rHip = { -8, 0, 6 },
	lHip = { 18, 0, -6 },
	rKnee = { 12 },
	lKnee = { 18 },
}
local function heavyBoltKeys(rig: ShotRig): { Key }
	return {
		k(0.18, merge(rig.aim, BRACED, body(rig, 4, 0)), "out"),
		k(0.36, merge(rig.full, BRACED, body(rig, 0, 0)), "inOut"),
		-- W30: the heavy kick throws the shoulders back and sinks the brace (its own silhouette against Double Shot)
		k(0.42, merge(rig.loose, BRACED, body(rig, 18, 0), { root = { -10, 0, 0, -0.45 } }), "out"),
		k(0.54, merge(rig.after, BRACED, body(rig, 10, 0)), "out"),
	}
end
motions.heavyBolt = {
	keys = heavyBoltKeys(BOW),
	recover = 0.3,
	release = 0.42,
	lock = true,
	variants = { crossbowOf(heavyBoltKeys) },
}

-- Pinning Shot (the Bow's K1): a short step forward with the weapon aimed down at the target's feet, a quick draw and
-- the release at 0.28.
local function pinningShotKeys(rig: ShotRig): { Key }
	local step: Pose = lunge(0.4)
	return {
		k(0.16, merge(lifted(rig.aim, -18), step, body(rig, -6, 6)), "out"),
		k(0.24, merge(lifted(rig.full, -20), step, body(rig, -8, 6)), "inOut"),
		k(0.28, merge(lifted(rig.loose, -20), step, body(rig, -4, 6)), "out"),
		k(0.38, merge(lifted(rig.after, -16), step, body(rig, -2, 6)), "out"),
	}
end
motions.pinningShot = {
	keys = pinningShotKeys(BOW),
	recover = 0.25,
	release = 0.28,
	variants = { crossbowOf(pinningShotKeys) },
}

-- Wind Step (the Bow's O1): a light skip to the left with the legs crossing, the weapon held low (the buff at 0.15),
-- landing crouched and turned toward the enemy (0.32).
motions.windstep = {
	keys = {
		k(
			0.15,
			merge(air(0.8, 0.6), {
				root = { 0, 18, -10, 0.8 },
				rShoulder = { 30, 0, 40 },
				rElbow = { 20, 0, 0 },
				lShoulder = { 45, 20, -15 },
				lElbow = { 10, 0, 0 },
				lWrist = { -60, 0, 0 },
				waist = { -6, 14, 0 },
			}),
			"out"
		),
		k(
			0.32,
			merge(crouch(0.4), {
				root = { 0, 28, 6, -0.36 },
				rShoulder = { 25, 0, 35 },
				rElbow = { 30, 0, 0 },
				lShoulder = { 60, 22, -10 },
				lElbow = { 5, 0, 0 },
				lWrist = { -60, 0, 0 },
				waist = { 0, -20, 0 },
			}),
			"in"
		),
		k(
			0.45,
			merge(STAND, {
				rShoulder = { 20, 0, 25 },
				rElbow = { 25, 0, 0 },
				lShoulder = { 55, 20, -10 },
				lElbow = { 5, 0, 0 },
				lWrist = { -60, 0, 0 },
				waist = { 0, -12, 0 },
			})
		),
	},
	recover = 0.25,
	hit = 0.15,
	land = 0.32,
}

-- Net Shot (the Crossbow's K2): the weapon raised for a high arc of the net (the release and the landing at 0.3, the
-- body leaning back a little; lower than Arrow Rain's shot at the sky).
local function netShotKeys(rig: ShotRig): { Key }
	return {
		k(0.18, merge(STAND, lifted(rig.aim, 35), body(rig, 10, 10)), "out"),
		k(0.27, merge(STAND, lifted(rig.full, 38), body(rig, 12, 10)), "inOut"),
		k(0.3, merge(STAND, lifted(rig.loose, 40), body(rig, 16, 10)), "out"),
		k(0.42, merge(STAND, lifted(rig.after, 34), body(rig, 12, 10)), "out"),
	}
end
motions.netShot = {
	keys = netShotKeys(BOW),
	recover = 0.3,
	release = 0.3,
	hit = 0.3,
	variants = { crossbowOf(netShotKeys) },
}

-- Executioner's Bolt (the Crossbow's S3): kneeling, a deliberate aim with the elbow trembling (0.44), the release at
-- 0.5 with a hard recoil.
local function deadlyBoltKeys(rig: ShotRig): { Key }
	return {
		k(0.25, merge(KNEEL, rig.aim, body(rig, -2, 6)), "out"),
		k(0.44, merge(KNEEL, tremble(rig.full, 2), body(rig, -4, 4)), "inOut"),
		k(0.5, merge(KNEEL, rig.loose, body(rig, 10, 4), { root = { -8, 0, 0, -1.3 } }), "out"),
		k(0.62, merge(KNEEL, rig.after, body(rig, 6, 4)), "out"),
	}
end
motions.deadlyBolt = {
	keys = deadlyBoltKeys(BOW),
	recover = 0.35,
	release = 0.5,
	lock = true,
	variants = { crossbowOf(deadlyBoltKeys) },
}

-- Mage ---------------------------------------------------------------------------------------------------------

-- S115: a bolt leaves the tip of the weapon pointed at the target. A wand (one hand, a flick of the wrist; the angles
-- of the basic attack, Data/AttackMotions wand: the tip at the target with the wrist at -60) or a staff upright in the
-- right hand, the left hand guiding the spell (Data/AttackMotions staff): `back` = the wind-up, `point` = the tip at the
-- target (the release), `after` = the wrist finishing.
export type CastRig = { back: Pose, point: Pose, after: Pose }

local WAND: CastRig = {
	back = { rShoulder = { 50, 0, 20 }, rElbow = { 80, 0, 0 }, rWrist = { -20, 0, 0 }, waist = { 0, -12, 0 } },
	point = { rShoulder = { 80, 0, 0 }, rElbow = { 0, 0, 0 }, rWrist = { -60, 0, 0 }, waist = { -4, 10, 0 } },
	after = { rShoulder = { 83, 0, -2 }, rElbow = { 0, 0, 0 }, rWrist = { -50, 0, 0 }, waist = { -4, 12, 0 } },
}
local STAFF: CastRig = {
	back = {
		rShoulder = { 35, 0, 15 },
		rElbow = { 60, 0, 0 },
		rWrist = { -10, 0, 0 },
		lShoulder = { 30, 0, 20 },
		lElbow = { 70, 0, 0 },
		waist = { 2, -12, 0 },
	},
	point = {
		rShoulder = { 25, 0, 5 },
		rElbow = { 0, 0, 0 },
		rWrist = { -60, 0, 0 },
		lShoulder = { 20, 0, 25 },
		lElbow = { 30, 0, 0 },
		waist = { -6, 8, 0 },
	},
	after = {
		rShoulder = { 28, 0, 5 },
		rElbow = { 0, 0, 0 },
		rWrist = { -55, 0, 0 },
		lShoulder = { 22, 0, 25 },
		lElbow = { 30, 0, 0 },
		waist = { -6, 10, 0 },
	},
}

-- Fire Bolt (firebolt; Arcane Bolt before S142): a quick flick of the weapon, the tip at the target at the release
-- (0.16); with 10B a second flick for the second bolt (0.31 = release + interval 0.15). A staff pushes its tip instead.
local BOLT_STEP = 0.15 -- seconds between two bolts (Offense.projectile default interval)
local function fireboltKeys(rig: CastRig, bolts: number): { Key }
	local keys = { k(0.1, rig.back, "out"), k(0.16, rig.point, "out") }
	local last = 0.16
	for bolt = 2, bolts do
		last = 0.16 + (bolt - 1) * BOLT_STEP
		table.insert(keys, k(last - 0.07, rig.back, "out"))
		table.insert(keys, k(last, rig.point, "out"))
	end
	table.insert(keys, k(last + 0.08, rig.after, "out"))
	return keys
end
motions.firebolt = {
	keys = fireboltKeys(WAND, 1),
	recover = 0.22,
	release = 0.16,
	variants = {
		variant({ weapon = "staff", hits = 2, keys = fireboltKeys(STAFF, 2) }),
		variant({ weapon = "staff", keys = fireboltKeys(STAFF, 1) }),
		variant({ hits = 2, keys = fireboltKeys(WAND, 2) }),
	},
}

-- Ice Shard: the hands brought together at the chest (0.18, the shard grows between them), both pushed forward at
-- the release (0.26), held a moment.
motions.iceShard = {
	keys = {
		k(0.18, {
			rShoulder = { 50, 35, 0 },
			rElbow = { 105, 0, 0 },
			lShoulder = { 50, -35, 0 },
			lElbow = { 105, 0, 0 },
			waist = { 4, 0, 0 },
		}, "out"),
		k(0.26, {
			rShoulder = { 95, 10, 0 },
			rElbow = { 0, 0, 0 },
			lShoulder = { 95, -10, 0 },
			lElbow = { 0, 0, 0 },
			waist = { -8, 0, 0 },
		}, "out"),
		k(0.34, {
			rShoulder = { 92, 12, 0 },
			rElbow = { 5, 0, 0 },
			lShoulder = { 92, -12, 0 },
			lElbow = { 5, 0, 0 },
			waist = { -9, 0, 0 },
		}, "out"),
	},
	recover = 0.25,
	release = 0.26,
}

-- Blink: a short tense hunch before vanishing (0.1), appearing leaning a little forward.
motions.blink = {
	keys = {
		k(
			0.1,
			merge(crouch(0.4), {
				rShoulder = { 40, 40, 0 },
				rElbow = { 100, 0, 0 },
				lShoulder = { 40, -40, 0 },
				lElbow = { 100, 0, 0 },
				waist = { -22, 0, 0 },
			}),
			"out"
		),
		k(0.2, merge(STAND, { rShoulder = { 20, 0, 40 }, lShoulder = { 20, 0, -40 }, waist = { -6, 0, 0 } }), "out"),
	},
	recover = 0.2,
	hit = 0.1,
}

-- Fireball: energy gathered at the hip with both hands (0.28), pushed forward in a lunge at the release (0.38), the
-- orb leaving the hands. A staff keeps the staff upright in the right hand and pushes its tip with the left palm.
local FIREBALL_GATHER: Pose = merge(STAND, {
	rShoulder = { 30, 20, 35 },
	rElbow = { 95, 0, 0 },
	lShoulder = { 35, -40, 10 },
	lElbow = { 95, 0, 0 },
	waist = { 0, -28, 0 },
	root = { 0, -8, 0, -0.2 },
})
local FIREBALL_PUSH: Pose = merge(lunge(0.5), {
	rShoulder = { 92, 5, 0 },
	rElbow = { 0, 0, 0 },
	lShoulder = { 92, -5, 0 },
	lElbow = { 0, 0, 0 },
	waist = { -6, 18, 0 },
})
local FIREBALL_AFTER: Pose =
	merge(lunge(0.55), { rShoulder = { 88, 6, 0 }, lShoulder = { 88, -6, 0 }, waist = { -8, 22, 0 } })
local STAFF_HOLD: Pose = { rShoulder = { 30, 0, 15 }, rElbow = { 60, 0, 0 }, rWrist = { -10, 0, 0 } }
local STAFF_TIP: Pose = { rShoulder = { 60, 0, 5 }, rElbow = { 0, 0, 0 }, rWrist = { -60, 0, 0 } }
motions.fireball = {
	keys = {
		k(0.28, FIREBALL_GATHER, "inOut"),
		k(0.38, FIREBALL_PUSH, "out"),
		k(0.46, FIREBALL_AFTER, "out"),
	},
	recover = 0.3,
	release = 0.38,
	hit = 0.38,
	variants = {
		variant({
			weapon = "staff",
			keys = {
				k(0.28, merge(FIREBALL_GATHER, STAFF_HOLD), "inOut"),
				k(0.38, merge(FIREBALL_PUSH, STAFF_TIP), "out"),
				k(0.46, merge(FIREBALL_AFTER, STAFF_TIP), "out"),
			},
		}),
	},
}

-- Chain Lightning: the arm thrown back high (0.18), hurled forward with the fingers spread at the release (0.26), the
-- arm running on down.
motions.chainLightning = {
	keys = {
		k(
			0.18,
			{ rShoulder = { 145, 0, 40 }, rElbow = { 45, 0, 0 }, lShoulder = { 60, 0, -20 }, waist = { 6, -22, 0 } },
			"out"
		),
		k(
			0.26,
			{ rShoulder = { 88, 15, 0 }, rElbow = { 0, 0, 0 }, lShoulder = { 20, 0, -20 }, waist = { -8, 24, 0 } },
			"in"
		),
		k(
			0.34,
			{ rShoulder = { 70, 18, 0 }, rElbow = { 5, 0, 0 }, lShoulder = { 18, 0, -20 }, waist = { -10, 28, 0 } },
			"out"
		),
	},
	recover = 0.3,
	release = 0.26,
	hit = 0.26,
}

-- Mana Shield: the arms raised in an arc over the head.
motions.manaShield = {
	keys = {
		k(0.28, {
			rShoulder = { 160, 0, 35 },
			rElbow = { 30, 0, 0 },
			lShoulder = { 160, 0, -35 },
			lElbow = { 30, 0, 0 },
			waist = { 8, 0, 0 },
		}, "out"),
		k(0.6, {
			rShoulder = { 165, 0, 40 },
			rElbow = { 25, 0, 0 },
			lShoulder = { 165, 0, -40 },
			lElbow = { 25, 0, 0 },
			waist = { 10, 0, 0 },
		}),
	},
	recover = 0.3,
	hit = 0.28,
}

-- Frost Nova: arms up, then a deep crouch with the palms slammed to the ground.
motions.frostNova = {
	keys = {
		k(0.16, merge(STAND, { rShoulder = { 150, 0, 25 }, lShoulder = { 150, 0, -25 }, waist = { 10, 0, 0 } }), "out"),
		k(
			0.34,
			merge(crouch(1.2), {
				rShoulder = { 30, 0, 15 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 30, 0, -15 },
				lElbow = { 5, 0, 0 },
				waist = { -38, 0, 0 },
			}),
			"in"
		),
		k(0.5, merge(crouch(1.1), { rShoulder = { 28, 0, 15 }, lShoulder = { 28, 0, -15 }, waist = { -34, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.34,
	lock = true,
}

-- Meteor: both arms raised high for a long call (0.45), highest at the event (0.6: the rock starts falling for the
-- event's `d`), then brought down at the point (0.8).
motions.meteor = {
	keys = {
		k(
			0.45,
			merge(STAND, {
				rShoulder = { 176, 0, 20 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 176, 0, -20 },
				lElbow = { 10, 0, 0 },
				waist = { 20, 0, 0 },
				root = { 4, 0, 0, 0.3 },
			}),
			"inOut"
		),
		k(
			0.6,
			merge(STAND, {
				rShoulder = { 178, 0, 25 },
				rElbow = { 4, 0, 0 },
				lShoulder = { 178, 0, -25 },
				lElbow = { 4, 0, 0 },
				waist = { 24, 0, 0 },
				root = { 5, 0, 0, 0.35 },
			}),
			"inOut"
		),
		k(
			0.8,
			merge(STAND, {
				rShoulder = { 90, 0, 10 },
				rElbow = { 0, 0, 0 },
				lShoulder = { 90, 0, -10 },
				lElbow = { 0, 0, 0 },
				waist = { -10, 0, 0 },
			}),
			"in"
		),
		k(
			0.95,
			merge(STAND, {
				rShoulder = { 82, 0, 10 },
				rElbow = { 4, 0, 0 },
				lShoulder = { 82, 0, -10 },
				lElbow = { 4, 0, 0 },
				waist = { -12, 0, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.6,
	lock = true,
}

-- Thunderstorm (firewall): the weapon raised to the clouds (0.3), the left hand calling them down at the event (0.42).
motions.firewall = {
	keys = {
		k(
			0.3,
			merge(
				STAND,
				{ rShoulder = { 178, 0, 10 }, rElbow = { 5, 0, 0 }, lShoulder = { 120, 0, -40 }, waist = { 14, 0, 0 } }
			),
			"out"
		),
		k(
			0.42,
			merge(
				STAND,
				{ rShoulder = { 175, 0, 8 }, lShoulder = { 45, 0, -30 }, lElbow = { 20, 0, 0 }, waist = { 4, 0, 0 } }
			),
			"in"
		),
		k(
			0.55,
			merge(
				STAND,
				{ rShoulder = { 170, 0, 8 }, lShoulder = { 35, 0, -28 }, lElbow = { 25, 0, 0 }, waist = { 2, 0, 0 } }
			),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.42,
}

-- Evocation (channel): rising off the ground, legs loose, the hands circling. S115: walking (5B channelMove, the cast
-- event's `mv`) keeps the hands circling with the feet on the ground (no lift, no legs: the walk animation moves them).
local function evocationKeys(airborne: boolean): { Key }
	local function at(lift: number, arms: Pose): Pose
		return if airborne then merge(air(lift, 0.4), arms) else arms
	end
	return {
		k(
			0.4,
			at(1, {
				rShoulder = { 60, 0, 40 },
				rElbow = { 60, 0, 0 },
				lShoulder = { 60, 0, -40 },
				lElbow = { 60, 0, 0 },
				waist = { 8, 0, 0 },
			}),
			"inOut"
		),
		k(
			0.8,
			at(1.2, {
				rShoulder = { 100, 30, 20 },
				rElbow = { 40, 0, 0 },
				lShoulder = { 30, -30, -20 },
				lElbow = { 80, 0, 0 },
				waist = { 8, 0, 0 },
			}),
			"inOut"
		),
		k(
			1.2,
			at(1.3, {
				rShoulder = { 60, 0, 40 },
				rElbow = { 60, 0, 0 },
				lShoulder = { 60, 0, -40 },
				lElbow = { 60, 0, 0 },
				waist = { 8, 0, 0 },
			}),
			"inOut"
		),
		k(
			1.6,
			at(1.2, {
				rShoulder = { 30, 30, 20 },
				rElbow = { 80, 0, 0 },
				lShoulder = { 100, -30, -20 },
				lElbow = { 40, 0, 0 },
				waist = { 8, 0, 0 },
			}),
			"inOut"
		),
		k(
			2,
			at(1, {
				rShoulder = { 60, 0, 40 },
				rElbow = { 60, 0, 0 },
				lShoulder = { 60, 0, -40 },
				lElbow = { 60, 0, 0 },
				waist = { 8, 0, 0 },
			}),
			"inOut"
		),
		k(
			2.4,
			if airborne
				then merge(STAND, {
					rShoulder = { 20, 0, 20 },
					rElbow = { 0, 0, 0 },
					lShoulder = { 20, 0, -20 },
					lElbow = { 0, 0, 0 },
					waist = { 0, 0, 0 },
				})
				else {
					rShoulder = { 20, 0, 20 },
					rElbow = { 0, 0, 0 },
					lShoulder = { 20, 0, -20 },
					lElbow = { 0, 0, 0 },
					waist = { 0, 0, 0 },
				},
			"inOut"
		),
	}
end
motions.evocation = {
	keys = evocationKeys(true),
	recover = 0.3,
	hit = 0.4,
	loop = { from = 0.4, to = 2 },
	lock = true,
	variants = { variant({ move = true, keys = evocationKeys(false) }) },
}

-- Elemental Fury (meteorStorm): both arms raised (0.38), then swept down and out across the area in a wide stance at
-- the event (0.55). Unlike Meteor (straight arms, one call) the arms open sideways and the feet stand wide.
local STORM_STANCE: Pose =
	{ root = { -6, 0, 0, -0.3 }, rHip = { 6, 0, 20 }, lHip = { 6, 0, -20 }, rKnee = { 20 }, lKnee = { 20 } }
motions.meteorStorm = {
	keys = {
		k(
			0.38,
			merge(STAND, {
				rShoulder = { 175, 20, 25 },
				lShoulder = { 175, -20, -25 },
				waist = { 18, 0, 0 },
				root = { 4, 0, 0, 0.3 },
			}),
			"inOut"
		),
		k(
			0.55,
			merge(STORM_STANCE, {
				rShoulder = { 70, -50, 30 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 70, 50, -30 },
				lElbow = { 5, 0, 0 },
				waist = { -15, 0, 0 },
			}),
			"in"
		),
		k(
			0.7,
			merge(STORM_STANCE, {
				rShoulder = { 55, -55, 40 },
				lShoulder = { 55, 55, -40 },
				waist = { -12, 0, 0 },
			}),
			"out"
		),
	},
	recover = 0.35,
	hit = 0.55,
	lock = true,
}

-- S80 (ROZWOJ 12.4, 12.5): the four path skills of the Mage.
-- Elemental Vortex: both hands circling at the waist, a short call (the vortex follows the mage).
motions.elementalVortex = {
	keys = {
		k(0.15, {
			rShoulder = { 50, 30, 35 },
			rElbow = { 70, 0, 0 },
			lShoulder = { 50, -30, -35 },
			lElbow = { 70, 0, 0 },
			waist = { 0, 25, 0 },
		}, "out"),
		k(0.3, {
			rShoulder = { 60, -20, 40 },
			rElbow = { 50, 0, 0 },
			lShoulder = { 60, 20, -40 },
			lElbow = { 50, 0, 0 },
			waist = { 0, -25, 0 },
		}, "inOut"),
		k(0.5, {
			rShoulder = { 45, 0, 35 },
			rElbow = { 60, 0, 0 },
			lShoulder = { 45, 0, -35 },
			lElbow = { 60, 0, 0 },
			waist = { 0, 0, 0 },
		}, "inOut"),
	},
	recover = 0.3,
	hit = 0.3,
}

-- Cataclysm: a long call with both arms raised, ended with a crouch and the slammed pose as the circle strikes.
motions.cataclysm = {
	keys = {
		k(
			0.4,
			merge(STAND, {
				rShoulder = { 176, 0, 20 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 176, 0, -20 },
				lElbow = { 10, 0, 0 },
				waist = { 20, 0, 0 },
				root = { 4, 0, 0, 0.3 },
			}),
			"inOut"
		),
		k(
			0.5,
			merge(STAND, {
				rShoulder = { 178, 0, 25 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 178, 0, -25 },
				lElbow = { 5, 0, 0 },
				waist = { 22, 0, 0 },
				root = { 5, 0, 0, 0.35 },
			})
		),
		k(0.6, merge(crouch(0.6), SLAMMED, { waist = { -18, 0, 0 } }), "in"),
		k(0.85, merge(crouch(0.6), SLAMMED, { waist = { -14, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.6,
	lock = true,
}

-- Arcane Discharge (S115, its own silhouette): the weapon held upright before the body in one hand while the left hand
-- draws the orbiting charges to its tip (0.3), then the tip alone thrust at the target with a turn of the upper body
-- at the release (0.4). No gathering at the hip (that is Fireball). A staff is held in both hands, the tip at the
-- target.
local DISCHARGE_DRAW: Pose = merge(STAND, {
	rShoulder = { 70, 0, 8 },
	rElbow = { 50, 0, 0 },
	rWrist = { 0, 0, 0 },
	lShoulder = { 95, -35, 0 },
	lElbow = { 40, 0, 0 },
	waist = { 0, -22, 0 },
	root = { 0, -6, 0, 0 },
})
local DISCHARGE_THRUST: Pose = merge(lunge(0.4), {
	rShoulder = { 90, 8, 0 },
	rElbow = { 0, 0, 0 },
	rWrist = { -60, 0, 0 },
	lShoulder = { 40, 0, -35 },
	lElbow = { 60, 0, 0 },
	waist = { -6, 30, 0 },
})
local DISCHARGE_AFTER: Pose = merge(lunge(0.45), {
	rShoulder = { 88, 10, 0 },
	rElbow = { 0, 0, 0 },
	rWrist = { -55, 0, 0 },
	lShoulder = { 35, 0, -35 },
	lElbow = { 60, 0, 0 },
	waist = { -8, 34, 0 },
})
local BOTH_ON_STAFF: Pose = { lShoulder = { 72, -20, 0 }, lElbow = { 40, 0, 0 } }
motions.arcaneDischarge = {
	keys = {
		k(0.3, DISCHARGE_DRAW, "inOut"),
		k(0.4, DISCHARGE_THRUST, "out"),
		k(0.5, DISCHARGE_AFTER, "out"),
	},
	recover = 0.3,
	release = 0.4,
	hit = 0.4,
	variants = {
		variant({
			weapon = "staff",
			keys = {
				k(0.3, merge(DISCHARGE_DRAW, { rWrist = { -10, 0, 0 } }), "inOut"),
				k(
					0.4,
					merge(DISCHARGE_THRUST, { rShoulder = { 75, 10, 0 }, rElbow = { 20, 0, 0 } }, BOTH_ON_STAFF),
					"out"
				),
				k(
					0.5,
					merge(DISCHARGE_AFTER, { rShoulder = { 73, 12, 0 }, rElbow = { 20, 0, 0 } }, BOTH_ON_STAFF),
					"out"
				),
			},
		}),
	},
}

-- Arcane Torrent: the weapon held in both hands before the chest for the whole beam (no legs: with 5B the mage walks).
-- The loop (0.25-0.95) is pinned by the server's time; the ticks (every 0.5 s) pulse in the ray, not in the arms.
motions.arcaneTorrent = {
	keys = {
		k(0.25, {
			rShoulder = { 85, 25, 0 },
			rElbow = { 30, 0, 0 },
			lShoulder = { 85, -25, 0 },
			lElbow = { 30, 0, 0 },
			waist = { -6, 0, 0 },
		}, "out"),
		k(0.6, {
			rShoulder = { 90, 22, 0 },
			rElbow = { 22, 0, 0 },
			lShoulder = { 90, -22, 0 },
			lElbow = { 22, 0, 0 },
			waist = { -9, 0, 0 },
		}, "inOut"),
		k(0.95, {
			rShoulder = { 85, 25, 0 },
			rElbow = { 30, 0, 0 },
			lShoulder = { 85, -25, 0 },
			lElbow = { 30, 0, 0 },
			waist = { -6, 0, 0 },
		}, "inOut"),
		k(1.3, {
			rShoulder = { 20, 0, 12 },
			rElbow = { 10, 0, 0 },
			lShoulder = { 20, 0, -12 },
			lElbow = { 10, 0, 0 },
			waist = { 0, 0, 0 },
		}, "inOut"),
	},
	recover = 0.3,
	hit = 0.25,
	loop = { from = 0.25, to = 0.95 },
	lock = true,
}

-- S140-S142 (DESIGN-18 §6.1) gave the fire, ice and lightning pools' new skills the S115 motions; W30 (walka-lm) gives
-- every one a body of its own (the server's hit / release / loop times unchanged, tests/fixtures/skill_timing): the
-- anticipation, the blow on the event and a follow-through.

-- Fire ------------------------------------------------------------------------------------------------------------
-- Flame Wave: the palms drawn back to the chest, then both thrust out wide in a lunge at the release (0.26), the cone
-- of fire leaving the spread hands; the arms run on outwards.
motions.flameWave = {
	keys = {
		k(
			0.16,
			merge(crouch(0.3), {
				rShoulder = { 40, 30, 30 },
				rElbow = { 110, 0, 0 },
				lShoulder = { 40, -30, -30 },
				lElbow = { 110, 0, 0 },
				waist = { 4, -20, 0 },
			}),
			"out"
		),
		k(
			0.26,
			merge(lunge(0.6), {
				rShoulder = { 85, -25, 0 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 85, 25, 0 },
				lElbow = { 5, 0, 0 },
				waist = { -10, 0, 0 },
			}),
			"in"
		),
		k(
			0.34,
			merge(lunge(0.65), {
				rShoulder = { 80, -45, 0 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 80, 45, 0 },
				lElbow = { 5, 0, 0 },
				waist = { -12, 0, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	release = 0.26,
	hit = 0.26,
}
-- Ember Shield: the forearms crossed before the chest in a crouch, then flung apart and up as the embers burst round
-- (0.28), the chest open, a little rise on the toes.
motions.emberShield = {
	keys = {
		k(
			0.14,
			merge(crouch(0.3), {
				rShoulder = { 70, 60, 0 },
				rElbow = { 100, 0, 0 },
				lShoulder = { 70, -60, 0 },
				lElbow = { 100, 0, 0 },
				waist = { -10, 0, 0 },
			}),
			"out"
		),
		k(
			0.28,
			merge(STAND, {
				rShoulder = { 60, -50, 40 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 60, 50, -40 },
				lElbow = { 10, 0, 0 },
				waist = { 12, 0, 0 },
				root = { 6, 0, 0, 0.15 },
			}),
			"in"
		),
		k(
			0.6,
			merge(STAND, {
				rShoulder = { 50, -45, 35 },
				rElbow = { 15, 0, 0 },
				lShoulder = { 50, 45, -35 },
				lElbow = { 15, 0, 0 },
				waist = { 6, 0, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.28,
}
-- Pyroblast: a great orb held over the head with both hands while focusing (the loop, castTime), then hurled down at
-- the target in a deep lunge.
local PYRO_HOLD: Pose = merge(STAND, {
	rShoulder = { 165, 10, 20 },
	rElbow = { 60, 0, 0 },
	lShoulder = { 165, -10, -20 },
	lElbow = { 60, 0, 0 },
	waist = { 14, 0, 0 },
	root = { 4, 0, 0, 0.1 },
})
motions.pyroblast = {
	keys = {
		k(0.2, PYRO_HOLD, "out"),
		k(
			0.28,
			merge(PYRO_HOLD, { rShoulder = { 170, 10, 24 }, lShoulder = { 170, -10, -24 }, waist = { 16, 0, 0 } }),
			"inOut"
		),
		k(
			0.38,
			merge(lunge(0.8), {
				rShoulder = { 70, 10, 0 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 70, -10, 0 },
				lElbow = { 5, 0, 0 },
				waist = { -16, 0, 0 },
			}),
			"in"
		),
		k(
			0.46,
			merge(lunge(0.85), { rShoulder = { 55, 10, 0 }, lShoulder = { 55, -10, 0 }, waist = { -18, 0, 0 } }),
			"out"
		),
	},
	recover = 0.3,
	loop = { from = 0.2, to = 0.28 },
}
-- Combustion: the right hand raised by the face, fingers ready to snap, then the fist clenched and pulled down at the
-- event (0.26): the target's burns burst.
motions.combustion = {
	keys = {
		k(0.14, {
			rShoulder = { 120, -20, 0 },
			rElbow = { 110, 0, 0 },
			rWrist = { -30, 0, 0 },
			lShoulder = { 30, 0, -15 },
			waist = { 4, -10, 0 },
		}, "out"),
		k(0.26, {
			rShoulder = { 60, -10, 10 },
			rElbow = { 95, 0, 0 },
			rWrist = { 20, 0, 0 },
			lShoulder = { 25, 0, -20 },
			waist = { -8, 8, 0 },
		}, "in"),
		k(0.34, {
			rShoulder = { 52, -10, 12 },
			rElbow = { 100, 0, 0 },
			rWrist = { 25, 0, 0 },
			lShoulder = { 25, 0, -20 },
			waist = { -10, 10, 0 },
		}, "out"),
	},
	recover = 0.25,
	hit = 0.26,
}
-- Immolate: a dip, then the weapon swept up from below (0.16), the flames rising round the target with it.
motions.immolate = {
	keys = {
		k(
			0.08,
			merge(crouch(0.2), {
				rShoulder = { 20, 0, 20 },
				rElbow = { 60, 0, 0 },
				rWrist = { -10, 0, 0 },
				lShoulder = { 30, 0, -10 },
				waist = { -10, -10, 0 },
			}),
			"out"
		),
		k(
			0.16,
			merge(STAND, {
				rShoulder = { 135, 0, 10 },
				rElbow = { 10, 0, 0 },
				rWrist = { -50, 0, 0 },
				lShoulder = { 40, 0, -20 },
				waist = { 8, 10, 0 },
				root = { 2, 0, 0, 0.15 },
			}),
			"in"
		),
		k(
			0.24,
			merge(STAND, {
				rShoulder = { 145, 0, 12 },
				rElbow = { 10, 0, 0 },
				rWrist = { -55, 0, 0 },
				lShoulder = { 40, 0, -20 },
				waist = { 10, 12, 0 },
			}),
			"out"
		),
	},
	recover = 0.22,
	hit = 0.16,
}

-- Ice -------------------------------------------------------------------------------------------------------------
-- Hailstorm: both hands raised with the fingers spread, then flung down and apart over the circle (0.42) in a crouch.
motions.hailstorm = {
	keys = {
		k(
			0.28,
			merge(STAND, {
				rShoulder = { 170, 0, 40 },
				rElbow = { 20, 0, 0 },
				lShoulder = { 170, 0, -40 },
				lElbow = { 20, 0, 0 },
				waist = { 16, 0, 0 },
			}),
			"out"
		),
		k(
			0.42,
			merge(crouch(0.4), {
				rShoulder = { 95, 0, 55 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 95, 0, -55 },
				lElbow = { 10, 0, 0 },
				waist = { -12, 0, 0 },
			}),
			"in"
		),
		k(
			0.55,
			merge(crouch(0.45), { rShoulder = { 80, 0, 60 }, lShoulder = { 80, 0, -60 }, waist = { -14, 0, 0 } }),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.42,
}
-- Ice Barrier: a kneel with the palms at the ground drawing the frost up, then the forearms crossed before the face as
-- the ice closes round (0.28).
motions.iceBarrier = {
	keys = {
		k(
			0.14,
			merge(crouch(0.6), {
				rShoulder = { 30, 0, 10 },
				rElbow = { 20, 0, 0 },
				lShoulder = { 30, 0, -10 },
				lElbow = { 20, 0, 0 },
				waist = { -25, 0, 0 },
			}),
			"out"
		),
		k(
			0.28,
			merge(crouch(0.15), {
				rShoulder = { 110, 40, 0 },
				rElbow = { 70, 0, 0 },
				lShoulder = { 110, -40, 0 },
				lElbow = { 70, 0, 0 },
				waist = { 4, 0, 0 },
			}),
			"in"
		),
		k(
			0.6,
			merge(STAND, {
				rShoulder = { 105, 40, 0 },
				rElbow = { 75, 0, 0 },
				lShoulder = { 105, -40, 0 },
				lElbow = { 75, 0, 0 },
				waist = { 2, 0, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.28,
}
-- Glacial Spike: the spike cocked behind the shoulder like a javelin, the left arm aiming, held while focusing (the
-- loop, castTime), then thrown in a lunge.
local SPIKE_COCK: Pose = merge(STAND, {
	rShoulder = { 150, -10, 35 },
	rElbow = { 80, 0, 0 },
	lShoulder = { 90, 20, 0 },
	lElbow = { 0, 0, 0 },
	waist = { 8, -30, 0 },
	root = { 0, -12, 0, 0 },
	rHip = { -10, 0, 4 },
	lHip = { 20, 0, -4 },
})
motions.glacialSpike = {
	keys = {
		k(0.18, SPIKE_COCK, "out"),
		k(0.26, merge(SPIKE_COCK, { rShoulder = { 156, -10, 38 }, waist = { 10, -32, 0 } }), "inOut"),
		k(
			0.34,
			merge(lunge(0.7), {
				rShoulder = { 80, 20, 0 },
				rElbow = { 0, 0, 0 },
				lShoulder = { 30, 0, -25 },
				lElbow = { 10, 0, 0 },
				waist = { -12, 28, 0 },
			}),
			"in"
		),
	},
	recover = 0.25,
	loop = { from = 0.18, to = 0.26 },
}
-- Frozen Orb: the orb swung low behind the hip and bowled forward along the ground in a lunge (release 0.38).
motions.frozenOrb = {
	keys = {
		k(
			0.26,
			merge(crouch(0.5), {
				rShoulder = { -30, 0, 15 },
				rElbow = { 20, 0, 0 },
				lShoulder = { 50, 0, -20 },
				lElbow = { 40, 0, 0 },
				waist = { -14, -15, 0 },
			}),
			"inOut"
		),
		k(
			0.38,
			merge(lunge(0.8), {
				rShoulder = { 70, 0, 5 },
				rElbow = { 0, 0, 0 },
				rWrist = { -30, 0, 0 },
				lShoulder = { 30, 0, -30 },
				waist = { -16, 10, 0 },
			}),
			"out"
		),
		k(
			0.46,
			merge(lunge(0.85), { rShoulder = { 95, 0, 5 }, lShoulder = { 25, 0, -30 }, waist = { -14, 14, 0 } }),
			"out"
		),
	},
	recover = 0.3,
	release = 0.38,
	hit = 0.38,
}
-- Deep Freeze: both open hands reaching at the target, then clenched shut and pulled in (0.34): the ice closes.
motions.deepFreeze = {
	keys = {
		k(
			0.18,
			merge(STAND, {
				rShoulder = { 95, -35, 0 },
				rElbow = { 20, 0, 0 },
				lShoulder = { 95, 35, 0 },
				lElbow = { 20, 0, 0 },
				waist = { 6, 0, 0 },
			}),
			"out"
		),
		k(
			0.34,
			merge(crouch(0.3), {
				rShoulder = { 85, 10, 0 },
				rElbow = { 95, 0, 0 },
				rWrist = { 30, 0, 0 },
				lShoulder = { 85, -10, 0 },
				lElbow = { 95, 0, 0 },
				lWrist = { 30, 0, 0 },
				waist = { -10, 0, 0 },
			}),
			"in"
		),
		k(
			0.5,
			merge(crouch(0.35), {
				rShoulder = { 80, 12, 0 },
				rElbow = { 100, 0, 0 },
				lShoulder = { 80, -12, 0 },
				lElbow = { 100, 0, 0 },
				waist = { -12, 0, 0 },
			})
		),
	},
	recover = 0.35,
	hit = 0.34,
}
-- Shatter: the right fist drawn back in a crouch and punched straight at the frozen target (0.26).
motions.shatter = {
	keys = {
		k(
			0.16,
			merge(crouch(0.25), {
				rShoulder = { 30, 0, 20 },
				rElbow = { 130, 0, 0 },
				lShoulder = { 70, 0, -20 },
				lElbow = { 60, 0, 0 },
				waist = { 4, -25, 0 },
			}),
			"out"
		),
		k(
			0.26,
			merge(lunge(0.7), {
				rShoulder = { 90, 0, 0 },
				rElbow = { 0, 0, 0 },
				lShoulder = { 20, 0, -25 },
				lElbow = { 90, 0, 0 },
				waist = { -10, 25, 0 },
			}),
			"in"
		),
		k(
			0.34,
			merge(
				lunge(0.75),
				{ rShoulder = { 88, 0, -2 }, lShoulder = { 20, 0, -25 }, lElbow = { 95, 0, 0 }, waist = { -12, 28, 0 } }
			),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.26,
}
-- Blizzard: the arms swept round in a wide circle and up over the head, then brought down and apart across the circle
-- in a crouch (0.55).
motions.blizzard = {
	keys = {
		k(
			0.25,
			merge(STAND, {
				rShoulder = { 120, 60, 0 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 60, 60, -30 },
				lElbow = { 10, 0, 0 },
				waist = { 6, 30, 0 },
			}),
			"inOut"
		),
		k(
			0.4,
			merge(STAND, {
				rShoulder = { 175, 0, 20 },
				lShoulder = { 175, 0, -20 },
				waist = { 18, 0, 0 },
				root = { 4, 0, 0, 0.25 },
			}),
			"inOut"
		),
		k(
			0.55,
			merge(crouch(0.5), {
				rShoulder = { 110, -50, 30 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 110, 50, -30 },
				lElbow = { 5, 0, 0 },
				waist = { -14, 0, 0 },
			}),
			"in"
		),
		k(
			0.7,
			merge(crouch(0.55), { rShoulder = { 100, -60, 35 }, lShoulder = { 100, 60, -35 }, waist = { -16, 0, 0 } })
		),
	},
	recover = 0.35,
	hit = 0.55,
	lock = true,
}

-- Lightning ---------------------------------------------------------------------------------------------------------
-- Lightning Bolt: two fingers pointed down the straight arm, the left hand bracing the right forearm; with 10B two
-- jabs (a staff pushes its tip as Fire Bolt does).
local JAB: CastRig = {
	back = {
		rShoulder = { 60, 0, 30 },
		rElbow = { 100, 0, 0 },
		lShoulder = { 50, 0, -10 },
		lElbow = { 90, 0, 0 },
		waist = { 0, -10, 0 },
	},
	point = {
		rShoulder = { 90, -5, 0 },
		rElbow = { 0, 0, 0 },
		rWrist = { -60, 0, 0 },
		lShoulder = { 70, -30, 0 },
		lElbow = { 60, 0, 0 },
		waist = { -8, 15, 0 },
	},
	after = {
		rShoulder = { 92, -5, 0 },
		rElbow = { 0, 0, 0 },
		rWrist = { -55, 0, 0 },
		lShoulder = { 68, -30, 0 },
		lElbow = { 62, 0, 0 },
		waist = { -8, 17, 0 },
	},
}
motions.lightningBolt = {
	keys = fireboltKeys(JAB, 1),
	recover = 0.22,
	release = 0.16,
	variants = {
		variant({ weapon = "staff", hits = 2, keys = fireboltKeys(STAFF, 2) }),
		variant({ weapon = "staff", keys = fireboltKeys(STAFF, 1) }),
		variant({ hits = 2, keys = fireboltKeys(JAB, 2) }),
	},
}
-- Static Shock: the left palm thrust out at the target in a short lunge (0.26), the right hand charged at the hip.
motions.staticShock = {
	keys = {
		k(
			0.16,
			merge(STAND, {
				lShoulder = { 40, 0, -60 },
				lElbow = { 90, 0, 0 },
				rShoulder = { 40, 0, 30 },
				rElbow = { 100, 0, 0 },
				waist = { 0, 20, 0 },
			}),
			"out"
		),
		k(
			0.26,
			merge(lunge(0.4), {
				lShoulder = { 90, -20, 0 },
				lElbow = { 0, 0, 0 },
				lWrist = { -50, 0, 0 },
				rShoulder = { 20, 0, 30 },
				rElbow = { 80, 0, 0 },
				waist = { -6, -20, 0 },
			}),
			"in"
		),
		k(
			0.34,
			merge(lunge(0.45), {
				lShoulder = { 88, -22, 0 },
				lElbow = { 0, 0, 0 },
				lWrist = { -50, 0, 0 },
				rShoulder = { 20, 0, 30 },
				rElbow = { 85, 0, 0 },
				waist = { -8, -22, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.26,
}
-- Storm Armor: a tense crouch with the fists at the chest, then the arms thrown down and back, chest out, a hop on the
-- toes as the storm takes the body (0.28).
motions.stormArmor = {
	keys = {
		k(
			0.16,
			merge(crouch(0.35), {
				rShoulder = { 20, 0, 20 },
				rElbow = { 120, 0, 0 },
				lShoulder = { 20, 0, -20 },
				lElbow = { 120, 0, 0 },
				waist = { -14, 0, 0 },
			}),
			"out"
		),
		k(
			0.28,
			merge(STAND, {
				root = { 8, 0, 0, 0.35 },
				rShoulder = { -20, 0, 45 },
				rElbow = { 30, 0, 0 },
				lShoulder = { -20, 0, -45 },
				lElbow = { 30, 0, 0 },
				waist = { 18, 0, 0 },
			}),
			"in"
		),
		k(
			0.6,
			merge(STAND, {
				rShoulder = { -10, 0, 40 },
				rElbow = { 35, 0, 0 },
				lShoulder = { -10, 0, -40 },
				lElbow = { 35, 0, 0 },
				waist = { 10, 0, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.28,
}
-- Thunder Strike: the weapon raised straight up to the sky, then swept down to point at the target in a lunge (0.42),
-- the bolt following the tip.
motions.thunderStrike = {
	keys = {
		k(
			0.3,
			merge(STAND, {
				rShoulder = { 175, 0, 15 },
				rElbow = { 0, 0, 0 },
				rWrist = { -30, 0, 0 },
				lShoulder = { 40, 0, -30 },
				waist = { 14, -10, 0 },
				root = { 4, 0, 0, 0.2 },
			}),
			"out"
		),
		k(
			0.42,
			merge(lunge(0.6), {
				rShoulder = { 100, 0, 0 },
				rElbow = { 0, 0, 0 },
				rWrist = { -60, 0, 0 },
				lShoulder = { 20, 0, -40 },
				waist = { -12, 12, 0 },
			}),
			"in"
		),
		k(
			0.55,
			merge(lunge(0.65), {
				rShoulder = { 92, 0, 0 },
				rElbow = { 0, 0, 0 },
				rWrist = { -60, 0, 0 },
				lShoulder = { 20, 0, -40 },
				waist = { -14, 14, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.42,
}
-- Ball Lightning: the ball spun between both hands at the right side, then pushed out low with the right palm in a
-- lunge (0.38), rolling away.
motions.ballLightning = {
	keys = {
		k(
			0.26,
			merge(STAND, {
				rShoulder = { 40, -30, 40 },
				rElbow = { 90, 0, 0 },
				lShoulder = { 60, -60, 0 },
				lElbow = { 90, 0, 0 },
				waist = { 0, -30, 0 },
				root = { 0, -12, 0, 0 },
			}),
			"inOut"
		),
		k(
			0.38,
			merge(lunge(0.7), {
				rShoulder = { 55, -10, 0 },
				rElbow = { 25, 0, 0 },
				rWrist = { -40, 0, 0 },
				lShoulder = { 60, -40, 0 },
				lElbow = { 60, 0, 0 },
				waist = { -14, 20, 0 },
			}),
			"out"
		),
		k(
			0.46,
			merge(lunge(0.75), {
				rShoulder = { 62, -10, 0 },
				rElbow = { 15, 0, 0 },
				lShoulder = { 55, -40, 0 },
				lElbow = { 65, 0, 0 },
				waist = { -16, 22, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	release = 0.38,
	hit = 0.38,
}
-- Lightning Lance: both hands drawn back to the right hip, then thrust straight ahead together in a deep lunge (0.26),
-- the lance leaving both palms.
motions.lightningLance = {
	keys = {
		k(
			0.16,
			merge(crouch(0.3), {
				rShoulder = { 20, 40, 30 },
				rElbow = { 110, 0, 0 },
				lShoulder = { 30, 60, 0 },
				lElbow = { 110, 0, 0 },
				waist = { 0, -35, 0 },
				root = { 0, -15, 0, -0.25 },
			}),
			"out"
		),
		k(
			0.26,
			merge(lunge(0.9), {
				rShoulder = { 80, 10, 0 },
				rElbow = { 0, 0, 0 },
				lShoulder = { 80, -10, 0 },
				lElbow = { 0, 0, 0 },
				waist = { -8, -5, 0 },
			}),
			"in"
		),
		k(
			0.34,
			merge(lunge(0.95), {
				rShoulder = { 76, 10, 0 },
				rElbow = { 0, 0, 0 },
				lShoulder = { 76, -10, 0 },
				lElbow = { 0, 0, 0 },
				waist = { -10, -5, 0 },
			}),
			"out"
		),
	},
	recover = 0.25,
	hit = 0.26,
}
-- Tempest: the arms raised wide on the toes calling the storm, then the fists pulled down hard in a deep crouch at the
-- event (0.55).
motions.tempest = {
	keys = {
		k(
			0.3,
			merge(STAND, {
				rShoulder = { 170, 0, 50 },
				rElbow = { 30, 0, 0 },
				lShoulder = { 170, 0, -50 },
				lElbow = { 30, 0, 0 },
				waist = { 20, 0, 0 },
				root = { 6, 0, 0, 0.3 },
			}),
			"out"
		),
		k(
			0.55,
			merge(crouch(0.8), {
				rShoulder = { 40, 0, 40 },
				rElbow = { 110, 0, 0 },
				lShoulder = { 40, 0, -40 },
				lElbow = { 110, 0, 0 },
				waist = { -20, 0, 0 },
			}),
			"in"
		),
		k(
			0.7,
			merge(crouch(0.85), {
				rShoulder = { 35, 0, 42 },
				rElbow = { 115, 0, 0 },
				lShoulder = { 35, 0, -42 },
				lElbow = { 115, 0, 0 },
				waist = { -22, 0, 0 },
			})
		),
	},
	recover = 0.35,
	hit = 0.55,
	lock = true,
}

-- Cleric -------------------------------------------------------------------------------------------------------

-- Holy Strike: the mace raised high and brought down in a half lunge at the hit (0.25), the left palm opening towards
-- the target (S114), the mace running on low.
motions.holyStrike = {
	keys = {
		k(
			0.18,
			merge(
				STAND,
				{ rShoulder = { 168, 0, 15 }, rElbow = { 50, 0, 0 }, lShoulder = { 30, 0, -15 }, waist = { 10, -8, 0 } }
			),
			"out"
		),
		k(
			0.25,
			merge(lunge(0.5), {
				rShoulder = { 45, 0, -10 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 75, 0, -8 },
				lElbow = { 8, 0, 0 },
				lWrist = { -40, 0, 0 },
				waist = { -14, 8, 0 },
			}),
			"in"
		),
		k(
			0.33,
			merge(lunge(0.5), {
				rShoulder = { 22, 0, -14 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 80, 0, -8 },
				lElbow = { 6, 0, 0 },
				lWrist = { -45, 0, 0 },
				waist = { -16, 8, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.25,
	trail = { from = 0.16, to = 0.3 },
}

-- Heal: the left hand stretched out towards the ally, the mace at the chest, a step towards the ally (S114).
motions.heal = {
	keys = {
		k(
			0.1,
			merge(crouch(0.2), {
				lShoulder = { 40, -30, 0 },
				lElbow = { 110, 0, 0 },
				rShoulder = { 40, 40, 0 },
				rElbow = { 100, 0, 0 },
				waist = { -6, -8, 0 },
			}),
			"out"
		), -- walka-wk: the hand gathers the light at the chest
		k(
			0.22,
			merge(lunge(0.3), {
				lShoulder = { 95, 10, 0 },
				lElbow = { 0, 0, 0 },
				lWrist = { -30, 0, 0 },
				rShoulder = { 45, 40, 0 },
				rElbow = { 100, 0, 0 },
				waist = { 0, 10, 0 },
			}),
			"out"
		),
		k(
			0.5,
			merge(lunge(0.25), {
				lShoulder = { 100, 10, 0 },
				lElbow = { 0, 0, 0 },
				lWrist = { -35, 0, 0 },
				rShoulder = { 45, 40, 0 },
				rElbow = { 100, 0, 0 },
				waist = { 2, 10, 0 },
			})
		),
	},
	recover = 0.25,
	hit = 0.25,
}

-- Renew: hands cupped low, then lifted as if pouring.
motions.renew = {
	keys = {
		k(
			0.08,
			merge(crouch(0.3), {
				rShoulder = { 20, 25, 0 },
				rElbow = { 70, 0, 0 },
				lShoulder = { 20, -25, 0 },
				lElbow = { 70, 0, 0 },
				waist = { -14, 0, 0 },
			}),
			"out"
		), -- walka-wk: a dip before the lift
		k(0.18, {
			rShoulder = { 40, 25, 0 },
			rElbow = { 80, 0, 0 },
			lShoulder = { 40, -25, 0 },
			lElbow = { 80, 0, 0 },
			waist = { -8, 0, 0 },
		}, "out"),
		k(0.4, {
			rShoulder = { 115, 20, 0 },
			rElbow = { 30, 0, 0 },
			lShoulder = { 115, -20, 0 },
			lElbow = { 30, 0, 0 },
			waist = { 8, 0, 0 },
		}, "inOut"),
		k(0.55, {
			rShoulder = { 128, 25, 0 },
			rElbow = { 20, 0, 0 },
			lShoulder = { 128, -25, 0 },
			lElbow = { 20, 0, 0 },
			waist = { 12, 0, 0 },
		}, "out"), -- walka-wk: the pour runs on
	},
	recover = 0.3,
	hit = 0.35,
}

-- Radiance: the mace raised high, the chest opened to the light.
motions.radiance = {
	keys = {
		k(
			0.2,
			merge(
				STAND,
				{ rShoulder = { 176, 0, 12 }, rElbow = { 10, 0, 0 }, lShoulder = { 40, 0, -60 }, waist = { 12, 0, 0 } }
			),
			"out"
		),
		k(
			0.3,
			merge(STAND, {
				rShoulder = { 178, 0, 15 },
				lShoulder = { 30, 0, -80 },
				waist = { 18, 0, 0 },
				root = { 5, 0, 0, 0.3 },
			}),
			"out"
		),
		k(0.42, merge(STAND, { rShoulder = { 172, 0, 14 }, lShoulder = { 34, 0, -72 }, waist = { 14, 0, 0 } })),
	},
	recover = 0.3,
	hit = 0.3,
}

-- Circle of Light: one slow turn of the body with the arms spread low (the mace in one hand), the circle growing as it
-- turns. S114: low open arms, unlike Wheel of Fortune (both hands over the head).
motions.circleOfLight = {
	keys = {
		k(
			0.15,
			merge(
				STAND,
				{ rShoulder = { 30, 0, 72 }, rElbow = { 12, 0, 0 }, lShoulder = { 30, 0, -72 }, waist = { 6, 0, 0 } }
			),
			"out"
		),
		k(
			0.6,
			merge(STAND, {
				rShoulder = { 40, 0, 78 },
				rElbow = { 8, 0, 0 },
				lShoulder = { 40, 0, -78 },
				waist = { 8, 0, 0 },
				root = { 0, 360, 0, 0.2 },
			}),
			"inOut"
		),
	},
	recover = 0.25,
	hit = 0.5,
	lock = true,
}

-- Purify: hands crossed at the chest, then thrown open.
motions.purify = {
	keys = {
		k(0.18, {
			rShoulder = { 70, 60, 0 },
			rElbow = { 110, 0, 0 },
			lShoulder = { 70, -60, 0 },
			lElbow = { 110, 0, 0 },
			waist = { -6, 0, 0 },
		}, "out"),
		k(0.3, {
			rShoulder = { 60, 0, 85 },
			rElbow = { 10, 0, 0 },
			lShoulder = { 60, 0, -85 },
			lElbow = { 10, 0, 0 },
			waist = { 10, 0, 0 },
		}, "out"),
		k(0.42, {
			rShoulder = { 70, -10, 98 },
			rElbow = { 6, 0, 0 },
			lShoulder = { 70, 10, -98 },
			lElbow = { 6, 0, 0 },
			waist = { 16, 0, 0 },
		}, "out"), -- walka-wk: the arms fly on
	},
	recover = 0.3,
	hit = 0.3,
}

-- Aura of Endurance: arms raised slowly, slightly apart, the head lifted.
motions.auraOfEndurance = {
	keys = {
		k(
			0.14,
			merge(crouch(0.3), {
				rShoulder = { 25, 30, 0 },
				rElbow = { 60, 0, 0 },
				lShoulder = { 25, -30, 0 },
				lElbow = { 60, 0, 0 },
				waist = { -10, 0, 0 },
			}),
			"out"
		), -- walka-wk: a breath in before the arms rise
		k(
			0.35,
			merge(STAND, {
				rShoulder = { 140, 0, 25 },
				rElbow = { 15, 0, 0 },
				lShoulder = { 140, 0, -25 },
				lElbow = { 15, 0, 0 },
				waist = { 10, 0, 0 },
			}),
			"inOut"
		),
		k(0.8, merge(STAND, { rShoulder = { 145, 0, 30 }, lShoulder = { 145, 0, -30 }, waist = { 12, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.4,
	lock = true,
}

-- Resurrection: the hands go up at once (S114: the server raises the fallen at 0, so the first 0.1 s is the call),
-- kneeling with a hand down to the fallen, then rising with the arms up.
motions.resurrection = {
	keys = {
		k(0.1, merge(STAND, { rShoulder = { 140, 0, 25 }, lShoulder = { 140, 0, -25 }, waist = { 8, 0, 0 } }), "out"),
		k(
			0.3,
			merge(KNEEL, {
				lShoulder = { 50, 0, -10 },
				lElbow = { 10, 0, 0 },
				rShoulder = { 60, 30, 0 },
				rElbow = { 90, 0, 0 },
				waist = { -25, 0, 0 },
			}),
			"out"
		),
		k(
			0.65,
			merge(
				KNEEL,
				{ lShoulder = { 45, 0, -10 }, rShoulder = { 60, 30, 0 }, rElbow = { 90, 0, 0 }, waist = { -28, 0, 0 } }
			)
		),
		k(
			0.95,
			merge(STAND, { rShoulder = { 150, 0, 25 }, lShoulder = { 150, 0, -25 }, waist = { 12, 0, 0 } }),
			"inOut"
		),
	},
	recover = 0.3,
	hit = 0,
	lock = true,
}

-- Shield of Faith: the mace upright, the left palm pushed forward.
motions.shieldOfFaith = {
	keys = {
		k(0.1, {
			rShoulder = { 60, 0, 10 },
			rElbow = { 95, 0, 0 },
			lShoulder = { 45, -40, 0 },
			lElbow = { 115, 0, 0 },
			lWrist = { 10, 0, 0 },
			waist = { -4, -18, 0 },
		}, "out"), -- walka-wk: the palm drawn back
		k(0.2, {
			rShoulder = { 70, 0, 10 },
			rElbow = { 90, 0, 0 },
			lShoulder = { 92, -10, 0 },
			lElbow = { 5, 0, 0 },
			lWrist = { -60, 0, 0 },
			waist = { -6, -10, 0 },
		}, "out"),
		k(0.45, {
			rShoulder = { 72, 0, 10 },
			rElbow = { 90, 0, 0 },
			lShoulder = { 95, -10, 0 },
			lElbow = { 0, 0, 0 },
			lWrist = { -65, 0, 0 },
			waist = { -8, -10, 0 },
		}),
	},
	recover = 0.25,
	hit = 0.2,
}

-- Judgement: a jump with the mace raised, a blow from above.
motions.judgement = {
	keys = {
		k(0.24, merge(air(1.5), OVERHEAD, { waist = { 14, 0, 0 } }), "out"),
		k(0.36, merge(crouch(1), SLAMMED, { waist = { -30, 0, 0 }, root = { -12, 0, 0, -0.8 } }), "in"),
		k(0.5, merge(crouch(0.8), SLAMMED, { waist = { -24, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.36,
	land = 0.36,
	lock = true,
	trail = { from = 0.24, to = 0.38 },
}

-- Prayer (channel): kneeling, the hands together at the chest, a slow bow.
motions.prayer = {
	keys = {
		k(
			0.4,
			merge(KNEEL, {
				rShoulder = { 60, 45, 0 },
				rElbow = { 120, 0, 0 },
				lShoulder = { 60, -45, 0 },
				lElbow = { 120, 0, 0 },
				waist = { -12, 0, 0 },
			}),
			"inOut"
		),
		k(
			1.2,
			merge(KNEEL, {
				rShoulder = { 62, 45, 0 },
				rElbow = { 122, 0, 0 },
				lShoulder = { 62, -45, 0 },
				lElbow = { 122, 0, 0 },
				waist = { -22, 0, 0 },
			}),
			"inOut"
		),
		k(
			2,
			merge(KNEEL, {
				rShoulder = { 60, 45, 0 },
				rElbow = { 120, 0, 0 },
				lShoulder = { 60, -45, 0 },
				lElbow = { 120, 0, 0 },
				waist = { -12, 0, 0 },
			}),
			"inOut"
		),
		k(2.4, merge(STAND, { rShoulder = { 20, 0, 15 }, lShoulder = { 20, 0, -15 } }), "inOut"),
	},
	recover = 0.3,
	hit = 0.4,
	loop = { from = 0.4, to = 2 },
	lock = true,
}

-- Divine Intervention: the arms spread wide and up, the body rising.
motions.divineIntervention = {
	keys = {
		k(
			0.2,
			merge(crouch(0.6), {
				rShoulder = { 30, 50, 0 },
				rElbow = { 100, 0, 0 },
				lShoulder = { 30, -50, 0 },
				lElbow = { 100, 0, 0 },
				waist = { -18, 0, 0 },
			}),
			"out"
		), -- walka-wk: gathered low before the rise
		k(
			0.45,
			merge(air(1.2, 0.3), {
				rShoulder = { 120, 0, 75 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 120, 0, -75 },
				lElbow = { 5, 0, 0 },
				waist = { 16, 0, 0 },
			}),
			"inOut"
		),
		k(0.9, merge(air(1.4, 0.3), { rShoulder = { 125, 0, 80 }, lShoulder = { 125, 0, -80 }, waist = { 18, 0, 0 } })),
	},
	recover = 0.4,
	hit = 0.45,
	lock = true,
}

-- Sanctuary (S70): hands cupped low like Renew, lifted, then both palms pressed down to consecrate the ground.
motions.sanctuary = {
	keys = {
		k(0.18, {
			rShoulder = { 40, 25, 0 },
			rElbow = { 80, 0, 0 },
			lShoulder = { 40, -25, 0 },
			lElbow = { 80, 0, 0 },
			waist = { -8, 0, 0 },
		}, "out"),
		k(0.32, {
			rShoulder = { 115, 20, 0 },
			rElbow = { 30, 0, 0 },
			lShoulder = { 115, -20, 0 },
			lElbow = { 30, 0, 0 },
			waist = { 8, 0, 0 },
		}, "inOut"),
		k(
			0.45,
			merge(crouch(0.4), {
				rShoulder = { 40, -10, 0 },
				rElbow = { 10, 0, 0 },
				rWrist = { -40, 0, 0 },
				lShoulder = { 40, 10, 0 },
				lElbow = { 10, 0, 0 },
				lWrist = { -40, 0, 0 },
				waist = { -14, 0, 0 },
			}),
			"in"
		),
	},
	recover = 0.3,
	hit = 0.4,
}

-- Guardian Angel (S70): kneeling with the hands together, then rising with the arms spread wide and up.
motions.guardianAngel = {
	keys = {
		k(
			0.2,
			merge(KNEEL, {
				rShoulder = { 60, 45, 0 },
				rElbow = { 120, 0, 0 },
				lShoulder = { 60, -45, 0 },
				lElbow = { 120, 0, 0 },
				waist = { -12, 0, 0 },
			}),
			"out"
		),
		k(
			0.5,
			merge(STAND, {
				rShoulder = { 120, 0, 75 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 120, 0, -75 },
				lElbow = { 5, 0, 0 },
				waist = { 16, 0, 0 },
			}),
			"inOut"
		),
		k(0.9, merge(STAND, { rShoulder = { 125, 0, 80 }, lShoulder = { 125, 0, -80 }, waist = { 18, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.45,
	lock = true,
}

-- Roll of the Dice (S70): the right hand swings back at the hip and throws the dice underhand, forward.
motions.fortuneDice = {
	keys = {
		k(
			0.15,
			merge(crouch(0.3), {
				rShoulder = { -40, 0, 10 },
				rElbow = { 20, 0, 0 },
				lShoulder = { 30, 0, -15 },
				waist = { -6, -12, 0 },
			}),
			"out"
		),
		k(
			0.28,
			merge(lunge(0.3), {
				rShoulder = { 110, 0, 10 },
				rElbow = { 10, 0, 0 },
				rWrist = { 20, 0, 0 },
				lShoulder = { 20, 0, -15 },
				waist = { -4, 10, 0 },
			}),
			"out"
		),
		k(
			0.42,
			merge(lunge(0.2), {
				rShoulder = { 128, 0, 12 },
				rElbow = { 5, 0, 0 },
				rWrist = { 30, 0, 0 },
				lShoulder = { 15, 0, -15 },
				waist = { -2, 14, 0 },
			}),
			"out"
		), -- walka-wk: the throw follows through
	},
	recover = 0.3,
	release = 0.25,
}

-- Wheel of Fortune (S70): both arms over the head, one slow turn of the body like Circle of Light.
motions.wheelOfFortune = {
	keys = {
		k(0.15, merge(STAND, OVERHEAD, { waist = { 10, 0, 0 } }), "out"),
		k(0.6, merge(STAND, OVERHEAD, { waist = { 12, 0, 0 }, root = { 0, 360, 0, 0.2 } }), "inOut"),
	},
	recover = 0.3,
	hit = 0.5,
	lock = true,
}

-- Brand of Light (S70): hands crossed at the chest like Purify, then the left palm thrust at the enemy.
motions.brandOfLight = {
	keys = {
		k(0.06, {
			rShoulder = { 30, 30, 0 },
			rElbow = { 60, 0, 0 },
			lShoulder = { 30, -30, 0 },
			lElbow = { 60, 0, 0 },
			waist = { -10, 0, 0 },
		}, "out"), -- walka-wk: the arms drawn in
		k(0.15, {
			rShoulder = { 70, 60, 0 },
			rElbow = { 110, 0, 0 },
			lShoulder = { 70, -60, 0 },
			lElbow = { 110, 0, 0 },
			waist = { -6, 0, 0 },
		}, "out"),
		k(0.25, {
			lShoulder = { 90, 0, -5 },
			lElbow = { 5, 0, 0 },
			lWrist = { -50, 0, 0 },
			rShoulder = { 50, 40, 0 },
			rElbow = { 100, 0, 0 },
			waist = { -6, 10, 0 },
		}, "out"),
		k(0.36, {
			lShoulder = { 96, 4, -5 },
			lElbow = { 0, 0, 0 },
			lWrist = { -58, 0, 0 },
			rShoulder = { 44, 40, 0 },
			rElbow = { 100, 0, 0 },
			waist = { -8, 14, 0 },
		}, "out"), -- walka-wk: the palm presses on
	},
	recover = 0.3,
	hit = 0.25,
}

-- Hammer of Heaven (S70): a leap like Judgement, the mace brought down from the sky at 0.5 s.
motions.hammerOfHeaven = {
	keys = {
		k(
			0.2,
			merge(crouch(0.8), { rShoulder = { -20, 0, 10 }, lShoulder = { -20, 0, -10 }, root = { 0, 0, 0, -0.7 } }),
			"out"
		),
		k(0.38, merge(air(1.8), OVERHEAD, { waist = { 10, 0, 0 }, root = { 0, 0, 0, 1.8 } }), "out"),
		k(0.5, merge(crouch(1), SLAMMED, { waist = { -26, 0, 0 }, root = { -10, 0, 0, -0.9 } }), "in"),
		k(0.7, merge(crouch(0.8), SLAMMED, { waist = { -20, 0, 0 } })),
	},
	recover = 0.35,
	hit = 0.5,
	land = 0.5,
	lock = true,
	trail = { from = 0.3, to = 0.52 },
}

-- S145 (DESIGN-18 §6.4): the Cleric pools' new skills. walka-wk: each has its own motion now (anticipation, the
-- action on the server's time, follow-through), no longer the keys of an S114 skill.
-- Light Ray: the left palm drawn back past the right shoulder with the body wound up, then thrust at the target in a
-- half lunge; the ray leaves the palm at the release (0.25), the arm overshoots and settles.
motions.lightRay = {
	keys = {
		k(
			0.12,
			merge(crouch(0.25), {
				lShoulder = { 70, -70, 0 },
				lElbow = { 110, 0, 0 },
				lWrist = { 10, 0, 0 },
				rShoulder = { 30, 20, 10 },
				rElbow = { 60, 0, 0 },
				waist = { -4, -28, 0 },
			}),
			"out"
		),
		k(
			0.25,
			merge(lunge(0.45), {
				lShoulder = { 96, 8, 0 },
				lElbow = { 0, 0, 0 },
				lWrist = { -55, 0, 0 },
				rShoulder = { 20, 0, 18 },
				rElbow = { 40, 0, 0 },
				waist = { -8, 18, 0 },
			}),
			"in"
		),
		k(
			0.33,
			merge(lunge(0.5), {
				lShoulder = { 102, 12, 0 },
				lElbow = { 0, 0, 0 },
				lWrist = { -62, 0, 0 },
				rShoulder = { 14, 0, 22 },
				rElbow = { 35, 0, 0 },
				waist = { -10, 22, 0 },
			}),
			"out"
		),
		k(
			0.5,
			merge(lunge(0.25), {
				lShoulder = { 80, 6, 0 },
				lElbow = { 15, 0, 0 },
				lWrist = { -35, 0, 0 },
				rShoulder = { 20, 0, 15 },
				rElbow = { 45, 0, 0 },
				waist = { -4, 12, 0 },
			})
		),
	},
	recover = 0.25,
	release = 0.25,
}
-- Blinding Light: both hands gathered before the face in a small crouch (the light held in), then thrown up and out
-- with the body arched back at the flash (0.3), held a breath.
motions.blindingLight = {
	keys = {
		k(
			0.14,
			merge(crouch(0.35), {
				rShoulder = { 95, 50, 0 },
				rElbow = { 120, 0, 0 },
				lShoulder = { 95, -50, 0 },
				lElbow = { 120, 0, 0 },
				waist = { -14, 0, 0 },
			}),
			"out"
		),
		k(
			0.3,
			merge(STAND, {
				rShoulder = { 150, -10, 35 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 150, 10, -35 },
				lElbow = { 10, 0, 0 },
				lWrist = { -30, 0, 0 },
				waist = { 18, 0, 0 },
				root = { 6, 0, 0, 0.25 },
			}),
			"in"
		),
		k(
			0.46,
			merge(STAND, {
				rShoulder = { 140, -10, 40 },
				rElbow = { 14, 0, 0 },
				lShoulder = { 140, 10, -40 },
				lElbow = { 14, 0, 0 },
				lWrist = { -25, 0, 0 },
				waist = { 14, 0, 0 },
				root = { 4, 0, 0, 0.1 },
			}),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.3,
}
-- Miracle: kneeling, both arms raised to the sky with open palms gathering the light (the loop breathes between 0.4
-- and 0.6 for the cast time, both ends the same pose), then rising with the palms brought down towards the healed.
local MIRACLE_RAISED: Pose = merge(KNEEL, {
	rShoulder = { 160, 0, 30 },
	rElbow = { 15, 0, 0 },
	rWrist = { -20, 0, 0 },
	lShoulder = { 160, 0, -30 },
	lElbow = { 15, 0, 0 },
	lWrist = { -20, 0, 0 },
	waist = { 16, 0, 0 },
})
motions.miracle = {
	keys = {
		k(
			0.2,
			merge(KNEEL, {
				rShoulder = { 60, 45, 0 },
				rElbow = { 120, 0, 0 },
				lShoulder = { 60, -45, 0 },
				lElbow = { 120, 0, 0 },
				waist = { -16, 0, 0 },
			}),
			"out"
		),
		k(0.4, MIRACLE_RAISED, "inOut"),
		k(
			0.5,
			merge(MIRACLE_RAISED, {
				rShoulder = { 166, 0, 36 },
				lShoulder = { 166, 0, -36 },
				waist = { 20, 0, 0 },
				root = { 0, 0, 0, -1.2 },
			}),
			"inOut"
		),
		k(0.6, MIRACLE_RAISED, "inOut"),
		k(
			0.82,
			merge(lunge(0.3), {
				rShoulder = { 85, 25, 0 },
				rElbow = { 10, 0, 0 },
				rWrist = { -35, 0, 0 },
				lShoulder = { 85, -25, 0 },
				lElbow = { 10, 0, 0 },
				lWrist = { -35, 0, 0 },
				waist = { -6, 0, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	loop = { from = 0.4, to = 0.6 },
}
-- Consecrate: the mace swung up in both hands, rising on the toes, then driven head down into the ground at the feet
-- in a deep crouch (0.25); the Cleric stays down while the waves of light run out, then rises.
local CONSECRATE_DOWN: Pose = merge(crouch(1), {
	rShoulder = { 40, 20, -10 },
	rElbow = { 20, 0, 0 },
	rWrist = { 40, 0, 0 },
	lShoulder = { 40, -20, 10 },
	lElbow = { 25, 0, 0 },
	waist = { -32, 0, 0 },
})
motions.consecrate = {
	keys = {
		k(0.12, merge(STAND, OVERHEAD, { waist = { 14, 0, 0 }, root = { 4, 0, 0, 0.3 } }), "out"),
		k(0.25, CONSECRATE_DOWN, "in"),
		k(0.34, merge(CONSECRATE_DOWN, { waist = { -36, 0, 0 }, root = { -6, 0, 0, -0.95 } }), "out"),
		k(0.75, CONSECRATE_DOWN),
		k(
			0.95,
			merge(crouch(0.3), { rShoulder = { 30, 10, 0 }, lShoulder = { 30, -10, 0 }, waist = { -8, 0, 0 } }),
			"inOut"
		),
	},
	recover = 0.3,
	hit = 0.25,
	trail = { from = 0.1, to = 0.28 },
}
-- Holy Chains: the left arm wound across the body, flung at the target like a whip in a lunge (0.25), then yanked
-- back to the hip with the body leaning away (the chain pulled tight).
motions.holyChains = {
	keys = {
		k(
			0.12,
			merge(crouch(0.2), {
				lShoulder = { 60, -80, 0 },
				lElbow = { 90, 0, 0 },
				rShoulder = { 40, 20, 0 },
				rElbow = { 80, 0, 0 },
				waist = { -6, -30, 0 },
			}),
			"out"
		),
		k(
			0.25,
			merge(lunge(0.6), {
				lShoulder = { 100, 10, -10 },
				lElbow = { 0, 0, 0 },
				lWrist = { 30, 0, 0 },
				rShoulder = { 20, 0, 20 },
				rElbow = { 50, 0, 0 },
				waist = { -10, 22, 0 },
			}),
			"in"
		),
		k(
			0.4,
			merge(lunge(0.2), {
				lShoulder = { 30, 0, -30 },
				lElbow = { 70, 0, 0 },
				lWrist = { 30, 0, 0 },
				rShoulder = { 30, 0, 20 },
				rElbow = { 60, 0, 0 },
				waist = { 14, -10, 0 },
				root = { 8, 0, 0, -0.2 },
			}),
			"out"
		),
		k(
			0.55,
			merge(STAND, {
				lShoulder = { 35, 0, -25 },
				lElbow = { 65, 0, 0 },
				rShoulder = { 25, 0, 15 },
				rElbow = { 50, 0, 0 },
				waist = { 8, -6, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.25,
}
-- Holy Nova: crouched with both fists gathered at the chest (the light pressed in), then a burst upwards: the body
-- leaves the ground with the arms flung wide and down in a star at the hit (0.3), landing soft.
motions.holyNova = {
	keys = {
		k(
			0.16,
			merge(crouch(0.6), {
				rShoulder = { 70, 55, 0 },
				rElbow = { 130, 0, 0 },
				lShoulder = { 70, -55, 0 },
				lElbow = { 130, 0, 0 },
				waist = { -20, 0, 0 },
			}),
			"out"
		),
		k(
			0.3,
			merge(air(0.6, 0.2), {
				rShoulder = { 60, 0, 110 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 60, 0, -110 },
				lElbow = { 5, 0, 0 },
				waist = { 14, 0, 0 },
				rHip = { 0, 0, 18 },
				lHip = { 0, 0, -18 },
			}),
			"in"
		),
		k(
			0.42,
			merge(air(0.3, 0.2), {
				rShoulder = { 50, 0, 100 },
				lShoulder = { 50, 0, -100 },
				waist = { 10, 0, 0 },
				rHip = { 0, 0, 12 },
				lHip = { 0, 0, -12 },
			}),
			"out"
		),
		k(0.55, merge(crouch(0.3), { rShoulder = { 30, 0, 40 }, lShoulder = { 30, 0, -40 }, waist = { -4, 0, 0 } })),
	},
	recover = 0.3,
	hit = 0.3,
}
-- Rebuke: the mace pulled back to the right hip with both hands and the body turned away, then shoved straight ahead
-- in a lunge (0.2) like a ram, the shoulders following through.
motions.rebuke = {
	keys = {
		k(
			0.1,
			merge(crouch(0.35), {
				rShoulder = { 10, 0, 30 },
				rElbow = { 90, 0, 0 },
				lShoulder = { 40, 60, 0 },
				lElbow = { 100, 0, 0 },
				waist = { -6, -35, 0 },
			}),
			"out"
		),
		k(
			0.2,
			merge(lunge(0.8), {
				rShoulder = { 88, 10, 0 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 88, -10, 0 },
				lElbow = { 15, 0, 0 },
				waist = { -14, 10, 0 },
			}),
			"in"
		),
		k(
			0.3,
			merge(lunge(0.9), {
				rShoulder = { 92, 12, 0 },
				rElbow = { 4, 0, 0 },
				lShoulder = { 92, -12, 0 },
				lElbow = { 8, 0, 0 },
				waist = { -18, 14, 0 },
			}),
			"out"
		),
		k(
			0.45,
			merge(lunge(0.4), {
				rShoulder = { 60, 10, 0 },
				rElbow = { 30, 0, 0 },
				lShoulder = { 60, -10, 0 },
				lElbow = { 35, 0, 0 },
				waist = { -8, 6, 0 },
			})
		),
	},
	recover = 0.25,
	hit = 0.2,
}

SkillMotions.motions = motions

function SkillMotions.get(skillId: string): Motion?
	return motions[skillId]
end

-- Seconds from the cast until the blow lands (the server delays the damage by it; at most MAX_HIT).
function SkillMotions.hitDelay(skillId: string): number
	local m = motions[skillId]
	if not m then
		return 0
	end
	return math.clamp(m.hit or m.release or 0, 0, SkillMotions.MAX_HIT)
end

return SkillMotions
