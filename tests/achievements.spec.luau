--!strict
-- S151 (docs/DESIGN.md §20b): achievements: the data, the shard budget, counting, rewards once per account, the events
-- of QuestEvents, the catch-up of old progress and the save without a migration.
local fs = require("@lune/fs")

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local AchData = require("../src/shared/Data/Achievements")
local AchievementView = require("../src/shared/Logic/AchievementView")
local Achievements = require("../src/shared/Logic/Achievements")
local Areas = require("../src/shared/Data/Areas")
local Bosses = require("../src/shared/Data/Bosses")
local Config = require("../src/shared/Config")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Maps = require("../src/shared/Data/Maps")
local Quests = require("../src/shared/Data/Quests")
local T = require("./Test")
local TitleData = require("../src/shared/Data/Titles")
local WeeklyOffer = require("../src/shared/Logic/WeeklyOffer")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local function fresh(): (any, any, Achievements.State)
	local account: any = AccountSchema.accountTemplate()
	local character: any = AccountSchema.characterTemplate()
	character.id = "c1"
	account.characters["1"] = character
	return account, character, Achievements.state(account, character)
end

local function counters(entries: { Achievements.Entry }): { [string]: any }
	local out: { [string]: any } = {}
	for _, e in entries do
		out[e.counter] = if e.mode == "set" then e.key else e.value
	end
	return out
end

