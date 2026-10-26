--!strict
-- NPC animation (owner 2026-10-26): what the owner's NPC models (ReplicatedStorage.Assets.Npcs, Tripo Auto Rig Biped,
-- Mixamo bones) need beyond the name rules, by model name, written from their rig dumps (tools/anim/rigs/npc_<id>.json,
-- 2026-10-26: innkeeper, banker, captain, wanderer, merchant, vendor_hunter, blacksmith, healer, guard; all 50-52
-- Mixamo bones on one skinned MeshPart, the fingers straight at rest, the arms in an A-pose; the wanderer's caravan is
-- a 15-stud cart without bones). A model without an entry takes the defaults.
-- * `keep`: arms that hold a prop modelled with the body (a spear, a shield): they keep their rest pose riding the
--   chest, and the moves that use only that arm go to the other one (Data/NpcStyles.MIRRORED);
-- * `hammer`: client/Anim/NpcRig puts a hammer in the right hand while the NPC works at its anvil (a model that holds
--   none of its own);
-- * `palms`: false keeps the arms' own twist (Logic/NpcMotion.fitPalms turns them so the palms face the thighs).
-- The rest poses read from the dumps (studs at a 5.5-stud height): the healer stands in mid-stride (the left foot a
-- stud ahead, the arms swinging) and stands square; the blacksmith's and the innkeeper's forearms reach forward; the
-- guard's body stands 1.3 studs behind its root and its bounds reach 2.7 studs to each side (something long in its
-- hands); the captain's body stands 1.1 studs ahead of its root (a cloak or a weapon on the back); the innkeeper lacks
-- two bones of the right little finger (the curl skips them).

local NpcRigs = {}

export type Rig = {
	keep: { R: boolean?, L: boolean? }?,
	hammer: boolean?,
	palms: boolean?,
}

local RIGS: { [string]: Rig } = {
	-- the long thing in its hands is most likely held in the right one: that arm stays as modelled (Studio check)
	guard = { keep = { R = true } },
}
NpcRigs.RIGS = RIGS

-- The entry of NPC `npcId`'s model (NpcService takes Assets.Npcs.<id>, else the id without its trailing digits:
-- guard1 -> guard); an empty one by default.
function NpcRigs.of(npcId: string): Rig
	return RIGS[npcId] or RIGS[(string.gsub(npcId, "%d+$", ""))] or {}
end

-- The arms an entry keeps (Logic/NpcMotion.new `keep`).
function NpcRigs.keep(rig: Rig): { [string]: boolean }
	local keep = rig.keep
	return { R = keep ~= nil and keep.R == true, L = keep ~= nil and keep.L == true }
end

return NpcRigs
