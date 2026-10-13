--!strict
-- Level curves (S54, ROZWOJ 8). Pure reader of Data/LevelCurves: identity up to the first anchor (level 20), then
-- log-log interpolation between anchors (a power law), flat above the last anchor. Every level-dependent formula
-- (Mage mana cost, potion interval, heal curve, DEX rating; S87 monster, Elite and EXP curves and the region tables)
-- goes through here. The wiki exporter does not require this
-- module; it reads the values through Logic/Skills, Logic/Potions and Logic/StatCalc.

local Data = require("../Data/LevelCurves")

local LevelCurves = {}

local function anchorsOf(id: string): { Data.Anchor }
	local anchors = Data.curves[id]
	if not anchors then
		error(`LevelCurves: unknown curve "{id}"`, 3)
	end
	return anchors
end

-- Multiplier of curve `id` at character level `level`. Exactly the first anchor's value (1) up to its level, so
-- levels 1-20 keep today's numbers bit for bit. An unknown id is an error, never a silent 1.
function LevelCurves.at(id: string, level: number): number
	local anchors = anchorsOf(id)
	local L = math.max(1, level)
	local first = anchors[1]
	if L <= first[1] then
		return first[2]
	end
	for i = 2, #anchors do
		local a, b = anchors[i - 1], anchors[i]
		if L <= b[1] then
			if L == b[1] then
				return b[2]
			end
			local t = (math.log(L) - math.log(a[1])) / (math.log(b[1]) - math.log(a[1]))
			return math.exp(math.log(a[2]) + t * (math.log(b[2]) - math.log(a[2])))
		end
	end
	return anchors[#anchors][2]
end

function LevelCurves.has(id: string): boolean
	return Data.curves[id] ~= nil
end

-- Sorted curve ids (admin /curves, tests).
function LevelCurves.ids(): { string }
	local ids = {}
	for id in Data.curves do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- Anchors of a curve (tests, admin); frozen.
function LevelCurves.anchors(id: string): { Data.Anchor }
	return anchorsOf(id)
end

-- Up to this level DEX counts in full for crit, attack speed and dodge.
function LevelCurves.dexRatingLevel(): number
	return Data.dexRatingLevel
end

-- Share of DEX that counts for crit, attack speed and dodge: 1 up to dexRatingLevel, then dexRatingLevel / L.
function LevelCurves.dexFactor(level: number): number
	return math.min(1, Data.dexRatingLevel / math.max(1, level))
end

-- S87 (balance plan D5): region tables by map id. `region` is a Data/Monsters.region number (1-4), a region map id
-- or nil; anything else (a boss's 0, an unknown id) gives nil.
function LevelCurves.regionOf(region: number | string | nil): string?
	if type(region) == "number" then
		return Data.regions[region]
	elseif type(region) == "string" then
		return if table.find(Data.regions, region) then region else nil
	end
	return nil
end

-- Chance that a cave Elite group of region `regionId` is a pair (AreaSpawns.cave). An unknown id is an error, so a
-- typo in cave data fails the tests instead of silently using a default.
function LevelCurves.elitePairChance(regionId: string): number
	local value = Data.elitePairChance[regionId]
	if value == nil then
		error(`LevelCurves: unknown region "{regionId}" for elitePairChance`, 2)
	end
	return value
end

-- Multiplier of the Unique and Heroic drop weights of the region's monsters (ItemRoll.rarityWeights); 1 for an
-- unknown region, a boss (0) and nil.
function LevelCurves.dropFactor(region: number | string | nil): number
	local id = LevelCurves.regionOf(region)
	return if id then Data.dropFactor[id] or 1 else 1
end

return LevelCurves
