--!strict
-- Guild banner (S159g, DESIGN §19): an emblem and a colour the leader picks. Shown before the guild tag over the heads of
-- members, in the guild window and in the guild chat. More emblems and colours open with the guild level (looks only).

export type Emblem = { id: string, glyph: string, level: number }
export type Colour = { id: string, hex: string, level: number, nameKey: string }

local EMBLEMS: { Emblem } = {
	{ id = "flag", glyph = "⚑", level = 1 },
	{ id = "swords", glyph = "⚔", level = 1 },
	{ id = "star", glyph = "✦", level = 1 },
	{ id = "clover", glyph = "☘", level = 1 },
	{ id = "cross", glyph = "✠", level = 3 },
	{ id = "sun", glyph = "☀", level = 5 },
	{ id = "moon", glyph = "☾", level = 5 },
	{ id = "frost", glyph = "❄", level = 8 },
	{ id = "hammers", glyph = "⚒", level = 8 },
	{ id = "knight", glyph = "♞", level = 12 },
	{ id = "seal", glyph = "✪", level = 16 },
	{ id = "crown", glyph = "♛", level = 20 },
}

local COLOURS: { Colour } = {
	{ id = "gold", hex = "#E3B341", level = 1 },
	{ id = "crimson", hex = "#C8463C", level = 1 },
	{ id = "azure", hex = "#4A86D4", level = 1 },
	{ id = "emerald", hex = "#4CAF6A", level = 1 },
	{ id = "silver", hex = "#C9CED6", level = 4 },
	{ id = "amber", hex = "#E08A2E", level = 6 },
	{ id = "violet", hex = "#9A6AD4", level = 9 },
	{ id = "teal", hex = "#3FB8AF", level = 12 },
	{ id = "rose", hex = "#D86A9A", level = 15 },
	{ id = "ivory", hex = "#F2E6C8", level = 18 },
} :: any

for _, colour in COLOURS do
	colour.nameKey = `guild.colour.{colour.id}`
end

local emblemById: { [string]: Emblem } = {}
for _, emblem in EMBLEMS do
	emblemById[emblem.id] = emblem
end
local colourById: { [string]: Colour } = {}
for _, colour in COLOURS do
	colourById[colour.id] = colour
end

return table.freeze({
	EMBLEMS = EMBLEMS,
	COLOURS = COLOURS,
	DEFAULT_EMBLEM = "flag",
	DEFAULT_COLOUR = "gold",
	emblem = function(id: string?): Emblem
		return (id and emblemById[id]) or EMBLEMS[1]
	end,
	colour = function(id: string?): Colour
		return (id and colourById[id]) or COLOURS[1]
	end,
	isEmblem = function(id: string): boolean
		return emblemById[id] ~= nil
	end,
	isColour = function(id: string): boolean
		return colourById[id] ~= nil
	end,
})
