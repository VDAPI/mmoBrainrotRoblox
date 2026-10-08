--!strict
-- Height-function terrains by map (S26): the starting city (Logic/TownTerrain), the Whispering Meadows
-- (Logic/MeadowsTerrain) and, since S45, every shaped region with a Data/Terrain/<map> (Logic/RegionTerrain). Maps
-- without one (built from terrain primitives) answer nil / true, and callers keep their old behaviour (raycasts,
-- y = 0). Pure: monster groups (Logic/AreaSpawns), arrivals, the server's ground lookups and the client read the
-- same numbers.

local MeadowsTerrain = require("./MeadowsTerrain")
local RegionTerrain = require("./RegionTerrain")
local TownTerrain = require("./TownTerrain")

local MapTerrain = {}

-- Ground height (map-relative) at a point, or nil when the map has no height function.
function MapTerrain.height(mapId: string, x: number, z: number): number?
	if mapId == "meadows" then
		return MeadowsTerrain.height(x, z)
	elseif mapId == "city" then
		return TownTerrain.heightAt(x, z)
	end
	local region = RegionTerrain.get(mapId)
	if region then
		return region.height(x, z)
	end
	return nil
end

-- Water surface at a point (nil when dry or unknown).
function MapTerrain.water(mapId: string, x: number, z: number): number?
	if mapId == "meadows" then
		return MeadowsTerrain.water(x, z)
	end
	local region = RegionTerrain.get(mapId)
	if region then
		return region.water(x, z)
	end
	return nil
end

-- Whether a map has a height function (the layout, decorations and tools read the ground from it).
function MapTerrain.has(mapId: string): boolean
	return mapId == "meadows" or mapId == "city" or RegionTerrain.has(mapId)
end

-- Whether a monster group or an arriving player can stand here: dry, no cliff within `radius` studs (default 4).
-- On shaped regions (S45) also no water of the terrain (marsh pools, basins) within RegionTerrain.WATER_CLEARANCE
-- and (S46) no lava or glowing crack within RegionTerrain.LAVA_CLEARANCE (region.walkable) or on the ring.
-- Maps without a height function: always true.
function MapTerrain.walkable(mapId: string, x: number, z: number, radius: number?): boolean
	if mapId == "meadows" then
		if not MeadowsTerrain.walkable(x, z) then
			return false
		end
		local r = radius or 4
		if r > 4 then
			for i = 0, 7 do
				local a = i * math.pi / 4
				local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
				if
					MeadowsTerrain.isWater(px, pz)
					or MeadowsTerrain.slope(px, pz, 2) > MeadowsTerrain.WALKABLE_SLOPE
				then
					return false
				end
			end
		end
		return true
	end
	local region = RegionTerrain.get(mapId)
	if not region then
		return true
	end
	if not region.walkable(x, z) then
		return false
	end
	local r = radius or 4
	if r > 4 then
		for i = 0, 7 do
			local a = i * math.pi / 4
			local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
			if region.slope(px, pz, 2) > region.WALKABLE_SLOPE or region.lavaDistance(px, pz) < 0 then
				return false
			end
		end
	end
	return region.dryAround(x, z, RegionTerrain.WATER_CLEARANCE)
end

return MapTerrain
