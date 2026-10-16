--!strict
-- Spawners per map id, generated from the named areas and caves (S19, Logic/AreaSpawns): every spawner is
-- a monster group of 1–4. S134i: a region map also holds its Elite II hideouts' spawners (after the area groups).

local AreaSpawns = require("../Logic/AreaSpawns")
local Areas = require("./Areas")
local Maps = require("./Maps")
local Types = require("@self/Types")

export type Spawner = Types.Spawner

local byMap: { [string]: { Spawner } } = {}

for mapId, data in Areas.byMap do
	local map = Maps.get(mapId)
	if map then
		local list = AreaSpawns.region(data, map.size)
		-- S134i: then the Elite II hideouts (their Elite II and guards)
		for _, spawner in AreaSpawns.lairs(data) do
			table.insert(list, spawner)
		end
		byMap[mapId] = list
	end
end
for _, cave in Areas.caves.list do
	byMap[cave.id] = AreaSpawns.cave(cave)
end

return table.freeze({
	byMap = byMap,
})
