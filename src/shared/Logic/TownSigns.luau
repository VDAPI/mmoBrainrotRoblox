--!strict
-- Service signs of the starting city (S21): one signpost per building with a service NPC (Town.city.npcs with
-- `at` naming a special building), beside the NPC's spot so it reads together with the NPC. The side is
-- chosen so the post stands on open ground (TownTerrain.isOpen) and clear of every NPC. Pure.
-- Owner 2026-10-21 (the "Kuźnia" board covered the smith from the front): the post stands far enough to the side that
-- its 7-stud board clears the NPC (Logic/SignSpots.covers, every NPC spot of the plan and of Town/npcExtra).

local SignSpots = require("./SignSpots")
local Town = require("../Data/Town")
local TownGeom = require("./TownGeom")
local TownTerrain = require("./TownTerrain")

local TownSigns = {}

export type Sign = { at: string, x: number, z: number, rot: number, key: string }

-- Studs from the NPC spot to the post: half the board, the NPC's footprint and a stud of air.
TownSigns.SIDE = SignSpots.BOARD_W / 2 + SignSpots.NPC_RADIUS + 1.5

local function clearOfNpcs(x: number, z: number, rot: number): boolean
	local sign = { x = x, z = z, rot = rot }
	for _, spot in Town.allNpcSpots() do
		if SignSpots.covers(sign, spot.x, spot.z) then
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
			-- the post and both ends of its board on open ground (the board must not reach into a wall)
			local half = SignSpots.BOARD_W / 2
			local open = TownTerrain.isOpen(x, z, 1.5)
				and TownTerrain.isOpen(x + rx * half, z + rz * half, 0.5)
				and TownTerrain.isOpen(x - rx * half, z - rz * half, 0.5)
			if open and clearOfNpcs(x, z, spot.facing) then
				table.insert(out, { at = at, x = x, z = z, rot = spot.facing, key = `town.sign.{at}` })
				seen[at] = true
				break
			end
		end
	end
	return out
end

return TownSigns
