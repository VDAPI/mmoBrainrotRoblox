--!strict
-- Where a dead character comes back (S22, DESIGN §3.4). Pure: DeathService measures the death spot (inside the
-- map? under it? in water or a wall? a free spot nearby?) and this decides.
--   "city"       : the capital's spawn (chosen, or no choice in time),
--   "entrance"   : in front of the boss dungeon entrance (death in a dungeon),
--   "spawnPoint" : the nearest spawn point of the map (under or off the map, or blocked with no free spot),
--   "here"       : where the character fell (or the free spot nearby when that place is water or a wall).

local Respawn = {}

export type Choice = "city" | "here"
export type Place = "city" | "entrance" | "spawnPoint" | "here"

export type Spot = {
	inside: boolean, -- inside the map's footprint
	belowFloor: boolean, -- fell under the ground (void, under the terrain)
	blocked: boolean, -- the death spot itself is water or inside geometry
	freeNearby: boolean, -- a free spot exists within the search radius
}

function Respawn.place(biome: string, choice: Choice, spot: Spot): Place
	if choice == "city" then
		return "city"
	end
	if biome == "dungeon" then
		return "entrance"
	end
	if not spot.inside or spot.belowFloor then
		return "spawnPoint"
	end
	if spot.blocked and not spot.freeNearby then
		return "spawnPoint"
	end
	return "here"
end

-- Candidate offsets (studs) around a blocked death spot, nearest first, up to `radius`.
function Respawn.searchOffsets(radius: number): { { number } }
	local out = {}
	local step = 5
	local r = step
	while r <= radius do
		local count = math.max(8, math.floor(2 * math.pi * r / step))
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2
			table.insert(out, { math.cos(a) * r, math.sin(a) * r })
		end
		r += step
	end
	return out
end

return Respawn
