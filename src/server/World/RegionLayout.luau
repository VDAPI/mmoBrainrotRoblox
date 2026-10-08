--!strict
-- Layout steps of a shaped region (S45), the World/Layouts/meadows recipe for any map with a Data/Terrain/<map>
-- (Logic/RegionTerrain) and a generator (Logic/WorldGen):
--   * terrain written by World/TerrainWriter with the shape's writer limits, the border mountains (Build.border),
--   * ctx.height / ctx.wet from the height function (props, nodes and NPCs read the ground from it),
--   * the "shell" level of every generated Build in <Name>/<tag> folders, big trees for the map's forest patches,
--   * portals (Data/Portals), cave entrances (portal, sign, icon; the generator dresses the mouths), signposts
--     where roads enter the areas (road lanterns come from the generator), the map's name sign,
--   * gathering nodes from the generator, quest anchors, the sketch (terrain shapes and buildings of the generator),
--   * World/BuildStats and the Output lines "[<Name>] terrain …", "[<Name>] shell …", "[<Name>] parts=… ms=…".
-- In a background build (ctx.pace) every long loop pauses when its time slice is used up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local BuildStats = require(script.Parent.BuildStats)
local Prefabs = require(script.Parent.Prefabs)
local TerrainWriter = require(script.Parent.TerrainWriter)

local Shared = ReplicatedStorage.Shared
local Areas = require(Shared.Data.Areas)
local BlueprintBuild = require(Shared.Util.BlueprintBuild)
local Log = require(Shared.Util.Log)
local Portals = require(Shared.Data.Portals)
local RegionTerrain = require(Shared.Logic.RegionTerrain)
local WorldGen = require(Shared.Logic.WorldGen)

local RegionLayout = {}

export type Options = {
	name: string, -- folder and log name ("Duskwood")
	border: Enum.Material, -- mountains past the edge
	borderHeight: number,
	signColor: string?, -- colour of the generic area landmarks (Prefabs.areaFeatures)
	nameSign: { x: number, z: number, rot: number }?, -- the map's name sign (Prefabs.signpost)
}

function RegionLayout.build(ctx: Build.Context, options: Options)
	local started = os.clock()
	local mapId = ctx.map.id
	local log = Log.new(options.name)
	local half = ctx.map.size.x / 2
	local T = assert(RegionTerrain.get(mapId), `no shaped terrain for {mapId}`)
	local gen = assert(WorldGen.get(mapId), `no generator for {mapId}`)
	local areas = Areas.byMap[mapId]
	local pace = ctx.pace or function() end
	local stats: BuildStats.Stats =
		{ parts = 0, ms = 0, terrainMs = 0, writeMs = 0, blocks = 0, shellMs = 0, builds = 0, nodes = 0 }
	BuildStats[mapId] = stats

	-- Terrain (written block by block; a background build pauses between blocks).
	local t0 = os.clock()
	local writer = T.shape.writer
	local blocks, writing = TerrainWriter.write(ctx.origin, half, T.voxels, T.MATERIALS, {
		bottom = writer.bottom,
		top = writer.top,
		margin = writer.margin,
		pace = ctx.pace,
	})
	stats.terrainMs = (os.clock() - t0) * 1000
	stats.writeMs = writing * 1000
	stats.blocks = blocks
	log:info("terrain: %d blocks in %.2f s (WriteVoxels %.2f s)", blocks, os.clock() - t0, writing)
	Build.border(ctx, options.border, options.borderHeight)
	ctx.height = T.height
	-- S46: lava and glowing cracks count as wet (signposts and lanterns keep off them)
	ctx.wet = function(x: number, z: number): boolean
		return T.isWater(x, z) or T.streamDistance(x, z) < 5 or T.lavaDistance(x, z) < 6
	end
	pace()

	-- Shells of every Build, grouped by tag.
	t0 = os.clock()
	local root = Instance.new("Folder")
	root.Name = options.name
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
	local builds = gen.all()
	pace()
	local shell = 0
	local lights = 0
	for _, build in builds do
		local result = BlueprintBuild.build(build :: any, ctx.origin, { shell = true }, folderFor(build.tag))
		shell += result.parts
		lights += #build.bp.lights
		pace()
	end
	ctx.parts += shell
	local trees = gen.trees()
	for _, tree in trees do
		table.insert(ctx.trees, { tree.x, tree.z })
	end
	stats.shellMs = (os.clock() - t0) * 1000
	stats.builds = #builds
	stats.trees = #trees
	stats.lights = lights
	log:info("shell: %d builds, %d parts, %d trees in %.2f s", #builds, shell, #trees, os.clock() - t0)

	-- Portals, cave entrances, signposts, the map's name sign.
	for _, portal in Portals.onMap(mapId) do
		if portal.kind == "portal" then
			Prefabs.portalFrom(ctx, portal.id)
		end
	end
	Prefabs.caveEntrances(ctx, areas, nil, { mouth = false })
	Prefabs.areaFeatures(ctx, areas, options.signColor, { lanterns = false })
	local sign = options.nameSign
	if sign then
		Prefabs.signpost(ctx, sign.x, sign.z, sign.rot, `map.{mapId}.name`, ctx.map.minLevel, ctx.map.maxLevel)
	end
	pace()

	-- Gathering nodes by the areas' character, quest anchors.
	local nodes = gen.nodes()
	for _, node in nodes do
		Build.node(ctx, node.kind, node.x, node.z)
	end
	stats.nodes = #nodes
	for _, anchor in (areas.questAnchors or {}) :: { Areas.QuestAnchor } do
		Build.questAnchor(ctx, anchor.id, anchor.x, anchor.z, anchor.y)
	end

	-- Sketch: the generator's terrain shapes and buildings.
	for _, shape in gen.sketch() do
		table.insert(ctx.sketch.shapes, shape :: any)
	end

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

-- Respawn markers from the shape data (Data/Terrain/<map> respawns).
function RegionLayout.respawns(ctx: Build.Context)
	local T = assert(RegionTerrain.get(ctx.map.id))
	for _, r in T.shape.respawns do
		Build.spawnPoint(ctx, r.x, r.z, r.lookX, r.lookZ)
	end
end

return RegionLayout
