--!strict
-- Hand-placed NPC spots in the city (S27), next to the generated plan (city.luau is generated, do not edit it):
-- the side quest givers by their buildings. Same shape as city.npcs (x, z, facing, `at` = building or stall id);
-- Town.npcSpot reads both. tests/town.spec checks open ground, reach from the spawn and the distance to the door.

local Types = require("./Types")

local spots: { [string]: Types.Spot } = {
	granary_keeper = { x = 192, z = 104, facing = 270, at = "spichlerz" },
	brother_anzelm = { x = -124, z = -141, facing = 180, at = "swiatynia" },
	fishwife = { x = 76, z = 24, facing = 0, at = "stall_fish" }, -- owner 2026-10-20: in front of the counter
	innkeeper = { x = 152, z = -17, facing = 180, at = "karczma" },
	miller_widow = { x = -194, z = 209, facing = 180, at = "mlyn" },
	stablemaster = { x = 243, z = 23, facing = 0, at = "stajnia" },
	sergeant = { x = 256, z = -33, facing = 180, at = "wartownia" },
	-- S132: the barber at the cloth stall on the market (no NPC of its own), next to the merchant's row
	barber = { x = -15, z = 24, facing = 0, at = "stall_cloth" }, -- owner 2026-10-20: in front of the counter
	-- S126: outside the north stands of Ristalle (they end at z = -106), off the spectators' way out (190, -88),
	-- facing the gate and the street; more than 16 studs from the arena's door point, so no `at`
	arenamaster = { x = 204, z = -96, facing = 135 },
	-- S134k: the Huntmaster beside the contract board on the market (the board stands at 28, -68 facing 180)
	huntmaster = { x = 40, z = -64, facing = 200 },
}

return spots
