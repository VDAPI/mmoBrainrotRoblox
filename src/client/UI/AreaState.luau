--!strict
-- The monster area the player stands in (S20, DESIGN §3.6), kept by AreaController and read by the HUD
-- (banner, minimap line).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

local AreaState = {}

-- Current area (nil outside every area).
AreaState.Current = scope:Value(nil :: Areas.Area?)
-- Last area entered with its banner (changes only when a banner should show).
AreaState.Banner = scope:Value(nil :: { area: Areas.Area, token: number }?)

-- Name key to show for a zone (S22: one name per place). On region maps with monster areas the PvP zone
-- sub-names ("Old Road", ...) are hidden: the zone banner and the minimap show the map name and the area
-- banner names the place. Elsewhere (city, caves) the zone's own name stays.
function AreaState.zoneNameKey(zone: { map: string, nameKey: string }, mapNameKey: string?): string
	if Areas.byMap[zone.map] and mapNameKey then
		return mapNameKey
	end
	return zone.nameKey
end

return AreaState
