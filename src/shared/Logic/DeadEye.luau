--!strict
-- S144 (DESIGN-18 §7): Dead Eye, the Marksman's keystone (row 8, hook `deadEye` = the health threshold %). Pure. The
-- main hit of a one-target skill (types target and projectile: no traps, areas or the falcon) on a target at the
-- threshold % of its health or more is a sure crit; like Lightning Lance's sure crit it spends nobody's guaranteedCrit
-- (Skills/Context, the model).

local DeadEye = {}

local ONE_TARGET: { [string]: boolean } = { target = true, projectile = true }

-- Does a skill of this type take part (a one-target attack)?
function DeadEye.applies(skillType: string): boolean
	return ONE_TARGET[skillType] == true
end

-- Is this hit a sure crit: the hook on, a main hit of a one-target skill, the target's health % at the threshold or more.
function DeadEye.sure(threshold: number, skillType: string, main: boolean, hpPct: number?): boolean
	return threshold > 0 and main and DeadEye.applies(skillType) and hpPct ~= nil and hpPct >= threshold
end

return table.freeze(DeadEye)
