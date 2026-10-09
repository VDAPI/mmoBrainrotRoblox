--!strict
-- Mosshollow Cave (16-20, red zone, boss cave of the Meadows) on the cave engine (Data/CaveShapes.meadows_cave,
-- dressing Logic/CaveDress/Moss). Monster groups, elites and the Elite II come from Data/Areas/Caves (S19); the exit and the
-- gate from Data/Portals.

local Build = require(script.Parent.Parent.Build)
local CaveLayout = require(script.Parent.Parent.CaveLayout)
local Prefabs = require(script.Parent.Parent.Prefabs)

return function(ctx: Build.Context)
	assert(CaveLayout.has("meadows_cave"), "meadows_cave: no shape in Data/CaveShapes")
	CaveLayout.build(ctx)
	Prefabs.portalFrom(ctx, "meadows_cave_exit")
	Prefabs.dungeonGateFrom(ctx, "meadows")
	Build.zone(ctx, "red", nil, -320, -320, 320, 320)
	Build.spawnPoint(ctx, -240, 0, 0, 0)
end
