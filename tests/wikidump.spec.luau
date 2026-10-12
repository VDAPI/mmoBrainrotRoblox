--!strict
-- Wiki data exporter (S34, docs/WIKI.md §1, §5): no leaks, every name in both languages, references that resolve,
-- counts equal to the game data, Monte Carlo matching the tables, clean / JSON rules, hidden entities, determinism.
-- Uses a quick build (500 rolls); the full export is `lune run tools/wikidump.luau`.

local fs = require("@lune/fs")

local Clean = require("../tools/WikiData/Clean")
local Codes = require("../src/shared/Data/Codes")
local Config = require("../src/shared/Config")
local Items = require("../src/shared/Data/Items")
local Json = require("../tools/WikiData/Json")
local Leak = require("../tools/WikiData/Leak")
local Monsters = require("../src/shared/Data/Monsters")
local PathData = require("../src/shared/Data/Paths")
local Quests = require("../src/shared/Data/Quests")
local Schema = require("../tools/WikiData/Schema")
local SkillData = require("../src/shared/Data/Skills")
local T = require("./Test")
local Visibility = require("../tools/WikiData/Visibility")
local WikiDump = require("../tools/WikiData")

local ROLLS = 500

local function build(): any
	return WikiDump.build({
		rolls = ROLLS,
		exists = fs.isFile,
		themeText = fs.readFile("src/client/UI/Theme.luau"),
		readText = function(path: string): string?
			return if fs.isFile(path) then fs.readFile(path) else nil
		end,
		git = { commit = "test", date = "test" },
	})
end

local result = build()
local d = result.data

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function secrets(): { codes: { string }, ids: { number } }
	local codes = {}
	for _, def in (Codes :: any).list do
		table.insert(codes, def.code)
	end
	return { codes = codes, ids = (Config :: any).AdminUserIds or {} }
end

