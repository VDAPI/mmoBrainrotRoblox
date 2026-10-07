--!strict
-- What an hour of grinding in a hunting ground gives (S33, DESIGN §3.6): the S32 fight model (Logic/FightSim) with
-- an area profile (Data/AreaProfiles). Pure, expected values, no randomness. Used by tests/balance.spec (profile
-- targets), tools/balance_report (docs/BALANS.md) and the admin commands /areainfo and /areasim.
--
-- One fight = the expected group of the area (profile group sizes, HP and attack) + rest to full HP + a break +
-- the walk to the next living group. A faster respawn keeps more groups alive, so the walk is shorter:
-- WALK x sqrt(respawn / default respawn).

local AreaProfiles = require("../Data/AreaProfiles")
local AreaSpawns = require("./AreaSpawns")
local Exp = require("./Exp")
local FightSim = require("./FightSim")
local ItemRoll = require("./ItemRoll")
local ItemValue = require("./ItemValue")
local Items = require("../Data/Items")
local LootTables = require("../Data/LootTables")
local MonsterStats = require("./MonsterStats")
local Monsters = require("../Data/Monsters")
local Rarities = require("../Data/Rarities")
local Stats = require("../Data/Stats")

local AreaRates = {}

-- Seconds between two fights and of the walk to the next group (same as tests/Balance).
AreaRates.BREAK = 1
AreaRates.WALK = 6

export type Rates = {
	profile: string?, -- profile id, nil = none
	level: number, -- monster (spawner) level
	members: number, -- monsters per fight
	secondsPerKill: number,
	killsPerHour: number,
	hpLostPerFight: number, -- share of max HP
	expPerKill: number,
	expPerHour: number,
	coinGoldPerHour: number, -- gold dropped by the monsters
	dropGoldPerHour: number, -- merchant value of the items and materials
	goldPerHour: number, -- both
	itemsPerHour: number,
	topPerHour: number, -- items of the source's highest rarity (Unique for normal monsters)
}

local function respawnMid(respawn: { min: number, max: number }): number
	return (respawn.min + respawn.max) / 2
end

-- Walk to the next living group (seconds) in an area of `profile`.
function AreaRates.walkSeconds(profile: AreaProfiles.Profile?): number
	if not profile then
		return AreaRates.WALK
	end
	return AreaRates.WALK * math.sqrt(respawnMid(profile.respawn) / respawnMid(AreaSpawns.RESPAWN))
end

-- Expected items per kill of `variant` with the profile's item chance (and `dropBonus` %), and the share of them
-- of the source's highest rarity.
function AreaRates.itemsPerKill(variant: string, mods: AreaProfiles.Mods, dropBonus: number?): (number, number)
	local drops = Rarities.itemDrops[variant] or Rarities.itemDrops.normal
	local chance = math.min(1, drops.chance * (1 + (dropBonus or 0) / 100) * mods.itemChanceMul)
	local count = chance * ((drops.min + drops.max) / 2 + (drops.extra or 0))
	local weights = ItemRoll.rarityWeights(variant, mods.topTierMul)
	local cap = Rarities.cap[variant] or Rarities.cap.normal
	local total, top, topRarity = 0, 0, 0
	for rarity, w in weights do
		total += w
		if w > 0 and rarity <= cap and rarity > topRarity then
			topRarity, top = rarity, w
		end
	end
	return count, if total > 0 then top / total else 0
end

local function tierId(baseType: string, ilvl: number): string
	return `{baseType}_{Items.generate.tierFor(math.max(1, ilvl))}`
end

