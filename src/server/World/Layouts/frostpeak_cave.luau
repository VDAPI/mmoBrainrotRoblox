--!strict
-- Glacier Heart (90–100, red): ice corridors and crystal halls. Entrance (west), the crystal hall of the
-- guardians, side caverns where the surface elites shelter, the young dragons' roost and the gate to
-- Vaelgrath's lair (east).

local Areas = require(game:GetService("ReplicatedStorage").Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local CRYSTAL = "#7FD4E8"

return function(ctx: Build.Context)
	Build.caveShell(ctx, Enum.Material.Glacier, 48)

	local rooms = {
		{ x = -250, z = 0, r = 40, h = 24 }, -- entrance
		{ x = -100, z = 0, r = 66, h = 32 }, -- crystal hall
		{ x = -110, z = -180, r = 46, h = 24 }, -- north cavern
		{ x = -110, z = 180, r = 46, h = 24 }, -- south cavern
		{ x = 60, z = -150, r = 46, h = 24 }, -- giants' rest
		{ x = 60, z = 150, r = 46, h = 24 }, -- elementals' spring
		{ x = 110, z = 0, r = 50, h = 34 }, -- young dragons' roost
		{ x = 245, z = 0, r = 48, h = 30 }, -- lair gate
	}
	for _, room in rooms do
		Build.carveRoom(ctx, room.x, room.z, room.r, room.h)
	end
	for _, c in
		{
			{ -215, 0, -170, 0 },
			{ -110, -65, -110, -135 },
			{ -110, 65, -110, 135 },
			{ -65, -170, 20, -155 },
			{ -65, 170, 20, 155 },
			{ 60, -105, 90, -45 },
			{ 60, 105, 90, 45 },
			{ -35, 0, 60, 0 },
			{ 160, 0, 200, 0 },
		}
	do
		Build.carveCorridor(ctx, c[1], c[2], c[3], c[4], 16, 20)
	end
	Build.paint(ctx, 0, 0, 640, 640, 0, Enum.Material.Ice)

	for _, room in rooms do
		for i = 1, 4 do
			local angle = i * 1.6
			Prefabs.crystal(
				ctx,
				room.x + math.cos(angle) * room.r * 0.7,
				room.z + math.sin(angle) * room.r * 0.7,
				CRYSTAL,
				1.3
			)
		end
	end
	for i = 0, 7 do
		local angle = i * math.pi / 4
		Prefabs.column(ctx, -100 + math.cos(angle) * 50, math.sin(angle) * 50, 30, "#A8D8F0")
	end

	Prefabs.portalFrom(ctx, "frostpeak_cave_exit")
	Prefabs.dungeonGateFrom(ctx, "frostpeak")
	Prefabs.torch(ctx, 272, -12, "#D64A3E")
	Prefabs.torch(ctx, 272, 12, "#D64A3E")

	-- Ore veins in the fighting rooms (S19: 6–10 per cave, Data/Areas/Caves)
	local cave = Areas.caves.get("frostpeak_cave")
	if cave and cave.rooms then
		local rooms = cave.rooms
		for i = 1, cave.oreCount do
			local room = rooms[(i - 1) % (#rooms - 2) + 2]
			local angle = ctx.rng:float(0, math.pi * 2)
			local distance = room.r * ctx.rng:float(0.45, 0.75)
			Build.node(
				ctx,
				cave.ores[(i - 1) % #cave.ores + 1],
				room.x + math.cos(angle) * distance,
				room.z + math.sin(angle) * distance
			)
		end
	end

	Build.zone(ctx, "red", nil, -320, -320, 320, 320)
	Build.spawnPoint(ctx, -240, 0, 0, 0)
end
