--!strict
-- Category rules of skill effects (S53, ROZWOJ 3.4 and 7.1), a helper of tests/effectstack.spec and tests/paths.spec
-- (not a spec itself). problems(skill, nodes?) lists every effect whose category does not fit: side, kind, stats, pct
-- mode, a missing category on a party / enemy effect, mixed pct in one kind/category. S71: path node effects
-- (modify.bp effect / selfEffect / allyEffect / behindEffect) pass the same rules with their skill.

local BuffCategories = require("../src/shared/Data/BuffCategories")
local Skills = require("../src/shared/Logic/Skills")

local EffectCategoryRules = {}

-- Kinds that a party / enemy effect must categorise.
local CATEGORISED = { statBuff = true, damageReduction = true, vulnerability = true, armorBreak = true, slow = true }

-- Category problems of a skill's effects and breakpoint effects (ROZWOJ 3.4, 7.1); `nodes` (S71) adds the modify.bp
-- of path nodes on that skill, checked like a breakpoint option.
function EffectCategoryRules.problems(skill: any, nodes: { { id: string, bp: any } }?): { string }
	local out: { string } = {}
	local seenPct: { [string]: boolean } = {}
	local function check(effect: any, side: string, where: string)
		local name = `{skill.id} {where} {effect.kind}`
		local id = effect.category
		local category = BuffCategories.get(id)
		if side == "self" and id ~= "own" then
			table.insert(out, `{name}: self effect without own`)
		end
		if id == "own" and side ~= "self" then
			table.insert(out, `{name}: own outside self`)
		end
		if id ~= nil and category == nil then
			table.insert(out, `{name}: unknown category {id}`)
		end
		if category and category.id ~= "own" then
			if category.side == "ally" and side ~= "allies" then
				table.insert(out, `{name}: ally category on {side}`)
			elseif category.side == "enemy" and side ~= "enemy" then
				table.insert(out, `{name}: enemy category on {side}`)
			end
			if category.kind ~= effect.kind then
				table.insert(out, `{name}: kind differs from {category.id}`)
			end
			if category.stats then
				for stat in effect.stats or {} do
					if not table.find(category.stats, stat) then
						table.insert(out, `{name}: stat {stat} outside {category.id}`)
					end
				end
			end
			if category.mode == "points" and effect.pct == true then
				table.insert(out, `{name}: pct in points category`)
			elseif category.mode == "pct" and effect.pct ~= true then
				table.insert(out, `{name}: no pct in pct category`)
			end
		end
		if (side == "allies" or side == "enemy") and CATEGORISED[effect.kind] and id == nil then
			table.insert(out, `{name}: missing category`)
		end
		if id then
			local key = `{effect.kind}/{id}`
			local pct = effect.pct == true
			if seenPct[key] ~= nil and seenPct[key] ~= pct then
				table.insert(out, `{name}: mixed pct in {key}`)
			end
			seenPct[key] = pct
		end
	end
	for _, effect in skill.effects or {} do
		check(effect, Skills.effectSide(skill, effect), "effects")
	end
	local function checkBp(bp: any, where: string)
		if bp.effect then
			check(bp.effect, Skills.effectSide(skill, bp.effect), where)
		end
		if bp.selfEffect then
			check(bp.selfEffect, "self", where)
		end
		if bp.allyEffect then
			check(bp.allyEffect, "allies", where)
		end
		if bp.behindEffect then -- S73 (Party Bastion, S75)
			check(bp.behindEffect, "allies", where)
		end
	end
	for _, level in Skills.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints and skill.breakpoints[level]
		for _, option in { "a", "b" } do
			local bp = pair and (pair :: any)[option]
			if bp then
				checkBp(bp, `bp{level}{option}`)
			end
		end
	end
	for _, node in nodes or {} do
		checkBp(node.bp, `node {node.id}`)
	end
	return out
end

return EffectCategoryRules
