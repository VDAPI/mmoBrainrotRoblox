--!strict
-- Hand-placed NPC spots in the city (S27), next to the generated plan (city.luau is generated, do not edit it):
-- the side quest givers by their buildings. Same shape as city.npcs (x, z, facing, `at` = building or stall id);
-- Town.npcSpot reads both. tests/town.spec checks open ground, reach from the spawn and the distance to the door.

local Types = require("./Types")

local spots: { [string]: Types.Spot } = {
	granary_keeper = { x = 192, z = 104, facing = 270, at = "spichlerz" },
	brother_anzelm = { x = -124, z = -141, facing = 180, at = "swiatynia" },
	fishwife = { x = 76, z = 36, facing = 0, at = "stall_fish" },
	innkeeper = { x = 152, z = -17, facing = 180, at = "karczma" },
	miller_widow = { x = -194, z = 209, facing = 180, at = "mlyn" },
	stablemaster = { x = 243, z = 23, facing = 0, at = "stajnia" },
	sergeant = { x = 256, z = -33, facing = 180, at = "wartownia" },
}

return spots
