--!strict
-- Quests (DESIGN §20): the main story and the daily contracts.

local Types = require("@self/Types")

export type Objective = Types.Objective
export type Reward = Types.Reward
export type MainQuest = Types.MainQuest
export type DailyTemplate = Types.DailyTemplate

return table.freeze({
	Main = require("@self/Main"),
	Daily = require("@self/Daily"),
})
