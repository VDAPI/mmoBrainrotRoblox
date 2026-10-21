--!strict
-- S159g: guild levels, rank rights, the guild bank and weekly goals (Logic/Guild, Logic/GuildBank,
-- Logic/GuildProgress, Data/GuildProgress, Data/GuildBanners).
local Guild = require("../src/shared/Logic/Guild")
local GuildBank = require("../src/shared/Logic/GuildBank")
local GuildBanners = require("../src/shared/Data/GuildBanners")
local GuildProgress = require("../src/shared/Logic/GuildProgress")
local GuildProgressData = require("../src/shared/Data/GuildProgress")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

local Rules = GuildProgressData.Rules

local function member(userId: number, name: string): Guild.Member
	return {
		userId = userId,
		charId = `c{userId}`,
		name = name,
		class = "Warrior",
		level = 30,
		rank = "member",
		joinedAt = 0,
		contributed = 0,
	}
end

local LEADER = Guild.memberKey(1, "c1")
local OFFICER = Guild.memberKey(2, "c2")
local VETERAN = Guild.memberKey(3, "c3")
local MEMBER = Guild.memberKey(4, "c4")

local function sample(): Guild.GuildData
	local g = Guild.create({ id = "g1", name = "Order", tag = "ORD", founder = member(1, "Lead"), now = 100 })
	assert(Guild.join(g, member(2, "Off"), 200))
	assert(Guild.join(g, member(3, "Vet"), 300))
	assert(Guild.join(g, member(4, "Mem"), 400))
	assert(Guild.setRank(g, LEADER, OFFICER, "officer"))
	assert(Guild.setRank(g, LEADER, VETERAN, "veteran"))
	return g
end

local function item(uid: string, bound: boolean?): any
	return { uid = uid, id = "potion_hp_1", rarity = 1, ilvl = 1, bonuses = {}, up = 0, bound = bound == true, n = 3 }
end

T.describe("Guild level (S159g)", function()
	T.it("levels from guild EXP, top at MAX_LEVEL", function()
		T.expect({ Guild.levelOf(0) }).toEqual({ 1, 0, GuildProgressData.LEVEL_EXP[1] })
		local first = GuildProgressData.LEVEL_EXP[1]
		T.expect({ Guild.levelOf(first) }).toEqual({ 2, 0, GuildProgressData.LEVEL_EXP[2] })
		T.expect((Guild.levelOf(first + 5))).toBe(2)
		local level, _, need = Guild.levelOf(1e12)
		T.expect(level).toBe(GuildProgressData.MAX_LEVEL)
		T.expect(need).toBe(nil)
		T.expect(Guild.level(nil)).toBe(1)
	end)

	T.it("level costs grow and skill unlocks are ordered", function()
		for n = 2, #GuildProgressData.LEVEL_EXP do
			T.expect(GuildProgressData.LEVEL_EXP[n] > GuildProgressData.LEVEL_EXP[n - 1]).toBe(true)
		end
		T.expect(GuildProgressData.SKILL_UNLOCK[1]).toBe(1)
		for n = 2, #GuildProgressData.SKILL_UNLOCK do
			T.expect(GuildProgressData.SKILL_UNLOCK[n] > GuildProgressData.SKILL_UNLOCK[n - 1]).toBe(true)
			T.expect(GuildProgressData.SKILL_UNLOCK[n] <= GuildProgressData.MAX_LEVEL).toBe(true)
		end
	end)

	T.it("vault grows with the level", function()
		local g = sample()
		T.expect(GuildBank.vaultSize(g)).toBe(Rules.vaultBase)
		g.exp = 1e12
		T.expect(GuildBank.vaultSize(g)).toBe(Rules.vaultBase + Rules.vaultPerLevel * (GuildProgressData.MAX_LEVEL - 1))
	end)
end)

