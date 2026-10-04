--!strict
-- Frostpeak (70–100, yellow): snow, ice and mountain passes. West: ice wolf valley (70–78); north: yeti
-- slopes (74–82); centre: the giants' pass (78–88); south: the frozen lake of the elementals (82–92) with
-- an ice hole; east: the ruins of the dragon temple (85–95) and the way into the Glacier Heart.

local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

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

	-- Roads
	Build.path(ctx, { -790, 0, -480, 20, -200, 0, 0, 0, 260, -40, 500, 0, 760, 0 }, 14, Enum.Material.Ground)
	Build.path(ctx, { -790, 160, -480, 20 }, 10, Enum.Material.Ground)
	Build.path(ctx, { -200, 0, -260, -460 }, 10, Enum.Material.Ground)
	Build.path(ctx, { 0, 0, 120, 440 }, 10, Enum.Material.Ground)

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

	-- Gathering
	for _, n in { { -620, -300 }, { -420, 380 }, { 260, -520 }, { 680, -420 } } do
		Build.node(ctx, "vein_adamantite", n[1], n[2])
	end
	for _, n in { { -640, 260 }, { -300, -620 }, { 380, 380 } } do
		Build.node(ctx, "vein_mithril", n[1], n[2])
	end
	for _, n in { { -520, -120 }, { -380, 160 }, { 40, -480 }, { 300, 460 }, { 640, 360 } } do
		Build.node(ctx, "bush_frostleaf", n[1], n[2])
	end

	-- Portals
	Prefabs.portal(ctx, "frostpeak_ashen", "ashen", -770, 0, 90, { x = 690, z = -690 })
	Prefabs.portal(ctx, "frostpeak_city", "city", -770, 160, 90, { x = 0, z = 236 })
	Prefabs.portal(ctx, "frostpeak_cave", "frostpeak_cave", 760, 0, 90)
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
	Build.spawnPoint(ctx, 690, 40, 760, 0)
end
