--!strict
-- Whispering Meadows (1–20, yellow). Sub-zones grow in level away from the city portal (west):
-- fields 1–6 (west), forest 5–10 (north), the trade road with the bandit camp 9–14 (south-east), the goblin
-- camp 13–18 (east). A lake with a fishing spot in the south-west, copper and iron veins, herbs, the entrance
-- to Mosshollow Cave (east) and the portal to Duskwood (north-east). Monster groups: Data/Areas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local AREAS = Areas.byMap.meadows

return function(ctx: Build.Context)
	local hx, hz = ctx.map.size.x / 2, ctx.map.size.z / 2
	Build.fill(ctx, -hx - 80, -hz - 80, hx + 80, hz + 80, Enum.Material.Grass)
	Build.border(ctx, Enum.Material.Rock, 55)

	-- Forest floor (north) and goblin dirt (east)
	Build.paint(ctx, -50, -430, 560, 740, 0, Enum.Material.LeafyGrass)
	Build.paint(ctx, 610, -400, 340, 560, 0, Enum.Material.Ground)

	-- Roads (Data/Areas/meadows)
	Build.roads(ctx, AREAS)

	-- Lake (south-west) with a jetty
	Build.lake(ctx, -470, 450, 95, 10)
	Prefabs.jetty(ctx, -470, 345, 0)
	Build.node(ctx, "fishing_meadows", -470, 352)
	-- A second fishing pond on the bandits' road (S19)
	Build.lake(ctx, -60, 560, 34, 6)
	Build.node(ctx, "fishing_meadows", -60, 530)

	-- Hills away from roads
	for _, h in
		{
			{ -650, -450, 60, 18 },
			{ -300, 620, 70, 14 },
			{ 200, 620, 80, 20 },
			{ -560, 250, 40, 10 },
			{ 300, -700, 60, 16 },
		}
	do
		Build.hill(ctx, h[1], h[2], h[3], h[4], Enum.Material.Grass)
	end

	-- Farm by the fields
	Prefabs.house(
		ctx,
		-640,
		-170,
		{ w = 20, d = 16, h = 10, wall = "#B89B5A", roof = "#7A4A2A", rot = 0, name = "Farmhouse" }
	)
	Prefabs.house(
		ctx,
		-600,
		-205,
		{ w = 14, d = 12, h = 8, wall = "#8A6B4A", roof = "#5A3A2A", rot = 90, name = "Barn" }
	)
	Prefabs.palisade(ctx, -700, -120, -540, -120)

	-- Fields: flowers, a few trees
	Prefabs.scatter(ctx, 30, -780, -350, -320, 350, function(x, z)
		Prefabs.flowers(ctx, x, z, if ctx.rng:chance(0.5) then "#F2E8A0" else "#E8A0C9")
	end, { { -470, 450, 110 } }, function(_x, z)
		return math.abs(z) > 14
	end)
	Prefabs.scatter(ctx, 25, -780, -780, -320, 780, function(x, z)
		Prefabs.tree(ctx, x, z, if ctx.rng:chance(0.3) then "birch" else "oak")
	end, { { -470, 450, 110 }, { -640, -180, 50 }, { -700, 0, 40 } }, function(_x, z)
		return math.abs(z) > 20
	end)

	-- Forest (north)
	Prefabs.scatter(ctx, 170, -320, -790, 220, -60, function(x, z)
		Prefabs.tree(ctx, x, z, if ctx.rng:chance(0.4) then "pine" else "oak", 1.1)
	end, { { -150, -380, 40 }, { 80, -560, 40 } }, function(x, z)
		-- keep the forest path open
		local t = math.clamp((z + 260) / -260, 0, 1)
		local px = -80 + 140 * t
		return math.abs(x - px) > 16 or z > -260
	end)
	Prefabs.scatter(ctx, 40, -320, -790, 220, -60, function(x, z)
		Prefabs.bush(ctx, x, z)
	end)
	Prefabs.ruins(ctx, -150, -380)

	-- Trade road: bandit camp
	for _, t in { { 260, 420 }, { 300, 450 }, { 340, 420 }, { 280, 470 } } do
		Prefabs.tent(ctx, t[1], t[2], "#6B4A2B")
	end
	Prefabs.campfire(ctx, 300, 425)
	Prefabs.palisade(ctx, 230, 400, 230, 500)
	Prefabs.palisade(ctx, 230, 500, 370, 500)

	-- Goblin camp (east)
	Prefabs.palisade(ctx, 520, -520, 760, -520)
	Prefabs.palisade(ctx, 760, -520, 760, -260)
	Prefabs.palisade(ctx, 520, -260, 620, -260)
	for _, t in { { 600, -460 }, { 660, -420 }, { 700, -340 }, { 620, -350 }, { 700, -470 } } do
		Prefabs.tent(ctx, t[1], t[2], "#4F6B2E")
	end
	Prefabs.campfire(ctx, 650, -390)
	Prefabs.scatter(ctx, 30, 400, -700, 790, -150, function(x, z)
		Prefabs.rock(ctx, x, z)
	end, { { 640, -390, 140 } })

	-- Scattered rocks and bushes
	Prefabs.scatter(ctx, 40, -790, -790, 790, 790, function(x, z)
		Prefabs.rock(ctx, x, z, 0.8)
	end, { { -470, 450, 110 }, { 300, 440, 90 }, { 640, -390, 150 } })
	Prefabs.scatter(ctx, 50, -100, 0, 790, 790, function(x, z)
		Prefabs.tree(ctx, x, z, "oak")
	end, { { 300, 440, 90 }, { 700, 340, 40 } }, function(x, z)
		return math.abs(z - (80 + (x + 120) * 0.75)) > 26 or x > 140
	end)

	-- Gathering (S19: 22 veins, 27 herb bushes)
	local clear = Build.clearOf(AREAS)
	Build.scatterNodes(ctx, "vein_copper", 12, { -760, -760, 0, 760 }, nil, clear)
	Build.scatterNodes(ctx, "vein_iron", 10, { 0, -760, 760, 760 }, nil, clear)
	Build.scatterNodes(ctx, "bush_meadowsweet", 12, { -760, -400, -200, 400 }, nil, clear)
	Build.scatterNodes(ctx, "bush_nightshade", 9, { -320, -760, 400, -60 }, nil, clear)
	Build.scatterNodes(ctx, "bush_moonpetal", 6, { -760, 360, 400, 760 }, nil, clear)

	-- Portals and the three caves (S19)
	Prefabs.portalFrom(ctx, "meadows_city")
	Prefabs.portalFrom(ctx, "meadows_duskwood")
	Prefabs.caveEntrances(ctx, AREAS)
	Prefabs.areaFeatures(ctx, AREAS) -- signposts, landmarks, lanterns (S20)
	Prefabs.extraDecor(ctx, AREAS, { "oak", "birch", "pine", "willow" }, { { -620, -140 }, { 140, 330 } })

	-- Zones (smallest wins): whole map, then the sub-zones
	Build.zone(ctx, "yellow", "zone.meadows.fields", -hx, -hz, hx, hz)
	Build.zone(ctx, "yellow", "zone.meadows.forest", -330, -hz, 230, -60)
	Build.zone(ctx, "yellow", "zone.meadows.road", -100, 60, hx, hz)
	Build.zone(ctx, "yellow", "zone.meadows.goblins", 400, -hz, hx, -120)
	Build.zone(ctx, "yellow", "zone.meadows.lake", -580, 340, -360, 560)

	Build.spawnPoint(ctx, -700, 30, 0, 0)
	Build.spawnPoint(ctx, -150, -300, 0, 0)
	Build.spawnPoint(ctx, 120, 300, 300, 400)
	Build.spawnPoint(ctx, 470, -180, 640, -390)
	Build.spawnPoint(ctx, 660, 380, 745, 330)
end
