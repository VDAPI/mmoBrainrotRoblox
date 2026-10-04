--!strict
-- Vaelgrath's Lair (boss 100): glacier walls, ice crystals and four braziers. In phase 3 the freezing storm
-- hurts everyone who is not standing by a brazier (Entities/BossScripts/vaelgrath uses the same positions).

local Build = require(script.Parent.Parent.Build)
local DungeonArena = require(script.Parent.DungeonArena)
local Prefabs = require(script.Parent.Parent.Prefabs)

local BRAZIERS = { { -32, -32 }, { 32, -32 }, { -32, 28 }, { 32, 28 } }

return function(ctx: Build.Context)
	DungeonArena(ctx, {
		rock = Enum.Material.Glacier,
		floor = Enum.Material.Ice,
		column = "#A8D8F0",
		light = "#9FE0FF",
		crystal = "#7FD4E8",
		cave = "frostpeak_cave",
	})
	for _, b in BRAZIERS do
		Prefabs.campfire(ctx, b[1], b[2])
		Build.icon(ctx, "brazier", b[1], b[2])
	end
end
