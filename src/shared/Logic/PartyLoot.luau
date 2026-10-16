--!strict
-- Party loot and sharing (DESIGN §17). Pure functions (Lune tests).
--   * every item is assigned separately: candidates = members in range; an item with a class requirement
--     goes to a member of that class (random among several); nobody with the class or no requirement
--     (jewellery, materials) -> random among all candidates,
--   * S134b: the monster's EXP and gold form a pool that grows by Progression.partyPoolPerMember % for every extra
--     counted member and is split equally between all credited players (each member then applies their own
--     level-difference multiplier and quest budget):
--         credited  pool   each
--         1         100 %  100 %
--         2         150 %   75 %
--         3         200 %  ~67 %
--         4         250 %  ~63 %
--         5         300 %   60 %
--     A member counts for the pool when active (fought: in combat / dealt damage or healed) and not carried (level
--     >= monster level - Progression.partyCarryGap); the others do not grow it and get total / n (the old equal
--     split). Gold uses the same factors, the remainder goes to one random member.

local Progression = require("../Data/Progression")
local Rng = require("./Rng")

local PartyLoot = {}

export type Candidate = { id: number, classId: string }
export type LootItem = { uid: string, classes: { string }? }
-- S134b: one credited player for the pool: their level and whether they fought.
export type Member = { level: number, active: boolean }

-- Returns { [itemUid] = candidate id }.
function PartyLoot.distribute(items: { LootItem }, candidates: { Candidate }, rng: Rng.Rng): { [string]: number }
	local result: { [string]: number } = {}
	if #candidates == 0 then
		return result
	end
	for _, item in items do
		local pool: { Candidate } = {}
		if item.classes and #item.classes > 0 then
			for _, candidate in candidates do
				if table.find(item.classes, candidate.classId) then
					table.insert(pool, candidate)
				end
			end
		end
		if #pool == 0 then
			pool = candidates
		end
		result[item.uid] = pool[rng:int(1, #pool)].id
	end
	return result
end

-- S134b: the pool multiplier of `counted` members: 1 + partyPoolPerMember / 100 x (counted - 1); <= 1 -> 1.
function PartyLoot.poolMul(counted: number): number
	if counted <= 1 then
		return 1
	end
	return 1 + Progression.partyPoolPerMember * (counted - 1) / 100
end

-- S134b: a member grows the pool when active and not carried (level >= monster level - partyCarryGap).
function PartyLoot.counts(member: Member, monsterLevel: number): boolean
	return member.active and member.level >= monsterLevel - Progression.partyCarryGap
end

-- S134b: each member's pool weight (the numerator of their share; the share is total x weight / n): poolMul(counted)
-- for a counted member, 1 for a carried or passive one.
local function weights(members: { Member }, monsterLevel: number): { number }
	local counted = 0
	for _, member in members do
		if PartyLoot.counts(member, monsterLevel) then
			counted += 1
		end
	end
	local pool = PartyLoot.poolMul(counted)
	local result = table.create(#members, 1)
	for i, member in members do
		if PartyLoot.counts(member, monsterLevel) then
			result[i] = pool
		end
	end
	return result
end

-- S134b: EXP of each member (before their own level-difference multiplier): floor(total x weight / n).
function PartyLoot.expShares(total: number, members: { Member }, monsterLevel: number): { number }
	local n = math.max(1, #members)
	local result: { number } = {}
	for i, weight in weights(members, monsterLevel) do
		result[i] = math.floor(total * weight / n)
	end
	return result
end

-- S134b: gold of each member: floor(total x weight / n); the rest of floor(total x sum of weights / n) goes to one
-- random member. An empty list counts as one member (the whole pool).
function PartyLoot.goldShares(total: number, members: { Member }, monsterLevel: number, rng: Rng.Rng): { number }
	local list: { number } = if #members > 0 then weights(members, monsterLevel) else { 1 }
	local n = #list
	local sum, given = 0, 0
	local shares: { number } = {}
	for i, weight in list do
		sum += weight
		shares[i] = math.floor(total * weight / n)
		given += shares[i]
	end
	local remainder = math.floor(total * sum / n) - given
	if remainder > 0 then
		local lucky = rng:int(1, n)
		shares[lucky] += remainder
	end
	return shares
end

-- `n` members who all count for the pool (S134b; level 0 against monster level 0, all active).
local function everyone(n: number): { Member }
	local list: { Member } = {}
	for i = 1, math.max(1, n) do
		list[i] = { level = 0, active = true }
	end
	return list
end

-- Splits gold between `n` members who all count: floor(total x poolMul(n)) split equally, the remainder added to one
-- random member (S134b; solo unchanged).
function PartyLoot.splitGold(total: number, n: number, rng: Rng.Rng): { number }
	return PartyLoot.goldShares(total, everyone(n), 0, rng)
end

-- EXP per member before the member's own level-difference multiplier, all `n` members counted (S134b pool).
function PartyLoot.splitExp(total: number, n: number): number
	return PartyLoot.expShares(total, everyone(n), 0)[1]
end

return PartyLoot
