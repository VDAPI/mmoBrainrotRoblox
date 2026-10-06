--!strict
-- Whispering Meadows (1–20, yellow), rebuilt in S26. Everything comes from data and pure generators:
--   * terrain: Logic/MeadowsTerrain (hills, the Wolf Hills ridge, the Whispering Brook and its forest tributary,
--     Toad Pond and its marsh, Bear Ravine with the waterfall, the Old Quarry terraces, flattened roads and building
--     places) written by World/TerrainWriter; mountains outside the edge as before (Build.border),
--   * buildings, camps, bridges, rocks and trees: the "shell" level of every Logic/MeadowsGen Build (the client adds
--     "detail" and "fine" near the camera, TownDetailController), in Meadows/<tag> folders,
--   * portals (Data/Portals), cave mouths (Data/Areas), signposts and road lanterns (Prefabs.areaFeatures), gathering
--     nodes by the areas' character (MeadowsGen.nodes), quest anchors for S27 (Data/Areas questAnchors), zones,
--     respawn points and the map sketch (streams, lakes, ravine, quarry, bridges, buildings, fields, forests).
-- Output: "[Meadows] terrain ...", "[Meadows] shell ...", "[Meadows] parts=… ms=…" (S26 budget: server parts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Parent.Build)
local BuildStats = require(script.Parent.Parent.BuildStats)
local Prefabs = require(script.Parent.Parent.Prefabs)
local TerrainWriter = require(script.Parent.Parent.TerrainWriter)

local Shared = ReplicatedStorage.Shared
local Areas = require(Shared.Data.Areas)
local BlueprintBuild = require(Shared.Util.BlueprintBuild)
local Log = require(Shared.Util.Log)
local MeadowsGen = require(Shared.Logic.MeadowsGen)
local MeadowsTerrain = require(Shared.Logic.MeadowsTerrain)
local TerrainShape = require(Shared.Data.Terrain.meadows)

local log = Log.new("Meadows")

local AREAS = Areas.byMap.meadows

