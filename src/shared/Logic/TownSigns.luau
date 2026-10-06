--!strict
-- Service signs of the starting city (S21): one signpost per building with a service NPC (Town.city.npcs with
-- `at` naming a special building), beside the NPC's spot so it reads together with the NPC. The side is
-- chosen so the post stands on open ground (TownTerrain.isOpen) and clear of every NPC. Pure.

local Town = require("../Data/Town")
local TownGeom = require("./TownGeom")
local TownTerrain = require("./TownTerrain")

local TownSigns = {}

export type Sign = { at: string, x: number, z: number, rot: number, key: string }

TownSigns.SIDE = 4 -- studs from the NPC spot
local CLEAR = 2.5 -- min distance to any NPC spot

local function clearOfNpcs(x: number, z: number): boolean
	for _, spot in Town.city.npcs do
		if (spot.x - x) ^ 2 + (spot.z - z) ^ 2 < CLEAR * CLEAR then
			return false
		end
	end
	return true
end

function TownSigns.list(): { Sign }
	local ids = {}
	for id in Town.city.npcs do
		table.insert(ids, id)
	end
	table.sort(ids)
	local out: { Sign } = {}
	local seen: { [string]: boolean } = {}
	for _, id in ids do
		local spot = Town.city.npcs[id]
		local at = spot.at
		if not at or seen[at] or not Town.special(at) then
			continue
		end
		local fx, fz = TownGeom.front(spot.facing)
		local rx, rz = -fz, fx
		for _, side in { 1, -1, 2, -2 } do
			local x = spot.x + rx * TownSigns.SIDE * side
			local z = spot.z + rz * TownSigns.SIDE * side
			if TownTerrain.isOpen(x, z, 1.5) and clearOfNpcs(x, z) then
				table.insert(out, { at = at, x = x, z = z, rot = spot.facing, key = `town.sign.{at}` })
				seen[at] = true
				break
			end
		end
	end
	return out
end

return TownSigns
