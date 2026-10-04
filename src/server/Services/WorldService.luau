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
		and local_.Y > -40
		and local_.Y < 500
end

function WorldService.GetSpawnCFrame(mapId: string): CFrame
	local map = Maps.get(mapId) or Maps.get("city")
	assert(map, "WorldService: city map missing")
	local ground = WorldService.GroundCFrame(map.id, map.spawn.x, map.spawn.z).Position
	-- Face the map centre.
	return CFrame.lookAt(ground, Vector3.new(map.offset.x, ground.Y, map.offset.z + 0.001))
end

-- Where to place a character returning to a saved location (falls back to the map spawn). Saved inside a
-- dungeon -> in front of that dungeon's entrance; on a map that is not built -> the capital.
function WorldService.ResolveLocation(mapId: string, x: number, y: number, z: number): CFrame
	local map = Maps.get(mapId)
	if map and map.biome == "dungeon" then
		for _, cave in Maps.byId do
			if cave.dungeonEntrance and cave.dungeonRegion and `dungeon_{cave.dungeonRegion}` == mapId then
				local e = cave.dungeonEntrance
				return CFrame.new(mapOrigin(cave) + Vector3.new(e.x - 20, e.y + 4, e.z))
			end
		end
	end
	if not map or not WorldService.IsBuilt(mapId) then
		return WorldService.GetSpawnCFrame("city")
	end
	local position = Vector3.new(x, y, z)
	if (x ~= 0 or y ~= 0 or z ~= 0) and WorldService.IsInsideMap(mapId, position) then
		return CFrame.new(position + Vector3.new(0, 3, 0))
	end
	return WorldService.GetSpawnCFrame(mapId)
end

-- Standing CFrame on the ground at a map-relative point (raycast against terrain and map geometry,
-- starting low enough to stay under cave roofs).
function WorldService.GroundCFrame(mapId: string, x: number, z: number): CFrame
	local map = Maps.get(mapId)
	if not map then
		return WorldService.GetSpawnCFrame("city")
	end
	local origin = mapOrigin(map)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local world = workspace:FindFirstChild("World")
	params.FilterDescendantsInstances = if world then { workspace.Terrain, world } else { workspace.Terrain }
	params.IgnoreWater = true
	local start = origin + Vector3.new(x, 16, z)
	local hit = workspace:Raycast(start, Vector3.new(0, -80, 0), params)
	local y = if hit then hit.Position.Y else origin.Y
	return CFrame.new(Vector3.new(origin.X + x, y + 4, origin.Z + z)) * CFrame.Angles(0, math.atan2(x, z), 0)
end

function WorldService.IsBuilt(mapId: string): boolean
	return WorldBuilder.built[mapId] == true
end

-- Gathering node placements collected from the layouts: { { map, kind, x, z } }.
function WorldService.GetNodePlacements(): { WorldBuilder.Placement }
	return WorldBuilder.placements
end

-- Portal registry: id -> { map, target, position, arrive? }.
function WorldService.GetPortal(id: string): WorldBuilder.Portal?
	return WorldBuilder.portals[id]
end

function WorldService.Rebuild(mapId: string): boolean
	return WorldBuilder.rebuild(mapId)
end

function WorldService.Init()
	WorldBuilder.build()
end

return WorldService
