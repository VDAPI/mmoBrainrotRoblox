--!strict
-- S105: the city's season for one character, from the story (no save field). Summer as always; snow in the middle of
-- summer once Vaelgrath is beaten (the dragon had no heart: the finale waits), spring once the finale "The First
-- Spring" is handed in. The client draws it for its own character only (CitySeasonController); /season forces it for
-- tests. Pure; tolerant to old and partial quest tables (nil, no fields, text) like Logic/SideQuests.

local Main = require("../Data/Quests/Main")

local CitySeason = {}

export type Season = "summer" | "snow" | "spring"

CitySeason.SEASONS = table.freeze({ "summer", "snow", "spring" })

function CitySeason.of(quests: any): Season
	if type(quests) ~= "table" then
		return "summer"
	end
	local done = tonumber(quests.mainDone) or 0
	local spring = Main.indexOf.firstSpring
	local snow = Main.indexOf.vaelgrath
	if spring and done >= spring then
		return "spring"
	elseif snow and done >= snow then
		return "snow"
	end
	return "summer"
end

-- Whether a text is a season name (the admin's forced season).
function CitySeason.isSeason(value: any): boolean
	return value == "summer" or value == "snow" or value == "spring"
end

return table.freeze(CitySeason)
