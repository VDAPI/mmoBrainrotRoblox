--!strict
-- Party loot and sharing (DESIGN §17). Pure functions (Lune tests).
--   * every item is assigned separately: candidates = members in range; an item with a class requirement
--     goes to a member of that class (random among several); nobody with the class or no requirement
--     (jewellery, materials) -> random among all candidates,
--   * gold is split evenly, the remainder goes to one random member,
--   * EXP is split evenly (each member then applies their own level-difference multiplier).

local Rng = require("./Rng")

local PartyLoot = {}

export type Candidate = { id: number, classId: string }
export type LootItem = { uid: string, classes: { string }? }

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

-- Splits gold between `n` members: { amount per member }, the remainder added to one random member.
function PartyLoot.splitGold(total: number, n: number, rng: Rng.Rng): { number }
	local count = math.max(1, n)
	local each = math.floor(total / count)
	local shares = table.create(count, each)
	local remainder = total - each * count
	if remainder > 0 then
		local lucky = rng:int(1, count)
		shares[lucky] += remainder
	end
	return shares
end

-- EXP per member before the member's own level-difference multiplier.
function PartyLoot.splitExp(total: number, n: number): number
	return math.floor(total / math.max(1, n))
end

return PartyLoot
