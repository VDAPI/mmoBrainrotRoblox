--!strict
-- Cloak of Luring rules (DESIGN-17 §3, S122), pure: the account time (account.lure, real time, runs offline too)
-- and which monsters one pulse pulls (Config.Lure). Where it does not work: Logic/UseBlocks (LureService asks
-- src/server/UseGuards first). The pull itself (threat) and the candidates' fields come from LureService.

local Config = require("../Config")

local Lure = {}

export type State = { untilTs: number, on: boolean }

-- One monster near the player, as LureService sees it (the test passes plain tables).
export type Candidate = {
	ref: any, -- the monster (opaque here)
	group: any?, -- spawner id: one pull engages the whole group (MonsterService context.engaged, S19)
	variant: string, -- "normal" | "elite" | "elite2" | "boss"
	boss: boolean, -- Monster.isBoss
	summoned: boolean, -- boss helpers
	fromSpawner: boolean, -- spawnerId ~= nil (world event monsters, S101, have none)
	passive: boolean, -- def.passive (never attacks first)
	idle: boolean, -- state == "idle" and an empty threat table (fights nobody)
	targetable: boolean, -- MonsterService.CanTarget(monster, player)
	level: number,
	distance: number,
	cost: number, -- alive members of its group not fighting this player yet (1 without a group)
}

local function stateOf(state: State?): State
	if type(state) ~= "table" then
		return { untilTs = 0, on = false }
	end
	return state
end

-- Seconds of cloak time left at `now`.
function Lure.left(state: State?, now: number): number
	return math.max(0, (stateOf(state).untilTs or 0) - now)
end

-- Switched on and with time left.
function Lure.active(state: State?, now: number): boolean
	return stateOf(state).on == true and Lure.left(state, now) > 0
end

-- The state after buying `seconds` more (a new table): time adds from now or from the current end; buying switches
-- the cloak on.
function Lure.extend(state: State?, seconds: number, now: number): State
	local s = stateOf(state)
	return { untilTs = math.max(s.untilTs or 0, now) + math.max(0, seconds), on = true }
end

-- Days, hours and minutes of a duration (the client picks lure.left.d / .h / .m / .s).
function Lure.parts(seconds: number): { d: number, h: number, m: number }
	local s = math.max(0, math.floor(seconds))
	return { d = s // 86400, h = (s % 86400) // 3600, m = (s % 3600) // 60 }
end

-- The Locale key and arguments of a duration ("6 d 23 h", "2 h 5 min", "59 min", "under a minute").
function Lure.timeKey(seconds: number): (string, { d: number, h: number, m: number })
	local p = Lure.parts(seconds)
	if p.d > 0 then
		return "lure.left.d", p
	elseif p.h > 0 then
		return "lure.left.h", p
	elseif p.m > 0 then
		return "lure.left.m", p
	end
	return "lure.left.s", p
end

-- Whether one candidate may be pulled by a player of `playerLevel` (DESIGN-17 §3: ordinary monsters only, never
-- Elites, Elites II, bosses, boss helpers or world event monsters; idle, within radius and level gap).
function Lure.eligible(c: Candidate, playerLevel: number): boolean
	return c.variant == "normal"
		and not c.boss
		and not c.summoned
		and c.fromSpawner
		and not c.passive
		and c.idle
		and c.targetable
		and math.abs(c.level - playerLevel) <= Config.Lure.levelGap
		and c.distance <= Config.Lure.radius
end

-- The candidates one pulse pulls: at most Config.Lure.maxPulled monsters fighting the player at once (`fighting`
-- already do). A group pull engages every member (S19), so a candidate costs its whole group and one group is taken
-- once; a group bigger than the limit is never pulled. Nearest first (ties: lower level). Deterministic.
function Lure.pick(candidates: { Candidate }, playerLevel: number, fighting: number): { Candidate }
	local budget = Config.Lure.maxPulled - fighting
	local out: { Candidate } = {}
	if budget <= 0 then
		return out
	end
	local pool: { Candidate } = {}
	for _, c in candidates do
		if Lure.eligible(c, playerLevel) then
			table.insert(pool, c)
		end
	end
	table.sort(pool, function(a: Candidate, b: Candidate): boolean
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.level < b.level
	end)
	local taken: { [any]: boolean } = {}
	for _, c in pool do
		local cost = math.max(1, c.cost)
		local free = c.group == nil or not taken[c.group]
		if free and cost <= budget then
			if c.group ~= nil then
				taken[c.group] = true
			end
			table.insert(out, c)
			budget -= cost
			if budget <= 0 then
				break
			end
		end
	end
	return out
end

return Lure
