--!strict
-- Layout steps of a cave or boss chamber on the cave engine (S48; Data/CaveShapes + Logic/CaveTerrain + the dressing
-- of Logic/CaveDress through Logic/WorldGen), shared by World/Layouts/CaveTemplate (every cave), the boss caves'
-- layouts and World/Layouts/DungeonArena:
--   * terrain (World/CaveTerrainWriter) instead of the old rock block, carved rooms and painted floor,
--   * ctx.height = the floor (props, nodes, portals and signs stand on it), ctx.rayFrom over it,
--   * the "shell" level of every dressing Build in <Cave>/<tag> folders, the dressing's ore veins (Build.node),
--   * the sketch: the floor outline (rectangles `floor`) and the dressing's shapes,
--   * World/BuildStats[<id>] and "[Cave:<id>] shell: … builds, … parts" / "parts=… ms=…".
-- Portals, the exit, signs, zones and respawn points stay with the caller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local BuildStats = require(script.Parent.BuildStats)
local CaveTerrainWriter = require(script.Parent.CaveTerrainWriter)

local Shared = ReplicatedStorage.Shared
local BlueprintBuild = require(Shared.Util.BlueprintBuild)
local CaveTerrain = require(Shared.Logic.CaveTerrain)
local Log = require(Shared.Util.Log)
local WorldGen = require(Shared.Logic.WorldGen)

local CaveLayout = {}

-- Whether a map builds on the cave engine.
function CaveLayout.has(mapId: string): boolean
	return CaveTerrain.has(mapId)
end

function CaveLayout.build(ctx: Build.Context)
	local started = os.clock()
	local mapId = ctx.map.id
	local log = Log.new(`Cave:{mapId}`)
	local T = assert(CaveTerrain.get(mapId), `no cave shape for {mapId}`)
	local pace = ctx.pace or function() end

	local blocks, terrainSeconds, writing = CaveTerrainWriter.write(mapId, ctx.origin, { pace = ctx.pace })
	ctx.height = function(x: number, z: number): number
		return T.floor(x, z) or 0
	end
	ctx.wet = function(x: number, z: number): boolean
		return T.liquid(x, z) ~= nil
	end
	ctx.rayFrom = 6
	pace()

	-- Shells of the dressing, grouped by tag.
	local t0 = os.clock()
	local root = Instance.new("Folder")
	root.Name = "Cave"
	root.Parent = ctx.folder
	local folders: { [string]: Folder } = {}
	local shell, lights, count = 0, 0, 0
	local gen = WorldGen.get(mapId)
	if gen then
		for _, build in gen.all() do
			local folder = folders[build.tag]
			if not folder then
				local created = Instance.new("Folder")
				created.Name = build.tag
				created.Parent = root
				folders[build.tag] = created
				folder = created
			end
			local result = BlueprintBuild.build(build :: any, ctx.origin, { shell = true }, folder :: Folder)
			shell += result.parts
			lights += #build.bp.lights
			count += 1
			pace()
		end
		for _, node in gen.nodes() do
			Build.node(ctx, node.kind, node.x, node.z)
		end
		for _, shape in gen.sketch() do
			table.insert(ctx.sketch.shapes, shape :: any)
		end
	end
	ctx.parts += shell
	local shellSeconds = os.clock() - t0
	log:info("shell: %d builds, %d parts in %.2f s", count, shell, shellSeconds)

	-- The floor outline on the map sketch (under the dressing's shapes).
	for i, rect in T.outline(8) do
		table.insert(
			ctx.sketch.shapes,
			i,
			{ t = "rect", x = rect.x, z = rect.z, w = rect.w, h = rect.d, c = "floor" } :: any
		)
	end

	local stats = BuildStats[mapId] or {} :: any
	stats.parts = ctx.parts
	stats.terrainMs = terrainSeconds * 1000
	stats.writeMs = writing * 1000
	stats.blocks = blocks
	stats.shellMs = shellSeconds * 1000
	stats.builds = count
	stats.nodes = if gen then #gen.nodes() else 0
	stats.lights = lights
	stats.ms = (os.clock() - started) * 1000
	BuildStats[mapId] = stats
	log:info("parts=%d ms=%d (terrain %d ms, shell %d ms)", ctx.parts, stats.ms, stats.terrainMs, stats.shellMs)
end

return CaveLayout
