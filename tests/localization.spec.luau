--!strict
-- Every "*Key" field in the data tables (items, monsters, skills, recipes, quests, NPCs, maps, bosses,
-- blessings, cosmetics, guild skills, ...) must exist in Polish and English (S14 quality pass).

local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

local MODULES: { [string]: any } = {
	Blessings = require("../src/shared/Data/Blessings"),
	Bosses = require("../src/shared/Data/Bosses"),
	Classes = require("../src/shared/Data/Classes"),
	Cosmetics = require("../src/shared/Data/Cosmetics"),
	Fish = require("../src/shared/Data/Fish"),
	GatherNodes = require("../src/shared/Data/GatherNodes"),
	GuildSkills = require("../src/shared/Data/GuildSkills"),
	Items = require("../src/shared/Data/Items"),
	Maps = require("../src/shared/Data/Maps"),
	Market = require("../src/shared/Data/Market"),
	Monsters = require("../src/shared/Data/Monsters"),
	Npcs = require("../src/shared/Data/Npcs"),
	Quests = require("../src/shared/Data/Quests"),
	Rarities = require("../src/shared/Data/Rarities"),
	Recipes = require("../src/shared/Data/Recipes"),
	Skills = require("../src/shared/Data/Skills"),
	Stats = require("../src/shared/Data/Stats"),
}

-- Fields that hold localization keys. Generated item names use namePrefix/nameBase (checked by data.spec).
local KEY_FIELDS = { nameKey = true, descKey = true, greetingKey = true, titleKey = true, textKey = true }

local function walk(value: any, seen: { [any]: boolean }, found: { [string]: boolean })
	if type(value) ~= "table" or seen[value] then
		return
	end
	seen[value] = true
	for k, v in value do
		if type(k) == "string" and KEY_FIELDS[k] and type(v) == "string" then
			found[v] = true
		else
			walk(v, seen, found)
		end
	end
end

T.describe("Localization of data tables", function()
	for name, module in MODULES do
		T.it(`{name}: every *Key exists in pl and en`, function()
			local found: { [string]: boolean } = {}
			walk(module, {}, found)
			local missing = {}
			for key in found do
				if en[key] == nil or pl[key] == nil then
					table.insert(missing, key)
				end
			end
			table.sort(missing)
			T.expect(missing).toEqual({})
		end)
	end

	T.it("every Elite II ability and boss attack has a name (S39)", function()
		local Abilities = require("../src/shared/Data/MonsterAbilities")
		local missing = {}
		local function check(key: string)
			if en[key] == nil or pl[key] == nil then
				table.insert(missing, key)
			end
		end
		for id in (Abilities :: any).byId do
			check(`ability.{id}.name`)
		end
		for _, boss in MODULES.Bosses.list do
			for _, a in boss.attacks do
				check(`boss.{boss.id}.attack.{a.id}`)
			end
		end
		table.sort(missing)
		T.expect(missing).toEqual({})
	end)
end)

return nil
