--!strict
-- Shared builder of the boss chambers (S09). Since S51 every chamber is on the cave engine (World/CaveLayout from its
-- entry in Data/CaveShapes; the arena contract: a flat floor of radius 74 round the fight's centre (0, -10) at y 0,
-- nothing collidable closer than 50, the dressing goes round it); this adds the exit, the boss icon, the zone and the
-- respawn point. Each dungeon layout (dungeon_<region>) calls it and adds its own (Vaelgrath's braziers).

local Build = require(script.Parent.Parent.Build)
local CaveLayout = require(script.Parent.Parent.CaveLayout)
local Prefabs = require(script.Parent.Parent.Prefabs)

return function(ctx: Build.Context)
	assert(CaveLayout.has(ctx.map.id), `DungeonArena: {ctx.map.id} has no shape in Data/CaveShapes`)
	CaveLayout.build(ctx)
	Prefabs.portalFrom(ctx, `{ctx.map.id}_exit`)
	Build.icon(ctx, "boss", 0, -10)
	Build.zone(ctx, "red", nil, -150, -150, 150, 150)
	Build.spawnPoint(ctx, 0, 60, 0, 0)
end
