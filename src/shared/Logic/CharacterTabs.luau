--!strict
-- The backpack window's tabs (UI plan phase 3, Studio review 2026-10-31: one window did three jobs at two thirds of
-- the screen). Pure; tested in tests/charactertabs.spec.luau.
--   "backpack": the equipment and the backpack (B opens it here);
--   "stats": stat points and the derived statistics;
--   "sets": the build sets and the title, only once one of them means something.
-- A build set means something from Progression.freeRespecLevel (below it a node refund is free, so a second set
-- gives nothing), or when the second set is the active one (never hide what the player uses). A title means something
-- once one is unlocked.

local Progression = require("../Data/Progression")

local CharacterTabs = {}

CharacterTabs.SETS_LEVEL = Progression.freeRespecLevel
CharacterTabs.DEFAULT = "backpack"

function CharacterTabs.setsShown(level: number?, buildSlot: number?): boolean
	return (level or 1) >= CharacterTabs.SETS_LEVEL or buildSlot == 2
end

function CharacterTabs.titlesShown(unlocked: number): boolean
	return unlocked > 0
end

-- The tab ids shown, in order.
function CharacterTabs.tabs(sets: boolean, titles: boolean): { string }
	local out = { "backpack", "stats" }
	if sets or titles then
		table.insert(out, "sets")
	end
	return out
end

-- The label key of the third tab: what it holds right now.
function CharacterTabs.setsLabel(sets: boolean, titles: boolean): string
	if sets and titles then
		return "character.tab.setsTitles"
	elseif sets then
		return "character.tab.sets"
	end
	return "character.tab.titles"
end

-- The tab to show: the asked one when shown, else the backpack.
function CharacterTabs.pick(asked: string?, shown: { string }): string
	if asked and table.find(shown, asked) then
		return asked
	end
	return CharacterTabs.DEFAULT
end

-- "Spend as the path suggests" and its plan line: only with free points to spend and a plan to follow.
function CharacterTabs.suggestShown(statPoints: number?, hasPlan: boolean): boolean
	return hasPlan and (statPoints or 0) > 0
end

return CharacterTabs
