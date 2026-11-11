--!strict
-- Text caps (owner 2026-11-10: "bardzo dużo napisów, niektóre rzeczy zasłaniają inne, zbyt szczegółowe opisy"): every
-- pl and en text fits the cap of the surface the code shows it on (Logic/TextCaps, the numbers of docs/UI-ZASADY.md
-- §2). The map from keys to surfaces comes from the code (tests/TextScan.luau); the texts that break a cap today are
-- listed per package of the UI plan in tests/fixtures/textcaps, lists that only shrink.
--   T1 every mapped key, pl and en, fits each of its surfaces (TextCaps.check after the sample values), or is listed
--   T2 no em dash in any text; no control words or "(K)" key hints on toasts, banners, alerts, prompts and the HUD;
--      ratchets in the same lists, hard for every key once the lists are empty; the A and B texts keep the
--      glossary's words for a quest and the backpack
--   T3 the lists: a listed key that now passes, got longer or belongs to another package fails
--   T4 every literal key at a toast, banner, alert, prompt or card site exists and has its surface; the scan read
--      every file to its end and found today's message calls
--   T6 the spec's own negative case: a 61-character toast fails
-- T5 (the content budgets of the item tooltip, the skill bar tooltip and dialogue pages) lives in tooltip.spec,
-- tiptext.spec and dialogue.spec.

local T = require("./Test")
local TextCaps = require("../src/shared/Logic/TextCaps")
local TextScan = require("./TextScan")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = T.describe, T.it, T.expect

-- At most this many lines of findings in one failure, so a broken scan stays readable.
local SHOWN = 40

