--!strict
-- S87 (balance plan C-I): the global balance fixes as pure logic. Monster and Elite curves from the final level
-- (exactly the old numbers up to 20), the region tables (cave Elite pairs, drop factor) with neutral values that keep
-- the Rng use, the pct scale capped at ilvl 20, two-handed weapons read on load, potion level thresholds, the
-- character power of /balance and the mana demand of its Mage line.
local AreaProfiles = require("../src/shared/Data/AreaProfiles")
local AreaRates = require("../src/shared/Logic/AreaRates")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local B = require("./Balance")
local Bonuses = require("../src/shared/Data/Bonuses")
local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local FightSim = require("../src/shared/Logic/FightSim")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local LevelCurveData = require("../src/shared/Data/LevelCurves")
local LevelCurves = require("../src/shared/Logic/LevelCurves")
local Loot = require("../src/shared/Logic/Loot")
local LootTables = require("../src/shared/Data/LootTables")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Potions = require("../src/shared/Logic/Potions")
local Rarities = require("../src/shared/Data/Rarities")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")
local Upgrade = require("../src/shared/Logic/Upgrade")

local GENERIC = { hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee" }

T.describe("S87: monster and Elite curves", function()
	T.it("up to level 20 the stats are the formula without curves, bit for bit", function()
		local function oldHp(L: number): number
			return Combat.monsterHpBase + Combat.monsterHpComp * Combat.monsterHpFactor * L ^ Combat.monsterHpExponent
		end
		local function oldAtk(L: number): number
			return Combat.monsterAtkBase + Combat.monsterAtkFactor * L ^ Combat.monsterAtkExponent
		end
		for L = 1, 20 do
			T.expect(MonsterStats.baseHp(L)).toBe(oldHp(L))
			T.expect(MonsterStats.baseAttack(L)).toBe(oldAtk(L))
			local m = MonsterStats.compute(GENERIC, L, "normal", 3)
			T.expect(m.maxHp).toBe(math.floor(oldHp(L) * 1 * 1 * 1 + 0.5))
			T.expect(m.attack).toBe(oldAtk(L) * 1 * 1 * 1 * MonsterStats.groupDamageMul(3))
		end
		-- an Elite of spawner 18 is level 20: still no curve
		local elite = MonsterStats.compute(GENERIC, 18, "elite")
		local v = Combat.variants.elite
		T.expect(elite.maxHp).toBe(math.floor(oldHp(20) * v.hpMul + 0.5))
		T.expect(elite.attack).toBe(oldAtk(20) * v.dmgMul)
	end)

	T.it("an Elite at 45 is level 47 with the monster and Elite curves of 47", function()
		local m = MonsterStats.compute(GENERIC, 45, "elite")
		local v = Combat.variants.elite
		T.expect(m.level).toBe(47)
		local hp = MonsterStats.baseHp(47) * v.hpMul * LevelCurves.at("eliteHp", 47)
		T.expect(m.maxHp).toBe(math.floor(hp + 0.5))
		T.expect(m.attack).toBeNear(MonsterStats.baseAttack(47) * v.dmgMul * LevelCurves.at("eliteDmg", 47), 1e-9)
		T.expect(MonsterStats.baseHp(47)).toBeNear(
			(Combat.monsterHpBase + Combat.monsterHpComp * Combat.monsterHpFactor * 47 ^ Combat.monsterHpExponent)
				* LevelCurves.at("monsterHp", 47),
			1e-9
		)
		-- normal monsters and bosses get no Elite curve; Elite II its own (neutral today)
		T.expect({ MonsterStats.variantCurves("normal", 47) }).toEqual({ 1, 1 })
		T.expect({ MonsterStats.variantCurves("boss", 70) }).toEqual({ 1, 1 })
		T.expect({ MonsterStats.variantCurves("elite2", 70) }).toEqual({
			LevelCurves.at("elite2Hp", 70),
			LevelCurves.at("elite2Dmg", 70),
		})
	end)
end)

T.describe("S87: region tables", function()
	local cave = Areas.caves.list[1]

	T.it("cave Elite pairs follow pairChance; the default equals the neutral 0.5", function()
		local function counts(spawners: { any }): (number, number)
			local single, pair = 0, 0
			for _, s in spawners do
				if s.variant == "elite" then
					if s.count == 2 then
						pair += 1
					else
						single += 1
					end
				end
			end
			return single, pair
		end
		local s0, p0 = counts(AreaSpawns.cave(cave, { pairChance = 0 }))
		T.expect(p0).toBe(0)
		T.expect(s0 > 0).toBe(true)
		local s1, p1 = counts(AreaSpawns.cave(cave, { pairChance = 1 }))
		T.expect(s1).toBe(0)
		T.expect(p1 > 0).toBe(true)
		T.expect(AreaSpawns.cave(cave)).toEqual(AreaSpawns.cave(cave, { pairChance = 0.5 }))
		T.expect(LevelCurves.elitePairChance(cave.region)).toBe(0.5)
	end)

	T.it("dropFactor 1 keeps the table itself; 0.5 halves Unique and Heroic, Common takes the rest", function()
		for _, variant in { "normal", "elite", "boss" } do
			T.expect(rawequal(ItemRoll.rarityWeights(variant, nil, 1), ItemRoll.rarityWeights(variant))).toBe(true)
		end
		local base = ItemRoll.rarityWeights("elite")
		local half = ItemRoll.rarityWeights("elite", nil, 0.5)
		local function total(w: { [number]: number }): number
			local sum = 0
			for _, x in w do
				sum += x
			end
			return sum
		end
		T.expect(half[Rarities.UNIQUE]).toBeNear(base[Rarities.UNIQUE] * 0.5)
		T.expect(half[Rarities.HEROIC]).toBeNear(base[Rarities.HEROIC] * 0.5)
		T.expect(total(half)).toBeNear(total(base))
		T.expect(half[Rarities.LEGENDARY] or 0).toBe(base[Rarities.LEGENDARY] or 0)
		-- the hunting ground's top tier multiplier applies on the scaled table
		local both = ItemRoll.rarityWeights("normal", 2, 0.5)
		T.expect(both[Rarities.UNIQUE]).toBeNear(Rarities.dropWeights.normal[Rarities.UNIQUE] * 0.5 * 2)
	end)

	T.it("AreaRates.itemsPerKill with dropFactor 1 is unchanged", function()
		local mods = AreaProfiles.NEUTRAL
		for _, variant in { "normal", "elite", "elite2" } do
			local a, b = AreaRates.itemsPerKill(variant, mods, 10)
			local c, d = AreaRates.itemsPerKill(variant, mods, 10, 1)
			T.expect({ a, b }).toEqual({ c, d })
		end
	end)

	T.it("every region's dropFactor rolls on every monster variant (Elite II has no Common to absorb f > 1)", function()
		for _, region in LevelCurveData.regions do
			local f = LevelCurves.dropFactor(region)
			for _, variant in { "normal", "elite", "elite2" } do
				local ok = pcall(ItemRoll.rarityWeights, variant, nil, f)
				T.expect(ok).toBe(true)
			end
		end
	end)

	T.it("the model's drops per hour follow the region's dropFactor (Balance.dropFactorAt)", function()
		T.expect(B.dropFactorAt(50)).toBe(LevelCurves.dropFactor("ashen"))
		local base = B.dropsPerHour("Warrior", 50, "K0", false)
		local saved = B.dropFactorAt
		B.dropFactorAt = function(level: number): number
			return 0.5 * saved(level)
		end
		local ok, half = pcall(B.dropsPerHour, "Warrior", 50, "K0", false)
		B.dropFactorAt = saved
		T.expect(ok).toBe(true)
		T.expect((half :: any).unique).toBeNear(base.unique * 0.5, 1e-9)
		T.expect((half :: any).killsPerHour).toBe(base.killsPerHour)
	end)
end)

T.describe("S87: substitute Mythic in the model", function()
	T.it("bossDrops gives the class every Mythic the boss rolls (Loot.rollBossItem always fits the class)", function()
		for bossId in LootTables.bosses do
			local sum = 0
			for k = 0, Config.Boss.dailyRuns - 1 do
				sum += Loot.bossChances(bossId, k).mythic
			end
			for _, classId in B.CLASSES do
				T.expect(B.bossDrops(classId, bossId).mythic).toBeNear(sum, 1e-9)
			end
		end
	end)
end)

T.describe("S87: items", function()
	T.it("pct lines stop growing at ilvl 20; below it 1 + ilvl / 60", function()
		local pctLine = "physAtk"
		local def = Bonuses.get(pctLine) :: Bonuses.BonusDef
		T.expect(def.scaling).toBe("pct")
		local low20, high20 = ItemRoll.bonusRange(pctLine, 20, Rarities.COMMON)
		for _, ilvl in { 60, 100 } do
			local low, high = ItemRoll.bonusRange(pctLine, ilvl, Rarities.COMMON)
			T.expect({ low, high }).toEqual({ low20, high20 })
		end
		local low10, high10 = ItemRoll.bonusRange(pctLine, 10, Rarities.COMMON)
		T.expect(low10).toBeNear(def.min * (1 + 10 / 60))
		T.expect(high10).toBeNear(def.max * (1 + 10 / 60))
		T.expect(Bonuses.scaling.pctCapIlvl).toBe(20)
	end)

	local function weapon(id: string, rarity: number, up: number, bonuses: { any }): any
		return { uid = "t", id = id, rarity = rarity, ilvl = 70, bonuses = bonuses, up = up, bound = false, n = 1 }
	end

	T.it(
		"regular lines of a rolled two-handed weapon x twoHandedBonusMul; legendary / mythic lines and quality stay",
		function()
			local two = Items.get("sword2h_70") and "sword2h_70" or B.tierId("sword2h", 70)
			local one = B.tierId("sword1h", 70)
			local lines = { { stat = "str", v = 10 }, { stat = "leg_bossDamage", v = 10 } }
			local stats2 = ItemRoll.itemStats(weapon(two, Rarities.LEGENDARY, 0, lines))
			local stats1 = ItemRoll.itemStats(weapon(one, Rarities.LEGENDARY, 0, lines))
			T.expect(ItemRoll.isRegularLine("str")).toBe(true)
			T.expect(ItemRoll.isRegularLine("leg_bossDamage")).toBe(false)
			local mul = Rarities.twoHandedBonusMul
			T.expect(stats2.bonuses[1].v).toBe(math.floor(10 * mul + 0.5))
			T.expect(stats2.bonuses[2].v).toBe(10)
			T.expect(stats2.bonuses[1].quality).toBe(stats1.bonuses[1].quality)
			T.expect(stats1.bonuses[1].v).toBe(10)
			T.expect((stats2.flat.str or 0) - (stats1.flat.str or 0) > 0).toBe(true)
		end
	)

	T.it("a two-handed base grows upgradeStatPerLevelTwoHanded per level; named items keep their lines", function()
		local two = B.tierId("sword2h", 70)
		local plain = ItemRoll.itemStats(weapon(two, Rarities.LEGENDARY, 0, {}))
		local up9 = ItemRoll.itemStats(weapon(two, Rarities.LEGENDARY, 9, {}))
		local raw = (Items.bases.byType.sword2h :: any).weapon(70)
		local baseMul = Rarities.get(Rarities.LEGENDARY).baseMul
		T.expect(up9.weapon and up9.weapon.dmg)
			.toBe(math.floor(raw.dmg * baseMul * (1 + 9 * Rarities.upgradeStatPerLevelTwoHanded) + 0.5))
		T.expect(plain.weapon and plain.weapon.dmg).toBe(math.floor(raw.dmg * baseMul + 0.5))
		T.expect(Upgrade.statMultiplier(9, true)).toBeNear(1 + 9 * Rarities.upgradeStatPerLevelTwoHanded)
		T.expect(Upgrade.statMultiplier(9)).toBeNear(1 + 9 * Rarities.upgradeStatPerLevel)
		-- the trait keeps 6 % per level
		T.expect(ItemRoll.traitPower(Rarities.LEGENDARY, 9)).toBeNear(baseMul * (1 + 9 * Rarities.upgradeStatPerLevel))
		-- a named two-handed Mythic keeps its fixed lines
		local named = ItemRoll.itemStats(weapon("unique_vaelgrath_fang", Rarities.MYTHIC, 0, {}))
		local def = Items.get("unique_vaelgrath_fang") :: any
		for i, line in def.fixedBonuses do
			T.expect(named.bonuses[i].v).toBe(line.v)
		end
	end)

	T.it("the model's two-handed item equals ItemRoll.itemStats on grid values (Legendary +9)", function()
		local item = weapon(B.tierId("axe2h", 70), Rarities.LEGENDARY, 9, {
			{ stat = "str", v = 10 }, -- x2.7 = 27, on the grid of every line (exact products)
			{ stat = "physAtk", v = 2 },
			{ stat = "critChance", v = 1 },
			{ stat = "leg_bossDamage", v = 11 },
		})
		local game = ItemRoll.itemStats(item)
		local model = B.itemStats(item)
		for _, map in { "flat", "pct", "hooks" } do
			local g, m = (game :: any)[map], (model :: any)[map]
			for k, v in g do
				T.expect(m[k] or 0).toBeNear(v, 1e-9)
			end
			for k, v in m do
				T.expect(g[k] or 0).toBeNear(v, 1e-9)
			end
		end
		T.expect(model.weapon and model.weapon.dmg).toBe(game.weapon and game.weapon.dmg)
	end)
end)

T.describe("S87: potion levels", function()
	T.it("Great from 45, Mighty from 70 for every kind; canDrink on 44 and 45", function()
		for _, kind in { "hp", "mana", "energy" } do
			local levels = {}
			for q = 1, 5 do
				levels[q] = Potions.requiredLevel(Items.get(`potion_{kind}_{q}`))
			end
			T.expect(levels).toEqual({ 1, 1, 1, 45, 70 })
		end
		local great = Items.get("potion_hp_4")
		T.expect(Potions.canDrink(great, 44)).toBe(false)
		T.expect(Potions.canDrink(great, 45)).toBe(true)
		T.expect(Potions.requiredLevel(Items.get("essence_dust"))).toBe(1)
		T.expect(Potions.requiredLevel(nil)).toBe(1)
	end)

	T.it("an old Mighty stack (ilvl 1) still needs 70; equipment keeps its ilvl", function()
		local stack = ItemRoll.makeStack("potion_hp_5", 3, "s")
		stack.ilvl = 1
		T.expect(ItemRoll.requiredLevel(stack)).toBe(70)
		local sword: any =
			{ uid = "w", id = B.tierId("sword1h", 70), rarity = 1, ilvl = 68, bonuses = {}, up = 0, n = 1 }
		T.expect(ItemRoll.requiredLevel(sword)).toBe(68)
	end)
end)

T.describe("S87: /balance numbers", function()
	T.it("FightSim.power with SKILL_DPS is Balance.power without options", function()
		for _, classId in B.CLASSES do
			for _, L in { 20, 70 } do
				local p = B.player(classId, L)
				local m = B.monster(B.GENERIC, L)
				T.expect(FightSim.power(p :: any, m, B.SKILL_DPS)).toBeNear(B.power(p), 1e-9)
			end
		end
	end)

	T.it("manaDemand sums cost / cooldown of the mana skills with a cooldown", function()
		local firebolt = SkillData.get("firebolt") :: any
		local list = {
			{ skill = firebolt, rank = 1, cooldown = 4 },
			{ skill = firebolt, rank = 1, cooldown = 0 }, -- no cooldown: left out
		}
		-- level 20: no mana curve, firebolt rank 1 costs 12
		T.expect(Skills.manaDemand(list, 20, "Mage")).toBeNear(12 / 4)
		T.expect(Skills.manaDemand(list, 45, "Mage")).toBeNear(12 * LevelCurves.at("manaCost.Mage", 45) / 4)
		T.expect(Skills.manaDemand({}, 45, "Mage")).toBe(0)
	end)
end)

return nil
