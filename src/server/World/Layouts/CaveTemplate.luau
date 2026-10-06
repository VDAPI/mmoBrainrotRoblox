--!strict
-- Generated cave layout (S19, DESIGN §3.5): rooms and corridors from Logic/CaveGen (the same plan
-- Logic/AreaSpawns fills with monster groups), carved from a rock block, lit with torches, decorated by
-- theme, with ore veins, the exit portal and a red zone. Each generated cave has a one-line module in
-- World/Layouts that calls this with its map id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local CaveGen = require(ReplicatedStorage.Shared.Logic.CaveGen)
local Prefabs = require(script.Parent.Parent.Prefabs)

type Room = CaveGen.Room

local THEME_COLORS: { [string]: { crystal: string, rock: string, tent: string? } } = {
	smugglers = { crystal = "#E8C25A", rock = "#6A5A48", tent = "#6B4A2B" },
	goblin = { crystal = "#7ACB3A", rock = "#5A5240", tent = "#4F6B2E" },
	den = { crystal = "#C9B26B", rock = "#4A4744" },
	barrow = { crystal = "#9A6BCB", rock = "#4A4058" },
	mine = { crystal = "#D8D8E0", rock = "#3A3430" },
	lair = { crystal = "#FF7A1A", rock = "#3A2A24" },
	grotto = { crystal = "#9FE0FF", rock = "#A8C8DD" },
	hold = { crystal = "#7FD4FF", rock = "#5A6878" },
}

local function material(name: string?): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name or "Rock"]
	end)
	return if ok and value then value else Enum.Material.Rock
end

local function decorate(ctx: Build.Context, theme: string, room: Room, index: number)
	local colors = THEME_COLORS[theme] or THEME_COLORS.den
	-- Glowing crystals or fungus around the walls give each room its light.
	for i = 1, 3 do
		local angle = i * 2.1 + index
		Prefabs.crystal(
			ctx,
			room.x + math.cos(angle) * room.r * 0.78,
			room.z + math.sin(angle) * room.r * 0.78,
			colors.crystal,
			0.8 + (i % 2) * 0.4
		)
	end
	-- Rubble
	Prefabs.scatter(
		ctx,
		4,
		room.x - room.r * 0.7,
		room.z - room.r * 0.7,
		room.x + room.r * 0.7,
		room.z + room.r * 0.7,
		function(x, z)
			Prefabs.rock(ctx, x, z, 0.8, colors.rock)
		end,
		{ { room.x, room.z, room.r * 0.45 } }
	)
	if theme == "smugglers" or theme == "goblin" then
		if index % 2 == 0 then
			Prefabs.tent(ctx, room.x + room.r * 0.4, room.z - room.r * 0.3, colors.tent)
			Prefabs.campfire(ctx, room.x, room.z)
		end
	elseif theme == "barrow" or theme == "den" then
		for i = 1, 4 do
			local angle = i * 1.6 + index
			Prefabs.tombstone(ctx, room.x + math.cos(angle) * room.r * 0.55, room.z + math.sin(angle) * room.r * 0.55)
		end
	elseif theme == "mine" then
		-- Wooden supports along the walls
		for i = 1, 4 do
			local angle = i * math.pi / 2 + 0.4
			Prefabs.column(
				ctx,
				room.x + math.cos(angle) * room.r * 0.8,
				room.z + math.sin(angle) * room.r * 0.8,
				room.h - 2,
				"#6B4A2B"
			)
		end
	elseif theme == "hold" then
		for i = 1, 4 do
			local angle = i * math.pi / 2
			Prefabs.column(
				ctx,
				room.x + math.cos(angle) * room.r * 0.6,
				room.z + math.sin(angle) * room.r * 0.6,
				room.h - 2,
				"#8FA3B3"
			)
		end
	end
end

return function(caveId: string)
	return function(ctx: Build.Context)
		local cave = Areas.caves.get(caveId)
		assert(cave, `CaveTemplate: unknown cave {caveId}`)
		local plan = CaveGen.generate(cave.seed or 1)
		local rock = material(cave.material)
		Build.caveShell(ctx, rock, 42)
		for _, room in plan.rooms do
			Build.carveRoom(ctx, room.x, room.z, room.r, room.h)
		end
		for _, c in plan.corridors do
			Build.carveCorridor(ctx, c.ax, c.az, c.bx, c.bz, c.w, 16)
		end
		Build.paint(ctx, 0, 0, CaveGen.SIZE, CaveGen.SIZE, 0, rock)

		-- Torches along the corridors
		for _, c in plan.corridors do
			local length = math.sqrt((c.bx - c.ax) ^ 2 + (c.bz - c.az) ^ 2)
			local steps = math.max(1, math.floor(length / 45))
			for i = 1, steps do
				local t = i / (steps + 1)
				Prefabs.torch(ctx, c.ax + (c.bx - c.ax) * t, c.az + (c.bz - c.az) * t + 4)
			end
		end
		for i, room in plan.rooms do
			if i > 1 then
				decorate(ctx, cave.theme or "den", room, i)
			end
		end

		-- Ore veins in the fighting rooms
		local fightRooms = {}
		for i = 2, #plan.rooms do
			table.insert(fightRooms, plan.rooms[i])
		end
		for i = 1, cave.oreCount do
			local room = fightRooms[(i - 1) % #fightRooms + 1]
			local angle = ctx.rng:float(0, math.pi * 2)
			local distance = room.r * ctx.rng:float(0.4, 0.75)
			Build.node(
				ctx,
				cave.ores[(i - 1) % #cave.ores + 1],
				room.x + math.cos(angle) * distance,
				room.z + math.sin(angle) * distance
			)
		end

		-- Exit back to the region map, in front of the cave mouth there
		local entrance = plan.rooms[1]
		Prefabs.portalFrom(ctx, `{caveId}_exit`)
		Prefabs.signpost(
			ctx,
			entrance.x + 6,
			entrance.z - entrance.r + 10,
			0,
			cave.nameKey,
			cave.levels[1],
			cave.levels[2]
		)
		Prefabs.torch(ctx, entrance.x - entrance.r + 14, entrance.z - 10)
		Prefabs.torch(ctx, entrance.x - entrance.r + 14, entrance.z + 10)

		local half = CaveGen.SIZE / 2
		Build.zone(ctx, "red", nil, -half, -half, half, half)
		Build.spawnPoint(ctx, entrance.x + 8, entrance.z, entrance.x + 40, entrance.z)
	end
end
