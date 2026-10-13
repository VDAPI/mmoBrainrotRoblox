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
	1.000, 1.000, 0.500, 0.649, 0.649, 0.654, 0.652, 0.652, 0.652, 0.651,
	0.651, 0.650, 0.650, 0.650, 0.650, 0.652, 0.652, 0.652, 0.652, 0.643,
	0.704, 0.704, 0.704, 0.749, 0.749, 0.749, 0.783, 0.783, 0.783, 0.772,
	0.772, 0.772, 0.797, 0.797, 0.797, 0.797, 0.829, 0.829, 0.829, 0.829,
	0.829, 0.829, 0.829, 0.829, 0.832, 0.832, 0.832, 0.832, 0.832, 0.828,
	0.828, 0.828, 0.828, 0.828, 0.839, 0.839, 0.839, 0.839, 0.839, 0.839,
	0.839, 0.847, 0.847, 0.847, 0.847, 0.847, 0.847, 0.847, 0.847, 0.847,
	0.847, 0.842, 0.842, 0.842, 0.842, 0.842, 0.842, 0.842, 0.842, 0.849,
	0.849, 0.849, 0.849, 0.849, 0.849, 0.849, 0.849, 0.849, 0.849, 0.849,
	0.849, 0.842, 0.842, 0.842, 0.842, 0.842, 0.842, 0.842, 0.842,
})
-- END GENERATED

return table.freeze({
	TARGET = table.freeze({ contract = 0.12, main = 0.10, side = 0.06, boss = 0.02 }), -- ~30% in total; S109 audits
	BANDS = table.freeze({ { 1, 19 }, { 20, 44 }, { 45, 69 }, { 70, 99 } }), -- budget bands (levels that need EXP)
	MUL_MIN = 0.5,
	MUL_MAX = 1.25,
	MONSTER_EXP_MUL = MONSTER_EXP_MUL,
})
