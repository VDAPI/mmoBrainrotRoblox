--!strict
-- Ashen Wastes (45–70, yellow): cracked earth and lava. West: salamander flats by the portals (45–52);
-- north: the ash orc warcamp with watchtowers (48–56); centre: the golem fields around lava pools (52–60);
-- south-east: scorpion dunes (55–63); north-east: wyvern crags (58–66); east: the gate to Deepforge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local AREAS = Areas.byMap.ashen

local function lavaPool(ctx: Build.Context, x: number, z: number, radius: number)
	Build.paint(ctx, x, z, radius * 2, radius * 2, 0, Enum.Material.CrackedLava)
	Build.hill(ctx, x, z, radius * 0.6, 2, Enum.Material.CrackedLava)
	table.insert(ctx.sketch.shapes, { t = "circle", x = x, z = z, r = radius, c = "lava" })
end

return function(ctx: Build.Context)
	local hx, hz = ctx.map.size.x / 2, ctx.map.size.z / 2
	Build.fill(ctx, -hx - 80, -hz - 80, hx + 80, hz + 80, Enum.Material.Ground)
	Build.border(ctx, Enum.Material.Basalt, 70)

	-- Dunes (south-east) and ash (north)
	Build.paint(ctx, 460, 450, 700, 700, 0, Enum.Material.Sand)
	Build.paint(ctx, 0, -520, 900, 560, 0, Enum.Material.Basalt)
	for _, d in { { 400, 360, 50, 8 }, { 560, 520, 60, 10 }, { 680, 300, 45, 7 }, { 360, 640, 55, 9 } } do
		Build.hill(ctx, d[1], d[2], d[3], d[4], Enum.Material.Sand)
	end

	-- Lava pools in the golem fields
	for _, p in { { -60, 120, 40 }, { 120, 40, 55 }, { 60, 260, 35 }, { -180, 300, 30 }, { 260, 180, 30 } } do
		lavaPool(ctx, p[1], p[2], p[3])
	end

	-- Roads (Data/Areas/ashen)
	Build.roads(ctx, AREAS)

	-- Ash orc warcamp (north-west)
	Prefabs.palisade(ctx, -420, -660, -60, -660)
	Prefabs.palisade(ctx, -420, -660, -420, -380)
	for _, t in { { -360, -560 }, { -280, -600 }, { -200, -540 }, { -300, -480 }, { -140, -600 } } do
		Prefabs.tent(ctx, t[1], t[2], "#6B2E25")
	end
	Prefabs.tower(ctx, -400, -400, 6, 26, "#5C5A55")
	Prefabs.tower(ctx, -80, -640, 6, 26, "#5C5A55")
	Prefabs.campfire(ctx, -260, -540)
	Prefabs.flag(ctx, -250, -500, "#B5462B")

	-- Wyvern crags (north-east): tall rocks
	Prefabs.scatter(ctx, 35, 300, -780, 780, -300, function(x, z)
		Prefabs.rock(ctx, x, z, 2.4, "#4A3A30")
	end, { { 620, -440, 30 } })

	-- Dead trees and rocks everywhere
	Prefabs.scatter(ctx, 120, -790, -790, 790, 790, function(x, z)
		Prefabs.tree(ctx, x, z, "dead", 1.1)
	end, { { -260, -540, 160 }, { 40, 150, 200 } }, function(_x, z)
		return math.abs(z) > 24
	end)
	Prefabs.scatter(ctx, 60, -790, -790, 790, 790, function(x, z)
		Prefabs.rock(ctx, x, z, 1.2, "#5C4A40")
	end, { { 40, 150, 200 } })
	Prefabs.ruins(ctx, -520, 420, "#7A6A58")
	Prefabs.ruins(ctx, 200, 640, "#7A6A58")

	-- Gathering (S19: 22 veins, 26 herb bushes)
	local clear = Build.clearOf(AREAS)
	Build.scatterNodes(ctx, "vein_silver", 12, { -760, -760, 0, 760 }, nil, clear)
	Build.scatterNodes(ctx, "vein_mithril", 10, { 0, -760, 760, 760 }, nil, clear)
	Build.scatterNodes(ctx, "bush_firebloom", 26, { -760, -760, 760, 760 }, nil, clear)
	-- Oasis with a fishing spot
	Build.lake(ctx, -560, 600, 70, 8)
	Prefabs.jetty(ctx, -560, 520, 0)
	Build.node(ctx, "fishing_ashen", -560, 526)
	-- A second spring in the flats (S19)
	Build.lake(ctx, -680, 300, 26, 6)
	Build.node(ctx, "fishing_ashen", -680, 270)
	for _, p in { { -500, 560 }, { -620, 650 }, { -520, 670 } } do
		Prefabs.tree(ctx, p[1], p[2], "willow", 1.2)
	end

	-- Portals
	Prefabs.portal(ctx, "ashen_duskwood", "duskwood", -770, 0, 90, { x = 690, z = -690 })
	Prefabs.portal(ctx, "ashen_city", "city", -770, 160, 90, Build.cityArrival("ashen"))
	Prefabs.portal(ctx, "ashen_frostpeak", "frostpeak", 740, -740, 45)

	Build.zone(ctx, "yellow", "zone.ashen.flats", -hx, -hz, hx, hz)
	Build.zone(ctx, "yellow", "zone.ashen.warcamp", -460, -hz, -20, -340)
	Build.zone(ctx, "yellow", "zone.ashen.golems", -240, -40, 320, 360)
	Build.zone(ctx, "yellow", "zone.ashen.dunes", 300, 300, hx, hz)
	Build.zone(ctx, "yellow", "zone.ashen.crags", 300, -hz, hx, -280)

	Build.spawnPoint(ctx, -700, 60, 0, 0)
	Build.spawnPoint(ctx, -240, -300, -260, -540)
	Build.spawnPoint(ctx, -100, -20, 40, 150)
	Build.spawnPoint(ctx, 300, 260, 460, 450)
	Build.spawnPoint(ctx, 480, -200, 620, -440)
	Build.spawnPoint(ctx, 690, 40, 745, 0)
	Prefabs.caveEntrances(ctx, AREAS, "#3A2A24")
	Prefabs.areaFeatures(ctx, AREAS, "#5C4A40") -- signposts, landmarks, lanterns (S20)
	Prefabs.extraDecor(ctx, AREAS, { "dead", "dark", "willow", "pine" }, { { -660, 90 } })
end
