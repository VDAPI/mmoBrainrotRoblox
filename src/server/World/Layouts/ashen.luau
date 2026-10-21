--!strict
-- Ashen Wastes (45–70, yellow), rebuilt in S46 on the shared region engine (World/RegionLayout): the shaped terrain
-- of Data/Terrain/ashen (Logic/RegionTerrain: ash plain, lava, cracks, dunes, mesas, spires, the dry oasis), every
-- building, camp, bridge, brazier and dead tree of Logic/AshenGen, portals, cave entrances dressed by the generator,
-- signposts, nodes and the sketch. This file adds what is only the Wastes': the zones and the respawn points
-- (Data/Terrain/ashen respawns); the map's name sign by the Ribcage Gate is Logic/SignSpots (RegionLayout). Built in the
-- background after the server started (Data/Maps buildLate).

local Build = require(script.Parent.Parent.Build)
local RegionLayout = require(script.Parent.Parent.RegionLayout)

return function(ctx: Build.Context)
	RegionLayout.build(ctx, {
		name = "Ashen",
		border = Enum.Material.Basalt,
		borderHeight = 70,
		signColor = "#5C4A40",
	})

	-- Zones (smallest wins): whole map, then the sub-zones (keys unchanged since S19).
	local hx, hz = ctx.map.size.x / 2, ctx.map.size.z / 2
	Build.zone(ctx, "yellow", "zone.ashen.flats", -hx, -hz, hx, hz)
	Build.zone(ctx, "yellow", "zone.ashen.warcamp", -460, -hz, -20, -340)
	Build.zone(ctx, "yellow", "zone.ashen.golems", -260, -40, 330, 420)
	Build.zone(ctx, "yellow", "zone.ashen.dunes", 330, 300, hx, hz)
	Build.zone(ctx, "yellow", "zone.ashen.crags", 300, -hz, hx, -300)

	RegionLayout.respawns(ctx)
end
