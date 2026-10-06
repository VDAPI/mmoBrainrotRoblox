--!strict
-- Prints the arrival points of every monster area (Logic/AreaArrival) to paste into Data/Areas/<map> after the
-- areas, roads or terrain change (tests/areaarrival.spec checks they match): lune run tools/arrivals.luau [map]

local process = require("@lune/process")

local AreaArrival = require("../src/shared/Logic/AreaArrival")
local Areas = require("../src/shared/Data/Areas")
local Maps = require("../src/shared/Data/Maps")

local only = process.args[1]
for mapId, data in Areas.byMap do
	if only == nil or only == mapId then
		local map = assert(Maps.get(mapId))
		local computed = AreaArrival.region(data, map.size, map.spawn)
		for _, area in data.areas do
			local a = computed[area.id]
			local old = area.arrive
			local changed = not old or not a or old.x ~= a.x or old.z ~= a.z
			print(
				string.format(
					"%s %-24s %s%s",
					mapId,
					area.id,
					if a then string.format("{ x = %d, z = %d }", a.x, a.z) else "NONE",
					if changed then "   <- changed" else ""
				)
			)
		end
	end
end
