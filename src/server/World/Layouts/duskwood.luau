--!strict
-- Duskwood (20–45, yellow): a dark forest. West: werewolf woods (20–28) by the portals from the Meadows and
-- the capital; centre-north: old ruins haunted by wraiths (23–31); centre-south: the rotting heart of the
-- forest with ents (26–34); north-east: the cultist village (29–37); south-east: the swamp with trolls
-- (32–40) and a fishing spot; east: the Crypt of the Forgotten. Spawners: Data/Spawns/duskwood.

local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

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

	-- Roads
	Build.path(ctx, { -790, 0, -480, 20, -200, -60, 80, 0, 360, -40, 560, 0, 740, 0 }, 12, Enum.Material.Ground)
	Build.path(ctx, { -790, 160, -480, 20 }, 10, Enum.Material.Ground)
	Build.path(ctx, { -200, -60, -80, -320 }, 10, Enum.Material.Ground)
	Build.path(ctx, { 360, -40, 500, -480 }, 10, Enum.Material.Ground)
	Build.path(ctx, { 80, 0, 160, 320, 380, 420 }, 8, Enum.Material.Mud)
	Build.path(ctx, { 560, 0, 740, -740 }, 10, Enum.Material.Ground)

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

	-- Gathering
	for _, n in { { -560, -420 }, { -640, 420 }, { -300, 520 }, { 220, -700 } } do
		Build.node(ctx, "vein_iron", n[1], n[2])
	end
	for _, n in { { 360, -720 }, { 700, -300 }, { 140, 640 } } do
		Build.node(ctx, "vein_silver", n[1], n[2])
	end
	for _, n in { { -420, -200 }, { -260, 260 }, { 20, 160 }, { -600, 300 } } do
		Build.node(ctx, "bush_nightshade", n[1], n[2])
	end
	for _, n in { { 220, 260 }, { -120, -520 }, { 300, 560 } } do
		Build.node(ctx, "bush_moonpetal", n[1], n[2])
	end

	-- Portals
	Prefabs.portal(ctx, "duskwood_meadows", "meadows", -770, 0, 90, { x = 690, z = -690 })
	Prefabs.portal(ctx, "duskwood_city", "city", -770, 160, 90, { x = 0, z = -236 })
	Prefabs.portal(ctx, "duskwood_crypt", "duskwood_cave", 760, 0, 90)
	Prefabs.portal(ctx, "duskwood_ashen", "ashen", 740, -740, 45)
	Prefabs.column(ctx, 760, -24, 18, "#4A4458")
	Prefabs.column(ctx, 760, 24, 18, "#4A4458")

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
	Build.spawnPoint(ctx, 690, 40, 760, 0)
end
