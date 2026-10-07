--!strict
-- Builds the world at startup and answers spawn/bounds questions about maps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local MapTerrain = require(ReplicatedStorage.Shared.Logic.MapTerrain)
local Respawn = require(ReplicatedStorage.Shared.Logic.Respawn)
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
		-- S26: on a reshaped map an old position may now be under a hill: stand on the ground there.
		local lx, lz = x - map.offset.x, z - map.offset.z
		local planned = MapTerrain.height(mapId, lx, lz)
		if planned then
			local ground = map.offset.y + planned
			return CFrame.new(x, math.max(y, ground + 3), z)
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
-- back to the plan's height (TownTerrain; S26: every map with a height function, Logic/MapTerrain).
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
		y = if ground then ground.Position.Y else origin.Y + (MapTerrain.height(mapId, x, z) or 0)
		local top = raycastDown(Vector3.new(origin.X + x, y + 16, origin.Z + z), 40, everything)
		if top then
			y = top.Position.Y
		end
	end
	return CFrame.new(Vector3.new(origin.X + x, y + 4, origin.Z + z)) * CFrame.Angles(0, math.atan2(x, z), 0)
end

-- S29: ground and free spots for placing figures ----------------------------------------------------------

-- Character column: feet to the top of the head (with a margin), and the body box checked for walls.
local HEADROOM = 6.5
local BODY = Vector3.new(2, 4.5, 2)
-- Geometry surfaces within STEP_UP over the terrain count as floor (porch, stairs, a square's paving, a bridge
-- deck low over the bank); the ray starts there, so roofs and awnings higher up never catch it.
local STEP_UP = 7
local SEARCH_RADIUS = 30

-- Terrain plus this map's own geometry: no NPCs (World.Npcs), gathering nodes, monsters or characters.
local function mapGeometry(mapId: string): { Instance }
	local world = workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild(mapId)
	return if folder then { workspace.Terrain, folder } else { workspace.Terrain }
end

local function castDown(from: Vector3, length: number, include: { Instance }, water: boolean): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	params.IgnoreWater = not water
	params.RespectCanCollide = true
	return workspace:Raycast(from, Vector3.new(0, -length, 0), params)
end

-- World point where a figure's feet rest at a map-relative (x, z): the top surface of the terrain or of the
-- map's own collidable geometry no higher than STEP_UP over the terrain. Ignores NPCs and characters.
-- `fromY` (map-relative) overrides where the ray starts (NpcService: just over the plan height).
function WorldService.FloorAt(mapId: string, x: number, z: number, fromY: number?): Vector3
	local map = Maps.get(mapId)
	if not map then
		return WorldService.GetSpawnCFrame("city").Position - Vector3.new(0, 4, 0)
	end
	local origin = mapOrigin(map)
	local geometry = mapGeometry(mapId)
	if LOW_RAY_BIOMES[map.biome] then
		local hit = castDown(origin + Vector3.new(x, fromY or 16, z), 80, geometry, false)
		return Vector3.new(origin.X + x, if hit then hit.Position.Y else origin.Y, origin.Z + z)
	end
	local start: number
	if fromY then
		start = origin.Y + fromY
	else
		local ground = castDown(origin + Vector3.new(x, 200, z), 400, { workspace.Terrain }, false)
		local y = if ground then ground.Position.Y else origin.Y + (MapTerrain.height(mapId, x, z) or 0)
		start = y + STEP_UP
	end
	local top = castDown(Vector3.new(origin.X + x, start, origin.Z + z), STEP_UP + 40, geometry, false)
	local y = if top then top.Position.Y else start - STEP_UP
	return Vector3.new(origin.X + x, y, origin.Z + z)
end

-- Whether a character fits with its feet at `feet`: no water there, nothing collidable in the body or over
-- the head (to HEADROOM). NPCs count as obstacles here (a character must not land inside one).
local function standable(mapId: string, feet: Vector3): boolean
	local wet = castDown(feet + Vector3.new(0, 2, 0), 4, { workspace.Terrain }, true)
	if wet and wet.Material == Enum.Material.Water then
		return false
	end
	local world = workspace:FindFirstChild("World")
	local include: { Instance } = { workspace.Terrain }
	if world then
		local folder = world:FindFirstChild(mapId)
		local npcs = world:FindFirstChild("Npcs")
		if folder then
			table.insert(include, folder)
		end
		if npcs then
			table.insert(include, npcs)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	params.IgnoreWater = true
	params.RespectCanCollide = true
	if workspace:Raycast(feet + Vector3.new(0, 0.2, 0), Vector3.new(0, HEADROOM, 0), params) then
		return false
	end
	-- Spatial queries never return Terrain: only the map's parts and the NPCs.
	local parts = table.clone(include)
	table.remove(parts, 1)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = parts
	overlap.RespectCanCollide = true
	local body = CFrame.new(feet + Vector3.new(0, 0.4 + BODY.Y / 2, 0))
	return #workspace:GetPartBoundsInBox(body, BODY, overlap) == 0
end

-- S29: the one "can a character stand here" check for teleports (/tp, /town tp, /npc, the dev panel). Tries the
-- map-relative (x, z), then rings around it (Logic/Respawn.searchOffsets) up to `radius`; returns the standing
-- CFrame (4 studs over the feet, like GroundCFrame) and whether it is a checked free spot. With no free spot:
-- the floor at (x, z) and false.
function WorldService.SafeSpot(mapId: string, x: number, z: number, radius: number?): (CFrame, boolean)
	local map = Maps.get(mapId)
	if not map then
		return WorldService.GetSpawnCFrame("city"), false
	end
	local first = WorldService.FloorAt(mapId, x, z)
	local candidates = { { 0, 0 } }
	for _, offset in Respawn.searchOffsets(radius or SEARCH_RADIUS) do
		table.insert(candidates, offset)
	end
	for _, offset in candidates do
		local px, pz = x + offset[1], z + offset[2]
		local feet = if offset[1] == 0 and offset[2] == 0 then first else WorldService.FloorAt(mapId, px, pz)
		if WorldService.IsInsideMap(mapId, feet) and math.abs(feet.Y - first.Y) < 12 and standable(mapId, feet) then
			return CFrame.new(feet + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.atan2(px, pz), 0), true
		end
	end
	return CFrame.new(first + Vector3.new(0, 4, 0)), false
end

-- SafeSpot turned to face a world point (an NPC, a building).
function WorldService.SafeSpotFacing(mapId: string, x: number, z: number, look: Vector3): (CFrame, boolean)
	local at, ok = WorldService.SafeSpot(mapId, x, z)
	local p = at.Position
	local flat = Vector3.new(look.X, p.Y, look.Z)
	if (flat - p).Magnitude < 0.1 then
		return at, ok
	end
	return CFrame.lookAt(p, flat), ok
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
