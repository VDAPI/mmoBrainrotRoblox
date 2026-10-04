--!strict
-- Spawner definition (DESIGN §15.1: point + radius + kind + count + respawn time).

export type Spawner = {
	id: string,
	monster: string, -- Data/Monsters id
	variant: "normal" | "elite" | "elite2",
	level: { min: number, max: number },
	position: { x: number, y: number, z: number }, -- relative to the map offset
	radius: number,
	count: number,
	respawn: { min: number, max: number }, -- seconds
}

return nil
