--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE.md F3): the bone roles of each imported flyer model
-- (ReplicatedStorage.Assets.Monsters.<model>, Tripo Auto Rig, no clips) that Logic/FlyerMotion drives, written from the
-- rig dump (tools/anim/rigs/<model>.json: positions in the model frame, feet at y = 0, the look's root 2.5 below).
-- * `body`: the bone that carries the whole model; `facing`: degrees the export is turned to its left of -Z (the body
--   bone turns it back, so the bird flies the way its root faces); `centre`: bones whose mean (x, z) is put over the
--   root and whose mean height is the pivot of the body's pitch and roll; `restHeight`: the body bone's height over the
--   look's root in dump units (the ratio to the clone's gives the model's scale); `half`: half the body's width (dump
--   units: how high its centre lies when it lies on its side); `carriage`: body pitch added to the export's pose so it
--   hovers as a flying body (rad, + nose up);
-- * `spine` (pelvis to chest), `neck` with their shares of the pitch and turn, `head`, `tail` (base out), `fan` (tail
--   feathers spread to the sides, centre first);
-- * `legs` L / R: each joint with its share of the thigh's `swing` (+ the foot forward), the `fold` sign and share
--   (a positive fold closes the joint the way a bird tucks its leg: the vulture's tarsus trails back, the harpy's knee
--   bends back and its ankle forward) and the toes' `curl` sign (+ the tips toward the sole);
-- * `wings` L / R (nil: the export has no wing bones, the wingbeat layer stays off): `clav` (optional shoulder blade),
--   `humerus`, `forearm`, `hand`, `primaries` (optional), `tip` (a leaf at the wing's end, else extrapolated);
--   `pin`: the bone the wing's root hangs from as far as its position goes (Tripo hung the harpy's wings from the
--   head; they follow the chest instead); `dorsal`: the direction the top of the wing faces at rest (root axes after
--   `facing`), so the membrane lies flat when the wing spreads;
-- * `muzzle`: where shots leave: the mean of the `at` bones, plus `ahead` (toward -Z) and `up` at rest (dump units),
--   carried by the turn of `at[1]` (client/Anim/FlyerRig moves the root's Muzzle attachment there every frame).
-- A Tripo Avian re-rig only needs its new map here: the wingbeat switches on for any model whose map lists wings.

export type Leg = { bone: string, swing: number?, fold: number?, curl: number? }
export type Wing = {
	clav: string?,
	humerus: string,
	forearm: string,
	hand: string,
	primaries: string?,
	tip: string?,
	pin: string?,
	dorsal: { number },
}
export type Rig = {
	body: string,
	facing: number,
	centre: { string },
	restHeight: number,
	half: number,
	carriage: number,
	spine: { { bone: string, share: number } },
	neck: { { bone: string, share: number } },
	head: string,
	tail: { string },
	fan: { string }?,
	legs: { [string]: { Leg } },
	wings: { [string]: Wing }?,
	muzzle: { at: { string }, ahead: number?, up: number? },
}

local RIGS: { [string]: Rig } = {
	-- ash vulture (18 bones): the chest Spine_0 carries the neck Head_0 and the head Head_1 (two zero-length leaves at the
	-- neck's base stay); bone_6 / bone_10 run from the pelvis to the hips, each leg thigh / tarsus / toes; bone_14 is the
	-- tail with three feather leaves. No wing bones: the wings are skinned to the body (docs/ANIM-WZORCE §4.5 re-rig)
	ashVulture = {
		body = "tripo::Root",
		facing = 31,
		centre = { "tripo::Spine_0", "tripo::0_Left_Limb_0", "tripo::0_Right_Limb_0" },
		restHeight = 2.73,
		half = 0.5,
		carriage = math.rad(-4),
		spine = { { bone = "tripo::Spine_0", share = 1 } },
		neck = { { bone = "tripo::Head_0", share = 1 } },
		head = "tripo::Head_1",
		tail = { "bone_14" },
		fan = { "bone_16", "bone_15", "bone_17" },
		legs = {
			L = {
				{ bone = "tripo::0_Left_Limb_0", swing = 1 },
				{ bone = "tripo::0_Left_Limb_1", fold = -1 },
				{ bone = "tripo::0_Left_Limb_2", curl = -1 },
			},
			R = {
				{ bone = "tripo::0_Right_Limb_0", swing = 1 },
				{ bone = "tripo::0_Right_Limb_1", fold = -1 },
				{ bone = "tripo::0_Right_Limb_2", curl = -1 },
			},
		},
		wings = nil,
		-- the beak's tip, about 0.3 ahead of the head bone
		muzzle = { at = { "tripo::Head_1" }, ahead = 0.3, up = -0.04 },
	},
	-- peak harpy (32 bones): Spine_0 / Spine_1 the back and chest, Head_0 the neck, Head_1 the head; Tripo hung both wings
	-- from the head (right: shoulder blade bone_6 under Head_1; left: Head_2, really the left shoulder blade), so they are
	-- pinned to the chest. The wings rest raised (heraldic), the primaries hanging; legs thigh / shin / tarsus / toes;
	-- tail bone_28..30
	peakHarpy = {
		body = "tripo::Root",
		facing = 39.5,
		centre = { "tripo::Spine_0", "tripo::Spine_1", "tripo::0_Left_Limb_0", "tripo::0_Right_Limb_0" },
		restHeight = 2.61,
		half = 0.42,
		carriage = 0,
		spine = { { bone = "tripo::Spine_0", share = 0.45 }, { bone = "tripo::Spine_1", share = 0.55 } },
		neck = { { bone = "tripo::Head_0", share = 1 } },
		head = "tripo::Head_1",
		tail = { "bone_28", "bone_29", "bone_30" },
		fan = nil,
		legs = {
			L = {
				{ bone = "tripo::0_Left_Limb_0", swing = 1 },
				{ bone = "tripo::0_Left_Limb_1", fold = -1 },
				{ bone = "tripo::0_Left_Limb_2", fold = 1 },
				{ bone = "tripo::0_Left_Limb_3", curl = -1 },
			},
			R = {
				{ bone = "tripo::0_Right_Limb_0", swing = 1 },
				{ bone = "tripo::0_Right_Limb_1", fold = -1 },
				{ bone = "tripo::0_Right_Limb_2", fold = 1 },
				{ bone = "tripo::0_Right_Limb_3", curl = -1 },
			},
		},
		wings = {
			R = {
				clav = "bone_6",
				humerus = "bone_7",
				forearm = "bone_8",
				hand = "bone_9",
				primaries = "bone_10",
				tip = "bone_11",
				pin = "tripo::Spine_1",
				dorsal = { 0, 0, 1 },
			},
			L = {
				clav = "tripo::Head_2",
				humerus = "bone_13",
				forearm = "bone_14",
				hand = "bone_15",
				primaries = "bone_16",
				tip = "bone_17",
				pin = "tripo::Spine_1",
				dorsal = { 0, 0, 1 },
			},
		},
		-- the lightning leaves between the two wing tips (flung forward at the release)
		muzzle = { at = { "bone_11", "bone_17" } },
	},
}

local FlyerRigs = {}

function FlyerRigs.get(model: string): Rig?
	return RIGS[model]
end

return FlyerRigs
