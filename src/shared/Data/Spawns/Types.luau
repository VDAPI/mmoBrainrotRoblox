--!strict
-- Spawner definition (DESIGN §15.1). Since S19 every spawner is a monster group generated from the named
-- areas (Logic/AreaSpawns): 1–4 members that wander, fight and respawn together.

export type Spawner = {
	id: string,
	monster: string, -- Data/Monsters id of the first member (the group's main kind)
	members: { string }?, -- kind of every member (length = count); nil = `monster` for all
	choices: { string }?, -- Elite II: the kind is picked from this list on every respawn
	variant: "normal" | "elite" | "elite2",
	level: { min: number, max: number },
	position: { x: number, y: number, z: number }, -- relative to the map offset
	radius: number,
	count: number,
	respawn: { min: number, max: number }, -- seconds (the whole group after its last member died)
	areaId: string?,
}

return nil
