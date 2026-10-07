--!strict
-- Starting city plan (S21): generated layout data plus small lookups. See Town/Types and docs/miasto/MIASTO.md.

local Types = require("@self/Types")

export type City = Types.City
export type Lot = Types.Lot
export type Special = Types.Special
export type Spot = Types.Spot

local city: Types.City = require("@self/city")
local extra: { [string]: Types.Spot } = require("@self/npcExtra")

local specialsById: { [string]: Types.Special } = {}
for _, special in city.specials do
	specialsById[special.id] = special
end

local Town = {}

Town.city = city

function Town.special(id: string): Types.Special?
	return specialsById[id]
end

-- NPC spot by NPC id (Data/Npcs ids), or nil when the NPC does not stand in the city. S27: the generated plan
-- first, then the hand-placed spots (Town/npcExtra).
function Town.npcSpot(id: string): Types.Spot?
	return city.npcs[id] or extra[id]
end

-- Every NPC spot (plan and hand-placed), for tests and tools.
function Town.allNpcSpots(): { [string]: Types.Spot }
	local out = table.clone(city.npcs)
	for id, spot in extra do
		out[id] = spot
	end
	return out
end

function Town.gate(target: string): Types.Gate?
	for _, gate in city.gates do
		if gate.target == target then
			return gate
		end
	end
	return nil
end

return Town
