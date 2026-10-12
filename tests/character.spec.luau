--!strict
-- Character creation, account schema and migrations.
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local CharacterFactory = require("../src/shared/Logic/CharacterFactory")
local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local T = require("./Test")
local TableUtil = require("../src/shared/Util/TableUtil")

local START_SKILL = { Warrior = "mightyStrike", Hunter = "aimedShot", Mage = "firebolt", Cleric = "holyStrike" }

local function ids()
	local n = 0
	return {
		newId = function(): string
			n += 1
			return `id{n}`
		end,
		now = 1000,
	}
end

T.describe("CharacterFactory", function()
	T.it("creates a level 1 character with class start stats", function()
		for _, classId in Classes.order do
			local character = CharacterFactory.create(classId, "Aria", ids())
			local class = Classes.get(classId) :: Classes.ClassDef
			T.expect(character.class).toBe(classId)
			T.expect(character.level).toBe(1)
			T.expect(character.exp).toBe(0)
			T.expect(character.statPoints).toBe(0)
			T.expect((character :: any).skills).toBeNil()
			T.expect((character :: any).skillPoints).toBeNil()
			T.expect(character.hotbar).toEqual({ ["1"] = START_SKILL[classId] })
			T.expect(character.path).toEqual({ nodes = {}, bp = {}, freeUsed = false })
			T.expect(character.buildSlot).toBe(1)
			T.expect(character.buildOther).toBeNil()
			T.expect(character.reworkNotice).toBe(false)
			T.expect(character.stats).toEqual(class.startStats)
			T.expect(character.stats == class.startStats).toBe(false) -- copied, not shared
		end
	end)

	T.it("starts with gold, the city, a cloth backpack, class gear and potions", function()
		local character = CharacterFactory.create("Mage", "Aria", ids())
		T.expect(character.gold).toBe(Config.StartingGold)
		T.expect(character.location.map).toBe(Config.StartingMap)
		T.expect(character.equipment.backpack.id).toBe("backpack_20")
		T.expect(character.equipment.backpack.n).toBe(1)
		T.expect(character.equipment.weapon.id).toBe("wand_1")
		T.expect(character.equipment.weapon.bound).toBe(true)
		T.expect(character.equipment.armor.id).toBe("armor_light_1")
		T.expect(character.inventory["1"].id).toBe("potion_hp_1")
		T.expect(character.inventory["1"].n).toBe(10)
		T.expect(character.potionBar.hp).toBe("potion_hp_1")
		T.expect(character.id).toBe("id1")
		T.expect(character.createdAt).toBe(1000)
		-- every item got its own uid
		local uids = {}
		for _, item in character.equipment do
			T.expect(uids[item.uid]).toBeNil()
			uids[item.uid] = true
		end
	end)

	T.it("schema 2 migration gives old characters their starting gear without replacing items", function()
		local old = CharacterFactory.create("Warrior", "Old", ids())
		old.equipment = { backpack = old.equipment.backpack }
		old.inventory = {
			["1"] = { uid = "keep", id = "ore_iron", rarity = 1, ilvl = 1, bonuses = {}, up = 0, bound = false, n = 3 },
		}
		old.potionBar = {}
		local data: any = AccountSchema.accountTemplate()
		data.schema = 1
		data.characters["1"] = old
		AccountSchema.migrate(data)
		T.expect(old.equipment.weapon.id).toBe("sword1h_1")
		T.expect(old.inventory["1"].uid).toBe("keep")
		T.expect(old.inventory["2"].id).toBe("potion_hp_1")
		T.expect(old.potionBar.hp).toBe("potion_hp_1")
	end)

	T.it("rejects unknown classes", function()
		T.expect(function()
			CharacterFactory.create("Bard" :: any, "Aria", ids())
		end).toThrow("unknown class")
	end)

	T.it("summarizes characters for the selection screen", function()
		local character = CharacterFactory.create("Hunter", "Kira", ids())
		character.level = 12
		T.expect(CharacterFactory.summary(character)).toEqual({
			name = "Kira",
			class = "Hunter",
			level = 12,
			map = "city",
		})
		local summaries = CharacterFactory.summaries({ ["2"] = character })
		T.expect(summaries["2"].name).toBe("Kira")
	end)

	T.it("validates slot numbers", function()
		T.expect(CharacterFactory.slotKey(1)).toBe("1")
		T.expect(CharacterFactory.slotKey(Config.MaxCharacters)).toBe(tostring(Config.MaxCharacters))
		T.expect(CharacterFactory.slotKey(0)).toBeNil()
		T.expect(CharacterFactory.slotKey(Config.MaxCharacters + 1)).toBeNil()
		T.expect(CharacterFactory.slotKey(1.5)).toBeNil()
		T.expect(CharacterFactory.slotKey("1")).toBeNil()
	end)
end)

