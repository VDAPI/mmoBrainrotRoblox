--!strict
-- The Tomb of Morvane (boss 45) on the cave engine (Data/CaveShapes, Logic/CaveDress/Tomb).

local Build = require(script.Parent.Parent.Build)
local DungeonArena = require(script.Parent.DungeonArena)

return function(ctx: Build.Context)
	DungeonArena(ctx)
end
