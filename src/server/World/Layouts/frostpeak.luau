--!strict
-- Frost Peaks (70–100, yellow), rebuilt in S47 on the shared region engine (World/RegionLayout): the shaped terrain
-- of Data/Terrain/frostpeak (Logic/RegionTerrain: ridges and a horn, frozen lakes and the frozen brook, glacier
-- tongues, crevasses, spires, the temple's terraces), every building, camp, statue, bridge, snow pole and tree of
-- Logic/FrostpeakGen, portals, cave entrances dressed by the generator, signposts, nodes and the sketch. This file
-- adds what is only the Peaks': the zones and the respawn points (Data/Terrain/frostpeak respawns); the map's name
-- sign by the cairn at the entry is Logic/SignSpots (RegionLayout). Built in the background after the server started
-- (Data/Maps buildLate).

local Build = require(script.Parent.Parent.Build)
local RegionLayout = require(script.Parent.Parent.RegionLayout)

return function(ctx: Build.Context)
	RegionLayout.build(ctx, {
		name = "Frostpeak",
		-- the mountains past the edge stand higher than the ridges (the horizon behind the Wyrm Spire)
		border = Enum.Material.Snow,
		borderHeight = 140,
		signColor = "#8FA3B3",
	})

	-- Zones (smallest wins): whole map, then the sub-zones (keys unchanged since S19).
	local hx, hz = ctx.map.size.x / 2, ctx.map.size.z / 2
	Build.zone(ctx, "yellow", "zone.frostpeak.valley", -hx, -hz, hx, hz)
	Build.zone(ctx, "yellow", "zone.frostpeak.slopes", -480, -hz, 0, -330)
	Build.zone(ctx, "yellow", "zone.frostpeak.pass", -200, -240, 330, 260)
	Build.zone(ctx, "yellow", "zone.frostpeak.lake", -60, 400, 420, hz)
	Build.zone(ctx, "yellow", "zone.frostpeak.temple", 400, -320, hx, 320)

	RegionLayout.respawns(ctx)
end
