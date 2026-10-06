--!strict
-- Frostpeak (70–100, yellow): snow, ice and mountain passes. West: ice wolf valley (70–78); north: yeti
-- slopes (74–82); centre: the giants' pass (78–88); south: the frozen lake of the elementals (82–92) with
-- an ice hole; east: the ruins of the dragon temple (85–95) and the way into the Glacier Heart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local AREAS = Areas.byMap.frostpeak

local ICE = "#9FE0FF"

return function(ctx: Build.Context)
	local hx, hz = ctx.map.size.x / 2, ctx.map.size.z / 2
	Build.fill(ctx, -hx - 80, -hz - 80, hx + 80, hz + 80, Enum.Material.Snow)
	Build.border(ctx, Enum.Material.Glacier, 90)

	-- Mountain ridges forming the pass (centre)
	for _, r in { { -100, -280, 90, 40 }, { 120, -300, 100, 46 }, { -60, 300, 90, 38 }, { 160, 320, 80, 34 } } do
		Build.hill(ctx, r[1], r[2], r[3], r[4], Enum.Material.Rock)
	end
	for _, r in { { -560, -560, 90, 30 }, { -520, 560, 80, 26 }, { 500, -600, 70, 24 } } do
		Build.hill(ctx, r[1], r[2], r[3], r[4], Enum.Material.Snow)
	end

	-- Frozen lake (south) with the ice hole
	Build.paint(ctx, 160, 560, 360, 260, 0, Enum.Material.Glacier)
	table.insert(ctx.sketch.shapes, { t = "rect", x = 160, z = 560, w = 360, h = 260, c = "water" })
	Build.lake(ctx, 160, 560, 26, 6)
	Build.node(ctx, "fishing_frostpeak", 160, 528)
	-- A second ice hole by the harpy rocks (S19)
	Build.lake(ctx, -560, 600, 22, 6)
	Build.node(ctx, "fishing_frostpeak", -560, 574)

	-- Roads (Data/Areas/frostpeak)
	Build.roads(ctx, AREAS)

	-- Dragon temple ruins (east)
	Prefabs.ruins(ctx, 520, -160, "#C8DDEB")
	Prefabs.ruins(ctx, 600, 140, "#C8DDEB")
	Prefabs.ruins(ctx, 460, 200, "#C8DDEB")
	for i = 0, 5 do
		Prefabs.column(ctx, 560 + (i % 3) * 30, -40 + math.floor(i / 3) * 80, 22, "#C8DDEB")
	end
	-- Yeti caves and ice crystals
	for _, p in { { -260, -520 }, { -180, -620 }, { -340, -440 }, { 260, 600 }, { 60, 640 } } do
		Prefabs.crystal(ctx, p[1], p[2], ICE, 1.4)
	end

	Prefabs.scatter(ctx, 260, -790, -790, 790, 790, function(x, z)
		Prefabs.tree(ctx, x, z, "pine", 1.2)
	end, {
		{ -100, -280, 100 },
		{ 120, -300, 110 },
		{ -60, 300, 100 },
		{ 160, 320, 90 },
		{ 160, 560, 200 },
		{ 560, 40, 160 },
	}, function(_x, z)
		return math.abs(z) > 26
	end)
	Prefabs.scatter(ctx, 50, -790, -790, 790, 790, function(x, z)
		Prefabs.rock(ctx, x, z, 1.3, "#8FA3B3")
	end, { { 160, 560, 200 } })

	-- Gathering (S19: 22 veins, 26 herb bushes)
	local clear = Build.clearOf(AREAS)
	Build.scatterNodes(ctx, "vein_mithril", 11, { -760, -760, 0, 760 }, nil, clear)
	Build.scatterNodes(ctx, "vein_adamantite", 11, { 0, -760, 760, 760 }, nil, clear)
	Build.scatterNodes(ctx, "bush_frostleaf", 26, { -760, -760, 760, 760 }, nil, clear)

	-- Portals
	Prefabs.portal(ctx, "frostpeak_ashen", "ashen", -770, 0, 90, { x = 690, z = -690 })
	Prefabs.portal(ctx, "frostpeak_city", "city", -770, 160, 90, Build.cityArrival("frostpeak"))
	Prefabs.caveEntrances(ctx, AREAS, "#8FA3B3")
	Prefabs.areaFeatures(ctx, AREAS, "#8FA3B3") -- signposts, landmarks, lanterns (S20)
	Prefabs.extraDecor(ctx, AREAS, { "pine", "birch", "dead", "dark" }, { { -660, 90 } })
	for x = -720, 720, 140 do
		Prefabs.lantern(ctx, x, 18, "#9FE0FF")
	end

	Build.zone(ctx, "yellow", "zone.frostpeak.valley", -hx, -hz, hx, hz)
	Build.zone(ctx, "yellow", "zone.frostpeak.slopes", -480, -hz, 0, -260)
	Build.zone(ctx, "yellow", "zone.frostpeak.pass", -200, -240, 320, 240)
	Build.zone(ctx, "yellow", "zone.frostpeak.lake", -60, 420, 400, hz)
	Build.zone(ctx, "yellow", "zone.frostpeak.temple", 400, -320, hx, 320)

	Build.spawnPoint(ctx, -700, 60, 0, 0)
	Build.spawnPoint(ctx, -260, -300, -260, -520)
	Build.spawnPoint(ctx, 40, 60, 0, 0)
	Build.spawnPoint(ctx, 40, 420, 160, 560)
	Build.spawnPoint(ctx, 420, 40, 560, 0)
	Build.spawnPoint(ctx, 690, 40, 745, 0)
end
