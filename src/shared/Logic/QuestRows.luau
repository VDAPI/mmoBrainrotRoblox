--!strict
-- Objective rows of a quest (S29, DESIGN §20): one list for the tracker, the journal, the NPC dialog and the world
-- map cards. Every objective stays in the list; finished ones are marked done (the UI draws them green with a "✔")
-- and, once all are done, the list carries the turn-in NPC ("Return to: <NPC>"). Pure functions (Lune tests).
-- `seen` remembers which rows were already done, so a row pulses once in the moment it is finished.

local Quests = require("../Data/Quests")

local QuestRows = {}

type Objective = Quests.Objective

export type Row = {
	index: number,
	objective: Objective,
	text: string,
	have: number,
	need: number,
	done: boolean,
}

export type List = {
	rows: { Row },
	-- every objective done
	complete: boolean,
	-- the NPC to return to when complete (nil while objectives are open or without a turn-in NPC)
	turnIn: string?,
	-- the first open objective (nil when complete)
	current: number?,
}

-- quest key -> objective index -> done
export type Seen = { [string]: { [number]: boolean } }

export type Label = (objective: Objective, have: number) -> string

QuestRows.DONE_MARK = "✔"
QuestRows.OPEN_MARK = "•"

-- Rows of a quest's objectives with their progress. `label` names an objective (the client passes the localized
-- QuestText.objective); without it the text is empty.
function QuestRows.build(objectives: { Objective }, progress: { number }?, turnIn: string?, label: Label?): List
	local rows: { Row } = {}
	local complete = true
	local current: number? = nil
	for i, objective in objectives do
		local raw = if type(progress) == "table" then progress[i] else nil
		local need = math.max(objective.n, 1)
		local have = math.clamp(if type(raw) == "number" then raw else 0, 0, need)
		local done = have >= need
		if not done then
			complete = false
			if current == nil then
				current = i
			end
		end
		table.insert(rows, {
			index = i,
			objective = objective,
			text = if label then label(objective, have) else "",
			have = have,
			need = need,
			done = done,
		})
	end
	return {
		rows = rows,
		complete = complete,
		turnIn = if complete then turnIn else nil,
		current = current,
	}
end

-- The row's line with its mark: "✔ Defeat: Grey Wolf 8/8" / "• Defeat: Grey Wolf 3/8".
function QuestRows.line(row: Row): string
	return `{if row.done then QuestRows.DONE_MARK else QuestRows.OPEN_MARK} {row.text}`
end

-- Owner 2026-10-21 (the tracker too tall): the progress of a quest on one tracker line: the mark when complete, the
-- count of a single counted objective ("3/8"), else the finished objectives of all ("1/3"); "" for one uncounted
-- objective that is still open ("Talk to ...").
function QuestRows.compact(list: List): string
	if list.complete then
		return QuestRows.DONE_MARK
	end
	if #list.rows == 1 then
		local row = list.rows[1]
		return if row.need > 1 then `{row.have}/{row.need}` else ""
	end
	local done = 0
	for _, row in list.rows do
		if row.done then
			done += 1
		end
	end
	return `{done}/{#list.rows}`
end

-- An objective label without its "have/need" count (the tracker shows the count in its own column):
-- "Defeat: Wolf 3/8 (Crow Field)" -> "Defeat: Wolf (Crow Field)". The label is returned as it is without the count.
function QuestRows.withoutCount(text: string, have: number, need: number): string
	local count = ` {math.min(have, need)}/{need}`
	local at: number? = nil
	local from = 1
	while true do
		local found = string.find(text, count, from, true)
		if not found then
			break
		end
		at = found
		from = found + 1
	end
	if not at then
		return text
	end
	return string.sub(text, 1, at - 1) .. string.sub(text, at + #count)
end

-- Rows that turned done since the last call for this quest key (they pulse once). The first call for a key only
-- remembers the state: rows already done when the quest is first shown do not pulse. Updates `seen` in place.
function QuestRows.newlyDone(seen: Seen, key: string, list: List): { number }
	local known = seen[key]
	local fresh: { number } = {}
	local state: { [number]: boolean } = {}
	for _, row in list.rows do
		state[row.index] = row.done
		if known and row.done and not known[row.index] then
			table.insert(fresh, row.index)
		end
	end
	seen[key] = state
	return fresh
end

return QuestRows
