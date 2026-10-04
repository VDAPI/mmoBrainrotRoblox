--!strict
-- Consistency of Shared/Data tables and of localization keys referenced from code.
local fs = require("@lune/fs")

local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local Maps = require("../src/shared/Data/Maps")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local STATS = { "str", "dex", "int", "vit" }

local function hasKey(key: string): boolean
	return en[key] ~= nil and pl[key] ~= nil
end

-- Every .luau file under a directory.
local function sources(dir: string, out: { string }): { string }
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			sources(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end

-- Namespaces whose string literals are localization keys.
local NAMESPACES = {
	"admin",
	"charSelect",
	"class",
	"common",
	"error",
	"hud",
	"kick",
	"map",
	"menu",
	"nameplate",
	"toast",
	"window",
	"stat",
	"statGroup",
	"breakdown",
	"source",
	"character",
	"slot",
	"item",
	"zone",
	"pvp",
	"death",
}

T.describe("Data: Classes", function()
	T.it("has the four classes in order", function()
		T.expect(Classes.order).toEqual({ "Warrior", "Hunter", "Mage", "Cleric" })
	end)

	T.it("every class is complete and localized", function()
		for _, id in Classes.order do
			local class = Classes.get(id) :: Classes.ClassDef
			T.expect(class.id).toBe(id)
			for _, key in { class.nameKey, class.roleKey, class.descKey } do
				T.expect({ key = key, ok = hasKey(key) }).toEqual({ key = key, ok = true })
			end
			for _, stat in STATS do
				T.expect((class.startStats :: any)[stat]).toBeBetween(1, 20)
			end
			for _, stat in class.mainStats do
				T.expect(table.find(STATS, stat) ~= nil).toBe(true)
			end
			T.expect(class.resource == "mana" or class.resource == "energy").toBe(true)
			T.expect(#class.weaponTypes > 0).toBe(true)
			T.expect(#class.offhandTypes > 0).toBe(true)
			T.expect(string.match(class.color, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
		end
	end)

	T.it("start stats match DESIGN §4.3", function()
		T.expect((Classes.get("Warrior") :: any).startStats).toEqual({ str = 10, dex = 5, int = 3, vit = 8 })
		T.expect((Classes.get("Hunter") :: any).startStats).toEqual({ str = 5, dex = 10, int = 3, vit = 8 })
		T.expect((Classes.get("Mage") :: any).startStats).toEqual({ str = 3, dex = 5, int = 10, vit = 8 })
		T.expect((Classes.get("Cleric") :: any).startStats).toEqual({ str = 4, dex = 4, int = 9, vit = 9 })
	end)
end)

T.describe("Data: Maps", function()
	T.it("starting map exists", function()
		T.expect(Maps.get(Config.StartingMap) ~= nil).toBe(true)
	end)

	T.it("every map is localized, sized and has a spawn inside", function()
		for id, map in Maps.byId do
			T.expect(map.id).toBe(id)
			T.expect({ key = map.nameKey, ok = hasKey(map.nameKey) }).toEqual({ key = map.nameKey, ok = true })
			T.expect(map.zone == "green" or map.zone == "yellow" or map.zone == "red").toBe(true)
			T.expect(math.abs(map.spawn.x) <= map.size.x / 2).toBe(true)
			T.expect(math.abs(map.spawn.z) <= map.size.z / 2).toBe(true)
		end
	end)

	T.it("maps are at least 3000 studs apart", function()
		local list = {}
		for _, map in Maps.byId do
			table.insert(list, map)
		end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i].offset, list[j].offset
				local dist = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
				T.expect(dist >= 3000).toBe(true)
			end
		end
	end)
end)

T.describe("Localization keys used in code", function()
	T.it("every key literal in src exists in both languages", function()
		local missing = {}
		for _, path in sources("src", {}) do
			if string.find(path, "Localization", 1, true) then
				continue
			end
			local text = fs.readFile(path)
			for literal in string.gmatch(text, '"([%w_]+%.[%w_.]+)"') do
				local namespace = string.match(literal, "^([%w_]+)%.")
				if namespace and table.find(NAMESPACES, namespace) and not hasKey(literal) then
					table.insert(missing, `{literal} ({path})`)
				end
			end
		end
		table.sort(missing)
		T.expect(missing).toEqual({})
	end)

	T.it("every NameRules error has a message", function()
		for _, reason in { "invalidUtf8", "tooShort", "tooLong", "invalidChars", "noLetter" } do
			T.expect(hasKey(`error.name.{reason}`)).toBe(true)
		end
	end)

	T.it("every HUD window has a title", function()
		for _, id in { "menu", "character", "inventory", "skills", "map", "quests", "guild", "party" } do
			T.expect({ id = id, ok = hasKey(`window.{id}.title`) }).toEqual({ id = id, ok = true })
		end
	end)
end)

return nil
