--!strict
-- Hunting ground profiles (S33, DESIGN §3.6): an area marked `profile` in Data/Areas trades EXP for drops or gold.
--   exp  ⚡ "Fast EXP"    : bigger groups, quick respawn, softer monsters, fewer items and less gold;
--   loot ✦ "Better drops" : fewer, tougher monsters, items more often and of the source's top rarity more often;
--   gold ⛁ "More gold"    : monsters with purses, a bit less EXP and fewer items.
-- An area without a profile uses NEUTRAL (all multipliers 1). The server applies the multipliers when a monster
-- spawns (HP, attack), when its group respawns and when it pays out (EXP before the party split, gold, loot);
-- clients only show them. Targets per hour (tests/balance.spec, docs/BALANS.md): exp ≥ 1.25× the EXP/h of loot,
-- loot ≥ 1.6× the top-rarity items/h of the others, gold ≥ 1.5× the gold/h (with the drop sold) of the others.
-- Lune-safe: colours are hex strings (the client turns them into Color3).

local Areas = require("./Areas")

export type ProfileId = "exp" | "loot" | "gold"

export type Profile = {
	id: string,
	icon: string, -- glyph shown before the area name
	color: string, -- hex, icon colour on maps and banners
	nameKey: string, -- "area.profile.<id>"
	descKey: string, -- "area.profile.<id>.desc": what the player feels
	sizeWeights: { [number]: number }, -- group sizes 1-4 (AreaSpawns.GROUP_SIZE_WEIGHTS without a profile)
	respawn: { min: number, max: number }, -- seconds, the whole group (AreaSpawns.RESPAWN without a profile)
	hpMul: number, -- monster HP
	atkMul: number, -- monster attack
	expMul: number, -- EXP of kills (not quests), before the party split
	goldMul: number, -- gold of kills, before the party split
	itemChanceMul: number, -- chance that a kill drops an item (with the killer's drop bonus)
	topTierMul: number, -- weight of the source's highest rarity (never above Rarities.cap)
	materialMul: number, -- amount of every dropped material
}

-- Multipliers only (what an area without a profile uses and what the reward code reads).
export type Mods = {
	hpMul: number,
	atkMul: number,
	expMul: number,
	goldMul: number,
	itemChanceMul: number,
	topTierMul: number,
	materialMul: number,
}

local ORDER: { string } = { "exp", "loot", "gold" }

local byId: { [string]: Profile } = {
	exp = {
		id = "exp",
		icon = "⚡",
		color = "#E8C14A",
		nameKey = "area.profile.exp",
		descKey = "area.profile.exp.desc",
		sizeWeights = { [1] = 10, [2] = 25, [3] = 35, [4] = 30 },
		respawn = { min = 20, max = 30 },
		hpMul = 0.85,
		atkMul = 1,
		expMul = 1,
		goldMul = 0.7,
		itemChanceMul = 0.6,
		topTierMul = 1,
		materialMul = 1,
	},
	loot = {
		id = "loot",
		icon = "✦",
		color = "#5FA8E8",
		nameKey = "area.profile.loot",
		descKey = "area.profile.loot.desc",
		sizeWeights = { [1] = 40, [2] = 35, [3] = 20, [4] = 5 },
		respawn = { min = 45, max = 60 },
		hpMul = 1.25,
		atkMul = 1.1,
		expMul = 0.8,
		goldMul = 1,
		itemChanceMul = 1.7,
		topTierMul = 2,
		materialMul = 1.5,
	},
	gold = {
		id = "gold",
		icon = "⛁",
		color = "#D9A441",
		nameKey = "area.profile.gold",
		descKey = "area.profile.gold.desc",
		sizeWeights = { [1] = 30, [2] = 30, [3] = 25, [4] = 15 },
		respawn = { min = 30, max = 45 },
		hpMul = 1,
		atkMul = 1,
		expMul = 0.85,
		goldMul = 1.9, -- S33: 1.8 left level 19 at 1.497x the gold/h of an area without a profile
		itemChanceMul = 0.8,
		topTierMul = 1,
		materialMul = 1.3,
	},
}

local NEUTRAL: Mods = table.freeze({
	hpMul = 1,
	atkMul = 1,
	expMul = 1,
	goldMul = 1,
	itemChanceMul = 1,
	topTierMul = 1,
	materialMul = 1,
})

for _, profile in byId do
	table.freeze(profile.sizeWeights)
	table.freeze(profile.respawn)
	table.freeze(profile)
end

local function get(id: string?): Profile?
	return if id then byId[id] else nil
end

-- Profile of a named area or a cave by id (nil: none, also for unknown ids and spawns without an area).
local function ofArea(areaId: string?): Profile?
	if not areaId then
		return nil
	end
	local area = Areas.areaById(areaId)
	if area then
		return get(area.profile)
	end
	local cave = Areas.caves.get(areaId)
	return if cave then get(cave.profile) else nil
end

-- Multipliers of an area (NEUTRAL without a profile).
local function modsOf(areaId: string?): Mods
	return ofArea(areaId) or NEUTRAL
end

return table.freeze({
	byId = byId,
	order = ORDER,
	NEUTRAL = NEUTRAL,
	get = get,
	ofArea = ofArea,
	modsOf = modsOf,
})
