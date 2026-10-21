--!strict
-- Guild EXP and weekly goals (S159g, DESIGN §19). Pure: the server turns gameplay events of members into activities
-- (GuildProgress.activity), caps the guild EXP of a character per UTC day (GuildProgress.earn, character.guildWork),
-- collects them per guild and writes them in one UpdateAsync now and then (GuildProgress.apply in the callback).
--   * Guild level: Logic/Guild.levelOf(guild.exp); levels open guild skill levels, vault slots and banner looks.
--   * Weekly goals: three per week (one of every Data/GuildProgress.GROUPS group), the same on every server (seeded by
--     the guild id and the week), targets from the member count at the start of the week. A goal done gives guild EXP
--     and treasury gold; every member who earned at least Rules.claimMin guild EXP that week takes its Dragon Shards
--     in the guild window (once per goal and character: character.guildWork.claimed). All three done = the rally:
--     +Rules.rallyExp % EXP and +Rules.rallyGold % gold for the members until the end of the next week.
-- Nothing here reads purchases; the guild board score does not read guild EXP (DESIGN-17 §0.2).

local GuildProgressData = require("../Data/GuildProgress")
local Guild = require("./Guild")
local Rng = require("./Rng")

local Rules = GuildProgressData.Rules

type GuildData = Guild.GuildData

export type Batch = { [string]: { exp: number, acts: { [string]: number } } }

-- character.guildWork: guild EXP earned on UTC day `day` (`today`), goal rewards taken in week `week`.
export type Work = { day: number, today: number, week: number, claimed: { [string]: boolean } }

export type Notes = { levels: { number }, goals: { string }, rally: boolean }

local GuildProgress = {}

function GuildProgress.newWork(): Work
	return { day = 0, today = 0, week = 0, claimed = {} }
end

-- The activity of a gameplay event (QuestEvents kinds; "kill" = CombatService.MonsterKilled for one credited member,
-- data { variant, level, boss }) and how many of it, or nil when it gives nothing.
function GuildProgress.activity(kind: string, data: { [string]: any }?, charLevel: number): (string?, number)
	local d: { [string]: any } = data or {}
	if kind == "kill" then
		if d.boss or d.noLoot then
			return nil, 0 -- dungeon bosses come as "boss"; summoned helpers give nothing
		end
		if (tonumber(d.level) or 0) < charLevel - Rules.greyGap then
			return nil, 0
		end
		if d.variant == "elite" or d.variant == "elite2" then
			return d.variant, 1
		end
		return "kill", 1
	elseif kind == "boss" then
		return "boss", 1
	elseif kind == "worldboss" then
		return "worldBoss", 1
	elseif kind == "quest" then
		if d.kind == "contract" then
			return "contract", math.max(1, math.floor(tonumber(d.n) or 1))
		elseif d.kind == "main" or d.kind == "side" then
			return "quest", 1
		end
		return nil, 0
	elseif kind == "event" then
		return if d.success then "event" else nil, 1
	elseif kind == "gather" or kind == "craft" or kind == "brew" then
		return kind, math.max(1, math.floor(tonumber(d.n) or 1))
	elseif kind == "fish" or kind == "upgrade" then
		return kind, 1
	end
	return nil, 0
end

function GuildProgress.points(act: string, n: number): number
	return (GuildProgressData.POINTS[act] or 0) * n
end

-- Guild EXP a character actually earns of `points` on UTC day `day` (Rules.dailyCap) and its new work record.
function GuildProgress.earn(work: any?, day: number, points: number): (number, Work)
	local w: Work = if type(work) == "table" then table.clone(work) :: any else GuildProgress.newWork()
	if w.day ~= day then
		w.day = day
		w.today = 0
	end
	local granted = math.clamp(points, 0, math.max(0, Rules.dailyCap - (w.today or 0)))
	w.today = (w.today or 0) + granted
	return granted, w
end

-- The three goals of a guild in `week` (one per group), targets from `members`.
function GuildProgress.goalsFor(guildId: string, week: number, members: number): { Guild.Goal }
	local rng = Rng.new(Rng.seedOf(`guildgoals:{guildId}:{week}`))
	local count = math.clamp(members, Rules.membersMin, Rules.membersMax)
	local goals = {}
	for _, group in GuildProgressData.GROUPS do
		local pool = {}
		for _, def in GuildProgressData.GOALS do
			if def.group == group then
				table.insert(pool, def)
			end
		end
		local def = rng:pick(pool)
		local target = math.max(def.min, math.ceil(def.perMember * count / def.step) * def.step)
		table.insert(goals, { id = def.id, target = target, n = 0, done = false })
	end
	return goals
end

-- Starts the goals of `week` when the record still has an older week. True when it changed.
function GuildProgress.ensureWeek(guild: GuildData, week: number): boolean
	local current = guild.week
	if type(current) == "table" and current.w == week then
		return false
	end
	guild.week = { w = week, goals = GuildProgress.goalsFor(guild.id, week, Guild.memberCount(guild)), contrib = {} }
	return true
