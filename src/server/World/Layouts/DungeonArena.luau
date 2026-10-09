--!strict
-- Shared builder of the boss chambers (S09): a round arena carved in rock, a ring of columns in the
-- region's style, torches, the boss's spot in the middle and the exit portal at the entrance side.
-- Each dungeon layout (dungeon_<region>) passes its style.

local Build = require(script.Parent.Parent.Build)
local CaveLayout = require(script.Parent.Parent.CaveLayout)
local Prefabs = require(script.Parent.Parent.Prefabs)

export type Style = {
	rock: Enum.Material,
	floor: Enum.Material,
	column: string,
	light: string,
	crystal: string?,
	cave: string, -- map id of the cave with the entrance
}

local RADIUS = 62

return function(ctx: Build.Context, style: Style)
	-- S48: a chamber with an entry in Data/CaveShapes builds on the cave engine (the arena contract: a flat floor of
	-- radius 74 round the fight's centre (0, -10) at y 0, nothing collidable closer than 50; the dressing goes round
	-- it); exit, boss icon, zone and respawn point as before
	if CaveLayout.has(ctx.map.id) then
		CaveLayout.build(ctx)
		Prefabs.portalFrom(ctx, `{ctx.map.id}_exit`)
		Build.icon(ctx, "boss", 0, -10)
		Build.zone(ctx, "red", nil, -150, -150, 150, 150)
		Build.spawnPoint(ctx, 0, 60, 0, 0)
		return
	end
	Build.caveShell(ctx, style.rock, 50)
	Build.carveRoom(ctx, 0, 0, RADIUS, 36)
	Build.carveRoom(ctx, 0, 70, 22, 22) -- entrance alcove
	Build.carveCorridor(ctx, 0, 40, 0, 70, 18, 20)
	Build.paint(ctx, 0, 0, 300, 300, 0, style.floor)

	for i = 0, 9 do
		local angle = i * math.pi * 2 / 10
		Prefabs.column(ctx, math.cos(angle) * (RADIUS - 8), math.sin(angle) * (RADIUS - 8), 30, style.column)
		Prefabs.torch(ctx, math.cos(angle + 0.3) * (RADIUS - 6), math.sin(angle + 0.3) * (RADIUS - 6), style.light)
	end
	if style.crystal then
		for i = 0, 5 do
			local angle = i * math.pi / 3 + 0.5
			Prefabs.crystal(ctx, math.cos(angle) * 30, math.sin(angle) * 30, style.crystal, 1.2)
		end
	end

	Prefabs.portalFrom(ctx, `{ctx.map.id}_exit`)

	Build.icon(ctx, "boss", 0, -10)
	Build.zone(ctx, "red", nil, -150, -150, 150, 150)
	Build.spawnPoint(ctx, 0, 60, 0, 0)
end
