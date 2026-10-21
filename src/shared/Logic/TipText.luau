--!strict
-- Short text and details of a tooltip (2026-10-21, owner: descriptions too long, the game unreadable). A tooltip shows
-- its short part and a hint; holding the details key (PC) or the press (touch) adds the details. Pure (Lune):
-- UI/Components/Tooltip composes with it, UI/SkillInfo splits the skill bar tooltip with SKILL_COMPACT;
-- tests/tiptext.spec.

local TipText = {}

export type Part = { kind: string, text: string }

-- The skill bar tooltip (UI/SkillInfo.tooltipParts): what stays in the short part. Everything else (area shape, cast
-- time, blow kind, weapon speed factor, heal on you, reached breakpoints, the full description) is details.
TipText.SKILL_COMPACT = table.freeze({
	name = true, -- "Name · Rank 3/10"
	unlock = true, -- "Unlocks at level N" (rank 0)
	short = true, -- the one sentence (skill.<id>.short)
	cost = true, -- cost · cooldown · range
	element = true, -- the weapon element the skill needs
})

-- At most this many lines in the short part of the skill bar tooltip (tests/tiptext.spec).
TipText.SKILL_MAX_LINES = 5

-- The text a tooltip shows: `short` alone without details; with details the hint under it (collapsed) or the details
-- (expanded).
function TipText.compose(short: string, details: string?, expanded: boolean, hint: string?): string
	if details == nil or details == "" then
		return short
	end
	if expanded then
		return if short == "" then details else `{short}\n{details}`
	end
	if hint and hint ~= "" then
		return if short == "" then hint else `{short}\n{hint}`
	end
	return short
end

-- Splits tagged lines into (short, details): a line whose kind is in `compact` goes to the short part, the rest to
-- the details, each in the given order; empty lines are dropped.
function TipText.split(parts: { Part }, compact: { [string]: boolean }): (string, string)
	local short: { string } = {}
	local details: { string } = {}
	for _, part in parts do
		if part.text ~= "" then
			table.insert(if compact[part.kind] then short else details, part.text)
		end
	end
	return table.concat(short, "\n"), table.concat(details, "\n")
end

-- Number of lines of a text ("" has none).
function TipText.lineCount(text: string): number
	if text == "" then
		return 0
	end
	local _, breaks = string.gsub(text, "\n", "")
	return breaks + 1
end

return TipText
