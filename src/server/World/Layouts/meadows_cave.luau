--!strict
-- Mosshollow Cave (16–20, red zone, boss cave of the region since S19). Carved from a rock block: entrance hall (west, exit portal and respawn),
-- the great goblin hall in the middle, side dens (wolves north-west, boars south-west, bandit hideout
-- north-east), the spider nest (north), the shamans' chamber (south) and the antechamber of Grimrok's
-- dungeon (east). Monster groups, elites and the Elite II come from Data/Areas/Caves (S19).

local Areas = require(game:GetService("ReplicatedStorage").Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local MOSS = "#7ACB3A"

return function(ctx: Build.Context)
	Build.caveShell(ctx, Enum.Material.Rock, 46)

	local rooms = {
		{ x = -250, z = 0, r = 42, h = 24 }, -- entrance
		{ x = -30, z = 0, r = 78, h = 30 }, -- goblin hall
		{ x = -150, z = -140, r = 38, h = 22 }, -- wolf den
		{ x = -150, z = 140, r = 38, h = 22 }, -- boar den
		{ x = 130, z = -160, r = 42, h = 22 }, -- bandit hideout
		{ x = -30, z = -230, r = 56, h = 26 }, -- spider nest
		{ x = 90, z = 215, r = 56, h = 26 }, -- shaman chamber
		{ x = 235, z = 0, r = 52, h = 28 }, -- dungeon antechamber
	}
	for _, room in rooms do
		Build.carveRoom(ctx, room.x, room.z, room.r, room.h)
	end
	local corridors = {
		{ -215, 0, -100, 0 },
		{ -150, 0, -150, -110 },
		{ -150, 0, -150, 110 },
		{ -30, -70, -30, -180 },
		{ -30, 70, 60, 170 },
		{ 40, 0, 190, 0 },
		{ 100, 0, 130, -120 },
	}
	for _, c in corridors do
		Build.carveCorridor(ctx, c[1], c[2], c[3], c[4], 16, 18)
	end
	-- Floor material inside
	Build.paint(ctx, 0, 0, 640, 640, 0, Enum.Material.Rock)

	-- Light: torches along the main corridor, moss crystals in the rooms
	for x = -200, 180, 40 do
		Prefabs.torch(ctx, x, 7)
	end
	for _, room in rooms do
		for i = 1, 3 do
			local angle = i * 2.1
			Prefabs.crystal(
				ctx,
				room.x + math.cos(angle) * room.r * 0.75,
				room.z + math.sin(angle) * room.r * 0.75,
				MOSS,
				0.9
			)
		end
	end
	-- Goblin hall: tents, totems, campfire
	for _, t in { { -70, -40 }, { -60, 40 }, { 10, -50 }, { 20, 45 } } do
		Prefabs.tent(ctx, t[1], t[2], "#4F6B2E")
	end
	Prefabs.campfire(ctx, -30, 0)
	-- Spider nest: webs as pale rocks
	Prefabs.scatter(ctx, 10, -80, -280, 20, -180, function(x, z)
		Prefabs.rock(ctx, x, z, 0.7, "#D8D2E8")
	end)
	-- Shaman chamber: bones and a glowing pool
	Prefabs.crystal(ctx, 90, 215, "#9FE0C9", 1.6)
	Prefabs.scatter(ctx, 8, 50, 180, 130, 250, function(x, z)
		Prefabs.tombstone(ctx, x, z)
	end, { { 90, 215, 10 } })

	-- Exit and the dungeon gate
	Prefabs.portalFrom(ctx, "meadows_cave_exit")
	Prefabs.dungeonGateFrom(ctx, "meadows")
	Prefabs.torch(ctx, 262, -12, "#D64A3E")
	Prefabs.torch(ctx, 262, 12, "#D64A3E")

	-- Ore veins in the fighting rooms (S19: 6–10 per cave, Data/Areas/Caves)
	local cave = Areas.caves.get("meadows_cave")
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
