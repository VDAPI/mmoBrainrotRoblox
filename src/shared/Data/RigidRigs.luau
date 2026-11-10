--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE.md F5 §6): the bone chains of a rigid kind whose model does
-- have a skeleton, from the rig dump (tools/anim/rigs/<model>.json). Logic/RigidMotion moves the whole look either way;
-- with these chains a serpent slithers along its own spine (the tail's wave, the neck's sway and strike) and the whole
-- body only follows a little. A model without an entry (or with a bone missing) stays rigid.
-- * `tail`, `coil`: from the base out (the wave travels to the end, growing);
-- * `neck`: from the base to the head (the strike and the sway spread over it);
-- * `head`: the head's own bones (kept level against the neck's pitch).
-- `fold` (owner 2026-10-26: "nogi się nie składają"): a model whose legs curl in on its death although it has no
-- bones; client/Anim/MeshFold bends its mesh (an EditableMesh) by Logic/LegFold, which finds the legs itself:
-- * `open`: the body is what a disc of this share of its own inscribed radius fits in (top view);
-- * `ground`, `reach`: a leg comes this close to the ground (share of the height) and is this long (share of the
--   larger horizontal size); `minLegs`..`maxLegs` found, else the rigid death stays;
-- * `targets`: the folded elevations (degrees in the comments) of the femur, the tibia and the tarsus in the leg's
--   upright plane, going down the curl (-90 straight down, -180 back in under the body, below that up toward it);
-- * `front`: legs pointing within `cone` of forward fold by `mul` (0: the scorpion's pincers stay as they are);
-- * `pace`: each leg's own pace (the curl's exponent within 1 ± pace).
-- `gaze` (owner 2026-11-10: "modele poruszają się nie poruszając głową tak 2d"): the head of a model without bones,
-- found in its one mesh by Logic/NeckBend and hung on a bone that client/Anim/MeshHead adds in code (an EditableMesh,
-- like Vaelgrath's jaw), turned by Logic/HeadGaze. A look whose model has bones never takes it (frostWyrm, the rigged
-- caveSpider, the new crow and bat on the flyer template). Tunable in Studio without code: MeshHead prints what it
-- found once per mesh, with a side and a top view (`H` the head, `+` the bend, `#` the body, `*` the joint).
-- * where the head is: the axis forward, tilted up by `rise` (degrees; 90: straight up); its tip the vertex furthest
--   along it within `mid` of the half-width of the midline; nothing under `floor` of the height (the legs, the feet)
--   and nothing outside `side` of the half-width (the wings, the legs, the pincers; nil: anywhere) is head; the neck
--   is the narrowest section looked for within `seek` (shares of the length along the axis from the tip; nil: none),
--   else the cut lies `neck` from the tip; the share of the head grows over `blend` of the length about the cut; the
--   joint lies `pivot` of the blend's half behind the cut;
-- * how it turns (degrees): `yaw` either way, `up`, `down`; calm glances within `glance` (a bird cocks its head by
--   `tilt`), the sniff's quick nods `sniff`, the nod with the steps `nod`, the flinch of a hit `flinch`; it keeps
--   `steady` of the body's own pitch level (a hop, a rear); `rate` (1/s): how fast it follows what it looks at.

local RigidRigs = {}

export type Fold = {
	open: number,
	ground: number,
	reach: number,
	minLegs: number,
	maxLegs: number,
	targets: { number },
	front: { cone: number, mul: number }?,
	pace: number,
}
export type Gaze = {
	rise: number,
	mid: number,
	floor: number,
	side: number?,
	seek: { number }?,
	neck: number,
	blend: number,
	pivot: number,
	yaw: number,
	up: number,
	down: number,
	glance: number,
	tilt: number,
	sniff: number,
	nod: number,
	flinch: number,
	steady: number,
	rate: number,
}
export type Rig = {
	tail: { string }?,
	coil: { string }?,
	neck: { string }?,
	head: { string }?,
	fold: Fold?,
	gaze: Gaze?,
}

-- A head's numbers: these, with the model's own over them.
local GAZE: Gaze = {
	rise = 20,
	mid = 0.35,
	floor = 0.25,
	side = nil,
	seek = { 0.15, 0.45 },
	neck = 0.3,
	blend = 0.14,
	pivot = 0.6,
	yaw = 30,
	up = 16,
	down = 14,
	glance = 26,
	tilt = 0,
	sniff = 2.5,
	nod = 2.5,
	flinch = 8,
	steady = 0.3,
	rate = 7,
}

