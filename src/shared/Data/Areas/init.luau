--!strict
-- Named monster areas, roads and cave entrances per region map, and the caves (S19). See Areas/Types.

local Caves = require("@self/Caves")
local Types = require("@self/Types")

export type Area = Types.Area
export type MapAreas = Types.MapAreas
export type Cave = Types.Cave
export type Road = Types.Road
export type CaveEntrance = Types.CaveEntrance

local byMap: { [string]: Types.MapAreas } = {
	meadows = require("@self/meadows"),
	duskwood = require("@self/duskwood"),
	ashen = require("@self/ashen"),
	frostpeak = require("@self/frostpeak"),
}

-- Entrance of a cave on its region map.
local function entranceOf(caveId: string): Types.CaveEntrance?
	local cave = Caves.get(caveId)
	local region = cave and byMap[cave.region]
	if not region then
		return nil
	end
	for _, entrance in region.caves do
		if entrance.cave == caveId then
			return entrance
		end
	end
	return nil
end

-- Point on the region map in front of a cave mouth (where players leaving the cave arrive).
local function arrivalOf(caveId: string): { x: number, z: number }?
	local entrance = entranceOf(caveId)
	if not entrance then
		return nil
	end
	local angle = math.rad(entrance.rot)
	-- The mouth opens towards -Z rotated by `rot` degrees around Y.
	local lookX, lookZ = -math.sin(angle), -math.cos(angle)
	return { x = entrance.x + lookX * 26, z = entrance.z + lookZ * 26 }
end

-- Area at a map-relative point (first match), for banners and the map.
local function areaAt(mapId: string, x: number, z: number): Types.Area?
	local data = byMap[mapId]
	if not data then
		return nil
	end
	for _, area in data.areas do
		local r = area.rect
		if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
			return area
		end
	end
	return nil
end

return table.freeze({
	byMap = byMap,
	caves = Caves,
	entranceOf = entranceOf,
	arrivalOf = arrivalOf,
	areaAt = areaAt,
})
