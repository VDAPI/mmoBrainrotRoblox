--!strict
-- Weapon pools (S137, DESIGN-18 §4, §9). Pure. The equipped weapon selects the pool of the class (Mage: the weapon
-- element; the others: the main-hand type); no weapon or an unknown one = the class's defaultPool. Members of a pool:
-- base skills with SkillDef.pool == the pool id (its school) or "common", and every path skill of the class (they work
-- in every pool; their node rule stays in Logic/Paths). Ranks, points and bars per pool: Logic/SkillPoints.

local ItemRoll = require("./ItemRoll")
local Items = require("../Data/Items")
local PoolData = require("../Data/SkillPools")
local SkillData = require("../Data/Skills")

type SkillDef = SkillData.SkillDef
type PoolDef = PoolData.PoolDef
type ClassPools = PoolData.ClassPools

export type WeaponTypes = { main: string?, offhand: string? }

local SkillPools = {}

SkillPools.COMMON = PoolData.COMMON

local function classPools(classId: string): ClassPools?
	return PoolData.get(classId)
end

-- The pool definition of a class (nil: unknown class or pool).
function SkillPools.def(classId: string, poolId: string): PoolDef?
	local pools = classPools(classId)
	if not pools then
		return nil
	end
	for _, pool in pools.pools do
		if pool.id == poolId then
			return pool
		end
	end
	return nil
end

-- Pool ids of a class in data order ({} for an unknown class).
function SkillPools.ids(classId: string): { string }
	local out: { string } = {}
	local pools = classPools(classId)
	if pools then
		for _, pool in pools.pools do
			table.insert(out, pool.id)
		end
	end
	return out
end

function SkillPools.defaultPool(classId: string): string?
	local pools = classPools(classId)
	return if pools then pools.defaultPool else nil
end

function SkillPools.version(classId: string): number
	local pools = classPools(classId)
	return if pools then pools.version else 0
end

-- The pool of the class for these weapons (DESIGN-18 §4.1): the first pool whose weapon lists the main-hand type and,
-- when it names an element, has that element; otherwise defaultPool. Unknown class: nil.
function SkillPools.poolOf(classId: string, weapons: WeaponTypes?, element: string?): string?
	local pools = classPools(classId)
	if not pools then
		return nil
	end
	local main = weapons and weapons.main
	if main then
		for _, pool in pools.pools do
			local req = pool.weapon
			if table.find(req.main, main) and (req.element == nil or req.element == element) then
				return pool.id
			end
		end
	end
	return pools.defaultPool
end

-- Main-hand type and element of the equipped weapon (nil when the slot is empty or the item unknown).
function SkillPools.weaponOf(equipment: any): (WeaponTypes, string?)
	if type(equipment) ~= "table" then
		return {}, nil
	end
	local item = equipment.weapon
	if type(item) ~= "table" or type(item.id) ~= "string" then
		return {}, nil
	end
	local def = Items.get(item.id)
	if not def then
		return {}, nil
	end
	return { main = def.type }, ItemRoll.elementOf(item :: any)
end

-- The pool of a character (`class`, `equipment`): what the server switches the bar to on an equipment change.
function SkillPools.activePool(character: any): string?
	local weapons, element = SkillPools.weaponOf(character.equipment)
	return SkillPools.poolOf(character.class, weapons, element)
end

-- Is `skill` a member of the pool (DESIGN-18 §4.1)? Path skills of the class: always (their node decides elsewhere).
function SkillPools.memberDef(classId: string, poolId: string, skill: SkillDef?): boolean
	if skill == nil or skill.class ~= classId or SkillPools.def(classId, poolId) == nil then
		return false
	end
	if skill.path ~= nil then
		return true
	end
	return skill.pool == PoolData.COMMON or skill.pool == poolId
end

function SkillPools.inPool(classId: string, poolId: string, skillId: string): boolean
	return SkillPools.memberDef(classId, poolId, SkillData.get(skillId))
end

-- Members of a pool: the base skills of the pool's plan first (school and common, buying order), then any other base
-- member, then the class's path skills in data order.
function SkillPools.members(classId: string, poolId: string): { string }
	local out: { string } = {}
	local pool = SkillPools.def(classId, poolId)
	if not pool then
		return out
	end
	local seen: { [string]: boolean } = {}
	for _, id in pool.plan do
		if not seen[id] and SkillPools.inPool(classId, poolId, id) then
			seen[id] = true
			table.insert(out, id)
		end
	end
	local list: { SkillDef } = SkillData.byClass[classId] or {}
	for _, skill in list do
		if not seen[skill.id] and skill.path == nil and SkillPools.memberDef(classId, poolId, skill) then
			seen[skill.id] = true
			table.insert(out, skill.id)
		end
	end
	for _, skill in list do
		if not seen[skill.id] and skill.path ~= nil then
			seen[skill.id] = true
			table.insert(out, skill.id)
		end
	end
	return out
end

-- The ladder rung of a skill definition (DESIGN-18 §5): its role code in LADDER or COMMON_LADDER, nil without one.
function SkillPools.ladderOf(def: SkillDef): PoolData.Rung?
	local role = def.role
	if role == nil then
		return nil
	end
	for _, rung in PoolData.LADDER do
		if rung.code == role then
			return rung
		end
	end
	for _, rung in PoolData.COMMON_LADDER do
		if rung.code == role then
			return rung
		end
	end
	return nil
end

-- A pool id that belongs to the class (a client may send anything).
function SkillPools.valid(classId: string, poolId: any): boolean
	return type(poolId) == "string" and SkillPools.def(classId, poolId) ~= nil
end

return SkillPools
