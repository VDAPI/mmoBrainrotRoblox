--!strict
-- Achievements (S151, docs/DESIGN.md §20b; data in Data/Achievements). Pure: the counters of the account and the
-- character, which game event moves which counter (COUNTER_EVENTS, one source: QuestEvents and the kill / level
-- signals the server maps onto the same kinds), when an achievement is done, its reward (Dragon Shards once per
-- account), the catch-up of old progress from the save (backfill, every load, idempotent like Logic/StoryProgress) and
-- the shard budget. AchievementService only feeds the events in and writes the results.
--
-- Save (no migration, AccountSchema templates + reconcile):
--   account.ach   = { c = { [counter] = n }, s = { [counter] = { [id] = true } }, done = { [achId] = os.time }, paid =
--                   { [achId] = true } }   (account counters and achievements, shards paid)
--   character.ach = { c, s, done, track }  (character counters and achievements; S151b: `track` = the ids followed in
--                                           the HUD tracker, at most Config.Achievements.trackMax; `paidHere` =
--                                           { [achId] = true }, the character achievements whose shards this
--                                           character received, added on the first payment)

local AchData = require("../Data/Achievements")
local Areas = require("../Data/Areas")
local Bosses = require("../Data/Bosses")
local Config = require("../Config")
local Cosmetics = require("../Data/Cosmetics")
local Maps = require("../Data/Maps")
local Quests = require("../Data/Quests")

type AchDef = AchData.AchDef

export type Branch = {
	c: { [string]: number },
	s: { [string]: { [string]: boolean } },
	done: { [string]: number },
	paid: { [string]: boolean }?,
	track: { string }?, -- S151b: character branch only
	paidHere: { [string]: boolean }?, -- S151b: character branch only, the shards this character received
}
export type State = { acc: Branch, chr: Branch }
export type Entry = { counter: string, mode: string, value: number, key: string? }
export type Applied = { newly: { string }, changed: boolean }
export type Reward = { title: string?, cosmetic: string?, shards: number, gold: number }

local Achievements = {}

-- Groups of the `all` goals ---------------------------------------------------------------------------------------------

local UNDERGROUND: { [string]: boolean } = { cave = true, crypt = true }

-- A map the player can travel to and that is marked visited (TravelService.MarkVisited): no dungeon, no server-mode map
-- (the arena pit), nothing hidden.
local function travelMap(map: Maps.MapDef): boolean
	return map.biome ~= "dungeon" and map.serverModes == nil and map.hidden ~= true
end

local groups: { [string]: { [string]: boolean } }? = nil
local groupSizes: { [string]: number } = {}

-- regions: the open-air maps (the city and the region maps); world: every travel map; caves: the caves and crypts;
-- lairs: the Elite II hideouts (Data/Areas lairs); dungeonBosses: Data/Bosses.list (no world boss).
local function buildGroups(): { [string]: { [string]: boolean } }
	local built: { [string]: { [string]: boolean } } =
		{ regions = {}, world = {}, caves = {}, lairs = {}, dungeonBosses = {} }
	for id, map in Maps.byId do
		if travelMap(map) then
			built.world[id] = true
			if UNDERGROUND[map.biome] then
				built.caves[id] = true
			else
				built.regions[id] = true
			end
		end
	end
	for _, data in Areas.byMap do
		for _, lair in (data.lairs or {}) :: { any } do
			built.lairs[lair.id] = true
		end
	end
	for _, boss in Bosses.list do
		built.dungeonBosses[boss.id] = true
	end
	for name, members in built do
		local n = 0
		for _ in members do
			n += 1
		end
		groupSizes[name] = n
	end
	return built
end

local function groupsOf(): { [string]: { [string]: boolean } }
	local g = groups
	if g ~= nil then
		return g
	end
	local built = buildGroups()
	groups = built
	return built
end

-- The ids of a group (a set; nil for an unknown group).
function Achievements.group(name: string): { [string]: boolean }?
	return groupsOf()[name]
end

-- State -------------------------------------------------------------------------------------------------------------