local function contains(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

T.describe("Achievements data (S151)", function()
	T.it("every achievement has a known counter, category and points, and texts in both languages", function()
		for _, def in AchData.list do
			T.expect({ def.id, AchData.COUNTERS[def.counter] ~= nil }).toEqual({ def.id, true })
			T.expect({ def.id, table.find(AchData.CATEGORIES, def.cat) ~= nil }).toEqual({ def.id, true })
			T.expect({ def.id, table.find(AchData.POINTS, def.points) ~= nil }).toEqual({ def.id, true })
			for _, key in { `ach.{def.id}.name`, `ach.{def.id}.desc` } do
				T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			end
			T.expect({ def.id, Achievements.goalOf(def) > 0 }).toEqual({ def.id, true })
		end
		for _, cat in AchData.CATEGORIES do
			T.expect({ cat, pl[`ach.cat.{cat}`] ~= nil, en[`ach.cat.{cat}`] ~= nil }).toEqual({ cat, true, true })
			T.expect({ cat, #AchData.forCategory(cat) > 0 }).toEqual({ cat, true })
		end
		T.expect(#AchData.list >= 55).toBe(true)
	end)

	T.it("a series step follows an existing lower step of the same counter", function()
		for _, def in AchData.list do
			if def.after then
				local prev = AchData.get(def.after)
				T.expect({ def.id, prev ~= nil }).toEqual({ def.id, true })
				if prev then
					T.expect({ def.id, prev.counter }).toEqual({ def.id, def.counter })
					T.expect({ def.id, Achievements.goalOf(prev) < Achievements.goalOf(def) }).toEqual({ def.id, true })
				end
			end
		end
	end)

	T.it("key and all goals use set counters and known groups", function()
		for _, def in AchData.list do
			if def.key or def.all then
				T.expect({ def.id, AchData.COUNTERS[def.counter].mode }).toEqual({ def.id, "set" })
			end
			if def.all then
				T.expect({ def.id, Achievements.group(def.all) ~= nil }).toEqual({ def.id, true })
			end
		end
		-- every dungeon boss has its own achievement
		for _, boss in Bosses.list do
			local def = AchData.get(`boss_{boss.id}`)
			T.expect({ boss.id, def and def.key }).toEqual({ boss.id, boss.id })
		end
	end)

	T.it(
		"a cosmetic reward is earned only (obtain.achievement = the id, price 0, never in the offer of the week)",
		function()
			local pool = WeeklyOffer.pool()
			local n = 0
			for _, def in AchData.list do
				local id = def.reward and def.reward.cosmetic
				if id then
					n += 1
					local cosmetic = Cosmetics.get(id)
					T.expect({ id, cosmetic ~= nil }).toEqual({ id, true })
					if cosmetic then
						local fields = 0
						for _ in cosmetic.obtain or {} do
							fields += 1
						end
						T.expect({ id, cosmetic.obtain and cosmetic.obtain.achievement, fields, cosmetic.price })
							.toEqual({
								id,
								def.id,
								1,
								0,
							})
						T.expect({ id, cosmetic.weekly, cosmetic.wiki }).toEqual({ id, nil, false })
						T.expect({ id, table.find(pool, id) }).toEqual({ id, nil })
					end
				end
			end
			T.expect(n).toBe(5)
			-- and the other way round: an obtain.achievement names the achievement that gives it
			for _, cosmetic in Cosmetics.list do
				local achId = cosmetic.obtain and cosmetic.obtain.achievement
				if achId then
					local def = AchData.get(achId)
					T.expect({ cosmetic.id, def and def.reward and def.reward.cosmetic })
						.toEqual({ cosmetic.id, cosmetic.id })
				end
			end
		end
	)

	T.it("a title reward is a title with req.kind achievement on that achievement", function()
		for _, def in AchData.list do
			local id = def.reward and def.reward.title
			if id then
				local title = TitleData.get(id)
				T.expect({ id, title and title.req.kind, title and (title.req :: any).id }).toEqual({
					id,
					"achievement",
					def.id,
				})
			end
		end
	end)
end)

T.describe("Dragon Shard budget (S151, DESIGN-17 §0)", function()
	T.it("the sum stays within Config.Achievements.shardBudget, none above 50, none for social", function()
		T.expect(Config.Achievements.shardBudget).toBe(500)
		T.expect(Achievements.shardTotal() <= Config.Achievements.shardBudget).toBe(true)
		T.expect(Achievements.shardTotal() > 0).toBe(true)
		for _, def in AchData.list do
			local shards = (def.reward and def.reward.shards) or 0
			T.expect({ def.id, shards >= 0 and shards <= 50 }).toEqual({ def.id, true })
			if def.cat == "social" then
				T.expect({ def.id, shards }).toEqual({ def.id, 0 })
			end
			local gold = (def.reward and def.reward.gold) or 0
			if gold > 0 then
				T.expect({ def.id, def.cat == "journey" or def.cat == "craft" }).toEqual({ def.id, true })
			end
		end
	end)

	T.it("shards are paid once per account", function()
		local def = AchData.get("level100") :: AchData.AchDef
		T.expect(Achievements.reward(def, {}).shards).toBe(50)
		T.expect(Achievements.reward(def, nil).shards).toBe(50)
		T.expect(Achievements.reward(def, { level100 = true }).shards).toBe(0)
		local titled = AchData.get("slayer4") :: AchData.AchDef
		T.expect(Achievements.reward(titled, { slayer4 = true }).title).toBe("ach_butcher")
	end)

	T.it("the catch-up model: a typical level 100 character gets less than the budget at once", function()
		T.expect(Achievements.shardsBy(1)).toBe(0)
		local at50, at100 = Achievements.shardsBy(50), Achievements.shardsBy(100)
		T.expect(at50 <= at100).toBe(true)
		T.expect(at100 > 0 and at100 <= Achievements.shardTotal()).toBe(true)
	end)
end)

T.describe("Counting (S151)", function()
	T.it("add, max and set", function()
		local _, _, st = fresh()
		local r = Achievements.apply(st, "kills", "add", 99, nil)
		T.expect(r.changed).toBe(true)
		T.expect(#r.newly).toBe(0)
		r = Achievements.apply(st, "kills", "add", 1, nil)
		T.expect(r.newly).toEqual({ "slayer1" })
		T.expect(st.chr.c.kills).toBe(100)
		r = Achievements.apply(st, "level", "max", 30, nil)
		T.expect(r.newly).toEqual({ "level10", "level25" }) -- goal order
		r = Achievements.apply(st, "level", "max", 12, nil)
		T.expect(r.changed).toBe(false)
		T.expect(st.chr.c.level).toBe(30)
		r = Achievements.apply(st, "bosses", "set", 1, "grimrok")
		T.expect(r.newly).toEqual({ "boss_grimrok" })
		T.expect(st.acc.s.bosses).toEqual({ grimrok = true })
		T.expect(st.acc.c.bosses).toBe(1)
		r = Achievements.apply(st, "bosses", "set", 1, "grimrok")
		T.expect(r.changed).toBe(false)
		-- unknown counters and garbage change nothing
		T.expect(Achievements.apply(st, "nope", "add", 5, nil).changed).toBe(false)
		T.expect(Achievements.apply(st, "kills", "add", 0 / 0, nil).changed).toBe(false)
		T.expect(Achievements.apply(st, "kills", "add", -5, nil).changed).toBe(false)
		T.expect(Achievements.apply(st, "maps", "set", 1, nil).changed).toBe(false)
	end)

	T.it("a done achievement is never newly again", function()
		local _, _, st = fresh()
		local r = Achievements.apply(st, "fish", "add", 50, nil)
		T.expect(r.newly).toEqual({ "fish1" })
		Achievements.markDone(st, AchData.get("fish1") :: AchData.AchDef, 1)
		r = Achievements.apply(st, "fish", "add", 1, nil)
		T.expect(r.newly).toEqual({})
		T.expect(st.chr.done.fish1).toBe(1)
	end)

	T.it("account counters go to the account, character ones to the character", function()
		local account, character, st = fresh()
		Achievements.apply(st, "trades", "add", 3, nil)
		Achievements.apply(st, "crafted", "add", 2, nil)
		T.expect(account.ach.c.trades).toBe(3)
		T.expect(character.ach.c.crafted).toBe(2)
		T.expect(account.ach.c.crafted).toBeNil()
		T.expect(Achievements.scopeOf("bosses")).toBe("account")
		T.expect(Achievements.scopeOf("lairs")).toBe("character")
	end)

	T.it("the state repairs garbage and keeps the save's own tables", function()
		local account: any = { ach = { c = { kills = -4, fish = 0 / 0, gold = 7 }, s = "x", done = 5 } }
		local character: any = { ach = 12 }
		local st = Achievements.state(account, character)
		T.expect(st.acc.c).toEqual({ kills = 0, fish = 0, gold = 7 })
		T.expect(st.acc.s).toEqual({})
		T.expect(st.acc.done).toEqual({})
		T.expect(st.acc.paid).toEqual({})
		T.expect(account.ach == st.acc).toBe(true)
		T.expect(character.ach == st.chr).toBe(true)
		local again = Achievements.state(account, character)
		T.expect(again.acc == st.acc and again.chr == st.chr).toBe(true)
	end)

	T.it("goals of `all` come from the data", function()
		local _, _, st = fresh()
		local regions, world, caves = 0, 0, 0
		for _, map in Maps.byId do
			if map.biome ~= "dungeon" and map.serverModes == nil and map.hidden ~= true then
				world += 1
				if map.biome == "cave" or map.biome == "crypt" then
					caves += 1
				else
					regions += 1
				end
			end
		end
		local lairs = 0
		for _, data in Areas.byMap do
			lairs += #(data.lairs or {})
		end
		local function goal(id: string): number
			local _, g = Achievements.progress(st, AchData.get(id) :: AchData.AchDef)
			return g
		end
		T.expect(goal("maps1")).toBe(regions)
		T.expect(goal("maps2")).toBe(world)
		T.expect(goal("caves1")).toBe(caves)
		T.expect(goal("lairs2")).toBe(lairs)
		T.expect(goal("bossAll")).toBe(#Bosses.list)
		T.expect(goal("boss_azgor")).toBe(1)
		T.expect(goal("lairs1") < lairs).toBe(true)
		-- a map outside the group never counts
		Achievements.apply(st, "maps", "set", 1, "dungeon_meadows")
		T.expect((Achievements.progress(st, AchData.get("maps2") :: AchData.AchDef))).toBe(0)
	end)
end)

T.describe("Events -> counters (S151)", function()
	T.it("every kind maps onto its counters", function()
		local E = Achievements.entriesFor
		T.expect(counters(E("kill", { variant = "normal" }))).toEqual({ kills = 1 })
		T.expect(counters(E("kill", { variant = "elite" }))).toEqual({ kills = 1, eliteKills = 1 })
		T.expect(counters(E("kill", { variant = "elite2", lair = "meadows_snarecamp" }))).toEqual({
			kills = 1,
			elite2Kills = 1,
			lairs = "meadows_snarecamp",
		})
		T.expect(counters(E("kill", { variant = "normal", lair = "meadows_snarecamp" }))).toEqual({ kills = 1 })
		T.expect(counters(E("boss", { bossId = "azgor", party = 5 }))).toEqual({
			bossKills = 1,
			bosses = "azgor",
			fullParty = 1,
		})
		T.expect(counters(E("boss", { bossId = "azgor", party = 4 }))).toEqual({ bossKills = 1, bosses = "azgor" })
		T.expect(counters(E("worldboss", { occId = "x" }))).toEqual({ worldBoss = 1, bosses = Bosses.world[1].id })
		T.expect(counters(E("event", { kind = "invasion", success = true }))).toEqual({ invasions = 1 })
		T.expect(counters(E("event", { kind = "invasion", success = false }))).toEqual({})
		T.expect(counters(E("event", { kind = "champion", success = true }))).toEqual({})
		T.expect(counters(E("bloodmoon", { id = "20261013" }))).toEqual({ bloodMoon = "20261013" })
		T.expect(counters(E("duel", { won = true }))).toEqual({ duelsWon = 1 })
		T.expect(counters(E("duel", { won = false }))).toEqual({})
		T.expect(counters(E("duel", { won = true, arena = true }))).toEqual({ arenaWins = 1 })
		T.expect(counters(E("pvpkill", {}))).toEqual({ pvpKills = 1 })
		T.expect(counters(E("upgrade", { to = 6 }))).toEqual({})
		T.expect(counters(E("upgrade", { to = 7 }))).toEqual({ upgraded7 = 1 })
		T.expect(counters(E("upgrade", { to = 9 }))).toEqual({ upgraded7 = 1, upgraded9 = 1 })
		T.expect(counters(E("craft", { recipeId = "x", n = 1 }))).toEqual({ crafted = 1 })
		T.expect(counters(E("dismantle", { n = 12 }))).toEqual({ dismantled = 12 })
		T.expect(counters(E("reroll", {}))).toEqual({ rerolled = 1 })
		T.expect(counters(E("brew", { n = 3 }))).toEqual({ brewed = 3 })
		T.expect(counters(E("gather", { n = 2 }))).toEqual({ gathered = 2 })
		T.expect(counters(E("fish", { fishId = "x" }))).toEqual({ fish = 1 })
		T.expect(counters(E("trade", {}))).toEqual({ trades = 1 })
		T.expect(counters(E("mail", {}))).toEqual({ mailSent = 1 })
		T.expect(counters(E("visit", { mapId = "meadows" }))).toEqual({ maps = "meadows" })
		T.expect(counters(E("visit", { mapId = "meadows_cave" })))
			.toEqual({ maps = "meadows_cave", caves = "meadows_cave" })
		T.expect(counters(E("visit", { mapId = "dungeon_meadows" }))).toEqual({})
		T.expect(counters(E("level", { level = 42 }))).toEqual({ level = 42 })
		T.expect(counters(E("quest", { kind = "main", index = 18 }))).toEqual({ mainDone = 18 })
		T.expect(counters(E("quest", { kind = "side", questId = "x" }))).toEqual({ sideDone = 1 })
		T.expect(counters(E("quest", { kind = "contract", n = 3 }))).toEqual({ contracts = 3 })
		T.expect(counters(E("dodge", { n = 4 }))).toEqual({ dodged = 4 })
		T.expect(counters(E("social", { friends = 6 }))).toEqual({ friends = 6 })
		T.expect(counters(E("social", { guild = true }))).toEqual({ guild = 1 })
		T.expect(counters(E("cosmetic", { id = "frame_bloodmoon" }))).toEqual({ earnedCosmetics = 1 })
		T.expect(counters(E("cosmetic", { id = "frame_bronze" }))).toEqual({}) -- bought, not earned
		T.expect(counters(E("cosmetic", { id = "aura_vip_hearth" }))).toEqual({}) -- VIP (Robux)
		T.expect(counters(E("cosmetic", { id = "aura_valor" }))).toEqual({}) -- starter pack (Robux)
		T.expect(counters(E("dismantle", { n = 0 / 0 }))).toEqual({})
	end)

	T.it("an unknown kind and the tutorial kinds count nothing", function()
		for _, kind in { "nope", "equip", "loot", "stats", "learn", "potion", "escort", "use", "reach", "talk" } do
			T.expect({ kind, #Achievements.entriesFor(kind, {}) }).toEqual({ kind, 0 })
		end
	end)

	T.it("every kind fired in the server is counted or deliberately not", function()
		local IGNORED = {
			equip = true,
			loot = true,
			stats = true,
			learn = true,
			potion = true,
			escort = true,
			use = true,
			reach = true,
		}
		local function walk(dir: string, out: { string })
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					walk(path, out)
				elseif string.match(name, "%.luau$") then
					table.insert(out, path)
				end
			end
		end
		local files: { string } = {}
		walk("src/server", files)
		local seen: { [string]: boolean } = {}
		for _, path in files do
			for kind in string.gmatch(fs.readFile(path), 'QuestEvents%.fire%([^,]+,%s*"([%w_]+)"') do
				seen[kind] = true
			end
		end
		for kind in seen do
			T.expect({ kind, Achievements.COUNTER_EVENTS[kind] ~= nil or IGNORED[kind] == true })
				.toEqual({ kind, true })
		end
		-- every new kind of S151 is fired somewhere
		for _, kind in
			{
				"worldboss",
				"bloodmoon",
				"pvpkill",
				"craft",
				"dismantle",
				"reroll",
				"brew",
				"trade",
				"mail",
				"visit",
				"quest",
				"dodge",
				"social",
				"cosmetic",
			}
		do
			T.expect({ kind, seen[kind] == true }).toEqual({ kind, true })
		end
	end)

	T.it("no S151 kind is a quest objective type (QuestService ignores them)", function()
		local types: { [string]: boolean } = {}
		for _, list in { Quests.Main.list, Quests.Side.list, Quests.Boss.list, Quests.Contracts.list } :: { any } do
			for _, quest in list do
				for _, objective in quest.objectives do
					types[objective.type] = true
				end
			end
		end
		for kind in Achievements.COUNTER_EVENTS do
			local old = kind == "kill" or kind == "boss" or kind == "event" or kind == "duel" or kind == "upgrade"
			local tracked = kind == "gather" or kind == "fish" or kind == "level"
			if not old and not tracked then
				T.expect({ kind, types[kind] }).toEqual({ kind, nil })
			end
		end
	end)
end)

T.describe("Old progress (S151)", function()
	local function veteran(): (any, any)
		local account, character = fresh()
		character.level = 100
		character.quests.mainDone = Quests.Main.indexOf.vaelgrath
		character.pvp = { kills = 12, deaths = 0, duelsWon = 3, duelsLost = 0 }
		character.visitedMaps = { city = true, meadows = true, meadows_cave = true, dungeon_meadows = true }
		account.social.friends = { ["1"] = { name = "A", since = 0 }, ["2"] = { name = "B", since = 0 } }
		account.worldBoss = { last = "20261018-02" }
		account.cosmetics.owned =
			{ frame_bloodmoon = true, frame_bronze = true, aura_vip_hearth = true, aura_valor = true }
		return account, character
	end

	T.it("a veteran gets level, story, the four bosses and the rest the save proves", function()
		local account, character = veteran()
		local st = Achievements.state(account, character)
		local ids = Achievements.applyAll(st, Achievements.backfill(account, character))
		T.expect(st.chr.c.level).toBe(100)
		T.expect(st.chr.c.mainDone).toBe(Quests.Main.indexOf.vaelgrath)
		T.expect(st.chr.c.pvpKills).toBe(12)
		T.expect(st.acc.s.bosses).toEqual({ grimrok = true, morvane = true, azgor = true, vaelgrath = true })
		T.expect(st.acc.c.bossKills).toBe(4)
		T.expect(st.acc.c.worldBoss).toBe(1)
		T.expect(st.acc.c.friends).toBe(2)
		T.expect(st.acc.c.earnedCosmetics).toBe(1)
		T.expect(st.chr.s.maps).toEqual({ city = true, meadows = true, meadows_cave = true })
		T.expect(st.chr.s.caves).toEqual({ meadows_cave = true })
		for _, id in { "level100", "story4", "bossAll", "boss_vaelgrath", "pvp1", "worldBoss1", "friends1" } do
			T.expect({ id, contains(ids, id) }).toEqual({ id, true })
		end
		T.expect(contains(ids, "story5")).toBe(false)
		T.expect(contains(ids, "slayer1")).toBe(false) -- kills count from S151 on
	end)

	T.it("is idempotent: twice is once", function()
		local account, character = veteran()
		local st = Achievements.state(account, character)
		Achievements.applyAll(st, Achievements.backfill(account, character))
		local first = table.clone(st.chr.c)
		local firstAcc = table.clone(st.acc.c)
		Achievements.applyAll(st, Achievements.backfill(account, character))
		T.expect(st.chr.c).toEqual(first)
		T.expect(st.acc.c).toEqual(firstAcc)
		-- counted since: a later event adds on top, the next catch-up keeps it
		Achievements.apply(st, "pvpKills", "add", 1, nil)
		Achievements.applyAll(st, Achievements.backfill(account, character))
		T.expect(st.chr.c.pvpKills).toBe(13)
	end)

	T.it("a new character gets nothing", function()
		local account, character, st = fresh()
		character.level = 1
		T.expect(Achievements.applyAll(st, Achievements.backfill(account, character))).toEqual({})
	end)

	T.it("the account counts every character, a character only itself", function()
		local account, character = fresh()
		local other: any = AccountSchema.characterTemplate()
		other.id = "c2"
		other.level = 60
		other.quests.mainDone = Quests.Main.indexOf.grimrok
		other.guildId = "g1"
		account.characters["2"] = other
		local st = Achievements.state(account, character)
		Achievements.applyAll(st, Achievements.backfill(account, character))
		T.expect(st.acc.s.bosses).toEqual({ grimrok = true })
		T.expect(st.acc.c.guild).toBe(1)
		T.expect(st.chr.c.level).toBe(1)
	end)
end)

T.describe("Save (S151)", function()
	T.it("the templates carry ach, old saves get it from reconcile without a migration", function()
		T.expect(AccountSchema.accountTemplate().ach).toEqual({ c = {}, s = {}, done = {}, paid = {} })
		-- S151b: the character branch carries the tracked ids too
		-- S151c: and the bestiary's kills and drops seen
		T.expect(AccountSchema.characterTemplate().ach)
			.toEqual({ c = {}, s = {}, done = {}, track = {}, b = {}, bd = {} })
		T.expect(AccountSchema.accountTemplate().settings.achToasts).toBe(true)
		local old: any = AccountSchema.accountTemplate()
		old.ach = nil
		old.settings.achToasts = nil
		old.characters["1"] = AccountSchema.characterTemplate()
		old.characters["1"].ach = nil
		T.expect(AccountSchema.migrate(old)).toEqual({})
		T.expect(old.schema).toBe(AccountSchema.CURRENT)
		T.expect(old.ach).toEqual({ c = {}, s = {}, done = {}, paid = {} })
		-- S151b: track, S151c: b / bd
		T.expect(old.characters["1"].ach).toEqual({ c = {}, s = {}, done = {}, track = {}, b = {}, bd = {} })
		T.expect(old.settings.achToasts).toBe(true)
		local kept: any = AccountSchema.accountTemplate()
		kept.ach = { c = { trades = 4 }, s = {}, done = { trade1 = 9 }, paid = {} }
		AccountSchema.migrate(kept)
		T.expect(kept.ach.c.trades).toBe(4)
		T.expect(kept.ach.done.trade1).toBe(9)
	end)
end)

-- S151b ------------------------------------------------------------------------------------------------------------------

local function done(st: Achievements.State, id: string, at: number)
	Achievements.markDone(st, AchData.get(id) :: any, at)
end

local function ids(rows: { AchievementView.Row }): { string }
	local out: { string } = {}
	for _, row in rows do
		table.insert(out, row.id)
	end
	return out
end

T.describe("Tracking (S151b)", function()
	T.it("canTrack gives every reason and the limit", function()
		local _, _, st = fresh()
		T.expect({ Achievements.canTrack(st, "nope") }).toEqual({ false, "ach.error.unknown" })
		done(st, "slayer1", 10)
		T.expect({ Achievements.canTrack(st, "slayer1") }).toEqual({ false, "ach.error.done" })
		T.expect({ Achievements.canTrack(st, "slayer2") }).toEqual({ true })
		T.expect(Config.Achievements.trackMax).toBe(3)
		for _, id in { "slayer2", "elite1", "dodge1" } do
			T.expect((Achievements.setTracked(st, id, true))).toBe(true)
		end
		T.expect(Achievements.tracked(st)).toEqual({ "slayer2", "elite1", "dodge1" })
		T.expect({ Achievements.canTrack(st, "pvp1") }).toEqual({ false, "ach.error.full" })
		-- an id already tracked is fine, twice changes nothing
		T.expect({ Achievements.setTracked(st, "elite1", true) }).toEqual({ true, nil, false })
		T.expect({ Achievements.setTracked(st, "pvp1", true) }).toEqual({ false, "ach.error.full", false })
		T.expect({ Achievements.setTracked(st, "elite1", false) }).toEqual({ true, nil, true })
		T.expect({ Achievements.setTracked(st, "elite1", false) }).toEqual({ true, nil, false })
		T.expect((Achievements.setTracked(st, "pvp1", true))).toBe(true)
		T.expect(Achievements.tracked(st)).toEqual({ "slayer2", "dodge1", "pvp1" })
	end)

	T.it("a secret achievement cannot be tracked before it is done", function()
		local _, _, st = fresh()
		local def = AchData.get("mail1") :: any
		local was = def.secret
		def.secret = true
		local ok, err = Achievements.canTrack(st, "mail1")
		def.secret = was
		T.expect({ ok, err }).toEqual({ false, "ach.error.secret" })
	end)

	T.it("done and unknown ids leave the tracker (also an account one done by another character)", function()
		local account, character, st = fresh()
		Achievements.setTracked(st, "slayer1", true)
		Achievements.setTracked(st, "trade1", true)
		Achievements.setTracked(st, "mail1", true)
		-- the server stops tracking in grant
		done(st, "slayer1", 5)
		T.expect((select(3, Achievements.setTracked(st, "slayer1", false)))).toBe(true)
		-- trade1 (account) earned elsewhere, a removed id in an old save: gone on the next load
		account.ach.done.trade1 = 7
		table.insert(character.ach.track, "removedAchievement")
		table.insert(character.ach.track, 42)
		local again = Achievements.state(account, character)
		T.expect(Achievements.tracked(again)).toEqual({ "mail1" })
	end)

	T.it("the save repairs the tracked list (strings, no duplicates, at most trackMax)", function()
		local account, character = fresh()
		character.ach.track = { "slayer1", "slayer1", "elite1", "dodge1", "pvp1", true }
		local st = Achievements.state(account, character)
		T.expect(Achievements.tracked(st)).toEqual({ "slayer1", "elite1", "dodge1" })
		character.ach.track = "garbage"
		T.expect(Achievements.tracked(Achievements.state(account, character))).toEqual({})
	end)
end)

T.describe("AchievementView (S151b)", function()
	T.it("summary: points and counts of the account, the character and both, per category", function()
		local _, _, st = fresh()
		done(st, "slayer1", 1) -- character, 5
		done(st, "trade1", 2) -- account, 10
		local all = AchievementView.summary(st, "all")
		T.expect(all.points).toBe(15)
		T.expect(all.done).toBe(2)
		T.expect(all.total).toBe(#AchData.list)
		local max = 0
		for _, def in AchData.list do
			max += def.points
		end
		-- S151c: the bestiary's points belong to the character
		T.expect(all.pointsMax).toBe(max + require("../src/shared/Logic/Bestiary").pointsMax())
		T.expect(all.byCat.combat.done).toBe(1)
		T.expect(all.byCat.social.done).toBe(1)
		T.expect(all.byCat.combat.total).toBe(#AchData.forCategory("combat"))
		local acc = AchievementView.summary(st, "account")
		local chr = AchievementView.summary(st, "character")
		T.expect({ acc.points, chr.points }).toEqual({ 10, 5 })
		T.expect(acc.total + chr.total).toBe(all.total)
		T.expect(acc.pointsMax + chr.pointsMax).toBe(all.pointsMax)
	end)

	T.it("rows: a series folds to its current step with the done steps and the next one", function()
		local _, _, st = fresh()
		local list = ids(AchievementView.rows(st, "combat", "all", "all"))
		T.expect(table.find(list, "slayer1") ~= nil).toBe(true)
		T.expect(table.find(list, "slayer2")).toBeNil()
		Achievements.apply(st, "kills", "add", 1500, nil)
		done(st, "slayer1", 10)
		done(st, "slayer2", 20)
		local folded = false
		for _, r in AchievementView.rows(st, "combat", "all", "all") do
			if r.id == "slayer3" then
				folded = true
			end
			T.expect(r.id ~= "slayer1" and r.id ~= "slayer2").toBe(true)
		end
		T.expect(folded).toBe(true)
		local row = AchievementView.detail(st, "slayer3") :: AchievementView.Row
		T.expect(row.next).toBe("slayer4")
		T.expect(#row.steps).toBe(5)
		T.expect({ row.steps[1].done, row.steps[2].done, row.steps[3].done }).toEqual({ true, true, false })
		T.expect({ row.value, row.goal }).toEqual({ 1500, 10000 })
		T.expect(row.pct).toBe(0.15)
		T.expect(row.scope).toBe("character")
		-- the last step done: the series shows it done, without a next one
		for _, id in { "slayer3", "slayer4", "slayer5" } do
			done(st, id, 30)
		end
		local last = AchievementView.detail(st, "slayer5") :: AchievementView.Row
		T.expect({ last.done, last.next }).toEqual({ true, nil })
		T.expect(table.find(ids(AchievementView.rows(st, "combat", "all", "all")), "slayer5") ~= nil).toBe(true)
	end)

	T.it("rows: filters, range and order (in progress closest first, then not started, then newest done)", function()
		local _, _, st = fresh()
		Achievements.apply(st, "eliteKills", "add", 40, nil) -- elite1 80 %
		Achievements.apply(st, "dodged", "add", 5, nil) -- dodge1 20 %
		Achievements.apply(st, "kills", "add", 150, nil)
		done(st, "slayer1", 100) -- slayer2 15 %
		done(st, "duel1", 50)
		done(st, "arena1", 60)
		local list = ids(AchievementView.rows(st, "combat", "all", "all"))
		T.expect({ list[1], list[2], list[3] }).toEqual({ "elite1", "dodge1", "slayer2" })
		-- earned last, newest first: arena1 (60) before duel1 (50); their series go on (duel2, arena2 not started)
		local earned = ids(AchievementView.rows(st, "combat", "done", "all"))
		T.expect(earned).toEqual({ "slayer1", "arena1", "duel1" })
		-- open: nothing done
		for _, row in AchievementView.rows(st, "combat", "open", "all") do
			T.expect(row.done).toBe(false)
		end
		-- every series of the category once, whatever the filter "all"
		T.expect(table.find(list, "duel2") ~= nil and table.find(list, "duel1") == nil).toBe(true)
		-- range: no account achievement in combat
		T.expect(#AchievementView.rows(st, "combat", "all", "account")).toBe(0)
		for _, row in AchievementView.rows(st, nil, "all", "account") do
			T.expect(row.scope).toBe("account")
		end
		-- a completed series sits with the earned ones, newest first
		for _, id in { "elite2", "elite3" } do
			done(st, id, 200)
		end
		done(st, "elite1", 199)
		local all = ids(AchievementView.rows(st, "combat", "all", "all"))
		T.expect(all[#all]).toBe("elite3")
		T.expect((AchievementView.detail(st, "elite3") :: AchievementView.Row).done).toBe(true)
		-- the tracked flag
		Achievements.setTracked(st, "dodge1", true)
		local tracked = AchievementView.detail(st, "dodge1") :: AchievementView.Row
		T.expect(tracked.tracked).toBe(true)
		T.expect(ids(AchievementView.trackedRows(st))).toEqual({ "dodge1" })
	end)

	T.it("rows: a secret one not done is ??? without a description, goal or reward", function()
		local _, _, st = fresh()
		local def = AchData.get("fullParty1") :: any
		local was = def.secret
		def.secret = true
		local hidden = AchievementView.detail(st, "fullParty1") :: AchievementView.Row
		done(st, "fullParty1", 3)
		local shown = AchievementView.detail(st, "fullParty1") :: AchievementView.Row
		def.secret = was
		T.expect(hidden.nameKey).toBe(AchievementView.SECRET_NAME)
		T.expect(hidden.descKey).toBeNil()
		T.expect({ hidden.goal, #hidden.reward, hidden.hidden }).toEqual({ 0, 0, true })
		T.expect(shown.nameKey).toBe("ach.fullParty1.name")
		T.expect(shown.hidden).toBe(false)
		T.expect(type((pl :: any)[AchievementView.SECRET_NAME])).toBe("string")
	end)

	T.it("rewardLines: title, cosmetic, shards, gold and shards already paid on the account", function()
		local _, _, st = fresh()
		local title = AchievementView.rewardLines(AchData.get("slayer4") :: any, st)
		T.expect(title[1].kind).toBe("title")
		T.expect(title[1].nameKey).toBe((TitleData.get("ach_butcher") :: any).nameKey)
		local cosmetic = AchievementView.rewardLines(AchData.get("elite3") :: any, st)
		T.expect({ cosmetic[1].kind, cosmetic[1].id }).toEqual({ "cosmetic", "frame_elitehunter" })
		local gold = AchievementView.rewardLines(AchData.get("level10") :: any, st)
		T.expect({ gold[1].kind, gold[1].n }).toEqual({ "gold", 100 })
		local shards = AchievementView.rewardLines(AchData.get("slayer3") :: any, st)
		T.expect({ shards[1].kind, shards[1].n }).toEqual({ "shards", 10 })
		-- another character of the account was paid: this one reads "already received"
		st.acc.paid = { slayer3 = true }
		local paid = AchievementView.rewardLines(AchData.get("slayer3") :: any, st)
		T.expect(paid[1].kind).toBe("shardsPaid")
		T.expect(paid[1].n).toBeNil()
		-- S151b: done on this character, but the shards went to another one: still "already received"
		done(st, "slayer3", 4)
		local second = AchievementView.rewardLines(AchData.get("slayer3") :: any, st)
		T.expect(second[1].kind).toBe("shardsPaid")
		-- paid to this very character: the amount stays
		st.chr.paidHere = { slayer3 = true }
		local own = AchievementView.rewardLines(AchData.get("slayer3") :: any, st)
		T.expect({ own[1].kind, own[1].n }).toEqual({ "shards", 10 })
		-- an account achievement: paid and done on the account is the amount on every character
		st.acc.paid.boss_vaelgrath = true
		done(st, "boss_vaelgrath", 5)
		local acc = AchievementView.rewardLines(AchData.get("boss_vaelgrath") :: any, st)
		T.expect({ acc[1].kind, acc[1].n }).toEqual({ "shards", 10 })
		T.expect(#AchievementView.rewardLines(AchData.get("slayer1") :: any, st)).toBe(0)
		for _, line in { title[1], cosmetic[1], gold[1], shards[1], paid[1] } do
			T.expect(type((pl :: any)[line.key])).toBe("string")
			T.expect(type((en :: any)[line.key])).toBe("string")
		end
	end)

	T.it("recent and read: the latest of both branches; read never repairs the save", function()
		local account, character, st = fresh()
		done(st, "slayer1", 10)
		done(st, "trade1", 30)
		done(st, "mail1", 20)
		done(st, "elite1", 5)
		T.expect(AchievementView.recent(st, 3)).toEqual({
			{ id = "trade1", at = 30 },
			{ id = "mail1", at = 20 },
			{ id = "slayer1", at = 10 },
		})
		character.ach.track = { "dodge1", "dodge1" }
		local view = AchievementView.read(account, character)
		T.expect(Achievements.tracked(view)).toEqual({ "dodge1" })
		T.expect(character.ach.track).toEqual({ "dodge1", "dodge1" })
		T.expect(AchievementView.summary(view, "all").done).toBe(4)
		T.expect(AchievementView.summary(AchievementView.read(nil, nil), "all").done).toBe(0)
	end)

	T.it("every series is a chain inside one category and one counter", function()
		for _, def in AchData.list do
			local chain = AchievementView.chainOf(def)
			T.expect(table.find(chain, def) ~= nil).toBe(true)
			for _, step in chain do
				T.expect({ step.id, step.cat, step.counter }).toEqual({ step.id, def.cat, def.counter })
			end
		end
	end)

	T.it("the window, tracker and profile texts exist in both languages", function()
		for _, key in
			{
				"window.achievements.title",
				"hud.menu.achievements",
				"ach.reward.shardsPaid",
				"ach.error.unknown",
				"ach.error.done",
				"ach.error.secret",
				"ach.error.full",
				"ach.toast.view",
				"ach.tracker",
				"profile.ach.points",
			}
		do
			T.expect({ key, type((pl :: any)[key]) }).toEqual({ key, "string" })
			T.expect({ key, type((en :: any)[key]) }).toEqual({ key, "string" })
		end
	end)
end)

return nil
