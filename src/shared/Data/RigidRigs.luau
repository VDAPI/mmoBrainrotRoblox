--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE.md F5 §6): the bone chains of a rigid kind whose model does
-- have a skeleton, from the rig dump (tools/anim/rigs/<model>.json). Logic/RigidMotion moves the whole look either way;
-- with these chains a serpent slithers along its own spine (the tail's wave, the neck's sway and strike) and the whole
-- body only follows a little. A model without an entry (or with a bone missing) stays rigid.
-- * `tail`, `coil`: from the base out (the wave travels to the end, growing);
-- * `neck`: from the base to the head (the strike and the sway spread over it);
-- * `head`: the head's own bones (kept level against the neck's pitch).

local RigidRigs = {}

export type Rig = {
	tail: { string }?,
	coil: { string }?,
	neck: { string }?,
	head: { string }?,
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
}

function RigidRigs.get(model: string): Rig?
	return RIGS[model]
end

return RigidRigs