-- Expected merchant value of the items and materials of one kill (cf. tests/Balance.dropValue, with the profile).
function AreaRates.dropValue(monsterLevel: number, variant: string, mods: AreaProfiles.Mods, partId: string?): number
	local count = AreaRates.itemsPerKill(variant, mods)
	local weights = ItemRoll.rarityWeights(variant, mods.topTierMul)
	local slots = LootTables.byId.wolf.slotWeights
	local wTotal, slotTotal = 0, 0
	for _, w in weights do
		wTotal += w
	end
	for _, w in slots do
		slotTotal += w
	end
	local low, high = ItemRoll.dropLevelRange(monsterLevel, variant)
	local ilvl = math.floor((low + high) / 2)
	local value = 0
	for rarity, w in weights do
		for slot, sw in slots do
			local base = if slot == "weapon"
				then "sword1h"
				elseif slot == "offhand" then "shield"
				elseif slot == "ring" or slot == "necklace" or slot == "talisman" then slot
				else `{slot}_heavy`
			local def = Items.get(tierId(base, ilvl))
			if def then
				value += (w / wTotal) * (sw / slotTotal) * ItemValue.equipment(def, ilvl, rarity, 0)
			end
		end
	end
	local materials = 0
	local tableDef = LootTables.byId[partId or "wolf"] or LootTables.byId.wolf
	local list = table.clone(tableDef.materials)
	for _, mat in (tableDef.variantMaterials[variant] or {}) :: { LootTables.MaterialDrop } do
		table.insert(list, mat)
	end
	for _, mat in list do
		local def = Items.get(mat.id)
		if def then
			materials += mat.chance * (mat.min + mat.max) / 2 * mods.materialMul * (def.price or 0)
		end
	end
	return count * value + materials
end

-- Rates of a player (FightSim.Player) grinding normal groups of `kind` (a Data/Monsters entry or a kind table)
-- at spawner level `level` in a hunting ground of `profileId` (nil = none).
function AreaRates.rates(
	p: FightSim.Player,
	kind: any,
	level: number,
	profileId: string?,
	skill: number?,
	dropBonus: number?
): Rates
	local profile = AreaProfiles.get(profileId)
	local mods: AreaProfiles.Mods = profile or AreaProfiles.NEUTRAL
	local fight = FightSim.expectedGroup(p, kind, level, skill, if profile then profile.sizeWeights else nil, mods)
	local regen = Stats.Formula.hpRegenPct / 100
	local perFight = fight.seconds + fight.hpLost / regen + AreaRates.BREAK + AreaRates.walkSeconds(profile)
	local secondsPerKill = perFight / fight.members
	local monsterLevel = MonsterStats.compute(kind, level, "normal").level
	local kindReward = MonsterStats.kindReward(kind)
	local expPerKill = Exp.monsterExp(monsterLevel, "normal")
		* kindReward
		* mods.expMul
		* Exp.levelDiffMultiplier(p.level, monsterLevel)
	local coinPerKill = MonsterStats.gold(monsterLevel, "normal", 0.5)
		* kindReward
		* mods.goldMul
		* MonsterStats.goldLevelMultiplier(p.level, monsterLevel)
	local dropPerKill = AreaRates.dropValue(monsterLevel, "normal", mods, kind.lootTable)
	local items, topShare = AreaRates.itemsPerKill("normal", mods, dropBonus)
	local killsPerHour = 3600 / secondsPerKill
	return {
		profile = profileId,
		level = monsterLevel,
		members = fight.members,
		secondsPerKill = secondsPerKill,
		killsPerHour = killsPerHour,
		hpLostPerFight = fight.hpLost,
		expPerKill = expPerKill,
		expPerHour = expPerKill * killsPerHour,
		coinGoldPerHour = coinPerKill * killsPerHour,
		dropGoldPerHour = dropPerKill * killsPerHour,
		goldPerHour = (coinPerKill + dropPerKill) * killsPerHour,
		itemsPerHour = items * killsPerHour,
		topPerHour = items * topShare * killsPerHour,
	}
end

-- Rates of a named area for a player: its first kind at the player's level clamped to the area's range.
function AreaRates.forArea(
	p: FightSim.Player,
	area: { lv: { number }, kinds: { string }, profile: string? },
	skill: number?,
	dropBonus: number?
): Rates?
	local kind = Monsters.get(area.kinds[1])
	if not kind then
		return nil
	end
	local level = math.clamp(p.level, area.lv[1], area.lv[2])
	return AreaRates.rates(p, kind, level, area.profile, skill, dropBonus)
end

return AreaRates
