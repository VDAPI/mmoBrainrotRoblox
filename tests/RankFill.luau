--!strict
-- Test helper (S137): the ranks the old automatic curve gave (Skills.rankAt at the level) as bought ranks in every
-- weapon pool of the class, for tests written before skill points (paths, model checks). Never game code: a real
-- character buys its ranks with SkillPoints (budget per pool); skillRank reads only members of the pool, so the extra
-- entries of other pools' skills are ignored.

local SkillData = require("../src/shared/Data/Skills")
local SkillPools = require("../src/shared/Logic/SkillPools")
local Skills = require("../src/shared/Logic/Skills")

local RankFill = {}

function RankFill.auto(classId: string, level: number, extra: { any }?): { [string]: { [string]: number } }
	local out: { [string]: { [string]: number } } = {}
	local list: { any } = table.clone(SkillData.byClass[classId] or {})
	for _, skill in extra or {} do
		table.insert(list, skill)
	end
	for _, poolId in SkillPools.ids(classId) do
		local own: { [string]: number } = {}
		for _, skill in list do
			if skill.class == classId then
				local rank = Skills.rankAt(skill, level)
				if rank > 0 then
					own[skill.id] = rank
				end
			end
		end
		out[poolId] = own
	end
	return out
end

-- Fills `character.ranks` (when missing) with RankFill.auto at its level; returns the character.
function RankFill.fill(character: any, extra: { any }?): any
	if character.ranks == nil then
		character.ranks = RankFill.auto(character.class, character.level, extra)
	end
	return character
end

return RankFill
