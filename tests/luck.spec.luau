--!strict
-- Group luck, Fortune on bosses and the class variety bonus (S60, ROZWOJ 6, 7.4): Logic/Luck, Paths.luck /
-- luckOfNodes on a test Fortune path, Logic/Loot with luck and Logic/PartyBonus.

local LootTables = require("../src/shared/Data/LootTables")
local Loot = require("../src/shared/Logic/Loot")
local Luck = require("../src/shared/Logic/Luck")
local LuckData = require("../src/shared/Data/Luck")
local PartyBonus = require("../src/shared/Logic/PartyBonus")
local PathData = require("../src/shared/Data/Paths")
local Paths = require("../src/shared/Logic/Paths")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")

local describe, it, expect = T.describe, T.it, T.expect

-- Test Fortune path (values of ROZWOJ 9.4), never in the game -------------------------------------------------------

local function node(pathId: string, name: string, kind: string, fields: { [string]: any }): any
	local out: { [string]: any } = {
		id = `{pathId}_{name}`,
		kind = kind,
		maxRank = 3,
		glyph = "*",
		nameKey = `path.{pathId}.{name}.name`,
		descKey = `path.{pathId}.{name}.desc`,
	}
	for key, value in fields do
		out[key] = value
	end
	return out
end

local function filler(pathId: string, r: number): any
	return node(pathId, `p{r}`, "passive", { values = { v = { 1, 3 } }, passive = { flat = { vit = "v" } } })
end

local function makePath(id: string, order: number, weapon: any, luckRows: { [number]: { any } }): any
	local rows = {}
	for r = 1, 11 do
		rows[r] = { choice = false, nodes = luckRows[r] or { filler(id, r) } }
	end
	return {
		id = id,
		class = "Cleric",
		order = order,
		role = "luck",
		nameKey = `path.{id}.name`,
		descKey = `path.{id}.desc`,
		titleId = `path_{id}`,
		weapon = weapon,
		rows = rows,
		reference = {},
		wiki = false,
	}
end

local L = "fxLuck"
local fxLuck = makePath(L, 1, { offhand = { "relic" } }, {
	[1] = { node(L, "fate", "luck", { luck = { bossLegendary = "fate" }, values = { fate = { 2, 6 } } }) },
	[4] = { node(L, "hand", "luck", { luck = { monsterItem = "hand" }, values = { hand = { 10, 30 } } }) },
	[5] = {
		node(L, "loot", "luck", { luck = { bossUpgrade = "loot" }, values = { loot = { 12, 35 } } }),
		node(L, "grace", "luck", { luck = { bossLegendary = "grace" }, values = { grace = { 2, 7 } } }),
	},
	[7] = {
		node(L, "vein", "luck", {
			luck = { gold = "vein", elite2 = "veinElite" },
			values = { vein = { 5, 15 }, veinElite = { 7, 20 } },
		}),
	},
	[10] = { node(L, "gift", "luck", { luck = { bossExtra = "gift" }, values = { gift = { 5, 15 } } }) },
})
local fxPlain = makePath("fxPlain", 2, { main = { "mace1h" } }, {})

local P = Paths.withSource(Paths.sourceOf({ fxLuck, fxPlain } :: { any }))

local LUCK_NODES = { "fate", "hand", "loot", "grace", "vein", "gift" }

local function cleric(main: string?, rank: number?): any
	local nodes: { [string]: number } = {}
	for _, name in LUCK_NODES do
		nodes[`{L}_{name}`] = rank or 3
	end
	return {
		class = "Cleric",
		level = 100,
		name = "Ava",
		path = { main = main, nodes = nodes, bp = {}, freeUsed = true },
	}
end

local RELIC = { main = "mace1h", offhand = "relic" }

local function member(name: string, luck: { [string]: number }?, dropBonus: number?): Luck.Member
	return { name = name, luck = luck, dropBonus = dropBonus }
end

describe("Luck.capped", function()
	it("caps every field at its own limit", function()
		local over = { monsterItem = 100, elite2 = 20, gold = 15, bossLegendary = 13, bossUpgrade = 50, bossExtra = 25 }
		for field, cap in over do
			expect(Luck.capped(field, 999)).toBe(cap)
			expect(LuckData.fields[field].cap).toBe(cap)
		end
		expect(Luck.capped("nothing", 50)).toBe(0)
		expect(Luck.capped("gold", -5)).toBe(0)
		expect(Luck.capped("gold", nil)).toBe(0)
	end)
end)

