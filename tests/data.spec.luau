--!strict
-- Consistency of Shared/Data tables and of localization keys referenced from code.
local fs = require("@lune/fs")

local Classes = require("../src/shared/Data/Classes")
local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local Bonuses = require("../src/shared/Data/Bonuses")
local Bosses = require("../src/shared/Data/Bosses")
local Families = require("../src/shared/Data/Families")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemTraits = require("../src/shared/Data/ItemTraits")
local Items = require("../src/shared/Data/Items")
local LootTables = require("../src/shared/Data/LootTables")
local Maps = require("../src/shared/Data/Maps")
local Rarities = require("../src/shared/Data/Rarities")
local Sfx = require("../src/shared/Data/Sfx")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local Monsters = require("../src/shared/Data/Monsters")
local PathData = require("../src/shared/Data/Paths")
local Spawns = require("../src/shared/Data/Spawns")
local Stats = require("../src/shared/Data/Stats")
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
	"fullElixir", -- S122 (not "elixir": the resistance elixirs)
	"lure", -- S122
	"emote", -- S123
	"arena", -- S126
	"bloodmoon", -- S129
	"tourney", -- S130
	"social", -- S133
	"animlab", -- S110
	"paths",
	"title",
	"bp",
	"buildset",
	"rework",
	"dev",
	"daily",
	"quest",
	"duel",
	"pvp",
	"trade",
	"boss",
	"dungeon",
	"party",
	"loading",
	"portal",
	"tip",
	"worldmap",
	"zone",
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
	T.it("has every kind from DESIGN §15.2 (7 + 8 + 8 + 7, +5 per region in S19)", function()
		local perRegion = { 0, 0, 0, 0 }
		for _, def in Monsters.list do
			perRegion[def.region] += 1
		end
		T.expect(perRegion).toEqual({ 12, 13, 13, 12 })
	end)

	T.it("every kind is complete, localized and consistent", function()
		-- S24: the look (plan, colours) lives in Data/MonsterLooks, checked by tests/anatomy.spec.
		for _, def in Monsters.list do
			local function check(ok: boolean, what: string)
				if not ok then
					error(`{def.id}: {what}`)
				end
			end
			for _, variant in Monsters.variants do
				check(hasKey(def.nameKeys[variant]), `missing name {def.nameKeys[variant]}`)
			end
			check(def.levels.min >= 1 and def.levels.max <= 100 and def.levels.min <= def.levels.max, "levels")
			check(
				def.hpMul > 0 and def.atkMul > 0 and def.defMul > 0 and def.mresMul > 0 and def.speed > 0,
				"multipliers"
			)
			check(def.attack == "melee" or def.attack == "ranged", "attack type")
			check(def.size >= 0.4 and def.size <= 2.5, "size")
			if def.elites then
				check(def.ability ~= nil and MonsterAbilities.get(def.ability :: string) ~= nil, "Elite II ability")
			end
			check(def.lootTable ~= "", "loot table id")
		end
	end)

	T.it("every kind and boss has a family (S66, STATY 7)", function()
		local CombatData = require("../src/shared/Data/Combat")
		T.expect(Families.ids).toEqual({ "animal", "humanoid", "undead", "beast", "elemental", "dragon" })
		for _, id in Families.ids do
			local family = Families.byId[id]
			T.expect(family.nameKey).toBe("family." .. id)
			T.expect({ key = family.nameKey, ok = hasKey(family.nameKey) }).toEqual({ key = family.nameKey, ok = true })
			for defenceId in family.defences do
				for _, key in { `monsterDefence.{defenceId}.name`, `monsterDefence.{defenceId}.line` } do
					T.expect({ key = key, ok = hasKey(key) }).toEqual({ key = key, ok = true })
				end
			end
		end
		T.expect(hasKey("family.none") and hasKey("monsterDefence.none.name")).toBe(true)

		local counts: { [string]: number } = {}
		local traits: { [string]: { string } } = {}
		for _, def in Monsters.list do
			T.expect({ id = def.id, ok = Families.get(def.family) ~= nil }).toEqual({ id = def.id, ok = true })
			counts[def.family] = (counts[def.family] or 0) + 1
			if def.defence then
				local trait = assert(Families.defence(def.family, def.defence), def.id)
				traits[def.defence] = traits[def.defence] or {}
				table.insert(traits[def.defence], def.id)
				T.expect({ def.id, def.defMul, def.mresMul, def.dodge })
					.toEqual({ def.id, trait.defMul or 1, trait.mresMul or 1, trait.dodge or 0 })
			else
				T.expect({ def.id, def.mresMul, def.dodge }).toEqual({ def.id, 1, 0 })
			end
			T.expect(def.dodge >= 0 and def.dodge <= CombatData.dodgeCap).toBe(true)
		end
		T.expect(counts).toEqual({ animal = 17, humanoid = 12, undead = 6, beast = 5, elemental = 6, dragon = 4 })
		for _, list in traits do
			table.sort(list)
		end
		local function sorted(list: { string }): { string }
			table.sort(list)
			return list
		end
		T.expect(traits).toEqual({
			armored = sorted({
				"renegadeDwarf",
				"ashOrc",
				"skeletonGuard",
				"frozenKnight",
				"fireGolem",
				"magmaGolem",
				"crystalGuardian",
			}),
			warded = sorted({ "forestWraith", "specter" }),
			scaled = sorted({ "wyvern", "dragonspawn", "youngFrostDragon", "frostWyrm" }),
			agile = sorted({ "lynx", "bloodBat", "snowLeopard", "peakHarpy" }),
		})

		local bosses: { [string]: string } = {}
		for _, def in Bosses.list do
			T.expect(Families.get(def.family) ~= nil).toBe(true)
			bosses[def.id] = def.family
		end
		T.expect(bosses)
			.toEqual({ grimrok = "humanoid", morvane = "undead", azgor = "elemental", vaelgrath = "dragon" })
		T.expect(Bosses.byId.vaelgrath.mresMul).toBe(1.4)
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
					-- DESIGN §15.1 (FIX 2026-10-09: grows with the cave level). S134e: shorter (owner 2026-10-15),
					-- Elite II respawn ~4-12 min (was ~7-33 min, min >= 400 s, max <= 2000 s)
					-- S134i: an Elite II hideout's x Combat.lairElite2RespawnMul (1.5: at most 18 min)
					local mul = if spawner.lair then Combat.lairElite2RespawnMul else 1
					T.expect(spawner.respawn.min >= 240 and spawner.respawn.max <= 720 * mul).toBe(true)
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
		-- 39 base types (S18: +8 weapons) x 21 tiers + 30 materials + 24 consumables + 9 backpacks + 12 uniques
		-- + S07: 25 blessings, 4 elixirs, 4 dungeon stones; S32: 3 monster parts; 2026-10-10: 3 premium backpacks;
		-- S92: 1 monster part (cursed_bone); S122: potion_full; S134d: scroll_hunt
		-- S134j: reroll_stone (Stone of Transmutation)
		T.expect(count).toBe(39 * 21 + 30 + 24 + 9 + 12 + 25 + 4 + 4 + 3 + 3 + 1 + 1 + 1 + 1)
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
			maxCount = math.max(maxCount, rarity.bonusMax, 5)
		end
		for group, pool in Bonuses.pools do
			T.expect({ group = group, ok = #pool >= maxCount }).toEqual({ group = group, ok = true })
			for _, entry in pool do
				-- S67: a marker stands for its variants, each a known, localized line
				local ids = if Bonuses.isParam(entry) then Bonuses.variants(entry) else { entry }
				if Bonuses.isParam(entry) then
					T.expect({ entry, #ids > 0 }).toEqual({ entry, true })
				end
				for _, id in ids do
					local def = Bonuses.get(id)
					if not def then
						fail(group, `unknown bonus {id}`)
					end
					if not hasKey((def :: any).nameKey) then
						fail(group, `missing {(def :: any).nameKey}`)
					end
				end
			end
		end
		T.expect(#Bonuses.pools.legendary >= 12).toBe(true)
	end)

	T.it("named boss items use known bonuses, are Mythic and belong to a boss table", function()
		T.expect(#Items.uniques).toBe(12)
		for _, def in Items.uniques do
			for _, bonus in def.fixedBonuses or {} do
				if not Bonuses.get(bonus.stat) then
					fail(def.id, `unknown bonus {bonus.stat}`)
				end
			end
			local boss = LootTables.bosses[def.bossId or ""]
			if not boss or not table.find(boss.named, def.id) then
				fail(def.id, "not in its boss table")
			end
			if def.rarity ~= Rarities.MYTHIC then
				fail(def.id, "named boss items are Mythic")
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
			for _, id in boss.named do
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
				-- S111: Data/Sfx sound keys ("skill.default.cast") are not texts
				if namespace and table.find(NAMESPACES, namespace) and not hasKey(literal) and not Sfx.has(literal) then
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
		for _, id in { "menu", "inventory", "skills", "map", "quests", "guild", "party" } do
			T.expect({ id = id, ok = hasKey(`window.{id}.title`) }).toEqual({ id = id, ok = true })
		end
	end)
end)

T.describe("Data: item traits and bonus tiers (S62)", function()
	local OFFHAND_GROUPS = { weapon = true, shield = true, quiver = true, magicOffhand = true }

	T.it("every weapon and off-hand base has a trait", function()
		local owner: { [string]: string } = {}
		for _, base in Items.bases.list do
			if OFFHAND_GROUPS[base.bonusGroup] then
				T.expect({ base.type, ItemTraits.get(base.trait) ~= nil }).toEqual({ base.type, true })
				T.expect({ base.trait, owner[base.trait or ""] }).toEqual({ base.trait, nil })
				owner[base.trait :: string] = base.type
			else
				T.expect({ base.type, base.trait }).toEqual({ base.type, nil })
			end
		end
		T.expect(#ItemTraits.list).toBe(24)
		local categories: { [string]: boolean } = {}
		for _, def in ItemTraits.list do
			T.expect({ def.id, owner[def.id] ~= nil }).toEqual({ def.id, true })
			T.expect({ def.id, categories[def.category] }).toEqual({ def.id, nil })
			categories[def.category] = true
			T.expect(def.kind == "stat" or def.kind == "hook" or def.kind == "effect").toBe(true)
			if def.kind == "stat" then
				T.expect({ def.id, def.stat ~= nil and Stats.get(def.stat) ~= nil, def.hook })
					.toEqual({ def.id, true, nil })
			else
				T.expect({ def.id, def.stat, type(def.hook) == "string" and def.hook ~= "" })
					.toEqual({ def.id, nil, true })
			end
			T.expect(def.pvp >= 0 and def.pvp <= 1 and def.value > 0).toBe(true)
			-- S65: every trait works
			T.expect({ def.id, def.live }).toEqual({ def.id, true })
		end
		T.expect((Items.get("orb_50") :: any).trait).toBe("powerLens")
		T.expect((Items.get("unique_vaelgrath_eye") :: any).trait).toBe("powerLens")
	end)

	T.it("trait names are localized and unique", function()
		local LOWER: { [string]: string } = {
			["Ą"] = "ą",
			["Ć"] = "ć",
			["Ę"] = "ę",
			["Ł"] = "ł",
			["Ń"] = "ń",
			["Ó"] = "ó",
			["Ś"] = "ś",
			["Ź"] = "ź",
			["Ż"] = "ż",
		}
		local function words(text: string): { string }
			local lower = string.lower(text)
			for upper, small in LOWER do
				lower = string.gsub(lower, upper, small)
			end
			local out = {}
			for word in string.gmatch(lower, "[^%s%p]+") do
				table.insert(out, word)
			end
			return out
		end
		-- `inner` appears as whole words inside `outer`.
		local function contains(outer: { string }, inner: { string }): boolean
			if #inner == 0 or #inner > #outer then
				return false
			end
			for start = 1, #outer - #inner + 1 do
				local ok = true
				for i = 1, #inner do
					if outer[start + i - 1] ~= inner[i] then
						ok = false
						break
					end
				end
				if ok then
					return true
				end
			end
			return false
		end
		for _, lang in { pl, en } :: { any } do
			local others: { { key: string, words: { string } } } = {}
			for key, text in lang do
				if string.match(key, "^skill%.[^%.]+%.name$") or string.match(key, "^effect%.[^%.]+$") then
					table.insert(others, { key = key, words = words(text) })
				end
			end
			for _, path in PathData.list do
				for _, row in path.rows do
					for _, n in row.nodes do
						if n.nameKey and lang[n.nameKey] then
							table.insert(others, { key = n.nameKey, words = words(lang[n.nameKey]) })
						end
					end
				end
			end
			for _, def in ItemTraits.list do
				local name = lang[def.nameKey]
				T.expect({ def.nameKey, type(name) == "string" }).toEqual({ def.nameKey, true })
				T.expect({ def.nameKey, name == string.match(name, "^%s*(.-)%s*$") }).toEqual({ def.nameKey, true })
				T.expect({ def.lineKey, lang[def.lineKey] ~= nil }).toEqual({ def.lineKey, true })
				local mine = words(name)
				for _, other in others do
					local clash = contains(mine, other.words) or contains(other.words, mine)
					T.expect({ def.nameKey, other.key, clash }).toEqual({ def.nameKey, other.key, false })
				end
				for _, word in mine do
					local bad = string.sub(word, 1, #"przebija") == "przebija"
						or string.sub(word, 1, #"głębok") == "głębok"
					T.expect({ def.nameKey, word, bad }).toEqual({ def.nameKey, word, false })
				end
			end
		end
	end)

	-- S65: a trait name is no inflected form of a skill, effect or node name in the same language (S68 audit).
	T.it("trait names are no inflections of skill, effect or node names (S65)", function()
		local LOWER: { [string]: string } = {
			["Ą"] = "ą",
			["Ć"] = "ć",
			["Ę"] = "ę",
			["Ł"] = "ł",
			["Ń"] = "ń",
			["Ó"] = "ó",
			["Ś"] = "ś",
			["Ź"] = "ź",
			["Ż"] = "ż",
		}
		-- Known false alarms ("trait key|other key"), each with a DECYZJE line.
		local ALLOWED: { [string]: boolean } = {}
		local function chars(word: string): { string }
			local out = {}
			for _, code in utf8.codes(word) do
				table.insert(out, utf8.char(code))
			end
			return out
		end
		local function words(text: string): { { string } }
			local lower = string.lower(text)
			for upper, small in LOWER do
				lower = string.gsub(lower, upper, small)
			end
			local out = {}
			for word in string.gmatch(lower, "[^%s%p]+") do
				table.insert(out, chars(word))
			end
			return out
		end
		local function variant(a: { string }, b: { string }): boolean
			local same = #a == #b
			local prefix = 0
			for i = 1, math.min(#a, #b) do
				if a[i] ~= b[i] then
					same = false
					break
				end
				prefix = i
			end
			if same then
				return true
			end
			local shorter = math.min(#a, #b)
			return shorter >= 4 and prefix >= math.max(3, shorter - 2)
		end
		local function inflected(x: { { string } }, y: { { string } }): boolean
			if #x == #y then
				for i = 1, #x do
					if not variant(x[i], y[i]) then
						return false
					end
				end
				return #x > 0
			end
			local short, long = if #x < #y then x else y, if #x < #y then y else x
			if #short < 2 then
				return false
			end
			for start = 1, #long - #short + 1 do
				local ok = true
				for i = 1, #short do
					if not variant(short[i], long[start + i - 1]) then
						ok = false
						break
					end
				end
				if ok then
					return true
				end
			end
			return false
		end
		T.expect(inflected(words("Podwójne cięcie"), words("Podwójny Strzał"))).toBe(false)
		T.expect(inflected(words("Podwójne cięcie"), words("Podwójnego cięcia"))).toBe(true)
		T.expect(inflected(words("Łuk"), words("łuk"))).toBe(true)
		for _, lang in { pl, en } :: { any } do
			local others: { { key: string, words: { { string } } } } = {}
			for key, text in lang do
				if string.match(key, "^skill%.[^%.]+%.name$") or string.match(key, "^effect%.[^%.]+$") then
					table.insert(others, { key = key, words = words(text) })
				end
			end
			for _, path in PathData.list do
				for _, row in path.rows do
					for _, n in row.nodes do
						if n.nameKey and lang[n.nameKey] then
							table.insert(others, { key = n.nameKey, words = words(lang[n.nameKey]) })
						end
					end
				end
			end
			for _, def in ItemTraits.list do
				local mine = words(lang[def.nameKey])
				for _, other in others do
					local clash = inflected(mine, other.words) and not ALLOWED[`{def.nameKey}|{other.key}`]
					T.expect({ def.nameKey, other.key, clash }).toEqual({ def.nameKey, other.key, false })
				end
			end
		end
	end)

	-- S65: every hook a trait adds is read by code (or the trait is an on-hit effect CombatService rolls).
	T.it("every trait hook has a reader in code (S65)", function()
		local texts: { string } = {}
		for _, dir in { "src/server", "src/shared/Logic" } do
			for _, path in sources(dir, {}) do
				table.insert(texts, fs.readFile(path))
			end
		end
		local function used(hookId: string): boolean
			local literal = `"{hookId}"`
			for _, text in texts do
				if string.find(text, literal, 1, true) then
					return true
				end
			end
			return false
		end
		local combat = fs.readFile("src/server/Services/CombatService.luau")
		for _, def in ItemTraits.list do
			if def.kind ~= "stat" then
				local ok = used(def.hook :: string)
					or (def.onHit ~= nil and string.find(combat, "onHitList", 1, true) ~= nil)
				T.expect({ def.id, def.hook, ok }).toEqual({ def.id, def.hook, true })
			end
			for hookId in def.fixedHooks or {} do
				T.expect({ def.id, hookId, used(hookId) }).toEqual({ def.id, hookId, true })
			end
		end
	end)

	T.it("affinity names known lines of the type's pool", function()
		local function check(baseType: string, weights: { [string]: number }, classId: string?)
			local base = Items.bases.byType[baseType]
			T.expect({ baseType, base ~= nil }).toEqual({ baseType, true })
			local pool = Bonuses.pools[base.bonusGroup] or {}
			for line, w in weights do
				T.expect({ baseType, line, Bonuses.get(line) ~= nil, table.find(pool, line) ~= nil }).toEqual({
					baseType,
					line,
					true,
					true,
				})
				T.expect({ baseType, line, w == 0 or w >= 1 }).toEqual({ baseType, line, true })
			end
			if classId then
				T.expect({ baseType, classId, table.find(base.classes or {}, classId) ~= nil }).toEqual({
					baseType,
					classId,
					true,
				})
			end
		end
		for baseType, weights in ItemTraits.affinity do
			check(baseType, weights)
		end
		for baseType, byClass in ItemTraits.classAffinity do
			for classId, weights in byClass do
				check(baseType, weights, classId)
			end
		end
		T.expect(ItemTraits.weight("wand", "basicDmg")).toBe(3)
		T.expect(ItemTraits.weight("wand", "accuracy")).toBe(1)
		T.expect(ItemTraits.weight("mace1h", "healPower")).toBe(1)
		T.expect(ItemTraits.weight("mace1h", "healPower", "Cleric")).toBe(3)
	end)

	T.it("bonus tiers and wiki flags", function()
		local inPool: { [string]: string } = {}
		for group, pool in Bonuses.pools do
			for _, id in pool do
				-- S67: markers stand for their variants (regular lines)
				for _, variant in if Bonuses.isParam(id) then Bonuses.variants(id) else { id } do
					inPool[variant] = group
				end
			end
		end
		for id, def in Bonuses.byId do
			T.expect({ id, def.tier == "regular" or def.tier == "legendary" or def.tier == "mythic" }).toEqual({
				id,
				true,
			})
			T.expect({ id, type(def.wiki) }).toEqual({ id, "boolean" })
			local group = inPool[id]
			if group == "legendary" or group == "mythic" then
				T.expect({ id, def.tier }).toEqual({ id, group })
			elseif group then
				T.expect({ id, def.tier }).toEqual({ id, "regular" })
			end
		end
		local legacy = Bonuses.get("armorPen") :: any
		T.expect(legacy.wiki).toBe(false)
		T.expect(legacy.replacedBy).toBe("pierce")
		T.expect(inPool.armorPen).toBeNil()
		T.expect(Bonuses.classStats.armorPen).toBeNil()
	end)

	T.it("mace and shield pools have 11-14 lines per class", function()
		for _, id in { "mace1h_20", "shield_20" } do
			for _, classId in (Items.get(id) :: any).classes do
				local n = #ItemRoll.bonusPool(id, classId)
				T.expect({ id, classId, n >= 11 and n <= 14 }).toEqual({ id, classId, true })
			end
		end
	end)
end)

T.describe("Data: kind of blow (S64, STATY 6)", function()
	local Bosses = require("../src/shared/Data/Bosses")
	local SkillData = require("../src/shared/Data/Skills")
	local Skills = require("../src/shared/Logic/Skills")

	-- The rule of STATY 6 lives in Logic/Skills.deliveryRule (the skill window shows the label by it too); nil for the
	-- types that deal no damage (any value, but one is required).
	local expected = Skills.deliveryRule

	T.it("every active skill has a delivery that follows the rule", function()
		for id, skill in SkillData.byId do
			if skill.type == "passive" then
				continue
			end
			local delivery = skill.delivery
			T.expect({ id, delivery == "melee" or delivery == "ranged" }).toEqual({ id, true })
			local want = expected(skill)
			if want then
				T.expect({ id, delivery }).toEqual({ id, want })
			end
		end
	end)

	T.it("monster abilities and boss attacks have no delivery or a valid one", function()
		for id, ability in MonsterAbilities.byId do
			local d = ability.delivery
			T.expect({ id, d == nil or d == "melee" or d == "ranged" }).toEqual({ id, true })
		end
		for _, boss in Bosses.list do
			for _, attack in boss.attacks do
				local d = attack.delivery
				T.expect({ attack.id, d == nil or d == "melee" or d == "ranged" }).toEqual({ attack.id, true })
			end
		end
	end)
end)

return nil
