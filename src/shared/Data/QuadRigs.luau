--!strict
-- Template animation (owner 2026-10-25, docs/ANIM-WZORCE.md F2): the bone roles of each imported quadruped model
-- (ReplicatedStorage.Assets.Monsters.<model>, Tripo Auto Rig, no clips) that Logic/QuadMotion drives. Tripo rigs differ
-- per model (bone names, missing lower legs), so the map is written per model after the rig audit (§1.9).
-- * `body`: the bone that carries the whole model (bob, pitch, roll, the death roll);
-- * `spine`: bones from the pelvis to the chest with their share of the flex and the side bend;
-- * `neck` and `head`: shares of the neck's pitch / yaw, then the head's own turn; `jaw`, `ears` if they exist;
-- * `tail`: from the base out (the wave runs down it with a lag);
-- * `legs` FL FR HL HR: each joint of the leg with the motion it takes: `swing` share of the leg's forward swing,
--   `fold` sign and share of the leg's fold (the joints of a front leg fold back, a hind knee back and the hock forward),
--   `paw` share of the paw's curl. A leg with fewer joints (a hind leg cut short by the export) simply has fewer rows.
-- Pitch is a turn about the model's side axis, + swings a limb forward (its lower end toward the front).

export type Joint = { bone: string, swing: number?, fold: number?, paw: number?, spread: number? }
export type Rig = {
	body: string,
	spine: { { bone: string, share: number } },
	neck: { { bone: string, share: number } },
	head: string,
	jaw: { bone: string, sign: number }?,
	ears: { L: string?, R: string? }?,
	tail: { string },
	legs: { [string]: { Joint } },
}

local RIGS: { [string]: Rig } = {
	-- wolf (also iceWolf): front legs scapula / shoulder / elbow / wrist / paw; the left hind leg hip / knee / hock,
	-- the right hind leg only hip / knee (the export dropped its lower bones: the mesh below follows the knee)
	wolf = {
		body = "tripo::Root",
		spine = {
			{ bone = "tripo::Spine_0", share = 0.3 },
			{ bone = "tripo::Spine_1", share = 0.35 },
			{ bone = "tripo::Spine_2", share = 0.35 },
		},
		neck = { { bone = "tripo::Head_0", share = 0.55 }, { bone = "tripo::Head_1", share = 0.45 } },
		head = "tripo::Head_2",
		jaw = { bone = "bone_13", sign = 1 },
		ears = { L = "bone_11", R = "bone_12" },
		tail = { "bone_1", "bone_2", "tripo::Tail_0", "tripo::Tail_1" },
		legs = {
			FL = {
				{ bone = "bone_16", swing = 0.25 },
				{ bone = "tripo::0_Left_Limb_0", swing = 0.75, fold = 0.35, spread = 1 },
				{ bone = "tripo::0_Left_Limb_1", fold = -1 },
				{ bone = "tripo::0_Left_Limb_2", fold = 0.85 },
				{ bone = "tripo::0_Left_Limb_3", paw = 1 },
			},
			FR = {
				{ bone = "bone_21", swing = 0.25 },
				{ bone = "tripo::0_Right_Limb_0", swing = 0.75, fold = 0.35, spread = 1 },
				{ bone = "tripo::0_Right_Limb_1", fold = -1 },
				{ bone = "tripo::0_Right_Limb_2", fold = 0.85 },
				{ bone = "tripo::0_Right_Limb_3", paw = 1 },
			},
			HL = {
				{ bone = "bone_28", swing = 1, fold = 0.3, spread = 1 },
				{ bone = "bone_29", fold = -1 },
				{ bone = "bone_30", fold = 0.9, paw = 1 },
			},
			HR = {
				{ bone = "tripo::1_Right_Limb_0", swing = 1, fold = 0.3, spread = 1 },
				{ bone = "tripo::1_Right_Limb_1", fold = -0.45, paw = 0.5 },
			},
		},
	},
	-- waste hyena: the export named the bones oddly (the chest chain is 0_Right_Limb_0..3, the rear chain Spine_0..1);
	-- front legs from the neck's base, hind legs from the rear spine, the right hind leg without its paw bone
	wasteHyena = {
		body = "tripo::Root",
		spine = {
			{ bone = "tripo::0_Right_Limb_0", share = 0.25 },
			{ bone = "tripo::0_Right_Limb_1", share = 0.25 },
			{ bone = "tripo::0_Right_Limb_2", share = 0.25 },
			{ bone = "tripo::0_Right_Limb_3", share = 0.25 },
		},
		neck = { { bone = "tripo::Head_0", share = 0.5 }, { bone = "tripo::Head_1", share = 0.5 } },
		head = "tripo::Head_2",
		jaw = { bone = "tripo::Head_3", sign = 1 },
		ears = { L = "bone_9", R = "bone_10" },
		tail = { "tripo::Tail_0", "tripo::Tail_1", "tripo::Tail_2", "tripo::Tail_3" },
		legs = {
			FL = {
				{ bone = "bone_11", swing = 0.25 },
				{ bone = "bone_12", swing = 0.75, fold = 0.35, spread = 1 },
				{ bone = "bone_13", fold = -1 },
				{ bone = "bone_14", fold = 0.85 },
				{ bone = "bone_15", paw = 1 },
			},
			FR = {
				{ bone = "bone_16", swing = 0.25 },
				{ bone = "bone_17", swing = 0.75, fold = 0.35, spread = 1 },
				{ bone = "bone_18", fold = -1 },
				{ bone = "bone_19", fold = 0.85 },
				{ bone = "bone_20", paw = 1 },
			},
			HL = {
				{ bone = "bone_27", swing = 0.3 },
				{ bone = "tripo::0_Left_Limb_0", swing = 0.7, fold = 0.3, spread = 1 },
				{ bone = "tripo::0_Left_Limb_1", fold = -1 },
				{ bone = "tripo::0_Left_Limb_2", fold = 0.9 },
				{ bone = "tripo::0_Left_Limb_3", paw = 1 },
			},
			HR = {
				{ bone = "bone_32", swing = 0.3 },
				{ bone = "tripo::1_Left_Limb_0", swing = 0.7, fold = 0.3, spread = 1 },
				{ bone = "tripo::1_Left_Limb_1", fold = -1 },
				{ bone = "tripo::1_Left_Limb_2", fold = 0.9, paw = 0.5 },
			},
		},
	},
}

local QuadRigs = {}

function QuadRigs.get(model: string): Rig?
	return RIGS[model]
end

return QuadRigs
