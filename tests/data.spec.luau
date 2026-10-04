--!strict
-- Consistency of Shared/Data tables and of localization keys referenced from code.
local fs = require("@lune/fs")

local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local Bonuses = require("../src/shared/Data/Bonuses")
local Items = require("../src/shared/Data/Items")
local LootTables = require("../src/shared/Data/LootTables")
local Maps = require("../src/shared/Data/Maps")
local Rarities = require("../src/shared/Data/Rarities")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local Monsters = require("../src/shared/Data/Monsters")
local Spawns = require("../src/shared/Data/Spawns")
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
	"alchemy",
	"blessing",
	"dungeon",
	"elixir",
	"fish",
	"gather",
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
	"monster",
	"monsterPlate",
	"variant",
	"combat",
	"rarity",
	"category",
	"bonus",
	"inventory",
	"tooltip",
	"equip",
	"loot",
	"reveal",
	"potion",
	"itemTier",
	"itemBase",
	"skill",
	"skills",
	"effect",
	"cast",
	"npc",
	"heal",
	"shop",
	"backpacks",
	"deposit",
	"smith",
	"announce",
	"scroll",
	"teleport",
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

T.describe("Data: Monsters", function()
	T.it("has every kind from DESIGN §15.2 (7 + 8 + 8 + 7)", function()
		local perRegion = { 0, 0, 0, 0 }
		for _, def in Monsters.list do
			perRegion[def.region] += 1
		end
		T.expect(perRegion).toEqual({ 7, 8, 8, 7 })
	end)

	T.it("every kind is complete, localized and consistent", function()
		local shapes = { quadruped = true, humanoid = true, spider = true, golem = true, flyer = true, dragon = true }
		for _, def in Monsters.list do
			local function check(ok: boolean, what: string)
				if not ok then
					error(`{def.id}: {what}`)
				end
			end
			for _, variant in Monsters.variants do
				check(hasKey(def.nameKeys[variant]), `missing name {def.nameKeys[variant]}`)
			end
			check(shapes[def.shape] == true, "unknown shape")
			check(def.levels.min >= 1 and def.levels.max <= 100 and def.levels.min <= def.levels.max, "levels")
			check(def.hpMul > 0 and def.atkMul > 0 and def.defMul > 0 and def.speed > 0, "multipliers")
			check(def.attack == "melee" or def.attack == "ranged", "attack type")
			check(string.match(def.colors.primary, "^#%x%x%x%x%x%x$") ~= nil, "primary colour")
			check(string.match(def.colors.secondary, "^#%x%x%x%x%x%x$") ~= nil, "secondary colour")
			if def.elites then
				check(def.ability ~= nil and MonsterAbilities.get(def.ability :: string) ~= nil, "Elite II ability")
			end
			check(def.lootTable ~= "", "loot table id")
		end
	end)

	T.it("abilities are well formed", function()
		for id, ability in MonsterAbilities.byId do
			T.expect(ability.id).toBe(id)
			T.expect(ability.windup > 0 and ability.cooldown > ability.windup).toBe(true)
			if ability.shape == "line" then
				T.expect((ability.length or 0) > 0 and (ability.width or 0) > 0).toBe(true)
			else
				T.expect((ability.radius or 0) > 0).toBe(true)
			end
		end
	end)

	T.it("spawners reference valid monsters and maps", function()
		for mapId, list in Spawns.byMap do
			T.expect(Maps.get(mapId) ~= nil).toBe(true)
			local ids = {}
			for _, spawner in list do
				local def = Monsters.get(spawner.monster)
				if not def then
					error(`spawner {spawner.id}: unknown monster {spawner.monster}`)
				end
				T.expect(ids[spawner.id]).toBeNil()
				ids[spawner.id] = true
				T.expect(spawner.count >= 1 and spawner.radius >= 0).toBe(true)
				T.expect(spawner.respawn.min > 0 and spawner.respawn.min <= spawner.respawn.max).toBe(true)
				if spawner.variant ~= "normal" then
					T.expect(def.elites).toBe(true)
				end
				if spawner.variant == "elite2" then
					-- DESIGN §15.1: Elite II respawn 10–20 min
					T.expect(spawner.respawn.min >= 600 and spawner.respawn.max <= 1200).toBe(true)
				end
			end
		end
	end)
end)

