--!strict
-- Deepforge (60–70, red): dwarven forges carved into basalt, bridges over magma. Entrance hall (west),
-- the great forge hall, magma galleries north and south with bridges, the renegades' armoury, the golem
-- foundry, the flame smiths' sanctum and the gate of Azgor's furnace (east).

local Areas = require(game:GetService("ReplicatedStorage").Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local CaveLayout = require(script.Parent.Parent.CaveLayout)
local Prefabs = require(script.Parent.Parent.Prefabs)

local EMBER = "#FF7A1A"

return function(ctx: Build.Context)
	-- S50: the cave engine (Data/CaveShapes.ashen_cave: carved dwarven halls, the River of Fire under the bridges,
	-- lava galleries; dressing Logic/CaveDress/Forge); the old carved layout below stays for a cave without a shape
	if CaveLayout.has("ashen_cave") then
		CaveLayout.build(ctx)
		Prefabs.portalFrom(ctx, "ashen_cave_exit")
		Prefabs.dungeonGateFrom(ctx, "ashen")
		Build.zone(ctx, "red", nil, -320, -320, 320, 320)
		Build.spawnPoint(ctx, -240, 0, 0, 0)
		return
	end
	Build.caveShell(ctx, Enum.Material.Basalt, 46)

	local rooms = {
		{ x = -250, z = 0, r = 40, h = 24 }, -- entrance
		{ x = -100, z = 0, r = 62, h = 30 }, -- great forge hall
		{ x = -100, z = -170, r = 48, h = 26 }, -- north magma gallery
		{ x = -100, z = 170, r = 48, h = 26 }, -- south magma gallery
		{ x = 60, z = -150, r = 46, h = 24 }, -- armoury (renegade dwarves)
		{ x = 60, z = 150, r = 46, h = 24 }, -- golem foundry
		{ x = 110, z = 0, r = 44, h = 26 }, -- flame smiths' sanctum
		{ x = 240, z = 0, r = 48, h = 28 }, -- furnace gate
	}
	for _, room in rooms do
		Build.carveRoom(ctx, room.x, room.z, room.r, room.h)
	end
	for _, c in
		{
			{ -215, 0, -160, 0 },
			{ -100, -60, -100, -125 },
			{ -100, 60, -100, 125 },
			{ -55, -165, 20, -155 },
			{ -55, 165, 20, 155 },
			{ 60, -105, 90, -40 },
			{ 60, 105, 90, 40 },
			{ -40, 0, 70, 0 },
			{ 150, 0, 195, 0 },
		}
	do
		Build.carveCorridor(ctx, c[1], c[2], c[3], c[4], 16, 18)
	end
	Build.paint(ctx, 0, 0, 640, 640, 0, Enum.Material.Basalt)

	-- Magma in the galleries with bridges across
	for _, z in { -170, 170 } do
		Build.paint(ctx, -100, z, 80, 30, 0, Enum.Material.CrackedLava)
		Prefabs.bridge(ctx, -100, z, 34, 90)
	end
	-- Forges: anvils and glowing coals
	for _, p in { { -130, -30 }, { -70, -30 }, { -130, 30 }, { -70, 30 }, { 110, -20 }, { 110, 20 } } do
		Prefabs.crystal(ctx, p[1], p[2], EMBER, 0.8)
	end
	for _, room in rooms do
		Prefabs.torch(ctx, room.x + room.r * 0.7, room.z, EMBER)
		Prefabs.torch(ctx, room.x - room.r * 0.7, room.z, EMBER)
	end
	for i = 0, 5 do
		local angle = i * math.pi / 3
		Prefabs.column(ctx, -100 + math.cos(angle) * 46, math.sin(angle) * 46, 28, "#3A2A22")
	end

	Prefabs.portalFrom(ctx, "ashen_cave_exit")
	Prefabs.dungeonGateFrom(ctx, "ashen")
	Prefabs.torch(ctx, 270, -12, "#D64A3E")
	Prefabs.torch(ctx, 270, 12, "#D64A3E")

	-- Ore veins in the fighting rooms (S19: 6–10 per cave, Data/Areas/Caves)
	local cave = Areas.caves.get("ashen_cave")
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