describe("Luck.boss", function()
	it("Legendary multiplier, upgrade and second item from the capped fields", function()
		expect(Luck.boss({ member("a", { bossLegendary = 6 }) }).legendaryMul).toBeNear(1.06)
		expect(Luck.boss({ member("a", { bossLegendary = 13 }) }).legendaryMul).toBeNear(1.13)
		expect(Luck.boss({ member("a", { bossLegendary = 20 }) }).legendaryMul).toBeNear(1.13)
		expect(Luck.boss({ member("a", { bossUpgrade = 35 }) }).upgrade).toBeNear(0.35)
		expect(Luck.boss({ member("a", { bossUpgrade = 70 }) }).upgrade).toBeNear(0.5)
		expect(Luck.boss({ member("a", { bossExtra = 15 }) }).extra).toBeNear(0.15)
		expect(Luck.boss({ member("a", { bossExtra = 40 }) }).extra).toBeNear(0.25)
	end)

	it("items, blessings and guild do nothing on bosses", function()
		local luck = Luck.boss({ member("a", nil, 80) })
		expect(luck.legendaryMul).toBe(1)
		expect(luck.upgrade).toBe(0)
		expect(luck.extra).toBe(0)
		expect(luck.from).toBeNil()
		expect(Luck.isNeutral(luck)).toBe(true)
	end)

	it("the best member counts, a second priest adds nothing", function()
		local luck = Luck.boss({
			member("a", { bossLegendary = 0 }),
			member("b", { bossLegendary = 6 }),
			member("c", { bossLegendary = 13 }),
		})
		expect(luck.legendaryMul).toBeNear(1.13)
		expect(luck.from).toBe("c")
		luck = Luck.boss({ member("x", { bossLegendary = 13 }), member("y", { bossLegendary = 13 }) })
		expect(luck.legendaryMul).toBeNear(1.13)
		expect(luck.from).toBe("x")
	end)

	it("no luck in PvP", function()
		local luck = Luck.boss({ member("a", { bossLegendary = 13, bossUpgrade = 35 }) }, { pvp = true })
		expect(luck).toEqual(Luck.NONE_BOSS)
		expect(Luck.isNeutral(nil)).toBe(true)
	end)
end)

describe("Luck.monster", function()
	it("best dropBonus of the group plus Fortune, inside one cap", function()
		local luck = Luck.monster({ member("killer", nil, 10), member("mate", { monsterItem = 30 }, 40) })
		expect(luck.personal).toBe(40)
		expect(luck.fortune).toBe(30)
		expect(luck.itemBonus).toBe(70)
		expect(luck.from).toBe("mate")
		luck = Luck.monster({ member("a", nil, 90), member("b", { monsterItem = 30 }) })
		expect(luck.itemBonus).toBe(100)
	end)

	it("gold and Elite II are capped", function()
		expect(Luck.monster({ member("a", { gold = 25 }) }).gold).toBe(15)
		expect(Luck.monster({ member("a", { elite2 = 20 }) }).elite2Mul).toBeNear(1.2)
		expect(Luck.monster({ member("a", { elite2 = 35 }) }).elite2Mul).toBeNear(1.2)
	end)

	it("no luck in PvP", function()
		local luck = Luck.monster({ member("a", { monsterItem = 30 }, 50) }, { pvp = true })
		expect(luck).toEqual(Luck.NONE_MONSTER)
	end)
end)

describe("Paths.luck", function()
	it("full Fortune: x1.13 and every field", function()
		local luck = P.luck(cleric(L), RELIC)
		expect(luck.bossLegendary).toBeNear(13)
		expect(luck.monsterItem).toBeNear(30)
		expect(luck.elite2).toBeNear(20)
		expect(luck.gold).toBeNear(15)
		expect(luck.bossUpgrade).toBeNear(35)
		expect(luck.bossExtra).toBeNear(15)
		local boss = Luck.boss({ member("Ava", luck) })
		expect(boss.legendaryMul).toBeNear(1.13)
		expect(boss.upgrade).toBeNear(0.35)
		expect(boss.extra).toBeNear(0.15)
		local monster = Luck.monster({ member("Ava", luck) })
		expect(monster.fortune).toBeNear(30)
		expect(monster.gold).toBeNear(15)
		expect(monster.elite2Mul).toBeNear(1.2)
	end)

	it("another main path: only row 1, at full value (x1.06)", function()
		local luck = P.luck(cleric("fxPlain"), RELIC)
		expect(luck).toEqual({ bossLegendary = 6 })
		expect(Luck.boss({ member("Ava", luck) }).legendaryMul).toBeNear(1.06)
		local monster = Luck.monster({ member("Ava", luck) })
		expect(monster.itemBonus).toBe(0)
		expect(monster.gold).toBe(0)
		expect(monster.elite2Mul).toBe(1)
	end)

	it("the main path without its weapon: x1.06", function()
		local luck = P.luck(cleric(L), { main = "mace1h", offhand = "shield" })
		expect(Luck.boss({ member("Ava", luck) }).legendaryMul).toBeNear(1.06)
	end)

	it("luckOfNodes on activeNodes equals luck; rank 1 is linear", function()
		local char = cleric(L)
		expect(P.luckOfNodes(P.activeNodes(char, RELIC))).toEqual(P.luck(char, RELIC))
		local low = cleric(L, 1)
		expect(P.luck(low, RELIC).bossLegendary).toBeNear(4) -- fate 2 + grace 2
		low.path.nodes = { [`{L}_fate`] = 1 }
		expect(P.luck(low, RELIC)).toEqual({ bossLegendary = 2 })
	end)

	it("a character without a path has no luck", function()
		local fresh = { class = "Cleric", level = 30 }
		expect(P.luck(fresh, {})).toEqual({})
		expect(Paths.luck(fresh, {})).toEqual({})
		expect(Luck.isNeutral(Luck.boss({ member("x", P.luck(fresh, {})) }))).toBe(true)
	end)
end)

