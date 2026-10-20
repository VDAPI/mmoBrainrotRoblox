--!strict
-- Achievements (S151, docs/DESIGN.md §20b): what counts, the goals, the points and the rewards. Pure data; the rules
-- (counting, catch-up of old progress, the shard budget) are in Logic/Achievements, the server in AchievementService.
-- Names: ach.<id>.name, ach.<id>.desc ({goal}), categories ach.cat.<cat> (Localization).
--
-- COUNTERS: every counter lives on the account or on the character (`scope`); an achievement has the scope of its
-- counter. `mode` = how a game event changes it: "add" (+value), "max" (the highest value seen), "set" (a set of
-- distinct ids in s[counter]; the value is the number of its elements).
-- An achievement is done when its counter reaches `goal`; with `key` (a set counter) when the set holds that id; with
-- `all` (a set counter) when the set holds every id of that group (Logic/Achievements.GROUPS, computed from the game
-- data, so a new map, hideout or boss raises the goal by itself; a done achievement stays done).
-- `after` = the previous step of a series (same counter, lower goal); the window (S151b) shows the next step.
-- Rewards: a title (Data/Titles req { kind = "achievement", id }), a cosmetic (Data/Cosmetics obtain.achievement),
-- Dragon Shards (paid once per account, the sum within Config.Achievements.shardBudget) or a little gold (journey and
-- craft only, at most 5% of the band's gold; tests/balance.spec). Never shards for social achievements.
-- Not a balance module (tools/balance_reasons NOT_BALANCE): the goals are milestones, not the pace of the game.

local Main = require("./Quests/Main")

export type Scope = string -- "account" | "character"
export type Mode = string -- "add" | "max" | "set"
export type CounterDef = { scope: Scope, mode: Mode }

export type Reward = { title: string?, cosmetic: string?, shards: number?, gold: number? }

export type AchDef = {
	id: string,
	cat: string,
	counter: string,
	goal: number, -- 1 for `key`, 0 for `all` (Logic/Achievements.goalOf counts the group)
	key: string?,
	all: string?,
	points: number, -- 5 / 10 / 25 / 50
	reward: Reward?,
	secret: boolean?,
	wiki: boolean?,
	after: string?,
}

-- Window order (S151b). `journey` (levels and quests) is the sixth one beside the owner's five (DECYZJE S151).
local CATEGORIES: { string } = { "combat", "bosses", "explore", "craft", "social", "journey" }

local POINTS: { number } = { 5, 10, 25, 50 }

local COUNTERS: { [string]: CounterDef } = {
	-- character
	kills = { scope = "character", mode = "add" },
	eliteKills = { scope = "character", mode = "add" },
	elite2Kills = { scope = "character", mode = "add" },
	dodged = { scope = "character", mode = "add" },
	pvpKills = { scope = "character", mode = "add" },
	duelsWon = { scope = "character", mode = "add" },
	arenaWins = { scope = "character", mode = "add" },
	level = { scope = "character", mode = "max" },
	mainDone = { scope = "character", mode = "max" },
	sideDone = { scope = "character", mode = "add" },
	contracts = { scope = "character", mode = "add" },
	maps = { scope = "character", mode = "set" },
	caves = { scope = "character", mode = "set" },
	lairs = { scope = "character", mode = "set" },
	crafted = { scope = "character", mode = "add" },
	upgraded7 = { scope = "character", mode = "add" },
	upgraded9 = { scope = "character", mode = "add" },
	dismantled = { scope = "character", mode = "add" },
	rerolled = { scope = "character", mode = "add" },
	brewed = { scope = "character", mode = "add" },
	gathered = { scope = "character", mode = "add" },
	fish = { scope = "character", mode = "add" },
	-- account
	bosses = { scope = "account", mode = "set" },
	bossKills = { scope = "account", mode = "add" },
	worldBoss = { scope = "account", mode = "add" },
	bloodMoon = { scope = "account", mode = "set" }, -- occurrence ids: two characters in one Blood Moon count once
	invasions = { scope = "account", mode = "add" },
	fullParty = { scope = "account", mode = "add" },
	trades = { scope = "account", mode = "add" },
	mailSent = { scope = "account", mode = "add" },
	friends = { scope = "account", mode = "max" },
	guild = { scope = "account", mode = "max" },
	earnedCosmetics = { scope = "account", mode = "add" }, -- +1 per cosmetic earned in the game (obtain ~= nil)
}

-- The winners present at a won dungeon boss for `fullParty` (a full party, Config.PartyFinder.maxMembers).
local FULL_PARTY = 5

type Opts = {
	reward: Reward?,
	key: string?,
	all: string?,
	after: string?,
	secret: boolean?,
	wiki: boolean?,
}

local list: { AchDef } = {}

local function ach(id: string, cat: string, counter: string, goal: number, points: number, opts: Opts?)
	local o: Opts = opts or {}
	table.insert(list, {
		id = id,
		cat = cat,
		counter = counter,
		goal = goal,
		key = o.key,
		all = o.all,
		points = points,
		reward = o.reward,
		secret = o.secret,
		wiki = o.wiki,
		after = o.after,
	})
end

-- Combat -------------------------------------------------------------------------------------------------------------
ach("slayer1", "combat", "kills", 100, 5)
ach("slayer2", "combat", "kills", 1000, 10, { after = "slayer1" })
ach("slayer3", "combat", "kills", 10000, 25, { after = "slayer2", reward = { shards = 10 } })
ach("slayer4", "combat", "kills", 50000, 50, { after = "slayer3", reward = { title = "ach_butcher" } })
ach("slayer5", "combat", "kills", 200000, 50, { after = "slayer4", reward = { shards = 25 } })
ach("elite1", "combat", "eliteKills", 50, 5)
ach("elite2", "combat", "eliteKills", 500, 10, { after = "elite1" })
ach("elite3", "combat", "eliteKills", 2500, 25, { after = "elite2", reward = { cosmetic = "frame_elitehunter" } })
ach("elite2_1", "combat", "elite2Kills", 10, 10)
ach("elite2_2", "combat", "elite2Kills", 100, 25, { after = "elite2_1" })
ach("elite2_3", "combat", "elite2Kills", 500, 50, { after = "elite2_2", reward = { shards = 20 } })
ach("dodge1", "combat", "dodged", 25, 5)
ach("dodge2", "combat", "dodged", 250, 10, { after = "dodge1" })
ach("dodge3", "combat", "dodged", 1000, 25, { after = "dodge2", reward = { title = "ach_elusive" } })
-- the old PvP and duel titles (bloodied, warlord, duelist, gladiator) keep their own requirements (DECYZJE S151)
ach("pvp1", "combat", "pvpKills", 10, 10)
ach("pvp2", "combat", "pvpKills", 100, 25, { after = "pvp1" })
ach("duel1", "combat", "duelsWon", 10, 5)
ach("duel2", "combat", "duelsWon", 50, 10, { after = "duel1" })
ach("arena1", "combat", "arenaWins", 25, 10)
ach("arena2", "combat", "arenaWins", 200, 25, { after = "arena1" })

-- Bosses -------------------------------------------------------------------------------------------------------------
ach("boss_grimrok", "bosses", "bosses", 1, 10, { key = "grimrok" })
ach("boss_morvane", "bosses", "bosses", 1, 10, { key = "morvane" })
ach("boss_azgor", "bosses", "bosses", 1, 25, { key = "azgor" })
ach("boss_vaelgrath", "bosses", "bosses", 1, 25, { key = "vaelgrath", reward = { shards = 10 } })
ach("bossAll", "bosses", "bosses", 0, 50, { all = "dungeonBosses", reward = { title = "ach_fourslayer" } })
ach("bossKills1", "bosses", "bossKills", 10, 10)
ach("bossKills2", "bosses", "bossKills", 100, 25, { after = "bossKills1" })
ach("bossKills3", "bosses", "bossKills", 500, 50, { after = "bossKills2", reward = { shards = 15 } })
ach("worldBoss1", "bosses", "worldBoss", 1, 25, { reward = { title = "ach_ancestorbane" } })
ach("worldBoss2", "bosses", "worldBoss", 10, 25, { after = "worldBoss1", reward = { shards = 25 } })
ach("worldBoss3", "bosses", "worldBoss", 50, 50, { after = "worldBoss2", reward = { cosmetic = "aura_ancestorfrost" } })
ach("fullParty1", "bosses", "fullParty", 10, 25, { reward = { cosmetic = "chatframe_five" } })

-- Exploration ----------------------------------------------------------------------------------------------------------
ach("maps1", "explore", "maps", 0, 10, { all = "regions" })
ach("maps2", "explore", "maps", 0, 25, { all = "world", after = "maps1", reward = { title = "ach_cartographer" } })
ach("caves1", "explore", "caves", 0, 25, { all = "caves", reward = { shards = 15 } })
ach("lairs1", "explore", "lairs", 6, 25)
ach("lairs2", "explore", "lairs", 0, 50, {
	all = "lairs",
	after = "lairs1",
	reward = { title = "ach_lairtracker", shards = 20 },
})
ach("bloodMoon1", "explore", "bloodMoon", 1, 10)
ach("bloodMoon2", "explore", "bloodMoon", 10, 25, { after = "bloodMoon1" })
ach("invasion1", "explore", "invasions", 5, 10)
ach("invasion2", "explore", "invasions", 50, 25, { after = "invasion1", reward = { shards = 10 } })

-- Crafting -------------------------------------------------------------------------------------------------------------
ach("craft1", "craft", "crafted", 10, 5)
ach("craft2", "craft", "crafted", 100, 10, { after = "craft1" })
ach("craft3", "craft", "crafted", 500, 25, { after = "craft2", reward = { shards = 10 } })
ach("upgrade7", "craft", "upgraded7", 10, 25)
ach("upgrade9", "craft", "upgraded9", 1, 50, { reward = { title = "ach_forgemaster" } })
ach("dismantle1", "craft", "dismantled", 100, 10)
ach("dismantle2", "craft", "dismantled", 1000, 25, { after = "dismantle1", reward = { shards = 10 } })
ach("reroll1", "craft", "rerolled", 10, 10)
ach("reroll2", "craft", "rerolled", 100, 25, { after = "reroll1", reward = { shards = 10 } })
ach("brew1", "craft", "brewed", 50, 10)
ach("brew2", "craft", "brewed", 500, 25, { after = "brew1", reward = { shards = 10 } })
ach("gather1", "craft", "gathered", 100, 5)
ach("gather2", "craft", "gathered", 1000, 10, { after = "gather1" })
ach("gather3", "craft", "gathered", 5000, 25, { after = "gather2", reward = { cosmetic = "levelup_gatherer" } })
ach("fish1", "craft", "fish", 50, 10)
ach("fish2", "craft", "fish", 500, 25, { after = "fish1", reward = { shards = 10 } })

-- Social (no shards: friends, trades and letters are easy to farm with second accounts) --------------------------------
ach("friends1", "social", "friends", 1, 5)
ach("friends2", "social", "friends", 10, 10, { after = "friends1" })
ach("guild1", "social", "guild", 1, 10)
ach("trade1", "social", "trades", 10, 10)
ach("trade2", "social", "trades", 100, 25, { after = "trade1", reward = { cosmetic = "chatframe_merchant" } })
ach("mail1", "social", "mailSent", 10, 10)

-- Journey (levels, the story, side quests, contracts) -----------------------------------------------------------------
-- the level and story titles stay in Data/Titles with their old requirements (no duplicates, DECYZJE S151)
ach("level10", "journey", "level", 10, 5, { reward = { gold = 100 } })
ach("level25", "journey", "level", 25, 10, { after = "level10" })
ach("level50", "journey", "level", 50, 25, { after = "level25", reward = { shards = 10 } })
ach("level75", "journey", "level", 75, 25, { after = "level50", reward = { shards = 25 } })
ach("level100", "journey", "level", 100, 50, { after = "level75", reward = { shards = 50 } })

-- The end of story chapters I-IV (the quest before the next chapter's first one) and the finale (the last quest).
local function chapterEnd(n: number): number
	local nextChapter = Main.CHAPTERS[n + 1]
	local first = if nextChapter then Main.indexOf[nextChapter.first] else nil
	return if first then first - 1 else #Main.list
end
ach("story1", "journey", "mainDone", chapterEnd(1), 10)
ach("story2", "journey", "mainDone", chapterEnd(2), 10, { after = "story1" })
ach("story3", "journey", "mainDone", chapterEnd(3), 25, { after = "story2" })
ach("story4", "journey", "mainDone", chapterEnd(4), 25, { after = "story3" })
ach("story5", "journey", "mainDone", #Main.list, 50, { after = "story4", reward = { shards = 20 } })
ach("side1", "journey", "sideDone", 25, 10)
ach("side2", "journey", "sideDone", 100, 25, { after = "side1", reward = { shards = 15 } })
-- one contract per level 1-99 (Data/Quests/Contracts): 99 is all of them
ach("contract1", "journey", "contracts", 25, 10)
ach("contract2", "journey", "contracts", 99, 25, { after = "contract1" })
ach("collector1", "journey", "earnedCosmetics", 5, 10)
ach("collector2", "journey", "earnedCosmetics", 15, 25, { after = "collector1" })

local byId: { [string]: AchDef } = {}
local byCounter: { [string]: { AchDef } } = {}
local byCategory: { [string]: { AchDef } } = {}
for _, def in list do
	assert(byId[def.id] == nil, `Achievements: duplicate id {def.id}`)
	byId[def.id] = def
	local forCounter = byCounter[def.counter]
	if not forCounter then
		forCounter = {}
		byCounter[def.counter] = forCounter
	end
	table.insert(forCounter, def)
	local forCat = byCategory[def.cat]
	if not forCat then
		forCat = {}
		byCategory[def.cat] = forCat
	end
	table.insert(forCat, def)
end
-- the hot path (every kill) reads byCounter in goal order
for _, defs in byCounter do
	table.sort(defs, function(a: AchDef, b: AchDef): boolean
		if a.goal ~= b.goal then
			return a.goal < b.goal
		end
		return a.id < b.id
	end)
end

return table.freeze({
	CATEGORIES = table.freeze(CATEGORIES),
	POINTS = table.freeze(POINTS),
	COUNTERS = table.freeze(COUNTERS),
	FULL_PARTY = FULL_PARTY,
	list = list,
	byId = byId,
	byCounter = byCounter,
	get = function(id: string): AchDef?
		return byId[id]
	end,
	forCategory = function(cat: string): { AchDef }
		return byCategory[cat] or {}
	end,
})
