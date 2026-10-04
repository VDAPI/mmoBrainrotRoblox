--!strict
local Guild = require("../src/shared/Logic/Guild")
local GuildSkills = require("../src/shared/Data/GuildSkills")
local ShopPrice = require("../src/shared/Logic/ShopPrice")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

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
local MEMBER = Guild.memberKey(3, "c3")

local function sample(): Guild.GuildData
	local g = Guild.create({ id = "g1", name = "Order", tag = "ORD", founder = member(1, "Lead"), now = 100 })
	assert(Guild.join(g, member(2, "Off"), 200))
	assert(Guild.join(g, member(3, "Mem"), 300))
	assert(Guild.setRank(g, LEADER, OFFICER, "officer"))
	return g
end

T.describe("Guild permissions", function()
	T.it("ranks have the right actions", function()
		T.expect(Guild.can("leader", "disband")).toBe(true)
		T.expect(Guild.can("officer", "invite")).toBe(true)
		T.expect(Guild.can("officer", "upgrade")).toBe(true)
		T.expect(Guild.can("officer", "promote")).toBe(false)
		T.expect(Guild.can("officer", "disband")).toBe(false)
		T.expect(Guild.can("member", "invite")).toBe(false)
		T.expect(Guild.can("member", "deposit")).toBe(true)
		T.expect(Guild.can(nil, "deposit")).toBe(false)
	end)
end)

T.describe("Guild names and tags", function()
	T.it("validates names", function()
		T.expect((Guild.validateName("Zakon Świtu"))).toBe(true)
		T.expect((Guild.validateName("Ab"))).toBe(false)
		T.expect((Guild.validateName(string.rep("a", 21)))).toBe(false)
		T.expect((Guild.validateName(" Lead"))).toBe(false)
		T.expect((Guild.validateName("Two  spaces"))).toBe(false)
		T.expect((Guild.validateName("Bad_Name"))).toBe(false)
		T.expect((Guild.validateName("123"))).toBe(false)
	end)

	T.it("validates tags", function()
		T.expect((Guild.validateTag("ORD"))).toBe(true)
		T.expect((Guild.validateTag("A1"))).toBe(true)
		T.expect((Guild.validateTag("ord"))).toBe(false)
		T.expect((Guild.validateTag("A"))).toBe(false)
		T.expect((Guild.validateTag("ABCDE"))).toBe(false)
	end)

	T.it("uniqueness keys ignore case", function()
		T.expect(Guild.nameKey("Zakon ŚWITU")).toBe(Guild.nameKey("zakon świtu"))
		T.expect(Guild.tagKey("ord")).toBe(Guild.tagKey("ORD"))
	end)
end)

