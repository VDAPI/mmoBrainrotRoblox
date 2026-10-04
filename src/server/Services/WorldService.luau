--!strict
-- Builds the world at startup and answers spawn/bounds questions about maps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local WorldService = {
	Name = "WorldService",
}

local function mapOrigin(map: Maps.MapDef): Vector3
	return Vector3.new(map.offset.x, map.offset.y, map.offset.z)
end

-- True when the position lies inside the map's footprint and above its floor.
function WorldService.IsInsideMap(mapId: string, position: Vector3): boolean
	local map = Maps.get(mapId)
	if not map then
		return false
	end
	local local_ = position - mapOrigin(map)
	return math.abs(local_.X) <= map.size.x / 2
		and math.abs(local_.Z) <= map.size.z / 2
		and local_.Y > WorldBuilder.FLOOR_TOP - 2
		and local_.Y < 500
end

function WorldService.GetSpawnCFrame(mapId: string): CFrame
	local map = Maps.get(mapId) or Maps.get("city")
	assert(map, "WorldService: city map missing")
	local spawn = mapOrigin(map) + Vector3.new(map.spawn.x, WorldBuilder.FLOOR_TOP + map.spawn.y, map.spawn.z)
	-- Face the plaza centre.
	return CFrame.lookAt(spawn, Vector3.new(map.offset.x, spawn.Y, map.offset.z))
end

-- Where to place a character returning to a saved location (falls back to the map spawn).
function WorldService.ResolveLocation(mapId: string, x: number, y: number, z: number): CFrame
	local position = Vector3.new(x, y, z)
	if (x ~= 0 or y ~= 0 or z ~= 0) and WorldService.IsInsideMap(mapId, position) then
		return CFrame.new(position + Vector3.new(0, 3, 0))
	end
	return WorldService.GetSpawnCFrame(mapId)
end

function WorldService.Init()
	WorldBuilder.build()
end

return WorldService
