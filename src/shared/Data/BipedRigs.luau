--!strict
-- Template animation (owner 2026-10-26): the imported bipeds whose bones client/Anim/BipedRig cannot take by their
-- names alone (Mixamo, Tripo biped aliases), by model, written from the rig dump (tools/anim/rigs/<model>.json). Without
-- an entry a model keeps the name rules.
-- * `bones`: Logic/BipedPose key -> the model's bone name, over the name rules;
-- * `virtual`: keys the model has no usable bone for (missing, or misplaced by the auto rig): a point at the rest
--   position of key `from` plus `offset` (dump units, root axes). The pose still solves them (the legs' IK, the scale
--   of a biped's distances) but nothing is written; bones of the model under them keep following their parents;
-- * `drop`: keys left out (their bones follow their parents);
-- * `unit`: a bone and its height over the look's root in the dump (dump units -> studs of the clone);
-- * `pivot`: the bone whose joint the body (Hips) turns about instead of its own (a Tripo root at the ground under
--   the pelvis), moved by `pivotOffset` (dump units); `legPlane`: the knees keep the rest legs' own plane (splayed);
-- * `muzzle`: the root's Muzzle attachment follows this key's bone (the point `offset` from its joint at rest, dump
--   units, root axes), so the shots drawn on the client leave the jaw or the casting hand (docs/ANIM-WZORCE §10);
-- * `tuck`: bones outside the pose turned once by `angle` (rad) about `axis` (root axes) at their rest and then left
--   to follow their parents (the regular wyvern's small forearms folded against the chest);
-- * `facing`: degrees the export stands turned to its left of -Z (Grimrok 40, Azgor -18: their hips, shoulders and feet
--   all turned alike), `centre`: its body stands off the root (Azgor's sword widens the box it was centred by). The
--   pose is solved on the model turned to face -Z with its Hips joint over the root, and the Hips' Transform carries
--   the correction (Logic/BipedPose.hipsFixed).

local BipedRigs = {}

-- The name rules: bone names of other biped exports (Tripo Auto Rig Biped on dragons: Vaelgrath) onto the Mixamo keys
-- the pose drives (Logic/BipedPose.KEYS; a Mixamo prefix is dropped); the bones between them (Pelvis, NeckTwist02) keep
-- their rest and follow their parents.
local ALIASES: { [string]: string } = {
	Hip = "Hips",
	Waist = "Spine",
	Spine01 = "Spine1",
	Spine02 = "Spine2",
	NeckTwist01 = "Neck",
	L_Thigh = "LeftUpLeg",
	L_Calf = "LeftLeg",
	L_Foot = "LeftFoot",
	L_ToeBase = "LeftToeBase",
	R_Thigh = "RightUpLeg",
	R_Calf = "RightLeg",
	R_Foot = "RightFoot",
	R_ToeBase = "RightToeBase",
	L_Clavicle = "LeftShoulder",
	L_Upperarm = "LeftArm",
	L_Forearm = "LeftForeArm",
	L_Hand = "LeftHand",
	R_Clavicle = "RightShoulder",
	R_Upperarm = "RightArm",
	R_Forearm = "RightForeArm",
	R_Hand = "RightHand",
}

-- The pose key of a bone by the name rules.
function BipedRigs.keyOf(name: string): string
	local bare = string.match(name, "[^:]*$") or name
	return ALIASES[bare] or bare
end

export type Virtual = { from: string, offset: { number } }
export type Map = {
	bones: { [string]: string }?,
	virtual: { [string]: Virtual }?,
	drop: { string }?,
	unit: { bone: string, height: number },
	pivot: string?,
	pivotOffset: { number }?,
	legPlane: boolean?, -- the knees bend in the rest legs' own plane (splayed legs), Logic/BipedPose.Options
	muzzle: { key: string, offset: { number } }?,
	tuck: { { bone: string, axis: { number }, angle: number } }?,
	facing: number?,
	centre: boolean?,
}

local MAPS: { [string]: Map } = {
	-- the regular wyvern (Tripo Auto Rig, 71 bones, front -Z, standing on its root): the spine hangs from the root, the
	-- pelvis bone_1 carries the legs and the tail, so the root is the Hips turned about the pelvis. Legs: hip bone_2 /
	-- bone_12, knee bone_3 / bone_13, the hock bone_4 / bone_14 (the IK's ankle; the metatarsus below keeps its slant)
	-- and the toes bone_5 / bone_15. The wings are its arms (shoulder blade bone_59 / bone_48, humerus bone_60 /
	-- bone_50, the wrist bone_61 / bone_51, the long finger bone_65 / bone_55); the small forearms under the chest
	-- (bone_32.., bone_39..) follow the chest. Neck Head_0, head Head_1
	wyvern = {
		bones = {
			Hips = "tripo::Root",
			Spine = "tripo::Spine_0",
			Spine1 = "tripo::Spine_1",
			Spine2 = "tripo::Spine_2",
			Neck = "tripo::Head_0",
			Head = "tripo::Head_1",
			HeadTop_End = "tripo::Head_2",
			LeftShoulder = "bone_59",
			LeftArm = "bone_60",
			LeftForeArm = "bone_61",
			LeftHand = "bone_65",
			LeftHandMiddle1 = "bone_66",
			RightShoulder = "bone_48",
			RightArm = "bone_50",
			RightForeArm = "bone_51",
			RightHand = "bone_55",
			RightHandMiddle1 = "bone_56",
			LeftUpLeg = "bone_2",
			LeftLeg = "bone_3",
			LeftFoot = "bone_4",
			LeftToeBase = "bone_5",
			RightUpLeg = "bone_12",
			RightLeg = "bone_13",
			RightFoot = "bone_14",
			RightToeBase = "bone_15",
		},
		unit = { bone = "tripo::Spine_0", height = 1.16 },
		pivot = "bone_1",
		legPlane = true,
		-- the jaw, ahead of the head bone
		muzzle = { key = "Head", offset = { 0, 0.05, -0.4 } },
		-- the small forearms hang to the ground at rest (and sink into it when it lies on its side): folded forward and up
		-- against the chest at the elbow, the claws curled
		tuck = {
			{ bone = "bone_33", axis = { 1, 0, 0 }, angle = math.rad(75) },
			{ bone = "bone_35", axis = { 1, 0, 0 }, angle = math.rad(60) },
			{ bone = "bone_41", axis = { 1, 0, 0 }, angle = math.rad(75) },
			{ bone = "bone_43", axis = { 1, 0, 0 }, angle = math.rad(60) },
		},
	},
	-- the specter (Mixamo, 48 bones; the look's root 2.5 under the robe's hem): no feet, the robe below the knees. Its
	-- feet are points under the knees; the legs trail as the robe (Logic/SpiritMotion)
	specter = {
		virtual = {
			LeftFoot = { from = "LeftLeg", offset = { 0, -0.8, 0 } },
			RightFoot = { from = "RightLeg", offset = { 0, -0.8, 0 } },
		},
		unit = { bone = "mixamorig:Hips", height = 4.69 },
		muzzle = { key = "RightHand", offset = { 0.05, -0.2, -0.1 } },
	},
	-- the ice elemental (Tripo biped, 55 bones): the auto rig set the legs sideways in the body and the neck and head
	-- under the chest, so only the body, the spine and the arms are driven; the hips turn about the body's middle
	iceElemental = {
		virtual = {
			LeftUpLeg = { from = "Hips", offset = { -0.25, 0, 0 } },
			LeftLeg = { from = "Hips", offset = { -0.25, -0.9, -0.05 } },
			LeftFoot = { from = "Hips", offset = { -0.25, -1.8, 0 } },
			RightUpLeg = { from = "Hips", offset = { 0.25, 0, 0 } },
			RightLeg = { from = "Hips", offset = { 0.25, -0.9, -0.05 } },
			RightFoot = { from = "Hips", offset = { 0.25, -1.8, 0 } },
			Neck = { from = "Spine2", offset = { 0, 0.35, 0 } },
			Head = { from = "Spine2", offset = { 0, 0.6, 0 } },
		},
		drop = { "LeftToeBase", "RightToeBase" },
		unit = { bone = "Hip", height = 4.28 },
		pivot = "Hip",
		pivotOffset = { -0.37, -0.53, -0.13 },
		muzzle = { key = "RightHand", offset = { 0.05, -0.2, -0.05 } },
	},
	-- the bosses (Mixamo, 52 bones each; dumps 2026-10-26). Grimrok's export stands turned 40 degrees to its left (the
	-- hips, the shoulders and the feet alike) and 0.47 ahead of its root; Azgor's 18 degrees to its right and 1.07 to
	-- the left of its root (its greatsword reaches far to the right)
	grimrok = {
		unit = { bone = "mixamorig:Hips", height = 1.78 },
		facing = 40,
		centre = true,
	},
	azgor = {
		unit = { bone = "mixamorig:Hips", height = 2.98 },
		facing = -18,
		centre = true,
	},
	-- Morvane's bolts leave her right hand
	morvane = {
		unit = { bone = "mixamorig:Hips", height = 3.89 },
		muzzle = { key = "RightHand", offset = { 0.05, -0.25, -0.1 } },
	},
	-- the young frost dragon (Tripo biped auto rig on a winged dragon, 35 bones; a new model is coming): the legs, the
	-- spine, the neck and the head are usable (the legs splayed); the arm chains run into the wings and the right one is
	-- broken (its hand above the head, its fingers on one point), so the wings stay as modelled, carried by the chest
	youngFrostDragon = {
		virtual = {
			LeftArm = { from = "Spine2", offset = { -0.35, 0.1, 0 } },
			LeftForeArm = { from = "Spine2", offset = { -0.4, -0.35, 0 } },
			LeftHand = { from = "Spine2", offset = { -0.4, -0.75, -0.1 } },
			RightArm = { from = "Spine2", offset = { 0.35, 0.1, 0 } },
			RightForeArm = { from = "Spine2", offset = { 0.4, -0.35, 0 } },
			RightHand = { from = "Spine2", offset = { 0.4, -0.75, -0.1 } },
		},
		drop = { "LeftShoulder", "RightShoulder" },
		unit = { bone = "Hip", height = 1.07 },
		legPlane = true,
		-- the jaw, ahead of the head bone
		muzzle = { key = "Head", offset = { 0, -0.1, -0.7 } },
	},
}

function BipedRigs.get(model: string): Map?
	return MAPS[model]
end

-- A jaw added in code (owner 2026-11-01: Vaelgrath's mouth, modelled open, has no jaw bone): client/Anim/MeshJaw adds
-- a jaw bone under the head bone to the model's skinned mesh (an EditableMesh) and skins the lower jaw to it, found by
-- Logic/JawHinge; the jaw is closed at rest and opens on the actions below. Tunable in Studio without code: what is
-- found (the shares are of the snout: the head bone's joint to the snout's tip, ahead) and how far the jaw opens.
-- * `head`: the pose key of the bone the jaw hangs from (by the map or the name rules);
-- * `headWeight`: a vertex is the head's with at least this share of its skin on the head bone and the bones under it;
--   `grow`: a vertex hanging off the lower jaw (a chin spike, a beard) joins it with at least this share;
-- * `from`: the mouth is looked for in the side view (`cells` cells along the snout) ahead of this share; it is an
--   opening between the upper and the lower jaw at least `gapMin` high over at least `minColumns` cells (a tooth over
--   at most `bridge` cells does not split it; Studio prints the side view when the mouth is not found);
-- * `below`: what hangs off the lower jaw reaches at most this far under its lowest point;
-- * `hinge`: the hinge from the back corner of the mouth: `back` along the snout, `down`;
-- * `blend`: the cheek between the jaws stretches instead of tearing: a vertex's share of the jaw grows from `back`
--   behind the hinge to `front` ahead of it, and from the seam to `seam` under it;
-- * closed: the lower jaw turns up until the teeth tips (from `contact` of the mouth's length forward) would touch,
--   short of that by `margin` at the tip (the teeth never go into each other); `closed` (degrees) overrides the
--   measured turn, at most `maxClosed`;
-- * `actions`: per action of the model's style, the jaw's opening (degrees from closed) at marks of the action's
--   timeline (Data/MotionFx marks: "W" the hit, "A0.35" 35 % into the anticipation, "F0.85", "R1" the end); eased
--   between them, 0 before the first and the last held after it (a dead jaw hangs slack); `rate` (1/s): the drawn jaw
--   follows its target.
export type JawKey = { at: string, open: number }
export type Jaw = {
	head: string,
	headWeight: number,
	grow: number,
	from: number,
	cells: number,
	gapMin: number,
	minColumns: number,
	mouth: { front: number, back: number, y: number }?, -- a seam given by hand when the side view finds none
	bridge: number?,
	below: number,
	hinge: { back: number, down: number },
	blend: { back: number, front: number, seam: number },
	contact: number,
	margin: number,
	closed: number?,
	maxClosed: number,
	rate: number,
	actions: { [string]: { JawKey } },
}

local function key(at: string, open: number): JawKey
	return { at = at, open = open }
end

local JAWS: { [string]: Jaw } = {
	-- Vaelgrath (Tripo biped rig, 55 bones, no map: its bones by the name rules; nothing under the head bone, the mouth
	-- modelled open, the lower jaw one surface with the rest, a spike under the chin). Its style is `wyvern`
	-- (Data/BipedStyles): the bite snaps shut on the hit, the breath opens with the charge and stays open while the
	-- frost streams (Data/MotionFx: W to F0.85), the roar opens wide on its thrust, the death cries out and hangs slack
	vaelgrath = {
		head = "Head",
		headWeight = 0.5,
		grow = 0.2,
		from = 0.1,
		cells = 48,
		gapMin = 0.03,
		minColumns = 6,
		mouth = { front = 0.85, back = 0.35, y = 0.396 }, -- off the map MeshJaw prints (JawHinge)
		below = 0.6,
		hinge = { back = 0.06, down = 0.02 },
		blend = { back = 0.12, front = 0.15, seam = 0.08 },
		contact = 0.3,
		margin = 0.02,
		closed = 22, -- (Studio: the given seam is no gap to measure; the teeth meet here)
		maxClosed = 60,
		rate = 24,
		actions = {
			bite = { key("A0.1", 0), key("A1", 30), key("S0.5", 32), key("W", 0) },
			breath = { key("A0.35", 0), key("A1", 10), key("S0.8", 34), key("F0.85", 34), key("R0.6", 6), key("R1", 0) },
			roar = { key("A0.5", 0), key("A1", 14), key("W", 40), key("F1", 36), key("R0.6", 0) },
			heavy = { key("A0.5", 0), key("A1", 14), key("W", 40), key("F1", 36), key("R0.6", 0) },
			deathDragon = { key("A0", 0), key("S1", 34), key("F0.4", 20), key("F1", 12), key("R1", 14) },
		},
	},
}

-- The jaw added to a model's mesh (nil: none; the mouth stays as modelled).
function BipedRigs.jaw(model: string): Jaw?
	return JAWS[model]
end

return BipedRigs
