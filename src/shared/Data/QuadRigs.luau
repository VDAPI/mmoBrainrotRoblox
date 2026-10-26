--!strict
-- Template animation (owner 2026-10-25, docs/ANIM-WZORCE.md F2): the bone roles of each imported quadruped model
-- (ReplicatedStorage.Assets.Monsters.<model>, Tripo Auto Rig, no clips) that Logic/QuadMotion drives. Tripo rigs differ
-- per model (bone names, missing lower legs), so the map is written per model after the rig audit (§1.9).
-- * `body`: the bone that carries the whole model (bob, pitch, roll, the death roll);
-- * `spine`: bones from the pelvis to the chest with their share of the flex and the side bend;
-- * `neck` and `head`: shares of the neck's pitch / yaw, then the head's own turn; `jaw`, `ears` if they exist;
-- * `tail`: from the base out (the wave runs down it with a lag);
-- * `legs` FL FR HL HR: each joint of the leg with the motion it takes: `swing` share of the leg's forward swing,
--   `fold` sign and share of the leg's fold (the joints of a front leg fold back, a hind knee back and the hock forward;
--   the signs follow the export's rest bends so a positive fold lifts the foot: the bear's and the boar's elbows are
--   the wolf's reversed),
--   `paw` share of the paw's curl. A leg with fewer joints (a hind leg cut short by the export) simply has fewer rows.
--   `level`: the foot of a plantigrade leg, kept flat on the ground in stance (Logic/QuadPose control <leg>l);
--   `tip` on the last bone when it carries the foot below its joint (a forearm without a paw bone): the foot's point
--   for planted feet;
-- * `trunk` (a mammoth's): from the root to the tip; `ears.axis` "yaw": ears that flap out instead of folding back;
-- * no `neck` rows: the head bone takes the neck's turn too.
-- Pitch is a turn about the model's side axis, + swings a limb forward (its lower end toward the front).
-- The models after the wolf were mapped from the Studio rig dump (tools/anim/rigs/<model>.json, 2026-10-26; positions
-- in the model frame, feet at y = 0) and checked by forward kinematics in tests/quadheavy.spec.luau.

export type Joint = {
	bone: string,
	swing: number?,
	fold: number?,
	paw: number?,
	spread: number?,
	level: boolean?,
	tip: { number }?, -- the last bone only: where its tip (the foot) is from its joint, in leg lengths
}
export type Rig = {
	body: string,
	spine: { { bone: string, share: number } },
	neck: { { bone: string, share: number } },
	head: string,
	jaw: { bone: string, sign: number }?,
	ears: { L: string?, R: string?, axis: string? }?,
	tail: { string },
	trunk: { string }?,
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
	-- brown bear (also blackBear): the pelvis bone carries the hind legs and the stub tail, the spine runs to the chest
	-- bone that carries the head (one bone: no neck chain, no jaw, no ears) and both fore legs; the left fore leg is
	-- shoulder / elbow, the right one hangs from a scapula bone (left still) with shoulder / elbow; the forearms carry
	-- the fore paws (no wrist bones). Hind legs hip / knee / ankle / toes, the foot kept flat (plantigrade).
	-- The skeleton's front half sits ~13 degrees to its left in the file (head and shoulders turned).
	brownBear = {
		body = "tripo::Root",
		spine = { { bone = "tripo::Spine_0", share = 0.55 }, { bone = "tripo::Head_0", share = 0.45 } },
		neck = {},
		head = "bone_13",
		tail = { "bone_10" },
		legs = {
			-- the paw's tip on the forearms is a guess from the elbows' height (Studio: tune it so the planted paws
			-- stay put)
			FL = {
				{ bone = "bone_14", swing = 1, fold = -0.5, spread = 1 },
				{ bone = "tripo::0_Left_Limb_0", fold = 1, tip = { 0, -0.51, -0.12 } },
			},
			FR = {
				{ bone = "tripo::Head_2", swing = 1, fold = -0.5, spread = 1 },
				{ bone = "tripo::0_Right_Limb_0", fold = 1, tip = { 0, -0.57, -0.12 } },
			},
			HL = {
				{ bone = "tripo::1_Left_Limb_0", swing = 1, fold = 0.35, spread = 1 },
				{ bone = "tripo::1_Left_Limb_1", fold = -1 },
				{ bone = "tripo::1_Left_Limb_2", fold = 0.65, level = true },
				{ bone = "tripo::1_Left_Limb_3", paw = 1 },
			},
			HR = {
				{ bone = "tripo::1_Right_Limb_0", swing = 1, fold = 0.35, spread = 1 },
				{ bone = "tripo::1_Right_Limb_1", fold = -1 },
				{ bone = "tripo::1_Right_Limb_2", fold = 0.65, level = true },
				{ bone = "tripo::1_Right_Limb_3", paw = 1 },
			},
		},
	},
	-- boar: the export named the back chain Head_0..2 (Head_0 carries the hind legs, Head_2 at the withers the fore
	-- legs through two collar bones), Head_3 is the head with the snout (Head_4) on it: no neck chain, no jaw, no ears.
	-- Fore legs collar / shoulder / elbow / knee / hoof, hind legs hip / stifle / hock / fetlock / hoof; the tail hangs
	-- from a rump chain (Spine_0..1, still)
	boar = {
		body = "tripo::Root",
		spine = { { bone = "tripo::Head_1", share = 0.5 }, { bone = "tripo::Head_2", share = 0.5 } },
		neck = {},
		head = "tripo::Head_3",
		tail = { "tripo::Tail_0", "tripo::Tail_1", "tripo::Tail_2", "tripo::Tail_3" },
		legs = {
			FL = {
				{ bone = "bone_6", swing = 0.2 },
				{ bone = "tripo::0_Left_Limb_0", swing = 0.8, fold = -0.3, spread = 1 },
				{ bone = "tripo::0_Left_Limb_1", fold = 1 },
				{ bone = "tripo::0_Left_Limb_2", fold = -1 },
				{ bone = "tripo::0_Left_Limb_3", paw = 1 },
			},
			FR = {
				{ bone = "bone_11", swing = 0.2 },
				{ bone = "tripo::0_Right_Limb_0", swing = 0.8, fold = -0.3, spread = 1 },
				{ bone = "tripo::0_Right_Limb_1", fold = 1 },
				{ bone = "tripo::0_Right_Limb_2", fold = -1 },
				{ bone = "tripo::0_Right_Limb_3", paw = 1 },
			},
			HL = {
				{ bone = "tripo::1_Left_Limb_0", swing = 1, fold = 0.3, spread = 1 },
				{ bone = "tripo::1_Left_Limb_1", fold = -1 },
				{ bone = "tripo::1_Left_Limb_2", fold = 0.9 },
				{ bone = "tripo::1_Left_Limb_3", fold = -0.2 },
				{ bone = "tripo::1_Left_Limb_4", paw = 1 },
			},
			HR = {
				{ bone = "tripo::1_Right_Limb_0", swing = 1, fold = 0.3, spread = 1 },
				{ bone = "tripo::1_Right_Limb_1", fold = -1 },
				{ bone = "tripo::1_Right_Limb_2", fold = 0.9 },
				{ bone = "tripo::1_Right_Limb_3", fold = -0.2 },
				{ bone = "tripo::1_Right_Limb_4", paw = 1 },
			},
		},
	},
	-- ice mammoth: spine Spine_0..1 to the withers (Head_0, which carries the fore legs), neck Head_1, head Head_2, the
	-- trunk Head_3..9 hanging from the face, one ear bone (the left; the right ear is skinned to the head), two stub
	-- tail bones on the root, the hind legs on the root. Pillar legs shoulder / elbow / wrist / foot and hip / knee /
	-- hock / foot, the feet kept flat.
	iceMammoth = {
		body = "tripo::Root",
		spine = {
			{ bone = "tripo::Spine_0", share = 0.35 },
			{ bone = "tripo::Spine_1", share = 0.35 },
			{ bone = "tripo::Head_0", share = 0.3 },
		},
		neck = { { bone = "tripo::Head_1", share = 1 } },
		head = "tripo::Head_2",
		ears = { L = "bone_13", axis = "yaw" },
		tail = { "bone_23", "bone_32" },
		trunk = {
			"tripo::Head_3",
			"tripo::Head_4",
			"tripo::Head_5",
			"tripo::Head_6",
			"tripo::Head_7",
			"tripo::Head_8",
			"tripo::Head_9",
		},
		legs = {
			FL = {
				{ bone = "tripo::0_Left_Limb_0", swing = 1, fold = 0.3, spread = 1 },
				{ bone = "tripo::0_Left_Limb_1", fold = -0.6 },
				{ bone = "tripo::0_Left_Limb_2", fold = -0.4, level = true },
				{ bone = "tripo::0_Left_Limb_3", paw = 1 },
			},
			FR = {
				{ bone = "tripo::0_Right_Limb_0", swing = 1, fold = 0.3, spread = 1 },
				{ bone = "tripo::0_Right_Limb_1", fold = -0.6 },
				{ bone = "tripo::0_Right_Limb_2", fold = -0.4, level = true },
				{ bone = "tripo::0_Right_Limb_3", paw = 1 },
			},
			HL = {
				{ bone = "tripo::1_Left_Limb_0", swing = 1, fold = 0.3, spread = 1 },
				{ bone = "tripo::1_Left_Limb_1", fold = -1 },
				{ bone = "tripo::1_Left_Limb_2", fold = 0.7, level = true },
				{ bone = "tripo::1_Left_Limb_3", paw = 1 },
			},
			HR = {
				{ bone = "tripo::1_Right_Limb_0", swing = 1, fold = 0.3, spread = 1 },
				{ bone = "tripo::1_Right_Limb_1", fold = -1 },
				{ bone = "tripo::1_Right_Limb_2", fold = 0.7, level = true },
				{ bone = "tripo::1_Right_Limb_3", paw = 1 },
			},
		},
	},
}

local QuadRigs = {}

function QuadRigs.get(model: string): Rig?
	return RIGS[model]
end

return QuadRigs
