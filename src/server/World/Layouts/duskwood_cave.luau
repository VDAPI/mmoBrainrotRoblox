--!strict
-- Crypt of the Forgotten (35–45, red): straight stone corridors and burial halls. Entrance hall (west),
-- the hall of columns, burial crypts north and south (forest elites driven underground), the ossuary of
-- the skeleton guards, the specters' gallery, the necromancer sanctum and the antechamber of Morvane's
-- dungeon (east). Monster groups from Data/Areas/Caves (S19).

local Areas = require(game:GetService("ReplicatedStorage").Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local GHOST = "#9FE0C9"
local VOID = "#7A3FA0"

return function(ctx: Build.Context)
	Build.caveShell(ctx, Enum.Material.Slate, 44)

	local rooms = {
		{ x = -250, z = 0, r = 38, h = 22 }, -- entrance
		{ x = -110, z = 0, r = 60, h = 28 }, -- hall of columns
		{ x = -110, z = -170, r = 46, h = 22 }, -- north crypt (werewolves, wraiths)
		{ x = -110, z = 170, r = 46, h = 22 }, -- south crypt (ents, trolls)
		{ x = 40, z = -170, r = 46, h = 22 }, -- cultist shrine
		{ x = 40, z = 0, r = 52, h = 26 }, -- ossuary (skeleton guards)
		{ x = 40, z = 170, r = 46, h = 24 }, -- specters' gallery
		{ x = 150, z = 0, r = 44, h = 26 }, -- necromancer sanctum
		{ x = 245, z = 0, r = 46, h = 28 }, -- dungeon antechamber
	}
	for _, room in rooms do
		Build.carveRoom(ctx, room.x, room.z, room.r, room.h)
	end
	for _, c in
		{
			{ -215, 0, -170, 0 },
			{ -110, -60, -110, -130 },
			{ -110, 60, -110, 130 },
			{ -50, 0, -10, 0 },
			{ 40, -50, 40, -130 },
			{ 40, 50, 40, 130 },
			{ 90, 0, 110, 0 },
			{ 190, 0, 205, 0 },
			{ -70, -170, 0, -170 },
			{ -70, 170, 0, 170 },
		}
	do
		Build.carveCorridor(ctx, c[1], c[2], c[3], c[4], 14, 18)
	end
	Build.paint(ctx, 0, 0, 640, 640, 0, Enum.Material.Basalt)

	-- Columns in the hall, tombstones in the crypts
	for i = 0, 7 do
		local angle = i * math.pi / 4
		Prefabs.column(ctx, -110 + math.cos(angle) * 42, math.sin(angle) * 42, 26, "#4A4458")
	end
	for _, room in { rooms[3], rooms[4], rooms[6] } do
		Prefabs.scatter(
			ctx,
			10,
			room.x - room.r * 0.7,
			room.z - room.r * 0.7,
			room.x + room.r * 0.7,
			room.z + room.r * 0.7,
			function(x, z)
				Prefabs.tombstone(ctx, x, z)
			end
		)
	end
	-- Light: cold torches and ghost crystals
	for _, room in rooms do
		Prefabs.torch(ctx, room.x + room.r * 0.7, room.z, "#9FB6FF")
		Prefabs.torch(ctx, room.x - room.r * 0.7, room.z, "#9FB6FF")
	end
	for _, room in { rooms[7], rooms[8] } do
		for i = 1, 3 do
			Prefabs.crystal(
				ctx,
				room.x + math.cos(i * 2) * 25,
				room.z + math.sin(i * 2) * 25,
				if room == rooms[8] then VOID else GHOST
			)
		end
	end

	Prefabs.portal(ctx, "duskwood_cave_exit", "duskwood", -275, 0, 90, Areas.arrivalOf("duskwood_cave"))
	Prefabs.dungeonGate(ctx, "duskwood", 282, 0, 90)
	Prefabs.torch(ctx, 270, -12, "#D64A3E")
	Prefabs.torch(ctx, 270, 12, "#D64A3E")

	-- Ore veins in the fighting rooms (S19: 6–10 per cave, Data/Areas/Caves)
	local cave = Areas.caves.get("duskwood_cave")
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
