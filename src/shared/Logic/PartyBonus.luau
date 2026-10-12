--!strict
-- Class variety bonus (docs/ROZWOJ.md 7.4, S60). Pure. Counted over the players credited for a kill (monster) or
-- the dungeon winners (boss), the same for each of them, before their own expBonus; quests get none.

local Progression = require("../Data/Progression")

local PartyBonus = {}

-- % EXP: varietyPerClass for each other distinct class, at most varietyMax. Empty class ids are skipped.
function PartyBonus.variety(classIds: { string }): number
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, id in classIds do
		if id ~= "" and not seen[id] then
			seen[id] = true
			count += 1
		end
	end
	if count <= 1 then
		return 0
	end
	return math.min(Progression.varietyMax, Progression.varietyPerClass * (count - 1))
end

function PartyBonus.expMul(classIds: { string }): number
	return 1 + PartyBonus.variety(classIds) / 100
end

return PartyBonus
