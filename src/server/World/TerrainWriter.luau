--!strict
-- Writes a height-function terrain (S21 city, S26 Whispering Meadows, S45 the shaped regions): Terrain:WriteVoxels in 64 x 64 stud blocks of
-- 4-stud voxels from a pure `voxels(x0, z0, nx, nz, yBottom, ny)` (Logic/TownTerrain, Logic/MeadowsTerrain), with
-- water where the function says so. Returns the number of blocks and the time spent in WriteVoxels.

local TerrainWriter = {}

TerrainWriter.BLOCK = 64 -- studs per block side (16 voxels)
local VOXEL = 4

export type VoxelsFn = (x0: number, z0: number, nx: number, nz: number, yBottom: number, ny: number) -> any

export type Options = {
	bottom: number, -- map-relative y of the lowest voxel layer
	top: number, -- map-relative y of the top of the highest layer
	margin: number, -- terrain continues this far past the map edge
	yields: boolean?, -- task.wait() between blocks (rebuilds; the world build at start must not yield)
	pace: (() -> ())?, -- S45: called after every block (a background build yields when its time slice is used)
}

-- Writes the square [-half - margin, half + margin] of a map. `origin` is the map offset (on the 4-stud grid).
function TerrainWriter.write(
	origin: Vector3,
	half: number,
	voxels: VoxelsFn,
	materials: { string },
	options: Options
): (number, number)
	local terrain = workspace.Terrain
	local enums: { [string]: Enum.Material } = {}
	for _, name in materials do
		enums[name] = (Enum.Material :: any)[name]
	end
	local B = TerrainWriter.BLOCK
	local n = B // VOXEL
	local bottom = options.bottom
	local ny = (options.top - bottom) // VOXEL
	local from = -half - options.margin
	local to = half + options.margin
	local count = 0
	local writing = 0
	for bx = from, to - 1, B do
		for bz = from, to - 1, B do
			local block = voxels(bx, bz, n, n, bottom, ny)
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
			local region = Region3.new(min, min + Vector3.new(B, ny * VOXEL, B))
			local started = os.clock()
			terrain:WriteVoxels(region, VOXEL, mats, block.occupancy)
			writing += os.clock() - started
			count += 1
			if options.yields then
				task.wait()
			end
			if options.pace then
				options.pace()
			end
		end
	end
	return count, writing
end

return TerrainWriter
