--!strict
-- Quests (DESIGN §20): the main story, the daily contracts and (S27) the side quests.

local Types = require("@self/Types")

export type Objective = Types.Objective
export type Reward = Types.Reward
export type MainQuest = Types.MainQuest
export type DailyTemplate = Types.DailyTemplate
export type SideQuest = Types.SideQuest

return table.freeze({
	Main = require("@self/Main"),
	Daily = require("@self/Daily"),
	Side = require("@self/Side"),
})
