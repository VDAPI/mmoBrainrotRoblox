--!strict
-- Fish per fishing spot (DESIGN §12). The server rolls the fish when the bobber bites; the minigame uses
-- its difficulty: `zone` = green zone width (fraction of the bar), `speed` = indicator sweeps per second.
-- After every hit the zone shrinks by ZONE_SHRINK and the indicator speeds up by SPEED_UP.

export type FishEntry = {
	id: string,
	weight: number,
	rarity: number, -- 1..5, colours the result
	zone: number,
	speed: number,
}

export type Spot = {
	fish: { FishEntry },
	chestChance: number,
}

local spots: { [string]: Spot } = {
	meadows = {
		chestChance = 0.02,
		fish = {
			{ id = "fish_carp", weight = 65, rarity = 1, zone = 0.26, speed = 0.7 },
			{ id = "fish_pike", weight = 30, rarity = 2, zone = 0.22, speed = 0.85 },
			{ id = "fish_goldfin", weight = 2, rarity = 5, zone = 0.14, speed = 1.2 },
		},
	},
	duskwood = {
		chestChance = 0.03,
		fish = {
			{ id = "fish_pike", weight = 50, rarity = 2, zone = 0.22, speed = 0.9 },
			{ id = "fish_eel", weight = 40, rarity = 3, zone = 0.18, speed = 1.0 },
			{ id = "fish_goldfin", weight = 3, rarity = 5, zone = 0.13, speed = 1.3 },
		},
	},
	ashen = {
		chestChance = 0.03,
		fish = {
			{ id = "fish_eel", weight = 40, rarity = 3, zone = 0.18, speed = 1.05 },
			{ id = "fish_magmafin", weight = 50, rarity = 3, zone = 0.16, speed = 1.15 },
			{ id = "fish_goldfin", weight = 3, rarity = 5, zone = 0.12, speed = 1.4 },
		},
	},
	frostpeak = {
		chestChance = 0.04,
		fish = {
			{ id = "fish_magmafin", weight = 30, rarity = 3, zone = 0.16, speed = 1.2 },
			{ id = "fish_icefin", weight = 60, rarity = 4, zone = 0.14, speed = 1.3 },
			{ id = "fish_goldfin", weight = 4, rarity = 5, zone = 0.11, speed = 1.5 },
		},
	},
}

-- Weighted pick with a roll in [0, 1).
local function pick(spot: Spot, roll: number): FishEntry
	local total = 0
	for _, fish in spot.fish do
		total += fish.weight
	end
	local target = roll * total
	for _, fish in spot.fish do
		target -= fish.weight
		if target < 0 then
			return fish
		end
	end
	return spot.fish[#spot.fish]
end

return table.freeze({
	spots = spots,
	get = function(spotId: string): Spot?
		return spots[spotId]
	end,
	pick = pick,
	HITS = 3,
	ZONE_SHRINK = 0.75,
	SPEED_UP = 1.2,
	-- Bite delay range (s) and how long the player has to finish the minigame after the bite.
	BITE_MIN = 3,
	BITE_MAX = 8,
	TIME_LIMIT = 15,
	-- Fastest plausible minigame: three hits need at least this many seconds after the bite.
	MIN_DURATION = 0.6,
	-- Treasure chest: gold = level x CHEST_GOLD, plus essences.
	CHEST_GOLD = 15,
	CHEST_LOOT = {
		{ id = "essence_dust", min = 3, max = 6, chance = 1 },
		{ id = "essence_shard", min = 1, max = 1, chance = 0.35 },
		{ id = "essence_crystal", min = 1, max = 1, chance = 0.05 },
	},
})