T.describe("Guild ranks and rights (S159g)", function()
	T.it("defaults: veterans invite and take items, members only put items in", function()
		T.expect(Guild.can("veteran", "invite")).toBe(true)
		T.expect(Guild.can("veteran", "kick")).toBe(false)
		T.expect(Guild.can("member", "putItem")).toBe(true)
		T.expect(Guild.can("member", "takeItem")).toBe(false)
		T.expect(Guild.can("officer", "withdrawGold")).toBe(true)
		T.expect(Guild.can("leader", "withdrawGold")).toBe(true)
		T.expect(Guild.can("member", "deposit")).toBe(true)
		T.expect(Guild.can("ghost", "deposit")).toBe(false)
		T.expect(Guild.limit(nil, "leader", "gold")).toBe(math.huge)
	end)

	T.it("the leader edits rights and limits of the lower ranks only", function()
		local g = sample()
		T.expect({ Guild.setPerm(g, OFFICER, "member", "invite", true) }).toEqual({ false, "guild.error.permission" })
		T.expect({ Guild.setPerm(g, LEADER, "leader", "invite", false) }).toEqual({ false, "error.badRequest" })
		T.expect({ Guild.setPerm(g, LEADER, "member", "disband", true) }).toEqual({ false, "error.badRequest" })
		T.expect((Guild.setPerm(g, LEADER, "member", "invite", true))).toBe(true)
		T.expect(Guild.can("member", "invite", g)).toBe(true)
		T.expect(Guild.can("member", "invite")).toBe(false) -- defaults untouched
		T.expect((Guild.setLimit(g, LEADER, "veteran", "items", 7))).toBe(true)
		T.expect(Guild.limit(g, "veteran", "items")).toBe(7)
		T.expect({ Guild.setLimit(g, LEADER, "veteran", "gold", -1) }).toEqual({ false, "guild.error.amount" })
		T.expect({ Guild.setLimit(g, LEADER, "veteran", "gold", Rules.goldLimitMax + 1) })
			.toEqual({ false, "guild.error.amount" })
	end)

	T.it("ranks change only below the actor", function()
		local g = sample()
		-- officers cannot by default; allowed, they move members and veterans but never to officer
		T.expect({ Guild.setRank(g, OFFICER, MEMBER, "veteran") }).toEqual({ false, "guild.error.permission" })
		assert(Guild.setPerm(g, LEADER, "officer", "promote", true))
		T.expect((Guild.setRank(g, OFFICER, MEMBER, "veteran"))).toBe(true)
		T.expect({ Guild.setRank(g, OFFICER, MEMBER, "officer") }).toEqual({ false, "guild.error.rank" })
		T.expect({ Guild.setRank(g, OFFICER, LEADER, "member") }).toEqual({ false, "guild.error.rank" })
		T.expect({ Guild.setRank(g, LEADER, MEMBER, "leader") }).toEqual({ false, "error.badRequest" })
		T.expect(Guild.outranks("veteran", "member")).toBe(true)
		T.expect(Guild.outranks("veteran", "officer")).toBe(false)
	end)

	T.it("membership changes write the log, trimmed to logMax", function()
		local g = sample()
		local kinds = {}
		for _, entry in g.log or {} do
			table.insert(kinds, entry.k)
		end
		T.expect(kinds).toEqual({ "join", "join", "join", "rank", "rank" })
		for i = 1, Rules.logMax + 5 do
			assert(Guild.deposit(g, MEMBER, i))
		end
		T.expect(#(g.log :: any)).toBe(Rules.logMax)
		T.expect((g.log :: any)[Rules.logMax].a).toBe(Rules.logMax + 5)
	end)

	T.it("banner looks open with the guild level; only the leader picks", function()
		local g = sample()
		T.expect({ Guild.banner(g) }).toEqual({ GuildBanners.DEFAULT_EMBLEM, GuildBanners.DEFAULT_COLOUR })
		T.expect({ Guild.setBanner(g, OFFICER, "swords", "azure") }).toEqual({ false, "guild.error.permission" })
		T.expect((Guild.setBanner(g, LEADER, "swords", "azure"))).toBe(true)
		T.expect({ Guild.banner(g) }).toEqual({ "swords", "azure" })
		T.expect({ Guild.setBanner(g, LEADER, "crown", "azure") }).toEqual({ false, "guild.error.guildLevel" })
		T.expect({ Guild.setBanner(g, LEADER, "nope", "azure") }).toEqual({ false, "error.badRequest" })
		g.exp = 1e12
		T.expect((Guild.setBanner(g, LEADER, "crown", "ivory"))).toBe(true)
		T.expect(Guild.banner({ banner = { e = "bad", c = "gold" } })).toBe(GuildBanners.DEFAULT_EMBLEM)
	end)

	T.it("every emblem and colour opens at a reachable level, colours are localized", function()
		local firstEmblems, firstColours = 0, 0
		for _, e in GuildBanners.EMBLEMS do
			T.expect(e.level >= 1 and e.level <= GuildProgressData.MAX_LEVEL).toBe(true)
			firstEmblems += if e.level == 1 then 1 else 0
		end
		for _, c in GuildBanners.COLOURS do
			T.expect(c.level >= 1 and c.level <= GuildProgressData.MAX_LEVEL).toBe(true)
			T.expect(string.match(c.hex, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
			T.expect(pl[c.nameKey] ~= nil and en[c.nameKey] ~= nil).toBe(true)
			firstColours += if c.level == 1 then 1 else 0
		end
		T.expect(firstEmblems >= 3 and firstColours >= 3).toBe(true)
	end)
end)

T.describe("Guild bank (S159g)", function()
	T.it("gold out: right, treasury and the daily limit", function()
		local g = sample()
		g.treasury = 200000
		T.expect({ GuildBank.withdrawGold(g, MEMBER, 10, 0, 5) }).toEqual({ false, "guild.error.permission" })
		T.expect({ GuildBank.withdrawGold(g, OFFICER, 1.5, 0, 5) }).toEqual({ false, "guild.error.amount" })
		local limit = Guild.limit(g, "officer", "gold")
		T.expect((GuildBank.withdrawGold(g, OFFICER, limit, 0, 5))).toBe(true)
		T.expect(g.treasury).toBe(200000 - limit)
		T.expect({ GuildBank.withdrawGold(g, OFFICER, 1, 0, 5) }).toEqual({ false, "guild.error.dailyLimit" })
		T.expect((GuildBank.withdrawGold(g, OFFICER, 1, 0, 6))).toBe(true) -- next day
		T.expect({ GuildBank.withdrawGold(g, LEADER, 1e8, 0, 6) }).toEqual({ false, "guild.error.treasury" })
		T.expect((GuildBank.withdrawGold(g, LEADER, g.treasury, 0, 6))).toBe(true)
		T.expect(g.treasury).toBe(0)
	end)

	T.it("items in and out, bound items never, full vault refused", function()
		local g = sample()
		T.expect({ GuildBank.putItem(g, MEMBER, item("a", true), nil, 0) }).toEqual({ false, "trade.error.bound" })
		local locked = item("a")
		locked.locked = true
		T.expect((GuildBank.putItem(g, MEMBER, locked, 3, 0))).toBe(true)
		T.expect((g.vault :: any)["3"].uid).toBe("a")
		T.expect((g.vault :: any)["3"].locked).toBe(nil)
		T.expect(locked.locked).toBe(true) -- the caller's copy is untouched
		-- members cannot take by default, veterans up to their limit
		T.expect({ GuildBank.takeItem(g, MEMBER, 3, "a", 0, 1) }).toEqual({ false, "guild.error.permission", nil })
		T.expect({ GuildBank.takeItem(g, VETERAN, 3, "zzz", 0, 1) }).toEqual({ false, "error.stale", nil })
		local ok, _, taken = GuildBank.takeItem(g, VETERAN, 3, "a", 0, 1)
		T.expect(ok).toBe(true)
		T.expect(taken.uid).toBe("a")
		T.expect(GuildBank.count(g)).toBe(0)
		for i = 1, GuildBank.vaultSize(g) do
			assert(GuildBank.putItem(g, MEMBER, item(`i{i}`), nil, 0))
		end
		T.expect({ GuildBank.putItem(g, MEMBER, item("late"), nil, 0) }).toEqual({ false, "guild.error.vaultFull" })
		local veteranLimit = Guild.limit(g, "veteran", "items")
		for i = 1, veteranLimit - 1 do
			assert(GuildBank.takeItem(g, VETERAN, i, `i{i}`, 0, 1))
		end
		T.expect({ GuildBank.takeItem(g, VETERAN, veteranLimit, `i{veteranLimit}`, 0, 1) })
			.toEqual({ false, "guild.error.dailyLimit", nil })
		local gold, items = GuildBank.left(g, g.members[VETERAN], 1)
		T.expect({ gold, items }).toEqual({ 0, 0 })
	end)

	T.it("moves inside the vault swap slots", function()
		local g = sample()
		assert(GuildBank.putItem(g, MEMBER, item("a"), 1, 0))
		assert(GuildBank.putItem(g, MEMBER, item("b"), 2, 0))
		T.expect((GuildBank.move(g, MEMBER, 1, 2))).toBe(true)
		T.expect((g.vault :: any)["1"].uid).toBe("b")
		T.expect({ GuildBank.move(g, MEMBER, 5, 1) }).toEqual({ false, "error.stale" })
		T.expect({ GuildBank.move(g, MEMBER, 1, 999) }).toEqual({ false, "error.stale" })
	end)
end)

T.describe("Guild EXP and weekly goals (S159g)", function()
	T.it("activities: grey monsters and bosses as kills give nothing", function()
		T.expect({ GuildProgress.activity("kill", { level = 30, variant = "normal" }, 30) }).toEqual({ "kill", 1 })
		T.expect({ GuildProgress.activity("kill", { level = 19, variant = "normal" }, 30) }).toEqual({ nil, 0 })
		T.expect({ GuildProgress.activity("kill", { level = 30, variant = "elite2" }, 30) }).toEqual({ "elite2", 1 })
		T.expect({ GuildProgress.activity("kill", { level = 30, boss = true }, 30) }).toEqual({ nil, 0 })
		T.expect({ GuildProgress.activity("quest", { kind = "contract", n = 3 }, 30) }).toEqual({ "contract", 3 })
		T.expect({ GuildProgress.activity("quest", { kind = "main" }, 30) }).toEqual({ "quest", 1 })
		T.expect({ GuildProgress.activity("event", { success = false }, 30) }).toEqual({ nil, 1 })
		T.expect({ GuildProgress.activity("dodge", {}, 30) }).toEqual({ nil, 0 })
	end)

	T.it("every activity has points and every goal counts known activities", function()
		for act in GuildProgressData.POINTS do
			T.expect(pl[`guild.source.{act}`] ~= nil and en[`guild.source.{act}`] ~= nil).toBe(true)
		end
		local groups = {}
		for _, def in GuildProgressData.GOALS do
			groups[def.group] = true
			for act in def.counts do
				T.expect(GuildProgressData.POINTS[act] ~= nil).toBe(true)
			end
			T.expect(pl[def.nameKey] ~= nil and en[def.descKey] ~= nil).toBe(true)
		end
		for _, group in GuildProgressData.GROUPS do
			T.expect(groups[group]).toBe(true)
		end
	end)

	T.it("the daily cap holds per UTC day", function()
		local granted, work = GuildProgress.earn(nil, 10, Rules.dailyCap - 5)
		T.expect(granted).toBe(Rules.dailyCap - 5)
		granted, work = GuildProgress.earn(work, 10, 50)
		T.expect(granted).toBe(5)
		granted, work = GuildProgress.earn(work, 10, 50)
		T.expect(granted).toBe(0)
		granted, work = GuildProgress.earn(work, 11, 50)
		T.expect(granted).toBe(50)
		T.expect(work.today).toBe(50)
	end)

	T.it("goals: one per group, the same on every server, targets from the member count", function()
		local a = GuildProgress.goalsFor("g1", 100, 10)
		T.expect(a).toEqual(GuildProgress.goalsFor("g1", 100, 10))
		T.expect(#a).toBe(#GuildProgressData.GROUPS)
		for i, goal in a do
			local def = GuildProgressData.goalById[goal.id]
			T.expect(def.group).toBe(GuildProgressData.GROUPS[i])
			T.expect(goal.target >= def.min).toBe(true)
			T.expect(goal.target % def.step).toBe(0)
		end
		local small = GuildProgress.goalsFor("g1", 100, 1)
		for i, goal in small do
			T.expect(goal.target <= a[i].target).toBe(true)
		end
	end)

	T.it("apply adds EXP and progress, finishes goals, pays the treasury and starts the rally once", function()
		local g = sample()
		local week = 2900
		GuildProgress.ensureWeek(g, week)
		local goals = (g.week :: any).goals
		local acts = {}
		for _, goal in goals do
			local def = GuildProgressData.goalById[goal.id]
			local act = next(def.counts) :: string
			acts[act] = (acts[act] or 0) + math.ceil(goal.target / def.counts[act])
		end
		local notes = GuildProgress.apply(g, { [MEMBER] = { exp = 100, acts = { kill = 1 } } }, week, 0)
		T.expect(#notes.goals).toBe(0)
		T.expect(GuildProgress.contribution(g, MEMBER, week)).toBe(100)
		T.expect(g.exp).toBe(100)
		local treasury = g.treasury
		notes = GuildProgress.apply(g, {
			[OFFICER] = { exp = 10, acts = acts },
			["9:gone"] = { exp = 1e6, acts = {} }, -- left the guild: skipped
		}, week, 0)
		T.expect(#notes.goals).toBe(3)
		T.expect(notes.rally).toBe(true)
		T.expect(g.exp).toBe(110 + 3 * GuildProgressData.GOALS[1].exp)
		T.expect(g.treasury > treasury).toBe(true)
		T.expect(GuildProgress.rallyActive(g, week + 1)).toBe(true)
		T.expect(GuildProgress.rallyActive(g, week + 2)).toBe(false)
		T.expect(GuildProgress.rallyBonus(g, week)).toEqual({ expBonus = Rules.rallyExp, goldBonus = Rules.rallyGold })
		notes = GuildProgress.apply(g, { [OFFICER] = { exp = 0, acts = acts } }, week, 0)
		T.expect(#notes.goals).toBe(0)
		T.expect(notes.rally).toBe(false)
		-- a new week starts fresh goals and contributions
		GuildProgress.apply(g, {}, week + 1, 0)
		T.expect((g.week :: any).w).toBe(week + 1)
		T.expect(GuildProgress.contribution(g, MEMBER, week + 1)).toBe(0)
	end)

	T.it("claims need a goal done, enough guild EXP this week, and once per goal", function()
		local g = sample()
		local week = 2900
		GuildProgress.ensureWeek(g, week)
		T.expect({ GuildProgress.canClaim(g, MEMBER, 1, week, nil) }).toEqual({ false, "guild.error.goalNotDone" })
		local goal = (g.week :: any).goals[1]
		goal.done = true
		T.expect({ GuildProgress.canClaim(g, MEMBER, 1, week, nil) }).toEqual({ false, "guild.error.claimMin" })
		GuildProgress.apply(g, { [MEMBER] = { exp = Rules.claimMin, acts = {} } }, week, 0)
		T.expect({ GuildProgress.canClaim(g, MEMBER, 1, week, nil) }).toEqual({ true, nil })
		local work = GuildProgress.markClaimed(nil, week, goal.id)
		T.expect({ GuildProgress.canClaim(g, MEMBER, 1, week, work) }).toEqual({ false, "guild.error.claimed" })
		T.expect({ GuildProgress.canClaim(g, MEMBER, 1, week + 1, work) }).toEqual({ false, "guild.error.goalNotDone" })
	end)

	T.it("a failed write merges back into the next batch", function()
		local a: GuildProgress.Batch = { k = { exp = 5, acts = { kill = 2 } } }
		GuildProgress.merge(a, { k = { exp = 3, acts = { kill = 1, fish = 4 } }, j = { exp = 1, acts = {} } })
		T.expect(a).toEqual({ k = { exp = 8, acts = { kill = 3, fish = 4 } }, j = { exp = 1, acts = {} } })
	end)

	T.it("weekly shards stay small", function()
		T.expect(Rules.claimShards * #GuildProgressData.GROUPS <= 20).toBe(true)
	end)
end)

return nil