local function fail(problems: { string }, hint: string)
	if #problems == 0 then
		return
	end
	table.sort(problems)
	local shown = table.move(problems, 1, math.min(#problems, SHOWN), 1, {})
	if #problems > SHOWN then
		table.insert(shown, `... and {#problems - SHOWN} more`)
	end
	error(`{#problems} found ({hint}):\n  {table.concat(shown, "\n  ")}`, 0)
end

local function has(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

local violations: { [string]: TextScan.Violation }? = nil
local function allViolations(): { [string]: TextScan.Violation }
	if violations == nil then
		violations = TextScan.violations()
	end
	return violations :: { [string]: TextScan.Violation }
end

describe("TextCaps", function()
	it("fills placeholders with samples of their kind's length", function()
		expect(TextCaps.chars(TextCaps.expand("{player}"))).toBe(20)
		expect(TextCaps.chars(TextCaps.expand("{item}"))).toBe(28)
		expect(TextCaps.chars(TextCaps.expand("{monster} {boss}"))).toBe(49)
		expect(TextCaps.chars(TextCaps.expand("{npc}"))).toBe(16)
		expect(TextCaps.chars(TextCaps.expand("{area}{map}{zone}"))).toBe(60)
		expect(TextCaps.chars(TextCaps.expand("{guild}"))).toBe(24)
		expect(TextCaps.chars(TextCaps.expand("{n}{count}{gold}{exp}{level}{pct}{min}{hours}{key}"))).toBe(54)
		expect(TextCaps.chars(TextCaps.expand("{slowDuration}"))).toBe(6)
		expect(TextCaps.chars(TextCaps.expand("{something}"))).toBe(12)
	end)

	it("counts what the player sees: no rich-text tags, no line breaks", function()
		expect(TextCaps.chars('<font color="#ffcc00"><b>Łup</b></font>')).toBe(3)
		expect(TextCaps.chars("ab\ncd")).toBe(4)
		expect(TextCaps.chars("◆ 5")).toBe(3)
	end)

	it("measures width with the uifit model: letter 0.56 em, space 0.3 em, symbol 1 em", function()
		expect(TextCaps.width("ab", 10)).toBeNear(11.2, 1e-9)
		expect(TextCaps.width("a b", 20)).toBeNear(28.4, 1e-9)
		expect(TextCaps.width("◆", 17)).toBeNear(17, 1e-9)
	end)

	it("wraps greedily, starts a line at each break and splits a word wider than the line", function()
		local word = TextCaps.width("abcd", 10)
		expect(TextCaps.lines("abcd abcd", 10, word * 2 + 3)).toBe(1)
		expect(TextCaps.lines("abcd abcd", 10, word * 2 + 2.9)).toBe(2)
		expect(TextCaps.lines("abcd\nabcd", 10, 1000)).toBe(2)
		expect(TextCaps.lines(string.rep("a", 30), 10, word)).toBe(8)
	end)

	it("counts sentences by their end marks before a capital", function()
		expect(TextCaps.sentences("Jedno. Dwa! Trzy? Cztery…")).toBe(4)
		expect(TextCaps.sentences("Na przykład np. miecz, 1.5 m, „Łuk”. Śnieg.")).toBe(2)
		expect(TextCaps.sentences("")).toBe(0)
	end)

	it("holds the caps of UI-ZASADY §2", function()
		local caps: { [string]: number } = {
			button = 18,
			tab = 12,
			windowTitle = 22,
			modalTitle = 28,
			sectionTitle = 24,
			panelTitle = 20,
			sectionSummary = 36,
			label = 20,
			line = 60,
			hudLine = 32,
			hudTip = 48,
			tileLabel = 18,
			toast = 60,
			alert = 28,
			banner = 56,
			card = 40,
			prompt = 60,
			modalBody = 90,
			modalDetails = 240,
			modalButton = 14,
			infoTip = 240,
			details = 300,
			tooltipCompact = 60,
			skillTip = 60,
			skillShort = 60,
			breakpoint = 48,
			npcGreeting = 60,
			dialogPage = 140,
			reply = 44,
			tutorialTile = 80,
			loadingTip = 80,
			cutscene = 140,
			placeholder = 20,
			keyName = 18,
		}
		for id, chars in caps do
			expect(TextCaps.SURFACES[id] and TextCaps.SURFACES[id].chars).toBe(chars)
		end
		for id in TextCaps.SURFACES do
			expect(caps[id] ~= nil).toBe(true)
		end
		expect(TextCaps.SURFACES.toast.lines).toBe(2)
		expect(TextCaps.SURFACES.toast.width).toBe(520 - 28)
		expect((TextCaps.SURFACES.toast.alt :: TextCaps.Wrap).lines).toBe(3)
		expect(TextCaps.SURFACES.infoTip.sentences).toBe(3)
		expect(TextCaps.SURFACES.tooltipCompact.lines).toBe(10)
		expect(TextCaps.SURFACES.skillTip.lines).toBe(5)
	end)

	it("lets a listed glossary term pass the tab cap whole, and nothing else (UI-ZASADY §2)", function()
		-- UI package D, 2026-11-10: the alchemist's "Błogosławieństwa" tab, the game's word for these buffs
		local term = "Błogosławieństwa"
		expect(TextCaps.chars(term) > TextCaps.SURFACES.tab.chars).toBe(true)
		expect(TextCaps.check("tab", term)).toBe(true)
		expect(TextCaps.check("tab", "<b>" .. term .. "</b>")).toBe(true) -- what the player sees
		-- only the whole term: anything longer or different stays capped, and no other surface takes it
		expect(TextCaps.check("tab", term .. "!")).toBe(false)
		expect(TextCaps.check("tab", "Wszystkie zwoje")).toBe(false)
		expect(TextCaps.check("label", term .. " i inne rzeczy")).toBe(false)
		local listed = 0
		for surface, terms in TextCaps.TERMS do
			expect(TextCaps.SURFACES[surface].terms).toBe(terms)
			for _ in terms do
				listed += 1
			end
		end
		expect(listed).toBe(1) -- a new term is an owner's word for a thing; add it here and in UI-ZASADY §2
	end)

	it("checks lines and sentences, not only characters", function()
		local ok, why = TextCaps.check("line", "Pierwsza\nDruga")
		expect(ok).toBe(false)
		expect(why).toBe("2 > 1 lines")
		ok, why = TextCaps.check("banner", string.rep("◆", 34)) -- 34 symbols, 884 px at 26 in 856
		expect(ok).toBe(false)
		expect(why).toBe("2 > 1 lines in 856 px at 26")
		ok = TextCaps.check("infoTip", "Raz. Dwa. Trzy. Cztery.")
		expect(ok).toBe(false)
		ok = TextCaps.check("tooltipCompact", string.rep("linia\n", 9) .. "linia")
		expect(ok).toBe(true)
		ok = TextCaps.check("tooltipCompact", string.rep("linia\n", 10) .. "linia")
		expect(ok).toBe(false)
	end)
end)

describe("textcaps T6: the negative case", function()
	it("a 61-character toast fails and a 60-character one fits", function()
		local sixty = string.rep("Zlecenie. ", 6)
		expect(TextCaps.chars(sixty)).toBe(60)
		expect((TextCaps.check("toast", sixty))).toBe(true)
		local ok, why = TextCaps.check("toast", sixty .. "x")
		expect(ok).toBe(false)
		expect(why).toBe("61 > 60 chars")
	end)

	it("a short toast on 3 lines fails", function()
		local ok, why = TextCaps.check("toast", "Linia pierwsza.\nLinia druga.\nLinia trzecia.")
		expect(ok).toBe(false)
		expect(why).toBe("3 > 2 lines in 492 px at 20")
	end)
end)

describe("textcaps T2: universal rules", function()
	it("finds control words and key hints, not words that only look like them", function()
		expect(TextScan.control("Kliknij kropkę, żeby zmienić tryb.")).toBe("kliknij")
		expect(TextScan.control("Najedź na ikonę.")).toBe("najedź")
		expect(TextScan.control("Use prawy klik")).toBe("prawy klik")
		expect(TextScan.control("Click the dot")).toBe("click")
		expect(TextScan.control("Drag it here")).toBe("drag")
		expect(TextScan.control("Open the journal (L).")).toBe("(L)")
		expect(TextScan.control("Press ({key}) to ride")).toBe("({key})")
		expect(TextScan.control("A dragon wakes in the ruins")).toBeNil()
		expect(TextScan.control("Smocza Waluta (i)")).toBeNil()
	end)

	it("every text with an em dash is a listed violation", function()
		local found = allViolations()
		local problems = {}
		for key, text in pl :: { [string]: string } do
			local other = (en :: { [string]: string })[key] or ""
			if string.find(text, TextScan.EM_DASH, 1, true) or string.find(other, TextScan.EM_DASH, 1, true) then
				local v = found[key]
				if v == nil or not string.find(v.reason, "em dash", 1, true) then
					table.insert(problems, key)
				end
			end
		end
		fail(problems, "em dash not reported")
	end)

	-- Final UI review 2026-11-10 (the toasts said "Przyjęto zadanie" under the button "Questy", a tablet's tutorial
	-- named a "torba"): the HUD's and the messages' texts (packages A and B) keep the glossary's words of
	-- docs/UI-ZASADY.md §3: a quest is a "quest", the backpack a "plecak".
	it("A and B texts call a quest a quest and the backpack a backpack", function()
		local OTHER = { "zadani", "zadań", "torb" }
		local problems = {}
		for key, text in pl :: { [string]: string } do
			local owner = TextScan.owner(key)
			if owner == "A" or owner == "B" then
				local lower = string.lower(text)
				for _, word in OTHER do
					if string.find(lower, word, 1, true) then
						table.insert(problems, `{key} ({owner}): {word}`)
					end
				end
			end
		end
		fail(problems, "a word the glossary replaced")
	end)

	-- Final UI review 2026-11-11: the windows' texts (packages C, D and E) keep the glossary's words too. The premium
	-- currency is "Smocza Waluta" (DECYZJE S120), ◆ beside a number in a reward list: the arena's season tab, the
	-- tournament, the quest board and the rankings said "Smocze Odłamki" or a bare "odłamków", which reads like the
	-- upgrade material; en says "Dragon Shards" everywhere.
	it("C, D and E texts name the premium currency one way", function()
		local OTHER = { "smocz[^ ]* odłamk", "}%s*odłamk", "%d%s*odłamk", "odłamki z kompletu" }
		local problems = {}
		for key, text in pl :: { [string]: string } do
			local owner = TextScan.owner(key)
			if owner == "C" or owner == "D" or owner == "E" then
				local lower = string.lower(text)
				for _, pattern in OTHER do
					if string.find(lower, pattern) then
						table.insert(problems, `{key} ({owner}): {pattern}`)
					end
				end
				local english = (en :: { [string]: string })[key]
				if english and string.find(english, "Dragon Currency", 1, true) then
					table.insert(problems, `{key} ({owner}) en: Dragon Currency`)
				end
			end
		end
		fail(problems, "a second name for the premium currency")
		-- the glossary's words themselves
		expect(string.find(pl["premium.currency.note"], "Smocza Waluta", 1, true) ~= nil).toBe(true)
		expect(string.find(en["premium.currency.note"], "Dragon Shards", 1, true) ~= nil).toBe(true)
	end)

	-- Final UI review 2026-11-11: armor is "Pancerz" (en "Armor"): the derived list said "Obrona" and the skills
	-- "obniża obronę celu" beside "Przebicie pancerza" and the stats' "+12 pancerza". "Obrona" stays the name of a
	-- defence (a path's role, the skills' tank role, a monster's defence in the bestiary, a lair defended, en's stat
	-- group).
	it("C, D and E texts call armor pancerz", function()
		local DEFENCE = {
			["paths.role.tank"] = true,
			["skills.role.O"] = true,
			["best.defence"] = true,
			["best.reveal2"] = true,
			["quest.wyrmSpire.p1b"] = true,
			["statGroup.defense"] = true,
		}
		local problems = {}
		for key, text in pl :: { [string]: string } do
			local owner = TextScan.owner(key)
			if (owner == "C" or owner == "D" or owner == "E") and not DEFENCE[key] then
				if string.find(string.lower(text), "obron", 1, true) then
					table.insert(problems, `{key} ({owner})`)
				end
			end
			if (owner == "C" or owner == "D" or owner == "E") and (en :: { [string]: string })[key] then
				local english = string.lower((en :: { [string]: string })[key])
				if string.find(english, "defense", 1, true) and not DEFENCE[key] then
					table.insert(problems, `{key} ({owner}) en: defense`)
				end
			end
		end
		fail(problems, "armor called obrona or defense")
		expect(pl["stat.armor"]).toBe("Pancerz")
		expect(en["stat.armor"]).toBe("Armor")
	end)

	-- Final UI review 2026-11-11: the windows say "quest" too (UI 3's default): a quest item's tooltip said "• zadania:",
	-- the wardrobe "Nagroda za zadanie", the mount window "Zadanie stajennego", and the journal kept the neuter of
	-- "zadanie" ("aby je rozpocząć", "Dostępne od poziomu"). The admin commands' texts and the map's search words (a
	-- player may still type "zadanie") keep it.
	it("C, D and E texts call a quest a quest", function()
		local OTHER = { "zadani", "zadań" }
		local problems = {}
		for key, text in pl :: { [string]: string } do
			local owner = TextScan.owner(key)
			local kept = string.sub(key, 1, 6) == "admin." or string.sub(key, 1, 16) == "worldmap.search."
			if (owner == "C" or owner == "D" or owner == "E") and not kept then
				local lower = string.lower(text)
				for _, word in OTHER do
					if string.find(lower, word, 1, true) then
						table.insert(problems, `{key} ({owner}): {word}`)
					end
				end
			end
		end
		fail(problems, "a word the glossary replaced")
		-- a quest is masculine
		expect(string.find(pl["quest.getFrom"], "aby go rozpocząć", 1, true) ~= nil).toBe(true)
		expect(string.find(pl["quest.nextAt"], "^Dostępny od poziomu") ~= nil).toBe(true)
		expect(string.find(en["mount.empty"], "task", 1, true)).toBeNil()
	end)

	-- Final UI review 2026-11-11: the ☰ tile, the ✧ tooltip and the toast say "Nagroda dnia", the window they open said
	-- "Nagroda za logowanie" and so did the reward's mail with a full backpack.
	it("the daily reward has one name from the tile to its window and its mail", function()
		for lang, texts in { pl = pl, en = en } :: { [string]: { [string]: string } } do
			local name = texts["menu.tile.login"]
			expect({ lang, texts["window.login.title"] }).toEqual({ lang, name })
			expect({ lang, string.sub(texts["mail.subject.login"], 1, #name) }).toEqual({ lang, name })
		end
		expect(string.find(pl["login.button"], pl["menu.tile.login"], 1, true) ~= nil).toBe(true)
	end)
end)

describe("textcaps T1-T3: caps and the per-package lists", function()
	it("every key over a cap or a rule is listed under its owner", function()
		local fixtures = TextScan.fixtures()
		local problems = {}
		for key, v in allViolations() do
			if fixtures[v.owner].known[key] == nil then
				local elsewhere = nil
				for _, package in TextScan.PACKAGES do
					if fixtures[package].known[key] then
						elsewhere = package
					end
				end
				if elsewhere then
					table.insert(problems, `{key}: listed under {elsewhere}, its owner is {v.owner}`)
				else
					table.insert(problems, `{key}: {v.reason} (owner {v.owner}; {v.chars} chars)`)
				end
			end
		end
		fail(problems, "shorten the text (pl and en, the same placeholders), or list it in its owner's fixture")
	end)

	it("the lists only shrink: a listed key still breaks a rule, no longer, and belongs to that package", function()
		local fixtures = TextScan.fixtures()
		local found = allViolations()
		local problems = {}
		for _, package in TextScan.PACKAGES do
			for key, known in fixtures[package].known do
				local v = found[key]
				if v == nil then
					table.insert(problems, `{package} {key}: now passes, remove its line`)
				elseif v.owner ~= package then
					table.insert(problems, `{package} {key}: belongs to package {v.owner}`)
				elseif v.chars > known.chars then
					table.insert(problems, `{package} {key}: got longer ({known.chars} -> {v.chars} chars)`)
				end
			end
		end
		fail(problems, "tests/fixtures/textcaps")
	end)

	it("every fixture rule names a surface of TextCaps", function()
		-- a rule may match no key yet (tutorial.<step>.phone: A adds the phone texts)
		local problems = {}
		for _, package in TextScan.PACKAGES do
			for _, rule in TextScan.fixtures()[package].rules do
				if TextCaps.SURFACES[rule.surface] == nil then
					table.insert(problems, `{package} {rule.pattern}: no surface {rule.surface}`)
				end
			end
		end
		fail(problems, "fixture rules")
	end)
end)

describe("textcaps T4: coverage of the scan", function()
	it("read every file to its end (every bracket and function body closed)", function()
		local scan = TextScan.scan()
		expect(scan.files > 800).toBe(true)
		fail(scan.health, "files the scanner lost its place in")
	end)

	it("found today's message calls", function()
		local calls = TextScan.scan().calls
		-- 2026-11-10: 196 Toast.push, 226 server toasts (the remote and the helpers), 42 banners, 47 alerts
		expect((calls["toast client"] or 0) >= 180).toBe(true)
		expect((calls["toast server"] or 0) >= 200).toBe(true)
		expect((calls.banner or 0) >= 35).toBe(true)
		expect((calls.alert or 0) >= 40).toBe(true)
	end)

	it("every literal key at a toast, banner, alert, prompt or card site exists and has that surface", function()
		local problems = {}
		for key, surface in TextScan.scan().messages do
			if (pl :: { [string]: string })[key] == nil or (en :: { [string]: string })[key] == nil then
				table.insert(problems, `{key}: at a {surface} site, missing from pl or en`)
			elseif not has(TextScan.surfaces(key), surface) then
				table.insert(problems, `{key}: at a {surface} site, not mapped to it`)
			end
		end
		fail(problems, "message keys")
	end)

	it("maps the sites the audits named to their surfaces", function()
		local cases = {
			{ "contract.ready", "toast" }, -- Net.Fire(player, "Toast", ...)
			{ "shop.error.locked", "toast" }, -- Toast.push(Text.now(...))
			{ "death.error.gold", "toast" }, -- return false, "key"
			{ "social.whisper.otherServer", "modalBody" }, -- an error the client shows in a modal (NOT_TOASTED)
			{ "tourney.notPicked", "toast" }, -- through the service's own helper
			{ "paths.toast.pointSoon", "toast" }, -- local key = if ... then (if soon then "a" else "b") else ...
			{ "arena.net.cancelled.noShow", "toast" }, -- back home from the arena server
			{ "boss.morvane.phase3", "alert" }, -- the boss's announce
			{ "dungeon.timeout", "alert" }, -- DungeonService fail(run, key) -> announce
			{ "boss.cast.lethal", "alert" }, -- the cast bar
			{ "rework2.body", "modalBody" },
			{ "rework2.body.info", "modalDetails" },
			{ "autoGrind.desc", "infoTip" }, -- a card spec's `info` (PremiumShop/Cards)
			{ "hud.auto", "hudTip" },
			{ "pvp.dot.off", "hudTip" },
			{ "window.inventory.title", "windowTitle" },
			{ "alchemy.group.blessing", "tab" },
			{ "keys.sprint", "keyName" },
			{ "skill.blink.bp10", "breakpoint" }, -- D's rule: a breakpoint's option A ...
			{ "skill.blink.bp10b", "breakpoint" }, -- ... and its option B
			{ "skill.blink.desc", "details" }, -- the skills window's texts through Data/Skills and Data/Paths
			{ "path.scout.desc", "infoTip" },
			{ "path.scout.eye.short", "skillShort" }, -- NodeText.shortKey
			{ "quest.side_granary.p1", "dialogPage" },
			{ "npc.healer.greeting", "npcGreeting" },
		}
		local problems = {}
		for _, case in cases do
			local surfaces = TextScan.surfaces(case[1])
			if not has(surfaces, case[2]) then
				table.insert(problems, `{case[1]}: {table.concat(surfaces, ", ")}, not {case[2]}`)
			end
		end
		fail(problems, "known sites")
	end)

	it("keeps keys off the surfaces the code never shows them on", function()
		local cases = {
			{ "worldboss.card.every", "banner" }, -- the (i) of the world boss's map card, not an announcement
			{ "worldboss.rewardCard.share", "banner" }, -- the (i) of BossReward's share line
			{ "social.whisper.otherServer", "toast" }, -- SocialController.failed offers a letter in a modal
		}
		local problems = {}
		for _, case in cases do
			if has(TextScan.surfaces(case[1]), case[2]) then
				table.insert(problems, `{case[1]}: mapped to {case[2]}`)
			end
		end
		fail(problems, "surfaces a rule or a site gave by mistake")
	end)

	it("gives each key the first package of the plan that reads it, else its rule's, else E", function()
		expect(TextScan.owner("hud.auto")).toBe("A") -- Hud/AutoGroup
		expect(TextScan.owner("contract.ready")).toBe("B") -- a toast: B's band shows it
		expect(TextScan.owner("shop.error.locked")).toBe("B") -- read in D's ShopWindow too, B comes first
		expect(TextScan.owner("rework2.body")).toBe("C") -- ReworkController
		expect(TextScan.owner("alchemy.group.blessing")).toBe("D") -- AlchemyWindow
		expect(TextScan.owner("skill.blink.name")).toBe("D") -- D's rule, not an orphan of E
		expect(TextScan.owner("path.berserker.rhythm.short")).toBe("D") -- D's rule comes before E's `.short` rule
		expect(TextScan.owner("quest.side_granary.p1")).toBe("E") -- E's rule
		expect(TextScan.owner("worldboss.safeZone")).toBe("B") -- B's rule: the zone banner's note
		expect(TextScan.owner("no.such.key.anywhere")).toBe("E")
		expect(TextScan.ownerOfFile("src/client/UI/Screens/Hud/QuestTracker.luau")).toBe("A")
		expect(TextScan.ownerOfFile("src/client/UI/Screens/Hud/AreaBanner.luau")).toBe("B")
		expect(TextScan.ownerOfFile("src/client/UI/Screens/SkillsWindow/Details.luau")).toBe("D")
		expect(TextScan.ownerOfFile("src/server/Services/ShopService.luau")).toBeNil()
	end)
end)
