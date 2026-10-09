--!strict
-- Grimrok's Chamber (boss 20): the goblins' chamber on the cave engine (Data/CaveShapes, Logic/CaveDress/GoblinThrone).

local Build = require(script.Parent.Parent.Build)
local DungeonArena = require(script.Parent.DungeonArena)

return function(ctx: Build.Context)
	DungeonArena(ctx)
end