T.describe("Wiki export: leaks", function()
	T.it("contains no reward code, administrator id or forbidden key", function()
		local found = Leak.scan(result.files, secrets())
		if #found > 0 then
			error(table.concat(found, "\n"))
		end
	end)

	T.it("the scanner catches a planted code, id and key", function()
		local fake = {
			["a.json"] = '{"name":"Use code WITAJ now"}',
			["b.json"] = '{"owner":123456789}',
			["c.json"] = '{"price":5}',
			["d.json"] = '{"name":"WITAJNIK 1234567890"}',
		}
		local found = Leak.scan(fake, { codes = { "WITAJ" }, ids = { 123456789 } })
		T.expect(#found).toBe(3)
	end)

	T.it("rejects a key outside the schema", function()
		local errors = Schema.check({ id = "x", secret = 1 }, Schema.rec("Fixture", { id = "string" }))
		T.expect(#errors).toBe(1)
		T.expect(string.find(errors[1], "secret") ~= nil).toBe(true)
	end)
end)

local function checkName(name: any, what: string)
	if type(name) ~= "table" or type(name.pl) ~= "string" or type(name.en) ~= "string" then
		error(`{what}: no name`)
	end
	if
		name.pl == ""
		or name.en == ""
		or string.find(name.pl, "^[%w_]+%.[%w_.]+$")
		or string.find(name.en, "^[%w_]+%.[%w_.]+$")
	then
		error(`{what}: name is a key or empty ({name.pl} / {name.en})`)
	end
end

T.describe("Wiki export: names", function()
	T.it("every entity has a name in Polish and English", function()
		for _, item in d.items.items do
			checkName(item.name, item.id)
		end
		for _, m in d.monsters.monsters do
			checkName(m.name, m.id)
			for v, variant in m.variants do
				checkName(variant.name, `{m.id}:{v}`)
			end
		end
		for _, list in
			{
				d.bosses.bosses,
				d.maps.maps,
				d.areas.areas,
				d.caves.caves,
				d.npcs.npcs,
				d.skills.skills,
				d.classes.classes,
				d.rarities.rarities,
				d.elements.elements,
				d.bonuses.bonuses,
				d.blessings.blessings,
				d.titles.titles,
				d.cosmetics.cosmetics,
			}
		do
			for _, entry in list do
				checkName(entry.name, entry.id)
			end
		end
		for _, q in d.quests.main do
			checkName(q.title, q.id)
		end
		for _, q in d.quests.side do
			checkName(q.title, q.id)
		end
	end)

	T.it("has no missing texts", function()
		T.expect(#result.missing).toBe(0)
	end)
end)

T.describe("Wiki export: consistency", function()
	local itemIds: { [string]: boolean } = {}
	for _, item in d.items.items do
		itemIds[item.id] = true
	end
	local function item(id: string, where: string)
		if not itemIds[id] then
			error(`{where}: unknown item {id}`)
		end
	end

	T.it("points only at existing items", function()
		for _, m in d.monsters.monsters do
			for v, variant in m.variants do
				for _, entry in variant.loot.items do
					item(entry.id, `{m.id}:{v} loot`)
				end
				for _, entry in variant.loot.materials do
					item(entry.id, `{m.id}:{v} materials`)
				end
			end
		end
		for _, b in d.bosses.bosses do
			for _, entry in b.loot.items do
				item(entry.id, `{b.id} loot`)
			end
			for _, id in b.loot.named do
				item(id, `{b.id} named`)
			end
		end
		for _, shop in d.shops.shops do
			for _, e in shop.entries do
				item(e.item, `shop {shop.id}`)
			end
		end
		for _, row in d.crafting.rows do
			for _, e in row.items do
				item(e.item, "crafting")
			end
		end
		for _, q in d.quests.main do
			for _, r in q.reward.items do
				item(r.id, `quest {q.id}`)
			end
		end
		for _, r in d.recipes.recipes do
			item(r.result.id, `recipe {r.id}`)
		end
	end)

	T.it("every monster lives in an area or a cave", function()
		for _, m in d.monsters.monsters do
			local places = 0
			for _, variant in m.variants do
				places += #variant.spawns
			end
			if places == 0 then
				error(`{m.id} has no spawn`)
			end
		end
	end)

	T.it("has as many records as the game data", function()
		T.expect(#d.items.items).toBe(count(Items.byId))
		T.expect(#d.monsters.monsters).toBe(#Monsters.list)
		T.expect(#d.quests.main).toBe(#Quests.Main.list)
		T.expect(#d.quests.side).toBe(#Quests.Side.list)
		-- S57: skills of unpublished or missing paths are hidden
		local hiddenSet = Visibility.collect()
		local shown = 0
		for id in SkillData.byId do
			if not hiddenSet[id] then
				shown += 1
			end
		end
		T.expect(#d.skills.skills).toBe(shown)
	end)

	T.it("labels objectives without placeholders and keeps chances in 0..1", function()
		for _, q in d.quests.main do
			for _, o in q.objectives do
				if string.find(o.label.pl, "{", 1, true) or string.find(o.label.en, "{", 1, true) then
					error(`{q.id}: {o.label.pl}`)
				end
			end
		end
		for _, m in d.monsters.monsters do
			for _, variant in m.variants do
				for _, entry in variant.loot.items do
					T.expect(entry.chance >= 0 and entry.chance <= 1).toBe(true)
				end
			end
		end
		for _, step in d.upgrade.steps do
			T.expect(step.chance >= 0 and step.chance <= 1).toBe(true)
		end
	end)

	T.it("matches the tables in the Monte Carlo (3 sigma)", function()
		local checked = 0
		for _, m in d.monsters.monsters do
			for _, variant in m.variants do
				local loot = variant.loot
				local n = loot.rolls
				local p = loot.itemChance
				local sigma = math.sqrt(p * (1 - p) / n)
				if math.abs(loot.itemMeasured - p) > 3 * sigma + 1e-9 then
					error(`{m.id}: item chance {p}, measured {loot.itemMeasured}`)
				end
				local seen: { [string]: number } = {}
				for _, mat in loot.materials do
					seen[mat.id] = (seen[mat.id] or 0) + 1
				end
				for _, mat in loot.materials do
					if seen[mat.id] == 1 then
						local q = mat.chance
						local s = math.sqrt(q * (1 - q) / n)
						if math.abs(mat.measured - q) > 3 * s + 1e-9 then
							error(`{m.id}: {mat.id} chance {q}, measured {mat.measured}`)
						end
						checked += 1
					end
				end
			end
		end
		T.expect(checked > 50).toBe(true)
	end)

	T.it("gives every Elite II ability damage, loot groups in 0..1 and bosses their script numbers (S39)", function()
		for _, m in d.monsters.monsters do
			local e2 = m.variants.elite2
			if m.ability and e2 then
				for _, row in e2.levels do
					if not (row.abilityMin and row.abilityMin > 0 and row.abilityMax >= row.abilityMin) then
						error(`{m.id}: no ability damage on level {row.level}`)
					end
				end
			end
			for variant, info in m.variants do
				local loot = info.loot
				local sum = 0
				for slot, g in loot.groups do
					if g.chance < 0 or g.chance > 1 then
						error(`{m.id} {variant} {slot}: chance {g.chance}`)
					end
					sum += g.chance
				end
				-- One item per kill: the groups are disjoint, so they add up to the item chance.
				if loot.itemMin == 1 and loot.itemMax == 1 and not loot.itemExtra then
					local p = loot.itemChance
					local sigma = math.sqrt(p * (1 - p) / loot.rolls)
					if math.abs(sum - p) > 3 * sigma + 1e-3 then
						error(`{m.id} {variant}: groups {sum}, item chance {p}`)
					end
				end
			end
		end
		local consts: { [string]: any } = {}
		for _, b in d.bosses.bosses do
			consts[b.id] = b.scriptConsts
			for i = 2, #b.byPlayers do
				T.expect(b.byPlayers[i].hp > b.byPlayers[i - 1].hp).toBe(true)
			end
			for _, a in b.attacks do
				if not a.name then
					error(`{b.id}.{a.id}: no name`)
				end
			end
		end
		T.expect(consts.azgor.SAFE_START).toBe(50)
		T.expect(consts.azgor.SHRINK_SECONDS ~= nil).toBe(true)
		T.expect(consts.vaelgrath.WARM_RADIUS ~= nil).toBe(true)
		T.expect(consts.vaelgrath.FLIGHT_SECONDS ~= nil).toBe(true)
	end)

	T.it("shows the sample records of the plan", function()
		local wolf
		for _, m in d.monsters.monsters do
			if m.id == "wolf" then
				wolf = m
			end
		end
		local level5
		for _, row in wolf.variants.normal.levels do
			if row.level == 5 then
				level5 = row
			end
		end
		T.expect(level5.hp > 0 and level5.dmgMin <= level5.dmgMax and level5.exp > 0).toBe(true)
		T.expect(#wolf.variants.normal.spawns > 0).toBe(true)
		local sword, cleaver
		for _, i in d.items.items do
			if i.id == "sword1h_30" then
				sword = i
			elseif i.id == "unique_grimrok_cleaver" then
				cleaver = i
			end
		end
		T.expect(#sword.stats.common.weapon.dmg).toBe(10)
		T.expect(#sword.sources.monsters > 0).toBe(true)
		T.expect(cleaver.fixedBonuses ~= nil).toBe(true)
		T.expect(cleaver.sources.bosses[1].boss).toBe("grimrok")
		local whirl
		for _, s in d.skills.skills do
			if s.id == "bladeWhirl" then
				whirl = s
			end
		end
		T.expect(whirl.ranks[1].desc.pl ~= whirl.ranks[10].desc.pl).toBe(true)
	end)

	T.it("ranks from the level (S56)", function()
		local SkillLogic = require("../src/shared/Logic/Skills")
		local cap = d.skills.rules.ranks.capLevel
		for _, s in d.skills.skills do
			T.expect(#s.ranks).toBe(s.maxLevel)
			T.expect(#s.rankLevels).toBe(s.maxLevel)
			for r = 1, s.maxLevel do
				local level = SkillLogic.rankLevel(SkillData.get(s.id) :: any, r)
				T.expect(s.rankLevels[r]).toBe(level)
				T.expect(s.ranks[r].requiredLevel).toBe(level)
			end
			T.expect(s.rankLevels[s.maxLevel] <= cap).toBe(true)
			for _, rank in s.ranks do
				for _, lang in { "pl", "en" } do
					local text = rank.desc[lang]
					if text == "" or string.find(text, "{", 1, true) then
						error(`{s.id} rank {rank.rank} {lang}: "{text}"`)
					end
				end
			end
		end
		T.expect(d.skills.rules.ranks).toEqual({ step = 4, capLevel = 95 })
		local text = Json.encode(d.skills)
		for _, key in { '"vectors"', '"requires"', '"col"', '"pointsByLevel"', '"skillPoints' } do
			if string.find(text, key, 1, true) then
				error(`skills.json has {key}`)
			end
		end
		T.expect(d.progression.skillPointsPerLevel).toBeNil()
	end)

	T.it("exports breakpoints as rank + option A (S55)", function()
		for _, s in d.skills.skills do
			if s.passiveSkill == false then
				T.expect(#s.breakpoints).toBe(2)
				for i, bp in s.breakpoints do
					T.expect(bp.rank).toBe(if i == 1 then 5 else 10)
					T.expect(bp.text).toBeNil()
					T.expect(bp.change).toBeNil()
					for _, lang in { "pl", "en" } do
						local text = bp.a.text[lang]
						if text == "" or string.find(text, "{", 1, true) then
							error(`{s.id} breakpoint {bp.rank} {lang}: "{text}"`)
						end
					end
					T.expect(next(bp.a.change) ~= nil).toBe(true)
				end
			else
				T.expect(#s.breakpoints).toBe(0)
			end
		end
	end)

	T.it("exports keys, the full PvP matrix and a best area for every level (S42)", function()
		local KeybindData = require("../src/shared/Data/Keybinds")
		local PvpRules = require("../src/shared/Logic/PvpRules")
		local Areas = require("../src/shared/Data/Areas")
		T.expect(#d.mechanics.keybinds).toBe(#KeybindData.actions)
		for _, k in d.mechanics.keybinds do
			for _, lang in { "pl", "en" } do
				if string.find(k.name[lang], "%)%s*$") then
					error(`{k.id} {lang}: "{k.name[lang]}"`)
				end
			end
		end
		T.expect(#d.mechanics.pvp.rows).toBe(3 * 4 * 2 * 2)
		for _, r in d.mechanics.pvp.rows do
			local ok = PvpRules.canAttack({ pvpEnabled = r.attackerPvp }, { pvpEnabled = r.targetPvp }, {
				zone = r.zone,
				sameParty = r.relation == "party",
				sameGuild = r.relation == "guild" or r.relation == "guildOpen",
				guildProtection = r.relation ~= "guildOpen",
			})
			T.expect(r.allowed).toBe(ok)
		end
		T.expect(#d.progression.bestArea).toBe(Config.MaxLevel)
		for _, b in d.progression.bestArea do
			local area = Areas.areaById(b.area)
			assert(area, `bestArea {b.level}: unknown area {b.area}`)
			local data = Areas.byMap[b.map]
			local found = false
			for _, a in data.areas do
				found = found or a.id == b.area
			end
			T.expect(found).toBe(true)
		end
		for _, key in { "robux", "productId", "passId", "price", "shards", "RespawnNowCost" } do
			T.expect(string.find(Json.encode(d.mechanics), `"{key}"`, 1, true)).toBe(nil)
		end
	end)

	T.it("exports guild permissions, passes, shop services and city buildings without prices (S43)", function()
		local Guild = require("../src/shared/Logic/Guild")
		local Products = require("../src/shared/Data/Products")
		local Town = require("../src/shared/Data/Town")
		for _, rank in d.mechanics.guild.ranks do
			for action, allowed in rank.can do
				T.expect(allowed).toBe(Guild.can(rank.id, action))
			end
		end
		T.expect(#d.premium.passes).toBe(#Products.passes)
		-- S81: the New Path Scroll is sold again, so it is on the wiki (key, kind and texts only)
		local scrolls = 0
		for _, service in d.premium.shop do
			scrolls += if service.key == "scroll_skillreset" then 1 else 0
		end
		T.expect(scrolls).toBe(1)
		-- the instant respawn product never reaches the wiki (areaProfiles use a "respawn" key, so only premium.json)
		T.expect(string.find(Json.encode(d.premium), 'respawn"', 1, true)).toBe(nil)
		for _, npc in d.npcs.npcs do
			if npc.building then
				local spot = Town.npcSpot(npc.id)
				assert(spot and (spot :: any).at == npc.building, `{npc.id}: building {npc.building}`)
			end
		end
		for _, file in { "cosmetics", "mechanics", "premium" } do
			local text = Json.encode(d[file])
			for _, key in { "robux", "productId", "passId", "price", "shards", "shardPacks", "RespawnNowCost" } do
				if string.find(text, `"{key}"`, 1, true) then
					error(`{file}.json has the key {key}`)
				end
			end
		end
	end)
end)

T.describe("Wiki export: building blocks", function()
	T.it("cleans data: sparse keys to text, functions dropped, mixed tables and cycles rejected", function()
		local out = Clean.clean({ [1] = "a", [3] = "c" })
		T.expect(out["1"]).toBe("a")
		T.expect(out["3"]).toBe("c")
		local f = Clean.clean({ x = 1, f = function() end })
		T.expect(f.f).toBeNil()
		T.expect(function()
			local mixed: { [any]: any } = { x = 3 }
			mixed[1], mixed[2] = 1, 2
			Clean.clean(mixed)
		end).toThrow("mixed")
		local cyclic: any = {}
		cyclic.self = cyclic
		T.expect(function()
			Clean.clean(cyclic)
		end).toThrow("cycle")
	end)

	T.it("writes JSON with sorted keys, whole numbers and no -0", function()
		T.expect(Json.encode({ b = 1, a = 2.5 })).toBe('{"a":2.5,"b":1}')
		T.expect(Json.encode({ -0.0, 1 / 3, 10 })).toBe("[0,0.3333,10]")
		T.expect(Json.encode(Json.object({}))).toBe("{}")
		T.expect(function()
			Json.encode({ 0 / 0 })
		end).toThrow("finite")
	end)

	T.it("leaves hidden entities and their references out", function()
		local hidden = Visibility.fromLists({
			{ { id = "a" }, { id = "b", hidden = true } },
			{ x = { id = "c", wiki = false }, y = { id = "d", wiki = true } },
		})
		T.expect(hidden).toEqual({ b = true, c = true })
		local loot = Clean.dropRefs({ { id = "a" }, { id = "b" }, { id = "c" } }, hidden, "id")
		T.expect(#loot).toBe(1)
		T.expect(Clean.dropRefs({ "a", "c" }, hidden)).toEqual({ "a" })
	end)

	T.it("hides unpublished paths, their nodes, title and skills (S57)", function()
		local hidden = Visibility.fromPaths({
			{
				id = "secret",
				titleId = "path_secret",
				wiki = false,
				rows = { { nodes = { { id = "secret_a" } } }, { nodes = { { id = "secret_b" } } } },
			},
			{ id = "open", titleId = "path_open", rows = { { nodes = { { id = "open_a" } } } } },
		}, {
			inSecret = { id = "inSecret", path = "secret" },
			orphan = { id = "orphan", path = "gone" },
			base = { id = "base" },
			inOpen = { id = "inOpen", path = "open" },
		})
		T.expect(hidden).toEqual({
			path_secret = true,
			secret_a = true,
			secret_b = true,
			inSecret = true,
			orphan = true,
		})
		-- game data: nothing hidden is exported (empty sets until a class has paths)
		local all = Visibility.collect()
		for _, skill in d.skills.skills do
			T.expect(all[skill.id]).toBeNil()
		end
		for _, title in d.titles.titles do
			T.expect(all[title.id]).toBeNil()
		end
		-- S71: ids of hidden skills, nodes and titles never appear quoted anywhere in the output; a path id only where
		-- it would mean the path (a record's "path" field), because "healer" / "fortune" are also NPC, shop, quest and
		-- blessing ids.
		local function leaks(needle: string, what: string, skip: string?)
			for file, text in result.files do
				if (skip == nil or string.find(file, skip, 1, true) == nil) and string.find(text, needle, 1, true) then
					error(`{what} leaks into {file}`)
				end
			end
		end
		-- S75: a hidden skill id that is also a monster ability id (Warrior's "cleave") is the ability in monsters.json
		local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
		for id in all do
			leaks(`"{id}"`, id, if MonsterAbilities.byId[id] then "monsters.json" else nil)
		end
		for _, path in PathData.list do
			if path.wiki == false then
				leaks(`"path":"{path.id}"`, path.id)
				leaks(`"path": "{path.id}"`, path.id)
				for _, row in path.rows do
					for _, node in row.nodes do
						leaks(`"{node.id}"`, node.id)
					end
				end
			end
		end
	end)

	T.it("gives the same bytes twice", function()
		local again = build()
		for path, text in result.files do
			if again.files[path] ~= text then
				error(`{path} differs between two builds`)
			end
		end
	end)
end)

-- S68: line frequency per base type and class, affinity, traits, families, mythic lines, allowlist.
T.describe("Wiki export: items and monsters (S68)", function()
	local Bonuses = require("../src/shared/Data/Bonuses")
	local Families = require("../src/shared/Data/Families")
	local ItemRoll = require("../src/shared/Logic/ItemRoll")
	local ItemTraits = require("../src/shared/Data/ItemTraits")
	local Rarities = require("../src/shared/Data/Rarities")

	local function sampleId(baseType: string): string?
		local best: any = nil
		for _, def in Items.byId do
			if def.type == baseType and def.tier and not def.fixedBonuses then
				if
					not best
					or math.abs(def.tier - 50) < math.abs(best.tier - 50)
					or (math.abs(def.tier - 50) == math.abs(best.tier - 50) and def.id < best.id)
				then
					best = def
				end
			end
		end
		return if best then best.id else nil
	end

	T.it("line frequency per base type and class sums to the line count", function()
		local frequency = d.bonuses.frequency
		for baseType, base in d.items.bases do
			local id = base.bonusGroup and sampleId(baseType)
			if id then
				for _, classId in base.poolClasses do
					local byRarity = frequency[baseType] and frequency[baseType][classId]
					T.expect({ baseType, classId, byRarity ~= nil }).toEqual({ baseType, classId, true })
					local pool = #ItemRoll.bonusPool(id, classId)
					for _, r in Rarities.list do
						if r.bonusMax > 0 then
							local sum = 0
							for line, share in byRarity[r.key] or {} do
								local def = Bonuses.get(line)
								T.expect({ line, def == nil or def.param == nil }).toEqual({ line, true })
								if Bonuses.isParam(line) or (def and def.tier == "regular") then
									sum += share
								end
							end
							local expected = 0
							for k = r.bonusMin, r.bonusMax do
								expected += math.min(k, pool)
							end
							expected /= r.bonusMax - r.bonusMin + 1
							T.expect({ baseType, classId, r.key, math.abs(sum - expected) <= 0.15 }).toEqual({
								baseType,
								classId,
								r.key,
								true,
							})
						end
					end
				end
			end
		end
		T.expect((frequency.sword1h.Warrior.heroic["@vsFamily"] or 0) > 0).toBe(true)
	end)

	T.it("affinity weights the pool: 0 never rolls, x3 rolls more often", function()
		local frequency = d.bonuses.frequency
		for baseType, base in d.items.bases do
			for classId, weights in base.affinity or {} do
				for line, w in weights do
					if w == 0 then
						for _, shares in frequency[baseType][classId] do
							T.expect({ baseType, classId, line, shares[line] or 0 })
								.toEqual({ baseType, classId, line, 0 })
						end
					end
				end
			end
		end
		T.expect(d.items.bases.axe2h.affinity.Warrior.woundChance).toBe(3)
		local axe = frequency.axe2h.Warrior.heroic.woundChance or 0
		local sword = frequency.sword1h.Warrior.heroic.woundChance or 0
		T.expect(axe - sword >= 0.1).toBe(true)
	end)

	T.it("exports every live trait with ten lines per rarity", function()
		local live = 0
		for _, def in ItemTraits.list do
			if def.live then
				live += 1
				local info = d.items.traits[def.id]
				T.expect({ def.id, info ~= nil }).toEqual({ def.id, true })
				checkName(info.name, def.id)
				checkName(info.info, `{def.id}.info`)
				checkName(info.pvp, `{def.id}.pvp`)
				for _, r in d.rarities.rarities do
					local lines = info.line[r.key]
					T.expect({ def.id, r.key, #lines }).toEqual({ def.id, r.key, 10 })
					for _, line in lines do
						T.expect(string.find(line.pl .. line.en, "{", 1, true)).toBeNil()
					end
				end
			end
		end
		T.expect(count(d.items.traits)).toBe(live)
		for baseType, base in d.items.bases do
			if base.trait then
				T.expect({ baseType, d.items.traits[base.trait] ~= nil }).toEqual({ baseType, true })
			end
		end
	end)

	T.it("monsters carry their game family and the families have names", function()
		T.expect(count(d.monsters.families)).toBe(#Families.ids)
		for _, id in Families.ids do
			checkName(d.monsters.families[id].name, `family.{id}`)
		end
		for _, m in d.monsters.monsters do
			T.expect({ m.id, m.family }).toEqual({ m.id, (Monsters.get(m.id) :: any).family })
		end
		for _, r in d.rarities.rarities do
			T.expect({ r.key, r.mythicLines }).toEqual({ r.key, Rarities.get(r.id).mythicLines })
		end
	end)

	T.it("keeps weights, node hooks and cap references out and lists four markers", function()
		for _, path in { "bonuses.json", "items.json", "monsters.json" } do
			local text: string? = nil
			for file, body in result.files do
				if string.sub(file, -#path) == path then
					text = body
				end
			end
			T.expect({ path, text ~= nil }).toEqual({ path, true })
			for _, key in { "itemWeights", "nodeHooks", "capRef", "reference", "statPlan" } do
				T.expect({ path, key, string.find(text :: string, `"{key}"%s*:`) }).toEqual({ path, key, nil })
			end
		end
		T.expect(count(d.bonuses.params)).toBe(4)
	end)
end)
