--!strict
-- Writes the starting city's terrain (S21): Terrain:WriteVoxels in 64 x 64 stud blocks of 4-stud voxels, from the
-- pure TownTerrain.voxels (heights, surface materials, river and moat water). See docs/miasto/MIASTO.md §4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TownTerrain = require(ReplicatedStorage.Shared.Logic.TownTerrain)

local TownTerrainWriter = {}

TownTerrainWriter.BLOCK = 64 -- studs per block side (16 voxels)
TownTerrainWriter.BOTTOM = -16 -- map-relative y of the lowest voxel layer (river bed is -6)
TownTerrainWriter.TOP = 64 -- map-relative y of the top of the highest layer (hills at the map edge reach ~55)
TownTerrainWriter.MARGIN = 64 -- terrain continues this far past the map edge, so the horizon is not a cliff

local enums: { [string]: Enum.Material } = {}
for _, name in TownTerrain.MATERIALS do
	enums[name] = (Enum.Material :: any)[name]
end

-- Writes the whole city. `origin` is the map offset (must lie on the 4-stud grid), `half` the half map size.
-- Yields between blocks when `yields` is true. Returns the number of blocks written.
function TownTerrainWriter.write(origin: Vector3, half: number, yields: boolean?): number
	local terrain = workspace.Terrain
	local V = TownTerrain.VOXEL
	local B = TownTerrainWriter.BLOCK
	local n = B // V
	local bottom = TownTerrainWriter.BOTTOM
	local ny = (TownTerrainWriter.TOP - bottom) // V
	local from = -half - TownTerrainWriter.MARGIN
	local to = half + TownTerrainWriter.MARGIN
	local count = 0
	for bx = from, to - 1, B do
		for bz = from, to - 1, B do
			local block = TownTerrain.voxels(bx, bz, n, n, bottom, ny)
			local mats: { { { Enum.Material } } } = table.create(n)
			for i = 1, n do
				local plane = table.create(ny)
				for j = 1, ny do
					local row = table.create(n)
					local names = block.materials[i][j]
					for k = 1, n do
						row[k] = enums[names[k]] or Enum.Material.Air
					end
					plane[j] = row
				end
				mats[i] = plane
			end
			local min = origin + Vector3.new(bx, bottom, bz)
			local region = Region3.new(min, min + Vector3.new(B, ny * V, B))
			terrain:WriteVoxels(region, V, mats, block.occupancy)
			count += 1
			if yields then
				task.wait()
			end
		end
	end
	return count
end

return TownTerrainWriter
