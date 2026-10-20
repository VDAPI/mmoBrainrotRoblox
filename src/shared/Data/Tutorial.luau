--!strict
-- The first minutes (S155, docs/DESIGN.md §20 "Samouczek"): the numbers of the hands-on tutorial and its reward at
-- level 5. Pure data; the steps, their order and the onboarding funnel live in Logic/Tutorial. The reward is comfort
-- only (a cosmetic title and bound convenience items): no EXP and no gold, so the pace of levels 1-20 stays as it is.
-- Balance numbers: tools/balance_reasons.luau (BALANCE_MODULES, pick REWARD / REWARD_LEVEL).

export type RewardItem = { id: string, n: number }
export type Reward = {
	title: string, -- Data/Cosmetics id of the title cosmetic (obtain.tutorial)
	items: { RewardItem }, -- stacks given bound to the character (a full backpack sends them by mail)
}

local Tutorial = {}

-- The character level that earns the reward (every character made from S155 on, skipped tutorial or not).
Tutorial.REWARD_LEVEL = 5

Tutorial.REWARD = table.freeze({
	title = "title_firststeps",
	items = table.freeze({
		table.freeze({ id = "stone_return", n = 3 }),
		table.freeze({ id = "potion_hp_1", n = 10 }),
	}),
} :: Reward)

-- Studs the player has to walk (steering, Logic/Tutorial.walk) for the "move" step (not a balance number).
Tutorial.MOVE_STUDS = 8
-- Studs between two samples (0.2 s) above which a jump is a pivot or a teleport, not walking (walk speed 16 gives 3.2).
Tutorial.MAX_STEP = 6

-- Seconds the closing "done" hint stays (a touch closes it sooner; not a balance number).
Tutorial.DONE_SECONDS = 6

return Tutorial
