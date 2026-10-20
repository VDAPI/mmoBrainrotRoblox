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
	Families = require("../src/shared/Data/Families"),
	Fish = require("../src/shared/Data/Fish"),
	GatherNodes = require("../src/shared/Data/GatherNodes"),
	GuildBanners = require("../src/shared/Data/GuildBanners"), -- S159g
	GuildProgress = require("../src/shared/Data/GuildProgress"), -- S159g
	GuildSkills = require("../src/shared/Data/GuildSkills"),
	ItemTraits = require("../src/shared/Data/ItemTraits"),
	Items = require("../src/shared/Data/Items"),
	Maps = require("../src/shared/Data/Maps"),
	Market = require("../src/shared/Data/Market"),
	Monsters = require("../src/shared/Data/Monsters"),
	Npcs = require("../src/shared/Data/Npcs"),
	Paths = require("../src/shared/Data/Paths"),
	Quests = require("../src/shared/Data/Quests"),
	Rarities = require("../src/shared/Data/Rarities"),
	Recipes = require("../src/shared/Data/Recipes"),
	Skills = require("../src/shared/Data/Skills"),
	Stats = require("../src/shared/Data/Stats"),
}

-- Fields that hold localization keys. Generated item names use namePrefix/nameBase (checked by data.spec).
-- lineKey: item trait lines (S65).
local KEY_FIELDS =
	{ nameKey = true, descKey = true, greetingKey = true, titleKey = true, textKey = true, lineKey = true }

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

	-- S139 (DESIGN-18 §12): one sentence per skill for the bar tooltip and the window ("What it does"): in both
	-- languages, at most SHORT_MAX characters, at most one placeholder and only fields of the skill's `values`.
	T.it("every skill has a short description (S139)", function()
		local SHORT_MAX = 90
		local bad = {}
		for _, skill in MODULES.Skills.byId do
			local key = `skill.{skill.id}.short`
			for lang, texts in { pl = pl, en = en } do
				local text = texts[key]
				if type(text) ~= "string" then
					table.insert(bad, `{key} ({lang}): missing`)
				else
					if utf8.len(text) > SHORT_MAX then
						table.insert(bad, `{key} ({lang}): {utf8.len(text)} characters`)
					end
					local count = 0
					for name in string.gmatch(text, "{([%w_]+)}") do
						count += 1
						if skill.values[name] == nil then
							table.insert(bad, `{key} ({lang}): \{{name}\} is not a value of the skill`)
						end
					end
					if count > 1 then
						table.insert(bad, `{key} ({lang}): {count} placeholders`)
					end
				end
			end
		end
		table.sort(bad)
		T.expect(bad).toEqual({})
	end)

	-- S139: the rank table of the skills window names every value field and every effect time of a skill.
	T.it("every skill value field and effect has a label (S139)", function()
		local missing = {}
		local function check(key: string)
			if (en[key] == nil or pl[key] == nil) and not table.find(missing, key) then
				table.insert(missing, key)
			end
		end
		for _, skill in MODULES.Skills.byId do
			for field in skill.values do
				check(`skills.field.{field}`)
			end
			local effects: { any } = skill.effects or {}
			for _, effect in effects do
				check(`effect.{effect.kind}`)
			end
		end
		for _, column in { "S", "A", "K", "O", "P", "U", "C" } do
			check(`skills.role.{column}`)
		end
		for _, section in { "what", "rank", "cost", "directions", "items", "full" } do
			check(`skills.section.{section}`)
		end
		table.sort(missing)
		T.expect(missing).toEqual({})
	end)

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
		for _, boss in MODULES.Bosses.all do -- S149: the world boss too
			for _, a in boss.attacks do
				check(`boss.{boss.id}.attack.{a.id}`)
			end
		end
		table.sort(missing)
		T.expect(missing).toEqual({})
	end)
end)

return nil
