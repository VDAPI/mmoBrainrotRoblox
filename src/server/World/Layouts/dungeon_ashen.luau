--!strict
-- Azgor's Furnace (boss 70) on the cave engine (Data/CaveShapes, Logic/CaveDress/Furnace). Azgor's lava field
-- covers the flat circle in phase 3 (Entities/BossScripts/azgor).

local Build = require(script.Parent.Parent.Build)
local DungeonArena = require(script.Parent.DungeonArena)

return function(ctx: Build.Context)
	DungeonArena(ctx)
end