T.describe("Guild skills", function()
	T.it("five skills with five increasing costs and localization", function()
		T.expect(#GuildSkills.list).toBe(5)
		for _, def in GuildSkills.list do
			T.expect(#def.costs).toBe(GuildSkills.MAX_LEVEL)
			for i = 2, #def.costs do
				T.expect(def.costs[i] > def.costs[i - 1]).toBe(true)
			end
			for _, lang in { en, pl } do
				T.expect(lang[def.nameKey] ~= nil and lang[def.descKey] ~= nil).toBe(true)
			end
		end
	end)

	T.it("member limit goes from 20 to 45", function()
		T.expect(Guild.memberLimit({})).toBe(20)
		T.expect(Guild.memberLimit({ expansion = 5 })).toBe(45)
		T.expect(Guild.memberLimit({ expansion = 9 })).toBe(45)
	end)

	T.it("bonuses follow DESIGN §19", function()
		T.expect(Guild.bonuses({ wisdom = 5, fortune = 2, healer = 1, luck = 3, expansion = 4 })).toEqual({
			expBonus = 10,
			goldBonus = 6,
			potionDiscount = 4,
			dropBonus = 3,
		})
	end)

	T.it("upgrade spends the treasury and needs permission", function()
		local g = sample()
		T.expect({ Guild.upgrade(g, OFFICER, "wisdom") }).toEqual({ false, "guild.error.treasury" })
		g.treasury = 1e7
		T.expect({ Guild.upgrade(g, MEMBER, "wisdom") }).toEqual({ false, "guild.error.permission" })
		T.expect((Guild.upgrade(g, OFFICER, "wisdom"))).toBe(true)
		T.expect(g.skills.wisdom).toBe(1)
		T.expect(g.treasury).toBe(1e7 - (GuildSkills.get("wisdom") :: any).costs[1])
		for _ = 2, 5 do
			assert(Guild.upgrade(g, LEADER, "wisdom"))
		end
		T.expect({ Guild.upgrade(g, LEADER, "wisdom") }).toEqual({ false, "guild.error.maxLevel" })
	end)
end)

T.describe("Guild membership", function()
	T.it("join respects the member limit", function()
		local g = sample()
		for i = 4, 20 do
			assert(Guild.join(g, member(i, `M{i}`), 0))
		end
		T.expect(Guild.memberCount(g)).toBe(20)
		T.expect({ Guild.join(g, member(99, "Late"), 0) }).toEqual({ false, "guild.error.full" })
		T.expect({ Guild.join(g, member(5, "Again"), 0) }).toEqual({ false, "guild.error.alreadyMember" })
	end)

	T.it("leader cannot leave without handing over", function()
		local g = sample()
		T.expect({ Guild.leave(g, LEADER) }).toEqual({ false, "guild.error.leaderLeave" })
		T.expect((Guild.leave(g, MEMBER))).toBe(true)
		T.expect(g.members[MEMBER]).toBe(nil)
	end)

	T.it("kicking needs a higher rank", function()
		local g = sample()
		T.expect({ Guild.kick(g, MEMBER, OFFICER) }).toEqual({ false, "guild.error.permission" })
		T.expect({ Guild.kick(g, OFFICER, LEADER) }).toEqual({ false, "guild.error.rank" })
		T.expect((Guild.kick(g, OFFICER, MEMBER))).toBe(true)
	end)

	T.it("transfer makes the old leader an officer", function()
		local g = sample()
		T.expect({ Guild.transfer(g, OFFICER, MEMBER) }).toEqual({ false, "guild.error.permission" })
		T.expect((Guild.transfer(g, LEADER, MEMBER))).toBe(true)
		T.expect(g.leaderCharId).toBe(MEMBER)
		T.expect(g.members[LEADER].rank).toBe("officer")
		T.expect(g.members[MEMBER].rank).toBe("leader")
	end)

	T.it("forceRemove promotes the best successor or reports empty", function()
		local g = sample()
		T.expect((Guild.forceRemove(g, LEADER))).toBe(true)
		T.expect(g.leaderCharId).toBe(OFFICER)
		local solo = Guild.create({ id = "g2", name = "Solo", tag = "SO", founder = member(7, "Solo"), now = 0 })
		T.expect({ Guild.forceRemove(solo, Guild.memberKey(7, "c7")) }).toEqual({ true, "empty" })
	end)

	T.it("deposit tracks contributions and rejects bad amounts", function()
		local g = sample()
		T.expect((Guild.deposit(g, MEMBER, 500))).toBe(true)
		T.expect(g.treasury).toBe(500)
		T.expect(g.members[MEMBER].contributed).toBe(500)
		T.expect({ Guild.deposit(g, MEMBER, 0) }).toEqual({ false, "guild.error.amount" })
		T.expect({ Guild.deposit(g, MEMBER, 1.5) }).toEqual({ false, "guild.error.amount" })
	end)

	T.it("disbanded guilds reject every change", function()
		local g = sample()
		T.expect({ Guild.disband(g, OFFICER) }).toEqual({ false, "guild.error.permission" })
		T.expect((Guild.disband(g, LEADER))).toBe(true)
		T.expect({ Guild.deposit(g, MEMBER, 5) }).toEqual({ false, "guild.error.gone" })
		T.expect({ Guild.join(g, member(9, "X"), 0) }).toEqual({ false, "guild.error.gone" })
	end)

	T.it("every change bumps the version", function()
		local g = sample()
		local before = g.version
		assert(Guild.setMotd(g, OFFICER, "Hello"))
		assert(Guild.setSetting(g, LEADER, "guildPvpProtection", false))
		T.expect(g.version).toBe(before + 2)
		T.expect({ Guild.setSetting(g, OFFICER, "guildPvpProtection", true) })
			.toEqual({ false, "guild.error.permission" })
		T.expect({ Guild.touchMember(g, MEMBER, "Mem", "Warrior", 30) }).toEqual({ false, "unchanged" })
	end)

	T.it("sorts members by rank, then level", function()
		local g = sample()
		g.members[MEMBER].level = 99
		T.expect(Guild.sortedKeys(g)).toEqual({ LEADER, OFFICER, MEMBER })
	end)
end)

T.describe("ShopPrice", function()
	T.it("discounts potions only", function()
		local potion = { item = "potion_hp_1" }
		local full = ShopPrice.unit(potion, 10, 0)
		T.expect(ShopPrice.unit(potion, 10, 20)).toBe(math.max(1, math.floor(full * 0.8 + 0.5)))
		local tool = { item = "pickaxe" }
		T.expect(ShopPrice.unit(tool, 10, 20)).toBe(ShopPrice.unit(tool, 10, 0))
		T.expect(ShopPrice.unit({ item = "scroll_oblivion", pricePerLevel = 500 }, 7, 20)).toBe(3500)
	end)
end)

return nil
