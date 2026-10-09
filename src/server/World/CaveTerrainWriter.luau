--!strict
-- Writes the terrain of a cave on the engine (S48): a thin wrapper of World/TerrainWriter over Logic/CaveTerrain
-- (rock, floor and ceiling surfaces, water of pools and streams), with ~32 studs of rock past the map edge chosen so
-- that half + margin stays on the 4-stud grid (WriteVoxels rejects regions off it). Logs
-- "[Cave:<id>] terrain: N blocks in … s (WriteVoxels … s)" and fills World/BuildStats[<id>].

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildStats = require(script.Parent.BuildStats)
local TerrainWriter = require(script.Parent.TerrainWriter)

local CaveTerrain = require(ReplicatedStorage.Shared.Logic.CaveTerrain)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local CaveTerrainWriter = {}

-- Margin of rock past the edge so that half + margin is a multiple of 4 (about 32 studs).
function CaveTerrainWriter.margin(half: number): number
	local m = 32
	while (half + m) % 4 ~= 0 do
		m += 1
	end
	return m
end

-- Writes the cave of `mapId` at `origin`; returns (blocks, seconds, WriteVoxels seconds).
function CaveTerrainWriter.write(
	mapId: string,
	origin: Vector3,
	options: { yields: boolean?, pace: (() -> ())? }?
): (number, number, number)
	local T = assert(CaveTerrain.get(mapId), `no cave shape for {mapId}`)
	local started = os.clock()
	local blocks, writing = TerrainWriter.write(origin, T.HALF, T.voxels, T.MATERIALS, {
		bottom = T.BOTTOM,
		top = T.TOP,
		margin = CaveTerrainWriter.margin(T.HALF),
		yields = options and options.yields,
		pace = options and options.pace,
	})
	local seconds = os.clock() - started
	Log.new(`Cave:{mapId}`):info("terrain: %d blocks in %.2f s (WriteVoxels %.2f s)", blocks, seconds, writing)
	local stats: any = BuildStats[mapId] or {}
	stats.terrainMs = seconds * 1000
	stats.writeMs = writing * 1000
	stats.blocks = blocks
	BuildStats[mapId] = stats :: any
	return blocks, seconds, writing
end

return CaveTerrainWriter
