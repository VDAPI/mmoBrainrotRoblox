--!strict
-- Basic attack motions of characters (S22, DESIGN §24): which motion a weapon type plays and its key poses.
-- Angles are degrees in the torso frame around the joint, applied as CFrame.fromEulerAnglesYXZ: first z tilts
-- the hanging limb sideways (+ towards the character's right), then x lifts it forward / up (elbow: + bends,
-- waist: + leans back), then y turns the lifted limb (waist: the body) to the left (+).
-- A motion goes rest -> `windup` pose (raise / draw) -> `strike` pose (cut / release) -> rest; times in seconds,
-- squeezed to fit when the attack interval is shorter. `hit` is where in the strike the blow lands (melee) or
-- the arrow / bolt leaves (ranged, 0 = at the end of the windup). Logic/AttackPose evaluates them.

-- Joint: "rShoulder" | "rElbow" | "rWrist" | "lShoulder" | "lElbow" | "lWrist" | "waist" (a plain string, so
-- table keys type-check).
export type Joint = string
export type Pose = { [Joint]: { number } }

export type Motion = {
	windup: number,
	strike: number,
	recover: number,
	hit: number, -- 0..1 of the strike phase
	ranged: boolean,
	poses: { windup: Pose, strike: Pose },
}

-- MotionName: "slash1h" | "slash2h" | "thrust" | "smash" | "bow" | "crossbow" | "wand" | "staff" | "unarmed".
export type MotionName = string

local motions: { [MotionName]: Motion } = {
	-- One-handed cut: from over the right shoulder diagonally across the target, a small twist of the body.
	slash1h = {
		windup = 0.12,
		strike = 0.1,
		recover = 0.25,
		hit = 0.6,
		ranged = false,
		poses = {
			windup = {
				rShoulder = { 150, 0, 35 },
				rElbow = { 55, 0, 0 },
				rWrist = { -25, 0, 0 },
				lShoulder = { 20, 0, -10 },
				waist = { 4, -22, 0 },
			},
			strike = {
				rShoulder = { 45, 0, -45 },
				rElbow = { 10, 0, 0 },
				rWrist = { 20, 0, 0 },
				lShoulder = { -10, 0, -5 },
				waist = { -6, 20, 0 },
			},
		},
	},
	-- Two-handed cut from above: both hands on the hilt.
	slash2h = {
		windup = 0.14,
		strike = 0.11,
		recover = 0.3,
		hit = 0.65,
		ranged = false,
		poses = {
			windup = {
				rShoulder = { 165, 0, 12 },
				rElbow = { 50, 0, 0 },
				lShoulder = { 160, 0, 30 },
				lElbow = { 55, 0, 0 },
				waist = { 8, -10, 0 },
			},
			strike = {
				rShoulder = { 45, 0, -8 },
				rElbow = { 10, 0, 0 },
				lShoulder = { 45, 0, 22 },
				lElbow = { 15, 0, 0 },
				waist = { -12, 8, 0 },
			},
		},
	},
	-- Spear thrust: pulled back, then the arm shoots forward.
	thrust = {
		windup = 0.12,
		strike = 0.09,
		recover = 0.25,
		hit = 0.7,
		ranged = false,
		poses = {
			windup = {
				rShoulder = { 60, 0, 15 },
				rElbow = { 100, 0, 0 },
				lShoulder = { 70, 0, -25 },
				lElbow = { 40, 0, 0 },
				waist = { 2, -18, 0 },
			},
			strike = {
				rShoulder = { 88, 0, 0 },
				rElbow = { 0, 0, 0 },
				lShoulder = { 75, 0, -10 },
				lElbow = { 10, 0, 0 },
				waist = { -6, 16, 0 },
			},
		},
	},
	-- Hammer / mace / priest staff: high overhead, down hard.
	smash = {
		windup = 0.16,
		strike = 0.1,
		recover = 0.3,
		hit = 0.75,
		ranged = false,
		poses = {
			windup = {
				rShoulder = { 175, 0, 8 },
				rElbow = { 45, 0, 0 },
				lShoulder = { 150, 0, 25 },
				lElbow = { 50, 0, 0 },
				waist = { 12, -6, 0 },
			},
			strike = {
				rShoulder = { 25, 0, -5 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 30, 0, 15 },
				lElbow = { 10, 0, 0 },
				waist = { -18, 4, 0 },
			},
		},
	},
	-- Bow (in the LEFT hand): the left arm holds the bow towards the target, the right hand draws the string to
	-- the cheek, the body turns side-on; release, the right hand snaps back.
	bow = {
		windup = 0.2,
		strike = 0.08,
		recover = 0.25,
		hit = 0,
		ranged = true,
		poses = {
			windup = {
				lShoulder = { 90, 28, 0 },
				lElbow = { 0, 0, 0 },
				lWrist = { 0, 0, 0 },
				rShoulder = { 90, -45, 0 },
				rElbow = { 120, 0, 0 },
				rWrist = { 0, 0, 0 },
				waist = { 0, -28, 0 },
			},
			strike = {
				lShoulder = { 95, 28, 0 },
				lElbow = { 0, 0, 0 },
				rShoulder = { 88, -65, 0 },
				rElbow = { 150, 0, 0 },
				waist = { 0, -28, 0 },
			},
		},
	},
	-- Crossbow (left hand on the stock): raised to the shoulder, shot without drawing, a short kick.
	crossbow = {
		windup = 0.12,
		strike = 0.08,
		recover = 0.25,
		hit = 0,
		ranged = true,
		poses = {
			windup = {
				lShoulder = { 88, 12, 0 },
				lElbow = { 20, 0, 0 },
				rShoulder = { 82, 30, 0 },
				rElbow = { 70, 0, 0 },
				waist = { 0, -8, 0 },
			},
			strike = {
				lShoulder = { 100, 12, 0 },
				lElbow = { 25, 0, 0 },
				rShoulder = { 94, 30, 0 },
				rElbow = { 75, 0, 0 },
				waist = { 4, -8, 0 },
			},
		},
	},
	-- Wand: pulled back, pushed at the target; the bolt leaves the tip.
	wand = {
		windup = 0.12,
		strike = 0.08,
		recover = 0.22,
		hit = 0.2,
		ranged = true,
		poses = {
			windup = {
				rShoulder = { 55, 0, 20 },
				rElbow = { 85, 0, 0 },
				rWrist = { -20, 0, 0 },
				lShoulder = { 15, 0, -10 },
				waist = { 0, -12, 0 },
			},
			strike = {
				rShoulder = { 95, 0, 0 },
				rElbow = { 0, 0, 0 },
				rWrist = { 10, 0, 0 },
				lShoulder = { 10, 0, -10 },
				waist = { -4, 10, 0 },
			},
		},
	},
	-- Staff (mage): both hands, the head of the staff thrust forward.
	staff = {
		windup = 0.14,
		strike = 0.09,
		recover = 0.25,
		hit = 0.3,
		ranged = true,
		poses = {
			windup = {
				rShoulder = { 70, 0, 15 },
				rElbow = { 95, 0, 0 },
				lShoulder = { 50, 0, 20 },
				lElbow = { 90, 0, 0 },
				waist = { 2, -12, 0 },
			},
			strike = {
				rShoulder = { 100, 0, 0 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 78, 0, 25 },
				lElbow = { 40, 0, 0 },
				waist = { -6, 8, 0 },
			},
		},
	},
	-- Fist.
	unarmed = {
		windup = 0.1,
		strike = 0.08,
		recover = 0.2,
		hit = 0.7,
		ranged = false,
		poses = {
			windup = {
				rShoulder = { 65, 0, 15 },
				rElbow = { 125, 0, 0 },
				lShoulder = { 60, 0, -15 },
				lElbow = { 110, 0, 0 },
				waist = { 0, -18, 0 },
			},
			strike = {
				rShoulder = { 90, 0, -5 },
				rElbow = { 5, 0, 0 },
				lShoulder = { 55, 0, -15 },
				lElbow = { 115, 0, 0 },
				waist = { -4, 16, 0 },
			},
		},
	},
}

