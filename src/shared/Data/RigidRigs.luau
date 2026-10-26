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
export type Rig = {
	tail: { string }?,
	coil: { string }?,
	neck: { string }?,
	head: { string }?,
	fold: Fold?,
}

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

return RigidRigs
