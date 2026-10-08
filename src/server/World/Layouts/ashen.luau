--!strict
-- Ashen Wastes (45–70, yellow), rebuilt in S46 on the shared region engine (World/RegionLayout): the shaped terrain
-- of Data/Terrain/ashen (Logic/RegionTerrain: ash plain, lava, cracks, dunes, mesas, spires, the dry oasis), every
-- building, camp, bridge, brazier and dead tree of Logic/AshenGen, portals, cave entrances dressed by the generator,
-- signposts, nodes and the sketch. This file adds what is only the Wastes': the zones, the respawn points
-- (Data/Terrain/ashen respawns) and the map's name sign by the Ribcage Gate. Built in the background after the server
-- started (Data/Maps buildLate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local RegionLayout = require(script.Parent.Parent.RegionLayout)

local SITES = assert(Areas.byMap.ashen.sites, "ashen sites")

return function(ctx: Build.Context)
	local gate = SITES.ribcage
	RegionLayout.build(ctx, {
		name = "Ashen",
		border = Enum.Material.Basalt,
		borderHeight = 70,
		signColor = "#5C4A40",
		nameSign = { x = gate.x - 30, z = gate.z - 16, rot = 90 },
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
