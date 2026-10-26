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
	aggro: string?,
	spawn: string?,
	fidgets: { string },
	fidgetEvery: { number },
	rate: number,
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
						by = -0.06,
						bpitch = deg(-7),
						HLu = deg(-14),
						HRu = deg(-14),
						HLf = deg(14),
						HRf = deg(14),
						FLu = deg(6),
						FRu = deg(6),
						FLf = deg(14),
						FRf = deg(14),
						npitch = deg(24),
						hpitch = deg(10),
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

local STYLES: { [string]: Style } = {
	canine = CANINE,
}

function QuadStyles.get(id: string): Style?
	return STYLES[id]
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
