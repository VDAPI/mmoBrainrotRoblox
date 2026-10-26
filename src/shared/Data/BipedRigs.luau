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
--   to follow their parents (the regular wyvern's small forearms folded against the chest).

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
}

function BipedRigs.get(model: string): Map?
	return MAPS[model]
end

return BipedRigs
