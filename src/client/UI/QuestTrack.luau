--!strict
-- Shared client state of quest tracking (S11): whether the main quest is tracked in the HUD and where its
-- current objective points (QuestController writes, the tracker and the minimap read).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

export type Target = { map: string, x: number?, z: number?, npc: string? }

return {
	Tracked = scope:Value(true),
	Target = scope:Value(nil :: Target?),
}
