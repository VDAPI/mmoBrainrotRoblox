--!strict
-- Route between maps (S25): a graph with the maps as vertices and every way out of a map (Data/Portals:
-- portals, city gates, cave mouths, cave and chamber exits, dungeon gates) as an edge. Breadth-first search,
-- deterministic (portals of a map in id order), so the guide, the map cards and the tests agree. Maps that
-- are not open (no layout yet, or `isOpen` says no: the client passes "has a sketch") are skipped.

local Maps = require("../Data/Maps")
local Portals = require("../Data/Portals")

local MapRoute = {}

export type Exit = { kind: Portals.Kind, id: string, x: number, z: number, target: string }

export type IsOpen = (mapId: string) -> boolean

local function defaultOpen(mapId: string): boolean
	local map = Maps.get(mapId)
	return map ~= nil and map.buildMode ~= "none"
end

-- Maps along the way from `fromMap` to `toMap`, both included; `{ fromMap }` when they are the same; nil when
-- there is no way (unknown or closed maps).
function MapRoute.path(fromMap: string, toMap: string, isOpen: IsOpen?): { string }?
	local open = isOpen or defaultOpen
	if not Maps.get(fromMap) or not Maps.get(toMap) then
		return nil
	end
	if fromMap == toMap then
		return { fromMap }
	end
	if not open(toMap) then
		return nil
	end
	local previous: { [string]: string } = {}
	local seen: { [string]: boolean } = { [fromMap] = true }
	local queue = { fromMap }
	local head = 1
	while head <= #queue do
		local mapId = queue[head]
		head += 1
		for _, portal in Portals.onMap(mapId) do
			local target = portal.target
			if not seen[target] and Maps.get(target) and open(target) then
				seen[target] = true
				previous[target] = mapId
				if target == toMap then
					local route = { toMap }
					local at = toMap
					while previous[at] do
						at = previous[at]
						table.insert(route, 1, at)
					end
					return route
				end
				table.insert(queue, target)
			end
		end
	end
	return nil
end

-- First portal on `fromMap` leading to `toMap` directly (lowest id), if any.
local function direct(fromMap: string, toMap: string): Portals.Portal?
	for _, portal in Portals.onMap(fromMap) do
		if portal.target == toMap then
			return portal
		end
	end
	return nil
end

-- The way out of `fromMap` to take now on the route to `toMap` (nil when already there or no route).
function MapRoute.nextExit(fromMap: string, toMap: string, isOpen: IsOpen?): Exit?
	local route = MapRoute.path(fromMap, toMap, isOpen)
	if not route or #route < 2 then
		return nil
	end
	local portal = direct(fromMap, route[2])
	if not portal then
		return nil
	end
	return { kind = portal.kind, id = portal.id, x = portal.x, z = portal.z, target = portal.target }
end

-- Number of map changes on the route (0 on the same map, nil without a route).
function MapRoute.hops(fromMap: string, toMap: string, isOpen: IsOpen?): number?
	local route = MapRoute.path(fromMap, toMap, isOpen)
	return if route then #route - 1 else nil
end

-- Ways out of a map (for cards and the map legend).
function MapRoute.exits(mapId: string): { Exit }
	local out: { Exit } = {}
	for _, portal in Portals.onMap(mapId) do
		table.insert(out, { kind = portal.kind, id = portal.id, x = portal.x, z = portal.z, target = portal.target })
	end
	return out
end

return MapRoute
