--!strict
-- Quest EXP budget (S98, docs/DESIGN-15.md §3.2). Quests replace part of the grinding: TARGET is the share of a
-- level's EXP that one-time quests give a player who does the contract, the story and the side quests (daily and
-- weekly contracts are outside the budget). MONSTER_EXP_MUL compensates: monster EXP at character level L is
-- multiplied by it so that the hours of grinding per level stay those of S94. The table between the GENERATED markers
-- is written by `lune run tools/quest_budget.luau` from the real quest data; never edit it by hand.
-- tests/questbudget.spec.luau fails when it is out of date.

-- BEGIN GENERATED (lune run tools/quest_budget.luau)
-- stylua: ignore
local MONSTER_EXP_MUL = table.freeze({ -- index = character level 1-99
	1.000, 1.000, 0.875, 0.950, 0.950, 0.950, 0.950, 0.950, 0.950, 0.950,
	0.950, 0.950, 0.950, 0.950, 0.950, 0.950, 0.950, 0.950, 0.950, 0.943,
	0.953, 0.953, 0.953, 0.960, 0.960, 0.960, 0.966, 0.966, 0.966, 0.964,
	0.964, 0.964, 0.968, 0.968, 0.968, 0.968, 0.973, 0.973, 0.973, 0.973,
	0.973, 0.973, 0.973, 0.973, 0.976, 0.976, 0.976, 0.976, 0.976, 0.975,
	0.975, 0.975, 0.975, 0.975, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977,
	0.977, 0.978, 0.978, 0.978, 0.978, 0.978, 0.978, 0.978, 0.978, 0.978,
	0.978, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977, 0.978,
	0.978, 0.978, 0.978, 0.978, 0.978, 0.978, 0.978, 0.978, 0.978, 0.978,
	0.978, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977, 0.977,
})
-- END GENERATED

return table.freeze({
	TARGET = table.freeze({ contract = 0.12, main = 0.10, side = 0.06, boss = 0.02 }), -- ~30% in total; S109 audits
	BANDS = table.freeze({ { 1, 19 }, { 20, 44 }, { 45, 69 }, { 70, 99 } }), -- budget bands (levels that need EXP)
	MUL_MIN = 0.5,
	MUL_MAX = 1.25,
	MONSTER_EXP_MUL = MONSTER_EXP_MUL,
})
