--!strict
-- Character creation, account schema and migrations.
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local CharacterFactory = require("../src/shared/Logic/CharacterFactory")
local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local T = require("./Test")

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
			T.expect(character.skillPoints).toBe(0)
			T.expect(character.stats).toEqual(class.startStats)
			T.expect(character.stats == class.startStats).toBe(false) -- copied, not shared
		end
	end)

	T.it("starts with gold, the city and a cloth backpack", function()
		local character = CharacterFactory.create("Mage", "Aria", ids())
		T.expect(character.gold).toBe(Config.StartingGold)
		T.expect(character.location.map).toBe(Config.StartingMap)
		T.expect(character.equipment.backpack.id).toBe(Config.StartingBackpackId)
		T.expect(character.equipment.backpack.n).toBe(1)
		T.expect(character.id).toBe("id1")
		T.expect(character.equipment.backpack.uid).toBe("id2")
		T.expect(character.createdAt).toBe(1000)
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

return nil