T.describe("AccountSchema", function()
	T.it("template is at the current schema", function()
		local data = AccountSchema.accountTemplate()
		T.expect(data.schema).toBe(AccountSchema.CURRENT)
		T.expect(data.characters).toEqual({})
		T.expect(data.settings.lang).toBe("")
	end)

	T.it("templates are fresh tables every call", function()
		local a, b = AccountSchema.accountTemplate(), AccountSchema.accountTemplate()
		T.expect(a.settings == b.settings).toBe(false)
	end)

	T.it("migrate reconciles missing fields on accounts and characters", function()
		local data: any = {
			schema = AccountSchema.CURRENT,
			characters = { ["1"] = { id = "x", name = "Old", class = "Warrior", level = 7 } },
			dragonShards = 42,
		}
		AccountSchema.migrate(data)
		T.expect(data.dragonShards).toBe(42)
		T.expect(data.settings.volume).toBe(0.8)
		T.expect(data.characters["1"].level).toBe(7)
		T.expect(data.characters["1"].gold).toBe(0)
		T.expect(data.characters["1"].quests.daily.list).toEqual({})
	end)

	T.it("template keeps an empty hotbar (reconcile)", function()
		T.expect(AccountSchema.characterTemplate().hotbar).toEqual({})
		local mage = CharacterFactory.create("Mage", "Empty", ids())
		mage.hotbar = {}
		local data: any = AccountSchema.accountTemplate()
		data.characters["1"] = mage
		AccountSchema.migrate(data)
		T.expect(mage.hotbar).toEqual({})
	end)

	T.it("migrate runs pending migrations in order", function()
		local migrations = AccountSchema._migrations
		local saved = AccountSchema.CURRENT
		local order = {}
		AccountSchema.CURRENT = saved + 2
		migrations[saved + 1] = function(d)
			table.insert(order, saved + 1)
			d.marker = "a"
		end
		migrations[saved + 2] = function(d)
			table.insert(order, saved + 2)
			d.marker ..= "b"
		end
		local data: any = AccountSchema.accountTemplate()
		data.schema = saved
		local ok, err = pcall(AccountSchema.migrate, data)
		AccountSchema.CURRENT = saved
		migrations[saved + 1] = nil
		migrations[saved + 2] = nil
		assert(ok, err)
		T.expect(order).toEqual({ saved + 1, saved + 2 })
		T.expect(data.marker).toBe("ab")
		T.expect(data.schema).toBe(saved + 2)
	end)
end)

-- Saves of schema 5: a character from the factory with the new fields cleared and the old ones put back.
local function oldSave(classId: string, level: number, extra: { [string]: any }?): (any, any)
	local character: any = CharacterFactory.create(classId :: any, "Old", ids())
	character.level = level
	character.path = nil
	character.buildSlot = nil
	character.reworkNotice = nil
	character.skills = {}
	character.skillPoints = 0
	for key, value in extra or {} do
		character[key] = value
	end
	local data: any = AccountSchema.accountTemplate()
	data.schema = 5
	data.characters["1"] = character
	return data, character
end

local function newId(): string
	return "x"
end

