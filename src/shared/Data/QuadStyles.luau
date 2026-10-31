--!strict
-- Template animation (owner 2026-10-25, docs/ANIM-WZORCE.md F2): the styles of imported quadrupeds animated by
-- Logic/QuadMotion (controls in Logic/QuadPose; distances in leg lengths, angles in radians).
-- * `gaits`: walk, trot, gallop: footfall phase of each leg (left hind = 0), duty (share of the cycle a foot is down),
--   stride k (cycle length in leg lengths), fold of the swinging leg and the paw, body bob / roll / gallop pitch and
--   spine flex, the neck's carriage, the tail's lift and sway; `thresholds`: speed over leg length where trot and
--   gallop take over;
-- * `stance`: added while it fights; `calm`: added while it goes home; `idle.tail`: the tail at rest;
-- * `actions`: keyed motions on Logic/MotionTimeline (anticipation stretched to the server's windup, the strike ending on
--   the hit), the pose of a key laid over the stance; `tremble`: the gather's shake at its end (rad);
-- * `flinch`: additive controls by side; `fidgets`: idle actions now and then (every `fidgetEvery` s).

local MotionTimeline = require("../Logic/MotionTimeline")

local QuadStyles = {}

export type Gait = {
	foot: { [string]: number },
	duty: number,
	dutyFront: number?,
	k: number,
	foldStance: number,
	foldFront: number,
	foldHind: number,
	pawFront: number,
	pawHind: number,
	bob: number,
	pitch: number,
	flex: number,
	roll: number,
	spineYaw: number,
	neck: number,
	tail: number,
	tailSway: number,
	-- the heavy quadrupeds (bear, boar, mammoth): the feet planted on the ground by Logic/QuadPose's foot solver
	-- (`plant`, swing height `lift` / `liftFront` in leg lengths), plantigrade feet kept flat (`level` 0..1), the
	-- roll turning about the feet that bear the weight (`rollPivot`: half the stance width), the head swaying with the
	-- steps (`headSway`), the body carried lower so straight legs reach the ends of the stride (`drop`, leg lengths)
	plant: boolean?,
	lift: number?,
	liftFront: number?,
	level: number?,
	rollPivot: number?,
	headSway: number?,
	drop: number?,
	-- the dragon (studio review 2026-10-31): the shoulders carried lower than the hips by a nose-down pitch (`stoop`,
	-- rad) so the long fore legs are not straight at the ends of the stride, and a swing that keeps the foot on its
	-- print as it leaves and lands (`onPrint`: its ground speed 0 at the lift-off and the touchdown, the lift rising
	-- and falling gently; a real spawn's run skimmed the ground a stud each step)
	stoop: number?,
	onPrint: boolean?,
	levelIn: number?, -- the share of the swing the paw takes to level before the touchdown (0.4)
}
-- A dragon's wings (Logic/DragonMotion, 2026-10-31): the procedural fold (`fold`: the elbow and wrist folds and the
-- other joints' bends, rad; the humerus' direction and the membrane's top side wanted, the right wing's, model frame),
-- one wingbeat (`beat`: Data/FlyerStyles Mode's stroke on the flat wing: elevation at the top and the bottom, sweep
-- forward on the downstroke and back on the upstroke, the upstroke's fold and twist), the gallop's pump (`pump`: the
-- wings opened by `open` and held up with tension: lifted by `lift`, the hand and the fingers bent up by `hand` and
-- `tips`, rad; a beat of `amp` a stride, its downstroke starting at gait phase `at`) and the tail's spring (`tail`: Hz,
-- damping ratio, gain).
export type Wings = {
	fold: { f: number, h: number, b: number?, w: number?, p: number?, q: number?, hum: { number }, nrm: { number } },
	beat: { top: number, bottom: number, fore: number, back: number, fold: number, twist: number },
	pump: { open: number, amp: number, at: number, lift: number, hand: number, tips: number },
	tail: { hz: number, damp: number, gain: number },
}
export type Style = {
	gaits: { [string]: Gait },
	thresholds: { trot: number, gallop: number },
	stance: { [string]: number },
	calm: { [string]: number },
	idle: { tail: number },
	actions: { [string]: MotionTimeline.Action },
	flinch: { [string]: { [string]: number } },
	basic: { string },
	abilities: { [string]: string },
	throw: string?,
	death: { string },
	-- (the dragon, 2026-10-31) the deaths by the side the killing blow came from (QuadMotion.side), as BipedStyles
	deaths: { [string]: { string } }?,
	aggro: string?,
	spawn: string?,
	fidgets: { string },
	fidgetEvery: { number },
	rate: number,
	-- a trunk that swings like a pendulum behind the head (Hz, damping ratio, gain) and ears that fan now and then
	trunk: { hz: number, damp: number, gain: number, arm: number, height: number }?,
	earFlap: { every: number, amp: number }?,
	-- added while it stands, scaled by stillness (a heavy quadruped's planted feet)
	ground: { [string]: number }?,
	-- a dragon (2026-10-31): its wings (Logic/DragonMotion), the tail bones the sways reach (default 4), the gait
	-- taken from the server's `Gait` (walk / trot / run: walk / trot / gallop, stepping down when too slow for it),
	-- the dazed pose of the server's stun (it also holds the pose while frozen) and AnimLab's extra states
	wings: Wings?,
	tailBones: number?,
	serverGait: boolean?,
	-- (the dragon, 2026-10-31) the ground speed (leg lengths a second) from which it steps (default 0.3): below it the
	-- planted feet stand still while the root moves on, a glide; a creep as slow as this still walks, short and slow
	stepFrom: number?,
	stun: { [string]: number }?,
	labExtra: { string }?,
}

local function deg(d: number): number
	return math.rad(d)
end

local function from(base: { [string]: number }, over: { [string]: number }): { [string]: number }
	local out = table.clone(base)
	for k, v in over do
		out[k] = v
	end
	return out
end

---------------------------------------------------------------- canine (wolf)

-- The fighting stance: weight a little low, head low and forward with the eyes level, ears up, tail level.
local STANCE = {
	by = -0.03,
	bpitch = deg(-2),
	npitch = deg(10),
	hpitch = deg(-6),
	earL = deg(-6),
	earR = deg(-6),
	tpitch = deg(5),
}
local function s(over: { [string]: number }): { [string]: number }
	return from(STANCE, over)
end

local LEGS_BACK = function(d: number): { [string]: number }
	-- every leg angled by `d` (the body moved forward of the planted feet: negative; back: positive)
	return { FLu = d, FRu = d, HLu = d, HRu = d }
end
local function merge(...: { [string]: number }): { [string]: number }
	local out = {}
	for _, t in { ... } do
		for k, v in t do
			out[k] = v
		end
	end
	return out
end

local CANINE: Style = {
	gaits = {
		walk = {
			foot = { HL = 0, FL = 0.25, HR = 0.5, FR = 0.75 },
			duty = 0.65,
			k = 1.2,
			foldStance = deg(5),
			foldFront = deg(42),
			foldHind = deg(32),
			pawFront = deg(25),
			pawHind = deg(12),
			bob = 0.015,
			pitch = 0,
			flex = 0,
			roll = deg(1.5),
			spineYaw = deg(3),
			neck = deg(4),
			tail = deg(-4),
			tailSway = deg(5),
		},
		trot = {
			foot = { HL = 0, FR = 0.02, HR = 0.5, FL = 0.52 },
			duty = 0.45,
			k = 1.8,
			foldStance = deg(6),
			foldFront = deg(58),
			foldHind = deg(42),
			pawFront = deg(40),
			pawHind = deg(18),
			bob = 0.035,
			pitch = 0,
			flex = 0,
			roll = deg(2),
			spineYaw = deg(1.5),
			neck = deg(6),
			tail = deg(10),
			tailSway = deg(4),
		},
		gallop = {
			foot = { HL = 0, HR = 0.1, FR = 0.42, FL = 0.52 },
			duty = 0.3,
			dutyFront = 0.28,
			k = 3.3,
			foldStance = deg(8),
			foldFront = deg(95),
			foldHind = deg(60),
			pawFront = deg(70),
			pawHind = deg(30),
			bob = 0.07,
			pitch = deg(5),
			flex = deg(10),
			roll = 0,
			spineYaw = 0,
			neck = deg(8),
			tail = deg(10),
			tailSway = deg(3),
		},
	},
	thresholds = { trot = 1.7, gallop = 3.8 },
	stance = STANCE,
	calm = { npitch = deg(8), tpitch = deg(-10) },
	idle = { tail = deg(-5) },
	basic = { "bite" },
	abilities = { leap = "leap", heavyBlow = "maul", crush = "rear", pounce = "pounce", slam = "rear", charge = "leap" },
	throw = "toss",
	death = { "deathL", "deathR" },
	aggro = "snarl",
	spawn = "spawn",
	fidgets = { "sniff", "shake" },
	fidgetEvery = { 6, 12 },
	rate = 0.06,
	flinch = {
		front = { bz = 0.1, bpitch = deg(6), hpitch = deg(-8), earL = deg(25), earR = deg(25), tpitch = deg(-15) },
		back = { bz = -0.06, bpitch = deg(-4), HLf = deg(10), HRf = deg(10), tpitch = deg(-20) },
		left = { broll = deg(-7), bx = 0.08, syaw = deg(-6), hyaw = deg(12) },
		right = { broll = deg(7), bx = -0.08, syaw = deg(6), hyaw = deg(-12) },
	},
	actions = {
		-- the bite (W 0.55; owner 2026-10-26: "a short hop and a bite"): a quick crouch with the jaw opening, a low hop of
		-- about 0.75 leg lengths at the target with the fore legs reaching and the hind legs pushing off, the jaws snap
		-- shut as the fore paws land on the server's hit, a head toss, then two short steps back to the stance
		bite = {
			strike = 0.3,
			follow = 0.17,
			recover = 0.42,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = s(merge(LEGS_BACK(0.1), {
						bz = 0.1,
						by = -0.1,
						bpitch = deg(-3),
						HLf = deg(32),
						HRf = deg(32),
						FLf = deg(12),
						FRf = deg(12),
						npitch = deg(4),
						hpitch = deg(-4),
						jaw = deg(18),
						earL = deg(30),
						earR = deg(30),
						tpitch = deg(-6),
					})),
				},
				{
					seg = "S",
					u = 0.18,
					ease = "out",
					pose = s({
						bz = -0.08,
						by = 0.0,
						bpitch = deg(9),
						HLu = deg(-32),
						HRu = deg(-32),
						HLf = 0,
						HRf = 0,
						HLp = deg(-10),
						HRp = deg(-10),
						FLu = deg(22),
						FRu = deg(22),
						FLf = deg(25),
						FRf = deg(25),
						npitch = deg(2),
						hpitch = deg(-8),
						jaw = deg(28),
						earL = deg(35),
						earR = deg(35),
						tpitch = deg(2),
					}),
				},
				{
					seg = "S",
					u = 0.6,
					ease = "lin",
					pose = s({
						bz = -0.45,
						by = 0.2,
						bpitch = deg(1),
						sflex = deg(-6),
						HLu = deg(-38),
						HRu = deg(-38),
						HLf = deg(8),
						HRf = deg(8),
						FLu = deg(34),
						FRu = deg(34),
						FLf = deg(6),
						FRf = deg(6),
						npitch = deg(10),
						hpitch = deg(-2),
						jaw = deg(34),
						earL = deg(35),
						earR = deg(35),
						tpitch = deg(6),
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = s({
						bz = -0.75,
						by = -0.1,
						bpitch = deg(-11),
						HLu = deg(-14),
						HRu = deg(-14),
						HLf = deg(14),
						HRf = deg(14),
						FLu = deg(8),
						FRu = deg(8),
						FLf = deg(26),
						FRf = deg(26),
						npitch = deg(42),
						hpitch = deg(18),
						jaw = 0,
						earL = deg(25),
						earR = deg(25),
						tpitch = deg(-4),
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = s({
						bz = -0.72,
						by = -0.04,
						bpitch = deg(-3),
						HLu = deg(-10),
						HRu = deg(-10),
						FLu = deg(-4),
						FRu = deg(-4),
						npitch = deg(14),
						hpitch = deg(-6),
						hyaw = deg(16),
						nyaw = deg(8),
						jaw = deg(4),
						earL = deg(15),
						earR = deg(15),
					}),
				},
				{
					seg = "R",
					u = 0.5,
					ease = "inout",
					pose = s({
						bz = -0.35,
						by = 0.02,
						FLu = deg(14),
						HRu = deg(16),
						FRu = deg(-8),
						HLu = deg(-10),
						FLf = deg(30),
						HRf = deg(25),
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = STANCE },
			},
		},
		-- Leap (Elite II, W 1.2): crouch and aim, a trembling hold, then the spring and the flight onto the target
		leap = {
			strike = 0.35,
			follow = 0.25,
			recover = 0.5,
			legs = true,
			travel = true,
			tremble = deg(1.5),
			keys = {
				{
					seg = "A",
					u = 0.3,
					ease = "out",
					pose = s(merge(LEGS_BACK(0.18), {
						by = -0.15,
						bz = 0.2,
						bpitch = deg(-3),
						HLf = deg(45),
						HRf = deg(45),
						FLf = deg(15),
						FRf = deg(15),
						FLo = deg(5),
						FRo = deg(5),
						npitch = deg(12),
						hpitch = deg(-10),
						earL = deg(40),
						earR = deg(40),
						tpitch = 0,
					})),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = s(merge(LEGS_BACK(0.2), {
						by = -0.15,
						bz = 0.21,
						bpitch = deg(-5),
						HLf = deg(48),
						HRf = deg(48),
						FLf = deg(15),
						FRf = deg(15),
						FLo = deg(5),
						FRo = deg(5),
						npitch = deg(12),
						hpitch = deg(-10),
						earL = deg(40),
						earR = deg(40),
						tpitch = 0,
					})),
				},
				{
					seg = "S",
					u = 0.15,
					ease = "out",
					pose = s({
						by = 0.02,
						bz = 0.05,
						bpitch = deg(12),
						HLu = deg(-30),
						HRu = deg(-30),
						HLf = 0,
						HRf = 0,
						FLu = deg(25),
						FRu = deg(25),
						npitch = deg(4),
						hpitch = deg(-8),
						earL = deg(40),
						earR = deg(40),
						jaw = deg(25),
						travel = 0.1,
					}),
				},
				{
					seg = "S",
					u = 0.6,
					ease = "lin",
					pose = s({
						by = 0.45,
						bpitch = deg(2),
						sflex = deg(-8),
						FLu = deg(40),
						FRu = deg(40),
						FLf = 0,
						FRf = 0,
						HLu = deg(-35),
						HRu = deg(-35),
						npitch = deg(6),
						hpitch = deg(-6),
						jaw = deg(35),
						earL = deg(45),
						earR = deg(45),
						tpitch = deg(5),
						travel = 0.62,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = s({
						by = -0.06,
						bpitch = deg(-10),
						FLu = deg(10),
						FRu = deg(10),
						FLf = deg(12),
						FRf = deg(12),
						HLu = deg(-20),
						HRu = deg(-20),
						npitch = deg(20),
						hpitch = deg(8),
						jaw = 0,
						earL = deg(30),
						earR = deg(30),
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = s({
						by = -0.04,
						bpitch = deg(-5),
						npitch = deg(14),
						hyaw = deg(10),
						jaw = deg(8),
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = s({ by = -0.04, bpitch = deg(-4), npitch = deg(12), hyaw = deg(-10), travel = 1 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = from(STANCE, { travel = 1 }) },
			},
		},
		-- Heavy Blow (Elite, W 1.8) "maul": a fore paw raised, the head cocked and snarling, then a sweep across the
		-- cone, the paw slamming down with the jaw
		maul = {
			strike = 0.14,
			follow = 0.3,
			recover = 0.35,
			legs = true,
			tremble = deg(1.2),
			keys = {
				{
					seg = "A",
					u = 0.55,
					ease = "out",
					pose = s(merge(LEGS_BACK(0.15), {
						bz = 0.2,
						bpitch = deg(10),
						FRu = deg(35),
						FRf = deg(60),
						FRp = deg(20),
						hyaw = deg(20),
						nyaw = deg(8),
						npitch = deg(-10),
						jaw = deg(35),
						earL = deg(40),
						earR = deg(40),
						tpitch = deg(-10),
					})),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = s(merge(LEGS_BACK(0.16), {
						bz = 0.21,
						bpitch = deg(11),
						FRu = deg(38),
						FRf = deg(62),
						FRp = deg(20),
						hyaw = deg(22),
						nyaw = deg(9),
						npitch = deg(-11),
						jaw = deg(30),
						earL = deg(42),
						earR = deg(42),
						tpitch = deg(-10),
					})),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = s(merge(LEGS_BACK(-0.2), {
						bz = -0.25,
						bpitch = deg(-6),
						FRu = deg(-6),
						FRf = 0,
						hyaw = deg(-25),
						nyaw = deg(-10),
						npitch = deg(18),
						jaw = 0,
						earL = deg(35),
						earR = deg(35),
					})),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = s(
						merge(
							LEGS_BACK(-0.18),
							{ bz = -0.22, hyaw = deg(-30), nyaw = deg(-12), npitch = deg(16), jaw = deg(6) }
						)
					),
				},
				{ seg = "R", u = 1, ease = "inout", pose = STANCE },
			},
		},
		-- Crush (Elite II, W 2.2) "rear and slam": up on the hind legs with the fore legs folded high, a long hold, then
		-- both fore paws slam down
		rear = {
			strike = 0.14,
			follow = 0.3,
			recover = 0.4,
			legs = true,
			full = true,
			tremble = deg(2),
			keys = {
				{
					seg = "A",
					u = 0.27,
					ease = "inout",
					pose = s({
						by = 0.3,
						bz = 0.3,
						bpitch = deg(52),
						HLu = deg(-48),
						HRu = deg(-48),
						HLf = deg(20),
						HRf = deg(20),
						FLu = deg(10),
						FRu = deg(10),
						FLf = deg(85),
						FRf = deg(85),
						FLp = deg(30),
						FRp = deg(30),
						npitch = deg(30),
						hpitch = deg(15),
						jaw = deg(30),
						earL = deg(35),
						earR = deg(35),
						tpitch = deg(-25),
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = s({
						by = 0.33,
						bz = 0.3,
						bpitch = deg(55),
						HLu = deg(-50),
						HRu = deg(-50),
						HLf = deg(22),
						HRf = deg(22),
						FLu = deg(14),
						FRu = deg(14),
						FLf = deg(90),
						FRf = deg(90),
						FLp = deg(30),
						FRp = deg(30),
						npitch = deg(32),
						hpitch = deg(16),
						jaw = deg(34),
						earL = deg(40),
						earR = deg(40),
						tpitch = deg(-25),
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = s(merge(LEGS_BACK(-0.1), {
						by = -0.08,
						bz = -0.12,
						bpitch = deg(-8),
						FLu = deg(25),
						FRu = deg(25),
						FLf = 0,
						FRf = 0,
						npitch = deg(18),
						jaw = deg(10),
						tpitch = deg(-5),
					})),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = s({
						by = -0.06,
						bz = -0.1,
						bpitch = deg(-5),
						npitch = deg(15),
						jaw = deg(25),
						earL = deg(30),
						earR = deg(30),
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = STANCE },
			},
		},
		-- Pounce (Elite II, W 1.4): the leap's crouch, deeper, then a long low flight onto the circle
		pounce = {
			strike = 0.4,
			follow = 0.3,
			recover = 0.35,
			legs = true,
			travel = true,
			tremble = deg(1.5),
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = s(merge(LEGS_BACK(0.22), {
						by = -0.2,
						bz = 0.22,
						bpitch = deg(-5),
						HLf = deg(55),
						HRf = deg(55),
						FLf = deg(20),
						FRf = deg(20),
						npitch = deg(14),
						hpitch = deg(-12),
						earL = deg(45),
						earR = deg(45),
						tpitch = 0,
					})),
				},
				{
					seg = "S",
					u = 0.5,
					ease = "out",
					pose = s({
						by = 0.4,
						bpitch = deg(18),
						sflex = deg(-8),
						FLu = deg(45),
						FRu = deg(45),
						HLu = deg(-40),
						HRu = deg(-40),
						npitch = deg(4),
						jaw = deg(35),
						earL = deg(45),
						earR = deg(45),
						travel = 0.5,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = s({
						by = -0.06,
						bpitch = deg(-14),
						FLu = deg(12),
						FRu = deg(12),
						HLu = deg(-15),
						HRu = deg(-15),
						npitch = deg(22),
						jaw = 0,
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = s(
						merge(LEGS_BACK(0.15), { by = -0.05, bz = 0.15, npitch = deg(12), hyaw = deg(12), travel = 1 })
					),
				},
				{ seg = "R", u = 1, ease = "inout", pose = from(STANCE, { travel = 1 }) },
			},
		},
		-- the thrown blow (Elite II): scoops something up with the head and flings it
		toss = {
			strike = 0.14,
			follow = 0.2,
			recover = 0.3,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 0.55,
					ease = "inout",
					pose = s({ npitch = deg(38), hpitch = deg(22), jaw = deg(30), bpitch = deg(-6) }),
				},
				{ seg = "A", u = 0.7, ease = "lin", pose = s({ npitch = deg(36), hpitch = deg(20), jaw = 0 }) },
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = s({ npitch = deg(-20), hpitch = deg(-8), bpitch = deg(6), bz = 0.06, jaw = 0 }),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = s({ npitch = deg(10), hpitch = deg(-20), bpitch = deg(-4), bz = -0.08, jaw = deg(30) }),
				},
				{ seg = "F", u = 1, ease = "out", pose = s({ npitch = deg(14), hpitch = deg(-4), jaw = deg(10) }) },
				{ seg = "R", u = 1, ease = "inout", pose = STANCE },
			},
		},
		-- the first aggro: the head drops, ears flat, a snarl, the tail up and stiff
		snarl = {
			strike = 0.12,
			follow = 0.4,
			recover = 0.3,
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = s({
						by = -0.05,
						npitch = deg(18),
						hpitch = deg(-14),
						earL = deg(45),
						earR = deg(45),
						tpitch = deg(15),
						jaw = deg(8),
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = s({
						by = -0.06,
						npitch = deg(20),
						hpitch = deg(-16),
						earL = deg(48),
						earR = deg(48),
						tpitch = deg(16),
						jaw = deg(18),
					}),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = s({
						by = -0.06,
						npitch = deg(20),
						hpitch = deg(-16),
						earL = deg(48),
						earR = deg(48),
						tpitch = deg(16),
						jaw = deg(8),
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = s({
						by = -0.05,
						npitch = deg(18),
						hpitch = deg(-14),
						earL = deg(45),
						earR = deg(45),
						tpitch = deg(15),
						jaw = deg(16),
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = STANCE },
			},
		},
		-- a summoned or new wolf: rises from a crouch and shakes itself off
		spawn = {
			strike = 0.3,
			follow = 0.35,
			recover = 0.2,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 0,
					ease = "lin",
					pose = s(merge(LEGS_BACK(0.2), {
						by = -0.3,
						HLf = deg(60),
						HRf = deg(60),
						FLf = deg(40),
						FRf = deg(40),
						npitch = deg(25),
						hpitch = deg(15),
					})),
				},
				{ seg = "S", u = 1, ease = "out", pose = STANCE },
				{ seg = "F", u = 0.25, ease = "inout", pose = s({ broll = deg(6), hroll = deg(-10), hyaw = deg(8) }) },
				{ seg = "F", u = 0.5, ease = "inout", pose = s({ broll = deg(-6), hroll = deg(10), hyaw = deg(-8) }) },
				{ seg = "F", u = 0.75, ease = "inout", pose = s({ broll = deg(5), hroll = deg(-8), hyaw = deg(6) }) },
				{ seg = "F", u = 1, ease = "inout", pose = STANCE },
				{ seg = "R", u = 1, ease = "inout", pose = STANCE },
			},
		},
		-- idle: sniffing the ground
		sniff = {
			strike = 0.5,
			follow = 0.9,
			recover = 0.6,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = { npitch = deg(30), hpitch = deg(15), earL = deg(-8), earR = deg(-8) },
				},
				{
					seg = "F",
					u = 0.2,
					ease = "inout",
					pose = { npitch = deg(33), hpitch = deg(18), earL = deg(-8), earR = deg(-8) },
				},
				{
					seg = "F",
					u = 0.4,
					ease = "inout",
					pose = { npitch = deg(29), hpitch = deg(14), earL = deg(-8), earR = deg(-8) },
				},
				{ seg = "F", u = 0.6, ease = "inout", pose = { npitch = deg(33), hpitch = deg(18), nyaw = deg(6) } },
				{ seg = "F", u = 0.8, ease = "inout", pose = { npitch = deg(29), hpitch = deg(14), nyaw = deg(6) } },
				{ seg = "F", u = 1, ease = "inout", pose = { npitch = deg(31), hpitch = deg(16), nyaw = deg(3) } },
				{ seg = "R", u = 1, ease = "inout", pose = {} },
			},
		},
		-- idle: a head shake
		shake = {
			strike = 0.15,
			follow = 0.4,
			recover = 0.25,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = { hyaw = deg(15), hroll = deg(-10), earL = deg(20), earR = deg(-10) },
				},
				{
					seg = "F",
					u = 0.25,
					ease = "inout",
					pose = { hyaw = deg(-15), hroll = deg(10), earL = deg(-10), earR = deg(20) },
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = { hyaw = deg(14), hroll = deg(-9), earL = deg(20), earR = deg(-10) },
				},
				{
					seg = "F",
					u = 0.75,
					ease = "inout",
					pose = { hyaw = deg(-12), hroll = deg(8), earL = deg(-10), earR = deg(18) },
				},
				{ seg = "F", u = 1, ease = "inout", pose = { hyaw = deg(4), hroll = deg(-2) } },
				{ seg = "R", u = 1, ease = "inout", pose = {} },
			},
		},
		-- death onto the left side: the jolt, the legs buckle (hind first), the roll and the settle
		deathL = {
			strike = 0.12,
			follow = 0.6,
			recover = 0.25,
			legs = true,
			full = true,
			hold = true,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = s({
						bz = 0.12,
						bpitch = deg(8),
						hpitch = deg(-12),
						jaw = deg(15),
						earL = deg(40),
						earR = deg(40),
					}),
				},
				{
					seg = "F",
					u = 0.45,
					ease = "in",
					pose = merge(LEGS_BACK(0.15), {
						by = -0.3,
						bpitch = deg(-5),
						HLf = deg(70),
						HRf = deg(70),
						FLf = deg(30),
						FRf = deg(30),
						npitch = deg(20),
						jaw = deg(12),
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "in",
					pose = {
						by = 0.3,
						bx = -0.05,
						broll = deg(85),
						bpitch = deg(-3),
						FLu = deg(15),
						FRu = deg(15),
						HLu = deg(10),
						HRu = deg(10),
						FLf = deg(15),
						FRf = deg(15),
						HLf = deg(15),
						HRf = deg(15),
						FLo = deg(8),
						HLo = deg(8),
						npitch = deg(-25),
						hroll = deg(10),
						jaw = deg(15),
						tpitch = 0,
					},
				},
				{
					seg = "R",
					u = 0.4,
					ease = "out",
					pose = {
						by = 0.34,
						bx = -0.05,
						broll = deg(82),
						bpitch = deg(-3),
						FLu = deg(15),
						FRu = deg(15),
						HLu = deg(18),
						HRu = deg(10),
						FLf = deg(15),
						FRf = deg(15),
						HLf = deg(15),
						HRf = deg(15),
						FLo = deg(8),
						HLo = deg(8),
						npitch = deg(-25),
						hroll = deg(10),
						jaw = deg(15),
					},
				},
				{
					seg = "R",
					u = 1,
					ease = "inout",
					pose = {
						by = 0.3,
						bx = -0.05,
						broll = deg(86),
						bpitch = deg(-3),
						FLu = deg(15),
						FRu = deg(15),
						HLu = deg(10),
						HRu = deg(10),
						FLf = deg(15),
						FRf = deg(15),
						HLf = deg(15),
						HRf = deg(15),
						FLo = deg(8),
						HLo = deg(8),
						npitch = deg(-27),
						hroll = deg(10),
						jaw = deg(15),
					},
				},
			},
		},
	},
}

-- death onto the right side: the left one mirrored
do
	local left = CANINE.actions.deathL
	local MIRROR: { [string]: boolean } =
		{ broll = true, bx = true, hroll = true, hyaw = true, nyaw = true, syaw = true }
	local keys = {}
	for _, key in left.keys do
		local pose = table.clone(key.pose)
		for k in MIRROR do
			if pose[k] then
				pose[k] = -pose[k]
			end
		end
		-- the spread legs swap sides
		pose.FLo, pose.FRo = pose.FRo, pose.FLo
		pose.HLo, pose.HRo = pose.HRo, pose.HLo
		table.insert(keys, { seg = key.seg, u = key.u, ease = key.ease, pose = pose })
	end
	CANINE.actions.deathR = {
		strike = left.strike,
		follow = left.follow,
		recover = left.recover,
		legs = true,
		full = true,
		hold = true,
		keys = keys,
	}
end

---------------------------------------------------------------- heavy quadrupeds: shared

-- Every foot planted where it stands: Logic/QuadPose solves the legs so the body moves over still feet (a key that
-- lifts a foot sets its `k` to 0 and poses it by swing and fold).
local PLANTED = { FLk = 1, FRk = 1, HLk = 1, HRk = 1 }

-- The twin of an action on the other side (a left-paw swipe, a death onto the other flank): the legs swap sides, the
-- side keys flip.
local SIDE_FLIP: { [string]: boolean } = {
	broll = true,
	bx = true,
	bpx = true,
	byaw = true,
	syaw = true,
	nyaw = true,
	hyaw = true,
	hroll = true,
	tyaw = true,
	kside = true,
}
local function mirrored(action: MotionTimeline.Action): MotionTimeline.Action
	local keys: { MotionTimeline.Key } = {}
	for _, key in action.keys do
		local pose: { [string]: number } = {}
		for name, v in key.pose do
			local to = name
			local leg = string.match(name, "^([FH][LR])%a$")
			local wing = string.match(name, "^w([LR])%a$")
			if leg then
				to = string.sub(leg, 1, 1) .. (if string.sub(leg, 2, 2) == "L" then "R" else "L") .. string.sub(name, 3)
			elseif wing then
				-- a dragon's wing keys swap sides (Logic/DragonMotion mirrors each wing's turns itself)
				to = "w" .. (if wing == "L" then "R" else "L") .. string.sub(name, 3)
			elseif name == "earL" then
				to = "earR"
			elseif name == "earR" then
				to = "earL"
			end
			local flip = SIDE_FLIP[name] or string.match(name, "^tY%d$") ~= nil
			pose[to] = if flip then -v else v
		end
		table.insert(keys, { seg = key.seg, u = key.u, ease = key.ease, pose = pose })
	end
	local out = table.clone(action)
	out.keys = keys
	return out
end

---------------------------------------------------------------- bear (brownBear, blackBear)

-- Bear (owner 2026-10-26, docs/ANIM-WZORCE.md §3.9): plantigrade feet flat on the ground, a rolling walk (the
-- shoulders roll over the planted side, the head swings with the steps), a heavy gallop; blows with the fore paws.
-- Sizes in leg lengths (hind hip height): hips 0.78 behind the centre, shoulders 0.42 ahead, the body ~1.2 wide.
local BEAR_STANCE = merge(PLANTED, { by = -0.03, bpitch = deg(-2), npitch = deg(6), hpitch = deg(-4) })
local function bs(over: { [string]: number }): { [string]: number }
	return from(BEAR_STANCE, over)
end
-- the hips: the pivot of a rear-up (the hind feet stay planted under them)
local BEAR_HIPS = { bpy = 0.94, bpz = 0.78 }

-- Up on the hind legs (by `rise` of the anticipation), a swaying, trembling hold, then both fore paws slam down 0.5
-- leg lengths ahead on the hit: the Elite II slam (W 1.4) and, with a longer hold, the crush (W 2.2).
local function bearRear(rise: number): MotionTimeline.Action
	local up = bs(merge(BEAR_HIPS, {
		by = 0.1,
		bpitch = deg(68),
		HLl = 1,
		HRl = 1,
		HLu = deg(-68),
		HRu = deg(-68),
		FLk = 0,
		FRk = 0,
		FLu = deg(80),
		FRu = deg(80),
		FLf = deg(30),
		FRf = deg(30),
		FLp = deg(-20),
		FRp = deg(-20),
		npitch = deg(48),
		hpitch = deg(10),
		tpitch = deg(-20),
	}))
	local function sway(roll: number, high: number): { [string]: number }
		local pose = table.clone(up)
		pose.broll = deg(roll)
		pose.bpitch = deg(70)
		pose.FLu, pose.FRu = deg(80 + high), deg(80 + high)
		pose.FLf, pose.FRf = deg(30 + high), deg(30 + high)
		return pose
	end
	return {
		strike = 0.14,
		follow = 0.4,
		recover = 0.4,
		legs = true,
		full = true,
		tremble = deg(2),
		keys = {
			{
				seg = "A",
				u = rise * 0.25,
				ease = "out",
				pose = bs({ by = -0.07, bz = 0.06, bpitch = deg(-4), npitch = deg(10) }),
			},
			{ seg = "A", u = rise, ease = "inout", pose = up },
			{ seg = "A", u = rise + (1 - rise) * 0.35, ease = "inout", pose = sway(3, 4) },
			{ seg = "A", u = rise + (1 - rise) * 0.7, ease = "inout", pose = sway(-3, 8) },
			{ seg = "A", u = 1, ease = "inout", pose = sway(1, 14) },
			{
				seg = "S",
				u = 1,
				ease = "in",
				pose = bs(merge(BEAR_HIPS, {
					by = -0.07,
					bz = -0.08,
					bpitch = deg(-6),
					HLl = 1,
					HRl = 1,
					FLz = -0.5,
					FRz = -0.5,
					FLu = deg(25),
					FRu = deg(25),
					npitch = deg(20),
					hpitch = deg(6),
					tpitch = deg(-5),
				})),
			},
			{
				seg = "F",
				u = 0.4,
				ease = "out",
				pose = bs({ by = -0.06, bz = -0.06, FLz = -0.5, FRz = -0.5, npitch = deg(22), hpitch = deg(-16) }),
			},
			{
				seg = "F",
				u = 1,
				ease = "inout",
				pose = bs({
					by = -0.05,
					bz = -0.05,
					FLz = -0.5,
					FRz = -0.5,
					npitch = deg(20),
					hpitch = deg(-12),
					hyaw = deg(8),
				}),
			},
			{ seg = "R", u = 0.55, ease = "inout", pose = bs({ bz = -0.02, FLz = -0.2, FLy = 0.08, FRz = -0.4 }) },
			{ seg = "R", u = 1, ease = "inout", pose = BEAR_STANCE },
		},
	}
end

-- The right fore paw raised high and out with the body wound to the right, swept down and across to land ahead on
-- the hit (W 0.55): the bear's regular blow; its left twin takes every other turn.
local BEAR_SWIPE: MotionTimeline.Action = {
	strike = 0.16,
	follow = 0.16,
	recover = 0.4,
	legs = true,
	full = true,
	sided = true,
	keys = {
		{
			seg = "A",
			u = 0.5,
			ease = "out",
			pose = bs({
				bx = -0.04,
				bz = 0.05,
				by = -0.03,
				broll = deg(3),
				bpitch = deg(3),
				byaw = deg(-3),
				FRk = 0,
				FRu = deg(75),
				FRf = deg(40),
				FRp = deg(10),
				FRo = deg(8),
				hyaw = deg(6),
				npitch = deg(3),
			}),
		},
		{
			seg = "A",
			u = 1,
			ease = "inout",
			pose = bs({
				bx = -0.06,
				bz = 0.08,
				by = -0.03,
				broll = deg(4),
				bpitch = deg(5),
				byaw = deg(-6),
				syaw = deg(-4),
				FRk = 0,
				FRu = deg(105),
				FRf = deg(65),
				FRp = deg(15),
				FRo = deg(15),
				hyaw = deg(10),
				nyaw = deg(4),
				npitch = deg(0),
			}),
		},
		{
			seg = "S",
			u = 0.5,
			ease = "in",
			pose = bs({
				bx = -0.02,
				bz = -0.1,
				by = -0.03,
				broll = deg(1),
				bpitch = deg(1),
				byaw = deg(0),
				FRk = 0,
				FRu = deg(75),
				FRf = deg(20),
				FRo = deg(6),
				hyaw = deg(2),
				npitch = deg(8),
			}),
		},
		{
			seg = "S",
			u = 1,
			ease = "in",
			pose = bs({
				bx = 0.03,
				bz = -0.3,
				by = -0.06,
				broll = deg(-2),
				bpitch = deg(-4),
				byaw = deg(7),
				syaw = deg(4),
				FRz = -0.6,
				FRu = deg(28),
				FRo = deg(-6),
				hyaw = deg(-8),
				npitch = deg(14),
			}),
		},
		{
			seg = "F",
			u = 1,
			ease = "out",
			pose = bs({
				bx = 0.05,
				bz = -0.28,
				by = -0.05,
				broll = deg(-3),
				byaw = deg(9),
				syaw = deg(5),
				FRz = -0.6,
				FRo = deg(-8),
				hyaw = deg(-12),
				npitch = deg(12),
			}),
		},
		{ seg = "R", u = 0.5, ease = "inout", pose = bs({ bz = -0.12, byaw = deg(3), FRz = -0.3, FRy = 0.1 }) },
		{ seg = "R", u = 1, ease = "inout", pose = BEAR_STANCE },
	},
}

local BEAR: Style = {
	gaits = {
		walk = {
			foot = { HL = 0, FL = 0.25, HR = 0.5, FR = 0.75 },
			duty = 0.75,
			k = 1.0,
			foldStance = deg(4),
			foldFront = deg(30),
			foldHind = deg(28),
			pawFront = deg(10),
			pawHind = deg(18),
			bob = 0.012,
			pitch = 0,
			flex = 0,
			roll = deg(4),
			spineYaw = deg(3),
			neck = deg(6),
			tail = 0,
			tailSway = deg(3),
			plant = true,
			lift = 0.11,
			liftFront = 0.14,
			level = 1,
			rollPivot = 0.3,
			headSway = deg(5),
			drop = 0.05,
		},
		trot = {
			foot = { HL = 0, FR = 0.02, HR = 0.5, FL = 0.52 },
			duty = 0.55,
			k = 1.5,
			foldStance = deg(6),
			foldFront = deg(45),
			foldHind = deg(38),
			pawFront = deg(20),
			pawHind = deg(22),
			bob = 0.03,
			pitch = 0,
			flex = 0,
			roll = deg(2.5),
			spineYaw = deg(1.5),
			neck = deg(8),
			tail = deg(5),
			tailSway = deg(3),
			plant = true,
			lift = 0.15,
			liftFront = 0.18,
			level = 0.8,
			rollPivot = 0.2,
			headSway = deg(3),
			drop = 0.04,
		},
		gallop = {
			foot = { HL = 0, HR = 0.1, FR = 0.42, FL = 0.52 },
			duty = 0.4,
			dutyFront = 0.38,
			k = 2.6,
			foldStance = deg(8),
			foldFront = deg(70),
			foldHind = deg(50),
			pawFront = deg(30),
			pawHind = deg(25),
			bob = 0.05,
			pitch = deg(4),
			flex = deg(6),
			roll = 0,
			spineYaw = 0,
			neck = deg(8),
			tail = deg(5),
			tailSway = deg(2),
			plant = true,
			lift = 0.2,
			liftFront = 0.26,
			level = 0.5,
			drop = 0.04,
		},
	},
	thresholds = { trot = 2.5, gallop = 4.0 },
	stance = BEAR_STANCE,
	calm = { npitch = deg(8) },
	idle = { tail = 0 },
	ground = { FLk = 1, FRk = 1, HLk = 1, HRk = 1, HLl = 1, HRl = 1 },
	basic = { "swipe", "swipeL" },
	abilities = {
		slam = "slam",
		crush = "crush",
		heavyBlow = "maul",
		pounce = "bodyslam",
		leap = "bodyslam",
		charge = "bodyslam",
	},
	throw = "hurl",
	death = { "deathL", "deathR" },
	aggro = "huff",
	spawn = "spawn",
	fidgets = { "sniff", "shake", "scent" },
	fidgetEvery = { 7, 13 },
	rate = 0.05,
	flinch = {
		front = { bz = 0.07, bpitch = deg(4), npitch = deg(-8) },
		back = { bz = -0.05, bpitch = deg(-3), npitch = deg(6) },
		left = { broll = deg(-5), bx = 0.06, syaw = deg(-5), hyaw = deg(10) },
		right = { broll = deg(5), bx = -0.06, syaw = deg(5), hyaw = deg(-10) },
	},
	actions = {
		swipe = BEAR_SWIPE,
		swipeL = mirrored(BEAR_SWIPE),
		slam = bearRear(0.48),
		crush = bearRear(0.39),
		-- Heavy Blow (Elite, W 1.8): half up on the hind legs with both fore paws high, then the right paw comes down
		-- 0.1 s before the hit and the left one on it
		maul = {
			strike = 0.3,
			follow = 0.3,
			recover = 0.45,
			legs = true,
			full = true,
			sided = true,
			tremble = deg(1.5),
			keys = {
				{
					seg = "A",
					u = 0.35,
					ease = "out",
					pose = bs(merge(BEAR_HIPS, {
						by = 0.04,
						bpitch = deg(28),
						byaw = deg(-4),
						HLl = 1,
						HRl = 1,
						HLu = deg(-28),
						HRu = deg(-28),
						FLk = 0,
						FRk = 0,
						FLu = deg(85),
						FRu = deg(85),
						FLf = deg(45),
						FRf = deg(45),
						FLo = deg(10),
						FRo = deg(10),
						npitch = deg(26),
					})),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = bs(merge(BEAR_HIPS, {
						by = 0.05,
						bpitch = deg(32),
						byaw = deg(-6),
						syaw = deg(-4),
						HLl = 1,
						HRl = 1,
						HLu = deg(-32),
						HRu = deg(-32),
						FLk = 0,
						FRk = 0,
						FLu = deg(100),
						FRu = deg(102),
						FLf = deg(60),
						FRf = deg(62),
						FLo = deg(12),
						FRo = deg(14),
						npitch = deg(30),
					})),
				},
				{
					seg = "S",
					u = 0.66,
					ease = "in",
					pose = bs(merge(BEAR_HIPS, {
						by = -0.02,
						bz = -0.12,
						bpitch = deg(6),
						byaw = deg(4),
						HLl = 1,
						HRl = 1,
						FRz = -0.45,
						FRu = deg(22),
						FLk = 0,
						FLu = deg(75),
						FLf = deg(30),
						FLo = deg(8),
						npitch = deg(14),
						hyaw = deg(-6),
					})),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = bs(merge(BEAR_HIPS, {
						by = -0.06,
						bz = -0.26,
						bpitch = deg(-5),
						byaw = deg(-6),
						HLl = 1,
						HRl = 1,
						FRz = -0.45,
						FLz = -0.55,
						FLu = deg(25),
						FRu = deg(22),
						npitch = deg(16),
						hyaw = deg(6),
					})),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = bs({
						by = -0.05,
						bz = -0.24,
						FRz = -0.45,
						FLz = -0.55,
						npitch = deg(20),
						hpitch = deg(-10),
						hyaw = deg(-8),
					}),
				},
				{ seg = "R", u = 0.5, ease = "inout", pose = bs({ bz = -0.1, FLz = -0.25, FLy = 0.08, FRz = -0.4 }) },
				{ seg = "R", u = 1, ease = "inout", pose = BEAR_STANCE },
			},
		},
		-- Pounce (Elite II, W 1.4; teleported onto the circle at the hit): a deep crouch, then a low, flat body-slam
		-- arc that lands with the whole weight on the hit, a short skid
		bodyslam = {
			strike = 0.4,
			follow = 0.3,
			recover = 0.4,
			legs = true,
			full = true,
			travel = true,
			tremble = deg(1.5),
			keys = {
				{
					seg = "A",
					u = 0.4,
					ease = "out",
					pose = bs({ by = -0.12, bz = 0.12, bpitch = deg(-3), npitch = deg(10), hpitch = deg(-8) }),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = bs({ by = -0.16, bz = 0.14, bpitch = deg(-4), npitch = deg(12), hpitch = deg(-10) }),
				},
				{
					seg = "S",
					u = 0.15,
					ease = "out",
					pose = bs({
						by = 0.02,
						bz = 0.02,
						bpitch = deg(10),
						FLk = 0,
						FRk = 0,
						FLu = deg(40),
						FRu = deg(40),
						FLf = deg(-20),
						FRf = deg(-20),
						npitch = deg(4),
						travel = 0.08,
					}),
				},
				{
					seg = "S",
					u = 0.55,
					ease = "lin",
					pose = {
						by = 0.34,
						bpitch = deg(2),
						sflex = deg(-6),
						FLu = deg(55),
						FRu = deg(55),
						FLf = deg(15),
						FRf = deg(15),
						HLu = deg(-40),
						HRu = deg(-40),
						HLf = deg(10),
						HRf = deg(10),
						npitch = deg(6),
						travel = 0.55,
					},
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = bs({
						by = -0.09,
						bpitch = deg(-6),
						FLz = -0.2,
						FRz = -0.2,
						HLz = 0.1,
						HRz = 0.1,
						npitch = deg(18),
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = bs({
						by = -0.06,
						bz = -0.3,
						FLz = -0.5,
						FRz = -0.5,
						HLz = -0.15,
						HRz = -0.15,
						npitch = deg(14),
						hyaw = deg(10),
						travel = 1,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = from(BEAR_STANCE, { travel = 1 }) },
			},
		},
		-- the thrown blow (Elite II): the right paw scoops a rock from the ground, draws back beside the shoulder and
		-- flings it forward and up; it leaves the paw on the hit
		hurl = {
			strike = 0.18,
			follow = 0.2,
			recover = 0.4,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 0.5,
					ease = "inout",
					pose = bs({
						by = -0.05,
						bz = -0.06,
						bpitch = deg(-6),
						FRz = -0.35,
						FRu = deg(30),
						npitch = deg(22),
					}),
				},
				{
					seg = "A",
					u = 0.62,
					ease = "lin",
					pose = bs({
						by = -0.05,
						bz = -0.06,
						bpitch = deg(-6),
						FRz = -0.35,
						FRu = deg(30),
						FRp = deg(25),
						npitch = deg(22),
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = bs(merge(BEAR_HIPS, {
						by = 0.03,
						bpitch = deg(14),
						byaw = deg(-8),
						syaw = deg(-5),
						HLl = 1,
						HRl = 1,
						HLu = deg(-14),
						HRu = deg(-14),
						FRk = 0,
						FRu = deg(-10),
						FRf = deg(-70),
						FRp = deg(25),
						npitch = deg(12),
						hyaw = deg(6),
					})),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = bs(merge(BEAR_HIPS, {
						bz = -0.1,
						bpitch = deg(4),
						byaw = deg(6),
						syaw = deg(4),
						HLl = 1,
						HRl = 1,
						HLu = deg(-4),
						HRu = deg(-4),
						FRk = 0,
						FRu = deg(110),
						FRf = deg(40),
						npitch = deg(2),
						hyaw = deg(-4),
					})),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = bs({ bz = -0.12, byaw = deg(5), FRk = 0, FRu = deg(60), FRf = deg(-10), npitch = deg(10) }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = BEAR_STANCE },
			},
		},
		-- the first aggro: a fore paw lifted and slapped down with a huff, the head thrust low, a shake
		huff = {
			strike = 0.12,
			follow = 0.4,
			recover = 0.3,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = bs({ by = 0.01, bpitch = deg(5), FRk = 0, FRu = deg(45), FRf = deg(25), npitch = deg(-4) }),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = bs({
						by = -0.05,
						bz = -0.04,
						bpitch = deg(-3),
						FRz = -0.2,
						npitch = deg(18),
						hpitch = deg(-12),
					}),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = bs({ by = -0.04, FRz = -0.2, npitch = deg(16), hpitch = deg(-14), hyaw = deg(9) }),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = bs({ by = -0.04, FRz = -0.2, npitch = deg(14), hpitch = deg(-10), hyaw = deg(-6) }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = BEAR_STANCE },
			},
		},
		-- a summoned or new bear: rises from a crouch and shakes its coat
		spawn = {
			strike = 0.3,
			follow = 0.4,
			recover = 0.2,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 0,
					ease = "lin",
					pose = bs({ by = -0.3, bz = 0.05, npitch = deg(25), hpitch = deg(10) }),
				},
				{ seg = "S", u = 1, ease = "out", pose = BEAR_STANCE },
				{
					seg = "F",
					u = 0.25,
					ease = "inout",
					pose = bs({ broll = deg(7), syaw = deg(4), hroll = deg(-12), hyaw = deg(10) }),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = bs({ broll = deg(-7), syaw = deg(-4), hroll = deg(12), hyaw = deg(-10) }),
				},
				{
					seg = "F",
					u = 0.75,
					ease = "inout",
					pose = bs({ broll = deg(5), syaw = deg(3), hroll = deg(-8), hyaw = deg(7) }),
				},
				{ seg = "F", u = 1, ease = "inout", pose = BEAR_STANCE },
				{ seg = "R", u = 1, ease = "inout", pose = BEAR_STANCE },
			},
		},
		-- idle: nose to the ground, three sniffs
		sniff = {
			strike = 0.6,
			follow = 1.0,
			recover = 0.7,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { by = -0.02, npitch = deg(32), hpitch = deg(10) }),
				},
				{
					seg = "F",
					u = 0.2,
					ease = "inout",
					pose = from(PLANTED, { by = -0.02, npitch = deg(35), hpitch = deg(12) }),
				},
				{
					seg = "F",
					u = 0.45,
					ease = "inout",
					pose = from(PLANTED, { by = -0.02, npitch = deg(31), hpitch = deg(9), nyaw = deg(6) }),
				},
				{
					seg = "F",
					u = 0.7,
					ease = "inout",
					pose = from(PLANTED, { by = -0.02, npitch = deg(35), hpitch = deg(12), nyaw = deg(8) }),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { by = -0.02, npitch = deg(31), hpitch = deg(9), nyaw = deg(3) }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- idle: a shake through the whole coat
		shake = {
			strike = 0.2,
			follow = 0.6,
			recover = 0.3,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = from(PLANTED, { broll = deg(5), syaw = deg(4), hyaw = deg(14), hroll = deg(-10) }),
				},
				{
					seg = "F",
					u = 0.25,
					ease = "inout",
					pose = from(PLANTED, { broll = deg(-5), syaw = deg(-4), hyaw = deg(-14), hroll = deg(10) }),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = from(PLANTED, { broll = deg(4), syaw = deg(3), hyaw = deg(12), hroll = deg(-8) }),
				},
				{
					seg = "F",
					u = 0.75,
					ease = "inout",
					pose = from(PLANTED, { broll = deg(-3), syaw = deg(-2), hyaw = deg(-9), hroll = deg(6) }),
				},
				{ seg = "F", u = 1, ease = "inout", pose = from(PLANTED, { hyaw = deg(3), hroll = deg(-2) }) },
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- idle: the head raised to scent the air, a couple of slow nods
		scent = {
			strike = 0.6,
			follow = 1.2,
			recover = 0.6,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { bpitch = deg(2), npitch = deg(-22), hpitch = deg(-10) }),
				},
				{
					seg = "F",
					u = 0.3,
					ease = "inout",
					pose = from(PLANTED, { bpitch = deg(2), npitch = deg(-25), hpitch = deg(-14), nyaw = deg(-8) }),
				},
				{
					seg = "F",
					u = 0.6,
					ease = "inout",
					pose = from(PLANTED, { bpitch = deg(2), npitch = deg(-20), hpitch = deg(-9), nyaw = deg(6) }),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { bpitch = deg(1), npitch = deg(-23), hpitch = deg(-12), nyaw = deg(2) }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- death onto the left flank: the jolt, the legs buckle (hind first) under the weight, the roll about the
		-- ground line under that flank, the settle and a last twitch
		deathL = {
			strike = 0.12,
			follow = 0.6,
			recover = 0.25,
			legs = true,
			full = true,
			hold = true,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = bs({ bz = 0.08, bpitch = deg(6), npitch = deg(-10), hpitch = deg(-8) }),
				},
				{
					seg = "F",
					u = 0.45,
					ease = "in",
					pose = from(PLANTED, {
						by = -0.3,
						bpitch = deg(-6),
						FLf = 0.9,
						FRf = 0.9,
						HLf = 0.9,
						HRf = 0.9,
						npitch = deg(22),
						hpitch = deg(4),
					}),
				},
				-- the feet let go as it tips over
				{
					seg = "F",
					u = 0.62,
					ease = "inout",
					pose = {
						by = -0.22,
						broll = deg(20),
						bpx = -0.9,
						bpitch = deg(-5),
						FLf = 0.9,
						FRf = 0.9,
						HLf = 0.9,
						HRf = 0.9,
						npitch = deg(18),
						hpitch = deg(2),
					},
				},
				{
					seg = "F",
					u = 1,
					ease = "in",
					pose = {
						by = 0,
						broll = deg(86),
						bpx = -0.9,
						bpitch = deg(-3),
						FLu = deg(18),
						FRu = deg(12),
						HLu = deg(10),
						HRu = deg(16),
						FLf = deg(15),
						FRf = deg(20),
						HLf = deg(15),
						HRf = deg(12),
						FLo = deg(-12),
						HLo = deg(-12),
						nyaw = deg(18),
						npitch = deg(-6),
						hroll = deg(8),
						FRo = deg(-20),
						HRo = deg(-20),
					},
				},
				{
					seg = "R",
					u = 0.4,
					ease = "out",
					pose = {
						by = 0,
						broll = deg(84),
						bpx = -0.9,
						bpitch = deg(-3),
						FLu = deg(18),
						FRu = deg(12),
						HLu = deg(10),
						HRu = deg(24),
						FLf = deg(15),
						FRf = deg(20),
						HLf = deg(15),
						HRf = deg(12),
						FLo = deg(-12),
						HLo = deg(-12),
						nyaw = deg(18),
						npitch = deg(-6),
						hroll = deg(8),
						FRo = deg(-20),
						HRo = deg(-20),
					},
				},
				{
					seg = "R",
					u = 1,
					ease = "inout",
					pose = {
						by = 0,
						broll = deg(87),
						bpx = -0.9,
						bpitch = deg(-3),
						FLu = deg(18),
						FRu = deg(12),
						HLu = deg(10),
						HRu = deg(16),
						FLf = deg(15),
						FRf = deg(20),
						HLf = deg(15),
						HRf = deg(12),
						FLo = deg(-12),
						HLo = deg(-12),
						nyaw = deg(20),
						npitch = deg(-6),
						hroll = deg(8),
						FRo = deg(-20),
						HRo = deg(-20),
					},
				},
			},
		},
	},
}
BEAR.actions.deathR = mirrored(BEAR.actions.deathL)
-- Studio review: the bear's skeleton sits twisted in its mesh, so on its right flank the mirrored fall lies about
-- 0.6 studs above the ground; lowered once it is on its side
for _, key in BEAR.actions.deathR.keys do
	if math.abs(key.pose.broll or 0) > deg(45) then
		key.pose.by = (key.pose.by or 0) - 0.24
	end
end

---------------------------------------------------------------- boar

-- Boar (§3.9): short legs, the head carried low, a quick trot and a scrambling gallop; tusk blows with the head.
-- Sizes in leg lengths: hips 0.75 behind the centre, the head 0.7 ahead, the snout 1.25 ahead.
local BOAR_STANCE =
	merge(PLANTED, { by = -0.02, bpitch = deg(-3), npitch = deg(14), hpitch = deg(-4), tpitch = deg(10) })
local function ps(over: { [string]: number }): { [string]: number }
	return from(BOAR_STANCE, over)
end
local BOAR_HIPS = { bpy = 1.0, bpz = 0.75 }

local BOAR: Style = {
	gaits = {
		walk = {
			foot = { HL = 0, FL = 0.25, HR = 0.5, FR = 0.75 },
			duty = 0.65,
			k = 1.1,
			foldStance = deg(5),
			foldFront = deg(40),
			foldHind = deg(30),
			pawFront = deg(25),
			pawHind = deg(15),
			bob = 0.012,
			pitch = 0,
			flex = 0,
			roll = deg(2),
			spineYaw = deg(2),
			neck = deg(10),
			tail = 0,
			tailSway = deg(10),
			plant = true,
			lift = 0.1,
			rollPivot = 0.2,
			headSway = deg(3),
			drop = 0.03,
		},
		trot = {
			foot = { HL = 0, FR = 0.02, HR = 0.5, FL = 0.52 },
			duty = 0.45,
			k = 1.6,
			foldStance = deg(6),
			foldFront = deg(55),
			foldHind = deg(40),
			pawFront = deg(35),
			pawHind = deg(20),
			bob = 0.03,
			pitch = 0,
			flex = 0,
			roll = deg(2),
			spineYaw = deg(1.5),
			neck = deg(8),
			tail = deg(10),
			tailSway = deg(6),
			plant = true,
			lift = 0.14,
			liftFront = 0.16,
		},
		gallop = {
			foot = { HL = 0, HR = 0.1, FR = 0.42, FL = 0.52 },
			duty = 0.3,
			dutyFront = 0.28,
			k = 2.8,
			foldStance = deg(8),
			foldFront = deg(80),
			foldHind = deg(55),
			pawFront = deg(50),
			pawHind = deg(25),
			bob = 0.06,
			pitch = deg(5),
			flex = deg(8),
			roll = 0,
			spineYaw = 0,
			neck = deg(8),
			tail = deg(12),
			tailSway = deg(3),
			plant = true,
			lift = 0.2,
			liftFront = 0.24,
		},
	},
	thresholds = { trot = 2.8, gallop = 4.9 },
	stance = BOAR_STANCE,
	calm = { npitch = deg(6), tpitch = deg(-5) },
	idle = { tail = deg(-10) },
	ground = PLANTED,
	basic = { "gore" },
	abilities = {
		charge = "charge",
		crush = "stomp",
		heavyBlow = "rake",
		pounce = "leap",
		slam = "stomp",
		leap = "leap",
	},
	throw = "toss",
	death = { "deathL", "deathR" },
	aggro = "snort",
	spawn = "spawn",
	fidgets = { "root", "shake", "sniff" },
	fidgetEvery = { 5, 10 },
	rate = 0.05,
	flinch = {
		front = { bz = 0.08, bpitch = deg(5), npitch = deg(-10), tpitch = deg(-10) },
		back = { bz = -0.06, bpitch = deg(-4), npitch = deg(6), tpitch = deg(-15) },
		left = { broll = deg(-6), bx = 0.07, syaw = deg(-6), hyaw = deg(12) },
		right = { broll = deg(6), bx = -0.07, syaw = deg(6), hyaw = deg(-12) },
	},
	actions = {
		-- the regular blow (W 0.55): the head drops, the fore hooves leave for one lunging step and land as the head
		-- hooks up with a twist on the hit (the tusks into the target), a head shake, the step back
		gore = {
			strike = 0.18,
			follow = 0.17,
			recover = 0.4,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = ps({
						bz = 0.08,
						by = -0.04,
						bpitch = deg(-4),
						npitch = deg(30),
						hpitch = deg(6),
						tpitch = deg(15),
					}),
				},
				{
					seg = "S",
					u = 0.4,
					ease = "lin",
					pose = ps({
						bz = -0.15,
						by = 0.02,
						bpitch = deg(2),
						FLk = 0,
						FRk = 0,
						FLu = deg(25),
						FRu = deg(25),
						FLf = deg(40),
						FRf = deg(40),
						npitch = deg(28),
						hpitch = deg(4),
						tpitch = deg(18),
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ps({
						bz = -0.5,
						by = -0.03,
						bpitch = deg(-2),
						FLz = -0.45,
						FRz = -0.4,
						npitch = deg(-12),
						hpitch = deg(-14),
						hroll = deg(15),
						hyaw = deg(6),
						tpitch = deg(15),
					}),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = ps({
						bz = -0.48,
						FLz = -0.45,
						FRz = -0.4,
						npitch = deg(-6),
						hroll = deg(-10),
						hyaw = deg(-8),
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = ps({ bz = -0.46, FLz = -0.45, FRz = -0.4, npitch = deg(4), hroll = deg(8), hyaw = deg(6) }),
				},
				{ seg = "R", u = 0.5, ease = "inout", pose = ps({ bz = -0.22, FLz = -0.2, FLy = 0.08, FRz = -0.35 }) },
				{ seg = "R", u = 1, ease = "inout", pose = BOAR_STANCE },
			},
		},
		-- Charge (Elite II own, W 1.0; S162m: the server runs the boar along its line the last 0.4 s): the head down,
		-- the right fore hoof scrapes the ground twice, a trembling set, then the gallop at the dash's speed with the
		-- head hooking on the hit, and a skid stop
		charge = {
			strike = 0.4,
			follow = 0.25,
			recover = 0.45,
			legs = true,
			travel = true,
			gait = "gallop",
			tremble = deg(1.5),
			keys = {
				{
					seg = "A",
					u = 0.15,
					ease = "out",
					pose = ps({ bz = 0.06, npitch = deg(30), hpitch = deg(6), tpitch = deg(25) }),
				},
				{
					seg = "A",
					u = 0.33,
					ease = "inout",
					pose = ps({
						bz = 0.06,
						FRk = 0,
						FRu = deg(-25),
						FRf = deg(15),
						FRp = deg(20),
						npitch = deg(30),
						tpitch = deg(25),
					}),
				},
				{
					seg = "A",
					u = 0.52,
					ease = "inout",
					pose = ps({ bz = 0.06, FRk = 0, FRu = deg(10), FRf = deg(25), npitch = deg(30), tpitch = deg(25) }),
				},
				{
					seg = "A",
					u = 0.72,
					ease = "inout",
					pose = ps({
						bz = 0.07,
						FRk = 0,
						FRu = deg(-25),
						FRf = deg(15),
						FRp = deg(20),
						npitch = deg(31),
						tpitch = deg(25),
					}),
				},
				{ seg = "A", u = 0.88, ease = "inout", pose = ps({ bz = 0.07, npitch = deg(31), tpitch = deg(28) }) },
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ps({ bz = 0.08, by = -0.04, bpitch = deg(-3), npitch = deg(32), tpitch = deg(30) }),
				},
				{
					seg = "S",
					u = 0.3,
					ease = "out",
					pose = from(
						PLANTED,
						{ bpitch = deg(-4), npitch = deg(24), hpitch = deg(2), tpitch = deg(25), travel = 0.25 }
					),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = from(PLANTED, {
						bpitch = deg(-2),
						npitch = deg(-12),
						hpitch = deg(-10),
						hroll = deg(12),
						tpitch = deg(25),
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = ps({
						by = -0.07,
						bz = 0.05,
						bpitch = deg(4),
						FLz = -0.2,
						FRz = -0.2,
						HLz = -0.1,
						HRz = -0.1,
						npitch = deg(5),
						hroll = deg(-6),
						tpitch = deg(20),
						travel = 1,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = from(BOAR_STANCE, { travel = 1 }) },
			},
		},
		-- Heavy Blow (Elite, W 1.8) "rake": the head low and cocked, a long snorting gather, then a lunge with the head
		-- sweeping across the cone and hooking up on the hit
		rake = {
			strike = 0.18,
			follow = 0.3,
			recover = 0.45,
			legs = true,
			full = true,
			tremble = deg(1.2),
			keys = {
				{
					seg = "A",
					u = 0.4,
					ease = "out",
					pose = ps({
						bz = 0.15,
						by = -0.05,
						bpitch = deg(-5),
						npitch = deg(30),
						hyaw = deg(22),
						hroll = deg(-8),
						tpitch = deg(25),
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ps({
						bz = 0.17,
						by = -0.06,
						bpitch = deg(-6),
						npitch = deg(32),
						hyaw = deg(25),
						hroll = deg(-10),
						tpitch = deg(28),
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ps({
						bz = -0.55,
						by = -0.02,
						FLz = -0.4,
						FRz = -0.45,
						npitch = deg(-10),
						hpitch = deg(-8),
						hyaw = deg(-28),
						hroll = deg(14),
						tpitch = deg(20),
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = ps({ bz = -0.5, FLz = -0.4, FRz = -0.45, npitch = deg(6), hyaw = deg(-34), hroll = deg(6) }),
				},
				{ seg = "R", u = 0.5, ease = "inout", pose = ps({ bz = -0.22, FLz = -0.2, FRz = -0.35, FRy = 0.08 }) },
				{ seg = "R", u = 1, ease = "inout", pose = BOAR_STANCE },
			},
		},
		-- Crush (Elite II, W 2.2) "stomp": backs up, rises on the hind legs pawing the air, then crashes down on both
		-- fore hooves on the hit
		stomp = {
			strike = 0.18,
			follow = 0.35,
			recover = 0.4,
			legs = true,
			full = true,
			tremble = deg(1.5),
			keys = {
				{
					seg = "A",
					u = 0.2,
					ease = "out",
					pose = ps({ bz = 0.1, by = -0.04, npitch = deg(24), tpitch = deg(20) }),
				},
				{
					seg = "A",
					u = 0.45,
					ease = "inout",
					pose = ps(merge(BOAR_HIPS, {
						by = 0.05,
						bpitch = deg(35),
						HLu = deg(-35),
						HRu = deg(-35),
						FLk = 0,
						FRk = 0,
						FLu = deg(55),
						FRu = deg(40),
						FLf = deg(40),
						FRf = deg(55),
						npitch = deg(38),
						tpitch = deg(30),
					})),
				},
				{
					seg = "A",
					u = 0.62,
					ease = "inout",
					pose = ps(merge(BOAR_HIPS, {
						by = 0.05,
						bpitch = deg(36),
						HLu = deg(-36),
						HRu = deg(-36),
						FLk = 0,
						FRk = 0,
						FLu = deg(40),
						FRu = deg(58),
						FLf = deg(55),
						FRf = deg(40),
						npitch = deg(38),
						tpitch = deg(30),
					})),
				},
				{
					seg = "A",
					u = 0.8,
					ease = "inout",
					pose = ps(merge(BOAR_HIPS, {
						by = 0.05,
						bpitch = deg(36),
						HLu = deg(-36),
						HRu = deg(-36),
						FLk = 0,
						FRk = 0,
						FLu = deg(58),
						FRu = deg(42),
						FLf = deg(40),
						FRf = deg(55),
						npitch = deg(38),
						tpitch = deg(30),
					})),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ps(merge(BOAR_HIPS, {
						by = 0.06,
						bpitch = deg(38),
						HLu = deg(-38),
						HRu = deg(-38),
						FLk = 0,
						FRk = 0,
						FLu = deg(62),
						FRu = deg(62),
						FLf = deg(45),
						FRf = deg(45),
						npitch = deg(40),
						tpitch = deg(32),
					})),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ps(merge(BOAR_HIPS, {
						by = -0.05,
						bpitch = deg(-5),
						FLz = -0.35,
						FRz = -0.35,
						npitch = deg(30),
						hpitch = deg(8),
						tpitch = deg(20),
					})),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "out",
					pose = ps({ by = -0.04, FLz = -0.35, FRz = -0.35, npitch = deg(26), hyaw = deg(10) }),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = ps({ by = -0.03, FLz = -0.35, FRz = -0.35, npitch = deg(24), hyaw = deg(-8) }),
				},
				{ seg = "R", u = 0.5, ease = "inout", pose = ps({ FLz = -0.1, FLy = 0.08, FRz = -0.3 }) },
				{ seg = "R", u = 1, ease = "inout", pose = BOAR_STANCE },
			},
		},
		-- Pounce (Elite II, W 1.4; teleported onto the circle at the hit): a crouch, a flat leap with the hooves tucked
		-- and the tusks forward, landing on the hit, a skid
		leap = {
			strike = 0.4,
			follow = 0.3,
			recover = 0.35,
			legs = true,
			full = true,
			travel = true,
			tremble = deg(1.5),
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ps({ by = -0.15, bz = 0.15, bpitch = deg(-4), npitch = deg(24), tpitch = deg(25) }),
				},
				{
					seg = "S",
					u = 0.15,
					ease = "out",
					pose = ps({
						by = 0.02,
						bpitch = deg(12),
						FLk = 0,
						FRk = 0,
						FLu = deg(30),
						FRu = deg(30),
						FLf = deg(45),
						FRf = deg(45),
						travel = 0.08,
					}),
				},
				{
					seg = "S",
					u = 0.55,
					ease = "lin",
					pose = {
						by = 0.38,
						bpitch = deg(2),
						sflex = deg(-6),
						FLu = deg(35),
						FRu = deg(35),
						FLf = deg(60),
						FRf = deg(60),
						HLu = deg(-35),
						HRu = deg(-35),
						npitch = deg(18),
						tpitch = deg(20),
						travel = 0.55,
					},
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ps({
						by = -0.06,
						bpitch = deg(-8),
						FLz = -0.2,
						FRz = -0.2,
						npitch = deg(-6),
						hpitch = deg(-8),
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = ps({
						by = -0.04,
						bz = -0.3,
						bpitch = deg(6),
						FLz = -0.55,
						FRz = -0.55,
						HLz = -0.2,
						HRz = -0.2,
						npitch = deg(10),
						travel = 1,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = from(BOAR_STANCE, { travel = 1 }) },
			},
		},
		-- the thrown blow (Elite II): the snout digs into the ground and flings a clod forward and up; it leaves on the
		-- hit
		toss = {
			strike = 0.14,
			follow = 0.2,
			recover = 0.35,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 0.55,
					ease = "inout",
					pose = ps({ bpitch = deg(-8), npitch = deg(45), hpitch = deg(15) }),
				},
				{
					seg = "A",
					u = 0.7,
					ease = "lin",
					pose = ps({ bpitch = deg(-8), bz = -0.04, npitch = deg(48), hpitch = deg(18) }),
				},
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = ps({ bpitch = deg(4), bz = 0.06, npitch = deg(10), hpitch = deg(-5) }),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ps({ bpitch = deg(-3), bz = -0.08, npitch = deg(-20), hpitch = deg(-25) }),
				},
				{ seg = "F", u = 1, ease = "out", pose = ps({ npitch = deg(4), hpitch = deg(-8) }) },
				{ seg = "R", u = 1, ease = "inout", pose = BOAR_STANCE },
			},
		},
		-- the first aggro: a hoof scrape, the head jerks up with a snort, then low and glaring
		snort = {
			strike = 0.12,
			follow = 0.4,
			recover = 0.3,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 0.5,
					ease = "out",
					pose = ps({ FRk = 0, FRu = deg(-20), FRf = deg(15), npitch = deg(28), tpitch = deg(25) }),
				},
				{ seg = "A", u = 1, ease = "inout", pose = ps({ npitch = deg(30), tpitch = deg(28) }) },
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = ps({ bpitch = deg(-2), npitch = deg(4), hpitch = deg(-14), tpitch = deg(30) }),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = ps({ npitch = deg(24), hpitch = deg(-2), tpitch = deg(28) }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = BOAR_STANCE },
			},
		},
		spawn = {
			strike = 0.3,
			follow = 0.35,
			recover = 0.2,
			legs = true,
			full = true,
			keys = {
				{ seg = "A", u = 0, ease = "lin", pose = ps({ by = -0.3, npitch = deg(30), hpitch = deg(10) }) },
				{ seg = "S", u = 1, ease = "out", pose = BOAR_STANCE },
				{
					seg = "F",
					u = 0.25,
					ease = "inout",
					pose = ps({ broll = deg(7), hroll = deg(-12), hyaw = deg(10) }),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = ps({ broll = deg(-7), hroll = deg(12), hyaw = deg(-10) }),
				},
				{ seg = "F", u = 0.75, ease = "inout", pose = ps({ broll = deg(5), hroll = deg(-8), hyaw = deg(6) }) },
				{ seg = "F", u = 1, ease = "inout", pose = BOAR_STANCE },
				{ seg = "R", u = 1, ease = "inout", pose = BOAR_STANCE },
			},
		},
		-- idle: rooting the ground with the snout (three shoves)
		root = {
			strike = 0.45,
			follow = 1.1,
			recover = 0.5,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { bpitch = deg(-5), npitch = deg(40), hpitch = deg(14) }),
				},
				{
					seg = "F",
					u = 0.2,
					ease = "out",
					pose = from(PLANTED, { bpitch = deg(-5), bz = -0.03, npitch = deg(44), hpitch = deg(8) }),
				},
				{
					seg = "F",
					u = 0.4,
					ease = "inout",
					pose = from(PLANTED, { bpitch = deg(-5), npitch = deg(40), hpitch = deg(16), nyaw = deg(6) }),
				},
				{
					seg = "F",
					u = 0.6,
					ease = "out",
					pose = from(
						PLANTED,
						{ bpitch = deg(-5), bz = -0.03, npitch = deg(44), hpitch = deg(8), nyaw = deg(6) }
					),
				},
				{
					seg = "F",
					u = 0.8,
					ease = "inout",
					pose = from(PLANTED, { bpitch = deg(-5), npitch = deg(40), hpitch = deg(16), nyaw = deg(-4) }),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = from(PLANTED, { bpitch = deg(-5), bz = -0.03, npitch = deg(44), hpitch = deg(8) }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- idle: a shake from the head down the back
		shake = {
			strike = 0.15,
			follow = 0.45,
			recover = 0.25,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = from(PLANTED, { broll = deg(5), hyaw = deg(14), hroll = deg(-12) }),
				},
				{
					seg = "F",
					u = 0.25,
					ease = "inout",
					pose = from(PLANTED, { broll = deg(-5), hyaw = deg(-14), hroll = deg(12) }),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = from(PLANTED, { broll = deg(4), hyaw = deg(12), hroll = deg(-9) }),
				},
				{
					seg = "F",
					u = 0.75,
					ease = "inout",
					pose = from(PLANTED, { broll = deg(-3), hyaw = deg(-9), hroll = deg(6) }),
				},
				{ seg = "F", u = 1, ease = "inout", pose = from(PLANTED, { hyaw = deg(3) }) },
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- idle: the snout up, sniffing the air
		sniff = {
			strike = 0.4,
			follow = 1.0,
			recover = 0.5,
			keys = {
				{ seg = "S", u = 1, ease = "inout", pose = from(PLANTED, { npitch = deg(-10), hpitch = deg(-14) }) },
				{
					seg = "F",
					u = 0.25,
					ease = "inout",
					pose = from(PLANTED, { npitch = deg(-12), hpitch = deg(-18), nyaw = deg(-6) }),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = from(PLANTED, { npitch = deg(-10), hpitch = deg(-14), nyaw = deg(-6) }),
				},
				{
					seg = "F",
					u = 0.75,
					ease = "inout",
					pose = from(PLANTED, { npitch = deg(-12), hpitch = deg(-18), nyaw = deg(5) }),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { npitch = deg(-10), hpitch = deg(-14), nyaw = deg(4) }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- death onto the left flank: the legs buckle, the roll, two kicks of the hind legs
		deathL = {
			strike = 0.12,
			follow = 0.6,
			recover = 0.25,
			legs = true,
			full = true,
			hold = true,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = ps({ bz = 0.1, bpitch = deg(7), npitch = deg(-6), hpitch = deg(-10) }),
				},
				{
					seg = "F",
					u = 0.45,
					ease = "in",
					pose = from(PLANTED, {
						by = -0.28,
						bpitch = deg(-6),
						FLf = 1.3,
						FRf = 1.3,
						HLf = 1.0,
						HRf = 1.0,
						npitch = deg(24),
						hpitch = deg(4),
					}),
				},
				-- the feet let go as it tips over
				{
					seg = "F",
					u = 0.62,
					ease = "inout",
					pose = {
						by = -0.22,
						broll = deg(20),
						bpx = -0.5,
						bpitch = deg(-5),
						FLf = 1.3,
						FRf = 1.3,
						HLf = 1.0,
						HRf = 1.0,
						npitch = deg(20),
						hpitch = deg(2),
					},
				},
				{
					seg = "F",
					u = 1,
					ease = "in",
					pose = {
						by = -0.02,
						broll = deg(86),
						bpx = -0.5,
						bpitch = deg(-3),
						FLu = deg(15),
						FRu = deg(20),
						HLu = deg(10),
						HRu = deg(18),
						FLf = deg(20),
						FRf = deg(25),
						HLf = deg(15),
						HRf = deg(15),
						FLo = deg(-12),
						HLo = deg(-12),
						nyaw = deg(16),
						npitch = deg(-4),
						hroll = deg(6),
						tpitch = deg(-10),
						FRo = deg(-18),
						HRo = deg(-18),
					},
				},
				{
					seg = "R",
					u = 0.3,
					ease = "out",
					pose = {
						by = 0.01,
						broll = deg(84),
						bpx = -0.5,
						bpitch = deg(-3),
						FLu = deg(15),
						FRu = deg(20),
						HLu = deg(10),
						HRu = deg(34),
						FLf = deg(20),
						FRf = deg(25),
						HLf = deg(15),
						HRf = deg(5),
						FLo = deg(-12),
						HLo = deg(-12),
						nyaw = deg(16),
						npitch = deg(-4),
						hroll = deg(6),
						tpitch = deg(-10),
						FRo = deg(-18),
						HRo = deg(-18),
					},
				},
				{
					seg = "R",
					u = 0.6,
					ease = "inout",
					pose = {
						by = -0.02,
						broll = deg(86),
						bpx = -0.5,
						bpitch = deg(-3),
						FLu = deg(15),
						FRu = deg(20),
						HLu = deg(10),
						HRu = deg(14),
						FLf = deg(20),
						FRf = deg(25),
						HLf = deg(15),
						HRf = deg(20),
						FLo = deg(-12),
						HLo = deg(-12),
						nyaw = deg(16),
						npitch = deg(-4),
						hroll = deg(6),
						tpitch = deg(-10),
						FRo = deg(-18),
						HRo = deg(-18),
					},
				},
				{
					seg = "R",
					u = 1,
					ease = "inout",
					pose = {
						by = -0.02,
						broll = deg(87),
						bpx = -0.5,
						bpitch = deg(-3),
						FLu = deg(15),
						FRu = deg(20),
						HLu = deg(10),
						HRu = deg(22),
						FLf = deg(20),
						FRf = deg(25),
						HLf = deg(15),
						HRf = deg(12),
						FLo = deg(-12),
						HLo = deg(-12),
						nyaw = deg(18),
						npitch = deg(-4),
						hroll = deg(6),
						tpitch = deg(-10),
						FRo = deg(-18),
						HRo = deg(-18),
					},
				},
			},
		},
	},
}
BOAR.actions.deathR = mirrored(BOAR.actions.deathL)

---------------------------------------------------------------- mammoth

-- Ice mammoth (§3.9): never gallops (a walk, then an amble in the same lateral sequence), flat pillar feet, a
-- rolling heavy gait, the trunk a pendulum behind the head, the ear fanning now and then; tusk sweeps and stomps.
-- Sizes in leg lengths: hips 0.69 behind the centre, shoulders 0.24 ahead, the body ~1.3 wide.
local MAMMOTH_STANCE = merge(PLANTED, { by = -0.015, npitch = deg(6), earL = 0.25, kcurl = 0.15 })
local function ms(over: { [string]: number }): { [string]: number }
	return from(MAMMOTH_STANCE, over)
end
local MAMMOTH_HIPS = { bpy = 0.96, bpz = 0.69 }
local MAMMOTH_FEET = { FLl = 1, FRl = 1, HLl = 1, HRl = 1 }

local MAMMOTH_AMBLE: Gait = {
	foot = { HL = 0, FL = 0.25, HR = 0.5, FR = 0.75 },
	duty = 0.5,
	k = 1.3,
	foldStance = deg(4),
	foldFront = deg(32),
	foldHind = deg(28),
	pawFront = deg(12),
	pawHind = deg(12),
	bob = 0.03,
	pitch = 0,
	flex = 0,
	roll = deg(2.5),
	spineYaw = deg(1),
	neck = deg(4),
	tail = 0,
	tailSway = deg(5),
	plant = true,
	lift = 0.1,
	level = 1,
	rollPivot = 0.25,
	headSway = deg(2),
	drop = 0.05,
}

-- The front rises about the hips (elephants do not rear high) with the trunk raised to trumpet and the ear out, a
-- trembling hold, then both fore feet stomp on the hit: the Elite II slam (W 1.4) and, held longer, the crush.
local function mammothStomp(rise: number): MotionTimeline.Action
	local function up(roll: number, front: number): { [string]: number }
		return ms(merge(MAMMOTH_HIPS, MAMMOTH_FEET, {
			by = 0.03,
			bpitch = deg(22),
			broll = deg(roll),
			HLu = deg(-22),
			HRu = deg(-22),
			FLk = 0,
			FRk = 0,
			FLu = deg(30 + front),
			FRu = deg(25 - front),
			FLf = deg(35),
			FRf = deg(30),
			npitch = deg(-6),
			hpitch = deg(-6),
			kpitch = 1.3,
			kcurl = 1.1,
			earL = 0.7,
		}))
	end
	return {
		strike = 0.16,
		follow = 0.4,
		recover = 0.45,
		legs = true,
		full = true,
		tremble = deg(1),
		keys = {
			{
				seg = "A",
				u = rise * 0.3,
				ease = "out",
				pose = ms({ bz = 0.05, by = -0.03, npitch = deg(10), kcurl = 0.4 }),
			},
			{ seg = "A", u = rise, ease = "inout", pose = up(0, 0) },
			{ seg = "A", u = rise + (1 - rise) * 0.4, ease = "inout", pose = up(2, 4) },
			{ seg = "A", u = rise + (1 - rise) * 0.75, ease = "inout", pose = up(-2, -4) },
			{ seg = "A", u = 1, ease = "inout", pose = up(0, 2) },
			{
				seg = "S",
				u = 1,
				ease = "in",
				pose = ms(merge(MAMMOTH_HIPS, MAMMOTH_FEET, {
					by = -0.05,
					bpitch = deg(-3),
					FLz = -0.15,
					FRz = -0.15,
					npitch = deg(16),
					kpitch = -0.3,
					kcurl = 0.2,
					earL = 0.3,
				})),
			},
			{
				seg = "F",
				u = 0.5,
				ease = "out",
				pose = ms({ by = -0.04, FLz = -0.15, FRz = -0.15, npitch = deg(18), hyaw = deg(6), kpitch = 0.3 }),
			},
			{
				seg = "F",
				u = 1,
				ease = "inout",
				pose = ms({ by = -0.03, FLz = -0.15, FRz = -0.15, npitch = deg(14), hyaw = deg(-6) }),
			},
			{ seg = "R", u = 0.5, ease = "inout", pose = ms({ FLz = -0.05, FLy = 0.06, FRz = -0.12 }) },
			{ seg = "R", u = 1, ease = "inout", pose = MAMMOTH_STANCE },
		},
	}
end

local MAMMOTH: Style = {
	gaits = {
		walk = {
			foot = { HL = 0, FL = 0.25, HR = 0.5, FR = 0.75 },
			duty = 0.65,
			k = 1.1,
			foldStance = deg(3),
			foldFront = deg(25),
			foldHind = deg(22),
			pawFront = deg(10),
			pawHind = deg(10),
			bob = 0.02,
			pitch = 0,
			flex = 0,
			roll = deg(2.5),
			spineYaw = deg(1.5),
			neck = deg(3),
			tail = 0,
			tailSway = deg(6),
			plant = true,
			lift = 0.08,
			level = 1,
			rollPivot = 0.28,
			headSway = deg(3),
			drop = 0.05,
		},
		-- the amble takes the trot's place; no gallop (its threshold is never reached)
		trot = MAMMOTH_AMBLE,
		gallop = MAMMOTH_AMBLE,
	},
	thresholds = { trot = 1.17, gallop = 99 },
	stance = MAMMOTH_STANCE,
	calm = { npitch = deg(5), earL = -0.1 },
	idle = { tail = 0 },
	ground = merge(PLANTED, MAMMOTH_FEET),
	basic = { "tusk" },
	abilities = {
		slam = "stomp",
		crush = "crush",
		heavyBlow = "gore",
		pounce = "lunge",
		leap = "lunge",
		charge = "lunge",
	},
	throw = "fling",
	death = { "deathL", "deathR" },
	aggro = "trumpet",
	spawn = "spawn",
	fidgets = { "dust", "fan", "sway" },
	fidgetEvery = { 6, 12 },
	rate = 0.04,
	trunk = { hz = 0.7, damp = 0.25, gain = 1.5, arm = 0.62, height = 1.3 },
	earFlap = { every = 5, amp = 0.35 },
	flinch = {
		front = { bz = 0.04, bpitch = deg(3), npitch = deg(-6), earL = 0.3 },
		back = { bz = -0.03, bpitch = deg(-2), npitch = deg(4) },
		left = { broll = deg(-3), bx = 0.03, syaw = deg(-3), hyaw = deg(6) },
		right = { broll = deg(3), bx = -0.03, syaw = deg(3), hyaw = deg(-6) },
	},
	actions = {
		-- the regular blow (W 0.55): the head cocked to one side with the trunk curled out of the way, the weight
		-- back, then the tusks sweep across on the hit with a short lunge over planted feet; the trunk swings on
		tusk = {
			strike = 0.16,
			follow = 0.2,
			recover = 0.4,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = ms({
						bz = 0.05,
						by = -0.01,
						broll = deg(-1.5),
						hyaw = deg(18),
						nyaw = deg(10),
						npitch = deg(10),
						kcurl = 0.9,
						kpitch = 0.3,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ms({
						bz = -0.18,
						by = -0.02,
						broll = deg(1.5),
						byaw = deg(-4),
						hyaw = deg(-20),
						nyaw = deg(-12),
						npitch = deg(14),
						hroll = deg(-6),
						kcurl = 0.5,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = ms({
						bz = -0.15,
						byaw = deg(-5),
						hyaw = deg(-26),
						nyaw = deg(-14),
						npitch = deg(8),
						kcurl = 0.3,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = MAMMOTH_STANCE },
			},
		},
		stomp = mammothStomp(0.45),
		crush = mammothStomp(0.36),
		-- Heavy Blow (Elite, W 1.8) "gore": the head low and cocked, the trunk curled up, a long rumbling gather, then
		-- the tusks sweep up and across the cone with a lunge
		gore = {
			strike = 0.2,
			follow = 0.3,
			recover = 0.5,
			legs = true,
			full = true,
			tremble = deg(0.8),
			keys = {
				{
					seg = "A",
					u = 0.4,
					ease = "out",
					pose = ms({
						bz = 0.08,
						by = -0.02,
						hyaw = deg(-25),
						nyaw = deg(-10),
						npitch = deg(18),
						kcurl = 1.1,
						kpitch = 0.4,
						earL = 0.5,
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ms({
						bz = 0.1,
						by = -0.03,
						hyaw = deg(-28),
						nyaw = deg(-12),
						npitch = deg(20),
						kcurl = 1.2,
						kpitch = 0.45,
						earL = 0.55,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ms({
						bz = -0.25,
						by = -0.02,
						byaw = deg(5),
						hyaw = deg(24),
						nyaw = deg(12),
						npitch = deg(-8),
						hroll = deg(8),
						kcurl = 0.6,
						earL = 0.6,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = ms({
						bz = -0.22,
						byaw = deg(6),
						hyaw = deg(30),
						nyaw = deg(14),
						npitch = deg(-4),
						kcurl = 0.3,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = MAMMOTH_STANCE },
			},
		},
		-- Pounce (Elite II, W 1.4; teleported onto the circle at the hit): the front lifts, a low lumbering lunge, both
		-- fore feet stomp on the hit
		lunge = {
			strike = 0.4,
			follow = 0.35,
			recover = 0.45,
			legs = true,
			full = true,
			travel = true,
			tremble = deg(1),
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ms(merge(MAMMOTH_HIPS, MAMMOTH_FEET, {
						by = -0.02,
						bpitch = deg(8),
						HLu = deg(-8),
						HRu = deg(-8),
						npitch = deg(4),
						kpitch = 0.6,
						kcurl = 0.9,
						earL = 0.6,
					})),
				},
				{
					seg = "S",
					u = 0.5,
					ease = "out",
					pose = {
						by = 0.14,
						bpitch = deg(6),
						FLu = deg(30),
						FRu = deg(30),
						FLf = deg(30),
						FRf = deg(30),
						HLu = deg(-20),
						HRu = deg(-20),
						npitch = deg(6),
						kpitch = 0.8,
						kcurl = 0.9,
						earL = 0.6,
						travel = 0.5,
					},
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ms(merge(MAMMOTH_FEET, {
						by = -0.05,
						bpitch = deg(-3),
						FLz = -0.15,
						FRz = -0.15,
						npitch = deg(16),
						kpitch = -0.2,
						travel = 1,
					})),
				},
				{
					seg = "F",
					u = 1,
					ease = "out",
					pose = ms({ by = -0.03, FLz = -0.15, FRz = -0.15, npitch = deg(12), hyaw = deg(6), travel = 1 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = from(MAMMOTH_STANCE, { travel = 1 }) },
			},
		},
		-- the thrown blow (Elite II): the trunk scoops a block of ice from the ground, swings it up over the head and
		-- whips it forward; it leaves the trunk on the hit
		fling = {
			strike = 0.16,
			follow = 0.25,
			recover = 0.45,
			legs = true,
			keys = {
				{ seg = "A", u = 0.4, ease = "inout", pose = ms({ npitch = deg(22), kpitch = 0.35, kcurl = -0.2 }) },
				{ seg = "A", u = 0.55, ease = "lin", pose = ms({ npitch = deg(22), kpitch = 0.3, kcurl = 0.7 }) },
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = ms({ bpitch = deg(3), npitch = deg(-8), kpitch = 1.6, kcurl = 1.2, earL = 0.5 }),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ms({ bz = -0.05, npitch = deg(10), kpitch = 0.6, kcurl = -0.2, earL = 0.5 }),
				},
				{ seg = "F", u = 1, ease = "out", pose = ms({ npitch = deg(12), kpitch = -0.2, kcurl = 0 }) },
				{ seg = "R", u = 1, ease = "inout", pose = MAMMOTH_STANCE },
			},
		},
		-- the first aggro: the head up, the trunk raised to trumpet, the ear out
		trumpet = {
			strike = 0.12,
			follow = 0.6,
			recover = 0.45,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = ms({ bpitch = deg(2), npitch = deg(-8), kpitch = 1.0, kcurl = 0.9, earL = 0.6 }),
				},
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = ms({
						bpitch = deg(4),
						npitch = deg(-14),
						hpitch = deg(-6),
						kpitch = 1.4,
						kcurl = 1.2,
						earL = 0.8,
					}),
				},
				{
					seg = "F",
					u = 0.6,
					ease = "inout",
					pose = ms({
						bpitch = deg(4),
						npitch = deg(-12),
						hpitch = deg(-6),
						hyaw = deg(4),
						kpitch = 1.45,
						kcurl = 1.15,
						earL = 0.8,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = ms({ bpitch = deg(2), npitch = deg(-6), kpitch = 0.9, kcurl = 0.8, earL = 0.6 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = MAMMOTH_STANCE },
			},
		},
		spawn = {
			strike = 0.3,
			follow = 0.45,
			recover = 0.25,
			legs = true,
			full = true,
			keys = {
				{ seg = "A", u = 0, ease = "lin", pose = ms({ by = -0.25, npitch = deg(18), kcurl = 0.6 }) },
				{ seg = "S", u = 1, ease = "out", pose = MAMMOTH_STANCE },
				{
					seg = "F",
					u = 0.3,
					ease = "inout",
					pose = ms({ broll = deg(4), hroll = deg(-8), hyaw = deg(6), earL = 0.8 }),
				},
				{
					seg = "F",
					u = 0.65,
					ease = "inout",
					pose = ms({ broll = deg(-4), hroll = deg(8), hyaw = deg(-6), earL = 0.1 }),
				},
				{ seg = "F", u = 1, ease = "inout", pose = MAMMOTH_STANCE },
				{ seg = "R", u = 1, ease = "inout", pose = MAMMOTH_STANCE },
			},
		},
		-- idle: the trunk sweeps the ground and tosses snow over the back
		dust = {
			strike = 0.6,
			follow = 1.0,
			recover = 0.7,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { npitch = deg(16), kpitch = 0.4, kcurl = -0.3 }),
				},
				{
					seg = "F",
					u = 0.3,
					ease = "inout",
					pose = from(PLANTED, { npitch = deg(16), kpitch = 0.2, kside = 0.3, kcurl = 0.5 }),
				},
				{
					seg = "F",
					u = 0.7,
					ease = "out",
					pose = from(PLANTED, { npitch = deg(-6), kpitch = 1.8, kcurl = 1.0 }),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { npitch = deg(-4), kpitch = 1.2, kcurl = 0.6 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- idle: the ear fans hard a few times
		fan = {
			strike = 0.3,
			follow = 1.2,
			recover = 0.3,
			keys = {
				{ seg = "S", u = 1, ease = "out", pose = from(PLANTED, { earL = 0.6, earR = 0.6 }) },
				{ seg = "F", u = 0.2, ease = "inout", pose = from(PLANTED, { earL = 0.05, earR = 0.05 }) },
				{
					seg = "F",
					u = 0.4,
					ease = "inout",
					pose = from(PLANTED, { earL = 0.6, earR = 0.6, hroll = deg(3) }),
				},
				{
					seg = "F",
					u = 0.6,
					ease = "inout",
					pose = from(PLANTED, { earL = 0.05, earR = 0.05, hroll = deg(-3) }),
				},
				{ seg = "F", u = 0.8, ease = "inout", pose = from(PLANTED, { earL = 0.55, earR = 0.55 }) },
				{ seg = "F", u = 1, ease = "inout", pose = from(PLANTED, { earL = 0.1, earR = 0.1 }) },
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- idle: a slow sway of the weight from side to side with the trunk swinging along
		sway = {
			strike = 0.8,
			follow = 1.6,
			recover = 0.8,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { bx = -0.04, broll = deg(2), kside = 0.25 }),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "inout",
					pose = from(PLANTED, { bx = 0.04, broll = deg(-2), kside = -0.25 }),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = from(PLANTED, { bx = -0.03, broll = deg(1.5), kside = 0.2 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = PLANTED },
			},
		},
		-- death onto the left flank: the hind legs fold under the weight, then the front, the roll about the ground
		-- line under that flank, the trunk and the ear limp
		deathL = {
			strike = 0.12,
			follow = 0.65,
			recover = 0.25,
			legs = true,
			full = true,
			hold = true,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = ms({ bz = 0.05, bpitch = deg(4), npitch = deg(-8), kpitch = 0.4, earL = 0.6 }),
				},
				{
					seg = "F",
					u = 0.3,
					ease = "in",
					pose = from(PLANTED, { by = -0.12, bpitch = deg(-8), bpz = -0.24, npitch = deg(12), kpitch = 0.2 }),
				},
				{
					seg = "F",
					u = 0.55,
					ease = "in",
					pose = from(PLANTED, {
						by = -0.28,
						bpitch = deg(-2),
						FLf = 1.1,
						FRf = 1.1,
						HLf = 1.1,
						HRf = 1.1,
						npitch = deg(22),
						kcurl = -0.2,
					}),
				},
				-- the feet let go as it tips over
				{
					seg = "F",
					u = 0.7,
					ease = "inout",
					pose = {
						by = -0.22,
						broll = deg(16),
						bpx = -0.75,
						bpitch = deg(-2),
						FLf = 1.1,
						FRf = 1.1,
						HLf = 1.1,
						HRf = 1.1,
						npitch = deg(20),
						kcurl = -0.2,
					},
				},
				{
					seg = "F",
					u = 1,
					ease = "in",
					pose = {
						by = -0.04,
						broll = deg(86),
						bpx = -0.75,
						bpy = -0.04,
						FLu = deg(10),
						FRu = deg(14),
						HLu = deg(8),
						HRu = deg(12),
						FLf = deg(10),
						FRf = deg(14),
						HLf = deg(10),
						HRf = deg(12),
						nyaw = deg(14),
						npitch = deg(-4),
						hroll = deg(6),
						kside = 0.5,
						kcurl = -0.2,
						earL = -0.1,
						FLo = deg(-8),
						HLo = deg(-8),
						FRo = deg(-14),
						HRo = deg(-14),
					},
				},
				{
					seg = "R",
					u = 0.4,
					ease = "out",
					pose = {
						by = -0.025,
						broll = deg(85),
						bpx = -0.75,
						bpy = -0.04,
						FLu = deg(10),
						FRu = deg(14),
						HLu = deg(8),
						HRu = deg(12),
						FLf = deg(10),
						FRf = deg(14),
						HLf = deg(10),
						HRf = deg(12),
						nyaw = deg(14),
						npitch = deg(-4),
						hroll = deg(6),
						kside = 0.55,
						kcurl = -0.2,
						earL = -0.1,
						FLo = deg(-8),
						HLo = deg(-8),
						FRo = deg(-14),
						HRo = deg(-14),
					},
				},
				{
					seg = "R",
					u = 1,
					ease = "inout",
					pose = {
						by = -0.04,
						broll = deg(87),
						bpx = -0.75,
						bpy = -0.04,
						FLu = deg(10),
						FRu = deg(14),
						HLu = deg(8),
						HRu = deg(12),
						FLf = deg(10),
						FRf = deg(14),
						HLf = deg(10),
						HRf = deg(12),
						nyaw = deg(15),
						npitch = deg(-4),
						hroll = deg(6),
						kside = 0.5,
						kcurl = -0.2,
						earL = -0.1,
						FLo = deg(-8),
						HLo = deg(-8),
						FRo = deg(-14),
						HRo = deg(-14),
					},
				},
			},
		},
	},
}
MAMMOTH.actions.deathR = mirrored(MAMMOTH.actions.deathL)

---------------------------------------------------------------- dragon (youngFrostDragon, the new model)

-- Young frost dragon on its new model (2026-10-31, docs/ANIM-WZORCE.md F4 as built): four planted legs, a long neck
-- and a six-bone tail on the quadruped's engine, and wings (Logic/DragonMotion) folded along the body at rest, opened
-- for the flaps, the pounce, the roar and the breath. Its model has no jaw bone (the snout is one piece), so the bites,
-- the roar and the breath are the neck's and the head's. A reptile's gaits: a lateral walk with the spine and tail
-- swinging in one S-wave, a diagonal trot, a heavy bound whose downstroke lifts it into the gathered flight. The gait
-- comes from the server's intent (wander, home, chase), not from its speed over its short legs.
-- Sizes in leg lengths (hind hip height): hips 0.26 ahead of the centre, shoulders 0.97 ahead, the snout 1.9 ahead
-- and 1.85 up, the tail's tip 1.9 behind; the body ~0.7 wide.
local DRAGON_STANCE = merge(PLANTED, {
	FLl = 1,
	FRl = 1,
	HLl = 1,
	HRl = 1,
	by = -0.04,
	bpitch = deg(-2),
	npitch = deg(14),
	hpitch = deg(-8),
	tpitch = deg(6),
	we = 0.06,
})
local function ds(over: { [string]: number }): { [string]: number }
	return from(DRAGON_STANCE, over)
end
-- the hips: the pivot of a rear-up (the hind feet stay planted under them)
local DRAGON_HIPS = { bpy = 1.0, bpz = -0.26 }
local DRAGON_REST = merge(PLANTED, { FLl = 1, FRl = 1, HLl = 1, HRl = 1 })

-- The right fore claw raised with the body wound to the right and the right wing half open for balance, raked down
-- and across to strike the ground ahead on the hit (W 0.55); its left twin takes another turn.
local DRAGON_CLAW: MotionTimeline.Action = {
	strike = 0.16,
	follow = 0.18,
	recover = 0.55,
	legs = true,
	full = true,
	sided = true,
	keys = {
		{
			seg = "A",
			u = 0.4,
			ease = "inout",
			pose = ds({
				bx = -0.04,
				bz = 0.04,
				broll = deg(3),
				bpitch = deg(4),
				byaw = deg(-4),
				FRk = 0,
				FRu = deg(16),
				FRf = deg(14),
				FRp = deg(4),
				FRo = deg(5),
				hyaw = deg(8),
				npitch = deg(6),
				wRo = 0.25,
			}),
		},
		{
			seg = "A",
			u = 1,
			ease = "inout",
			pose = ds({
				bx = -0.06,
				bz = 0.07,
				broll = deg(4),
				bpitch = deg(7),
				byaw = deg(-8),
				syaw = deg(-5),
				FRk = 0,
				FRu = deg(86),
				FRf = deg(72),
				FRp = deg(20),
				FRo = deg(18),
				hyaw = deg(12),
				nyaw = deg(6),
				npitch = deg(2),
				wRo = 0.45,
				wRe = 0.2,
			}),
		},
		{
			seg = "S",
			u = 0.5,
			ease = "in",
			pose = ds({
				bx = -0.02,
				bz = -0.08,
				broll = deg(1),
				bpitch = deg(2),
				FRk = 0,
				FRu = deg(70),
				FRf = deg(30),
				FRo = deg(6),
				hyaw = deg(2),
				npitch = deg(10),
				wRo = 0.3,
			}),
		},
		{
			seg = "S",
			u = 1,
			ease = "in",
			pose = ds({
				bx = 0.03,
				bz = -0.2,
				by = -0.07,
				broll = deg(-2),
				bpitch = deg(-4),
				byaw = deg(7),
				syaw = deg(4),
				FRz = -0.4,
				FRu = deg(25),
				FRo = deg(-6),
				hyaw = deg(-8),
				npitch = deg(20),
				wRo = 0.12,
			}),
		},
		{
			seg = "F",
			u = 1,
			ease = "out",
			pose = ds({
				bx = 0.05,
				bz = -0.18,
				by = -0.06,
				broll = deg(-3),
				byaw = deg(9),
				syaw = deg(5),
				FRz = -0.4,
				FRo = deg(-8),
				hyaw = deg(-12),
				npitch = deg(18),
			}),
		},
		-- the paw steps back under the shoulder: up, over, straight down (studio review 2026-10-31: it slid)
		{ seg = "R", u = 0.3, ease = "inout", pose = ds({ bz = -0.1, byaw = deg(3), FRz = -0.3, FRy = 0.09 }) },
		{ seg = "R", u = 0.6, ease = "inout", pose = ds({ bz = -0.05, byaw = deg(1), FRz = -0.02, FRy = 0.06 }) },
		{ seg = "R", u = 0.78, ease = "inout", pose = ds({ bz = -0.02 }) },
		{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
	},
}

-- On the hind legs (by `rise` of the anticipation) with the wings open, two flaps on the timeline (`flaps` > 0) or a
-- trembling hold, then both fore feet crash down 0.4 leg lengths ahead on the hit with the wings beating down: the
-- crush (W 2.2, rearing high and flapping) and the Elite's claw rake (W 1.8, a lower rear, the claws drawn back
-- through the ground after it).
-- (studio review 2026-10-31: the fore feet rose to twice the withers' height; a lower rear with the fore legs drawn up
-- and tucked keeps them at about 1.3 times it)
local LIFT, TUCK = 50, 72
local function dragonRear(rise: number, pitch: number, flaps: number, rake: boolean): MotionTimeline.Action
	local up = ds(merge(DRAGON_HIPS, {
		by = 0.03,
		bpitch = deg(pitch),
		HLl = 1,
		HRl = 1,
		FLk = 0,
		FRk = 0,
		FLu = deg(LIFT),
		FRu = deg(LIFT),
		FLf = deg(TUCK),
		FRf = deg(TUCK),
		FLp = deg(-10),
		FRp = deg(-10),
		npitch = deg(-14 - pitch * 0.3),
		hpitch = deg(14),
		-- the tail lifted against the rear, most at its root (it pivots about the hips and would sink into the
		-- ground): it rests on the ground behind
		tpitch = deg(pitch * 1.2),
		tP1 = deg(pitch * 0.25),
		wo = if flaps > 0 then 1.9 else 1.35,
		we = if flaps > 0 then 0.25 else 0.4,
		ws = 0.1,
	}))
	local function cocked(roll: number, high: number, beat: number, flap: number): { [string]: number }
		local pose = table.clone(up)
		pose.broll = deg(roll)
		pose.bpitch = deg(pitch + 3)
		pose.tpitch = deg((pitch + 3) * 1.2)
		pose.tP1 = deg((pitch + 3) * 0.25)
		pose.FLu, pose.FRu = deg(LIFT + 10 + high), deg(LIFT + 10 + high)
		pose.FLf, pose.FRf = deg(TUCK + 10 + high), deg(TUCK + 10 + high)
		pose.beat, pose.flap = beat, flap
		return pose
	end
	local keys: { MotionTimeline.Key } = {
		{
			seg = "A",
			u = rise * 0.5,
			ease = "inout",
			pose = ds({ by = -0.07, bz = 0.05, bpitch = deg(-4), npitch = deg(8), wo = 0.6, we = 0.2 }),
		},
	}
	if flaps > 0 then
		-- up, then `flaps` beats between the rise and the end of the gather (the wings at the top on its end); the
		-- strokes kept within the per-frame turn of docs/ANIM-WZORCE.md 5.8
		local upFlap = table.clone(up)
		upFlap.beat, upFlap.flap = 0, 0.8
		table.insert(keys, { seg = "A", u = rise, ease = "inout", pose = upFlap })
		table.insert(keys, { seg = "A", u = rise + (1 - rise) * 0.85, ease = "lin", pose = cocked(2, 6, flaps, 0.8) })
		table.insert(keys, { seg = "A", u = 1, ease = "inout", pose = cocked(-1, 12, flaps, 0) })
	else
		table.insert(keys, { seg = "A", u = rise, ease = "inout", pose = up })
		table.insert(keys, { seg = "A", u = rise + (1 - rise) * 0.5, ease = "inout", pose = cocked(3, 6, 0, 0) })
		table.insert(keys, { seg = "A", u = 1, ease = "inout", pose = cocked(-2, 12, 0, 0) })
	end
	-- the crash: the wings beat down with it
	table.insert(keys, {
		seg = "S",
		u = 1,
		ease = "in",
		pose = ds(merge(DRAGON_HIPS, {
			by = -0.09,
			bz = -0.1,
			bpitch = deg(-6),
			HLl = 1,
			HRl = 1,
			FLz = -0.4,
			FRz = -0.4,
			FLu = deg(22),
			FRu = deg(22),
			npitch = deg(28),
			hpitch = deg(-8),
			tpitch = deg(2),
			wo = 1.7,
			we = -0.45,
			ws = 0.3,
			beat = flaps,
		})),
	})
	if rake then
		-- the claws dragged back through the ground: the toes curl back under the planted feet as the body pulls back
		table.insert(keys, {
			seg = "F",
			u = 0.55,
			ease = "inout",
			pose = ds({
				by = -0.08,
				bz = -0.02,
				FLz = -0.4,
				FRz = -0.4,
				FLp = deg(25),
				FRp = deg(25),
				npitch = deg(24),
				hpitch = deg(-10),
				wo = 1.2,
				we = -0.1,
				beat = flaps,
			}),
		})
	else
		table.insert(keys, {
			seg = "F",
			u = 0.4,
			ease = "out",
			pose = ds({
				by = -0.08,
				bz = -0.08,
				FLz = -0.4,
				FRz = -0.4,
				npitch = deg(26),
				hpitch = deg(-14),
				wo = 1.4,
				we = -0.2,
				beat = flaps,
			}),
		})
	end
	table.insert(keys, {
		seg = "F",
		u = 1,
		ease = "inout",
		pose = ds({
			by = -0.05,
			bz = -0.05,
			FLz = -0.4,
			FRz = -0.4,
			npitch = deg(20),
			hpitch = deg(-10),
			hyaw = deg(8),
			wo = 0.6,
			we = 0.05,
			beat = flaps,
		}),
	})
	-- the fore feet step back under the shoulders one after the other: up, over, straight down (no sliding)
	local function step(u: number, fl: { number }, fr: { number }, wo: number)
		table.insert(keys, {
			seg = "R",
			u = u,
			ease = "inout",
			pose = ds({
				by = -0.04,
				bz = -0.03,
				FLy = fl[1],
				FLz = fl[2],
				FRy = fr[1],
				FRz = fr[2],
				npitch = deg(15),
				wo = wo,
			}),
		})
	end
	step(0.16, { 0.09, -0.34 }, { 0, -0.4 }, 0.3)
	step(0.32, { 0.06, -0.02 }, { 0, -0.4 }, 0.25)
	step(0.42, { 0, 0 }, { 0, -0.4 }, 0.2)
	step(0.58, { 0, 0 }, { 0.09, -0.34 }, 0.15)
	step(0.74, { 0, 0 }, { 0.06, -0.02 }, 0.1)
	step(0.84, { 0, 0 }, { 0, 0 }, 0.05)
	table.insert(keys, { seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE })
	return {
		strike = 0.18,
		follow = if rake then 0.5 else 0.45,
		recover = 1.05,
		legs = true,
		full = true,
		tremble = deg(if flaps > 0 then 0.8 else 1.6),
		keys = keys,
	}
end

-- The tail's whip (a regular blow): the spine and the tail wind the other way over the planted feet, it springs off
-- them and spins 125 degrees in the air with the tail swinging through the target on the hit, lands, and hops back
-- round onto its feet (studio review 2026-10-31: the body turns only while the feet are off the ground, so they never
-- slide; the spin stays a whip).
local TAIL_SPIN = deg(125)
local function tailHop(yaw: number, by: number, tuck: number, extra: { [string]: number }): { [string]: number }
	return merge({
		by = by,
		byaw = yaw,
		FLu = deg(10),
		FRu = deg(10),
		HLu = deg(-6),
		HRu = deg(-6),
		FLf = deg(tuck),
		FRf = deg(tuck),
		HLf = deg(tuck),
		HRf = deg(tuck),
		npitch = deg(12),
		hpitch = deg(-6),
		tpitch = deg(10),
		we = 0.06,
	}, extra)
end
local DRAGON_TAIL: MotionTimeline.Action = {
	strike = 0.24,
	follow = 0.4,
	recover = 0.5,
	legs = true,
	full = true,
	sided = true,
	keys = {
		{
			seg = "A",
			u = 0.5,
			ease = "inout",
			pose = ds({
				by = -0.06,
				bx = 0.02,
				syaw = deg(-12),
				tyaw = deg(-35),
				tpitch = deg(12),
				nyaw = deg(10),
				hyaw = deg(8),
			}),
		},
		{
			seg = "A",
			u = 1,
			ease = "inout",
			pose = ds({
				by = -0.11,
				bx = 0.03,
				syaw = deg(-16),
				tyaw = deg(-60),
				tpitch = deg(16),
				nyaw = deg(14),
				hyaw = deg(12),
				wo = 0.3,
			}),
		},
		-- the spring: off the ground before it turns
		{
			seg = "S",
			u = 0.3,
			ease = "out",
			pose = tailHop(deg(6), 0.16, 32, { syaw = deg(-8), tyaw = deg(-55), nyaw = deg(4), wo = 0.5, we = 0.2 }),
		},
		-- in the air, the spin half way
		{
			seg = "S",
			u = 0.65,
			ease = "in",
			pose = tailHop(deg(58), 0.19, 30, { syaw = deg(8), tyaw = deg(-30), nyaw = deg(-12), wo = 0.6, we = 0.25 }),
		},
		-- the hit, still in the air: the tail's tip sweeps through the front
		{
			seg = "S",
			u = 1,
			ease = "out",
			pose = tailHop(TAIL_SPIN, 0.11, 24, {
				syaw = deg(14),
				tyaw = deg(70),
				tY5 = deg(10),
				tY6 = deg(14),
				tpitch = deg(14),
				nyaw = deg(-28),
				hyaw = deg(-18),
				wo = 0.6,
				we = 0.25,
			}),
		},
		-- down on its feet, the turn spent (the legs held as they land: the feet stay where they touch)
		{
			seg = "F",
			u = 0.3,
			ease = "out",
			pose = tailHop(TAIL_SPIN + deg(6), -0.06, 18, {
				HLf = deg(6),
				HRf = deg(6),
				syaw = deg(6),
				tyaw = deg(40),
				nyaw = deg(-24),
				hyaw = deg(-14),
				wo = 0.4,
				we = 0.1,
			}),
		},
		{
			seg = "F",
			u = 0.5,
			ease = "inout",
			pose = tailHop(
				TAIL_SPIN + deg(6),
				-0.06,
				18,
				{ HLf = deg(6), HRf = deg(6), syaw = deg(6), tyaw = deg(20), nyaw = deg(-14), wo = 0.3 }
			),
		},
		-- the hop back round, the feet up while it turns
		{
			seg = "F",
			u = 0.8,
			ease = "out",
			pose = tailHop(TAIL_SPIN, 0.15, 32, { tyaw = deg(-4), nyaw = deg(-8), wo = 0.3 }),
		},
		{
			seg = "R",
			u = 0.4,
			ease = "inout",
			pose = tailHop(deg(14), 0.13, 30, { tyaw = deg(-14), nyaw = deg(4), wo = 0.2 }),
		},
		-- the feet over their own footprints, then straight down onto them
		{
			seg = "R",
			u = 0.6,
			ease = "inout",
			pose = ds({
				by = 0.02,
				FLy = 0.1,
				FRy = 0.1,
				HLy = 0.08,
				HRy = 0.08,
				tyaw = deg(-12),
				npitch = deg(10),
				wo = 0.15,
			}),
		},
		{ seg = "R", u = 0.8, ease = "in", pose = ds({ by = -0.07, tyaw = deg(-8), npitch = deg(12) }) },
		{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
	},
}

-- Death onto the left flank: the jolt, the legs buckle and the wings slip open, the roll about the ground under that
-- flank over the feet still planted on it, both wings fanned out on the ground behind the back (the upper one draped
-- over the lower), the neck and the tail settling, a last twitch.
local DRAGON_SIDE = {
	by = -0.13,
	broll = deg(84),
	bpx = -0.42,
	bpitch = deg(-3),
	FLu = deg(18),
	FRu = deg(12),
	HLu = deg(10),
	HRu = deg(18),
	FLf = deg(20),
	FRf = deg(26),
	HLf = deg(16),
	HRf = deg(14),
	FLo = deg(-28),
	HLo = deg(-28),
	FRo = deg(-20),
	HRo = deg(-20),
	nyaw = deg(24),
	npitch = deg(-30),
	hpitch = deg(-10),
	hroll = deg(10),
	tyaw = deg(18),
	tpitch = deg(-14),
	-- both wings fanned out on the ground behind the back, the upper one draped over the lower
	wLo = 1.8,
	wLe = 1.5,
	wRo = 1.5,
	wRe = 1.8,
	wRb = 0.3,
}

local DRAGON: Style = {
	gaits = {
		-- a lateral walk: the spine and the tail swing in one wave, the head held steady over it
		-- (studio review 2026-10-31: the swing took 0.23 s and the long fore legs went straight at the ends of the
		-- stride, so a leg snapped 30 degrees in a frame at the lift-off: a slower cadence with the same stride, the fore
		-- feet a shorter stance, the shoulders carried lower, the lift and the paw's levelling eased in)
		walk = {
			foot = { HL = 0, FL = 0.25, HR = 0.5, FR = 0.75 },
			duty = 0.6,
			dutyFront = 0.5,
			k = 1.5,
			foldStance = deg(4),
			foldFront = deg(38),
			foldHind = deg(34),
			pawFront = deg(18),
			pawHind = deg(20),
			bob = 0.014,
			pitch = 0,
			flex = 0,
			roll = deg(3),
			spineYaw = deg(6),
			neck = deg(6),
			tail = 0,
			tailSway = deg(4),
			plant = true,
			lift = 0.15,
			liftFront = 0.15,
			level = 0.8,
			rollPivot = 0.25,
			headSway = deg(-3),
			drop = 0.05,
			stoop = 0.1,
			onPrint = true,
			levelIn = 0.6,
		},
		trot = {
			foot = { HL = 0, FR = 0.02, HR = 0.5, FL = 0.52 },
			duty = 0.5,
			dutyFront = 0.45,
			k = 1.7,
			foldStance = deg(6),
			foldFront = deg(55),
			foldHind = deg(45),
			pawFront = deg(30),
			pawHind = deg(25),
			bob = 0.03,
			pitch = 0,
			flex = 0,
			roll = deg(2),
			spineYaw = deg(4),
			neck = deg(9),
			tail = deg(4),
			tailSway = deg(4),
			plant = true,
			lift = 0.17,
			liftFront = 0.2,
			level = 0.6,
			rollPivot = 0.15,
			headSway = deg(-2),
			drop = 0.05,
			stoop = 0.1,
			onPrint = true,
			levelIn = 0.6,
		},
		-- a heavy bound: the hind feet together, then the fore feet; the wings half open beat down as the fore feet
		-- push it up into the gathered flight (Data/QuadStyles Wings `pump`)
		gallop = {
			foot = { HL = 0, HR = 0.05, FL = 0.45, FR = 0.5 },
			duty = 0.3,
			dutyFront = 0.28,
			k = 2.8,
			foldStance = deg(8),
			foldFront = deg(80),
			foldHind = deg(60),
			pawFront = deg(40),
			pawHind = deg(30),
			bob = 0.05,
			pitch = deg(6),
			flex = deg(12),
			roll = 0,
			spineYaw = 0,
			neck = deg(10),
			tail = deg(6),
			tailSway = deg(3),
			plant = true,
			lift = 0.2,
			liftFront = 0.3,
			level = 0.4,
			drop = 0.05,
			stoop = 0.1,
			onPrint = true,
			levelIn = 0.6,
		},
	},
	thresholds = { trot = 2.3, gallop = 3.6 },
	serverGait = true,
	-- (a real spawn, 2026-10-31: the wander's slow stretches glided on planted feet) it steps at any crawl
	stepFrom = 0.08,
	tailBones = 6,
	wings = {
		-- folded and carried high (owner 2026-10-31: "te skrzydła takie opadnięte są"): the humerus back and up from
		-- the shoulder, the elbow over the back, the wrist up by the shoulder, the fingers swept back toward the tail,
		-- the membrane folded along the top of the flank, its top side out
		fold = { f = deg(100), h = deg(75), hum = { 0.12, 0.6, 1 }, nrm = { -1, 0.6, 0 } },
		beat = {
			top = deg(60),
			bottom = deg(-40),
			fore = deg(14),
			back = deg(-18),
			fold = deg(45),
			twist = deg(20),
		},
		-- half open as modelled (the wrists high), held up, the fingers spread level, not hanging
		pump = { open = 1, amp = 0.45, at = 0.45, lift = 0.15, hand = 0.15, tips = 0.25 },
		tail = { hz = 1.1, damp = 0.45, gain = 0.6 },
	},
	stance = DRAGON_STANCE,
	calm = { npitch = deg(6), tpitch = deg(-2) },
	idle = { tail = 0 },
	ground = DRAGON_REST,
	-- dazed: the head hanging and wobbling, the wings slipping half open, the tail down
	stun = { by = -0.05, npitch = deg(26), hpitch = deg(12), tpitch = deg(-10), wo = 0.3, we = -0.12 },
	labExtra = { "stun", "freeze" },
	-- bites with a claw, the wings' buffet and the tail's whip between them
	basic = { "bite", "claw", "bite", "buffet", "bite", "clawL", "bite", "tail" },
	abilities = {
		frostBreath = "breath",
		fireBreath = "breath",
		heavyBlow = "rake",
		crush = "stomp",
		slam = "stomp",
		pounce = "pounce",
		leap = "pounce",
		charge = "pounce",
		wingBuffet = "buffet",
		tailSwipe = "tail",
	},
	throw = "spit",
	death = { "deathL", "deathR" },
	-- (studio review 2026-10-31) a blow from the front or behind drops it onto its belly, one from a side throws it
	-- onto the other flank
	deaths = { front = { "death" }, back = { "death" }, left = { "deathR" }, right = { "deathL" } },
	-- (studio review 2026-10-31: the lab's alert showed the idle) the first sight of a fighter: the short roar of
	-- docs/ANIM-WZORCE.md 5.3; the full roar stays in the kit
	aggro = "alert",
	spawn = "spawn",
	fidgets = { "resettle", "stretch", "resettle" },
	fidgetEvery = { 7, 13 },
	rate = 0.05,
	flinch = {
		-- (studio review 2026-10-31: the blow sinks it onto its fore legs instead of lifting the shoulders off them)
		front = { bz = 0.05, by = -0.03, bpitch = deg(-2), npitch = deg(-10), hpitch = deg(-6), wo = 0.15 },
		back = { bz = -0.03, by = -0.03, bpitch = deg(-1), npitch = deg(8), wo = 0.12 },
		left = { broll = deg(-4), bx = 0.04, by = -0.02, syaw = deg(-6), hyaw = deg(12), wLo = 0.2 },
		right = { broll = deg(4), bx = -0.04, by = -0.02, syaw = deg(6), hyaw = deg(-12), wRo = 0.2 },
	},
	actions = {
		-- the bite (W 0.55): the neck coils back and up, then strikes forward and down with the body behind it, a
		-- tearing shake
		bite = {
			strike = 0.16,
			follow = 0.22,
			recover = 0.42,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 0.45,
					ease = "out",
					pose = ds({ bz = 0.05, by = -0.05, bpitch = deg(2), npitch = deg(-12), hpitch = deg(6), we = 0.12 }),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ds({
						bz = 0.09,
						by = -0.07,
						bpitch = deg(3),
						npitch = deg(-22),
						hpitch = deg(12),
						hyaw = deg(-6),
						nyaw = deg(-4),
						tpitch = deg(10),
						we = 0.16,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ds({
						bz = -0.16,
						by = -0.06,
						bpitch = deg(-6),
						npitch = deg(42),
						hpitch = deg(-14),
						hyaw = deg(4),
						nyaw = deg(3),
						tpitch = deg(2),
						we = 0.1,
					}),
				},
				{
					seg = "F",
					u = 0.35,
					ease = "out",
					pose = ds({
						bz = -0.13,
						by = -0.05,
						bpitch = deg(-5),
						npitch = deg(36),
						hpitch = deg(-8),
						hroll = deg(14),
						hyaw = deg(10),
						nyaw = deg(6),
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = ds({
						bz = -0.08,
						bpitch = deg(-3),
						npitch = deg(28),
						hpitch = deg(-6),
						hroll = deg(-8),
						hyaw = deg(-6),
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
			},
		},
		claw = DRAGON_CLAW,
		-- the wing buffet (W 0.55): the wings snap open and up, then beat down and forward together on the hit
		buffet = {
			strike = 0.18,
			follow = 0.3,
			recover = 0.45,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 0.6,
					ease = "inout",
					pose = ds({
						bz = 0.04,
						bpitch = deg(6),
						npitch = deg(-8),
						hpitch = deg(4),
						wo = 1.15,
						we = 0.4,
						ws = 0.15,
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ds({
						bz = 0.06,
						by = -0.02,
						bpitch = deg(10),
						npitch = deg(-12),
						hpitch = deg(6),
						tpitch = deg(8),
						wo = 1.9,
						we = 0.95,
						ws = 0.05,
						wt = 0.1,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ds({
						bz = -0.12,
						by = -0.06,
						bpitch = deg(-4),
						npitch = deg(20),
						hpitch = deg(-8),
						wo = 1.9,
						we = -0.55,
						ws = 0.45,
						ww = 0.25,
						wp = 0.2,
					}),
				},
				{
					seg = "F",
					u = 0.5,
					ease = "out",
					pose = ds({ bz = -0.1, bpitch = deg(-3), npitch = deg(16), wo = 1.6, we = -0.3, ws = 0.3 }),
				},
				{ seg = "F", u = 1, ease = "inout", pose = ds({ bz = -0.05, npitch = deg(14), wo = 0.8, we = 0.1 }) },
				{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
			},
		},
		tail = DRAGON_TAIL,
		-- the Elite's claw rake (W 1.8): reared on the hind legs with the wings half open, both fore claws crash
		-- down ahead on the hit and are dragged back through the ground
		rake = dragonRear(0.45, 14, 0, true),
		-- the Elite II's crush (W 2.2): reared high, two flaps of the open wings, the crash on the hit
		stomp = dragonRear(0.4, 16, 2, false),
		-- the pounce (Elite II, W 1.4; the server's jump of 0.4 s, teleported onto the circle at the hit): a crouch
		-- with the wings cocked high, the downstroke launches it on the Dash arc, the wings held out in the flight,
		-- the landing flared on the hit
		pounce = {
			strike = 0.4,
			follow = 0.35,
			recover = 0.9,
			legs = true,
			full = true,
			travel = true,
			tremble = deg(0.6),
			-- (studio review 2026-10-31: the feet skated 8 studs at the take-off and the landing) it pushes off with
			-- the hind feet on their footprints and lifts them straight up before the flight carries it forward; in
			-- the air the legs tuck, then reach down over the spots they land on and come straight down onto them,
			-- the body sinking to absorb it; the fore feet step back under it one after the other
			keys = {
				{
					seg = "A",
					u = 0.35,
					ease = "inout",
					pose = ds({
						by = -0.1,
						bz = 0.1,
						bpitch = deg(-4),
						npitch = deg(10),
						hpitch = deg(-6),
						wo = 0.8,
						we = 0.3,
					}),
				},
				{
					seg = "A",
					u = 0.65,
					ease = "inout",
					pose = ds({
						by = -0.15,
						bz = 0.13,
						bpitch = deg(-6),
						npitch = deg(14),
						hpitch = deg(-10),
						tpitch = deg(10),
						wo = 1.9,
						we = 1.0,
						ws = -0.1,
					}),
				},
				-- the push: the hind legs drive it up and forward over their planted feet, the fore feet leave
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ds({
						by = 0.02,
						bz = 0.02,
						bpitch = deg(8),
						FLy = 0.3,
						FRy = 0.3,
						FLz = -0.08,
						FRz = -0.08,
						npitch = deg(4),
						tpitch = deg(4),
						wo = 2,
						we = 0.6,
						flap = 0.5,
						beat = 0,
					}),
				},
				-- off: the hind feet straight up from their footprints, then the flight (in the air the feet are held
				-- under the body on targets that travel with it: the legs tuck and reach without a jump between poses)
				{
					seg = "S",
					u = 0.14,
					ease = "inout",
					pose = ds({
						by = 0.03,
						bpitch = deg(8),
						FLy = 0.38,
						FRy = 0.38,
						FLz = -0.14,
						FRz = -0.14,
						HLy = 0.14,
						HRy = 0.14,
						npitch = deg(4),
						wo = 2,
						we = 0.3,
						flap = 1,
						beat = 0,
						arc = 0.3,
					}),
				},
				{
					seg = "S",
					u = 0.35,
					ease = "lin",
					pose = ds({
						by = 0.02,
						bpitch = deg(5),
						FLy = 0.62,
						FRy = 0.62,
						FLz = -0.25,
						FRz = -0.25,
						HLy = 0.58,
						HRy = 0.58,
						HLz = 0.12,
						HRz = 0.12,
						npitch = deg(6),
						tpitch = deg(2),
						wo = 2,
						flap = 0.8,
						beat = 0.18,
						travel = 0.25,
						arc = 0.8,
					}),
				},
				{
					seg = "S",
					u = 0.62,
					ease = "lin",
					pose = ds({
						by = 0,
						bpitch = deg(1),
						sflex = deg(-6),
						FLy = 0.62,
						FRy = 0.62,
						FLz = -0.32,
						FRz = -0.32,
						HLy = 0.6,
						HRy = 0.6,
						HLz = 0.05,
						HRz = 0.05,
						npitch = deg(10),
						tpitch = deg(-4),
						wo = 2,
						flap = 0.3,
						beat = 0.3,
						travel = 0.66,
						arc = 0.95,
					}),
				},
				-- over the landing: the feet reach down above the spots they land on
				{
					seg = "S",
					u = 0.74,
					ease = "lin",
					pose = ds({
						by = -0.02,
						bpitch = deg(-4),
						FLz = -0.3,
						FRz = -0.3,
						FLy = 0.2,
						FRy = 0.2,
						HLy = 0.18,
						HRy = 0.18,
						npitch = deg(16),
						hpitch = deg(-6),
						wo = 1.9,
						we = 0.6,
						ws = 0.3,
						beat = 0.3,
						travel = 0.95,
						arc = 0.3,
					}),
				},
				-- down: the jaws at the target, the feet on the ground, the body sinking on into the legs
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = ds({
						by = -0.06,
						bpitch = deg(-6),
						FLz = -0.3,
						FRz = -0.3,
						npitch = deg(22),
						hpitch = deg(-8),
						wo = 1.9,
						we = 0.55,
						ws = 0.35,
						beat = 0.3,
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 0.3,
					ease = "inout",
					pose = ds({
						by = -0.12,
						bz = -0.03,
						bpitch = deg(-6),
						FLz = -0.3,
						FRz = -0.3,
						npitch = deg(22),
						hpitch = deg(-8),
						wo = 1.7,
						we = 0.45,
						ws = 0.3,
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 0.6,
					ease = "inout",
					pose = ds({
						by = -0.08,
						bz = -0.04,
						FLz = -0.3,
						FRz = -0.3,
						npitch = deg(18),
						wo = 1.2,
						we = 0.3,
						travel = 1,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = ds({
						by = -0.05,
						bz = -0.03,
						FLz = -0.3,
						FRz = -0.3,
						npitch = deg(14),
						hyaw = deg(8),
						wo = 0.6,
						travel = 1,
					}),
				},
				-- the fore feet step back under the shoulders: up, over, straight down
				{
					seg = "R",
					u = 0.18,
					ease = "inout",
					pose = ds({ by = -0.04, bz = -0.03, FLz = -0.24, FLy = 0.09, FRz = -0.3, wo = 0.4, travel = 1 }),
				},
				{
					seg = "R",
					u = 0.34,
					ease = "inout",
					pose = ds({ by = -0.04, bz = -0.02, FLz = -0.02, FLy = 0.06, FRz = -0.3, wo = 0.3, travel = 1 }),
				},
				{
					seg = "R",
					u = 0.44,
					ease = "inout",
					pose = ds({ by = -0.04, bz = -0.02, FRz = -0.3, wo = 0.25, travel = 1 }),
				},
				{
					seg = "R",
					u = 0.6,
					ease = "inout",
					pose = ds({ by = -0.04, bz = -0.01, FRz = -0.24, FRy = 0.09, wo = 0.2, travel = 1 }),
				},
				{
					seg = "R",
					u = 0.76,
					ease = "inout",
					pose = ds({ by = -0.04, FRz = -0.02, FRy = 0.06, wo = 0.1, travel = 1 }),
				},
				{ seg = "R", u = 0.86, ease = "inout", pose = ds({ by = -0.04, travel = 1 }) },
				{ seg = "R", u = 1, ease = "inout", pose = from(DRAGON_STANCE, { travel = 1 }) },
			},
		},
		-- the frost breath (W 1.3; cone 17 x 60): it rears a little with the chest swelling and the wings mantled
		-- forward, the neck drawn back; on the hit the head thrusts forward and down and sweeps the cone from the
		-- right to the left while the stream runs (Data/MotionFx `dragon` breath: W - F0.85)
		breath = {
			strike = 0.2,
			follow = 1.1,
			recover = 0.6,
			legs = true,
			tremble = deg(0.8),
			keys = {
				{
					seg = "A",
					u = 0.3,
					ease = "inout",
					pose = ds({
						bz = 0.04,
						bpitch = deg(6),
						npitch = deg(-10),
						hpitch = deg(6),
						wo = 0.9,
						we = 0.25,
						ws = 0.15,
					}),
				},
				{
					seg = "A",
					u = 0.75,
					ease = "inout",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(14),
						sflex = deg(-6),
						npitch = deg(-30),
						hpitch = deg(16),
						tpitch = deg(17),
						tP1 = deg(3.5),
						wo = 1.35,
						we = 0.4,
						ws = 0.3,
						wt = 0.15,
					})),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(15),
						sflex = deg(-7),
						npitch = deg(-34),
						hpitch = deg(18),
						tpitch = deg(18),
						tP1 = deg(4),
						wo = 1.45,
						we = 0.42,
						ws = 0.32,
						wt = 0.15,
					})),
				},
				{
					seg = "S",
					u = 1,
					ease = "in",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(2),
						bz = -0.08,
						npitch = deg(30),
						hpitch = deg(-12),
						nyaw = deg(-10),
						hyaw = deg(-8),
						wo = 1.35,
						we = 0.3,
						ws = 0.4,
						wt = 0.1,
					})),
				},
				{
					seg = "F",
					u = 0.45,
					ease = "inout",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(1),
						bz = -0.08,
						npitch = deg(30),
						hpitch = deg(-11),
						nyaw = deg(2),
						hyaw = deg(1),
						wo = 1.35,
						we = 0.3,
						ws = 0.4,
						wt = 0.1,
					})),
				},
				{
					seg = "F",
					u = 0.85,
					ease = "inout",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(1),
						bz = -0.07,
						npitch = deg(28),
						hpitch = deg(-10),
						nyaw = deg(11),
						hyaw = deg(8),
						wo = 1.3,
						we = 0.28,
						ws = 0.38,
						wt = 0.1,
					})),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = ds({ npitch = deg(20), nyaw = deg(6), wo = 0.9, we = 0.15 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
			},
		},
		-- the thrown blow at a fleeing target (Elite II): a frost spit, the neck drawn back and snapped forward
		spit = {
			strike = 0.14,
			follow = 0.25,
			recover = 0.4,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 0.6,
					ease = "out",
					pose = ds({ bz = 0.05, bpitch = deg(4), npitch = deg(-18), hpitch = deg(10), we = 0.12 }),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ds({
						bz = 0.07,
						bpitch = deg(6),
						sflex = deg(-4),
						npitch = deg(-26),
						hpitch = deg(14),
						we = 0.15,
					}),
				},
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = ds({ bz = -0.06, bpitch = deg(-3), npitch = deg(28), hpitch = deg(-16), we = 0.05 }),
				},
				{ seg = "F", u = 1, ease = "out", pose = ds({ bz = -0.04, npitch = deg(20), hpitch = deg(-8) }) },
				{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
			},
		},
		-- the roar at a new target: rearing a little with the wings spread wide and high, the head thrust up and
		-- forward on the hit, a trembling hold
		roar = {
			strike = 0.15,
			follow = 1.0,
			recover = 0.6,
			legs = true,
			tremble = deg(1.2),
			keys = {
				{
					seg = "A",
					u = 0.65,
					ease = "inout",
					pose = ds({ bpitch = deg(4), npitch = deg(-10), hpitch = deg(8), wo = 0.85, we = 0.25 }),
				},
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(14),
						by = 0.02,
						npitch = deg(-22),
						hpitch = deg(14),
						tpitch = deg(17),
						tP1 = deg(3.5),
						wo = 1.5,
						we = 0.65,
						ws = 0.15,
						ww = 0.1,
						wp = 0.15,
					})),
				},
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(8),
						bz = -0.04,
						npitch = deg(18),
						hpitch = deg(-20),
						tpitch = deg(10),
						wo = 1.6,
						we = 0.7,
						ws = 0.2,
						ww = 0.15,
						wp = 0.25,
					})),
				},
				{
					seg = "F",
					u = 0.35,
					ease = "inout",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(8),
						bz = -0.04,
						npitch = deg(20),
						hpitch = deg(-18),
						hroll = deg(7),
						nyaw = deg(-5),
						wo = 1.6,
						we = 0.75,
						ws = 0.2,
						ww = 0.15,
						wp = 0.25,
					})),
				},
				{
					seg = "F",
					u = 0.7,
					ease = "inout",
					pose = ds(merge(DRAGON_HIPS, {
						bpitch = deg(7),
						bz = -0.03,
						npitch = deg(18),
						hpitch = deg(-18),
						hroll = deg(-7),
						nyaw = deg(6),
						wo = 1.55,
						we = 0.7,
						ws = 0.2,
						ww = 0.15,
						wp = 0.25,
					})),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = ds({ npitch = deg(14), hpitch = deg(-6), wo = 1.1, we = 0.3 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
			},
		},
		-- appearing: low with the wings wrapped tight, it rises, flicks the wings open with one beat and folds them
		spawn = {
			strike = 0.25,
			follow = 0.8,
			recover = 0.6,
			legs = true,
			full = true,
			keys = {
				{
					seg = "A",
					u = 0,
					pose = merge(DRAGON_REST, {
						by = -0.3,
						bpitch = deg(-6),
						npitch = deg(40),
						hpitch = deg(10),
						tpitch = deg(-20),
						we = -0.08,
					}),
				},
				{
					seg = "A",
					u = 1,
					ease = "out",
					pose = ds({ by = -0.14, npitch = deg(24), hpitch = deg(4), we = -0.04 }),
				},
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = ds({
						by = 0,
						bpitch = deg(6),
						npitch = deg(-10),
						hpitch = deg(6),
						wo = 1.8,
						we = 0.5,
						flap = 0.6,
					}),
				},
				{
					seg = "F",
					u = 0.6,
					ease = "lin",
					pose = ds({
						bpitch = deg(3),
						npitch = deg(-4),
						hroll = deg(8),
						wo = 1.8,
						we = 0.3,
						flap = 0.6,
						beat = 1,
					}),
				},
				{ seg = "F", u = 1, ease = "inout", pose = ds({ hroll = deg(-4), wo = 0.5, beat = 1 }) },
				{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
			},
		},
		-- idle: the wings opened half way, ruffled once and folded again
		resettle = {
			strike = 0.35,
			follow = 0.7,
			recover = 0.6,
			legs = true,
			keys = {
				{
					seg = "A",
					u = 1,
					ease = "inout",
					pose = merge(DRAGON_REST, { npitch = deg(-2), wo = 0.3, we = 0.1 }),
				},
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = merge(DRAGON_REST, { npitch = deg(-4), wo = 0.9, we = 0.35 }),
				},
				{
					seg = "F",
					u = 0.25,
					ease = "out",
					pose = merge(DRAGON_REST, { npitch = deg(-6), wo = 1.25, we = 0.45, flap = 0.25 }),
				},
				{
					seg = "F",
					u = 0.6,
					ease = "lin",
					pose = merge(DRAGON_REST, { npitch = deg(-4), wo = 1.1, we = 0.35, flap = 0.25, beat = 1 }),
				},
				{ seg = "F", u = 1, ease = "inout", pose = merge(DRAGON_REST, { wo = 0.3, we = 0.05, beat = 1 }) },
				{ seg = "R", u = 1, ease = "inout", pose = DRAGON_REST },
			},
		},
		-- idle: the neck stretched long and high, the back arched, the wings lifted, the tail raised
		stretch = {
			strike = 0.6,
			follow = 0.8,
			recover = 0.7,
			legs = true,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "inout",
					pose = merge(DRAGON_REST, {
						by = 0.02,
						sflex = deg(-6),
						npitch = deg(-24),
						hpitch = deg(-12),
						tpitch = deg(12),
						wo = 0.5,
						we = 0.4,
					}),
				},
				{
					seg = "F",
					u = 1,
					ease = "inout",
					pose = merge(DRAGON_REST, {
						by = 0.02,
						sflex = deg(-5),
						npitch = deg(-20),
						hpitch = deg(-8),
						hroll = deg(6),
						tpitch = deg(10),
						wo = 0.4,
						we = 0.3,
					}),
				},
				{ seg = "R", u = 1, ease = "inout", pose = DRAGON_REST },
			},
		},
		deathL = {
			strike = 0.12,
			follow = 1.0,
			recover = 0.4,
			legs = true,
			full = true,
			hold = true,
			keys = {
				{
					seg = "S",
					u = 1,
					ease = "out",
					pose = ds({ bz = 0.08, bpitch = deg(8), npitch = deg(-16), hpitch = deg(-8), wo = 0.6, we = 0.25 }),
				},
				{
					seg = "F",
					u = 0.4,
					ease = "inout",
					pose = merge(DRAGON_REST, {
						by = -0.32,
						bpitch = deg(-6),
						FLf = 0.9,
						FRf = 0.9,
						HLf = 0.9,
						HRf = 0.9,
						npitch = deg(30),
						hpitch = deg(4),
						tpitch = deg(16),
						tP1 = deg(6),
						wo = 0.55,
						we = 0.15,
					}),
				},
				-- the feet let go as it tips over
				{
					seg = "F",
					u = 0.62,
					ease = "inout",
					pose = {
						by = -0.16,
						broll = deg(22),
						bpx = -0.42,
						bpitch = deg(-5),
						FLk = 1,
						HLk = 1,
						FLl = 1,
						HLl = 1,
						FLf = 1.1,
						FRf = 0.9,
						HLf = 1.1,
						HRf = 0.9,
						FLo = deg(-25),
						HLo = deg(-25),
						-- (the upper feet lift straight off their prints as it rolls)
						FRk = 1,
						HRk = 1,
						FRl = 1,
						HRl = 1,
						FRy = 0.08,
						FRz = 0.04,
						HRy = 0.2,
						HRz = -0.15,
						tpitch = deg(8),
						npitch = deg(18),
						hpitch = deg(2),
						wLo = 1.0,
						wLe = 0.7,
						wRo = 1.1,
						wRe = 0.7,
					},
				},
				{ seg = "F", u = 1, ease = "in", pose = DRAGON_SIDE },
				{
					seg = "R",
					u = 0.4,
					ease = "out",
					pose = from(DRAGON_SIDE, { broll = deg(82), HRu = deg(26), tY6 = deg(14), wRe = 1.65 }),
				},
				{ seg = "R", u = 1, ease = "inout", pose = from(DRAGON_SIDE, { broll = deg(85), nyaw = deg(26) }) },
			},
		},
	},
}
DRAGON.actions.clawL = mirrored(DRAGON_CLAW)
DRAGON.actions.deathR = mirrored(DRAGON.actions.deathL)

-- (studio review 2026-10-31: the lab's death was deathL's twin) death by a blow from the front or behind: the jolt
-- rears it back off its fore feet, it staggers a step forward onto them, the knees buckle under the weight and it
-- sinks onto its belly with the fore legs out ahead, the neck slumping aside, the wings sliding down over its flanks
-- and the tail laid out behind; every foot stays on its print once it is down
local DRAGON_BELLY = merge(DRAGON_REST, {
	by = -0.45,
	bpitch = deg(-10),
	FLz = -0.45,
	FRz = -0.45,
	FLf = deg(90),
	FRf = deg(90),
	HLf = deg(40),
	HRf = deg(40),
	npitch = deg(95),
	nyaw = deg(30),
	hroll = deg(6),
	tpitch = deg(30),
	tP1 = deg(3),
	tY4 = deg(10),
	tY5 = deg(12),
	tY6 = deg(12),
	wo = 0.5,
	we = -0.6,
})
DRAGON.actions.death = {
	strike = 0.12,
	follow = 1.0,
	recover = 0.6,
	legs = true,
	full = true,
	hold = true,
	keys = {
		{
			seg = "S",
			u = 1,
			ease = "out",
			pose = ds({
				bz = 0.06,
				by = 0.02,
				bpitch = deg(8),
				FLy = 0.08,
				FRy = 0.08,
				FLz = -0.06,
				FRz = -0.06,
				npitch = deg(-16),
				hpitch = deg(-8),
				wo = 0.6,
				we = 0.25,
			}),
		},
		-- the stagger: the fore feet over the spots ahead, then straight down onto them
		{
			seg = "F",
			u = 0.22,
			ease = "inout",
			pose = merge(DRAGON_REST, {
				by = -0.1,
				bpitch = deg(0),
				FLy = 0.07,
				FRy = 0.07,
				FLz = -0.45,
				FRz = -0.45,
				npitch = deg(4),
				hpitch = deg(2),
				tpitch = deg(8),
				wo = 0.55,
				we = 0.15,
			}),
		},
		{
			seg = "F",
			u = 0.4,
			ease = "inout",
			pose = merge(DRAGON_REST, {
				by = -0.24,
				bpitch = deg(-4),
				FLz = -0.45,
				FRz = -0.45,
				npitch = deg(22),
				hpitch = deg(6),
				nyaw = deg(6),
				tpitch = deg(12),
				wo = 0.5,
				we = 0,
			}),
		},
		-- the knees give
		{
			seg = "F",
			u = 0.72,
			ease = "inout",
			pose = from(DRAGON_BELLY, {
				by = -0.36,
				bpitch = deg(-7),
				npitch = deg(55),
				nyaw = deg(16),
				hroll = deg(2),
				tpitch = deg(20),
				tY4 = deg(4),
				tY5 = deg(5),
				tY6 = deg(5),
				we = -0.3,
			}),
		},
		{ seg = "F", u = 1, ease = "out", pose = DRAGON_BELLY },
		-- the last breath out: the body settles, the head rolls a little further, the wings slip down
		{
			seg = "R",
			u = 1,
			ease = "inout",
			pose = from(DRAGON_BELLY, { by = -0.46, npitch = deg(100), nyaw = deg(34), hroll = deg(10), we = -0.7 }),
		},
	},
}

-- (studio review 2026-10-31: the lab's alert showed the idle) the first sight of a fighter (docs/ANIM-WZORCE.md
-- 5.3): the neck snaps up and toward it, the wings half open and held taut, a short roar on the hit, then back down
-- into the fighting stance
DRAGON.actions.alert = {
	strike = 0.12,
	follow = 0.35,
	recover = 0.45,
	legs = true,
	keys = {
		{
			seg = "A",
			u = 0.6,
			ease = "inout",
			pose = ds({ bpitch = deg(2), npitch = deg(0), hpitch = deg(-2), tpitch = deg(10), wo = 0.5, we = 0.15 }),
		},
		{
			seg = "A",
			u = 1,
			ease = "inout",
			pose = ds(merge(DRAGON_HIPS, {
				bpitch = deg(5),
				npitch = deg(-16),
				hpitch = deg(-4),
				tpitch = deg(15),
				wo = 0.8,
				we = 0.3,
				ws = 0.05,
			})),
		},
		{
			seg = "S",
			u = 1,
			ease = "out",
			pose = ds(merge(DRAGON_HIPS, {
				bpitch = deg(6),
				bz = -0.02,
				npitch = deg(-12),
				hpitch = deg(-14),
				tpitch = deg(16),
				wo = 0.85,
				we = 0.35,
				ws = 0.08,
			})),
		},
		{
			seg = "F",
			u = 0.5,
			ease = "inout",
			pose = ds(merge(DRAGON_HIPS, {
				bpitch = deg(5),
				bz = -0.02,
				npitch = deg(-10),
				hpitch = deg(-12),
				hroll = deg(5),
				tpitch = deg(14),
				wo = 0.85,
				we = 0.35,
				ws = 0.08,
			})),
		},
		{
			seg = "F",
			u = 1,
			ease = "inout",
			pose = ds({ npitch = deg(8), hpitch = deg(-8), tpitch = deg(8), wo = 0.45, we = 0.12 }),
		},
		{ seg = "R", u = 1, ease = "inout", pose = DRAGON_STANCE },
	},
}

local STYLES: { [string]: Style } = {
	canine = CANINE,
	bear = BEAR,
	boar = BOAR,
	mammoth = MAMMOTH,
	dragon = DRAGON,
}

function QuadStyles.get(id: string): Style?
	return STYLES[id]
end

-- The AnimLab states every style shows (LookAnim's slots, the gaits, the reactions, the short fight).
local GENERIC_STATES = {
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
	"hit",
	"hitBack",
	"hitLeft",
	"hitRight",
	"death",
	"spawn",
	"fight",
}

-- The AnimLab states of style `id` (`/animlab mob <id> <state>`): the generic ones, then every action of its own by
-- name (a bear's swipe, a boar's charge, a mammoth's trumpet).
function QuadStyles.labStates(id: string): { string }
	local out = table.clone(GENERIC_STATES)
	local style = STYLES[id]
	if style then
		-- a dragon's stun and freeze (Effects in the game)
		local extra: { string } = style.labExtra or {}
		for _, name in extra do
			table.insert(out, name)
		end
		local own: { string } = {}
		for name in style.actions do
			if not table.find(out, name) then
				table.insert(own, name)
			end
		end
		table.sort(own)
		for _, name in own do
			table.insert(out, name)
		end
	end
	return out
end

QuadStyles.LAB_STATES = {
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
	"bite",
	"leap",
	"maul",
	"rear",
	"pounce",
	"toss",
	"snarl",
	"sniff",
	"shake",
	"hit",
	"hitBack",
	"hitLeft",
	"hitRight",
	"death",
	"deathL",
	"deathR",
	"spawn",
	"fight",
}

return QuadStyles
