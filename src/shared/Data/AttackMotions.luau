--!strict
-- Basic attack motions of characters (S22, DESIGN §24; S113 combos, contact poses and clips, DESIGN-16 §5): which
-- motion a weapon type plays, its blows (steps) and their key poses. Logic/AttackPose evaluates them.
-- Angles are degrees in the torso frame around the joint, applied as CFrame.fromEulerAnglesYXZ: first z tilts
-- the hanging limb sideways (+ towards the character's right), then x lifts it forward / up (elbow: + bends,
-- waist: + leans back), then y turns the lifted limb (waist: the body) to the left (+).
-- One step is one blow: rest -> `windup` (anticipation) -> `pass` (the contact, reached accelerating at the server's
-- hit time SERVER_HIT) -> `strike` (end of the blow, decelerating) -> `follow` (overshoot, part of the recovery) ->
-- rest. Times in seconds, squeezed to fit when the attack interval is shorter. The hit fraction of a step is derived
-- from SERVER_HIT (AttackPose.timing), never written here: the server's damage time is not a pose's to change.
-- Steps 2-3 are the combo: consecutive attacks within COMBO_WINDOW play the next step (client looks only; the server,
-- the damage and the attack speed know nothing of it).
-- `clips` / `clipsByWeapon` (S113, docs/ANIMACJE.md "Własne klipy ataków i umiejętności"): real AnimationTracks that
-- play instead of the poses, fitted to SERVER_HIT by their "Hit" marker (Logic/ClipFit); the poses stay the fallback.

-- Joint: "rShoulder" | "rElbow" | "rWrist" | "lShoulder" | "lElbow" | "lWrist" | "waist" (a plain string, so
-- table keys type-check).
export type Joint = string
export type Pose = { [Joint]: { number } }

-- One blow of a basic attack. Poses: rest -> windup (anticipation) -> pass (the contact: the pose at the server's
-- hit time, reached accelerating) -> strike (end of the blow, decelerating) -> follow (overshoot, part of the
-- recovery) -> rest. `pass` and `follow` are optional (without them: windup -> strike -> rest as in S22).
export type Step = {
	windup: number, -- seconds; the pose is reached at the end
	strike: number, -- seconds; the blow lands inside it at SERVER_HIT (the hit fraction is derived)
	recover: number,
	follow: number?, -- 0..1 of `recover` spent reaching `poses.follow` (default FOLLOW_SHARE)
	poses: { windup: Pose, pass: Pose?, strike: Pose, follow: Pose? },
	trail: { from: number, to: number }?, -- seconds of the weapon trail (default windup - 0.02 .. windup + strike + 0.04)
	sfx: { start: string?, swing: string?, release: string? }?, -- Data/Sfx keys; nil = the motion's default (SFX)
	hitstop: number?, -- visual freeze of this pose at the hit, seconds (<= 0.05)
}

-- A real clip: `id` "rbxassetid://<digits>", `hit` the marker name (default "Hit"), `speed` without a marker time,
-- `hitTime` the marker's time at speed 1 (from `/animlab clip`).
export type Clip = { id: string, hit: string?, speed: number?, hitTime: number? }
-- "rbxassetid://…" alone means { id = …, hit = "Hit" }.
export type ClipRef = string | Clip

