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
		T.expect(#d.skills.skills).toBe(count(SkillData.byId))
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

	T.it("gives the planner every rank with texts and parity vectors of every class and reason (S41)", function()
		for _, s in d.skills.skills do
			T.expect(#s.ranks).toBe(s.maxLevel)
			for _, rank in s.ranks do
				for _, lang in { "pl", "en" } do
					local text = rank.desc[lang]
					if text == "" or string.find(text, "{", 1, true) then
						error(`{s.id} rank {rank.rank} {lang}: "{text}"`)
					end
				end
			end
		end
		local vectors = d.skills.rules.vectors
		local classes, reasons = {}, {}
		for _, state in vectors.states do
			classes[state.class] = true
			for _, r in state.results do
				reasons[if r.ok then "ok" else r.reason] = true
			end
		end
		for _, id in { "Warrior", "Hunter", "Mage", "Cleric" } do
			T.expect(classes[id]).toBe(true)
		end
		for _, reason in { "ok", "maxLevel", "noPoints", "level", "requires" } do
			T.expect(reasons[reason]).toBe(true)
		end
		local good, bad = 0, 0
		for _, b in vectors.builds do
			if b.achievable then
				good += 1
			else
				bad += 1
			end
		end
		T.expect(good > 0 and bad > 0).toBe(true)
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

	T.it("gives the same bytes twice", function()
		local again = build()
		for path, text in result.files do
			if again.files[path] ~= text then
				error(`{path} differs between two builds`)
			end
		end
	end)
end)
