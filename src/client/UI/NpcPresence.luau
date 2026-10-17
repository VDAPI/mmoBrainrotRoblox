--!strict
-- S134k: the NPC the player talks to (opened its dialog and stays within reach; NpcController writes it and clears it
-- when the player walks away). Screens that act only at an NPC (the journal's hunting contracts, the contract board,
-- the Huntmaster's shop) read it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

return {
	Current = scope:Value(nil :: string?),
}