export type Motion = {
	ranged: boolean,
	steps: { Step }, -- 1..3: step 1 = the single attack, 2..3 = the combo; ranged motions may have one step
	-- Real clips, clips[i] plays as combo step i (the combo then has #clips steps, at most 3). Example:
	-- clips = { { id = "rbxassetid://1234567890", hit = "Hit", hitTime = 0.31 }, "rbxassetid://1234567891" },
	clips: { ClipRef }?,
}

-- MotionName: "slash1h" | "slash2h" | "thrust" | "smash" | "bow" | "crossbow" | "wand" | "staff" | "unarmed".
export type MotionName = string

local motions: { [MotionName]: Motion } = {
	-- One-handed weapons (swords, sabres, axes, sceptres): a diagonal cut, the reverse cut, a thrust to finish.
	-- The weapon sits across the palm (WeaponLooks: tip along the hand's -Z), so the blade's pitch is shoulder + elbow + wrist
	-- (0 = level forward): every contact pose levels it at the target with the wrist.
	slash1h = {
		ranged = false,
		steps = {
			-- Diagonal cut from over the right shoulder down to the left, the blade level with the target at the contact.
			{
				windup = 0.12,
				strike = 0.1,
				recover = 0.25,
				poses = {
					windup = {
						rShoulder = { 150, 0, 35 },
						rElbow = { 45, 0, 0 },
						rWrist = { -5, 0, 0 },
						lShoulder = { 20, 0, -10 },
						waist = { 4, -22, 0 },
					},
					pass = {
						rShoulder = { 70, 0, 12 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 5, 0, -8 },
						waist = { 0, 0, 0 },
					},
					strike = {
						rShoulder = { 35, 25, -30 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { -10, 0, -5 },
						waist = { -6, 20, 0 },
					},
					follow = {
						rShoulder = { 28, 30, -36 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { -12, 0, -5 },
						waist = { -8, 26, 0 },
					},
				},
			},
			-- Reverse cut from the left to the right at chest height (the right arm only: a shield stays in the left hand).
			{
				windup = 0.1,
				strike = 0.13,
				recover = 0.25,
				poses = {
					windup = {
						rShoulder = { 72, 60, 0 },
						rElbow = { 40, 0, 0 },
						rWrist = { -50, 0, 0 },
						waist = { 2, 24, 0 },
					},
					pass = {
						rShoulder = { 70, 0, 0 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						waist = { 0, 0, 0 },
					},
					strike = {
						rShoulder = { 66, -60, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -56, 0, 0 },
						waist = { -4, -20, 0 },
					},
					follow = {
						rShoulder = { 64, -72, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -56, 0, 0 },
						waist = { -4, -28, 0 },
					},
				},
			},
			-- Thrust to finish: the hand pulled back at the hip, the blade level, then straight at the target.
			{
				windup = 0.13,
				strike = 0.1,
				recover = 0.3,
				poses = {
					windup = {
						rShoulder = { -15, -10, 28 },
						rElbow = { 100, 0, 0 },
						rWrist = { -60, 0, 0 },
						waist = { 2, -20, 0 },
					},
					pass = {
						rShoulder = { 45, 0, 10 },
						rElbow = { 40, 0, 0 },
						rWrist = { -60, 0, 0 },
						waist = { -4, 0, 0 },
					},
					strike = {
						rShoulder = { 82, 8, -6 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						waist = { -8, 18, 0 },
					},
					follow = {
						rShoulder = { 87, 11, -8 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						waist = { -9, 21, 0 },
					},
				},
				trail = { from = 0.15, to = 0.27 },
				sfx = { swing = "swing.thrust" },
			},
		},
	},
	-- Two-handed swords and axes: a cut from above, a horizontal sweep, a rising cut; both hands on the hilt.
	slash2h = {
		ranged = false,
		steps = {
			{
				windup = 0.14,
				strike = 0.11,
				recover = 0.3,
				hitstop = 0.035,
				poses = {
					windup = {
						rShoulder = { 165, 0, 12 },
						rElbow = { 45, 0, 0 },
						rWrist = { -20, 0, 0 },
						lShoulder = { 160, 0, 30 },
						lElbow = { 50, 0, 0 },
						lWrist = { -20, 0, 0 },
						waist = { 8, -10, 0 },
					},
					pass = {
						rShoulder = { 70, 0, -4 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 72, 0, 22 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -4, 2, 0 },
					},
					strike = {
						rShoulder = { 34, 0, -8 },
						rElbow = { 0, 0, 0 },
						rWrist = { -50, 0, 0 },
						lShoulder = { 36, 0, 24 },
						lElbow = { 5, 0, 0 },
						lWrist = { -50, 0, 0 },
						waist = { -12, 8, 0 },
					},
					follow = {
						rShoulder = { 26, 0, -10 },
						rElbow = { 0, 0, 0 },
						rWrist = { -50, 0, 0 },
						lShoulder = { 28, 0, 24 },
						lElbow = { 5, 0, 0 },
						lWrist = { -50, 0, 0 },
						waist = { -16, 10, 0 },
					},
				},
			},
			-- Horizontal sweep from the right to the left.
			{
				windup = 0.15,
				strike = 0.11,
				recover = 0.3,
				hitstop = 0.035,
				poses = {
					windup = {
						rShoulder = { 75, -55, 0 },
						rElbow = { 40, 0, 0 },
						rWrist = { -45, 0, 0 },
						lShoulder = { 75, -40, 15 },
						lElbow = { 40, 0, 0 },
						lWrist = { -45, 0, 0 },
						waist = { 0, -30, 0 },
					},
					pass = {
						rShoulder = { 70, 0, 0 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 70, 10, 18 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -2, 0, 0 },
					},
					strike = {
						rShoulder = { 66, 60, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -56, 0, 0 },
						lShoulder = { 66, 70, 18 },
						lElbow = { 5, 0, 0 },
						lWrist = { -56, 0, 0 },
						waist = { -4, 28, 0 },
					},
					follow = {
						rShoulder = { 64, 74, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -56, 0, 0 },
						lShoulder = { 64, 82, 18 },
						lElbow = { 5, 0, 0 },
						lWrist = { -56, 0, 0 },
						waist = { -4, 34, 0 },
					},
				},
			},
			-- Rising cut from the low left up to the right.
			{
				windup = 0.14,
				strike = 0.12,
				recover = 0.3,
				poses = {
					windup = {
						rShoulder = { 20, 40, 20 },
						rElbow = { 10, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 25, 45, 30 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 6, 20, 0 },
					},
					pass = {
						rShoulder = { 80, 10, 8 },
						rElbow = { 10, 0, 0 },
						rWrist = { -50, 0, 0 },
						lShoulder = { 75, 18, 20 },
						lElbow = { 10, 0, 0 },
						lWrist = { -50, 0, 0 },
						waist = { 8, 0, 0 },
					},
					strike = {
						rShoulder = { 150, -20, 0 },
						rElbow = { 15, 0, 0 },
						rWrist = { -20, 0, 0 },
						lShoulder = { 140, -10, 10 },
						lElbow = { 15, 0, 0 },
						lWrist = { -20, 0, 0 },
						waist = { 10, -18, 0 },
					},
					follow = {
						rShoulder = { 160, -28, 0 },
						rElbow = { 15, 0, 0 },
						rWrist = { -15, 0, 0 },
						lShoulder = { 150, -16, 10 },
						lElbow = { 15, 0, 0 },
						lWrist = { -15, 0, 0 },
						waist = { 10, -22, 0 },
					},
				},
			},
		},
	},
	-- Spear: a thrust from the hip, a sweep with the shaft, a high thrust from the shoulder.
	thrust = {
		ranged = false,
		steps = {
			-- Thrust from the hip: pulled back, then both arms drive the point forward.
			{
				windup = 0.12,
				strike = 0.09,
				recover = 0.25,
				poses = {
					windup = {
						rShoulder = { -15, -10, 28 },
						rElbow = { 95, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 45, 0, -25 },
						lElbow = { 40, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 2, -18, 0 },
					},
					pass = {
						rShoulder = { 40, 0, 6 },
						rElbow = { 40, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 60, 0, -16 },
						lElbow = { 15, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -3, 4, 0 },
					},
					strike = {
						rShoulder = { 72, 8, -4 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 72, 0, -10 },
						lElbow = { 5, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -6, 16, 0 },
					},
					follow = {
						rShoulder = { 77, 11, -6 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 75, 0, -9 },
						lElbow = { 5, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -8, 20, 0 },
					},
				},
				trail = { from = 0.15, to = 0.25 },
			},
			-- Sweep with the shaft from the right to the left.
			{
				windup = 0.12,
				strike = 0.1,
				recover = 0.25,
				poses = {
					windup = {
						rShoulder = { 70, -40, 10 },
						rElbow = { 30, 0, 0 },
						rWrist = { -40, 0, 0 },
						lShoulder = { 60, -20, -20 },
						lElbow = { 30, 0, 0 },
						lWrist = { -40, 0, 0 },
						waist = { 0, -20, 0 },
					},
					pass = {
						rShoulder = { 70, 15, 4 },
						rElbow = { 10, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 66, 22, -8 },
						lElbow = { 15, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -2, 8, 0 },
					},
					strike = {
						rShoulder = { 72, 45, 0 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 70, 55, 0 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -4, 25, 0 },
					},
					follow = {
						rShoulder = { 71, 58, 0 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 68, 66, 0 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -4, 32, 0 },
					},
				},
			},
			-- High thrust: the spear drawn back at the shoulder, driven at the head of the target.
			{
				windup = 0.14,
				strike = 0.08,
				recover = 0.28,
				poses = {
					windup = {
						rShoulder = { -30, 0, 20 },
						rElbow = { 110, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 30, 0, -20 },
						lElbow = { 70, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 4, -12, 0 },
					},
					pass = {
						rShoulder = { 45, 0, 8 },
						rElbow = { 45, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 58, 0, -12 },
						lElbow = { 25, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -4, 4, 0 },
					},
					strike = {
						rShoulder = { 92, 0, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 86, 0, -8 },
						lElbow = { 5, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -10, 10, 0 },
					},
					follow = {
						rShoulder = { 97, 0, -2 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 90, 0, -8 },
						lElbow = { 5, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -12, 12, 0 },
					},
				},
				trail = { from = 0.15, to = 0.26 },
			},
		},
	},
	-- Mace / flail / hammer / priest staff: high overhead and down hard, then a heavy side swing.
	smash = {
		ranged = false,
		steps = {
			{
				windup = 0.16,
				strike = 0.12,
				recover = 0.3,
				hitstop = 0.035,
				poses = {
					windup = {
						rShoulder = { 170, 0, 8 },
						rElbow = { 40, 0, 0 },
						rWrist = { -20, 0, 0 },
						lShoulder = { 150, 0, 25 },
						lElbow = { 50, 0, 0 },
						lWrist = { -20, 0, 0 },
						waist = { 12, -6, 0 },
					},
					pass = {
						rShoulder = { 65, 0, 2 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 62, 0, 16 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -6, 2, 0 },
					},
					strike = {
						rShoulder = { 32, 0, -5 },
						rElbow = { 0, 0, 0 },
						rWrist = { -52, 0, 0 },
						lShoulder = { 32, 0, 15 },
						lElbow = { 5, 0, 0 },
						lWrist = { -52, 0, 0 },
						waist = { -18, 4, 0 },
					},
					follow = {
						rShoulder = { 24, 0, -6 },
						rElbow = { 0, 0, 0 },
						rWrist = { -52, 0, 0 },
						lShoulder = { 26, 0, 14 },
						lElbow = { 5, 0, 0 },
						lWrist = { -52, 0, 0 },
						waist = { -22, 4, 0 },
					},
				},
			},
			-- Heavy side swing from the right to the left.
			{
				windup = 0.17,
				strike = 0.1,
				recover = 0.32,
				hitstop = 0.035,
				poses = {
					windup = {
						rShoulder = { 70, -60, 30 },
						rElbow = { 40, 0, 0 },
						rWrist = { -40, 0, 0 },
						lShoulder = { 60, -50, 20 },
						lElbow = { 40, 0, 0 },
						lWrist = { -40, 0, 0 },
						waist = { 6, -30, 0 },
					},
					pass = {
						rShoulder = { 66, 5, 5 },
						rElbow = { 10, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 58, 8, 5 },
						lElbow = { 15, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -2, 0, 0 },
					},
					strike = {
						rShoulder = { 60, 55, -20 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 55, 60, -10 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -10, 30, 0 },
					},
					follow = {
						rShoulder = { 58, 68, -24 },
						rElbow = { 5, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 54, 72, -12 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { -10, 34, 0 },
					},
				},
			},
		},
	},
	-- Bow (in the LEFT hand, along the arm: the wrist turns it upright): the left arm holds the bow towards the
	-- target, the right hand draws the string to the cheek, the body turns side-on; release, the right hand snaps back.
	bow = {
		ranged = true,
		steps = {
			{
				windup = 0.2,
				strike = 0.08,
				recover = 0.25,
				poses = {
					windup = {
						rShoulder = { 90, -45, 0 },
						rElbow = { 120, 0, 0 },
						rWrist = { 0, 0, 0 },
						lShoulder = { 90, 28, 0 },
						lElbow = { 0, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 0, -28, 0 },
					},
					strike = {
						rShoulder = { 88, -65, 0 },
						rElbow = { 150, 0, 0 },
						lShoulder = { 95, 28, 0 },
						lElbow = { 0, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 0, -28, 0 },
					},
					follow = {
						rShoulder = { 85, -80, 0 },
						rElbow = { 140, 0, 0 },
						lShoulder = { 94, 28, 0 },
						lElbow = { 0, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 0, -28, 0 },
					},
				},
			},
		},
	},
	-- Crossbow (left hand on the stock): levelled at the chest, shot without drawing, a short kick upwards.
	crossbow = {
		ranged = true,
		steps = {
			{
				windup = 0.12,
				strike = 0.08,
				recover = 0.25,
				poses = {
					windup = {
						rShoulder = { 55, 30, 0 },
						rElbow = { 60, 0, 0 },
						rWrist = { -40, 0, 0 },
						lShoulder = { 60, 12, 0 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 0, -8, 0 },
					},
					strike = {
						rShoulder = { 62, 30, 0 },
						rElbow = { 65, 0, 0 },
						rWrist = { -40, 0, 0 },
						lShoulder = { 68, 12, 0 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 4, -8, 0 },
					},
					follow = {
						rShoulder = { 66, 30, 0 },
						rElbow = { 65, 0, 0 },
						rWrist = { -40, 0, 0 },
						lShoulder = { 72, 12, 0 },
						lElbow = { 10, 0, 0 },
						lWrist = { -60, 0, 0 },
						waist = { 5, -8, 0 },
					},
				},
			},
		},
	},
	-- Wand: raised back and pointed at the target, then a flick from the left; the bolt leaves the tip.
	wand = {
		ranged = true,
		steps = {
			{
				windup = 0.1,
				strike = 0.06,
				recover = 0.24,
				poses = {
					windup = {
						rShoulder = { 50, 0, 20 },
						rElbow = { 80, 0, 0 },
						rWrist = { -20, 0, 0 },
						lShoulder = { 15, 0, -10 },
						waist = { 0, -12, 0 },
					},
					strike = {
						rShoulder = { 80, 0, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 10, 0, -10 },
						waist = { -4, 10, 0 },
					},
					follow = {
						rShoulder = { 83, 0, -2 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 10, 0, -10 },
						waist = { -4, 12, 0 },
					},
				},
			},
			-- Flick from the left.
			{
				windup = 0.1,
				strike = 0.06,
				recover = 0.24,
				poses = {
					windup = {
						rShoulder = { 70, 40, 0 },
						rElbow = { 60, 0, 0 },
						rWrist = { -30, 0, 0 },
						lShoulder = { 15, 0, -10 },
						waist = { 0, 14, 0 },
					},
					strike = {
						rShoulder = { 80, -10, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 10, 0, -10 },
						waist = { -4, -8, 0 },
					},
					follow = {
						rShoulder = { 79, -18, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 10, 0, -10 },
						waist = { -4, -10, 0 },
					},
				},
			},
		},
	},
	-- Mage staff (upright in the hand, along the arm): the head tipped back, then pushed at the target; then raised
	-- high in front and tipped forward.
	staff = {
		ranged = true,
		steps = {
			{
				windup = 0.12,
				strike = 0.07,
				recover = 0.27,
				poses = {
					windup = {
						rShoulder = { 35, 0, 15 },
						rElbow = { 60, 0, 0 },
						rWrist = { -10, 0, 0 },
						lShoulder = { 30, 0, 20 },
						lElbow = { 70, 0, 0 },
						waist = { 2, -12, 0 },
					},
					strike = {
						rShoulder = { 25, 0, 5 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 20, 0, 25 },
						lElbow = { 30, 0, 0 },
						waist = { -6, 8, 0 },
					},
				},
			},
			-- Raised high in front, then tipped forward at the target.
			{
				windup = 0.12,
				strike = 0.07,
				recover = 0.27,
				poses = {
					windup = {
						rShoulder = { 80, 0, 10 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 60, 0, 20 },
						lElbow = { 40, 0, 0 },
						waist = { 6, -6, 0 },
					},
					strike = {
						rShoulder = { 40, 0, 0 },
						rElbow = { 0, 0, 0 },
						rWrist = { -60, 0, 0 },
						lShoulder = { 40, 0, 25 },
						lElbow = { 30, 0, 0 },
						waist = { -6, 6, 0 },
					},
				},
			},
		},
	},
	-- Fists: a right straight, a left straight, a right uppercut.
	unarmed = {
		ranged = false,
		steps = {
			{
				windup = 0.1,
				strike = 0.08,
				recover = 0.2,
				poses = {
					windup = {
						rShoulder = { 35, -15, 22 },
						rElbow = { 125, 0, 0 },
						lShoulder = { 55, 0, -15 },
						lElbow = { 110, 0, 0 },
						waist = { 0, -18, 0 },
					},
					pass = {
						rShoulder = { 74, 0, 2 },
						rElbow = { 45, 0, 0 },
						lShoulder = { 55, 0, -15 },
						lElbow = { 112, 0, 0 },
						waist = { -2, 4, 0 },
					},
					strike = {
						rShoulder = { 90, 10, -5 },
						rElbow = { 5, 0, 0 },
						lShoulder = { 55, 0, -15 },
						lElbow = { 115, 0, 0 },
						waist = { -4, 16, 0 },
					},
					follow = {
						rShoulder = { 94, 12, -7 },
						rElbow = { 5, 0, 0 },
						lShoulder = { 55, 0, -15 },
						lElbow = { 115, 0, 0 },
						waist = { -5, 19, 0 },
					},
				},
			},
			-- Left straight (fists only: no shield or off-hand item is held with this motion).
			{
				windup = 0.1,
				strike = 0.08,
				recover = 0.2,
				poses = {
					windup = {
						lShoulder = { 35, 15, -22 },
						lElbow = { 125, 0, 0 },
						rShoulder = { 55, 0, 15 },
						rElbow = { 110, 0, 0 },
						waist = { 0, 18, 0 },
					},
					pass = {
						lShoulder = { 74, 0, -2 },
						lElbow = { 45, 0, 0 },
						rShoulder = { 55, 0, 15 },
						rElbow = { 112, 0, 0 },
						waist = { -2, -4, 0 },
					},
					strike = {
						lShoulder = { 90, -10, 5 },
						lElbow = { 5, 0, 0 },
						rShoulder = { 55, 0, 15 },
						rElbow = { 115, 0, 0 },
						waist = { -4, -16, 0 },
					},
					follow = {
						lShoulder = { 94, -12, 7 },
						lElbow = { 5, 0, 0 },
						rShoulder = { 55, 0, 15 },
						rElbow = { 115, 0, 0 },
						waist = { -5, -19, 0 },
					},
				},
			},
			-- Right uppercut.
			{
				windup = 0.11,
				strike = 0.08,
				recover = 0.22,
				poses = {
					windup = {
						rShoulder = { 20, -12, 14 },
						rElbow = { 110, 0, 0 },
						lShoulder = { 50, 0, -15 },
						lElbow = { 110, 0, 0 },
						waist = { 4, -12, 0 },
					},
					pass = {
						rShoulder = { 80, 0, 4 },
						rElbow = { 90, 0, 0 },
						lShoulder = { 50, 0, -15 },
						lElbow = { 110, 0, 0 },
						waist = { -2, 0, 0 },
					},
					strike = {
						rShoulder = { 120, 8, 0 },
						rElbow = { 70, 0, 0 },
						lShoulder = { 50, 0, -15 },
						lElbow = { 110, 0, 0 },
						waist = { -8, 10, 0 },
					},
					follow = {
						rShoulder = { 128, 10, -2 },
						rElbow = { 68, 0, 0 },
						lShoulder = { 50, 0, -15 },
						lElbow = { 110, 0, 0 },
						waist = { -9, 12, 0 },
					},
				},
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

-- Real clips of one weapon type, over its motion's clips (Logic/ClipFit.attackClip). Example:
-- axe1h = { { id = "rbxassetid://1234567890", hit = "Hit", hitTime = 0.28 } },
local clipsByWeapon: { [string]: { ClipRef } } = {}

return table.freeze({
	motions = motions,
	byWeapon = byWeapon,
	offhand = OFFHAND,
	clipsByWeapon = clipsByWeapon,
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
	-- Seconds from the start of a basic attack until the blow lands / the shot leaves: the server waits this long
	-- (plus the projectile's flight) before the damage (AttackPose.hitDelay, FIX 2026-10-09). Values of S81 (4d533e2);
	-- the poses (every combo step, every clip) are timed to them, never the other way round. Changing one is a
	-- balance change (DESIGN-16 §0.2).
	SERVER_HIT = table.freeze({
		slash1h = 0.18,
		slash2h = 0.2115,
		thrust = 0.183,
		smash = 0.235,
		bow = 0.2,
		crossbow = 0.12,
		wand = 0.136,
		staff = 0.167,
		unarmed = 0.156,
	} :: { [MotionName]: number }),
	COMBO_WINDOW = 1.5, -- seconds from the previous attack's start that keep a combo going (client only)
	FOLLOW_SHARE = 0.35, -- default share of `recover` spent reaching the follow pose
	-- Default sounds of a motion (Data/Sfx keys; a step's `sfx` overrides them): `start` at the start of the windup,
	-- `swing` at the start of the blow (the end of the windup), `release` at SERVER_HIT (the shot leaves).
	SFX = table.freeze({
		slash1h = { swing = "swing.light" },
		slash2h = { swing = "swing.heavy" },
		thrust = { swing = "swing.thrust" },
		smash = { swing = "swing.blunt" },
		unarmed = { swing = "swing.light" },
		bow = { start = "bow.draw", release = "bow.release" },
		crossbow = { release = "crossbow.release" },
		wand = { release = "wand.cast" },
		staff = { release = "wand.cast" },
	} :: { [MotionName]: { start: string?, swing: string?, release: string? } }),
	-- A hit character's reaction (looks only, Logic/AttackPose.flinch): seconds, degrees of the waist (critical hits
	-- more), the shoulders' share (a monster's push since S117: Config.MonsterLook.hitLean / hitPush, Gait.hitLean).
	FLINCH = table.freeze({ seconds = 0.18, degrees = 5, critDegrees = 9, shoulder = 0.35 }),
	-- The weapon trail of a basic attack (Vfx/Library.weaponTrail with basic = true): lifetime, texture, where along
	-- the weapon it starts (share of the grip-to-tip length; a mace's head: baseByMotion), widths at the tip and base.
	TRAIL = table.freeze({
		lifetime = 0.18,
		key = "trailStreak",
		base = 0.35,
		widthTip = 1,
		widthBase = 0.35,
		baseByMotion = table.freeze({ smash = 0.6 } :: { [MotionName]: number }),
	}),
})