-- Weapon item type (Items / WeaponLooks) -> motion. Off-hand items (shield, quiver, tome, orb, relic) never
-- attack and are not listed.
local byWeapon: { [string]: MotionName } = {
	sword1h = "slash1h",
	saber1h = "slash1h",
	axe1h = "slash1h",
	scepter = "slash1h",
	sword2h = "slash2h",
	axe2h = "slash2h",
	spear2h = "thrust",
	mace1h = "smash",
	flail1h = "smash",
	hammer2h = "smash",
	holystaff = "smash",
	bow = "bow",
	shortbow = "bow",
	longbow = "bow",
	crossbow = "crossbow",
	heavycrossbow = "crossbow",
	wand = "wand",
	staff = "staff",
	runestaff = "staff",
}

local OFFHAND: { [string]: boolean } = { shield = true, quiver = true, tome = true, orb = true, relic = true }

return table.freeze({
	motions = motions,
	byWeapon = byWeapon,
	offhand = OFFHAND,
	JOINTS = { "rShoulder", "rElbow", "rWrist", "lShoulder", "lElbow", "lWrist", "waist" } :: { Joint },
	-- Joint angle limits (degrees, absolute) the tests hold every key pose to.
	LIMITS = table.freeze({
		rShoulder = 180,
		lShoulder = 180,
		rElbow = 155,
		lElbow = 155,
		rWrist = 60,
		lWrist = 60,
		waist = 35,
	} :: { [Joint]: number }),
})
