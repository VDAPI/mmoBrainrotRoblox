--!strict
-- How generated monsters move in a fight (S117, DESIGN-16 §8, docs/ANIMACJE.md "Potwory i bossowie w walce"): attack
-- styles by body plan, the weapon of humanoids, the Elite II special by ability, deaths by plan. Looks only (the server's
-- windup, hit time and areas never change); Logic/Gait adds a style to the walk / idle pose. Data only (Lune).
--
-- Pose offsets per Gait role, applied on top of the walk / idle pose (Logic/Gait):
--   windup = full when the gather curve reaches 1 (the end of the windup), strike = full at the blow,
--   each { rx, ry, rz, x, y, z } in radians / studs at scale 1; `arms` = "right" | "both" | "alt" (which arm leads).
-- Axes (the joint frames of Logic/Anatomy): rx > 0 tilts a forward piece up (body: the front rises, head: rears up,
-- jaw: closes; a hanging limb swings forward), ry > 0 turns the front to the left, rz > 0 moves a right-hand limb
-- outwards / a right wing up; z < 0 is forward. Offsets are written for the right side: Gait mirrors ry, rz and x for
-- joints with side -1. A role a style lists replaces the generic attack motion of that role (Gait.attack terms); roles
-- it does not list keep it. "leg" applies to front legs and to the legs of two-legged plans, `hindWindup` /
-- `hindStrike` to hind legs (joint attribute Front < 0, Util/LookBuild); `left` replaces "arm" on the left arm.
-- `arms` shares "arm" and front "leg": "right" = the right one full, the left 0.3; "both" = both full; "alt" = the right
-- leads the windup, the left the strike.

export type RolePose = { number } -- { rx, ry, rz, x, y, z }
export type Arms = "right" | "both" | "alt"
export type Style = {
	windup: { [string]: RolePose }, -- role -> offset at full windup
	strike: { [string]: RolePose }, -- role -> offset at the blow
	arms: Arms?,
	hindWindup: RolePose?, -- hind legs (and hind spider legs) at full windup
	hindStrike: RolePose?,
	left: { windup: RolePose?, strike: RolePose?, follow: RolePose? }?, -- the left arm instead of the mirrored "arm"
	-- S159g: the pose after the blow (a throw's arm across the body, a slam's bent back): the strike cross-fades into it
	-- over the recovery, it holds Gait.FOLLOW_HOLD s and settles (Gait.followOf); a held channel keeps the strike first
	follow: { [string]: RolePose }?,
	tremble: number?, -- radians of shaking at the end of a long windup (charging up), default 0
	spin: number?, -- body turns (full circles) during the strike (whirlwind)
	hop: number?, -- studs of the visual jump at the blow (pounce, slam)
	dash: number?, -- studs of the visual lunge forward at the blow (charge, bite)
}
-- How hard a hit pushes a plan (Gait.hitLean): body lean (rad), push (studs), head turn towards the attacker (rad);
-- nil fields take Config.MonsterLook.hitLean / hitPush and 0.2.
export type HitReaction = { lean: number?, push: number?, head: number? }
export type PlanMotion = {
	basic: string, -- style of the regular attack
	special: { [string]: string }, -- Elite II ability id (Data/MonsterAbilities) -> style; "default" for the rest
	death: string, -- style of the death (DEATH)
	roar: string?, -- style of the phase roar (bosses), default "roar"
	hit: HitReaction?,
}
-- A death (Gait, motion.dead 0..1 over Config.MonsterLook.deathSeconds): `pose` is reached at dead = 1; with `early`
-- the body first reaches `early` at dead = `split`, then goes on to `pose` (knees, then the fall). `flip` is the axis
-- whose sign the model's seed picks (rolls to the left or the right, falls forwards or backwards). `hoverDrop`: the
-- body also drops by the plan's hover height (fliers fall to the ground).
export type DeathStyle = {
	pose: { [string]: RolePose },
	early: { [string]: RolePose }?,
	split: number?,
	flip: ("rz" | "rx")?,
	hoverDrop: boolean?,
}

local function P(rx: number, ry: number, rz: number, x: number, y: number, z: number): RolePose
	return { rx, ry, rz, x, y, z }
end

local function style(def: Style): Style
	return def
end

local function death(def: DeathStyle): DeathStyle
	return def
end

