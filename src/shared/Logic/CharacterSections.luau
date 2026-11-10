--!strict
-- The backpack window's sections (owner 2026-11-10: the tabs of UI plan phase 3 are gone; the equipment, the backpack
-- and the statistics stand in one window again, as before 2026-10-31, and what is secondary folds under one header:
-- UI/Components/Section, Logic/SectionFold). Pure; tested in tests/charactersections.spec.luau.
--   "charStats": stat points and the derived statistics, open by default; folded, one line: the free points;
--   "charSets": the build sets and the title, only once one of them means something; folded, one line: the active set
--     and the worn title.
-- The columns follow the screen on touch (`columns`): three on a wide tablet, two on a phone (the statistics under the
-- equipment), the stat rows on two lines in a narrow column.
-- A build set means something from Progression.freeRespecLevel (below it a node refund is free, so a second set gives
-- nothing), or when the second set is the active one (never hide what the player uses). A title means something once
-- one is unlocked (UI plan phase 3, Studio review 2026-10-31).

local Progression = require("../Data/Progression")

local CharacterSections = {}

CharacterSections.SETS_LEVEL = Progression.freeRespecLevel

function CharacterSections.setsShown(level: number?, buildSlot: number?): boolean
	return (level or 1) >= CharacterSections.SETS_LEVEL or buildSlot == 2
end

function CharacterSections.titlesShown(unlocked: number): boolean
	return unlocked > 0
end

-- The title key of the sets and title section: what it holds right now (nil: the section does not show).
function CharacterSections.setsLabel(sets: boolean, titles: boolean): string?
	if sets and titles then
		return "character.section.setsTitle"
	elseif sets then
		return "character.section.sets"
	elseif titles then
		return "character.section.title"
	end
	return nil
end

-- The folded statistics' badge: the free stat points, nil without any (the header stays bare).
function CharacterSections.pointsBadge(statPoints: number?): number?
	if statPoints and statPoints > 0 then
		return statPoints
	end
	return nil
end

-- A part of the folded sets and title line: a text key with its arguments, or `title`: the worn title's own name.
export type Part = { key: string?, args: { [string]: any }?, title: string? }

-- The folded sets and title line, in order: the active set while the sets show, the worn title while titles do
-- (`titleId` nil: none worn).
function CharacterSections.setsSummary(sets: boolean, titles: boolean, buildSlot: number?, titleId: string?): { Part }
	local out: { Part } = {}
	if sets then
		table.insert(out, { key = "buildset.set", args = { n = if buildSlot == 2 then 2 else 1 } })
	end
	if titles then
		table.insert(out, if titleId then { title = titleId } else { key = "character.section.noTitle" })
	end
	return out
end

-- The window's columns in virtual px (UI/Screens/CharacterWindow; `pad`, `gutter`, `narrowGutter`: Theme.Padding.Large,
-- Large, Medium): the left column (name, equipment, sets), the backpack, the statistics on the right; `scrollPad` is a
-- scrolling column's room for its bar; a stat row stands on one line from `statsOneLine` (the name with its "i" about
-- 170, StatAllocator's controls 214).
CharacterSections.LAYOUT = table.freeze({
	pad = 22,
	left = 260,
	middle = 500,
	gutter = 22,
	narrowGutter = 14,
	narrowLeftMin = 220,
	narrowLeftMax = 400,
	statsMin = 340,
	statsOneLine = 380,
	scrollPad = 8,
})

export type Columns = { wide: boolean, left: number, compact: boolean }

-- PC: always the three columns (the window is 1240 wide). Touch: three columns while the statistics keep `statsMin`,
-- else two: the left one (name, equipment, both sections; scrolling) as wide as the backpack leaves. `contentWidth`:
-- the window's content (Logic/WindowFrame.content, virtual px; owner 2026-11-10 via the UI plan: not the screen, whose
-- safe-area insets left a 428-px backpack on an 844x390 phone). `compact`: the statistics' column is too narrow for a
-- stat row on one line (StatAllocator `Compact`: the controls under the name).
function CharacterSections.columns(touch: boolean, contentWidth: number): Columns
	local L = CharacterSections.LAYOUT
	if not touch then
		return { wide = true, left = L.left, compact = false }
	end
	local content = contentWidth
	local right = content - (L.left + L.gutter + L.middle + L.gutter)
	if right >= L.statsMin then
		return { wide = true, left = L.left, compact = right - L.scrollPad < L.statsOneLine }
	end
	local left = math.clamp(content - L.middle - L.narrowGutter, L.narrowLeftMin, L.narrowLeftMax)
	return { wide = false, left = left, compact = left - L.scrollPad < L.statsOneLine }
end

-- "Spend as the path suggests" and its plan line: only with free points to spend and a plan to follow.
function CharacterSections.suggestShown(statPoints: number?, hasPlan: boolean): boolean
	return hasPlan and (statPoints or 0) > 0
end

return CharacterSections
