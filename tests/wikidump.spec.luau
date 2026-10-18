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
			["e.json"] = '{"reference":[]}', -- S82: model builds of paths
		}
		local found = Leak.scan(fake, { codes = { "WITAJ" }, ids = { 123456789 } })
		T.expect(#found).toBe(4)
		T.expect(table.find(Leak.FORBIDDEN_KEYS, "reference") ~= nil).toBe(true)
		T.expect(table.find(Leak.FORBIDDEN_KEYS, "itemWeights") ~= nil).toBe(true)
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
		-- S57: skills of unpublished or missing paths are hidden. S109 (G6.1): every quest is released, so the story,
		-- the side quests and the boss quests are all on the wiki, the contracts 1..MAX_LEVEL without a gap
		local hiddenSet = Visibility.collect()
		T.expect(#d.quests.main).toBe(#Quests.Main.list)
		T.expect(#d.quests.side).toBe(#Quests.Side.list)
		T.expect(#d.quests.bossQuests).toBe(#Quests.Boss.list)
		T.expect(#d.quests.contracts.list).toBe(Quests.Contracts.MAX_LEVEL)
		for i, c in d.quests.contracts.list do
			T.expect(c.level).toBe(i)
		end
		T.expect(d.quests.contracts.max).toBe(Quests.Contracts.MAX_LEVEL)
		T.expect(#d.quests.weekly.templates > 0).toBe(true)
		T.expect(#d.quests.weekly.bossContract.byLevel > 0).toBe(true)
		local shown = 0
		for id in SkillData.byId do
			if not hiddenSet[id] then
				shown += 1
			end
		end
		T.expect(#d.skills.skills).toBe(shown)
	end)

	-- S109 (G6): the story keeps the shape of its records (only `chapter` added), every story quest is exported (the
	-- old ones with their text and done, the new ones with their pages as the text) and the cutscenes stay off
	T.it("Wiki export: main quests keep their shape (S109)", function()
		local Locale = require("../src/shared/Util/Locale")
		local StoryProgress = require("../src/shared/Logic/StoryProgress")
		local SHAPE: { [string]: boolean } = {
			id = true,
			order = true,
			level = true,
			giver = true,
			turnIn = true,
			title = true,
			objectives = true,
			reward = true,
			chapter = true,
		}
		local OPTIONAL: { [string]: boolean } = { text = true, done = true }
		T.expect(#d.quests.main).toBe(#Quests.Main.list)
		for i, q in d.quests.main do
			T.expect(q.order).toBe(i)
			for key in SHAPE do
				T.expect(`{q.id} {key} {(q :: any)[key] ~= nil}`).toBe(`{q.id} {key} true`)
			end
			for key in q :: any do
				T.expect(`{q.id} {key} {SHAPE[key] == true or OPTIONAL[key] == true}`).toBe(`{q.id} {key} true`)
			end
		end
		local byId: { [string]: any } = {}
		for _, q in d.quests.main do
			byId[q.id] = q
		end
		-- the 32 quests of e5f2074: text and done exactly as before S109 (quest.<id>.text / .done)
		for _, id in StoryProgress.LEGACY_ORDER do
			local q = assert(byId[id], id)
			for _, lang in { "pl", "en" } do
				for _, field in { "text", "done" } do
					local key = `quest.{id}.{field}`
					local want = if Locale.has(key, lang) then Locale.T(key, nil, lang) else nil
					local got = if q[field] then q[field][lang] else nil
					T.expect(`{id}.{field}.{lang} {got == want}`).toBe(`{id}.{field}.{lang} true`)
				end
			end
		end
		-- the new ones with pages: exactly their pages p1..pN joined by a blank line (not the journal summary .text)
		local legacy: { [string]: boolean } = {}
		for _, id in StoryProgress.LEGACY_ORDER do
			legacy[id] = true
		end
		local paged = 0
		for _, quest in Quests.Main.list do
			if quest.pages and not legacy[quest.id] then
				paged += 1
				local q = assert(byId[quest.id], quest.id)
				for _, lang in { "pl", "en" } do
					local parts = {}
					for i = 1, quest.pages do
						table.insert(parts, Locale.T(`quest.{quest.id}.p{i}`, nil, lang))
					end
					local want = table.concat(parts, "\n\n")
					local got = if q.text then q.text[lang] else nil
					T.expect(`{quest.id}.{lang} {got == want}`).toBe(`{quest.id}.{lang} true`)
				end
			end
		end
		T.expect(paged > 0).toBe(true)
		-- no cutscene text (cutscene.<id>.title / .l<n>) in any wiki file nor in the search index
		local Cutscenes = require("../src/shared/Data/Cutscenes")
		local texts: { string } = {}
		-- (the scenes' titles are place and chapter names, which the wiki shows on its own)
		for _, scene in (Cutscenes :: any).list do
			for _, line in scene.lines or {} do
				local text = Locale.T(line.key, nil, "pl")
				if #text >= 24 then
					table.insert(texts, text)
				end
			end
		end
		T.expect(#texts > 20).toBe(true)
		for _, file in fs.readDir("wiki/src/data") do
			if string.match(file, "%.json$") then
				local text = fs.readFile(`wiki/src/data/{file}`)
				if string.find(text, '"cutscene.', 1, true) then
					error(`{file} names a cutscene key`, 0)
				end
				for _, line in texts do
					if string.find(text, Json.encode(line), 1, true) then
						error(`{file} holds a cutscene line: {line}`, 0)
					end
				end
			end
		end
	end)

	-- S109 (G6.3): the chapters come from Main.CHAPTERS; every story quest carries its chapter
	T.it("exports the story's chapters from Main.CHAPTERS (S109)", function()
		local chapters = d.quests.chapters
		T.expect(#chapters).toBe(#Quests.Main.CHAPTERS)
		local maps: { [string]: boolean } = {}
		for _, m in d.maps.maps do
			maps[(m :: any).id] = true
		end
		local levels: { [number]: { number } } = {}
		for _, q in d.quests.main do
			T.expect(q.chapter).toBe(Quests.Main.chapterOf(q.id))
			local list = levels[q.chapter] or {}
			levels[q.chapter] = list
			table.insert(list, q.level)
		end
		for i, c in chapters do
			T.expect(c.n).toBe(Quests.Main.CHAPTERS[i].n)
			if i > 1 then
				T.expect(c.n > chapters[i - 1].n).toBe(true)
				-- consecutive chapters share at most their border level
				T.expect(c.from >= chapters[i - 1].to).toBe(true)
			end
			local list = assert(levels[c.n], `chapter {c.n}`)
			T.expect(c.from).toBe(math.min(table.unpack(list)))
			T.expect(c.to).toBe(math.max(table.unpack(list)))
			T.expect(maps[c.map]).toBe(true)
			T.expect(c.final == true).toBe(Quests.Main.CHAPTERS[i].final == true)
		end
		T.expect(chapters[#chapters].final).toBe(true)
	end)

	-- S109 (G6.5): nothing released is hidden (HIDDEN_OK: the exceptions with their reason; none)
	T.it("hides nothing that the game released (S109)", function()
		local Areas = require("../src/shared/Data/Areas")
		local Cosmetics = require("../src/shared/Data/Cosmetics")
		local Npcs = require("../src/shared/Data/Npcs")
		local HIDDEN_OK: { [string]: string } = {}
		local all = Visibility.collect()
		local wrong = {}
		local function check(id: string?, what: string)
			if id and all[id] and not HIDDEN_OK[id] then
				table.insert(wrong, `{what} {id}`)
			end
		end
		for _, list in { Quests.Main.list, Quests.Side.list, Quests.Boss.list } do
			for _, q in list :: { any } do
				check(q.id, "quest")
				if not all[q.id] then
					check(q.giver, "giver")
					check(q.turnIn, "turnIn")
					for _, o in q.objectives do
						if o.type == "talk" or o.type == "deliver" then
							check(o.npc, "objective npc")
						end
					end
				end
			end
		end
		for _, mapId in { "meadows", "duskwood", "ashen", "frostpeak" } do
			local data = Areas.byMap[mapId] :: any
			for spotId, spot in data.npcSpots or {} do
				if spot.wiki == false then
					table.insert(wrong, `npc spot {mapId}.{spotId}`)
				end
			end
			for _, a in data.questAnchors or {} do
				if a.wiki == false then
					table.insert(wrong, `anchor {a.id}`)
				end
			end
		end
		for _, cave in Areas.caves.list do
			for _, a in (cave :: any).questAnchors or {} do
				if a.wiki == false then
					table.insert(wrong, `anchor {a.id}`)
				end
			end
		end
		for _, c in Cosmetics.list do
			local obtain = (c :: any).obtain
			if obtain and obtain.quest then
				check(c.id, "cosmetic")
			end
		end
		for _, npc in Npcs.list do
			if npc.map ~= "city" then
				check(npc.id, "npc")
			end
		end
		T.expect(wrong).toEqual({})
		-- the premium mount stays off for ever
		for _, file in fs.readDir("wiki/src/data") do
			if string.match(file, "%.json$") then
				T.expect(`{file} {string.find(fs.readFile(`wiki/src/data/{file}`), "mount_royal", 1, true) == nil}`)
					.toBe(`{file} true`)
			end
		end
	end)

	T.it("labels objectives without placeholders and keeps chances in 0..1", function()
		local function clean(label: any, where: string)
			if string.find(label.pl, "{", 1, true) or string.find(label.en, "{", 1, true) then
				error(`{where}: {label.pl}`)
			end
		end
		-- S109 (G6.4): the story, the side quests, the weekly templates and the contracts
		for _, q in d.quests.main do
			for _, o in q.objectives do
				clean(o.label, q.id)
			end
		end
		for _, q in d.quests.side do
			for _, o in q.objectives do
				clean(o.label, q.id)
			end
		end
		for _, t in d.quests.weekly.templates do
			for _, b in t.byLevel do
				clean(b.objective.label, `weekly {t.id} {b.level}`)
			end
		end
		for _, c in d.quests.contracts.list do
			clean(c.label, `contract {c.level}`)
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
			-- S134: one HP for every party (no list for 1-5 players)
			T.expect(b.byPlayers).toBeNil()
			T.expect(b.stats.hp > 0 and b.stats.dmgMax >= b.stats.dmgMin).toBe(true)
			for _, a in b.attacks do
				if not a.name then
					error(`{b.id}.{a.id}: no name`)
				end
				-- S134: a big blow to dodge and a party mechanic carry their rule text
				if (a.avoid or a.mechanic) and not a.mechanicText then
					error(`{b.id}.{a.id}: no mechanic text`)
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
		-- S82: `vectors` was back in rules (S148: moved to the planner test file), the S41 tree fields stay gone
		-- S138: rules.skillPointsByLevel is the new skill points (DESIGN-18 §14); the S56-removed field stays gone
		for _, key in { '"requires"', '"col"', '"pointsByLevel"', '"skillPoints"', '"skillPointsPerLevel' } do
			if string.find(text, key, 1, true) then
				error(`skills.json has {key}`)
			end
		end
		T.expect(d.progression.skillPointsPerLevel).toBeNil()
	end)

	T.it("exports breakpoints with their level and options A and B (S82)", function()
		local SkillLogic = require("../src/shared/Logic/Skills")
		for _, s in d.skills.skills do
			local def = SkillData.get(s.id) :: any
			if s.passiveSkill == false then
				T.expect(#s.breakpoints).toBe(2)
				for i, bp in s.breakpoints do
					T.expect(bp.rank).toBe(if i == 1 then 5 else 10)
					T.expect(bp.level).toBe(SkillLogic.rankLevel(def, bp.rank))
					T.expect(bp.text).toBeNil()
					T.expect(bp.change).toBeNil()
					T.expect({ s.id, bp.rank, bp.b ~= nil })
						.toEqual({ s.id, bp.rank, def.breakpoints[bp.rank].b ~= nil })
					for _, option in { bp.a, bp.b } do
						for _, lang in { "pl", "en" } do
							local text = option.text[lang]
							if text == "" or string.find(text, "{", 1, true) then
								error(`{s.id} breakpoint {bp.rank} {lang}: "{text}"`)
							end
						end
						T.expect(next(option.change) ~= nil).toBe(true)
					end
				end
			else
				T.expect(#s.breakpoints).toBe(0)
			end
		end
	end)

	T.it("exports world events in general, without the reward formulas (S101)", function()
		local w = d.mechanics.worldEvents
		assert(w, "mechanics.worldEvents")
		T.expect(#w.kinds).toBe(2)
		T.expect(w.kinds[1].id).toBe("invasion")
		T.expect(w.kinds[2].id).toBe("champion")
		for _, kind in w.kinds do
			for _, lang in { "pl", "en" } do
				T.expect(type(kind.name[lang]) == "string" and kind.name[lang] ~= "").toBe(true)
				T.expect(type(kind.desc[lang]) == "string" and kind.desc[lang] ~= "").toBe(true)
			end
			T.expect(kind.durationMin > 0).toBe(true)
		end
		for _, key in { "expKills", "goldKills", "chest", "scale", "hpEquivalent", "levelWindow", "retry", "first" } do
			T.expect(w[key]).toBeNil()
		end
		T.expect(w.reward).toBeNil()
		T.expect(#w.regions).toBe(4)
	end)

	T.it("exports keys, the full PvP matrix and a best area for every level (S42)", function()
		local KeybindData = require("../src/shared/Data/Keybinds")
		local PvpRules = require("../src/shared/Logic/PvpRules")
		local Areas = require("../src/shared/Data/Areas")
		-- S96: actions with wiki = false stay off the list (S97 published the mount key)
		local shownKeys = 0
		for _, action in KeybindData.actions do
			if action.wiki ~= false then
				shownKeys += 1
			end
		end
		T.expect(#d.mechanics.keybinds).toBe(shownKeys)
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
		-- S121: switched-off passes (VIP forever) stay off the wiki; no subscription, id or price reaches it
		local enabledPasses = 0
		for _, pass in Products.passes do
			enabledPasses += if (pass :: any).enabled ~= false then 1 else 0
		end
		T.expect(#d.premium.passes).toBe(enabledPasses)
		for _, pass in d.premium.passes do
			T.expect(pass.key ~= "vip").toBe(true)
		end
		local premiumText = Json.encode(d.premium)
		for _, bad in { "subscriptionId", "EXP-", "robux" } do
			T.expect({ bad, string.find(premiumText, bad, 1, true) }).toEqual({ bad })
		end
		-- S81: the New Path Scroll is sold again, so it is on the wiki (key, kind and texts only)
		local scrolls = 0
		for _, service in d.premium.shop do
			scrolls += if service.key == "scroll_skillreset" then 1 else 0
		end
		T.expect(scrolls).toBe(1)
		-- S122: one row of the Elixir of Wholeness (two packs), the two Cloak of Luring entries with name and text;
		-- no pack size, cloak seconds or price
		local elixirRows, lures = 0, {}
		for _, service in d.premium.shop do
			elixirRows += if service.item == "potion_full" then 1 else 0
			if service.key == "lure_1h" or service.key == "lure_7d" then
				T.expect({ service.key, service.name ~= nil, service.desc ~= nil }).toEqual({ service.key, true, true })
				table.insert(lures, service.key)
			end
		end
		T.expect(elixirRows).toBe(1)
		table.sort(lures)
		T.expect(lures).toEqual({ "lure_1h", "lure_7d" })
		for _, key in { '"seconds"', '"n"', '"price"' } do
			T.expect({ key, string.find(premiumText, key, 1, true) }).toEqual({ key })
		end
		local elixir: any = nil
		for _, item in d.items.items do
			if item.id == "potion_full" then
				elixir = item
			end
		end
		assert(elixir, "items.json: potion_full")
		T.expect(elixir.use and elixir.use.kind).toBe("fullElixir")
		T.expect(elixir.buyPrice).toBeNil()
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
		local hidden, hiddenPaths = Visibility.fromPaths({
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
		-- S82 (A7): the bare path id only in the set of paths, never in the shared one
		T.expect(hiddenPaths).toEqual({ secret = true })
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
		-- S134g: the rarity records carry the skill effects (were legendary / mythic lines)
		for _, r in d.rarities.rarities do
			local rarity = Rarities.get(r.id)
			T.expect({ r.key, r.legendaryEffects, r.mythicEffects })
				.toEqual({ r.key, rarity.legendaryEffects, rarity.mythicEffects })
		end
	end)

	T.it("S134g: every published item effect with its finished line, no legacy pools, named items' effects", function()
		local ItemEffectData = require("../src/shared/Data/ItemEffects")
		local hiddenIds = require("../tools/WikiData/Visibility").collect()
		local published = 0
		for _, def in ItemEffectData.list do
			-- an effect of a skill hidden on the wiki (an unpublished path) waits with it
			if def.wiki and def.replacedBy == nil and not hiddenIds[def.skill] then
				published += 1
			end
		end
		T.expect(published >= 4 * 3).toBe(true)
		T.expect(#d.items.effects).toBe(published)
		for _, e in d.items.effects do
			for _, lang in { "pl", "en" } do
				T.expect({ e.id, lang, string.find(e.line[lang], "{", 1, true) }).toEqual({ e.id, lang, nil })
			end
		end
		T.expect(d.bonuses.pools.legendary).toBeNil()
		T.expect(d.bonuses.pools.mythic).toBeNil()
		local named = 0
		for _, item in d.items.items do
			if item.fixedEffects then
				named += 1
			end
		end
		T.expect(named).toBe(12)
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

-- WIKI-GRAFIKA: item icons follow the game's picture rule (Logic/ItemIcons, Logic/ArtTiers) with every atlas sheet
-- counted as ready: own boss picture, else the nearest lower tier picture of the type (S118: mage weapons too).
T.describe("Wiki export: owner's pictures (WIKI-GRAFIKA)", function()
	local ArtTiers = require("../src/shared/Logic/ArtTiers")
	local Atlas = require("../src/shared/Data/ItemIconAtlas")

	T.it("equipment shows its own or the nearest lower tier picture, mage weapons too (S118)", function()
		local pictures, checked = 0, 0
		for _, item in d.items.items do
			local def = Items.get(item.id)
			if def and def.category == "equipment" then
				checked += 1
				local expected: string? = nil
				local own = Atlas.PNG[`uniq/{def.id}`]
				if own then
					expected = `uniq/{def.id}`
				elseif not Atlas.ICONS[`uniq/{def.id}`] then
					for _, key in ArtTiers.iconKeys(`eq/{def.type}`, def.tier) do
						local png = Atlas.PNG[key]
						if png then
							expected = key
							break
						end
					end
				end
				if expected then
					pictures += 1
					T.expect(item.iconKey).toBe(expected)
					for _, layer in item.layers do
						T.expect(layer.image > Atlas.SVG_SHEETS).toBe(true)
					end
				else
					T.expect(Atlas.PNG[item.iconKey] == nil).toBe(true)
				end
			end
		end
		T.expect(checked > 0).toBe(true)
		T.expect(pictures > 0).toBe(true)
	end)

	T.it("other items take their own picture, then the shared key's picture, else the drawn icon", function()
		for _, item in d.items.items do
			local def = Items.get(item.id)
			if def and def.category ~= "equipment" and item.iconKey then
				local group = string.match(item.iconKey, "^(%a+)/")
				local own = `{group}/{def.id}`
				if Atlas.PNG[own] then
					T.expect(item.iconKey).toBe(own)
				end
				T.expect(Atlas.PNG[item.iconKey] ~= nil or Atlas.ICONS[item.iconKey] ~= nil).toBe(true)
			end
		end
	end)
end)

-- S82 (ROZWOJ 3.5, docs/WIKI.md §5): skills with options A/B and rank variants, published paths only, the planner
-- vectors (Logic/Paths.canBuy / canRefund) and the planner test file from tests/fixtures/paths.luau.
T.describe("Wiki export: skill planner (S82)", function()
	local Bases = require("../src/shared/Data/Items/Bases")
	local GamePaths = require("../src/shared/Logic/Paths")
	local SkillLogic = require("../src/shared/Logic/Skills")
	local SkillsExport = require("../tools/WikiData/Skills")
	local TableUtil = require("../src/shared/Util/TableUtil")
	local Fixture = require("./fixtures/paths") :: any

	-- Every reason key Logic/Paths.canBuy and canRefund return in the code.
	local BUY_REASONS = {
		"paths.error.unknown",
		"paths.error.maxRank",
		"paths.error.points",
		"paths.error.level",
		"paths.error.need",
		"paths.error.choice",
		"skills.error.capstoneTaken", -- S138: one capstone per set
		"paths.error.upgrade", -- S148: the upgrade row without its capstone
	}
	local REFUND_REASONS = { "paths.error.unknown", "paths.error.noRank", "paths.error.needAbove" }

	local published: { [string]: any } = {}
	for _, path in PathData.list do
		if path.wiki ~= false then
			published[path.id] = path
		end
	end

	local function checkText(name: any, what: string)
		for _, lang in { "pl", "en" } do
			local text = name[lang]
			if type(text) ~= "string" or text == "" or string.find(text, "{", 1, true) then
				error(`{what} {lang}: "{tostring(text)}"`)
			end
		end
	end

	local function checkWeapon(weapon: any, what: string)
		for _, key in { "main", "offhand" } do
			for _, kind in weapon[key] or {} do
				T.expect({ what, kind, Bases.byType[kind] ~= nil }).toEqual({ what, kind, true })
			end
		end
	end

	T.it("exports skills of published paths only and every published path in full", function()
		for _, s in d.skills.skills do
			T.expect({ s.id, s.path == nil or published[s.path] ~= nil }).toEqual({ s.id, true })
		end
		T.expect(#d.skills.paths).toBe(count(published))
		for _, path in d.skills.paths do
			T.expect(published[path.id] ~= nil).toBe(true)
			T.expect(#path.rows).toBe(#GamePaths.rowsFor(path.class))
			checkText(path.name, path.id)
			checkText(path.desc, path.id)
			T.expect(path.weapon).toBeNil() -- S148: a direction has no weapon (DESIGN-18 §7)
			for _, row in path.rows do
				for _, node in row.nodes do
					local ranks = if node.kind == "skill" then 1 else node.maxRank
					T.expect({ node.id, #node.ranks }).toEqual({ node.id, ranks })
					checkText(node.name, node.id)
					for _, rank in node.ranks do
						checkText(rank.desc, node.id)
					end
					if node.weapon then
						checkWeapon(node.weapon, node.id)
					end
				end
			end
		end
	end)

	T.it("has rank variants exactly where a skill has option B, with the numbers B changes", function()
		-- the numbers an option changes: values, add of a field in values, mul of cost or cooldown
		local function numeric(option: any, skill: any): any
			if option == nil then
				return {}
			end
			local add = {}
			for key, amount in option.add or {} do
				if skill.values[key] ~= nil then
					add[key] = amount
				end
			end
			local mul = {}
			for _, key in { "cost", "cooldown" } do
				if option.mul and option.mul[key] then
					mul[key] = option.mul[key]
				end
			end
			return { values = option.values or {}, add = add, mul = mul }
		end
		local checked = 0
		for _, s in d.skills.skills do
			local def = SkillData.get(s.id) :: any
			local b5 = def.breakpoints and def.breakpoints[5] and def.breakpoints[5].b ~= nil
			local b10 = def.breakpoints and def.breakpoints[10] and def.breakpoints[10].b ~= nil
			for r, rank in s.ranks do
				local want = {}
				if b5 and r >= 5 then
					want.ba = true
				end
				if b10 and r >= 10 then
					want.ab = true
				end
				if want.ba and want.ab then
					want.bb = true
				end
				local have = {}
				for key in rank.variants or {} do
					have[key] = true
				end
				T.expect({ s.id, r, have }).toEqual({ s.id, r, want })
			end
			for _, at in SkillLogic.BREAKPOINT_LEVELS do
				local pair = def.breakpoints and def.breakpoints[at]
				if pair and pair.b and not TableUtil.deepEqual(numeric(pair.a, def), numeric(pair.b, def)) then
					local rank = s.ranks[at]
					local variant = rank.variants[if at == 5 then "ba" else "ab"]
					local same = variant.cost == rank.cost
						and variant.cooldown == rank.cooldown
						and TableUtil.deepEqual(variant.values, rank.values)
					if same then
						error(`{s.id} option B at rank {at} changes numbers, but its variant equals A`)
					end
					checked += 1
				end
			end
		end
		T.expect(checked > 0).toBe(true)
	end)

	T.it("leaves unpublished paths, their nodes, titles and skills out; NPC, shop and quest stay", function()
		-- Bare path ids are not searched as text: "healer" is also an NPC, a shop and a quest, "fortune" and
		-- "guardian" are blessing lines. Unique ids (nodes <pathId>_<name>, titles path_<pathId>) are.
		for _, path in PathData.list do
			if path.wiki == false then
				for _, entry in d.skills.paths do
					T.expect(entry.id ~= path.id).toBe(true)
				end
				for _, s in d.skills.skills do
					T.expect({ s.id, s.path ~= path.id }).toEqual({ s.id, true })
				end
				for _, e in d.search.entries do
					if e.type == "skill" then
						local def = SkillData.get(e.id) :: any
						T.expect({ e.id, def == nil or def.path ~= path.id }).toEqual({ e.id, true })
					end
				end
				for file, text in result.files do
					T.expect({ file, string.find(text, `path_{path.id}`, 1, true) }).toEqual({ file, nil })
					for _, row in path.rows do
						for _, node in row.nodes do
							local found = string.find(text, "%f[%w_]" .. node.id .. "%f[^%w_]")
							T.expect({ file, node.id, found }).toEqual({ file, node.id, nil })
						end
					end
				end
			end
		end
		-- A7: the hidden path "healer" (S71) must not hide the NPC, the shop and the main quest "healer"
		local function has(list: { any }, id: string): boolean
			for _, entry in list do
				if entry.id == id then
					return true
				end
			end
			return false
		end
		T.expect(has(d.npcs.npcs, "healer")).toBe(true)
		T.expect(has(d.shops.shops, "healer")).toBe(true)
		T.expect(has(d.quests.main, "healer")).toBe(true)
	end)

	T.it("writes the planner test file outside the data folder, valid and up to date", function()
		local path = WikiDump.PLANNER_FIXTURE_PATH
		local text = result.files[path]
		T.expect(text ~= nil).toBe(true)
		T.expect(string.sub(path, 1, #WikiDump.DATA_DIR + 1) == WikiDump.DATA_DIR .. "/").toBe(false)
		-- a change of Logic/Paths or of the test paths without `npm run data` fails the check
		T.expect(fs.isFile(path)).toBe(true)
		-- S138 let the file go stale until the owner's wiki refresh (PLANNER_STALE_OK); S148 refreshed it
		local PLANNER_STALE_OK = false
		if fs.readFile(path) ~= text and not PLANNER_STALE_OK then
			error(`{path} is stale: run npm run data in wiki/ (or lune run tools/wikidump.luau)`)
		end
		local fixture = Clean.clean(SkillsExport.plannerFixture())
		T.expect(Schema.check(fixture, SkillsExport.PlannerFixture)).toEqual({})
		-- the test paths never reach wiki/src/data
		for file, body in result.files do
			if string.sub(file, 1, #WikiDump.DATA_DIR + 1) == WikiDump.DATA_DIR .. "/" then
				for _, def in Fixture.paths do
					T.expect({ file, string.find(body, `"{def.id}"`, 1, true) }).toEqual({ file, nil })
					for _, row in def.rows do
						for _, node in row.nodes do
							T.expect({ file, string.find(body, `"{node.id}"`, 1, true) }).toEqual({ file, nil })
						end
					end
				end
			end
		end
		-- every reason key of canBuy and canRefund, achievable and unreachable builds
		local buy: { [string]: boolean } = {}
		local refund: { [string]: boolean } = {}
		for _, state in fixture.vectors.states do
			for _, r in state.results do
				buy[r.reason or "ok"] = true
				refund[r.refundReason or "ok"] = true
			end
		end
		for _, key in BUY_REASONS do
			T.expect({ key, buy[key] }).toEqual({ key, true })
		end
		for _, key in REFUND_REASONS do
			T.expect({ key, refund[key] }).toEqual({ key, true })
		end
		T.expect(buy.ok and refund.ok).toBe(true)
		local reached: { [boolean]: boolean } = {}
		for _, b in fixture.vectors.builds do
			reached[b.achievable] = true
		end
		T.expect(reached[true] and reached[false]).toBe(true)
		-- pathAchievable on hand-made targets
		local api = GamePaths.withSource(Fixture.source)
		local achievable = SkillsExport.pathAchievable
		T.expect(achievable(api, Fixture.paths, "Mage", 1, {})).toBe(true)
		T.expect(achievable(api, Fixture.paths, "Mage", 10, { fxStorm_focus = 3 })).toBe(true)
		T.expect(achievable(api, Fixture.paths, "Mage", 10, { fxStorm_focus = 4 })).toBe(false)
		T.expect(achievable(api, Fixture.paths, "Mage", 20, { fxStorm_surge = 1 })).toBe(false)
		-- S138: row 3 of any direction with its points, no main path
		local deep = { fxRune_fxGlyph = 1, fxRune_mend = 3, fxRune_r3a = 1 }
		T.expect(achievable(api, Fixture.paths, "Mage", 20, deep)).toBe(true)
		T.expect(achievable(api, Fixture.paths, "Mage", 19, deep)).toBe(false)
	end)

	T.it("has the planner rules, the pools in code order and no vectors in skills.json", function()
		-- S148: the path vectors of the published directions live in the planner test file (`game`)
		T.expect(d.skills.rules.vectors).toBeNil()
		local fixture = Clean.clean(SkillsExport.plannerFixture())
		for _, path in published do
			local found = false
			for _, state in fixture.game.states do
				if state.class == path.class then
					found = true
				end
			end
			T.expect({ path.id, found }).toEqual({ path.id, true })
		end
		for _, state in fixture.game.states do
			for _, r in state.results do
				local _, owner = GamePaths.findNode(r.node)
				T.expect({ r.node, owner == nil or published[(owner :: any).id] ~= nil }).toEqual({ r.node, true })
			end
		end
		-- S148: skill-point vectors with every reason key of SkillPoints.canBuy, and reservations both ways
		local reasons: { [string]: boolean } = {}
		for _, state in fixture.skills.states do
			for _, r in state.results do
				reasons[r.reason or "ok"] = true
			end
		end
		for _, key in
			{
				"ok",
				"error.badRequest",
				"skills.error.pool",
				"skills.error.locked",
				"skills.error.limit",
				"skills.error.points",
			}
		do
			T.expect({ key, reasons[key] }).toEqual({ key, true })
		end
		local applied: { [boolean]: boolean } = {}
		for _, p in fixture.skills.plans do
			applied[p.ok] = true
		end
		T.expect(applied[true] and applied[false]).toBe(true)
		-- S138: no main path; directions, one capstone, skill points and the pools
		T.expect(d.skills.rules.mainPathLevel).toBeNil()
		T.expect(d.skills.rules.capstonesMax).toBe(PathData.CAPSTONES_MAX)
		T.expect(d.skills.rules.mainMinPoints).toBe(PathData.MAIN_MIN_POINTS)
		T.expect(d.skills.rules.teamFullPoints).toBe(PathData.TEAM_FULL_POINTS)
		T.expect(d.skills.rules.freeRespecLevel).toBe(require("../src/shared/Data/Progression").freeRespecLevel)
		T.expect(d.skills.rules.barSlots).toBe(SkillData.HOTBAR_SLOTS)
		T.expect(#d.skills.rules.skillPointsByLevel).toBe(Config.MaxLevel)
		for level, points in d.skills.rules.skillPointsByLevel do
			T.expect({ level, points }).toEqual({ level, GamePaths.skillPointsAt(level) })
		end
		local PoolData = require("../src/shared/Data/SkillPools")
		T.expect(#d.skills.rules.ladder).toBe(#PoolData.LADDER + #PoolData.COMMON_LADDER)
		local rungIndex: { [string]: number } = {}
		for i, rung in d.skills.rules.ladder do
			rungIndex[rung.code] = i
		end
		local skillById: { [string]: any } = {}
		for _, skill in d.skills.skills do
			skillById[skill.id] = skill
		end
		local poolCount = 0
		for _, entry in d.skills.classPools do
			local own = PoolData.get(entry.class) :: any
			T.expect(#entry.pools).toBe(#own.pools)
			poolCount += #entry.pools
			for _, pool in entry.pools do
				checkText(pool.name, `pool {pool.id}`)
				T.expect(pool.plan).toBeNil()
				T.expect(#pool.skills > 0).toBe(true)
				-- the code order: base skills by ladder rung (school, then common), direction skills after them
				local last, sawPath = 0, false
				for _, id in pool.skills do
					local skill = skillById[id]
					T.expect({ id, skill ~= nil }).toEqual({ id, true })
					if skill.path then
						sawPath = true
					else
						T.expect({ id, sawPath }).toEqual({ id, false })
						local at = rungIndex[skill.role]
						T.expect({ id, at ~= nil and at > last }).toEqual({ id, true })
						last = at
					end
				end
			end
		end
		T.expect(poolCount > 0).toBe(true)
		local withPool = 0
		for _, skill in d.skills.skills do
			local def = SkillData.get(skill.id) :: any
			T.expect({ skill.id, skill.pool, skill.role }).toEqual({ skill.id, def.pool, def.role })
			checkText(skill.short, `{skill.id} short`)
			withPool += if skill.pool then 1 else 0
		end
		T.expect(withPool > 0).toBe(true)
		T.expect(#d.skills.rules.pathPointsByLevel).toBe(Config.MaxLevel)
		for level, points in d.skills.rules.pathPointsByLevel do
			T.expect({ level, points }).toEqual({ level, GamePaths.pointsAt(level) })
		end
		T.expect(#d.skills.rules.rows).toBe(#PathData.ROWS)
		T.expect(d.skills.rules.dipRows).toBe(PathData.DIP_ROWS)
	end)
end)

T.describe("Wiki export: mounts (S97)", function()
	local MountConfig = require("../src/shared/Config").Mount

	T.it("publishes the stable arc with its horse and mount skin", function()
		local byId: { [string]: any } = {}
		for _, q in d.quests.side do
			byId[q.id] = q
		end
		for _, id in { "side_stable_harness", "side_stable_stallion", "side_stable_ride" } do
			T.expect(byId[id] ~= nil).toBe(true)
		end
		T.expect(byId.side_stable_ride.reward.mount).toBe("mount_horse")
		T.expect(byId.side_stable_ride.reward.cosmetic).toBe("mountskin_meadow")
		local vaelgrath = nil
		for _, q in d.quests.main do
			if q.id == "vaelgrath" then
				vaelgrath = q
			end
		end
		T.expect(vaelgrath and vaelgrath.reward.cosmetic).toBe("mountskin_dragonslayer")
	end)

	T.it("exports the mounts without the premium one and without any price", function()
		T.expect(d.mounts ~= nil).toBe(true)
		local ids: { [string]: boolean } = {}
		for _, m in d.mounts.mounts do
			ids[m.id] = true
			T.expect(m.source ~= "premium").toBe(true)
		end
		for _, id in { "mount_horse", "mount_grimrok", "mount_morvane", "mount_azgor", "mount_vaelgrath" } do
			T.expect(ids[id]).toBe(true)
		end
		T.expect(ids.mount_royal).toBe(nil)
		T.expect(#d.mounts.levels).toBe(MountConfig.maxLevel)
		T.expect(d.mounts.levels[1].gold).toBe(nil)
		T.expect(d.mounts.levels[2].gold ~= nil).toBe(true)
		local text = result.files["wiki/src/data/mounts.json"]
		for _, key in { '"productId"', '"robux"', '"enabled"', '"price"', '"product"', "mount_royal" } do
			T.expect(string.find(text, key, 1, true)).toBe(nil)
		end
		local SOURCES = { shop = true, boss = true, quest = true }
		T.expect(#d.mounts.skins >= 8).toBe(true)
		for _, s in d.mounts.skins do
			T.expect(SOURCES[s.source]).toBe(true)
		end
	end)

	T.it("S123: new kinds in cosmetics.json without prices or new fields; no packs, offer or bought titles", function()
		local kinds: { [string]: boolean } = {}
		for _, k in d.cosmetics.kinds do
			kinds[k.id] = true
		end
		for _, kind in { "dye", "frame", "chatframe", "title", "emote", "levelup" } do
			T.expect({ kind, kinds[kind] }).toEqual({ kind, true })
		end
		local ids: { [string]: boolean } = {}
		for _, c in d.cosmetics.cosmetics do
			ids[c.id] = true
			for _, key in { "price", "weekly", "free", "obtain", "frame", "chat", "emote", "levelup", "dye", "title" } do
				T.expect({ c.id, key, c[key] }).toEqual({ c.id, key, nil })
			end
		end
		T.expect(ids.frame_royal and ids.emote_wave and ids.title_pilgrim and ids.dye_gold).toBe(true)
		for _, title in d.titles.titles do
			for _, id in { "pilgrim", "lorekeeper", "oathbound", "nightwatch", "highborn" } do
				T.expect(title.id ~= id).toBe(true)
			end
		end
		for name, file in d do
			local text = Json.encode(file)
			-- S131: premium.json lists the starter packs' contents (B2), never their price or product id
			local bads = if name == "premium"
				then { '"productId"', '"robux"' }
				else { "starter_wanderer", "starter_hero", '"productId"', '"robux"' }
			for _, bad in bads do
				T.expect({ name, bad, string.find(text, bad, 1, true) }).toEqual({ name, bad })
			end
		end
	end)

	T.it("lists the mount skins in cosmetics.json without new fields", function()
		local kinds: { [string]: boolean } = {}
		for _, k in d.cosmetics.kinds do
			kinds[k.id] = true
		end
		T.expect(kinds.mountskin).toBe(true)
		for _, c in d.cosmetics.cosmetics do
			T.expect(c.skin).toBe(nil)
			T.expect(c.obtain).toBe(nil)
			T.expect(c.price).toBe(nil)
		end
	end)
end)

T.describe("Wiki export: rankings (S125)", function()
	T.it("writes the placeholder: no rows, names in both languages, no ids or forbidden keys", function()
		local r = d.rankings
		T.expect(r ~= nil).toBe(true)
		T.expect(r.available).toBe(false)
		T.expect(r.updatedAt).toBe(0)
		T.expect(#r.boards > 0).toBe(true)
		local ids = {}
		for _, b in r.boards do
			ids[b.id] = true
			T.expect({ b.id, #b.rows }).toEqual({ b.id, 0 })
			T.expect({ b.id, type(b.name.pl), type(b.name.en) }).toEqual({ b.id, "string", "string" })
		end
		for _, id in { "level", "level_mage", "exp_week_1", "exp_week_4", "guild", "hof_cleric" } do
			T.expect({ id, ids[id] }).toEqual({ id, true })
		end
		local text = result.files["wiki/src/data/rankings.json"]
		for _, key in { "userId", "charId", "key", "shards", "productId", "robux" } do
			T.expect({ key, string.find(text, `"{key}"`, 1, true) == nil }).toEqual({ key, true })
		end
	end)
end)

-- S131 (DESIGN-17 §9, B8): the shop, the VIP, the arena and the PvP events on the wiki: no ids, prices, amounts of
-- Dragon Shards or service keys; the arena data equal to the game data.
T.describe("Wiki export: shop, VIP, arena, events (S131)", function()
	local Arena = require("../src/shared/Data/Arena")
	local Products = require("../src/shared/Data/Products")
	local ScheduledEvents = require("../src/shared/Data/ScheduledEvents")

	local FORBIDDEN = {
		"robux",
		"productId",
		"passId",
		"subscriptionId",
		"price",
		"shards",
		"dailyShards",
		"shardReward",
		"RespawnNowCost",
		"enabled",
		"jobId",
		"placeId",
	}
	local SERVICE_KEYS = { "ArenaQueue_", "ArenaMatch_", "BloodMoon_", "Tourney_", "paid_" }

	local function fileText(name: string): string
		return result.files[`wiki/src/data/{name}.json`] or ""
	end

	T.it("1. no forbidden key in arena, premium, titles, cosmetics, mechanics; enabled passes only", function()
		for _, name in { "arena", "premium", "titles", "cosmetics", "mechanics" } do
			local text = fileText(name)
			T.expect({ name, #text > 0 }).toEqual({ name, true })
			for _, key in FORBIDDEN do
				T.expect({ name, key, string.find(text, `"{key}":`, 1, true) }).toEqual({ name, key, nil })
			end
		end
		T.expect(string.find(fileText("premium"), "mount_royal", 1, true)).toBeNil()
		for _, pass in Products.passes do
			if (pass :: any).enabled == false then
				for _, p in d.premium.passes do
					T.expect({ pass.key, p.key ~= pass.key }).toEqual({ pass.key, true })
				end
			end
		end
	end)

	T.it("2. the arena brackets, tiers and shop follow Data/Arena", function()
		T.expect(d.arena ~= nil).toBe(true)
		T.expect(#d.arena.brackets).toBe(#Arena.BRACKETS)
		for i, b in Arena.BRACKETS do
			T.expect(d.arena.brackets[i]).toEqual({ min = b.min, max = b.max })
		end
		for i = 2, #d.arena.tiers do
			T.expect(d.arena.tiers[i].min > d.arena.tiers[i - 1].min).toBe(true)
		end
		for _, e in d.arena.shop do
			T.expect({ e.id, e.tokens > 0 }).toEqual({ e.id, true })
			if e.item then
				local def = Items.get(e.item) :: any
				T.expect({ e.item, def.category ~= "equipment" and def.bonusGroup == nil }).toEqual({ e.item, true })
			end
		end
		-- no Locale placeholder left in a name (the season titles use their plain name)
		T.expect(string.match(fileText("arena"), "{%a+}")).toBeNil()
	end)

	T.it("3. the event slots follow Data/ScheduledEvents", function()
		local moon = ScheduledEvents.get("bloodmoon") :: any
		T.expect(#d.arena.bloodMoon.slots).toBe(#moon.slots)
		for i, s in moon.slots do
			T.expect(d.arena.bloodMoon.slots[i]).toEqual({ weekday = s.weekday, hour = s.hour, minute = s.minute })
		end
		local cup = (ScheduledEvents.get("tourney") :: any).slots[1]
		T.expect(d.arena.tourney.slot).toEqual({ weekday = cup.weekday, hour = cup.hour, minute = cup.minute })
	end)

	T.it("4. the VIP names its daily shards without an amount, the elixir lists the series' blocks", function()
		T.expect(d.premium.vip.dailyCurrency).toBe(true)
		for key in d.premium.vip do
			T.expect({ key, string.find(string.lower(key), "shard", 1, true) }).toEqual({ key, nil })
		end
		local blocked: { [string]: boolean } = {}
		for _, name in d.premium.items.fullElixir.blocked do
			blocked[name.pl] = true
		end
		local Locale = require("../src/shared/Util/Locale")
		for _, reason in { "arena", "duel", "dungeon", "bloodMoon", "tourney" } do
			local text = Locale.T(`fullElixir.block.{reason}`, nil, "pl")
			T.expect({ reason, blocked[text] == true }).toEqual({ reason, true })
		end
	end)

	T.it("5. no file holds a store key of the cross-server services", function()
		for path, text in result.files do
			for _, word in SERVICE_KEYS do
				T.expect({ path, word, string.find(text, word, 1, true) }).toEqual({ path, word, nil })
			end
		end
	end)

	T.it("6. the published titles and arena cosmetics carry no purchase", function()
		for _, t in d.titles.titles do
			T.expect({ t.id, t.req.kind ~= "cosmetic" and t.req.kind ~= "pass" }).toEqual({ t.id, true })
		end
		local ids: { [string]: boolean } = {}
		for _, c in d.cosmetics.cosmetics do
			ids[c.id] = true
		end
		for _, id in { "frame_gladiator", "aura_gladiator", "frame_bloodmoon", "aura_champion", "frame_tourney" } do
			T.expect({ id, ids[id] == true }).toEqual({ id, true })
		end
	end)
end)

-- S132 (DESIGN-17 §9a): the class looks on the wiki, without catalog ids, models or prices.
T.describe("Wiki export: class looks (S132)", function()
	T.it("exports four class looks with colours and garments, the creator counts and the skins", function()
		local looks = d.classlooks
		T.expect(looks ~= nil).toBe(true)
		T.expect(#looks.classes).toBe(4)
		for _, look in looks.classes do
			T.expect({ look.class, #look.garments >= 3, #look.outfits }).toEqual({ look.class, true, 5 })
			T.expect(type(look.colors.main)).toBe("string")
			T.expect(type(look.name.pl) == "string" and type(look.name.en) == "string").toBe(true)
		end
		T.expect(looks.faces).toBe(8)
		T.expect(looks.hairs).toBe(12)
		T.expect(#looks.skins).toBe(10)
		local classOf: { [string]: string } = {}
		for _, c in d.cosmetics.cosmetics do
			if c.class then
				classOf[c.id] = c.class
			end
		end
		for _, look in looks.classes do
			for _, outfit in look.outfits do
				T.expect({ outfit.id, classOf[outfit.id] }).toEqual({ outfit.id, look.class })
			end
		end
	end)

	T.it("leaks no catalog id, model, clothing, price or source of the game", function()
		for name, text in result.files do
			if string.find(name, "classlooks.json", 1, true) or string.find(name, "cosmetics.json", 1, true) then
				for _, key in { "catalog", "asset", "shirt", "pants", "price", "obtain", "productId", "robux" } do
					T.expect({ name, key, string.find(text, `"{key}"%s*:`) }).toEqual({ name, key, nil })
				end
			end
		end
	end)
end)
