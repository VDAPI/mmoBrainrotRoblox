--!strict
-- Morvane's Tomb (boss 45): black stone, cold light, ghost crystals.

local Build = require(script.Parent.Parent.Build)
local DungeonArena = require(script.Parent.DungeonArena)

return function(ctx: Build.Context)
	DungeonArena(ctx, {
		rock = Enum.Material.Slate,
		floor = Enum.Material.Basalt,
		column = "#4A4458",
		light = "#9FB6FF",
		crystal = "#9FE0C9",
		cave = "duskwood_cave",
	})
end
