--!strict
-- Grimrok's Chamber (boss 20): mossy rock, goblin torches.

local Build = require(script.Parent.Parent.Build)
local DungeonArena = require(script.Parent.DungeonArena)

return function(ctx: Build.Context)
	DungeonArena(ctx, {
		rock = Enum.Material.Rock,
		floor = Enum.Material.Ground,
		column = "#5A5650",
		light = "#FF9A3A",
		crystal = "#7ACB3A",
		cave = "meadows_cave",
	})
end
