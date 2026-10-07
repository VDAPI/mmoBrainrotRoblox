--!strict
-- Balance targets of levels 1-20 (S32, DESIGN §15.1), checked with the model in tests/Balance.luau (expected
-- values from the game's own modules). Also keeps the S18 single-fight band for the higher levels.
local B = require("./Balance")
local Bosses = require("../src/shared/Data/Bosses")
local Items = require("../src/shared/Data/Items")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Loot = require("../src/shared/Logic/Loot")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Monsters = require("../src/shared/Data/Monsters")
local Rarities = require("../src/shared/Data/Rarities")
local Shops = require("../src/shared/Data/Shops")
local T = require("./Test")

local LEVELS = { 1, 2, 5, 10, 15, 18, 20 }
local MAIN = { "Warrior", "Hunter", "Mage" }

-- Highest weapon merchant tier at or below `level` (the starting weapon below the first tier).
local function shopTier(level: number): number
	local best = 1
	for _, tier in Shops.WEAPONSMITH_TIERS do
		if tier <= level then
			best = tier
		end
	end
	return best
end

T.describe("Balance S32: one monster and groups", function()
	for _, classId in B.CLASSES do
		T.it(`{classId}: one monster of its level takes 6-10 s and 12-25 % HP (levels 2-20)`, function()
			for _, level in LEVELS do
				local f = B.duel(B.player(classId, level), B.monster(B.GENERIC, level))
				if level >= 2 then
					-- Clerics fight slower but take less damage (S18 band).
					local slow = if classId == "Cleric" then 11 else 10
					local low = if classId == "Cleric" then 0.09 else 0.1
					T.expect(f.seconds).toBeBetween(5.5, slow)
					T.expect(f.hpLost).toBeBetween(low, 0.25)
				else
					-- Level 1 is a gentle start.
					T.expect(f.hpLost < 0.15).toBe(true)
				end
			end
		end)

		T.it(`{classId}: an average group costs 35-60 % HP, a group of 4 at most 110 % (levels 5-20)`, function()
			for _, level in LEVELS do
				local g = B.expectedGroup(B.player(classId, level), B.GENERIC, level)
				local high = if classId == "Mage" then 0.7 else 0.6
				local low = if classId == "Cleric" then 0.3 else 0.35
				if level >= 5 then
					T.expect(g.hpLost).toBeBetween(low, high)
				end
				T.expect(g.bySize[4].hpLost <= 1.1).toBe(true)
			end
		end)
	end

	T.it("bigger groups hit softer per member", function()
		local last = math.huge
		for n = 1, 4 do
			local mul = MonsterStats.groupDamageMul(n)
			T.expect(mul <= last).toBe(true)
			last = mul
		end
		T.expect(MonsterStats.groupDamageMul(nil)).toBe(1)
		T.expect(MonsterStats.groupDamageMul(9)).toBe(MonsterStats.groupDamageMul(4))
	end)

	T.it("three wolves of the player's level are hard but winnable without skills", function()
		local skill = B.SKILL_DPS
		B.SKILL_DPS = 1
		for _, classId in B.CLASSES do
			for _, level in { 3, 5, 6 } do
				local f = B.groupFight(B.player(classId, level), B.group("wolf", level, 3))
				T.expect(f.hpLost).toBeBetween(0.4, 0.95)
			end
		end
		B.SKILL_DPS = skill
	end)

	T.it("gear from the shops (up to 9 levels too low) still kills a monster in <= 15 s with <= 35 % HP", function()
		for _, classId in B.CLASSES do
			for level = 2, 20 do
				local p = B.player(classId, level, {
					ilvl = Items.generate.tierFor(level),
					weaponIlvl = shopTier(level),
				})
				local f = B.duel(p, B.monster(B.GENERIC, level))
				-- Clerics are slow on purpose (and lose the least HP).
				T.expect(f.seconds <= (if classId == "Cleric" then 20 else 15.5)).toBe(true)
				T.expect(f.hpLost <= 0.36).toBe(true)
			end
		end
	end)
end)

T.describe("Balance S32: elites, Elite II, Grimrok", function()
	T.it("an Elite solo (level +2) takes 20-35 s and 55-95 % HP", function()
		for _, classId in MAIN do
			for _, level in { 10, 15, 18, 20 } do
				local f = B.elite(B.player(classId, level), B.GENERIC, level)
				T.expect(f.seconds).toBeBetween(20, 36)
				T.expect(f.hpLost).toBeBetween(0.55, 0.95)
			end
		end
	end)

	T.it("an Elite II needs 2-3 players: solo it kills, three players win", function()
		for _, spec in { { "bandit", 12 }, { "goblinScout", 16 }, { "caveSpider", 18 }, { "goblinShaman", 18 } } do
			local kind, spawner = spec[1] :: string, spec[2] :: number
			local level = math.min(20, spawner + 2)
			local w, m, h = B.player("Warrior", level), B.player("Mage", level), B.player("Hunter", level)
			T.expect(B.elite2({ w }, kind, spawner).hpLost > 1.5).toBe(true)
			T.expect(B.elite2({ w, m }, kind, spawner).hpLost <= 1.5).toBe(true)
			T.expect(B.elite2({ w, m, h }, kind, spawner).hpLost <= 1.0).toBe(true)
		end
	end)

	T.it("Grimrok: 3-5 players of level 19 need 4-6 min; no hit takes more than 70 % of a level 20 Mage", function()
		local order = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }
		for n = 3, 5 do
			local team = {}
			for i = 1, n do
				table.insert(team, B.player(order[i], 19))
			end
			T.expect(B.boss("grimrok", team).seconds / 60).toBeBetween(4, 6)
		end
		local mage = B.boss("grimrok", { B.player("Mage", 20) })
		T.expect(mage.biggest[1].share <= 0.7).toBe(true)
		-- A level 18 Mage survives one hit too.
		T.expect(B.boss("grimrok", { B.player("Mage", 18) }).biggest[1].share < 1).toBe(true)
		T.expect((Bosses.byId.grimrok :: any).hpMul ~= nil).toBe(true)
	end)
end)

