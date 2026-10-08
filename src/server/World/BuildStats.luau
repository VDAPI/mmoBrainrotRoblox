--!strict
-- Numbers of the last build of a map with a height-function terrain (S26): terrain and shell timings, blocks,
-- parts and gathering nodes, filled by the layout and read by the admin commands /meadowsstats and (S45)
-- /regionstats. `background` is the wall-clock time of a background build (World/WorldBuilder), trees and lights
-- the generator's big trees and lights.

export type Stats = {
	parts: number,
	ms: number,
	terrainMs: number,
	writeMs: number,
	blocks: number,
	shellMs: number,
	builds: number,
	nodes: number,
	trees: number?,
	lights: number?,
	background: number?,
}

local BuildStats: { [string]: Stats } = {}

return BuildStats
