--!strict
-- Vaelthorn, the capital (DESIGN §3.2): walls with four gates, main plaza with the fountain, craft quarter
-- (forge, alchemist) to the north-west, trade quarter (merchant, backpacks, auction house, bank) to the
-- north-east, temple (healer, teacher) and guild hall to the south-west, the Arena (yellow zone) to the
-- south-east, portals to the regions at the gates. NPC positions in Data/Npcs match this layout.

local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local HALF = 290 -- wall line
local GATE_GAP = 26

return function(ctx: Build.Context)
	local size = ctx.map.size
	Build.fill(ctx, -size.x / 2 - 60, -size.z / 2 - 60, size.x / 2 + 60, size.z / 2 + 60, Enum.Material.Grass)
	Build.border(ctx, Enum.Material.Rock, 40)

	-- Streets
	Build.path(ctx, { -size.x / 2, 0, size.x / 2, 0 }, 18, Enum.Material.Cobblestone)
	Build.path(ctx, { 0, -size.z / 2, 0, size.z / 2 }, 18, Enum.Material.Cobblestone)
	Build.path(ctx, { -220, -120, 220, -120 }, 10, Enum.Material.Pavement)
	Build.path(ctx, { -220, 120, 220, 120 }, 10, Enum.Material.Pavement)
	Build.paint(ctx, 0, 0, 130, 130, 0, Enum.Material.Cobblestone)
	Build.rect(ctx, 0, 0, 130, 130, "plaza")
	Prefabs.fountain(ctx, 0, 0, 11)

	-- Walls, corner towers and gates
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Prefabs.tower(ctx, corner[1] * HALF, corner[2] * HALF, 9, 30)
	end
	for _, side in { -1, 1 } do
		Prefabs.wall(ctx, -HALF, side * HALF, -GATE_GAP, side * HALF)
		Prefabs.wall(ctx, GATE_GAP, side * HALF, HALF, side * HALF)
		Prefabs.wall(ctx, side * HALF, -HALF, side * HALF, -GATE_GAP)
		Prefabs.wall(ctx, side * HALF, GATE_GAP, side * HALF, HALF)
	end
	Prefabs.gate(ctx, HALF, 0, 90)
	Prefabs.gate(ctx, -HALF, 0, 90)
	Prefabs.gate(ctx, 0, -HALF, 0)
	Prefabs.gate(ctx, 0, HALF, 0)

	-- Portals just inside the gates
	Prefabs.portal(ctx, "city_meadows", "meadows", 262, 0, 90)
	Prefabs.portal(ctx, "city_duskwood", "duskwood", 0, -262, 0)
	Prefabs.portal(ctx, "city_ashen", "ashen", -262, 0, 90)
	Prefabs.portal(ctx, "city_frostpeak", "frostpeak", 0, 262, 0)

	-- Craft quarter (north-west)
	Prefabs.forge(ctx, -110, -48, 180)
	Prefabs.house(
		ctx,
		-190,
		-46,
		{ w = 22, d = 20, h = 14, wall = "#6F8A5A", roof = "#3E5A3A", rot = 180, name = "Alchemist" }
	)
	Prefabs.house(ctx, -150, -175, { rot = 0 })
	Prefabs.house(ctx, -215, -175, { rot = 0, wall = "#A89478" })

	-- Trade quarter (north-east)
	Prefabs.stall(ctx, 92, -42, "#C2352E", 180)
	Prefabs.stall(ctx, 130, -42, "#4A8FE7", 180)
	Prefabs.house(
		ctx,
		185,
		-50,
		{ w = 24, d = 20, h = 14, wall = "#B8A27A", roof = "#5A3A6B", rot = 180, name = "AuctionHouse" }
	)
	Prefabs.house(
		ctx,
		240,
		-56,
		{ w = 30, d = 24, h = 16, wall = "#C9C2B2", roof = "#3A4A6B", rot = 180, name = "Bank" }
	)
	Prefabs.house(ctx, 150, -175, { rot = 0 })
	Prefabs.house(ctx, 215, -175, { rot = 0, wall = "#A89478" })

	-- Temple and guild hall (south-west)
	Prefabs.temple(ctx, -130, 75, 0)
	Prefabs.house(
		ctx,
		-225,
		62,
		{ w = 30, d = 22, h = 18, wall = "#8A7A62", roof = "#7A1F2B", rot = 0, name = "GuildHall" }
	)
	Prefabs.flag(ctx, -205, 44, "#7A1F2B")
	Prefabs.flag(ctx, -245, 44, "#7A1F2B")
	Prefabs.house(ctx, -150, 185, { rot = 180 })
	Prefabs.house(ctx, -215, 185, { rot = 180, wall = "#A89478" })

	-- Arena (south-east, yellow zone)
	Prefabs.arena(ctx, 160, 175, 52)
	Build.zone(ctx, "yellow", "zone.arena", 104, 119, 216, 231)

	-- Plaza details: banners, lanterns, trees
	for _, p in { { 50, 50 }, { -50, 50 }, { 50, -50 }, { -50, -50 } } do
		Prefabs.flag(ctx, p[1], p[2], "#C9A45C")
	end
	for i = -6, 6 do
		if math.abs(i) > 1 then
			Prefabs.lantern(ctx, i * 40, 14)
			Prefabs.lantern(ctx, 14, i * 40)
		end
	end
	Prefabs.scatter(ctx, 40, -270, -270, 270, 270, function(x, z)
		Prefabs.tree(ctx, x, z, "oak", 0.9)
	end, {
		{ 0, 0, 80 },
		{ -110, -48, 40 },
		{ -190, -46, 30 },
		{ 160, -45, 110 },
		{ -130, 75, 40 },
		{ -225, 62, 30 },
		{ 160, 175, 75 },
		{ -180, -175, 60 },
		{ 180, -175, 60 },
		{ -180, 185, 60 },
	}, function(x, z)
		return math.abs(x) > 18 and math.abs(z) > 18 and math.abs(math.abs(z) - 120) > 12
	end)

	Build.zone(ctx, "green", nil, -size.x / 2, -size.z / 2, size.x / 2, size.z / 2)
	Build.spawnPoint(ctx, ctx.map.spawn.x, ctx.map.spawn.z, 0, 0)
end
