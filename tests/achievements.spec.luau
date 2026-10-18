--!strict
-- S151 (docs/DESIGN.md §20b): achievements: the data, the shard budget, counting, rewards once per account, the events
-- of QuestEvents, the catch-up of old progress and the save without a migration.
local fs = require("@lune/fs")

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local AchData = require("../src/shared/Data/Achievements")
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
		T.expect(AccountSchema.characterTemplate().ach).toEqual({ c = {}, s = {}, done = {} })
		T.expect(AccountSchema.accountTemplate().settings.achToasts).toBe(true)
		local old: any = AccountSchema.accountTemplate()
		old.ach = nil
		old.settings.achToasts = nil
		old.characters["1"] = AccountSchema.characterTemplate()
		old.characters["1"].ach = nil
		T.expect(AccountSchema.migrate(old)).toEqual({})
		T.expect(old.schema).toBe(AccountSchema.CURRENT)
		T.expect(old.ach).toEqual({ c = {}, s = {}, done = {}, paid = {} })
		T.expect(old.characters["1"].ach).toEqual({ c = {}, s = {}, done = {} })
		T.expect(old.settings.achToasts).toBe(true)
		local kept: any = AccountSchema.accountTemplate()
		kept.ach = { c = { trades = 4 }, s = {}, done = { trade1 = 9 }, paid = {} }
		AccountSchema.migrate(kept)
		T.expect(kept.ach.c.trades).toBe(4)
		T.expect(kept.ach.done.trade1).toBe(9)
	end)
end)

return nil