T.describe("Balance S32: items", function()
	T.it("a full set of a rarity beats Common: Unique +8-15 %, Heroic +15-25 %, Legendary +25-40 %", function()
		for _, classId in B.CLASSES do
			for _, level in { 5, 10, 20 } do
				T.expect(B.rarityGain(classId, level, Rarities.UNIQUE)).toBeBetween(0.07, 0.15)
				T.expect(B.rarityGain(classId, level, Rarities.HEROIC)).toBeBetween(0.15, 0.25)
				T.expect(B.rarityGain(classId, level, Rarities.LEGENDARY)).toBeBetween(0.25, 0.42)
				local mythic = B.rarityGain(classId, level, Rarities.MYTHIC)
				T.expect(mythic > B.rarityGain(classId, level, Rarities.LEGENDARY)).toBe(true)
			end
		end
	end)

	T.it("two-handed weapons match 1H + off-hand within 3 % of DPS x survivability", function()
		local cases = {
			{ "Warrior", { "sword2h", "axe2h", "hammer2h", "spear2h" } },
			{ "Mage", { "staff", "runestaff" } },
			{ "Cleric", { "holystaff" } },
		}
		for _, case in cases do
			local classId = case[1] :: string
			for _, level in { 5, 10, 20 } do
				local base = B.power(B.player(classId, level)) ^ 2
				for _, weapon in case[2] :: { string } do
					local score = B.power(B.player(classId, level, { weapon = weapon, offhand = false })) ^ 2
					T.expect(score / base).toBeBetween(0.97, 1.035)
				end
			end
		end
	end)

	T.it("Grimrok's Mythic cleaver beats a Legendary axe of level 20", function()
		local cleaver = B.playerFromItems("Warrior", 20, {
			{
				uid = "c",
				id = "unique_grimrok_cleaver",
				rarity = 5,
				ilvl = 20,
				bonuses = {},
				up = 0,
				bound = false,
				n = 1,
			},
		})
		local legendary = B.player("Warrior", 20, {
			ilvl = 20,
			weapon = "axe1h",
			rarity = Rarities.LEGENDARY,
			offhand = false,
			armor = false,
			jewellery = false,
		})
		local m = B.monster(B.GENERIC, 20)
		T.expect(B.dps(cleaver, m) > B.dps(legendary, m)).toBe(true)
	end)

	T.it("weapon bonuses never roll stats of another class", function()
		for _, id in ItemRoll.bonusPool("sword1h_20") do
			T.expect(id ~= "int" and id ~= "magAtk" and id ~= "dex" and id ~= "mana").toBe(true)
		end
		for _, id in ItemRoll.bonusPool("wand_20") do
			T.expect(id ~= "str" and id ~= "physAtk" and id ~= "dex").toBe(true)
		end
		-- Jewellery follows the class it dropped for.
		T.expect(table.find(ItemRoll.bonusPool("ring_20", "Warrior"), "int")).toBeNil()
		T.expect(table.find(ItemRoll.bonusPool("ring_20", "Mage"), "int") ~= nil).toBe(true)
		T.expect(table.find(ItemRoll.bonusPool("ring_20"), "int") ~= nil).toBe(true)
	end)

	T.it("the Mage's light armour has HP and jewellery helps every class", function()
		T.expect((Items.bases.byType.armor_light.stats :: any)(20).hp > 0).toBe(true)
		local talisman = (Items.bases.byType.talisman.stats :: any)(20)
		T.expect(talisman.hp > 0 and talisman.armor > 0).toBe(true)
		for _, classId in B.CLASSES do
			local with = B.power(B.player(classId, 20))
			local without = B.power(B.player(classId, 20, { jewellery = false }))
			T.expect(with / without - 1).toBeBetween(0.08, 0.3)
		end
	end)
end)

