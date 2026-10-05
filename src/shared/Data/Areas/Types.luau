--!strict
-- Named monster areas and map features (S19, DESIGN §3.5–§3.6). One source of truth for monster groups
-- (Logic/AreaSpawns -> Data/Spawns), roads drawn by the layouts, cave entrances and the world map (S20).
-- Coordinates are map-relative studs.

export type Circle = { x: number, z: number, r: number }

export type Road = { points: { number }, width: number, material: string }

export type Area = {
	id: string,
	nameKey: string,
	lv: { number }, -- { min, max }
	kinds: { string }, -- normal monster kinds (2–3)
	rect: { number }, -- { x1, z1, x2, z2 }
	groups: number,
	landmark: { x: number, z: number }?,
}

-- Entrance of a cave on its region map; the mouth faces `rot` degrees (0 = the opening looks to -Z).
export type CaveEntrance = { cave: string, x: number, z: number, rot: number }

export type MapAreas = {
	map: string,
	roads: { Road },
	lakes: { Circle },
	avoid: { Circle }, -- portals, spawn points, buildings: no monster groups here
	caves: { CaveEntrance },
	areas: { Area },
}

export type Room = { x: number, z: number, r: number, h: number }

export type Cave = {
	id: string, -- map id
	region: string, -- region map id
	nameKey: string,
	levels: { number }, -- { min, max }
	normal: { string }, -- 2–3 normal kinds (groups of 1–4)
	elites: { string }, -- exactly 2 elite kinds (3–5 groups of 1–2)
	elite2: { string }, -- 1–2 kinds; one Elite II at a time, picked on every respawn
	eliteGroups: number,
	ores: { string }, -- gathering node kinds
	oreCount: number,
	-- Generated caves (CaveTemplate): seed, terrain material and decoration theme; the boss caves keep
	-- their hand-made layouts and list their rooms here.
	seed: number?,
	material: string?,
	theme: string?,
	rooms: { Room }?, -- rooms[1] is the entrance; boss caves: the last room is the dungeon antechamber
	boss: boolean, -- last cave of the region with the boss dungeon gate
}

return nil