describe("luck node data", function()
	local function check(def: any)
		for r, row in def.rows do
			for _, n in row.nodes do
				if n.luck then
					for field, valueKey in n.luck do
						expect(LuckData.fields[field] ~= nil).toBe(true)
						expect(n.values ~= nil and n.values[valueKey] ~= nil).toBe(true)
						if r <= PathData.DIP_ROWS then
							expect(field).toBe("bossLegendary")
						end
					end
				end
			end
		end
	end

	it("every luck field exists and points at a node value; rows 1-2 give only bossLegendary", function()
		for _, def in PathData.list do
			check(def)
		end
		check(fxLuck)
	end)
end)

-- S71: the Priest of Fortune on the real Cleric data (Data/Paths/Cleric, model builds) -------------------------------

describe("Full Fortune on the Cleric paths (S71)", function()
	local function buildNodes(pathId: string, buildId: string): { [string]: number }
		local def = PathData.get(pathId) :: any
		for _, build in def.reference do
			if build.id == buildId then
				local nodes: { [string]: number } = {}
				for _, entry in build.nodes do
					nodes[entry[1]] = entry[2]
				end
				return nodes
			end
		end
		error(`no build {pathId}/{buildId}`)
	end
	local function priest(main: string, nodes: { [string]: number }, name: string?): any
		return {
			class = "Cleric",
			level = 100,
			name = name or "Ava",
			path = { main = main, nodes = nodes, bp = {}, freeUsed = true },
		}
	end
	local plunder = buildNodes("fortune", "plunder")

	it("the plunder build: x1.13, 35% upgrade, 15% second item, +30% items, Elite II x1.2, gold +15%", function()
		local luck = Paths.luck(priest("fortune", plunder), RELIC)
		local want = { bossLegendary = 13, monsterItem = 30, elite2 = 20, gold = 15, bossUpgrade = 35, bossExtra = 15 }
		for field, value in want do
			expect(luck[field]).toBeNear(value)
		end
		local boss = Luck.boss({ member("Ava", luck) })
		expect(boss.legendaryMul).toBeNear(1.13)
		expect(boss.upgrade).toBeNear(0.35)
		expect(boss.extra).toBeNear(0.15)
		local monster = Luck.monster({ member("Ava", luck) })
		expect(monster.elite2Mul).toBeNear(1.2)
		expect(monster.gold).toBeNear(15)
	end)

	it("without a relic, or from the Healer's build: only row 1 (x1.06)", function()
		local noRelic = Paths.luck(priest("fortune", plunder), { main = "scepter", offhand = "shield" })
		expect(noRelic).toEqual({ bossLegendary = 6 })
		expect(Luck.boss({ member("Ava", noRelic) }).legendaryMul).toBeNear(1.06)
		local healer =
			Paths.luck(priest("healer", buildNodes("healer", "dungeon")), { main = "scepter", offhand = "shield" })
		expect(healer).toEqual({ bossLegendary = 6 })
		local boss = Luck.boss({ member("Bo", healer) })
		expect(boss.legendaryMul).toBeNear(1.06)
		expect(boss.upgrade).toBe(0)
		expect(boss.extra).toBe(0)
	end)

	it("the party: shared item cap, a second priest adds nothing, no luck in PvP", function()
		local luck = Paths.luck(priest("fortune", plunder), RELIC)
		expect(Luck.monster({ member("rich", nil, 80), member("Ava", luck) }).itemBonus).toBe(100)
		local twice = Luck.boss({ member("Ava", luck), member("Cy", luck) })
		expect(twice.legendaryMul).toBeNear(1.13)
		expect(Luck.boss({ member("Ava", luck) }, { pvp = true })).toEqual(Luck.NONE_BOSS)
		expect(Luck.monster({ member("Ava", luck) }, { pvp = true })).toEqual(Luck.NONE_MONSTER)
	end)

	it("the max node values of a field in one path never pass its cap", function()
		for _, def in PathData.list do
			local sums: { [string]: number } = {}
			for _, row in def.rows do
				for _, n in row.nodes do
					for field, valueKey in n.luck or {} do
						local max = Paths.nodeValues(n, n.maxRank)[valueKey] or 0
						sums[field] = (sums[field] or 0) + max
					end
				end
			end
			for field, sum in sums do
				expect({ def.id, field, sum <= LuckData.fields[field].cap + 1e-9 }).toEqual({ def.id, field, true })
			end
		end
	end)
end)

