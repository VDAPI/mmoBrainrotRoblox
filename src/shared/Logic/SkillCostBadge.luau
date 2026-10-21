--!strict
-- Owner 2026-10-21 ("show the skill's cost in the left corner of the bar, mana blue, energy yellow"): the small number
-- in the top-left corner of a skill slot (Hud/SkillBar, Hud/MobileSkills). The cost is the one the server takes and
-- the tooltip shows (Skills.cost after rank, breakpoints, nodes, the item saving and Arcane Charges; a beam: the mana
-- of one tick), rounded up like the tooltip (the bar needs the full amount). Pure.

local SkillCostBadge = {}

-- The resources a badge is drawn for, with their colour (UI/Theme.Resource key).
SkillCostBadge.COLORS = table.freeze({
	mana = "Mana",
	energy = "Energy",
	hp = "Hp",
}) :: { [string]: string }

-- The badge text for `cost` of `resource` ("12", "1.5k", "24k"), nil when there is nothing to show.
function SkillCostBadge.label(cost: number?, resource: string?): string?
	if type(cost) ~= "number" or cost ~= cost or cost == math.huge or cost <= 0 then
		return nil
	end
	if type(resource) ~= "string" or SkillCostBadge.COLORS[resource] == nil then
		return nil
	end
	local n = math.ceil(cost - 1e-6)
	if n < 1000 then
		return tostring(math.max(1, n))
	elseif n < 10000 then
		local tenths = math.floor(n / 100) / 10
		return if tenths == math.floor(tenths) then `{tenths}k` else string.format("%.1fk", tenths)
	end
	return `{math.floor(n / 1000)}k`
end

return SkillCostBadge
