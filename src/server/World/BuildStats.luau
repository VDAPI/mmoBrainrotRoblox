--!strict
-- Numbers of the last build of a map with a height-function terrain (S26): terrain and shell timings, blocks,
-- parts and gathering nodes, filled by the layout and read by the admin command /meadowsstats.

export type Stats = {
	parts: number,
	ms: number,
	terrainMs: number,
	writeMs: number,
	blocks: number,
	shellMs: number,
	builds: number,
	nodes: number,
}

local BuildStats: { [string]: Stats } = {}

return BuildStats
