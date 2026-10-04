--!strict
-- World maps (DESIGN §3.2). S01 only defines the capital as a flat placeholder; S08 adds the real
-- layouts, portals and the remaining maps. Offsets keep maps >= 3000 studs apart (ARCHITECTURE §8).

export type PvpZone = "green" | "yellow" | "red"

export type MapDef = {
	id: string,
	nameKey: string,
	zone: PvpZone,
	minLevel: number,
	maxLevel: number,
	-- World-space centre of the map.
	offset: { x: number, y: number, z: number },
	-- Playable footprint (studs) used for bounds checks of saved positions.
	size: { x: number, z: number },
	-- Default spawn point relative to offset.
	spawn: { x: number, y: number, z: number },
}

local Maps: { [string]: MapDef } = {
	city = {
		id = "city",
		nameKey = "map.city.name",
		zone = "green",
		minLevel = 1,
		maxLevel = 100,
		offset = { x = 0, y = 0, z = 0 },
		-- 1200 wide: the 512 x 512 city plus the S02 test strip to the east (training meadow + cave).
		size = { x = 1200, z = 512 },
		spawn = { x = 0, y = 4, z = 40 },
	},
}

return table.freeze({
	byId = Maps,
	get = function(id: string): MapDef?
		return Maps[id]
	end,
})