T.describe("Migration 6 (S56)", function()
	T.it("level 1 Warrior", function()
		local data, c = oldSave("Warrior", 1, { skills = { mightyStrike = 1 }, skillPoints = 0 })
		T.expect(AccountSchema.migrate(data)).toEqual({ 6 })
		T.expect(data.schema).toBe(6)
		T.expect(c.skills).toBeNil()
		T.expect(c.skillPoints).toBeNil()
		T.expect(c.stats).toEqual((Classes.get("Warrior") :: any).startStats)
		T.expect(c.statPoints).toBe(0)
		T.expect(c.hotbar).toEqual({ ["1"] = "mightyStrike" })
		T.expect(c.path).toEqual({ nodes = {}, bp = {}, freeUsed = false })
		T.expect(c.buildSlot).toBe(1)
		T.expect(c.buildOther).toBeNil()
		T.expect(c.reworkNotice).toBe(true)
	end)

	T.it("level 20 Hunter gets every stat point back and a rebuilt bar", function()
		local start = (Classes.get("Hunter") :: any).startStats
		local stats = table.clone(start)
		stats.dex += 95
		local data, c = oldSave("Hunter", 20, {
			stats = stats,
			statPoints = 0,
			skillPoints = 3,
			hotbar = { ["1"] = "aimedShot", ["5"] = "frostTrap" },
		})
		AccountSchema.migrate(data)
		T.expect(c.stats).toEqual(start)
		T.expect(c.statPoints).toBe(95)
		T.expect(c.hotbar).toEqual({
			["1"] = "aimedShot",
			["2"] = "doubleShot",
			["3"] = "disengage",
			["4"] = "arrowRain",
			["5"] = "venomArrow",
		})
	end)

	T.it("level 100 Cleric", function()
		local data, c = oldSave("Cleric", 100)
		AccountSchema.migrate(data)
		T.expect(c.statPoints).toBe(495)
		-- S71: the Cleric has paths, so the new bar holds only the 6 base actives (path skills come with their nodes)
		T.expect(c.hotbar).toEqual({
			["1"] = "holyStrike",
			["2"] = "heal",
			["3"] = "radiance",
			["4"] = "circleOfLight",
			["5"] = "shieldOfFaith",
			["6"] = "judgement",
		})
	end)

	T.it("odd saves", function()
		local migration = AccountSchema._migrations[6]
		-- not a table
		local data: any = { characters = { ["1"] = "oops" } }
		migration(data, newId)
		T.expect(data.characters["1"]).toBe("oops")
		-- no class: counted as the template's Warrior
		local noClass: any = { level = 12, stats = { str = 1, dex = 1, int = 1, vit = 1 }, statPoints = 3 }
		migration({ characters = { ["1"] = noClass } }, newId)
		T.expect(noClass.stats).toEqual((Classes.get("Warrior") :: any).startStats)
		T.expect(noClass.statPoints).toBe(55)
		T.expect(noClass.hotbar).toEqual({
			["1"] = "mightyStrike",
			["2"] = "battleCry",
			["3"] = "charge",
			["4"] = "bladeWhirl",
		})
		-- unknown class: stats kept, empty bar, new fields
		local bard: any = { class = "Bard", level = 30, stats = { str = 9, dex = 9, int = 9, vit = 9 }, statPoints = 7 }
		migration({ characters = { ["1"] = bard } }, newId)
		T.expect(bard.stats).toEqual({ str = 9, dex = 9, int = 9, vit = 9 })
		T.expect(bard.statPoints).toBe(7)
		T.expect(bard.hotbar).toEqual({})
		T.expect(bard.path).toEqual({ nodes = {}, bp = {}, freeUsed = false })
		T.expect(bard.buildSlot).toBe(1)
		T.expect(bard.reworkNotice).toBe(true)
		-- broken levels
		local abc: any = { class = "Mage", level = "abc" }
		migration({ characters = { ["1"] = abc } }, newId)
		T.expect(abc.statPoints).toBe(0)
		local high: any = { class = "Mage", level = 250 }
		migration({ characters = { ["1"] = high } }, newId)
		T.expect(high.statPoints).toBe(495)
	end)

	T.it("is idempotent", function()
		local data, c = oldSave("Mage", 40)
		AccountSchema.migrate(data)
		local copy = TableUtil.deepCopy(c)
		AccountSchema._migrations[6](data, newId)
		T.expect(data.characters["1"]).toEqual(copy)
	end)
end)

return nil
