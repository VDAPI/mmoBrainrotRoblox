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

export type Joint = string
export type Pose = { [Joint]: { number } }
export type Ease = "linear" | "in" | "out" | "inOut"
export type Key = { t: number, pose: Pose, ease: Ease? }

export type Motion = {
	keys: { Key },
	recover: number,
	hit: number?,
	release: number?,
	land: number?,
	loop: { from: number, to: number }?,
	lock: boolean?,
	trail: { from: number, to: number }?,
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

-- Bow (left hand): drawn to the cheek / released.
local BOW_DRAW: Pose = {
	lShoulder = { 90, 28, 0 },
	lElbow = { 0, 0, 0 },
	lWrist = { 0, 0, 0 },
	rShoulder = { 90, -45, 0 },
	rElbow = { 120, 0, 0 },
	rWrist = { 0, 0, 0 },
	waist = { 0, -28, 0 },
}
local BOW_LOOSE: Pose = {
	lShoulder = { 95, 28, 0 },
	lElbow = { 0, 0, 0 },
	rShoulder = { 88, -68, 0 },
	rElbow = { 150, 0, 0 },
	waist = { 0, -28, 0 },
}

local function k(t: number, pose: Pose, ease: Ease?): Key
	return { t = t, pose = pose, ease = ease }
end

local motions: { [string]: Motion } = {}

-- Warrior ----------------------------------------------------------------------------------------------------

-- Mighty Strike: the blade raised high over the right shoulder, a lunge and a heavy diagonal cut.
motions.mightyStrike = {
	keys = {
		k(
			0.22,
			merge(STAND, {
				rShoulder = { 170, 0, 25 },
				rElbow = { 60, 0, 0 },
				rWrist = { -20, 0, 0 },
				lShoulder = { 40, 0, -15 },
				waist = { 10, -18, 0 },
			}),
			"out"
		),
		k(
			0.32,
			merge(lunge(1), {
				rShoulder = { 30, 0, -35 },
				rElbow = { 5, 0, 0 },
				rWrist = { 20, 0, 0 },
				lShoulder = { -10, 0, -10 },
				waist = { -14, 22, 0 },
			}),
			"in"
		),
		k(0.42, merge(lunge(1), { rShoulder = { 25, 0, -30 }, waist = { -12, 18, 0 } })),
	},
	recover = 0.3,
	hit = 0.3,
	trail = { from = 0.2, to = 0.36 },
}

-- Battle Cry: weapon raised, the body arched back, a roar.
motions.battleCry = {
	keys = {
		k(
			0.25,
			merge(STAND, {
				rShoulder = { 175, 0, 10 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 60, 0, -40 },
				lElbow = { 90, 0, 0 },
				waist = { 18, 0, 0 },
				root = { 6, 0, 0, 0.2 },
			}),
			"out"
		),
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

-- Charge: bent forward running at the target (the server moves the body), a shoulder bash at the end.
motions.charge = {
	keys = {
		k(0.12, {
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
		}, "out"),
		k(0.24, {
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
		}, "in"),
	},
	recover = 0.3,
	hit = 0.15,
}

-- Blade Whirl: the blade out to the side, two full turns of the body (720°) in a low stance.
motions.bladeWhirl = {
	keys = {
		k(
			0.1,
			merge(crouch(0.35), {
				rShoulder = { 10, 0, 92 },
				rElbow = { 5, 0, 0 },
				rWrist = { 0, 0, 0 },
				lShoulder = { 10, 0, -70 },
				lElbow = { 20, 0, 0 },
				waist = { -6, -25, 0 },
				root = { 0, -20, 0, -0.35 },
			}),
			"out"
		),
		k(
			0.7,
			merge(crouch(0.35), {
				rShoulder = { 10, 0, 92 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 10, 0, -70 },
				lElbow = { 20, 0, 0 },
				waist = { -6, -25, 0 },
				root = { 0, 700, 0, -0.35 },
			}),
			"linear"
		),
	},
	recover = 0.25,
	hit = 0.18,
	lock = true,
	trail = { from = 0.1, to = 0.7 },
}

-- Cleave: a wide horizontal sweep from left to right.
motions.cleave = {
	keys = {
		k(
			0.2,
			merge(STAND, {
				rShoulder = { 85, 65, 0 },
				rElbow = { 35, 0, 0 },
				lShoulder = { 20, 0, -20 },
				waist = { 0, 38, 0 },
				root = { 0, 10, 0, -0.2 },
			}),
			"out"
		),
		k(
			0.32,
			merge(lunge(0.6), {
				rShoulder = { 85, -85, 0 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 10, 0, -30 },
				waist = { -4, -42, 0 },
				root = { -4, -10, 0, -0.3 },
			}),
			"in"
		),
	},
	recover = 0.3,
	hit = 0.27,
	trail = { from = 0.18, to = 0.34 },
}

-- Taunt: arms thrown wide, chest out, a challenge.
motions.taunt = {
	keys = {
		k(
			0.18,
			merge(STAND, {
				rShoulder = { 20, 0, 100 },
				rElbow = { 20, 0, 0 },
				lShoulder = { 20, 0, -100 },
				lElbow = { 20, 0, 0 },
				waist = { 16, 0, 0 },
				root = { 4, 0, 0, 0 },
			}),
			"out"
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
		k(
			0.16,
			merge(crouch(0.4), {
				waist = { -22, 0, 0 },
				rShoulder = { 40, 0, 10 },
				rElbow = { 115, 0, 0 },
				lShoulder = { 40, 0, -10 },
				lElbow = { 115, 0, 0 },
			}),
			"out"
		),
		k(
			0.42,
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
		k(
			0.8,
			merge(crouch(0.45), {
				lShoulder = { 88, 10, -22 },
				lElbow = { 72, 0, 0 },
				rShoulder = { 22, 0, 30 },
				rElbow = { 65, 0, 0 },
				waist = { -10, 10, 0 },
			})
		),
	},
	recover = 0.3,
	hit = 0.18,
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
do
	local keys = {}
	for i, yaw in { 0, 35, -35 } do
		for _, key in leap((i - 1) * 0.45, yaw) do
			table.insert(keys, key)
		end
	end
	table.insert(keys, k(1.45, merge(crouch(0.8), SLAMMED, { waist = { -20, 0, 0 } })))
	motions.titansWrath =
		{ keys = keys, recover = 0.35, hit = 0.3, land = 0.3, lock = true, trail = { from = 0.2, to = 1.2 } }
end

-- Hunter -----------------------------------------------------------------------------------------------------

-- Aimed Shot: a long draw, a still moment of aiming, release.
motions.aimedShot = {
	keys = {
		k(0.4, merge(BOW_DRAW, { rElbow = { 135, 0, 0 }, waist = { 0, -32, 0 } }), "out"),
		k(0.55, merge(BOW_DRAW, { rElbow = { 140, 0, 0 }, rShoulder = { 90, -50, 0 }, waist = { 0, -32, 0 } })),
		k(0.62, merge(BOW_LOOSE, { waist = { 4, -32, 0 } }), "out"),
	},
	recover = 0.3,
	release = 0.58,
	lock = true,
}

-- Double Shot: two quick draws.
motions.doubleShot = {
	keys = {
		k(0.13, BOW_DRAW, "out"),
		k(0.18, BOW_LOOSE, "out"),
		k(0.3, BOW_DRAW, "out"),
		k(0.35, BOW_LOOSE, "out"),
	},
	recover = 0.25,
	release = 0.16,
}

-- Disengage: a crouch and a backflip (the server moves the body back at once).
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
			merge(crouch(0.8), { root = { 360, 0, 0, -0.7 }, rShoulder = { 40, 0, 40 }, lShoulder = { 40, 0, -40 } }),
			"out"
		),
	},
	recover = 0.25,
	hit = 0.05,
	land = 0.5,
}

-- Arrow Rain: the bow aimed at the sky, the body leaning back.
motions.arrowRain = {
	keys = {
		k(
			0.25,
			merge(STAND, {
				lShoulder = { 165, 20, 0 },
				lElbow = { 0, 0, 0 },
				rShoulder = { 150, -35, 0 },
				rElbow = { 120, 0, 0 },
				waist = { 25, -20, 0 },
				root = { 6, 0, 0, 0 },
			}),
			"out"
		),
		k(
			0.32,
			merge(STAND, {
				lShoulder = { 170, 20, 0 },
				rShoulder = { 140, -60, 0 },
				rElbow = { 150, 0, 0 },
				waist = { 28, -20, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	release = 0.3,
	hit = 0.3,
}

-- Venom Arrow: the arrow dipped low from the quiver, a crouched shot.
motions.venomArrow = {
	keys = {
		k(
			0.14,
			merge(crouch(0.5), {
				rShoulder = { -25, 0, 20 },
				rElbow = { 40, 0, 0 },
				lShoulder = { 60, 28, 0 },
				waist = { -10, -10, 0 },
			}),
			"out"
		),
		k(0.32, merge(crouch(0.5), BOW_DRAW), "out"),
		k(0.38, merge(crouch(0.5), BOW_LOOSE), "out"),
	},
	recover = 0.3,
	release = 0.36,
}

-- Frost Trap: kneeling, the trap set on the ground.
motions.frostTrap = {
	keys = {
		k(
			0.22,
			merge(
				KNEEL,
				{ rShoulder = { 55, 0, 10 }, rElbow = { 25, 0, 0 }, lShoulder = { 30, 0, -20 }, waist = { -25, 0, 0 } }
			),
			"out"
		),
		k(
			0.45,
			merge(
				KNEEL,
				{ rShoulder = { 45, 0, 10 }, rElbow = { 15, 0, 0 }, lShoulder = { 35, 0, -20 }, waist = { -28, 0, 0 } }
			)
		),
	},
	recover = 0.3,
	hit = 0.35,
	lock = true,
}

-- Piercing Arrow: a wide stance, a full draw side-on and a heavy release.
motions.piercingArrow = {
	keys = {
		k(
			0.35,
			merge(BOW_DRAW, {
				rElbow = { 145, 0, 0 },
				waist = { -4, -40, 0 },
				root = { 0, -15, 0, -0.4 },
				rHip = { 10, 0, 18 },
				lHip = { 10, 0, -18 },
				rKnee = { 25 },
				lKnee = { 25 },
			}),
			"out"
		),
		k(
			0.42,
			merge(BOW_LOOSE, {
				waist = { 8, -40, 0 },
				root = { 3, -15, 0, -0.4 },
				rHip = { 10, 0, 18 },
				lHip = { 10, 0, -18 },
				rKnee = { 25 },
				lKnee = { 25 },
			}),
			"out"
		),
	},
	recover = 0.35,
	hit = 0.4,
	release = 0.4,
	lock = true,
}

-- Hunter's Mark: the left hand points at the prey, the right at the eye.
motions.huntersMark = {
	keys = {
		k(
			0.2,
			merge(STAND, {
				lShoulder = { 95, 20, 0 },
				lElbow = { 0, 0, 0 },
				rShoulder = { 125, 25, 0 },
				rElbow = { 135, 0, 0 },
				waist = { 0, -15, 0 },
			}),
			"out"
		),
		k(
			0.5,
			merge(STAND, {
				lShoulder = { 98, 20, 0 },
				rShoulder = { 125, 25, 0 },
				rElbow = { 135, 0, 0 },
				waist = { 0, -15, 0 },
			})
		),
	},
	recover = 0.25,
	hit = 0.22,
}

-- Volley: drawn to the left, three arrows loosed in a sweep to the right.
motions.volley = {
	keys = {
		k(0.18, merge(BOW_DRAW, { waist = { 0, 15, 0 }, root = { 0, 25, 0, 0 } }), "out"),
		k(0.36, merge(BOW_LOOSE, { waist = { 0, -50, 0 }, root = { 0, -25, 0, 0 } }), "linear"),
	},
	recover = 0.3,
	release = 0.22,
	hit = 0.22,
}

-- Camouflage: a crouch, the cloak pulled around.
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

-- Storm Arrow: the arrow raised to the sky to catch the storm, then a full draw forward.
motions.stormArrow = {
	keys = {
		k(
			0.25,
			merge(STAND, {
				lShoulder = { 160, 20, 0 },
				rShoulder = { 165, -20, 0 },
				rElbow = { 30, 0, 0 },
				waist = { 18, -10, 0 },
			}),
			"out"
		),
		k(
			0.52,
			merge(BOW_DRAW, { rElbow = { 145, 0, 0 }, waist = { 0, -35, 0 }, root = { 0, -10, 0, -0.2 } }),
			"inOut"
		),
		k(0.6, merge(BOW_LOOSE, { waist = { 6, -35, 0 } }), "out"),
	},
	recover = 0.35,
	release = 0.58,
	lock = true,
}

-- Mage ---------------------------------------------------------------------------------------------------------

-- Arcane Bolt (firebolt): a quick flick of the weapon.
motions.firebolt = {
	keys = {
		k(
			0.1,
			{ rShoulder = { 60, 0, 22 }, rElbow = { 85, 0, 0 }, rWrist = { -20, 0, 0 }, waist = { 0, -14, 0 } },
			"out"
		),
		k(
			0.18,
			{ rShoulder = { 98, 0, 0 }, rElbow = { 0, 0, 0 }, rWrist = { 12, 0, 0 }, waist = { -4, 12, 0 } },
			"out"
		),
	},
	recover = 0.22,
	release = 0.16,
}

-- Ice Shard: the hands brought together at the chest, then both pushed forward.
motions.iceShard = {
	keys = {
		k(0.18, {
			rShoulder = { 50, 35, 0 },
			rElbow = { 105, 0, 0 },
			lShoulder = { 50, -35, 0 },
			lElbow = { 105, 0, 0 },
			waist = { 4, 0, 0 },
		}, "out"),
		k(0.28, {
			rShoulder = { 95, 10, 0 },
			rElbow = { 0, 0, 0 },
			lShoulder = { 95, -10, 0 },
			lElbow = { 0, 0, 0 },
			waist = { -8, 0, 0 },
		}, "out"),
	},
	recover = 0.25,
	release = 0.26,
}

-- Blink: a short tense hunch before vanishing.
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
		k(0.2, merge(STAND, { rShoulder = { 20, 0, 40 }, lShoulder = { 20, 0, -40 } }), "out"),
	},
	recover = 0.2,
	hit = 0.1,
}

-- Fireball: energy gathered at the hip with both hands, then pushed forward.
motions.fireball = {
	keys = {
		k(
			0.28,
			merge(STAND, {
				rShoulder = { 30, 20, 35 },
				rElbow = { 95, 0, 0 },
				lShoulder = { 35, -40, 10 },
				lElbow = { 95, 0, 0 },
				waist = { 0, -28, 0 },
				root = { 0, -8, 0, -0.2 },
			}),
			"inOut"
		),
		k(
			0.4,
			merge(lunge(0.5), {
				rShoulder = { 92, 5, 0 },
				rElbow = { 0, 0, 0 },
				lShoulder = { 92, -5, 0 },
				lElbow = { 0, 0, 0 },
				waist = { -6, 18, 0 },
			}),
			"out"
		),
	},
	recover = 0.3,
	release = 0.38,
	hit = 0.38,
}

-- Chain Lightning: the arm thrown back high and hurled forward.
motions.chainLightning = {
	keys = {
		k(
			0.18,
			{ rShoulder = { 145, 0, 40 }, rElbow = { 45, 0, 0 }, lShoulder = { 60, 0, -20 }, waist = { 6, -22, 0 } },
			"out"
		),
		k(
			0.27,
			{ rShoulder = { 85, 15, 0 }, rElbow = { 0, 0, 0 }, lShoulder = { 20, 0, -20 }, waist = { -8, 24, 0 } },
			"in"
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

-- Meteor: both arms raised high for a long call, then brought down.
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
			0.8,
			merge(STAND, {
				rShoulder = { 178, 0, 25 },
				lShoulder = { 178, 0, -25 },
				waist = { 22, 0, 0 },
				root = { 5, 0, 0, 0.35 },
			})
		),
		k(
			0.95,
			merge(STAND, {
				rShoulder = { 90, 0, 10 },
				rElbow = { 0, 0, 0 },
				lShoulder = { 90, 0, -10 },
				lElbow = { 0, 0, 0 },
				waist = { -10, 0, 0 },
			}),
			"in"
		),
	},
	recover = 0.3,
	hit = 0.6,
	lock = true,
}

-- Thunderstorm (firewall): the weapon raised to the clouds, the left hand calling them down.
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
	},
	recover = 0.3,
	hit = 0.42,
}

-- Evocation (channel): rising off the ground, legs loose, the hands circling.
motions.evocation = {
	keys = {
		k(
			0.4,
			merge(air(1, 0.4), {
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
			merge(air(1.2, 0.4), {
				rShoulder = { 100, 30, 20 },
				rElbow = { 40, 0, 0 },
				lShoulder = { 30, -30, -20 },
				lElbow = { 80, 0, 0 },
			}),
			"inOut"
		),
		k(
			1.2,
			merge(
				air(1.3, 0.4),
				{ rShoulder = { 60, 0, 40 }, rElbow = { 60, 0, 0 }, lShoulder = { 60, 0, -40 }, lElbow = { 60, 0, 0 } }
			),
			"inOut"
		),
		k(
			1.6,
			merge(air(1.2, 0.4), {
				rShoulder = { 30, 30, 20 },
				rElbow = { 80, 0, 0 },
				lShoulder = { 100, -30, -20 },
				lElbow = { 40, 0, 0 },
			}),
			"inOut"
		),
		k(
			2,
			merge(
				air(1, 0.4),
				{ rShoulder = { 60, 0, 40 }, rElbow = { 60, 0, 0 }, lShoulder = { 60, 0, -40 }, lElbow = { 60, 0, 0 } }
			),
			"inOut"
		),
		k(2.4, merge(STAND, { rShoulder = { 20, 0, 20 }, lShoulder = { 20, 0, -20 } }), "inOut"),
	},
	recover = 0.3,
	hit = 0.4,
	loop = { from = 0.4, to = 2 },
	lock = true,
}

-- Elemental Fury (meteorStorm): both arms raised, then swept down across the area.
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
			merge(lunge(0.6), { rShoulder = { 70, -50, 0 }, lShoulder = { 70, 50, 0 }, waist = { -15, 0, 0 } }),
			"in"
		),
	},
	recover = 0.35,
	hit = 0.55,
	lock = true,
}

-- Cleric -------------------------------------------------------------------------------------------------------

-- Holy Strike: the mace raised high and brought down.
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
			0.27,
			merge(
				lunge(0.5),
				{ rShoulder = { 30, 0, -10 }, rElbow = { 5, 0, 0 }, lShoulder = { 10, 0, -15 }, waist = { -16, 8, 0 } }
			),
			"in"
		),
	},
	recover = 0.3,
	hit = 0.25,
	trail = { from = 0.16, to = 0.28 },
}