local function number(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	if value == math.huge then
		return 0
	end
	return value
end

-- Repairs a branch in place (garbage -> empty tables, negative / NaN numbers -> 0) or makes a new one.
local function branchOf(raw: any, withPaid: boolean): Branch
	local b: any = if type(raw) == "table" then raw else {}
	for _, field in { "c", "s", "done" } do
		if type(b[field]) ~= "table" then
			b[field] = {}
		end
	end
	if withPaid and type(b.paid) ~= "table" then
		b.paid = {}
	end
	for counter, value in b.c do
		if type(value) ~= "number" or number(value) ~= value then
			b.c[counter] = number(value)
		end
	end
	for counter, set in b.s do
		if type(set) ~= "table" then
			b.s[counter] = {}
		end
	end
	return b :: Branch
end

-- S151b: the tracked ids of a character branch: strings in order, no duplicates, at most trackMax (a clean copy).
local function trackOf(b: any)
	local clean: { string } = {}
	if type(b.track) == "table" then
		for _, id in ipairs(b.track) do
			if type(id) == "string" and not table.find(clean, id) and #clean < Config.Achievements.trackMax then
				table.insert(clean, id)
			end
		end
	end
	b.track = clean
end

-- The achievement state of an account and its character. The branches are the save's own tables (repaired in place and
-- attached when missing), so the server writes into them and replicates the changed paths.
function Achievements.state(account: any, character: any): State
	local acc = branchOf(if type(account) == "table" then account.ach else nil, true)
	if type(account) == "table" then
		account.ach = acc
	end
	local chr = branchOf(if type(character) == "table" then character.ach else nil, false)
	trackOf(chr)
	if type(character) == "table" then
		character.ach = chr
	end
	-- S151b: an id that is unknown or done (an account achievement earned by another character) leaves the tracker
	local track = chr.track :: { string }
	for i = #track, 1, -1 do
		local def = AchData.get(track[i])
		local branch = if def and Achievements.scopeOf(def.counter) == "account" then acc else chr
		if not def or branch.done[def.id] ~= nil then
			table.remove(track, i)
		end
	end
	return { acc = acc, chr = chr }
end

-- The branch an achievement or counter belongs to ("account" -> acc, otherwise chr).
function Achievements.scopeOf(counter: string): string
	local def = AchData.COUNTERS[counter]
	return if def then def.scope else "character"
end

local function branchFor(st: State, counter: string): Branch
	return if Achievements.scopeOf(counter) == "account" then st.acc else st.chr
end

-- Progress ----------------------------------------------------------------------------------------------------------

local function setSize(set: { [string]: boolean }?): number
	local n = 0
	local members: { [string]: boolean } = set or {}
	for _, v in members do
		if v == true then
			n += 1
		end
	end
	return n
end

-- The goal of an achievement: the number of ids of its group for `all` (grows with the data), 1 for `key`.
function Achievements.goalOf(def: AchDef): number
	if def.all then
		groupsOf()
		return groupSizes[def.all] or 0
	elseif def.key then
		return 1
	end
	return def.goal
end

-- (value, goal) of an achievement in a state (the window of S151b, tests).
function Achievements.progress(st: State, def: AchDef): (number, number)
	local b = branchFor(st, def.counter)
	local goal = Achievements.goalOf(def)
	local set = b.s[def.counter]
	if def.key then
		return if set and set[def.key] == true then 1 else 0, goal
	elseif def.all then
		local members: { [string]: boolean } = Achievements.group(def.all) or {}
		local n = 0
		for id in members do
			if set and set[id] == true then
				n += 1
			end
		end
		return n, goal
	end
	local mode = (AchData.COUNTERS[def.counter] or { mode = "add" }).mode
	if mode == "set" then
		return setSize(set), goal
	end
	return number(b.c[def.counter]), goal
end

function Achievements.isMet(st: State, def: AchDef): boolean
	local value, goal = Achievements.progress(st, def)
	return goal > 0 and value >= goal
end

function Achievements.isDone(st: State, def: AchDef): boolean
	return branchFor(st, def.counter).done[def.id] ~= nil
end

-- The achievements of each counter in goal order (goalOf: `all` goals come from the data), built once.
local ordered: { [string]: { AchDef } } = {}
local function orderedFor(counter: string): { AchDef }
	local cached = ordered[counter]
	if cached then
		return cached
	end
	local defs: { AchDef } = table.clone(AchData.byCounter[counter] or {})
	table.sort(defs, function(a: AchDef, b: AchDef): boolean
		local ga, gb = Achievements.goalOf(a), Achievements.goalOf(b)
		if ga ~= gb then
			return ga < gb
		end
		return a.id < b.id
	end)
	ordered[counter] = defs
	return defs
