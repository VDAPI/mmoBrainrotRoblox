--!strict
-- Shared client state of quest tracking (S11): whether the tracked quest shows its arrow / minimap target, which
-- quest is tracked (S27: the story or one side quest) and where its current objective points (QuestController
-- writes, the tracker, the minimap and the world map read).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

-- S101b: `place` = locale key of a hinted place's name (shown under the star on the world map)
export type Target = { map: string, x: number?, z: number?, npc: string?, place: string? }

-- S27: the tracked quest; nil = the story quest. S99: { kind = "contract" } = the active hunting contract (no id);
-- S134k: { kind = "contract", id = "contract_<level>" } one of the active ones (no id: the first the tracker shows).
export type Focus = { kind: "side" | "contract", id: string? }?

return {
	Tracked = scope:Value(true),
	Focus = scope:Value(nil :: Focus),
	Target = scope:Value(nil :: Target?),
}
