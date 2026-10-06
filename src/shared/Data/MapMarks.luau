--!strict
-- Own map marks (S25, DESIGN §23): up to Config.Nav.maxMarks per character, saved in `character.mapMarks` as
-- { map, x, z, icon }. No text of their own (no chat filter needed): an icon from this list and a name made
-- from the nearest NPC or monster area.

export type Icon = { id: string, glyph: string, color: string, nameKey: string }

local LIST: { Icon } = {
	{ id = "flag", glyph = "⚑", color = "#E8C25A", nameKey = "worldmap.mark.flag" },
	{ id = "star", glyph = "★", color = "#F2E28A", nameKey = "worldmap.mark.star" },
	{ id = "cross", glyph = "✖", color = "#E0564A", nameKey = "worldmap.mark.cross" },
	{ id = "pick", glyph = "⛏", color = "#C9CED6", nameKey = "worldmap.mark.pick" },
	{ id = "gold", glyph = "💰", color = "#E8C25A", nameKey = "worldmap.mark.gold" },
	{ id = "skull", glyph = "☠", color = "#D8D2E8", nameKey = "worldmap.mark.skull" },
}

local byId: { [string]: Icon } = {}
for _, icon in LIST do
	byId[icon.id] = icon
end

return table.freeze({
	list = LIST,
	get = function(id: string): Icon?
		return byId[id]
	end,
})
