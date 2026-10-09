--!strict
-- Heart of the Glacier (92-100, red zone, boss cave of the Frost Peaks) on the cave engine
-- (Data/CaveShapes.frostpeak_cave, dressing Logic/CaveDress/Heart). Monster groups, elites and the Elite II come from Data/Areas/Caves (S19); the exit and the
-- gate from Data/Portals.

local Build = require(script.Parent.Parent.Build)
local CaveLayout = require(script.Parent.Parent.CaveLayout)
local Prefabs = require(script.Parent.Parent.Prefabs)

return function(ctx: Build.Context)
	assert(CaveLayout.has("frostpeak_cave"), "frostpeak_cave: no shape in Data/CaveShapes")
	CaveLayout.build(ctx)
	Prefabs.portalFrom(ctx, "frostpeak_cave_exit")
	Prefabs.dungeonGateFrom(ctx, "frostpeak")
	Build.zone(ctx, "red", nil, -320, -320, 320, 320)
	Build.spawnPoint(ctx, -240, 0, 0, 0)
end
