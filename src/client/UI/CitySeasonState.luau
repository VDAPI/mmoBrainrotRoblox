--!strict
-- S105: the season of the city this client shows (Logic/CitySeason from the character's story; /season <auto|summer|
-- snow|spring> forces it for tests through AdminClient "season"). Read by CitySeasonController (flowers, the maypole,
-- the snow) and AmbienceController (the city's mood); nothing is replicated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CitySeason = require(ReplicatedStorage.Shared.Logic.CitySeason)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.State)

local scope = Fusion.scoped(Fusion)

local CitySeasonState = {}

-- The admin's forced season (nil = from the story).
CitySeasonState.Forced = scope:Value(nil :: CitySeason.Season?)

-- The season to show now.
function CitySeasonState.current(): CitySeason.Season
	local forced: any = Fusion.peek(CitySeasonState.Forced)
	if CitySeason.isSeason(forced) then
		return forced :: CitySeason.Season
	end
	return CitySeason.of(State.Get({ "character", "quests" }))
end

-- "auto" (or anything that is not a season) gives the season back to the story.
function CitySeasonState.force(value: any)
	CitySeasonState.Forced:set(if CitySeason.isSeason(value) then value else nil)
end

return CitySeasonState
