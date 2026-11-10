--!strict
-- Owner 2026-10-21 (too many detailed descriptions): a direction node in the skills window (SkillsWindow/Details)
-- shows one paragraph: the next rank (at the limit the current one, not bought yet rank 1). A long description (over
-- LONG characters) shows its short line `path.<path>.<node>.short` there; its full text and the rank bought now go
-- under "More" (Components/Details).
-- UI plan 2026-11-10 (owner: "zbyt szczegółowe opisy"): LONG from 100 to 60, the cap of a visible line, so every
-- description that would wrap past one line in the details shows its short line (71 more of them, pl and en).

local Locale = require("../Util/Locale")

local NodeText = {}

-- A description longer than this (as written, Polish) has a short line.
NodeText.LONG = 60

-- `rank`: the rank the visible paragraph shows; `now`: the bought rank shown under "More" (only below the limit);
-- `label`: "atRank" ("At rank N") or "now" ("Now", the node at its limit).
export type Plan = { rank: number, now: number?, label: "atRank" | "now" }

function NodeText.plan(rank: number, maxRank: number): Plan
	if rank <= 0 then
		return { rank = 1, label = "atRank" }
	elseif rank < maxRank then
		return { rank = rank + 1, now = rank, label = "atRank" }
	end
	return { rank = rank, label = "now" }
end

-- The short line of a node description ("path.scout.eye.desc" -> "path.scout.eye.short"); nil when it has none.
function NodeText.shortKey(descKey: string, lang: string?): string?
	local key, n = string.gsub(descKey, "%.desc$", ".short")
	if n == 1 and Locale.has(key, lang) then
		return key
	end
	return nil
end

return NodeText
