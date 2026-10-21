--!strict
-- Folded groups of the quest tracker (owner 2026-10-21: the tracker took ~40 % of the screen height). The tracker lists
-- its entries in groups under a header with an arrow (quests, hunting contracts, daily, weekly, achievements; "all" =
-- the whole tracker); a click folds or unfolds a group. The state is an account setting
-- (`account.settings.trackerFold`, SetSetting "trackerFold"): group id -> folded, only for the groups the player
-- clicked; the others follow DEFAULTS. Pure (Lune): tests/trackerfold.spec.

local TrackerFold = {}

TrackerFold.GROUPS = table.freeze({ "all", "quests", "contracts", "daily", "weekly", "ach" })

-- Folded until the player opens them: the weekly set (its header carries the progress, as before).
TrackerFold.DEFAULTS = table.freeze({ weekly = true } :: { [string]: boolean })

local KNOWN: { [string]: boolean } = {}
for _, id in TrackerFold.GROUPS do
	KNOWN[id] = true
end

-- Whether `group` is folded under the saved setting (anything else than a table reads as no setting).
function TrackerFold.isFolded(saved: any, group: string): boolean
	local value = if type(saved) == "table" then saved[group] else nil
	if type(value) == "boolean" then
		return value
	end
	return TrackerFold.DEFAULTS[group] == true
end

-- A new setting with `group` folded or not; unknown groups and values equal to the default are dropped.
function TrackerFold.with(saved: any, group: string, folded: boolean): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, id in TrackerFold.GROUPS do
		local value = if id == group then folded else TrackerFold.isFolded(saved, id)
		if value ~= (TrackerFold.DEFAULTS[id] == true) then
			out[id] = value
		end
	end
	return out
end

-- Two settings fold the same groups.
function TrackerFold.same(a: any, b: any): boolean
	for _, id in TrackerFold.GROUPS do
		if TrackerFold.isFolded(a, id) ~= TrackerFold.isFolded(b, id) then
			return false
		end
	end
	return true
end

-- Server validator of the setting: a table of known group ids to booleans.
function TrackerFold.valid(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, folded in value do
		if type(key) ~= "string" or not KNOWN[key] or type(folded) ~= "boolean" then
			return false
		end
	end
	return true
end

return TrackerFold