end

-- Achievements of `counter` met in `st` and not done yet, in goal order.
function Achievements.pending(st: State, counter: string): { string }
	local out: { string } = {}
	for _, def in orderedFor(counter) do
		if not Achievements.isDone(st, def) and Achievements.isMet(st, def) then
			table.insert(out, def.id)
		end
	end
	return out
end

-- Every achievement met and not done (after a catch-up, a new achievement over an old counter, an admin reset).
function Achievements.allPending(st: State): { string }
	local out: { string } = {}
	for _, def in AchData.list do
		if not Achievements.isDone(st, def) and Achievements.isMet(st, def) then
			table.insert(out, def.id)
		end
	end
	return out
end

-- Changes one counter: "add" (+value), "max" (the higher one), "set" (adds `key` to the set; the count goes to c).
-- Returns the achievements of the counter that are met and not done (done is written by the server together with the
-- reward) and whether anything changed. Unknown counters and bad values change nothing.
function Achievements.apply(st: State, counter: string, mode: string, value: number, key: string?): Applied
	if AchData.COUNTERS[counter] == nil then
		return { newly = {}, changed = false }
	end
	local b = branchFor(st, counter)
	local changed = false
	if mode == "set" then
		if type(key) ~= "string" or key == "" then
			return { newly = {}, changed = false }
		end
		local set = b.s[counter]
		if not set then
			set = {}
			b.s[counter] = set
		end
		if set[key] ~= true then
			set[key] = true
			b.c[counter] = setSize(set)
			changed = true
		end
	else
		local v = number(value)
		local old = number(b.c[counter])
		local new = if mode == "max" then math.max(old, math.floor(v)) else old + math.floor(v)
		if new ~= old then
			b.c[counter] = new
			changed = true
		end
	end
	return { newly = if changed then Achievements.pending(st, counter) else {}, changed = changed }
end

-- Tracking (S151b) -----------------------------------------------------------------------------------------------------

