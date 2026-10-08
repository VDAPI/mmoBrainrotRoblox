--!strict
-- Duskwood (20–45, yellow), rebuilt in S45 on the shared region engine (World/RegionLayout): the shaped terrain of
-- Data/Terrain/duskwood (Logic/RegionTerrain), every building, camp, bridge, lantern and tree of Logic/DuskwoodGen,
-- portals, cave entrances dressed by the generator, signposts, nodes and the sketch. This file adds what is only
-- Duskwood's: the zones, the respawn points (Data/Terrain/duskwood respawns) and the map's name sign by the gate.
-- Built in the background after the server started (Data/Maps buildLate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local RegionLayout = require(script.Parent.Parent.RegionLayout)

local SITES = assert(Areas.byMap.duskwood.sites, "duskwood sites")

return function(ctx: Build.Context)
	local gate = SITES.duskGate
	RegionLayout.build(ctx, {
		name = "Duskwood",
		border = Enum.Material.Slate,
		borderHeight = 60,
		signColor = "#4A4458",
		nameSign = { x = gate.x - 8, z = gate.z - 14, rot = 90 },
	})

	-- Zones (smallest wins): whole map, then the sub-zones.
	local hx, hz = ctx.map.size.x / 2, ctx.map.size.z / 2
	Build.zone(ctx, "yellow", "zone.duskwood.woods", -hx, -hz, hx, hz)
	Build.zone(ctx, "yellow", "zone.duskwood.ruins", -260, -560, 80, -300)
	Build.zone(ctx, "yellow", "zone.duskwood.heart", 0, 220, 300, 520)
	Build.zone(ctx, "yellow", "zone.duskwood.village", 470, -650, 650, -470)
	Build.zone(ctx, "yellow", "zone.duskwood.swamp", 370, 300, hx, hz)

	RegionLayout.respawns(ctx)
end