-- Heal: the left hand stretched out towards the ally, the mace at the chest.
motions.heal = {
	keys = {
		k(0.22, {
			lShoulder = { 95, 10, 0 },
			lElbow = { 0, 0, 0 },
			lWrist = { -30, 0, 0 },
			rShoulder = { 45, 40, 0 },
			rElbow = { 100, 0, 0 },
			waist = { 0, 10, 0 },
		}, "out"),
		k(0.5, {
			lShoulder = { 100, 10, 0 },
			lElbow = { 0, 0, 0 },
			lWrist = { -35, 0, 0 },
			rShoulder = { 45, 40, 0 },
			rElbow = { 100, 0, 0 },
			waist = { 2, 10, 0 },
		}),
	},
	recover = 0.25,
	hit = 0.25,
}

-- Renew: hands cupped low, then lifted as if pouring.
motions.renew = {
	keys = {
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
			0.32,
			merge(STAND, {
				rShoulder = { 178, 0, 15 },
				lShoulder = { 30, 0, -80 },
				waist = { 18, 0, 0 },
				root = { 5, 0, 0, 0.3 },
			}),
			"out"
		),
	},
	recover = 0.3,
	hit = 0.3,
}

-- Circle of Light: the mace raised, one slow turn of the body.
motions.circleOfLight = {
	keys = {
		k(
			0.15,
			merge(
				STAND,
				{ rShoulder = { 176, 0, 10 }, rElbow = { 10, 0, 0 }, lShoulder = { 60, 0, -50 }, waist = { 10, 0, 0 } }
			),
			"out"
		),
		k(
			0.6,
			merge(STAND, {
				rShoulder = { 176, 0, 10 },
				lShoulder = { 60, 0, -50 },
				waist = { 10, 0, 0 },
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
	},
	recover = 0.3,
	hit = 0.3,
}

-- Aura of Endurance: arms raised slowly, slightly apart, the head lifted.
motions.auraOfEndurance = {
	keys = {
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

-- Resurrection: kneeling with a hand down to the fallen, then rising with the arms up.
motions.resurrection = {
	keys = {
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
