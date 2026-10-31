--!strict
-- Template animation (owner 2026-10-31, docs/ANIM-WZORCE.md §6.6): the legs of a many-legged crawler whose model has a
-- skeleton (Tripo "Octopod" rig, Studio names = FBX names), walked by Logic/OctoMotion on top of its rigid recipe
-- (Data/RigidStyles: the body still moves whole on its motor, the legs plant their feet under it). One model id may
-- have several maps (the old rigid model and the new rigged one share the id until the owner swaps them): the first map
-- whose bones all exist in the look is used, none = the look stays rigid (client/Anim/RigidRig).
-- Legs are named by where they stand, not by the export's names (Tripo names them mirrored and gave some legs
-- `Spine_0` / `bone_N`): L = the creature's left (-X), R = its right (+X), 1 the front pair .. 4 the hind pair, P the
-- pedipalps.
-- * `bones`: the leg's joints from the hip (the bone on the body) to the last one (its foot is found where the last
--   segment, carried on, meets the ground);
-- * `group`: the tetrad (0 or 1: L1 R2 L3 R4 step together, R1 L2 R3 L4 half a cycle later), `rank` the leg's place
--   from the front (a ripple runs back through the tetrad: each rank lifts a little later);
-- * `front`: how much the leg takes of a raise (the front legs held up and waving in a rear-up, a bite);
-- * `palp`: a pedipalp (taps the ground in the idle, held up in a fight);
-- * `fangs`: chelicerae chains (the joint first) with the side they open to (-1 left, 1 right, 0 forward);
-- * `abdomen`: bones that pump with the venom (the `gr` control of the recipe) and breathe;
-- * `arms`, `tail` (a scorpion's pincers and sting, when its model gets a skeleton): chains raised / curled by the
--   recipe's `raise` / `stab` (arms) and `dip` (the tail goes up and over), see Logic/OctoMotion.
-- The legs bend in the plane through the hip and the foot; the knee is the joint highest at rest (Logic/OctoPose).

local OctoRigs = {}

export type Leg = {
	name: string,
	bones: { string },
	group: number,
	rank: number,
	front: number,
	palp: boolean?,
}
export type Chain = { bones: { string }, side: number }
export type Rig = {
	body: string, -- the bone the legs hang on (not driven: the whole look moves on its motor)
	legs: { Leg },
	fangs: { Chain }?,
	abdomen: { string }?,
	arms: { Chain }?,
	tail: { string }?,
}

local function limb(prefix: string, n: number): { string }
	local out = {}
	for i = 0, n - 1 do
		table.insert(out, prefix .. i)
	end
	return out
end

local RIGS: { [string]: { Rig } } = {
	-- caveSpider, the Tripo model of 2026-10-31 (tools/anim/rigs/caveSpider_v2.json, plot rigs_v2/caveSpider.png): the
	-- mesh has seven legs (no third leg on its right) and two pedipalps long enough to reach the ground; the chelicerae
	-- hang under the face (bone_55..57 left, bone_58..59 and bone_60..63 by the middle; the right one has no bones of
	-- its own); bone_54 carries the front of the abdomen. Tetrads: L1 R2 L3 R4 + the right palp, R1 L2 L4 + the left.
	-- The old model (one rigid mesh, no bones) matches no map and keeps Data/RigidStyles `spider` with its MeshFold death.
	caveSpider = {
		{
			body = "tripo::Root",
			legs = {
				{ name = "PL", bones = limb("tripo::2_Right_Limb_", 5), group = 1, rank = 0, front = 0.8, palp = true },
				{ name = "L1", bones = limb("tripo::1_Right_Limb_", 6), group = 0, rank = 1, front = 1 },
				{ name = "L2", bones = limb("tripo::0_Right_Limb_", 6), group = 1, rank = 2, front = 0.35 },
				{ name = "L3", bones = limb("tripo::3_Left_Limb_", 6), group = 0, rank = 3, front = 0 },
				{ name = "L4", bones = limb("tripo::3_Right_Limb_", 6), group = 1, rank = 4, front = 0 },
				{ name = "PR", bones = limb("tripo::1_Left_Limb_", 5), group = 0, rank = 0, front = 0.8, palp = true },
				{ name = "R1", bones = limb("tripo::2_Left_Limb_", 6), group = 1, rank = 1, front = 1 },
				{
					name = "R2",
					bones = { "tripo::Spine_0", "bone_13", "bone_14", "bone_15", "bone_16", "bone_17" },
					group = 0,
					rank = 2.5,
					front = 0.2,
				},
				{
					name = "R4",
					bones = { "bone_18", "bone_19", "bone_20", "bone_21", "bone_22", "bone_23" },
					group = 0,
					rank = 4,
					front = 0,
				},
			},
			fangs = {
				{ bones = { "bone_55", "bone_56" }, side = -1 },
				{ bones = { "bone_58" }, side = 0 },
				{ bones = { "bone_60", "bone_61" }, side = 1 },
			},
			abdomen = { "bone_54" },
		},
	},
	-- desertScorpion: no skeleton yet (tools/anim/rigs/desertScorpion.json). A Tripo Octopod or Hexapod rig gets a map
	-- here: its walking legs in `legs` (front 0, the pincers do the raising), the pincers in `arms` (side -1 / 1), the
	-- tail from its base to the sting in `tail`; Data/RigidStyles `scorpion` already keys the legs.
}

-- The first map of `model` whose bones `has` all.
function OctoRigs.find(model: string, has: (string) -> boolean): Rig?
	local list = RIGS[model]
	if not list then
		return nil
	end
	for _, rig in list do
		local ok = has(rig.body)
		for _, leg in rig.legs do
			for _, name in leg.bones do
				ok = ok and has(name)
			end
		end
		local fangs: { Chain } = rig.fangs or {}
		local arms: { Chain } = rig.arms or {}
		local abdomen: { string } = rig.abdomen or {}
		local tail: { string } = rig.tail or {}
		for _, chains in { fangs, arms } do
			for _, chain in chains do
				for _, name in chain.bones do
					ok = ok and has(name)
				end
			end
		end
		for _, names in { abdomen, tail } do
			for _, name in names do
				ok = ok and has(name)
			end
		end
		if ok then
			return rig
		end
	end
	return nil
end

-- Every map of `model` (the specs).
function OctoRigs.all(model: string): { Rig }
	return RIGS[model] or {}
end

-- The models that have a map.
function OctoRigs.models(): { string }
	local out = {}
	for id in RIGS do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

return OctoRigs