local STYLES: { [string]: Style } = {
	-- Quadrupeds ----------------------------------------------------------------------------------------------------
	-- canine, dragon, hare: the head lunges, the jaw snaps
	bite = style({
		windup = { body = P(0.12, 0, 0, 0, 0, 0.25), head = P(0.35, 0, 0, 0, 0, 0), jaw = P(-0.5, 0, 0, 0, 0, 0) },
		strike = { body = P(-0.15, 0, 0, 0, 0, 0), head = P(-0.5, 0, 0, 0, 0, 0), jaw = P(-0.08, 0, 0, 0, 0, 0) },
		dash = 0.4,
	}),
	-- canine leap: a crouch back and down, shaking, then the jump onto the area
	pounce = style({
		windup = {
			body = P(0.15, 0, 0, 0, -0.35, 0.4),
			head = P(-0.2, 0, 0, 0, 0, 0),
			leg = P(0.5, 0, 0, 0, 0, 0),
			jaw = P(-0.3, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(-0.2, 0, 0, 0, 0, 0),
			head = P(-0.4, 0, 0, 0, 0, 0),
			leg = P(0.9, 0, 0, 0, 0, 0),
			jaw = P(-0.5, 0, 0, 0, 0, 0),
		},
		hindWindup = P(-0.45, 0, 0, 0, 0, 0),
		hindStrike = P(-0.7, 0, 0, 0, 0, 0),
		arms = "both",
		tremble = 0.04,
		hop = 1.2,
		dash = 1.5,
	}),
	-- boar: the head goes low, then tosses up
	gore = style({
		windup = { body = P(-0.08, 0, 0, 0, -0.05, 0.2), head = P(-0.35, 0, 0, 0, 0, 0) },
		strike = { body = P(0.1, 0, 0, 0, 0, 0), head = P(0.5, 0, 0, 0, 0, 0) },
		dash = 0.5,
	}),
	-- boar and the renegade dwarf: head low, a front foot scrapes (the shake), then the rush
	charge = style({
		windup = {
			body = P(-0.12, 0, 0, 0, -0.15, 0.3),
			head = P(-0.45, 0, 0, 0, 0, 0),
			leg = P(-0.3, 0, 0, 0, 0, 0),
			arm = P(1.4, 0, -0.15, 0, 0, 0),
		},
		strike = {
			body = P(-0.1, 0, 0, 0, 0, 0),
			head = P(-0.3, 0, 0, 0, 0, 0),
			leg = P(0.3, 0, 0, 0, 0, 0),
			arm = P(1.5, 0, -0.1, 0, 0, 0),
		},
		arms = "alt",
		tremble = 0.05,
		dash = 3.0,
	}),
	-- bear: the right front paw rises and comes down
	swipe = style({
		windup = {
			body = P(0.15, 0.1, 0, 0, 0, 0),
			leg = P(1.3, 0, 0.2, 0, 0, 0),
			head = P(0.2, 0, 0, 0, 0, 0),
			jaw = P(-0.4, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(-0.1, -0.1, 0, 0, 0, -0.2),
			leg = P(-0.2, 0, -0.1, 0, 0, 0),
			head = P(-0.3, 0, 0, 0, 0, 0),
			jaw = P(-0.15, 0, 0, 0, 0, 0),
		},
		arms = "right",
	}),
	-- bear slam: rears up on the hind legs with both paws high, then slams them down
	rear = style({
		windup = {
			body = P(0.9, 0, 0, 0, 0.4, 0.2),
			leg = P(1.4, 0, 0.15, 0, 0, 0),
			head = P(-0.3, 0, 0, 0, 0, 0),
			jaw = P(-0.5, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(-0.15, 0, 0, 0, -0.1, -0.3),
			leg = P(-0.3, 0, 0, 0, 0, 0),
			head = P(-0.2, 0, 0, 0, 0, 0),
			jaw = P(-0.2, 0, 0, 0, 0, 0),
		},
		hindWindup = P(-0.5, 0, 0, 0, 0, 0),
		hindStrike = P(0.1, 0, 0, 0, 0, 0),
		arms = "both",
		tremble = 0.03,
	}),
	-- mammoth: the tusks swing from side to side
	tusk = style({
		windup = { head = P(0.15, 0.5, 0, 0, 0, 0), segment = P(0.3, 0, 0, 0, 0, 0), body = P(0, 0.15, 0, 0, 0, 0) },
		strike = { head = P(-0.2, -0.6, 0, 0, 0, 0), segment = P(-0.3, 0, 0, 0, 0, 0), body = P(0, -0.2, 0, 0, 0, 0) },
		dash = 0.3,
	}),
	-- mammoth slam: the front rises, the trunk up, then the stomp
	stomp = style({
		windup = {
			body = P(0.55, 0, 0, 0, 0.3, 0.1),
			leg = P(0.9, 0, 0, 0, 0, 0),
			head = P(0.4, 0, 0, 0, 0, 0),
			segment = P(0.6, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(-0.1, 0, 0, 0, -0.1, -0.2),
			leg = P(-0.2, 0, 0, 0, 0, 0),
			head = P(-0.2, 0, 0, 0, 0, 0),
			segment = P(-0.2, 0, 0, 0, 0, 0),
		},
		hindWindup = P(-0.3, 0, 0, 0, 0, 0),
		arms = "both",
		tremble = 0.03,
	}),
	-- toad (and the missing slime plan, DECYZJE S117): a squeeze down, then the throw of the head
	squash = style({
		windup = { body = P(0.1, 0, 0, 0, -0.3, 0.1), head = P(0.2, 0, 0, 0, 0, 0), jaw = P(-0.2, 0, 0, 0, 0, 0) },
		strike = { body = P(-0.1, 0, 0, 0, 0.15, -0.3), head = P(-0.3, 0, 0, 0, 0, 0), jaw = P(-0.6, 0, 0, 0, 0, 0) },
		dash = 0.3,
	}),
	-- toad, lizard, serpent poison: puffs up with the jaw open, spits on the blow
	spit = style({
		windup = {
			body = P(0.25, 0, 0, 0, 0.3, 0.1),
			head = P(0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.6, 0, 0, 0, 0, 0),
			segment = P(0.25, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(-0.15, 0, 0, 0, 0, -0.2),
			head = P(-0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.7, 0, 0, 0, 0, 0),
			segment = P(-0.2, 0, 0, 0, 0, 0),
		},
		tremble = 0.03,
	}),
	-- lizard basic: head and jaw snap, the tail swings against it
	snap = style({
		windup = {
			head = P(0.3, 0.2, 0, 0, 0, 0),
			jaw = P(-0.5, 0, 0, 0, 0, 0),
			body = P(0.05, 0.1, 0, 0, 0, 0.15),
			segment = P(0, -0.25, 0, 0, 0, 0),
		},
		strike = {
			head = P(-0.4, -0.2, 0, 0, 0, 0),
			jaw = P(0, 0, 0, 0, 0, 0),
			body = P(-0.08, -0.1, 0, 0, 0, 0),
			segment = P(0, 0.25, 0, 0, 0, 0),
		},
		dash = 0.3,
	}),
	-- fire / frost breath: the neck goes back and up, then forward with the maw held open to the end of the blow
	breath = style({
		windup = {
			head = P(0.6, 0, 0, 0, 0, 0),
			jaw = P(-0.15, 0, 0, 0, 0, 0),
			body = P(0.2, 0, 0, 0, 0.1, 0.2),
			segment = P(0.2, 0, 0, 0, 0, 0),
			flap = P(0, 0, 0.4, 0, 0, 0),
			arm = P(0.5, 0, 0.4, 0, 0, 0),
		},
		strike = {
			head = P(-0.35, 0, 0, 0, 0, 0),
			jaw = P(-0.85, 0, 0, 0, 0, 0),
			body = P(-0.1, 0, 0, 0, 0, -0.2),
			segment = P(-0.15, 0, 0, 0, 0, 0),
			flap = P(0, 0, -0.2, 0, 0, 0),
			arm = P(0.2, 0, 0.6, 0, 0, 0),
		},
		arms = "both",
		tremble = 0.03,
	}),
	-- serpent basic: the chain coils back, then whips forward
	strike = style({
		windup = {
			segment = P(0.35, 0, 0, 0, 0, 0),
			head = P(0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.5, 0, 0, 0, 0, 0),
			body = P(0.1, 0, 0, 0, 0.1, 0.3),
		},
		strike = {
			segment = P(-0.35, 0, 0, 0, 0, 0),
			head = P(-0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.1, 0, 0, 0, 0, 0),
			body = P(-0.1, 0, 0, 0, 0, 0),
		},
		dash = 0.6,
	}),
	-- Creatures -----------------------------------------------------------------------------------------------------
	-- spider basic: the front legs rise, the body lunges, the fangs bite
	fang = style({
		windup = {
			spiderLeg = P(0, 0.2, 0.7, 0, 0, 0),
			body = P(0.2, 0, 0, 0, 0.1, 0.2),
			jaw = P(-0.4, 0, 0, 0, 0, 0),
		},
		strike = {
			spiderLeg = P(0, -0.2, -0.1, 0, 0, 0),
			body = P(-0.15, 0, 0, 0, 0, 0),
			jaw = P(0.25, 0, 0, 0, 0, 0),
		},
		dash = 0.5,
	}),
	-- spider poison: the abdomen up, the front legs spread, then the spit
	spiderSpit = style({
		windup = {
			body = P(-0.35, 0, 0, 0, 0.15, 0.1),
			spiderLeg = P(0, 0.4, 0.5, 0, 0, 0),
			jaw = P(-0.3, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(0.15, 0, 0, 0, 0, -0.2),
			spiderLeg = P(0, 0.1, 0.2, 0, 0, 0),
			jaw = P(-0.5, 0, 0, 0, 0, 0),
		},
		hindWindup = P(0, 0, -0.15, 0, 0, 0),
		tremble = 0.03,
	}),
	-- scorpion basic: the pincers open high and snap
	pincer = style({
		windup = {
			claw = P(-0.7, 0, 0, 0, 0, 0),
			arm = P(0.6, 0, 0.2, 0, 0, 0),
			body = P(0.1, 0, 0, 0, 0, 0.15),
			sting = P(0.2, 0, 0, 0, 0, 0),
		},
		strike = {
			claw = P(0.3, 0, 0, 0, 0, 0),
			arm = P(-0.2, 0, -0.1, 0, 0, 0),
			body = P(-0.1, 0, 0, 0, 0, 0),
			sting = P(-0.1, 0, 0, 0, 0, 0),
		},
		arms = "both",
		dash = 0.4,
	}),
	-- scorpion poison: the tail curls back and stabs
	sting = style({
		windup = {
			sting = P(0.5, 0, 0, 0, 0, 0),
			body = P(-0.1, 0, 0, 0, 0.05, 0.1),
			claw = P(-0.4, 0, 0, 0, 0, 0),
			arm = P(0.3, 0, 0.4, 0, 0, 0),
		},
		strike = {
			sting = P(-1.0, 0, 0, 0, 0, 0),
			body = P(-0.12, 0, 0, 0, 0, 0),
			claw = P(-0.2, 0, 0, 0, 0, 0),
			arm = P(0.1, 0, 0.3, 0, 0, 0),
		},
		arms = "both",
		tremble = 0.03,
		dash = 0.3,
	}),
	-- birds and bats: a dive with the wings swept back, the beak / teeth first
	dive = style({
		windup = {
			body = P(0.25, 0, 0, 0, 0.4, 0.3),
			flap = P(0, 0, 0.6, 0, 0, 0),
			head = P(0.3, 0, 0, 0, 0, 0),
			leg = P(0.4, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(-0.5, 0, 0, 0, -0.6, -0.3),
			flap = P(0, 0.4, -0.5, 0, 0, 0),
			head = P(-0.4, 0, 0, 0, 0, 0),
			leg = P(0.8, 0, 0, 0, 0, 0),
		},
		arms = "both",
		dash = 0.5,
	}),
	-- wail: the wings wide, the head forward, the beak open, the body up
	screech = style({
		windup = {
			flap = P(0, 0, 0.75, 0, 0, 0),
			body = P(0.3, 0, 0, 0, 0.3, 0.1),
			head = P(0.3, 0, 0, 0, 0, 0),
			jaw = P(-0.3, 0, 0, 0, 0, 0),
		},
		strike = {
			flap = P(0, 0, 0.3, 0, 0, 0),
			body = P(-0.1, 0, 0, 0, 0.15, -0.2),
			head = P(-0.3, 0, 0, 0, 0, 0),
			jaw = P(-0.6, 0, 0, 0, 0, 0),
		},
		tremble = 0.05,
	}),
	-- Humanoids by weapon -------------------------------------------------------------------------------------------
	-- one-handed cut (sabres, swords, the default of humanoids)
	slash = style({
		windup = { arm = P(2.2, 0, 0.2, 0, 0, 0), body = P(0.05, -0.2, 0, 0, 0, 0), head = P(0.1, 0, 0, 0, 0, 0) },
		strike = { arm = P(-0.3, 0, -0.1, 0, 0, 0), body = P(-0.12, 0.15, 0, 0, 0, 0), head = P(-0.15, 0, 0, 0, 0, 0) },
		arms = "right",
		dash = 0.4,
	}),
	-- dagger and spear: drawn back, then a straight thrust
	thrust = style({
		windup = { arm = P(0.9, 0, 0.1, 0, 0, 0), body = P(0.05, -0.25, 0, 0, 0, 0.2) },
		strike = { arm = P(1.5, 0, 0, 0, 0, 0), body = P(-0.1, 0.2, 0, 0, 0, 0) },
		arms = "right",
		dash = 0.6,
	}),
	-- one-handed blow from above (clubs, cleavers, smith hammers)
	overhead = style({
		windup = { arm = P(2.5, 0, 0.1, 0, 0, 0), body = P(0.15, -0.1, 0, 0, 0.05, 0), head = P(0.15, 0, 0, 0, 0, 0) },
		strike = { arm = P(0.2, 0, 0, 0, 0, 0), body = P(-0.25, 0.05, 0, 0, -0.15, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "right",
		dash = 0.3,
	}),
	-- two-handed blow from above (hammers, axes, pickaxes, great clubs): slower in, harder down
	overhead2 = style({
		windup = { arm = P(2.5, 0, 0.05, 0, 0, 0), body = P(0.2, 0, 0, 0, 0.05, 0.1), head = P(0.15, 0, 0, 0, 0, 0) },
		strike = { arm = P(0.4, 0, -0.1, 0, 0, 0), body = P(-0.3, 0, 0, 0, -0.2, 0), head = P(-0.25, 0, 0, 0, 0, 0) },
		arms = "both",
		dash = 0.3,
	}),
	-- wide cut (scythe, the Elite II cleave): the weapon far back, the body turns through the cut
	wide = style({
		windup = { arm = P(1.4, 0, 0.8, 0, 0, 0), body = P(0.05, -0.6, 0, 0, 0, 0.1) },
		strike = { arm = P(0.6, 0, -0.3, 0, 0, 0), body = P(-0.1, 0.7, 0, 0, 0, 0) },
		arms = "right",
		dash = 0.3,
	}),
	-- staff, skull staff, broom: the staff up, then a push of the hand
	cast = style({
		windup = { arm = P(1.6, 0, 0.15, 0, 0, 0), body = P(0.1, 0, 0, 0, 0, 0), head = P(0.2, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.2, 0, -0.05, 0, 0, 0), body = P(-0.1, 0, 0, 0, 0, -0.1), head = P(-0.1, 0, 0, 0, 0, 0) },
		arms = "right",
	}),
	-- Elite II slam of humanoids and beasts: the weapon / both fists over the head, a jump, down on the ground
	jumpSlam = style({
		windup = { arm = P(2.4, 0, 0.15, 0, 0, 0), body = P(0.15, 0, 0, 0, -0.35, 0.1), head = P(0.2, 0, 0, 0, 0, 0) },
		strike = { arm = P(-0.2, 0, 0.1, 0, 0, 0), body = P(-0.3, 0, 0, 0, -0.2, 0), head = P(-0.3, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.03,
		hop = 0.8,
	}),
	-- bone nova, void pool, ember nova of casters: both hands up, then out to the sides
	castBurst = style({
		windup = { arm = P(2.4, 0, 0.5, 0, 0, 0), head = P(0.4, 0, 0, 0, 0, 0), body = P(0.15, 0, 0, 0, 0.1, 0) },
		strike = { arm = P(0.8, 0, 1.2, 0, 0, 0), head = P(-0.1, 0, 0, 0, 0, 0), body = P(-0.05, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.04,
	}),
	-- beasts: the claws in turns
	claw = style({
		windup = { arm = P(1.6, 0, 0.3, 0, 0, 0), body = P(0.08, -0.15, 0, 0, 0, 0), head = P(0.2, 0, 0, 0, 0, 0) },
		strike = { arm = P(-0.3, 0, -0.2, 0, 0, 0), body = P(-0.12, 0.15, 0, 0, 0, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "alt",
		dash = 0.3,
	}),
	-- werewolf / ghoul leap: a low crouch with the claws out, then the jump with both arms reaching
	beastPounce = style({
		windup = { arm = P(0.6, 0, 0.4, 0, 0, 0), body = P(-0.25, 0, 0, 0, -0.4, 0.3), head = P(0.3, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.8, 0, 0.1, 0, 0, 0), body = P(-0.3, 0, 0, 0, 0, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.04,
		hop = 1.2,
		dash = 1.5,
	}),
	-- Golems, treants, spirits ---------------------------------------------------------------------------------------
	-- golem basic: a heavy punch from behind
	punch = style({
		windup = { arm = P(-0.5, 0, 0.3, 0, 0, 0), body = P(0.05, -0.35, 0, 0, 0, 0.1) },
		strike = { arm = P(1.5, 0, 0, 0, 0, 0), body = P(-0.15, 0.3, 0, 0, 0, 0) },
		arms = "right",
		dash = 0.5,
	}),
	-- golem slam: both arms over the head, then down
	slam = style({
		windup = { arm = P(2.5, 0, 0.1, 0, 0, 0), body = P(0.2, 0, 0, 0, 0.1, 0.1), head = P(0.15, 0, 0, 0, 0, 0) },
		strike = { arm = P(0.1, 0, 0.1, 0, 0, 0), body = P(-0.35, 0, 0, 0, -0.25, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.04,
	}),
	-- golem ember nova: the arms out, the body up, then down with a burst
	erupt = style({
		windup = { arm = P(0.3, 0, 1.1, 0, 0, 0), body = P(0.15, 0, 0, 0, 0.3, 0), head = P(0.4, 0, 0, 0, 0, 0) },
		strike = { arm = P(0.4, 0, 0.3, 0, 0, 0), body = P(-0.1, 0, 0, 0, -0.3, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.05,
	}),
	-- treant basic: a swing of the branch arm
	branch = style({
		windup = { arm = P(2.0, 0, 0.6, 0, 0, 0), body = P(0.05, -0.3, 0, 0, 0, 0) },
		strike = { arm = P(0.1, 0, -0.2, 0, 0, 0), body = P(-0.1, 0.25, 0, 0, 0, 0) },
		arms = "right",
		dash = 0.3,
	}),
	-- treant slam: both branches up, down into the roots
	rootSlam = style({
		windup = { arm = P(2.3, 0, 0.3, 0, 0, 0), body = P(0.2, 0, 0, 0, 0.05, 0) },
		strike = { arm = P(-0.1, 0, 0.2, 0, 0, 0), body = P(-0.3, 0, 0, 0, -0.2, 0) },
		arms = "both",
		tremble = 0.03,
	}),
	-- ghost basic: the hands reach out
	reach = style({
		windup = { arm = P(0.6, 0, 0.2, 0, 0, 0), body = P(0.1, 0, 0, 0, 0.2, 0.2), head = P(0.15, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.5, 0, 0, 0, 0, 0), body = P(-0.15, 0, 0, 0, 0, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "both",
		dash = 0.6,
	}),
	-- ghost wail / frost nova: rises, the arms wide, the head thrown back
	wail = style({
		windup = { arm = P(1.2, 0, 1.0, 0, 0, 0), body = P(0.2, 0, 0, 0, 0.5, 0), head = P(0.5, 0, 0, 0, 0, 0) },
		strike = { arm = P(0.6, 0, 1.4, 0, 0, 0), body = P(0.1, 0, 0, 0, 0.3, 0), head = P(0.6, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.06,
	}),
	-- elemental basic: a push of the core forward, the shards turn faster
	pulse = style({
		windup = { body = P(0.15, 0, 0, 0, 0.2, 0.3), orbit = P(0, 1.0, 0, 0, 0, 0) },
		strike = { body = P(-0.15, 0, 0, 0, 0, 0), orbit = P(0, 2.0, 0, 0, 0, 0) },
		dash = 0.6,
	}),
	-- elemental nova: a contraction, then the burst
	nova = style({
		windup = { body = P(0, 0, 0, 0, -0.4, 0), orbit = P(0, 1.5, 0, 0, 0, 0) },
		strike = { body = P(0.1, 0, 0, 0, 0.4, 0), orbit = P(0, 2.5, 0, 0, 0, 0) },
		tremble = 0.06,
	}),
	-- Phases and summons ---------------------------------------------------------------------------------------------
	-- the phase roar of bosses (only `windup` is used: the roar envelope, Gait motion.roar)
	roar = style({
		windup = {
			head = P(0.6, 0, 0, 0, 0, 0),
			jaw = P(-0.6, 0, 0, 0, 0, 0),
			arm = P(1.0, 0, 0.9, 0, 0, 0),
			flap = P(0, 0, 0.7, 0, 0, 0),
			body = P(0.25, 0, 0, 0, 0.2, 0.1),
			spiderLeg = P(0, 0, 0.4, 0, 0, 0),
			claw = P(-0.6, 0, 0, 0, 0, 0),
			segment = P(0.2, 0, 0, 0, 0, 0),
			leg = P(0.4, 0, 0, 0, 0, 0),
		},
		strike = {},
		arms = "both",
	}),
	-- a summoned helper climbing out of the ground (only `windup`, scaled by 1 - rise): a tilt and a shake
	rise = style({
		windup = { body = P(0.25, 0, 0.15, 0, 0, 0), head = P(-0.3, 0, 0, 0, 0, 0), arm = P(0.8, 0, 0.3, 0, 0, 0) },
		strike = {},
		arms = "both",
	}),
	-- Bosses (Data/BossMotions: every attack of a boss has its own silhouette) ---------------------------------------
	-- Grimrok: the cleaver far back over the right shoulder, the shield in front; a wide cut turning to the left
	gr_sweep = style({
		windup = { arm = P(1.4, 0, 1.1, 0, 0, 0), body = P(0.05, -0.8, 0, 0, 0, 0.1) },
		strike = { arm = P(0.9, 0, -0.5, 0, 0, 0), body = P(-0.1, 0.9, 0, 0, 0, 0) },
		left = { windup = P(1.2, 0, -0.2, 0, 0, 0), strike = P(0.6, 0, 0.3, 0, 0, 0) },
		arms = "right",
		dash = 0.3,
	}),
	-- Grimrok leap: a deep crouch with both arms back, shaking; the jump is the arc of Gait.leapArc
	gr_leap = style({
		windup = { arm = P(-0.8, 0, 0.3, 0, 0, 0), body = P(-0.2, 0, 0, 0, -0.5, 0.1), head = P(0.25, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.8, 0, 0, 0, 0, 0), body = P(-0.35, 0, 0, 0, -0.2, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.05,
	}),
	-- Grimrok whirlwind: cleaver and shield spread out, the body wound up; two turns through the blow
	gr_whirl = style({
		windup = { arm = P(0.3, 0, 1.4, 0, 0, 0), body = P(0, -0.7, 0, 0, -0.1, 0) },
		strike = { arm = P(0.2, 0, 1.4, 0, 0, 0), body = P(-0.05, 0, 0, 0, -0.1, 0) },
		arms = "both",
		spin = 2,
	}),
	-- Morvane shadow bolt: the left hand up, the scythe behind the back; a push of the hand
	mv_bolt = style({
		windup = { arm = P(-0.6, 0, 0.2, 0, 0, 0), head = P(0.1, 0, 0, 0, 0, 0), body = P(0.05, 0.2, 0, 0, 0, 0) },
		strike = { arm = P(-0.4, 0, 0.2, 0, 0, 0), head = P(-0.1, 0, 0, 0, 0, 0), body = P(-0.1, -0.1, 0, 0, 0, 0) },
		left = { windup = P(2.3, 0, 0.3, 0, 0, 0), strike = P(1.5, 0, 0, 0, 0, 0) },
		arms = "right",
	}),
	-- Morvane fast bolts: both hands forward at once
	mv_boltFast = style({
		windup = { arm = P(1.0, 0, 0.2, 0, 0, 0), body = P(0.05, 0, 0, 0, 0, 0.1) },
		strike = { arm = P(1.6, 0, 0, 0, 0, 0), body = P(-0.1, 0, 0, 0, 0, 0) },
		arms = "both",
		dash = 0.3,
	}),
	-- Morvane curse field: the scythe planted in front, both hands on the shaft, the head down; then the arms open
	mv_curse = style({
		windup = { arm = P(1.0, 0, -0.3, 0, 0, 0), head = P(-0.5, 0, 0, 0, 0, 0), body = P(-0.15, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.2, 0, 1.3, 0, 0, 0), head = P(0.3, 0, 0, 0, 0, 0), body = P(0.1, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.03,
	}),
	-- Morvane death ring: lifts above the ground with the scythe high, falls and strikes the ground
	mv_deathRing = style({
		windup = { arm = P(2.3, 0, 0.9, 0, 0, 0), head = P(0.3, 0, 0, 0, 0, 0), body = P(0.1, 0, 0, 0, 1.2, 0) },
		strike = { arm = P(0.5, 0, 0.3, 0, 0, 0), head = P(-0.2, 0, 0, 0, 0, 0), body = P(-0.3, 0, 0, 0, -0.3, 0) },
		arms = "both",
		tremble = 0.04,
	}),
	-- Azgor flame cleave: the sword over the right shoulder, the left hand forward; a diagonal cut down
	az_cleave = style({
		windup = { arm = P(2.4, 0, 0.5, 0, 0, 0), body = P(0.1, -0.3, 0, 0, 0, 0) },
		strike = { arm = P(0.2, 0, -0.4, 0, 0, 0), body = P(-0.2, 0.4, 0, 0, -0.1, 0) },
		left = { windup = P(1.2, 0, 0, 0, 0, 0), strike = P(0.3, 0, 0.2, 0, 0, 0) },
		arms = "right",
		dash = 0.3,
	}),
	-- Azgor meteor: both hands and the head up, the hands come down with the rocks
	az_meteor = style({
		windup = { arm = P(2.5, 0, 0.3, 0, 0, 0), head = P(0.6, 0, 0, 0, 0, 0), body = P(0.15, 0, 0, 0, 0.1, 0) },
		strike = { arm = P(0.3, 0, 0.2, 0, 0, 0), head = P(0, 0, 0, 0, 0, 0), body = P(-0.15, 0, 0, 0, 0, 0) },
		-- S159g: crouched with the hands low while the meteors burn out
		follow = { arm = P(0.1, 0, 0.4, 0, 0, 0), body = P(-0.25, 0, 0, 0, -0.3, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.04,
	}),
	-- Azgor inferno: a crouch with the arms crossed, then up with the arms flung out
	az_inferno = style({
		windup = { arm = P(1.0, 0, -0.6, 0, 0, 0), body = P(-0.1, 0, 0, 0, -0.4, 0), head = P(-0.3, 0, 0, 0, 0, 0) },
		strike = { arm = P(0.5, 0, 1.5, 0, 0, 0), body = P(0.15, 0, 0, 0, 0.3, 0), head = P(0.4, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.05,
	}),
	-- Vaelgrath frost breath: the neck back and up, the maw shut, the front legs wider; forward with the maw open
	vg_breath = style({
		windup = {
			head = P(0.8, 0, 0, 0, 0, 0),
			jaw = P(-0.05, 0, 0, 0, 0, 0),
			body = P(0.25, 0, 0, 0, 0.15, 0.2),
			leg = P(0.3, 0, 0.3, 0, 0, 0),
			flap = P(0, 0, 0.3, 0, 0, 0),
		},
		strike = {
			head = P(-0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.9, 0, 0, 0, 0, 0),
			body = P(-0.1, 0, 0, 0, 0, -0.3),
			leg = P(0.1, 0, 0.3, 0, 0, 0),
			flap = P(0, 0, 0.1, 0, 0, 0),
		},
		arms = "both",
		tremble = 0.03,
	}),
	-- Vaelgrath wing buffet: the wings as high as they go, the body up; a hard beat down
	vg_wings = style({
		windup = { flap = P(0, 0, 1.0, 0, 0, 0), body = P(0.3, 0, 0, 0, 0.5, 0), head = P(0.3, 0, 0, 0, 0, 0) },
		strike = { flap = P(0, 0, -0.6, 0, 0, 0), body = P(0.05, 0, 0, 0, -0.2, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		tremble = 0.03,
	}),
	-- Vaelgrath tail swipe: the body turned away from the target, the tail coiled; the tail whips along the line
	vg_tail = style({
		windup = { body = P(0, 0.7, 0, 0, 0, 0), tail = P(0, -0.8, 0, 0, 0, 0), head = P(0, -0.4, 0, 0, 0, 0) },
		strike = { body = P(0, -0.8, 0, 0, -0.1, 0), tail = P(0, 1.0, 0, 0, 0, 0), head = P(0, 0.3, 0, 0, 0, 0) },
	}),
	-- Vaelgrath glacial ring: rears up on the hind legs with the wings spread; the front legs hit the ground
	vg_glacial = style({
		windup = {
			body = P(0.9, 0, 0, 0, 0.6, 0.2),
			leg = P(1.3, 0, 0.1, 0, 0, 0),
			flap = P(0, 0, 0.9, 0, 0, 0),
			head = P(-0.2, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(-0.2, 0, 0, 0, -0.2, -0.3),
			leg = P(-0.3, 0, 0, 0, 0, 0),
			flap = P(0, 0, 0.2, 0, 0, 0),
			head = P(-0.3, 0, 0, 0, 0, 0),
		},
		hindWindup = P(-0.5, 0, 0, 0, 0, 0),
		arms = "both",
		tremble = 0.05,
	}),
	-- S159g: gestures of the dodgeable patterns (Data/BossMotions.patterns): the windup is the anticipation over the
	-- pattern's warning, the strike peaks when the first projectile leaves (or the first rock lands), `follow` is the
	-- follow-through; a channel (a spiral, a breath, a rain) holds the strike for its length (Logic/HazardGesture).
	-- Grimrok axe throw: the hand axe cocked behind the head, the shield arm points at the target; the whip forward
	-- with a step, the arm follows through low across the body
	gr_axeThrow = style({
		windup = {
			arm = P(2.5, 0, 0.35, 0, 0, 0),
			body = P(0.12, -0.55, 0, 0, 0, 0.25),
			head = P(0.1, 0.2, 0, 0, 0, 0),
		},
		strike = {
			arm = P(0.9, 0, -0.35, 0, 0, 0),
			body = P(-0.2, 0.6, 0, 0, 0, -0.1),
			head = P(-0.1, -0.1, 0, 0, 0, 0),
		},
		follow = {
			arm = P(0.5, 0, -0.5, 0, 0, 0),
			body = P(-0.18, 0.45, 0, 0, -0.08, 0),
			head = P(-0.05, 0, 0, 0, 0, 0),
		},
		left = {
			windup = P(1.45, 0, -0.05, 0, 0, 0),
			strike = P(0.3, 0, 0.25, 0, 0, 0),
			follow = P(0.2, 0, 0.3, 0, 0, 0),
		},
		arms = "right",
		dash = 0.5,
	}),
	-- Grimrok axe fan (behind the shield): both arms crossed over the chest in a crouch, then flung wide as the five
	-- axes fly out of the hands; the arms stay spread while they come back
	gr_axeFan = style({
		windup = {
			arm = P(1.1, 0, -0.75, 0, 0, 0),
			body = P(-0.1, -0.3, 0, 0, -0.3, 0.1),
			head = P(-0.2, 0, 0, 0, 0, 0),
		},
		strike = { arm = P(1.0, 0, 1.5, 0, 0, 0), body = P(0.12, 0.2, 0, 0, 0.1, 0), head = P(0.3, 0, 0, 0, 0, 0) },
		follow = { arm = P(0.6, 0, 1.3, 0, 0, 0), body = P(0.05, 0, 0, 0, 0, 0), head = P(0.15, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.03,
	}),
	-- Grimrok bombs: bent down to the belt, a bomb in each hand; an underhand lob up and over, the hands stay high
	gr_bombLob = style({
		windup = {
			arm = P(-0.5, 0, 0.25, 0, 0, 0),
			body = P(-0.3, 0.2, 0, 0, -0.2, 0),
			head = P(-0.3, 0, 0, 0, 0, 0),
		},
		strike = { arm = P(2.3, 0, 0.15, 0, 0, 0), body = P(0.2, -0.1, 0, 0, 0.15, 0.1), head = P(0.35, 0, 0, 0, 0, 0) },
		follow = { arm = P(1.8, 0, 0.2, 0, 0, 0), body = P(0.1, 0, 0, 0, 0.05, 0), head = P(0.25, 0, 0, 0, 0, 0) },
		left = {
			windup = P(-0.3, 0, 0.2, 0, 0, 0),
			strike = P(1.6, 0, 0.2, 0, 0, 0),
			follow = P(1.2, 0, 0.25, 0, 0, 0),
		},
		arms = "right",
	}),
	-- Grimrok ground splitter: the cleaver high over the head in both hands, leaning back; down into the ground as the
	-- crack runs, the back stays bent over the buried blade
	gr_fissure = style({
		windup = { arm = P(2.5, 0, 0.05, 0, 0, 0), body = P(0.3, 0, 0, 0, 0.1, 0.15), head = P(0.3, 0, 0, 0, 0, 0) },
		strike = {
			arm = P(-0.1, 0, 0.1, 0, 0, 0),
			body = P(-0.5, 0, 0, 0, -0.35, -0.15),
			head = P(-0.35, 0, 0, 0, 0, 0),
		},
		follow = { arm = P(0, 0, 0.15, 0, 0, 0), body = P(-0.45, 0, 0, 0, -0.3, -0.1), head = P(-0.25, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.04,
		dash = 0.4,
	}),
	-- Morvane soul orbs: she rises with the free hand up, gathering the souls above it, the scythe low behind; the hand
	-- sends them at her targets and stays pointing after them
	mv_soulOrbs = style({
		windup = {
			arm = P(-0.3, 0, 0.35, 0, 0, 0),
			body = P(0.15, 0, 0, 0, 0.5, 0.1),
			head = P(0.35, 0, 0, 0, 0, 0),
		},
		strike = {
			arm = P(0.2, 0, 0.2, 0, 0, 0),
			body = P(-0.15, 0.1, 0, 0, 0.3, -0.2),
			head = P(-0.15, 0, 0, 0, 0, 0),
		},
		follow = { arm = P(0.1, 0, 0.25, 0, 0, 0), body = P(-0.08, 0, 0, 0, 0.2, 0), head = P(-0.05, 0, 0, 0, 0, 0) },
		left = {
			windup = P(2.2, 0, 0.5, 0, 0, 0),
			strike = P(1.5, 0, -0.15, 0, 0, 0),
			follow = P(1.4, 0, 0.1, 0, 0, 0),
		},
		arms = "right",
		tremble = 0.03,
	}),
	-- Morvane soul volley: both hands drawn to the chest, then pushed out; the fingers stay fanned like the orbs
	mv_soulVolley = style({
		windup = { arm = P(0.5, 0, -0.5, 0, 0, 0), body = P(0.1, 0, 0, 0, -0.1, 0.2), head = P(-0.2, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.7, 0, 0.3, 0, 0, 0), body = P(-0.15, 0, 0, 0, 0, -0.2), head = P(0.05, 0, 0, 0, 0, 0) },
		follow = { arm = P(1.55, 0, 0.55, 0, 0, 0), body = P(-0.1, 0, 0, 0, 0, -0.1) },
		arms = "both",
		dash = 0.4,
	}),
	-- Morvane spiral: bowed, gathering, then she rises with the arms flung wide and turns with the spiral (the body
	-- turn of Logic/HazardGesture.turnOf) while it pours out
	mv_spiral = style({
		windup = { arm = P(0.4, 0, 0.3, 0, 0, 0), body = P(-0.2, 0, 0, 0, 0.2, 0), head = P(-0.45, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.3, 0, 1.45, 0, 0, 0), body = P(0.15, 0, 0, 0, 0.9, 0), head = P(0.45, 0, 0, 0, 0, 0) },
		follow = { arm = P(0.6, 0, 0.9, 0, 0, 0), body = P(0, 0, 0, 0, 0.3, 0), head = P(0.1, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.05,
	}),
	-- Azgor flame wall: the sword dragged low behind, crouched and turned; ripped up along the lane, held high after
	az_flameWall = style({
		windup = {
			arm = P(-0.9, 0, 0.45, 0, 0, 0),
			body = P(-0.15, -0.5, 0, 0, -0.25, 0.15),
			head = P(-0.1, 0, 0, 0, 0, 0),
		},
		strike = {
			arm = P(2.3, 0, -0.25, 0, 0, 0),
			body = P(0.15, 0.45, 0, 0, 0.1, -0.2),
			head = P(0.15, 0, 0, 0, 0, 0),
		},
		follow = { arm = P(2.0, 0, 0.1, 0, 0, 0), body = P(0.08, 0.35, 0, 0, 0.05, 0), head = P(0.1, 0, 0, 0, 0, 0) },
		left = { windup = P(0.6, 0, 0.6, 0, 0, 0), strike = P(0.3, 0, 0.9, 0, 0, 0), follow = P(0.3, 0, 0.8, 0, 0, 0) },
		arms = "right",
		dash = 0.5,
	}),
	-- Azgor fireballs: both hands cupped at the hip, the body wound up and shaking; a push of both palms, the hands
	-- stay spread like the fan
	az_fireballs = style({
		windup = {
			arm = P(0.6, 0, -0.6, 0, 0, 0),
			body = P(0.05, -0.6, 0, 0, -0.15, 0.2),
			head = P(0, -0.3, 0, 0, 0, 0),
		},
		strike = {
			arm = P(1.65, 0, 0.15, 0, 0, 0),
			body = P(-0.12, 0.25, 0, 0, 0, -0.25),
			head = P(-0.05, 0.1, 0, 0, 0, 0),
		},
		follow = { arm = P(1.5, 0, 0.45, 0, 0, 0), body = P(-0.08, 0.15, 0, 0, 0, -0.15) },
		arms = "both",
		tremble = 0.04,
		dash = 0.5,
	}),
	-- Azgor magma: both fists high over the head, then a hop and both fists into the ground (the balls burst out of
	-- it); he stays crouched over them
	az_magmaSlam = style({
		windup = { arm = P(2.5, 0, 0.2, 0, 0, 0), body = P(0.25, 0, 0, 0, 0.25, 0.1), head = P(0.3, 0, 0, 0, 0, 0) },
		strike = { arm = P(0, 0, 0.3, 0, 0, 0), body = P(-0.45, 0, 0, 0, -0.45, -0.1), head = P(-0.3, 0, 0, 0, 0, 0) },
		follow = { arm = P(0.1, 0, 0.35, 0, 0, 0), body = P(-0.4, 0, 0, 0, -0.4, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.05,
		hop = 0.7,
	}),
	-- Vaelgrath ice comets: the head up with the maw open and the wings wide, calling them down; the head snaps to the
	-- ground at the first landing and watches the rest fall
	vg_comets = style({
		windup = {
			head = P(1.1, 0, 0, 0, 0, 0),
			jaw = P(-0.8, 0, 0, 0, 0, 0),
			flap = P(0, 0, 0.95, 0, 0, 0),
			body = P(0.35, 0, 0, 0, 0.3, 0.1),
			segment = P(0.3, 0, 0, 0, 0, 0),
		},
		strike = {
			head = P(-0.55, 0, 0, 0, 0, 0),
			jaw = P(-0.3, 0, 0, 0, 0, 0),
			flap = P(0, 0, -0.3, 0, 0, 0),
			body = P(-0.15, 0, 0, 0, -0.1, -0.2),
			segment = P(-0.25, 0, 0, 0, 0, 0),
		},
		follow = {
			head = P(-0.35, 0, 0, 0, 0, 0),
			jaw = P(-0.5, 0, 0, 0, 0, 0),
			flap = P(0, 0, 0.25, 0, 0, 0),
			body = P(-0.08, 0, 0, 0, 0, 0),
		},
		tremble = 0.05,
	}),
	-- Vaelgrath avalanche: rears up on the hind legs with the wings spread, the front legs crash down and the
	-- snowballs roll out; it roars after them
	vg_avalanche = style({
		windup = {
			body = P(0.85, 0, 0, 0, 0.55, 0.25),
			leg = P(1.3, 0, 0.1, 0, 0, 0),
			flap = P(0, 0, 0.85, 0, 0, 0),
			head = P(-0.2, 0, 0, 0, 0, 0),
			jaw = P(-0.4, 0, 0, 0, 0, 0),
		},
		strike = {
			body = P(-0.25, 0, 0, 0, -0.2, -0.4),
			leg = P(-0.35, 0, 0, 0, 0, 0),
			flap = P(0, 0, -0.2, 0, 0, 0),
			head = P(-0.35, 0, 0, 0, 0, 0),
			jaw = P(-0.7, 0, 0, 0, 0, 0),
		},
		follow = {
			body = P(-0.18, 0, 0, 0, -0.15, -0.2),
			head = P(0.1, 0, 0, 0, 0, 0),
			jaw = P(-0.85, 0, 0, 0, 0, 0),
			flap = P(0, 0, 0.4, 0, 0, 0),
		},
		hindWindup = P(-0.5, 0, 0, 0, 0, 0),
		arms = "both",
		tremble = 0.04,
		dash = 0.6,
	}),
	-- Vaelgrath frost orbs: the neck coils back with the maw shut, then the spit; the maw stays open on the orbs
	vg_orbSpit = style({
		windup = {
			segment = P(0.45, 0, 0, 0, 0, 0),
			head = P(0.75, 0, 0, 0, 0, 0),
			jaw = P(-0.05, 0, 0, 0, 0, 0),
			body = P(0.2, 0, 0, 0, 0.1, 0.3),
			flap = P(0, 0, 0.35, 0, 0, 0),
		},
		strike = {
			segment = P(-0.35, 0, 0, 0, 0, 0),
			head = P(-0.45, 0, 0, 0, 0, 0),
			jaw = P(-0.9, 0, 0, 0, 0, 0),
			body = P(-0.12, 0, 0, 0, 0, -0.25),
		},
		follow = { head = P(-0.25, 0, 0, 0, 0, 0), jaw = P(-0.6, 0, 0, 0, 0, 0), segment = P(-0.2, 0, 0, 0, 0, 0) },
		tremble = 0.03,
		dash = 0.3,
	}),
	-- Vaelgrath shard rain: the wings as high as they go, the head up; a hard beat down that shakes the shards loose,
	-- then the wings rise again over the falling ice
	vg_wingStorm = style({
		windup = {
			flap = P(0, 0, 1.05, 0, 0, 0),
			body = P(0.3, 0, 0, 0, 0.65, 0.15),
			head = P(0.6, 0, 0, 0, 0, 0),
			jaw = P(-0.6, 0, 0, 0, 0, 0),
		},
		strike = {
			flap = P(0, 0, -0.75, 0, 0, 0),
			body = P(-0.05, 0, 0, 0, -0.15, 0),
			head = P(0.2, 0, 0, 0, 0, 0),
		},
		follow = {
			flap = P(0, 0, 0.5, 0, 0, 0),
			body = P(0.1, 0, 0, 0, 0.3, 0),
			head = P(0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.5, 0, 0, 0, 0, 0),
		},
		tremble = 0.03,
	}),
	-- Hrimvald boulder throw: squatting with the boulder over the head in both hands, leaning back; heaved forward
	-- with a step, the arms follow it out
	hv_boulderThrow = style({
		windup = { arm = P(2.5, 0, 0.25, 0, 0, 0), body = P(0.3, 0, 0, 0, -0.25, 0.3), head = P(0.3, 0, 0, 0, 0, 0) },
		strike = { arm = P(0.8, 0, 0.05, 0, 0, 0), body = P(-0.35, 0, 0, 0, 0, -0.4), head = P(-0.25, 0, 0, 0, 0, 0) },
		follow = { arm = P(0.6, 0, 0.2, 0, 0, 0), body = P(-0.3, 0, 0, 0, -0.1, -0.25), head = P(-0.1, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.03,
		dash = 0.6,
	}),
	-- Hrimvald ice spikes: the club high over the right shoulder in both hands, turned back; slammed into the ground,
	-- bent over it while the spikes run
	hv_spikeSlam = style({
		windup = {
			arm = P(2.5, 0, -0.1, 0, 0, 0),
			body = P(0.25, -0.35, 0, 0, 0.1, 0.15),
			head = P(0.25, 0, 0, 0, 0, 0),
		},
		strike = {
			arm = P(-0.15, 0, 0.15, 0, 0, 0),
			body = P(-0.5, 0.1, 0, 0, -0.4, -0.2),
			head = P(-0.35, 0, 0, 0, 0, 0),
		},
		follow = {
			arm = P(0, 0, 0.2, 0, 0, 0),
			body = P(-0.45, 0.05, 0, 0, -0.4, -0.1),
			head = P(-0.25, 0, 0, 0, 0, 0),
		},
		arms = "both",
		tremble = 0.04,
		hop = 0.5,
	}),
	-- Hrimvald ice blocks: both arms raised wide to the sky, shaking; pulled down hard as the blocks land
	hv_iceCall = style({
		windup = { arm = P(2.5, 0, 1.0, 0, 0, 0), head = P(0.7, 0, 0, 0, 0, 0), body = P(0.25, 0, 0, 0, 0.15, 0) },
		strike = { arm = P(0.5, 0, 0.35, 0, 0, 0), body = P(-0.3, 0, 0, 0, -0.35, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		follow = { arm = P(0.3, 0, 0.5, 0, 0, 0), body = P(-0.25, 0, 0, 0, -0.3, 0), head = P(-0.1, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.05,
	}),
	-- Hrimvald shard rain: the club raised to the sky, the free hand open; held up, shaking, while the shards fall
	hv_shardCall = style({
		windup = { arm = P(2.2, 0, 0.3, 0, 0, 0), head = P(0.5, 0, 0, 0, 0, 0), body = P(0.15, 0, 0, 0, 0.1, 0) },
		strike = { arm = P(2.5, 0, 0.1, 0, 0, 0), head = P(0.7, 0, 0, 0, 0, 0), body = P(0.25, 0, 0, 0, 0.25, 0) },
		follow = { arm = P(2.0, 0, 0.3, 0, 0, 0), head = P(0.3, 0, 0, 0, 0, 0), body = P(0.1, 0, 0, 0, 0.1, 0) },
		left = { windup = P(0.8, 0, 0.9, 0, 0, 0), strike = P(1.0, 0, 1.1, 0, 0, 0), follow = P(0.5, 0, 0.6, 0, 0, 0) },
		arms = "right",
		tremble = 0.05,
	}),
	-- Hrimvald frost breath: a deep breath with the chest up and the arms back, then the head forward and the breath
	-- turns with the body (Logic/HazardGesture.turnOf) across the front
	hv_breath = style({
		windup = { body = P(0.35, 0, 0, 0, 0.15, 0.25), head = P(0.7, 0, 0, 0, 0, 0), arm = P(-0.5, 0, 0.5, 0, 0, 0) },
		strike = {
			body = P(-0.2, 0, 0, 0, -0.05, -0.15),
			head = P(-0.35, 0, 0, 0, 0, 0),
			arm = P(0.4, 0, 0.7, 0, 0, 0),
		},
		follow = { body = P(-0.05, 0, 0, 0, 0, 0), head = P(-0.1, 0, 0, 0, 0, 0), arm = P(0.2, 0, 0.4, 0, 0, 0) },
		arms = "both",
		tremble = 0.03,
	}),
	-- Hrimvald ice javelins: the right arm cocked far back, the left points, the body turned away; the hurl through,
	-- the arm follows low
	hv_javelins = style({
		windup = { arm = P(2.5, 0, 0.65, 0, 0, 0), body = P(0.15, -0.75, 0, 0, 0, 0.3), head = P(0, 0.35, 0, 0, 0, 0) },
		strike = {
			arm = P(0.85, 0, -0.45, 0, 0, 0),
			body = P(-0.25, 0.8, 0, 0, 0, -0.2),
			head = P(-0.1, -0.2, 0, 0, 0, 0),
		},
		follow = { arm = P(0.5, 0, -0.55, 0, 0, 0), body = P(-0.22, 0.55, 0, 0, -0.1, -0.1) },
		left = {
			windup = P(1.5, 0, -0.1, 0, 0, 0),
			strike = P(0.2, 0, 0.3, 0, 0, 0),
			follow = P(0.1, 0, 0.35, 0, 0, 0),
		},
		arms = "right",
		dash = 0.7,
	}),
	-- Hrimvald glacier walls: the arms wide and rising, shaking; a jump and both fists down at the arena's edge, then
	-- the arms push outwards like the walls
	hv_wallRise = style({
		windup = { arm = P(1.6, 0, 1.35, 0, 0, 0), body = P(0.2, 0, 0, 0, 0.3, 0), head = P(0.5, 0, 0, 0, 0, 0) },
		strike = { arm = P(0.4, 0, 0.4, 0, 0, 0), body = P(-0.35, 0, 0, 0, -0.45, 0), head = P(-0.2, 0, 0, 0, 0, 0) },
		follow = { arm = P(1.2, 0, 0.9, 0, 0, 0), body = P(-0.1, 0, 0, 0, -0.2, 0), head = P(0, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.05,
		hop = 0.9,
	}),
	-- Hrimvald glacier stomp (its shock ring rides on it): a crouch with the arms out, a jump and the stomp, the arms
	-- stay out for balance while the ring runs
	hv_stomp = style({
		windup = { body = P(0.15, 0, 0, 0, -0.3, 0.1), arm = P(1.6, 0, 0.9, 0, 0, 0), head = P(0.2, 0, 0, 0, 0, 0) },
		strike = { body = P(-0.25, 0, 0, 0, -0.35, 0), arm = P(0.2, 0, 0.7, 0, 0, 0), head = P(-0.25, 0, 0, 0, 0, 0) },
		follow = { body = P(-0.2, 0, 0, 0, -0.3, 0), arm = P(0.3, 0, 0.8, 0, 0, 0), head = P(-0.1, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.04,
		hop = 1.0,
	}),
	-- S159g: boss roars (only `windup`: the roar envelope); `*_rage` roars into the last phase
	gr_roar = style({
		windup = {
			arm = P(2.4, 0, 0.6, 0, 0, 0),
			head = P(0.55, 0, 0, 0, 0, 0),
			jaw = P(-0.6, 0, 0, 0, 0, 0),
			body = P(0.25, 0, 0, 0, 0.15, 0.1),
		},
		strike = {},
		left = { windup = P(0.9, 0, 1.0, 0, 0, 0) },
		arms = "right",
	}),
	gr_rage = style({
		windup = {
			arm = P(1.2, 0, 1.3, 0, 0, 0),
			head = P(0.35, 0, 0, 0, 0, 0),
			jaw = P(-0.7, 0, 0, 0, 0, 0),
			body = P(-0.2, 0, 0, 0, -0.25, 0),
		},
		strike = {},
		arms = "both",
	}),
	mv_wail = style({
		windup = {
			arm = P(1.1, 0, 1.4, 0, 0, 0),
			head = P(0.75, 0, 0, 0, 0, 0),
			jaw = P(-0.6, 0, 0, 0, 0, 0),
			body = P(0.25, 0, 0, 0, 0.9, 0),
		},
		strike = {},
		arms = "both",
	}),
	mv_rage = style({
		windup = {
			arm = P(2.5, 0, 0.6, 0, 0, 0),
			head = P(0.5, 0, 0, 0, 0, 0),
			jaw = P(-0.7, 0, 0, 0, 0, 0),
			body = P(0.1, 0, 0, 0, 1.1, 0),
		},
		strike = {},
		arms = "both",
	}),
	az_roar = style({
		windup = {
			arm = P(0.6, 0, 1.1, 0, 0, 0),
			head = P(0.6, 0, 0, 0, 0, 0),
			jaw = P(-0.6, 0, 0, 0, 0, 0),
			body = P(0.3, 0, 0, 0, 0.1, 0.15),
		},
		strike = {},
		arms = "both",
	}),
	az_rage = style({
		windup = {
			arm = P(2.3, 0, 0.8, 0, 0, 0),
			head = P(0.7, 0, 0, 0, 0, 0),
			jaw = P(-0.7, 0, 0, 0, 0, 0),
			body = P(0.2, 0, 0, 0, 0.25, 0),
		},
		strike = {},
		arms = "both",
	}),
	vg_roar = style({
		windup = {
			body = P(0.75, 0, 0, 0, 0.45, 0.2),
			head = P(0.95, 0, 0, 0, 0, 0),
			jaw = P(-0.95, 0, 0, 0, 0, 0),
			flap = P(0, 0, 1.0, 0, 0, 0),
			leg = P(1.0, 0, 0.1, 0, 0, 0),
			segment = P(0.35, 0, 0, 0, 0, 0),
			tail = P(0.3, 0, 0, 0, 0, 0),
		},
		strike = {},
		hindWindup = P(-0.4, 0, 0, 0, 0, 0),
		arms = "both",
	}),
	vg_rage = style({
		windup = {
			body = P(-0.15, 0, 0, 0, -0.1, 0),
			head = P(0.25, 0, 0, 0, 0, 0),
			jaw = P(-0.9, 0, 0, 0, 0, 0),
			flap = P(0, 0, 0.9, 0, 0, 0),
			leg = P(0.3, 0, 0, 0, 0, 0),
			segment = P(-0.2, 0, 0, 0, 0, 0),
		},
		strike = {},
		arms = "both",
	}),
	hv_roar = style({
		windup = {
			arm = P(1.3, 0, 1.2, 0, 0, 0),
			head = P(0.65, 0, 0, 0, 0, 0),
			jaw = P(-0.6, 0, 0, 0, 0, 0),
			body = P(0.3, 0, 0, 0, 0.15, 0.15),
		},
		strike = {},
		arms = "both",
	}),
	hv_rage = style({
		windup = {
			arm = P(2.5, 0, 0.5, 0, 0, 0),
			head = P(0.6, 0, 0, 0, 0, 0),
			jaw = P(-0.7, 0, 0, 0, 0, 0),
			body = P(0.2, 0, 0, 0, 0.2, 0),
		},
		strike = {},
		arms = "both",
	}),
	-- S159g: the draw before a regular ranged blow (RANGED; the "aw" event's shot), short windups (Data/Combat.basicWind)
	-- a bow: the bow arm out, the string hand drawn back past the cheek, the body side on; the release flicks it back
	bowDraw = style({
		windup = { arm = P(1.5, 0, 0.6, 0, 0, 0), body = P(0, -0.35, 0, 0, 0, 0), head = P(0, 0.3, 0, 0, 0, 0) },
		strike = { arm = P(1.2, 0, 0.9, 0, 0, 0), body = P(-0.05, -0.3, 0, 0, 0, 0.05), head = P(0, 0.25, 0, 0, 0, 0) },
		left = { windup = P(1.55, 0, -0.1, 0, 0, 0), strike = P(1.5, 0, -0.1, 0, 0, 0) },
		arms = "right",
	}),
	-- a staff / wand / bare hand: raised with the bolt gathering, thrust at the target, held out after it
	castBolt = style({
		windup = { arm = P(2.0, 0, 0.2, 0, 0, 0), body = P(0.12, 0, 0, 0, 0, 0.15), head = P(0.2, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.45, 0, -0.05, 0, 0, 0), body = P(-0.12, 0, 0, 0, 0, -0.15), head = P(-0.1, 0, 0, 0, 0, 0) },
		follow = { arm = P(1.3, 0, 0, 0, 0, 0), body = P(-0.05, 0, 0, 0, 0, 0) },
		arms = "right",
		tremble = 0.03,
	}),
	-- an overhand throw (a rock, a dark bolt): cocked behind the head, the other hand points, a step into the throw
	throwOver = style({
		windup = { arm = P(2.5, 0, 0.4, 0, 0, 0), body = P(0.1, -0.45, 0, 0, 0, 0.2) },
		strike = { arm = P(0.7, 0, -0.3, 0, 0, 0), body = P(-0.15, 0.45, 0, 0, 0, -0.15) },
		follow = { arm = P(0.4, 0, -0.4, 0, 0, 0), body = P(-0.1, 0.3, 0, 0, 0, 0) },
		left = { windup = P(1.2, 0, 0, 0, 0, 0), strike = P(0.2, 0, 0.2, 0, 0, 0), follow = P(0.1, 0, 0.2, 0, 0, 0) },
		arms = "right",
		dash = 0.3,
	}),
	-- golems and treants: a two-handed heave from over the head
	heave = style({
		windup = { arm = P(2.5, 0, 0.1, 0, 0, 0), body = P(0.25, 0, 0, 0, -0.15, 0.2) },
		strike = { arm = P(0.9, 0, 0, 0, 0, 0), body = P(-0.3, 0, 0, 0, 0, -0.3) },
		follow = { arm = P(0.7, 0, 0.1, 0, 0, 0), body = P(-0.2, 0, 0, 0, 0, -0.1) },
		arms = "both",
		dash = 0.3,
	}),
	-- ghosts: the hands drawn in to the chest as it rises, then pushed out with the curse
	hex = style({
		windup = { arm = P(0.4, 0, -0.6, 0, 0, 0), body = P(0.1, 0, 0, 0, 0.3, 0.2), head = P(-0.2, 0, 0, 0, 0, 0) },
		strike = { arm = P(1.6, 0, 0.25, 0, 0, 0), body = P(-0.15, 0, 0, 0, 0, -0.2), head = P(0.1, 0, 0, 0, 0, 0) },
		arms = "both",
		tremble = 0.04,
	}),
	-- elementals: the core shrinks back, the shards whirl, then it pushes the bolt out
	pulseShot = style({
		windup = { body = P(0, 0, 0, 0, -0.2, 0.3), orbit = P(0, 1.5, 0, 0, 0, 0) },
		strike = { body = P(-0.1, 0, 0, 0, 0.1, -0.4), orbit = P(0, 2.5, 0, 0, 0, 0) },
		tremble = 0.05,
	}),
	-- birds and bats: the wings swept up and back, the body rises; a beat forward flings the shot
	featherShot = style({
		windup = { flap = P(0, 0.4, 0.8, 0, 0, 0), body = P(0.3, 0, 0, 0, 0.35, 0.3), head = P(0.3, 0, 0, 0, 0, 0) },
		strike = { flap = P(0, -0.5, -0.4, 0, 0, 0), body = P(-0.2, 0, 0, 0, 0, -0.2), head = P(-0.3, 0, 0, 0, 0, 0) },
		arms = "both",
	}),
	-- dragons and wyverns: the neck pulls back, then the spit with the maw open
	spitShot = style({
		windup = {
			segment = P(0.35, 0, 0, 0, 0, 0),
			head = P(0.6, 0, 0, 0, 0, 0),
			jaw = P(-0.1, 0, 0, 0, 0, 0),
			body = P(0.15, 0, 0, 0, 0.1, 0.25),
		},
		strike = {
			segment = P(-0.3, 0, 0, 0, 0, 0),
			head = P(-0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.8, 0, 0, 0, 0, 0),
			body = P(-0.1, 0, 0, 0, 0, -0.2),
		},
		tremble = 0.03,
	}),
	-- four-legged throwers (an Elite II's rock): the head low to scoop, then tossed up and forward
	toss = style({
		windup = { head = P(-0.5, 0, 0, 0, 0, 0), body = P(-0.1, 0, 0, 0, -0.15, 0.2), jaw = P(-0.3, 0, 0, 0, 0, 0) },
		strike = { head = P(0.6, 0, 0, 0, 0, 0), body = P(0.15, 0, 0, 0, 0.1, -0.2), jaw = P(-0.5, 0, 0, 0, 0, 0) },
		dash = 0.2,
	}),
}

local PLANS: { [string]: PlanMotion } = {
	hare = { basic = "bite", special = { default = "bite" }, death = "side" },
	-- S134c: the Invasion commander's blows (warlord*) borrow the plan's leap / slam / cast styles
	canine = {
		basic = "bite",
		special = { leap = "pounce", warlordLeap = "pounce", default = "pounce" },
		death = "side",
	},
	bear = { basic = "swipe", special = { slam = "rear", default = "rear" }, death = "side", hit = { lean = 0.12 } },
	boar = { basic = "gore", special = { charge = "charge", default = "charge" }, death = "side" },
	toad = { basic = "squash", special = { poisonPool = "spit", default = "spit" }, death = "flat" },
	lizard = {
		basic = "snap",
		special = { fireBreath = "breath", poisonPool = "spit", default = "breath" },
		death = "side",
	},
	mammoth = {
		basic = "tusk",
		special = { slam = "stomp", default = "stomp" },
		death = "side",
		hit = { lean = 0.08, push = 0.12 },
	},
	-- S96 mounts: never fight; a minimal entry keeps the plan list complete
	horse = { basic = "bite", special = { default = "bite" }, death = "side" },
	serpent = {
		basic = "strike",
		special = { poisonPool = "spit", frostBreath = "breath", default = "breath" },
		death = "coil",
	},
	spider = { basic = "fang", special = { poisonPool = "spiderSpit", default = "spiderSpit" }, death = "curl" },
	scorpion = { basic = "pincer", special = { poisonPool = "sting", default = "sting" }, death = "curl" },
	bird = {
		basic = "dive",
		special = { wail = "screech", default = "screech" },
		death = "fall",
		hit = { lean = 0.25 },
	},
	bat = { basic = "dive", special = { wail = "screech", default = "screech" }, death = "fall", hit = { lean = 0.25 } },
	dragon = {
		basic = "bite",
		special = { fireBreath = "breath", frostBreath = "breath", default = "breath" },
		death = "dragon",
		hit = { lean = 0.1 },
	},
	humanoid = {
		basic = "slash",
		special = {
			cleave = "wide",
			slam = "jumpSlam",
			boneNova = "castBurst",
			voidPool = "castBurst",
			emberNova = "castBurst",
			charge = "charge",
			fireBreath = "breath",
			warlordCleave = "wide",
			warlordLeap = "jumpSlam",
			warlordRally = "castBurst",
			default = "wide",
		},
		death = "knees",
	},
	beast = {
		basic = "claw",
		special = { slam = "jumpSlam", leap = "beastPounce", warlordLeap = "beastPounce", default = "jumpSlam" },
		death = "knees",
	},
	golem = {
		basic = "punch",
		special = { slam = "slam", emberNova = "erupt", default = "slam" },
		death = "crumble",
		hit = { lean = 0.08, push = 0.1 },
	},
	treant = {
		basic = "branch",
		special = { slam = "rootSlam", default = "rootSlam" },
		death = "crumble",
		hit = { lean = 0.1 },
	},
	ghost = { basic = "reach", special = { wail = "wail", frostNova = "wail", default = "wail" }, death = "dissolve" },
	elemental = { basic = "pulse", special = { frostNova = "nova", default = "nova" }, death = "dissolve" },
}

-- S134e: the kit blows of Elites / Elites II (Data/MonsterAbilities.KITS) by plan: Crushing Blow a heavy overhead /
-- rearing blow, Pounce a lunge, Heavy Blow the plan's sweep; a plan without an entry takes special.default.
local KIT_STYLES: { [string]: { [string]: string } } = {
	canine = { crush = "rear", pounce = "pounce", heavyBlow = "bite" },
	bear = { crush = "stomp", pounce = "charge", heavyBlow = "swipe" },
	boar = { crush = "rear", pounce = "charge", heavyBlow = "gore" },
	toad = { crush = "squash", pounce = "squash", heavyBlow = "squash" },
	lizard = { crush = "rear", pounce = "charge", heavyBlow = "snap" },
	mammoth = { crush = "rear", pounce = "charge", heavyBlow = "tusk" },
	serpent = { crush = "strike", pounce = "strike", heavyBlow = "strike" },
	spider = { crush = "fang", pounce = "fang", heavyBlow = "fang" },
	scorpion = { crush = "sting", pounce = "pincer", heavyBlow = "pincer" },
	bird = { crush = "dive", pounce = "dive", heavyBlow = "dive" },
	bat = { crush = "dive", pounce = "dive", heavyBlow = "dive" },
	dragon = { crush = "stomp", pounce = "dive", heavyBlow = "bite" },
	humanoid = { crush = "overhead", pounce = "jumpSlam", heavyBlow = "wide" },
	beast = { crush = "overhead", pounce = "beastPounce", heavyBlow = "claw" },
	golem = { crush = "slam", pounce = "punch", heavyBlow = "punch" },
	treant = { crush = "rootSlam", pounce = "branch", heavyBlow = "branch" },
	ghost = { crush = "reach", pounce = "reach", heavyBlow = "reach" },
	elemental = { crush = "nova", pounce = "pulse", heavyBlow = "pulse" },
}

-- S159g: the draw before a regular ranged blow by plan and shot (the "aw" event's `st`: "arrow" a physical shot,
-- "bolt" a magic one, "throw" an Elite II's throw); a plan without an entry draws its basic style.
local RANGED: { [string]: { [string]: string } } = {
	humanoid = { arrow = "bowDraw", bolt = "castBolt", throw = "throwOver" },
	beast = { arrow = "throwOver", bolt = "castBolt", throw = "throwOver" },
	golem = { arrow = "heave", bolt = "castBolt", throw = "heave" },
	treant = { arrow = "heave", bolt = "heave", throw = "heave" },
	ghost = { arrow = "hex", bolt = "hex", throw = "hex" },
	elemental = { arrow = "pulseShot", bolt = "pulseShot", throw = "pulseShot" },
	bird = { arrow = "featherShot", bolt = "featherShot", throw = "featherShot" },
	bat = { arrow = "featherShot", bolt = "featherShot", throw = "featherShot" },
	dragon = { arrow = "spitShot", bolt = "spitShot", throw = "spitShot" },
	serpent = { arrow = "spit", bolt = "spit", throw = "spit" },
	lizard = { arrow = "spit", bolt = "spit", throw = "spit" },
	toad = { arrow = "spit", bolt = "spit", throw = "spit" },
	spider = { arrow = "spiderSpit", bolt = "spiderSpit", throw = "spiderSpit" },
	scorpion = { arrow = "sting", bolt = "sting", throw = "sting" },
	canine = { arrow = "toss", bolt = "toss", throw = "toss" },
	bear = { arrow = "toss", bolt = "toss", throw = "toss" },
	boar = { arrow = "toss", bolt = "toss", throw = "toss" },
	mammoth = { arrow = "toss", bolt = "toss", throw = "toss" },
	hare = { arrow = "toss", bolt = "toss", throw = "toss" },
	horse = { arrow = "toss", bolt = "toss", throw = "toss" },
}

-- Basic attacks of humanoids and beasts by the weapon of their look (Data/MonsterLooks `weapon`).
local WEAPON_BASIC: { [string]: string } = {
	saber1h = "slash",
	sword1h = "slash",
	frostSword = "slash",
	flameSword = "slash",
	dagger = "thrust",
	spear2h = "thrust",
	club = "overhead",
	cleaver = "overhead",
	smithHammer = "overhead",
	hammer2h = "overhead2",
	axe2h = "overhead2",
	iceClub = "overhead2",
	pickaxe = "overhead2",
	scythe = "wide",
	staff = "cast",
	skullStaff = "cast",
	broom = "cast",
}

local DEATH: { [string]: DeathStyle } = {
	-- rolls onto its side (the seed picks left or right), the legs stiffen
	side = death({
		pose = {
			body = P(0, 0, 1.5, 0, -0.45, 0),
			leg = P(0.35, 0, 0.25, 0, 0, 0),
			head = P(-0.3, 0, 0, 0, 0, 0),
			jaw = P(-0.35, 0, 0, 0, 0, 0),
			tail = P(0.3, 0, 0, 0, 0, 0),
			segment = P(-0.1, 0, 0, 0, 0, 0),
		},
		flip = "rz",
	}),
	-- flattens and sinks a little, the legs splay
	flat = death({
		pose = {
			body = P(-0.1, 0, 0, 0, -0.35, 0),
			leg = P(0, 0, 0.9, 0, 0, 0),
			head = P(-0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.3, 0, 0, 0, 0, 0),
		},
	}),
	-- the legs fold under, the body sinks
	curl = death({
		pose = {
			body = P(0.1, 0, 0, 0, -0.5, 0),
			spiderLeg = P(0, 0, -0.8, 0, 0, 0),
			claw = P(0.3, 0, 0, 0, 0, 0),
			arm = P(-0.3, 0, 0, 0, 0, 0),
			sting = P(0.5, 0, 0, 0, 0, 0),
			jaw = P(0.2, 0, 0, 0, 0, 0),
		},
	}),
	-- fliers drop to the ground (hover height) with the wings folded and roll a little
	fall = death({
		pose = {
			body = P(-0.2, 0, 1.2, 0, -0.4, 0),
			flap = P(0, 0, -0.9, 0, 0, 0),
			head = P(-0.4, 0, 0, 0, 0, 0),
			leg = P(0.3, 0, 0, 0, 0, 0),
		},
		flip = "rz",
		hoverDrop = true,
	}),
	-- the wave dies down, the front drops
	coil = death({
		pose = {
			body = P(-0.1, 0, 0.6, 0, -0.3, 0),
			head = P(-0.6, 0, 0, 0, 0, 0),
			jaw = P(-0.4, 0, 0, 0, 0, 0),
			segment = P(-0.15, 0, 0, 0, 0, 0),
			flap = P(0, 0, -0.6, 0, 0, 0),
		},
		flip = "rz",
	}),
	-- dragons: the wings fold, then the roll
	dragon = death({
		pose = {
			body = P(0, 0, 1.3, 0, -0.5, 0),
			flap = P(0, 0, -0.9, 0, 0, 0),
			head = P(-0.5, 0, 0, 0, 0, 0),
			jaw = P(-0.5, 0, 0, 0, 0, 0),
			tail = P(0.2, 0, 0, 0, 0, 0),
			leg = P(0.3, 0, 0, 0, 0, 0),
		},
		flip = "rz",
	}),
	-- two legs: down on the knees first, then over forwards or backwards
	knees = death({
		early = {
			body = P(0.1, 0, 0, 0, -0.8, 0),
			leg = P(-0.6, 0, 0, 0, 0, 0),
			arm = P(0.3, 0, 0.1, 0, 0, 0),
			head = P(-0.3, 0, 0, 0, 0, 0),
		},
		pose = {
			body = P(1.3, 0, 0, 0, -1.0, 0),
			leg = P(-0.9, 0, 0, 0, 0, 0),
			arm = P(0.6, 0, 0.4, 0, 0, 0),
			head = P(-0.4, 0, 0, 0, 0, 0),
			jaw = P(-0.35, 0, 0, 0, 0, 0),
			flap = P(0, 0, -0.6, 0, 0, 0),
		},
		split = 0.45,
		flip = "rx",
	}),
	-- golems and treants: collapse in place with a tilt, no roll
	crumble = death({
		pose = {
			body = P(-0.25, 0, 0.2, 0, -0.9, 0),
			arm = P(-0.3, 0, 0.6, 0, 0, 0),
			head = P(-0.6, 0, 0, 0, 0, 0),
			leg = P(0, 0, 0.5, 0, 0, 0),
		},
		flip = "rz",
	}),
	-- spirits: rise a little and fade (MonsterViewController fades every corpse)
	dissolve = death({
		pose = {
			body = P(0.2, 0, 0, 0, 1.5, 0),
			arm = P(0.4, 0, 0.7, 0, 0, 0),
			head = P(0.4, 0, 0, 0, 0, 0),
		},
	}),
}

local MonsterMotions = {
	STYLES = STYLES,
	PLANS = PLANS,
	KIT_STYLES = KIT_STYLES,
	RANGED = RANGED,
	WEAPON_BASIC = WEAPON_BASIC,
	DEATH = DEATH,
}

-- The style of an attack: an Elite II special (`abilityId`) -> PLANS[plan].special[abilityId], KIT_STYLES (S134e) or
-- special.default; a regular attack -> WEAPON_BASIC[weapon] for humanoids and beasts with a weapon, else
-- PLANS[plan].basic. Nil for a plan without an entry.
function MonsterMotions.styleFor(plan: string, weapon: string?, abilityId: string?): string?
	local entry = PLANS[plan]
	if not entry then
		return nil
	end
	if abilityId then
		local kit = KIT_STYLES[plan]
		return entry.special[abilityId] or (kit and kit[abilityId]) or entry.special.default
	end
	if weapon and (plan == "humanoid" or plan == "beast") and WEAPON_BASIC[weapon] then
		return WEAPON_BASIC[weapon]
	end
	return entry.basic
end

-- S159g: the style of the draw before a regular ranged blow (`shot` "arrow" / "bolt" / "throw"): RANGED[plan][shot],
-- else the plan's basic style. Nil for a plan without an entry.
function MonsterMotions.rangedFor(plan: string, weapon: string?, shot: string): string?
	local own = RANGED[plan]
	return (own and own[shot]) or MonsterMotions.styleFor(plan, weapon, nil)
end

-- The death style of a plan (nil for a plan without an entry).
function MonsterMotions.deathFor(plan: string): string?
	local entry = PLANS[plan]
	return if entry then entry.death else nil
end

return MonsterMotions
