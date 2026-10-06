--!strict
-- Height-function terrains by map (S26): the starting city (Logic/TownTerrain) and the Whispering Meadows
-- (Logic/MeadowsTerrain). Maps without one (built from terrain primitives) answer nil / true, and callers keep their
-- old behaviour (raycasts, y = 0). Pure: monster groups (Logic/AreaSpawns), arrivals, the server's ground
-- lookups and the client read the same numbers.

local MeadowsTerrain = require("./MeadowsTerrain")
local TownTerrain = require("./TownTerrain")

local MapTerrain = {}

-- Ground height (map-relative) at a point, or nil when the map has no height function.
function MapTerrain.height(mapId: string, x: number, z: number): number?
	if mapId == "meadows" then
		return MeadowsTerrain.height(x, z)
	elseif mapId == "city" then
		return TownTerrain.heightAt(x, z)
	end
	return nil
end

-- Water surface at a point (nil when dry or unknown).
function MapTerrain.water(mapId: string, x: number, z: number): number?
	if mapId == "meadows" then
		return MeadowsTerrain.water(x, z)
	end
	return nil
end

-- Whether a monster group or an arriving player can stand here: dry, no cliff within `radius` studs (default 4).
-- Maps without a height function: always true.
function MapTerrain.walkable(mapId: string, x: number, z: number, radius: number?): boolean
	if mapId ~= "meadows" then
		return true
	end
	if not MeadowsTerrain.walkable(x, z) then
		return false
	end
	local r = radius or 4
	if r > 4 then
		for i = 0, 7 do
			local a = i * math.pi / 4
			local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
			if MeadowsTerrain.isWater(px, pz) or MeadowsTerrain.slope(px, pz, 2) > MeadowsTerrain.WALKABLE_SLOPE then
				return false
			end
		end
	end
	return true
end

return MapTerrain
