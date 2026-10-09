--!strict
-- Vaelgrath's Lair (boss 100) on the cave engine (Data/CaveShapes, Logic/CaveDress/DragonLair): glacier walls, the crown
-- of ice spikes and four braziers. In phase 3 the freezing storm hurts everyone who is not standing by a brazier
-- (Entities/BossScripts/vaelgrath uses the same positions; tests/caveterrain.spec compares them with this table).

local Build = require(script.Parent.Parent.Build)
local DungeonArena = require(script.Parent.DungeonArena)
local Prefabs = require(script.Parent.Parent.Prefabs)

local BRAZIERS = { { -32, -32 }, { 32, -32 }, { -32, 28 }, { 32, 28 } }

return function(ctx: Build.Context)
	DungeonArena(ctx)
	for _, b in BRAZIERS do
		Prefabs.campfire(ctx, b[1], b[2])
		Build.icon(ctx, "brazier", b[1], b[2])
	end
end
