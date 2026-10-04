--!strict
-- Azgor's Furnace (boss 70): basalt, ember light, magma crystals. Azgor's lava field shrinks this arena in
-- phase 3 (Entities/BossScripts/azgor).

local Build = require(script.Parent.Parent.Build)
local DungeonArena = require(script.Parent.DungeonArena)

return function(ctx: Build.Context)
	DungeonArena(ctx, {
		rock = Enum.Material.Basalt,
		floor = Enum.Material.Basalt,
		column = "#3A2A22",
		light = "#FF7A1A",
		crystal = "#FF5A1A",
		cave = "ashen_cave",
	})
end
