--!strict
-- How good an item is for a class (S20, DESIGN §5.9 "Better item!"): weighted sum of its stats. Weapon damage
-- counts as damage per second of the class's damage type; flat and % bonuses by class weights; hooks
-- (legendary effects) a flat bonus. Pure.

local Classes = require("../Data/Classes")
local ItemRoll = require("./ItemRoll")
local Items = require("../Data/Items")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

local ItemScore = {}

-- Weight per point of a stat, by class (stats every class likes are in COMMON).
local COMMON: { [string]: number } = {
	vit = 2,
	maxHp = 0.2,
	armor = 0.6,
	mres = 0.5,
	hpRegen = 2,
	dodge = 3,
	moveSpeed = 1,
	expBonus = 0.5,
	dropBonus = 0.5,
	goldBonus = 0.3,
	resFire = 0.4,
	resIce = 0.4,
	resLightning = 0.4,
	resPoison = 0.4,
}

local CLASS: { [string]: { [string]: number } } = {
	Warrior = {
		str = 3,
		physAtk = 3,
		critChance = 3,
		critDmg = 1,
		atkSpeed = 3,
		armorPen = 2,
		lifesteal = 3,
		maxEnergy = 0.5,
		energyRegen = 2,
		accuracy = 1.5,
	},
	Hunter = {
		dex = 3,
		physAtk = 3,
		critChance = 4,
		critDmg = 1.5,
		atkSpeed = 3,
		armorPen = 2,
		lifesteal = 2,
		maxEnergy = 0.5,
		energyRegen = 2,
		accuracy = 2,
	},
	Mage = { int = 3, magAtk = 3, critChance = 3, critDmg = 1, atkSpeed = 2, maxMana = 0.4, manaRegen = 3 },
	Cleric = { int = 3, magAtk = 3, maxMana = 0.4, manaRegen = 3, critChance = 2, atkSpeed = 2 },
}

local WEAPON_WEIGHT = 5 -- per point of damage per second
local HOOK_WEIGHT = 2 -- per point of a legendary effect

function ItemScore.score(item: ItemInstance, classId: string): number
	local stats = ItemRoll.itemStats(item)
	local weights = CLASS[classId] or {}
	local total = 0
	for stat, value in stats.flat do
		total += value * (weights[stat] or COMMON[stat] or 0)
	end
	for stat, value in stats.pct do
		-- % bonuses (e.g. +3% HP) are worth roughly a few flat points each
		total += value * 2 * ((weights[stat] or COMMON[stat] or 0) > 0 and 1 or 0)
	end
	for _, value in stats.hooks do
		total += value * HOOK_WEIGHT
	end
	local weapon = stats.weapon
	if weapon then
		local class = Classes.get(classId)
		local magic = class ~= nil and class.basicAttack.kind == "magic"
		total += (if magic then weapon.mdmg else weapon.dmg) * weapon.speed * WEAPON_WEIGHT
	end
	return total
end

-- True when `candidate` is equippable by the character and scores higher than what it would replace
-- (`equipped` nil = empty slot).
function ItemScore.isUpgrade(candidate: ItemInstance, equipped: ItemInstance?, classId: string, level: number): boolean
	local def = Items.get(candidate.id)
	if not def or not def.slot or def.category ~= "equipment" then
		return false
	end
	if def.classes and not table.find(def.classes, classId) then
		return false
	end
	if ItemRoll.requiredLevel(candidate) > level then
		return false
	end
	if not equipped then
		return true
	end
	return ItemScore.score(candidate, classId) > ItemScore.score(equipped, classId) * 1.02
end

return ItemScore
