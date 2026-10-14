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
	1.000, 1.000, 0.875, 0.649, 0.649, 0.654, 0.621, 0.620, 0.620, 0.651,
	0.651, 0.592, 0.592, 0.592, 0.592, 0.613, 0.613, 0.613, 0.613, 1.231,
	1.151, 1.151, 1.151, 1.060, 1.060, 1.060, 1.043, 1.043, 1.043, 1.043,
	1.043, 1.043, 1.043, 1.043, 1.043, 1.043, 0.980, 0.980, 0.968, 0.968,
	0.978, 0.978, 0.978, 0.902, 0.844, 0.844, 0.844, 0.844, 0.843, 0.844,
	0.844, 0.844, 0.843, 0.843, 0.844, 0.844, 0.844, 0.844, 0.844, 0.844,
	0.844, 0.843, 0.843, 0.843, 0.843, 0.844, 0.844, 0.844, 0.844, 0.844,
	0.844, 0.803, 0.803, 0.803, 0.803, 0.803, 0.803, 0.803, 0.803, 0.804,
	0.804, 0.804, 0.804, 0.804, 0.804, 0.804, 0.804, 0.803, 0.803, 0.803,
	0.803, 0.804, 0.804, 0.804, 0.804, 0.804, 0.804, 0.804, 0.804,
})
-- END GENERATED

return table.freeze({
	TARGET = table.freeze({ contract = 0.12, main = 0.10, side = 0.06, boss = 0.02 }), -- ~30% in total; S109 audited: TARGET met, see docs/BALANS.md
	BANDS = table.freeze({ { 1, 19 }, { 20, 44 }, { 45, 69 }, { 70, 99 } }), -- budget bands (levels that need EXP)
	MUL_MIN = 0.5,
	MUL_MAX = 1.25,
	MONSTER_EXP_MUL = MONSTER_EXP_MUL,
})