local function gaze(over: { [string]: any }): Gaze
	local out = table.clone(GAZE) :: any
	for k, v in over do
		out[k] = v
	end
	if over.seek == false then
		out.seek = nil
	end
	return out :: Gaze
end

local RIGS: { [string]: Rig } = {
	-- frostWyrm (Tripo, 23 bones under RootPart, coiled on the ground): bone_1..5 the coil under the neck, bone_6 and
	-- Head_0..4 the neck rising to y 1.74, Head_5 (Head_6 its tip) the head, Tail_0..8 the spiral of the tail
	frostWyrm = {
		tail = {
			"tripo::Tail_0",
			"tripo::Tail_1",
			"tripo::Tail_2",
			"tripo::Tail_3",
			"tripo::Tail_4",
			"tripo::Tail_5",
			"tripo::Tail_6",
			"tripo::Tail_7",
			"tripo::Tail_8",
		},
		coil = { "bone_1", "bone_2", "bone_3", "bone_4", "bone_5" },
		neck = {
			"bone_6",
			"tripo::Head_0",
			"tripo::Head_1",
			"tripo::Head_2",
			"tripo::Head_3",
			"tripo::Head_4",
		},
		head = { "tripo::Head_5" },
	},
	-- caveSpider (Tripo, one mesh, no bones; 5.06 x 2.35 x 4.61): eight long arched legs (and maybe the palps) curl
	-- under the body: femur -35, tibia -160 (back in under it), tarsus -225 (up toward the belly); on its back they
	-- stand curled over the belly
	caveSpider = {
		fold = {
			open = 0.5,
			ground = 0.12,
			reach = 0.12,
			minLegs = 6,
			maxLegs = 12,
			targets = { math.rad(-35), math.rad(-160), math.rad(-225) },
			pace = 0.3,
		},
		-- the head: the front of the cephalothorax (the eyes, the chelicerae, the palps) between the legs, which stay;
		-- an arachnid barely turns it, it aims its fangs
		gaze = gaze({
			rise = 0,
			mid = 0.12,
			side = 0.16,
			floor = 0.3,
			seek = false,
			neck = 0.16,
			blend = 0.1,
			pivot = 0.3,
			yaw = 12,
			up = 8,
			down = 8,
			glance = 10,
			sniff = 0,
			nod = 1,
			flinch = 5,
			steady = 0.1,
			rate = 6,
		}),
	},
	-- desertScorpion (Tripo, one mesh, no bones; 3.34 x 3.14 x 4.43): eight short legs tuck in under the flat body;
	-- the raised tail never reaches the ground (stays), the pincers point forward (stay)
	desertScorpion = {
		fold = {
			open = 0.5,
			ground = 0.15,
			reach = 0.1,
			minLegs = 6,
			maxLegs = 12,
			targets = { math.rad(-30), math.rad(-150), math.rad(-215) },
			front = { cone = math.rad(35), mul = 0 },
			pace = 0.25,
		},
		-- the head: the front of the prosoma between the pincers (they, the legs and the raised tail stay)
		gaze = gaze({
			rise = 0,
			mid = 0.1,
			side = 0.22,
			floor = 0.05,
			seek = false,
			neck = 0.16,
			blend = 0.1,
			pivot = 0.3,
			yaw = 10,
			up = 8,
			down = 6,
			glance = 8,
			sniff = 0,
			nod = 0.8,
			flinch = 5,
			steady = 0.1,
			rate = 6,
		}),
	},
	-- The models without bones (Tripo, one mesh each; the rig dumps tools/anim/rigs/<model>.json: width x height x
	-- depth) whose head turns on a bone added in code (`gaze`); first guesses, tuned in Studio by the printed views.
	-- rabbit (1.32 x 2.96 x 2.62: tall ears): the head ahead of the chest, the ears with it; a twitchy sniffer that
	-- keeps its head level as it hops
	rabbit = {
		gaze = gaze({
			rise = 15,
			floor = 0.3,
			seek = { 0.15, 0.5 },
			neck = 0.35,
			blend = 0.16,
			yaw = 35,
			up = 18,
			down = 18,
			glance = 30,
			sniff = 4,
			nod = 2,
			flinch = 9,
			steady = 0.4,
			rate = 9,
		}),
	},
	-- lynx (1.83 x 3.61 x 4.07; snowLeopard wears it): the head held high on the neck over long legs
	lynx = {
		gaze = gaze({
			rise = 15,
			floor = 0.4,
			seek = { 0.12, 0.4 },
			neck = 0.28,
			yaw = 35,
			up = 15,
			down = 18,
			glance = 30,
			nod = 3,
		}),
	},
	-- swampToad (2.62 x 2.02 x 2.95): no neck, the head the front of the body: a broad soft bend, a small turn; the
	-- splayed front legs (outside the side band) stay planted
	swampToad = {
		gaze = gaze({
			rise = 10,
			floor = 0.18,
			side = 0.55,
			seek = false,
			neck = 0.36,
			blend = 0.3,
			pivot = 0.3,
			yaw = 14,
			up = 12,
			down = 8,
			glance = 12,
			sniff = 1.5,
			nod = 1.5,
			flinch = 6,
			steady = 0.25,
			rate = 5,
		}),
	},
	-- basilisk (1.78 x 2.04 x 3.12) and salamander (1.22 x 1.71 x 2.15): a low head ahead of the sprawled front legs
	-- (outside the side band); a lizard's head bobs
	basilisk = {
		gaze = gaze({
			rise = 10,
			floor = 0.2,
			side = 0.5,
			seek = { 0.1, 0.4 },
			neck = 0.26,
			yaw = 30,
			up = 15,
			down = 12,
			glance = 24,
			sniff = 2,
			nod = 3,
			steady = 0.2,
			rate = 8,
		}),
	},
	salamander = {
		gaze = gaze({
			rise = 15,
			floor = 0.15,
			side = 0.55,
			seek = { 0.1, 0.4 },
			neck = 0.28,
			yaw = 30,
			up = 15,
			down = 12,
			glance = 24,
			sniff = 2,
			nod = 3,
			steady = 0.2,
			rate = 8,
		}),
	},
	-- bogSerpent (2.13 x 1.6 x 2.13: coiled, the head raised): the raised neck and head over the coil, which stays
	bogSerpent = {
		gaze = gaze({
			rise = 35,
			mid = 0.5,
			floor = 0.4,
			seek = { 0.1, 0.45 },
			neck = 0.32,
			blend = 0.2,
			pivot = 0.5,
			yaw = 30,
			up = 14,
			down = 18,
			sniff = 2,
			nod = 0,
			steady = 0.15,
			rate = 6,
		}),
	},
	-- carrionCrow (1.94 x 1.83 x 1.94) and bloodBat (2.79 x 2.63 x 2.35), the old models (their new exports with wing
	-- bones fly on the flyer template and never take this): the head ahead of the wings, which stay; a crow's head
	-- darts and cocks
	carrionCrow = {
		gaze = gaze({
			rise = 25,
			mid = 0.3,
			side = 0.35,
			floor = 0.4,
			seek = { 0.12, 0.45 },
			neck = 0.3,
			yaw = 45,
			up = 20,
			down = 25,
			glance = 40,
			tilt = 20,
			sniff = 0,
			nod = 2,
			flinch = 9,
			steady = 0.45,
			rate = 11,
		}),
	},
	bloodBat = {
		gaze = gaze({
			rise = 15,
			mid = 0.25,
			side = 0.3,
			floor = 0.25,
			seek = { 0.12, 0.45 },
			neck = 0.3,
			yaw = 35,
			up = 16,
			down = 22,
			glance = 30,
			tilt = 8,
			sniff = 0,
			nod = 1,
			steady = 0.35,
			rate = 9,
		}),
	},
	-- rotEnt (6.29 x 6.88 x 6.78, upright): the crown and the top of the trunk turn on it slowly, the roots stay
	rotEnt = {
		gaze = gaze({
			rise = 90,
			mid = 0.3,
			floor = 0.5,
			seek = false,
			neck = 0.35,
			blend = 0.25,
			pivot = 0.5,
			yaw = 20,
			up = 6,
			down = 10,
			glance = 16,
			tilt = 5,
			sniff = 0,
			nod = 1.5,
			flinch = 4,
			steady = 0.15,
			rate = 3.5,
		}),
	},
}

function RigidRigs.get(model: string): Rig?
	return RIGS[model]
end

-- The leg fold of a model without bones (nil: its death stays rigid).
function RigidRigs.fold(model: string): Fold?
	local rig = RIGS[model]
	return if rig then rig.fold else nil
end

-- The head of a model without bones that turns on a bone added in code (nil: it moves as one piece).
function RigidRigs.gaze(model: string): Gaze?
	local rig = RIGS[model]
	return if rig then rig.gaze else nil
end

-- The models with a `gaze` (sorted).
function RigidRigs.gazes(): { string }
	local out = {}
	for model, rig in RIGS do
		if rig.gaze then
			table.insert(out, model)
		end
	end
	table.sort(out)
	return out
end

return RigidRigs
