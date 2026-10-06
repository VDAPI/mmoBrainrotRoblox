--!strict
-- Writes the starting city's terrain (S21): Terrain:WriteVoxels in 64 x 64 stud blocks of 4-stud voxels, from the
-- pure TownTerrain.voxels (heights, surface materials, river and moat water). See docs/miasto/MIASTO.md §4.
-- S26: the block loop lives in World/TerrainWriter (shared with the Meadows).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerrainWriter = require(script.Parent.TerrainWriter)
local TownTerrain = require(ReplicatedStorage.Shared.Logic.TownTerrain)

local TownTerrainWriter = {}

TownTerrainWriter.BLOCK = TerrainWriter.BLOCK
TownTerrainWriter.BOTTOM = -16 -- map-relative y of the lowest voxel layer (river bed is -6)
TownTerrainWriter.TOP = 64 -- map-relative y of the top of the highest layer (hills at the map edge reach ~55)
TownTerrainWriter.MARGIN = 64 -- terrain continues this far past the map edge, so the horizon is not a cliff

-- Writes the whole city. `origin` is the map offset (must lie on the 4-stud grid), `half` the half map size.
-- Yields between blocks when `yields` is true. Returns the number of blocks written.
function TownTerrainWriter.write(origin: Vector3, half: number, yields: boolean?): number
	local count = TerrainWriter.write(origin, half, TownTerrain.voxels, TownTerrain.MATERIALS, {
		bottom = TownTerrainWriter.BOTTOM,
		top = TownTerrainWriter.TOP,
		margin = TownTerrainWriter.MARGIN,
		yields = yields,
	})
	return count
end

return TownTerrainWriter
