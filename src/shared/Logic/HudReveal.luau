--!strict
-- UI plan phase 4 (`wyglad/UI-PLAN.md` §5 "Nowy gracz", DESIGN §23): the HUD grows with the tutorial. A new character
-- first sees what the fight needs: the portrait, the skill and potion bars, the minimap, the story quests in the
-- tracker, the chat and the ☰ (the settings and the language are there). Owner 2026-11-10: the window hubs are gone,
-- so the reveal goes by the bar's own buttons (Logic/HudMenu.BAR), each with the stage its hub had: the backpack and
-- the skills (the Character hub) with the tutorial's "backpack" step (its hint points at the backpack), the world map,
-- the quests and the Dragon Shop, and the tracker's other groups, when the tutorial ends or is skipped. Nothing becomes
-- unreachable: every window key still opens its window and the game menu keeps its tiles from the start. Characters
-- made before the tutorial (no save or a finished one) see everything. Pure (Lune): tests/hudreveal.spec.

local Tutorial = require("./Tutorial")

local HudReveal = {}

export type Stage = "start" | "backpack" | "full"

local RANK: { [Stage]: number } = { start = 1, backpack = 2, full = 3 }

-- The tutorial stage a bar button waits for; a button not listed waits for the end of the tutorial.
HudReveal.BUTTON_STAGE = table.freeze({
	menu = "start",
	inventory = "backpack",
	skills = "backpack",
} :: { [string]: Stage })

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

-- Whether the bar's button `id` shows at `stage`.
function HudReveal.button(id: string, stage: Stage): boolean
	return HudReveal.reached(stage, HudReveal.BUTTON_STAGE[id] or "full")
end

-- Whether the tracker's group `id` shows at `stage`.
function HudReveal.trackerGroup(id: string, stage: Stage): boolean
	return stage == "full" or HudReveal.TRACKER_EARLY[id] == true
end

return HudReveal
