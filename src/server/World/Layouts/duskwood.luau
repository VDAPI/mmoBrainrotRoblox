--!strict
-- Duskwood (20–45, yellow): a dark forest. West: werewolf woods (20–28) by the portals from the Meadows and
-- the capital; centre-north: old ruins haunted by wraiths (23–31); centre-south: the rotting heart of the
-- forest with ents (26–34); north-east: the cultist village (29–37); south-east: the swamp with trolls
-- (32–40) and a fishing spot; three caves (Data/Areas/duskwood). Monster groups: Data/Areas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local AREAS = Areas.byMap.duskwood

return function(ctx: Build.Context)
	local hx, hz = ctx.map.size.x / 2, ctx.map.size.z / 2
	Build.fill(ctx, -hx - 80, -hz - 80, hx + 80, hz + 80, Enum.Material.LeafyGrass)
	Build.border(ctx, Enum.Material.Slate, 60)

	-- Swamp (south-east): mud with pools
	Build.paint(ctx, 520, 470, 520, 560, 0, Enum.Material.Mud)
	for _, pool in { { 420, 420, 50 }, { 600, 560, 70 }, { 640, 300, 40 }, { 480, 650, 35 } } do
		Build.lake(ctx, pool[1], pool[2], pool[3], 6)
	end
	Prefabs.jetty(ctx, 600, 480, 0)
	Build.node(ctx, "fishing_duskwood", 600, 486)
	Build.node(ctx, "fishing_duskwood", 420, 466) -- second spot (S19)

	-- Roads (Data/Areas/duskwood)
	Build.roads(ctx, AREAS)

	local function road(x: number, z: number): boolean
		-- coarse check against the main road band
		return math.abs(z) < 90 and x > -800
	end

	-- Dense dark forest
	Prefabs.scatter(ctx, 360, -790, -790, 790, 790, function(x, z)
		local roll = ctx.rng:next()
		Prefabs.tree(ctx, x, z, if roll < 0.55 then "dark" elseif roll < 0.8 then "pine" else "dead", 1.2)
	end, {
		{ -80, -330, 60 },
		{ 540, -500, 150 },
		{ 520, 470, 220 },
		{ 160, 300, 70 },
		{ 740, 0, 40 },
		{ -760, 80, 60 },
	}, function(x, z)
		return not road(x, z) or math.abs(z - (if x < -480 then 20 else 0)) > 30
	end)
	Prefabs.scatter(ctx, 80, -790, -790, 790, 790, function(x, z)
		Prefabs.bush(ctx, x, z, "#2E3A24")
	end)
	Prefabs.scatter(ctx, 40, -790, -790, 790, 790, function(x, z)
		Prefabs.rock(ctx, x, z, 1, "#4A4744")
	end, { { 520, 470, 220 } })

	-- Ruins (wraiths)
	Prefabs.ruins(ctx, -80, -330, "#6A6470")
	Prefabs.ruins(ctx, -20, -420, "#6A6470")
	Prefabs.ruins(ctx, -150, -440, "#6A6470")
	for i = 1, 6 do
		Prefabs.tombstone(ctx, -60 + i * 12, -280)
	end

	-- Heart of the forest (ents): glowing fungus
	for i = 1, 6 do
		Prefabs.crystal(ctx, 160 + math.cos(i) * 50, 300 + math.sin(i) * 50, "#5FA06B", 0.8)
	end

	-- Cultist village (north-east)
	for _, t in { { 480, -520 }, { 540, -460 }, { 600, -540 }, { 520, -600 }, { 620, -440 } } do
		Prefabs.tent(ctx, t[1], t[2], "#3A2A4A")
	end
	Prefabs.house(
		ctx,
		560,
		-620,
		{ w = 18, d = 16, h = 10, wall = "#4A4058", roof = "#2A1F33", rot = 0, name = "CultHall" }
	)
	Prefabs.campfire(ctx, 550, -510)
	Prefabs.crystal(ctx, 560, -540, "#7A3FA0", 1.4)
	Prefabs.palisade(ctx, 440, -660, 680, -660)
	Prefabs.palisade(ctx, 680, -660, 680, -400)

	-- Lanterns of the road keep the darkness readable
	for x = -720, 720, 120 do
		Prefabs.lantern(ctx, x, 16, "#9FD0FF")
	end

	-- Gathering (S19: 22 veins, 26 herb bushes)
	local clear = Build.clearOf(AREAS)
	Build.scatterNodes(ctx, "vein_iron", 12, { -760, -760, 0, 760 }, nil, clear)
	Build.scatterNodes(ctx, "vein_silver", 10, { 0, -760, 760, 760 }, nil, clear)
	Build.scatterNodes(ctx, "bush_nightshade", 14, { -760, -760, 100, 760 }, nil, clear)
	Build.scatterNodes(ctx, "bush_moonpetal", 12, { -100, -760, 760, 760 }, nil, clear)

	-- Portals and the three caves (S19)
	Prefabs.portal(ctx, "duskwood_meadows", "meadows", -770, 0, 90, { x = 690, z = -690 })
	Prefabs.portal(ctx, "duskwood_city", "city", -770, 160, 90, Build.cityArrival("duskwood"))
	Prefabs.portal(ctx, "duskwood_ashen", "ashen", 740, -740, 45)
	Prefabs.caveEntrances(ctx, AREAS, "#4A4458")
	Prefabs.areaFeatures(ctx, AREAS, "#4A4458") -- signposts, landmarks, lanterns (S20)
	Prefabs.extraDecor(ctx, AREAS, { "dark", "pine", "dead", "willow" }, { { -660, 90 } })

	Build.zone(ctx, "yellow", "zone.duskwood.woods", -hx, -hz, hx, hz)
	Build.zone(ctx, "yellow", "zone.duskwood.ruins", -260, -560, 80, -200)
	Build.zone(ctx, "yellow", "zone.duskwood.heart", 20, 140, 300, 460)
	Build.zone(ctx, "yellow", "zone.duskwood.village", 420, -700, hx, -380)
	Build.zone(ctx, "yellow", "zone.duskwood.swamp", 300, 220, hx, hz)

	Build.spawnPoint(ctx, -700, 60, 0, 0)
	Build.spawnPoint(ctx, -120, -200, -80, -330)
	Build.spawnPoint(ctx, 60, 100, 160, 300)
	Build.spawnPoint(ctx, 380, -300, 540, -520)
	Build.spawnPoint(ctx, 300, 150, 520, 470)
	Build.spawnPoint(ctx, 690, 40, 745, 0)
end
