--!strict
-- Spawners per map id. Each map file returns a list of Types.Spawner.

local Types = require("@self/Types")

export type Spawner = Types.Spawner

local byMap: { [string]: { Spawner } } = {
	meadows = require("@self/meadows"),
	meadows_cave = require("@self/meadows_cave"),
	duskwood = require("@self/duskwood"),
	duskwood_cave = require("@self/duskwood_cave"),
}

return table.freeze({
	byMap = byMap,
})
