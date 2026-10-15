--!strict
-- The shown name of a title (S128): a season title of the arena (Data/Titles seasonArg) carries its season as
-- "{month}.{year}" (Logic/ArenaRules.seasonLabel); without a season (a state not yet read) the plain name
-- ("<nameKey>.plain"), so "{season}" never shows. Every other title is its name key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Text)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)

local TitleText = {}

local function seasonOf(use: Fusion.Use, season: string): string
	local month, year = ArenaRules.seasonLabel(season)
	return Text.get(use, "arena.season.short", { month = month, year = year })
end

-- Inside a Computed. `season` = "YYYYMM" (Titles.argsOf, or the model attribute TitleSeason).
function TitleText.get(use: Fusion.Use, def: TitleData.TitleDef, season: string?): string
	if def.seasonArg then
		if type(season) == "string" and season ~= "" then
			return Text.get(use, def.nameKey, { season = seasonOf(use, season) })
		end
		return Text.get(use, `{def.nameKey}.plain`)
	end
	return Text.get(use, def.nameKey)
end

return TitleText