-- The ids the character follows in the HUD tracker (the save's own list).
function Achievements.tracked(st: State): { string }
	local list = st.chr.track
	if list == nil then
		list = {}
		st.chr.track = list
	end
	return list :: { string }
end

-- Whether `id` may be added to the tracker: a known achievement, not done, not secret, a free place (an id already
-- tracked is fine). Error keys ach.error.unknown / .done / .secret / .full.
function Achievements.canTrack(st: State, id: string): (boolean, string?)
	local def = AchData.get(id)
	if not def then
		return false, "ach.error.unknown"
	end
	if Achievements.isDone(st, def) then
		return false, "ach.error.done"
	end
	if def.secret == true then
		return false, "ach.error.secret"
	end
	local list = Achievements.tracked(st)
	if not table.find(list, id) and #list >= Config.Achievements.trackMax then
		return false, "ach.error.full"
	end
	return true, nil
end

-- Follows (`on`) or stops following `id`. Returns (ok, errorKey?, changed): stopping an id that is not tracked is ok
-- and changes nothing.
function Achievements.setTracked(st: State, id: string, on: boolean): (boolean, string?, boolean)
	local list = Achievements.tracked(st)
	local at = table.find(list, id)
	if not on then
		if at then
			table.remove(list, at)
			return true, nil, true
		end
		return true, nil, false
	end
	local ok, err = Achievements.canTrack(st, id)
	if not ok then
		return false, err, false
	end
	if at then
		return true, nil, false
	end
	table.insert(list, id)
	return true, nil, true
end

-- Rewards -----------------------------------------------------------------------------------------------------------

-- The reward of an achievement; Dragon Shards only while `paid[def.id]` is not set (once per account: the same
-- character achievement on a second character pays no shards again).
function Achievements.reward(def: AchDef, paid: { [string]: boolean }?): Reward
	local r: AchData.Reward = def.reward or {}
	local shards = if paid and paid[def.id] == true then 0 else math.max(0, math.floor(r.shards or 0))
	return {
		title = r.title,
		cosmetic = r.cosmetic,
		shards = shards,
		gold = math.max(0, math.floor(r.gold or 0)),
	}
end

-- The sum of every Dragon Shard reward (<= Config.Achievements.shardBudget, tests/achievements.spec).
function Achievements.shardTotal(): number
	local total = 0
	for _, def in AchData.list do
		total += (def.reward and def.reward.shards) or 0
	end
	return total
end

function Achievements.budget(): number
	return Config.Achievements.shardBudget
end

-- Events -> counters --------------------------------------------------------------------------------------------------

local function add(counter: string, n: number?): Entry
	return { counter = counter, mode = "add", value = n or 1 }
end

local function max(counter: string, n: number): Entry
	return { counter = counter, mode = "max", value = n }
end

local function member(counter: string, key: string): Entry
	return { counter = counter, mode = "set", value = 1, key = key }
end

-- A whole positive count from event data (1 when missing, 0 for garbage).
local function count(value: any, default: number?): number
	if value == nil then
		return default or 1
	end
	if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

local function amount(counter: string, value: any): { Entry }
	local n = count(value)
	return if n > 0 then { add(counter, n) } else {}
end

local function worldBossId(): string
	local first = Bosses.world[1]
	return if first then first.id else "hrimvald"
end

-- A cosmetic earned in the game (earnedCosmetics): it has an obtain, and that obtain is not a Robux source (the VIP
-- cosmetic of the month, a starter pack).
function Achievements.earnedInGame(def: Cosmetics.Def?): boolean
	local obtain = def and def.obtain
	return obtain ~= nil and obtain.vipMonth == nil and obtain.pack == nil
end

-- QuestEvents kinds (and the kill / level signals, mapped onto "kill" / "level" by the server) -> counter changes.
-- Every new source of progress: a kind here and one QuestEvents.fire line in the service that knows the fact.
local COUNTER_EVENTS: { [string]: (data: { [string]: any }) -> { Entry } } = {
	kill = function(data)
		local out = { add("kills") }
		if data.variant == "elite" then
			table.insert(out, add("eliteKills"))
		elseif data.variant == "elite2" then
			table.insert(out, add("elite2Kills"))
			-- S134i: an Elite II of a hideout (the spawner's lair id)
			if type(data.lair) == "string" and data.lair ~= "" then
				table.insert(out, member("lairs", data.lair))
			end
		end
		return out
	end,
	boss = function(data)
		local out: { Entry } = { add("bossKills") }
		if type(data.bossId) == "string" and data.bossId ~= "" then
			table.insert(out, member("bosses", data.bossId))
		end
		if type(data.party) == "number" and data.party >= AchData.FULL_PARTY then
			table.insert(out, add("fullParty"))
		end
		return out
	end,
	worldboss = function(data)
		local id = if type(data.bossId) == "string" and data.bossId ~= "" then data.bossId else worldBossId()
		return { add("worldBoss"), member("bosses", id) }
	end,
	event = function(data)
		return if data.kind == "invasion" and data.success == true then { add("invasions") } else {}
	end,
	bloodmoon = function(data)
		return if type(data.id) == "string" and data.id ~= "" then { member("bloodMoon", data.id) } else {}
	end,
	-- duels and (S126) ranked arena matches (ArenaService adds arena = true)
	duel = function(data)
		if data.won ~= true then
			return {}
		end
		return { add(if data.arena == true then "arenaWins" else "duelsWon") }
	end,
	pvpkill = function(_data)
		return { add("pvpKills") }
	end,
	upgrade = function(data)
		local to = if type(data.to) == "number" then data.to else 0
		local out: { Entry } = {}
		if to >= 7 then
			table.insert(out, add("upgraded7"))
		end
		if to >= 9 then
			table.insert(out, add("upgraded9"))
		end
		return out
	end,
	craft = function(data)
		return amount("crafted", data.n)
	end,
	dismantle = function(data)
		return amount("dismantled", data.n)
	end,
	reroll = function(_data)
		return { add("rerolled") }
	end,
	brew = function(data)
		return amount("brewed", data.n)
	end,
	gather = function(data)
		return amount("gathered", data.n)
	end,
	fish = function(_data)
		return { add("fish") }
	end,
	trade = function(_data)
		return { add("trades") }
	end,
	mail = function(_data)
		return { add("mailSent") }
	end,
	visit = function(data)
		local id = data.mapId
		if type(id) ~= "string" then
			return {}
		end
		local g = groupsOf()
		local out: { Entry } = {}
		if g.world[id] then
			table.insert(out, member("maps", id))
		end
		if g.caves[id] then
			table.insert(out, member("caves", id))
		end
		return out
	end,
	level = function(data)
		local level = count(data.level, 0)
		return if level > 0 then { max("level", level) } else {}
	end,
	quest = function(data)
		if data.kind == "main" then
			local index = count(data.index, 0)
			return if index > 0 then { max("mainDone", index) } else {}
		elseif data.kind == "side" then
			return { add("sideDone") }
		elseif data.kind == "contract" then
			return amount("contracts", data.n)
		end
		return {}
	end,
	dodge = function(data)
		return amount("dodged", data.n)
	end,
	social = function(data)
		local out: { Entry } = {}
		if type(data.friends) == "number" then
			local n = count(data.friends, 0)
			if n > 0 then
				table.insert(out, max("friends", n))
			end
		end
		if data.guild == true then
			table.insert(out, max("guild", 1))
		end
		return out
	end,
	cosmetic = function(data)
		local def = if type(data.id) == "string" then Cosmetics.get(data.id) else nil
		return if Achievements.earnedInGame(def) then { add("earnedCosmetics") } else {}
	end,
}
Achievements.COUNTER_EVENTS = table.freeze(COUNTER_EVENTS)

-- The counter changes of one event (nothing for an unknown kind).
function Achievements.entriesFor(kind: string, data: { [string]: any }?): { Entry }
	local fn = COUNTER_EVENTS[kind]
	if not fn then
		return {}
	end
	return fn(if type(data) == "table" then data else {})
end

-- Old progress --------------------------------------------------------------------------------------------------------

local function tableOf(value: any): { [any]: any }
	return if type(value) == "table" then value else {}
end

local function trueCount(value: any): number
	local n = 0
	for _, v in tableOf(value) do
		if v == true then
			n += 1
		end
	end
	return n
end

-- Dungeon bosses a character has surely defeated: the story quest with that boss objective handed in, or the boss quest
-- boss_<id> (S98) handed in. bossRuns (today only) and bossPity (kills without loot) prove nothing for good.
local function bossesOf(character: any, out: { [string]: boolean })
	local quests = tableOf(character.quests)
	local mainDone = number(quests.mainDone)
	local sideDone = tableOf(tableOf(quests.side).done)
	for _, boss in Bosses.list do
		if sideDone[`boss_{boss.id}`] == true then
			out[boss.id] = true
		end
	end
	for index, quest in Quests.Main.list do
		if index > mainDone then
			break
		end
		for _, objective in quest.objectives do
			if objective.type == "boss" and objective.boss then
				out[objective.boss] = true
			end
		end
	end
end

-- What the save proves of the counters, as `max` / `set` entries (applied like events, so a second run changes
-- nothing). Character counters from `character`; account counters from the account and every character on it. What
-- the save does not keep (kills, crafting, gathering, trades, letters, dodges, Elite II, hideouts, Blood Moons, …)
-- counts from S151 on.
function Achievements.backfill(account: any, character: any): { Entry }
	local out: { Entry } = {}
	local acc = tableOf(account)
	local chr = tableOf(character)
	-- character
	local level = math.floor(number(chr.level))
	if level > 0 then
		table.insert(out, max("level", level))
	end
	local quests = tableOf(chr.quests)
	local mainDone = math.floor(number(quests.mainDone))
	if mainDone > 0 then
		table.insert(out, max("mainDone", mainDone))
	end
	local side = trueCount(tableOf(quests.side).done)
	if side > 0 then
		table.insert(out, max("sideDone", side))
	end
	local contract = tableOf(quests.contract)
	local contracts = math.floor(number(contract.done)) + #tableOf(contract.extra)
	if contracts > 0 then
		table.insert(out, max("contracts", contracts))
	end
	local pvp = tableOf(chr.pvp)
	if number(pvp.kills) > 0 then
		table.insert(out, max("pvpKills", math.floor(number(pvp.kills))))
	end
	if number(pvp.duelsWon) > 0 then
		table.insert(out, max("duelsWon", math.floor(number(pvp.duelsWon))))
	end
	-- the arena keeps the current and the last season only: a lower bound
	local arena = tableOf(chr.arena)
	local last = tableOf(arena.last)
	local arenaWins = math.max(number(arena.wins) + number(arena.wins3), number(last.wins) + number(last.wins3))
	if arenaWins > 0 then
		table.insert(out, max("arenaWins", math.floor(arenaWins)))
	end
	local g = groupsOf()
	local mapIds: { string } = {}
	for id, v in tableOf(chr.visitedMaps) do
		if v == true and type(id) == "string" then
			table.insert(mapIds, id)
		end
	end
	table.sort(mapIds)
	for _, id in mapIds do
		if g.world[id] then
			table.insert(out, member("maps", id))
		end
		if g.caves[id] then
			table.insert(out, member("caves", id))
		end
	end
	-- account (every character of the account counts)
	local characters: { any } = {}
	if type(character) == "table" then
		table.insert(characters, chr)
	end
	for _, other in tableOf(acc.characters) do
		if type(other) == "table" and other ~= chr then
			table.insert(characters, other)
		end
	end
	local bosses: { [string]: boolean } = {}
	local guild = false
	for _, c in characters do
		bossesOf(c, bosses)
		if type(c.guildId) == "string" and c.guildId ~= "" then
			guild = true
		end
	end
	local bossIds: { string } = {}
	for id in bosses do
		table.insert(bossIds, id)
	end
	table.sort(bossIds)
	for _, id in bossIds do
		table.insert(out, member("bosses", id))
	end
	if #bossIds > 0 then
		table.insert(out, max("bossKills", #bossIds))
	end
	local worldBoss = tableOf(acc.worldBoss)
	if type(worldBoss.last) == "string" and worldBoss.last ~= "" then
		table.insert(out, max("worldBoss", 1))
	end
	local friends = 0
	for _ in tableOf(tableOf(acc.social).friends) do
		friends += 1
	end
	if friends > 0 then
		table.insert(out, max("friends", friends))
	end
	if guild then
		table.insert(out, max("guild", 1))
	end
	local earned = 0
	for _, owned in { tableOf(acc.cosmetics).owned, tableOf(acc.pets).owned } do
		for id, v in tableOf(owned) do
			local def = if v == true and type(id) == "string" then Cosmetics.get(id) else nil
			if Achievements.earnedInGame(def) then
				earned += 1
			end
		end
	end
	if earned > 0 then
		table.insert(out, max("earnedCosmetics", earned))
	end
	return out
end

-- Applies a list of entries; the achievements met and not done afterwards (every one, not only of these counters).
function Achievements.applyAll(st: State, entries: { Entry }): { string }
	for _, e in entries do
		Achievements.apply(st, e.counter, e.mode, e.value, e.key)
	end
	return Achievements.allPending(st)
end

-- Marks an achievement done (the server does it together with the reward; tests and the shard model).
function Achievements.markDone(st: State, def: AchDef, at: number)
	branchFor(st, def.counter).done[def.id] = at
end

-- The shard model (docs/SESJE.md S151) ----------------------------------------------------------------------------------

-- A typical character of level `level` before S151: every story quest up to its level, half of the side quests and
-- contracts up to it, every travel map up to it visited; no PvP, arena, friends, guild or earned cosmetics.
function Achievements.typical(level: number): (any, any)
	local mainDone = 0
	for index, quest in Quests.Main.list do
		if quest.level <= level then
			mainDone = index
		end
	end
	local sideDone: { [string]: boolean } = {}
	local sideAll: { string } = {}
	for _, quest in Quests.Side.list do
		if quest.level <= level then
			table.insert(sideAll, quest.id)
		end
	end
	table.sort(sideAll)
	for i, id in sideAll do
		if i % 2 == 0 then
			sideDone[id] = true
		end
	end
	local visited: { [string]: boolean } = {}
	for id, map in Maps.byId do
		if travelMap(map) and map.minLevel <= level then
			visited[id] = true
		end
	end
	local character = {
		id = "typical",
		level = level,
		quests = {
			mainDone = mainDone,
			side = { done = sideDone },
			contract = { done = math.floor(math.min(level - 1, 99) / 2), extra = {} },
		},
		visitedMaps = visited,
	}
	local account = { characters = { ["1"] = character } }
	return account, character
end

-- Dragon Shards a typical character of `level` gets at once from the catch-up of old progress.
function Achievements.shardsBy(level: number): number
	local account, character = Achievements.typical(level)
	local st = Achievements.state(account, character)
	local total = 0
	for _, id in Achievements.applyAll(st, Achievements.backfill(account, character)) do
		local def = AchData.get(id)
		if def then
			total += Achievements.reward(def, st.acc.paid).shards
		end
	end
	return total
end

return Achievements
