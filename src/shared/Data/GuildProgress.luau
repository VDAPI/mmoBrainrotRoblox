--!strict
-- Guild progress (S159g, DESIGN §19): the guild level from guild EXP that members earn by playing, what the levels
-- unlock (guild skill levels, vault slots), the guild vault and the default rank rights, and the weekly guild goals
-- with their rewards. Everything is earned in play: nothing here is sold, and the score of the guild board
-- (Logic/Leaderboard.guildScore) does not read it. Rules only in Logic/Guild, Logic/GuildBank and Logic/GuildProgress.

export type GoalDef = {
	id: string,
	group: string, -- one goal of every group per week (GROUPS order)
	counts: { [string]: number }, -- activity id -> progress per activity
	perMember: number, -- target = max(min, perMember x members at the start of the week), rounded up to `step`
	min: number,
	step: number,
	exp: number, -- guild EXP when done
	nameKey: string,
	descKey: string, -- "{n}" = target
}

local MAX_LEVEL = 20

-- Guild EXP from level n to n + 1 (index n): 1500 x n^1.5, rounded to 100. Ten members who play daily reach level 10
-- in about two months, level 20 is a long goal of a big guild.
local LEVEL_EXP: { number } = {}
for n = 1, MAX_LEVEL - 1 do
	LEVEL_EXP[n] = math.floor(1500 * n ^ 1.5 / 100 + 0.5) * 100
end

-- Guild EXP a member earns per activity (Logic/GuildProgress.activity names them). A monster counts only when it is
-- at most `greyGap` levels below the character (no farming of grey monsters); every character earns at most
-- `dailyCap` guild EXP per UTC day (activities over the cap still count for the weekly goals).
local POINTS: { [string]: number } = {
	kill = 1,
	elite = 4,
	elite2 = 10,
	boss = 25, -- a dungeon boss beaten
	worldBoss = 40, -- a world boss reward
	quest = 10, -- a main or side quest handed in
	contract = 4, -- per hunting contract handed in
	event = 12, -- a world event won
	gather = 1,
	fish = 1,
	craft = 2,
	brew = 1, -- per collected brew
	upgrade = 1,
}

-- The guild level that opens skill level n (index n) of every guild skill. Levels bought before S159g stay.
local SKILL_UNLOCK: { number } = { 1, 2, 4, 7, 10 }

local GROUPS = { "fight", "adventure", "craft" }

local GOALS: { GoalDef } = (
	{
		{
			id = "hunt",
			group = "fight",
			counts = { kill = 1, elite = 1, elite2 = 1 },
			perMember = 120,
			min = 300,
			step = 50,
		},
		{ id = "elites", group = "fight", counts = { elite = 1, elite2 = 3 }, perMember = 8, min = 25, step = 5 },
		{ id = "bosses", group = "fight", counts = { boss = 1, worldBoss = 2 }, perMember = 2, min = 6, step = 1 },
		{ id = "quests", group = "adventure", counts = { quest = 1, contract = 1 }, perMember = 6, min = 15, step = 5 },
		{ id = "events", group = "adventure", counts = { event = 1 }, perMember = 1.5, min = 5, step = 1 },
		{ id = "gather", group = "craft", counts = { gather = 1, fish = 1 }, perMember = 25, min = 60, step = 10 },
		{
			id = "smith",
			group = "craft",
			counts = { craft = 1, brew = 1, upgrade = 1 },
			perMember = 5,
			min = 12,
			step = 2,
		},
	} :: { any }
) :: any

local byId: { [string]: GoalDef } = {}
for _, goal in GOALS do
	goal.exp = 1200
	goal.nameKey = `guild.goal.{goal.id}.name`
	goal.descKey = `guild.goal.{goal.id}.desc`
	byId[goal.id] = goal
end

local Rules = table.freeze({
	maxLevel = MAX_LEVEL,
	greyGap = 10, -- levels below the character a monster still gives guild EXP
	dailyCap = 400, -- guild EXP per character per UTC day
	membersMin = 3, -- the goal targets count at least this many members
	membersMax = 45,
	goalGoldBase = 3000, -- treasury gold of a goal done: base + perLevel x guild level
	goalGoldPerLevel = 1500,
	claimMin = 60, -- guild EXP a member earned this week to take the goal rewards
	claimShards = 5, -- Dragon Shards per goal done (a game reward, tests/paywall.spec)
	rallyExp = 3, -- all three goals done: +EXP % and +gold % for members until the end of the next week
	rallyGold = 3,
	vaultBase = 10, -- vault slots at guild level 1
	vaultPerLevel = 2, -- + per guild level above 1
	logMax = 50, -- entries of the guild log
	flushSeconds = 60, -- how often a server writes the guild EXP of its members (+ up to flushJitter)
	flushJitter = 30,
	goldLimitMax = 10000000, -- highest daily gold limit a leader can set for a rank
	itemLimitMax = 100,
})

-- Default rights and daily limits of the ranks below the leader (the leader may change them; deposit is always on).
local RANK_DEFAULTS = {
	officer = {
		perms = {
			invite = true,
			kick = true,
			upgrade = true,
			motd = true,
			promote = false,
			withdrawGold = true,
			takeItem = true,
			putItem = true,
		},
		gold = 50000,
		items = 10,
	},
	veteran = {
		perms = {
			invite = true,
			kick = false,
			upgrade = false,
			motd = false,
			promote = false,
			withdrawGold = false,
			takeItem = true,
			putItem = true,
		},
		gold = 0,
		items = 3,
	},
	member = {
		perms = {
			invite = false,
			kick = false,
			upgrade = false,
			motd = false,
			promote = false,
			withdrawGold = false,
			takeItem = false,
			putItem = true,
		},
		gold = 0,
		items = 0,
	},
}

return table.freeze({
	MAX_LEVEL = MAX_LEVEL,
	LEVEL_EXP = LEVEL_EXP,
	POINTS = POINTS,
	SKILL_UNLOCK = SKILL_UNLOCK,
	GROUPS = GROUPS,
	GOALS = GOALS,
	goalById = byId,
	Rules = Rules,
	RANK_DEFAULTS = RANK_DEFAULTS,
})
