--!strict
-- S30: the new rarity ladder (Data/Rarities), source caps, the boss personal roll with pity (Logic/Loot),
-- daily runs (Logic/BossScaling) and the save migration to the new ids (AccountSchema 5, mail, auction).

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Auction = require("../src/shared/Logic/Auction")
local Bonuses = require("../src/shared/Data/Bonuses")
local Config = require("../src/shared/Config")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Loot = require("../src/shared/Logic/Loot")
local LootTables = require("../src/shared/Data/LootTables")
local Mail = require("../src/shared/Logic/Mail")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")
local Time = require("../src/shared/Logic/Time")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = Test.describe, Test.it, Test.expect

local counter = 0
local function uid(): string
	counter += 1
	return `r{counter}`
end

describe("Rarities S30", function()
	it("has 5 rarities with rising multipliers and the right colours", function()
		expect(#Rarities.list).toBe(5)
		expect(Rarities.MAX).toBe(5)
		expect({ Rarities.COMMON, Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC }).toEqual({
			1,
			2,
			3,
			4,
			5,
		})
		local hex = { "#9DA3AB", "#F2D33A", "#3D8BFF", "#FF9F1C", "#E5302A" }
		local keys = { "common", "unique", "heroic", "legendary", "mythic" }
		for i, rarity in Rarities.list do
			expect(rarity.id).toBe(i)
			expect(rarity.key).toBe(keys[i])
			expect(rarity.hex).toBe(hex[i])
			expect(rarity.bonusMin <= rarity.bonusMax).toBe(true)
			expect(rarity.frame.thickness > 0).toBe(true)
			if i > 1 then
				local before = Rarities.list[i - 1]
				expect(rarity.baseMul > before.baseMul).toBe(true)
				expect(rarity.sellMul > before.sellMul).toBe(true)
				-- Common rolls no bonuses, so its rangeMul is unused (S32: Unique 1.0).
				expect(rarity.rangeMul >= before.rangeMul).toBe(true)
				expect(rarity.frame.thickness >= before.frame.thickness).toBe(true)
			end
		end
		expect(Rarities.get(Rarities.LEGENDARY).frame.spin).toBe(true)
		expect(Rarities.get(Rarities.MYTHIC).frame.gradient ~= nil).toBe(true)
		expect(Rarities.get(Rarities.HEROIC).frame.glow).toBe(true)
		expect(Rarities.get(Rarities.MYTHIC).legendaryLines).toBe(2)
		expect(Rarities.get(99).id).toBe(Rarities.MAX) -- clamped, never nil
	end)

	it("capabilities come from data", function()
		local function flags(field: string): { boolean }
			local out = {}
			for _, rarity in Rarities.list do
				table.insert(out, (rarity :: any)[field] == true)
			end
			return out
		end
		expect(flags("valuable")).toEqual({ false, false, true, true, true })
		expect(flags("reveal")).toEqual({ false, false, false, true, true })
		expect(flags("legendCore")).toEqual({ false, false, false, true, true })
		expect(flags("quickSell")).toEqual({ true, true, false, false, false })
		expect(Rarities.get(Rarities.LEGENDARY).announce).toBe("legendary")
		expect(Rarities.get(Rarities.MYTHIC).announce).toBe("mythic")
		expect(Rarities.get(Rarities.HEROIC).announce).toBeNil()
		for _, rarity in Rarities.list do
			expect(#rarity.dismantle > 0).toBe(true)
			for _, drop in rarity.dismantle do
				expect(Items.get(drop.id) ~= nil).toBe(true)
			end
		end
	end)

	it("bonus pools hold at least bonusMax entries, legendary pool at least 2 lines", function()
		local most = 0
		for _, rarity in Rarities.list do
			most = math.max(most, rarity.bonusMax)
		end
		for group, pool in Bonuses.pools do
			expect({ group = group, ok = #pool >= most }).toEqual({ group = group, ok = true })
		end
		expect(#Bonuses.pools.legendary >= 2).toBe(true)
	end)

	it("every rarity has a name and a short filter name in both languages", function()
		for _, rarity in Rarities.list do
			for _, dict in { en, pl } :: { { [string]: string } } do
				expect(type(dict[rarity.nameKey])).toBe("string")
				expect(type(dict[rarity.shortKey])).toBe("string")
			end
		end
		expect(pl["rarity.unique"]).toBe("Unikatowy")
		expect(pl["rarity.mythic"]).toBe("Mityczny")
		expect(pl["itemTier.95.m"]).toBe("Eteryczny")
		expect(en["itemTier.95.m"]).toBe("Ethereal")
		expect((pl :: any)["rarity.epic"]).toBeNil()
		expect((pl :: any)["rarity.uncommon"]).toBeNil()
	end)

	it("parses admin input", function()
		expect(Rarities.parse("mythic")).toBe(5)
		expect(Rarities.parse("HEROIC")).toBe(3)
		expect(Rarities.parse("leg")).toBe(4)
		expect(Rarities.parse("2")).toBe(2)
		expect(Rarities.parse("6")).toBeNil()
		expect(Rarities.parse("epic")).toBeNil()
		expect(Rarities.parse(nil)).toBeNil()
	end)
end)

describe("Drop sources S30", function()
	it("no source weight goes above its cap", function()
		for source, weights in Rarities.dropWeights do
			local cap = Rarities.cap[source]
			expect(cap ~= nil).toBe(true)
			for rarity in weights do
				expect({ source = source, ok = rarity <= cap }).toEqual({ source = source, ok = true })
			end
		end
		expect(Rarities.cap).toEqual({ normal = 2, elite = 3, elite2 = 4, boss = 5 })
		-- The shared boss items stop at Heroic: Legendary and Mythic only from the personal roll.
		for rarity in Rarities.dropWeights.boss do
			expect(rarity <= Rarities.HEROIC).toBe(true)
		end
		expect((LootTables :: any).elite2UniqueChance).toBeNil()
		expect((Rarities :: any).bossUniqueChance).toBeNil()
	end)

	it("monsters never drop above their cap (normal, elite, Elite II)", function()
		local rng = Rng.new(30)
		for _, variant in { "normal", "elite", "elite2" } do
			local best = 0
			for _ = 1, 4000 do
				for _, drop in Loot.rollMonsterLoot("wolf", variant, 10, rng).items do
					best = math.max(best, drop.rarity)
				end
			end
			expect({ variant = variant, ok = best <= Rarities.cap[variant] }).toEqual({ variant = variant, ok = true })
		end
	end)

	it("merchant and smith items (rolled Common) have no bonuses", function()
		local item = ItemRoll.rollItem("sword1h_30", 30, Rarities.COMMON, Rng.new(1), uid())
		expect(item.rarity).toBe(Rarities.COMMON)
		expect(#item.bonuses).toBe(0)
	end)
end)

describe("Boss personal roll S30", function()
	local boss = LootTables.bosses.grimrok

	it("every boss has pity numbers and named Mythic items", function()
		for id, def in LootTables.bosses do
			expect(def.id).toBe(id)
			expect(def.legendaryHard > 1).toBe(true)
			expect(def.mythicHard > 1).toBe(true)
			expect(#def.named > 0).toBe(true)
			for _, itemId in def.named do
				expect((Items.get(itemId) :: any).rarity).toBe(Rarities.MYTHIC)
			end
		end
	end)

	it("chances grow with misses and hit 100 % at the hard limit", function()
		expect(Loot.bossChances("grimrok", nil)).toEqual({ legendary = 0.2, mythic = 0.04 })
		local c = Loot.bossChances("grimrok", { leg = 2, myth = 3 })
		expect(c.legendary).toBeNear(0.30)
		expect(c.mythic).toBeNear(0.07)
		expect(Loot.bossChances("grimrok", { leg = boss.legendaryHard - 1, myth = boss.mythicHard - 1 })).toEqual({
			legendary = 1,
			mythic = 1,
		})
		expect(Loot.bossChances("nobody", nil)).toEqual({ legendary = 0, mythic = 0 })
	end)

	it("guarantees at the limit and resets the counter on a hit", function()
		local rng = Rng.new(31)
		for _ = 1, 50 do
			local roll = Loot.rollBossPersonal(boss, { leg = boss.legendaryHard - 1, myth = boss.mythicHard - 1 }, rng)
			expect(roll.legendary).toBe(true)
			expect(roll.mythic).toBe(true)
			expect(roll.pity).toEqual({ leg = 0, myth = 0 })
		end
		-- A miss adds one; the input is not mutated.
		local pity = { leg = 0, myth = 0 }
		local sawMiss = false
		for _ = 1, 50 do
			local roll = Loot.rollBossPersonal(boss, pity, rng)
			if not roll.legendary then
				sawMiss = true
				expect(roll.pity.leg).toBe(1)
			end
		end
		expect(sawMiss).toBe(true)
		expect(pity).toEqual({ leg = 0, myth = 0 })
		-- Never more than legendaryHard kills without a legendary.
		local current = nil
		local since = 0
		for _ = 1, 2000 do
			local roll = Loot.rollBossPersonal(boss, current, rng)
			current = roll.pity
			since = if roll.legendary then 0 else since + 1
			expect(since < boss.legendaryHard).toBe(true)
		end
	end)

	it("averages about 3.4 kills per legendary and 9.8 per mythic (100 000 kills)", function()
		local n = 100000
		local result = Loot.simulateBoss(boss, n, Rng.new(32))
		expect(n / result.legendary).toBeNear(3.4, 0.1)
		expect(n / result.mythic).toBeNear(9.8, 0.35)
	end)

	it("personal items: Legendary at boss level, Mythic named or rolled with 2 legendary lines", function()
		local rng = Rng.new(33)
		local named, rolled, classMatch, legendaries = 0, 0, 0, 0
		for _ = 1, 400 do
			local drops =
				Loot.personalItems(boss, { legendary = true, mythic = true, pity = { leg = 0, myth = 0 } }, "Mage", rng)
			for _, drop in drops do
				expect(drop.ilvl).toBe(boss.level)
				local def = Items.get(drop.defId) :: any
				if drop.rarity == Rarities.LEGENDARY then
					legendaries += 1
					expect(def.fixedBonuses).toBeNil()
					if def.classes == nil or table.find(def.classes, "Mage") then
						classMatch += 1
					end
				else
					expect(drop.rarity).toBe(Rarities.MYTHIC)
					if def.fixedBonuses then
						named += 1
						expect(table.find(boss.named, drop.defId) ~= nil).toBe(true)
					else
						rolled += 1
						local item = ItemRoll.rollItem(drop.defId, drop.ilvl, drop.rarity, rng, uid())
						local lines = {}
						for _, bonus in item.bonuses do
							if table.find(Bonuses.pools.legendary, bonus.stat) then
								expect(lines[bonus.stat]).toBeNil()
								lines[bonus.stat] = true
							end
						end
						local count = 0
						for _ in lines do
							count += 1
						end
						expect(count).toBe(2)
					end
				end
			end
		end
		expect(legendaries).toBe(400)
		expect(named / 400).toBeNear(Config.BossLoot.mythicNamedShare, 0.08)
		expect(named + rolled).toBe(400)
		expect(classMatch / 400 >= Config.BossLoot.legendaryClassShare - 0.05).toBe(true)
		expect(#Loot.personalItems(boss, { legendary = false, mythic = false, pity = { leg = 1, myth = 1 } }, nil, rng)).toBe(
			0
		)
	end)

	it("the daily limit defaults to 3", function()
		expect(Config.Boss.dailyRuns).toBe(3)
	end)
end)

describe("Rarity migration S30", function()
	it("upgradeItem maps equipment, keeps stacks by definition and is idempotent", function()
		local old: any =
			{ uid = "a", id = "sword1h_30", rarity = 4, ilvl = 30, bonuses = {}, up = 0, bound = false, n = 1 }
		Rarities.upgradeItem(old, Items.get(old.id))
		expect(old.rarity).toBe(Rarities.HEROIC) -- epic -> heroic
		expect(old.rv).toBe(2)
		Rarities.upgradeItem(old, Items.get(old.id))
		expect(old.rarity).toBe(Rarities.HEROIC) -- second pass changes nothing
		local expected = { [1] = 1, [2] = 2, [3] = 3, [4] = 3, [5] = 4, [6] = 5 }
		for legacy, new in expected do
			local item: any = { id = "ring_30", rarity = legacy }
			expect(Rarities.upgradeItem(item, Items.get("ring_30")).rarity).toBe(new)
		end
		local named: any = { id = "unique_grimrok_cleaver", rarity = 6 }
		expect(Rarities.upgradeItem(named, Items.get(named.id)).rarity).toBe(Rarities.MYTHIC)
		for tier = 1, 5 do
			local blessing: any = { id = `blessing_warrior_{tier}`, rarity = tier, n = 2 }
			Rarities.upgradeItem(blessing, Items.get(blessing.id))
			expect(blessing.rarity).toBe(tier)
			expect(blessing.n).toBe(2)
		end
		local fresh = ItemRoll.rollItem("ring_30", 30, Rarities.LEGENDARY, Rng.new(1), uid())
		Rarities.upgradeItem(fresh, Items.get(fresh.id))
		expect(fresh.rarity).toBe(Rarities.LEGENDARY) -- new items carry rv = 2 and are never remapped
		expect(ItemRoll.makeStack("essence_dust", 3, uid()).rv).toBe(2)
	end)

	it("an old profile migrates items, loot log, settings and boss lockouts", function()
		local now = 20000 * 86400 + 5000
		local savedNow = AccountSchema.now
		AccountSchema.now = function()
			return now
		end
		local today = Time.dayNumber(now)
		local function old(id: string, rarity: number, extra: any?): any
			local item: any =
				{ uid = id, id = id, rarity = rarity, ilvl = 30, bonuses = {}, up = 0, bound = false, n = 1 }
			for k, v in extra or {} do
				item[k] = v
			end
			return item
		end
		local data: any = {
			schema = 4,
			characters = {
				["1"] = {
					id = "c1",
					name = "Old",
					level = 40,
					equipment = { weapon = old("sword1h_30", 5), ring1 = old("unique_grimrok_fang", 6) },
					inventory = {
						["1"] = old("armor_heavy_30", 4),
						["2"] = old("blessing_fortune_5", 5, { n = 3 }),
						["3"] = old("essence_dust", 1, { n = 40 }),
					},
					lootLog = {
						{ id = "ring_30", rarity = 4, ilvl = 30, at = 1 },
						{ id = "ring_30", rarity = 6, ilvl = 20, at = 2 },
					},
					bossLockouts = { grimrok = today, morvane = today - 1 },
					quests = {
						mainDone = 3,
						side = {
							active = { q = { progress = { 1 }, used = {}, choice = { old("ring_30", 3) } } },
							done = {},
						},
					},
				},
			},
			deposit = { size = 60, items = { ["1"] = old("helmet_heavy_30", 2) } },
			settings = { lootHideBelow = 4, lootAutoFrom = 5 },
		}
		local applied = AccountSchema.migrate(data)
		AccountSchema.now = savedNow
		expect(applied).toEqual({ 5 })
		local char = data.characters["1"]
		expect(char.equipment.weapon.rarity).toBe(Rarities.LEGENDARY)
		expect(char.equipment.ring1.rarity).toBe(Rarities.MYTHIC)
		expect(char.inventory["1"].rarity).toBe(Rarities.HEROIC)
		expect(char.inventory["2"].rarity).toBe(5) -- Mythic blessing (tier 5) unchanged
		expect(char.inventory["2"].n).toBe(3)
		expect(char.inventory["3"].n).toBe(40)
		expect(char.quests.side.active.q.choice[1].rarity).toBe(Rarities.HEROIC)
		expect(data.deposit.items["1"].rarity).toBe(Rarities.UNIQUE)
		expect(char.lootLog[1].rarity).toBe(Rarities.HEROIC)
		expect(char.lootLog[2].rarity).toBe(Rarities.MYTHIC)
		expect(data.settings.lootHideBelow).toBe(3)
		expect(data.settings.lootAutoFrom).toBe(4)
		expect(char.bossLockouts).toBeNil()
		expect(char.bossRuns).toEqual({ grimrok = { day = today, n = Config.Boss.dailyRuns } })
		expect(char.bossPity).toEqual({})
		expect(char.level).toBe(40)
		expect(char.equipment.weapon.rv).toBe(2)
		-- Running the migration code again (as if applied twice) changes nothing.
		AccountSchema._migrations[5](data, function()
			return "x"
		end)
		expect(char.equipment.weapon.rarity).toBe(Rarities.LEGENDARY)
		expect(char.inventory["1"].rarity).toBe(Rarities.HEROIC)
	end)

	it("settings map 0→0, 2→2, 3→3, 4→3 (hide) and 5→4 (auto)", function()
		for _, case in { { 0, 0, 0, 0 }, { 2, 2, 2, 2 }, { 3, 3, 3, 3 }, { 4, 3, 5, 4 } } do
			local data: any =
				{ schema = 4, characters = {}, settings = { lootHideBelow = case[1], lootAutoFrom = case[3] } }
			AccountSchema.migrate(data)
			expect({ data.settings.lootHideBelow, data.settings.lootAutoFrom }).toEqual({ case[2], case[4] })
		end
	end)

	it("new characters get empty bossRuns and bossPity", function()
		local template = AccountSchema.characterTemplate()
		expect(template.bossRuns).toEqual({})
		expect(template.bossPity).toEqual({})
		expect((template :: any).bossLockouts).toBeNil()
	end)

	it("mail parcels and auction entries from before S30 are upgraded when read", function()
		local box = Mail.box({
			parcels = {
				p = {
					id = "p",
					items = {
						{
							uid = "m",
							id = "ring_30",
							rarity = 5,
							ilvl = 30,
							bonuses = {},
							up = 0,
							bound = false,
							n = 1,
						},
					},
				},
			},
		})
		expect((box.parcels.p :: any).items[1].rarity).toBe(Rarities.LEGENDARY)
		Mail.box(box)
		expect((box.parcels.p :: any).items[1].rarity).toBe(Rarities.LEGENDARY)
		local summary: any = { id = "a", r = 4 }
		expect(Auction.upgradeSummary(summary).r).toBe(Rarities.HEROIC)
		expect(Auction.upgradeSummary(summary).r).toBe(Rarities.HEROIC)
		local listing: any = {
			id = "b",
			item = ItemRoll.rollItem("ring_30", 30, Rarities.MYTHIC, Rng.new(2), uid()),
			price = 10,
			expiresAt = 1,
			sellerName = "x",
			sellerUserId = 1,
		}
		local fresh = Auction.summary(listing, Items.get("ring_30") :: any, "ring")
		expect(Auction.upgradeSummary(fresh).r).toBe(Rarities.MYTHIC)
	end)
end)

return nil