T.describe("Data: Items", function()
	local function fail(id: string, what: string)
		error(`{id}: {what}`)
	end

	T.it("every item has a localized name, icon and valid fields", function()
		local count = 0
		for id, def in Items.byId do
			count += 1
			if def.id ~= id then
				fail(id, "id mismatch")
			end
			if def.nameKey then
				if not hasKey(def.nameKey) then
					fail(id, `missing {def.nameKey}`)
				end
			else
				local prefix = `{def.namePrefix}.{def.gender}`
				if not hasKey(prefix) or not hasKey(def.nameBase or "") then
					fail(id, `missing generated name {prefix} / {def.nameBase}`)
				end
			end
			if def.descKey and not hasKey(def.descKey) then
				fail(id, `missing {def.descKey}`)
			end
			if string.match(def.icon.color, "^#%x%x%x%x%x%x$") == nil or def.icon.glyph == "" then
				fail(id, "icon")
			end
			if def.price < 0 or def.maxStack < 1 or (def.stackable and def.maxStack ~= 999) then
				fail(id, "price/stack")
			end
			if def.category == "equipment" then
				if not def.slot or (not def.weapon and not def.base) then
					fail(id, "equipment without slot or stats")
				end
				if not def.fixedBonuses and not Bonuses.pools[def.bonusGroup or ""] then
					fail(id, "unknown bonus group")
				end
				for _, classId in def.classes or {} do
					if not Classes.get(classId) then
						fail(id, `unknown class {classId}`)
					end
				end
			end
		end
		-- 31 base types x 21 tiers + 30 materials + 24 consumables + 9 backpacks + 12 uniques
		-- + S07: 25 blessings, 4 elixirs, 4 dungeon stones
		T.expect(count).toBe(31 * 21 + 30 + 24 + 9 + 12 + 25 + 4 + 4)
	end)

	T.it("class weapon types exist as item bases", function()
		for _, classId in Classes.order do
			local class = Classes.get(classId) :: Classes.ClassDef
			for _, weaponType in class.weaponTypes do
				T.expect({ type = weaponType, ok = Items.bases.byType[weaponType] ~= nil })
					.toEqual({ type = weaponType, ok = true })
			end
			for _, offhand in class.offhandTypes do
				T.expect({ type = offhand, ok = Items.bases.byType[offhand] ~= nil })
					.toEqual({ type = offhand, ok = true })
			end
		end
	end)

	T.it("bonus pools are large enough and localized", function()
		local maxCount = 0
		for _, rarity in Rarities.list do
			maxCount = math.max(maxCount, rarity.bonusCount)
		end
		for group, pool in Bonuses.pools do
			T.expect({ group = group, ok = #pool >= maxCount }).toEqual({ group = group, ok = true })
			for _, id in pool do
				local def = Bonuses.get(id)
				if not def then
					fail(group, `unknown bonus {id}`)
				end
				if not hasKey((def :: any).nameKey) then
					fail(group, `missing {(def :: any).nameKey}`)
				end
			end
		end
		T.expect(#Bonuses.pools.legendary >= 12).toBe(true)
	end)

	T.it("uniques use known bonuses and belong to a boss table", function()
		T.expect(#Items.uniques).toBe(12)
		for _, def in Items.uniques do
			for _, bonus in def.fixedBonuses or {} do
				if not Bonuses.get(bonus.stat) then
					fail(def.id, `unknown bonus {bonus.stat}`)
				end
			end
			local boss = LootTables.bosses[def.bossId or ""]
			if not boss or not table.find(boss.uniques, def.id) then
				fail(def.id, "not in its boss table")
			end
		end
	end)

	T.it("loot tables reference existing items", function()
		for _, def in Monsters.list do
			local tableDef = LootTables.get(def.lootTable)
			if not tableDef then
				fail(def.id, "no loot table")
			end
			for _, drop in (tableDef :: any).materials do
				T.expect(Items.get(drop.id) ~= nil).toBe(true)
			end
			for _, list in (tableDef :: any).variantMaterials do
				for _, drop in list do
					T.expect(Items.get(drop.id) ~= nil).toBe(true)
				end
			end
		end
		for bossId, boss in LootTables.bosses do
			for _, id in boss.uniques do
				T.expect(Items.get(id) ~= nil).toBe(true)
			end
			for _, drop in boss.materials do
				if not Items.get(drop.id) then
					fail(bossId, `unknown material {drop.id}`)
				end
			end
		end
	end)

	T.it("starting gear exists and fits the class", function()
		for classId, list in Items.startingGear do
			for _, id in list do
				local def = Items.get(id)
				if not def then
					fail(classId, `unknown starting item {id}`)
				end
				T.expect(def.classes == nil or table.find(def.classes :: any, classId) ~= nil).toBe(true)
			end
		end
		T.expect(Items.get(Items.startingBackpack) ~= nil).toBe(true)
		T.expect(Items.get(Items.startingPotions.id) ~= nil).toBe(true)
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
