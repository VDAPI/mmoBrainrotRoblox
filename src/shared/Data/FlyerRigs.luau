--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE.md F3): the bone roles of each imported flyer model
-- (ReplicatedStorage.Assets.Monsters.<model>, Tripo rigs, no clips) that Logic/FlyerMotion drives, written from the
-- rig dumps (tools/anim/rigs/<model>.json from Studio: the model frame, feet at y = 0, the look's root 2.5 below;
-- <model>_v2.json from the new FBX, 2026-10-31). A model may have several maps (its old and its new export): the first
-- whose bones the model has is used (FlyerRigs.pick), so the old model keeps working until the new one replaces it.
-- Lengths are in dump units: studs of the old template at scale 1 (a v2 map's FBX units times its `k`).
-- * `body`: the bone that carries the whole model; `facing`: degrees the export is turned to its left of -Z (nil:
--   read from the wings' shoulders, so a turned import still flies forward); `level`: degrees the export's body
--   stands nose up from a level flying body (the new exports stand upright with their wings spread: the skeleton is
--   solved in a frame where the body is level, so yaw stays yaw and the wings beat about the body's long axis);
--   `centre`: bones whose mean (x, z) is put over the root and whose mean height is the pivot of the body's pitch and
--   roll; the scale (studs per dump unit): `measure` (the distance of two bones at rest, robust to how the template
--   was placed) or else `restHeight` (the body bone's height over the look's root); `hover`: the centre's height over
--   the ground in old-template studs (nil: as the template's rest has it; FlyerRig passes the clone's scale, so the
--   new model flies as high as the old one whatever its template's size or root); `half`: half the body's width (how
--   high its centre lies when it lies on its side); `carriage`: body pitch added to the export's pose so it hovers as a
--   flying body (rad, + nose up); `pose`: controls always added (the head, tail and legs of an upright export turned
--   to a flying carriage);
-- * `spine` (pelvis to chest), `neck` with their shares of the pitch and turn, `head`, `jaw` (opens with the `jaw`
--   control), `tail` (base out), `fan` (tail feathers spread to the sides, centre first; on `fanBase`, else the tail's
--   last bone);
-- * `legs` L / R: each joint with its share of the thigh's `swing` (+ the foot forward), the `fold` sign and share
--   (a positive fold closes the joint the way a bird tucks its leg: the vulture's tarsus trails back, the harpy's knee
--   bends back and its ankle forward) and the toes' `curl` sign (+ the tips toward the sole);
-- * `wings` L / R (nil: the export has no wing bones, the wingbeat layer stays off): `clav` (optional shoulder blade),
--   `humerus`, `forearm`, `hand`, `primaries` (optional), `tip` (a leaf at the wing's end, else extrapolated);
--   `pin`: the bone the wing's root hangs from as far as its position goes (Tripo hung wings from the head or the
--   neck; they follow the chest instead); `dorsal`: the direction the top of the wing faces at rest (root axes after
--   `facing` and `level`), so the membrane lies flat when the wing spreads; `surface`: the normal of the feathers'
--   plane at rest (the same axes, measured from the skinned mesh) where the arm bones bend out of it, else the plane
--   of the shoulder, the wrist and the tip is the wing's; `fingers`: chains off the hand that fan in
--   the wing's plane with the `n` control (a bat's membrane fingers, a crow's or a vulture's splayed primaries), by
--   their `spread` share (+ back toward the trailing edge);
-- * `follow`: bones Tripo hung from the body or the shoulder blade that belong to a wing (coverts, a trailing feather
--   chain): each takes the turn of the bone `like` by its `share` (1 when nil) and keeps its own pivot;
-- * `muzzle`: where shots leave: the mean of the `at` bones, plus `ahead` (toward -Z) and `up` at rest (dump units),
--   carried by the turn of `at[1]` (client/Anim/FlyerRig moves the root's Muzzle attachment there every frame).

export type Leg = { bone: string, swing: number?, fold: number?, curl: number? }
export type Finger = { bone: string, spread: number }
export type Wing = {
	clav: string?,
	humerus: string,
	forearm: string,
	hand: string,
	primaries: string?,
	tip: string?,
	pin: string?,
	dorsal: { number },
	surface: { number }?,
	fingers: { Finger }?,
}
export type Follow = { bone: string, like: string, share: number? }
export type Rig = {
	id: string,
	body: string,
	facing: number?,
	level: number?,
	centre: { string },
	restHeight: number?,
	measure: { from: string, to: string, length: number }?,
	hover: number?,
	half: number,
	carriage: number,
	pose: { [string]: number }?,
	spine: { { bone: string, share: number } },
	neck: { { bone: string, share: number } },
	head: string,
	jaw: string?,
	tail: { string },
	fan: { string }?,
	fanBase: string?,
	legs: { [string]: { Leg } },
	wings: { [string]: Wing }?,
	follow: { Follow }?,
	muzzle: { at: { string }, ahead: number?, up: number? },
}

local function deg(d: number): number
	return math.rad(d)
end

local OLD: { [string]: Rig } = {
	-- ash vulture (18 bones): the chest Spine_0 carries the neck Head_0 and the head Head_1 (two zero-length leaves at the
	-- neck's base stay); bone_6 / bone_10 run from the pelvis to the hips, each leg thigh / tarsus / toes; bone_14 is the
	-- tail with three feather leaves. No wing bones: the wings are skinned to the body (docs/ANIM-WZORCE §4.5 re-rig)
	ashVulture = {
		id = "ashVulture",
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
		id = "peakHarpy",
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

-- 2026-10-31: the new Tripo exports (tools/anim/rigs/<model>_v2.json, FBX units times `k` below). Each stands upright
-- with its wings spread (`level` lays the body down); Tripo hung one or both wings from the neck or the head (`pin`).

-- ash vulture, new (36 bones, k 4.2: about 4.2 x 1.6 x 2.1 old-template studs): Root -> Left_Limb_0 (the pelvis) ->
-- Spine_0 (the chest) -> Head_0 (the neck) -> Head_1 (the head) -> bone_5 (the beak). The right wing hangs from the chest
-- (shoulder blade bone_20, humerus bone_21, forearm bone_22, hand bone_23, primaries bone_24..25, a trailing feather
-- chain bone_26..27 off the hand); the left one from the neck (bone_7, bone_8..12) with its trailing edge as a separate
-- chain off the shoulder blade (bone_13..16 and the feather tips bone_17..19), which follows the arm bone beside it.
-- Left_Limb_1 -> bone_29 the tail; the left leg Left_Limb_2..5, the right leg one bone (bone_35).
local VULTURE_V2: Rig = {
	id = "ashVulture_v2",
	body = "tripo::Root",
	facing = nil,
	level = 46,
	centre = { "tripo::Spine_0", "tripo::0_Left_Limb_0", "tripo::Head_0" },
	measure = { from = "tripo::Head_0", to = "tripo::0_Left_Limb_2", length = 0.7485 },
	hover = 3.57,
	half = 0.4,
	carriage = deg(6),
	pose = { npitch = deg(10), lLs = deg(35), lRs = deg(35) },
	spine = { { bone = "tripo::0_Left_Limb_0", share = 0.4 }, { bone = "tripo::Spine_0", share = 0.6 } },
	neck = { { bone = "tripo::Head_0", share = 1 } },
	head = "tripo::Head_1",
	jaw = nil,
	tail = { "tripo::0_Left_Limb_1", "bone_29" },
	fan = nil,
	legs = {
		L = {
			{ bone = "tripo::0_Left_Limb_3", swing = 1 },
			{ bone = "tripo::0_Left_Limb_4", fold = -1 },
			{ bone = "tripo::0_Left_Limb_5", curl = -1 },
		},
		R = { { bone = "bone_35", swing = 1 } },
	},
	wings = {
		R = {
			clav = "bone_20",
			humerus = "bone_21",
			forearm = "bone_22",
			hand = "bone_23",
			primaries = "bone_24",
			tip = "bone_25",
			pin = nil,
			dorsal = { 0, 1, 0 },
			surface = { 0.27, 0.96, 0.07 },
			fingers = { { bone = "bone_26", spread = 1 } },
		},
		L = {
			clav = "bone_7",
			humerus = "bone_8",
			forearm = "bone_9",
			hand = "bone_10",
			primaries = "bone_11",
			tip = "bone_12",
			pin = "tripo::Spine_0",
			dorsal = { 0, 1, 0 },
			surface = { -0.19, 0.98, 0.08 },
		},
	},
	follow = {
		{ bone = "bone_13", like = "bone_8" },
		{ bone = "bone_14", like = "bone_8" },
		{ bone = "bone_15", like = "bone_9" },
		{ bone = "bone_16", like = "bone_10" },
	},
	-- the hooked beak's tip
	muzzle = { at = { "bone_5" }, ahead = 0.2, up = 0 },
}

-- carrion crow, new (67 bones, k 3.2: about 3.2 x 1.9 x 1.4): Root (the belly) -> Head_0 (the chest) -> Head_1 (the
-- neck) -> Head_2 / Head_3 (the head and the beak). Both wings hang from the neck: shoulder blade (Spine_0 / bone_6),
-- humerus (bone_22 / bone_7), forearm (bone_23 / bone_8), hand (bone_24 / bone_9), primaries (bone_25..27 /
-- bone_10..12) with more primaries off the hand (bone_28..29 / bone_13..14) and the secondaries off the forearm
-- (bone_32..34 / bone_18..20, kept trailing behind the humerus when the wing folds); the coverts of the inner wing hang
-- from the body (bone_43, bone_53 / bone_35, bone_38, bone_50) and follow the humerus part of the way. Legs Left_Limb_0..3 / Right_Limb_0..2 (short, the toes forward);
-- the tail Tail_0..2 with the side feathers bone_1 (centre), bone_56 / bone_65 (left), bone_59 (right).
local CROW_V2: Rig = {
	id = "carrionCrow_v2",
	body = "tripo::Root",
	facing = nil,
	level = 50,
	centre = { "tripo::Head_0", "tripo::Tail_0", "tripo::0_Left_Limb_0", "tripo::0_Right_Limb_0" },
	measure = { from = "tripo::Head_1", to = "tripo::Tail_0", length = 0.7506 },
	hover = 3.41,
	half = 0.32,
	carriage = deg(10),
	pose = { npitch = deg(25), hpitch = deg(20), tpitch = deg(-12), lLs = deg(40), lRs = deg(40) },
	spine = { { bone = "tripo::Head_0", share = 1 } },
	neck = { { bone = "tripo::Head_1", share = 1 } },
	head = "tripo::Head_2",
	jaw = nil,
	tail = { "tripo::Tail_0", "tripo::Tail_1", "tripo::Tail_2" },
	fan = { "bone_1", "bone_59", "bone_56" },
	fanBase = "tripo::Tail_0",
	legs = {
		L = { { bone = "tripo::0_Left_Limb_0", swing = 1 }, { bone = "tripo::0_Left_Limb_2", curl = -1 } },
		R = { { bone = "tripo::0_Right_Limb_0", swing = 1 }, { bone = "tripo::0_Right_Limb_2", curl = -1 } },
	},
	wings = {
		L = {
			clav = "tripo::Spine_0",
			humerus = "bone_22",
			forearm = "bone_23",
			hand = "bone_24",
			primaries = "bone_25",
			tip = "bone_27",
			pin = "tripo::Head_0",
			dorsal = { 0, 1, 0 },
			surface = { 0.36, 0.93, -0.05 },
			fingers = { { bone = "bone_28", spread = 1 } },
		},
		R = {
			clav = "bone_6",
			humerus = "bone_7",
			forearm = "bone_8",
			hand = "bone_9",
			primaries = "bone_10",
			tip = "bone_12",
			pin = "tripo::Head_0",
			dorsal = { 0, 1, 0 },
			surface = { -0.34, 0.94, -0.06 },
			fingers = { { bone = "bone_13", spread = 1 } },
		},
	},
	follow = {
		{ bone = "bone_43", like = "bone_22", share = 0.6 },
		{ bone = "bone_53", like = "bone_22", share = 0.3 },
		{ bone = "bone_35", like = "bone_7", share = 0.6 },
		{ bone = "bone_50", like = "bone_7", share = 0.6 },
		{ bone = "bone_38", like = "bone_7", share = 0.3 },
		{ bone = "bone_65", like = "bone_56", share = 1 },
		{ bone = "bone_32", like = "bone_22", share = 0.85 },
		{ bone = "bone_18", like = "bone_7", share = 0.85 },
	},
	-- the beak's tip
	muzzle = { at = { "tripo::Head_3" }, ahead = 0.12, up = 0 },
}

-- blood bat, new (83 bones, k 3.4: about 3.4 x 2.6 x 2.3): Root -> Spine_0 / Spine_1 (the body) -> Head_0 (the neck and
-- the back of the head) -> Head_1 (the head and the ears) -> Head_2 (the snout) -> Head_3..4 (the jaw); Tail_0 (the
-- pelvis) -> bone_10..14 the tail lying behind, the feet (Left_Limb_0..3, Tail_1 -> bone_8..9; Right_Limb_0..4 and the
-- haunches bone_65..70 off the root) ride the body. Both wings hang from the neck through a zero-length bone: humerus
-- (bone_32 / bone_45), forearm (bone_33 / bone_46), the wrist (bone_34 / bone_47), the leading finger (bone_35..36 /
-- bone_48..49) and the membrane fingers (bone_37..43 / bone_50..59, one more on the right).
local BAT_V2: Rig = {
	id = "bloodBat_v2",
	body = "tripo::Root",
	facing = nil,
	level = 62,
	centre = { "tripo::Spine_0", "tripo::Spine_1", "tripo::Tail_0" },
	measure = { from = "tripo::Head_0", to = "tripo::Tail_0", length = 0.9717 },
	hover = 3.82,
	half = 0.42,
	carriage = deg(18),
	pose = { npitch = deg(20), hpitch = deg(45), tpitch = deg(-55), jaw = deg(-20) },
	spine = { { bone = "tripo::Spine_0", share = 0.45 }, { bone = "tripo::Spine_1", share = 0.55 } },
	neck = { { bone = "tripo::Head_0", share = 1 } },
	head = "tripo::Head_1",
	jaw = "tripo::Head_3",
	tail = { "bone_11", "bone_12", "bone_13" },
	fan = nil,
	legs = {},
	wings = {
		L = {
			humerus = "bone_32",
			forearm = "bone_33",
			hand = "bone_34",
			primaries = "bone_35",
			tip = "bone_36",
			pin = "tripo::Spine_1",
			dorsal = { 0, 1, 0 },
			surface = { -0.17, 0.98, 0.12 },
			fingers = {
				{ bone = "bone_37", spread = 0.4 },
				{ bone = "bone_39", spread = 0.75 },
				{ bone = "bone_41", spread = 1 },
			},
		},
		R = {
			humerus = "bone_45",
			forearm = "bone_46",
			hand = "bone_47",
			primaries = "bone_48",
			tip = "bone_49",
			pin = "tripo::Spine_1",
			dorsal = { 0, 1, 0 },
			surface = { 0.13, 0.98, 0.15 },
			fingers = {
				{ bone = "bone_50", spread = 0.4 },
				{ bone = "bone_52", spread = 0.75 },
				{ bone = "bone_54", spread = 1 },
				{ bone = "bone_57", spread = 1 },
			},
		},
	},
	follow = nil,
	-- the snout
	muzzle = { at = { "tripo::Head_2" }, ahead = 0.15, up = -0.05 },
}

-- Each model's maps, the newest export first.
local RIGS: { [string]: { Rig } } = {
	ashVulture = { VULTURE_V2, OLD.ashVulture },
	peakHarpy = { OLD.peakHarpy },
	carrionCrow = { CROW_V2 },
	bloodBat = { BAT_V2 },
}

local FlyerRigs = {}

-- Every bone a map names (the driven ones, the centre, the measure, the fingers, the followers and what they follow).
function FlyerRigs.bones(rig: Rig): { [string]: boolean }
	local set: { [string]: boolean } = { [rig.body] = true, [rig.head] = true }
	local function add(name: string?)
		if name then
			set[name] = true
		end
	end
	for _, row in rig.spine do
		add(row.bone)
	end
	for _, row in rig.neck do
		add(row.bone)
	end
	add(rig.jaw)
	for _, name in rig.tail do
		add(name)
	end
	local fan: { string } = rig.fan or {}
	for _, name in fan do
		add(name)
	end
	add(rig.fanBase)
	for _, leg in rig.legs do
		for _, joint in leg do
			add(joint.bone)
		end
	end
	local wings: { [string]: Wing } = rig.wings or {}
	for _, wing in wings do
		add(wing.clav)
		add(wing.humerus)
		add(wing.forearm)
		add(wing.hand)
		add(wing.primaries)
		add(wing.tip)
		add(wing.pin)
		local fingers: { Finger } = wing.fingers or {}
		for _, finger in fingers do
			add(finger.bone)
		end
	end
	local follow: { Follow } = rig.follow or {}
	for _, row in follow do
		add(row.bone)
		add(row.like)
	end
	for _, name in rig.centre do
		add(name)
	end
	if rig.measure then
		add(rig.measure.from)
		add(rig.measure.to)
	end
	for _, name in rig.muzzle.at do
		add(name)
	end
	return set
end

-- The maps of a model, the newest export first (empty without any).
function FlyerRigs.maps(model: string): { Rig }
	return RIGS[model] or {}
end

-- The map of `model` whose every bone the model has (`has`: the model's bones by name), nil without one: the new
-- export's map once its model is in Assets, the old one before.
function FlyerRigs.pick(model: string, has: { [string]: any }): Rig?
	for _, rig in FlyerRigs.maps(model) do
		local ok = true
		for name in FlyerRigs.bones(rig) do
			if has[name] == nil then
				ok = false
				break
			end
		end
		if ok then
			return rig
		end
	end
	return nil
end

-- A map by its id (the model's name, "_v2" for the new export).
function FlyerRigs.byId(id: string): Rig?
	for _, list in RIGS do
		for _, rig in list do
			if rig.id == id then
				return rig
			end
		end
	end
	return nil
end

return FlyerRigs
