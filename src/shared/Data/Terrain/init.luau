--!strict
-- Registry of the shaped region terrains (S45) read by Logic/RegionTerrain. Only maps on the shared engine are
-- listed; the Whispering Meadows keep their own Logic/MeadowsTerrain (Data/Terrain/meadows stays outside), the city
-- has Logic/TownTerrain. A new region: Data/Terrain/<map>.luau (types in Types) + one line here.

local Types = require("@self/Types")

export type Shape = Types.Shape

local byMap: { [string]: Types.Shape } = {
	duskwood = require("@self/duskwood"),
	ashen = require("@self/ashen"), -- S46
}

return {
	byMap = byMap,
}