end

function GuildProgress.goalGold(level: number): number
	return Rules.goalGoldBase + Rules.goalGoldPerLevel * level
end

function GuildProgress.rallyActive(guild: any?, week: number): boolean
	local rally = type(guild) == "table" and guild.rally
	return type(rally) == "table" and week >= (rally.from or 0) and week <= (rally.to or -1)
end

-- Bonuses of the rally for the "guild" modifier source ({} when not active).
function GuildProgress.rallyBonus(guild: any?, week: number): { [string]: number }
	if not GuildProgress.rallyActive(guild, week) then
		return {}
	end
	return { expBonus = Rules.rallyExp, goldBonus = Rules.rallyGold }
end

-- Guild EXP a member earned in `week` (0 in another week).
function GuildProgress.contribution(guild: any?, key: string, week: number): number
	local current = type(guild) == "table" and guild.week
	if type(current) ~= "table" or current.w ~= week then
		return 0
	end
	return tonumber(current.contrib[key]) or 0
end

-- Adds guild EXP: the level-ups go to `notes` and the log.
local function addExp(guild: GuildData, amount: number, notes: Notes, now: number)
	local before = Guild.level(guild)
	guild.exp = (guild.exp or 0) + math.max(0, math.floor(amount))
	local after = Guild.level(guild)
	for level = before + 1, after do
		table.insert(notes.levels, level)
		Guild.addLog(guild, { t = now, k = "level", a = level })
	end
end

-- Applies a batch of member activity (one server's share) to the record: guild EXP, weekly contributions, goal
-- progress, goal rewards and the rally. Members no longer in the guild are skipped. Returns what happened.
function GuildProgress.apply(guild: GuildData, batch: Batch, week: number, now: number): Notes
	local notes: Notes = { levels = {}, goals = {}, rally = false }
	GuildProgress.ensureWeek(guild, week)
	local current = guild.week :: Guild.Week
	for key, part in batch do
		if not guild.members[key] then
			continue
		end
		if part.exp > 0 then
			current.contrib[key] = (current.contrib[key] or 0) + part.exp
			addExp(guild, part.exp, notes, now)
		end
		for _, goal in current.goals do
			local def = GuildProgressData.goalById[goal.id]
			if def and not goal.done then
				for act, n in part.acts do
					goal.n += (def.counts[act] or 0) * n
				end
			end
		end
	end
	local allDone = #current.goals > 0
	for _, goal in current.goals do
		local def = GuildProgressData.goalById[goal.id]
		if not goal.done and goal.n >= goal.target and def then
			goal.done = true
			goal.n = goal.target
			guild.treasury += GuildProgress.goalGold(Guild.level(guild))
			Guild.addLog(guild, { t = now, k = "goal", x = goal.id })
			table.insert(notes.goals, goal.id)
			addExp(guild, def.exp, notes, now)
		end
		allDone = allDone and goal.done
	end
	if allDone and not GuildProgress.rallyActive(guild, week + 1) then
		guild.rally = { from = week, to = week + 1 }
		notes.rally = true
	end
	guild.version = (guild.version or 0) + 1
	return notes
end

-- Whether the member `key` may take the reward of goal `index` in `week` (character.guildWork = `work`):
-- (ok, errorKey?).
function GuildProgress.canClaim(guild: any?, key: string, index: number, week: number, work: any?): (boolean, string?)
	local current = type(guild) == "table" and guild.week
	local goal = type(current) == "table" and current.w == week and current.goals[index]
	if not goal or not goal.done then
		return false, "guild.error.goalNotDone"
	end
	if GuildProgress.contribution(guild, key, week) < Rules.claimMin then
		return false, "guild.error.claimMin"
	end
	local claimed = type(work) == "table" and work.week == week and work.claimed or nil
	if claimed and claimed[goal.id] then
		return false, "guild.error.claimed"
	end
	return true, nil
end

-- The work record after taking the reward of goal `goalId` in `week`.
function GuildProgress.markClaimed(work: any?, week: number, goalId: string): Work
	local w: Work = if type(work) == "table" then table.clone(work) :: any else GuildProgress.newWork()
	if w.week ~= week or type(w.claimed) ~= "table" then
		w.week = week
		w.claimed = {}
	else
		w.claimed = table.clone(w.claimed)
	end
	w.claimed[goalId] = true
	return w
end

-- Merges batch `b` into `a` (a failed write keeps its batch for the next round).
function GuildProgress.merge(a: Batch, b: Batch)
	for key, part in b do
		local into = a[key]
		if not into then
			into = { exp = 0, acts = {} }
			a[key] = into
		end
		into.exp += part.exp
		for act, n in part.acts do
			into.acts[act] = (into.acts[act] or 0) + n
		end
	end
end

return GuildProgress
