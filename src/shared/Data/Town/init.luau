--!strict
-- Starting city plan (S21): generated layout data plus small lookups. See Town/Types and docs/miasto/MIASTO.md.

local Types = require("@self/Types")

export type City = Types.City
export type Lot = Types.Lot
export type Special = Types.Special
export type Spot = Types.Spot

local city: Types.City = require("@self/city")

local specialsById: { [string]: Types.Special } = {}
for _, special in city.specials do
	specialsById[special.id] = special
end

local Town = {}

Town.city = city

function Town.special(id: string): Types.Special?
	return specialsById[id]
end

-- NPC spot by NPC id (Data/Npcs ids), or nil when the NPC does not stand in the city.
function Town.npcSpot(id: string): Types.Spot?
	return city.npcs[id]
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