describe("Loot with luck", function()
	local boss = LootTables.bosses.grimrok

	it("bossChances: Fortune multiplies the Legendary chance only, same shape", function()
		local c = Loot.bossChances("grimrok", 0, { legendaryMul = 1.13 })
		expect(c.legendary).toBeNear(0.0678)
		expect(c.mythic).toBeNear(0.01)
		local keys = {}
		for key in c do
			table.insert(keys, key)
		end
		table.sort(keys)
		expect(keys).toEqual({ "legendary", "mythic" })
		expect(Loot.bossChances("grimrok", 0)).toEqual(Loot.bossChances("grimrok", 0, nil))
	end)

	it("neutral luck rolls exactly like no luck", function()
		local neutral = { legendaryMul = 1, upgrade = 0, extra = 0 }
		for seed = 1, 200 do
			local a, b = Rng.new(seed), Rng.new(seed)
			local x = Loot.rollBossItem(boss, 0, "Cleric", a)
			local y = Loot.rollBossItem(boss, 0, "Cleric", b, neutral)
			expect(y).toEqual(x)
			expect(Loot.rollBossExtra(boss, "Cleric", b, neutral)).toBeNil()
			expect(b:next()).toBe(a:next())
		end
	end)

	it("upgrade = 1 leaves no Unique boss item", function()
		local rng = Rng.new(7)
		local upgraded = 0
		for _ = 1, 2000 do
			local drop = Loot.rollBossItem(boss, 0, "Cleric", rng, { upgrade = 1 }) :: any
			expect(drop.rarity ~= Rarities.UNIQUE).toBe(true)
			upgraded += if drop.upgraded then 1 else 0
		end
		expect(upgraded > 0).toBe(true)
	end)

	it("second item: nothing at extra 0, a Unique / Heroic item at extra 1", function()
		local a, b = Rng.new(5), Rng.new(5)
		expect(Loot.rollBossExtra(boss, "Cleric", a, { extra = 0 })).toBeNil()
		expect(Loot.rollBossExtra(boss, "Cleric", a, nil)).toBeNil()
		expect(a:next()).toBe(b:next())
		local rng = Rng.new(9)
		for _ = 1, 50 do
			local drop = Loot.rollBossExtra(boss, "Cleric", rng, { extra = 1 }) :: any
			expect(drop.extra).toBe(true)
			expect(drop.rarity == Rarities.UNIQUE or drop.rarity == Rarities.HEROIC).toBe(true)
			expect(drop.upgraded).toBeNil()
		end
	end)
end)

describe("PartyBonus", function()
	it("+5% EXP for each other class, at most +15%", function()
		expect(PartyBonus.variety({})).toBe(0)
		expect(PartyBonus.variety({ "Cleric" })).toBe(0)
		expect(PartyBonus.variety({ "Cleric", "Cleric" })).toBe(0)
		expect(PartyBonus.variety({ "Cleric", "Mage" })).toBe(5)
		expect(PartyBonus.variety({ "Cleric", "Mage", "Hunter" })).toBe(10)
		expect(PartyBonus.variety({ "Cleric", "Mage", "Hunter", "Warrior" })).toBe(15)
		expect(PartyBonus.variety({ "Cleric", "Mage", "Hunter", "Warrior", "Mage" })).toBe(15)
		expect(PartyBonus.variety({ "Cleric", "" })).toBe(0)
		expect(PartyBonus.expMul({ "Cleric", "Mage", "Hunter", "Warrior" })).toBeNear(1.15)
	end)
end)

return nil
