--!strict
-- Spawners per map id. Each map file returns a list of Types.Spawner.

local Types = require("@self/Types")

export type Spawner = Types.Spawner

local byMap: { [string]: { Spawner } } = {
	city = require("@self/test"),
}

return table.freeze({
	byMap = byMap,
})
