--!strict
-- The arena server's map (S127, DESIGN-17 §6): sand, stands and start points, map-relative (the map centre is
-- (0, 0)). One layout per server mode; S130 adds `tournament` (four fields and a lobby). A layout without its own
-- entry falls back to `arena`. The sizes copy the Ristalle (Data/Town city.arena: half 40, stands 14, starts +-25,
-- the way out 72 studs from the centre), so a ranked match looks the same on both. Pure data (Lune); geometry, not
-- balance (tools/balance_reasons NOT_BALANCE).

export type Field = {
	id: string,
	x: number,
	z: number,
	half: number, -- half the side of the square of sand
	stands: number, -- depth of the stands around the sand
	exit: { number }, -- the way out (on the north gate side)
	starts: { { number } }, -- the 1v1 start points, side 1 then side 2
}
-- S130: `lobby` = the stone platform between the fields of a tournament server (where players appear and wait):
-- its centre, its half side and the height of its top; `size` = the side of the whole layout (the map is as large as
-- the largest layout, Data/Maps arena_pit).
export type Lobby = { x: number, z: number, half: number, height: number }
export type Layout = { size: number, fields: { Field }, lobby: Lobby? }

local function field(def: Field): Field
	return def
end

-- S130 (DESIGN-17 §8): a tournament server: four fields of the Ristalle size two by two, `spacing` from the centre on
-- both axes, each with its way out on the gate facing the lobby (gates are in the middle of the north and south sides
-- of the stands), and the lobby in the middle of the cross of open ground between the stands.
local SPACING = 80

local function tourneyField(n: number, sx: number, sz: number): Field
	return field({
		id = `pit{n}`,
		x = sx * SPACING,
		z = sz * SPACING,
		half = 40,
		stands = 14,
		exit = { 0, -sz * 72 },
		starts = { { -25, 0 }, { 25, 0 } },
	})
end

local LAYOUTS: { [string]: Layout } = {
	arena = {
		size = 240,
		fields = {
			field({
				id = "pit1",
				x = 0,
				z = 0,
				half = 40,
				stands = 14,
				exit = { 0, 72 },
				starts = { { -25, 0 }, { 25, 0 } },
			}),
		},
	},
	tournament = {
		size = 280,
		fields = {
			tourneyField(1, -1, -1),
			tourneyField(2, 1, -1),
			tourneyField(3, -1, 1),
			tourneyField(4, 1, 1),
		},
		lobby = { x = 0, z = 0, half = 12, height = 1.2 },
	},
}

local ArenaPit = { LAYOUTS = LAYOUTS }

-- The layout of a server mode (the `arena` layout for a mode without its own).
function ArenaPit.layout(mode: string): Layout
	return LAYOUTS[mode] or LAYOUTS.arena
end

-- S130: the side of the largest layout (the arena_pit map, Data/Maps).
function ArenaPit.maxSize(): number
	local size = 0
	for _, layout in LAYOUTS do
		size = math.max(size, layout.size)
	end
	return size
end

-- One field of a mode's layout, nil when unknown.
function ArenaPit.field(mode: string, id: string): Field?
	for _, f in ArenaPit.layout(mode).fields do
		if f.id == id then
			return f
		end
	end
	return nil
end

local function deepFreeze(value: any): any
	if type(value) == "table" and not table.isfrozen(value) then
		for _, v in value do
			deepFreeze(v)
		end
		table.freeze(value)
	end
	return value
end

deepFreeze(ArenaPit)

return ArenaPit
