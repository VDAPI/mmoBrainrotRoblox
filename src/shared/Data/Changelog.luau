--!strict
-- S153 (docs/DESIGN.md §11): the in-game "What has changed" log, shown once as a letter when a character enters the
-- world (Logic/Returning.letter: entries newer than account.returning.seen) and again from the game menu. Separate
-- from the wiki's "Updates" (S43): shorter, only what a player feels in the game, no balance numbers in the text.
-- Adding an entry: the next `id` (ids only grow, never reused), the UTC day it ships (an entry dated in the future
-- stays hidden until that day) and `changelog.<key>.title` / `.body` in pl.luau and en.luau (tests/returning.spec).

local Time = require("../Logic/Time")

export type Entry = {
	id: number,
	day: number, -- UTC day number (Time.dayNumber)
	key: string, -- texts changelog.<key>.title / .body
}

local function entry(id: number, year: number, month: number, day: number, key: string): Entry
	return table.freeze({ id = id, day = Time.fromCivil(year, month, day), key = key })
end

local Changelog = {}

-- Oldest first.
Changelog.ENTRIES = table.freeze({
	entry(1, 2026, 10, 17, "parchment"), -- S135-S136
	entry(2, 2026, 10, 18, "skills2"), -- S137-S148
	entry(3, 2026, 10, 18, "worldBoss"), -- S149-S149b
	entry(4, 2026, 10, 18, "friends"), -- S150
	entry(5, 2026, 10, 18, "achievements"), -- S151-S151b
	entry(6, 2026, 10, 18, "seasonPass"), -- S152-S152b
	entry(7, 2026, 10, 19, "returning"), -- S153
}) :: { Entry }

-- The highest id of the log (0 when empty).
function Changelog.maxId(): number
	local top = 0
	for _, e in Changelog.ENTRIES do
		top = math.max(top, e.id)
	end
	return top
end

return table.freeze(Changelog)
