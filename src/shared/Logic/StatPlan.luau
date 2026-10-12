--!strict
-- Stat points of a build set (ROZWOJ 2.9, 2.11; S58). Pure. The class start, the points a level grants, the points
-- spent, fitting a set to a level (SetLevel down, both sets) and the "Spend as the path suggests" plan.

local Classes = require("../Data/Classes")
local Exp = require("./Exp")
local Stats = require("../Data/Stats")
local Types = require("../Types")

export type Plan = { [string]: number }

local StatPlan = {}

local function copyStats(stats: any): Types.Stats
	local out: any = {}
	if type(stats) == "table" then
		for id, value in stats do
			out[id] = value
		end
	end
	return out
end

-- The class start stats (a copy); an unknown class has zeros.
function StatPlan.startOf(classId: string): Types.Stats
	local class = Classes.get(classId :: any)
	if not class then
		return { str = 0, dex = 0, int = 0, vit = 0 }
	end
	return copyStats(class.startStats)
end

-- Every stat point a character of `level` has (the class start is free).
function StatPlan.total(level: number): number
	return Exp.pointsForLevels(1, level)
end

-- Points spent above the class start, over the primary stats.
function StatPlan.spent(classId: string, stats: { [string]: number }): number
	local start: { [string]: number } = StatPlan.startOf(classId) :: any
	local total = 0
	for _, id in Stats.primary do
		total += (stats[id] or 0) - (start[id] or 0)
	end
	return total
end

-- A set fitted to `level` (ROZWOJ 2.9): more spent than the level grants resets to the class start with every point
-- free; otherwise the stats stay (a new table) and the rest is free. Unknown class: the stats and total(level).
function StatPlan.refit(classId: string, level: number, stats: { [string]: number }): (Types.Stats, number)
	local total = StatPlan.total(level)
	if not Classes.get(classId :: any) then
		return copyStats(stats), total
	end
	local spent = StatPlan.spent(classId, stats)
	if spent > total then
		return StatPlan.startOf(classId), total
	end
	return copyStats(stats), total - spent
end

-- Every free point goes to the plan stat with the largest deficit against the plan share of all points
-- above the class start (ROZWOJ 2.11). Points already in off-plan stats count toward the total, so the
-- plan catches up. Integer scores (plan weights are integers); ties go to the earlier stat in Stats.primary.
function StatPlan.suggest(
	plan: Plan,
	start: { [string]: number },
	current: { [string]: number },
	free: number
): { [string]: number }
	local keys: { string }, weight = {}, 0
	for _, id in Stats.primary do
		local w = plan[id]
		if type(w) == "number" and w > 0 then
			table.insert(keys, id)
			weight += w
		end
	end
	local out: { [string]: number } = {}
	if weight <= 0 or free < 1 then
		return out
	end
	local above: { [string]: number }, total = {}, 0
	for _, id in Stats.primary do
		local a = math.max(0, (current[id] or 0) - (start[id] or 0))
		above[id] = a
		total += a
	end
	for _ = 1, math.floor(free) do
		total += 1
		local best, bestScore = keys[1], -math.huge
		for _, id in keys do
			local score = plan[id] * total - above[id] * weight -- (share - have) x weight
			if score > bestScore then
				best, bestScore = id, score
			end
		end
		above[best] += 1
		out[best] = (out[best] or 0) + 1
	end
	return out
end

return StatPlan
