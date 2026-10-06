--!strict
-- Builds the world at startup and answers spawn/bounds questions about maps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local TownTerrain = require(ReplicatedStorage.Shared.Logic.TownTerrain)
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
		if mapId == "city" then
			-- S21: a position saved in the old city may now be inside a house or under the terrain.
			local lx, lz = x - map.offset.x, z - map.offset.z
			local ground = map.offset.y + TownTerrain.heightAt(lx, lz)
			if TownTerrain.isOpen(lx, lz) and y >= ground - 2 then
				return CFrame.new(x, math.max(y, ground + 3), z)
			end
			return WorldService.GetSpawnCFrame(mapId)
		end
		return CFrame.new(position + Vector3.new(0, 3, 0))
	end
	return WorldService.GetSpawnCFrame(mapId)
end

-- Underground maps keep a short ray that starts under their roof.
local LOW_RAY_BIOMES = { cave = true, crypt = true, dungeon = true }

local function raycastDown(from: Vector3, length: number, include: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	params.IgnoreWater = true
	return workspace:Raycast(from, Vector3.new(0, -length, 0), params)
end

-- Standing CFrame on the ground at a map-relative point. Underground maps: one short ray (terrain and map
-- geometry) starting 16 studs up, under the roof. Outdoors (S21: the city's castle hill is at y 20 and the
-- hills past its walls reach ~55): the terrain surface from high above first, then map geometry from 16 studs
-- over that surface (bridges, floors), so tree crowns and roofs never catch the ray. In the city a miss falls
-- back to the plan's height (TownTerrain).
function WorldService.GroundCFrame(mapId: string, x: number, z: number): CFrame
	local map = Maps.get(mapId)
	if not map then
		return WorldService.GetSpawnCFrame("city")
	end
	local origin = mapOrigin(map)
	local world = workspace:FindFirstChild("World")
	local everything: { Instance } = if world then { workspace.Terrain, world } else { workspace.Terrain }
	local y: number
	if LOW_RAY_BIOMES[map.biome] then
		local hit = raycastDown(origin + Vector3.new(x, 16, z), 80, everything)
		y = if hit then hit.Position.Y else origin.Y
	else
		local ground = raycastDown(origin + Vector3.new(x, 200, z), 400, { workspace.Terrain })
		y = if ground
			then ground.Position.Y
			elseif mapId == "city" then origin.Y + TownTerrain.heightAt(x, z)
			else origin.Y
		local top = raycastDown(Vector3.new(origin.X + x, y + 16, origin.Z + z), 40, everything)
		if top then
			y = top.Position.Y
		end
	end
	return CFrame.new(Vector3.new(origin.X + x, y + 4, origin.Z + z)) * CFrame.Angles(0, math.atan2(x, z), 0)
end

function WorldService.IsBuilt(mapId: string): boolean
	return WorldBuilder.built[mapId] == true
end

-- Gathering node placements collected from the layouts: { { map, kind, x, z } }.
function WorldService.GetNodePlacements(): { WorldBuilder.Placement }
	return WorldBuilder.placements
end

-- Parts per built map (S20, /perf).
function WorldService.PartCounts(): { [string]: number }
	return WorldBuilder.partCounts
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