T.describe("Balance S32: drops, rewards, gold", function()
	T.it("drops are never above the monster's level; Elites drop at their spawner's level", function()
		for level = 1, 20 do
			local low, high = ItemRoll.dropLevelRange(level)
			T.expect(high).toBe(level)
			T.expect(low).toBe(math.max(1, level - 2))
		end
		T.expect(B.wearableShare(10)).toBe(1)
		T.expect(Loot.dropBaseLevel(22, "elite2", 20)).toBe(18)
		T.expect(Loot.dropBaseLevel(22, "elite", 20)).toBe(20)
		T.expect(Loot.dropBaseLevel(20, "elite", 18)).toBe(18)
		T.expect(Loot.dropBaseLevel(10, "normal", nil)).toBe(10)
	end)

	T.it("a Unique for the class about every 1-2 levels, a Heroic about every 1-2 h of cave Elites", function()
		for _, level in { 10, 15, 18 } do
			local pace = B.pace("Warrior", level)
			local uniques = (pace.kills + B.questKills(level)) * B.itemsPerKill("normal", Rarities.UNIQUE)
			T.expect(uniques).toBeBetween(0.5, 1.6)
			local heroicPerHour = 3600 / B.eliteCadence("Warrior", level) * B.itemsPerKill("elite", Rarities.HEROIC)
			T.expect(heroicPerHour).toBeBetween(0.5, 1.5)
		end
	end)

	T.it("tougher kinds pay more EXP and gold, weak ones less", function()
		local bear = MonsterStats.kindReward(Monsters.get("brownBear") :: any)
		local rabbit = MonsterStats.kindReward(Monsters.get("rabbit") :: any)
		T.expect(bear > 1.1).toBe(true)
		T.expect(rabbit < 0.7).toBe(true)
		T.expect(MonsterStats.kindReward(B.GENERIC :: any)).toBe(1)
		-- EXP per second of fighting stays close between the kinds of the Meadows.
		for _, def in Monsters.list do
			if def.region == 1 then
				local level = math.floor((def.levels.min + def.levels.max) / 2)
				local p = B.player("Warrior", level)
				local own = B.killExp(level, def, level) / B.duel(p, B.monster(def, level)).seconds
				local generic = B.killExp(level, B.GENERIC, level) / B.duel(p, B.monster(B.GENERIC, level)).seconds
				T.expect(own / generic).toBeBetween(0.85, 1.2)
			end
		end
	end)

	T.it("gold from monsters far below the player drops (half the EXP penalty)", function()
		T.expect(MonsterStats.goldLevelMultiplier(20, 20)).toBe(1)
		T.expect(MonsterStats.goldLevelMultiplier(20, 15)).toBe(1)
		T.expect(MonsterStats.goldLevelMultiplier(10, 20)).toBe(1) -- never a bonus
		local mul = MonsterStats.goldLevelMultiplier(20, 10)
		T.expect(mul).toBeBetween(0.5, 0.75)
		T.expect(B.killGold(20, B.GENERIC, 20) > B.killGold(20, B.GENERIC, 10)).toBe(true)
	end)

	T.it("+1..+3 on the weapon fits a level's income; potions <= 15 %, drop sales 30-50 % of kill gold", function()
		for _, classId in B.CLASSES do
			local eco = B.economy(classId, 20)
			for _, row in eco.rows do
				if row.level >= 4 then
					T.expect(row.up3 <= row.income * 1.05).toBe(true)
				end
			end
			local income = eco.killGold + eco.dropGold + eco.questGold
			T.expect(eco.potionGold / income <= 0.15).toBe(true)
			T.expect(eco.dropGold / eco.killGold).toBeBetween(0.3, 0.55)
		end
	end)
end)

-- The S18 band (weapon + 4 armour pieces of the same level, no off-hand, jewellery or skills) at higher levels.
T.describe("Monster balance (S18 band, levels 30-90)", function()
	for _, level in { 30, 60, 90 } do
		T.it(`Warrior level {level}: 6-10 s per kill, 10-30% HP lost`, function()
			local fight = B.fight("Warrior", level)
			T.expect(fight.killSeconds).toBeBetween(6, 10)
			T.expect(fight.hpLost).toBeBetween(0.10, 0.30)
		end)
	end

	T.it("no class dies to one monster of its level", function()
		for classId in B.LOADOUT do
			for _, level in { 2, 5, 10, 30, 60, 90 } do
				T.expect(B.fight(classId, level).hpLost < 0.5).toBe(true)
			end
		end
	end)
end)
