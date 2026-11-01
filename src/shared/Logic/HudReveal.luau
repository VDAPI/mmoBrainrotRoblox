--!strict
-- UI plan phase 4 (`wyglad/UI-PLAN.md` §5 "Nowy gracz", DESIGN §23): the HUD grows with the tutorial and the level.
-- A new character first sees what the fight needs: the portrait, the skill and potion bars, the minimap, the story
-- quests in the tracker, the chat and the ☰ (the settings and the language are there). The Character hub's button comes
-- with the tutorial's "backpack" step (its hint points at it), the other hubs and the tracker's other groups when the
-- tutorial ends or is skipped, and a hub tied to an unlock (Logic/Unlocks `hub`: Rivalry with the arena) from that
-- level. Nothing becomes unreachable: every window key still opens its window and the game menu keeps its tiles.
-- Characters made before the tutorial (no save or a finished one) see everything. Pure (Lune): tests/hudreveal.spec.

local Tutorial = require("./Tutorial")
local Unlocks = require("./Unlocks")

local HudReveal = {}

export type Stage = "start" | "backpack" | "full"

local RANK: { [Stage]: number } = { start = 1, backpack = 2, full = 3 }

-- The tutorial stage a hub's button waits for (Data/UiHubs ids); a hub not listed waits for the end of the tutorial.
HudReveal.HUB_STAGE = table.freeze({ character = "backpack" } :: { [string]: Stage })

-- The tracker's groups (Hud/QuestTracker) shown during the tutorial; the others wait for its end.
HudReveal.TRACKER_EARLY = table.freeze({ quests = true } :: { [string]: boolean })

-- How far the tutorial (character.tutorial, raw) is for the HUD: "start" before its "backpack" step, "backpack" from
-- it (or once the backpack was opened ahead), "full" when it is finished, skipped or missing.
function HudReveal.stage(raw: any): Stage
	if type(raw) ~= "table" then
		return "full"
	end
	local state = Tutorial.sanitize(raw)
	if state.done then
		return "full"
	end
	local pending = state.pending
	if state.step >= Tutorial.indexOf.backpack or (pending ~= nil and pending.backpack == true) then
		return "backpack"
	end
	return "start"
end

-- Whether stage `stage` has reached `need`.
function HudReveal.reached(stage: Stage, need: Stage): boolean
	return RANK[stage] >= RANK[need]
end

-- Whether hub `hubId`'s HUD button shows at `stage` for a character of `level`.
function HudReveal.hub(hubId: string, stage: Stage, level: number): boolean
	if not HudReveal.reached(stage, HudReveal.HUB_STAGE[hubId] or "full") then
		return false
	end
	local need = Unlocks.hubLevel(hubId)
	return need == nil or level >= need
end

-- Whether the tracker's group `id` shows at `stage`.
function HudReveal.trackerGroup(id: string, stage: Stage): boolean
	return stage == "full" or HudReveal.TRACKER_EARLY[id] == true
end

return HudReveal