local function sketch(ctx: Build.Context)
	-- terrain first (drawn under everything by MapSketch's order)
	local m = TerrainShape.marsh
	for _, c in { { 0, 0, 0.75 }, { -0.35, 0.3, 0.45 }, { 0.3, -0.25, 0.45 }, { 0.35, 0.35, 0.4 } } do
		table.insert(ctx.sketch.shapes, {
			t = "circle",
			x = m.x + c[1] * m.rx,
			z = m.z + c[2] * m.rz,
			r = (m.rx + m.rz) / 2 * c[3],
			c = "marsh",
		})
	end
	local ravine = TerrainShape.ravine
	for i = 1, #ravine.pts - 1 do
		local a, b = ravine.pts[i], ravine.pts[i + 1]
		Build.sketchLine(ctx, { a.x, a.z, b.x, b.z }, a.half + b.half + 2 * ravine.wall, "ravineWall")
		Build.sketchLine(ctx, { a.x, a.z, b.x, b.z }, a.half + b.half, "ravine")
	end
	local last = ravine.pts[#ravine.pts]
	table.insert(
		ctx.sketch.shapes,
		{ t = "circle", x = last.x, z = last.z, r = last.half + ravine.wall, c = "ravineWall" }
	)
	table.insert(ctx.sketch.shapes, { t = "circle", x = last.x, z = last.z, r = last.half, c = "ravine" })
	for _, lake in AREAS.lakes do
		table.insert(ctx.sketch.shapes, { t = "circle", x = lake.x, z = lake.z, r = lake.r, c = "water" })
	end
	for _, stream in (AREAS.streams or {}) :: { Areas.Stream } do
		local p = stream.points
		for i = 1, #p - 3, 2 do
			local k = (i + 1) // 2
			local w = ((stream.widths[k] or 8) + (stream.widths[k + 1] or 8)) / 2
			Build.sketchLine(ctx, { p[i], p[i + 1], p[i + 2], p[i + 3] }, w, "water")
		end
	end
	for _, road in AREAS.roads do
		Build.sketchLine(ctx, road.points, road.width, "path")
	end
	for _, ramp in TerrainShape.ramps do
		local pts = {}
		for _, q in ramp.pts do
			table.insert(pts, q[1])
			table.insert(pts, q[2])
		end
		Build.sketchLine(ctx, pts, ramp.w, "path")
	end
	-- buildings, camps, fields, the quarry, bridges (MeadowsGen)
	for _, shape in MeadowsGen.sketch() do
		table.insert(ctx.sketch.shapes, shape :: any)
	end
end

return function(ctx: Build.Context)
	local started = os.clock()
	local half = ctx.map.size.x / 2
	-- numbers of this build (admin /meadowsstats)
	local stats: BuildStats.Stats =
		{ parts = 0, ms = 0, terrainMs = 0, writeMs = 0, blocks = 0, shellMs = 0, builds = 0, nodes = 0 }
	BuildStats[ctx.map.id] = stats

	-- Terrain. The world is built from WorldService.Init, which must not yield: write without pauses.
	local t0 = os.clock()
	local blocks, writing = TerrainWriter.write(ctx.origin, half, MeadowsTerrain.voxels, MeadowsTerrain.MATERIALS, {
		bottom = -24,
		top = 48,
		margin = 64,
	})
	stats.terrainMs = (os.clock() - t0) * 1000
	stats.writeMs = writing * 1000
	stats.blocks = blocks
	log:info("terrain: %d blocks in %.2f s (WriteVoxels %.2f s)", blocks, os.clock() - t0, writing)
	-- Mountains past the edge and the invisible boundary (balls over the written margin).
	Build.border(ctx, Enum.Material.Rock, 55)
	ctx.height = MeadowsTerrain.height
	ctx.wet = function(x: number, z: number): boolean
		return MeadowsTerrain.isWater(x, z) or MeadowsTerrain.streamDistance(x, z) < 5
	end

	-- Shells of every Build, grouped by tag (home, camp, trees, bridge, ...).
	t0 = os.clock()
	local root = Instance.new("Folder")
	root.Name = "Meadows"
	root.Parent = ctx.folder
	local folders: { [string]: Folder } = {}
	local function folderFor(tag: string): Folder
		local folder = folders[tag]
		if not folder then
			local created = Instance.new("Folder")
			created.Name = tag
			created.Parent = root
			folders[tag] = created
			folder = created
		end
		return folder :: Folder
	end
	local builds = MeadowsGen.all()
	local shell = 0
	for _, build in builds do
		local result = BlueprintBuild.build(build :: any, ctx.origin, { shell = true }, folderFor(build.tag))
		shell += result.parts
	end
	ctx.parts += shell
	for _, tree in MeadowsGen.trees() do
		table.insert(ctx.trees, { tree.x, tree.z })
	end
	stats.shellMs = (os.clock() - t0) * 1000
	stats.builds = #builds
	log:info("shell: %d builds, %d parts in %.2f s", #builds, shell, os.clock() - t0)

	-- Portals, cave mouths, signposts and lanterns along the roads; the map's name sign by the gate.
	Prefabs.portalFrom(ctx, "meadows_city")
	Prefabs.portalFrom(ctx, "meadows_duskwood")
	Prefabs.caveEntrances(ctx, AREAS)
	Prefabs.areaFeatures(ctx, AREAS)
	local gate = assert(AREAS.sites, "meadows sites").gate
	Prefabs.signpost(ctx, gate.x + 8, gate.z - 13, 90, "map.meadows.name", ctx.map.minLevel, ctx.map.maxLevel)

	-- Gathering nodes by the areas' character (fishing spots, herbs, ores).
	local nodes = MeadowsGen.nodes()
	for _, node in nodes do
		Build.node(ctx, node.kind, node.x, node.z)
	end
	stats.nodes = #nodes

	-- Quest objects for S27 (invisible, tagged QuestAnchor).
	for _, anchor in (AREAS.questAnchors or {}) :: { Areas.QuestAnchor } do
		Build.questAnchor(ctx, anchor.id, anchor.x, anchor.z, anchor.y)
	end

	-- Zones (smallest wins): whole map, then the sub-zones.
	local hz = ctx.map.size.z / 2
	Build.zone(ctx, "yellow", "zone.meadows.fields", -half, -hz, half, hz)
	Build.zone(ctx, "yellow", "zone.meadows.forest", -330, -hz, 230, -60)
	Build.zone(ctx, "yellow", "zone.meadows.road", -100, 60, half, hz)
	Build.zone(ctx, "yellow", "zone.meadows.goblins", 400, -hz, half, -120)
	Build.zone(ctx, "yellow", "zone.meadows.lake", -720, 380, -330, 760)

	Build.spawnPoint(ctx, -700, 30, 0, 0)
	Build.spawnPoint(ctx, -60, -250, 0, 0)
	Build.spawnPoint(ctx, 120, 300, 300, 400)
	Build.spawnPoint(ctx, 395, -150, 560, -120)
	Build.spawnPoint(ctx, 680, 322, 745, 330)

	sketch(ctx)

	stats.parts = ctx.parts
	stats.ms = (os.clock() - started) * 1000
	log:info(
		"parts=%d ms=%d (terrain %d ms, shell %d ms, %d nodes)",
		ctx.parts,
		stats.ms,
		stats.terrainMs,
		stats.shellMs,
		stats.nodes
	)
end
